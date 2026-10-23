# pdp64 system architecture: privilege, exceptions, interrupts, memory management and boot

[← pdp64 index](../README.md)

**Status: first draft, 2026-10-22.** This document gathers what the [ISA](pdp64-isa.md) says about the machine as an operating system sees it, in one place, and
**states plainly what is not yet defined**, so that it can be designed later. It decides nothing new. Each statement carries a label:

* **Established**: written in the ISA, the implementation plan or the LB64 document, with the section named.
* **Open**: not yet decided or not yet written. The list of all open items is in section 13.

The companion for the bus and the devices is [`pdp64-q64-bus.md`](pdp64-q64-bus.md). The question this document answers is: what does a kernel need from the
processor, and which of it exists? The first kernel is a port of OpenBSD, with Unix/32V as the fallback (section 12).

## 1. Privilege modes

*Established* (ISA §2.1, §2.2): three modes, **kernel**, **supervisor** and **user**. The stack pointer `R14` and the direct-page register `DP` each have three
copies, one per mode, switched with the mode. The reason for the banked stack pointer: a trap arriving in user mode has a kernel stack to land on. In kernel mode `DP` is
the per-CPU pointer (§17.4); in user mode it is the thread pointer, which makes local-exec thread-local storage one four-byte instruction (§19.3).

*Established* (ISA §4.11): `PROBER` and `PROBEW` test an address against the **previous** mode. A privileged instruction executed in user mode is an abort (§7.1).

*Open*:
* what the supervisor mode is for. It is carried from the PDP-11, whose Unix did not use it. Whether pdp64 keeps it, and for what (a hypervisor guest kernel? a
  driver mode?), is not decided. Without a use it is cost: a third bank of `SP` and `DP`, a third set of page permissions.
* which instructions are privileged, as a table. They are implied (the `SYS` group, `TLBI` and the rest) but not listed per mode.
* how a mode change is made other than by exception and `RTI`.

## 2. The processor status word

*Established* (ISA §2.2): a 16-bit `PSW` holding the condition flags `N Z V C`, the **current mode**, the **previous mode**, the interrupt **priority** and the
trace bit `T`. `MTPS` writes all of it, `MFPS` reads it, `SPL #n` sets the priority field alone and leaves the flags alone (ISA §4.11.1). `FPSR`, the five-bit
sticky floating-point flag word, is saved with the `PSW` as part of the thread context (§2.2).

*Open*:
* **the bit layout** and the width of each field: the fields listed need about 12 of the 16 bits, but their positions, the number of priority levels and the
  reserved bits are not assigned;
* what `MTPS` does in user mode (the PDP-11 let user code write only the flags);
* the effect of writing the mode fields directly.

## 3. System registers and the instructions that reach them

*Established* (ISA §2.2, §4.11):

| Register | Width | Read / written by |
|---|---|---|
| `PSW` | 16 | `MFPS` / `MTPS`, `SPL` |
| `FPSR` | 5 | `FSFLAGS` (swap) |
| `DP` (three copies) | 64 | `MFDP` / `MTDP` |
| `ASID` | 16 | `MFASID` / `MTASID` |
| `DMW0`, `DMW1` | 64 | `MTDMW`; `MFSR` / `MTSR` `dmw0`, `dmw1` |
| `PTBR` | 64 | `MFSR` / `MTSR` `ptbr` |
| `EPC` | 64 | `MFSR` / `MTSR` `epc` |
| `EVA`, `ECAUSE` | 64 / 16 | `MFSR` `eva`, `ecause` (read only) |
| user and supervisor `SP` | 64 | `MFSR` / `MTSR` `usp`, `ssp` |

*Decided* (errata 32, added 2026-10-22): the instructions **`mfsr rd,name`** and **`mtsr name,rs`**, privileged, four bytes, in the `SYS` group. They close the gap that a kernel could not install a page table
(`ptbr`) or read why it was entered (`epc`, `eva`, `ecause`), and give access to the stack pointers of the other modes (`usp`, `ssp`), which a kernel needs for signal frames, `fork` and the context switch.
A system-register number has eight bits, so further registers (a vector base, a timer compare, an interrupt mask) can be added without changing the instruction.

*Open*:
* what `epc`, `eva` and `ecause` contain and when they are set (the entry sequence of section 4);
* whether the numbered registers `dp` (kernel) and the others should also be reachable by name through `mfsr`/`mtsr` (today `MFDP`/`MTDP` do it), and which `DMW` an operand of `MTDMW` selects;
* where identification beyond the core number (features, ISA version) is reported, as `MFCPUID` reports only the core number.

## 4. Exceptions

*Established* (ISA §7.1, §7.2, §7.3): four categories.

| Category | Instruction | `PC` on entry | Restartable |
|---|---|---|---|
| Trap | completes | next instruction | n/a |
| Abort | annulled, no architectural effect | the faulting instruction | yes, by `RTI` |
| Progress | partially complete, progress in registers | the faulting instruction | yes, by `RTI` (§7.5) |
| Machine check | indeterminate | best effort in `EPC` | no |

The aborts: page not present, protection violation, non-canonical address, misalignment, reserved instruction, privileged instruction in user mode, divide by zero,
landing-pad violation. The faults are **precise**: the register update of `(Rn)+` and `-(Rn)` is buffered and committed at retirement, so an abort leaves no partial
effect, and there is no undo journal for software to run (§7.2). The number of faults any ordinary instruction can take is bounded: at most two on the instruction fetch, at most two on the
operand read, none on the write because write permission is checked during the read (§7.3). The block operations (`MBLK`) are restartable by progress held in
registers (§7.5). A read timeout on the bus is a precise abort with `ECAUSE = BUSFAULT`; a timed-out posted write is a machine check (§7.1). Floating-point exceptions
never trap: they set flags in `FPSR` (§4.10.1).

*Established*: the registers `EPC` (exception `PC`), `EVA` (faulting address) and `ECAUSE` (16 bits). `ECAUSE` values named in the ISA so far: `NONCANON`, `ALIGN`, `BUSFAULT`.

*Open*, and this is the largest gap in this document:
* **the entry sequence**: where the old `PC` and `PSW` are saved (the registers `EPC` and a saved `PSW`, or the kernel stack as on the PDP-11), what the new `PSW` is, which mode
  and which stack the handler runs on, and whether interrupts are disabled on entry;
* **the vector table**: where it is (a base register? a fixed address in the direct-mapping window?), what an entry holds, and the **assignment of vector numbers** to
  aborts, interrupts and machine checks. `TRAP #n` and `TRAPL #n` reach 256 vectors, but which of the 256 are reserved for the processor and which are free for system calls
  is not stated;
