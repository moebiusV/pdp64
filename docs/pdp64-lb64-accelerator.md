# LB64 — A Q64 Accelerator for LittleBit Inference

[← pdp64 index](../README.md)

**DEC PDP-64: Digital Equity Collective's Pragmatic Digital Processor, 64 bit.** (11/64W was the working name under which this document was written.)

**Companion to the ISA ([`pdp64-isa.md`](pdp64-isa.md), originally written against revision 20) and the implementation plan ([`pdp64-fpga-plan.md`](pdp64-fpga-plan.md)).** Device-side design; touches the ISA only through ISA §16. Brought up to date with the changes since revision 20; see "Changes since revision 20" at the end and [`../CHANGES-SINCE-R20.md`](CHANGES-SINCE-R20.md). Section numbers of the ISA are unchanged.

Yes — the Q64 coprocessor referred to in ISA §4.6.2 and ISA §15.2, the three-class memory topology of revision 5 of the design, and "a GPU" in the sense of a bus-mastering accelerator sharing the CPU's DRAM are all the same thing. This document specifies it for one workload.

---

## 1. LittleBit-2 needs no new hardware over LittleBit

Taking the easy part first, because it changes the scope of the question.

LittleBit-2's contribution is **entirely at quantization time**. Samsung Research's description is explicit that it "does not propose a new architecture": it adds an offline rotation of the latent factors before binarization — a random rotation to make the coordinates Gaussian-like, then a Joint-ITQ orthogonal Procrustes solve for a shared rotation — and reports this costs about three seconds per layer once, with no inference cost at all. The rotation is absorbed into the stored factors.

The effect is to reduce the per-row binarization distortion λ(u) = 1 − (1/r)(‖u‖₁/‖u‖₂)², pushing mean distortion on their example layer from about 0.36 to about 0.30, which moves the break-even spectral decay exponent γ\* from ≈0.36 to ≈0.51 and so covers most Llama-2 7B layers.

**So an accelerator optimized for LittleBit-2 is an accelerator optimized for LittleBit.** The representation, the memory layout and the inference kernel are the same. Everything below serves both.

---

## 2. What the kernel actually is

For a layer with weight **W** ∈ ℝ^(d_out × d_in), LittleBit stores

```
Ŵ = diag(h) · U_sign · diag(ℓ) · V_signᵀ · diag(g)
```

with `U_sign ∈ {−1,+1}^(d_out × r)`, `V_sign ∈ {−1,+1}^(d_in × r)`, and FP16 scale vectors `h` (length d_out), `g` (length d_in), `ℓ` (length r). Two such paths exist — primary and residual — and their outputs sum.

Inference never materializes Ŵ. It evaluates

```
Y = (((( X ⊙ g ) · V_sign ) ⊙ ℓ ) · U_signᵀ ) ⊙ h
```

which at decode time (batch 1) is five steps:

| Step | Operation | Count |
|---|---|---|
| 1 | `x′ = x ⊙ g` | d_in FP16 multiplies |
| 2 | `z = x′ · V_sign` | **d_in × r sign-flip accumulates** |
| 3 | `z′ = z ⊙ ℓ` | r FP16 multiplies |
| 4 | `y = z′ · U_signᵀ` | **r × d_out sign-flip accumulates** |
| 5 | `y′ = y ⊙ h` | d_out FP16 multiplies |

### 2.1 The correction: this is not XNOR-popcount

ISA revision 13 §4.6.2 justified `XNORPOP` on the XNOR-net identity `dot(a,b) = n − 2·popcount(a ⊕ b)`. That identity requires **both** operands to be binary. Here the weights are binary and **the activations are FP16**. Popcount is not the primitive and `XNORPOP` is not this kernel's inner loop.

The primitive is instead

```
acc ← acc ± a        where the sign comes from one weight bit
```

a conditional add/subtract of a real value under a one-bit control. That is what "MatMul-free" means in the paper: there are no multiplications in either contraction. The only multiplies are the O(d_in + r + d_out) element-wise scalings, which are negligible against the O(d_in·r + r·d_out) contractions.

This is a better hardware target than popcount, not a worse one. See §3.

`XNORPOP` remains worth its `BESC` slot — for genuinely binary-activation networks, Hamming distance, bitset intersection cardinality, and garbage-collector mark counting — but ISA §4.6.2's stated rationale was wrong and was corrected in ISA revision 14.

### 2.2 Rank and size, concretely

From the paper's Eq. 17, for a 4096 × 4096 layer:

| Target bpw | Rank r | Sign bits, both paths | FP16 scales | Total per layer |
|---|---|---|---|---|
| 1.0 | 1006 | 2.0 MB | 33 KB | 2.1 MB |
| 0.55 | 546 | 1.07 MB | 33 KB | 1.1 MB |
| 0.1 | 86 | 172 KB | 33 KB | **209 KB** |

Two things fall out of that table.

**At 0.1 bpw the FP16 scales are 16% of the layer**, because they are O(d_in + d_out) while the sign bits are O(r·(d_in + d_out)) and r has collapsed. The scale path is not a rounding error in the design and cannot be an afterthought in the DMA schedule.

**The op count equals the sign-bit count exactly.** Every bit fetched drives exactly one accumulate, in both contractions. That is the single most useful fact for sizing:

> **lanes × clock = sign-bit bandwidth required.**

There is no arithmetic intensity to exploit and no blocking scheme that improves the ratio. The accelerator is bandwidth-bound by construction, and the only lever is where the bits live.

---

## 3. Datapath

### 3.1 The processing element

```
         weight bit s ──┐
                        ▼
   value a ──▶ [conditional negate] ──▶ [32-bit add] ──▶ acc
```

For a two's-complement fixed-point `a`, conditional negate is 32 XORs with `s` plus `s` into the adder's carry-in. For a float it would be a single XOR on the sign bit — **the multiplier array of a conventional accelerator is replaced by one XOR gate per lane.**

**Accumulate in fixed point, not floating point.** This is the decision that makes the design cheap, and it is available because the inner loop is add-only:

1. After step 1, find `max |x′|` in one pass over d_in — O(d) work, free against O(d·r).
2. Convert `x′` to 16-bit fixed point scaled by that maximum. This is block floating point with a per-vector exponent, which is exactly right here: every addend in a given contraction shares a magnitude scale, which is the condition under which fixed-point accumulation loses nothing.
3. Accumulate in 32 bits. Summing 4096 terms of 16-bit magnitude needs 16 + log₂4096 = 28 bits, so 32 gives four bits of headroom.
4. Convert back to FP16 at step 3 and step 5, where the scales are applied anyway.

A 32-bit integer adder with a conditional-invert input is roughly 64–80 ALUTs on Cyclone V — about 150 LE. An FP32 adder is nearer 600 LUTs. **The fixed-point decision buys a factor of four to five in lanes per LUT**, and the per-vector exponent is what makes it sound rather than merely cheap.

Stage 2's accumulation is over r terms rather than d_in, so it needs fewer headroom bits; share the same 32-bit lanes.

### 3.2 The two stages have opposite shapes

```
Stage 1 (contract over d_in):  one x′[j] broadcast to L lanes,
                               each lane taking its own bit from V[j, k]
                               → L partial sums for L different k

Stage 2 (contract over r):     L values z′[k] gathered,
                               each with its bit from U[i, k]
                               → one output y[i], L-way reduced
```

Stage 1 is **broadcast-and-scatter**: L independent accumulators, one input per step. Stage 2 is **gather-and-reduce**: L inputs per step, one accumulator, needing an L-input adder tree.

