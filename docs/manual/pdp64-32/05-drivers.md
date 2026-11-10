# 5. The device driver model

[← manual index](00-index.md)

**A driver on the pdp64 is a short ordinary program: it maps a device's windows, negotiates features and sets up queues through the virtio transport, hands the device descriptors in memory and finds them marked used, and because every device speaks virtio the same transport code serves a network card, a display and a sound device, each with a thin class driver on top.** The chapter gives the driver writer's view of the memory-mapped registers and of DMA: what a driver sees, the virtio transport and its queue, the life of a driver from probe to detach, how data moves and what the driver need not do, the default devices, how errors and departures are handled, interrupts, and how this maps onto OpenBSD's driver interfaces. The bus the devices sit on, and how they are found, is chapter 2. Tags: *(D)* decided; *(P)* proposed; *(S)* unspecified.

## 5.1 What a driver sees

**5.1.1** A device is a PCI Express function whose windows (the regions its base-address registers describe) a driver maps with the device memory type, strongly ordered. *(D for the memory types; P for windows that start on page boundaries and are whole pages)*

**5.1.2** A driver reaches a register with an ordinary load or store; there are no input or output instructions and no port space. *(D)*

**5.1.3** Registers are naturally aligned and accessed at their own width; the machine is little-endian throughout and the virtio structures are little-endian, so a driver has no byte-order or byte-lane cases. *(D)*

**5.1.4** Accesses to a device page happen in program order; one `FENCE` separates the last write to memory the device will read from the write that notifies the device. *(D)*

*Commentary.* **Precedent.** A V7 driver is a structure laid over a fixed address: `rk.c` declares `struct device { int rkds; int rker; int rkcs; int rkwc; caddr_t rkba; int rkda; }` and a pointer to it at `0177400`, and reads and writes the fields. **Trade-offs.** A window of whole pages wastes address space and no memory, and lets the kernel give one device to one protection domain. **Improvements.** The register's address is a virtual address the kernel maps, so the driver is position-independent. **Benefits.** There is no accessor layer to learn and nothing to get wrong with endianness or alignment. **Modern comparables.** Linux and BSD wrap register access in an accessor (`readl`, `bus_space_read_8`) to hide port and memory differences and byte order; on the pdp64 those wrappers reduce to a load or a store. **Impact.** *Kernel:* No accessor layer: a register access is a load or a store. *Compiler:* Register access is a `volatile` load or store of the register's width through a pointer to a structure. *Hardware:* A device window is decoded by page address.

## 5.2 The device interface: virtio

**5.2.1** Every standard device is a virtio device or a USB (xHCI) controller; the disk, network, graphics and audio devices are virtio-blk, virtio-net, virtio-gpu (2D) and virtio-snd, over the virtio PCI Express transport, so that one transport driver and a thin class driver per device serve the system and the same devices run in QEMU, `sim64` and the FPGA. *(D)* Any other PCI Express device, an NVMe controller for example, may be attached with its own driver; it is not a standard device. *(D)*

**5.2.2** The driver finds a virtio device's structures through the capabilities in its configuration space: the common configuration, the notification area, the interrupt status and the device-specific configuration, each at an offset in one of the device's windows. *(D)* The common configuration has these fields, as the virtio specification lays them out:

| Offset | Field | Meaning |
|---|---|---|
| `0x00` | `device_feature_select` | which 32 bits of the device's features `device_feature` shows |
| `0x04` | `device_feature` | the device's feature bits (read-only) |
| `0x08` | `driver_feature_select` | which 32 bits of the driver's features `driver_feature` sets |
| `0x0C` | `driver_feature` | the features the driver accepts |
| `0x10` | `config_msix_vector` | the interrupt vector for a change of configuration |
| `0x12` | `num_queues` | how many queues the device has (read-only) |
| `0x14` | `device_status` | the handshake bits; writing zero resets the device |
| `0x15` | `config_generation` | changes when the device-specific configuration changes |
| `0x16` | `queue_select` | which queue the next fields describe |
| `0x18` | `queue_size` | the number of entries of the selected queue |
| `0x1A` | `queue_msix_vector` | the interrupt vector of the selected queue |
| `0x1C` | `queue_enable` | the driver sets it to 1 to start the queue |
| `0x1E` | `queue_notify_off` | where, in the notification area, the driver notifies this queue |
| `0x20` | `queue_desc` | physical address of the descriptor table |
| `0x28` | `queue_driver` | physical address of the available ring |
| `0x30` | `queue_device` | physical address of the used ring |

