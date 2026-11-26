#!/usr/bin/env python3
"""
mkenc -- the generator of the prefix-coded encodings.  The single source of truth of an encoding is its hbnf grammar, the parts of the drop-in directory

    spec/grammars.d/NN-name.hbnf     the parts (tools/grammars_d.py; spec/README.md): the vocabulary, the registers and hot tables (hand edited), the forms and leaves, the
                                     shapes, `insn` and the group mn-ext (GENERATED), and any part a person drops in for a family of instructions of their own

(errata 179, 180: a generator owns whole parts and never one a person edits).  tools/encgram.py reads the whole directory (hbnf has no generator for a table of leaves, so this is the
small generator that reads the grammar; it reads nothing else).  This writes

    build/pdp64-tab.c, build/pdp64-hbfields.h    the C tables of the codec (common/pdp64enc.c): forms, leaves, bit runs, mnemonics
    build/x/pdp64-extnames.h, pdp64-mnnames.h    the name tables of as64: the words of group mn-ext by number, every word of the hand-written groups by (group, number)
    spec/pdp64/tables.md                         the leaf tables for people (with --md)

(build/x/pdp64-groups.h is tools/mkgrammar.py's.  The assembly grammar of as64 is spec/pdp64-asm.hbnf over the parts; there is no copy of it to patch.)
It verifies each table as it reads it, independently of the optimiser: the prefixes form a prefix code (Kraft), every leaf covers all of its
16n bits exactly once, the words the leaves use that no hand-written group numbers are exactly the group mn-ext, and the 65,536 first parcels decode to at most one leaf each.

    tools/mkenc.py            generate into $BUILD (default build)
    tools/mkenc.py --md       also rewrite spec/pdp64/tables.md
    tools/mkenc.py --check    fail if spec/pdp64/tables.md is not what the forms tables say
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
sys.path.insert(0, HERE)
import encgram
DP = 255


def msize(mn, acc):
    """the size of the access of a mnemonic: the rules acc-N of 22-enc-vocabulary.hbnf; a suffix after a dot (.u .d .ud) does not change it; 1 for the others"""
    return acc.get(mn.split('.')[0], 1)


def load():
    return encgram.load(ROOT)


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


def gen_c(d):
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
        elif k == 'V':
            z.update(kind='ES_V', w=s['w'], kop=1 if s['cls'] == 't' else 0)	# kop: the class, 0 vector register, 1 tile register
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
        mrows.append('\t{ "%s", %d, %d, %d },' % (m, msize(m, d['acc']), len(crows), len(cs)))
        for _, fi, li, k in cs:
            crows.append('\t{ %d, %d, %d },' % (fi, li, k))
    out = []
    out.append('/* generated by tools/mkenc.py from spec/pdp64/pdp64.hbnf -- do not edit */')
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
    out.append('struct etab enc_tab = { "%s", %d, %d, %d, %d, %d, M, F, S, FS, FM, HOT, LF, P, R, C, 0 };' %
               (d['name'], d['registers'], len(mnames), len(forms), len(leaves), len(specs.items)))
    return '\n'.join(out) + '\n', mnames


# ---------------------------------------------------------------- the fields as hbnf's own decoder reads them
def gen_fields(d):
    """A C function over the record hbnf generates from the grammar (parse_bits, the decoder of the encoding): the raw value of every field of the leaf taken,
    by key (operand index * 16 + part index; 0xFE0 for the sub-opcode), the pieces of a split field put together.  tests/enc/hbdec.c compares these with what
    the codec's generated tables extract from the same bits: the tables (made by this program) against hbnf's reading of the grammar (made by hbnf)."""
    out = ['/* generated by tools/mkenc.py from spec/pdp64/pdp64.hbnf -- do not edit.  Include after the parser hbnf generates from the same grammar. */',
           'static int hb_fields(const insn_t *o, int *key, uint64_t *val)', '{', '	int n = 0;', '	switch (o->leaf.kind) {']
    forms, leaves = d['forms'], d['leaves']
    seen = {}
    for li, lf in enumerate(leaves):
        f = forms[lf['form']]
        k = seen[lf['form']] = seen.get(lf['form'], 0) + 1
        # hbnf spells the hyphens of the rule name as underscores (the mangled form name)
        lname = 'leaf_%s_%d' % (encgram.mangle(f['name']).replace('-', '_'), k)
        pcs = encgram.leaf_pieces(lf, f['specs'])
        if not pcs:
            # a leaf of no fields (vend): hbnf makes no record for it, and there is nothing to read
            out.append('	case %d: break;' % (li + 1))
            continue
        out.append('	case %d: { const %s_t *l = &o->leaf.u.a%d.%s;' % (li + 1, lname, li + 1, lname))
        keys = []
        for _, name, w, key in pcs:
            kk = 0xFE0 if key[0] in ('sub', 'xsub') else key[0] * 16 + key[1]
            if kk not in keys:
                keys.append(kk)
        for kk in keys:
            parts = [(name.replace('-', '_'), w) for _, name, w, key in pcs if (0xFE0 if key[0] in ('sub', 'xsub') else key[0] * 16 + key[1]) == kk]
            e = '(uint64_t)l->%s' % parts[0][0]
            for nm_, w in parts[1:]:
                e = '((%s << %d) | l->%s)' % (e, w, nm_)
            out.append('		key[n] = 0x%X; val[n++] = %s;' % (kk, e))
        out.append('		} break;')
    out += ['	default: return -1;', '	}', '	return n;', '}']
    return '\n'.join(out) + '\n'


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
    if k == 'V':
        return [s['cls']]
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


def gen_md(d):
    forms = d['forms']
    L = sorted(range(len(d['leaves'])), key=lambda i: (forms[d['leaves'][i]['form']]['n'], d['leaves'][i]['L'], i))
    o = ['# %s: the leaves of the encoding' % d['name'], '',
         'Generated by `tools/mkenc.py --md` from `spec/pdp64/pdp64.hbnf`; do not edit.  %d forms, %d leaves, %d registers.' % (len(forms), len(d['leaves']), d['registers']), '',
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


# ---------------------------------------------------------------- the words
def check_ext(allmn, ext_decl):
    """the group mn-ext (generated) must be the words the leaves use that no hand-written group numbers; returns the hand-written enums"""
    sys.path.insert(0, HERE)
    import mkgrammar
    en = mkgrammar.enums(ROOT)
    old = {lit for g, items in en.items() if g.startswith('mn-') for lit, v in items}
    need = {m for m in allmn if m not in old}
    ext = list(ext_decl)
    if set(ext) != need or len(set(ext)) != len(ext):
        sys.exit('mkenc: the rule mn-ext of spec/grammars.d/80-mn-ext.hbnf (run tools/encopt/addforms.py --grammar-out spec/grammars.d) is not the set of words the leaves use that no hand-written group mn-NAME numbers (a part that adds a form of its own has its words in its own group):\n  missing from mn-ext: %s\n  not used by a leaf: %s' % (
            ' '.join(sorted(need - set(ext))), ' '.join(sorted(set(ext) - need))))
    return en


def main():
    md = '--md' in sys.argv
    check = '--check' in sys.argv
    bd = os.path.join(ROOT, os.environ.get('BUILD', 'build'))
    os.makedirs(bd, exist_ok=True)
    allmn = set()
    bad = 0
    if True:
        d = load()
        ext_decl = d['ext']
        n = verify(d)
        c, mnames = gen_c(d)
        open(os.path.join(bd, 'pdp64-tab.c'), 'w').write(c)
        open(os.path.join(bd, 'pdp64-hbfields.h'), 'w').write(gen_fields(d))
        allmn |= set(mnames)
        text = gen_md(d)
        p = os.path.join(ROOT, 'spec', 'pdp64', 'tables.md')
        if md:
            open(p, 'w').write(text)
        elif check:
            if not os.path.exists(p) or open(p).read() != text:
                print('mkenc: %s is not what spec/pdp64/pdp64.hbnf says (run tools/mkenc.py --md)' % p); bad = 1
    en = check_ext(allmn, ext_decl)
    ext = list(ext_decl)
    os.makedirs(os.path.join(bd, 'x'), exist_ok=True)
    with open(os.path.join(bd, 'x', 'pdp64-extnames.h'), 'w') as f:
        f.write('/* generated by tools/mkenc.py -- do not edit.  The words of group mn-ext, by number. */\nstatic const char *const ext_names[] = {\n')
        for m in ext:
            f.write('\t"%s",\n' % m)
        f.write('};\n#define N_EXT_NAMES %d\n' % len(ext))
        f.write('/* the aliases: the word, and the number of the word it stands for (it is numbered 0x1000 plus that) */\nstatic const struct { const char *name; int target; } ext_alias[] = {\n')
        for a, t in d['ext_alias']:
            f.write('\t{ "%s", %d },\n' % (a, t))
        f.write('\t{ 0, 0 }\n};\n')
    # the names of the mnemonics by (group, number), with the word an alias stands for: for the assembler's canonical instruction
    sys.path.insert(0, HERE)
    import mkgrammar
    order = mkgrammar.group_order(ROOT)
    with open(os.path.join(bd, 'x', 'pdp64-mnnames.h'), 'w') as f:
        f.write('/* generated by tools/mkenc.py -- do not edit.  Every word of the mnemonic groups: group (MG_*), number, the word, the word of the encoding it stands for. */\n'
                'struct mnname { short mg, num; const char *name, *canon; };\nstatic const struct mnname mnnames[] = {\n')
        consts = {}
        for rule, items in en.items():
            for lit, v in items:
                consts[(rule, v)] = lit
        for gi, g in enumerate(order):
            if g not in en:
                continue                       # a generated group (mn-ext): its names are in pdp64-extnames.h
            items = en[g]
            for lit, v in items:
                num = v
                if len(items) == 1:
                    num = {'mn-lea': 11, 'mn-sob': 63}.get(g, 0)
                canon = lit
                if v >= 0x100:
                    canon = consts[(g, v - 0x100)]
                f.write('\t{ %d, %d, "%s", "%s" },\n' % (gi + 1, num, lit, canon))
        f.write('};\n')
    sys.exit(bad)


if __name__ == '__main__':
    main()
