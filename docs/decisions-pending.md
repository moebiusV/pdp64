# Decisions waiting for the author

[← pdp64 index](../README.md)

**Status: written 2026-10-22 for the author's review; facts about other systems were checked on 2026-10-22 as far as sources could be read (appendix at the end; data in `docs/codegen-data/verification/claims.csv`).** Nothing in this document is decided unless it says so. For each open decision there is: the **need**, a plain **explanation**, the **current state** in the documents, **five options**, my **recommendation**, and what happens if nothing is decided. Each decision also says **what current systems do** and **how the recommendation compares**. Instruction counts come from the kernel survey (static counts in the sources). Claims about the PDP-11 and VAX were checked against the V7 and 3BSD/4.3BSD sources in the local Unix tree and the DEC handbooks on archive.org (PDP-11/70 1977-78, PDP-11 04-55 1976, VAX Architecture Handbook 1977, VAX-11 Architecture Reference Manual Rev 6.1 1982, VAX 6000 Vector Programmer's Guide); other claims against the RISC-V ISA manual snapshot, the Intel SDM text (felixcloutier mirror), the clang, Linux and OpenBSD sources and OpenBSD's vmm(4) page. **A marker reading "(from memory, not confirmed in the sources read)" means no source for that statement was read in this pass (mostly the Arm, Power ISA, SPARC, s390, Alpha and MIPS manuals; kernel and compiler source was used where it settles a claim and is labelled as practice, see the appendix); treat those as leads.**  Numbers from the kernel survey are static counts of instructions written in the sources, not measurements of how often they run.

**Decided 2026-10-22 (errata 42 to 46):** the no-mode-bits rule is a soft rule, and P2, P10, P11 and P13. Their sections are kept as the record.

Context for all of them: the operating system order is now OpenBSD first through the LLVM back end, Unix/32V as the fallback (errata 41). The FPGA and ASIC implementations are small in-order cores, and the architecture is to be kept ready for a large out-of-order design (errata 38). The machine is one core today; SMP, DMA devices and virtualization are not yet defined.

## Contents

