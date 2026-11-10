<a id="j71"></a>
### J.7.1 The wake rule of WFE and the idle loop

**Issue.** `WFE` (wait for event) puts a core to sleep until another core executes `SEV` (send event) or an interrupt arrives (7.6.1). The idle loop of a kernel checks the run queue and then sleeps; if an interrupt arrives between the check and the sleep, it queues work, returns, and the core sleeps with work waiting (a *lost wake-up*, an event that arrives in the gap between the test and the sleep and is never seen). The PDP-11's V7 kernel had the same gap and a clock tick repaired it within one tick. A core that takes no periodic tick has no repair. The question is what ends a `WFE` sleep, and (the decided answer for a masked interrupt is in the statement below). The author decided (2026-10-22: "Yes, wake on pending") that `WFE` ends its sleep when an interrupt is pending even if the priority masks it, so that the idle loop is `SPL #7`, check for work, `WFE`, `SPL #0`, with no gap (7.6.2). What is open is the rest of the wake rule: whether `SEV` is sticky for one wait, and whether other events also end the sleep (options 2 to 5).

**Why it matters.** The idle loop of every kernel, and the port's `cpu_idle_cycle`, depend on it. A lock waiter that could sleep instead of spinning would save memory bandwidth on 16 cores, and the answer decides whether an unlock must execute `SEV`. A wrong rule is a hang that occurs once a week.

**Options.**

1. *The decided rule alone, with `SEV` sticky for one wait.* The loop is `SPL #7`, test, `WFE`, `SPL #0`. For: closes the gap with no new instruction; two rules in the core. Against: none beyond the decided rule: a core wakes for an interrupt it will not take until the level drops (it then takes it, as intended).
2. *Option 1, and `WFE` also ends when the reservation of a preceding `LL` is lost.* A spin wait becomes `LL r, lock; test; WFE`; the holder's ordinary release store wakes the waiter, and the unlocker executes no `SEV`. For: unlock stays one store; a waiter costs no bus bandwidth. Against: the reservation must stay armed while the core sleeps; a spurious wake is allowed, so the loop re-reads; the reservation rules (7.3.1) must say that the reservation survives the sleep.
3. *`WFE` takes a priority operand.* One instruction lowers the level and sleeps. For: no `SPL` around it. Against: a new operand form to encode; no gain where the loop is already two instructions.
4. *A timeout form with a deadline.* For: a waiter cannot sleep forever if the wake source breaks; the secure core's bounded waits. Against: an operand; a deadline needs the timer.
5. *No `WFE`; poll with the `HINT` pause.* For: nothing to specify. Against: burns power and bandwidth, and on an FPGA a spinning core takes the memory bandwidth the other cores want.

**Precedents.** ARM's `WFE` ends on `SEV`, on an interrupt and on the clearing of the exclusive monitor, which is how a lock waiter sleeps until the holder's store *(unverified: general knowledge)*. RISC-V's `wfi` ends when an interrupt is pending and enabled in its own register whatever the global enable says, and may be a no-op; `Zawrs` adds a wait on a reservation *(verified in the repository's notes)*. x86 has `HLT` after `STI` (the instruction after `STI` cannot be interrupted, which makes the pair safe) and `MONITOR`/`MWAIT` on a cache line *(unverified)*. V7's idle routine lowered the priority and executed `wait` in a loop *(verified in the repository's notes)*. OpenBSD's riscv64 idle is `intr_enable(); wfi` with a comment that doubts it *(verified)*.

**The author's referents.** "main cores tickless"; no system named for the idle loop.

**The assistant's leaning.** Option 2, which contains option 1: a lock waiter sleeps without an `SEV`.

**Where the body refers to it.** Sections 6.11 and 7.6.2.

<a id="j72"></a>
### J.7.2 Coherence beyond four cores