* **the numeric `ECAUSE` codes**, and the full list of causes (page-not-present against protection violation, instruction fetch against data, read against write: is that
  in `ECAUSE` or elsewhere?);
* **nested exceptions**: what happens on a fault in the handler before `EPC` is saved;
* the exact semantics of `RTI` and `RTT` (what they restore, in what order, whether `RTI` can change the mode), beyond "`RTT` sets the `T` bit after the return rather than before" (ISA §4.11.1).

## 5. System calls

*Established*: `TRAP #n` (two bytes, `n < 16`) and `TRAPL #n` (four bytes, `n` up to 255) enter the kernel through vector `n`. `BPT` is the two-byte breakpoint. The user-level
calling convention is [`abi.md`](abi.md).

*Open*: the system-call convention (which vector, which registers carry the number and the arguments, how errors are returned). Note that the `trap #0`, `#1`, `#2`
(exit, write, read) of the emulator [`sim64`](sim64.md) and of the QEMU target is a stand-in for testing, not an operating-system interface.

## 6. Interrupts

*Established*: the `PSW` has an interrupt priority field and `SPL #n` sets it (§4.11.1). `WFE` sleeps until an interrupt or another core's `SEV`; `WAIT` is its alias on one core
(§4.11.1, §17.2). A device raises an interrupt when a DMA transfer is done ([`pdp64-q64-bus.md`](pdp64-q64-bus.md) §6).

*Open*: all of the rest.
* the number of priority levels and how the `PSW` priority compares with a device's;
* **the interrupt controller**: how a device's interrupt becomes a vector, how it is acknowledged, masked and prioritised;
* **the timer**: whether there is a processor-local timer (a tick for the scheduler is not optional for a Unix), how it is read and programmed, its width and
  frequency; and a free-running counter for timekeeping;
* inter-processor interrupts: ISA §17.4 suggests "a memory-mapped per-core register is sufficient and needs no APIC-like complexity"; nothing is defined;
* interrupts and the exception categories: whether an interrupt is a fifth category or a trap taken between instructions.

## 7. Memory management

*Established* (ISA §8): a three-level page table of 4 KB pages (9 + 9 + 9 + 12 bits) gives a 39-bit virtual address; the physical address is 40 bits (Q64). **Decided (errata 60, P19):** bit 39 of the physical address is the space bit: set is device space (memory-mapped registers), clear is memory (DRAM), as on the VAX. The page-table entry's memory type must agree with it (a cached mapping of device space, or a device-typed mapping of memory, is a fault), and the bus controller refuses a device's DMA into device space. The QEMU memory map has moved into the upper half (timer at `0x8000000000`, console at `0x8000001000`; `spec/pdp64-system.hbnf`). **Implemented as a proposal (errata 65, not yet confirmed by the author):** the walker makes a leaf whose physical page has bit 39 set and whose memory type is cached or uncached, or whose bit 39 is clear and whose type is device or device-weak, a protection fault of the access type (`IPROT`, `LPROT`, `SPROT`); with translation off a physical address with bit 39 set reaches the devices. A virtual address cannot name device space directly (bit 39 of a canonical virtual address equals bit 38), so a kernel maps devices through a device-typed leaf. Large pages at level 1
(2 MB) and level 2 (1 GB). A **hardware table walker** and a TLB (the plan assumes 4-way, 64 entries). A virtual address that is not the sign-extension of bit 38 aborts with
`ECAUSE = NONCANON` (§6.1.1). The page table entry holds: valid `V`; permissions `R`, `W`, `X`; user `U`; global `G` (ignores the ASID); accessed `A` and dirty `D`; and a 2-bit memory
type `MT` (`00` cached, `01` uncached, `10` device strongly ordered, `11` device weakly ordered). A 16-bit `ASID` makes a context switch constant-time (one store, no flush); the `G` bit
keeps kernel text mapped across address-space switches. Two **direct mapping windows** `DMW0` and `DMW1` map `PA = VA - VirtualBase + PhysicalBase` with no table reference,
kernel only, with a memory type each; the machine comes up with `DMW0` covering physical memory (§8.3). `TLBI` and `TLBIA` **broadcast** to all cores and `TLBSYNC` waits for completion
(§17.2). `PROBER` and `PROBEW` validate a user address without faulting.

This is enough for demand paging, copy-on-write, `fork`, `mmap` and `mprotect`, and it is the same shape as RISC-V's Sv39 (three levels, 39-bit virtual address; PTE flags and PPN position checked against the QEMU source, `target/riscv/cpu_bits.h`). That Linux offers a 39-bit, three-level configuration on AArch64 is from memory and was not checked ([fact-check](fact-check-2026-10-22.md)).

*Open*:
* **the page table entry bit layout**: the fields are listed, their positions in the 64-bit entry are not;
* whether there is one table base for both halves of the address space or one for user and one for kernel;
* the hardware walker's behaviour: whether it sets `A` and `D` itself (and what a failure to do so atomically means) or faults to software;
* the `TLBI` operand forms (by address, by ASID, both) and what `TLBIA` covers;
* **ASID allocation and rollover**: 16 bits are plentiful, but the policy when they run out (a global flush, a generation count) is the kernel's and needs the instruction
  semantics to be exact;
* the cache and TLB behaviour at reset, and cache control beyond `ICINV`/`ICINVA` (the data cache is stated to be transparently coherent between CPUs, ISA §17.3);
* whether supervisor mode has its own permission bits (section 1).

## 8. Context switch

*Established*: a thread's context is the sixteen registers (the stack pointer of the mode), the `PC`, the `PSW` and `FPSR`; there is no separate floating-point register file because floating
point lives in the general registers (ISA §2.3). The address space is selected with `MTASID` (and `PTBR`), one store and no flush (§8.1). The kernel's `DP` is the per-CPU pointer
(§17.4), the user's `DP` the thread pointer (§19.3).

*Open*: nothing in the processor, but the **kernel's context-switch code has not been written**, and its exact sequence depends on the entry and `RTI` semantics of section 4.

## 9. Reset and boot

