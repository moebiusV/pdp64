# The strip width of the vec block: what 256, 128 and 64 bits cost in speed and save in logic

**Status (as of 2026-11-18, commit 044a7195): a measurement (logic by yosys, speed by a cycle model), still valid as measurement; its follow-up decisions are made and implemented.** What it measured stands: logic is proportional to the strip (128 bits halves the vector unit), a 128-bit strip is 1.53 times slower in geometric mean at a 16-byte port, and 128 bits is recommended for an FPGA build with a 16-byte port (an ASIC keeps the strip a design parameter). **What it led to** (errata 173 to 175, R477 to R482, `vec-isa.md` section 8): the owner chose to make the strip invisible ("yes do 2, close the 5 places"), so the five places of 5.1 are closed, `vlen` and the register form of `vtbl.b` are removed, the floating-point sum has a canonical order, a block with accumulators has a 16-byte strip, and **the least strip is 16 bytes (128 bits)**; the strip of 8 bytes, measured below, is **outside the architecture** (`sim64 -S 8` warns), so the 8-byte columns are measurements for the cycle study only. The strip itself remains the implementation's choice (sim64's default is 32 bytes; `-S 16|32|64`). **Superseded:** the 8-byte option, the closing "two changes of definition" of section 7 (done more completely), 5.1 as a list of open exceptions (all closed),. **Still current:** sections 3 and 4 (the logic by strip, the FPGA fit), 5.2 (the cycle model on the kernels; model 1, and model 2 in `vec-latency.md`), 7 (the recommendation). The word counts here are of wave 1 and 2 (the vector unit without the floating-point lanes: 298,779 NAND2 at 256 bits); the family now has 363 words and 63 base mnemonics.

