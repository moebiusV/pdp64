# The `vec` forms written by hand, and what they save on eight kernels

**Status (as of 2026-11-18, commit 044a7195): a study record of 2026-11-17 whose notation became the grammar; the measurements are current as measurements, the notation and the gather are not.** The block notation proposed here (`vec Rs,Re` ... `vend`, hidden vector registers, `vld`, `vst`, `vfir`, `vacc`) was implemented (errata 161) and revised (errata 170 to 175): the family is **363 words, 63 base mnemonics** in `spec/pdp64/pdp64.hbnf` (`vec-isa.md`, which is the semantics reference and has a table of every word). **Superseded:** (1) "nothing here is in the grammar or `as64`, the forms have not been assembled": they are in the grammar, `as64`, `sim64` and QEMU, and run (`tests/sim/vec-*.s`); the hand-written listings of `arch-data/vec-forms/` were partly updated (errata 170: `k_q8dot`, `k_q4dot`, `k_sad` use the fused forms) and the others are as written on 2026-11-17 and were not re-assembled for this note; (2) **the gather `vldx` and the scatter-add `vaddx`**: `vldx` was removed in wave 1 (errata 170; `vtbl.b` replaced its table-lookup use) and `vaddx` was never added, so the `k_hist` form (finding 4) used words that no longer exist and `k_hist.vec.s` was deleted (commit 9451eed3); (3) `vexp` is not in the family (open); (4) the hidden registers are `v0` to `v15` (this text says `v0` to `v7`), and the strip is invisible with a least value of 16 bytes (errata 173), so "a strip of 8 or 16 lanes" and "256 bits is the assumption of the column" are the study's assumption, not a property. **Still current:** the corpus, the eight kernels, the instruction counts of pcc's scalar code, the comparison with clang's code for six vector instruction sets and with hand-written x86, NEON and RVV assembly, and findings 1 to 3, 5 and 6.

**Related:** `vec-isa.md` (the family as implemented); `gemm-forms.md` (the sequel: BLAS calls; its tile and GEMM-unit forms are historical); `vector-study.md` (the dav1d measurement before this); `vec-cost-benefit.md` (the table of operations, with the outcome of each row); `vec-survey.md` (the review against other ISAs that pruned this family); `docs/errata.md` 139, 161, 170 to 175.

**Original status (2026-11-17):** a study record. The notation below is the assistant's **proposal** for the study; the author decided only that `vec` is a prefix over a region `[Rs, Re)` named by two registers, with progress in ordinary registers, hidden vector registers allowed, and the details to be determined (errata 139). Nothing here is a decision, nothing is in the grammar or `as64`, and the forms have **not been assembled or run**: there is no assembler or simulator for them. Instruction counts are counts of lines written by hand.

Data and scripts: `docs/encoding-work/arch-data/vec-forms/` (the forms `*.vec.s`, `kernels.c`, `pcc-scalar.s`, `vecbench.csv`, `handasm.tsv`, `vec-forms-summary.md`); `tools/arch-compare/vecbench.py`, `handasm.py`, `vecforms.py`.

## 1. What the vec corpus is

Asked by the author (2026-11-17): "so what is our vec corpus?" It was **dav1d only** (the AV1 decoder; `vector-study.md`). It is now five projects:

