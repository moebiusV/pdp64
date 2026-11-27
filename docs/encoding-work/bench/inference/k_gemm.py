#!/usr/bin/env python3
"""k_gemm.py: 16 x 16 x K matrix products (K = 256) made of micro-kernel calls, with the current words:
  f32      the repository's 8x4 accumulator micro-kernel (vfmab), panels in binary32 (what packing to binary32 gives)
  bf16B    B panel in bfloat16, widened inside the kernel (vld.wu.l, vshl.l, the vbsl retag), A panel binary32 (vfmab broadcasts a binary32)
  i8dacc   int8 x int8 -> int32, 4 x 4 block of scalar accumulators, vdacc.b (no accumulator block: the strip is free)
and the proxies of candidate words (the same instruction and byte counts, see the note)."""
import sys, numpy as np
from lib import *
M = N = 16
def ukr_main(K, asz, bsz, kern, call_name='k_ukr', Kcall=None):
    Kc = Kcall or K
    body = ['\tpush\tr8', '\tpush\tr9', '\tclr\tr8', 'Lp:\tclr\tr9', 'Lq:']
    body += ['\tmov\t#%d,r0' % (8 * K * asz // 1), '\tmul\tr8,r0', '\tlea\tPA,r1', '\tadd\tr1,r0']
    body += ['\tmov\t#%d,r1' % (4 * K * bsz), '\tmul\tr9,r1', '\tlea\tPB,r2', '\tadd\tr2,r1']
    body += ['\tmov\t#%d,r2' % (8 * N * 4), '\tmul\tr8,r2', '\tmov\t#16,r3', '\tmul\tr9,r3', '\tadd\tr3,r2', '\tlea\tCC,r3', '\tadd\tr3,r2']
    body += ['\tmov\t#%d,r3' % Kc, '\tmov\t#%d,r4' % (N * 4), '\tcall\t%s' % call_name]
    body += ['\tinc\tr9', '\tcbne\tr9,#4,Lq', '\tinc\tr8', '\tcbne\tr8,#2,Lp', '\tpop\tr9', '\tpop\tr8']
    return body
UKR_F32 = """k_ukr:
	mov	r3,r6
	shl	#4,r6
	add	r1,r6
	mov	r2,r16
	lea	(r16)(r4*1),r17
	lea	(r17)(r4*1),r18
	lea	(r18)(r4*1),r19
	lea	(r19)(r4*1),r20
	lea	(r20)(r4*1),r21
	lea	(r21)(r4*1),r22
	lea	(r22)(r4*1),r23
	vec	r1,r6
	vclr.f	v0,#8
	vld.f	v8,(r1)+
	vfmab.f	v0,v8,(r0)+
	vfmab.f	v1,v8,(r0)+
	vfmab.f	v2,v8,(r0)+
	vfmab.f	v3,v8,(r0)+
	vfmab.f	v4,v8,(r0)+
	vfmab.f	v5,v8,(r0)+
	vfmab.f	v6,v8,(r0)+
	vfmab.f	v7,v8,(r0)+
	vfin
""" + ''.join("\tvld.f\tv9,(r%d)\n\tvadd.f\tv9,v9,v%d\n\tvst.f\tv9,(r%d)\n" % (16 + i, i, 16 + i) for i in range(8)) + "\tvend\n\tret\n"
# bf16 B panel: 4 columns of one k = 8 bytes; widened by the shift, retagged by vbsl (zero mask in v14, float donor in v15, both accumulators so they are made once)
UKR_BF16B = """k_ukrb:
	mov	r3,r6
	shl	#3,r6
	add	r1,r6
	mov	r2,r16
	lea	(r16)(r4*1),r17
	lea	(r17)(r4*1),r18
	lea	(r18)(r4*1),r19
	lea	(r19)(r4*1),r20
	lea	(r20)(r4*1),r21
	lea	(r21)(r4*1),r22
	lea	(r22)(r4*1),r23
	vec	r1,r6
	vclr.f	v0,#8
	vclr.l	v14,#1
	vclr.f	v15,#1
	vld.wu.l	v8,(r1)+
	vshl.l	v8,v8,#16
	vbsl	v8,v14,v15,v8
	vfmab.f	v0,v8,(r0)+
	vfmab.f	v1,v8,(r0)+
	vfmab.f	v2,v8,(r0)+
	vfmab.f	v3,v8,(r0)+
	vfmab.f	v4,v8,(r0)+
	vfmab.f	v5,v8,(r0)+
	vfmab.f	v6,v8,(r0)+
	vfmab.f	v7,v8,(r0)+
	vfin
""" + ''.join("\tvld.f\tv9,(r%d)\n\tvadd.f\tv9,v9,v%d\n\tvst.f\tv9,(r%d)\n" % (16 + i, i, 16 + i) for i in range(8)) + "\tvend\n\tret\n"
def gemm_ref(Ab, Bb, K):
    return (Ab.astype(np.float64) @ Bb.astype(np.float64).T).astype(np.float32)   # exact products of bf16 values; the sum order differs slightly: a tolerance
def run_ukr(variant, K=256):
    r = rng(3)
    A = from_bf16(to_bf16(r.standard_normal((M, K)).astype(np.float32))); B = from_bf16(to_bf16(r.standard_normal((N, K)).astype(np.float32)))
    ref = gemm_ref(A, B, K)
    # panels: A panel p = rows 8p..8p+7, for each k 8 floats; B panel q = cols 4q..4q+3, for each k 4 values
    PA = np.concatenate([A[8 * p:8 * p + 8].T.reshape(-1) for p in range(2)]).astype(np.float32)
    if variant == 'f32':
        PB = np.concatenate([B[4 * q:4 * q + 4].T.reshape(-1) for q in range(4)]).astype(np.float32); bsz = 4; kern = UKR_F32; cn = 'k_ukr'
    else:
        PB = np.concatenate([to_bf16(B[4 * q:4 * q + 4].T.reshape(-1)) for q in range(4)]); bsz = 2; kern = UKR_BF16B; cn = 'k_ukrb'
    body = ukr_main(K, 4, bsz, kern, cn)
    L = frame(body, [], 'CC', M * N * 4) + kern.split('\n') + data('PA', PA) + data('PB', PB) + bss('CC', M * N * 4)
    def check(out):
        C = np.frombuffer(out, dtype=np.float32).reshape(M, N)
        err = np.max(np.abs(C - ref)); return err < 1e-3 * np.max(np.abs(ref)), 'maxerr %.3g' % err
    base = measure('none', frame(['\tnop'], [], 'CC', M * N * 4) + bss('CC', M * N * 4), None, lambda o: (True, ''))
    res = measure(variant, L, None, check)
    return res, base
def i8_main(K):
    # 4x4 block: A rows a0..a3 (pointers r0..r3), B rows b0..b3 (r4..r7), accumulators r8..r23; the C block stored at (r24)
    return None
ACC = [15] + list(range(16, 28)) + [29, 30, 31]
I8 = """k_i8blk:
""" + "".join("\tclr\tr%d\n" % r for r in ACC) + """	lea	(r4)(r28),r10
	vec	r4,r10
	vld.b	v0,(r4)+
	vld.b	v1,(r5)+
	vld.b	v2,(r6)+
	vld.b	v3,(r7)+
	vld.b	v4,(r8)+
	vld.b	v5,(r9)+
	vld.b	v6,(r2)+
	vld.b	v7,(r3)+
""" + "".join("\tvdacc.b\tr%d,v%d,v%d\n" % (ACC[4 * i + j], i, 4 + j) for i in range(4) for j in range(4)) + """	vend
""" + "".join("\tmov\tr%d,%d(r1)\n" % (ACC[4 * i + j], (i * 16 + j) * 8) for i in range(4) for j in range(4)) + """	ret
"""
def run_i8(K=256):
    r = rng(5)
    A = r.randint(-127, 128, (M, K)).astype(np.int8); B = r.randint(-127, 128, (N, K)).astype(np.int8)
    ref = (A.astype(np.int64) @ B.astype(np.int64).T)
    body = ['\tclr\tr0', 'Lp:\tclr\tr11', 'Lq:', '\tmov\t#%d,r28' % K]
    body += ['\tmov\t#%d,r12' % (4 * K), '\tmul\tr0,r12', '\tlea\tAA,r4', '\tadd\tr12,r4', '\tlea\t(r4)(r28),r5', '\tlea\t(r5)(r28),r6', '\tlea\t(r6)(r28),r7']
    body += ['\tmov\t#%d,r12' % (4 * K), '\tmul\tr11,r12', '\tlea\tBB,r8', '\tadd\tr12,r8', '\tlea\t(r8)(r28),r9', '\tlea\t(r9)(r28),r2', '\tlea\t(r2)(r28),r3']
    body += ['\tmov\t#%d,r1' % (4 * 16 * 8), '\tmul\tr0,r1', '\tmov\t#32,r12', '\tmul\tr11,r12', '\tadd\tr12,r1', '\tlea\tCC,r12', '\tadd\tr12,r1', '\tcall\tk_i8blk']
    body += ['\tinc\tr11', '\tcbne\tr11,#4,Lq', '\tinc\tr0', '\tcbne\tr0,#4,Lp']
    L = frame(body, [], 'CC', M * N * 8) + I8.split('\n') + data('AA', A) + data('BB', B) + bss('CC', M * N * 8)
    def check(out):
        C = np.frombuffer(out, dtype=np.int64).reshape(M, N)
        return bool((C == ref).all()), 'exact'
    base = measure('none', frame(['\tnop'], [], 'CC', M * N * 8) + bss('CC', M * N * 8), None, lambda o: (True, ''))
    return measure('i8', L, None, check), base
if __name__ == '__main__':
    res, base = run_i8()
    for s_, o in res.items():
        print('i8gemm16x16x256 vdacc4x4 strip %2d m1 %6d m2 %6d  vops %d %s %s' % (s_, o['m1'] - base[s_]['m1'], o['m2'] - base[s_]['m2'], o.get('vops', 0), 'OK' if o['ok'] else 'FAIL', o['note']))
    for v in ('f32', 'bf16B'):
        res, base = run_ukr(v)
        for s, o in res.items():
            print('ukr16x16x256 %-6s strip %2d m1 %6d m2 %6d  %s %s' % (v, s, o['m1'] - base[s]['m1'], o['m2'] - base[s]['m2'], 'OK' if o['ok'] else 'FAIL', o['note']))
