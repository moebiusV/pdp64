# Vector, SIMD and matrix instructions in existing ISAs and in real code, and a revised vec family

**Status (as of 2026-11-18, commit 044a7195): a survey and a proposal that the owner accepted and that is implemented; kept as the record of the evidence and the reasoning.** The owner read it and said "i accept all your recommendations and leanings" (2026-11-17/18, R474, errata 170). **Wave 1 (18 words added, 55 removed) and wave 2 (compare, select, convert: 16 words) are in the grammar, `as64`, `sim64` and the tests (errata 170, 171); the removals are done** (the whole-GEMM unit `gemm.f`, the tile `vtclr vtfmopa vtld vtst vtadd`, the gather `vldx`, the 23 lane variants). **Superseded by what followed:** (1) the word counts below are the survey's own counts of a grammar that had 384 words, not 372 (errata 170: it "counted 12 fewer words than the grammar had"), so its 372 -> 335 -> 349 are, as implemented, **384 -> 347 -> 363** (wave 2 has 16 words, not 14: the unsigned conversions were added); the grammar now has **363 words and 63 base mnemonics** (`vec-isa.md`, counted by `tools/vec-glance.py`); (2) `vlen.b`, which wave 1 kept, and the register form of `vtbl.b` (the survey's "group of 16 lanes") are **removed** (errata 173: the strip is invisible); (3) the silicon figures of 5.2 are estimates; yosys measured them (`vec-silicon.md` section 5: the survey's 219,000 for wave 1 is too low by 20 to 33%, 17 to 27% with floating-point lanes; the headline saving, 83 to 85%, held); (4) the open questions of section 7 are answered: the floating-point sum has a canonical order of 16-byte chunks (errata 174), the accumulators are kept (errata 172, 175), the second wave was taken, early-exit loops remain uncovered; (5) the "float to int32 with round to nearest even" of item 11 became truncation with saturation, as the scalar `FCVTSL` (errata 171). **Still current:** the survey of other ISAs, the frequency evidence (sections 1 to 4) and the reasoning for each word. Where the text below says "proposed", "will", "not in the grammar" the proposal is now implemented unless a bracketed `[now: ...]` says otherwise. The semantics of the words are `vec-isa.md` sections 6 to 8.

**Related:** `vec-isa.md` (the semantics reference and the table of every word); `vec-silicon.md` (the measurement of this proposal's silicon); `vec-gates.md` (the first gate estimates this one scaled from); `vec-strip.md`, `vec-latency.md` (the strip width and the cycle models, after this survey); `vec-cost-benefit.md` (the table of 2026-11-17 that preceded it); `docs/errata.md` 161, 170, 171, 173-175; `docs/decision-register.md` R450-R482; `llvm/vector-usage.md` (what the compiler selects).

**Original status (2026-11-17): a survey and a proposal, for the owner to read before anything is implemented.** The owner asked (errata 161; "you're supposed to base your vector/gemm/simd decisions on looking at existing cpu arch and coming up with something better; either fusing operations, or choosing the low hanging fruit while getting rid of the stuff that is never used much") for the family of `vec-isa.md`, `gemm-forms.md` and the grammar to be judged against what other architectures have and what real code uses. [now: wave 1 and wave 2 are in the grammar, `as64`, `sim64` and the LLVM tables; see the status above.] When this was written nothing here was in the grammar, the assembler, the simulator or the compiler, and `vec-isa.md` and the grammar were not edited. The criteria are the owner's: the most work for the fewest instructions and the least code, reasonable performance for a small silicon footprint, and, above both, restartability, precise exceptions and security (hidden vector state is not saved at a context switch, R435).

Evidence grades, as in `vec-cost-benefit.md`: **M** measured here (a count or an experiment run on this machine, with the method named); **E** estimated from measured numbers with the assumption stated; **U** general knowledge or memory, not checked on this machine. Two grades are added: **A** an instruction that the assembler of clang 19.1.7 accepted for the named target and extension (proof that the mnemonic and operand form exist in LLVM's tables; it is not the manual and says nothing of semantics), and **D** read in a document fetched during the work (named). **The official manuals were not read** (Intel SDM and intrinsics guide, Arm ARM and the A64 XML, RISC-V V specification, LoongArch manual, Power ISA, MSA, HVX, z/Architecture): section 1 says why and what stood in for them. Every claim below is marked with one of these grades or sits in a table whose caption says which.

## 0. Summary

1. **What real code uses most, after loads, stores, moves and adds:** shuffles and interleaves (x86 15.6% of the vector instructions of dav1d, FFmpeg and libjpeg-turbo assembly; 3 to 11% elsewhere), the fused widening and narrowing family (NEON: widening multiply-accumulate 5.3%, shift-round-narrow 4.8%, widening add 3.2%; RVV: shift-narrow 7.7%, widening add 6.3%, widening multiply-accumulate 3.7%; LoongArch: shift-narrow 5.8%, widening add 7.8%), the x86 pairwise multiply-adds (`pmaddwd`, `pmaddubsw` 4.4%; 15.9% in llama.cpp's AVX2 kernels), the Q15 rounding multiply (`pmulhrsw` 2.8% on x86, 3.4% in dav1d), saturating add and narrow (2 to 5%), and table lookup (`pshufb`, `tbl`, `vrgather`, `vshuf`: 1 to 5%) (M, section 3.2).
2. **What our family has against that list.** It fuses the widening into the load and the narrowing into the store, which is the part of that family that is most of its instruction count, and has the reductions into a scalar register, the saturating forms, `vabd`, the segment loads, and `vfir`. It lacks: the rounding average, the high-half and Q15 rounding multiply, the rounding shift and the shift-round-narrow-saturate-store, the 16-bit pairwise dot (`pmaddwd`), table lookup, and a general compare-and-select. It has no int/float conversion. It has 7 base instructions (32 of its 372 words) that nothing measured uses and that cost the most silicon and state: `gemm.f`, the five tile instructions, and the gather (section 4.3).
3. **Proposal in one line:** remove the whole-GEMM unit, the tile, the gather, and 23 words of lane variants and spellings that nothing uses; add 10 base instructions (18 words) of fused forms that reuse existing datapaths, plus 14 words in a second wave; **words 372 to 335 (349 with the second wave) [now: as implemented 384 to 347 to 363, errata 170 and 171], estimated silicon 1.4 to 2.0 million NAND2 equivalents (E) to 0.22 to 0.30 million**, and no hidden state that survives a strip except the accumulators of `vclr`/`vfmab`, which the owner may also drop (section 5).
4. **The one structural finding:** with a strip whose width is set by the widest lane of the block (errata 168, `sim64`), every widening that is not fused halves or quarters the elements for each instruction. Fusing the widening with the reduction (`vacc`, now `vdacc` for the dot product, `vsad` for the absolute difference) keeps the strip at 32 bytes. For the compiled `k_q8dot` that is 513 instructions executed for 1,000 elements today (M, `llvm/bench/results.csv`) against about 110 with a dot-reduce on byte lanes (E).
5. **Arm's newest model** (SME2 with ZA and ZT0, multi-vector operands, predicate-as-counter, LUTI, FP8, SMMLA) is mostly the cost of architectural vector state and of a fixed-size register file; the pieces worth copying are LUTI-style table lookup and the in-vector matrix multiply, and both are small (section 2.3). The tile and the multi-vector operands are not needed by a machine whose strip is chosen by the hardware and whose state is hidden.
6. **Where the evidence is weak:** the frequency counts are of source text (macros counted once), so they tell what programmers write, not what runs; no dynamic counts were made; the silicon figures are scaled from the synthesised blocks of `vec-gates.md` (yosys is not on this machine); the clang used (19.1.7) is older than the repository's LLVM 21 and had no dot-product auto-vectorization. Section 7 lists what is decided by evidence and what is judgement.

## 1. What was read, counted, and not done

| source | what | how | grade |
|---|---|---|---|
| Intel SDM and intrinsics guide, Arm ARM, RISC-V V spec, LoongArch manual, Power ISA, MSA, HVX, z/Architecture | **not read.** developer.arm.com pages were fetched and came back empty or as a redirect (they are rendered by script); the others were not tried because the assembler check below answers "does this mnemonic exist" and the semantics of the fused operations are well known | - | - |
| clang 19.1.7 (Debian) assembler, `--target` x86_64, aarch64, riscv64, loongarch64, powerpc64le, mips64el, s390x, hexagon | for every instruction named in the table of section 2.1, one line of assembly was assembled with the extension that should carry it (`asmchk`, 20 to 34 lines for each ISA; `-mavx512vnni -mavx512vbmi -mamx-int8`, `-march=armv9-a+sme2`, `+sve2p1`, `+lut`, `+sme-f8f16`, `rv64gcv_zvfbfwma_zvbb`, `-mcpu=power10`, `-mmsa`, `-mhvx`, `-march=z15`) | run here | **A** |
| Linux kernel documentation `docs.kernel.org/arch/arm64/sve.html` and `sme.html` | what is saved at a syscall and a signal, what clears ZA | fetched 2026-11-17 | **D** |
| Arm C Language Extensions, `ARM-software/acle` `main/acle.md` (release 2026Q1, 15 May 2026) | the feature macros: SVE2, SVE2.1, SVE2.2, SVE2.3; SME, SME2, SME2.1, SME2.2, SME2.3; the streaming and ZA state attributes | first 100,000 of 745,271 characters read (the rest not) | **D** |
| source of dav1d (6c7bee6, 2026-11-16), FFmpeg (6f98930, 2026-11-13), llama.cpp (401563f, 2026-11-17), OpenBLAS (dbf2c24, 2026-11-17), libjpeg-turbo (ab2cb1a, 2026-11-16), libyuv (6c353fe via the lemenkov mirror, 2026-11-16), zlib-ng (a046705, 2026-11-13) | hand-written vector assembly and intrinsics counted by mnemonic | `git clone --depth 1` into the scratchpad from github.com (one clone every 20 seconds; nothing from the sources was run; the scripts read text only) | **M** |
| 20 small C kernels compiled by clang 19 for 13 vector targets | which fused instructions an auto-vectorizer picks | `tools/arch-compare/vsurvey-kernels.sh` | **M** |
| everything about hardware cost | scaled from `vec-gates.md` (synthesised blocks) | yosys is not installed; no new block was synthesised | **E** |
| everything about instructions of the Arm and RISC-V extensions newer than clang 19 (Zvqdotq, Zvabd, Zvzip, SME2.2 MOP4, SVE2.2) | memory only; clang 19 rejects the names | - | **U** |

Method of the counts (`tools/arch-compare/vsurvey-freq.py`, `-class.py`, `-report.py`, `-top.py`, `-memop.py`, `-kmn.py`): for assembly (`.S`, `.asm`) the first word of each line after comments and labels, so a macro is counted where it is written and not once for each expansion; for C with intrinsics every call of a name of the family (`_mm*`, `v*q_*`, `sv*`, `__riscv_v*`, `__lsx_*`, `__lasx_*`, `__msa_*`, `vec_*`), the type suffix cut; inline assembly in quoted lines where the project uses it (OpenBLAS Haswell kernels, libyuv `row_gcc.cc`, `row_neon64.cc`, `row_rvv.cc`). NEON assembly lines are split into vector and scalar by whether an operand is a `v`, `z`, `q` or `p` register (a heuristic); scalar lines are dropped. Words are sorted into 34 operation classes by hand-written rules (`vsurvey-class.py`); the share of words the rules did not classify (macros, project helpers) is under 10% for every column of section 3.2 except NEON OpenBLAS assembly (16.6%, not used in the tables). 495,805 tokens in 7,348 distinct (ISA, project, kind, word) rows. **Limits:** source counts are not execution counts; `mova` on x86 is both a load, a store and a register move (x86inc), so the class "load, store, move" is not comparable across ISAs; the corpus is codec, image, linear-algebra and LLM code, not games or crypto.

## 2. Survey

### 2.1 Operation classes against ISAs

Legend: **1** one instruction; **2** two or more (the usual sequence named); **-** absent; **m** from memory and not assembled; a name in a cell was assembled (grade A) unless marked **m**. Columns: x86 = SSE2 to SSE4 and AVX2; x512 = AVX-512 with VNNI, VBMI, BITALG, and AMX; NEON includes dotprod, i8mm, bf16; SVE2 includes 2.1; SME = SME and SME2; RVV 1.0 with Zvbb, Zvfbfwma; POWER = VSX, Power10 MMA; HVX = Hexagon v68. The last column is the family as it is now (`vec-isa.md`, the grammar).

| # | operation class | x86 | x512 | NEON | SVE2 | SME2 | RVV | LSX/LASX | POWER | MSA | HVX | s390x | pdp64 now |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | floating fused multiply-add | 1 vfmadd | 1 | 1 fmla | 1 fmla | 1 fmla (into ZA) | 1 vfmacc | 1 vfmadd | 1 xvmaddasp | 1 fmadd.w | 1 m | 1 vfmasb | 1 vfma |
| 2 | integer multiply-accumulate, same width | 2 pmullw+paddw | 2 | 1 mla | 1 mla | - | 1 vmacc | 1 vmadd | 1 vmladduhm | 1 maddv | 1 m | 1 vmalf | 2 (vmla takes a scalar only) |
| 3 | widening multiply | 2 (pmullw+pmulhw, unpack) | 2 | 1 smull | 1 smullb | - | 1 vwmul | 2 vmulwev+od | 2 vmuleub+oub | 2 dotp | 1 m | 2 vmleb+lob | 1 (widening load, vmul) |
| 4 | widening multiply-accumulate | - | - | 1 smlal | 1 smlalb | 1 smlall (4-way, into ZA) | 1 vwmacc | 2 vmaddwev+od | 1 vmsumubm (4-way) | 1 dpadd_s | 1 m | 1-2 vmalheb | 2 |
| 5 | pairwise multiply-add (`pmaddwd`) | 1 pmaddwd, pmaddubsw | 1 | - (2) | - | - | - | 2 | 1 vmsumshm | 1 dotp_s | 1 vdmpy | 1 | - |
| 6 | int8 dot product into 32-bit lanes | 3 (pmaddubsw, pmaddwd, paddd); 1 vpdpbusd with AVX-VNNI | 1 vpdpbusd | 1 sdot, udot, usdot | 1 sdot | 1 sdot (multi-vector, into ZA) | 3; Zvqdotq m | 2 (there is no `vdp2`: dav1d's `vdp2` is a macro) | 1 vmsumubm; MMA xvi8ger4pp | 2 | 1 vrmpy | 2 | 1 vdot (lane form) |
| 7 | multiply high, Q15 rounding | 1 pmulhrsw, pmulhw | 1 | 1 sqrdmulh | 1 sqrdmulh | 1 m | 1 vsmul, vmulh | 1 vmuh (no rounding) | 1 vmhraddshs | 1 mulr_q | 1 vmpy:<<1:rnd:sat | 1 vmahb (no rounding) | 3 (widen, vmul, vsar) |
| 8 | sum of absolute differences | 1 psadbw | 1 | 2 uabal+uaddlv | 2 uaba+uaddv | - | 3+ (vminu, vmaxu, vsub, widen, vredsum); Zvabd m | 2 vabsd+vhaddw | 2 vabsdub+vsum4ubs | 2 | 1 vrsadub m | 2 | 2 (vabdu, vacc) |
| 9 | absolute difference | 3 (pminub, pmaxub, psubb) | 3 | 1 uabd | 1 uabd | - | 3 | 1 vabsd | 1 vabsdub | 1 asub_u | 1 vabsdiff | 3 | 1 vabd |
| 10 | rounding average | 1 pavgb, pavgw | 1 | 1 urhadd | 1 urhadd | - | 1 vaaddu | 1 vavgr | 1 vavgub | 1 aver_u | 1 vavg:rnd | 1 vavgl | 3 |
| 11 | saturating add, subtract | 1 | 1 | 1 sqadd, uqadd | 1 | - | 1 vsadd | 1 vsadd | 1 vaddubs | 1 adds_u | 1 | - m | 1 vadds |
| 12 | saturating narrow, signed to unsigned | 1 packuswb | 1 vpmovuswb | 1 sqxtun | 1 sqxtnb | 1 m | 1 vnclipu (shift 0) | 1 vssrani (shift 0) | 1 vpkshus | 2 sat_s+pckev | 1 vsat+vpack | 1 vpkls m | 1 vsts (at the store only) |
| 13 | shift right, round, saturate, narrow | 2-3 (no rounding) | 2-3 | 1 rshrn, sqrshrun | 1 sqrshrnb | 1 sqrshr (multi) | 1 vnclip(u).wi | 1 vssrarni | 2 | 2 | 1 vasr:rnd:sat | - | 3 |
| 14 | rounding shift right | 2 | 2 | 1 srshr, urshr | 1 | - | 1 vssra | 1 vsrari | 2 | 1 srari | 1 | 2 | 2 |
| 15 | reduce lanes to a scalar | 3+ | 3+ | 1 addv, uaddlv, smaxv | 1 uaddv | - | 2 vredsum+vmv.x.s | 3+ | 3+ | 3+ | 3+ | 2 vsumqf+extract | 1 vacc, vmaxacc |
| 16 | pairwise add of neighbours | 1 phaddw | 1 | 1 addp, uaddlp | 1 | - | 2 | 1 vhaddw | - | 1 hadd_s | 1 vdmpy | 1 vsumb | - |
| 17 | variable table lookup, byte permute | 1 pshufb | 1 vpermb, vpermt2b | 1 tbl, tbx | 1 tbl | 1 luti2/luti4 (ZT0) | 1 vrgather | 1 vshuf.b | 1 vperm | 1 vshf.b | 1 vlut16/32 | 1 vperm | 1 vldx (gather, a lane a cycle) |
| 18 | fixed shuffle, interleave, unpack | 1 punpck*, pshufd | 1 | 1 zip, uzp, trn, ext | 1 | 1 zip/uzp (multi) | 2 (slides; Zvzip m) | 1 vilvl | 1 vmrghb | 1 ilvr | 1 vshuff | 1 vmrhb | memory path only (vlseg, vsseg) |
| 19 | compare and select | 2 | 2 | 2 cm+bsl | 2 | - | 2 vms+vmerge | 2 | 2 | 2 | 2 vcmp+vmux | 2 | - (min, max, abd cover clamps) |
| 20 | mask or predicate registers | - | 1 k0-k7 | - | 1 P0-P15, PN | 1 | 1 v0.t | - | - | - | 1 Q | - | - |
| 21 | widening load | 1 pmovzx from memory | 1 | 2 | 1 (ld1b into .h) | 1 | 2 | 2 | 2 | 2 | 2 | 2 | 1 vld.bu.w |
| 22 | segment (interleaved) load, store | - | - | 1 ld2, ld3, ld4 | 1 | - | 1 vlseg2..8 | - | - | - | - | - | 1 vlseg, vsseg |
| 23 | gather, scatter | 1 gather (AVX2), no scatter | 1 gather, scatter | - | 1 | - | 1 vluxei, vsuxei | - | - | - | 1 vgather m | 1 vgef | 1 vldx (no scatter) |
| 24 | population count | - (pshufb sequence) | 1 vpopcnt | 1 cnt | 1 | - | 1 vcpop.v (Zvbb) | 1 vpcnt | 1 vpopcntb | 1 pcnt | - m | 1 vpopct | - |
| 25 | int and float conversion | 1 cvtdq2ps | 1 | 1 scvtf | 1 | 1 m | 1 vfcvt | 1 vffint | 1 xvcvsxwsp | 1 ffint_s | 1 m | 1 vcdgb | - |
| 26 | min, max | 1 | 1 | 1 | 1 | 1 (multi) | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| 27 | matrix in a vector or a tile | - | AMX 1 tdpbssd (8 tiles of 1 KiB) | 1 smmla, ummla, usmmla (2x8 by 8x2) | 1 smmla | 1 fmopa, smopa, umopa, bfmopa (ZA) | - (IME not in clang 19) | - | 1 xvf32gerpp, xvi8ger4pp (8 accumulators of 512 bits) | - | - | - | 1 vtfmopa (hidden tile); gemm.f |
| 28 | hardware strip-mining, no width in the program | - | - | - | yes (VL) | yes (SVL) | yes (vsetvli) | - | - | - | - | - | yes (the block) |

Assembled but only partly checked: Hexagon `vshuff` and `vdeal` did not assemble in the spelling tried (the rest of 18 lines did); LoongArch `vdp2.h.bu.b` and `vdp2add` did not assemble because they are not instructions (they are macros of dav1d's `loongson_asm.S`); s390x `vpkls` needed another operand count; clang 19 does not know `zvqdotq`, `zvabd`, `zvzip`, `sme-mop4`. The cells for those are **U**.

What the table shows (M for the cells marked A, U otherwise):

* **Every ISA with a fused form for the codec classes has it as one instruction, and the groups differ in which fusions they chose.** x86 fused the pairwise multiply-add and the Q15 rounding multiply (it has no widening multiply-accumulate and no rounding shift); Arm fused the widening, the rounding shift, and the narrow; RVV took the widening and the fixed-point forms (`vnclip` and `vssra` take the rounding mode from a control register); LoongArch has the Arm set with a different even/odd spelling.
* **The only instruction nobody has in two ISAs for the same thing is the dot product**: 4-way for int8 (x86 VNNI, Arm SDOT, POWER `vmsumubm`, HVX `vrmpy`), and none in the 128/256-bit LoongArch and MSA sets.
* **Arm has two in-vector matrix operations without a tile**: SDOT/UDOT/USDOT (1 by 4 products in each 32-bit lane) and SMMLA/UMMLA/USMMLA (a 2x8 by 8x2 integer matrix multiply into a 2x2 block of 32-bit lanes of each 128-bit segment, 32 multiply-adds an instruction, against 16 for SDOT; BFMMLA for bf16). Both assembled (A).
* **Our family has the load-time widening and the narrowing store, which most ISAs spend two instructions on** (rows 21 and 12), and lacks the middle of the codec classes: 7, 10, 13, 14, 5, and 17 in registers.

### 2.2 What the table says for compilers

The compiler path of each class is in section 3.4 (what clang 19 emitted for 20 small loops) and in the proposal table of section 5.

### 2.3 The AArch64 vector model on its own

**What was read.** The ACLE of 2026Q1 lists feature macros for SVE2, SVE2.1, SVE2.2, SVE2.3, SME, SME2, SME2.1, SME2.2, SME2.3 (D) and the state attributes `__arm_streaming`, `__arm_streaming_compatible`, `__arm_locally_streaming`, `__arm_in/out/inout/preserves`, `__arm_new` (D). The kernel documents give the operating-system side (D). The architecture text itself (Arm ARM, A64 XML, SME2 programmer's guide) **was not read**: the pages did not load. The instruction forms below were assembled with clang 19.1.7 (A); features that need a newer LLVM (SME2.2, SME-MOP4, SVE2.2) are U. So this section is an informed reading of the mnemonics, the kernel and ACLE documents, and memory, and says so where it is memory.

| feature | what it is for | state and silicon (as far as known) | emitted by compilers? |
|---|---|---|---|
| **SVE, SVE2** (Z0-Z31, P0-P15, FFR) | vector-length-agnostic code: the program asks for the elements left with a predicate and the loop is driven by `WHILELO`/`WHILELT` which make the predicate for the last, partial strip (A) | architectural: Z registers (128 to 2048 bits), 16 predicates, FFR; the kernel zeroes everything above bit 127 of Z and all P and FFR at each syscall (D, sve.html section 3) | LLVM and GCC auto-vectorize to SVE (U). In my test clang 19 with `-march=armv9-a+sve2` emitted `ptrue`, `rdvl`, `incw` counted loops and **no `whilelo`** (M, `kern/sve2.s`): tail folding is off by default for generic tuning |
| **SVE2.1, predicate-as-counter (PN8-PN15)** | one predicate register that describes a run of active elements for the multi-vector loads and stores (`ld1w {z0.s-z3.s}, pn8/z`, `whilelo pn8.b, x0, x1, vlx2`) (A) | no new vector state; a compact counter form | intrinsics (ACLE `svcount_t`) (U) |
| **first-fault and non-fault loads (LDFF1, LDNF1, FFR)** | SVE's answer to speculative strip-mining: a load that does not trap on the second and later elements, writing the elements loaded into FFR so that the loop can stop at the first fault (A: assembled `ldff1b`, `ldnf1b`, `rdffr`, `setffr`) | FFR is architectural state; first-fault loads exist so that `strlen`, `memchr` and search loops can run a strip beyond the end without a fault (U) | none of the seven projects' sources contains `ldff1` or `ldnf1` (M: grep over the clones); libc string routines are the users (U, not measured) |
| **SME streaming mode** (PSTATE.SM, SVL) | a second vector length, the streaming vector length, for a matrix coprocessor-like mode; many SVE instructions are illegal in streaming mode and a few are legal only there (U) | PSTATE.SM, PSTATE.ZA; the syscall clears SM and preserves ZA (D, sme.html section 3); a prctl vector-length change clears ZA (D, section 6) | ACLE function attributes `__arm_streaming`; compilers do not turn ordinary loops into streaming code (U) |
| **ZA array, tile slices, ZT0** | ZA is SVL x SVL bits: with SVL 512 bits that is 32 KiB; ZT0 is 64 bytes for the lookup tables (D: "a single 512 bit register", sme.html section 7); horizontal and vertical slices of tiles move to and from Z registers (`mova`, `ld1w {za0h.s[w12, 0]}`) (A) | **the largest architectural state in the ISA**; signal frame carries ZA only when PSTATE.ZA is 1 (D, section 4); the ABI has a lazy-save scheme through TPIDR2_EL0 (U, from the AAPCS64 SME ABI) | intrinsics and attributes (`__arm_inout("za")`); OpenBLAS has 16 SME and SME2 kernel files for GEMM, SYRK, TRMM, SYMM (M: `grep` of `OpenBLAS/kernel/arm64`), llama.cpp reaches SME through the external KleidiAI library (M: `ggml-cpu/kleidiai`); no codec in the corpus uses it |
| **outer products FMOPA, BFMOPA, SMOPA, UMOPA, USMOPA, SUMOPA** (2-way and 4-way widening forms) | rank-1 (or rank-2, rank-4) update of a ZA tile: a GEMM micro-kernel with the accumulators in ZA (A) | SVL x SVL accumulators; a whole VL-by-VL tile of multiply-adds in one instruction; VL x VL multipliers (hundreds of thousands of NAND2 equivalents, E as in `vec-gates.md` row 14) | intrinsics only; the compilers do not recognise a GEMM loop (U) |
| **SME2 multi-vector operands** | two or four consecutive (or strided) Z registers in one instruction (`ld1w {z0.s-z3.s}, pn8/z`, `sdot za.s[w8, 0, vgx4], {z0.b-z3.b}, z4.b`, `sqrshr z0.b, {z0.s-z3.s}`, `zip {z0.b-z3.b}`) (A); more work per instruction and per predicate, and ZA-array vector groups as destinations | no state beyond the registers; the encoding space of register groups | intrinsics (U) |
| **ZT0 and LUTI2/LUTI4** (SME2); **FEAT_LUT** (`luti2`, `luti4` on SIMD and SVE registers) | table lookup of 2- or 4-bit indices into a 16-entry table of bytes or halfwords, packed indices unpacked as part of the lookup: the dequantisation of 2- and 4-bit weights of a language model in one instruction (A: `luti4 v0.16b, {v1.16b}, v2[0]`, `luti4 z0.b, zt0, z1[0]` assembled) | ZT0 is a 512-bit register (D); the SIMD form takes the table in a vector register (no new state) | intrinsics (U); **no source of the seven projects mentions `luti`** (M, grep) |
| **FP8, FP8 dot, FMLAL, FMOPA** | 8-bit float formats for ML: `fmopa za0.s, ..., z0.b, z1.b` (A, `+sme-f8f32`) | extra FPMR control register for the format (U) | intrinsics (U) |
| **SDOT, UDOT, USDOT with indexed forms** (a 32-bit lane of a register broadcast as the second operand: `sdot v0.4s, v1.16b, v2.4b[1]`) | the int8 dot product of a quantised layer or an 8-tap filter; the indexed form puts four filter taps in one 32-bit lane (A) | none | clang 19 did **not** emit SDOT for a plain int8 dot loop, with `+dotprod` and with SVE2 (M, `kern/neondot.s`: `smull`, `saddw`); newer LLVM has a partial-reduction path (U); ggml uses `vdotq_*` intrinsics in 200 places (M) |
| **SMMLA, UMMLA, USMMLA, BFMMLA, BFDOT** (I8MM, BF16) | 2x8 by 8x2 matrix multiply into a 2x2 int32 block per 128-bit segment; no tile (A) | none: the accumulators are ordinary Z/V registers; but they are architectural and persist across the K loop | intrinsics (`vmmlaq_s32`: 49 uses in ggml's NEON quantised kernels, `svmmla` 42 in its SVE kernels, M) |

**What Arm does with the state that is not saved.** Arm saves everything, lazily where it can: the kernel keeps per-thread vector length, Z, P, FFR, ZA, ZT0 (D); the syscall clears SM and the upper bits of Z, P and FFR but keeps ZA (D); a signal frame has an optional record for each, present only when the corresponding state is live (D). Faults in streaming mode are ordinary precise exceptions on instructions whose architectural state is saved by the operating system (U); there is no restart-from-entry concept, because the state is visible. **The price is state proportional to the vector length**: a 2048-bit SVE implementation has about 8 KiB of Z, an SME implementation with a 512-bit streaming vector length 32 KiB of ZA (U arithmetic).

**For the owner's question** (what to copy, what to avoid, and what is better for hidden state and restartable blocks):

* **Copy:** (a) LUTI's idea, a table lookup of small indices that makes dequantisation of low-bit weights one step; the 16-entry byte form needs no state (section 5, `vtbl.b`). (b) The rounding, saturating narrowing shift as one instruction (`rshrn`, `sqrshrun`): ours is the store. (c) SDOT and its indexed form as the canonical int8 dot, and the Q15 `sqrdmulh`.
* **Avoid:** (a) ZA and the tile as architectural state, and the lazy-save machinery that follows (the TPIDR2 protocol, the clear-on-vector-length-change rule): our hidden registers are not saved, so a tile is an accumulator that the block must restart from its entry, and the larger it is the more work a fault throws away. (b) Predicates and first-fault loads as the way to do strip-mining: they exist because the program owns the loop; ours is the hardware's. (c) Streaming mode: a second mode with its own legal instruction set doubles the test matrix.
* **A better idea for hidden state:** make every instruction either lane-local, strip-local, or a reduction into an integer register at the strip commit, so that a block has no state beyond the pointers and the registers it names. SDOT then becomes a dot-reduce into a scalar register (`vdacc`), SMMLA's matrix form is the one thing that needs lane-resident accumulators and is left out.
* **Multi-vector operands** are a way of getting more lanes per instruction without a bigger register: in our block the strip is as wide as the hardware chooses, so asking for a wider strip is the same thing and costs the architecture nothing; the cost moves to the register file of the implementation (the hidden file grows with the strip: 16 registers of 256 bits are 4 Kibit, of 1024 bits 16 Kibit).
* **SMMLA-style matrix-multiply-in-a-vector** gives more work per instruction (32 against 16 multiply-adds for a 128-bit segment, each loaded byte used twice) and no tile, but the 2x2 results accumulate in lanes across the K loop: it is the `vclr` accumulator case. It is not in the proposal; it is the first thing to add if the owner keeps the accumulators and wants the matrix work per instruction raised without a tile.

## 3. Frequency evidence

### 3.1 The corpus

Seven projects, cloned shallow on 2026-11-17 (commits in section 1). Hand-written vector code counted, of which assembly: dav1d x86 (48 `.asm` files, 87,008 vector words), NEON (23 `.S`, 17,766), RVV (12, 2,759), LoongArch (10, 9,847); FFmpeg x86 (186, 28,476), NEON (65, 13,939), RVV (67, 3,812), LoongArch (12, 6,713); libjpeg-turbo x86 (35, 4,650); libyuv RVV inline asm (1,836); OpenBLAS NEON and LoongArch assembly (not used in the tables: scalar kernels with a few vector words). Intrinsics: llama.cpp ggml x86 (12 files, 8,533), NEON and SVE (5,284), RVV (1,404), LoongArch, POWER and s390x (a few hundred each); libyuv x86 (20,258), NEON (6,442); OpenBLAS x86, NEON, POWER, RVV; FFmpeg LoongArch, MSA, VSX intrinsics (7,718, 6,276, 2,962); zlib-ng; libjpeg-turbo NEON, VSX. Hexagon HVX and s390x have no hand-written code in these projects beyond ggml's s390x file (484), so **the frequency data covers x86, Arm, RISC-V V, LoongArch, MIPS MSA and POWER; HVX and s390x are in the survey table only.**

### 3.2 Class shares

Percent of the vector instructions counted in each column (M, method in section 1). Only the columns most useful are shown; the others are in the scripts' output.

| class (percent of vector instructions) | x86 asm | NEON asm | RVV asm | LSX/LASX asm | libyuv x86 | ggml x86 | ggml NEON+SVE | ggml RVV |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| **vector instructions counted** | 120134 | 31705 | 8407 | 16560 | 20258 | 8533 | 5284 | 1404 |
| load, store, move, broadcast | 40.8 | 33.2 | 27.5 | 33.7 | 35.1 | 23.6 | 37.9 | 16.3 |
| segment (interleaved) load/store | 0.0 | 0.7 | 2.6 | 0.0 | 0.0 | 0.0 | 0.1 | 0.0 |
| gather/scatter | 0.2 | 0.0 | 0.2 | 0.0 | 0.0 | 0.0 | 0.0 | 3.1 |
| add, subtract | 12.3 | 7.7 | 7.2 | 9.2 | 8.4 | 13.2 | 3.9 | 7.7 |
| saturating add/sub | 2.2 | 2.2 | 2.1 | 3.1 | 1.1 | 0.1 | 0.0 | 0.0 |
| averaging | 0.5 | 0.8 | 1.3 | 0.9 | 1.3 | 0.2 | 0.3 | 0.0 |
| abs, abs-difference, SAD | 0.4 | 1.9 | 0.5 | 1.6 | 0.3 | 0.7 | 0.1 | 0.6 |
| min, max | 1.5 | 1.7 | 2.5 | 0.9 | 0.8 | 0.3 | 0.2 | 0.1 |
| multiply (low) | 1.7 | 1.3 | 1.4 | 1.7 | 0.6 | 0.1 | 3.6 | 3.9 |
| multiply high / Q15 round | 2.8 | 0.5 | 0.7 | 0.0 | 1.0 | 0.0 | 0.0 | 0.0 |
| widening multiply | 0.0 | 3.6 | 3.0 | 3.2 | 0.0 | 0.0 | 0.7 | 13.5 |
| pairwise multiply-add (pmaddwd) | 4.4 | 0.0 | 0.0 | 0.0 | 4.1 | 15.9 | 0.0 | 0.0 |
| integer multiply-accumulate | 0.0 | 2.1 | 1.1 | 0.9 | 0.0 | 0.0 | 3.8 | 0.1 |
| widening multiply-accumulate | 0.0 | 5.3 | 3.7 | 3.5 | 0.0 | 0.0 | 1.8 | 17.6 |
| dot product (sdot, vpdpbusd) | 1.1 | 0.5 | 0.0 | 0.7 | 0.8 | 0.2 | 5.6 | 0.0 |
| floating fused multiply-add | 0.1 | 0.3 | 0.7 | 0.0 | 0.0 | 1.4 | 0.8 | 1.8 |
| other floating point | 1.1 | 0.3 | 1.1 | 0.0 | 0.9 | 3.4 | 0.0 | 7.4 |
| shift | 4.3 | 2.5 | 2.3 | 4.4 | 9.6 | 4.6 | 7.8 | 9.3 |
| rounding shift | 0.0 | 2.7 | 1.0 | 1.1 | 0.0 | 0.0 | 0.0 | 0.0 |
| shift + round + narrow | 0.1 | 4.8 | 7.7 | 5.8 | 0.0 | 0.0 | 0.0 | 1.7 |
| narrow, pack, saturating narrow | 2.5 | 2.0 | 0.5 | 0.0 | 4.3 | 0.4 | 0.0 | 0.0 |
| widen (extend, unpack with zero) | 0.4 | 3.1 | 1.8 | 0.0 | 0.9 | 1.7 | 1.7 | 0.0 |
| widening add/sub | 0.0 | 3.2 | 6.3 | 7.8 | 0.0 | 0.0 | 0.0 | 1.6 |
| logic | 3.2 | 1.5 | 0.9 | 2.0 | 6.2 | 7.6 | 8.5 | 8.0 |
| select, blend | 0.2 | 0.8 | 0.5 | 0.5 | 0.7 | 2.6 | 0.2 | 0.6 |
| compare to mask | 0.7 | 0.9 | 0.8 | 0.9 | 1.0 | 0.6 | 0.2 | 0.0 |
| mask / predicate registers | 0.4 | 0.0 | 0.5 | 0.0 | 3.1 | 0.4 | 5.7 | 1.4 |
| fixed shuffle, interleave, unpack, slide | 15.6 | 6.1 | 3.0 | 10.8 | 11.1 | 16.1 | 3.6 | 0.9 |
| variable table lookup, byte permute | 2.6 | 1.2 | 1.8 | 4.9 | 4.8 | 4.1 | 0.7 | 2.5 |
| reduction, pairwise add | 0.4 | 1.8 | 1.2 | 0.0 | 0.2 | 0.3 | 2.8 | 0.0 |
| bit counts, crypto | 0.0 | 0.0 | 0.0 | 0.3 | 0.0 | 0.0 | 0.0 | 0.0 |
| int/float convert | 0.2 | 0.2 | 0.2 | 0.0 | 0.7 | 2.4 | 0.8 | 0.0 |
| vector-length configuration | 0.0 | 0.0 | 15.7 | 0.0 | 0.0 | 0.0 | 0.0 | 1.5 |
| unclassified or macro | 0.2 | 7.0 | 0.2 | 2.2 | 2.9 | 0.1 | 9.1 | 0.3 |

What the shares show (M):

* **Loads, stores and moves are a sixth to two fifths** of every column (16 to 41%). A block that removes the loop and the bumps does not change this share, but the fused load-and-widen of our family removes most of the "widen" rows (3.1% NEON, 1.8% RVV, 0.4 to 1.7% x86) and the second half of every widening-multiply pair.
* **Fused widening classes together** (widening multiply, multiply-accumulate and add, plus shift-round-narrow) are 17% of NEON assembly, 20% of RVV, 20% of LoongArch, and 0.1% of x86 (which spends its fusion on pairwise multiply-add, 4.4%, 15.9% in ggml). So the widening-narrowing family is the common denominator of Arm, RISC-V and LoongArch hand-written codec code.
* **Shuffles and interleaves** are the largest class after memory on x86 (15.6%, 16.1% in ggml, 11.1% in libyuv) and 6.1% NEON, 3.0% RVV, 10.8% LoongArch. Most of the x86 figure is `punpck*` (`punpcklwd` 2,593, `punpckhwd` 1,991, `punpcklbw` 1,904, `pshufd` 1,701; M) used to interleave operand pairs for `pmaddwd` and `pmaddubsw`, to widen with zero, and to transpose. In our family the widening is in the load, the interleave of operands is not needed with a displaced load or a segment load, and the transposes of the transform kernels go through memory with `vsseg`/`vlseg` (E: not measured; the transform kernels are the weakest case of our family and the cost is two memory instructions for each shuffle step).
* **Table lookup** is 1.2 to 4.9% of the assembly (x86 `pshufb` 2,599, NEON `tbl` 351, RVV `vrgather` 124, LoongArch `vshuf` 115) and 4.1% of ggml's x86 kernels (`shuffle_epi8` for the 16-entry dequantisation tables of the `iq4` formats; RVV ggml uses `vluxei16` gathers, 3.1%, for the same lookup).
* **Gather** is 0.0 to 0.3% everywhere except ggml's RVV code (3.1%, the lookup above). **Predicate and mask registers** are 0.0 to 0.5% of assembly, 3.1 to 5.7% of intrinsics code that targets AVX-512 and SVE (libyuv, ggml). **Select** is 0.2 to 0.8% of assembly and 2.6% of ggml x86.
* **Reductions across lanes to a scalar** are 0.4% (x86), 1.8% (NEON), 1.2% (RVV): rare, because code accumulates in lanes and reduces once at the end of a row.
* **Dot products** are 1.1% of x86 assembly (VNNI in the AVX-512 paths of dav1d: `vpdpwssd` 1,009, `vpdpbusd` 299), 0.5% of NEON assembly, and 5.6% of ggml's NEON and SVE code; ggml's RVV code reaches the same operation with `vwmul` and `vwmacc` (13.5% and 17.6%).
* **Vector-length configuration** (`vsetvli`) is 15.7% of the RVV assembly: the overhead that the hardware strip-mining of our block does not have (M). It is the one class where we are at an advantage in instruction count that the counts show directly.

### 3.3 The words that carry the fused classes

(M; counts over the assembly of dav1d, FFmpeg, libjpeg-turbo for x86, dav1d and FFmpeg for NEON, RVV, LoongArch.)

| class | x86 | NEON | RVV | LoongArch |
|---|---|---|---|---|
| widening multiply-accumulate | - | smlal 703, smlal2 491, umlal 262, umlal2 157 | vwmacc 137, vwmaccu 118, vwmaccsu 53 | vmaddwod 289+161, vmaddwev 66+58 |
| pairwise multiply-add | pmaddwd 2,961, pmaddubsw 2,236 | - | - | - |
| multiply high, Q15 | pmulhrsw 3,098, pmulhw 184, pmulhuw 120 | sqrdmulh 127, sqdmulh 38 | vsmul 37, vmulhu 20 | vmuh 3 |
| shift, round, narrow | - | rshrn 408+236, sqrshrn 165+117+138, sqrshrun 80, shrn 99 | vnclipu 243, vnsrl 212, vnclip 157, vnsra 37 | vssrarni 402+110, vssrani 192+26 |
| rounding shift | - | srshr 501, srshl 207, urshr 106 | vssra 80 | vsrari 127+40 |
| saturating narrow | packssdw 1,662, packuswb 1,015 | sqxtun 307+124, xtn 81 | vncvt 46 | - |
| saturating add, sub | paddsw 1,223, psubsw 822, psubusb 228 | sqadd 325, sqsub 227 | vsadd 87, vssub 72 | vsadd 246, vssub 208 |
| averaging | pavgw 322, pavgb 274 | urhadd 204 | vaaddu 101 | vavgr 145 |
| absolute difference, SAD | psadbw 115 | uabd 190, uabal 100, saba 35 | vabsaddu 4 (a macro) | vabsd 108 |
| dot | vpdpwssd 1,009, vpdpbusd 299 | sdot 132 | - | - |
| table lookup | pshufb 2,599, vpermt2/i2* 400 | tbl 351, tbx 37 | vrgather 124, vcompress 16 | vshuf 115, xvpermi 445 |
| segment load/store | - | ld2 529, st2 337, ld4 30, st4 15 | vlseg4e8 20, vsseg4e8 23, ... | - |

### 3.4 What an auto-vectorizer emits (clang 19.1.7, `-O3 -fno-unroll-loops -fno-slp-vectorize`, 20 loops, `vsurvey-kernels.c`)

M. "yes" means the fused instruction appeared in the vector loop; the rest is what appeared instead.

| loop | x86 AVX2 (and AVX-512 VNNI) | NEON (+dotprod, i8mm) | SVE2 | RVV | other |
|---|---|---|---|---|---|
| SAD of bytes | **vpsadbw yes** | uabdl + uaddw (no `uabal`) | **uaba yes** | vminu, vmaxu, vsub, vwaddu.wv, vredsum | POWER vabsduw |
| int8 dot into int32 | vpmovsxbw + **vpmaddwd**; no `vpdpbusd` even with VNNI (`vpdpwssd` after widening) | smull + saddw; **no sdot** (with `+dotprod`) | mla on widened | vsext.vf2 + **vwmacc** | z15 vmalf |
| 16-bit dot into int32 | **vpmaddwd yes** | smlal, smlal2 | - | vwmacc | - |
| shift, clamp, narrow | vpsraw + **vpackuswb yes**; vpmovuswb with AVX-512 | sshr + smin + smax + xtn (**no sqshrun**) | smin, smax | vsra + vmax + **vnclipu yes** | - |
| rounding average | **vpavgb yes** | **urhadd yes** | **urhadd yes** | **vaaddu yes** | z15: xor trick |
| Q15 rounding multiply high | no `pmulhrsw`: pmovsxwd + pmulld + shifts (12 instructions) | smull + smull2 + rshrn + rshrn2 (**no sqrdmulh**) | rshrnb | vwmacc + vnsrl | - |
| saturating byte add | no `paddusb`: pmovzxbd + vpminud + packs | umin + ushll (no `uqadd`) | umin | vwaddu + vnclipu | - |
| byte sum | pmovzxbd, vpaddd (no psadbw) | uaddw (no uaddlv/uadalp) | uaddv | vwaddu.wv + vredsum | - |
| widening multiply-accumulate into an array | vpmovsxwd, vpmulld, vpaddd | **smlal, smlal2 yes** | mad | **vwmacc.vx yes** | z15 vmalf |
| select with byte mask | vpinsrb x45 (scalarised) | - | - | - | - |
| 16-entry table lookup | scalar (vpinsrb) | scalar | scalar | vluxei8 (a gather) | - |
| popcount sum | vpshufb nibble table + vpsadbw | **cnt + uaddlp, uadalp yes** | cnt | vsrl, vand, vadd (no `vcpop.v`) | - |
| stereo deinterleave | vpshufb, vpermq, vpblendd | **ld2 yes** | **ld2 yes** | **vlseg2e16 yes** | - |

On LoongArch LASX and MIPS MSA clang 19 produced scalar element inserts (`vinsgr2vr`: 96 per loop for the saturating add) or scalar loops, and Hexagon HVX code was not vectorized: **those columns say nothing about the ISAs**, only about the state of LLVM 19's backends. clang 19 is not the compiler of the repository (LLVM 21.1.8): a partial-reduction path for dot products was added to LLVM after 19 (U), so the SDOT and VNNI rows may differ.

### 3.5 Other counts

* **Memory operands in x86 vector arithmetic** (M, `vsurvey-memop.py`: 68,461 source lines of vector arithmetic and shuffles in dav1d, FFmpeg and libjpeg-turbo x86 assembly): 12.0% have a memory source, mostly constants (`pmulhrsw` with a `pw_...` table 26%, `pmaddwd` 21%, `paddw` 15%, `pshufb` 10%). In our family constants are immediates or scalar registers (`vmul.w vD, vA, #imm`), so the fused load-and-operate would remove at most about 12% of the instructions of an x86-style kernel and much less of ours; it is **not proposed**: it would multiply the words by the memory types.
* **SME in real code** (M, grep): OpenBLAS has 16 files of SME and SME2 kernels (`sme_sgemm_kernel.c`, `sme_dgemm_kernel.c`, `sme_zgemm_kernel.c`, `sbgemm_kernel_sme2.c`, `sgemm_direct_sme1_2VLx2VL.S`, `ssyrk_...sme1.c`, `strmm_...`); llama.cpp calls KleidiAI. No codec uses it.
* **POWER MMA** (M): 21 OpenBLAS kernel files use `__builtin_mma`/`xvf32gerpp`; **AMX** (M): llama.cpp's `ggml-cpu/amx/mmq.cpp` (16 uses of the tile dot-product intrinsics) and one OpenBLAS file. The tile exists in three ISAs and is used by the linear-algebra libraries only.
* **First-fault loads, LUTI, FP8**: no use in the seven projects (M, grep).
* **`vsetvli` overhead** in RISC-V assembly: 982 `vsetvli` + 270 `vsetivli` for 8,407 vector words in dav1d and FFmpeg (15.7%, M).

### 3.6 The existing measure, restated

`llvm/vector-usage.md` (M, errata 167): 22 of 55 base mnemonics unused by 31 compiled kernels: `vlen vclr vfir vlseg/vsseg vldx vdot vmla vfmab vabdu`, the tile and `gemm.f`. Two things in it matter here. (1) A compiler that cannot narrow cannot use byte lanes for a reduction, so the strip is 8 elements for `k_q8dot` and `k_sad` (M: `llvm/bench/results.csv`: `k_q8dot` 125 strips for 1,000 elements, 4 operations a strip, 513 instructions executed against 6,011 scalar). (2) The families that the compiled kernels do use, loads, stores, lane add, subtract and multiply, `vfma`, `vacc`, saturating add, are the same as in the left-hand classes of section 3.2.

## 4. Gap analysis

### 4.1 What real code needs and we lack

Each row says whether the evidence supports it (not assumed). "Cost today" is the instruction count of the idiom in our family.

| class | evidence that it matters | our cost today | verdict |
|---|---|---|---|
| rounding average | 0.2 to 1.3% of every column; `avg` loops in codecs (dav1d `avg_c`, `w_avg`, `mask`), clang emits it on four targets (M) | 3 (`vadd`, `vadd #1`, `vshr`) | **needed** |
| Q15 rounding multiply high | x86 2.8% (dav1d 3.4%), 3,098 uses; dav1d's transforms use it through `pw_2896x8` (M); Arm `sqrdmulh` 0.5%; clang 19 emits it nowhere (M) | 3, in 32-bit lanes: half the elements per strip | **needed** (hand-written code) |
| rounding shift right | NEON 2.7%, RVV 1.0%, LoongArch 1.1% | 2 | **needed** |
| shift, round, saturate, narrow | NEON 4.8%, RVV 7.7%, LoongArch 5.8%: the largest missing class after widening | 3 (`vadd`, `vsar`, `vsts`) | **needed**, fuse into the store |
| 16-bit pairwise dot (`pmaddwd`) | x86 4.4% (2,961 + `vpdpwssd` 1,009), ggml x86 15.9%; clang emits it for 16-bit dot loops (M) | 2 (`vmul`, `vacc` on 32-bit lanes) | **needed** |
| dot product reduced to a scalar | 5.6% of ggml NEON+SVE, 0.5 to 1.1% of assembly; the reduce form is what a row of a matrix-vector product needs | `vdot` + `vacc`: 2, and the strip drops to 32-bit lanes (8 elements) | **needed** (fusion) |
| SAD / abs-diff accumulate | x86 `psadbw` 115, NEON `uabal` 100, SVE2 `uaba`, RVV none; kernels of encoders and motion search (FFmpeg `pixelutils`) | 2 | small; nearly free to add |
| table lookup | 1.2 to 4.9% of assembly, 4.1% of ggml x86; LLM dequantisation | 1 (`vldx`), one lane a cycle | **needed**, as a 16-entry in-strip lookup |
| fixed interleave, unpack, zip | 15.6% x86, 6.1% NEON, 10.8% LoongArch | memory path only | **mostly covered** by load-widen, segment loads and displaced loads; not added (section 4.4) |
| compare and select | 0.8% to 2.6%; 14% of the vectorized loops of dav1d's C were masked (M, `vector-study.md`) | not expressible except as min/max/abd | **needed for the compiler**, rare in hand code: second wave |
| int/float conversion | ggml x86 2.4%, libyuv 0.7%, assembly 0.2%; the quantisation of activations | none | **needed for LLM code**, second wave |
| in-register widen and narrow | NEON widen 3.1%, narrow 2.0% | store and load again (the lane type of a register is fixed by its last write; the assembler checks it) | **unknown size**: much of it is directly after a load or before a store, which we have; deferred |
| gather | 0.0 to 0.3%; clang vectorizes none; 3.1% of ggml RVV is a lookup | `vldx` | **not needed** once the lookup exists |
| masks, predication | 0.0 to 0.5% of assembly, 3 to 6% of AVX-512 and SVE intrinsics code | none | **not needed** in the first revision; vector registers hold masks (second wave) |
| popcount | 0.0% | none | not needed |
| integer multiply-accumulate v by v | NEON `mla` 2.1%, RVV `vmacc` 1.1% | `vmul` + `vadd` (2); `vmla` exists for a scalar operand only | **add the operand form**, no new words |
| rounding of the strip: `vlen`, `vsetvli` | 15.7% of RVV assembly | 0 (not needed in a block) | we are ahead |

### 4.2 What is fused well already

* **Widening on the load, narrowing and saturating on the store** (`vld.bu.w`, `vst.w.b`, `vsts.w.bu`): the widen row is 3.1% of NEON and 1.8% of RVV assembly, and the widening multiply, multiply-accumulate and add rows (8 to 14%) have operands that are loads in most kernels; here these are wide-lane operations with no extra instruction; x86 needs `pmovzx` or `punpck` for the same (M, section 3.2).
* **Reductions into a scalar register with an accumulate width chosen by the type** (`vacc.<src>.<acc>`, errata 168): one instruction for what x86 does in 3+ and RVV in 2 (`vredsum`, `vmv.x.s`); each strip commits to an ordinary register, so a fault restarts at the strip (M for the count, `vec-isa.md` for the rule).
* **Saturating add and subtract, min and max, absolute difference** as lane words: one instruction each, as in every ISA (row 9: x86 and RVV need three for the absolute difference).
* **The sliding-window multiply-accumulate** (`vfir`): no ISA surveyed has it (the nearest are HVX `vrmpy` with a sliding window and the x86 `pmaddubsw` plus shuffles, U), and it makes the 8-tap filter 0.62 block operations for each pixel against 2.38 with displaced loads (M, `vec-forms.md`).
* **Segment loads and stores** (`vlseg`, `vsseg`): one instruction as in NEON, SVE and RVV; absent from x86, LoongArch, POWER, MSA (M, section 2.1).
* **Hardware strip-mining**: the 15.7% of RVV that is `vsetvli` does not exist.

### 4.3 What we have that nothing much uses (candidates to delete)

For each, whether real code outside our 31 compiled kernels uses it, and what removing it saves (E for gates, `vec-gates.md`; words from the grammar).

| item | words | compiled kernels | real code outside | evidence | decision |
|---|---:|---|---|---|---|
| `gemm.f` (whole-GEMM unit with a descriptor) | 1 | none | **no ISA has one** (U): every CPU ISA stops at the tile (AMX, SME, MMA); a descriptor-driven matrix instruction is an accelerator | 1.2 to 1.7 million gates (E), 8 times the core's logic (E); a whole GEMM livelocks against the timer tick (gemm-forms 5a) | **remove** |
| tile: `vtclr vtld vtst vtadd vtfmopa` | 9 | none | AMX, SME, MMA: used by OpenBLAS (16 SME files, 21 MMA files, 1 AMX), llama.cpp AMX and KleidiAI; **only by linear-algebra libraries** (M) | 260,000 (int8) to 665,000 (fp32) gates (E); the largest hidden state; restart from the entry of the block | **remove** (judgement: the micro-kernel form below covers 0.141 against 0.047 operations for each multiply-add for 28,000 gates) |
| gather `vldx` | 22 | none (the pass cannot recognise one) | AVX2/512 `vpgather*` 0.2% of dav1d assembly (film grain); RVV `vluxei` 3.1% of ggml RVV, but there it is the table lookup | 4,000 to 6,000 gates (E) plus one lane a cycle and **a precise fault for each lane**: a strip with 32 independent addresses may fault in the middle | **remove** (replaced by `vtbl.b`) |
| `vlen.<t>` | 6 | none | `cntw`/`rdvl` in SVE (0.4% of ggml SVE) and `vlenb` in RVV: the program needs VL to lay out a packed panel | nothing in the block needs it | **keep one word** |
| `vclr`, `vfmab`, 16 hidden registers | 6 + 2 | none (needs a loop nest) | the micro-kernel of every GEMM (OpenBLAS Haswell, SVE, SME) | 28,000 gates for the second register file (E); the only hidden state that crosses strips: the block restarts from its entry | **keep, ranked last**; the first thing to delete if the owner wants no state across strips |
| `vfir` | 6 | none (needs a recogniser) | no ISA has it; motion compensation is 15,884 of the 56,230 assembled NEON instructions of dav1d, 28% (M, the table of `vector-study.md` section 4) | 3,000 to 6,000 gates on shared multipliers (E); the halo is the last elements of the previous strip, **which are in memory** and can be re-read at a restart, so it is not hidden state (E, a rule to state in `vec-isa.md`) | **keep** (3 words: `.w .l .f`) |
| `vdot` family | 3 | none (not auto-vectorized by clang 19; the pass has no pattern) | VNNI and SDOT: 1.1% of x86 assembly, 5.6% of ggml NEON | 37,000 gates (E) | **keep**, plus the 16-bit and the reduce forms |
| 64-bit lane forms of multiply, min, max, abd | 10 | none | x86 `paddq` 28 of 172,958 tokens; no codec or LLM kernel multiplies 64-bit lanes | the 16-bit multiplier array would need ten passes for 64 bits (E) | **remove** (`vmul.q vmin.q vmax.q vminu.q vmaxu.q vabd.q vabd.f vabd.d vabdu.l vabdu.q`) |
| `vmla` on 8 and 64-bit lanes, `vclr`/`vfir` on other lanes | 8 | none | - | - | **remove** (`vmla.b vmla.q`, `vclr` to `.l .f .d`, `vfir` to `.w .l .f`) |

### 4.4 Fusion opportunities, one at a time

For every proposal: what it replaces, in instructions of a concrete kernel (E: hand counts of the proposed form, none assembled; the existing forms are in `arch-data/vec-forms/`); silicon (E, scaled from the synthesised blocks of `vec-gates.md`); restart; compiler path.

1. **Shift, round, saturate, narrow, store**: the existing narrowing store `vsts.<lane>.<m>` takes an optional immediate (`vsts.w.bu vS, (Ra)+, #sh`: add `1 << (sh-1)`, shift right arithmetic, clamp to the range of `<m>`, narrow, store; `#0` is today's instruction). Replaces `vadd #round`, `vsar`, `vsts` (3) by 1. dav1d `blend_c` (`(a*(64-m)+b*m+32)>>6`): 10 instructions in the block to 8; dav1d 8-bit `put_8tap` horizontal with `vfir`: `vld, vfir, vadd #32, vsar #6, vsts` (5) to `vld, vfir, vsts #6` (3); dav1d `avg_c`: 6 to 5 (the bias term of the intermediate format still needs its add). Silicon: a rounding adder per lane and the shifter that `vsar` already has, wired into the store path: 2,000 to 4,000 gates. Restart: lane-local, strip-local, none. Compiler: RVV and x86 patterns already fuse the clamp and narrow (M, 3.4: `vnclipu`, `packuswb`); AArch64 clang 19 missed `sqshrun` on the loop tried (M), so a DAG combine of `trunc(smin(smax(ashr(add x, r), s)))` is needed (the pass of the repository emits `vsts` already for the clamp).
2. **Rounding average** `vavg.b .w`, `vavgu.b .w`: `(a + b + 1) >> 1` without overflow. Replaces 3 (`vadd`, `vadd #1`, `vshr`) by 1, and the byte version keeps byte lanes (the sum of two bytes needs 9 bits). Silicon: a carry-in and a shift of the lane adder: 1,000 to 2,000 gates. Restart none. Compiler: canonical (`avgceilu`/`avgceils` nodes; clang 19 emitted `vpavgb`, `urhadd`, `vaaddu` from `(a+b+1)>>1`, M).
3. **Multiply high and Q15 rounding multiply** `vmulh.w`, `vmulhu.w`, `vmulhr.w`: high half of the 16 by 16 product, and `(a*b + 2^14) >> 15`, saturating at -32768 times -32768 (the semantics of `sqrdmulh`; x86 `pmulhrsw` wraps in that one case: stated, not hidden). Replaces 3 instructions in 32-bit lanes (so half the elements a strip) by 1 in 16-bit lanes: dav1d's inverse transforms (`t = (x*2896 + 2048) >> 12`, with `2896*8` as the 16-bit constant, M for the use of `pw_2896x8` in `itx_avx2.asm`): 6 instructions per 8 elements to 4 per 16 (0.25 against 0.75 per element). Silicon: the high half of the existing 16 by 16 multipliers plus a rounding bit injected into the adder tree, a clamp of one case: 1,000 to 2,000 gates. Restart none. Compiler: `mulhs`/`mulhu` are canonical IR (`x86 pmulhw` is selected from them, U); the Q15 rounding idiom was **not** matched by clang 19 on x86 or AArch64 (M, section 3.4): needs a DAG pattern or is hand-written.
4. **Rounding shift** `vsarr.w .l`, `vshrr.w .l`: `(x + (1 << (s-1))) >> s` in the lane. Replaces 2 by 1; used where the value stays wide (transforms: `srshr`, `vsrari`). Silicon: 2,000 to 3,000 gates (a rounding adder for each lane after the shifter). Restart none. Compiler: AArch64 selects `srshr`/`urshr` from the idiom (SVE2 emitted `urshr`, M); partial.
5. **Dot product on 16-bit lanes** `vdot.w vD, vA, vB`: each 32-bit lane gets the sum of the two 16-bit products. Replaces `vmul` plus a widening add (2). Silicon: the existing 16 multipliers, one 32-bit adder for each pair and one for the accumulate: 3,000 to 4,000 gates. Restart none (the accumulator is in-strip). Compiler: clang emits `pmaddwd` from `sum += a[i]*b[i]` on i16 (M).
6. **Dot product reduced to a scalar register** `vdacc.b`, `vdacc.bu`, `vdacc.bsu`, `vdacc.w Rd, vA, vB`: `Rd +=` the sum of all products of the strip. It is `vdot` and `vacc` in one: **the strip stays at 32 byte lanes** (no 32-bit lane in the block, so no widest-lane penalty), and the register is committed at the strip like `vacc`, so there is no accumulator and no restart rule. `k_q8dot` (the plain dot of llama.cpp's q8_0 inner loop, `arch-data/vec-forms/games/k_q8dot.vec.s`): 4 block instructions for 16 multiply-adds (the hand form: `vld.b.w, vld.b.w, vmul.w, vacc.w.l`) to 3 for 32 (`vld.b, vld.b, vdacc.b`): 0.25 to 0.094 per multiply-add; the compiled form (strip of 8, 4 operations) is 0.5: 5.3 times fewer. The silicon is the 8 `dot4` blocks of row 7 (37,000 gates, M) plus an 8-input sum (about 1,500, E from `reduce16` 2,979) in place of the lane write; `vdot` stays for the filters. Compiler: needs the dot-product pattern (partial reduction of `mul(sext, sext)`, LLVM 20 and later, U) or an intrinsic.
   *A limit that the existing `k_q8dot` form hides:* llama.cpp's q8_0 format has one scale for each 32 elements, so the real loop is a scalar loop over blocks with `vec`, three block instructions, `vend`, and the scale arithmetic: about 12 instructions for 32 multiply-adds, of which the dot is 3 (E, hand count). Nested `vec` blocks of 32 elements pay two instructions of set-up each; whether `vec`/`vend` is cheap in hardware is a design question that the cost-benefit study (which used the unscaled dot) did not show.
7. **SAD** `vsad.bu Rd, vA, vB`: `Rd += sum |a - b|` of unsigned bytes. Replaces `vabdu` and `vacc.bu.l` (2) by 1; FFmpeg `pixel_sad`: 4 block instructions per 32 bytes to 3. Silicon: wiring of the `vabd` lane and the `vacc` tree: about 500 gates. Restart none. Compiler: x86 `psadbw` and SVE2 `uaba` were selected from the idiom (M); a pattern.
8. **16-entry table lookup in the strip** `vtbl.b vD, vT, vI`: for each lane, `vD[i] = vT[16*(i/16) + (vI[i] & 15)]`, and 0 if bit 7 of the index is set (the semantics of `pshufb`, with the table per group of 16 lanes so that the result does not depend on the strip length). Replaces `vldx` (a gather, one lane a cycle) for the dequantisation tables of ggml's `iq4` formats and the shuffles of dav1d (`pshufb` 2,599, constant masks): instruction count the same (1), **time 16 to 32 times less** (a strip of 32 lookups in 1 to 2 cycles against 32; E). Silicon: a 16:1 byte multiplexer for each lane, 32 lanes: about 10,000 to 12,000 gates (E: 3,840 two-way multiplexers at 2.5 to 3 gates each). It is the only cross-lane network in the proposal and it is small because it is confined to 16 lanes. Restart none. Compiler: none emits it (clang 19 left `t[a[i] & 15]` scalar on x86, NEON, SVE and made a gather on RVV, M): intrinsic or hand-written. The Arm answer, LUTI4, also unpacks the nibble indices; ours leaves that to `vand` and `vshr` (2 instructions for 32 outputs; not added).
9. **Integer `vmla` with a vector operand** (`vmla.w vD, vA, vB`: `vD += vA * vB`): no new words, a new operand form in the `VOP.VVV` shape. Replaces `vmul` + `vadd` (2) by 1: `blend_c` goes from 8 to 7. Silicon: the adder behind the multiplier already exists for `vfma` and `vdot` (E, small). Compiler: canonical (`add(mul)` fuses to `mla`/`vmacc` in clang 19, M, `wmac`).
10. **Second wave, compare and select**: `vceq.b .w .l .f`, `vcgt.b .w .l .f`, `vcgtu.b .w .l` (a lane mask: all ones or zero, in an ordinary vector register: no mask file) and `vbsl vD, vM, vA, vB` (bitwise select). Replaces nothing in the compiled kernels (they have no branches); makes a loop with `if (x > t) y[i] = ...` and a ternary vectorizable. 12 words and 2,000 to 4,000 gates (E); the three read ports of the register file exist. Restart none. Compiler: canonical (`select(icmp)`). *Deferred beyond it:* predicate registers (state, a second register class) and masked stores.
11. **Second wave, conversion** `vcvt.f.l`, `vcvt.l.f` (int32 to float, float to int32 with round to nearest even): the quantisation of activations in the LLM loop (`quantize_row_q8_0`) and the dequantisation of a lane. 2 words, 3,000 to 5,000 gates on the existing 8 floating-point lanes (E). Compiler: canonical (`sitofp`, `fptosi` with rounding intrinsics).

**Considered and not proposed:** (a) a fused load-and-operate (a memory operand on lane operations): 12% of x86 vector lines, mostly constants, which are immediates here (M, 3.5); (b) in-register zip and unpack: transposes go through `vsseg`/`vlseg`; adding them needs a rule for what a zip of two registers means when the strip length is the hardware's, and 15.6% of x86 is `punpck` mostly because x86 has no widening load of this kind; (c) in-register widening and narrowing of the lane type: 30 words; unknown size; test first; (d) `vmmla` (SMMLA): section 2.3; (e) multi-vector operands: section 2.3; (f) predicate registers and first-fault loads: a block with a precise strip fault does not need first-fault; early-exit loops (`strlen`, `memchr`) are a gap that this survey did not measure (U); (g) LUTI-style nibble unpack in the lookup: 1 to 2 instructions saved for 32 outputs, deferred.

## 5. The revised family

### 5.1 Words to add, fuse, keep and remove

[now: every row of this table was accepted (R474) and implemented, with these differences. (a) `vlen`: the row says keep one word; wave 1 kept `vlen.b`; errata 173 removed it (the strip is invisible), so the micro-kernel has a fixed 8 by 4 tile. (b) `vtbl.b`: only the memory form `vD, (Ra), vI` exists; the register form was removed (errata 173). (c) `vcvt`: 4 words, not 2 (unsigned forms added), names `vcvt.<from>.<to>`, float to integer truncates and saturates (errata 171); the compares write an integer lane also for `.f`. (d) `vmulhr` saturates (-32768 x -32768 gives 32767); `vsad.bu` and `vdacc` commit with the strip. (e) the REMOVE rows are done: `gemm.f`, the tile, `vldx` (22 words), the 10 lane variants, `vmla.b .q`, `vclr.b .w .q`, `vfir.b .q .d`. (f) the "Compiler" letters are what the survey expected; the words the LLVM lowering actually selects are in `llvm/vector-usage.md` and the table of `vec-isa.md`.]

Ranks: 1 is the best ratio of work saved per instruction and code byte to silicon, counting the evidence (a fusion that is nearly free but saves one instruction in a rare kernel ranks below one that costs more and saves three in a common one). "Compiler" is the path to use: **C** = canonical IR, LoopVectorize/SLP selects it with a pattern that exists in LLVM; **P** = needs a backend combine or a recogniser that does not exist (clang 19 missed it, or no pattern is known); **I** = intrinsic or hand-written assembly only. Kernel effect is block instructions, E.

| word (new operand forms in italics) | action | replaces | kernel effect | silicon (gates, E) | restart / hidden state | compiler | rank |
|---|---|---|---|---:|---|---|---:|
| `vavg.b .w`, `vavgu.b .w` | ADD (4 words) | `vadd, vadd #1, vshr` (3) | dav1d `avg`/`w_avg` family: 3 to 1 for the rounding step | 1,000 to 2,000 | none | **C** (verified x86, NEON, SVE2, RVV) | 1 |
| *`vsts.<lane>.<m> vS, (Ra)+, #sh`* (rounding shift in the narrowing store) | FUSE (0 words) | `vadd #r, vsar, vsts` (3) | `blend_c` 10 to 8, `put_8tap` h 5 to 3, `avg_c` 6 to 5 | 2,000 to 4,000 | none (strip-local) | **P** (RVV, x86 fuse the clamp; AArch64 clang 19 does not) | 2 |
| `vmulh.w`, `vmulhu.w`, `vmulhr.w` | ADD (3 words) | `widen, vmul.l, vsar` (3 in half-width lanes) | dav1d `itx` butterfly 0.75 to 0.25 instructions per element | 1,000 to 2,000 | none | high half **C**, Q15 round **P/I** (clang 19 does not match it) | 3 |
| `vdacc.b .bu .bsu .w` (dot reduced to a scalar) | FUSE `vdot`+`vacc` (4 words) | `vdot.b` + `vacc.l.l` (2, 8 elements a strip) | `k_q8dot` 0.5 compiled / 0.25 hand to 0.094 per multiply-add; strip stays 32 bytes | about 1,500 over `vdot` (the tree) | none: the register is committed at the strip like `vacc` | **P** (partial reduction of `mul(sext,sext)`, LLVM 20+, U) or I | 4 |
| `vsarr.w .l`, `vshrr.w .l` | ADD (4 words) | `vadd #r`, `vsar` (2) | transform kernels' rounding steps 2 to 1 | 2,000 to 3,000 | none | **P** (AArch64 selects `srshr` from the idiom; partial) | 5 |
| `vdot.w` | ADD (1 word) | `vmul` + widening add (2) | 16-bit filters and `scalarproduct`: 2 to 1 | 3,000 to 4,000 | none | **C** (`pmaddwd` from the i16 dot loop, M) | 6 |
| `vsad.bu` | FUSE `vabdu`+`vacc` (1 word) | 2 | FFmpeg SAD 4 to 3 per 32 bytes | about 500 | none | **P** (`psadbw`, `uaba` exist) | 7 |
| `vtbl.b` | ADD (1 word) | `vldx` (lane a cycle) | q4/iq4 dequantisation, dav1d masks: same count, 16 to 32 times faster | 10,000 to 12,000 | none (in-strip) | **I** | 8 |
| *`vmla vD, vA, vB`* (vector operand) | FUSE (0 words) | `vmul` + `vadd` (2) | `blend_c` 8 to 7; `wmac` | small | none | **C** | 9 |
| `vceq`, `vcgt` (4 each), `vcgtu` (3), `vbsl` (1) | ADD, second wave (12) | not expressible | masked loops (14% of dav1d's vectorized loops) | 2,000 to 4,000 | none (mask in a vector register) | **C** | 10 |
| `vcvt.f.l`, `vcvt.l.f` | ADD, second wave (2) | none | LLM quantise/dequantise loops | 3,000 to 5,000 | none | **C** | 11 |
| `vld`, `vst`, `vsts`, `vldt`, `vstt`, `vlseg`, `vsseg`, lane ALU words, `vmul`, `vfma`, `vfnma`, `vacc`, `vmaxacc`, `vminacc`, `vdot.b/.bu/.bsu`, `vabd`, `vabdu.b .w`, `vlen` (1 word), `vec`, `vend` | KEEP | - | - | - | none | as now | - |
| `vfir.w .l .f` | KEEP (3 words, from 6) | 8 loads and 8 multiplies | `put8h` 0.62 against 2.38 operations per pixel | 3,000 to 6,000 | the halo is re-read from memory at a restart | **I** (needs a recogniser) | - |
| `vfmab.f .d`, `vclr.l .f .d` | KEEP, rank last (5 words, from 8) | the micro-kernel | 0.141 against 0.5 operations per multiply-add | 28,000 | **restart from the entry of the block**; the only state across strips | **I** | - |
| `gemm.f` | REMOVE (1) | - | - | 1,200,000 to 1,700,000 | livelock against the timer | - | - |
| `vtclr vtld vtst vtadd vtfmopa.f .d` | REMOVE (9) | - | - | 260,000 to 665,000 | hidden tile | - | - |
| `vldx` (22 words) | REMOVE | `vtbl.b` | - | 4,000 to 6,000 | a fault in any lane | - | - |
| `vlen.b .w .l .q .f .d` | REMOVE 5 (keep one) | - | - | - | - | - | - |
| `vmul.q vmin.q vmax.q vminu.q vmaxu.q vabd.q vabd.f vabd.d vabdu.l vabdu.q` | REMOVE (10) | - | - | 0 | - | - | - |
| `vmla.b .q`, `vclr` (3), `vfir` (3) | REMOVE (8, counted above) | - | - | - | - | - | - |

### 5.2 Words and silicon, before and after

[now: the proposal's word counts below are the survey's, of a grammar it counted as 372 words; the grammar had 384. Implemented: 384 words before, **347 after wave 1** (55 removed, 18 added), **363 after wave 2** (16 added: `vceq vcgt` 4 each, `vcgtu` 3, `vbsl`, 4 conversions), **363 after errata 173** (`vlen.b` out, `vfin` in); base mnemonics 55, 58, 63, 63. The silicon column is the survey's estimate; the measured figures are in `vec-silicon.md` section 5 (wave 1, 16 integer lanes: 263,000 to 291,000, not 219,000).]

| | before | after wave 1 | after waves 1 and 2 |
|---|---:|---:|---:|
| words (grammar: 372; M) | 372 | 335 (remove 55, add 18) | 349 (add 14 more) |
| base mnemonics | 55 | 58 (remove 7: `vldx vtclr vtfmopa vtld vtst vtadd gemm`; add 10) | 63 |
| words of the memory forms (`vld vst vsts vldt vstt vlseg vsseg vldx`) | 197 | 175 | 175 |
| silicon, NAND2 equivalents (E) | **1.4 to 2.0 million** (the yes and likely rows of `vec-gates.md`, 195,000 to 280,000, plus the whole-GEMM unit 1.22 to 1.74 million, which contains the tile) | **219,000** with the 16-lane integer unit (298,000 with the 8 floating-point lanes) | 224,000 to 228,000 (303,000 to 307,000 with floating point) |
| the same without `vfmab`/`vclr` and the second register file | - | 191,000 (270,000) | - |
| hidden state that survives a strip | the accumulators of `vclr`, the tile, `gemm.f` progress | the accumulators of `vclr` only | same |

How the 219,000 is made (E): base 98,000 (M for blocks, E for the sum, `vec-gates.md`); reductions 6,000; saturation and narrowing 13,500; shifts 3,000; `vfir` on shared multipliers 4,500; `vdot.b` 37,000; segment loads 3,500; register file of 16 28,000; new: `vdot.w` 3,500, `vdacc` 2,000, `vsad` 500, `vavg` 1,500, `vmulh` 1,500, `vtbl` 11,000, rounding shifts 2,500, the rounding store 3,000 = 25,500. The proposal costs about 25,000 gates more than the yes-and-likely set that the owner accepted (errata 157) and about 1.2 to 1.7 million less than the family as it is in the grammar. **The ranges are E and a factor of 1.5 either way is possible**; a synthesis of the new blocks would narrow them (not done: no yosys on this machine). One saving is not taken: the `vdot.b` array (37,000) could share the 16 by 16 multipliers if those are built as four 8 by 8 products, which would save 10,000 to 20,000 (U: depends on the multiplier structure; not claimed).

### 5.3 Effect on the kernels

[now: measured after the implementation (`llvm/bench/results.csv`, `llvm/README.md` stage 2c; instructions executed for 1,000 elements): `k_q8dot` 513 to 109 (the survey's estimate was about 110), `k_sad` 755 to 339, `k_softmax` 5,405 to 3,431; the 31 kernels `lv` geometric mean moved from 1/7.66 to 1/8.40 of scalar and 46 kernels (15 new ones that use the new words) are 1/10.99. The hand-written kernels `k_q8dot`, `k_q4dot` and `k_sad` use the fused forms (vector instructions executed 252 to 96, 352 to 144, 160 to 120, errata 170). The tables below are the survey's hand counts.]

**The 31 compiled kernels** (`llvm/bench`, M): 26 use only words that are kept, so their counts do not change. Five could change if the loop pass learns the new patterns: `k_q8dot` (513 instructions executed for 1,000 elements; with `vdacc.b` and byte lanes about 110: 3 operations for 32 elements, 32 strips; E), `k_q4dot` (708; the nibble unpack needs `vand`/`vshr` before the dot: about 2 to 3 times fewer, E), `k_sad` (756: 128 strips of 4 operations to 32 strips of 3, about 2.8 times fewer; most of it is the narrowing the pass cannot do today, not `vsad`), `k_put8h` (3,401: the final add, shift and store become one store, about 8% of the 26 operations of a strip), and the saturating-narrow kernels. The geometric mean over the 29 vectorized kernels (1/11.4 of the scalar instructions, M) would move by a few percent (E): the gain of the proposal is in hand-written code and in the strip width, not in these kernels. Of the 22 base mnemonics no kernel used, 7 are removed, `vlen` is cut to one word, and the others stay until the pass learns their patterns.

**Six kernels of real code** (E, hand counts of the proposed forms; the current forms are those of `arch-data/vec-forms/` or written by the same rule as them):

| kernel (source) | pcc scalar loop, instructions per element (M where from `vec-forms.md`, `vec-cost-benefit.md`) | now: block instructions per strip (elements per strip) | proposed | what does it |
|---|---|---:|---:|---|
| ggml q8_0 dot, inner (llama.cpp `ggml_vec_dot_q8_0_q8_0`; **without** the per-block scale) | 6 (M) | 4 (16); 4 (8) as the pass compiles it | 3 (32) | `vdacc.b` |
| dav1d `blend_c` (`(a*(64-m) + b*m + 32) >> 6`, 8 bit) | not measured | 10 (16) | 7 (16) | `vmla` v by v (-1), rounding store (-2) |
| dav1d `put_8tap` horizontal, 8 bit, with `vfir` | 48 (M) | 5 (8, 32-bit lanes) | 3 (8) | rounding store |
| dav1d `itx` 1-D butterfly step (`(x*2896 + 2048) >> 12`) | not measured | 6 (8, 32-bit lanes) | 4 (16) | `vmulhr.w` |
| FFmpeg `pixel_sad` row | 7 (M) | 4 (32) | 3 (32) | `vsad.bu` |
| ggml `iq4_nl` lookup `kvalues[x & 15]`, 32 weights | not measured | 5 instructions, about 32 cycles (a gather lane a cycle) | 5 instructions, about 2 cycles | `vtbl.b` instead of `vldx` |

(The "now" and "proposed" columns are hand counts of block bodies without `vec` and `vend`, E. The elements a strip differ between rows because the lane width differs; compare instructions for each element: q8_0 0.25 to 0.094, `blend` 0.63 to 0.44, `put_8tap` 0.63 to 0.38, `itx` 0.75 to 0.25, SAD 0.125 to 0.094.)

For comparison, hand-written code of the other ISAs for the same step (from section 3; M where counted): x86 `pavgb`, `pmulhrsw`, `pmaddwd`, `psadbw`, `pshufb` are each one instruction; NEON `urhadd`, `sqrdmulh`, `sqrshrun`, `sdot`, `tbl` too; **so the proposed family reaches the instruction count of the best hand-written forms of the other ISAs for these steps and keeps the block's advantages: no loop, no pointer bump, no remainder, no width**.

## 6. Ease of implementation, speed and compiler ease ("optimal by construction")

The owner asked (B) which things can be implemented most easily and run fastest, that is, are optimal by construction because a fixed canonical instruction covers a common pattern and neither the compiler nor the hardware has to find or schedule anything. Three axes, each with its own scale.

**Hardware ease.** R = reuses an existing datapath (multiplier, adder tree, shifter, the lane ALU) so the cost is wiring and control; N = needs a new unit; L = stays within one lane; G = within a group of 16 lanes; X = a crossbar across the strip; S = new state; U = fixed latency and one micro-operation. **Speed.** the datapath it needs and the chain it creates or removes; **Memory** = bound by memory bandwidth, not lanes. **Compiler.** C, P, I as in section 5.

| instruction or class | hardware | execution speed | compiler |
|---|---|---|---|
| block control (`vec`, `vend`) | N small (4 pointers, sequencer: 5,000, M); S none beyond pointers; U | removes the 15.7% `vsetvli` overhead of RVV; the set-up of an inner block of 32 elements costs 2 instructions | **C** (the repository's pass) |
| `vld`, `vst` with widen or narrow | R (alignment and merge 10,000 E); L; U | **memory-bound**: 32 bytes a cycle at best; more lanes do not help streaming kernels (`fmac`, `prep`, `mix16` are bound by the load port, E) | **C** |
| `vsts` with rounding shift | R shifter and clamp; L; U | removes a 3-instruction chain of 3 dependent lane operations | **P** |
| `vldt`, `vstt` (strided) | R address generator; **extra cache accesses**; U | one access per lane for strides over a line: slow, a lane a cycle | **C** (strided loop) |
| `vlseg`, `vsseg` | N small de-interleave network in the memory path (2,000 to 5,000, M for the 8-bit network); G | one line read serves all fields (E) | **C** (LLVM's interleaved-access pass, as on AArch64: M, `ld2` emitted) |
| lane add, sub, logic, shift, min, max, abd, saturating | R lane ALU; L; U, one cycle | one strip a cycle at 16 lanes of 16 bits; the cheapest operations | **C** |
| `vavg` | R lane adder with carry-in; L; U | one cycle | **C** |
| `vmul`, `vmulh`, `vmulhr`, `vmla` | R 16 by 16 multipliers; L; U, 2 to 3 cycles, pipelined | 16 products a cycle; `vmla` removes a dependency | `vmul`, `vmla`, `vmulh` **C**; `vmulhr` **P/I** |
| `vdot.b`, `vdot.w` | N for byte multipliers (37,000), R for `.w`; L; U | 32 byte products a cycle | **P** (partial reduction) |
| `vdacc` | R `dot4` array + sum tree; **reduction tree depth log2 of the strip** | removes the strip-to-strip dependency of a lane accumulator: the sum tree has no loop-carried dependency but the scalar register, which adds one 64-bit add a strip (1 cycle) | **P** |
| `vacc`, `vmaxacc`, `vminacc` | R tree (6,000 E); latency about 4 cycles for a 16-lane tree; **the scalar accumulate is a loop-carried chain of 1 add a strip** | a serial accumulate in lanes would be one add a cycle with no tree, and one reduction at the end: cheaper tree-wise, but needs a hidden accumulator across strips (the restart rule). **The tree in the strip is the right choice here** because it keeps the block stateless; it costs about 6,000 gates and 3 to 4 cycles of latency that a strip of 8 cycles or more hides | **C** (in-loop reduction, `-prefer-inloop-reductions`) |
| floating-point `vacc.f` | tree; **the order of the sum depends on the strip length** | results differ between implementations with different strips: a reproducibility hazard. A strictly sequential `vacc.f` would be exact and one lane a cycle. State the order in the manual (decision for the owner) | needs `reassoc` (the pass requires it) |
| `vsad` | R `vabd` + tree; L then tree | as `vacc` | **P** |
| `vfir` | R multipliers over 8 cycles; **local window network of 8 taps across lanes** (not a crossbar); halo re-read | 8 multiply-adds a lane in 8 cycles on 16 multipliers = 16 outputs per 8 cycles at 16 lanes: the filter is compute-bound, 2 outputs a cycle | **I** |
| `vtbl.b` | N small crossbar within 16 lanes, 10,000 to 12,000; G; U, 1 to 2 cycles | 32 lookups per strip in 1 to 2 cycles | **I** |
| `vceq`, `vcgt`, `vbsl` | R lane ALU (flags) + 3-input mux; L; U; 3 read ports exist | one cycle | **C** |
| `vcvt` | R on the fp lanes; L | as fp add | **C** |
| `vldx` gather (removed) | N, **X** (address generation per lane) | a lane a cycle; per-lane faults | **P** |
| tile, `vtfmopa` (removed) | N 260,000 to 665,000; **S** | 64 to 256 multiply-adds a cycle; but the prefill only | **I** |
| `gemm.f` (removed) | N 1.2 to 1.7 million; S | DMA-bound | **I** |

**On a small in-order core** (one strip a cycle, or a strip over several cycles on a narrower datapath, "chime"): every lane word is a fixed latency, one micro-operation, so the block runs as a short software pipeline without scoreboarding of variable-latency operations. The instructions that break this are the gather (a variable number of cache accesses and faults), the strided load (one access per lane), and `vfir` (8 cycles). The proposal adds **no new variable-latency instruction**: `vtbl` is 1 to 2 cycles and fixed. On a larger out-of-order core the same instructions are renamed as ordinary vector micro-operations; the fusions help most there because they shorten dependency chains (`vmla` removes the multiply-to-add chain, the rounding store removes three).

**Where more lanes do not help** (E, assumptions stated in `vec-cost-benefit.md` section 1: 3 GHz, 50 to 100 GB/s): a streaming kernel such as `fmac`, `mix16`, `prep`, `blend` moves 3 bytes for each element and is memory-bound: 16 to 32 bytes a cycle at the first-level cache, 17 to 33 bytes a cycle from memory; a strip of 256 bits already saturates the port. `q8dot` at 2 bytes a multiply-add from memory is bound at 8 to 16 multiply-adds a cycle, which `vdacc.b` at 32 per cycle exceeds: for a model larger than the cache more lanes are useless and the work saved is the instruction count and the energy of fetching them. The filters, transforms and dot products on data in cache are compute-bound and are where the lanes and the fusions pay.

### 6.1 The cheapest tweaks that make common code optimal by construction, ranked

Each: what it buys, and the class of change. **Free** = a different spelling or a rule, no hardware; **little** = a few thousand gates on an existing datapath; **architecture** = changes state, the register model or the strip rule.

| # | tweak | what it buys | class |
|---|---|---|---|
| 1 | the rounding average, a saturating-narrowing store with a rounding shift, and the Q15 rounding multiply as the canonical pixel operations (`vavg`, `vsts ... #sh`, `vmulhr`) | the three idioms that dav1d, FFmpeg and libyuv write in every pixel kernel become one instruction each: 3 to 1, 3 to 1, 3 to 1 (E, section 4.4); a 17 to 40% cut in the block for the filter and blend kernels | little (1,000 to 4,000 gates each; the multiplier, shifter and adder exist) |
| 2 | the dot product as a reduction into a scalar register (`vdacc`, `vsad`) rather than into lanes | keeps the strip at 32 byte lanes: 5 times fewer instructions for the compiled `q8dot`; no accumulator, no restart rule; the strip-to-strip dependency is one scalar add | free in silicon (the tree exists), new words |
| 3 | the existing store-narrow and load-widen as the **only** place where lane widths change (no in-register widen) | the lane type of a register is fixed for its life, so hardware needs no per-register type state and the assembler can check it (errata 168); the cost is a store and a load where a mid-block narrow would be wanted | free (a rule; already so) |
| 4 | **uniform latencies**: every lane word one or two cycles, `vmul` family three, the tree reductions four; no word of variable latency in the family | the block pipelines like a short loop on a small core; no scoreboard | free (a rule for the implementer, and for the next additions); removing the gather and the tile makes it true |
| 5 | **`vmla` with a vector operand and `vfma` as the only multiply-accumulate shapes** (no separate widening MAC: the load widens) | the multiply-to-add dependency is gone and one fused shape is canonical for `LoopVectorize` | free (an operand form) |
| 6 | `vtbl.b` in groups of 16 lanes (the `pshufb` shape) | makes lookup tables and constant shuffles one fixed-latency instruction; no crossbar across the strip; independent of the strip length | little (10,000 to 12,000 gates), the largest of the list |
| 7 | remove what needs a new network or a new unit: gather, tile, `gemm.f` | the family becomes lane-local except `vtbl` (16 lanes), `vlseg` (memory path) and `vfir` (a window of 8) | **architecture** only in the sense of removing; saves 1.2 to 1.7 million gates (E) |
| 8 | decide the order of the floating-point reduction (`vacc.f`) in the manual | reproducibility across implementations with different strips; strict order is slower, a tree is faster | free (a rule); a decision for the owner |
| 9 | a rule that `vfir`'s halo is re-read from memory at the start of each strip | the one instruction with strip-to-strip data needs no hidden state | free (a rule in `vec-isa.md`; `vec-isa.md` section 2 says the neighbours "are the last and the first elements of the previous and next strip", which is state if read as a register) |
| 10 | accumulators across strips (`vclr`, `vfmab`) only in a bounded block | the micro-kernel remains, restart from entry loses at most the block so far | **architecture** (the one hidden state); keep last, or drop |

What would change the architecture: any state across strips (accumulators, tiles), predicate or mask registers as a second register class, an in-register lane-type change (the strip rule of errata 168 would have to say how many lanes a narrowed register has), and the first-fault load. None of them is in the proposal except the existing `vclr`.

## 7. Decided by evidence, judgement, and not verified

**Decided by evidence (counted or run here):**

* the classes that carry the hand-written code of the seven projects (section 3.2, 3.3) and which of them our family lacks (section 4.1);
* that no ISA surveyed has a whole-GEMM instruction, and that the tile is used by linear-algebra libraries only (section 3.5: 16 SME files in OpenBLAS, 21 MMA files, AMX in llama.cpp and one OpenBLAS file; U for the claim "no ISA", since a manual was not read);
* that gather is 0.0 to 0.3% of assembly (and 3.1% of one RVV file where it stands for a lookup), and that no compiler vectorized the two gather kernels (section 3.4, `vector-usage.md`);
* the instructions that clang 19 does and does not fuse (section 3.4);
* the `vsetvli` overhead (15.7% of RVV assembly);
* the 22 base mnemonics unused by the 31 compiled kernels (`vector-usage.md`) and the 7 that stay unused in the surveyed real code.

**Judgement (the assistant's, for the owner to take or leave):**

* removing the tile and `gemm.f` outright: the evidence says libraries use tiles, the owner's criteria (silicon, state, restart) say the cost is not justified before a GPU; this is a decision about the "gpu-lite" goal of errata 155, not a measurement;
* keeping `vfmab`/`vclr` and the 16 registers: the micro-kernel is 3.5 times better on instruction count for GEMM than a dot per output, but needs the one piece of hidden state that crosses strips;
* removing the gather in favour of `vtbl.b` (section 4.3);
* the saturating semantics of `vmulhr` (differs from `pmulhrsw` in one input), the group-of-16 semantics of `vtbl.b`;
* the order of the second wave and the exact word lists; which lane types are cut (section 4.3);
* whether a nested block per 32 elements (llama.cpp's q8_0 layout) is acceptable: it needs a measurement on a simulator that models the cost of `vec`/`vend`;
* the silicon of every new block: estimates (E), not synthesised.

**Not verified:** the manuals (section 1); semantics of all newer extensions (Zvqdotq, Zvabd, Zvzip, SME2.2, MOP4, SVE2.2, LUTI behaviour); that clang 19 vs 21 differ in the dot-product rows; the instruction counts of the proposed forms (nothing was assembled: the new words are not in `as64`); the effect on the 31 kernels beyond the five named (not run); real execution counts (all counts are of source text); POWER, MSA and HVX frequency beyond FFmpeg's MSA and VSX and OpenBLAS's VSX intrinsics; s390x frequency (ggml's file only); `vtbl` as a replacement for `vfir`'s permutes (not examined); the claim that the transform kernels are the weakest case (E).

[now: answered. (1) strict or tree order for `vacc.f`: neither; a canonical order of 16-byte chunks chained through the register (errata 174, `vec-isa.md` 8.5); (2) the accumulators `vclr` and `vfmab` are kept, ranked last, with a 16-byte strip and `vfin` (errata 172, 175); (3) the second wave was taken (errata 171); (4) early-exit loops: not covered.] **Open questions for the owner as they stood** (not answered by the data): (1) strict or tree order for `vacc.f`; (2) keep the accumulators (`vclr`, `vfmab`) or take the family fully stateless; (3) whether the second wave (compare and select, conversion) is wanted before a measurement on branchy kernels; (4) early-exit loops (`strlen`, `memchr`, `compare256`): the data here does not cover them.

## 8. Reproduce

    git clone --depth 1 <repo> ...                                         # the seven clones of section 1, one every 20 seconds
    python3 -I tools/arch-compare/vsurvey-freq.py SRCROOT freq.tsv           # counts the words and intrinsics (text only)
    python3 -I tools/arch-compare/vsurvey-report.py freq.tsv                  # the class table, one column for each (ISA, project, kind)
    python3 -I tools/arch-compare/vsurvey-top.py freq.tsv x86 asm 8           # the most frequent words of each class
    python3 -I tools/arch-compare/vsurvey-memop.py SRCROOT                    # memory operands in x86 vector arithmetic
    tools/arch-compare/vsurvey-kernels.sh OUTDIR                              # 20 loops, 13 targets, clang
    python3 -I tools/arch-compare/vsurvey-kmn.py OUTDIR/avx2.s sad dot_i8 ... # the mnemonics of a function

The existence checks of section 2.1 are single assembler lines of the form `echo 'sqrdmulh v0.8h, v1.8h, v2.8h' | clang --target=aarch64-linux-gnu -march=armv9-a -x assembler -c -o /dev/null -`.
