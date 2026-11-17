Status: record, dated 2026-11-17. It describes what was measured on that day; the current state is in `docs/manual` and `docs/decisions-and-status.md`, and where this document disagrees, those win. The findings in section 6 are the assistant's analysis, not decisions: the author decides J.8.5 and the shape of `vec`.

# Vector work on a codec: what a `vec` prefix has to cover

The author decided on 2026-11-16 (errata 139) that `vec` is a prefix instruction over a region of memory, and asked (2026-11-17) for a corpus that exercises AVX2 and SIMD code, "perhaps that video codec decoding library", with the ARM and RISC-V vector operations where it has them, so that the vector decision is the best one. The corpus is **dav1d** (the AV1 decoder, commit 6c7bee6 of 2026-11-16): its pixel kernels exist as portable C and as hand-written assembly for x86 (SSE, AVX2, AVX-512; NASM), AArch64 NEON and RISC-V vector (`src/x86`, `src/arm/64`, `src/riscv/64`).

Scripts: `tools/arch-compare/vecscan.py`, `handkernels.py`, `vecwin.py`; data: `docs/encoding-work/arch-data/vector/`.

## 0. Summary

* **A `vec` prefix over one existing instruction covers a fifth of the codec's data-parallel loops.** The codec's loops are filters, not elementwise operations: in the 131 loops of the pdp64 code for the kernels that load, compute and store, there are on average **7.8 loads and 1.4 stores** and a median of **6 element operations**; only 27 (21%) are one operation on at most two streams.
* **What the loops need besides that** (from the IR of 185 loop bodies that clang vectorizes for AVX2): elementwise maps 65%, **reductions 16%**, **masked or selected operations 14%**, shuffles 5%, **gathers 0%**. Clamping (`iclip`) is called in 70 of the loops and min, max, abs and sign helpers in more; widening from 8 to 16 bits is in the first loop of the list.
* **Autovectorizers find the loops and make the code bigger.** clang vectorizes 42% of the loops it looks at (AVX2 and AArch64: 353 of 845) and the vectorized builds are **1.24 to 1.45 times** the instructions and bytes of the scalar builds of the same files (runtime checks, remainders, wide constants). pdp64's scalar code for the same files is 30,169 instructions and 87,070 bytes: 0.93 of AArch64's scalar instructions and 0.67 of its bytes, 0.64 and 0.46 of its autovectorized code. A region prefix with defined overlap and restart needs neither the checks nor the remainder.
* **The hand-written kernels differ by ISA**: RISC-V vector, which does not name the width, is smaller than NEON in the transforms, the prediction and the motion compensation and larger in CDEF.
* **Not measured:** dynamic counts (instructions executed), the hand-written AVX2 (NASM is not installed and building it from source was not permitted here), and any pdp64 `vec` code (there is no compiler for it).

## 1. What was compiled

The C of dav1d's pixel kernels, 15 files: `cdef`, `itx`, `mc`, `ipred`, `loopfilter`, `looprestoration`, `filmgrain` (each at 8 and 16 bits) and `itx_1d.c`, with `enable_asm=false` (the portable path), preprocessed as the rest of the corpus is.

* **pdp64**: pcc, `ccom -m pdp64`, `as64 --stats`: all 15 compile, 30,169 instructions, 87,070 bytes. pcc does not inline the small clip helper `iclip`, so many pdp64 loops contain a call that clang's output does not.
* **clang 21** at -O3 for x86-64 with `-mavx2 -mfma`, AArch64 (NEON), riscv64 with `-march=rv64gcv`, LoongArch64 with `-mlasx`: each with the vectorizers (`-Rpass` remarks counted) and with `-fno-vectorize -fno-slp-vectorize`.
* **The IR** of the AVX2 and AArch64 builds is read: every `vector.body` block is classified as map, reduce, shuffle, masked or gather, with its element operations, load streams and store streams.
* **The assembly**: dav1d's NEON and RISC-V vector `.S` files assembled with clang and counted (`handkernels.py`).

## 2. Size: scalar, autovectorized, pdp64

| target | files ok | scalar instructions | vector instructions | ratio | scalar bytes | vector bytes | vectorized loops (vf avg) | SLP |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| x86_64-avx2 | 15 | 42,706 | 60,407 | 1.414 | 167,314 | 260,484 | 180 (13.7) | 50 |
| aarch64 | 15 | 32,361 | 47,030 | 1.453 | 129,444 | 188,120 | 173 (10.3) | 40 |
| riscv64-v | 15 | 45,407 | 56,334 | 1.241 | 133,728 | 172,138 | 12 (6.0) | 45 |
| loongarch64-lasx | 15 | 41,301 | 58,661 | 1.420 | 165,204 | 234,644 | 169 (8.9) | 31 |

