<a id="j21"></a>
### J.2.1 Locating devices without a selecting bit

**Issue.** On the Unibus, an address whose top bits were all ones meant "a device register", so every driver knew where its device was. The pdp64 has no such bit (errata 97, 102): a device window is an ordinary range of physical addresses, and the physical address is at least 40 and at most 64 bits wide. Software must therefore learn from somewhere where each window is, and something must choose where it goes. There are three ways to do it: **enumeration** (the processor reads a small self-description from every device and assigns each one a window), a **table handed over at boot** (the first stage tells the kernel what is where), or **fixed addresses** written into the architecture. The manual's text assumes enumeration through the root complex (the chip at the top of the bus tree, which turns the processor's accesses into bus transactions) and says only that the address of the root complex arrives in the boot-information block.

**Why it matters.** The kernel cannot attach a driver before it knows a base address. With no address bit to mark a device page, the memory type of a mapping is the only marker of what a page is. The root complex must decode exactly the windows that were assigned, and must refuse a device's DMA (direct memory access: a device reading or writing memory by itself) into another device's window; the IOMMU (a unit that translates the addresses a device uses, so that a device can only reach the memory it was given) needs the same map to do that. The statement that says where the configuration space and the windows sit is unspecified.

**Options.**

1. *PCI Express enumeration, with the root complex address and a window pool in the boot-information block.* The kernel assigns each function's base-address registers (the registers by which a device states the size of a window it wants and is told where it sits) from a range of addresses that the block gives it. For: one mechanism for everything on the bus; only two numbers are passed (the base of the configuration space and the window pool); the platform may move them freely, so the architecture fixes nothing; drivers learn their base from the device. Against: the kernel must trust the pool, and a pool that overlaps RAM can be detected only by comparing ranges; the console needs a separate base before enumeration has run.
2. *A device table in the boot-information block* (kind, base, size, interrupt for each device), with no enumeration for the platform's own devices. For: suits devices that are not on PCI Express at all; needs no walk of the bus. Against: duplicates what enumeration finds, so there are two mechanisms; a device that arrives later is not in the table.
3. *A fixed platform map written in the architecture:* the root complex and a window range at fixed addresses. For: no table to trust and no problem early in boot; very simple for a small board. Against: it fixes an address below 2^40, the smallest width, and so brings back the habit of the upper half of the address space that the author dropped; a wider machine cannot put its windows high; the VAX shows that a fixed map is changed from model to model.
4. *Top-down placement:* the root-complex window ends at the top of the implemented physical address space, so it moves with the width the processor reports. For: never collides with RAM, which grows up from zero; one rule for 40 and for 64 bits. Against: depends on the width being discoverable (an open question of its own); a program that assumes a width computes a wrong address; memory sizes near the top collide with it.
5. *An address-map list handed over at boot,* each range typed as RAM, device or reserved, with the memory type of a page as the only runtime marker. For: one place says what every range is; a window can sit anywhere; the kernel can refuse to map RAM as a device and the reverse. Against: the list can be wrong; a wrong memory type on a device page is no longer caught by hardware, as the old address bit caught it; more kernel code.
6. *A self-describing window-map register block at one fixed low address,* just above the first pages, through which everything else is found. For: only one address is architectural, and it is in the reserved boot area; no block is needed. Against: a new device and a new fixed address; the reservation of the first pages must cover its page.

**Precedents.** The RISC-V virt board of QEMU gives the configuration space at 0x30000000 and the PCI Express windows at 0x40000000 and describes them to the kernel *(verified: QEMU hw/riscv/virt.c)*. The x86 ACPI table that names the configuration-space base *(unverified: general knowledge)*. The VAX had the Interconnect (the bus of the VAX-11/780) and a table that its adapter slots filled; its I/O space began at 0x20000000 with one 8 KB window per adapter slot, changing from model to model *(verified: the 4.3BSD `nexus.h` read for chapter 2)*. The PDP-11 I/O page at the top of the 16-bit space, and the extended spaces of the later models *(verified for the 16-bit page; the 18- and 22-bit extensions unverified)*. The VAX RPB and the Alpha HWRPB (restart and hardware parameter blocks that hand a device table to the operating system) and device trees on ARM and RISC-V *(unverified: general knowledge)*. The x86 PCI hole just under 4 GB and the BIOS E820 and UEFI memory maps *(unverified: general knowledge)*. The VAX nexus status registers describe each slot *(verified: the 4.3BSD `probenexi` read for chapter 2)*.

**The author's referents.** USB, enumerated over a PCI Express bus ("arbitrary buses ... can be connected to it and enumerated"); virtio "across the board"; the VAX's I/O space ("it should be noted in the book how the vax does this io space idea"); "mmio allows larger windows as needed"; and, of the old address bit, "if we are going to mmap petabytes, we need those bits".

