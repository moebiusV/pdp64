# 7. Multiple processors

[← manual index](00-index.md)

**The pdp64 is built so that adding a second core needs seventeen operations, one per-core register, and nothing a kernel writer has to work around: memory is sequentially consistent, the atomics are one instruction each, the per-CPU pointer is a register that already exists, and the other cores' translation buffers are invalidated by a single broadcast.** This chapter collects everything the architecture adds for symmetric multiprocessing, what a kernel does with it, what was deliberately left out, and what must still be built on the device side. The instruction-set text is [`../pdp64-isa.md`](../pdp64-isa.md), section 17. Tags: *(D)* decided; *(P)* proposed.

## 7.1 The seventeen operations

**7.1.1** The instructions that exist for multiple processors fall under one umbrella of seventeen operations: ten atomics and seven others. *(D)*

| Group | Operations |
|---|---|
| **Atomics (10)** | compare-and-swap (`CAS`), swap (`SWAP`), fetch-and-add (`XADD`), fetch-and-and (`XAND`), fetch-and-or (`XOR_`), fetch-and-exclusive-or (`XXOR`), fetch-and-maximum (`XMAX`, with `XMAXU`), fetch-and-minimum (`XMIN`, with `XMINU`), load-linked (`LL`), store-conditional (`SC`) |
| **Others (7)** | `FENCE`, wait-for-event (`WFE`), send-event (`SEV`), `TLBI` (with `TLBIA` as its "all" form), `TLBSYNC`, instruction-cache invalidate (`ICINV`, with `ICINVA`), read the core number (`MFCPUID`) |

**7.1.2** Every atomic has a variant, `_DB`, that folds a barrier into the instruction, so that a lock acquire or release is one instruction. *(D)*

**7.1.3** The atomics live in the atomic escape group and the other operations in the system group; the umbrella is conceptual, not an encoding. *(D)*

**7.1.4** Supporting these are things the machine already had: the banked direct-page register, the address-space tag, the global-page bit and the banked stack pointer (section 7.4). *(D)*

*Commentary.* **Precedent.** The PDP-11/70's read-modify-write instructions were indivisible on the Unibus (`DATIP` and `DATO`); the VAX added interlocked instructions (`BBSSI`, `ADAWI` and the queue instructions) and multiprocessor models, and the 4.3BSD kernel on them still used `spl` for exclusion. **Trade-offs.** The set is the union of the three designs found on other machines (compare-and-swap, load-linked and store-conditional, fetch-and-operate), which is more atomic operations than any architecture surveyed, in exchange for nothing a kernel writer has to emulate. **Improvements.** The `_DB` forms were taken from LoongArch: a lock acquire should be one instruction, with no separate fence. **Benefits.** The seven non-atomic operations are the minimum that a kernel cannot synthesise: which core am I, wait and signal, invalidate everywhere, and make the instruction fetch see what the data side wrote. **Modern comparables.** RISC-V's `LR`/`SC` and `AMO` set, AArch64's exclusive loads and stores and its large-system atomics, x86's `LOCK`-prefixed read-modify-write. **Impact.** *Kernel:* Each of the seventeen operations is one instruction in the kernel's lock, idle, shootdown and per-CPU code. *Compiler:* C11 atomics and the kernel's intrinsics map to them directly. *Hardware:* The atomics live in one escape group and the other seven in the system group, so the decoder has two places to look.

## 7.2 The memory model

**7.2.1** Memory is sequentially consistent: the result is as if all cores' accesses happened in one order that respects each program's order. *(D)*

**7.2.2** A store buffer is allowed, provided loads snoop it and stores drain in program order. *(D)*

**7.2.3** Quad accesses are naturally aligned, so every access is atomic within its own size; no misaligned access can be torn across cores. *(D)*

**7.2.4** The machine is in order and does not speculate, so no speculative side channel exists to be mitigated. *(D, errata 38)*

**7.2.5** The ABI says nothing about memory ordering, because with sequential consistency there is nothing to say. *(D)*

**7.2.6** Memory is sequentially consistent per byte: a load returns, for each byte, the value written by the last store to that byte in the single order, and an aligned access of N bytes is single-copy atomic. A load that overlaps a buffered store of a different size either waits for the buffer to drain or merges the buffer and memory in one step; it never returns a mixture that no order of the stores could produce. *(D, the author 2026-10-23, errata 71)*

