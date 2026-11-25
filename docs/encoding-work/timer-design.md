# The timer of the pdp64: registers, guest timer, and what a program may know of time

Written 2026-11-25 for the owner, at his request ("we need to define those timer registers ... best practice and best possible improved versions"). It is a design with options and a list of decisions at the end (section 8), to be answered "accept / change / not decided". Nothing is built, changed in the manual, or recorded as decided by this document.

The rules used (the owner's, restated twice): start from the best designs of other processors, read in their own documents; change them minimally so that holes close **by construction** (the hardware cannot do the wrong thing, rather than software being told not to); a bold change is welcome if it is a big win. In order: **safety, speed, fewer instructions**, and last a **set small enough to keep in the head** like the PDP-11's. Each point below says in a few words what it is, which hole it closes, and what we lose.

## 0. The proposal in one page

A **timer** here is three things: a counter that counts time, a comparator that raises an interrupt when the counter reaches a chosen value, and the rules around them.

1. **Registers, not a device page.** Time is read with `MFSR TIME` and the deadline is set with `MTSR TIMECMP`: two new system registers (the numbered registers that `MFSR`/`MTSR` read and write, kernel mode only). No load or store, no bus, no page to map or to forget to protect.
2. **One counter for the whole machine,** 64 bits, read only, counting at a fixed **10 MHz** (10,000,000 ticks a second, the rate of today's model). It cannot be written, so it cannot go backwards. 64 bits at 10 MHz wraps after **58,454 years** (computed: 2^64 / 10^7 / 31,557,600 s).
3. **One comparator per core, one register: `TIMECMP`.** The deadline is an **absolute** counter value. The interrupt is asserted while counter >= `TIMECMP`; the value all ones means "never" (it is the reset value). There is no enable bit and no pending bit: arming, re-arming and disarming are each one write, so there is no moment with half-written state.
4. **The interrupt is a level** (it stays asserted until software writes a later deadline), at priority level 6, vector 32 (unchanged). A write to `TIMECMP` takes effect before the next instruction, so an interrupt for a deadline that the write removed is never taken.
5. **One-shot only.** A periodic tick is the interrupt handler adding the period to the old deadline (no drift). This is also exactly what seL4's tickless scheduler asks of a timer (section 3.7).
6. **Guests get a second comparator and a counter offset, in registers.** At the hypervisor level the same two names reach the real counter and the real comparator; in a guest they reach (real counter minus `VTOFF`) and the guest's own comparator, whose expiry sets virtual line 6. One new hypervisor-block register, `GTIMECMP`, lets the hypervisor load and save the guest's deadline. A guest has no way to read the real counter, so there is no trap bit to forget.
7. **No unprivileged clock** (unchanged). A user program learns the time from a system call, or from a read-only page the kernel keeps up to date at a resolution the kernel chooses. If a user-readable clock is ever added the rule is set now: off at reset, one kernel-set bit, and the hardware itself rounds the value to a kernel-set resolution.
8. **Numbers:** `TIME` = 16, `TIMECMP` = 17, `GTIMECMP` = 148. Numbers 18 to 23 stay free for the family (a watchdog comparator of the same shape; the user-access control), and 24 to 31 for the performance counters.

| Register | Number | Access | Width | At the kernel level (`H` = 0 in a guest, or no hypervisor) | At the hypervisor level (`H` = 1) |
|---|---|---|---|---|---|
| `TIME` | 16 | read only | 64 | counter (a guest: counter minus `VTOFF`) | the real counter |
| `TIMECMP` | 17 | read, write | 64 | this core's comparator (a guest: its own comparator, expiry sets virtual line 6) | the real comparator (expiry is the physical level-6 interrupt, vector 32), which keeps running while a guest runs |
| `GTIMECMP` | 148 | read, write | 64 | illegal instruction (a guest cannot use a hypervisor register) | the guest's comparator, to load before entering a guest and save after an exit |
| `VTOFF` | 140 (exists) | read, write | 64 | not reachable | the offset subtracted for guests |

Gate cost (section 6): **about 2,600 NAND2 gate equivalents per core and about 670 for the machine's counter**, a gate count of Verilog blocks that I synthesised (the sum, with one shared subtractor, is my estimate), about one percent of the scalar core's estimated 220,000 to 310,000.

**What this reverses of recorded decisions:** the "core-local virtual timer page" (the hypervisor design's choice T2, accepted with its 23 decisions), the device page of the machine's timer, and the "virtual alarm fires once each time it is armed" stays (not reversed). Details in section 7.

## 1. What exists today (read in the repository)

* **The machine's timer** is a device page with three 64-bit registers: counter at offset 0, compare at 8, control at 16 (enable bit 0, pending bit 1). The counter counts at 10,000,000 ticks a second of the emulator's clock. The interrupt is asserted while counter >= compare and enable is set, at level 6, vector 32 (`spec/grammars.d/50-system-v1.hbnf` lines 52, 96, 124 to 133; the device `qemu-pdp64/hw-pdp64/timer.c` lines 43, 85 to 88, 104 to 109: reset sets compare to all ones and enable to 0). The page is at device address 0x8000000000.
* **The guest's timer** is a second page of the same three registers at a provisional address, one per core, whose counter reads the real counter minus `VTOFF` (system register 140); its expiry sets bit 6 of `VIRQ` once each time compare or control is written (`qemu-pdp64/hw-pdp64/vtimer.c` lines 33, 56 to 60, 114 to 118). Today it exists only as a bus device of a one-core machine, because a bus device cannot know which core or guest is asking (the review of the MMU and virtualization, hole H7).
* **The rules:** no unprivileged instruction reads a clock, a counter or the core number (manual 6.14.2, from the audit of sensitive instructions). The manual says the main cores are tickless and that a core in secure mode takes no periodic tick, and leaves the form of the timer open (manual 5.7.1 and appendix J.5.1). The model is in order and does not speculate (manual 7.5.4). A guest's `SPL` masks only virtual interrupts and a physical interrupt always exits to the hypervisor (manual 6.14.5).
* **The system registers** are numbers 0 to 12 (`spec/grammars.d/41-sysreg.hbnf`); 13 to 127 are kept for kernel registers, 128 to 147 are the hypervisor block, and an unassigned number is an illegal instruction (hypervisor design, 1.3).
* **A difference to correct:** the hypervisor design's reset table says the guest timer's compare resets to 0 with enable clear; the code resets it to all ones (`vtimer.c` line 139). With the design below the right value is all ones and the row becomes a single register.
* **There is no timer in the shared executor** (`common/pdp64exec.c` has only the `VTOFF` hook, lines 458 and 481), and so none in the simulator `sim64`; the tests `tests/qemu/timer.S`, `hv-timer.S` and `hv-vtimer.S` use the device pages.

## 2. What other machines do (each read in a primary source on 2026-11-25)

Quotes are one sentence of under 25 words. "Unverified" means I could not read it and it is kept out of every conclusion.

| Design | Where the time and the deadline live | What was read (source, then quote) |
|---|---|---|
| **Arm generic timer** | The counter is one "system count" shared by all cores; each core has timers reached by system registers (`CNTVCT`, `CNTV_CVAL`, `CNTV_CTL` and so on). | Arm, "Learn the architecture - Generic Timer", version 1.3, document 102379_0103_01_en (documentation-service.arm.com, static/65fac6957bcc0c1c661b36c0): "The System Counter is an always-on device, which provides a fixed frequency incrementing system count." |
| | Frequency | Same document: "CNTFRQ_EL0 reports the frequency of the system count. However, this register is not populated by hardware." and "From Armv8.6-A and Armv9.1-A, the frequency of the count is fixed at 1GHz." The Linux binding (Documentation/devicetree/bindings/timer/arm,arch_timer.yaml) adds a workaround: "Should be present only where necessary to work around broken firmware which does not configure CNTFRQ on all CPUs". |
| | Width | Same document: "The system count value is between 56 bits and 64 bits in width." (My arithmetic: 56 bits at 1 GHz wraps after 2.3 years.) |
| | Two ways to set a deadline | Same document: the comparator `CVAL` is 64 bits ("Timer Condition Met: CVAL <= System Count"); "The timer register, TVAL, is a 32-bit register." and "When software writes TVAL, the processor reads the current system count internally, adds the written value, and then populates CVAL". |
| | Interrupt | Same document: "The interrupts generated by the timer behave in a level-sensitive manner." It stays until the timer is masked, disabled, or the compare is written so the condition is false. |
| | Guest | Same document: "Virtual Count = Physical Count - <offset>" and the offset is in `CNTVOFF_EL2`, "only accessible at EL2 or EL3". QEMU `target/arm/helper.c` also checks a hypervisor bit before a guest may read the physical count (`gt_pct_access`): the hypervisor must remember to turn that off. |
| | User access | Same document: "EL0 access to these timers is controlled by CNTKCTL_EL1." and "Reads of CNTPCT_EL0 can be made speculatively" (so an `ISB` or the self-synchronising read is needed). QEMU `helper.c` lines 1188 and 1229 show the bits that make an EL0 read trap. |
| **RISC-V** | `time` is a read-only register (a CSR, RISC-V's name for a system register) that shadows a memory-mapped counter `mtime`; the machine compare `mtimecmp` is memory-mapped, one per hart (hardware thread). The Sstc extension adds `stimecmp` as a register so supervisor mode need not call machine mode. | Privileged specification, source `src/priv/machine.adoc` and `sstc.adoc` of the public repository, main branch, read 2026-11-25: "The time CSR is a read-only shadow of the memory-mapped mtime register." and "This extension serves to provide supervisor mode with its own CSR-based timer interrupt facility" (Sstc). |
| | Counter | Same source: "mtime must increment at constant frequency", "The mtime register will wrap around if the count overflows."; the platform tells the tick period (the device tree's `timebase-frequency`; unverified here). `mtime` is read-write there, and "the mtime counter can be shared between multiple cores". |
| | Compare and interrupt | Same source: "A machine timer interrupt becomes pending whenever mtime contains a value greater than or equal to mtimecmp"; "The interrupt remains posted until mtimecmp becomes greater than mtime". Also "guaranteed to be reflected in MTIP eventually, but not necessarily immediately" (so a spurious interrupt after a write is allowed: the specification's own note says so). No enable bit: masking is the interrupt-enable bits. |
| | Guest | Hypervisor extension, `hypervisor.adoc`: "reading the time CSR in VS or VU mode returns the sum of the contents of htimedelta and the actual value of time." and large deltas "may be used to represent negative time offsets" (needed to move a guest to a machine whose counter is behind). `vstimecmp` is the guest's comparator. |
| | User access | Same source: the `mcounteren` fields "may be read-only zero", and a read then "will cause an illegal-instruction exception"; `scounteren` and `hcounteren` do the same one level down. QEMU `target/riscv/tcg/csr.c` lines 151 to 165 implements the three checks. |
| **RISC-V ACLINT** (the memory-mapped timer device) | `MTIME` one register, `MTIMECMP` one per hart, in device memory. | ACLINT specification 1.0-rc4, 2022-01-10 (riscv-aclint repository, read through a fetch tool that returns quotes): "On MTIMER device reset, the MTIME register is cleared to zero." and "a time compare register (MTIMECMP) for each HART connected to the MTIMER device." QEMU `hw/intc/riscv_aclint.c` lines 82 to 87: a compare set "in the past" raises the interrupt at once. |
| **x86** | Local APIC timer, TSC-deadline mode: a 64-bit deadline written by `WRMSR` (a model-specific register write, kernel only) against the time-stamp counter. | Intel 64 and IA-32 Software Developer's Manual, order number 325462-093US, volume 3A section 13.5.4.1 (a copy already on this computer, read 2026-11-25): "An interrupt is generated when the logical processor's time-stamp counter equals or exceeds the target value in the IA32_TSC_DEADLINE MSR." and "each write to the IA32_TSC_DEADLINE MSR generates at most one timer interrupt." |
| | Disarm, and the race | Same section: "writing 0 to the IA32_TSC_DEADLINE MSR disarms the local-APIC timer"; and "race conditions may result in delivery of a timer interrupt associated with the original deadline." (a postponed or disarmed deadline can still deliver once). The older one-shot mode is a down-counter written as an initial count (same section, table 13-2). |
| | User access | Same manual, control register 4: "Restricts the execution of the RDTSC instruction to procedures running at privilege level 0 when set". A guest's `RDTSC` can be offset or trapped by the hypervisor ("Use TSC offsetting", volume 3C). |
| **PDP-11, KW11-L** (the family's line clock) | One register, `LKS` at 777546, two bits. | PDP-11 Peripherals Handbook 1976 (bitsavers PDF, pages 4-331 and 4-332, text from OCR, read 2026-11-25): bit 7 "Monitor: Set by the line frequency clock signal and cleared by the program." and bit 6 "Set to allow Monitor = 1 to cause an interrupt." Vector 100, level BR6, one tick each 16-2/3 ms at 60 Hz or 20 ms at 50 Hz: the rate depended on the mains. |
| **PDP-11, KW11-P** (programmable clock) | Control and status 772540, count-set buffer 772542, 16-bit counter 772544; rates 100 kHz, 10 kHz, line, external; modes single and repeat. | Same handbook, page 4-334: bit 15 Error: "Set when, in Repeat-Interrupt Mode, a second underflow or overflow occurs before the interrupt of the preceding one has been serviced." (a periodic clock can lose a tick; the hardware only reports it). The counter counts down to zero and "the interrupt sequence is initiated at zero (underflow)". |
| **seL4** (the kernel that the pdp64 wants to run) | The machine layer needs three things under the tickless "MCS" scheduler. | seL4 repository, `include/machine/timer.h`, master, read 2026-11-25: "Set the next deadline irq - deadline is absolute and may be slightly in the past." (plus `getCurrentTime` and `ackDeadlineIRQ`). Its Arm driver sets the deadline by writing the compare register, and acknowledges by writing the compare register to all ones (`include/drivers/timer/arm_generic.h`, read through a fetch tool). Its RISC-V timer source I could not fetch (not found at the address I tried). |
| **Browsers** | A web page's clock is deliberately coarse. | MDN, `Performance.now()`, read 2026-11-25: "Resolution in non-isolated contexts: 100 microseconds" and "Resolution in isolated contexts: 5 microseconds". The page does not say why; the usual reason (timing attacks on caches) is general knowledge, **unverified**. |

**Read in the QEMU sources (v11.1.2, on this computer):** `target/arm/helper.c` `gt_recalc_timer` (the comparison is done "in unsigned 64 bit arithmetic", the status is recomputed whenever a register is written), `target/riscv/time_helper.c` (a compare written "in the past" raises the interrupt at once; a compare of all ones is treated as "never" because the counter would wrap and the level would fall again after one tick), `hw/intc/riscv_aclint.c`, `hw/intc/apic.c`.

**Not read or not available:** the HPET (QEMU `hw/timer/hpet.c` exists but I read no HPET specification; kept out of the conclusions); Linux's policy for user access to the counter (unverified); the Arm Architecture Reference Manual text of the timer registers (only the guide and QEMU's implementation); the seL4 reference manual's own text on the timer (the repository's earlier review quotes "will overflow the timer" and "tickless"); the PDP-11 handbook is OCR text, so bit-diagram positions are taken from the table of bits, not the figure.

## 3. The design, point by point

### 3.1 Where the registers live: system registers

*What it is.* `MFSR TIME`, `MTSR TIMECMP`, in kernel mode.
*Choices compared.* (a) **Device page** (today's QEMU model; RISC-V ACLINT; the KW11 at a fixed bus address; HPET). (b) **System registers** (Arm's `CNTVCT`/`CNTV_CVAL`, RISC-V's `time`/`stimecmp`, x86's `TSC_DEADLINE` MSR).
*Holes it closes.* (1) A page that a kernel can map into a user program by mistake gives that program a clock; a register cannot be mapped. (2) The guest's offset has to be applied inside the core, because a bus device does not know which core or which guest is asking (the review's hole H7); a register read is already the core's own. (3) The hypervisor does not have to protect one more device page in stage 2. (4) The model needs no per-core bus page (the hypervisor design flagged that QEMU might not support one: "unverified"). Arm, RISC-V and x86 all moved the *deadline* into registers for the same reason (RISC-V's Sstc says it removes "the large overheads" of calling machine mode).
*Speed.* A register read is an instruction; a device read is a bus transaction that cannot be cached. seL4 reads the time and writes the deadline on kernel entry and exit under its tickless scheduler (my reading of the interface: three calls, section 3.7).
*Fewer instructions.* None added: `MFSR` and `MTSR` exist.
*What we lose.* The old timer page was readable by any software that had it mapped, including a future device-style user of the clock; that is the point. Another loss: a timer that is part of the platform description (the memory map) is now part of the architecture, so a machine cannot leave it out. It can: with the machine's `TIMECMP` never written the core simply has no interrupts.

### 3.2 One counter for the machine, read only

*What it is.* A single 64-bit counter, shared by all cores, that starts at 0 at machine reset and only counts up. Reading `TIME` on any core gives the same count (Arm: "broadcast to all the cores", RISC-V: "can be shared between multiple cores").
*The cross-core rule* (mine, not copied): if core B reads `TIME` after core A's read has finished and B knows it (by a lock or an interrupt), B's value is not less than A's. An implementation that distributes the counter to cores must meet this.
*Holes closed.* (1) **Unwritable:** RISC-V's `mtime` is "read-write", and a counter that software can set can go backwards, so every user of time must defend against it; ours never moves except forward. A guest's time moves only through `VTOFF`, which only the hypervisor can write. (2) **A per-core counter** would give each core its own time; with the kernel's migration between cores a deadline moved from one core to another would mean a different time. (3) **No ordering instruction needed:** Arm says reads of its count "can be made speculatively", so an `ISB` is needed; the pdp64's first implementations are in order and do not speculate (manual 7.5.4), so `MFSR TIME` is ordered by construction. An out-of-order core must keep that (the manual already says the same for the side channels).
*What we lose.* Setting the wall clock cannot be done by writing the counter; the kernel keeps its own "wall time = counter + offset" (this is what Linux does anyway; general knowledge, unverified here). A machine that wants the counter set at boot (to a battery clock's value) cannot; it would use the same offset.

### 3.3 Frequency: fixed in the architecture, 10 MHz

*What it is.* The counter counts 10,000,000 ticks a second, always. There is no frequency register and no device-tree entry for it. One tick is 100 ns.
*Holes closed.* The frequency is something firmware must write on Arm (`CNTFRQ_EL0`: "not populated by hardware") and something the platform must report on RISC-V; the Linux binding itself has a workaround for "broken firmware which does not configure CNTFRQ on all CPUs". A constant cannot be left unset or wrong, so a kernel needs no code to find it and a guest cannot be told a different rate by a hypervisor that forgot. Arm itself moved to a fixed 1 GHz from Armv8.6.
*Why 10 MHz.* It is the rate the model and the manual's tests already use; ten ticks make a microsecond, a whole number, so "microseconds to ticks" (which seL4 needs: it converts its worst-case run time) is a multiplication; it lasts 58,454 years in 64 bits. Faster has no use here: 1 GHz wraps after 584 years in 64 bits and gives a finer clock to anyone who can read it.
*Table (computed).* At 10 MHz: 32 bits wrap after 429 s (7 minutes), so a 32-bit counter is out; Arm's 32-bit `TVAL` can reach at most 214.7 s ahead; 64 bits: 58,454 years.
*What we lose.* A machine cannot choose a finer or coarser tick, and a real chip must make 10 MHz from its crystal. If a later machine really needs finer, it needs a new register (reserved number 18 to 23 is room). I recommend accepting the loss.

### 3.4 Width and wraparound

*What it is.* 64 bits for the counter and the comparator. Comparisons are unsigned.
*Wrap.* The real counter will not wrap in practice (58,454 years). The guest's counter (real minus `VTOFF`, modulo 2^64) is fine as long as the hypervisor sets `VTOFF` so the guest's time starts near what the guest expects; a negative offset (a guest moved to a machine whose counter is behind) is a large `VTOFF`, as RISC-V's "large values ... may be used to represent negative time offsets" says, and the guest's count is still a small number. So I do not make the subtraction saturate (that would break such a move).
*Hole closed.* The all-ones value is defined as "never" in hardware (3.5), so a deadline that software "disarms" with the largest value does not fire when a counter happens to reach all ones: RISC-V's own QEMU model has a special case because of exactly this.
*What we lose.* The last tick of the 58,000 years cannot be a deadline.

### 3.5 The deadline: absolute, one register, all ones means never

*What it is.* The comparator holds a counter value. The condition is "counter >= `TIMECMP` and `TIMECMP` is not all ones". `TIMECMP` resets to all ones.
*Compared with a down-counter (Arm's `TVAL`).* A relative write (`TVAL`) is "now plus this many ticks", computed by the hardware at the write.
*Holes closed by the absolute form.* (1) **Missed deadline:** a deadline already in the past fires at once (the level is true), so a late write is never lost; a down-counter write of a small value can also not be lost but a down-counter has no way to say "at 12:00:00.000" after the code was delayed. (2) **A short reach:** `TVAL` is 32 bits, 214.7 s at 10 MHz; the comparator reaches the whole 64 bits. (3) **Drift in a periodic tick:** next = previous deadline + period never accumulates the delay of the handler; a relative re-arm loses the time between the interrupt and the write each period (my reasoning). (4) **The read and the write do not race for correctness:** between `MFSR TIME` and `MTSR TIMECMP` time may pass, so the deadline is slightly later than intended but never lost or wrapped; that is the cost, not a hole. (5) **seL4's own interface is absolute** (`setDeadline`, "absolute and may be slightly in the past").
*Hole closed by one register.* With an enable bit and a compare (the current device, Arm's `CTL` and `CVAL`, x86's separate local-APIC entry and deadline), arming takes two writes and a stale compare in the past plus a late enable gives a surprise interrupt; ordering rules and barriers exist to manage it. One register has no in-between state: disarm, arm and re-arm are each one write. No pending bit is needed either: the question "is it due" is `TIME >= TIMECMP`, and the interrupt itself is the pending state.
*What we lose.* (a) The write needs a counter value in a register, so arming from nothing is a read, an add and a write (three instructions) where a relative write would be one; seL4 already has the time in hand (it computes the deadline itself), so it pays nothing; I do not add a relative alias because it would be a second way to do one thing (see decision 5). (b) You cannot disable the timer and keep its deadline for later; you write the deadline again. (c) Disabling needs a register that holds all ones (one move). (d) The timer cannot be masked on its own; its interrupt is masked by priority (`SPL`) like every other interrupt.

### 3.6 The interrupt: level, cleared by writing, immediate

*What it is.* While the condition is true the core's timer line is asserted at **level 6, vector 32** (unchanged). A **level** interrupt means "asserted while the condition holds", as Arm and RISC-V do; an **edge** is a single pulse that can be lost. Software clears it by writing a later deadline (or all ones). The line is the core's own, not a bus line shared with other cores.
*Hole closed (the rule I add).* **A write to `TIMECMP` takes effect before the next instruction:** an interrupt taken after the write is never for the deadline the write removed. RISC-V allows the opposite ("eventually, but not necessarily immediately", so a spurious interrupt after re-arming); x86 documents "race conditions may result in delivery of a timer interrupt associated with the original deadline"; seL4's Arm driver puts an instruction barrier after its acknowledging write so the line falls before the interrupt controller is told. In an in-order core with the line computed from the register, this costs nothing; in a more complex core the pending latch is cleared by the write (a few gates).
*A level cannot be lost.* An edge that arrives while interrupts are masked and then cleared is gone; a level stays until software acts, so a missed tick shows as an interrupt that arrives late, not as a silent loss. The PDP-11's KW11-P could lose a tick and only reported it in an error bit; its simple KW11-L kept the "monitor" bit set until the program cleared it, which is the level form.
*What we lose.* A handler that forgets to write a new deadline is re-entered at once, forever (a storm); that is visible and safe (it only hurts that core's level-6 work), and the seL4 handler writes the deadline anyway. The model today already behaves as a level.

### 3.7 One-shot, not periodic; what seL4 needs

*What it is.* One deadline, once. Periodic = the handler writes `deadline + period`.
*What seL4 asks.* In its tickless scheduler configuration (the "mixed-criticality" extension, MCS) the machine layer has three functions: read the current time, set the next deadline (absolute, in the past is allowed and fires at once), acknowledge the deadline interrupt. On the pdp64: `MFSR TIME`; `MTSR TIMECMP`; `MTSR TIMECMP` with all ones (exactly what seL4's Arm driver does to acknowledge). Each is one instruction beside a register load. A fixed tick for a periodic non-MCS kernel is the same code in a loop. The earlier seL4 review also found the timer "wide enough not to overflow the timer" to be a requirement: 64 bits at 10 MHz is 58,454 years.
*Holes closed.* A periodic mode needs a reload register and a mode bit, and then the "second tick before the first was handled" case which the KW11-P reports in an Error bit and x86's periodic mode silently coalesces (I only read that the x86 timer has the mode; its overrun behaviour I did not read). No periodic mode means no such case.
*What we lose.* A kernel that wants a plain 100 Hz tick takes an add and a write per tick (two instructions in the handler). Tickless is the decided direction (manual 5.7.1).

### 3.8 The guest's timer: registers, with two comparators

*The question the owner has not decided* (the MMU review proposed registers; the hypervisor design chose a core-local page): see decision 1. This section is the registers form.

*What it is.* There are **two comparators per core, both always running**: the *real* one (the hypervisor's own, compared with the real counter) and the *guest's* one (compared with the real counter minus `VTOFF`). The names `TIME` and `TIMECMP` mean *the timer of whoever is running*:

* at the hypervisor level (`H` = 1, or a machine without the hypervisor at all): `TIME` is the real counter; `TIMECMP` is the real comparator; its expiry is the physical level-6 interrupt (vector 32). A physical interrupt always exits a guest to the hypervisor (the existing rule), so the hypervisor's tick keeps working while a guest runs.
* in a guest (`H` = 0): `TIME` is real minus `VTOFF`; `TIMECMP` is the guest's own comparator; its expiry sets bit 6 of `VIRQ` once each time it is armed (the owner's accepted rule), and the guest takes it as virtual line 6, vector from `VIVEC`.
* `GTIMECMP` (number 148, hypervisor level only) is the guest's comparator as the hypervisor sees it: the hypervisor writes it before `GENTER` and reads it after an exit, exactly as it uses `GEVA` and `GECAUSE` for the guest's exception registers.

*Arm and RISC-V compared.* Arm has separate registers (`CNTV_*` for the guest, `CNTHP_*` for the hypervisor) and a hypervisor-controlled bit lets the guest read the real count; RISC-V has `vstimecmp` and `htimedelta`. Same idea. The difference here is that the guest's `TIME` offers **no way** to read the real counter, so there is no trap bit the hypervisor must remember to set, and the same guest kernel code that runs on bare metal runs unchanged (same register numbers, same handler).
*Holes closed.* (1) The leak of the host's time to a guest: there is no read of the real counter at `H` = 0. (2) The which-core and which-guest problem of the page (hole H7). (3) A guest cannot arm the real comparator to stall the hypervisor: it cannot reach it. (4) The guest's expiry can only ever set the line of the guest that is loaded, because the comparator and `VIRQ` are loaded together by the hypervisor: a guest that is switched out has its deadline in memory, and the hypervisor handles it with its own comparator (the way a hypervisor must).
*World switch (rule).* Before `GENTER` the hypervisor loads `VTOFF`, `GTIMECMP`; after an exit it saves `GTIMECMP` (and keeps `VTOFF`). While the hypervisor runs (`H` = 1) the guest's comparator keeps running; its expiry sets bit 6 of `VIRQ`, which is delivered at the next guest entry (the existing accepted rule: no virtual line is delivered while the hypervisor runs). If the hypervisor does not want that, it writes `GTIMECMP` all ones after the exit.
*Reset (the reset table).* Machine reset: both comparators all ones, counter 0. **Guest reset** (an operation the hypervisor performs): `GTIMECMP` all ones, `VTOFF` set so the guest's counter starts where the hypervisor wants (for a new guest: real counter at that moment, so the guest's time starts near 0), bit 6 of `VIRQ` clear. The table's old row ("compare 0, enable clear") is replaced by the one row `GTIMECMP`: all ones (also fixes the difference of section 1).
*Fewer instructions / speed.* A guest's time read and deadline write cost no exit and no hypervisor code; the hypervisor's world switch adds two register moves (and one read to save) per guest.
*What we lose.* (a) A new hypervisor-block register (148). (b) The names `TIME`/`TIMECMP` mean different hardware at `H` = 0 and `H` = 1, like the other ordinary registers in the hypervisor design, and the manual has to say so once. (c) A hypervisor that wants to **trap** a guest's timer to emulate it (record-and-replay, or a nested hypervisor) has no bit for that; I propose none because no case needs it yet; it can be added to the trap-control register later if one does. (d) `HVE` clear: `GTIMECMP` is an illegal instruction, and `TIME`/`TIMECMP` are the real timer (VTOFF counts as 0).

### 3.9 How the guest's timer interrupt reaches the guest

*What it is.* Unchanged from the accepted virtual-line design: at expiry the hardware sets bit 6 of `VIRQ`; between instructions, a guest takes the highest pending virtual line above its priority, the hardware clears the bit when it delivers, the vector is the guest's `VIVEC` field for line 6 (a vector below 32 is refused when written).
*Difference between the physical and the virtual timer, stated honestly.* The real timer is a level (stays until the deadline is written); the guest's is **once each time armed** (the owner's recorded answer), because its path is the virtual-line bit, which the hardware clears on delivery. For a correct handler (which writes the next deadline) they are the same. For a handler that forgets, the real one storms and the virtual one goes quiet; neither hurts anyone but that guest. The alternative is to make the guest's line 6 a level too (decision 7).
*What we lose by keeping "once":* the guest sees a different failure mode from bare metal for the forgotten-rearm bug.

### 3.10 The hypervisor's own timer

It is `TIMECMP` at the hypervisor level: the real comparator, always running, interrupts as physical level 6, vector 32, entering the hypervisor at priority 7 as today. With the hypervisor level run like a kernel with its own translation (the owner's choice of the Arm VHE style), the hypervisor's kernel uses the same two registers and the same handler shape as a kernel, with no special case. Multiplexing many guests' deadlines onto the one real comparator is the hypervisor's job (set `TIMECMP` to the earliest of the descheduled guests' deadlines).

### 3.11 What a user program may know of time

*What it is.* **No unprivileged instruction reads a clock** (unchanged; manual 6.14.2). `MFSR` is privileged, so user mode cannot read `TIME`, and the old device page is gone, so a mapping mistake cannot give a user program a clock.
*What other designs do.* All three let the kernel allow user reads: Arm by `CNTKCTL_EL1` bits, RISC-V by the `TM` bit in `mcounteren` and `scounteren`, x86 by `CR4.TSD` clear (all read, section 2). All three have the user read the full-resolution counter.
*What is safe.* Reading a clock gives a program a stopwatch for cache and translation-buffer timing; the owner's requirement is "no timing-channel attacks" (`docs/hardware-vulnerabilities.md`). Coarsening the clock (browsers: 100 microseconds, or 5 in isolated pages, section 2) raises the cost of an attack, but a program can build its own clock by counting in a spare thread (general knowledge; unverified here), so coarsening is **a brake, not a wall**. The real protection on this machine is that the cores are in order and do not speculate, that no cache or translation buffer is shared between mutually untrusting programs without the kernel's control, and that the secure-mode core uses data-independent timing.
*Recommendation (by construction).*
1. Keep: no unprivileged instruction reads the counter. A system call gives the time (cost: a trap, a few hundred cycles; I have not measured it).
2. For programs that read the time very often (the point of Linux's vDSO, a kernel-supplied code page, general knowledge), the kernel keeps a **read-only page** with a time value and the offset to the wall clock, updated when the kernel runs; a user load reads it at the cost of one load. Its resolution is whatever the kernel writes, by design coarse; the page holds nothing finer than what the kernel decides. A tickless kernel updates it at each kernel entry (so it can be stale between entries; that is the intended coarse clock).
3. If a user-readable clock is ever added (for example `RDTIME` as a new unprivileged instruction), fix the rule now so it closes by construction: **off at reset; enabled by one kernel-set bit; and the hardware rounds the value it returns by a kernel-set "granule" field that resets to the coarsest**, so that a kernel that forgets leaves the safest setting. The reserved system register **18, `TIMEUSER`**, holds that bit and field; it is not defined now (an unassigned number stays an illegal instruction). A guest would have it too, with the hypervisor able to force it to a coarser value. Hardware cost of the rounding: about 305 NAND2 gate equivalents for a 64-bit mask with a 6-bit granule (counted, section 6).
*What we lose.* An unprivileged read costs a system call (a trap and return; not measured), and the coarse page is not a precise timer for user benchmarking. A program that needs a precise cycle count for profiling has to use a kernel service or the performance counters (section 3.12).

### 3.12 Room for the watchdog and the performance counters

The watchdog and the performance counters are open (manual appendix J, item J.6.11); I do not design them. The room left: numbers **18 to 23** next to the timer for a **watchdog comparator** that would have the *same shape* as `TIMECMP` (an absolute deadline against `TIME`, all ones off) with its own interrupt level (a higher one, or a reset): a programmer who knows the timer knows it. Numbers **24 to 31** for **performance counters**, which are a different kind of register (event counts, not time) and must not be mistaken for the time. A watchdog must be one that the kernel cannot be tricked into disabling, which is a policy for J.6.11 (for example write-once until reset); I do not claim it.

### 3.13 The register numbers

Checked against the system-register grammar (`41-sysreg.hbnf`: 0 to 12 and 128 to 147) and the hypervisor block (`52-hypervisor-v1.hbnf`, which adds only constants, not numbers):
* **13** is the leaning for `KTBR` and, with it, `MMUINFO` (MMU review decision 10, still open). I keep 13 to 15 out of this proposal.
* **`TIME` = 16, `TIMECMP` = 17** (a group of eight, 16 to 23, so a decoder can recognise "timer group" from the top bits; this is a convenience, not a requirement).
* **`GTIMECMP` = 148**, the next number after the hypervisor block's last (`GUDP` = 147); 148 to 255 are free.
* `TIME` is read only (a write is an illegal instruction, as for `EVA`, `ECAUSE`, `CPUID`); `TIMECMP` and `GTIMECMP` use every bit (no reserved bit, so the rule "refuse a write of a one to an unused bit" has nothing to refuse).
* The assembler and the generated tables take numbers up to 147 with no change (errata, the hypervisor implementation note); I read this, I did not regenerate.

### 3.14 Gates (counted, and estimated)

Method: the repository's, `tools/gates` (yosys 0.52 style flow of `gates.sh`: synthesise, map to NAND2 and inverters; count = NAND2 plus half an inverter; a flip-flop is counted apart and as 6 NAND2 in totals). **Reference reproduced first:** my run of `gates.sh` on `blocks.v` gave `add64` 660, `add32` 322, `add48` 494 NAND2 equivalents, identical to the recorded `tools/gates/vec-silicon-blocks.tsv`. The timer blocks are in a scratch file (not committed; the Verilog is simple enough to restate: a register with a reset value, an unsigned `>=`, a subtract).

| Block (counted by synthesis) | NAND2 equivalents of logic | flip-flops |
|---|---|---|
| counter, 64 bits, increment on a tick | 283 | 64 |
| unsigned compare `a >= b`, 64 bits | 490 | 0 |
| all-ones detect, 64 bits | 94 | 0 |
| real comparator: register (reset all ones), compare, "not all ones" | 565 | 64 |
| for comparison, the old shape: register, compare, enable flip-flop | 485 | 65 |
| guest comparator: subtract, register, compare, "not all ones", the "armed" flip-flop that makes it fire once | 1,063 | 65 |
| `TIME` read: real counter, or real minus `VTOFF` by `H` | 851 | 0 |
| user rounding (clear the low *g* bits, *g* of 6 bits) | 305 | 0 |

*Estimated from those (not counted as one block):* per core, logic about 565 + 1,063 + 851 − 660 = **1,819** (one subtractor serves both the `TIME` read and the guest comparator: that sharing is my assumption), flip-flops 129 (two comparators, one armed flop; `VTOFF`'s 64 flops are already in the hypervisor design) = 774 gate equivalents, total about **2,600 NAND2 equivalents per core**. The machine's counter: 283 plus 384 for flip-flops, about **670**, **plus a prescaler** that makes 10 MHz from the core clock, which I did **not** count (an estimate: a small counter and a compare, under 200). The scalar core is estimated at 220,000 to 310,000 (`vec-gates.md`), so a core's timer is **about one percent**. The old shape (a three-register device) is not cheaper by the counted blocks: dropping the enable and pending bits saves no gates and costs about 80 for the all-ones detect; its value is safety, not area. Not counted: the register-select decode, the line into the interrupt logic, wiring, the hypervisor's `VIRQ` set. The counted figures are of single blocks synthesised alone; a whole core's layout and timing (the speed of a 64-bit compare against the clock rate) were **not** examined.

### 3.15 What changes in the model, the executor, the tests and the manual

* **Grammar:** `41-sysreg` gains `time` 16 (read only), `timecmp` 17, and `gtimecmp` 148 (hypervisor block); `50-system-v1` loses `timer-reg`, `timer-ctl` and the `timer` and `vtimer` map pages (`timer-clock hz` stays, as the architecture's constant), and keeps `timer`@32 and `irq-level timer`@6.
* **Executor** (`common/pdp64exec.c`, shared by `sim64` and QEMU): a core field for each comparator and the guest's "armed" flag; cases in the `MFSR`/`MTSR` switch (`TIME` read through a host hook for the counter; a write to `TIMECMP` or `GTIMECMP` through the existing `hv_event`-style hook so the host re-evaluates the interrupt before the next instruction); `HVE` clear makes `GTIMECMP` illegal; `TIME` write illegal; the guest's `TIME` is real minus `VTOFF`. `sim64` has no clock today (not read beyond a search): it needs a defined one (a proposal to decide later: one tick per instruction, so tests are deterministic).
* **QEMU model:** delete the two bus devices (`timer.c`, `vtimer.c`) and `MAP_TIMER`/`MAP_VTIMER`; one counter in the machine (the virtual clock at 10 MHz, as now) and a `QEMUTimer` for each comparator in the CPU, whose callback sets line 0 (vector 32) or `VIRQ` bit 6 (the arithmetic of the present callbacks, including the guard against too-distant deadlines, carries over); the `VTOFF` hook already exists. This also removes the open "core-local page at one address" problem for several cores.
* **Tests:** rewrite `timer.S`, `hv-timer.S`, `hv-vtimer.S` to use the registers; new cases: a deadline in the past fires at once; a write that removes the deadline takes effect before the next instruction (no stale interrupt); all ones never fires, including when the counter is set near the top by `VTOFF` in a guest; acknowledging by writing all ones; `TIME` never decreases and is the same on two cores (a second-core test needs the MMU review's second-core work); a user-mode `MFSR TIME` is illegal; a write to `TIME` is illegal; at `H` = 0 `TIME` equals real minus `VTOFF` and a read of `GTIMECMP` is illegal; `HVE` clear: number 148 illegal; the guest's expiry sets `VIRQ` bit 6 exactly once per write; a guest switched out does not set the next guest's `VIRQ`; the hypervisor's `TIMECMP` still exits a guest at priority 7; a guest reset leaves all ones. Each test should be checked against a scratch change of the model, as the hypervisor tests were.
* **Manual:** 5.7.1 (replace "details pending" with the registers and the rules), the hardclock example near 6.3.7 (it reads a device; it becomes `MTSR TIMECMP`), 6.14.5 (the virtual timer: registers), the reset table of the hypervisor text, the system-register table in 6.3 (three rows), appendix J.5.1 and J.6.3 (the timer part leaves the open list; the controller part stays), and the hypervisor design's timer sections. Every manual change is followed by the manual's build check (the memory rule: a skipped check must not pass silently).

### 3.16 Order of work

1. The owner's answers to section 8.
2. Grammar (`41-sysreg`, `50-system-v1`), regenerate the constants and tables; check nothing else moved.
3. Executor and hooks; `sim64` clock.
4. QEMU: counter, two comparators, delete the two devices; the machine file.
5. Tests: rewrite and add (section 3.15), checked against scratch mutations.
6. The gate run on the final Verilog (the blocks above, in `tools/gates`), and the manual numbers updated from it.
7. Manual text (3.15), then the build check.
8. Errata entry recording the decisions.

## 4. How the design answers the principles

* **Safety:** no clock in a mappable page; no way for a guest to read the real counter; a read-only counter; no half-armed state; a write removes an interrupt before the next instruction; a level cannot be lost; absolute deadlines cannot be missed or wrapped; fixed frequency cannot be mis-set.
* **Speed:** reads and deadline writes are single register instructions, with no bus access and no exit in a guest; the hypervisor's own tick is untouched by a guest.
* **Fewer instructions:** none added; two registers (and one in the hypervisor block); no periodic mode, no relative register, no enable and no status register.
* **In the head:** the PDP-11's clock had one register and two bits, and its programmable clock had three registers with modes. Here: **read the time, write a deadline, write a later one to stop it.**

## 5. What does not follow from the other designs (a bold part)

The bold parts: no enable/status register at all (Arm, RISC-V and the old device keep them); a fixed architectural frequency (RISC-V and older Arm leave it to the platform); one name for "the timer of whoever runs" instead of separate guest and hypervisor registers (Arm, RISC-V keep them separate for the guest); a hard rule that a write takes effect immediately (RISC-V says "eventually"). Each is a minimal change that removes a case, and each can be refused without breaking the rest: decisions 3, 2, 6 and 4.

## 6. Measurements and what is not measured

Measured by me: the gate counts of section 3.14 (and the reproduction of the reference adders); the wrap times (arithmetic). Not measured: the cost of a system call, any speed of a 64-bit compare in a clock cycle, the prescaler, the whole-core effect, the performance of QEMU with a timer per CPU.

## 7. What this reverses of recorded decisions

* **The core-local virtual timer page** of the hypervisor design (choice T2, accepted by the owner with the other 22 decisions, and implemented): reversed if decision 1 is accepted; the page, its provisional address and the vtimer device go. The MMU review had already proposed this as its item A7 and the owner has not answered it.
* **The three-register shape of the machine's timer** (counter, compare, control with enable and pending) in the grammar and in the QEMU device: replaced (decisions 1 and 3). The manual never fixed it (5.7.1 is open), and the model's page is described there as a stand-in.
* **Not reversed:** the level 6 and vector 32; no unprivileged clock (6.14.2); a physical interrupt always exits; the virtual timer's alarm "fires once each time it is armed" (the owner's answer of 2026-11-25) and the rule that no virtual line is delivered while the hypervisor runs; the hypervisor block's numbers 128 to 147 (one number is added, 148); the 10 MHz rate.
* **A change to a stated value:** the reset table's "compare 0, enable clear" for the guest timer becomes all ones (a correction to match the code).

## 8. Decisions for the owner

Answer each "accept / change / not decided". My recommendation is first in each.

1. **Where does time live: in system registers (`MFSR TIME`, `MTSR TIMECMP`), or in a device page (today's model; for the guest, the core-local page)?**
   * *Registers (recommended).* For: nothing to map, protect or place; the guest's offset is applied inside the core; one instruction to read and set; the same shape as Arm, RISC-V and x86 deadlines; removes the open "same address, different core" problem. Against: reverses the accepted core-local page; the machine's timer stops being a device the platform can leave out; the model's two devices are rewritten.
   * *Keep the device pages.* For: nothing to rewrite; a user of ACLINT or HPET would recognise it. Against: a mapping mistake exposes a clock; a bus read costs more and cannot know the core; the several-core page is unbuilt and untestable today.

2. **Is the counter's frequency fixed in the architecture at 10 MHz, with no register that tells it?**
   * *Fixed (recommended).* For: cannot be mis-set or left unset; no code to find it; whole microseconds (10 ticks); 58,454 years. Against: a machine cannot pick another rate; a real chip divides its crystal.
   * *A read-only frequency register (Arm's way).* For: the rate can differ by machine. Against: a register and a rule that someone sets it correctly (Arm's firmware had to; Linux has a workaround for firmware that did not).
   * *Reported by the machine description (RISC-V's way).* For: no register. Against: one more thing the platform must tell, and a guest depends on it being right.

3. **Is the deadline one 64-bit register, absolute, with all ones meaning "never", and no enable or pending register?**
   * *One register (recommended).* For: arming and disarming are one write; no state in between; the interrupt is the pending state; fewest registers. Against: the last tick of 58,000 years cannot be a deadline; the deadline cannot be parked while the timer is off; the all-ones detect costs about 80 gates.
   * *Compare plus control register (today's model; Arm's shape).* For: a parked deadline; a status bit to poll. Against: two writes to arm and an in-between state.
   * *Relative down-counter (Arm's `TVAL`).* For: arming from nothing is one write. Against: 32-bit reach (214.7 s), drift in periodic use, not what seL4's interface is.

4. **Is the interrupt a level, cleared by writing a later deadline, and does a write take effect before the next instruction?**
   * *Yes (recommended).* For: cannot be lost; no spurious interrupt for a removed deadline (the holes of RISC-V's "eventually" and x86's stated race). Against: a handler that forgets the write storms (visibly); a more complex core must clear its pending latch on the write.
   * *Level, but allow the delay (RISC-V's rule).* For: easier for an aggressive implementation. Against: every handler must tolerate a spurious interrupt.
   * *Edge, self-clearing (x86's deadline register zeroes itself).* For: no acknowledge write. Against: an edge can be lost when masked; needs a feedback path from the interrupt taker to the timer.

5. **One-shot only: no periodic mode, and no relative-write alias?**
   * *One-shot only (recommended).* For: the one thing seL4's tickless scheduler uses; periodic is an add and a write; no mode, no reload register, no missed-tick case (the KW11-P's Error bit). Against: a 100 Hz kernel spends two instructions a tick; arming from nothing is read, add, write.
   * *Add a write-only relative register (arm for N ticks from now, saturating at "never").* For: one write to arm from nothing; closes the read-then-write delay. Against: a second way to do one thing; seL4 does not use it; one more register to test.
   * *Add a periodic mode.* For: no handler work. Against: mode and reload state, a missed-tick case, a second interface.

6. **The guest timer: two comparators, `TIME`/`TIMECMP` meaning "the timer of whoever runs", one new hypervisor register `GTIMECMP` (number 148)?**
   * *Yes (recommended).* For: the guest cannot read the real counter or arm the hypervisor's comparator; the same guest kernel code as on bare metal; no trap bits; the hypervisor's tick runs during a guest. Against: one more hypervisor register; the same names mean different hardware at `H` = 0 and `H` = 1; no way to trap a guest's timer for emulation (can be added to the trap-control register if a case appears).
   * *Arm's way: separate guest and hypervisor registers, and a bit that lets the guest read the real count.* For: the known layout. Against: a bit to get right; more register numbers.
   * *One comparator, the hypervisor multiplexes in software.* For: least hardware. Against: a guest's deadline write exits (the thing "in hardware" was chosen to avoid).

7. **Virtual line 6 for the guest's timer: keep "fires once each time it is armed" (the recorded answer), or make the guest's line 6 a level like the real one?**
   * *Keep once (recommended: it is the owner's answer of 2026-11-25).* For: uses the virtual-line bit exactly as for any virtual device; delivery clears it. Against: a handler that forgets to re-arm behaves differently from bare metal (quiet, not a storm).
   * *Level.* For: identical behaviour to bare metal, so one kernel handler is tested once. Against: reverses the recorded answer; the line then has two sources (the comparator and the hypervisor's own injection) and "delivery clears the bit" no longer clears the timer's part.

8. **One counter for the whole machine, read only, reset to 0 at machine reset only, with the rule that a read after another core's finished read is not smaller?**
   * *Yes (recommended).* For: no migration problem; cannot go backwards; same as Arm's system count and RISC-V's shared `mtime`. Against: the counter cannot be set (the kernel keeps an offset for wall time); an implementation that distributes the counter must keep the rule.
   * *A counter on each core.* For: no distribution problem. Against: a deadline moved between cores means a different time.

9. **User programs and time: keep "no unprivileged clock"; the kernel publishes a coarse read-only time page; and fix now the rule for a future gated clock (off at reset, one kernel-set bit, hardware rounding to a kernel-set granule that resets to coarsest, in reserved register 18)?**
   * *Yes (recommended).* For: no clock for a program by default; the rule is set before anyone asks; a forgetful kernel is safe. Against: a precise timestamp needs a system call or the kernel page (coarse); the rounding costs about 305 gates if it is ever built; coarsening is only a brake against a program that builds its own clock.
   * *Add a gated unprivileged `RDTIME` now, as Arm and RISC-V allow.* For: fast precise timestamps. Against: a new instruction before a measured need; it is the timing channel the owner wants to avoid.
   * *Leave it to the kernel with no hardware rounding.* For: simpler. Against: a kernel that forgets leaves a fine clock.

10. **Register numbers: `TIME` 16, `TIMECMP` 17, `GTIMECMP` 148; 13 to 15 left for the MMU registers; 18 to 23 free in the timer group; 24 to 31 free for the performance counters?**
    * *Yes (recommended).* For: clashes with nothing named anywhere; leaves room for the watchdog and the counters. Against: a reservation of 14 numbers that may never be used (the space has 115 free below the hypervisor block).
    * *Take the next free numbers, 13, 14, 15.* For: compact. Against: collides with the open `KTBR` and `MMUINFO` leaning.

11. **The simulator `sim64` needs a counter: one tick per instruction (deterministic tests)?** *(A small question; I did not read `sim64`'s structure.)*
    * *Instruction count (recommended).* For: tests give the same result every run. Against: time does not pass during a wait, so a `WFE` with a deadline must jump the counter to the deadline.
    * *The host's real clock.* For: nothing special. Against: tests depend on speed.

12. **The order of work of section 3.16 (grammar, executor, QEMU, tests, gates, manual, errata), starting only after these answers?**
    * *Yes (recommended).* Against: nothing is built until the owner answers.
    * *Build the register form in a branch first and measure.* For: the answer to decision 1 comes with working code. Against: work thrown away if refused.

## 9. Sources read (all on 2026-11-25 unless stated)

Arm, "Learn the architecture - Generic Timer" 1.3 (and version 1.0, same text for the points used); the Linux device-tree binding for the Arm architected timer; RISC-V privileged specification (`machine.adoc`, `hypervisor.adoc`, `sstc.adoc`, `csrs.adoc`, main branch); the RISC-V ACLINT specification 1.0-rc4; Intel SDM 325462-093US volume 3A chapter 13 and the register-4 text; DEC PDP-11 Peripherals Handbook 1976 (KW11-L, KW11-P, address list); seL4 `include/machine/timer.h` and `include/drivers/timer/arm_generic.h`; MDN `Performance.now()`; QEMU 11.1.2 sources named in section 2; in the repository the manual (5.7, 6.2, 6.3, 6.14, 7.5, 7.10, appendix J), the errata on the hypervisor and the audit (186, 195, 196, 198, 202, 204, 205), `hypervisor-design.md`, `best-of-breed-mmu-virt.md`, `sel4-fit.md`, `sel4-on-the-pdp64.md`, `vec-gates.md`, the grammar parts, `common/pdp64exec.c` and `.h`, and the QEMU timer and virtual-timer devices. Downloads were made one at a time with at least ten seconds between loads from a host, into a temporary directory that is deleted afterwards; no captcha or block was met.
