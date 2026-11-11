<a id="j71"></a>
### J.7.1 The wake rule of WFE and the idle loop

**Issue.** `WFE` (wait for event) puts a core to sleep until another core executes `SEV` (send event) or an interrupt arrives (7.10.1). The idle loop of a kernel checks the run queue and then sleeps; if an interrupt arrives between the check and the sleep, it queues work, returns, and the core sleeps with work waiting (a *lost wake-up*, an event that arrives in the gap between the test and the sleep and is never seen). The PDP-11's V7 kernel had the same gap and a clock tick repaired it within one tick. A core that takes no periodic tick has no repair. The question is what ends a `WFE` sleep. The author decided (2026-10-22: "Yes, wake on pending") that `WFE` ends its sleep when an interrupt is pending even if the priority masks it, so that the idle loop is `SPL #7`, check for work, `WFE`, `SPL #0`, with no gap (7.10.2). What is open is the rest of the wake rule: whether `SEV` is sticky for one wait, and whether other events also end the sleep (options 2 to 5).

**Why it matters.** The idle loop of every kernel, and the port's `cpu_idle_cycle`, depend on it. A lock waiter that could sleep instead of spinning would save memory bandwidth on 16 cores, and the answer decides whether an unlock must execute `SEV`. A wrong rule is a hang that occurs once a week.

**Options.**

1. *The decided rule alone, with `SEV` sticky for one wait.* The loop is `SPL #7`, test, `WFE`, `SPL #0`. For: closes the gap with no new instruction; two rules in the core. Against: none beyond the decided rule: a core wakes for an interrupt it will not take until the level drops (it then takes it, as intended).
2. *Option 1, and `WFE` also ends when the reservation of a preceding `LL` is lost.* A spin wait becomes `LL r, lock; test; WFE`; the holder's ordinary release store wakes the waiter, and the unlocker executes no `SEV`. For: unlock stays one store; a waiter costs no bus bandwidth. Against: the reservation must stay armed while the core sleeps; a spurious wake is allowed, so the loop re-reads; the reservation rules (7.4.1) must say that the reservation survives the sleep.
3. *`WFE` takes a priority operand.* One instruction lowers the level and sleeps. For: no `SPL` around it. Against: a new operand form to encode; no gain where the loop is already two instructions.
4. *A timeout form with a deadline.* For: a waiter cannot sleep forever if the wake source breaks; the secure core's bounded waits. Against: an operand; a deadline needs the timer.
5. *No `WFE`; poll with the `HINT` pause.* For: nothing to specify. Against: burns power and bandwidth, and on an FPGA a spinning core takes the memory bandwidth the other cores want.

**Precedents.** ARM's `WFE` ends on `SEV`, on an interrupt and on the clearing of the exclusive monitor, which is how a lock waiter sleeps until the holder's store *(unverified: general knowledge)*. RISC-V's `wfi` ends when an interrupt is pending and enabled in its own register whatever the global enable says, and may be a no-op; `Zawrs` adds a wait on a reservation *(verified in the repository's notes)*. x86 has `HLT` after `STI` (the instruction after `STI` cannot be interrupted, which makes the pair safe) and `MONITOR`/`MWAIT` on a cache line *(unverified)*. V7's idle routine lowered the priority and executed `wait` in a loop *(verified in the repository's notes)*. OpenBSD's riscv64 idle is `intr_enable(); wfi` with a comment that doubts it *(verified)*.

**The author's referents.** "main cores tickless"; no system named for the idle loop.

**The assistant's leaning.** Option 2, which contains option 1: a lock waiter sleeps without an `SEV`.

**Where the body refers to it.** Sections 6.11 and 7.10.2.

<a id="j72"></a>
### J.7.2 Coherence beyond four cores

