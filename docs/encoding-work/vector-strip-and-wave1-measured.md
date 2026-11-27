# The 16-byte strip and the wave-1 removals, judged on run time

[← encoding work](README.md) · errata 210, items 5 · measurements in `bench/vecwave1/` (read its README first)

Written 2026-11-27. Nothing is changed in the grammar, the manual or the simulator; this is a recommendation.

## What I recommend

1. **The strip of an accumulator block: keep 16 bytes.** It costs run time only in one kernel, the register-blocked matrix micro-kernel, and only on an implementation wider than 16 bytes; a wide implementation gets that time back by issuing two or four of the 16-byte multiply-adds at once (1.6 and 2.3 times, counted in the model), which needs no new instruction and no new state. Every other accumulating loop I measured (integer dot products, sums of floating point, filters) has no accumulator block and does speed up with a wider strip. *What it heals:* the same answer on every width, and a hidden state that is the program's own. *What we lose:* a wide machine needs a second issue slot to run a matrix multiply at its width.
2. **The tile (`vtfmopa`): keep it removed.** In the model it makes the micro-kernel 3.5 times faster at a 32-byte strip, but only with an array of VL x VL multiply-adders (the survey's 260,000 to 665,000 NAND2, an estimate I could not check), only 1.2 times at the 16-byte strip, and the program has to know VL to pack its panels, which the invisible strip forbids. *What we lose:* about 2 times on a matrix multiply that the issue-width route (1.6 to 2.3 times) does not give back.
3. **The whole-GEMM unit (`gemm.f`): keep it removed.** 5 to 9 times the micro-kernel in the model, but it is memory-bound at the port (576 cycles of traffic against 256 of arithmetic for my size), it is a device's job (the engine route of chapter 8), and one instruction that runs for the whole matrix is the restart problem the survey found.
4. **The gather (`vldx`): keep it removed, unless you name sparse work as a goal.** On a sparse matrix-vector product it is 2.5 to 3.6 times faster than the scalar loop (up to 5.8 times with four address ports); for a 256-entry byte table the instruction we kept (`vtbl.b`, used sixteen times) is within 13 percent of a gather that does a lane a cycle. If sparse kernels, graph work or large embedding lookups are a stated goal, restore a small 32-bit gather (that is the one decision I leave to you).
5. **Found on the way:** `vdot.b` into an accumulator runs 6.3 times slower than the `vdacc.b` that replaced it (the 32-bit accumulator lane makes the strip four bytes). Nothing compiled uses `vdot`, `vdotu` or `vdotsu`. I recommend removing the three words (Occam); this is a count from one kernel and the strip rule of section 8.3 of `vec-isa.md`, and is for you to confirm.

## What the two items were

* **The strip.** A `vec` block runs on strips whose width is the implementation's. A block that names accumulators (`vclr`, `vfmab`, `vfin`) runs on exactly 16 bytes on every implementation, so that the hidden partial sums, and a floating-point result, are the same on a 128-bit and a 512-bit machine (`vec-isa.md` 8.4). The alternatives the notes name (`rejudge-accepted-recommendations.md` item 2): a fixed 32-byte tile (the accumulator registers double on the small machine, 61,578 against 30,869 NAND2 *as that note states, not rechecked*), or a fixed order of the final sum that lets the strip vary.
* **Wave 1** (errata 170) removed the tile (`vtclr vtld vtst vtadd vtfmopa`), `gemm.f` (a whole matrix product from a descriptor) and the gather (`vldx`, 22 words), on static counts of assembly, "clang vectorizes none" and a silicon estimate (1.4 to 2.0 million NAND2 down to 0.22 to 0.30). The 16-entry `vtbl.b` replaced the gather.

## How I measured

*Measured:* cycles of model 1 and model 2 of the current `sim64 -V` (`docs/sim64.md`: a strip costs the larger of its vector instructions and its memory beats, plus one; model 2 adds latencies), port 16 bytes a cycle, commit 1, at strips 16, 32 and 64; instruction counts; the output of every variant hashed, and equal. The kernels are plain C compiled scalar (`llc -O2`) and with LoopVectorize, plus hand-written assembly where the compiler cannot make the form. *The removed words* exist only in the simulator of the commit before wave 1 (`fe84570d~1`), which I rebuilt in a scratch directory: I ran whole programs there, and all four **passed their checks**; that simulator has no cycle model, so I applied model 1 to those programs (`removed/model.py`; it reproduces the current simulator's 652 cycles for the q8 dot, which is its check). *Assumed:* what the old words cost in hardware: a tile outer product in one cycle (or a row a cycle), a gather a lane a cycle (or four lanes), the unit's array of 64 multiply-adders. *Not measured, and why:* caches and misses (the models have none; a sparse product on a real matrix is limited by misses on `x[col]`, so the gather figures are for data in the first-level cache), silicon, power, and real hardware (none exists).

## The numbers

Model 1 cycles for the whole kernel, strip 32, port 16, output equal in every variant (results: `bench/vecwave1/results/current.tsv`). *Measured* (the simulator) unless marked.

| kernel | scalar | LoopVectorize / hand, strip 16 / 32 / 64 | note |
|---|---:|---|---|
| q8 dot, 4,096 bytes | 24,588 | `vdacc` 1,036 / 652 / 588 | 8,192 bytes read at 16 a cycle is 512 cycles: 79% of the memory floor at 32 |
| q8 dot, accumulator form `vdot.b` | | 4,111 / 4,111 / 4,111 | the 4-byte strip: 6.3 times `vdacc` at 32 |
| q8 matrix-vector, 64 x 256 | 98,965 | 5,080 / 3,544 / 3,288 | memory-bound: a decode step reads each weight once |
| 1-D convolution, 2,048 x 8 taps | 110,609 (LLVM does not vectorise it: 71,709) | `vfir` 5,657 / 2,841 / 1,433 | scales with the strip |
| 3 x 3 convolution, 32 x 32 | 30,035 | 8,303 / 5,871 / 5,807 | |
| f32 matrix product 16 x 16 x 64, dot form | 101,100 | 23,817 / 15,625 / 12,553 | no accumulator block: the strip is free |
| same, micro-kernel (accumulator block) | | 5,568 / 5,568 / 5,568 | fixed 16 bytes; plus 12,593 scalar instructions of packing (measured) |
| 256-entry byte table, 4,096 bytes | 20,496 | `vtbl.b` x 16 (hand): 13,872 / 6,960 / 3,504 | |

**The strip question, the micro-kernel on its own** (*counted* with model 1 where the issue width is the one changed assumption; `bench/vecwave1/widths.py`; measured at width 1):

| way | cycles | against the measured kernel |
|---|---:|---:|
| fixed 16 bytes, issue 1 (measured) | 5,568 | 1.0 |
| the same, issue 2 | 3,448 | 1.6 |
| the same, issue 4 | 2,424 | 2.3 |
| a fixed 32-byte tile, issue 1 | 2,812 | 2.0 |
| the dot form with a free strip at 64 bytes (measured) | 12,553 | 0.44 |

So the fixed strip makes the micro-kernel the same on every machine, which is its aim, and the cost is 2 times at 256 bits and about 4 times at 512 on a single-issue vector unit, the same as the 32-byte tile gives at 256 bits and less at 512. Packing is 6.15 instructions an element (measured); for a 256-cube product it is 15% of the micro-kernel's cycles, for a 1,024-cube 3.8% (counted), so packing the weights is not what limits inference.

**The removed words** (*assumed* costs; the programs themselves were run and passed):

| word | kernel | model 1 cycles | against |
|---|---|---:|---|
| tile, strip 32 (8 x 8) | 16 x 16 x 64 | 1,580 (outer product in a cycle), 3,116 (a row a cycle) | micro-kernel 5,568: 3.5 and 1.8 times |
| tile, strip 16 / 64 | same | 4,720 / 795 | 1.2 and 7.0 times |
| `gemm.f`, array of 64 | same | 613 to 1,125 (traffic floor to tile-reload traffic; arithmetic alone 256) | 9.1 to 4.9 times |
| gather, a lane a cycle | SpMV, 256 rows, 4 / 16 / 64 non-zeros a row | 4,352 / 9,472 / 32,512 | scalar 10,773 / 32,277 / 118,293 (measured): 2.5, 3.4, 3.6 times |
| gather, four lanes a cycle | same | 3,584 / 6,400 / 20,224 | 3.0, 5.0, 5.8 times |
| gather, a lane a cycle | 256-entry table | 6,157 (4 lanes: 3,085) | `vtbl.b` x 16: 6,960 at strip 32, 3,504 at 64 |

The tile and the gather also show a width problem the numbers hide: the tile grows with VL squared, the gather does not grow with the strip at all (a lane a cycle), while the `vtbl` form halves when the strip doubles.

## Judged by the principles, in order

1. *Safety.* The 16-byte strip is the safe choice: the accumulators are the program's own and restart from the block's entry. **The tile** adds the largest hidden state in the family, partial results across strips, and its shape depends on VL, so the program would see the width or the architecture would have to fix a tile size (the same trade as the 32-byte option). **`gemm.f`** is one instruction that runs far past a timer tick; the survey's answer (progress in two registers, restart from a tile) works but it is a device in an instruction. **The gather** has no hidden state, but the addresses depend on the data, so the cache timing does; `vtbl.b` is constant-time, which matters for a cipher's byte table (this is the one safety difference, and it favours what we kept). The gather's per-lane precise fault is solved by checking the strip's addresses first, at a cost the survey put at 4,000 to 6,000 NAND2 *(estimate, not rechecked)*.
2. *Speed (measured).* Above. The only real losses are a matrix multiply on a wide machine, which issue width recovers in the model, and sparse work, which only the gather helps. Matrix-vector work for token generation is memory-bound: it reaches 79% of the memory floor with the instructions we have.
3. *Fewer instructions.* The micro-kernel is 10 instructions per 32 multiply-adds; at a 32-byte tile it would be 10 per 64. The gather replaces about 8 scalar instructions per non-zero (7.2 to 10.5 measured) by under 1 vector instruction.
4. *Density, 5. compiler.* None of the three is made by a compiler today, and the loop vectoriser cannot make the micro-kernel (`llvm/vector-usage.md`); hand kernels and libraries (OpenBLAS-style) would. This is a fact about the compiler, so I do not weigh it.
6. *Coherence.* Removing the three keeps the family lane-local plus `vtbl` and the segment loads; the fixed accumulator strip is one rule.

## What would change these

* The strip: if the owner wants a matrix multiply at the machine's full width without a second issue slot, change to the 32-byte tile, at +30.7k NAND2 on the small machine *(that note's figure)*; or if fetch and decode, not arithmetic, limit the loop (my model counts each vector instruction as one cycle and ignores fetch).
* The tile: a measured prefill workload where the matrix product is most of the run time, **and** a stated silicon budget, **and** an architectural tile size that does not depend on the strip.
* The gather: sparse kernels, graphs or embeddings named as goals; measured miss behaviour on a real matrix (which my models cannot show and which would probably lower the gain, since the loop waits on memory).

## Limits, stated plainly

The models are mine and the survey's: one cycle a vector instruction, no cache, a single memory port. The three removed words' costs are assumed. The kernels are small (one product of 16 x 16 x 64; at larger sizes packing is a smaller share, see the packing line above). The compiled and the hand-written kernels differ in quality; I did not tune the scalar baseline beyond LLVM `-O2`. No other machine's numbers are used here.
