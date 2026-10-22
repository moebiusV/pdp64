# System v1: the options, how others do it, and how the choices serve the goals

[← pdp64 index](../README.md)

**Status: written 2026-10-22, after the fact.** The choices of System v1 ([`pdp64-system-architecture.md`](pdp64-system-architecture.md) §15, errata 36) were proposed by Claude and accepted by the author with
little discussion. This document is the discussion that was missing: what the main options were, what the major architectures and operating systems do, how each choice measures against the author's stated goals, and where it does not.
**Statements about other architectures and operating systems are from general knowledge, not checked against their manuals in this session; they are marked "(to verify)" where the detail matters.** The choices are the author's to change.

## 1. The goals the design is judged by

From the README and the ISA's own ranked rules (ISA §1, §1.2), and from what the author has said in the course of the work:

* **G1, minimal chance of inconsistency.** One source of truth (the numbers live once, in grammars); no mode bits that change the meaning of unrelated instructions; an instruction does what its name says; one mechanism where others have several.
* **G2, restarts easy and minimal.** Every instruction restartable with O(1) recorded state; faults precise; no undo journal that software must run; the machinery of taking an exception must itself be unable to fail in a hard-to-recover way.
* **G3, fewer instructions and fewer memory fetches**, on the paths that run most: kernel entry and exit, handler dispatch, the page-table walk, the context switch.
* Behind them, the ranked constraints of the ISA: a small gate count first, a bounded fault surface second, pleasant assembler third.

## 2. The decisions

Each decision: the options, who does what, what System v1 chose, and what it costs.

### D1. Where the old PC and status go on an exception

| System | What it does |
|---|---|
| PDP-11 | the hardware loads a new PC and PSW from the vector and **pushes the old PC and PSW on the new mode's stack** |
| VAX | pushes PC and PSL (and parameters) on the kernel or interrupt stack |
| x86-64 | pushes SS, RSP, RFLAGS, CS, RIP (and an error code) on a stack chosen through the task-state segment or the interrupt-stack table |
| AArch64 | **registers**: the PC goes to `ELR_ELx`, the status to `SPSR_ELx` |
| RISC-V | **registers**: `sepc`, `sstatus` (previous-mode and interrupt-enable bits), `scause`, `stval` |
| MIPS, POWER | registers: `EPC`, `Cause`, `BadVAddr`; `SRR0`, `SRR1` |
| **pdp64 System v1** | **registers**: `EPC`, `EPSW`, `EVA`, `ECAUSE`; nothing is written to memory |

Chosen: registers. Why: **entry writes no memory, so entry cannot fault** (a bad kernel stack cannot turn into a double fault), which is G2; `RTI` is register-to-register. *Cost:* a second exception taken before the handler has saved `EPC` and `EPSW`
overwrites them, so a handler runs at priority 7 until the two registers are saved; a stack-push machine nests for free. And the handler spends instructions that the hardware spends for free elsewhere: two `mfsr` and two stores, about four instructions on
every kernel entry that may nest. That is against G3. A candidate that would win it back is in §5.

### D2. How the handler is found

| System | What it does |
|---|---|
| PDP-11 | a vector per cause, two words each, at a low fixed address |
| VAX | the System Control Block, a table of vectors |
| x86-64 | the interrupt descriptor table, 256 gate descriptors |
| AArch64 | a vector table at `VBAR_ELx` of 16 entries, 0x80 bytes apart, chosen by source and type (not by cause); the handler reads `ESR` to find the cause |
| RISC-V | one entry point (`stvec`) in direct mode: the handler reads `scause` and dispatches in software; a table only for interrupts in vectored mode |
| MIPS | a few fixed addresses (TLB refill, general exception) and a software dispatch on `ExcCode` |
| **pdp64 System v1** | **a table of 8-byte handler addresses at physical `VBR + 8 * vector`**; `ECAUSE` is the vector number |

Chosen: a table indexed by cause, as on the PDP-11 and VAX. Why: **the dispatch is done by the hardware**, so a page fault, a divide by zero and a timer interrupt each arrive at their own handler with no software `ECAUSE` decode and no jump table
(G3, and G1 because there is one dispatch mechanism and one number space). *Cost:* one 8-byte memory fetch on every exception, which the fixed-entry machines do not make; against that, a software dispatch makes a load and an indirect jump anyway, so the fetch count is
about equal and the instruction count is lower. A table that must be at a physical address also means the kernel has to know where it is with translation on.

