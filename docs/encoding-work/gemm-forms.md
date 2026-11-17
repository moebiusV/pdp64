# The OpenBLAS calls of cugpt and cngpt as `vec` forms, and a GEMM unit

**Status:** a study record, 2026-11-17, a sequel to `vec-forms.md` and with the same limits: the notation is the assistant's **proposal** (errata 139 decided the `vec` prefix and recorded the author's idea of a unit with its own instruction set, and left the details to be determined); the forms are **not assembled or run**; counts are of lines written by hand. Data: `arch-data/vec-forms/blas/` (the forms `*.vec.s` and `k_sgemm_nt.*.s`, `blas.c`, `pcc-scalar-blas.s`, `vecbench-blas.csv`, `openblas-loops.tsv`, `gemm-forms-summary.md`); scripts `tools/arch-compare/vecbench.py`, `gemmloops.py`, `vecforms.py`.

## 0. What "lb64" is (a correction of this record's first version)

The first version of this record called form 4 "a GEMM instruction of the `lb64` unit". That mislabels it. From the conversation database (`ai-conversations`):

* **The name was coined by the assistant, 2026-10-20.** The author had asked (claude_web thread 533, "PDP-11 to VAX silicon implementation", message 51, 20:28) "what would a gpu look like that is optimized purely for samsung's littlebit-2 encoding", an accelerator on the same bus that uses the same RAM and does DMA. The assistant's answer (message 52, 20:34) is the first use of "LB64": the machine splits into three engines, "LB64 (sign-flip, no DSPs), ATT64 (FP16 MAC, uses the DSPs), VEC64 (elementwise, norms, softmax)". No document expands the name; `docs/pdp64-lb64-accelerator.md` is titled "LB64 -- An Accelerator on the System Bus for LittleBit Inference". It is most likely LittleBit plus 64, as ATT64 is attention plus 64 (my reading; nowhere stated).
* **What it is:** a device for models whose weights are one sign bit each: it does sign-flip accumulates, **no multiplier, no floating-point multiply-add**, takes a chain of descriptors, and "has no instruction set" (its design section). It is marked proposed, not decided. An `sgemm` of 32-bit floats is **not** something it does; the engine of the proposal for floating-point multiply-accumulate is ATT64.
* **The author's own use, 2026-11-16** (errata 139, register R432, in the Grok thread): "if we need to turn lb64 into a special unit with its own instruction set we will, no need to put it on the pcie bus it must always be present at a certain memory page". That is the author's idea of growing the accelerator into a unit with an instruction set (and GEMM operations, R430 to R435), not a statement that it is one now.

So form 4 below is a **GEMM unit** of the author's idea, not LB64 as proposed. Errata 139 and J.8.5 said "the GEMM unit `lb64`"; they now say "the accelerator `lb64`".

## 1. What the two programs ask of BLAS

*A correction first.* `vec-forms.md` said that `cugpt.c` calls `cblas_sgemm` and `cblas_dgemm` at 27 sites. That was wrong: the figure came from a command whose output was misread. Counted from the sources:

| program | what it calls | where | sizes |
|---|---|---|---|
| **cugpt** (microgpt in C, the BLAS version; double) | `dgemv` 2 (NoTrans and Trans), `dger` 1, `ddot` 5, `daxpy` 9, `dscal` 3: levels 1 and 2 only, no matrix-matrix call | `cugpt.c` | `N_EMBD` 16, `HEAD_DIM` 4, `BLOCK_SIZE` 16: vectors of 4 to 16 doubles |
| **cngpt** (nanoGPT in C; float) | **`sgemm` 11 sites**: the linear layer forward, the two backward products, attention scores and values, forward and backward (`ops.c`, `model.c`); `saxpy` and `snrm2` | `src/ops.c`, `src/model.c` | GPT-2 defaults `n_embd` 768, `block_size` 1024; the test configuration 32 and 8 |

cngpt also has hand-written AVX2 intrinsics for its scalar helpers (`ops.c`); not examined here.

## 2. Additions to the notation (proposed)