*Commentary.* **Precedent.** The PDP-11 and VAX ran one processor at a time in the model that mattered, so the question did not arise; ARM's memory model took about a decade to formalise, and the C11 and C++11 models exist largely to paper over the differences between weak architectures. **Trade-offs.** Sequential consistency is the model with no cost to software and the highest cost to a large speculative core; software written against a weak model runs on a strong machine and not the reverse, so the choice is close to irreversible, which is why it was made once. If a large out-of-order core is ever built, total store order is the least painful retreat. **Benefits.** None of the barrier code that fills other kernels: the kernel survey found barrier vocabulary in 5,596 lines of Linux code and 3,016 lines of `memory-barriers.txt` documentation, and none of it arises here. **Modern comparables.** x86 and SPARC are total store order; ARM, POWER and RISC-V are weak. **Impact.** *Kernel:* None of the 5,596 lines of ordering code found in Linux, nor the barrier documentation, is needed. *Compiler:* The optimiser may move non-volatile accesses freely, and no fence is inserted for ordering. *Hardware:* In-order with a snooped store buffer; sequential consistency is nearly free on this core and the expensive part only appears on a speculative one.

## 7.3 The atomics in detail

**7.3.1** `LL` takes a reservation on a granule of memory; a write to the granule by any initiator, core or device, clears it; `SC` succeeds exactly when the reservation is intact and otherwise writes nothing. *(D, errata 45)*

**7.3.2** A short `LL`/`SC` sequence must eventually succeed if no other initiator keeps writing the granule. *(D)*

**7.3.3** The read-modify-write atomics are single-copy atomic with respect to every initiator; the memory system may build them from an exclusive access with hardware retry. *(D)*

**7.3.4** A device that writes memory shared with a core takes part by clearing reservations. *(D)*

*Commentary.* **Precedent.** A bus lock, the Unibus's `DATIP`/`DATO` pair, is simple and a bottleneck as cores multiply; a monitor maps onto the exclusive access of AXI and the memory systems of FPGAs and modern chips. **Trade-offs.** A monitor needs forward-progress rules and, under contention, can livelock if not specified; RISC-V's guarantee of eventual success for constrained sequences is the model. The pain-points report records that the kernels' simple lock does not scale (OpenBSD's ticket kernel lock measured 155% worse than an Anderson lock in one developer's test) and that Linux moved from test-and-set through ticket locks to queued locks; the instruction set provides the primitives and the lock design is the kernel's. **Benefits.** A kernel's lock needs one instruction; lock-free queues need compare-and-swap. **Modern comparables.** RISC-V `LR`/`SC` with its constrained-loop guarantee, AArch64 load-exclusive and `CAS`, x86 `LOCK CMPXCHG`. **Use.** `CAS` for lock-free structures and lock words; `XADD` for counters and ticket numbers; `LL`/`SC` for everything else. **Impact.** *Kernel:* A lock is one `_DB` instruction. *Compiler:* A `LL`/`SC` loop must be emitted in the constrained form, with no other memory access between the two. *Hardware:* A reservation granule tag in the cache controller and an exclusive-access path to memory.

## 7.4 Per-CPU state and cheap context

**7.4.1** `MFCPUID` returns the number of the core that executes it. It cannot be synthesised and per-CPU data needs it. *(D)*

**7.4.2** `DP`, the direct-page register, has a copy per mode; in kernel mode it is the per-CPU pointer and a field of the per-CPU structure is one four-byte instruction, `MOVQ d(DP), Rd`. *(D)*

**7.4.3** The address-space tag makes a context switch constant-time, and global page-table entries and the direct-mapping windows keep the kernel's own mappings out of the invalidation path. *(D)*

**7.4.4** The stack pointer is banked by mode, so an interrupt arriving in user mode on any core finds that core's kernel stack without a search. *(D)*

*Commentary.* **Precedent.** Every SMP kernel builds a per-CPU base by hand: x86 uses the `GS` base and a `swapgs` instruction, ARM uses `TPIDR_EL1`, RISC-V the supervisor scratch register, MIPS reserves two registers; the kernel survey found seven architectures paying for the problem of having no free register at the moment of entry. **Improvements.** `DP` was added for code density and turns out to be what both an SMP kernel and a threaded C runtime need most, in the mode where each needs it, and the two copies do not conflict. **Benefits.** No `swapgs`, no reserved scratch register, no code spent finding the CPU. **Modern comparables.** `GS` and `TPIDR` as above. **Impact.** *Kernel:* Per-CPU data is one four-byte `MOVQ d(DP), Rd`, with no `swapgs` and no reserved register. *Compiler:* The compiler addresses per-CPU variables relative to `DP`. *Hardware:* Three copies of `DP`, one per mode.