The row for pdp64 is 30,169 instructions and 87,070 bytes. The vectorized builds are bigger than the scalar ones on every target; the cost is the code that makes the vector loop safe (a test that the arrays do not overlap, the remainder loop) and the constants. Of 845 loops that the vectorizers of AVX2 and AArch64 considered, 353 were vectorized and 492 left; the reasons the compiler gave, counted per file and target, were: instruction cannot be vectorized 24; value that could not be identified as reduction is used outs 24; cannot identify array bounds 20; Cannot vectorize uncountable loop 19; call instruction cannot be vectorized 16; could not determine number of loop iterations 15; Cannot vectorize potentially faulting early exit loop 4; Control flow cannot be substituted for a select 4. RISC-V vector vectorized only 12 loops (clang's choice of scalable vectors); that is a statement about the compiler, not the ISA.

## 3. The shape of the vectorized loops

x86_64-avx2: 185 vectorized loop bodies in the IR: map 120, reduce 29, masked 26, shuffle 10
  map       120 bodies; element operations per iteration: median 4, max 24; loads 2.9, stores 1.4 on average
  reduce     29 bodies; element operations per iteration: median 4, max 32; loads 3.6, stores 0.7 on average
  shuffle    10 bodies; element operations per iteration: median 17, max 76; loads 5.7, stores 2.8 on average
  masked     26 bodies; element operations per iteration: median 9, max 20; loads 4.3, stores 1.3 on average

aarch64: 182 vectorized loop bodies in the IR: map 115, masked 31, reduce 26, shuffle 10
  map       115 bodies; element operations per iteration: median 4, max 24; loads 2.9, stores 1.0 on average
  reduce     26 bodies; element operations per iteration: median 2, max 24; loads 2.6, stores 0.5 on average
  shuffle    10 bodies; element operations per iteration: median 17, max 36; loads 4.7, stores 1.8 on average
  masked     31 bodies; element operations per iteration: median 8, max 19; loads 4.1, stores 1.4 on average

No loop in the vectorized IR needed a gather. Shuffles (a lane permutation or an interleave) are in 5% of the bodies and are large when present (median 17 operations).

## 4. The hand-written kernels

dav1d's assembly, assembled and counted (file level; the exported functions differ between ISAs, so only CDEF, whose seven entry points do the same work on both, is like for like; the rest is indicative):

| kernel family (8 and 16 bit files together) | AArch64 NEON: instructions (exported functions) | RISC-V vector: instructions (exported functions) | RVV / NEON |
|---|---:|---:|---:|
| cdef | 3,222 (12) | 5,028 (14) | 1.56 |  |
| ipred | 8,220 (62) | 903 (37) | 0.11 |  |
| itx | 16,024 (340) | 3,781 (172) | 0.24 |  |
| mc | 15,884 (67) | 3,591 (49) | 0.23 |  |
| filmgrain | 7,217 (16) | 302 (2) | 0.04 |  |
| loopfilter | 2,963 (8) | none |  |  |
| looprestoration | 2,700 (20) | none |  |  |

CDEF, 8-bit, the like-for-like pair: NEON 1,961 instructions, RISC-V vector 3,075 (1.57 times). The transforms, prediction and motion compensation are smaller in RISC-V vector, whose length register lets one code path serve every block width where NEON writes one path for each; film grain exists in RISC-V vector only in part (one entry point). The x86 assembly (SSE, AVX2, AVX-512, 36 files) was not assembled.

## 5. Where `vec` would win in pdp64 code (`vecwin.py`)

The author asked for "a script to examine the asm for cases where the vec instruction would actually be a win" (R433). `vecwin.py` reads pcc's pdp64 assembly, finds the innermost loops and classifies each by its body: `map` (loads, operations, stores, no call and no branch), `reduce`, `fill`, `branch` (a branch inside: needs predication) and `call` (a call inside).

| | the 15 dav1d kernel files (30,142 instructions) | the 841-file corpus (296,069 instructions) |
|---|---:|---:|
| innermost loops | 345 (36.5% of the static instructions) | 9,880 (38.4%) |
| map | 131 loops, 9.2% of the instructions | 307 loops, 1.2% |
| reduce | 18 loops, 0.4% | 65 loops, 0.4% |
| fill | 14 loops, 0.1% | 97 loops, 0.1% |
| branch inside | 44 loops, 3.9% | 1,142 loops, 5.8% |
| call inside | 138 loops, 22.8% | 8,251 loops, 30.8% |
| map loops that one prefixed instruction could be (at most two streams, at most two operations) | 27 of 131 (21%) | 137 of 307 (45%) |
| map loops of at most four streams and four operations | 45 (34%) | 239 (78%) |

In the kernels the `call` loops are mostly the clip helper: 70 of the 138 call `iclip`, and in 56 of them every call is a clip, min, max, abs or sign helper (`imin`, `imax`, `iabs`, `apply_sign`); with those inlined, as clang does, they become map or branch loops. In the corpus the calls are mostly `__builtin_abort` (6,152 of the 8,251: the assertions of its test files). The corpus is the project's general C test and library set, so its 1.7% of static instructions in `map`, `reduce` and `fill` loops is the share of code that a `vec` could serve in ordinary C; the codec kernels are 9.7%. Static counts understate the dynamic share, since a loop body executes many times; they were not weighted.

## 6. Findings (the assistant's analysis, not decisions)

1. **A bare `vec` prefix on one existing instruction serves the simple loops and not the codec.** Fill, reduce and the 21% of map loops that are one operation on two streams are what it covers. The codec's kernels are 8-tap filters, transforms and stencils with about 8 loads for each store; run one instruction at a time over memory, each of the 6 operations is a pass over arrays that the next must read again (J.8.5: 24k bytes an element against 8(k+2) when the intermediates stay in registers). The decision already allows the remedy (hidden registers, errata 139); the data says it is needed, and says what it holds.
2. **What the vector design should have, in the order the data asks for it:** (a) **chaining**: several operations between the loads and the store without going through memory, which is the hidden register file of the decision; (b) a **sliding-window multiply-accumulate** (a filter over a region with taps held in registers or an array), the form of the filter loops, which is the part of "GEMM" that a codec uses; (c) **widening and narrowing** between 8, 16 and 32 bits in the element operations; (d) **minimum, maximum, clamp and absolute value** as element operations (J.9.1 decides how `MIN` and `MAX` expand; the clip appears in 70 loops); (e) a **select under a compare** (masked operations are 14% of the vectorized loops); (f) **reductions** to a register (16%). **Shuffles** (5%) and **gathers** (0%) are the first to leave out.
3. **Length-agnostic by construction.** The hand-written RISC-V vector kernels are smaller than NEON where the width varies, because one path serves every width; a region prefix named by `[Rs, Re)` is that, and it needs no remainder loop and no overlap test the way the autovectorized code does (the 1.24 to 1.45 growth).
4. **Code size is not where a vector design pays on this machine.** pdp64's scalar kernels are already smaller than every other ISA's scalar code and smaller than their autovectorized code; the gain is in instructions executed and in fetch, which this record did not measure.
5. **What would settle it:** the dynamic counts of the kernels (instructions executed and bytes fetched, with the simulator for pdp64 and a plugin-capable QEMU for the others); a pcc that inlines the clip helpers, so that `vecwin.py` counts the loops that are really there; and the same three or four kernels written by hand in the `vec` forms above (`prep_c`, the bilinear and 8-tap filters, CDEF) to count their instructions, which needs the instruction list that errata 139 left to be determined.

## 7. What was not measured

* **Instructions executed.** All counts are static.
* **x86 hand-written code.** The NASM sources were not assembled: NASM is not installed and building it from a downloaded source was not allowed in this session. The AVX2 data is clang's compiled output.
* **The RISC-V vector builds** vectorize few loops with clang 21; the RISC-V figures of section 2 are of the scalar-heavy output.
* **pcc and clang differ** in optimiser strength; pcc does not inline small static functions.
* **libyuv, libjpeg-turbo, libaom and libvpx**, which have intrinsics for AVX2 and NEON in C, were not compiled.

## 8. To reproduce

    meson setup <dir>/dav1d-c -Denable_asm=false -Denable_tools=false -Denable_tests=false -Denable_examples=false     # in a checkout of dav1d
    SYSROOT_LA64=<musl headers of loongarch64> python3 tools/arch-compare/vecscan.py <dir>/dav1d-c/compile_commands.json <out> -j 2
    python3 tools/arch-compare/handkernels.py <dav1d> <cfg-a64> <cfg-rv> <out>        # config.h copies with HAVE_ASM and the architecture switched on
    # pdp64: preprocess each kernel as prep.py does (aarch64 musl headers), ccom -m pdp64, then
    python3 tools/arch-compare/vecwin.py -v <file>.s ...
