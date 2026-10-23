# 6. The kernel: modes, exceptions and memory management

[← manual index](00-index.md)

**An operating system on the pdp64 sees three things: a status word with a mode and a priority, an exception mechanism that writes only registers, and a three-level page table with software-managed accessed and dirty bits.** This chapter is what a kernel writer needs: the modes and the privileged instructions, the exception and interrupt entry, the vector table, the system registers, translation and the page-table entry, the user-memory guard, system calls, and how the machine starts. It is the design called System v1, accepted on 2026-10-22 and implemented in the simulator and the QEMU target; the options and the comparisons with other architectures are in [`../pdp64-system-architecture.md`](../pdp64-system-architecture.md) (section 15) and [`../pdp64-system-design.md`](../pdp64-system-design.md). Tags: *(D)* decided; *(P)* proposed.

## 6.1 Modes and the status word

**6.1.1** There are three modes, with the PDP-11's encoding: kernel 0, supervisor 1, user 3. The supervisor mode exists in the status word and in the banked registers and nothing uses it yet. *(D, errata 36)*

**6.1.2** The status word holds the flags in bits 0 to 3, the trace bit in bit 4, the interrupt priority in bits 5 to 7, the current mode in bits 8 and 9, the previous mode in bits 10 and 11, and the user-access guard in bit 12; the other bits are zero. *(D)*

**6.1.3** `MTPS` in user mode writes only the flags; in kernel mode it writes every writable bit. `SPL #n` is kernel-only. *(D)*

**6.1.4** The stack pointer `R14` and the direct-page register `DP` each have one copy per mode; the mode selects which one an instruction names. *(D)*

**6.1.5** These instructions abort with the privileged-instruction vector outside kernel mode: `RTI`, `RTT`, `HALT`, `SPL`, `MTASID`, `MFASID`, `TLBI`, `TLBIA`, `TLBSYNC`, `MTDMW`, `MFSR`, `MTSR`, `PROBER`, `PROBEW`, `WFE`, `ISYNC`, `STUA`, `CLUA`, `PUSHX`, `POPX`. *(D)*

**6.1.6** These are not privileged: `MTDP` and `MFDP` (in user mode, the thread pointer), `ICINV` and `ICINVA` (a JIT needs them), `FENCE`, `SEV`, `HINT`, `TRAP`, `BPT`, `NOP`, and `MTPS` and `MFPS` with the restriction above. *(D)*

*Commentary.* **Precedent.** The PDP-11 had kernel, supervisor and user modes, with a status word whose priority and mode fields the pdp64 keeps, and a stack pointer per mode so that a trap arriving in user mode finds a kernel stack without searching for one. **Trade-offs.** Three modes cost a third copy of two registers and no logic the kernel uses; supervisor mode has no user yet, and is kept because adding a mode later would change the status word and every saved copy of it. **Benefits.** Entry from user mode needs no stack switch code; a threaded program's pointer and a kernel's per-CPU pointer are the same register in different modes. **Modern comparables.** x86 has four rings of which two are used; AArch64 has exception levels 0 to 3; RISC-V has user, supervisor and machine modes. **Use.** `MFSR` and `MTSR` are the whole of system control; `PROBER` and `PROBEW` replaced the `nofault` idiom of V6 and V7. **Impact.** *Kernel:* Banked stack pointers mean a trap from user mode needs no stack switch, and the direct-page copies give a per-CPU pointer in the kernel and a thread pointer in user mode. *Compiler:* User-mode thread-local storage is one `MOVQ d(DP), Rd`. *Hardware:* Three copies of two registers, selected by the mode, and a mode comparison on privileged decode.

## 6.2 Exceptions and interrupts

**6.2.1** Entry to an exception or an interrupt writes only registers: `EPC` receives the address of the faulting instruction (for an abort or a progress exception) or of the next instruction (for a trap or an interrupt), `EPSW` the old status word, `EVA` the faulting address (zero except for aborts), `ECAUSE` the vector number. *(D, errata 36)*

**6.2.2** The new status word has the current mode kernel, the previous mode the old current mode, priority 7, and the trace bit and the flags cleared. *(D, errata 40)*

**6.2.3** The new program counter is the 64-bit word at the physical address `VBR + 8 × vector`; a bus error on that fetch is a machine check that halts. *(D)*

