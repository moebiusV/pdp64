# 5. The device driver model

[← streamlined index](00-index.md)

**A driver on the pdp64 is a short ordinary program: it maps a device's page, writes eight registers, hands the device descriptors in memory, and finds them marked done, and because the device is always the same shape the same driver skeleton serves a disk, a network card and a serial line.** This chapter is the driver writer's view of the memory-mapped registers and of DMA: what a driver sees, the uniform eight-register convention and its descriptor, the life of a driver from probe to detach, how data moves and what the driver need not do, the default devices, how errors and departures are handled, interrupts, and how this maps onto OpenBSD's driver interfaces. The bus the devices sit on is chapter 2. Tags: *(D)* decided; *(P)* proposed and not yet settled; the drivers are expected to be trivially small because a device is eight registers, which the author has settled.

## 5.1 What a driver sees

**5.1.1** A device is eight 64-bit registers at the start of its own 4 KB page, and the page is mapped with the device memory type, strongly ordered. *(P for the page per device; D for the memory types)*

**5.1.2** A driver reaches a register with an ordinary load or store; there are no input or output instructions and no port space. *(D)*

**5.1.3** The registers are 64 bits wide, naturally aligned and accessed whole; the machine is little-endian throughout, so a driver has no byte-order or byte-lane cases. *(D)*

**5.1.4** Accesses to a device page happen in program order; one `FENCE` separates the last write to memory the device will read from the write of the doorbell. *(D)*

*Commentary.* **Precedent.** A V7 driver is a structure laid over a fixed address: `rk.c` declares `struct device { int rkds; int rker; int rkcs; int rkwc; caddr_t rkba; int rkda; }` and a pointer to it at `0177400`, and reads and writes the fields. **Trade-offs.** One page per device wastes address space and no memory, and lets the kernel give one device to one protection domain. **Improvements.** The register's address is a virtual address the kernel maps, so the driver is position-independent and the same code serves any slot. **Benefits.** There is no accessor layer to learn and nothing to get wrong with endianness or alignment. **Modern comparables.** Linux and BSD wrap register access in an accessor (`readl`, `bus_space_read_8`) to hide port and memory differences and byte order; on the pdp64 those wrappers reduce to a load or a store. **Impact.** *Kernel:* No accessor layer: a register access is a load or a store. *Compiler:* Register access is a 64-bit `volatile` load or store through a pointer to a structure. *Hardware:* A device is decoded by page address; its eight registers are an eight-way decode within the page.

## 5.2 The device convention: eight registers and DMA

**5.2.1** Each device is eight memory-mapped registers and moves its data by DMA. *(D, errata 29)*

**5.2.2** The first three registers are the same in every device: `ID`, `CONTROL` and `STATUS`. *(P)*

| Offset | Register | Meaning |
|---|---|---|
| `0x00` | `ID` | type, variant, version, feature bits (read-only) |
| `0x08` | `CONTROL` | enable, `INIT` (initialise yourself), interrupt enable |
| `0x10` | `STATUS` | `READY`, `ERROR`, `BUSY`, error code |
| `0x18` | `RING_BASE` | physical address of the descriptor ring |
| `0x20` | `RING_SIZE` | the ring's size in entries (a power of two) |
| `0x28` | `DOORBELL` | write the producer index to start work |
| `0x30` | `IRQ` | cause bits (complete, error, attention); write 1 to clear |
| `0x38` | `DEVICE` | device-specific (for the polled devices, the data register) |

**5.2.3** A transfer is a 32-byte descriptor in a ring in host memory: four 64-bit words giving an operation and flags, a status field the device writes, a length, a buffer address, an argument (a block number, for a disk) and a result the device writes. *(P)*

```
word 0:  OP(8) FLAGS(8) STATUS(16) LENGTH(32)     FLAGS: OWN, STARTED, INTERRUPT, MORE
word 1:  ADDRESS (physical)
word 2:  ARGUMENT
word 3:  RESULT (written by the device)
```

**5.2.4** The host sets `OWN` when it hands a descriptor to the device; the device clears it when it is finished, after writing the data, the status and the result. Progress is therefore in memory, not in the device. *(P)*

