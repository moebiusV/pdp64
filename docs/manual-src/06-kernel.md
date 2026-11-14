# 6. The kernel: modes, exceptions and memory management

[← manual index](00-index.md)

**An operating system on the pdp64 sees a status word with a mode and a priority, an exception mechanism that writes only registers, and a page table of three, four or five levels whose accessed and dirty bits the kernel maintains in software.** The reader is taken to be a first-year computer-science student or a PDP-11 programmer who has read the Unix Version 6 or 7 kernel, and to know nothing that appeared after the 1970s. The chapter starts from that kernel (the status word, the vectors, `trap()`, the KT11 memory-management unit with its eight page registers per mode, `mfpi` and `mtpi`, swapping). Each later idea follows with the PDP-11 way first, the intermediate machines that changed it, and the pdp64 way with the reason. Pseudocode walks a system call, a page fault, a timer interrupt and a context switch. The design is System v1; the comparisons with other architectures are in [`pdp64-system-architecture.md`](../pdp64-system-architecture.md) (section 15) and [`pdp64-system-design.md`](../pdp64-system-design.md). A fact about an older or another machine that could not be checked on this computer is marked *unverified* and listed in section 6.14.

*How to read this chapter.* A term is defined where it first appears, as the technical word followed by a plain restatement. In the pictures a box is a piece of memory or a register and an arrow is an address stored in it. Code blocks are pseudocode (C-like, `#` starts a comment) unless the text says they are PDP-11 or pdp64 assembly. The PDP-11 code is quoted from the V7 and 2.11BSD kernels on this machine (section 6.14). The pdp64 code is **an illustration written for this chapter**, not part of the architecture (the first operating system is OpenBSD, 6.12.2). The decisions are the numbered statements.

## 6.1 What you already know: the kernel of a PDP-11

Take Unix Version 7 (or 2.11BSD, the same kernel grown up) on a PDP-11/45, 70 or 73. Six things about it carry the rest of the chapter.

**The status word and the modes.** The **processor status word** (PS, also called PSW: one 16-bit register holding the flags, the interrupt priority and the mode of the running program) sits at address 0177776. Bits 15-14 are the **current mode** (the privilege the program runs with: kernel, supervisor or user), bits 13-12 the **previous mode** (the mode running before the last trap), bits 7-5 the **priority** (the level at or below which interrupts are held back), bit 4 the **trace** bit (take a trap after every instruction) and bits 3-0 the flags N, Z, V and C. The 2.11BSD header `psl.h` says the same in C: `PSL_CURMOD` 0xc000, `PSL_PRVMOD` 0x3000, `PSL_IPL` 0xe0, `PSL_T` 0x10, the condition codes in 0xf. Each mode has its **own stack pointer** (R6 names a different register in each mode), so a trap arriving in user mode finds a kernel stack waiting. User mode may not execute `halt`, `reset`, `wait` or change the priority (*unverified*).

**Vectors in low memory.** A **trap** (the machine transferring control to the kernel because something happened) goes through a **vector**: two words at a fixed low address, the new program counter and the new PS. The hardware pushes the old PS and PC on the new mode's stack and loads the pair. This is the start of the V7 table, `conf/l.s` (the octal addresses are added; the file's first two words are a branch and a 4, the vectors follow):

```
        trap;  br7+0.           / 004  bus error
        trap;  br7+1.           / 010  illegal instruction
        trap;  br7+2.           / 014  bpt-trace trap
        trap;  br7+3.           / 020  iot trap
        trap;  br7+4.           / 024  power fail
        trap;  br7+5.           / 030  emulator trap
        start; br7+6.           / 034  system call (overlaid by 'trap')
        . = ZERO+60
        klin;  br4              / 060  console keyboard
        klou;  br4              / 064  console printer
        . = ZERO+100
        kwlp;  br6              / 100  line clock
```

The first word of each pair is the handler's address. The second is the new PS: `br7` is priority 7 (nothing may interrupt) plus a small number that the handler passes to `trap()` to say which trap it was. The device vectors carry the device's priority, 4 for the console and 6 for the clock. A handler ends with `rti` (return from interrupt: pop the PC and PS) or `rtt` (the same, but a pending trace trap is not taken at the first instruction).

**`trap()`.** Assembly code at the vector (`call` in the V7 file `mch_i.s`) saves the registers and calls one C function, `trap(dev, sp, r1, nps, r0, pc, ps)`; its arguments are, in the words of the V7 comment, "the words saved on the system stack by the hardware and software during the trap processing". A system call is one of these traps: the program executes `sys n` and `trap()` fetches that instruction back from user memory and uses its low six bits as an index (`callp = &sysent[fuiword((caddr_t)(a-1))&077]`).

