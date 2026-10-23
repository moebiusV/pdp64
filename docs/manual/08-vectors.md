# 8. Vector work, AI and array languages: the device route

[← manual index](00-index.md)

**Wide data-parallel work, whether neural-network inference or the primitives of an array language, is done by memory-mapped devices with their own memory and driven by descriptors, not by SIMD registers in the processor.** There is no vector register file and no AVX2-style instruction set in the pdp64. This chapter states that decision, why it was taken, and how it serves the workloads the author named: AI and large-language-model inference, and the array languages APL and K. Graphics, the third, has its own chapter (chapter 3), since its devices are the first a user sees. It is the route ARM-based systems take for their neural-network and graphics engines, and the one the PDP-11 took for its attached array processors. The discussion of the alternatives is appendix B (S1 to S6); the accelerator designs are [`../pdp64-lb64-accelerator.md`](../pdp64-lb64-accelerator.md) and section 12 of [`../pdp64-fpga-plan.md`](../pdp64-fpga-plan.md). Tags: *(D)* decided; *(P)* proposed.

## 8.1 The decision

**8.1.1** The processor has no vector register file and no SIMD instruction set of the SSE, AVX2 or NEON kind. *(D, errata 59)*

**8.1.2** Wide work is described to a device by descriptors in memory: an operation, the addresses of the arrays and their length. *(D)*

**8.1.3** The processor owes such a device what it owes every device: a memory type per page, a `FENCE`, and atomics that reach device memory; the instruction set changes not at all. *(D, instruction-set text section 16)*

**8.1.4** Packed-lane operations in the ordinary integer registers (a handful of instructions for bytes, halves and words in a 64-bit register) are not part of this decision; they remain a possibility to be settled by measurement. *(P, appendix A.10)*

*Commentary.* **Precedent.** The PDP-11's heavy numerical work went to attached array processors driven by library calls (the Floating Point Systems AP-120B attached to PDP-11 hosts, by the one brochure checked), and the VAX gave its 6000 series a vector extension of 16 registers of 64 elements, supported by VMS but little used by Unix. x86 went from MMX through SSE, AVX and AVX2 (256-bit) to AVX-512, a new width and a new set of state each time; ARM has NEON in the processor and scalable vectors beyond, and attaches its neural-network and graphics engines as memory-mapped devices; RISC-V has a scalable vector extension. **Trade-offs.** A device needs a setup (a descriptor) and a completion (a status), so small arrays are faster on the processor and large ones on the device; a SIMD register file has no setup and a cost in state, opcodes and width that grows with every generation. **Improvements.** The decision removes the questions that a vector register file raises: whether a context switch saves the vector state (x86's lazy saving of floating-point state was a security hole and Linux went back to eager restore), whether the kernel may use the registers, how wide they are, and what the calling convention does with them. **Benefits.** A processor that stays small and in order and that gains graphics and inference by adding devices. **Modern comparables.** ARM's Ethos neural engines and Mali graphics engines, Apple's matrix coprocessor reached through a library, Google's TPU on PCI Express. **Impact.** *Kernel:* no vector state to save at a context switch and no rule about the kernel using vector registers; a device is one more slot, mapped like any other. *Compiler:* no auto-vectoriser targets the device; the library and the language runtime call it at the level of an operation on an array. *Hardware:* no second register file, no wide load and store path, no opcodes spent; the processor's cost does not grow with the workload.

## 8.2 Why not SIMD in the processor

**8.2.1** A SIMD register file is a second wide register file, which the instruction set deliberately avoided (floating point shares the general registers), and it brings wide loads and stores entangled with the alignment rules and a large demand on a first-page opcode map that is 58 of 64 full. *(D)*

**8.2.2** A fixed-width design (128-bit NEON, 256-bit AVX2) bakes the width into every instruction, so a wider generation needs new instructions, and old binaries cannot use the new width. *(D)*

**8.2.3** A scalable design (ARM SVE, RISC-V V) avoids that and is the most complex to specify and to implement; it is the only in-processor form that would suit this project's range from a small FPGA core to a possible large one. *(P)*

**8.2.4** The compiled corpus shows little vectorisable code at the size-optimising setting; whether it shows more at higher optimisation is a measurement to make before any in-processor form is reconsidered. *(P, appendix B, S1)*

