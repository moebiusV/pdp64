#!/usr/bin/env python3
"""
check-enc -- the C codec (common/pdp64enc.c, with the tables generated from spec/pdp64-NN/pdp64-NN.hbnf) against the Python model of the encoding
(docs/codegen-data/encoding/enc.py, the code that produced and verified the tables).  For each of pdp64/16 and pdp64/32:

  1. the model, given only the forms of the grammar, lays out the same prefixes and bit positions as the table says (the table is what the model computes);
  2. a vector for every mnemonic of every form: the boundaries of every operand field (minimum, maximum, 0, +-1, a few random combinations) and, for
     the PC-relative and absolute fields, an unresolved external (a relocation);
  3. for each vector, the model chooses the form (the shortest that fits, in table order) and encodes; the C codec must produce the same parcels,
     or both must find no form; decoding those parcels in C must give the model's decoding, and that must be the vector itself.
"""
import collections, json, os, random, subprocess, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import encgram
sys.path.insert(0, os.path.join(ROOT, 'docs', 'codegen-data', 'encoding'))
sys.dont_write_bytecode = True
import enc
from enc import *

B = os.path.join(ROOT, os.environ.get('BUILD', 'build'))
DPC = 255


def mkspec(s):
    k = s['k']
    if k == 'R': return SR(s['w'], tuple(s['table']) if s['table'] is not None else None)
    if k == 'K': return SK(tuple(s['op']))
    if k == 'I': return SI(s['w'], s['signed'], s['scale'], s['vals'])
    if k == 'B': return SB(mkspec(s['rn']), s['dw'], s['signed'], s['scale'])
    if k == 'X': return SX(mkspec(s['rn']), mkspec(s['rx']), s['dw'], s['signed'])
    if k in ('PI', 'PD'): return SP(k, mkspec(s['rn']), s['dw'])
    if k == 'PC': return SPC(s['w'], s['unit'])
    if k == 'A': return SA(s['w'])
    raise ValueError(k)