Both consume exactly L weight bits per step, which is the §2.2 invariant showing up as a hardware symmetry: one bit-fetch port of width L serves both stages. The adder tree for stage 2 is the only structure stage 1 does not use, and at L = 128 it is a 7-deep tree of 32-bit adders — about 4,000 LE, pipelined.

The intermediate vector `z` of length r stays entirely on chip. At r = 1006 and 32-bit accumulators that is 4 KB, one M10K block. **There is no round trip to DRAM between the two contractions**, which is the structural reason this is not just a GEMV engine with a narrow datapath.

### 3.3 Weight layout, and the uncomfortable coupling

Stage 1 wants, for a fixed block of L consecutive `k` values, the bits `V[j, k_block]` for j = 0, 1, 2, … — so **V must be packed k-major, blocked by L**: one L-bit word per (k_block, j).

Stage 2 wants `U[i, :]`, all r bits for one output row — so **U must be packed i-major**, r bits contiguous per i.

The two factors need different layouts, and V's layout **has the lane count baked into it**. Change L and V must be repacked.

Two ways out, and the second is better:

- Pack at the largest L the family will ever use and have narrower implementations read sub-words. Wasteful only in that a 64-lane part reads 256-bit words and uses a quarter at a time, which costs nothing if the DMA burst is that wide anyway.
- **Make L architecturally fixed at 256** and let implementations vary the number of *cycles* they take to consume a 256-bit word. A 64-lane part takes four cycles per word; a 256-lane part takes one. The packed format is then portable across the family, which matters because the packing is an offline step that produces artifacts people will want to keep.

Take the second. It is the same discipline as ISA §7.5: state the architectural granularity, let the implementation pick its own internal width.

---

## 4. Sizing on the actual boards

### 4.1 Lane count is set by DRAM, not by fabric

| Board | DDR, realistic | Lanes it can feed at 100 MHz | Fabric cost of those lanes |
|---|---|---|---|
| DE10-Nano (Cyclone V) | ~2 GB/s | **~160** | ~24K LE, about 22% of the device |
| Zybo Z7-20 | ~2.5 GB/s | ~200 | ~15% |
| KV260 (UltraScale+) | ~12 GB/s | ~960 | ~25% |

Take **128 lanes at 100 MHz on the DE10-Nano** — 1.6 GB/s of sign bits, inside the achievable DDR3 budget with headroom for the activation and scale traffic. Fabric is not the constraint; it never is for this kernel.

And note what is *not* on that list: **zero DSP blocks.** There are no multipliers in the contractions. All 112 of the DE10-Nano's DSPs stay available for the CPU's FPU and multiplier ([implementation plan](pdp64-fpga-plan.md) §2). A conventional FP16 MAC array of comparable width would need more DSPs than the board has.

### 4.2 Time per layer, and what the real comparison is

A 4096 × 4096 layer at 0.1 bpw, 128 lanes, 100 MHz:

```
1,409,024 sign-flip accumulates / 128 lanes = 11,008 cycles = 110 µs
```

Against FP16 on the same board, the compute comparison gives about 13× — which is roughly the paper's 11.6× kernel figure. **But for batch-1 GEMV the compute comparison is the wrong one.** The FP16 version must stream 33 MB of weights per layer, which at 2 GB/s is 16 ms. The LittleBit version streams 209 KB, which is 105 µs.

> The win is **160× in weight bandwidth** — 0.1 bpw against 16 bpw — and the compute reduction is secondary. Any design discussion that starts from operation counts will size this thing wrong.

### 4.3 What that makes possible on a $130 board

A 0.6B-parameter model body at 0.1 bpw is about 7.5 MB. At 2 GB/s that is 3.75 ms of weight streaming per token — a ceiling near 260 tokens/second from the weight path alone, and over 100 even at half the achievable bandwidth.

That is a striking number for a Cyclone V, and the project should not get attached to it, because §6 is where it goes wrong.

At 0.1 bpw the *other* direction opens too: a 209 KB layer fits in the DE10-Nano's 687 KB of BRAM, so two or three layers can be resident. Once weights are on-chip the kernel becomes compute-bound and the lane count can rise to whatever the fabric holds. For a small enough model, or a hot enough subset of layers, this is a different and better operating point.

### 4.4 The KV cache bonus

The paper notes that for K and V projections the quantity cached is the rank-r latent rather than the full d-dimensional output. At r = 86 against d = 4096 that is a reduction of roughly 48× in KV cache size, which at long context is usually the binding memory constraint rather than the weights. Worth confirming against the implementation before planning around it, but if it holds it is a larger practical win than the weight compression for anything conversational.

---

## 5. No instruction set — a descriptor chain

The question was what other devices with their own instruction sets would look like. For this one the answer is that **it should not have an instruction set**, and the reason is the argument from revision 5 of the design: the computation has exactly one shape, so a programmable sequencer would spend its silicon running the same program forever.

```c
struct lb_desc {
    u64 next;           /* 0 to stop; chains a whole transformer block     */
    u64 x, y;           /* activation in, result out                       */
    u64 g, l, h;        /* FP16 scale vectors                              */
    u64 v_sign;         /* k-major, 256-bit words  (§3.3)                  */
    u64 u_sign;         /* i-major, r bits per row                         */
    u32 d_in, d_out, r;
    u32 flags;          /* ACCUM: add into y, for the residual path        */
                        /* ONCHIP: weights already resident in BRAM        */
    u32 status;         /* written back on completion                      */
};
```

One descriptor per path. A layer is two descriptors, the second with `ACCUM`. A transformer block is a chain, and the CPU writes the chain once and is then idle — which is how every competent DMA engine since the RK11 has worked, and it is what keeps a 60 MHz scalar core from being the bottleneck.

The `status` write-back plus a completion interrupt is the whole control interface. No command FIFO is needed when the descriptors are themselves the queue.

---

## 6. What LB64 does not do, which is the actual problem

LB64 covers the projections and the MLP — everything with a quantized weight matrix. The rest of a transformer layer has no weights to compress, and **this is where the 260 tokens/second of §4.3 goes to die.**

### 6.1 Attention is not helped at all

`QKᵀ` and the subsequent `·V` are activation against activation. There are no binary weights, so there is nothing for LittleBit to compress and nothing for LB64 to accelerate. Those are real FP multiplies.

For batch 1, sequence length 2048, 32 heads of 128 dimensions: about 8.4M MACs per layer for the scores and as many again for the weighted sum. That is **more arithmetic than the LittleBit contractions in the same layer** (1.4M), and it needs multipliers rather than XOR gates.

> At any useful context length, attention dominates, and sub-1-bit weight quantization does not touch it.

This is the non-obvious consequence of taking the format seriously. **But §12 revises what to do about it.** Profiling the whole token shows attention dominates as a *bandwidth* problem — reading the KV cache is 68% of the cost at sequence 2048 — not as a compute problem. So the first move is shrinking the cache, and `MX64` should be sized only afterwards. §10.3 confirms `MX64` is the engine training needs too, so it is still the right second engine; it is not the right *first* optimization.

### 6.2 The elementwise work needs somewhere to go

RMSNorm, softmax, SiLU or GELU, RoPE, and the residual adds are O(d) per layer — about 1% of the operations. But on a 60 MHz scalar core with no vector unit, 4096 elements through a transcendental is on the order of a millisecond per layer, and 32 layers of that is 44 ms per token. The 1% of operations becomes the majority of the time.

So a small **VEC64** is worth having: 8 to 16 FP16 lanes, a small vector register file, and `add`, `sub`, `mul`, `max`, plus reductions and low-precision `exp`, `reciprocal` and `rsqrt` by table-and-interpolate.