*Commentary.* **Precedent.** x86's history of SSE, AVX, AVX2 and AVX-512 is the argument against a fixed width: each added instructions and state, and AVX-512 was withdrawn from some client chips and later proposed to be unified. **Trade-offs.** A scalable vector extension would let one binary run on a small and a large implementation, at the price of the largest specification in the architecture and a compiler model that must handle an unknown vector length. **Improvements.** Moving the work to a device makes the length a descriptor field, which is the scalable idea without a register file. **Benefits.** The block RAM of a small FPGA, the scarce resource of the plan, is not spent on vector registers. **Modern comparables.** AVX2 on x86, NEON on ARM, SVE and the RISC-V vector extension. **Impact.** *Kernel:* nothing to save and no lazy-save hazard. *Compiler:* no vector types in the ABI and no vectorisation pass for the processor. *Hardware:* no area for a register file or wide data paths; the FPGA's memory goes to the caches and the device buffers.

## 8.3 AI and large-language-model inference

**8.3.1** The inference accelerator, LB64, evaluates the layers of a binary-weight language model as sign-flip accumulates with no multipliers, taking a chain of descriptors and writing a status back on completion. *(D, LB64 document)*

**8.3.2** A layer is two descriptors, the second accumulating into the first's result for the residual path, and a transformer block is a chain; the processor writes the chain once and is then idle. *(D)*

**8.3.3** The work is partitioned between small engines, each doing one thing with its own local memory: LB64 for the projections and the feed-forward layers, a floating-point multiply-accumulate engine for the attention products, a vector engine for normalisation, softmax, activation and rotary position encoding, and the processor for the descriptor chains, sampling and the tokeniser. *(P, LB64 document, section 6.4)*

**8.3.4** The accelerator has no instruction set: its computation has exactly one shape, so a programmable sequencer would spend its area on flexibility the work does not use. *(D)*

**8.3.5** The processor keeps `POPCNT` and `XNORPOP` for the binary operations that small models and bitsets use; they are not what the accelerator uses. *(D)*

*Commentary.* **Precedent.** A descriptor chain is how every competent DMA engine since the PDP-11's RK11 has worked, and the partition into small single-purpose engines fed by chains is the idea of the 144-processor GA144 chip applied to a workload that suits it. **Trade-offs.** The accelerator is fast at what it does and does nothing else: attention is not helped, the element-wise work needs another engine, and a training accelerator is a different design again. The accelerator's descriptor is larger than the 32-byte descriptor of chapter 5, so the two must be reconciled: the proposal is that the standard descriptor's address points at a device-defined work block, which can chain, and the ring carries pointers to work blocks. **Improvements.** The earlier rationale for `XNORPOP`, which was wrong about which workload it serves, was corrected in the instruction-set text. **Benefits.** The lane count is set by the memory bandwidth and not by the amount of logic, so a small board can run a model the processor alone could not. **Modern comparables.** ARM's Ethos engines, Google's TPU, and the many inference accelerators on small boards. **Impact.** *Kernel:* a driver builds a chain and starts it; the kernel owns no model state and the only scheduling is of the device. *Compiler:* none; inference frameworks emit descriptors. *Hardware:* adders and sign-flip logic and no multipliers in LB64; the multiply-accumulate engine needs multiplier blocks; the memory interface sets the size.

## 8.4 Array languages: APL and K

**8.4.1** Array languages express computation as operations on whole arrays: each primitive (add, multiply, compare, reduce, scan, index, where, sort) is one operation over contiguous data. *(the nature of the languages)*

**8.4.2** A device that takes a descriptor naming an operation, the addresses of the arrays and a length is the natural implementation of those primitives: one descriptor per primitive, the length in the descriptor. *(P)*

**8.4.3** The interpreter stays on the processor and sends a primitive to the device when the array is long enough to repay the setup; short arrays run on the processor. *(P)*

**8.4.4** There is no vector length in the language and none in a register: the length is a field of the descriptor, so one implementation serves any array size. *(P)*

**8.4.5** A vector engine for such primitives would provide element-wise arithmetic and comparison, selection, reductions, scans, gather and scatter, compress (`where`) and index generation, on integer, floating-point and bit-array types. *(P)*