**5.2.3** A transfer is a chain of descriptors in a queue (a virtqueue) in host memory. A descriptor is 16 bytes: a 64-bit buffer address, a 32-bit length, 16 bits of flags (`NEXT`: the chain continues; `WRITE`: the device writes the buffer; `INDIRECT`: the buffer is a table of descriptors) and a 16-bit index of the next descriptor. *(D)*

```
descriptor:  ADDRESS(64)  LENGTH(32)  FLAGS(16)  NEXT(16)
available ring (the driver writes):  flags, idx, ring[ ] of descriptor-chain heads
used ring (the device writes):       flags, idx, ring[ ] of (head id, bytes written)
```

**5.2.4** The driver puts the head of a chain in the available ring and advances its index, executes `FENCE`, and writes the queue's notification address; the device carries the chain out and writes the head and the byte count in the used ring, advances the used index, and may interrupt. Progress is therefore in memory, not in the device. *(D)*

**5.2.5** The driver and device agree on features before any queue runs: the driver reads the device's features, writes the subset it accepts, and the device confirms it; the version-1 feature is required. *(D)* The feature subset that the pdp64 accepts for each device, and the platform-ordering feature that the pdp64 must declare, are not specified. *(S)*

**5.2.6** A device that carries traffic in two directions (a network card) has one queue for each direction in the one device; a console-like device is the same pattern. *(D)*

**5.2.7** Storage is virtio-blk: a virtqueue of requests, each a header (read, write or flush, and the sector), the data buffers and a status byte, the device marking the request done in the used ring. *(D)* An NVMe controller, which keeps a submission queue and a completion queue in host memory with a doorbell register for each (the shape of the virtqueue with a different command encoding), may be attached as any PCI Express device may; it is not the standard disk. *(D)*

*Commentary.* **Precedent.** The V7 RK11 disk is six registers (drive status, error, control and status, word count, bus address, disk address) with DMA by a word count and a bus address; the 4.3BSD DEUNA Ethernet is four registers plus transmit and receive rings in memory, each ring entry holding a segment length, an address, flags and errors, with an `OWN` bit that is zero when the descriptor belongs to the driver. The virtqueue is the second design, standardised: the done mark is the used ring instead of a bit in the descriptor. **Trade-offs.** A queue per direction keeps each ring in order and simple; the used ring costs one write per chain. Taking a standard interface rather than a design of the pdp64's own gives up the freedom to shape the registers and gains every driver and every emulated device that already exists. **Improvements.** Because progress lives in the rings and not in a device register, a driver can recover from a departed or reset device with one routine: scan the available ring for chains that are not in the used ring, then read, save, resend or fail them. **Benefits.** A driver is a skeleton shared by all devices. **Modern comparables.** `virtio` rings, NVMe's submission and completion queues, the descriptor-done bit of Intel Ethernet controllers and the command lists of SATA controllers are all rings with a done mark. **Impact.** *Kernel:* One transport driver and a thin driver per class. *Compiler:* The descriptor is a 16-byte aligned C structure, and register offsets are generated constants. *Hardware:* A device is a standard PCI Express function and the virtio interface is the specification's.

## 5.3 The life of a driver

**5.3.1** *Probe.* The kernel enumerates the bus (section 2.6), reads each function's identifiers, and matches the virtio device type (or the USB class) against the drivers it has. *(D)*

**5.3.2** *Attach.* The driver resets the device (zero to `device_status`), sets the acknowledge and driver bits, negotiates features, sets the features-ok bit and reads it back, sets up each queue (its size and the three addresses, then `queue_enable`), and sets the driver-ok bit. *(D)*

**5.3.3** *Run.* The driver puts the queue in uncached memory, fills descriptors, publishes the chain in the available ring, executes `FENCE`, and notifies the queue; a chain is complete when it appears in the used ring, which the driver sees by polling or by the interrupt. *(D)*

**5.3.4** *Fail.* A device that sets its needs-reset bit, or that stops answering, is reset and its queues reprogrammed, and the driver resubmits the chains that are not in the used ring. *(P for the resubmission rule; D for the reset)*

**5.3.5** *Detach.* A departure event, or a bus fault from an absent device, tells the driver to stop; it reads, saves, resends or fails the chains still queued. *(P)*

