# The timer, the IOMMU, the interrupt controller and the atomics: every pending decision judged again by the approved principles

I took the twelve decisions of the timer design and the twenty-one questions of the review of the IOMMU, the interrupt controller and the atomics, and judged each one again against the complete set of principles in their order. For the reader who fell asleep at a PDP-11 console fifty years ago: the order is **safety** first, by a ladder (make the mistake impossible in the hardware; failing that, make the safe way the idiom of the software; failing that, soften the damage; failing that, make failure cheap to recover from), with "the safe way must also be the shortest and cheapest way to write" inside it; then **speed as measured run time** (and power); then fewer instructions and fetches (which only stand in for speed); then dense encoding; then a good compiler target; and last a set small enough to keep in your head. Standing over all of it: one binary must run on every implementation; measure, do not guess; an instruction is weighed by how often it runs; rules are soft; do not multiply things without benefit; and the work already done, the tests that exist and the effort of a change are never a reason for or against an option.

I name the decisions **T1 to T12** (the timer design, in its order) and **F1 to F21** (the form of the review, in its order).

## 1. The result in one paragraph

Of the 33 decisions, **7 recommendations change** (T3, T7, T9, F5, F7, F14, F16); 4 more keep their answer but gain a sentence that closes a hole I found in the wording (F1, F3, F10, T4); the other 22 stand. Three of the changes are the same principle applied twice: *a duty that software can forget is a defect of the hardware* (the zero value of the timer deadline, the forgotten "armed" state of the guest timer, the table stores the IOMMU may never see). Nothing here is built or edited; I changed no other file.

Measurements I could not make, and what each would decide, are in section 4.

## 2. The table

"Changed?" compares with the recommendation in the earlier documents. "Rung" is the place on the safety ladder: a = prevented by construction in hardware, b = prevented by idiom in software, c = only softened, d = only recovered from.

| # | Decision | Options | Recommendation | Changed? | The principle that decides it |
|---|---|---|---|---|---|
| T1 | Where time lives | system registers / device page | System registers `MFSR TIME`, `MTSR TIMECMP` | no | rung a: a register cannot be mapped into a user program by a slip; the guest's offset is applied inside the core |
| T2 | Counter frequency | fixed 10 MHz / a frequency register / told by the machine description | Fixed 10 MHz | no | nothing to set wrong; one binary everywhere; no measurable gain from a finer tick |
| T3 | The deadline register | one register, absolute, a special "never" value / compare plus enable / relative down-counter | One register, absolute; **zero means never** (was: all ones) | **yes** | the easy value (zeroed memory, a cleared save area) must be the safe one; same gates, and disarming becomes a shorter instruction |
| T4 | The interrupt | level, effect before the next instruction / level but delayed / edge | Level, effect before the next instruction; the timer stays a level input beside the interrupt page (see F5) | no (one interlock added) | rung a: a level cannot be lost, a removed deadline cannot fire |
| T5 | One-shot, no periodic mode, no relative write | one-shot / add a relative write / add periodic | One-shot only | no | Occam; the extra instructions run once per scheduling event, not in a hot loop |
| T6 | The guest's timer | two comparators and "the timer of whoever runs" / Arm's separate registers plus a read-real-count bit / one comparator multiplexed in software | Two comparators, `GTIMECMP` for the hypervisor | no | rung a: no way to read the real count, no trap bit to forget |
| T7 | Guest line 6 | fires once when armed / a level like the real one | **A level**, like the real one (was: once) | **yes** | no hidden state to lose at a world switch; the same handler behaves the same on bare metal and in a guest |
| T8 | The counter | one for the machine, read only, never goes back / one per core | One for the machine, read only, with the cross-core rule and a test | no | rung a for "cannot go backwards"; the Linux clock-trust flaws |
| T9 | What a user program may know of time | no clock, kernel page, gated future rule / gated rounded read now / leave it to the kernel | Keep no unprivileged clock in version 1; **withdraw the kernel-updated page** as the fast path; the future read is the hardware-rounded one; **needs measurement**: how often real programs read the clock | **yes** | safety by default, then measured run time: a read costs 1 cycle against about 20 to 300 for a system call, but a page that only the kernel updates goes stale |
| T10 | Register numbers | 16, 17, 148 and reserved groups / next free numbers | 16, 17, 148; reserve a group for the interrupt controller as well | no | one source of truth; room for the family |
| T11 | `sim64` counter | one tick per instruction / the host's clock | One tick per instruction; a wait jumps to the deadline | no | tests must give the same answer every run |
| T12 | Order of work | answers first / build the register form first and measure | Answers first | no | nothing is left to measure that a build would decide; effort is not a reason |
| F1 | IOMMU layout | copy RISC-V where we agree / keep our own | Copy where we agree; keep a written list of deviations, now with one more entry (commands run in order) | no (list gains an entry) | best of breed, and an independent model to test against; safety deviations stay |
| F2 | Device interrupts | table per device in the IOMMU / one fixed target / trust the devices | Table per device in the IOMMU | no | rung a: a device with no entry raises nothing |
| F3 | The "forget this mapping" promise | precise weaker promise / strong promise plus stopping the device / keep the old sentence | Precise promise, **stated as a safety guarantee** | no (wording) | do not state what hardware cannot keep; state what it can keep and test it |
| F4 | Devices behind a switch | require ACS, group as fallback / group only / refuse without ACS | Require ACS, group as fallback | no | rung a where the hardware exists, rung b only where it does not |
| F5 | The interrupt controller | per-core page with set register and TOP / only a signal register / adopt AIA | A per-core pending-and-enable file; **the core's side by system registers, the page for devices only and closed to cores** | **yes** | rung a again: no page for the kernel to map wrongly; and a register read is faster than a bus read |
| F6 | Level from the vector | vector / 32 / a stored level per vector | Vector / 32 | no | rung a: a vector and its level cannot disagree; measured: about 14,800 gates and 672 state bits saved |
| F7 | The physical timer | per-core page, shape of the virtual one / shared timer / per core plus RDTIME | **Per-core comparator in registers**, no page, no RDTIME in version 1 | **yes** | follows T1, T6, T9 |
| F8 | Atomic operand layout | three registers, CAS keeps expected and old in one / four registers for CAS / two registers | Three registers (A) | no | the same form as the oldest compare-and-swap and as x86, RISC-V and Arm; measured on a real corpus |
| F9 | Offset in the address | none / small scaled offset / full modes | No offset | no | measured: 78 percent need an address calculation, but it costs one overlapped cycle beside an atomic that takes many |
| F10 | Sizes | 4 and 8 / 8 only / also byte and half | 4 and 8; **add the rule for mixed-size access** | no (rule added) | measured: 95 percent of value-returning atomics are 4 bytes; learn from the mixed-size flaw |
| F11 | Misaligned atomic | precise fault / allow within a line / allow any | Precise fault | no | rung a; the split-lock flaw costs over 1,000 cycles and stalls other cores |
| F12 | Atomics on uncached or device memory | cached only, fault elsewhere / far atomics / forward to the bus | Cached only, precise fault elsewhere | no | rung a: an atomic is atomic or it faults, never half |
| F13 | When LL/SC loops finish | RISC-V's constrained loop / prose / looser limit | The constrained loop, with a test | no | rung a for the hardware promise, rung b for the compiler |
| F14 | Size of the marked piece | 8 to 128 reported / fixed 8 / unreported / **fixed 128** | **Fixed bound of 128 bytes, no register in version 1** (was: 8 to 128 reported) | **yes** | easy to be correct (pad to 128 and stop); Occam; measured: same gates either way |
| F15 | Memory order | keep sequential consistency / weak / total store order | Keep sequential consistency | no | rung a: ordering errors cannot arise |
| F16 | Table stores visible to the IOMMU | every invalidate is the visibility point plus FENCE / a separate command / unit watches caches | **The unit reads its tables coherently** (the invalidate command still orders its own caches) | **yes** | the proposal leaves a hole: a fence does not write a dirty cache line back |
| F17 | Device atomic needs write permission | state now / say nothing | State now, with its own fault cause | no | close it before the feature exists |
| F18 | Capability bits | a bit per refused or optional feature / none | A bit per feature, read only, zero where refused | no | one binary: what is refused must be discoverable |
| F19 | Order of work | atomics first / interrupts and IOMMU first | Atomics first; the rule sentences that cost no code at once | no | dependencies and untested decided rules |
| F20 | Adopt the RISC-V IOMMU whole | not now / adopt | Not now | no | no measured big win; default-deny is ours |
| F21 | Adopt AIA whole | never while SPL stands / adopt | No | no | measured in the kernel survey: the BSD kernels emulate in software what SPL gives in one instruction |