**The assistant's leaning.** Option 1, with the memory type of the page as the safety check and a kernel rule that a device mapping is made only on an enumerated window. It is the text the manual already has, it adds no table and it works from 40 to 64 bits. It would change if the author wants platform devices without PCI Express (a timer, a console, an interrupt controller); then Option 2's table is added for those alone.

**Where the body refers to it.** Sections 2.2 and 2.4.6.

<a id="j22"></a>
### J.2.2 The bus controller

**Issue.** An early decision (errata 49) made the bus a device in its own right, with registers by which the processor could detect what is on it, ask it to map a device to a given address range, and be alerted when a device enters or leaves. The register interface was later dropped (errata 95), but the three jobs were kept: the bus **enumerates** (lists what is on it), **maps** (assigns each device a window) and **alerts** (tells the processor of arrivals and departures). Under PCI Express the three jobs already have standard mechanisms: enumeration by reading each function's configuration space through the root complex; mapping by sizing and assigning the base-address registers; alerts by the hot-plug events of the slot and the root complex's own interrupt. The question is which jobs standard PCI Express and virtio already do, which need a piece of the pdp64's own, and what, if anything, the "bus controller" now is.

**Why it matters.** The kernel needs one recursive walk of the bus (section 2.4.3) and one routine to recover from a departure; the mature PCI code of OpenBSD can be reused only if the machine presents a standard PCI Express bus. For the hardware, a root complex is a large block, and the first boards (the Cyclone V and the Zynq 7020) have no hard one, while a Zynq UltraScale+ has; a native controller would be a small custom block. The alert is decided (2.4.4, errata 49); the queued work of a departed device staying in memory is decided (2.4.5, the author's suggestion of 2026-10-22), its mechanism is not, and the precise fault for a departed device (2.4.5, appendix H.2) is a proposal, and where the configuration space and the windows sit (2.4.8) is open (J.2.1).

**Options.**

1. *Pure PCI Express.* The root complex is the bus controller; there is no pdp64 device; enumeration, window assignment, hot-plug and error reporting are the standard ones (configuration space, slot status, message-signalled interrupts, advanced error reporting); the pdp64's own rules live in how the processor treats the root complex. For: the least new design; compatible with every card; OpenBSD already enumerates PCI Express. Against: needs a root complex the cheap boards lack; the notorious configuration difficulties of PCI (about thirty boot options in the BSD and Linux kernels for bus numbers and window assignment; guessed window sizes for hot-plugged devices) come with it; a removed device reads as all ones, the opposite of the precise fault of 2.4.5, which would need extra circuitry anyway.
2. *PCI Express plus a small pdp64 root-complex function* (the shape of the proposals of appendix H.2). Enumeration and hot-plug are standard; the root complex adds a few processor-side registers and rules: a bus reset write, the departure alert, the precise bus fault and drop-and-count for a departed window, and a reset that produces no removal events. These stay invisible to cards. For: it keeps the three verbs of errata 49 and gives them to standard mechanisms; departure is detected and recoverable. Against: still needs the root complex; the extras are proposals whose detail is not specified; the precise-fault rule needs presence tracked per function, which standard PCI Express provides only for hot-plug slots.
3. *virtio-mmio devices behind a native bus controller* (errata 49 as written, with virtio devices). The controller is a small memory-mapped device with a table of present devices (type, base, size, interrupt) and an alert register; each device is a virtio-mmio transport (virtio's form for machines without PCI) in a window the controller assigned. For: no root complex, so the first boards work; it gives errata 49 exactly. Against: gives up compatibility with PCI Express and the plan to attach USB as a PCI Express function; a real card (a network adapter, a graphics card, NVMe, a USB controller) cannot be attached; the drivers carry two transports; it reverses decisions of 2026-11-03.
4. *A soft host-bridge facade.* The processor always sees a configuration space and virtio-PCI functions; on the FPGA, a small block in the fabric presents simple devices as PCI functions with no PCI Express link; on silicon, a real root complex. For: software sees one bus on every board; no hard block is needed on the first boards. Against: custom logic that must emulate enough configuration space for the kernel's PCI code to accept it, so a fault in it looks like a driver fault; no real card on that board; one more block to test.
5. *A static description for the fixed machine; hot-plug only for USB.* The boot-information block or a small device tree lists the root complex and every fixed device; the kernel enumerates once at boot; only the USB host controller reports arrivals and departures; PCI Express slot hot-plug is software only (the fault and event rules, no slot hardware) until a board has slots. For: fewest moving parts; the bus controller becomes boot data. Against: no live add or remove of anything but USB; a device tree is another artefact the boot ROM must carry and keep in step with the hardware; statement 2.4.4 would shrink to USB. It is compatible with Option 1 or 2 underneath.

**Precedents.** On x86, ARM and RISC-V servers the configuration space is reached through a memory-mapped window (ECAM, the enhanced configuration access mechanism) and hot-plug uses the slot capability and its interrupt *(unverified: general knowledge)*. PCI sizes a window by writing all ones to the base register and reading back *(not confirmed in the project's own sources)*. The VAX scanned its interconnect through an adapter on the nexus: `probenexi()` reads each slot's status register, and the UNIBUS adapter's own registers hold the map registers *(verified: the 4.3BSD sources `vaxuba/ubareg.h` and `vax/autoconf.c`, read for chapter 2)*. Amiga AutoConfig, in which each board announces itself and is told where to live *(unverified: general knowledge)*. virtio-mmio is what QEMU's virt and microVM machines use where PCI is absent *(unverified: general knowledge)*. ARM and RISC-V boards describe fixed devices in a device tree and enumerate only PCI below the root port *(unverified: general knowledge)*. A PCI-compatible host bridge in an FPGA with no transceiver is a configuration-space emulator of some hundreds of registers *(unverified: no specific design found)*.

**The author's referents.** The first idea, in his words: "the bus itself is another device with its own set of mmap registers so we can detect what is on it and request it to map a device to a particular address range, we do need some way for the bus to alert us when a device enters or leaves the bus"; the eight registers were later rejected ("forget the native 8 register devices. gone."). USB enumerated over a PCI Express bus; "we're going with pcie and nvme and usb"; and "didn't we talk about hot swap?".

**The assistant's leaning.** Option 2 as written, with Option 5's limit on hot-plug (USB live; PCI Express in software only), and two things put to the author: where the configuration space and the windows sit (for example a fixed base outside the first few pages), and a short table of the controller's registers (reset, departure alert, presence). It delivers the three verbs with standard mechanisms and costs a few registers beyond PCI Express. It would change if the first board has no PCI Express block and no budget for a soft core (then Option 4 or 3), or if the departure fault turns out not to be buildable on root-port hardware (then a presence register per function).

**Where the body refers to it.** Section 2.4.4.

<a id="j23"></a>
### J.2.3 The IOMMU: table format, place, faults and virtualization

**Issue.** The author has decided that the pdp64 has an IOMMU (a unit that translates the addresses a device uses, with a page table of its own for each device) and accepted five rules for it (errata 75, 85): translation on by default, one domain for each device, no kernel pointers in descriptors, permanent mappings for the rings, bounce buffers for small data. The leaf entry shares bits 0 to 39 with the processor's page-table entry and bits 40 to 63 are free (errata 85). Four things are not decided: the format of the table above the leaf (how many levels, how a device is found from the identity the bus gives it), where the unit sits (in the root complex, in each bridge, or beside the memory controller), how a refused access is reported (to the device, to the kernel, or both), and what happens when a guest operating system runs its own devices (virtualization, R8 of appendix B).

**Why it matters.** The kernel's mapping routines, the driver interface (a descriptor holds a device address, not a physical address) and the interrupt controller (J.6.3, which may use the same unit to check where a device's interrupt write goes) all depend on it. A unit placed at the root complex sees every device but cannot tell a device behind a bridge from the bridge; a refused write that is silently dropped is hard to debug, one that stops the machine is easy to attack.

**Options.**

1. *A device table indexed by the bus-device-function number, one page table for each entry.* For: the shape PCI Express already identifies devices with; each device its own domain falls out. Against: a large sparse table unless it is indexed in levels; functions behind a bridge may share one identity.
2. *A small table of domains, with the device-to-domain map in a register file in the root complex.* For: cheap in hardware; fits the first FPGA boards. Against: a fixed number of devices; a hot-plugged device may find the table full.
3. *Same, with a second-level table, so a guest's mapping is composed with the host's* (nested translation). For: virtualization costs no emulation. Against: two walks for every access; a larger unit.
4. *Report a fault only to the kernel, as an interrupt with a log entry* (device, address, kind), the device's access being refused or dropped. For: one path. Against: a device waiting for a read completion hangs unless the unit completes it with an error.
5. *Report a fault to the device as a failed completion and also log it.* For: the device's driver sees an error at once. Against: not every device handles it; the log can overflow under attack.

**Precedents.** x86 has the IOMMU of Intel (VT-d) and of AMD, indexed by bus, device and function, with a fault-recording ring and an interrupt *(unverified: general knowledge)*. ARM has the SMMU with stream identifiers and stage 1 and stage 2 translation *(unverified)*. The VAX Unibus adapter's map registers were per adapter, not per device *(verified: 4.3BSD `ubareg.h`)*.

**The author's referents.** "iommu will allow us to map in c64/c128" (errata 75, a later use); the five accepted recommendations (errata 85).

**The assistant's leaning.** Option 1 with a two-level device table, and Option 5 (an error completion and a log entry), because both keep the same code for boot and for a hot-added device. It would change if virtualization is wanted early (then Option 3).

**Where the body refers to it.** Section 2.11.

<a id="j24"></a>
### J.2.4 Which optional virtio features the pdp64 uses

**Issue.** virtio lets each side agree optional features by bit. Three concern the machine and not one device. `VIRTIO_RING_F_EVENT_IDX` (bit 29) replaces the two on-off flags with an index at which a side wants to be woken. `VIRTIO_F_ACCESS_PLATFORM` (bit 33) says that a device's addresses go through the platform's translation (the IOMMU). `VIRTIO_F_ORDER_PLATFORM` (bit 36) says that the device obeys the platform's ordering rules and not weaker ones. The exact feature subset of each standard device is a fourth, per-device item, set when each device is written.

**Why it matters.** A driver on a machine with an IOMMU that does not agree `ACCESS_PLATFORM` leaves the device on physical addresses and defeats the unit; a device that is not told to order its writes may let an interrupt overtake data (2.5.4). `EVENT_IDX` changes the notification test in every driver.

**Options.**

1. *Require `ACCESS_PLATFORM` and `ORDER_PLATFORM` of every device and refuse the device without them.* For: the IOMMU and the ordering rule hold for every device. Against: some emulators and old devices do not offer them.
2. *Require them on the physical machine, accept their absence under an emulator with a warning.* For: runs on QEMU as is. Against: two behaviours; the secure case is not the tested one.
3. *Do not use `EVENT_IDX`: the two flags only.* For: smaller driver, nothing to get wrong. Against: more doorbells and interrupts under load.
4. *Use `EVENT_IDX` when the device offers it.* For: fewer notifications. Against: more code and a corner case at index wrap; the polled mode needs no help from it.
5. *Declare nothing beyond `VERSION_1`, and treat translation and ordering as properties of the platform, not negotiated.* For: fewest bits. Against: a driver cannot tell that a device honours them.

**Precedents.** Linux negotiates `ACCESS_PLATFORM` and refuses translation-less operation on a platform that needs it, and uses `EVENT_IDX` when offered *(unverified: general knowledge)*. The bit numbers are in the Linux headers `virtio_config.h` and `virtio_ring.h` *(verified)*.

**The author's referents.** "virtio across the board" (errata 95).

**The assistant's leaning.** Option 1 for the first two, and Option 3 until a measurement shows a need for `EVENT_IDX`.

**Where the body refers to it.** Section 2.7.

<a id="j25"></a>
### J.2.5 The root complex's own registers and the pdp64's additions

**Issue.** Three decided rules name a register of the root complex and give no place for it: a bus reset is a write to a register (2.9.4), a read of an empty configuration position is recorded in a sticky, write-one-to-clear bit of its status register (2.4.8, errata 104), and the circuitry that the pdp64 adds to PCI Express for convenience and security is mentioned without detail (2.3.4). A fourth, where the root complex itself sits, is J.2.1. The author asked that the miss be recorded in a status register and mode flags that already exist and not in new state, and agreed to the root complex's own bit; the processor status word was ruled out because it belongs to the running thread.

**Why it matters.** The kernel cannot reset the bus, or tell a dead link from an empty slot, without an address; and a block of registers is the natural home for the later additions.

**Options.**

1. *A register block at a fixed offset from the configuration-space base.* For: one address (the base) is passed; nothing new to discover. Against: shares the address range of the functions, and an enumeration walk must skip it.
2. *A PCI Express function on bus 0 whose windows hold the registers.* For: found by enumeration like everything else; no fixed address. Against: the function needs a driver, and the reset is then a write to a device that the reset itself disturbs.
3. *A block at an address in the boot-information block.* For: free placement. Against: one more field to hand over.
4. *Bits in a system register* (the numbers from 13 up are reserved). For: no address. Against: the register is per core, so the root complex's single flag lives in a per-core place; the author did not choose it.
5. *A block in the interrupt controller's page,* if J.6.3 gives that unit its own range. For: the registers of the machine's central units together. Against: ties two decisions together.

**Precedents.** The x86 root complex registers (root control, root status) are in the configuration space of the root port *(unverified: general knowledge)*. The VAX adapter's registers (configuration and status) sit in its nexus window *(verified: 4.3BSD `ubareg.h`)*.

**The author's referents.** "don't we already have a status register and mode flags, can't you use a bit in one of those or add a bit?"; "agree root complex bit" (errata 104).

**The assistant's leaning.** Option 1 or 3: pass the base once in the boot-information block and place the block at a fixed offset from it.

**Where the body refers to it.** Sections 2.3.4, 2.4.8 and 2.9.4.
