# Latencies from logic depth: a second cycle model for the vec blocks, and what it changes

**Note (errata 173 to 175, 2026-11-18): the strip is now invisible to programs, and its least value is 16 bytes (128 bits).** The 8-byte columns of this study are for the cycle study only (a strip of 8 bytes is outside the architecture: `sim64 -S 8` warns); the table lookup `vtbl.b` has only its memory form (the class `tbl`'s `w_vtbl_g16` block is the 16-way multiplexer of both); a floating-point sum (`acc` class, `vacc.f`/`.d`) is in a canonical order of 16-byte chunks, so its latency is the chain of `strip/16` adds through the register: model 2 charges one `fma`-class latency for each chunk after the first, model 1 one cycle for each chunk (`vec-isa.md` 8.5); the class `misc` is `vclr` alone (`vlen` is gone). The conclusions below were measured before this change and stand for every kernel that has no floating-point sum.

**Status: a measurement and a model, 2026-11-18, the assistant's work, for the owner to read; it changes no grammar, manual or encoding.** The owner's question was: "would yosys emit information we could feed to sim64 about expected cycles etc?" The answer given was: yosys gives area and logic **depth** (the `ltp` pass prints the longest topological path of a flattened module; on an FPGA mapping the depth is in LUT levels), not delay and not cycles. Cycles = depth x an **assumed** delay per level / a **chosen** clock period, rounded up; throughput, the pipeline structure and the memory are design decisions and stay parameters. This document does that: it measures the depth of the blocks of the strip study ([vec-strip.md](vec-strip.md)), converts it to latencies under stated assumptions, feeds the latencies to a **second cycle model** in `sim64` (beside the first, which is unchanged and still the default), and compares the two on the benchmark kernels.

**Limits, first.**

1. **Depth is not delay.** A level of the NAND2 flow, of the LUT4 flow, of the LUT6 flow is a count of cells on the longest path. The delay per level (routing included on an FPGA), the clock period, the register overhead of a pipeline stage, the cycles of a multiplier primitive are **assumptions** (section 2); the latencies in the tables are derived from them and are not measurements. `nextpnr` and Vivado are not installed: there is no placed-and-routed Fmax anywhere in this document.
2. **The blocks are the study's behavioural Verilog, written to count area, not to be fast.** Their depth is therefore an upper bound on what a timing-driven design would have. Two causes were found: (a) the lane ALU, the shifts with rounding and the conversions chain byte-wide adders and muxes through *all* bytes of the strip (the carry of a lane that stops at a lane boundary is a structural path that the tools cannot see is false), so the depth measured at 256 bits (35.7 LUT4 levels, 321 gates) is a property of the description, and the same block at 64 bits has 35.3 and 315: the lane-local classes use the 64-bit measurement (the widest lane is 8 bytes), the trees and networks the measurement at the strip itself; (b) `vmaxacc` is a chain of compares (177 LUT4 levels at 256 bits; a tree would be about 20 or fewer) and the floating-point multiply-add is one behavioural block (93 LUT4 levels). **The ASIC column (NAND2 levels) is the worst case of this**: an ALU of 315 gate levels needs 37 cycles at 0.075 ns a level and a 0.75 ns clock. No one would build that; the ASIC numbers say "the study's RTL, as it is, on an ASIC" and nothing about a designed ASIC.
3. The model is **in order, with a scoreboard and no chaining, with a single memory port**, as the task fixed it; real designs with chaining, a decoupled load unit or register renaming would be nearer model 1 (section 5 shows how much each assumption costs).
4. The kernels are the 41 with a vec block of `llvm/bench` (the `lv` build, 40, and the hand-written `k_sad`), 1,000 elements each: not a workload. **None of the 41 blocks has a hidden accumulator (`vclr`) or reads a scalar register that one of its reductions writes**, so those two parts of model 2 (loop-carried latency through a v register, the scalar dependence) were exercised only by `tests/sim/vec-restart.S` (175 blocks with a hidden accumulator; counters, no cycle claim), and by a 6-instruction program written for the check (scalar dependence: `--vpipe=4` gave the same cycles as `--vpipe=1`, as it must, and the same block without the dependence gained 62 cycles of 391).
5. The FPGA numbers use LUT4 levels of `synth_ecp5` (yosys 0.52); the LUT6 levels of `synth_xilinx -family xc7` are listed beside them and not used. A DSP block's own latency is a parameter (1 to 3 cycles). The multiplier depth in the tables counts the LUTs around the multiplier primitive only.

## Headline

| | model 1 (vec-strip.md) | model 2, fpga table, vpipe 1, vmemlat 4 | model 2, fpga, vpipe 4 | model 2, asic table, vpipe 1 |
|---|---|---|---|---|
| geometric mean of cycles, model 2 / model 1, 41 kernels, strip 32, port 16 | - | **2.29** (best kernel 1.19 k_softmax, worst 6.37 k_vtxaos) | 2.05 (vpipe 2: 2.05) | 7.21 (worst 33.8) |
| 128-bit strip against 256-bit, port 16, geometric mean slowdown (worst kernel) | **1.53** (k_quant 1.98) | 1.60 (k_blend 1.99) | 1.55 | 1.79 |
| 64-bit strip against 256-bit, port 16 | 2.80 | 2.99 | 2.90 | 3.35 |
| 128-bit, port 8 / port 32 | 1.14 / 1.78 | 1.41 / 1.83 | 1.42 / 1.82 | 1.72 / 1.88 |
| kernels (of 36 not scalar-dominated) whose vector cycles stay (ratio 1.2 or less) when the strip halves from 32 to 16: port 8 / 16 / 32 | 31 / 2 / 0 | 3 / 0 / 0 | 1 / 0 / 0 | 0 / 0 / 0 |

* **Model 2 costs more than model 1, by a factor of 2.3 on an FPGA with the assumed delays** (2.05 with two or more strips in flight; 2.0 to 2.85 for a memory latency of 2 to 8 cycles), because model 1 lets every instruction of a strip issue back to back, and in model 2 the dependent ones wait for the latency of the one before. The ratio is not a prediction of a design: the table is assumed and the RTL is not timing-driven (limit 2).
* **Does any conclusion of vec-strip.md change? The recommendation of a 128-bit strip: no. The slowdown of narrower strips: hardly. The memory-bound / compute-bound split: yes.** (1) The geometric-mean slowdown of a 128-bit strip at a 16-byte port is 1.53 in model 1, 1.54 to 1.67 in model 2 (fpga table, vpipe 1 or 4, memory latency 2 to 8) and 1.79 with the asic table: always below 2, worst kernel 1.99; the 64-bit strip 2.80 against 2.86 to 3.35; so the saving of half the logic for 1.5 to 1.8 times the vector time is the same trade as before. (2) What does change is the split: in model 1, with a port of 8 bytes, 31 of the 36 kernels were memory-bound (the vector cycles did not change when the strip halved); in model 2 only 3 are (1 with strips in flight), at a port of 16 bytes 2 become 0. The cause is that a strip now has a latency chain that every strip pays (a load of 4+ cycles, the arithmetic, the store), so halving the strip doubles the number of chains; the memory port is no longer the only bound, and the geometric-mean slowdown of a 128-bit strip at port 8 is 1.41 (not 1.14): **the argument "a narrow port makes the strip width irrelevant" is weaker than vec-strip.md said**, unless the implementation overlaps strips (below).
* **Strips in flight help little in this model: vpipe 2 is 2.05 and vpipe 4 is 2.05 against 2.29 for 1** (asic 5.94, 5.54 against 7.21). Issue is in order: the first instruction that waits for a result stops every instruction behind it, the next strip's loads included; only the tail of a strip (the reductions' trees, the stores) overlaps the next start. A design that wants model 1's numbers needs an issue that is not stalled by a dependent instruction (a decoupled load unit, or chaining), not more strips in flight.
* **Which latencies matter** (section 5.3; one class set to latency 1, ld and st to 0, all else as the fpga table; geometric mean over the 41 kernels at strip 32): the **binary32 multiply-add (`fma`, 10 cycles, used by 11 kernels, 3,523 instructions)**: 0.846, that is 15% of the time (k_vtxaos gains most: to 0.32), the largest by far; the lane ALU (4 cycles, 9 kernels): 0.961; `fma64` (6 cycles, 6 kernels): 0.948; `st` (the store merge, 1 cycle on top of the memory): 0.961; `dacc` (5, 3 kernels): 0.980; `acc` (2, 7 kernels): 0.988; every other class less than 1%. In the asic table the same order with larger effects (fma 0.70, alu 0.84, fma64 0.82, dacc 0.92, acc 0.92). **And the memory latency, a parameter and not a class, matters more than any one class: 2.00 at 2 cycles, 2.29 at 4, 2.85 at 8.** The classes worth redesigning or fusing, in this order: the floating-point multiply-add (depth 93 LUT4 levels as one behavioural block: a pipelined design or a fused one), the lane ALU (the byte-chained carry), `vmaxacc` (a chain, 18 cycles; only k_softmax uses it, 0.997 if it were 1 cycle: not worth it for these kernels), and the load path as a whole.