And note where that lands relative to ISA §9.7. The CPU correctly refuses transcendental instructions, because libm needs correctly-rounded results over the whole argument range and x87's attempt is the cautionary tale. An activation function needs nothing of the kind — a few percent error in a GELU is invisible. **Fast approximate transcendentals belong in the accelerator, at the accelerator's accuracy target, and that is not an exception to ISA §9.7 but a consequence of it:** the two have different requirements, so they belong in different places.

### 6.3 Why the text codecs do not belong in a helper chip

A natural suggestion is to put the UTF-8 and string codecs in a helper alongside this one, since both are streaming transformations over bytes. It is the wrong split, and the reason is latency rather than area.

**Per-character work must be in the CPU.** A lexer, a terminal emulator, a tokenizer or a JSON parser decodes the *next* character and immediately branches on it. There is nothing to batch, and a bus round trip to a helper is tens of cycles against the four-byte `BESC` instruction it would replace (ISA §4.6.1, about 400 LUTs). The descriptor setup alone would cost more than the work for every string shorter than a kilobyte, which is most strings in most programs.

**Whole-buffer work belongs in `MBLK`, not in a helper either.** Validating a 10 MB document is genuinely bulk work, but ISA §4.7.1's `MVAL` already does it by wiring the validity comparators that exist for `UTF8DEC` to the block sequencer that exists for `MCPY`. It costs no opcode, no bus transaction and no DMA descriptor. A helper chip would need its own copy of both.

So the split is per-character in `BESC`, per-buffer in `MBLK`, and nothing in a helper. The LLM accelerator is in a helper for the opposite reason: its working set is megabytes, its operations are millions of cycles long, and its weights never touch the CPU's cache. Those are the properties that pay for a bus crossing, and text codecs have none of them.

### 6.4 The resulting partition

| Engine | Work | Primitive |
|---|---|---|
| **LB64** | projections, MLP | sign-flip accumulate, no multipliers |
| **MX64** | QKᵀ, scores·V | FP16 MAC, FP32 accumulate — needs the DSPs after all. §10.3 shows this is also the training engine |
| **VEC64** | norm, softmax, activation, RoPE | FP16 elementwise and reductions, approximate transcendentals |
| CPU | descriptor chains, sampling, tokenizer, everything else | §5 |

Three small engines fed by descriptor chains, each doing one thing with its own local memory. That is revision 5's reading of Moore's GA144 applied to a workload that happens to suit it unusually well.

---

## 7. Bus integration

LB64 is a Q64 **initiator**, not merely a target. It DMAs sign-bit blocks, scale vectors and activations from the same DRAM the CPU uses, and writes results back.

That has one consequence worth naming, because it is already an open question: **a bus-mastering accelerator is what forces ISA open item 4 to be resolved.** The Unibus-derived `DATIP`/`DATO` locked read-modify-write carried into Q64 is a lock; AXI exclusive access is a monitor; and the moment there are two initiators contending for a descriptor's `status` word, the difference stops being academic. Settle it in the bus document before LB64 exists, not after.

Coherence, in the simplest correct form:

1. CPU builds the descriptor chain and the activation vector in memory mapped `MT = 01`, normal uncached (ISA §8.2 — the memory-type field that revision 13 added for the framebuffer serves this identically).
2. `FENCE`.
3. CPU writes the doorbell.
4. LB64 walks the chain, DMAs weights, computes, writes `y` and `status`, raises an interrupt.
5. CPU reads `y`.

No cache coherence protocol, no snooping, no shared-cache complexity. This is the "shared-structure" class from revision 5's three-class topology, and uncached-by-page-attribute is what makes it free.

---

## 8. What this means for the ISA

**Nothing**, which is the point of ISA §16. LB64 needs exactly the three things the ISA already owes devices: a memory type per page, a `FENCE` with defined meaning against Q64, and atomics that reach device memory.

One correction propagated back. ISA §4.6.2's rationale for `XNORPOP` was wrong about which workload it serves (§2.1 above); ISA revision 14 replaced the rationale and kept the instruction, whose other uses stand. ISA revision 20 then moved `ROR` into `BESC` alongside it for an unrelated reason, so the bit-manipulation group is now where both live.

And the broader claim in ISA §15.2 — that wide data-parallel work belongs off the scalar core rather than in an AVX-style extension — holds up under this exercise, and for a sharper reason than the one given there. SIMD in the CPU would have cost a second wide register file (the thing ISA §2.3 specifically avoided), wide load/store paths entangled with the alignment rules of ISA §7.4, and a large opcode space from a map that ISA revision 20 reallocated by frequency. LB64 needs **no ISA opcodes at all**, runs concurrently with the CPU rather than blocking it, and can be sized independently of the CPU's clock. For a machine this size that is not close.

---

## 9. Open questions

1. **Lane count as architecture.** §3.3 proposes fixing the packed-word width at 256 bits and letting implementations vary cycles-per-word. That makes the offline packing portable but commits a number before any measurement exists. Check it against the DE10-Nano's DDR burst length first.

2. **Where the scales live.** At 0.1 bpw the FP16 scales are 16% of a layer (§2.2) and are read in a completely different pattern from the sign bits — sequential and short, against long streaming reads. They may want their own DMA channel rather than sharing one, which is a decision about the Q64 interface rather than about LB64.

3. **`MX64` versus widening LB64.** §6.1 says attention dominates at useful context lengths, and §10.3 says the same FP array serves gradient GEMM, so `MX64` is the right thing to build next on two independent grounds. What is still open is its size. Before committing DSPs, profile a real model at a real sequence length — the intuition that the quantized layers are the hard part is probably wrong.

4. **BRAM residency strategy.** §4.3 notes that a 0.1 bpw layer fits on chip, and §13.2 shows the whole working set fits in SRAM at a modern node — so this question is really "how much of §12.3's floor can be bought back with on-chip memory," at every scale from one BRAM to a 4 nm die. Whether to hold a working set of layers, cache them with some replacement policy, or just stream everything is a question with a different answer for a 0.6B model than for a 7B one, and the `ONCHIP` descriptor flag is a placeholder for an unmade decision.

5. **Verifying against the reference kernel.** The paper's CUDA kernel is the correctness oracle, and the fixed-point accumulation of §3.1 will not be bit-identical to it. Establish an acceptable error bound against FP32 reference output before building, not after, or there will be no way to tell a hardware bug from accumulated rounding.

6. **Does the KV latent caching hold?** §4.4 would be the largest practical win in this document if it does. Confirm it from the implementation rather than from the summary.

---

---

## 10. A training accelerator is a different engine

Revision 15 of this document answered "can this machine train" (no) rather than "what would an accelerator for training look like", which was the question. Answering the right one produces a design, and the design is **not** LB64 with extra lanes.

### 10.1 Why it cannot be LB64

| | LB64 (inference) | Training engine |
|---|---|---|
| Batch | 1 | 8–256 |
| Shape | GEMV | **GEMM** |
| Reuse per weight fetch | **1** — op count equals bit count (§2.2) | **O(batch)** |
| Bound by | weight bandwidth | compute, if tiled |
| Inner primitive | sign-flip accumulate, one XOR | **FP multiply-accumulate** |
| Accumulator | 32-bit fixed point (§3.1) | **FP32** |
| Weights | ±1, read-only | ±1 forward, FP32 latent updated |
| Dominant memory | weights | **optimizer state and stored activations** |

Three of those rows invert the decisions that make LB64 cheap. **Arithmetic intensity appears**, so the right structure is a systolic array with weights held stationary and data flowing through, not a streaming reduction. **The multipliers come back**, because the backward pass computes `dX = dY·W` and `dW = dYᵀ·X` on full-precision gradients and there are no binary weights to exploit — quantization-aware training keeps an FP latent and a straight-through estimator, so **LittleBit's advantage vanishes entirely in the backward pass.** And **accumulation must be FP32**, because summing thousands of small gradients in FP16 rounds them to nothing.

