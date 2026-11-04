#!/usr/bin/env python3
"""
mkenc -- the generator of the prefix-coded encodings.  The single source of truth of an encoding is its forms table,

    spec/pdp64-16/forms.json     pdp64/16: 16 registers, 4-bit fields (A16 + the four fused pairs)
    spec/pdp64-32/forms.json     pdp64/32: 32 registers, 5-bit fields (A32r + the four fused pairs)

(written by docs/codegen-data/encoding/export_forms.py from the optimiser; see spec/README.md).  This reads them and writes

    build/pdp64-16-tab.c, build/pdp64-32-tab.c   the C tables of the codec (common/pdp64enc.c): forms, leaves, bit runs, mnemonics
    build/x/pdp64-mnemonics.hbnf, pdp64-asm.hbnf, pdp64-groups.h, pdp64-extnames.h
                                                 the assembly grammar of as64: the grammar of spec/ plus the mnemonics only the new
                                                 encodings have (group mn-ext) and the registers r16-r31
    spec/pdp64-NN/tables.md                      the leaf tables for people (with --md)

It verifies each table as it reads it, independently of the optimiser: the prefixes form a prefix code (Kraft), every leaf covers all of its
16n bits exactly once, and the 65,536 first parcels decode to at most one leaf each.

    tools/mkenc.py            generate into $BUILD (default build)
    tools/mkenc.py --md       also rewrite spec/pdp64-NN/tables.md
    tools/mkenc.py --check    fail if spec/pdp64-NN/tables.md is not what the forms tables say
"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
ENCS = [('16', 'pdp64/16'), ('32', 'pdp64/32')]
SIZE = {'movq': 8, 'movl': 4, 'movw': 2, 'movb': 1, 'movzl': 4, 'movzw': 2, 'movzb': 1}
DP = 255


def msize(mn):
    return SIZE.get(mn.split('.')[0], 1)


def load(tag):
    return json.load(open(os.path.join(ROOT, 'spec', 'pdp64-' + tag, 'forms.json')))


# ---------------------------------------------------------------- verification
def verify(d):
    forms, leaves = d['forms'], d['leaves']
    kraft = 0.0
    seen = {}
    for i, lf in enumerate(leaves):
        f = forms[lf['form']]
        L = lf['L']
        assert 1 <= L <= 16
        kraft += 2.0 ** -L
        lo = lf['prefix'] << (16 - L)
        for p in range(lo, lo + (1 << (16 - L))):
            assert p not in seen, 'prefix clash between leaves %d and %d' % (seen[p], i)
            seen[p] = i
        used = set(16 * 0 + b for b in range(15, 15 - L, -1))
        for oi, pi, bits in lf['place']:
            for b in bits:
                assert b not in used, (f['name'], 'bit used twice')
                used.add(b)
        for b in lf['subbits']:
            assert b not in used
            used.add(b)
        assert len(used) == 16 * f['n'], (f['name'], len(used), 16 * f['n'])
    assert kraft <= 1.0 + 1e-12
    return len(seen)


# ---------------------------------------------------------------- C tables
class Pool:
    def __init__(self):
        self.items, self.idx = [], {}

    def add(self, key, make=None):
        if key not in self.idx:
            self.idx[key] = len(self.items)
            self.items.append(key)
        return self.idx[key]


def runs_of(bits):
    """absolute bit positions 16*parcel+bit, msb first -> [(parcel, hi, len)] within one parcel"""
    out = []
    for b in bits:
        k, bb = divmod(b, 16)
        if out and out[-1][0] == k and out[-1][1] - out[-1][2] == bb:
            out[-1][2] += 1
        else:
            out.append([k, bb, 1])
    return out


def gen_c(d, tag):
    forms, leaves = d['forms'], d['leaves']
    specs = Pool()
    hot = []
    hottabs = {}

    def spec(s):
        k = s['k']
        z = dict(kind=0, w=0, sgn=0, ntab=0, kop=0, scale=0, kval=0, tab=0, rn=-1, rx=-1)
        if k == 'R':
            z.update(kind='ES_R', w=s['w'])
            if s['table'] is not None:
                t = tuple(s['table'])
                if t not in hottabs:
                    hottabs[t] = len(hot)
                    hot.extend(t)
                z.update(ntab=len(t), tab=hottabs[t])
        elif k == 'K':
            kind, v = s['op']
            if kind == 'R':
                z.update(kind='ES_K', kop='EK_R', kval=DP if v == 16 else v)
            else:
                z.update(kind='ES_K', kop='EK_I', kval=v)
        elif k == 'I':
            assert s['vals'] is None
            z.update(kind='ES_I', w=s['w'], sgn=int(s['signed']), scale=s['scale'])
        elif k == 'B':
            z.update(kind='ES_B', w=s['dw'], sgn=int(s['signed']), scale=0 if s['scale'] == 'sz' else s['scale'], rn=spec(s['rn']))
        elif k == 'X':
            z.update(kind='ES_X', w=s['dw'], sgn=int(s['signed']), rn=spec(s['rn']), rx=spec(s['rx']))
        elif k in ('PI', 'PD'):
            z.update(kind='ES_' + k, w=s['dw'], rn=spec(s['rn']))
        elif k == 'PC':
            z.update(kind='ES_PC', w=s['w'], scale=s['unit'])
        elif k == 'A':
            z.update(kind='ES_A', w=s['w'])
        else:
            raise ValueError(k)
        return specs.add(tuple(sorted(z.items())))

    formspec, formmn = [], []
    mnames = sorted(set(m for f in forms for m in f['mns']))
    mid = {m: i for i, m in enumerate(mnames)}
    frows = []
    for f in forms:
        sp0 = len(formspec)
        for s in f['specs']:
            formspec.append(spec(s))
        mn0 = len(formmn)
        formmn.extend(mid[m] for m in f['mns'])
        frows.append('\t{ %d, %d, %d, %d, %d, "%s" },' % (f['n'], len(f['specs']), sp0, len(f['mns']), mn0, f['name']))
    runs, places, lrows = [], [], []
    cands = {m: [] for m in mnames}
    order = {}
    for fi, f in enumerate(forms):
        order[fi] = (f['n'], fi)
    for li, lf in enumerate(leaves):
        f = forms[lf['form']]
        pl0 = len(places)
        pls = []
        sub = lf['subbits']
        for oi, pi, bits in lf['place']:
            if oi == -1:
                pls.append((0xFE, 0, bits))			# xbits form: the whole mnemonic index
            else:
                pls.append((oi, pi, bits))
        if sub:
            pls.append((0xFE, 0, sub))
        for oi, pi, bits in pls:
            rr = runs_of(bits)
            places.append('\t{ %d, %d, %d, %d, %d },' % (oi, pi, len(bits), len(rr), len(runs)))
            for k, hi, ln in rr:
                runs.append('\t{ %d, %d, %d },' % (k, hi, ln))
        nm = len(lf['mns'])
        off = lf['off']
        assert f['mns'][off:off + nm] == lf['mns']
        lrows.append('\t{ %d, %d, %d, %d, %d, %d, %d },' % (lf['form'], off, nm, lf['prefix'], lf['L'], pl0, len(pls)))
        for k, m in enumerate(lf['mns']):
            cands[m].append((order[lf['form']], lf['form'], li, k))
    mrows, crows = [], []
    for m in mnames:
        cs = sorted(cands[m])
        mrows.append('\t{ "%s", %d, %d, %d },' % (m, msize(m), len(crows), len(cs)))
        for _, fi, li, k in cs:
            crows.append('\t{ %d, %d, %d },' % (fi, li, k))
    out = []
    out.append('/* generated by tools/mkenc.py from spec/pdp64-%s/forms.json -- do not edit */' % tag)
    out.append('#include "pdp64enc.h"')
    out.append('static const struct espec S[] = {')
    for it in specs.items:
        z = dict(it)
        out.append('\t{ %s, %d, %d, %d, %s, %d, %d, %d, %d, %d },' % (z['kind'], z['w'], z['sgn'], z['ntab'], z['kop'] or 0, z['scale'], z['kval'], z['tab'], z['rn'], z['rx']))
    out.append('};')
    out.append('static const uint16_t FS[] = { %s };' % ', '.join(map(str, formspec)))
    out.append('static const uint16_t FM[] = { %s };' % ', '.join(map(str, formmn)))
    out.append('static const uint8_t HOT[] = { %s };' % (', '.join(map(str, hot)) or '0'))
    out.append('static const struct eform F[] = {')
    out += frows
    out.append('};')
    out.append('static const struct erun R[] = {')
    out += runs
    out.append('};')
    out.append('static const struct eplace P[] = {')
    out += places
    out.append('};')
    out.append('static const struct eleaf LF[] = {')
    out += lrows
    out.append('};')
    out.append('static const struct ecand C[] = {')
    out += crows
    out.append('};')
    out.append('static const struct emn M[] = {')
    out += mrows
    out.append('};')
    out.append('struct etab enc_tab_%s = { "%s", %d, %d, %d, %d, %d, M, F, S, FS, FM, HOT, LF, P, R, C, 0 };' %
               (tag, d['name'], d['registers'], len(mnames), len(forms), len(leaves), len(specs.items)))
    return '\n'.join(out) + '\n', mnames


# ---------------------------------------------------------------- human-readable tables
def fieldpos(lf, f):
    def rng(bits):
        parts = []
        cur = []
        for b in bits:
            if cur and (b // 16 != cur[-1] // 16 or b != cur[-1] - 1):
                parts.append(cur); cur = []
            cur.append(b)
        if cur:
            parts.append(cur)
        return '+'.join('p%d[%d:%d]' % (c[0] // 16, c[0] % 16, c[-1] % 16) if len(c) > 1 else 'p%d[%d]' % (c[0] // 16, c[0] % 16) for c in parts)
    names = {'r': 'r', 'i': 'imm', 'd': 'd', 's': 'scale', 'p': 'pcrel', 'a': 'abs'}
    out = []
    for oi, pi, bits in sorted(lf['place'], key=lambda x: -max(x[2])):
        out.append('%s=%s' % ('subop' if oi == -1 else 'op%d.%s' % (oi + 1, part_name(f['specs'][oi], pi)), rng(bits)))
    if lf['subbits']:
        out.append('subop=' + rng(lf['subbits']))
    return ' '.join(out)


def part_names(s):
    k = s['k']
    if k == 'R':
        return ['r']
    if k == 'K':
        return []
    if k == 'I':
        return ['imm']
    if k == 'B':
        return part_names(s['rn']) + (['d'] if s['dw'] else [])
    if k == 'X':
        return [('base' if x == 'r' else x) for x in part_names(s['rn'])] + [('index' if x == 'r' else x) for x in part_names(s['rx'])] + ['scale'] + (['d'] if s['dw'] else [])
    if k in ('PI', 'PD'):
        return part_names(s['rn']) + ['stride']
    if k == 'PC':
        return ['pcrel']
    if k == 'A':
        return ['abs']


def part_name(s, pi):
    n = part_names(s)
    nm = n[pi]
    if s['k'] in ('B', 'PI', 'PD') and nm == 'r':
        return 'base'
    if s['k'] == 'X':
        return nm
    return nm


def gen_md(d, tag):
    forms = d['forms']
    L = sorted(range(len(d['leaves'])), key=lambda i: (forms[d['leaves'][i]['form']]['n'], d['leaves'][i]['L'], i))
    o = ['# %s: the leaves of the encoding' % d['name'], '',
         'Generated by `tools/mkenc.py --md` from `spec/pdp64-%s/forms.json`; do not edit.  %d forms, %d leaves, %d registers.' % (tag, len(forms), len(d['leaves']), d['registers']), '',
         'Each leaf is a prefix-coded group of mnemonics of one form.  The prefix is the top L bits of parcel 0; `subop` selects the mnemonic inside the group',
         '(binary-aligned); `opN` is the Nth operand of the assembly syntax; fields are written `pK[hi:lo]` (bits of parcel K, bit 15 the top) and joined by `+`',
         'where a field is split.  There are no pad bits: every bit of an instruction is prefix, sub-opcode or operand.  A hot-register field holds an index into the',
         'table below, not a register number.', '',
         '**Hot-register table(s)** (the part of the ABI the encoding depends on, docs/abi.md): 3-bit fields hold, in order, `%s`' % ' '.join(regname(r) for r in d['hot8'])
         + ('; 4-bit fields hold `%s`' % ' '.join(regname(r) for r in d['hot16']) if d['hot16'] else ''), '',
         '| parcels | form | L | prefix (top bits of p0) | mnemonics | fields |', '|---|---|---|---|---|---|']
    for i in L:
        lf = d['leaves'][i]
        f = forms[lf['form']]
        o.append('| %d | %s | %d | %s | %s | %s |' % (f['n'], f['name'], lf['L'], format(lf['prefix'], '0%db' % lf['L']), ' '.join(lf['mns']), fieldpos(lf, f)))
    return '\n'.join(o) + '\n'


def regname(r):
    return {14: 'sp', 13: 'fp'}.get(r, 'r%d' % r)


# ---------------------------------------------------------------- the grammar of as64 with the new words
def mkgrammar_order(en):
    sys.path.insert(0, HERE)
    import mkgrammar
    return mkgrammar.group_order(en)


def old_words(path):
    sys.path.insert(0, HERE)
    import mkgrammar
    en = mkgrammar.enums(path)
    return en


FUSED = ['movcall', 'popmret', 'popret', 'mov2']


def gen_grammar(allmn, outdir):
    en = old_words(os.path.join(ROOT, 'spec', 'pdp64-mnemonics.hbnf'))
    old = set()
    for g, items in en.items():
        if g.startswith('mn-'):
            for lit, v in items:
                old.add(lit)
    old |= {'rol'}
    ext = sorted(m for m in allmn if m not in old)
    os.makedirs(outdir, exist_ok=True)
    mn = open(os.path.join(ROOT, os.environ.get('BUILD', 'build'), 'pdp64-mnemonics.hbnf')).read()
    # the group: the number is the position in this list (the C table ext_names in pdp64-extnames.h)
    body = '\n; written by tools/mkenc.py: the words only the prefix-coded encodings (pdp64/16, pdp64/32) have; the number is the position in the list\nmn-ext = ' + '\n       | '.join('"%s"@%d' % (m, i) for i, m in enumerate(ext)) + '\n'
    m = re.search(r'^mnemonic = (.*)\Z', mn, flags=re.M | re.S)
    head = mn[:m.start()]
    alts = m.group(1).rstrip() + '\n         | mn-ext\n'
    head = head.replace('"r15"@15', '"r15"@15 | ' + ' | '.join('"r%d"@%d' % (i, i) for i in range(16, 32)), 1)
    assert '"r31"@31' in head
    open(os.path.join(outdir, 'pdp64-mnemonics.hbnf'), 'w').write(head + body + '\nmnemonic = ' + alts)
    a = open(os.path.join(ROOT, 'spec', 'pdp64-asm.hbnf')).read()
    a = a.replace('reg      = rnum | ralias', 'reg      = rnum | ralias\n; (as64: r16-r31 parse in every encoding; only pdp64/32 has them, the others refuse them in the assembler)')
    open(os.path.join(outdir, 'pdp64-asm.hbnf'), 'w').write(a)
    return ext, en


def main():
    md = '--md' in sys.argv
    check = '--check' in sys.argv
    bd = os.path.join(ROOT, os.environ.get('BUILD', 'build'))
    os.makedirs(bd, exist_ok=True)
    allmn = set()
    bad = 0
    for tag, name in ENCS:
        d = load(tag)
        n = verify(d)
        c, mnames = gen_c(d, tag)
        open(os.path.join(bd, 'pdp64-%s-tab.c' % tag), 'w').write(c)
        allmn |= set(mnames)
        text = gen_md(d, tag)
        p = os.path.join(ROOT, 'spec', 'pdp64-' + tag, 'tables.md')
        if md:
            open(p, 'w').write(text)
        elif check:
            if not os.path.exists(p) or open(p).read() != text:
                print('mkenc: %s is not what spec/pdp64-%s/forms.json says (run tools/mkenc.py --md)' % (p, tag)); bad = 1
    ext, en = gen_grammar(allmn, os.path.join(bd, 'x'))
    with open(os.path.join(bd, 'x', 'pdp64-extnames.h'), 'w') as f:
        f.write('/* generated by tools/mkenc.py -- do not edit.  The words of group mn-ext, by number. */\nstatic const char *const ext_names[] = {\n')
        for m in ext:
            f.write('\t"%s",\n' % m)
        f.write('};\n#define N_EXT_NAMES %d\n' % len(ext))
    # the names of the mnemonics by (group, number), with the word an alias stands for: for the assembler's canonical instruction
    order = mkgrammar_order(en)
    with open(os.path.join(bd, 'x', 'pdp64-mnnames.h'), 'w') as f:
        f.write('/* generated by tools/mkenc.py -- do not edit.  Every word of the mnemonic groups: group (MG_*), number, the word, the word of the encoding it stands for. */\n'
                'struct mnname { short mg, num; const char *name, *canon; };\nstatic const struct mnname mnnames[] = {\n')
        consts = {}
        for rule, items in en.items():
            for lit, v in items:
                consts[(rule, v)] = lit
        for gi, g in enumerate(order):
            items = en[g]
            for lit, v in items:
                num = v
                if len(items) == 1:
                    num = {'mn-lea': 11, 'mn-sob': 63}.get(g, 0)
                canon = lit
                if v >= 0x100 and lit != 'rol':
                    canon = consts[(g, v - 0x100)]
                f.write('\t{ %d, %d, "%s", "%s" },\n' % (gi + 1, num, lit, canon))
        f.write('};\n')
    # the groups header of as64: the one of mkgrammar plus MG_EXT, last
    g = open(os.path.join(bd, 'pdp64-groups.h')).read()
    k = len(re.findall(r'^\tMG_\w+ = \d+,', g, flags=re.M))
    g = g.replace('};\n#define MG_COND', '\tMG_EXT = %d,\n};\n#define MG_COND' % (k + 1), 1)
    g = g.replace('\t} } while (0)', '\tcase %d: (out) = (m)->mn_ext; break; \\\n\t} } while (0)' % (k + 1), 1)
    open(os.path.join(bd, 'x', 'pdp64-groups.h'), 'w').write(g)
    sys.exit(bad)


if __name__ == '__main__':
    main()
