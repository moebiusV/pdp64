# Appendix B. Decisions pending

[← streamlined index](00-index.md)

**These are the decisions the author has not yet made, each with its question, the proposed answer, and the precedent, trade-offs and benefits that surround it.** Each has five options with their costs in the working document [`../decisions-pending.md`](../decisions-pending.md) (the identifiers P, R, S, N and B below are that document's), and the boot choices are worked through in [`../boot.md`](../boot.md). Decisions already made (errata 42 to 57) are not repeated here. Each entry is judged by the three principles in order: code size, easy recoverability (less recovery code), and speed and efficiency through fewer gates and tighter hot loops. Every entry is a proposal *(P)* until the author decides it.

## B.1 The instruction set and the system

### B.1.1 The wake rule of `WFE` (P1)

**B.1.1.1** The question is whether `WFE` ends its sleep when an interrupt is pending even if the priority masks it; the proposal is yes. *(P)*

*Commentary.* **Precedent.** An idle loop must check for work and sleep without a gap, or an interrupt that arrives between the two is lost. V7's idle routine lowered the priority and executed `wait` inside a loop that rechecked the run queue after every interrupt, so a lost wake-up cost at most one clock tick. **Trade-offs.** With priority 7 on entry, "lower the priority, then sleep" misses an interrupt that lands between the two, and "sleep at priority 7" never wakes. **Benefits.** The idle loop becomes `spl #7`, check for work, `wfe`, `spl #0`, with no gap and no timer tick to bound it; no opcode, a few gates. **Modern comparables.** AArch64 and RISC-V `wfi` resume on a pending enabled interrupt (RISC-V's manual says the global enable bit is ignored and that an implementation may wake for any reason, so "the same as RISC-V" holds only if the pdp64's priority mask is treated like that bit); x86 closes the gap with the one-instruction interrupt shadow of `STI`, which is hidden state.

### B.1.2 An unprivileged time counter (P3)

**B.1.2.1** The proposal is `RDTIME rd`, an unprivileged read of a free-running, constant-rate, monotonic counter. *(P)*

*Commentary.* **Precedent.** The PDP-11 and VAX kept the time in memory updated by a line clock and read it with a system call. **Trade-offs.** A user-readable counter is a timing side channel, so the kernel needs an enable bit; the counter's width and rate become architecture. **Benefits.** A clock read without a trap, which is what a fast `clock_gettime` in a shared page needs. **Modern comparables.** x86 `RDTSC`, RISC-V `rdtime`, PowerPC `mftb`, s390 `STCKF`, MIPS `RDHWR`, LoongArch `rdtime`; the x86 counter's history of unreliability is the argument for fixing monotonicity and constant rate at the start. **Use.** Timestamps, timeouts, and the fast path of every library's clock call.

### B.1.3 Feature and identification registers (P4)

**B.1.3.1** The proposal is a block of read-only system registers (numbers 13 and up) giving the version, the optional features, the cache geometry, the page sizes and the address width. *(P)*

*Commentary.* **Precedent.** The VAX had a system-identification register the kernel switched on; x86 has `CPUID`, which has grown hundreds of leaves and traps under virtualisation. **Trade-offs.** Each register's layout must be written once in a grammar so it cannot drift. **Benefits.** One binary adapts to the machine, and a kernel need not patch itself per model (OpenBSD carries 75 references to its boot-time patching). **Modern comparables.** AArch64's identification registers, RISC-V's `misa`.

### B.1.4 TLB invalidation by address-space tag (P5)

**B.1.4.1** The proposal is one new instruction, `TLBIASID`, that invalidates every translation of one address space, broadcast like `TLBI`. *(P)*

*Commentary.* **Precedent.** The VAX flushed process translations on every context switch and kept system ones; x86 added tags (PCID) and `INVPCID` much later. **Trade-offs.** A flush-all works until the first rollover of the tag numbers, after which every process loses its translations. **Benefits.** Process exit and tag reuse become cheap. **Modern comparables.** AArch64 `TLBI ASIDE1IS`, RISC-V `sfence.vma` with an address-space operand, x86 `INVPCID`.

### B.1.5 What a multi-register instruction leaves behind when it faults (P12)

**B.1.5.1** The proposal is a rule and a test: every multi-access instruction (`PUSHM`, `POPM`, `PUSHX`, `POPX`, the block operations) is either all-or-nothing or safe to repeat from the start, and an emulator test interrupts each at every access and checks that a restart reaches the same state. *(P)*

*Commentary.* **Precedent.** The PDP-11 needed a status register (`MMR1`) and, on the 11/40, a kernel routine that decoded the faulting instruction to undo it; the VAX needed a first-part-done bit; ARM's load-multiple restarts with the base register restored. **Trade-offs.** The area below the stack pointer is dead memory, so a partial push is invisible; the risk is another observer (a device or core) seeing a half-written area. **Benefits.** The fault handler restarts blindly, with no instruction-specific cases, which is what recoverability means. **Modern comparables.** RISC-V has no multi-register instruction; ARM and the VAX restart as above.

### B.1.6 Priority 7 on interrupt entry as well as exception entry (P14)

**B.1.6.1** Exceptions enter at priority 7, which is decided; the open question is whether interrupts do too, which the implementation does. *(exceptions D, errata 40; interrupts P)*

*Commentary.* **Precedent.** The PDP-11 loaded each vector's own priority and pushed the old state on a stack, so an interrupt at any time could not lose it; trap vectors conventionally held priority 7. **Trade-offs.** Entering in registers needs the priority raised, or a higher-level interrupt could overwrite the saved state before the handler stores it; the cost is one `SPL` in a handler that wants to be interruptible. The alternatives are per-vector priority (the PDP-11's choice), a hardware push, and an interrupt shadow. **Modern comparables.** x86, AArch64 and RISC-V all mask interrupts on entry.

