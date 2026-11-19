# The IOMMU: proposals for the four open points

Status: **proposals for the owner's review. Nothing here is decided, nothing is in the manual, the grammar, the assembler, sim64, QEMU or LLVM.** Written 2026-11-19 after errata 181 (the IOMMU is to be finished now, as proposals for review, and then built into the QEMU model).

How to read it. Each of the four open points of manual J.2.3 has its own section with the same parts: the options, for and against, the precedents (each claim marked **verified: FILE** when I read it in a file on this machine, or **unverified: general knowledge** when it is from memory), a recommendation, and what it would cost. Then the register block, the QEMU model, the things this document does not settle, and last a numbered list of the decisions, each with my recommendation, so that all can be answered in one pass. Where a number below (a field width, an entry size) is mine, it is a *proposal*, and says so. Costs are qualitative; where I give a size it is arithmetic from the proposal, not a measurement.

Files that were read: the manual sections named in the task (2.3 to 2.5, 2.11, 5.4, 5.10, 6.6 to 6.8, 6.14, appendix J.2.3 and J.6.3, B.2.11), errata 61, 75, 85, 97, 178 and 181, decisions-pending F25, the QEMU model in `qemu/` (its `README.md`, `hw-pdp64/virt.c`, `target-pdp64/mmu.c`), the QEMU v11.1.2 source for the Intel, AMD, ARM and RISC-V IOMMU models, and the Linux header `linux/iommufd.h`.

## 0. Words used here