### 10.2 The design choices that matter, in order

**1. Train in the factored space, not the weight space.** This is the largest single win and it is algorithmic rather than architectural — the hardware should be built around it.

If the trainable parameters are `U`, `V`, `ℓ`, `g`, `h` rather than `W`, then for a 4096² layer at r = 86 there are 2 × 86 × 4096 ≈ 704 K sign parameters plus about 8 K scales, against 16.7 M weights. **A 24× reduction in trainable parameters, and the optimizer state falls with it.** This is what LittleBit's own QAT recipe does; an accelerator should assume it rather than supporting dense weight training as well.

**2. Optimizer state is the memory problem, by three orders of magnitude.**

| Per parameter | Bytes |
|---|---|
| LittleBit weight at 0.1 bpw | 0.0125 |
| Adam first and second moment, FP32 | 8 |
| FP32 master / latent weight | 4 |
| **ratio** | **~960×** |

Compressing weights to a tenth of a bit while carrying twelve bytes of optimizer state per parameter is optimizing the wrong term. Two mitigations, both worth building into the engine rather than leaving to the host:

- **Factored second moments**, Adafactor-style: store row and column factors instead of the full second-moment matrix, O(m+n) instead of O(m·n). For a 4096² matrix that is 8 K floats against 16.7 M — and it is the same factorization idea the weights already use, which makes it a natural fit rather than a bolt-on.
- **Block-wise 8-bit moments**, bitsandbytes-style: 2 bytes per parameter instead of 8. The quantize/dequantize pair in the update path is a small fixed-function unit, and it belongs in the engine because the update is where the state is touched.

**3. The straight-through estimator is a hardware element.** The forward pass needs `sign(U)`; the backward pass accumulates the gradient into `U` through a clip mask (`|U| < 1`). So between the FP32 latent storage and the binary compute array sits a unit that extracts sign bits going forward and does masked FP accumulation coming back. Small, and it is what makes QAT efficient rather than a simulation of QAT.

**4. Bit-matrix transpose is free in fabric, and it changes the memory layout decision.** The backward pass needs `Uᵀ` and `Vᵀ`. Transposing a bit matrix is a real operation in software — about six rounds of mask-shift-XOR for a 64×64 block by the *Hacker's Delight* method — but **in an FPGA a 64×64 bit transpose is pure routing**: 4096 wires, no logic, no DSPs. So a transpose unit costs essentially nothing and removes §3.3's awkward conclusion that `U` and `V` need different packings. Store one layout and derive the other.

**5. FP32 accumulate, with loss scaling and overflow detection.** FP16 gradients underflow, so training scales the loss up before the backward pass and down after. The scaling itself is a power-of-two multiply and free. What is *not* free and is easy to forget: a **sticky overflow flag per batch** that the host reads to adjust the scale dynamically. Without it, dynamic loss scaling cannot work and training silently diverges.

### 10.3 The engine inventory, consolidated

Writing this out produced a simplification of §6.4. **The attention engine and the training engine are the same hardware at different sizes** — both are FP multiply-accumulate arrays with FP32 accumulation. There is no reason to design two.

| Engine | Inference role | Training role | Primitive |
|---|---|---|---|
| **LB64** | projections, MLP | **forward *and* backward through frozen layers** (§10.4) | sign-flip accumulate; no multipliers |
| **MX64** | attention — `QKᵀ`, scores·`V` (§6.1) | **gradient GEMM, both directions** | FP16 multiply, FP32 accumulate, systolic |
| **VEC64** | norm, softmax, activation, RoPE (§6.2) | the same, plus gradient reductions and clipping norms | FP16 elementwise and reductions |
| **BT64** | — | bit-matrix transpose — **required for any backward pass**, not just full fine-tuning (§10.4) | routing only, no logic |

`MX64` replaces §6.4's `ATT64`, which was the same array under a narrower name. That consolidation is the practical finding here: building the FP array for attention at inference time gets most of a training engine, and sizing it is the one decision that serves both.

### 10.4 LoRA: where the dataflow actually lands

Revision 17 of this document said LB64 handles "the forward pass" of a fine-tune. That understated it. Working the gradients through properly, **LoRA is about 99% LB64 work, in both directions.**

LoRA replaces the effective weight with `W_frozen + B·A`, where `A` is r × d_in and `B` is d_out × r for a small r — typically 8 to 64. Only `A` and `B` train.

| Work | Share of FLOPs | Engine |
|---|---|---|
| forward through frozen `Ŵ` | ~50% | **LB64** |
| backward `dx` through frozen `Ŵ` | ~50% | **LB64** |
| adapter forward `x·Aᵀ·Bᵀ` | <1% | MX64 |
| adapter gradients `dA`, `dB` | <1% | MX64 |
| optimizer step on ~5 M parameters | negligible | VEC64 or the CPU |

**The backward pass through a frozen LittleBit layer is the same kernel as the forward pass.** If `y = x·Ŵᵀ` then `dx = dy·Ŵ`, which expands to

```
dx = (((( dy ⊙ h ) · U_sign ) ⊙ ℓ ) · V_signᵀ ) ⊙ g
```

Compare §2's forward expression: identical structure, with `U` and `V` exchanged and `h` and `g` exchanged. Two binary contractions with a rank-r intermediate on chip. **No new hardware, no multipliers, the same sign-flip array.** That is why LB64 covers both halves of a LoRA step rather than just the forward one.

**What does change is the layout, and this is why `BT64` is not optional.** §3.3 established that stage 1 wants its sign matrix packed k-major in lane-width blocks (broadcast-and-scatter) while stage 2 wants i-major rows (gather-and-reduce). In the backward pass the two matrices swap roles, so each is needed in *both* layouts across a full step. Two ways out:

- **Store both layouts.** Doubles sign-bit storage — 0.1 bpw becomes 0.2 bpw, which is still almost nothing. Zero logic, zero latency. For LoRA this is the better answer, because the frozen weights are read-only and the second copy is written once at load time.
- **Transpose on the fly with `BT64`.** Zero storage, and in fabric a 64 × 64 bit transpose is 4,096 wires with no logic at all. The right answer for *factored* fine-tuning (§10.2 item 1), where `U` and `V` are themselves updating and maintaining two copies would mean writing both every step.

So: both layouts for a frozen-weight LoRA, `BT64` when the factors train.

**And training is less bandwidth-bound than inference, which inverts §4.1.** §2.2's invariant — one accumulate per weight bit, no arithmetic intensity — holds only at batch 1. At batch *B* the activation is `[B × d_in]`, so stage 1 performs `B × d_in × r` operations against the same `d_in × r` sign bits:

> **Arithmetic intensity is *B*.** A LoRA step at batch 32 fetches each weight bit once and uses it thirty-two times.

Batch-1 decoding is the hardest case for this hardware, not the easiest. At batch 32, §4.1's conclusion that 128 lanes saturates the DE10-Nano's DRAM no longer applies — the engine becomes compute-bound and fabric is the limit again, so a wider array pays. That is worth knowing before sizing anything: **size the array for the training batch, not for batch-1 inference.**

### 10.5 What the numbers permit

Pretraining is out, and arithmetic rather than opinion says so. A 0.6 B-parameter model from scratch is on the order of 10¹⁹ FLOPs. An `MX64` sized to a DE10-Nano's 112 DSPs is perhaps an 8×8 or 10×10 FP16 array, about 12.8 GFLOP/s; a KV260 with 1,200-plus DSPs supports roughly 32×32 and about 200 GFLOP/s. Ten to the nineteenth at 12.8 GFLOP/s is roughly twenty-five years, and no instruction-set or dataflow decision moves a number like that.