**Related:** `vec-isa.md` section 8 (the statement of the invisible strip, and the options for the floating-point sum with their silicon); `vec-latency.md` (the second cycle model, which re-examines this study's conclusions); `vec-silicon.md` (the 256-bit blocks this study parameterises); `vec-gates.md` (the first gate estimates); `vec-survey.md` (the proposal whose family this measures); `docs/errata.md` 173 to 175.

**Update (errata 173 to 175, 2026-11-18): the strip is now invisible to programs, and the least strip is 16 bytes.** The owner chose to close the places listed in 5.1 ("yes do 2, close the 5 places"): `vlen` and the register form of `vtbl.b` are removed, a floating-point sum has a canonical order, a block with accumulators has a strip of 16 bytes (and a `vfin` epilogue), and EVA, EPC and ECAUSE are exact while the registers a handler sees are opaque; `vec-isa.md` section 8 is the statement, 5.1 below is the study that found the places (kept as it was, with a note at each) and `tools/strip-equiv.py` now runs the whole suite at 16, 32 and 64 bytes with nothing switched off. **A strip of 8 bytes is not an allowed implementation** (it cannot hold a 4-field segment of 4-byte elements in a beat, the 16 entries of the table of `vtbl.b` or the 16-byte chunk of the floating-point sum); the 8-byte rows of the tables below stay as measurements for the cycle study, `sim64 -S 8` runs with a warning, and 128 bits is the least strip, not a recommendation among options.

**Status: a measurement, 2026-11-18, the assistant's work, for the owner to read; it changes no grammar, manual or encoding.** The question was: "128 bit strip, 16 lanes ... compare to what? would we lose any speed? when dealing at that amount of data processing, a couple extra bytes of instructions is nothing. Measure it with yosys and a sim64 strip option." The strip is the implementation's choice, not the program's: VL, the elements of a strip, is the strip's bytes over the widest lane type that the block names (`common/pdp64exec_vec.inc`). **The binary is the same at every strip; the hardware goes round the block more times** (so, as the owner says, the code size is not an argument). The baseline is the strip that `vec-silicon.md` and sim64 had: 32 bytes = 256 bits. This document measures a strip of 16 bytes (128 bits) and one of 8 bytes (64 bits) against it, in logic (yosys) and in time (a cycle model in sim64).

**Limits, first.**

1. The gate counts are **gate counts of behavioural Verilog, not layout**: no timing, no wiring, no clock tree, no power. The NAND2 count is the study's (`abc -g NAND`, flip-flops at 6); the FPGA counts are the LUT and multiplier cells that yosys 0.52 gives (`synth_ecp5`, `synth_xilinx -family xc7`), not place and route. The same Verilog can map to counts that differ by a few per cent from one run or file to the next (section 3).
2. **The time is a model, not a measurement of hardware**: one cycle for each vector instruction of a strip, a commit cost, a memory port of stated width (section 2 and `docs/sim64.md`). It has no instruction latencies, no cache misses, no bank conflicts, and it makes a narrower strip exactly proportionally slower in compute, which a design with more units per lane would not.
3. The speed is measured on the 41 kernels with a vec block of `llvm/bench` (the `lv` build: LoopVectorize with the pdp64 cost model, not hand-written code; of the hand-written listings only `k_sad` still assembles and gives the same result as the compiled kernel), on the bench's data of 1,000 elements: it is not a workload.
4. No FPGA part was targeted: the fit statements are sums of cell counts against the parts' sizes and ignore the scalar core, the memory system and routing.

## Headline

| strip | NAND2 equivalents (wave 1 and 2) | saving | ECP5 LUT4 | saving | Xilinx LUT6 | saving | multipliers: ECP5 18x18 / xc7 DSP48 | with fp lanes: NAND2, LUT4, LUT6 | geomean slowdown on the kernels with a block, port 16 B/cycle (worst) | at port 8 | at port 32 |
|---|---:|---:|---:|---:|---:|---:|---|---|---|---|---|
| 256 bits (32 bytes) | 298,779 | - | 77,574 | - | 39,674 | - | 64 / 64 | 384,313, 102,936, 48,673 | 1.00 (reference) | 1.00 | 1.00 |
| 128 bits (16 bytes) | 149,251 | 50% | 37,052 | 52% | 18,597 | 53% | 32 / 32 | 191,922, 50,270, 23,134 | **1.53** (k_quant 1.98) | 1.14 | 1.77 |
| 64 bits (8 bytes) | 73,254 | 75% | 16,626 | 79% | 8,829 | 78% | 16 / 16 | 94,559, 23,189, 10,919 | **2.80** (k_quant 3.94) | 1.78 | 3.27 |

* **Logic is proportional to the strip: half at 128 bits, a quarter at 64.** (Wave 1 and 2 without floating-point lanes: 50% and 75% fewer NAND2 equivalents, 52% and 79% fewer ECP5 LUT4, 53% and 78% fewer Xilinx LUT6; the multipliers 64, 32, 16.) The blocks that fall faster than the strip are the interleave networks (segment load and store 0.41 and 0.13 of the 256-bit block for the load), the load and store alignment (0.39 and 0.14) and `vtbl` at 64 bits (0.12); the strip control (4,640 NAND2 equivalents, an estimate) does not scale.
* **Speed is lost, yes** (the owner's second question). In the model a 128-bit strip is **1.53 times slower in geometric mean over the 41 kernels with a vec block at a 16-byte port, at worst 1.98 times (k_quant)**; a 64-bit strip 2.80 times (worst 3.94). The loss is less than the 2 times (4 times) that halving the width suggests because of kernels that are mostly scalar code (the strip does not matter to them) and kernels whose strip is limited by the memory port: with a port of 8 bytes a cycle the geometric mean for 128 bits is 1.14, with a port of 32 bytes 1.77. Kernels limited by the one instruction a cycle take exactly twice as long: 14 of the 41 at port 16 (1.91 for strip 16, 3.73 for strip 8). Memory-bound (the cycles hardly change when the strip halves from 32 to 16 bytes) are only 2 of the 41 kernels at a 16-byte port, but 31 of the 36 kernels not dominated by scalar code at a port of 8 bytes.
* **Recommendation** (section 7): **128 bits for an FPGA build**. The vector unit alone is, at 256 bits, 92% of an ECP5-85F's LUT4 (123% with the fp lanes) and 63% of an Artix-7 100T's LUT6 (77% with them); at 128 bits 44% (60%) and 30% (37%). With an extrapolated scalar core beside it (4.3) the 128-bit unit makes 76 to 94% of an Artix-7 100T (tight) and 36 to 44% of a 200T; a 256-bit one needs the 200T (51 to 60%); an ECP5-85F is too small for the core and any of the three units by that extrapolation (88 to 115% even at 64 bits). For a later ASIC make the strip a design parameter; by the owner's priorities (minimal silicon, reasonable performance) 128 bits with a 16-byte port (the chip is about 27% smaller, the vector kernels take 1.53 times as long); 256 bits only where vector throughput is the point and the first-level data cache delivers 32 bytes a cycle.

## 1. What changes with the strip, and what does not

* **Code size does not change.** A `vec Rs, Re` block with its instructions and `vend` is the same bytes; the number of strips is the region over VL x element size, rounded up: for the kernels the strips at 32, 16 and 8 bytes are in the proportion 1 : 2 : 4 up to the last, short strip (section 5.2, the "strips" column).
* **Lane counts** follow the strip: 256 bits has 32 byte, 16 halfword, 8 word and 4 doubleword lanes; 128 bits 16, 8, 4, 2; 64 bits 8, 4, 2, 1. The floating-point lanes (`fma32`) are 8, 4, 2. The vector registers are 16 x strip bits.
* **What a program can see of the strip** was listed in 5.1 with the test that found it: `vlen.b` (by design), the register form of `vtbl.b`, a `vclr` accumulator that the block itself reads or stores, a floating-point reduction (a sum is order dependent), and what a fault handler sees of the registers (the progress is a whole number of strips). **All five are closed (errata 173 to 175, `vec-isa.md` section 8).** Everything else that the test suite runs gave the same results at 8, 16, 32 and 64 bytes, and now every test, unmodified, gives the same results at 16, 32 and 64.

## 2. Method

**Logic.** `tools/gates/vecw.v` has the width-dependent blocks of `vec2.v`, `vec3.v`, `mem2.v` and `fp2.v` written for a strip of SNB bytes (`read_verilog -D SNB=32|16|8`): the logic of each lane is unchanged and the literals 32, 16, 8, 256 are functions of SNB. The blocks are the lane ALU, the shifts with rounding, the narrowing store, the array of 8 x 8 products with the `vdacc` tree, `vfir`, `vacc` and `vmaxacc`/`vminacc`, `vsad`, `vtbl`, compare, select, segment load and store, the register file, load alignment and store merge, the floating-point lanes and the conversions. Places where a width cannot simply be scaled are marked `WIDTH` in the file and listed in section 6. `tools/gates/strip-synth.sh` runs, for each module and width, the three flows of the study: `synth -flatten; abc -g NAND` (NAND2 equivalents = NAND + NOT/2, flip-flops at 6), `synth_ecp5` (LUT4, MULT18X18D) and `synth_xilinx -family xc7` (LUT6, DSP48E1). `tools/gates/strip-total.py` composes the totals as `silicon-total.py` composes the wave-1 vector unit (variant B: one array of 8 x 8 products, flip-flop registers), then wave 2 (compare and select, conversions) and the floating-point lanes. The whole run is `tools/gates/run-strip.sh` (section 8).

**A correction to the existing FPGA numbers.** `fpga.sh` runs `synth_xilinx` without `-flatten`. yosys then prints one statistics section for each module and a design-hierarchy total, and the script adds all of them: a wrapper and its core are counted twice and a block of N identical instances (N+1)/N times (`fma32x8`: nine instances' worth for eight). `strip-synth.sh` uses `-flatten`. The Xilinx column of `fpga-blocks.tsv` is therefore too high for every module that has a submodule (`narrow_both` is 5,168 there and 2,586 here); the ECP5 flow flattens by itself and is not affected, and neither is the NAND2 flow.

**Time.** `sim64 -S BYTES` sets the strip (8, 16, 32, 64; default 32; the environment variable `PDP64_VSTRIP` is the default of `-S`, so that `llvm/check.sh`, which gives sim64 no options, can run at a strip). `sim64 -V` prints the cycle model, with `--vport=BYTES` (memory port, default 16) and `--vcommit=CYCLES` (default 1); `docs/sim64.md` documents them. `common/pdp64exec_vec.inc` has a runtime strip (`cpu->vstrip`, 0 means 32) in place of the constant, the registers are 64 bytes of storage, and it has the model's counters. `qemu/sync.sh` was run and `qemu/sync.sh --check` is clean (QEMU was not rebuilt; it neither sets the strip nor reads the counters). The strip-32 counters of all 46 `lv` kernels (blocks, strips, vector instructions) equal those of `llvm/bench/results.csv`, so the default behaviour did not change.

**The model**, for an in-order implementation whose strip pipeline issues one vector instruction a cycle: a scalar instruction costs 1 cycle (the `vec` is one of them: its set-up); a `vend` 1 cycle; a strip costs `max(compute, memory) + commit`, where compute is one cycle for each vector instruction (a `vfir` one for each tap) and memory is, for each load or store, the bytes it moves over the port width, rounded up, summed (one port); commit is 1 cycle. The kernels are the `lv` build of `llvm/bench` (46 kernels, 40 with a block) and the hand-written `k_sad`, the driver's set-up subtracted.

## 3. The parameterised blocks at 256 bits reproduce the existing ones

**Check: the parameterised blocks at 256 bits against the existing ones**


`ref` is the module of vec2.v, vec3.v, mem2.v or fp2.v synthesised again by this run (strip-synth.sh, the commands of gates2.sh and fpga.sh); `w_` is the parameterised module of vecw.v at SNB = 32; `committed` is the study's file (vec-silicon-blocks.tsv, fpga-blocks.tsv).  NAND2 equivalents with flip-flops at 6; LUT4 and LUT6 as the flows give them (for the register file the distributed RAM sites are added: see the header of strip-total.py).  diff = w_ against ref.

| block | NAND2 ref | NAND2 w_ | diff | NAND2 committed | LUT4 ref | LUT4 w_ | diff | LUT4 committed | LUT6 ref | LUT6 w_ | diff | LUT6 committed | DSP ecp5 ref / w_ | DSP xc7 ref / w_ |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| fma32x8 | 85,534 | 85,534 | +0.0% | 86,650 | 24,845 | 25,362 | +2.1% | 26,862 | 9,149 | 8,999 | -1.6% | 10,386 | 32 / 32 | 16 / 16 |
| cvt_both8 | 16,025 | 16,007 | -0.1% | 15,847 | 5,634 | 5,634 | +0.0% | 5,466 | 3,917 | 3,878 | -1.0% | 3,834 | 0 / 0 | 0 / 0 |
| ms8x8 | 87,660 | 87,737 | +0.1% | 85,516 | 7,491 | 7,491 | +0.0% | 7,531 | 4,684 | 4,713 | +0.6% | 4,580 | 64 / 64 | 64 / 64 |
| ms8x8_notree | 83,844 | 83,659 | -0.2% | 81,722 | 6,141 | 6,140 | -0.0% | 6,130 | 4,354 | 4,226 | -2.9% | 9,508 | 64 / 64 | 64 / 64 |
| lanealu_mw | 19,782 | 19,618 | -0.8% | 19,782 | 5,232 | 5,225 | -0.1% | 5,232 | 3,150 | 3,280 | +4.1% | 6,556 | 0 / 0 | 0 / 0 |
| lanealu_mw_noavg | 18,275 | 18,189 | -0.5% | 18,275 | 5,066 | 5,075 | +0.2% | 5,066 | 2,904 | 2,900 | -0.1% | 5,900 | 0 / 0 | 0 / 0 |
| shiftround_mw | 11,582 | 11,582 | +0.0% | 11,582 | 6,821 | 6,821 | +0.0% | 6,821 | 3,899 | 3,899 | +0.0% | 7,748 | 0 / 0 | 0 / 0 |
| shiftlane_mw | 9,430 | 9,423 | -0.1% | 9,430 | 6,291 | 6,291 | +0.0% | 6,291 | 3,313 | 3,348 | +1.1% | 6,710 | 0 / 0 | 0 / 0 |
| segload | 9,856 | 9,854 | -0.0% | 9,856 | 9,888 | 9,888 | +0.0% | 9,888 | 3,419 | 3,438 | +0.6% | 3,419 | 0 / 0 | 0 / 0 |
| segstore | 13,418 | 13,418 | +0.0% | 13,418 | 10,881 | 10,881 | +0.0% | 10,881 | 3,640 | 3,640 | +0.0% | 3,640 | 0 / 0 | 0 / 0 |
| vacc_naive | 9,875 | 9,875 | +0.0% | 9,875 | 2,474 | 2,474 | +0.0% | 2,474 | 1,848 | 1,848 | +0.0% | 1,848 | 0 / 0 | 0 / 0 |
| vmmacc | 10,702 | 10,702 | +0.0% | 10,702 | 5,119 | 5,119 | +0.0% | 5,119 | 2,323 | 2,325 | +0.1% | 2,323 | 0 / 0 | 0 / 0 |
| narrow_both | 8,629 | 8,498 | -1.5% | 8,629 | 5,773 | 5,773 | +0.0% | 5,773 | 2,588 | 2,586 | -0.1% | 5,168 | 0 / 0 | 0 / 0 |
| vfir_added | 12,360 | 12,336 | -0.2% | 12,386 | 2,303 | 2,303 | +0.0% | 2,303 | 2,786 | 2,785 | -0.0% | 2,857 | 0 / 0 | 0 / 0 |
| dacc_tree | 3,734 | 3,509 | -6.0% | 3,734 | 792 | 763 | -3.7% | 792 | 610 | 662 | +8.5% | 610 | 0 / 0 | 0 / 0 |
| sum32_bu | 2,670 | 2,670 | +0.0% | 2,670 | 718 | 718 | +0.0% | 718 | 575 | 575 | +0.0% | 575 | 0 / 0 | 0 / 0 |
| vsad_bu | 7,921 | 7,921 | +0.0% | 7,921 | 2,461 | 2,461 | +0.0% | 2,461 | 1,385 | 1,385 | +0.0% | 1,385 | 0 / 0 | 0 / 0 |
| vtbl_g16 | 12,736 | 12,736 | +0.0% | 12,736 | 5,376 | 5,376 | +0.0% | 5,376 | 1,643 | 1,615 | -1.7% | 1,643 | 0 / 0 | 0 / 0 |
| vcmp_mw | 2,905 | 2,917 | +0.4% | 2,905 | 1,368 | 1,368 | +0.0% | 1,368 | 90,071 | 90,008 | -0.1% | 89,804 | 0 / 0 | 0 / 0 |
| vbsl | 896 | 896 | +0.0% | 896 | 256 | 256 | +0.0% | 256 | 256 | 256 | +0.0% | 256 | 0 / 0 | 0 / 0 |
| vregs16_r3 | 61,578 | 61,578 | +0.0% | 61,578 | 768 | 768 | +0.0% | 0 | 512 | 512 | +0.0% | 0 | 0 / 0 | 0 / 0 |
| vmem_ld | 9,379 | 9,379 | +0.0% | 9,531 | 4,614 | 4,614 | +0.0% | 4,614 | 1,964 | 1,964 | +0.0% | 2,084 | 0 / 0 | 0 / 0 |
| vmem_st | 5,534 | 5,534 | +0.0% | 5,534 | 2,571 | 2,571 | +0.0% | 2,571 | 1,297 | 1,297 | +0.0% | 1,297 | 0 / 0 | 0 / 0 |

Blocks where w_ at 256 bits differs from ref by more than 3% in NAND2, LUT4 or LUT6: dacc_tree 8.5%, lanealu_mw 4.1%.

How to read this: the NAND2 equivalents agree within 1.5% for every block except `dacc_tree` (a block of nine adders), where the new module is 6.0% lower; the study itself says a few per cent of mapper noise from one file to the next, and this is the largest case. The ECP5 LUT4 agree within 3.7%. The Xilinx LUT6 are, in this run, flattened for both (the existing module is re-synthesised with the same corrected flow), and differ by at most 8.5% (the differences are in the blocks named in the line above the table). The `committed` columns are the study's files; the Xilinx ones are doubled where a module has a submodule (section 2). The register file has no LUTs in the committed files because `fpga.sh` does not count distributed RAM; the figures here add it (4 LUT sites for a `TRELLIS_DPR16X4` or a `RAM32M`). **The NAND2 totals agree to better than 1%**: wave 1 at 256 bits is 278,959 NAND2 equivalents here and 277,237 in `vec-silicon.md`.

## 4. Logic by strip

### 4.1 Every block

**Every block at the three strips**


NAND2 equivalents (flip-flops at 6), then ECP5 LUT4 (distributed RAM at 4 LUT4 a DPR16X4), Xilinx xc7 LUT6 (RAM32M at 4 sites), the multipliers MULT18X18D / DSP48E1.  Ratio: the block at 128 (64) bits over the block at 256 bits.

| block | NAND2 256 | 128 | 64 | ratio 128 | ratio 64 | LUT4 256 | 128 | 64 | LUT6 256 | 128 | 64 | MULT18 256 / 128 / 64 | DSP48 256 / 128 / 64 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| vector register file, 16 x strip, 3 read, 1 write | 61,578 | 30,869 | 15,409 | 0.50 | 0.25 | 768 | 384 | 192 | 512 | 256 | 128 | 0 / 0 / 0 | 0 / 0 / 0 |
| lane ALU, all widths (with avg) | 19,618 | 9,923 | 4,811 | 0.51 | 0.25 | 5,225 | 2,671 | 1,323 | 3,280 | 1,581 | 807 | 0 / 0 / 0 | 0 / 0 / 0 |
| shifts with rounding | 11,582 | 5,797 | 2,982 | 0.50 | 0.26 | 6,821 | 3,364 | 1,944 | 3,899 | 1,955 | 988 | 0 / 0 / 0 | 0 / 0 / 0 |
| narrowing store with rounding shift | 8,498 | 4,233 | 2,144 | 0.50 | 0.25 | 5,773 | 2,938 | 1,462 | 2,586 | 1,300 | 638 | 0 / 0 / 0 | 0 / 0 / 0 |
| array of 8 x 8 products with the vdacc tree | 87,737 | 43,726 | 22,140 | 0.50 | 0.25 | 7,491 | 3,655 | 1,759 | 4,713 | 2,247 | 1,132 | 64 / 32 / 16 | 64 / 32 / 16 |
|   (the array without the tree) | 83,659 | 41,860 | 21,209 | 0.50 | 0.25 | 6,140 | 3,140 | 1,543 | 4,226 | 2,172 | 1,100 | 64 / 32 / 16 | 64 / 32 / 16 |
|   (the vdacc tree alone) | 3,509 | 1,665 | 1,093 | 0.47 | 0.31 | 763 | 351 | 191 | 662 | 314 | 127 | 0 / 0 / 0 | 0 / 0 / 0 |
| vacc, one tree per source type | 9,875 | 4,842 | 2,335 | 0.49 | 0.24 | 2,474 | 1,060 | 487 | 1,848 | 775 | 323 | 0 / 0 / 0 | 0 / 0 / 0 |
| vmaxacc, vminacc | 10,702 | 4,961 | 2,269 | 0.46 | 0.21 | 5,119 | 2,513 | 1,220 | 2,325 | 1,257 | 538 | 0 / 0 / 0 | 0 / 0 / 0 |
| sum of the bytes (the tree of vsad / vacc.bu) | 2,670 | 1,459 | 845 | 0.55 | 0.32 | 718 | 368 | 187 | 575 | 286 | 108 | 0 / 0 / 0 | 0 / 0 / 0 |
| vsad.bu standalone | 7,921 | 4,087 | 2,141 | 0.52 | 0.27 | 2,461 | 1,187 | 595 | 1,385 | 677 | 340 | 0 / 0 / 0 | 0 / 0 / 0 |
| vtbl.b (register form) | 12,736 | 6,368 | 1,472 | 0.50 | 0.12 | 5,376 | 2,688 | 456 | 1,615 | 807 | 192 | 0 / 0 / 0 | 0 / 0 / 0 |
| compare (vceq, vcgt, vcgtu), study form | 2,917 | 1,448 | 725 | 0.50 | 0.25 | 1,368 | 797 | 440 | 90,008 | 45,514 | 22,633 | 0 / 0 / 0 | 0 / 0 / 0 |
| compare, fixed comparators (no dynamic shift) | 2,953 | 1,477 | 742 | 0.50 | 0.25 | 1,391 | 781 | 360 | 626 | 317 | 159 | 0 / 0 / 0 | 0 / 0 / 0 |
| vbsl | 896 | 448 | 224 | 0.50 | 0.25 | 256 | 128 | 64 | 256 | 128 | 64 | 0 / 0 / 0 | 0 / 0 / 0 |
| conversions vcvt.f.l, vcvt.l.f, SNB/4 lanes each | 16,007 | 8,053 | 3,972 | 0.50 | 0.25 | 5,634 | 2,955 | 1,356 | 3,878 | 1,774 | 959 | 0 / 0 / 0 | 0 / 0 / 0 |
| vfir (without the 112 halo flip-flops) | 12,336 | 6,599 | 3,768 | 0.53 | 0.31 | 2,303 | 1,214 | 719 | 2,785 | 1,092 | 567 | 0 / 0 / 0 | 0 / 0 / 0 |
| segment load (de-interleave) | 9,854 | 4,072 | 1,276 | 0.41 | 0.13 | 9,888 | 2,971 | 1,962 | 3,438 | 1,262 | 420 | 0 / 0 / 0 | 0 / 0 / 0 |
| segment store (interleave) | 13,418 | 6,297 | 2,053 | 0.47 | 0.15 | 10,881 | 5,898 | 1,559 | 3,640 | 1,723 | 539 | 0 / 0 / 0 | 0 / 0 / 0 |
| load alignment with widening | 9,379 | 3,689 | 1,348 | 0.39 | 0.14 | 4,614 | 1,902 | 501 | 1,964 | 743 | 316 | 0 / 0 / 0 | 0 / 0 / 0 |
| store merge | 5,534 | 2,214 | 814 | 0.40 | 0.15 | 2,571 | 1,030 | 362 | 1,297 | 496 | 239 | 0 / 0 / 0 | 0 / 0 / 0 |
| floating-point multiply-add lanes (SNB/4) | 85,534 | 42,671 | 21,305 | 0.50 | 0.25 | 25,362 | 13,218 | 6,563 | 8,999 | 4,537 | 2,090 | 32 / 16 / 8 | 16 / 8 / 4 |

Scaling in one line each. The lane ALU, shifts, narrowing store, reductions, array of products, compare, conversions, register file and floating-point lanes are linear in the strip (0.50 and 0.25; the `vmaxacc` tree slightly better, 0.46 and 0.21, because the depth of a tree falls). **The interleave networks fall faster than linearly**: segment load 0.41 and 0.13 and segment store 0.47 and 0.15 of the 256-bit block (they grow with strip x fields x beats; at 64 bits only the (fields, size) cases that fit a beat are built, section 6); the load alignment and store merge 0.39 and 0.14 (a rotate of two strips by up to strip-1 bytes, and the widening); `vtbl.b` 0.50 and 0.12 (a lane selects among 16 bytes of its group at 256 and 128 bits and among 8 at 64 bits, because a table lane beyond the strip reads as 0). `vfir` does not halve (0.53 and 0.31) because the tap window and the 7-halfword halo are fixed by the filter's 8 taps. The array of 8 x 8 products is the largest block (87,737 NAND2 equivalents at 256 bits, 31% of the unit) and is exactly linear: 64 multipliers of 18 x 18 on ECP5, then 32 and 16 (yosys uses one multiplier for each 9 x 9 product, so these counts are upper bounds: two 9 x 9 products fit one 18 x 18 or one DSP48 in a hand-packed design, not tried).

### 4.2 The vector unit

**The wave-1 vector unit, by unit**


| unit | NAND2 256 | 128 | 64 | LUT4 256 | 128 | 64 | LUT6 256 | 128 | 64 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| registers 16 x strip | 61,578 | 30,869 | 15,409 | 768 | 384 | 192 | 512 | 256 | 128 |
| lane ALU | 19,618 | 9,923 | 4,811 | 5,225 | 2,671 | 1,323 | 3,280 | 1,581 | 807 |
| shifts with rounding | 11,582 | 5,797 | 2,982 | 6,821 | 3,364 | 1,944 | 3,899 | 1,955 | 988 |
| multiplier array + vdacc tree | 87,737 | 43,726 | 22,140 | 7,491 | 3,655 | 1,759 | 4,713 | 2,247 | 1,132 |
| vsad (estimate: 8 NAND2 and 8 LUT a byte) | 800 | 400 | 200 | 256 | 128 | 64 | 256 | 128 | 64 |
| reductions (vacc, vmaxacc, vminacc) | 20,577 | 9,803 | 4,604 | 7,593 | 3,573 | 1,707 | 4,173 | 2,032 | 861 |
| narrowing store | 8,498 | 4,233 | 2,144 | 5,773 | 2,938 | 1,462 | 2,586 | 1,300 | 638 |
| vfir (+ 112 halo flip-flops) | 13,008 | 7,271 | 4,440 | 2,303 | 1,214 | 719 | 2,785 | 1,092 | 567 |
| segment load and store | 23,272 | 10,369 | 3,329 | 20,769 | 8,869 | 3,521 | 7,078 | 2,985 | 959 |
| vtbl.b | 12,736 | 6,368 | 1,472 | 5,376 | 2,688 | 456 | 1,615 | 807 | 192 |
| load alignment and store merge | 14,913 | 5,903 | 2,162 | 7,185 | 2,932 | 863 | 3,261 | 1,239 | 555 |
| strip control (4 adders + estimate; not scaled) | 4,640 | 4,640 | 4,640 | 756 | 756 | 756 | 756 | 756 | 756 |
| (wave 2) compare, select (vcmp_mw for NAND2 and ECP5, vcmp2 for Xilinx) + vbsl | 3,813 | 1,896 | 949 | 1,624 | 925 | 504 | 882 | 445 | 223 |
| (wave 2) conversions | 16,007 | 8,053 | 3,972 | 5,634 | 2,955 | 1,356 | 3,878 | 1,774 | 959 |

**Totals and the saving against the 256-bit strip**


Flip-flops are inside the NAND2 count (6 each); in the FPGA columns they are listed apart (LUT4 and LUT6 are logic and distributed RAM only).  The registers are 16 x strip bits of distributed RAM with 3 read ports (a copy of the array for each port) in both FPGA flows: no block RAM.

| configuration | strip | NAND2 eq | saving | ECP5 LUT4 | saving | ECP5 FF | MULT18X18D | xc7 LUT6 | saving | xc7 FF | DSP48E1 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| wave 1, 16 integer lanes at 256 bits (8 at 64) | 256 bit | 278,959 | - | 70,316 | - | 624 | 64 | 34,914 | - | 624 | 64 |
|  | 128 bit | 139,302 | 50% | 33,172 | 53% | 368 | 32 | 16,378 | 53% | 368 | 32 |
|  | 64 bit | 68,333 | 76% | 14,766 | 79% | 240 | 16 | 7,647 | 78% | 240 | 16 |
| wave 1 and 2 | 256 bit | 298,779 | - | 77,574 | - | 624 | 64 | 39,674 | - | 624 | 64 |
|  | 128 bit | 149,251 | 50% | 37,052 | 52% | 368 | 32 | 18,597 | 53% | 368 | 32 |
|  | 64 bit | 73,254 | 75% | 16,626 | 79% | 240 | 16 | 8,829 | 78% | 240 | 16 |
| wave 1 and 2 with floating-point lanes | 256 bit | 384,313 | - | 102,936 | - | 624 | 96 | 48,673 | - | 624 | 80 |
|  | 128 bit | 191,922 | 50% | 50,270 | 51% | 368 | 48 | 23,134 | 52% | 368 | 40 |
|  | 64 bit | 94,559 | 75% | 23,189 | 77% | 240 | 24 | 10,919 | 78% | 240 | 20 |

The lane count follows the strip (the lane names refer to the 256-bit strip): at 128 bits 8 halfword lanes, 4 word lanes, 8 byte-product halfword lanes of the array (a vdot.b strip is 4 lanes of 4 products), 2 floating-point lanes; at 64 bits 4 halfword lanes, 2 word lanes, 1 doubleword lane, 2 floating-point lanes.
Floating-point lane count: 256 bit 8 fma32 lanes, 128 bit 4 fma32 lanes, 64 bit 2 fma32 lanes.

The saving is the whole unit's, including the strip control that does not scale. The register file is 16 x strip bits of distributed RAM with three read ports in both FPGA flows (a copy of the array for each read port); block RAM was not tried.

### 4.3 Fit in the FPGA parts

**Fit in the FPGA parts (wave 1 and 2 with floating-point lanes; the vector unit alone, not the scalar core, not the memory system)**


| strip | ECP5-85F: 84k LUT4, 156 18x18 | Artix-7 100T: 63k LUT6, 240 DSP48 | Artix-7 200T: 134k LUT6, 740 DSP48 |
|---|---|---|---|
| 256 bit | 123% of the LUT4, 96 of 156 multipliers (without fp lanes: 92%, 64) | 77% of the LUT6, 80 of 240 DSP (without fp lanes: 63%, 64) | 36% of the LUT6, 80 of 740 DSP (without fp lanes: 30%) |
| 128 bit | 60% of the LUT4, 48 of 156 multipliers (without fp lanes: 44%, 32) | 37% of the LUT6, 40 of 240 DSP (without fp lanes: 30%, 32) | 17% of the LUT6, 40 of 740 DSP (without fp lanes: 14%) |
| 64 bit | 28% of the LUT4, 24 of 156 multipliers (without fp lanes: 20%, 16) | 17% of the LUT6, 20 of 240 DSP (without fp lanes: 14%, 16) | 8% of the LUT6, 20 of 740 DSP (without fp lanes: 7%) |

The scalar core and the memory system are not in these figures. The study's scalar core (`vec-silicon.md`, `core-total.py`) is 219,324 to 307,618 NAND2 equivalents: 0.73 to 1.03 times the 256-bit unit (wave 1 and 2, no fp lanes), 1.5 to 2.1 times the 128-bit one, 3.0 to 4.2 times the 64-bit one. **An extrapolation, not a measurement**: if the core maps to FPGA cells at the vector unit's own ratio (0.26 ECP5 LUT4 and 0.13 Xilinx LUT6 for each NAND2 equivalent), it is 57k to 80k LUT4 or 29k to 41k LUT6, and the vector unit (wave 1 and 2, no floating-point lanes; with them in brackets) plus that core is, in per cent of the part's LUTs:

| strip | ECP5-85F (84k LUT4): unit [with fp], unit + core | Artix-7 100T (63k LUT6): unit [with fp], unit + core | Artix-7 200T (134k LUT6): unit [with fp], unit + core |
|---|---|---|---|
| 256 bits | 92% [123%], 160% to 187% | 63% [77%], 109% to 128% | 30% [36%], 51% to 60% |
| 128 bits | 44% [60%], 112% to 139% | 30% [37%], 76% to 94% | 14% [17%], 36% to 44% |
| 64 bits | 20% [28%], 88% to 115% | 14% [17%], 60% to 79% | 7% [8%], 28% to 37% |

The extrapolated core could be wrong by a factor of two either way (the vector unit is mostly multiplexers and adders; the core is also control, a decoder and translation buffers, and its flip-flops are not counted in LUTs); the table says only which strips are not in question. Neither the memory system, the caches nor routing are in it, and a design should leave 15 to 25% of a part free for routing.

## 5. Speed by strip

### 5.1 Results do not depend on the strip, except where listed

**This is the study of 2026-11-18 that found the five places; they are closed (errata 173 to 175, `vec-isa.md` section 8). Below, the table and the list are as measured then; the checks marked "switched off" are no longer switched off: `vec-basic` (check 4 is now a block with an accumulator and a `vfin`), `vec-wave1` (the register-form test is gone) and `vec-restart` (the state a handler saw is checked as a relation) pass unmodified at 16, 32 and 64 bytes, and `tools/strip-equiv.py` has no patches.**

The programs of `tests/sim` (assembled and linked as `tools/check-sim64.sh` does) and `llvm/check.sh` were run at strips of 8, 16, 32 and 64 bytes (`tools/strip-equiv.py`). Results:

52 programs of tests/sim, each run at 4 strips (the 3 tests that look at the strip are run a second time with those checks switched off); 52 runs gave the same exit status and standard output at all four strips, 3 runs differ; the programs that are not in the table below gave the expected exit status and the same output at all four.

Patched copy of vec-basic switches off: check 4: vlen.b is 32 (1).

Patched copy of vec-restart switches off: every check of the rows of the kernels kern17 kern48 kern49 kern51, the blocks of which store lanes that depend on the strip (a register-form vtbl.b, or a vclr accumulator stored or reduced inside the block; the expected states are the strip-32 ones; the rows of all other kernels run all checks); checks 5 to 11: the registers and the memory the handler sees at a fault (the progress at the strip it stopped in) (7).

Patched copy of vec-wave1 switches off: check 63: vtbl.b with a table register, the result of lanes 16 and above depends on the strip (1).

| test | patched | expected exit | exit at strip 8, 16, 32, 64 | stdout identical at all four | verdict |
|---|---|---:|---|---|---|
| vec-basic | no | 0 | 4 4 0 4 | yes | DIFFERS |
| vec-basic | yes | 0 | 0 0 0 0 | yes | same |
| vec-restart | no | 0 | 5 5 0 5 | yes | DIFFERS |
| vec-restart | yes | 0 | 0 0 0 0 | yes | same |
| vec-wave1 | no | 0 | 63 63 0 63 | yes | DIFFERS |
| vec-wave1 | yes | 0 | 0 0 0 0 | yes | same |

vacc.f of 1000 binary32 values (seeded random, mixed sign, 10^-3 to 10^3), the result as binary32 bits by strip: 8: 0xc602a2a3, 16: 0xc602a2a0, 32: 0xc602a2a1, 64: 0xc602a2a1 (they differ: a floating-point sum depends on the strip)

llvm/check.sh at each strip (`PDP64_VSTRIP=8|16|32|64`; the `.ll` tests, the C programs through two pipelines, and the vector kernels of `llvm/tests/vec` in four builds each): **197 ok and 0 FAIL at every strip, and the output lines identical** (none differs between strip 32 and 8, 16 or 64).

On the benchmark kernels (section 5.2): the exit status and a hash of every global array of the driver (all the data the kernels read and write), written to standard output, are **identical at all 20 settings of strip, port and commit for all 47 programs**. The bench's data are small integers, whose sums are exact, so it does not exercise the order dependence of a floating-point sum; the probe above does.

**What a program can see of the strip (the exceptions)**

1. **`vlen.b` returns the strip** (by design): `tests/sim/vec-basic.s` check 4 expects 32.
2. **The register form of `vtbl.b vD, vT, vI`** takes its table from the 16 bytes of `vT` that belong to the lane's group of 16 lanes, and a lane of `vT` that is not in the strip reads as 0. A program that loads the table register from a stream with different 16-byte groups, or that relies on bytes 16 to 31 of a 32-byte strip, gets different results at 8 and 16 bytes (`tests/sim/vec-wave1.s` test 63 expects the strip-32 result; at 8 a lane sees 8 table bytes) and at 64. The memory form (a 16-byte table at `(Ra)`) is strip independent. **A strip-independent definition of the register form** would be "the table is bytes 0 to 15 of `vT` for every lane", the meaning of the memory form: it costs the same silicon (`vtbl_one` 12,663 against 12,736 at 256 bits in `vec-silicon.md`). That is a proposal; it was not tested here.
3. **A `vclr` accumulator that the block itself reads inside the block** (a `vst` of the running accumulator, or a `vacc` of it in every strip) shows lane-wise partial sums that depend on VL: the kernels kern48, kern49 and kern51 of `tests/sim/vec-restart.S` differ. An accumulator reduced once after `vend` does not depend on the strip (the other accumulating kernels of the restart test, and the benchmark kernels, give identical results).
4. **A floating-point reduction** is order dependent. `vacc.f` of 1,000 seeded random binary32 values of mixed sign and size gives 8: 0xc602a2a3, 16: 0xc602a2a0, 32: 0xc602a2a1, 64: 0xc602a2a1 (binary32 bits at strip 8, 16, 32, 64): the known reproducibility issue, here with numbers. Integer reductions, `vdot`, `vsad` are exact modulo 2^n and do not depend on the strip. `vfmab` and `vfir` in floating point were not probed separately.
5. **A fault handler sees the registers and memory as they were at the start of the strip that faulted** (a whole number of strips), so what it sees differs by strip (`vec-restart.S` checks 5 to 11); the state after the restart does not (every later check passes with those switched off).

### 5.2 The cycle model on the kernels

Model: one cycle for each vector instruction in a strip (a vfir one for each tap), a commit of 1 cycle for each strip, a vend 1 cycle, the strip is the greater of its compute cycles and the cycles its memory instructions hold the port (bytes / port, rounded up for each instruction), scalar instructions 1 cycle each (a vec is one of them).  Per kernel the set-up of the driver is subtracted.
47 programs ran (46 kernels `lv` and 1 hand-written); 41 of them have a vec block (40 lv, 1 hand); without a block (no vector code in the lv build, the strip cannot matter): k_put8h k_hist k_ssm k_q4dot k_gray k_clamp8.
Hand-written kernels of vec-forms (k_*.vec.s, run with the same driver): used: k_sad; assembled but dropped, the program's result differs from the lv build of the same kernel (the cause was not investigated: the listings take their own register arguments, the driver calls with the C convention): k_dctop_fill k_fmac; not assembled by the current as64 (older syntax): k_prep8.vec.s k_put8h.vec.s k_put8h.vecfir.s k_dctop_sum.vec.s k_ssm.vec.s.
Results (exit status and a hash of every global array of the driver, written to standard output) of the kernels at all 20 (strip, port, commit) settings: identical for 47 of 47 programs.

**Per kernel (port 16 bytes a cycle, commit 1): vector instructions executed, strips, model cycles in total (scalar + vector), slowdown against strip 32**


| kernel | build | vec instrs (at 32) | strips 32 / 16 / 8 | cycles 32 | cycles 16 | cycles 8 | slow 16 | slow 8 | vector cycles 16/32 | memory / compute cycles at 32 | scalar share at 32 | class |
|---|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| k_sad | hand | 96 | 32 / 64 / 128 | 306 | 402 | 658 | 1.314 | 2.150 | 1.55 | 1.33 | 0.42 | between |
| k_avg8 | lv | 128 | 32 / 63 / 125 | 240 | 333 | 643 | 1.387 | 2.679 | 1.42 | 1.48 | 0.07 | between |
| k_blend | lv | 1375 | 125 / 250 / 500 | 1534 | 3034 | 6034 | 1.978 | 3.934 | 2.00 | 0.36 | 0.02 | compute-bound |
| k_bytemap | lv | 96 | 32 / 63 / 125 | 176 | 269 | 517 | 1.528 | 2.938 | 1.58 | 1.31 | 0.09 | between |
| k_clampr | lv | 250 | 125 / 250 / 500 | 512 | 762 | 1512 | 1.488 | 2.953 | 1.50 | 1.50 | 0.02 | between |
| k_cmul | lv | 567 | 63 / 125 / 250 | 846 | 1280 | 2530 | 1.513 | 2.991 | 1.53 | 1.32 | 0.03 | between |
| k_copy16 | lv | 126 | 63 / 125 / 250 | 329 | 391 | 766 | 1.188 | 2.328 | 1.20 | 1.98 | 0.05 | memory-bound at 32 |
| k_daxpy | lv | 1000 | 250 / 500 / 1000 | 1763 | 2513 | 5013 | 1.425 | 2.843 | 1.43 | 1.50 | 0.01 | between |
| k_dctop_fill | lv | 64 | 32 / 64 / 128 | 304 | 400 | 592 | 1.316 | 1.947 | 1.86 | 1.00 | 0.63 | scalar-dominated |
| k_dctop_sum | lv | 64 | 32 / 63 / 125 | 132 | 225 | 411 | 1.705 | 3.114 | 1.96 | 0.98 | 0.27 | compute-bound |
| k_ddot | lv | 1000 | 250 / 500 / 1000 | 1283 | 2533 | 5033 | 1.974 | 3.923 | 2.00 | 1.00 | 0.02 | compute-bound |
| k_dequant | lv | 500 | 125 / 250 / 500 | 641 | 1266 | 2516 | 1.975 | 3.925 | 2.00 | 0.75 | 0.02 | compute-bound |
| k_dgemv_n | lv | 2048 | 512 / 1024 / 2048 | 3025 | 5585 | 10705 | 1.846 | 3.539 | 1.99 | 1.00 | 0.14 | compute-bound |
| k_dgemv_t | lv | 2080 | 528 / 1056 / 2112 | 4386 | 5970 | 11186 | 1.361 | 2.550 | 1.43 | 1.49 | 0.16 | between |
| k_dger | lv | 2048 | 512 / 1024 / 2048 | 4299 | 5835 | 10955 | 1.357 | 2.548 | 1.42 | 1.50 | 0.16 | between |
| k_dot16 | lv | 189 | 63 / 125 / 250 | 347 | 533 | 1033 | 1.536 | 2.977 | 1.59 | 1.32 | 0.09 | between |
| k_dscal | lv | 750 | 250 / 500 / 1000 | 1261 | 2011 | 4011 | 1.595 | 3.181 | 1.60 | 1.33 | 0.01 | between |
| k_fmac | lv | 500 | 125 / 250 / 500 | 888 | 1263 | 2513 | 1.422 | 2.830 | 1.43 | 1.50 | 0.01 | between |
| k_i2f | lv | 500 | 125 / 250 / 500 | 640 | 1265 | 2515 | 1.977 | 3.930 | 2.00 | 1.00 | 0.02 | compute-bound |
| k_isum | lv | 250 | 125 / 250 / 500 | 407 | 782 | 1532 | 1.921 | 3.764 | 2.00 | 1.00 | 0.08 | compute-bound |
| k_maskblend | lv | 192 | 32 / 63 / 125 | 308 | 463 | 897 | 1.503 | 2.912 | 1.54 | 1.31 | 0.07 | between |
| k_mix16 | lv | 252 | 63 / 125 / 250 | 457 | 643 | 1268 | 1.407 | 2.775 | 1.42 | 1.49 | 0.04 | between |
| k_mla32 | lv | 625 | 125 / 250 / 500 | 1147 | 1522 | 3022 | 1.327 | 2.635 | 1.33 | 1.60 | 0.02 | between |
| k_mulh16 | lv | 252 | 63 / 125 / 250 | 457 | 643 | 1268 | 1.407 | 2.775 | 1.42 | 1.49 | 0.04 | between |
| k_prep8 | lv | 189 | 63 / 125 / 250 | 267 | 515 | 1015 | 1.929 | 3.801 | 1.98 | 0.99 | 0.05 | compute-bound |
| k_q15mul | lv | 252 | 63 / 125 / 250 | 457 | 643 | 1268 | 1.407 | 2.775 | 1.42 | 1.49 | 0.04 | between |
| k_q8blk | lv | 93 | 31 / 62 / 124 | 779 | 872 | 1120 | 1.119 | 1.438 | 1.50 | 1.33 | 0.76 | scalar-dominated |
| k_q8dot | lv | 96 | 32 / 63 / 125 | 192 | 285 | 533 | 1.484 | 2.776 | 1.58 | 1.31 | 0.17 | between |
| k_quant | lv | 500 | 125 / 250 / 500 | 638 | 1263 | 2513 | 1.980 | 3.939 | 2.00 | 0.75 | 0.02 | compute-bound |
| k_relu | lv | 375 | 125 / 250 / 500 | 642 | 1017 | 2017 | 1.584 | 3.142 | 1.60 | 1.33 | 0.02 | between |
| k_rmsnorm | lv | 375 | 125 / 250 / 500 | 7523 | 8023 | 9023 | 1.066 | 1.199 | 2.00 | 0.67 | 0.93 | scalar-dominated |
| k_sad | lv | 96 | 32 / 64 / 128 | 438 | 534 | 790 | 1.219 | 1.804 | 1.55 | 1.33 | 0.60 | scalar-dominated |
| k_sadrow | lv | 96 | 32 / 63 / 125 | 192 | 285 | 533 | 1.484 | 2.776 | 1.58 | 1.31 | 0.17 | between |
| k_saxpy | lv | 500 | 125 / 250 / 500 | 888 | 1263 | 2513 | 1.422 | 2.830 | 1.43 | 1.50 | 0.01 | between |
| k_sdot | lv | 500 | 125 / 250 / 500 | 659 | 1284 | 2534 | 1.948 | 3.845 | 2.00 | 1.00 | 0.05 | compute-bound |
| k_sgemm_nt | lv | 2048 | 512 / 1024 / 2048 | 3474 | 6034 | 11154 | 1.737 | 3.211 | 1.98 | 1.00 | 0.24 | compute-bound |
| k_softmax | lv | 64 | 32 / 64 / 128 | 3464 | 3560 | 3752 | 1.028 | 1.083 | 1.99 | 1.00 | 0.97 | scalar-dominated |
| k_split | lv | 189 | 63 / 125 / 250 | 601 | 663 | 1038 | 1.103 | 1.727 | 1.11 | 2.65 | 0.06 | memory-bound at 32 |
| k_thresh | lv | 750 | 125 / 250 / 500 | 899 | 1774 | 3524 | 1.973 | 3.920 | 2.00 | 0.67 | 0.03 | compute-bound |
| k_vtx | lv | 3000 | 125 / 250 / 500 | 3347 | 6472 | 12722 | 1.934 | 3.801 | 2.00 | 1.00 | 0.07 | compute-bound |
| k_vtxaos | lv | 576 | 32 / 63 / 125 | 653 | 1242 | 2420 | 1.902 | 3.706 | 1.97 | 0.87 | 0.07 | compute-bound |

**Summary at port 16, commit 1 (geometric mean and worst case of cycles(strip) / cycles(32) over the kernels with a block)**


| set | kernels | geomean 16 | geomean 8 | worst 16 | worst 8 |
|---|---:|---:|---:|---|---|
| all with a block | 41 | 1.528 | 2.802 | k_quant 1.980 | k_quant 3.939 |
| lv only | 40 | 1.534 | 2.820 | k_quant 1.980 | k_quant 3.939 |
| hand-written only | 1 | 1.314 | 2.150 | k_sad 1.314 | k_sad 2.150 |
| not scalar-dominated | 36 | 1.590 | 3.068 | k_quant 1.980 | k_quant 3.939 |
| compute-bound | 14 | 1.911 | 3.730 | k_quant 1.980 | k_quant 3.939 |
| memory-bound at 32 | 2 | 1.145 | 2.005 | k_copy16 1.188 | k_copy16 2.328 |
| between | 20 | 1.446 | 2.792 | k_dscal 1.595 | k_dscal 3.181 |
| scalar-dominated | 5 | 1.145 | 1.457 | k_dctop_fill 1.316 | k_dctop_fill 1.947 |

Class (at port 16): compute-bound = the vector cycles double at both halvings (ratio 1.9 or more); memory-bound at 32 = the vector cycles hardly change from 32 to 16 (1.2 or less: a commit cost of 1 a strip is the allowance); between = the rest; scalar-dominated = more than half of the cycles at strip 32 are scalar instructions.

**Memory-bound or compute-bound, by port and by step (of the 36 kernels with a block that are not scalar-dominated at strip 32; the vector cycles when the strip halves: unchanged = ratio 1.2 or less, doubles = 1.9 or more)**


| port | 32 to 16: unchanged / between / doubles | 16 to 8: unchanged / between / doubles | 64 to 32 (the vector cycles when the strip doubles back): unchanged / between / doubles |
|---:|---|---|---|
| 8 | 31 / 4 / 1 | 2 / 20 / 14 | 35 / 0 / 1 |
| 16 | 2 / 20 / 14 | 0 / 1 / 35 | 30 / 5 / 1 |
| 32 | 0 / 2 / 34 | 0 / 0 / 36 | 2 / 20 / 14 |

**Sensitivity: geometric mean (and worst) slowdown against strip 32 of the same port and commit, over the 41 kernels with a block**


| port (bytes a cycle) | commit | strip 16 | strip 8 | strip 64 (cycles against strip 32: below 1 is faster) |
|---:|---:|---|---|---|
| 8 | 1 | 1.139 (worst 1.978) | 1.783 (worst 3.934) | 0.941 (fastest 0.515) |
| 16 | 0 | 1.459 (worst 1.976) | 2.640 (worst 3.928) | 0.945 (fastest 0.516) |
| 16 | 1 | 1.528 (worst 1.980) | 2.802 (worst 3.939) | 0.883 (fastest 0.515) |
| 16 | 2 | 1.578 (worst 1.983) | 2.920 (worst 3.949) | 0.838 (fastest 0.514) |
| 32 | 1 | 1.775 (worst 1.990) | 3.271 (worst 3.969) | 0.675 (fastest 0.513) |

**Per kernel at the other ports (cycles at strip 32, slowdown at strip 16 and 8 against strip 32), commit 1**


| kernel | build | cycles 32 (port 8) | slow 16 | slow 8 | cycles 32 (port 32) | slow 16 | slow 8 |
|---|---|---:|---:|---:|---:|---:|---:|
| k_sad | hand | 434 | 1.074 | 1.516 | 274 | 1.467 | 2.401 |
| k_avg8 | lv | 426 | 1.073 | 1.509 | 178 | 1.871 | 3.612 |
| k_blend | lv | 1534 | 1.978 | 3.934 | 1534 | 1.978 | 3.934 |
| k_bytemap | lv | 300 | 1.103 | 1.723 | 145 | 1.855 | 3.566 |
| k_clampr | lv | 762 | 1.328 | 1.984 | 387 | 1.969 | 3.907 |
| k_cmul | lv | 1593 | 1.039 | 1.588 | 660 | 1.939 | 3.833 |
| k_copy16 | lv | 579 | 1.107 | 1.323 | 205 | 1.907 | 3.737 |
| k_daxpy | lv | 3263 | 1.077 | 1.536 | 1263 | 1.990 | 3.969 |
| k_dctop_fill | lv | 368 | 1.087 | 1.609 | 304 | 1.316 | 1.947 |
| k_dctop_sum | lv | 194 | 1.160 | 2.119 | 132 | 1.705 | 3.114 |
| k_ddot | lv | 2283 | 1.110 | 2.205 | 1283 | 1.974 | 3.923 |
| k_dequant | lv | 766 | 1.653 | 3.285 | 641 | 1.975 | 3.925 |
| k_dgemv_n | lv | 5073 | 1.101 | 2.110 | 3025 | 1.846 | 3.539 |
| k_dgemv_t | lv | 7490 | 1.070 | 1.493 | 3362 | 1.776 | 3.327 |
| k_dger | lv | 7371 | 1.069 | 1.486 | 3275 | 1.782 | 3.345 |
| k_dot16 | lv | 596 | 1.104 | 1.733 | 285 | 1.870 | 3.625 |
| k_dscal | lv | 2261 | 1.111 | 1.774 | 1011 | 1.989 | 3.967 |
| k_fmac | lv | 1638 | 1.076 | 1.534 | 638 | 1.980 | 3.939 |
| k_i2f | lv | 1140 | 1.110 | 2.206 | 640 | 1.977 | 3.930 |
| k_isum | lv | 657 | 1.190 | 2.332 | 407 | 1.921 | 3.764 |
| k_maskblend | lv | 556 | 1.056 | 1.613 | 246 | 1.882 | 3.646 |
| k_mix16 | lv | 831 | 1.075 | 1.526 | 333 | 1.931 | 3.808 |
| k_mla32 | lv | 2147 | 1.058 | 1.408 | 772 | 1.972 | 3.915 |
| k_mulh16 | lv | 831 | 1.075 | 1.526 | 333 | 1.931 | 3.808 |
| k_prep8 | lv | 453 | 1.137 | 2.241 | 267 | 1.929 | 3.801 |
| k_q15mul | lv | 831 | 1.075 | 1.526 | 333 | 1.931 | 3.808 |
| k_q8blk | lv | 903 | 1.034 | 1.240 | 748 | 1.166 | 1.497 |
| k_q8dot | lv | 316 | 1.098 | 1.687 | 161 | 1.770 | 3.311 |
| k_quant | lv | 763 | 1.655 | 3.294 | 638 | 1.980 | 3.939 |
| k_relu | lv | 1142 | 1.109 | 1.766 | 517 | 1.967 | 3.901 |
| k_rmsnorm | lv | 7648 | 1.049 | 1.180 | 7523 | 1.066 | 1.199 |
| k_sad | lv | 566 | 1.057 | 1.396 | 406 | 1.315 | 1.946 |
| k_sadrow | lv | 316 | 1.098 | 1.687 | 161 | 1.770 | 3.311 |
| k_saxpy | lv | 1638 | 1.076 | 1.534 | 638 | 1.980 | 3.939 |
| k_sdot | lv | 1159 | 1.108 | 2.186 | 659 | 1.948 | 3.845 |
| k_sgemm_nt | lv | 5522 | 1.093 | 2.020 | 3474 | 1.737 | 3.211 |
| k_softmax | lv | 3528 | 1.009 | 1.063 | 3464 | 1.028 | 1.083 |
| k_split | lv | 1101 | 1.056 | 1.170 | 352 | 1.528 | 2.949 |
| k_thresh | lv | 1149 | 1.544 | 3.067 | 899 | 1.973 | 3.920 |
| k_vtx | lv | 6347 | 1.020 | 2.004 | 3347 | 1.934 | 3.801 |
| k_vtxaos | lv | 1087 | 1.143 | 2.226 | 653 | 1.902 | 3.706 |

**Strips of 64 bytes (the speed-up over 32 at port 16, commit 1)**


| kernel | build | cycles 32 | cycles 64 | speed-up |
|---|---|---:|---:|---:|
| k_sad | hand | 306 | 290 | 1.055 |
| k_avg8 | lv | 240 | 223 | 1.076 |
| k_blend | lv | 1534 | 790 | 1.942 |
| k_bytemap | lv | 176 | 159 | 1.107 |
| k_clampr | lv | 512 | 388 | 1.320 |
| k_cmul | lv | 846 | 815 | 1.038 |
| k_copy16 | lv | 329 | 298 | 1.104 |
| k_daxpy | lv | 1763 | 1638 | 1.076 |
| k_dctop_fill | lv | 304 | 288 | 1.056 |
| k_dctop_sum | lv | 132 | 115 | 1.148 |
| k_ddot | lv | 1283 | 1158 | 1.108 |
| k_dequant | lv | 641 | 393 | 1.631 |
| k_dgemv_n | lv | 3025 | 2769 | 1.092 |
| k_dgemv_t | lv | 4386 | 4122 | 1.064 |
| k_dger | lv | 4299 | 4043 | 1.063 |
| k_dot16 | lv | 347 | 316 | 1.098 |
| k_dscal | lv | 1261 | 1136 | 1.110 |
| k_fmac | lv | 888 | 826 | 1.075 |
| k_i2f | lv | 640 | 578 | 1.107 |
| k_isum | lv | 407 | 345 | 1.180 |
| k_maskblend | lv | 308 | 290 | 1.062 |
| k_mix16 | lv | 457 | 426 | 1.073 |
| k_mla32 | lv | 1147 | 1085 | 1.057 |
| k_mulh16 | lv | 457 | 426 | 1.073 |
| k_prep8 | lv | 267 | 236 | 1.131 |
| k_q15mul | lv | 457 | 426 | 1.073 |
| k_q8blk | lv | 779 | 779 | 1.000 |
| k_q8dot | lv | 192 | 175 | 1.097 |
| k_quant | lv | 638 | 390 | 1.636 |
| k_relu | lv | 642 | 580 | 1.107 |
| k_rmsnorm | lv | 7523 | 7337 | 1.025 |
| k_sad | lv | 438 | 422 | 1.038 |
| k_sadrow | lv | 192 | 175 | 1.097 |
| k_saxpy | lv | 888 | 826 | 1.075 |
| k_sdot | lv | 659 | 597 | 1.104 |
| k_sgemm_nt | lv | 3474 | 3218 | 1.080 |
| k_softmax | lv | 3464 | 3448 | 1.005 |
| k_split | lv | 601 | 570 | 1.054 |
| k_thresh | lv | 899 | 589 | 1.526 |
| k_vtx | lv | 3347 | 3285 | 1.019 |
| k_vtxaos | lv | 653 | 561 | 1.164 |

How to read it. A strip is `max(compute, memory) + commit` cycles. At strip 32 and a 16-byte port a 32-byte load takes 2 cycles of the port while the instruction issues in 1, so a loop of one load, one store and one arithmetic instruction is memory-bound (memory 4, compute 3); halving the strip halves the memory time of a strip and not its compute time, so at 16 bytes the same loop is compute-bound (memory 2, compute 3) and its cycles grow by less than 2 times (1.6 with the commit). The column "memory / compute cycles at 32" is near 1.5 for most kernels: they are balanced, which is why the geometric mean lies between 1 and 2. Kernels with long arithmetic bodies (`k_blend`, `k_ddot`, `k_thresh`, `k_vtx`, `k_quant`) are compute-bound and take twice as long at 16 bytes and four times at 8. The kernels dominated by scalar code (`k_softmax`, `k_rmsnorm`, `k_q8blk`, `k_sad`, `k_dctop_fill`) hardly notice the strip, as the table's scalar share says.

## 6. What the numbers leave out, and what was not verified

* **Not verified: the behaviour of the new Verilog.** `vecw.v` was written to be counted, as the blocks of `vec-silicon.md`; it was not simulated at any width (no test bench for it), and its 256-bit blocks were checked only by their gate counts against the existing blocks (section 3), which is evidence of the same structure, not of the same function.
* **Not verified: timing.** No clock period, no critical path. A narrower strip also has shorter wires and shallower trees; a wider one may not make the clock.
* **vsad** is the study's estimate (8 NAND2 equivalents and 8 LUT for each byte of the strip), scaled; **the strip control** (4 adders and 2,000 NAND2 equivalents, 4,640 in all) is the study's estimate and is not scaled.
* **Segment loads and stores at 64 bits**: a 4-byte field element with 3 or 4 fields (12 or 16 bytes) does not fit an 8-byte beat; those two cases are left out of the network (`WIDTH` in `vecw.v`), so the 64-bit segment count (3,329 NAND2 equivalents for both) is short of a design that handles them with two beats an element, by an amount not measured. The simulator handles them.
* **vtbl at 64 bits** [now: a strip of 8 bytes is outside the architecture and `vtbl.b` has the memory form only, errata 173] selects among 8 bytes, the semantics of a table lane outside the strip (section 5.1, item 2). A design that kept a 16-byte table would cost more.
* **vfir** keeps its 8-tap window and 112 halo flip-flops at every strip; whether a 64-bit strip supports a useful vfir was not examined.
* **The register file** is counted as 16 x strip flip-flops (6 NAND2 each) or distributed RAM; the latch variant of `vec-silicon.md` (which saves 5%) and block RAM were not synthesised at the new widths. The variant A of the shared array (a monolithic 16 x 16 array plus a separate `vdot.b` array) was not synthesised either; the totals are variant B, as the headline of `vec-silicon.md`.
* **The 64-byte strip** was run in the simulator only (cycles against strip 32: geometric mean 0.94 at a port of 8 bytes, 0.88 at 16, 0.68 at 32; the compute-bound kernels gain up to 2 times, the memory-bound ones nothing); no gates were synthesised for 512 bits, so what it would cost in logic (about twice the 256-bit unit by the scaling above) is extrapolated.
* **The model**: instructions issue back to back; a strided load moves only its elements' bytes (it would not on a real cache); the hand-written listings `k_prep8`, `k_put8h`, `k_dctop_sum`, `k_ssm` do not assemble with the current `as64` (an older syntax) and `k_dctop_fill`, `k_fmac` assemble but do not give the compiled kernels' results with the driver (the cause was not investigated), so they are not in the tables.
* **QEMU** [now: the executor was copied to QEMU and QEMU rebuilt for errata 173, `qemu/sync.sh`; the strip there stays 32] was not rebuilt with the new executor (`qemu/sync.sh --check` is clean; the strip there stays 32).

## 7. Recommendation

*By the owner's priorities on record (the most work per instruction and the smallest code, reasonable performance with a minimal silicon footprint).*

**FPGA: 128 bits (16 bytes).** It halves the logic (50% of the NAND2 equivalents, 52% of the ECP5 LUT4, 53% of the Xilinx LUT6, half of the multipliers: 32 of the 156 of an ECP5-85F, 32 of the 240 of an Artix-7 100T) for a geometric-mean cost of 1.53 times the cycles on the vector kernels at a 16-byte port (1.14 at 8 bytes a cycle; the port widths are sensitivity parameters, not measurements of any board), and the worst case is 2 times, for compute-bound loops. Which part (4.3, the core extrapolated): **an Artix-7 200T** takes the 128-bit unit with the core at 36 to 44% of its LUT6 and the 256-bit one at 51 to 60%; **an Artix-7 100T** takes the 128-bit unit with the core at 76 to 94% (tight; the 64-bit strip 60 to 79%); **an ECP5-85F** takes the 128-bit vector unit alone (44% of its LUT4) but not, by the extrapolation, the core beside it, even with the 64-bit strip (88 to 115%): it is a part for the unit on its own, or for a smaller core. To save more at any strip: the floating-point lanes are 16% of the ECP5's LUT4 at 128 bits; after the array of products the largest blocks are the register file, the conversions and the segment networks.

**Not the whole chip's area-time product.** With the scalar core as the study counted it (mid-range 263,471 NAND2 equivalents, not scaled) the chip's NAND2 count times the vector kernels' time (a workload that is all vector kernels, the case that favours the wide strip) is, relative to 256 bits:

| port (bytes a cycle) | 256 bits | 128 bits | 64 bits |
|---:|---:|---:|---:|
| 8 | 1.00 | 0.84 | 1.07 |
| 16 | 1.00 | 1.12 | 1.68 |
| 32 | 1.00 | 1.30 | 1.96 |
| (the chip alone, no vector time) | 1.00 | 0.73 | 0.60 |

so for a chip whose time is all in vector kernels the 256-bit strip is the better product at a 16-byte or wider port, and 128 bits is at least as good as 256 only at an 8-byte port; for any workload with scalar code in it the narrower strip gains. This is the arithmetic of the measured counts, not a measurement of a chip.

**ASIC.** Keep the strip a parameter of the generated design (`vecw.v` is that parameter in the Verilog). The model says the strip pays only up to what the memory port feeds: at an 8-byte port 256 bits is only 1.14 times faster than 128, at 16 bytes 1.53 times, at 32 bytes 1.77 times. By the owner's priorities (minimal silicon with reasonable performance) the choice is **128 bits for a 16-byte port**: the chip (with the study's core) is 27% smaller and the vector kernels take 1.53 times as long (the area-time product above, for an all-vector workload, is 1.12 against 1.00; it is below 1 only at an 8-byte port). **256 bits** is the choice only where vector throughput is the purpose of the chip and the first-level data cache delivers 32 bytes a cycle (then the product is the better one: 1.30 for 128 bits). A 64-byte strip would gain only 12% at a 16-byte port (and 32% at 32) for about twice the logic, and was not synthesised.

**Two changes of definition that make the strip invisible to programs**, both small: (a) `vtbl.b` in the register form takes its table from bytes 0 to 15 of `vT` for every lane (5.1 item 2); (b) the document that says programs must not depend on the strip (`vec-isa.md`) should list `vlen.b`, a `vclr` accumulator read inside the block, and floating-point reductions as the places where they can. **Done differently and more completely (errata 173 to 175): the register form was removed (one form, the memory one), the strip is invisible in all five places and the least strip is 16 bytes; the recommendation of 128 bits above is therefore the least strip an implementation may have. The measured cost of the canonical floating-point sum is in `vec-isa.md` 8.5: none at 128 bits.**

## 8. How to run it

From `tools/gates`: `./run-strip.sh [OUTDIR]` runs the four stages in order (`synth total equiv bench`, or any of them by name), default output `tools/gates/strip-results`:

* `synth`: `strip-synth.sh` on `vecw.v` at SNB = 32, 16, 8 and on `vec2.v vec3.v mem2.v fp2.v` at 256 bits (the check): `strip-32.tsv strip-16.tsv strip-8.tsv ref-32.tsv`, with the yosys statistics kept in `OUTDIR/stat` (resumable: a stat file that exists is not made again). About an hour on 12 cores with `JOBS=3` for each of the four runs.
* `total`: `strip-total.py OUTDIR` writes `area.md` and `area.tsv` (the tables above).
* `equiv`: `tools/strip-equiv.py OUTDIR` runs `tests/sim` and `llvm/check.sh` at each strip: `equiv.md`.
* `bench`: `tools/strip-bench.py OUTDIR` builds the kernels (needs `build/sim64`, the LLVM tools of `../llvm-build`, `clang`) and runs `sim64 -V -S s --vport=p --vcommit=c` for the strips, ports and commits: `bench.tsv`, `bench.md`.

Single commands: `sim64 -V -S 16 --vport=16 prog` (the model, one run); `PDP64_VSTRIP=16 tools/check-sim64.sh` (the `tests/sim` suite at a strip: all pass; `tools/check-sim64.sh` itself also runs the five vec tests at 16, 32 and 64); `PDP64_VSTRIP=16 llvm/check.sh`; `JOBS=10 tools/gates/strip-synth.sh 16 "vecw.v fp2.v" w_lanealu_mw w_vtbl_g16` (some blocks at a width).

Files: `tools/gates/vecw.v`, `strip-synth.sh`, `strip-total.py`, `run-strip.sh`, `tools/strip-equiv.py`, `tools/strip-bench.py`; changed: `common/pdp64exec_vec.inc`, `common/pdp64exec.h` (and their QEMU copies), `sim64/sim64.c`, `docs/sim64.md`.

A second cycle model for the same blocks, with latencies derived from yosys's logic depth (assumed delay per level and clock) and a comparison with the model above: [vec-latency.md](vec-latency.md). It does not change the recommendation of section 7 (a 128-bit strip costs 1.54 to 1.67 times, not 1.53, in the fpga-table model) but weakens the memory-bound argument of the headline.