## 7.5 Translation and instruction-cache coherence

**7.5.1** `TLBI` and `TLBIA` broadcast to all cores; `TLBSYNC` waits until the broadcast has completed everywhere. *(D)*

**7.5.2** Instruction caches are not coherent with data caches; `ICINV` invalidates a line and `ICINVA` all of it, and neither is privileged, because a JIT needs them. *(D)*

**7.5.3** A write to the page-table base, the address-space tag, the translation-enable bit or the vector base takes effect only after the next `ISYNC`. *(D, errata 39)*

*Commentary.* **Precedent.** x86 flushes remote translation buffers with an inter-processor interrupt and a software handshake, which is slow and intricate; AMD added a broadcast invalidate only late. **Trade-offs.** A broadcast is simpler in hardware and far faster for two to four cores; it needs the completion barrier, because a broadcast one cannot wait for is no use. Making instruction caches coherent would cost a snoop port for a case that almost never happens. **Improvements.** The kernel's own mappings are global or window-mapped and never part of a shootdown. **Benefits.** The pain-points report finds that remote translation-buffer shootdown, a source of deadlocks in the BSDs and of much code in Linux, does not arise. **Modern comparables.** ARM's broadcast `TLBI` and `DSB`; RISC-V's `SFENCE.VMA` still needs software shootdown. **Impact.** *Kernel:* A shootdown is `TLBI` then `TLBSYNC`; a module or JIT write is `ICINV` then `ISYNC`. *Compiler:* A JIT or a trampoline generator must call `ICINV` after writing code. *Hardware:* A broadcast on the interconnect and a counter for completion; the instruction cache has an invalidate port but no snoop port.

## 7.6 Waiting and signalling

**7.6.1** `WFE` sleeps until another core executes `SEV` or an interrupt arrives, and `HINT #1` is the spin-wait pause. *(D, errata 39)*

**7.6.2** `WFE` ends its sleep when an interrupt is pending even if the priority masks it, so that the idle loop is `SPL #7`, check for work, `WFE`, `SPL #0`, with no gap. *(P, the wake rule under decision)*

**7.6.3** On one core `WFE` is the idle instruction, and `WAIT` is its assembler alias. *(D)*

*Commentary.* **Precedent.** x86's `PAUSE` tells a spinning core to back off; ARM's `WFE` lets it stop until an event. V7's idle routine lowered the priority and executed `wait` in a loop that rechecked the run queue after every interrupt, so a missed wake-up cost one clock tick. **Trade-offs.** On an FPGA a spinning core consumes memory bandwidth the other cores want, which is the reason to prefer a real wait. **Benefits.** An idle core costs nothing and wakes on a signal. **Modern comparables.** ARM `WFE` and `SEV`, RISC-V `WFI`. **Impact.** *Kernel:* An idle core waits on `WFE` and costs no bandwidth. *Compiler:* Spin-wait loops use `HINT #1`. *Hardware:* `WFE` stalls or gates the core's clock until an event or an interrupt.

## 7.7 Cache coherence

**7.7.1** Between processors, coherence is transparent to software, by snooping with three states (modified, shared, invalid), for two to four cores. *(D)*

**7.7.2** A DMA device is the opposite case: the buffers are uncached and the hand-off is explicit, because snooping the DMA path is expensive and DMA transfers are large, infrequent and have an explicit hand-off. *(D)*

*Commentary.* **Trade-offs.** MESI would add an exclusive state to avoid a bus transaction when writing a clean line nobody else holds; at four cores the benefit is small and the state machine larger; a directory scales further and is not needed below about eight cores. Software-managed coherence is cheaper in hardware and is where concurrency bugs live, since every missing flush is a race that reproduces once a week. **Benefits.** The instruction set owes nothing to the coherence protocol, which is the correct division. **Modern comparables.** x86 snoops with MESIF or MOESI and directories across sockets; ARM's coherent interconnects use directories or snoop filters. **Impact.** *Kernel:* No coherence code, in either direction between cores. *Compiler:* None. *Hardware:* A snoop port on each data cache, about 500 lookup tables and a small state machine for three states, plus about 600 per core.

