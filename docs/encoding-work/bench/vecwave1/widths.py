#!/usr/bin/env python3
"""widths.py: the 8x4 micro-kernel (hand/k_ukr.acc.s, 8 calls for 16x16x64) under model 1 with the vector issue width as a parameter, and the 32-byte-tile alternative.
Validated: width 1 reproduces sim64's own model 1 (vector 5336 + scalar 232).  Everything else here is the same model with a stated change (assumed hardware)."""
from math import ceil
K = 64; SCAL = 232
def call(w, port=16, strip=16, cols=4):
    # per k step: 8 vfmab + 1 vld (9 vector instrs); memory: the vld of the B row (cols*4 bytes) over the port; the broadcast scalar of vfmab is not counted (model 1)
    mem = ceil(cols * 4 / port)
    k = max(ceil(9 / w), mem) + 1
    epi = max(ceil(25 / w), 8 * (ceil(cols * 4 / port) * 2)) + 1    # vclr + 24 epilogue instructions; 8 rows loaded and stored
    return K * k + epi + 1
print('width  cycles(16x16x64, kernel only)   speedup vs width 1')
base = None
for w in (1, 2, 4):
    c = 8 * call(w) + SCAL
    base = base or c
    print('%d      %d      %.2f' % (w, c, base / c))
c32 = 4 * call(1, strip=32, cols=8) + SCAL // 2
print('32-byte tile (8x8 per call, 4 calls, single issue):', c32, '%.2f' % (base / c32))
# packing, counted: scalar instructions per packed element from the measured run (12593 instructions, (16+16)*64 = 2048 elements)
pk = 12593 / 2048
print('pack instructions per element (measured): %.2f' % pk)
for n in (16, 64, 256, 1024):
    m = k = n
    pack = pk * (m + n) * k; comp = 8 * 0 + m * n * k / (4 * 9 / 10 * 1)   # ukr: 9 instr + commit per 32 madds => 3.2 madds a cycle at width 1
    comp = m * n * k / 3.2
    print('M=N=K=%4d: packing %.0f instructions, micro-kernel %.0f cycles at width 1: packing is %.1f%% of it' % (n, pack, comp, 100 * pack / comp))
