# {{c:id01006|n}}. The kernel: modes, exceptions and memory management

[← manual index](00-index.md)

**An operating system on the pdp64 sees a status word with a mode and a priority, an exception mechanism that writes only registers, and a page table of three, four or five levels whose accessed and dirty bits the kernel maintains in software.** I take you to be a first-year computer-science student or a PDP-11 programmer who has read the Unix Version 6 or 7 kernel, and to know nothing that appeared after the 1970s. The chapter starts from that kernel (the status word, the vectors, `trap()`, the KT11 memory-management unit with its eight page registers per mode, `mfpi` and `mtpi`, swapping). Each later idea follows with the PDP-11 way first, the intermediate machines that changed it, and the pdp64 way with the reason. Pseudocode walks a system call, a page fault, a timer interrupt and a context switch. The design is System v1; the comparisons with other architectures are in [`pdp64-system-architecture.md`](../pdp64-system-architecture.md) (section 15) and [`pdp64-system-design.md`](../pdp64-system-design.md). A fact about an older or another machine that could not be checked on this computer is marked *unverified* and listed in section {{r:kernel-what-was-checked}}.

*How to read this chapter.* A term is defined where it first appears, as the technical word followed by a plain restatement. In the pictures a box is a piece of memory or a register and an arrow is an address stored in it. Code blocks are pseudocode (C-like, `#` starts a comment) unless the text says they are PDP-11 or pdp64 assembly. The PDP-11 code is quoted from the V7 and 2.11BSD kernels on this machine (section {{r:kernel-what-was-checked}}). The pdp64 code is **an illustration written for this chapter**, not part of the architecture (the first operating system is OpenBSD, {{r:first-operating-system-is-openbsd}}). The decisions are the numbered statements.

## {{#kernel-what-you-already-know}} What you already know: the kernel of a PDP-11

Take Unix Version 7 (or 2.11BSD, the same kernel grown up) on a PDP-11/45, 70 or 73. Six things about it carry the rest of the chapter.

**The status word and the modes.** The **processor status word** (PS, also called PSW: one 16-bit register holding the flags, the interrupt priority and the mode of the running program) sits at address 0177776. Bits 15-14 are the **current mode** (the privilege the program runs with: kernel, supervisor or user), bits 13-12 the **previous mode** (the mode running before the last trap), bits 7-5 the **priority** (the level at or below which interrupts are held back), bit 4 the **trace** bit (take a trap after every instruction) and bits 3-0 the flags N, Z, V and C. The 2.11BSD header `psl.h` says the same in C: `PSL_CURMOD` 0xc000, `PSL_PRVMOD` 0x3000, `PSL_IPL` 0xe0, `PSL_T` 0x10, the condition codes in 0xf. Each mode has its **own stack pointer** (R6 names a different register in each mode), so a trap arriving in user mode finds a kernel stack waiting. Outside kernel mode `halt` traps through location 4, and the processor ignores `reset` and `spl` and executes a no-operation instead (the *PDP-11 Processor Handbook* says so, {{r:kernel-what-was-checked}}); that `wait` is also barred there is *unverified*.

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

