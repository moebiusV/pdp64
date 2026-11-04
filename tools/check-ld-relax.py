#!/usr/bin/env python3
"""check-ld-relax -- the relaxed link of tests/ld-pdp64-NN (main.s + lib.s) against the Python model of the encoding (docs/codegen-data/encoding/enc.py).
The model relaxes this five-instruction program by itself (every instruction from its shortest form, growing until each address fits, the data page after
the text) and encodes the result; ld64's words must be the same.   usage: check-ld-relax.py 16|32 linked.out"""
import json, os, struct, sys
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
sys.path.insert(0, os.path.join(ROOT, 'docs', 'codegen-data', 'encoding'))
sys.dont_write_bytecode = True
import enc
from enc import *
sys.path.insert(0, os.path.join(ROOT, 'tools'))
tag, path = sys.argv[1], sys.argv[2]
import encgram
d = encgram.load(tag, ROOT)
enc.RELOC = 'max'
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
forms = [Form(f['name'], f['n'], f['mns'], [mkspec(s) for s in f['specs']], xbits=f['xbits']) for f in d['forms']]
code = Code(forms)
def choose(mn, ops, minn):
    c = [(f.n, i, f) for i, f in enumerate(forms) if mn in f.mns and f.n >= minn]
    for n, i, f in sorted(c, key=lambda x: (x[0], x[1])):
        v = f.fit(mn, ops)
        if v is not None: return f, v
    return None
def words(mn, ops, minn):
    r = choose(mn, ops, minn)
    if r is None: return None
    f, v = r
    lf = next(l for l in code.leaves if l.form is f and mn in l.mns)
    return words_of(build_word(lf, mn, v), f.n)
TEXT = 0x10000
# main: movq #msg,r1 ; call f ; bne f ; movq val(pc),r2 ; halt     lib: f: ret      data: msg: .quad f ; val: .quad 42
prog = [('movq', lambda A, P: [('I', A['msg']), ('R', 1)]), ('call', lambda A, P: [('PC', A['f'] - P)]), ('bne', lambda A, P: [('PC', A['f'] - P)]),
        ('movq', lambda A, P: [('PC', A['val'] - P), ('R', 2)]), ('halt', lambda A, P: []), ('ret', lambda A, P: [])]
cur = [0] * len(prog)
A = {'msg': 0, 'f': 0, 'val': 0}
first = True
for _ in range(50):
    pos = []
    p = TEXT
    for i in range(len(prog)): pos.append(p); p += 2 * (cur[i] or 1)
    A['f'] = pos[5]
    data = (p + 4095) // 4096 * 4096
    A['msg'] = data; A['val'] = data + 8
    new = []
    for i, (mn, ops) in enumerate(prog):
        o = ops(A, pos[i]) if not first else ops({'msg': 0, 'f': 0, 'val': 0}, 0)
        w = words(mn, o, cur[i] or 0)
        new.append(len(w))
    first = False
    if new == cur: break
    cur = [max(a, b) for a, b in zip(cur, new)]
else: sys.exit('no fixed point')
want = []
for i, (mn, ops) in enumerate(prog): want += ['%04x' % x for x in words(mn, ops(A, pos[i]), cur[i])]
b = open(path, 'rb').read()
got = ['%04x' % struct.unpack_from('<H', b, 0x1000 + 2 * i)[0] for i in range(len(want))]
print(('ok   ' if got == want else 'DIFF ') + 'relaxed link pdp64/%s equals the model\'s own relaxation (%d bytes of text)' % (tag, 2 * len(want)))
if got != want: print('  got ', ' '.join(got)); print('  want', ' '.join(want))
sys.exit(got != want)
