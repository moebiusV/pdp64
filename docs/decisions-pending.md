# Decisions waiting for the author

[← pdp64 index](../README.md)

**Status: written 2026-10-22 for the author's review.** Nothing in this document is decided unless it says so. For each open decision there is: the **need** (why the question exists at all), a plain **explanation**, the **current state** in the documents, **five options** with what each gains and costs, my **recommendation**, and what happens if nothing is decided. Each decision also says **what current systems do** and **how the recommendation compares**: counts of instructions come from the kernel survey (static counts in the sources), and the rest is my general knowledge, marked **(from memory, unchecked)**, so treat the comparisons as leads to verify, not as settled facts. Where a fact comes from another document it is cited; where it comes from my general knowledge and has not been checked, it says **(from memory, unchecked)**. Numbers from the kernel survey are static counts of instructions written in the sources, not measurements of how often they run.

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
* [What I need from you](#what-i-need-from-you)

## How to read this

Two terms recur. A **mode bit** (ISA section 1.1) is a bit whose value changes the meaning of unrelated instructions; the ISA has a rule against adding them, because a mode bit has to be saved and restored when one program is switched for another. **Precise** exceptions mean that when an instruction faults, every earlier instruction has completed and no later one has had any effect, so the faulting instruction can simply be run again.

The options are listed best-first by my judgement, not by cost. "Cost to build" always means the work in the assembler grammar, `as64`, `sim64`, QEMU, the LLVM generator and the tests, which is mostly mechanical because the grammars generate the numbers.

## Summary table

| # | Decision | My recommendation | Blocks or helps |
|---|---|---|---|
| P1 | `WFE` wakes on a pending interrupt even if masked | **Decided: yes** (your answer); errata 42 to write | idle loop of any kernel |
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
| `ISYNC` and `HINT` exist | errata 39 |
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

**Recommendation and status.** Option 1, and you have said yes. Cost to build: small; the QEMU agent can do it in one pass with a test of the idiom. **If nothing is done:** the text stays wrong.

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

**Recommendation.** Option 1 (what is built): the hole is real for interrupts and the cost is one instruction per handler. Option 3 is the only one that keeps the PDP-11's flexibility and I would take it if you want nested-interrupt latency tuned per device. Cost to build option 1: already done. **If nothing is done:** option 1 stays.

**How the recommendation compares.** Option 1 matches the modern practice of masking on entry, and it **keeps the multi-level priority** that the one-bit architectures lack, so the handler can lower to the level it wants instead of switching all interrupts back on. It is **less flexible** than per-vector priority (option 3), which the PDP-11 had.

---

## What I need from you

Please mark each of P2 to P14 with the number of the option you choose (or "defer"). I will then: write each choice as an erratum, update the ISA and system text, and queue the implementation for an agent, one at a time. The ones I think matter most before the OpenBSD work starts are **P2** (the guard), **P10** (remove `MMUCTL`), **P11** (the monitor) and **P13** (the `long double` ABI). The rest are safe to defer.
