# How many gates the vector, segment, gather and GEMM operations add

**Status: the assistant's estimate, 2026-11-17, asked by the author ("make sure to tell how many gates those will add").** Nothing here is a design of the hardware. The blocks that decide most of the number were **written in Verilog and synthesised** (yosys 0.52, mapped to NAND2 gates and inverters by abc: `tools/gates/blocks.v`, `gates.sh`, results in `arch-data/vec-gates-blocks.tsv`); the rest are **estimates** and are marked so. The unit is the **NAND2 equivalent** (a two-input NAND is 1; an inverter 0.5; a flip-flop is counted as 6). The strip is 256 bits (16 lanes of 16 bits, or 8 lanes of 32), as in the cost-benefit study (`vec-cost-benefit.md`), and the operations are those of its table.

**What is not counted:** caches and their ports (a gather that is faster than one lane a cycle needs more cache ports, which are mostly wiring and SRAM, not logic), the translation of the extra addresses, the clock and power distribution, timing (a synthesis to generic gates has no timing: the wiring and the speed-up cells of a real design add 20 to 50%, U), verification and test logic. **Power is not estimated here.** A real design will differ from these counts; they are for deciding which operations are cheap and which are not, to a factor of two.

## The blocks that were synthesised

| block | NAND2 equivalents | flip-flops |
|---|---:|---:|
| `lanealu16` | 15487 | 0 |
| `lanealu16plain` | 6881 | 0 |
| `mul8s` | 698 | 0 |
| `mul16s` | 3023 | 0 |
| `mul24u` | 5751 | 0 |
| `add32` | 322 | 0 |
| `add48` | 494 | 0 |
| `add64` | 660 | 0 |
| `shr48` | 1052 | 0 |
| `norm48` | 1091 | 0 |
| `dot4` | 4620 | 0 |
| `reduce16` | 2979 | 0 |
| `vregs` | 16155 | 2048 |
| `segload8` | 872 | 0 |
| `gather1` | 1260 | 68 |
| `firsum8` | 1021 | 0 |

Reference points the numbers can be checked against (U, from general knowledge of such designs, not measured here): an 8x8 integer multiplier is about 700 NAND2 equivalents and a 16x16 about 3,000; a 32-bit adder about 300; a 32-bit floating-point multiply-add 8,000 to 12,000. The synthesised figures are in those ranges.

## What each operation adds

| operation | gates added (NAND2 equivalents) | how it was counted |
|---|---:|---|
| 1 the block: 8 hidden vector registers x 256 bits (3 read, 1 write) | 28 k | synthesised |
| 1 the block: lane ALU (add, subtract, and, or, xor), 16 lanes of 16 bits | 7 k | synthesised |
| 1 the block: 16-bit integer multipliers, 16 lanes | 48 k | 16 x the synthesised 16x16 multiplier |
| 1 the block: 32-bit floating-point multiply-add, 8 lanes | 79 k | 8 x (24x24 multiplier + aligner + 48-bit add + normaliser, synthesised, + 1,500 estimated for exponent and rounding) |
| 1 the block: strip control (4 auto-increment pointers, the count, the sequencer) | 5 k | 4 x the synthesised 64-bit adder + 2,000 estimated |
| 1 the block: load and store alignment (256-bit rotate and merge) | 10 k | estimated |
| **1 the block, total** | 98 k to 177 k | without and with the floating-point lanes |
| 3 reductions (`vacc`, a max reduction) | 6 k | 2 x the synthesised 16-lane reduction |
| 4 saturating and min/max lane operations, widening and narrowing | 12 k to 15 k | the synthesised difference of the two lane ALUs + 3,000 to 6,000 estimated for the pack and unpack |
| 5 sliding window `vfir`: one output strip a cycle (128 8x8 multipliers, 16 adders of 8) | 106 k to 108 k | 128 x mul8s + 16 x the synthesised 8-input sum (+ 2,000 for the halo registers) |
| 5 sliding window `vfir`: 8 cycles on the existing multipliers | 3 k to 6 k | estimated: the halo registers, the tap select, the control |
| 6 broadcast multiply-add and the micro-kernel: 16 vector registers instead of 8 | 28 k | a second register file of the same size (the form needs 10 registers); the broadcast mux is ~1,000 more |
| 7 int8 dot product: 8 lanes of 4 byte products into 32 bits | 37 k | 8 x the synthesised `dot4` |
| 8 nibble and shift operations: a per-lane barrel shift | 3 k | estimated: 16 lanes x a 16-bit, 4-stage shifter |
| 10 gather, one lane a cycle | 4 k to 6 k | the synthesised address generator + 2,000 to 4,000 estimated for lane insertion (more cache ports are not logic) |
| 11 segment loads and stores (2, 3 or 4 fields; 8, 16 and 32 bits) | 2 k to 5 k | 2 x (load, store) of the synthesised 8-bit network to 6 x for the wider elements |
| 12 predication: a mask register and per-lane write enables | 2 k to 4 k | estimated |
| 9 vector exponential on the existing multipliers (a table and control) | 8 k to 15 k | estimated: a 64-entry table and a sequencer, using the 8 floating-point lanes |
| 13 fp16 and bf16 conversions, 8 lanes each way | 15 k to 30 k | estimated |
| 14 tile with outer-product: 8x8 fp32 multiply-adds, 2,048 accumulator bits | 665 k | 64 x the multiply-add + the accumulators (6 per bit) + 20,000 for broadcast and write-back |
| 14 tile with outer-product: 16x16 int8 products, 16x16 x 32-bit accumulators | 258 k | 256 x mul8s + 8,192 accumulator bits + 30,000 |
| 15 the whole-GEMM unit: a tile, a DMA and sequencer, 64 KB of buffers | 1219 k to 1744 k | row 14 (fp32) + 30,000 for the descriptor sequencer and DMA + 64 KB of SRAM at 1 to 2 NAND2 equivalents a bit |

