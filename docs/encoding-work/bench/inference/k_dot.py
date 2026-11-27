#!/usr/bin/env python3
"""k_dot.py: the bfloat16 dot product (4096 elements, binary32 result) with the current words."""
import sys, numpy as np
from lib import *
N = 4096
r = rng(7)
a = r.standard_normal(N).astype(np.float32); b = r.standard_normal(N).astype(np.float32)
ha, hb = to_bf16(a), to_bf16(b)
ref = np.float64(from_bf16(ha).astype(np.float64) @ from_bf16(hb).astype(np.float64))
def prog(kern, call=True):
    body = ['\tlea\tXA,r0', '\tlea\tXB,r1', '\tmov\t#%d,r2' % (2 * N)]
    if call: body += ['\tcall\tkern']
    body += ['\tlea\tRES,r5', '\tmov\tr4,(r5)']
    L = frame(body, [], 'RES', 8)
    L += kern if call else []
    L += data('XA', ha) + data('XB', hb) + bss('RES', 8)
    return L
def check(out):
    v = np.frombuffer(out[:4], dtype=np.float32)[0]
    return abs(float(v) - ref) < 2e-3 * max(1, abs(ref)) + 1e-3 * np.sqrt(N), 'got %.6f ref %.6f' % (v, ref)
K = {}
# the shift of 16 makes integer lanes; the checker of as64 refuses to read them as floating point; the only retag the family has is vbsl (it takes the kind of its second source)
K['widen'] = """kern:
	clr	r4
	lea	(r0)(r2),r3
	vec	r0,r3
	vmov.l	v4,#0
	vmov.f	v5,#0
	vld.wu.l	v0,(r0)+
	vld.wu.l	v1,(r1)+
	vshl.l	v0,v0,#16
	vshl.l	v1,v1,#16
	vbsl	v0,v4,v5,v0
	vbsl	v1,v4,v5,v1
	vmul.f	v2,v0,v1
	vacc.f	r4,v2
	vend
	ret""".split('\n')
K['evenodd'] = """kern:
	clr	r4
	mov	#0xffff0000,r9
	lea	(r0)(r2),r3
	vec	r0,r3
	vmov.l	v8,#0
	vmov.f	v9,#0
	vld.l	v0,(r0)+
	vld.l	v1,(r1)+
	vshl.l	v2,v0,#16
	vshl.l	v3,v1,#16
	vand.l	v0,v0,r9
	vand.l	v1,v1,r9
	vbsl	v2,v8,v9,v2
	vbsl	v3,v8,v9,v3
	vbsl	v0,v8,v9,v0
	vbsl	v1,v8,v9,v1
	vmul.f	v2,v2,v3
	vfma.f	v2,v0,v1
	vacc.f	r4,v2
	vend
	ret""".split('\n')
if __name__ == '__main__':
    base = measure('none', prog([], False), None, lambda o: (True, ''))
    for name, k in K.items():
        res = measure(name, prog(k), None, check)
        for s, o in res.items():
            print('bf16dot %-8s strip %2d  m1 %6d  m2 %6d  vops %5d  strips %4d  %s %s' % (name, s, o.get('m1', -1) - base[s]['m1'], o.get('m2', -1) - base[s]['m2'], o.get('vops', 0), o.get('strips', 0), 'OK' if o['ok'] else 'FAIL', o['note']))