| project | what it exercises | what was done here |
|---|---|---|
| **dav1d** (6c7bee6) | pixel filters, transforms, prediction; hand-written x86, NEON, RISC-V vector | C kernels compiled for pdp64 and six vector instruction sets; hand assembly counted (NEON, RVV; **x86 now too**, NASM built) |
| **FFmpeg** (shallow clone, 2026-11-17) | audio and video DSP; hand-written assembly in x86 (SSE to AVX2), NEON, RISC-V vector | `vector_fmac_scalar` and `pixel_sad`: C compiled; the hand-written functions of x86, NEON and RVV counted |
| **LightGBM** (shallow clone) | gradient-boosted trees: histogram construction is a gather and a scatter-add | `ConstructHistogramInner` as C, compiled; vec form written |
| **mamba.c** (kroggen, 2026-11-09; its description says Mamba, Mamba2 and Mamba3) | the selective scan of a state-space model: elementwise, `exp`, a reduction per row | the fused scan of one row, as C, compiled; vec form written |
| **cngpt, cugpt** (the author's repositories moebiusV/cngpt and moebiusV/cugpt) | cngpt: 11 `sgemm` calls (the linear layers and attention), the part OpenBLAS writes by hand for each ISA; cugpt: BLAS levels 1 and 2 on vectors of 4 to 16 doubles | done in `gemm-forms.md` (an earlier version of this table said that cugpt called `sgemm` and `dgemm` at 27 sites: wrong, corrected there) |

Not done: scanning all of FFmpeg's and LightGBM's C with `vecwin.py` (a loop census like dav1d's); the hand-written LoongArch assembly (FFmpeg's LoongArch code is C with LSX/LASX intrinsics, not assembled here); POWER, s390x, MIPS MSA and Hexagon. **A correction to earlier records:** `vector-study.md` said NASM could not be built because it "was not allowed in this session". The author never refused it. The first build attempt was stopped by the automatic permission check of the assistant's tool, and the assistant did not retry it. NASM 2.16.03 built without trouble on 2026-11-17 and assembles dav1d's and FFmpeg's x86 sources (their configuration headers made by hand); the paragraphs of `vector-study.md` are corrected.

## 2. The notation (proposed; implemented since, with the changes of the status above)

The decision says one prefix instruction names a region and the next instruction runs over it. The kernels show that this is **not enough for six of eight**: pdp64 allows **at most one memory operand per instruction** (9.2), so `vec` over one instruction can express a fill (a register stored to the region) and a reduction (a memory element added to a register), and nothing with two streams or two operations. The forms below therefore use a **block**: `vec Rs,Re` ... `vend`. Hidden vector registers `v0`..`v7` [now: `v0` to `v15`] hold a *strip*, as many elements as the hardware takes at once; the block runs once per strip until the first stream reaches `Re`, so the program says nothing about the width (length-agnostic, as RISC-V vector is) and needs no remainder loop, no overlap test and no pointer bump.

| form | meaning |
|---|---|
| `vec Rs,Re` | the first stream is the region `[Rs, Re)`; run the block over it, a strip at a time |
| `vld.bu.w v0,(r1)+` | load a strip from memory into `v0`: element type `b`, `bu`, `w`, `wu`, `l`, `lu`, `q`, `f` or `d` (8, 16, 32, 64-bit integers, signed or zero-extended, and 32- and 64-bit floats; the suffixes of the scalar moves `movb`, `movw`, `movl`, `movq`; an earlier draft wrote `h` for `w`), then (optional) the lane type it is widened to; `(r1)+` moves `r1` past the strip; `d(r1)` reads at an offset and does not move it |
| `vst.w v0,(r0)+` | store a strip; `vsts.l.bu` narrows with saturation |
| `vadd`, `vsub`, `vmul`, `vmla` (`v += v*scalar`), `vfma`, `vshl`, `vsar`, `vor`, `vabd` | lane operations; the scalar operand is a general register |
| `vfir.l v1,v0,r10` | sliding window: `v1[i] = sum k=0..7 of r(10+k) * v0[i+k-3]`, the hardware keeping the elements of the previous strip that the window needs |
| `vacc.l r6,v1` | `r6 +=` the sum of the lanes of `v1`: a reduction into an ordinary register, kept up to date after each strip |
| `vldx.bu.l v1,(r0)[v0]`, `vaddx.d (r6)[v1*8],v2` | gather; scatter-add (lanes applied in order, so equal indices are right) **[now: `vldx` was removed in wave 1, errata 170 (the lookup use is `vtbl.b`); `vaddx` was never added]** |
| `vexp.f` | the exponential, lane by lane (not in the decided set) [now: still not in the family] |

A fault leaves the pointers at the first strip not done, as the block moves do; progress lives in the ordinary registers. Predication, shuffles and the instruction list are left as the decision left them.

Example, the 8-bit `prep` of dav1d (`tmp[x] = src[x] << 4`, one row):

```
k_prep8:
	lea	(r1)(r2),r3		; end of the source region
	vec	r1,r3
	vld.bu.w v0,(r1)+		; bytes, zero-extended to 16-bit lanes
	vshl.w	v0,#4
	vst.w	v0,(r0)+
	vend
	ret
```

pcc's scalar code for the same function is 8 instructions with a 5-instruction loop that runs once per element.

## 3. The kernels

| kernel | source | vec form (file) | needs |
|---|---|---|---|
| `k_prep8` | dav1d `prep_c`, 8 bit | `k_prep8.vec.s` | two streams, widening: the block |
| `k_put8h` | dav1d `put_8tap_c`, horizontal, 8 bit | `k_put8h.vec.s` (eight displaced loads), `k_put8h.vecfir.s` (sliding window) | the block; widening to 32-bit lanes; clamp on narrowing; form B needs `vfir` |
| `k_dctop_sum` | dav1d `dc_gen_top` | `k_dctop_sum.vec.s` | **the decided prefix alone**, with one new instruction (add of a zero-extended byte) |
| `k_dctop_fill` | dav1d `splat_dc` | `k_dctop_fill.vec.s` | **the decided prefix alone** (a store of a register to a region) |
| `k_fmac` | FFmpeg `vector_fmac_scalar_c` | `k_fmac.vec.s` | the block; a fused multiply-add |
| `k_sad` | FFmpeg `pixel_sad_c` | `k_sad.vec.s` | the block; absolute difference; a widening reduction |
| `k_hist` | LightGBM `ConstructHistogramInner` | `k_hist.vec.s` | the block; **gather and scatter-add** |
| `k_ssm` | mamba.c `forward_layer`, one row of the scan, fused | `k_ssm.vec.s` | the block; `exp`; a reduction; a fused multiply-add |

## 4. Measured

All counts are static instructions of what was written or compiled; "per element" divides a loop by the elements it does. The full tables are in `arch-data/vec-forms/vec-forms-summary.md`.

**pdp64, scalar (pcc) against the vec form** (instructions of the function; the inner loop of the scalar code runs once per element):

| kernel | pcc scalar: function | pcc scalar: loop per element | vec form: function | vec form: operations of the block per element at a 256-bit strip |
|---|---:|---:|---:|---:|
| prep8 | 8 | 5 | 7 | 0.19 |
| put8h | 51 | 48 | 31 (form A), 17 (form B) | 2.38 (A), 0.62 (B) |
| dctop_sum | 21 | 4 | 9 | 0.03 |
| dctop_fill | 11 | 3 | 9 | 0.03 |
| fmac | 10 | 7 | 8 | 0.50 |
| sad | 26 | 7 | 18 | 0.25 |
| hist | 26 | 24 | 11 | 2.00 |
| ssm | 33 | 19 (plus a call of `expf`) | 18 | 1.50 |
| **all eight** | **186** | | **111 (A), 97 (B)** | |

The vec forms are 40% (form A) to 48% (form B) fewer instructions than pcc's scalar functions. The row that matters is the last column: the scalar loop spends 3 to 48 instructions on each element and the block spends a fraction of one. (The block's operations are hardware strips of the width chosen; 256 bits is the assumption of the column, the program does not name it.)