**Issue.** The first device has four cores that snoop (every cache watches the others' writes) with three states, modified, shared and invalid (7.6.1), and the architecture supports at least four cores, with sixteen or more as the preferred ceiling (7.6.3, errata 92). The protocol that serves more than four coherent cores has not been chosen. The architecture promises that memory is coherent and sequentially consistent (7.5.1) and says nothing of the protocol. The statement as first written: the protocol for more than four coherent cores is open; the leaning of the SMP decisions is MESI with a snoop filter inside clusters of four and a directory between clusters. *(P)*

**Why it matters.** The number of general cores sets the size of the cache controller, the FPGA that can hold the design (about 16,000 look-up tables for a core before coherence, by a paper estimate at plus or minus 40 percent; four cores fit a Kria-class board and none of the planned boards holds sixteen), and what the kernel's scheduler sees as a group. Also the line size (64 bytes), the reservation granule and the invalidate granularity hang from it.

**Options.**

1. *Keep three-state snooping for two to four cores and say so.* For: smallest; fits the first device. Against: breaks the target of sixteen or more cores; snooping traffic grows with the cores.
2. *MESI within clusters of up to four cores, a snoop filter at a shared second-level cache, and a directory between clusters.* MESI adds an exclusive state, so a write to a clean line that nobody else holds needs no bus transaction. For: four cores are one cluster and nothing is wasted; the ceiling is reached by adding the inter-cluster layer. Against: two protocols; the directory is where protocol deadlocks hide.
3. *A flat directory.* One home place per line and a bit-vector of sharers. For: simplest to reason about; scales to 64. Against: two hops for the common case, which is more than a four-core machine needs.
4. *No coherence between clusters; explicit cache operations.* For: cheapest to scale. Against: every missing flush is a race that reproduces once a week; it weakens sequential consistency to "within a cluster".

**Precedents.** PDP-11/70 caches were kept coherent by write-through and invalidation on DMA writes *(unverified: from memory)*. Bus-snooping multiprocessors (Sequent, Sun Enterprise) stopped near 16 to 64 processors *(unverified)*; directory machines (Stanford DASH, SGI Origin) scale by messaging the sharers *(unverified)*; x86 uses snoop filters inside a die and directories across sockets; ARM's coherent interconnects use filters or directories *(unverified)*.

**The author's referents.** "4 cores minimum, 16 or more preferred"; "for initial device 4 cores is enough hopefully that fits on the fpga".

**The assistant's leaning.** Option 2 as the direction, built in two steps: one cluster of four cores first, with the shared cache designed so a directory can be added; the architecture text says "coherent, sequentially consistent, line size 64 bytes" and nothing of the protocol, so more cores are an implementation and not a change.

**Where the body refers to it.** Section 7.6.4.

<a id="j73"></a>
### J.7.3 The operands of the atomic instructions

**Issue.** The atomic words (7.3.1) take three register fields in the grammar (four for `CAS`), with the address in a register and the size in the sub-opcode. The roles of the registers, the size encoding of `CAS` and any displacement are not fixed in the text. The statement as first written: the operands of the atomic words sit in three register fields (four for `CAS`), the roles are not fixed, and the study leans to fixing three register fields now, with the fourth reserved zero. *(P)*

**Why it matters.** The placement decides how many instructions an atomic costs, how many bytes it takes, and what the lock and reference-count code of the kernel compiles to. `CAS` in the four-field form fills the last four-register slots of the encoding.

**Options.**

1. *Register only, address in a register, three fields.* `rd` receives the old value, `rs` is the operand, `ra` holds the address; `CAS` has the expected value in and the old value out in `rd`; the fourth field is reserved zero. For: densest; the simplest address path; a misaligned address is detected at one place. Against: one `LEA` (load effective address) when the address is a structure field at a nonzero offset.
2. *Option 1 and a small scaled displacement in the spare field.* The address is `ra` plus `d` times the size, `d` from 0 to 15. For: removes the `LEA` for the first sixteen words of a structure, where lock owners and reference counts usually sit. Against: uses the spare field; one small adder in the atomic unit.
3. *Full memory operand modes as for loads and stores.* For: indexed atomics. Against: a general address generator in the atomic unit and side effects (auto-increment) that complicate restart after a fault.
4. *`CAS` with fixed registers, as x86.* For: frees two register fields. Against: a fixed register is a permanent constraint on the compiler in a 16-register machine.
5. *Double-width `CAS` as a register pair.* For: lock-free lists with a tag. Against: not needed while a pointer has spare bits to hold a version count.

**Precedents.** RISC-V's `AMO` words take three registers, address in `rs1` with no displacement *(unverified: from memory)*; ARM's large-system atomics take registers; x86 takes any memory operand with `LOCK` *(unverified)*. OpenBSD's mutex is one compare-and-swap on the owner word and its ticket lock one add *(verified in the local source)*.

**The author's referents.** None named beyond the PDP-11 and VAX atomics (`DATIP`/`DATO`, interlocked queue instructions).

**The assistant's leaning.** Option 1 now, with the spare field reserved, and a displacement taken only when the OpenBSD port is compiled and the `LEA` count in front of atomics is measured.

**Where the body refers to it.** Section 7.4.6.

<a id="j74"></a>
### J.7.4 Atomics on uncached memory and on device memory

**Issue.** The read-modify-write atomics are atomic with respect to every initiator, cores and devices alike (7.4.3). That is easy on cached memory, where the cache line is held exclusively. On a page of uncached memory or a device page the access goes to the bus, and a PCI Express transaction has atomic operations (`AtomicOp`) only on devices that choose to implement them. The mapping of the machine's atomics onto the bus is therefore not stated.

**Why it matters.** The rings of every virtio device sit in memory that may be uncached; a program that issues `CAS` on such a word needs either a defined result or a defined fault. The software cannot be silent about it, and a silent non-atomic update is the worst outcome.

**Options.**

1. *Abort.* An atomic to a device or uncached page raises an access fault. For: easy to detect and cheap to build. Against: a driver cannot use an atomic on a shared uncached ring.
2. *Performed at the memory controller (far atomics).* The operation travels to the memory and the result returns. For: constant cost under contention; works for uncached normal memory. Against: the memory side needs an arithmetic unit and a defined form for every word, and a clear rule for the interaction with reservations.
3. *Forwarded as PCI Express atomic operations where the device advertises them, abort otherwise.* For: uses what the bus offers. Against: only compare-and-swap, swap and fetch-and-add exist on the bus; the other words would still abort.
4. *Defined only for cached normal memory, undefined elsewhere.* For: nothing to build. Against: undefined behaviour in a place where a fault would be better.

**Precedents.** PCI Express defines `AtomicOp` for fetch-and-add, swap and compare-and-swap *(unverified)*. AXI5 has atomic transactions performed near the memory *(unverified)*. The PDP-11's `DATIP`/`DATO` pair locked the Unibus for the read-modify-write *(verified in the repository's sources)*.