### D3. System calls

| System | What it does |
|---|---|
| PDP-11 | `TRAP`, `EMT`: a vector chosen by the instruction |
| VAX | `CHMK` and friends: change mode with a code operand, through the System Control Block |
| x86-64 | `SYSCALL`: entry address and masks in model-specific registers; does not touch the stack; a separate fast path from interrupts |
| AArch64, RISC-V | `SVC`, `ecall`: an ordinary exception; the number is a register; software dispatches |
| **pdp64 System v1** | **`TRAP #n` / `TRAPL #n` enter vector 256 + n**: 256 system-call entry points in the same table as every other exception |

Chosen: the same mechanism as every other exception, with the call number selecting the handler. Why: nothing special to build or specify (G1); and **the system-call table is the vector table**, so a kernel that wants one handler per call has no dispatch code at all
(G3). A kernel with a single entry reads the number back from `ECAUSE`. *Cost:* there is no dedicated fast path that skips the vector fetch, as x86-64 has.

### D4. Privilege modes

PDP-11: kernel, supervisor, user. VAX: kernel, executive, supervisor, user. x86: four rings, in practice two used. AArch64: EL0 to EL3. RISC-V: machine, supervisor, user. Unix on all of these uses two. **Chosen:** the PDP-11's three, with the stack pointer and the
direct-page register banked per mode (ISA §2.1), the PDP-11 mode encoding (kernel 0, supervisor 1, user 3). *Cost:* nothing uses supervisor mode; it costs a third bank of two registers and a third set of mode checks. This is an unresolved question (system architecture §1), not a decision.

### D5. Interrupt priority

PDP-11 and VAX: priority levels in the status word (PDP-11 eight, VAX 32); a device interrupts when its level exceeds the processor's. x86: the APIC priority classes and task-priority register. AArch64: the GIC's priorities and priority mask. RISC-V: the PLIC's priority threshold, outside the core.
**Chosen:** the PDP-11's, in the processor: three bits in the PSW, eight levels, `SPL` sets them, a device level above the PSW priority is taken. Why: a Unix kernel written for the PDP-11 or VAX already uses exactly this model (`spl0`..`spl7`), and it needs no interrupt-controller programming in the processor (G1: one place to look).
*Cost:* only eight levels, no per-source masking in the processor; the controller is a device-side matter, which the system document leaves open.

### D6. The shape of the page table

| System | What it does |
|---|---|
| PDP-11 | segmentation: eight page-address and page-descriptor register pairs per mode; no tables in memory |
| VAX | three regions (P0, P1, system) with base and length registers; **linear** page tables, themselves virtual |
| x86-64 | four-level tree (five optional), 9 bits per level, 48-bit virtual address |
| AArch64 | four-level tree with 4 KB pages (three levels for a 39-bit address), two table bases (`TTBR0` user, `TTBR1` kernel) |
| RISC-V | Sv39: **three levels, 39-bit address**, one table base (`satp`); Sv48 four |
| MIPS | no hardware walk: a **software-refilled TLB** |
| **pdp64 System v1** | **three-level tree, 4 KB pages, 39-bit virtual (Sv39-like), one table base `PTBR`; 2 MB and 1 GB leaves** |

Chosen: the three-level tree. Why: **three memory fetches per TLB miss against four on x86-64 or AArch64's 48-bit mode** (G3); the same shape as the RISC-V Sv39 and AArch64's 39-bit mode, which Linux already runs on, so the kernel-side machinery is well understood;
a software-refilled TLB would remove the walker (a few thousand transistors) but make every miss a trap. *Cost:* 39 bits is 512 GB of address space, less than 48 bits (ASLR entropy is lower, very large mappings do not fit); a single table base for both halves means the kernel is mapped in every address space
(global pages), with no separate-tables defence against speculative side channels (the machine has no speculation, ISA §17.5).

### D7. The page-table entry

x86-64: flags in the low bits, physical address in place at bits 12 to 51, no-execute at bit 63. AArch64: physical address in place, attributes through an index into a memory-attribute register. RISC-V: flags V, R, W, X, U, G, A, D in bits 0 to 7, the physical page number from bit 10.
**Chosen:** the flags in bits 0 to 7 in the **RISC-V order** (V R W X U G A D), the 2-bit memory type at 8 and 9, the physical page number **in place** at bits 12 to 39 (as x86-64 and AArch64). Why: familiar to anyone who has read Sv39, and **the walker needs no shift or mask to form an address** (a gate-count and latency saving). The
memory type is two bits in the entry, as RISC-V's Svpbmt does, not an indirection through a register, so there is nothing to program.