**Against the other instruction sets** (clang, loop instructions per element; the whole-function size is in the summary file):

| kernel | AVX2 | AVX-512 | NEON | LASX | RVV (instructions per strip of VL elements) | pdp64 `vec` |
|---|---:|---:|---:|---:|---|---:|
| prep8 | 0.44 | 0.19 | 0.38 | 1.12 | 6 | 0.19 |
| put8h | 3.56 | 1.80 | 7.62 | 12.5 | 85 | 2.38 (A), 0.62 (B) |
| dctop_sum | 0.62 | 0.31 | 0.56 | 2.0 | 6 | 0.03 |
| fmac | 0.75 | 0.38 | 1.50 | 1.0 | 7 | 0.50 |
| sad | 1.38 | 0.69 | 0.75 | 2.5 | 12 | 0.25 |
| dctop_fill | not vectorized by any (a scalar loop of 1 to 8 instructions per element) | | | | | 0.03 |
| hist | **not vectorized by any** (14 to 19 scalar instructions per element) | | | | | 2.00 |
| ssm | 6.8 | 6.1 | not measured | 11.1 | not measured | 1.50 |

For the `ssm` row clang's vector loops call `expf` once per lane (no vector math library), so they are not real vector code; the NEON and RVV loops were not found by the script (they contain calls). Clang with `-march=armv9-a+sve2` chose fixed-width loops of the NEON size, not scalable ones (the SVE rows of the summary file equal the NEON rows); only RISC-V vector came out scalable. All six compiled versions are bigger than their scalar builds: 3 to 5 times for the filters (`put8h` 264 instructions on AVX2 against 55 scalar), because of the overlap tests and remainder loops.

**Hand-written assembly** (instructions, bytes; whole functions):

