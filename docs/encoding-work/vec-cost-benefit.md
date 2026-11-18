# Cost and benefit of the vector, GEMM and accelerator operations (a start)

**Status: the assistant's analysis, begun 2026-11-17, not a decision.** The author decided (errata 155) that nothing of the GEMM and `vec` work is dropped before a cost-benefit analysis, and that, until there is a GPU, SIMD on the CPU is wanted for games and for language-model inference on machines without a large, power-hungry GPU: "like a gpu-lite". The GPU, when there is one, will use unified memory (errata 154). This record is the table that decides among the operations, with what is **measured** and what is only **estimated** marked. It is a start: the benefit columns have static instruction counts, the workload section has arithmetic from stated assumptions, the cost columns are mostly estimates, and the measurement that would settle it (dynamic counts on a simulator that has the operations) does not exist yet.

Evidence grades used below: **M** measured here (static instruction counts of hand-written forms and of compiled code, `vec-forms.md`, `gemm-forms.md`, `arch-data/vec-forms/`); **E** estimated by the assistant from numbers measured here, with the assumption stated; **U** general knowledge not checked on this machine; **N** not studied.

## 1. The workloads (what "gpu-lite" has to run)

Seven kernels of games and of inference were added to the eight of `vec-forms.md` and the BLAS calls of `gemm-forms.md` (`arch-data/vec-forms/games/`; `tools/arch-compare/costbenefit.py`). pcc's scalar code, the hand-written `vec` form (the proposed block notation, unassembled), and what clang's vectorizers did:

| kernel | use | pcc scalar: loop for each element | vec form: block operations for each element (256-bit strip) |
|---|---|---|---:|
| `q8dot` | LLM: the int8 dot product of a quantized layer | 6 instructions | 0.25 |
| `q4dot` | LLM: 4-bit weights, two to a byte | 16 | 0.69 |
| `rmsnorm` | LLM: a reduction and a map | 5 and 8 | 1.00 |
| `softmax` | LLM: attention scores: max, exp, sum, scale | 5, 6 and 8 | 1.25 (with a vector exp) |
| `blend` | games: alpha blending of 8-bit channels | 18 | 0.75 |
| `mix16` | games: audio, saturating 16-bit add | 11 | 0.25 |
| `vtx` | games: a 4x4 matrix on vertices (structure of arrays) | 57 | 2.25 |

Clang vectorized every one of them on all five targets that were built (AVX2, AVX-512, NEON, RISC-V V, LASX), at 2 to 7 times the size of the scalar function, and 27 times for one LASX build of `blend` (the overlap tests and the remainder loop; `games-summary.md`). The hand-written forms are shorter than pcc's scalar functions in all seven (`vtx` 34 against 60 instructions, `mix16` 8 against 14).

**What the numbers mean for a frame and for a token** (E; the assumptions are stated and unmeasured: 3 GHz, one scalar instruction a cycle, one block operation a cycle):

| workload | pcc scalar | `vec` block |
|---|---:|---:|
| alpha-blend one 1080p RGBA frame (8.3 million channels) | 149 million instructions, **50 ms** | 6.2 million operations, **2 ms** |
| transform 100,000 vertices | 5.7 million instructions, 1.9 ms | 0.23 million, 0.08 ms |
| mix one second of 48 kHz stereo audio | 1.1 million, 0.4 ms | 0.02 million, 0.01 ms |

A 60-frame-a-second game has 16.7 ms: the scalar blend alone is three frames. Software compositing, skinning and audio need SIMD; for these the basic block (section 3, rows 1 to 5) is enough.

**Inference** (E, with U inputs for the model sizes and the memory speed): decoding one token multiplies the whole weight matrix once, so the memory ceiling is the bandwidth over the weight bytes, and the compute needed is one multiply-add for each parameter.

| model | weights | tokens a second the memory allows at 50 and 100 GB/s |
|---|---:|---|
| 1 billion parameters, 8 bit | 1.0 GB | 50 to 100 |
| 3 billion, 4 bit | 1.7 GB | 30 to 59 |
| 7 billion, 4 bit | 3.9 GB | 13 to 25 |
| 7 billion, 8 bit | 7.0 GB | 7 to 14 |