## 1. Method

**Depth.** `tools/gates/depth-synth.sh` runs, for each module and strip, the three flows of [vec-strip.md](vec-strip.md) section 2 (the same commands as `strip-synth.sh`): (a) `synth -flatten; abc -g NAND` (levels of 2-input NAND and NOT), (b) `synth_ecp5` (LUT4; yosys flattens), (c) `synth_xilinx -family xc7 -flatten` (LUT6). After each it runs `ltp -noff` (yosys's longest topological path) and `write_json`, and `tools/gates/lat-depth.py` computes the longest path from the netlist again with weights. **Why two numbers:** `ltp` counts every cell as one level, and on both FPGA flows a carry cell (a `CCU2C` is 2 bits of an adder, a `CARRY4` 4) is as much as a LUT, though a carry hop is a tenth of a LUT in time: the `ltp` of the lane ALU in the ECP5 flow is 100 levels, of which 36 are LUT levels. `lat-depth.py` weights (ASSUMED, in its header): a LUT 1; PFUMX / L6MUX21 / MUXF7/8 0.5; a carry hop CIN to COUT 0.1, CIN to a sum bit 0.5, a CARRY4 input to its outputs 0.3; I/O buffers 0; a multiplier primitive (`MULT18X18D`, `DSP48E1`) 0, counted separately as `dsp` on the path (the path is chosen by levels + 4 x dsp). On the NAND2 flow the weighted number is `ltp`. **`sta` adds nothing**: it does not know the cells of the NAND flow (`$_NAND_` is "not recognised") and on ECP5 it stops at every carry cell (`CCU2C`, `PFUMX`, `L6MUX21` "have no timing arcs"). The modules are the ones named in section 3; the new file `tools/gates/latw.v` holds two chains of classes (`lat_cmpsel`: compare then select, `lat_alushift`: ALU then shift) to show what fusing them costs in depth. `vcmp_mw` in the Xilinx flow is the study's form with a dynamic shift (90,000 LUT6): `vcmp2` is used.

**Latency.** `tools/gates/lat-table.py`: latency = max(1, ceil(levels x delay per level / (clock period - register overhead))) + (multiplier primitives on the path) x (DSP cycles); `ld` and `st` are that minus the cycle of the cache access (0 allowed). **Assumed, with a range** (lo / mid / hi; the mid column is the built-in table and the default):

| family | levels | delay per level | clock | register overhead per stage | cycles of a multiplier primitive |
|---|---|---|---|---|---|
| FPGA (ECP5-like) | LUT4 levels | 0.6 / **0.9** / 1.2 ns (routing included) | 10 ns (100 MHz) | 0.5 / **0.75** / 1.0 ns | 1 / **2** / 3 |
| ASIC-ish | NAND2/NOT levels | 0.05 / **0.075** / 0.1 ns | 1.0 / **0.75** / 0.5 ns (1 to 2 GHz) | 0.1 ns | 0 (a multiplier is logic) |

Every class is pipelined (interval 1). The classes combine the blocks (section 3): the lane-local classes take the depth at the 64-bit strip (limit 2a), the trees and networks the depth at the strip itself, so the tables have values for 8, 16 and 32 bytes; a strip of 64 bytes takes the 32 values. `fir` (a multiply and the window add) and `fma64` (the four blocks of `core.v` in a row) are **estimates** of summed depths, not synthesised blocks. The depth of a DSP-based multiplier (`ms16_lo`: 1 LUT level and 1 DSP) is mostly the DSP's own latency: with 1 to 3 cycles for it the `mul16` latency is 2 to 4.

**The model in sim64** (`docs/sim64.md` is the reference; `common/pdp64exec_vec.inc` has the code, a counter only): per block, instructions issue in order one a cycle; a scoreboard on v0..v15 (no chaining); an instruction waits for its sources, for the unit of its class (interval), for an older pending write of its destination, and for the one memory port; a load's data is ready `--vmemlat` (default 4) + the `ld` class cycles after its last beat; a reduction adds into its scalar register when its tree is done; a strip ends when its last result and store are done plus the commit cost (1); `--vpipe=N` strips in flight; a hidden accumulator (a `vclr` register) keeps its ready time from strip to strip; a block that reads a scalar register its reduction writes does not overlap strips; scalar instructions 1 cycle each, as in model 1 (**neither model has the latency of the scalar multiplier, the divider or loads**; the scalar part of both totals is the same number). Options: `--latency=fpga|asic|FILE`, `--vpipe=N`, `--vmemlat=N`, `--vmix` (the number of instructions run in each class); the tables as text are `sim64/latency-fpga.txt` and `sim64/latency-asic.txt` (the built-in defaults are `sim64/vlatency-defaults.h`, generated). **Model 1 is unchanged, is the default, and its `-V` line is as it was**: model 2 adds a line. The kernels are built and run as `tools/strip-bench.py` does (`tools/lat-bench.py` runs its build code, then 280 configurations of strip, port, table, vpipe, vmemlat, and one class set to latency 1 at a time). Run: `tools/gates/run-latency.sh` (section 7).

**Checks.** The results of the programs do not depend on the models: for all 47 programs, the exit status and a hash of every global array are identical over all 280 configurations, and identical to a run without `-V` (the counters are off). `tools/check-all.sh` exits 0, `qemu/sync.sh --check` is clean, `llvm/check.sh` passes (61, 5, 21, 5, 21, 84). QEMU was not rebuilt: the model-2 state is a runtime flag (`vm2`) that only `sim64 -V` sets; the code is in the shared `.inc`, so it compiles into QEMU but is never run there (not compiled out: unverified that the QEMU build is unaffected). The model with the unit table (every class 1 cycle, ld and st 0), 16 strips in flight and a memory latency of 1 is not model 1 (geometric mean of model 2 / model 1 1.04, range 0.76 to 1.67): model 1 lets a strip's instructions issue back to back while model 2 issues in order and the memory port holds a load for its beats and then its latency; it is a sanity check of the order of magnitude, not an identity.

## 2. What was assumed, what was measured, what is derived

* **Measured** (yosys 0.52, behavioural Verilog of the study): the longest path in levels of each block and strip (section 3), the instruction counts and the model's cycles (section 5; sim64 is deterministic).
* **Assumed**: the weights of carry hops and muxes in a level; the delay per level, the clock, the register overhead, the cycles of a multiplier primitive (table in section 1); that every class is pipelined to interval 1; that a lane-local class has the depth of its 8-byte slice; the load latency (4 cycles, 2 and 8 as sensitivity); in-order issue without chaining; one memory port; the renaming of v registers per strip in flight.
* **Derived**: every latency in the second table of section 3, from the two above.
* **Not verified**: any post-place-and-route delay; that a designer could pipeline each block into the number of stages the formula gives (a block with a feedback, an iterative divider, cannot, and the divider is not in the vector table); the area cost of the pipeline registers (not in the gate counts of vec-strip.md, which are combinational with the study's registers: a block pipelined into 4 stages needs flip-flops for its width at each cut); the DSP latency of 2 cycles as a typical value.

## 3. Depth and latency tables

The first table is every block (`ltp` is yosys's own number, in cells; the others are the weighted levels of section 1). The second is the classes and the cycles that follow under the assumptions. The third is the scalar core's long operations: they are **not** used by sim64 (both models count 1 cycle for each scalar instruction); the divider's iteration depth is the cycle time of a 1-bit-a-cycle divider, 64 cycles when an iteration fits a clock (known), and `mul64` is also the `mul64` class (the `vmul.q` lane multiplier is assumed to be that multiplier).

### 3.1 Depth of every block (longest path in levels: NAND2/NOT gates; ECP5 LUT4 levels, carry hops 0.1 and PFUMX/L6MUX21 0.5; Xilinx LUT6 levels, carry hops 0.1 and MUXF 0.5), strips of 32 / 16 / 8 bytes where the block is parameterised

| block | nand 32 / 16 / 8 | ltp nand 32 | ecp5 32 / 16 / 8 | ltp ecp5 32 | xc7 32 / 16 / 8 | ltp xc7 32 | multiplier primitives on the critical path (ecp5, xc7, at 32) | cells on the ecp5 path (32) |
|---|---|---:|---|---:|---|---:|---|---:|
| w_lanealu_mw | 321 / 319 / 315 | 321 | 35.7 / 35.7 / 35.3 | 100 | 119.7 / 63.7 / 35.9 | 269 | 0, 0 | 97 |
| w_lanealu_mw_noavg | 317 / 319 / 314 | 317 | 35.7 / 35.7 / 35.2 | 100 | 120.5 / 63.2 / 36.4 | 269 | 0, 0 | 97 |
| w_shiftround_mw | 164 / 163 / 166 | 164 | 19.5 / 19.5 / 18.5 | 29 | 28 / 28 / 28 | 43 | 0, 0 | 28 |
| w_shiftlane_mw | 38 / 38 / 37 | 38 | 10 / 10.5 / 10 | 14 | 8.5 / 8.5 / 8.5 | 14 | 0, 0 | 14 |
| w_narrow_both | 48 / 50 / 48 | 48 | 13.9 / 13.4 / 13.2 | 31 | 10.7 / 10.7 / 10.3 | 23 | 0, 0 | 31 |
| w_ms8x8 | 266 / 271 / 251 | 266 | 23.7 / 21.3 / 19 | 64 | 18.5 / 14.9 / 13.4 | 45 | 1, 2 | 63 |
| w_ms8x8_notree | 123 / 121 / 122 | 123 | 13.9 / 13.4 / 13.9 | 28 | 8.9 / 8.9 / 9.3 | 20 | 1, 2 | 20 |
| w_dacc_tree | 143 / 147 / 127 | 143 | 9.9 / 7.4 / 5.5 | 38 | 5.7 / 5.7 / 3.2 | 22 | 0, 0 | 38 |
| w_vacc_naive | 173 / 168 / 150 | 173 | 17.4 / 15.1 / 11.8 | 46 | 14.7 / 11.3 / 9.7 | 33 | 0, 0 | 44 |
| w_vmmacc | 532 / 274 / 145 | 532 | 177.1 / 89.1 / 45.1 | 1058 | 151 / 78.6 / 37.3 | 306 | 0, 0 | 1055 |
| w_sum_bu | 172 / 162 / 150 | 172 | 14.8 / 12.7 / 9.9 | 44 | 11.1 / 8.6 / 5.7 | 29 | 0, 0 | 44 |
| w_vsad_bu | 192 / 182 / 170 | 192 | 17.8 / 16.2 / 13.4 | 50 | 14.3 / 12.8 / 10.5 | 35 | 0, 0 | 49 |
| w_vfir_added | 69 / 69 / 69 | 69 | 4.5 / 4 / 4 | 112 | 3.8 / 3.4 / 3.4 | 137 | 0, 0 | 5 |
| w_vtbl_g16 | 13 / 13 / 9 | 13 | 4 / 4 / 2.5 | 6 | 3 / 3 / 2 | 6 | 0, 0 | 6 |
| w_vcmp_mw | 30 / 32 / 30 | 30 | 8.5 / 8 / 7.5 | 36 | 137.5 / 138.5 / 134.9 | 497 | 0, 0 | 11 |
| w_vcmp2 | 30 / 30 / 28 | 30 | 8 / 7.5 / 7 | 35 | 7.7 / 7.7 / 7.6 | 15 | 0, 0 | 10 |
| w_vbsl | 3 / 3 / 3 | 3 | 1 / 1 / 1 | 1 | 1 / 1 / 1 | 3 | 0, 0 | 1 |
| lat_cmpsel | 31 / 33 / 33 | 31 | 8.9 / 8.5 / 7.5 | 36 | 7.7 / 8.1 / 7.7 | 15 | 0, 0 | 24 |
| lat_alushift | 490 / 488 / 480 | 490 | 51.8 / 51.5 / 52.1 | 124 | 147.9 / 94.1 / 67.7 | 306 | 0, 0 | 107 |
| w_segload | 15 / 15 / 13 | 15 | 4.5 / 5 / 4 | 7 | 3.5 / 3.5 / 3 | 7 | 0, 0 | 7 |
| w_segstore | 19 / 19 / 17 | 19 | 6.5 / 6 / 5.5 | 10 | 5 / 5 / 4.5 | 9 | 0, 0 | 10 |
| w_vmem_ld | 24 / 21 / 19 | 24 | 9 / 8 / 6.5 | 13 | 6 / 6.5 / 5.5 | 10 | 0, 0 | 13 |
| w_vmem_st | 32 / 18 / 10 | 32 | 10.9 / 8 / 6.3 | 40 | 6.2 / 4.4 / 4 | 23 | 0, 0 | 37 |
| w_vregs16_r3 | 11 / 11 / 11 | 11 | 1 / 1 / 1 | 1 | 1 / 1 / 1 | 4 | 0, 0 | 1 |
| w_cvt_both | 193 / 191 / 182 | 193 | 33.1 / 30.5 / 28.1 | 66 | 17.6 / 17.5 / 17.5 | 41 | 0, 0 | 66 |
| w_fma32xn | 553 / 547 / 555 | 553 | 95.8 / 94.3 / 90.5 | 178 | 45.7 / 45.5 / 46.7 | 86 | 0, 0 | 172 |
| ms16_lo | 55 | 55 | 1 | 2 | 1 | 4 | 1, 1 | 2 |
| ms16_hi | 98 | 98 | 6.3 | 15 | 4.9 | 14 | 1, 1 | 15 |
| ms16_hi_mla | 92 | 92 | 6.3 | 15 | 5.4 | 15 | 1, 1 | 15 |
| ms16_all | 101 | 101 | 8 | 22 | 7.9 | 18 | 1, 1 | 19 |
| mul32s | 146 | 146 | 5 | 25 | 2.8 | 17 | 1, 2 | 25 |
| fma32x8 | 558 | 558 | 94.8 | 187 | 47.7 | 91 | 0, 0 | 178 |
| fma32 | 535 | 535 | 93.4 | 175 | 46.5 | 86 | 0, 0 | 166 |
| cvt_i2f | 208 | 208 | 28.2 | 61 | 17 | 40 | 0, 0 | 59 |
| cvt_f2i | 73 | 73 | 15.3 | 32 | 10.1 | 21 | 0, 0 | 32 |
| alu64 | 136 | 136 | 9.6 | 38 | 9.3 | 26 | 0, 0 | 38 |
| shift64 | 24 | 24 | 7.5 | 12 | 6.5 | 11 | 0, 0 | 10 |
| bitops64 | 85 | 85 | 12 | 18 | 133.4 | 210 | 0, 0 | 16 |
| mul64 | 221 | 221 | 10.5 | 68 | 7.2 | 39 | 1, 4 | 67 |
| div64 | 129 | 129 | 5.6 | 352 | 4.3 | 356 | 0, 0 | 34 |
| tlb32 | 24 | 24 | 7 | 10 | 8 | 17 | 0, 0 | 7 |
| ldalign | 13 | 13 | 5.5 | 8 | 3.5 | 6 | 0, 0 | 8 |
| stmerge | 11 | 11 | 3.5 | 5 | 2.5 | 5 | 0, 0 | 5 |
| clmul64 | 24 | 24 | 5.5 | 8 | 5.5 | 10 | 0, 0 | 8 |
| mul53 | 167 | 167 | 9 | 56 | 4.8 | 30 | 1, 4 | 56 |
| shr106 | 16 | 16 | 7 | 10 | 5 | 8 | 0, 0 | 10 |
| add106 | 139 | 139 | 6.6 | 53 | 4.3 | 30 | 0, 0 | 53 |
| norm106 | 140 | 140 | 18 | 26 | 21.5 | 36 | 0, 0 | 25 |

levels of the xc7 flow for `w_vcmp_mw` are an artefact of the study's own form of the compare (a dynamic shift: it maps to 90,000 LUT6, vec-strip.md section 3); `w_vcmp2` is the fixed-comparator form that the class uses.

### 3.2 The classes: the blocks, the depth at strip 32 (and 16, 8 where it differs), and the latency in cycles under the assumed delays

| class | what | blocks (mode) | NAND2 levels 32 / 16 / 8 | LUT4 levels 32 / 16 / 8 | DSP on path (ecp5) | LUT6 levels 32 | fpga-lo | **fpga** | fpga-hi | asic-lo | **asic** | asic-hi | fpga / asic at strip 16 | at strip 8 |
|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| alu | lane ALU add sub logic min max abs average, saturating | w_lanealu_mw (local) | 315 | 35.3 | 0 | 35.9 | 3 | **4** | 5 | 18 | **37** | 79 | 4 / 37 | 4 / 37 |
| cmp | vceq vcgt vcgtu | w_vcmp2 (local) | 28 | 7 | 0 | 7.6 | 1 | **1** | 1 | 2 | **4** | 7 | 1 / 4 | 1 / 4 |
| bsl | vbsl | w_vbsl (local) | 3 | 1 | 0 | 1 | 1 | **1** | 1 | 1 | **1** | 1 | 1 / 1 | 1 / 1 |
| shift | vshl vshr vsar and the rounding vsarr vshrr | w_shiftround_mw (local) | 166 | 18.5 | 0 | 28 | 2 | **2** | 3 | 10 | **20** | 42 | 2 / 20 | 2 / 20 |
| narrow | the narrowing of vsts (rounding shift, saturation) | w_narrow_both (local) | 48 | 13.2 | 0 | 10.3 | 1 | **2** | 2 | 3 | **6** | 12 | 2 / 6 | 2 / 6 |
| mul8 | vmul.b and the 8 x 8 products of vdot.b | w_ms8x8_notree (local) | 122 | 13.9 | 1 | 9.3 | 2 | **4** | 5 | 7 | **15** | 31 | 4 / 15 | 4 / 15 |
| mul16 | vmul.w (low half) | ms16_lo (fixed) | 55 | 1 | 1 | 1 | 2 | **3** | 4 | 4 | **7** | 14 | 3 / 7 | 3 / 7 |
| mulh16 | vmulh vmulhu vmulhr vmla on halfwords | ms16_hi_mla (fixed) | 92 | 6.3 | 1 | 5.4 | 2 | **3** | 4 | 6 | **11** | 23 | 3 / 11 | 3 / 11 |
| mul32 | vmul.l and 32-bit multiplies | mul32s (fixed) | 146 | 5 | 1 | 2.8 | 2 | **3** | 4 | 9 | **17** | 37 | 3 / 17 | 3 / 17 |
| mul64 | vmul.q: the scalar 64 x 64 multiplier as the lane multiplier | mul64 (fixed) | 221 | 10.5 | 1 | 7.2 | 2 | **4** | 5 | 13 | **26** | 56 | 4 / 26 | 4 / 26 |
| dot | vdot vdotu vdotsu (the larger of the byte and the halfword form) | w_ms8x8_notree (local), ms16_all (fixed) | 122 | 13.9 | 1 | 9.3 | 2 | **4** | 5 | 7 | **15** | 31 | 4 / 15 | 4 / 15 |
| dacc | vdacc: products, then the reduction tree into a scalar | w_ms8x8 (wide) | 266 / 271 / 251 | 23.7 / 21.3 / 19 | 1 | 18.5 | 3 | **5** | 7 | 15 | **31** | 67 | 5 / 32 | 4 / 29 |
| sad | vsad.bu | w_vsad_bu (wide) | 192 / 182 / 170 | 17.8 / 16.2 / 13.4 | 0 | 14.3 | 2 | **2** | 3 | 11 | **23** | 48 | 2 / 21 | 2 / 20 |
| acc | vacc | w_vacc_naive (wide), w_sum_bu (wide) | 173 / 168 / 150 | 17.4 / 15.1 / 11.8 | 0 | 14.7 | 2 | **2** | 3 | 10 | **20** | 44 | 2 / 20 | 2 / 18 |
| mmacc | vmaxacc vminacc | w_vmmacc (wide) | 532 / 274 / 145 | 177.1 / 89.1 / 45.1 | 0 | 151 | 12 | **18** | 24 | 30 | **62** | 133 | 9 / 32 | 5 / 17 |
| fir | vfir: one tap = a 16-bit multiply and the add of the window (ESTIMATE: the sum of the two blocks) | ms16_lo (fixed), w_vfir_added (wide) | 124 | 5.5 / 5 / 5 | 1 | 4.8 | 2 | **3** | 4 | 7 | **15** | 31 | 3 / 15 | 3 / 15 |
| tbl | vtbl | w_vtbl_g16 (wide) | 13 / 13 / 9 | 4 / 4 / 2.5 | 0 | 3 | 1 | **1** | 1 | 1 | **2** | 4 | 1 / 2 | 1 / 2 |
| lseg | vlseg2..4 de-interleave (after the load alignment) | w_segload (wide) | 15 / 15 / 13 | 4.5 / 5 / 4 | 0 | 3.5 | 1 | **1** | 1 | 1 | **2** | 4 | 1 / 2 | 1 / 2 |
| sseg | vsseg2..4 interleave (before the store merge) | w_segstore (wide) | 19 / 19 / 17 | 6.5 / 6 / 5.5 | 0 | 5 | 1 | **1** | 1 | 2 | **3** | 5 | 1 / 3 | 1 / 2 |
| cvt | vcvt between 32-bit integers and binary32 | w_cvt_both (local) | 182 | 28.1 | 0 | 17.5 | 2 | **3** | 4 | 11 | **21** | 46 | 3 / 21 | 3 / 21 |
| fma | binary32 add sub mul fma (one lane of fma32x8) | fma32 (fixed) | 535 | 93.4 | 0 | 46.5 | 6 | **10** | 13 | 30 | **62** | 134 | 10 / 62 | 10 / 62 |
| fma64 | binary64 add sub mul fma (ESTIMATE: the sum of the four blocks of core.v; not a synthesised block) | mul53 (fixed), shr106 (fixed), add106 (fixed), norm106 (fixed) | 462 | 40.6 | 1 | 35.6 | 4 | **6** | 9 | 26 | **54** | 116 | 6 / 54 | 6 / 54 |
| ld | load alignment and widening, after the memory's own latency (vmemlat) | w_vmem_ld (wide) | 24 / 21 / 19 | 9 / 8 / 6.5 | 0 | 6 | 0 | **0** | 1 | 1 | **2** | 5 | 0 / 2 | 0 / 2 |
| st | store merge | w_vmem_st (wide) | 32 / 18 / 10 | 10.9 / 8 / 6.3 | 0 | 6.2 | 0 | **1** | 1 | 1 | **3** | 7 | 0 / 2 | 0 / 1 |
| misc | vclr: a register write | - | 0 | 0 | 0 | 0 | 1 | **1** | 1 | 1 | **1** | 1 | 1 / 1 | 1 / 1 |

Parameters (ASSUMED): fpga-lo: ecp5 levels, 0.6 ns a level, clock 10 ns, 0.5 ns register overhead a stage, 1 cycles a multiplier primitive; fpga: ecp5 levels, 0.9 ns a level, clock 10 ns, 0.75 ns register overhead a stage, 2 cycles a multiplier primitive; fpga-hi: ecp5 levels, 1.2 ns a level, clock 10 ns, 1 ns register overhead a stage, 3 cycles a multiplier primitive; asic-lo: nand levels, 0.05 ns a level, clock 1 ns, 0.1 ns register overhead a stage, 0 cycles a multiplier primitive; asic: nand levels, 0.075 ns a level, clock 0.75 ns, 0.1 ns register overhead a stage, 0 cycles a multiplier primitive; asic-hi: nand levels, 0.1 ns a level, clock 0.5 ns, 0.1 ns register overhead a stage, 0 cycles a multiplier primitive.

### 3.3 The scalar core's long operations (not used by sim64: both models count 1 cycle a scalar instruction): depth and latency in the same conversion, mid assumptions

| block | what | NAND2 levels | LUT4 levels | DSP on path (ecp5) | LUT6 levels | fpga cycles | asic cycles |
|---|---|---:|---:|---:|---:|---:|---:|
| alu64 | scalar ALU | 136 | 9.6 | 0 | 9.3 | 1 | 16 |
| shift64 | scalar shifts | 24 | 7.5 | 0 | 6.5 | 1 | 3 |
| bitops64 | bit counts and reversal | 85 | 12 | 0 | 133.4 | 2 | 10 |
| mul64 | scalar 64 x 64 multiplier | 221 | 10.5 | 1 | 7.2 | 4 | 26 |
| div64 | one iteration of the divider (64 iterations, 1 quotient bit each: 64 cycles when one iteration fits a cycle) | 129 | 5.6 | 0 | 4.3 | 1 | 15 |
| tlb32 | translation buffer match and read | 24 | 7 | 0 | 8 | 1 | 3 |
| ldalign | scalar load alignment | 13 | 5.5 | 0 | 3.5 | 1 | 2 |
| stmerge | scalar store merge | 11 | 3.5 | 0 | 2.5 | 1 | 2 |
| clmul64 | carry-less multiply | 24 | 5.5 | 0 | 5.5 | 1 | 3 |
| fma32 (scalar) | scalar binary32 fma | 535 | 93.4 | 0 | 46.5 | 10 | 62 |
| mul53 | double-precision multiplier 53 x 53 | 167 | 9 | 1 | 4.8 | 3 | 20 |

## 4. Per kernel

47 programs ran (46 `lv`, 1 hand-written: k_sad; dropped as strip-bench does: k_dctop_fill k_fmac); 41 have a vec block; without: k_put8h k_hist k_ssm k_q4dot k_gray k_clamp8.
280 runs a program over 280 configurations. Results (exit status and a hash of every global array) identical over all configurations: 47 of 47 programs; identical to a run without -V (no model): 47 of 47.

Cycles at strip 32, port 16, commit 1, `vmemlat` 4, `vpipe` 1 unless named. `scalar` is the instruction count of the part outside the blocks (the same in both models). "mix" is the instructions run in each class (`ld` includes `vldt`; `lseg`, `sseg` are separate; classes of at least 5% of the kernel's vector instructions). The whole grid (every strip, port, table, vpipe, vmemlat, and the class runs) is in `tools/gates/latency-results/bench.tsv`; the other tables of the run in `bench.md` there.

| kernel | build | strips | vec instrs | scalar | model 1 total | model 2 fpga | ratio | model 2 asic | ratio | fpga, vpipe 2 | fpga, vpipe 4 | hidden-acc blocks | scalar-dep blocks | mix (instrs at strip 32, classes with 5% or more of the block's instructions) |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| k_sad | hand | 32 | 96 | 130 | 306 | 466 | 1.523 | 1202 | 3.928 | 434 | 434 | 0 | 0 | ld 64 sad 32 |
| k_avg8 | lv | 32 | 128 | 17 | 240 | 463 | 1.929 | 1647 | 6.862 | 432 | 432 | 0 | 0 | ld 64 alu 32 st 32 |
| k_blend | lv | 125 | 1375 | 33 | 1534 | 3159 | 2.059 | 19909 | 12.978 | 3035 | 3035 | 0 | 0 | alu 375 ld 375 shift 250 mul32 250 st 125 |
| k_bytemap | lv | 32 | 96 | 16 | 176 | 399 | 2.267 | 1583 | 8.994 | 368 | 368 | 0 | 0 | alu 32 ld 32 st 32 |
| k_clampr | lv | 125 | 250 | 11 | 512 | 1137 | 2.221 | 2137 | 4.174 | 765 | 765 | 0 | 0 | ld 125 st 125 |
| k_cmul | lv | 63 | 567 | 29 | 846 | 3363 | 3.975 | 15711 | 18.571 | 3239 | 3239 | 0 | 0 | fma 252 alu 126 lseg 126 sseg 63 |
| k_copy16 | lv | 63 | 126 | 15 | 329 | 518 | 1.574 | 770 | 2.340 | 456 | 456 | 0 | 0 | ld 63 st 63 |
| k_daxpy | lv | 250 | 1000 | 12 | 1763 | 4013 | 2.276 | 17013 | 9.650 | 3764 | 3764 | 0 | 0 | ld 500 fma64 250 st 250 |
| k_dctop_fill | lv | 32 | 64 | 192 | 304 | 432 | 1.421 | 1552 | 5.105 | 400 | 400 | 0 | 0 | alu 32 st 32 |
| k_dctop_sum | lv | 32 | 64 | 35 | 132 | 291 | 2.205 | 931 | 7.053 | 229 | 229 | 0 | 0 | acc 32 ld 32 |
| k_ddot | lv | 250 | 1000 | 32 | 1283 | 4033 | 3.143 | 21033 | 16.394 | 3535 | 3535 | 0 | 0 | ld 500 acc 250 fma64 250 |
| k_dequant | lv | 125 | 500 | 15 | 641 | 2516 | 3.925 | 11766 | 18.356 | 2392 | 2392 | 0 | 0 | cvt 125 fma 125 ld 125 st 125 |
| k_dgemv_n | lv | 512 | 2048 | 433 | 3025 | 8657 | 2.862 | 43473 | 14.371 | 7697 | 7697 | 0 | 0 | ld 1024 acc 512 fma64 512 |
| k_dgemv_t | lv | 528 | 2080 | 721 | 4386 | 9058 | 2.065 | 36242 | 8.263 | 8548 | 8548 | 0 | 0 | ld 1024 st 528 fma64 512 |
| k_dger | lv | 512 | 2048 | 683 | 4299 | 8907 | 2.072 | 35531 | 8.265 | 8427 | 8427 | 0 | 0 | ld 1024 fma64 512 st 512 |
| k_dot16 | lv | 63 | 189 | 32 | 347 | 850 | 2.450 | 2614 | 7.533 | 540 | 540 | 0 | 0 | ld 126 dacc 63 |
| k_dscal | lv | 250 | 750 | 10 | 1261 | 3511 | 2.784 | 16511 | 13.094 | 3262 | 3262 | 0 | 0 | fma64 250 ld 250 st 250 |
| k_fmac | lv | 125 | 500 | 12 | 888 | 2513 | 2.830 | 9513 | 10.713 | 2389 | 2389 | 0 | 0 | ld 250 fma 125 st 125 |
| k_i2f | lv | 125 | 500 | 14 | 640 | 2640 | 4.125 | 11890 | 18.578 | 2516 | 2516 | 0 | 0 | cvt 125 fma 125 ld 125 st 125 |
| k_isum | lv | 125 | 250 | 31 | 407 | 1032 | 2.536 | 3532 | 8.678 | 784 | 784 | 0 | 0 | acc 125 ld 125 |
| k_maskblend | lv | 32 | 192 | 21 | 308 | 466 | 1.513 | 690 | 2.240 | 435 | 435 | 0 | 0 | ld 96 cmp 32 bsl 32 st 32 |
| k_mix16 | lv | 63 | 252 | 17 | 457 | 897 | 1.963 | 3228 | 7.063 | 835 | 835 | 0 | 0 | ld 126 alu 63 st 63 |
| k_mla32 | lv | 125 | 625 | 21 | 1147 | 1897 | 1.654 | 4147 | 3.616 | 1773 | 1773 | 0 | 0 | ld 375 mul32 125 st 125 |
| k_mulh16 | lv | 63 | 252 | 17 | 457 | 834 | 1.825 | 1590 | 3.479 | 772 | 772 | 0 | 0 | ld 126 mulh16 63 st 63 |
| k_prep8 | lv | 63 | 189 | 14 | 267 | 581 | 2.176 | 1967 | 7.367 | 519 | 519 | 0 | 0 | shift 63 ld 63 st 63 |
| k_q15mul | lv | 63 | 252 | 17 | 457 | 834 | 1.825 | 1590 | 3.479 | 772 | 772 | 0 | 0 | ld 126 mulh16 63 st 63 |
| k_q8blk | lv | 31 | 93 | 593 | 779 | 1027 | 1.318 | 1895 | 2.433 | 1027 | 1027 | 0 | 0 | ld 62 dacc 31 |
| k_q8dot | lv | 32 | 96 | 32 | 192 | 447 | 2.328 | 1343 | 6.995 | 292 | 292 | 0 | 0 | ld 64 dacc 32 |
| k_quant | lv | 125 | 500 | 12 | 638 | 2763 | 4.331 | 12513 | 19.613 | 2391 | 2391 | 0 | 0 | cvt 125 fma 125 ld 125 st 125 |
| k_relu | lv | 125 | 375 | 16 | 642 | 1517 | 2.363 | 6142 | 9.567 | 1393 | 1393 | 0 | 0 | alu 125 ld 125 st 125 |
| k_rmsnorm | lv | 125 | 375 | 7022 | 7523 | 9273 | 1.233 | 18273 | 2.429 | 9025 | 9025 | 0 | 0 | acc 125 fma 125 ld 125 |
| k_sad | lv | 32 | 96 | 262 | 438 | 598 | 1.365 | 1334 | 3.046 | 566 | 566 | 0 | 0 | ld 64 sad 32 |
| k_sadrow | lv | 32 | 96 | 32 | 192 | 351 | 1.828 | 1087 | 5.661 | 289 | 289 | 0 | 0 | ld 64 sad 32 |
| k_saxpy | lv | 125 | 500 | 12 | 888 | 2513 | 2.830 | 9513 | 10.713 | 2389 | 2389 | 0 | 0 | ld 250 fma 125 st 125 |
| k_sdot | lv | 125 | 500 | 33 | 659 | 2534 | 3.845 | 11534 | 17.502 | 2286 | 2286 | 0 | 0 | ld 250 acc 125 fma 125 |
| k_sgemm_nt | lv | 512 | 2048 | 850 | 3474 | 11154 | 3.211 | 48018 | 13.822 | 10258 | 10258 | 0 | 0 | ld 1024 acc 512 fma 512 |
| k_softmax | lv | 32 | 64 | 3367 | 3464 | 4136 | 1.194 | 5608 | 1.619 | 3758 | 3578 | 0 | 0 | mmacc 32 ld 32 |
| k_split | lv | 63 | 189 | 37 | 601 | 853 | 1.419 | 1168 | 1.943 | 791 | 791 | 0 | 0 | st 126 lseg 63 |
| k_thresh | lv | 125 | 750 | 23 | 899 | 1649 | 1.834 | 2399 | 2.669 | 1525 | 1525 | 0 | 0 | ld 375 cmp 125 bsl 125 st 125 |
| k_vtx | lv | 125 | 3000 | 221 | 3347 | 18722 | 5.594 | 97722 | 29.197 | 18598 | 18598 | 0 | 0 | fma 1500 ld 1125 st 375 |
| k_vtxaos | lv | 32 | 576 | 44 | 653 | 4161 | 6.372 | 22081 | 33.815 | 4099 | 4099 | 0 | 0 | fma 384 alu 128 lseg 32 sseg 32 |

**Which kernels change most, and why.** Highest model 2 / model 1 at the fpga table: **k_vtxaos 6.37 and k_vtx 5.59** (fp32 multiply-add heavy: k_vtx runs 1,500 and k_vtxaos 384 `fma` instructions, 10 cycles each, dependent chains), **k_quant 4.33, k_i2f 4.13, k_dequant 3.93** (`cvt` then `fma`, each strip a chain of load 4 + cvt 3 + fma 10 + store), k_cmul 3.98, k_sdot 3.85 (an `fma` and an `acc`), k_sgemm_nt 3.21, k_ddot 3.14 (binary64: `fma64` 6 + `acc`). **Multiply-heavy in integer** (k_mla32, k_mulh16, k_q15mul: 1.65 to 1.83) change less: the integer multiplier is 3 cycles. **Reduction-heavy** kernels: k_isum 2.54 (`acc`: 2 cycles, an add into the scalar register of the previous strip's, one cycle after it), k_dot16 2.45, k_q8dot 2.33 (`dacc` 5, the tree after the products), k_sadrow 1.83. **Segment-load-heavy**: k_split 1.42, k_cmul (segment store) changes less than its `fma` explains: `lseg` and `sseg` set to 1 cycle gain at most 5% (k_split, asic) and 0.8% (k_cmul). **Hidden-accumulator**: none of the kernels has one. **Smallest change** (scalar code dominates the cycles, so the vector latencies are a small part): k_softmax 1.19, k_rmsnorm 1.23, k_q8blk 1.32, the `lv` k_sad 1.37 and k_dctop_fill 1.42 (scalar 192 of 304). With the asic table the order is the same and the ratios 1.6 to 34 (the lane ALU alone takes 37 cycles).

## 5. The comparison

### 5.1 Model 2 over model 1, and the strips

#### Geometric mean of model 2 / model 1 cycles over the 41 kernels with a block, strip 32, port 16 (worst case in brackets)

| table | vmemlat | vpipe 1 | vpipe 2 | vpipe 4 |
|---|---:|---|---|---|
| fpga | 2 | 1.996 (k_vtxaos 6.274; best 1.176) | 1.750 (k_vtxaos 6.179; best 1.003) | 1.748 (k_vtxaos 6.179; best 1.003) |
| fpga | 4 | 2.289 (k_vtxaos 6.372; best 1.194) | 2.054 (k_vtxaos 6.277; best 1.085) | 2.052 (k_vtxaos 6.277; best 1.033) |
| fpga | 8 | 2.851 (k_vtxaos 6.568; best 1.231) | 2.627 (k_vtxaos 6.473; best 1.105) | 2.625 (k_vtxaos 6.473; best 1.070) |
| asic | 2 | 6.858 (k_vtxaos 33.717; best 1.600) | 5.612 (k_vtxaos 33.432; best 1.288) | 5.172 (k_vtxaos 33.432; best 1.135) |
| asic | 4 | 7.206 (k_vtxaos 33.815; best 1.619) | 5.937 (k_vtxaos 33.530; best 1.298) | 5.542 (k_vtxaos 33.530; best 1.141) |
| asic | 8 | 7.866 (k_vtxaos 34.011; best 1.656) | 6.565 (k_vtxaos 33.726; best 1.318) | 6.293 (k_vtxaos 33.726; best 1.154) |

#### Slowdown of a narrower strip against strip 32 (cycles(strip) / cycles(32), same port and parameters): geometric mean (worst kernel)

| model | table | vpipe | vmemlat | port | strip 16 | strip 8 |
|---|---|---:|---:|---:|---|---|
| 1 | - | - | - | 8 | 1.139 (k_blend 1.978) | 1.783 (k_blend 3.934) |
| 2 | fpga | 1 | 4 | 8 | 1.414 (k_blend 1.989) | 2.379 (k_blend 3.968) |
| 2 | fpga | 4 | 4 | 8 | 1.423 (k_blend 1.988) | 2.252 (k_blend 3.965) |
| 2 | asic | 1 | 4 | 8 | 1.715 (k_blend 1.986) | 3.053 (k_blend 3.945) |
| 2 | asic | 4 | 4 | 8 | 1.635 (k_blend 1.998) | 2.866 (k_blend 3.994) |
| 1 | - | - | - | 16 | 1.528 (k_quant 1.980) | 2.802 (k_quant 3.939) |
| 2 | fpga | 1 | 2 | 16 | 1.539 (k_blend 1.989) | 2.864 (k_blend 3.966) |
| 2 | fpga | 1 | 4 | 16 | 1.595 (k_blend 1.989) | 2.993 (k_blend 3.968) |
| 2 | fpga | 1 | 8 | 16 | 1.668 (k_thresh 1.991) | 3.160 (k_thresh 3.973) |
| 2 | fpga | 4 | 4 | 16 | 1.553 (k_blend 1.988) | 2.898 (k_blend 3.965) |
| 2 | asic | 1 | 2 | 16 | 1.771 (k_blend 1.986) | 3.305 (k_blend 3.944) |
| 2 | asic | 1 | 4 | 16 | 1.786 (k_blend 1.986) | 3.348 (k_blend 3.945) |
| 2 | asic | 1 | 8 | 16 | 1.807 (k_blend 1.986) | 3.413 (k_blend 3.946) |
| 2 | asic | 4 | 4 | 16 | 1.730 (k_blend 1.998) | 3.248 (k_blend 3.994) |
| 1 | - | - | - | 32 | 1.775 (k_daxpy 1.990) | 3.271 (k_daxpy 3.969) |
| 2 | fpga | 1 | 4 | 32 | 1.832 (k_dscal 1.996) | 3.454 (k_dscal 3.989) |
| 2 | fpga | 4 | 4 | 32 | 1.817 (k_dscal 1.996) | 3.408 (k_dscal 3.987) |
| 2 | asic | 1 | 4 | 32 | 1.875 (k_dot16 2.021) | 3.524 (k_vtx 3.983) |
| 2 | asic | 4 | 4 | 32 | 1.845 (k_dscal 1.999) | 3.473 (k_dscal 3.997) |

### 5.2 Memory-bound or compute-bound

#### Memory-bound or compute-bound (the vector cycles when the strip halves from 32 to 16: unchanged = ratio 1.2 or less, doubles = 1.9 or more), kernels with a block that are not scalar-dominated at strip 32 in model 1

36 kernels. | model | port | unchanged / between / doubles |
|---|---:|---|
| model 1 | 8 | 31 / 4 / 1 |
| model 2, fpga, vpipe 1 | 8 | 3 / 32 / 1 |
| model 2, fpga, vpipe 4 | 8 | 1 / 34 / 1 |
| model 2, asic, vpipe 1 | 8 | 0 / 27 / 9 |
| model 2, asic, vpipe 4 | 8 | 1 / 29 / 6 |
| model 1 | 16 | 2 / 20 / 14 |
| model 2, fpga, vpipe 1 | 16 | 0 / 34 / 2 |
| model 2, fpga, vpipe 4 | 16 | 0 / 34 / 2 |
| model 2, asic, vpipe 1 | 16 | 0 / 21 / 15 |
| model 2, asic, vpipe 4 | 16 | 0 / 16 / 20 |
| model 1 | 32 | 0 / 2 / 34 |
| model 2, fpga, vpipe 1 | 32 | 0 / 4 / 32 |
| model 2, fpga, vpipe 4 | 32 | 0 / 3 / 33 |
| model 2, asic, vpipe 1 | 32 | 0 / 9 / 27 |
| model 2, asic, vpipe 4 | 32 | 0 / 4 / 32 |

The count of kernels whose vector cycles stay when the strip halves falls from 31 (model 1, port 8) to 3 or fewer in every model 2 setting; the number that double rises with the port in both models, and with the asic table at port 16 from 14 (model 1) to 15 to 20.

### 5.3 Sensitivity to the table, and which classes matter

#### Sensitivity to the latency table: geometric mean of model 2 / model 1 over the kernels with a block, port 16, vpipe 1, vmemlat 4

| table | strip 8 | strip 16 | strip 32 |
|---|---|---|---|
| unit | 1.572 | 1.555 | 1.526 |
| fpga-lo | 2.069 | 2.038 | 1.939 |
| fpga | 2.445 | 2.389 | 2.289 |
| fpga-hi | 2.749 | 2.913 | 2.706 |
| asic-lo | 5.106 | 4.942 | 4.320 |
| asic | 8.612 | 8.421 | 7.206 |
| asic-hi | 16.280 | 16.146 | 13.575 |

Sanity check (model 2 with the unit table, 16 strips in flight, memory latency 1, strip 32, port 16) against model 1: geometric mean of model 2 / model 1 = 1.038, range 0.758 to 1.669 over the 41 kernels.

#### Class sensitivity: one class set to latency 1 (ld, st: 0), all else as the table; geometric mean of cycles / cycles with the table, and the largest single-kernel gain; kernels that use the class; port 16, vpipe 1, vmemlat 4

| class | instrs run (all kernels, strip 32) | kernels using it | fpga strip 32: geomean (best kernel) | fpga strip 16 | asic strip 32 | asic strip 16 |
|---|---:|---:|---|---|---|---|
| alu | 929 | 9 | 0.9609 (k_relu 0.753) | 0.9504 (k_dctop_fill 0.676) | 0.8386 (k_dctop_fill 0.258) | 0.8122 (k_dctop_fill 0.168) |
| cmp | 157 | 2 | 1.0000 (k_avg8 1.000) | 1.0000 (k_avg8 1.000) | 0.9964 (k_maskblend 0.861) | 0.9951 (k_maskblend 0.817) |
| bsl | 157 | 2 | 1.0000 (k_avg8 1.000) | 1.0000 (k_avg8 1.000) | 1.0000 (k_avg8 1.000) | 1.0000 (k_avg8 1.000) |
| shift | 313 | 2 | 0.9952 (k_prep8 0.892) | 0.9948 (k_prep8 0.877) | 0.9709 (k_prep8 0.391) | 0.9680 (k_prep8 0.348) |
| narrow | 0 | 0 | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) |
| mul8 | 0 | 0 | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) |
| mul16 | 0 | 0 | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) |
| mulh16 | 126 | 2 | 0.9920 (k_mulh16 0.849) | 0.9893 (k_mulh16 0.803) | 0.9757 (k_mulh16 0.604) | 0.9692 (k_mulh16 0.527) |
| mul32 | 375 | 2 | 0.9924 (k_blend 0.842) | 0.9910 (k_mla32 0.820) | 0.9787 (k_mla32 0.518) | 0.9743 (k_mla32 0.430) |
| mul64 | 0 | 0 | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) |
| dot | 0 | 0 | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) |
| dacc | 126 | 3 | 0.9803 (k_dot16 0.704) | 0.9741 (k_dot16 0.645) | 0.9246 (k_dot16 0.277) | 0.9096 (k_dot16 0.230) |
| sad | 96 | 3 | 0.9946 (k_sadrow 0.909) | 0.9924 (k_sadrow 0.883) | 0.9369 (k_sadrow 0.352) | 0.9279 (k_sadrow 0.323) |
| acc | 1681 | 7 | 0.9883 (k_isum 0.879) | 0.9862 (k_isum 0.860) | 0.9231 (k_isum 0.328) | 0.9171 (k_isum 0.300) |
| mmacc | 32 | 1 | 0.9966 (k_softmax 0.868) | 0.9969 (k_softmax 0.880) | 0.9896 (k_softmax 0.652) | 0.9900 (k_softmax 0.662) |
| fir | 0 | 0 | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) |
| tbl | 0 | 0 | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) |
| lseg | 221 | 3 | 1.0000 (k_avg8 1.000) | 1.0000 (k_avg8 1.000) | 0.9985 (k_split 0.946) | 0.9980 (k_split 0.925) |
| sseg | 95 | 2 | 1.0000 (k_avg8 1.000) | 1.0000 (k_avg8 1.000) | 0.9997 (k_cmul 0.992) | 0.9997 (k_cmul 0.992) |
| cvt | 375 | 3 | 0.9927 (k_dequant 0.901) | 0.9921 (k_i2f 0.895) | 0.9831 (k_dequant 0.788) | 0.9826 (k_i2f 0.783) |
| fma | 3523 | 11 | 0.8456 (k_vtxaos 0.323) | 0.8183 (k_vtxaos 0.271) | 0.6977 (k_vtx 0.091) | 0.6751 (k_vtx 0.074) |
| fma64 | 2286 | 6 | 0.9476 (k_dscal 0.644) | 0.9343 (k_dscal 0.584) | 0.8242 (k_dscal 0.198) | 0.8029 (k_dscal 0.159) |
| ld | 10425 | 37 | 1.0000 (k_avg8 1.000) | 1.0000 (k_avg8 1.000) | 0.9518 (k_thresh 0.792) | 0.9441 (k_thresh 0.779) |
| st | 3734 | 25 | 0.9606 (k_copy16 0.880) | 1.0000 (k_avg8 1.000) | 0.9512 (k_copy16 0.756) | 0.9786 (k_clampr 0.867) |
| misc | 0 | 0 | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) |

