# The vector family redesign measured in gates, and the transistor count of the pdp64

**Status: a measurement, 2026-11-18, of the silicon figures of `vec-survey.md` (sections 5.1 and 5.2) and of the total for the chip; the assistant's work, for the owner to read.** The blocks were **written in Verilog and synthesised with yosys 0.52** (installed now; it was not when the survey was written), by the flow and in the unit of `vec-gates.md`. Nothing here changes the grammar, the manual or the existing files of `tools/gates/`; the new Verilog and scripts are new files there.

**What this is not.** A synthesis result is a technology-independent gate count of a *behavioural* description, not a layout. **Timing was not closed** (nothing here has a clock period or a critical path; a real design adds 20 to 50% for speed-up cells and buffers, U). **Wiring, clock distribution, scan, power and the pads are not counted. Power was not estimated.** The multipliers are yosys's default array multiplier (not Booth: with `synth -booth` `mul16s` is 2,491 instead of 3,023 and `mul8s` 611 instead of 698, so every multiplier-heavy figure below would fall by 10 to 18%; the baseline method was kept so that the numbers stay comparable). The same Verilog in a different file can map to a count that differs by up to 3% (the cause was not investigated: `lanealu_mw_noavg` was 17,704 in the first run and is 18,275 in the final one, after unrelated modules were deleted from the file); inside one file the count is repeatable. Differences of a few hundred NAND2 equivalents (the `vmla` row) are noise. Each new block was written for this count and **checked against a Python model only in the cases listed in section 8**; the blocks not listed there were not checked for behaviour.

## 1. Method and unit (as `vec-gates.md`)

`tools/gates/gates.sh` and the new `tools/gates/gates2.sh` (the same flow; it runs the modules in parallel) do, for each module M: `read_verilog F; synth -top M -flatten; abc -g NAND; opt_clean; stat`. `abc -g NAND` is yosys's built-in mapping of the logic to two-input NAND gates and inverters (no cell library, no liberty file). **NAND2 equivalents = (number of `$_NAND_`) + (number of `$_NOT_`) / 2.** Flip-flops are counted apart and **as 6 NAND2 equivalents each** in every total (`total.py`, `core-total.py`, `silicon-total.py`), a latch as 4; a flip-flop with a write enable (`$_DFFE_`) is counted as a plain flip-flop (the enable is taken as clock gating, as the register files are built). Arrays written as Verilog memories are flattened by yosys to flip-flops and multiplexers. In transistors, a NAND2 is 4 and an inverter 2 (static CMOS), a flip-flop of 6 equivalents is 24; the conversion and its range are in section 7.

## 2. The baseline reproduces exactly

`sh tools/gates/gates.sh yosys blocks.v` (16 blocks) and the same over `core.v`, `aes.v`, `decode.v` (17 blocks) give **the same numbers as `arch-data/vec-gates-blocks.tsv` and `arch-data/core-gates-blocks.tsv` in all 33 blocks** (compared with `diff` after sorting; yosys 0.52, git `fee39a3`, the version that made them; so no difference of version or script can arise). `core-total.py` over the new run gives the scalar core **219,324 to 307,618 NAND2 equivalents** (219 k to 308 k), as `vec-gates.md`. The `vdot.b` of 37,000 is confirmed: 8 x `dot4` in a full strip is **37,052** (`vdotb_s`), and with the sign flags for `.b .bu .bsu` (9 x 9 multipliers) **36,200** (`vdotb_sep`).

## 3. What was synthesised, against the survey