**5.2.5** `INIT` makes a device initialise itself without touching the ring; a device may take a firmware image through an ordinary descriptor operation; boot-critical devices work without any image. *(P)*

**5.2.6** Operations common to all devices: no-op, identify (the device writes an identification block into a buffer) and load-firmware; each device adds its own from `0x10`. *(P)*

**5.2.7** A device that carries traffic in two directions (a network card, a serial line) is two slots, one ring each; a console, a timer and an entropy source are polled devices with their data in the last register. *(P)*

*Commentary.* **Precedent.** The V7 RK11 disk is six registers (drive status, error, control and status, word count, bus address, disk address) with DMA by a word count and a bus address; the 4.3BSD DEUNA Ethernet is four registers plus transmit and receive rings in memory, each ring entry holding a segment length, an address, flags and errors, with an `OWN` bit that is zero when the descriptor belongs to the driver. The proposal is the second design, kept uniform. **Trade-offs.** A single ring per device makes duplex devices two slots, which is simple and slightly unusual, in exchange for in-order completion and no out-of-order bookkeeping; the ownership bit costs one status write per descriptor. **Improvements.** Because progress lives in the descriptor and not in a device register, a driver can recover from a departed or reset device with one routine: scan the ring for descriptors that are not done, then read, save, resend or fail them. **Benefits.** A driver is a skeleton shared by all devices, and the hardware is one reusable ring engine that fetches a descriptor, hands the operation to the device's own logic and writes the status back. **Modern comparables.** `virtio` rings, NVMe's submission and completion queues, the descriptor-done bit of Intel Ethernet controllers and the command lists of SATA controllers are all rings with a done mark; the 16550 serial chip is the classic eight-register device. **Impact.** *Kernel:* One driver skeleton serves every device, and the layout is the same for a disk, a network card and a serial line. *Compiler:* The descriptor is a 32-byte aligned C structure, and register offsets are generated constants. *Hardware:* One reusable ring engine fetches a descriptor, hands the operation to the device's logic and writes the status back.

## 5.3 The life of a driver

**5.3.1** *Probe.* The kernel reads the bus controller's slots (section 2.6), reads each present device's `ID` register, and matches the type and version against the drivers it has. *(P)*

**5.3.2** *Attach.* The driver maps the slot's page, writes `INIT`, waits for `READY`, and reads the device's identification block by submitting an identify descriptor. *(P)*

**5.3.3** *Run.* The driver puts the ring in uncached memory, writes `RING_BASE` and `RING_SIZE`, fills descriptors with `OWN` set, executes `FENCE`, and writes `DOORBELL`; a descriptor is complete when the device has cleared `OWN`, which the driver sees by polling or by the interrupt. *(P)*

**5.3.4** *Fail.* A failed descriptor completes with an error code in its status; a device that stops answering is reset with `INIT` and its ring reprogrammed from the first descriptor that is not done. *(P)*

**5.3.5** *Detach.* A departure event, or a bus fault from an absent slot, tells the driver to stop; it reads, saves, resends or fails the descriptors still queued. *(P)*

*Commentary.* **Precedent.** A V7 disk driver is a strategy routine that queues a buffer, a start routine that writes the registers, and an interrupt routine that completes the buffer; 4.3BSD's Unibus drivers add a probe routine that tests whether a device answers at an address and an attach routine, which BSD's autoconfiguration calls in order. **Trade-offs.** The five steps are the same for every device, so the work that differs is the personality: what the operations mean. **Improvements.** Probe reads the bus and not a configuration file, and detach is a defined path because the bus reports departures. **Benefits.** A new device is a new set of operations in a driver that already has the skeleton. **Modern comparables.** OpenBSD's autoconfiguration calls a driver's `match`, `attach` and `detach` functions; Linux's driver model has `probe` and `remove`. **Impact.** *Kernel:* The five steps are the same for every driver, so only the operations differ. *Compiler:* Nothing special. *Hardware:* The `INIT` and `READY` handshake is a small state machine in each device.

## 5.4 DMA and the hand-off

**5.4.1** Buffers and descriptors are in memory mapped uncached, and the driver does no cache clean or invalidate. *(D)*