* [Part 0. Your principles, the rule change, and how the options are judged](#part-0-your-principles-the-rule-change-and-how-the-options-are-judged)
* [How to read this](#how-to-read-this)
* [Summary table](#summary-table)
* [Already decided, listed so they are not asked twice](#already-decided-listed-so-they-are-not-asked-twice)
* [P1. The wake rule of `WFE`](#p1-the-wake-rule-of-wfe)
* [P2. The kernel's access to user memory (a guard)](#p2-the-kernels-access-to-user-memory-a-guard)
* [P3. An unprivileged time counter](#p3-an-unprivileged-time-counter)
* [P4. Feature and identification registers](#p4-feature-and-identification-registers)
* [P5. Invalidating the TLB by address-space tag](#p5-invalidating-the-tlb-by-address-space-tag)
* [P6. Data-cache maintenance by address](#p6-data-cache-maintenance-by-address)
* [P7. Firmware calls and the missing `RESET`](#p7-firmware-calls-and-the-missing-reset)
* [P8. Double-width compare-and-swap](#p8-double-width-compare-and-swap)
* [P9. A source of random numbers](#p9-a-source-of-random-numbers)
* [P10. The direct-mapping windows and `MMUCTL`](#p10-the-direct-mapping-windows-and-mmuctl)
* [P11. Atomics on the bus: a lock or a monitor](#p11-atomics-on-the-bus-a-lock-or-a-monitor)
* [P12. What a multi-register instruction leaves behind when it faults](#p12-what-a-multi-register-instruction-leaves-behind-when-it-faults)
* [P13. `long double`](#p13-long-double)
* [P14. Confirm: priority 7 on interrupt entry as well as exception entry](#p14-confirm-priority-7-on-interrupt-entry-as-well-as-exception-entry)
* [P15. Prefetch](#p15-prefetch)
* [P16. Performance counters](#p16-performance-counters)
* [P17. Constant-time execution](#p17-constant-time-execution-a-timing-channel-defence)
* [P18. The literal pool and execute-only code](#p18-the-literal-pool-and-execute-only-code)
* [Part B. Previous decisions, written up so they can be changed](#part-b-previous-decisions-written-up-so-they-can-be-changed)
* [Part C. The gaps: several cores, DMA devices and virtualization](#part-c-the-gaps-several-cores-dma-devices-and-virtualization)
* [Part D. Vector and SIMD math](#part-d-vector-and-simd-math)
* [Appendix: errata 42 to 46 in full](#appendix-errata-42-to-46-in-full)
* [What I need from you](#what-i-need-from-you)

## Part 0. Your principles, the rule change, and how the options are judged

**The rule change (errata 42).** All the design rules are soft. Several arguments earlier in this document leaned on "the ISA has a rule against that"; under errata 42 they count as costs and benefits like any others. P10 was the clearest case (decided: `MMUCTL` stays). Q9 option 4 is revised below.

**Your principles (2026-10-22), in order, and the test I apply to every option:**

1. **Code size.** Bytes of kernel and user code, including hot-path length and the code spent on error handling. An instruction that makes common sequences shorter wins.
2. **Easy recoverability, meaning less recovery code.** Fewer possible errors means less code to handle them, and an easier recovery path means less code to write it. So an option scores well when it adds **fewer distinct failure outcomes**, makes a fault **restartable without special cases** (precise exceptions, no hidden state, a restart that repeats safely), and avoids partial results the handler would have to undo. A feature that adds a new fault, a new error return or a new "half done" state costs recovery code in every kernel that uses it.
3. **Speed and efficiency through fewer gates and tighter hot loops.** Simpler hardware (fewer states, fewer special paths, less logic on an FPGA), and faster by *careful instruction choice*: the shortest sequences for the operations that run constantly (system-call entry and exit, context switch, copy to and from user memory, atomics, string and block loops, interrupt entry), not by adding hardware.

All the rules are soft (errata 42). The README states these principles in its design paragraph and gives the examples in "How the principles show up".

**What changed because of this.** The table lists every decision with the priority it mostly serves, my pick under the new test, and whether the pick moved.

| # | Mostly serves (principle) | Pick now | Changed? |
|---|---|---|---|
| P1 `WFE` wake rule | recovery (no lost wake-up to detect and repair), gates | wake on pending | no |
| P2 user guard (decided) | recovery (a bad kernel pointer becomes a clean fault, not corruption) | `UA` + `stua`/`clua`; later maybe 2-byte page-2 forms | decided; small addition noted |
| P3 `rdtime` | hot loop (clock read without a trap) | add | no |
| P4 feature registers | code size (one binary adapts) | `mfsr` registers | no |
| P5 TLB invalidate by ASID | hot loop, gates | add; priority raised from medium | **raised** |
| P6 cache maintenance | gates | reserve nothing | no |
| P7 firmware calls | recovery, gates | devices only, **plus a required reset/watchdog register** | **addition** |
| P8 double-width CAS | gates | defer | no |
| P9 random numbers | gates | entropy device | no |
| P10 `MMUCTL` (decided) | gates, recovery | stays | decided |
| P11 atomics (decided) | gates | monitor | decided |
| P12 partial effects of multi-register instructions | **recovery** | every multi-access instruction all-or-nothing or safely repeatable, **with a test** | **strengthened** |
| P13 `long double` (decided) | code size, gates | `double` | decided |
| P14 priority 7 on all entries | recovery (removes a window that needs repair code) | confirm | no |
| P15 prefetch | hot loop, gates | none, reserve the shape | no |
| P16 performance counters | gates | two counters after P3, or defer | no |
| Q2 software accessed/dirty bits | gates against recovery code | keep for v1; **under your recovery priority option 3 (optional hardware) gains** | **flagged** |
| Q9 64-bit-only ALU | code size, hot loops | **measure now; add 32-bit forms if the extension overhead is a few percent** | **moved** |
| Q10 devices | code size, gates | eight registers; **virtio only if reusing OpenBSD's drivers saves more than it costs** | **softened** |
| R1 interrupt controller | gates | **wired lines to core 0 plus a per-line target register; messages later** | **moved** |
| R4 bus protocol | gates | AXI as the transport | strengthened |
| R8 virtualization | gates | out of scope, five constraints | no |
| S1 to S6 vectors | gates, code size | coprocessor; measure before packed lanes | strengthened |
| all other Q and R items | as before | as before | no |

The sections below keep their original text and recommendations; where a pick moved, a **Revised for your principles** paragraph is added at the end of that section.

---

## How to read this

Two terms recur. A **mode bit** (ISA section 1.1) is a bit whose value changes the meaning of unrelated instructions; the ISA used to have a rule against adding them, because a mode bit has to be saved and restored when one program is switched for another; since errata 42 that is a cost to weigh, not a ban. **Precise** exceptions mean that when an instruction faults, every earlier instruction has completed and no later one has had any effect, so the faulting instruction can simply be run again.

The options are listed best-first by my judgement, not by cost. "Cost to build" always means the work in the assembler grammar, `as64`, `sim64`, QEMU, the LLVM generator and the tests, which is mostly mechanical because the grammars generate the numbers.

## Summary table

| # | Decision | My recommendation | Blocks or helps |
|---|---|---|---|
| P1 | `WFE` wakes on a pending interrupt even if masked | wake on pending (**open**: an earlier answer was recorded by mistake and is withdrawn) | idle loop of any kernel |
| P2 | Guard against the kernel touching user memory by mistake | **decided, errata 43**: PSW bit `UA` plus `stua`/`clua` | hardening; OpenBSD (checked: it enables SMAP) |
| P3 | Unprivileged time counter | `rdtime rd` instruction | fast clock reads from user code |
| P4 | Feature and identification registers | read-only `mfsr` numbers 13 and up | portable kernels and libraries |
| P5 | TLB invalidate by address-space tag | one new `TLBIASID` | context-switch cost, SMP |
| P6 | Data-cache maintenance by address | reserve the encoding, build nothing yet | only a non-coherent DMA device |
| P7 | Firmware-call convention | none; devices only | boot, reboot, power-off |
| P8 | Double-width compare-and-swap | no | lock-free structures (rarely) |
| P9 | Random numbers | an entropy device on the bus, no instruction | OpenBSD's early boot (from memory, not confirmed in the sources read) |
| P10 | `DMW` format and `MMUCTL` | **decided, errata 44**: `MMUCTL` stays, `DMW` deferred | boot, ISA consistency |
| P11 | Bus atomics: lock or monitor | **decided, errata 45**: monitor | the second core and any shared-queue device |
| P12 | Partial effects of `pushm`, `popm`, `pushx`, `popx` on a fault | accept and document, with one rule | restart correctness |
| P13 | `long double` | **decided, errata 46**: `double`, ABI version 2 for binary128 | libc, clang, the ABI |
| P14 | Priority 7 also on interrupt entry | confirm | exception entry |
| P15 | Prefetch instruction | none for now; reserve the shape | list and copy loops (from the kernel survey) |
| P16 | Performance counters | cycle and instruction counters after the clock (P3) | profiling |
| P18 | Literal pool out of `.text` so code can be execute-only | proposed: option 1, an ABI rule (a read-only pool section next to the text) | OpenBSD's execute-only mitigation |
| P17 | Constant-time execution (timing-channel defence) | proposed: option 3 (a core set always constant-time plus a `DIT` bit for divide, `mscn`, `mcmp` and floating point); option 4 costs about 1% on average by a rough estimate | cryptography; the hardware-vulnerability rules |

## Already decided, listed so they are not asked twice

| What | Where decided |
|---|---|
| Flags are two groups, `C` and `{N, Z, V}`; `cbCC`, moves, loads and stores write no flags; shifts write the same flags for any count; `mscn` writes all four; rotates and `dshr` write no flags; `ASL` keeps `V = N xor C` | errata 39 and the author's ruling |
| `ISYNC` and `HINT` exist (Q15 reopens the idea behind `ISYNC` for review) | errata 39 |
| The multi-access block instructions' internal accesses are unordered with respect to each other; `pushm` with `r14` in the list is reserved; page-table entry changes need `TLBI`; no speculative loads from device pages | errata 39 item 7 (the text is still to be written into the ISA) |
| Exception entry sets priority 7 (P14 asks you to confirm the part about interrupts) | errata 40 |
| Operating system order: OpenBSD first, Unix/32V fallback, 3BSD dropped | errata 41 |

---

## P1. The wake rule of `WFE`

**The need.** `WFE` ("wait for event") puts the processor to sleep until something wakes it. An idle kernel uses it: when there is no work, sleep, and let an interrupt bring the next piece of work. The question is *what* wakes it. System v1 (section 15) says "until an interrupt is taken", and since errata 40 every exception and interrupt entry sets priority 7.

**The explanation.** An idle loop must check for work and then sleep *without a gap*, because an interrupt that lands in the gap queues work and then the processor sleeps anyway (a **lost wake-up**: the wake-up happened before the sleep and so is missed). There are two ways to write the loop and under the current wording both fail. Lower the priority and then sleep (`spl #0; wfe`): an interrupt arriving between the two is taken, queues the work, returns, and the `wfe` then sleeps with work waiting. Sleep with the priority still at 7 (`wfe; spl #0`): the interrupt is masked, so it is never "taken", and the machine never wakes. The cure used by RISC-V `wfi` is that the sleep ends when an interrupt that is enabled in its own enable register becomes pending, whatever the global enable bit says (checked: RISC-V ISA manual snapshot, WFI; AArch64: Linux relies on it in practice, see the comparison paragraph) is that the sleep ends when an interrupt is *pending*, even if the priority masks it. Then the loop is: `spl #7`, check for work, `wfe`, `spl #0` (the pending interrupt is taken at that point). There is no gap, because while at priority 7 nothing is taken, and the sleep returns the moment one is waiting.

**Current state.** Section 15 and the core: `WFE` (kernel mode only) sleeps until an interrupt is taken (`common/pdp64exec.c` sets a wait flag). Found by the kernel survey (its section 7, gap 1).

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Wake on a pending interrupt, masked or not** | no gap; no new opcode; same idiom as `wfi` on the two architectures I know best | a small change in the core, QEMU and a test; a pending-but-masked interrupt must be visible to the wait logic |
| 2 | Keep as written | nothing to do | the lost wake-up stays; idle loops need a workaround (a timer tick to bound the sleep) |
| 3 | `WFE` takes a priority operand ("sleep, then run at level n") | one instruction does the lower-and-sleep atomically | new operand form; more to encode and verify |
| 4 | An x86-style "interrupt shadow" after `SPL` (the next instruction cannot be interrupted) | the lower-then-sleep pair becomes safe | hidden state; rejected for the same reasons as for exception entry (errata 40) |
| 5 | No `WFE` in the idle loop; poll with `HINT` pause | nothing to specify | burns power; defeats the purpose of the instruction |

**What current systems do.** Survey counts of the wait instructions in the kernel sources: x86 `hlt` 57 and `mwait` 9, AArch64 `wfi` 15 and `wfe` 20, ARM 32-bit `wfi` 9, RISC-V `wfi` 14. The wake rule: RISC-V `wfi` ends the sleep when an interrupt enabled in its own register is pending, even with the global enable bit clear (checked: RISC-V ISA manual snapshot; an implementation may also wake for any reason, so a NOP is legal; AArch64 `wfi` as used by kernels: Linux `arm64/kernel/idle.c` runs `wfi` from its idle loop and its comment warns that interrupts masked at the GIC priority mask (PMR) do not wake the core, which shows kernels rely on `wfi` waking for an interrupt masked only by the processor mask bit (practice, not a quoted guarantee; the Arm Architecture Reference Manual text was not read)); x86 closes the same gap with the "interrupt shadow" of `sti`, which delays interrupts by one instruction so that `sti; hlt` is safe (checked: Intel SDM text for STI).

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11:** a `WAIT` instruction exists, and V7's `idle()` lowers the priority and executes `wait`, called from the scheduler's `swtch()`, and a comment in `slp.c` says the race exists and `idle()` returns in at most one clock interval (checked: V7 `mch.s`, `slp.c`). **VAX:** no wait instruction; 4.3BSD's idle loop spins at priority 0 testing the run-queue summary `_whichqs` (checked: 4.3BSD `vax/locore.s`, `Idle`). *Trade-off:* both avoid the problem by bounding it (a tick) or by polling (burning power). *Comparison:* the recommendation removes the bound without polling; the PDP-11 way is acceptable only with a regular clock tick, which a tickless modern kernel does not have.

**Survey detail.** The kernel survey (its section 7, proposal 1) adds one more point: `SEV` should be *sticky for one wait*, so that an event signalled just before the sleep is not lost. Both points are one rule in the core and need no opcode. **Verification note:** RISC-V `wfi` wakes only for an interrupt enabled in its own enable register (the global enable bit is ignored) and a no-op implementation is legal, so "the same as RISC-V" holds only if the pdp64's priority mask is treated like that global bit; AArch64 `wfi` was not confirmed.

**Recommendation.** Option 1. **This decision is open:** an answer to it was recorded by mistake (it was given inside a question that was rejected) and has been withdrawn. Cost to build: small; one pass with a test of the idiom. **If nothing is done:** the text stays wrong.

**How the recommendation compares.** Option 1 gives the same result as AArch64 and RISC-V and is **not better than them**; it is better than the x86 way in that it needs no hidden one-instruction state, which an out-of-order design must track. It costs one rule in the core and no opcode.

---

## P2. The kernel's access to user memory (a guard)

> **DECIDED (errata 43): option 1**, a `PSW` bit `UA` with `stua` and `clua`, following the author's picks of 2026-10-22. The rest of this section is kept as the record of the options.

**The need.** The kernel must read and write user memory to implement system calls (it copies arguments in and results out). It runs with the *right* to touch user pages. A kernel bug, or an attacker, can make it touch a user page it did not mean to: a corrupted pointer that now points into user memory, or code the attacker placed in user memory. A **guard** makes any kernel access to user pages fault unless the kernel has deliberately opened it. Modern kernels value that: x86 calls it `SMAP`, AArch64 `PAN`, RISC-V `SUM` (x86 `SMAP`/`stac`/`clac`: checked in the Intel SDM text; RISC-V `SUM`: present in the RISC-V manual snapshot; AArch64 `PAN`: Linux `arm64/include/asm/sysreg.h` and `cpufeature.c` set it, and LLVM has the `pan` feature (practice); the kernel survey counted `stac`/`clac` uses in the BSD and Linux sources, 88 in total, its section 7).

**The explanation.** There is a second, separate protection: the kernel must also be unable to *execute* user pages (x86 `SMEP`). System v1 already has that. It has no guard against *reading and writing* them. The design document (D11) lists this as a weak point: "a kernel bug that dereferences a user pointer by mistake succeeds."

**Current state.** Kernel mode may read and write user pages and may not execute them. `PROBER` and `PROBEW` test an address. The PDP-11 solved the same need with explicit instructions (`MFPI`, `MTPI`: move from or to the *previous* mode's space), which also made accidental access impossible because ordinary instructions could not reach the other space.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **A `PSW` bit "kernel may not touch user pages" plus two `SYSX` instructions to clear and set it** (x86 `stac`/`clac` style) | ordinary loads and stores unchanged, so compiler output and old code are unaffected; copy routines open the window briefly; a fault if anything else touches user memory | it is a mode bit in the `PSW` (saved and restored with it, which the `PSW` already is); every error path out of a copy routine must close the window, or the kernel runs unguarded; entry should clear it |
| 2 | **"Access as user" load and store forms** (AArch64 `ldtr`/`sttr`, m68k `moves` style) | ordinary kernel accesses can never reach user pages: always on, nothing to forget to close | new instruction forms for each size (several encodings); more assembler, simulator, QEMU, LLVM and test work; copy routines are written with the special forms only |
| 3 | A single **"open the window for the next n accesses"** instruction, closed automatically (and by any exception) | cannot be left open; one instruction | new kind of state (a count); out-of-order tracking of "the next n accesses" is hard; copy loops of unknown length are awkward |
| 4 | Only **explicit copy instructions** (PDP-11 style `MFPI`/`MTPI` as `copyin`/`copyout`, block-oriented) | smallest attack surface; one instruction does the whole copy with checks | less flexible (strings, partial copies, user-memory atomics); kernels expect to use ordinary code on user pointers |
| 5 | **Nothing for now**: keep `PROBE` and discipline plus no-execute | no work | the weak point stays; the OpenBSD port would run without a guard it may expect (whether OpenBSD requires it was not checked) |

**What current systems do.** Survey: x86 `stac`/`clac` appear 88 times (FreeBSD 50, Linux 32) in the sources, and OpenBSD enables `SMAP` (checked: OpenBSD amd64 `cpu.c` sets `CR4_SMAP`); AArch64 has `PAN` and the unprivileged `ldtr`/`sttr`; RISC-V has `SUM`; ARM 32-bit `ldrt`/`strt`; m68k `moves`; s390 `mvcos`; MIPS has EVA loads and stores; the PDP-11 had `MFPI`/`MTPI`. So both styles exist, six architectures chose the special-forms style, three chose the bit.

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11:** user and kernel have separate address spaces, so the kernel cannot reach user memory with an ordinary instruction at all; it uses `MFPI`/`MTPI` (and V7's `fuword`/`copyin` are built on them, checked: V7 `mch.s`). That is an always-on guard by construction. **VAX:** the process's memory is mapped in the same address space as the kernel, so a kernel routine reads a user address directly after a `PROBER`/`PROBEW` check and a fault handler for errors. That is the pdp64's present design (option 5). *Trade-off:* the PDP-11 way is safest and clumsy (every access an instruction pair, and it was fixed by 16-bit address limits); the VAX way is fast and flexible but trusts the kernel. *Comparison:* option 1 keeps the VAX ease of use and adds the guard the PDP-11 had for free; option 2 is nearest the PDP-11 in spirit.

**Recommendation.** Option 1: smallest change that closes the gap, and it matches what the three modern architectures I named do, so the kernel code that an OpenBSD port starts from already has the open/close pattern. Cost to build: a `PSW` bit, two `SYSX` sub-opcodes (sub 4 and 5 are free), a fault when kernel mode touches a user page with the bit set, tests. **If nothing is done:** option 5 by default.

**How the recommendation compares.** Option 1 copies the x86, AArch64 and RISC-V design, which is what the kernel code OpenBSD already has expects. **It is not safer than the special-forms style** (option 2), where nothing can be left open; it is cheaper to build, leaves the compiler untouched, and can be made safer than x86 by having exception entry set the guard so a handler cannot forget it.


**Revised for your principles.** One small addition for code size: every user copy routine opens and closes the window, so `stua` and `clua` are on the hot path of every system call that moves data. Two-byte page-2 forms (two of the 19 reserved slots) would save four bytes per copy routine and two bytes of fetch per copy. Not worth the slots until the kernel exists; noted so the slots are not spent elsewhere first.
---

## P3. An unprivileged time counter

**The need.** Programs ask for the time constantly (timestamps, timeouts, profiling). A system call costs a mode switch. Kernels avoid it with a **vDSO** (a small page of kernel-provided code mapped into every process): the clock read becomes a few user-mode instructions, but it needs a way to read a hardware counter from user mode. The survey found an unprivileged counter read on x86 (`rdtsc`), RISC-V, PowerPC, s390, MIPS, LoongArch and Alpha (its section 7, gap 3). The pdp64 has a counter in the timer device (a 64-bit free-running register) but it is only reachable by a device access from the kernel, and no instruction reads a counter from user mode.

**The explanation.** The choice is where the counter lives and who may read it. The risk side is *information leak*: a precise cycle counter lets a program time cache misses (the basis of side-channel attacks), so some systems make the user-readable counter coarse or let the kernel switch it off.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **`rdtime rd`: an unprivileged instruction that reads the same constant-rate counter as the timer device** | fast, simple, one instruction (a `SYSX` sub-opcode or a user-readable `mfsr`); vDSO-friendly | fixes the counter's width and rate in the architecture; needs a rule for virtualization later; an enable/disable control if side channels matter |
| 2 | Make the counter a `mfsr` register with a **user-enable bit** in a control register (RISC-V `counteren` style) | the kernel can turn it off per process | one more control register and a bit; same as option 1 otherwise |
| 3 | **No instruction: map the timer device's counter page into user space** (a read-only mapping; ordinary `movq` reads it) | no ISA change at all | depends on the device existing; a device-memory load per read; the counter's address is part of the platform, not the architecture |
| 4 | **A kernel-updated shared page** (seconds and ticks in memory, updated on every timer tick; a sequence-lock) | no hardware counter needed; needs no instruction | time resolution is the tick; every process pays for the memory page; not a high-resolution clock |
| 5 | **A system call for time** (no user-mode read) | nothing to specify | the cost of a trap on every clock read, which is very frequent in some programs |

**What current systems do.** Survey: unprivileged counters on x86 (`rdtsc` 19 uses, `rdtscp` 10; user-readable unless `CR4.TSD` is set, checked: Intel SDM text), RISC-V (`rdtime`), PowerPC (`mftb`), s390 (`stckf`), MIPS (`rdhwr`), LoongArch (`rdtime.d`) and Alpha. Linux builds its fast clock read (the vDSO) on them (checked, practice: `vdso/gettimeofday.h` or `timex.h` read `cntvct` on arm64, `rdhwr` on MIPS, `rdtime` on RISC-V and LoongArch, `mftb` on PowerPC, `stckf` on s390). x86's `rdtsc` has a history of counters that differed between cores or changed rate with power state (checked: Wikipedia "Time Stamp Counter" describes unsynchronized counters and the constant-rate/invariant TSC flags; the kernels' workarounds themselves not read).

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11:** a line clock interrupts 50 or 60 times a second and the kernel keeps the time in memory; a program reads it with the `time` system call (seconds). **VAX:** the same shape with a finer interval clock the kernel reads (`gettimeofday` in 4BSD); no user-mode counter. Both are option 5. *Trade-off:* a system call per clock read was cheap enough when programs asked rarely; it is not for modern programs that timestamp every event. *Comparison:* option 1 gives user code the clock without a trap; neither older machine had that.

**Recommendation.** Option 1 with the enable bit of option 2 held back until someone needs it: one instruction, and the survey found it on 7 of the 14 families. Cost to build: one `SYSX` sub-opcode (free ones remain) and a core change that reads the counter. **If nothing is done:** option 5.

**How the recommendation compares.** Option 1 is what RISC-V, MIPS and LoongArch do. Its advantage over x86 is to fix **at the start** that the counter is monotonic and runs at a constant rate on every core, which spares the kernel the workarounds. It is not better in features: it offers no cycle counter and no per-core performance counters, which the pdp64 does not have yet.

---

## P4. Feature and identification registers

**The need.** Software (a kernel, a C library, a runtime) must learn what the processor it runs on can do: which optional instructions exist, how big a cache line is, what page sizes, how many address bits. Without that, one binary cannot adapt, and a library cannot choose its fastest routine. x86 uses `cpuid` (the survey counted 73 uses in the kernels' sources, its section 7, gap 4); AArch64 and RISC-V use read-only system registers.

**Current state.** `mfsr` reads system registers; `cpuid` is system register 12 (the system architecture table). The ISA also lists `MFCPUID`. Nothing describes optional-feature bits, cache geometry or page sizes.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **A fixed block of read-only `mfsr` numbers (13 and up): an ISA-features bitmap, a cache-geometry register, a page-size register, an address-width register** | no opcode; easy to read in a few instructions; matches AArch64's `ID_*` register idea (checked, practice: Linux `arm64/kernel/cpufeature.c` reads `ID_AA64ISAR0_EL1` and others) | each register's bit layout must be written once (in a grammar, so it is generated); grows over time |
| 2 | **A `cpuid`-style instruction** returning several registers selected by a leaf number | one place for all queries; very flexible | an opcode; the leaf space is a second namespace to manage |
| 3 | **Firmware-provided description in memory** (a table handed to the kernel at boot, like a device tree) | the architecture stays silent; platforms describe themselves | the processor's own features still need a source; the kernel parses a table before it knows anything |
| 4 | **One `misa`-like bitmap register** plus a configuration string in memory (RISC-V style (from memory, not confirmed in the sources read)) | one register to read; a string for the rest | a bitmap fills up; the string needs a parser |
| 5 | **Probe by trying**: execute the instruction and catch the illegal-instruction exception | no registers | slow, fragile, and impossible for non-instruction facts (cache size) |

**What current systems do.** Survey: x86 `cpuid` 73 uses; AArch64, ARM and RISC-V read identification registers (`mrs`, `mrc`, `csrr`); s390 `stidp`/`stfle`/`stsi`; Alpha `amask`/`implver`; PowerPC `mfpvr`. x86's `cpuid` has grown hundreds of leaves, differs by vendor and traps in virtual machines (from memory, not confirmed in the sources read).

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11:** no identification register on early models (later processors added an instruction to read the processor type, as I recall (not confirmed)); Unix was configured at build time for the machine, and device presence was found by touching the device's addresses and catching the bus-error trap (option 5). **VAX:** a system identification register, read with `MFPR`, gave the CPU type and revision, and the kernel switched on it (option 1 in spirit). *Trade-off:* probing is simple and breaks for anything that is not a device; an identification register works for everything but must keep being extended. *Comparison:* option 1 is the VAX way, with the layout generated from a grammar.

**Recommendation.** Option 1, defined once in a grammar: no opcode cost and it fits `mfsr`. Cost to build: a table in the grammar, generated constants, a read-only check, a test. **If nothing is done:** option 5.

**How the recommendation compares.** Option 1 is the AArch64 and RISC-V approach, **not an improvement over them**. Against x86 it avoids a second namespace (leaf numbers) and an opcode, and because the bit layouts are written once in a grammar and generated, kernels and the LLVM back end cannot drift from the hardware description.

---

## P5. Invalidating the TLB by address-space tag

**The need.** The **TLB** (translation lookaside buffer: the cache of recent address translations) must be told when a translation is no longer valid. Each translation is tagged with an **ASID** (address-space identifier: a number naming the process it belongs to), so that switching processes does not flush everything. The questions are what you can invalidate: one address, everything, or everything for one ASID.

**Current state.** `TLBI` invalidates by address (and, per the ISA text, it broadcasts to other cores), `TLBIA` invalidates everything, `MTASID`/`MFASID` set and read the ASID. There is no "invalidate all entries of ASID n".

**Why it matters.** When a process exits, or when the ASID numbers run out and are reused (a **rollover**), the kernel must drop every entry of one ASID. With only "everything" it drops all processes' entries, which costs the others their cached translations. The survey saw per-ASID invalidate on AArch64 (`aside1is`), RISC-V (`sfence.vma` with an ASID), x86 (`invpcid`) and LoongArch (`invtlb`) (its section 7, gap 5).

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Add `TLBIASID`: invalidate every entry of one ASID** | exact cost for process exit and ASID reuse | one `SYSX` sub-opcode; the broadcast form needs defining |
| 2 | **Give `TLBI` an ASID operand** (address + ASID) | one instruction family, flexible | changes an existing instruction's form; more bits |
| 3 | **Both by-ASID and by-address-and-ASID** (AArch64-like) | the most complete | two new forms; the most to verify |
| 4 | **No new instruction: rollover flushes all with `TLBIA`** (software generation count) | nothing to build | after every rollover all processes lose their entries; fine on a small ASID space only if rollovers are rare |
| 5 | **Drop ASIDs: flush on every context switch** | simplest hardware | the slowest switches; wasteful on any machine with a real MMU |

**What current systems do.** Survey: x86 `invlpg` 16 uses and `invpcid` 14; AArch64 `tlbi` (by all, address, ASID, with or without broadcast); RISC-V `sfence.vma` with an optional ASID; LoongArch `invtlb`. x86 had no broadcast and used inter-processor interrupts to make other cores flush (a **shootdown**), which is slow; AMD added `invlpgb` late, which the survey saw once (checked, practice: Linux `x86/mm/tlb.c` calls `invlpgb_flush_*`, and OpenBSD amd64 `pmap.c` carries `pmap_tlb_shoot*` for the IPI shootdown; the history is from memory).

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11:** the memory-management unit has no translation cache to invalidate; it has a small set of relocation registers per mode, and the kernel reloads the whole set on a context switch, which is the tagging (the register set *is* the address space). **VAX:** a translation buffer with invalidate-all and invalidate-single operations (`TBIA`, `TBIS`, written through `MTPR`) and no address-space tags; the process half is flushed on a context switch and the system half survives. *Trade-off:* flush on switch is simple and costs the new process its warm entries; the VAX split keeps kernel entries. *Comparison:* ASIDs plus per-ASID invalidate (option 1) beat the VAX flush on switch, and the PDP-11 way does not scale beyond 8 pages per mode.

**Recommendation.** Option 1, but it is medium priority: option 4 works until the first rollover, and a small machine with few processes rolls over rarely. Cost to build: small. **If nothing is done:** option 4.

**How the recommendation compares.** The pdp64 already broadcasts `TLBI`, so it avoids the shootdown cost that x86 pays; option 1 closes the one remaining gap. It is **the same as AArch64 and RISC-V and not better**, and the broadcast bus transaction itself has not been designed (see P11), so the advantage over x86 is on paper.


**Revised for your principles.** This now ranks above "medium": invalidating one address space exactly makes process exit and ASID reuse cheap (a tighter hot path at every context switch) and needs one `SYSX` word and a small broadcast rule. Fewer flushes also means fewer lost translations to refill, which is time, not recovery code. Recommended: add.
---

## P6. Data-cache maintenance by address

**The need.** If a device that moves data by **DMA** (direct memory access: the device reads and writes memory without the processor) is not kept **coherent** with the processor's cache, then the software must write cached data back before the device reads it (**clean**) and discard stale cached data before reading what the device wrote (**invalidate**). That needs instructions that act on a cache line by address. The design today avoids it: DMA buffers are mapped uncached (`MT = 01`) and the hand-off is explicit (section 6 of the bus document), so no cache instructions exist.

**Why it comes up.** The survey found that 12 of the 14 families have cache-maintenance instructions in their kernels. They matter if a future device is not coherent, or if performance wants cached DMA buffers (uncached memory is slow to fill and read).

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Reserve three `SYSX` sub-opcodes now (clean, invalidate, flush by address); execute as no-ops on coherent hardware** | the encoding is claimed; software can be written against it; no cost on coherent systems | spending opcode space on something not yet needed; a rule for what "no-op" means on a system that later is not coherent |
| 2 | **Reserve nothing; add later if a non-coherent device appears** | no work now; the space stays free | a later addition changes the ISA after software exists |
| 3 | **Keep it as is: uncached DMA buffers only** (current design) | no instructions; simple | slow buffers; no cached DMA |
| 4 | **Require every DMA device to be coherent** (a snoop path on the bus) | software never sees caches at all | hardware cost on every device; the bus document rejects it as expensive for large, infrequent transfers |
| 5 | **One "cache operation" instruction with an operation field** (clean, invalidate, flush, and more) | one opcode covers all, room for future operations | a field to define; the hardest to verify; more than is needed today |

**What current systems do.** Survey: 12 of the 14 families have cache-maintenance instructions in their kernels (x86 `wbinvd` 17, `clflush` 9, `clwb` 1; ARM and AArch64 clean and invalidate by address). x86 DMA is coherent, so its kernels seldom need them for devices; ARM, MIPS and embedded PowerPC with non-coherent DMA do, and Linux wraps this in a DMA API that has to be called at the right moments (checked: kernel.org swiotlb document describes the DMA layer map, unmap and sync calls; the BSDs have `bus_dmamap_sync`).

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11:** the larger models had a cache; it was kept consistent with Unibus DMA by the hardware (checked: PDP-11/70 handbook: on a write hit from the I/O bus the cache block is marked invalid), so Unix had no cache instructions. **VAX:** caches were transparent too; the one place software managed buffering was the Unibus adapter, where drivers purged its buffered data paths before reading a device's data (as I recall (not confirmed)). *Trade-off:* hardware coherence costs gates and made every DMA path more complex, and the software never sees a cache. *Comparison:* the pdp64's uncached buffers are closer to the PDP-11 outcome (software never manages a cache) by a cheaper means (a memory type per page), at a cost of speed that those machines' caches did not impose on DMA.

**Recommendation.** Option 2 for now: the current design needs none of it, and nothing in the OpenBSD plan requires it as long as devices follow the uncached hand-off. Revisit the day a device is not coherent. Cost to build: none. **If nothing is done:** option 3 stays.

**How the recommendation compares.** Uncached DMA buffers (the present design) remove the whole class of mistakes where a driver forgets a clean or an invalidate. **That is a correctness gain, not a speed gain**: ARM and MIPS systems with cache maintenance move data faster. Option 2 keeps the gain and defers the cost.

---

## P7. Firmware calls and the missing `RESET`

**The need.** `RESET` was dropped as an instruction ("resetting the bus is a device operation", ISA section 4.11.1). Kernels call something outside themselves for a few things: reboot, power off, early console output, secondary-core start. On many systems that is **firmware** reached by a special call. The question is whether the architecture defines such a call.

**Current state.** Nothing is defined. The kernel survey suggests reserving trap vectors for firmware calls (its gap 7). `TRAPL` vectors are available.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Nothing: everything through devices** (a bus-controller reset register, a console device, a power register) | no new convention; consistent with eight-register devices | each platform defines its own devices; a kernel needs a table to find them |
| 2 | **A firmware-call convention on reserved `TRAPL` vectors** (an SBI-like interface: function number in a register, results in registers) | one interface for reboot, power-off, early console, core start; the kernel does not need device knowledge to start | a convention to write and keep stable; someone must provide the firmware |
| 3 | **A boot ROM table** of entry points handed over at boot | simple; no trap | an indirect call convention; still needs a calling convention |
| 4 | **A separate highest privilege level ("machine mode")** | strong separation of firmware from the kernel | a new mode; against the simplicity of two modes; far more work |
| 5 | **Let the boot loader define it per platform** | no architecture work | different on every platform; the OS port carries the differences |

**What current systems do.** Survey: class 13 (hypervisor, secure and firmware calls) appears in 6 families. RISC-V kernels call firmware with `ecall` through the SBI interface; ARM uses `hvc`/`smc` for power control (checked, practice: Linux `arm64/kernel/psci.c` and `smccc-call.S`); RISC-V `ecall` SBI: checked, Linux `riscv/include/asm/sbi.h`; Alpha had PALcode; SPARC had Open Firmware; x86 reaches firmware through BIOS or UEFI services and ACPI.

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11:** boot ROMs and a console debugger (`ODT`) in firmware; Unix never called firmware, and it halted to the console. **VAX:** a console processor (on the VAX-11/780 a small separate computer) with console commands, a halt instruction that returns to it, and console terminal registers the kernel could read and write (`MTPR`/`MFPR`); reboot was a halt and a boot command. *Trade-off:* a separate console machine gave remote operation and a recovery path at the price of a second computer. *Comparison:* option 1 (devices only) is nearer the PDP-11; the VAX console processor is the origin of the firmware-call idea but was not a call interface.

**The survey disagrees.** The kernel survey (its section 7, proposal 7) recommends *specifying* a firmware-call convention on a reserved range of `TRAPL` vectors, with a register convention, because `RESET` was dropped and so there is currently no way for the kernel to ask for power-off, a secondary-core start or a reset; it costs text only. My recommendation below is the opposite (devices only), so the choice is real: the survey's reasoning is that an interface costs nothing to reserve and is hard to add after software exists.

**Recommendation.** Option 1 for the first system: it fits "devices are eight registers", needs no firmware, and OpenBSD ports get a console and reset from devices. Revisit with option 2 when there is a second platform. Cost to build: none now. **If nothing is done:** option 1.

**How the recommendation compares.** Option 1 is the opposite of what these do. Its advantage is **no firmware to trust, port or bug-fix and no extra privilege level**; its cost is that every platform must say where its console and reset registers are, which the others get from the firmware. For a first system with few platforms the trade is in its favour, and it is **worse** once there are many.


**Revised for your principles.** Under the recovery priority, a way to *reset the machine* is what matters most, because it is the simplest recovery path of all and needs the least code: add a requirement that the bus controller has a reset register and a watchdog (a timer that resets the machine if not kicked). That gives recovery from a hung kernel with no firmware, no new instruction, and about ten lines of kernel code. Option 1 stays, with this requirement added.
---

## P8. Double-width compare-and-swap

**The need.** A **compare-and-swap** (CAS) atomically replaces a memory word if it still holds the expected value. A **double-width** CAS does it on two adjacent words (128 bits). Lock-free data structures use it to avoid the **ABA problem** (a value changes from A to B and back to A while you were looking, so a plain CAS wrongly succeeds): pair the pointer with a counter and swap both together.

**Current state.** The ISA has `LL`/`SC` and `ATOM` operations on single words. The kernel survey found double-width CAS only in the Linux sources (its gap 8).

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Do not add** | no work | lock-free structures needing it fall back to a lock or a different design |
| 2 | **Add `cas128` on a register pair** | the standard tool for ABA-safe structures | an instruction with a pair of registers and a 16-byte aligned access; atomicity rules on a bus with 64-bit data |
| 3 | **Multi-word `LL`/`SC` on one cache line** | general | the hardest to define and verify; reservation rules grow |
| 4 | **Use the spare pointer bits as a counter** (a 39-bit virtual address leaves 25 bits of a 64-bit pointer unused, per the ISA; software tags the pointer) | no instruction; ABA protection by a version number in the pointer | pointers must be masked before use; a counter of 25 bits can wrap; not for all designs |
| 5 | **Defer until there is SMP and a user** | no work now; no wrong guess | the question comes back |

**What current systems do.** Survey: x86 `cmpxchg16b` 4 uses (and `cmpxchg8b` 13), AArch64 `casp` 2, RISC-V `amocas.q` 1, s390 `cdsg`; one Linux use, a lock-free free list with a tag. The ABA problem is otherwise handled by RCU, hazard pointers, tagged pointers or locks (from memory, not confirmed in the sources read). AArch64 can ignore the top byte of an address for tagging.

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11:** read-modify-write instructions (`INC`, `BIS`, `BIC` on memory) are indivisible on the Unibus (`DATIP`/`DATO`), but nothing as wide as a double word; Unix on one CPU used `spl` for exclusion. **VAX:** interlocked instructions (checked: VAX-11 Architecture Reference Manual 6.1; the 1977 handbook has only `INSQUE`/`REMQUE`): `BBSSI`/`BBCCI` (branch on bit and set or clear, interlocked), `ADAWI`, and the interlocked queue instructions `INSQHI`/`REMQHI`, which are whole lock-free queue operations in one instruction, so the ABA problem never appears. *Trade-off:* the VAX solved the problem with a few large microcoded instructions instead of a general primitive. *Comparison:* a double-width CAS (option 2) would be the general version; option 4 does in software with spare pointer bits what the VAX did in microcode.

**Recommendation.** Option 5 now, with option 4 as the recommended software pattern. The only evidence is Linux-only; nothing in the BSD sources asked for it. Cost to build: none. **If nothing is done:** same as option 5.

**How the recommendation compares.** Option 5 plus the tagged-pointer pattern is what systems without a double-width instruction already do; it is **not better** than having the instruction. The evidence of need is one Linux use, so building it now would be speculative.

---

## P9. A source of random numbers

**The need.** A kernel needs unpredictable bits at boot (for address randomization, key generation, network sequence numbers). A hardware source is the most reliable. Without one, the system gathers jitter from interrupt timing and device events, which is slow to produce enough early in boot. (That OpenBSD wants randomness very early: not confirmed in the sources read.)

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **An entropy device on the bus** (one more eight-register device: a status and a data register) | no instruction; the physical source is the platform's choice; fits the device convention | not available until the platform has the device; an access per read |
| 2 | **A random-number instruction** (x86 `rdrand`, AArch64 `rndr` (from memory, not confirmed in the sources read)) | fast, available everywhere | an opcode; the architecture must say what quality it guarantees; side-channel and trust questions about the source |
| 3 | **A read-only `mfsr` register** that returns random bits | no new opcode | privileged only unless made user-readable; the same quality questions |
| 4 | **Software only**: collect jitter from the timer and interrupts | nothing in hardware | slow to fill; weak early in boot, which is the worst time to need it |
| 5 | **A seed passed in by the boot loader** (stored from the previous boot) | no hardware; fast at start | needs persistent storage; weak on first boot |

**What current systems do.** Survey: x86 `rdrand` 12 and `rdseed` 9 uses, PowerPC `darn`, s390 `prno`, AArch64 `rndr`; no other family has one. Virtual machines supply a random-number device (virtio-rng) (not confirmed in the sources read), and kernels mix several sources and a stored seed file (from memory, not confirmed in the sources read).

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11 and VAX Unix:** no hardware random source; `rand()` was a small linear congruential generator (V7 `rand.c`) with a fixed default seed of 1 unless the program calls `srand` (corrected after checking: this text said seeded from the time), and 4BSD added `random()` (checked: 4.3BSD `libc/gen/random.c`). There was no `/dev/random`. The uses that need real entropy today (address randomization, network keys) did not exist. *Trade-off:* none was needed then. *Comparison:* the question is new; neither machine offers a precedent, and option 1 is the answer built for the present.

**Recommendation.** Option 1 (an entropy device): it matches how every other peripheral is defined and keeps the ISA free of a quality promise. Use option 5 as the supplement. Cost to build: a device definition in the bus document and a QEMU model. **If nothing is done:** option 4.

**How the recommendation compares.** Option 1 is how virtual machines already do it. It is better than an instruction in that **no opaque instruction becomes the only trusted source** and the ISA makes no quality promise; it is worse in being unavailable until the platform has the device, and slower per read.

---

## P10. The direct-mapping windows and `MMUCTL`

> **DECIDED (errata 44, with errata 42): `MMUCTL` stays** (option 2) and the `DMW` format is deferred (option 5 for the format). The author's clarification that the no-mode-bits rule is soft withdrew my recommendation to remove it: `MMUCTL` is machine-wide and set once at boot, so the benefits the rule protected are kept. The rest of this section is kept as the record of the options.

**The need.** The design document (D9) flags a contradiction: the ISA says there are **no mode bits** (section 1.1) and that the machine comes up with the direct-mapping window `DMW0` covering physical memory, so translation is always on and nothing needs switching. System v1 nevertheless added a `MMUCTL` register whose bit 0 turns translation on, "because the format of the direct mapping windows is not defined yet". That is a mode bit: it is not saved on a context switch, which is exactly the cost the rule exists to avoid.

**The explanation.** A **direct-mapping window** (`DMW`) maps a range of virtual addresses onto a range of physical addresses without a page-table lookup, so the kernel and the boot code can reach physical memory (and device registers) before any page tables exist. If the window format were defined, the machine could boot with a window mapping low memory, and there would be no off state to design.

**Current state.** `MMUCTL` bit 0, reset 0; `DMW0` and `DMW1` registers exist but are storage-only in System v1 (the section 15 table). The system design document calls the consistent fix "define the `DMW` format, boot with a window that maps low physical memory, and drop `MMUCTL`."

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Define the `DMW` format, boot with a window on low physical memory, remove `MMUCTL`** | consistent with the ISA's rule; no mode bit; fewer special cases | a format to write (base, size, attributes, permissions), the reset value, the exception-entry interaction; tests and the QEMU model change |
| 2 | **Keep `MMUCTL` as it is** (a documented exception to the rule) | already built | the inconsistency stays; one more thing to save in a hypervisor later |
| 3 | **A "bare" mode selected by `PTBR` = 0 or ASID 0** (RISC-V `satp` Bare style (from memory, not confirmed in the sources read)) | no separate register; a value, not a bit | still a mode in effect, merely spelled differently |
| 4 | **A single fixed identity window in hardware, not programmable**, plus page tables for everything else | simplest; no `DMW` registers at all | the kernel cannot move or resize it; platform-specific physical layouts get harder |
| 5 | **Defer: leave both** until the kernel work shows what it needs | no work now | the open item stays and more code depends on `MMUCTL` meanwhile |

**What current systems do.** x86 turns paging on with `CR0.PG` and long mode requires it, so boot code runs with an identity mapping while switching on; AArch64 has `SCTLR.M`; RISC-V `satp` has a Bare mode; MIPS has no off state and fixed unmapped windows (`kseg0`/`kseg1`); LoongArch has programmable direct-mapped windows (checked: MIPS `CKSEG0` in Linux `mips/include/asm/addrspace.h`, LoongArch `LOONGARCH_CSR_DMWIN0` in `loongarch.h`, RISC-V Bare mode in the ISA manual; x86 `CR0.PG` and AArch64 `SCTLR.M` not read). The pdp64's own ISA rule (no mode bits) matches the MIPS and LoongArch kind.

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11:** the memory-management unit is switched on by a bit in status register 0 (`SR0`); Unix boots with it off, builds its relocation registers, then sets the bit. **VAX:** `MAPEN` turns on mapping; the boot code runs position-independent, has an identity mapping of low memory in the system page table, sets `MAPEN` and jumps to a system virtual address (the same trampoline x86 needs). *Trade-off:* a switch is simple hardware and a transition to get right. *Comparison:* `MMUCTL` is exactly the PDP-11 `SR0` precedent, so keeping it (option 2) is the heritage choice; option 1 removes the transition both older machines had to manage.

**Recommendation.** Option 1: it is the fix the design document already called consistent, and it is cheaper to do before an OpenBSD port starts depending on `MMUCTL`. Cost to build: moderate (grammar, core, QEMU, tests, the boot description). **If nothing is done:** option 5.

**How the recommendation compares.** Option 1 is the MIPS and LoongArch design. It is **better than the x86 and RISC-V way** in that there is no switch-on moment and no identity-map trampoline in the boot code; it is **worse** in needing a window format to be specified and verified before the first kernel runs.

---

## P11. Atomics on the bus: a lock or a monitor

> **DECIDED (errata 45): option 1**, a monitor (reservation); `DATIP`/`DATO` are no longer architectural. The rest of this section is kept as the record of the options.

**The need.** Two things at once want to update the same word in memory: a second processor core, and a DMA device such as the `LB64` accelerator writing a descriptor's status word. An atomic read-modify-write must be indivisible against both. There are two ways to build that, and the ISA has been carrying both ideas without choosing (open item 4, bus document section 8).

**The explanation.** A **lock** (the Unibus-derived `DATIP`/`DATO` pair: read the word and hold the bus until the write) stops everyone else from using the bus in between. A **monitor** (AXI exclusive access, and `LL`/`SC`: load-linked/store-conditional) lets anyone proceed, and the store succeeds only if nobody wrote the address in the meantime. They are different primitives and mapping one onto the other is not clean. With one initiator this can wait; with a second core or a contending device it is blocking.

**Current state.** The readiness review prefers the monitor (AXI exclusive). The `_DB` variants of the atomics ("with barrier") assert an ordering guarantee that has to mean something on the real interconnect.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Monitor: `LL`/`SC` and the atomics are defined on a reservation; `DATIP`/`DATO` removed from the architecture** | matches AXI exclusive access and the FPGA memory system; no bus lock; scales to more cores | a reservation rule for every initiator; forward-progress rules for `SC`; devices must take part (or never touch shared words) |
| 2 | **Lock: keep `DATIP`/`DATO` as a bus lock** | the PDP-11 programming model; simple to reason about | a bus lock is a bottleneck with several cores; AXI has no exact equivalent (a lock is emulated by exclusive access plus retry) |
| 3 | **Both: monitor for cores, lock for devices that need it** | each used where it fits | two mechanisms to specify and test; the interaction between them is the hard part |
| 4 | **Atomics performed at the memory (far atomics, AXI5-style)** | a device and a core use the same operation; no reservation | newer bus features; the FPGA memory system may not provide them; the operation set is fixed by the memory side |
| 5 | **Defer: single initiator for now**, but write the constraints | no work today | the question blocks SMP and the first shared-queue device; changing later may break software |

**What current systems do.** Survey: pdp64 has more atomic operations than any surveyed architecture (`CAS`, `SWAP`, `XADD`, and the logical and min/max forms, plus `LL`/`SC`). MIPS, PowerPC, Alpha, ARM and RISC-V use load-linked/store-conditional; AArch64 adds far atomics (the LSE extension); x86 uses the `lock` prefix, which locks a cache line rather than the whole bus on modern parts; the VAX had interlocked queue instructions that locked the bus (RISC-V LR/SC with an eventual-success rule for constrained loops: checked, RISC-V ISA manual 5.2.1; Arm LSE `ldadd`/`casp`: practice, Linux `atomic_lse.h`; x86 lock-prefix scope and VAX bus-lock wording not read). Linux moved its spinlocks from test-and-set to ticket to queued locks as core counts rose (checked: LWN 590243 describes ticket spinlocks and Waiman Long's qspinlock, MCS-based, for contended locks, queued for 3.15 at the time of writing; `qspinlock.h` exists in the x86, powerpc, sparc and loongarch trees).

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11:** the Unibus locked read-modify-write; Unix on a single CPU relied on `spl`; the multiprocessor 11/74 was a rare exception. **VAX:** interlocked instructions backed by a bus or memory interlock (`BBSSI`, `ADAWI`, the queue instructions); the 4BSD kernel on a uniprocessor again used `spl`. *Trade-off:* a bus interlock is simple and does not scale as cores multiply. *Comparison:* option 2 is the heritage design; option 1 gives up the Unibus model for the one the FPGA memory system provides, which is the design the FPGA memory system already provides.

**Recommendation.** Option 1 now, written as a specification (no hardware yet): it is the only one that maps cleanly onto the FPGA's memory system. Cost to build: the ISA and bus text, `LL`/`SC` rules, tests for the reservation in the emulators. **If nothing is done:** option 5, and SMP stays blocked.

**How the recommendation compares.** Option 1 is what most RISC architectures and the AXI bus the FPGA uses already do, so it maps cleanly. It is **better than the PDP-11 bus lock** for scaling and **not better than far atomics** (option 4), which avoid the retry cost of a monitor under contention. The cost of a monitor, livelock under contention, is real and known.

---

## P12. What a multi-register instruction leaves behind when it faults

**The need.** `pushm`, `popm`, `pushx` and `popx` move several registers to or from the stack in one instruction. If one of the memory accesses faults partway (a page not present), the exception is **precise** (the instruction is run again after the fault is handled). But some stores may already have happened. The reviewer asked what the architecture promises about that.

**The explanation.** For `pushm` the stores go to the stack *below* the stack pointer, which is dead memory (nothing reads it), so a partial result is harmless: the restart writes the same values again. The danger is **observation**: a DMA device or another core could see a half-written area; and for `popm` a half-updated register file, if register writes were not deferred. The ISA already says side effects are deferred (D12) so that the stack pointer is only updated at the end.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Accept and document: stores already done may stay; restart rewrites them; rule that the area below the stack pointer is dead and unobserved** | no hardware cost; matches the present design | software must not hand the area to another observer mid-instruction; the rule needs a sentence per instruction |
| 2 | **All-or-nothing: probe every page before the first store** | no partial effect at all | a pre-check pass costs cycles and complexity; hard in an out-of-order core |
| 3 | **Resumable: save progress in a register so the restart continues** (x86 `rep` style (from memory, not confirmed in the sources read)) | no repeated work, no partial exposure | hidden state; the kernel must preserve it |
| 4 | **Forbid page crossing**: the instruction faults if the area spans two pages, and software splits | each part is all-or-nothing | software complexity; a long list may not fit one page |
| 5 | **Replace by a sequence of single stores** (drop the instruction) | no partial-effect question | gives up the 11-instruction saving the survey measured for entry and exit |

**What current systems do.** ARM `ldm`/`stm` restart after an abort with the base register restored (from memory, not confirmed in the sources read); the VAX marks an interrupted instruction with a "first part done" bit and resumes; x86 `rep` instructions resume from the register state; m68k saves internal state in an exception frame. Survey: the multi-register save/restore instructions are `pushr`/`popr` on the VAX and `movem` on m68k, and the survey's path-length table puts those machines in the 6 to 11 instruction range for syscall entry.

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11:** an autoincrement or autodecrement changes a register before a later part of the instruction can fault; the larger models had `SR1` (`MMR1` on the 11/70), which recorded those register changes so the kernel could undo them and restart (V7's `backup` in `mch.s` reads it, and `trap.c` calls `backup` to grow the stack); the 11/34 and 11/40 memory management has only `SR0` and `SR2`, and `trap.c` notes that for the 11/40 the routine `backup/l40.s` may fail on instructions such as `cmp -(sp),-(sp)` (checked: PDP-11 04-55 handbook chapters 8 and 10; V7 `mch.s`, `trap.c`). **VAX:** the hardware keeps a first-part-done bit and enough state in the exception frame to resume a long instruction. *Trade-off:* both needed extra hardware state or kernel code to make faults restartable. *Comparison:* the pdp64's precise exceptions with deferred side effects (D12) need neither `SR1`, nor a decoder in the kernel, nor a resume bit; option 1 keeps that, with the one rule about the dead stack area.

**Recommendation.** Option 1, with the dead-area rule written next to each instruction: nothing in the system reads below the stack pointer, so a partial push is invisible. Cost to build: text only, plus a test that proves a restart gives the same final memory. **If nothing is done:** the guarantee stays unwritten.

**How the recommendation compares.** Option 1 is closest to the ARM approach (restart, no hidden resume state) and **simpler than the VAX or m68k**, which save the instruction's progress. It is not better than resumable designs where the same work would otherwise repeat, but the pdp64's stack area below the stack pointer is dead, so the repeated stores are free.


**Revised for your principles.** This is the decision that most directly serves your recoverability priority, so it is strengthened. The kernel's page-fault and restart path should have *no instruction-specific cases*: every multi-access instruction (`pushm`, `popm`, `pushx`, `popx`, `mcpy`, `mmov`, `mset`, `mscn`) must be either all-or-nothing or safe to repeat from the start, and the fault handler restarts it blindly. `pushx`/`popx` already check both words before accessing either (ISA 4.11). The recommendation is option 1 with the dead-area rule *plus* a test in the emulators that interrupts each such instruction at every possible access and checks that a restart gives the same final state, for registers and memory. The PDP-11 needed `SR1` and a kernel routine that decoded instructions to undo them, and the VAX a resume bit; passing this test is what "no recovery code" means.
---

## P13. `long double`

> **DECIDED (errata 46): option 5**, `long double` stays `double` and the ABI version is the door (version 2 for binary128). The rest of this section is kept as the record of the options.

**The need.** C's `long double` type has no single standard width. The ABI today says `long double` is the same as `double` (64 bits). That is the cheapest choice and is what some platforms do (checked: clang makes it 64 bits on Windows and Apple AArch64, and on FreeBSD, OpenBSD, musl and AIX PowerPC). Other platforms make it 128 bits, and a few use the 80-bit x87 extended format. The choice goes into the ABI, the C library, the compiler and every program that uses the type, and it cannot be changed later without breaking binaries.

**Why it comes up now.** The LLVM and clang work is next, and a decision made after clang exists would break things. Which format OpenBSD's other ports use was not checked, and a port needs `printf`, `strtold` and the math functions to agree with the compiler.

**Current state.** The pcc back end for aarch64 has an opt-in binary128 `long double` (`A64QUAD`); the pdp64 has no 128-bit float hardware, so any quad would be software.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **`long double` = `double` (64-bit)** (the ABI today) | no library work; fast; nothing to maintain | programs expecting more precision get none; some C library functions have no separate `long double` versions to test |
| 2 | **binary128 in software** (AArch64 Linux and RISC-V use this, checked: clang `AArch64.cpp`, `RISCV.h`) | highest precision; the common 128-bit choice | a software float library for add, multiply, divide, conversions; slow; the library must come before the system |
| 3 | **80-bit x87 extended** | compatible with x86 software | no hardware; an odd format with padding; the worst of both |
| 4 | **double-double** (PowerPC Linux style, checked: clang `PPC.h`) | fast on hardware with fused multiply-add; wide range | not IEEE; surprising edge cases; special library behaviour |
| 5 | **Start with option 1 and reserve the right to change at a defined ABI revision** | the first system moves; the door stays open | a later change breaks binaries unless the ABI is versioned from the start |

**What current systems do.** `long double` is 80-bit extended on x86, 128-bit binary128 on AArch64 Linux and RISC-V, double-double on PowerPC Linux, and the same as `double` on Apple's and Microsoft's ARM64 ABIs (checked: clang `lib/Basic/Targets/RISCV.h`, `AArch64.cpp`, `PPC.h`). Corrected after checking: clang gives FreeBSD, OpenBSD and musl PowerPC a 64-bit `long double`, so OpenBSD powerpc64 uses `double`; OpenBSD arm64 and riscv64 get binary128 by the clang defaults (no override found). MSVC not checked.

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11:** floating point in 32-bit and 64-bit formats; the V7 C compiler had `float` and `double`, and no `long double`. **VAX:** F, D and G formats (32 and 64 bits) and a 128-bit H format in hardware on some models; C's `double` was D-floating and the 128-bit format was little used from C. *Trade-off:* neither machine had a 128-bit float in the C language. *Comparison:* there is no precedent in either; option 5 starts where they ended (`double` is the widest) and keeps the door open.

**Recommendation.** Option 5: ship `long double = double` first and put an ABI version number into the object format now, so a later change to binary128 is a version bump not a surprise. Cost to build: none for the type; a small version field in the ABI/ELF flags. **If nothing is done:** option 1 with no door.

**How the recommendation compares.** Option 5 starts where the Apple and Windows ARM64 ABIs sit: **no library work and no quality risk**. It is **worse** in precision than the Linux choices. Versioning the ABI from the start is better than the others, which each had to live with their first choice.

---

## P14. Confirm: priority 7 on interrupt entry as well as exception entry

**The need.** You decided priority 7 on exception entry (errata 40). I extended it to interrupts, which you did not explicitly say. I did so because the same hole exists: a level-6 timer interrupt can preempt a level-4 handler before it has saved `EPC` and `EPSW`, overwriting them. This item is here so you can confirm or narrow it.

**What it costs.** An interrupt handler no longer runs at its own level automatically. It lowers the priority itself, with one `spl`, once the two registers are saved. The PDP-11 took the priority from each vector (**from memory, unchecked**), so each vector could choose. Here it is fixed at 7 for all of them.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Priority 7 on every entry, exceptions and interrupts (as implemented)** | closes both windows; one rule; no per-vector state | every interrupt handler needs one `spl` to its working level |
| 2 | **Exceptions only; interrupts enter at their own level** | no extra `spl` in interrupt handlers; the interrupt priority works as on the PDP-11 | the `EPC`/`EPSW` overwrite hole stays for interrupts: a higher-level interrupt can preempt before the save |
| 3 | **Per-vector priority**, held in the vector table (PDP-11 style) | each vector chooses | the vector table entry grows (two words or a packed field); hardware reads more at entry |
| 4 | **Hardware pushes `EPC` and `EPSW` on entry** (nested interrupts are then safe at any level) | no window at all; no `spl` needed | memory writes at entry, against the register-based design; entry can fault; more hardware |
| 5 | **Interrupt shadow** (nothing can interrupt for one instruction after entry) | no change to the priority | hidden state; relies on the handler's first instruction; rejected earlier |

**What current systems do.** The survey found that x86, AArch64, RISC-V, PowerPC, MIPS and SPARC all mask interrupts on entry, and that the VAX and m68k raise the priority. Most of those have one mask bit (x86 `IF`, AArch64 `DAIF`, RISC-V `SIE`), so a handler that wants nesting re-enables it by hand; the PDP-11 loaded the priority from each vector (checked: V7 `mkconf.c` writes `br4` to `br7` into the vectors).

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11:** the processor loads a new `PC` and `PS` from the vector (two words) and pushes the old pair on the kernel stack; V7's vector table (generated by `mkconf.c`) gives traps the status word `340` (`br7 = 340`) and each device interrupt its own priority (`br4` to `br7`, the line clock `br6`) (checked: V7 `mkconf.c`). **VAX:** an interrupt raises the priority to the interrupt's level and an exception keeps it; the hardware pushes `PC` and `PSL` on the stack. *Trade-off:* because both push the old state in hardware, an interrupt at any time cannot lose it; the cost is a memory write at entry. *Comparison:* the pdp64 saves in registers, which is why it needs priority 7 on every entry; its traps at 7 follow the PDP-11 convention, and its interrupts differ from both older machines by not entering at their own level.

**Recommendation.** Option 1 (what is built): the hole is real for interrupts and the cost is one instruction per handler. Option 3 is the only one that keeps the PDP-11's flexibility and I would take it if you want nested-interrupt latency tuned per device. Cost to build option 1: already done. **If nothing is done:** option 1 stays.

**How the recommendation compares.** Option 1 matches the modern practice of masking on entry, and it **keeps the multi-level priority** that the one-bit architectures lack, so the handler can lower to the level it wants instead of switching all interrupts back on. It is **less flexible** than per-vector priority (option 3), which the PDP-11 had.

---

## P15. Prefetch

**The need.** A processor spends much of its time waiting for memory. A **prefetch** instruction tells the memory system to start fetching a cache line that the program will soon use, without waiting and without changing any register, so the data is there when the real load arrives. Kernels use it in list and queue walks and in copy loops. The kernel survey counted more than 100 prefetch instructions in the four kernels' sources (AArch64 `prfm`, ARM `pld`, PowerPC `dcbt`, SPARC `prefetch`, x86 `prefetcht0`; its sections 4.4, 4.8 and 4.18). `HINT` has reserved codes that execute as no-ops, but no prefetch is defined, and no decision asks whether one should be.

**The explanation.** A prefetch must carry an address, and `HINT #n` has only a number (the `pad` byte), so a prefetch cannot simply be a hint code: it needs an operand form, like a load that discards its result. It must never fault (a prefetch of a bad address is ignored) and has no architectural effect, only a performance effect.

**Current state.** None. The core and QEMU have no caches to speed up, so a prefetch would be a no-op there; the FPGA implementation would have a data cache, but its prefetch policy is unspecified.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **No prefetch instruction; rely on hardware prefetchers** (hardware that detects streams and fetches ahead) | nothing to specify | irregular patterns (pointer chasing) get no help; small in-order cores seldom have good prefetchers |
| 2 | **A `PREFETCH d(rn)` instruction** (a memory-operand form, non-faulting, no register written) | direct software control; the standard solution | one new opcode or `SYSX` sub-opcode with a memory operand (a larger encoding than `HINT`); compilers must be taught when to use it |
| 3 | **Prefetch with intent and locality fields** (read or write, cache level, streaming: AArch64 `prfm`) | the most expressive; lets a core avoid cache pollution | a field to define and implement; most hardware ignores the extra bits |
| 4 | **Define the hint codes `hint #16` to `#31` as "prefetch the line addressed by `r0`, `r1`, ..."** | reuses the existing `HINT` space; no new opcode | an odd encoding; a fixed register choice; cannot take an offset |
| 5 | **A non-faulting load into a scratch register as the prefetch** (use `movq (rn), rd`, ignore the result) | no new instruction | it occupies a register, can fault, and on an in-order core it stalls on use rather than prefetching |

**What current systems do.** The kernel survey counts prefetch instructions in all four kernels (x86 `prefetcht0` 2 uses in the sampled counts, SPARC `prefetch` 48, and more than 100 across `prfm`/`pld`/`dcbt`). Linux wraps them in `prefetch()` and `prefetchw()` helpers used in list traversal; FreeBSD and the other BSDs have a small number **(checked: Linux `x86/include/asm/processor.h` has `prefetch()` and `prefetchw()`, arm64 `processor.h` uses `prfm pldl1keep`)**.

**What Unix on the PDP-11 and the VAX-11 did.** Neither had a prefetch instruction; the PDP-11/70 cache and the VAX caches were transparent, and the VAX instruction buffer fetched ahead in hardware **(not confirmed in the sources read)**. *Comparison:* the question did not arise on machines whose memory was close to the processor's speed.

**Recommendation.** Option 1 for the in-order implementations, and reserve the shape of option 2 (a non-faulting `PREFETCH` with a memory operand on a free `SYSX` sub-opcode) in the text so it can be added without moving anything. The survey found it used, but mostly in tuned list and copy code; the `mcpy` family and the compiler corpus do not need it. Cost to build now: none. **If nothing is done:** option 1.

---

## P16. Performance counters

**The need.** Counting cycles, instructions, cache misses and branch mispredictions is how kernels and programs find out why they are slow, and how operating systems profile themselves. Without hardware counters, profiling falls back on sampling the program counter at clock ticks, which is coarse. The readiness review and the survey both list an unprivileged `rdcycle`/`rdinstret` under "do later". The survey notes that the *timekeeping* use (a fast clock read, P3) is a separate and earlier need from the *performance* use (counters).

**The explanation.** A **performance monitoring unit** (PMU) is a set of counters that each count a selected event, with a way to read them, to start and stop them, and to raise an interrupt when one overflows (for sampling). The simplest useful version is two free-running counters, cycles and instructions retired, readable from user mode. Anything larger needs event selection, overflow interrupts and virtualization rules.

**Current state.** None; the timer device's counter is a clock, not a cycle counter.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **None (current)** | nothing to build | no hardware profiling; kernels and tools sample at clock ticks only |
| 2 | **Two free-running counters, cycle and instruction count, readable in user mode** (RISC-V `rdcycle`, `rdinstret`) | cheap; enough for benchmarks and a basic profile | the width and clock must be defined; a user-readable cycle counter is a timing side channel, so the kernel needs an enable bit |
| 3 | **A privileged counter block with event selection and overflow interrupts** (x86 `rdpmc`, AArch64 PMU, RISC-V `hpm` counters) | real profiling (sampling by event) | a large block: event list per implementation, interrupts, context-switch state |
| 4 | **Counters in a bus device, not in the processor** | no ISA change; implementations vary freely | every access is a device read; cannot count per-process without kernel help |
| 5 | **A trace interface** (an on-chip trace port, a debug tool) | complete visibility on an FPGA | hardware only; no software use in production |

**What current systems do.** The kernel survey found `rdpmc` in the x86 kernels (6 uses) and AArch64, ARM, PowerPC, MIPS and RISC-V kernels read PMU registers; Linux exposes them through its `perf` subsystem **(Linux perf: arch code exists, e.g. `arm64/kernel/perf_callchain.c`; the drivers are outside the trees read)**.

**What Unix on the PDP-11 and the VAX-11 did.** Neither had a hardware counter that Unix used; profiling used a clock-driven sampling call (the `profil` system call and later `gprof`) **(checked: V7 `profil.2` manual and 4.2BSD `ucb/gprof`)**.

**Recommendation.** Option 2, but only after P3: define the clock first (a constant-rate monotonic counter), then add `rdcycle` and `rdinstret` with the same enable-bit mechanism if profiling needs them. Option 3 should wait for a measured need. Cost to build option 2: two `SYSX` sub-opcodes, a counter definition. **If nothing is done:** option 1.

---

## P17. Constant-time execution (a timing-channel defence)

> **PROPOSED, not decided.** The author asked for this ("a constant-time flag or something, so instructions always take an equal amount of time no matter the input") as part of "no Spectre, no timing-channel attacks". The options below are mine. The catalogue of past hardware bugs that this decision draws on is being written as `docs/hardware-vulnerabilities.md` (not linked yet; it does not exist at the time of writing).

**The need.** A **timing channel** is an information leak through how long something takes. If an instruction takes longer for some operand values than for others, a program that can measure time (and with `RDTIME`, P3, every user program can) learns about the operands. For cryptography the operands are keys, so code that does a divide or a multiply on a secret can leak it. Real examples: an early-out multiplier or divider whose latency depends on the operand's leading zeros, a data-dependent prefetcher, and the frequency-throttling channel that turned power draw into a timing difference (the last two are part of the hardware-vulnerability catalogue). Defences exist in software (write code with no secret-dependent branches, addresses or variable-latency instructions) but only work if the hardware promises which instructions are safe.

**The explanation.** Two different promises are involved, and the options differ in which they make. (1) **Data-independent latency of instructions**: the time an instruction takes does not depend on its operand *values*. (2) **Constant-time code**: a whole routine whose timing does not depend on secrets. The first is necessary for the second and is not sufficient: a load from a table indexed by a secret still leaks through the cache, and a branch on a secret leaks through the branch predictor. So the architecture can promise (1) for a defined set of instructions, and software must still avoid secret-dependent addresses and branches. For an in-order, non-speculative core the promise is cheap; an out-of-order core with predictors, prefetchers and caches has to work to keep it.

**Where pdp64 stands.** The ISA says nothing about instruction timing. In any plausible implementation the instructions that may take data-dependent time are: the `DIV` sequencer (a divider often finishes early on small quotients), a multiplier built with an early-out, `mscn`/`mscnn` (stop at the first match, so they take time that depends on the data), the length-dependent `mcpy`, `mmov` and `mset` (time depends on the count, which is usually public but not always), floating point (subnormal operands, divide and square-root iterations), and every load and store (cache hit or miss). Naturally constant-time on a small core: add, subtract, logic, shifts by a register count (a barrel shifter), rotates, `popcount`, byte swap, compare, `set`, `min`/`max`/`abs`, carry-less multiply and a fixed-latency multiplier. Nothing in the architecture says so today.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **A `PSW` bit, `DIT` (data-independent timing), that the program sets: while it is set, a defined list of instructions takes time independent of operand values; while it is clear, the hardware may use fast paths (divide early-out, `mscn` early exit)** (the shape of Arm's DIT bit and of Intel's data-operand-independent timing mode, both not confirmed in the sources read) | fast paths stay available for normal code; crypto turns it on only where it matters; a mode bit in the `PSW` is saved with it, so there is no new state to switch | a bit and a defined list; the implementation must be able to disable each fast path; a mode bit (accepted under errata 42 because it lives in the `PSW`) |
| 2 | **An unconditional promise for a defined core set (add, logic, shift, rotate, multiply, high multiply, compare, bit counts, byte swap, carry-less multiply, `min`/`max`) with no flag; `DIV`, floating point and `mscn` explicitly excluded** (the shape of RISC-V's scalar-crypto timing subset, not confirmed in the sources read) | no state, no flag; gates are a design rule, not logic (a fixed-latency multiplier is *cheaper* than one with an early-out); easiest to test | nothing for divide or floating point: crypto that needs them (rare) has no safe instruction |
| 3 | **Both: the core set always (option 2) plus the `DIT` bit (option 1) to extend the promise to `DIV`, `mscn` and the block operations** | the strongest; the common case costs nothing; the rare instructions are covered when asked | two things to specify; the bit still needs fast-path disable logic for the instructions it covers |
| 4 | **Everything is always constant-time for integer instructions and the block operations** (`DIV` always takes its worst-case time, `mscn` always scans the whole range or takes a data-independent time, no early-out anywhere), no flag | the simplest to specify and verify; no flag, no fast-path logic at all (fewest gates); matches principles 2 and 3 on a small in-order core | an average divide is slower (the ISA says real divides are rare because compilers turn division by a constant into a multiply); `mscn` loses its early exit, which is its point; floating point still needs its own rule |
| 5 | **Software only: no architectural promise; crypto libraries use a published safe list per implementation** | nothing to specify | the safe list drifts per implementation; this is the situation that produced the surprises on other architectures |

**What current systems do.** Arm has a DIT bit in the processor state that, when set, makes a defined set of instructions data-independent in timing. Intel added a data-operand-independent timing mode (DOITM) in 2022 after earlier documenting a list of instructions that were already constant-time; AMD documents similar guidance. RISC-V's scalar-crypto extension lists the instructions that must have data-independent latency (Zkt), and a vector counterpart exists (Zvkt). Libraries such as OpenSSL, BearSSL and libsodium write constant-time code and are tested with tools that check for secret-dependent branches and addresses; BearSSL, which is in the pdp64 corpus, is built around constant-time implementations **(all of the above not confirmed in the sources read; the claims about specific bits and extensions will be verified in the hardware-vulnerabilities document)**.

**What Unix on the PDP-11 and the VAX-11 did.** Nothing: the machines predate the concern, and the PDP-11's multiply and divide were microcoded with operand-dependent times **(not confirmed in the sources read)**. There was no cache timing to leak on most models. *Comparison:* the question is new, and the PDP-11 and VAX have no precedent; the 30 years since are the evidence.

**What it would cost, from the corpus (added after the author asked how much it would slow the machine).** Static counts of what the compiler emits over the 827-file corpus (370,115 instructions; `docs/codegen-data/mnemonics_pdp64.csv`, measured on the compiled corpus, not run time): **divide (`div`, `divu`) 149 instructions, 0.040%**; block copy (`mcpy`) 154, 0.042%; floating-point divide 10, 0.003%; `mscn`/`mscnn` none (the compiler never emits them); multiply 2,204, 0.595%. **Multiply costs nothing to make constant-time** (a fixed-latency multiplier needs less logic than one with an early-out). So the only integer instruction that gets slower under option 4 is **divide**. As a *rough estimate*, with my assumptions of a 64-cycle worst-case divide against a 30-cycle average and about 1.5 cycles per instruction otherwise: 0.0004 of instructions times 34 extra cycles is about 0.014 cycles per instruction, **about 1% slower over a whole program on average**. Static counts are not run-time counts: a loop that divides on every iteration (a hash with a modulus) could weigh many times more, and the dynamic figure should be measured by running programs under `sim64` with a cycle model, which has not been done. **Published figures** for hardware data-independent-timing modes (Arm's DIT bit, Intel's DOITM, Apple's DIT on newer chips) were not found for this draft and are queued as research; I recall that vendors describe the cost as workload-dependent and small for most code, but I do not have a number and will not quote one *(not confirmed in the sources read)*.

**The author's remark:** "for non-sensitive things, constant time isn't a priority." That points to keeping the fast paths for ordinary code, which favours option 3 (or 1) over option 4: the core set that costs nothing is promised always, and the bit that turns the promise on for divide, `mscn`, `mcmp` and floating point is set by the code that handles secrets (a crypto routine sets it and clears it), so ordinary code never pays.

**Recommendation (revised after the author's remark and the numbers above): option 3.** *My earlier pick, kept for the record:* on a small in-order core the safest and cheapest choice is **option 4 for the integer unit** (no early-out hardware at all, which removes gates, and nothing for software to opt into), plus a one-line rule that floating point and the data-dependent `mscn` are excluded and documented. If you want fast divides for normal code, option 3 keeps them and puts the cost in one `PSW` bit. Under your principles: fewer gates and less recovery code (nothing new to handle) favour option 4; hot-loop speed of divides favours option 3 (but the ISA's own data say divides are rare). Whichever is chosen, say in the ABI and the crypto notes that **constant-time instructions do not make code constant-time**: secret-dependent branches and table indexes still leak through the predictor and the cache. Cost to build: a few lines of specification and a test that measures the latency of each listed instruction over operand patterns (all zeros, all ones, random, small and large); for option 1 or 3, the `PSW` bit and the fast-path disable. **If nothing is decided:** option 5.

---

## P18. The literal pool and execute-only code

> **PROPOSED, not decided.** Found by the OpenBSD-mitigations review (`docs/openbsd-mitigations.md`, ranked first of its improvement ideas). It is cheap: an ABI rule, no hardware.

**The need.** OpenBSD makes code **execute-only** where the hardware allows it (xonly: the code can be run but not read as data), so an attacker who finds a memory-disclosure bug cannot read the program's code to find gadgets or addresses. That needs code pages that hold *only* instructions. Errata 33 put the **literal pool** (the 8-byte constants loaded by `movq =K, rd`) **in `.text`**, flushed at the end of the section or at `.pool`, so every code page can contain data that the program reads. A page the program reads cannot be execute-only.

**The explanation.** The pool sits in `.text` because the load is PC-relative and the displacement of the compiler's pool load has limited reach; the nearest place is the code. If the pool lived in a read-only data section instead, the code would stay pure instructions and could be mapped execute-only, while the constants stay in ordinary read-only memory. The cost is reach: a PC-relative load can only reach so far, so a very large function's pool must still be within range of its loads.

**Current state.** The pool is emitted in `.text` (errata 33). The ABI (`abi.md`) says nothing about execute-only code. The page-table entry has `R`, `W`, `X` permission bits (System v1), so execute-only (`X` without `R`) can already be expressed *(to be confirmed against the section 15 PTE definition)*.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **An ABI rule: the compiler and assembler place each literal pool in a read-only data section adjacent to its code section (`.rodata.pool`), reached by the same PC-relative load; the linker keeps the two sections within reach of each other** | code pages are pure instructions, so they can be execute-only; no hardware change; constants stay read-only | the PC-relative reach limits how far the pool may be; the linker must place the pool section near its text (an ordering rule); a few code-size bytes if a long form is needed for distant pools |
| 2 | **Keep the pool in `.text` (as errata 33 says today)** | nothing to do | no execute-only code on pdp64; the mitigation OpenBSD relies on elsewhere is unavailable |
| 3 | **Per-function pool islands, placed between functions, in a page marked readable-and-executable** | pools stay close to their loads | execute-only is lost for those pages; the idea defeats its own purpose |
| 4 | **Move the constants into the global data and load them with an absolute or GOT-style address** | no reach limit | an extra indirection per constant; relocations; more code; against principle 1 |
| 5 | **Build wide constants from pieces (shift and or) so there is no pool** | no data in code at all | several instructions per constant; against principles 1 and 3 |

**What current systems do.** OpenBSD uses execute-only code on amd64 (where the hardware supports it through protection keys) and on arm64 *(per the OpenBSD review, `docs/openbsd-mitigations.md`; not confirmed against the source)*. ARM compilers historically put literal pools in the text section next to the code, and the modern way to get execute-only code is to move them out (a flag exists for this in the compilers) *(not confirmed in the sources read)*. RISC-V builds constants from instruction pairs or loads from a pool placed in data *(not confirmed)*.

**What Unix on the PDP-11 and the VAX-11 did.** The PDP-11 put immediate operands in the instruction stream, and with separate instruction and data spaces (the larger models) the program could not read its own instructions as data except through the move-from-instruction-space instructions *(not confirmed in the sources read)*: the nearest ancestor of execute-only code. The VAX had no such separation.

**Recommendation.** Option 1. It costs no gates and no opcodes (principles 3), adds one placement rule for the assembler and linker, and keeps the code pure so that the hardware can give it the strongest page permission (the recovery-code argument of principle 2 is that a memory-disclosure bug then reveals no code). Cost to build: `as64` places the pool in a `.rodata.pool` section next to its text section, `ld64` orders the two sections together and checks the PC-relative reach, and the pcc back end is unchanged (it already emits `=K`); a test checks that a built program's text segment contains no data reads. **If nothing is decided:** option 2, and no execute-only code.

---

## Part B. Previous decisions, written up so they can be changed

These were decided earlier (the errata cited). They are set out in the same form as P1 to P14 so that any of them can be reopened: if you want to change one, mark it, and it becomes a new erratum. "Keep" below is my view of whether to keep it, not a decision. Unchecked facts from my memory are marked (from memory, not confirmed in the sources read).

| # | Decision | Decided in | My view |
|---|---|---|---|
| Q1 | Exception entry saves state in registers (`EPC`, `EPSW`), with `pushx`/`popx` | errata 36, 37 | keep |
| Q2 | Accessed and dirty bits are managed by software | errata 36 | keep for v1, make hardware management optional later |
| Q3 | Three-level page tables, 39-bit virtual, 40-bit physical, 4 KB pages | errata 36 | keep |
| Q4 | Eight interrupt priority levels in the `PSW`, no interrupt controller | errata 36 | keep |
| Q5 | Sequential consistency as the memory model | ISA section 17 | keep for now, revisit when an out-of-order core is real |
| Q6 | In-order FPGA and ASIC, architecture kept ready for out-of-order | errata 38 | keep |
| Q7 | Condition codes kept (two flag groups; `cbCC`, moves, loads and stores write none) | errata 14, 39 | keep, consider opt-in flag writing |
| Q8 | Instruction length 2, 4 or 6 bytes plus a one-parcel second page | errata 31 | keep |
| Q9 | Integer arithmetic only 64-bit, no sized ALU operations | errata 28 | keep, measure the cost of the extensions |
| Q10 | Devices are eight memory-mapped registers plus DMA | errata 29 | keep, consider compatibility with virtio |
| Q11 | Wide constants come from an explicit literal pool (`=K`) | errata 33 | keep |
| Q12 | System registers are reached by `MFSR`/`MTSR` with an 8-bit number | errata 32 | keep |
| Q13 | Carry on subtract means borrow (the PDP-11 sense) | errata 14 | keep |
| Q14 | Operating system order: OpenBSD first, Unix/32V fallback | errata 41 | keep, weigh NetBSD |
| Q15 | `ISYNC`: system-register writes take effect only after an explicit instruction | errata 39 | keep |

---

## Q1. Exception entry saves state in registers

**The need.** When an exception or interrupt arrives, the processor must remember where it was (the program counter and the status word) so the handler can return. Where that memory lives decides the cost of every system call and interrupt, and whether entry can itself fault.

**The explanation.** Two broad designs. The processor can **push** the old program counter and status onto a stack in memory (the PDP-11, the VAX, x86). Or it can **latch them in registers** (`EPC`, `EPSW`) and let the handler save them if it needs to (AArch64, RISC-V, MIPS, PowerPC). Registers make entry cheap and unable to fault; the price is that a second exception before the handler has saved them overwrites them (which is why errata 40 raises the priority to 7 on entry), and the handler must save them itself. `pushx`/`popx` (errata 37) are one instruction each for saving and restoring both.

**Current state.** Registers plus `pushx`/`popx`; the kernel survey puts the system-call entry at 4 to 5 instructions on paper (not measured).

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Registers + `pushx`/`popx` (current)** | no memory write at entry; entry cannot fault; short path | handler discipline; needs priority 7 on entry; nested exceptions need the explicit save |
| 2 | **Hardware pushes `PC` and `PSW` on the kernel stack** (PDP-11, VAX, x86) | nesting is automatic and safe | a memory write at entry that can fault; a stack must always be valid |
| 3 | **Swap status words in fixed memory** (s390 style) | simple hardware | slow; not re-entrant without extra work |
| 4 | **A shadow register bank** that is switched in on entry (ARM fast-interrupt style) | no save at all for one level | only one level deep; more registers to build |
| 5 | **Registers, but the hardware also stacks them once a nesting flag says so** | automatic nesting | a mode and state; against the simple design |

**What current systems do.** The kernel survey found that AArch64, RISC-V, MIPS, LoongArch and PowerPC save the return address and status in registers; x86 pushes five words; s390 swaps whole status words in low memory. NetBSD and OpenBSD on x86 therefore carry code to cope with the pushed frame (from memory, not confirmed in the sources read).

**What Unix on the PDP-11 and the VAX-11 did.** Both pushed the old `PC` and `PS`/`PSL` on the kernel stack, in hardware; the PDP-11 loaded the new `PC` and `PS` from the vector. *Trade-off:* the stack made nesting free and made entry a memory operation; Unix's trap code relied on the pushed frame being there. *Comparison:* the pdp64 trades that safety for a short, fault-free entry, and pays with the priority-7 rule and one explicit save.

**View.** Keep. It is the modern RISC arrangement, and option 2 would put a memory write on every system call.

---

## Q2. Accessed and dirty bits are managed by software

**The need.** A page-replacement policy has to know which pages were used (**accessed**) and which were written (**dirty**, so they must be written back before reuse). The page-table entry holds a bit for each. The question is who sets them.

**The explanation.** If the **hardware** sets them, the memory-management unit must do an atomic read-modify-write of the entry on a first touch, which complicates the walker and, with several cores, needs care. If **software** manages them, the first touch of each page and the first write to it cause a fault and the kernel sets the bit; this is simple hardware but costs a fault per page per event. System v1 chose software, partly on the grounds that a hardware modify bit with software-emulated reference bits is how 3BSD paged on the VAX (checked: 3BSD `usr/doc/vmunix/design.t` says the VAX-11/780 has no reference bit, and `vmpage.c` pageout simulates it).

**Current state.** Software-managed accessed and dirty bits; one extra fault on first touch of each page and one more on first write (system design, D8).

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Software-managed (current)** | simplest walker; no atomic update in hardware | two extra faults per page; slower for a big working set |
| 2 | **Hardware sets both, atomically** (x86) | no faults; fastest | the walker writes memory; atomicity with other cores and DMA; harder out-of-order |
| 3 | **Optional hardware management with a software fallback** (AArch64 and RISC-V have it as an option) | cheap cores stay simple; fast cores skip the faults | two modes to specify; a feature bit (see P4) |
| 4 | **Hardware dirty, software accessed** (the VAX had a hardware modify bit and no reference bit) | the dirty write-back case is cheap | half the benefit; still emulation for reference |
| 5 | **No accessed bit; approximate usage another way** (periodic protection tricks) | simplest page table | worse replacement decisions |

**What current systems do.** x86 sets both in hardware; AArch64 and RISC-V make hardware management optional and fall back to a fault (checked for RISC-V: Svade/Svadu in the ISA manual; AArch64 FEAT_HAFDBS: QEMU `ptw.c`, see the earlier fact check); MIPS uses software refill and software bits. Linux on RISC-V runs the software scheme when the hardware lacks the option (not confirmed in the sources read).

**What Unix on the PDP-11 and the VAX-11 did.** The PDP-11's page descriptor registers have a W bit set by the hardware when the page is written and an A bit set when an access met the page's trap condition, both cleared when the register is written (corrected after checking the 04-55 handbook: the A bit is not a plain accessed bit), usable for swapping. The VAX hardware set a modify bit and had no reference bit, so 4BSD emulated reference bits in software by invalidating pages and noting the resulting faults (checked: 3BSD `design.t` and `vmpage.c`, "simulating the missing hardware reference bit"). *Trade-off:* the emulation cost faults for a policy the hardware could not give. *Comparison:* the pdp64's scheme is the VAX scheme plus emulated modify bits; it is worse than the VAX for dirty tracking and no worse for reference.

**View.** Keep for System v1, then move to option 3 once there is a feature register to advertise it. Software-only is acceptable for a first system, but the extra faults will show up in any measurement of a real workload.


**Revised for your principles.** Your recovery priority argues against software-managed bits: each extra fault type (first touch, first write) is another case in the kernel's fault handler and a path that can go wrong, while hardware-managed bits remove those cases. Your gates priority argues for software, because the hardware version needs an atomic read-modify-write in the table walker. The two priorities pull in opposite directions here. My pick: keep software for System v1 and make option 3 (optional hardware management, advertised in the feature registers of P4) the planned next step, so the kernel can drop the fault paths on hardware that has it.
---

## Q3. Three-level page tables, 39-bit virtual, 40-bit physical, 4 KB pages

**The need.** The page-table shape fixes how much memory a process can address, how many memory reads a translation costs, and how large a table is.

**The explanation.** Each level multiplies reach by 512. Three levels of 9 bits over a 12-bit page offset give 39 bits, 512 GB. The ISA calls this "one bit of headroom" over the physical window and lets the direct-mapping windows reach physical memory with no translation. More levels mean a larger address space and a longer walk on a TLB miss.

**Current state.** 3 levels, 9 + 9 + 9 + 12, entry with the physical page number in place, a flag field in the low bits; large leaf pages (1 GB) usable by the kernel.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **3 levels, 39-bit (current)** | short walk; small tables; the RISC-V Sv39 shape (from memory, not confirmed in the sources read) | 512 GB limit per address space; a database or a memory-mapped large file can run out |
| 2 | **4 levels, 48-bit** (x86-64, AArch64) | huge address space | a longer walk; more table memory |
| 3 | **Larger base page (16 or 64 KB)** | fewer levels and fewer TLB misses | internal fragmentation; software that assumes 4 KB |
| 4 | **A linear table** (VAX) or a **hashed table** (PowerPC) | simple hardware or fast lookup | large contiguous allocations; hash collisions |
| 5 | **Software TLB refill, no hardware walker** (MIPS) | any table format the kernel likes | a software refill handler runs on every TLB miss, which is slow |

**What current systems do.** x86-64 uses four levels (and five on newer parts), AArch64 up to four with 4 KB pages, RISC-V Sv39 / Sv48 / Sv57 (checked: the RISC-V ISA manual names all three); the survey notes the hardware walker avoids the software refill instructions of MIPS, embedded PowerPC, PA-RISC and LoongArch.

**What Unix on the PDP-11 and the VAX-11 did.** PDP-11: eight segments per mode with base and length, no page tables as such. VAX: a linear page table per region (P0, P1, system) with base and length registers, 512-byte pages; the user page tables were themselves in virtual system space. *Trade-off:* the VAX scheme made big sparse address spaces cost a lot of page-table memory. *Comparison:* a multi-level tree wastes less on sparse spaces than the VAX's linear tables.

**View.** Keep. A fourth level can be added later behind a feature bit if 512 GB becomes the limit.

---

## Q4. Eight interrupt priority levels in the `PSW`, no interrupt controller

**The need.** Interrupts must be ordered so that urgent devices can interrupt slower handlers, and the kernel must be able to block them to protect its data.

**The explanation.** The PDP-11 solved both with a priority in the status word: a device asserts a level; the processor takes it if the level is above its own. Unix built its locking on this (the `spl` calls: raise the priority to keep a handler out, then lower it). Modern systems use an **interrupt controller** that ranks many sources and a single mask bit in the processor.

**Current state.** Eight levels (0 to 7) in the `PSW`; `SPL #n` sets it; timer at 6, console at 4; no controller code needed.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **8 levels in the `PSW` (current)** | the V7/3BSD model; no controller code; trivial `spl` | only 8 classes; devices at the same level can't be ordered by the processor |
| 2 | **32 levels** (VAX `IPL`) | finer classes | more bits in the `PSW`; more levels to assign |
| 3 | **One mask bit + an external controller with priorities** (x86 APIC, RISC-V PLIC) | scales to many sources and cores | a controller to design, drive and virtualize |
| 4 | **Per-source programmable priority in a controller** (AArch64 GIC) | most flexible | the biggest hardware and driver burden |
| 5 | **No priorities: one mask, threaded handlers** (interrupts only wake threads) | simplest hardware | latency and priority inversion are the kernel's problem |

**What current systems do.** The survey found the VAX and m68k raise the processor priority; x86, AArch64, RISC-V, PowerPC, MIPS and SPARC mask on entry. NetBSD and OpenBSD keep the `spl` interface and emulate it in software on most machines, because the hardware has no priority levels (survey); with option 1 the emulation disappears.

**What Unix on the PDP-11 and the VAX-11 did.** PDP-11: the `PS` priority and device lines BR4 to BR7; Unix wrote `spl4()`, `spl5()`, `spl6()` and `spl7()` around critical code. VAX: interrupt priority levels 0 to 31 (31 interrupt levels, 1-15 software and 16-31 hardware, plus level 0; checked: VAX-11 Architecture Reference Manual 6.1.1) and the same `spl` family (`splbio`, `splnet`, `spltty`, `splclock`). *Trade-off:* a priority scheme is cheap and gives priority inversion only through bad assignment. *Comparison:* it is exactly the model that BSD kernels are written for, so an OpenBSD port gets its locking model with no emulation layer.

**View.** Keep. It is a real strength for the OpenBSD plan.

---

## Q5. Sequential consistency as the memory model

**The need.** With several processors and caches, the architecture must say in what order one processor's memory writes can be seen by the others. The stronger the promise, the simpler the software and the harder the fast hardware.

**The explanation.** **Sequential consistency** means the result is as if all processors' accesses happened in some single order that respects each program's own order: the easiest to reason about. Weaker models (x86's **total store order**, ARM's and RISC-V's weak models) let hardware reorder and require **fences** where software needs order. Large out-of-order cores pay for sequential consistency by speculating on loads and replaying when another core intervenes.

**Current state.** Sequential consistency (ISA section 17); `FENCE` exists for device ordering; weakly ordered device pages exist by memory type. The readiness review rates it "awkward but defined" for out-of-order.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Sequential consistency (current)** | simplest software; no fences in normal code | speculation and replay in a large core; limits some optimizations |
| 2 | **Total store order** (x86) | nearly as easy; stores buffered | a store buffer rule to specify; the one reordering software must know |
| 3 | **Weak ordering with fences** (ARM, RISC-V RVWMO, POWER) | fastest hardware | fences and subtle bugs in software; harder to verify |
| 4 | **Sequential by default, weak by page type or mode** | strong where needed, fast where chosen | a second model to specify and test; mixes are hard |
| 5 | **Total store order now, tighten to sequential on request** | an easy step toward both | two meanings of the same program |

**What current systems do.** x86 total store order; AArch64, ARM and POWER weakly ordered; RISC-V offers a weak model with optional total store order; Alpha was the weakest, even reordering dependent loads (RISC-V RVWMO with optional Ztso: checked, ISA manual; the others not read). Linux and the BSDs carry barrier macros for each.

**What Unix on the PDP-11 and the VAX-11 did.** On one processor the question didn't arise; the Unibus and VAX interlocks gave the ordering that devices needed; multiprocessor VAX systems used interlocked instructions to synchronize. *Comparison:* sequential consistency is the single-processor illusion extended to several, which is why the heritage fits it.

**View.** Keep while the cores are small and in order. Revisit when an out-of-order core is really planned: total store order (option 2) would be the least painful retreat.

---

## Q6. In-order FPGA and ASIC, architecture kept ready for out-of-order

**The need.** A small in-order core is cheap to build and verify, which fits an FPGA. But an instruction set can be designed so a later, much faster core is impossible or ugly. The decision was to build small and keep the door open.

**The explanation.** The cost of "ready" is visible: the readiness review found that condition codes are the structural obstacle (68.2% of compiled instructions wrote a flag), and errata 39 removed most of that. The remaining text items (reservation rules, side-effect rules) are still to be written.

**Current state.** In-order implementations; out-of-order readiness a design aim (errata 38, 39).

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **In-order now, out-of-order-ready (current)** | small cores soon; a path to speed | design discipline; some choices made for a core that may never exist |
| 2 | **Design for out-of-order only** | the best large core | a harder first implementation; the FPGA suffers |
| 3 | **In-order forever** | simplest ISA and verification | a performance ceiling |
| 4 | **Exposed pipeline / very long instruction word** | simple hardware, compiler schedules | a different ISA; compilers and software are harder |
| 5 | **Microcoded small core** (the 1970s way) | tiny area | slow; wrong for the target |

**What current systems do.** The same instruction set often spans in-order and out-of-order cores: ARM's small in-order cores beside its out-of-order ones, RISC-V's Rocket (in order) and BOOM (out of order), x86 from the in-order Pentium to the out-of-order P6, Alpha from the 21064 to the 21264 (all from memory, not confirmed in the sources read).

**What Unix on the PDP-11 and the VAX-11 did.** Both lines ran many implementations, from microcoded to pipelined, under one instruction set; the VAX's complexity (long, orthogonal instructions with many side effects) is generally blamed for making its later fast implementations hard (from memory, not confirmed in the sources read). *Comparison:* this decision is exactly the lesson of the VAX: keep the instruction set implementable fast, and ready from the start.

**View.** Keep.

---

## Q7. Condition codes kept, with two flag groups

**The need.** After arithmetic and comparisons, a branch needs to know the outcome. The two designs are a **flag register** written by instructions (PDP-11, VAX, x86, ARM) or **no flags**, where a compare-and-branch tests registers directly (MIPS, RISC-V).

**The explanation.** Flags are compact and make multiword arithmetic and tests cheap, but every flag-writing instruction creates a dependency that an out-of-order core must track. Errata 39 keeps the flags but makes them far cheaper to track: two groups (`C` and `{N, Z, V}`), `cbCC` and moves, loads and stores write none, shifts write the same flags for any count.

**Current state.** Flags kept as described; a measured cost in code size from the compiler change of +0.39% (1,499,530 to 1,505,382 bytes on the 827-file corpus; `docs/codegen-data/pdp64-after-errata39.csv`), against an estimate of at most about 0.77% in errata 39.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Flags with the two-group rule (current)** | compact code; PDP-11 heritage; cheap compares | flag writers remain in many instructions (68.2% of compiled instructions wrote a flag before errata 39; the share afterwards was not measured); a rename path for the flags in a large core |
| 2 | **Opt-in flag writing: only instructions marked "set flags" write them** (AArch64 `adds`) | flag dependencies only where wanted | an extra bit or forms in the encoding; larger code |
| 3 | **No flags; compare-and-branch and set-on-compare only** (RISC-V, MIPS) | simplest for out-of-order | multiword add/subtract needs explicit carry code; the corpus shows many `cmp`+branch pairs that need to be re-expressed |
| 4 | **Several condition fields** (PowerPC `CR0` to `CR7`) | independent flag sets | a register file to rename; more encoding |
| 5 | **PDP-11 exact: every instruction writes flags** | the classic | the structural problem the review found |

**What current systems do.** x86 and ARM32 write flags on most arithmetic; AArch64 writes them only on the "s" forms; RISC-V and MIPS have none; PowerPC has eight fields (not confirmed in the sources read).

**What Unix on the PDP-11 and the VAX-11 did.** Both wrote condition codes on nearly every instruction, including moves, and Unix's compiled code relied on that (a `tst` after a move was often omitted). *Trade-off:* compact code and cheap tests, with a hidden dependency in nearly every instruction. *Comparison:* the pdp64 keeps the programming model and drops the dependencies that cost most; its compiler had relied on the old behaviour and the change cost a small amount of code size (0.39% not found; see Current state).

**View.** Keep. Option 2 is worth a look if a large core is built, but it would reopen the encoding.

---

## Q8. Instruction length: 2, 4 or 6 bytes plus a one-parcel second page

**The need.** The length of instructions decides code size, fetch bandwidth and how hard decoding is.

**The explanation.** Fixed-length instructions decode trivially but waste space; variable-length ones are denser but make wide decoding harder. The pdp64 uses 16-bit **parcels**: an instruction is one, two or three of them, and the first parcel says which. A second page of one-parcel abbreviations (`len = 11`) covers the commonest forms in two bytes.

**Current state.** 2, 4 or 6 bytes; 45 one-parcel abbreviations (checked against the grammar, `spec/pdp64-mnemonics.hbnf`, which defines 45 page-2 opcodes including `0x2C` and `0x2D`; ISA 4.18 said 43 only because it predated errata 39 and has been brought up to date); measured code size within 0.2% of `gcc -Os` and 7% below `clang -Os`.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **2/4/6 bytes + second page (current)** | dense; length found from the first parcel; PDP-11 lineage | variable length; branches and calls need relaxation |
| 2 | **Fixed 32 bits** (AArch64, MIPS) | trivial decode | about a third larger code; 32-bit constants need sequences |
| 3 | **16/32-bit mix** (RISC-V C, Thumb-2) | dense and mostly regular | the compressed forms limit register choice |
| 4 | **Byte-granular** (x86, VAX) | densest | the hardest to decode wide; length from the whole prefix |
| 5 | **Fixed 64-bit / bundled** (VLIW) | simple fetch | large code; a different machine |

**What current systems do.** AArch64 fixed 32; RISC-V 16/32 mixed (checked: ISA manual instruction-length encoding); x86 byte-granular up to 15 bytes (not confirmed in the sources read).

**What Unix on the PDP-11 and the VAX-11 did.** PDP-11: 1 to 3 sixteen-bit words, the length read from the opcode and addressing modes; VAX: 1 to 57 bytes with an operand specifier per operand. *Trade-off:* the VAX's byte-level generality made long, slow decoders; the PDP-11 shape is the kind that stays reasonably easy. *Comparison:* the pdp64 literally keeps the PDP-11 parcel scheme with the length in the first parcel, which is the easy end of variable length.

**View.** Keep.

---

## Q9. Integer arithmetic only 64-bit, no sized ALU operations

**The need.** C's `int` is 32 bits and `char` and `short` are narrower. The question is whether the machine has native narrow arithmetic.

**The explanation.** The PDP-11 had 16-bit and byte operations; the VAX had byte, word, long and quad operations. A 64-bit machine can do all arithmetic in 64 bits and extend results when narrower values are stored or loaded, keeping the instruction set small. The price is that 32-bit wraparound semantics need an extension instruction after an add that might overflow, and signed 32-bit arithmetic needs a sign extension.

**Current state.** All arithmetic is 64-bit; narrow loads sign- or zero-extend; the compiler emits `movl`/`movzb`-style extensions where C's rules require them (about a thousand sites were counted in the flag work; the corpus-wide extension cost was not separately measured).

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **64-bit only (current)** | small ISA; simple core | extension instructions after narrow arithmetic |
| 2 | **Add 32-bit forms of add, subtract, shift** (AArch64 `w`, RISC-V `addw`) | no extension after 32-bit arithmetic | a second set of opcodes; page-2 space |
| 3 | **Fully sized operations** (VAX, x86) | exact C semantics | a huge instruction set |
| 4 | **Sign-extension as a side effect of every narrow operation by a mode** | none needed | a mode bit that changes what arithmetic means: it must be saved at every context switch and every reader of the code must know the mode (the cost the old rule protected against); acceptable only if the saving in instructions is large |
| 5 | **A single `sext`/`zext` that fuses with the previous operation in hardware** | no encoding change | fusion hardware that small cores avoid |

**What current systems do.** RISC-V RV64 and AArch64 both have 32-bit forms of the common operations; MIPS64 has separate 32-bit and 64-bit adds; x86-64 has sized operations (from memory, not confirmed in the sources read).

**What Unix on the PDP-11 and the VAX-11 did.** PDP-11: word and byte forms (`MOVB`, `CMPB`, `INCB`) with the byte sign-extending into registers on load; VAX: sized operations for every data type. *Trade-off:* sized operations made programs compact and the instruction set large. *Comparison:* the pdp64 deliberately gives up the PDP-11's sized operations, and the compiler pays with extension instructions that the other two 64-bit RISCs avoid with their 32-bit forms.

**View.** Keep, but measure the extension overhead on the corpus; if it is more than a few percent of instructions, option 2 is the usual fix and fits the second page.


**Revised for your principles.** Under your code-size and hot-loop priorities this moves from "keep" to "**measure now**". The compiler spends an extension instruction (`movl`, `movzb` and the like) after narrow arithmetic; the flag work counted about a thousand `movl`-type sites among sites that mattered for flags, but the total extension overhead on the corpus was never measured. Count it: if extensions are more than a few percent of instructions or bytes, add 32-bit forms of add, subtract, shift and multiply on page 2 (two bytes each), as AArch64 and RISC-V do. If it is under about one percent, keep as is. The measurement is one script over the compiled corpus (`tools/pdp64size.py` already classifies mnemonics).
---

## Q10. Devices are eight memory-mapped registers plus DMA

**The need.** How a driver talks to a device decides how much code every device costs and how fast it can go.

**The explanation.** Devices appear as a few addresses; the processor sets a transfer up by writing them, and the device moves the data itself by **DMA** (direct memory access) and interrupts when done. Fewer registers means less driver code; the author's goal was a driver that is trivial to write and a processor that is left free.

**Current state.** Ethernet, USB and disk each eight registers plus DMA (errata 29); layout, descriptor format and doorbell convention not yet written.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Eight registers + a descriptor chain (current)** | tiny drivers; PDP-11 spirit | USB and Ethernet at speed want queues of many descriptors; one layout may not fit all three |
| 2 | **Virtio-style: a small register set plus shared-memory queues** | existing drivers in OpenBSD and others (from memory, not confirmed in the sources read); standard for virtual machines | the queue formats to implement in hardware |
| 3 | **NVMe or xHCI style: many registers, doorbells and rings** | the fastest, matches real hardware | large and complex drivers |
| 4 | **Programmed I/O only (no DMA)** | trivial devices | the processor moves every byte |
| 5 | **Channel I/O** (IBM mainframe style) | the processor offloads completely | a second processor per channel |

**What current systems do.** Virtual machines use virtio; real storage and network devices use NVMe, xHCI and vendor ring designs; embedded systems use memory-mapped register blocks with DMA descriptors.

**What Unix on the PDP-11 and the VAX-11 did.** Unibus devices had a handful of registers (a disk controller about eight; a serial line four), some with DMA (disks) and some with programmed I/O (terminals); the VAX added the Unibus adapter with map registers for DMA. *Trade-off:* simple drivers, little parallelism. *Comparison:* this is the PDP-11 device model; its weakness is throughput at gigabit rates, where ring-based designs win.

**View.** Keep, and consider making the virt machine's devices virtio-compatible because an OpenBSD port could reuse its virtio drivers (OpenBSD virtio drivers: not found in the sparse tree, which has `sys/arch` only; not confirmed).


**Revised for your principles.** Under code size and gates the plain eight-register layout is the strongest choice (small drivers, simple devices). The suggestion to consider virtio compatibility is softened: take it only if reusing OpenBSD's existing virtio drivers saves more driver code than virtio's extra registers and queue formats cost.
---

## Q11. Wide constants come from an explicit literal pool

**The need.** A 64-bit machine with short instructions must still load constants that do not fit in an instruction.

**The explanation.** The assembler can place the constant in a table near the code and load it by a PC-relative instruction. The question was whether the assembler does that silently when a constant is too wide, or only when asked. The decision: only when asked, with `=K`; a too-wide bare immediate is an error.

**Current state.** `movq =K, rd` plus `.pool`; the compiler uses it.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Explicit `=K` pool (current)** | nothing hidden; the programmer sees the load | an extra memory read and a pool placement concern |
| 2 | **A 64-bit immediate instruction form** (x86 `movabs`) | no memory read | an instruction up to 10 bytes; does not fit the parcel scheme |
| 3 | **Built from pieces** (AArch64 `movz`/`movk`, RISC-V `lui`/`addi`) | no data access | three or four instructions per constant |
| 4 | **Constants in a global table** (a GOT-like) | position independence | an extra indirection |
| 5 | **Silent pooling** by the assembler | convenient | surprises; the rejected option |

**What current systems do.** ARM32 and some AArch64 code use literal pools; RISC-V uses `lui`/`addi` and a pool for 64-bit constants; x86 has `movabs` (from memory, not confirmed in the sources read).

**What Unix on the PDP-11 and the VAX-11 did.** PDP-11: an immediate is a word that follows the instruction (autoincrement on the PC); VAX: an immediate operand could be as wide as 8 bytes inline. *Trade-off:* inline immediates make instructions long. *Comparison:* the PDP-11 style does not extend to 64 bits within 6-byte instructions, hence the pool.

**View.** Keep.

---

## Q12. System registers through `MFSR`/`MTSR` with an 8-bit number

**The need.** The kernel must read and write processor control state (page-table base, vector base, exception state).

**The explanation.** Either each register has its own instructions, or one pair of instructions takes a register number. The survey found most architectures use the second. The pdp64 has 243 numbers free.

**Current state.** `MFSR`/`MTSR`, privileged, 13 registers defined.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **`MFSR`/`MTSR` + number (current)** | few opcodes; room to grow | an indirect register file |
| 2 | **Memory-mapped control registers** (the PDP-11 way) | no instructions | a load or store that must not be cached or reordered |
| 3 | **A dedicated instruction per register** (x86 `mov cr`) | explicit | opcode space grows with every register |
| 4 | **Atomic read-modify-write forms** (RISC-V `csrrs`, `csrrc`) | set or clear bits in one step | more instruction forms |
| 5 | **Registers behind a bus device** | no instructions | slow; not for exception state |

**What current systems do.** AArch64 `mrs`/`msr`, RISC-V `csrr`/`csrw`, MIPS `mfc0`/`mtc0`, PowerPC `mfspr`/`mtspr` (checked: kernel survey tables); the survey counted privileged-register access as 48% of all compiler-invisible occurrences.

**What Unix on the PDP-11 and the VAX-11 did.** PDP-11: control registers at fixed high addresses (the MMU registers, the `PS`), accessed with ordinary moves; VAX: `MTPR`/`MFPR` with an internal-register number, exactly option 1. *Comparison:* the pdp64 takes the VAX route.

**View.** Keep; add the set/clear forms (option 4) only if profiling shows read-modify-write on control registers in a hot path.

---

## Q13. Carry on subtract means borrow

**The need.** After a subtract or compare, what the carry flag means decides how the unsigned comparisons are written.

**The explanation.** On the PDP-11, VAX, x86 and m68k, subtraction sets `C` when it borrows, so "no borrow" means unsigned greater-or-equal. ARM and AArch64 do the opposite: `C` is "not borrow". Both work; mixing conventions breaks code written for the other.

**Current state.** Borrow sense (PDP-11), so `BHIS`/`BCC` mean "no borrow", unsigned greater-or-equal (errata 14).

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Borrow (current)** | PDP-11 code and habit carry over | different from ARM |
| 2 | **Not-borrow** (ARM, AArch64) | multiword subtract uses the same carry as add | different from the heritage |
| 3 | **Select by instruction** | both available | confusion; extra forms |
| 4 | **No carry from subtract** | simplest | multiword subtract needs a set-on-less |
| 5 | **Two flags** | explicit | state |

**What current systems do.** x86 and m68k borrow; ARM family not-borrow; RISC-V has no flags (from memory, not confirmed in the sources read).

**What Unix on the PDP-11 and the VAX-11 did.** Both used the borrow sense, and Unix's assembly and compilers assume it.

**View.** Keep; this is a heritage choice with no performance weight.

---

## Q14. Operating system order: OpenBSD first, Unix/32V fallback

**The need.** The first operating system fixes what the architecture, the compiler and the toolchain must provide.

**The explanation.** OpenBSD needs the LLVM back end, which is the long pole; Unix/32V needs only the existing compiler but is old and swaps whole processes. 3BSD was dropped.

**Current state.** Errata 41.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **OpenBSD first, 32V fallback (current)** | a modern, secure system; one back end serves clang | depends on the LLVM work; effort estimate unproved |
| 2 | **32V first** | needs only the existing compiler | old; no paging; a dead end |
| 3 | **NetBSD first** | the most portable BSD kernel; it has a VAX tree and the survey found OpenBSD has none | needs the same compiler work; a different security stance |
| 4 | **Linux** | the biggest ecosystem | the largest port; needs a GNU or LLVM toolchain; the kernel assumes much of its architectures |
| 5 | **A new small kernel** | complete control | no ecosystem |

**What current systems do.** OpenBSD supports a long list of architectures with a single source tree; NetBSD is known for the widest portability; Linux has the most ports (checked: OpenBSD tree has 13 architecture directories, the NetBSD sparse tree more, Linux 11 in the sparse tree; "widest portability" is a reputation, not checked).

**What Unix on the PDP-11 and the VAX-11 did.** The line ran Research Unix and BSD. *Comparison:* NetBSD's VAX heritage means its machine-dependent layer is the closest living relative of the pdp64's design; that is the one reason to look at option 3 before starting.

**View.** Keep, but have a look at NetBSD's VAX code during the OpenBSD bring-up; it is the closest model for the machine-dependent parts.

---

## Q15. `ISYNC`: system-register writes take effect only after an explicit instruction

**The need.** After the kernel changes the page-table base, the vector base or the translation control, the processor may have fetched or translated using the old values. An out-of-order or deeply pipelined core needs to be told when to drain.

**The explanation.** Either every write takes effect at once (simple, but it forces a pipeline flush on each write), or the architecture says the effect is guaranteed only after an explicit synchronizing instruction. Errata 39 chose the latter: the small in-order cores may apply writes immediately; software must still execute `ISYNC`.

**Current state.** `ISYNC` exists; the emulators apply writes at once and flush the translation state at `ISYNC`.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Explicit `ISYNC` (current)** | out-of-order friendly; cheap on in-order | software must remember it; a forgotten one works on small cores and fails on a big one |
| 2 | **Immediate effect** | simple software | a flush on every write; hard on a big core |
| 3 | **Writes to certain registers are automatically serializing** (x86 for control registers) | nothing to remember | hidden stalls |
| 4 | **Per-register rules** | exact | more to specify and to get wrong |
| 5 | **Hardware tracks the dependency** | none | the most complex hardware |

**What current systems do.** AArch64 `isb`, RISC-V `fence.i` / `sfence.vma`, x86 serializing instructions and control-register writes (checked: kernel survey; RISC-V `fence.i` in the ISA manual); the survey found the context-synchronizing barrier is the most used barrier on most architectures (`isb` 187, `isync` 662, SPARC `membar` 533 occurrences).

**What Unix on the PDP-11 and the VAX-11 did.** Both applied changes at once (a write to the MMU registers or to `MAPEN` or the translation-buffer registers took effect immediately); the VAX required a short discipline around `MAPEN`. *Comparison:* the pdp64 follows modern practice at the cost of one instruction in rare kernel paths.

**View.** Keep.

---

## Part C. The gaps: several cores, DMA devices and virtualization

Nothing in the documents decides these yet. The system architecture and the bus document list them as open items ("not yet defined"); Parts A and B above cover the pieces that already exist (P6, P11, Q4, Q5, Q10). They are written in the same form so you can choose. The facts about other systems and about the PDP-11 and VAX are from my memory and are **not confirmed in the sources read** unless the text says they come from the kernel survey; the survey itself is about assembly instructions, not about these subsystems, so it says little here.

The boot decisions (the first code, starting the other cores, the hand-off, device initialisation, UEFI) are in [`boot.md`](boot.md) as B1 to B5; B2 covers the secondary-core start that R2 also touches.

| # | Decision | My recommendation | Needed for |
|---|---|---|---|
| R1 | The interrupt controller and routing interrupts to cores | a small controller with a per-core threshold and message-signalled interrupts | the second core; any device that is not core 0's |
| R2 | Inter-processor interrupts and starting the other cores | per-core doorbell registers; cores held in reset and released with an entry address | the second core |
| R3 | How coherence scales beyond two to four cores | keep snooping for now, record the limit | more than four cores |
| R4 | The bus protocol itself (Q64) | AXI as the transport, Q64 as a mapping on top | DMA devices; the FPGA |
| R5 | The device register layout and DMA descriptors | uniform layout with an ID register and a descriptor ring | every DMA device |
| R6 | DMA addressing and protection (an I/O translation unit) | none for now; devices address all of physical memory | untrusted devices; virtualization |
| R7 | Errors raised by devices and the bus | bus-controller error registers and the machine-check path already in the ISA | DMA devices |
| R8 | Virtualization | out of scope for System v1; fix five constraints now | running one system inside another |

---

## R1. The interrupt controller and routing interrupts to cores

**The need.** With one core, the processor's priority level (Q4) is the whole story: a device asserts a level, the core takes it or not. With several cores, someone must decide *which core* takes each interrupt, and a device must be able to interrupt a core that is not core 0. A device shared by two cores (an Ethernet controller with several queues) wants its interrupts spread. That is the job of an **interrupt controller**: a piece of hardware between the devices and the cores.

**The explanation.** Two styles. In a **wired** style each device has a line; the controller ranks the lines and delivers the chosen one to a core. In a **message-signalled** style (MSI) the device does an ordinary memory write to a special address and the write *is* the interrupt, so no wires are needed and each queue can have its own target.

**Current state.** Not defined. The bus document says only that an inter-processor interrupt path "a memory-mapped per-core register is sufficient and needs no APIC-like complexity", and lists "the interrupt controller, the vectors, the per-core registers" as open. In System v1 the timer (level 6, vector 32) and console (level 4) interrupt the single core directly.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **A small controller: wired lines with a priority, a per-core enable and threshold register, plus message-signalled interrupts as a write to a per-core address** | enough for several cores and many devices; keeps the 8-level priority; modern devices can use messages | a design to write; a register block to specify and drive |
| 2 | **Wired lines only, all delivered to core 0 unless a per-line target register says otherwise** | the simplest routing | no per-queue interrupts for fast devices; wires scale badly |
| 3 | **Message-signalled interrupts only** (no wires) | simplest scalable model; fits the memory-mapped device idea | every device must be able to issue a write; legacy wired devices need an adapter |
| 4 | **A full distributor and per-core interface in the style of ARM's GIC** | the most complete, with virtualization support | a large block; a lot of driver code |
| 5 | **No controller: devices interrupt core 0, which forwards to others by inter-processor interrupt** | nothing to design | core 0 is a bottleneck; every interrupt on another core costs two |

**What current systems do.** x86 moved from the 8259 pair to the APIC: one local APIC per core plus I/O APICs, and MSI/MSI-X for most modern devices; ARM uses the GIC (a distributor, a redistributor or CPU interface per core, and an ITS for messages); RISC-V uses the PLIC (wired, a priority threshold per core) with the newer APLIC and IMSIC for messages; PowerPC uses OpenPIC, XICS and XIVE. Linux has an interrupt-controller framework; FreeBSD, NetBSD and OpenBSD each have one, and OpenBSD drives the APIC on amd64 and the GIC on arm64 (checked: OpenBSD `amd64/apic.c`, `arm64/dev/agintc.c`; riscv64 `plic.c`, `aplic.c`, `imsic.c`; powerpc64 `xics.c`, `xive.c`; FreeBSD `gic_v3.c`, `plic.c`, `local_apic.c`; NetBSD `cortex/gicv3.c`; Linux `powerpc/sysdev/mpic.c`).

**What Unix on the PDP-11 and the VAX-11 did.** PDP-11: no controller; a device raises one of four bus-request lines (BR4 to BR7) and supplies its own vector; the processor arbitrates by priority. VAX: 32 priority levels, interrupts through the System Control Block (a table of vectors), and on a multiprocessor an interrupt went to one chosen processor; VMS supported multiprocessing, while Berkeley Unix on a VAX multiprocessor was rare (from memory, not confirmed in the sources read). *Trade-off:* the PDP-11 scheme needs no controller and cannot route to several processors. *Comparison:* option 1 keeps the PDP-11 priority model and adds the routing it lacked.

**Recommendation.** Option 1, with the message-signalled path first. It keeps `SPL` working and the BSD locking model intact (Q4), and it avoids a wire per device. Cost to build: a register block in the virt machine, a QEMU model, a kernel driver. **If nothing is done:** option 5 by default, which is fine for two cores and poor beyond.


**Revised for your principles.** Under your gates priority I now prefer the smaller design: wired interrupt lines delivered to core 0, with a per-line target register that can send a line to another core (option 2), and message-signalled interrupts added later if a fast multi-queue device needs them. It keeps the 8-level priority, needs the least logic, and adds no new failure cases. My earlier pick (option 1) is a superset and can follow.
---

## R2. Inter-processor interrupts and starting the other cores

**The need.** Cores must signal each other (to flush a TLB the hardware does not broadcast, to run a function on another core, to reschedule) and the machine must be able to start the cores that are not core 0 after reset.

**The explanation.** The **boot protocol** answers: at reset, which core runs, what do the others do, and how are they released? An **inter-processor interrupt** (IPI) is an interrupt one core raises for another.

**Current state.** The bus document names a memory-mapped per-core register as sufficient and a "boot protocol for releasing secondary cores from reset" as open. `SEV` and `WFE` (event signalling) exist in the ISA; `TLBI` broadcasts.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Per-core doorbell registers in the interrupt controller; secondary cores held in reset and released by writing an entry address** | simple, explicit; matches the bus document | a register block; the entry-address convention to write |
| 2 | **The IPI is a message-signalled interrupt to the target core's address** (x86 APIC style) | no extra mechanism if R1 chose messages | one more use of R1; the boot start still needs a rule |
| 3 | **A software-interrupt bit per core in a system register** (RISC-V's machine software interrupt) | an instruction (`mtsr`) raises it | a new system register and a routing rule |
| 4 | **Cores start parked in `WFE` waiting on a mailbox in memory** (the ARM "spin table" style); `SEV` wakes them | no hardware release logic | busy memory polling at boot; trust in the mailbox |
| 5 | **Start cores by a firmware call** (needs P7, option 2) | one interface | needs firmware, which P7 recommends against |

**What current systems do.** x86 starts application processors with the INIT and startup IPIs through the APIC; ARM uses PSCI (a firmware call) or a spin table; RISC-V uses the SBI hart-state calls; Linux and the BSDs have an application-processor startup path and per-architecture IPI code (checked, practice: Linux `x86/kernel/smpboot.c` sends INIT and `APIC_DM_STARTUP`, `arm64/kernel/smp_spin_table.c` and `psci.c`, `riscv/include/asm/sbi.h` `SBI_EXT_HSM_HART_START`).

**What Unix on the PDP-11 and the VAX-11 did.** PDP-11: multiprocessor models (such as the 11/74) were exceptional, and Unix on them was a research port. VAX: the 11/782 attached processor and later multiprocessors (8300, 8800) started secondary processors from the console and signalled with software interrupts at a priority level; VMS used them, 4BSD barely (from memory, not confirmed in the sources read). *Trade-off:* those designs relied on the console processor and an elaborate firmware. *Comparison:* option 1 has no firmware and no console processor, at the price of a documented register convention.

**Recommendation.** Option 1, with `SEV`/`WFE` used for waiting (so P1, the `WFE` rule, matters here). Cost to build: a doorbell register block, a reset-release register, QEMU support for a second core, tests. **If nothing is done:** a single core only.

---

## R3. How coherence scales beyond two to four cores

**The need.** Each core has a cache; when one writes, the others' copies must not go stale. The ISA already chose snooping for two to four cores. The question is what happens at eight or sixty-four.

**The explanation.** In **snooping** every cache watches a shared bus, simple but limited by the bus. In a **directory** scheme a table records who holds each line, so messages go only where needed; it scales but is complex. The decision interacts with sequential consistency (Q5) and atomics (P11).

**Current state.** Snooping MSI, two to four cores (ISA section 17.3); nothing beyond.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Snooping MSI, two to four cores; say plainly that more needs a new protocol (current)** | simple; fits the FPGA | a ceiling |
| 2 | **Snooping MESI or MOESI** (an exclusive or owned state) | fewer bus transactions | more states to verify |
| 3 | **Directory-based coherence** | scales to many cores | a directory and a protocol; a large design |
| 4 | **No hardware coherence between clusters; explicit cache operations** | cheap to scale | software burden (P6); against the model of Q5 |
| 5 | **One shared cache and no private caches** | trivially coherent | slow; defeats the purpose |

**What current systems do.** x86 uses MESIF or MOESI snooping within a die and directories or snoop filters across sockets; ARM's coherent interconnects (ACE, CHI) are directory or snoop-filter based; RISC-V cores use TileLink or CHI (all from memory, not confirmed in the sources read).

**What Unix on the PDP-11 and the VAX-11 did.** Both predated multi-level coherent caches for most models; VAX multiprocessors shared memory over the SBI, with cache coherence in the memory system and interlocked instructions for locks. *Comparison:* the pdp64's plan is the small-snooping case; it says nothing wrong about larger systems because it makes no claim.

**Recommendation.** Option 1, and record the ceiling so nobody assumes more. Cost to build: a paragraph. **If nothing is done:** same.

---

## R4. The bus protocol itself (Q64)

**The need.** The bus connects cores, memory and devices. `Q64` is the name given in the ISA, "defined in 11/64 revision 5", but that revision is not among the documents, so its transactions (widths, bursts, arbitration, timing) are not written anywhere. Something has to be the real protocol.

**The explanation.** An FPGA implementation talks AXI, the standard on-chip bus of Xilinx and other tools; a bridge from Q64 to AXI is estimated at 600 lookup tables (an estimate, not measured). Rather than keep two protocols, one could make AXI the architecture's transport and treat Q64 as the name of the programming model on top of it.

**Current state.** Q64 is named, its lineage is the Unibus and Q-bus (including the locked read-modify-write pair `DATIP`/`DATO`), but undefined; P11 asks about the atomics.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Write Q64 from the lineage as a real protocol and bridge to AXI** | heritage; full control | a new protocol to specify, verify and keep in step with AXI |
| 2 | **AXI (with AXI-Lite for registers) as the transport; Q64 names the model on top (ordering, memory types, hand-off)** | the FPGA tools work directly; exclusive access gives the monitor of P11 | the lock model of the Unibus is not native |
| 3 | **TileLink** (RISC-V ecosystem) | clean coherence support | a smaller tool ecosystem |
| 4 | **Wishbone** (open hardware cores) | simple, many open cores | no coherence; limited bursts |
| 5 | **A packet fabric in the style of PCI Express for all peripherals** | scalable, discoverable | heavy for small devices |

**What current systems do.** ARM systems use AMBA (AXI, ACE, CHI); x86 uses internal fabrics plus PCI Express for peripherals; RISC-V uses TileLink or AXI; FPGA SoCs use AXI throughout (all from memory, not confirmed in the sources read).

**What Unix on the PDP-11 and the VAX-11 did.** PDP-11: the Unibus, an asynchronous master-slave bus with transactions `DATI`, `DATO`, `DATIP` (read, pause for a write), `DATOB` (byte); the Q-bus multiplexed addresses and data. VAX: the SBI (synchronous), then the BI and XMI. *Trade-off:* each machine generation introduced a bus; software hid them behind drivers. *Comparison:* option 2 follows what the whole industry did, taking an external standard, and the drivers see the model, not the bus.

**Recommendation.** Option 2, because the FPGA plan is already on AXI and it makes P11's monitor the natural choice. This changes the stated heritage a little (Q64 becomes a mapping, not a bus). Cost to build: the bus document rewritten around the mapping. **If nothing is done:** Q64 stays undefined and the bridge is designed ad hoc.

---

## R5. The device register layout and DMA descriptors

**The need.** Q10 chose eight registers plus DMA but never wrote the layout. Without it no driver can be written, and the QEMU devices (timer and console aside) have nothing to follow.

**The explanation.** A **descriptor** is a small record in memory telling a device where a buffer is and how big it is; a **chain** or **ring** of them lets a device run several transfers on its own. A **doorbell** is a register write that tells the device new descriptors are ready. The layout fixes what each of the eight registers means, the descriptor's fields, and how a device reports completion.

**Current state.** Open: the order of the eight registers, whether Ethernet, USB and disk share one layout, the descriptor format (the accelerator's `lb_desc` chain is the only example), the doorbell and interrupt convention (bus document section 9).

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **One uniform layout: an ID/version register, control, status, descriptor-ring base, size, head, tail and doorbell; devices differ in the descriptor payload** | one driver skeleton for all; self-identifying | the shared shape must fit USB, Ethernet and disk |
| 2 | **Virtio-mmio compatibility** | existing drivers; standard for virtual machines | more registers than eight; its queue format to implement |
| 3 | **Bespoke per device** (the Unibus way) | each device is exactly right | no shared driver code |
| 4 | **PCI-style enumeration with configuration space** | discoverable; the industry standard | heavy for a small design |
| 5 | **A device tree or table from the boot loader describes each device** | flexible | the layout of the registers is still needed |

**What current systems do.** PC systems enumerate PCI Express devices through configuration space and base-address registers; embedded ARM and RISC-V use a device tree for addresses and interrupts; virtual machines use virtio (mmio or PCI); Linux and the BSDs access registers through a bus-space abstraction (all from memory, not confirmed in the sources read).

**What Unix on the PDP-11 and the VAX-11 did.** Unibus devices sat at fixed addresses with a control and status register and a few data registers (a disk controller about eight); the vector was set by switches; Unix's `config` and the kernel's `probe` routines found devices by touching their addresses. The VAX Unibus adapter added map registers for DMA. *Trade-off:* simple but each device bespoke. *Comparison:* option 1 is the PDP-11 shape made uniform; option 2 trades the shape for existing driver code.

**Recommendation.** Option 1 with an ID/version register first (so a driver and the QEMU model can check what they found) and a boot-loader table for addresses. Consider option 2 for the virt machine only, as a way to reuse existing drivers during the OpenBSD bring-up. Cost to build: a grammar for the layout (the bus document already says it should be generated), headers, QEMU models. **If nothing is done:** each device invents its own.

---

## R6. DMA addressing and protection (an I/O translation unit)

**The need.** A device that does DMA reads and writes physical memory on its own. Two problems follow: a device that cannot address all of memory (an older device with 32 address bits on a machine with 40-bit physical addresses), and a faulty or malicious device that overwrites anything.

**The explanation.** An **I/O memory-management unit** (IOMMU) translates and checks a device's addresses the way the processor's MMU does for programs. Without one, the kernel must copy through low memory for limited devices (a **bounce buffer**) and must trust every device.

**Current state.** Not discussed in the documents. DMA buffers are mapped uncached (P6, bus section 6); devices use physical addresses.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **No IOMMU; the rule that every device can address all 40 bits of physical memory** | nothing to build; simple | no protection from bad devices; no help for a restricted device |
| 2 | **A base-and-limit window register per device** | cheap protection and relocation | coarse; one region per device |
| 3 | **A full IOMMU with its own page tables** (x86 VT-d, ARM SMMU, RISC-V IOMMU) | real protection; virtualization of devices | a large block; driver and kernel work |
| 4 | **Devices share the processor's page tables** (shared virtual memory) | zero-copy with user buffers | page-fault handling for devices; complex |
| 5 | **Bounce buffers in a reserved low region, kernel copies** | no hardware | copy cost; only for limited devices |

**What current systems do.** x86 servers have VT-d, ARM systems an SMMU, RISC-V an IOMMU specification; Linux has the swiotlb bounce-buffer layer for devices with limited addressing, and the BSDs have `bus_dma` with bounce support (checked: kernel.org swiotlb document; FreeBSD `x86/x86/busdma_bounce.c`; NetBSD `x86/bus_dma.c` and OpenBSD `amd64/bus_dma.c` mention bounce buffers; swiotlb was created for devices limited to 32-bit DMA addresses).

**What Unix on the PDP-11 and the VAX-11 did.** The Unibus carries only 18 address bits, so on machines with more memory the Unibus map translated device addresses to memory (the Unibus map on the larger PDP-11s, and the VAX Unibus adapter's map registers with `uballoc` in 4BSD). *Trade-off:* a translation unit served both limited addressing and relocation. *Comparison:* the older machines had a simple IOMMU out of necessity; option 1 ignores the need because the devices are defined to address everything.

**Recommendation.** Option 1 now, with the rule written down; revisit with option 3 when virtualization (R8) or untrusted devices matter. Cost to build: a sentence in the bus document. **If nothing is done:** option 1 by default, unwritten.

---

## R7. Errors raised by devices and the bus

**The need.** A device can fail mid-transfer, an access to nothing can time out, memory can have an uncorrectable error. The kernel needs to learn of it and to know whether it can continue.

**The explanation.** The ISA already says a read that times out is a precise fault, a posted write that times out or an uncorrectable error is an imprecise **machine check**. What is missing is how a device or the bus controller *tells* the processor, and what registers record the cause.

**Current state.** Bus document section 7: the error-reporting registers of the bus controller, and what a device may raise itself, are open.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **A bus-controller error register block (cause, address) plus a machine-check interrupt** | one place to look; fits the ISA | a register block to define |
| 2 | **Bus error responses only (the AXI error code) becoming the precise bus fault for reads and a machine check for posted writes** | no new registers | no cause detail beyond the response |
| 3 | **Each device reports through its own status register only** | local, simple | nothing reports bus-level faults |
| 4 | **A PCI Express style advanced error reporting structure** | rich, standard | heavy |
| 5 | **Treat every error as fatal** | nothing to build | no recovery |

**What current systems do.** x86 has the machine-check architecture (banks of error registers) and PCI Express error reporting; ARM has the RAS extension and the SError interrupt; Linux has EDAC (checked: kernel.org EDAC document) and machine-check handling (`x86/kernel/cpu/mce`).

**What Unix on the PDP-11 and the VAX-11 did.** PDP-11: a bus timeout traps to vector 4 and a parity error to another vector, usually ending in a panic in Unix. VAX: a machine-check exception through the System Control Block with a machine-check frame of processor state, plus memory-error interrupts and fault registers on the bus; 4BSD logged and mostly panicked. *Comparison:* the pdp64's precise read fault is better than the PDP-11's unrestartable bus error; options 1 and 2 together give the VAX's frame without the VAX's size.

**Recommendation.** Options 2 and 1 together: the precise and imprecise paths the ISA already defines, plus a small register block for the cause. Cost to build: the register block and tests. **If nothing is done:** option 2 alone.

---

## R8. Virtualization

**The need.** Virtualization runs one operating system (a **guest**) inside another system (the **host** or **hypervisor**) as if it had a machine of its own. It matters for cloud use, for testing kernels and for isolation. If the architecture ignores it now, later additions can force changes to instructions the guest already depends on.

**The explanation.** The classic method is **trap and emulate**: the guest runs in user mode, and every privileged instruction traps into the hypervisor, which emulates it. It works only if every instruction that reveals or changes the machine's state is privileged (a machine failing that test is not cleanly virtualizable). Modern processors add a **hypervisor mode** and **nested translation** (the guest's page tables are themselves translated by the host's) so the guest can run in kernel mode at full speed.

**Current state.** Not addressed. System v1 has two modes (supervisor mode is defined in the `PSW` and banked registers but unused).

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Out of scope for System v1; fix five constraints now** (see below) so it can be added later | no work now; nothing painted into a corner | the work still comes later |
| 2 | **Classic trap and emulate, as the first form** (guest in user mode, all privileged instructions trap) | no new hardware; the privileged/unprivileged split exists | slow for page-table and interrupt traffic; the guest kernel's own user mode needs a second level |
| 3 | **A hypervisor mode plus nested translation** (x86 VT-x with EPT, ARM EL2 with stage-2, RISC-V H extension) | near-native speed | a large addition: a mode, a second walker, virtual interrupts |
| 4 | **Paravirtualization**: a guest modified to call the host (hypercalls) instead of using privileged instructions (Xen PV) | no hardware, good speed | the guest must be ported; the hypercall interface must be defined |
| 5 | **Software emulation only** (the pdp64 as a guest in QEMU on other hosts, as today) | already works | no pdp64 hosts; no isolation on the pdp64 |

**The five constraints** for option 1, so a later hypervisor needs no change to the guest-visible architecture: (a) every instruction that reveals or changes machine state stays privileged or is controllable (the time counter of P3 and the identification registers of P4 get an enable bit or trap, not an unconditional user read); (b) the page-table walker is specified so that a second level could wrap it; (c) interrupts are injectable (a pending virtual interrupt can be presented as a real one); (d) the system-register model (Q12) allows a trap on access; (e) the `MMUCTL` mode bit (P10) and the software accessed and dirty bits (Q2) are reviewed for what a hypervisor would need.

**What current systems do.** x86 has VMX and SVM with nested paging (EPT, NPT); ARM has exception level 2 and stage-2 translation; RISC-V has the H extension; PowerPC has hypervisor mode and logical partitions; IBM mainframes have had virtual machines since VM/370, by trap and emulate. Linux has KVM, FreeBSD bhyve, NetBSD NVMM, OpenBSD `vmm` (checked: working code in `amd64` only; the arm64 tree has a stub `vmmvar.h`; FreeBSD bhyve also has arm64 and riscv trees, so "x86 only" is not true of bhyve), Windows Hyper-V; Xen offers paravirtualization (checked: Linux KVM trees exist for x86 `vmx`/`svm`, arm64 `kvm/mmu.c` stage 2, riscv, powerpc `book3s_hv`, s390 `sie64a`, mips and loongarch; FreeBSD `sys/amd64/vmm`, `sys/arm64/vmm`, `sys/riscv/vmm`; NetBSD nvmm(4) lists amd64/x86 only; Hyper-V and Xen not read).

**What Unix on the PDP-11 and the VAX-11 did.** The PDP-11 was not designed for virtualization and, as I recall (not confirmed), has sensitive instructions that do not trap in user mode. The VAX was not cleanly virtualizable either; DEC's research on a VAX security kernel led to a published paper on "virtualizing the VAX architecture" that added a virtual-machine bit and changed some instructions (Judith S. Hall and Paul T. Robinson, ISCA 1991, checked: Crossref). *Trade-off:* adding virtualization late cost the VAX instruction changes. *Comparison:* option 1 is the lesson of the VAX: settle the constraints early even if the feature comes late.

**Recommendation.** Option 1: say it is out of scope for System v1 and record the five constraints. Cost to build: a short section. **If nothing is done:** the constraints are broken by accident, one at a time, as P3 and P4 are decided.

---

## Part D. Vector and SIMD math

(I read "avax" as AVX. If you meant something else, tell me.) **SIMD** means single instruction, multiple data: one instruction operating on several values packed side by side. This is a real gap: the ISA has considered and rejected separate vector register files (ISA section 15.2, "Separate vector register files (LSX, LASX)"), and put wide data-parallel work in a bus-attached coprocessor instead (the LB64 accelerator is the worked case), but no decision record exists and nothing weighs the alternatives. Facts about other systems are from my memory and **not confirmed in the sources read**; the [kernel survey](kernel-asm-survey.md) says only that avoiding floating-point state avoids about 180 x86 instructions that save it. The compiler corpus was built at `-Os`, where gcc and clang vectorize little, so **there is no measurement of how much vector code a pdp64 would run**; the first thing to do before choosing is collect that evidence (list at the end of this part).

| # | Decision | My recommendation | Depends on |
|---|---|---|---|
| S1 | Where data-parallel work lives | keep the coprocessor model; measure first; reserve a small packed-lane set in the integer registers | the evidence below |
| S2 | If vectors are in the ISA: which registers | none yet; if built, a separate file | S1 |
| S3 | Vector length: fixed width or scalable | if built, scalable | S1, S2 |
| S4 | Machine state: context switch and kernel use | decide before any vector state exists | S2, P4, Q1 |
| S5 | Number formats and matrix operations | scalar half precision stays; extend only through the coprocessor | S1, the LB64 workload |
| S6 | ABI, compiler and library support | write the rule now: no vectors in the ABI until S1 changes | S1 |

**Already in the ISA and related to this part:**

| What | Where | Note |
|---|---|---|
| Floating point in the general registers (no separate FP register file) | ISA section 2.3 | the reason a separate vector file was rejected |
| Half precision (`binary16`): 17 scalar words | errata 27, ISA section 9 | scalar only |
| `XNORPOP` (popcount of the XNOR) | ISA section 4.6.2 | for the binary-weight workload |
| `UTF8ENC`/`UTF8DEC` and the string and block instructions (`mscn`, `mcpy`, `mmov`, `mset`) | ISA sections 4.6 and 11 | the string work that SIMD does on other machines |
| `abs`, `min`, `max` and `set cc` | errata 23, 25 | scalar |
| CRC instructions | errata 20 | considered, added, withdrawn |
| The LB64 accelerator and the `BLT64` blitter | LB64 document, FPGA plan section 12 | the coprocessor model in practice |
| SWAR (using a wide scalar register as several lanes) | ISA glossary | how packed work is done today |

---

## S1. Where data-parallel work lives

**The need.** Image and signal processing, graphics, compression, cryptography, neural-network inference and scientific loops all do the same operation on arrays. Doing it one element at a time costs several times what dedicated hardware costs. Every modern processor has an answer. The pdp64's answer is, so far, "not in the processor", and that was a choice made once and never put to the author as a decision with alternatives.

**The explanation.** There are four places such work can go: **nowhere** (scalar code, perhaps unrolled); **inside the integer registers** (several small values packed into one 64-bit register, with instructions that add or compare each lane separately, called **packed SIMD in general registers**; with plain integer instructions and masks it is called **SWAR**); a **separate vector register file** with its own instructions; or **outside the processor**, in a device on the bus that the processor sets up and that does the loop on its own (the ISA's current choice). Each costs differently: in opcodes, in state the kernel must save, in area on an FPGA (whose block RAM is limited; the FPGA plan warns of exhaustion), and in how much software must change to use it.

**Current state.** Separate vector register files rejected (ISA section 15.2) because "a second wide register file is the thing section 2.3 specifically avoided", it entangles wide loads with the alignment rules, and the opcode map is nearly full. Wide work goes to a coprocessor on the Q64 bus, which "needs no opcodes at all". The LB64 document specifies one such device for one workload (LittleBit inference).

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Coprocessor only (current)** | no opcodes, no new processor state, no kernel save; scales with the device; matches the DMA hand-off model | every use needs a device and a driver; small jobs pay the setup cost; compilers cannot vectorize into it; nothing for the many loops too small to offload |
| 2 | **Packed lanes in the integer registers** (a handful of instructions on 8, 16 and 32-bit lanes: add, subtract, saturating add, compare, min, max, average, sum of absolute differences, shuffle) | no new state; works with today's registers and calling convention; small hardware cost; helps string, image and codec inner loops | 64-bit width only, so a modest gain per instruction; uses opcode space on page 2 (21 slots reserved; corrected after checking ISA 4.18, which said 19 here); compiler support is poor for it |
| 3 | **A separate fixed-width vector register file** (128, 256 or 512 bits, as SSE, AVX or NEON) | what compilers vectorize for best; large gains on regular loops | a second register file and its state; wide loads and alignment rules; opcode demand; new widths later force new instructions (the x86 history); FPGA block RAM cost |
| 4 | **A scalable vector extension** (the register width is implementation-defined and software asks for it; ARM SVE, RISC-V V) | one program runs on a small and a large implementation; no new instructions per width | the most complex to specify and to implement; the compiler and the ABI need the model; vector-length-dependent state |
| 5 | **A matrix or tile unit** (x86 AMX, ARM SME) | the largest gain for neural-network and linear-algebra work | big state; narrow use; usually layered on one of 3 or 4 |

**What current systems do.** x86: MMX, SSE, AVX, AVX2, AVX-512, and AMX, a sequence of fixed widths, each needing new instructions and new state; Intel removed AVX-512 from some client chips and proposed AVX10 to unify them. ARM: NEON (128-bit fixed) and SVE/SVE2 (scalable, 128 to 2048 bits), with SME for matrices. RISC-V: the V extension (scalable) and a packed-SIMD extension "P" for general registers still in development. PowerPC: AltiVec/VMX, VSX and the MMA matrix instructions. MIPS: MDMX and MSA. Alpha: MVI (packed operations on the integer registers). SPARC: VIS (packed operations on the FP registers). PA-RISC: MAX (packed operations on the integer registers). s390: a 128-bit vector facility. LoongArch: LSX and LASX (128 and 256 bits). Linux, FreeBSD, NetBSD and OpenBSD ship hand-tuned vector routines for the C library and cryptography, chosen at run time (the survey counted `ifunc`/alternatives uses), and Apple reaches its matrix coprocessor only through a library (checked in part: Linux has `ifunc`/alternatives and `prefetch`; Intel dropped AVX-512 from client chips (Alder Lake fused off) and announced AVX10 in 2023, Wikipedia AVX-512; SVE widths 128 to 2048 bits, Wikipedia AArch64; RISC-V P is a proposal in the ISA manual and an experimental `FeatureStdExtP` in LLVM; Alpha MVI and PA-RISC MAX work on the integer registers and SPARC VIS on the floating-point registers, per Wikipedia; Linux has `msa.h` for MIPS, `fpu.c` for s390 vectors, `visasm.h` for SPARC, and LoongArch LSX hwcaps; Apple not read).

**What Unix on the PDP-11 and the VAX-11 did.** PDP-11: none; the floating-point unit was scalar; heavy numerical work used an **attached array processor** (for example the Floating Point Systems AP-120B; the 1976 brochure lists PDP-11 hosts, a VAX host was not confirmed in the sources read), driven by library calls. VAX: a **vector extension** on the 6000 series (16 vector registers of 64 elements, checked: VAX 6000 Vector Processor Programmer's Guide) supported by VMS with context switching of vector state; Unix support was limited (the VMS part and Unix support not confirmed in the sources read). *Trade-off:* the attached processor needed no change to the architecture and no kernel support but had a high setup cost; the VAX vector unit gave compiler-visible speed and cost state, opcode space and a vector-aware scheduler. *Comparison:* the pdp64's current choice is the PDP-11's, which is also the choice that kept the instruction set unchanged for decades.

**Recommendation.** Keep option 1 for the large jobs and add a measured version of option 2: collect the evidence first (list below), and if string, codec and image loops dominate, add a small packed-lane set on page 2. Do **not** add a fixed-width vector file (option 3) in this round: it is the choice with the longest tail of regret, and if vectors come, they should come as option 4. Cost to build now: the measurement, then perhaps ten page-2 instructions. **If nothing is done:** option 1 by default.

---

## S2. If vectors are in the ISA: which registers

**The need.** If S1 chooses option 3, 4 or 5, the vector data lives somewhere, and where decides the instruction encoding, the calling convention and the cost of a context switch.

**The explanation.** The pdp64 keeps floating point in the same 16 registers as integers, which keeps the register file and the state small (ISA section 2.3). A vector extension can extend that (use several adjacent registers as one wide value), add a **separate file**, or work **memory to memory** with no vector registers at all.

**Current state.** No vector registers; sixteen 64-bit general registers carry integers and floating point.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **No vector registers (current)** | the register file stays small and uniform | no vector instructions in the ISA |
| 2 | **Vectors in groups of general registers** (pairs or quads as 128 or 256 bits) | no new state; the ABI and kernel are unchanged | only 16 registers, so a few live vectors starve the scalar code; spills |
| 3 | **A separate vector file** (16 or 32 registers) | independent of scalar pressure; the standard shape | the largest state; a second ABI class; FPGA block RAM; opcodes |
| 4 | **A separate file that overlaps floating point** (x86 XMM over the x87-then-SSE history) | one file for scalar floating point and vector | couples two things that scale differently |
| 5 | **Memory-to-memory vector instructions** (no vector registers; the vector lives in memory) | no new register state | memory traffic; the design of the 1970s supercomputers; poor fit for caches |

**What current systems do.** x86 has 16 or 32 vector registers of 128 to 512 bits (and mask registers in AVX-512); ARM has 32 vector registers aliasing the floating-point file; RISC-V V has 32 vector registers plus configuration registers; PowerPC VSX shares 64 registers between floating point and vectors; the older Cray machines had vector registers, and the CDC STAR-100 and TI ASC operated memory to memory (not confirmed in the sources read).

**What Unix on the PDP-11 and the VAX-11 did.** PDP-11: no vector registers. VAX: a separate vector register file with a vector control and mask register. *Comparison:* option 2 is the only choice that adds no state for the kernel.

**Recommendation.** Option 1 now (no registers). If S1 ever changes, take option 3 unless the register-pressure measurement favours option 2. Cost to build: none now. **If nothing is done:** option 1.

---

## S3. Vector length: fixed width or scalable

**The need.** If there is a vector unit, how wide it is decides what happens across implementations over decades. The pdp64 plans a small in-order FPGA core and a possible large out-of-order core.

**The explanation.** A **fixed-width** design (128-bit NEON, 256-bit AVX) bakes the width into every instruction; a wider future implementation needs new instructions and old binaries cannot use the extra width. A **scalable** design lets software say "process as many elements as the hardware handles this step" so the same binary runs on a narrow and a wide implementation.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **None (current)** | nothing to specify | no vectors |
| 2 | **Fixed 128 bits** (NEON, SSE) | simplest; fits a small FPGA | a future wider unit needs a new extension |
| 3 | **Fixed 256 or 512 bits** (AVX, AVX-512) | more per instruction | area; power; the x86 lesson that widths multiply the instruction set |
| 4 | **Scalable, set by the implementation** (SVE, RISC-V V) | one binary across implementations; the long-lived choice | the most complex architecture; compilers and software must be written for it |
| 5 | **Scalable but with a minimum width and a software-chosen length register** (RVV 1.0 shape) | simpler than full SVE | still a new programming model |

**What current systems do.** Fixed widths dominate x86 and older ARM; scalable ones (SVE, RISC-V V) are the recent designs; Linux, FreeBSD and other kernels carry per-width code paths for x86 and are adding vector-length handling for ARM and RISC-V (checked: Linux `riscv/include/asm/vector.h` and the kernel.org RISC-V vector document, `arm64/kernel/fpsimd.c`).

**What Unix on the PDP-11 and the VAX-11 did.** The VAX vector architecture had a fixed vector length of 64 elements, with a vector-length register for partial vectors, (checked: VAX 6000 Vector Processor Programmer's Guide: 64 elements maximum, vector length register). *Comparison:* the pdp64's span, from a small FPGA to a possible large core, is the case scalable designs exist for.

**Recommendation.** If vectors are built, option 4 or 5, never a fixed width, because the project already plans two very different implementations. Cost to build: a large specification, only if S1 asks for it. **If nothing is done:** option 1.

---

## S4. Machine state: context switch and use in the kernel

**The need.** Every register the processor adds must be saved when one program is switched for another, and restored. Large vector state makes every switch cost thousands of bytes and makes system calls and interrupts expensive if they use it. The decision should be made before any vector state exists, because a decision made after software depends on the state is much harder.

**The explanation.** There are three tactics: **eager save** (always save and restore), **lazy save** (leave the previous program's vector state in place and trap on first use by the next program, then switch), and **dirty tracking** (a flag the hardware sets when the state was touched, so unused state is not saved). The kernel itself usually refuses to use vector registers, because doing so would force a save at every entry.

**Current state.** No vector state. The survey notes that having no floating-point and vector state to save avoids about 180 occurrences of x86 state-saving instructions in the kernels; the pdp64's floating point is in the general registers, so the existing save covers it.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **No vector state (current)** | the switch cost does not grow | no vectors |
| 2 | **Eager save and restore** | simple and predictable | costs every switch even for programs that never use vectors |
| 3 | **Lazy save with a trap on first use** | cheap for programs that never use vectors | a trap on first use; **x86's lazy floating-point switching was a security hole, and Linux went back to eager** (checked: Wikipedia "Lazy FP state restore" describes CVE-2018-3665 and eager restore as the mitigation, with Linux able to force it since 3.7; the current Linux x86 FPU code has no lazy path, `TIF_NEED_FPU_LOAD` loads on return to user space) |
| 4 | **Dirty-state bits in the status word** (RISC-V's `FS`/`VS`, ARM SVE state) | saves only what was used; no trap | a field in the `PSW`; the OS must read it on every switch |
| 5 | **Vector state lives in the coprocessor and is never saved by the kernel** (the LB64 model) | no processor state at all | the device is owned by one process at a time, or has its own contexts |

**What current systems do.** Linux saves with an extended save area (`xsave`) and tracks which parts are in use, and the kernel avoids vector registers except in marked regions (`kernel_fpu_begin`); FreeBSD and NetBSD have similar kernel-FPU APIs; Windows saves the extended state; ARM Linux handles SVE with a per-thread vector-length setting (checked, practice: `arm64/kernel/fpsimd.c`); `kernel_fpu_begin` exists (`x86/kernel/fpu/core.c`), FreeBSD `fpu_kern_enter` and OpenBSD `fpu_kernel_enter` exist.

**What Unix on the PDP-11 and the VAX-11 did.** PDP-11: the floating-point registers were saved per process, and Unix saved them only for processes that used floating point (a flag set on first use); the kernel did not use floating point. VAX: VMS saved vector state lazily with a "vector consumer" flag set on first use (not found in the VAX 6000 Vector Processor Programmer's Guide; the guide does describe a vector-processor-disabled fault and the VMAC register for context switching). *Comparison:* both older machines used a first-use flag; the lesson from x86 is that lazy trapping on the privileged side leaks, so a dirty bit (option 4) is the modern form.

**Recommendation.** Decide now that any future vector state is covered by option 4 plus the rule that the kernel does not use it outside marked regions; that costs nothing today. Cost to build: a paragraph. **If nothing is done:** option 1.

---

## S5. Number formats and matrix operations

**The need.** Neural-network inference and training use formats and operations that scalar double precision does not serve well: half precision, bfloat16 (a 16-bit format with the range of single precision), 8-bit floating point, 8-bit integers with 32-bit accumulation, and matrix multiply-accumulate. The LB64 accelerator exists for one such workload.

**The explanation.** The ISA already has scalar `binary16` (17 words) and the `XNORPOP` instruction. The question is whether anything else belongs in the processor or all of it belongs in the coprocessor (S1, option 1).

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Scalar half precision only, everything else in the coprocessor (current)** | no new formats in the core | each new format means a new device or a firmware update to it |
| 2 | **Add scalar bfloat16** (conversions and multiply-accumulate) | the format used by most training | about 6 words on the floating-point page; little use without vectors |
| 3 | **Add integer dot-product instructions** (8-bit values multiplied and summed into 32 bits: x86 VNNI, ARM `SDOT`) | big gain for quantized inference | works best with vectors; as scalar on a 64-bit register it handles eight values |
| 4 | **Add 8-bit floating point (FP8) conversions** | the newest inference formats | formats are still changing |
| 5 | **A matrix tile unit** | the largest gain | big state; effectively S1 option 5 |

**What current systems do.** x86 has half precision, bfloat16 (on newer parts), VNNI and AMX; ARM has bfloat16, `SDOT`, `I8MM` and SME; RISC-V has vector extensions with these types; GPUs and tensor accelerators handle the rest (checked, practice: Linux hwcaps for arm64 `BF16`, `ASIMDDP` (SDOT), `I8MM`, x86 `AVX_VNNI`/`AVX512_VNNI`, AMX per Wikipedia; RISC-V vector types not read). Operating systems expose none of it directly; it is in libraries.

**What Unix on the PDP-11 and the VAX-11 did.** Nothing comparable existed; array processors handled such work. *Comparison:* the pdp64's coprocessor model is the same one used then.

**Recommendation.** Option 1; revisit option 2 and option 3 only if a measured workload runs on the core. Cost to build: none. **If nothing is done:** option 1.

---

## S6. ABI, compiler and library support

**The need.** If vectors ever exist, the calling convention must say how vector values are passed and which registers a callee must preserve, and the compiler needs to know what it may vectorize. If they do not, the ABI should say so, so that nobody guesses.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **State in the ABI that there are no vector types and no vector registers (current in practice, unwritten)** | clear; nothing to maintain | will need a revision if S1 changes |
| 2 | **Reserve the ABI space now (a vector-register class marked "not used")** | a smoother later addition | a rule with no user |
| 3 | **Define the full vector ABI with the extension** | complete | only when the extension is specified |
| 4 | **Library-level vectorization only (hand-tuned routines selected at run time by the feature registers of P4)** | works without ABI change | the libc and crypto routines are written by hand |
| 5 | **Let the compiler auto-vectorize into packed lanes in the integer registers (S1 option 2)** | no ABI change | compilers rarely do this well |

**What current systems do.** Every ABI for a machine with vectors defines vector argument passing and which vector registers are saved by the callee; the C libraries of Linux and the BSDs select hand-tuned vector routines at run time (not confirmed in the sources read).

**What Unix on the PDP-11 and the VAX-11 did.** Neither had a vector calling convention; the VAX vector unit was reached through compiler-generated sequences in VMS languages (not confirmed in the sources read).

**Recommendation.** Option 1 now, written into the ABI document as one sentence: no vector types, no vector registers; the string and block instructions are the substitute for the C library's memory and string routines. Cost to build: one sentence. **If nothing is done:** it stays unwritten.

---

### Evidence to gather before choosing S1

None of these was measured. Each is a small job:

1. Compile the corpus at `-O2` and `-O3` with gcc and clang for x86-64 and AArch64, and count how many functions and loops are vectorized and which instruction classes they use (the `-Os` corpus hides this).
2. Count the share of run time in memory and string routines (`memcpy`, `memset`, `strlen`, `memcmp`) in a typical program; the pdp64 already has `mcpy`, `mmov`, `mset`, `mscn` for these.
3. List the codec, hash and cryptography routines in the corpus (the corpus has bearssl, cjson and others) and which of them use lane operations, byte shuffles or carry-less multiplication.
4. Estimate the FPGA cost: block RAM for 16 vector registers of 128 bits against the 5.5 Mb budget in the FPGA plan.
5. Decide the target workloads: LittleBit inference (LB64), graphics (`BLT64` and VIC-64X), signal processing, scientific loops. A workload list decides S1 better than any survey.

## Appendix: errata 42 to 46 in full

These are the decisions of 2026-10-22, copied from `errata.md` so they can be read here. The sections of P2, P10, P11 and P13 above are the record of the options.

42. **DECISION (the author's): every design rule is a soft rule; none is absolute.** The author's words: "the no mode bits rule is a very soft rule; there were benefits to it, as long as we keep those benefits, a mode bit is fine, and where mode bits outweigh the costs, we take them," and then "all the rules are soft rules." A rule is a default that records a benefit worth protecting and the failure it prevents; it yields when the benefit of breaking it outweighs the cost, with the cost written down (the test of ISA 1.1: the benefit is named and concrete, the cost is bounded and written down, and the author judges the balance). *Consequences:* (1) ISA 1.1 no longer lists any rule as having no exceptions: the two it listed, **no mode bits** (what it protected: state saved and restored at every context switch, and a bit that changes the meaning of unrelated instructions) and **natural alignment of quad accesses** (what it protected: a trapped bug instead of silent corruption in tagged runtimes), are now the strongest defaults, and each is reopened by its cost-benefit and not by its status. (2) A mode bit that keeps the protected benefits (a machine-wide bit set once at boot, a bit in the `PSW` that is saved anyway) is accepted without further argument, and one whose benefit outweighs its cost is accepted with the cost written down. (3) Earlier choices made by a rule ("conversion instructions, never mode bits", no rounding-mode or precision bits in floating point, the one-memory-operand rule) stand but may be reopened one at a time, and a decision document should weigh them as costs and benefits, not cite the rule as a reason.
43. **DECISION (the author's picks, 2026-10-22; decisions-pending P2): a user-memory guard, `UA`, with two instructions.** Closes the weak point D11 of the system design document. *Spec:* `PSW` bit 12 is **`UA`** ("user access allowed"). With `UA` = 0 a kernel-mode data access (load, store, atomic, block-instruction operand) to a page whose `U` bit is set raises the page permission abort, reported as such in `ECAUSE`; with `UA` = 1 it behaves as today. Instruction fetch from user pages by the kernel stays forbidden (the existing rule). `PROBER` and `PROBEW` are not affected by `UA`. User-mode code is not affected (the bit is ignored outside kernel mode). Two `SYSX` words (class 0 minor 15), four bytes, privileged, no flags, `pad` = 0 else illegal instruction: **`stua`** (sub-opcode 4) sets `UA`, **`clua`** (sub-opcode 5) clears it. Exception and interrupt entry **clear `UA`** in the new `PSW`; `EPSW` keeps the old value and `RTI` restores it; `MTPS` writes it like the other `PSW` bits. Reset value 0 (guard on).
  *Why a mode bit is acceptable here (errata 42):* the bit is in the `PSW`, which is saved and restored anyway, so there is no new state to switch, and its only effect is to turn a class of kernel bugs into faults. *Cost:* a copy routine must open and close the window, and every error path out of it must close it (entry clearing it bounds the damage). *Consequences to implement:* the core, grammar (`SYSX` subs 4 and 5, `PSW` bit), QEMU, the simulator, the LLVM generator and tests; the existing test `sys-pushx` uses `SYSX` sub 4 as its "reserved word" and must move to a different reserved sub-opcode (6 or higher). Page-2 forms are not allocated.
44. **DECISION (the author's, from the principle of errata 42; decisions-pending P10): `MMUCTL` stays; the `DMW` format is deferred.** `MMUCTL` bit 0 (translation enable, reset 0) is accepted as a deliberate mode bit: it is machine-wide, set once at boot, not part of any thread's state and not saved at a context switch, and it changes the meaning of no instruction a program executes (it only decides whether addresses are translated), so the benefits the rule protected are kept. It follows the PDP-11's `SR0` enable bit and the VAX's `MAPEN`. The weak point D9 of the system design document is closed as accepted. `DMW0`/`DMW1` stay stored-only registers (System v1, errata 36); their format is defined when a kernel needs a window, not before. ISA 8.3's sentence that the machine comes up with `DMW0` covering physical memory is superseded for System v1 by "`MMUCTL` = 0: every address is physical". *My earlier recommendation to remove `MMUCTL` rested on the absolute reading of the rule and is withdrawn.*
45. **DECISION (the author's picks, 2026-10-22; decisions-pending P11): atomics are defined on a monitor (reservation), not a bus lock.** *Spec:* `LL` establishes a reservation on a naturally aligned granule of the implementation's choice (not smaller than 8 bytes); a write to the granule by **any initiator** (another core, a device, an atomic) clears it; `SC` succeeds exactly when the reservation is intact and otherwise writes nothing. The read-modify-write atomics (`CAS`, `SWAP`, `XADD` and the others) are single-copy atomic with respect to every initiator; the implementation may build them from an exclusive access with hardware retry. A constrained `LL`/`SC` sequence (short, no intervening memory access or exception) must eventually succeed when no other initiator keeps writing the granule (the guarantee RISC-V gives, per the verified RISC-V manual). `DATIP`/`DATO` are no longer an architectural primitive; a bus may still implement the atomics with them or with AXI exclusive access, which is decided separately (decisions-pending R4). The `_DB` variants keep their meaning (the atomic plus a barrier) and, under sequential consistency, are a convenience. *Still to write:* the ISA text (open item 4, 17.6), granule discovery in the feature registers (decisions-pending P4), the reservation tests in the emulators. *Cost:* a reservation rule for every initiator, and forward-progress rules; a device that writes shared words takes part by clearing reservations.
46. **DECISION (the author's pick, 2026-10-22; decisions-pending P13): `long double` stays the same as `double`; the ABI version is the door.** ABI version 1 (`abi.md`) keeps `long double` = `double`. A change to a 128-bit `long double` (binary128, in software) is an incompatible ABI change and so ABI **version 2**; the library, compiler and runtime support for it come with that version, not before. The ABI version is to be carried in the object format (ELF `e_flags`, low byte, value 1 for all objects built now): `as64` writes it, `ld64` refuses to link objects of different versions; the fields are defined when this is implemented. Matches the Apple and Windows ARM64 position and costs nothing now; the per-port variation of OpenBSD (powerpc64 64-bit, arm64 and riscv64 binary128, per the verification pass) is noted for the port.


## What I need from you

Please mark each of P1 to P18 (and any of Q1 to Q15 you want to reopen, R1 to R8, and S1 to S6) with the number of the option you choose (or "defer"). I will then: write each choice as an erratum, update the ISA and system text, and queue the implementation for an agent, one at a time. The ones I think matter most before the OpenBSD work starts are **P2** (the guard), **P10** (remove `MMUCTL`), **P11** (the monitor) and **P13** (the `long double` ABI). The rest are safe to defer.

## Appendix: verification of the comparisons

Checked on 2026-10-22 in two passes; details per claim in `docs/codegen-data/verification/claims.csv` (104 rows: verified 83, corrected 5, partly 7, not_found 9; each row has an `evidence` column: `guarantee` when a manual or standard states it, `practice` when only kernel or compiler source shows what software does, `secondary` for Wikipedia or LWN, `internal` for the pdp64's own documents). The last not_found row bundles the statements that remain marked "not confirmed in the sources read" (listed in it). Rule used for the pdp64's own facts: the grammars, `common/*.c`, tests and `docs/codegen-data` are authoritative over the prose.

**Second pass (kernel and compiler sources, vendor and standards pages):** added the Linux, OpenBSD, FreeBSD and NetBSD trees, the clang target definitions, the RISC-V ISA manual, the Intel SDM text, the kernel.org swiotlb, EDAC and RISC-V vector documents, LWN 590243, NetBSD nvmm(4), and Wikipedia pages (as pointers) for AVX-512, AMX, VIS, MAX, MVI, MDMX, the TSC and LazyFP. Statements about what software does (for example that Linux `cpu_do_idle` runs `wfi` and warns that the GIC priority mask blocks the wake-up) are labelled as practice in the text, not as an architectural guarantee. **Not obtained:** the Arm Architecture Reference Manual text on `wfi` wake-up events, the Power ISA, SPARC, s390, Alpha and MIPS manuals, AMD APM, the Intel SDM on lock-prefix scope, and everything about Hyper-V, Xen, VMS lazy vector switching, Cray and CDC machines.

**Sources used:** V7 `mch.s`, `trap.c`, `slp.c`, `mkconf.c`, `rand.c`; 3BSD `design.t`, `vmpage.c`; 4.3BSD `vax/locore.s`, `vaxuba/uba.c` (local Unix tree); PDP-11 04-55 Processor Handbook 1976 and PDP-11/70 Handbook 1977-78, VAX Architecture Handbook 1977, VAX-11 Architecture Reference Manual Rev 6.1 (May 1982), VAX 6000 Vector Processor Programmer's Guide, FPS AP-120B brochure 1976 (archive.org); Crossref for Hall and Robinson; RISC-V ISA manual snapshot; Intel SDM text (felixcloutier mirror: STI, STAC, CLAC, RDTSC, INVPCID); clang target definitions; Linux, OpenBSD, FreeBSD source trees in `~/claude/kernel-src`; `docs/kernel-asm-survey.md` and its CSV; the pdp64 documents.

### Corrections

| Old claim | New fact | Source |
|---|---|---|
| (verification pass, withdrawn) 45 one-parcel abbreviations / 19 reserved | the verification pass read 43 / 21 in ISA 4.18, which predated errata 39; the grammar defines 45 and the claim was right; the ISA text was the stale part and is now corrected | `spec/pdp64-mnemonics.hbnf`, ISA 4.18 |
| rand() seeded from the time | fixed default seed 1, programs seed it | V7 rand.c |
| VAX has 32 priority levels | levels 1-31 plus level 0 | VAX-11 Arch. Ref. Manual 6.1.1 |
| PDP-11 page registers have an accessed bit | A bit means an access met the trap condition; W bit means written | PDP-11 04-55 handbook |
| PowerPC long double is double-double | only on Linux; FreeBSD, OpenBSD, musl, AIX use 64 bits | clang PPC.h |
| (verification pass, withdrawn) code-size cost of the flag change 0.39% | the figure is measured: +0.39% bytes, 1,499,530 to 1,505,382 | `docs/codegen-data/pdp64-after-errata39.csv` |
| OpenBSD vmm and bhyve x86 only | OpenBSD arm64 has a stub only; FreeBSD bhyve has arm64 and riscv trees | source trees |
| `wfi` of AArch64 and RISC-V wakes on any pending interrupt | RISC-V: needs the interrupt enabled individually, global bit ignored; AArch64 unread | RISC-V manual |
| VAX interlocked queue instructions INSQHI in the early VAX | not in the 1977 handbook; present in the 1982 manual | VAX handbooks |

### Corrections that weaken an argument or touch a recommendation

* **P13 (`long double`):** OpenBSD's own ports are not uniform: powerpc64 uses a 64-bit `long double`, arm64 and riscv64 binary128 (clang defaults). This supports option 1 or 5 for a port that wants to match the powerpc64 port, and removes the statement that OpenBSD's choice is unknown; it does not by itself change the recommendation.
* **P1:** the RISC-V `wfi` wake rule is weaker than the text said (an enable bit of the individual interrupt is needed, and an implementation may wake for any reason), so "same result as RISC-V" holds only if the pdp64 treats the priority mask like the global enable bit.
* **P9:** the "rand() seeded from the time" remark was wrong; no effect on the recommendation.
* **Q7:** the 0.39% figure is measured and sourced (`docs/codegen-data/pdp64-after-errata39.csv`); the verification pass wrongly said it could not be found.