def svals(sp, mn, rnd):
    if isinstance(sp, SR):
        regs = sorted(sp.table) if sp.table else list(range(1 << sp.w))
        pick = {regs[0], regs[-1], regs[len(regs) // 2]}
        if sp.table: pick |= {sp.table[0], sp.table[-1]}
        return [('R', r) for r in sorted(pick)]
    if isinstance(sp, SK): return [sp.op]
    if isinstance(sp, SI):
        sc = sp.scale
        lo, hi = (-(1 << (sp.w - 1)), (1 << (sp.w - 1)) - 1) if sp.signed else (0, (1 << sp.w) - 1)
        return [('I', x * sc) for x in sorted(x for x in {lo, hi, 0, 1, -1} if lo <= x <= hi)]
    if isinstance(sp, SB):
        rs = svals(sp.rn, mn, rnd) if not isinstance(sp.rn, SK) else [sp.rn.op]
        if sp.dw == 0: ds = [0]
        else:
            sc = sp._sc(mn)
            lo, hi = (-(1 << (sp.dw - 1)), (1 << (sp.dw - 1)) - 1) if sp.signed else (0, (1 << sp.dw) - 1)
            ds = sorted({x * sc for x in (lo, hi, 0, 1) if lo <= x <= hi})
        return [('B', d, r[1]) for r in rs[:2] + rs[-1:] for d in ds]
    if isinstance(sp, SX):
        rs = svals(sp.rn, mn, rnd); xs = svals(sp.rx, mn, rnd); ds = [0]
        if sp.dw:
            lo, hi = (-(1 << (sp.dw - 1)), (1 << (sp.dw - 1)) - 1) if sp.signed else (0, (1 << sp.dw) - 1)
            ds = sorted({lo, hi, 0})
        return [('X', d, r[1], x[1], s) for r in (rs[0], rs[-1]) for x in (xs[0], xs[-1]) for d in ds for s in (1, 2, 4, 8)]
    if isinstance(sp, SP):
        rs = svals(sp.rn, mn, rnd)
        return [(sp.kind_, r[1], d) for r in (rs[0], rs[-1]) for d in (0, (1 << sp.dw) - 1)]
    if isinstance(sp, SPC):
        lo, hi = -(1 << (sp.w - 1)), (1 << (sp.w - 1)) - 1
        v = [('PC', x * sp.unit) for x in (lo, hi, 0, 1, -1)]
        return v + [('PC', None)]
    if isinstance(sp, SA):
        lo, hi = -(1 << (sp.w - 1)), (1 << (sp.w - 1)) - 1
        return [('A', x) for x in (lo, hi, 0, 1)] + [('A', None)]
    raise TypeError(sp)


def tok(o):
    k = o[0]
    if k == 'R': return 'R:%d' % o[1]
    if k == 'I': return 'I:%d' % o[1]
    if k == 'B': return 'B:%d:%d' % (o[1], DPC if o[2] == 16 and False else o[2])
    if k == 'X': return 'X:%d:%d:%d:%d' % o[1:]
    if k in ('PI', 'PD'): return '%s:%d:%d' % (k, o[1], o[2])
    if k == 'PC': return 'PC:0:E' if o[1] is None else 'PC:%d' % o[1]
    if k == 'A': return 'A:0:E' if o[1] is None else 'A:%d' % o[1]


def run(tag):
    d = encgram.load(tag, ROOT)
    enc.RELOC = 'max'
    forms = []
    dpforms = set()
    for f in d['forms']:
        forms.append(Form(f['name'], f['n'], f['mns'], [mkspec(s) for s in f['specs']], xbits=f['xbits']))
    code = Code(forms)
    # 1. the table is what the model computes
    assert len(code.leaves) == len(d['leaves'])
    for lf, jl in zip(code.leaves, d['leaves']):
        assert lf.prefix == jl['prefix'] and lf.L == jl['L'] and lf.off == jl['off'] and lf.mns == jl['mns'], (lf.form.name, jl)
        assert [(oi, pi, bits) for (oi, pi), bits in sorted(lf.place.items())] == [tuple(x) for x in jl['place']], lf.form.name
        assert lf.subbits == jl['subbits']
    by_mn = collections.defaultdict(list)
    for i, f in enumerate(forms):
        for m in f.mns: by_mn[m].append((f.n, i, f))
    for m in by_mn: by_mn[m].sort(key=lambda x: (x[0], x[1]))

    def choose(mn, ops):
        for n, i, f in by_mn.get(mn, ()):
            v = f.fit(mn, ops)
            if v is not None: return f, v
        return None
    rnd = random.Random(7)
    vecs = []
    for f in forms:
        for mn in f.mns:
            lists = [svals(sp, mn, rnd) for sp in f.specs]
            base = [l[0] for l in lists]
            combos = [tuple(base)]
            for i, l in enumerate(lists):
                for v in l:
                    c = list(base); c[i] = v; combos.append(tuple(c))
            for _ in range(10): combos.append(tuple(rnd.choice(l) for l in lists))
            for c in set(combos): vecs.append((mn, c))
    # DP: the model writes the base of d(DP) as register 16; the C codec as 255
    def cop(o):
        if o[0] == 'B' and o[2] == 16 and tag == '16' and False: return o
        return o
    inp = []
    exp = []
    nenc = 0
    for mn, ops in vecs:
        r = choose(mn, ops)
        isdp = any(o[0] == 'B' and o[2] == 16 for o in ops) and any(isinstance(sp, SB) and isinstance(sp.rn, SK) for f in forms for sp in f.specs)
        cops = tuple(('B', o[1], DPC) if (o[0] == 'B' and o[2] == 16 and isdp and r is not None and any(isinstance(sp, SB) and isinstance(sp.rn, SK) for sp in r[0].specs)) else o for o in ops)
        inp.append(mn + ''.join(' ' + tok(o) for o in cops))
        if r is None:
            exp.append('NOENC'); continue
        f, vals = r
        lf = next(l for l in code.leaves if l.form is f and mn in l.mns)
        w = build_word(lf, mn, vals); par = words_of(w, f.n)
        dm = decode_word(code, par)
        assert dm is not None and dm[0] == mn
        dops = tuple(('PC', None) if False else o for o in dm[1])
        # the decoded form of the vector: externals decode as 0
        def norm(o, orig):
            if o[0] == 'PC': return ('PC', o[1])
            return o
        want = tuple(('PC', 0) if (o[0] == 'PC' and o[1] is None) else ('A', 0) if (o[0] == 'A' and o[1] is None) else o for o in ops)
        got = tuple(norm(o, None) for o in dm[1])
        # the model's decode: for the ordinary vector it must be the vector (after the external -> 0 mapping)
        assert got == want, (mn, ops, got, want)
        nenc += 1
        dec = mn + ''.join(' ' + tok(o) for o in dm[1])
        dec = dec.replace(':16 ', ':%d ' % DPC) if False else dec
        exp.append('%d %s| %s' % (f.n, ''.join('%04x ' % x for x in par), dec))
    out = subprocess.run([os.path.join(B, 'encdrv'), tag], input='\n'.join(inp) + '\n', capture_output=True, text=True).stdout.split('\n')
    bad = 0
    for i, (a, b) in enumerate(zip(exp, out)):
        # DP base: the model says 16, the codec 255
        b2 = b
        if a != b2 and ':255' in b2 and ':16' in a:
            b2 = b2.replace(':255', ':16')
        if a != b2:
            bad += 1
            if bad <= 5: print('MISMATCH', inp[i], '\n  model', a, '\n  codec', b)
    # 3b. the decoder alone: every 1-parcel pattern whose length is 1, and a sample of the others, against the model
    nd = 0
    pats = []
    for p0 in range(65536):
        lf = code.table[p0]
        if lf is None: pats.append(('%04x' % p0, None)); continue
        n = lf.form.n
        if n == 1 or p0 % 11 == 0:
            ps = [p0] + [rnd.randrange(65536) for _ in range(n - 1)]
            pats.append((' '.join('%04x' % x for x in ps), ps))
    out = subprocess.run([os.path.join(B, 'encdrv'), '-d', tag], input='\n'.join(p for p, _ in pats) + '\n', capture_output=True, text=True).stdout.split('\n')
    bad_d = 0
    for (txt, ps), got in zip(pats, out):
        nd += 1
        if ps is None:
            ok = got == 'ILLEGAL'
        else:
            dm = decode_word(code, ps)
            if dm is None: ok = got == 'ILLEGAL'
            else:
                want = '%d %s' % (dm[2], dm[0] + ''.join(' ' + tok(o) for o in dm[1]))
                ok = got == want or got.replace(':255', ':16') == want
        if not ok:
            bad_d += 1
            if bad_d <= 5: print('DECODE MISMATCH', txt, got)
    # 4. the hand-checked format vectors (tests/enc/vectors-NN.txt, from the prototype): the same parcels, and the instruction back
    vl = [l.rstrip('\n') for l in open(os.path.join(ROOT, 'tests', 'enc', 'vectors-%s.txt' % tag)) if l.strip() and not l.startswith('#')]
    out = subprocess.run([os.path.join(B, 'encdrv'), tag], input='\n'.join(l.split(' | ')[0] for l in vl) + '\n', capture_output=True, text=True).stdout.split('\n')
    bad_v = 0
    for l, got in zip(vl, out):
        ins, want = l.split(' | ')
        back = ins.replace(':E', '')
        back = ' '.join(('PC:0' if t.startswith('PC:') and t.endswith(':E') else 'A:0' if t.startswith('A:') and t.endswith(':E') else t) for t in ins.split())
        g_par, _, g_ins = got.partition(' | ')
        if g_par.strip() != want.strip() or g_ins != back:
            bad_v += 1; print('VECTOR', ins, 'wanted', want, 'got', got)
    print('pdp64/%s: %d forms, %d leaves laid out as the model does; %d vectors (%d encodable), %d mismatches; %d decoder patterns, %d mismatches' %
          (tag, len(forms), len(code.leaves), len(vecs), nenc, bad, nd, bad_d))
    print('pdp64/%s: %d format vectors, %d differ' % (tag, len(vl), bad_v))
    return bad + bad_d + bad_v


if __name__ == '__main__':
    sys.exit(1 if (run('16') + run('32')) else 0)