| the multiply-add loop, one core at 3 GHz | multiply-adds a cycle | 1B model, tokens a second | 7B model |
|---|---:|---:|---:|
| pcc scalar (6 instructions for each, two a cycle) | 0.33 | 1.0 | 0.14 |
| `vec` block, 16-bit lanes (4 operations for 16 multiply-adds), 1 operation a cycle | 4 | 12 | 1.7 |
| the same at 2 operations a cycle | 8 | 24 | 3.4 |
| an int8 dot-product instruction (4 operations for 32), 1 a cycle | 8 | 24 | 3.4 |
| the same at 2 operations a cycle | 16 | 48 | 6.9 |

So for a language model on a CPU the **compute, not the memory, is the limit** by a factor of 3 to 8 at 7 billion parameters on one core of this class of SIMD, and a small model (1 to 3 billion) reaches the memory ceiling with a dot-product instruction on two operations a cycle. Many cores and a wider strip move the figures (not modelled). A GEMM unit or a tile does not change the decode of one token, which is a matrix-vector product with no reuse of the weights; it changes **batched decoding and the prompt** (the prefill is a matrix-matrix product).

## 2. What each operation costs (shared)

* **Opcode space** (E from `J.9.13` and `tables.md`): the register-register group `R2` has 957 free sub-opcodes of 1,024 and `R3` 77 of 128; a vector operation with two or three vector-register operands fits one of them if the optimiser gives the vector registers a field shape, at no first-parcel pattern; the first-parcel patterns are spent only by a one-parcel hot form or by a shape the groups cannot hold. The prefix optimiser decides (R434, R446): its input is the corpus, so the cost is counted when the instructions are in the forms, not here.
* **State**: the `vec` block has hidden vector registers (decided as allowed, R435). Hidden registers that never hold anything across an interrupt (they are refilled from memory by a restarted strip) cost nothing at a context switch. Accumulators that persist across strips do (section 4).
* **Compiler**: an operation that pcc cannot emit is a hand-written-library feature only; what pcc can emit is used by every program. The check instructions needed a tree operator and two templates; a vector loop needs a vectorizer pcc does not have (`vecwin.py` finds the loops; nothing rewrites them).

## 3. The table

Verdicts are the assistant's provisional leans (L), for the author to take or leave.

