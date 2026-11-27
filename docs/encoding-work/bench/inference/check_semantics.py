#!/usr/bin/env python3
"""check_semantics.py: the CANDIDATE words are not in any simulator here; this checks, in numpy, that the proposed definitions and the panel layouts give the right matrix product (the layouts the candidate kernels of model.py assume).
  vfmab.bf  vD(4 x binary32 lanes) += pairdot(vB(8 bf16 = 4 columns x 2 k), broadcast pair (2 bf16 at (Ra)+), Ra moves 4 bytes)
  vdacc.bf  Rd(binary32) += sum over the products of all bf16 pairs of the strip (each product exact in binary32; chunks of 16 bytes by a fixed tree, in order)
  vdotb.b   vD(4 x int32 lanes) += 4-way dot of vB(16 bytes = 4 columns x 4 k) with the broadcast 4 bytes at (Ra)+ (Ra moves 4 bytes)"""
import numpy as np
from lib import *
r = rng(9); K = 64
A = from_bf16(to_bf16(r.standard_normal((8, K)).astype(np.float32))); B = from_bf16(to_bf16(r.standard_normal((4, K)).astype(np.float32)))
ref = A.astype(np.float64) @ B.astype(np.float64).T
acc = np.zeros((8, 4), dtype=np.float32)
for k in range(0, K, 2):
    Bv = np.stack([B[:, k], B[:, k + 1]], axis=1).reshape(8)            # the packed B vector: (col0 k, col0 k+1, col1 k, ...)
    for i in range(8):
        a0, a1 = A[i, k], A[i, k + 1]                                     # the broadcast pair
        for j in range(4): acc[i, j] = np.float32(acc[i, j] + np.float32(np.float32(a0 * Bv[2 * j]) + np.float32(a1 * Bv[2 * j + 1])))
print('vfmab.bf 8x4 tile, K=%d: max error against binary64 %.3g (binary32 rounding only)' % (K, np.max(np.abs(acc - ref))))
# bfloat16 product is exact in binary32
x, y = from_bf16(to_bf16(r.standard_normal(100000).astype(np.float32))), from_bf16(to_bf16(r.standard_normal(100000).astype(np.float32)))
print('bf16 x bf16 exact in binary32:', bool(np.all((x.astype(np.float64) * y) == (x * y).astype(np.float64))))
Ai = r.randint(-127, 128, (8, 64)).astype(np.int8); Bi = r.randint(-127, 128, (4, 64)).astype(np.int8)
C = np.zeros((8, 4), dtype=np.int64)
for k in range(0, 64, 4):
    for i in range(8):
        for j in range(4): C[i, j] += int((Ai[i, k:k + 4].astype(np.int64) * Bi[j, k:k + 4]).sum())
print('vdotb.b 8x4 tile, K=64: exact', bool((C == Ai.astype(np.int64) @ Bi.astype(np.int64).T).all()))