*Commentary.* **Precedent.** A V7 disk driver is a strategy routine that queues a buffer, a start routine that writes the registers, and an interrupt routine that completes the buffer; 4.3BSD's Unibus drivers add a probe routine that tests whether a device answers at an address and an attach routine, which BSD's autoconfiguration calls in order. **Trade-offs.** The five steps are the same for every device, so the work that differs is the personality: what the requests mean. **Improvements.** Probe reads the bus and not a configuration file, and detach is a defined path because the bus reports departures. **Benefits.** A new device is a new set of requests in a driver that already has the skeleton. **Modern comparables.** OpenBSD's autoconfiguration calls a driver's `match`, `attach` and `detach` functions; Linux's driver model has `probe` and `remove`. **Impact.** *Kernel:* The five steps are the same for every driver, so only the requests differ. *Compiler:* Nothing special. *Hardware:* None beyond the device's own.

## 5.4 DMA and the hand-off

**5.4.1** Buffers and queues are in memory mapped uncached, and the driver does no cache clean or invalidate. *(D)*

**5.4.2** A device addresses physical memory directly and the driver gives it physical addresses; until an address-translation unit for devices exists, every device must be able to address all of memory. *(P)*

**5.4.3** A buffer that crosses a page is described by several descriptors chained with the `NEXT` flag; the driver does not make buffers contiguous. *(D)*

**5.4.4** The device writes the data, then the used-ring entry, then advances the used index; the driver reads the used index and then the data. *(D)*

*Commentary.* **Precedent.** The Unibus carried 18 address bits, so the VAX and the larger PDP-11s had map registers (`uballoc` in 4.3BSD) translating device addresses to memory, and the VAX's adapter had data paths a driver had to purge before reading; the 11/70's cache watched DMA writes so that the data appeared coherent. **Trade-offs.** Uncached buffers make the processor's reads of received data slow, in return for a driver that cannot forget a cache operation; a non-coherent device that came later would call for cache-maintenance instructions. No address-translation unit means no protection from a faulty or malicious device. **Benefits.** The sequence build, `FENCE`, notify, complete is the whole of the hand-off. **Modern comparables.** ARM and MIPS systems with non-coherent DMA need a DMA-mapping layer that places cache maintenance; x86 DMA is coherent; `swiotlb` in Linux copies for devices that cannot address all memory. **Impact.** *Kernel:* No cache clean or invalidate in any driver, so none can be forgotten. *Compiler:* None. *Hardware:* DMA goes around the processor's data cache, so the cache needs no snoop port for devices.

## 5.5 The default devices

