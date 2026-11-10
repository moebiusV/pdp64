# 2. The bus

[← manual index](00-index.md)

**The processor reaches the world through one bus, Q64, which is PCI Express with convenience and security circuitry added; every standard device is a virtio device (the disk is virtio-blk) or a USB controller, and any other PCI Express device may be attached, all found by PCI Express enumeration; every transfer of data is a descriptor in a queue in memory that the device carries out and marks done.**

The chapter starts from the Unibus of the PDP-11 and explains each later idea by contrast with it: the PCI Express link, the configuration space, base-address registers, bus-mastering DMA, virtio, message-signalled interrupts and the IOMMU. Between the PDP-11 and the pdp64 it names the intermediate steps that changed the idea (the VAX interconnect, PCI, PCI Express, virtio), each with the one thing it contributed; section 2.1 gives the route in a table, and each commentary repeats the part of it that concerns its topic. The numbered statements are the rules; the rest is explanation. Tags: *(D)* decided, *(P)* proposed, *(S)* unspecified. A fact about PCI Express or virtio that could not be checked on this machine is marked *unverified* and listed in section 2.12. How a driver talks to a device, the virtio transport and the default devices are in chapter 5; interrupts and modes are chapter 6; the other cores are chapter 7. The full discussion is in [`../pdp64-q64-bus.md`](../../pdp64-q64-bus.md); the open options are in [`../decisions-pending.md`](../../decisions-pending.md).

A term is defined where it first appears, as the technical word followed by a plain restatement. The boxes-and-arrows figures are the kind a textbook draws for a linked list: a box is a piece of memory, an arrow is an address stored in it. Code blocks are pseudocode (C-like; `mmio_read16(address)` and the like are ordinary loads and stores to a device register, section 2.3); the PDP-11 assembly is quoted from a 2.11BSD driver or written in its style.

## 2.1 What you already know: the Unibus

A PDP-11 reaches everything outside the processor over its **bus** (a set of shared wires that every part of the machine hangs on), the Unibus. Four ideas of it matter here, because each later idea in this chapter keeps or replaces one of them.

**Registers at fixed addresses.** The Unibus has 18 address lines, so 256 KB of **address space** (the set of numbers that name locations). The top 8 KB of it is the **I/O page** (the region where devices, not memory, answer). A device is a handful of 16-bit **registers** (small storage cells in the device that the processor can read or write) at addresses that were set by switches on the card. Nothing tells the processor what is plugged in. 2.11BSD's standalone boot code has the RK11 at `0177400` written into it (`pdpstand/rk.c`), and the kernel's autoconfiguration has a probe routine per device that pokes the controller (`rkprobe` in `autoconfig/rkauto.c` writes a drive reset with interrupt enable and returns `ACP_IFINTR`, a flag meaning "present if it interrupts"). A driver is written against a C structure laid over those addresses; this is the whole of 2.11BSD's declaration for the RK05 disk controller (`rkreg.h`):

```
struct rkdevice {
        short   rkds;   /* drive status        */
        short   rker;   /* error bits          */
        short   rkcs;   /* control and status  */
        short   rkwc;   /* word count          */
        caddr_t rkba;   /* bus address         */
        short   rkda;   /* disk address        */
};
```

![The Unibus: address space and the registers of a disk](figures/bus-unibus.svg)

**The CSR convention.** Most devices have a **CSR** (control and status register: one word whose bits both command the device and report on it). The RK11's has GO in bit 0 (do it now), READY in bit 7 (the device is idle and may be given work), IDE in bit 6 (interrupt on done enable) and ERROR in bit 15 (`rkreg.h`: `RKCS_GO` 01, `RKCS_RDY` 0200, `RKCS_IDE` 0100, `RKCS_ERR` 0100000). The console serial line has the same shape: its status register is at `0177560` in `pdp/cons.c`. Other devices with a **DBR** (data buffer register: the word the data passes through) beside the CSR are *unverified* here.

**DMA.** To move a block, the processor does not copy words: it writes the memory address into a register (`rkba`), a negative count into another (`rkwc`), the disk address into a third and then GO. The controller becomes a **bus master** (a part that is allowed to start transfers itself, not only answer them) and **DMA** (direct memory access: moving data between a device and memory without the processor's help) does the copying, requesting the bus by **NPR** (non-processor request: the Unibus line a device raises to be given the bus for a data transfer at once, at a priority above every interrupt). The 18-bit bus address was too narrow once memory grew, and a **map register** (a table entry that translates a device's address to a memory address) appears in 2.11BSD as the UNIBUS map: `struct ubmap` (two 16-bit words per register) at `0170200`, allocated by `mapalloc` (`h/uba.h`, `pdp/machdep.c`). It is the ancestor of the IOMMU of section 2.11.