## 7.8 Starting and signalling the other cores

**7.8.1** The controller holds every core but core 0 in reset; a write to a per-core start register gives a core an entry address and an argument and releases it into kernel mode at priority 7, with its number in `r0`. *(P, decision B2)*

**7.8.2** An inter-processor interrupt is a write to a per-core register in the interrupt controller; no APIC-like machinery is needed. *(P)*

**7.8.3** The routing of device interrupts to cores, and a shared second-level cache or a coherent interconnect, are device-side and not yet defined. *(P, decision R1)*

**7.8.4** Each core has a read-only identification register giving its class and capacity, defined from the first system although every core is alike, and a stop-and-drain register that a kernel writes to take a core offline: the core finishes its outstanding bus transactions and stops. *(D, the author 2026-10-23, errata 71; not yet in the specification files, the simulator or QEMU)*

*Commentary.* **Precedent.** An x86 core wakes in 16-bit real mode and has to be walked through three modes by a trampoline (1,528 lines of start-up code and 1,258 of real-mode code in Linux); arm64 uses a firmware call in 124 lines or a spin table in 127; RISC-V 108 or 58; the VAX's console processor started the others. **Benefits.** A core can start in its normal mode at any address, so the whole protocol is one register write. **Modern comparables.** x86's INIT and START-UP interrupts, ARM's PSCI, RISC-V's hart-start call. **Impact.** *Kernel:* Starting a core is one register write, and a stuck core is reset by another. *Compiler:* None. *Hardware:* A start register and a reset-hold per core in the controller.

## 7.9 A kernel's view

**7.9.1** The kernel starts a core by writing its start register, keeps its per-CPU structure at the address in `DP`, and takes a lock with one `_DB` atomic. *(P)*

**7.9.2** It unmaps a page by changing the entry, issuing `TLBI`, and waiting with `TLBSYNC`. *(D)*

**7.9.3** It makes new instructions visible by writing them, issuing `ICINV` and executing `ISYNC`. *(D)*

**7.9.4** It idles a core with `WFE` and wakes it with `SEV` or an inter-processor interrupt. *(P)*

*Commentary.* This section is the checklist an operating-system port works through. Each item is one instruction or one register write, and each is a place where other architectures need a trampoline, a handshake or a fence.

## 7.10 What was avoided

**7.10.1** The architecture has no weak ordering, no speculative execution, no hardware transactional memory, no software-managed coherence between processors, no coherent instruction caches, no inter-processor-interrupt shootdown as the main mechanism, and no memory-model-dependent ABI. *(D)*

*Commentary.* **Trade-offs.** Intel's transactional memory produced a decade of errata and side channels for a feature few programs used; compare-and-swap and `LL`/`SC` suffice. Each avoided item is a tax on every concurrent program, or on every implementation, in exchange for performance the small in-order core cannot use. **Impact.** *Kernel:* Each avoided feature is code a kernel does not have to write: no barriers, no software coherence, no shootdown interrupts. *Compiler:* Each is analysis the compiler does not have to do: no memory-model-dependent code generation. *Hardware:* Each is a block not built: no speculation, no transactional memory, no coherent instruction cache.

## 7.11 What the model does not give for free, and the road to out of order

