# 4. Boot, the BIOS, the disk label and the GPT

[← manual index](00-index.md)

**The machine starts the way the PDP-11 did: a small ROM in the controller chip loads one block from the boot device and jumps to it, and every later stage is an ordinary program, open source, compiled by the project's own compiler.** This chapter is written for a reader who has keyed a bootstrap in on a PDP-11 front panel, used a boot ROM, or typed `boot` at the `:` prompt of Unix Version 7 or 2.11BSD, or who is learning computing from the start, and who has not met anything invented after the 1970s: no BIOS, no UEFI, no partition table, no device tree, no start-up of a second processor, no firmware update. It begins with what the PDP-11 did (the switches, the boot ROM, block 0, the two-stage bootstrap, `ODT`), explains each later idea by contrast with it (the PC's BIOS and boot sector, UEFI, the GPT and the BSD disk label, the hand-off of a description of the machine, starting other cores, starting devices, recovery), walks each stage through in pseudocode, and gives the decisions as numbered statements along the way. The full review of how other systems boot is [`../boot.md`](../../boot.md). Tags: *(D)* decided; *(P)* proposed; *(S)* unspecified; a fact about an older or another machine that could not be checked on this computer is marked *unverified* and listed in section 4.12.

*How to read this chapter.* A term is defined where it first appears, as the technical word followed by a plain restatement. Boxes-and-arrows pictures are the kind a textbook draws for a linked list: a box is a piece of memory, a register or a program, an arrow says what is handed on. Code blocks are pseudocode (C-like, `#` starts a comment) unless the text says they are PDP-11 assembly; the PDP-11 code is quoted from the V7M and 2.11BSD sources on this machine (section 4.12), and every pdp64 sketch is **an illustration written for this chapter**: no pdp64 boot ROM, first stage or second stage exists (the QEMU machine loads the kernel directly, 6.12.2), so none of it is tested. The decisions are the numbered statements; the rest is explanation, and where the repository does not say, the text says *not specified*.

## 4.1 What you already know: starting a PDP-11

A processor that has just been powered on has a problem that no program can solve for it: the program that loads programs has to come from somewhere, and the memory holds nothing it can trust. This is the **bootstrap problem** (the name is the old joke of pulling yourself up by your own bootstraps, which is how it is shortened to "boot"). A PDP-11 solved it in three ways, each smaller than the one before it was.

**The front panel.** The console of a PDP-11 had rows of switches. You set the address switches to a memory address and pressed LOAD ADDRESS, set the data switches to a word and pressed DEPOSIT (which stores the word and steps the address), repeated that for each word of a short **bootstrap loader** (a program of a few dozen words that reads a bigger program from a device), set the start address and pressed START. This is how machines were brought up, and the manual of the V7M system still says so: its `boot(8)` page tells you to "load block 0 of the boot device by fiddling with the console keys as appropriate for your hardware. If you have no appropriate ROM, some programs suitable for manual use are given below" (section 4.12; the switch mechanics themselves are general knowledge, unverified).

**The boot ROM.** Later machines kept the loader in a **ROM** (read-only memory: storage that holds its contents without power and is not written during normal operation) on the processor board, one small program for each kind of disk or tape. The V7M sources name the card, the M9312, in a comment on the tape bootstrap (`sas/htboot.s`: "The M9312, which is the only boot for the TS11"); a console switch or a command chose the device and the ROM did the rest. What the ROM did is the whole subject of this chapter in one sentence: it read **block 0** (the first 512-byte **block**, the unit a disk is read in; the first block of the disk is numbered 0) of the boot device into low memory and jumped to it.

**Block 0, the primary bootstrap.** What lived in block 0 was a **primary bootstrap**: a program small enough to fit in one block. The V7M page says it in one paragraph: "A PDP11 UNIX system is started by a two-stage process. The first is a primary bootstrap which is able to read in relatively small stand-alone programs; the second (called *boot*) is used to read in the system itself. The primary bootstrap must reside in the otherwise unused block zero of the boot device. It can be read in and started by the standard ROM programs, or if necessary by keying in a small startup routine." Here is the head of the primary bootstrap for the RM02/3 and RP04/5/6 disks, `sys/mdec/hpuboot.s` (285 lines of assembler, measured), which shows what a block-0 program has to do for itself:

```
/ UNIX/v7m RM02/3 and RP04/5/6 block 0 bootstrap
/ Can only boot from unit zero.
/ Assumes disk at standard address (0176700).

core = 28.
.. = [core*2048.]-512.          / 28 K words = 56 KB, less 512 bytes: high in memory

start:
        mov     $..,sp          / the stack is just below the program's new home
        clr     r0
        mov     sp,r1
        cmp     pc,r1           / are we running below the intended origin?
        bhis    2f
1:      mov     (r0)+,(r1)+     / yes: copy this program up, out of the way
        cmp     r1,$end
        blo     1b
        jmp     (sp)
2:      clr     (r0)+           / clear core to make things clean
        cmp     r0,sp
        blo     2b
        mov     $drive,*$hpcs2  / initialize the disk hardware and select the drive type
        ...
        mov     $'\r,r0         / print CRLF and '#' as a prompt
        ...                     / read a pathname from the console, then walk the
                                / inodes from the root (inode 2) to find the file
        jsr     pc,*$0          / the loaded program is entered by a call
```

The ROM put this program at address 0; it copies itself to the top of the first 56 KB so that the kernel can be loaded at 0, clears the rest of memory, starts the disk, prints `#`, reads the name of a file, finds the file by reading the disk's **inodes** (the file system's table entries, one for each file) from the root directory down, loads it, and enters it. The file it loads is the second stage.

**The second stage, `boot`.** `boot` is an ordinary program, written in C (`sys/sas/boot.c`, 272 lines, measured). The V7M page: "When read into location 0 and executed, *boot* sets up memory management, relocates itself into high memory, and types `Boot` and `:` on the console. Then it reads from the console a device specification followed immediately by a pathname", for example `hp(0,0)unix`: the device, the unit, and the block offset of the file system on it. "*Boot* finds the corresponding file on the given device, loads that file into memory location zero, sets up memory management as required, and calls the program by executing a `trap` instruction." So there were two prompts, `#` from the first stage (type `boot`) and `:` from the second (type `hp(0,0)unix`), and two reasons for the split: block 0 has room for 512 bytes of program, which can find a file by name but cannot also keep a menu, a device table and an error message for every disk; and a bigger program with all of that can be an ordinary compiled file that you can change by copying a new one in.

**2.11BSD**, the same kernel grown up, is explicit about the limit and about what the stages pass on. Its `boot(8)` page: "a primary bootstrap (limited to 512 bytes) ... must reside in block zero of the boot device (the disklabel resides in block one) ... `disklabel(8)` is normally used to place a copy of the appropriate bootstrap in block zero of new file systems"; copies are kept in `/mdec`. The header of its `hpuboot.s` says "assembled size must be <= 512; if > 494, the 16-byte a.out header must be removed" and that all the options (an alternate name, echoing) "had to be removed to make room". The next stage passes the machine on **in registers**: the comment in its start-up code `pdpstand/srt0.s` reads "the bootstrap passes the cputype through in r0", `r1` holds the controller's register address, `r3` the boot device's major and minor number, and `r2` is a check word that is the complement of the boot options, so that the program can tell an unattended reboot from a person typing. That is the PDP-11 form of what the pdp64 does with `r0`, `r1` and the boot-information block (4.4, 4.6).

**`ODT` and the console.** When nothing booted, you were not stranded: the processor or the ROM carried a tiny monitor, **ODT** (Octal Debugging Technique, a console program that lets you type an address, see the word there, change it, and start a program at an address: *examine*, *deposit*, *start*). A PDP-11 with a dead disk could still be inspected and a bootstrap keyed in. (`ODT` itself is not in the sources on this machine: it is general knowledge, unverified.)

**What a PDP-11 did not have,** and what the rest of the chapter explains, each by contrast:

* **No table of partitions on the disk.** V7 compiled the sizes of a disk's regions into the driver (`hp_sizes[8]` in `hp.c`: eight pairs of a size and a first cylinder, with comments like "cyl 44 thru 429"), so changing the layout meant recompiling the kernel (4.5).
* **No description of the machine handed to the kernel.** The kernel was built for the machine, with the devices and their addresses compiled in (the vector table of chapter 6 is that table), and what the bootstrap passed was three or four registers (4.6).
* **No other processors to start,** and no cores held in reset (4.7).
* **No device that needed a program of its own** before it would work, and no way to give it one (4.8).
* **No firmware, no BIOS and no UEFI,** so no question of what to do about them (4.2, 4.3, 4.9).
* **A monitor, but no watchdog:** nothing restarted a hung machine (4.10).

**What does not change in the pdp64:** a ROM that reads block 0 and jumps; a first stage that fits in a block; a second stage that is an ordinary program and finds the kernel by name; registers that carry the boot device across; a console monitor when nothing boots. What is new is six things, each explained where it first matters: partitions and the GPT (4.5), the boot-information block (4.6), starting other cores (4.7), starting devices (4.8), recovery by watchdog (4.10), and the decision not to build the PC's firmware (4.9).

## 4.2 What the PC added: the BIOS, the boot sector and UEFI

Everything in this section is the history of the machine that the pdp64's designers did not copy, so it is told briefly and from the PDP-11's point of view. The facts here come from the OpenBSD sources on this machine where they can (section 4.12), and are otherwise general knowledge, marked unverified.