**Fine-tuning is in, and it is the interesting case.** A LoRA-style adaptation of that model — rank 16 on the attention and MLP projections, perhaps 5 M trainable parameters against 0.6 B frozen — spends most of its FLOPs on the forward pass through frozen LittleBit weights, which is exactly what LB64 is for. Ten million training tokens comes to something near 10¹⁶ FLOPs:

| Board | `MX64` scale | Order of magnitude |
|---|---|---|
| DE10-Nano | 8×8 FP16, ~12.8 GFLOP/s | **a week to ten days** |
| KV260 | 32×32 FP16, ~200 GFLOP/s | **overnight** |

That is the difference between impossible and merely slow, and it is the regime worth designing for. Three things stack to get there: factored-space training cuts the parameter count ~24×, LoRA cuts the trainable set another ~100×, and the frozen forward pass still gets LB64's 160× bandwidth advantage (§4.2).

### 10.6 Not worth building

- **FP64 anything.** Training is FP16 or BF16 forward with FP32 accumulate. Double precision appears nowhere in the workload.
- **A sparse engine.** Structured sparsity is unsettled research and the hardware is complex for an uncertain factor.
- **Distributed training.** One board, one engine. Gradient all-reduce across devices is a bus and network problem that this machine has no reason to take on.
- **Dense weight training.** §10.2 item 1 makes the factored space the design point; supporting both doubles the engine for the case that does not fit in memory anyway.
- **An instruction set for the engine.** §5's descriptor chain extends to training without change: a chain per layer, `ACCUM` flags for the gradient sums, and the sticky overflow flag read back in the status word.

### 10.7 The division that holds

**Quantize on a host, fine-tune on the device, infer on the device.** LittleBit's quantization step is a truncated SVD plus roughly fifty Procrustes iterations per layer — Samsung reports about three seconds per layer on real hardware, and an SVD of a 4096² matrix is on the order of 10¹¹ FLOPs. That belongs on a workstation and its output is an artifact this machine loads. Everything after it fits here.

---

## 11. Scaling out: the ten-thousand-unit question

The arithmetic works, which is why the idea is worth taking seriously enough to refute properly. §10.5 puts pretraining a 0.6 B model at about twenty-five years on one DE10-Nano. Divided by ten thousand units that is **21.9 hours** — one night, as asked.

It does not work, for three independent reasons, and only the first is about money.

### 11.1 Ten thousand boards is a fifth of one GPU

Being generous to the FPGA: the DE10-Nano's 112 DSP blocks support perhaps 100 usable FP16 multiply-accumulates, which at 100 MHz is **20 GFLOP/s**. Ten thousand of those is 200 TFLOP/s.

| | FP16 dense | Power | Price |
|---|---|---|---|
| 10,000 × DE10-Nano | **200 TFLOP/s** | ~60 kW | ~$1.5 M |
| 1 × H100 SXM5 | **989 TFLOP/s** | 700 W | ~$30 K |

Ten thousand boards deliver **one fifth** of a single H100. Matching one H100 takes roughly fifty thousand of them. Normalized:

- **~250× worse per dollar** — $7,500 per TFLOP/s against $30.
- **~420× worse per watt** — 300 W per TFLOP/s against 0.71.

Those ratios are not an argument against FPGAs; they are what dedicated silicon at a modern process node buys, and an H100 is about 80 billion transistors of it against a Cyclone V's few million logic elements. The conclusion is narrower than "FPGAs are bad": **this hardware's value is not throughput per dollar, and it should never be defended on that ground.**

### 11.2 The all-reduce eats the parallelism

Data-parallel training synchronizes gradients every step. For a 0.6 B model that is 1.2 GB of BF16 gradients, and a ring all-reduce moves roughly twice that per node.

Over gigabit ethernet at 125 MB/s: **about 19 seconds per step, per node.** The compute it is hiding, with the work split ten thousand ways, is on the order of half a second. **The fabric is 38× slower than the compute it serves**, so ten thousand units deliver the throughput of roughly two hundred and sixty.

Faster networking fixes the ratio and breaks the budget. At 400 Gb/s InfiniBand the all-reduce drops to about 48 ms and the system becomes compute-bound — but ten thousand ports of 400 G, with the switch hierarchy and optics to make them non-blocking, costs many times the $1.5 M of boards. The interconnect would be the product and the compute an afterthought.

And a further problem precedes all of this: a 0.6 B model with FP32 Adam state needs about 8.4 GB per replica, against the DE10-Nano's **1 GB**. Pure data parallelism does not fit at all, so it would have to be ZeRO-3 or FSDP with parameters gathered from the network every layer — which multiplies the communication rather than reducing it.

### 11.3 A small model cannot absorb a ten-thousand-way batch

This one is statistical, and no interconnect fixes it.

Data parallelism across *N* units means a global batch of at least *N* samples. Beyond a model's **critical batch size**, additional samples per step stop reducing the number of steps proportionally — the extra gradient information is redundant, and loss-per-token gets worse. AI2's direct measurements on OLMo put the critical batch size plateauing **around 4,096**, and find it depends mainly on the quantity of data rather than on model size, so a larger model does not raise the ceiling much.

Ten thousand units at one sample each is already past that plateau, and one sample per unit is the *floor*. So the parallelism cannot be spent usefully on data even with a perfect network. The alternative is tensor and pipeline parallelism to split the model itself, which communicates inside every layer and therefore needs the fastest link in the system — the opposite of what a shelf of commodity boards provides.

### 11.4 How the labs actually do it

Not one kind of parallelism but four or five, arranged so that **the chattiest form sits on the fastest link.** That principle is the whole design.

| Dimension | What it splits | Communication | Where it runs |
|---|---|---|---|
| **Tensor (TP)** | individual matmuls | all-reduce *inside every layer* | NVLink within one node, ≤8 GPUs — never crosses nodes |
| **Pipeline (PP)** | layers | activations at layer boundaries only, small | across nodes |
| **Data (DP)** | samples | all-reduce per step, and overlappable | across the widest span |
| **Sequence / context** | the sequence dimension, for long context | Ring Attention and relatives | wherever TP is |
| **Expert (EP)** | MoE experts | all-to-all routing | within fast domains |

Layered on top:

- **ZeRO / FSDP** shards optimizer state, then gradients, then parameters across the data-parallel ranks, cutting per-rank memory by roughly the rank count — which is what makes a model larger than one device's memory trainable at all.
- **BF16 rather than FP16**, because it has FP32's exponent range and therefore needs no loss scaling. FP8 on Hopper and Blackwell for the GEMMs themselves.
- **Activation checkpointing** — recompute activations in the backward pass instead of storing them, roughly a third more compute for a large memory reduction.
- **Flash Attention** — tile the attention computation so the N² score matrix is never materialized, making attention memory-linear in sequence length.
- **Overlapping the all-reduce with the backward pass** — begin reducing layer *N*'s gradients while computing layer *N−1*'s. This single technique is what lets data parallelism scale at all; without it §11.2's ratio applies to everyone.
- **Gradient accumulation** — several microbatches per optimizer step, amortizing the all-reduce over more compute, and trading directly against the critical batch size of §11.3.

Megatron-LM and DeepSpeed are the reference implementations, and the hard part of a large run is not the arithmetic but this scheduling.

### 11.5 Where many units genuinely do win