**5.5.1** The **disk** is virtio-blk (the author's decision of 2026-11-10, errata 101) with read, write and flush at 512-byte sectors. *(D)* The boot ROM reads block 0 with one read request on the device's queue. *(P)*

**5.5.2** The **network card** is virtio-net: a receive queue the host fills with buffers for the device and a transmit queue of frames to send; the device completes each receive buffer with the frame length. *(D)*

**5.5.3** The **graphics device** is virtio-gpu in its 2D mode (create a surface, point it at memory, flush a rectangle) and the **audio device** is virtio-snd (streams in queues in shared memory). *(D)*

**5.5.4** **USB** is an xHCI host controller, a PCI Express function, driven by the operating system's USB stack, which enumerates the attached devices. *(P)*

**5.5.5** The form of the console, the timer and the entropy source under this interface is not specified: the candidates are a UART-style console, a small fixed timer and interrupt controller that need no enumeration, and virtio's console and entropy devices; the entropy pool is one device shared by all cores. *(S)*

*Commentary.* **Precedent.** The PDP-11 had a disk with eight registers, a serial line with four, and network controllers with rings. **Trade-offs.** One transport for network, graphics and audio means one driver, and the cost is the feature negotiation and the queue format of a standard that the pdp64 does not control. An existing USB stack comes with xHCI, at the price of that large stack. **Improvements.** A card of any vendor that speaks the standard works with the drivers already written. **Benefits.** OpenBSD's tree has drivers for several virtio devices (`if_vio`, `vioblk`, `viornd`, `viogpu`, `viocon`) under `sys/dev/pv`, by the listing recorded in `security-proposals.md`; whether it has one for virtio-snd is open. **Modern comparables.** xHCI is the conventional USB controller; a USB-to-Ethernet adapter appears to the host as a network class device. **Impact.** *Kernel:* One transport driver, a thin driver per class. *Compiler:* None. *Hardware:* Standard PCI Express devices; the same virtio devices in the emulator, the simulator and the FPGA.

## 5.6 Errors, departure and recovery

**5.6.1** A request that fails completes with the status of its device class (for a virtio-blk request, a status byte in the last descriptor of its chain); a device that is broken sets its needs-reset bit in `device_status`. *(D)*

**5.6.2** A device that is reset leaves its queues in memory untouched; the driver reprograms the queue registers and resubmits the chains that are not in the used ring. *(P)*

**5.6.3** A device that leaves the bus leaves its queued work in memory; the driver finds it by comparing the available ring with the used ring. *(P)*

**5.6.4** Requests are repeatable where possible (reads, writes of the same data, sends, buffer posts), so that resending an unfinished chain is safe; a request that must not run twice is tracked by its class driver, which can tell "never started" from "started, outcome unknown" only by the request's own status. *(P)*

*Commentary.* **Precedent.** 4.3BSD's `ubareset()` resets the Unibus adapter and then calls each driver's reset routine, so each driver re-issues what was pending: resending as a design, driver by driver. **Trade-offs.** The cost is a write to the used ring per chain and the ordering rule between data and the used index. **Improvements.** One recovery routine serves a device that fails and is reset, a device replaced by another, and, with a saved queue, a hand-over between cores. **Benefits.** This is the recoverability principle in the driver: fewer failure outcomes (the precise bus fault, not all ones on a removed device) and one path to recover from any of them. **Modern comparables.** NVMe and virtio drivers requeue outstanding requests after a reset; PCI returns all ones for a read of a removed device. **Impact.** *Kernel:* One recovery routine handles a failed, reset, replaced or departed device. *Compiler:* None. *Hardware:* The device writes data before the used entry before the used index.

## 5.7 Interrupts from devices

**5.7.1** A device interrupts by a message-signalled write (MSI-X): the configuration change and each queue have a vector that the driver sets in the common configuration, and the interrupt status structure says why. *(P)*

**5.7.2** A driver may mask a device's interrupts and poll the used ring instead. *(D)*

**5.7.3** A changeable interrupt target is changed with its vector masked and then read back, or is a single atomic register write. *(D)*

**5.7.4** The write that raises an interrupt cannot overtake the data writes that precede it (section 2.4.4). *(D)*

*Commentary.* **Precedent.** A PDP-11 device asserted one of four bus-request lines and supplied its own vector, set by switches on the card. **Trade-offs.** A message carries its own vector, so no switch and no assignment table are needed; the controller and routing are an open decision (R1). **Benefits.** A driver's interrupt routine reads the used ring to learn what completed. **Modern comparables.** MSI-X is how PCI Express devices interrupt. **Impact.** *Kernel:* An interrupt routine reads the used ring and the status structure. *Compiler:* None. *Hardware:* An MSI-X target in the interrupt controller, and the eight-level priority encoder.

## 5.8 Drivers in user space, and in OpenBSD

**5.8.1** Because a device's windows are whole pages, a driver can run in user space with only those pages and its buffers mapped. *(P)*

**5.8.2** Until devices have an address-translation unit, a user-space driver can instruct its device to write anywhere in memory, so it is as trusted as the device. *(P)*

**5.8.3** In OpenBSD the register accessors become loads and stores, the DMA mapping interface returns physical addresses with no cache-synchronisation work to do, and the autoconfiguration framework attaches a driver to each function the bus reports. *(P)*

*Commentary.* **Precedent.** Microkernels and exokernels run drivers in user space where the hardware lets one device be mapped to one process; the PDP-11's Unibus gave every device a fixed address and no protection. **Trade-offs.** Without a translation unit the mapping protects against stray register writes but not against DMA. **Benefits.** A driver can be tested, restarted and replaced without taking the kernel with it. **Modern comparables.** Linux's `VFIO` and `UIO` and DPDK run drivers in user space, relying on an I/O translation unit for protection. **Impact.** *Kernel:* The accessors reduce to loads and stores, the DMA interface to physical addresses, and attach to the functions the bus reports. *Compiler:* None. *Hardware:* Windows of whole pages let the translation unit protect a device.

## 5.9 Still open

The feature subset of each virtio device and the platform-ordering feature, the form of the console, the timer and the entropy source, the feature subset of virtio-blk (flush, block size, ordering), DMA addressing and protection (R6), errors raised by devices (R7), and the details of interrupt routing (R1). The working documents are [`../decisions-pending.md`](../../decisions-pending.md) and [`../pdp64-q64-bus.md`](../../pdp64-q64-bus.md), and appendix B.