**The BIOS.** The IBM PC of 1981 (unverified) kept a ROM called the **BIOS** (Basic Input/Output System). It did four different jobs, and it is worth pulling them apart because the name has stuck to all four: (1) **bring-up and self-test**, initialising the chipset, sizing the memory and checking the basics (the power-on self-test); (2) **the first code**: find a boot device, read its first sector (the PC's word for a block, 512 bytes) to a fixed address and jump to it; (3) **a library of services** for software to call, by **software interrupt** (an instruction that behaves like a trap through a vector: the PDP-11's `emt` or `sys` is the same kind of thing), one for the disk, one for the screen, one for the keyboard, one for the memory map; (4) **configuration**, a setup screen and a small battery-backed memory for the clock and the settings. The third job is why a 512-byte PC boot sector can read the rest of a disk: it does not carry a disk driver, it calls the BIOS's. OpenBSD's PC first stage does exactly that: `biosboot.S` calls `INT 0x13`, the disk service, to get the drive's geometry and to read it (read in source, section 4.12). The PDP-11's bootstrap carried its own disk driver (the `hpcs1` and `hpcs2` writes above); the PC's borrowed the firmware's.

**The boot sector and its 446 bytes.** On the PC the first sector of the disk is the **MBR** (master boot record). It is one block with three parts: the first 446 bytes are the first-stage program, then a **partition table** of four entries of 16 bytes each (a **partition** is a named region of the disk, which lets several operating systems share one disk), then the two-byte signature `0xAA55` that tells the BIOS the block is a boot block. OpenBSD's `sys/disklabel.h` says so in C: `dmbr_boot[446]`, four `dos_partition` entries, `dmbr_sign`, the signature at byte `0x1fe`, and the entry holds a flag byte (`0x80`, "active"), a type byte, and a start and a size of 32 bits each (read in source). The 446 bytes are shared with a partition table because the PC wanted both in one sector, and 446 is what is left. The 32-bit size is why this scheme tops out at 2 TiB for 512-byte sectors (4,294,967,296 sectors of 512 bytes, arithmetic), and four entries is why there are "extended" partitions with a chain of further tables. The chain on an OpenBSD PC is: BIOS, then the MBR's 446 bytes (`mbr.S`, which "finds the first active partition"), then the **partition boot record** (the first block of that partition, `biosboot`: "roughly 512 bytes of code"), then `/boot`, then the kernel: **four stages** where the PDP-11 had two (read in source).

**Real mode.** The BIOS and the first stages run the processor in **real mode**, the 16-bit mode of the 8086 of 1978 that can address one megabyte, because that is the only mode the processor is in when it starts. Getting out of it into the processor's modern modes is the job of the loader, and is one of the things the pdp64 does not have to do (4.7).

**The GPT.** The four 32-bit entries ran out, so a new table arrived with UEFI: the **GPT** (GUID partition table, where a **GUID** is a 128-bit identifier, long enough that two made anywhere will not collide). It has a header in the second block, "EFI PART" in its first eight bytes, then an array of entries (128 of them by default, each 128 bytes: a type GUID, a unique GUID, a 64-bit first and last block, attribute bits and a 36-character name), a checksum (a **CRC32**, a 32-bit check value computed over the bytes) over the header and another over the array, and a **backup copy** at the end of the disk, so that a damaged table can be rebuilt. All values are little-endian (low byte first, the PDP-11's and the pdp64's byte order). All of this is read from OpenBSD's `gpt_header` and `gpt_partition` structures (read in source; the UEFI specification itself was not opened). Block 0 of a GPT disk is a **protective MBR**: an MBR whose table holds one entry of type `0xEE`, "EFI Protective Partition", covering the whole disk, so that an old tool that reads only the MBR sees a disk that is full and does not offer to partition it.

