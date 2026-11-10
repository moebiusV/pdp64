# 2. The bus

[← manual index](00-index.md)

**The processor reaches the world through one bus, Q64, which is PCI Express with convenience and security circuitry added; every standard device is a virtio device (the disk is virtio-blk) or a USB controller, and any other PCI Express device may be attached, all found by PCI Express enumeration; every transfer of data is a descriptor in a queue in memory that the device carries out and marks done.** The chapter states what the processor owes the bus and how the bus enumerates devices and tells the processor when one comes or goes. How a driver talks to a device, the virtio transport and the default devices are in chapter 5. Decided statements are tagged *(D)*; proposed ones *(P)*; unspecified ones *(S)*. Interrupts and modes are chapter 6, and the other cores are chapter 7. The full discussion is in [`../pdp64-q64-bus.md`](../../pdp64-q64-bus.md); the options still open are in [`../decisions-pending.md`](../../decisions-pending.md).

## 2.1 Q64 and the address space

**2.1.1** Q64 is the system bus: PCI Express, so that an ordinary PCI Express device works on it unchanged, with the programming model of the PDP-11 Q-bus (devices as memory locations in the one address space) widened to 64-bit data and a physical address that is not limited to 40 bits (the simulator and the emulator implement 40), and with convenience and security circuitry added. *(D)*

**2.1.2** Devices live in the ordinary address space; the processor has no input or output instructions. *(D)*

**2.1.3** The windows of a device (the regions its base-address registers describe) start on 4 KB page boundaries and are a whole number of pages, so that one device can be mapped to one protection domain. *(P)*

**2.1.4** Every page has a memory type: normal cached, normal uncached, device strongly ordered, or device weakly ordered. *(D)*

**2.1.5** The transactions of Q64 are those of PCI Express; the circuitry the pdp64 adds is for convenience (overlays, helper registers) and security (the IOMMU, error and reset rules), and is measured against the list of pain points of `kernel-pain-points.md`. An extension is announced to a card, through a PCI Express extended capability, only if the card must take part in it; a mitigation that lives on the processor side is invisible to cards. *(D)* The detail of the extensions is not specified. *(S)*

**2.1.6** No bit of the physical address selects device space: a device window is an ordinary range of physical addresses, found by enumeration (section 2.6), and the physical address is at least 40 bits and at most 64, an implementation choosing its width in that range, so that mappings of petabytes are possible. *(D)* A window can be mapped anywhere in the physical address space except the first few pages, where the boot code and boot data are loaded. *(D)* How many pages are "the first few" is not decided, *(P)* and nor is how software discovers the implemented width. *(S)* The simulator and the emulator place their devices in the upper half of a 40-bit space, from `0x8000000000`, and check the memory type of a page against that bit; those two arrangements belong to the present implementation, not to the architecture.

