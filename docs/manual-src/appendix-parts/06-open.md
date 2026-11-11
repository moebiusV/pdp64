<a id="j61"></a>
### J.6.1 Discovering the implemented widths

**Issue.** An implementation chooses its physical address width (from 40 to 64 bits) and its number of page-table levels (3, 4 or 5, giving virtual addresses of 39, 48 or 57 bits). The author's requirement is that this be "discoverable easily at runtime", so that one kernel binary adapts to the machine without a build option. How software learns the two numbers is not specified: no register or field reports them. System registers 0 to 12 are defined and 13 upward are reserved. A feature register is a read-only register whose fields describe the hardware; a probe is a write of a value followed by a read of what stuck.

**Why it matters.** The kernel must choose the walk depth and the width of every page number it writes. User code that tags pointers with spare high bits needs to know which bits are free: the top bit of the virtual address, which decides the canonical test, is bit 38, 47 or 56 according to the levels (6.9.1). The hardware cost is a few flip-flops. The body of 6.6 and statement 2.3.5 each carry a pointer to this entry. The same question covers the feature and identification registers that the numbers from 13 up would hold.

**Options.**

1. *A read-only feature register read by `MFSR`* (number 13), with fields for the physical bits, the maximum levels and the set of levels supported. For: one instruction in one place, no side effect and no mode change, room for later feature bits, and a read is always safe. Against: one register number and a few gates; privileged only, so user code that needs the canonical bit must ask the kernel (or see option 5); the layout is fixed forever once code depends on it.
2. *Probe by write and read back* (the register accepts any write and holds only a legal value). The kernel writes the level count it wants into a field of `MMUCTL` and reads back; an unsupported value leaves the old one. The physical width is found by writing all ones to a field that holds a page number and reading what stuck. For: no new register, no new instruction. Against: a write with a side effect (it changes the translation mode, needs `ISYNC`, can crash if translation is on); the probe code is longer than one `MFSR`; the width probe needs a writable field of the right width, which may not exist; a probe is a place for error.
3. *Both: a read-only register for what exists, and a writable field to choose.* The register reports the maximum and the set supported, as a bit mask with one bit per level count; a field in `MMUCTL` selects the number in use, legal only if its bit is set. For: one read to learn, one write to choose; the kernel may run three levels on a five-level machine for compatibility or to save walk cost; a bad write is detectable. Against: a register and a field, the most state of any option; whether a machine must support all lower level counts becomes a rule (three levels on every machine is what the author's "System v1" form implies, errata 96, so the mask would say 3 always, 4 and 5 optional).
4. *The boot ROM states the widths in the boot-information block and the processor reports nothing.* For: the block already lists the memory ranges and the root-complex address, so the early kernel reads it with the rest; the processor is unchanged. Against: the facts do not come from the hardware itself, and a stale or wrong block gives wrong widths that cannot be detected; useless to a second-stage loader run by hand or a bare-metal program that has no block.
5. *An unprivileged read-only register or instruction* (a counterpart of x86's CPUID, readable in user mode). For: a JIT compiler or a pointer-tagging runtime learns the canonical bit without a system call; the information is not secret. Against: a new user-visible instruction, or an exception to the rule that system registers are privileged (6.2.5); a virtualiser or sandbox cannot hide it; it lets a program fingerprint the machine.
6. *A profile number instead of fields.* One read-only identification register says "profile 1 is 3 levels and 40 bits, profile 2 is 4 levels and 48 bits", and the manual defines each profile. For: a few well-tested combinations in place of the 3 by 25 that would have to be verified. Against: every new width forces a new profile; the freedom "40 to 64 anywhere" (errata 102) is lost; the kernel needs a table.

**Precedents.** x86 reports physical bits in bits 7:0 and virtual bits in bits 15:8 of CPUID leaf 0x80000008, and a 57-bit virtual address by the LA57 bit of leaf 7 *(verified: QEMU `target/i386/cpu.c`)*; CPUID is readable in user mode *(unverified)*. AArch64 reports the physical range in the PARange field of `ID_AA64MMFR0`, bits 3:0 *(verified: QEMU `target/arm/cpu-features.h`)*. LoongArch reports PALEN and VALEN in fields of `CPUCFG1` *(verified: QEMU `target/loongarch/cpu.h`)*. RISC-V's `satp` register ignores a write of an unsupported mode *(verified: QEMU `target/riscv/tcg/csr.c`)*, and QEMU keeps a bit mask of supported modes and checks the write against it *(verified: `target/riscv/cpu.c`)*; x86 turns on five-level paging by setting `CR4.LA57` only where CPUID reports it *(the CPUID bit verified, the control bit unverified)*. Linux on RISC-V and ARM learns the memory mode from the device tree the loader passes *(unverified)*; the VAX restart parameter block and the Alpha hardware restart parameter block carry machine parameters *(named in the boot chapter's sources)*. RISC-V profiles (RVA20, RVA22, RVA23) define sets of mandatory extensions *(unverified)*.

**The author's referents.** "as long as this info is discoverable easily at runtime" (chosen); "good thing we already had dmw in the design!" (chosen); of LoongArch, "looking at loongarch64, they are pragmatic; what can we learn from them and adopt" and "what other parts of the design are effected if we have 5 level tlb like loongso[n]" (both considered); "what is the largest physical ram supported right now by any cpu? how many table levels?" (considered).

**The assistant's leaning.** Option 1 first: a read-only `MMUCFG` at system register 13 with the physical bits, a mask of supported level counts and the virtual bits. It needs no probe, so a bad value cannot arise, and the number 13 is already reserved. The writable selector of option 3 is added only if the author wants a kernel to run fewer levels than the maximum. Option 2 would be the choice if the author wants no new register, and option 5 as a user-readable copy if user code needs the canonical bit.

**Where the body refers to it.** Sections 2.3.5 and 6.6.1.

<a id="j62"></a>
### J.6.2 The page-table entry for wide physical addresses

**Issue.** The page-table entry is 64 bits, with the physical page number in bits 12 to 39 (28 bits, a 40-bit physical address) and bits 10, 11 and 40 to 63 reserved and zero. The author has decided that the physical address may be anywhere from 40 to 64 bits (errata 102) and that the old rule of using bit 39 to tell device space from memory is gone, because "if we are going to mmap petabytes, we need those bits". A 64-bit physical address needs a 52-bit page number, bits 12 to 63, and that leaves no bit above bit 11 for any flag. The question is where the page number sits, how wide it may be, and where spare flag bits go. 2^52 bytes is 4 PiB and 2^64 bytes is 16 EiB.

**Why it matters.** Every `fork`, `mmap` and fault handler writes entries, so the position of the page number is shift-and-mask code on the hot path. In hardware, the width of each translation-buffer entry and of the physical tag of every cache grows with the page number: 52 bits in place of 28 is 24 more bits per translation-buffer entry, and a 32 KB cache with 64-byte lines (512 lines) would carry 24 more tag bits each, about 12,000 flip-flops (an estimate, not a measurement). Statements 6.7.1, 6.6.2 and 6.7.5 wait on the answer, and the memory type has only two bits (8 and 9) with nowhere to grow.

**Options.**

1. *The page number in place, bits 12 to 63.* For: no change for the 40-bit machine (bits 12 to 39 stay), the present text is a subset, and the hardware extracts the same field; cheapest in hardware. Against: no spare bit remains for any later flag (a no-execute extension, a wider memory type, a protection key, software bits), so any later flag forces a new format.
2. *Cap the page number at 40 bits (a physical address of 52 bits), in place at bits 12 to 51, with bits 52 to 63 for flags and software.* For: twelve spare bits and 4 PiB of reach, which already covers "petabytes"; room for protection. Against: it contradicts "up to full 64 bit" (errata 102), which becomes "40 to 52 in page tables"; a device mapped above 2^52 cannot go through a page table (see option 5).
3. *Move the page number down to bit 10, as RISC-V does.* The page number occupies bits 10 to 61 (52 bits) and bits 62 and 63 are free. For: a 64-bit address fits and two bits remain at the top. Against: the physical address is `(pte >> 10) << 12`, one more step in the walker and the kernel; every existing entry format is rewritten; only two spare bits, and a 64-bit device address still uses all of them; no gain in reach over option 2 if option 2's cap is accepted.
4. *Keep the 64-bit entry, but the page-number width equals the implemented physical width.* Bits above the implemented width are reserved and must be zero, and the spare bits are defined only as "the bits above the physical width". For: a 40-bit machine keeps bits 40 to 63 for future flags, a 64-bit machine has none; one format with varying free space; a reserved-bit fault is a good detector. Against: the position of a flag depends on the implementation, so code that uses a spare bit works on 40-bit machines and not on 64-bit ones; the detection works only above the implemented width.
5. *Page tables reach 52 bits (option 2), and everything above is reached by the direct-mapping windows* `DMW0` and `DMW1`, whose physical base is a full 64-bit field. A direct-mapping window (appendix I, 6.9.2) maps a range of virtual addresses to a range of physical addresses with no table walk. For: "good thing we already had dmw in the design!"; one window maps a petabyte-scale device or a very large memory without any entry, and the entries keep their spare bits. Against: only two windows; user processes cannot map above 2^52, because a window is kernel-only; the window format, which the author has deferred (appendix I, 6.9.2), would have to be designed now, and the registers are at present stored without effect.
6. *A 16-byte entry (128 bits).* For: no cramping; a full 64-bit address, memory type, protection key and 40 free bits. Against: 256 entries per 4 KB table, so 8 bits per level, and three levels cover only 36 bits and five levels 60; the whole 39, 48 and 57-bit design of errata 96 changes; twice the memory per walk step; larger translation-buffer entries.

**Precedents.** x86-64 addresses bits 51 to 12 in place, with the no-execute bit at 63 *(the mask verified in QEMU `target/i386/cpu.h`, the rest unverified)*, and puts protection keys in the upper bits *(unverified)*; reserved bits above the implemented physical width must be zero and fault *(unverified)*. AArch64's large-physical-address extension stops at 52 bits *(verified: QEMU `target/arm/ptw.c`, the table of sizes ends at 52)*, and output-address bits above the implemented range are reserved *(unverified)*. RISC-V puts the page number at bit 10, with up to 44 bits at 10 to 53, flag fields at 63 to 61 and bits 60 to 54 reserved *(verified: QEMU `target/riscv/cpu_bits.h`)*. LoongArch direct-mapping windows are named in the ISA text, and MIPS's KSEG0 is the older example *(MIPS behaviour unverified)*. IBM's z/Architecture has region and segment tables of another shape *(unverified)*; no common processor uses a 128-bit entry.

**The author's referents.** "if we are going to mmap petabytes, we need those bits" (chosen); "good thing we already had dmw in the design!", and his question "what are dmw registers? part of pcie?" (chosen); "what other parts of the design are effected if we have 5 level tlb like loongso[n]" (considered).

**The assistant's leaning.** Option 2 for page tables with option 5 for the rest: a 40-bit page number (a 52-bit physical address through page tables, 4 PiB) and the windows for anything above. A 64-bit page number consumes the whole entry, and every later need (protection, memory type, a no-execute bit separate from `X`) would force a new format, whereas 2^52 already covers "petabytes". If the author insists that user processes map above 2^52, option 3 (page number shifted to bit 10, two spare bits) is the alternative.

**Where the body refers to it.** Sections 6.7.1 and A.6.1.

<a id="j63"></a>
### J.6.3 Interrupt delivery and vector numbers

**Issue.** How does a device's interrupt reach one of the cores, how many vectors are there, how are they numbered and prioritised, and how is an interrupt moved from one core to another? The old bus made this trivial: each slot had a number and the vector came from it. PCI Express devices have no slot in that sense, and the author retired slot-derived vectors (errata 29, 49 and 75). The PCI Express answer is **MSI-X** (message-signalled interrupts: the device performs an ordinary memory write whose address and data say which core and which vector, and the write itself is the interrupt, with no wire). Every virtio device carries one MSI-X vector for a change of its configuration and one for each queue (2.6 and 2.7.4). What is missing is the unit on the processor side that receives the write and turns it into "core N takes vector V at level L". A second fact bounds the answer: the vector table has 512 entries, entries 32 to 255 are available to interrupts, 256 to 511 are `TRAP #n`, so only 224 vector numbers (32 to 255) can be used by interrupts.

**Why it matters.** OpenBSD needs an interrupt-controller driver and a number of vectors. Linux's complaint, on x86, is that 256 vectors per core are shared by every device class; a device with many queues (a network card, an NVMe disk) wants one vector per queue per core. In hardware, the controller needs per-core pending state, a path to receive writes and perhaps a remapping table; the rule that an interrupt entry sets priority 7 (errata 40) and the wake-up of `WFE` (7.10.2) must agree with it. The interrupt write must not overtake the data writes before it, and a moved target must be masked and read back or changed atomically (errata 71). Statements 2.6.3, 5.9, 7.10.4 and 7.10.5 and the vector table of 6.3.6 wait on the answer; the eight priority levels (6.3.7) are decided.

**Options.**

1. *A per-core interrupt file, messages only.* Each core has a 4 KB page in the controller at `base + 4096 * core`. An MSI-X write of a vector number sets that vector's pending bit in that core's file; each vector has a 3-bit level and an enable bit; the core takes the highest pending enabled vector above the priority in the status word and puts its number in `ECAUSE`. Vector *n* of the file maps to a table entry in the interrupt range (so the file has 224 vectors, 32 to 255, or entries are remapped). For: scales to any core count; the same store is the inter-processor interrupt; no claim read (one memory fetch fewer than RISC-V's PLIC or ARM's GIC); the status-word level stays the only threshold; the pending file sits outside the pipeline, which suits an out-of-order core. Against: about 1,300 bits of state per core by the estimate of the multiprocessor record (a few hundred look-up tables in an FPGA, or a small RAM); a wired legacy source needs a converter; on its own it gives no protection, because a hostile device's write can reach the wrong core (that is option 2).
2. *Option 1 plus an IOMMU interrupt-remapping table.* The device's write carries an index, not a core number; the IOMMU (the unit that translates and checks the addresses of devices) maps the index to a core, a vector and a level in a 64-bit entry; retargeting is one atomic 64-bit store; a hostile device reaches only the entries the kernel gave it. The kernel owns the vector numbers of each core, and devices see only indices. For: gives many vectors, atomic retargeting and masking during a change by construction; forged interrupts cannot arise; invisible to cards (errata 81); an IOMMU already exists for DMA (errata 85). Against: a table walk or entry cache on every interrupt write, and a structure to size (about 1,024 entries of 8 bytes per device range for the first iteration); the IOMMU becomes a dependency of interrupts, so a broken IOMMU silences them; the author must decide whether remapping belongs to the first iteration.
3. *A GIC-style distributor with an ITS.* A central block holds all state, a distributor forwards to per-core interfaces and a translation service (the ITS) turns messages into interrupts; 16 software-generated interrupts per core serve as inter-processor interrupts. For: mature and well tested; it would match ARM software; full affinity control from one place. Against: the largest block and by far the largest driver (2,166 lines in OpenBSD against 375 plus 228 for RISC-V's IMSIC and APLIC); no benefit over option 2 in a design with no legacy; more state to get wrong.
4. *Wired lines to core 0 with a per-line target register.* One wire per device into a small controller whose per-line register names a core; messages may be added later; the vector can be 32 plus the line number. For: the smallest (PDP-11 style: bus-request lines BR4 to BR7, with the device supplying its own vector); enough for a four-core machine with a UART, a timer and a few virtio devices. Against: virtio devices raise messages, not wires, so an adapter is needed anyway; every interrupt of sixteen cores goes through one front door; a per-queue vector cannot have its own target; shared level lines have the "nobody cared" interrupt storms recorded in the Linux sources.
5. *Interrupts as events in a per-core memory ring, with one doorbell per core.* The controller appends (device, queue, level) to a ring in the core's memory and raises one wake signal; the handler reads the ring; the vector is the single doorbell number. For: consistent with the choice for virtio that progress lives in memory (5.2.4); one hardware vector per core, so the 224-entry problem disappears; priority is eight rings or a field; the handler reads memory it was going to read anyway. Against: the controller becomes a bus master that writes memory on every interrupt, so it needs the IOMMU treatment; the ring can overflow, and the overflow rule is new; hardware priority arbitration is replaced by software ordering of rings; no OpenBSD driver exists to copy.
6. *Polled devices on dedicated cores, interrupts only for inter-processor signals, the timer and errors.* The graphics, network and audio cores poll their queues (a driver may mask interrupts and poll, 2.6.3 and 5.9.2, decided); general cores take only inter-processor interrupts, the timer and device-error interrupts, with a small fixed vector set (for example 32 timer, 33 inter-processor, 34 error, 35 hot-plug alert). For: removes most interrupt work from the cores that run the kernel; vector numbers stay a handful, so numbering is trivial; compatible with options 1 or 2 as a front end. Against: needs dedicated cores, which is still only a proposal; a polling core burns power that `WFE` and interrupts would save; the disk and console on a general core still need some interrupt; it hides the delivery question for any device a general core drives.

**Precedents.** RISC-V's AIA has an interrupt file per hart with enable, pending and threshold registers (the IMSIC); OpenBSD's driver is 375 lines and keeps a threshold table per priority level, and Linux has the same driver in files of 308, 390 and 977 lines plus a header *(verified: line counts and sources of the local tree)*. Intel's VT-d interrupt remapping puts a table between the device's message and its destination *(unverified)*; ARM's GICv3 ITS translates a device identifier and an event identifier to an interrupt through tables *(file existence verified, 5,903 lines in Linux; behaviour unverified)*. The ARM GIC with GICv3 redistributors and the ITS has OpenBSD's `agintc.c` of 2,166 lines *(verified)*. The PDP-11 had bus-request lines and device-supplied vectors *(verified in the repository's sources)*; RISC-V's PLIC has wired sources and a priority and threshold per context, in a 737-line OpenBSD driver *(verified)*; RISC-V's APLIC converts wired lines to messages in 228 lines *(verified)*. POWER's XIVE uses event queues with per-queue notification *(names verified, behaviour unverified)*; NVMe completion queues and virtio used rings have the same shape for completions *(verified in the repository)*. Polled-mode network and storage stacks (DPDK, SPDK) and Linux's NAPI, which turns interrupts off under load, follow the model of option 6 *(unverified)*.

**The author's referents.** "go with priority 7 on entry and document its throwback to pdp-11 design" (chosen); "what if all interrupts were suspended/defered for one instruction giving time for that spl #7" (considered); "iommu will allow us to map in c64/c128" (considered); "survey of what all major modern os and cpu do, plus vax/pdp" (considered); "virtio across the board" (chosen).

**The assistant's leaning.** Option 2 as the end state, in two steps: option 1 in the first iteration, since a four-core machine with virtio devices gains little from remapping, and the remapping table before sixteen cores or untrusted devices. For the numbering, the file's vector number is 8 bits and is delivered in `ECAUSE` at a fixed offset (entry 32 + *n* for *n* from 0 to 223, entries 224 to 255 of the file unused), or the `TRAP` range moves; the author has not yet been shown the 224-entry fact and should decide this. The fixed devices (timer and UART, J.5.1) enter through a small wired-to-message converter, as RISC-V's APLIC does. A first iteration that never exceeds a dozen vectors would favour option 6 as a stand-in; a wish for ARM-compatible software favours option 3; a finding by the OpenBSD port that a per-core threshold register is needed would add an IMSIC-style threshold to option 1.

**Where the body refers to it.** Sections 2.6.1, 5.9.1, 5.9.4, 6.3.7, 7.10.4 and 7.10.5.


<a id="j64"></a>
### J.6.4 The register number and the layout of the kernel's root table (KTBR)

**Issue.** The author accepted the split of the address space by its top bit (errata 71): the lower half is walked from `PTBR`, one table for each address space, and the upper half from a second register, `KTBR`, one table for the whole system. The system-register table (6.5.1) has no number for `KTBR`: numbers 0 to 12 are taken and 13 and up are reserved. Nothing says how the top-level tables of the two roots are laid out. With the split by the top bit, each root has 256 entries in use at the top level (the top level has 512 entries and the top bit picks the half), so a root could be a full page with half of it unused, or a half page. Nor is it settled whether the user half is the lower half in every case.

**Why it matters.** The kernel writes `KTBR` once and the walker reads it on every upper-half miss, so the number is fixed in the instruction stream of every kernel (`MTSR` takes an 8-bit constant), and the layout decides how a kernel builds its tables and whether a page can hold both roots. It also decides what a user process with two halves (a guest kernel, a library with its own privilege) could do.

**Options.**

1. *Number 13, the first free register.* For: no gap, and the numbers 0 to 12 stay as they are. Against: it takes the number that J.6.1 would use for a feature register, so one of them moves.
2. *A number in a block kept for translation (for example 16 and up), leaving 13 to 15 for identification.* For: translation registers stay together, and identification keeps its own run. Against: a gap in the numbering, and the decision about the block is itself new.
3. *Each root is a full page; `KTBR` holds the address of a 4 KB table whose upper 256 entries are used.* For: the same table shape as every level, so one walker routine serves both roots. Against: half a page of each root is unused; with one kernel root for the whole system the loss is small, with a root for each address space it is not.
4. *`PTBR` and `KTBR` each point at a half-page of 256 entries.* For: no unused entries. Against: a table that is not page-sized is an exception to the rule that every table is one page (6.6), and a page cannot be given back whole.
5. *One shared table with two roots indexed by the top bit* (what x86 kernels do when they share a table and split it by position in the top level). For: a single register, so the number question disappears. Against: the user half would see the kernel entries in the same table, which is what the split was made to avoid (the speculative read of kernel translations, 6.9.1); this is the arrangement the author's decision replaced.
6. *The upper half is selected by a field instead of the top bit* (a base and a size register). For: the kernel could choose where the halves meet. Against: it defeats the canonical test that decides the half by one bit and puts a comparator in the walker.

**Precedents.** AArch64 has two translation base registers, `TTBR0` and `TTBR1`, and selects between them by the top bits of the address *(unverified: not in the QEMU source checked here)*. RISC-V has one `satp` and no second root *(verified in the QEMU source)*. x86 kernels shared the user's tables until page-table isolation of January 2018 and have since switched the table on every entry *(repository text: `docs/kernel-pain-points.md`, row 1)*. The VAX had a base register for the process space and another for the system space *(unverified)*.

**The author's referents.** His acceptance of "all 8" of the edits of research round 7 (errata 71), of which the split is one.

**The assistant's leaning.** Option 1 with option 3: `KTBR` as number 13 if J.6.1 puts its feature register elsewhere, otherwise the first number after the feature block, and each root a full page. It costs the least new rule; the unused half is small because there is one kernel root.

**Where the body refers to it.** Section 6.9.1.


<a id="j65"></a>
### J.6.5 The system-call register convention

**Issue.** A system call is `TRAP #n` through vector 256 + n (6.10.2), and the call number and arguments "travel in registers by the ABI". Appendix D, the ABI, does not say which registers. In V7 the call number was fetched back from the user's `sys n` instruction and the arguments were read from the user's stack with `fuword`.

**Why it matters.** The first operating system (OpenBSD, 6.12.2) and its C library each hard-code the convention, and so does a system-call stub. The kernel's entry code reads the registers before it knows anything else about the process. A convention that overlaps the registers the callee-saved rule preserves costs a move on every call.

**Options.**

1. *The number in the `TRAP` vector alone, and arguments in the first argument registers of the ordinary calling convention.* The vector number is the system-call number, so the kernel dispatches in hardware. For: no register carries the number, and the dispatch is a table lookup. Against: 256 numbers (`TRAPL` reaches them), which is a limit, and an operating system with more calls than that needs a second level.
2. *The number in one register (the first argument register or a dedicated one), arguments in the following ones, and one vector (`TRAP #0`).* For: the form of Linux and of the BSDs on every architecture *(unverified)*; any number of calls; one entry point. Against: one register is spent on the number; the dispatcher reads it before using the table.
3. *The number in the `TRAP` operand and arguments in the argument registers, results in the first result register, an error in the carry flag.* For: PDP-11 Unix reported an error in the carry bit after `sys` *(unverified)* and the BSDs on x86 kept it; the result and error need no second register. Against: ties the convention to the flags, which the entry clears (6.3.2) and the exit must set.
4. *The number in a register and the arguments in memory at an address held in a register.* For: any number of arguments without a limit from the register file. Against: the kernel must read user memory with the guard open (6.10) before it can dispatch, which is the V7 cost the register form was meant to remove.
5. *Follow the platform's ordinary calling convention exactly, so the stub is a function with one `TRAP`.* For: the compiler needs no special case; a wrapper of the C library is trivial. Against: the callee-saved registers and the argument registers are the ABI's to choose first (appendix D), so this option only moves the question.

**Precedents.** V7 read the number from the user's instruction and the arguments from the user's stack *(verified: `trap.c` on this machine)*. Linux and the BSDs on x86-64 and AArch64 put the number in a register and the arguments in the first registers *(unverified)*; RISC-V Linux uses `a7` for the number and `a0` to `a5` for arguments *(unverified)*.

**The author's referents.** None recorded for the convention; the decisions are that `TRAP #n` has its own vector (6.10.2) and that the ABI names the registers.

**The assistant's leaning.** Option 2 with the error and result in registers, following the ABI's argument registers, because it matches what the first operating system's other ports do. The author or the ABI work decides it, and the decision belongs in appendix D.

**Where the body refers to it.** Section 6.10.1.


<a id="j66"></a>
### J.6.6 Enabling translation safely

**Issue.** Translation is off at reset and `MMUCTL` bit 0 turns it on (6.8.2); the write takes effect after the next `ISYNC` (6.5.2). The instruction after the `ISYNC` is fetched through the new tables. The running code was fetched at a physical address, so it continues only if the new tables map it at the same address, or if something else (a window, a trampoline, a second mapping) covers it. The architecture does not say which.

**Why it matters.** Every kernel's first page of boot code has to do this. If the architecture does not say how it is safe, each port invents a trick, and a trick that depends on the implementation (the length of an instruction queue, say) is a bug.

**Options.**

1. *The kernel maps its own boot code at the address it is running at.* The kernel builds the tables so that the virtual address of the next instruction equals its physical address (an identity mapping of the boot code), enables translation, and jumps to the real address. For: no hardware help; it is what the first OS ports to RISC-V do. Against: the kernel must build an identity mapping before it can enable anything, and tear it down after.
2. *A direct-mapping window covers physical memory at reset or at the write.* For: the kernel need not build anything first. Against: the format of the windows is deferred (appendix I, 6.9.2), and the ISA text's old rule that `DMW0` covers physical memory at reset was superseded by errata 44, so this option needs the deferred decision made.
3. *Translation enables in two steps: the write sets a bit that takes effect at the next `RTI`.* The kernel arranges `EPC` and `EPSW` so that the `RTI` jumps to the mapped address. For: one clean transition, in the same way the kernel already leaves for user mode. Against: a new rule for one bit, and `RTI` now has a second job.
4. *The write takes effect immediately and the instruction after it is fetched physical, once.* For: no mapping needed for that single instruction, and the kernel puts a jump there. Against: it breaks the rule that `ISYNC` is the point at which a change takes effect (6.5.2), and an out-of-order core cannot promise it.
5. *A bare mode: when translation is on, an address in the first page range is still taken as physical.* For: the early kernel keeps running where it is. Against: it recreates a fixed window the architecture otherwise refuses (errata 97: no address bit means "device"), and the range is another number to choose (J.4.1).
6. *The boot ROM enables translation with a ready-made identity table and hands over with translation on.* For: the kernel starts in a mapped world. Against: the reset state is then different from the decided one (translation off, 6.8.2), and the ROM carries a page table.

**Precedents.** RISC-V's `satp` has a bare mode and kernels turn paging on after an identity mapping or a jump to a mapped trampoline *(satp modes verified in QEMU; the kernel practice unverified)*. AArch64 has `SCTLR.M`, and a kernel that turns the MMU on runs from an identity-mapped page *(unverified)*. The PDP-11 enabled the memory manager by a write to `SSR0` and the V7 boot code ran with the map loaded to identity (`mov $1,SSR0` in `mch_i.s`, verified; the identity map unverified). The VAX turned on mapping with `MAPEN` and a jump to a mapped address *(unverified)*.

**The author's referents.** "good thing we already had dmw in the design!" (chosen; deferred by errata 44).

**The assistant's leaning.** Option 1, since it needs no new rule and is what a kernel already does. If a window is later specified, option 2 makes the early kernel simpler and can be added without changing option 1.

**Where the body refers to it.** Section 6.12.2.


<a id="j67"></a>
### J.6.7 Saving and restoring a thread's user `DP`

**Issue.** `DP` is the direct-page register, banked by mode (6.2.4). A user program's copy points to its thread's private data. At a thread switch the kernel must save the old thread's user `DP` and restore the new one's. `MTDP` and `MFDP` name only the copy of the current mode, and the system-register table (6.5.1) has no number for the user's `DP`, whereas `USP` and `SSP` have (numbers 6 and 7).

**Why it matters.** Every thread switch and every signal frame needs the thread pointer. Without a way to read and write the user copy from kernel mode, the kernel cannot give threads their own thread-local storage, which every C library with threads needs.

**Options.**

1. *A system register for the user's `DP`* (for example `UDP`, beside `USP`). For: the same idiom as `USP`; one `MFSR` and one `MTSR`. Against: one more register number, and the supervisor copy would want its own for symmetry.
2. *An instruction that reads or writes the previous mode's `DP`* (as `MFPI` and `MTPI` reach the previous mode's space on the PDP-11). For: no number; the previous mode field already says which. Against: a new opcode, and it works only on the way in from user mode, not for a thread other than the one that trapped.
3. *The kernel keeps the thread pointer in its own thread structure and writes it back into the trap frame.* The user's `DP` is saved on entry like any other register. For: no new hardware; `DP` becomes an ordinary register for exception handling. Against: the entry code must save a banked register that the hardware did not save for it, so the claim that entry costs one `PUSHX` and a few stores no longer holds for it.
4. *The thread pointer is an ordinary general register by the ABI, as RISC-V's `tp` is, and `DP` stays the per-CPU pointer in kernel mode only.* For: no banked user copy; the register is saved in the trap frame with the rest. Against: the user `DP` is a decided feature (6.2.4, the thread pointer is one `MOVQ d(DP), Rd`), and removing the user copy is a change of the decided design.
5. *`MTDP` and `MFDP` in kernel mode with a mode operand.* For: one pair of instructions. Against: it changes decided instructions.

**Precedents.** RISC-V keeps the thread pointer in the general register `tp` and the kernel saves it in the trap frame *(unverified)*. x86-64 reads the user's `FS` base with `rdfsbase` or writes it with `wrfsbase`, and the kernel swaps `GS` with `swapgs` *(unverified)*. AArch64 has `TPIDR_EL0` for the user thread pointer, reachable by `MRS` and `MSR` from the kernel *(unverified)*. The PDP-11 reached the other space by `MFPI` and `MTPI` *(verified: V7 source)*.

**The author's referents.** None recorded; the banked `DP` is the author's decision (6.2.4).

**The assistant's leaning.** Option 1, in the same register table as `USP`, because it repeats a pattern that is already decided.

**Where the body refers to it.** Section 6.11.


<a id="j68"></a>
### J.6.8 What a write to the translation registers flushes, and invalidating by address-space number

**Issue.** Two texts of the specification disagree. Section 6.8 (and the purpose of the address-space tags) says that a context switch is a write to `PTBR` and to `ASID` and an `ISYNC`, with the old process's entries staying in the buffer. The entry of `MFSR` in chapter 9 says that a write to `PTBR`, `ASID` or `MMUCTL` flushes the whole translation buffer. The reference executor does the latter (`docs/implementation-status.md`). A related gap: the architecture has `TLBI` (by address) and `TLBIA` (everything) but no invalidate by `ASID`, so a kernel that reuses a number, or that wraps the 16-bit counter, can only flush everything; the policy for a wrap is the kernel's.

**Why it matters.** If a write flushes, tags save nothing and every context switch pays a refill of the buffer, which is what the tags were added to avoid. If it does not flush, the hardware must keep the stale entries of a retired address space until they are replaced, and an `ASID` reused by a new process must first be invalidated, or the old entries would answer for it.

**Options.**

1. *A write to `PTBR`, `ASID` or `MMUCTL` flushes nothing; the kernel invalidates when it reuses a number.* For: the tags work, and a switch costs two register writes. Against: a reused `ASID` needs a whole-buffer flush (`TLBIA`) or an invalidate-by-ASID instruction, and a mistake in the kernel's allocator shows up as a wrong translation.
2. *A write to `MMUCTL` flushes everything, and a write to `PTBR` or `ASID` flushes nothing.* For: turning translation on or off is rare, so a flush there is cheap, and it removes stale state at the one moment when it matters. Against: one more rule to state, and an extra flush on a write that sets only a bit.
3. *Every write flushes the entries of the old tag only.* For: the old process's entries cannot answer under a reused number. Against: it is a hardware search for the tag on a write, as costly as an invalidate by ASID; the entries that survive are the ones of other tags.
4. *Add `TLBIASID rN`, an invalidate by address-space number, to option 1.* For: the cheap way to reuse one number without flushing the others; a wrap is then a loop over numbers or a `TLBIA`. Against: a new broadcast instruction (each core must search the tag), and the kernel needs the bookkeeping either way.
5. *Flush all on every write to `PTBR` or `ASID`* (the text of chapter 9 today). For: the simplest hardware, with no tag matching in the invalidate path; the buffer is always consistent with the registers. Against: the tags are then dead weight (16 bits in every buffer entry), and every switch is a full refill.
6. *The tag has the generation in it* (the high bits count the wraps). For: a wrap needs no flush because an old number never equals a new one. Against: a wider tag, and the generation is the kernel's policy, not the hardware's, so this is option 1 with the policy written in.

**Precedents.** RISC-V's `satp` carries a 16-bit address-space number and the `sfence.vma` instruction can invalidate by it *(`SATP64_ASID` verified in the QEMU source; the instruction form unverified)*. x86 has a process-context tag (`CR4.PCIDE`, verified in the QEMU source) and an instruction `invpcid` that invalidates by it *(unverified)*. AArch64 has `TLBI ASIDE1` *(unverified)*. The PDP-11 loaded all page registers at each switch and had no buffer to flush.

**The author's referents.** The ISA text takes the `ASID` and the `G` bit from the Commodore 128's memory-management unit (`docs/pdp64-isa.md` section 8.1); the purpose of the tag, a switch without a flush, is stated in 6.8.

**The assistant's leaning.** Option 1, and the entry of `MFSR` in chapter 9 corrected to match; the invalidate by number of option 4 only if the first kernel finds that `TLBIA` at each wrap is too expensive.

**Where the body refers to it.** Section 6.8.3. chapter 9 (the entry of `MFSR`).


<a id="j69"></a>
### J.6.9 Whether supervisor mode has a use

**Issue.** The status word has a mode field of two bits with kernel 0, supervisor 1 and user 3, and the value 2 reserved (6.2.2). The stack pointer and `DP` are banked for supervisor mode as for the other two (6.2.4), and the system registers include `SSP`. No code uses the mode. The mode is decided; whether it has a use is not. 2.11BSD runs its network code in supervisor mode on the PDP-11 (`trap()` tests `SUPVMODE(ps)`, verified).

**Why it matters.** A mode that nothing uses costs a third copy of two registers and a third set of mode checks (`docs/pdp64-system-design.md`, "an unresolved question, not a decision"). If it is to be used, the kernel's entry code, the page-table permission bits (`U` has no supervisor form) and the privileged-instruction set (6.2.5) would need rules for it. If it is not, the question is only whether to keep or remove it.

**What the earlier text said (restored at the author's request, errata 117).** "Three modes cost a third copy of two registers and no logic the kernel uses; supervisor mode has no user, and is included because adding a mode would change the status word and every saved copy of it." That is the assistant's inference, not the author's statement, and no document gives a reason; `docs/pdp64-system-architecture.md` (section 1) says the mode is carried from the PDP-11, whose Unix did not use it. Checked against the status word: the mode field is two bits wide, so kernel 0, supervisor 1 and user 3 fill it with the value 2 reserved. Dropping supervisor mode would not free a bit, because kernel 0 and user 3 still need both bits, so the third mode costs nothing in the word. The earlier wording is weaker than it looked: a fourth mode (the value 2) would also fit without changing the layout, so "adding a mode would change the status word" holds only for a fifth mode or a change of encoding. What the PDP-11 encoding does buy is that the values need no translation for anyone who knows the PDP-11.

**Options.**

1. *Keep it unused.* For: nothing to build or specify; a later use needs no change of the status word. Against: a third bank of two registers and a mode comparison that nothing uses.
2. *Use it for a library with its own privilege* (a user-level subsystem protected from the program that calls it). For: finer protection between the kernel and a program. Against: needs a page permission that supervisor but not user may use, a new `U`-like bit, and a way to enter and leave the mode cheaply.
3. *Use it for a hypervisor's guest kernel* (the guest runs in supervisor mode and the host in kernel mode). For: a guest kernel needs a privilege between its host and its user programs. Against: a hypervisor needs more than a mode (a second translation, virtual-machine control), which is not specified.
4. *Use it for the network stack, as 2.11BSD did.* For: the one historical use; a bug in the stack cannot reach the kernel's own data. Against: 2.11BSD gave it up in later systems *(unverified)*; the cost of the mode change on each packet.
5. *Remove the mode and reserve the value 3 for user and 2 and 1 as illegal.* For: three copies become two and the decode is simpler. Against: the status-word layout does not change, so no bit is saved (see above); loses the PDP-11 encoding's meaning; reverses a decided statement (6.2.1).
6. *Make the mode field a width that holds four modes, reserve the fourth for a hypervisor.* For: room to grow. Against: it already holds four values; the value 2 is free now.

**Precedents.** x86 has four rings of which two are used *(unverified)*; AArch64 has exception levels 0 to 3, of which a hypervisor uses level 2 *(unverified)*; RISC-V has user, supervisor and machine modes, and the hypervisor extension adds virtual versions *(unverified)*. 2.11BSD uses the PDP-11's supervisor mode for the network *(verified: `SUPVMODE` in `trap.c`)*; V7 used kernel and user only *(verified)*.

**The author's referents.** The PDP-11 encoding (kernel 0, supervisor 1, user 3), which the author kept (6.2.1).

**The assistant's leaning.** Option 1: keep the mode, since removing it saves no bit, and decide a use when the hypervisor question (option 3) is asked.

**Where the body refers to it.** Section 6.2.6.


<a id="j610"></a>
### J.6.10 The vector of `TRAPCC`

**Issue.** `TRAPCC.cc` (the word that enters the kernel when a condition holds) is a decided trap: it completes and `EPC` is the next instruction (6.13.8), and the body gives it the check vector, 16, which the study the author approved (errata 85, 86) names. What is not worked out is the number itself, which the author did not discuss (errata 88: "the vector number is the proposal's"), and what `EVA` holds (the study says the address of the `TRAPCC`). The options below are the alternatives to the study's choice.

**Why it matters.** The kernel's vector table needs the entry, a debugger and a signal layer need to know what the trap means, and a compiler that emits `TRAPCC` for a runtime check (an array bound, an arithmetic overflow) must name what the program sees.

**Options.**

1. *Vector 16, a vector of its own, with `EVA` the address of the `TRAPCC`.* For: the kernel tells a check from an illegal instruction at once; the vectors 0 to 31 are the processor's, and 16 is free. Against: a vector of the processor's block used up by an optional word of two members.
2. *The vector is 256 + n of a `TRAP` number named by the instruction.* For: no processor vector is spent, and the operating system names the check. Against: `TRAPCC` has no operand (one parcel), so it cannot carry n.
3. *The illegal-instruction vector (2).* For: nothing to add. Against: a check is not an error in the instruction; the kernel must decode to tell them apart.
4. *The breakpoint vector (15).* For: the same shape (a deliberate trap by a program). Against: the debugger and a check share a vector.
5. *One vector for each condition (fourteen vectors).* For: the handler learns the condition from the vector. Against: it uses fourteen of the thirty-two entries of the processor block, which leaves no room.
6. *The vector chosen by a system register* (a `TRAPCC` vector register). For: the operating system picks. Against: one more register and a hidden dependence between an instruction and the register.

**Precedents.** MIPS has `TEQ`, `TNE` and the other trap-on-condition instructions, which raise the trap exception with the condition in a code field *(unverified)*. PowerPC has `TW` and `TD` (trap word and doubleword on a condition) *(unverified)*. x86 has `INTO` (trap on overflow, its own vector 4) *(unverified)*; AArch64 has `BRK` with an immediate *(unverified)*; RISC-V has no trap-on-condition instruction *(unverified)*.

**The author's referents.** Errata 85 (item 9: `TRAPCC` with the fused `ADDV`, `SUBV` and `MULV` forms) and errata 86 (`TRAPCC` is a trap and not an abort); none recorded for the vector number or for `EVA`.

**The assistant's leaning.** Option 1 as the study had it, and as the body states it; a decision of the author fixes the number.

**Where the body refers to it.** Sections 6.3 and 6.13.8.


<a id="j611"></a>
### J.6.11 Hardware breakpoints and watchdogs, performance counters, machine-check reporting

**Issue.** Three groups of kernel-visible facilities are not specified: debug registers (hardware breakpoints and watchpoints), performance counters, and what a machine check reports beyond the halt of 6.4.3. A watchdog (a timer that resets the machine if the kernel does not touch it) is the fourth. None has a system-register number: 13 and up are reserved.

**Why it matters.** A kernel debugger without hardware breakpoints cannot stop on a data access, and a profiler without counters cannot count cache misses. A machine check that reports nothing leaves a kernel nothing to log. None is needed to boot; each would have to be present before the system is used for serious work.

**Options.**

1. *None in System v1.* For: smallest. Against: each is requested by a debugging and operations workflow later, and a software replacement is slow.
2. *A fixed small set* (two breakpoint registers, one cycle counter, one machine-check status register). For: enough to start a debugger and a profiler. Against: the set is then fixed forever.
3. *Adopt RISC-V's sets* (the debug trigger module, the hardware performance monitor counters and the `mcause` convention). For: ready-made specifications and software. Against: much larger than a first iteration needs.
4. *Leave them to the platform, not the architecture.* For: each implementation chooses. Against: a kernel then has no portable way to use them.
5. *The memory-mapped debug unit of the bus (PCI Express's own capabilities).* For: no new registers. Against: the processor's state is then not reachable in the processor's own terms.

**Precedents.** x86 has debug registers `DR0` to `DR7`, performance counters selected by `MSR`s and machine-check banks *(unverified)*; AArch64 has the debug, `PMU` and RAS extensions *(unverified)*; RISC-V has a trigger module, `hpmcounter` registers and a `mcause` *(unverified)*.

**The author's referents.** None recorded.

**Where the body refers to it.** Section A.10.1.


<a id="j612"></a>
### J.6.12 Recovering from a failed user copy

**Issue.** A kernel copy routine opens the guard, copies and closes it (6.10.3). Before the copy `PROBER` checks that the page is readable, but the copy may still fault (a file mapped into the process may be truncated under it, or a page may have to be brought in). The page-fault handler can bring a missing page in and restart the instruction (6.4), so a fault that the kernel can repair is not a problem. A fault that it cannot repair (an unmapped address) has to turn into an `EFAULT` return from the copy routine. The author accepted the fixup table with the `.U` qualifier (errata 86, item 18; the body, 6.10.4), so how the handler finds the place to return to is decided for the `.U` moves. What is pending is the rest: the form for the atomics (once the operand placement of `ATOM` is fixed), the full specification of the fixup table, and the recovery of a copy that does not use a `.U` move (for example in a member without the qualifier, or a block copy).

**Why it matters.** Every system call that takes a user pointer depends on it, and a kernel that cannot recover panics on a bad pointer from user mode, which is the attack that the guard exists to stop.

**Options.**

1. *A global `nofault` return address, as V6 and V7 had.* The routine stores a recovery address, the handler on a fault in kernel mode at a user address jumps there. For: already described in 6.4 and tested in V7; no new instruction. Against: a global (or per-thread) variable that the routine must reset on every path out; a fault in other kernel code at the same time would be taken for it.
2. *Address ranges of the copy routines.* The handler compares `EPC` with the start and end of the copy routines and jumps to one recovery address. For: no variable to set, no instruction change. Against: every copy routine must lie in the range, and any new copy loop must be added to it.
3. *A fixup table: the qualifier `.U` marks the instructions that touch user memory and the handler looks up `EPC` in a table of recovery addresses.* This is the decided form of 6.10.4. For: exact for each instruction, no variable, no range, and the move accesses user memory with user privilege so the guard is not needed. Against: a new qualifier on seven words, a table to build, and the specification is incomplete (the atomics).
4. *Check every page first with `PROBER` and `PROBEW`, never fault.* For: no recovery path. Against: a page can disappear between the check and the copy (a file truncated by another thread), so it is not safe for a mapped file.
5. *Run the copy with a fault handler stack: `setjmp`-style context saved at the system-call entry.* For: any depth of nesting returns to the system-call entry with an error. Against: the context save is memory traffic on every system call; it needs a new rule that unwinds kernel state.
6. *Exception tables in the manner of Linux, in a section of the kernel image.* For: the same as option 3 without a new qualifier: any instruction can be listed in the table. Against: the table is a section that the assembler and linker must support, and each use is a macro.

**Precedents.** V6 and V7 set a global `nofault` and the trap handler jumped to it *(verified: `trap.c` and `mch_i.s` on this machine)*. Linux keeps an exception table of (instruction, recovery) pairs for user access *(unverified)*; OpenBSD on x86 and ARM keeps a `pcb_onfault` address in the process control block, which the fault handler reads *(unverified)*. x86 reads user memory with `SMAP` open by `STAC` and `CLAC` and Linux uses the exception table *(unverified)*.

**The author's referents.** "pdp64 specifically designs the instructions for minimal uops, so we have minimal restart/recovery code needed, no?" (2026-11-09, on restart); the five leanings of the study that the author accepted (the fixup table, the `.U` spelling, keeping `UA`, `STUA` and `CLUA` until the OpenBSD port confirms them, bit 15 of `ECAUSE`, the atomics taking the user form).

**The assistant's leaning.** Option 3 is decided for the `.U` moves; option 1 for the first kernel's other copies, which is what the OpenBSD port will expect (`pcb_onfault`).

**Where the body refers to it.** Sections 6.10 and 6.10.4.
