# 5. The device driver model

[← manual index](00-index.md)

**A driver on the pdp64 is an ordinary program that finds a device by its identifiers, agrees features with it, gives it queues in memory, hands it requests as chains of descriptors and learns from the used ring that they are done, by an interrupt or by polling; because every standard device speaks virtio, one transport routine serves the disk, the network card, the display and the sound device, and each has a thin class driver on top.** The form of the console, the timer and the entropy source is not specified (5.7).

This chapter is written for a reader who has written or read a driver for V6, V7 or 2.11BSD Unix (a `strategy` routine, a `struct buf`, the CSR of an RK11, an interrupt vector pair), or who is learning computing from the start, and who has not met virtio, PCI Express, MSI-X, a driver that attaches by matching identifiers, or a machine description that is not compiled into the kernel. It runs from what that reader knows to what the pdp64 does: the PDP-11 driver (5.1), the systems between (5.2), what a driver is now (5.3), the interface it programs (5.4), its life (5.5), the disk (5.6), the console, timer and entropy source (5.7), the network, display, sound and USB drivers (5.8), interrupts (5.9), the memory a device reaches (5.10), errors (5.11), firmware (5.12), where drivers run and how they are written in C (5.13) and how one is tested (5.14). The bus, the virtio structures and the MSI-X table are chapter 2; this chapter uses them and does not repeat them. Tags: *(D)* decided; *(P)* proposed; *(S)* unspecified. A fact about an older or another machine is marked **(read)** when it was read in a source on this computer, **(repo)** when it comes from the repository's documents, and *unverified* when it is general knowledge that could not be checked here; 5.15 lists what was checked.

*How to read this chapter.* A term is defined where it first appears, as the technical word followed by a plain restatement. Boxes-and-arrows pictures are the kind a textbook draws for a linked list: a box is a piece of memory or a program, an arrow says what is handed on. Code blocks are C-like pseudocode (`#` starts a comment, `mmio_read32(address)` and the like are ordinary loads and stores to a device register) unless the text says they are V7 or 2.11BSD C, quoted from the sources on this computer. **No pdp64 driver has been written**: every pdp64 listing in this chapter is an illustration, and so is untested, except where it names a test that exists (5.14). The decisions are the numbered statements; where the repository does not say, the text says *not specified*.

## 5.1 What you already know: a PDP-11 driver

A **driver** (the part of the kernel that knows how to operate one kind of device, and nothing else) in V7 or 2.11BSD has four parts: a structure laid over the device's registers, entry points listed in a table, an interrupt routine, and a way of being found and started. The disk driver `rk.c` has all four (135 lines in V7, 204 in 2.11BSD, counted), and the console driver is a second example.

**The registers.** V7's `rk.c` begins with `#define RKADDR ((struct device *)0177400)` and declares the structure `struct device { int rkds; int rker; int rkcs; int rkwc; caddr_t rkba; int rkda; }`: six words at a fixed address, which chapter 2 (2.1) explains and draws. The driver reads and writes the fields. In the control and status register (the **CSR**, one word whose bits both command the device and report on it) the bits it needs are GO (01), IDE (interrupt on done enable, 0100), RDY (0200) and ERR (0100000) (2.11BSD `rkreg.h`).

**The device switch.** The kernel does not know drivers by name. Two arrays, `bdevsw` for block devices and `cdevsw` for character devices, hold one row of function pointers per driver, and the **major device number** (one half of a device number; the other half, the **minor number**, selects a unit within the driver) picks the row. In 2.11BSD's `pdp/conf.c` the RK05 is row 6 of `bdevsw` and row 15 of `cdevsw`:

```
/* bdevsw: open, close, strategy, root, size, flags */
/* rk = 6 */    rkopen,  rkclose,  rkstrategy,  nulldev,  rksize,  0,
/* cdevsw: open, close, read, write, ioctl, stop, ttys, select, strategy */
/* rk = 15 */   rkopen, rkclose, rawrw, rawrw, nodev, nulldev, 0, seltrue, rkstrategy,
```

A disk has both rows. Through the block row the kernel reads and writes 512-byte blocks by way of its **buffer cache** (disk blocks kept in memory), and through the character row `rawrw` reaches the same `rkstrategy` for the **raw** interface, which moves data between the disk and a user's memory without the cache.

**The strategy, start and interrupt routines.** A block driver is three routines around a queue. This is V7's `rk.c` with the disk-statistics lines left out:

```
rkstrategy(bp)  register struct buf *bp;
{
        /* give the device an address it can use */
        if(bp->b_flags&B_PHYS)  mapalloc(bp);
        if (bp->b_blkno >= NRKBLK) { bp->b_flags |= B_ERROR; iodone(bp); return; }
        bp->av_forw = (struct buf *)NULL;
        /* keep rkintr out while the queue changes */
        spl5();
        if(rktab.b_actf == NULL) rktab.b_actf = bp; else rktab.b_actl->av_forw = bp;
        rktab.b_actl = bp;
        /* the device is idle: start it */
        if(rktab.b_active == NULL) rkstart();
        spl0();
}
rkstart()
{
        if ((bp = rktab.b_actf) == NULL) return;
        rktab.b_active++;
        bn = bp->b_blkno;  dn = minor(bp->b_dev);  cn = bn/12;  sn = bn%12;
        RKADDR->rkda = (dn<<13) | (cn<<4) | sn;          /* disk address     */
        RKADDR->rkba = bp->b_un.b_addr;                  /* memory address   */
        RKADDR->rkwc = -(bp->b_bcount>>1);               /* words, negative  */
        com = ((bp->b_xmem&3) << 4) | IENABLE | GO;
        if(bp->b_flags & B_READ) com |= RCOM; else com |= WCOM;
        /* go; the interrupt comes when done */
        RKADDR->rkcs = com;
}
rkintr()
{
        if (rktab.b_active == NULL) return;
        bp = rktab.b_actf;  rktab.b_active = NULL;
        if (RKADDR->rkcs < 0) {                          /* the error bit */
                deverror(bp, RKADDR->rker, RKADDR->rkds);
                RKADDR->rkcs = RESET|GO;
                while((RKADDR->rkcs&CTLRDY) == 0) ;
                /* retry up to ten times */
                if (++rktab.b_errcnt <= 10) { rkstart(); return; }
                bp->b_flags |= B_ERROR;
        }
        rktab.b_errcnt = 0;
        rktab.b_actf = bp->av_forw;
        /* wake whoever sleeps on this buffer */
        iodone(bp);
        rkstart();                                       /* the next request */
}
```

The **buffer header** `struct buf` is the kernel's record of one transfer: the device (`b_dev`), the block number (`b_blkno`), the byte count (`b_bcount`), the memory address (`b_un.b_addr`, with `b_xmem` for the bits above 16), flags such as `B_READ` and `B_ERROR`, and a link (`av_forw`) that chains it onto the driver's queue (`buf.h`). The strategy routine is called by the file system or by `physio`, one buffer at a time. Because the controller does one transfer at a time, the queue of waiting requests lives in the kernel's memory, and `rkstart` feeds the hardware from it. `spl5()` is one of the **spl** functions (set priority level: they write the priority bits of the processor status word); while the priority is 5, an interrupt of level 5 or lower waits, so `rkintr` cannot run between the test of the queue and its change. 2.11BSD writes `s = splbio(); ... splx(s)`, which restores the previous level and does not drop to 0, and `splx` writes the low byte of the status word at `0177776` (`rk.c`, `machparam.h`, read).

**The interrupt vector.** A device that finishes asserts a **bus request** line, BR4 to BR7 (the RK11 uses BR5); when the processor's priority is lower, it takes the interrupt, and the device supplies a **vector**, a number set by switches on the card that is the address of two words in low memory: a new program counter and a new status word. The processor pushes the old pair on the stack and loads the new one (6.3 gives the pdp64's version). 2.11BSD's `pdp/scb.s` fills the pair for the RK11 with `DEVTRAP(220, rkintr, br5)`: at address 0220, the address of `rkintr` and priority 5. The routine ends with `RTI`, return from interrupt.

**INIT and READY.** A device is put in a known state by a command and a wait. `rkintr` above writes `RESET|GO` to the CSR and spins until `CTLRDY` (the RDY bit) comes back; `rkprobe` writes `DRESET|GO`; the RX02 floppy controller has a bit named `RX_INIT`, "initialize" (`rxreg.h`, read). All the work happens behind the register, in the device's own logic: the driver writes one bit and waits for another. Chapter 4 (4.8, statement 4.8.1) keeps this as the PDP-11 way of starting a device, and 5.5 shows what it becomes.