**5.4.2** A device addresses physical memory directly, with 40-bit addresses, and the driver gives it physical addresses; until an address-translation unit for devices exists, every device must be able to address all of memory. *(P, decision R6)*

**5.4.3** A buffer that crosses a page is described by several descriptors chained with the `MORE` flag; the driver does not make buffers contiguous. *(P)*

**5.4.4** The device writes the data, then the status and result, then clears `OWN`; the driver reads `OWN` and then the data. *(P)*

*Commentary.* **Precedent.** The Unibus carried 18 address bits, so the VAX and the larger PDP-11s had map registers (`uballoc` in 4.3BSD) translating device addresses to memory, and the VAX's adapter had data paths a driver had to purge before reading; the 11/70's cache watched DMA writes so that the data appeared coherent. **Trade-offs.** Uncached buffers make the processor's reads of received data slow, in return for a driver that cannot forget a cache operation; a non-coherent device that came later would call for cache-maintenance instructions. No address-translation unit means no protection from a faulty or malicious device. **Benefits.** The sequence build, `FENCE`, doorbell, complete is the whole of the hand-off. **Modern comparables.** ARM and MIPS systems with non-coherent DMA need a DMA-mapping layer that places cache maintenance; x86 DMA is coherent; `swiotlb` in Linux copies for devices that cannot address all memory. **Impact.** *Kernel:* No cache clean or invalidate in any driver, so none can be forgotten. *Compiler:* None. *Hardware:* DMA goes around the processor's data cache, so the cache needs no snoop port for devices.

## 5.5 The default devices

**5.5.1** The **disk** has the operations read, write and flush at 512-byte sectors, with the block number in the argument word; its identification block gives the capacity in sectors and the sector size; the boot ROM reads block 0 with one descriptor. *(P)*

**5.5.2** The **network card** is a transmit slot and a receive slot: the transmit ring carries frames to send, the receive ring carries buffers the host posts and the device fills, completing each with the frame length; link changes raise an attention interrupt. *(P)*

**5.5.3** **USB** is presented by a controller chip that does the protocol and the enumeration and shows each attached device as a slot on the bus with the personality of its class: a mass-storage device looks like a disk, a keyboard or mouse like a receive-only device, a serial adapter like a console. *(P, decision for the author)*

**5.5.4** The **console** is a polled serial device with a transmit-ready and a receive-ready bit and one data register; the **timer** is a 64-bit free-running counter, a compare register and a control register; the **entropy source** returns 64 random bits from its data register and fills buffers by descriptor. *(console and timer D, as built in the emulator; entropy P)*

**5.5.5** A device raises one interrupt line at the level its slot asks for, with the vector numbered from the slot. *(P)*

*Commentary.* **Precedent.** The PDP-11 had a disk with eight registers, a serial line with four, and network controllers with rings; this is the same set with a common layout. **Trade-offs.** USB in eight registers is the hard case: a conventional host controller exposes command, event and transfer rings and many registers. Presenting each device as a bus slot moves the protocol into the controller chip, which costs gates or a small embedded processor in the controller and takes the USB stack out of the operating system; the alternative is a conventional ring-based host controller, which an existing operating-system USB stack can drive at the price of that large stack. The decision is the author's. **Improvements.** Treating every USB port as a hot-pluggable slot reuses the bus's own enumeration and hot-plug machinery instead of a second one. **Benefits.** A disk driver written for the bus disk works for a USB disk. **Modern comparables.** `virtio` block and network devices have the same shape; xHCI is the conventional USB controller; a USB-to-Ethernet adapter appears to the host as a network class device. **Impact.** *Kernel:* A disk driver written for the bus disk also drives a USB disk; the network card is two slots. *Compiler:* None. *Hardware:* Each personality is a small block of logic behind the common ring engine; the USB protocol, if done in the controller, is where the gates go.

## 5.6 Errors, departure and recovery

**5.6.1** A descriptor's status carries a code: success; bad operation; bad address (a DMA access faulted); bad length; media error; not ready; aborted (the device was reset); bad image. *(P)*

**5.6.2** A device that is reset with `INIT` leaves its ring in memory untouched and clears its ring registers; the driver reprograms them and starts at the first descriptor that is not done. *(P)*

