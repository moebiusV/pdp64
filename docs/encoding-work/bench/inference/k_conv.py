#!/usr/bin/env python3
"""k_conv.py: the conversions and the dequantisation loops with the current words (4096 elements each)."""
import numpy as np
from lib import *
N = 4096
r = rng(11)
def run(name, kern, body_regs, datalines, outsym, outbytes, check, extra_base=''):
    body = body_regs + ['\tcall\tkern']
    L = frame(body, [], outsym, outbytes) + kern.split('\n') + datalines
    base = measure('none', frame(['\tnop'], [], outsym, outbytes) + datalines, None, lambda o: (True, ''))
    res = measure(name, L, None, check)
    return res, base
def report(label, res, base, per=N):
    for s, o in res.items():
        c = o['m1'] - base[s]['m1']
        print('%-28s strip %2d  m1 %6d (%.2f/elem)  m2 %6d  vops %5d  strips %4d  %s %s' % (label, s, c, c / per, o['m2'] - base[s]['m2'], o.get('vops', 0), o.get('strips', 0), 'OK' if o['ok'] else 'FAIL', o['note']))
out = []
# ---- f32 -> bf16, round to nearest even, NaN kept (quiet); the vector words of the family only
x = r.standard_normal(N).astype(np.float32) * np.float32(10) ** r.randint(-5, 6, N).astype(np.float32)
x[::97] = np.nan; x[5::131] = np.inf; x[7::131] = -np.inf; x[11::211] = 0.0; x[13::211] = 1e-39
u = f32bits(x); u[3::251] = 0x7fc12345; u[9::257] = 0x7f800001   # NaN payloads, a signalling NaN
# ties: low half exactly 0x8000
u[20:40] = (u[20:40] & 0xffff0000) | 0x8000; u[40:60] = (u[40:60] & 0xffff0000) | 0x18000 & 0xffff | 0x8000
want = to_bf16(bits32f(u))
F2B = """kern:
	mov	#32767,r6
	mov	#0x7fffffff,r7
	mov	#0x7f800000,r8
	lea	(r0)(r2),r3
	vec	r0,r3
	vld.l	v0,(r0)+
	vshr.l	v1,v0,#16
	vand.l	v1,v1,#1
	vadd.l	v1,v1,r6
	vadd.l	v1,v1,v0
	vshr.l	v1,v1,#16
	vand.l	v2,v0,r7
	vcgtu.l	v2,v2,r8
	vshr.l	v3,v0,#16
	vor.l	v3,v3,#64
	vbsl	v1,v2,v3,v1
	vst.l.w	v1,(r1)+
	vend
	ret"""
res, base = run('f2b', F2B, ['\tlea\tXA,r0', '\tlea\tXB,r1', '\tmov\t#%d,r2' % (4 * N)], data('XA', u) + bss('XB', 2 * N), 'XB', 2 * N,
                lambda o: (np.array_equal(np.frombuffer(o, dtype=np.uint16), want), 'bit-exact vs RNE+quiet NaN'))
report('f32->bf16 RNE+NaN (vector)', res, base)
# without the NaN lines (what a program that knows its data has no NaN would write): 6 instructions
F2B_NN = F2B.replace("""	vand.l	v2,v0,r7
	vcgtu.l	v2,v2,r8
	vshr.l	v3,v0,#16
	vor.l	v3,v3,#64
	vbsl	v1,v2,v3,v1
""", "")
xn = r.standard_normal(N).astype(np.float32); wn = to_bf16(xn)
res, base = run('f2b_nonan', F2B_NN, ['\tlea\tXA,r0', '\tlea\tXB,r1', '\tmov\t#%d,r2' % (4 * N)], data('XA', xn) + bss('XB', 2 * N), 'XB', 2 * N,
                lambda o: (np.array_equal(np.frombuffer(o, dtype=np.uint16), wn), 'bit-exact, finite inputs'))
report('f32->bf16 RNE, no NaN test', res, base)
# ---- bf16 -> f32 through memory (the only way the current words can retag): widen, shift, store the bits
h = to_bf16(r.standard_normal(N).astype(np.float32))
B2F = """kern:
	lea	(r0)(r2),r3
	vec	r0,r3
	vld.wu.l	v0,(r0)+
	vshl.l	v0,v0,#16
	vst.l	v0,(r1)+
	vend
	ret"""