**6.2.4** The hardware pushes nothing. A handler that can be interrupted saves `EPC` and `EPSW` with `PUSHX`, lowers the priority with `SPL`, and before returning restores them with `POPX` and executes `RTI`. *(D, errata 37)*

**6.2.5** `RTI` loads the program counter from `EPC` and the status word from `EPSW`; `RTT` does the same and sets the trace bit after the return. *(D)*

**6.2.6** The vector table has 512 entries and `ECAUSE` equals the vector number. *(D)*

| Vectors | Meaning |
|---|---|
| 0 | reset (not used by the QEMU machine) |
| 1 | machine check |
| 2, 3, 4, 5 | illegal instruction, privileged instruction, misaligned access, non-canonical address |
| 6, 7, 8 | instruction, load and store page fault |
| 9, 10, 11 | protection violation on instruction, load and store |
| 12, 13 | divide by zero, bus fault |
| 14, 15 | landing-pad violation, breakpoint |
| 16 to 31 | reserved |
| 32 to 63 | interrupts (in the virt machine, 32 timer, 33 console input, 34 console output) |
| 64 to 255 | reserved (the proposal assigns device interrupts here, vector 64 plus the slot) |
| 256 + n | `TRAP #n` and `TRAPL #n`, n from 0 to 255 |

**6.2.7** There are eight interrupt priority levels; the processor takes an interrupt between instructions when its level is greater than the priority in the status word; the timer is at level 6 and the console at level 4. *(D)*

*Commentary.* **Precedent.** The PDP-11 pushed the program counter and the status word on a stack and loaded new ones from a two-word vector, and its trap vectors conventionally held priority 7, so a PDP-11 handler began with interrupts masked and chose when to lower them; its interrupts took the priority of their device from the vector. The VAX pushed the program counter and the processor status longword and raised the priority to the interrupt's level for an interrupt, leaving it unchanged for an exception. **Trade-offs.** Entering in registers is short and cannot itself fault (no memory is written), and costs the handler an explicit save; it needs the priority raised on entry, because a higher-level interrupt could otherwise arrive before the handler had stored the pair and overwrite it, which is why the entry sets priority 7 for every exception and interrupt, a fixed choice where the PDP-11 let each vector choose. **Improvements.** `PUSHX` and `POPX` make the save and restore one instruction each; the aborts are precise, so a page-fault handler repairs the mapping and executes `RTI` to run the instruction again. **Benefits.** The kernel survey estimates a system-call entry at four or five instructions on paper, against 45 to 70 on RISC kernels; no entry code is needed to find a stack. **Modern comparables.** AArch64 and RISC-V latch the return address and status in registers; x86 pushes five words on the stack; every one of them masks interrupts on entry. **Impact.** *Kernel:* Entry is four or five instructions on paper; priority 7 on entry removes the code that would otherwise guard the saved state. *Compiler:* Handlers written in C need a short assembler stub to save and restore; no other code generation is affected. *Hardware:* Entry writes registers only, so it cannot fault, and the vector fetch is one 64-bit read.

## 6.3 System registers

**6.3.1** The system registers are reached by `MFSR` and `MTSR` with an 8-bit register number. *(D, errata 32)*

| Number | Register | Meaning |
|---|---|---|
| 0 | `PTBR` | physical address of the level-2 page table |
| 1 | `EPC` | exception program counter |
| 2 | `EVA` | exception virtual address |
| 3 | `ECAUSE` | exception cause (the vector number) |
| 4, 5 | `DMW0`, `DMW1` | direct-mapping windows (stored, not yet defined) |
| 6, 7 | `USP`, `SSP` | the user and supervisor stack pointers |
| 8 | `EPSW` | exception status word |
| 9 | `VBR` | vector base register |
| 10 | `MMUCTL` | memory-management control (bit 0 enables translation) |
| 11 | `ASID` | address-space identifier |
| 12 | `CPUID` | the core number (read-only) |
| 13 and up | | reserved (feature and identification registers are proposed here) |

**6.3.2** A write to `PTBR`, `ASID` or `MMUCTL`, or an `ICINV`, is guaranteed to take effect only after the next `ISYNC`. *(D, errata 39)*