## 3. How I judged, and what I measured

**Measured here, with programs in `docs/encoding-work/bench/rejudge-timer-iommu/`** (all of it under 100 KB):

* **M1. Gates.** `blocks.v` and `count.sh`: the repository's own method (`tools/gates`: yosys synthesis, mapped to two-input NAND, count = NAND plus half an inverter; a flip-flop counted apart and as 6 in totals). The subtractor came to 661, matching the reference 64-bit adder of 660 in the earlier study. Results in `gate-results.txt`. Counts of single blocks synthesised alone, not a placed core.
* **M2. Gate depth.** `depth.sh`, `depth-results.txt`: a 64-bit compare is 28 gate levels as synthesised, shallower than the 131 levels of the same style of 64-bit subtract that every core already finishes in a cycle. The file says which depths I do not trust.
* **M3. Cycles of a time read.** `tload.s`, `tsys.s`, `tnone.s`, `run-timer-bench.sh`, `timer-bench-result.txt`: 1,000 reads of the time by a load from a kernel-kept word and by a trap, in the cycle model of `sim64 --timing`. The load adds **1.0 cycle** a read; the trap adds `sys + 1`, that is **21, 101 and 301 cycles** for the model's trap cost set to 20, 100 and 300. The model's trap is a flat parameter, not a measurement of any kernel: the model has no kernel path, and `sim64 -K` has no cycle model. So the real trap cost is **not measured**.
* **M4. A real machine's clock read.** `clockbench.c`, `clockbench-result.txt`: on a six-core desktop x86-64 under Linux 6.12, the kernel-assisted user read of the clock (the vDSO, which reads the hardware counter from user mode) takes **16.8 ns**, the same call as a real system call **158 ns**, a plain system call **120 ns**: a factor of **9.4**. Linux added the user read for exactly this reason.
* **M5. Atomics in a real kernel.** `atomics-corpus.py`, `run-atomics-corpus.sh`, `atomics-corpus-result.txt`: a static census of every locked instruction in the 4,225 x86-64 kernel modules of Linux 6.12 on this machine (37,566 of them). It is a static count of one architecture's compiled code, not run-time frequency, and modules lean to drivers. The figures are used where each decision needs them.
* **Not available:** QEMU would only give the host's speed, never the speed of a pdp64 core, so I did not run it for run-time questions; `sim64 -V` is the vector model and has nothing to say here.

