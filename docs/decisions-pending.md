# Decisions waiting for the author

[← pdp64 index](../README.md)

**Status: written 2026-10-22 for the author's review.** Nothing in this document is decided unless it says so. For each open decision there is: the **need** (why the question exists at all), a plain **explanation**, the **current state** in the documents, **five options** with what each gains and costs, my **recommendation**, and what happens if nothing is decided. Each decision also says **what current systems do** and **how the recommendation compares**: counts of instructions come from the kernel survey (static counts in the sources), and the rest is my general knowledge, marked **(from memory, unchecked)**, so treat the comparisons as leads to verify, not as settled facts. A third paragraph says what Unix on the PDP-11 and the VAX-11 did (my recollection of V7 and 4BSD, not checked against the sources, which are in the toolchain repository only for the commands and libraries, not the kernel). Where a fact comes from another document it is cited; where it comes from my general knowledge and has not been checked, it says **(from memory, unchecked)**. Numbers from the kernel survey are static counts of instructions written in the sources, not measurements of how often they run.

Context for all of them: the operating system order is now OpenBSD first through the LLVM back end, Unix/32V as the fallback (errata 41). The FPGA and ASIC implementations are small in-order cores, and the architecture is to be kept ready for a large out-of-order design (errata 38). The machine is one core today; SMP, DMA devices and virtualization are not yet defined.

