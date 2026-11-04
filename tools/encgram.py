#!/usr/bin/env python3
"""
encgram -- reads the hbnf grammars of the prefix-coded encodings (spec/pdp64-enc.hbnf, spec/pdp64-NN/pdp64-NN.hbnf) and returns the forms and the
leaves of an encoding as a plain dict.  The grammars are the source of truth; this is how the generators and the checks read them.

    import encgram; d = encgram.load('16')       # or '32'

The dict has the shape tools/mkenc.py and the checks have always worked on:

    name, registers, hot8 (the 3-bit hot-register table, register numbers), hot16 (the 4-bit one or None), fused,
    forms  = [ { name, n (parcels), mns, xbits, specs } ],            specs: R K I B X PI PD PC A, see below
    leaves = [ { form, off, j, L, prefix, mns, subbits, place } ],    place: [ [operand index (-1: the extended sub-opcode), part index, [bit, ...]], ... ]
    plus   ext (the numbered words of group mn-ext), acc (size of access by mnemonic stem), regnames, source (the files read)

A bit is 16*parcel + bit (15 the top of the parcel); the bits of a field are listed from its top bit down.  The vocabulary of the grammars (leaf-, sub-, form-,
shape names, field names oI-PART[-N], sub, xsub) is documented in the header of spec/pdp64-enc.hbnf.  hbnf itself checks the syntax and the references
(tools/check-encgram.sh generates a parser from each grammar); this reads the meaning, and checks everything that it can check on the way: every leaf covers its
16*n bits once, every field has the width its shape says, the mnemonic counts fit the sub-opcode bits, the index of the catalogue is dense, `insn` lists the leaves.

It reads the subset of hbnf the grammars use: rules in column 1 (continuation lines indented), `;` comments, `include`, literals, `|`, bit fields.
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')


class GrammarError(Exception):
    pass


def guard_text(name, widths, n):
    """the check that rejects the unused numbers of a sub-opcode: `?(sub < 5)`; for a field the layout splits in pieces (sub-1, sub-2, ...) the value is put together: `?(((sub_1 << 3) | sub_2) < 5)`
    (an hbnf expression names a hyphenated field with an underscore)"""
    if len(widths) == 1:
        return '?(%s < %d)' % (name, n)
    e = '%s_1' % name
    for i, w in enumerate(widths[1:], 2):
        e = '((%s << %d) | %s_%d)' % (e, w, name, i)
    return '?(%s < %d)' % (e, n)


def mangle(name):
    return re.sub(r'[./_]', '-', name)


def strip_comment(line):
    out, q = [], False
    for ch in line:
        if ch == '"':
            q = not q
        if ch == ';' and not q:
            break
        out.append(ch)
    return ''.join(out).rstrip()


def read_rules(path, rules=None, files=None):
    """{rule name: (body text, file, line)}, following `include`."""
    rules = {} if rules is None else rules
    files = [] if files is None else files
    path = os.path.normpath(path)
    files.append(path)
    cur = None
    for ln, raw in enumerate(open(path).read().split('\n'), 1):
        line = strip_comment(raw)
        if not line.strip():
            continue
        m = re.match(r'^include\s+"([^"]+)"\s*$', line)
        if m:
            read_rules(os.path.join(os.path.dirname(path), m.group(1)), rules, files)
            cur = None
            continue
        if re.match(r'^prefix\s', line):
            cur = None
            continue
        m = re.match(r'^([A-Za-z][\w-]*)\s*=(?!/)\s*(.*)$', line)
        if m and not line[0].isspace():
            cur = m.group(1)
            if cur in rules:
                raise GrammarError('%s:%d: rule %s is defined twice' % (path, ln, cur))
            rules[cur] = [m.group(2), path, ln]
        elif line[0].isspace() and cur:
            rules[cur][0] += ' ' + line.strip()
        else:
            raise GrammarError('%s:%d: cannot read this line: %s' % (path, ln, line))
    return {k: tuple(v) for k, v in rules.items()}, files


def literals(body):
    """['a', 'b'] from  "a" | "b"  ; with @N numbers: [('a', N-or-None)]."""
    out = []
    for part in re.split(r'\s*\|\s*', body.strip()):
        m = re.match(r'^"([^"]*)"(?:@(0[xbo][0-9A-Fa-f]+|\d+))?$', part)
        if not m:
            raise GrammarError('not a list of literals: %s' % part)
        out.append((m.group(1), int(m.group(2), 0) if m.group(2) else None))
    return out


def numbered(body):
    """the literals of an enum with the values hbnf gives them (the one before plus 1)"""
    out, nxt = [], 0
    for lit, v in literals(body):
        if v is not None:
            nxt = v
        out.append((lit, nxt))
        nxt += 1
    return out


def regnumbers(words, aliases):
    out = []
    for w in words:
        if re.match(r'^r\d+$', w):
            out.append(int(w[1:]))
        elif w in aliases:
            out.append(aliases[w])
        else:
            raise GrammarError('unknown register %s' % w)
    return out


# ---------------------------------------------------------------- shapes
def parse_fields(body):
    """'base:4 d:28s' -> [('base', 4, False), ('d', 28, True)];  'none:bits(0)' / 'sp:bits(0)' -> []"""
    out = []
    for t in body.split():
        if re.match(r'^\w+:bits\(0\)$', t):
            continue
        m = re.match(r'^([a-z]+):(\d+)(s?)$', t)
        if not m:
            raise GrammarError('not a field: %s' % t)
        out.append((m.group(1), int(m.group(2)), bool(m.group(3))))
    return out


def reg_spec(w, nreg, hot):
    full = (1 << w) >= nreg
    if full:
        return {'k': 'R', 'w': w, 'table': None}
    if w not in hot or len(hot[w]) != 1 << w:
        raise GrammarError('a register field of %d bits needs a table hot%d of %d registers' % (w, w, 1 << w))
    return {'k': 'R', 'w': w, 'table': list(hot[w])}


def shape_spec(name, body, nreg, hot):
    """the spec dict of the shape `name` (the meaning of the name is in the header of spec/pdp64-enc.hbnf), checked against the fields of `body`"""
    fl = parse_fields(body)
    def expect(*want):
        if [(n, w) for n, w, _ in fl] != [(n, w) for n, w, _ in want] or [s for _, _, s in fl] != [s for _, _, s in want]:
            raise GrammarError('shape %s: the fields are `%s`, its name says %s' % (name, body, want))
    sg = lambda c: c == 's'
    m = re.match(r'^reg(\d+)$', name)
    if m:
        w = int(m.group(1)); expect(('r', w, False)); return reg_spec(w, nreg, hot)
    if name == 'k-sp': return {'k': 'K', 'op': ['R', 14]}
    if name == 'k-dp': return {'k': 'K', 'op': ['R', 16]}
    m = re.match(r'^k-imm(\d+)$', name)
    if m: return {'k': 'K', 'op': ['I', int(m.group(1))]}
    m = re.match(r'^k-r(\d+)$', name)
    if m: return {'k': 'K', 'op': ['R', int(m.group(1))]}
    m = re.match(r'^imm(\d+)([su])(?:-x(\d+))?$', name)
    if m:
        w = int(m.group(1)); expect(('imm', w, sg(m.group(2))))
        return {'k': 'I', 'w': w, 'signed': sg(m.group(2)), 'scale': int(m.group(3) or 1), 'vals': None}
    m = re.match(r'^(?:b(\d+)|(sp|dp))d(\d+)([su])-x(\d+|sz)$', name)
    if m:
        dw, signed = int(m.group(3)), sg(m.group(4))
        scale = m.group(5) if m.group(5) == 'sz' else int(m.group(5))
        want = ([('base', int(m.group(1)), False)] if m.group(1) else []) + ([('d', dw, signed)] if dw else [])
        if not want and not fl: pass
        else: expect(*want)
        rn = reg_spec(int(m.group(1)), nreg, hot) if m.group(1) else {'k': 'K', 'op': ['R', 14 if m.group(2) == 'sp' else 16]}
        return {'k': 'B', 'rn': rn, 'dw': dw, 'signed': signed, 'scale': scale}
    m = re.match(r'^x(\d+)-(\d+)d(\d+)([su])$', name)
    if m:
        a, b, dw, signed = int(m.group(1)), int(m.group(2)), int(m.group(3)), sg(m.group(4))
        expect(*([('base', a, False), ('index', b, False), ('scale', 2, False)] + ([('d', dw, signed)] if dw else [])))
        return {'k': 'X', 'rn': reg_spec(a, nreg, hot), 'rx': reg_spec(b, nreg, hot), 'dw': dw, 'signed': signed}
    m = re.match(r'^(pi|pd)(\d+)-s(\d+)$', name)
    if m:
        rw, dw = int(m.group(2)), int(m.group(3))
        expect(*([('base', rw, False)] + ([('stride', dw, False)] if dw else [])))
        return {'k': m.group(1).upper(), 'rn': reg_spec(rw, nreg, hot), 'dw': dw}
    m = re.match(r'^pc(\d+)-u(\d+)$', name)
    if m:
        expect(('pcrel', int(m.group(1)), False)); return {'k': 'PC', 'w': int(m.group(1)), 'unit': int(m.group(2))}
    m = re.match(r'^abs(\d+)$', name)
    if m:
        expect(('abs', int(m.group(1)), False)); return {'k': 'A', 'w': int(m.group(1))}
    raise GrammarError('unknown operand shape %s' % name)


def part_list(spec):
    """(name, width) of the parts of an operand, in the order of the place indices"""
    k = spec['k']
    if k == 'R': return [('r', spec['w'])]
    if k == 'K': return []
    if k == 'I': return [('imm', spec['w'])]
    if k == 'B': return ([('base', spec['rn']['w'])] if spec['rn']['k'] == 'R' else []) + ([('d', spec['dw'])] if spec['dw'] else [])
    if k == 'X': return [('base', spec['rn']['w']), ('index', spec['rx']['w']), ('scale', 2)] + ([('d', spec['dw'])] if spec['dw'] else [])
    if k in ('PI', 'PD'): return [('base', spec['rn']['w'])] + ([('stride', spec['dw'])] if spec['dw'] else [])
    if k == 'PC': return [('pcrel', spec['w'])]
    if k == 'A': return [('abs', spec['w'])]
    raise GrammarError(k)


# ---------------------------------------------------------------- the loader
def spec_dir(root=None):
    return os.path.join(root or ROOT, 'spec')


def load(tag, root=None):
    import mkgrammar
    sd = spec_dir(root)
    path = os.path.join(sd, 'pdp64-' + tag, 'pdp64-%s.hbnf' % tag)
    rules, files = read_rules(path)
    aliases = {lit: v for lit, v in numbered(read_rules(os.path.join(sd, 'pdp64-mnemonics.hbnf'))[0]['ralias'][0])}
    g = lambda n: rules[n][0] if n in rules else (_ for _ in ()).throw(GrammarError('%s: no rule %s' % (path, n)))
    name = literals(g('encoding-name'))[0][0]
    regs = numbered(g('regs'))
    nreg = len(regs)
    if [v for _, v in regs] != list(range(nreg)) or [l for l, _ in regs] != ['r%d' % i for i in range(nreg)]:
        raise GrammarError('regs must be r0..r%d numbered 0..%d' % (nreg - 1, nreg - 1))
    hot = {}
    for w in (3, 4, 5):
        if 'hot%d' % w in rules:
            hot[w] = regnumbers([l for l, _ in numbered(g('hot%d' % w))], aliases)
    fused = [l for l, _ in literals(g('fused'))]
    cat = numbered(g('forms'))
    if [v for _, v in cat] != list(range(len(cat))):
        raise GrammarError('the numbers of the catalogue `forms` must be 0, 1, 2 ... in order')
    fnames = [l for l, _ in cat]
    mang = {}
    for i, fnm in enumerate(fnames):
        mg = mangle(fnm)
        if mg.lower() in mang:
            raise GrammarError('forms %s and %s have the same rule name' % (fnm, fnames[mang[mg.lower()]]))
        mang[mg.lower()] = i
    # shapes used: every rule that is not one of ours
    shapes = {}
    def shape(nm):
        if nm not in shapes:
            if nm not in rules:
                raise GrammarError('no operand shape %s' % nm)
            shapes[nm] = shape_spec(nm, rules[nm][0], nreg, hot)
        return shapes[nm]
    forms, leaves = [], []
    leafrules = {}            # form index -> [(k, rulename)]
    for rn in rules:
        m = re.match(r'^leaf-(.+)-(\d+)$', rn)
        if m:
            fi = mang.get(m.group(1).lower())
            if fi is None:
                raise GrammarError('%s: no form %s in the catalogue' % (rn, m.group(1)))
            leafrules.setdefault(fi, []).append((int(m.group(2)), rn))
    for rn in rules:
        if rn.startswith('form-') and mang.get(rn[5:].lower()) is None:
            raise GrammarError('%s is not in the catalogue `forms`' % rn)
    insn_order = []
    for fi, fnm in enumerate(fnames):
        fr = 'form-' + mangle(fnm)
        if fr not in rules:
            raise GrammarError('no rule %s for the form %s' % (fr, fnm))
        body = rules[fr][0].strip()
        if body == 'noop':
            specs = []
        else:
            specs = []
            for k, t in enumerate(body.split(), 1):
                mm = re.match(r'^o(\d+):([\w-]+)$', t)
                if not mm or int(mm.group(1)) != k:
                    raise GrammarError('%s: operand %d must be `o%d:shape`' % (fr, k, k))
                specs.append(shape(mm.group(2)))
        lrs = sorted(leafrules.get(fi, []))
        if [k for k, _ in lrs] != list(range(1, len(lrs) + 1)) or not lrs:
            raise GrammarError('%s: the leaves must be numbered 1, 2, ...' % fr)
        form = dict(name=fnm, n=None, mns=[], xbits=0, specs=specs)
        off = 0
        for k, lr in lrs:
            lf = parse_leaf(lr, rules, mangle(fnm), k, specs, fi, off, form)
            off += len(lf['mns'])
            form['mns'] += lf['mns']
            leaves.append(lf)
            insn_order.append(lr)
        forms.append(form)
    mi = re.match(r'^leaf:\(\s*(.*?)\s*\)$', g('insn'))
    if not mi:
        raise GrammarError('`insn` must be  leaf:( leaf-A | leaf-B | ... )')
    listed = [x.strip() for x in mi.group(1).split('|')]
    if listed != insn_order:
        raise GrammarError('`insn` must list every leaf, in the order of the catalogue and the numbers (%d listed, %d leaves); first difference: %s' % (
            len(listed), len(insn_order), next(((a, b) for a, b in zip(listed, insn_order) if a != b), None)))
    # the shared grammar
    shared = os.path.join(sd, 'pdp64-enc.hbnf')
    acc = {}
    for sz in (8, 4, 2, 1):
        for lit, _ in literals(rules['acc-%d' % sz][0]):
            acc[lit] = sz
    ext = [(l, v) for l, v in numbered(rules['mn-ext'][0])]
    if [v for _, v in ext] != list(range(len(ext))):
        raise GrammarError('the numbers of mn-ext must be 0, 1, 2 ... in order')
    return dict(name=name, registers=nreg, hot8=hot.get(3), hot16=hot.get(4), fused=fused, forms=forms, leaves=leaves,
                ext=[l for l, _ in ext], acc=acc, regnames=[l for l, _ in regs], source=files)


def parse_leaf(rn, rules, mname, k, specs, fi, off, form):
    body, path, ln = rules[rn]
    gi = body.find('?(')
    toks = body[:gi].split() + [body[gi:].strip()] if gi >= 0 else body.split()
    m = re.match(r'^0b([01]+)$', toks[0])
    if not m:
        raise GrammarError('%s: a leaf starts with its prefix, a binary constant' % rn)
    L = len(m.group(1))
    if not 1 <= L <= 16:
        raise GrammarError('%s: the prefix has %d bits' % (rn, L))
    prefix = int(m.group(1), 2)
    pos = L
    sub, xsub, ops = [], [], {}
    widths = {}
    guard = None
    pieces = []
    for t in toks[1:]:
        if t.startswith('?('):
            guard = t
            continue
        f = re.match(r'^([\w-]+):(\d+)$', t)
        if not f:
            raise GrammarError('%s: cannot read the field `%s`' % (rn, t))
        fname, w = f.group(1), int(f.group(2))
        recbits = [16 * (p // 16) + 15 - p % 16 for p in range(pos, pos + w)]
        pos += w
        mm = re.match(r'^(x?sub)(?:-(\d+))?$', fname)
        if mm:
            (xsub if mm.group(1) == 'xsub' else sub).extend(recbits)
            pieces.append((mm.group(1), mm.group(2), w))
            continue
        mm = re.match(r'^o(\d+)-([a-z]+)(?:-(\d+))?$', fname)
        if not mm:
            raise GrammarError('%s: unknown field name %s' % (rn, fname))
        oi = int(mm.group(1)) - 1
        if not 0 <= oi < len(specs):
            raise GrammarError('%s: field %s but the form has %d operands' % (rn, fname, len(specs)))
        parts = [p for p, _ in part_list(specs[oi])]
        if mm.group(2) not in parts:
            raise GrammarError('%s: operand %d has no part %s (it has %s)' % (rn, oi + 1, mm.group(2), ' '.join(parts)))
        key = (oi, parts.index(mm.group(2)))
        lst = ops.setdefault(key, [])
        want = 1 + len([1 for p in pieces if p[0] == key]) if mm.group(3) else None
        if mm.group(3) and int(mm.group(3)) != want:
            raise GrammarError('%s: the pieces of %s must be numbered 1, 2, ... from the top' % (rn, fname))
        if not mm.group(3) and lst:
            raise GrammarError('%s: field %s twice' % (rn, fname))
        lst.extend(recbits)
        pieces.append((key, mm.group(3), w))
    if pos != 16 * (-(-pos // 16)):
        raise GrammarError('%s: the fields cover %d bits, not a whole number of parcels' % (rn, pos))
    n = pos // 16
    if form['n'] is None:
        form['n'] = n
    elif form['n'] != n:
        raise GrammarError('%s: %d parcels, but the other leaves of the form have %d' % (rn, n, form['n']))
    # each part has the width its shape says
    for oi, spec in enumerate(specs):
        for pi, (pname, pw) in enumerate(part_list(spec)):
            got = len(ops.get((oi, pi), []))
            if got != pw:
                raise GrammarError('%s: operand %d part %s has %d bits, its shape says %d' % (rn, oi + 1, pname, got, pw))
    for key in ops:
        if key[1] >= len(part_list(specs[key[0]])):
            raise GrammarError('%s: a field of no part' % rn)
    se = 'sub-%s-%d' % (mname, k)
    if se not in rules:
        raise GrammarError('no rule %s (the mnemonics of %s)' % (se, rn))
    mns = [l for l, _ in literals(rules[se][0])]
    if sub and xsub:
        raise GrammarError('%s: sub and xsub' % rn)
    nb = len(sub) or len(xsub)
    if len(mns) > (1 << nb) if nb else len(mns) > 1:
        raise GrammarError('%s: %d mnemonics do not fit %d sub-opcode bits' % (rn, len(mns), nb))
    exp = None
    if nb and len(mns) < (1 << nb):
        sw = [w for (nm_, _, w) in pieces if nm_ == ('sub' if sub else 'xsub')]
        exp = guard_text('sub' if sub else 'xsub', sw, len(mns))
    if exp != guard:
        raise GrammarError('%s: the guard must be %s' % (rn, exp or 'absent'))
    if xsub:
        if off != 0:
            raise GrammarError('%s: an xsub leaf must be the first of its form' % rn)
        form['xbits'] = len(xsub)
    place = [[oi, pi, bits] for (oi, pi), bits in sorted(ops.items())]
    if xsub:
        place.insert(0, [-1, 0, xsub])
    return dict(form=fi, off=off, j=len(sub), L=L, prefix=prefix, mns=mns, subbits=sub, place=place)


def runs(bits):
    """the bits of a field (16*parcel+bit, bit 15 the top of its parcel), from the top bit of its value down -> record positions (the instruction read from the
    top bit of parcel 0), merged into maximal runs of consecutive positions: [[first position, length]].  The bits of a field are in record order."""
    pos = [16 * (b // 16) + 15 - (b % 16) for b in bits]
    if pos != sorted(pos):
        raise GrammarError('the bits of a field are not in record order')
    out = []
    for p in pos:
        if out and out[-1][0] + out[-1][1] == p:
            out[-1][1] += 1
        else:
            out.append([p, 1])
    return out


def leaf_pieces(lf, specs):
    """The fields of a leaf after its prefix, in record order: [(position, field name, width, key)], key = ('sub',), ('xsub',) or (operand index, part index).
    A field the layout splits is several pieces, `name-1`, `name-2`, ... from the top."""
    items = []
    def add(name, bits, key):
        rr = runs(bits)
        for ri, (p, ln) in enumerate(rr):
            items.append((p, name if len(rr) == 1 else '%s-%d' % (name, ri + 1), ln, key))
    if lf['subbits']:
        add('sub', lf['subbits'], ('sub',))
    for oi, pi, bits in lf['place']:
        if oi == -1:
            add('xsub', bits, ('xsub',))
        else:
            add('o%d-%s' % (oi + 1, part_list(specs[oi])[pi][0]), bits, (oi, pi))
    return sorted(items)


def free_patterns(d):
    """first parcels that no leaf decodes (the illegal ones)"""
    used = 0
    for lf in d['leaves']:
        used += 1 << (16 - lf['L'])
    return 65536 - used


if __name__ == '__main__':
    sys.path.insert(0, HERE)
    import json
    d = load(sys.argv[1])
    print(json.dumps({k: v for k, v in d.items() if k not in ('forms', 'leaves')}), len(d['forms']), 'forms', len(d['leaves']), 'leaves')
