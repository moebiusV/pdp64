# The OpenBLAS calls of cugpt and cngpt as `vec` forms, and the GEMM unit

**Status:** a study record, 2026-11-17, a sequel to `vec-forms.md` and with the same limits: the notation is the assistant's **proposal** (errata 139 decided the `vec` prefix and the `lb64` unit and left the details to be determined); the forms are **not assembled or run**; counts are of lines written by hand. Data: `arch-data/vec-forms/blas/` (the forms `*.vec.s` and `k_sgemm_nt.*.s`, `blas.c`, `pcc-scalar-blas.s`, `vecbench-blas.csv`, `openblas-loops.tsv`, `gemm-forms-summary.md`); scripts `tools/arch-compare/vecbench.py`, `gemmloops.py`, `vecforms.py`.

## 1. What the two programs ask of BLAS

*A correction first.* `vec-forms.md` said that `cugpt.c` calls `cblas_sgemm` and `cblas_dgemm` at 27 sites. That was wrong: the figure came from a command whose output was misread. Counted from the sources:

| program | what it calls | where | sizes |
|---|---|---|---|
| **cugpt** (microgpt in C, the BLAS version; double) | `dgemv` 2 (NoTrans and Trans), `dger` 1, `ddot` 5, `daxpy` 9, `dscal` 3: levels 1 and 2 only, no matrix-matrix call | `cugpt.c` | `N_EMBD` 16, `HEAD_DIM` 4, `BLOCK_SIZE` 16: vectors of 4 to 16 doubles |
| **cngpt** (nanoGPT in C; float) | **`sgemm` 11 sites**: the linear layer forward, the two backward products, attention scores and values, forward and backward (`ops.c`, `model.c`); `saxpy` and `snrm2` | `src/ops.c`, `src/model.c` | GPT-2 defaults `n_embd` 768, `block_size` 1024; the test configuration 32 and 8 |

cngpt also has hand-written AVX2 intrinsics for its scalar helpers (`ops.c`); not examined here.

## 2. Additions to the notation (proposed)

