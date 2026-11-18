#!/usr/bin/env python3
"""total.py BLOCKS.tsv -- the gates of each operation of docs/encoding-work/vec-gates.md from the synthesised blocks (gates.sh) and the stated assumptions.
A flip-flop counts 6 NAND2 equivalents.  Prints a table in markdown."""
import sys
b = {}
for ln in open(sys.argv[1]):
    m, g, f = ln.split()
    b[m] = int(g) + 6 * int(f)
K = lambda x: '%.0f k' % (x / 1000.0) if x >= 1000 else '%d' % x
rows = []
def row(name, low, high, how): rows.append((name, low, high, how))
vreg = b['vregs']
alu = b['lanealu16plain']
mul16 = 16 * b['mul16s']
mul8 = 32 * b['mul8s']
fma = b['mul24u'] + b['shr48'] + b['add48'] + b['norm48'] + 1500		# the exponent and rounding logic: an estimate of 1,500
fma8 = 8 * fma
ctl = 4 * b['add64'] + 2000
ldst = 10000																# alignment rotate and store merge of 256 bits: an estimate
row('1 the block: 8 hidden vector registers x 256 bits (3 read, 1 write)', vreg, vreg, 'synthesised')
row('1 the block: lane ALU (add, subtract, and, or, xor), 16 lanes of 16 bits', alu, alu, 'synthesised')
row('1 the block: 16-bit integer multipliers, 16 lanes', mul16, mul16, '16 x the synthesised 16x16 multiplier')
row('1 the block: 32-bit floating-point multiply-add, 8 lanes', fma8, fma8, '8 x (24x24 multiplier + aligner + 48-bit add + normaliser, synthesised, + 1,500 estimated for exponent and rounding)')
row('1 the block: strip control (4 auto-increment pointers, the count, the sequencer)', ctl, ctl, '4 x the synthesised 64-bit adder + 2,000 estimated')
row('1 the block: load and store alignment (256-bit rotate and merge)', ldst, ldst, 'estimated')
base_low = vreg + alu + mul16 + ctl + ldst
base_high = vreg + alu + mul16 + fma8 + ctl + ldst
row('**1 the block, total**', base_low, base_high, 'without and with the floating-point lanes')
row('3 reductions (`vacc`, a max reduction)', 2 * b['reduce16'], 2 * b['reduce16'], '2 x the synthesised 16-lane reduction')
row('4 saturating and min/max lane operations, widening and narrowing', b['lanealu16'] - b['lanealu16plain'] + 3000, b['lanealu16'] - b['lanealu16plain'] + 6000, 'the synthesised difference of the two lane ALUs + 3,000 to 6,000 estimated for the pack and unpack')
row('5 sliding window `vfir`: one output strip a cycle (128 8x8 multipliers, 16 adders of 8)', 128 * b['mul8s'] + 16 * b['firsum8'], 128 * b['mul8s'] + 16 * b['firsum8'] + 2000, '128 x mul8s + 16 x the synthesised 8-input sum (+ 2,000 for the halo registers)')
row('5 sliding window `vfir`: 8 cycles on the existing multipliers', 3000, 6000, 'estimated: the halo registers, the tap select, the control')
row('6 broadcast multiply-add and the micro-kernel: 16 vector registers instead of 8', vreg, vreg, 'a second register file of the same size (the form needs 10 registers); the broadcast mux is ~1,000 more')
row('7 int8 dot product: 8 lanes of 4 byte products into 32 bits', 8 * b['dot4'], 8 * b['dot4'], '8 x the synthesised `dot4`')
row('8 nibble and shift operations: a per-lane barrel shift', 3000, 3000, 'estimated: 16 lanes x a 16-bit, 4-stage shifter')
row('10 gather, one lane a cycle', b['gather1'] + 2000, b['gather1'] + 4000, 'the synthesised address generator + 2,000 to 4,000 estimated for lane insertion (more cache ports are not logic)')
row('11 segment loads and stores (2, 3 or 4 fields; 8, 16 and 32 bits)', 2 * b['segload8'], 6 * b['segload8'], '2 x (load, store) of the synthesised 8-bit network to 6 x for the wider elements')
row('12 predication: a mask register and per-lane write enables', 2000, 4000, 'estimated')
row('9 vector exponential on the existing multipliers (a table and control)', 8000, 15000, 'estimated: a 64-entry table and a sequencer, using the 8 floating-point lanes')
row('13 fp16 and bf16 conversions, 8 lanes each way', 15000, 30000, 'estimated')
tile_fp = 64 * fma + 2048 * 6 + 20000
tile_i8 = 256 * b['mul8s'] + 8192 * 6 + 30000
row('14 tile with outer-product: 8x8 fp32 multiply-adds, 2,048 accumulator bits', tile_fp, tile_fp, '64 x the multiply-add + the accumulators (6 per bit) + 20,000 for broadcast and write-back')
row('14 tile with outer-product: 16x16 int8 products, 16x16 x 32-bit accumulators', tile_i8, tile_i8, '256 x mul8s + 8,192 accumulator bits + 30,000')
row('15 the whole-GEMM unit: a tile, a DMA and sequencer, 64 KB of buffers', tile_fp + 30000 + 524288, tile_fp + 30000 + 524288 * 2, 'row 14 (fp32) + 30,000 for the descriptor sequencer and DMA + 64 KB of SRAM at 1 to 2 NAND2 equivalents a bit')
print('| operation | gates added (NAND2 equivalents) | how it was counted |\n|---|---:|---|')
for n, lo, hi, how in rows:
    s = K(lo) if lo == hi else '%s to %s' % (K(lo), K(hi))
    print('| %s | %s | %s |' % (n, s, how))
