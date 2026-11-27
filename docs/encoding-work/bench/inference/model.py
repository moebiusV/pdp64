#!/usr/bin/env python3
"""model.py: model 1 of docs/sim64.md (strip = max(compute, memory) + commit; compute = vector instructions, a binary32 sum one cycle for each 16-byte chunk; memory = bytes over a 16-byte port, rounded up for each load) with the vector issue
width W as a parameter (compute = ceil(instructions / W): ASSUMED, as in ../vecwave1/widths.py).  The first block VALIDATES the model on kernels the real simulator ran (k_dot.py, k_gemm.py: the measured numbers are the constants on the right); the second block is
CANDIDATE words, which no simulator here has: those numbers are COUNTED from the model, not measured."""
from math import ceil
def st(comp, mem, W=1): return max(ceil(comp / W), mem) + 1
def dot(n, s, instr_fixed, chunks, loads_bytes_per_el, VLfn, W=1, scalar=9):
    VL = VLfn(s); strips = ceil(n / VL)
    mem = sum(ceil(VL * b / 16) for b in loads_bytes_per_el)
    return scalar + strips * st(instr_fixed + chunks(s), mem, W)
ch = lambda s: s // 16
print('VALIDATION against the simulator (model / measured):')
for s, meas in ((16, 11270), (32, 6150), (64, 3590)):
    print('  bf16 dot widen    s=%2d  model %6d  measured %6d' % (s, dot(4096, s, 9, ch, (2, 2), lambda s: s // 4), meas))
for s, meas in ((16, 8199), (32, 4359), (64, 2439)):
    print('  bf16 dot evenodd  s=%2d  model %6d  measured %6d' % (s, dot(4096, s, 14, ch, (4, 4), lambda s: s // 4 * 2) if False else 9 + ceil(4096 / (2 * (s // 4))) * st(14 + s // 16, 2 * ceil(s / 16)), meas))
X = 274
def ukr(per_k, ksteps, calls=8, epi=27): return calls * (ksteps * per_k + epi) + X
for name, per_k, meas in (('f32 vfmab 8x4', st(9, 1), 20970), ('bf16 B widened in kernel', st(11, 1), 25082)):
    print('  %-28s model %6d  measured %6d' % (name, ukr(per_k, 256), meas))
def i8blk(s, W=1, K=256, blocks=16, scal=988): return scal + blocks * ceil(K / s) * st(24, 8 * ceil(s / 16), W)
for s, meas in ((16, 7388), (32, 4188), (64, 3100)): print('  i8 vdacc 4x4 s=%2d             model %6d  measured %6d' % (s, i8blk(s), meas))
print()
print('CANDIDATES (counted, model 1), single issue unless W is given.  MAC = multiply-adds.')
MAC = 16 * 16 * 256
print('bf16 dot, 4096 elements (cycles; cycles per element):')
for s in (16, 32, 64):
    cur = 9 + ceil(4096 / (2 * (s // 4))) * st(14 + s // 16, 2 * ceil(s / 16))
    a = dot(4096, s, 3, ch, (2, 2), lambda s: s // 4)                 # vld.bf.f x2, vmul.f, vacc.f
    b = dot(4096, s, 2, ch, (2, 2), lambda s: s // 2)                 # vld.w x2, vdacc.bf
    c = 9 + 4096 // 8 * st(3, 2) + 20                                 # vld.w x2, vbfdot into an accumulator (strip 16 always), epilogue ~20
    print('  s=%2d  current best (even/odd, retag by vbsl) %6d (%.2f)   vld.bf.f+vmul+vacc %6d (%.2f)   vdacc.bf %6d (%.2f)   bfdot accumulator %6d (%.2f)' % (s, cur, cur / 4096, a, a / 4096, b, b / 4096, c, c / 4096))
print('bf16 micro-kernel 16x16x256 (65,536 MAC), issue width W = 1, 2, 4:')
for W in (1, 2, 4):
    f32 = ukr(st(9, 1, W), 256); cur = ukr(st(11, 1, W), 256); ldbf = ukr(st(9, 1, W), 256)
    bfd = ukr(st(9, 1, W), 128)
    print('  W=%d  f32 panels %6d (%.2f MAC/c)  bf16 in kernel, current words %6d (%.2f)  vld.bf.f + vfmab.bf %6d (%.2f)  bfdot by element (8x4, pairs) %6d (%.2f)' % (W, f32, MAC / f32, cur, MAC / cur, ldbf, MAC / ldbf, bfd, MAC / bfd))
print('bf16 micro-kernel with 12 rows (13 instr a step), bfdot by element, W=1:', ukr(st(13, 1), 128, calls=ceil(16 / 12 * 4 / 4) * 4 // 4 * 4 // 4 * 1) if False else 'see note: 96 MAC per 14 cycles = %.2f MAC/cycle against 64 per 10 = %.2f' % (96 / st(13, 1), 64 / st(9, 1)))
print('bf16 4x4 block of vdacc.bf (no accumulators; scalar f32 sums): 8 loads + 16 vdacc.bf a strip of 16 bytes')
for s in (16, 32, 64):
    print('  s=%2d  %.2f MAC/cycle' % (s, 16 * (s // 2) / st(8 + 16 * (s // 16), 8 * ceil(s / 16))))
print('int8 micro-kernel 16x16x256, W = 1, 2, 4  (vdacc 4x4 at s = 16, 32, 64 : counted from the validated model; by element dot 8x4 pairs of 4 bytes, strip 16):')
for W in (1, 2, 4):
    d = [i8blk(s, W) for s in (16, 32, 64)]; e = ukr(st(9, 1, W), 64)
    print('  W=%d  vdacc 4x4: %s (%s MAC/c)   dot by element: %d (%.2f MAC/c)' % (W, d, ', '.join('%.1f' % (MAC / x) for x in d), e, MAC / e))
print('bf16 GEMV 8 x 1024 (8,192 MAC), 4 rows a group, cycles (MAC/cycle):')
def gemv(s, per_row_instr, per_row_chunks, x_instr, VL, ldb, W=1, scal=2 * 14):
    strips = ceil(1024 / VL); comp = x_instr + 4 * (per_row_instr + per_row_chunks(s)); mem = ceil(VL * 2 / 16) * 0 + 5 * ceil(VL * ldb / 16)
    return scal + 2 * strips * st(comp, mem, W)
for s in (16, 32, 64):
    a = gemv(s, 3, ch, 1, s // 4, 2)                 # vld.bf.f, vmul, vacc.f; x: one vld.bf.f
    b = gemv(s, 2, ch, 1, s // 2, 2)                 # vld.w, vdacc.bf; x: one vld.w
    print('  s=%2d  current (measured at 16/32/64: 10292, 5684, 3380)  vld.bf.f %6d (%.2f)  vdacc.bf %6d (%.2f)' % (s, a, 8192 / a, b, 8192 / b))
print('f32 -> bf16 conversion, 4096 elements, cycles per element: current words with NaN test 3.25 / 1.63 / 0.81 (measured), without NaN test 2.00 / 1.00 / 0.50 (measured);')
for s in (16, 32, 64):
    VL = s // 4
    print('   s=%2d  vcvt.f.bf (ld, cvt, st.w) %.2f   vst.f.bf (ld, narrowing rounding store) %.2f' % (s, st(3, ceil(VL * 4 / 16) + ceil(VL * 2 / 16)) / VL, st(2, ceil(VL * 4 / 16) + ceil(VL * 2 / 16)) / VL))