**UEFI.** The BIOS's successor is a firmware standard, **UEFI** (Unified Extensible Firmware Interface). It does not read a boot sector. The firmware itself understands the GPT and a **FAT** file system (the file system of MS-DOS, kept as the common denominator) on a partition of type "EFI system partition" (`GPT_UUID_EFI_SYSTEM` in OpenBSD's header), finds a **loader** file there, and runs it. The loader is a **PE/COFF** program: the executable file format of Windows (portable executable, from the Common Object File Format), which UEFI requires of its programs, so that a loader is a different kind of file from the Unix `a.out` or ELF files of chapter 1 (OpenBSD's arm64 loader begins "We need to be a PE32+ file for EFI", read in source). The loader receives a table of **boot services** (function pointers: allocate memory, read the memory map, read a file, write to the console, draw on the screen) and a few **runtime services** (the clock, reset, variables, which stay available after boot) and, when it is ready to take over the machine, calls **exit boot services**, which tells the firmware to stop using the memory it kept for itself. OpenBSD's own UEFI loaders call about fifteen of these (counted in 4.9). The loader also receives **configuration tables**, which describe the machine to the kernel: **ACPI** (a standard of tables, with a byte-code interpreter the kernel must carry) or a **device tree** (a text-sourced tree of nodes that names each device and its addresses, flattened into a blob), both of which OpenBSD's loaders look for (`EFI_ACPI_TABLE_GUID` and `FDT_TABLE_GUID`, read in source). Beneath all this the firmware is a large program with phases of its own; the QEMU tree on this machine carries ready-built firmware images of the open-source implementation EDK II (`pc-bios/edk2-*.fd.bz2`), of which the x86-64 code image is 3,653,632 bytes uncompressed (measured; the riscv and aarch64 images are padded flash images of 32 and 64 MiB, which says nothing about the code in them).

The six jobs side by side, from the PDP-11 to the pdp64:

| Job | PDP-11 | PC with a BIOS | PC with UEFI | pdp64 |
|---|---|---|---|---|
| Bring-up | the processor and its ROM | the BIOS | the firmware | the controller's sequencer; on the FPGA the vendor's memory block |
| First code | ROM or front panel reads block 0 | BIOS reads the MBR | firmware runs a loader file | the boot ROM reads block 0 |
| Services for the loader | none: the bootstrap has its own driver | software interrupts | boot services | none: the loader has its own drivers |
| Finding the kernel | a name typed at `:` | partition boot record, `/boot` | the loader on a FAT partition | the second stage reads the label and finds `/bsd` |
| Telling the kernel about the machine | registers | registers and the BIOS's memory map (unverified) | the memory map and ACPI or a device tree | the boot-information block |
| Starting other processors | none | INIT and START-UP signals | the same | a write to a start register |

![The PC path beside the pdp64 path](figures/boot-pc-vs-pdp64.svg)

## 4.3 What takes the place of a BIOS

**4.3.1** The pdp64's "BIOS" is the controller chip's boot ROM and its monitor. It brings up the machine, loads the first block, and offers a console monitor when nothing boots. It has no resident services and nothing is called after boot. *(P)*

**4.3.2** The boot software is open source and part of the specification: the ROM and monitor, the first-block program, the second-stage loader and the boot tools. *(D)*

**4.3.3** Everything in the project, the boot software included, is under the BSD 2-clause licence. *(D)*

**Why there are stages.** The chain is a ROM, a first block, a second stage and a kernel, and each exists because the one before it is too small to do the next one's job. The ROM sits in the controller chip, so every byte of it costs silicon: it knows how to read one block from the boot devices and nothing else. The first block is one block, 512 bytes, and under a GPT only the 446 of the protective MBR's code area are its own (4.5): it can hold a short list of where the next program lies on the disk and the few instructions that read it. Only the second stage is big enough to understand a file system, the partition table and the label, because it is an ordinary program in C, loaded from the disk, of whatever size it needs. The kernel is then loaded by a program that can find it by name and fill in what it needs to be told. The PDP-11 had the same chain with the partition table missing (the `#` and `:` prompts of 4.1). Each stage in the figure knows one more thing than the one before, and hands on a little:

![The boot stages as a chain](figures/boot-stages.svg)

**Why open source, and why it is in the specification.** The author's words (errata 47, 2026-10-22): "we'll have an open source boot sector boot loader as part of the spec; that is part of the spec that the boot loader/bios is open source." On a PC the firmware that ships (a BIOS, or a UEFI implementation: the UEFI specification itself is published, 4.9) is typically a vendor's build, whose source the owner does not have (unverified), at the bottom of the chain, running before anything the owner can inspect, and kept resident afterwards (4.2). In the pdp64 every stage after the controller's own sequencer is a published source file built by the project's own compiler, and the ROM and monitor of the controller are in the same position, so there is no closed program at the root of the chain of trust. The licence is the BSD 2-clause licence of the whole project (errata 48: "bsd license for everything").

*Commentary.* **Precedent.** A BIOS did four jobs: hardware bring-up and self-test, the first code (read the boot sector and jump), a runtime library of device services called by software interrupt (the "I/O" in its name), and configuration. UEFI replaced the second and third with a loader file and a set of boot and runtime services, and the other architectures have the same roles under other names: Open Firmware on SPARC and PowerPC, U-Boot with trusted firmware on ARM, OpenSBI on RISC-V, the SRM console on Alpha, the console processor on the VAX, and the boot ROMs and `ODT` monitor on the PDP-11. **Trade-offs.** The pdp64 needs only the first, second and fourth jobs in a small form. The third disappears because every device speaks virtio through one transport (chapter 2), so the loader and the kernel share one driver and the loader needs no firmware to read a disk. The cost is that the second-stage loader carries its own driver for the boot disk, which is small because a virtio device is a handful of structures. **Improvements.** There is no firmware API to specify, no compatibility layer, no resident management code and no closed blob at the bottom of the trust chain. **Benefits.** The failure cases reduce to one: the first block did not load, and the monitor is the recovery. **Modern comparables.** x86 firmware keeps resident system-management code that the operating system cannot see; arm64 and RISC-V servers need trusted firmware and, usually, UEFI beside it. **Impact.** *Kernel:* There are no firmware services to call or to bug-fix. *Compiler:* The ROM, loader and tools are built by the project's own compiler. *Hardware:* A boot ROM of a few hundred bytes to a few kilobytes, with a driver per boot device.

## 4.4 The reset state and the first block

**What happens at power-on.** The **controller chip** (the chip that holds the boot ROM, `boot.md`) brings up the memory and holds every core in **reset** (a state in which a core executes nothing and keeps no state). The ROM runs on core 0. On the PDP-11 the equivalent was the processor's own power-up sequence and the ROM or the front panel; here it is a small program in the controller, and it does five things, in this order: find a boot device, read block 0 from it into low memory, check that it looks like a boot block, set core 0's registers, and start core 0 at the block. If it cannot find a device or the block is not a boot block, it runs the monitor (4.10). In pseudocode, the ROM is this:

```
rom_entry():                                  # core 0; every other core is held in reset
    quick_memory_check()                      # the monitor's short test of the first pages
    for dev in boot_order:                    # disk or flash, then SD card, then the serial line (4.4.1)
        if not bring_up(dev): continue        # enumerate the bus, find the function, handshake (4.8)
        if not read_block(dev, 0, LOAD):      # LOAD = 0x1000 in this chapter's example (4.4.2)
            continue
        if byte[LOAD + 510] != 0x55 or byte[LOAD + 511] != 0xAA:
            continue                          # not a boot block: try the next device
        info = fill_boot_info(dev)            # memory ranges, cores, root complex, device, console (4.6)
        core0.mode = KERNEL; core0.priority = 7; core0.translation = off; core0.VBR = 0
        core0.guard = clear                   # the user-memory guard
        core0.r0 = number_of(dev)             # which device it came from
        core0.r1 = info                       # the boot-information block
        core0.r14 = 0x10000                   # the top of the first 64 KB of memory
        core0.all_other_registers = 0
        core0.pc = LOAD                       # the first instruction of block 0
        return                                # core 0 now runs the block; the ROM is done
    monitor()                                 # nothing booted: the console monitor (4.10)

read_block(dev, n, address):                  # the standard disk: one virtio-blk request (5.5.1)
    build a three-descriptor chain: request header (type = read, sector = n),
                                    a 512-byte buffer at `address`, a one-byte status
    FENCE; write the queue's doorbell; poll the used ring until the chain returns
    return status == OK
```

The ROM polls (checks in a loop) and does not use interrupts, because no interrupt controller is set up yet. It needs a driver for each kind of boot device, which for the standard disk is the virtio-blk reader of chapter 5: find the function in the bus's configuration space, set up one queue and read one block. Which device comes first, and how the ROM names a device in `r0`, are not specified (the order of decision F10 of `decisions-pending.md` is open after the disk).

**The first few pages of memory.** At the moment core 0 starts, memory looks like this. The **vector table** (the table of handlers that an exception or an interrupt jumps through, chapter 6) is **one whole page**, 512 entries of 8 bytes, at address 0, because the system register `VBR` (vector base register) is zero at reset; the PDP-11's was a fixed table of a few hundred bytes at 0 to 0377, and its boot programs lived elsewhere. The author's own summary of the PDP-11 way (2026-10-22) was "load 512 byte block 0 then jmp 0", which he called "not precisely true, but directionally true"; here the "jmp 0" becomes a jump to the address block 0 was loaded to, because the first page now holds the vectors. Block 0 is loaded **above** the table, at 0x1000 in this chapter's example (the address is "to be chosen"; `docs/boot.md`), so that the first stage can run without overwriting the vectors. The stack pointer `r14` starts at the top of the first 64 KB of memory, so the first stage has a stack before it has written one instruction. `r1` points at the **boot-information block**, the description of the machine (4.6). The author's rule of errata 102 is that no device window is mapped in **the first few pages**, where "the boot stuff is loaded": how many pages that is, is not decided.

![Memory when block 0 is loaded](figures/boot-block0-memory.svg)

**4.4.1** At reset the controller brings up memory, holds every core in reset, and looks for a boot device in a fixed order: disk or flash, then SD card, then the serial line. *(P)*

**4.4.2** It reads block 0 of the first device that answers (for the standard disk, a virtio-blk read request) into low memory, checks the `0x55AA` signature in the last two bytes, and starts core 0 at that address. It does not parse a partition table. *(P)*

**4.4.3** Core 0 starts in kernel mode at priority 7 with translation off (every address physical), `VBR` zero and the user-memory guard clear; `r0` holds the boot device number, `r1` the address of the boot-information block, `r14` the top of the first 64 KB of memory, and the other registers are zero. *(P)* The first few pages of the physical address space are reserved for the boot code and boot data, and no device window is mapped there (2.3.6, *(D)*); how many pages is not decided. *(P)*

**4.4.4** If no boot device answers, or a key is held at power-up, the monitor runs on the serial console. *(P)*

**What is not specified here.** Where block 0 is loaded (0x1000 is an illustration); how the ROM finds the boot device's windows before any software has assigned them (2.4.1 says the processor assigns windows; the ROM is the first software to do it, and the repository does not say where it puts them or whether it leaves them for the kernel); which of the boot-information block's fields the ROM fills in and which the second stage adds (the natural reading, since the ROM knows the memory it brought up, the cores and the device, is that the ROM fills the block and the second stage adds the command line and the screen, 4.6; not stated); and the number of reserved pages.

*Commentary.* **Precedent.** The PDP-11 read block 0 of the boot device into low memory and jumped to it, from a boot ROM or a few words keyed in on the front panel; the VAX console processor did the same with the boot block and passed the boot device in registers; the mainframe's IPL record and the Alpha console's boot block are the same idea. In V7M the block-0 program is about 285 lines of PDP-11 assembler that read a pathname and loaded the second stage, `boot`, a C program of 272 lines (4.1; the boot review took the 250-line block-0 program for the second stage). **Trade-offs.** A boot ROM with a driver per boot device is more code in the controller than a "jump to a fixed flash address" scheme, and much less than firmware; the first block must fit in one sector. **Improvements.** The reset state is specified in full, where the earlier machines left it to the console. **Benefits.** The first stage is the same on every board. **Modern comparables.** A PC's BIOS reads one 512-byte sector; ARM boards load a first-stage loader from the boot medium; UEFI runs a file from a FAT partition. **Impact.** *Kernel:* The reset state is fully specified, so the first kernel code makes no guesses. *Compiler:* The first block is 446 bytes of assembler. *Hardware:* The ROM reads one block and starts one core.

## 4.5 The disk: a GPT around the BSD label

**What a partition is, and why V7 had none on the disk.** A disk is one long run of blocks, and a computer wants several regions of it: a root file system, a swap area, a place for the users' files. A **partition** is such a region, a named range of blocks. Something has to record where each begins and ends, and there are three places to put the record. V7 put it **in the kernel**: the disk driver compiles in a table, `hp_sizes[8]` in `hp.c`, eight pairs of a block count and a first cylinder, so changing the layout means editing the driver and building a new kernel; 4.3BSD kept that arrangement. The 1988 4.3BSD-Tahoe put it **on the disk**: a **disk label**, a small structure written in one of the first blocks that holds the disk's geometry and a table of its partitions; its header says "the label is in block 0 or 1, possibly offset from the beginning to leave room for a bootstrap", with the magic number `0x82564557` that marks it as a label. 2.11BSD's block 0 holds the bootstrap and its block 1 the label, the same two places as here. OpenBSD's label is its direct descendant, with the same magic number, **16 partitions** (`MAXPARTITIONS16`) and sector counts beyond 32 bits (fields such as `d_secperunith` hold the high part). The third place is the PC's: a **table in the first sector** (the MBR table of 4.2, then the GPT).

**Why the pdp64 has both a GPT and a label.** The author's words (errata 50, 2026-10-22): "we will have the gpt wrapper for the disk label." The disk carries a GPT with a protective MBR, so that other operating systems and partitioning tools recognise it, and the operating system's own partition (the OpenBSD type, `GPT_UUID_OPENBSD`) holds the BSD label, which says where the root file system, swap and the rest are. The label alone would have been smaller and would have been unreadable to everything else; the wrapper costs a reader for the GPT in the second stage and the kernel. And the author added (errata 51, "follow the majority as far as boot block offset"): inside the OS partition the label is at **sector 1, offset 0**, the sector that most of OpenBSD's ports choose, leaving sector 0 for a boot block.

**The first stage lives in the protective MBR.** Block 0 of a GPT disk is the protective MBR, 512 bytes: 446 bytes of code, then the table (one entry, of type `0xEE`), then `0xAA55` (that is, the bytes `0x55` then `0xAA`, which is the `0x55AA` of 4.4.2). So the first stage has 446 bytes for itself. It cannot understand a GPT or a file system in that space, and does not try: it carries a **block list**, three numbers for each piece of the second stage (the first block, the number of blocks, the address to load them at), written into its own code area by the **`installboot`** tool when the system is installed, and it reads those blocks and jumps to the first. This is a pattern the BSD systems already use: OpenBSD's `installboot(8)` page for the sparc says the first-stage program "loads the second stage program from a set of filesystem block numbers that have been hard-coded into it by the installboot program", and on the PC `installboot` patches `biosboot` with the location of `/boot` and "must be re-run whenever `boot(8)` is changed, as its inode may change" (read in source). The boot-code bytes of the MBR are the only place the pdp64 puts block-list data, so a damaged GPT cannot stop the machine reaching the second stage, which can repair it.

```
first_stage():                                # at LOAD (0x1000): 446 bytes of code plus the block list
    # entering state: kernel mode, priority 7, r0 = boot device, r1 = boot-information block, r14 = a stack
    for entry in block_list:                  # entries written by installboot: (start, count, address)
        read_blocks(r0, entry.start, entry.count, entry.address)     # (see the open question below)
        if failed: goto monitor_or_halt       # what to do on failure is not specified
    jump to block_list[0].address             # the second stage, with r0 and r1 unchanged
```

The pseudocode hides a hard question that the repository does not answer: **how the first stage reads blocks.** 4.3.1 says the ROM offers no services after boot, and a virtio-blk read needs a queue, three descriptors, a doorbell and a poll (4.4); can that fit in 446 bytes beside the list? The PDP-11 primary bootstrap carried its own disk driver (the `hpcs1` and `hpcs2` writes of 4.1) and the PC's called the BIOS. The pdp64 has three ways out, none decided: the first stage contains a small polled virtio-blk reader of its own (the PDP-11 way, and consistent with 4.3.1; its size on the pdp64 is unknown: nothing has been assembled); or the ROM leaves a read routine and tells the first stage where it is (a firmware call in miniature, against 4.3.1); or the ROM loads more than block 0 (the whole 8 KB boot area of 4.5.3, say), so the first stage has room to carry the reader. The question is in section 4.13.

**4.5.1** The disk carries a GUID partition table with a protective MBR; the operating system's own partition holds the BSD disk label, which names the root, swap and other partitions. *(D)*

**4.5.2** Block 0 is the protective MBR, so the first stage lives in its 446 boot-code bytes, carrying a short block list (start block, count, load address) to the second stage; neither the ROM nor the first stage parses the GPT. *(P)*

**4.5.3** Inside the BSD partition, the label is at sector 1, offset 0; the boot area is 8192 bytes at the start of the partition; the file system begins after it, its superblock at offset 8192. *(D)*

| Sector (512 bytes) of the BSD partition | Contents |
|---|---|
| 0 | the partition's own boot block |
| 1 | the disk label, at offset 0 |
| 2 to 15 | the rest of the 8 KB boot area |
| 16 on | the file system, superblock at offset 8192 |

**4.5.4** Sector counts are 64-bit throughout; the label has 16 partitions and its sizes carry high fields beyond 32 bits. *(D)*

![The protective MBR, the GPT and the disk label](figures/boot-disk-layout.svg)

The **superblock** (the file system's first record: its size, its block size and where its tables are) sits at byte 8192 of the partition, after the 8 KB boot area that the BSD tradition (`BBSIZE`) reserves for the bootstraps, whose header says that the area holds "primary (block 0) and secondary (block 1-15) bootstraps". The second stage can therefore live in the boot area, in a small boot partition, or as a file in the root file system; whether a dedicated boot partition is needed at all is open (4.13), since the block list can point at any of them.

*Commentary.* **Precedent.** V7 had no partition table on the disk: each driver compiled in an array of eight sizes and starting cylinders (`hp_sizes[8]` in `hp.c`), and changing the layout meant recompiling the kernel. The disk label arrived with 4.3BSD-Tahoe in 1988, in sector 0 or 1 "possibly offset from the beginning to leave room for a bootstrap", with the magic number `0x82564557`; OpenBSD's label is its descendant, with the same magic number, 16 partitions and 64-bit sizes. In the OpenBSD tree seven architecture headers put the label at sector 1 offset 0 (amd64, i386, arm, arm64, riscv64, hppa, powerpc64); Alpha and SPARC64 put it at sector 0. The PC used the MBR, a four-partition table in sector 0 with 446 bytes of boot code, and UEFI requires the GPT, whose header is in the second block, with a backup at the end of the disk and a protective MBR in block 0. **Trade-offs.** The label alone would have been the smallest design and would have been unreadable to other systems' tools; the GPT wrapper costs a GPT reader in the second stage and the kernel (OpenBSD's kernel already has one) and puts the protective MBR in block 0, and gives a disk that other operating systems and partitioning tools recognise. Following the majority on the offsets means the port adds one header of a dozen lines. **Improvements.** The first stage does not depend on a GPT that may be damaged, so a corrupted table cannot stop the machine reaching the second stage, which can repair it. **Benefits.** The label code, `disklabel`, `newfs` and `installboot` come with OpenBSD. **Modern comparables.** BSDs on UEFI machines use a GPT with the label inside an OpenBSD-type partition and a FAT partition for the loader; Linux has no scheme of its own. **Impact.** *Kernel:* The label code, `disklabel`, `newfs` and `installboot` come with OpenBSD. *Compiler:* None. *Hardware:* None.

## 4.6 The second stage and the hand-off

**What the second stage is for.** The first stage has done one thing: put a bigger program in memory. The second stage is that program, and it does what the PDP-11's `boot` did, with more to read: it finds the disk, reads the partition table, reads the label, finds the root file system, finds the kernel by name in it, loads the kernel into memory, and enters it. Because it is written in C and loaded from disk it can be as large as it needs and be replaced by copying a file. It has its own drivers (the virtio-blk reader, now complete) and no firmware to call. As a sketch:

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
    info.video = framebuffer if we set one up (4.6.4)
    info.checksum = checksum(info)
    jump elf.entry with r0 = boot device, r1 = info     # still kernel mode, priority 7, translation off
```

**The hand-off: how the kernel learns about the machine.** The PDP-11 had four registers and a kernel built for the machine. A kernel that is to run on any pdp64 needs to be told: how much memory there is and where it lies (ranges, since memory is not always one block), how many cores there are, where the bus's root complex is (so that it can **enumerate**, walk the bus and list what is attached, 2.4), which device it was loaded from, where the console is, and the command line. The way to tell it is a **boot-information block**, a structure in memory whose address is in `r1`. Other machines tell the kernel with larger things: the VAX passed a **restart parameter block** (a record of the machine's state, fixed in layout; in the 4.3BSD source on this machine it is a page in low memory that a restart after a crash runs a dump routine from, and what DEC's own boot program passed is unverified), the Alpha a **hardware restart parameter block** (the same idea), and x86 and ARM servers pass **ACPI tables**, while arm64 and RISC-V pass a **device tree**; an operating system for several of them has to carry a parser for each. The pdp64's hand-off is small because the bus describes its own devices: the block names memory, cores, the root complex, the boot device and console, and the screen if one was set up, and everything else the kernel finds by enumeration.

![The boot-information block](figures/boot-bootinfo.svg)

**4.6.1** The second stage is a program in C that understands the root file system, reads the GPT and the label, loads `/bsd` (an ELF file) and jumps to it with `r0` and `r1` as before and a command line in the boot-information block. *(P)*

**4.6.2** The boot-information block names the memory ranges, the core count, the address of the root complex and the identity of the boot device and the console; the kernel enumerates every other device by PCI Express enumeration (section 2.4). *(P)*

**4.6.3** The block's layout is defined once, in a grammar from which the headers are generated, and carries a checksum and a version. *(P)*

**4.6.4** The boot-information block carries the video device's base address, size, pitch and pixel format when the boot loader has set it up, and nothing about the device's clock or power state is changed behind the kernel: its pixel clock stays up until the kernel's driver owns the device. *(D)*

Statement 4.6.4 exists because of a lesson the PC learned the hard way (the loader sets up a picture so that the boot messages are visible, and the kernel must be able to keep drawing on it until its own driver takes over, without the screen flickering or going blank): the **framebuffer** the loader set up is described in the block, and the device is left as it is.

*Commentary.* **Precedent.** The VAX passed a restart parameter block, the Alpha a hardware restart parameter block, both fixed-layout records of the machine; the PDP-11 configured the kernel for the machine at build time and probed device addresses; x86 uses ACPI tables, and arm64 and RISC-V use a device tree. **Trade-offs.** A fixed-layout block with a checksum has two failure cases (bad checksum, unknown version), against the parser a device tree or ACPI requires; a device tree has the advantage that OpenBSD's arm64 and riscv64 ports already parse one and attach drivers from it, which could save kernel code if the port reuses many of their drivers. **Improvements.** Because the bus describes its own devices, the block shrinks to memory, cores and the bus controller's address. **Benefits.** The hand-off is a struct; the generated header cannot disagree with the loader. **Modern comparables.** The device tree and ACPI are the two standard answers. **Impact.** *Kernel:* The hand-off is a structure the kernel reads. *Compiler:* The header is generated from one grammar, so it cannot drift from the loader. *Hardware:* None.

## 4.7 Starting the other cores

**The problem the PDP-11 did not have.** A PDP-11 had one processor, so "start the machine" was one thing. A pdp64 may have several **cores** (processors on one chip; chapter 7), and at reset only one of them, core 0, runs the boot code. The others have to be started by the kernel, each with its own stack and its own idea of who it is. On the PC this is a famous mess. The x86 boot core sends special signals through the interrupt controller (INIT and START-UP signals, which Linux's comment calls the INIT, INIT, STARTUP sequence), the START-UP carrying an address below one megabyte, and the other core wakes in the 8086's **real mode** (4.2) at that address, 16 bits and one megabyte, and a hand-written **trampoline** (a short program that takes a processor from a limited mode into its full one, by switching it through two more modes) must walk it into 64-bit mode before it can run the kernel: the Linux `smpboot.c` that does this is 1,528 lines and the real-mode code another 1,258 (measured in the boot review, `boot.md`, from Linux `7be4bc52`). arm64 asks firmware, through a call called PSCI, in 124 lines, or has the waiting cores **spin** (loop on a word in memory) on a **spin table** until the boot core writes an address there, in 127; RISC-V asks the firmware to start a **hart** (its word for a core) in 108 lines or spins in 58. The VAX's console processor started the VAX's other processors (unverified).

**The pdp64's rule: one register write.** A pdp64 core has no mode ladder, so it can start in its normal mode at any address. The controller holds every core but core 0 in reset; to start core *n*, the kernel writes, to a register block in the controller that belongs to core *n*, the address where the core should begin and one argument, and the controller releases the core into **kernel mode at priority 7** with its core number in `r0` and the argument in `r1`. The kernel's convention for the argument is a pointer to a structure that belongs to that core (its stack, its per-CPU data). A core that sticks is reset by a write to a core-reset register, and started again. In pseudocode, the kernel side and the new core's side:

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

The cost is small: one register block in the controller, with a start register and a reset hold for each core. The core does not start with translation set up or a stack of its own; the kernel's entry code does that in the first few instructions, as the first kernel does (6.12). Whether a started core begins with translation off and what `MMUCTL` it sees are not specified.

**4.7.1** The controller holds every core except core 0 in reset; a write to a core's start register in the controller gives it an entry address and an argument and releases it into kernel mode at priority 7, with its core number in `r0` and the argument in `r1`. *(P)*

**4.7.2** A stuck core is reset by a write to a core-reset register. *(P)*

*What the author and the other chapters say.* This is option 1 of boot decision B2 and of decision R2 of `decisions-pending.md`, which recommend it and leave it proposed (the other options were the x86 signals, a firmware call, a spin table and a table that all cores start from; none was chosen); the SMP chapter states the same rule as 7.8.1 and loads `r0` only, where 4.7.1 loads `r1` too, a difference to settle (4.13). Waiting uses `WFE` and `SEV` (7.6), and a signal from one core to another, an **inter-processor interrupt**, is a write to a per-core register of the interrupt controller (7.8.2).

*Commentary.* **Precedent.** On x86 the boot core sends INIT and START-UP interrupts through the APIC and each other core wakes in 16-bit real mode, then has to be walked through protected mode into 64-bit mode by a trampoline: the Linux `smpboot.c` is 1,528 lines and the real-mode code another 1,258. arm64 uses a firmware call (PSCI) in 124 lines or a spin table in 127; RISC-V asks the firmware to start a hart in 108 lines or spins in 58. The VAX's console processor started its other processors. **Trade-offs.** The pdp64 has no mode ladder, so a core can start in its normal mode at any address and the whole protocol is one register write, at the cost of a small register block in the controller. **Improvements.** There is no trampoline and no firmware call. **Benefits.** Fewer lines than any system measured and one recovery path, a core reset. **Modern comparables.** PSCI, the SBI hart-state calls, and x86's INIT and START-UP sequence. **Impact.** *Kernel:* Starting a core is a register write and a device start is `INIT`. *Compiler:* None. *Hardware:* A start register and a reset hold per core; an `INIT` bit per device.

## 4.8 Starting the devices

**The INIT bit.** On the Unibus every device had a **control and status register** (CSR) with a bit that told the device "initialise yourself" and a bit that said it was ready: you wrote `INIT`, waited for `READY`, and the device was in a known state (the RK11 of chapter 2 has `GO` and `RDY` in its CSR). All the work of bringing the device to life happened behind the register, in the device's own logic. The pdp64 keeps that idea and turns it into a conversation: under virtio (chapter 2, 2.6.3) the driver writes **zero** to the device's `device_status` byte, which resets it, then sets the bits `ACKNOWLEDGE`, `DRIVER`, `FEATURES_OK` and `DRIVER_OK` in order, each meaning "I have got this far", and the device answers by refusing or accepting the features the driver chose. That is the `INIT` and `READY` of the CSR spread over a few steps, and the pseudocode of 2.6.3, `init_device(fn)`, is the pdp64's device start. At boot it is run by the ROM for the boot disk (4.4), by the second stage again for the devices it uses, and by each kernel driver at attach.

**Firmware for a device.** Some devices contain a small processor of their own and need a program, **firmware**, loaded into them before they work: a network or wireless card is the usual case, a graphics device another. On a PC the driver loads the blob at attach time from a file (Linux's `request_firmware` and OpenBSD's `firmload(9)`, unverified), and the files come in a separate package. The pdp64 proposal is that such a device is given its firmware through a descriptor operation (a request on the device's queue, or a descriptor that gives the device the address and length of an image in memory, with a small header the device checks: its identifier, a version, a length and a checksum), **once the root file system is available**, and that a device the boot depends on needs none: the boot disk, the console and the interrupt controller must work from their built-in logic alone, so that no device waits for firmware that is on the disk it controls.

```
start_device(dev):                            # at boot or at attach
    init_device(dev)                          # the handshake of 2.6.3; reset first
    if dev.needs_firmware:                    # a device the boot depends on never does
        image = read_file(root_fs, firmware_name(dev))      # the file system must be up (4.6)
        check image.header: device id, version, length, checksum
        submit a descriptor chain giving dev the address and length of image
        wait for the device to answer; if it refuses, mark the device failed
```

**4.8.1** A device is initialised by writing its `INIT` bit and waiting for `READY`; a device that wants firmware is given it through a descriptor operation once the root file system is available, and a device the boot depends on needs no firmware. *(P)*

*What the statement predates.* 4.8.1 was written when devices were eight registers with an `INIT` bit and a `READY` bit (the decision of errata 29, which errata 95 withdrew in favour of virtio); the `device_status` handshake above is how it reads under virtio. How a virtio device is handed firmware is not specified: virtio has no firmware operation of its own, so a request type, or a separate device, would have to be defined (4.13).

*Commentary.* **Precedent.** PCI Express devices are initialised through their configuration space and per-device driver code; the Unibus's CSR with its `INIT` bit and nothing more was the whole of it on the PDP-11; the VAX console and some adapters loaded microcode from storage (unverified). **Trade-offs.** A reset bit and a status register make the simplest device, with one failure case, a timeout; a firmware window lets a device be cheap (no flash) and makes an update a file replacement, at the cost of a header format and a device that rejects a wrong image safely; a device whose firmware is on a disk it must itself read cannot start, which is why the boot-critical devices are excluded. **Benefits.** One start convention for every device. **Modern comparables.** `request_firmware` and `firmload(9)`; NVMe's firmware-download command, which needs a working queue first. **Impact.** *Kernel:* Starting a core is a register write and a device start is `INIT`. *Compiler:* None. *Hardware:* An `INIT` bit per device.

## 4.9 Why UEFI is not used

**4.9.1** The pdp64 does not use UEFI: its boot is the block-0 route of sections 4.4 and 4.5, its hand-off is the boot-information block, and its devices describe themselves. UEFI firmware is not part of the specification and is not built. *(D)*

**4.9.2** The hand-off and the second stage are kept simple enough that a UEFI shim could be written by someone who wanted one. *(D)*

Both statements are the author's decision of 2026-11-10 (errata 109). The record, in his words. On 2026-10-22 he asked, of boot, "look into uefi; is it worth it at all? can't we do what pdp11 used to do, load 512 byte block 0 then jmp 0? (not precisely true, but directionally true)", and asked how UEFI plays into partitions and the GPT; the review (`boot.md`) answered that UEFI was not worth it as the machine's own boot, and sections 4.6.1 and 4.6.2 of the earlier text were the assistant's proposals, tagged *(P)*, never a decision. On 2026-11-10 he asked "i thought we did decide to allow uefi? check all the threads where we discussed it" (no decision to allow UEFI was found in any recorded message), then "or we kept the originnal simple pdp11 boot block method?", and, given three options, chose "option 2, block 0 with a shim possible". So the pdp64 boots by the block-0 route; a UEFI shim is not built; and the hand-off and second stage are kept simple enough that someone who wanted one could write it.

**Is UEFI an open specification, and what does an open-source system do with it?** The author asked, after the decision (2026-11-10): "if uefi isn't an open spec how are all the open source os supporting it? it requires binary firmware blobs?" The honest answer, by what could be checked:

* **The specification** is published by the UEFI Forum, the industry body that maintains it, and can be read without charge (general knowledge, unverified: the specification is not on this machine, and whether implementing it needs a membership, a licence or a compliance test is not known here). So it is not a closed specification; the closed part is elsewhere.
* **An open-source implementation exists.** EDK II, the TianoCore project's reference implementation, is under the BSD-2-Clause-Patent licence (read: `/home/david/claude/qemu-src/pc-bios/edk2-licenses.txt`, and the Debian `ovmf` package's `/usr/share/doc/ovmf/copyright`, "Upstream-Name: edk2"). Built images are on this machine (QEMU's `pc-bios/edk2-*.fd.bz2` and `/usr/share/OVMF`, including `OVMF_CODE_4M.secboot.fd`), so an emulated PC boots under open firmware. The source is not on this machine (the `roms/edk2` directory is empty), so nothing about its size or contents was read here.
* **Open-source operating systems write the loader side.** OpenBSD's `efiboot` (read in source), Linux and NetBSD each contain a program or stub that runs on top of firmware that is already on the machine and calls its services (4.9, the table below); they do not ship the firmware. A loader needs no blob.
* **The proprietary blobs are in the firmware shipped on real PCs:** the vendor's firmware builds, and the CPU vendor's initialisation code that brings up memory and the chipset, which many boards include as a binary (unverified general knowledge: not on this machine). That is a property of how PCs are made, not of the UEFI specification.
* **Secure Boot** adds a chain of signed loaders and keys kept in the firmware's variable store, so that firmware runs only a loader that is signed by a key it trusts (unverified; the existence of the `secboot` images above is the only thing seen here).

The author's conclusion (2026-11-10): "I guess leaving the door open to uefe support but having the classic mbr fallback, gpt wrapper is a good choice then." That is a **confirmation of option 2** of errata 109, not a new decision (errata 110). The two routes share one disk: block 0 of the pdp64 disk already has the protective MBR and GPT layout (errata 50, 4.5), so the classic route (the ROM reads block 0, the first stage in its 446 bytes) and a future UEFI route (a firmware, or the shim, reads the GPT and a FAT system partition) read the same disk without repartitioning it.

**What a shim is, and what it is not.** The author asked, "not sure why firmware and coff are needed for uefi, with virtio native that shuld be minimal, no?" and then, "yes, state the shim's real scope." The answer in two parts. *First, virtio removes most of the driver mass* that a full UEFI firmware carries (a firmware ships drivers for every disk, network card and screen it might meet; the pdp64 has one device interface), and the shim needs only the drivers of the second stage, which already exist. *Second, two things stay,* and they are the shim's real scope:

1. **PE/COFF.** The UEFI specification requires a UEFI application to be a PE32+ image (the 64-bit form of the PE/COFF file of 4.2); this is a property of the **loader programs**, not of the firmware. To run an existing UEFI loader, such as OpenBSD's `efiboot`, it has to be built as a PE/COFF image *for the pdp64*, so the toolchain has to produce one, and a **machine-type code** for the pdp64 (a 16-bit number in the image's header that names the processor: OpenBSD's arm64 loader says `IMAGE_FILE_MACHINE_ARM64 0xaa64`, read in source) would have to be assigned by the owners of the UEFI specification. Both of those are unverified general knowledge (the specification is not on this machine). What the sources on this machine do show is that this need not be a linker feature: OpenBSD's arm64 loader is linked as an ordinary ELF file and wrapped as a PE32+ image by a header written by hand in assembler (`start.S`, 176 lines, "on arm64 we need to do it ourselves") plus a small self-relocator (`self_reloc.c`, 124 lines), with `objcopy` doing the rest (measured, read in source). Whatever the container, the loader is itself a program that must be compiled for the pdp64.
2. **A small services layer.** The loader calls a table of services, and the shim has to provide the few that loaders use: memory allocation and the **memory map**; reading a file from the boot partition; the console and the **graphics output protocol** (a framebuffer to draw on); **exit boot services**; and a runtime clock and reset. All of it over virtio. And a **hand-off** of a device description to the kernel in the form such a loader expects: a device tree or tables.

**How many services, counted.** OpenBSD's own UEFI loaders in `/home/david/claude/kernel-src/openbsd/sys/arch/*/stand/efiboot` call the following (measured by counting the distinct `BS->`, `RS->` and console calls in the `.c` files; the number after the name is the count of call sites in the amd64 loader):

| Boot services (`BS->`) | Runtime services (`RS->`) | Console and file protocols (through a handle) |
|---|---|---|
| `HandleProtocol` 13, `AllocatePages` 7, `LocateHandle` 5, `LocateProtocol` 2, `LocateHandleBuffer` 2, `GetMemoryMap` 2, `FreePages` 2, `WaitForEvent`, `SetWatchdogTimer`, `FreePool`, `AllocatePool`, `Exit`, `ExitBootServices` (1 each); the arm64 and riscv64 loaders add `SetTimer`, `CreateEvent`, `CloseEvent` | `ResetSystem` 3, `GetVariable` 3, `SetVariable` 2, `GetTime` 1 | the text console (`OutputString`, `ReadKeyStroke`, `SetMode`, `QueryMode`, ...), the disk (`ReadBlocks`, `WriteBlocks`), files (`Open`, `Read`, `Write`, `Close`, `SetPosition`, `GetInfo`), the network (`Mtftp`, `Transmit`, `Receive`), the graphics output protocol, the random-number protocol |

That is about fifteen to seventeen distinct boot and runtime calls in each loader. It is a count of what **one** loader uses and not a specification of what a shim must offer: another loader would use others, and the person who writes the shim reads the loader. One more fact from the same source shows the calling convention: the loader re-reads the memory map and calls `ExitBootServices` with the map's key, and retries once if the call fails, because the call refuses a stale key (`efiboot.c`, read in source).

**A sketch of the shim (an illustration; no such code exists).** What the shim does, in C-like pseudocode: the shim is the second stage, loaded by block 0; it builds the services table, loads the loader's PE image, calls it, and answers its calls.

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

**The costs, kept honest.** A shim is **not** a UEFI firmware stack. The boot review's figure of "hundreds of thousands to millions of lines" for a UEFI firmware (`docs/boot.md`, "Is UEFI worth it?") was never confirmed against a source, and it describes a **full firmware stack** such as EDK II, with its phases, its driver model, its variable store and its drivers for every device; a shim is a different and much smaller thing, and that figure is not used as the cost of one. **No count of the shim's lines is given here, because none can be measured on this machine:** no implementation of the UEFI services is present (the `edk2` and `u-boot` directories under the QEMU tree's `roms/` are empty; only EDK II's built images are, 3,653,632 bytes for the x86-64 code image). The measured sizes are those of the loaders that would run on it (OpenBSD's `efiboot` is 4,593 lines for amd64, 7,195 for arm64, 4,513 for riscv64) and, for what a pdp64 build of one would need beside the loader, the 176 lines of header and 124 of relocator above. The costs that remain:

* **A PE/COFF build and a number.** The toolchain emits a PE/COFF image (small, per the precedent above), and a machine-type number must be obtained (unverified).
* **A loader to port.** The loader has to be ported to the pdp64 as any program is, which is the larger part of the work.
* **A services layer.** It has to be written, tested and kept in step with the loaders it serves.
* **Code to trust before the kernel.** The shim is open source (4.3.2), runs only at boot and, unlike a firmware, is not resident afterwards except for the clock and reset.
* **A platform description.** The shim does not remove the need for one (a device tree or tables), which it must build from the boot-information block.

What it does **not** cost is a closed firmware, a variable store, a setup screen or a second boot path in the machine itself: the machine's own boot stays block 0.

*Commentary.* **Precedent.** UEFI is a firmware specification of boot services, runtime services, a memory map, the GPT, the PE/COFF executable format and a driver model, implemented usually by the open-source EDK II or by a vendor. Its aim is that one installer boots on any machine that offers it. OpenBSD's arm64 and riscv64 ports use UEFI and a device tree, and its own loaders for them are 7,195 and 4,513 lines; for amd64 the loaders total 15,440 lines, including a BIOS boot block of 862 lines and a second stage of 189 beside the UEFI loader of 4,593 (all measured). **Trade-offs.** UEFI firmware would let existing generic loaders run unchanged, offers a standard memory map and a secure-boot chain, and costs a great deal of firmware, adds failure modes (variable storage, drivers, boot-order state), enlarges the attack surface, and still needs a device tree or ACPI to describe the devices; a shim gives the first without the rest, at the price of a services layer and a PE/COFF build. **Improvements.** The pdp64 has one architecture and one platform description, which is the case UEFI was not built for, and a decision that leaves a door open for someone who wants to carry an existing loader. **Benefits.** Smaller (principle 1), fewer failures (principle 2), fewer gates and less flash (principle 3), and a shim possible. **Modern comparables.** x86 servers, arm64 servers and RISC-V servers all use UEFI; OpenBSD itself still ships a BIOS-style loader beside the UEFI one on amd64. **Impact.** *Kernel:* No firmware interface, no UEFI services, no memory-map translation in the machine itself; a shim would translate the boot-information block. *Compiler:* No PE/COFF format in the toolchain unless a shim is built; if it is, a header and a relocator. *Hardware:* A smaller flash and no firmware stack.

## 4.10 Recovery

**What to do when nothing boots.** A PDP-11 whose disk was dead was not a dead machine: the console's `ODT` let you examine memory and key a bootstrap in (4.1). The pdp64 keeps the idea and gives it a place. The ROM that reads block 0 (4.4) also contains a **monitor**: a small program that runs on the serial console when no boot device answers, or when a key is held at power-up, and offers a handful of commands: examine and deposit memory and registers, load a program over the serial line, start at an address or from a named device, reset a core, reset the machine. It needs a working serial port and nothing else, so it is also the way to bring up a new board before any boot device works. In pseudocode:

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
            "z"             : write the reset register (a bus-controller write, 2.9.4; what else it resets is not specified)
            otherwise       : print("?")
```

The command letters and the prompt are an illustration. **Watchdog:** a **watchdog** is a hardware timer that counts down and restarts the machine if software does not write to it ("kick" it) in time; a hung kernel stops kicking and is restarted. The PDP-11 had none; a PC's firmware may have one. It is the simplest recovery of all from a hang, and needs about ten lines in the kernel, as `decisions-pending.md` P7 argues when it asks for a bus-controller reset register and a watchdog **in place of** firmware calls: the monitor's reset command writes that register.

**4.10.1** The controller's ROM includes a monitor reached on the serial console when nothing boots: examine and deposit memory and registers, load a program over the serial line, start at an address or from a named device, reset a core, reset the machine. *(P)*

**4.10.2** A hardware watchdog restarts the machine if the kernel hangs. *(P)*

*Commentary.* **Precedent.** The PDP-11's console `ODT`, a monitor in ROM for examining and depositing memory and starting at an address, and the VAX console processor were the way in when nothing booted. **Trade-offs.** A monitor is a few hundred bytes of ROM and needs a working serial port and nothing else. **Benefits.** The same monitor brings up a new board before any boot device works, and it is the simplest recovery path of all: it needs the least code to write. **Modern comparables.** U-Boot's console and OpenSBI's debug console fill this role; PC firmware has a setup screen. **Impact.** *Kernel:* A monitor is the way in when nothing boots. *Compiler:* None. *Hardware:* A serial port and a few hundred bytes of ROM.

## 4.11 Five boots side by side

The author asked (2026-11-10): "also boot would compare pdp11 boot, vax boot, c64 boot, the x86 bios boot with mbr, then finally the gpt/uefi". Those five are his referents, in his order, and this section sets them side by side and puts the pdp64 beside them. Each is a numbered list of steps, a chain with what each stage knows (the figure, then the table), and a mark for how much of it could be checked: **(read)** is read in the sources on this machine, **(repo)** is from the repository's documents, and **(unverified)** is general knowledge, the handbooks and specifications not being here.

![Five boots and the pdp64](figures/boot-five-boots.svg)

**(a) The PDP-11 boot** (4.1).
1. The processor is powered on and does nothing useful by itself; the operator has the console. (unverified)
2. The operator keys in a bootstrap on the front panel, or starts a boot ROM (the M9312 is named in V7M's `htboot.s`) that reads **block 0** of the boot device to low memory and jumps to it. (read: V7M `boot(8)`)
3. Block 0 (`hpuboot.s`) copies itself up, clears memory, starts the disk and prints `#`. (read)
4. The operator types `boot`; the block-0 program finds `/boot` by walking the inodes from the root, loads it and calls it. (read; the page also provides `/boot.bu`, "a backup copy of the bootstrap")
5. `boot` prints `Boot` and `:`; the operator types `hp(0,0)unix`; it loads the file at 0, sets up memory management and enters it with a `trap` instruction. (read)
6. The kernel runs; 2.11BSD's stage passes `r0` cputype, `r1` controller address, `r3` boot device, `r2` a check word. (read)

**(b) The VAX boot** (the 4.3BSD sources on this machine; the console and DEC's own boot program are not).
1. A **console processor** (on the VAX-11/780 a separate small computer) powers up and runs a self-test; it also provides the console commands and starts the other processors on multiprocessor models. (repo: `boot.md`; unverified otherwise)
2. On a boot command the console, or a boot ROM on the smaller models, reads the boot block (block 0) of the device into memory and starts it with registers describing the device. (repo; read for the registers: 4.3BSD-Tahoe `mdec/raboot.c` takes the Unibus adapter number from `r1`, the controller address from `r2`, the unit from `r3` and the flags and partition from `r5`, and says it "should work with any disk using 750 boot rom")
3. That first-level program (`raboot.c`) "loads next 7.5 Kbytes from boot sector of file system" to address `0x50000`: sectors 1 to 15 of the 8 KB boot area (`BOOTLAST` 15), which is where the pdp64's 8 KB boot area (4.5.3) comes from. (read)
4. That second level is `vaxstand/boot.c`: it takes `r10` (the device) and `r11` (the options), prints `Boot` and `:`, opens a file by name (`vmunix` by default) and enters it. (read)
5. The kernel runs. The restart parameter block, `rpb.h`, is in the 4.3BSD source "a page in (very) low core which runs after a crash", a record for a dump routine; what DEC's boot program (VMB, a name from general knowledge) passed is unverified.

**(c) The Commodore 64 boot** (nothing about it is in the repository beyond the machine's description in chapter 3; all of it is unverified general knowledge).
1. The 6510 processor, on reset, reads its start address from the two bytes at `0xFFFC`; they lie in the **KERNAL ROM**, the top 8 KB of memory, so the first code is in ROM and nothing is loaded.
2. The KERNAL's cold-start routine initialises the chips, tests the RAM, sets the vectors and the screen.
3. It looks at `0x8000` for the signature `CBM80`: if a cartridge is plugged in and carries it, the cartridge's own start address is called (**cartridge autostart**).
4. Otherwise it enters the **BASIC ROM's** cold start, which prints its banner and `READY.`
5. The user types `LOAD` and `RUN`: the program comes from the datasette or from the 1541 disk drive, a separate machine with its own processor and ROM.

**(d) The x86 PC with a BIOS and an MBR** (4.2; the OpenBSD loaders are read, the rest is unverified).
1. The processor starts at the **reset vector**, `0xFFFFFFF0`, at the top of the 4 GB space, where the firmware flash is mapped; it is in 16-bit real mode. (unverified)
2. The BIOS runs its self-test (POST), initialises the chipset and memory and runs the **option ROMs** of add-in cards (video, disk). (unverified)
3. It goes through the **boot-device order** and reads the first 512-byte sector, the **MBR**, to `0x7C00`, and checks the signature `0x55AA`; the code in its first 446 bytes runs. (the 446, the table and the signature read in OpenBSD's `disklabel.h`; the address and the order unverified)
4. The MBR code finds the **active** partition in the four-entry table and loads its first sector, the **volume boot record**; OpenBSD's `mbr.S` does this and `biosboot` is the record. (read)
5. That program, using BIOS `INT 13h` for every disk read, loads the next stage, `/boot`, which loads the kernel. (read: `biosboot.S`)
6. The kernel gets the memory map and the machine's description from the loader and from the BIOS. (unverified)

**(e) The GPT and UEFI boot** (4.2, 4.9; OpenBSD's `efiboot` read).
1. The firmware starts (at the reset vector as above, through phases of its own, unverified) and runs its **boot manager**, which reads the **boot variables** from non-volatile memory (**NVRAM**) to learn which loader to run and from where. (unverified; the loaders read and write variables: `GetVariable`, `SetVariable`, read)
2. The firmware reads the GPT, finds the **EFI system partition** (type `GPT_UUID_EFI_SYSTEM`, read) and its **FAT** file system, and opens the loader file by name.
3. The loader is a **PE/COFF** application (read: `start.S` of the arm64 loader); the firmware loads and runs it with a table of boot services.
4. The loader calls boot services (memory, files, console, graphics: read, counted in 4.9), reads its configuration, and picks up the **memory map** and the ACPI or device-tree table (read: `GetMemoryMap`, `EFI_ACPI_TABLE_GUID`, `FDT_TABLE_GUID`).
5. It loads the kernel and calls **exit boot services** with the map's key (read, with the retry), after which the firmware's boot services are gone.
6. The kernel runs with the memory map and the tables. With **Secure Boot** each step above is a signed image checked against keys in the firmware (unverified).

**(f) The pdp64 boot** (4.3 to 4.10, a proposal and a decision, no code). The ROM in the controller chip runs on core 0, reads block 0 through a virtio-blk request, checks `0x55AA`, and starts core 0 at it with `r0`, `r1` and `r14` set (4.4); the first stage, in the protective MBR's 446 bytes, reads the blocks on its list (4.5); the second stage reads the GPT, the label and the root file system, fills in the boot-information block and loads `/bsd` (4.6); the kernel enumerates the bus and starts the other cores by register writes (4.7).

The six side by side. A dagger marks a cell that rests on general knowledge, unverified; the last column says which of the five each property resembles.

| Property | (a) PDP-11 | (b) VAX | (c) C64 | (d) x86 BIOS, MBR | (e) GPT, UEFI | (f) pdp64, and which it resembles |
|---|---|---|---|---|---|---|
| Who runs first | the processor, then the operator's keys or a ROM | the console processor† | the 6510 from its reset vector† | the processor at `0xFFFFFFF0`† | the same, then the firmware† | the ROM on core 0: like (a) and (b), without the operator |
| Where the first code lives | front panel or boot ROM | console ROM and storage† | the KERNAL ROM† | firmware flash† | firmware flash† | a ROM in the controller chip: like (a) and (c) |
| How big the first code may be | a few dozen words (keys), a ROM's size; block 0 of 512 bytes | the boot block; the 750 loaded 7.5 KB next | the ROM's 8 KB† | 446 bytes in the MBR (read) | the loader file, any size† | the ROM's size; 446 bytes in block 0: like (d) |
| How it finds the next stage | block 0 reads a name (`boot`) by walking inodes; `boot` reads `hp(0,0)unix` (read) | the boot block loads sectors 1 to 15; `boot` opens a name (read) | it does not: `LOAD` by the user† | the active flag in the table, then `INT 13h` reads (read) | the boot variables and the GPT's type, then a name on FAT† | a block list in block 0, then the GPT, the label and a name: like (b) and (a) |
| What the hand-off carries | registers `r0` to `r3` (read) | `r10`, `r11`, and others (read) | nothing: the program owns the machine† | registers and the BIOS's memory map† | the memory map and ACPI or a device tree (read) | `r0`, `r1` and the boot-information block: like (a) in registers, like (e) in a description |
| How it is repaired | keys, `ODT`, the backup `/boot.bu` (read for the last) | the console† | the ROM cannot be damaged by storage; a cartridge† | re-write the MBR from another disk† | the firmware's setup and boot manager† | the monitor, a core reset, a watchdog (4.10): like (a); a damaged GPT does not stop the first stage (4.5) |
| What is open source | the BSD and V7 stages (the sources here); ROMs† | the BSD stages (read); the console† | the ROMs are Commodore's† | the loaders, in OpenBSD (read); the BIOS is a vendor's† | the specification is published†; EDK II is BSD-2-Clause-Patent (read, 4.9); shipped firmware often not† | everything, by decision (4.3.2): beyond all five |
| How many stages | 3 (ROM or keys, block 0, `boot`) before the kernel | 3 (console, boot block, `boot`) | 1 (ROM) or 2 with a cartridge† | 4 or more (BIOS, MBR, boot record, `/boot`) (read) | 3 or more, with firmware phases† | 3 (ROM, block 0, second stage): like (a) and (b) |
| What recovery exists | `ODT` and the front panel† | the console† | reset, a cartridge† | the BIOS setup, a rescue disk† | the setup, rescue media, a fallback loader name† | the monitor and the watchdog (4.10), the same disk readable by a UEFI route (4.9) |

The pdp64's boot is, property by property, the PDP-11's and the VAX's: a ROM, a first block, a second stage that finds a file by name, a hand-off in registers. It takes three things from the PC: the protective MBR and its 446 bytes (d), the GPT (e), and, in the boot-information block, a description of the machine (e) that the PDP-11 and the VAX did not pass. It takes from the C64 the ROM that is the first code and cannot be damaged by what is on the storage, and nothing else: the C64 had no second stage, and its user loaded programs by hand. And it differs from all five in that every stage is open source and in that no stage calls a firmware after the ROM.

## 4.12 What was checked, and what was not

The rule of the project is: check, do not guess. For the facts of this chapter about older and other machines, the handbooks and the specifications are not on this machine. What was available, and what each fact rests on:

* **Checked against the Unix sources on this machine** (`/home/david/claude/facetlang/unixtree`): the V7M `boot(8)` page and `sys/mdec/hpuboot.s` (285 lines: its header, `core = 28.`, the copy up, the clear, the `#` prompt, the pathname read, the inode walk from inode 2, the call `jsr pc,*$0`); `sys/sas/boot.c` (272 lines) and the `Boot` and `:` prompts and `device(unit,offset)` names of the page; the V7M tape bootstrap's mention of the M9312 (`sas/htboot.s`, `dev/ts.c`); V7 `hp.c` and `hp_sizes[8]`; the 2.11BSD `boot(8)` page (the 512-byte limit, block zero, the disklabel in block one, `/mdec`) and the header of its `hpuboot.s` (the 512 and 494 bytes); the registers of its `pdpstand/srt0.s` and `pdpstand/boot.c` (`r0` cputype, `r1` csr, `r3` boot device, `r2` the check word); the 4.3BSD-Tahoe `disklabel.h` (the block 0 or 1 comment, `0x82564557`).
* **Checked against the OpenBSD sources on this machine** (`/home/david/claude/kernel-src/openbsd`, commit `2114d7b7`): `sys/sys/disklabel.h` (the MBR: `DOSPARTOFF` 446, four `dos_partition` entries of a flag, a type, a start and a size, the signature at `0x1fe`, types `0xee`, `0xef`, `0xa6`; the GPT: "EFI PART", `gpt_header`, `gpt_partition`, 128 entries of 128 bytes by default, little-endian, the two GUIDs; `DISKMAGIC`, `MAXPARTITIONS16`; the sector for the label); `sys/arch/amd64/stand` (`mbr/mbr.S`, 521 lines, finds the first active partition; `biosboot/biosboot.S`, 862 lines, "roughly 512 bytes of code", calls `INT 0x13`, patched by `installboot`; `boot/`, 189 lines; `libsa`, 6,319 lines; `efiboot`, 4,593 lines); `sys/arch/arm64/stand/efiboot` (7,195 lines, `start.S` of 176 lines with the PE32+ header and `IMAGE_FILE_MACHINE_ARM64 0xaa64`, `self_reloc.c` of 124 lines) and riscv64 (4,513 lines); the counts of the services called by the three `efiboot` loaders; the `ExitBootServices` retry; the seven architecture headers of the label sector. The sparc `installboot(8)` page (the hard-coded block numbers) is in the OpenBSD 4.6 tree under `/home/david/claude/facetlang/unixtree/OpenBSD-4.6`.  The Linux and other counts of 4.7 are those of the boot review (`boot.md`), measured there in Linux `7be4bc52`.
* **Checked for section 4.11:** the 4.3BSD-Tahoe `usr/src/sys/mdec/raboot.c` (registers, the 7.5 KB, `0x50000`, `BOOTLAST`), `usr/src/sys/vaxstand/boot.c` (`r10`, `r11`, `Boot`, `:`, the default `vmunix`) and `usr/src/sys/vax/rpb.h` (the comment), under `/home/david/claude/facetlang/unixtree`; the EDK II licence, BSD-2-Clause-Patent, in `qemu-src/pc-bios/edk2-licenses.txt` and `/usr/share/doc/ovmf/copyright`; the Secure-Boot image names in `/usr/share/OVMF`; OpenBSD's `biosboot.S`, `mbr.S` and `efiboot` for the x86 and UEFI steps marked read. Nothing about the Commodore 64's boot is in the repository: every statement of (c) is general knowledge, unverified, as are the VAX console and VMB, the x86 reset vector and the load address `0x7C00`, the UEFI boot manager and NVRAM variables, Secure Boot, and the publication terms of the UEFI specification.
* **Checked on this machine:** the QEMU tree carries EDK II's built firmware images (`pc-bios/edk2-x86_64-code.fd.bz2` is 3,653,632 bytes uncompressed) and no source of any UEFI implementation (the `edk2` and `u-boot` directories of `roms/` are empty).
* **Checked against the repository:** the statements of this chapter against `docs/errata.md` (47, 48, 50, 51, 95, 101, 102, 103, 104, 109), `docs/boot.md`, `docs/decisions-pending.md` (B2 as R2, P7, F10), chapters 2, 5, 6 and 7 of the manual, and `docs/pdp64-system-architecture.md` section 9.
* **Unverified** (general knowledge, the specifications and handbooks not being on this machine): the front panel's switches and keys and the bootstrap loader of a few words; that the M9312 held one ROM program per device; what `ODT` does, and its name; the date of the IBM PC and of UEFI's arrival; the BIOS's four jobs and its other services (video, keyboard, the memory map); real mode and the 1 MB limit; that the PC's x86 start-up signals are INIT and two START-UP signals carrying an address below 1 MB; that the first stage is loaded at a fixed address by the BIOS; the Commodore 64 boot of 4.11 (reset vector `0xFFFC`, KERNAL, `CBM80` at `0x8000`, BASIC, the datasette and the 1541); the VAX console and VMB; the usual meaning of PSCI, the spin table and the SBI hart calls; that the VAX console processor started the other processors; the Alpha and VAX hand-off blocks; that the UEFI specification requires PE32+ images, FAT on the system partition, the services named, and the use of ACPI or a device tree; that a machine-type code for a new processor would be assigned by the owners of the specification; that Linux's `request_firmware` and OpenBSD's `firmload(9)` work as described; U-Boot's and OpenSBI's consoles.
* **Decided by the author and recorded in `errata.md`:** everything stated as a decision with a tag *(D)*; the pseudocode of this chapter is an illustration, and nothing in it is a decision.

## 4.13 Still open

**Decisions the author has asked for, or that follow from the author's, and that are not made:** (a) the address block 0 is loaded to (0x1000 is the example; errata 102(a)) and how many pages "the first few" are; (b) how the first stage reads blocks: a small reader of its own in 446 bytes, a routine the ROM leaves, or a larger first stage loaded by the ROM (4.5); (c) how the ROM finds and maps the boot device's windows before any software has (4.4); (d) who fills which fields of the boot-information block: the ROM, the second stage, or both (4.4, 4.6); its layout, order and widths (4.6.3); (e) the partition type of the boot partition, and whether a dedicated boot partition is needed at all, since the first stage's block list can point at the second-stage file in the root file system or at the 8 KB boot area (4.5); (f) the device-tree option: whether the boot-information block is replaced or accompanied by a device tree if the OpenBSD arm64 and riscv64 drivers are reused (4.6); (g) the registers of the core start block, whether a started core begins with translation off, and the difference between 4.7.1 (`r0` and `r1`) and 7.8.1 (`r0`) (4.7); (h) how a virtio device is given firmware, and whether the `INIT` and `READY` words of 4.8.1 are to be restated over virtio (4.8); (i) the order of the other boot media after the virtio-blk disk (F10); (j) the monitor's commands, the serial speed and what is kept in non-volatile memory (boot order, serial speed: `boot.md`); (k) the shim: the path of the loader it runs, the services it offers, the machine-type number (4.9), none of which is to be settled until someone wants one.

**Facts still to check against their own documents:** the PDP-11 power-up behaviour, the M9312 boot ROMs and `ODT`; the VAX and Alpha boot protocols and hand-off blocks; the x86 reset vector and START-UP rules; PSCI, the SBI hart calls and the spin table as specified; what the UEFI specification requires of a loader and of firmware, including the machine-type registry; the size of a UEFI services layer, which only an implementation could give.