**Issue.** The first device has four cores that snoop (every cache watches the others' writes) with three states, modified, shared and invalid (7.7.1), and the architecture supports at least four cores, with sixteen or more as the preferred ceiling (7.7.3, errata 92). The protocol that serves more than four coherent cores has not been chosen. The architecture promises that memory is coherent and sequentially consistent (7.2.1) and says nothing of the protocol. The statement as first written: the protocol for more than four coherent cores is open; the leaning of the SMP decisions is MESI with a snoop filter inside clusters of four and a directory between clusters, with dedicated cores as non-coherent partners that use uncached rings. *(P)*

**Why it matters.** The number of general cores sets the size of the cache controller, the FPGA that can hold the design (about 16,000 look-up tables for a core before coherence, by a paper estimate at plus or minus 40 percent; four cores fit a Kria-class board and none of the planned boards holds sixteen), and what the kernel's scheduler sees as a group. Also the line size (64 bytes), the reservation granule and the invalidate granularity hang from it.

**Options.**

1. *Keep three-state snooping for two to four cores and say so.* For: smallest; fits the first device. Against: breaks the target of sixteen or more cores; snooping traffic grows with the cores.
2. *MESI within clusters of up to four cores, a snoop filter at a shared second-level cache, and a directory between clusters.* MESI adds an exclusive state, so a write to a clean line that nobody else holds needs no bus transaction. For: four cores are one cluster and nothing is wasted; the ceiling is reached by adding the inter-cluster layer. Against: two protocols; the directory is where protocol deadlocks hide.
3. *A flat directory.* One home place per line and a bit-vector of sharers. For: simplest to reason about; scales to 64. Against: two hops for the common case, which is more than a four-core machine needs.
4. *No coherence between clusters; explicit cache operations.* For: cheapest to scale. Against: every missing flush is a race that reproduces once a week; it weakens sequential consistency to "within a cluster".
5. *Dedicated cores as non-coherent partners of coherent general cores.* The graphics, network and audio cores use uncached rings and `FENCE`, as a DMA device does. For: the coherent count stays at the general cores. Against: the data of a partner is not coherent with the kernel's buffers without a copy or a flush; it depends on the dedicated cores of 7.8.6, whose details are pending (J.7.5).

**Precedents.** PDP-11/70 caches were kept coherent by write-through and invalidation on DMA writes *(unverified: from memory)*. Bus-snooping multiprocessors (Sequent, Sun Enterprise) stopped near 16 to 64 processors *(unverified)*; directory machines (Stanford DASH, SGI Origin) scale by messaging the sharers *(unverified)*; x86 uses snoop filters inside a die and directories across sockets; ARM's coherent interconnects use filters or directories *(unverified)*.

**The author's referents.** "4 cores minimum, 16 or more preferred"; "for initial device 4 cores is enough hopefully that fits on the fpga".

**The assistant's leaning.** Option 2 as the direction, built in two steps: one cluster of four cores first, with the shared cache designed so a directory can be added; the architecture text says "coherent, sequentially consistent, line size 64 bytes" and nothing of the protocol, so more cores are an implementation and not a change.

**Where the body refers to it.** Section 7.7.4.

<a id="j73"></a>
### J.7.3 The operands of the atomic instructions

**Issue.** The atomic words (7.12.1) take three register fields in the grammar (four for `CAS`), with the address in a register and the size in the sub-opcode. The roles of the registers, the size encoding of `CAS` and any displacement are not fixed in the text, and the reference executor does not implement the group. The statement as first written: the operands of the atomic words sit in three register fields (four for `CAS`), the roles are not fixed, and the study leans to fixing three register fields now, with the fourth reserved zero. *(P)*

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

**Where the body refers to it.** Section 7.12.5.

<a id="j74"></a>
### J.7.4 Atomics on uncached memory and on device memory

**Issue.** The read-modify-write atomics are atomic with respect to every initiator, cores and devices alike (7.3.3, 7.12.3). That is easy on cached memory, where the cache line is held exclusively. On a page of uncached memory or a device page the access goes to the bus, and a PCI Express transaction has atomic operations (`AtomicOp`) only on devices that choose to implement them. The mapping of the machine's atomics onto the bus is therefore not stated.

**Why it matters.** The rings of every virtio device and the locks of dedicated cores sit in memory that may be uncached; a program that issues `CAS` on such a word needs either a defined result or a defined fault. The software cannot be silent about it, and a silent non-atomic update is the worst outcome.

**Options.**

1. *Abort.* An atomic to a device or uncached page raises an access fault. For: easy to detect and cheap to build. Against: a driver cannot use an atomic on a shared uncached ring.
2. *Performed at the memory controller (far atomics).* The operation travels to the memory and the result returns. For: constant cost under contention; works for uncached normal memory. Against: the memory side needs an arithmetic unit and a defined form for every word, and a clear rule for the interaction with reservations.
3. *Forwarded as PCI Express atomic operations where the device advertises them, abort otherwise.* For: uses what the bus offers. Against: only compare-and-swap, swap and fetch-and-add exist on the bus; the other words would still abort.
4. *Defined only for cached normal memory, undefined elsewhere.* For: nothing to build. Against: undefined behaviour in a place where a fault would be better.

**Precedents.** PCI Express defines `AtomicOp` for fetch-and-add, swap and compare-and-swap *(unverified)*. AXI5 has atomic transactions performed near the memory *(unverified)*. The PDP-11's `DATIP`/`DATO` pair locked the Unibus for the read-modify-write *(verified in the repository's sources)*.