**The author's referents.** None named.

**The assistant's leaning.** Option 1 for device pages and option 2 or an abort for uncached normal memory, decided with the transport of the bus (errata 80); a fault that is easy to detect is better than a silent non-atomic update.

**Where the body refers to it.** Section 7.4.5.

<a id="j75"></a>
### J.7.5 The reservation granule and how software learns its size

**Issue.** `LL` reserves a granule: a naturally aligned piece of memory of a size the implementation chooses, not smaller than 8 bytes (errata 45; 7.4.1). The text leaves the size to the implementation and says that a feature register is to report it (errata 45 lists "granule discovery in the feature registers" as still to write). Nothing says which register, nor what software may assume before it reads it. The size matters to software because two lock words in one granule make an `SC` fail whenever the neighbour is written (false sharing of the reservation), and because a constrained `LL`/`SC` sequence (7.4.2) must not touch the granule between the two instructions.

**Why it matters.** The kernel lays out its lock words and per-CPU structures with the granule in mind (padding a hot lock to a granule costs memory and saves failed `SC`s). The compiler's `LL`/`SC` loops and the C library's allocator need a safe assumption before any feature register is read. The cache controller's reservation tag, one per core, is sized by it.

**Options.**

1. *The granule is the cache line, fixed by the architecture.* One number for every implementation (the line size is itself open, J.7.2). For: software needs no discovery; one rule for locks and for padding. Against: an implementation with another line size cannot conform; it fixes the line size as a side effect.
2. *An implementation choice, reported in a feature register, with a stated minimum of 8 bytes.* This is the text as it stands. For: the implementation is free. Against: portable code must read the register or assume 8 bytes, the worst case for padding.
3. *An implementation choice between 8 bytes and a stated maximum, for example 128 bytes, reported in a register.* For: software can pad to the maximum with no register read; the implementation keeps a range. Against: a maximum is another number to commit to.
4. *A reservation on the exact word, held in a monitor at the memory controller.* For: no false sharing, whatever the lines are. Against: a monitor with an address comparator for every core, and a rule for cached lines that move between cores while a reservation is held.