*Commentary on 2.1.6.* **Precedent.** The VAX-11/780 divided its physical address space in two: memory in the low half and the I/O space above `0x20000000` (the 4.3BSD kernel's `NEX780`), which holds one 8 KB window (`NEXSIZE`) per adaptor slot; the 4.3BSD `nexus.h` also records the 8600's, 8200's and MicroVAX's different bases, so the VAX itself kept changing the map from model to model. The PDP-11 put its devices in a fixed page at the top of the address space (a V7 driver's pointer to its registers is a constant in that page). PCI Express places each function's windows where enumeration assigns them. **Trade-offs.** A decoding bit makes the first routing decision in the bus fabric trivial and makes a mapping of the wrong memory type detectable, but it costs half of the physical address space; the author dropped it because mapping petabytes needs those bits. Without it, a device's DMA into another device's windows has to be refused by the IOMMU (errata 85) and not by the address. **Modern comparables.** Most systems split the map by address ranges chosen by the platform; x86 has a separate port space. **Impact.** *Kernel:* devices are mapped where enumeration says, and a device mapping is recognised by its memory type and its window, not by an address bit. *Compiler:* none. *Hardware:* the root complex decodes the windows it has assigned.

## 2.2 What the processor owes the bus

**2.2.1** The processor owes the bus exactly three things: a memory type per page, a `FENCE` instruction whose meaning against Q64 is defined, and atomics that can reach device memory. *(D)*

**2.2.2** A driver can be sure a descriptor is visible before it notifies the device: it builds the descriptor and publishes it in the queue, executes `FENCE`, and writes the queue's notification address (the doorbell). *(D)*

*Commentary.* **Precedent.** The PDP-11 needed none of this because there was one processor and no cache. **Trade-offs.** Three obligations is the whole contract, which keeps the device side free to change without respecifying the processor; a virtio device is written against the virtio specification and these three promises alone. **Benefits.** A device and a driver can be written against these three promises without knowing the processor's pipeline. **Modern comparables.** ARM's device-memory types and `DMB`/`DSB`, and RISC-V's `FENCE` with I/O bits, play the same roles. **Impact.** *Kernel:* One `FENCE` before the doorbell is the whole ordering rule. *Compiler:* `FENCE` is an intrinsic. *Hardware:* The memory type is two bits per page-table entry and the bus honours it.

## 2.3 When an access fails

**2.3.1** A read or instruction fetch of non-existent memory is a precise abort with cause `BUSFAULT`, at the faulting instruction. *(D)*

**2.3.2** A posted write that times out, and an uncorrectable memory error, are machine checks: imprecise and not restartable. A `FENCE` before a probe makes even a posted write precise at a known point. *(D)*

**2.3.3** `PROBER` and `PROBEW` test whether an address can be read or written without faulting. *(D)*

**2.3.4** Resetting the bus is a write to a register of the root complex, not an instruction. *(D)*

*Commentary.* **Precedent.** A PDP-11 read timeout was an unrestartable bus error, fatal to the process; the `nofault` idiom of V6 and V7 existed to probe for devices without dying. **Improvements.** The read timeout is a precise, restartable abort, and `PROBE` does the work of the idiom. **Benefits.** A driver that probes for a device handles a missing one in a few lines of ordinary fault-handling code, which is the recoverability principle at work. **Modern comparables.** x86 machine checks and ARM's `SError` correspond to the imprecise class; PCI returns all ones for a read of a removed device, which every driver must then learn to distrust, and the pdp64 avoids that convention. **Impact.** *Kernel:* A driver probes a missing device in a few lines of ordinary fault handling. *Compiler:* None. *Hardware:* A timeout counter in the bridge and a way to make a read abort precise.

## 2.4 Coherence and the hand-off

**2.4.1** Between processors the data caches are coherent without any software action, by snooping with three states (modified, shared, invalid), for two to four cores. *(D)*

**2.4.2** Between a processor and a DMA device they are not: buffers are mapped uncached and the hand-off is explicit. *(D)*

**2.4.3** The hand-off is five steps: the processor builds the descriptors and data in uncached memory, executes `FENCE`, writes the device's notification address; the device walks the descriptors, moves the data by DMA, writes the result and its used-ring entry, and raises an interrupt; the processor reads the result. *(D)*

**2.4.4** The write that raises a device's interrupt (a message-signalled write) cannot overtake the data writes that precede it on the same path. *(D)*

*Commentary.* **Precedent.** The 11/70's cache watched Unibus writes so that DMA appeared coherent; the VAX's Unibus adapter had buffered data paths that a driver had to purge. **Trade-offs.** Snooping the DMA path is expensive and DMA transfers are large, infrequent and have an explicit hand-off, so two mechanisms are used, each where it is cheap; the cost is that the processor reads received data from uncached memory, which is slow, and a cache-maintenance instruction would remove it for a non-coherent device that may come later. **Benefits.** No driver can forget a cache clean or invalidate, because there is none to forget. **Modern comparables.** x86 DMA is coherent; ARM and MIPS systems with non-coherent DMA need a DMA-mapping layer in the kernel to place cache maintenance correctly. **Impact.** *Kernel:* Uncached DMA buffers mean no driver cache code. *Compiler:* None. *Hardware:* A snoop port on each data cache for core coherence only; no snoop port for DMA.

## 2.5 Atomics on the bus

**2.5.1** The atomics are defined on a monitor: a load-linked takes a reservation, a write by any initiator clears it, and a store-conditional succeeds only if it is intact; the Unibus's `DATIP`/`DATO` locked pair is not an architectural primitive. *(D)*

**2.5.2** A device that writes memory shared with a core takes part by clearing reservations. *(D)*

*Commentary.* **Precedent.** The PDP-11's locked read-modify-write and the VAX's interlocked instructions are bus locks. **Trade-offs.** A lock is simple and a bottleneck as cores multiply; a monitor maps onto AXI's exclusive access and the memory systems of FPGAs and modern chips, at the cost of forward-progress rules. **Modern comparables.** RISC-V `LR`/`SC`, AArch64's exclusive loads and stores, and the large-system atomics that perform the operation at the memory. **Impact.** *Kernel:* Lock words and lock-free structures use the atomics of chapter 7. *Compiler:* C11 atomics lower to them. *Hardware:* A reservation monitor and an exclusive access, not a bus lock.

## 2.6 Enumeration and hot-plug

**2.6.1** The processor finds the devices by PCI Express enumeration: it reads the configuration space of each function through the root complex, sizes the base-address registers of the function and assigns its windows in device space. *(D)*

**2.6.2** A function is a virtio device when its configuration space says so (the virtio vendor identifier and a device identifier that carries the virtio device type); the capabilities in its configuration space locate the virtio structures in its windows (chapter 5). One transport driver serves every virtio device. *(D)*

**2.6.3** A function may itself be a bus: a PCI Express bridge presents the functions behind it, and a USB host controller (itself a PCI Express function) enumerates its own tree of hubs and devices, so any bus can be attached to Q64 and its devices enumerated, to any depth. The kernel's enumeration is one recursive walk. *(D)*

**2.6.4** The bus alerts the processor when a device enters or leaves, by an interrupt; the kernel then rescans the bus, which is also what it does at boot. *(P)*

**2.6.5** When a device leaves, an access to its windows is at once a precise bus fault, not a read of all ones: a read of the window faults, a posted write is dropped and counted, and the device's in-flight bus transactions are aborted. *(P)*

**2.6.6** The queued work of a departed device stays in memory untouched, so the driver can read, save, resend or fail it. *(P)*

**2.6.7** A bus reset produces no removal events, so a reset is not mistaken for the removal of every device, and the identity of every function is defined after the bus has lost power. *(D)*

**2.6.8** Where the configuration space and the windows of the functions sit in the physical address space (fixed bases and sizes) is unspecified, as is how a hot-plug event behind a bridge is reported. *(S)*

*Commentary.* **Precedent.** The VAX scanned its interconnect: `probenexi()` in 4.3BSD reads each nexus slot's status register, whose type field says what is plugged in; the Unibus had no enumeration at all, with devices at switch-set addresses and `badaddr()` probes, and nothing told the kernel when a device left. PCI sizes each device's windows by writing all ones to its base registers and assigns addresses; Amiga AutoConfig lets each board announce itself at a fixed address and be told where to live; NuBus gave each slot a fixed share of the address space. **Trade-offs.** Assignment on demand supports any layout at the cost of a sizing step at boot; a fixed window per slot needs no assignment and limits the slot count. Standard enumeration costs the processor nothing it does not already do for a PCI Express device, and means an ordinary card works unchanged. **Improvements.** On a surprise removal PCI returns all ones, so every driver must treat all ones as a possible error; the pdp64 uses the precise bus fault the instruction set already defines, so the driver has a single recovery path. Rescan on an event makes hot-plug and boot the same code. **Benefits.** The kernel needs one address, the root complex's, to find every device. **Modern comparables.** PCI Express enumerates through configuration space with hot-plug signalled by a slot-status interrupt; USB hubs report port changes through a status-change endpoint; NVMe and `virtio` keep their queues in host memory and re-queue them after a reset. **Impact.** *Kernel:* Enumeration is one recursive loop over the functions of each bus; hot-plug is an interrupt and a rescan. *Compiler:* None. *Hardware:* The root complex is a standard one; the pdp64 adds the precise fault for an absent device.

*Commentary on 2.6.3.* **Precedent.** The VAX did this: the Unibus hung off the VAX-11/780's interconnect through a Unibus adapter, a device on the nexus whose own registers include a table of map registers for DMA and whose Unibus memory (the devices' registers) appears in a window of its own (`UMEM780(i)` in `vaxuba/ubareg.h`, 4.3BSD); `unifind()` in `vax/autoconf.c` probes the devices behind each adapter. PCI-to-PCI bridges nest buses, a USB host controller enumerates a tree of hubs and devices, and Thunderbolt tunnels PCI Express over a cable. **Trade-offs.** Each level adds a mapping of windows and a hop of latency, and a departure deep in the tree must be reported to a driver that does not know the path; the cure for the first is that a bridge's windows are ordinary device space (ordinary device windows, section 2.1.6). **Improvements.** A new bus costs one bridge and no change to the processor, the kernel's walk or the driver model. **Benefits.** Any bus a board offers is connected by a bridge. **Modern comparables.** PCI Express switches and bridges, USB hubs, Thunderbolt, CXL, and the device-tree and ACPI descriptions of nested buses. **Impact.** *Kernel:* one recursive enumeration routine and one hot-plug path for every bus. *Compiler:* none. *Hardware:* a bridge is a standard PCI Express bridge.

## 2.7 Still open

The bus chapter's open items, each with options in the decisions document: the interrupt controller and routing (R1), starting the other cores and inter-processor interrupts (R2, B2), coherence beyond four cores (R3), the detail of the IOMMU (its five recommendations are accepted, errata 85), errors raised by devices (R7), virtualization (R8), where the configuration space and the windows sit in the physical address space and how wide that address is, and the exact feature subset of each virtio device.
