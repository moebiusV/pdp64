Status: internal design document, current as of 2026-11-10. The file name keeps the working name Q64 for the pdp64's bus *with its additions to PCI Express*. **The manual does not use the name Q64**: the author decided (errata 120) that it is held until the additions to PCI Express are decided ("if we DO add things to pcie, then that is q64 bus"), and until then the bus of the manual is simply PCI Express (chapter 2, section 2.3). This document is where the additions are collected, so that when the author decides them the name and the material are ready. It follows chapter 2 of the manual and the ledger; where it disagrees, they win. Section 13 lists which of its items are decided, which are proposals and which are open.

# The pdp64 system bus: PCI Express and the additions (Q64)

[← pdp64 index](../README.md)

This document gathers what the manual and the other documents say about the bus, in one place, and lists what is still open. Labels:

* Decided: a decision of the author, recorded in [`errata.md`](errata.md) or the [ledger](decisions-and-status.md), and placed in the manual (tag *(D)*); "details pending" means the decision stands and the details are open.
* Proposed: an idea nobody has decided (manual appendix H).
* Open: a question the architecture must answer and has not (manual appendix J, items J.2.x and others).

The processor side (privilege, exceptions, interrupts, memory management, boot) is in the manual's chapter 6 and, as a record of System v1, [`pdp64-system-architecture.md`](pdp64-system-architecture.md).

## 1. Why the bus is part of the architecture

The architecture is the processor, the bus and the devices together. The instruction set is its stable core: it is the part that should not change when a device does. The instruction-set text says that devices touch the ISA in no way ([`pdp64-isa.md`](pdp64-isa.md), the section on what the architecture owes devices), and that is a statement about dependency, so that the device side can churn without respecifying the processor. It is not a statement that the bus is unimportant. A great deal of what makes the machine pleasant and cheap to program is on the bus side: how a driver is written, who moves the data, what the processor is promised about ordering, what happens when an access fails.

## 2. What the bus is

*Decided* (manual 2.3.1, 2.3.4): the system bus is **PCI Express**, so that an ordinary PCI Express device works on it unchanged, with the programming model of the PDP-11 Q-bus (devices as memory locations in the one address space) widened to 64-bit data and a physical address that is not limited to 40 bits, and with convenience and security circuitry added. The transactions on the bus are those of PCI Express. The additions are for convenience (overlays, helper registers) and security (the IOMMU, error and reset rules) and are measured against the list of pain points in [`kernel-pain-points.md`](kernel-pain-points.md). An extension is announced to a card, through a PCI Express extended capability, only if the card must take part in it; a mitigation that lives on the processor side is invisible to cards.

Lineage: Unibus, Q-bus, PCI Express with additions. **The name Q64 is for the last step and is held** (errata 120). The Unibus `DATIP`/`DATO` locked pair is not an architectural primitive (errata 45; section 8).

*Open* (J.2.5): the detail of the additions to PCI Express, and the root complex's own registers. Earlier text that said the transaction definitions (widths, bursts, arbitration, timing) were "not written anywhere" is superseded: the transactions are PCI Express's own.

## 3. Addressing

* *Decided* (manual 2.3.5; errata 97, 102): the physical address is **40 to 64 bits**, an implementation choosing its width in that range. **No bit of the physical address selects device space**: a device window is an ordinary range of physical addresses, found by enumeration. A window can be mapped anywhere except the first few pages, where the boot code and boot data are loaded. *Open*: how many pages those are, where the configuration space sits, how software discovers the implemented width (J.2.1, J.4.1, J.6.1), and the page-table entry for a wide address (J.6.2).
* *Decided* (manual 2.3.6; details to be determined): the windows of a device start on 4 KB page boundaries and are a whole number of pages, so that one device can be mapped to one protection domain.
* *Decided* (manual 2.3.2): devices live in the ordinary address space; the processor has no input or output instructions.
* The virtual address is 39, 48 or 57 bits (manual 6.6); the direct-mapping windows have no defined format yet (manual 6.9.2).

## 4. Who can start a transaction

The processor is an initiator. A device is a target (its registers) and, if it moves data itself, also an initiator (DMA). A DMA master and a second CPU are different problems with different answers, and conflating them is the usual way this goes wrong (manual chapter 7). The accelerator design (LB64, [`pdp64-lb64-accelerator.md`](pdp64-lb64-accelerator.md)) is a *proposal* and a worked example of a bus initiator; it is not decided.

## 5. What the processor owes the bus

*Decided* (manual 2.8.1): exactly three things, and nothing else.