## Contents

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
* [Part B. Previous decisions, written up so they can be changed](#part-b-previous-decisions-written-up-so-they-can-be-changed)
* [What I need from you](#what-i-need-from-you)

## How to read this

Two terms recur. A **mode bit** (ISA section 1.1) is a bit whose value changes the meaning of unrelated instructions; the ISA has a rule against adding them, because a mode bit has to be saved and restored when one program is switched for another. **Precise** exceptions mean that when an instruction faults, every earlier instruction has completed and no later one has had any effect, so the faulting instruction can simply be run again.

The options are listed best-first by my judgement, not by cost. "Cost to build" always means the work in the assembler grammar, `as64`, `sim64`, QEMU, the LLVM generator and the tests, which is mostly mechanical because the grammars generate the numbers.

## Summary table

| # | Decision | My recommendation | Blocks or helps |
|---|---|---|---|
| P1 | `WFE` wakes on a pending interrupt even if masked | wake on pending (**open**: an earlier answer was recorded by mistake and is withdrawn) | idle loop of any kernel |
| P2 | Guard against the kernel touching user memory by mistake | PSW bit plus two `SYSX` instructions | hardening; OpenBSD (from memory, unchecked) |
| P3 | Unprivileged time counter | `rdtime rd` instruction | fast clock reads from user code |
| P4 | Feature and identification registers | read-only `mfsr` numbers 13 and up | portable kernels and libraries |
| P5 | TLB invalidate by address-space tag | one new `TLBIASID` | context-switch cost, SMP |
| P6 | Data-cache maintenance by address | reserve the encoding, build nothing yet | only a non-coherent DMA device |
| P7 | Firmware-call convention | none; devices only | boot, reboot, power-off |
| P8 | Double-width compare-and-swap | no | lock-free structures (rarely) |
| P9 | Random numbers | an entropy device on the bus, no instruction | OpenBSD's early boot (from memory, unchecked) |
| P10 | `DMW` format and `MMUCTL` | define `DMW`, drop `MMUCTL` | boot, ISA consistency |
| P11 | Bus atomics: lock or monitor | monitor (reservation) | the second core and any shared-queue device |
| P12 | Partial effects of `pushm`, `popm`, `pushx`, `popx` on a fault | accept and document, with one rule | restart correctness |
| P13 | `long double` | keep as `double` for the first system | libc, clang, the ABI |
| P14 | Priority 7 also on interrupt entry | confirm | exception entry |

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

**The explanation.** An idle loop must check for work and then sleep *without a gap*, because an interrupt that lands in the gap queues work and then the processor sleeps anyway (a **lost wake-up**: the wake-up happened before the sleep and so is missed). There are two ways to write the loop and under the current wording both fail. Lower the priority and then sleep (`spl #0; wfe`): an interrupt arriving between the two is taken, queues the work, returns, and the `wfe` then sleeps with work waiting. Sleep with the priority still at 7 (`wfe; spl #0`): the interrupt is masked, so it is never "taken", and the machine never wakes. The cure used by AArch64 `wfi` and RISC-V `wfi` **(from memory, unchecked)** is that the sleep ends when an interrupt is *pending*, even if the priority masks it. Then the loop is: `spl #7`, check for work, `wfe`, `spl #0` (the pending interrupt is taken at that point). There is no gap, because while at priority 7 nothing is taken, and the sleep returns the moment one is waiting.

**Current state.** Section 15 and the core: `WFE` (kernel mode only) sleeps until an interrupt is taken (`common/pdp64exec.c` sets a wait flag). Found by the kernel survey (its section 7, gap 1).

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Wake on a pending interrupt, masked or not** | no gap; no new opcode; same idiom as `wfi` on the two architectures I know best | a small change in the core, QEMU and a test; a pending-but-masked interrupt must be visible to the wait logic |
| 2 | Keep as written | nothing to do | the lost wake-up stays; idle loops need a workaround (a timer tick to bound the sleep) |
| 3 | `WFE` takes a priority operand ("sleep, then run at level n") | one instruction does the lower-and-sleep atomically | new operand form; more to encode and verify |
| 4 | An x86-style "interrupt shadow" after `SPL` (the next instruction cannot be interrupted) | the lower-then-sleep pair becomes safe | hidden state; rejected for the same reasons as for exception entry (errata 40) |
| 5 | No `WFE` in the idle loop; poll with `HINT` pause | nothing to specify | burns power; defeats the purpose of the instruction |

**What current systems do.** Survey counts of the wait instructions in the kernel sources: x86 `hlt` 57 and `mwait` 9, AArch64 `wfi` 15 and `wfe` 20, ARM 32-bit `wfi` 9, RISC-V `wfi` 14. The wake rule: AArch64 and RISC-V `wfi` end the sleep when an interrupt is *pending*, whether or not the mask lets it be taken **(from memory, unchecked)**; x86 closes the same gap with the "interrupt shadow" of `sti`, which delays interrupts by one instruction so that `sti; hlt` is safe **(from memory, unchecked)**.

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11:** a `WAIT` instruction exists, and as I recall V7's idle routine lowered the priority and executed `wait` inside the scheduler's loop, which rechecks the run queue after every interrupt, so a wake-up lost in the gap costs at most one clock tick (60 per second). **VAX:** no wait instruction; as I recall 4BSD's idle loop spun at priority 0 testing the run-queue summary. *Trade-off:* both avoid the problem by bounding it (a tick) or by polling (burning power). *Comparison:* the recommendation removes the bound without polling; the PDP-11 way is acceptable only with a regular clock tick, which a tickless modern kernel does not have.

**Recommendation.** Option 1. **This decision is open:** an answer to it was recorded by mistake (it was given inside a question that was rejected) and has been withdrawn. Cost to build: small; one pass with a test of the idiom. **If nothing is done:** the text stays wrong.

**How the recommendation compares.** Option 1 gives the same result as AArch64 and RISC-V and is **not better than them**; it is better than the x86 way in that it needs no hidden one-instruction state, which an out-of-order design must track. It costs one rule in the core and no opcode.

---

## P2. The kernel's access to user memory (a guard)

**The need.** The kernel must read and write user memory to implement system calls (it copies arguments in and results out). It runs with the *right* to touch user pages. A kernel bug, or an attacker, can make it touch a user page it did not mean to: a corrupted pointer that now points into user memory, or code the attacker placed in user memory. A **guard** makes any kernel access to user pages fault unless the kernel has deliberately opened it. Modern kernels value that: x86 calls it `SMAP`, AArch64 `PAN`, RISC-V `SUM` (all **from memory, unchecked**; the kernel survey counted `stac`/`clac` uses in the BSD and Linux sources, 88 in total, its section 7).

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

**What current systems do.** Survey: x86 `stac`/`clac` appear 88 times (FreeBSD 50, Linux 32) in the sources, and OpenBSD enables `SMAP` **(from memory, unchecked, as the design document says)**; AArch64 has `PAN` and the unprivileged `ldtr`/`sttr`; RISC-V has `SUM`; ARM 32-bit `ldrt`/`strt`; m68k `moves`; s390 `mvcos`; MIPS has EVA loads and stores; the PDP-11 had `MFPI`/`MTPI`. So both styles exist, six architectures chose the special-forms style, three chose the bit.

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11:** user and kernel have separate address spaces, so the kernel cannot reach user memory with an ordinary instruction at all; it uses `MFPI`/`MTPI` (and V7's `fuword`/`copyin` are built on them, as I recall). That is an always-on guard by construction. **VAX:** the process's memory is mapped in the same address space as the kernel, so a kernel routine reads a user address directly after a `PROBER`/`PROBEW` check and a fault handler for errors. That is the pdp64's present design (option 5). *Trade-off:* the PDP-11 way is safest and clumsy (every access an instruction pair, and it was fixed by 16-bit address limits); the VAX way is fast and flexible but trusts the kernel. *Comparison:* option 1 keeps the VAX ease of use and adds the guard the PDP-11 had for free; option 2 is nearest the PDP-11 in spirit.

**Recommendation.** Option 1: smallest change that closes the gap, and it matches what the three modern architectures I named do, so the kernel code that an OpenBSD port starts from already has the open/close pattern. Cost to build: a `PSW` bit, two `SYSX` sub-opcodes (sub 4 and 5 are free), a fault when kernel mode touches a user page with the bit set, tests. **If nothing is done:** option 5 by default.

**How the recommendation compares.** Option 1 copies the x86, AArch64 and RISC-V design, which is what the kernel code OpenBSD already has expects. **It is not safer than the special-forms style** (option 2), where nothing can be left open; it is cheaper to build, leaves the compiler untouched, and can be made safer than x86 by having exception entry set the guard so a handler cannot forget it.

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

**What current systems do.** Survey: unprivileged counters on x86 (`rdtsc` 19 uses, `rdtscp` 10), RISC-V (`rdtime`), PowerPC (`mftb`), s390 (`stckf`), MIPS (`rdhwr`), LoongArch (`rdtime.d`) and Alpha. Linux builds its fast clock read (the vDSO) on them **(from memory, unchecked)**. x86's `rdtsc` has a history of counters that differed between cores or changed rate with power state, which the kernels work around **(from memory, unchecked)**.

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
| 1 | **A fixed block of read-only `mfsr` numbers (13 and up): an ISA-features bitmap, a cache-geometry register, a page-size register, an address-width register** | no opcode; easy to read in a few instructions; matches AArch64's `ID_*` register idea **(from memory, unchecked)** | each register's bit layout must be written once (in a grammar, so it is generated); grows over time |
| 2 | **A `cpuid`-style instruction** returning several registers selected by a leaf number | one place for all queries; very flexible | an opcode; the leaf space is a second namespace to manage |
| 3 | **Firmware-provided description in memory** (a table handed to the kernel at boot, like a device tree) | the architecture stays silent; platforms describe themselves | the processor's own features still need a source; the kernel parses a table before it knows anything |
| 4 | **One `misa`-like bitmap register** plus a configuration string in memory (RISC-V style **(from memory, unchecked)**) | one register to read; a string for the rest | a bitmap fills up; the string needs a parser |
| 5 | **Probe by trying**: execute the instruction and catch the illegal-instruction exception | no registers | slow, fragile, and impossible for non-instruction facts (cache size) |

**What current systems do.** Survey: x86 `cpuid` 73 uses; AArch64, ARM and RISC-V read identification registers (`mrs`, `mrc`, `csrr`); s390 `stidp`/`stfle`/`stsi`; Alpha `amask`/`implver`; PowerPC `mfpvr`. x86's `cpuid` has grown hundreds of leaves, differs by vendor and traps in virtual machines **(from memory, unchecked)**.

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11:** no identification register on early models (later processors added an instruction to read the processor type, as I recall); Unix was configured at build time for the machine, and device presence was found by touching the device's addresses and catching the bus-error trap (option 5). **VAX:** a system identification register, read with `MFPR`, gave the CPU type and revision, and the kernel switched on it (option 1 in spirit). *Trade-off:* probing is simple and breaks for anything that is not a device; an identification register works for everything but must keep being extended. *Comparison:* option 1 is the VAX way, with the layout generated from a grammar.

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

**What current systems do.** Survey: x86 `invlpg` 16 uses and `invpcid` 14; AArch64 `tlbi` (by all, address, ASID, with or without broadcast); RISC-V `sfence.vma` with an optional ASID; LoongArch `invtlb`. x86 had no broadcast and used inter-processor interrupts to make other cores flush (a **shootdown**), which is slow; AMD added `invlpgb` late, which the survey saw once **(shootdown history from memory, unchecked)**.

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11:** the memory-management unit has no translation cache to invalidate; it has a small set of relocation registers per mode, and the kernel reloads the whole set on a context switch, which is the tagging (the register set *is* the address space). **VAX:** a translation buffer with invalidate-all and invalidate-single operations (`TBIA`, `TBIS`, written through `MTPR`) and no address-space tags; the process half is flushed on a context switch and the system half survives. *Trade-off:* flush on switch is simple and costs the new process its warm entries; the VAX split keeps kernel entries. *Comparison:* ASIDs plus per-ASID invalidate (option 1) beat the VAX flush on switch, and the PDP-11 way does not scale beyond 8 pages per mode.

**Recommendation.** Option 1, but it is medium priority: option 4 works until the first rollover, and a small machine with few processes rolls over rarely. Cost to build: small. **If nothing is done:** option 4.

**How the recommendation compares.** The pdp64 already broadcasts `TLBI`, so it avoids the shootdown cost that x86 pays; option 1 closes the one remaining gap. It is **the same as AArch64 and RISC-V and not better**, and the broadcast bus transaction itself has not been designed (see P11), so the advantage over x86 is on paper.

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

**What current systems do.** Survey: 12 of the 14 families have cache-maintenance instructions in their kernels (x86 `wbinvd` 17, `clflush` 9, `clwb` 1; ARM and AArch64 clean and invalidate by address). x86 DMA is coherent, so its kernels seldom need them for devices; ARM, MIPS and embedded PowerPC with non-coherent DMA do, and Linux wraps this in a DMA API that has to be called at the right moments **(from memory, unchecked)**.

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11:** the larger models had a cache; as I recall it was kept consistent with Unibus DMA by the hardware (the cache watched DMA writes), so Unix had no cache instructions. **VAX:** caches were transparent too; the one place software managed buffering was the Unibus adapter, where drivers purged its buffered data paths before reading a device's data (as I recall). *Trade-off:* hardware coherence costs gates and made every DMA path more complex, and the software never sees a cache. *Comparison:* the pdp64's uncached buffers are closer to the PDP-11 outcome (software never manages a cache) by a cheaper means (a memory type per page), at a cost of speed that those machines' caches did not impose on DMA.

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

**What current systems do.** Survey: class 13 (hypervisor, secure and firmware calls) appears in 6 families. RISC-V kernels call firmware with `ecall` through the SBI interface; ARM uses `hvc`/`smc` for power control **(from memory, unchecked)**; Alpha had PALcode; SPARC had Open Firmware; x86 reaches firmware through BIOS or UEFI services and ACPI.

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11:** boot ROMs and a console debugger (`ODT`) in firmware; Unix never called firmware, and it halted to the console. **VAX:** a console processor (on the VAX-11/780 a small separate computer) with console commands, a halt instruction that returns to it, and console terminal registers the kernel could read and write (`MTPR`/`MFPR`); reboot was a halt and a boot command. *Trade-off:* a separate console machine gave remote operation and a recovery path at the price of a second computer. *Comparison:* option 1 (devices only) is nearer the PDP-11; the VAX console processor is the origin of the firmware-call idea but was not a call interface.

**Recommendation.** Option 1 for the first system: it fits "devices are eight registers", needs no firmware, and OpenBSD ports get a console and reset from devices. Revisit with option 2 when there is a second platform. Cost to build: none now. **If nothing is done:** option 1.

**How the recommendation compares.** Option 1 is the opposite of what these do. Its advantage is **no firmware to trust, port or bug-fix and no extra privilege level**; its cost is that every platform must say where its console and reset registers are, which the others get from the firmware. For a first system with few platforms the trade is in its favour, and it is **worse** once there are many.

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

**What current systems do.** Survey: x86 `cmpxchg16b` 4 uses (and `cmpxchg8b` 13), AArch64 `casp` 2, RISC-V `amocas.q` 1, s390 `cdsg`; one Linux use, a lock-free free list with a tag. The ABA problem is otherwise handled by RCU, hazard pointers, tagged pointers or locks **(from memory, unchecked)**. AArch64 can ignore the top byte of an address for tagging.

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11:** read-modify-write instructions (`INC`, `BIS`, `BIC` on memory) are indivisible on the Unibus (`DATIP`/`DATO`), but nothing as wide as a double word; Unix on one CPU used `spl` for exclusion. **VAX:** interlocked instructions: `BBSSI`/`BBCCI` (branch on bit and set or clear, interlocked), `ADAWI`, and the interlocked queue instructions `INSQHI`/`REMQHI`, which are whole lock-free queue operations in one instruction, so the ABA problem never appears. *Trade-off:* the VAX solved the problem with a few large microcoded instructions instead of a general primitive. *Comparison:* a double-width CAS (option 2) would be the general version; option 4 does in software with spare pointer bits what the VAX did in microcode.

**Recommendation.** Option 5 now, with option 4 as the recommended software pattern. The only evidence is Linux-only; nothing in the BSD sources asked for it. Cost to build: none. **If nothing is done:** same as option 5.

**How the recommendation compares.** Option 5 plus the tagged-pointer pattern is what systems without a double-width instruction already do; it is **not better** than having the instruction. The evidence of need is one Linux use, so building it now would be speculative.

---

## P9. A source of random numbers

**The need.** A kernel needs unpredictable bits at boot (for address randomization, key generation, network sequence numbers). A hardware source is the most reliable. Without one, the system gathers jitter from interrupt timing and device events, which is slow to produce enough early in boot. (That OpenBSD wants randomness very early is from memory and unchecked.)

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **An entropy device on the bus** (one more eight-register device: a status and a data register) | no instruction; the physical source is the platform's choice; fits the device convention | not available until the platform has the device; an access per read |
| 2 | **A random-number instruction** (x86 `rdrand`, AArch64 `rndr` **(from memory, unchecked)**) | fast, available everywhere | an opcode; the architecture must say what quality it guarantees; side-channel and trust questions about the source |
| 3 | **A read-only `mfsr` register** that returns random bits | no new opcode | privileged only unless made user-readable; the same quality questions |
| 4 | **Software only**: collect jitter from the timer and interrupts | nothing in hardware | slow to fill; weak early in boot, which is the worst time to need it |
| 5 | **A seed passed in by the boot loader** (stored from the previous boot) | no hardware; fast at start | needs persistent storage; weak on first boot |

**What current systems do.** Survey: x86 `rdrand` 12 and `rdseed` 9 uses, PowerPC `darn`, s390 `prno`, AArch64 `rndr`; no other family has one. Virtual machines supply a random-number device (virtio-rng) **(from memory, unchecked)**, and kernels mix several sources and a stored seed file **(from memory, unchecked)**.

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11 and VAX Unix:** no hardware random source; `rand()` was a small linear generator seeded from the time, and 4BSD added `random()`. There was no `/dev/random`. The uses that need real entropy today (address randomization, network keys) did not exist. *Trade-off:* none was needed then. *Comparison:* the question is new; neither machine offers a precedent, and option 1 is the answer built for the present.

**Recommendation.** Option 1 (an entropy device): it matches how every other peripheral is defined and keeps the ISA free of a quality promise. Use option 5 as the supplement. Cost to build: a device definition in the bus document and a QEMU model. **If nothing is done:** option 4.

**How the recommendation compares.** Option 1 is how virtual machines already do it. It is better than an instruction in that **no opaque instruction becomes the only trusted source** and the ISA makes no quality promise; it is worse in being unavailable until the platform has the device, and slower per read.

---

## P10. The direct-mapping windows and `MMUCTL`

**The need.** The design document (D9) flags a contradiction: the ISA says there are **no mode bits** (section 1.1) and that the machine comes up with the direct-mapping window `DMW0` covering physical memory, so translation is always on and nothing needs switching. System v1 nevertheless added a `MMUCTL` register whose bit 0 turns translation on, "because the format of the direct mapping windows is not defined yet". That is a mode bit: it is not saved on a context switch, which is exactly the cost the rule exists to avoid.

**The explanation.** A **direct-mapping window** (`DMW`) maps a range of virtual addresses onto a range of physical addresses without a page-table lookup, so the kernel and the boot code can reach physical memory (and device registers) before any page tables exist. If the window format were defined, the machine could boot with a window mapping low memory, and there would be no off state to design.

**Current state.** `MMUCTL` bit 0, reset 0; `DMW0` and `DMW1` registers exist but are storage-only in System v1 (the section 15 table). The system design document calls the consistent fix "define the `DMW` format, boot with a window that maps low physical memory, and drop `MMUCTL`."

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Define the `DMW` format, boot with a window on low physical memory, remove `MMUCTL`** | consistent with the ISA's rule; no mode bit; fewer special cases | a format to write (base, size, attributes, permissions), the reset value, the exception-entry interaction; tests and the QEMU model change |
| 2 | **Keep `MMUCTL` as it is** (a documented exception to the rule) | already built | the inconsistency stays; one more thing to save in a hypervisor later |
| 3 | **A "bare" mode selected by `PTBR` = 0 or ASID 0** (RISC-V `satp` Bare style **(from memory, unchecked)**) | no separate register; a value, not a bit | still a mode in effect, merely spelled differently |
| 4 | **A single fixed identity window in hardware, not programmable**, plus page tables for everything else | simplest; no `DMW` registers at all | the kernel cannot move or resize it; platform-specific physical layouts get harder |
| 5 | **Defer: leave both** until the kernel work shows what it needs | no work now | the open item stays and more code depends on `MMUCTL` meanwhile |

**What current systems do.** x86 turns paging on with `CR0.PG` and long mode requires it, so boot code runs with an identity mapping while switching on; AArch64 has `SCTLR.M`; RISC-V `satp` has a Bare mode; MIPS has no off state and fixed unmapped windows (`kseg0`/`kseg1`); LoongArch has programmable direct-mapped windows **(all from memory, unchecked)**. The pdp64's own ISA rule (no mode bits) matches the MIPS and LoongArch kind.

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11:** the memory-management unit is switched on by a bit in status register 0 (`SR0`); Unix boots with it off, builds its relocation registers, then sets the bit. **VAX:** `MAPEN` turns on mapping; the boot code runs position-independent, has an identity mapping of low memory in the system page table, sets `MAPEN` and jumps to a system virtual address (the same trampoline x86 needs). *Trade-off:* a switch is simple hardware and a transition to get right. *Comparison:* `MMUCTL` is exactly the PDP-11 `SR0` precedent, so keeping it (option 2) is the heritage choice; option 1 removes the transition both older machines had to manage.

**Recommendation.** Option 1: it is the fix the design document already called consistent, and it is cheaper to do before an OpenBSD port starts depending on `MMUCTL`. Cost to build: moderate (grammar, core, QEMU, tests, the boot description). **If nothing is done:** option 5.

**How the recommendation compares.** Option 1 is the MIPS and LoongArch design. It is **better than the x86 and RISC-V way** in that there is no switch-on moment and no identity-map trampoline in the boot code; it is **worse** in needing a window format to be specified and verified before the first kernel runs.

---

## P11. Atomics on the bus: a lock or a monitor

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

**What current systems do.** Survey: pdp64 has more atomic operations than any surveyed architecture (`CAS`, `SWAP`, `XADD`, and the logical and min/max forms, plus `LL`/`SC`). MIPS, PowerPC, Alpha, ARM and RISC-V use load-linked/store-conditional; AArch64 adds far atomics (the LSE extension); x86 uses the `lock` prefix, which locks a cache line rather than the whole bus on modern parts; the VAX had interlocked queue instructions that locked the bus **(all from memory, unchecked)**. Linux moved its spinlocks from test-and-set to ticket to queued locks as core counts rose **(from memory, unchecked)**.

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
| 3 | **Resumable: save progress in a register so the restart continues** (x86 `rep` style **(from memory, unchecked)**) | no repeated work, no partial exposure | hidden state; the kernel must preserve it |
| 4 | **Forbid page crossing**: the instruction faults if the area spans two pages, and software splits | each part is all-or-nothing | software complexity; a long list may not fit one page |
| 5 | **Replace by a sequence of single stores** (drop the instruction) | no partial-effect question | gives up the 11-instruction saving the survey measured for entry and exit |

**What current systems do.** ARM `ldm`/`stm` restart after an abort with the base register restored **(from memory, unchecked)**; the VAX marks an interrupted instruction with a "first part done" bit and resumes; x86 `rep` instructions resume from the register state; m68k saves internal state in an exception frame. Survey: the multi-register save/restore instructions are `pushr`/`popr` on the VAX and `movem` on m68k, and the survey's path-length table puts those machines in the 6 to 11 instruction range for syscall entry.

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11:** an autoincrement or autodecrement changes a register before a later part of the instruction can fault; the larger models had `SR1`, which recorded those register changes so the kernel could undo them and restart (V7 used this to grow the stack on a fault); the 11/40 class had no such register and V7's kernel carried a `backup` routine that decoded the faulting instruction to undo its effects, as I recall. **VAX:** the hardware keeps a first-part-done bit and enough state in the exception frame to resume a long instruction. *Trade-off:* both needed extra hardware state or kernel code to make faults restartable. *Comparison:* the pdp64's precise exceptions with deferred side effects (D12) need neither `SR1`, nor a decoder in the kernel, nor a resume bit; option 1 keeps that, with the one rule about the dead stack area.

**Recommendation.** Option 1, with the dead-area rule written next to each instruction: nothing in the system reads below the stack pointer, so a partial push is invisible. Cost to build: text only, plus a test that proves a restart gives the same final memory. **If nothing is done:** the guarantee stays unwritten.

**How the recommendation compares.** Option 1 is closest to the ARM approach (restart, no hidden resume state) and **simpler than the VAX or m68k**, which save the instruction's progress. It is not better than resumable designs where the same work would otherwise repeat, but the pdp64's stack area below the stack pointer is dead, so the repeated stores are free.

---

## P13. `long double`

**The need.** C's `long double` type has no single standard width. The ABI today says `long double` is the same as `double` (64 bits). That is the cheapest choice and is what some platforms do **(from memory, unchecked)**. Other platforms make it 128 bits, and a few use the 80-bit x87 extended format. The choice goes into the ABI, the C library, the compiler and every program that uses the type, and it cannot be changed later without breaking binaries.

**Why it comes up now.** The LLVM and clang work is next, and a decision made after clang exists would break things. Which format OpenBSD's other ports use was not checked, and a port needs `printf`, `strtold` and the math functions to agree with the compiler.

**Current state.** The pcc back end for aarch64 has an opt-in binary128 `long double` (`A64QUAD`); the pdp64 has no 128-bit float hardware, so any quad would be software.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **`long double` = `double` (64-bit)** (the ABI today) | no library work; fast; nothing to maintain | programs expecting more precision get none; some C library functions have no separate `long double` versions to test |
| 2 | **binary128 in software** (AArch64 Linux and RISC-V use this **(from memory, unchecked)**) | highest precision; the common 128-bit choice | a software float library for add, multiply, divide, conversions; slow; the library must come before the system |
| 3 | **80-bit x87 extended** | compatible with x86 software | no hardware; an odd format with padding; the worst of both |
| 4 | **double-double** (PowerPC style **(from memory, unchecked)**) | fast on hardware with fused multiply-add; wide range | not IEEE; surprising edge cases; special library behaviour |
| 5 | **Start with option 1 and reserve the right to change at a defined ABI revision** | the first system moves; the door stays open | a later change breaks binaries unless the ABI is versioned from the start |

**What current systems do.** `long double` is 80-bit extended on x86, 128-bit binary128 on AArch64 Linux and RISC-V, double-double on PowerPC Linux, and the same as `double` on Apple's and Microsoft's ARM64 ABIs and with MSVC **(all from memory, unchecked)**. What OpenBSD's ports use was not checked.

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

**What current systems do.** The survey found that x86, AArch64, RISC-V, PowerPC, MIPS and SPARC all mask interrupts on entry, and that the VAX and m68k raise the priority. Most of those have one mask bit (x86 `IF`, AArch64 `DAIF`, RISC-V `SIE`), so a handler that wants nesting re-enables it by hand; the PDP-11 loaded the priority from each vector **(from memory, unchecked)**.

**What Unix on the PDP-11 and the VAX-11 did.** **PDP-11:** the processor loads a new `PC` and `PS` from the vector (two words) and pushes the old pair on the kernel stack; as I recall V7's vector table gave traps the status word `340` (priority 7) and gave each device interrupt its own priority (`br4` to `br7`). **VAX:** an interrupt raises the priority to the interrupt's level and an exception keeps it; the hardware pushes `PC` and `PSL` on the stack. *Trade-off:* because both push the old state in hardware, an interrupt at any time cannot lose it; the cost is a memory write at entry. *Comparison:* the pdp64 saves in registers, which is why it needs priority 7 on every entry; its traps at 7 follow the PDP-11 convention, and its interrupts differ from both older machines by not entering at their own level.

**Recommendation.** Option 1 (what is built): the hole is real for interrupts and the cost is one instruction per handler. Option 3 is the only one that keeps the PDP-11's flexibility and I would take it if you want nested-interrupt latency tuned per device. Cost to build option 1: already done. **If nothing is done:** option 1 stays.

**How the recommendation compares.** Option 1 matches the modern practice of masking on entry, and it **keeps the multi-level priority** that the one-bit architectures lack, so the handler can lower to the level it wants instead of switching all interrupts back on. It is **less flexible** than per-vector priority (option 3), which the PDP-11 had.

---

## Part B. Previous decisions, written up so they can be changed

These were decided earlier (the errata cited). They are set out in the same form as P1 to P14 so that any of them can be reopened: if you want to change one, mark it, and it becomes a new erratum. "Keep" below is my view of whether to keep it, not a decision. Unchecked facts from my memory are marked **(from memory, unchecked)**.

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

**What current systems do.** The kernel survey found that AArch64, RISC-V, MIPS, LoongArch and PowerPC save the return address and status in registers; x86 pushes five words; s390 swaps whole status words in low memory. NetBSD and OpenBSD on x86 therefore carry code to cope with the pushed frame **(from memory, unchecked)**.

**What Unix on the PDP-11 and the VAX-11 did.** Both pushed the old `PC` and `PS`/`PSL` on the kernel stack, in hardware; the PDP-11 loaded the new `PC` and `PS` from the vector. *Trade-off:* the stack made nesting free and made entry a memory operation; Unix's trap code relied on the pushed frame being there. *Comparison:* the pdp64 trades that safety for a short, fault-free entry, and pays with the priority-7 rule and one explicit save.

**View.** Keep. It is the modern RISC arrangement, and option 2 would put a memory write on every system call.

---

## Q2. Accessed and dirty bits are managed by software

**The need.** A page-replacement policy has to know which pages were used (**accessed**) and which were written (**dirty**, so they must be written back before reuse). The page-table entry holds a bit for each. The question is who sets them.

**The explanation.** If the **hardware** sets them, the memory-management unit must do an atomic read-modify-write of the entry on a first touch, which complicates the walker and, with several cores, needs care. If **software** manages them, the first touch of each page and the first write to it cause a fault and the kernel sets the bit; this is simple hardware but costs a fault per page per event. System v1 chose software, partly on the grounds that a hardware modify bit with software-emulated reference bits is how 3BSD paged on the VAX (unverified; see the fact-check).

**Current state.** Software-managed accessed and dirty bits; one extra fault on first touch of each page and one more on first write (system design, D8).

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Software-managed (current)** | simplest walker; no atomic update in hardware | two extra faults per page; slower for a big working set |
| 2 | **Hardware sets both, atomically** (x86) | no faults; fastest | the walker writes memory; atomicity with other cores and DMA; harder out-of-order |
| 3 | **Optional hardware management with a software fallback** (AArch64 and RISC-V have it as an option) | cheap cores stay simple; fast cores skip the faults | two modes to specify; a feature bit (see P4) |
| 4 | **Hardware dirty, software accessed** (the VAX had a hardware modify bit and no reference bit) | the dirty write-back case is cheap | half the benefit; still emulation for reference |
| 5 | **No accessed bit; approximate usage another way** (periodic protection tricks) | simplest page table | worse replacement decisions |

**What current systems do.** x86 sets both in hardware; AArch64 and RISC-V make hardware management optional and fall back to a fault **(from memory, unchecked)**; MIPS uses software refill and software bits. Linux on RISC-V runs the software scheme when the hardware lacks the option **(from memory, unchecked)**.

**What Unix on the PDP-11 and the VAX-11 did.** The PDP-11's page descriptor registers have an accessed-style and a written bit that the hardware sets (on the larger models; from memory), which Unix used for swapping. The VAX hardware set a modify bit and had no reference bit, so 4BSD emulated reference bits in software by invalidating pages and noting the resulting faults **(from memory, unchecked)**. *Trade-off:* the emulation cost faults for a policy the hardware could not give. *Comparison:* the pdp64's scheme is the VAX scheme plus emulated modify bits; it is worse than the VAX for dirty tracking and no worse for reference.

**View.** Keep for System v1, then move to option 3 once there is a feature register to advertise it. Software-only is acceptable for a first system, but the extra faults will show up in any measurement of a real workload.

---

## Q3. Three-level page tables, 39-bit virtual, 40-bit physical, 4 KB pages

**The need.** The page-table shape fixes how much memory a process can address, how many memory reads a translation costs, and how large a table is.

**The explanation.** Each level multiplies reach by 512. Three levels of 9 bits over a 12-bit page offset give 39 bits, 512 GB. The ISA calls this "one bit of headroom" over the physical window and lets the direct-mapping windows reach physical memory with no translation. More levels mean a larger address space and a longer walk on a TLB miss.

**Current state.** 3 levels, 9 + 9 + 9 + 12, entry with the physical page number in place, a flag field in the low bits; large leaf pages (1 GB) usable by the kernel.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **3 levels, 39-bit (current)** | short walk; small tables; the RISC-V Sv39 shape **(from memory, unchecked)** | 512 GB limit per address space; a database or a memory-mapped large file can run out |
| 2 | **4 levels, 48-bit** (x86-64, AArch64) | huge address space | a longer walk; more table memory |
| 3 | **Larger base page (16 or 64 KB)** | fewer levels and fewer TLB misses | internal fragmentation; software that assumes 4 KB |
| 4 | **A linear table** (VAX) or a **hashed table** (PowerPC) | simple hardware or fast lookup | large contiguous allocations; hash collisions |
| 5 | **Software TLB refill, no hardware walker** (MIPS) | any table format the kernel likes | a software refill handler runs on every TLB miss, which is slow |

**What current systems do.** x86-64 uses four levels (and five on newer parts), AArch64 up to four with 4 KB pages, RISC-V Sv39 / Sv48 / Sv57 **(from memory, unchecked)**; the survey notes the hardware walker avoids the software refill instructions of MIPS, embedded PowerPC, PA-RISC and LoongArch.

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

**What Unix on the PDP-11 and the VAX-11 did.** PDP-11: the `PS` priority and device lines BR4 to BR7; Unix wrote `spl4()`, `spl5()`, `spl6()` and `spl7()` around critical code. VAX: 32 interrupt priority levels and the same `spl` family (`splbio`, `splnet`, `spltty`, `splclock`). *Trade-off:* a priority scheme is cheap and gives priority inversion only through bad assignment. *Comparison:* it is exactly the model that BSD kernels are written for, so an OpenBSD port gets its locking model with no emulation layer.

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

**What current systems do.** x86 total store order; AArch64, ARM and POWER weakly ordered; RISC-V offers a weak model with optional total store order; Alpha was the weakest, even reordering dependent loads **(all from memory, unchecked)**. Linux and the BSDs carry barrier macros for each.

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

**What current systems do.** The same instruction set often spans in-order and out-of-order cores: ARM's small in-order cores beside its out-of-order ones, RISC-V's Rocket (in order) and BOOM (out of order), x86 from the in-order Pentium to the out-of-order P6, Alpha from the 21064 to the 21264 **(all from memory, unchecked)**.

**What Unix on the PDP-11 and the VAX-11 did.** Both lines ran many implementations, from microcoded to pipelined, under one instruction set; the VAX's complexity (long, orthogonal instructions with many side effects) is generally blamed for making its later fast implementations hard **(from memory, unchecked)**. *Comparison:* this decision is exactly the lesson of the VAX: keep the instruction set implementable fast, and ready from the start.

**View.** Keep.

---

## Q7. Condition codes kept, with two flag groups

**The need.** After arithmetic and comparisons, a branch needs to know the outcome. The two designs are a **flag register** written by instructions (PDP-11, VAX, x86, ARM) or **no flags**, where a compare-and-branch tests registers directly (MIPS, RISC-V).

**The explanation.** Flags are compact and make multiword arithmetic and tests cheap, but every flag-writing instruction creates a dependency that an out-of-order core must track. Errata 39 keeps the flags but makes them far cheaper to track: two groups (`C` and `{N, Z, V}`), `cbCC` and moves, loads and stores write none, shifts write the same flags for any count.

**Current state.** Flags kept as described; a measured cost of 0.39% in code size from the compiler change.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Flags with the two-group rule (current)** | compact code; PDP-11 heritage; cheap compares | flag writers remain in many instructions (68.2% of compiled instructions wrote a flag before errata 39; the share afterwards was not measured); a rename path for the flags in a large core |
| 2 | **Opt-in flag writing: only instructions marked "set flags" write them** (AArch64 `adds`) | flag dependencies only where wanted | an extra bit or forms in the encoding; larger code |
| 3 | **No flags; compare-and-branch and set-on-compare only** (RISC-V, MIPS) | simplest for out-of-order | multiword add/subtract needs explicit carry code; the corpus shows many `cmp`+branch pairs that need to be re-expressed |
| 4 | **Several condition fields** (PowerPC `CR0` to `CR7`) | independent flag sets | a register file to rename; more encoding |
| 5 | **PDP-11 exact: every instruction writes flags** | the classic | the structural problem the review found |

**What current systems do.** x86 and ARM32 write flags on most arithmetic; AArch64 writes them only on the "s" forms; RISC-V and MIPS have none; PowerPC has eight fields **(from memory, unchecked)**.

**What Unix on the PDP-11 and the VAX-11 did.** Both wrote condition codes on nearly every instruction, including moves, and Unix's compiled code relied on that (a `tst` after a move was often omitted). *Trade-off:* compact code and cheap tests, with a hidden dependency in nearly every instruction. *Comparison:* the pdp64 keeps the programming model and drops the dependencies that cost most; its compiler had relied on the old behaviour and the change cost 0.39% in size.

**View.** Keep. Option 2 is worth a look if a large core is built, but it would reopen the encoding.

---

## Q8. Instruction length: 2, 4 or 6 bytes plus a one-parcel second page

**The need.** The length of instructions decides code size, fetch bandwidth and how hard decoding is.

**The explanation.** Fixed-length instructions decode trivially but waste space; variable-length ones are denser but make wide decoding harder. The pdp64 uses 16-bit **parcels**: an instruction is one, two or three of them, and the first parcel says which. A second page of one-parcel abbreviations (`len = 11`) covers the commonest forms in two bytes.

**Current state.** 2, 4 or 6 bytes; 45 one-parcel abbreviations; measured code size within 0.2% of `gcc -Os` and 7% below `clang -Os`.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **2/4/6 bytes + second page (current)** | dense; length found from the first parcel; PDP-11 lineage | variable length; branches and calls need relaxation |
| 2 | **Fixed 32 bits** (AArch64, MIPS) | trivial decode | about a third larger code; 32-bit constants need sequences |
| 3 | **16/32-bit mix** (RISC-V C, Thumb-2) | dense and mostly regular | the compressed forms limit register choice |
| 4 | **Byte-granular** (x86, VAX) | densest | the hardest to decode wide; length from the whole prefix |
| 5 | **Fixed 64-bit / bundled** (VLIW) | simple fetch | large code; a different machine |

**What current systems do.** AArch64 fixed 32; RISC-V 16/32 mixed; x86 byte-granular up to 15 bytes **(from memory, unchecked)**.

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
| 4 | **Sign-extension as a side effect of every narrow operation by a mode** | none needed | a mode bit, against the ISA's rule |
| 5 | **A single `sext`/`zext` that fuses with the previous operation in hardware** | no encoding change | fusion hardware that small cores avoid |

**What current systems do.** RISC-V RV64 and AArch64 both have 32-bit forms of the common operations; MIPS64 has separate 32-bit and 64-bit adds; x86-64 has sized operations **(from memory, unchecked)**.

**What Unix on the PDP-11 and the VAX-11 did.** PDP-11: word and byte forms (`MOVB`, `CMPB`, `INCB`) with the byte sign-extending into registers on load; VAX: sized operations for every data type. *Trade-off:* sized operations made programs compact and the instruction set large. *Comparison:* the pdp64 deliberately gives up the PDP-11's sized operations, and the compiler pays with extension instructions that the other two 64-bit RISCs avoid with their 32-bit forms.

**View.** Keep, but measure the extension overhead on the corpus; if it is more than a few percent of instructions, option 2 is the usual fix and fits the second page.

---

## Q10. Devices are eight memory-mapped registers plus DMA

**The need.** How a driver talks to a device decides how much code every device costs and how fast it can go.

**The explanation.** Devices appear as a few addresses; the processor sets a transfer up by writing them, and the device moves the data itself by **DMA** (direct memory access) and interrupts when done. Fewer registers means less driver code; the author's goal was a driver that is trivial to write and a processor that is left free.

**Current state.** Ethernet, USB and disk each eight registers plus DMA (errata 29); layout, descriptor format and doorbell convention not yet written.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Eight registers + a descriptor chain (current)** | tiny drivers; PDP-11 spirit | USB and Ethernet at speed want queues of many descriptors; one layout may not fit all three |
| 2 | **Virtio-style: a small register set plus shared-memory queues** | existing drivers in OpenBSD and others **(from memory, unchecked)**; standard for virtual machines | the queue formats to implement in hardware |
| 3 | **NVMe or xHCI style: many registers, doorbells and rings** | the fastest, matches real hardware | large and complex drivers |
| 4 | **Programmed I/O only (no DMA)** | trivial devices | the processor moves every byte |
| 5 | **Channel I/O** (IBM mainframe style) | the processor offloads completely | a second processor per channel |

**What current systems do.** Virtual machines use virtio; real storage and network devices use NVMe, xHCI and vendor ring designs; embedded systems use memory-mapped register blocks with DMA descriptors.

**What Unix on the PDP-11 and the VAX-11 did.** Unibus devices had a handful of registers (a disk controller about eight; a serial line four), some with DMA (disks) and some with programmed I/O (terminals); the VAX added the Unibus adapter with map registers for DMA. *Trade-off:* simple drivers, little parallelism. *Comparison:* this is the PDP-11 device model; its weakness is throughput at gigabit rates, where ring-based designs win.

**View.** Keep, and consider making the virt machine's devices virtio-compatible because an OpenBSD port could reuse its virtio drivers **(from memory, unchecked)**.

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

**What current systems do.** ARM32 and some AArch64 code use literal pools; RISC-V uses `lui`/`addi` and a pool for 64-bit constants; x86 has `movabs` **(from memory, unchecked)**.

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

**What current systems do.** AArch64 `mrs`/`msr`, RISC-V `csrr`/`csrw`, MIPS `mfc0`/`mtc0`, PowerPC `mfspr`/`mtspr` **(from memory, unchecked)**; the survey counted privileged-register access as 48% of all compiler-invisible occurrences.

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

**What current systems do.** x86 and m68k borrow; ARM family not-borrow; RISC-V has no flags **(from memory, unchecked)**.

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

**What current systems do.** OpenBSD supports a long list of architectures with a single source tree; NetBSD is known for the widest portability; Linux has the most ports **(from memory, unchecked)**.

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

**What current systems do.** AArch64 `isb`, RISC-V `fence.i` / `sfence.vma`, x86 serializing instructions and control-register writes **(from memory, unchecked)**; the survey found the context-synchronizing barrier is the most used barrier on most architectures (`isb` 187, `isync` 662, SPARC `membar` 533 occurrences).

**What Unix on the PDP-11 and the VAX-11 did.** Both applied changes at once (a write to the MMU registers or to `MAPEN` or the translation-buffer registers took effect immediately); the VAX required a short discipline around `MAPEN`. *Comparison:* the pdp64 follows modern practice at the cost of one instruction in rare kernel paths.

**View.** Keep.

---

## What I need from you

Please mark each of P1 to P14 (and any of Q1 to Q15 you want to reopen) with the number of the option you choose (or "defer"). I will then: write each choice as an erratum, update the ISA and system text, and queue the implementation for an agent, one at a time. The ones I think matter most before the OpenBSD work starts are **P2** (the guard), **P10** (remove `MMUCTL`), **P11** (the monitor) and **P13** (the `long double` ABI). The rest are safe to defer.