**What I checked in the repository's studies** is cited by file in each argument: `docs/hardware-vulnerabilities.md`, `docs/kernel-pain-points.md`, `docs/openbsd-mitigations.md`, `docs/kernel-asm-survey.md`, `docs/encoding-work/best-of-breed-iommu-irq-atomics.md` and `docs/encoding-work/timer-design.md` (which holds the reading of Arm, RISC-V, x86, the PDP-11 clocks and seL4). Where I use a fact about another machine that those documents did not read, I say "from memory, not verified" and the argument does not depend on it.

## 4. What still needs a measurement I could not make

| Decision | The measurement | Why I could not |
|---|---|---|
| T9, F7 | How often real programs read the clock, and the true cost of a trap and return on the first core | no pdp64 kernel or core exists; the model's trap cost is a parameter |
| F2 | The cost of one interrupt-table read on a cache miss, against a whole interrupt | needs the memory model of a real unit; the tools give gates only |
| F9 | How many atomics are executed, and how many are preceded by an address calculation, in the compiled OpenBSD kernel | no pdp64 build of the kernel; my census is static and on another architecture |
| F15 | What sequential consistency costs a large out-of-order core | no such core; not measurable with the tools |
| F16 | The gate and traffic cost of a coherent table reader | the cores' interconnect is not designed in gates |
| T2 | Whether any user needs a tick finer than 100 ns | no user to ask; I found no measured need |

## 5. The timer decisions

### T1. Time lives in system registers

