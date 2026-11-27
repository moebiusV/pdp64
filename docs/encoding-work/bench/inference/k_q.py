#!/usr/bin/env python3
"""k_q.py: quantised dot products and the bfloat16 GEMV with the current words."""
import numpy as np
from lib import *
r = rng(21)
def run(name, kern, regs, datalines, outsym, outbytes, check):
    L = frame(regs + ['\tcall\tkern'], [], outsym, outbytes) + kern.split('\n') + datalines
    base = measure('none', frame(['\tnop'], [], outsym, outbytes) + datalines, None, lambda o: (True, ''))
    return measure(name, L, None, check), base
def report(label, res, base, macs):
    for s, o in res.items():
        c = o['m1'] - base[s]['m1']
        print('%-34s strip %2d  m1 %6d  %.2f MAC/cycle  m2 %6d  vops %5d  %s %s' % (label, s, c, macs / c, o['m2'] - base[s]['m2'], o.get('vops', 0), 'OK' if o['ok'] else 'FAIL', o['note']))
NB = 128; N = NB * 32
w = r.randint(-127, 128, N).astype(np.int8); x = r.randint(-127, 128, N).astype(np.int8)
ws = r.uniform(0.001, 0.05, NB).astype(np.float16); xs = r.uniform(0.001, 0.05, NB).astype(np.float16)
isum = (w.astype(np.int64).reshape(NB, 32) * x.astype(np.int64).reshape(NB, 32)).sum(1)
ref = np.float32(0)
for b in range(NB): ref = np.float32(ref + np.float32(ws[b]) * np.float32(xs[b]) * np.float32(isum[b]))
Q8 = """kern:
	clr	r6
	clr	r11
L8:	clr	r10
	lea	32(r0),r3
	vec	r0,r3
	vld.b	v0,(r0)+
	vld.b	v1,(r1)+
	vdacc.b	r10,v0,v1
	vend
	mov.u16	(r4)+,r8
	mov.u16	(r5)+,r9
	fcvt	r8.f16,r8.f32
	fcvt	r9.f16,r9.f32
	fmul.f32	r9,r8
	fcvt	r10.s32,r10.f32
	fmadd.f32	r8,r10,r6,r6
	inc	r11
	cbne	r11,r2,L8
	lea	RES,r5
	mov	r6,(r5)
	ret"""
res, base = run('q8_0', Q8, ['\tlea\tWQ,r0', '\tlea\tXQ,r1', '\tlea\tWS,r4', '\tlea\tXS,r5', '\tmov\t#%d,r2' % NB], data('WQ', w) + data('XQ', x) + data('WS', ws.view(np.uint16)) + data('XS', xs.view(np.uint16)) + bss('RES', 8), 'RES', 8,
                lambda o: (abs(float(np.frombuffer(o[:4], dtype=np.float32)[0]) - float(ref)) < 1e-3 * abs(float(ref)) + 1e-3, 'got %.5f ref %.5f' % (np.frombuffer(o[:4], dtype=np.float32)[0], ref)))
report('q8_0 dot, 128 blocks, scales (scalar)', res, base, N)
# the same integer dot without the scale work: the floor
Q8N = """kern:
	clr	r10
	lea	(r0)(r2),r3
	vec	r0,r3
	vld.b	v0,(r0)+
	vld.b	v1,(r1)+
	vdacc.b	r10,v0,v1
	vend
	lea	RES,r5
	mov	r10,(r5)
	ret"""
res, base = run('q8nos', Q8N, ['\tlea\tWQ,r0', '\tlea\tXQ,r1', '\tmov\t#%d,r2' % N], data('WQ', w) + data('XQ', x) + bss('RES', 8), 'RES', 8,
                lambda o: (int(np.frombuffer(o, dtype=np.int64)[0]) == int((w.astype(np.int64) * x).sum()), 'exact'))
