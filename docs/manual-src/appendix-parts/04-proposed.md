### 4.3 What takes the place of a BIOS (moved from chapter 4)

**4.3.1b** (moved from chapter 4) The ROM brings up the machine, loads the first block, and offers a console monitor when nothing boots. It has no resident services and nothing is called after boot. *(P)* (The first sentence of 4.3.1 is in the body, decided by errata 47.)

*Commentary (moved).* **Trade-offs.** The pdp64 returns to the PDP-11 split and drops job 3: every device speaks virtio through one transport (chapter 2), so the loader and the kernel share one driver design and the loader needs no firmware to read a disk. The cost is a driver for the boot disk in the second stage, small because a virtio device is a handful of structures. **Benefits.** There is no firmware API to specify, no compatibility layer, no resident management code and no closed blob at the bottom of the trust chain (x86 firmware also keeps resident system-management code that the operating system cannot see, unverified; arm64 and RISC-V servers need trusted firmware and usually UEFI beside it, unverified, though OpenBSD's arm64 and riscv64 ports do boot through `efiboot`, read); the failure cases reduce to one, the first block did not load, and the monitor is the recovery. **Impact.** *Kernel:* no firmware services to call or to fix. *Compiler:* builds the ROM, loader and tools. *Hardware:* a boot ROM of a few hundred bytes to a few kilobytes, with a driver per boot device (not specified more closely).

### 4.4 The reset state and the first block (moved from chapter 4)

**The ROM's details (moved; its job as pseudocode, and 4.4.1, are in the body).** The ROM does five things in order: find a boot device, read block 0 into low memory, check that it looks like a boot block (the `0x55AA` signature), set core 0's registers, and start core 0 at the block. The assistant's fuller pseudocode, with the register state:

```
    quick_memory_check()                      # a short test of the first pages (repo: `boot.md`, job 1)
    for dev in boot_order:                    # disk or flash, then SD card, then the serial line (4.4.1)
        ...
        if byte[LOAD + 510] != 0x55 or byte[LOAD + 511] != 0xAA: continue
        core0.mode = KERNEL; core0.priority = 7; core0.translation = off; core0.VBR = 0
        core0.guard = clear                   # the user-memory guard
        core0.r0 = number_of(dev); core0.r1 = info; core0.r14 = 0x10000
        core0.all_other_registers = 0
```

read_block (the standard disk: one virtio-blk request, 5.6.2): build a three-descriptor chain (request header, a 512-byte buffer at `address`, a one-byte status); FENCE; write the queue's doorbell; poll the used ring until the chain returns.

The ROM polls (checks in a loop) rather than using interrupts. Inference, not stated: the ROM runs before any software has programmed the interrupt controller (2.6.3: how the interrupt controller is programmed is not specified), so there is nothing to interrupt it; polling needs no set-up, and 2.7.8 shows the polled form. It needs a driver for each kind of boot device; for the standard disk that is the virtio-blk reader of chapter 5: find the function in the bus's configuration space, set up one queue, read one block. Which device comes first, and how the ROM names a device in `r0`, are not specified (F10 of `decisions-pending.md` leaves the order after the disk open).

**The reset state of core 0 and the load address (moved from the paragraph "The first few pages of memory").** Block 0 is loaded **above** the table, at 0x1000 in this chapter's example (the address is "to be chosen"; `docs/boot.md`), so that the first stage runs without overwriting the vectors. The stack pointer `r14` starts at the top of the first 64 KB, so the first stage has a stack before it has run an instruction. `r1` points at the **boot-information block** (4.6). The author's rule of errata 102 is that no device window is mapped in **the first few pages**, where "the boot stuff is loaded"; how many pages that is, is not decided.

![Memory when block 0 is loaded](figures/boot-block0-memory.svg)

**4.4.1** (moved from chapter 4) At reset the controller brings up memory, holds every core in reset, and looks for a boot device in a fixed order: disk or flash, then SD card, then the serial line. *(P)*

**4.4.2b** (moved from chapter 4) The ROM reads block 0 of the first device that answers (for the standard disk, a virtio-blk read request), checks the `0x55AA` signature in the last two bytes, and does not parse a partition table. *(P)* (That the ROM reads block 0 and starts core 0 is in the body.)

**4.4.3** (moved from chapter 4) Core 0 starts in kernel mode at priority 7 with translation off (every address physical), `VBR` zero and the user-memory guard clear; `r0` holds the boot device number, `r1` the address of the boot-information block, `r14` the top of the first 64 KB of memory, and the other registers are zero. *(P)* The first few pages of the physical address space are reserved for the boot code and boot data, and no device window is mapped there (2.3.5, *(D)*); how many pages is not decided. *(P)*

**4.4.4** (moved from chapter 4) If a key is held at power-up, the monitor runs on the serial console. *(P)* (That the monitor runs when nothing boots is 4.10.1 in the body.)


*Commentary (moved).* **Trade-offs.** A boot ROM with a driver per boot device is more code in the controller than a "jump to a fixed flash address" scheme and much less than firmware; the first block must fit in one sector. **Benefits.** The first stage is the same on every board, and the first kernel code makes no guesses about the reset state, which earlier machines left to the console (inference: the VAX console and the PC's BIOS each defined their own). **Impact.** *Compiler:* the first block is 446 bytes of assembler. *Hardware:* the ROM reads one block and starts one core.

### 4.5 The disk: a GPT around the BSD label (moved from chapter 4)

**The first stage lives in the protective MBR.** Block 0 of a GPT disk is the protective MBR, 512 bytes: 446 bytes of code, the table (one entry, type `0xEE`), then `0xAA55` (the bytes `0x55`, `0xAA`: the `0x55AA` of 4.4.1). The first stage has 446 bytes. It cannot understand a GPT or a file system in that space and does not try: it carries a **block list**, three numbers per piece of the second stage (first block, number of blocks, load address), written into its code area by the **`installboot`** tool at installation; it reads those blocks and jumps to the first. The BSDs already do this. OpenBSD 4.6's `installboot(8)` page for the sparc says the first-stage program "loads the second stage program from a set of filesystem block numbers that have been hard-coded into it by the installboot program"; on the PC `installboot` patches `biosboot` with the location of `/boot`, and `biosboot(8)` says to re-run it whenever `boot(8)` is changed, "as its inode may change" (read). Because the boot-code bytes are the only place the pdp64 keeps block-list data, a damaged GPT cannot stop the machine reaching the second stage, which can repair it.

```
first_stage() with the block list (the assistant's sketch; the body has the general form):   # at LOAD (0x1000): 446 bytes of code plus the block list
    # entering state: kernel mode, priority 7, r0 = boot device, r1 = boot-information block, r14 = a stack
    for entry in block_list:                  # entries written by installboot: (start, count, address)
        read_blocks(r0, entry.start, entry.count, entry.address)     # (see the open question below)
        if failed: goto monitor_or_halt       # what to do on failure is not specified
    jump to block_list[0].address             # the second stage, with r0 and r1 unchanged
```

The pseudocode hides a question the repository does not answer: **how the first stage reads blocks.** 4.3.1 says the ROM offers no services after boot, and a virtio-blk read needs a queue, three descriptors, a doorbell and a poll (4.4). Whether that fits in 446 bytes beside the list is not established. The PDP-11 primary bootstrap carried its own disk driver (the `hpcs1` and `hpcs2` writes of 4.1) and the PC's called the BIOS. Three ways out, none decided: the first stage holds a small polled virtio-blk reader of its own (the PDP-11 way, consistent with 4.3.1); or the ROM leaves a read routine and tells the first stage where it is (a firmware call in miniature, against 4.3.1); or the ROM loads more than block 0, the whole 8 KB boot area of 4.5.3 for example, so the first stage has room for the reader. The question is in 4.13.

**4.5.2b** (moved from chapter 4) The first stage carries a short block list (start block, count, load address) to the second stage; neither the ROM nor the first stage parses the GPT. *(P)* (Decision B8, a proposal. That the first stage lives in the 446 bytes of the protective MBR is 4.5.2 in the body.)

From the paragraph on the superblock: The second stage can live in the boot area, in a small boot partition, or as a file in the root file system; whether a dedicated boot partition is needed is open (4.13), since the block list can point at any of them.

From the commentary: the benefit "The first stage does not depend on a GPT that may be damaged."

### 4.6 The second stage and the hand-off (moved from chapter 4)

**What the second stage is for (the fuller sketch; the general form is in the body).** The first stage put a bigger program in memory. The second stage does what the PDP-11's `boot` did, with more to read: it finds the disk, reads the partition table, reads the label, finds the root file system, finds the kernel by name in it, loads the kernel and enters it. Because it is a C program loaded from disk it can be as large as it needs and be replaced by copying a file. It has its own drivers (the virtio-blk reader, now complete) and no firmware to call. As a sketch:

```
second_stage():                               # loaded by the first stage; r0 and r1 as at reset
    dev = open_boot_device(r0)                # the same virtio-blk driver the ROM used, now complete
    gpt = read_gpt(dev)                       # header at block 1: check "EFI PART" and the CRC32;
                                              # if it is bad, use the backup at the end of the disk
    part = first entry whose type GUID is the OpenBSD type
    label = read(dev, part.start + 1)         # sector 1 of the partition (4.5.3)
    check label.magic == 0x82564557 and the label's checksum
    root = the label's root partition ('a'); mount it read-only
    cmdline = prompt("boot> ") or the default   # as the V7 ':' prompt: which kernel, which options
    elf = root.open("/bsd")                   # an ELF file, the toolchain's own object format
    for seg in elf.loadable_segments:
        copy seg.file_bytes to physical address seg.address; zero the rest of seg
    info = r1                                 # the block the ROM began; add what only we know:
    info.cmdline = cmdline
    info.video = framebuffer if we set one up (4.6.3)
    info.checksum = checksum(info)
    jump elf.entry with r0 = boot device, r1 = info     # still kernel mode, priority 7, translation off
```

**The pdp64's hand-off (moved from the hand-off paragraph).** A kernel that is to run on any pdp64 has to be told: how much memory there is and where (ranges, since memory is not always one block), how many cores, where the bus's root complex is (so that it can **enumerate**, walk the bus and list what is attached, 2.4), which device it was loaded from, where the console is, and the command line. The block is addressed by `r1`. The pdp64's hand-off is small because the bus describes its own devices: the block names memory, cores, the root complex, the boot device, the console and the screen if one was set up, and the kernel finds everything else by enumeration.

![The boot-information block](figures/boot-bootinfo.svg)

**4.6.1b** (moved from chapter 4) The second stage is a program in C that understands the root file system, reads the GPT and the label, loads `/bsd` (an ELF file) and jumps to it with `r0` and `r1` as before and a command line in the boot-information block. *(P)* (That the second stage carries its own drivers, finds the kernel and enters it is 4.6.1 in the body.)

**4.6.2b** (moved from chapter 4) The boot-information block names the memory ranges, the core count, the address of the root complex and the identity of the boot device and the console; the kernel enumerates every other device by PCI Express enumeration (section 2.4). *(P)*

**4.6.3** (moved from chapter 4) The block's layout is defined once, in a grammar from which the headers are generated, and carries a checksum and a version. *(P)*

*Commentary (moved).* **Trade-offs.** A fixed-layout block with a checksum has two failure cases (bad checksum, unknown version), against the parser a device tree or ACPI needs. OpenBSD's arm64 and riscv64 ports already parse a device tree and attach drivers from it, which could save kernel code if the port reuses many of their drivers (4.13). **Benefits.** Because the bus describes its own devices, the block shrinks to memory, cores and the bus controller's address, and the generated header cannot disagree with the loader. **Impact.** *Kernel:* reads a structure. *Compiler:* generates the header from one grammar. *Hardware:* none.

### 4.7 Starting the other cores (moved from chapter 4)

**The pdp64's rule: one register write.** A pdp64 core has no mode ladder, so it can start in its normal mode at any address. The controller holds every core but core 0 in reset; to start core *n*, the kernel writes, to a register block in the controller that belongs to core *n*, the address where the core should begin and one argument, and the controller releases the core into **kernel mode at priority 7** with its core number in `r0` and the argument in `r1`. By the kernel's convention the argument points to a structure that belongs to that core (its stack, its per-CPU data). A core that sticks is reset by a write to a core-reset register and started again.

```
start_secondary_cores():                      # core 0, in the kernel, after its tables are built
    for c in 1 .. core_count - 1:             # core_count comes from the boot-information block
        percpu[c] = allocate(percpu_size); percpu[c].stack = allocate(KSTACK)
        percpu[c].online = 0
        write(start[c].entry, secondary_entry)   # the exact registers are not specified (4.7.1)
        write(start[c].argument, percpu[c])
        write(start[c].go, 1)                    # the controller releases core c into kernel mode
        wait up to a timeout until percpu[c].online == 1
        if not online:
            write(core_reset[c], 1)              # 4.7.2: stop it, and try once more
            ... start it again, or mark core c failed and go on without it

secondary_entry():                            # core c: kernel mode, priority 7; r0 = c, r1 = percpu[c]
    set VBR and the page-table base to the kernel's, turn translation on, ISYNC    # chapter 6 (6.12)
    set the per-CPU pointer DP from r1; set R14 = percpu.stack top                 # chapter 7 (7.4.2)
    percpu.online = 1                         # core 0 is polling this word
    enable the clock; enter the scheduler's idle loop (WFE until there is work)    # chapter 6, 7.6
```

![Starting the other cores](figures/boot-smp-timeline.svg)

The cost is one register block in the controller, with a start register and a reset hold per core. The started core has no translation or stack of its own; the kernel's entry code sets them up in its first instructions, as the first kernel does (6.12). Whether a started core begins with translation off, and what `MMUCTL` it sees, are not specified.

**4.7.1b** (moved from chapter 4) (4.7.1 of the body says only that the controller chip provides the way to start the other cores.) The controller holds every core except core 0 in reset; a write to a core's start register in the controller gives it an entry address and an argument and releases it into kernel mode at priority 7, with its core number in `r0` and the argument in `r1`. *(P)*

**4.7.2** (moved from chapter 4) A stuck core is reset by a write to a core-reset register. *(P)*

*Other chapters.* This is option 1 of boot decision B2 and of R2 in `decisions-pending.md`, which recommend it and leave it proposed (the other options were the x86 signals, a firmware call, a spin table and a table that all cores start from). Chapter 7 states the same rule as 7.8.1 and loads `r0` only, where 4.7.1 loads `r1` too; the difference is to settle (4.13). Waiting uses `WFE` and `SEV` (7.6); an **inter-processor interrupt**, a signal from one core to another, is a write to a per-core register of the interrupt controller (7.8.2).

*Commentary.* **Chain.** PDP-11: one processor, nothing to start. VAX: the console processor started the others (unverified). x86: INIT and START-UP signals and a trampoline through three modes. arm64 and RISC-V: a firmware call or a spin loop. pdp64: a register write. **Trade-offs.** With no mode ladder the whole protocol is one write, at the cost of a small register block in the controller. **Benefits.** No trampoline, no firmware call, fewer lines than any system counted, and one recovery path, a core reset. **Impact.** *Kernel:* starting a core is a register write. *Compiler:* none. *Hardware:* a start register and a reset hold per core.

### 4.8 Starting the devices (moved from chapter 4)

**The INIT bit (the sentences moved).** Statement 4.8.1 keeps `INIT` and `READY`. At boot the ROM runs the device start for the boot disk (4.4), the second stage again for the devices it uses, and each kernel driver at attach.

**Firmware for a device.** Some devices contain a small processor and need a program, **firmware**, loaded into them before they work; a network or wireless card is the usual case, a graphics device another. The PDP-11 had no such device and no way to give it one. On a PC the driver loads the blob from a file at attach time (Linux's `request_firmware`, declared in `include/linux/firmware.h`; OpenBSD's `loadfirmware(9)`, which reads the file from `/etc/firmware`; NetBSD's `firmload(9)`: all read), and the files come in a separate package. The pdp64 proposal is that such a device is given its firmware through a descriptor operation (a request on the device's queue, or a descriptor giving the address and length of an image in memory, with a small header the device checks: identifier, version, length, checksum) **once the root file system is available**, and that a device the boot depends on needs none: the boot disk, the console and the interrupt controller work from their built-in logic alone, so that no device waits for firmware that is on the disk it controls.

```
start_device(dev):                            # at boot or at attach
    init_device(dev)                          # the handshake of 2.7.3; reset first
    if dev.needs_firmware:                    # a device the boot depends on never does
        image = read_file(root_fs, firmware_name(dev))      # the file system must be up (4.6)
        check image.header: device id, version, length, checksum
        submit a descriptor chain giving dev the address and length of image
        wait for the device to answer; if it refuses, mark the device failed
```

**4.8.1b** (moved from chapter 4) A device that wants firmware is given it through a descriptor operation once the root file system is available, and a device the boot depends on needs no firmware. *(P)* (That a device is initialised by a register write behind the bus, and may be given values or a firmware image, is 4.8.1 in the body.)

*How the statement reads under virtio.* 4.8.1 is the PDP-11 form, one `INIT` bit and one `READY` bit (errata 29); under virtio (errata 95) it is the `device_status` handshake above. How a virtio device is handed firmware is not specified: virtio has no firmware operation of its own, so a request type or a separate device would have to be defined (4.13).

*Commentary.* **Chain.** PDP-11: the CSR's `INIT` bit, nothing more. PC: PCI Express devices initialised through configuration space and per-device driver code, firmware blobs loaded from files. VAX: the console and some adapters loaded microcode from storage (unverified). pdp64: the virtio handshake, firmware by descriptor. **Trade-offs.** A reset bit and a status register make the simplest device, with one failure case, a timeout. A firmware window lets a device be cheap (no flash) and makes an update a file replacement, at the cost of a header format and a device that rejects a wrong image safely; boot-critical devices are excluded because a device whose firmware is on a disk it must itself read cannot start. NVMe has a firmware-download command that needs a working queue first (unverified; not found in the QEMU headers read). **Impact.** *Kernel:* a device start is the 2.7.3 handshake. *Compiler:* none. *Hardware:* a status register per device.

### 4.9 Why UEFI is not used (moved from chapter 4: the shim's details)

Statements 4.9.1 and 4.9.2 stay in the chapter. The details of a shim are proposed.

**What a shim is, and what it is not.** The author asked, "not sure why firmware and coff are needed for uefi, with virtio native that shuld be minimal, no?" and then, "yes, state the shim's real scope." Virtio removes most of the driver mass that a full firmware carries (it ships drivers for every disk, network card and screen it might meet; the pdp64 has one device interface), and the shim needs only the drivers the second stage has. Two things stay, and they are the shim's real scope:

1. **PE/COFF.** The UEFI specification requires a UEFI application to be a PE32+ image (unverified: the specification is not here); that is a property of the **loader programs**, not of the firmware. To run an existing loader such as OpenBSD's `efiboot` it must be built as a PE/COFF image *for the pdp64*, so the toolchain has to produce one, and a **machine-type code** (a 16-bit number in the image's header that names the processor; OpenBSD's arm64 loader uses `IMAGE_FILE_MACHINE_ARM64 0xaa64`, read) would have to be assigned by the owners of the specification (unverified). It need not be a linker feature: OpenBSD's arm64 loader is linked as an ordinary ELF file and wrapped as PE32+ by a header written by hand in assembler (`start.S`, 176 lines) plus a self-relocator (`self_reloc.c`, 124 lines), with `objcopy` doing the rest (read, counted). The loader is itself a program that must be compiled for the pdp64.
2. **A small services layer.** The shim provides the few services loaders use: memory allocation and the **memory map**; reading a file from the boot partition; the console and the **graphics output protocol** (a framebuffer to draw on); **exit boot services**; a runtime clock and reset; all over virtio. It also hands the kernel a device description in the form such a loader expects, a device tree or tables.

**How many services, counted.** The three UEFI loaders in `/home/david/claude/kernel-src/openbsd/sys/arch/*/stand/efiboot` call these (counted as `BS->`, `RS->` and console calls in the `.c` files; the number is the count of call sites in the amd64 loader):

| Boot services (`BS->`) | Runtime services (`RS->`) | Console and file protocols (through a handle) |
|---|---|---|
| `HandleProtocol` 13, `AllocatePages` 7, `LocateHandle` 5, `LocateProtocol` 2, `LocateHandleBuffer` 2, `GetMemoryMap` 2, `FreePages` 2, `WaitForEvent`, `SetWatchdogTimer`, `FreePool`, `AllocatePool`, `Exit`, `ExitBootServices` (1 each); the arm64 and riscv64 loaders add `SetTimer`, `CreateEvent`, `CloseEvent` and lack the two pool calls | `ResetSystem` 3, `GetVariable` 3, `SetVariable` 2, `GetTime` 1 (called as `ST->RuntimeServices->GetTime`) | the text console (`OutputString`, `ReadKeyStroke`, `SetMode`, `QueryMode`, ...), the disk (`ReadBlocks`, `WriteBlocks`), files (`Open`, `Read`, `Write`, `Close`, `SetPosition`, `GetInfo`), the network (`Mtftp`, `Transmit`, `Receive`), the graphics output protocol, the random-number protocol |

That is 17 distinct boot and runtime calls in the amd64 loader (13 and 4) and 18 in the arm64 and riscv64 ones (14 and 4); errata 109 and `boot.md` say "about fifteen to seventeen", which this count corrects. It counts what **one** loader uses and is not a specification of what a shim must offer: another loader uses others, and whoever writes the shim reads the loader.

**A sketch of the shim (an illustration).** The shim is the second stage, loaded by block 0; it builds the services table, loads the loader's PE image, calls it, and answers its calls.

```
shim_entry():                                 # the second stage of a pdp64 that wants UEFI loaders
    info = r1; heap = free_ranges_from(info.memory_ranges)
    table = new system_table {
        boot_services = {
            allocate_pages = shim_allocate_pages,   # out of the heap; the loader asks for a page count
            free_pages     = shim_free_pages,
            get_memory_map = shim_get_memory_map,   # the ranges of `info`, plus what the heap handed out
            locate_protocol = shim_locate_protocol, # the console, the graphics output, a file volume
            exit_boot_services = shim_exit_boot_services,
            ... }                                    # the others a given loader uses; unused ones return "unsupported"
        runtime_services = { get_time = clock_register, reset_system = reset_register, ... }
        configuration_tables = [ (DEVICE_TREE_GUID, make_device_tree(info)) ]   # made from the boot-information block
    }
    image = read_file(boot_partition, loader_path)  # the path convention is not specified
    entry = pe_load(image)                          # headers, sections, relocations
    status = call entry(image_handle, &table)       # the loader runs, and calls back through the table

shim_exit_boot_services(handle, map_key):
    if map_key != current_map_key: return INVALID_PARAMETER    # the map changed since the loader read it
    stop the shim's console and timer; free the memory of the boot-services data
    keep only the runtime services: the clock and reset are register writes
    return SUCCESS                                 # the loader owns the memory and enters the kernel
```

![The place of a UEFI shim](figures/boot-shim.svg)

**The costs.** A shim is not a UEFI firmware stack. The boot review's figure of "hundreds of thousands to millions of lines" for a UEFI firmware (`docs/boot.md`, "Is UEFI worth it?") was never confirmed against a source, describes a full stack such as EDK II, and is not used as the cost of a shim. **No count of the shim's lines is given, because none can be measured here:** no UEFI implementation source is on this machine (the `edk2` and `u-boot` directories under the QEMU tree's `roms/` are empty). Measured are the loaders that would run on it (OpenBSD's `efiboot`: 4,593 lines for amd64, 7,195 for arm64, 4,513 for riscv64) and the 176 lines of header and 124 of relocator above. The costs that remain:

* **A PE/COFF build and a number.** The toolchain emits a PE/COFF image, and a machine-type number must be obtained (unverified).
* **A loader to port** to the pdp64 as any program is, the larger part of the work.
* **A services layer** written, tested and kept in step with the loaders it serves.
* **Code to trust before the kernel.** The shim is open source (4.3.2), runs only at boot and is not resident afterwards except for the clock and reset.
* **A platform description** (a device tree or tables) built from the boot-information block.

It does not cost a closed firmware, a variable store, a setup screen or a second boot path in the machine itself: the machine's own boot stays block 0.

*Commentary (moved).* The shim sentence: "A shim gives the first benefit without the rest, at the price of a services layer and a PE/COFF build." The impact lines: *Kernel:* a shim would translate the boot-information block. *Compiler:* no PE/COFF unless a shim is built.

### 4.10 Recovery (moved from chapter 4: what remains proposed)

**What to do when nothing boots.** A PDP-11 with a dead disk was not a dead machine: `ODT` let you examine memory and key a bootstrap in (4.1), and V7 shipped `/boot.bu`, a backup of the second stage. The pdp64 keeps the idea and gives it a place. The ROM that reads block 0 (4.4) also contains a **monitor**, a small program that runs on the serial console when no boot device answers or when a key is held at power-up and offers a few commands: examine and deposit memory and registers, load a program over the serial line, start at an address or from a named device, reset a core, reset the machine. It needs a working serial port and nothing else, so it also brings up a new board before any boot device works.

```
monitor():                                    # the ROM's console program; no interrupts, no memory but the first pages
    loop:
        print("pdp64> ")
        line = read_line(serial)
        case first word of line:
            "x" addr [n]    : print n words at addr                  # examine (the PDP-11's `addr/`)
            "d" addr value  : store value at addr                    # deposit
            "r" [name value]: print or set a register of the stopped core
            "l"             : read a program from the serial line into memory   # load
            "g" addr        : start core 0 at addr (r0, r1 as in 4.4.3)
            "b" device      : try to boot from this device
            "c" n           : write core n's reset register (4.7.2)
            "z"             : write the root complex's reset register (2.9.4; what else it resets is not specified)
            otherwise       : print("?")
```

The command letters and the prompt are an illustration. A **watchdog** is a hardware timer that counts down and restarts the machine unless software writes to it ("kicks" it) in time; a hung kernel stops kicking and is restarted. The PDP-11 had none. PC chipsets carry watchdog timers (QEMU models the ICH9 chipset's TCO timer in `hw/acpi/ich9_tco.c` and the Intel 6300ESB watchdog in `hw/watchdog/wdt_i6300esb.c`: read); whether PC firmware arms one is unverified. It needs about ten lines in the kernel. `decisions-pending.md` P7 asks for a bus-controller reset register and a watchdog **in place of** firmware calls, and the monitor's reset command writes that register.

**4.10.1b** (moved from chapter 4) The monitor is reached on the serial console and offers: examine and deposit memory and registers, load a program over the serial line, start at an address or from a named device, reset a core, reset the machine. *(P)* (That the controller's ROM includes a monitor is 4.10.1 in the body.)

**4.10.2** (moved from chapter 4) A hardware watchdog restarts the machine if the kernel hangs. *(P)*

*Commentary.* **Chain.** PDP-11: `ODT`, the front panel and `/boot.bu`. VAX: the console processor (unverified). PC and UEFI: a setup screen and rescue media (unverified). ARM and RISC-V boards: the console of U-Boot and the debug console of OpenSBI (unverified). pdp64: a monitor in ROM and a watchdog. **Trade-offs.** A monitor is a few hundred bytes of ROM (an estimate) and needs a serial port. **Benefits.** It is the recovery path that needs the least code. **Impact.** *Kernel:* the way in when nothing boots. *Compiler:* none. *Hardware:* a serial port and the ROM bytes.

### 4.13 Still open (moved from chapter 4: what is not an open item of the architecture)

The open items (a) to (i) of the former list are entries J.4.1 to J.4.8 of appendix J. The rest of the list:

**(j)** the monitor's commands, the serial speed and what is kept in non-volatile memory are now J.4.10; **(k)** the shim: the path of the loader it runs, the services it offers, the machine-type number (4.9), none to be settled until someone wants one.

**Facts still to check against their own documents:** the PDP-11 power-up behaviour and the M9312's ROM contents (only its contract with block 0 was read); the VAX console, VMB and the Alpha console's boot protocol (only the restart block was read); the C64 boot; the x86 reset vector and START-UP rules; PSCI, the SBI hart calls and the spin table as specified; what the UEFI specification requires of a loader and of firmware, including the machine-type registry; the size of a UEFI services layer, which only an implementation could give.