res, base = run('b2f', B2F, ['\tlea\tXA,r0', '\tlea\tXB,r1', '\tmov\t#%d,r2' % (2 * N)], data('XA', h) + bss('XB', 4 * N), 'XB', 4 * N,
                lambda o: (np.array_equal(np.frombuffer(o, dtype=np.float32), from_bf16(h)), 'exact'))
report('bf16->f32 to memory', res, base)
# ---- dequantise int8 -> f32 with a scale
w = r.randint(-127, 128, N).astype(np.int8); sc = np.float32(0.0123)
DQ = """kern:
	lea	(r0)(r2),r3
	vec	r0,r3
	vld.b.l	v0,(r0)+
	vcvt.l.f	v0,v0
	vmul.f	v0,v0,r8
	vst.f	v0,(r1)+
	vend
	ret"""
res, base = run('dq', DQ, ['\tlea\tXA,r0', '\tlea\tXB,r1', '\tmov\t#%d,r2' % N, '\tmov\t#%d,r8' % int(f32bits(sc))], data('XA', w) + bss('XB', 4 * N), 'XB', 4 * N,
                lambda o: (np.array_equal(np.frombuffer(o, dtype=np.float32), (w.astype(np.float32) * sc).astype(np.float32)), 'exact'))
report('int8 -> f32 * scale', res, base)
# int8 -> bf16 (scale, then the RNE narrowing, finite data)
DQB = """kern:
	mov	#32767,r6
	lea	(r0)(r2),r3
	vec	r0,r3
	vmov.l	v8,#0
	vld.b.l	v0,(r0)+
	vcvt.l.f	v0,v0
	vmul.f	v0,v0,r8
	vbsl	v0,v8,v8,v0
	vshr.l	v1,v0,#16
	vand.l	v1,v1,#1
	vadd.l	v1,v1,r6
	vadd.l	v1,v1,v0
	vshr.l	v1,v1,#16
	vst.l.w	v1,(r1)+
	vend
	ret"""
res, base = run('dqb', DQB, ['\tlea\tXA,r0', '\tlea\tXB,r1', '\tmov\t#%d,r2' % N, '\tmov\t#%d,r8' % int(f32bits(sc))], data('XA', w) + bss('XB', 2 * N), 'XB', 2 * N,
                lambda o: (np.array_equal(np.frombuffer(o, dtype=np.uint16), to_bf16((w.astype(np.float32) * sc).astype(np.float32))), 'bit-exact'))
report('int8 -> bf16 * scale', res, base)
# ---- E4M3 -> f32 by the exponent trick: bits = sign<<31 | (x & 0x7f) << 20, times 2^120 (NaN handled by the caller's format: not here)
e = r.randint(0, 256, N).astype(np.uint8)
def e4m3(x):
    x = x.astype(np.uint32); s = np.where(x & 0x80, -1.0, 1.0); em = x & 0x7f; E = em >> 3; Mn = em & 7
    return (s * np.where(E == 0, Mn * 2.0 ** -9, (1 + Mn / 8.0) * 2.0 ** (E.astype(np.int64) - 7))).astype(np.float32)
want = e4m3(e); nanmask = (e & 0x7f) == 0x7f
E43 = """kern:
	mov	#0x80,r6
	mov	#0x7f,r7
	mov	#0x7b800000,r8
	lea	(r0)(r2),r3
	vec	r0,r3
	vmov.l	v8,#0
	vmov.f	v9,#0
	vld.bu.l	v0,(r0)+
	vand.l	v1,v0,r6
	vshl.l	v1,v1,#24
	vand.l	v0,v0,r7
	vshl.l	v0,v0,#20
	vor.l	v0,v0,v1
	vbsl	v0,v8,v9,v0
	vmul.f	v0,v0,r8
	vst.f	v0,(r1)+
	vend
	ret"""
res, base = run('e4m3', E43, ['\tlea\tXA,r0', '\tlea\tXB,r1', '\tmov\t#%d,r2' % N], data('XA', e) + bss('XB', 4 * N), 'XB', 4 * N,
                lambda o: (np.array_equal(np.frombuffer(o, dtype=np.float32)[~nanmask], want[~nanmask]), 'exact except the NaN codes (S.1111.111, not tested here)'))
report('E4M3 -> f32 (arithmetic)', res, base)