report('q8 integer dot, no scales (stream)', res, base, N)
# ---- 4-bit weights: nibbles of one byte, low = element j of the first half, high = element j of the second half (x stored as two streams)
nib = r.randint(0, 16, N).astype(np.uint8)
packed = (nib[:N // 2] | (nib[N // 2:] << 4)).astype(np.uint8)          # byte j: low = w[j], high = w[N/2 + j]
xlo, xhi = x[:N // 2], x[N // 2:]
Q4 = """kern:
	clr	r10
	lea	(r0)(r2),r3
	vec	r0,r3
	vld.bu	v0,(r0)+
	vand.b	v1,v0,#15
	vshr.b	v2,v0,#4
	vld.b	v3,(r1)+
	vld.b	v4,(r4)+
	vdacc.bsu	r10,v3,v1
	vdacc.bsu	r10,v4,v2
	vend
	lea	RES,r5
	mov	r10,(r5)
	ret"""
res, base = run('q4', Q4, ['\tlea\tWP,r0', '\tlea\tXL,r1', '\tlea\tXH,r4', '\tmov\t#%d,r2' % (N // 2)], data('WP', packed) + data('XL', xlo) + data('XH', xhi) + bss('RES', 8), 'RES', 8,
                lambda o: (int(np.frombuffer(o, dtype=np.int64)[0]) == int((nib.astype(np.int64) * x).sum()), 'exact'))
report('q4 nibble dot, no scales (stream)', res, base, N)
# ---- bfloat16 GEMV, 4 rows at a time: the even/odd route, retags by vbsl
R, K = 8, 1024
W = from_bf16(to_bf16(r.standard_normal((R, K)).astype(np.float32))); X = from_bf16(to_bf16(r.standard_normal(K).astype(np.float32)))
Wb, Xb = to_bf16(W), to_bf16(X)
yref = (W.astype(np.float64) @ X.astype(np.float64)).astype(np.float32)
rows = ''
for j in range(4):
    rows += """	vld.l	v2,(r%d)+
	vshl.l	v3,v2,#16
	vand.l	v2,v2,r9
	vbsl	v3,v8,v9,v3
	vbsl	v2,v8,v9,v2
	vmul.f	v3,v3,v1
	vfma.f	v3,v2,v0
	vacc.f	r%d,v3
""" % (1 + j, 16 + j)
GV = """kern:
	mov	#0xffff0000,r9
	clr	r16
	clr	r17
	clr	r18
	clr	r19
	lea	(r0)(r12),r3
	vec	r0,r3
	vmov.l	v8,#0
	vmov.f	v9,#0
	vld.l	v0,(r0)+
	vshl.l	v1,v0,#16
	vand.l	v0,v0,r9
	vbsl	v1,v8,v9,v1
	vbsl	v0,v8,v9,v0
""" + rows + """	vend
	mov.s32	r16,(r10)+
	mov.s32	r17,(r10)+
	mov.s32	r18,(r10)+
	mov.s32	r19,(r10)+
	ret"""
GVBODY = ['\tlea\tXV,r0', '\tlea\tWM,r1', '\tmov\t#%d,r12' % (2 * K), '\tlea\tYY,r10', '\tclr\tr11', 'LG:', '\tmov\t#%d,r5' % (4 * 2 * K), '\tmul\tr11,r5', '\tlea\tWM,r1', '\tadd\tr5,r1',
          '\tlea\t(r1)(r12),r2', '\tlea\t(r2)(r12),r3', '\tlea\t(r3)(r12),r4', '\tlea\tXV,r0', '\tcall\tkern', '\tinc\tr11', '\tcbne\tr11,#%d,LG' % (R // 4)]
# registers: kern uses r0..r4 as pointers (r0 x, r1..r4 rows) -- r3 is also the end of the region, so use r13? keep distinct below
GV = GV.replace('lea\t(r0)(r12),r3', 'lea\t(r0)(r12),r6')
GV = GV.replace('vec\tr0,r3', 'vec\tr0,r6')
Lg = frame(GVBODY, [], 'YY', 4 * R) + GV.split('\n') + data('XV', Xb) + data('WM', Wb) + bss('YY', 4 * R)
basegv = measure('none', frame(['\tnop'], [], 'YY', 4 * R) + data('XV', Xb) + data('WM', Wb) + bss('YY', 4 * R), None, lambda o: (True, ''))
resgv = measure('gemv', Lg, None, lambda o: (np.allclose(np.frombuffer(o, dtype=np.float32), yref, rtol=1e-3, atol=1e-3), 'maxerr %.2g' % np.max(np.abs(np.frombuffer(o, dtype=np.float32) - yref)) if len(o) == 4 * R else 'no output'))
report('bf16 GEMV 8x1024, 4 rows, evenodd', resgv, basegv, R * K)
# ---- FP4 (E2M1) weights decoded by vtbl.b: the 16 values doubled so they are int8: 0,1,2,3,4,6,8,12 and the negatives; dot against int8 activations (the result is twice the true dot)
tab = np.array([0, 1, 2, 3, 4, 6, 8, 12, 0, -1, -2, -3, -4, -6, -8, -12], dtype=np.int8)
FP4 = """kern:
	clr	r10
	lea	(r0)(r2),r3
	vec	r0,r3
	vld.bu	v0,(r0)+
	vand.b	v1,v0,#15
	vshr.b	v2,v0,#4
	vtbl.b	v1,(r6),v1
	vtbl.b	v2,(r6),v2
	vld.b	v3,(r1)+
	vld.b	v4,(r4)+
	vdacc.b	r10,v3,v1
	vdacc.b	r10,v4,v2
	vend
	lea	RES,r5
	mov	r10,(r5)
	ret"""
res, base = run('fp4', FP4, ['\tlea\tWP,r0', '\tlea\tXL,r1', '\tlea\tXH,r4', '\tlea\tTAB,r6', '\tmov\t#%d,r2' % (N // 2)], data('WP', packed) + data('XL', xlo) + data('XH', xhi) + data('TAB', tab) + bss('RES', 8), 'RES', 8,
                lambda o: (int(np.frombuffer(o, dtype=np.int64)[0]) == int((tab[nib].astype(np.int64) * x).sum()), 'exact'))
report('fp4 (E2M1) table dot, no scales', res, base, N)
