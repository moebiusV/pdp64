# Security proposals, round two: replies to the annotations

[← pdp64 index](../README.md)

For the author's annotation. This answers the four annotations on [`security-proposals.md`](security-proposals.md) and the questions in [`retire-stage-candidates.md`](retire-stage-candidates.md). The disposition of the nineteen candidates is errata 84. Priorities are those of errata 83.

## 1. A write-only absorbing pool (reply to the P9 annotation)

**The proposal.** A pool of 256 or 512 bytes. A write mixes the written value into the pool and cannot be read back. A read returns a fresh value derived from the pool. The effect is a hardware entropy pool with two operations, *absorb* (mix input in) and *squeeze* (take output out), the shape of a sponge construction (a state that soaks up input and is then drained for output) *(from memory, not confirmed)*.

**What is good about it.** The pool cannot be read, so a bug or an attacker cannot copy its state. Absorbing is one store, with no function call, so a kernel can feed it every interrupt timing at almost no cost. The algorithm is fixed and known, and the register interface is two words wide.

**What it does not do.**

1. *It creates no entropy.* Mixing spreads the entropy that was written; it does not add any. The "new bit of randomness" is only as good as what was absorbed, so a physical source must feed the pool inside the device.
2. *A read has a side effect.* Each squeeze advances the pool so that earlier outputs cannot be recomputed from later state (forward secrecy). That is a strange side effect (priority 1) and is acceptable only on a device page that is strongly ordered and never accessed speculatively. A load restarted after a fault merely discards one output, which is harmless.
3. *It is one pool for the machine.* Each process still needs its own generator for fork safety and speed (OpenBSD's `arc4random` keeps one per process, seeded from the kernel), so the pool seeds those; it does not replace them.
4. *The algorithm is frozen in silicon unless it is updatable.* A flaw in a hardware generator has shipped before and was repaired in firmware *(from memory, not confirmed)*. A version register and updatable firmware keep it repairable.

**Would it break if OpenBSD changed its algorithm?** No, provided the OS treats it as one more source and not as the generator. OpenBSD mixes every hardware source through `enqueue_randomness()` and trusts none alone (`security-proposals.md` section 1, commits cited there). It would absorb into the device, squeeze from it, and feed what it reads into its own generator. Its algorithm is untouched.

**Proposal.** Build it as a platform device (memory-mapped, privileged), not as an instruction or a system register:

| Register | Access | Meaning |
|---|---|---|
| `ABSORB` | write 64 bits | mix into the pool |
| `SQUEEZE` | read 64 bits | next output; ratchets the pool |
| `SEED` | write, firmware only, once per boot | initial seed |
| `STATUS` | read | seeded flag, sources present, algorithm version |

This is the hardware behind the virtio-rng device of the P9 lean: the same four registers sit behind a virtio-rng function for standard software. No opcode (priorities 2 and 3), a small amount of logic (priority 4), and it adds a source without disturbing the OS generator (priority 1).

**Your annotations:**

&nbsp;

## 2. Constant time in a core class, and what `MASKEQZ` is

**`MASKEQZ`.** A LoongArch instruction: `maskeqz rd, rj, rk` writes zero to `rd` when `rk` is zero and `rj` otherwise *(from memory, not confirmed)*. Two of them, one with the opposite condition, ORed together, make a select with no branch. It is how constant-time code picks between two values without a data-dependent jump. The pdp64 has no such instruction yet; `pdp64-isa.md` lists it as on hold, and `hardware-vulnerabilities.md` wrongly writes as if it exists. The name is incidental: the need is a branch-free select.

**The proposal.** No crypto devices. Instead, a core can be configured, by firmware before it starts, into a *secure class*: in order, no speculation, every instruction of fixed latency, `DIT` (data-independent timing) always on. Other cores keep speculation, out-of-order execution and tickless operation, each switchable per core. One core is then dedicated to cryptography.

**Assessment.**

* *It fits what is already decided.* The core-class register of manual 7.8.4 identifies a core's class, and errata 76 already has dedicated cores for graphics, network and audio. A secure core is a fourth. Scheduling is by affinity.
* *It answers OpenBSD's objection.* The strongest evidence against crypto devices was OpenBSD removing its PCI crypto drivers because "scheduling crypto tasks via PCI is probably slower than the CPU" (commit 0a828ff4, 2021, `security-proposals.md` section 2). Work that stays on a CPU in the same memory has no bus crossing, no DMA exposure and no small-message penalty.
* *"Per core" is cheapest as two kinds of core.* Switching a large out-of-order core into a faithful in-order mode is a second design to verify. A small in-order core of the same ISA is simpler, and the class register tells software which is which. In iteration one every core is in order anyway, so the class exists from the start.
* *Constant time needs more than in-order.* Multiply and divide must have no early exit. The data cache must not leak: a secure core's lines must not be observable by other cores (private L1 or way partitioning, candidate 13). Software must still avoid secret-dependent addresses, because a table lookup is a timing channel on any cache.
* *Speed.* The pdp64 has no AES or SHA instructions. Constant-time AES in software is several times slower than hardware AES *(from memory, not confirmed)*, which is the point of the accelerators OpenBSD's commit mentions. If throughput matters, AES and SHA instructions (constant time by construction) can be added to the secure class later; they are not needed to start.
* *Keys.* They live in the secure core's memory, protected by ASID and the IOMMU domain, and never cross a bus.

**Recommendation.** Adopt the secure core class in place of crypto devices for iteration one. Keep the core set that is always promised: carry-less multiply, rotate, and a branch-free select (name to be chosen). Define `PSW.DIT` as always on in the secure class. A PCI Express crypto card remains attachable (any card may be), but is not part of the standard.

**Your annotations:**

&nbsp;

## 3. A 64-bit literal inside the instruction (reply to the P18 annotation)

**The two readings.**

* *An exception for the load at the next address.* An execute-only page would allow a data load whose address is exactly the byte after the instruction. This weakens execute-only (a data path touches the page), needs the permission check to compare addresses, and leaves the processor to skip over the literal afterwards. In effect it is an inline literal done the hard way.
* *An instruction that carries the literal.* The 64 bits follow the opcode and are fetched with the instruction, on the instruction side. No data load touches the page, so execute-only needs no exception and no pool exists. This is the second half of the annotation, and it is better.

**Proposal.** `MOVQL #imm64, Rd`: the opcode parcel (with `Rd`), then four parcels of literal; 10 bytes, 5 parcels. Binary64 constants load with the same instruction, since floating-point values live in the general registers.

| Way to load a 64-bit constant | Bytes | Instructions | Data-side read of code |
|---|---|---|---|
| Pool in text, `MOVQ d(PC)` | 4 + 8 | 1 | yes |
| Separate read-only pool, long form | 6 + 8 | 1 | no (other page) |
| Build from two 32-bit pieces | 12 | 2 | no |
| **`MOVQL #imm64`** | **10** | **1** | **no** |

It wins on priority 2 (one instruction) and priority 3 (10 bytes against 12 or 14) and satisfies priority 1 (execute-only is clean, one less section, no pool to flush).

**Cost, written down.**

* It breaks the maximum of three parcels (errata 31) and the rule that length is a function of the `len` field alone. To keep length knowable from the first parcel it must be a top-level opcode, using one of the five reserved slots (`0x2B` to `0x2F`), and the length logic gains one term. That term is on the fetch path, which is the critical path; its cost is a gate delay to be measured, not a certainty.
* The literal's bytes can be reached by jumping into the middle of the instruction, because instructions sit on 2-byte boundaries. Candidate 5 (landing pads required on indirect-branch targets) is the existing defence.
* The fetch buffer must hold 10 bytes; at 2-byte alignment that is still at most two aligned quads.

**How often it would run.** Integer code builds addresses with `LEA d(PC)`, so the users are binary64 constants, hash and cipher constants, and large masks. The count of pool loads in the compiled corpus (`docs/codegen-data`) decides whether the slot is worth spending.

**Recommendation.** Adopt `MOVQL`, subject to that count and to the fetch-path timing, and drop the separate-pool section of P18 in its favour. Keep the pool and the segment flag only for objects built before the instruction existed.

**Your annotations:**

&nbsp;

## 4. One IOMMU design from the five options (reply to the F25 annotation)

**One line for each option.**

| # | Option | In one line |
|---|---|---|
| 1 | Paged IOMMU with copying | A standard page-granular unit; small or unaligned buffers are copied into pre-mapped bounce pages. No new hardware, but copies cost time. |
| 2 | Byte range in each leaf | The same paged unit, but each entry also records the first and last valid byte of the page, so a device cannot touch the rest of it and no copy is needed. |
| 3 | Per-queue windows | No paging for devices: each queue gets base-and-length windows. Exact to the byte and cheap to revoke, but scatter-gather fits badly. |
| 4 | Trust tiers by port | Policy, not hardware: trusted internal devices get option 2; anything external, hot-plugged or behind a bridge without ACS gets bounce-only mappings. |
| 5 | Cooperating devices with handles | Devices that opt in get a region and offsets. It protects nothing against a hostile device, so it is rejected. |

**The synthesis, least disruptive.** The ten layers L1 to L10 apply to every option and are processor-side, invisible to cards (errata 81). On top of them:

1. *The base is a standard paged IOMMU whose entries use the CPU's page-table format* (F4). It reuses the page walker's design; the only new hardware is a second walker, the fault ring and the invalidate register.
2. *The one format extension is option 2's byte range,* in reserved leaf bits 40 to 63 (12 + 12 bits). It answers Thunderclap's page-granularity finding without copies and without touching a card.
3. *Option 4 is added as policy,* in the kernel's trusted-device list and the root complex's knowledge of which ports are internal. It costs no hardware. It means option 1's copying path exists only for untrusted devices, so it is rarely executed.
4. *Option 3 is left out for now.* Revisit only if rings turn out to want it and the window registers prove cheap.
5. *Option 5 is rejected.*

**To verify before building:** that bits 40 to 63 of the leaf are free in the page-table format (`pdp64-system-architecture.md`); and that a PCI Express memory request never crosses a 4 KB boundary, which option 2 relies on *(from memory, not confirmed)*.

**What changes where.** Root complex and IOMMU: a walker, two extra leaf fields, the fault ring. Kernel: `bus_dma` map and unmap set the byte range. Cards: nothing.

**Your annotations:**

&nbsp;
