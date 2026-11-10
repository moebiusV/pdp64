<a id="j41"></a>
### J.4.1 The first few pages

**Issue.** The author's rule (errata 102) is that device windows can go anywhere in physical space "except the first few pages where the boot stuff is loaded". How many pages are "the first few", and what exactly lives in them, is not fixed. The rule is a **reservation**: a range of physical addresses that no device window may overlap, so that the boot ROM and the first stage can assume plain memory there. What the documents already put in that range: the vector table (the table through which an exception or an interrupt finds its handler: 512 entries of 8 bytes, exactly one page of 4096 bytes at address 0, because the register `VBR` is zero at reset); block 0 (512 bytes), read to an address "to be chosen" (0x1000 is the example, which is why the load address is part of this entry); the boot-information block, whose size is not specified and which lists the memory ranges, boot device, console, core count, device table, command line, ABI version and a checksum; and the top of the first 64 KB, which register `r14` holds as the first stack.

**Why it matters.** Before translation is on, the kernel needs a known place for the vector table, the boot-information block and the early stack. The root complex must refuse to decode a window below the limit, and the boot ROM's load address and the reset value of `VBR` are tied to it. Section 4.4 and the boot sequence cannot quote an address until it is chosen.

**Options.**

1. *Two pages (8 KB).* Page 0 is the vector table; page 1 holds block 0 at 0x1000 with the boot-information block after it. For: the smallest reservation that holds what is already named; a window can start at 0x2000; the decoder compares against one constant. Against: block 0, a block of a few hundred bytes and a stack can overflow 8 KB when the device table grows; moving the limit later breaks every board that placed a window at 0x2000.
2. *64 KB (sixteen pages), matching the rule for `r14`.* Everything below the top of the first 64 KB is boot territory. For: reuses a number the reset state already defines, so the reservation, the initial stack and the load area agree; room for the vectors, block 0, the boot-information block, a first stack and the second-stage loader; costs nothing at 40 bits or more. Against: wasted if a board's RAM does not start at 0.
3. *1 MiB (256 pages), the low megabyte of the PC.* For: room for a second-stage loader, the first segment of a kernel image, a hand-off area for a frame buffer and the pages where other cores start. Against: wastes the low megabyte of a small FPGA board with tens of megabytes; invites sloppy use; invents a number.
4. *Nothing fixed by the architecture.* The platform states the limit in the boot-information block or the root complex; the architecture says only that page 0 is never a device window. For: every board picks; one page is enough for the vector table at `VBR` 0. Against: a loader and a kernel can assume nothing about low memory and must parse the block first, though `r1` itself points into the reserved area; the documents lose a number to quote.
5. *Move the boot area to the top of physical memory,* or of the implemented space. For: address 0 becomes an unmapped page, so a null pointer used as a physical address is caught; the reservation moves with the width, so no device meets low RAM. Against: `VBR` zero at reset must change; every sentence of the reset state (`r14`, the load address of block 0) is rewritten; the top depends on the width, which is itself open.
6. *Reserve by type, not by count.* The root complex refuses windows only over ranges that the memory map in the boot-information block marks as RAM or reserved; there is no "first few pages" rule. For: "a window anywhere" becomes literally true. Against: whoever enumerates the bus needs the map before placing any window, and the same code that reads the block makes the first decisions; more code than a constant.

