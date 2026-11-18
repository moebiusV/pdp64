# Why LoopVectorize does not vectorise a loop for the pdp64, and what instruction would let it

Input to the review of the vector instruction set (the survey of other vector ISAs is `docs/encoding-work/vec-survey.md`). All of it is measured with LLVM 21.1.8's own `LoopVectorize`
and the pdp64 `TargetTransformInfo` (`llvm/target/PDP64/PDP64TargetTransformInfo.cpp`), which says what the ISA has and costs what it lacks as Invalid, so **each "no instruction for
vector X" below is a recipe LoopVectorize refused to form because of the cost model, i.e. because the ISA has no word for it** (the cost model is only as true as its author's reading of
`vec-isa.md` and `common/pdp64exec_vec.inc`; what it treats as missing is listed at the end). Nothing here was run on hardware: `sim64` only.

How it was collected: `llvm/bench/gaps.py` compiles `llvm/bench/gaps.c` (one small loop for each cause, 59 functions) with clang (no LLVM pass), runs `opt -passes='default<O2>' -mtriple=pdp64-unknown-elf`
with `-debug-only=loop-vectorize` (the remark pass `-pass-remarks-analysis` asserts inside LLVM 21.1.8's `emitInvalidCostRemarks` on some recipes, so the debug output is parsed instead), then `llc
-pdp64-vecloop-verbose` for the lowering. The 31 kernels of the benchmark (`llvm/bench/bench.py`) were read the same way. Two columns matter: **LoopVectorize** (did it vectorise; if not why) and
**lowering** (did `PDP64VecLoop` make a `vec` block of the vector loop; if not, the loop stays correct but is scalarised by the type legaliser, no faster than the scalar loop).

## The classes, with the missing instruction

| # | class (what LoopVectorize says) | loops that show it | what the ISA would need |
|---|---|---|---|
| 1 | **a compare that makes a mask, and select / blend / masked store** (`icmp`, `fcmp`, `select` Invalid; `isLegalMaskedLoad/Store` false) | `g_select_const`, `g_cond_store`, `g_count`, `g_cmp_val`, `g_if_else`, `g_clamp_u8` (a clamp written as nested `?:` that InstCombine does not turn into `smin`/`smax`), `k_softmax` first loop (the maximum as compare+select: the select carries `nsz` but not `nnan`, so LoopVectorize does not see an fmax reduction) | `vcmp.<cc> vM, vA, vB\|Rs\|#imm` into a one-bit-per-lane mask (or a predicate register), `vsel vD, vM, vA, vB`, a mask on `vld`/`vst` (masked and fault-suppressed loads), a mask-to-count (`vpopc`) for `g_count`. This is the largest class: every `if` in a loop body. `vmin`/`vmax`/`vabd`/`vadds` already cover the clamp and absolute-value forms. |
| 2 | **division and square root** (`sdiv`, `udiv`, `urem`, `fdiv`, `sqrt` Invalid) | `g_idiv`, `g_idiv_const`, `g_irem`, `g_fdiv`, `g_fdiv_inv`, `g_sqrt`, `k_rmsnorm` second loop (`x / sqrt(..)`), `k_softmax` third loop (`x[i] / s`) | `vdiv.f/d` and `vsqrt.f/d` (the scalar `fdiv`/`fsqrt` exist); for integers `vdiv/vdivu/vrem/vremu` or, for division by a constant (what LLVM makes of `/ 7`), the high multiply `vmulh.l/vmulhu.l` (`mulh`/`mulhu` exist as scalar instructions). A reciprocal-and-multiply by an invariant (`x / d` -> `x * (1/d)` under `arcp`) is a choice of LLVM or the front end and is not made for this target. |
| 3 | **special functions and library calls** (`Found a non-intrinsic callsite`) | `k_ssm`, `k_softmax` second loop (`expf`), `g_exp` | `vexp`, `vlog`, `vsin`... (under study in `vec-isa.md`). Also LLVM must know the library: with the `pdp64-unknown-elf` triple `TargetLibraryInfo` knows no libc function, so `abs`, `sqrtf`, `fabsf` are ordinary calls unless clang (builtins on) has already turned them into intrinsics. The benchmark kernels are compiled with builtins on; with `-fno-builtin` (as in `check.sh`) `k_sad`'s `abs` is a call that blocks vectorisation. |
| 4 | **bit operations** (`ctpop`, `ctlz`, `bswap`, `fshl` with two different inputs) | `g_popcnt`, `g_clz`, `g_bswap`, `g_call` (`ctz`) | `vpopcnt`, `vclz`, `vctz`, `vbswap`, `vbitrev` (the scalar `popcnt clz ctz bswap bitrev` exist). A rotate by a constant is handled (three lane instructions, `g_rotl`); a `vrotl` word would make it one. |
| 5 | **lane type conversions of register values** (`sitofp`, `uitofp`, `fptosi`, `zext`/`trunc` of a computed value) | `g_i2f`, `g_f2i`, `g_u8_to_f`, `g_q4dot`, `k_q4dot` (LoopVectorize computes `(w & 15) - 8` in byte lanes and widens the result: a `zext` of an `and`; the pass cannot turn that into lanes), `g_cmp_val` | `vcvt.<from>.<to>` (int to float and back, signed and unsigned) and in-register widening/narrowing (`vext`/`vtrunc`) between lane widths. Today a lane type changes only inside `vld.<m>.<lane>`, `vst.<lane>.<m>`, `vsts` and `vacc.<src>.<acc>`; float to double on a load and back on a store (`vld.f.d`, `vst.d.f`) is used (`g_f2d`). For `k_q4dot` the pass could also push the extension back to the load (`zext(and(x, 15))` = `and(zext x, 15)`): work, not ISA. |
| 6 | **gather / scatter / scatter-add** (`Can't vectorize due to memory conflicts`) | `g_gather`, `g_scatter`, `g_hist`, `k_hist` | LoopVectorize refuses before any cost: an access whose address comes from a load has no range, so no run-time overlap test can be made (`c[i] = a[idx[i]]` with `c` and `a` possibly the same array; `restrict` would remove that). **Gather exists** (`vldx`) but `isLegalMaskedGather` is false because the lowering does not recognise `llvm.masked.gather` yet (work, not ISA). **Scatter does not exist** (`vstx`), nor scatter-add with conflict handling (`vaddx`, under study). |
| 7 | **strided access with gaps** (cost "not beneficial"; an interleave group with a gap is Invalid) | `g_stride2`, `g_stride4_gap`, `k_gray` (3 of 4 fields of rgba) | `vldt`/`vstt` exist and are what the scalar-loop recogniser uses (k_gray: 1,290 instructions against 13,009 scalar). LoopVectorize 21 cannot emit a strided load (only a gather or an interleave group; a group with a gap needs a mask or reads past the end of the array). Needs LLVM's strided-access support in VPlan (22 or later, `isLegalStridedLoadStore`), or a `vlseg` that loads only some fields (a field mask), or the gather recogniser for constant-step pointer vectors. Not an ISA hole. |
| 8 | **reversed access** | `g_reverse` | a lane reverse (`vrev`) or a stream that moves backwards (`vldt` takes a positive stride only). |
| 9 | **reductions other than sum, maximum, minimum** | `g_prod`, `g_or`, `g_xor`, `g_and`, `g_argmax`, strict floating-point sum, NaN-aware `fmaxf` without fast-math | `vmulacc`, `vandacc`/`voracc`/`vxoracc` (the accumulate family has `vacc`, `vmaxacc`, `vminacc` only), `vargmax`/`vargmin` (value and index), an ordered `vacc.f` (only a scalar loop is exact today: `vacc` reassociates, so floating-point sums need `reassoc`), `vmaxacc.f` with the NaN rule of `fmaxf`. |
| 10 | **a loop-carried dependence** | `g_prefix`, `g_carry` (`a[i+1] = a[i] + 1`, `tests/vec/lv_alias.c`) | a scan (`vscan.add`) or a strip of one element for such a block. LoopVectorize refuses (distance 1). A distance between 1 and the strip (`a[i+4] = a[i]` with a strip of 8 words) is accepted by LoopVectorize for VF 4 but would be wrong for a strip of 8: the lowering rejects it (the loop stays legalised scalar code); a `vlen`-limited strip would serve. |
| 11 | **loops that are not counted** | `g_find`, `g_strlen`, `g_list` | an early-exit vector loop needs fault-only-first loads (`vldff`) and a first-match (`vfirst`); pointer chasing cannot be vectorised by a vector ISA. |
| 12 | **register pressure, windows** (`uses too many registers`) | `k_put8h`, `g_window8` (an 8-tap filter written as eight shifted loads and eight invariant coefficients), `g_q4dot` | The machine has 16 hidden registers; LoopVectorize counts a splatted invariant as a live vector register (here a splat is a scalar operand), so the cost model reports 32 registers and the lowering checks the real 16. For the window itself `vfir` exists; nothing recognises it (LoopVectorize cannot produce it; the scalar-loop recogniser makes eight shifted streams, 3,401 instructions against 40,043). |

## What the cost model tells LoopVectorize (so that the table is the machine's, not LLVM's)

* **Legal**: lanes b w l q f d (no half, no i1, no i128); 16 registers of 256 bits (reported as 32 because splats count); VF up to 256 / the narrowest lane after type narrowing; lane `add sub mul and or xor shl lshr ashr`
  (integers), `fadd fsub fmul fneg` (float), `smin smax umin umax`, `abs` (as `vabd` of a difference), `sadd.sat ssub.sat uadd.sat usub.sat` (b, w, l), `fma`/`fmuladd`, `maxnum`/`minnum` with `nnan`, a rotate;
  consecutive loads and stores (one vector instruction for each 256 bits); extensions and truncations only as part of a load or a store; interleaved groups of 2, 3, 4 fields with every field used
  (`vlseg`/`vsseg`); reductions `add`, `fadd` (with `reassoc`), `smax smin umax umin` (up to 32-bit lanes), `fmax fmin` (with `nnan`).
* **Invalid** (the VF that needs it is dropped): vector `icmp fcmp select`, masked load/store, gather, scatter, strided, `sdiv udiv srem urem fdiv frem`, `sqrt` and every other intrinsic, int/fp conversions,
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
| `g_clamp_u8` | no instruction for vector `icmp`; no instruction for vector `trunc`; no instruction for vector `reduction (no accumulating instruction)`; too many live vectors | not a single-block loop with a preheader and one exit |
| `g_select_const` | no instruction for vector `icmp`; no instruction for vector `select`; not beneficial | - |
| `g_cond_store` | no instruction for vector `icmp`; not beneficial | not a single-block loop with a preheader and one exit |
| `g_count` | no instruction for vector `icmp`; no instruction for vector `zext`; not beneficial | - |
| `g_cmp_val` | no instruction for vector `icmp`; no instruction for vector `zext`; too many live vectors; not beneficial | - |
| `g_argmax` | Not vectorizing: Found an unidentified PHI   %.01114 = phi i32 [ %4, %.lr.ph.preheader ], [ %.112, %.lr.ph ]; Can't vectorize the instructions or CFG; Not vectorizing: Cannot prove legality. | - |
| `g_find` | Not vectorizing: Loop may fault.; Not vectorizing: Cannot prove legality. | not a single-block loop with a preheader and one exit |
| `g_if_else` | no instruction for vector `fcmp`; no instruction for vector `select`; not beneficial | - |
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
| `g_mulh` | vectorised, VF 8 | 1 vec block(s) |
| `g_rotl` | vectorised, VF 8 | 1 vec block(s) |
| `g_i2f` | no instruction for vector `sitofp`; not beneficial | - |
| `g_f2i` | no instruction for vector `fptosi`; not beneficial | - |
| `g_f2d` | vectorised, VF 8 | 1 vec block(s) |
| `g_u8_to_f` | no instruction for vector `uitofp`; not beneficial | - |
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

The functions whose result differs without fast-math (`gaps.py --strict`): `g_fmax_nan` (the NaN-aware maximum becomes an any-of select: not vectorised), `g_sqrt` and `g_exp` (calls instead of intrinsics), `g_fsum` and `g_matvec_row` (an ordered floating-point sum: LoopVectorize does not touch it), `g_inner3`.

## The kernels of the benchmark that LoopVectorize + the lowering do not turn into blocks (6 of the 31 have no block, 25 have one or more; `k_rmsnorm` has a block for one of its two loops)

| kernel | LoopVectorize | class above |
|---|---|---|
| `k_put8h` | vectorisation possible but not beneficial: too many live vectors | 12 (`vfir`) |
| `k_hist` | memory conflicts (a gather of the bin, a scatter-add) | 6 |
| `k_ssm` | a call of `expf` | 3 |
| `k_q4dot` | vectorised at VF 8, but the pass cannot make the widened `and` into lanes: scalarised (7,258 instructions, scalar 7,014) | 5 |
| `k_softmax` | max loop: compare+select without nnan; exponentials: a call; scale: `fdiv` | 1, 3, 2 |
| `k_gray` | strided access with a gap (3 of 4 fields): not beneficial | 7 |
| `k_rmsnorm` | first loop (sum of squares) a block; second loop an `fdiv` | 2 |