The lesson is not that parallelism fails. It is that **parallelism works exactly where there is no all-reduce** — and there is one such workload here, which happens to be the one this hardware is for.

**Inference serving is embarrassingly parallel.** Independent requests, no gradient synchronization, no shared state. Ten thousand units each sustaining on the order of 100 tokens/second on a 0.6 B LittleBit model is roughly **a million tokens per second aggregate, scaling linearly, with no interconnect at all** beyond a load balancer. Every argument in §11.1 through §11.3 evaporates, because none of them is about compute — they are all about synchronization.

So the honest division: **rent GPUs to pretrain, fine-tune on one board (§10.4), and scale out only for serving.** A shelf of these is a serving fleet, not a training cluster.

---

## 12. Optimizing inference: where the time actually goes

§6.1 said attention dominates at useful context length. That was half right in a way worth correcting, because it pointed at the wrong fix. Attention dominates — but as a **bandwidth** problem, not a compute problem, and the thing to shrink is the KV cache.

### 12.1 The profile

A 0.6 B-class model, assumed configuration: 28 layers, d = 1024, d_ff = 3072, eight KV heads of 128 under grouped-query attention, 150 K vocabulary, weights at 0.55 bpw. Batch 1, sequence 2048, on a DE10-Nano at roughly 2 GB/s and an initial 64-MAC `MX64`.

| Cost per token | Bytes moved | Time at 2 GB/s | Compute time | Share |
|---|---|---|---|---|
| **KV cache read** | **235 MB** | **117 ms** | — | **68%** |
| attention MACs (235 M) | — | — | 37 ms, 64-MAC array | 22% |
| body weights, 28 layers | 20 MB | 10 ms | 11 ms, 128 lanes | 6% |
| LM head | 11 MB | 5 ms | 6 ms, 128 lanes | 4% |
| **total** | **266 MB** | | **~171 ms** | **≈6 tok/s** |

Two things in that table were not obvious before computing it.

**The KV cache read is two thirds of the cost, and it is pure bandwidth.** Every token must read the entire cache: 28 layers × 2 × 2048 positions × 1024 dimensions × 2 bytes. No amount of array width touches it. This is the number that matters, and §6.1's framing — that a second compute engine was the priority — was aimed one step past the real problem.

**The LM head alone rivals half the body.** One 1024 × 150 000 projection is 11 MB and 80 M operations, against 20 MB and 146 M for all twenty-eight layers. It is a quarter of the model's parameters in one matrix and it is easy to leave out of a budget.

### 12.2 The ladder, in order of payoff

**1. Quantize the KV cache to int8.** Halves 235 MB to 117 MB. Standard practice, negligible quality cost at eight bits, and it needs nothing from the architecture beyond the `MT` attribute already present.

**2. Cache the rank-r latent, not the full projection.** §4.4's observation, now load-bearing rather than incidental: if K and V are stored as their rank-r latents, the cache dimension falls from 1024 to r. At r = 124 that is **8.3×**.

Stacked with int8, the two take 235 MB to **14 MB — a 16× reduction, and the single largest optimization available anywhere in this document.**

**3. Then widen `MX64`.** Once the cache fits, attention compute becomes the limit. 64 MACs gives 37 ms; 256 gives 9 ms; 1024 gives 2 ms. Size it against the profile after step 2, not before — sizing it first would have bought almost nothing.

**4. Tile attention, Flash-Attention style.** Never materialize the N² score matrix. Saves on-chip storage and a second pass over the scores, and it is a dataflow choice in `MX64` rather than new hardware.

**5. Then the LM head.** 11 MB and 80 M ops for one matrix. The structural shortcut is that sampling needs only the top few candidates, not all 150 000 logits — but every scheme for exploiting that changes the sampling distribution, so it is a correctness question before it is a performance one. Worth knowing the cost before deciding.

**6. Watch the sampler.** Top-k and top-p over 150 K logits on a 100 MHz scalar core is on the order of ten milliseconds, comparable to a whole token of compute. Use `VEC64`'s max and sum reductions and a threshold pass rather than a sort; never sort 150 K elements on the CPU.

After steps 1 through 4, the same model looks like:

| | Before | After |
|---|---|---|
| KV cache | 117 ms | **7 ms** |
| attention compute | 37 ms | **9 ms** (256 MACs) |
| body weights | 11 ms | 11 ms |
| LM head | 6 ms | 6 ms |
| **per token** | ~171 ms | **~33 ms** |
| | ≈6 tok/s | **≈30 tok/s** |

### 12.3 The floor, and what it means

After those optimizations the machine moves about 45 MB per token — 14 MB of cache, 20 MB of body weights, 11 MB of head. At 2 GB/s that is **22 ms, or 45 tokens/second, and no amount of compute goes faster.**

> **This is a memory-bandwidth machine.** Bytes per token divided by bandwidth is the floor. Lane counts, array widths and CPU clock are all secondary, and every optimization worth doing is a reduction in bytes moved.

Which also settles the CPU-or-accelerator question. The CPU issues descriptors, runs the sampler and does the tokenizer; that is single-digit milliseconds and it does not care whether it runs at 50 MHz or 1 GHz. **Nothing about inference performance argues for a faster scalar core.** The ISA work in revisions 13 through 17 earns its keep for the operating system, the compiler and the Lisp runtime — not for this.

---

## 13. What converting to an ASIC actually buys

An FPGA design does convert to standard-cell silicon, and it is much faster. But the gain is not where it looks, and the node the question assumed is the wrong one by two orders of magnitude in cost.

### 13.1 The clock

Two multipliers stack. The long-standing measurement of the FPGA-to-ASIC gap in the *same* process — Kuon and Rose's study is the canonical one — puts FPGAs at roughly 3–4× the critical-path delay, 20–35× the area, and 10–14× the dynamic power of standard cells. Then 28 nm to a 4 nm-class node adds perhaps 3–5× in achievable frequency across four or five generations.

So 50–80 MHz on a Cyclone V becomes roughly **0.5–1.5 GHz**, a 10–20× improvement.

**The architecture is the ceiling, not the process.** A non-pipelined machine's cycle time is the entire datapath — fetch, decode, address generation, TLB, cache, ALU, writeback — so around 1 GHz it stops being a fabric question. Going further means pipelining, and the [implementation plan](pdp64-fpga-plan.md)'s risk 2 already notes that pipelining a machine with memory operands and precise faults is not a small change. Four nanometres does not make that change smaller.

### 13.2 At 4 nm the CPU is free, and that is the real finding

The core is about 92,000 transistors (ISA §10). At 4 nm densities of 100–150 million transistors per mm², that is **roughly 0.001 mm²** — a speck. The die would be entirely SRAM, I/O pads and accelerator array; the processor would not be visible on a floorplan.

So "convert the CPU to 4 nm" is not a meaningful optimization target. The design question at that node is **how much SRAM and what memory interface**, and the CPU comes along for free.

**And that reframes §12.3 completely.** At 0.55 bpw the body weights are 30 MB, the LM head 11 MB, and an int8 latent KV cache 14 MB — **about 55 MB in total, which fits in the SRAM budget of a modest 4 nm die.** With the working set on chip there is no DRAM bottleneck, the floor of §12.3 disappears, and LB64's lane count can rise into the thousands before anything saturates. That is what a node shrink buys for inference: **capacity, not clock.** A 20× faster scalar core would change the token rate by a few percent; holding the model in SRAM changes it by one to two orders of magnitude.

### 13.3 But not at 4 nm

The non-recurring cost makes this the wrong target for a project of this size. A 4 nm mask set alone is in the tens of millions; add full EDA flow licences, memory compilers and standard-cell libraries, DDR and PCIe PHY IP, a physical-design team, packaging and test, and the realistic figure is **$30–100 million** before a single wafer.