| function | x86 | NEON | RVV | pdp64 vec form (instructions) |
|---|---|---|---|---:|
| `vector_fmac_scalar` (FFmpeg) | SSE 22 (96 B), AVX 14 (64 B), FMA3 15 (80 B) | 16 (56 B) | 12 (44 B) | 8 |
| pixel SAD (FFmpeg) | 16x16 SSE2 81 (336 B); 32x32 AVX2 27 (129 B) | `sad16` 28 (100 B), `sad32` 37 (148 B) | none | 18 (any w, h) |
| `ipred_dc_top` 8 bit (dav1d) | AVX2 16 (64 B), AVX-512 16 (80 B), SSSE3 15 (64 B): **the entry only, the code per width is shared and not counted** | 77 (308 B) | 9 (20 B) | 9 (the sum) + 9 (the fill) |

## 5. Findings (the assistant's analysis, not decisions)

1. **The single-instruction prefix of errata 139 covers 2 of the 8 kernels** (the sum and the fill of the DC predictor), as the loop census had said (21% of map loops). Every kernel that reads two streams, or does two operations, needs the **block form with hidden registers** (J.8.5, the remedy that the decision allows). The restriction to one memory operand per instruction is the reason, and it is a good reason to keep.
2. **A block form is not larger than the RISC-V vector code and is smaller than everything else.** The fmac is 8 instructions against RVV's 12, AVX's 14, NEON's 16; the SAD for any size is 18, against 28 for NEON's 16-wide function and 81 for SSE2's unrolled 16x16. The saving is that the program carries no pointer bump, no remainder loop and no width.
3. **The gain is in the filter, and it needs the window.** Form A of the 8-tap filter (eight displaced loads) is 31 instructions with 19 in the block, 2.4 block operations per element, no better than AVX2's compiled 3.6 and worse than AVX-512's 1.8. Form B, with a **sliding-window multiply-accumulate**, is 17 instructions and 0.62 per element: the best figure of any column. This agrees with the earlier finding that the part of "GEMM" a codec uses is a sliding window.
4. **[now: the gather was removed, errata 170; the finding is the record of why it was added] Gather and scatter-add are what nothing vectorizes and `vec` can state.** Clang left the LightGBM histogram scalar on all six targets (14 to 19 instructions per element); the vec form is 11 instructions with 2 block operations per element. Whether the hardware is any faster depends on bin conflicts: equal bins inside a strip must be applied in order, and a 256-bin histogram of a skewed feature conflicts often. This one kernel decides whether the scatter-add belongs in the first version; the data here only shows the program size.
5. **`exp` is the price of the state-space scan.** The mamba row is 18 instructions and 1.5 block operations per element *if* the vector unit has `vexp`; without it the scan is a call per strip or per element, which is what the scalar code does.
6. **Not shown:** time. A block operation is not an instruction time; a strip of 8 or 16 lanes takes cycles that depend on the datapath and the memory. The comparison is of instructions the program writes and issues, which is what this machine's fetch and decode pay; the measurement of speed needs the simulator the project does not have for `vec`. [now: `sim64 -V` counts vector instructions executed and has two cycle models, `vec-strip.md` and `vec-latency.md`; they are models, not hardware.] Byte counts of the vec forms are not given: the encodings are left to the prefix-code optimiser (errata 139).

## 6. What was not checked

[now: the family was implemented and tested, `vec-isa.md`; what follows is what was true on 2026-11-17.] The forms are unassembled and their semantics informal; each could hide an error that an assembler or a simulator would find (the sliding window's treatment of the first and last strip, the saturating narrow, the order of scatter-add lanes). The compiled numbers are of one compiler (clang 21) at -O3 and -Ofast; the main-loop finder is a heuristic (a loop is a backward branch) and failed on the loops that contain calls. The hand-written x86 functions were assembled with a configuration written by hand for this study. No dynamic count was made (instructions executed, bytes fetched).

## 7. Reproduce

    python3 tools/arch-compare/vecbench.py docs/encoding-work/arch-data/vec-forms/kernels.c OUTDIR      # clang, six targets
    python3 tools/arch-compare/handasm.py 'x86=OBJ.o:REGEX' 'a64=OBJ.o:REGEX' ...                        # hand-written assembly
    python3 tools/arch-compare/vecforms.py docs/encoding-work/arch-data/vec-forms                        # the tables
