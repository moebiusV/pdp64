# Q64: the pdp64 system bus and its devices

[← pdp64 index](../README.md)

This document gathers what the other documents say about the bus, in one place, and lists what is still open. Each statement carries a label:

* Established: written in the ISA, the implementation plan or the LB64 document, with the section named.
* Decided: a project decision, recorded in [`errata.md`](errata.md).
* Open: not yet decided or not yet written.

The processor side (privilege, exceptions, interrupts, memory management, boot) is in [`pdp64-system-architecture.md`](pdp64-system-architecture.md).

## 1. Why the bus is part of the architecture

The architecture is the processor, the bus and the devices together. The instruction set is its stable core: it is the part that should not change when a
device does. ISA §16 says the devices "none of them touches the ISA", and that is a statement about dependency, so that the device side can churn without
respecifying the processor. It is not a statement that the bus is unimportant. A great deal of what makes the machine pleasant and cheap to program is on the bus
side: how a driver is written, who moves the data, what the processor is promised about ordering, what happens when an access fails. Those are specified here.

## 2. What Q64 is

*Established* (ISA §18, glossary): `Q64` is the system bus, the PDP-11 Q-bus lineage widened to 64-bit data and a physical address of 24 to 64 bits (errata 102). It keeps the Unibus and
Q-bus programming model, including the locked read-modify-write transaction pair `DATIP` (data in, pause) and `DATO` (data out). *(Superseded for atomics: errata 45 makes them monitor-based, and `DATIP`/`DATO` are no longer architectural.)* Lineage: Unibus, Q-bus, Q64.

*Open*: the transaction definitions (widths, bursts, arbitration, timing) are not written anywhere in this repository.

## 3. Addressing

* *Established* (ISA §6.1, §8): the physical address is 24 to 64 bits (errata 102: 40 in the present implementation); the virtual address is 39 bits (9 + 9 + 9 + 12), "one bit of headroom, no translation needed for
  the physical window".
* *Established* (ISA §8.3): two direct mapping windows, `DMW0` and `DMW1`, translate `PA = VA - VirtualBase + PhysicalBase` with no page-table reference. Physical memory,
  and so a device's registers and a DMA descriptor, are reachable without mapping them first. This is what a driver, a debugger and the bootstrap need.
* *Established* (ISA §16): devices are in the ordinary address space (memory-mapped). The processor has no separate I/O instructions.

## 4. Who can start a transaction

*Established*: the processor is an initiator. A device is a target (its registers) and, if it moves data itself, also an initiator (DMA). The LB64 accelerator
is the worked example: "a Q64 initiator, not merely a target" (LB64 §7). Several initiators already exist, and a DMA master and a second CPU "are different
problems with different answers, and conflating them is the usual way this goes wrong" (ISA §17).

## 5. What the processor owes the bus

*Established* (ISA §16): exactly three things, and nothing else.

1. A memory type per page, the `MT` field of the page-table entry (ISA §8.2):

   | `MT` | meaning |
   |---|---|
   | `00` | normal, cached, write-back |
   | `01` | normal, uncached |
   | `10` | device, strongly ordered |
   | `11` | device, weakly ordered |

   Per page, not per access, so the code doing the writing does not need to know.
2. An ordering instruction, `FENCE` (ISA §4.11), with a defined meaning against Q64: a driver can be sure a descriptor is visible before the doorbell write.
3. Atomics that reach device memory (ISA §4.11), for queues shared between the processor and a device.

## 6. Coherence and the hand-off

*Established* (ISA §17.3): between CPUs, coherence is transparent to software (snooping MSI at two to four cores). Between the processor and a DMA device it is the
opposite: the buffers are mapped uncached (`MT = 01`) and the hand-off is explicit, because snooping the DMA path is expensive and the access pattern is large,
infrequent and has an explicit hand-off. Two mechanisms, each where it is cheap.

*Established* (LB64 §7, ISA §16): the hand-off every device follows, with no coherence protocol:

1. The processor builds the descriptors and data in memory mapped `MT = 01`.
2. `FENCE`.
3. The processor writes the device's doorbell register.
4. The device walks the descriptors, moves the data by DMA, writes the result and a status word, and raises an interrupt.
5. The processor reads the result.

## 7. When an access fails

*Established* (ISA §7.1):

* A read that times out (load or instruction fetch of nonexistent memory) is reported as an abort with `ECAUSE = BUSFAULT`, precisely, at the faulting
  instruction. This is a deliberate improvement on the PDP-11, where a read timeout was an unrestartable bus error and fatal to the process.