**7.11.1** A simple memory model does not make an atomic implementation simple by itself: cache coherence, exclusive ownership, invalidation, ordering and the interaction with interrupts still have to be designed and tested. *(the author's caveat)*

**7.11.2** Out-of-order execution was never ruled out: the first implementations are in order, and the architecture is kept ready for a large out-of-order design. *(D, errata 38)*

**7.11.3** Sequential consistency on a speculative core needs loads that are replayed when another core intervenes; the readiness review calls this awkward but defined, and the flag rules (errata 39), the reservation rules and the `ISYNC` and `HINT` instructions are what the review asked for. *(D)*

*Commentary.* **Precedent.** One instruction set often spans small in-order and large out-of-order cores: ARM's small and large cores, RISC-V's Rocket and BOOM, the x86 Pentium and P6, Alpha's 21064 and 21264. **Trade-offs.** What the pdp64 gains by refusing speculation is a smaller design with fewer error cases and none of the speculative side channels; what it gives up is the performance of an aggressive core, which an FPGA or a small chip could not build anyway. The readiness document ([`../pdp64-ooo-readiness.md`](../pdp64-ooo-readiness.md)) and the hardware-vulnerabilities report give the rules a future core would follow. **Benefits.** The decision is reversible in the direction that matters: total store order can be the retreat for a large core. **Impact.** *Kernel:* None today. *Compiler:* None today. *Hardware:* A speculative core would need loads that replay when another core intervenes, and the flag and reservation rules of errata 39 keep that path open.

## 7.12 The atomic and ordering instructions

**7.12.1** The atomic escape provides `CAS`, `SWAP`, `XADD`, `XAND`, `XOR_`, `XXOR`, `XMAX`, `XMIN`, `XMAXU` and `XMINU`, each with a `_DB` variant that adds a barrier, and `LL` and `SC`. *(opcode `0x11`)*

**7.12.2** `LL` takes a reservation on a granule of memory; any write to it by any initiator clears it; `SC` succeeds exactly when the reservation is intact. A short `LL`/`SC` sequence must eventually succeed if no other initiator keeps writing the granule. *(D, errata 45)*

**7.12.3** The read-modify-write atomics are atomic with respect to every initiator, cores and devices alike. *(D)*

**7.12.4** `FENCE` orders device accesses; `WFE` and `SEV` wait for and signal an event; `ISYNC` makes earlier system-register writes take effect; `HINT #n` has no architectural effect (1 pause, 2 speculation barrier, others reserved). *(D, errata 39)*

*Commentary.* **Precedent.** The PDP-11's read-modify-write instructions were indivisible on the Unibus (the `DATIP`/`DATO` pair); the VAX had interlocked queue and bit instructions. **Trade-offs.** A bus lock is simple and does not scale as cores multiply; a monitor (reservation) maps onto the memory systems that FPGAs and modern chips use, at the cost of forward-progress rules. **Improvements.** The pdp64 offers all three designs found on other machines (load-linked/store-conditional, compare-and-swap, fetch-and-operate), more atomic operations than any architecture surveyed. **Benefits.** A kernel lock needs one instruction. **Modern comparables.** RISC-V `LR`/`SC` and the `AMO` set; AArch64 load-exclusive and its large-system atomics; x86 `LOCK`-prefixed read-modify-write. **Use.** `CAS` for lock-free structures; `XADD` for counters; `LL`/`SC` for anything else; `WFE` for the idle loop. **Impact.** *Kernel:* A lock is one instruction, and the `_DB` forms need no separate fence. *Compiler:* C11 atomics map one-to-one, no ordering fences are emitted under sequential consistency, and a `LL`/`SC` loop must be generated in the constrained form (short, no other memory access inside). *Hardware:* The reservation is a granule tag in the cache controller, and the read-modify-write atomics use an exclusive access with hardware retry.

<!-- entries:7.12 -->
**The instruction entries for this section are in chapter 9, section 9.13:** each entry there is complete (syntax, encoding diagram, operation, flags, exceptions, status); this chapter gives the reasons, the history and the use.

| Entry | Mnemonics |
|---|---|
| [Compare and swap](09-isa.md#cas-compare-and-swap) | `CAS`, `CASDB` |
| [Atomic exchange](09-isa.md#swap-atomic-exchange) | `SWAP`, `SWAPDB` |
| [Atomic fetch and add](09-isa.md#xadd-atomic-fetch-and-add) | `XADD`, `XADDDB` |
| [Atomic fetch and and, or, xor](09-isa.md#xand-atomic-fetch-and-and-or-xor) | `XAND`, `XANDDB`, `XOR`, `XOR_DB`, `XXOR`, `XXORDB` |
| [Atomic fetch and minimum or maximum](09-isa.md#xmax-atomic-fetch-and-minimum-or-maximum) | `XMAX`, `XMAXDB`, `XMIN`, `XMINDB`, `XMAXU`, `XMAXUDB`, `XMINU`, `XMINUDB` |
| [Load-linked and store-conditional](09-isa.md#llsc-load-linked-and-store-conditional) | `LL`, `SC` |
<!-- /entries:7.12 -->

## 7.13 Still open

The transport and the bus's own atomics mapping (decision R4), the interrupt controller and routing (R1), starting the other cores (R2, B2), how coherence scales beyond four cores (R3), the wake rule of `WFE` (P1), and lock scaling above a few cores, which is a kernel design question the instruction set does not settle.