Reading it: the numbers are the cycles with that class at 1 over the cycles with the table, so 0.8456 is 15.4% less time; "best kernel" is the kernel that gains most. A class with no instructions in the 41 kernels (`narrow`, `mul8`, `mul16`, `mul64`, `dot`, `fir`, `tbl`, `misc`: the kernels of `llvm/bench` compiled by LoopVectorize do not use them) cannot be judged from these kernels: its latency in the table is the depth measurement and nothing tests it.

## 6. What this does not tell

* The latencies are assumptions on the study's area-oriented RTL (limit 2); the asic column in particular is not a design. A real design would first fix the lane ALU, `vmaxacc` and the fp multiply-add depth, which the class sensitivity says are the first to pay.
* Model 2 is in order, one port, no chaining, renamed registers when strips overlap: a decoupled design (loads issued ahead, chaining) would be between model 1 and model 2; this document does not model it.
* Scalar instruction latencies are in neither model; the vector part's share of the total at these kernels is below half for 5 of the 41 (scalar-dominated).
* Nothing here is evidence about area: pipelining each block into the stages the table gives costs flip-flops that vec-strip.md's counts do not include.

## 7. Rerun

`tools/gates/run-latency.sh [OUTDIR] [depth] [table] [build] [bench]` (default all, OUTDIR `tools/gates/latency-results`): `depth` synthesises every block at strips 32, 16, 8 (the three flows each; resumable through `OUTDIR/stat`; roughly an hour or more of wall clock on 12 cores with JOBS=10, not timed precisely), `table` writes `OUTDIR/depth.md`, the two tables `OUTDIR/latency-{fpga,asic}.txt` (copied to `sim64/`) and `sim64/vlatency-defaults.h` (rebuild sim64 after it), `build` is `tools/build-sim64.sh`, `bench` is `tools/lat-bench.py` (about 10 minutes at JOBS=10). It needs yosys, the environment of the other tools (`HBNF`, `HBNF_TEMPLATES`, `PATH` with `~/.local/bin`) and the LLVM tools of `../llvm-build`. The parameters of the conversion are in the header of `lat-table.py` (`PARAMS`): to try another clock or delay, edit them, run `table`, `build`, `bench`; for one run, `sim64 -V --latency=FILE` takes a table without rebuilding (a file names the classes it changes).
