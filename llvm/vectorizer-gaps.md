# Why LoopVectorize does not vectorise a loop for the pdp64, and what instruction would let it

Input to the review of the vector instruction set (the survey of other vector ISAs is `docs/encoding-work/vec-survey.md`). All of it is measured with LLVM 21.1.8's own `LoopVectorize`
and the pdp64 `TargetTransformInfo` (`llvm/target/PDP64/PDP64TargetTransformInfo.cpp`), which says what the ISA has and costs what it lacks as Invalid, so **each "no instruction for
vector X" below is a recipe LoopVectorize refused to form because of the cost model, i.e. because the ISA has no word for it** (the cost model is only as true as its author's reading of
`vec-isa.md` and `common/pdp64exec_vec.inc`; what it treats as missing is listed at the end). Nothing here was run on hardware: `sim64` only.

How it was collected: `llvm/bench/gaps.py` compiles `llvm/bench/gaps.c` (one small loop for each cause, 76 functions: 56 as before and 20 for the words of waves 1 and 2) with clang (no LLVM pass), runs `opt -passes='default<O2>' -mtriple=pdp64-unknown-elf`
with `-debug-only=loop-vectorize` (the remark pass `-pass-remarks-analysis` asserts inside LLVM 21.1.8's `emitInvalidCostRemarks` on some recipes, so the debug output is parsed instead), then `llc
-pdp64-vecloop-verbose` for the lowering. The 31 kernels of the benchmark (`llvm/bench/bench.py`) were read the same way. Two columns matter: **LoopVectorize** (did it vectorise; if not why) and
**lowering** (did `PDP64VecLoop` make a `vec` block of the vector loop; if not, the loop stays correct but is scalarised by the type legaliser, no faster than the scalar loop).

## The classes, with the missing instruction

| # | class (what LoopVectorize says) | loops that show it | what the ISA would need |
|---|---|---|---|
| 1 | **a compare that makes a mask, and select / blend / masked load and store** (was: `icmp`, `fcmp`, `select` Invalid) | **now vectorised and lowered** (`vceq`/`vcgt`/`vcgtu` + `vbsl`): `g_select_const`, `g_count`, `g_cmp_val`, `g_if_else`, `g_thresh_arms`, `g_fmaxnan`, `k_thresh`, `k_maskblend`, `k_relu`, `k_softmax` first loop. **Still not**: `g_cond_store`, `g_thresh_cond`, `g_cmp_wide_arms` (a load or store that only happens under the condition: LoopVectorize needs `llvm.masked.load/store`, `isLegalMaskedLoad/Store` is false, and the ISA has no masked access: a masked store is `vbsl` with a read-modify-write that touches the lanes the program does not, and has no fault rule yet, `vec-isa.md` section 7 "not decided"), `g_clamp_u8` / `k_clamp8` (a clamp to 0..255 written as nested `?:` into a byte: InstCombine leaves three blocks and a `trunc nuw` of the loaded int that is a select arm; the cost of a `trunc` of a computed value is Invalid, and the arms would be bytes under a 32-bit mask; the same clamp with a rounding shift in front, `k_clampr`, becomes `smax`/`umin` and is a block) | a mask on `vld`/`vst` with fault suppression (masked and fault-only-first loads) for the conditional accesses; for `k_clamp8` a way to say a narrowing move (`vtrunc`) or, as work, a select whose arms are the low bytes of 32-bit lanes (the lowering widens the arms of a select whose mask is wider only when they are loads or constants: `g_thresh_arms`). Compare and select are one word each: the cost is one `vcgt`/`vceq` and one `vbsl`; `<=`, `>=`, `!=` and the unordered predicates are the negation of those (the arms swap: no instruction), and only `<=`, `>=`, `one`, `ueq` of floating point without `nnan` need a second compare and a `vor`. `vcgtu.f`, a 64-bit compare (`g_cmp64`) and a compare of `double` are not in the ISA. |
| 2 | **division and square root** (`sdiv`, `udiv`, `urem`, `fdiv`, `sqrt` Invalid) | `g_idiv`, `g_idiv_const`, `g_irem`, `g_fdiv`, `g_fdiv_inv`, `g_sqrt`, `k_rmsnorm` second loop (`x / sqrt(..)`), `k_softmax` third loop (`x[i] / s`) | `vdiv.f/d` and `vsqrt.f/d` (the scalar `fdiv`/`fsqrt` exist); for integers `vdiv/vdivu/vrem/vremu` or, for division by a constant (what LLVM makes of `/ 7`), the high multiply `vmulh.l/vmulhu.l` (`mulh`/`mulhu` exist as scalar instructions). A reciprocal-and-multiply by an invariant (`x / d` -> `x * (1/d)` under `arcp`) is a choice of LLVM or the front end and is not made for this target. |
| 3 | **special functions and library calls** (`Found a non-intrinsic callsite`) | `k_ssm`, `k_softmax` second loop (`expf`), `g_exp` | `vexp`, `vlog`, `vsin`... (under study in `vec-isa.md`). Also LLVM must know the library: with the `pdp64-unknown-elf` triple `TargetLibraryInfo` knows no libc function, so `abs`, `sqrtf`, `fabsf` are ordinary calls unless clang (builtins on) has already turned them into intrinsics. The benchmark kernels are compiled with builtins on; with `-fno-builtin` (as in `check.sh`) `k_sad`'s `abs` is a call that blocks vectorisation. |
| 4 | **bit operations** (`ctpop`, `ctlz`, `bswap`, `fshl` with two different inputs) | `g_popcnt`, `g_clz`, `g_bswap`, `g_call` (`ctz`) | `vpopcnt`, `vclz`, `vctz`, `vbswap`, `vbitrev` (the scalar `popcnt clz ctz bswap bitrev` exist). A rotate by a constant is handled (three lane instructions, `g_rotl`); a `vrotl` word would make it one. |
| 5 | **lane type conversions of register values** | **now vectorised and lowered for 32-bit lanes**: `vcvt.l.f`/`lu.f`/`f.l`/`f.lu`: `g_i2f`, `g_f2i`, `g_f2u`, `g_u2f`, `g_u8_to_f` (a byte or halfword is loaded as a 32-bit lane, `vld.bu.l`, and then converted), `k_i2f`, `k_dequant`, `k_quant`. **Still not**: `g_f2i64`, `g_d2i` (64-bit integer lanes and `double` have no `vcvt`), `g_q4dot`, `k_q4dot` (LoopVectorize computes `(w & 15) - 8` in byte lanes and widens the result: a `zext` of an `and`; the pass cannot turn that into lanes) | `vcvt` for `double` and 64-bit lanes; in-register widening/narrowing (`vext`/`vtrunc`) between lane widths. For `k_q4dot` the pass could also push the extension back to the load (`zext(and(x, 15))` = `and(zext x, 15)`): work, not ISA. A float to integer conversion that overflows is poison in IR, so the saturating word is a legal refinement (the scalar `(int)x` is `fcvtsd` + `fcvtdq`, a 64-bit conversion whose low 32 bits wrap: it does NOT saturate at 32 bits, so scalar and block differ for out-of-range inputs: `tests/vec/w2_cvt_sat.c`; one `fcvtsl` would be the scalar instruction that agrees with the lane). |
| 6 | **gather / scatter / scatter-add** (`Can't vectorize due to memory conflicts`) | `g_gather`, `g_scatter`, `g_hist`, `k_hist` | LoopVectorize refuses before any cost: an access whose address comes from a load has no range, so no run-time overlap test can be made (`c[i] = a[idx[i]]` with `c` and `a` possibly the same array; `restrict` would remove that). **Gather exists** (`vldx`) but `isLegalMaskedGather` is false because the lowering does not recognise `llvm.masked.gather` yet (work, not ISA). **Scatter does not exist** (`vstx`), nor scatter-add with conflict handling (`vaddx`, under study). |
| 7 | **strided access with gaps** (cost "not beneficial"; an interleave group with a gap is Invalid) | `g_stride2`, `g_stride4_gap`, `k_gray` (3 of 4 fields of rgba) | `vldt`/`vstt` exist and are what the scalar-loop recogniser uses (k_gray: 1,290 instructions against 13,009 scalar). LoopVectorize 21 cannot emit a strided load (only a gather or an interleave group; a group with a gap needs a mask or reads past the end of the array). Needs LLVM's strided-access support in VPlan (22 or later, `isLegalStridedLoadStore`), or a `vlseg` that loads only some fields (a field mask), or the gather recogniser for constant-step pointer vectors. Not an ISA hole. |
| 8 | **reversed access** | `g_reverse` | a lane reverse (`vrev`) or a stream that moves backwards (`vldt` takes a positive stride only). |
| 9 | **reductions other than sum, maximum, minimum** | `g_prod`, `g_or`, `g_xor`, `g_and`, `g_argmax`, strict floating-point sum, NaN-aware `fmaxf` without fast-math | `vmulacc`, `vandacc`/`voracc`/`vxoracc` (the accumulate family has `vacc`, `vmaxacc`, `vminacc` only), `vargmax`/`vargmin` (value and index), an ordered `vacc.f` (only a scalar loop is exact today: `vacc` reassociates, so floating-point sums need `reassoc`), `vmaxacc.f` with the NaN rule of `fmaxf`. |
| 10 | **a loop-carried dependence** | `g_prefix`, `g_carry` (`a[i+1] = a[i] + 1`, `tests/vec/lv_alias.c`) | a scan (`vscan.add`) or a strip of one element for such a block. LoopVectorize refuses (distance 1). A distance between 1 and the strip (`a[i+4] = a[i]` with a strip of 8 words) is accepted by LoopVectorize for VF 4 but would be wrong for a strip of 8: the lowering rejects it (the loop stays legalised scalar code); a `vlen`-limited strip would serve. |
| 11 | **loops that are not counted** | `g_find`, `g_strlen`, `g_list` | an early-exit vector loop needs fault-only-first loads (`vldff`) and a first-match (`vfirst`); pointer chasing cannot be vectorised by a vector ISA. |
| 12 | **register pressure, windows** (`uses too many registers`) | `k_put8h`, `g_window8` (an 8-tap filter written as eight shifted loads and eight invariant coefficients), `g_q4dot` | The machine has 16 hidden registers; LoopVectorize counts a splatted invariant as a live vector register (here a splat is a scalar operand), so the cost model reports 32 registers and the lowering checks the real 16. For the window itself `vfir` exists; nothing recognises it (LoopVectorize cannot produce it; the scalar-loop recogniser makes eight shifted streams, 3,401 instructions against 40,043). |

## What the cost model tells LoopVectorize (so that the table is the machine's, not LLVM's)

* **Legal**: lanes b w l q f d (no half, no i128; `<N x i1>` only as the mask of a compare); 16 registers of 256 bits (reported as 32 because splats count); VF up to 256 / the narrowest lane after type narrowing; lane `add sub and or xor shl lshr ashr`
  (integers), `mul` (b w l: no `vmul.q` since wave 1; a 64-bit product of two extended bytes or halfwords that is a step of a sum is legal, it becomes `vdacc`), `fadd fsub fmul fneg` (float), `smin smax umin umax` and `abs` (b w l: wave 1 removed the `.q` words; `abs` as `vabd` of a difference), `sadd.sat ssub.sat uadd.sat usub.sat` (b, w, l), `fma`/`fmuladd`, `maxnum`/`minnum` with `nnan`, a rotate;
  **wave 2**: vector `icmp` (b w l) and `fcmp` (f) with every predicate but `ord`/`uno` costing one strip (three for the ones that need a second compare), `select` (b w l f) one strip, `and or xor` of masks one, `zext`/`sext` of a mask, `sitofp`/`uitofp` of 8, 16, 32-bit integers to float and `fptosi`/`fptoui` float to i32 (one strip each);
  consecutive loads and stores (one vector instruction for each 256 bits); extensions and truncations only as part of a load or a store; interleaved groups of 2, 3, 4 fields with every field used
  (`vlseg`/`vsseg`); reductions `add`, `fadd` (with `reassoc`), `smax smin umax umin` (up to 32-bit lanes), `fmax fmin` (with `nnan`).
* **Invalid** (the VF that needs it is dropped): masked load/store, gather, scatter, strided, `sdiv udiv srem urem fdiv frem`, `sqrt` and every other intrinsic, conversions of 64-bit lanes and of `double`, a compare or select of 64-bit lanes or `double`,
  extension or truncation of a computed value, a product/and/or/xor reduction (asked for as an in-loop reduction, whose cost is Invalid).
* **Expensive but legal** (correct but slow if chosen): `insertelement`/`extractelement` (64); every shuffle that is not a broadcast of an invariant (1000: not Invalid, because an Invalid cost compares as
  0 in passes that only compare totals, and VectorCombine then merged three splat products into one `<4 x float>` operation plus a shuffle of splats that no block can run); a vector of fewer than four lanes (x32).
* **Policy**: `preferPredicateOverEpilogue` false and `hasActiveVectorLength` false (the block takes any trip count: no tail folding, no `vlen`), `getMaxInterleaveFactor` 1, no epilogue vectorisation, no runtime or
  partial unrolling. SLP is off in effect (`getMaximumVF` 1: a vector value outside a loop has no instruction here; two horizontal-reduction trees are still built by SLP and scalarised again).

## The result for each loop of `llvm/bench/gaps.c` (generated: `llvm/bench/gaps.py`, with `-ffast-math`; `--strict` for the ordered reductions)

| function | LoopVectorize | lowering |
|---|---|---|
| `g_axpy` | vectorised, VF 8 | 1 vec block(s) |
| `g_sum32` | vectorised, VF 8 | 1 vec block(s) |
| `g_max2` | vectorised, VF 8 | 1 vec block(s) |
| `g_neg` | vectorised, VF 8 | 1 vec block(s) |
| `g_widen_mul` | vectorised, VF 16 | 1 vec block(s) |
| `g_shiftv` | vectorised, VF 8 | 1 vec block(s) |
| `g_clamp_u8` | no instruction for vector `trunc`; too many live vectors; not beneficial | not a single-block loop with a preheader and one exit |
| `g_select_const` | vectorised, VF 8 | 1 vec block(s) |
| `g_cond_store` | not beneficial | not a single-block loop with a preheader and one exit |
| `g_count` | vectorised, VF 8 | 1 vec block(s) |
| `g_cmp_val` | vectorised, VF 16 | 1 vec block(s) |
| `g_argmax` | Not vectorizing: Found an unidentified PHI   %.01114 = phi i32 [ %4, %.lr.ph.preheader ], [ %.112, %.lr.ph ]; Can't vectorize the instructions or CFG; Not vectorizing: Cannot prove legality. | - |
| `g_find` | Not vectorizing: Loop may fault.; Not vectorizing: Cannot prove legality. | not a single-block loop with a preheader and one exit |
| `g_if_else` | vectorised, VF 8 | 1 vec block(s) |
| `g_fmax_nan` | vectorised, VF 8 | 1 vec block(s) |
| `g_idiv` | no instruction for vector `sdiv`; not beneficial | - |
| `g_idiv_const` | no instruction for vector `sdiv`; not beneficial | - |
| `g_irem` | no instruction for vector `urem`; not beneficial | - |
| `g_fdiv` | no instruction for vector `fdiv`; not beneficial | - |
| `g_fdiv_inv` | no instruction for vector `fdiv`; not beneficial | - |
| `g_sqrt` | not beneficial | - |
| `g_exp` | not beneficial | - |
| `g_fabs` | not beneficial | - |
| `g_popcnt` | not beneficial | - |
| `g_clz` | not beneficial | - |
| `g_bswap` | not beneficial | - |
| `g_mulh` | no instruction for vector `mul`; not beneficial | - |
| `g_rotl` | vectorised, VF 8 | 1 vec block(s) |
| `g_i2f` | vectorised, VF 8 | 1 vec block(s) |
| `g_f2i` | vectorised, VF 8 | 1 vec block(s) |
| `g_f2d` | vectorised, VF 8 | 1 vec block(s) |
| `g_u8_to_f` | vectorised, VF 32 | 1 vec block(s) |
| `g_q4` | vectorised, VF 16 | 1 vec block(s) |
| `g_q4dot` | no instruction for vector `zext`; too many live vectors; not beneficial | - |
| `g_gather` | Can't vectorize due to memory conflicts; Not vectorizing: Cannot prove legality. | - |
| `g_scatter` | Can't vectorize due to memory conflicts; Not vectorizing: Cannot prove legality. | - |
| `g_hist` | Can't vectorize due to memory conflicts; Not vectorizing: Cannot prove legality. | - |
| `g_stride2` | not beneficial | - |
| `g_stride3` | vectorised, VF 8 | 1 vec block(s) |
| `g_stride4_gap` | too many live vectors; not beneficial | - |
| `g_reverse` | not beneficial | - |
| `g_ahead` | vectorised, VF 8 | 1 vec block(s) |
| `g_prefix` | Can't vectorize due to memory conflicts; Not vectorizing: Cannot prove legality. | - |
| `g_window8` | vectorised, VF 8 | an access that is not consecutive or strided forwards |
| `g_matvec_row` | vectorised, VF 8 | 1 vec block(s) |
| `g_prod` | no instruction for vector `reduction (no accumulating instruction)`; not beneficial | - |
| `g_or` | no instruction for vector `reduction (no accumulating instruction)`; not beneficial | - |
| `g_xor` | no instruction for vector `reduction (no accumulating instruction)`; not beneficial | - |
| `g_and` | no instruction for vector `reduction (no accumulating instruction)`; not beneficial | - |
| `g_sum64_of32` | vectorised, VF 8 | 1 vec block(s) |
| `g_fsum` | vectorised, VF 8 | 1 vec block(s) |
| `g_sad8` | vectorised, VF 8 | 1 vec block(s) |
| `g_strlen` | (the loop vectoriser never saw it: removed or rewritten by an earlier pass) | - |
| `g_list` | Not vectorizing: Found an unidentified PHI   %.046 = phi ptr [ %5, %.lr.ph ], [ %0, %.lr.ph.preheader ]; Can't vectorize the instructions or CFG; Not vectorizing: Cannot prove legality. | - |
| `g_call` | not beneficial | - |
| `g_inner3` | not beneficial | - |
| `g_avg_u8` | vectorised, VF 16 | 1 vec block(s) |
| `g_mulh16` | vectorised, VF 16 | 1 vec block(s) |
| `g_q15` | vectorised, VF 16 | 1 vec block(s) |
| `g_dot8` | vectorised, VF 8 | 1 vec block(s) |
| `g_dot16` | vectorised, VF 8 | 1 vec block(s) |
| `g_rsh16` | vectorised, VF 16 | 1 vec block(s) |
| `g_rsh32_u` | vectorised, VF 8 | 1 vec block(s) |
| `g_qround` | vectorised, VF 32 | 1 vec block(s) |
| `g_mla` | vectorised, VF 8 | 1 vec block(s) |
| `g_thresh_arms` | vectorised, VF 8 | 1 vec block(s) |
| `g_thresh_cond` | no instruction for vector `select`; not beneficial | - |
| `g_lut16` | Can't vectorize due to memory conflicts; Not vectorizing: Cannot prove legality. | - |
| `g_fmaxnan` | vectorised, VF 8 | 1 vec block(s) |
| `g_f2u` | vectorised, VF 8 | 1 vec block(s) |
| `g_u2f` | vectorised, VF 8 | 1 vec block(s) |
| `g_f2i64` | no instruction for vector `fptosi`; not beneficial | - |
| `g_d2i` | no instruction for vector `fptosi`; not beneficial | - |
| `g_cmp64` | no instruction for vector `icmp`; not beneficial | - |
| `g_cmp_wide_arms` | no instruction for vector `select`; not beneficial | - |
| `g_cmp_wide_arms2` | vectorised, VF 32 | 1 vec block(s) |

The functions whose result differs without fast-math (`gaps.py --strict`): `g_fmax_nan` (the NaN-aware maximum becomes an any-of select: not vectorised), `g_sqrt` and `g_exp` (calls instead of intrinsics), `g_fsum` and `g_matvec_row` (an ordered floating-point sum: LoopVectorize does not touch it), `g_inner3`.

## The kernels of the benchmark that LoopVectorize + the lowering do not turn into blocks (6 of the 46 have no block: 5 of the 31 old ones and `k_clamp8` of the 15 new; 40 have one or more; `k_rmsnorm` has a block for one of its two loops)

| kernel | LoopVectorize | class above |
|---|---|---|
| `k_put8h` | vectorisation possible but not beneficial: too many live vectors | 12 (`vfir`) |
| `k_hist` | memory conflicts (a gather of the bin, a scatter-add) | 6 |
| `k_ssm` | a call of `expf` | 3 |
| `k_q4dot` | vectorised at VF 8, but the pass cannot make the widened `and` into lanes: scalarised (7,258 instructions, scalar 7,014) | 5 |
| `k_gray` | strided access with a gap (3 of 4 fields): not beneficial | 7 |
| `k_clamp8` | a clamp into a byte written as nested `?:`: three blocks left by InstCombine, `trunc` of a computed value Invalid (the same clamp after a rounding shift, `k_clampr`, is a block) | 1 |
| `k_rmsnorm` | first loop (sum of squares) a block; second loop an `fdiv` | 2 |

Changed since the stage 2b run of this table (before: 6 of the 31 without a block, 25 with): `k_softmax` now has a block (its maximum loop, `x[i] > m ? x[i] : m`, is compare + select, the one that was Invalid; the exponentials stay a call and the scale an `fdiv`).

## What waves 1 and 2 changed in this table (the run that selects the new words)

* Class 1 (mask and select) and class 5 (conversions) were the loops the wave 2 words were meant for. Of the 12 loops they named, 8 are now blocks (`g_select_const`, `g_count`, `g_cmp_val`, `g_if_else`, `g_i2f`, `g_f2i`, `g_u8_to_f`, and the select of `k_softmax`'s maximum); 4 are not: a masked store (`g_cond_store`), the nested-`?:` clamp (`g_clamp_u8`: a `trunc` of a computed value under a select) and the widening of a computed byte (`g_q4dot`, `k_q4dot`).
* New idiom loops (20 in `gaps.c`): the 14 that the words select are blocks (`g_avg_u8`, `g_mulh16`, `g_q15`, `g_dot8`, `g_dot16`, `g_rsh16`, `g_rsh32_u` (as plain `vadd`/`vshr`: the sum wraps in C, so `vshrr.l` would be wrong), `g_qround`, `g_mla`, `g_thresh_arms`, `g_fmaxnan`, `g_f2u`, `g_u2f`, `g_cmp_wide_arms2`); `g_thresh_cond` (conditional loads), `g_cmp_wide_arms` (conditional loads, mask narrower than the arms), `g_f2i64`, `g_d2i`, `g_cmp64` (no 64-bit lane in `vcvt`, `vcgt`) and `g_lut16` (a table lookup is a gather in IR: `vtbl.b` is unreachable) are not.
* Two corrections to the cost model that came out of this run, not of the new words: wave 1 removed `vmul.q`, `vmin.q`, `vmax.q`, `vminu.q`, `vmaxu.q`, `vabd.q`, but the cost model still called a 64-bit multiply, minimum, maximum and absolute value legal, so LoopVectorize vectorised `g_mulh` (`(uint64_t)a * b >> 32`) and the lowering then had no word (`the grammar has no vmul.q`) and left it as scalarised vector code: the 64-bit forms are Invalid now (`g_mulh` stays scalar), except a 64-bit product of two extended bytes or halfwords that is a step of a sum (it is `vdacc`, no multiply). `fneg` of a vector had no cost (Invalid) although `vneg` exists: legal now (`k_neg`).
* A vector loop with a constant trip count that is a multiple of VF is not followed by LoopVectorize's `middle.block` but directly by whatever came after (the latch of an outer loop: the inner loop of `k_q8blk`, 32 bytes of each block); the lowering took that for a shape it did not know. It takes it now (`k_q8blk`: 31 blocks of one `vdacc.b` each).