### D8. Accessed and dirty bits

x86-64: the hardware sets both, atomically. AArch64: optional hardware management (otherwise a fault, the access flag managed by software). RISC-V: either a fault (Svade) or hardware (Svadu). MIPS: the dirty bit is a TLB write-permission bit set by software. **VAX: a hardware modify bit and no reference bit at all; 3BSD emulated reference bits in software** (to verify).
**Chosen:** software. An access to a page with `A` = 0, or a write to one with `D` = 0, faults and the kernel sets the bit. Why: **the walker never writes memory**, which is G2 (a walk cannot fault on a write, cannot need an atomic read-modify-write of a page table, and the open lock-versus-monitor question stays away from it) and G4 (no read-modify-write path in the walker), and it is how
3BSD's paging worked on the VAX. *Cost:* one extra fault the first time each page is touched, and one more on its first write; Linux on RISC-V machines without hardware management pays this too.

### D9. Switching translation on

x86: `CR0.PG`. AArch64: `SCTLR_EL1.M`. RISC-V: `satp.MODE` (Bare is zero). VAX: `MAPEN`. PDP-11: a bit in SR0. MIPS: always on, with unmapped windows. **Chosen:** a system register `MMUCTL`, bit 0, reset to 0.
**This choice sits badly with the ISA's own rule.** The ISA says there are **no mode bits** (ISA §1.1: a bit whose value changes the meaning of unrelated instructions), and ISA §8.3 says the machine **comes up with `DMW0` covering physical memory**, so translation is always on and there is nothing to switch. `MMUCTL` is not
per-thread state and is not saved across a context switch, which is the particular cost the rule exists to avoid; but it is a mode bit. It was added because the format of the direct mapping windows is not defined yet. **The consistent design is to define the `DMW` format, boot with a window that maps low physical memory, and drop `MMUCTL`.**
That is an open item, recorded here so it is not lost.

### D10. Keeping the TLB right