* A posted write that times out, uncorrectable ECC and parity errors are machine checks, imprecise and not restartable, the descendants of the PDP-11's
  vector 004. A `FENCE` before a probe makes even a posted write precise at a known point.
* `PROBER` and `PROBEW` (ISA §4.11) cover the address-validation case that the PDP-11's `nofault` idiom served.
* `RESET` is not an instruction: "resetting the bus is a device operation and belongs in a Q64 bus-controller register" (ISA §4.11.1).

*Open*: the error-reporting registers of the root complex, and which of these a device can raise itself.

## 8. Atomics: the blocking open item

*Established, and open* (ISA open item 4, §17.6; FPGA plan §11, risk 3; LB64 §7): the Unibus-derived `DATIP`/`DATO` locked read-modify-write is a lock. AXI exclusive
access, which the FPGA build's memory system uses, is a monitor. They are not the same primitive and the mapping between them is not clean. With one initiator
this could wait; with a second core, or with LB64 contending for a descriptor's status word, it is blocking. `LL`/`SC` needs a reservation that another initiator's write
invalidates. The `_DB` (barrier) variants of the atomics assert an ordering guarantee that has to mean something on the real interconnect. To be settled before any second
initiator and before the memory system is built.

## 9. The device convention

*Decided* (errata 75, 79, 95): every standard device is a virtio device or a USB (xHCI) controller (errata 101: the disk is virtio-blk, not NVMe); any other PCI Express device, an NVMe controller for example, may be attached with its own driver; the disk, network, graphics and audio devices are virtio-blk, virtio-net, virtio-gpu (2D) and virtio-snd over the virtio PCI Express transport. The device moves its own data by DMA, so the processor only sets up a transfer and carries no multitasking burden for it. A driver finds the virtio structures through the capabilities in the function's configuration space, negotiates features, sets up its queues (a table of 16-byte descriptors, an available ring the driver writes and a used ring the device writes) and notifies the device by a write to the queue's notification address; chapter 5 of the manual gives the layout. It costs the ISA nothing: it is bus and device design, and uses only what section 5 lists.

*Open*:

* the feature subset of each virtio device, and the platform-ordering feature that the pdp64 must declare;
* the form of the console, the timer and the entropy source under this interface;
* the interrupt convention beyond message-signalled interrupts (decision R1).

## 10. Interrupts and the other cores

*Established* (ISA §17.4): an inter-processor interrupt path "a memory-mapped per-core register is sufficient and needs no APIC-like complexity", a boot protocol for
releasing secondary cores from reset, and a shared L2 or at least a coherent interconnect are device side and still to be built. A device raises an interrupt when its
transfer is done (section 6, step 4). *Open*: the interrupt controller, the vectors, the per-core registers.

## 11. What it costs

*Established* (FPGA plan §2): the Q64-to-AXI bridge for the FPGA build is about 600 LUTs; this is an estimate, not a measurement.

## 12. The list of open items

1. The Q64 transaction definitions (widths, bursts, arbitration, timing).
2. Locked read-modify-write against exclusive access (section 8): blocking for SMP and for LB64.
3. The feature subset of each virtio device; the form of the console, the timer and the entropy source (section 9).
4. Decided (errata 102): the physical address is 24 to 64 bits, and windows can be mapped anywhere except the first few pages, where the boot code and boot data are loaded. Open: how many pages those are, where the configuration space sits, how software discovers the implemented width, and the page-table entry format for a wide address.
5. The root complex's error registers (section 7).
6. The interrupt controller, the inter-processor interrupt registers and the boot protocol for secondary cores (section 10).
7. The details of enumeration and hot-plug: where the windows sit, the hot-plug alert and the handling of accesses to a departed device (section 13).


## 13. Enumeration, mapping and hot-plug

*Decided* (errata 49, 80, 95): the bus enumerates the devices, maps them and alerts the processor when one enters or leaves; the enumeration is that of PCI Express (configuration space and base-address registers, errata 80), so an ordinary PCI Express device works unchanged. The processor reads the configuration space of each function through the root complex, sizes its base-address registers and assigns its windows; a function that is a bridge presents the functions behind it, and the kernel's enumeration is one recursive walk. A virtio function is recognised by its virtio identifiers and capabilities.