*Options.* A device page (today's model, the RISC-V ACLINT, the PDP-11 clock card at a fixed bus address) or registers (Arm, RISC-V's Sstc extension, the x86 deadline register, and, from the repository's own note, the VAX interval clock as processor registers, from memory not verified).
*Ladder.* A page that a kernel can map into a user program by a slip hands that program a clock: that is a duty software can forget, so the device page is at best rung b. A register cannot be mapped: rung a. The guest's offset must be applied inside the core, and a bus device does not know which core or which guest is asking, so the page cannot be made right for a guest at all.
*Easy to be correct.* One instruction to read, one to set; nothing to map or protect.
*Run time.* A register read is an instruction; a device read is a bus round trip. In the model (M3) a load from a kernel word costs 1 cycle; an uncached bus read is longer, but I cannot give its number.
*One binary.* A machine without the timer simply never writes the deadline.
*Past flaws.* The many "borked timers" that a Linux timekeeper has to cope with (`docs/kernel-pain-points.md`, interrupts and timers, row 3) are platform-described timers; a counter defined by the architecture has no variants.
*Recommendation.* Registers, as before. Unchanged.

### T2. A fixed frequency of 10 MHz

*Options.* Fixed, or a register that tells it (Arm's way, which firmware had to fill in and sometimes did not: the Linux binding has a workaround), or told by the machine description.
*Ladder.* A constant cannot be left unset or wrong: rung a. The two others leave a duty to firmware.
*Run time and power.* A finer tick buys nothing measurable: a deadline cannot usefully be finer than the interrupt latency, which is far longer than 100 ns, and a finer counter toggles more and needs more gates to run at that speed. Ten ticks make a microsecond; 64 bits last 58,454 years.
*One binary.* A constant is invisible to the binary; a real chip makes 10 MHz from its crystal.
*Past.* Arm moved to a fixed rate from Armv8.6 (read in the earlier study), which agrees with the principle; it chose 1 GHz, and I did not read why, so I do not argue from it. A finer tick would make a coarse clock harder to give a user (T9); here the tick is already too coarse to time a single cache access (a cache miss is of the order of 100 ns, and a hit far less) though not too coarse to time a thousand of them.
*Recommendation.* Fixed 10 MHz. Unchanged. The one open question (does anyone need finer) has no measurement to settle it, so it stays at the cheaper side.

### T3. The deadline register: one register, absolute; zero means never

*Options.* One absolute register where a special value means "never"; a compare register plus an enable bit (today's model, Arm); a relative down-counter (Arm's second register).
*Ladder.* One register has no half-armed moment: arming, re-arming and disarming are each one write, so a late enable cannot meet a stale deadline: rung a. A relative counter reaches only 214 seconds at 10 MHz with 32 bits and drifts when used for a periodic tick.
*What I found in the choice of the special value.* The earlier design made all ones mean never, and reset to all ones. I judge that the wrong way round. The commonest state of a program's memory is zeroed: a cleared save area, a freshly allocated context, a guest whose registers the hypervisor zeroes, a loop that clears registers to be safe. A deadline register loaded with zero from such a state means "the deadline was at time zero, long ago": the level interrupt fires at once and then storms until a handler rewrites it. That is the easy way to use the register being the unsafe way, a hardware encouragement to a software flaw. The x86 deadline register has the safe convention (writing zero disarms it, read in the earlier study). Making zero mean never costs nothing: the counter is already past zero from its first tick, so zero is never a wanted deadline, and all ones becomes an ordinary (very distant) value, which also removes the earlier rule that "the last tick of 58,000 years cannot be a deadline".
*Measured.* The comparator "counter at or past the deadline, and the deadline is not zero" is **565** gates, the same as the all-ones version (`t_zero` and `t_abs` in `gate-results.txt`); both are 28 levels deep. Disarming becomes a write of zero, which needs no register preloaded with all ones, a shorter and cheaper instruction every time (the earlier design listed the extra move as a loss).
*Past.* The RISC-V reference model needs a special case for an all-ones compare because the counter would wrap; with zero there is no such case.
*Recommendation.* One register, absolute, **zero means never, reset to zero**. Changed from before: *the safe value must be the one that needs no work.*

### T4. The interrupt is a level, and a write takes effect before the next instruction

*Options.* Level with immediate effect; level but "eventually" (RISC-V's rule, which allows a spurious interrupt after re-arming); edge that clears itself (x86), which the earlier study notes can still deliver once for a deadline that was just changed.
*Ladder.* A level cannot be lost while masked: a masked edge is gone (the PDP-11 programmable clock could lose a tick and only set a bit to say so). Immediate effect means no handler need tolerate an interrupt for a deadline already removed; that is rung a for the in-order cores and a stated architectural rule for any other core (a pending latch cleared by the write), so it is the same binary everywhere and testable.
*Run time.* A deadline is written about once per scheduling event, so even a few cycles of serialising on an out-of-order core do not matter.
*Past.* The x86 documented race and RISC-V's "eventually" are the flaws; the "nobody cared" interrupt storm in `docs/kernel-pain-points.md` (interrupts, row 2) is the price of a level that is never cleared, which is why T7 matters.
*The interlock I add.* If F5's page turns a wired source into a message, a message sets a pending bit and the bit is cleared when taken. A level that is converted that way becomes "once" and the stale-interrupt rule needs a cancel path. So the timer must stay a **level input** that is combined with the pending bits at the core, not a message. I state this here so F5 and T4 are not decided apart.
*Recommendation.* Level and immediate effect. Unchanged, plus the interlock.

### T5. One-shot only; no relative write; no periodic mode

*Options.* One-shot; add a write-only relative register; add a periodic mode.
*Ladder.* No mode means no "second tick before the first was handled" case (the PDP-11 programmable clock reports it in an error bit; I read only that the x86 periodic mode exists, not its overrun behaviour).
*Run time and instructions.* Arming from nothing is read, add, write: three instructions where a relative write would be one. They run once per scheduling event (a timeslice end, an idle entry), a few thousand times a second at most, while a context switch costs hundreds of cycles; two extra instructions are far below measurement. Hot-loop weight does not apply: the timer is not touched in loops.
*Occam.* A second way to do one thing, and seL4's own interface is absolute.
*Recommendation.* One-shot only. Unchanged.

### T6. The guest's timer: two comparators, one name for "the timer of whoever runs", and `GTIMECMP`

*Options.* As proposed; Arm's separate guest and hypervisor registers with a bit that lets a guest read the real count; one comparator multiplexed by the hypervisor in software.
*Ladder.* In the proposed form the guest has no way to name the real counter or the hypervisor's comparator: rung a. In Arm's form there is a bit the hypervisor must remember: rung b, the exact shape of "hardware that encourages software flaws". The software-multiplexed form needs every guest deadline write to trap, so a trap bit that is set by default; safe, but a hypervisor entry for each write.
*Run time.* With two comparators a guest arms its timer with no exit. A guest writes a deadline about once per scheduling event; an exit and entry is of the order of tens to hundreds of cycles (the earlier study assumed 20 and says no real figure exists), so the difference is small but it is paid on a hot path of every guest; I did not measure it.
*Gates.* About 2,600 gates a core, about one percent of a core (the earlier count; the changes below remove the guest's armed flip-flop and its edge logic).
*One binary.* The names mean the same thing to the same code at either level; a guest kernel runs unchanged.
*Recommendation.* As proposed. Unchanged.

### T7. The guest's line 6 is a level, like the real one

*Options.* Fire once each time it is armed (the recorded answer), or follow the comparator as a level.
*What I found.* "Once each time it is armed" needs a hidden flip-flop, the "armed" flag, that no register shows. At a world switch the hypervisor saves and restores `GTIMECMP` and `VTOFF`, but not that flag, so a guest whose deadline fired and was delivered before the switch is re-armed by the restore and fires a second time: the state is not fully in registers. That is hidden state across an interruption, against the last rung of the ladder (restart without hidden state). A level has no such flag: the whole state is the deadline, the offset and the counter, so a restored expired deadline fires at once, exactly what "a deadline in the past fires at once" already says.
*Coherence.* With once for the guest and level for the real timer, a handler that forgets to write the next deadline behaves differently on bare metal (a storm) and in a guest (silence). The same binary must behave the same; a level on both removes the difference.
*Cost.* The guest's line is the "pending" bit that the hypervisor may set OR the comparator condition; delivery clears the first and not the second. One OR, and one flip-flop fewer.
*Recommendation.* A level. **Changed** from the recorded answer: *no hidden state; the same code behaves the same.*

### T8. One counter for the machine, read only, never going back

*Options.* One for the machine; one per core.
*Ladder.* Unwritable: a counter software can set can go backwards (RISC-V's is writable): rung a for "never backwards". The cross-core rule (a read begun after another core's read finished is not smaller) is a stated architectural rule every implementation must meet and a test can check.
*Past flaws.* The clock-trust pains of Linux (`docs/kernel-pain-points.md`, interrupts, rows 3 and 6: counters that disagree between cores, a second clock needed to watch the first) are exactly a per-core or settable counter.
*Test to add.* One core reads the counter and signals another through an atomic; the other reads and must not see less. It needs two cores, hence the atomics first (F19).
*Recommendation.* As proposed. Unchanged.

### T9. What a user program may know of time

*Options.* (1) No unprivileged clock; the kernel keeps a read-only page updated when it runs; a future gated, rounded read reserved. (2) A gated, hardware-rounded read now. (3) Leave it to the kernel without hardware rounding.
*What I found about the page.* A page the kernel updates "when it runs" goes stale in a tickless kernel: a program that spins on the clock until a deadline sees time stand still until the kernel next runs, and may never leave the loop. A clock must advance for correctness, not only for timing channels. To keep the page fresh the kernel would need a periodic tick, which the design refuses. So the page as the fast path is withdrawn: it is a flaw waiting for the first busy-wait.
*Ladder for the timing channels.* The honest facts from `docs/hardware-vulnerabilities.md`: cache-timing attacks need a shared cache and a precise timer, and a program can build its own clock with a counting thread on another core, so coarsening is a brake and not a wall. The strongest rung available is therefore the kernel's control of what is shared, not the absence of a clock. Given that, an information-equal choice is available: a kernel-mediated read and a hardware-rounded user read give the program the **same** information at the same granule. They differ in cost, and in who can forget: with the rounding in hardware, off at reset and coarsest by default, a forgetful kernel is safe.
*Run time.* M3: 1 cycle for a read against `sys + 1` (21 to 301) for a trap in the model. M4: 9.4 times on a real x86. A program that stamps every request (a database, a network server) reads the clock very often; this is the reason a user read exists on every other architecture. The figure that decides, how often real programs read it, I did not measure.
*Encoding and gates.* The rounding is 275 gates counted (`tround`), about the same as the 305 of the earlier count; a granule field and an enable bit in one reserved register. A new mnemonic is cheap and Occam does not forbid it if it is separate and correct.
*Old designs.* As far as I remember, none of the PDP-11 or VAX clocks was user-readable (from memory, not verified); I found nothing to revive here.
*Recommendation.* Keep **no unprivileged clock in version 1**; **withdraw** the kernel-updated page as the fast path (the system call is always correct); fix now that the future read is the hardware-rounded one described, with register 18 reserved for its enable and granule; and **measure** how often real programs read the clock and what a trap costs on the first core before building it. **Changed** in the part about the page.

### T10. The register numbers

*Options.* 16, 17 and 148 with reserved groups, or the next free numbers.
*Ladder and principle.* An unassigned number is an illegal instruction (rung a), so a reservation costs nothing and protects the family. One source of truth: the numbers live in the grammar and the tables are generated.
*Added.* F5 needs a handful of registers for the core's interrupt file (enable bits, top, a signal to another core); reserve one group of eight beside the timer's, in the kernel range 13 to 127.
*Recommendation.* As proposed plus that group. Unchanged.

### T11. The simulator's counter

*Options.* One tick per instruction (the same answer every run), or the host's clock.
*Principle.* A test must give the same result every run; a wait for an event must jump the counter to the deadline. With the cycle model the count could follow modelled cycles, but then a test's result would depend on the model's parameters, which defeats the purpose.
*Recommendation.* One tick per instruction. Unchanged.

### T12. Order of work

*Options.* Answers first, or build the register form first and measure.
*Principle.* Building first would be justified only if a build could measure something I cannot now; I found none that it would decide (section 4 lists what would need hardware). The effort of building and of rewriting tests is no reason either way.
*Recommendation.* Answers first. Unchanged.

## 6. The questions of the review

### F1. Take the IOMMU's layout from RISC-V

*Options.* Copy where we do the same job; keep our own.
*Ladder.* No hole closes by copying; the gain is an independent model: the shared parts can be run against another implementation, which is the cheapest way to find our bugs (verify before you state; best of breed).
*Past flaws.* Copying a ratified design copies what it leaves to software. Reading the earlier study: the RISC-V unit "may execute the fetched commands out of order" and says software must place a fence; its mode that lets everything through must exist; its reset is only "recommended" to be off. Each is a duty software can forget, so each stays a deviation, and the list of deviations gains one entry: **our unit executes its commands in the order given**, so a missing fence cannot reorder an invalidate. (The old Unibus map had none of this, only a few registers and a bus reset; the VAX-era drivers' trouble with purging buffers is the lesson.)
*One binary, run time.* The layout decides only table depth and register names; I could not measure the walk cost.
*Recommendation.* Copy where we agree; deviations listed, now with in-order commands. Unchanged in substance.

### F2. A table per device inside the IOMMU for message interrupts

*Options.* The table; one fixed target; trust the devices.
*Ladder.* With the table a device's write carries an index and the unit looks it up in that device's own table, so a device with no entry raises nothing: rung a. "Trust the devices" is no rung. One fixed target closes the hole but makes a queue-per-core card unassignable.
*Measured.* A four-entry cache of table entries (27-bit tag, 40-bit entry) is 922 gates of logic and 272 flip-flops, about **2,550 gate equivalents** (`itcache4`); a hit is 18 gate levels. A miss is one memory read; an interrupt costs thousands of cycles, so a cached or even an uncached read is a small fraction, but I did not measure it.
*Past flaws.* A device can forge interrupts when nothing filters the message; the sources (Intel's remapping "to control and censor external interrupt requests", the GIC and RISC-V translation tables) all put a table between the device and the target (`best-of-breed-iommu-irq-atomics.md`, section 1.3). `docs/hardware-vulnerabilities.md` lists the DMA family (Thunderclap) that shows an IOMMU alone is not enough.
*An alternative I considered.* Filter by page: give each device a window of vectors by the page the IOMMU maps for it, so no new table, command or fault is needed. It is also rung a, and cheaper in state. I did not recommend it because a guest-owned device is programmed by the guest with its own vector numbers, and the per-device table is what lets those pass unchanged without the hypervisor trapping every write to the card's interrupt table; the page scheme would force that trap, a software duty. This is a judgement, not a measurement, and the page scheme deserves a gate count if the table's cost troubles anyone.
*Recommendation.* The table. Unchanged.

### F3. What "forget this mapping" promises

*Options.* The precise weaker promise; the strong sentence with stopping the device; keep the old sentence.
*Principle.* Do not state what the hardware cannot keep; state what it can, and test it. Thinking it through I find the promise is stronger than the form says: every request is seen by the unit when it **arrives**, so a request still on the cable when the command completes will arrive afterwards and be translated by the new table, refused if unmapped. What the unit cannot do is stop a write the device issued before the unmap from being dropped. So the guarantee is a safety one: *after the command completes, nothing that device sends can reach the old target; what the unit already accepted is complete.* The kernel stops the device first only to avoid losing data, not for safety. This needs no ATS, which version 1 refuses.
*Measured.* The count of requests accepted and not completed is a 16-bit up-down counter with a zero test: 177 gates of logic and 16 flip-flops, about **270** gate equivalents.
*Past.* Thunderclap's cost of strict, synchronous invalidation (up to 80 percent of throughput, `docs/hardware-vulnerabilities.md`) says the command must be cheap to wait for; a counter that drains is.
*Recommendation.* The precise promise, written as the safety guarantee above, with a two-phase model to test it. Unchanged; wording.

### F4. Devices behind a switch: require ACS

*Options.* Require ACS and keep the group as fallback; the group rule only; refuse without ACS.
*Ladder.* ACS redirects every request upward so the unit sees it: rung a, where the card has it. Where it does not, the group is rung b. Refusing outright is also rung a, but takes a whole class of boards out of use; the ladder says stop at the first rung that works, and the group works if it is computed in one place.
*Verified now.* The names of the bits (source validation, request redirect, completion redirect, upstream forwarding, translation blocking, direct translated, egress control) are in the Linux header on this machine; I did not read the PCI Express specification, so the exact meaning of each in the text stays to be checked before the manual is written.
*Recommendation.* Require ACS, group as fallback, with one test: a device model behind a switch without it is assigned only together with its whole group, or not at all. Unchanged.

### F5. The interrupt controller

*Options.* A per-core page with a set register and `TOP`; a signal register only; adopt AIA whole.
*History I looked at.* The PDP-11 kept the pending request **in the device** as a level on a priority line; the processor stored nothing. A message cannot do that: a posted write is consumed, so something must hold the pending bit. So the file is needed, and the designs I compared (a file per core, with the signal between cores as the same message) are the best of breed.
*Where I change it.* The proposal made the file, its enable bits, `TOP` and the signal to another core all registers in a page. A page that a kernel can map into a user program by a slip lets that program forge any vector or signal any core: a duty software can forget, and the same argument I accepted for the timer (T1). The AIA itself reads and claims through processor registers and only receives messages in memory. So: **the core's side is by system registers** (enable, top, send a signal to a core; kernel mode only, rung a), and the **page exists only for devices**, reachable through the IOMMU, and **the hardware refuses a core's access to it**. A guest's version is the hypervisor's seven virtual lines, unchanged.
*Measured.* Highest pending enabled vector above the current priority, level from the vector: 1,336 gates of logic; 224 pending and 224 enable bits are 448 flip-flops, 2,688 gates; **about 4,000 gate equivalents a core**, one and a half percent of a core of 220,000 to 310,000 (the earlier "about 1,300 bits" estimate is not what the derived-level design needs; it is 448). The model of the priority select I wrote is a plain chain; a real one is a balanced tree and I do not claim its depth.
*Safe defaults.* Everything disabled at reset; a vector that belongs to a wired source (the timer, the console) cannot be set by a message write.
*Run time.* A register read of the top is an instruction; a read of a page is a bus read.
*Recommendation.* The per-core file, **its core side in registers**, the page for devices only. **Changed**: *no page for the kernel to map wrongly.*

### F6. The level follows from the vector

*Options.* Level is the vector divided by 32; a stored level for each vector.
*Ladder.* With the rule a vector and its level cannot disagree: rung a. With stored levels they can, and a check or a rule is needed. The PDP-11 had exactly this trap: a card's priority jumper and its vector switch were set independently, a classic misconfiguration (from memory, not verified here).
*Measured, same coding style on both sides.* Select the highest eligible pending vector: **1,007** gates when the level is derived, **11,741** when each vector carries a level (`irq_derived`, `irq_stored`); and 672 bits of state, 4,032 gates, that the stored form needs. The stored form's logic is my plain coding; a cleverer one cannot go below 224 three-bit comparisons plus the 672 flip-flops, so the saving is at least 4,000 gates and probably about 14,800, five to seven percent of a core.
*Past.* x86 and AIA derive the priority from the number (`best-of-breed-iommu-irq-atomics.md`). x86's pain that "the vector space is notoriously low" (`docs/kernel-pain-points.md`, interrupts, row 8) is a reminder that 32 vectors a level a core is a limit; a queue-per-core card needs few vectors a core, so it holds.
*Recommendation.* Vector divided by 32. Unchanged, now measured.

### F7. The physical timer

*Options.* Per-core page; shared timer; per core plus a user read.
*Judgement.* A comparator per core: yes (a shared one needs a lock or a window). But **in registers, as T1 and T6 now say**, not in a page, and no user read in version 1 (T9). With T3, T4 and T7 it has the same shape as the guest's.
*Recommendation.* Per-core comparator in registers. **Changed** from the page.

### F8. Atomic operand layout

*Options.* (A) three registers for all, compare-and-swap with the expected value in the destination register and the old value coming out in it; (B) four registers for compare-and-swap; (C) two registers.
*The old design.* From memory, not verified here: IBM's System/360 compare-and-swap (1970) already works this way: it compares the first register with storage; if equal it stores the third, if not it loads storage into the first. x86's `CMPXCHG` ties the accumulator the same way, and RISC-V's compare-and-swap does. So form A is the 1970 form.
*Easy to be correct.* On success the old value equals the expected one; on failure the C11 call overwrites the expected value with the old one, exactly what A does, so a retry loop costs nothing. The one extra instruction is loading a constant expected value (zero for a lock) before each try.
*Measured (M5).* Of 1,970 compare-and-swaps in the x86 corpus, 134 (7 percent) have a zeroing within three instructions: the cost of A is that, on a compiler that already pays it on x86 where the accumulator is tied the same way.
*Encoding and gates.* A needs no decode cost over B (`casA`, `casB`: 0 gates either way); it takes one leaf shape and frees the full four-register leaf.
*Recommendation.* A. Unchanged; now supported by the corpus and the oldest example.

### F9. A small offset in the atomic's address

*Options.* Register only; a small scaled offset; full modes.
*Measured (M5).* Of the 37,566 locked instructions: **22 percent** use a register alone, **76 percent** a register plus a displacement, 2 percent a global and under 1 percent an index. Displacement up to 120 bytes (a 4-bit offset of 8-byte words) adds another 32 points; up to 504 bytes 51 points in all, up to 2,040 bytes 60 points. So register-only needs an address calculation (one `LEA`) for about 78 percent of atomics, and a 4-bit offset would remove it for only about two in five of those.
*Run time.* The `LEA` is independent and runs beside the atomic, which on a contended line takes many cycles; and atomics are a tiny fraction of instructions executed. I do not have the dynamic count (section 4), but a one-cycle overlapped instruction before a memory operation of many cycles is far below measurement.
*Cost of the offset.* An adder in the address path (291 gates, `addr_off`) and opcode space in a leaf of all the atomics; the alignment check (4 gates) must come after it.
*Recommendation.* No offset. Unchanged, and now the number the earlier note asked for is known; it does not tip the decision because the cost is overlapped.

### F10. Sizes: 4 and 8 bytes; add a rule for mixed sizes

*Options.* 4 and 8; 8 only; also byte and half.
*Measured (M5).* Of value-returning atomics (compare-and-swap and exchange-and-add): **9,150 are 4 bytes, 415 are 8 bytes**. Of all: 4 bytes 45 percent, 8 bytes 21 percent, byte 34 percent; the byte figure is almost all `lock orb` and `lock andb` with a constant, which a compiler uses to set or clear one bit of a flag word; on the pdp64 those are 4- or 8-byte atomic or/and. Compare-and-swap on a byte occurs 3 times in 4,225 modules.
*Past flaw.* `docs/kernel-pain-points.md` (atomics, row 3): bit operations on arrays of ints, the lock-and-count of 8 bytes over two 4-byte fields, and the finding that on Arm and POWER barriers do not recover sequential consistency for mixed-size accesses. The manual's own statement lacks the case.
*Rule to add.* State that every aligned access is atomic for its size and that overlapping accesses of different sizes to the same bytes obey the same sequentially consistent order, with a litmus test for the 8-byte pair of 4-byte halves. In a coherent machine whose unit is the line this is free; saying it by construction is what makes the flaw impossible.
*Recommendation.* 4 and 8, plus the mixed-size rule. Unchanged plus a sentence.

### F11. A misaligned atomic

*Options.* Precise fault; allow within a line; allow any.
*Ladder.* A fault cannot stall other cores or be non-atomic: rung a. `docs/hardware-vulnerabilities.md`: a split lock "takes over 1000 extra cycles" and the detection "cannot be virtualized"; any program can slow every core. One alignment check is 4 gates (`align8`).
*Recommendation.* Precise fault. Unchanged.

### F12. Atomics on uncached and device memory

*Options.* Cached only, a precise fault elsewhere; far atomics at the memory; forward to the bus.
*Ladder.* The atomic runs atomically or faults, never half: rung a. It also removes the contradiction between "a device write clears a reservation" and "the DMA path is not snooped": the pages devices write are the pages where no reservation exists.
*Past.* A silent read-then-write that is not atomic is the worst outcome (a lock two parties hold). The stricter memory type wins (already decided), so the hypervisor's second stage cannot make an atomic page cached by a trick.
*Recommendation.* Cached only. Unchanged.

### F13. When an LL/SC loop is guaranteed to finish

*Options.* RISC-V's constrained loop (at most 16 instructions in sequence, only register instructions between the pair, the same address); the prose "short"; a looser limit.
*Ladder.* The hardware promise is rung a (the store-conditional may not fail forever for a listed reason); the compiler's obedience is rung b, which a test can check by running two cores on the loop. The prose cannot be checked.
*Past.* `docs/kernel-pain-points.md` (atomics, row 2): "if you have a case of failing cmpxchg a lot, your cache coherency is simply bad", about 25 retries for one compare-and-swap on an Arm part; the livelock RISC-V names as the main disadvantage of LL/SC.
*Old designs.* Compare-and-swap (F8) has no livelock of this kind and the fetch-and-op words cover the commonest uses; LL/SC stays for what they cannot do, and for waking on a reserved word.
*Recommendation.* The constrained loop, with a two-core test. Unchanged.

### F14. How big is the marked piece

*Options.* 8 to 128 reported in a register; fixed 8; unreported; fixed 128.
*What I found.* The reservation must always cover the loaded word; extra clearing only causes a retry. So the architecture can say "an aligned 128-byte block"; an implementation that tracks less never misses the word and is still correct. Software that pads its locks to 128 bytes never suffers false failure on any implementation; a register would only let software pad less, which saves memory and never affects correctness.
*Measured.* The compare of a store address against the reservation is 322 gates for a fixed 128 bytes, 348 for a fixed 8, 359 for a reported size (`resv128`, `resv8`, `resvvar`): no difference worth a decision.
*Principle.* Easy to be correct (one rule: pad to 128); Occam (no register to read, to test or to get wrong); one binary (it is the same for all). A cache line over 128 bytes is not allowed to be the reservation. If memory used by padded lock arrays is ever measured to matter, a capability can be added later.
*Recommendation.* **A fixed upper bound of 128 bytes, no register in version 1.** **Changed.**

### F15. Keep sequential consistency

*Options.* Keep; weak; total store order.
*Ladder.* Ordering mistakes cannot arise: rung a. `docs/kernel-pain-points.md` (atomics, rows 1 and the store-buffering entry) records decades of barriers and the Linux memory model, and the store-to-load reordering that even x86 needs a flush for.
*Run time.* The only cost is on a large out-of-order core: a speculative core must replay on a violation. I cannot measure that without such a core; the first implementations do not speculate, and the veto of one binary says an out-of-order core must implement sequential consistency, not change the rule. An old design shows it can be done: the MIPS R10000 was an out-of-order machine with sequential consistency (from memory, not verified here).
*Recommendation.* Keep it, with the litmus tests and the wake on a reserved word. Unchanged.

### F16. Table stores become visible at the next invalidate command

*Options.* Every invalidate is the point of visibility plus a fence; a separate command; the unit watches the caches.
*What I found.* The proposal says the kernel puts a fence before the command and the unit flushes its own caches. But a fence orders the core's stores; it does not write a dirty line out of the core's data cache, and the manual says the unit's path is not snooped. If so, the new table entry may still be in a core's cache when the unit reads memory. The kernel would have to clean the line by hand: a duty with two steps to forget, the exact flaw of the early Intel IOMMUs, whose "coherency" bit told software to flush the cache line itself (from memory, not verified; the Arm SMMU's coherent-access bit I did read).
*By construction.* Let the unit read its **tables** coherently, as a cache-less core would, through the same snooping that the cores already have between themselves. The reason the manual refuses to snoop DMA (large, infrequent transfers) does not apply to a table walk (an 8-byte read, rare). Then nothing has to be remembered; the invalidate command still orders the unit's own caches. Devices' data stays uncached as decided.
*Measure.* The gates and traffic of a coherent reader on the interconnect I could not count.
*Recommendation.* **The unit's table reads are coherent; the invalidate command orders its own caches.** **Changed**: *the table store must be visible by construction, not by two remembered steps.*

### F17. A device atomic needs write permission

*Options.* State it now; say nothing.
*Principle.* Version 1 refuses device atomics, so nothing is lost, and the rule is in place when the feature comes. The fault gets its own cause so a test can tell it from a plain refusal.
*Recommendation.* State it now. Unchanged.

### F18. Capability bits for refused or optional features

*Options.* A bit each; none.
*Ladder and one binary.* A refusal that no program can discover is a rule, not a fact; one binary needs to ask. A read-only bit, zero where refused, makes a later version add a feature without breaking old drivers.
*Recommendation.* A bit each. Unchanged.

### F19. Order of work

*Options.* Atomics first; interrupts and IOMMU first.
*Principle.* The decided rules that have no test (the clearing of a reservation at an exception and a world switch) cannot be tested before the atomics exist, and the other two parts need a second core. Effort is no reason either way. The sentences that cost no code and close holes by words (F3, F10, F11, F12, F17, F18) have no dependencies and can go in at once.
*Recommendation.* Atomics first, those sentences in parallel. Unchanged.

### F20. Adopt the RISC-V IOMMU whole

*Principle.* A bold change needs a measured big win; none is measured. Adopting it whole gives up default deny (a safety rung a that is ours) and our table entry.
*Recommendation.* Not now; revisit when a real kernel's driver is attempted. Unchanged.

### F21. Adopt AIA whole

*Principle.* The AIA makes priority the identity number (as F6 does) but offers only a threshold register and says it does not define nesting. `docs/kernel-asm-survey.md` (section 4.14) finds that NetBSD and OpenBSD emulate in software on x86 and Arm what `SPL` gives in one instruction, and calls the pdp64 position "the design the survey most clearly vindicates". The `spl` calls are on every lock and driver path of a BSD kernel, which is the heaviest hot-loop weight in the list.
*Recommendation.* No, for as long as `SPL` and the vector table stand. Unchanged.

## 7. What I could not verify

* The cost of a trap on a real pdp64 core, the time-read rate of real programs, the dynamic atomic counts of a compiled BSD kernel, the interrupt-table read on a miss, the coherent table reader, and the speed of sequential consistency on a large out-of-order core (section 4).
* Statements marked "from memory": the VAX processor registers for the interval clock; the PDP-11 priority jumper; IBM's compare-and-swap of 1970; the MIPS R10000; the early Intel IOMMU coherency bit; whether the Arm 1 GHz fixed rate has a stated reason.
* The PCI Express text for the ACS bits (only the Linux header was read).
* My static census counts the compiled code of one architecture, not run-time frequency; the byte-size figure is the compiler's choice for bit operations.