x86-64: `INVLPG`, `CR3` writes, PCID. AArch64: broadcast `TLBI` by address, ASID or all. RISC-V: `sfence.vma` by address and ASID (local; remote shoot-down is software). **Chosen:** a 16-bit ASID; `TLBI rN` (one page, current ASID and global), `TLBIA`, `TLBSYNC`, all broadcast (ISA §17.2). Why: a context switch is one store to
the ASID and no flush (the PDP-11 map sets' constant-time switch, kept), and broadcast removes the interprocessor-interrupt shoot-down of x86 (G3 for SMP). The QEMU model flushes on ASID change as the simplest correct approach; that is an implementation simplification, not the architecture.

### D11. The kernel's access to user memory

PDP-11: explicit instructions, `MFPI` and `MTPI`, move to and from the previous mode's space. VAX: `PROBER`/`PROBEW` then ordinary access. x86: `SMAP` blocks it unless `STAC` is executed. AArch64: `PAN` blocks it unless cleared. RISC-V: `SUM` in `sstatus`, off by default.
**Chosen:** kernel mode may read and write pages marked user, but may not execute them (the equivalent of `SMEP`); `PROBER`/`PROBEW` are available. *Cost:* **there is no `SMAP`/`PAN`/`SUM` guard**: a kernel bug that dereferences a user pointer by mistake succeeds. Modern kernels value that guard (OpenBSD turns `SMAP` on). It would be one more bit in the PSW; it is an open item, not
needed for 3BSD.

### D12. Restart

PDP-11: three status registers and a two-entry journal of register side effects (`MMR0`, `MMR1`, `MMR2`) that software reads and undoes. VAX: saved microstate and a first-part-done flag for the long instructions. x86: precise exceptions, with `REP` string instructions restartable by their registers. AArch64, RISC-V: precise.
**pdp64:** precise; an abort has **no architectural effect** (ISA §7.2: the register update of `(Rn)+` and `-(Rn)` is buffered and committed at retirement, so there is no journal to read); the number of faults an ordinary instruction can take is bounded (ISA §7.3); block instructions keep their progress in registers; exception entry
cannot fault (D1). This is the one area where System v1 follows the ISA to the letter.

## 3. How the choices measure against the goals

| Choice | G1 consistency | G2 restart | G3 instructions and fetches |
|---|---|---|---|
| D1 registers (`EPC`, `EPSW`) | one saved state | **entry cannot fault; `RTI` is registers** | − about 4 handler instructions per nesting entry |
| D2 vector table by cause | one mechanism, one number space | the table fetch is the only entry memory access | **no software dispatch**; one 8-byte fetch |
| D3 `TRAP #n` = vector 256 + n | no special system-call path | same | **no dispatch code** with one handler per call; − no fast path past the fetch |
| D4 three modes | PDP-11 compatible | n/a | − an unused bank |
| D5 eight priority levels | one place to look | n/a | the V7/3BSD model, no controller code |
| D6 three-level tree | Sv39-like | precise walk | **3 fetches per miss** |
| D7 PTE in place | familiar | n/a | **no shift in the walker** |
| D8 software `A`/`D` | one writer of page tables (the kernel) | **the walker never writes** | − one extra fault per page first use, per first write |
| D9 `MMUCTL` bit | **− a mode bit, against ISA §1.1 and §8.3** | n/a | n/a |
| D10 ASID, broadcast `TLBI` | n/a | n/a | no flush on switch, no shoot-down IPI |
| D11 kernel sees user pages | − no guard | n/a | no mode switching for copyin/copyout |
| D12 precise, deferred side effects | follows the ISA | **the strongest** | n/a |

The design is strongest on G2, which is where it follows the ISA rules most closely; on G3 it wins where the hardware does the dispatch (D2, D3) and the walk (D6, D7), and loses a few handler instructions where it declined to push state (D1) and a fault per page where it
declined to write page tables (D8). It is **weakest on G1 in two places, D9 and D11**.

## 4. What the major operating systems need from this

| Need | System v1 |
|---|---|
| A kernel entry that can be nested or not at will | yes, by saving `EPC`/`EPSW` (D1), at a cost |
| Per-CPU data in one register | the kernel `DP` copy (ISA §17.4) |
| Thread-local storage in one instruction | the user `DP` copy (ISA §19.3) |
| Copy-on-write, demand paging, `mmap`, `mprotect` | yes: `R`/`W`/`X`/`U`, software `A` and `D`, 4 KB pages |
| Large pages for the kernel's own mapping | 2 MB and 1 GB leaves |
| No-execute pages, kernel not executing user pages | yes |
| ASLR and position-independent code | PIE is cheap (ISA §19); 39 bits limits the entropy |
| SMP: broadcast shoot-down, atomics, a memory model | broadcast `TLBI`, atomics, sequentially consistent (ISA §17); the bus atomics question is open |
| Kernel protected from its own user-pointer mistakes | no (D11) |
| Separate address spaces for kernel and user against side channels | no (D6); the machine does not speculate |
| 3BSD (and 32V) | everything it needs of the processor: two modes, eight priority levels, a clock, a console, a disk, page tables, restartable faults |

## 5. Ideas that come out of this, not yet decided

1. **Save and restore the exception state in one instruction each** (for example `PUSHX` that pushes `EPC` and `EPSW` and `POPX` that pops them): it would win back the four handler instructions of D1 for two bytes each, keep exception entry register-only, and keep the machine's rule that an instruction does what its name says.
2. **Define the direct mapping window format and remove `MMUCTL`** (D9), the consistent fix.
3. **A user-memory guard bit** in the PSW (D11), if the kernel is to be hardened.
4. **Hardware-managed accessed and dirty bits** as an option, if the cost of the extra faults shows up in measurements (D8); it brings back the lock-versus-monitor question for the walker.
5. **A per-CPU trap number to handler mapping**, if one table for all processors is ever a problem (not for v1).

## 6. Sources and caveats

This document is Claude's, written for the author to criticise. The comparison tables are from memory of the manuals (the PDP-11/70 processor handbook, the VAX architecture handbook, the Intel and Arm architecture manuals, the RISC-V privileged specification) and of how
Linux, BSD and others use them; none was re-read for this document. The pdp64 statements are from [`pdp64-system-architecture.md`](pdp64-system-architecture.md) §15, [`errata.md`](errata.md) 32 and 36 and the ISA.
