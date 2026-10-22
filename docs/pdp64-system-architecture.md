# pdp64 system architecture: privilege, exceptions, interrupts, memory management and boot

[← pdp64 index](../README.md)

**Status: first draft, 2026-10-22.** This document gathers what the [ISA](pdp64-isa.md) says about the machine as an operating system sees it, in one place, and
**states plainly what is not yet defined**, so that it can be designed later. It decides nothing new. Each statement carries a label:

* **Established**: written in the ISA, the implementation plan or the LB64 document, with the section named.
* **Open**: not yet decided or not yet written. The list of all open items is in section 13.

The companion for the bus and the devices is [`pdp64-q64-bus.md`](pdp64-q64-bus.md). The question this document answers is: what does a kernel need from the
processor, and which of it exists? The first kernel is V7 Unix (section 12).

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
| `DMW0`, `DMW1` | 64 | `MTDMW` (read: `MFDMW` is not in the list) |
| `PTBR` | 64 | **no instruction is listed** |
| `EPC`, `EVA`, `ECAUSE` | 64 / 64 / 16 | **no instruction is listed** |

*Open*: the four gaps above. A kernel cannot install a page table or read why it was entered without them. They may be system-register moves in the style of the
existing `MTxx`/`MFxx` words, or one general move with a register number; that is a design decision. Also open: where `MFCPUID`-style identification (core number,
features, ISA version) is reported beyond the core number.

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

*Established* (ISA §8): a three-level page table of 4 KB pages (9 + 9 + 9 + 12 bits) gives a 39-bit virtual address; the physical address is 40 bits (Q64). Large pages at level 1
(2 MB) and level 2 (1 GB). A **hardware table walker** and a TLB (the plan assumes 4-way, 64 entries). A virtual address that is not the sign-extension of bit 38 aborts with
`ECAUSE = NONCANON` (§6.1.1). The page table entry holds: valid `V`; permissions `R`, `W`, `X`; user `U`; global `G` (ignores the ASID); accessed `A` and dirty `D`; and a 2-bit memory
type `MT` (`00` cached, `01` uncached, `10` device strongly ordered, `11` device weakly ordered). A 16-bit `ASID` makes a context switch constant-time (one store, no flush); the `G` bit
keeps kernel text mapped across address-space switches. Two **direct mapping windows** `DMW0` and `DMW1` map `PA = VA - VirtualBase + PhysicalBase` with no table reference,
kernel only, with a memory type each; the machine comes up with `DMW0` covering physical memory (§8.3). `TLBI` and `TLBIA` **broadcast** to all cores and `TLBSYNC` waits for completion
(§17.2). `PROBER` and `PROBEW` validate a user address without faulting.

This is enough for demand paging, copy-on-write, `fork`, `mmap` and `mprotect`, and it is the arrangement Linux uses on AArch64 with `VA_BITS=39`.

*Open*:
* **the page table entry bit layout**: the fields are listed, their positions in the 64-bit entry are not;
* how `PTBR` is written (section 3), and whether there is one table base for both halves of the address space or one for user and one for kernel;
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

*Established* (ISA §8.3): the machine comes up with `DMW0` covering physical memory, so there is no chicken-and-egg problem in setting up the first page tables. Resetting the bus is a bus-controller
register write, not an instruction (§4.11.1).

*Open*: the **reset state** (mode, `PSW`, priorities, which registers are defined), the **reset vector** and where the first instruction is fetched from, the firmware or boot ROM and what
it hands to the kernel (a device description? the memory size?), and the **boot protocol for releasing secondary cores** (ISA §17.4 lists it as still to be built).

## 10. Multiprocessing

*Established* (ISA §17): the memory model is **sequentially consistent**; the additions are `MFCPUID`, `ICINV`/`ICINVA`, `TLBSYNC`, `WFE`, `SEV` and broadcasting `TLBI`; coherence between CPUs is
transparent (snooping MSI for two to four cores), and between a CPU and a DMA device it is explicit (uncached mapping plus `FENCE`). The atomics are `CAS`, `SWAP`, the fetch-and-operate family and
`LL`/`SC`, each with a barrier-fused `_DB` form (§4.11).

*Open*: the lock-against-monitor question for the atomics on the bus (**blocking** for any second core; [`pdp64-q64-bus.md`](pdp64-q64-bus.md) §8), the inter-processor interrupt, the secondary-core boot
protocol (section 9), and the shared cache or coherent interconnect, which the ISA calls device-side and still to be built.

## 11. Debugging and machine checks

*Established*: the `T` bit single-steps; `BPT` is the shortest instruction so it can overwrite any other; `RTT` lets a debugger step out of its own trap handler (ISA §4.11.1). Machine checks are the
descendants of the PDP-11's bus error and are not restartable (§7.1); the old `nofault` idiom remains the pattern for probing hardware.

*Open*: hardware breakpoints and watchpoints; how a machine check is reported and logged; a performance counter.

## 12. The first operating system: a port of V7 Unix