**The memory-management unit.** A PDP-11 program uses 16-bit addresses (64 KB) while physical memory is wider: 18 bits (256 KB) on the Unibus machines, 22 bits on later ones (*unverified*, section {{r:kernel-what-was-checked}}). The **KT11** (the memory-management unit: the hardware between processor and memory that turns the program's addresses into memory addresses, a step called **translation**) has for each mode **eight pairs** of **page registers**: a **PAR** (page address register: where the segment starts in physical memory, in units of 64 bytes) and a **PDR** (page descriptor register: how long it is, up to 8 KB, and whether it may be read or written). The top three bits of a program's address pick a pair; the other thirteen are the offset in that 8 KB piece. 2.11BSD names the user's registers `UISA` and `UISD` (0177640 and 0177600) and the kernel's `KISA0` (0172340) and following. With **separate instruction and data space** (code and data each get their own 64 KB) there are sixteen pairs. `estabur()` fills a process's saved pairs from the sizes of its text, data and stack and fails with `ENOMEM` if they need more than eight segments; `sureg()` copies the saved pairs into the hardware registers when the process is switched in. Each pair describes **base and length** (a start and a size, the oldest form of memory protection), so a program's text, data and stack are each one **contiguous** run of memory, handed out by a first-fit allocator (`malloc.c`: "the core map unit is 64 bytes").

**Reaching the other space.** The kernel's address space is separate from the user's, so a kernel pointer to user memory means something else. `mfpi` and `mtpi` (move from and to the **previous** instruction space; `mfpd` and `mtpd` for data space) take the address from the kernel's registers but use the previous mode's page registers. `fubyte` and `subyte` are built from them, with a global named `nofault` that makes an error in the access return -1 instead of panicking.

**Swapping.** A process image was one block of memory. When memory ran short, `sched()` called `swapout()`, which wrote the whole image to the **swap device**, and `swapin()` read it back whole. No part of a program could be in memory without the rest.

**What carries over.** The pdp64 keeps three modes with a recognisable status word, a stack pointer per mode, vectors, `RTI`, a priority the kernel raises and lowers, a previous mode and an idle instruction. Eight things are new, each met where it first matters: entry stores state in registers instead of pushing it ({{r:exceptions-interrupts-and-traps}}); exceptions are precise ({{r:faults-and-restart-what-precise-means}}); control registers are reached by number ({{r:system-registers-mfsr-and-mtsr}}); the eight page registers become a tree of page tables that the hardware walks ({{r:from-segments-to-pages-virtual-memory}}, {{r:page-table-entry}}); a translation buffer caches the walk and must be kept honest ({{r:accessed-dirty-tlb-and-asids}}); its entries carry an address-space number so a context switch need not empty it ({{r:accessed-dirty-tlb-and-asids}}); the kernel half of the address space has its own table ({{r:splitting-the-space-and-the-layout}}); and `R7` is an ordinary register: the PC is not a register at all and the stack pointer is `R14`.

## {{#modes-and-the-status-word}} Modes and the status word

The three modes keep their PDP-11 values: kernel 0, supervisor 1, user 3. Loading the reserved value 2 into the status word is an illegal instruction. The fields moved down to make room for one new bit:

| | PDP-11 (`psl.h`) | pdp64 |
|---|---|---|
| flags (four bits) | 3-0 | 3-0 |
| trace | 4 | 4 |
| priority | 7-5 | 7-5 |
| current mode | 15-14 | 9-8 |
| previous mode | 13-12 | 11-10 |

![{{#fig-processor-status-word}}The processor status word](figures/psw.svg)

The status word has no bit for the **user-memory guard** (the rule that the kernel may not touch user memory with an ordinary access; section {{r:user-memory-guard-and-system-calls}}): it is always on. The **previous mode** has the same job as on the PDP-11: after a trap from user mode it says where the kernel came from, and the instructions that act for the previous mode (`PROBER` and `PROBEW`, {{r:user-memory-guard-and-system-calls}}) use it. A **privileged instruction** (one that only the kernel may execute, because it could break the protection between programs) executed outside kernel mode **aborts** (is cancelled before it changes anything, {{r:faults-and-restart-what-precise-means}}) with the privileged-instruction vector, as `halt` and `reset` did on the PDP-11.

**{{#there-are-three-modes}}** There are three modes, with the PDP-11's encoding: kernel 0, supervisor 1, user 3. The supervisor mode exists in the status word and in the banked registers, and no code uses it.

**{{#status-word-holds-the-flags}}** The status word holds the flags in bits 0 to 3, the trace bit in bit 4, the interrupt priority in bits 5 to 7, the current mode in bits 8 and 9, and the previous mode in bits 10 and 11; the other bits are zero.

**{{#mtps-in-user-mode-writes}}** `MTPS` in user mode writes only the flags; in kernel mode it writes every writable bit. `SPL #n` is kernel-only.

**{{#stack-pointer-r14}}** The stack pointer `R14` and the direct-page register `DP` each have one copy per mode; the mode selects which one an instruction names.

**{{#instructions-abort-with-the-privileged}}** These instructions abort with the privileged-instruction vector outside kernel mode: `RTI`, `RTT`, `HALT`, `SPL`, `TLBI`, `TLBIA`, `TLBSYNC`, `MFSR`, `MTSR`, `PROBER`, `PROBEW`, `WFE`, `PUSHX`, `POPX`, `TLBIAS`, `GENTER`. At `H` = 1 (the hypervisor running, {{r:hypervisor-mode-is-one-state}}) all are allowed ({{r:while-h-is-1-hypervisor-registers}}).

**{{#not-privileged-mtdp-and-mfdp}}** These are not privileged: `MTDP` and `MFDP` (in user mode, the thread pointer), `ICINV` and `ICINVA` (a JIT needs them), `FENCE`, `ISYNC` (a program that generates code needs it after `ICINV`), `SEV`, `HINT`, `TRAP`, `BPT`, `NOP`, and `MTPS` and `MFPS` with the restriction above.

`DP` is new to a PDP-11 reader. It is the **direct-page register** (a base register that makes one region addressable with a short displacement, descended from the 6502's zero page). The kernel's copy points to the structure of the core it is running on (the **per-CPU pointer**: which core am I, and where is its private data); a user program's copy points to its thread's private data, so a thread-local variable is one `MOVQ d(DP), Rd`.

*Lineage.* **PDP-11:** three modes, a stack pointer per mode, priority and mode fields in the status word; V7 used kernel and user, and 2.11BSD runs its network code in supervisor mode (`trap()` tests `SUPVMODE(ps)`, checked). **Between:** x86 has four rings of which two are used; AArch64 has exception levels 0 to 3; RISC-V has user, supervisor and machine modes (all *unverified*). Each later design kept a privilege ladder and a banked stack pointer. **pdp64:** the PDP-11's three modes and its stack-pointer banking, so entry from user mode needs no stack switch code, plus a banked `DP`. The third mode costs a third copy of two registers and no logic the kernel uses.

*Impact.* *Kernel:* a trap from user mode needs no stack switch, and the banked `DP` is a per-CPU pointer in kernel mode and a thread pointer in user mode. *Hardware:* three copies of `R14` and `DP`, selected by the mode, and one mode comparison at the decode of a privileged instruction. `PROBER` and `PROBEW` do the work of the `nofault` idiom of V6 and V7 ({{r:faults-and-restart-what-precise-means}}).



## {{#exceptions-interrupts-and-traps}} Exceptions, interrupts and traps: how the machine enters the kernel

The PDP-11 used one word, "trap", for three different events, and the pdp64 names them apart. An **exception** is the machine stopping an instruction because it cannot carry it out (a page that is not in memory, an illegal instruction, a division by zero); it belongs to the instruction. An **interrupt** is a device asking for attention; it belongs to no instruction and is taken between two of them. A **trap**, in the narrow sense used here, is a deliberate entry by an instruction that succeeds (`TRAP #n`, the system call). All three enter the kernel the same way.

**The PDP-11's way.** The hardware read the new PC and PS from the vector, pushed the old pair on the kernel stack and ran the handler. This is **entry through memory**: two words are written to the stack before one handler instruction runs.

**The pdp64's way.** Entry writes only registers and then reads one word. Four **system registers** (registers outside the general ones, reached with `MFSR` and `MTSR`, {{r:system-registers-mfsr-and-mtsr}}) receive the facts: `EPC` (exception program counter: where to resume), `EPSW` (the old status word), `EVA` (exception virtual address: the address that caused a fault) and `ECAUSE` (what happened: the vector number). The new status word is made, and the new program counter is read from the **vector table**: an array of 512 entries of 8 bytes, 4096 bytes in all, whose base is in the register `VBR` (vector base register). `kind` below is one of the families of {{r:faults-and-restart-what-precise-means}}:

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

![{{#fig-exception-entry-and-the-vector}}Exception entry and the vector table](figures/kern-exception.svg)

Three differences from the PDP-11 matter to a kernel writer. Entry **cannot fault**: writing registers cannot meet a missing page, as a push on a kernel stack could. Entry **leaves the saving to the handler**: the hardware pushes nothing, so a handler that may be interrupted first saves `EPC` and `EPSW` (one instruction, `PUSHX`), and one that cannot be interrupted need not save them. Entry is **the same for every cause**: V7's trap vectors say `br7` and its device vectors `br4` and `br6`, each vector choosing its own priority, while the pdp64 always enters at priority 7 and the handler lowers it. A second exception before the handler has saved `EPC` and `EPSW` would overwrite them. The first instructions of every handler, and the memory they touch, therefore must not fault, which is why the kernel's text and stacks are in pages every address space shares or in a direct-mapping window ({{r:splitting-the-space-and-the-layout}}). (That consequence is this chapter's reading; the architecture document states a related rule, that the entry code and kernel stack are pinned until the save is done.)

**The table.** `ECAUSE` receives the vector number, so one handler can serve several vectors and tell them apart. Vectors 0 to 31 are for the processor, 32 to 63 for interrupts, 64 to 255 are reserved and 256 to 511 are one per `TRAP` number. In V7 every `sys n` shared the single vector at 034 and the number was fetched from the instruction.

**{{#entry-to-an-exception-or}}** Entry to an exception or an interrupt writes only registers: `EPC` receives the address of the faulting instruction (for an abort or a progress exception) or of the next instruction (for a trap or an interrupt), `EPSW` the old status word, `EVA` the faulting address (zero except for aborts), `ECAUSE` the vector number.

**{{#new-status-word-has}}** The new status word has the current mode kernel, the previous mode the old current mode, priority 7, and the trace bit and the flags cleared.

**{{#new-program-counter}}** The new program counter is the 64-bit word at the physical address `VBR + 8 × vector`; a bus error on that fetch is a machine check that halts.

**{{#hardware-pushes-nothing-a-handler}}** The hardware pushes nothing. A handler that can be interrupted saves `EPC` and `EPSW` with `PUSHX`, lowers the priority with `SPL`, and before returning restores them with `POPX` and executes `RTI`.

**{{#rti-mask-loads-the-program}}** `RTI #mask` loads the program counter from `EPC` and the status word from `EPSW`; `RTT #mask` does the same and sets the trace bit after the return. There is no `RTI` or `RTT` without the mask: each is one six-byte instruction whose last four bytes are the mask of {{r:mask-is-32-bits-bit}}.

**{{#vector-table-has-512-entries}}** The vector table has 512 entries and `ECAUSE` equals the vector number.

| Vectors | Meaning |
|---|---|
| 0 | reset |
| 1 | machine check |
| 2, 3, 4, 5 | illegal instruction, privileged instruction, misaligned access (an atomic, `PUSHX` or `POPX`, or an operand of a vector block), non-canonical address |
| 6, 7, 8 | instruction, load and store page fault |
| 9, 10, 11 | protection violation on instruction, load and store |
| 12, 13 | divide by zero, bus fault |
| 14, 15 | landing-pad violation, breakpoint |
| 16 | check (`CT<cc>` and `CHK2`; `ADDV`, `SUBV` and `MULV` on overflow) |
| 17 to 20 | exits to the hypervisor ({{r:exit-enters-the-hypervisor-through}}) |
| 21 to 31 | reserved |
| 32 to 63 | interrupts (in the virt machine, 32 timer, 33 console input, 34 console output) |
| 64 to 255 | reserved (device interrupts are message-signalled, section {{r:interrupts-as-a-driver-sees-them}}) |
| 256 + n | `TRAP #n`, n from 0 to 255 |

**{{#there-are-eight-interrupt-priority}}** There are eight interrupt priority levels; the processor takes an interrupt between instructions when its level is greater than the priority in the status word; the timer is at level 6 and the console at level 4. In a guest only the virtual interrupt lines are masked by the priority in the guest's status word; a physical interrupt always leaves the guest ({{r:physical-interrupt-always-exits-exit}}, {{r:guest-sees-seven-virtual-interrupt}}).

The two levels are the PDP-11's: V7 vectors the line clock at priority 6 and the console at 4 (`l.s`, checked above). A **message-signalled interrupt** is a device raising an interrupt by writing a word to a memory address, so that no interrupt wire is needed (section {{r:msi-interrupts-that-are-writes}}). Vectors 64 to 255 are reserved for it.



*Lineage.* **PDP-11:** push PC and PS on the kernel stack, load a new pair from the vector; trap vectors conventionally held priority 7 (V7 `l.s`: every trap vector is `br7+code`). **Between:** the VAX pushed the program counter and the processor status longword, and raised the priority to the interrupt's level for an interrupt but not for an exception (*unverified*); x86 pushes five words on the stack (*unverified*); AArch64 and RISC-V latch the return address and status in registers (*unverified*); each of the three masks interrupts on entry (*unverified*). **pdp64:** the register form, so entry cannot fault and costs no memory write; priority 7 is fixed on entry so that no interrupt can overwrite the saved pair before the handler stores it. The kernel survey estimates a system-call entry at four or five instructions on paper, against 45 to 70 on the RISC kernels it examined; it is a paper estimate, not a measurement. Handlers written in C need a short assembler stub to save and restore registers.

*Impact.* *Kernel:* priority 7 on entry removes the code that would otherwise guard the saved state, and `PUSHX` and `POPX` make the save and restore one instruction each. *Hardware:* entry writes registers only, so it cannot fault, and the vector fetch is one 64-bit read.

**What `RTI` did not do.** On the PDP-11 `RTI` restored two things, the program counter and the status word, and nothing else. Whatever the kernel's code had last put in `R0` to `R5` was still there when the user program ran again, and the user program could read it. That is a small leak while the kernel holds nothing private. It is not small when the kernel holds a key, a pointer into its own memory or a piece of another process's data, and a kernel is written by many people, each of whom must remember, at every return, to wipe every register that holds something private. A single one forgotten is a silent hole that no test finds, because the program still runs correctly.

I took the remembering out of the programmer's hands. On the pdp64 a return to a lesser mode **names the registers that may be seen**, and the hardware clears all the others in the same step as the return. The mask is part of the instruction, so it is a constant of the place in the kernel where the return is written, which is where the kernel knows what it is handing back:

```
    # system-call return: the result in R0 and the callee-saved registers belong to the user
    POPX
    RTI #RTIMASK_SYSCALL
    # the return that starts a new process: nothing is kept
    POPX
    RTI #RTIMASK_NONE
```

A mask that names too little costs the user a value, and the first test shows it as a zero where a result should be. A mask that names too much is the one spelling that leaks (`RTI #RTIMASK_ALL`), and it is written in plain sight. That is why the mask is in the instruction and not in a register that the kernel sets and may forget to set again.

**{{#mask-is-32-bits-bit}}** The mask is 32 bits. Bit n keeps `Rn` for n from 0 to 31 except 14: when the return is to a lesser mode, that is from kernel to supervisor or user, or from supervisor to user, every register whose bit is zero is cleared in the same step as the return. The instruction carries the mask in parcel 1 (the high half) and parcel 2 (the low half).

**{{#r14-is-the-stack-pointer}}** `R14` is the stack pointer of the mode returned to and is never cleared, so bit 14 of the mask names something else: it keeps the vector registers and the floating-point flags (`FPSR`). A zero in bit 14 clears the vector registers (the hidden accumulators included) and the floating-point flags in `FPSR`. The vector registers are zero at the start of every strip in any case, so what a program can see of bit 14 is `FPSR`.

**{{#return-to-the-same-mode}}** A return to the same mode ignores the mask: nothing is a lesser mode, and no register is cleared.

**{{#generated-rtimask-constants}}** The generated constants `RTIMASK_ALL` (every register kept), `RTIMASK_NONE` (none kept), `RTIMASK_CALLEE` (`R8` to `R11`, `R13`, `R15`, `R24` to `R31`) and `RTIMASK_SYSCALL` (`R0` and the callee-saved registers; a call that returns two words adds `R1`) name the common masks, and `RTIMASK_VECTOR` is the number of the bit of {{r:r14-is-the-stack-pointer}}. The default mask of a system-call return is `RTIMASK_SYSCALL` (appendix {{c:id03004|n}}).

**{{#rti-and-rtt-are-six}}** `RTI` and `RTT` are six bytes where they were two. They run at the rate of interrupts and system calls, never in a hot loop, and a two-byte slot is worth more to a frequent instruction. The same mask on `GENTER` is in {{r:rti-mask-is-the-only}}.

## {{#faults-and-restart-what-precise-means}} Faults and restart: what "precise" means

When an instruction cannot finish (its page is absent, say), the machine must stop it, tell the kernel and, once the kernel has removed the cause, **restart** it (run it again from the start). Whether that works depends on what the instruction did before it stopped.

**On the PDP-11** it did not always work. `cmp -(sp),-(sp)` changes a register (`sp` goes down by 2, twice) while it works out its operands, and may then fault on the second operand; rerun as it stands, it leaves `sp` 4 too low. The hardware therefore kept a small journal of the register changes (the register `MMR1`, on the machines that had one), and the kernel's `backup()` read it and undid them before the restart. The 2.11BSD `trap()` says that on the 11/40, which had no such register, "the routine backup/mch.s may fail", and then so may the automatic growth of the user stack, which relies on restarting. Floating-point errors were worse: V7 and 2.11BSD both say "the floating exception is an imprecise trap", meaning that by the time it was taken the processor had run on, and the saved PC no longer named the faulting instruction.

**Between.** The VAX saved resumable microstate and a status-word bit for instructions interrupted half way; the 68000 had no restart path for a bus error in its first form (both *unverified*, repository text). The next step was to make exceptions precise by design and let the compiler and hardware avoid the cases that were not.

**On the pdp64** every exception that belongs to an instruction is **precise**. A **precise exception** (one taken so that the machine looks as if it ran one instruction at a time, in order: every earlier instruction has completed, and the faulting instruction and every later one have changed nothing) lets the kernel treat a page fault as a subroutine call the program never noticed. It matters here because the pdp64 is meant to be built both as a simple **in-order core** (one that runs instructions one after the other, as the PDP-11 did) and as an **out-of-order core** (one that looks ahead, starts later instructions whose inputs are ready before earlier ones have finished, and holds the results in a buffer until the earlier instructions are known not to have faulted). In the second kind the faulting instruction is one of dozens in flight, some already half done; the machine must discard their results and report the fault as if none had started. The architecture makes this possible without a journal. An instruction has at most one memory operand, and the register update of an auto-increment or auto-decrement mode is held until the instruction **retires** (is certain to complete) and thrown away if it aborts ({{r:register-update-of-an-auto}}; `docs/pdp64-isa.md` section 7.2 has the argument and 7.3 the table of every reference that can fault). My remark on this (2026-11-09): "pdp64 specifically designs the instructions for minimal uops, so we have minimal restart/recovery code needed, no?".

**Four families.** The kernel sees separately the cases that the PDP-11 mixed together:

| Family | The instruction | `EPC` on entry | Restartable |
|---|---|---|---|
| **trap** | completes | the next instruction | not applicable |
| **abort** | annulled, as if it had not begun | the faulting instruction | yes, by `RTI` |
| **progress** | partly done, the progress is in registers | the faulting instruction | yes, by `RTI` |
| **machine check** | indeterminate | best effort | no |

A **progress** exception belongs to the block instructions (`MCPY` and the others of the `MBLK` group, section {{r:integer-arithmetic}}). A copy of a megabyte may take 256 page faults; the instruction keeps its position in its own registers, so `RTI` re-executes it and it carries on from where it stopped. A **machine check** descends from the PDP-11's bus error at vector 004: something happened that the machine cannot repair or locate exactly (an uncorrectable memory error, a posted write that timed out), and the kernel can only stop the process or the machine. A **posted write** (a store the processor has handed on and no longer waits for) is the reason: when the bus reports the failure the instruction retired long ago.

**{{#faults-fall-in-four-categories}}** Faults fall in four categories: traps (the instruction completes), aborts (it is annulled and restarted), progress (a block operation stopped part-way, restarted from its registers) and machine checks (not restartable).

**{{#register-update-of-an-auto}}** The register update of an auto-increment or auto-decrement mode is held until the instruction retires and discarded by an abort, so a handler never undoes anything.

**{{#read-of-non-existent-memory}}** A read of non-existent memory is a precise abort with cause `BUSFAULT`; a posted write that times out and an uncorrectable memory error are machine checks.


Three consequences. The undo buffer is a single entry, and row 3 of the fault matrix (an operand write) can never fault, so no journal or undo protocol exists. One small page-fault handler serves first touch, first write and demand paging ({{r:kernel-at-work-four-walks}}), and there is no `backup()` and no `MMR1`. The `nofault` idiom of V6 and V7 `trap.c` (set the global, do the probe, `longjmp` out of the handler instead of panicking) remains the pattern for probing hardware, though `PROBER` and `PROBEW` cover address validation. A read of a configuration position that holds no device is not a fault at all (it returns all ones, {{r:read-of-a-configuration-position}}), so a bus scan does not take a `BUSFAULT` for every empty slot. The pdp64 makes floating-point exceptions flags that never trap, so they need no imprecise case; whether current architectures keep exceptions precise for page faults and leave some floating-point and bus errors imprecise is *unverified*.

*Impact.* The price of precision is in the implementation and not in the kernel: an out-of-order core needs the buffer that holds its results until retirement. *Kernel:* one small page-fault handler for first touch, first write and demand paging; no `backup()` and no `MMR1`. *Compiler:* no scheduling restriction arises from faults, because the register update of an addressing mode is held until retirement. *Hardware:* a single-entry undo buffer, a result buffer for the out-of-order implementation and a retirement stage that decides.

## {{#system-registers-mfsr-and-mtsr}} System registers: `MFSR` and `MTSR`

The PDP-11 reached its control registers by address. The KT11's page registers, the status word and the other control and status registers sit in the top 8 KB of the address space, the I/O page (`KISA6` at 0172354, `UISD` at 0177600, the PS at 0177776), and the kernel used ordinary `mov` instructions on them. The pdp64 cannot, because its address space is translated ({{r:from-segments-to-pages-virtual-memory}}): a load or store to a control register would itself be translated, and an instruction that changes the translation would change the mapping of the access that reads it. Control registers are **system registers**, numbered 0 to 255, read and written by `MFSR Rd, name` (move from system register) and `MTSR name, Rs` (move to system register). Both are privileged ({{r:instructions-abort-with-the-privileged}}).

**{{#system-registers-are-reached}}** The system registers are reached by `MFSR` and `MTSR` with an 8-bit register number.

| Number | Register | Meaning |
|---|---|---|
| 0 | `PTBR` | physical address of the level-2 page table |
| 1 | `EPC` | exception program counter |
| 2 | `EVA` | exception virtual address |
| 3 | `ECAUSE` | exception cause (the vector number) |
| 4, 5 | | unassigned: an illegal instruction |
| 6, 7 | `USP`, `SSP` | the user and supervisor stack pointers |
| 8 | `EPSW` | exception status word |
| 9 | `VBR` | vector base register |
| 10 | `MMUCTL` | memory-management control (bit 0 enables translation) |
| 11 | `ASID` | address-space identifier |
| 12 | `CPUID` | the core number (read-only) |
| 13 to 15 | | unassigned |
| 16 | `TIME` | the machine's counter, 64 bits, read only; counts at 10 MHz and never goes back ({{r:timer-is-two-system-registers}}) |
| 17 | `TIMECMP` | the core's timer deadline; zero means never ({{r:timer-is-two-system-registers}}) |
| 18 to 31 | | unassigned |
| 32 | `FEATURES` | what the machine has: the hypervisor, the width of an address, the number of translation levels and more; read only ({{r:one-read-only-system-register}}) |
| 33 to 127 | | unassigned |
| 128 to 144, 148 to 162 | | the registers of the hypervisor mode, reached only at `H` = 1: trap control, exit reason, stage 2, virtual interrupts and timer, and the guest's own copies of the registers above ({{r:registers-of-the-hypervisor}}) |
| 136, 145 to 147, 165 to 255 | | unassigned |

`EVA` and `ECAUSE` are read only, as is `CPUID`; the rest of 0 to 12 read and write. `MFSR` is privileged, and no system register is readable outside kernel mode ({{r:every-instruction-that-reveals-or}}). A number that is not assigned is an illegal instruction. `PTBR` is called a level-2 table for the three-level form; it holds the top table of whichever number of levels the machine has ({{r:from-segments-to-pages-virtual-memory}}). `USP` is the user's stack pointer, needed because in kernel mode `R14` is the kernel's; it replaces the PDP-11 idiom `mfpd sp`, and the kernel reads and writes it to build a signal frame, copy a process or switch context. `SSP` is the supervisor's and nothing uses it.

**{{#write-to-ptbr-asid-or}}** A write to `PTBR`, `ASID` or `MMUCTL`, or an `ICINV`, is guaranteed to take effect only after the next `ISYNC`.

`ISYNC` (instruction synchronisation) makes this safe on a machine with more than one instruction in progress. A pipelined or out-of-order core has already fetched and started the instructions after the `MTSR` under the old translation; `ISYNC` waits for every earlier instruction to finish, discards everything fetched after it and fetches again under the new rules. The PDP-11 needed no such instruction, because an instruction was fetched after the previous one had finished.

*Lineage.* **PDP-11:** control registers at fixed high addresses, reached with ordinary moves. **Between:** the VAX had `MTPR` and `MFPR` with an internal-register number; AArch64 has `MRS` and `MSR`, RISC-V `CSRR` and `CSRW`, PowerPC `MFSPR` and `MTSPR`. **pdp64:** the VAX's numbered form. The pair costs two opcodes; a separate instruction per register would spend opcode space with every register. A new register is a number and not an instruction, and the numbers not yet assigned cost nothing until used. The kernel survey found privileged-register access to be 48% of all the compiler-invisible instructions in four kernels; the compiler reaches them through an intrinsic with a constant number. *Hardware:* a control-register file addressed by an 8-bit number, with a read-only decode for the identification registers.

## {{#from-segments-to-pages-virtual-memory}} From segments to pages: virtual memory

**Two kinds of address.** A **virtual address** is the number a program uses; a **physical address** is the number the memory chips answer to. The PDP-11 had both, 16 bits against 18 or 22, and the KT11 translated one into the other. A pdp64 program has 64-bit pointers of which only some bits count (below), and the physical address is 40 to 64 bits wide: 40 bits is one terabyte, and the maximum, 2^64, is sixteen exabytes.

**What the KT11 cost.** The figure puts the PDP-11 scheme (left) beside the pdp64's (right). On the left, the three top bits of a 16-bit address pick one of eight page registers, which says where an 8 KB piece starts and how long it is. Nothing is looked up, because the whole map of the running program is in the eight pairs. Three costs follow. A process had at most 64 KB (eight pieces of 8 KB; 128 KB with separate instruction and data space), and `estabur()` returns `ENOMEM` for a program that needs a ninth segment. Each piece was one **contiguous** block of physical memory, so memory fragmented, and the allocator either found a hole big enough or the kernel swapped something out to make one. And with only eight registers there was no way to leave a hole in the middle of a program unmapped, to share half a segment, to start a program before all of it was in memory, or to learn which part had been used.

![{{#fig-kt11-beside-the-pdp64-walk}}The KT11 beside the pdp64 walk](figures/kern-kt11-walk.svg)

**Between: pages.** The VAX had the remedy that most machines since have copied (*unverified*, repository text): cut both address spaces into equal pieces and let any virtual piece sit in any physical piece. The virtual piece is a **page** and the physical piece a **frame** (the same size, here 4 KB). A virtual address is a **page number** and an **offset** within the page; translation replaces the page number by a frame number and keeps the offset. The map from page numbers to frame numbers is a **page table**: an array indexed by page number, each element (a **page-table entry**, PTE, {{r:page-table-entry}}) saying where the frame is, who may touch it and whether it is present. With pages a program's memory need not be contiguous; a page can be absent (fetched from disk when touched, which is **demand paging**) or shared by two programs; and the kernel can tell which pages are in use.

**The tree.** One flat table is too large. A 39-bit virtual address with 4 KB pages has 2^27 pages (134 million); at 8 bytes an entry the table is 1 GB for every process, nearly all of it empty. Instead the table is a **tree**. Each table is exactly one page, 4096/8 = 512 entries, so nine bits of index, and some of its entries point to tables of the next level rather than to frames. The address is cut into 9-bit fields, one per level, over a 12-bit offset: with **three levels** it has 9 + 9 + 9 + 12 = 39 bits. Translation is a **walk**:

![{{#fig-tree-of-page-tables}}The tree of page tables](figures/kern-pagetree.svg)

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

The pseudocode renders statements {{r:virtual-addresses-are-translated}}, {{r:page-table-entry-is-64}} and {{r:non-leaf-entry-has-v}}; a leaf not aligned to its size is a page fault. The cost is one memory read per level, three to five. A program that touches a few megabytes has a handful of tables, and the **sparse** address space (most of the 512 GB unused) costs nothing, because an entry that is not valid has no table under it. A leaf found above level 0 maps a larger piece, 2 MB at level 1 and 1 GB at level 2: a **large page** (many times the basic size, mapped by one entry; used for the kernel's own mapping and for big buffers). Its frame address must be aligned to its size.

**Three, four or five.** I decided that the walk may have three levels (39 virtual bits: what System v1 specifies), four (48 bits) or five (57 bits), with the number discoverable at run time. Each level adds nine bits and one more memory read per miss. My own referent was the Loongson five-level table ("what other parts of the design are effected if we have 5 level tlb like loongson arch?"). A **canonical** address has all bits above the top virtual bit equal to that bit, so a 39-bit machine accepts a 64-bit pointer only if bits 63 to 38 are all the same. This rules out storing a tag in the unused high bits, which would stop working on a machine with more levels.

**{{#virtual-addresses-are-translated}}** Virtual addresses are translated by three, four or five levels of nine bits over 4 KB pages, which gives virtual addresses of 39, 48 or 57 bits. With three levels, address bits 38 to 30 index level 2, 29 to 21 level 1 and 20 to 12 level 0; with four, bits 47 to 39 index level 3 above them; with five, bits 56 to 48 index level 4 above that; `PTBR` holds the physical address of the table of the top level.

The number of levels is readable by software at runtime, so a kernel adapts to the implementation without a build option; so is the physical address width.

**{{#virtual-addresses-are-39-48}}** Virtual addresses are 39, 48 or 57 bits, translated by three, four or five levels of nine bits over 4 KB pages ({{r:virtual-addresses-are-translated}}) to a physical address of 40 to 64 bits (section {{r:no-bit-of-the-physical}}).

*Lineage.* **PDP-11:** eight base-and-length segments per mode, no tables. **Between:** the VAX had a linear page table per region with a hardware modify bit and no reference bit (*unverified*, repository text); RISC-V's Sv39, Sv48 and Sv57 are the three-, four- and five-level forms with nine bits per level (`satp` modes 8, 9 and 10, checked in the QEMU source); x86-64 uses four levels, and five on newer parts through `LA57`; LoongArch describes the width of each level in a register (`PWCL`, checked). **pdp64:** the Sv39 geometry, with the level count left to the implementation. A leaf at any level makes large pages free for the kernel's own mapping, and the walker only reads, so it is a small state machine. Position-independent code uses PC-relative addressing, and pointers must not carry tags in the high bits.

*Impact.* Thirty-nine bits is 512 GB, what three levels index with nine bits each; each further level adds nine bits (48, then 57) at the price of one more read on every miss, and the kernel chooses what the implementation offers. *Kernel:* the same walk code serves three, four and five levels, with the level count read at run time. *Hardware:* one read per level, three to five.

## {{#page-table-entry}} The page-table entry

Each entry is one 64-bit word. The diagram shows every bit.

![{{#fig-page-table-entry}}The page-table entry](figures/kern-pte.svg)

An entry has two shapes. A **leaf** maps: at least one of `R`, `W`, `X` is set, and the physical page number is the frame the page lives in. A **pointer** says that the next table is here: `V` is set, `R`, `W` and `X` are all clear, and the page number is the next table's. When **valid** `V` is zero nothing is mapped, and the other 63 bits are the kernel's to use, for example for the place on the swap device where the page now lives.

**Permissions and modes.** `R`, `W` and `X` allow reads, writes and instruction fetches. `U` says user mode may use the page, and user mode needs it. Kernel mode may read and write a user page, which is what lets it copy to and from user memory directly ({{r:user-memory-guard-and-system-calls}}), but may never **execute** one, so a kernel tricked into jumping to user memory takes a fault. `W` without `R` is not a valid combination and is a fault. `G` (global) marks a translation the hardware keeps whatever the address space ({{r:accessed-dirty-tlb-and-asids}}). Any undefined bit must be zero in a valid entry, and a set reserved bit is a page fault, which lets the format grow and catches a wild value written by the kernel.

**Memory types.** Each page says how the memory system may treat accesses to it, in the field `MT`. **Normal cached** (0) is ordinary memory, which the **caches** (small fast memories near the processor holding copies of recently used memory) may keep. **Normal uncached** (1) must not be cached, as for a frame buffer that the display hardware reads and the processor writes. The two device types are for device registers: **device weakly ordered** (2) lets the machine combine or reorder accesses, for device memory where only the final result matters, and **device strongly ordered** (3) sends every access to the device in exactly the order written, one at a time and never combined. The number is the strictness: a larger code is a stricter type, so cached is 0, uncached 1, device weakly ordered 2 and device strongly ordered 3. The architecture text gives the four names and numbers; the glosses of the last two are the usual meanings and are *unverified*. The PDP-11 had no memory type: everything at the top of the address space was a device. The pdp64 has **no address bit that says "device"**. The memory type is what a driver sets when it maps a device, and a device window can be anywhere in the physical address space except the first few pages (section {{r:no-bit-of-the-physical}}).

**{{#page-table-entry-is-64}}** A page-table entry is 64 bits: `V` (valid) in bit 0, `R`, `W`, `X`, `U` and `G` (global) in bits 1 to 5, `A` (accessed) and `D` (dirty) in bits 6 and 7, the memory type `MT` in bits 8 and 9, and, for a 40-bit physical address, the physical page number in bits 12 to 39, in place; all other bits are zero, and a set reserved bit is a page fault.

The physical address is 40 to 64 bits ({{r:virtual-addresses-are-39-48}}), so the entry has a form for a physical address wider than 40 bits.

**{{#non-leaf-entry-has-v}}** A non-leaf entry has `V` set and `R`, `W` and `X` clear and points to the next table; a leaf at level 2 maps 1 GB, at level 1 maps 2 MB and at level 0 maps 4 KB, and where the levels exist a leaf at level 3 maps 512 GB and at level 4 maps 256 TB.

**{{#user-mode-access-needs-u}}** A user-mode access needs `U`; kernel mode may read and write user pages but may not execute them; `W` without `R` is reserved.

**{{#memory-type-of-a-page}}** The memory type of a page is one of normal cached (0), normal uncached (1), device weakly ordered (2) and device strongly ordered (3); the larger the code, the stricter the type.

**{{#page-table-entry-carries}}** A page-table entry carries the physical page number in place and read, write, execute and user permission bits; accessed and dirty bits are managed by software; one memory type per page selects cached, uncached, weakly ordered or strongly ordered.

*Lineage.* **PDP-11:** a PDR with length and access bits, no per-page type. **Between:** the VAX entry held a hardware modify bit and a four-bit protection field (*unverified*); RISC-V's low eight bits are `V R W X U G A D` in the same places as here (checked in `cpu_bits.h`); ARM's memory types and LoongArch's cache attributes are the source of the four types, reduced to what a machine of this size can tell apart (`docs/pdp64-isa.md` section 8.2). **pdp64:** one entry shape at every level keeps the walker simple. A memory type per page, not per access, means the code that writes a frame buffer needs no cooperation to be uncached, and a driver maps a device register uncached and strongly ordered without a special instruction.

*Impact.* One entry shape at every level makes the walker simple, and a leaf that is not aligned to its size is a fault, which costs a check and saves the walker from reasoning about partial frames. The physical page number is in place, so no shifting. *Kernel:* the entry is built and read with shifts and masks that are the same for every level, and leaves at any level let the kernel map itself with 1 GB pages. *Hardware:* a translation-buffer entry holds a page number as wide as the physical address, 28 bits at 40.

## {{#accessed-dirty-tlb-and-asids}} Accessed, dirty, the translation buffer and address-space numbers

**Accessed and dirty.** A kernel that runs programs larger than memory must choose pages to throw out. It needs two facts: whether a page has been used lately (**accessed**, `A`) and whether it has been written since it was brought in (**dirty**, `D`: a dirty page must be written to disk before its frame is reused, a clean one can simply be dropped). On the VAX the hardware set a modify bit and the kernel emulated the reference bit (*unverified*, repository text). Many later machines, x86-64 and AArch64 among them (*unverified*), have the **walker** (the part of the memory-management hardware that reads the tables) set both bits itself by writing the page-table entry. The pdp64's walker **never writes a page table**. An access to a page with `A` clear, or a write to a page with `D` clear, takes the page fault of its kind; the kernel sets the bit and runs the instruction again. These are **software-managed** accessed and dirty bits. The cost is one extra fault the first time each page is touched and one the first time it is written; precise exceptions ({{r:faults-and-restart-what-precise-means}}) make that fault cheap, and the walker stays a small read-only state machine.

**{{#accessed-and-dirty-bits}}** The accessed and dirty bits are managed by software: an access to a page with `A` clear, or a write to a page with `D` clear, raises the page fault of its kind and the kernel sets the bit; the hardware walker never writes a page table.

**The translation buffer.** The walk costs a memory read per level, three to five reads for every load, store and instruction fetch, which is unaffordable. Every machine with a walk therefore has a **translation buffer** (TLB, translation lookaside buffer: a small, very fast memory in the processor that keeps recent translations, so that a repeated access to the same page needs no walk). It is a **cache** (a small copy of a larger store, kept for speed) of translations. The PDP-11 had none: its eight page registers were the translation, loaded whole at each process switch, and there was no table to be slow.

![{{#fig-translation-buffer}}The translation buffer](figures/kern-tlb.svg)

An access looks in the buffer first, by virtual page number and address-space number (below). On a match (a **hit**) the physical page and permissions come out and the access proceeds with no memory read for the translation. Otherwise (a **miss**) the walker reads the tables; if the walk ends in a valid leaf with the right permissions and the right `A` and `D` it **fills** the buffer and the access is retried, and if not the access takes the page fault of {{r:exceptions-interrupts-and-traps}}. A miss costs one read per level; a program that touches no more pages than the buffer holds pays only for its first touches. The size and organisation are the implementation's choice (a **set-associative** buffer lets an entry live in any of a few places chosen by the low bits of the page number, which is cheaper than one that can put an entry anywhere). A buffer entry holds a page number as wide as the physical address, 28 bits at 40.

**Keeping it honest.** The buffer holds copies. When the kernel changes a page-table entry it must see that no stale copy remains, or a page it has unmapped or made read-only would still be reachable. An **invalidate** (removing entries from the buffer; "flush" in the older word) is `TLBI rN`, which drops the translation of the page containing the address in `rN` for the current address space and the global entries, or `TLBIA`, which drops everything. Each core has its own buffer, so the invalidate must reach all of them. On the pdp64 both instructions are **broadcast** (sent to every core by the hardware) and `TLBSYNC` waits until every core has finished, so the kernel knows nobody holds the old translation. Other architectures leave this to software, which sends an inter-processor interrupt to every other core and waits for the answers (a **shootdown**); the pain-points report (`docs/kernel-pain-points.md`) counts the IPI deadlock cases among the costs. Unmapping a page is then three lines, as chapter {{c:id01007|n}} says ({{r:unmaps-a-page-by-changing}}):

```
unmap_page(space, va):
    pte_of(space, va) = 0           # change the entry in memory first
    TLBI va                         # drop the old translation, on every core
    TLBSYNC                         # wait until every core has done so
    # now the frame may be reused
```

**{{#translation-is-off-at-reset}}** Translation is off at reset (`MMUCTL` is zero and every address is physical) and is enabled by bit 0 of `MMUCTL`; the `ASID` selects non-global entries.

**{{#tlbi-rn-invalidates-the-translation}}** `TLBI rN` invalidates the translation of the page containing the address in `rN` for the current address space and the global entries; `TLBIA` invalidates all; both broadcast to every core and `TLBSYNC` waits for the broadcast to finish. `TLBIAS rN` invalidates the non-global translations of the address-space number in the low 16 bits of `rN`, for the tag in force, and broadcasts in the same way (a broadcast carries the tag of the core that issued it); an implementation may discard more. At the hypervisor level `TLBIGP rN` invalidates the translations of the guest tag in `GTBR` that used the guest-physical page named by `rN` ({{r:each-translation-buffer-entry}}) (an implementation that keeps no guest-physical page discards the whole tag); it is the invalidate for a hypervisor that has changed one second-stage entry.

**{{#writes-to-mmuctl-ptbr}}** Writes to `MMUCTL`, `PTBR` and `ASID` and the cached translations. Each takes effect at the next `ISYNC` ({{r:write-to-ptbr-asid-or}}); an instruction between the write and the `ISYNC` may use the old translations or the new, and none after it uses a cached translation that the rule below discards. The rules are per core (a write to a system register is not broadcast). *(a)* A write to `MMUCTL` that changes bit 0, in either direction, discards every cached translation, global entries and those of every `ASID`: an entry made while translation was on cannot be used after it was turned off and on again, and an entry cannot be used after translation is turned on whatever the page tables hold by then. *(b)* A write to `PTBR` that changes its value discards the global entries and the entries tagged with the current `ASID`, unless the `ASID` is changed too before the next `ISYNC` (the switch of {{r:kernel-at-work-four-walks}}: an `ASID` is bound to one table by the kernel, and a number that is reused for another table is first invalidated with `TLBIA`, as the end of this section says): an entry walked from the old table is never used under the new one with the same `ASID`. *(c)* A write to `ASID` discards nothing that the architecture promises: an entry tagged with another number is never used (the tag), and whether it is kept for when that number returns is the implementation's choice, so a kernel that changes a page-table entry must `TLBI` it whether or not the `ASID` is the one that used it. *(d)* `TLBI`, `TLBIA`, `TLBIAS` and `TLBIGP` are as in {{r:tlbi-rn-invalidates-the-translation}}. *(e)* A write to `ASID` or `PTBR`, or at the hypervisor level to `GTBR`, also clears the floating-point flags `FPSR` (not a write to `MMUCTL`): the flags belong to the process, and the kernel that switches to another process loads that process's flags. An implementation may discard more than these rules require (the reference executor and the QEMU model discard everything at each write and at each `ISYNC`); no program may depend on an entry surviving.

**{{#reset-leaves-no-cached-translation}}** Reset leaves no cached translation: after a reset translation is off ({{r:translation-is-off-at-reset}}) and the buffer holds no entry, so no translation from before the reset can be used when translation is turned on. Any event that resets the translation state of a core, or of a guest, must discard the cached translations of that core or guest with it: the state registers and the cache are cleared together or not at all (for a guest see {{r:each-translation-buffer-entry}}, {{r:guest-never-sees-a-stale}} and {{r:there-is-no-hardware-event}}, and for the translations of a device {{r:unit-cached-translations}}).

**Address-space numbers.** A process switch changes the page tables. If the buffer cannot tell which process an entry belongs to, the old process's entries would answer for the new one, so the whole buffer must be emptied at every switch and the new process starts with all misses. On the PDP-11 the corresponding cost was `sureg()` writing the new process's eight (or sixteen) pairs into the page registers: sixteen (or thirty-two) register writes with nothing to flush. For tables walked from memory the cost is worse, because the emptied buffer refills one miss at a time. The remedy is to **tag** every buffer entry with the number of the address space it came from, the **address-space identifier** (ASID, 16 bits on the pdp64, set with `MTSR`). An entry matches only if its tag equals the current ASID or it is **global** (`G` set, so it answers in every address space, as the kernel's own pages do). A switch is then a write to `PTBR` and to `ASID` and an `ISYNC` ({{r:write-to-ptbr-asid-or}}): the old process's entries stay in the buffer, harmless, and answer again if that process runs soon. The whole switch is pictured in {{r:kernel-at-work-four-walks}}. What a write to `PTBR`, `ASID` or `MMUCTL` does to the buffer is stated in {{r:writes-to-mmuctl-ptbr}}: a write to `ASID` flushes nothing, so the tags keep their purpose; a write to `MMUCTL` flushes everything; a write to `PTBR` flushes only when the address space does not change with it.

There are 65,536 numbers. When they run out the kernel starts again: it allocates in order, and when the counter wraps it invalidates everything (`TLBIA`) and starts a new **generation**, so that a process holding a number from before is given a fresh one when it next runs. The policy is the kernel's. `TLBIAS` ({{r:tlbi-rn-invalidates-the-translation}}) invalidates every translation of one number, so a kernel that retires one number need not empty the buffer.

*Lineage.* **PDP-11:** no buffer, no tags; `sureg()` rewrote the registers at every switch. **Between:** the VAX emulated reference bits in software under 4.3BSD (*unverified*); MIPS refills its translation buffer in software (*unverified*); x86 added a process-context tag late (the `PCIDE` bit of `CR4`, checked in the QEMU source; its width is *unverified*); RISC-V's `satp` carries a 16-bit address-space number (`SATP64_ASID`, checked) and software flushes other cores' buffers; AArch64 has a broadcast invalidate (*unverified*). The ISA text takes the ASID and the `G` bit from the Commodore 128's memory-management unit, which had four sets of map registers selected by one store and a common region that no map set could hide (`docs/pdp64-isa.md` section 8.1). **pdp64:** a 16-bit tag and a global bit; broadcast invalidates, so the kernel has no shootdown code; a walker that only reads. A core with no speculation has no page-table side channels, which is one reason for the small walker.

*Impact.* Software-managed bits cost one extra fault on the first touch of each page and one on the first write. A walker that never writes cannot damage a table. *Kernel:* the handler sets the accessed and dirty bits; `TLBI` broadcasts, so there is no shootdown code; a context switch writes two registers. *Hardware:* the walker only reads; each buffer entry carries an ASID tag and a global bit, compared on lookup.

## {{#splitting-the-space-and-the-layout}} Splitting the space and the layout of an address space

**One space or two.** On the PDP-11 the kernel had its own address space, with its own eight page registers, and the user could not see it. A kernel on a later machine usually sits in the upper part of every process's own address space, so it can reach the process's memory directly, and the permission bits keep the user out. That arrangement has a hole. A processor that **speculates** (runs instructions ahead before it knows they are allowed, discarding the results if they were not) could on some designs read kernel memory before the permission check caught up, and leave a trace in the caches that a user program could measure. This is the flaw class made public in January 2018 as Meltdown (`docs/hardware-vulnerabilities.md`, section 3.2: CVE-2017-5754, a permission check performed late with data forwarded early). The repository gives it as the reason for the split below: `docs/kernel-pain-points.md`, row 1, "Kernel mapped in every user address space; after Meltdown the page tables had to be split". The pdp64's answer is that **the user does not walk the kernel's tables at all**.

**{{#translation-is-split}}** The translation is split by the top bit of the virtual address (bit 38 with three levels, 47 with four, 56 with five): clear selects the lower half, translated from the table at `PTBR` (one per address space), and set selects the upper half, translated from the table at the system register `KTBR` (one for the whole system, the kernel's). In user mode the upper half is never walked: an access to it takes a translation fault without consulting any page table, so no kernel translation is present for a speculating core to read around a permission check. In kernel mode both halves are walked, so the copy routines of {{r:user-memory-guard-and-system-calls}} need no change of root. Entry to an exception changes the mode in hardware and so changes the halves walked; no entry trampoline is mapped in user space. Translation-buffer entries carry the half they came from, and a mode change flushes nothing.

I accepted this split.

**{{#mmuctl-bit-zero-enables-translation}}** `MMUCTL` bit 0 enables translation and is zero at reset, so every address is physical until the kernel turns it on. The machine has no direct-mapping window: every translated address goes through the page tables.

The kernel reaches physical memory through the page tables, with leaves of 1 GB where it can ({{r:non-leaf-entry-has-v}}).

**The layout of a process's address space.** On a three-level machine a process sees the picture below. The two halves are the architecture's; what goes where in each half is the kernel's to choose, and the figure is one example.

![{{#fig-layout-of-an-address-space}}The layout of an address space](figures/kern-layout.svg)

The **user half** holds the program's text, data, heap and stack, in pages with `U` set, reached through the process's own tree (`PTBR`, selected by the `ASID`); address zero is left unmapped so that a null pointer faults. The **kernel half** holds the kernel's text and data (global pages: one copy of the entries answers in every address space), the per-CPU structures (the kernel's `DP` points at them), the kernel stacks and the mappings of **devices**. A device's registers are mapped by page entries with the device memory type ({{r:page-table-entry}}) at the physical address that PCI Express enumeration found for them (chapter {{c:id01002|n}}); no address bit and no fixed page says "this is a device". Between the two halves lie the addresses that are not canonical, and an access to one takes the non-canonical-address fault (vector 5).

*Lineage.* **PDP-11:** separate kernel and user spaces, crossed with `mfpi` and `mtpi`. **Between:** the VAX divided its address space into a process half and a system half (*unverified*: the VAX manual is not on this machine, though the 4.3BSD sources are); x86 kernels shared the user's tables until KAISER and page-table isolation were merged in January 2018 (`docs/kernel-pain-points.md`, row 1), and have since paid a table switch on every entry (a `cr3` write, `docs/hardware-vulnerabilities.md`, section 3.2); AArch64 has two translation base registers, `TTBR0` and `TTBR1` (*unverified*, not in the QEMU source checked here). **pdp64:** the PDP-11's separation recovered in the VAX's shape, by one half-selecting bit and a second root register. An entry trampoline (a page of kernel code that some architectures map into user space so that an exception has somewhere to land) is not needed. The cost is a second root register, a second walk to cache and a half bit in each buffer entry.

*Impact.* The split removes the kernel from the translation that a user program's speculation can reach. *Kernel:* the kernel maps itself once, global, with large pages where it can. *Hardware:* a second root register and a half bit in each translation-buffer entry.

## {{#user-memory-guard-and-system-calls}} The user-memory guard and system calls

**Reaching the user's memory.** On the PDP-11 the kernel's pointers and the user's pointers lived in different spaces, so reaching user memory took `mfpi` and `mtpi` ({{r:kernel-what-you-already-know}}), and a user pointer used by mistake in kernel code failed on its own because the same number meant something else. On the pdp64 kernel and user pages share one address space, so the two kinds of pointer are the same kind of number. The kernel can copy from a user buffer with an ordinary load, and a **buggy kernel** (one that follows a user-supplied pointer without checking) can do it by mistake, which is how many attacks work. The guard is always on: a kernel-mode data access to a user page faults. The kernel reaches user memory only with an access that says so, a move qualified `.U` or a block copy qualified `.UR` or `.UW`, and that permission belongs to the one instruction: there is no window to open, none to leave open on an error path, and none that an interrupt can find open.

**{{#kernel-data-access-to-user-page}}** A kernel-mode data access to a user page faults, with the load or store protection vector, whether the access is a load, a store or an operand of a block instruction; `PROBER`, `PROBEW` and an instruction fetch are not accesses of this kind. There is no status bit that changes this.

**System calls.** A system call is `TRAP #n`. It enters through vector `256 + n`, the next instruction becomes `EPC`, and the call number and arguments travel in registers named by the ABI. In V7, `sys n` entered one vector, `trap()` fetched the number back from the user's instruction with `fuiword`, and the arguments were read from the user's stack by `fuword`.



**{{#trap-n-n-from-0}}** `TRAP #n` (n from 0 to 255, two bytes) enters the kernel through vector 256 + n; the system-call number and arguments travel in registers by the ABI.

**{{#copy-routine-uses-user-accesses}}** A copy routine copies with `.U` moves or with `MCPY.UR` and `MCPY.UW`; nothing is opened, so no error path has anything to close.

**{{#move-with-the-qualifier-u}}** A move with the qualifier `.U` (`MOVQ.U`, `MOVL.U` and the others, seven words) accesses its memory operand with user privilege, so that a copy-in or copy-out routine needs no window in the status word. The block copy has the same two forms for its two sides: `MCPY.UR` (the bytes it reads are user memory, the copy-in) and `MCPY.UW` (the bytes it writes are, the copy-out); the other side is kernel memory, accessed as any kernel access is, so a user address in the wrong register faults. A fault on a user side is marked in `ECAUSE` as a `.U` move's is, and the registers stand at the byte that faulted. A block fill of user memory is a copy from a zero buffer, and `copyinstr` is a loop of `MOVZB.U` loads. A fault on that operand is attributed to the instruction and recovered through a **fixup table** (a table of recovery addresses, one entry for each instruction that may fault): the handler looks up the faulting `EPC` in the table, and the copy returns an error. Bit 15 of `ECAUSE` marks the fault. The atomics take the user form once the operand placement of `ATOM` is fixed.



A copy routine, for the case that a user address is bad:

```
copyin(user_src, kernel_dst, n):
    if PROBER(user_src) == 0 or PROBER(user_src + n - 1) == 0:   # readable in the previous mode?
        return EFAULT                      # PROBER tests, and takes no fault
    MCPY.UR kernel_dst, user_src, n        # may still fault, if the file was truncated under us: the fixup table finds the way out
    return 0
```

*Lineage.* **PDP-11:** explicit `MFPI` and `MTPI`, so accidental access was impossible. **Between:** the VAX read user addresses directly after a `PROBER` check (*unverified*); x86 added `SMAP` with `STAC` and `CLAC`, AArch64 `PAN` and RISC-V `SUM` (`SUM` checked in the QEMU source; the others *unverified*). **pdp64:** the guard is always on and a user access is the attribute of one instruction, so it cannot be left open or leak through an interrupt (the `.U` loads and stores are AArch64's `LDTR` and `STTR`, extended to the block copy). A stray kernel pointer becomes a clean fault, and a copy costs no more than the copy.

*Impact.* *Kernel:* every user access is a `.U` access, and the copy routines are `copyin`, `copyout` and `copyinstr`. *Compiler:* the copy routines are written in assembler or inline assembler; a system-call stub is one `TRAP`. *Hardware:* a check on a kernel-mode data access to a user page, and a qualifier on one memory operand (on each side of the block copy).

## {{#kernel-at-work-four-walks}} The kernel at work: four walks in pseudocode

Everything above is machinery; this section runs it. The pseudocode is **an illustration written for this chapter**, in the style of a V7 kernel, from the statements of this chapter. It is not part of the architecture. Names such as `find_region`, `alloc_frame` and `tick` are what any Unix kernel has and are not specified by the architecture. The mnemonics (`PUSHX`, `POPX`, `SPL`, `MFSR`, `MTSR`, `TLBI`, `TLBSYNC`, `ISYNC`, `WFE`, `RTI`) are real.

**A system call.** The program puts the call number and arguments in the registers the ABI names and executes `TRAP #0` (or whichever number the system uses). The processor does `enter(256 + n, trap)` of {{r:exceptions-interrupts-and-traps}}, which makes `EPC` the instruction after the `TRAP`:

```
vector 256+n  ->  syscall_entry:        # kernel mode, priority 7, R14 is the kernel stack
    PUSHX                               # save EPC and EPSW: one instruction
    save the registers the C code will clobber on the kernel stack
    SPL #0                              # let interrupts in: a system call may take a while
    number = the register the ABI names
    result = sysent[number].handler(args from the registers)     # copyin/copyout use MCPY.UR and MCPY.UW
    put result and error in the registers the ABI names
    restore the registers
    SPL #7
    POPX                                # EPC and EPSW back
    RTI #RTIMASK_SYSCALL                # PC = EPC (the instruction after TRAP); PSW = EPSW: user mode again
```

**A page fault.** A load, store or instruction fetch whose translation is not valid, or whose `A` or `D` bit is clear, aborts with vector 7, 8 or 6 ({{r:vector-table-has-512-entries}}). `EVA` holds the address, `EPC` the faulting instruction, `ECAUSE` the kind. The handler below covers the page faults; vectors 9 to 11 (protection violations) are not handled in it.

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
    RTI #RTIMASK_ALL                                   # EPC is the faulting instruction: it runs again (the trap frame restored every register, so none is stale)
```

The same handler serves first touch, first write and paging in; only the bits it sets differ. The faulting instruction restarts because the abort was precise ({{r:faults-and-restart-what-precise-means}}).

**A timer interrupt.** The timer is vector 32 at level 6 ({{r:vector-table-has-512-entries}}, {{r:there-are-eight-interrupt-priority}}). This is the pdp64's `hardclock`:

```
timer_interrupt:                          # vector 32; entered at priority 7
    PUSHX
    save the registers the C code will clobber
    SPL #6                                # at the device's own level: only a higher one may interrupt
    tick()                                # advance time; charge the running process; run due timeouts
    MTSR TIMECMP, next_deadline           # the next tick: a periodic tick is the handler adding the period (6.16.28)
    if --current.time_slice <= 0: need_resched = 1
    SPL #7
    restore the registers
    if need_resched and the interrupted mode (EPSW) was user:
        call switch()                     # V7: "runrun"; see below
    POPX
    RTI #RTIMASK_ALL                      # every register was just restored from the interrupted program's own trap frame: none is the kernel's
```

The V7 `call` routine does the same test (previous mode user, `_runrun` set) and makes an artificial trap number 12, "give up cpu", before it returns (`mch_i.s`, checked above).

**A context switch.** The kernel has decided to run another process. The user program's registers are already in the trap frame on its own kernel stack, so the switch deals only with the kernel's state and with the user stack pointer, which lives in a banked register that entry did not save. The picture shows what is touched; the V7 equivalents are `swtch()`, `resume()` and `sureg()`.

![{{#fig-context-switch}}A context switch](figures/kern-ctxswitch.svg)

```
switch_to(old, new):                      # kernel mode, priority 7
    push the callee-saved registers (appendix C) on old's kernel stack
    old.ksp = R14                         # R14 in kernel mode is the kernel stack pointer
    old.usp = MFSR USP                    # the user's stack pointer is not in the trap frame
    R14     = new.ksp                     # one ordinary move: the stack changes here
    pop the callee-saved registers from new's kernel stack
    if new.space != old.space:
        MTSR PTBR, new.space.root         # the new top-level table
        MTSR ASID, new.space.asid        # the new address-space number
        ISYNC                             # both take effect now (6.5.2)
    return                                # to wherever new was when it called switch_to
                                          # (the return address was on the stack just loaded)

return_to_user(p):
    MTSR USP, p.usp                       # the user's own stack pointer; R14 is the kernel's
    restore the user registers from p's trap frame
    POPX                                  # EPC and EPSW from p's trap frame
    RTI #RTIMASK_CALLEE                   # user mode, user PC (the frame restore wrote the registers the user keeps; the hardware clears the rest)
```

No entry of either process need be touched (a write to `ASID` flushes nothing, and a write to `PTBR` that comes with a new `ASID` flushes nothing of the new one, {{r:writes-to-mmuctl-ptbr}}): the entries of the process that stopped stay, tagged with its ASID, and are used again if it runs soon, and the kernel's own entries are global and serve both. 



**The idle loop.** With no process runnable the kernel waits for an interrupt. The PDP-11 lowered the priority so that an interrupt could be taken and executed `wait`; the V7 `idle` routine clears the priority bits and waits, and 2.11BSD's does `SPLLOW` and `wait` (both checked). The pdp64's `WFE` (wait for event) is the idle instruction ({{r:one-core-wfe}}). `WFE` ends its sleep for an interrupt that is pending even though the priority masks it, so there is no gap between testing for work and sleeping. The pseudocode is an illustration, written for this chapter:

```
idle():
    loop:
        SPL #7                            # mask everything while we look
        if run_queue is not empty:  SPL #0 ; return
        WFE                               # sleep until an event or an interrupt, masked or not
        SPL #0                            # now take the interrupt that woke us
```



## {{#reset-and-the-first-kernel}} Reset and the first kernel

**What the machine contains at power-on.** There is no kernel yet. A boot ROM (chapter {{c:id01004|n}}) reads one block into low memory and starts core 0. The **vector table** is 512 × 8 = 4096 bytes, exactly one page; the kernel places it by writing `VBR` and executing `ISYNC`. The PDP-11 also had its vectors at address 0, but as a fixed table of a few hundred bytes (V7's `l.s` goes past octal 0224), and its boot ROMs lived elsewhere. The first few pages of physical memory hold the boot code and the boot data, with the vector table; no device window is mapped there.

**{{#reset-core-0-starts}}** At reset core 0 starts in kernel mode at priority 7 (the entry of the reset vector, {{r:new-status-word-has}}) with translation off and `VBR` zero; on a machine with the hypervisor strap `HVE` the core starts with `H` = 1, so the first software is the hypervisor ({{r:hypervisor-mode-is-one-state}}). To turn translation on the kernel sets `VBR`, builds page tables, writes `PTBR`, sets `MMUCTL` bit 0 and executes `ISYNC`.

**{{#first-operating-system-is-openbsd}}** The first operating system is OpenBSD, with Unix/32V as the fallback if OpenBSD proves too hard.

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



*Lineage.* **PDP-11:** the memory manager was turned on by writing a bit in its status register (V7 `mch_i.s` does `mov $1,SSR0`, checked), and the VAX did the same with a jump to a mapped address (*unverified*); each needed a transition in the boot code. **Between:** RISC-V's `satp` has a bare mode and AArch64 has `SCTLR.M` (*unverified*). **pdp64:** translation off at reset, one enable bit in `MMUCTL`, one `ISYNC`. The first kernel code is position-independent and uses no virtual address until translation is on.

*Impact.* *Kernel:* boot code runs at physical addresses until the kernel is ready, and the transition is one write and one `ISYNC`; what covers the next fetch is open. *Hardware:* translation-enable is one bit, a machine-wide mode bit accepted for that reason.

## {{#kernel-system-instructions-exceptions}} System instructions, exceptions and interrupts

This section collects, in the vocabulary of the kernel, the statements of {{r:modes-and-the-status-word}} to {{r:user-memory-guard-and-system-calls}} that an implementer needs side by side. The entries of the instructions are in chapter {{c:id01009|n}}.

**{{#there-are-three-modes-kernel}}** There are three modes (kernel, supervisor, user); supervisor is defined and unused. On a machine with the strap `HVE` there is also the hypervisor mode, a state bit `H` outside the status word ({{r:hypervisor-mode-is-one-state}}). System instructions executed outside kernel mode abort with the privileged-instruction vector.

**{{#kernel-trap-n-n-from-0}}** `TRAP #n` (n from 0 to 255, two bytes) enters the kernel through vector 256 + n; `RTI #mask` returns, and `RTT #mask` returns and sets the trace bit after; the mask names the registers kept when the return is to a lesser mode ({{r:mask-is-32-bits-bit}}).

**{{#exception-or-interrupt-writes-only}}** An exception or interrupt writes only registers: `EPC` receives the address of the faulting instruction (or the next one, for a trap or interrupt), `EPSW` the old status word, `EVA` the faulting address and `ECAUSE` the vector number; the new program counter is the 64-bit word at `VBR + 8 × vector`. At `H` = 1 these names are the hypervisor level's own registers ({{r:while-h-is-1-hypervisor-registers}}).

**{{#entry-sets-the-priority}}** Entry sets the priority to 7 for every exception and every interrupt; the handler lowers it.

**{{#kernel-there-are-eight-interrupt-priority}}** There are eight interrupt priority levels; `SPL #n` sets the priority without touching the flags.

**{{#mfsr-and-mtsr-read}}** `MFSR` and `MTSR` read and write the system registers by number; `TLBI`, `TLBIA`, `TLBIAS` and `TLBSYNC` invalidate translations (broadcast to other cores); `MTSR` of `ASID` sets the address-space tag; `ICINV` and `ICINVA` invalidate the instruction cache; `PROBER` and `PROBEW` test an address; `MFSR` of `CPUID` identifies the processor; `GENTER #mask` enters a guest from the hypervisor ({{r:genter-enters-a-guest-before}}).

**{{#check-vector-causes}}** The compare-and-trap words `CT<cc>` and `CHK2` enter the kernel by the check vector, 16 ({{r:exceptions-interrupts-and-traps}}), when a check fails; so do `ADDV`, `SUBV` and `MULV` on signed overflow, in the two-register form. All of them are aborts: `EPC` is the instruction itself, so that a handler finds the site in the table of check sites, and nothing is written.



The modes and exceptions are {{r:modes-and-the-status-word}} to {{r:faults-and-restart-what-precise-means}} and the multiprocessor instructions are chapter {{c:id01007|n}}. `PROBER` and `PROBEW` replace the `nofault` idiom for address checks, and `ISYNC` follows a write to the page-table base or the vector base. The compiler never emits these instructions except through intrinsics. This is the kernel's whole instruction vocabulary: `MFSR`, `MTSR`, `TLBI`, `RTI`, `SPL`, `ISYNC` and the probes, and, on a machine with a hypervisor, `GENTER`. *Hardware:* the system group takes its sub-opcode from the register field, and the privilege check is one comparison on the current mode.

<!-- entries:{{r:kernel-system-instructions-exceptions}} -->
<!-- /entries:{{r:kernel-system-instructions-exceptions}} -->

## {{#running-a-kernel-under-a-kernel}} Running a kernel under a kernel: virtualization

**A hypervisor is a small kernel whose programs are whole operating systems.** This section tells why anyone wants one, who built the first, and how the idea works. Section {{r:guest-step-by-step-eleven-events}} follows a guest operating system through eleven events on the pdp64, and section {{r:hypervisor-mode-the-rules}} is the reference: every register, bit and rule.

**The scene.** You have one PDP-11/70 running Version 7 Unix, and it is the machine everyone uses. (A *kernel* is the part of an operating system that runs in the processor's most privileged state, *kernel mode*, and does what ordinary programs may not: it handles the devices, shares the processor among programs, and decides what memory each program may touch. On the PDP-11 the mode is two bits of the processor status word, the PS.) Three things happen in one week. A colleague wants to try a different operating system on it. You have written a new version of your own kernel and want to know whether it boots, but if it crashes it takes the machine, and everyone's work, down with it. And two customers each say they want a whole machine of their own, not an account on yours.

What do you do? The first answer is a second machine. It costs a second machine, and it sits idle whenever its one user is away while the first is busy. People building time-sharing systems wanted to leave exactly that situation. Creasy, who built the first system that did what this section describes, says that before it, system developers could only enjoy computer-assisted programming up to the point of trying the code, at which time "they required a dedicated hardware system, usually at night or on weekends" (Creasy 1981).

The second answer is to run the other operating system as an ordinary program under V7. This fails, and the PDP-11 shows how. A kernel does things only a kernel may do. These are the **privileged instructions**: instructions that the processor refuses, or ignores, outside kernel mode. A kernel raises the priority in the PS to keep interrupts out of a critical section (an *interrupt* is a signal from a device that makes the processor stop what it is doing and enter the kernel, and the *priority* says which devices may do that now); it loads the page registers of the KT11, the memory-management unit (a *page table*, here eight pairs of page-address and page-descriptor registers, says which real memory each piece of an *address space*, the set of addresses a program can use, refers to); it executes `HALT` when there is nothing more to do. Run it in user mode and the machine does one of two unhelpful things. The *PDP-11 Processor Handbook* says that outside kernel mode a `HALT` is a **trap** (an instruction that stops itself and enters the kernel through a vector, here location 4), which is at least a signal, but that the processor "will ignore the 'RESET' and 'SPL' (Set Priority Level) instructions, and will execute No Operation". Think about the second case. The guest kernel executes `SPL 7` to keep interrupts out of its run-queue code. The machine silently does nothing. The guest believes interrupts are held off and they are not; one arrives in the middle of the list update; the guest corrupts its own data and nobody has been told anything. The trouble is not that the guest is forbidden to do what it wants. The trouble is that the machine neither lets it nor tells anyone that it tried.

```
        ; a PDP-11 kernel, run in user mode under V7 (PDP-11 assembler)
        spl     7              ; "keep interrupts out of the run queue": in user mode, silently nothing
        mov     (r1), r2       ; take the first entry off the queue ...
        mov     (r2), (r1)     ; ... an interrupt between these two instructions corrupts the queue
```

What is wanted is a layer under the kernel that sees every one of those acts, does for the guest what the instruction would have done, and keeps the guest from touching anything that is not its own. Here is the same `SPL` on the pdp64, run by a guest kernel under a hypervisor that asked to see it. The instruction exits; the handler of the hypervisor (the **exit handler**) does what `SPL` would have done, which is to put the priority in the guest's saved status word, and enters the guest again. The guest's next `MFPS` shows the priority it asked for. (`MFSR` and `MTSR` move a value between a general register and a numbered system register; `HEXITR` and `HEPSW` are two of the hypervisor's; the `#0` after `GENTER` is explained in {{r:guest-step-by-step-eleven-events}}, example 1.)

```
guest:  spl     #7              ; the guest's instruction: it exits instead of being ignored
        mfps    r5              ; later: the guest sees priority 7
...
hx:     mfsr    r20, hexitr     ; the hypervisor's handler: why did the guest stop?
        cbeq    r20, #XCODE_PRIO, h_prio
...
h_prio: mfsr    r21, hepsw      ; the guest's status word, saved by the hardware at the exit
        movq    =(7<<PSW_PRI), r22
        bis     r22, r21        ; do what SPL #7 would have done
        mtsr    hepsw, r21
        genter  #0              ; enter the guest again, just after its SPL
```

**What a hypervisor is.** A **hypervisor** is a program that runs other operating systems, each believing that it has the whole machine to itself. The operating systems it runs are its **guests**; the real machine is the **host**; and each guest's imaginary machine is a **virtual machine**. (Popek and Goldberg's name for the same program is the *virtual machine monitor*, and their definition of the machine it makes is "an efficient, isolated duplicate of the real machine".)

**Who did it first.** IBM, in the middle of the 1960s. Creasy writes that the system was designed and built by him and his group at the IBM Systems Research and Development Center in the mid-1960s (the center is now the IBM Scientific Center in Cambridge, Massachusetts); CP/CMS was conceived in 1964 for the newly announced System/360. In his words: "CP is an operating system that uses a computing machine to simulate multiple copies of the machine itself." Each copy was a virtual machine controlled "like the real machine by their own operating systems". CP-40, on a System/360 Model 40 that had been modified with a device for address translation, and CMS were the first; CP-67 followed on the Model 67, which had translation built in. Creasy says of the product: "CP and CMS have seen continuous production use since 1967", and "VM/370 became available in 1972 for the IBM System/370 computer family whose members all included virtual memory hardware".

Their way of catching the guest's privileged acts is the one this section uses. The System/360 had two states of execution, privileged and problem. Creasy: "As they are encountered in problem state, the machine blocks their execution and transfers control to a designated program. When using CP, each virtual machine program is actually executed in problem state. The effects of privileged instructions are reproduced by CP within the virtual machines." That is **trap and emulate**: the guest kernel runs in the least privileged state, so its privileged instruction traps; the hypervisor does what the instruction would have done, on a private copy of the state it keeps for that guest; and the guest goes on, not knowing that it did not do the work itself. Compare the PDP-11, where the guest's `SPL` did nothing and nobody was told.

In 1974 Popek and Goldberg, who had studied virtual machine systems, wrote down exactly when this works. Their theorem: "For any conventional third generation computer, a virtual machine monitor may be constructed if the set of sensitive instructions for that computer is a subset of the set of privileged instructions." Said in plain words: an instruction is **privileged** if it traps in user mode, and it is **sensitive** if it would let a program see or change the real machine instead of its own. If every sensitive instruction traps, the machine can be virtualized; if one sensitive instruction does not trap, the guest runs it, nothing is caught, and the illusion has a hole. They gave a machine with such an instruction: on the DEC PDP-10, `JRST 1` returns to user mode and does not trap. The PDP-11 of the scene above has the same fault in miniature, because its `SPL` is sensitive and is not caught.

A year later, at the Fifth Symposium on Operating System Principles (1975), Popek and Kline published "The PDP-11 Virtual Machine Architecture: A Case Study" (pages 97 to 105 of the proceedings). We have read its bibliographic record and nothing of its text.

Machines that failed the theorem could be virtualized only by software tricks, which cost speed. Then processors were changed to pass it: a table of the costs of VM exits in a 2012 paper by Agesen, Mattson, Rugina and Sheldon begins with the Intel Prescott processor, launched in the third quarter of 2005. The RISC-V privileged specification has a chapter "'H' Extension for Hypervisor Support, Version 1.0" in its library of ratified specifications; it "virtualizes the supervisor-level architecture to support the efficient hosting of guest operating systems atop a type-1 or type-2 hypervisor". (A **type-1** hypervisor runs directly on the machine; a **type-2** is an ordinary operating system that also runs guests.) We found no date for the RISC-V extension in a primary source and so give none. The pdp64 builds the support in from the first version, so that no sensitive instruction escapes.

**How it works, in broad strokes.** Picture three layers, with the hypervisor under everything:

```
   user programs        user programs        user programs
  ---------------      ---------------      ---------------
   guest kernel A       guest kernel A       guest kernel B       <- each runs at the
                                                                      kernel level of its own
  ----------------------------------------------------------      virtual machine
   the hypervisor        (the only code that owns the machine)
  ----------------------------------------------------------
   the machine: cores, memory, devices, IOMMU
```

There are five ideas, and each is the PDP-11 idea with something added.

*First, the guest believes it owns the machine.* A V7 kernel starts, finds its memory and its devices and begins to run. A guest kernel does the same, except that what it finds has been set up for it: a range of memory that it believes begins at address zero, a status word, a set of devices, a clock. It cannot tell that it is a guest, because everything it can look at is an accurate picture of a machine, only not the real one.

*Second, every privileged act is caught.* When the guest kernel executes an instruction that would change the real machine, the machine stops the guest and enters the hypervisor. This stop is called an **exit** (the guest "exits" to the hypervisor); it is the machine's `trap()` entry one level up. The hypervisor looks at why, does for the guest what the instruction would have done, on the private copy of the registers it keeps for the guest (the same idea as the PS and the page registers that V7 keeps in a process's `user` structure so that `swtch()`, the routine that switches the processor from one process to another, can restore them: this is a **context switch**, one level up), and then re-enters the guest. As in Creasy's CP, the guest's own user programs run at full speed and without any exit; only the kernel's privileged acts cost a trip through the hypervisor.

*Third, the guest's memory is translated twice.* On the PDP-11 the KT11 turns a program's addresses into memory addresses through the page registers. A guest kernel on a pdp64 fills its own page tables with what it believes are physical addresses; those are called **guest-physical** addresses. The hypervisor has a second set of page tables that turn a guest-physical address into a real one. The first translation is the **first stage** (stage 1) and the second the **second stage** (stage 2). Because a guest can only reach memory that its stage 2 maps, one guest cannot touch another's memory, nor the hypervisor's. The processor keeps recent translations in a small fast memory, the **translation buffer** (the TLB, the translation lookaside buffer; the KT11 has no such buffer, and a *cache* is any such small fast memory that holds a copy of something slower), and every entry in it is labelled with a **tag** saying which guest made it, so that one guest's entries can be thrown away without the others'.

*Fourth, interrupts and the clock are made up.* A real device interrupt always goes to the hypervisor first, whatever the guest's priority. What the guest sees are **virtual interrupts**: lines that the hypervisor raises when its virtual device has something to say, and a virtual clock that counts from a starting point the hypervisor chooses. The guest's `SPL` works on these in hardware, so the guest's priority keeps its meaning and costs no exit.

*Fifth, devices are shared or handed over.* A guest's disk can be a file that the hypervisor reads and writes on the guest's behalf (shared, and every command is trapped), or a real device given to the guest, whose DMA (a device's own reads and writes of memory, with no processor in between) is then confined by the IOMMU (the unit between devices and memory that translates a device's addresses the way the KT11 translates a program's) to the guest's own memory.

**Why the pdp64 has one.** Two reasons of our own. The first is **seL4**, the verified microkernel, which we mean the pdp64 to run, and to run as a hypervisor. The second is **safety**, the first of the principles (safety, speed, fewer instructions, and last a set small enough to keep in the head): a machine that divides itself into isolated parts, in hardware, is the pdp64's safety idea applied to whole operating systems.

**What it means not to have hardware support.** A machine that does not trap every sensitive act can host guests only by keeping, for each guest, a copy of the guest's page tables that the hardware really walks, and by making every write of the guest to its own tables a trap so that the copy stays in step. Every guest page-table write then costs an exit. With two stages in hardware, the guest's page tables are walked by the hardware as they are, and the hypervisor is not involved. The pdp64 therefore builds the support in from the first version: every privileged act traps, memory is translated in two stages by the hardware walker, and interrupts and the timer are virtualized in hardware.

**What it costs.** A state bit and some registers, a second table root and a guest tag in the translation buffer, virtual interrupt lines, a virtual timer, a small range comparator for the hypervisor's tables, and a tag allocator. Each of these is a fraction of a percent to about one percent of the scalar core, and the total, counted piece by piece, is a few percent. The price in time is the second walk: a miss in the translation buffer under two stages needs, in the worst case, nm + n + m page-table entry reads for n levels in the guest's tables and m in the second stage, which is one less than (n + 1)(m + 1): 15 for three levels at each stage, against 3 for one stage.

## {{#guest-step-by-step-eleven-events}} A guest, step by step: eleven events

The examples follow one guest kernel, which we call G, running under one hypervisor, on one core. The code is **an illustration written for this chapter**, in pdp64 assembler (with a few lines of PDP-11 assembler where the story needs them, marked as such); the registers and the instruction `GENTER` are the ones that section {{r:hypervisor-mode-the-rules}} defines. Lines marked with an ellipsis `...` stand for code that the example does not need to show. Each example says what the hardware does, what the hypervisor does, and what the guest sees.

**Example 1. The life of a guest.** When a machine with a hypervisor starts, the hypervisor runs first, at the hypervisor level, with its own vector table (the table of handler addresses that the machine consults when it takes a trap or an interrupt) and on physical addresses (this is the state bit `H` of {{r:hypervisor-mode-the-rules}}: "`H` = 1 means the hypervisor is running"). A native operating system on such a machine is simply a guest. The hypervisor has four things to do before the first guest instruction.

It builds the guest's second-stage tables: a three-level tree of the same page-table entries as {{r:page-table-entry}}, mapping guest-physical memory to real memory, with a root that is one page. It writes the register `GTBR` with the root of that tree and a switch that turns stage 2 on, and asks the hardware for a **guest tag**, a number that every translation made for this guest will carry. The hypervisor never chooses the number: the hardware hands one out, and throws away everything it holds under that number as it does so. It tells the hardware where it keeps its stage-2 tables, by `HARENA` (the **arena**: one contiguous run of real pages, so that the hardware can notice when the tables change; example 6 says why), and where the word lives that tells the other cores that they changed, by `HEPOCH`. It writes the trap-control register `HTRAP`, the list of events that must exit (which of the guest's privileged acts it wants to see; example 2 says which are on after reset). And it writes where the guest starts, into `HEPC` (where the guest resumes) and `HEPSW` (the guest's starting status word).

```
        lea     arena, r1
        shr     #12, r1             ; the number of the first page of the arena ...
        shl     #28, r1             ; ... goes in bits 55 to 28 of HARENA ...
        bis     #16, r1             ; ... and the number of pages, 16, in bits 27 to 0
        mtsr    harena, r1          ; the one run of pages that holds every stage-2 table
        lea     hepoch_word, r1
        mtsr    hepoch, r1          ; the epoch word, inside the arena
        lea     hroot, r1           ; the guest's stage-2 root (one page) ...
        movq    =(1<<GTBR_S2EN | 1<<GTBR_NEW), r2
        bis     r2, r1              ; ... stage 2 on, and a fresh tag from the hardware
        mtsr    gtbr, r1
        movq    =(1<<HTRAP_WFE | 1<<HTRAP_PTBR), r1
        mtsr    htrap, r1           ; exit on WFE and on writes of PTBR
        lea     guest_entry, r1
        mtsr    hepc, r1
        movq    #0, r1
        mtsr    hepsw, r1           ; kernel mode, priority 0
        genter  #0                  ; the guest starts; no register of the hypervisor is kept
```

`GENTER` ("guest enter") is the one new instruction. It is to the hypervisor what `RTI` is to a kernel returning to a user program: it loads the status word from `HEPSW` and the program counter from `HEPC`, makes the guest's own registers the live ones, and clears the state bit. Like `RTI` it carries a **mask**, here `#0`, that names the registers that keep their values; the hardware clears every other register in the same step. So the guest starts with every register zero and finds nothing of the hypervisor's. From the next instruction on, G is running at the kernel level of its own machine, and what it executes is executed by the real processor, not by the hypervisor. Nothing slows it down. G does not know that a second stage of translation is between it and memory.

**Example 2. A guest kernel does something privileged.** G is idle. Like a V7 kernel with nothing to run, it executes the instruction that waits for an event, `WFE`. On a real kernel this puts the core to sleep. Under a hypervisor the core is the hypervisor's to share.

What the hardware does, in order. It checks that the instruction is allowed in G's own mode, as it would for any kernel; G is at kernel level, so yes. It looks in `HTRAP`: the bit for `WFE` is set (it is set at reset), so this instruction is one that exits. The hardware records the guest's state in the hypervisor's registers: `HEPC` gets the address of the instruction after the `WFE` (the exit is a trap, so the instruction counts as done); `HEPSW` gets the guest's whole status word; `HEXITR`, the **exit-reason register**, gets the code for `WFE`. It sets the state bit, sets the priority to 7, and reads a one-word entry from the hypervisor's own vector table. The hypervisor's handler is running; the guest has not been told. Every general register still holds the guest's value; the hypervisor level has its own `R14` and `DP`, so the handler's first instructions can store the guest's registers through `DP` without first having to find a free register.

The hypervisor reads `HEXITR` to see why. For `WFE` the answer is: this virtual core has nothing to do, so mark it idle and run another guest; or, if nothing else is runnable, put the real core to sleep. When the guest has a virtual interrupt pending, the hypervisor enters it again with `GENTER`, and G resumes after its `WFE`, as if it had slept.

```
guest:  wfe                     ; the guest is idle
        halt                    ; (the guest stops when it wakes: HALT always exits)
...
hx:     mfdp    r19             ; DP, the hypervisor's own: its per-core structure
        ; (here the handler would store the guest's r0 to r31 through r19)
        mfsr    r20, hexitr     ; why did the guest stop?
        cbeq    r20, #XCODE_WFE, h_wfe
        cbeq    r20, #XCODE_HALT, h_halt
...
h_wfe:  lea     guest+2, r21    ; HEPC is the instruction after the WFE (one parcel, 2 bytes)
        mfsr    r22, hepc
        cbeq    r21, r22, 1f    ; ... as it must be
        ...
1:      ; mark guest 5 idle, run someone else, or sleep; later, reload the guest's registers, then:
        genter  #0              ; the mask names every register just reloaded; here none
```

The hypervisor keeps nothing in registers across `GENTER`: whatever it needs after the exit it stores in its own per-core structure before it enters and loads again when it comes back, which is one store and one load a value, per exit.

Two points are worth stopping on. The first is that some privileged acts of G do **not** exit. If G writes its page-table base register, `PTBR`, with the bit for `PTBR` in `HTRAP` clear, the write is simply G's own: the guest's page tables are walked by the hardware, and the hypervisor is not involved. (A machine that has no second stage must trap every such write and keep shadow copies of the guest's tables; section {{r:running-a-kernel-under-a-kernel}} told why.) The bit exists so that a hypervisor that wants to see the writes (to count them, or to emulate something) can ask. The second point is that a few things always exit and cannot be turned off, because no guest could handle them: `HALT` is the first. A guest that executes `HALT` means "stop this machine". The hypervisor decides what that means: stop the guest, or power the virtual machine down, or reset it.

A third group are events that the guest could use to *time* its neighbours. Processors have since been built to run ahead of themselves (they start the next instructions before the earlier ones are known to be needed, which is **speculation**) and to keep copies of recent data in caches; as a result how long an operation takes depends on what other programs did a moment before, and a program can learn another's secrets by timing its own operations, without reading a byte of the other's memory. This is a **side channel**. An instruction that invalidates all the translations or all the instruction cache of a core takes a time that depends on how much the neighbours had cached, so the bits for `ICINV`, `TLBIA` and `TLBSYNC` are set after reset (the hypervisor sees every one), and a hypervisor that gives a guest a core of its own, with no neighbours to learn from, clears them:

```
        mfsr    r1, htrap
        movq    =((1<<HTRAP_ICINV)|(1<<HTRAP_TLBIA)|(1<<HTRAP_TLBSYNC)), r2
        bic     r2, r1          ; this guest owns its core: its invalidates are its own
        mtsr    htrap, r1
```

**Example 3. A hypercall.** Sometimes G wants something from the hypervisor on purpose: to print a character through the hypervisor's console, to ask for more memory, to tell the hypervisor "this page is free". This is a **hypercall**, the analogue of a system call one level up. (A *system call* is how a user program asks its kernel for a service: it executes a trap instruction, `TRAP #n` here, `trap` and `sys` on the PDP-11, and the kernel looks at `n` to see what is wanted.) As `TRAP #n` is the system call from a user program to a kernel, so a `TRAP` can be the call from a guest kernel to the hypervisor. There is no new instruction. The hypervisor sets a mask in `HTRAP` that routes a range of `TRAP` numbers to itself: bit k of the 8-bit mask routes the thirty-two numbers 32k to 32k + 31. (`TRAP` takes a number from 0 to 255.)

Say bit 1 is set and G executes `TRAP #40`. Number 40 is in 32 to 63, so the trap does not go to G's own vector table; it exits. The instruction is complete, so `HEPC` is the next instruction; the exit-reason register says "hypercall"; and the hypervisor's vector is 256 + 40, so the hypervisor's table has one entry for each hypercall number, as the kernel's has one for each system call. The arguments are in registers, as for a system call. The hypervisor does the work, puts the result in `R0`, reloads the registers it saved, and executes `GENTER` with a mask that names them. The pieces, in assembler:

```
        movq    =(2<<HTRAP_MASK), r1    ; the hypervisor: bit 1 of the 8-bit mask (bits 16 to 23 of HTRAP)
        mtsr    htrap, r1
...
guest:  movq    #65, r0         ; the guest: the argument, the character 'A'
        trap    #40             ; the hypercall; it exits instead of entering the guest's own vector table
...
hcall:  mfsr    r20, hexitr     ; the hypervisor: reason 17, a hypercall
        mfsr    r20, hcause     ; the vector: VECTOR_TRAP_BASE + 40, that is 256 + 40
        ...                     ; r0 still holds the guest's argument
        movq    #0, r0          ; the result
        genter  #1              ; the mask keeps R0 (bit 0) and clears every other register
```

G's own system calls, which are `TRAP` numbers outside the routed range, never leave the guest: a user program of G that makes a system call enters G's kernel directly, as on a machine with no hypervisor.

**Example 4. A guest page fault, and a second-stage fault.** Here the two stages show. The page-table entries and the walk are those of {{r:from-segments-to-pages-virtual-memory}} and {{r:page-table-entry}}: three levels of nine bits over 4 KB pages. Say G, with translation on, loads from the guest-virtual address `0x403A58`.

Cut it into its fields. Address bits 38 to 30 are 0, so the top-level index is 0. Bits 29 to 21: `0x403A58 >> 21` is 2, so the next index is 2. Bits 20 to 12: `(0x403A58 >> 12) & 0x1FF` is `0x403 & 0x1FF`, which is 3, so the last index is 3. The offset in the page is `0xA58`. G's own tables, which it keeps in what it believes is physical memory, end in an entry for page 3 that says: the page is at guest-physical page `0x123`. So the guest-physical address is `0x123A58`. That is the answer of stage 1.

Stage 2 takes `0x123A58`, cuts it the same way, and walks the hypervisor's tables. Say they say guest-physical page `0x123` is at real page `0x8F7`. The real address is `0x8F7A58`, and the load happens there. The translation buffer remembers the whole result (guest-virtual page `0x403` for the guest's tag goes to real page `0x8F7`) so the next load from that page costs nothing. A miss costs more than in a one-stage machine, because each of G's own table entries is itself at a guest-physical address that needs stage 2: three entries at three levels each, plus the last step, make 15 table reads against 3.

Now two things can go wrong, and the hardware tells them apart.

*If G's own entry for page 3 is not valid,* it is G's fault, and only G's. The hardware takes the page fault in the guest: G's `EPC`, `EVA` and `ECAUSE` are written, and G's own kernel handles it, as a V7 kernel handles a page fault in `trap()`. No exit, no hypervisor, no instruction run. This is why a guest's ordinary virtual memory costs the hypervisor nothing.

*If G's entry is fine but the hypervisor's stage 2 has no entry for guest-physical page `0x123`,* it is the hypervisor's matter: G believes the memory exists. The hardware makes an exit. It writes `HEPC` with the instruction itself (it did not complete, so it will be run again), `HEVA` with the guest-virtual address `0x403A58`, and `HGPA`, the **guest-physical fault address**, with `0x123A58`. The reason register says "second-stage fault, entry invalid". The hypervisor can now do its job: find a real page, write the stage-2 entry, and `GENTER`. G runs the same load again; this time it succeeds. G has no idea that anything happened; that is the whole of "demand paging for a guest". If the hypervisor decides that G has no right to that page, it can instead inject a fault into G, or stop G.

Here is the hypervisor's side of the demand fill, in assembler. The stage-2 entry is the last-level entry of the page-table format of {{r:page-table-entry}}: the real address with the flag bits in its low bits. The store goes to a table that lies inside the hypervisor's arena (example 6 says why that matters), and the `GENTER` is the same as before.

```
        mfsr    r21, hgpa               ; 0x123A58, the guest-physical address that failed
        movq    =0xfffffffff000, r22
        and     r21, r22                ; its page, 0x123000
        shr     #12, r22
        movq    =0x1ff, r23
        and     r23, r22                ; 0x123 & 0x1ff: the index in the last-level table
        shl     #3, r22                 ; 8 bytes to an entry
        lea     s2leaf, r24             ; the last-level stage-2 table, inside the arena
        add     r24, r22
        movq    =(0x8f7000|LEAF), r23   ; real page 0x8F7, readable, writable, executable
        movq    r23, (r22)              ; the entry; a store into the arena
        genter  #0                      ; the guest runs the load again
```

A second guest, G2, might use the same guest-virtual address `0x403A58`, and its own stage 2 might put its guest-physical page `0x123` at real page `0x5B2`. The translation buffer must hold both results at once and must never answer one guest with the other's: that is what the **tag** is for. Every entry in the buffer is keyed by the tag of the guest that made it as well as by the address; while G runs, the processor looks up `0x403` under G's tag and finds `0x8F7`; while G2 runs it looks up the same address under G2's tag and finds `0x5B2`. Without a tag, every change of guest would have to throw the whole buffer away, which is what the KT11's users did at each change of process (a PDP-11 reloads its page registers at a context switch) and which makes a guest switch cost a burst of misses. With the tag, a guest's entries can stay in the buffer while other guests run, and the hypervisor can throw away one guest's entries without touching the rest.

There is a third case, which the hardware also tells apart. If the stage-2 entry is valid but points at a physical address where, by the platform's map of memory and devices, nothing answers, it is still the hypervisor's matter, and the exit says "no device answers" instead of "entry invalid"; the hypervisor handles it the same way. If a device does answer and answers with an error, the guest has not made a mistake of mapping but met a failure of the machine, and that is a machine check in the guest.

**Example 5. A timer tick for the guest, and a device interrupt.** A V7 kernel has the line clock at vector 0100 at priority 6; each tick enters `trap()` and calls `clock()`. G needs the same: a clock that ticks. The pdp64 gives a kernel its clock in two system registers: `MFSR TIME` reads a counter that counts at 10 MHz and cannot be written, and `MTSR TIMECMP` writes a **deadline**, an absolute counter value; while the counter is at or past a deadline that is not zero, the timer's interrupt line is asserted (level 6, vector 32). A deadline of zero means "never", which is also the value after reset. The line is a **level**: it stays asserted until the kernel writes a later deadline, as the line of the PDP-11's KW11-L stays set until the program clears it.

G uses the same two registers, with the same handler as on bare metal, and three pieces make a clock of them. The hypervisor offers G a **virtual timer**: when G reads `TIME` it gets the real counter minus an offset the hypervisor chose in `VTOFF` (so the guest's time starts where the hypervisor says); when G writes `TIMECMP` it writes its own comparator, and while the guest's counter is at or past that deadline the hardware holds **virtual interrupt line 6** asserted, the line for the clock's priority. Like the real timer's it is a level, so a handler that forgets to write the next deadline behaves in the guest as it does on bare metal, and a deadline that had passed when the hypervisor reloaded the guest's registers simply fires at once. The hypervisor has, besides, the real timer, which keeps running at the hypervisor level: the same two names reach it there, its expiry is a physical interrupt, and it is how the hypervisor itself gets control to schedule guests. The hypervisor loads and saves the guest's deadline with `GTIMECMP`.

```
        mfsr    r1, time        ; the guest's time: the real counter minus VTOFF
        add     #3000, r1       ; 3000 counts from now: 300 microseconds at 10 MHz
        mtsr    timecmp, r1     ; the guest's own deadline; no exit
...
        movq    #0, r1
        mtsr    timecmp, r1     ; zero means never: the handler's way to stop the clock
```

```
; in the guest, a tick 3000 counts ahead; no exit happens
        mfsr    r1, time            ; the guest's time: the real counter minus VTOFF
        add     #3000, r1
        mtsr    timecmp, r1         ; the guest's own deadline
```

A **virtual interrupt line** is one bit in the register `VIRQ`, set by the hypervisor (for a device it emulates) or held by the timer hardware. There are seven, one for each priority from 1 to 7. Between two instructions of G, if the highest pending line is above the priority in G's status word, the hardware makes G's own exception entry, with the vector number the hypervisor put in `VIVEC` for that line. This is the entry of {{r:exceptions-interrupts-and-traps}}, run inside the guest, with no exit: `EPC`, `EPSW` and `ECAUSE` are written, the priority goes to 7, and G's handler runs. The bit that the hypervisor set is cleared by the delivery; line 6's timer part follows the comparator. G's `SPL` and `MTPS` work against these lines in hardware, so G's idea of "interrupts held off" is true and cheap. Here is the whole thing in assembler (the hypervisor's side, then the guest's), and it runs:

```
        movq    #(1<<6), r1
        mtsr    virq, r1                ; hypervisor: line 6 is pending
        movq    =(0x60<<40), r1         ; line 6 is the field in bits 47 to 40 of VIVEC: vector 0x60
        mtsr    vivec, r1
        movq    =((MODE_KERNEL<<PSW_MODE)|(MODE_KERNEL<<PSW_PREV)|(7<<PSW_PRI)), r1
        mtsr    hepsw, r1               ; the guest starts at priority 7 ...
        genter  #0
guest:  nop                             ; ... and the pending line is held off
        spl     #0                      ; the priority drops: the guest's own exception entry
        nop                             ; follows at once, to the handler at vector 0x60; no exit
```

A **physical** interrupt is different. An RK11 completing a transfer asserts its line; whatever G's priority is, the interrupt goes to the hypervisor first (an exit, with the reason "physical interrupt" and the line's vector). The hypervisor decides whom it is for. If it is for the hypervisor's own driver, it handles it. If it is for G's virtual disk, it completes the virtual transfer, sets the right bit in `VIRQ`, and enters G; G sees an interrupt, as if its own RK11 had finished. Each physical line stays asserted until the hypervisor clears it at the device, so none is lost. 

Two more newcomers belong here. A **message-signalled interrupt** is an interrupt that a device raises not on a wire (as the RK11 does, on a priority line) but by writing a word to a particular address, the interrupt page; the word says which vector. The PDP-11 kept the pending request inside the device as a level on a line, so the processor stored nothing; a written message is consumed by the write, so the interrupt controller in the processor keeps a pending bit for each vector until the kernel takes it. A card with many queues, one for each core, can raise its own vector for each core. The risk is the one every device that writes memory has: it could write anywhere. A device that does DMA (reads and writes memory by itself) is confined by the **IOMMU**, the unit between devices and memory that translates a device's addresses as the KT11 translates a program's, with a table for each device. Say the hypervisor gave G a real network card. G's driver gives the card a buffer at the guest-physical address `0x123000`. The card puts that address on the bus; the IOMMU finds the card's table, which carries G's tag, walks G's stage 2, and the write lands at real page `0x8F7`. A card that tries a guest-physical address that G has no mapping for finds the entry invalid: the write is refused and counted, and nothing is written. The same table gives the card its interrupt: the message the card writes carries an index, the IOMMU looks it up in that card's own table of vectors, and a card with no entry raises nothing, so a card cannot forge an interrupt for a vector that is not its. The IOMMU also refuses a write by any card to a system register or to an arena page.

**Example 6. A guest reset, and why stale translations must not survive.** A guest sometimes needs to be reset: it asks (by a hypercall, or by touching a virtual device) and the hypervisor does it. A reset must make the guest's machine the machine of reset: all registers to the values of a table, memory as the hypervisor chooses, translation off. There is a trap here, and it is a real one.

The translation buffer holds finished translations tagged with the guest's tag. If the hypervisor changes a stage-2 table, or resets the guest and reuses its root, while the buffer still holds translations made before, the guest can read memory that is no longer its own through them. The Linux KVM bug of 2026 (CVE-2026-99312) is of this kind: when KVM emulated an INIT for a nested guest with paging off, it ran the outer guest "with a stale MMU context". The rule, stated in {{r:reset-leaves-no-cached-translation}}, is: **whatever resets the translation state of a core or a guest must discard its cached translations, in the same step**.

On the pdp64 the hypervisor is not asked to remember. The hardware watches the arena: any store by this core into the one run of pages that holds the stage-2 tables, and any write of a guest's translation register, sets a flag, and `GENTER` throws away every translation of the guest and clears the flag. Until a hypervisor tells the hardware where its arena is, the flag is always set: every entry throws away everything, which is slow and safe, and the fast path has to be asked for. The hardware also refuses to walk a stage-2 table that lies outside the arena, so the hypervisor cannot slip a table past the watch. A device can never write the arena (the IOMMU refuses). Another core is told by the epoch word: when a core has stored into the arena, it adds one to the epoch word in memory at its next entry into a guest or its next `FENCE`; a core entering a guest reads the word and, if it differs from the value it kept at its last flush, throws everything away. No wire runs between cores; the ordinary coherence of memory carries the word. There is no flush bit on `GENTER`, because a bit that the hypervisor can forget to set closes nothing.

The reset sequence is written down in order ({{r:there-is-no-hardware-event}}), and the first thing it does is stop the guest's cores; the hardware does the rest, and the tag is never given to another guest while entries of the old one could exist.

**Example 7. What the hypervisor itself runs on.** The hypervisor is a program too: it has code, data, a stack, and it may have bugs, so it too needs protection from stray pointers. The hypervisor level is built so that an ordinary kernel can itself run there, unmodified. ("VHE" is Arm's name for the same arrangement, a *virtualization host extension*; it keeps a kernel from having to be split in two halves, one that runs at the kernel level and one that runs above.) At the hypervisor level the ordinary register names mean the hypervisor level's own registers: `PTBR`, `MMUCTL`, `ASID`, `VBR`, `EPC`, `EPSW`, `EVA`, `ECAUSE`, `R14` and `DP` are the hypervisor's, so a kernel's handlers, its page tables and its `RTI` work there as they do at the kernel level. The tag of everything translated at the hypervisor level is 0, the host's, and there is one stage only. The guest's registers are reached by explicit names, each the guest's register name with a `G` in front, as a V7 kernel reaches a user's registers with `mfpi` and `mtpi` (the instructions that move a word between the kernel and the memory of the previous mode) and not by the plain names.

```
; at the hypervisor level: the plain names are the hypervisor's own, the G names the guest's
        mfdp    r20             ; DP: the hypervisor's own per-core structure
        mfsr    r1, gptbr       ; the guest's PTBR ...
        movq    r1, (r20)       ; ... into the structure
        mfsr    r1, gvbr
        movq    r1, 8(r20)
        mfsr    r1, gkdp        ; the guest's kernel-mode DP
        movq    r1, 16(r20)
        mtsr    ptbr, r2        ; the hypervisor's own table base: not the guest's
```

A small hypervisor, like the first one of the project, may leave its own translation off and run on physical addresses.

**Example 8. What is saved and what is cleared at the entry and the exit.** When G exits and the hypervisor enters, the hardware saves very little: G's program counter in `HEPC`, G's status word in `HEPSW`, and the facts about the exit (`HEXITR`, `HEVA`, `HGPA`, `HINSN`: the first words of the instruction that caused it). It makes the plain register names mean the hypervisor level's own, so that the first instruction of the handler has a register that is not G's. Everything else that is G's stays where it was: the registers `PTBR`, `VBR`, `EPC` are G's and the hypervisor reaches them by `MFSR` with their explicit names if it is going to run another guest (as a V7 kernel saves a process's PS). This is deliberate: an exit that does not need to touch G's state is as short as the machine can make it.

What the hardware clears is what could leak. At every exit and at `GENTER`, and at every exception entry and return, any `LL` reservation (the marker that `LL` and `SC`, load-linked and store-conditional, use to build an atomic update) is cleared, so that what one guest left behind is not found by another. `RTI` and `GENTER` both carry a **mask**: `RTI #mask` is the only form of `RTI`, and the mask names the registers that are to keep their values; the hardware clears every other register in the same step as the return to a less privileged mode. A kernel that forgets to name a register it used gives the user program a zero, never a secret. Mask bit 14 names the vector registers and the floating-point flags together (register 14 is the stack pointer, which is never cleared, so its bit was free); a mask with that bit clear clears them. The same mask is on `GENTER`, so that a hypervisor cannot hand G a register of another guest by forgetting. Here a kernel leaves a secret in `R5` and a user value in `R8`, and returns to user mode naming only `R8` (bit 8); the user program finds `R5` zero and `R8` intact, and this runs:

```
        movq    =0x1234, r5             ; the kernel's secret
        movq    =0x77, r8               ; a value the kernel restored for the user
        rti     #(1<<8)                 ; keep R8; every other register is cleared in the same step
user:   cbeq    r5, #0, 1f              ; the secret is gone
```

The mask is written in the instruction, not kept in a register, so that no stale mask can survive from an earlier return.

A **vector block** is the pdp64's way of working on a whole array with one short piece of code, and it is the newest idea here, so here is an example. The `VEC` instruction begins the block, names a pointer and an end, and repeats the instructions up to `VEND` once for each **strip**, a piece of a few words that the hardware handles together (the strip is 16 bytes in a block that keeps a sum, so four 32-bit lanes). This block adds up 21 words of 16 bits. The running sum lives in a hidden **accumulator**, `v4`, which `VCLR` zeroes; `VFIN` starts the epilogue, which runs once, after the last strip, and adds the lanes into `R12`.

```
        lea     wsrc, r1                ; 21 words of 16 bits
        movq    #21, r2
        lea     (r1)(r2*2), r4          ; the end pointer
        movq    #0, r12
        vec     r1, r4                  ; the block: the body runs once for each strip
        vclr.l  v4, #1                  ; the accumulator starts at zero (only legal inside the block)
        vld.w.l v0, (r1)+               ; four 16-bit words widened to 32 bits; the pointer advances
        vadd.l  v4, v4, v0              ; the running sum, by lane
        vfin                            ; the epilogue, once
        vacc.l.q r12, v4                ; add the lanes into R12
        vend
```

Run on a machine whose strip is 16, 32 or 64 bytes, this block gives the same sum as adding the words one at a time: the strip is invisible to a program that keeps its sums in accumulators. Now an interrupt arrives, or a guest exits, after the block has done three strips. The accumulator `v4` holds the sum of twelve words; the pointer `R1` has advanced by 24 bytes. The handler is shown the **entry** values (`R1` at the start of the block) and the address of the `VEC`, so that if it simply returns to that address the block starts again from its first strip and is correct: restarting never needs any hidden state. But restarting throws away the three strips, and a block that is interrupted often (a page fault on each page of a large array, a timer tick every few thousand cycles) might never finish. So the hardware keeps, for each core, one hidden **resume record**: the address of the `VEC`, whose context it is (guest tag, address-space number, mode), the entry and the current values of the registers the block changes, and a one-use **token**, a number the hardware makes up and puts in the saved status word, so that only the code that returns with that saved word can resume it. If the same context returns to the same `VEC` with the token and the entry values unchanged, the block carries on at strip four with its sum intact. In every other case (another guest entered, a translation register written, any other vector instruction run, the token missing) the record is discarded and the block starts again from its first strip: resume is only ever faster, and never changes an answer. Because a program must not be able to hold off the kernel for as long as a block takes, an interrupt is taken between two strips, never inside one; and because the record is a hidden thing, the token is made so that a guest cannot learn from it how many times other guests were suspended ({{r:vector-block-that-an-exception}}).

**Example 9. What is not in version 1.** G is a kernel; it cannot be a hypervisor in turn. The first version has **no nested guests**: if G touches any hypervisor register or executes `GENTER`, it exits with the reason "hypervisor register used by a guest", and the hypervisor may make it look to G like an illegal instruction. The reason is the cost: nested virtualization in software needs no new gates but many exits for each guest operation, and in hardware it would take from a fraction of a percent to several percent of a core; and a stale-translation bug of the kind of example 6 happened in the nested case. The rule is stated so that it can be lifted without changing the meaning of anything else.

**Example 10. Two programs, one word: the atomic instructions.** So far the guest and the hypervisor have kept to their own memory. Sooner or later they share a word: a count of the characters waiting in a console buffer that the guest fills and the hypervisor empties, a lock on that buffer, a ticket number. A kernel on the PDP-11 kept shared data safe by raising the processor's priority (`SPL`, {{r:exceptions-interrupts-and-traps}}) so that no interrupt could come between two of its instructions; there was one processor, so that was enough. A machine with a hypervisor, or with a second core, has two ways in which that is not enough, and the first of them needs no second core at all.

Take the plain way to add one to a counter in memory:

```
        movq    (r3), r1        ; read the counter
        add     #1, r1          ; add one
        movq    r1, (r3)        ; write it back
```

Say G runs these three instructions, and after the first one its time slice ends and the hypervisor takes an exit. The hypervisor, which shares the counter, adds one to it and later gives G the core again. G's `R1` still holds the old value, G adds one to that and writes it: the hypervisor's addition is lost, and nothing has gone wrong that anyone could see. A second core would do the same between any two of the three instructions. What is wanted is an **atomic** operation (from the Greek for "that cannot be cut"): one that every other core, every other guest and the hypervisor see either complete or not started, never half done. The PDP-11's `INC` on a memory word had this property against an interrupt, because an interrupt can only come between instructions; the pdp64 gives it to a whole family.

**The family.** There are ten operations, and a pair that works together: `CAS` (compare and swap), `SWAP`, `AADD` (fetch and add), `AAND`, `ABIS`, `AXOR` (fetch and the bit operation), `AMAX`, `AMIN`, `AMAXU`, `AMINU` (fetch and the larger or the smaller, signed and unsigned); each fetch-and-operate word is the name of the machine's own ALU instruction (`ADD`, `AND`, `BIS`, `XOR`, `MAX`, `MIN`, `MAXU`, `MINU`) with an `A` for atomic in front, and `LL` and `SC` (load-linked and store-conditional, below). Each is one instruction, so that taking a lock is one instruction; example 11 says why nothing more is needed between ordinary accesses.

The rules are few, and each exists so that an atomic can never be half done:

* Every one of them has three register fields, and the destination is written last, as everywhere on the machine: `AADD Rs, (Ra), Rd`. The address is in `Ra`, with no offset (the parentheses hold a register and nothing else), the old value of the memory word comes back in `Rd`, and `Rs` is the operand. `CAS Rs, (Ra), Rd` has the **expected** value in `Rd` and the new value in `Rs`, and it puts the old value into `Rd`: the destination register is used for the expected value going in and the old value coming out, as the destination of `ADD` is a source too. If the old value is the expected one, the swap happened.
* The size is 4 bytes or 8 bytes. The bare name is the 8-byte form; the 4-byte form is the name with `L` after the operation: `AADD` and `AADDL`, `CAS` and `CASL`, and for the load-linked pair `LL` and `LLL`, `SC` and `SCL`, as `MOVQ` and `MOVL` are the 8-byte and the 4-byte move. The examples here use the 8-byte form.
* The word must be naturally aligned (an 8-byte word at an address that is a multiple of 8). An atomic on a word that is not aligned takes a **precise fault**: the fault happens before the instruction has changed anything, and the saved program counter is the instruction itself.
* The memory must be ordinary cached memory. An atomic, or an `LL` or `SC`, on uncached memory or on a device's registers also takes a precise fault. The reason is that the machine can make an operation atomic only where it controls the whole path, in the cache; on a device register the choice is a fault, never an operation that is silently not atomic.

**A lock taken and released.** The simplest use of `CAS` is a **spin lock**: a word that is 0 when free and 1 when held, taken by a loop that tries until it succeeds (it "spins"). To take it, the program says: "if the word is 0 make it 1, and tell me what it was". If what it was is 0 the lock is mine; if not, someone else has it and I try again.

```
take:   movq    #0, r1                  ; expected: the lock is free
        movq    #1, r2                  ; new: held
        cas     r2, (r3), r1            ; one step; r3 holds the address of the lock; r1 is now the old value
        cbeq    r1, #0, held            ; the old value was 0: the lock is mine
        hint    #1                      ; it was 1: tell the core this is a wait ...
        br      take                    ; ... and try again
held:   ...                             ; the work on the shared data
        movq    #0, r1
        movq    r1, (r3)                ; the release is an ordinary store
```

Taking the lock is one instruction, and the release is an ordinary store because, as example 11 shows, an ordinary store is seen by the other cores in order. The loop sets `R1` again on every try because `CAS` has overwritten it with the old value, which was 1, and the expected value must be 0 once more.

**A counter.** With `AADD` the counter of the beginning is one instruction, and what it returns is the old value, which is useful: if two programs each add one to the same word, they get two different numbers back, so it also hands out ticket numbers.

```
        lea     count, r3
        movq    #1, r2
        aadd    r2, (r3), r1            ; one step: r1 is the number I took, the counter is one more
```

**The pair `LL` and `SC`.** Not every update is one of the ten. A counter that must stop at a limit cannot be a fetch and add: the program must read it, compare, and write only if it is still what it read. `LL` reads the word and puts a **reservation** on it, a mark that the core keeps; `SC` writes the new value only if the mark is still there, and says whether it did, by a register that is 0 when the word was written and not 0 when it was not. A write to the marked memory by another core, or by a device, clears the mark, and so does anything that ends the guest's turn: the reservation is cleared at every exit, at `GENTER`, and at every exception entry and return (example 8), so that a guest cannot leave a mark for another to find. A program therefore never assumes that its `SC` works: it asks and, if it fails, it begins again from the `LL`.

```
        movq    #100, r5                ; the limit
retry:  ll      (r3), r1                ; read the word and take the reservation
        cbeq    r1, r5, full            ; at the limit: leave without writing
        movq    r1, r6
        add     #1, r6                  ; the new value, in a register
        sc      r6, (r3), r4            ; write it only if no one wrote the marked memory since the LL
        cbne    r4, #0, retry           ; r4 is not 0: the SC did not write; start again
```

Such a loop could, in principle, fail for ever if two cores keep clearing each other's marks. To forbid this the machine makes a promise for the loop of one shape, called a **constrained loop**: from the `LL` to the `SC` there are at most 16 instructions; between them only instructions that work on registers (no loads, no stores, no backward branches); and the `SC` is to the same address as the `LL`. For a loop of that shape, the machine promises that it succeeds sooner or later unless someone else keeps writing the marked memory. The loop above is of that shape (its only branch before the `SC` is a forward one). The marked memory is the aligned block of 128 bytes that holds the word: the hardware may track less (a piece of 8 bytes), never more, and a mark that is cleared by a neighbour's write only costs the loop another try. A program that wants no such cost keeps each word that it protects in a block of its own, as the snippet does by placing the counter on a 128-byte boundary and leaving the rest of the block empty. The weakness of `CAS` is that it compares values: a word that went from A to B and back to A looks as if no one had touched it, though the structure that it points to may have changed (the **ABA problem**), while an `SC` fails if anyone wrote the marked memory, even with the same value.

**Why a hypervisor cares.** First, a guest's atomic is an ordinary instruction on memory, so it does not exit by itself: it is atomic against the hypervisor and against every other guest and core, because the memory system makes it so and does not ask who is calling. The hypervisor can therefore keep a word that a guest also changes (the count of the console buffer, a flag in a ring of requests) and know that a guest cannot leave it half done, because an exit or an interrupt can come only between instructions and never inside one. Second, a fault is precise: if G's atomic touches a page that the hypervisor has not yet mapped (example 4), nothing has changed when the exit comes, and when the hypervisor has filled the entry and gives the core back, the instruction begins again whole. Third, a fault on uncached memory or on a device is a fault and not a silent loss: the hypervisor cannot be led into trusting a lock word that the machine did not keep atomic. Fourth, because the reservation is cleared at each exit and each `GENTER`, no mark that one level left is ever found by the other. Last, the reports of other machines show that the retry costs something where the memory system is slow: an engineer at a maker of Arm servers reported about 25 retries of one compare-and-swap with 28 threads working on the same file, and a Linux developer's comment on it was that a failing compare-and-swap loop means that the cache coherency is bad. This is a reason to keep a contended word to a few programs, which is a rule of the programmer's, and not a flaw of the instruction.

**Example 11. What one core sees of another: the memory model.** The atomics of example 10 make one operation indivisible. A different question is what a program sees of the *order* of another's plain loads and stores. Take the commonest exchange there is, **message passing**: one program writes some data and then sets a flag to say "ready"; another waits for the flag and then reads the data. The guest and the hypervisor of the examples do exactly this when G fills a request and the hypervisor looks at it, and so do a driver and a device. On the PDP-11 the order was simple: there was one processor, it did one access after another, and a program saw its own memory as it had written it. Here are the two sides on the pdp64; the first is G's and the second the hypervisor's, after G's hypercall has stopped it:

```
guest:  movq    #42, r1
        movq    r1, (r3)                ; first the data ...
        movq    #1, r1
        movq    r1, (r4)                ; ... then the flag: "the data is ready"
        trap    #40                     ; tell the hypervisor to look

hcall:  movq    (r4), r1                ; first the flag ...
        cbne    r1, #1, hbad            ; not set: nothing to read yet
        movq    (r3), r2                ; ... then the data
        cbeq    r2, #42, 1f             ; the flag was set, so the data is the new data, never the old
```

Here the reader looks after G's hypercall has stopped G, so the order is plain. What matters is what the architecture promises when the two run at the same time, on two cores: **the pdp64 keeps sequential consistency.** A **memory model** is the promise a machine makes about which values a load may return when other cores are writing; **sequential consistency** (SC) is the simplest promise there is: the result is as if the loads and stores of all the cores had been done one at a time, in one order, with each core's own accesses in its own program order. Under that promise, if the reader sees the flag it sees the data, with no instruction between the reader's two loads and none between the writer's two stores. The program above needs no **fence** (an instruction that tells the core to finish its earlier accesses before it begins the later ones; the same thing as the barrier of example 10). That is why the lock of example 10 is released with an ordinary store.

**Why other machines need fences.** A fast core does not want to wait for slow memory, and so it does three things. It puts a store into a small queue, a **store buffer**, and goes on without waiting for it to reach memory. It may begin a load before an earlier store has been seen by the others. And its caches may bring two related pieces of memory up to date at different times. A single core hides all of this from its own program, which always sees its own stores. Another core cannot be given that privilege for free, and on a machine that allows these things it can see the data store and the flag store in the wrong order: the flag is set and the data is still old. The machines differ in how much they allow. The x86 allows the store buffer and little else: its manual says that reads may be reordered with older writes to different locations, but not with older writes to the same location. Arm's manual calls its model weakly ordered, and RISC-V's default is a weak model too (RISC-V also defines a stronger variant that exists to carry over programs written for the x86). The DEC Alpha was the extreme: the Linux kernel's documentation calls it "one of the most relaxed CPUs there is", and says that some versions have a split data cache that can update two related lines at separate times, so that a program which has just read a pointer to new data can still read the old data through it. So the kernel needs a barrier even between loading a pointer and loading through it, and, since it has to run on the Alpha, it says that the Alpha defines the Linux kernel's memory barrier model: outside the code of one particular machine, the kernel must assume the most relaxed case. The same document notes that even a guest kernel built to run on one processor can be affected, because it shares memory with a host that has several.

What a program on such a machine pays is a fence at every place where order matters, put by the programmer who must find each place, and an error is not a crash on the first run: it is a flag seen before its data, once in a long while, with a timing that no test repeats. This is what a weak model asks of every kernel, driver and compiler, and it is what the pdp64 does not ask.

**What SC does not do, and what it costs.** It orders the accesses; it does not make a sequence of them indivisible. The three-instruction counter of example 10 is still wrong under SC, as the example showed on one core: SC says what order the accesses are seen in, and the atomics make the sequence one access. The two ideas are used together. The cost of SC is paid by the designer of the hardware: a very fast core that runs loads early must check afterwards, and redo any load that another core got in between. The first pdp64 cores are simple and in order and have nothing to gain from a weaker promise, and a program written for the strong promise runs on a weaker machine only with fences added, so the choice is made once, in the strong direction.

**A device is another core that sees memory.** A disk or a network card reads and writes memory by itself (this is **DMA**, direct memory access); to the program it is one more writer, and it can be shown the memory in the wrong order for the same reasons. The pdp64 puts a unit between devices and memory, the **IOMMU** (input-output memory management unit): it translates the addresses a device uses, by tables that the kernel writes, and refuses any access that the tables do not allow. Three rules make the order right by construction:

* The unit reads its tables **coherently**: it reads them through the same path as the cores, so that an entry the kernel has just written is the entry the unit finds, and the kernel does not have to remember to push a changed line out of its cache first. (A fence orders a core's stores; it does not write a modified line out of the core's cache.)
* The kernel tells the unit that a mapping has changed by an **invalidate command** (the commands are: invalidate a device, a domain, a guest, or everything, and a sync), because the unit keeps copies of the translations it has used, just as the processor does in its translation buffer. The unit executes its commands in the order they are given, so that a missing fence cannot make an invalidate run before the store it was meant to follow; the RISC-V unit studied for this design may execute its commands out of order and says that software must place a fence. The command to invalidate a device does not finish until that device's requests already in flight are finished or refused. To reset a guest, the hypervisor blocks the guest's devices, invalidates its translations, and only then resets (example 6).
* A device never writes the arena (example 1), the hypervisor's own tables: the unit refuses it. And the memory that devices write, the DMA buffers, is uncached, so the atomics of example 10, which fault on uncached memory, can never be used on a word that a device is writing; a lock word is always in ordinary memory.

In order, then, with G handing a buffer to a device: G writes the data (plain stores, no fence); the hypervisor (or G's kernel, through it) writes the table entry that lets the device reach the buffer, the unit reads it coherently, and a command to the unit makes it forget any old copy; the device then reads the buffer. On a weak machine with a unit that reads its tables through a cache of its own, each of those steps has a place where a fence or a cache flush has to be remembered. Here none has to be.

## {{#hypervisor-mode-the-rules}} The hypervisor mode: the rules

Everything of {{r:running-a-kernel-under-a-kernel}} and {{r:guest-step-by-step-eleven-events}} is here as numbered statements and tables.

### State and registers

**{{#virtualization-is-part}}** Virtualization is part of the architecture: a hypervisor can run guest operating systems, each at the kernel level of its own machine.

**{{#every-instruction-that-reveals-or}}** Every instruction that reveals or changes the real state of the machine either traps to the hypervisor when a guest runs it, or is harmless. No unprivileged instruction reads a clock, a counter or the identity of the core, and there is no page that the kernel keeps up to date for a user program to read the time from: a user program learns the time by a system call. No system register is readable outside kernel mode.

**{{#hypervisor-mode-is-one-state}}** The hypervisor mode is one state bit, **`H`**, inside the core, not in the status word and not in any register a program can read. `H` = 1 means the hypervisor is running; `H` = 0 means anything else. Only the hardware changes `H`: an exit sets it and `GENTER` clears it. The reserved mode value 2 stays reserved, so `MFPS`, `MTPS`, `RTI` and `EPSW` do not change and a guest cannot see the mode. Whether the machine has a hypervisor is a property of the machine, the **strap `HVE`**, which no program can change, and which `FEATURES` reports ({{r:one-read-only-system-register}}). With `HVE` = 0 the machine is the machine of chapters {{c:id01001|n}} to {{c:id01009|n}} without this section: `H` is always 0, every register of {{r:registers-of-the-hypervisor}} and `GENTER` is an illegal instruction. With `HVE` = 1, `H` is 1 at reset, so the first software to run is the hypervisor (or firmware that starts it).

**{{#while-h-is-1-hypervisor-registers}}** While `H` = 1 the hypervisor level is a kernel of its own, and the ordinary register names are its own: *(a)* the registers 0 to 3 and 6 to 11 of {{r:system-registers-mfsr-and-mtsr}} (`PTBR`, `EPC`, `EVA`, `ECAUSE`, `USP`, `SSP`, `EPSW`, `VBR`, `MMUCTL`, `ASID`), `R14` and `DP` name the hypervisor level's own registers, and `CPUID` (number 12) returns the real core number; *(b)* an exception, a trap or an interrupt taken at `H` = 1 is entered as in {{r:exceptions-interrupts-and-traps}}, with those registers, and `RTI`, `RTT`, `PUSHX` and `POPX` use them as they do for any kernel; the exit registers (`HEPC`, `HEPSW`, `HEVA`, `HCAUSE`, `HGPA`, `HINSN`, `HEXITR`) are never touched by an event taken at `H` = 1, which sets `HEXITR` to 0; *(c)* the priority is the priority field of the status word, which an exit sets to 7 and the hypervisor lowers with `SPL` after it has saved what it needs; *(d)* every privileged instruction is allowed, whatever the mode field says; *(e)* no virtual interrupt line is delivered; a physical interrupt is taken, as in {{r:exceptions-interrupts-and-traps}}, if its level is above the hypervisor's priority; *(f)* a reserved mode value in `HEPSW` is refused with an illegal instruction when it is written. At `H` = 0 the same numbers and names are the guest's.

**{{#hypervisor-level-translates-its-own}}** The hypervisor level translates its own addresses with its own registers ({{r:while-h-is-1-hypervisor-registers}}): its page-table base, address-space number and translation control are the ordinary `PTBR`, `ASID` and `MMUCTL` at `H` = 1, its tag is 0 (the host's), and it has one stage only. A guest's translation-buffer entry never answers a hypervisor access. A hypervisor that leaves `MMUCTL` clear runs on physical addresses.

**{{#hypervisor-reaches-the-guest}}** The hypervisor reaches the guest's copy of every register that {{r:while-h-is-1-hypervisor-registers}} renames through an explicit name, the guest's register name with a `G` in front, defined at `H` = 1 only ({{r:registers-of-the-hypervisor}}); a guest's own use of these numbers exits ({{r:there-is-no-nested-virtualization}}). An exit changes none of the guest's registers in hardware: it writes `HEPC`, `HEPSW` and the facts of the exit and makes the names of {{r:while-h-is-1-hypervisor-registers}} mean the hypervisor level's own, so the first instruction of the handler has `R14` and `DP` that are not the guest's. After a machine reset the kernel stack register is set by the boot protocol of the platform (chapter {{c:id01004|n}}). The hypervisor keeps no value in a general register across `GENTER` ({{r:rti-mask-is-the-only}}).

**{{#registers-of-the-hypervisor}}** The registers of the hypervisor are system registers ({{r:system-registers-mfsr-and-mtsr}}) numbered 128 to 162; they are reached only at `H` = 1. A guest's `MFSR` or `MTSR` of an assigned number exits with exit code 12, after the guest's own privilege check ({{r:some-events-have-no-bit}}); on a machine with `HVE` = 0 it is an illegal instruction; an unassigned number (136, 145 to 147, and 165 to 255) is an illegal instruction. The registers marked read only refuse a write with an illegal instruction. In every register **a write of a one to a bit that is not in use is refused** with an illegal instruction, and such a bit reads as zero. After a machine reset every register is zero except `HTRAP` ({{r:htrap-is-the-trap-control}}).

| Number | Name | Width in use | Access | What it holds |
|---|---|---|---|---|
| 128 | `HTRAP` | 24 bits | read, write | trap control ({{r:htrap-is-the-trap-control}}) |
| 129 | `HEXITR` | 10 bits | read only | exit reason: code in bits 7 to 0, flags in bits 9 and 8 ({{r:hexitr-says-why-the-guest}}) |
| 130 | `HEPC` | 64 | read, write | the guest's program counter at an exit; where `GENTER` resumes |
| 131 | `HEPSW` | status word, and a token in bits 63 to 32 | read, write | the guest's status word at an exit; the one `GENTER` loads; the token of {{r:vector-block-that-an-exception}} |
| 132 | `HEVA` | 64 | read only | the guest-virtual address of the access that caused the exit, else 0 |
| 133 | `HCAUSE` | 9 bits | read only | the vector number of the exit ({{r:exit-enters-the-hypervisor-through}}) |
| 134 | `HGPA` | 39 bits | read only | the guest-physical address that stage 2 could not translate, else 0 |
| 135 | `HINSN` | 32 bits | read only | the first two parcels of the instruction that caused the exit, else 0 |
| 137 | `GTBR` | 64 | read, write | stage-2 enable, root and guest tag ({{r:gtbr-holds-the-whole}}) |
| 138 | `VIRQ` | 8 bits | read, write | virtual interrupt lines, pending; bit 0 reads zero ({{r:guest-sees-seven-virtual-interrupt}}) |
| 139 | `VIVEC` | 56 bits | read, write | the vector number of each virtual line ({{r:guest-sees-seven-virtual-interrupt}}) |
| 140 | `VTOFF` | 64 | read, write | virtual timer offset ({{r:timer-is-two-system-registers}}) |
| 141 | `VCPUID` | 16 bits | read, write | the guest's virtual core number ({{r:mfcpuid-is-privileged-each-guest}}) |
| 142 | `HARENA` | 56 bits | read, write | the arena of stage-2 tables ({{r:guest-never-sees-a-stale}}) |
| 143 | `HEPOCH` | 40 bits | read, write | the real address of the epoch word ({{r:guest-never-sees-a-stale}}) |
| 144 | `GTOKEN` | 64 | read, write | the guest's token key and counter ({{r:vector-block-that-an-exception}}) |
| 148 | `GTIMECMP` | 64 | read, write | the guest's timer deadline ({{r:timer-is-two-system-registers}}) |
| 149 to 162 | `GPTBR`, `GEPC`, `GEVA`, `GECAUSE`, `GUSP`, `GSSP`, `GEPSW`, `GVBR`, `GMMUCTL`, `GASID`, `GKSP`, `GKDP`, `GSDP`, `GUDP` | 64 (`GEPSW`: status word) | read, write | the guest's copy of the registers 0 to 3 and 6 to 11 of {{r:system-registers-mfsr-and-mtsr}}, of `R14` of the kernel mode, and of `DP` of the kernel, supervisor and user modes |

The guest's registers of the last row are written in this order of numbers: 149 `GPTBR`, 150 `GEPC`, 151 `GEVA`, 152 `GECAUSE`, 153 `GUSP`, 154 `GSSP`, 155 `GEPSW`, 156 `GVBR`, 157 `GMMUCTL`, 158 `GASID`, 159 `GKSP`, 160 `GKDP`, 161 `GSDP`, 162 `GUDP`. `GEVA` and `GECAUSE` are writable, though `EVA` and `ECAUSE` are not, because they are the stored values that a world switch must put back. `HINSN` lets the hypervisor emulate a trapped instruction without reading guest memory through the guest's tables.

**{{#one-read-only-system-register}}** One read-only system register, **`FEATURES`** (number 32), says what the machine has, so that software tests instead of trapping or guessing; it is readable at every level, and in a guest the field `HV` reads zero and the other fields are the machine's.

| Bits | Field | Meaning |
|---|---|---|
| 0 | `HV` | the hypervisor is present (`HVE`) |
| 7 to 1 | `PABITS` | the width of a physical address in bits (40) |
| 11 to 8 | `LEVELS` | the number of translation levels (3) |
| 15 to 12 | `TAGBITS` | the width of a guest tag in bits, divided by 4 (4, that is 16 bits) |
| 19 to 16 | `VLINES` | the number of virtual interrupt lines (7) |
| 23 to 20 | `STRIP` | the base-2 logarithm of the vector strip in bytes (the strip of an ordinary block; {{r:vector-block-that-an-exception}}) |
| the rest | | zero |

### Trap control

**{{#htrap-is-the-trap-control}}** `HTRAP` is the trap-control register. A set bit sends its event to the hypervisor as an exit; a clear bit leaves the event to the guest, or to a form of the hardware scoped to the guest. Bit 15 and bits 24 to 63 are reserved ({{r:registers-of-the-hypervisor}}). After a machine reset the bits `WFE`, `SEV`, `TLBIA`, `TLBSYNC` and `ICINV` are set and the rest are clear, so that a guest which has not been given a core of its own can neither sleep the core, wake another guest's core, nor time its neighbours by an invalidate; a hypervisor that gives a guest a core of its own clears them.

| Bit | Name | The event (exit code of {{r:hexitr-says-why-the-guest}}) | When the bit is clear | Reset |
|---|---|---|---|---|
| 0 | `WFE` | `WFE` (3) | the guest sleeps | 1 |
| 1 | `SEV` | `SEV` (4) | `SEV` is the guest's | 1 |
| 2 | `PAUSE` | `HINT #1` (5) | a no-op | 0 |
| 3 | `PRIO` | `SPL` and a changing `MTPS` (6) | the priority is the guest's virtual priority | 0 |
| 4 | `TLBI` | `TLBI` (7) | the invalidate acts on the guest's own tag ({{r:each-translation-buffer-entry}}) | 0 |
| 5 | `TLBIA` | `TLBIA` (7) | as above | 1 |
| 6 | `TLBSYNC` | `TLBSYNC` (7) | as above | 1 |
| 7 | `ASID` | `MTSR` and `MFSR` of `ASID` (8) | the tag keeps the numbers apart | 0 |
| 8 | `PTBR` | a write to `PTBR` (9) | the guest's own register | 0 |
| 9 | `MMUCTL` | a write to `MMUCTL` (10) | the guest's own register | 0 |
| 10 | `VBR` | a write to `VBR` (11) | the guest's own register | 0 |
| 11 | `CPUID` | `MFSR CPUID` (13) | `VCPUID` is returned ({{r:mfcpuid-is-privileged-each-guest}}) | 0 |
| 12 | `ICINV` | `ICINV`, `ICINVA` (14) | they execute ({{r:icinv-and-icinva}}) | 1 |
| 13 | `BPT` | `BPT` (15) | the guest's own breakpoint exception | 0 |
| 14 | `STEP` | an exit after each guest instruction (16) | none | 0 |
| 15 | | reserved | | 0 |
| 16 to 23 | `TRAPMASK` | `TRAP #n`, bit k for the numbers 32k to 32k + 31 (22) | the guest's own system call ({{r:halt-always-exits-exit-code}}) | 0 |

**{{#some-events-have-no-bit}}** Some events have no bit in `HTRAP`. These **always exit**: `HALT` ({{r:halt-always-exits-exit-code}}); `PROBER` and `PROBEW` that meet a stage-2 miss ({{r:translation-of-a-guest}}); any use of a hypervisor register or of `GENTER` ({{r:there-is-no-nested-virtualization}}); every stage-2 fault, a stage-2 miss on the vector fetch or the page-table walk, and a machine check ({{r:what-stage-2-does}}); and every physical interrupt ({{r:physical-interrupt-always-exits-exit}}). These are **the guest's own** and never exit: an illegal instruction, a privileged instruction, the page faults and protection faults of stage 1, the check words and the overflow checks, `TRAP #n` outside the routed range, an unassigned system-register number, and `ISYNC`. The guest's own privilege check comes first: an instruction that the guest's current mode may not execute (`WFE` in a guest's user mode) raises the guest's privileged-instruction exception, vector 3 in the guest, and never reaches `HTRAP`.

**{{#halt-always-exits-exit-code}}** `HALT` always exits (exit code 2). A range of `TRAP #n` numbers is routed to the hypervisor by the 8-bit **hypercall mask** in bits 16 to 23 of `HTRAP`: bit k routes the numbers 32k to 32k + 31. That is the hypercall; it has no opcode of its own. A routed `TRAP` is a trap: the instruction completes, `HEPC` is the next instruction, the exit code is 22, and the vector in `HCAUSE` is 256 + n. It is routed at any guest mode. The mask is zero at reset. `WFE` traps by default and may be untrapped for a guest that owns a core; `SEV` traps by default so that the hypervisor limits it to the cores of the guest.

**{{#icinv-and-icinva}}** `ICINV` and `ICINVA`, and the unscoped `TLBIA` and `TLBSYNC`, trap by default for a guest ({{r:htrap-is-the-trap-control}}) because the time they take shows what the other guests are doing. The bits can be cleared for a guest that owns its core. `ICINV` and `ICINVA` are unprivileged and do not touch data, and a program that generates code needs them.

**{{#mfcpuid-is-privileged-each-guest}}** Reading `CPUID` is privileged. Each guest has a virtual core number, set by the hypervisor in `VCPUID` (16 bits). When a guest runs, `MFSR CPUID` returns `VCPUID`; at `H` = 1 they return the real core number. If the `CPUID` bit of `HTRAP` is set they exit instead (exit code 13).

### Exits, entry and what is saved

**{{#hexitr-says-why-the-guest}}** `HEXITR` says why the guest stopped, finer than the vector. The code is in bits 7 to 0 and two flags are in bits 9 and 8. `HEPC` is the address of the next instruction for a trap and an interrupt, and the address of the instruction for a fault (it is run again).

| Code | Reason | `HCAUSE` (vector) | `HEPC` is |
|---|---|---|---|
| 0 | an event taken at `H` = 1 (the hypervisor's own, not an exit) | its vector | as in {{r:entry-to-an-exception-or}} |
| 1 | machine check in a guest: a device answered a guest's real access, or a read of a stage-2 table, with an error | 1 | the instruction |
| 2 | `HALT` | 17 | next |
| 3 | `WFE` | 17 | next |
| 4 | `SEV` | 17 | next |
| 5 | `HINT #1` | 17 | next |
| 6 | `SPL` or `MTPS` priority change | 17 | next |
| 7 | `TLBI`, `TLBIA` or `TLBSYNC` | 17 | next |
| 8 | address-space register (`ASID` by `MFSR` or `MTSR`) | 17 | next |
| 9 | write to `PTBR` | 17 | next |
| 10 | write to `MMUCTL` | 17 | next |
| 11 | write to `VBR` | 17 | next |
| 12 | hypervisor register or `GENTER` used by a guest | 17 | next |
| 13 | core number | 17 | next |
| 14 | `ICINV` or `ICINVA` | 17 | next |
| 15 | `BPT` | 17 | next |
| 16 | single step | 17 | next |
| 21 | physical interrupt | the line's vector (32 to 63; 64 to 255 when message-signalled) | next instruction |
| 22 | hypercall (`TRAP` routed) | 256 + n | next |
| 23 | stage-2 fault: the entry is invalid | 18 (instruction fetch), 19 (load), 20 (store) | the instruction |
| 24 | stage-2 fault: the entry refuses the access (permission, a reserved bit set, accessed or dirty clear) | 18, 19, 20 | the instruction |
| 25 | stage-2 fault: the address is one that, by the platform map, no device answers (a table entry that points at nothing, or a guest's access to nothing) | 18, 19, 20 | the instruction |
| 26 | stage-2 fault: a stage-2 table lies outside the arena ({{r:guest-never-sees-a-stale}}) | 18, 19, 20 | the instruction |

**{{#exit-codes-and-vector-numbers}}** The codes and the vector numbers are numbered so that no number means two different things in the two registers: where a code names the same event as a vector it is that vector's number (code 1 and vector 1 are the machine check, code 15 and vector 15 the breakpoint), codes 2 to 16 are the exits for an instruction (vector 17), and no code is 17, 18, 19 or 20, which are the numbers of the hypervisor's own vectors.

Flags: bit 8 `WALK`: the failing access was the read of a guest page-table entry, so `HGPA` is the guest-physical address of that entry and `HEVA` the address the guest was trying to reach; bit 9 `VEC`: it was the guest's vector fetch, so `HGPA` is the guest's `VBR + 8 * vector`.

**{{#exit-enters-the-hypervisor-through}}** An exit enters the hypervisor through a **vector table** of 8-byte entries at the address `VBR + 8 * HCAUSE`, where `VBR` is the hypervisor level's own ({{r:while-h-is-1-hypervisor-registers}}) and the table is read through the hypervisor's own translation when it is on ({{r:hypervisor-level-translates-its-own}}): the same fetch as the kernel's ({{r:new-program-counter}}). The vectors are:

| Vector | Meaning |
|---|---|
| 17 | an exit for an instruction (all codes 2 to 16) |
| 18 | guest-physical instruction fault (a stage-2 fault on an instruction fetch) |
| 19 | guest-physical load fault |
| 20 | guest-physical store fault |

**{{#genter-enters-a-guest-before}}** `GENTER` enters a guest. Before it the hypervisor, at `H` = 1, loads the guest's state ({{r:world-switch-an-exit-followed}}) and writes `HEPC` and `HEPSW`. `GENTER` includes an `ISYNC` ({{r:write-to-ptbr-asid-or}}), discards the guest's cached translations if the arena's flag or the epoch word says so ({{r:guest-never-sees-a-stale}}), loads the status word from `HEPSW`, makes the guest's registers the live ones, loads the program counter from `HEPC`, clears `H`, and clears every register that its mask does not name ({{r:rti-mask-is-the-only}}). If a virtual interrupt line is pending and above the guest's priority, it is taken at the boundary before the first guest instruction. There is no operand that asks for a flush: the hardware decides.

**{{#rti-mask-is-the-only}}** **`RTI #mask` is the only form of `RTI`, and `GENTER #mask` is the only form of `GENTER`.** The mask has one bit for each of `R0` to `R31`; a register whose bit is one keeps its value, and the hardware clears every other register in the same step as the return to a less privileged mode (or the entry of a guest). `R14`, the banked stack pointer, is never cleared, so its bit is free and means: **keep the vector registers**; with it zero, the vector registers (the hidden accumulators included) and the floating-point sticky flags are cleared too. A return to the same mode ignores the mask. `RTT` returns and sets the trace bit after, and takes the mask as `RTI` does. The mask is in the instruction; no system register holds it. The hypervisor keeps nothing in registers across `GENTER`; the callee-saved set of the ABI (chapter {{c:id01003|n}}) says which registers a handler returning to a program must name, and `R16` to `R23` are caller-saved scratch.

**{{#exit-is-made}}** An exit is made in this order. *(1)* An event that aborts an instruction is undone ({{r:faults-and-restart-what-precise-means}}). *(2)* The reason and the vector are decided and the word at `VBR + 8 * HCAUSE` is read; a bus error here is a machine check of the hypervisor and nothing has been changed. *(3)* `HEPC` is written with the address of the instruction (an abort) or of the next instruction (a trap or an interrupt); `HEPSW` with the guest's whole status word, and with the token of {{r:vector-block-that-an-exception}} in its upper half when a block was suspended; `HEVA`, `HGPA` and `HINSN` as the table of {{r:hexitr-says-why-the-guest}} and {{r:registers-of-the-hypervisor}} say, else 0; `HEXITR` and `HCAUSE`. *(4)* `H` is set. The status word is made as in {{r:new-status-word-has}}: the current mode kernel, the previous mode the guest's current mode, priority 7, the trace bit, the flags and the guard clear. The names of {{r:while-h-is-1-hypervisor-registers}} mean the hypervisor level's own registers. *(5)* Any `LL` reservation is cleared, and the vector block's resume record is made as {{r:vector-block-that-an-exception}} says. *(6)* The program counter is the word read in step 2. Not written: any register of the guest, and no general register. Not done: no translation-buffer entry is removed and `GTBR` is not changed. A stage-2 fault on the vector fetch of the instruction's own entry (`TRAP`, `BPT`, a check trap) is an exit with `HEPC` at the instruction: it is retried.

**{{#world-switch-an-exit-followed}}** At a world switch (an exit followed by the entry of a guest) the hardware saves and loads only the guest's program counter and its status word. The hypervisor saves and loads the rest in software:

| What | How the hypervisor reaches it |
|---|---|
| `PTBR`, `EPC`, `EVA`, `ECAUSE`, `USP`, `SSP`, `EPSW`, `VBR`, `MMUCTL`, `ASID` | `MFSR` and `MTSR` of `GPTBR` to `GASID` |
| `R14` of the kernel mode and `DP` of the three modes | `GKSP`, `GKDP`, `GSDP`, `GUDP` |
| the general registers other than `R14` | ordinary loads and stores, and `GENTER #mask` naming the ones loaded |
| the floating-point status | `FSFLAGS`, an unprivileged instruction |
| `HTRAP`, `GTBR`, `VIRQ`, `VIVEC`, `VTOFF`, `VCPUID`, `GTIMECMP`, `GTOKEN` | `MFSR` and `MTSR` |

### Translation in two stages

**{{#translation-of-a-guest}}** Translation of a guest's memory is in two stages in hardware: the guest's page tables (**stage 1**) turn a guest-virtual address into a guest-physical address, and a second set of tables (**stage 2**), with a second root, turns that into a physical address ({{r:gtbr-holds-the-whole}}). A guest tag in each translation-buffer entry lets one guest's entries be invalidated without the rest ({{r:each-translation-buffer-entry}}); a fault in the second stage is an exit that reports the guest-physical address. The vector fetch and the page-table walk of a guest go through the second stage too, and a second-stage miss on either is an exit, not a machine check. `PROBER` and `PROBEW` in a guest test both stages; a second-stage miss exits (code 23 or 24) and the probe runs again after the hypervisor has filled it; a stage-1 miss gives the probe's ordinary answer.

**{{#gtbr-holds-the-whole}}** `GTBR` holds the whole of stage 2's identity in one register, so that one write changes the root and the tag together. Bit 0 is `S2EN` (stage 2 on; with it clear the guest-physical address equals the physical address); bit 1 is `NEW`, which a write sets to ask the hardware for a fresh tag and which reads as zero; bits 39 to 12 are the physical page number of the stage-2 root; bits 63 to 48 are the **guest tag**, 16 bits, 0 being the host; the other bits are refused ({{r:registers-of-the-hypervisor}}). **The guest tag is allocated by the hardware**: a write with `NEW` set puts into the tag field the next number of a 16-bit counter, after discarding every entry that carries that number in the translation buffer and in the IOMMU, so that a number handed out again is a new generation by construction; a write without `NEW` whose tag field is neither 0 nor a number the hardware has handed out is refused. The width is 16 bits everywhere (`TAGBITS` of {{r:one-read-only-system-register}}). A **stage-2 entry** is the page-table entry of {{r:page-table-entry}} with `U` and `G` required to be zero; a set `U` or `G` is a refused entry. Stage 2 has three levels of 512 entries over a root of **one page**, as every root has, so that it covers the 39-bit guest-physical space; `LEVELS` and `PABITS` of {{r:one-read-only-system-register}} tell software how many levels and how wide a machine has. The accessed and dirty bits of stage 2 are managed by software like stage 1's ({{r:accessed-and-dirty-bits}}): a clear `A`, or a clear `D` on a write, is a refused entry, code 24, which gives the hypervisor dirty-page tracking. The permissions of an access are those of both stages together, the size of the page that the buffer holds is the smaller of the two, and **the stricter memory type wins**: the memory type of an access is the largest of three terms, the type of the stage-1 entry, that of the stage-2 entry, and the type that the **platform map** gives the physical address; the codes run in the order of strictness (cached 0, uncached 1, device weakly ordered 2, device strongly ordered 3), so the largest code is the strictest. The platform map of device ranges replaces the old device bit of the address.

| Bits of `GTBR` | Field | Meaning |
|---|---|---|
| 0 | `S2EN` | stage 2 on |
| 1 | `NEW` | write: allocate a fresh tag |
| 39 to 12 | root | physical page number of the stage-2 root |
| 63 to 48 | `GTAG` | the guest tag; 0 is the host |
| the rest | | zero (a write of a one is refused) |

**{{#what-stage-2-does}}** What stage 2 does for each access of a guest. A guest page-table entry that stage 1 reads has a guest-physical address, which goes through stage 2 before it is read, and so does the final guest-physical address; with n levels in stage 1 and m in stage 2 a miss reads nm + n + m entries (15 for three and three), and a guest with its translation off walks stage 2 only. A stage-2 entry that is invalid or refuses the access is an exit: code 23 or 24, with `HCAUSE` 18, 19 or 20 for an instruction fetch, a load or a store; `HEPC` is the faulting instruction, `HEVA` the guest-virtual address, `HGPA` the guest-physical address that failed (for a table read, the address of the entry and the flag `WALK`; for the vector fetch, the guest's `VBR + 8 * vector` and the flag `VEC`) and `HINSN` the instruction. The hypervisor fills or corrects the entry, sets `A` and, for a write, `D`, and enters; the guest runs the instruction again. The same holds for a miss inside an exception entry of the guest: the instruction is undone. On the vector fetch of a guest's exception or interrupt, a miss exits with nothing changed, so that the guest takes the exception after the fill; a virtual line stays pending. **A bus error on a stage-2 table read or on a guest's access is split by what the platform map says about the address, not by what the bus does:** if the map says that no device answers there, it is an exit the hypervisor can handle (code 25; for a table read, the entry points at nothing, which is an invalid entry); if a device is there and answers with an error, it is a machine check (code 1). The same program on two interconnects gets the same exit.

**{{#each-translation-buffer-entry}}** Each translation-buffer entry is keyed by the guest tag, the address-space number, the guest-virtual page and the global bit, and holds the final physical page and the permissions of both stages. A hit needs the tag to match, and the global bit means global within the tag. While a guest runs the buffer uses the tag in `GTBR`. An invalidate acts as follows. *(a)* A guest's own `TLBI`, `TLBIA`, `TLBSYNC` and `MTSR` of `ASID`, when not trapped, act on entries of its own tag only, on every core. *(b)* The rules of {{r:writes-to-mmuctl-ptbr}} and {{r:reset-leaves-no-cached-translation}} apply per tag. *(c)* A write to `GTBR` that changes the root or `S2EN` discards every entry of the tag it writes; a write that changes only the tag discards nothing. *(d)* **`TLBIAS`** (invalidate by address-space number) exists: it invalidates every entry of an address-space number, in the issuer's tag, on every core, waited for by `TLBSYNC`. *(e)* **An invalidate by guest-physical page, `TLBIGP rN`, is a separate mnemonic**, used by the hypervisor after a change to a stage-2 entry; the hypervisor's `TLBI` of the guest-virtual form is not used for that. `TLBIGP` is legal only at `H` = 1: a guest in kernel mode that executes it exits with code 12, in a guest's user mode it is the guest's own privileged-instruction exception, and on a machine with `HVE` = 0 it is an illegal instruction. `TLBIAS` in a guest exits under the same `HTRAP` bit as `TLBI`. A change to a stage-2 entry that was valid is followed by an invalidate for the guest and `TLBSYNC`. As in {{r:writes-to-mmuctl-ptbr}} an implementation may discard more than these rules require, and no program may depend on an entry surviving.

**{{#guest-never-sees-a-stale}}** **A guest never sees a stale translation of a changed stage-2 table**, and the hypervisor is not asked to remember how that is kept. *(a)* The hypervisor tells the hardware its **arena** by `HARENA`: one contiguous run of real pages, the first page number in bits 55 to 28 and the number of pages in bits 27 to 0; zero means no arena. Every stage-2 table must lie inside the arena, and a stage-2 walk that reads an entry outside it is an exit with code 26. *(b)* A store by this core into the arena, and every write of a guest's translation register at `H` = 1 (`GTBR`, `GPTBR`, `GASID`, `GMMUCTL`), even with the same value, sets a flag; `GENTER` discards every cached translation of the guest, and clears the flag, if it is set. *(c)* **When no arena is set the flag is always set**: every guest entry discards the guest's translations, so the safe thing is what happens when nobody did anything, and the fast path is asked for by setting an arena. There is no flush bit. *(d)* **A device never writes the arena**: the IOMMU refuses a device write to an arena page, as it refuses a device write to a system register, and counts it. *(e)* **Other cores are covered by an epoch word in memory**: `HEPOCH` holds the real address, inside the arena, of a 64-bit word; a core that has stored into the arena adds one to it with one atomic add at its next guest entry or its next `FENCE`; a core entering a guest loads the word and, if it differs from the value that core kept at its last discard, discards every cached translation of the guest and keeps the new value. An edit of a stage-2 table therefore takes effect for another core when the editing core publishes it, at its next entry or barrier; a guest already running on another core keeps the translations it has until it exits, and the hypervisor stops it sooner with an interrupt, which always exits ({{r:physical-interrupt-always-exits-exit}}).

### Interrupts, timer, devices, nesting

**{{#physical-interrupt-always-exits-exit}}** A physical interrupt always exits (exit code 21), whatever the guest's priority; the vector of the highest line (the highest level, then the lowest vector number) is in `HCAUSE` and the next instruction in `HEPC`; the line stays asserted until the hypervisor clears it at the device.

**{{#guest-sees-seven-virtual-interrupt}}** A guest sees seven **virtual interrupt lines**, one for each priority level 1 to 7. `VIRQ` bit L, for L from 1 to 7, says line L is pending; bit 0 reads zero. `VIVEC` has a field of 8 bits for each line (line 1 in bits 7 to 0, line 7 in bits 55 to 48) that holds the vector number the guest takes; **a write that puts a vector below 32 in a field is refused at once with an illegal instruction**. The hypervisor injects an interrupt by setting the bit of the line. Between two instructions of a guest, if no physical interrupt is asserted and the highest pending line L is above the priority in the guest's status word, the core makes the guest's own exception entry ({{r:exceptions-interrupts-and-traps}}) with the vector of the line: the vector word is read at the guest's `VBR + 8 * vector` through stage 2, `EPC` is the next instruction, `EPSW` the old status word, `EVA` 0, `ECAUSE` the vector, the new status word is kernel mode with priority 7, and the hardware **clears the bit of the line** (for line 6 only the bit that the hypervisor set; the timer's part follows the comparator, {{r:timer-is-two-system-registers}}). No exit is made. A guest's `SPL` and `MTPS` never exit (unless `PRIO` of `HTRAP` is set). A physical interrupt at the same boundary exits first. `WFE` in a guest ends when a virtual line is pending, even if the priority masks it ({{r:wfe-ends-its-sleep-when}}).

**{{#timer-is-two-system-registers}}** The timer is two system registers, **`TIME`** (number 16, read only) and **`TIMECMP`** (number 17). `TIME` is one 64-bit counter for the machine, which counts at a fixed 10 MHz, cannot be written, and never goes back: a read that begins after another core's read has finished is not smaller. `TIMECMP` is the core's deadline, an absolute counter value; **zero means never**, and it is zero after a machine reset. While `TIME` is at or past a deadline that is not zero, the core's timer line is asserted, as a **level**, at level 6, vector 32; software clears it by writing a later deadline or zero. A write to `TIMECMP` takes effect before the next instruction, so an interrupt is never taken for a deadline that the write removed. There is no periodic mode: a periodic tick is the handler adding the period to the old deadline. At the hypervisor level the two names reach the real counter and the real comparator, which keeps running while a guest runs. In a guest `TIME` is the real counter minus `VTOFF` (a register of 64 bits), and `TIMECMP` is the guest's own comparator; while the guest's counter is at or past a deadline that is not zero, **virtual line 6 is asserted as a level**, in addition to the bit of `VIRQ` that the hypervisor may set. A guest has no way to read the real counter. The hypervisor loads the guest's deadline before `GENTER` and saves it after an exit through `GTIMECMP` (number 148), which is zero after a machine reset and after a guest reset; while the hypervisor runs, the guest's comparator keeps running and a virtual line is not delivered until the next entry, and a hypervisor that does not want that writes zero. With `HVE` = 0, `GTIMECMP` is an illegal instruction and `VTOFF` counts as 0. No unprivileged instruction reads the counter ({{r:every-instruction-that-reveals-or}}).

**{{#device-can-be-assigned}}** A device can be assigned to a guest through the IOMMU of {{r:iommu-a-page-table-per-device}}. In version 1 the guest's unit is virtual and trapped: the hypervisor forwards the guest's commands and faults, and there is no guest-visible hardware ring. The interrupt controller's side for a core is system registers, readable and writable at the kernel level only; the interrupt page exists for devices only, is reached through the IOMMU's per-device table, and **refuses any access from a core**. A guest's version of the controller is the seven virtual lines of {{r:guest-sees-seven-virtual-interrupt}}.

**{{#there-is-no-nested-virtualization}}** There is no nested virtualization in version 1: a guest's use of any hypervisor register or of `GENTER` exits with code 12, after the guest's own privilege check, and the hypervisor may make it look like an illegal instruction.

### Vector blocks, instruction guarantees, reset, first software

**{{#vector-block-that-an-exception}}** A vector block that an exception or an exit interrupts **resumes where possible, and resume is optional**: an implementation that keeps no record is a conforming implementation, and no program may depend on resuming. The hardware keeps one hidden **resume record** for each core: the address of the block's `VEC`, the tag of the context (guest tag, address-space number, mode, and whether the hypervisor is running), the entry and current values of the changed registers, and a one-use **token**. A block that changes more than **four** registers has no record and starts again. The handler is shown the entry values of the registers, `EPC` at the `VEC`, and the token in bits 63 to 32 of `EPSW` (`HEPSW` for an exit). The block resumes at the strip where it stopped only if the return carries the record's token, goes to the address of the `VEC`, has the record's context, and finds the changed registers at their entry values. The record is discarded, and the block starts again from its first strip, with its sums zero, on: any vector instruction that is not a resume; a write to `ASID`, `PTBR`, `MMUCTL` or `GTBR`; `GENTER` into another guest; `ICINV`, `ICINVA`, `TLBI`, `TLBIA`, `TLBIAS`; a return that presents the token but fails a check; a machine check; a later suspension; reset. The record stays on its core and dies, never moves, if the context moves to another. The **token** is a keyed permutation of a counter that the hardware keeps for each guest, 32 bits wide, so that it does not repeat within 2^32 suspensions of one guest and shows a guest nothing of other guests' suspensions; the hypervisor loads the guest's key and counter by `GTOKEN` with the rest of the guest's state. A block covers at most **256 strips**; a longer job is cut into blocks. An interrupt or an exit is taken at a **strip boundary**, never inside a strip; a strip commits all its stores or none. `VCLR` outside a block is refused: **`VCLR` is valid only inside a block**. A block with accumulators whose main loop stores through the register that it loads through is refused at the `VEC`, before any work. The size of the strip is not hidden: `STRIP` of `FEATURES` gives it. A block is not atomic against other writers of memory.

**{{#four-more-guarantees}}** Four more guarantees that a guest and a native kernel share. *(a)* **`ISYNC` is the instruction-stream fence in every mode**, unprivileged: a program that writes code, invalidates with `ICINV` and executes `ISYNC` runs the new code. *(b)* A block operation (`MCPY`, `MSET`) writes **each aligned 8-byte unit whole and at most once**, and no order is promised to a second observer. *(c)* The floating-point flags are cleared when the address-space number, the guest register `GTBR` or the page-table base is written. *(d)* Every hole and information bleed this section closes has a test in the assembler corpus.

**{{#table-gives-for-every-register}}** The table gives, for every register and for the state that is not in a register, what a core holds after a machine reset and what the hypervisor puts a guest in by a guest reset. A guest after a guest reset is a machine after a machine reset, except that the hypervisor's registers keep the hypervisor's values and `CPUID` returns the guest's virtual core number.

| Register | After a machine reset | After a guest reset |
|---|---|---|
| status word | kernel mode, previous mode kernel, priority 7, trace 0, flags 0, guard 0 | the same |
| `PC` | the platform's reset entry | the guest's reset entry, in `HEPC` |
| 0 `PTBR`, 1 `EPC`, 2 `EVA`, 3 `ECAUSE`, 6, 7 `USP`, `SSP`, 8 `EPSW`, 9 `VBR`, 10 `MMUCTL`, 11 `ASID` | 0 (translation off) | 0 (through `GPTBR` to `GASID`) |
| 12 `CPUID` | the core number | `VCPUID` |
| `R14` of the kernel mode | set by the platform's boot protocol (chapter {{c:id01004|n}}) | set by the hypervisor's boot protocol |
| the other `R14` copies and the three `DP` | 0 | 0 |
| the general registers other than `R14`; the vector registers | 0 | zero, set by the hypervisor |
| the floating-point status | 0 | 0 |
| any `LL` reservation, the resume record | cleared | cleared |
| cached translations of the guest's tag | none | none |
| 128 `HTRAP` | `WFE`, `SEV`, `TLBIA`, `TLBSYNC` and `ICINV` set, the rest 0 | the hypervisor's policy |
| 129 to 135 `HEXITR`, `HEPC`, `HEPSW`, `HEVA`, `HCAUSE`, `HGPA`, `HINSN` | 0 | not defined; `HEPC` and `HEPSW` are the resume point |
| 137 `GTBR` | 0 | the guest's root, `S2EN` set, its tag |
| 138, 139 `VIRQ`, `VIVEC` | 0 | 0 |
| 140 `VTOFF` | 0 | the hypervisor's value |
| 142, 143 `HARENA`, `HEPOCH` | 0 | not a guest's |
| 144 `GTOKEN` | 0 | the hypervisor's value |
| 16 `TIME` | counts from 0 | the guest's counter starts where `VTOFF` puts it |
| 17 `TIMECMP`, 148 `GTIMECMP` | 0 (never) | 0 (never) |
| 141 `VCPUID` | 0 | the guest's virtual core number |
| 149 to 162 | 0 | 0 |

**{{#there-is-no-hardware-event}}** There is no hardware event for a guest reset: no instruction resets a guest. A guest asks for a reset by a hypercall or by touching a virtual device, and both exit. The reset is an operation of the hypervisor, in this order. *(1)* Stop the guest's cores. *(2)* For each device assigned to the guest, block it and invalidate the unit's translations for the guest tag ({{r:guest-tag-has-the-same}}), and wait for the unit. *(3)* Write `GTBR` with the new root (the hardware discards the old translations, {{r:each-translation-buffer-entry}} and {{r:guest-never-sees-a-stale}}), then write the guest's `MMUCTL` as 0. *(4)* Write every system register and every other piece of state to the value of the table of {{r:table-gives-for-every-register}}. *(5)* Zero the general registers and the floating-point status, set `HEPSW` to the reset status word and `HEPC` to the guest's reset entry, and execute `GENTER` with the mask of the registers it loaded. The hardware, not this sequence, keeps the old guest's translations from the new one.

**{{#first-software-to-use-all}}** The first software to use all of this is a small hypervisor of our own, on the QEMU target, with one guest kernel; it is not Linux and not KVM. It is written in assembler, in one file with the guest kernel; it boots at `H` = 1 on physical addresses, builds its own vector table and its stage 2, routes a range of `TRAP` numbers to itself for the guest's console output, gives the guest a virtual core number, a virtual timer and a virtual line for it, and enters the guest. The guest builds its own page tables and turns translation on, touches a page that stage 2 does not map yet (the hypervisor maps it and the instruction runs again), takes its timer interrupt, runs a user program that makes a system call that must not exit, and stops with `HALT`; the hypervisor handles every exit.

## {{#kernel-what-was-checked}} What was checked, and what was not

The rule of the project is to check and not to guess. The handbooks for the PDP-11 and the VAX are not on this machine. What was available, and what each fact rests on:

* **Checked against the Unix sources on this machine** (`<work>/facetlang/unixtree`, files gzipped: the V7M kernel under `V7M/sys` and 2.11BSD under `2.11BSD/sys`): the V7 vector table (`conf/l.s`: the pairs `trap; br7+n`, the console at 060 and 064 at `br4`, the clock at 0100 at `br6`; the file has no `. = ZERO+4` line, the vectors follow a branch and the word 4 at 0 and 2); the processor-status address 0177776 (`PS` in 2.11BSD `mch_iopage.h`) and the status fields in `pdp/psl.h` (`PSL_CURMOD`, `PSL_PRVMOD`, `PSL_IPL`, `PSL_T`, the condition codes); the KT11 register addresses in `pdp/seg.h` (`UISD` 0177600, `UISA` 0177640, `KISA0` 0172340, `KISA6` 0172354); `trap(dev, sp, r1, nps, r0, pc, ps)` and its comment; the system-call dispatch `sysent[fuiword((caddr_t)(a-1))&077]` (V7 `sys/trap.c`); `estabur()` and `sureg()` (eight page-register pairs per mode, sixteen with separate instruction and data space, `ENOMEM` when the segments exceed eight or the image exceeds memory, the segment of at most 128 blocks of 64 bytes); the first-fit core allocator (`malloc.c`: "The core map unit is 64 bytes", "Algorithm is first-fit"); `mfpi`, `mtpi` and the `nofault` global in `mch_i.s`; the `wait` of the V7 and 2.11BSD idle routines; the artificial trap 12 "give up cpu" of the interrupt exit when `_runrun` is set, and the write of 1 to `SSR0` (`mch_i.s`); the comments that the floating exception is an imprecise trap and that `backup()` may fail on the 11/40 (2.11BSD `pdp/trap.c`); supervisor mode used by the 2.11BSD network (`SUPVMODE`); `sched()`, `swapout()` and `swapin()` by name; the comment about "18 bit controllers present in" 22-bit Q-bus systems (2.11BSD `machdep.c`).
* **Checked against the QEMU sources** (`<work>/qemu-src`): RISC-V's `satp` modes 8, 9 and 10 (Sv39, Sv48, Sv57), its 16-bit address-space field, its entry bits `V R W X U G A D` in bits 0 to 7 and its page number at bit 10, its `SUM` bit; x86's `CPUID` leaf 0x80000008 and the `PCIDE` bit of `CR4`; AArch64's `ID_AA64MMFR0` field `PARange`; LoongArch's `CPUCFG1` fields and `PWCL` register.
* **Checked against the repository:** the statements of this chapter against `docs/pdp64-isa.md` sections 7 and 8, `docs/pdp64-system-architecture.md`, `docs/kernel-pain-points.md` and `docs/hardware-vulnerabilities.md`. The vector numbers and system-register numbers are those of the generated constants (`qemu/target-pdp64/gen/pdp64-consts.h`), which come from the grammars.
* **The repository's sizing, not measured:** the kernel survey's estimate of four or five instructions for a system-call entry, against 45 to 70 on RISC kernels (`docs/kernel-pain-points.md`).
* **Unverified** (general knowledge, the handbooks not being on this machine): the names **APF**, and the layouts of the **PAR** and **PDR** beyond what the 2.11BSD code shows (the length field and the access and extension bits); that the KT11 gave 18-bit physical addresses on the original models and 22 bits on later ones; that the I/O page is the top 8 KB of the physical space; the bit positions of the status word apart from those 2.11BSD's header gives; `MMR1` as the register that recorded the auto-increment changes (the repository's text says so, and the 2.11BSD `backup()` routine is its user); the VAX's regions, modify bit and missing reference bit, its entry sequence, its process and system halves, its `MTPR`, its protection field and its `PROBER` use; that the 68000 had no restart path; that MIPS refills its buffer in software; the width of x86's process-context tag and the five words x86 pushes; AArch64's two translation base registers, `PAN`, hardware-managed accessed and dirty bits and broadcast invalidate; x86 rings, AArch64 exception levels and RISC-V modes; the usual meanings of "strongly ordered" and "weakly ordered"; whether the PDP-11 forbade `WAIT` outside kernel mode; that current architectures keep exceptions precise for page faults.
* **Checked in {{r:running-a-kernel-under-a-kernel}} to {{r:hypervisor-mode-the-rules}}** (every sentence quoted was found in the document named, on the date given; quotations are under 25 words):

  * R. J. Creasy, "The Origin of the VM/370 Time-Sharing System", *IBM Journal of Research and Development* 25(5), September 1981, pages 483 to 490. https://lass.cs.umass.edu/~shenoy/courses/fall07/papers/vm370.pdf, read 2026-11-25. "CP is an operating system that uses a computing machine to simulate multiple copies of the machine itself." "they required a dedicated hardware system, usually at night or on weekends". "CP and CMS have seen continuous production use since 1967." "VM/370 became available in 1972 for the IBM System/370 computer family whose members all included virtual memory hardware." "The CP/CMS system was conceived in 1964 as a second-generation time-sharing system for the newly announced IBM System/360." The system was designed and built by Creasy and his group at "the IBM Systems Research and Development Center in the mid-1960s", now the IBM Scientific Center in Cambridge, Massachusetts. The text extraction of the page that dates CP-40 and CMS misreads a digit, so no year is printed for them. "As they are encountered in problem state, the machine blocks their execution and transfers control to a designated program."
  * G. J. Popek and R. P. Goldberg, "Formal requirements for virtualizable third generation architectures", *Communications of the ACM* 17(7), July 1974, pages 412 to 421. https://course.ece.cmu.edu/~ece845/docs/p412-popek.pdf, read 2026-11-25. "A virtual machine is taken to be an efficient, isolated duplicate of the real machine." Theorem 1 as quoted in {{r:running-a-kernel-under-a-kernel}}. "Another example of a control sensitive instruction is JRST 1, on the DEC PDP-10, which is a return to user mode." The key words of the paper include "hypervisor, virtual machine monitor".
  * G. J. Popek and C. S. Kline, "The PDP-11 Virtual Machine Architecture: A Case Study", *Proceedings of the Fifth Symposium on Operating System Principles*, ACM, 1975, pages 97 to 105, doi 10.1145/800213.806527. https://bibtex.github.io/SOSP-1975-PopekK.html, read 2026-11-25: **the bibliographic record only; the text of the paper was not read.**
  * O. Agesen, J. Mattson, R. Rugina, J. Sheldon, "Software Techniques for Avoiding Hardware Virtualization Exits", USENIX ATC 2012. https://usenix.org/system/files/conference/atc12/atc12-final158.pdf, read 2026-11-25: Table 1 starts with Intel Prescott, launch date 3Q2005.
  * RISC-V, privileged architecture, chapter {{c:id01001|n}}4.1 '"H" Extension for Hypervisor Support, Version 1.0', in the Ratified Specifications Library, v20260120. https://docs.riscv.org/reference/isa/v20260120/priv/hypervisor.html, read 2026-11-25. "to support the efficient hosting of guest operating systems atop a type-1 or type-2 hypervisor". No ratification date was found on the page.
  * *PDP-11 Processor Handbook*, 1979 edition (read 2026-11-19): `HALT` traps outside kernel mode; outside kernel mode "the processor will ignore the 'RESET' and 'SPL' (Set Priority Level) instructions, and will execute No Operation".
  * CVE-2026-99312 (Linux kernel, KVM x86), published 2026-11-18. https://cveawg.mitre.org/api/cve/CVE-2026-99312, read 2026-11-25: "an INIT while L2 is running with CR0.PG=0 will result in KVM running L1 with a stale MMU context".
  * *Not checked, and so not stated:* the date of the PDP-11's announcement; the content of Popek and Kline's paper; the dates of CP-40, CMS and of the RISC-V and Arm virtualization extensions; the first use of the word "hypervisor"; the virtualization of the VAX, of the x86 before 2005, and of Arm; present industrial uses; the name or the operating systems of other PDP-11 systems (the scene of {{r:running-a-kernel-under-a-kernel}} names none for that reason); the date of IBM's interpretive-execution mode; seL4's use as a hypervisor (said only as the aim of this project).
* **Decided:** everything stated as a decision; the illustrations of {{r:kernel-at-work-four-walks}} and {{r:reset-and-the-first-kernel}} are not decisions.