**Interrupts.** A device that wants attention asserts one of four **BR** lines (bus request, levels 4 to 7: the priority at which it wishes to interrupt; `br4` to `br7` in 2.11BSD's `pdp/scb.s`); when the processor's priority is lower, it grants the bus, and the device places its own **interrupt vector** (the address of a pair of words, new program counter and new status word, that the processor loads) on the data lines. The vector too was set by switches on the card; the RK11's is `0220` at level 5 (`DEVTRAP(220, rkintr, br5)` in `pdp/scb.s`). The interrupt routine returns with `RTI` (return from interrupt). A driver that does not want interrupts **polls** (reads the status register again and again until the bit it wants changes).

Here is the RK11 driver in the two styles, both real or in the style of the real code. The interrupt-driven start, from 2.11BSD `pdpuba/rk.c`:

```
rkaddr->rkda = (dn << 13) | (cn << 4) | sn;     /* disk address     */
rkaddr->rkba = bp->b_un.b_addr;                  /* where in memory  */
rkaddr->rkwc = -(bp->b_bcount >> 1);             /* words, negative  */
com = ((bp->b_xmem & 3) << 4) | RKCS_IDE | RKCS_GO;
com |= (bp->b_flags & B_READ) ? RKCS_RCOM : RKCS_WCOM;
rkaddr->rkcs = com;                              /* go; return; rkintr() runs when done */
```

and the same command polled, in PDP-11 assembly (the registers are at `0177400` plus the structure's offsets: `rkds` 0, `rker` 2, `rkcs` 4, `rkwc` 6, `rkba` 010, `rkda` 012; `RCOM` is `RKCS_RCOM`, 04):

```
        MOV  #<disk address>, @#177412     ; RKDA
        MOV  #<buffer>,       @#177410     ; RKBA
        MOV  #-256.,          @#177406     ; RKWC: 256 words, negative
        MOV  #RCOM+GO,        @#177404     ; RKCS: read, go, no interrupt enable
1$:     TSTB @#177404                      ; bit 7 of the low byte is READY
        BPL  1$                            ; plus means not yet: look again
        TST  @#177404                      ; bit 15 is ERROR
        BMI  error
```

The processor knows the register layout, loads each register, waits, and knows the meaning of every bit of that one device. A device with different registers needs a new driver. The rest of the chapter is the answer the pdp64 adopts: every device has the same shape.

Gone in Q64: the fixed I/O page, the switches, the vectors on the data lines, the bus request levels, and the single shared set of wires (with it the locked read-modify-write `DATIP`/`DATO`, section 2.10). Kept: devices are locations in the one address space, reached by ordinary loads and stores with no I/O instructions (2.3.2); the device moves its own data by DMA; the interrupt says only "look at the device"; polling stays allowed (2.7.4).

**The route from the Unibus to Q64.** Each row is one step and what it contributed; the later sections say where the contribution is used.

| step | what it contributed | basis |
|---|---|---|
| PDP-11 Unibus | registers in one address space, CSR, DMA by NPR, vectors and BR levels, map registers | 2.11BSD sources |
| VAX-11/780 | devices behind adapters on an interconnect whose slots report their type in a status register, so the kernel scans instead of being told; the Unibus adapter keeps the map registers and adds buffered data paths that a driver purges; a Massbus adapter is a second kind of adapter (`NEX_MBA`, `NEX_UBA0`) | 4.3BSD `nexus.h`, `ubareg.h`, `autoconf.c` |
| PCI | every function describes itself in a configuration space, and windows are placed by software through base-address registers | the layout is checked in `pci_regs.h`; the date and history are *unverified* |
| PCI Express | the same software model over point-to-point links and packets; MSI-X interrupts as memory writes; bus mastering as a command bit | `pci_regs.h`, QEMU `docs/pcie.txt` |
| virtio | one transport and one queue structure for every device kind | `virtio_*.h`, QEMU |
| Q64 | the above, with no device-space address bit, an IOMMU, precise faults and one fence rule | the decisions of errata 75, 80, 95, 97, 101, 102, 104 |

The name Q64 echoes the PDP-11 Q-bus, which no source on this machine describes (*unverified*; statement 2.3.1 uses it as the model for "devices as memory locations").

## 2.2 PCI Express: links, packets and configuration space

PCI Express (written PCIe) descends from PCI, the 1990s parallel bus (*unverified*: dates and lineage are not in any source here) whose configuration space and software model it kept. Its ideas, each against the Unibus.

**A link, not a shared bus.** A Unibus is one set of wires that all devices share, so only one transfer happens at a time and every card loads the wires. PCI Express uses **point-to-point links** (a connection between exactly two ends; nothing else is on it). A **lane** is the unit of width: a pair of wires carrying data one way and a second pair the other way, so a lane sends and receives at the same time. A link of more lanes is faster: `pci_regs.h` defines negotiated widths x1, x2, x4 and x8 and has a six-bit width field (x16 and wider are *unverified*). The speed codes of `pci_regs.h` are 2.5, 5, 8, 16, 32 and 64 **GT/s** (gigatransfers a second: signal changes, not yet bytes); each generation is faster than the last. Software sees none of this; it sees addresses.

**A tree.** Because links are point-to-point, a machine is a tree. The root is the **root complex** (the part, in the processor chip or beside it, that connects the processor and memory to the tree and is the PCI Express counterpart of the Unibus's processor-side logic); below it are **root ports** (its links to the outside), **switches** and **bridges** (parts with one link up and several down, which pass traffic between them; to software a switch is a set of bridges) and at the leaves **endpoints** (the devices). QEMU's `docs/pcie.txt` uses these words: root complex, root port, downstream port, bridge, integrated endpoint.

![A PCI Express tree](figures/bus-tree.svg)

**Packets.** Where the Unibus signals on dedicated wires, PCI Express sends everything as a **packet** (a small message with a header that says what it is, where it goes and how much data follows). The packets that carry reads and writes are **TLPs** (transaction layer packets: the unit software sees, above the layers that frame bytes and retry on error). The kinds a programmer meets (*unverified*; the specification is not on this machine): a memory write (address and data, with no answer, called **posted**: the sender has handed it over and moves on); a memory read (address and length), answered later by a **completion** (a packet carrying the data back); configuration reads and writes; and messages. A read is a **split transaction** (request and answer are separate packets, and the link is free in between); on the Unibus the bus master held the bus, with `MSYN` asserted, until the slave replied with `SSYN` (*unverified* here). Two consequences: a write has "happened" in the program's mind while it is still on its way, which is why section 2.8 has a `FENCE`; and an interrupt (section 2.7) can be a packet like any other.

**Configuration space: the device describes itself.** The Unibus had nothing like it. Every device, which PCI Express calls a **function** (one logical device; a card may carry several), has a **configuration space** (a block of 4096 bytes of registers, separate from the device's working registers, that says who made the device, what it is and how much address space it wants). The first 256 bytes are the older PCI part, with a 64-byte header; the 4096 bytes in all are the PCI Express part (`PCI_CFG_SPACE_SIZE` 256 and `PCI_CFG_SPACE_EXP_SIZE` 4096). A function is named by three numbers, its **bus**, **device** and **function** numbers (the position in the tree). The processor reaches the configuration space of function (b, d, f) with ordinary loads and stores to one address range: byte `offset` of function (b, d, f) is at `base + (b << 20) + (((d << 3) + f) << 12) + offset` (this is **ECAM**, enhanced configuration access mechanism; the shifts are from QEMU's `pcie_host.h`, `PCIE_MMCFG_BUS_BIT` 20 and `PCIE_MMCFG_DEVFN_BIT` 12). Where `base` is on the pdp64 is not specified (2.4.8).

![The configuration-space header and the capability list](figures/bus-config-header.svg)

The 64-byte header of an ordinary function (type 0) holds, as the figure shows and `pci_regs.h` defines: the **vendor ID** and **device ID** (two 16-bit numbers that name the maker and the product; 0xFFFF as a vendor ID means that no function answers), the **command** register (bit 1 lets the function answer memory addresses, bit 2 lets it be a bus master, bit 10 turns off its old-style interrupt pin), the **status** register, the **class code** (what kind of device), the **header type** at 0x0E (0 for an ordinary function, 1 for a bridge, with bit 7 set when the card has several functions) and six **base-address registers** at 0x10 to 0x24 (section 2.4). A pointer to the capability list is at 0x34. A bridge's header (type 1) has a different layout after the first 16 bytes; the bus-number bytes at 0x18 to 0x1A are its.

**Capabilities.** The header is fixed; everything optional hangs off a **capability list**: a linked list, inside the configuration space, of small records, each starting with an identifier byte and a byte holding the offset of the next record (0 ends the list). It is a linked list of the kind drawn in section 2.6. The records a pdp64 driver looks for are the MSI-X record (identifier 0x11, section 2.7), the PCI Express record (0x10) and the vendor-specific record (0x09) which virtio uses to say where its structures are (section 2.6).

**What the pdp64 adds.** A PCI Express endpoint looks to software like a PCI device, so one driver model serves both (*unverified* as history). The author's decision (errata 80) is that Q64 is PCI Express, so an ordinary card works on it unchanged, with circuitry added on the processor side for convenience and security (2.3.5).

## 2.3 Q64 and the address space

**Memory-mapped registers.** On the PDP-11 the registers of a device are **memory-mapped** (they have addresses in the same address space as memory, so the instruction that reads memory reads a register). Q64 keeps this and widens it: a function's registers are in **windows** (ranges of the physical address space that the function answers), and a driver reaches them with ordinary loads and stores, with no input or output instructions. What changed is who chooses the addresses. On the Unibus the switches on the card did. In PCI Express the function says how much room it needs, the system assigns an address, and the function answers there (section 2.4). The **base-address register** (BAR: a register in the configuration-space header that holds where a window starts and, by the trick of section 2.4, how big it is) places a window in the address map:

![A base-address register and its window](figures/bus-bar-window.svg)

Against the Unibus, three things differ. The fixed I/O page at the top of the address space is gone (errata 97, 102: no address bit says "device"); the address is wider (40 to 64 bits, against 18); and a window may be placed anywhere except the first few pages, where the boot code and boot data are loaded.

**2.3.1** Q64 is the system bus: PCI Express, so that an ordinary PCI Express device works on it unchanged, with the programming model of the PDP-11 Q-bus (devices as memory locations in the one address space) widened to 64-bit data and a physical address that is not limited to 40 bits (the simulator and the emulator implement 40), and with convenience and security circuitry added. *(D)*

**2.3.2** Devices live in the ordinary address space; the processor has no input or output instructions. *(D)*

**2.3.3** The windows of a device (the regions its base-address registers describe) start on 4 KB page boundaries and are a whole number of pages, so that one device can be mapped to one protection domain. *(P)*

**2.3.4** Every page has a memory type: normal cached, normal uncached, device strongly ordered, or device weakly ordered. *(D)*

**2.3.5** The transactions of Q64 are those of PCI Express; the circuitry the pdp64 adds is for convenience (overlays, helper registers) and security (the IOMMU, error and reset rules), and is measured against the list of pain points of `kernel-pain-points.md`. An extension is announced to a card, through a PCI Express extended capability, only if the card must take part in it; a mitigation that lives on the processor side is invisible to cards. *(D)* The detail of the extensions is not specified. *(S)*

**2.3.6** No bit of the physical address selects device space: a device window is an ordinary range of physical addresses, found by enumeration (section 2.4), and the physical address is at least 40 bits and at most 64, an implementation choosing its width in that range, so that mappings of petabytes are possible. *(D)* A window can be mapped anywhere in the physical address space except the first few pages, where the boot code and boot data are loaded. *(D)* How many pages are "the first few" is not decided, *(P)* and nor is how software discovers the implemented width. *(S)* The simulator and the emulator place their devices in the upper half of a 40-bit space, from `0x8000000000`, and check the memory type of a page against that bit; these two arrangements belong to the present implementation, not to the architecture.

*Commentary on 2.3.6.* **Chain.** The PDP-11 put its devices in a fixed page at the top of the address space (a driver's pointer to its registers is a constant in that page: `cnaddr = 0177560` in 2.11BSD `pdp/cons.c`). The VAX-11/780 put them in nexus space from `0x20000000`, one 8 KB window (`NEXSIZE` 0x2000) per slot (`NEX780` in 4.3BSD `nexus.h`), and `nexus.h` gives the 11/750, 730 and 8600 different bases, so the VAX kept changing the map from model to model. PCI Express places each function's windows where enumeration assigns them. The pdp64 follows PCI Express. **Trade-off.** A decoding bit makes the first routing decision in the fabric trivial and makes a mapping of the wrong memory type detectable, at the cost of half the physical address space; the author dropped it because mapping petabytes needs those bits. Without it, a device's DMA into another device's window is refused by the IOMMU (errata 85), not by the address. **Impact.** The kernel maps devices where enumeration says and recognises a device mapping by its memory type and window; the root complex decodes the windows it has assigned. Whether other systems split the map by platform-chosen ranges, and whether x86 has a separate port space, are *unverified* here.

## 2.4 Enumeration and hot-plug

**Finding the devices.** The PDP-11 kernel is told where each device is and probes the address (2.1); the VAX kernel scans the slots of its interconnect and reads each one's type; the Q64 kernel asks every function. **Enumeration** (walking the whole tree and reading each function's configuration space to find out what is there) goes: for every bus, for every device number 0 to 31 and function number 0 to 7, read the vendor ID; if a function answers, read its header type; if it is a bridge, give the bus behind it a number and walk that bus too; if it is an ordinary function, size and place its windows and record it. The pseudocode (the bus numbers follow the `PCI_PRIMARY_BUS`, `PCI_SECONDARY_BUS` and `PCI_SUBORDINATE_BUS` bytes at offsets 0x18 to 0x1A of a bridge's header):

```
next_bus = 1                                   # bus 0 is the root complex's own

scan(bus):
    for dev in 0 .. 31:
        for fn in 0 .. 7:
            vendor = cfg_read16(bus, dev, fn, 0x00)
            if vendor == 0xFFFF:               # nothing here
                if fn == 0: break              # no function 0, no card: skip its other functions
                continue
            htype = cfg_read8(bus, dev, fn, 0x0E)
            if (htype & 0x7F) == 1:            # a bridge: a bus lies behind it
                secondary = next_bus++
                cfg_write8(bus, dev, fn, 0x18, bus)           # primary bus
                cfg_write8(bus, dev, fn, 0x19, secondary)     # secondary bus
                cfg_write8(bus, dev, fn, 0x1A, 255)           # subordinate: provisional
                scan(secondary)                               # the recursion
                cfg_write8(bus, dev, fn, 0x1A, next_bus - 1)  # now the real highest number
            else:
                size_and_place_bars(bus, dev, fn)
                add_to_device_list(bus, dev, fn, vendor, cfg_read16(bus, dev, fn, 0x02))
            if fn == 0 and not (htype & 0x80): break          # single-function card
```

(`cfg_read16` is a load from the ECAM address of section 2.2. A real PCI Express root complex and QEMU answer all ones for an empty position (*unverified* on real hardware); the pdp64's root complex does so by decision (2.4.9). The windows of a bridge must also be programmed so that traffic for the functions behind it passes; that step is omitted here.)

**Sizing a window.** The register must say how big its window is, and it is the same register that holds the address. The bits below the size are not storage: they always read as zero. So the system writes all ones, reads the register back, and the bits that stuck show the size (the header comment of `pci_regs.h` says the same: "writing a value of 0xffffffff to the register, and reading it back. Only 1 bits are decoded"; QEMU builds the answer as `~(size - 1)`). The low four bits of a memory BAR are not part of the address (the listing below handles memory BARs only): bit 0 is 0 for memory and 1 for an I/O port, bits 2:1 give the width (00 is a 32-bit address, 10 a 64-bit one that uses the **next** BAR as its high half), and bit 3 says the memory is **prefetchable** (reading it has no side effects, so it can be read ahead).

```
size_bar(bus, dev, fn, index):                       # returns (size, is_64bit)
    reg = 0x10 + 4 * index
    cmd = cfg_read16(bus, dev, fn, 0x04)
    cfg_write16(bus, dev, fn, 0x04, cmd & ~0x2)      # stop the function answering memory while we play
    old = cfg_read32(bus, dev, fn, reg)
    cfg_write32(bus, dev, fn, reg, 0xFFFFFFFF)
    got = cfg_read32(bus, dev, fn, reg)
    cfg_write32(bus, dev, fn, reg, old)              # put it back
    is64 = ((got >> 1) & 3) == 2
    if is64:                                         # the same dance on the high half
        oldh = cfg_read32(..., reg + 4)
        cfg_write32(..., reg + 4, 0xFFFFFFFF)
        goth = cfg_read32(..., reg + 4)
        cfg_write32(..., reg + 4, oldh)
        mask = (goth << 32) | (got & 0xFFFFFFF0)
        size = (~mask + 1) & 0xFFFFFFFFFFFFFFFF
    else:
        mask = got & 0xFFFFFFF0
        size = (~mask + 1) & 0xFFFFFFFF
    cfg_write16(bus, dev, fn, 0x04, cmd)             # restore the command register
    return (size, is64)

size_and_place_bars(bus, dev, fn):
    index = 0
    while index < 6:
        (size, is64) = size_bar(bus, dev, fn, index)
        if size != 0:
            base = allocate(size, align = size)      # a window starts on a multiple of its own size
            cfg_write32(bus, dev, fn, 0x10 + 4*index, base & 0xFFFFFFFF)
            if is64: cfg_write32(bus, dev, fn, 0x14 + 4*index, base >> 32)
        index += 2 if is64 else 1
    cmd = cfg_read16(bus, dev, fn, 0x04)
    cfg_write16(bus, dev, fn, 0x04, cmd | 0x2 | 0x4) # answer memory (bit 1); may be a bus master (bit 2)
```

The worked example of the figure: reading back 0xFFFFC000 means the low 14 bits are not storage, so the size is 2^14 = 16 KB. On the pdp64 a window is at least a page, 4 KB, and a whole number of pages (2.3.3), so that one device can be given to one protection domain. The last line sets bit 2 of the command register; until it is set the function may not start a transfer of its own (section 2.5).

**2.4.1** The processor finds the devices by PCI Express enumeration: it reads the configuration space of each function through the root complex, sizes the base-address registers of the function and assigns its windows in device space. *(D)*

**2.4.2** A function is a virtio device when its configuration space says so (the virtio vendor identifier and a device identifier that carries the virtio device type); the capabilities in its configuration space locate the virtio structures in its windows (chapter 5). One transport driver serves every virtio device. *(D)*

**2.4.3** A function may itself be a bus: a PCI Express bridge presents the functions behind it, and a USB host controller (itself a PCI Express function) enumerates its own tree of hubs and devices, so any bus can be attached to Q64 and its devices enumerated, to any depth. The kernel's enumeration is one recursive walk. *(D)*

**2.4.4** The bus alerts the processor when a device enters or leaves, by an interrupt; the kernel then rescans the bus, which is also what it does at boot. *(P)*

**2.4.5** When a device leaves, an access to its windows is at once a precise bus fault, not a read of all ones: a read of the window faults, a posted write is dropped and counted, and the device's in-flight bus transactions are aborted. *(P)*

**2.4.6** The queued work of a departed device stays in memory untouched, so the driver can read, save, resend or fail it. *(P)*

**2.4.7** A bus reset produces no removal events, so a reset is not mistaken for the removal of every device, and the identity of every function is defined after the bus has lost power. *(D)*

**2.4.8** Where the configuration space and the windows of the functions sit in the physical address space (fixed bases and sizes) is unspecified, as is how a hot-plug event behind a bridge is reported. *(S)*

**2.4.9** A read of a configuration position that never held a function completes normally and returns all ones in every byte, so a vendor ID of `0xFFFF` means that nothing is there; it is not a bus fault (the read of other non-existent addresses stays a precise `BUSFAULT`, 6.4.3). *(D)*

**2.4.10** The root complex records such a miss in a sticky bit of its own status register, cleared by writing a one to it, so that a dead link can be told from an empty slot; the register and its place are not specified. *(D)*

*Commentary.* **Chain.** The PDP-11 had no enumeration: devices at switch-set addresses, found by probes such as `rkprobe`, and nothing told the kernel when a device left. The VAX scanned its interconnect: `probenexi()` in 4.3BSD `autoconf.c` reads each nexus slot's status register (`badaddr` first, then the type field, `NEX_MEM4`, `NEX_MBA`, `NEX_UBA0` and so on), and `unifind()` probes the devices behind each Unibus adapter. PCI added configuration space and sizing by writing all ones, so a card can be placed anywhere. PCI Express keeps that and adds hot-plug (*unverified*: the slot-status interrupt). The pdp64 uses standard enumeration, so an ordinary card works unchanged and the kernel needs one address, the root complex's. Amiga AutoConfig (each board announces itself at a fixed address and is told where to live) and NuBus (a fixed share of the address space per slot) are other answers (*unverified* here); assignment on demand supports any layout at the cost of a sizing step at boot, a fixed window per slot needs no assignment and limits the slot count. **Where the pdp64 differs.** On a surprise removal PCI returns all ones, so every driver must treat all ones as a possible error (*unverified*); the pdp64 uses the precise bus fault the instruction set already defines (2.4.5), so a driver has one recovery path, and rescan on an event makes hot-plug and boot the same code. **Impact.** One recursive loop over the functions of each bus; hot-plug is an interrupt and a rescan; the root complex is a standard one plus the precise fault for an absent device.

*Commentary on 2.4.3.* **Chain.** The VAX did this: the Unibus hung off the 11/780's interconnect through a Unibus adapter, a nexus device whose registers include the map registers for DMA and whose Unibus memory (the devices' registers) appears in a window of its own (`UMEM780(i)` at `0x20100000 + i * 0x40000`, `vaxuba/ubareg.h`, 4.3BSD). PCI-to-PCI bridges nest buses, a USB host controller enumerates a tree of hubs and devices, and Thunderbolt tunnels PCI Express over a cable (*unverified*). The pdp64 allows any bus to be attached behind a bridge. **Trade-off.** Each level adds a mapping of windows and a hop of latency, and a departure deep in the tree must be reported to a driver that does not know the path; a bridge's windows are ordinary device windows (2.3.6). **Impact.** A new bus costs one bridge and no change to the processor, the kernel's walk or the driver model; a bridge is a standard PCI Express bridge.

## 2.5 DMA, coherence and the hand-off

**Bus mastering.** On the Unibus any device could become master by winning an NPR grant. In PCI Express a function is a **bus master** (it may originate memory reads and writes of its own, as packets, instead of only answering) once the processor sets bit 2 of its command register; until then it only answers. A DMA transfer is a function sending memory-write packets (to deliver data) or memory-read packets (to fetch it) to addresses in memory the processor gave it. There is no request line, no grant chain and no priority between devices; the switches of the tree carry the packets. The danger is the one the Unibus map registers hinted at: a device that can write anywhere can write into the kernel (section 2.11).

**The hand-off.** Telling each side that the data is ready is the harder half of DMA, and a queue in memory does it (section 2.6). Statement 2.5.3 gives the five steps in order.

**2.5.1** Between processors the data caches are coherent without any software action, by snooping with three states (modified, shared, invalid), for two to four cores. *(D)*

**2.5.2** Between a processor and a DMA device they are not: buffers are mapped uncached and the hand-off is explicit. *(D)*

**2.5.3** The hand-off is five steps: the processor builds the descriptors and data in uncached memory, executes `FENCE`, writes the device's notification address; the device walks the descriptors, moves the data by DMA, writes the result and its used-ring entry, and raises an interrupt; the processor reads the result. *(D)*

**2.5.4** The write that raises a device's interrupt (a message-signalled write) cannot overtake the data writes that precede it on the same path. *(D)*

*Commentary.* **Chain.** The RK11 driver of 2.1 contains no cache or ordering step. On the VAX the Unibus adapter had buffered data paths, and a driver had to purge them before reading what a device had written (`UBA_PURGE780` and `UBA_PURGE750` in 4.3BSD `ubareg.h`). That a PDP-11/70's cache watched Unibus writes so that DMA appeared coherent is *unverified* here. Modern x86 DMA is coherent, while ARM and MIPS systems with non-coherent DMA need a kernel layer that places cache maintenance (*unverified*). The pdp64 chooses two mechanisms, each where it is cheap: snooping between cores, which are few, and uncached buffers with an explicit hand-off for DMA, which is large and infrequent. **Trade-off.** The processor reads received data from uncached memory, which is slow; a cache-maintenance instruction would remove that cost for a non-coherent device that may come later. No driver can forget a cache clean or invalidate, because there is none. **Impact.** A snoop port on each data cache for core coherence only; none for DMA.

## 2.6 virtio: one shape for every device

The Unibus gave every device its own registers, and every driver learned them. **virtio** (a specification for devices meant to be imitated in software; the name is from "virtual I/O") gives every device the same few structures in memory, and only the meaning of the requests differs. A **driver** (the program that runs a device) and a **device** (the hardware, or the emulator that pretends to be it) talk by **shared memory** (both sides read and write the same region of memory under a fixed protocol, instead of passing values through registers). The author decided on virtio for every standard device (errata 95, 79, 101): the network card, the graphics device, the audio device and the disk are virtio-net, virtio-gpu, virtio-snd and virtio-blk. One transport driver (2.6.2) and a thin driver per device kind serve the machine, and the same devices run in QEMU, the simulator and the FPGA. The chain from the RK11: one register set per device (PDP-11); the VAX added a second adapter kind, the Massbus (`NEX_MBA`), beside the Unibus adapter, so its interconnect carried several device interfaces; PCI Express made discovery and addressing uniform and left the device interface to each vendor (NVMe, which errata 75 first chose, is one such interface and may still be attached, errata 101); virtio makes the device interface uniform too. Chapter 5 states the rules; this section teaches the shape.

### 2.6.1 The five ideas, against the RK11

| the RK11 | virtio |
|---|---|
| the kernel is told where the device is | the device is found by enumeration, by vendor and device ID (2.6.2) |
| six registers, each with bits of its own | a standard set of registers of **feature bits** and a **status** byte, the same for every device (2.6.3) |
| one command at a time: load the registers, GO | a **virtqueue**, a queue of commands in memory, so many are outstanding at once (2.6.4) |
| the command is in the registers | the command is a **descriptor chain**, boxes in memory linked like a list (2.6.5) |
| READY bit, or an interrupt, says it is done | the device writes the finished chain into the **used ring** in memory, and may interrupt (2.6.6, 2.7) |

### 2.6.2 Finding a virtio device

A virtio function is recognised by its identifiers: the vendor ID is 0x1AF4 (QEMU's `PCI_VENDOR_ID_REDHAT_QUMRANET`), and its device ID is 0x1040 plus the **device type** (QEMU's `PCI_DEVICE_ID_VIRTIO_10_BASE`). The types are in the Linux header `virtio_ids.h`: network 1, block 2, console 3, GPU 16, sound 25, so virtio-blk is device ID 0x1042, virtio-net 0x1041, virtio-gpu 0x1050 and virtio-snd 0x1059. (These are the "modern" device IDs. An older numbering exists; that it starts at 0x1000 is *unverified*, and it is not used, section 2.6.3.)

The registers are not at fixed places in the window. The function's **vendor-specific capabilities** (capability identifier 0x09 in the list of section 2.2) say where each structure is. Each record is the 16 bytes of `struct virtio_pci_cap`: the identifier, the next-record offset, the record length, a `cfg_type` byte that says which structure it describes, a `bar` byte (which of the six windows), an `id` byte, two bytes of padding, a 32-bit `offset` into that window and a 32-bit `length`. The `cfg_type` values are 1 common configuration, 2 notifications, 3 interrupt status, 4 device-specific configuration, 5 a PCI configuration access window, 8 shared memory, 9 vendor data (`virtio_pci.h`); a driver for the pdp64 needs 1 to 4. The notification record (`struct virtio_pci_notify_cap`) is four bytes longer: it ends with a 32-bit `notify_off_multiplier`.

```
find_virtio_structures(fn):
    cap = cfg_read8(fn, 0x34)                       # head of the capability list
    while cap != 0:
        if cfg_read8(fn, cap + 0) == 0x09:          # vendor-specific: could be virtio
            type   = cfg_read8 (fn, cap + 3)
            bar    = cfg_read8 (fn, cap + 4)
            offset = cfg_read32(fn, cap + 8)
            length = cfg_read32(fn, cap + 12)
            where[type] = bar_base(fn, bar) + offset         # the physical address of the structure
            if type == 2: notify_multiplier = cfg_read32(fn, cap + 16)
        cap = cfg_read8(fn, cap + 1)                # follow "next"
```

### 2.6.3 The handshake: status and features

The **common configuration** structure is a block of registers, the same in every device; chapter 5 (5.2.2) lists them with their offsets, from `device_feature_select` at 0x00 to `queue_device` at 0x30 (the Linux header `virtio_pci.h` spells the last three `queue_desc_lo`, `queue_avail_lo` and `queue_used_lo` with `_hi` halves, and the feature registers `guest_feature_select` and `guest_feature`; the offsets follow from its field order). Three are the handshake.

`device_status` is one byte whose bits the driver sets in order, each meaning "I have got this far": ACKNOWLEDGE (1, "I have seen you"), DRIVER (2, "I know how to drive you"), FEATURES_OK (8, "I have chosen my features"), DRIVER_OK (4, "I am running"); the device may set NEEDS_RESET (0x40) and the driver FAILED (0x80) (`virtio_config.h`). Writing 0 resets the device (*unverified*: the Linux headers do not say). The RK11's GO and READY, spread over a conversation, correspond to these bits.

**Feature bits** let two sides that were not written together agree. The device offers a 64-bit set of **features** (optional abilities, one bit each; for example indirect descriptors, bit 28), read 32 bits at a time through a window selected by `device_feature_select`; the driver writes back the subset it will use, and nothing outside that subset is used. A device can add a feature without breaking an old driver, which never asks for it. One feature is required of every device the pdp64 drives, `VIRTIO_F_VERSION_1` (bit 32: "modern layout"; errata 95 and 5.2.5). Two more matter to the processor and are open (2.13): `VIRTIO_F_ACCESS_PLATFORM` (bit 33: device addresses go through the platform's translation, section 2.11) and `VIRTIO_F_ORDER_PLATFORM` (bit 36: the device respects the platform's ordering rules).

```
init_device(fn):
    status = 0;               write_status(0)                    # reset
    write_status(status |= ACKNOWLEDGE)                          # 1
    write_status(status |= DRIVER)                               # 2
    wanted = (1 << 32) | class_driver_features                   # VERSION_1 and what this driver uses
    offered = read_features_64()                                 # 2 reads through device_feature_select
    if (offered & (1 << 32)) == 0: fail()
    write_features_64(wanted & offered)                          # 2 writes through the driver's feature-select window
    write_status(status |= FEATURES_OK)                          # 8
    if (read_status() & FEATURES_OK) == 0: fail()                # the device may refuse the subset
    for q in 0 .. num_queues - 1: setup_queue(q)                 # section 2.6.4
    write_status(status |= DRIVER_OK)                            # 4: go
```

### 2.6.4 A virtqueue: three areas of memory

A **virtqueue** (a queue of requests that lives in ordinary memory, shared by the driver and the device) is three arrays, each in memory the driver allocates: the **descriptor table** (the requests), the **available ring** (the driver's list of which requests are new) and the **used ring** (the device's list of which are finished). The size, a power of two, is a number of entries chosen by the driver up to the device's maximum. Sizes: a descriptor is 16 bytes aligned to 16, the available ring is aligned to 2 and the used ring to 4 (the `VRING_*_ALIGN_SIZE` of `virtio_ring.h`); all fields are little-endian (5.1.3). The driver tells the device where the three are by writing their physical addresses into `queue_desc`, `queue_driver` and `queue_device` (offsets 0x20, 0x28 and 0x30) after selecting the queue with `queue_select`, and then sets `queue_enable`.

```
setup_queue(q):
    write16(queue_select, q)
    n = min(read16(queue_size), 256)                 # the device proposes a size; the driver may lower it
    write16(queue_size, n)
    desc  = alloc_uncached(16 * n, align = 16)       # the descriptor table
    avail = alloc_uncached(6 + 2 * n, align = 2)     # flags, idx, ring[n], one optional word
    used  = alloc_uncached(6 + 8 * n, align = 4)     # flags, idx, ring[n] of 8-byte elements
    zero(desc, avail, used)
    write64(queue_desc, desc);  write64(queue_driver, avail);  write64(queue_device, used)
    write16(queue_msix_vector, vector_for(q))        # section 2.7
    write16(queue_enable, 1)
    notify_addr[q] = where[2] + read16(queue_notify_off) * notify_multiplier    # the doorbell of this queue
    free_head = 0; link all n descriptors into a free list through their `next` fields
    avail_idx = 0; last_used = 0                     # the driver's private counters
```

(The queue memory is in uncached memory on the pdp64, 2.5.2, so no cache instructions appear anywhere. The sizes 6 + 2n and 6 + 8n follow from the structures `struct vring_avail` and `struct vring_used` of `virtio_ring.h`, each two 16-bit fields followed by the ring, and a final optional 16-bit field, section 2.6.9.)

### 2.6.5 The descriptor, and the chain

A **descriptor** is 16 bytes, four fields (`struct vring_desc`): `addr`, a 64-bit physical address of a buffer; `len`, a 32-bit length in bytes; `flags`, 16 bits; and `next`, a 16-bit index of another descriptor. The flags are `NEXT` (1: the request continues in the descriptor `next` names), `WRITE` (2: the device will write into this buffer; absent, the device only reads it) and `INDIRECT` (4: the buffer is itself a table of descriptors). One request is a **chain** (a sequence of descriptors, each pointing to the next by index, ending at one without `NEXT`): in the language of a textbook, a linked list whose nodes are the 16-byte descriptors, whose pointers are table indices and whose payloads are the buffers.

![A chain of descriptors](figures/bus-desc-chain.svg)

The figure is a virtio-blk read of one sector. The first box is the header the driver filled in (`struct virtio_blk_outhdr`: a 32-bit request type, a 32-bit priority, a 64-bit sector number counted in 512-byte units; type 0 is a read, 1 a write, 4 a flush: `virtio_blk.h`); it has no `WRITE` flag because the device only reads it. The second is the 512-byte buffer for the data, with `WRITE`, because for a read the device fills it. The third is one byte the device writes with the result (0 is OK, 1 an I/O error, 2 unsupported). A chain may use any free slots of the table in any order; the free ones are kept on a list of the driver's own. A buffer that straddles a page is simply two descriptors (5.4.3). Compare the RK11: the whole request was in registers, and could not be more than one; here it is memory the device reads, and the table holds many.

### 2.6.6 The available ring and the used ring

The two rings are arrays of 16-bit and 32-bit numbers with an index each.

![The descriptor table, the available ring and the used ring](figures/bus-rings.svg)

The **available ring** (`struct vring_avail`) is a 16-bit `flags`, a 16-bit `idx` and `ring[]`, 16-bit entries. The driver puts the index of the **head** (first descriptor) of a chain into `ring[idx mod size]` and then adds 1 to `idx`; `idx` only ever increases and wraps at 65536, so that "how many have been offered in all" is the difference of two readings and no extra state is kept. The **used ring** (`struct vring_used`) is the mirror: `flags`, `idx` and `ring[]` of **used elements** (`struct vring_used_elem`), each a 32-bit `id` (the head of the finished chain) and a 32-bit `len` (the number of bytes the device wrote into the chain's buffers). The device writes the element and then adds 1 to its own `idx`. Each side keeps a private count of how far it has read the other's ring (`last_used` for the driver); each ring has one writer, so neither side waits for the other and no lock is needed. This is the **producer-consumer ring** (a fixed circular array with one writer and one reader, each owning one index) that the 4.3BSD DEUNA's transmit and receive rings already were, except that the "own" bit of each DEUNA entry is replaced by the two indices.

### 2.6.7 Posting a buffer and reaping the completions

```
post(q, head):                                       # head: first descriptor of a built chain
    avail.ring[avail_idx mod n] = head               # 1. name the chain
    FENCE                                            # 2. the descriptors and the ring entry are visible...
    avail_idx = avail_idx + 1 (mod 65536)
    avail.idx = avail_idx                            # 3. ...before the device is told there is one more
    FENCE
    if (used.flags & NO_NOTIFY) == 0:                # the device may ask not to be rung (section 2.6.9)
        mmio_write16(notify_addr[q], q)              # 4. the doorbell

reap(q):                                             # called from the interrupt routine, or when polling
    while last_used != used.idx:                     # the device has added finished chains
        FENCE                                        # read the index first, then the element and the data (5.4.4)
        e = used.ring[last_used mod n]               # e.id = head of chain, e.len = bytes written
        complete(e.id, e.len)                        # the class driver reads status, frees the chain
        free_chain(e.id)
        last_used = last_used + 1 (mod 65536)
```

The doorbell is an ordinary 16-bit write to a notification address: the address is the notification area's base plus `queue_notify_off` times the `notify_off_multiplier` (QEMU decodes the queue from the address, `addr / multiplier`; what value the specification asks the driver to write is *unverified*: the code above writes the queue number, which QEMU ignores). The `FENCE` between step 1 and step 3 is the pdp64's statement 2.8.2; the processor owes nothing else (2.8.1).

A complete read of one sector, from the driver's side, putting the pieces of this section together:

```
blk_read(sector, buf):                               # buf: a physical address of 512 bytes
    h = alloc_hdr();  h.type = 0; h.ioprio = 0; h.sector = sector      # 16 bytes
    s = alloc_status_byte()
    d0 = get_free();  d1 = get_free();  d2 = get_free()
    desc[d0] = { addr: h,   len: 16,  flags: NEXT,         next: d1 }
    desc[d1] = { addr: buf, len: 512, flags: NEXT | WRITE, next: d2 }
    desc[d2] = { addr: s,   len: 1,   flags: WRITE,        next: 0  }
    post(q, d0)
    wait_for_completion(d0)                          # polled or interrupt-driven
    return status_byte(s) == 0
```

### 2.6.8 The polled driver, two ways

The two loops side by side, the RK11 of section 2.1 and the same job as virtio-blk:

```
RK11 (the PDP-11 way)                         virtio-blk (the virtio way)
-------------------------------------------   -----------------------------------------------
write RKDA, RKBA, RKWC                        build 3 descriptors in memory (blk_read above)
write RKCS = READ | GO                        post(q, head)           # one doorbell write
while (RKCS & READY) == 0 : spin              while last_used == used.idx : spin   # reads memory
if RKCS & ERROR : read RKER, reset            status = the byte the device wrote in d2
one command in flight                         up to `size` commands in flight
the registers are this device's               the structures are every device's
```

The polling loop differs only in what it reads: a word of memory, the used index, where the RK11 loop reads a register. The read is an ordinary load as the page's memory type says, not a transaction on the device's link.

### 2.6.9 Suppressing notifications and interrupts

Doorbells and interrupts cost time on both sides, so each side can ask the other to stay quiet. Both flags are in the rings' `flags` fields and both are **hints** (a request the other side may, for a short time, not honour; the driver must work either way). The device sets `VRING_USED_F_NO_NOTIFY` (bit 0 of `used.flags`) to say "do not ring the doorbell; I am looking at the available ring anyway". The driver sets `VRING_AVAIL_F_NO_INTERRUPT` (bit 0 of `avail.flags`) to say "do not interrupt; I am polling". A finer scheme exists when feature bit 29 (`VIRTIO_RING_F_EVENT_IDX`) is agreed: each side writes into an extra 16-bit word at the end of its ring the **index** at which it wants to be woken, and the other side then rings or interrupts only when it crosses that number (`virtio_ring.h`: the driver "publishes the used index for which it expects an interrupt at the end of the avail ring"; the host "publishes the avail index for which it expects a kick at the end of the used ring"). Whether the pdp64 uses it is not decided (2.13). A driver may mask a device's interrupts and poll the used ring (2.7.4).

## 2.7 Interrupts that are writes: MSI and MSI-X

On the Unibus an interrupt was a signal: a BR line went up, the processor granted the bus, and the device put its vector on the data lines. A PCI Express link has no such lines to raise. The first answer, kept for old devices, was four shared **interrupt pins** per slot (`INTA` to `INTD`; the header's **interrupt line** and **interrupt pin** bytes at 0x3C and 0x3D describe them, and bit 10 of the command register turns the function's pin off), which several devices share, so that the handler must ask each in turn whether it was the one. PCI Express emulates the pins with messages for old software (*unverified*); the pdp64 does not use them for its standard devices.

The answer for new devices is that **an interrupt is a memory write**. A function that wants attention does not raise a signal; it performs a write, of a value the system chose, to an address the system chose, and the part of the machine that owns that address (the **interrupt controller**: the unit that decides which core runs which handler) takes the arrival of the write as the interrupt. **MSI** (message-signalled interrupts, capability identifier 0x05) gives a function one address and one data value; how it varies the data to give several interrupts is *unverified*. **MSI-X** (capability 0x11, the "extended" form, and the one the pdp64's virtio devices use, errata 95 and 5.7.1) gives a function a **table** (an array in one of its windows) of entries, up to 2048 of them (the table-size field is 11 bits, `PCI_MSIX_FLAGS_QSIZE` 0x07FF), each with a separate address and data, so that every queue of every device can have an interrupt of its own, aimed at a core of its own.

![An MSI-X table entry](figures/bus-msix.svg)

The capability record (`pci_regs.h`, offsets from the record's start) is: the identifier and next byte; a 16-bit **message control** at 2, whose bit 15 enables MSI-X, bit 14 masks every vector of the function and bits 10:0 hold the table size minus one; a 32-bit word at 4 whose low three bits say which BAR holds the table (the **BIR**, BAR indicator register) and the rest an offset in it; and a 32-bit word at 8 of the same form for the **PBA**, the **pending-bit array** (one bit per vector, set by the function when it wanted to interrupt and could not because the entry was masked). An entry is 16 bytes: the message address, low half at 0 and high half at 4; the message data at 8; and at 12 the **vector control**, whose bit 0 is the **mask** (while it is set the function sends nothing for that vector and records the wish in the PBA).

```
enable_msix(fn, nvec):
    cap  = find_capability(fn, 0x11)
    ctrl = cfg_read16(fn, cap + 2)
    table_bar    = cfg_read32(fn, cap + 4) & 7
    table_offset = cfg_read32(fn, cap + 4) & ~7
    table = bar_base(fn, table_bar) + table_offset
    cfg_write16(fn, cap + 2, ctrl | 0x8000 | 0x4000)     # enable, but mask every vector for now
    for v in 0 .. nvec - 1:
        entry = table + 16 * v
        (addr, data) = interrupt_controller_allocate(core_for(v), handler_for(v))
        mmio_write32(entry + 0,  addr & 0xFFFFFFFF)
        mmio_write32(entry + 4,  addr >> 32)
        mmio_write32(entry + 8,  data)
        mmio_write32(entry + 12, 0)                      # unmask this vector
    cfg_write16(fn, cap + 2, (ctrl | 0x8000) & ~0x4000)  # lift the function-wide mask

# in virtio, each queue is told its vector, and the device-wide changes have one too:
write16(msix_config, 0);  write16(queue_msix_vector, 1)    # 0xFFFF means no vector
```

When the device raises vector *v*, it sends a write of `data[v]` to `address[v]`, if the entry is not masked; a handler then learns what happened by reading the used ring (2.6.7) and, for the device as a whole, the interrupt-status structure of the virtio capabilities (type 3, section 2.6.2). On the Unibus there were four levels and the RK11's vector was `0220` at level 5, so a handler for a level shared with other devices had to find out which had spoken; here there is a vector for each queue, assigned by software, and no wire.

**2.7.1** A device interrupts by a message-signalled write (MSI-X): the configuration change and each queue have a vector that the driver sets in the common configuration, and the interrupt status structure says why. *(P)* (This is 5.7.1.)

**2.7.2** The write that raises an interrupt cannot overtake the data writes that precede it on the same path, so a handler that runs because of the interrupt finds the data in memory (2.5.4). *(D)*

**2.7.3** Which unit of the processor receives the writes, how a core is chosen, how a vector number reaches a handler and how the interrupt controller is programmed (the address and data that `interrupt_controller_allocate` returns above) are not specified. *(S)* This is the interrupt-controller decision R1 of appendix B; the pseudocode shows the shape that any choice has.

**2.7.4** A driver may mask a device's interrupts and poll the used ring instead (2.6.9, 5.7.2). *(D)*

*Commentary.* **Chain.** PDP-11: four BR levels and switch-set vectors, a scarce shared resource (`pdp/scb.s`). PCI: four shared interrupt pins per slot, described by the header bytes at 0x3C and 0x3D (`pci_regs.h`). PCI Express adds MSI and MSI-X, an interrupt as a write (`pci_regs.h`, QEMU `hw/pci/msix.c`). virtio gives each queue its own vector. The pdp64 uses MSI-X for its standard devices. **Trade-off.** A message carries its own vector, so no switch and no assignment table are needed and there can be thousands; the interrupt controller must be an address that many devices write, and a confused device that writes to the wrong address causes an interrupt (the IOMMU of 2.11 can refuse a write to an address that is not allowed). That the x86 local APIC and the ARM GIC's translation service receive such writes is *unverified*. **Impact.** An interrupt routine reads the used ring and the status structure; the table is programmed once at attach; the hardware needs an MSI-X target in the interrupt controller.

## 2.8 What the processor owes the bus

**2.8.1** The processor owes the bus exactly three things: a memory type per page, a `FENCE` instruction whose meaning against Q64 is defined, and atomics that can reach device memory. *(D)*

**2.8.2** A driver can be sure a descriptor is visible before it notifies the device: it builds the descriptor and publishes it in the queue, executes `FENCE`, and writes the queue's notification address (the doorbell). *(D)*

*Commentary.* **Chain.** The RK11 driver of 2.1 contains no ordering step; its writes reach the device in program order over one bus (*unverified* for models with a cache). PCI Express posts writes, and the driver must order them (2.2); multi-core machines add the same need between cores. ARM's `DMB`/`DSB` and device-memory types, and RISC-V's `FENCE` with I/O bits, play the same part (*unverified*). The pdp64's contract has three items: a memory type per page, a `FENCE` whose meaning against Q64 is defined, and atomics that reach device memory. A virtio device is written against the virtio specification and these three promises alone, without knowing the processor's pipeline. **Impact.** One `FENCE` before the doorbell is the whole ordering rule; `FENCE` is a compiler intrinsic; the memory type is two bits per page-table entry (6.7.1) and the bus honours it.

## 2.9 When an access fails

**2.9.1** A read or instruction fetch of non-existent memory is a precise abort with cause `BUSFAULT`, at the faulting instruction. *(D)*

**2.9.2** A posted write that times out, and an uncorrectable memory error, are machine checks: imprecise and not restartable. A `FENCE` before a probe makes even a posted write precise at a known point. *(D)*

**2.9.3** `PROBER` and `PROBEW` test whether an address can be read or written without faulting. *(D)*

**2.9.4** Resetting the bus is a write to a register of the root complex, not an instruction. *(D)*

*Commentary.* **Chain.** On the PDP-11 a read of a missing address takes the bus-error trap through vector 4 (`T_BUSFLT`, `pdp/scb.s`), which the kernel could not restart; V7's `nofault` idiom (`m40.s`: set `nofault`, touch the address, clear it) existed to probe for devices without dying. The pdp64 makes the read timeout a precise, restartable abort, and `PROBER` and `PROBEW` do what the idiom did; a driver handles a missing device in a few lines of ordinary fault handling. x86 machine checks and ARM's `SError` correspond to the imprecise class, and PCI returns all ones for a read of a removed device (both *unverified*), which every driver must learn to distrust; the pdp64 avoids that for removal (2.4.5), and returns all ones only for an empty configuration position (2.4.9). **Impact.** A timeout counter in the bridge and a way to make a read abort precise.

## 2.10 Atomics on the bus

**2.10.1** The atomics are defined on a monitor: a load-linked takes a reservation, a write by any initiator clears it, and a store-conditional succeeds only if it is intact; the Unibus's `DATIP`/`DATO` locked pair is not an architectural primitive. *(D)*

**2.10.2** A device that writes memory shared with a core takes part by clearing reservations. *(D)*

*Commentary.* **Chain.** PDP-11: the locked read-modify-write `DATIP`/`DATO` (*unverified* here; `decisions-pending.md` records it). VAX: interlocked instructions (`BBSSI`, `BBCCI`, `ADAWI`, `INSQHI`, checked in `decisions-pending.md` against the VAX-11 Architecture Reference Manual). Both lock; a lock is simple and a bottleneck as cores multiply. RISC-V `LR`/`SC` and AArch64 exclusive loads and stores use a monitor, which maps onto AXI exclusive access, at the cost of forward-progress rules (*unverified* here). The pdp64 chose the monitor (errata 45). **Impact.** Lock words and lock-free structures use the atomics of chapter 7; C11 atomics lower to them; the hardware needs a reservation monitor and an exclusive access, not a bus lock.

## 2.11 The IOMMU: a page table for each device

A device that is a bus master (section 2.5) can write wherever its packets say, and a descriptor is only an address the driver gave it. If the driver is wrong, or the device is, or the device has been modified by an attacker, that address can be the kernel's. The chain: on the PDP-11 the map registers of 2.1 (`UBMAP` at `0170200`) existed so that an 18-bit address could reach more memory, and as a side effect limited what a device could reach; the VAX Unibus adapter kept them (`ubareg.h`). The **IOMMU** (input-output memory management unit: a translator between the device's addresses and memory's addresses, with a page table of its own for each device, as the processor's MMU has for each program) makes the limit the purpose. A device is given **device addresses** (also called I/O virtual addresses) in its descriptors; the IOMMU walks that device's table to turn each into a physical address, and refuses the access if the table has no entry or the entry forbids that kind of access. The table is per device (the unit is a **domain**: a set of mappings that one or more devices share), so a network card can reach its buffers and nothing else.

*Decided.* An IOMMU is part of the design (errata 75). The five recommendations of the synthesis in `decisions-pending.md` (F25) are accepted (errata 85): translation is on by default; each device is its own domain; descriptors contain no kernel pointers; the mappings of the rings, which stay put for the life of the queue, are permanent; and a small buffer is **bounced** (copied into a buffer mapped for the device, so the device cannot reach the page that holds other data). The IOMMU's leaf entry shares bits 0 to 39 with the processor's page-table entry, and bits 40 to 63 are free (errata 85). *Open.* The format of the device table, where the unit sits in the machine, how a fault is reported and virtualization (section 2.13). Until the unit exists, a device addresses all of memory and a user-space driver can direct its device to write anywhere (5.4.2, 5.8.2).

With no address bit that says "device" (errata 97), another device's window is an ordinary address, so the IOMMU also refuses a device's DMA into another device's window (2.3.6). In virtio the feature bit `VIRTIO_F_ACCESS_PLATFORM` (33) states that the addresses in a device's descriptors are subject to the platform's translation; a driver on a machine with an IOMMU must have agreed it (2.6.3, 2.13).

## 2.12 What was checked, and what was not

The specifications of PCI Express and virtio are not on this machine. What the facts rest on:

* **Linux headers** (`/usr/include/linux/pci_regs.h`, `virtio_pci.h`, `virtio_config.h`, `virtio_ring.h`, `virtio_blk.h`, `virtio_ids.h`): configuration-space header offsets and the command, status and header-type bits; base-address register fields and the all-ones sizing rule; capability-list fields; the MSI-X record, table entry, mask and size fields; link speed and width codes; the virtio vendor-specific capability layout and `cfg_type` values; the common configuration field order (offsets computed from it); status bits; feature bits 28, 29, 32, 33 and 36; the descriptor, available ring and used ring, their flags and alignments; the virtio-blk header, request types and status values; the device types.
* **QEMU sources** (`/home/david/claude/qemu-src`): vendor ID 0x1AF4 and device-ID base 0x1040; the ECAM shifts (`pcie_host.h`); the doorbell decoding (`virtio_pci_notify_write`); MSI-X entry layout and mask handling; the BAR sizing mask; the tree vocabulary of `docs/pcie.txt`.
* **2.11BSD** (`/home/david/claude/facetlang/unixtree/2.11BSD/sys`): the RK11 register structure and bits (`pdpuba/rkreg.h`), `rkstart` (`pdpuba/rk.c`), `rkprobe` (`autoconfig/rkauto.c`), the RK11 at `0177400` (`pdpstand/rk.c`), its vector `0220` at level 5 and vector 4 as the bus error (`pdp/scb.s`), `br4` to `br7`, the UNIBUS map and `mapalloc` (`h/uba.h`, `pdp/machdep.c`), and the console at `0177560` (`pdp/cons.c`).
* **4.3BSD** (`unixtree/4.3BSD/usr/src/sys`): `nexus.h` (`NEX780`, `NEXSIZE`, the nexus types), `autoconf.c` (`probenexi`, `unifind`, `badaddr`), `ubareg.h` (`UMEM780`, `UBA_PURGE780`), `if_de.c` (the DEUNA ring ownership flags). V7 `m40.s` for `nofault`.
* **Unverified** (general knowledge): the 18-bit width and the 8 KB extent of the I/O page (consistent with the addresses above, not stated in a source); `MSYN`/`SSYN`, NPR priority above interrupts and the grant chain; the locked `DATIP`/`DATO` as hardware; lane counts beyond x8; the kinds of TLP, posting and completions; the negotiation of width and speed; the dates and lineage of PCI and PCI Express; that an empty configuration position reads all ones on real hardware; PCI Express emulation of the interrupt pins; the way MSI varies its data; that writing 0 to `device_status` resets; the value the specification asks to be written to a doorbell (QEMU ignores it); that the specification asks for a barrier between publishing the available index and reading the used flags; the older virtio numbering; the Q-bus; PCI Express hot-plug signalling; Amiga AutoConfig, NuBus, Thunderbolt; the cache behaviour of PDP-11 models; the architectures named in the commentaries as "modern comparables".
* **Decided** by the author and recorded in `errata.md`: every statement tagged *(D)*; nothing else in this chapter is a decision.

## 2.13 Still open

The bus chapter's open items, each with options in the decisions document: the interrupt controller and routing, and so how the address and data of an MSI-X entry are made (R1, 2.7.3); starting the other cores and inter-processor interrupts (R2, B2); coherence beyond four cores (R3); the detail of the IOMMU (its five recommendations are accepted, errata 85; the format of its table, where it sits and how it reports a fault are open); errors raised by devices (R7); virtualization (R8); where the configuration space and the windows sit in the physical address space and how wide that address is (how software finds the width: no register is defined); how many pages "the first few" are; the exact feature subset of each virtio device, and whether the pdp64 uses the `EVENT_IDX` feature (2.6.9) and declares `ACCESS_PLATFORM` and `ORDER_PLATFORM` (2.6.3); and where the root complex's status register that records such a miss sits (2.4.10).