On top of `vec-forms.md`: `vlen.f rD` (the floats in a strip, the `cntw` of SVE and the `vsetvli` of RISC-V: a packed panel depends on it); `vclr.f v0,#8` (zero eight hidden registers); `vfmab.f vD,vS,(rA)+` (`vD += vS * broadcast(*rA)`, `rA` moved by one element: the multiply-add with a broadcast memory operand, one memory operand as the rule requires); `clrq (r)+` as the single-instruction fill of zeros; for the tile form a hidden tile `t0`..`t3` (VL x VL floats) with `vtclr`, `vtfmopa.f t0,v9,v8` (`t0[i][j] += v9[i]*v8[j]`, the outer-product accumulate of ARM SME's FMOPA, Intel AMX and POWER MMA), `vtld`, `vtadd`, `vtst` (tile load and store with a row stride); for the unit, `gemm.f rD,rI,rJ`, one 3-parcel instruction: `rD` is the address of a descriptor of the constants, `rI` and `rJ` are the progress (the row and the column, in elements, of the next output tile), advanced by the unit past each tile it finishes.

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
| 4. the whole GEMM as one `gemm.f` of a GEMM unit: constants in a descriptor, progress in two ordinary registers, restart from the start of a tile (`k_sgemm_nt.unit.s`) | 19 | the unit | all | none: 19 set-up instructions for any size |

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
6. **A GEMM unit takes the question out of the program; its progress is two registers and it restarts from the start of a tile.** Form 4 keeps the constants (twelve fields: three addresses, three sizes, three strides, alpha, beta, flags) in a descriptor in memory and the progress in two ordinary registers, the row and column of the next output tile, as a block move keeps its address and count. The unit computes a tile over all of K in its own registers and writes it once, after checking that the pages of the C tile can be written, and the write-back and the advance of the registers are one uninterruptible step; an interrupt or fault before that step discards the tile and the instruction redoes it from the start, so C never holds a half-finished tile, beta = 1 in place is correct, at most one tile (about 2 microseconds at K = 768) is lost, and nothing beyond the ordinary registers is saved at a context switch. The translation buffer must hold the pages of one tile (about 48). This is the third version of the form: the first kept the progress in the descriptor, the second a K offset in a third register with a K-block commit (section 5a gives the reasons for the change). cngpt's 11 `sgemm` sites become 11 set-ups of 19 instructions and one `gemm.f` each. The cost is the hardware, and the unit's start-up on the small matrices of attention (a batch of 64 x 64 at the test size).
7. **Not shown:** speed, packing, edge tiles (M, N and K that are not multiples of the tile), alpha and beta other than 1 and 0, transposes other than NT, and the memory behaviour that OpenBLAS's prefetches serve.

## 5a. Resuming a GEMM: start over, a page of memory, or state inside the unit (the assistant's analysis, asked by the author, 2026-11-17)

The questions: would starting over from zero be simpler than resuming; could the resume state live in a page of memory like the C64's zero page; could it stay inside the unit; does anything outside ever need to see it?

**What an interrupt or fault asks of an instruction.** It stops at any moment (a page fault in the middle, a timer tick, a signal) and is run again later, possibly after another process has run, possibly on another core (pdp64 is SMP), possibly after a debugger looked at the process or a hypervisor snapshotted the machine. Whatever the unit holds that cannot be thrown away and rebuilt from the registers and memory the program can see is, by that fact, state that somebody outside must save and restore.

**1. Starting over from zero is correct only under three conditions.**
* *Idempotence.* A second run must give the same result as one. With `beta = 0` or an output separate from the inputs it does; with the in-place accumulate that cngpt uses in its backward pass (`beta = 1`: `dX += ...`, `dW += ...`) a tile already written would be added a second time. So a restart from zero needs the output of each piece to be written once, completely, and the write not to be cut in half (the pages checked for writing first, the write-back not interruptible).
* *Bounded length.* A restart from zero must finish before the next interrupt, or it never finishes. cngpt at its defaults (batch 4, sequence 1024) multiplies 4096 x 768 by 768 x 2304 in the attention projection (14.5 billion floating-point operations) and 4096 x 768 by 768 x 3072 in the first layer of the feed-forward block (19.3 billion): at an assumed 50 billion operations a second that is 290 and 390 milliseconds, against a timer tick of 1 to 10 milliseconds. A whole GEMM restarted from zero **livelocks** (it is cut off by the tick every time, with a periodic timer it is certain). One output tile of 8 x 8 with K = 768 is 98 thousand operations, about 2 microseconds.
* *Forward progress under faults.* A restarted piece must not fault forever: a tile touches at most about 48 pages (16 for the rows of A, 16 for B, 16 for the rows of C at 768 floats a row), and the translation buffer must hold them, as the VAX required of its long instructions.

**2. So "from zero" means from the start of a tile, and then the progress is the tile coordinates.** The unit of restart is one output tile, computed over all of K, written once. The only thing the unit must remember between runs is which tiles are finished: two numbers, the row and column of the next tile, which are **ordinary registers** (or, if software drives the tiles with one tile instruction at a time as forms 2 and 3 do, are the program's own loop counters and the unit remembers nothing). The K offset that an earlier version of form 4 kept in a third register is unnecessary (form 4 is rewritten accordingly); a K-block commit exists to save work, and at 2 microseconds there is little to save. The cost of a restart is at most one tile, and for a very long K (tens of thousands) a tile grows to tens of microseconds, still far below the tick.

**3. A page of memory, like the zero page, works and has real merits, and the same protocol problem.** Progress kept in memory in the process's own address space is per process, survives a migration to another core and a snapshot without anyone saving anything, and has no size limit. Precedent (from memory, not checked against a source here): IBM's z/Architecture interruptible compression and cryptography instructions keep their running state in a parameter block in memory, with the addresses and lengths advanced in registers. The costs: the unit's store of the progress and its stores into C must be ordered and cannot be cut apart (commit C, then the progress, with no interrupt between, or a restart repeats an accumulated tile: the same condition as for registers); other cores and a debugger can see and corrupt it, so the unit must treat it as untrusted and validate it against the sizes of the descriptor; and "a certain page" must be a per-process virtual page or the state is shared. It buys nothing over two registers for a progress of two numbers; it is the right place only for state that is large.

**4. Staying internal is correct only for what can be dropped.** Accumulators, packed copies of panels, prefetch queues and the position inside a tile are a cache: if the unit loses them, it recomputes the tile. State that **cannot** be dropped without losing work (which tiles are done) must be visible, or the restart is from the beginning and the livelock of 1 applies. Internal state that is not droppable would also have to be switched by the operating system at every context switch (the unit's own xsave), would be lost on a migration to another core, would be clobbered by a signal handler that runs its own GEMM, and would be invisible to a debugger and to a hypervisor's snapshot: each of these needs the state to be either visible or droppable.

**5. Answer to "does anything external ever need to see it?"** Yes, exactly the state that cannot be rebuilt: here, which tiles are finished (two numbers), for the operating system at a context switch, for a debugger, for migration and for snapshots. Nothing else: the accumulators and buffers can and should stay inside, and a restart discards them. The design that follows is: **one-tile restart, the tile coordinates in two ordinary registers, the constants in a descriptor in memory, all other state internal and droppable.** The K-block commit of the second version of form 4 was an optimisation that adds a third visible number for little saving; an implementation that wanted it could do it inside a tile and still restart the tile from its start.

The precedent the author named earlier is the same shape: a block move restarts from registers that always hold the address and count of the first unmoved byte; the unit is the byte, here it is the tile.

## 6. What was not checked

The forms are unassembled. OpenBLAS was built from a shallow clone of its repository (2026-11-17) with hand-made configuration headers for each target; the kernels are those named in the table, one per instruction set (the Haswell kernel, not the Skylake-X AVX-512 ones). The main-loop finder takes the innermost loop with the most multiply-adds, and for the unrolled kernels that loop holds several iterations of the K loop; the multiply-adds of the loop are counted, so the ratio is right. The lane counts are 8 for ymm and LASX, 4 for NEON, and 8 for RISC-V at a vector length of 256 bits; SVE is given for a vector of VL floats.