| # | operation | benefit (evidence) | games / inference use | cost | provisional lean |
|---|---|---|---|---|---|
| 1 | **the `vec` block**: loads, lane operations, stores over a region, hidden registers, no width in the program | each of the 15 kernels written needs 12 to over 100 times fewer block operations per element than pcc's scalar loop has instructions (these are not times), and every one of the 15 forms is shorter than pcc's scalar function (M, `vec-forms.md`, `games-summary.md`); no remainder loop, no overlap test, no width (the clang vector builds are 2 to 7 times the scalar size, M) | all of the above | encoding: tens of words (E); state: hidden registers, refilled after an interrupt (restartable per strip, E); compiler: a vectorizer is new work; **gates: about 100,000 with 16 integer lanes, about 180,000 with 8 floating-point lanes as well (M for the blocks, E for the rest, `vec-gates.md`)** | **yes** (the base of everything) |
| 2 | the **single-instruction prefix** (decided, R430) | covers 2 of 8 kernels in the first study (a fill and a reduction, M) because of the one-memory-operand rule | `memset`, sum, count | one prefix word | **keep**, as the decided minimum; the block (row 1) is what carries the rest |
| 3 | **reductions into a register** (`vacc`, a max reduction) | the sum, the SAD, the dot product, the sum of squares, the scan: 7 of the 15 kernels (M) | `q8dot`, `rmsnorm`, SAD, softmax | a few words; no persistent state (the register is ordinary); **gates: about 6,000** | **yes** |
| 4 | **widening and narrowing, saturating add and clamp** (`vadds`, `vsts`) | the filters, `blend`, `mix16`, the quantized dots: without them the kernel needs 16-bit intermediates and explicit clamps (M: `put8h` 31 instructions with a clamp on the store, `mix16` 4 operations) | pixels, audio, quantized weights | a few words per width; **gates: 12,000 to 15,000** | **yes** |
| 5 | **sliding-window multiply-accumulate** (`vfir`) | the 8-tap filter: 0.62 block operations for each pixel against 2.38 with displaced loads (M); the hand NEON, AVX2 and RVV kernels do the same in loops of 40 to 115 instructions (M) | image filters, blur, audio FIR, convolution | one word with a tap-register range; a halo of 7 elements kept between strips (E); **gates: 3,000 to 6,000 on the existing multipliers over eight cycles, 106,000 for one strip a cycle (M)** | **yes** (the one operation that made a pdp64 form better than every other column) |
| 6 | **broadcast multiply-add** and the **register-blocked micro-kernel** (`vfmab`, 8 accumulators) | 0.141 block operations for each multiply-add against OpenBLAS's hand kernels at 0.24 to 0.45 and clang's naive loop at 1.1 to 3.5 (M) | dense matrix products: LLM prefill and batches, physics, the linear layers | accumulators that persist across strips (the resume rule, section 4); `vlen`; **gates: 28,000 for the register file of 16 (M)** | **yes, with the resume rule decided** |
| 7 | an **int8 dot-product instruction** (4 byte products added into a 32-bit lane: `dp4a`, `sdot`, VNNI) | on the model of section 1, 2 times the multiply-adds a cycle of the plain widen-multiply-reduce form (E); not written as a form | the quantized layers of an LLM (`q8dot`, `q4dot`) | one or two words; a datapath of byte multipliers; **gates: 37,000 (M)** | **likely yes for a gpu-lite, to be measured** |
| 8 | **bit-field and nibble operations** (mask, shift, subtract on lanes) | `q4dot`: 11 block operations, 0.69 for each element (M); they are ordinary lane operations | 4-bit and 2-bit weights, packed pixels | none beyond row 1; **gates: about 3,000** | **yes** (in row 1) |
| 9 | a **vector exponential** (`vexp`), reciprocal square root, `silu` and `gelu` approximations | `softmax` is 5 operations in the block with it; without it the scalar `expf` is a call for each lane and clang's vector builds of `softmax` were 160 to 300 instructions (M); a GPU has these as special-function units (U) | attention (softmax), activations, audio and shading | **gates: 8,000 to 15,000 on the existing lanes (E)**; a table-driven unit and a precision rule (the ISA refuses transcendentals, `§9.7`: correct rounding; an approximate one is a different word, E) | **open: measure the share of the time in a real model** |
| 10 | **gather and scatter** (`vldx`, `vaddx`) | clang vectorized the histogram on none of six targets (M); the form is 11 instructions, 2 block operations for each element, with serialised conflicts (E) | embedding lookup (an LLM's first layer), sparse and indexed data, texture sampling in software, a histogram | the conflict rule for scatter; gather alone is simpler; **gates: 4,000 to 6,000 for one lane a cycle (M); more cache ports are wiring, not counted** | **gather: likely; scatter-add: open** |
| 11 | **strided and segment loads** (de-interleave 3 and 4 fields: `x y z w` of an array of structures) | **studied now (M, `arch-data/vec-forms/seg/`)**: four kernels of interleaved data (RGBA to gray, a stereo split, vertices of four floats, complex multiply); with segment loads and stores the forms are 7 to 19 instructions against 16 to 73 for pcc's scalar functions, and **1 to 5 block operations (7 to 25%) fewer than with strided loads**, and each field is read once instead of the whole cache line once for each field (E); clang vectorized all four, and its NEON code (`ld2`, `ld4`, `st4`) is half the size of the AVX2 shuffle sequences (`split`: 48 against 93; `vtxaos`: 88 against 148) and a quarter of LASX's (M) | vertices, RGBA pixels, complex numbers, stereo audio | a field count (2 to 4) and an element size in a word; **gates: 2,000 to 5,000 (M for the 8-bit network)** | **yes** |
| 12 | **predication and masks** (a bit for each lane; select under a compare) | masked loops were 14% of the vectorized loops of the codec (M, `vector-study.md`) | clipping, branchy shader-like code, the conditional parts of games | a mask register (state) or a select word; **gates: 2,000 to 4,000 (E)** | **open: to be studied** |
| 13 | **number formats**: fp16, bf16, int4, fp8 conversions | **not studied (N)**; model weights and activations are in these (U) | LLM weights and activations; half-float textures | conversion words, a datapath for each | **open** |
| 14 | the **tile with an outer-product** instruction (`vtfmopa`) | 0.047 block operations for each multiply-add, 3 operations for 64 (M) | dense matrix products; the prefill; batched decode | 256 bytes of tile at 256-bit strips (1 KiB for four, E): more state than the hidden vector registers, the resume rule, a datapath of VL x VL multipliers | **open; the largest benefit and the largest state** |
| 15 | the **whole-GEMM instruction** (`gemm.f`: a descriptor, two progress registers, one-tile restart) | 19 set-up instructions for any size (M); no instructions in the loop | prompt processing, batched decode, convolutions, attention products (small matrices are a weak case, E) | a matrix unit (a start-up cost, DMA of its own, caches); a descriptor format; the unit may be a device (`lb64`) or part of the core | **open; the decision between a CPU instruction and an accelerator** |

## 4. The one design question that the table shares

Rows 6, 14 and 15 keep partial sums that last across many strips (an accumulator), and the decision says nothing is saved at a context switch beyond the ordinary registers (R435, errata 139). Three ways out (`gemm-forms.md` §5a): save the accumulators at a context switch (state and time); restart a piece from its start (correct for a bounded piece: a tile, about 2 microseconds at K = 768; a whole GEMM livelocks against the timer tick); or write the partial sums to memory every so many strips. Rows 1 to 5, 7 to 10 keep nothing across strips beyond ordinary registers and need none of this.

## 5. A first reading (the assistant's, for the author to change)

1. **Rows 1 to 5 and 8 pay on every kernel measured, cost little state and little encoding, and are what games need today**: the 50 ms to 2 ms blend of section 1 is this. They are the base of a gpu-lite.
2. **For inference the question is rows 6, 7 and the number formats (13), not the tile**: decode of one token is a matrix-vector product, memory-bound only for a small model or a wide enough datapath, and compute-bound by 3 to 8 times at 7 billion parameters on one core (section 1); an int8 dot instruction (row 7) doubles it, a second vector unit doubles it again. The tile and the GEMM unit help the prefill and batched work, which a person on a laptop does less than decode.
3. **The tile and the whole-GEMM (14, 15) are the expensive operations, with real uncertainty about their value for the CPU-only user** (they are where a matrix unit or a GPU earns its area); the resume rule of section 4 is settled for a bounded piece, so the open part is whether the area and the power are worth it before the GPU exists.
4. **What this table cannot yet say**: dynamic counts (no simulator runs the operations), the area and the power of any of them (U, not measured), the real workloads (a game's frame, a model's token: only kernels here), and rows 9, 11, 12, 13 (studied little or not at all).

## 6. What would settle it (to do)

* A model of the block in `sim64` (or a separate simulator) so that dynamic instruction and operation counts can be taken on whole kernels and then on a real loop nest (a transformer layer from `cngpt`'s forward pass at its test size; a software-rendered frame of a small game).
* The missing studies: segment loads (11), predication (12), number formats (13), a table of vector exponential and reciprocal accuracy against what a language model tolerates (9).
* Power: a first estimate of the datapath area for the rows 7, 14 and 15 from published designs (U) and a comparison with a small GPU's energy for a token; none is on this machine.
* A **minimum viable gpu-lite**, stated as a set of rows: for example rows 1 to 5, 7, 8, 10 (gather) and 11, and the resume rule, as the first revision; 6, 9, 12 and 13 after their studies; 14 and 15 after the model of the CPU-only user.