*Decided by the author* (errata 30): the plan is that the first operating system is **a port of V7 Unix to the pdp64**. That fixes what the system architecture must provide first, and it is a
modest list, because V7 is small and uses the processor in a plain way. The precedent is Unix/32V, the original port of V7 to the VAX, which widened a 16-bit-`int` kernel to a 32-bit machine and
was built with the portable C compiler, the same compiler family as the pdp64's. This section is an assessment of the V7 port against the sections above; the statements about what V7 needs are
the assessment's, not facts established elsewhere.

| What V7 needs | What the pdp64 has | State |
|---|---|---|
| A way into the kernel for a system call, with the call number and arguments in registers or on the stack | `TRAP #n`, `TRAPL #n`, a banked kernel stack (sections 1, 5) | the entry sequence and the call convention are open (sections 4, 5) |
| Separate address spaces; V7 swaps whole processes, so a simple per-process mapping is enough at first | a three-level page table, `ASID`, broadcast `TLBI` (section 7) | `PTBR` cannot yet be written; the entry layout is open (sections 3, 7) |
| Mode, priority levels `spl0` to `spl7` | the `PSW` priority field and `SPL` (section 6) | the number of levels, and the `PSW` layout, are open (sections 2, 6) |
| A periodic clock interrupt (V7 uses a 50 or 60 Hz line clock) | nothing | open (section 6) |
| A console | nothing | a serial device is needed and is not one of the three devices of errata 29 (Ethernet, USB, disk); open |
| A disk with a driver | an eight-register DMA disk is the plan (errata 29) | the layout is open ([bus document](pdp64-q64-bus.md) §9) |
| Two privilege levels | kernel and user (section 1) | V7 never used the PDP-11's supervisor mode, which suggests that the open question about supervisor mode (section 1) can wait |
| Saved floating-point state | none beyond `FPSR`, since floating point lives in the general registers (section 8) | nothing to do |
| Signals and `fork`/`exec` | `fork` needs an address-space copy, `exec` a loader, signals a return path from the handler | kernel work; follows from sections 4 and 5 |

What is not in the architecture's documents at all:

* **The V7 kernel sources.** The toolchain repository ([v7unix-toolchain](https://github.com/moebiusV/v7unix-toolchain)) has V7's libraries, commands and headers (`orig/usr/src/cmd`, `libc`) and
  the C-ported commands of `modern/`, but not `/usr/sys`, the kernel. The V7 kernel sources are freely redistributable (they were released under a BSD-style licence in 2002) and are in the
  Unix Heritage Society's archive; fetching them is a step to be done with the project's browser tooling.
* **The word-size work.** The V7 kernel assumes a 16-bit `int`, 32-bit `long`s and 16-bit physical addresses counted in 64-byte clicks. The pdp64 is LP64 (`int` is 32 bits, `long` and pointers 64), so the port is
  the 32V kind of work: types, address arithmetic, and the memory-management files rewritten. The commands in `modern/` show the userland half of this already done for the toolchain's compiler.
* **The binary format.** V7 expects `a.out`; the pdp64 toolchain writes ELF (`ld64`, e_machine `0xF064`). The kernel's `exec` has to read ELF, or the linker has to write an `a.out`; not decided.
* **Everything the QEMU target lacks.** It runs user programs only; to boot a kernel it needs the memory-management unit, the privileged state, the interrupts, the timer and a serial device, which are the open
  items above made concrete. That is the practical order of work: define section 4 and section 6, then implement them in the QEMU target, then write the kernel against it.

A Linux or modern BSD port is a different question, since they need a GCC or LLVM back end; the plan does not depend on it.

## 13. The list of open items

1. The supervisor mode: its use, or its removal (section 1).
2. The `PSW` bit layout; `MTPS` in user mode (section 2).
3. Instructions or a general move for `PTBR`, `EPC`, `EVA`, `ECAUSE` (section 3).
4. The exception entry sequence, the vector table and vector numbering, the numeric `ECAUSE` codes, nested exceptions, `RTI`/`RTT` semantics (section 4).
5. The system-call convention (section 5).
6. The interrupt controller, priority levels, the timer, the inter-processor interrupt (section 6).
7. The page table entry layout, the walker's `A`/`D` behaviour, `TLBI` forms, ASID rollover policy, cache control (section 7).
8. The reset state and vector, firmware and boot hand-off, secondary-core boot (section 9).
9. Atomics against the bus (section 10; bus document §8).
10. Hardware breakpoints, machine-check reporting, performance counters (section 11).
11. The device register layouts, the DMA descriptor format and the interrupt convention ([bus document](pdp64-q64-bus.md) §9).

When these are decided they should be written once, as the instruction numbers are, in a grammar from which the register definitions, the cause codes, the vector numbers and the emulator's models
are generated.

## Sources

The ISA ([`pdp64-isa.md`](pdp64-isa.md)): §2.1, §2.2, §2.3, §4.11, §4.11.1, §6.1.1, §7.1 to §7.5, §8.1 to §8.3, §17, §19. Decisions: [`errata.md`](errata.md).
