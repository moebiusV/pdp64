#!/usr/bin/env python3
"""core-total.py CORE.tsv VEC.tsv -- the gates of the scalar core of the pdp64 from the synthesised blocks (gates.sh over core.v, aes.v, decode.v) and the stated estimates, and the
vector operations against it.  A flip-flop counts 6 NAND2 equivalents.  Prints markdown."""
import sys
def load(p):
    b = {}
    for ln in open(p):
        m, g, f = ln.split()
        b[m] = int(g) + 6 * int(f)
    return b
c = load(sys.argv[1]); v = load(sys.argv[2])
rows = []
def row(name, lo, hi, how): rows.append((name, lo, hi, how))
K = lambda x: '%d' % round(x / 1000.0) + ' k'
row('register file, 32 x 64 bits, 3 read ports, 1 write', c['rf3'], c['rf3'], 'synthesised')
row('integer ALU (add, subtract with carry, logic, select, min, max, abs, flags)', c['alu64'], c['alu64'], 'synthesised')
row('shifter and rotator, 64 bits', c['shift64'], c['shift64'], 'synthesised')
row('bit-manipulation words (count, bit reverse, byte swap)', c['bitops64'], 4000, 'synthesised (the low figure; the synthesiser simplified the counts) to an estimate of 4,000')
row('multiplier, 64 x 64 to 128 bits', 8000, c['mul64'], 'synthesised (the high figure); an iterative multiplier would be about 8,000 (estimated)')
row('divider, iterative', c['div64'], c['div64'], 'synthesised')
row('instruction decoder of the 217 leaves (generated from the grammar)', c['decode'] + 3000, c['decode'] + 3000, 'synthesised from the grammar + 3,000 estimated for the hot-register tables and the immediates')
row('instruction fetch: variable length of 1 to 5 parcels, the alignment and the buffer', 5000, 8000, 'estimated')
row('branch unit: comparator, pc adder, target adder', 2000, 3000, 'estimated from the synthesised adders')
row('load and store: the address adder (base + index x scale + displacement), alignment, merge, block-operation sequencer, atomics', c['ldalign'] + c['stmerge'] + 1500 + 5000, c['ldalign'] + c['stmerge'] + 1500 + 7000, 'synthesised alignment and merge + estimates')
row('translation: two buffers (16 and 32 entries), the page walker, permissions, the direct-mapped windows', c['tlb32'] * 3 // 2 + 4500, c['tlb32'] * 3 // 2 + 8000, 'the synthesised 32-entry buffer x 1.5 for two + estimates')
fp = c['mul53'] + c['shr106'] * 2 + c['add106'] + c['norm106']
row('floating point (single, double, half): multiplier, aligners, adder, normaliser, rounding, divide and square root, conversions', fp + 12000, fp + 20000, 'synthesised pieces + 12,000 to 20,000 estimated')
cry = c['aesround'] + 6000 + c['clmul64']
row('crypto words: AES round, SHA-2 steps, carry-less multiply', c['aesround'] + 6000 + 8000, cry, 'synthesised AES round and 64-bit carry-less multiply (the low figure uses an iterative one, estimated) + 6,000 for SHA')
row('system registers, exceptions, interrupts, the vector fetch', 10000, 16000, 'estimated')
row('pipeline: control, hazards, bypass, stage registers', 18000, 26000, 'estimated')
row('debug, trace, performance counters', 3000, 6000, 'estimated')
lo = sum(r[1] for r in rows); hi = sum(r[2] for r in rows)
print('| block | gates (NAND2 equivalents) | how |\n|---|---:|---|')
for n, a, b, how in rows:
    print('| %s | %s | %s |' % (n, K(a) if a == b else '%s to %s' % (K(a), K(b)), how))
print('| **the scalar core, total (no caches, no branch predictor)** | **%s to %s** | the sum of the rows |' % (K(lo), K(hi)))
mid = (lo + hi) / 2
print()
print('SCALAR %d %d %d' % (lo, hi, mid))