**Character devices and the clist.** A terminal is read and written a byte at a time, and the kernel shares the work with the **line discipline** (the kernel code that edits the input line and echoes it, so that no driver does). 2.11BSD's console driver for the KL11 serial line (`pdp/cons.c`, 196 lines) is five small routines: the receive interrupt `cnrint` reads the data buffer register and passes the byte up with `(*linesw[tp->t_line].l_rint)(c, tp)`; `cnstart` takes the next byte from the terminal's output queue with `getc(&tp->t_outq)`, writes it to the transmit buffer when the transmitter is ready (`DLXCSR_TRDY`) and marks the line busy; the transmit interrupt `cnxint` clears the busy mark and calls the line discipline's `l_start`, which calls `cnstart` again. The queues are **clists** (character lists: chains of small blocks of `CBSIZE` bytes taken from one free list; `getc` returns -1 when the list is empty). The console is at `0177560` and interrupts at vectors 060 and 064, both BR4; the line clock KW11-L is at vector 0100, BR6, and runs `hardclock` (`scb.s`).

**Being found.** In V7 nothing finds a device: `conf.c` and the vector table `l.s` are written by hand. 2.11BSD added `autoconfig(8)`, a user program that "needs the ucall() system call and special kernel to work" (`autoconfig/main.c`): it reads `/etc/dtab`, calls the driver's **probe** routine for each line (`rkprobe` writes the CSR to make the controller raise an interrupt and returns `ACP_IFINTR`, "exists if the interrupt arrives"), patches the interrupt vector, and calls the driver's **attach** routine (`rkattach(addr, unit)` stores the controller's address in `RKADDR`).

**Moving data: `physio` and map registers.** A raw read or write goes through `physio`, which builds a buffer header that points into the user's memory: it turns the user's virtual address into a physical one from the user's segment registers, locks the process in memory (`SLOCK`), calls the strategy routine and sleeps until `B_DONE` (`vm_swp.c`, read). It translates only the first address and passes the whole length, so it assumes that the buffer is one contiguous run of physical memory. The Unibus carries 18 address bits, so a device cannot name all of a larger memory; the **map registers** (table entries that translate a device's address to a memory address) at `0170200` do (`h/uba.h`), and `mapalloc(bp)` of `rkstrategy` allocates registers for a raw transfer and rewrites the buffer's address into one the device can use (`pdp/machdep.c`, read).

**The Q-bus.** The PDP-11's second bus, the Q-bus, carries the same programming model: registers in an I/O page, vectors, BR levels (that the Q-bus served the lower-cost PDP-11s such as the 11/23 is *unverified* here; no source on this computer describes it). What reaches a driver is the address width. 2.11BSD supports "22-bit q-bus systems" (`MAXCLICK_22`, "22 bit QBUS", `pdp/machdep2.c`), where memory is larger than an 18-bit controller can name. A controller built for the 18-bit Unibus, such as the RK11, then cannot reach a buffer above 256 KB, and `rkstrategy` calls `sofub_alloc(bp)`: a **soft Unibus map** that copies the data through a bounce buffer below 256 KB with `copyv`, and `sofub_relse` copies back (`pdp/machdep.c`, `rk.c`, read). `rl.c` notes that third-party 18-bit RL controllers work this way on a Q-bus and that the DEC RLV11 "does not properly monitor the I/O page signal", so it cannot (read). The drivers, the registers and the vectors were the same on both buses; the DMA address was the part that differed (5.10).

**What the PDP-11 driver did not have.** The driver is told what is there; the device is not asked. A device does one command at a time. The register set is the device's own, so a new kind of device is a new set of bits to learn. The interrupt vector and its level are set by hand. No device needed a program loaded into it before it worked (4.1). The pdp64's drivers change each of these, and 5.3 starts from this list.

## 5.2 What came between: the VAX, PCI, virtio and OpenBSD

The author's own statements about drivers name few referents. He said, of the eight-register devices, that drivers "should be trivially small" (errata 49, since withdrawn with the eight-register model by errata 95); he asked for "a standard audio/video interface so there is no bullshit with supporting a bunch of device drivers, although as a pcie bus any device MAY be attached and supported" (errata 78); and he chose virtio: "yeah, virtio is fine" (errata 79), "forget the native 8 register devices. gone. virtio across the board" (errata 95), "disk is virtio-blk" (errata 101). OpenBSD is the first operating system (errata 41). On 2026-11-09 he also wrote that "we will support all the virtio devices in silicon (the ones it makes sense to support, that is)" and asked what "syntactic sugar" (not new opcodes) could make devices easier to use "like the 12 register + dma thing" (message 592:13); which virtio devices make sense, and the sugar, are not answered in the repository (5.16). No other system is named in his messages on drivers (the decision log was searched); `docs/decisions-and-status.md`, the ledger, agrees with this list: its subjects for devices are DONE for the virtio-net, virtio-gpu and virtio-snd standard and for USB and NVMe as the modern I/O hardware, and it still shows the virtio-only chapter rewrite as TO DO, which this chapter and chapter 2 now are. The VAX, PCI and the intermediate OpenBSD interfaces below are the assistant's steps, from the sources read.

| step | what it contributed to drivers | basis |
|---|---|---|
| PDP-11, V6 to 2.11BSD | register structure, device switch, strategy/start/interrupt, `spl`, `INIT`/`READY`, probe and attach (2.11BSD), map registers | read (5.1) |
| PDP-11 on the Q-bus | the same drivers and registers; 22-bit memory, so an 18-bit controller needs a bounce buffer (the soft Unibus map) | read (5.1); which models *unverified* |
| VAX, 4.3BSD | `config(8)` turns a text file into the device tables (`ioconf.c`); a driver is one table of probe, slave, attach and start routines (`struct uba_driver`); the kernel scans the adapter and calls the probe where something answers; `uballoc` hands out map registers; `ubareset` calls every driver's reset routine | read |
| PCI | a function names itself by vendor and device number, so a driver's probe tests numbers and pokes no address; windows are placed by software | structure read in OpenBSD; history *unverified* |
| PCI Express, MSI-X | an interrupt is a memory write, so each queue can have its own vector; a bus-mastering device reads and writes memory by itself | chapter 2 (2.5, 2.6) |
| virtio | one transport and one queue structure for every class of device; a class driver is only the request format; features are agreed at start | `virtio_*.h`, QEMU, OpenBSD `vioblk.c` (read) |
| OpenBSD, the pdp64's first system | a softc and a `cfattach` of `match` and `attach`; DMA through `bus_dma` maps with explicit syncs; the interrupt priority survives as `IPL_BIO`; `bdevsw` and its strategy routine survive; a virtio disk appears as a SCSI adapter under `sd(4)` | read (5.13) |
| pdp64 | virtio across the board; found by enumeration; MSI-X; uncached buffers and no cache syncs; an IOMMU when it exists | errata 79, 85, 95, 101 |

The VAX's `config(8)` and `uba_driver` are in `etc/config/mkioconf.c` and `sys/vaxuba/ubavar.h` of the 4.3BSD tree; the kernel's scan (`unifind` in `sys/vax/autoconf.c`) calls `(*udp->ud_probe)` where `badaddr` finds a device. `ubareset` (`vaxuba/uba.c`) "generate[s] a reset on uba number uban" and then calls `(*cdp->d_reset)(uban)` for every row of the character device table, so that each driver re-issues what was pending.

## 5.3 What a driver is on the pdp64

The pdp64 changes the four parts of 5.1 in turn. The register structure is a PCI Express function whose windows hold the virtio structures instead of the device's own registers (statements 5.3.2 to 5.3.5, and 5.4). The device switch row is the OpenBSD driver's own interface (5.13). The vector and the level are a message that the device writes (5.9). The probe and attach are an identifier match and a handshake (5.5). Figure 5.1 draws the two side by side.