**The memory-management unit.** A PDP-11 program uses 16-bit addresses (64 KB) while physical memory is wider: 18 bits (256 KB) on the Unibus machines, 22 bits on later ones (*unverified*, section 6.14). The **KT11** (the memory-management unit: the hardware between processor and memory that turns the program's addresses into memory addresses, a step called **translation**) has for each mode **eight pairs** of **page registers**: a **PAR** (page address register: where the segment starts in physical memory, in units of 64 bytes) and a **PDR** (page descriptor register: how long it is, up to 8 KB, and whether it may be read or written). The top three bits of a program's address pick a pair; the other thirteen are the offset in that 8 KB piece. 2.11BSD names the user's registers `UISA` and `UISD` (0177640 and 0177600) and the kernel's `KISA0` (0172340) and following. With **separate instruction and data space** (code and data each get their own 64 KB) there are sixteen pairs. `estabur()` fills a process's saved pairs from the sizes of its text, data and stack and fails with `ENOMEM` if they need more than eight segments; `sureg()` copies the saved pairs into the hardware registers when the process is switched in. Each pair describes **base and length** (a start and a size, the oldest form of memory protection), so a program's text, data and stack are each one **contiguous** run of memory, handed out by a first-fit allocator (`malloc.c`: "the core map unit is 64 bytes").

**Reaching the other space.** The kernel's address space is separate from the user's, so a kernel pointer to user memory means something else. `mfpi` and `mtpi` (move from and to the **previous** instruction space; `mfpd` and `mtpd` for data space) take the address from the kernel's registers but use the previous mode's page registers. `fubyte` and `subyte` are built from them, with a global named `nofault` that makes an error in the access return -1 instead of panicking.

**Swapping.** A process image was one block of memory. When memory ran short, `sched()` called `swapout()`, which wrote the whole image to the **swap device**, and `swapin()` read it back whole. No part of a program could be in memory without the rest.

**What carries over.** The pdp64 keeps three modes with a recognisable status word, a stack pointer per mode, vectors, `RTI`, a priority the kernel raises and lowers, a previous mode and an idle instruction. Eight things are new, each met where it first matters: entry stores state in registers instead of pushing it (6.3); exceptions are precise (6.4); control registers are reached by number (6.5); the eight page registers become a tree of page tables that the hardware walks (6.6, 6.7); a translation buffer caches the walk and must be kept honest (6.8); its entries carry an address-space number so a context switch need not empty it (6.8); the kernel half of the address space has its own table (6.9); and `R7` is an ordinary register (errata 100): the PC is not a register at all and the stack pointer is `R14`.

## 6.2 Modes and the status word

The three modes keep their PDP-11 values: kernel 0, supervisor 1, user 3. Loading the reserved value 2 into the status word is an illegal instruction. The fields moved down to make room for one new bit:

| | PDP-11 (`psl.h`) | pdp64 |
|---|---|---|
| flags (four bits) | 3-0 | 3-0 |
| trace | 4 | 4 |
| priority | 7-5 | 7-5 |
| current mode | 15-14 | 9-8 |
| previous mode | 13-12 | 11-10 |
| user-memory guard | none | 12 |

![The processor status word](figures/psw.svg)

The **user-memory guard** (a status bit that says whether the kernel may touch user memory; section 6.10) is the new bit. The **previous mode** has the same job as on the PDP-11: after a trap from user mode it says where the kernel came from, and the instructions that act for the previous mode (`PROBER` and `PROBEW`, 6.10) use it. A **privileged instruction** (one that only the kernel may execute, because it could break the protection between programs) executed outside kernel mode **aborts** (is cancelled before it changes anything, 6.4) with the privileged-instruction vector, as `halt` and `reset` did on the PDP-11.

**6.2.1** There are three modes, with the PDP-11's encoding: kernel 0, supervisor 1, user 3. The supervisor mode exists in the status word and in the banked registers, and no code uses it. *(D)*

**6.2.2** The status word holds the flags in bits 0 to 3, the trace bit in bit 4, the interrupt priority in bits 5 to 7, the current mode in bits 8 and 9, the previous mode in bits 10 and 11, and the user-access guard in bit 12; the other bits are zero. *(D)*

**6.2.3** `MTPS` in user mode writes only the flags; in kernel mode it writes every writable bit. `SPL #n` is kernel-only. *(D)*

**6.2.4** The stack pointer `R14` and the direct-page register `DP` each have one copy per mode; the mode selects which one an instruction names. *(D)*

**6.2.5** These instructions abort with the privileged-instruction vector outside kernel mode: `RTI`, `RTT`, `HALT`, `SPL`, `MTASID`, `MFASID`, `TLBI`, `TLBIA`, `TLBSYNC`, `MTDMW`, `MFSR`, `MTSR`, `PROBER`, `PROBEW`, `WFE`, `ISYNC`, `STUA`, `CLUA`, `PUSHX`, `POPX`. *(D)*

**6.2.6** These are not privileged: `MTDP` and `MFDP` (in user mode, the thread pointer), `ICINV` and `ICINVA` (a JIT needs them), `FENCE`, `SEV`, `HINT`, `TRAP`, `BPT`, `NOP`, and `MTPS` and `MFPS` with the restriction above. *(D)*

`DP` is new to a PDP-11 reader. It is the **direct-page register** (a base register that makes one region addressable with a short displacement, descended from the 6502's zero page). The kernel's copy points to the structure of the core it is running on (the **per-CPU pointer**: which core am I, and where is its private data); a user program's copy points to its thread's private data, so a thread-local variable is one `MOVQ d(DP), Rd`.

*Lineage.* **PDP-11:** three modes, a stack pointer per mode, priority and mode fields in the status word; V7 used kernel and user, and 2.11BSD runs its network code in supervisor mode (`trap()` tests `SUPVMODE(ps)`, checked). **Between:** x86 has four rings of which two are used; AArch64 has exception levels 0 to 3; RISC-V has user, supervisor and machine modes (all *unverified*). Each later design kept a privilege ladder and a banked stack pointer. **pdp64:** the PDP-11's three modes and its stack-pointer banking, so entry from user mode needs no stack switch code, plus a banked `DP`. The third mode costs a third copy of two registers and no logic the kernel uses.

*Impact.* *Kernel:* a trap from user mode needs no stack switch, and the banked `DP` is a per-CPU pointer in kernel mode and a thread pointer in user mode. *Hardware:* three copies of `R14` and `DP`, selected by the mode, and one mode comparison at the decode of a privileged instruction. `PROBER` and `PROBEW` do the work of the `nofault` idiom of V6 and V7 (6.4).

Details pending: what, if anything, will use supervisor mode ([J.6.9](appendix-j-open.md#j69)).

## 6.3 Exceptions, interrupts and traps: how the machine enters the kernel

The PDP-11 used one word, "trap", for three different events, and the pdp64 names them apart. An **exception** is the machine stopping an instruction because it cannot carry it out (a page that is not in memory, an illegal instruction, a division by zero); it belongs to the instruction. An **interrupt** is a device asking for attention; it belongs to no instruction and is taken between two of them. A **trap**, in the narrow sense used here, is a deliberate entry by an instruction that succeeds (`TRAP #n`, the system call). All three enter the kernel the same way.

**The PDP-11's way.** The hardware read the new PC and PS from the vector, pushed the old pair on the kernel stack and ran the handler. This is **entry through memory**: two words are written to the stack before one handler instruction runs.

**The pdp64's way.** Entry writes only registers and then reads one word. Four **system registers** (registers outside the general ones, reached with `MFSR` and `MTSR`, 6.5) receive the facts: `EPC` (exception program counter: where to resume), `EPSW` (the old status word), `EVA` (exception virtual address: the address that caused a fault) and `ECAUSE` (what happened: the vector number). The new status word is made, and the new program counter is read from the **vector table**: an array of 512 entries of 8 bytes, 4096 bytes in all, whose base is in the register `VBR` (vector base register). `kind` below is one of the families of 6.4:

```
enter(vector, kind):
    EPC    = (kind is abort or progress) ? address of this instruction
                                         : address of the next instruction
    EPSW   = PSW
    EVA    = (kind is abort) ? the faulting address : 0
    ECAUSE = vector
    PSW.previous_mode = PSW.current_mode
    PSW.current_mode  = kernel
    PSW.priority      = 7
    PSW.trace = 0 ; PSW.flags = 0 ; PSW.guard = 0         # the guard: section 6.10
    PC = load64_physical(VBR + 8 * vector)                # a bus error here is a machine check
```

![Exception entry and the vector table](figures/kern-exception.svg)

Three differences from the PDP-11 matter to a kernel writer. Entry **cannot fault**: writing registers cannot meet a missing page, as a push on a kernel stack could. Entry **leaves the saving to the handler**: the hardware pushes nothing, so a handler that may be interrupted first saves `EPC` and `EPSW` (one instruction, `PUSHX`), and one that cannot be interrupted need not save them. Entry is **the same for every cause**: V7's trap vectors say `br7` and its device vectors `br4` and `br6`, each vector choosing its own priority, while the pdp64 always enters at priority 7 and the handler lowers it. A second exception before the handler has saved `EPC` and `EPSW` would overwrite them. The first instructions of every handler, and the memory they touch, therefore must not fault, which is why the kernel's text and stacks are in pages every address space shares or in a direct-mapping window (6.9). (That consequence is this chapter's reading; the architecture document states a related rule, that the entry code and kernel stack are pinned until the save is done.)

**The table.** `ECAUSE` receives the vector number, so one handler can serve several vectors and tell them apart. Vectors 0 to 31 are for the processor, 32 to 63 for interrupts, 64 to 255 are reserved and 256 to 511 are one per `TRAP` number. In V7 every `sys n` shared the single vector at 034 and the number was fetched from the instruction.

**6.3.1** Entry to an exception or an interrupt writes only registers: `EPC` receives the address of the faulting instruction (for an abort or a progress exception) or of the next instruction (for a trap or an interrupt), `EPSW` the old status word, `EVA` the faulting address (zero except for aborts), `ECAUSE` the vector number. *(D)*

**6.3.2** The new status word has the current mode kernel, the previous mode the old current mode, priority 7, and the trace bit and the flags cleared. *(D)*

**6.3.3** The new program counter is the 64-bit word at the physical address `VBR + 8 × vector`; a bus error on that fetch is a machine check that halts. *(D)*

**6.3.4** The hardware pushes nothing. A handler that can be interrupted saves `EPC` and `EPSW` with `PUSHX`, lowers the priority with `SPL`, and before returning restores them with `POPX` and executes `RTI`. *(D)*

**6.3.5** `RTI` loads the program counter from `EPC` and the status word from `EPSW`; `RTT` does the same and sets the trace bit after the return. *(D)*

**6.3.6** The vector table has 512 entries and `ECAUSE` equals the vector number. *(D)*

| Vectors | Meaning |
|---|---|
| 0 | reset |
| 1 | machine check |
| 2, 3, 4, 5 | illegal instruction, privileged instruction, misaligned access, non-canonical address |
| 6, 7, 8 | instruction, load and store page fault |
| 9, 10, 11 | protection violation on instruction, load and store |
| 12, 13 | divide by zero, bus fault |
| 14, 15 | landing-pad violation, breakpoint |
| 16 | check (`TRAPCC`; `ADDV`, `SUBV` and `MULV` on overflow) |
| 17 to 31 | reserved |
| 32 to 63 | interrupts (in the virt machine, 32 timer, 33 console input, 34 console output) |
| 64 to 255 | reserved (device interrupts are message-signalled, section 5.9) |
| 256 + n | `TRAP #n` and `TRAPL #n`, n from 0 to 255 |

**6.3.7** There are eight interrupt priority levels; the processor takes an interrupt between instructions when its level is greater than the priority in the status word; the timer is at level 6 and the console at level 4. *(D)*

The two levels are the PDP-11's: V7 vectors the line clock at priority 6 and the console at 4 (`l.s`, checked above). A **message-signalled interrupt** is a device raising an interrupt by writing a word to a memory address, so that no interrupt wire is needed (section 2.6). Vectors 64 to 255 are reserved for it.

Details pending: how such a write becomes a vector number, and which core receives it ([J.6.3](appendix-j-open.md#j63)).

*Lineage.* **PDP-11:** push PC and PS on the kernel stack, load a new pair from the vector; trap vectors conventionally held priority 7 (V7 `l.s`: every trap vector is `br7+code`). **Between:** the VAX pushed the program counter and the processor status longword, and raised the priority to the interrupt's level for an interrupt but not for an exception (*unverified*); x86 pushes five words on the stack (*unverified*); AArch64 and RISC-V latch the return address and status in registers (*unverified*); each of the three masks interrupts on entry (*unverified*). **pdp64:** the register form, so entry cannot fault and costs no memory write; priority 7 is fixed on entry so that no interrupt can overwrite the saved pair before the handler stores it. The kernel survey estimates a system-call entry at four or five instructions on paper, against 45 to 70 on the RISC kernels it examined; it is a paper estimate, not a measurement. Handlers written in C need a short assembler stub to save and restore registers.

*Impact.* *Kernel:* priority 7 on entry removes the code that would otherwise guard the saved state, and `PUSHX` and `POPX` make the save and restore one instruction each. *Hardware:* entry writes registers only, so it cannot fault, and the vector fetch is one 64-bit read.

## 6.4 Faults and restart: what "precise" means

When an instruction cannot finish (its page is absent, say), the machine must stop it, tell the kernel and, once the kernel has removed the cause, **restart** it (run it again from the start). Whether that works depends on what the instruction did before it stopped.

**On the PDP-11** it did not always work. `cmp -(sp),-(sp)` changes a register (`sp` goes down by 2, twice) while it works out its operands, and may then fault on the second operand; rerun as it stands, it leaves `sp` 4 too low. The hardware therefore kept a small journal of the register changes (the register `MMR1`, on the machines that had one), and the kernel's `backup()` read it and undid them before the restart. The 2.11BSD `trap()` says that on the 11/40, which had no such register, "the routine backup/mch.s may fail", and then so may the automatic growth of the user stack, which relies on restarting. Floating-point errors were worse: V7 and 2.11BSD both say "the floating exception is an imprecise trap", meaning that by the time it was taken the processor had run on, and the saved PC no longer named the faulting instruction.

**Between.** The VAX saved resumable microstate and a status-word bit for instructions interrupted half way; the 68000 had no restart path for a bus error in its first form (both *unverified*, repository text). The next step was to make exceptions precise by design and let the compiler and hardware avoid the cases that were not.

**On the pdp64** every exception that belongs to an instruction is **precise**. A **precise exception** (one taken so that the machine looks as if it ran one instruction at a time, in order: every earlier instruction has completed, and the faulting instruction and every later one have changed nothing) lets the kernel treat a page fault as a subroutine call the program never noticed. It matters here because the pdp64 is meant to be built both as a simple **in-order core** (one that runs instructions one after the other, as the PDP-11 did) and as an **out-of-order core** (one that looks ahead, starts later instructions whose inputs are ready before earlier ones have finished, and holds the results in a buffer until the earlier instructions are known not to have faulted; errata 68). In the second kind the faulting instruction is one of dozens in flight, some already half done; the machine must discard their results and report the fault as if none had started. The architecture makes this possible without a journal. An instruction has at most one memory operand, and the register update of an auto-increment or auto-decrement mode is held until the instruction **retires** (is certain to complete) and thrown away if it aborts (6.4.2; `docs/pdp64-isa.md` section 7.2 has the argument and 7.3 the table of every reference that can fault). The author's remark on this (2026-11-09): "pdp64 specifically designs the instructions for minimal uops, so we have minimal restart/recovery code needed, no?".

**Four families.** The kernel sees separately the cases that the PDP-11 mixed together:

| Family | The instruction | `EPC` on entry | Restartable |
|---|---|---|---|
| **trap** | completes | the next instruction | not applicable |
| **abort** | annulled, as if it had not begun | the faulting instruction | yes, by `RTI` |
| **progress** | partly done, the progress is in registers | the faulting instruction | yes, by `RTI` |
| **machine check** | indeterminate | best effort | no |

A **progress** exception belongs to the block instructions (`MCPY` and the others of the `MBLK` group, section 9.7). A copy of a megabyte may take 256 page faults; the instruction keeps its position in its own registers, so `RTI` re-executes it and it carries on from where it stopped. A **machine check** descends from the PDP-11's bus error at vector 004: something happened that the machine cannot repair or locate exactly (an uncorrectable memory error, a posted write that timed out), and the kernel can only stop the process or the machine. A **posted write** (a store the processor has handed on and no longer waits for) is the reason: when the bus reports the failure the instruction retired long ago.

**6.4.1** Faults fall in four categories: traps (the instruction completes), aborts (it is annulled and restarted), progress (a block operation stopped part-way, restarted from its registers) and machine checks (not restartable). *(D)*

**6.4.2** The register update of an auto-increment or auto-decrement mode is held until the instruction retires and discarded by an abort, so a handler never undoes anything. *(D)*

**6.4.3** A read of non-existent memory is a precise abort with cause `BUSFAULT`; a posted write that times out and an uncorrectable memory error are machine checks. *(D)*

**6.4.4** A deferred load (`MOVQ.D` and the six other `.D` words) does not fault at the load: a faulting load leaves a poison mark on its destination register, and the fault is taken at the first instruction that writes the flags from a poisoned source. The kernel decides the fault of a deferred load, and the kernel dispatcher, not the hardware, tests the argument registers for poison. *(D)* Details to be determined: the form of the poison bit, and the combination `.UD` of the two qualifiers. Open: whether an input-taint lane of the Perl kind and a tag for each word of memory are added beside the poison, secret and valid-pointer marks ([J.9.14](appendix-j-open.md#j914)).


Three consequences. The undo buffer is a single entry, and row 3 of the fault matrix (an operand write) can never fault, so no journal or undo protocol exists. One small page-fault handler serves first touch, first write and demand paging (6.11), and there is no `backup()` and no `MMR1`. The `nofault` idiom of V6 and V7 `trap.c` (set the global, do the probe, `longjmp` out of the handler instead of panicking) remains the pattern for probing hardware, though `PROBER` and `PROBEW` cover address validation. A read of a configuration position that holds no device is not a fault at all (it returns all ones, 2.4.7), so a bus scan does not take a `BUSFAULT` for every empty slot. The pdp64 makes floating-point exceptions flags that never trap, so they need no imprecise case; whether current architectures keep exceptions precise for page faults and leave some floating-point and bus errors imprecise is *unverified*.

*Impact.* The price of precision is in the implementation and not in the kernel: an out-of-order core needs the buffer that holds its results until retirement. *Kernel:* one small page-fault handler for first touch, first write and demand paging; no `backup()` and no `MMR1`. *Compiler:* no scheduling restriction arises from faults, because the register update of an addressing mode is held until retirement. *Hardware:* a single-entry undo buffer, a result buffer for the out-of-order implementation and a retirement stage that decides.

## 6.5 System registers: `MFSR` and `MTSR`

The PDP-11 reached its control registers by address. The KT11's page registers, the status word and the other control and status registers sit in the top 8 KB of the address space, the I/O page (`KISA6` at 0172354, `UISD` at 0177600, the PS at 0177776), and the kernel used ordinary `mov` instructions on them. The pdp64 cannot, because its address space is translated (6.6): a load or store to a control register would itself be translated, and an instruction that changes the translation would change the mapping of the access that reads it. Control registers are **system registers**, numbered 0 to 255, read and written by `MFSR Rd, name` (move from system register) and `MTSR name, Rs` (move to system register). Both are privileged (6.2.5).

**6.5.1** The system registers are reached by `MFSR` and `MTSR` with an 8-bit register number. *(D)*

| Number | Register | Meaning |
|---|---|---|
| 0 | `PTBR` | physical address of the level-2 page table |
| 1 | `EPC` | exception program counter |
| 2 | `EVA` | exception virtual address |
| 3 | `ECAUSE` | exception cause (the vector number) |
| 4, 5 | `DMW0`, `DMW1` | direct-mapping windows (stored; no effect on translation) |
| 6, 7 | `USP`, `SSP` | the user and supervisor stack pointers |
| 8 | `EPSW` | exception status word |
| 9 | `VBR` | vector base register |
| 10 | `MMUCTL` | memory-management control (bit 0 enables translation) |
| 11 | `ASID` | address-space identifier |
| 12 | `CPUID` | the core number (read-only) |
| 13 and up | | reserved |

`EVA` and `ECAUSE` are read only, as is `CPUID`; the rest read and write. `PTBR` is called a level-2 table for the three-level form; it holds the top table of whichever number of levels the machine has (6.6). `USP` is the user's stack pointer, needed because in kernel mode `R14` is the kernel's; it replaces the PDP-11 idiom `mfpd sp`, and the kernel reads and writes it to build a signal frame, copy a process or switch context. `SSP` is the supervisor's and nothing uses it.

**6.5.2** A write to `PTBR`, `ASID` or `MMUCTL`, or an `ICINV`, is guaranteed to take effect only after the next `ISYNC`. *(D)*

`ISYNC` (instruction synchronisation) makes this safe on a machine with more than one instruction in progress. A pipelined or out-of-order core has already fetched and started the instructions after the `MTSR` under the old translation; `ISYNC` waits for every earlier instruction to finish, discards everything fetched after it and fetches again under the new rules. The PDP-11 needed no such instruction, because an instruction was fetched after the previous one had finished.

*Lineage.* **PDP-11:** control registers at fixed high addresses, reached with ordinary moves. **Between:** the VAX had `MTPR` and `MFPR` with an internal-register number; AArch64 has `MRS` and `MSR`, RISC-V `CSRR` and `CSRW`, PowerPC `MFSPR` and `MTSPR`. **pdp64:** the VAX's numbered form. The pair costs two opcodes; a separate instruction per register would spend opcode space with every register. A new register is a number and not an instruction, and the 243 unused numbers cost nothing until used. The kernel survey found privileged-register access to be 48% of all the compiler-invisible instructions in four kernels; the compiler reaches them through an intrinsic with a constant number. *Hardware:* a control-register file addressed by an 8-bit number, with a read-only decode for the identification registers.

## 6.6 From segments to pages: virtual memory

**Two kinds of address.** A **virtual address** is the number a program uses; a **physical address** is the number the memory chips answer to. The PDP-11 had both, 16 bits against 18 or 22, and the KT11 translated one into the other. A pdp64 program has 64-bit pointers of which only some bits count (below), and the physical address is 40 to 64 bits wide (errata 102): 40 bits is one terabyte, and the maximum, 2^64, is sixteen exabytes.

**What the KT11 cost.** The figure puts the PDP-11 scheme (left) beside the pdp64's (right). On the left, the three top bits of a 16-bit address pick one of eight page registers, which says where an 8 KB piece starts and how long it is. Nothing is looked up, because the whole map of the running program is in the eight pairs. Three costs follow. A process had at most 64 KB (eight pieces of 8 KB; 128 KB with separate instruction and data space), and `estabur()` returns `ENOMEM` for a program that needs a ninth segment. Each piece was one **contiguous** block of physical memory, so memory fragmented, and the allocator either found a hole big enough or the kernel swapped something out to make one. And with only eight registers there was no way to leave a hole in the middle of a program unmapped, to share half a segment, to start a program before all of it was in memory, or to learn which part had been used.

![The KT11 beside the pdp64 walk](figures/kern-kt11-walk.svg)

**Between: pages.** The VAX had the remedy that most machines since have copied (*unverified*, repository text): cut both address spaces into equal pieces and let any virtual piece sit in any physical piece. The virtual piece is a **page** and the physical piece a **frame** (the same size, here 4 KB). A virtual address is a **page number** and an **offset** within the page; translation replaces the page number by a frame number and keeps the offset. The map from page numbers to frame numbers is a **page table**: an array indexed by page number, each element (a **page-table entry**, PTE, 6.7) saying where the frame is, who may touch it and whether it is present. With pages a program's memory need not be contiguous; a page can be absent (fetched from disk when touched, which is **demand paging**) or shared by two programs; and the kernel can tell which pages are in use.

**The tree.** One flat table is too large. A 39-bit virtual address with 4 KB pages has 2^27 pages (134 million); at 8 bytes an entry the table is 1 GB for every process, nearly all of it empty. Instead the table is a **tree**. Each table is exactly one page, 4096/8 = 512 entries, so nine bits of index, and some of its entries point to tables of the next level rather than to frames. The address is cut into 9-bit fields, one per level, over a 12-bit offset: with **three levels** it has 9 + 9 + 9 + 12 = 39 bits. Translation is a **walk**:

![The tree of page tables](figures/kern-pagetree.svg)

```
translate(va, access, mode):                        # three, four or five levels
    if va is not canonical:  fault NONCANONICAL     # bits above the top one must equal it
    table = PTBR                                    # physical address of the top table
    for level = LEVELS-1 down to 0:
        index = (va >> (12 + 9*level)) & 511
        pte   = load64_physical(table + 8*index)    # one memory read per level
        if not pte.V or pte has a reserved bit set: fault PAGE_FAULT
        if pte.R or pte.W or pte.X:                 # a leaf: the walk ends here
            break
        if level == 0:       fault PAGE_FAULT       # a pointer where nothing is left to point to
        table = pte.PPN << 12                       # follow the pointer to the next table
    check the leaf (6.7): permissions for this mode, accessed and dirty (6.8)
    size  = 4 KB << (9*level)                       # level 0: 4 KB; level 1: 2 MB; level 2: 1 GB
    return (pte.PPN << 12) | (va & (size - 1))
```

The pseudocode renders statements 6.6.1, 6.7.1 and 6.7.2; a leaf not aligned to its size is a page fault. The cost is one memory read per level, three to five. A program that touches a few megabytes has a handful of tables, and the **sparse** address space (most of the 512 GB unused) costs nothing, because an entry that is not valid has no table under it. A leaf found above level 0 maps a larger piece, 2 MB at level 1 and 1 GB at level 2: a **large page** (many times the basic size, mapped by one entry; used for the kernel's own mapping and for big buffers). Its frame address must be aligned to its size.

**Three, four or five.** The author decided (errata 96) that the walk may have three levels (39 virtual bits: what System v1 specifies), four (48 bits) or five (57 bits), with the number discoverable at run time. Each level adds nine bits and one more memory read per miss. His own referent was the Loongson five-level table ("what other parts of the design are effected if we have 5 level tlb like loongson arch?"). A **canonical** address has all bits above the top virtual bit equal to that bit, so a 39-bit machine accepts a 64-bit pointer only if bits 63 to 38 are all the same. This rules out storing a tag in the unused high bits, which would stop working on a machine with more levels.

**6.6.1** Virtual addresses are translated by three, four or five levels of nine bits over 4 KB pages, which gives virtual addresses of 39, 48 or 57 bits. With three levels, address bits 38 to 30 index level 2, 29 to 21 level 1 and 20 to 12 level 0; with four, bits 47 to 39 index level 3 above them; with five, bits 56 to 48 index level 4 above that; `PTBR` holds the physical address of the table of the top level. *(D)*

The number of levels is readable by software at runtime, so a kernel adapts to the implementation without a build option (errata 96); so is the physical address width. Details pending: the register or field that reports them ([J.6.1](appendix-j-open.md#j61)).

**6.6.2** Virtual addresses are 39, 48 or 57 bits, translated by three, four or five levels of nine bits over 4 KB pages (6.6.1) to a physical address of 40 to 64 bits (section 2.3.5). *(D)*

*Lineage.* **PDP-11:** eight base-and-length segments per mode, no tables. **Between:** the VAX had a linear page table per region with a hardware modify bit and no reference bit (*unverified*, repository text); RISC-V's Sv39, Sv48 and Sv57 are the three-, four- and five-level forms with nine bits per level (`satp` modes 8, 9 and 10, checked in the QEMU source); x86-64 uses four levels, and five on newer parts through `LA57`; LoongArch describes the width of each level in a register (`PWCL`, checked). **pdp64:** the Sv39 geometry, with the level count left to the implementation. A leaf at any level makes large pages free for the kernel's own mapping, and the walker only reads, so it is a small state machine. Position-independent code uses PC-relative addressing, and pointers must not carry tags in the high bits.

*Impact.* Thirty-nine bits is 512 GB, what three levels index with nine bits each; each further level adds nine bits (48, then 57) at the price of one more read on every miss, and the kernel chooses what the implementation offers. *Kernel:* the same walk code serves three, four and five levels, with the level count read at run time. *Hardware:* one read per level, three to five.

## 6.7 The page-table entry

Each entry is one 64-bit word. The diagram shows every bit.

![The page-table entry](figures/kern-pte.svg)

An entry has two shapes. A **leaf** maps: at least one of `R`, `W`, `X` is set, and the physical page number is the frame the page lives in. A **pointer** says that the next table is here: `V` is set, `R`, `W` and `X` are all clear, and the page number is the next table's. When **valid** `V` is zero nothing is mapped, and the other 63 bits are the kernel's to use, for example for the place on the swap device where the page now lives.

**Permissions and modes.** `R`, `W` and `X` allow reads, writes and instruction fetches. `U` says user mode may use the page, and user mode needs it. Kernel mode may read and write a user page, which is what lets it copy to and from user memory directly (6.10), but may never **execute** one, so a kernel tricked into jumping to user memory takes a fault. `W` without `R` is not a valid combination and is a fault. `G` (global) marks a translation the hardware keeps whatever the address space (6.8). Any undefined bit must be zero in a valid entry, and a set reserved bit is a page fault, which lets the format grow and catches a wild value written by the kernel.

**Memory types.** Each page says how the memory system may treat accesses to it, in the field `MT`. **Normal cached** (0) is ordinary memory, which the **caches** (small fast memories near the processor holding copies of recently used memory) may keep. **Normal uncached** (1) must not be cached, as for a frame buffer that the display hardware reads and the processor writes. The two device types are for device registers: **device strongly ordered** (2) sends every access to the device in exactly the order written, one at a time and never combined, and **device weakly ordered** (3) lets the machine combine or reorder accesses, for device memory where only the final result matters. The architecture text gives the four names and numbers; the glosses of the last two are the usual meanings and are *unverified*. The PDP-11 had no memory type: everything at the top of the address space was a device. The pdp64 has **no address bit that says "device"** (errata 97). The memory type is what a driver sets when it maps a device, and a device window can be anywhere in the physical address space except the first few pages (errata 102, section 2.3.5).

**6.7.1** A page-table entry is 64 bits: `V` (valid) in bit 0, `R`, `W`, `X`, `U` and `G` (global) in bits 1 to 5, `A` (accessed) and `D` (dirty) in bits 6 and 7, the memory type `MT` in bits 8 and 9, and, for a 40-bit physical address, the physical page number in bits 12 to 39, in place; all other bits are zero, and a set reserved bit is a page fault. *(D)*

The physical address is 40 to 64 bits (6.6.2), so the entry has a form for a physical address wider than 40 bits. Details pending: that format ([J.6.2](appendix-j-open.md#j62)).

**6.7.2** A non-leaf entry has `V` set and `R`, `W` and `X` clear and points to the next table; a leaf at level 2 maps 1 GB, at level 1 maps 2 MB and at level 0 maps 4 KB, and where the levels exist a leaf at level 3 maps 512 GB and at level 4 maps 256 TB. *(D)*

**6.7.3** A user-mode access needs `U`; kernel mode may read and write user pages but may not execute them; `W` without `R` is reserved. *(D)*

**6.7.4** The memory type of a page is one of normal cached, normal uncached, device strongly ordered and device weakly ordered. *(D)*

**6.7.5** A page-table entry carries the physical page number in place and read, write, execute and user permission bits; accessed and dirty bits are managed by software; one memory type per page selects cached, uncached, strongly ordered or weakly ordered. *(D)*

*Lineage.* **PDP-11:** a PDR with length and access bits, no per-page type. **Between:** the VAX entry held a hardware modify bit and a four-bit protection field (*unverified*); RISC-V's low eight bits are `V R W X U G A D` in the same places as here (checked in `cpu_bits.h`); ARM's memory types and LoongArch's cache attributes are the source of the four types, reduced to what a machine of this size can tell apart (`docs/pdp64-isa.md` section 8.2). **pdp64:** one entry shape at every level keeps the walker simple. A memory type per page, not per access, means the code that writes a frame buffer needs no cooperation to be uncached, and a driver maps a device register uncached and strongly ordered without a special instruction.

*Impact.* One entry shape at every level makes the walker simple, and a leaf that is not aligned to its size is a fault, which costs a check and saves the walker from reasoning about partial frames. The physical page number is in place, so no shifting. *Kernel:* the entry is built and read with shifts and masks that are the same for every level, and leaves at any level let the kernel map itself with 1 GB pages. *Hardware:* a translation-buffer entry holds a page number as wide as the physical address, 28 bits at 40.

## 6.8 Accessed, dirty, the translation buffer and address-space numbers

**Accessed and dirty.** A kernel that runs programs larger than memory must choose pages to throw out. It needs two facts: whether a page has been used lately (**accessed**, `A`) and whether it has been written since it was brought in (**dirty**, `D`: a dirty page must be written to disk before its frame is reused, a clean one can simply be dropped). On the VAX the hardware set a modify bit and the kernel emulated the reference bit (*unverified*, repository text). Many later machines, x86-64 and AArch64 among them (*unverified*), have the **walker** (the part of the memory-management hardware that reads the tables) set both bits itself by writing the page-table entry. The pdp64's walker **never writes a page table**. An access to a page with `A` clear, or a write to a page with `D` clear, takes the page fault of its kind; the kernel sets the bit and runs the instruction again. These are **software-managed** accessed and dirty bits. The cost is one extra fault the first time each page is touched and one the first time it is written; precise exceptions (6.4) make that fault cheap, and the walker stays a small read-only state machine.

**6.8.1** The accessed and dirty bits are managed by software: an access to a page with `A` clear, or a write to a page with `D` clear, raises the page fault of its kind and the kernel sets the bit; the hardware walker never writes a page table. *(D)*

**The translation buffer.** The walk costs a memory read per level, three to five reads for every load, store and instruction fetch, which is unaffordable. Every machine with a walk therefore has a **translation buffer** (TLB, translation lookaside buffer: a small, very fast memory in the processor that keeps recent translations, so that a repeated access to the same page needs no walk). It is a **cache** (a small copy of a larger store, kept for speed) of translations. The PDP-11 had none: its eight page registers were the translation, loaded whole at each process switch, and there was no table to be slow.

![The translation buffer](figures/kern-tlb.svg)

An access looks in the buffer first, by virtual page number and address-space number (below). On a match (a **hit**) the physical page and permissions come out and the access proceeds with no memory read for the translation. Otherwise (a **miss**) the walker reads the tables; if the walk ends in a valid leaf with the right permissions and the right `A` and `D` it **fills** the buffer and the access is retried, and if not the access takes the page fault of 6.3. A miss costs one read per level; a program that touches no more pages than the buffer holds pays only for its first touches. The size and organisation are the implementation's choice (a **set-associative** buffer lets an entry live in any of a few places chosen by the low bits of the page number, which is cheaper than one that can put an entry anywhere). A buffer entry holds a page number as wide as the physical address, 28 bits at 40.

**Keeping it honest.** The buffer holds copies. When the kernel changes a page-table entry it must see that no stale copy remains, or a page it has unmapped or made read-only would still be reachable. An **invalidate** (removing entries from the buffer; "flush" in the older word) is `TLBI rN`, which drops the translation of the page containing the address in `rN` for the current address space and the global entries, or `TLBIA`, which drops everything. Each core has its own buffer, so the invalidate must reach all of them. On the pdp64 both instructions are **broadcast** (sent to every core by the hardware) and `TLBSYNC` waits until every core has finished, so the kernel knows nobody holds the old translation. Other architectures leave this to software, which sends an inter-processor interrupt to every other core and waits for the answers (a **shootdown**); the pain-points report (`docs/kernel-pain-points.md`) counts the IPI deadlock cases among the costs. Unmapping a page is then three lines, as chapter 7 says (7.12.2):

```
unmap_page(space, va):
    pte_of(space, va) = 0           # change the entry in memory first
    TLBI va                         # drop the old translation, on every core
    TLBSYNC                         # wait until every core has done so
    # now the frame may be reused
```

**6.8.2** Translation is off at reset (`MMUCTL` is zero and every address is physical) and is enabled by bit 0 of `MMUCTL`; the `ASID` selects non-global entries. *(D)*

**6.8.3** `TLBI rN` invalidates the translation of the page containing the address in `rN` for the current address space and the global entries; `TLBIA` invalidates all; both broadcast to every core and `TLBSYNC` waits for the broadcast to finish. *(D)*

**Address-space numbers.** A process switch changes the page tables. If the buffer cannot tell which process an entry belongs to, the old process's entries would answer for the new one, so the whole buffer must be emptied at every switch and the new process starts with all misses. On the PDP-11 the corresponding cost was `sureg()` writing the new process's eight (or sixteen) pairs into the page registers: sixteen (or thirty-two) register writes with nothing to flush. For tables walked from memory the cost is worse, because the emptied buffer refills one miss at a time. The remedy is to **tag** every buffer entry with the number of the address space it came from, the **address-space identifier** (ASID, 16 bits on the pdp64, set with `MTASID`). An entry matches only if its tag equals the current ASID or it is **global** (`G` set, so it answers in every address space, as the kernel's own pages do). A switch is then a write to `PTBR` and to `ASID` and an `ISYNC` (6.5.2): the old process's entries stay in the buffer, harmless, and answer again if that process runs soon. The whole switch is pictured in 6.11. Open: whether a write to `PTBR`, `ASID` or `MMUCTL` flushes the buffer, as the entry of `MFSR` in chapter 9 says, which would defeat the purpose of the tags ([J.6.8](appendix-j-open.md#j68)).

There are 65,536 numbers. When they run out the kernel starts again: it allocates in order, and when the counter wraps it invalidates everything (`TLBIA`) and starts a new **generation**, so that a process holding a number from before is given a fresh one when it next runs. The policy is the kernel's. The architecture has no invalidate by ASID.

*Lineage.* **PDP-11:** no buffer, no tags; `sureg()` rewrote the registers at every switch. **Between:** the VAX emulated reference bits in software under 4.3BSD (*unverified*); MIPS refills its translation buffer in software (*unverified*); x86 added a process-context tag late (the `PCIDE` bit of `CR4`, checked in the QEMU source; its width is *unverified*); RISC-V's `satp` carries a 16-bit address-space number (`SATP64_ASID`, checked) and software flushes other cores' buffers; AArch64 has a broadcast invalidate (*unverified*). The ISA text takes the ASID and the `G` bit from the Commodore 128's memory-management unit, which had four sets of map registers selected by one store and a common region that no map set could hide (`docs/pdp64-isa.md` section 8.1). **pdp64:** a 16-bit tag and a global bit; broadcast invalidates, so the kernel has no shootdown code; a walker that only reads. A core with no speculation has no page-table side channels, which is one reason for the small walker.

*Impact.* Software-managed bits cost one extra fault on the first touch of each page and one on the first write. A walker that never writes cannot damage a table. *Kernel:* the handler sets the accessed and dirty bits; `TLBI` broadcasts, so there is no shootdown code; a context switch writes two registers. *Hardware:* the walker only reads; each buffer entry carries an ASID tag and a global bit, compared on lookup.

## 6.9 Splitting the space and the layout of an address space

**One space or two.** On the PDP-11 the kernel had its own address space, with its own eight page registers, and the user could not see it. A kernel on a later machine usually sits in the upper part of every process's own address space, so it can reach the process's memory directly, and the permission bits keep the user out. That arrangement has a hole. A processor that **speculates** (runs instructions ahead before it knows they are allowed, discarding the results if they were not) could on some designs read kernel memory before the permission check caught up, and leave a trace in the caches that a user program could measure. This is the flaw class made public in January 2018 as Meltdown (`docs/hardware-vulnerabilities.md`, section 3.2: CVE-2017-5754, a permission check performed late with data forwarded early). The repository gives it as the reason for the split below: `docs/kernel-pain-points.md`, row 1, "Kernel mapped in every user address space; after Meltdown the page tables had to be split". The pdp64's answer is that **the user does not walk the kernel's tables at all**.

**6.9.1** The translation is split by the top bit of the virtual address (bit 38 with three levels, 47 with four, 56 with five): clear selects the lower half, translated from the table at `PTBR` (one per address space), and set selects the upper half, translated from the table at the system register `KTBR` (one for the whole system, the kernel's). In user mode the upper half is never walked: an access to it takes a translation fault without consulting any page table, so no kernel translation is present for a speculating core to read around a permission check. In kernel mode both halves are walked, so the copy routines of 6.10 need no change of root. Entry to an exception changes the mode in hardware and so changes the halves walked; no entry trampoline is mapped in user space. Translation-buffer entries carry the half they came from, and a mode change flushes nothing. *(D)*

The author accepted this split (errata 71). Details pending: the system-register number of `KTBR` and the layout of the top-level tables of the two roots ([J.6.4](appendix-j-open.md#j64)).

**6.9.2** The system registers `DMW0` and `DMW1` are stored and have no effect on translation; `MMUCTL` bit 0 enables translation and is zero at reset, so every address is physical until the kernel turns it on. The direct-mapping windows exist; their format is deferred until a kernel needs a window (errata 44). *(D)*

The kernel reaches physical memory through the page tables, with leaves of 1 GB where it can (6.7.2).

**The layout of a process's address space.** On a three-level machine a process sees the picture below. The two halves are the architecture's; what goes where in each half is the kernel's to choose, and the figure is one example.

![The layout of an address space](figures/kern-layout.svg)

The **user half** holds the program's text, data, heap and stack, in pages with `U` set, reached through the process's own tree (`PTBR`, selected by the `ASID`); address zero is left unmapped so that a null pointer faults. The **kernel half** holds the kernel's text and data (global pages: one copy of the entries answers in every address space), the per-CPU structures (the kernel's `DP` points at them), the kernel stacks and the mappings of **devices**. A device's registers are mapped by page entries with the device memory type (6.7) at the physical address that PCI Express enumeration found for them (chapter 2); no address bit and no fixed page says "this is a device". Between the two halves lie the addresses that are not canonical, and an access to one takes the non-canonical-address fault (vector 5).

*Lineage.* **PDP-11:** separate kernel and user spaces, crossed with `mfpi` and `mtpi`. **Between:** the VAX divided its address space into a process half and a system half (*unverified*: the VAX manual is not on this machine, though the 4.3BSD sources are); x86 kernels shared the user's tables until KAISER and page-table isolation were merged in January 2018 (`docs/kernel-pain-points.md`, row 1), and have since paid a table switch on every entry (a `cr3` write, `docs/hardware-vulnerabilities.md`, section 3.2); AArch64 has two translation base registers, `TTBR0` and `TTBR1` (*unverified*, not in the QEMU source checked here). **pdp64:** the PDP-11's separation recovered in the VAX's shape, by one half-selecting bit and a second root register. An entry trampoline (a page of kernel code that some architectures map into user space so that an exception has somewhere to land) is not needed. The cost is a second root register, a second walk to cache and a half bit in each buffer entry.

*Impact.* The split removes the kernel from the translation that a user program's speculation can reach. *Kernel:* the kernel maps itself once, global, with large pages where it can. *Hardware:* a second root register and a half bit in each translation-buffer entry.

## 6.10 The user-memory guard and system calls

**Reaching the user's memory.** On the PDP-11 the kernel's pointers and the user's pointers lived in different spaces, so reaching user memory took `mfpi` and `mtpi` (6.1), and a user pointer used by mistake in kernel code failed on its own because the same number meant something else. On the pdp64 kernel and user pages share one address space, so the two kinds of pointer are the same kind of number. The kernel can copy from a user buffer with an ordinary load, and a **buggy kernel** (one that follows a user-supplied pointer without checking) can do it by mistake, which is how many attacks work. The guard is a status-word bit, `UA`: with it clear, a kernel-mode data access to a user page faults. The kernel sets it (`STUA`) only around the copy and clears it (`CLUA`) after, and entry to every exception clears it.

**6.10.1** With the guard bit `UA` clear, a kernel-mode data access to a user page faults; `STUA` sets it and `CLUA` clears it; exception entry clears it and `EPSW` keeps the old value. *(D)*

**System calls.** A system call is `TRAP #n`, or `TRAPL #n` for the long form. It enters through vector `256 + n`, the next instruction becomes `EPC`, and the call number and arguments travel in registers named by the ABI. In V7, `sys n` entered one vector, `trap()` fetched the number back from the user's instruction with `fuiword`, and the arguments were read from the user's stack by `fuword`.

Details pending: which registers carry the system-call number, the arguments and the result ([J.6.5](appendix-j-open.md#j65)).

**6.10.2** `TRAP #n` and `TRAPL #n` (n up to 255, two bytes each: one word with an 8-bit vector number) enter the kernel through vector 256 + n; the system-call number and arguments travel in registers by the ABI. *(D)*

**6.10.3** A copy routine opens the guard, copies, and closes it; every error path out of the copy must close it, and entry clearing it bounds the damage if one does not. *(D)*

**6.10.4** A move with the qualifier `.U` (`MOVQ.U`, `MOVL.U` and the others, seven words) accesses its memory operand with user privilege, so that a copy-in or copy-out routine needs no window in the status word. A fault on that operand is attributed to the instruction and recovered through a **fixup table** (a table of recovery addresses, one entry for each instruction that may fault): the handler looks up the faulting `EPC` in the table, and the copy returns an error. Bit 15 of `ECAUSE` marks the fault. `UA`, `STUA` and `CLUA` stay until the OpenBSD port confirms them, and the atomics take the user form once the operand placement of `ATOM` is fixed. *(D)* Details pending ([J.6.12](appendix-j-open.md#j612)).



A copy routine, for the case that a user address is bad:

```
copyin(user_src, kernel_dst, n):
    if PROBER(user_src) == 0 or PROBER(user_src + n - 1) == 0:   # readable in the previous mode?
        return EFAULT                      # PROBER tests, and takes no fault
    STUA                                   # open the guard
    memcpy(kernel_dst, user_src, n)        # may still fault, if the file was truncated under us
    CLUA                                   # close it, on every path out
    return 0
```

*Lineage.* **PDP-11:** explicit `MFPI` and `MTPI`, so accidental access was impossible. **Between:** the VAX read user addresses directly after a `PROBER` check (*unverified*); x86 added `SMAP` with `STAC` and `CLAC`, AArch64 `PAN` and RISC-V `SUM` (`SUM` checked in the QEMU source; the others *unverified*). **pdp64:** the guard is a mode bit because it lives in the status word, which is saved anyway. A stray kernel pointer becomes a clean fault, at the cost of an open and a close around every user copy, and every error path must close it.

*Impact.* *Kernel:* every user copy opens and closes the guard; every error path must close it, and entry clearing it bounds the damage of one that does not. The user copy routines are `copyin`, `copyout` and `copyinstr`. *Compiler:* the copy routines are written in assembler or inline assembler; a system-call stub is one `TRAP`. *Hardware:* one status-word bit and one check on a kernel-mode data access to a user page.

## 6.11 The kernel at work: four walks in pseudocode

Everything above is machinery; this section runs it. The pseudocode is **an illustration written for this chapter**, in the style of a V7 kernel, from the statements of this chapter. It is not part of the architecture. Names such as `find_region`, `alloc_frame` and `tick` are what any Unix kernel has and are not specified by the architecture. The mnemonics (`PUSHX`, `POPX`, `SPL`, `MFSR`, `MTSR`, `TLBI`, `TLBSYNC`, `MTASID`, `ISYNC`, `WFE`, `RTI`) are real.

**A system call.** The program puts the call number and arguments in the registers the ABI names and executes `TRAP #0` (or whichever number the system uses). The processor does `enter(256 + n, trap)` of 6.3, which makes `EPC` the instruction after the `TRAP`:

```
vector 256+n  ->  syscall_entry:        # kernel mode, priority 7, R14 is the kernel stack
    PUSHX                               # save EPC and EPSW: one instruction
    save the registers the C code will clobber on the kernel stack
    SPL #0                              # let interrupts in: a system call may take a while
    number = the register the ABI names
    result = sysent[number].handler(args from the registers)     # copyin/copyout use STUA, CLUA
    put result and error in the registers the ABI names
    restore the registers
    SPL #7
    POPX                                # EPC and EPSW back
    RTI                                 # PC = EPC (the instruction after TRAP); PSW = EPSW: user mode again
```

**A page fault.** A load, store or instruction fetch whose translation is not valid, or whose `A` or `D` bit is clear, aborts with vector 7, 8 or 6 (6.3.6). `EVA` holds the address, `EPC` the faulting instruction, `ECAUSE` the kind. The handler below covers the page faults; vectors 9 to 11 (protection violations) are not handled in it.

```
page_fault:                               # vectors 6, 7, 8 (instruction, load, store)
    PUSHX
    save the registers the C code will clobber
    va    = MFSR EVA                      # read both before lowering the priority
    cause = MFSR ECAUSE
    SPL #0                                # we may sleep, reading the page from disk
    region = find_region(current_process, va)
    if region is none:                    # a wild pointer
        send SIGSEGV; goto leave          # (leave delivers the signal on the way out)
    if cause == STORE_FAULT and not region.writable:
        send SIGSEGV; goto leave
    pte = find_pte(current_process.space, va)         # the kernel walks the tree in software, too
    if pte is invalid:                                 # the first touch
        frame = alloc_frame()
        fill frame from the file or with zeroes        # may sleep
        pte = make_pte(frame, region.permissions, A = 1, D = (cause == STORE_FAULT))
    else:                                              # valid, but A or D was clear
        pte.A = 1
        if cause == STORE_FAULT: pte.D = 1
    store pte
    TLBI va ; TLBSYNC                                  # no stale copy of the old entry on any core
leave:
    SPL #7
    restore the registers
    POPX
    RTI                                                # EPC is the faulting instruction: it runs again
```

The same handler serves first touch, first write and paging in; only the bits it sets differ. The faulting instruction restarts because the abort was precise (6.4).

**A timer interrupt.** The timer is vector 32 at level 6 (6.3.6, 6.3.7). This is the pdp64's `hardclock`:

```
timer_interrupt:                          # vector 32; entered at priority 7
    PUSHX
    save the registers the C code will clobber
    SPL #6                                # at the device's own level: only a higher one may interrupt
    tick()                                # advance time; charge the running process; run due timeouts
    if --current.time_slice <= 0: need_resched = 1
    SPL #7
    restore the registers
    if need_resched and the interrupted mode (EPSW) was user:
        call switch()                     # V7: "runrun"; see below
    POPX
    RTI
```

The V7 `call` routine does the same test (previous mode user, `_runrun` set) and makes an artificial trap number 12, "give up cpu", before it returns (`mch_i.s`, checked above).

**A context switch.** The kernel has decided to run another process. The user program's registers are already in the trap frame on its own kernel stack, so the switch deals only with the kernel's state and with the user stack pointer, which lives in a banked register that entry did not save. The picture shows what is touched; the V7 equivalents are `swtch()`, `resume()` and `sureg()`.

![A context switch](figures/kern-ctxswitch.svg)

```
switch_to(old, new):                      # kernel mode, priority 7
    push the callee-saved registers (appendix D) on old's kernel stack
    old.ksp = R14                         # R14 in kernel mode is the kernel stack pointer
    old.usp = MFSR USP                    # the user's stack pointer is not in the trap frame
    R14     = new.ksp                     # one ordinary move: the stack changes here
    pop the callee-saved registers from new's kernel stack
    if new.space != old.space:
        MTSR PTBR, new.space.root         # the new top-level table
        MTASID new.space.asid             # the new address-space number
        ISYNC                             # both take effect now (6.5.2)
    return                                # to wherever new was when it called switch_to
                                          # (the return address was on the stack just loaded)

return_to_user(p):
    MTSR USP, p.usp                       # the user's own stack pointer; R14 is the kernel's
    restore the user registers from p's trap frame
    POPX                                  # EPC and EPSW from p's trap frame
    RTI                                   # user mode, user PC
```

No entry in the translation buffer is touched (provided that a write to `PTBR` and `ASID` flushes nothing, 6.8): the entries of the process that stopped stay, tagged with its ASID, and are used again if it runs soon, and the kernel's own entries are global and serve both. 

Details pending: how the kernel saves and restores a thread's **user** `DP` (the thread pointer, a banked register of user mode) at a thread switch, since the system-register table (6.5.1) has no number for it and `MTDP` and `MFDP` name only the current mode's copy ([J.6.7](appendix-j-open.md#j67)).

**The idle loop.** With no process runnable the kernel waits for an interrupt. The PDP-11 lowered the priority so that an interrupt could be taken and executed `wait`; the V7 `idle` routine clears the priority bits and waits, and 2.11BSD's does `SPLLOW` and `wait` (both checked). The pdp64's `WFE` (wait for event) is the idle instruction (7.10.3). `WFE` ends its sleep for an interrupt that is pending even though the priority masks it, so there is no gap between testing for work and sleeping. The pseudocode is an illustration, written for this chapter:

```
idle():
    loop:
        SPL #7                            # mask everything while we look
        if run_queue is not empty:  SPL #0 ; return
        WFE                               # sleep until an event or an interrupt, masked or not
        SPL #0                            # now take the interrupt that woke us
```

Details pending: the rest of the wake rule ([J.7.1](appendix-j-open.md#j71)).

## 6.12 Reset and the first kernel

**What the machine contains at power-on.** There is no kernel yet. A boot ROM (chapter 4) reads one block into low memory and starts core 0. The **vector table** is 512 × 8 = 4096 bytes, exactly one page; the kernel places it by writing `VBR` and executing `ISYNC`. The PDP-11 also had its vectors at address 0, but as a fixed table of a few hundred bytes (V7's `l.s` goes past octal 0224), and its boot ROMs lived elsewhere. The first few pages of physical memory hold the boot code and the boot data, with the vector table; by errata 102 no device window is mapped there. Details pending: how many pages that is, and where block 0 goes ([J.4.1](appendix-j-open.md#j41)).

**6.12.1** At reset core 0 starts in kernel mode at priority 7 (the entry of the reset vector, 6.3.2) with translation off, the user-memory guard clear and `VBR` zero. To turn translation on the kernel sets `VBR`, builds page tables, writes `PTBR`, sets `MMUCTL` bit 0 and executes `ISYNC`. *(D)*

**6.12.2** The first operating system is OpenBSD, with Unix/32V as the fallback if OpenBSD proves too hard. *(D)*

The first kernel in outline (illustration):

```
kernel_entry:                              # core 0, translation off
    R14 is already a stack
    MTSR VBR, kernel_vector_table          # the table the kernel built or linked
    ISYNC
    read the boot-information block : memory ranges, core count, root complex
    build the kernel's page tables (the upper half, global pages; section 6.9)
    MTSR PTBR, user_root_for_process_0     # the lower half; ASID 0
    MTSR MMUCTL, 1                         # bit 0: translation on
    ISYNC                                  # from here every address is virtual (see below)
    enumerate the bus (section 2.4); start the other cores; start the clock; run init
```

Details pending: what covers the instruction fetch after the write that turns translation on ([J.6.6](appendix-j-open.md#j66)).

*Lineage.* **PDP-11:** the memory manager was turned on by writing a bit in its status register (V7 `mch_i.s` does `mov $1,SSR0`, checked), and the VAX did the same with a jump to a mapped address (*unverified*); each needed a transition in the boot code. **Between:** RISC-V's `satp` has a bare mode and AArch64 has `SCTLR.M` (*unverified*). **pdp64:** translation off at reset, one enable bit in `MMUCTL`, one `ISYNC`. The first kernel code is position-independent and uses no virtual address until translation is on.

*Impact.* *Kernel:* boot code runs at physical addresses until the kernel is ready, and the transition is one write and one `ISYNC`; what covers the next fetch is open (J.6.6). *Hardware:* translation-enable is one bit, a machine-wide mode bit accepted for that reason.

## 6.13 System instructions, exceptions and interrupts

This section collects, in the vocabulary of the kernel, the statements of 6.2 to 6.10 that an implementer needs side by side. The entries of the instructions are in chapter 9.

**6.13.1** There are three modes (kernel, supervisor, user); supervisor is defined and unused. System instructions executed outside kernel mode abort with the privileged-instruction vector. *(D)*

**6.13.2** `TRAP #n` and `TRAPL #n` (vectors 0 to 255, two bytes each) enter the kernel; `RTI` returns, and `RTT` returns and sets the trace bit after. *(D)*

**6.13.3** An exception or interrupt writes only registers: `EPC` receives the address of the faulting instruction (or the next one, for a trap or interrupt), `EPSW` the old status word, `EVA` the faulting address and `ECAUSE` the vector number; the new program counter is the 64-bit word at `VBR + 8 × vector`. *(D)*

**6.13.4** Entry sets the priority to 7 for every exception and every interrupt; the handler lowers it. *(D)*

**6.13.5** There are eight interrupt priority levels; `SPL #n` sets the priority without touching the flags. *(D)*

**6.13.6** `MFSR` and `MTSR` read and write the system registers by number; `TLBI`, `TLBIA` and `TLBSYNC` invalidate translations (broadcast to other cores); `MTASID` and `MFASID` set the address-space tag; `ICINV` and `ICINVA` invalidate the instruction cache; `PROBER` and `PROBEW` test an address; `MFCPUID` identifies the processor. *(D)*

**6.13.7** `UA` in the status word guards user memory: with it clear, a kernel-mode data access to a user page faults; `STUA` sets it and `CLUA` clears it; entry clears it. *(D)*

**6.13.8** `TRAPCC.cc` (fourteen words, one for each condition; one parcel, no operand) enters the kernel when its condition holds; it is a trap and not an abort, so the instruction completes and `EPC` is the next instruction. It takes the check vector, 16 (6.3). `ADDV`, `SUBV` and `MULV` take the same vector on signed overflow, in the two-register form, as an abort that writes nothing. *(D)*

Details pending: the number of the vector and the value of `EVA` ([J.6.10](appendix-j-open.md#j610)).

The modes and exceptions are 6.2 to 6.4 and the multiprocessor instructions are chapter 7. `PROBER` and `PROBEW` replace the `nofault` idiom for address checks, and `ISYNC` follows a write to the page-table base or the vector base. The compiler never emits these instructions except through intrinsics. This is the kernel's whole instruction vocabulary: `MFSR`, `MTSR`, `TLBI`, `RTI`, `SPL`, `ISYNC` and the probes. *Hardware:* the system group takes its sub-opcode from the register field, and the privilege check is one comparison on the current mode.

<!-- entries:6.13 -->
<!-- /entries:6.13 -->

## 6.14 What was checked, and what was not

The rule of the project is to check and not to guess. The handbooks for the PDP-11 and the VAX are not on this machine. What was available, and what each fact rests on:

* **Checked against the Unix sources on this machine** (`<work>/facetlang/unixtree`, files gzipped: the V7M kernel under `V7M/sys` and 2.11BSD under `2.11BSD/sys`): the V7 vector table (`conf/l.s`: the pairs `trap; br7+n`, the console at 060 and 064 at `br4`, the clock at 0100 at `br6`; the file has no `. = ZERO+4` line, the vectors follow a branch and the word 4 at 0 and 2); the processor-status address 0177776 (`PS` in 2.11BSD `mch_iopage.h`) and the status fields in `pdp/psl.h` (`PSL_CURMOD`, `PSL_PRVMOD`, `PSL_IPL`, `PSL_T`, the condition codes); the KT11 register addresses in `pdp/seg.h` (`UISD` 0177600, `UISA` 0177640, `KISA0` 0172340, `KISA6` 0172354); `trap(dev, sp, r1, nps, r0, pc, ps)` and its comment; the system-call dispatch `sysent[fuiword((caddr_t)(a-1))&077]` (V7 `sys/trap.c`); `estabur()` and `sureg()` (eight page-register pairs per mode, sixteen with separate instruction and data space, `ENOMEM` when the segments exceed eight or the image exceeds memory, the segment of at most 128 blocks of 64 bytes); the first-fit core allocator (`malloc.c`: "The core map unit is 64 bytes", "Algorithm is first-fit"); `mfpi`, `mtpi` and the `nofault` global in `mch_i.s`; the `wait` of the V7 and 2.11BSD idle routines; the artificial trap 12 "give up cpu" of the interrupt exit when `_runrun` is set, and the write of 1 to `SSR0` (`mch_i.s`); the comments that the floating exception is an imprecise trap and that `backup()` may fail on the 11/40 (2.11BSD `pdp/trap.c`); supervisor mode used by the 2.11BSD network (`SUPVMODE`); `sched()`, `swapout()` and `swapin()` by name; the comment about "18 bit controllers present in" 22-bit Q-bus systems (2.11BSD `machdep.c`).
* **Checked against the QEMU sources** (`<work>/qemu-src`): RISC-V's `satp` modes 8, 9 and 10 (Sv39, Sv48, Sv57), its 16-bit address-space field, its entry bits `V R W X U G A D` in bits 0 to 7 and its page number at bit 10, its `SUM` bit; x86's `CPUID` leaf 0x80000008 and the `PCIDE` bit of `CR4`; AArch64's `ID_AA64MMFR0` field `PARange`; LoongArch's `CPUCFG1` fields and `PWCL` register.
* **Checked against the repository:** the statements of this chapter against `docs/pdp64-isa.md` sections 7 and 8, `docs/pdp64-system-architecture.md`, `docs/errata.md` (43, 60, 65, 71, 96, 97, 100, 102, 103), `docs/kernel-pain-points.md` and `docs/hardware-vulnerabilities.md`. The vector numbers and system-register numbers are those of the generated constants (`qemu/target-pdp64/gen/pdp64-consts.h`), which come from the grammars.
* **The repository's sizing, not measured:** the kernel survey's estimate of four or five instructions for a system-call entry, against 45 to 70 on RISC kernels (`docs/kernel-pain-points.md`).
* **Unverified** (general knowledge, the handbooks not being on this machine): the names **APF**, and the layouts of the **PAR** and **PDR** beyond what the 2.11BSD code shows (the length field and the access and extension bits); that the KT11 gave 18-bit physical addresses on the original models and 22 bits on later ones; that the I/O page is the top 8 KB of the physical space; the bit positions of the status word apart from those 2.11BSD's header gives; `MMR1` as the register that recorded the auto-increment changes (the repository's text says so, and the 2.11BSD `backup()` routine is its user); the VAX's regions, modify bit and missing reference bit, its entry sequence, its process and system halves, its `MTPR`, its protection field and its `PROBER` use; that the 68000 had no restart path; that MIPS refills its buffer in software; the width of x86's process-context tag and the five words x86 pushes; AArch64's two translation base registers, `PAN`, hardware-managed accessed and dirty bits and broadcast invalidate; x86 rings, AArch64 exception levels and RISC-V modes; the usual meanings of "strongly ordered" and "weakly ordered"; which instructions the PDP-11 forbade in user mode; that current architectures keep exceptions precise for page faults.
* **Decided by the author and recorded in `errata.md`:** everything stated as a decision with a tag *(D)*; the illustrations of 6.11 and 6.12 are not decisions.