**A review of how the main systems boot, whether UEFI is worth having, and a proposal (block 0 loaded by the controller's ROM, a register write to start each other core, a boot-information block, a reset bit plus an optional firmware window for each device) is in [`boot.md`](boot.md); the items below stay open until its decisions B1 to B5 are made.**

**The BIOS, and what takes its place.** A BIOS is firmware doing four jobs: hardware bring-up and self-test, the first code (a boot sector), a runtime library of device services called by software interrupt, and configuration. UEFI replaces the second and third with a loader file and a set of boot and runtime services; other architectures have the same roles under other names (Open Firmware, U-Boot with trusted firmware, OpenSBI, the Alpha SRM console, the VAX console processor, the PDP-11 boot ROMs and `ODT`). The pdp64 needs only the first, second and fourth, in a minimal form: **its "BIOS" is the controller chip's boot ROM and monitor, with no resident services and nothing called after boot**; the third job disappears because the devices have one uniform register layout that the loader and the kernel share (decisions R5, B1 and P7). The reasoning, and the comparison with UEFI, is in [`boot.md`](boot.md).

*Established* (ISA §8.3): the machine comes up with `DMW0` covering physical memory, so there is no chicken-and-egg problem in setting up the first page tables. Resetting the bus is a bus-controller
register write, not an instruction (§4.11.1).

*Open*: the **reset state** (mode, `PSW`, priorities, which registers are defined), the **reset vector** and where the first instruction is fetched from, the firmware or boot ROM and what
it hands to the kernel (a device description? the memory size?), and the **boot protocol for releasing secondary cores** (ISA §17.4 lists it as still to be built).

## 10. Multiprocessing

*Established* (ISA §17): the memory model is **sequentially consistent**; the additions are `MFCPUID`, `ICINV`/`ICINVA`, `TLBSYNC`, `WFE`, `SEV` and broadcasting `TLBI`; coherence between CPUs is
transparent (snooping MSI for two to four cores), and between a CPU and a DMA device it is explicit (uncached mapping plus `FENCE`). The atomics are `CAS`, `SWAP`, the fetch-and-operate family and
`LL`/`SC`, each with a barrier-fused `_DB` form (§4.11).

**An important caveat.** A simple memory model does not make an atomic implementation simple by itself. Cache coherence, exclusive ownership, invalidation, ordering, and interaction with interrupts still have to be designed and tested.
Declaring the model sequentially consistent (ISA §17.1) tells software what it may rely on; it does not build the machinery that makes `CAS`, `LL`/`SC`, the `_DB` forms and `FENCE` mean that on real hardware, and it is the machinery, not the declaration, that is hard to get right.

*Open*: the lock-against-monitor question for the atomics on the bus (**blocking** for any second core; [`pdp64-q64-bus.md`](pdp64-q64-bus.md) §8), the inter-processor interrupt, the secondary-core boot
protocol (section 9), and the shared cache or coherent interconnect, which the ISA calls device-side and still to be built.

## 11. Debugging and machine checks

*Established*: the `T` bit single-steps; `BPT` is the shortest instruction so it can overwrite any other; `RTT` lets a debugger step out of its own trap handler (ISA §4.11.1). Machine checks are the
descendants of the PDP-11's bus error and are not restartable (§7.1); the old `nofault` idiom remains the pattern for probing hardware.

*Open*: hardware breakpoints and watchpoints; how a machine check is reported and logged; a performance counter.

## 12. The operating system plan: OpenBSD first, Unix/32V as the fallback

*Decided by the author* (errata 41, 2026-10-22; it supersedes errata 30 and 30a): the first operating system is **OpenBSD**, ported through the LLVM back end (section 14); if OpenBSD proves too hard, the fallback is a port of **Unix/32V** (the original port of V7 Unix to the VAX-11/780) built with the existing pcc compiler. The author
expects OpenBSD to be doable. **3BSD is dropped**: it was the plan of errata 30a, chosen because 32V only swaps whole processes and 3BSD added demand paging, and it is no longer needed as a stepping stone, which also removes the unresolved question of the licence of the 3BSD sources. The rest of this section is
what a 32V port needs, which stays true for the fallback, and the history of the earlier plan is kept in errata 30 and 30a.

**What the earlier plan said about 3BSD, kept for the record** (**Checked**, [fact-check](fact-check-2026-10-22.md)): 3BSD was released at the end of 1979 for the VAX, built from UNIX/32V with Ozalp Babaoglu's virtual-memory implementation (Bill Joy also worked on it); 32V "did not take advantage of the VAX's virtual memory capabilities" (Wikipedia, *Berkeley Software Distribution* and *UNIX/32V*). **Not checked, from general knowledge:** the compiler that built 3BSD, the VAX having a hardware modify bit but no reference bit with 3BSD emulating
reference bits in software (the Babaoglu and Joy paper is, from memory, "Converting a swap-based system to do paging in an architecture lacking page-referenced bits", SOSP 1981, not looked up), which is the arrangement System v1 chose on purpose (software-managed accessed and dirty bits, section 15).

**A note on paging, from the 32V headers in the toolchain repository's corpus.** The 32V kernel as released **swaps whole processes** and uses the VAX page tables for relocation and protection:
`proc.h` has `p_size` ("size of swappable image"), `p_swaddr` and `p_swsize` and the states `SLOAD`, `SSWAP` and `SSPART` ("partially swapped out"); its page-table entries are those of the u-area
(`p_addr[UPAGES]`); and the headers contain no paging structures. 3BSD added the paging to it. The pdp64's memory-management unit supports demand paging (section 7); with 3BSD as the starting point the port needs the paging support from the first day: page-fault handling, the `A` and `D` bits in software, and a page daemon.

| What the port needs (32V, and so 3BSD) | What the pdp64 has | State |
|---|---|---|
| A way into the kernel for a system call, with the call number and arguments in registers or on the stack | `TRAP #n`, `TRAPL #n`, a banked kernel stack (sections 1, 5) | the entry sequence and the call convention are open (sections 4, 5) |
| Separate address spaces, swapped as whole images, with per-process page tables | a three-level page table, `ASID`, broadcast `TLBI` (section 7) | `PTBR` is written by `mtsr` (section 3); the entry layout is open (section 7) |
| Mode, interrupt priority levels | the `PSW` priority field and `SPL` (section 6) | the number of levels, and the `PSW` layout, are open (sections 2, 6) |
| A periodic clock interrupt | nothing | open (section 6) |
| A console | nothing | a serial device is needed and is not one of the three devices of errata 29 (Ethernet, USB, disk); open |
| A disk with a driver | an eight-register DMA disk is the plan (errata 29) | the layout is open ([bus document](pdp64-q64-bus.md) §9) |
| Two privilege levels, kernel and user | kernel and user (section 1) | 32V, like V7, does not use a third mode, which suggests that the open question about supervisor mode (section 1) can wait |
| Saved floating-point state | none beyond `FPSR`, since floating point lives in the general registers (section 8) | nothing to do |
| Signals and `fork`/`exec` | `fork` needs an address-space copy, `exec` a loader, signals a return path from the handler | kernel work; follows from sections 4 and 5 |

What is not in the architecture's documents at all:

* **The 32V kernel sources.** The toolchain repository ([v7unix-toolchain](https://github.com/moebiusV/v7unix-toolchain)) has V7's libraries and commands (`orig/usr/src/cmd`, `libc`), the C-ported commands of `modern/`
  and the 32V headers (in the corpus directory), but not the kernel. In January 2002 Caldera International relicensed several early versions under the four-clause BSD licence "up to and including Version 7 Unix (UNIX/32V)" (Wikipedia, *Ancient UNIX*); the Unix Heritage Society archive (tuhs.org) holds them. **That 2002 licence is for the AT&T-derived early systems up to 32V; this page does not show that it covers 3BSD**, which contains Berkeley additions to the 32V kernel, and the licence terms of the 3BSD sources are not established (the licence text, `Caldera-license.pdf` on tuhs.org, could not be read through the browser tool). Fetching the sources and settling the licence is a step still to be done.
* **The word-size work.** 32V already has 32-bit `int`s, `long`s and pointers, so it avoids the 16-bit assumptions of V7. The pdp64 is LP64 (`long` and pointers are 64 bits), so the port still has the work of widening
  `long` and pointer arithmetic, and the VAX-specific memory-management and trap code has to be rewritten for the pdp64's tables and entry sequence. The commands in `modern/` show the userland half of this already done for the toolchain's compiler.
* **The binary format.** 32V expects `a.out`; the pdp64 toolchain writes ELF (`ld64`, e_machine `0xF064`). The kernel's `exec` has to read ELF, or the linker has to write an `a.out`; not decided.
* **Everything the QEMU target lacks.** It runs user programs only; to boot a kernel it needs the memory-management unit, the privileged state, the interrupts, the timer and a serial device, which are the open
  items above made concrete. That is the practical order of work: define section 4 and section 6, then implement them in the QEMU target, then write the kernel against it.

A Linux or modern BSD port (OpenBSD is the author's next candidate) is a different question, since they need a GCC or LLVM back end; the plan does not depend on it. See the answer on LLVM in section 14.

## 13. The list of open items

1. The supervisor mode: its use, or its removal (section 1).
2. The `PSW` bit layout; `MTPS` in user mode (section 2).
3. ~~Instructions or a general move for `PTBR`, `EPC`, `EVA`, `ECAUSE`~~ closed by `mfsr`/`mtsr` (errata 32); what the registers contain is open (section 4). Remaining: further registers (vector base, timer compare, interrupt mask).
4. The exception entry sequence, the vector table and vector numbering, the numeric `ECAUSE` codes, nested exceptions, `RTI`/`RTT` semantics (section 4).
5. The system-call convention (section 5).
6. The interrupt controller, priority levels, the timer, the inter-processor interrupt (section 6).
7. The page table entry layout, the walker's `A`/`D` behaviour, `TLBI` forms, ASID rollover policy, cache control (section 7).
8. The reset state and vector, firmware and boot hand-off, secondary-core boot (section 9).
9. Atomics against the bus (section 10; bus document §8).
10. Hardware breakpoints, machine-check reporting, performance counters (section 11).
11. The device register layouts, the DMA descriptor format and the interrupt convention ([bus document](pdp64-q64-bus.md) §9).
12. The 32V kernel sources; the a.out-versus-ELF decision; the LP64 widening (section 12).
13. An LLVM back end and its generated machine-code layer; then an OpenBSD port, conditional on the back end (section 14).

When these are decided they should be written once, as the instruction numbers are, in a grammar from which the register definitions, the cause codes, the vector numbers and the emulator's models
are generated.

## 14. The LLVM back end, and OpenBSD

*Decided by the author, conditionally* (errata 30): if an LLVM back end proves easy enough, the next operating system is an OpenBSD port. This section is the assessment of that condition. The estimates below are
the least certain statements in this document; milestone 1 (section 14.2) has turned part of the picture into measurements.

### 14.1 What an LLVM back end is, and what makes it easy or hard

**What an LLVM back end is.** A target description in LLVM's TableGen language (registers, instruction encodings and assembly syntax), the code that turns LLVM's intermediate form into those instructions (calling
convention, instruction selection, frame layout, branches and compares), the machine-code layer (assembler, object writer, relocations, instruction-size relaxation) and, for a self-hosted system, support in
the LLVM linker, `lld`, and the compiler runtime library.

**What helps.** The instruction encodings, assembly syntax and register names already exist as grammars and are the single source of truth, so the register and instruction definitions of the machine-code layer
(the largest mechanical part of a back end) can be generated from them, which keeps the compiler from drifting from the assembler as the rest of the toolchain cannot. Floating point in the general registers is a
shape LLVM already supports for RISC-V. The register file is small and regular, the ABI is accepted (`abi.md`), and there is a compiler to compare against: the existing pcc back end, a C test suite of 82 programs, a
benchmark corpus of 841 files with gcc and clang `-Os` figures, an emulator and a QEMU target to run the output. The nearest in-tree LLVM back ends are small ones (MSP430 and AVR are official targets; M68k is still an *experimental* target in LLVM 21.1.8, listed in `LLVM_ALL_EXPERIMENTAL_TARGETS` in `llvm/CMakeLists.txt`). LLVM already supports floating point in the integer registers for RISC-V (the Zfinx and Zdinx extensions, `RISCVFeatures.td`), and selects RISC-V compressed forms with a table-driven `CompressPat` mechanism (`CompressInstEmitter`, once named `RISCVCompressInstEmitter`), both checked in the source of 21.1.8.

**What makes it harder than a RISC-V-style back end.** The condition flags `N Z V C` set by ordinary instructions (LLVM models flags, as for x86 and ARM, but it is more work than a flag-free machine); the memory
operand on most instructions and the addressing modes (richer selection patterns); variable-length instructions, 2 to 6 bytes (with a one-parcel second page, ISA §4.18), whose branch and call forms must be relaxed to the shortest that reaches; and the
instructions with no counterpart in LLVM's generic operations (block copy, bit-field, UTF-8), which would be left to intrinsics at first.

### 14.2 Status: milestone M1, the machine-code layer (2026-10-22)

The first milestone is done: an assembler, a disassembler and an ELF object writer for the pdp64 in LLVM 21.1.8, checked byte for byte against our own assembler `as64`. There is no code generator yet (`llc`, `clang` and `lld` are later milestones). Everything we wrote lives in the pdp64
repository under `llvm/`, in the arrangement of `qemu/`: `llvm/target/PDP64/` becomes `llvm/lib/Target/PDP64/` in a checkout of LLVM that is kept outside the repository (`../llvm-project`), `llvm/install.sh` copies it in and applies the small `llvm/patch/llvm-core.patch` (the `pdp64` triple, `EM_PDP64 = 0xF064` and
its five relocation types, the experimental-target list), `llvm/build.sh` builds, `llvm/check.sh` runs the oracle. The register and instruction definitions are **generated** from the grammar by `tools/gen-llvm-td.py` (about 1,700 records), so the target cannot drift from the assembler.

**Results, against the ISA as of the morning of 2026-10-22** (before the flag cleanup, `ISYNC` and `HINT` of errata 39):

- `oracle.py`: 52 of 56 programs of tests/asm and tests/sim identical to as64 (bytes, relocations, symbols, disassembly round trip); 4 skipped
  (the literal pool in tests/asm/pool.s and tests/sim/pool.s; `digitnames.s` names that start with a digit; `utf8.s` non-ASCII names).
- `forms.py`: 6297 instructions/programs compared, 6297 agree (463 are refused by both: out-of-range fields).
- `negative.py`: 26 of 27 programs that as64 refuses are refused; 6 pool programs skipped; `odd.s` (an instruction at an odd address) was
  accepted by llvm-mc (fixed in the re-check, section 14.8).
- `runsim.py`: 32 of 33 tests/sim programs assembled by llvm-mc, linked by ld64 and run under sim64 give the expected status/output (pool.s skipped).

**Cost on this machine** (3 GB, 2 cores, `ninja -j1`, `nice`, assertions on): `llvm-tblgen` 5.5 minutes and 383 MB; the MC libraries, the PDP64 target and `llvm-mc` 7 minutes and 437 MB; never out of memory. `llvm-objdump` and `llvm-readobj` need 389 more compile steps and were not built (the patch for them is in place and untested). The
milestone took about 75 minutes of agent time.

**It must be re-checked whenever the ISA changes.** The ISA changed while the milestone was being built (`pushx`/`popx`, `SYSX`, new page-2 rows, the register-register `cbCC`), and the generator absorbed each change with a small edit; that is the point of generating the target. The results above predate errata 39 and the later changes; the re-check against the current ISA is
recorded in section 14.8.

### 14.3 How each feature of the machine maps to LLVM

| pdp64 | LLVM mechanism | note |
|---|---|---|
| 1, 2 or 3 parcels; parcel 0 = `len:2 opc:6 reg:4 low:4` | three `Inst16/32/48` base classes (`field bits<N> Inst`), parcel 0 in bits 15-0, parcel 1 in 31-16, parcel 2 in 47-32; the disassembler has three decoder tables | like RISC-V's 16/32/48; the bits inside a parcel keep the grammar's numbering (the grammar reads MSB first) |
| each mnemonic x form x length | one record each: `ADD_R`, `ADD_B1`, `ADD_B2`, `ADD_X1` ... (`R` register, `B` base, `X` index, `D` dp, `PC`, `I` immediate, `A` absolute, `PI` post-increment, `PD` pre-decrement; `1`/`2` the extension parcels) | about 1700 records; the multiclasses in `PDP64InstrInfo.td`, the list from `spec/pdp64-mnemonics.hbnf` |
| the eight addressing modes | one composite `Operand` per mode and length (`MIOperandInfo`), packed by `getMemOpValue<Form,Len>` / unpacked by `decodeMemOp<Form,Len>`; the parser builds one `PDP64Operand` per mode, the matcher tests its kind | the displacement is split high part first (`rm:4 d:12`, then 16 more bits): the field is `V = rm<<D | d`, `Inst{31-16} = V{31-16}`, `Inst{47-32} = V{15-0}` |
| the shortest encoding | the parser starts from the narrowest record whose operand class matches (the longer records have an operand class that never matches); a constant that does not fit moves to the next record (`PDP64AsmParser::fixupWidth`); a symbol is relaxed (`PDP64AsmBackend::relaxInstruction`, grow-only like as64) | the chain is `PDP64_WIDEN` in `gen/PDP64Tables.inc` |
| page 2 (`len = 11`): the one-parcel abbreviations of ISA §4.18 | not records.  The code emitter offers every four-byte instruction without a fixup to `PDP64::p2Compress`; the disassembler expands a page-2 word to its page-1 word first (`p2Expand`) and decodes that | the table is `common/p2.c`'s, parsed by the generator, so the three of them cannot differ.  RISC-V's `CompressPat` was not used: the abbreviations are a table of 41 rows over arbitrary field positions (a displacement `8*(16+low)`, a constant register `sp`), which `CompressInstEmitter` cannot say, and a table is already the single source |
| three branch forms | `Bcc_0`, `Bcc_1`, `Bcc_2` (8, 16, 32-bit displacement in parcels); relaxation 0 -> 1 -> 2 | an unresolved target (another section, undefined) is relaxed straight to 32 bits, as as64 does |
| `cbCC` in three flavours (0x28, 0x29, 0x2A) | `CBxx` (imm5, d11), `CBxx_W` (imm16, d16), `CBxx_L` (imm5, d27), `CBxx_RR1/2` (two registers) | the chain `CB -> CB_W -> CB_L` reproduces "when both six-byte forms fit, the wide one"; the step `W -> L` is allowed only for an immediate that fits 5 bits (`PDP64_WIDEN`'s third field) |
| `d(pc)` operands and branch displacements measured from the first parcel | every fixup is at offset 0 of the instruction, so `r_offset` is the address of the first parcel and LLVM's `S + A - P` is the pdp64's | the fixup kinds (one per field and length) are in `gen/PDP64Fixups.def`; `applyFixup` writes the high part into parcel 1 and the rest into the following parcels |
| relocation types `D64 D32 INSN_ABS INSN_PC INSN_BR` | `PDP64ELFObjectWriter::getRelocType` (RELA, ELF64, little endian, `e_machine 0xF064`) | |
| a pc-relative reference to a symbol of the same section is resolved by the assembler, even a global one | `PDP64AsmBackend::evaluateFixup` (LLVM would otherwise keep a relocation for a global symbol: it may be preempted) | static link only |
| the `set cc, rd` and `cbCC` conditions, `mfsr`/`mtsr` system register names | the parser reads them as words in that operand position (not as symbols); the names are `gen/PDP64Tables.inc` | |
| `sp = r14`, `fp = r13`, `pc` and `dp` only as a base | `RegisterInfo` has `R0`..`R15`; `sp`/`fp` are aliases in the parser and in `printReg`; `pc` and `dp` select the mode | |
| `.word` (16 bits), `.even`, `.lpad` | `parseDirective` (LLVM's generic assembler has no `.word`/`.even`); `.align n` is in bytes (`AlignmentIsInBytes`) | |
| padding in `.text` | `writeNopData`: the `nop` parcel `0x1400` (an odd byte first) | |
| literal pool `=K`, `.pool` | **not supported** | LLVM's MC has no literal pool.  The code generator will use the constant pool of the AsmPrinter and emit `movq` with an explicit pc-relative operand; the assembler sugar stays as64's |

### 14.4 Where the numbers come from, and what is still typed twice

`tools/gen-llvm-td.py` reads `spec/pdp64-mnemonics.hbnf` (through `tools/mkgrammar.py`'s `enums()`), the field widths from
`as64 --limits` (measured from the grammar's own encoder), and the rows of `common/p2.c`.  `--check` fails if the generated files
differ (`install.sh` and `check.sh` run it).  What is *not* generated, and is typed twice: the **position** of the fields inside a
parcel (`PDP64InstrFormats.td`, `PDP64InstrInfo.td`: where `reg`, `low`, `sub`, `t`, `x` sit), the operand-count classification of the
escape groups (which BESC/FESC words take two, three or four registers: `gen-llvm-td.py` and `as64.c` both have the lists), and
the TSFlags layout (`PDP64InstrFormats.td` and `PDP64BaseInfo.h`).  The first is guarded by `static_assert`s on the widths and by
the oracle; the second would be better as an annotation in the mnemonic grammar (open).

### 14.5 How it is tested

- `oracle.py`: every `tests/asm/*.s` and `tests/sim/*.s` with both assemblers; the bytes of `.text` and `.data`, `.bss`, the
  relocations (section, offset, type, symbol, addend) and the symbols must be equal; then the disassembly of `.text` must reassemble to
  the same bytes.  The only translation of the source is lexical (`translate()`): a string in `.byte` becomes `.ascii`, a decimal with a
  leading zero loses its zeros, `0o17` becomes `017`.  Skipped, with the reason: the literal pool and names that start with a digit.
- `forms.py`: every mnemonic in every form at the edges of every field (largest and smallest displacement of each length, an
  immediate that just fits and one that does not, symbols before, after, in another section and undefined, branches over distances
  that straddle each length); both refusing is agreement.
- `negative.py`: `tests/asm-err/*.s` must be refused by llvm-mc as well.

### 14.6 Awkward spots, as design feedback for the ISA

1. **The destination register is also a source** (`add src, rd`): in LLVM that is a tied operand.  The M1 records have no outputs; the
   selection milestone will have to redo the register operands (outs and ins, `$rd = $rd_in`).
2. **No linker relaxation.**  The assembler picks every length, and a symbol in another section or undefined always gets the widest
   field (32 bits).  That costs two bytes per external call and every global access, and LLVM's own mechanism for it (RISC-V style
   `R_RISCV_RELAX` plus a linker that shrinks) is not available until ld64 relaxes (CHANGES section 12: open).
3. **Constants wider than the immediate field** need `movq =K`, which MC cannot say.  The compiler must lower them to a constant
   pool entry and a pc-relative `movq`; there is no `movabs`.
4. **The operand `rd` of `cmp` is first** (`cmp rd, src` computes `rd - src`): a plain exception in the operand order; harmless
   in TableGen, easy to get wrong in a pattern.
5. **ATOM and MESC** are in the ISA but not in as64 (no encoder, no oracle), so they are not in the LLVM target either.
6. **`.comm`** has no alignment operand in as64 (8 is implied); LLVM wants one.
7. `EM_PDP64 = 0xF064` is a private-use number.
8. **An instruction at an odd address** is an error in as64. Fixed in the re-check (14.8): every instruction gets a fragment of its own (`allowEnhancedRelaxation`) and `finishLayout` refuses an odd offset.
9. Names: LLVM's lexer has no non-ASCII identifiers and no names that start with a digit; quoted names are not tested.

### 14.7 What the next milestones need decided

* Tied operands for the two-address forms (item 1 above). * A condition-code model: `cmp` and the arithmetic instructions set `N Z V C`, `set cc` reads them, and after errata 39 `cbCC` and moves, loads and stores write none (the flag-group invariant helps: two groups, `C` and `{N, Z, V}`).
* The lowering of 64-bit constants and of the addresses of globals: a constant-pool entry plus a PC-relative `movq`, and which of `lea sym(pc)` and `movq #sym` is the canonical address load (both exist). * A frame description: a call pushes the return address and there is no link register, so the DWARF return-address column and the call-frame rules are undecided
(a placeholder register is used now). * A selection policy for the compare-and-branch forms and their range limits. * Whether `long double` is binary128 before clang (the ABI says `long double` is `double`). * A `TargetMachine`, the calling convention (from `abi.md`), and the clang triple and data-layout string. * The encodings of the atomics in `as64`.

### 14.8 The re-check against the current ISA

**2026-10-22, after errata 39 and 40** (ISA commits up to `06e4a05`; the LLVM generator change for `isync`/`hint` is `52ef51f`). Regenerated with `tools/gen-llvm-td.py`, `llvm-mc` rebuilt (about 15 seconds: only the PDP64 libraries changed), `llvm/check.sh` run in full:

- `oracle.py`: 62 of 68 programs identical to as64 (was 52 of 56; the new tests `hint`, `isync`, `flagfree`, `shiftflags`, the `sys-*` ones and others), 0 failed, 6 skipped (the literal pool in four sources, `digitnames.s`, `utf8.s`).
- `forms.py`: 6304 compared, 6304 agree (465 refused by both) (was 6297 of 6297).
- `negative.py`: 30 of 30 refused, 6 pool programs skipped (was 26 of 27).
- `runsim.py`: 40 ok, 0 failed, 3 skipped (the pool programs) (was 32 of 33).

What changed and what broke:
- `isync` (SYSX sub 2) and `hint #n` (SYSX sub 3, `n` in the pad byte): new records, two page-2 rows (0x2C, 0x2D). `hint` is the first SYSX word with an operand and its page-2 word carries `n` in `reg:low`, so the generator reads `XN(...)` rows of `p2.c` and `PDP64P2.cpp` keys the SYSX words by the pad byte. The flag cleanup of errata 39 and the entry priority of errata 40 do not touch the machine-code layer, as expected.
- The disassembly round trip of `tests/sim/hint.s` and `isync.s` failed at first: those tests write the four-byte form of `hint #n` with `.word` on purpose, and the reassembly (correctly) chooses the page-2 word. The oracle now accepts a round trip whose reassembled bytes disassemble to the same listing.
- The odd-address limit is gone: `allowEnhancedRelaxation()` makes every instruction a fragment of its own, and `PDP64AsmBackend::finishLayout` refuses a fragment at an odd offset ("an instruction at an odd address: put .even before it"), as as64 does.
- Nothing else needed a change; the FP16 rows and the register-form `cbCC` were already covered by the generator and by `forms.py`.

### 14.9 Building it on a bigger machine

    git clone --depth 1 --branch llvmorg-21.1.8 https://github.com/llvm/llvm-project.git ../llvm-project
    LLVM_USE_LINKER=lld TARGETS="llvm-tblgen llvm-mc llvm-objdump llvm-readobj llvm-objcopy" llvm/build.sh -j 16
    llvm/check.sh

(`build.sh` runs `install.sh`, which applies the patch and copies the target, then `cmake` and `ninja`; set `LLVM_MC` and `LLVM_BUILD` if the tree is elsewhere.)

### 14.10 The size of the whole job

**An estimate of the size.** A first back end that compiles C correctly, with the machine-code layer, is months of focused work, not weeks: I would put it at roughly three to six months for one engineer who has
written an LLVM back end before, less if the generated parts are in place first, and longer to reach the density of the pcc back end. Linker support in `lld` (relocations, and position-independent code if wanted) and
the compiler-runtime built-ins are further weeks. I have not built one for this machine and would not call this easy; whether it is "easy enough" is the author's judgement against this estimate.

*After milestone 1:* the machine-code layer, the part that generation from the grammar was expected to make fast, was written and verified in about 75 minutes of agent time on a small machine, which supports that expectation for the MC layer only. It says nothing yet about the hard parts (instruction selection for a
two-address machine with memory operands and condition codes, the calling convention and frames, clang, the runtime library), which are most of the work; the estimate above stands for them.

### 14.11 What OpenBSD adds beyond the compiler

OpenBSD's base system is built with clang on some architectures and with an in-tree GCC on others (the OpenBSD 6.4 release page lists "LLVM/Clang 6.0.0 (+ patches)" and "GCC 4.2.1 (+ patches) and 3.3.6 (+ patches)"; which architectures use which was not established, and the current split may differ), so on an architecture that uses clang the back end must be good enough to build a whole operating system, not only test programs. OpenBSD's RETGUARD return-address protection is implemented per architecture in its LLVM (amd64 and arm64 in 6.4, mips64 in 6.7, powerpc and powerpc64 in 6.9; openbsd.org/innovations.html), so a new architecture would also need it or go without. The officially supported platform list (openbsd.org/plat.html) includes arm64 and riscv64. Then the port itself: the
machine-dependent kernel (memory management code for the page tables, exception and interrupt entry, locore, the device drivers and autoconfiguration), the machine-dependent C library and dynamic linker, and a boot
loader. OpenBSD insists on properties this architecture has or can have (W^X is enforced by default since 6.0 and PIE is the default, per openbsd.org/innovations.html; that it requires SMP or enables SMAP was not checked): write-xor-execute (the `R`, `W`, `X` bits), position-independent executables (cheap here, ISA §19), and landing pads on indirect branches
(`LPAD`, still open, ABI version 1 has them off). It would depend on every item of this document's open list being closed, and on more: SMP, the lock and monitor question, a full device set.

**The order this suggests:** the system architecture of sections 3 to 6, the QEMU target extended to match, the LLVM back end (the critical path: selection, calling convention, then clang, section 14.7), then OpenBSD; if that proves too hard, a Unix/32V port with the existing pcc compiler (section 12).

## 15. System v1: a complete design for the first implementation (accepted 2026-10-22)

The options, how other architectures and operating systems do each of these, and how each choice measures against the goals (and where it falls short) are in [`pdp64-system-design.md`](pdp64-system-design.md).

**Status: accepted by the author on 2026-10-22 as the design to implement in the QEMU target and to write the first kernel against; the author may still change any part of it after seeing it work** (errata 36; the author's choices were register-based exception entry, software-managed accessed and dirty bits, and the whole of this section in the first cut). Sections 1 to 14 say what is established and what is open; this section closes every open item that the QEMU
memory-management unit and privileged mode, and a Unix/32V port, need, with the defaults most in the spirit of the PDP-11 and of the rest of this ISA, so that it can be implemented and then judged.

**PSW (16 bits).** Bit 0 `C`, bit 1 `V`, bit 2 `Z`, bit 3 `N` (the PDP-11 order), bit 4 `T` (trace), bits 5 to 7 the **interrupt priority** (0 to 7), bits 8 and 9 the **current mode**, bits 10 and 11 the **previous mode**, bits 12 to 15 reserved, zero.
Mode encoding as on the PDP-11: kernel 0, supervisor 1, user 3. `MTPS` in user mode writes only the flags (bits 0 to 3); in kernel mode all writable bits. `SPL #n` is kernel only.

**Exception entry (every exception and every interrupt).** Entry writes no memory except the fetch of the vector, and writes registers only: `EPC` is the address of the faulting instruction for an abort or progress exception and of the next instruction for a trap or
interrupt; **`EPSW`** (new system register) receives the old PSW; `EVA` the faulting address (aborts; zero otherwise); `ECAUSE` the vector number. The new PSW is: current mode kernel, previous mode the old current mode, **priority 7 for every exception and every interrupt** (errata 40), `T` and the flags cleared. The new PC is the 64-bit word at the **physical** address `VBR + 8 * vector` (**`VBR`**, a new system register). A bus error on that fetch is a machine check that halts. Nothing is pushed by the hardware: a handler that can be interrupted saves
`EPC` and `EPSW` itself with **`pushx`** (and restores them with **`popx`** before `RTI`; errata 37), one instruction each. Because the entry itself raises the priority to 7, no interrupt can arrive between entry and the save, and the window in which `EPC` and `EPSW` could be overwritten by an interrupt is closed by the hardware, not by the handler's first instruction. The handler lowers the priority with `SPL` once the two registers are saved
and it is ready to be interrupted. **A throwback to the PDP-11:** there the processor loaded the new `PSW` from the second word of the vector, and the vectors of traps conventionally held priority 7, so a PDP-11 trap handler also began with interrupts masked and chose when to lower them (this is from memory of the PDP-11 processor handbook and is not checked against it; see `fact-check-2026-10-22.md` section 12 for the to-fetch list). The pdp64 differs in one respect: the PDP-11 took the priority from the vector, so each vector could choose, while here it is fixed at 7 for all of them, which is simpler hardware and one `SPL` in the handler. What priority 7 does **not** protect against is an *exception* in the handler's first instructions (a page fault on the handler's own code or stack, or a bus error): that would overwrite `EPC` and `EPSW`, so the entry code and the kernel stack are pinned and unfaultable until the save is done.
**`RTI`** (kernel mode only) loads `PC` from `EPC` and `PSW` from `EPSW`; **`RTT`** does the same and sets `T` after the return. The kernel stack pointer of the new mode is selected by the mode change: `R14` names the bank of the current mode.

**Vector numbers** (the table has 512 entries; `ECAUSE` equals the vector number): 0 reset (unused by the QEMU machine), 1 machine check, 2 illegal instruction, 3 privileged instruction, 4 misaligned access, 5 non-canonical address, 6 instruction page fault,
7 load page fault, 8 store page fault, 9 protection (instruction), 10 protection (load), 11 protection (store), 12 divide by zero, 13 bus fault, 14 landing-pad violation, 15 breakpoint (`BPT`), 16 to 31 reserved, 32 to 63 interrupts (the virt machine: 32 timer, 33 console input, 34 console output),
64 to 255 reserved; **`TRAP #n` and `TRAPL #n` use vector 256 + n** (0 to 255). An instruction page fault has `EPC` = the faulting fetch address and `EVA` the same.

**Page-table entry (64 bits).** Bit 0 `V` valid, 1 `R`, 2 `W`, 3 `X`, 4 `U`, 5 `G`, 6 `A`, 7 `D`, bits 8 and 9 the memory type `MT`, bits 12 to 39 the physical page number (physical address bits 12 to 39, in place), all other bits zero (a set reserved bit is a page fault).
A non-leaf entry has `V` = 1 and `R` = `W` = `X` = 0 and points to the next table; a leaf at level 2 maps 1 GB, at level 1 maps 2 MB, at level 0 maps 4 KB. Virtual address bits 38 to 30 index level 2, 29 to 21 level 1, 20 to 12 level 0. `PTBR` holds the physical address of the level-2 table.
**Permissions:** a user-mode access needs `U` = 1; kernel mode may read and write `U` pages but may not execute them; `W` needs `R`... (`W` without `R` is reserved). **`A` and `D` are managed by software**: an access to a page with `A` = 0, or a write to a page with `D` = 0, raises the page fault of its kind and the kernel sets the bit
(the hardware walker never writes a page table).

**Memory-management control.** A new system register **`MMUCTL`**: bit 0 enables translation. At reset it is 0 and every address is physical (as the ISA promises: the machine comes up with the physical memory reachable). With translation enabled, an address in a direct mapping window
(`DMW0`, `DMW1`, kernel mode only, section 7) is translated by the window and any other address by the page tables, with the `ASID` selecting non-global entries. A write to `PTBR`, `ASID` or `MMUCTL` takes effect for the next instruction.
**`TLBI rN`** invalidates the translation of the page that contains the virtual address in `rN` (for the current `ASID` and the global entries); **`TLBIA`** invalidates all; **`TLBSYNC`** is a no-op on one core.

**System registers added to `mfsr`/`mtsr`** (errata 32 gave 0 to 7): **`epsw` 8**, **`vbr` 9**, **`mmuctl` 10**, **`asid` 11** (so the `ASID` has the general access as well; `MTASID` and `MFASID` stay), **`cpuid` 12** (read only; the core number, as `MFCPUID`). Numbers above 12 are reserved.

**Privileged instructions** (outside kernel mode they abort with vector 3): `RTI`, `RTT`, `HALT`, `SPL`, `MTASID`, `MFASID`, `TLBI`, `TLBIA`, `TLBSYNC`, `MTDMW`, `MFSR`, `MTSR`, `PROBER`, `PROBEW`, `WFE`. Not privileged: `MTDP`/`MFDP` (they name the current mode's `DP`; in user mode that
is the thread pointer), `ICINV`/`ICINVA` (a JIT needs them), `FENCE`, `SEV`, `TRAP`, `BPT`, `NOP`, and `MTPS`/`MFPS` with the restriction above.

**Interrupts.** Eight priority levels as on the PDP-11. A device asserts a level and a vector; the processor takes the interrupt between instructions when the level is greater than the PSW priority. The virt machine has: a **timer** (level 6, vector 32; registers: a 64-bit free-running
counter, a 64-bit compare, and a control/status register with an enable and a pending bit; the interrupt is level while counter >= compare and enabled), and a **console** (level 4; vector 33 for input, 34 for output; a four-register serial device in the spirit of the PDP-11 `KL11`: receive status, receive data,
transmit status, transmit data). `WFE` (kernel) sleeps until an interrupt is taken.

**Reset and the QEMU machine.** The machine starts in kernel mode, priority 7, `MMUCTL` 0, at the entry point of the ELF given with `-kernel`; the stack pointer of the kernel bank is the top of RAM. (The architectural reset vector, vector 0, is not modelled by the virt machine.)
The system-call stand-in (`trap #0` to `#2`) of `sim64` and of the current QEMU target remains for user programs run without a kernel (`-M pdp64-virt`, the default); a new machine option `kernel=on` turns it off, so that `TRAP` enters the kernel through vector 256 + n.

**Not in v1:** `DMW0` and `DMW1` have no defined register format yet, so they are stored by `mfsr`/`mtsr` and have no translation effect (kernels use ordinary page tables, for instance 1 GB leaf pages); the supervisor mode exists in the `PSW` and the banked registers and nothing uses it.

**What this leaves open** (unchanged from section 13): hardware breakpoints and watchpoints, performance counters, machine-check reporting beyond halt, the supervisor mode's use, the DMA device layouts, SMP.

## Sources

The ISA ([`pdp64-isa.md`](pdp64-isa.md)): §2.1, §2.2, §2.3, §4.11, §4.11.1, §6.1.1, §7.1 to §7.5, §8.1 to §8.3, §17, §19. Decisions: [`errata.md`](errata.md).