### B.1.7 A prefetch instruction (P15)

**B.1.7.1** The proposal is none for now, with the shape of a non-faulting `PREFETCH` with a memory operand reserved on a free sub-opcode. *(P)*

*Commentary.* **Precedent.** Neither the PDP-11 nor the VAX had one; caches there were transparent. **Trade-offs.** The kernel survey counts over a hundred prefetch instructions across the four kernels, mostly in tuned list and copy code; an in-order core with no data cache gains nothing. **Modern comparables.** AArch64 `PRFM`, ARM `PLD`, PowerPC `DCBT`, x86 `PREFETCHT0`.

### B.1.8 Performance counters (P16)

**B.1.8.1** The proposal is two free-running counters, cycles and instructions retired, readable in user mode, added after the clock (P3) with the same enable bit. *(P)*

*Commentary.* **Precedent.** Unix profiled by sampling the program counter at clock ticks. **Trade-offs.** A user-readable cycle counter is a timing channel; a full counter block with event selection costs a large block and interrupt machinery. **Modern comparables.** x86 `RDPMC`, the AArch64 PMU, RISC-V's `hpm` counters.

### B.1.9 Constant-time execution (P17)

**B.1.9.1** The question is how to guarantee that instruction time does not depend on operand values; the proposal is a core set of instructions that is always constant-time plus a mode bit that extends the promise to divide, `MSCN`, `MCMP` and floating point. *(P, the author's request, option 3)*

*Commentary.* **Trade-offs.** Making all integer instructions constant-time would cost about 1% on average by a rough estimate, because divide is only 0.04% of compiled instructions (149 of 370,115; multiply costs nothing, since a fixed-latency multiplier needs less logic than one with an early-out); the mode bit keeps fast paths for ordinary code, which the author prefers. A constant-time instruction does not make code constant-time: a secret-dependent branch or table index still leaks through the predictor and the cache. **Precedent.** Neither ancestor addressed it; the PDP-11's multiply and divide were microcoded with operand-dependent times. **Modern comparables.** Arm's `DIT` bit, Intel's data-operand-independent timing mode, RISC-V's scalar-crypto timing subset. **Use.** Cryptography on secret keys. The published performance cost of those modes is being researched.

### B.1.10 The literal pool and execute-only code (P18)

**B.1.10.1** The proposal is an ABI rule: literal pools move out of `.text` into a read-only section beside it, so code pages hold only instructions and can be execute-only. *(P)*

*Commentary.* **Precedent.** The PDP-11's immediates sit in the instruction stream, and with separate instruction and data spaces a program could not read its own instructions as data. **Trade-offs.** The PC-relative reach limits how far the pool may be, and the linker must keep the two sections near each other. **Benefits.** Zero hardware; a memory-disclosure bug no longer reveals code. **Modern comparables.** OpenBSD makes code execute-only on amd64 and arm64; ARM compilers offer a flag to keep pools out of code.

### B.1.11 Vector and SIMD math (S1 to S6)

**B.1.11.1** The ISA has rejected separate vector registers in favour of a bus-attached coprocessor for wide data-parallel work; the proposal is to keep that, measure before adding anything, and, if vectors are ever built, make them length-agnostic. *(P)*

**B.1.11.2** The six open questions are: where data-parallel work lives (coprocessor, packed lanes in the integer registers, a fixed-width vector file, a scalable one, a matrix unit); which registers hold vectors; fixed or scalable length; how the machine state is saved on a context switch and whether the kernel may use it; which number formats (half precision, bfloat16, 8-bit integer dot products, 8-bit floating point); and the ABI and compiler support. *(P)*

*Commentary.* **Precedent.** The PDP-11 sent heavy numerical work to attached array processors; the VAX had a vector extension on its 6000 series, with 16 vector registers of 64 elements, supported by VMS; neither Unix used it much. **Trade-offs.** A fixed-width vector file brings a second register file and its context-switch cost, opcodes, and a new width for every generation (the history of SSE, AVX and AVX-512); a scalable design runs one binary on a small and a large implementation at the price of the most complex specification. Lazy saving of vector state was a security hole on x86, and Linux went back to eager restore. **Benefits.** The coprocessor needs no opcodes and no processor state. **Modern comparables.** ARM SVE and RISC-V V (scalable), ARM NEON, x86 AVX, PowerPC VSX, Alpha MVI. **Use.** Neural-network inference (the LB64 accelerator), graphics, signal processing and the library's string and memory routines. The evidence needed first: compile the corpus at higher optimisation and count vectorised loops, measure the share of time in memory and string routines, and decide the target workloads.

## B.2 The bus, boot and devices

### B.2.1 Data-cache maintenance by address (P6)

**B.2.1.1** The proposal is to reserve nothing: DMA buffers are uncached, so no cache instruction is needed until a non-coherent device appears. *(P)*

*Commentary.* **Precedent.** The 11/70's cache watched DMA writes; the VAX's adapter had data paths to purge. **Trade-offs.** Uncached buffers are slow to read; cache maintenance would speed them and needs three reserved sub-opcodes. **Modern comparables.** ARM, MIPS and embedded PowerPC with non-coherent DMA wrap cache maintenance in a DMA-mapping layer; x86 DMA is coherent.

### B.2.2 Firmware calls (P7)

**B.2.2.1** The proposal is none: everything goes through devices, with a required reset register and a watchdog in the bus controller. The kernel survey disagrees and would specify a firmware-call convention on reserved trap vectors. *(P)*

*Commentary.* **Precedent.** The PDP-11 kernel never called firmware; the VAX had console registers the kernel read and wrote. **Trade-offs.** No firmware means no firmware to trust and no extra privilege level, and every platform must say where its console and reset registers are, which the others get from firmware. **Modern comparables.** RISC-V's supervisor binary interface, ARM's PSCI and secure monitor calls, Alpha's PALcode, SPARC's Open Firmware.

### B.2.3 Double-width compare-and-swap and a random-number instruction (P8, P9)

**B.2.3.1** The proposals are to add neither: the evidence for a 128-bit compare-and-swap is one Linux use (software can tag a pointer with the 25 spare bits instead), and random numbers come from an entropy device on the bus rather than an instruction. *(P)*

*Commentary.* **Precedent.** The VAX solved the lock-free queue with whole-queue interlocked instructions; no machine of the period had a random-number instruction. **Modern comparables.** x86 `CMPXCHG16B`, AArch64 `CASP`, RISC-V `AMOCAS.Q`; x86 `RDRAND` and `RDSEED`, PowerPC `DARN`, s390 `PRNO`, AArch64 `RNDR`.

### B.2.4 The interrupt controller and routing to cores (R1)

**B.2.4.1** The proposal is wired interrupt lines to core 0 with a per-line target register, keeping the eight priority levels, with message-signalled interrupts added later. *(P)*

*Commentary.* **Precedent.** The PDP-11 had no controller; a device asserted one of four request lines and supplied its vector. **Trade-offs.** The smallest design adds no new failure cases and cannot give a fast multi-queue device its own interrupt. **Modern comparables.** x86's APIC, ARM's GIC, RISC-V's PLIC and AIA.

### B.2.5 Inter-processor interrupts and starting other cores (R2, B2)

**B.2.5.1** The proposal is a per-core doorbell register and a per-core start register in the bus controller (chapter 3), with `SEV` and `WFE` for waiting. *(P)*

*Commentary.* **Precedent.** The VAX's console processor started the other processors. **Modern comparables.** x86's INIT and START-UP sequence, ARM's PSCI and spin table, RISC-V's hart-start call.

### B.2.6 How coherence scales (R3)

**B.2.6.1** The proposal is to keep snooping for two to four cores and to record the ceiling. *(P)*

*Commentary.* **Trade-offs.** Directory protocols scale and are large; software coherence is cheap and fragile. **Modern comparables.** x86's snoop filters and directories across sockets, ARM's coherent interconnects.

### B.2.7 The bus transport (R4)

**B.2.7.1** The proposal is AXI as the transport, with Q64 as the model of ordering, memory types and the hand-off on top. *(P)*

*Commentary.* **Trade-offs.** It saves a bridge and makes the atomics a monitor naturally, and the Unibus's lock is no longer a native transaction. **Modern comparables.** ARM's AMBA, RISC-V's TileLink or AXI, FPGA systems on AXI throughout.

### B.2.8 The device layout and the descriptor (R5)

**B.2.8.1** The proposal is the uniform layout and the 32-byte descriptor of chapter 6, with an identification register first, and virtio-compatible devices only if reusing OpenBSD's drivers saves more than it costs. *(P)*

*Commentary.* **Precedent.** The RK11 and the DEUNA, as in chapter 6. **Trade-offs.** The single ring per device makes duplex devices two slots. **Modern comparables.** `virtio`, NVMe, SATA's command lists, Intel Ethernet's done bit.

### B.2.9 DMA addressing and protection (R6)

**B.2.9.1** The proposal is no translation unit for now: every device must be able to address all 40 bits of physical memory. *(P)*

*Commentary.* **Precedent.** The Unibus carried only 18 address bits, so the VAX and the larger PDP-11s had map registers that translated device addresses, in effect a simple translation unit for necessity. **Trade-offs.** No protection from a faulty or malicious device; a translation unit matters when virtualisation or untrusted devices do. **Modern comparables.** x86 VT-d, ARM SMMU, the RISC-V IOMMU; Linux's bounce buffers for limited devices.

### B.2.10 Errors raised by devices and the bus (R7)

**B.2.10.1** The proposal is the precise and imprecise paths the ISA already has plus a small register block in the bus controller for the cause. *(P)*

*Commentary.* **Precedent.** A PDP-11 bus timeout trapped through vector 4 and usually ended in a panic; the VAX had a machine-check frame. **Modern comparables.** x86's machine-check banks and PCI Express error reporting, ARM's RAS extension.

### B.2.11 Virtualisation (R8)

**B.2.11.1** The proposal is to declare it out of scope for System v1 and fix five constraints now: privileged state stays privileged or controllable, the page-table walker could be wrapped by a second level, interrupts are injectable, system-register access can trap, and the translation-enable bit and software accessed and dirty bits are reviewed for what a hypervisor would need. *(P)*

*Commentary.* **Precedent.** The PDP-11 was not designed for virtualisation and has sensitive instructions that do not trap in user mode; the VAX was not cleanly virtualisable either, and a 1991 paper described the changes needed. **Trade-offs.** Adding virtualisation late cost the VAX instruction changes; settling the constraints early costs a paragraph. **Modern comparables.** x86 VMX with nested paging, ARM exception level 2, the RISC-V hypervisor extension, IBM's trap-and-emulate machines.

### B.2.12 The bus controller's mechanisms (N1 to N3)

**B.2.12.1** The proposals are a fixed 4 KB page per slot with the mapping register for exceptions (N1), an interrupt with a small event queue and a rescan on overflow (N2), and an absent mark with a precise fault and the queued work left in memory (N3). *(P)*

*Commentary.* See section 2.6 and its commentary: the VAX's nexus scan, PCI's configuration space and all-ones reads, USB's status-change endpoint.

### B.2.13 The boot decisions (B1, B3, B4, B5, B8)

**B.2.13.1** The proposals are a boot ROM that reads block 0 (B1), a boot-information block of memory, cores, the bus controller's address and two slots (B3), an `INIT` bit with an optional firmware descriptor (B4), no UEFI, with a simple hand-off a shim could use (B5), and a block list in the protective MBR's boot code (B8). *(P)*

*Commentary.* See chapter 3 and [`../boot.md`](../boot.md): the PDP-11's block 0 and `ODT`, the VAX's boot block and restart parameter block, the BIOS and UEFI.

### B.2.14 How USB attaches, and virtio first

**B.2.14.1** The question is whether USB is a controller that shows each attached device as a bus slot, or a conventional ring-based host controller driven by an existing operating-system USB stack; and whether the emulator uses `virtio` devices first to reach an OpenBSD login sooner. *(P, for the author)*

*Commentary.* **Trade-offs.** Per-slot USB moves the protocol into the controller chip and takes the stack out of the operating system; the conventional controller uses code that already exists. `virtio` reuses OpenBSD's existing drivers in the emulator and defers the project's own eight-register devices to silicon; it gets to `ssh` faster and puts native devices later. **Modern comparables.** xHCI for the conventional controller; `virtio-mmio` on every emulated RISC-V and ARM board.