## The sets

* **The base (row 1), a vector unit with 16 integer lanes**: **about 100,000 gates**; with **8 floating-point multiply-add lanes** as well, **about 180,000**. Most of it is the multipliers (48,000 for the integer lanes, 79,000 for the floating-point ones) and the register file (28,000). The hidden registers are 16 to 29% of the base.
* **The "yes" rows** (1 to 5, 8, with the sliding window run on the existing multipliers over eight cycles): the base plus **24,000 to 30,000** (reductions 6,000, saturation and narrowing 12,000 to 15,000, the window 3,000 to 6,000, shifts 3,000): **about 120,000 to 205,000 in all**.
* **The "likely" rows** (6 the micro-kernel's larger register file 28,000, 7 the int8 dot 37,000, 10 gather 4,000 to 6,000, 11 segment loads 2,000 to 5,000): **about 70,000 to 75,000 more**.
* **Yes and likely together: about 195,000 to 280,000 gates** (about 195,000 to 385,000 if the sliding window runs at one strip a cycle on 128 dedicated multipliers).
* **The open rows**: the vector exponential 8,000 to 15,000 on the existing lanes; the conversions 15,000 to 30,000; predication 2,000 to 4,000; the **tile 260,000 (int8) to 665,000 (fp32)**, and the **whole-GEMM unit 1.2 to 1.7 million** (most of it the multipliers and the buffer SRAM).

## The scalar core, counted the same way (the author asked for "a proper gate estimate")

The first version of this record compared with a scalar core of 150,000 to 500,000 gates taken from general knowledge. The core was then counted the same way as the vector blocks: its blocks were written in Verilog and synthesised (`tools/gates/core.v`, `aes.v`, and the instruction decoder **generated from the grammar** by `gen_decode.py`: the 217 leaves of `spec/pdp64/pdp64.hbnf`, its prefix matches and the AND-OR planes that extract the fields), the rest estimated; `tools/gates/core-total.py` adds them (data: `arch-data/core-gates-blocks.tsv`). The core is single-issue and in order, 64 bits, with the integer, bit, floating-point (single, double, half), crypto and system instructions of the grammar; **no caches and no branch predictor** (their arrays and tags are memory and wiring, not counted for either side).

| block | gates (NAND2 equivalents) | how |
|---|---:|---|
| register file, 32 x 64 bits, 3 read ports, 1 write | 32 k | synthesised |
| integer ALU (add, subtract with carry, logic, select, min, max, abs, flags) | 4 k | synthesised |
| shifter and rotator, 64 bits | 3 k | synthesised |
| bit-manipulation words (count, bit reverse, byte swap) | 1 k to 4 k | synthesised (the low figure; the synthesiser simplified the counts) to an estimate of 4,000 |
| multiplier, 64 x 64 to 128 bits | 8 k to 41 k | synthesised (the high figure); an iterative multiplier would be about 8,000 (estimated) |
| divider, iterative | 3 k | synthesised |
| instruction decoder of the 217 leaves (generated from the grammar) | 6 k | synthesised from the grammar + 3,000 estimated for the hot-register tables and the immediates |
| instruction fetch: variable length of 1 to 5 parcels, the alignment and the buffer | 5 k to 8 k | estimated |
| branch unit: comparator, pc adder, target adder | 2 k to 3 k | estimated from the synthesised adders |
| load and store: the address adder (base + index x scale + displacement), alignment, merge, block-operation sequencer, atomics | 8 k to 10 k | synthesised alignment and merge + estimates |
| translation: two buffers (16 and 32 entries), the page walker, permissions, the direct-mapped windows | 34 k to 38 k | the synthesised 32-entry buffer x 1.5 for two + estimates |
| floating point (single, double, half): multiplier, aligners, adder, normaliser, rounding, divide and square root, conversions | 51 k to 59 k | synthesised pieces + 12,000 to 20,000 estimated |
| crypto words: AES round, SHA-2 steps, carry-less multiply | 30 k to 48 k | synthesised AES round and 64-bit carry-less multiply (the low figure uses an iterative one, estimated) + 6,000 for SHA |
| system registers, exceptions, interrupts, the vector fetch | 10 k to 16 k | estimated |
| pipeline: control, hazards, bypass, stage registers | 18 k to 26 k | estimated |
| debug, trace, performance counters | 3 k to 6 k | estimated |
| **the scalar core, total (no caches, no branch predictor)** | **219 k to 308 k** | the sum of the rows |

**The scalar core is about 220,000 to 310,000 gates** (rounded; the middle is about 265,000). The largest parts are the floating-point unit (about 55,000), the register file (32,000), the multiplier (8,000 to 41,000 by design), the translation (about 36,000) and the crypto words (30,000 to 48,000). The decoder of a 217-leaf prefix-coded encoding is small: about 3,400 gates for the matches and the field extraction, 6,000 with the tables around it.

**What the vector operations add against it:**

| addition | gates | against the scalar core (220,000 to 310,000) |
|---|---:|---|
| the block alone: 16 integer lanes | about 100,000 | +33% to +45% |
| the block with 8 floating-point lanes | about 180,000 | +58% to +82% |
| **yes and likely together** (rows 1 to 8, 10, 11) | **195,000 to 280,000** | **+63% to +128%: about 1.6 to 2.3 times the core's logic** |
| the tile with an outer-product (8 x 8 fp32; 16 x 16 int8) | 665,000; 260,000 | +2.1 to 3.0 times; +0.8 to 1.2 times |
| the whole-GEMM unit | 1.2 to 1.7 million | about 4 to 8 times |

So **yes, the yes and likely operations roughly double the logic of the core** (1.6 to 2.3 times at the extremes of both ranges); the block with integer lanes alone adds a third to a half; the tile or a GEMM unit is several times the core. Two things soften it and one does not. *Softens:* the vector floating-point lanes (79,000) could share the multiplier and adder of the scalar floating-point unit if the vector unit were narrow (the figures assume a separate strip of 8 lanes); and the vector unit can be small (4 lanes, half the multipliers) at half the throughput. *Does not:* the register file of 16 vector registers, and the caches and load/store ports for a strip of 256 bits (memory, not counted on either side), which a vector unit needs to be fed.

## Reading it

1. **The block is cheap relative to what it does for the kernels measured** (100,000 to 180,000 gates against 12 to over 100 times fewer operations per element): the multipliers are what a SIMD unit is, and the rest is small.
2. **The yes rows beyond the base cost about 25,000 gates**: the reductions, the saturation, the nibble shifts and the window on shared multipliers are almost free once the base exists (24,000 to 30,000 in all).
3. **The two "likely" operations that are not free are the micro-kernel's second register file (28,000) and the int8 dot (37,000)**; each is a quarter of the base; the dot product is the one that doubles the inference rate of section 1 of the cost-benefit study (E) and is the best gate-for-gate buy of the likely rows. A smaller register file (the 8 accumulators in 8 registers with the B strip kept in a ninth) would save the 28,000.
4. **Gather and segment loads are logic-cheap (a few thousand gates)**; their cost is in the cache ports and the cycles, which this count does not show.
5. **The tile and the GEMM unit are where the gates are** (hundreds of thousands to over a million), as the cost-benefit study's reading said; their benefit is the prefill and batched work, not the decode of one token.