The nodes worth considering instead:

| Path | NRE, order of magnitude | Expected clock | What it is good for |
|---|---|---|---|
| **SKY130 / IHP130 open shuttle** | $10 K | 100–200 MHz | real silicon you can hold, at roughly FPGA speed. The right first tapeout |
| **TSMC 65 nm or 28 nm MPW** | $50–150 K | 300–600 MHz | a genuinely faster part, a few mm² on a shared mask |
| **GlobalFoundries 22FDX** | $0.5–1 M | 1 GHz+ | low power, enough SRAM to matter |
| 4 nm | $30–100 M | 1–1.5 GHz without pipelining | not this project |

A 130 nm shuttle run is the interesting one despite being no faster than the FPGA, because it converts the design from a configuration into a device, and it validates the whole flow — timing, power, test, packaging — at a cost that does not require a company behind it. If more speed is wanted after that, 28 nm is the step that pays, and 22FDX is where on-die SRAM starts to be large enough to attack §12.3's floor.


---

## 14. Putting the processor in the memory

§12.3 found that this is a memory-bandwidth machine and §13.2 that a node shrink buys SRAM rather than clock. The logical next question is whether the compute can move to the memory instead. It can, the field is called processing-in-memory, and there is a hard process constraint that decides the shape of every answer.

### 14.1 A 4 nm CPU cannot go on a DRAM die

DRAM and logic processes are nearly incompatible, and not by accident — each is optimized for something the other does not want.

A DRAM process exists to form dense storage capacitors and to hold charge, so its transistors are built for **low leakage rather than speed**, and the die carries only three or four metal layers because the array needs almost no routing. A logic process accepts high leakage to get fast transistors and stacks fifteen or more metal layers for routing. "4 nm" is also a logic-process designation; DRAM's leading nodes are a different naming scheme entirely and are roughly 12–14 nm in effective terms.

So the choice is not *what node* but *which die*. Three architectures are real, and they differ in which side of that boundary the compute sits on.

### 14.2 The three real architectures

**Logic in the DRAM process — true PIM.** UPMEM is the existence proof and is almost exactly what the question proposes: a simple 32-bit RISC core, one per 64 MB DRAM bank, eight per chip and 128 per DIMM, clocked at **350 MHz** with the designers suggesting 400 MHz is reachable. Measured bank bandwidth is **624 MB/s per core**, aggregating to about 1.6 TB/s across a 2,556-core system against roughly 20 GB/s for the DDR bus it replaces.

What the DRAM process costs is worth quoting precisely, because it decides §14.3. A UPMEM core has **no 32 × 32 multiplier** — multiply and divide run as multi-cycle step instructions taking up to 32 cycles — and **no floating-point hardware at all**. FP32 addition is emulated at about 4.9 MOPS per core, more than an order of magnitude below its integer throughput.

And: **the cores cannot talk to each other.** The documentation is unambiguous that there is no support for direct inter-core communication; everything goes through the host over the memory bus. That is the single largest limitation of real PIM hardware and it is precisely what the question asks about.

**Logic base die under a DRAM stack — near-memory.** This is HBM's existing structure with compute added to the layer that is currently only a PHY. Memory dies sit above a logic die built in a proper logic process, connected by through-silicon vias that provide vastly more internal bandwidth than the external channel. HBM4's move toward a customer-specific base die is the industry walking in this direction. **This is the architecture the question should want**, because the logic is in a logic process and the bandwidth is in the stack.

**Chiplets with local DRAM.** Each logic die at a modern node with its own LPDDR, on a substrate rather than an interposer. No TSVs, no DRAM-process compromise, far cheaper, and buildable with ordinary packaging.

### 14.3 LB64 is unusually well suited to a DRAM process, by accident

This is the strongest finding in the section. A DRAM-process logic budget forbids multipliers and floating-point units. Look at what LB64's inner loop actually needs (§3.1):

| LB64 requires | DRAM process allows |
|---|---|
| conditional negate — **one XOR per lane** | yes, trivially |
| 32-bit integer accumulate | yes — UPMEM has native 32- and 64-bit add |
| fixed-point with a per-vector exponent (§3.1) | yes — no FP needed anywhere in the loop |
| **no multipliers** | the process has no room for them |
| **no floating point** | the process effectively cannot provide it |

The decisions made in §3.1 to economize on FPGA LUTs — conditional negate instead of multiply, block floating point instead of FP adders — turn out to be exactly the decisions a DRAM process *requires*. **LB64 would run natively in a DRAM-process logic layer. A conventional FP16 MAC array would not.**

The converse is equally clean and gives the partition for free: `MX64`, being FP multiply-accumulate (§10.3), **cannot** live in a DRAM process. So in a PIM system the weight contractions go into the memory and attention stays on a logic die or the host. That is not a design compromise; it is the process boundary falling exactly where the workload already splits.

### 14.4 LLM inference partitions almost for free

The reason this works at all, and the number to remember:

> At batch 1 the **activations are tiny and the weights are enormous.** A 1024-dimensional activation is 2 KB. The weights read to apply it are 45 MB per token. The reduction that has to cross between units is 496 bytes per layer.

Concretely, for tensor-parallel LittleBit across *N* units:

- **Stage 1** contracts over `d_in`. Split `d_in` across the units and each produces a partial `z` of length r — so the units must sum **r elements**, 496 bytes at r = 124.
- **Stage 2** contracts over r. Split `d_out` and each unit produces its own slice of the output, needing **no communication at all.**

That is the standard column-then-row-parallel pattern, and it works even better here than in a dense model because **r ≪ d**: the reduction is over the latent rank, not the hidden dimension.

| Per token, per unit | |
|---|---|
| weight bytes read from local memory | 45 MB |
| reduction bytes sent between units | **13.9 KB** |
| **ratio** | **3,240 : 1** |

At 1,000 tokens per second that is 14 MB/s of inter-unit traffic. **The interconnect bandwidth requirement is negligible**, which is the opposite of the training case in §11.2 where gradients are parameter-sized.

### 14.5 The interconnect is a reduction tree, not a network

Because the only inter-unit traffic is a small all-reduce, the requirement is **latency, not bandwidth**, and the right structure is a hardware reduction tree rather than a general network-on-chip.

Assuming 100 ns per hop and 56 synchronization points per token (two per layer):

| Units | Ring all-reduce | **Reduction tree** |
|---|---|---|
| 8 | 78 µs/token | **17 µs** |
| 32 | 347 µs/token | **28 µs** |
| 128 | 1,422 µs/token | **39 µs** |

Against a 33 ms token (§12.2), even the ring is tolerable at small N — but it degrades linearly while the tree degrades logarithmically, and at 128 units the ring costs 4% of the token while the tree costs 0.1%.

So the design is:

- **A dedicated reduction tree**, log₂(N) deep, with an adder in each node so the sum accumulates as the message climbs. In-network reduction, which is what InfiniBand switches do with SHARP — here it is a few hundred gates per node because the payload is 496 bytes.
- **Q64 for control and descriptors only** (§5), plus the one-time bulk weight load.
- **No cache coherence between units.** Each unit owns its memory privately and communication is explicit. This is ISA §17.3's distinction applied here: transparent coherence between CPUs that share memory, explicit messaging for accelerators. Making 128 near-memory units coherent would be both enormous and pointless, since they never touch each other's data.

The programming model is therefore message passing, which the descriptor chain of §5 already is.

### 14.6 What it buys

