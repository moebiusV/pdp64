#!/usr/bin/env python3
"""k_soft.py: softmax (three passes) and RMSNorm (two passes) over 1024 binary32 values with the current words; exp by a degree-5 polynomial."""
import numpy as np
from lib import *
N = 1024
r = rng(31)
x = (r.standard_normal(N) * 3).astype(np.float32)
# 2^f on [-0.5, 0.5], degree 5, Chebyshev interpolation, coefficients highest first
from numpy.polynomial import chebyshev as C
nodes = np.cos(np.pi * (np.arange(6) + 0.5) / 6) * 0.5
co = np.polyfit(nodes, 2.0 ** nodes, 5)
co32 = co.astype(np.float32)
def fi(v): return int(f32bits(np.float32(v)))
def s32(u): return u - (1 << 32) if u >= (1 << 31) else u
LOG2E = fi(1.4426950408889634); HALF = fi(0.5); LO = fi(-87.0)
poly = ''
poly += '\tvmov.f\tv3,r%d\n' % 20      # placeholder, replaced below
def exp_block(src='v0', fin=''):
    s = ''
    s += '\tvmax.f\tv0,v0,r10\n'                # clamp at -87
    s += '\tvmul.f\tv1,v0,r11\n'                # t = x log2e
    s += '\tvsub.f\tv2,v1,r12\n'                # t - 0.5
    s += '\tvcvt.f.l\tv2,v2\n'                  # n = trunc(t - 0.5)  (t <= 0: round to nearest, ties away)
    s += '\tvcvt.l.f\tv3,v2\n'                  # n as float
    s += '\tvsub.f\tv1,v1,v3\n'                 # f = t - n
    s += '\tvmov.f\tv4,r%d\n' % 20              # p = c5
    for k in range(1, 6):
        s += '\tvmov.f\tv5,r%d\n' % (20 + k)
        s += '\tvfma.f\tv5,v4,v1\n'             # v5 = c + p f
        s += '\tvmov.f\tv4,v5\n'
    s += '\tvadd.l\tv2,v2,#127\n'
    s += '\tvshl.l\tv2,v2,#23\n'
    s += '\tvbsl\tv2,v14,v15,v2\n'              # integer lanes -> float lanes
    s += '\tvmul.f\tv0,v4,v2\n'
    return s
# the Horner step through a move is wasteful: vfma.f v5 += v4*v1 with v5 = c; then the next step reads v5: swap roles v4/v5 each step instead of the vmov
def exp_block(first=''):
    s = '\tvmax.f\tv0,v0,r10\n\tvmul.f\tv1,v0,r11\n\tvsub.f\tv2,v1,r12\n\tvcvt.f.l\tv2,v2\n\tvcvt.l.f\tv3,v2\n\tvsub.f\tv1,v1,v3\n'
    cur, oth = 'v4', 'v5'
    s += '\tvmov.f\t%s,r20\n' % cur
    for k in range(1, 6):
        s += '\tvmov.f\t%s,r%d\n\tvfma.f\t%s,%s,v1\n' % (oth, 20 + k, oth, cur)
        cur, oth = oth, cur
    s += '\tvadd.l\tv2,v2,#127\n\tvshl.l\tv2,v2,#23\n\tvbsl\tv2,v14,v15,v2\n\tvmul.f\tv0,%s,v2\n' % cur
    return s
consts = ['\tmov\t#%d,r10' % s32(LO), '\tmov\t#%d,r11' % s32(LOG2E), '\tmov\t#%d,r12' % s32(HALF)] + ['\tmov\t#%d,r%d' % (s32(fi(c)), 20 + k) for k, c in enumerate(co32)]
SOFT = 'kern:\n' + '\n'.join(consts) + """
	mov	#-8388608,r4
	lea	(r0)(r2),r3
	vec	r0,r3
	vld.f	v0,(r0)+
	vmaxacc.f	r4,v0
	vend
	lea	XA,r0
	clr	r5
	lea	(r0)(r2),r3
	vec	r0,r3
	vmov.l	v14,#0
	vmov.f	v15,#0
	vld.f	v0,(r0)+
	vsub.f	v0,v0,r4
""" + exp_block() + """	vst.f	v0,(r1)+
	vacc.f	r5,v0
	vend
	mov	#0x3f800000,r6
	fdiv.f32	r5,r6
	lea	YY,r1
	lea	(r1)(r2),r3
	vec	r1,r3
	vld.f	v0,(r1)
	vmul.f	v0,v0,r6
	vst.f	v0,(r1)+
	vend
	ret"""