* **Requester identity (bus-device-function, BDF).** Every PCI Express packet a device sends carries the 16-bit number of the function that sent it: 8 bits of bus, 5 of device, 3 of function (manual 2.4: the enumeration loops over exactly these). The IOMMU uses it to tell devices apart. That a bridge or switch leaves this number unchanged is **unverified: general knowledge**, and has exceptions (a bridge to old PCI replaces it, also unverified).
* **Device address.** What a device puts in its descriptors and packets. The IOMMU turns it into something else, or refuses it.
* **Device table.** The IOMMU's table that says, for each requester identity, what to do with that device's addresses. One **device entry** per identity.
* **Domain.** A set of mappings that one or more devices share (manual 2.11). Errata 85: each device is its own domain.
* **Cached translation (IOTLB).** A copy, kept inside the unit, of a translation it has already worked out, so that it need not walk the tables again. The same idea as the processor's translation buffer of manual 6.8, and it has the same danger: a stale copy.
* **Fault.** A refused access, or an access the unit could not translate.
* **Posted write.** A write that is sent and not answered (manual 2.8 commentary: "PCI Express posts writes"). Nobody can be told it failed by an answer, because there is none.
* **Completion.** The answer to a read. A device that sent a read waits for it.
* **Two names for the two levels (mine, to avoid a clash of words).** The manual's processor has a "first" and a "second" stage (6.14.4): guest tables, then the hypervisor's tables. J.2.3 and 6.14.6 say "a second level that the guest can see" for the IOMMU, and the word "second" then points in two directions. I use **level A** for the table that translates a *device address* (in the native kernel it is the kernel's, under a guest it is the guest's) and **level B** for the table that translates a *guest-physical address* to a physical one (the hypervisor's). A native kernel uses level A alone, its output being physical. An assigned device under a guest uses A then B. What I take 6.14.6 to mean is decision 1 in section 9.

## 1. What is already decided (and so not argued again)

* An IOMMU exists (errata 75). Translation is on by default, each device is its own domain, descriptors hold no kernel pointers, ring mappings are permanent, small buffers are bounced (errata 85, F25).
* The leaf of the IOMMU table shares bits 0 to 39 with the processor's page-table entry; bits 40 to 63 are free (errata 85). The processor's entry: V in bit 0; R, W, X, U, G in 1 to 5; A, D in 6 and 7; the memory type in 8 and 9; the page number in 12 to 39; a set undefined bit is a fault; a leaf at level 1 or 2 is a 2 MB or 1 GB page (manual 6.7.1, 6.7.2). The walker never writes a table (6.8.1).
* No address bit says "device" (errata 97), so a device's DMA into another device's window is an ordinary address and "is refused by the IOMMU, not by the address" (manual 2.3.5 commentary).
* Tables and caches are reset together or not at all (6.8.5, B.2.11.2, errata 178); a guest or domain reset discards its cached device translations (J.2.3).
* Devices are assignable to guests through the IOMMU with a guest-visible second level; the hypervisor mode, two-stage translation and the guest tag are decided; no nesting of hypervisors in version 1 (errata 181, 6.14.4, 6.14.6, 6.14.7).
* Buffers and rings are uncached and DMA goes around the processor's data cache (5.10.1), so the unit sits on the memory side of the cache and has no cache-coherence duty.

## 2. Point 1: the format of the device table above the leaf

**The question.** Given a packet with a 16-bit requester identity and a device address, how does the unit find the page table to use? Everything between "identity" and "the leaf entry whose bits 0 to 39 match the processor's" is open: the device table (how many levels), the device entry (what it says), and the levels of the page table itself (how many, how big a device's address space).

### Options

**1A. A flat table, one device entry for each of the 65,536 identities.** For: one memory read to find the entry; nothing to get wrong. Against: if every identity had an entry of the size proposed below (32 bytes) the table would be 2 MiB (65,536 x 32), almost all of it empty, and it must be one contiguous block allocated at boot. Precedent: AMD's IOMMU has such a table, entry size 32 bytes, base address in bits 12 to 51 of a register, size given in units of 4 KB (**verified: QEMU `hw/i386/amd_iommu.h`**, `AMDVI_DEVTAB_ENTRY_SIZE`, `AMDVI_MMIO_DEVTAB_BASE_MASK`, `AMDVI_MMIO_DEVTAB_SIZE_UNIT`). Whether the real hardware does everything the model does is **unverified**.

**1B. Two levels split by bus, then by device and function (256 x 256).** For: follows the way people think of PCI; a bus with no devices costs one empty entry. Against: the lower table is 256 entries, which is a whole page only if an entry is 16 bytes; with a 32-byte entry it is two pages. Precedent: Intel VT-d's root table (one entry per bus, 256 entries) and context table (one per device-function, 256 entries) (**verified: QEMU `hw/i386/intel_iommu_internal.h`**: `VTD_ROOT_ENTRY_NR` and `VTD_CONTEXT_ENTRY_NR` are the page size divided by a 16-byte entry; the context entry holds a domain identifier, a fault-processing-disable bit and a translation type).

**1C. A directory and a leaf, split by the number of entries that fit a page: 9 bits and 7 bits.** The top 9 bits of the identity pick one of 512 directory entries (8 bytes each: valid, plus a page number); the low 7 bits pick one of 128 device entries (32 bytes each) in a leaf page. 512 x 8 and 128 x 32 are both exactly 4 KB. For: every table is one page, like the processor's; sparse (a machine with a dozen devices needs the directory page and a few leaf pages); the walk is the same shape as the processor's walk, so the kernel's routines that allocate and fill page-table pages serve both. Against: a bus is not a clean unit (a bus's 256 identities span two leaf pages). Precedent: this is the RISC-V IOMMU's two-level shape with the 32-byte "base" device context: the unit has modes OFF, BARE, 1-level, 2-level and 3-level; with the base format a 1-level table covers 7 bits of identity, 2 levels 16 bits and 3 levels 24 bits, and a directory entry holds only a valid bit and a page number, any other bit set being a "misconfigured" fault (**verified: QEMU `hw/riscv/riscv-iommu.c`** `riscv_iommu_ctx_fetch`, and `hw/riscv/riscv-iommu-bits.h`, `RISCV_IOMMU_DDTP_MODE_*`, `RISCV_IOMMU_DDTE_VALID`).

**1D. A small fixed table of domains plus a map from identity to domain in a register file in the root complex** (J.2.3 Option 2). For: cheapest in hardware; fits a first FPGA board. Against: a fixed number of devices (a hot-plugged device may find it full); it does not scale to the virtualization the owner has chosen, where each of a guest's assigned devices needs an entry of its own. I do not recommend it as the architecture; an implementation with few devices can still keep a small cache of entries.

**1E. The ARM way: a stream identifier, assigned by the system, indexes a stream table that is linear or two-level (split chosen by a register).** The identifier is not the PCI number but a number the platform derives from it. For: a platform with many kinds of master, not only PCI. Against: a mapping step (the platform's "iommu-map") sits in front. Precedent: the SMMUv3 model reads `STRTAB_BASE_CFG` with a format and split field (**verified: QEMU `hw/arm/smmuv3.c`**, lines near 1700), and QEMU's RISC-V board writes an `iommu-map` property for the device tree (**verified: QEMU `hw/riscv/virt.c`**). The pdp64 has one kind of master that needs it (PCI Express), so the extra mapping buys nothing now.

### The device entry (proposal, 32 bytes, four 64-bit words)

| word | content |
|---|---|
| 0 | bit 0 **V** (valid; 0 means every access of this device is refused); bit 1 **MUTE** (refused accesses are not logged; for a device already known to be hostile); bits 2-3 **STAGES**: 1 = level A only, 2 = level B only, 3 = A then B (0 reserved); bits 4-6 **LEVELS_A** (3, 4 or 5 levels, as the processor's walk, 6.6.1); bits 7-9 **LEVELS_B**; bits 16-31 **DOMAIN** tag; bits 32-47 **GUEST** tag (0 is the host itself); other bits reserved, must be zero |
| 1 | physical address of the top table of level A (a **guest-physical** address when STAGES is 3) |
| 2 | physical address of the top table of level B |
| 3 | reserved, must be zero (kept free for the interrupt-remapping table of J.6.3 Option 2, which is a per-device pointer) |

The fields are my proposal. Rules taken from the processor, 6.7: a set reserved bit makes the entry bad and every access of the device a fault (fail closed), so that a wild value written by the kernel is caught. There is **no bypass mode** that skips translation: errata 85 says translation is on by default, so "the device sees physical addresses" is built, when wanted, as a level-A table with one 1 GB leaf, an ordinary table with ordinary faults. The RISC-V unit has a BARE mode that passes addresses through (**verified: `riscv-iommu.c`**, `RISCV_IOMMU_DDTP_MODE_BARE`); I recommend the pdp64 does not copy that.

### The page table below the device entry (proposal)

One entry shape at every level, as the processor has (6.7): V, R, W, X, A, D and the page number in place; V set with R, W, X clear is a pointer; a leaf at level 1 or 2 maps 2 MB or 1 GB and must be aligned to its size. For a device:

* Used: **V, R, W**, and the page number in bits 12 to 39. A leaf must have R or W. **W without R stays reserved**, as in the processor (one rule for the kernel's mapping code; a receive buffer that the device can also read costs nothing).
* **X, U, G must be zero** (a device does not fetch instructions and has no user mode); **MT must be zero** (DMA goes around the cache, 5.10.1, so a memory type has no meaning). **A and D are ignored**: a device cannot take a page fault and try again in version 1, and the unit, like the processor's walker, never writes a table (6.8.1), so there is nobody to set them. These are proposals; the alternative for A and D is "must be set, else a fault", which a kernel that reuses its processor-entry builder would satisfy for free. The alternative costs the kernel one more rule to remember for no gain.
* **Bits 40 to 63** (free, errata 85): I recommend to *allocate none of them now*, and to say that they continue the page number in place if the physical address is wider than 40 bits, whatever form J.6.2 gives the processor's wide entry. The reason: J.6.2 is still open, and a bit given away now could be wanted for the address. If the owner prefers the free bits to hold something else (a mapping cookie for the kernel's own use, for instance), the two uses conflict and must be chosen between.
* The device level is **3, 4 or 5 levels, chosen per device in its entry**: a device that can drive only 32 or 39 address bits gets a 3-level table.

### Recommendation for point 1

**1C**, with the device-table register (section 7) carrying a mode field: blocked (the reset value: no device may do anything), one level (7 bits of identity: enough for the small boards, one page), and two levels (the full 16 bits). A third level is reserved for a machine with more than one PCI Express segment, which this document does not assume; the unit has one identity space. The device entry as above, four words, with word 3 reserved. Level A and level B tables in the processor's shape.

### Cost

* **Hardware:** a walker for the device table (two reads: directory, then entry) in addition to the page-table walk (three to five reads, as the processor's) and a cache so that the common case does not walk. The page-table walker can be the same state machine as the processor's, because it is the same shape; the shared bits make shared tests and shared constants.
* **Kernel:** one routine to find or create the leaf page for an identity, one to fill an entry, and the rule that an entry is written *before* the device's bus-master bit (bit 2 of its command register, manual 2.4) is set and invalidated *after* the device is removed (2.4.9).
* **Unknown:** the cost on a real FPGA board in logic and memory is not known; no design exists and none was measured.

## 3. Point 2: where the unit sits

**The question.** Between the devices and memory there is a tree of root complex, bridges and switches (manual 2.2, 2.4.3). The unit must see every device's access before it reaches memory, and must still know which device it came from.

### Options

**2A. One unit at the root complex, on the upstream side of every root port.** For: one set of tables, one register block, one fault log; every device is behind it; the requester identity is intact in the packet when it arrives (**unverified: general knowledge**). The unit exists from reset, before any enumeration, so "translation on by default" is true from the first instruction: a device that is not yet enumerated cannot DMA, because no entry exists. Against: it cannot see traffic that never goes to the root complex. If two devices sit behind one switch and the switch lets one send to the other directly (peer-to-peer), the unit does not see it. PCI Express has an access-control feature of switches that forces such traffic upstream, and a switch that lacks it does not (**unverified: general knowledge**; the pdp64's own bridges can be specified to force upstream, but an ordinary card or switch "works unchanged", manual 2.3.4). A related limit: devices behind a bridge to old PCI share one identity, so they cannot be told apart (also **unverified**).

**2B. A unit in each bridge or root port.** For: each sees the peer-to-peer traffic below its bridge; scales to many roots. Against: many register blocks, many fault logs, many copies of the tables to keep in step, and the kernel must program each; it multiplies exactly the stale-copy problem that errata 178 is about. Intel's machines have several remapping units in a system, each covering a set of devices (**unverified: general knowledge**; in QEMU the Intel model is one device, **verified: `hw/i386/intel_iommu.c`** exists as one unit).

**2C. A unit beside the memory controller, between the fabric and memory.** For: it sees every bus master of any kind, including the interrupt controller if it becomes a master that writes rings (J.6.3 Option 5) and any on-chip DMA engine; one choke point before memory. Against: by then the identity must have been carried through the on-chip fabric on every transfer, and the fabric designer must keep it; it is the farthest from the device and sees peer-to-peer traffic least of all. The ARM SMMU is a unit of this general kind with stream identifiers supplied by the master side (**unverified: general knowledge**; the model is `hw/arm/smmuv3.c`).

**2D. The unit as a PCI Express function of its own** (found by enumeration). For: no fixed address. Against: a unit found by enumeration does not exist before the enumeration; it contradicts "on by default". QEMU has the RISC-V unit both ways, as a PCI function and as a platform device (**verified: `hw/riscv/riscv-iommu-pci.c`, `riscv-iommu-sys.c`** exist). This is a statement about where its *registers* are (section 7), not where it sits in the data path.

### Recommendation for point 2

**2A**, one unit at the root complex, its registers a block in the root complex's own register block (J.2.5 Options 1 or 3: base passed once in the boot-information block), *not* a PCI Express function. Two rules go with it, and both are limits to state plainly:

1. The pdp64's own bridges and root ports force every packet upstream. (A statement about our hardware.)
2. A set of devices that a third-party switch lets talk to each other directly **cannot be given separate domains by the unit**, because it never sees their traffic. The kernel must put such a set in one **group**: they are assigned together (to one guest) and share one domain. This is the one place where errata 85's "each device is its own domain" cannot hold. The kernel needs to learn which devices form a group; how it learns is not settled here (it needs a property of the switch, which the pdp64 may not be able to read; **unverified**).

Entries for several identities may point at the same tables, so a group is not a new mechanism.

### Cost

* **Hardware:** the unit is one place; every packet from the root ports goes through it; the root complex gets a bounded cache and a walker. Less than 2B (one of everything), more than nothing.
* **Kernel:** one driver, one register base. Group handling is code that does not exist in a machine with isolation everywhere.
* **Unknown:** how often a real switch lacks the access-control feature; whether the pdp64 can read it.

## 4. Point 3: how a refused access is reported

**The question.** Three audiences: the device (it sent a packet), the kernel (it owns the tables), and, for an assigned device, the guest. Plus the pressure of an attack: a hostile device can send a refused access a million times.

### What the device sees

The device is either answered or it is not. A *read* waits for a completion; a *posted write* has none.

* **Drop and say nothing to the device.** The write vanishes; for a read, no answer comes, so the device waits until it gives up (PCI Express devices have a completion timeout; how long, and what the device does then, is **unverified: general knowledge**). Bad: the wait is the device's business, not ours, and a device without a timeout hangs.
* **Answer a read with an error completion** (the device is told that the request was refused: an "unsupported request" or "completer abort" status; **unverified: general knowledge**), and drop a posted write (counted and logged). The device's driver sees the error at once, the device can set its own error status (the PCI status register has "received master abort" and "received target abort" bits, bits 13 and 12, **verified: `linux/pci_regs.h`**: `PCI_STATUS_REC_MASTER_ABORT`, `PCI_STATUS_REC_TARGET_ABORT`). Not every device handles it well (**unverified**).
* **Answer a read with all ones or zeros as if it succeeded.** This is what some platforms do (**unverified: general knowledge**). It is the worst case: a descriptor read that returns all ones is a length of 4 GB. The manual's rule is the opposite: all ones only for an empty configuration position, never for other missing things (2.4.7, 2.9).
* **Stall the request and let the kernel resolve it, then resume.** The SMMU has this: events and commands for "stall", "resume" and "stall terminate" (**verified: QEMU `hw/arm/smmuv3-internal.h`**, `SMMU_CMD_RESUME`, `SMMU_CMD_STALL_TERM`, and the page-request event). It exists to serve devices that fault pages in. Not for version 1: it blocks the fabric while the kernel thinks, and a hostile device could block it forever.

### What the kernel sees

* **An interrupt only, no record.** Cheap, no information.
* **A log of records in a ring in memory, read by the kernel, with an interrupt when the ring goes from empty to not empty.** Every precedent has this: Intel's fault recording registers with an interrupt (**verified: `intel_iommu.c`**, `vtd_report_frcd_fault`, `vtd_generate_fault_event`, and a table of fault reasons in `intel_iommu_internal.h` `VTD_FR_*`), AMD's event log (**verified: `amd_iommu.c`**, `amdvi_log_devtab_error`, `AMDVI_EVENT_*`), ARM's event queue with its own event codes (**verified: `smmuv3-internal.h`**, `SMMU_EVT_*`), and RISC-V's fault queue, whose header holds a cause number, a device identity and a transaction type, with separate causes for "DMA disabled", "device-table entry invalid", "misconfigured" and "load fault" (**verified: `riscv-iommu-bits.h`**, `RISCV_IOMMU_FQ_HDR_*`, `RISCV_IOMMU_FQ_CAUSE_*`). A ring in memory, with the unit writing and the kernel reading, is also the shape of the virtqueue (5.4.3: progress is in memory), so the kernel already has the code.
* **A machine check** (manual 2.9.2: imprecise, not restartable). J.2.3 says it: "one that stops the machine is easy to attack". Rejected.
* **An exception at the processor, precise.** Impossible: the access came from a device, long after the instruction that started it retired.

### The log's own problems

* **Overflow.** The ring fills. Proposal: the unit stops adding, sets a sticky overflow bit and counts what it dropped; nothing blocks. Precedent: every unit above has a way of saying "records were lost" (named for RISC-V, Intel and ARM in the headers read; the detail of each was not read).
* **One device floods.** A per-entry **mute** bit lets the kernel stop the log for a device it already has decided about, by setting a bit in the entry. Precedent: Intel's "fault processing disable" bit in the context entry (**verified: `intel_iommu_internal.h`**, `VTD_CONTEXT_ENTRY_FPD`) and RISC-V's "disable translation fault" bit (**verified: `riscv-iommu-bits.h`**, `RISCV_IOMMU_DC_TC_DTF`, and `riscv-iommu.c` near line 613). The kernel's usual policy is better still: on the first fault from a device, reset the device (virtio's "needs reset", 5.11.1) and set its entry invalid.
* **The unit's own table is unreadable** (the device table points at memory that does not exist). Proposal: *fail closed*: a sticky "table error" status bit and an interrupt, and every access of the affected device refused, as an entry with V clear.

### What a record says (proposal, 32 bytes)

| word | content |
|---|---|
| 0 | cause (which check failed: no device entry, entry malformed, no level-A mapping, no level-B mapping, no read permission, no write permission, address out of range, table read failed...), the **stage** that failed (device table, level A, level B), kind (read or write), a valid bit, an overflow bit |
| 1 | requester identity (16 bits), guest tag (16 bits) |
| 2 | the device address |
| 3 | for a level-B failure the **guest-physical address** that failed (as the processor's second-stage fault reports, 6.14.4); otherwise zero |

The cause list is mine; the *kinds* of cause are the ones every precedent has. The exact numbering is a later task.

### Guests

A fault at level A of an assigned device is the guest's fault; a fault at level B is the hypervisor's. The unit has **one** ring, owned by the host. The hypervisor reads it and, for a level-A fault, writes a record into the guest's *virtual* fault ring (in guest memory, as the guest's driver expects) and raises the guest's virtual interrupt (6.14.5). Hardware rings per guest are the alternative; not for version 1 (section 5).

### Recommendation for point 3

**Both**: a read is **answered with an error completion**; a posted write is **dropped and counted** (as 2.4.9 already says for a departed device); and **every refusal is logged** in a ring in memory, with an interrupt on empty-to-non-empty, an overflow bit and count, a per-device mute bit, and fail-closed on a bad table. Never all ones; never a machine check.

**What a device waiting for a read sees**, then: a completion with an error status, in good time. Whether it copes is the device's affair. For virtio devices, the QEMU model shows what to expect in the model: QEMU returns an error result to the device model (a refused translation falls to QEMU's "unassigned" region and the access fails: **verified: `system/physmem.c`** `address_space_translate_iommu`, and `system/memory.c` returning `MEMTX_DECODE_ERROR`), and the virtio device model that receives it marks itself broken and sets `NEEDS_RESET` in `device_status` (**verified: `hw/virtio/virtio.c`**, `virtio_error`), which is exactly 5.11.1 ("a device that is broken sets its needs-reset bit"). The test device `edu` ignores the result of its DMA (**verified: `hw/misc/edu.c`**, the `pci_dma_read` and `pci_dma_write` calls do not look at the return value), so a test must look at memory and at the fault record, not at the device.

**What a real device does on receiving an error completion is not known to me.** The model cannot tell us.

### Cost

* **Hardware:** a small producer for the ring (write the record, advance the tail), one interrupt source, a way to complete a read with an error, three status bits. The error completion is the one item that needs the root complex to be able to answer a read it did not forward.
* **Kernel:** a fault interrupt handler, the policy (reset the device, mark the entry invalid), the forwarding for guests.
* **Risk:** the ring is a place an attacker's flood lands; the mute bit and the overflow rule bound the damage but a driver that does not read the ring in time loses evidence.

## 5. Point 4: a guest-visible second level for assigned devices

**The question.** A guest should be able to own a device and, as its own kernel wants (errata 85's five rules apply inside the guest too), run an IOMMU for it. The hypervisor mode, two-stage translation and the guest tag are decided; the version-1 hypervisor does not nest hypervisors (6.14.7). How does the IOMMU compose the guest's table with the hypervisor's?

### The options

**4A. One level only; the hypervisor emulates a guest IOMMU in software and keeps a combined ("shadow") table.** Every time the guest maps or unmaps for its device the hypervisor traps, works out the combined mapping and edits the unit's single-level table. For: no nested walk in the unit; the cheapest hardware. Against: every guest mapping change is a trap; the shadow must be kept exactly equal to the guest's, and a stale shadow is the CVE-2026-99312 kind of bug (errata 178); this is the "shadow page tables" the manual describes as the slow way (6.14). The owner has already chosen against this as the end state (errata 181, question 5). It stays useful as a *mode*: a guest with no IOMMU of its own gets its device with level B only (STAGES = 2): the guest's device addresses are guest-physical and level B maps them.

**4B. Nested translation in the unit: level A (guest's table, in guest memory) then level B (hypervisor's), composed in hardware.** The unit walks the guest's table and, because the guest's table pointers are *guest-physical* addresses, sends each of them through level B before reading it, then sends the final guest-physical address through level B again. For: no trap on a guest mapping change; the guest's kernel uses the *same driver* as a native kernel (decision 1). Against: a longer walk; a larger unit; twice the translation cases to test, which is the bug source errata 178 is about. Precedent: Intel (the scalable-mode entry's translation type distinguishes first-stage, second-stage and pass-through, **verified: `intel_iommu_internal.h`**, `VTD_SM_PASID_ENTRY_PGTT`, and the Linux header has a "nest parent" flag for the hypervisor's table and a "VT-d stage-1" structure whose fields are the guest's page-table address and width, **verified: `linux/iommufd.h`**, `IOMMU_HWPT_ALLOC_NEST_PARENT`, `struct iommu_hwpt_vtd_s1`); ARM (the IOTLB key has both an ASID and a VMID, **verified: `hw/arm/smmu-common.h`**, `SMMUIOTLBKey`; commands to invalidate by stage 2 address and by VMID, **verified: `smmuv3-internal.h`**); RISC-V (a device context holds a G-stage pointer with a 16-bit guest-space identifier, GSCID, and a separate first-stage pointer, **verified: `riscv-iommu-bits.h`**, `iohgatp`, `RISCV_IOMMU_DC_IOHGATP_GSCID`, and the invalidate commands name a PSCID and a GSCID, `RISCV_IOMMU_CMD_IOTINVAL_*`). Whether each real chip implements all of this the way its model does is **unverified**. The AMD model I read does not do nested translation (**unverified**: I did not read it closely enough to say; the real chip has a guest-translation feature, general knowledge).

**4C. Nested, but the guest's table also holds the hypervisor's mappings** (a "pre-composed" table made by the guest at the hypervisor's request). Not an option: it hands the guest control of host addresses.

### Who writes what (the point that matters most for security)

In every nested precedent the **device entry stays the host's**. The hypervisor writes the real device entry; the guest supplies, through the hypervisor, only the root of its own level-A table and its format. The guest never writes the real device table, so it cannot name a device that is not its own or change its guest tag. The guest sees a *virtual* unit with the same registers as the real one (section 7); the hypervisor traps each access to that virtual register block (it is a guest-physical page left unmapped in the guest's level B, so a touch is an exit to the hypervisor), checks it and applies it to the real entry or the real command ring. That is *trap-and-forward for the control path* and *hardware nesting for the data path*. It is the cheapest division. A guest-visible hardware command ring (a ring in guest memory that the unit consumes directly) would need the unit to translate the guest's device identities and guest tags per command, and one ring per guest; I recommend leaving that out of version 1.

### The guest tag, and the cache

The processor's second stage has a **guest tag** in every translation-buffer entry (6.14.4). The unit uses the same tag, so one number names one guest everywhere. I propose:

* The tag is the same width and the same number space as the processor's guest tag. The width is not stated in the manual (6.14.4 says "details to be determined"); if the processor takes 16 bits, as its address-space number has (6.8), the unit's field above is 16 bits. This is a dependency, not a decision.
* **Guest tag 0 is the host.** A native kernel's entries have tag 0.
* The cached-translation key is **(requester identity, guest tag, domain tag, device-address page, level)**. Including the requester identity in the key means that invalidating a device discards *everything obtained through its entry*, so the two-step mistake of Intel's design (a cached entry and a cached translation invalidated by separate commands, **verified: `intel_iommu_internal.h`**: `VTD_INV_DESC_CC` and `VTD_INV_DESC_IOTLB` are different commands) cannot be made.
* The domain tag is kept in the key (the tag comes from the device entry) because errata 85 speaks of a unit of sharing, and invalidation of a whole domain at once is wanted for a group (section 3). Each device is its own domain by default, and the kernel can then set the domain tag to the same number as the device's number.

### Invalidation: the rule of 6.8.5, written for the unit

6.8.5 says the state registers and the cache are cleared together or not at all. The unit's translation state lives in two places: *memory* (the device table, the page tables) and *registers* (the device-table base, the enable, the ring pointers). The hardware cannot make a write to memory and a cache discard happen together, so the promise is split in two:

1. **Register rule (hardware, like 6.8.4(a)).** A write that *changes* the device-table base or mode, a write of the reset bit, and a machine reset, each **discard every cached device entry and every cached translation of the unit**, in the same step. After a reset nothing from before can be used (6.8.5, errata 178(e)).
2. **Memory rule (software, through commands).** After the kernel changes a device entry or a page-table entry, it must issue an invalidate and wait for it to finish before relying on the change:
   * **invalidate device** (requester identity): discards the cached entry for that device and *every* translation obtained through it; **does not complete until the device's requests already in flight have either finished or been refused** (so that after it, nothing of the old mapping can still land: 2.4.9's "in-flight transactions are aborted");
   * **invalidate domain** (domain tag), **invalidate guest** (guest tag): all cached entries and translations carrying the tag, in every device entry that has it;
   * **invalidate page** (guest tag, domain, device address, size): an optional refinement;
   * **invalidate all**;
   * **sync**: completes when every earlier command has taken effect and writes a value to a memory address the command names, so the kernel can wait without polling a register. All the precedents have this: RISC-V's IOFENCE with a data write, ARM's CMD_SYNC, Intel's invalidation-wait descriptor, AMD's COMPLETION_WAIT (**verified: `riscv-iommu-bits.h`** `RISCV_IOMMU_CMD_IOFENCE_*`; **`smmuv3-internal.h`** `SMMU_CMD_SYNC`; **`intel_iommu_internal.h`** `VTD_INV_DESC_WAIT`; **`amd_iommu.h`** `AMDVI_CMD_COMPLETION_WAIT`).

   An implementation may discard more than a command asks (as 6.8.4 says of the processor): no program may depend on an entry surviving. The QEMU model discards everything on every command and keeps the cache only to make a stale entry possible to find. A hole that does not exist in the processor but does in the unit: a **page-table entry change at level B** invalidates the translations of *every* device of the guest (a guest-physical page has no device number), so "invalidate guest" is the right command; a finer one (by guest-physical page) is an optimisation. ARM has a command by stage-2 address (**verified: `SMMU_CMD_TLBI_S2_IPA`**).

3. **The guest reset sequence** (the stale-entry case of errata 178 for devices; B.2.11.2): (a) stop the guest's processors; (b) for each device assigned to the guest, reset the device and set its entry's V to 0 or its STAGES and roots to the fresh values; (c) **invalidate guest** for the guest's tag, then **sync**; (d) only then reuse the tag or free the guest's tables. Step (c) is what B.2.11.2 requires; the hardware cannot do it for the hypervisor. A hardware guard I do propose: *a device entry whose guest tag is in the process of invalidation faults every access of its device until the invalidation completes* (the device is blocked while the cache is being cleaned). That costs a flag and prevents a use of an old entry after the command was issued.

### What the guest sees on a fault

As in section 4: the hypervisor translates a level-A fault into the guest's virtual log, and a level-B fault is the hypervisor's own.

### Interrupts of an assigned device

A device's interrupt is a write (manual 2.6) to an address the guest set up, which is a guest-physical address. For a guest it must reach the guest's virtual interrupt line (6.14.5). With **J.6.3 Option 1** (a per-core interrupt file, messages only) the write goes to the hypervisor's page for the core, and the hypervisor injects the virtual interrupt: works, costs an exit per interrupt. With **J.6.3 Option 2** (interrupt remapping in the same unit) the device entry's word 3 would point at a remapping table, the guest's index would be mapped by the host to a virtual interrupt, and no exit is needed. This is why word 3 of the device entry is kept free. Not decided here (J.6.3 is open).

### Recommendation for point 4

**4B**, with the control path trap-and-forward: nested translation of data in hardware (STAGES = 1, 2 or 3 in the device entry), the real device table and command ring the host's alone, a virtual unit emulated for the guest by the hypervisor, the guest tag shared with the processor, the cached-translation key above, the two-part reset rule, and the guest reset sequence. The 4A mode (level B only) is the way a guest without its own IOMMU gets a device, and is also the first thing to build.

### Cost

* **Hardware:** the nested walk (each level-A table pointer through level B), a field for the guest tag in the cache, the invalidate-by-tag commands, the blocking guard. The walk is the big item.
* **Walk length (my arithmetic, standard result; unverified as a general claim).** With *a* levels at A and *b* at B, a nested walk that must translate every table pointer and the final address takes (a+1)(b+1)-1 memory reads: 15 for three and three, against 3 for one level. Manual 6.14 says "up to three times" the references of a single-stage miss for the processor's second stage; by my count the factor for 3 and 3 is five. One of us counts a different thing, and it is worth the owner's look at 6.14 (I have not edited it). Large pages at level B (1 GB leaves) shorten the nested walk a great deal, and the permanent mappings of errata 85 (rings) mean that walks are rare once the cache is warm.
* **Kernel / hypervisor:** the virtual unit's emulation (the register block, the command decoder, the ring), the table of what the guest gets after reset (6.14.8), the group rule of section 3.
* **Verification:** two stages double the cases, and the *stale entry* hazard is the most likely bug: that is why the tests of section 8 are written first.

## 6. What stays unsettled by these four proposals

* **J.6.3** interrupt delivery: the unit needs one interrupt of its own (the fault interrupt), and may be the place for the remapping table. Until J.6.3 is answered the model gives the unit a wired line like the timer's (section 8).
* **J.6.2** the wide page-table-entry format: bits 40 to 63 of the device leaf wait for it.
* **J.2.1 and J.2.5** where the configuration space, the windows and the root complex's register block sit.
* **The processor's second-stage format** (B.2.11.3): the unit's level B uses the device-leaf format. A hypervisor may point a device's level B at the *same* table as the processor's second stage only if the two formats agree where the entries are used; the reserved-bit rules above mean that a processor entry with bits the unit forbids faults in the unit. Sharing saves memory and double bookkeeping, and then one change must invalidate both the processor's translation buffer (by guest tag, broadcast) and the unit (by a command). The processor-side invalidate by guest tag is B.2.11.3's, not designed here.
* **ATS and page requests** (a device caching its own translations, and asking the kernel to supply a missing page): **unverified: general knowledge** of the PCI Express features; RISC-V's header has commands for it (**verified: `riscv-iommu-bits.h`**, `RISCV_IOMMU_CMD_ATS_*`). A device that caches a translation holds a copy the unit cannot reach, which breaks the rule of 6.8.5. **Version 1 does not offer it**: the unit answers a translation request with an error. This should be written into the manual as a rule, not left to silence.
* **Quality of the group limit** (section 3): the kernel's way of learning that devices cannot be isolated from each other.

## 7. What the register block would hold

A block of memory-mapped 64-bit registers at 8-byte spacing like the timer and console (**verified: `qemu/README.md`**, registers of 64 bits). Errata 61 gave a device **common first eight registers**: ID, CONTROL, STATUS, RING_BASE, RING_SIZE, DOORBELL, IRQ, DEVICE, "in the same place in every device". Errata 95 later withdrew the eight-register convention for the virtio devices, and `docs/pdp64-q64-bus.md` says so; the unit is not a virtio device but a platform unit, so there is no rule that binds it. **It fits, loosely:** the unit *is* a ring device (the kernel produces commands, the unit consumes them), so the eight map onto its **command ring**, with DEVICE the register that is specific to this unit (the device table). The fault ring, being a ring in the other direction, needs more registers, which go after the eight.

| offset | name | meaning (proposal) |
|---|---|---|
| 0x00 | **ID** | read only: a unit-type code and a version |
| 0x08 | **CONTROL** | bit 0 enable command ring; bit 1 enable fault logging; bit 2 enable the fault interrupt; bit 3 **reset** (write 1: discards every cached entry and translation, clears the device-table mode to "blocked"; fixed point of 6.8.5) |
| 0x10 | **STATUS** | read only except the sticky bits (write one to clear): command busy; command error (a command the unit could not decode); fault ring not empty; fault ring overflow (sticky); table error (sticky); invalidation in progress |
| 0x18 | **RING_BASE** | physical address of the command ring (page aligned) |
| 0x20 | **RING_SIZE** | number of command entries (a power of two) |
| 0x28 | **DOORBELL** | the kernel's write of the command ring's tail index (hardware consumes up to it) |
| 0x30 | **IRQ** | the interrupt of the fault ring: its vector, pending J.6.3 |
| 0x38 | **DEVICE** | the **device-table pointer**: the page number of the directory (or of the one-level table) and a mode field: 0 blocked (reset value), 1 one level, 2 two levels; a write that changes it discards all caches (rule 1 of section 5) |
| 0x40 | **CAPS** | read only: the largest number of levels at A and B, the physical address width, the guest-tag width, and which features exist (nested, level B only) |
| 0x48 | **IRQ_ADDR** | the message address of the fault interrupt (a placeholder: the shape depends on J.6.3) |
| 0x50 | **CMD_HEAD** | read only: how far the unit has consumed |
| 0x58 | **FAULT_BASE** | physical address of the fault ring |
| 0x60 | **FAULT_SIZE** | number of fault records |
| 0x68 | **FAULT_HEAD** | the kernel's write: how far it has read |
| 0x70 | **FAULT_TAIL** | read only: how far the unit has written |
| 0x78 | **FAULT_DROPPED** | read only count of records lost to overflow; reading clears it, or writing one clears it (to settle) |
| 0x80 | **INV0** | the **invalidate register**, first word: one command in the same 16-byte format as a ring entry |
| 0x88 | **INV1** | second word; the write that starts the command; the status bit "invalidation in progress" is set until it finishes |

The **command ring** entry is 16 bytes: word 0 holds the opcode (no-op, invalidate device, domain, guest, page, all, sync), flags, the requester identity, the domain tag and the guest tag; word 1 holds a device address for the page form or the memory address for sync, with the value to write in a word of its own for the sync (the entry may need a third word; to settle). The **invalidate register** is the same command given in two registers: it is for the time before the ring exists (early boot, before memory is mapped) and for the hypervisor in an emergency; both go to the same executor, so there is one behaviour to specify and to test. If the owner prefers one path, the register alone is the simpler: a ring adds state and the QEMU work (section 8) and a machine with a dozen devices issues few commands. Intel has both a register path and a queued path (**verified: `intel_iommu_internal.h`**, `DMAR_IOTLB_REG` and `VTD_CCMD_*` for registers, `VTD_INV_DESC_*` for the queue); RISC-V, ARM and AMD have the ring only (**verified** in the headers named above). I recommend both, since the owner's list names both.

The fault ring's record is the 32 bytes of section 4. The order of writes follows the contract the manual already has for rings (5.10.3): the unit writes the record, then advances FAULT_TAIL, then raises the interrupt, and the interrupt cannot pass the record (2.5.4).

Registers that must work before the unit is told anything: **at reset, DEVICE is "blocked", CONTROL is zero and every cache is empty.** A machine that has not set up the unit refuses every DMA.

## 8. What the QEMU model would need

**Where things are now (verified: `qemu/README.md`, `qemu/hw-pdp64/virt.c`).** The machine `pdp64-virt` has RAM, a timer, a console, one CPU, and a memory map in which device space is `0x8000000000` to `0x800fffffff` (a 256 MiB window; the bit-39 "space bit" of the model is the rule errata 97 has since retired, and the README marks the consistency check as proposed). It has **no PCI Express host, no PCI device and no interrupt controller beyond per-vector lines to the CPU**; I found no mention of PCI in `qemu/hw-pdp64` or `qemu/configs`. So the unit is not the first step. There is a PCI host to add first.

### Steps (in order; each leaves the model working)

1. **A PCI Express host bridge in `pdp64-virt`** (kernel-mode machine only; option to be named by the owner). QEMU has a generic one (`hw/pci-host/gpex.c`, Kconfig `PCI_EXPRESS_GENERIC_BRIDGE`, **verified**), which the RISC-V virt board uses (**verified: `hw/riscv/virt.c`**, `gpex_set_irq_num`). It places a configuration-space window and a memory window in the machine's address map: the model's addresses must lie inside the device window above (a few bus numbers of configuration space, small windows) and are **provisional until J.2.1 is decided**; they must also pass the model's memory-type/space-bit check, which still follows the retired bit. Needs a way to deliver an interrupt (a stand-in: a wired line to the CPU, as the timer's).
2. **A device that does DMA and tells the test the result.** `edu` (**verified: `hw/misc/edu.c`**) has a DMA engine that reads and writes arbitrary addresses through `pci_dma_read` and `pci_dma_write`, but ignores the result, and its Kconfig depends on `MSI_NONBROKEN` (**verified: `hw/misc/Kconfig`**), which the pdp64 machine does not provide. I recommend a **tiny test function of our own** (`hw-pdp64`, PCI with a window of registers: source, destination, length, direction, run, and a *result register holding the status the memory system returned*), so tests can see a refused read. Also later: `virtio-blk-pci` with `iommu_platform=on` (`ACCESS_PLATFORM`, 2.7.3; the property exists, **verified: `hw/virtio/virtio-bus.c`** line 99) for a real driver path.
3. **The unit as a sysbus device `pdp64-iommu`** in `qemu/hw-pdp64/iommu.c`, with the register block of section 7 mapped in device space, state for the device-table pointer, the command executor, the fault-ring writer and one interrupt line to the CPU. The register offsets, bit numbers and the record layouts must come from the grammar's constants (the README's rule: "the grammar stays the only source"; `spec/grammars.d/50-system-v1.hbnf` for the timer, console and map), so **step 3 needs a grammar addition that this document does not make and the owner must approve.**
4. **Per-device address spaces.** QEMU gives an IOMMU a hook on the PCI bus: `pci_setup_iommu(bus, ops, opaque)` with a `get_address_space(bus, opaque, devfn)` callback (**verified: `include/hw/pci/pci.h`**, `PCIIOMMUOps`; used by the Intel, AMD, ARM and RISC-V models, **verified** by `grep pci_setup_iommu`). The callback returns a different address space for each device: a memory region of type IOMMU, whose `translate(addr, is_write)` method returns the physical address and the permissions (**verified: `include/system/memory.h`**, `IOMMUMemoryRegionClass.translate`, `IOMMUTLBEntry`). If the permission returned lacks the access, QEMU treats the address as unassigned and the access fails (**verified: `system/physmem.c`**, around line 446). The bus number is the kernel's to assign later, so the model reads it when the access is made, not when the device is created.
5. **Translation in `translate`**: read the directory and the device entry (checking reserved bits and V), walk level A, walk level B, and for STAGES = 3 send every level-A table pointer through level B; check R and W; return the page (or the 2 MB or 1 GB range); on failure return no permission and write a fault record. The page-table walk is `qemu/target-pdp64/mmu.c` (`pdp64_mmu_translate`) with the page tables in memory of a device instead of the processor's `PTBR`: **the same function, parameterised by the root, the levels and the allowed bits, serves both**; the model's own walker, `ldq_le` reads of the tables from `address_space_memory`, is the pattern.
6. **A model cache** keyed as in section 5 (a hash table, as `smmu_get_iotlb_key` for ARM and `VTD_IOTLB_*` for Intel, **verified** in the headers), filled on translate, drained by the commands and by the register rule. The cache exists in the model *so that a missing invalidate is observable* (the processor model flushes everything at every write, errata 178, which makes a missing flush hard to see). On every drop the model must also call QEMU's notifier for unmapping (**verified: `intel_iommu.c`** uses `IOMMU_NOTIFIER_UNMAP` events) so that a device model's own cached mapping of a ring (virtio caches its ring mappings: `hw/virtio/virtio.c` has `MemoryRegionCache`, **verified**) does not keep a stale translation that the architecture would have discarded. **That second cache is QEMU's, not the architecture's; the tests must not confuse the two.**
7. **The fault ring and the interrupt**, overflow bit and count, mute bit, table-error status.
8. **The invalidate commands and the sync** (`dma_memory_write` of the value), the register path and the ring path sharing one executor, the in-progress guard of section 5.
9. **Reset**: the unit's reset hook empties the cache and sets the mode blocked (6.8.5). The harness has no way to reset the machine (errata 178: `-monitor none`, no reset device), so reset is tested by the register bit, not by a machine reset; this is stated plainly there and again here.
10. **The tests** (`tests/qemu/*.S`, run by `tools/check-qemu.sh` on the kernel-mode machine; extra QEMU arguments for the device go in `NAME.qargs`, **verified: `tools/check-qemu.sh`**).