*Commentary.* **Precedent.** Iverson's APL made whole-array operations the language, and its descendants J and Arthur Whitney's K (the language of the kdb+ database) are interpreters whose speed comes from running long loops over contiguous arrays in a few tight kernels; the Cray vector machines were built around the same shape of loop, and DEC offered APL for the PDP-11 (not confirmed in the sources read). **Trade-offs.** Offloading a primitive has a fixed cost, so the benefit is for arrays above a size threshold; reductions and scans carry a dependence along the array that the device must support directly; sorting and gather are bandwidth-limited. **Improvements.** The language supplies the parallelism: the programmer says "add these two arrays", so there is no vectorising compiler to find it, which is the hardest part of making an ordinary language fast on SIMD hardware. The interpretive overhead is paid once per primitive, not once per element, and the device streams the data at memory bandwidth. **Benefits.** Vector languages are easier to support (a small interpreter with a library of primitives that map onto descriptors) and more efficient (the per-element work is hardware, and the per-primitive work is one descriptor), and the same device that serves the array languages serves the elementwise work of inference (section 7.4) and the lane-wise work of graphics. **Modern comparables.** K and kdb+ interpreters use AVX2 intrinsics heavily on x86 *(not confirmed in the sources read)*; array-language compilers for GPUs (Futhark, Co-dfns) target accelerators through offload, the same shape as this. **Impact.** *Kernel:* a language runtime that drives a device from user space needs the device's page mapped into its address space, with the protection caveat of chapter 5 (without a translation unit a user-space driver can direct its device to write anywhere). *Compiler:* none; the interpreter or compiler for the array language lowers primitives to descriptors, and a conventional compiler never sees a vector. *Hardware:* a streaming engine with a small set of element-wise, reduce, scan and gather units behind the ring engine, sized to the memory bandwidth.

## 8.5 Number formats

**8.5.1** The processor handles `binary64`, `binary32` and `binary16` as scalar floating point; other formats (bfloat16, 8-bit integers with 32-bit accumulation, binary weights, 8-bit floating point) are the device's. *(D for the processor; P for the devices)*

**8.5.2** Each vector device names its operations and formats in its identification block and feature bits, so a library can choose by asking. *(P, with the feature registers of appendix B)*

*Commentary.* **Trade-offs.** A format fixed in the processor's instruction set is a format that cannot change when the machine-learning field changes it, as it has several times; a format in a device is replaced by replacing the device. **Modern comparables.** x86 has half precision, bfloat16 and `VNNI` dot products in the instruction set; ARM has `BF16`, `SDOT` and matrix extensions; accelerators handle the rest. **Impact.** *Kernel:* none. *Compiler:* only the scalar formats; the machine-learning formats are descriptor fields. *Hardware:* the devices' multiply-accumulate units, not the processor's, are built for the formats in use.

## 8.6 Driving a vector device

**8.6.1** A program fills a descriptor naming the operation and the arrays, executes `FENCE`, and writes the doorbell; the device processes the descriptor, writes the results and a status, and clears the ownership bit; the program polls or takes the interrupt. *(P)*

**8.6.2** A chain of descriptors runs without the processor, and a work block that is a chain is how a transformer layer or a sequence of array primitives is expressed. *(P)*

**8.6.3** The buffers are uncached, as for every device, so the processor's reads of results are slow; a large result is left in the device's memory or read back by the next descriptor. *(P)*

*Commentary.* This is the same driver skeleton as for a disk (chapter 5), with an operation field that means "add these arrays". **Trade-offs.** The slow uncached readback is the cost of the explicit hand-off; an interpreter that needs many small results back on the processor should leave them in device memory. **Impact.** *Kernel:* one driver skeleton. *Compiler:* none. *Hardware:* one ring engine shared with every device.

## 8.7 Still open

The reconciliation of the accelerators' descriptors with the standard descriptor, the formats and operation set of the vector engine, the target workloads, and the evidence that would reopen the question of packed integer lanes: compile the corpus at higher optimisation and count vectorised loops, measure the share of time in memory and string routines, and estimate the block RAM cost (appendix B, S1 to S6).