*Commentary.* **Precedent.** The VAX had `MTPR` and `MFPR` with an internal-register number, the same design. The PDP-11 kept its control registers at fixed high addresses and reached them with ordinary moves. **Trade-offs.** A general pair of instructions with 243 free numbers costs two opcodes and no decoding as the registers are added; separate instructions per register would have spent opcode space with every register. **Benefits.** A new register is a number, not an instruction. **Modern comparables.** AArch64's `MRS` and `MSR`, RISC-V's `CSRR` and `CSRW`, PowerPC's `MFSPR` and `MTSPR`; the kernel survey found privileged-register access to be 48% of all the compiler-invisible instructions in four kernels. **Impact.** *Kernel:* A single pair of instructions reaches every system register, so adding a register adds a number and no instruction. *Compiler:* The compiler reaches them through an intrinsic with a constant register number. *Hardware:* A control-register file addressed by an 8-bit number, with a read-only decode for the identification registers.

## 6.4 Memory management

**6.4.1** Virtual addresses are 39 bits, translated by three levels of nine bits over 4 KB pages: address bits 38 to 30 index level 2, 29 to 21 level 1 and 20 to 12 level 0; `PTBR` holds the physical address of the level-2 table. *(D)*

**6.4.2** A page-table entry is 64 bits: `V` (valid) in bit 0, `R`, `W`, `X`, `U` and `G` (global) in bits 1 to 5, `A` (accessed) and `D` (dirty) in bits 6 and 7, the memory type `MT` in bits 8 and 9, and the physical page number in bits 12 to 39, in place; all other bits are zero, and a set reserved bit is a page fault. *(D)*

**6.4.3** A non-leaf entry has `V` set and `R`, `W` and `X` clear and points to the next table; a leaf at level 2 maps 1 GB, at level 1 maps 2 MB and at level 0 maps 4 KB. *(D)*

**6.4.4** A user-mode access needs `U`; kernel mode may read and write user pages but may not execute them; `W` without `R` is reserved. *(D)*

**6.4.5** The accessed and dirty bits are managed by software: an access to a page with `A` clear, or a write to a page with `D` clear, raises the page fault of its kind and the kernel sets the bit; the hardware walker never writes a page table. *(D, errata 36)*

**6.4.6** Translation is off at reset (`MMUCTL` is zero and every address is physical) and is enabled by bit 0 of `MMUCTL`; the `ASID` selects non-global entries. *(D, errata 44)*

**6.4.7** `TLBI rN` invalidates the translation of the page containing the address in `rN` for the current address space and the global entries; `TLBIA` invalidates all; both broadcast to every core and `TLBSYNC` waits for the broadcast to finish. *(D)*

**6.4.8** The memory type of a page is one of normal cached, normal uncached, device strongly ordered and device weakly ordered. *(D)*