*Proposed*: an arrival or departure raises an interrupt and the kernel rescans the bus, which is also what it does at boot; a bus reset produces no removal events. When a device leaves, an access to its windows is at once a precise bus fault (section 7, `BUSFAULT`), not a read of all ones, a posted write is dropped and counted, and the device's in-flight bus transactions are aborted. *Open*: where the configuration space and the windows sit in the physical address space (no address bit selects device space, errata 97), and how a hot-plug event behind a bridge is reported. Facts about other systems are marked *(not confirmed in the sources read)* unless the text says they were read in the source trees on this machine.

What other systems do. The VAX scanned its interconnects *(read in source, 4.3BSD)*: `probenexi()` in `vax/autoconf.c` walks the nexus slots and reads each slot's status register, whose type field says what is plugged in; the Unibus had no enumeration at all, with devices at switch-set addresses and `badaddr()` probes. PCI sizes each device's windows by writing all ones to its base registers *(not confirmed in the sources read)*; Amiga AutoConfig lets each board appear at a fixed configuration address and be told where to live *(not confirmed)*; NuBus gave each slot a fixed share of the address space *(not confirmed)*.

### Work in flight when a device leaves

Part of the proposal, not yet settled: when a device leaves, the queued work is left in memory so that it can be read, saved and resent. This fits the design because the queues are already in host memory (section 6: descriptors and buffers in memory the processor owns; the device holds only a pointer). The proposal makes it a rule with four parts:

1. The host owns the queue. The descriptor ring and its buffers live in host memory; a departing device cannot take them with it. The root complex does not discard the departed device's descriptors; it only stops its bus accesses.
2. Progress is written to memory, not kept in the device. The device writes an entry in the used ring after the data it moved (the head of the chain and the number of bytes written). A device must complete its data writes before the used index advances (the ordering rule the bus already gives with `FENCE`, section 5). If progress lived only in a device register, it would leave with the device.
3. The root complex aborts the device's in-flight bus transactions when it marks the device absent, so that no half-finished transaction hangs the bus. The data in a buffer beyond what the used ring covers is undefined, and the driver knows which descriptors those are.
4. Recovery is one generic step: scan the available ring for chains that are not in the used ring and then choose. The driver can read them (for diagnosis), save them (copy the ring and buffers aside), resend them to a replacement device of the same type (program the queue's addresses into the new device and resubmit the chains that are not in the used ring, so the new device adopts the work), or fail them back to the callers. For devices whose operations are repeatable (disk reads and writes, network sends, most transfers) resending the unfinished chains is safe; an operation that must not run twice is tracked by its class driver, because the used ring cannot tell "never started" from "started, outcome unknown".

What it costs. One used-ring write per chain (devices already write a completion) and the ordering rule between data and the used index. What it saves (principle 2). The driver has *one* recovery routine for any device that disappears or is reset, and the same routine serves a device that fails and is reset in place, a replacement of one device by another, and (with the saved ring) a hand-over of work between cores or machines. It is the same argument as for the restartable instructions of decision P12: make the operation repeatable from the start and the recovery code does not have to be specific to the failure.

What other systems do *(not confirmed in the sources read unless marked)*: NVMe and virtio keep their submission and completion queues in host memory, and the Linux drivers re-queue outstanding requests after a controller reset; a surprise-removed PCI device's requests are usually failed back with an error (and its reads return all ones) rather than resent, except where multipath or redundancy provides a second device; USB cancels the outstanding requests and returns each with a "device gone" status; hardware RAID controllers keep their write-back cache in battery-backed memory so that unwritten data survives and can be replayed. What the PDP-11 and VAX did *(read in source, 4.3BSD)*: `ubareset()` in `vaxuba/uba.c` resets the Unibus adapter and then calls every device driver's reset routine (`(*cdp->d_reset)(uban)` for each character device, plus `ifubareset()` for the network interfaces), so that each driver re-issues what was pending: resending as a design, driver by driver. *Comparison:* the proposal makes that the architecture's rule instead of every driver's own code.

### Effects on the other documents

* Boot (`boot.md`, B3): the hand-off can shrink to memory ranges, core count, the address of the root complex and the identity of the boot device and console; the kernel enumerates the rest.
* Interrupts (decision R1): a device interrupts by a message-signalled write; routing to cores is still R1.
* Device layout: the virtio specification's (section 9).

## Sources

The ISA ([`pdp64-isa.md`](pdp64-isa.md)): §6.1.1, §7.1, §8.2, §8.3, §16, §17.3, §17.4, §17.6, §18 and open item 4. The implementation plan
([`pdp64-fpga-plan.md`](pdp64-fpga-plan.md)): §2, §11 (risk 3) and §12. The accelerator ([`pdp64-lb64-accelerator.md`](pdp64-lb64-accelerator.md)): §5 and §7.