ex = np.exp((x - x.max()).astype(np.float64)); ref = (ex / ex.sum()).astype(np.float32)
L = frame(['\tlea\tXA,r0', '\tlea\tYY,r1', '\tmov\t#%d,r2' % (4 * N), '\tcall\tkern'], [], 'YY', 4 * N) + SOFT.split('\n') + data('XA', x) + bss('YY', 4 * N)
base = measure('none', frame(['\tnop'], [], 'YY', 4 * N) + data('XA', x) + bss('YY', 4 * N), None, lambda o: (True, ''))
def chk(o):
    y = np.frombuffer(o, dtype=np.float32)
    if len(y) != N: return False, 'no output'
    return bool(np.max(np.abs(y - ref) / ref) < 2e-6), 'max rel err %.2g' % np.max(np.abs(y - ref) / ref)
res = measure('softmax', L, None, chk)
for s, o in res.items():
    c = o['m1'] - base[s]['m1']; print('softmax 1024 f32 (3 passes, vector exp)  strip %2d  m1 %6d (%.2f/elem)  m2 %6d  vops %5d %s %s' % (s, c, c / N, o['m2'] - base[s]['m2'], o.get('vops', 0), 'OK' if o['ok'] else 'FAIL', o['note']))
# the exp pass alone: instructions per strip
n_exp = exp_block().count('\n')
print('instructions in the exp block (per strip):', n_exp)
# ---- RMSNorm: y = x * rsqrt(mean(x^2) + eps) * g
g = r.standard_normal(N).astype(np.float32)
RMS = """kern:
	clr	r5
	lea	(r0)(r2),r3
	vec	r0,r3
	vld.f	v0,(r0)+
	vmul.f	v0,v0,v0
	vacc.f	r5,v0
	vend
	mov	#%d,r6
	fmul.f32	r6,r5
	mov	#%d,r6
	fadd.f32	r6,r5
	fsqrt.f32	r5,r5
	mov	#0x3f800000,r6
	fdiv.f32	r5,r6
	lea	XA,r0
	lea	(r0)(r2),r3
	vec	r0,r3
	vld.f	v0,(r0)+
	vld.f	v1,(r7)+
	vmul.f	v0,v0,r6
	vmul.f	v0,v0,v1
	vst.f	v0,(r1)+
	vend
	ret""" % (s32(fi(1.0 / N)), s32(fi(1e-5)))
ms = np.float32(0)
yref = (x * (np.float32(1) / np.sqrt(np.float32((x.astype(np.float64) ** 2).sum() / N) + np.float32(1e-5))) * g).astype(np.float32)
L = frame(['\tlea\tXA,r0', '\tlea\tYY,r1', '\tlea\tGG,r7', '\tmov\t#%d,r2' % (4 * N), '\tcall\tkern'], [], 'YY', 4 * N) + RMS.split('\n') + data('XA', x) + data('GG', g) + bss('YY', 4 * N)
base = measure('none', frame(['\tnop'], [], 'YY', 4 * N) + data('XA', x) + data('GG', g) + bss('YY', 4 * N), None, lambda o: (True, ''))
res = measure('rms', L, None, lambda o: (len(o) == 4 * N and bool(np.allclose(np.frombuffer(o, dtype=np.float32), yref, rtol=1e-4, atol=1e-5)), 'rtol 1e-4'))
for s, o in res.items():
    c = o['m1'] - base[s]['m1']; print('RMSNorm 1024 f32 (2 passes)              strip %2d  m1 %6d (%.2f/elem)  m2 %6d  vops %5d %s %s' % (s, c, c / N, o['m2'] - base[s]['m2'], o.get('vops', 0), 'OK' if o['ok'] else 'FAIL', o['note']))