### What the tests would check

* **A DMA from a device without a mapping is refused.** (a) The device has no entry (V = 0): a DMA write leaves memory unchanged; the fault ring gets one record with the right cause, identity, address and kind; the interrupt comes; the test function's result register shows the error; a DMA read leaves the device's buffer unchanged. (b) The device has an entry but the page is not mapped: same, with the "no mapping" cause. (c) Read-only mapping: a write is refused ("no write permission"), a read goes through. (d) A device address aimed at another device's window, not mapped: refused (manual 2.3.5). (e) The unit is blocked at reset: before any set-up, every DMA is refused. (f) A malformed entry (a reserved bit): every access refused, and the cause says so. (g) Overflow: more faults than the ring holds, the sticky bit and count, no hang.
* **A stale device translation after a domain change is discarded.** The device does a DMA through a mapping to page P1 (so the cache holds it). The kernel changes the mapping to P2 (and, in a second run, moves the device to another entry with another root). **Without an invalidate the test asserts nothing about which page is used** (staleness is allowed, errata 178), then after *invalidate device* (and again with *invalidate domain*, *invalidate all*, and the register path) plus *sync* the DMA must land in P2 and *never* in P1. Then the register rule: change the device-table pointer; the next DMA uses the new table with no command. **Non-vacuity**, as errata 178 did: with a scratch edit of the model (outside the repository, reverted by `qemu/install.sh`) that removes the cache discard of each command in turn, the test must fail at the matching check; without it the test could pass on a model with no cache at all. Include the guest case: two guest tags with the same device addresses reaching different pages must not hit each other's cache entries, and after *invalidate guest* and sync no entry of that tag is used.
* **The guest-visible second level.** (a) Level B only (STAGES = 2): a device address taken as guest-physical lands on the host page the hypervisor's table gives. (b) Nested (STAGES = 3): level A maps a device address to a guest-physical address, level B maps that to a host page; the DMA lands there. (c) **The level-A tables themselves** sit at guest-physical addresses whose host mapping is *not* the identity: the walk succeeds only if the unit sent the table pointers through level B (otherwise it would read the wrong page). (d) A level-A hole reports stage A and the device address; a level-B hole reports stage B and the guest-physical address. (e) Two guests, same level-A tables, different level B: different pages. (f) The guest reset sequence of section 5: after the entry is rewritten with level A off and *invalidate guest* plus sync, nothing cached from the nested state is used (the CVE-2026-99312 shape, errata 178). (g) The guard: while an *invalidate guest* is in progress, the device's accesses are refused.

  **Limit of this test, stated:** the model's CPU has no hypervisor mode (it is not built; `kernel-mode` is the only mode switch); the test plays both roles, writing the hypervisor's tables and the guest's tables from one kernel-mode program. That tests the *unit's* nesting, not the entry and exit of a guest, nor the virtual unit's trapping, nor the guest-forwarded fault ring.