On top of `vec-forms.md`: `vlen.f rD` (the floats in a strip, the `cntw` of SVE and the `vsetvli` of RISC-V: a packed panel depends on it); `vclr.f v0,#8` (zero eight hidden registers); `vfmab.f vD,vS,(rA)+` (`vD += vS * broadcast(*rA)`, `rA` moved by one element: the multiply-add with a broadcast memory operand, one memory operand as the rule requires); `clrq (r)+` as the single-instruction fill of zeros; for the tile form a hidden tile `t0`..`t3` (VL x VL floats) with `vtclr`, `vtfmopa.f t0,v9,v8` (`t0[i][j] += v9[i]*v8[j]`, the outer-product accumulate of ARM SME's FMOPA, Intel AMX and POWER MMA), `vtld`, `vtadd`, `vtst` (tile load and store with a row stride); for the unit, `gemm.f rD`, one 3-parcel instruction that takes the address of a descriptor.

## 3. The level 1 and 2 calls of cugpt

`ddot` is a reduction (`vacc.d`), `daxpy` the fmac of the earlier study, `dscal` an in-place multiply, `dgemv` NoTrans a `ddot` of every row (the block moves the matrix pointer to the next row by itself), `dgemv` Trans a fill of zeros and an `daxpy` of every row, and `dger` an `daxpy` of every row (`k_dgemv_n.vec.s`, `k_dgemv_t.vec.s`, `k_dger.vec.s`). Each is the 3-to-7-instruction block that `vec-forms.md` already had:

| call | pcc scalar: function | pcc scalar: loop for each element | vec form: function | block operations for each element (4 doubles in a strip) |
|---|---:|---|---:|---:|
| ddot | 10 | 5 | 10 | 1.00 |
| daxpy | 10 | 7 | 8 | 1.00 |
| dscal | 8 | 5 | 7 | 0.75 |
| dgemv NoTrans | 17 | 8 | 13 | 1.00 |
| dgemv Trans | 23 | 4 and 10 | 15 | 1.75 |
| dger | 20 | 13 | 12 | 1.00 |

For clang the same loops cost, at the width of each target, 1.25 (AVX2) and 0.6 (AVX-512) to 2.5 (NEON) instructions for each element of `ddot`, and 1.75 to 4.0 for `dger` (summary file). **The finding for cugpt is about size, not width:** its vectors are 4 to 16 doubles, one or four strips, so the cost is the call into the library and the loop set-up, not the throughput; a block of 4 to 7 inline instructions is a smaller bill than a `cblas_ddot` call, which was not measured here.

## 4. The `sgemm` of cngpt: four forms

`linear_fwd` is `Y[M,N] = X[M,K] . W[N,K]^T` (`cblas_sgemm`, NoTrans and Trans). The reference is the triple loop (`k_sgemm_nt` in `blas.c`); pcc compiles its inner loop to 12 instructions for each multiply-add (it recomputes `i*K+k` and `j*K+k` each time).

| form | instructions of the function | in the block | multiply-adds for each strip | block operations for each multiply-add |
|---|---:|---:|---:|---:|
| pcc scalar | 28 | 12 (loop) | 1 | 12 |
| 1. a dot product for each output, `vec` over K (`k_sgemm_nt.dot.s`) | 20 | 4 | 8 | 0.500 |
| 2. register-blocked micro-kernel: 8 hidden accumulators, a strip of B and eight broadcast multiply-adds from packed A (`k_sgemm_nt.ukr.s`) | 48 | 9 | 64 | 0.141 |
| 3. the same with a hidden tile and one outer-product instruction (`k_sgemm_nt.tile.s`) | 14 | 3 | 64 | 0.047 |
| 4. the whole GEMM as one `gemm.f` of the `lb64` unit with a descriptor (`k_sgemm_nt.lb64.s`) | 17 | the unit | all | none: 17 set-up instructions for any size |

Strip of 8 floats (256 bits) throughout. Forms 2 and 3 take the packed panels that a GEMM driver makes (OpenBLAS's copy routines; a vec block with a strided load could do the packing and was not written); the function count of form 2 is mostly its write-back of eight rows (32 instructions).

**Against the hand-written kernels of OpenBLAS** (the main loop of `sgemm_kernel`, assembled with clang from OpenBLAS's own sources; the RISC-V kernel is C with intrinsics compiled by clang, not hand assembly):

| ISA | kernel | loop instructions | fused multiply-adds | instructions for each multiply-add |
|---|---|---:|---:|---:|
| x86 AVX2 (Haswell) | `sgemm_kernel_16x4_haswell.S` | 387 | 192 (50%) | 0.252 |
| AArch64 NEON | `sgemm_kernel_8x8.S` | 114 | 64 (56%) | 0.445 |
| AArch64 SVE | `sgemm_kernel_sve_v1x8.S` | 166 | 64 (39%) | 2.59 / VL |
| LoongArch LASX | `sgemm_kernel_16x8_lasx.S` | 243 | 128 (53%) | 0.237 |
| RISC-V V (256-bit), clang | `sgemm_kernel_16x8_zvl256b.c` | 69 | 30 (43%) | 0.287 |
| *clang, the naive loop (autovectorized)* | `blas.c` | 13 to 17 | | **1.06 (AVX-512), 1.6 (LASX), 2.0 (AVX2), 3.5 (NEON)** |
| **pdp64, form 1 / 2 / 3** | | | | **0.500 / 0.141 / 0.047** |

Half of OpenBLAS's loop is multiply-adds; the rest is what a block form does not carry: Haswell's 96 broadcasts (`vbroadcastss`), 32 pointer increments, 16 prefetches and 16 loop counters of 387; NEON's 24 address adds of 114; LASX's 64 broadcasts of 243.

## 5. Findings (the assistant's analysis, not decisions)

1. **The level 1 and 2 calls need nothing the vec study did not have**, and for cugpt's 4-to-16-element vectors the saving is the call, not the loop.
2. **A plain `vec` dot product is the naive loop, vectorized**: 0.5 operations for each multiply-add, because every multiply-add reads two operands from memory. It beats clang's autovectorized naive loops (1.1 to 3.5) and is **two to three times worse than OpenBLAS's hand kernels** (0.24 to 0.45). That gap is the whole reason GEMM is written by hand elsewhere.
3. **The register-blocked block form (0.14) is better than every hand-written kernel measured** (0.24 on AVX2 and LASX) on instruction count, by dropping the pointer bumps, prefetches, broadcasts and loop control; it needs hidden accumulators, a multiply-add with a broadcast memory operand, and `vlen`. This is a count of instructions in the loop, not of speed: OpenBLAS's prefetches and its unrolling exist for the memory system, which a block form leaves to the hardware.
4. **The tile form (0.047) is the cheapest in instructions and the one that changes the architecture:** a VL x VL accumulator is 256 bytes at 256-bit strips (1 KiB for four tiles), more state than the hidden vector registers of errata 139.
5. **The accumulators raise a question the decision did not have to answer.** A block holding partial sums in hidden registers cannot, on a page fault or an interrupt inside the K loop, resume from the last strip unless those registers survive. Either they are saved at a context switch (against "nothing is saved at a context switch beyond the ordinary registers"), or the block restarts from the beginning of the tile (correct, and wasteful for a K of 1024), or the accumulators are committed to memory by the program every so many strips. This applies to forms 2, 3 and to the reductions of the earlier study (their accumulator is an ordinary register, which is why they are safe). **It is the main design question for GEMM in the `vec` block.**
6. **The unit with a descriptor (17 instructions for any size) removes the question from the program** and puts it in the unit: the descriptor holds the progress, packing and tiling are the unit's business, and a fault restarts at the first tile not done, like the block moves. cngpt's 11 `sgemm` sites become 11 `gemm.f` instructions. The cost is the hardware, and the kernels it needs for the other BLAS calls and for the attention products (a batch of small matrices of 64 x 64 at the test size, where a unit's start-up cost matters more than its peak).
7. **Not shown:** speed, packing, edge tiles (M, N and K that are not multiples of the tile), alpha and beta other than 1 and 0, transposes other than NT, and the memory behaviour that OpenBLAS's prefetches serve.

## 6. What was not checked

The forms are unassembled. OpenBLAS was built from a shallow clone of its repository (2026-11-17) with hand-made configuration headers for each target; the kernels are those named in the table, one per instruction set (the Haswell kernel, not the Skylake-X AVX-512 ones). The main-loop finder takes the innermost loop with the most multiply-adds, and for the unrolled kernels that loop holds several iterations of the K loop; the multiply-adds of the loop are counted, so the ratio is right. The lane counts are 8 for ymm and LASX, 4 for NEON, and 8 for RISC-V at a vector length of 256 bits; SVE is given for a vector of VL floats.
