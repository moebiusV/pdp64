# 8. Vector work, AI and array languages: the device route

[← manual index](00-index.md)

**Wide data-parallel work, whether neural-network inference or the primitives of an array language, is done by memory-mapped devices with their own memory and driven by descriptors, not by SIMD registers in the processor.** There is no vector register file and no AVX2-style instruction set in the pdp64. The chapter states that decision, the reason for it, and how it serves AI and large-language-model inference and the array languages APL and K. Graphics has its own chapter (chapter 3), since its devices are the first a user sees. It is the route ARM-based systems take for their neural-network and graphics engines, and the one the PDP-11 took for its attached array processors.

## 8.1 The decision

**8.1.1** The processor has no vector register file and no SIMD instruction set of the SSE, AVX2 or NEON kind. *(D)*

**8.1.2** Wide work is described to a device by descriptors in memory: an operation, the addresses of the arrays and their length. *(D)*

**8.1.3** The processor owes such a device what it owes every device: a memory type per page and a `FENCE`; the instruction set is unchanged. *(D)*

**8.1.4** Such a device is a helper or accelerator that uses the same RAM as the processor and does DMA; this is what "GPU" means in this manual. *(D)*

**8.1.5** Open: whether the integer registers get packed-lane operations ([J.8.3](appendix-j-open.md#j83)).

**8.1.6** Open: how the descriptor of a vector device relates to the virtio descriptor of chapter 5 ([J.8.2](appendix-j-open.md#j82)).

*Commentary.* **Precedent.** The PDP-11's heavy numerical work went to attached array processors driven by library calls (the Floating Point Systems AP-120B attached to PDP-11 hosts, by the one brochure checked), and the VAX gave its 6000 series a vector extension of 16 registers of 64 elements, supported by VMS but little used by Unix. x86 went from MMX through SSE, AVX and AVX2 (256-bit) to AVX-512, a new width and a new set of state each time; ARM has NEON in the processor and scalable vectors beyond, and attaches its neural-network and graphics engines as memory-mapped devices; RISC-V has a scalable vector extension. **Trade-offs.** A device needs a setup (a descriptor) and a completion (a status), so small arrays are faster on the processor and large ones on the device; a SIMD register file has no setup and a cost in state, opcodes and width that grows with every generation. **Improvements.** The decision removes the questions that a vector register file raises: whether a context switch saves the vector state (x86's lazy saving of floating-point state was a security hole and Linux went back to eager restore), whether the kernel may use the registers, how wide they are, and what the calling convention does with them. **Benefits.** A processor that stays small and in order and that gains graphics and inference by adding devices. **Modern comparables.** ARM's Ethos neural engines and Mali graphics engines, Apple's matrix coprocessor reached through a library, Google's TPU on PCI Express. **Impact.** *Kernel:* no vector state to save at a context switch and no rule about the kernel using vector registers; a device is one more slot, mapped like any other. *Compiler:* no auto-vectoriser targets the device; the library and the language runtime call it at the level of an operation on an array. *Hardware:* no second register file, no wide load and store path, no opcodes spent; the processor's cost does not grow with the workload.

## 8.2 Why not SIMD in the processor

**8.2.1** A SIMD register file is a second wide register file, which the instruction set deliberately avoided (floating point shares the general registers), and it brings wide loads and stores entangled with the alignment rules and a large demand on a first-page opcode map that is 58 of 64 full. *(D)*

**8.2.2** A fixed-width design (128-bit NEON, 256-bit AVX2) bakes the width into every instruction, so a wider generation needs new instructions, and old binaries cannot use the new width. *(D)*

*Commentary.* **Precedent.** x86's history of SSE, AVX, AVX2 and AVX-512 is the argument against a fixed width: each added instructions and state, and AVX-512 was withdrawn from some client chips and later proposed to be unified. **Improvements.** Moving the work to a device makes the length a descriptor field, which needs no register file. **Benefits.** The block RAM of a small FPGA, the scarce resource of the plan, is not spent on vector registers. **Modern comparables.** AVX2 on x86 and NEON on ARM. **Impact.** *Kernel:* nothing to save and no lazy-save hazard. *Compiler:* no vector types in the ABI and no vectorisation pass for the processor. *Hardware:* no area for a register file or wide data paths; the FPGA's memory goes to the caches and the device buffers.

## 8.3 AI and large-language-model inference

**8.3.1** Inference is the workload that the machine is optimised for, and it runs on memory-mapped devices (section 8.1), not in the processor. *(D)*

**8.3.2** The processor keeps `POPCNT` and `XNORPOP` for the binary operations that small models and bitsets use. *(D)*

## 8.4 Array languages: APL and K

**8.4.1** Array languages express computation as operations on whole arrays: each primitive (add, multiply, compare, reduce, scan, index, where, sort) is one operation over contiguous data.

**8.4.2** A device that takes a descriptor naming an operation, the addresses of the arrays and a length is the natural implementation of those primitives: one descriptor per primitive, the length in the descriptor. *(D)*

**8.4.3** There is no vector length in a register: the length is a field of the descriptor, so one implementation serves any array size. *(D)*

**8.4.4** Open: the operations and the number formats of the vector device ([J.8.1](appendix-j-open.md#j81)).

*Commentary.* **Precedent.** Iverson's APL made whole-array operations the language, and its descendants J and Arthur Whitney's K (the language of the kdb+ database) are interpreters whose speed comes from running long loops over contiguous arrays in a few tight kernels; the Cray vector machines were built around the same shape of loop, and DEC offered APL for the PDP-11 (not confirmed in the sources read). **Improvements.** The language supplies the parallelism: the programmer says "add these two arrays", so there is no vectorising compiler to find it, which is the hardest part of making an ordinary language fast on SIMD hardware. The interpretive overhead is paid once per primitive, not once per element, and the device streams the data at memory bandwidth. **Benefits.** Vector languages are easier to support (a small interpreter with a library of primitives that map onto descriptors) and more efficient (the per-element work is hardware, and the per-primitive work is one descriptor). **Modern comparables.** K and kdb+ interpreters use AVX2 intrinsics heavily on x86 *(not confirmed in the sources read)*; array-language compilers for GPUs (Futhark, Co-dfns) target accelerators through offload, the same shape as this. **Impact.** *Kernel:* a language runtime that drives a device from user space needs the device's page mapped into its address space, with the protection caveat of chapter 5 (without a translation unit a user-space driver can direct its device to write anywhere). *Compiler:* none; the interpreter or compiler for the array language lowers primitives to descriptors, and a conventional compiler never sees a vector.

## 8.5 Number formats

**8.5.1** The processor handles `binary64`, `binary32` and `binary16` as scalar floating point. *(D)*

**8.5.2** Open: the number formats of the vector device, and how a program learns them ([J.8.1](appendix-j-open.md#j81)).