**Precedents.** RISC-V lets the implementation choose the size of the reservation set and requires no minimum beyond the word *(unverified: from memory of the specification)*. Arm exposes the exclusives reservation granule size in a system register and gives a range of 8 bytes to 2 KB *(unverified)*. x86's `lock` prefix works on a cache line and has no granule to report *(unverified)*.

**The author's referents.** None named; the spec is the author's (errata 45: "a naturally aligned granule of the implementation's choice (not smaller than 8 bytes)").

**The assistant's leaning.** Option 3, with the maximum equal to the line size once J.7.2 fixes it.

**Where the body refers to it.** Section 7.4.6.

<a id="j76"></a>
### J.7.6 How block operations order their accesses

**Issue.** The block operations are `MCPY`, `MMOV` and `MSET`, which write memory, and `MCMP`, `MSCN`, `MSCNN` and `MVAL`, which only read it (9.11.3). Each keeps its progress in its registers (9.11.4) and an implementation may move more than a byte per step (9.11.5). One part of the ordering is decided: the accesses inside one block operation are unordered with respect to one another, and only the final contents of memory and the register progress are defined (7.5.8, errata 39 item 7; the text was never written into the instruction-set document, and the decision list of the ledger does not carry it). Nothing is decided about the rest: (1) the order of the elements, and the meaning of overlap for `MMOV`; (2) how far an access may tear, per byte, per aligned word or per cache line; (3) whether another core may observe an intermediate state, and which; (4) what a program must execute to publish the result, given that `FENCE` orders only device accesses (7.5.7); (5) what a fault or an interrupt leaves in memory beyond the progress in the registers (the progress category of 6.4); (6) the effect on a reservation (7.4.1 clears it on any write) and on atomics that touch the same granule; (7) uncached and device memory, where the number and size of accesses are visible. The ledger lists the block instructions themselves as in the air (no standing decision beyond the progress in registers, R362: "good" to a single move with no resume opcode).

**Why it matters.** The flag idiom (copy a buffer, then store a flag that another core polls) is the commonest use of a copy between cores, and under sequential consistency (7.5.1) it needs no barrier for ordinary stores. Whether it works for a block copy decides whether a kernel's `copyout` of a message and the C library's `memcpy` into a shared buffer need code that the rest of the machine avoids. A copy into a device queue is the other case. The out-of-order readiness review found that this is the one place where the text of the instruction set (a byte at a time, "stated as a loop") and the promise of 7.5.1 disagree.

**Options.** Options 1, 2, 4 and 5 differ in what another core sees; option 6 is about device memory and combines with 1, 2 or 4.

1. *Unordered inside, ordered as a whole.* Every access of the instruction is after all earlier accesses of the core and before all later ones, as the other cores see them; inside, any order, any intermediate state. A plain store of a flag after the instruction is safe. For: the flag idiom works with no fence; the decided rule of 7.5.8 holds. Against: the engine must finish before the next access issues, so a large copy cannot overlap later work; an interrupted copy has published part of its data.
2. *Unordered inside and with respect to later accesses; a fence after the instruction publishes.* The engine runs in the background as a DMA device does, and `FENCE` is widened to all memory. For: the cheapest hardware and the most overlap. Against: breaks the rule of 7.5.1 for the code after a copy and brings back the barrier a kernel writer must remember; `FENCE` changes meaning (7.5.7).
3. *Ordered as the loop of the instruction-set text, byte by byte.* For: nothing new to learn; the model is the PDP-11 loop. Against: contradicts the decided 7.5.8; a wide engine must hold back stores to keep the order seen by others.
4. *Option 1, and every aligned 8-byte piece is single-copy atomic.* The head and the tail that are not aligned are byte accesses. For: a reader of copied pointers or counters never sees a torn word (7.5.3 and 7.5.6 already promise this for ordinary accesses); the engine moves aligned quads. Against: an engine that moves lines must still be able to split them; `MSET` of one byte into a word needs a byte access.
5. *The block operation is atomic against other cores.* For: nothing to reason about. Against: an unbounded hold on memory against interrupts and the progress rule, and a latency no real-time claim survives (J.9.7).
6. *Device and uncached pages are accessed in element order, one access of the program's size per element, never combined or repeated.* Ordinary pages follow option 1, 2 or 4. For: a block write to a device register ring means what a loop would mean. Against: the behaviour depends on the memory type of the page, and the same instruction runs at two speeds.