**Precedents.** The PDP-11 kept its trap vectors in the first octal 0 to 0377 bytes of memory, with the boot ROMs elsewhere *(unverified: general knowledge)*. The RISC-V virt board of QEMU has a debug region at 0x0, the boot ROM at 0x1000 and devices from 0x2000000, and 0x1000 is the default reset vector *(verified: QEMU hw/riscv/virt.c and target/riscv/cpu_bits.h)*. The PC reserves the first megabyte of real mode for vectors, BIOS data and the boot sector loaded at 0x7C00 *(unverified: general knowledge)*. The VAX console passes a boot block and a restart parameter block that lives in low memory *(unverified: general knowledge)*. The PDP-11 I/O page sat at the very top of its address space *(verified in the project's chapter 2 commentary of the V7 drivers)*, and x86 resets at 0xFFFFFFF0, at the top of 4 GB *(unverified: general knowledge)*. The PC BIOS E820 map and the UEFI memory map type each range *(unverified: general knowledge)*.

**The author's referents.** The PDP-11 boot ("load 512 byte block 0 then jmp 0"; "not precisely true, but directionally true"); "follow the majority as far as boot block offset"; the VAX's I/O space (memory low, I/O above; "it should be noted in the book how the vax does this io space idea"); UEFI ("is it worth it at all?", since decided against); the GPT as the disk label.

**The assistant's leaning.** Option 2, 64 KB, because the reset state already defines the first 64 KB through `r14`, so no new number is invented; the vector page and block 0 fit with room; and the cost is nothing at 40 bits. It would change if a board's RAM does not start at 0, or if the boot-information block grows beyond 8 KB (then Option 3 or 4). To decide it, the author's size for the boot-information block and for the second-stage loader would help, and whether the vector table stays at 0 after boot (`VBR` can be moved).

**Where the body refers to it.** Sections 2.3.5, 4.4.1 and 6.12.


<a id="j42"></a>
### J.4.2 How the first stage reads blocks

**Issue.** The first stage is the program in block 0, one 512-byte block, and its job is to read the next stage from the disk. The ROM has done the same job once, with a virtio-blk request: a **virtqueue** (the shared ring through which a driver hands requests to a virtio device), three descriptors (a request header, a 512-byte buffer and a one-byte status), a write to the doorbell register, and a poll until the device returns the chain. The PDP-11's first stage carried its own disk driver; the PC's called the BIOS. Which of those the pdp64's first stage does is not decided. If the block is a protective MBR, only its first 446 bytes are code, which is also the space for whatever the first stage needs to know about where the second stage lies.

**Why it matters.** The size of the first stage, what the ROM must leave behind for it, and whether the ROM offers anything after boot all follow from the answer. The ROM and the first stage cannot be written until it is settled.

**Options.**

1. *A small polled virtio-blk reader inside the first stage.* The PDP-11 way. For: no dependence on the ROM; the ROM keeps no service after it has run. Against: the reader, the list of what to read and a stack-and-queue set-up may not fit in 446 bytes; it duplicates the ROM's reader.
2. *The ROM leaves a read routine in memory and tells the first stage where it is.* For: the first stage is a few instructions. Against: it is a firmware call in miniature; the routine's address and calling convention become part of the architecture and the ROM's code can then never change.
3. *The ROM loads more than block 0*, for example the whole 8 KB boot area. For: room for a reader and for more than a list. Against: the ROM must learn a size and a place, so it is no longer "read block 0 and jump"; it conflicts with a block 0 that is the protective MBR, since the rest of the 8 KB belongs to the GPT.
4. *The ROM reads the second stage itself,* from a list in block 0 that the ROM parses. For: there is no first-stage reader at all. Against: the ROM is larger and the list format is frozen in ROM; block 0 becomes data and not a program.
5. *A simple programmed-I/O read register on the boot device or the controller,* beside virtio. For: a few instructions, no queue. Against: a second device interface that every board must implement.

**Precedents.** The V7 primary bootstrap for the RM02/3 writes the disk's registers itself *(verified: `sys/mdec/hpuboot.s`)*. OpenBSD's PC first stage calls `INT 0x13` *(verified: `biosboot.S`)*. OpenBSD's `installboot` hard-codes the block numbers of the second stage into the first stage *(verified: `installboot(8)` for the sparc, and `biosboot(8)` for the PC)*. The 4.3BSD-Tahoe VAX `raboot` is documented as working with the 750's boot ROM and reading 7.5 KB *(verified for the header; how the ROM helps it is unverified)*.

**The author's referents.** The PDP-11 boot ("load 512 byte block 0 then jmp 0"); "follow the majority as far as boot block offset"; the GPT wrapper of errata 50.

**The assistant's leaning.** Option 1 if a measured reader fits, because it needs nothing from the ROM; Option 3 if it does not. A measurement of a polled virtio-blk read in assembler for the pdp64 would decide it.

**Where the body refers to it.** Section 4.5.2.

<a id="j43"></a>
### J.4.3 How the ROM finds and maps the boot device

**Issue.** Section 2.4 says that the processor assigns the windows of the bus's devices. The ROM is the first software to run, and to read block 0 it must reach the boot device's registers and queues, which lie in a window that nobody has assigned yet. It is not stated whether the ROM assigns every window or only the boot device's, where it places them, and whether it leaves them for the kernel to keep or to change. The author's rule (errata 102) keeps windows out of the first few pages ([J.4.1](appendix-j-open.md#j41)).

**Why it matters.** The kernel's own enumeration starts from the state the ROM leaves. The root complex's reset state, the ROM's size and the boot-information block's description of the root complex all depend on it.

**Options.**

1. *The ROM enumerates the whole bus and assigns every window,* as PC firmware does. For: the kernel finds a mapped machine. Against: a long program in the ROM, the largest of the options.
2. *The ROM assigns only the boot device's window,* at a fixed address, and the kernel enumerates afresh. For: a few lines; the ROM needs one function. Against: the kernel must keep that window or move it, and the second stage must be told which.
3. *The boot device's window is decoded from reset* at an address fixed by the board, so that the ROM assigns nothing. For: no ROM code for it. Against: it makes the boot device a special case beside the rule that the processor assigns windows; the address is per board.
4. *A table in the ROM lists where the boot devices are,* per board. For: no scan. Against: a port to a new board is a new ROM; the table duplicates what the bus reports.
5. *The ROM maps, reads, then unmaps everything it assigned,* and the second stage and the kernel begin clean. For: one rule for every later stage. Against: the second stage must map the device again to read the next block, so the code is written twice.

**Precedents.** PC firmware assigns the base address registers of the devices before boot *(unverified: general knowledge)*. QEMU's RISC-V virt board places its devices at fixed addresses, and 0x1000 is its reset vector *(verified: `hw/riscv/virt.c`)*. The PDP-11's I/O page was fixed by the hardware at the top of the address space *(verified in chapter 2's commentary of the V7 drivers)*.

**The author's referents.** PCI Express enumeration (2.4); the PDP-11 and VAX I/O space.

**Where the body refers to it.** Section 4.4.1.1.

<a id="j44"></a>
### J.4.4 The boot-information block: fields, who fills them, layout

**Issue.** The kernel must be told about the machine it is on: memory ranges, the number of cores, the address of the root complex, the boot device, the console, a command line, and, when the loader has set one up, the screen (decided: 4.6.3). That the kernel is told through a boot-information block, and that the bus lists the devices (so the block need not), is decided (4.6.2, errata 109 and 49). It has been assumed that the ROM fills what it knows (memory, cores, the device) and the second stage adds the command line and the screen, and that the address of the block is passed in `r1`; none of that is decided. The details that are open: the fields, and the layout (order, field widths, a checksum, a version, a header), whether the block is generated from a grammar like the rest of the specification, and whether it is replaced or joined by a device tree are open.

**Why it matters.** The ROM, the second stage and the kernel are written against it; the generated headers and the ABI appendix cannot carry it until it is fixed.

**Options.**

1. *A fixed-layout record, with a version and a checksum, generated from a grammar.* The ROM fills the fixed part; the second stage adds the rest. For: simple to read in a few instructions; the header cannot disagree with the loader. Against: a new field means a new version.
2. *A list of tagged records (tag, length, value).* For: extends without breaking old readers; a loader adds its own. Against: a parser in the kernel, though a short one.
3. *A flattened device tree built by the ROM or the second stage.* For: OpenBSD's arm64 and riscv64 drivers attach from a device tree, so reusing them would save kernel code. Against: a parser and a second description of the devices beside bus enumeration, which already lists them.
4. *A record plus a device tree* for the devices that enumeration cannot find. For: both worlds. Against: two things to build and keep consistent.
5. *Registers only,* as on the PDP-11 and VAX. For: no structure. Against: a kernel for any pdp64 needs the memory ranges, which a few registers cannot hold.
6. *A memory map alone;* everything else by enumeration. For: the smallest. Against: the console, the core count and the command line have no place.

**Precedents.** The VAX restart parameter block and the Alpha hardware restart parameter block are fixed-layout records of the machine *(verified: 4.3BSD `vax/rpb.h`, OpenBSD `alpha/include/rpb.h`)*. UEFI passes a memory map and configuration tables for ACPI or a device tree, and OpenBSD's loaders look for both *(verified: `efiboot`)*. OpenBSD's arm64 and riscv64 kernels parse a device tree *(verified through `efiboot`'s `FDT_TABLE_GUID`)*.

**The author's referents.** UEFI ("is it worth it at all?"), since decided against; "load 512 byte block 0 then jmp 0"; errata 109: the hand-off "kept simple enough that a UEFI shim could be written".

**The assistant's leaning.** Option 1, with a version field: the bus describes its own devices, so the block only has to carry what enumeration cannot (memory, cores, root complex, boot device, console, command line, screen). It changes if the OpenBSD device-tree drivers are to be reused, which would favour Option 4.

**Where the body refers to it.** Section 4.6.2.

<a id="j45"></a>
### J.4.5 Firmware for a virtio device

**Issue.** The author decided (4.8.1; R256) that device initialisation happens behind the bus, a register write telling the device to initialise itself, and that a device may also be given values or a binary firmware image to load. What is open is how. Some devices contain a small processor and need a program, **firmware**, loaded into them before they work; a network or wireless card is the usual case. The PDP-11 had no such device. Virtio has no firmware operation of its own. A device the boot depends on (the disk, the console, the interrupt controller) cannot wait for firmware that lies on the disk it controls, so it must work from built-in logic.

**Why it matters.** Without a mechanism, such a device cannot be used, or each vendor invents one.

**Options.**

1. *A firmware request type on the device's own queue.* For: one queue, the mechanism the device already has. Against: virtio would need a new request type for each device class.
2. *A descriptor that gives the address and length of an image in memory, with a small header* (identifier, version, length, checksum) that the device checks. For: the device pulls the image by DMA; the header lets it refuse a wrong image. Against: a header format to specify.
3. *A separate small virtio device for firmware loading* that other devices consult. For: one mechanism for every device. Against: a second device, and a dependency between devices.
4. *A firmware window in the device's register space,* written by the driver. For: needs no queue. Against: programmed I/O of a whole image.
5. *No loaded firmware at all:* every device carries its program in its own flash. For: nothing to specify. Against: the device is dearer, and an update is a hardware operation.

**Precedents.** Linux `request_firmware`, OpenBSD `loadfirmware(9)` (reads from `/etc/firmware`) and NetBSD `firmload(9)` load a blob from a file at attach time *(verified: read in the trees)*. NVMe has a firmware-download command *(unverified; not found in the QEMU headers read)*. The VAX console and some adapters loaded microcode from storage *(unverified)*.

**The author's referents.** "the init protocol should mostly happen behind the bus, poke a register to tell the device 'initialize yourself' and possibly have another register populated with values or a binary firmware blob for the device to load" (R256); the `INIT` and `READY` bits of the Unibus device (errata 29); virtio's `device_status` handshake (errata 95).

**Where the body refers to it.** Section 4.8.1.

<a id="j46"></a>
### J.4.6 Starting the other cores

**Issue.** At reset only core 0 runs, and the controller chip provides the way the others are started (4.7.1; the author, R256: "we'll need a way for the controller chip to 'boot' the other chips"). The open part is the mechanism. The kernel must start the others, each with its own stack and its own identity. The mechanism is not decided: how a core is given its entry address and an argument, what registers and mode it starts with (and so whether it starts with translation off, and what `MMUCTL` it sees), which registers carry its core number and the argument (chapter 7 states one rule, `r0` only, and the first design of this chapter a second, `r0` and `r1`), and how a core that sticks is reset.

**Why it matters.** The kernel's secondary-start code, the controller's register block and the boot-information block's core count are written against it.

**Options.**

1. *A register block in the controller: write an entry address and an argument to the core's start register, and the controller releases the core into kernel mode at priority 7.* A core-reset register restarts a core that sticks. For: no trampoline and no firmware call; one write. Against: a register block with a start and a reset register for every core.
2. *The x86 way: INIT and START-UP signals through the interrupt controller.* For: a known protocol. Against: the signal carries only an address below a limit; the x86 needs a trampoline because the woken core starts in a mode ladder, which the pdp64 does not have.
3. *A firmware call* (PSCI on arm64, the SBI hart start on RISC-V). For: a standard form on two architectures. Against: it needs resident firmware after boot, which the project does not otherwise have.
4. *A spin table:* every core runs from reset and waits on a word in memory until core 0 writes an address there. For: no register block. Against: the cores run before the kernel has set up memory, and they must be told where the table is.
5. *All cores start at the same address and choose a role from their number.* For: no start protocol. Against: the first stage and the ROM's hand-off must handle every core at once.
6. *An inter-processor interrupt* from core 0 carrying the entry address. For: uses the interrupt controller already needed. Against: the interrupt controller must be programmed on the started core first, a circle.

**Precedents.** Linux counted: `smpboot.c` 1,528 lines and `arch/x86/realmode` 1,258 for x86; PSCI 124 and the spin table 127 on arm64; the SBI start 108 and the spin wait 58 on RISC-V *(verified, re-counted in Linux `7be4bc52`)*. The VAX console processor started the other processors *(unverified)*.

**The author's referents.** The PDP-11, which had one processor; "we'll need a way for the controller chip to 'boot' the other chips; do a thorough review of how all the main smp systems do it, which is best/easiest" (R256). He has not chosen among the options.

**The assistant's leaning.** Option 1: it removes the trampoline and the firmware call and recovers a stuck core by one write.

**Where the body refers to it.** Sections 4.2 and 4.7.1.

<a id="j47"></a>
### J.4.7 The order of the boot media

**Issue.** The ROM must choose a boot device when more than one is present: a disk or flash, an SD card, a serial line. Which comes first, whether a key at power-up changes it, how the chosen device is named in a register for the later stages, and whether the order is kept in non-volatile memory is not decided (F10 of `decisions-pending.md` leaves the order after the virtio-blk disk open).

**Why it matters.** A board with two disks or a removable card cannot boot predictably without it, and the ROM's device list and its use of non-volatile memory follow from it.

**Options.**

1. *A fixed order wired into the ROM:* disk or flash, then SD card, then the serial line. For: no state. Against: no way to boot from the card when a disk is present, short of removing the disk.
2. *A fixed order, changed by a key held at power-up.* For: a rescue path without storage. Against: a key input every board must offer.
3. *An order kept in non-volatile memory.* For: the user chooses. Against: the memory must exist, and a bad setting leaves a machine that does not boot, so a reset to defaults is needed.
4. *The order of the bus: the first device in enumeration order that has a valid block 0.* For: no table at all. Against: the order depends on the wiring, not on the user's intent.
5. *One boot device per board,* fixed by the board's description. For: the simplest. Against: no choice and no recovery medium.

**Precedents.** The PC BIOS keeps a boot-device order in its setup memory *(unverified)*. UEFI keeps boot variables in non-volatile memory, which its loaders read and write *(verified: `GetVariable` and `SetVariable` calls in `efiboot`)*. The DEC boot ROM cards chose the device by a console command or switch *(M9312 comment verified; the command unverified)*.

**The author's referents.** The PDP-11 ROM; no statement of his on the order was found.

**Where the body refers to it.** Section 4.4.

<a id="j48"></a>
### J.4.8 Where the second stage lies, and a dedicated boot partition

**Issue.** The first stage loads the second stage from somewhere on the disk. Three places are candidates: the 8 KB boot area at the start of the BSD partition (4.5.3), a file in the root file system, and a small partition of its own with a partition type chosen for it. The second stage holds a virtio-blk driver, a GPT reader, a label reader and a file-system reader; OpenBSD's amd64 second stage is 189 lines beside a `libsa` of 6,319 lines *(counted)*, and whether such a program fits the 7.5 KB left in the boot area is not measured.

**Why it matters.** It decides whether the disk layout needs another partition type, what the installation tool writes and where, and whether the second stage has a size limit.

**Options.**

1. *The 8 KB boot area of the BSD partition.* For: the BSD tradition (sector 0 the primary bootstrap, sectors 1 to 15 the label and a secondary bootstrap); no new partition. Against: a hard size limit of 7.5 KB, and the label occupies sector 1.
2. *A file in the root file system,* its blocks written into the first stage by `installboot`. For: no size limit. Against: the list must be rewritten whenever the file moves (`biosboot(8)` says to re-run `installboot` "as its inode may change"), and a damaged root file system stops the boot before the second stage.
3. *A dedicated boot partition with its own type.* For: a place that no file system moves; room for a larger loader. Against: another partition to create, to size and to keep, and a type to assign.
4. *The EFI system partition (FAT).* For: the same disk serves a UEFI route (4.9). Against: a FAT reader in the second stage, and a partition that the pdp64's own boot does not need.
5. *The gap between the GPT and the first partition.* For: no partition entry. Against: a tool that repartitions the disk may overwrite it.

**Precedents.** 4.3BSD-Tahoe and 2.11BSD reserve 15 sectors after block 0 for the bootstraps *(verified: `disklabel.h`)*. OpenBSD on the PC patches `biosboot` with the location of `/boot` *(verified: `biosboot(8)`)*. OpenBSD defines both the OpenBSD-type and the EFI-system partition GUIDs *(verified: `disklabel.h`)*. Other systems keep a "BIOS boot partition" for a loader *(unverified)*.

**The author's referents.** The GPT wrapper (errata 50); "follow the majority as far as boot block offset" (errata 51); the 2026-11-10 choice of block 0 with a UEFI route kept possible (errata 109).

**Where the body refers to it.** Sections 4.5.2 and 4.5.4.

<a id="j49"></a>
### J.4.9 The state core 0 starts in

**Issue.** The ROM starts core 0 at block 0 (4.4.1, decided). What core 0 holds when it starts is not decided: its mode and priority, whether translation is on, `VBR`, the user-memory guard, which registers carry the boot device and the boot-information block (4.1 says the pdp64 passes `r0` and `r1`, after the PDP-11 form), and the stack.

**Why it matters.** The first stage is written against it; it must not guess.

**Options.**

1. *Kernel mode, priority 7, translation off, `VBR` zero, guard clear; `r0` the device, `r1` the boot-information block, `r14` the top of the first 64 KB, the rest zero.* For: the first stage has a stack and every fact before it runs an instruction; the PDP-11 handed on registers the same way. Against: the top of 64 KB is a number to fix with J.4.1.
2. *As option 1 but the stack is left to the first stage.* For: no stack number. Against: 446 bytes spend instructions on it.
3. *Only the boot-information block's address in one register; everything else a documented reset state of the core.* For: fewest registers. Against: the device number moves into the block.

**Precedents.** 2.11BSD passes `r0`, `r1`, `r3` and a check word in `r2` *(verified: `pdpstand/srt0.s`, `boot.c`)*; the VAX boot passes `r1` to `r5` *(verified: `raboot.c`)*.

**The author's referents.** "load 512 byte block 0 then jmp 0".

**The assistant's leaning.** Option 1.

**Where the body refers to it.** Section 4.4.1.

<a id="j410"></a>
### J.4.10 The monitor: commands, how it is reached, its console

**Issue.** The controller's ROM includes a monitor (4.10.1, decided). Open: its command set, how it is reached (when nothing boots, a key at power-up, or both), its console and speed, whether it loads a program over the serial line, and what is kept in non-volatile memory (boot order, serial speed). Whether a hardware watchdog, which restarts the machine when the kernel hangs, belongs beside it is the assistant's proposal and is in appendix H.

**Why it matters.** The monitor is the way in when nothing boots, so its ROM size and its dependence on a serial port decide how a new board is brought up.

**Options.**

1. *Examine, deposit, load over serial, start at an address, start from a device, reset a core, reset the machine.* For: the PDP-11's `ODT` plus a loader. Against: a few hundred bytes of ROM (an estimate) and a working serial port.
2. *Examine, deposit and start only, the `ODT` set.* For: the smallest. Against: no program can be loaded when the disk is dead.
3. *A boot menu (choose a device) only.* For: simple. Against: no inspection of a dead machine.

**Precedents.** `ODT` on the PDP-11 *(2.11BSD `cons(4)` read; the commands unverified)*; U-Boot and OpenSBI consoles *(unverified)*.

**The author's referents.** Errata 47: "the boot ROM and its monitor".

**The assistant's leaning.** Option 1.

**Where the body refers to it.** Section 4.10.1.