**The author's referents.** None named.

**The assistant's leaning.** Option 1 for device pages and option 2 or an abort for uncached normal memory, decided with the transport of the bus (errata 80); a fault that is easy to detect is better than a silent non-atomic update.

**Where the body refers to it.** Section 7.3.5.

<a id="j75"></a>
### J.7.5 The dedicated cores: how many, how they share memory, what they run

**Issue.** The author decided (errata 76: "we recommend one core dedicated to the gpu/graphics device, one core dedicated to the nic, running the full tcp/ip stack, then a bunch of other cores for general processing", and "one core for audio processing, doing midi, dsp, etc.") that the machine has dedicated cores for graphics, network and audio besides the general cores (7.8.6). Not worked out: whether the first device has them or only the general cores (it has four cores in all, 7.7.3), how a dedicated core shares memory with the others, what runs the TCP/IP stack, how many cores in total, and the IOMMU domain of each.

**Why it matters.** Four cores in all leave one general core if three are dedicated; the coherence of J.7.2, the interrupt delivery of J.6.3 (a dedicated core can poll its virtio queues instead) and the secure core's isolation all depend on the answer.

**Options.**

1. *Dedicated cores in the first device as logical roles of ordinary cores.* For: nothing to build; the roles can change. Against: with four cores, little is left for general work.
2. *Dedicated cores beyond the first device.* The first device has four general cores and the dedicated cores arrive with the 16-core target. For: fits the FPGA. Against: the graphics and network paths are first exercised late.
3. *Dedicated cores as non-coherent partners, with uncached rings and `FENCE`, each in its own IOMMU domain.* For: a fault in one does not reach the others. Against: a copy or flush for data shared with the kernel's buffers.
4. *Dedicated cores coherent like the others.* For: shared buffers need no flushes. Against: the coherence protocol of J.7.2 must reach them.

**Precedents.** The Blit's terminal had a processor of its own (Pike, Locanthi and Reiser); the VAX console processor was a second processor; smart network cards run the stack on an on-card core.

**The author's referents.** The Blit model; a standard PCI Express network card (errata 75).

**The assistant's leaning.** Option 3, with option 2 for the first device if the FPGA cannot hold more than four cores.

**Where the body refers to it.** Sections 3.8.2 and 7.8.6.