**5.6.3** A device that leaves the bus leaves its queued work in memory; the driver finds it by scanning the ring from its last completed descriptor. *(P, the author's suggestion)*

**5.6.4** Operations are repeatable where possible (reads, writes of the same data, sends, buffer posts, identify), so that resending an unfinished descriptor is safe; an operation that must not run twice carries a `STARTED` flag so the driver can tell "never started" from "started, outcome unknown". *(P)*

*Commentary.* **Precedent.** 4.3BSD's `ubareset()` resets the Unibus adapter and then calls each driver's reset routine, so each driver re-issues what was pending: resending as a design, driver by driver. **Trade-offs.** The cost is a status write per descriptor and the ordering rule between data and the done mark. **Improvements.** One recovery routine serves a device that fails and is reset, a device replaced by another, and, with a saved ring, a hand-over between cores. **Benefits.** This is the recoverability principle in the driver: fewer failure outcomes (the precise bus fault, not all ones on a removed device) and one path to recover from any of them. **Modern comparables.** NVMe and virtio drivers requeue outstanding requests after a reset; PCI returns all ones for a read of a removed device. **Impact.** *Kernel:* One recovery routine handles a failed, reset, replaced or departed device. *Compiler:* None. *Hardware:* The device writes data before status before clearing the ownership bit, and the bus keeps one presence bit per slot.

## 5.7 Interrupts from devices

**5.7.1** A device raises one interrupt line, at the priority level its slot asks for, and its cause is in the `IRQ` register, where each bit is cleared by writing a 1. *(P)*

**5.7.2** The vector of a device interrupt is its slot number added to 64. *(P)*

**5.7.3** A polled device (the console, the timer, the entropy source) may be used with its interrupts masked. *(D)*

*Commentary.* **Precedent.** A PDP-11 device asserted one of four bus-request lines and supplied its own vector, set by switches on the card. **Trade-offs.** A vector derived from the slot needs no per-device switch and no assignment, and limits the device interrupts to 192 slots. **Benefits.** A driver's interrupt routine reads one register to learn why. **Modern comparables.** The causes and the write-one-to-clear convention are those of most memory-mapped controllers; message-signalled interrupts, which need no line, are added to the proposal later (decision R1). **Impact.** *Kernel:* An interrupt routine reads one register to learn why and clears it by writing the same bits. *Compiler:* None. *Hardware:* One line per device into an eight-level priority encoder, with the vector derived from the slot number.

## 5.8 Drivers in user space, and in OpenBSD

**5.8.1** Because a device is one page, a driver can run in user space with only that page and its buffers mapped. *(P)*

**5.8.2** Until devices have an address-translation unit, a user-space driver can instruct its device to write anywhere in memory, so it is as trusted as the device. *(P, decision R6)*

**5.8.3** In OpenBSD the register accessors become loads and stores, the DMA mapping interface returns physical addresses with no cache-synchronisation work to do, and the autoconfiguration framework attaches a driver to each slot the bus reports. *(P, to be checked against the OpenBSD sources)*

*Commentary.* **Precedent.** Microkernels and exokernels run drivers in user space where the hardware lets one device be mapped to one process; the PDP-11's Unibus gave every device a fixed address and no protection. **Trade-offs.** Without a translation unit the mapping protects against stray register writes but not against DMA. **Benefits.** A driver can be tested, restarted and replaced without taking the kernel with it. **Modern comparables.** Linux's `VFIO` and `UIO` and DPDK run drivers in user space, relying on an I/O translation unit for protection. **Impact.** *Kernel:* The accessors reduce to loads and stores, the DMA interface to physical addresses, and attach to the bus's slots. *Compiler:* None. *Hardware:* One device per page lets the translation unit protect a device, which a device-sharing page layout would not.

## 5.9 Still open

The register layout and descriptor details (decision R5), whether USB is a per-slot controller or a conventional ring controller, whether the emulator uses `virtio` devices first to reach an OpenBSD login sooner, DMA addressing and protection (R6), errors raised by devices (R7), and the details of the interrupt vector and cause (R1). The proposal is in the working documents ([`../decisions-pending.md`](../decisions-pending.md), [`../pdp64-q64-bus.md`](../pdp64-q64-bus.md)) and appendix B.