* **Not testable in QEMU:** what a real PCI Express endpoint does on an error completion, completion time-outs, the dropping of posted writes at the link, switch-level peer-to-peer routing and access control, the drain of in-flight requests (QEMU's DMA is synchronous in the device model), real timing, hot removal during a DMA. No test here should claim them.

### Order and size

Steps 1 and 2 (the host bridge and the test function) are a precondition for anything; steps 3 to 5 give the refused-DMA tests; 6 to 8 give the stale-translation tests; level B and nesting (5, 6) are the last because they are the part that the first tests do not need. I have no time estimate worth giving; the amount of code is that of the processor's `mmu.c` several times over, by my judgement (an estimate), most of it the nested walk and the cache.

## 9. The decisions the owner must make

Each with my recommendation, in the order that the later ones depend on the earlier ones.

1. **What does "a second level that the guest can see" mean (6.14.6, errata 181)?** My reading: the unit translates in two levels, the host's (level B, guest-physical to physical) and, before it, one the **guest** writes (level A); the real device table stays the host's and the guest sees a virtual unit with the same registers. *Recommend: confirm this reading.* The alternative (the guest sees the hypervisor's level) would not give a guest an IOMMU of its own; I do not think it is meant.
2. **Device table shape.** *Recommend:* 16-bit identity, one unit identity space (no segment), directory of 512 entries x 8 bytes and leaf page of 128 entries x 32 bytes (a 9 and 7 bit split), a mode field with blocked, one level and two levels, blocked at reset.
3. **Device entry.** *Recommend:* 32 bytes as the table of section 2: V, MUTE, STAGES (A, B, A then B), levels per stage, domain and guest tags, two root words, a reserved word kept for the interrupt table; reserved bits must be zero or the device is refused; **no bypass mode**.
4. **Leaf use.** *Recommend:* V, R, W and the page number; W needs R; X, U, G, MT must be zero; A and D ignored; large pages allowed; 3, 4 or 5 levels per device; **bits 40 to 63 left unallocated** (they continue the page number if J.6.2 widens it).
5. **Where the unit sits.** *Recommend:* one unit at the root complex, registers in the root complex's block (J.2.5), not a PCI Express function; our bridges force traffic upstream; devices that a third-party switch lets talk directly form a **group** assigned together, which is the one exception to "each device its own domain".
6. **Refusal reporting.** *Recommend:* read answered with an error completion; posted write dropped and counted; every refusal logged in a ring in memory with an interrupt on empty to non-empty, a sticky overflow bit and count, a per-device mute bit, fail closed on a bad table; never all ones, never a machine check; for guests the hypervisor forwards level-A faults to the guest's virtual log.
7. **Cached translations and invalidation.** *Recommend:* the key (requester identity, guest tag, domain tag, page, level); commands invalidate device, domain, guest, all, (page optional) and sync; **hardware discards everything on a change of the device-table pointer, on the reset bit and on reset**; invalidate device does not complete until in-flight requests are finished or refused; an implementation may discard more; and the guard that blocks a device whose guest is being invalidated.
8. **Guest tag.** *Recommend:* the same number space and width as the processor's guest tag (the width is still to be set in 6.14.4); 0 is the host; the **guest reset sequence** of section 5 is written into the manual as the hypervisor's duty.
9. **Guest control path in version 1.** *Recommend:* the guest's unit is virtual and trapped, the hypervisor forwards commands and faults; no guest-visible hardware ring.
10. **ATS and page requests.** *Recommend:* not offered in version 1; the unit answers a translation request with an error; written into the manual.
11. **Register block.** *Recommend:* 64-bit registers at 8-byte spacing; the first eight as the command ring (ID, CONTROL, STATUS, RING_BASE, RING_SIZE, DOORBELL, IRQ, DEVICE = the device-table pointer), then CAPS, the fault ring registers and the invalidate register; **both** a command ring and an invalidate register on one executor. The fallback if the owner wants less: the register alone, no command ring.
12. **The unit's own interrupt.** *Recommend:* a wired line to the CPU like the timer's in the model, to be replaced when J.6.3 is decided; word 3 of the device entry reserved for an interrupt-remapping pointer.
13. **The model.** *Recommend:* add a PCI Express host bridge and our own DMA test function to `pdp64-virt` first (addresses provisional until J.2.1); constants for the unit added to the grammar (the owner's approval needed; not done here); a model cache so that a missing invalidate is observable; the tests of section 8 including the scratch-edit non-vacuity check; and the statement that the hypervisor mode is not in the model so that the nested test plays both roles.
14. **Not for this round, to be asked later:** the walk-count discrepancy with 6.14 (section 5: 15 reads against 3 by my count, where 6.14 says up to three times); whether the processor's second stage and the unit's level B share a table.

## 10. What was checked, and what was not

**Verified** (read in a file on this machine): the QEMU v11.1.2 sources named in the text (Intel `intel_iommu.c` and `intel_iommu_internal.h`, AMD `amd_iommu.c` and `amd_iommu.h`, ARM `smmuv3.c`, `smmuv3-internal.h`, `smmu-common.h`, RISC-V `riscv-iommu.c`, `riscv-iommu-bits.h` and the file list, `hw/misc/edu.c`, `hw/misc/Kconfig`, `hw/pci-host/Kconfig`, `include/hw/pci/pci.h`, `include/system/memory.h`, `system/physmem.c`, `system/memory.c`, `hw/virtio/virtio.c`), the Linux headers `linux/iommufd.h` and `linux/pci_regs.h`, and the repository's manual, errata and QEMU model. I did not run QEMU or the tests, and I did not read any of the four IOMMU models end to end: I read their headers, command and fault lists, the table walks named and the functions cited.

**Not verified** (from memory, marked at each place): PCI Express packet details (the requester identity being unchanged through switches, the error completion statuses, posted writes having no answer, completion time-outs, the access-control and ATS features, bridges to old PCI changing the identity); the real hardware of Intel, AMD and ARM IOMMUs as distinct from their QEMU models; how a real device reacts to an error completion; how often real switches lack isolation; that the AMD model lacks nested translation (I did not read enough to say); the walk-count formula for nested translation (a standard result, and the figure in 6.14 differs from it); the VAX Unibus map registers beyond what the manual's 2.11 says of them (I did not re-read `ubareg.h` here).

**Not claimed:** any size, area or time for the hardware; the model's effort; that the proposed field layouts are the best possible, which no one has measured.