**5.3.1** Every standard device is a virtio device or a USB (xHCI) controller; the disk, network, graphics and audio devices are virtio-blk, virtio-net, virtio-gpu (2D) and virtio-snd, over the virtio PCI Express transport, so that one transport driver and a thin class driver per device serve the system and the same devices run in QEMU, `sim64` and the FPGA. *(D)* Any other PCI Express device, an NVMe controller for example, may be attached with its own driver; it is not a standard device. *(D)* (Neither QEMU's pdp64 machine nor `sim64` has a virtio device yet: 5.14.)

**5.3.2** A device is a PCI Express function whose windows (the regions its base-address registers describe) a driver maps with the device memory type, strongly ordered. *(D for the memory types; P for windows that start on page boundaries and are whole pages)*

**5.3.3** A driver reaches a register with an ordinary load or store; there are no input or output instructions and no port space. *(D)*

**5.3.4** Registers are naturally aligned and accessed at their own width; the machine is little-endian throughout and the virtio structures are little-endian, so a driver has no byte-order or byte-lane cases. *(D)*

**5.3.5** Accesses to a device page happen in program order; one `FENCE` separates the last write to memory the device will read from the write that notifies the device. *(D)*

![The structure of a driver: the PDP-11's beside the pdp64's](figures/drv-structures.svg)

*Commentary.* **Chain.** PDP-11: a structure laid over fixed addresses (`RKADDR` at `0177400`), so that the register is a field and the driver needs no accessor. VAX: the same structure at an address the kernel found by scanning the adapter, plus map registers and data paths to manage. PCI and PCI Express: the registers are in windows that software placed, so the address is a value the kernel hands the driver; Linux and BSD wrap every access in an accessor (`readl`, `bus_space_read_8`) to hide port-or-memory differences and byte order (*unverified* for the names; OpenBSD's `virtio_read_device_config_4` and `_8` are read in `vioblk.c`). pdp64: ordinary loads and stores through a pointer to a structure, because the machine has no port space and one byte order, so the accessor is a load or a store. The assistant's reasoning from this: the register's address is a virtual address the kernel maps, so the driver is position-independent, which `RKADDR` at `0177400` was not. **Trade-offs.** A window of whole pages wastes address space and no memory, and lets the kernel give one device to one protection domain. Taking virtio rather than a design of the pdp64's own gives up the freedom to shape the registers and gains every driver and every emulated device that already exists. **Impact.** *Kernel:* one transport driver and a thin driver per class; no accessor layer. *Compiler:* register access is a `volatile` load or store of the register's width through a pointer to a structure (5.13). *Hardware:* a device window is decoded by page address; the devices are standard PCI Express functions.

## 5.4 The interface a driver programs: structures, queues and features

Chapter 2 explains the structures (2.7.2 to 2.7.9) and gives pseudocode for the handshake (`init_device`), the queue set-up (`setup_queue`), posting and reaping (`post`, `reap`). This section keeps the decisions as the driver writer needs them.

**5.4.1** The driver finds a virtio device's structures through the capabilities in its configuration space: the common configuration, the notification area, the interrupt status and the device-specific configuration, each at an offset in one of the device's windows. *(D)* The common configuration has these fields, as the virtio specification lays them out (the offsets are those of `struct virtio_pci_common_cfg` in the Linux header `virtio_pci.h`, read; the header spells the driver's feature fields `guest_feature_select` and `guest_feature`, the interrupt-vector field of the device `msix_config`, and each queue address as a `_lo` and a `_hi` word):

| Offset | Field | Meaning |
|---|---|---|
| `0x00` | `device_feature_select` | which 32 bits of the device's features `device_feature` shows |
| `0x04` | `device_feature` | the device's feature bits (read-only) |
| `0x08` | `driver_feature_select` | which 32 bits of the driver's features `driver_feature` sets |
| `0x0C` | `driver_feature` | the features the driver accepts |
| `0x10` | `msix_config` | the interrupt vector for a change of configuration |
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

**5.4.2** A transfer is a chain of descriptors in a queue (a virtqueue) in host memory. A descriptor is 16 bytes: a 64-bit buffer address, a 32-bit length, 16 bits of flags (`NEXT`: the chain continues; `WRITE`: the device writes the buffer; `INDIRECT`: the buffer is a table of descriptors) and a 16-bit index of the next descriptor. *(D)*

**5.4.3** The driver puts the head of a chain in the available ring and advances its index, executes `FENCE`, and writes the queue's notification address; the device carries the chain out and writes the head and the byte count in the used ring, advances the used index, and may interrupt. Progress is therefore in memory, not in the device. *(D)*

**5.4.4** The driver and device agree on features before any queue runs: the driver reads the device's features, writes the subset it accepts, and the device confirms it; the version-1 feature is required. *(D)* The feature subset that the pdp64 accepts for each device, and the platform-ordering feature that the pdp64 must declare, are not specified. *(S)*

**5.4.5** A device that carries traffic in two directions (a network card) has one queue for each direction in the one device; a console-like device is the same pattern. *(D)*

*Commentary.* **Chain.** PDP-11: the command is the register values; one is in flight, and the completion is the interrupt or the RDY bit. VAX and PCI: the same, with the DEUNA Ethernet controller of 4.3BSD (four registers, `dereg.h`) as the exception, whose transmit and receive **rings** (circular arrays of entries in memory, each with an ownership bit) let the driver queue many frames; its `if_de.c` is where the ring appears in the sources read. virtio: the ring becomes the standard, with the done mark in a second ring (the used ring) and not in the descriptor, and the control registers shrink to a handshake. pdp64: the standard as it is, on a PCI Express function. **Modern comparables** (*unverified*, general knowledge): NVMe's submission and completion queues, the descriptor-done bit of Intel Ethernet controllers and the command lists of SATA controllers are all rings with a done mark, so a virtqueue is the common shape and not a novelty. **Trade-offs.** A queue per direction keeps each ring in order and simple; the used ring costs one write per chain. The pdp64 does not control the standard, and a feature or a field it dislikes stays. **Impact.** *Kernel:* one transport driver and a thin driver per class. *Compiler:* the descriptor is a 16-byte structure with natural alignment (no padding is needed: `8 + 4 + 2 + 2` bytes), and register offsets are named constants. *Hardware:* the interface is the specification's, so a standard device works.

## 5.5 The life of a driver: probe, attach, run, fail, detach

The five steps are the PDP-11's, in the order autoconfiguration calls them, with the bus doing the finding.

**5.5.1** *Probe.* The kernel enumerates the bus (section 2.4), reads each function's identifiers, and matches the virtio device type (or the USB class) against the drivers it has. *(D)*

**5.5.2** *Attach.* The driver resets the device (zero to `device_status`), sets the acknowledge and driver bits, negotiates features, sets the features-ok bit and reads it back, sets up each queue (its size and the three addresses, then `queue_enable`), and sets the driver-ok bit. *(D)*

**5.5.3** *Run.* The driver puts the queue in uncached memory, fills descriptors, publishes the chain in the available ring, executes `FENCE`, and notifies the queue; a chain is complete when it appears in the used ring, which the driver sees by polling or by the interrupt. *(D)*

**5.5.4** *Fail.* A device that sets its needs-reset bit, or that stops answering, is reset and its queues reprogrammed, and the driver resubmits the chains that are not in the used ring. *(P for the resubmission rule; D for the reset)*

**5.5.5** *Detach.* A departure event, or a bus fault from an absent device, tells the driver to stop; it reads, saves, resends or fails the chains still queued. *(P)*

**`INIT` and `READY`, and the status handshake.** The PDP-11's start of a device (5.1) is one command and one wait: write `INIT` (or `RESET|GO`), spin until `READY`. Statement 4.8.1 *(P)* says the same for the pdp64 in the words of that time, "written when devices were eight registers". The virtio `device_status` byte is that idea spread over steps: writing zero resets the device (the `INIT`), and the driver then sets `ACKNOWLEDGE`, `DRIVER`, `FEATURES_OK` and `DRIVER_OK`, each meaning "I have got this far", reading `FEATURES_OK` back to learn whether the device accepts the features chosen (the `READY` answer, now with a refusal possible; 2.7.3). The assistant's reasoning: the step that is new is the negotiation, which the one-bit form could not carry because the PDP-11 device had nothing to negotiate. The ledger lists the device-initialisation protocol as IN THE AIR (no standing decision; PCI Express supplies its own reset and init, errata 80); the handshake follows from "virtio across the board" (errata 95) and is the form this chapter and 4.8 use.

Probe and attach for a virtio-blk driver, written over the helpers of chapter 2 (`find_virtio_structures`, `init_device`, `setup_queue`); the names are the assistant's, an illustration:

```
# 5.5.1: called for every function the bus walk found
vioblk_match(fn):
    # 0x1040 + device type 2 (2.7.2)
    return fn.vendor == 0x1AF4 and fn.device == 0x1042

vioblk_attach(fn):                             # 5.5.2
    # 2.7.2: where the common configuration, notify, status, device config are
    find_virtio_structures(fn)
    # 2.7.3: reset, ACKNOWLEDGE, DRIVER, features, FEATURES_OK, queue 0, DRIVER_OK
    init_device(fn)
    # virtio_blk_config.capacity, in 512-byte sectors (virtio_blk.h)
    capacity = mmio_read64(device_config + 0)
    # the block driver's row of bdevsw, 5.13
    register_disk(fn, capacity, vioblk_strategy)
```

OpenBSD's `vioblk_match` is the same test, on the device number alone (`va->va_devid == PCI_PRODUCT_VIRTIO_BLOCK`, with the vendor tested one level down in `virtio_pci_match`), and its `vioblk_attach` asks for the features `RO`, `NOTIFY_ON_EMPTY`, `SIZE_MAX`, `SEG_MAX` and `FLUSH`, reads the capacity, allocates the queue with `virtio_alloc_vq` and registers its completion routine in `vq_done` (read, `vioblk.c`). What differs from the PDP-11's `rkattach`: the driver is not told an address, there is a negotiation, and every step can fail with a defined status.

*Commentary.* **Chain.** PDP-11: V7 has no probe; 2.11BSD's `rkprobe` pokes an address and `rkattach` stores it. VAX: `ud_probe` and `ud_attach` in a table, called by the kernel's scan. PCI: the identifier match replaces the poke, and BSD's autoconfiguration calls `match` then `attach`; OpenBSD's `cfattach` for `vioblk` is `{ sizeof(softc), vioblk_match, vioblk_attach, NULL }`, so it has **no detach routine** (read). Linux's driver model has `probe` and `remove` (*unverified*). PCI returns all ones for a read of a removed device (*unverified*), which, as the assistant reasons, is why a pdp64 driver that finds all ones cannot tell a departed device from a register that holds them, and why the pdp64 faults instead (2.4.5). pdp64: probe by identifier, attach by the status handshake, and a defined detach path because the bus reports departures (2.4.4 to 2.4.6). The probe reads the bus and not a configuration file, so a new device needs no line in `dtab` or `ioconf.c`. **Trade-offs.** The five steps are the same for every device, so the work that differs is the personality: what the requests mean. A detach path that no BSD virtio driver has is new work. **Impact.** *Kernel:* the steps are the same for every driver, so only the requests differ. *Compiler:* none. *Hardware:* none beyond the device's own.

## 5.6 The block path: virtio-blk

**5.6.1** Storage is virtio-blk: a virtqueue of requests, each a header (read, write or flush, and the sector), the data buffers and a status byte, the device marking the request done in the used ring. *(D)* An NVMe controller, which keeps a submission queue and a completion queue in host memory with a doorbell register for each (the shape of the virtqueue with a different command encoding), may be attached as any PCI Express device may; it is not the standard disk. *(D)*

**5.6.2** The **disk** is virtio-blk (the author's decision of 2026-11-10, errata 101) with read, write and flush at 512-byte sectors. *(D)* The boot ROM reads block 0 with one read request on the device's queue (4.4). *(P)*

The request is the three-descriptor chain of chapter 2 (2.7.5, with its figure): a header the device reads (type 0 read, 1 write, 4 flush, the priority and the sector), the data buffer (device-writable for a read) and one status byte the device writes (0 OK, 1 I/O error, 2 unsupported; `virtio_blk.h`, read). Figure 5.2 follows one request through the driver, the rings and the device.

![The life of one block request](figures/drv-block-request.svg)

The strategy, start and interrupt routines of 5.1 become the following, a block driver written as an illustration over the `post` and `reap` of chapter 2 (2.7.7). The queue of waiting requests is still the kernel's, but the hardware now takes up to `queue_size` chains at once, so `start` fills the ring until it is full, not until the controller is busy:

```
# called one buf at a time, as rkstrategy is
vioblk_strategy(bp):
    s = splbio()                               # IPL_BIO in OpenBSD (5.9)
    append bp to queue
    vioblk_start()
    splx(s)

vioblk_start():
    while queue not empty and free_descriptors() >= 3:
        bp = take head of queue
        h = alloc_hdr();  h.type = (bp.flags & B_READ) ? 0 : 1
        h.ioprio = 0;  h.sector = bp.blkno
        s = alloc_status_byte()
        d0 = get_free(); d1 = get_free(); d2 = get_free()
        desc[d0] = { addr: h,         len: 16,         flags: NEXT,         next: d1 }
        wr = (bp.flags & B_READ) ? WRITE : 0       # the device writes the buffer on a read
        desc[d1] = { addr: bp.addr, len: bp.bcount, flags: NEXT | wr, next: d2 }
        desc[d2] = { addr: s,         len: 1,          flags: WRITE,        next: 0 }
        inflight[d0] = bp
        post(q, d0)                            # FENCE, then the doorbell (5.3.5)

vioblk_intr():                                 # the queue's vector, at IPL_BIO
    # reap(q), with the buf completed as rkintr completes it
    while last_used != used.idx:
        e = used.ring[last_used mod n];  bp = inflight[e.id]
        if status_byte(e.id) != 0: bp.flags |= B_ERROR
        free_chain(e.id);  last_used += 1
        iodone(bp)                             # wake the sleeper, as in 5.1
    vioblk_start()                             # slots are free again: send more
```

The routine that polls, which the boot ROM and a crash dump use because they run with no interrupt set up, differs only in who waits (chapter 2, 2.7.8, gives the polled loops side by side):

| | RK11, interrupt style (5.1) | virtio-blk, interrupt style (above) | virtio-blk, polled (the boot ROM) |
|---|---|---|---|
| strategy | queue the buf; start if idle | queue the buf; fill the ring | `blk_read` (2.7.7): set `NO_INTERRUPT` in `avail.flags` |
| start | four register writes, GO | `post(q, d0)`: one doorbell write | `post(q, d0)` |
| completion | `rkintr`: ERR? retry up to 10 times; `iodone`; start the next | `vioblk_intr`: status byte, `B_ERROR`, `iodone`, start more | spin while `last_used == used.idx`; read the status byte of `d2` |
| in flight | one transfer | up to `queue_size` transfers | up to `queue_size` transfers |

The raw interface changes with paging. `physio` of 5.1 translated one address and passed the whole length, because a PDP-11 process's memory was contiguous; with a page-table memory (chapter 6) a user's buffer is a list of pages scattered in physical memory, so the driver describes it with one descriptor per page (statement 5.10.3) and the pages must stay in place until the status byte is written. Figure 5.3 draws the layers a request crosses on the two machines.

![The layers from a system call to the device](figures/drv-layers.svg)

*Commentary.* **Chain.** PDP-11: one command at a time, a software queue per drive, one interrupt per transfer. VAX: the Unibus RK611 driver of 4.3BSD (`vaxuba/rk.c`) is a `uba_driver` whose start routine `rkdgo` loads the registers after `uballoc` has found map registers. PCI: the same registers, now with a controller that queues commands itself (SCSI, ATA, NVMe: the shape of the virtqueue, errata 61 and 75). virtio-blk: three descriptors and a status byte. OpenBSD: `vioblk.c` (747 lines, counted) is not a block driver with a strategy routine of its own but a SCSI adapter (`vioblk_scsi_cmd`) under the `sd(4)` disk driver, whose `sdstrategy` (`scsi/sd.c`) keeps the `bdevsw` row (read). pdp64: the same driver, with `bus_dmamap_sync` calls that do nothing (5.10). **Trade-offs.** A request with many commands outstanding replaces the one-at-a-time loop and its retry-ten-times error handling by a status byte and a reset (5.11). The cost is memory for the queue and the ordering rule between data and the used index (5.10.4). **Impact.** *Kernel:* a disk driver is a skeleton shared by all devices; OpenBSD's `vioblk.c` is the model. *Compiler:* none. *Hardware:* the device writes the data before the used entry before the used index.

## 5.7 The console, the timer and the entropy source

**5.7.1** The form of the console, the timer and the entropy source under this interface is not specified: the candidates are a UART-style console, a small fixed timer and interrupt controller that need no enumeration, and virtio's console and entropy devices; the entropy pool is one device shared by all cores. *(S)*

This section is **open**: it states what the repository says and what the briefing offers, and decides nothing. The author's statements bear on it in two places only. Errata 85 (the ledger marks the entropy subject IN THE AIR, because its chain shows only potentials and errata 85 records them as decisions; the author's rationale there is "guys suffered from bad rng in the past", and optimising their algorithms "is ok", message 1882:69): the random-number pool "is one device shared by all cores; no per-process pool; no version register and no updatable firmware", "an assistant to the operating system's own generator, which absorbs into it and squeezes from it". Errata 86: the secure core takes no periodic timer tick. No console, timer or entropy referent from another system is recorded in his messages.

**What exists in the repository** (read). `spec/pdp64-system.hbnf` defines, for the QEMU machine and `sim64`, a **timer**: a 64-bit free-running counter at 10,000,000 ticks a second of QEMU's virtual clock, a 64-bit compare register and a control register (enable, pending), interrupting at level 6 on vector 32 while the counter is at or above compare; and a **console** in the spirit of the KL11: four 64-bit registers (`RXCS`, `RXDB`, `TXCS`, `TXDB`), READY in bit 7 and interrupt-enable in bit 6, level 4, vectors 33 (receive) and 34 (transmit). They sit at fixed addresses (`0x8000000000`, `0x8000001000`) behind physical-address bit 39 of errata 60, which errata 97 withdrew; the specification and the QEMU machine have not been changed (5.14). Neither is virtio nor PCI Express. `decisions-pending.md` F11 leans to a 16550-style UART in place of the KL11-style console, and F12 to "a small device tree for these (timer, interrupt controller, UART), PCI Express enumeration for the rest". A **device tree** is a data structure, written by hand or by the boot loader, that lists each device the bus cannot enumerate with its type, address and interrupt, so that the kernel reads it instead of probing; no device tree exists in the repository yet.

**What virtio has** (read in `/usr/include/linux`, QEMU and OpenBSD). *Console:* device type 3. Port 0 has one receive queue and one transmit queue (queues 0 and 1 in QEMU's `virtio-serial-bus.c`; further control queues exist when `MULTIPORT` is negotiated); the configuration holds `cols`, `rows`, `max_nr_ports` and `emerg_wr`, and the feature `EMERG_WRITE` (bit 2) lets a driver print one character by writing it to `emerg_wr` (offset 8 of the configuration) with no queue and no buffer in memory; QEMU passes the low byte to the port. OpenBSD's `viocon.c` (617 lines) drives the queues through the tty layer and asks only for `SIZE`; it does not use `EMERG_WRITE`. *Entropy:* device type 4, one queue; the driver posts a device-writable buffer and the device fills it with random bytes (QEMU `virtio-rng.c`, queue of 8 entries). OpenBSD's `viornd.c` (201 lines) asks for 16 bytes at boot and again at an interval, and passes each word to `enqueue_randomness`, so the device is an input to the kernel's own generator, the shape of errata 85. *Timer:* no standard tick device. The ID list has `VIRTIO_ID_CLOCK` (17, "virtio clock/timer"), and `virtio_rtc.h` defines a clock-reading request, a cross-timestamp request and an alarm (`VIRTIO_RTC_F_ALARM`, `SET_ALARM`, a notification `VIRTIO_RTC_NOTIF_ALARM`); QEMU has a `vhost-user-rtc` device. A real-time clock with an alarm is a wall clock with one request and one notification through a queue; whether a periodic tick or a one-shot compare could be served so is not stated by any file read.

**What the briefing offers** (`docs/decision-log/data/shared/oq/B.md`, item Q6; open material, the assistant's proposals and not decisions). Five options for the three devices: (1) the fixed console and timer of the implementation and virtio-rng for entropy; (2) the timer inside the core (a shared counter and a one-shot compare register per core, read and written by system registers) with a minimal fixed UART for boot and panic and virtio-rng; (3) everything enumerated, virtio-console and virtio-rng and the timer in the core; (4) the author's absorb-and-squeeze pool of errata 85 as a fixed device; (5) no entropy hardware, only software gathering and a boot seed. The same document lists the costs the options carry: a fixed device is a second device model beside virtio; a virtio console cannot print before the bus works. `smp-decisions.md` section 4 leans to a global counter and a per-core one-shot compare. **The emergency write above bears on the second cost** and the briefing does not mention it: it needs the bus (the device's window mapped, its configuration structure found) but no queue, no descriptor, no DMA and no IOMMU entry, so a panic path through it is a store, though not a store at a fixed address. Whether the boot ROM may find the console by enumeration is part of what is open.

![The console and the timer as the options stand](figures/drv-console-timer.svg)

A complete tiny console driver, for the fixed console of the QEMU machine (the first and last lines of `tests/qemu/con-tx.S` and `con-rx.S` do in assembly what `con_putc_polled` and `con_rxint` do here); a virtio-console version would replace the three register writes with a transmit-queue post and keep the shape. An illustration:

```
# fixed address in the present machine (0x8000001000)
CON = MAP_CONSOLE
RXCS = 0;  RXDB = 8;  TXCS = 16;  TXDB = 24  # four 64-bit registers
READY = 1 << 7;  IE = 1 << 6                 # as the KL11's bits
ring txq, rxq                                # circular byte buffers: the clist's job

# vectors 33, 34: con_rxint, con_txint (6.3.3)
con_attach():
    # receive interrupts on; transmit off for now
    mmio_write64(CON + RXCS, IE)

# the boot code and a panic: no queue, no interrupt
con_putc_polled(c):
    while (mmio_read64(CON + TXCS) & READY) == 0: spin
    mmio_write64(CON + TXDB, c)

con_write(buf, n):                           # from the tty layer, as cnstart's caller
    s = spl4()                               # keep con_txint out while txq changes
    for c in buf[0..n): put(txq, c)
    # interrupts while IE is set: starts output
    mmio_write64(CON + TXCS, IE)
    splx(s)

con_txint():                                 # vector 34, level 4
    if empty(txq): mmio_write64(CON + TXCS, 0)       # nothing left: interrupt off
    else:          mmio_write64(CON + TXDB, get(txq))

con_rxint():                                 # vector 33, level 4
    tty_input(mmio_read64(CON + RXDB))       # reading RXDB clears READY
```

A timer tick handler, for the fixed timer: the interrupt stays asserted while the counter is at or above the compare register, so the handler moves the compare register forward by one period (`tests/qemu/mini-kernel.S` does this with `PERIOD` 200000, 20 ms at 10 MHz). An illustration:

```
timer_attach():
    mmio_write64(TIMER + COMPARE, mmio_read64(TIMER + COUNTER) + PERIOD)
    mmio_write64(TIMER + CONTROL, ENABLE)    # bit 0

timer_intr():                                # vector 32, level 6
    # drops the request
    mmio_write64(TIMER + COMPARE, mmio_read64(TIMER + COMPARE) + PERIOD)
    hardclock()                              # ticks++, due callouts, accounting
```

*Commentary.* **Chain.** PDP-11: the KL11 console has a receive and a transmit CSR with READY and IE bits and interrupts at BR4 on vectors 060 and 064; the KW11-L line clock interrupts at line frequency at BR6 on vector 0100 and `hardclock` runs on each tick; both are at fixed addresses and need no probe (`cons.c`, `scb.s`, read). VAX: an interval timer in processor registers and a console processor (`boot.md`, from memory in the repository, *unverified* here). The PC: a UART at a legacy port and a programmable timer, then per-core timers; the ARM and RISC-V systems of today describe their UART and timer to the kernel in a device tree (*unverified*; OpenBSD has the `sys/dev/fdt` bus, read, and a virtio-over-memory-mapped-registers transport `virtio_mmio.c` for machines that have a device tree and no PCI). pdp64: the console and timer exist today as the KL11 shape (5.7, read) and the form that will stay is open. **Trade-offs.** A fixed console works before the bus does and costs a second device model; a virtio console is one model and cannot print before the queue is set up, unless the emergency write serves; a timer in the core removes a device and a lock and adds system registers, a counter distribution and an architectural definition (`smp-decisions.md`, read). **Impact.** *Kernel:* the console must work before enumeration for the boot ROM and the panic path; the timer must work before any driver. *Compiler:* none for the console and entropy; a timer in system registers adds `MTSR` and `MFSR` numbers. *Hardware:* a fixed UART or timer is a few registers; a virtio console is a queue engine; an entropy source is a physical circuit whose quality the standard would promise.

## 5.8 The network, graphics, sound and USB drivers

Each class driver is a few request formats over the transport of 5.4. What the driver does is the part that differs.

**5.8.1** The **network card** is virtio-net: a receive queue the host fills with buffers for the device and a transmit queue of frames to send; the device completes each receive buffer with the frame length. *(D)*

**5.8.2** The **graphics device** is virtio-gpu in its 2D mode (create a surface, point it at memory, flush a rectangle) and the **audio device** is virtio-snd (streams in queues in shared memory). *(D)*

**5.8.3** **USB** is an xHCI host controller, a PCI Express function, driven by the operating system's USB stack, which enumerates the attached devices. *(P)*

**virtio-net** (device type 1). The driver keeps the receive queue full: it posts empty buffers with `WRITE`, and the device fills one with a frame and reports its length in the used ring; to send, the driver posts the frame and the device reads it. Each frame starts with a 10-byte `struct virtio_net_hdr` (flags, GSO type, header length, GSO size, checksum start and offset; `virtio_net.h`, read), which tells the device which checksum to fill in and where. Queue 0 receives, queue 1 transmits, and a control queue exists with the feature `CTRL_VQ`; the MAC address is in the device configuration with the feature `MAC` (`virtio_net.h`, QEMU `virtio-net.c`, read). OpenBSD's `if_vio.c` is 2,184 lines (counted), the largest virtio driver of the tree. The PDP-11's counterpart is the DEUNA of 4.3BSD or the network driver of a Unix with a network (V7 has none).

**virtio-gpu** (type 16). Two queues: the control queue, 256 entries in QEMU, carries the commands of chapter 3 (3.14: create a resource, attach its backing memory, set the scanout, transfer a rectangle, flush it), and the cursor queue, 16 entries, carries cursor updates. The driver sends a command and waits for the response in the same chain. OpenBSD's `viogpu.c` (727 lines, read) has the functions `viogpu_create_2d`, `viogpu_attach_backing`, `viogpu_set_scanout`, `viogpu_transfer_to_host_2d` and `viogpu_flush_resource`, the five commands of the figure of 3.14. The PDP-11 had no counterpart; the nearest is the display register pair of a VT11 or the bitmap of a Blit, which chapter 3 tells.

**virtio-snd** (type 25). Four queues in the order control, event, transmit, receive (`virtio_snd.h`, read; QEMU adds them in that order); the control queue sets up the streams, and the transmit and receive queues carry the samples of an output or an input stream. Chapter 3 (3.19) says what a stream is and what a mixer does with it. **OpenBSD's tree on this computer has no virtio-snd driver:** `sys/dev/pv` holds `if_vio.c`, `vioblk.c`, `viocon.c`, `viogpu.c`, `viomb.c`, `viornd.c`, `vioscsi.c` and `virtio.c`, and no sound file, so the question of errata 79 ("whether OpenBSD has a virtio-snd driver (if not, one is written)") is answered for that tree: one is written. The PDP-11 had no audio device.

**USB** (an xHCI controller, a PCI Express function). The controller runs the protocol in hardware; the driver gives it lists of transfer descriptors in memory and reads an event ring, the same pattern as a virtqueue with its own formats. The operating system's USB stack enumerates the devices behind the controller (2.4.3). The author's uses of USB are the keyboard, the mouse and a hard drive ("modern usb keyboard, mouse, and nvme hard drive", message 531:0; the ledger's modern I/O hardware subject, DONE); the class drivers that those need (human interface device, mass storage) are not described in the repository. That a USB-to-Ethernet adapter appears to the host as a network class device is *unverified*.

*Commentary.* **Chain.** PDP-11: one driver per controller, each with its own registers (`rk.c`, `cons.c`, `dz.c`, 579 lines for the multiplexer). VAX: the same, with the adapter handling the memory mapping. PCI: one driver per chip family, with firmware and quirk tables (`kernel-pain-points.md`, repo). virtio: one transport and a thin driver per class, so that a card of any vendor that speaks the standard works with the drivers already written. pdp64: that, for network, graphics and audio; xHCI for USB. **Trade-offs.** One transport means one driver to write, at the cost of feature negotiation and a queue format that the pdp64 does not control; an existing USB stack comes with xHCI at the price of that large stack. **Impact.** *Kernel:* one transport driver and a thin driver per class; a virtio-snd driver to write. *Compiler:* none. *Hardware:* standard PCI Express functions; the same virtio devices are the aim in QEMU, `sim64` and the FPGA.

## 5.9 Interrupts as a driver sees them

**5.9.1** A device interrupts by a message-signalled write (MSI-X): the configuration change and each queue have a vector that the driver sets in the common configuration, and the interrupt status structure says why. *(P)*

**5.9.2** A driver may mask a device's interrupts and poll the used ring instead. *(D)*

**5.9.3** A changeable interrupt target is changed with its vector masked and then read back, or is a single atomic register write. *(D)*

**5.9.4** The write that raises an interrupt cannot overtake the data writes that precede it (section 2.5.4). *(D)*

What changes for the driver is where the vector number and the level come from. On the PDP-11 the programmer chose them by switches and by the vector table: the RK11's pair at 0220, level 5. On the pdp64 the driver asks the interrupt controller for an address and a data word (`interrupt_controller_allocate` in 2.6), writes them into the device's MSI-X entry for the queue, tells the queue its entry (`queue_msix_vector`), and installs its handler in the vector table at `VBR + 8 × vector` (6.3.3). One queue, one vector, one core: the handler of `vioblk_intr` runs when the queue's vector arrives, and reads the used ring to learn what finished, where `rkintr` read the CSR. Figure 5.4 draws the two paths.

![The interrupt path from the device to the handler](figures/drv-interrupt-path.svg)

An entry puts the processor at priority 7 with the interrupted program counter and status word in registers (6.3.1 and 6.3.2); the handler saves them with `PUSHX`, lowers the priority with `SPL` to its own level, does its work, restores the pair with `POPX` and returns with `RTI` (6.3.4). The level of a device is the level the interrupt controller gives its vector; the kernel's `splbio` is the status-word priority at which the block code runs. OpenBSD keeps the idea: `vioblk_attach` sets `vsc->sc_ipl = IPL_BIO` (read), and `virtio_pci.c` can give a device one MSI-X vector for configuration changes and one for each queue (`IRQ_MSIX_PER_VQ`), or one shared by all queues (`IRQ_MSIX_SHARED`), up to `MAX_MSIX_VECS`, 16 (read).

**Not specified.** The unit that receives the write, how a core is chosen, how the vector number is made and the level assigned are the interrupt-controller decision **R1** of appendix B and statement 2.6.3, which are **open**. The briefing (`B.md`, item Q7) lays out six options, none decided: a per-core interrupt file that messages write; that file plus a remapping table in the IOMMU (`smp-decisions.md` leans to this as the end state); an ARM-GIC-style distributor; wired lines to core 0 for the fixed devices; per-core event rings in memory; and polled devices on dedicated cores with interrupts only for the timer, inter-processor interrupts and errors. It also records that 256 vectors per core do not fit the 224 free entries (32 to 255) of the 512-entry vector table of 6.3.6; the numbering is part of what is open. The vectors of the QEMU machine (32 timer, 33 and 34 console) are fixed wires (5.7), and the `-i N:LEVEL:VECTOR` option of `sim64` injects an interrupt by instruction count (5.14).

*Commentary.* **Chain.** PDP-11: four bus-request lines and switch-set vectors; a level shared by several devices, so a handler may have to ask which spoke; `spl` raises the priority to keep a handler out (5.1). VAX: 31 priority levels and a **system control block**, a table of vectors in memory (the repository's `decisions-pending.md`, checked there against a VAX architecture manual; not on this computer); `spl` becomes `splbio`, `spltty`, `splclock`. PCI: four shared pins per slot, and a handler that asks each device whether it was the one. PCI Express: MSI-X, an interrupt as a write (2.6). virtio: a vector per queue. pdp64: MSI-X for the standard devices, vectors in the same table as exceptions, priority 7 on entry (errata 40, "a throwback to pdp-11 design"), and the controller open. **Trade-offs.** A message carries its own vector, so no switch and no assignment table are needed and there can be thousands; the controller is an address that many devices write, and a confused device that writes the wrong address causes an interrupt, which the IOMMU can refuse (2.11). **Impact.** *Kernel:* an interrupt routine reads the used ring and the status structure; a controller driver. *Compiler:* none. *Hardware:* an MSI-X target in the interrupt controller, and the eight-level priority encoder.

## 5.10 DMA and the buffer's memory

**5.10.1** Buffers and queues are in memory mapped uncached, and the driver does no cache clean or invalidate. *(D)*

**5.10.2** A device addresses physical memory directly and the driver gives it physical addresses; until an address-translation unit for devices exists, every device must be able to address all of memory. *(P)*

**5.10.3** A buffer that crosses a page is described by several descriptors chained with the `NEXT` flag; the driver does not make buffers contiguous. *(D)*

**5.10.4** The device writes the data, then the used-ring entry, then advances the used index; the driver reads the used index and then the data. *(D)*

Three questions arise for a driver: which addresses the device sees, whether the processor's cache agrees with memory, and in what order the writes land. The PDP-11 answered the first with map registers, which the driver loaded (`mapalloc`, 5.1), and on a Q-bus machine with a bounce buffer for controllers that could not reach all of memory (`sofub_alloc`, 5.1); the second hardly arose (that the 11/70's cache watched Unibus writes, so that DMA data appeared coherent, is *unverified*, as in 2.5); and the third by one bus that delivered writes in order. The pdp64 answers them in this way:

* **Addresses.** Today the descriptor holds a physical address and the device may use any (5.10.2, P). When the IOMMU of chapter 2 (2.11) exists, the descriptor holds a **device address** (an address in the device's own mapped space, which the IOMMU turns into a physical address or refuses); the driver asks the kernel to map a buffer for the device and puts the returned address in the descriptor, and `VIRTIO_F_ACCESS_PLATFORM` (feature 33) says so to the device. The five recommendations of errata 85 (translation on by default, a domain per device, no kernel pointers in descriptors, permanent ring mappings, small buffers bounced) shape what that mapping call does. Which feature bits the pdp64 declares is not specified (5.4.4).
* **Coherence.** Buffers and rings are mapped uncached (memory type 6.7.4), so that the processor's cache never holds a stale copy of what a device wrote and the driver never cleans a line. OpenBSD's `vioblk.c` calls `bus_dmamap_sync` with `PREWRITE`, `PREREAD`, `POSTREAD` and `POSTWRITE` around each request (read); on the pdp64 those calls have nothing to do (5.13.3). The cost is that the processor reads received data from uncached memory, which is slow.
* **Order.** The processor's `FENCE` before the doorbell, the device's data-before-used-entry-before-used-index, and the interrupt that cannot pass the data (5.9.4) are the whole contract; chapter 2 (2.5, 2.8) states them.

*Commentary.* **Chain.** PDP-11: 18 address bits, so map registers (`UBMAP` at `0170200`) translate; `physio` assumed a contiguous buffer. VAX: `uballoc` for map registers and **buffered data paths** that a driver purged before reading what a device had written (`UBA_PURGE780`, `ubareg.h`, read). PCI and PCI Express: a bus master uses physical addresses, and Linux and BSD wrap the work in a DMA-mapping layer (`bus_dma` in OpenBSD, read) that places cache maintenance on machines that need it and copies into a **bounce buffer** (a buffer in memory the device can reach; 2.11BSD's soft Unibus map is the same idea on the PDP-11) when a device cannot reach the data (`swiotlb` in Linux, *unverified*). That x86 DMA is coherent while ARM and MIPS DMA often is not is *unverified*. pdp64: uncached memory for coherence, descriptors per page for scattered buffers, an IOMMU for the addresses. **Trade-offs.** Uncached buffers make the processor's reads slow and make the driver unable to forget a cache operation; a device that is not coherent would call for cache-maintenance instructions. With no IOMMU there is no protection from a faulty or malicious device. **Impact.** *Kernel:* no cache clean or invalidate in any driver; a mapping call that reduces to the identity until the IOMMU exists. *Compiler:* none. *Hardware:* DMA goes around the processor's data cache, so the cache needs no snoop port for devices.

## 5.11 Errors, departure and recovery

**5.11.1** A request that fails completes with the status of its device class (for a virtio-blk request, a status byte in the last descriptor of its chain); a device that is broken sets its needs-reset bit in `device_status`. *(D)*

**5.11.2** A device that is reset leaves its queues in memory untouched; the driver reprograms the queue registers and resubmits the chains that are not in the used ring. *(P)*

**5.11.3** A device that leaves the bus leaves its queued work in memory; the driver finds it by comparing the available ring with the used ring. *(P)*

**5.11.4** Requests are repeatable where possible (reads, writes of the same data, sends, buffer posts), so that resending an unfinished chain is safe; a request that must not run twice is tracked by its class driver, which can tell "never started" from "started, outcome unknown" only by the request's own status. *(P)*

On the PDP-11 an error was the ERR bit of the CSR, the error word `RKER`, and the driver's choice: `rkintr` reset the controller and retried up to ten times before it set `B_ERROR`. A virtio-blk request reports a status of 0, 1 (I/O error) or 2 (unsupported) in its last byte, and no retry happens in the device. A driver that finds the device stuck resets it. OpenBSD's `vioblk_reset` (read) stops the device with `virtio_reset`, runs `virtio_check_vq` to complete what finished, and **fails every other request** with a driver error; its `virtio_reinit_start` then repeats the handshake and `virtio_init_vq` **zeroes the ring memory and restarts both indices at 0**. Two things follow for statements 5.11.2 and 5.5.4: the queue memory is not left untouched by that driver, so the chains to resend must be copied out before the ring is rebuilt; and resending is the pdp64's proposal, not what the OpenBSD driver does. Whether the specification requires the indices to restart after a reset is *unverified* (the specification is not on this computer).

*Commentary.* **Chain.** PDP-11: errors in device registers, a retry loop in the driver, no device that can leave. VAX: `ubareset` resets the adapter and calls every driver's reset routine so that each re-issues its own pending work (read): resending as a design, driver by driver. PCI Express: an error completion and a link-down; hot-plug exists (2.4). The author's reason for leaving a departed device's work in memory is "so it can be read, saved, resent" (message 1889:2641; ledger, bus hotplug, DONE with the resend rule still *(P)*). NVMe and virtio drivers requeue outstanding requests after a reset (*unverified*; OpenBSD's `vioblk` fails them instead, as above). virtio: a status byte per request and a needs-reset bit. pdp64: one recovery routine for a failed, reset, replaced or departed device and a hand-over between cores, with the precise bus fault for a departed device (2.4.5, 2.9.1) and not all ones (an empty configuration position is the one read that returns all ones, 2.4.9). **Trade-offs.** The cost is a write to the used ring per chain and the ordering rule between data and the used index. **Impact.** *Kernel:* one recovery routine handles a failed, reset, replaced or departed device. *Compiler:* none. *Hardware:* the device writes data before the used entry before the used index.

## 5.12 Firmware for a device

A device that contains a small processor may need a program, **firmware**, loaded into it before it works. A PDP-11 peripheral needed none (4.1). On a PC the driver reads the blob from a file at attach time: OpenBSD's `loadfirmware(name, &buf, &len)` reads `/etc/firmware/<name>` (`dev/firmload.c`, read), and 19 files under `sys/dev/pci` call it (counted); Linux's `request_firmware` is *unverified*. The pdp64 has one statement on the subject, 4.8.1 *(P)*: that a device that wants firmware is given it "through a descriptor operation once the root file system is available", and that a device the boot depends on needs none. That statement was written for devices of eight registers with an `INIT` bit and a `READY` bit; under virtio the idea of `INIT` and `READY` stays and takes the form of the `device_status` handshake (5.5), and the register words themselves are withdrawn. The other half has no virtio counterpart: **no virtio header on this computer mentions firmware** (a search of all 29 `virtio_*.h` files and of QEMU's `hw/virtio`), and each device class defines its own request set, so a firmware download would be a request of a class that none defines.

**5.12.1** How a virtio device is handed firmware is not specified: virtio has no firmware operation, so a request type or a separate device would have to be defined, and a device the boot depends on (the disk, and the console if it is a device) needs none. *(S)*

*Commentary.* **Chain.** PDP-11: none. PC: a file per device, a loader in the kernel (`loadfirmware(9)` in OpenBSD, `firmload(9)` in NetBSD) and a separate package of files. pdp64: errata 85 already sets one precedent, an entropy pool with "no updatable firmware", and 4.8.1 sets the other, a descriptor operation; neither settles how a network card or a GPU gets its program. **Trade-offs.** A firmware window lets a device be cheap (no flash) and makes an update a file replacement, at the cost of a header format and a device that rejects a wrong image safely. **Impact.** *Kernel:* a loader that runs after the root file system is up, and a rule that no boot device needs it. *Compiler:* none. *Hardware:* a device-side image check.

## 5.13 Where drivers run, and how they are written

**5.13.1** Because a device's windows are whole pages, a driver can run in user space with only those pages and its buffers mapped. *(P)*

**5.13.2** Until devices have an address-translation unit, a user-space driver can instruct its device to write anywhere in memory, so it is as trusted as the device. *(P)*

**5.13.3** In OpenBSD the register accessors become loads and stores, the DMA mapping interface returns physical addresses with no cache-synchronisation work to do, and the autoconfiguration framework attaches a driver to each function the bus reports. *(P)*

**In OpenBSD** (read in the source tree at `/home/david/claude/facetlang/pdp11/openbsd-src`, version 8.0). A driver is a `struct cfattach` (the size of its per-device structure, the **softc**, a `match` and an `attach` function, and an optional detach) and a `struct cfdriver`. The virtio drivers attach below the transport `virtio.c` (1,075 lines) and `virtio_pci.c` (1,246 lines), which do the handshake of 5.5, the queues, and the MSI-X set-up; a class driver calls `virtio_negotiate_features`, `virtio_alloc_vq` and `virtio_enqueue` and sets `vq_done`. The device switch of 5.1 is still there, in the machine's `conf.c`: `bdevsw[]` rows are built by `bdev_disk_init` from open, close, strategy, ioctl, dump, size and flags. A virtio-over-memory-mapped-registers transport, `virtio_mmio.c`, exists for machines with a device tree; the pdp64's transport is the PCI Express one.

**In user space.** Microkernels and exokernels run drivers as ordinary programs where the hardware lets one device be mapped to one process (*unverified*); the PDP-11's Unibus gave every device a fixed address and no protection. Windows of whole pages make that possible here (5.13.1), and the IOMMU is what would make it safe: until it exists, a user-space driver is as trusted as its device (5.13.2). Linux `VFIO` and `UIO` and the DPDK libraries are the same idea and rely on an I/O translation unit (*unverified*). **Trade-offs.** A driver in user space can be tested, restarted and replaced without taking the kernel with it; its cost is a crossing for each request and the trust above.

**In C, and the tool chain.** A V7 driver is written in the PDP-11's C, where `int` is 16 bits and the register structure's fields are `int` and `short`. On the pdp64 `int` is 32 bits and `long` and pointers 64 (LP64, appendix D, D.1), so a register or a descriptor field is declared by its width (`uint16_t`, `uint32_t`, `uint64_t`); natural alignment gives the 16-byte descriptor, the 10-byte `virtio_net_hdr` and the offsets of the virtio structures with no `packed` attribute. The headers that define those structures are the Linux `virtio_*.h` files, each of which says that it "is BSD licensed so anyone can use the definitions to implement compatible drivers" (read in `virtio_rng.h`; the same line is in all 29), which fits the project's BSD 2-clause licence (errata 48); for the repository's own fixed devices the offsets are generated constants, `pdp64-consts.h`, made from `spec/pdp64-system.hbnf`, so that the device model, the test and a driver read one definition. A register is read and written through a `volatile` pointer: the compiler's value reuse is tested not to merge two reads of a volatile (`tests/c-new/avail_volatile.c`, function `vtwice`, read). The `FENCE` of 5.3.5 has no C intrinsic: the compiler's name table knows the mnemonic (`arch/pdp64/pdp64-names.h` in the pcc tree) and nothing else (read), so a driver today would call a function written in assembly. The two compilers are the C compiler `pcc` (working for pdp64/32 on the branch `enc-prefix`; the fallback system is Unix/32V) and the LLVM back end for OpenBSD, which has an assembler and a disassembler and no code generator yet (`handoff.md`), so no driver of this chapter can be compiled for the pdp64 by a compiler that exists for OpenBSD.

*Commentary.* **Chain.** PDP-11: a driver is one C file and a line in `conf.c`, in the language of the day with 16-bit `int`. VAX: the same, with `config(8)` writing the tables. OpenBSD: softc, `cfattach`, `bus_dma`, a framework of its own. pdp64: OpenBSD's framework, with the DMA calls reduced to the identity and the accessors to loads and stores. **Impact.** *Kernel:* the accessors reduce to loads and stores, the DMA interface to physical addresses, and attach to the functions the bus reports. *Compiler:* fixed-width types, `volatile`, and a `FENCE` function or intrinsic. *Hardware:* windows of whole pages let the translation unit protect a device.

## 5.14 Testing a driver

What exists today (read in the repository):

* **`sim64`** has no device and no bus. `-K` starts the System v1 kernel-mode machine with flat physical memory and no MMU, and `-i N:LEVEL:VECTOR` raises an interrupt request of that level and vector once N instructions have started; `wfe` jumps to the next pending request. `tests/sim/sys-irq.S` and `sys-wfe.S` use it: a driver's handler can be entered, but there is nothing to talk to.
* **QEMU's `pdp64-virt` machine** with `kernel-mode=on` has the fixed timer and the fixed console of 5.7, an interrupt controller that is two wires, the vector table at `VBR + 8 × vector`, and an MMU. Its tests are the ones named above: `tests/qemu/con-tx.S` (transmit by polling), `con-rx.S` (receive by interrupt at level 4, vector 33, echo by polling, then transmit by interrupt at vector 34), `timer.S` (counter, compare, level 6, `wfe`) and `mini-kernel.S` (a tiny kernel with page tables, a timer tick at 20 ms, system calls and a demand-paged fault). They run under `tools/check-qemu.sh`.
* **Not implemented, anywhere in the repository:** a PCI Express root complex, configuration space, a virtio device, an MSI-X target, an interrupt controller beyond the two fixed wires, an IOMMU, a block device, a network device. A search of `qemu/`, `sim64/`, `common/` and `spec/pdp64-system.hbnf` for `pci`, `virtio`, `msi` and `iommu` finds nothing. The statement that "the same devices run in QEMU, `sim64` and the FPGA" (5.3.1) is an aim.
* **What QEMU's own sources provide.** `hw/virtio` holds the virtio devices (`virtio-rng.c`, `virtio-blk.c`, `virtio-net.c`, `virtio-gpu`, `virtio-snd.c`, `virtio-serial-bus.c`) and the PCI transport; QEMU's ARM and RISC-V `virt` machines attach them through a PCI Express host bridge (*unverified*: the machines' sources were not read). A pdp64 machine that attached them would need a root complex model, the interrupt controller of R1 and, for the IOMMU, a model of it, in `qemu/hw-pdp64/virt.c`; none is begun.

A virtio driver could be exercised before the machine has them by compiling its logic for the host and running it against a software model of a virtqueue; that is a proposal and nothing in the repository does it.

## 5.15 What was checked, and what was not

The virtio and PCI Express specifications are not on this computer. What the chapter rests on:

* **2.11BSD** (`unixtree/2.11BSD/sys`): `pdpuba/rk.c`, `rkreg.h`, `ubavar.h`, `pdp/conf.c` (the `bdevsw` and `cdevsw` rows), `h/conf.h`, `h/buf.h`, `h/uba.h`, `pdp/scb.s` (the vectors and levels of the RK11, the console and the clock), `pdp/cons.c`, `sys/tty_subr.c`, `h/clist.h`, `sys/vm_swp.c` (`physio`, `rawrw`), `pdp/machdep.c` (`mapalloc`), `sys/ufs_bio.c` (`biodone`), `autoconfig/` (`main.c`, `do_config.c`, `attach.c`, `rkauto.c`), `pdp/machparam.h` (`splx`). **V7** `usr/sys/dev/rk.c`.
* **4.3BSD** (`unixtree/4.3BSD/usr/src`): `sys/vaxuba/ubavar.h`, `uba.c` (`ubareset`), `rk.c`, `sys/vax/autoconf.c` (`unifind`), `etc/config/mkioconf.c`, `sys/vaxif/if_dereg.h`.
* **Linux headers** in `/usr/include/linux`: `virtio_pci.h` (the common-configuration offsets), `virtio_config.h`, `virtio_ring.h`, `virtio_ids.h`, `virtio_blk.h`, `virtio_net.h`, `virtio_console.h`, `virtio_snd.h`, `virtio_gpu.h`, `virtio_rng.h`, `virtio_rtc.h`, and a search of all `virtio_*.h` for "firmware" and "BSD licensed".
* **QEMU** (`/home/david/claude/qemu-src/hw`): the queues created by `virtio-rng.c`, `virtio-serial-bus.c` (including the emergency write in `set_config`), `virtio-blk.c`, `virtio-net.c`, `virtio-gpu-base.c`, `virtio-snd.c`; the pdp64 target in `qemu/hw-pdp64`.
* **OpenBSD 8.0** (`facetlang/pdp11/openbsd-src/sys`): `dev/pv/vioblk.c`, `viornd.c`, `viocon.c`, `viogpu.c`, `if_vio.c`, `virtio.c`, `dev/pci/virtio_pci.c`, `dev/firmload.c`, `scsi/sd.c`, `arch/amd64/amd64/conf.c`; line counts from `wc`. The older OpenBSD tree at `kernel-src/openbsd` has no `sys/dev/pv`.
* **The repository:** `spec/pdp64-system.hbnf`, `qemu/hw-pdp64`, `sim64/sim64.c`, `tests/qemu`, `tests/sim`, `tests/c-new/avail_volatile.c`, the pcc tree's `arch/pdp64/pdp64-names.h`, `docs/errata.md`, `docs/smp-decisions.md`, `docs/decisions-pending.md`, `docs/decision-log` (the briefing `B.md`, item Q6 and Q7, and the author's messages).
* **Unverified** (general knowledge): the PDP-11 caches and the contiguity of a process's memory beyond what `physio` assumes; the PCI and virtio history; that a virtio reset restarts the ring indices; that `request_firmware` is Linux's; Linux's `probe` and `remove`, `swiotlb`, `VFIO`, `UIO` and DPDK; that x86 DMA is coherent and some ARM and MIPS DMA is not; the VAX interval timer and console processor; device trees on ARM and RISC-V machines; that a USB-to-Ethernet adapter appears as a network device; that QEMU's ARM and RISC-V machines attach virtio through a PCI Express host bridge.
* **The ledger** (`docs/decisions-and-status.md`) was read for devices, virtio, the standard GPU, NIC and audio interfaces, USB and NVMe, random numbers, device initialisation, hot-plug, interrupt entry and the first operating system; this chapter agrees with its Decided lines. Where it differs: it still lists the virtio-only rewrite as TO DO and says `errata.md` ends at 93; it lists the entropy and device-initialisation subjects as IN THE AIR, which the chapter says too.
* **Decided** by the author and recorded in `errata.md`: every statement tagged *(D)*. Nothing else in this chapter is a decision, and the console, timer, entropy, interrupt-controller, firmware and device-tree discussions are open.

## 5.16 Still open

The feature subset of each virtio device and the platform-ordering feature (5.4.4); the feature subset of virtio-blk (flush, block size, ordering) and the boot ROM's read of block 0 (5.6.2); the form of the console, the timer and the entropy source, and whether a device tree exists (5.7.1; briefing `B.md`, Q6; `decisions-pending.md` F11 and F12); the interrupt controller, the vector numbering and the routing (5.9; R1); DMA addressing and protection (R6, 5.10.2); errors raised by devices (R7); how a device is given firmware (5.12.1); the PCI Express root complex, interrupt controller and IOMMU models without which no driver can be tested (5.14); a `FENCE` in C; which virtio devices "it makes sense to support" in silicon, and the syntactic sugar of message 592:13. The working documents are [`../decisions-pending.md`](../../decisions-pending.md) and [`../pdp64-q64-bus.md`](../../pdp64-q64-bus.md), and appendix B.