Files: `vec2.v` (lane ALU, shifts, narrowing, reductions, `vtbl`, compare, segments, register files, the separate forms), `vec3.v` (the shared multiplier arrays, `vfir`), `fp2.v` (floating-point multiply-add, tile, GEMM sequencer, gather, conversions), `mem2.v` (load alignment and store merge), `blocks.v` (the baseline). Command for all of it: `tools/gates/run-silicon.sh` (about 15 minutes on 12 cores); for one block `tools/gates/gates2.sh vec2.v lanealu_mw`. The table is the output of `silicon-total.py` over `vec-silicon-blocks.tsv`. **"Measured" is the cost of the instruction added to a unit that already has the shared datapath** unless the row says otherwise (the survey's estimates were of that kind); the standalone form, with its own datapath, is in the last column. Rows are marked **(>30%)** where the measure is more than 1.3 times or less than 0.7 of the middle of the survey's estimate.

| block | measured (NAND2 eq) | survey (NAND2 eq) | measured / survey (against the middle) | file | module(s) | the separate or standalone form |
|---|---:|---:|---:|---|---|---|
| vavg, vavgu (all lane widths): added to the lane ALU | 1507 | 1000 to 2000 | 1.00 | vec2.v | lanealu_mw - lanealu_mw_noavg | vavg_mw: 2783 |
| vsts rounding shift + saturating narrow (w to b and l to w), added to the plain saturating narrow | 6859 | 2000 to 4000 | 2.29 **(>30%)** | vec2.v | narrow_both - narrow_both_plain | narrow_both: 8629 |
| vmulh, vmulhu, vmulhr (.w) on the shared 16 x 16 array | 6439 | 1000 to 2000 | 4.29 **(>30%)** | vec3.v | ms16_hi - vmul16_full | vmulh16_sep: 52613 |
| vmla vector by vector on the shared array | -319 | 0 to 1000 | -0.64 | vec3.v | ms16_hi_mla - ms16_hi (the difference is inside the noise of the mapper, a few hundred) | vmla16_sep: 22506 |
| vdot.w on the shared array | 5488 | 3000 to 4000 | 1.57 **(>30%)** | vec3.v | ms16_all - ms16_hi_mla | vdotw_sep: 53700 |
| vdacc: the reduction tree over the 8 lanes of a vdot | 3794 | 1500 | 2.53 **(>30%)** | vec2.v, vec3.v | ms8x8 - ms8x8_notree (the tree alone, dacc_tree: 3734) | vdaccb_sep: 37622; vdaccw_sep: 58245 |
| vsarr, vshrr (.w .l): the rounding added to the shifter | 2992 | 2000 to 3000 | 1.20 | vec2.v | shiftround_wl - shiftlane_wl | shiftround_wl: 11579 |
| vsad.bu: the tree if vacc.bu does not exist (the abdu comes from the lane ALU) | 2670 | 500 | 5.34 **(>30%)** | vec2.v | sum32_bu | vsad_bu: 7921 |
| vtbl.b (32 lanes, groups of 16) | 12736 | 10000 to 12000 | 1.16 | vec2.v | vtbl_g16 | vtbl_one: 12663 |
| vceq, vcgt, vcgtu (4 widths) and vbsl | 3801 | 2000 to 4000 | 1.27 | vec2.v | vcmp_mw + vbsl |  |
| vcvt.f.l and vcvt.l.f, 8 lanes each | 15847 | 3000 to 5000 | 3.96 **(>30%)** | fp2.v | cvt_both8 (cvt_i2f 1070, cvt_f2i 938 a lane) |  |
| the reductions: vacc (b bu w wu l lu q) and vmaxacc/vminacc (the same) | 20577 | 6000 | 3.43 **(>30%)** | blocks.v, vec2.v | vacc_naive + vmmacc (vacc_shared64: 11141, per type b 6938 w 5345 l 3773 q 2397; the survey counted one type, reduce16 2 x 2979) |  |
| the lane ALU, all widths (add, sub, saturating, min, max, abs, abd; avg excluded) | 18275 | 19000 to 22000 | 0.89 | vec2.v | lanealu_mw_noavg (the survey: lane ALU 7,000 + saturation/min/max 12,000 to 15,000) |  |
| the lane shifts (left, logical right, arithmetic right), all widths | 9430 | 3000 | 3.14 **(>30%)** | vec2.v | shiftlane_mw |  |
| vfir.w on the shared multipliers (window select, tap select, 16 x 32-bit accumulators, 112 halo flops) | 13058 | 3000 to 6000 | 2.90 **(>30%)** | vec3.v | vfir_added + 112 halo flops x 6 |  |
| segment loads and stores (2 to 4 fields; bytes, halfwords, words) | 23274 | 2000 to 5000 | 6.65 **(>30%)** | vec2.v | segload + segstore | segload 9856, segstore 13418 |
| the 256-bit load alignment with widening, and the store merge | 15065 | 10000 | 1.51 **(>30%)** | mem2.v | vmem_ld + vmem_st (without widening: vmem_ld_plain 6635) |  |
| vector register file, 16 x 256 bits, 3 read, 1 write, flip-flops | 61578 | 56800 | 1.08 | vec2.v | vregs16_r3 (survey: 8 registers 28,400 x 2) | latches: 47295; 2 read ports: 49262; 4: 74062 |
| vdot.b, .bu, .bsu: 8 lanes of 4 byte products (signed bytes: vdotb_s 37052) | 36200 | 37000 | 0.98 | vec2.v | vdotb_sep (9 x 9 multipliers with the sign flags) | vdotb_s (dot4 x 8): 37052 |
| the 16 x 16 integer multipliers (vmul with the full product) | 48225 | 48000 | 1.00 | vec2.v, vec3.v | vmul16_full (low half only, vmul16_lo: 19906) |  |
| 8 floating-point multiply-add lanes (single, fused, 74-bit frame) | 86650 | 79000 | 1.10 | fp2.v | fma32x8 (one fma32: 10693; two flat: 21523) |  |
| gather (vldx), one lane a cycle: address, counter, merge | 5001 | 4000 to 6000 | 1.00 | fp2.v | gather_full (a 32-lane parallel address generator alone: 12287) |  |
| the tile: 64 fused multiply-adds, 2,048 accumulator flops, row read and write | 705636 | 665000 | 1.06 | fp2.v | 64 x fma32 + tile_state (hierarchical count: 64 identical copies; the 20,000 of the survey for broadcast and write-back is in tile_state) |  |
| the whole-GEMM unit: the tile + the sequencer (7693) + a DMA engine (20,000, estimated) + 64 KB of SRAM at 6T (1.5 NAND2 eq a bit) to 2.0 with periphery | 1519761 | 1219000 to 1744000 | 1.03 | fp2.v | tile + gemm_seq + 20,000 + 524,288 bits x 1.5 .. 2.0; high: 1781905 |  |

**11 of the 24 rows are off by more than 30%, 8 of them by 2.5 times or more; every one of them is above the survey's estimate (the lowest ratio of all rows, 0.89, is the lane ALU).** The big blocks the survey scaled from synthesised ones are within 10% (16 x 16 multipliers 1.00, `vdot.b` 0.98, register file 1.08, floating-point lanes 1.10, tile 1.06, gather 1.00, GEMM unit 1.03). The misses are in the **small** blocks the survey estimated without a design: segment loads and stores (6.7 times: 23 k for the load and the store networks of 2 to 4 fields, bytes to words, with the four field registers and the beat positions; the model is mine and the figure depends on it, section 8), the sum of the **reductions** (3.4 times: the survey counted `reduce16` twice, one source type; the family has `b bu w wu l lu q` and the maximum and minimum), the vector **shifts** (3.1 times), `vfir` (2.9 times: the 32-bit accumulators and the 8-way window select), `vdacc`'s tree (2.5 times), the `vmulh` family (4.3 times: the high half needs the full 17 x 17 product, which the low half of `vmul` does not: `vmul16_lo` is 19,906, the full product 48,225), the rounding store (2.3 times), `vsad`'s tree (5.3 times) and the conversions (4.0 times). The survey's "a factor of 1.5 either way" **does not hold for the individual blocks and does for the total** (section 5).

## 4. Sharing, measured

The proposal says that one multiplier array serves `vmul`, `vmulh`, `vmulhr`, `vmla`, `vdot.w`, `vdot.b` and `vdacc`. Measured (all NAND2 equivalents):

| configuration | cost | module |
|---|---:|---|
| everything separate: `vmul` (full product) 48,225 + `vmulh` family 52,613 + `vmla` 22,506 + `vdot.w` 53,700 + `vdot.b` 36,200 + `vdacc` tree 3,734 | **216,978** | `vmul16_full`, `vmulh16_sep`, `vmla16_sep`, `vdotw_sep`, `vdotb_sep`, `dacc_tree` |
| A: one 16 x 16 array for `vmul`, `vmulh`, `vmulhu`, `vmulhr`, `vmla`, `vdot.w` (59,833), a separate `vdot.b` array (36,200), the `vdacc` tree (3,734) | **99,767** | `ms16_all`, `vdotb_sep`, `dacc_tree` |
| B: one array built of four 9 x 9 byte products a lane, with all of the above and `vdacc` | **85,516** | `ms8x8` (`ms8x8_notree` 81,722: the tree is 3,794) |

* **The sharing is real and large**: the separate forms are 2.5 times the shared one (B). The increments on the shared 16 x 16 array over the plain full-product `vmul` (48,225): `vmulh`/`vmulhu`/`vmulhr` +6,439, `vmla` -319 (noise: `vmla` is free on the array), `vdot.w` +5,488; total **+11,608** against the survey's 1,500 + 3,500 + small = about 5,000.
* **The survey's unclaimed saving (the `vdot.b` array on the 16 x 16 multipliers built as 8 x 8 products, 10,000 to 20,000, U) is confirmed: B is 14,251 (14%) below A.** B makes the whole array out of byte products; its increment over A's 16 x 16 array alone (`vdot.b`, `.bu`, `.bsu` and the `vdacc` tree included) is 25,683, against 39,934 for a separate `vdot.b` array and the tree.
* `vdacc` is **not** free on the `vdot` array, and not what the survey said (about 1,500): the tree over the 8 word lanes into a 64-bit scalar accumulate is **3,794**. Built alone, `vdacc.b` is 37,622 and `vdacc.w` 58,245 (no better than a `vdot` plus a reduction: the separate forms are as big as `vdot`).
* `vavg` on the lane adder with a carry in costs **1,507** (all widths), standalone 2,783. `vsarr`/`vshrr` (rounding on the shifter, `.w .l`) +2,992 (the survey: 2,000 to 3,000); on all four widths +2,152.
* `vsad.bu`: 32 absolute differences and the tree is 7,921 standalone. With the absolute differences taken from the lane ALU's `abdu` (it exists), what is added is the tree, which is the tree of `vacc.bu`: **2,670** if `vacc.bu` does not exist, **about 800 (estimated: 256 two-input selects) if it does**. The row in the totals uses 800.
* The reduction trees do not share by the "classes of byte position" method I tried (`vacc_shared64` 11,141); the best form is one tree per source type with a selector (`vacc_naive` **9,875**, per type: `b` 6,938, `w` 5,345, `l` 3,773, `q` 2,397). The accumulate width does not matter: summing in 32 bits (`vacc_shared32`) saves 2,361.
* The register file: 16 x 256 bits with 3 read ports and one write is **61,578** with flip-flops (37,002 of logic, 4,096 flip-flops), 47,295 with latches (29,345 logic, 261 flip-flops, 4,096 latches), 49,262 with two read ports and 74,062 with four. A custom multi-port array (not measured) would be smaller than either.
* `vfir` on the shared multipliers: the window select, tap select and the 16 accumulators of 32 bits are **13,058** (9,314 logic, 512 flip-flops, 112 halo flip-flops); the multipliers are the shared ones.
* The conversion unit, 8 lanes each way, would share a normaliser and an aligner with the floating-point lanes if they exist; **not measured** (an integer-only unit pays the whole 15,847).

## 5. Totals of the vector unit, the headline, and the ranking

The survey built 219,000 from: base 98,000 (hidden registers 28,400, lane ALU 7,000, multipliers 48,000, control 5,000, load/store 10,000), reductions 6,000, saturation and narrowing 13,500, shifts 3,000, `vfir` 4,500, `vdot.b` 37,000, segments 3,500, the second register file 28,000, and 25,500 of new words. The same blocks, measured (B, flip-flop registers):

| line | survey | measured | difference |
|---|---:|---:|---:|
| registers, 16 x 256 | 56,400 | 61,578 | +5,178 |
| lane ALU, all widths, with `vavg`, saturating forms, min, max, abs, abd | 22,000 | 19,782 | -2,218 |
| narrowing store with the rounding shift | 3,000 | 8,629 | +5,629 |
| shifts, all widths, with rounding | 5,500 | 11,582 | +6,082 |
| multiplier array with `vdot.w`, `vdot.b`, `vdacc`, `vmulh`, `vmla` (B) | 92,000 | 85,516 | -6,484 |
| `vsad` | 500 | 800 (est.) | +300 |
| reductions | 6,000 | 20,577 | +14,577 |
| `vfir` | 4,500 | 13,058 | +8,558 |
| segment loads and stores | 3,500 | 23,274 | +19,774 |
| `vtbl.b` | 11,000 | 12,736 | +1,736 |
| load alignment with widening, store merge | 10,000 | 15,065 | +5,065 |
| strip control (4 x `add64` + 2,000 estimated) | 5,000 | 4,640 | -360 |
| **wave 1, 16 integer lanes** | **219,400** | **277,237** | **+57,837** |

| the proposed vector unit | A: monolithic array + separate vdot.b array | B: one array of 8 x 8 products | B with latch registers |
|---|---:|---:|---:|
| wave 1, 16 integer lanes | 291488 | 277237 | 262954 |
| wave 1 and 2, 16 integer lanes | 311136 | 296885 | 282602 |
| wave 1 and 2 with 8 floating-point lanes | 397786 | 383535 | 369252 |

**The survey's 219,000 (298,000 with floating-point lanes) is too low by 20 to 33% (17 to 27% with floating point); the measured wave 1 is 263,000 to 291,000 NAND2 equivalents with 16 integer lanes, 350,000 to 378,000 with the 8 floating-point lanes** (the lower figure: B with latch registers; the upper: A with flip-flops), wave 2 (compare and select 3,801, conversions 15,847) adds 19,648. That is **inside the survey's own "factor of 1.5 either way" for the total**, though not for the parts (section 3). The floating-point lane unit is 86,650 (the survey 79,000; the fused unit here keeps the 74-bit frame, one fused multiply-add 10,693 against the survey's 9,888).

| the family as it stands | NAND2 eq |
|---|---:|
| vector unit, 16 integer lanes (ALU without avg, plain shifts, vmul + vdot.b arrays, plain narrow, reductions, vfir, segments, control, load/store, gather, 16 registers) | 257945 |
| + 8 floating-point lanes | 344595 |
| + the tile (alone) | 705636 |
| + the whole-GEMM unit (contains the tile): low to high | 1519761 to 1781905 |
| total, integer lanes, with the GEMM unit | 1777706 to 2039850 |
| total, floating-point lanes, with the GEMM unit | 1864356 to 2126500 |

**The headline reduction** (the survey: 1.4 to 2.0 million down to 0.22 to 0.30 million, about 6.5 times). Measured: the family as it stands is **1.78 to 2.04 million** with integer lanes (1.86 to 2.13 million with floating-point lanes), of which the vector unit without the tile and the GEMM unit is 258,000; the proposal (waves 1 and 2, B or A) is **0.28 to 0.31 million** (0.37 to 0.40 million with floating point). **The reduction is 1.5 to 1.7 million, 83 to 85%, about 5.7 to 7.2 times (central 6.4 times); the survey's reduction survives**, and nearly all of it is the removal of the tile (705,636: 64 fused multiply-adds 684,352, accumulators and row ports 21,284) and the GEMM unit (1,519,761 to 1,781,905, of which the 64 KB of buffer SRAM at 6T is 786,432 to 1,048,576). The new words add 19,000 to 53,000 (5,000 with latch registers) and the gather removal saves 5,001: the 219,000-against-258,000 comparison the survey made is, measured, **277,000 against 258,000 (wave 1, B) or 291,000 (A)**. **Without the SRAM of the GEMM unit** (logic only) the family as it stands is 0.99 million against 0.30, **3.3 times**.

**Ranking** (work saved per instruction and per code byte, divided by the measured silicon; "saved" is the survey's own count of instructions per use, section 5.1 and 5.3, E). Everything of wave 1 costs under 7,000 gates (2.5% of the unit) except `vtbl` and the conversions, so the ranking changes the order but removes nothing:

| survey rank | word | saved per use | measured (shared) | saved per 1,000 gates | rank now |
|---:|---|---:|---:|---:|---:|
| 9 | `vmla` vector by vector | 1 | about 0 (inside the noise) | very large | **1** |
| 1 | `vavg` | 2 | 1,507 | 1.33 | **2** |
| 7 | `vsad.bu` | 1 | about 800 on `vacc`'s tree, 2,670 if alone | 1.25 / 0.37 | **3** |
| 5 | `vsarr`, `vshrr` | 1 | 2,992 | 0.33 | **4** |
| 3 | `vmulh`, `vmulhu`, `vmulhr` | 2 | 6,439 | 0.31 | **5** |
| 2 | rounding shift in the narrowing store | 2 | 6,859 (w to b alone 4,900) | 0.29 (0.41) | **6** |
| 4 | `vdacc` | 1, and the strip stays 32 bytes (0.25 to 0.094 instructions a multiply-add) | 3,794 | 0.26 | **7 by this count; keep 4 for the strip-width effect** |
| 6 | `vdot.w` | 1 | 5,488 | 0.18 | **8** |
| 8 | `vtbl.b` | same count, 16 to 32 times faster than a gather lane a cycle | 12,736, **net 7,735 over the gather it replaces** | - | 9 |
| 10 | compare and select | enables vectorisation of masked loops | 3,801 | - | 10 |
| 11 | conversions | enables the LLM quantise loops | 15,847 | - | **11** |

**What changes.** (1) The rounding store falls from 2 to 6 and `vmulh` from 3 to 5: they cost 2.3 and 4.3 times the estimate; they stay in. (2) `vmla` v by v is free on the array and goes to the top. (3) `vsad` is cheap only if `vacc.bu` exists (the same tree); say so. (4) The conversions cost four times the estimate (15.8 k, 5.7% of the unit) and are the one word-pair whose silicon is not small; with the floating-point lanes the sharing is likely and unmeasured, without them they are the most expensive wave-2 item: **build them only with the floating-point lanes, or leave them to the second wave as the survey did, but do not call them 3,000 to 5,000**. (5) **The reductions, the segment loads and the shifts are where the estimate was most wrong and where the unit has most to save**: a `vmaxacc`/`vminacc` for every source type is 10,702 (the sum `vacc` for every type 9,875); if the maximum and minimum are cut to `b bu w wu` the saving is a share of that (not measured by type); the segment network (23,274 in my model) is the largest block outside the multipliers and the registers, and a restriction to 2 and 4 fields of bytes and halfwords would cut it (not measured); the rounding on the narrowing store for `w` to `b` only is 4,900 instead of 6,859. (6) The latch register file saves 14,283 (5%). (7) The 219,000 and 298,000 should be replaced by 277,000 (B) to 291,000 (A) and 364,000 to 378,000 in `vec-survey.md` 5.2 and 0. (8) **No recommendation of the survey fails**: the removal of the tile, the GEMM unit and the gather, and the wave-1 words, hold at the measured costs; the claim that fails is "219,000" and "a factor of 1.5 either way" as a claim about each block.

## 6. What the chip's transistor count needs besides the numbers of the survey

The scalar core of `core-total.py` (`vec-gates.md`): **219,324 to 307,618 NAND2 equivalents, flip-flops at 6**. What it includes, row by row: the register file of 32 x 64 bits with 3 read ports (synthesised: 19,893 + 2,048 flip-flops = 32,181), the integer ALU, shifter, bit words, the **multiplier** (8,000 iterative to 41,492) and the **divider** (iterative, 3,000), the **floating-point unit** (single, double, half: 51,000 to 59,000: 53 x 53 multiplier, aligners, adder, normaliser, divide and square root, estimated in part), the crypto words, the instruction decoder generated from the grammar (6,000), fetch, branch, load and store, **the two translation buffers (16 and 32 entries) with the page walker, as flip-flops and comparators (34,000 to 38,000)**, the system registers, the pipeline control, debug. **It excludes: all caches and their tags and decoders, any branch predictor or prefetcher, the memory and bus interface, write buffers, the interrupt controller beyond the vector fetch, the clock tree, test logic, the pads.** The vector unit above is **not** in it (the 16 x 256-bit registers are in the vector unit). The translation buffers as flip-flops are an upper bound on a CAM array; the register file as flip-flops is an upper bound on an SRAM-like array.

**Conversion to transistors.** Static CMOS, **NAND2 = 4 transistors, inverter 2, flip-flop (6 equivalents) 24, latch (4) 16** are the stated unit: transistors = NAND2 equivalents x 4. The range: **low 3.0 per equivalent** (the mapper's NAND/inverter netlist is larger than a netlist of complex gates, transmission-gate flip-flops of 18 to 20 transistors and optimised XORs and full adders; U), **high 5.2** (4.0 plus 30% for buffering, sizing, scan flip-flops and clock gating, within the 20 to 50% of `vec-gates.md`, U). The SRAM: **6 transistors a bit**; for the caches, 32 KB of instruction and 32 KB of data = 524,288 bits = 3,145,728 transistors; plus tags and state (about 6.3%: 512 lines of 64 bytes in each cache, a tag of 28 bits and 4 of state, 4 ways), plus the periphery (decoders, sense amplifiers, write drivers, comparators: 15% low, 25% middle, 35% high), plus parity or ECC (12.5%, high end only): **3.85 million to 5.08 million transistors, middle 4.18 million** (an illustrative configuration; the instruction cache and a data cache with the vector port are the owner's choices). The buffer SRAM of the GEMM unit is counted at 1.5 to 2.0 NAND2 equivalents a bit (6 to 8 transistors).

## 7. The total

NAND2 equivalents from the sums above (low: the scalar low, with the vector unit in its lowest form, B with latch registers; high: the scalar high, with A and flip-flop registers); transistors at 3.0, 4.0 and 5.2 per equivalent.

| case | NAND2 eq, low to high | transistors at 3.0 per eq (low end) | at 4.0 per eq (stated unit) | at 5.2 per eq (high end) |
|---|---:|---:|---:|---:|
| (a) the scalar core, logic only | 219324 to 307618 | 0.66 M to 0.92 M | 0.88 M to 1.23 M | 1.14 M to 1.60 M |
| (b) core + the proposed vector unit, 16 integer lanes (waves 1 and 2) | 501926 to 618754 | 1.51 M to 1.86 M | 2.01 M to 2.48 M | 2.61 M to 3.22 M |
| (c) core + the proposed vector unit with 8 floating-point lanes | 588576 to 705404 | 1.77 M to 2.12 M | 2.35 M to 2.82 M | 3.06 M to 3.67 M |
| (e) core + the family as it stands, integer lanes, with tile and GEMM unit | 1997030 to 2347468 | 5.99 M to 7.04 M | 7.99 M to 9.39 M | 10.38 M to 12.21 M |
| (e) core + the family as it stands, floating-point lanes, with tile and GEMM unit | 2083680 to 2434118 | 6.25 M to 7.30 M | 8.33 M to 9.74 M | 10.84 M to 12.66 M |

With the caches (32 KB + 32 KB, the SRAM range above, the middle at 4.0 per equivalent and 4.18 million for the caches):

| case with 32 KB + 32 KB of caches (3.85 M to 5.08 M transistors, middle 4.18 M) | transistors, low to high | SRAM share (middle) |
|---|---:|---:|
| (a) the scalar core, logic only | 4.50 M to 6.68 M (middle 5.23 M) | 80% |
| (b) core + the proposed vector unit, 16 integer lanes (waves 1 and 2) | 5.35 M to 8.30 M (middle 6.42 M) | 65% |
| (c) core + the proposed vector unit with 8 floating-point lanes | 5.61 M to 8.75 M (middle 6.77 M) | 62% |
| (e) core + the family as it stands, integer lanes, with tile and GEMM unit | 9.84 M to 17.29 M (middle 12.87 M) | 32% |
| (e) core + the family as it stands, floating-point lanes, with tile and GEMM unit | 10.10 M to 17.74 M (middle 13.22 M) | 32% |

**In words.** (a) The scalar core's logic alone: **0.9 to 1.2 million transistors** at the stated unit (0.66 to 1.60 million over the whole range). (b) With the proposed vector unit, 16 integer lanes: **2.0 to 2.5 million** (1.5 to 3.2). (c) With 8 floating-point lanes: **2.35 to 2.8 million** (1.8 to 3.7). (d) With 32 KB + 32 KB of caches: **5.3 to 8.3 million, middle 6.4 million** for (b), **5.6 to 8.8 million, middle 6.8 million** for (c); **the SRAM is 62 to 65% of the transistors** (80% of a scalar core with the same caches), so it dominates as soon as caches are counted, and the choice of cache size moves the total more than the choice of vector lanes. (e) **The family as it stands**, with the tile and the GEMM unit: **8.0 to 9.4 million** (6.0 to 12.2) without caches, **9.8 to 17.3 million, middle 12.9 million** with them: the proposal halves the chip with caches and cuts it to a quarter without. (The GEMM unit's 64 KB of buffers, 3.1 to 4.2 million transistors at 6 to 8 a bit, is inside the figure for (e) both with and without caches.)

**For scale** (U: published figures from memory, **not checked on this machine**; transistor counts of different eras count different things and include their caches): the Intel 4004 2,300; the 8086 29,000; the 80386 275,000; the 80486 1.2 million (with 8 KB of cache and a floating-point unit); the Pentium 3.1 million; the Apple M1 16 billion. The pdp64 scalar core with vector unit, without caches (2.0 to 2.5 million) is between the 486 and the Pentium in transistor count. I did not look up any figure for the cores of comparable ISAs.

## 8. What was verified, what was estimated, what was not

**Synthesised** (Verilog, yosys 0.52, the flow of section 1): everything in the table of section 3 except the lines named under "estimated"; the 33 baseline blocks (reproduced). **Behaviour checked against a Python model** (`check-vec2.py`, yosys `eval` on the flattened netlist, random inputs, results in `all 13 checks pass, 2026-11-18`): `vavg_mw`, `vacc_shared64`, `vacc_naive`, `lanealu_mw` (all 18 operations, random widths), `shiftround_mw`, `vtbl_g16`, `narrow_w2b`, `ms16_all` (6 modes), `ms8x8` (7 modes including `.b`, `.bu`, `.bsu`), `cvt_i2f`, `cvt_f2i`, `vmem_ld`, `fma32` (7 vectors), and one byte position of `segload`. **Not checked for behaviour:** `vmmacc`, `vcmp_mw`, `vbsl`, `segstore` and the other segment cases, `vfir_added`, the narrowing store for `l` to `w`, `vsad_bu`, `vdacc*`, `tile_state`, `gemm_seq`, `gather_*`, `vmem_st`, the `vregs16*` (the register files and the separate forms are plain Verilog); a block that does nothing would be counted as small, so these rows are the least certain.

**Estimated, not synthesised:** the strip control's 2,000 (`add64` x 4 is measured); `vsad`'s 800; the DMA engine of the GEMM unit (20,000; the sequencer is measured: 7,693); the multi-ported arrays, the caches, tags, periphery and every transistor conversion (section 6); the scalar core's own estimated rows (`core-total.py`); the survey's estimates compared against.

**Not verified or not done:** timing, area, wiring, power, clock distribution, test; the floating-point lanes' other operations (add, compare, min, max, absolute value use the fused unit or are not counted: the 86,650 is the multiply-add alone); infinity and NaN logic and the corner case of an addend more than 25 binades above the product in `fma32` (about 5% of its count); the straddling of the 3-field elements over the 32-byte beat in the segment network; `vmulh.l` (32-bit lanes, not in the proposal: one 32 x 32 multiplier is 11,694, so 8 lanes would be about 94,000 if built alone); the sharing of the conversions with the floating-point lanes; the Booth form of any multiplier; the savings of a restricted set of reductions or segments; the compiler or the instruction counts of the survey (taken as given); the frequencies in the survey.

## 9. Reproduce

From `tools/gates`: `./run-silicon.sh` (the baseline, the new blocks, the tables; writes `vec-silicon-blocks.tsv` and `core-silicon-blocks.tsv`); `python3 check-vec2.py` (the behaviour checks); `./gates2.sh FILE.v MODULE...` for single blocks; `python3 silicon-total.py vec-silicon-blocks.tsv core-silicon-blocks.tsv` for the tables. The baseline alone: `sh gates.sh yosys blocks.v`, `for f in core.v aes.v decode.v; do sh gates.sh yosys $f; done`.
