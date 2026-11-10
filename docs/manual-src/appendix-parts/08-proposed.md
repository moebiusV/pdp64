### 8.2 Why not SIMD in the processor (moved from chapter 8)

**8.2.3** (moved from chapter 8) A scalable design (ARM SVE, RISC-V V) avoids the fixed-width problem and is the most complex to specify and to implement; it is the only in-processor form that would suit this project's range from a small FPGA core to a possible large one. *(P)*

**8.2.4** (moved from chapter 8) The compiled corpus shows little vectorisable code at the size-optimising setting; whether it shows more at higher optimisation is a measurement to make before any in-processor form is reconsidered. *(P)*

*Commentary (moved from chapter 8).* **Trade-offs.** A scalable vector extension would let one binary run on a small and a large implementation, at the price of the largest specification in the architecture and a compiler model that must handle an unknown vector length. **Modern comparables.** SVE and the RISC-V vector extension. (Packed lanes in the integer registers, the other in-processor form, are the open item [J.8.3](appendix-j-open.md#j83).)

### 8.3 AI and large-language-model inference: the LB64 accelerator (moved from chapter 8)

The author decided that inference is the target and that it runs on memory-mapped devices (errata 59; kept in the body as 8.3.1). The design of one such device, LB64, is the assistant's, written in `docs/pdp64-lb64-accelerator.md`, and no decision of the author names it; it was written on the register model of the first device family, which errata 95 later set aside for virtio. It is kept here as a proposal, and the statements below, which the chapter had tagged decided, are entered as proposed for that reason.

**8.3.1** (moved from chapter 8) The inference accelerator, LB64, evaluates the layers of a binary-weight language model as sign-flip accumulates with no multipliers, taking a chain of descriptors and writing a status back on completion. *(D in the chapter; judged proposed because no decision of the author names the device)*

**8.3.2** (moved from chapter 8) A layer is two descriptors, the second accumulating into the first's result for the residual path, and a transformer block is a chain; the processor writes the chain once and is then idle. *(D in the chapter; judged proposed, as 8.3.1)*

**8.3.3** (moved from chapter 8) The work is partitioned between small engines, each doing one thing with its own local memory: LB64 for the projections and the feed-forward layers, a floating-point multiply-accumulate engine for the attention products, a vector engine for normalisation, softmax, activation and rotary position encoding, and the processor for the descriptor chains, sampling and the tokeniser. *(P)*

**8.3.4** (moved from chapter 8) The accelerator has no instruction set: its computation has exactly one shape, so a programmable sequencer would spend its area on flexibility the work does not use. *(D in the chapter; judged proposed, as 8.3.1)*

**8.3.5** (the last clause, moved from chapter 8) `POPCNT` and `XNORPOP` are not what the accelerator uses.

*Commentary (moved from chapter 8).* **Precedent.** A descriptor chain is how every competent DMA engine since the PDP-11's RK11 has worked, and the partition into small single-purpose engines fed by chains is the idea of the 144-processor GA144 chip applied to a workload that suits it. **Trade-offs.** The accelerator is fast at what it does and does nothing else: attention is not helped, the element-wise work needs another engine, and a training accelerator is a different design again. The accelerator's descriptor is larger than the 32-byte descriptor of chapter 5, so the two must be reconciled: the proposal is that the standard descriptor's address points at a device-defined work block, which can chain, and the ring carries pointers to work blocks (the question is [J.8.2](appendix-j-open.md#j82)). **Benefits.** The lane count is set by the memory bandwidth and not by the amount of logic, so a small board can run a model the processor alone could not. **Modern comparables.** ARM's Ethos engines, Google's TPU, and the many inference accelerators on small boards. **Impact.** *Kernel:* a driver builds a chain and starts it; the kernel owns no model state and the only scheduling is of the device. *Compiler:* none; inference frameworks emit descriptors. *Hardware:* adders and sign-flip logic and no multipliers in LB64; the multiply-accumulate engine needs multiplier blocks; the memory interface sets the size.

### 8.4 Array languages: APL and K (moved from chapter 8)

**8.4.3** (moved from chapter 8) The interpreter stays on the processor and sends a primitive to the device when the array is long enough to repay the setup; short arrays run on the processor. *(P)*

**8.4.5** (moved from chapter 8) A vector engine for such primitives would provide element-wise arithmetic and comparison, selection, reductions, scans, gather and scatter, compress (`where`) and index generation, on integer, floating-point and bit-array types. *(P)* (The question of the operation set is [J.8.1](appendix-j-open.md#j81).)

*Commentary (moved from chapter 8).* **Trade-offs.** Offloading a primitive has a fixed cost, so the benefit is for arrays above a size threshold; reductions and scans carry a dependence along the array that the device must support directly; sorting and gather are bandwidth-limited. **Benefits.** The same device that serves the array languages serves the elementwise work of inference and the lane-wise work of graphics. **Impact.** *Hardware:* a streaming engine with a small set of element-wise, reduce, scan and gather units behind the ring engine, sized to the memory bandwidth.

### 8.5 Number formats (moved from chapter 8)

**8.5.1** (the second clause, moved from chapter 8) Formats other than `binary64`, `binary32` and `binary16` (bfloat16, 8-bit integers with 32-bit accumulation, binary weights, 8-bit floating point) are the device's. *(P)*

**8.5.2** (moved from chapter 8) Each vector device names its operations and formats in its identification block and feature bits, so a library can choose by asking. *(P)*

*Commentary (moved from chapter 8).* **Trade-offs.** A format fixed in the processor's instruction set is a format that cannot change when the machine-learning field changes it, as it has several times; a format in a device is replaced by replacing the device. **Modern comparables.** x86 has half precision, bfloat16 and `VNNI` dot products in the instruction set; ARM has `BF16`, `SDOT` and matrix extensions; accelerators handle the rest. **Impact.** *Kernel:* none. *Compiler:* only the scalar formats; the machine-learning formats are descriptor fields. *Hardware:* the devices' multiply-accumulate units, not the processor's, are built for the formats in use.

### 8.6 Driving a vector device (moved from chapter 8)

**8.6.1** (moved from chapter 8) A program fills a descriptor naming the operation and the arrays, executes `FENCE`, and writes the doorbell; the device processes the descriptor, writes the results and a status, and clears the ownership bit; the program polls or takes the interrupt. *(P)*

**8.6.2** (moved from chapter 8) A chain of descriptors runs without the processor, and a work block that is a chain is how a transformer layer or a sequence of array primitives is expressed. *(P)*

**8.6.3** (moved from chapter 8) The buffers are uncached, as for every device, so the processor's reads of results are slow; a large result is left in the device's memory or read back by the next descriptor. *(P)*

*Commentary (moved from chapter 8).* This is the same driver skeleton as for a disk (chapter 5), with an operation field that means "add these arrays". **Trade-offs.** The slow uncached readback is the cost of the explicit hand-off; an interpreter that needs many small results back on the processor should leave them in device memory. **Impact.** *Kernel:* one driver skeleton. *Compiler:* none. *Hardware:* one ring engine shared with every device.