| Architecture | Aggregate bandwidth | Ceiling at 45 MB/token |
|---|---|---|
| DE10-Nano today | 2 GB/s | 44 tok/s |
| **8 × DE10-Nano, tensor-parallel** | 16 GB/s | **356 tok/s** |
| one UPMEM-class DRAM-process core | 0.62 GB/s | 14 tok/s |
| **UPMEM-class DIMM, 128 cores** | 80 GB/s | **1,775 tok/s** |
| 4 nm logic + one LPDDR5X channel | 68 GB/s | 1,511 tok/s |
| **4 nm base die + HBM3E stack** | 1.2 TB/s | **26,667 tok/s** |

Three conclusions, in order of how much they should change the plan.

**Eight boards give near-linear scaling today.** 356 tok/s against 44, for about $1,200 of hardware and a few LVDS pairs between boards. The scaling is near-linear precisely because of §14.4's 3,240:1 ratio, and this is buildable now with no new silicon. **It is the practical answer to the question.**

**One HBM stack beats 128 DRAM-process cores.** 1.2 TB/s against 80 GB/s. So if a 3D stack is available, the many-small-units architecture is answering a question that no longer exists. Many-small-units is a **cost** play — commodity DRAM at a few dollars per gigabyte against HBM at ten to twenty, with no silicon interposer required — not a performance one.

**A small model is capacity-rich and bandwidth-poor on PIM.** Reaching 1,000 tok/s needs 45 GB/s, which is 73 UPMEM-class cores — and each would hold 55 MB ÷ 73 ≈ 0.75 MB of weights while sitting on a 64 MB bank. Splitting the model finer is pointless. The right use of that capacity is to **replicate the model across groups of cores and serve many independent streams**, which is §11.5's serving case reappearing at the chip level.

### 14.7 Thermal, where smallness finally pays

DRAM retention and timing are temperature-dependent in a way that matters: read and write latencies are roughly 33% and 55% better at 55 °C than at 85 °C. A logic die dissipating underneath a DRAM stack therefore spends part of the memory's own performance budget, and the thermal ceiling — not area — is what limits compute in a stack.

The budget for a base die under a four-high stack is on the order of single-digit watts. The pdp64 core is about 92,000 transistors (ISA §10, a revision-20 estimate) and LB64's lanes are an XOR and an adder each. The whole thing is one to three watts.

**The design's smallness, which has been a constraint in every previous section, is the property that makes it stackable.** A large out-of-order core would cook the memory it sits under. This one would not, and that is the clearest argument yet for the design point chosen in ISA §1.

### 14.8 What to actually build

In order, each step independently useful:

1. **Eight boards, tensor-parallel, reduction tree over LVDS.** 356 tok/s, buildable now, validates §14.4's partitioning and §14.5's interconnect with no fabrication at all. If the measured scaling is not near-linear, everything downstream is wrong and it is better to find out here.
2. **One board with a wider memory interface.** LPDDR5X at 68 GB/s on a KV260-class part gets 1,500 tok/s from a single unit and skips the interconnect question entirely. Cheaper than step 1 in engineering effort if the boards are not already in hand.
3. **A 130 nm shuttle of the core plus LB64** (§13.3), to turn the design into a device.
4. **A logic base die under a DRAM stack**, which is the architecture this section recommends and which nothing in the project can currently reach. Worth designing toward; not worth planning around.

And explicitly not: a DRAM-process implementation of the whole machine. §14.3 says LB64 would fit, but the CPU would run at 350 MHz with no FPU and no inter-unit communication, which means `MX64` and `VEC64` both have to live elsewhere and the host becomes the bottleneck for everything except the weight contractions. The partition is right; the silicon is not reachable.


---

## Sources

- [LittleBit: Ultra Low-Bit Quantization via Latent Factorization](https://arxiv.org/abs/2506.13771v4) — the factorization, Eq. 1–5, 9–10, 16–17
- [LittleBit, NeurIPS 2025 proceedings](https://papers.nips.cc/paper_files/paper/2025/file/a917c1d57088897beba47f96b4fd7f3c-Paper-Conference.pdf)
- [LittleBit-2: Maximizing the Spectral Energy Gain in Sub-1-Bit LLMs via Latent Geometry Alignment](https://research.samsung.com/blog/LittleBit-2-Maximizing-the-Spectral-Energy-Gain-in-Sub-1-Bit-LLMs-via-Latent-Geometry-Alignment) — the rotation, Joint-ITQ, distortion figures, γ\*
- [Samsung Research paper listing](https://research.samsung.com/research-papers/LittleBit-Ultra-Low-Bit-Quantization-via-Latent-Factorization)
- [H100 SXM5 throughput figures](https://glennklockwood.com/garden/processors/H100) — 989.4 TFLOPS FP16/BF16 dense, 700 W
- [Critical batch size, measured on OLMo](https://allenai.org/blog/critical-batch-size) — the plateau near 4,096 used in §11.3
- [How AI training scales](https://openai.com/index/how-ai-training-scales) — the original gradient-noise-scale treatment of the same limit
- [Benchmarking a Real Processing-in-Memory Architecture](https://arxiv.org/pdf/2105.03814) — the UPMEM figures in §14.2: 350 MHz, 64 MB/core, 624 MB/s measured, no FPU, no inter-core communication
- [A Modern Primer on Processing in Memory](https://arxiv.org/pdf/2012.03112) — the PUM/PNM distinction, logic base dies and TSVs, and the DRAM temperature figures in §14.7

---

## Changes since revision 20

This document was copied from [`orig/11-64W-lb64-accelerator.md`](orig/11-64W-lb64-accelerator.md), written under the working name 11/64W against ISA revision 20. The original is unmodified in `docs/11-64W/`. Full list, with reasons: [`../CHANGES-SINCE-R20.md`](CHANGES-SINCE-R20.md); decisions numbered in [`../errata.md`](errata.md). LB64 touches the ISA only through ISA §16 (memory type, `FENCE`, atomics). CHANGES-SINCE-R20.md does not discuss LB64, so the device design, arithmetic and sizing above are left as written. The changes that touch what this document mentions:

- Renamed to pdp64; cross-references point at `pdp64-isa.md` and `pdp64-fpga-plan.md`. (errata 12)
- §6.2 (ISA §9.7): the reciprocal and reciprocal-square-root *estimate* instructions `FRECPED` and `FRSQRTED` were dropped from `FESC` (errata 16). VEC64's own table-and-interpolate `reciprocal`/`rsqrt` is a separate, device-side matter and is unaffected. FP instruction spellings are now `fadd` (binary64), `fadd32` (binary32), with `fadd16` reserved (errata 24).
- §2.1, §8 (`XNORPOP`, `BESC`): the CRC instructions were added and withdrawn (errata 20); carry-less multiply (`CLMULL`/`CLMULH`) stands as the polynomial primitive. `RORI` was added to `BESC` as its own mnemonic (errata 10).
- §3.1 (FP16 scale vectors): half precision (`binary16`) is proposed, not decided; conversion only is estimated at about six words and 500-1,000 LUTs, full arithmetic 2,000-3,500 LUTs (CHANGES §14, estimates, unmeasured). The spelling `fadd16` is reserved.
- §7 (Q64 lock versus AXI monitor, ISA open item 4): still open (CHANGES §12, "atomics against Q64"). Coherence, `MT = 01` and `FENCE` are not mentioned in CHANGES.
- Opcode map: 55 assigned opcodes (not 56), 93 operations folded, 230 mnemonic words and 196 instructions (CHANGES §1, errata 2). The ISA r20 section numbers cited here are unchanged.
- Toolchain: `as64`, `ld64`, `sim64` and a pcc back end exist (CHANGES §1, §12, §14); no LB64-specific tooling exists or is mentioned in the sources.