**Precedents.** x86 `REP MOVS` keeps its progress in registers and, in the fast-string forms, is allowed to order its stores differently from ordinary ones; Linux's `memcpy` uses `rep movsb` where the processor has the fast form (`arch/x86/lib/memcpy_64.S`, read; the rules in the Intel manual are unverified). ARM64 `FEAT_MOPS` splits a copy and a set into prologue, main and epilogue instructions (`cpyp`, `setp` in Linux's `arch/arm64/lib/memcpy.S` and `memset.S`, read), updates the registers as it goes and leaves the order and size of the accesses to the implementation (the architectural wording is unverified). The VAX `MOVC3` and `MOVC5` were interruptible, with the registers as state and a first-part-done bit in the status word (9.11 and J.9.7; the NetBSD VAX copy routines use `movc3`, `subr.S`, read; the memory ordering is moot on a machine that was one processor in most models). The PDP-11 had no block move: a loop of `MOV (R0)+,(R1)+` makes every word its own access in program order (inference). RISC-V's Zicboz zeroes a whole aligned block with one instruction (`ZICBOZ` in Linux's `hwcap.h`, read; its ordering rule is unverified) and proposals for memcpy and memset instructions exist (unverified). A DMA engine, a virtio device, moves its data in any order and publishes it by writing the used ring last, with the driver's barrier between the two (the rule of the virtio specification, unverified here).

**The author's referents.** "rep movsb r1,r2,10;" and "how about mmov mcpy mset ? like ibm system z?" (the author, 2026-10-20); "doesn't mcmp/mmov count?"; VAX `MOVC5` as the argument against hidden state (9.11); errata 39 item 7.

**The assistant's leaning.** Option 4 with option 6: ordered as a whole against the other accesses of the core, aligned quads atomic, and element order on device pages. The leaning keeps the flag idiom free of fences, which is what the decision for sequential consistency was bought for. This is the assistant's view, not a decision.

**Where the body refers to it.** Sections 7.5.8, 7.5.9 and 9.11.

<a id="j77"></a>
### J.7.7 Secure mode on every core, or one secure core

**Issue.** The author decided on 2026-11-10 (errata 132): "at least one core that can be in 'secure' mode; if it doesn't take too many gates, let that be a mode for all the cores, but if it slows things down too much then return to a single secure core" (7.11.3). Two things are not decided: what counts as "too many gates" and "too much slowdown", and how the two are measured. Secure mode here is the whole of 7.11.3 to 7.11.5: constant-time instructions and cache fetches, private cache lines, no periodic tick, stop and preemption by an inter-processor interrupt, constant-time AES and SHA instructions, the private fixed-latency window, the locked translation buffer, no speculation, a fixed clock, and the clear at a domain switch. The status-word bit `DIT` (9.3.7) is already decided for every core; it makes the data-dependent timing of instructions, of the clock and of prefetch disappear while set, and leaves out the private window, the locked buffer, the absence of speculation and the clear.

**Why it matters.** A mode of every core means every core carries the extra logic and a kernel may place a secret-handling process anywhere; one secure core means a smaller, simpler design for the rest and a scheduling rule that sends secret work to one core. On four cores, one secure core is a quarter of the first device. The choice sets the class register's fields (7.11.1), the instruction set of 9.9.7 on every core or one, the kernel's affinity rule, and what the first device's FPGA must hold (10.1.3).