1. A memory type per page: normal cached, normal uncached, device strongly ordered, device weakly ordered (manual 2.3.3 and 6.7). Per page, not per access, so the code doing the writing does not need to know.
2. An ordering instruction, `FENCE`, with a defined meaning against PCI Express: a driver can be sure a descriptor is visible before it writes the queue's notification address (the doorbell).
3. Atomics that can reach device memory (what an atomic does on uncached and device memory is open: J.7.4).

## 6. Coherence and the hand-off

*Decided* (manual 2.5): between CPUs, coherence is transparent to software (snooping with three states, for two to four cores). Between the processor and a DMA device it is the opposite: buffers are mapped uncached and the hand-off is explicit, because snooping the DMA path is expensive and the access pattern is large, infrequent and has an explicit hand-off. The hand-off has five steps (manual 2.5.3): the processor builds the descriptors and data in uncached memory, executes `FENCE`, writes the device's notification address; the device walks the descriptors, moves the data by DMA, writes the result and its used-ring entry, and raises an interrupt; the processor reads the result. The write that raises an interrupt cannot overtake the data writes that precede it on the same path (manual 2.5.4 and 2.6.2).

## 7. When an access fails

*Decided* (manual 2.9):

* A read or instruction fetch of non-existent memory is a precise abort with cause `BUSFAULT`, at the faulting instruction. This is a deliberate improvement on the PDP-11, where a read timeout was an unrestartable bus error and fatal to the process.
* A posted write that times out, and an uncorrectable memory error, are machine checks, imprecise and not restartable (the descendants of the PDP-11's vector 004). A `FENCE` before a probe makes even a posted write precise at a known point.
* `PROBER` and `PROBEW` cover the address-validation case that the PDP-11's `nofault` idiom served.
* Resetting the bus is a write to a register of the root complex, not an instruction (manual 2.9.4).
* A read of a configuration position that never held a function returns all ones, not a bus fault, and the root complex records the miss in a sticky status bit (manual 2.4.7, 2.4.8).

*Open* (J.2.5): the error-reporting registers of the root complex, and which of these a device can raise itself.

## 8. Atomics: settled

The Unibus `DATIP`/`DATO` locked read-modify-write is a lock; the exclusive access of the FPGA memory fabric is a monitor. The question of which the architecture uses was settled: the atomics are defined on a **monitor** (a reservation that a write by any initiator clears), and the locked pair is not architectural (errata 45; manual 2.10 and 7.4). A device that writes memory shared with a core takes part by clearing reservations. What remains is the behaviour on uncached and device memory (J.7.4).

## 9. The device convention

*Decided* (errata 75, 79, 95, 101; manual 2.7 and chapter 5): every standard device is a virtio device or a USB controller; the disk is virtio-blk (an NVMe disk may be attached as any PCI Express device may), and the network, graphics and audio devices are virtio-net, virtio-gpu and virtio-snd, over the virtio PCI Express transport. The device moves its own data by DMA, so the processor only sets up a transfer. A driver finds the virtio structures through the capabilities in the function's configuration space, negotiates features, sets up its queues (a table of descriptors, an available ring the driver writes and a used ring the device writes) and notifies the device by a write to the queue's notification address. The earlier convention of eight memory-mapped registers per device was withdrawn. The pdp64 supports in silicon the virtio devices that it makes sense to support, and it standardises on the latest USB, NVMe and PCI Express (decision register R359; details pending, J.5.6).

*Open*: the feature subset of each virtio device (J.2.4, J.5.2); the form of the console, the timer and the entropy source under this interface (J.5.1); USB's controller interface (J.5.7).

## 10. Interrupts and the other cores

*Decided* (manual 2.6): a device interrupts by a message-signalled write (MSI-X); the details (delivery to a core, vector count and numbering, moving an interrupt between cores) are pending (J.6.3). An inter-processor interrupt exists as a need (manual 7.10.4). *Open*: how a device interrupt and an inter-processor interrupt reach a core, the per-core registers and the boot protocol for secondary cores (J.6.3, J.4.6).

## 11. What it costs

The cost of the bridge from the bus to the FPGA's memory fabric is an estimate in the implementation plan ([`pdp64-fpga-plan.md`](pdp64-fpga-plan.md)); it is not a measurement and was made for the earlier bus description (unverified for the present one).

## 12. Enumeration, mapping and hot-plug

*Decided* (manual 2.4; errata 49, 80, 95): the bus enumerates the devices, maps them and alerts the processor when one enters or leaves; the enumeration is that of PCI Express (configuration space and base-address registers), so an ordinary PCI Express device works unchanged. The processor reads the configuration space of each function through the root complex, sizes its base-address registers and assigns its windows; a function that is a bridge presents the functions behind it (so USB, itself a PCI Express function, is enumerated to any depth); a virtio function is recognised by its virtio identifiers and capabilities. The bus alerts the processor by an interrupt when a device enters or leaves, and the kernel rescans (2.4.4); a bus reset produces no removal events (2.4.6). The queued work of a departed device stays in memory untouched, so the driver can read, save, resend or fail it (2.4.5, details to be determined). When a device leaves, an access to its windows is at once a precise bus fault, a posted write is dropped and counted, and the device's in-flight transactions are aborted (2.4.9, details to be determined). The author's wording (2026-10-22): "your bus design looks excellent, let's wait for pain points to land before settling it, but it looks good."

### Work in flight when a device leaves

The proposal behind 2.4.5 and 2.4.9 (the details are still to be determined): the queued work is left in memory so that it can be read, saved and resent. This fits the design because the queues are already in host memory. The rule has four parts:

1. The host owns the queue. The descriptor ring and its buffers live in host memory; a departing device cannot take them with it. The root complex does not discard the departed device's descriptors; it only stops its bus accesses.
2. Progress is written to memory, not kept in the device. The device writes an entry in the used ring after the data it moved. A device must complete its data writes before the used index advances. If progress lived only in a device register, it would leave with the device.
3. The root complex aborts the device's in-flight bus transactions when it marks the device absent, so that no half-finished transaction hangs the bus. The data in a buffer beyond what the used ring covers is undefined, and the driver knows which descriptors those are.
4. Recovery is one generic step: scan the available ring for chains that are not in the used ring and then choose: read them, save them, resend them to a replacement device of the same type, or fail them back to the callers. Resending is safe for repeatable operations (disk reads and writes, network sends); an operation that must not run twice is tracked by its class driver, because the used ring cannot tell "never started" from "started, outcome unknown".

What it costs: one used-ring write per chain (devices already write a completion) and the ordering rule between data and the used index. What it saves: the driver has one recovery routine for any device that disappears or is reset. Compare the VAX, where `ubareset()` reset the adapter and then called every driver's reset routine so that each re-issued what was pending (read in the 4.3BSD source): resending as a design, driver by driver. The proposal makes it the architecture's rule. Facts about other systems' hot-plug (NVMe, USB, RAID cache) in the older text were *not confirmed in the sources read* and are omitted here.

## 13. Which items are decided

| Item | State |
|---|---|
| The bus is PCI Express, with convenience and security additions | decided (2.3.1, 2.3.4) |
| The additions themselves (root complex registers, overlays, helper registers) | open (J.2.5); the name Q64 returns with them |
| Physical address 40 to 64 bits; no selecting bit; windows anywhere but the first pages | decided (errata 97, 102); details open (J.2.1, J.4.1, J.6.1, J.6.2) |
| Windows start on page boundaries | decided, details to be determined (2.3.6) |
| Memory type per page; `FENCE`; atomics reach devices | decided (2.8.1); atomics on device memory open (J.7.4) |
| Atomics are monitor-based, not `DATIP`/`DATO` | decided (errata 45; 2.10) |
| Coherence: snooping between CPUs, uncached and explicit with DMA | decided (2.5) |
| `BUSFAULT` on a read of nothing; machine check on a lost posted write | decided (2.9) |
| Enumeration by PCI Express; hot-plug alert and rescan | decided (2.4) |
| Departed device: windows fault, work stays in memory | decided, details to be determined (2.4.5, 2.4.9) |
| MSI-X | decided, details pending (2.6; J.6.3) |
| virtio devices, USB, disk virtio-blk, no eight-register devices | decided (errata 95, 101; register R359) |
| IOMMU | part of the design; format, place and faults open (J.2.3) |
| Which virtio features; console, timer, entropy | open (J.2.4, J.5.1, J.5.2) |
| The bus controller of errata 49 | open (J.2.2) |
| The root complex error registers | open (J.2.5) |
| Interrupt controller, inter-processor interrupt, boot of secondary cores | open (J.6.3, J.4.6) |

## Sources

Manual chapters 2, 5 and 6 and appendix J; [`errata.md`](errata.md) entries 45, 49, 75, 79, 80, 95, 97, 101, 102, 118, 120, 121; [`pdp64-isa.md`](pdp64-isa.md); [`pdp64-fpga-plan.md`](pdp64-fpga-plan.md); [`pdp64-lb64-accelerator.md`](pdp64-lb64-accelerator.md) (proposed).