**6.4.9** The translation is split by the top bit of the virtual address: bit 38 clear selects the lower half, translated from the table at `PTBR` (one per address space), and bit 38 set selects the upper half, translated from the table at a new system register `KTBR` (one for the whole system, the kernel's). In user mode the upper half is never walked: an access to it takes a translation fault without consulting any page table, so no kernel translation is present for a speculating core to read around a permission check. In kernel mode both halves are walked, so the copy routines of 6.5 need no change of root. Entry to an exception changes the mode in hardware and so changes the halves walked; no entry trampoline is mapped in user space. Translation-buffer entries carry the half they came from, and a mode change flushes nothing. The register number of `KTBR` and the layout of the level-2 tables of the two roots are not yet fixed. *(D, the author 2026-10-23, errata 71; not yet in the specification files, the simulator or QEMU)*

*Commentary.* **Precedent.** The PDP-11 had eight segments per mode, each with a base and a length, and no page tables; the VAX had a linear page table per region with a hardware modify bit and no reference bit, so 4.3BSD emulated reference bits in software. **Trade-offs.** Software-managed bits cost one extra fault on the first touch of each page and one on the first write, and they make the walker small and make it safe against the chip bugs of hardware management that other architectures have had; a hardware-managed option, advertised in a feature register, is the planned next step. A fourth page-table level would give 48 bits at the price of a longer walk on every miss. **Improvements.** The entry has the physical address in place, so no shifting; a leaf at any level makes large pages free to use for the kernel's own mapping. **Benefits.** A walker that only reads is small; a kernel's page-fault handler is the same code for first touch, first write and demand paging, differing only in the bits it sets. **Modern comparables.** The geometry is RISC-V's Sv39; x86-64 and AArch64 use four levels and hardware-managed accessed and dirty bits; MIPS refills its translation buffer in software. **Impact.** *Kernel:* The handler sets accessed and dirty bits; leaves at any level let the kernel map itself with 1 GB pages; `TLBI` broadcasts so there is no shootdown code. *Compiler:* Position-independent code uses PC-relative addressing; the canonical 39-bit form means pointers need no masking. *Hardware:* The walker only reads; the physical page number is in place, so no shifting; three levels of nine bits keep the walk to three reads.

## 6.5 The user-memory guard and system calls

**6.5.1** With the guard bit `UA` clear, a kernel-mode data access to a user page faults; `STUA` sets it and `CLUA` clears it; exception entry clears it and `EPSW` keeps the old value. *(D, errata 43)*

**6.5.2** `TRAP #n` (n up to 15, two bytes) and `TRAPL #n` (n up to 255) enter the kernel through vector 256 + n; the system-call number and arguments travel in registers by the ABI. *(D)*

**6.5.3** A copy routine opens the guard, copies, and closes it; every error path out of the copy must close it, and entry clearing it bounds the damage if one does not. *(D)*

*Commentary.* **Precedent.** The PDP-11 reached user memory with the explicit instructions `MFPI` and `MTPI`, since its kernel and user address spaces were separate, so accidental access was impossible; the VAX read user addresses directly after a `PROBER` check. **Trade-offs.** The guard is a mode bit, accepted because it lives in the status word, which is saved anyway; it makes a stray kernel pointer a clean fault at the cost of an open and a close around every user copy. **Benefits.** A kernel bug that dereferences a user pointer by mistake no longer succeeds silently. **Modern comparables.** x86 `SMAP` with `STAC` and `CLAC`, AArch64 `PAN` and RISC-V `SUM`. **Use.** The user copy routines (`copyin`, `copyout`, `copyinstr`). **Impact.** *Kernel:* Every user copy opens and closes the guard; every error path must close it, and entry clearing it bounds the damage of one that does not. *Compiler:* The copy routines are written in assembler or inline assembler; system-call stubs are one `TRAP`. *Hardware:* One status-word bit and one check on a kernel-mode data access to a user page.

## 6.6 Reset and the first kernel

**6.6.1** At reset core 0 starts in kernel mode at priority 7 with translation off, the guard clear and `VBR` zero; the kernel sets `VBR`, builds page tables, writes `PTBR`, sets `MMUCTL` bit 0 and executes `ISYNC`. *(D for the QEMU machine; P for the architectural reset, chapter 4)*

**6.6.2** The QEMU machine starts at the entry point of the ELF given with `-kernel`, with the kernel stack at the top of memory; the option `kernel-mode=on` turns off the system-call stand-in of user-mode programs so that `TRAP` enters the kernel. *(D)*

**6.6.3** The first operating system is OpenBSD, with Unix/32V as the fallback if OpenBSD proves too hard. *(D, errata 41)*

*Commentary.* **Precedent.** The PDP-11 and VAX turned the memory manager on with a bit in a status register and a jump to a mapped address, each needing a transition in the boot code. **Trade-offs.** Translation-off at reset is the same arrangement, and the single bit is a machine-wide mode bit accepted for that reason (errata 44). **Benefits.** The boot code runs at physical addresses until the kernel is ready, with no identity-map trampoline of the kind x86 needs. **Modern comparables.** RISC-V's `satp` with a bare mode, AArch64's `SCTLR.M`. **Impact.** *Kernel:* Boot code runs at physical addresses until the kernel is ready, with no identity-map trampoline. *Compiler:* The first kernel code is position-independent and uses no virtual address until translation is on. *Hardware:* Translation-enable is one bit.

## 6.7 System instructions, exceptions and interrupts

**6.7.1** There are three modes (kernel, supervisor, user); supervisor is defined and unused. System instructions executed outside kernel mode abort with the privileged-instruction vector. *(D)*

**6.7.2** `TRAP #n` (0 to 15, two bytes) and `TRAPL #n` (vectors 0 to 255) enter the kernel; `RTI` returns, and `RTT` returns and sets the trace bit after. *(D)*

**6.7.3** An exception or interrupt writes only registers: `EPC` receives the address of the faulting instruction (or the next one, for a trap or interrupt), `EPSW` the old status word, `EVA` the faulting address and `ECAUSE` the vector number; the new program counter is the 64-bit word at `VBR + 8 × vector`. *(D, errata 36)*

**6.7.4** Entry sets the priority to 7 for every exception and every interrupt; the handler lowers it. *(D, errata 40)*

**6.7.5** There are eight interrupt priority levels; `SPL #n` sets the priority without touching the flags. *(D)*

**6.7.6** `MFSR` and `MTSR` read and write the system registers by number; `TLBI`, `TLBIA` and `TLBSYNC` invalidate translations (broadcast to other cores); `MTASID` and `MFASID` set the address-space tag; `ICINV` and `ICINVA` invalidate the instruction cache; `PROBER` and `PROBEW` test an address; `MFCPUID` identifies the processor. *(D)*

**6.7.7** `UA` in the status word guards user memory: with it clear, a kernel-mode data access to a user page faults; `STUA` sets it and `CLUA` clears it; entry clears it. *(D, errata 43)*

*Commentary.* The modes and exceptions are sections 6.1 to 6.3 and the multiprocessor instructions are chapter 7. **Precedent.** The PDP-11 pushed the program counter and status word on a stack and loaded new ones from a two-word vector; its trap vectors conventionally held priority 7. **Trade-offs.** Entering in registers is short and cannot fault, and costs the handler an explicit save; raising the priority on entry closes the window in which an interrupt could overwrite the saved state. **Improvements.** `PUSHX` and `POPX` save the pair in one instruction, and the user-memory guard turns a stray kernel pointer into a clean fault. **Benefits.** The kernel survey estimates system-call entry at four or five instructions against 45 to 70 on RISC kernels (a paper estimate, not a measurement). **Modern comparables.** AArch64 and RISC-V save the return address and status in registers on exception entry; x86 pushes five words; x86's `SMAP` with `STAC`/`CLAC`, AArch64's `PAN` and RISC-V's `SUM` are the user-memory guards. **Use.** `PROBER` and `PROBEW` replace the `nofault` idiom of V6 and V7; `ISYNC` follows a write to the page-table base or the vector base. **Impact.** *Kernel:* This is the kernel's whole instruction vocabulary: `MFSR`, `MTSR`, `TLBI`, `RTI`, `SPL`, `ISYNC`, the probes. *Compiler:* The compiler never emits them except through intrinsics. *Hardware:* The system group takes its sub-opcode from the register field, and the privilege check is one comparison on the current mode.

<!-- entries:6.7 -->
**The instruction entries for this section are in chapter 9, section 9.14:** each entry there is complete (syntax, encoding diagram, operation, flags, exceptions, status); this chapter gives the reasons, the history and the use.

| Entry | Mnemonics |
|---|---|
| [No operation and landing pad](09-isa.md#nop-no-operation-and-landing-pad) | `NOP`, `LPAD` |
| [Return from interrupt or exception](09-isa.md#rti-return-from-interrupt-or-exception) | `RTI`, `RTT` |
| [Return from subroutine](09-isa.md#ret-return-from-subroutine) | `RET` |
| [Halt the processor](09-isa.md#halt-halt-the-processor) | `HALT` |
| [Breakpoint](09-isa.md#bpt-breakpoint) | `BPT` |
| [Memory fence](09-isa.md#fence-memory-fence) | `FENCE` |
| [Wait for an event](09-isa.md#wfe-wait-for-an-event) | `WFE` |
| [Send an event](09-isa.md#sev-send-an-event) | `SEV` |
| [Invalidate all translations; wait for translation invalidations; invalidate the whole instruction cache](09-isa.md#tlba-invalidate-all-translations-wait-for-translation-invalidations-invalidate-the-whole-instruction-cache) | `TLBIA`, `TLBSYNC`, `ICINVA` |
| [Push and pop the exception state](09-isa.md#pushx-push-and-pop-the-exception-state) | `PUSHX`, `POPX` |
| [Instruction synchronisation](09-isa.md#isync-instruction-synchronisation) | `ISYNC` |
| [Hint](09-isa.md#hint-hint) | `HINT` |
| [Move from and to a system register](09-isa.md#mfsr-move-from-and-to-a-system-register) | `MFSR`, `MTSR` |
| [Move to and from the processor status word](09-isa.md#mtps-move-to-and-from-the-processor-status-word) | `MTPS`, `MFPS` |
| [Set the interrupt priority level](09-isa.md#spl-set-the-interrupt-priority-level) | `SPL` |
| [System call and trap](09-isa.md#trap-system-call-and-trap) | `TRAP`, `TRAPL` |
| [Invalidate a translation](09-isa.md#tlbi-invalidate-a-translation) | `TLBI` |
| [Move to and from the address-space identifier](09-isa.md#mtasid-move-to-and-from-the-address-space-identifier) | `MTASID`, `MFASID` |
| [Move to and from the direct pointer](09-isa.md#mtdp-move-to-and-from-the-direct-pointer) | `MTDP`, `MFDP` |
| [Move to a direct-mapping window](09-isa.md#mtdmw-move-to-a-direct-mapping-window) | `MTDMW` |
| [Read the processor identifier](09-isa.md#mfcpuid-read-the-processor-identifier) | `MFCPUID` |
| [Invalidate the instruction cache for an address](09-isa.md#icinv-invalidate-the-instruction-cache-for-an-address) | `ICINV` |
| [Probe an address for read or write access](09-isa.md#probe-probe-an-address-for-read-or-write-access) | `PROBER`, `PROBEW` |
<!-- /entries:6.7 -->

## 6.8 Faults, restart and memory management

**6.8.1** Faults fall in four categories: traps (the instruction completes), aborts (it is annulled and restarted), progress (a block operation stopped part-way, restarted from its registers) and machine checks (not restartable). *(D)*

**6.8.2** The register update of an auto-increment or auto-decrement mode is held until the instruction retires and discarded by an abort, so a handler never undoes anything. *(D)*

**6.8.3** A read of non-existent memory is a precise abort with cause `BUSFAULT`; a posted write that times out and an uncorrectable memory error are machine checks. *(D)*

**6.8.4** Virtual addresses are 39 bits, translated by three levels of nine bits over 4 KB pages to a 40-bit physical address. *(D)*

**6.8.5** A page-table entry carries the physical page number in place and read, write, execute and user permission bits; accessed and dirty bits are managed by software; one memory type per page selects cached, uncached, strongly ordered or weakly ordered. *(D, errata 36)*

**6.8.6** Two direct-mapping windows, `DMW0` and `DMW1`, are stored but not yet defined; `MMUCTL` bit 0 enables translation and is zero at reset, so every address is physical until the kernel turns it on. *(D, errata 36 and 44)*

*Commentary.* **Precedent.** The PDP-11 recorded its register side effects in `MMR1` and left the undo to software; the VAX needed resumable microstate and a status-word bit; the 68000 had no restart path. **Trade-offs.** Thirty-nine bits is 512 GB, what a three-level table indexes with nine bits per level; a fourth level would give 48 bits at the price of a longer walk on every TLB miss. Software-managed accessed and dirty bits cost one extra fault on first touch and one on first write per page, in exchange for a simpler walker (appendix B). **Improvements.** The one-memory-operand rule makes the undo buffer a single entry and row 3 of the fault matrix provably empty, so there is no journal and no undo protocol. **Benefits.** An FPGA walker is small, and a core with no speculation has no page-table side channels. **Modern comparables.** RISC-V's Sv39 has the same geometry; x86-64 and AArch64 have 48-bit spaces with four levels and hardware-managed accessed and dirty bits. **Use.** The memory type on a page lets a driver map a device register uncached and strongly ordered without a special instruction. **Impact.** *Kernel:* Precise faults and software-managed accessed and dirty bits make one small page-fault handler for first touch, first write and demand paging. *Compiler:* No scheduling restriction arises from faults, because the register update of an addressing mode is held until retirement. *Hardware:* A single-entry undo buffer, a read-only walker, and (on the FPGA) a four-way set-associative translation buffer rather than a content-addressable one.

## 6.9 Still open

The format of the direct-mapping windows `DMW0` and `DMW1` (stored but without effect; the translation-enable bit stays, errata 44), the use of supervisor mode, hardware breakpoints and watchdogs, performance counters, machine-check reporting beyond halting, feature and identification registers from register 13 up, and a TLB invalidate by address-space tag (appendix B).