**The measurement plan.** *Gates:* synthesise one core twice for the FPGA of the plan, with and without the mode, and compare the lookup-table counts (and block RAMs) of the logic the mode adds: the fixed-latency window, the locked translation buffer, the clear engine, the clock hold, the speculation disable and the AES and SHA datapaths. *Slowdown:* with the mode's circuitry present but unused, measure the instructions per cycle of ordinary mode on the benchmark set and the critical path (the clock the core reaches), the extra multiplexers in the memory path and the cache arrangement the private lines need; separately measure the performance while in secure mode, which is allowed to be slow. *Threshold:* a number for each, set by the author (for example a percentage of the core's lookup tables, a percentage of the clock); nothing is measured yet, and no core has been synthesised (10.1.8).

**Options.**

1. *One dedicated secure core.* The design of `crypto-secure-core.md`: a small in-order core with the window, the clear engine and the bus slot, and no mode on the other cores. For: the other cores pay nothing; the guarantee is by construction (no speculation, no sharing); the design is already approved (errata 86). Against: a core that general work cannot use; secret work must move to it, and a process that needs more than the window does not fit.
2. *A secure mode on every core, entered by a privileged instruction or by a status-word bit.* The mode relates to `DIT` (9.3.7): `DIT` makes ordinary instructions constant-time, and secure mode adds the private window, the locked buffer, a fixed clock and no speculation. For: any core can run a secure domain; no core is set aside. Against: every core carries the logic; an out-of-order core must turn speculation off and drain its predictors on entry (a cost in time); the critical path may lengthen.
3. *Secure mode on a subset of cores (a core class).* The class register of 7.11.1 says which. For: a middle way: more than one secure core without the cost on all. Against: a scheduling rule that depends on the machine; the subset size is another number to choose.
4. *Secure mode as a core class chosen at build time.* A configuration parameter of the die, a number of secure cores from none to all. For: one design serves every product; the first device can have one and a larger die more. Against: the kernel must read the class and plan for any count; more variants to test.
5. *A time-shared secure domain on any core, with the clear-on-switch rule only.* The kernel clears the core's state when it enters and leaves a secure domain, and the core has no other mode logic. For: the least hardware. Against: a shared cache, translation buffer and predictors cannot all be cleared at a cost that hides the leak; it removes no channel that a clear does not reach.
6. *No secure mode, only `DIT`.* For: nothing added; `DIT` (9.3.7) covers constant-time instructions. Against: leaves table lookups indexed by secrets exposed to the cache and the translation buffer, which the private window and locked buffer exist to close; contradicts the decided 7.11.3.

**Precedents.** Arm TrustZone gives every core a secure state (*unverified*; Linux's `PSR_DIT_BIT` in `arch/arm64/include/uapi/asm/ptrace.h` and `PSTATE_DIT` in `sysreg.h` show the data-independent-timing bit on Arm, *read*). Intel SGX and TDX are modes of every core (*unverified* as designs; Linux has an SGX driver, `arch/x86/kernel/cpu/sgx`, and TDX configuration in `arch/x86/Kconfig`, *read*); the repository records that enclaves on a shared core suffer every microarchitectural channel (`hardware-vulnerabilities.md`, the SGX and TEE attacks row, and rule C15 against enclave claims without partitioned hardware, *read*). The RISC-V physical memory protection registers (Linux `arch/riscv/include/asm/csr.h`, `PMP_R`, *read*) and the security extensions are modes of every core (*unverified* beyond the register names). Arm CCA realms are a state of every core (*unverified*). Apple's Secure Enclave and AMD's platform security processor are separate cores (*unverified*); OpenTitan is a separate security chip (*unverified*). The repository's own design (`crypto-secure-core.md`) is a separate core class, and its section 1.4 makes `DIT` constant on it (*read*).

**The author's referents.** "i like your design. approved." (errata 86); "constant-time AES and SHA instructions" (errata 85); the decision of 2026-11-10 above; `DIT` (9.3.7).

**The assistant's leaning.** Option 4: build the mode as a class that a die parameter sets, measure the gates and the slowdown on the first device, and let the author's threshold decide between one and all. The gate figures should come before the leaning is trusted. This is the assistant's view, not a decision.

**Where the body refers to it.** Sections 7.11 and 7.11.3, and 10.4.3.
