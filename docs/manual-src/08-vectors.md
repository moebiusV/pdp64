# 8. Vector work, AI and array languages: the device route

[← manual index](00-index.md)

**The pdp64 has a vector and accelerator engine as a standard part of the architecture, as the FPU, the MMU and the IOMMU are: every system has one, software can rely on it, and the architecture specifies its descriptor and its operations. The engine is not in the processor. It is a device on the bus that uses the same RAM as the processor, moves data by DMA and is told what to do by descriptors (records in memory) that the processor writes; the processor itself has no vector register file and no SIMD instruction set, and gains only the memory ordering and the `FENCE` instruction that every device already needs.** Open: the operations and number formats of the engine ([J.8.1](appendix-j-open.md#j81)), its descriptor ([J.8.2](appendix-j-open.md#j82)), packed-lane operations in the integer registers ([J.8.3](appendix-j-open.md#j83)), which engine is built first ([J.8.4](appendix-j-open.md#j84)) and operations on regions of memory in the instruction set ([J.8.5](appendix-j-open.md#j85)).

This chapter is written for a reader who has programmed a PDP-11 with the FP11 floating-point unit (the `movf` and `addf` instructions of V7 assembly), or who is learning computing from the start, and who has not met a vector register, a SIMD instruction or a graphics processor. It runs from what that reader knows to what the pdp64 does: the PDP-11 and its floating-point unit (8.1), what a vector unit and a SIMD unit are and the machines that had them (8.2), the decision (8.3), the engine as a standard part, the accelerator route and what "GPU" means in this manual (8.4), inference, array languages and the bit instructions (8.5), the number formats (8.6) and what was checked (8.7). Graphics has its own chapter (chapter 3), since its devices are the first a user sees; the descriptor rings of chapter 5 are the transport this chapter assumes.

*How to read this chapter.* A term is defined where it first appears, as the technical word followed by a plain restatement. Boxes-and-arrows pictures draw a box for a piece of memory or a program and an arrow for what is handed on. Code blocks are pseudocode (`#` starts a comment), or PDP-11 assembly in the syntax of the V7 assembler when the text says so. Every listing for the pdp64 is an illustration, and so is every record layout; the decisions are the numbered statements.

## 8.1 What you already know: the PDP-11 and its floating-point unit

The PDP-11 had one way to do arithmetic on real numbers: the **FP11**, a floating-point unit (a second processor-like block, an option that a model could lack) with six **accumulators** (floating-point registers) named `AC0` to `AC5`. Each holds a 64-bit value; a mode instruction, `setd` for 64-bit double and `setf` for 32-bit single, says how the instructions that follow read them. V7 Unix tests for the unit at boot (`mch.s` executes `setd` with a trap catcher installed, and sets a flag, `fpp`, if the instruction did not trap) and keeps the state of a process in its `struct user` (`user.h`):

```
struct {
    int     u_fpsr;          /* FP status register */
    double  u_fpregs[6];     /* FP registers: AC0..AC5 */
} u_fps;                     /* 2 + 6 * 8 = 50 bytes */
```

The kernel saves it with `savfp` and restores it with `restfp`, two assembly routines in `mch.s` (`stfps`, `setd`, six `movf` to memory; the reverse for restore; the code moves `AC4` and `AC5` through `AC0` before storing them, which suggests, by inference, that this store form reaches only `AC0` to `AC3`). `swtch()` in `slp.c` calls `savfp` for the process it is leaving, unless `u_fpsaved` says that has been done; `trap()` clears `u_fpsaved` on entry and calls `restfp` on the way out only if it was set. So a system call that never switches processes costs no floating-point save at all, and a switch costs fifty bytes.

A loop that adds two arrays of 64 doubles on this machine (written for this chapter, V7 assembler syntax, after `setd`):

```
        mov     $64., r0          / count
loop:   movf    (r1)+, fr0        / fr0 = a[i]; r1 steps by 8
        addf    (r2)+, fr0        / fr0 = fr0 + b[i]
        movf    fr0, (r3)+        / c[i] = fr0
        sob     r0, loop          / count down, repeat
```

Each pass loads, adds, stores and decrements: four instructions per number, and the instruction fetches take as long as the arithmetic. The FP11 is a **scalar** unit (it works on one number at a time), and the PDP-11 had no vector unit and no SIMD instructions. Programs that needed more than the FP11 gave went to an **attached array processor** (a separate box, with its own memory and its own program store, that the host fills with data and starts): the Floating Point Systems AP-120B (1976) listed PDP-11 hosts in its brochure *(unverified here: the repository's notes record the brochure, which is not on this computer)*. The host talked to it through a library of calls and a set of device registers. That is the oldest precedent for this chapter's route.

## 8.2 What came between: vector machines, SIMD and the graphics processor

Three ideas followed, and each answered a limit of the loop above.

**The vector machine.** The loop above spends its time on instruction fetch and loop control. A **vector machine** (a processor whose registers each hold a whole array of numbers, and whose instructions act on all of them) replaces the loop with four instructions:

```
vl = 64                   # the vector length register: how many elements to use
v0 = vload(a)             # one instruction loads 64 numbers
v1 = vload(b)
v2 = vadd(v0, v1)         # one instruction adds 64 pairs, one pair after another in a pipeline
vstore(c, v2)
```

The **Cray-1** (1976) had eight vector registers of 64 elements of 64 bits *(unverified)*. DEC's answer was the **vector facility** of the VAX 6000 series (1990): sixteen vector registers of 64 elements each, a vector-length register and a mask register, an option in a separate processor board *(unverified here: the repository's notes cite the VAX 6000 Vector Processor Programmer's Guide, not on this computer)*. A longer array is cut into pieces of 64 (**strip mining**: a loop that handles one register's worth at a time and a final short piece with a shorter length). The price is state: sixteen registers of 64 elements of 8 bytes is 8192 bytes that the operating system must save at a context switch, 164 times the 50 bytes of the FP11, drawn to one scale below.

![The state that floating-point and vector work adds, to one scale](figures/vec-state.svg)

**SIMD, in the 1990s.** **SIMD** (single instruction, multiple data: one instruction applied to several numbers packed side by side in one register, each position a **lane**) took the idea down to the size of an ordinary register. Intel's MMX (1997) reused the floating-point registers as packed integers, SSE (1999) added sixteen-byte registers, and AltiVec on the PowerPC (1999) had 32 of them *(dates unverified)*. The Linux 2.6.33 headers on this machine show the cost: an x86 process carries 16 SSE registers of 16 bytes, `xmm_space[64]` of 32-bit words (`processor.h`), and a PowerPC process carries `vr[32]` of 16 bytes, a status register and a save mask. ARM's NEON registers are the floating-point file seen as 128-bit registers *(unverified)*; the Linux `vfp_hard_struct` holds 32 registers of 64 bits. A SIMD instruction does not take the vector length from a register; the width is in the instruction. When x86 went from 128-bit to 256-bit (AVX) and 512-bit (AVX-512) registers, each width brought new instructions, new state and new kernel code, and a binary built for one could not use the next width *(unverified for the dates and the widths)*. ARM's SVE and the RISC-V vector extension went back to the vector-machine idea, with a length that the hardware chooses and the program asks for *(unverified)*.

The state has a second cost, recorded in this repository's survey of kernel pain points: x86 kernels delayed saving and restoring the floating-point registers until a process used them again (**lazy** switching), and in 2018 that was found to leak the previous process's registers; Linux went back to saving eagerly (`docs/hardware-vulnerabilities.md`, the commit it cites calls the lazy design "rather messy"). On the PowerPC the Linux source says in a comment that on a multiprocessor "we don't do lazy VMX switching because it just gets too horrendously complex" (`arch/powerpc/kernel/vector.S`). V7's own trick, saving only when a switch happens, was an early form of the same laziness.

**The graphics processor.** A **GPU** (graphics processing unit) is a second processor on a board of its own, with many small arithmetic units that run one program on many data at once *(unverified)*. It does not execute instructions from the host's instruction stream. The driver writes **commands** (small packets: draw this, run that program on these arrays) into a **ring buffer** in memory (a circular array that the producer fills and the consumer drains), and tells the chip how far the ring has been filled. The Linux 2.6.33 Radeon driver (`radeon_ring.c`: `radeon_ring_lock`, `radeon_ring_write`) shows the pattern. This is the attached array processor of 8.1 grown up, with the difference that it reads and writes the host's RAM by DMA instead of having its own program store and memory to load.

**The chain.** The PDP-11 had a scalar floating-point unit and a library call to an attached box. The vector machines (the Cray-1, the VAX vector facility) put the array in registers of the processor and paid in state. SIMD put a fixed few lanes in the registers and paid in instruction sets that grew with each width. The GPU and the neural-network engine returned to the attached box and put it on the memory bus. The pdp64 takes the last of these (8.3, 8.4).

![Four ways to add two arrays](figures/vec-shapes.svg)

## 8.3 The decision: no vector or SIMD unit in the processor

The author's instruction (register row R277): "just before the isa section, add a chapter about sdim/avx2 vector stuff, i agree we should go the mmap device arm style route for that. so it is about graphics and ai/llm stuff... also mention apl/k as making vector languages easier to support and more efficient." The decision it records (errata 59) is stated here and in the statements below.

**8.3.1** The processor has no vector register file and no SIMD instruction set of the SSE, AVX2 or NEON kind. *(D)*

**8.3.2** The reasons recorded with the decision: a vector register file is a second wide register file, which the instruction set deliberately avoids (floating point shares the general registers, 9.12.1), and it brings wide loads and stores entangled with the alignment rules of the memory system. *(D)*

**8.3.3** A fixed-width design (128-bit NEON, 256-bit AVX2) bakes its width into every instruction, so a wider generation needs new instructions and old binaries cannot use the new width. *(D)*

**8.3.4** Open: whether the integer registers get packed-lane operations, a handful of instructions that treat a 64-bit register as eight bytes or four halves ([J.8.3](appendix-j-open.md#j83)).

**8.3.5** Open: whether the instruction set gets operations on regions of memory, with no vector register named ([J.8.5](appendix-j-open.md#j85)).

*Commentary.* **Chain.** PDP-11: a scalar floating-point unit with 50 bytes of state, and attached array processors for heavy work (8.1). VAX: a vector facility with 8192 bytes of state (8.2). x86, PowerPC, ARM: fixed-width SIMD in the processor, with state of 256 bytes to 512 bytes and a width that changed every few years; kernels that carried lazy-save code and then removed it. pdp64: none of this, because the floating-point formats use the general registers (9.12.1), the only floating-point state beyond them is the flag register `FPSR` (9.12.3), and the wide work leaves the processor. **Trade-offs.** A device needs a setup (a descriptor) and a completion (a status), so small arrays are faster on the processor and large ones on the device; a SIMD register file has no setup and a cost in state, opcodes and width that grows with every generation. **Improvements.** The decision removes the questions that a vector register file raises: whether a context switch saves the vector state, whether the kernel may use the registers, how wide they are, and what the calling convention does with them (the lazy-switching leak above does not arise for a state that does not exist). **Modern comparables.** ARM-based systems attach their neural-network engines (Ethos) and graphics engines (Mali) as memory-mapped devices *(unverified)*; Apple's matrix coprocessor is reached through a library and Google's TPU is a PCI Express card *(unverified)*. **Impact.** *Kernel:* no vector state to save at a context switch and no rule about the kernel using vector registers. *Compiler:* no auto-vectoriser (a compiler pass that turns a loop into SIMD instructions) and no vector types in the ABI. *Hardware:* no second register file, no wide load and store path, no opcodes spent; the processor's size does not grow with the workload.

## 8.4 The engine: a standard part of the architecture, and the device route

What the processor does not do, a device does, and the author has said that the device is part of the architecture. His words, 2026-11-10 (errata 131): "even if it doesn't involve specific opcodes 'in the cpu' still it must be built in as a standard part of the architecture, just as the fpu mmu and iommu are."

The PDP-11 treated its floating-point unit as an option: a model could lack the FP11, and V7 tested for it at boot (8.1). The pdp64 has no such options among the units the author names. The floating-point instructions are in the instruction set (9.12), the MMU is the page-table machinery of chapter 6, and the IOMMU is the translator between a device's addresses and memory's (2.11). The vector and accelerator engine joins them. It is reached in a different way, because the decision of errata 59 stands: the processor has no vector registers and no SIMD instructions, so the engine is not another group of instructions. The FPU is reached by instructions, the MMU by system registers and by the translation of every access, and the IOMMU by a register block on the bus; the engine is reached by descriptors. What makes it a standard part is that the manual specifies its interface the way it specifies `FADD`.

![Where the engine sits: beside the FPU and the MMU in the machine, and on the bus beside the IOMMU](figures/vec-engine.svg)

**8.4.1** The vector and accelerator engine is a standard part of the architecture, as the FPU, the MMU and the IOMMU are. *(D)* Details pending ([J.8.1](appendix-j-open.md#j81) to [J.8.4](appendix-j-open.md#j84)): its operations and number formats, its descriptor, and which engine is built first.

**8.4.2** The word "standard" has five consequences: every pdp64 system has the engine, including the smallest; software may rely on its presence; the kernel and a program can find out that it is present and what it implements; the architecture specifies its descriptor and its operation set, so that a program written for one engine runs on any other; and it is not an optional PCI Express card. *(D)* These five are the reading of the author's comparison with the FPU, the MMU and the IOMMU (inference). How software finds the engine is pending ([J.8.1](appendix-j-open.md#j81)).

**8.4.3** The engine is a device on the bus and an architectural component at once: the processor reaches it as it reaches every device (a memory-mapped interface, descriptors, DMA, `FENCE`), and the manual defines what it does. *(D)*

The definition behind the device route is the author's, 2026-10-20 (register row R136, thread 533 message 51): "when i say gpu i just mean a helper/accelerator that uses the same ram, does dma, etc, and can do the same or similar helps that a gpu would. and the simd/avax stuff."

**8.4.4** Wide work is described to the engine by descriptors in memory: an operation, the addresses of the arrays and their length. *(D)*

**8.4.5** Such a device is a helper or accelerator that uses the same RAM as the processor and does DMA; this is what "GPU" means in this manual. *(D)*

**8.4.6** The processor owes such a device what it owes every device: buffers in uncached memory (5.10.1) and a `FENCE`; the instruction set is unchanged. *(D)*

**8.4.7** Open: how the descriptor of the engine relates to the virtio descriptor of chapter 5 ([J.8.2](appendix-j-open.md#j82)).

**8.4.8** Open: which engine is built first ([J.8.4](appendix-j-open.md#j84)).

What this looks like to a driver (a pseudocode illustration: the field names and the layout are invented here, and the real record is the open item of 8.4.7):

```
struct vwork {                      # one request to an accelerator
    u32 op;                         # ADD, MUL, DOT, SUM, ...
    u32 format;                     # how to read the elements: binary64, int32, ...
    u64 a, b, c;                    # addresses of the two inputs and the result
    u64 n;                          # the length, in elements
    u32 status;                     # the device writes this when it is done
}

work.op = ADD;  work.a = &x;  work.b = &y;  work.c = &z;  work.n = 1000000
work.status = 0
fence()                             # the record is visible in memory ...
mmio_write64(doorbell, &work)       # ... before the device is told to look
while (work.status == 0) ;          # or wait for the interrupt (5.9)
```

![The route of one request to the engine](figures/vec-route.svg)

This is the shape of the RK11 driver of 8.1 and chapter 5, with the registers (`RKDA`, `RKBA`, `RKWC`) replaced by a record in memory, and it is the shape of a virtio request: the device reads descriptors from memory, reads or writes the buffers they name, writes a status and (optionally) interrupts. A device that speaks virtio takes the same transport routine as a disk (5.4), so what differs between a disk and an adder of arrays is what the operation field means. Whether the engine's own work record is a virtio descriptor, or something a virtio descriptor points to, is the open item of 8.4.7.

A device that does DMA writes memory without the processor's knowledge, which is why the processor owes it ordering: the descriptor must be visible before the doorbell (`FENCE`), and the buffers are in memory that is not cached in the processor's way (5.10.1), as for every device. A device in a user program's hands is confined by the IOMMU (2.11): the descriptor holds device addresses, and the IOMMU refuses any address that the device's table does not map, so a user-space driver can direct its engine only at its own buffers. (Without translation, which is not the default, the device would write anywhere, as 2.11 says.)

*Commentary.* **Chain.** PDP-11: heavy numerical work went to an attached array processor through library calls (8.1); the interface was a few device registers. VAX: the same for most customers, with the vector facility for the 6000 series. GPUs and neural-network engines: a ring of commands in memory and a doorbell, with data by DMA (8.2). pdp64: the same, with the ring and the transport shared with the standard devices of chapter 5, and with the engine specified by the manual and present in every system. **Reconciliation with the earlier decisions.** Errata 59 chose the memory-mapped device route and no vector register file in the processor; that stands, and the engine of 8.4.1 is that device made standard. Errata 78 and the author's remark of 2026-10-23 (R278, "if we can plug a regular card into the bus, why not") allow any PCI Express card to be attached and supported; that stands too, and such a card is an addition to the machine and not the engine, which every system has. Errata 95 made every device a virtio device, which is why the descriptor of the engine is measured against the virtio descriptor ([J.8.2](appendix-j-open.md#j82)). The FP11 and the VAX vector facility were options, and each SIMD generation of x86 and ARM was a new part of the processor; the nearest comparison for the engine is the IOMMU, which is a bus unit and not an instruction group and is standard all the same. **Trade-offs.** The slow part is the hand-off: the buffers are uncached, so reading many small results back is slow, and a result that the next operation needs should stay where the device left it. **Impact.** *Kernel:* a device is one more slot, mapped like any other; the driver is the driver skeleton of chapter 5. *Compiler:* none; a library or a language runtime calls the device at the level of an operation on an array. *Hardware:* one ring engine shared with every device.

## 8.5 Inference, array languages and the bit instructions

Three workloads use the route, and one set of instructions stays in the processor.

**Inference.** A neural network's **inference** (running a trained model to produce an answer, as opposed to training it) is mostly multiplications and additions over large arrays of weights, which is the work vector machines were built for. The author, 2026-10-20 (R139): "just optimize inference whether in cpu or gpu whatever makes most sense."

**8.5.1** Inference is the workload that the machine is optimised for; whether a given part of it runs in the processor or on an accelerator is whichever makes most sense. *(D)*

**The bit instructions.** The weights of some small models are one bit each (the sign of the weight), and the multiply of a weight and an activation of one bit is an exclusive-nor followed by a count of the bits set. `POPCNT` (population count: the number of one bits in a register) and `XNORPOP` (population count of the exclusive-nor of two registers) do that for 64 weights at a time, and serve bitsets and Hamming distance (the number of positions at which two bit strings differ) as well. They are bit instructions of the ordinary integer unit (9.9), not vector instructions: they use the general registers and add no state.

**8.5.2** The processor has `POPCNT` and `XNORPOP` (9.9.1, 9.9.3) for the binary operations that small models and bitsets use. *(D)*

These instructions do not serve every model with binary weights: a language model whose weights are one bit but whose activations are 16-bit floating-point numbers needs a conditional add, not a count, and its inner loop is limited by memory bandwidth, which is what an accelerator is for (the note on `XNORPOP` in 9.9).

**Array languages.** In **APL**, created by Kenneth Iverson, and its descendants J and K (the language of Arthur Whitney's kdb+ database), a program is written as operations on whole arrays: add two arrays, multiply them, compare, reduce (sum), scan (running sum), index, select where a condition holds. An interpreter spends its time in a few tight loops over contiguous data. There is no loop for a compiler to find and turn into vector instructions: the programmer has said "add these two arrays", so the parallelism is in the source. DEC offered APL for the PDP-11 *(unverified)*; the Cray machines were built for the same shape of loop *(unverified)*. That is why the author asked for the mention: a device that takes a descriptor with an operation, the addresses of the arrays and a length is the natural implementation of the primitives, and a small interpreter with a library of primitives that map onto descriptors is "easier to support and more efficient" than a conventional compiler aimed at SIMD (his words, R277).

**8.5.3** The primitives of an array language map one to one onto descriptors: one descriptor per primitive. *(D)*

**8.5.4** There is no vector length in a register: the length is a field of the descriptor, so one implementation serves any array size. *(D)*

**8.5.5** Open: the operations of the engine, and its number formats ([J.8.1](appendix-j-open.md#j81)).

*Commentary.* **Chain.** PDP-11: scalar loops in assembly, and APL interpreters in software *(unverified)*. Cray and VAX vector machines: the loop of 8.2, run by a vector register. x86 with AVX: K and kdb+ interpreters use SIMD instructions heavily *(unverified)*. pdp64: the interpreter pays its overhead once per primitive and not once per element, and the device streams the data at the speed of memory. **Trade-offs.** A device has a fixed cost for each descriptor, so an interpreter keeps short arrays on the processor. **Impact.** *Kernel:* a runtime that drives a device from user space needs the device's page mapped into its address space (confined by the IOMMU, 8.4). *Compiler:* none; the interpreter lowers primitives to descriptors, and a conventional compiler never sees a vector.

## 8.6 Number formats

The FP11 had two formats, single and double, chosen by a mode bit. The pdp64's formats are chosen by the instruction (9.12.5), and there are three.

**8.6.1** The processor handles `binary64`, `binary32` and `binary16` (the IEEE 754 formats of 64, 32 and 16 bits) as scalar floating point. *(D)*

**8.6.2** Open: the number formats of the engine, and how a program learns them ([J.8.1](appendix-j-open.md#j81)).

*Commentary.* **Chain.** PDP-11: single and double, in DEC's own formats and not IEEE's *(unverified)*. VAX: F, D, G and H formats (9.12). pdp64: the IEEE formats, three of them in the processor. **Trade-offs.** A format fixed in the processor's instruction set cannot change when the field's formats change; machine-learning models have used several (bfloat16, 8-bit integers, 8-bit floating point) since 2017 *(unverified)*, and an engine whose formats are fields of its descriptor and entries of a feature list can follow the field where an instruction set cannot ([J.8.1](appendix-j-open.md#j81)).

## 8.7 What was checked, and what was not

* **V7** (`unixtree/V7/usr/sys`): `h/user.h` (`u_fps`, `u_fpsaved`), `conf/mch.s` (`savfp`, `restfp`, the `fpp` test), `sys/slp.c` (`swtch`), `sys/trap.c`, `sys/sig.c`, `sys/sys1.c`; the loop in 8.1 is written for this chapter and was not assembled.
* **Linux 2.6.33.2** (`unixtree/Linux-2.6.33.2`): `arch/x86/include/asm/processor.h` (`xmm_space`, `st_space`), `arch/powerpc/include/asm/processor.h` and `kernel/vector.S`, `arch/arm/include/asm/fpstate.h`, `drivers/gpu/drm/radeon/radeon_ring.c`.
* **The repository:** `docs/errata.md` (59), `docs/decision-register.md` (R136, R139, R277), `docs/hardware-vulnerabilities.md` (lazy floating-point restore), `docs/decisions-pending.md` (the notes on the VAX 6000 and the AP-120B).
* **Sources read for the open items of the engine** (appendix J, J.8.1 to J.8.5): the Linux 7.3 sources (`Documentation/accel/`, `Documentation/arch/x86/xstate.rst`, `Documentation/arch/riscv/vector.rst`, `Documentation/arch/arm64/sve.rst`), the Linux user-space headers (`linux/virtio_ring.h`, `virtio_blk.h`, `virtio_gpu.h`, `virtio_net.h`, `virtio_ids.h`, `io_uring.h`, `idxd.h`), QEMU 11.1.2 (`target/riscv/insn32.decode`, `target/arm/tcg/sve.decode` and `sme.decode`, `target/hppa/insns.decode`, `target/alpha/translate.c`, `target/sparc/vis_helper.c`, `hw/arm/smmuv3-internal.h`, `hw/net/e1000_regs.h`, `include/block/nvme.h`) and the LLVM target descriptions (`llvm/lib/Target/X86`, `AArch64`, `RISCV`, `Hexagon`, `ARM`, `llvm/include/llvm/IR/IntrinsicsNVVM.td`, `mlir/include/mlir/Dialect/Tosa`) and 4.3BSD `sys/vaxif/if_dereg.h`. The counts of instructions were made from these files and are stated with their units in J.8.5.
* **Unverified** (general knowledge, or cited by the repository's notes from documents not on this computer): the AP-120B brochure; the Cray-1 and VAX vector-facility register counts; the dates and widths of MMX, SSE, AltiVec, AVX, SVE and RISC-V V; ARM Ethos, Apple's matrix coprocessor and the TPU; DEC's APL for the PDP-11; the graphics processor's design; the use of SIMD by K and kdb+; the date of the machine-learning formats; and every machine, format and number marked unverified in J.8.1 to J.8.5.
