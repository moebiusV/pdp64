# 4. Boot, the BIOS, the disk label and the GPT

[← manual index](00-index.md)

**The machine starts the way the PDP-11 did: a small ROM in the controller chip loads one block from the boot device and jumps to it, and every later stage is an ordinary program, open source, compiled by the project's own compiler.** This chapter is written for a reader who has keyed a bootstrap in on a PDP-11 front panel, used a boot ROM, or typed `boot` at the `:` prompt of Unix Version 7 or 2.11BSD, or who is learning computing from the start, and who has not met anything invented after the 1970s: no BIOS, no UEFI, no partition table, no device tree, no start-up of a second processor, no firmware update. It follows the author's order (errata 110): the PDP-11 boot (4.1), then the systems that came between, the VAX, the Commodore 64, the PC's BIOS with the MBR, and the GPT with UEFI (4.2), each with the one thing it added; then the pdp64's boot, stage by stage (4.3 to 4.10), with the numbered decisions where the reader meets them; then the five boots and the pdp64 side by side (4.11). The wider review of how other systems boot is [`../boot.md`](../../boot.md). Tags: *(D)* decided; *(P)* proposed; *(S)* unspecified. A fact about an older or another machine that could not be checked on this computer is marked *unverified* and listed in 4.12.

*How to read this chapter.* A term is defined where it first appears, as the technical word followed by a plain restatement. Boxes-and-arrows pictures are the kind a textbook draws for a linked list: a box is a piece of memory, a register or a program, an arrow says what is handed on. Code blocks are pseudocode (C-like, `#` starts a comment) unless the text says they are PDP-11 assembly; the PDP-11 code is quoted from the V7M sources on this machine. Every pdp64 sketch is **an illustration written for this chapter**, not a specification. The decisions are the numbered statements; where the repository does not say, the text says *not specified*.

## 4.1 What you already know: starting a PDP-11

A processor that has just been powered on has a problem that no program can solve for it: the program that loads programs has to come from somewhere, and the memory holds nothing it can trust. This is the **bootstrap problem** (after the old joke of pulling yourself up by your own bootstraps, shortened to "boot"). A PDP-11 solved it in three ways, each a smaller job for the operator than the one before.

**The front panel.** The console had rows of switches. You set the address switches to a memory address and pressed LOAD ADDRESS, set the data switches to a word and pressed DEPOSIT (which stores the word and steps the address), repeated that for each word of a short **bootstrap loader** (a program of a few dozen words that reads a bigger program from a device), set the start address and pressed START. The V7M `boot(8)` page still says so: "load block 0 of the boot device by fiddling with the console keys as appropriate for your hardware. If you have no appropriate ROM, some programs suitable for manual use are given below". (The switch mechanics are general knowledge, unverified.)

**The boot ROM.** Later machines kept the loader in a **ROM** (read-only memory: storage that holds its contents without power) on the processor board. The V7M tape bootstrap names one such card in a comment (`sas/htboot.s`: "The M9312, which is the only boot for the TS11 ... leaves the CSR address in r1"): the M9312 is a ROM card that holds a boot program per device kind and hands the program the device's register address in `r1` (read; that a console switch or command chose the device is general knowledge, unverified). 2.11BSD's block-0 programs show the other side of the contract: they begin `nop` then `br start`, with the comment "These two lines must be present or DEC boot ROMs will refuse to run boot block!", and start with `mov r0,unit` and `mov r1,csr`, so DEC's ROM evidently checks that block 0 begins with those two instructions (inference from the comment) and passes the unit in `r0` and the controller's address in `r1` (read: `mdec/rkuboot.s`). What the ROM did is the subject of this chapter in one sentence: it read **block 0** (the first 512-byte **block**, the unit a disk is read in, numbered from 0) of the boot device into low memory and jumped to it.

**Block 0, the primary bootstrap.** The program in block 0 is the **primary bootstrap**, small enough to fit in one block. The V7M page says it in one paragraph: "A PDP11 UNIX system is started by a two-stage process. The first is a primary bootstrap which is able to read in relatively small stand-alone programs; the second (called *boot*) is used to read in the system itself. The primary bootstrap must reside in the otherwise unused block zero of the boot device. It can be read in and started by the standard ROM programs, or if necessary by keying in a small startup routine." Here is the head of the primary bootstrap for the RM02/3 and RP04/5/6 disks, `sys/mdec/hpuboot.s` (285 lines, counted), which shows what a block-0 program has to do for itself:

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

The ROM put this program at address 0. It copies itself to the top of the first 56 KB so that the kernel can be loaded at 0, clears the rest of memory, starts the disk, prints `#`, reads a file name, finds the file by reading the disk's **inodes** (the file system's table entries, one per file) from the root directory down, loads it and enters it. The file it loads is the second stage.

**The second stage, `boot`.** `boot` is an ordinary C program (`sys/sas/boot.c`, 272 lines, counted). The V7M page: "When read into location 0 and executed, *boot* sets up memory management, relocates itself into high memory, and types `Boot` and `:` on the console. Then it reads from the console a device specification followed immediately by a pathname", for example `hp(0,0)unix`: the device, the unit, and the block offset of the file system on it. "*Boot* finds the corresponding file on the given device, loads that file into memory location zero, sets up memory management as required, and calls the program by executing a `trap` instruction." So there were two prompts, `#` from the first stage (type `boot`) and `:` from the second (type `hp(0,0)unix`). There were two stages because block 0 holds 512 bytes of program, enough to find a file by name but not also a menu, a device table and an error message for every disk; and a bigger program with all of that can be an ordinary compiled file, replaced by copying a new one in. The page also provides `/boot.bu`, "a backup copy of the bootstrap", the PDP-11's first recovery measure (4.10).

**2.11BSD**, the same kernel grown up, is explicit about the limit and about what the stages hand on. Its `boot(8)` page: "a primary bootstrap (limited to 512 bytes) ... must reside in block zero of the boot device (the disklabel resides in block one) ... `disklabel(8)` is normally used to place a copy of the appropriate bootstrap in block zero of new file systems"; copies are kept in `/mdec`. The header of its `hpuboot.s` says "assembled size must be <= 512; if > 494, the 16-byte a.out header must be removed" and that features "had to be removed to make room". The next stage receives the machine **in registers**: the comment in `pdpstand/srt0.s` reads "the bootstrap passes the cputype through in r0", `r1` holds the controller's register address and `r3` the boot device's major and minor number; `pdpstand/boot.c` declares a `checkword` that is "one's complements of bootopts", and its comment says "If r2 (checkword) was the complement of bootopts, this is an automatic reboot, otherwise do it the hard way": `r2` carries the check word, so that the program can tell an unattended reboot, which passed its options, from a person typing at the prompt (read). That is the PDP-11 form of what the pdp64 does with `r0`, `r1` and the boot-information block (4.4, 4.6).

**`ODT` and the console.** When nothing booted you were not stranded: the processor or the ROM carried a tiny monitor, **ODT** (Octal Debugging Technique, a console program that lets you type an address, see the word there, change it, and start a program at an address). A PDP-11 with a dead disk could still be inspected and a bootstrap keyed in. (2.11BSD's `cons(4)` page names it: "ODT (console debugger mode) prompt", entered by control-P on an 11/44, whose prompt is `>>>`, and by the front-panel halt switch on an 11/73, whose prompt is `@`; "the operation of the console in this mode varies per-processor" (read). That it can examine, deposit and start is general knowledge, unverified.)

**What a PDP-11 did not have.** It had no partition table on the disk: V7's `hp.c` compiled the disk's regions into the driver (`hp_sizes[8]`, eight pairs of a size and a first cylinder, with comments such as "cyl 44 thru 429"; the V7M version has 24 entries for three drive types), so changing the layout meant recompiling the kernel (4.5). It handed the kernel no description of the machine: the devices and their addresses were compiled in (chapter 6's vector table is that table) and the bootstrap passed three or four registers (4.6). It had one processor, so no other processor to start (4.7); no device that needed a program of its own before it would work (4.8); no firmware, so no BIOS and no UEFI (4.2, 4.9); and a monitor but no watchdog, so nothing restarted a hung machine (4.10). What the pdp64 keeps is the chain: a ROM that reads block 0 and jumps; a first stage that fits in a block; a second stage that is an ordinary program and finds the kernel by name; registers that carry the boot device across; a console monitor when nothing boots.

## 4.2 What came between: the VAX, the Commodore 64, the PC with a BIOS, the GPT with UEFI

The author named four systems between the PDP-11 and the pdp64: "pdp11 boot, vax boot, c64 boot, the x86 bios boot with mbr, then finally the gpt/uefi" (errata 110). Each added or removed one thing from the PDP-11 chain, and each is told here as steps and with the one idea it contributed. The marks: **(read)** is read in the sources on this machine, **(repo)** is from the repository's documents, **(unverified)** is general knowledge, the handbooks and specifications not being here.

### The VAX: a console computer starts the machine

*What it added:* a processor whose only job is to start the main one, and a boot block of 15 sectors (the PDP-11's 512-byte block 0 and ROM made larger). The 4.3BSD sources are on this machine; the console and DEC's own boot program are not.

1. A **console processor** (on the VAX-11/780 a separate small computer) powers up and runs a self-test; it also provides the console commands and starts the other processors on multiprocessor models. (repo: `boot.md`; unverified otherwise)
2. On a boot command the console, or a boot ROM on the smaller models, reads the boot block (block 0) of the device into memory and starts it with registers describing the device. (repo; read for the registers below)
3. That first-level program is `raboot.c` in 4.3BSD-Tahoe. Its header says it "loads next 7.5Kbytes from boot sector of file system" to `0x50000` (sectors 1 to 15 of an 8 KB boot area, `BOOTLAST` 15) and "should work with any disk using 750 boot rom". It takes the Unibus I/O page address from `r1` (the adapter number is cut from it), the controller address from `r2`, the unit from `r3`, and the boot flags and partition from `r5`. (read)
4. The second level is `vaxstand/boot.c`: it takes `r10` (the device) and `r11` (the options), prints `Boot` and then the `:` prompt, opens a file by name and enters it. The default name is `hd(6,0,0) /vmunix` (`saio.h`). (read)
5. The kernel runs. In 4.3BSD `rpb.h` holds the "restart parameter block, which is a page in (very) low core which runs after a crash", a record for a dump routine and not a boot hand-off; what DEC's own boot program (VMB, a name from general knowledge) passed is unverified.

The 8 KB boot area of step 3 is where the pdp64's 8 KB boot area comes from (4.5.3).

### The Commodore 64: the ROM is the whole boot

*What it added:* nothing to load. All of this is general knowledge, unverified; nothing about the C64's boot is in the repository beyond the machine's description in chapter 3.

1. The 6510 processor, on reset, reads its start address from the two bytes at `0xFFFC`; they lie in the **KERNAL ROM**, the top 8 KB of memory, so the first code is in ROM and nothing is loaded.
2. The KERNAL's cold-start routine initialises the chips, tests the RAM, sets the vectors and the screen.
3. It looks at `0x8000` for the signature `CBM80`; if a cartridge carries it, the cartridge's start address is called (**cartridge autostart**).
4. Otherwise it enters the **BASIC ROM's** cold start, which prints its banner and `READY.`
5. The user types `LOAD` and `RUN`; the program comes from the datasette or from the 1541 disk drive, a separate machine with its own processor and ROM.

The C64 has no second stage: the ROM is the operating system, and a program on a cartridge or disk replaces it by hand. The pdp64 takes from it one point: the first code is in a ROM that storage cannot damage.

### The PC with a BIOS and an MBR: services in firmware, and a table in block 0

*What it added:* a firmware library the first stage can call, so that 512 bytes can read a disk; and a partition table sharing block 0 with the code. The facts come from the OpenBSD sources on this machine where they can, and are otherwise general knowledge, marked unverified.

**The BIOS.** The IBM PC of 1981 (unverified) kept a ROM called the **BIOS** (Basic Input/Output System). The name has stuck to four jobs that are worth pulling apart: (1) **bring-up and self-test**, initialising the chipset, sizing the memory, checking the basics (the power-on self-test); (2) **the first code**: find a boot device, read its first sector (the PC's word for a block, 512 bytes) to a fixed address and jump to it; (3) **a library of services** called by **software interrupt** (an instruction that behaves like a trap through a vector: the PDP-11's `emt` or `sys` is the same kind of thing), one service each for the disk, the screen, the keyboard and the memory map; (4) **configuration**, a setup screen and a small battery-backed memory for the clock and the settings. The third job is why a 512-byte boot sector can read the rest of a disk: it carries no disk driver, it calls the BIOS's. OpenBSD's PC first stage does exactly that: `biosboot.S` and `mbr.S` call `INT 0x13`, the BIOS disk service (read). The PDP-11's bootstrap carried its own driver (the `hpcs1` and `hpcs2` writes above); the PC's borrowed the firmware's.

**The steps** (the OpenBSD loaders are read; the rest is unverified):

1. The processor starts at the **reset vector**, `0xFFFFFFF0`, at the top of the 4 GB space, where the firmware flash is mapped, in 16-bit real mode. (unverified)
2. The BIOS runs its self-test (POST), initialises the chipset and memory and runs the **option ROMs** of add-in cards. (unverified)
3. It goes through the **boot-device order**, reads the first 512-byte sector, the **MBR**, to `0x7C00`, and checks the signature `0x55AA`; the code in the first 446 bytes runs. (the 446, the table and the signature are read in OpenBSD's `disklabel.h`; the address and the order are unverified)
4. The MBR code finds the **active** partition in the four-entry table and loads its first sector, the **partition boot record** (OpenBSD: `mbr.S`, which "finds the first active partition", then `biosboot`, whose manual page says "roughly 512 bytes of code"). (read)
5. That program, using `INT 13h` for every disk read, loads the next stage, `/boot`, which loads the kernel. (read: `biosboot.S`)
6. The kernel gets the memory map and the machine's description from the loader and the BIOS. (unverified)

**The boot sector and its 446 bytes.** The MBR (master boot record) is one block with three parts: 446 bytes of first-stage program, a **partition table** of four 16-byte entries (a **partition** is a named region of the disk, so that several operating systems can share one disk), then the two-byte signature `0xAA55` (the bytes `0x55`, `0xAA`). OpenBSD's `sys/disklabel.h` has it in C: `dmbr_boot[446]`, four `dos_partition` entries, `dmbr_sign` at byte `0x1fe`; an entry holds a flag byte (`0x80`, active), a type byte, and a start and a size of 32 bits each (read). The code gets 446 bytes because that is what a table and a signature leave in a sector. The 32-bit size caps the scheme at 2 TiB of 512-byte sectors (2^32 x 512, arithmetic), and four entries is why "extended" partitions with a chain of further tables exist. The OpenBSD chain is BIOS, `mbr.S`, `biosboot`, `/boot`, kernel: four programs before the kernel, against the PDP-11's three (ROM, block 0, `boot`) or V7's own count of two (block 0 and `boot`).

**Real mode.** The BIOS and the first stages run in **real mode**, the 16-bit mode of the 8086 of 1978 (unverified) that addresses one megabyte, the only mode the processor starts in. Getting out of it is the loader's job and one thing the pdp64 does not have to do (4.7).

### The GPT and UEFI: a table that outgrew the sector, and firmware that reads files

*What it added:* a partition table with 64-bit sector numbers, and a firmware that understands a file system and runs a program from it, so there is no boot sector to jump to.

**The GPT.** The four 32-bit entries ran out, and UEFI brought the **GPT** (GUID partition table; a **GUID** is a 128-bit identifier, long enough that two made anywhere will not collide). OpenBSD's `gpt_header` and `gpt_partition` structures (read) show it: the header sits in the second block (`GPTSECTOR 1`) with "EFI PART" in its first eight bytes; it holds a **CRC32** (a 32-bit check value computed over the bytes) of itself, the location of an alternate header (the **backup copy** at the end of the disk, so a damaged table can be rebuilt), and a CRC32 of the entry array; OpenBSD's constants are 128 entries of at least 128 bytes (a type GUID, a unique GUID, a 64-bit first and last block, attribute bits, a 36-character UTF-16 name). All values are little-endian (low byte first, the PDP-11's and the pdp64's byte order). The UEFI specification itself was not opened. Block 0 of a GPT disk is a **protective MBR**: an MBR with one entry of type `0xEE` ("EFI Protective Partition") covering the disk, so that an old tool that reads only the MBR sees a full disk and does not offer to partition it.

**UEFI.** The BIOS's successor is a firmware standard, **UEFI** (Unified Extensible Firmware Interface). The steps (OpenBSD's `efiboot` is read; the rest is unverified):

1. The firmware starts, through phases of its own, and runs its **boot manager**, which reads **boot variables** from non-volatile memory (**NVRAM**) to learn which loader to run. (unverified; the loaders call `GetVariable` and `SetVariable`: read)
2. It reads the GPT, finds the **EFI system partition** (`GPT_UUID_EFI_SYSTEM`, read) and its **FAT** file system (the MS-DOS file system, kept as the common denominator), and opens the loader file by name.
3. The loader is a **PE/COFF** program, the executable format of Windows (portable executable, from the Common Object File Format), where the PDP-11 and the BSDs use `a.out` or ELF. OpenBSD's arm64 loader begins "We need to be a PE32+ file for EFI" (read: `start.S`). The firmware runs it with a table of **boot services** (function pointers: allocate memory, read the memory map, read a file, write to the console, draw on the screen) and a few **runtime services** (clock, reset, variables) that stay after boot.
4. The loader calls the boot services and picks up the **memory map** and the **configuration tables** that describe the machine to the kernel: **ACPI** (a standard of tables, with a byte-code interpreter the kernel must carry) or a **device tree** (a tree of nodes naming each device and its addresses, flattened into a blob). OpenBSD's loaders look for both (`EFI_ACPI_TABLE_GUID`, `FDT_TABLE_GUID`; read).
5. It loads the kernel and calls **exit boot services** with the memory map's key, retrying once because the call refuses a stale key (`efiboot.c`, read); the firmware's boot services are gone after that.
6. The kernel runs with the memory map and the tables. With **Secure Boot**, each image is signed and checked against keys held in the firmware. (unverified)

Beneath this the firmware is a large program with phases of its own. The QEMU tree here carries built images of the open-source implementation EDK II (`pc-bios/edk2-*.fd.bz2`); the x86-64 code image is 3,653,632 bytes uncompressed (measured).

### The chain, and the six jobs side by side

From the PDP-11 to the pdp64 the first code moved from the operator's keys, to a ROM, to a console computer (VAX), to the processor's own ROM with nothing loaded (C64), to a BIOS with services (PC), to a firmware that runs files (UEFI); and the pdp64 returns to the ROM and block 0 of the PDP-11. The jobs, by system:

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

**Why there are stages.** The chain is a ROM, a first block, a second stage and a kernel, and each exists because the one before it is too small to do the next one's job. The ROM sits in the controller chip, where every byte costs silicon: it reads one block from the boot devices and does nothing else. The first block is 512 bytes, and under a GPT only the 446 bytes of the protective MBR's code area are its own (4.5): it holds a short list of where the next program lies on the disk and the few instructions that read it. Only the second stage, an ordinary C program loaded from disk, can be as large as it needs to understand a file system, the partition table and the label. The PDP-11 had the same chain without the partition table (the `#` and `:` prompts of 4.1).

![The boot stages as a chain](figures/boot-stages.svg)

**Why open source, and why it is in the specification.** The author's words (errata 47, 2026-10-22): "we'll have an open source boot sector boot loader as part of the spec; that is part of the spec that the boot loader/bios is open source." The firmware that ships on a PC is typically a vendor's build whose source the owner does not have (unverified), runs before anything the owner can inspect, and stays resident afterwards (4.2). In the pdp64 every stage after the controller's own sequencer is a published source file built by the project's compiler, and the ROM and monitor are in the same position, so no closed program sits at the root of the chain. The licence is that of the whole project (errata 48: "bsd license for everything"; the 2-clause variant is the assistant's choice of the common default, noted there). The UEFI specification itself is published (4.9), so what is closed on a PC is the shipped firmware and not the specification.

*Commentary.* **Chain.** The PDP-11's ROM and `ODT` did jobs 1, 2 and (as a monitor) 4 of the BIOS list; the PC added job 3, the services, so that a 512-byte sector could read a disk; UEFI turned job 2 into a loader file and job 3 into boot and runtime services. Other architectures fill the same roles under other names: Open Firmware on SPARC and PowerPC (OpenBSD's `sparc64/stand/ofwboot` is a loader for it, and QEMU carries `openbios-sparc64` and `openbios-ppc` images: read), U-Boot on ARM and PowerPC boards (QEMU carries `u-boot` images: read; its use on ARM is unverified), OpenSBI on RISC-V (QEMU carries `opensbi-riscv64-generic-fw_dynamic.bin`, and OpenBSD's riscv64 kernel calls it through `sbi_*` functions: read), the console of the Alpha (OpenBSD's `alpha/include/rpb.h` takes its restart block from DEC's system programmer's manual, 4.6; the name SRM is unverified) and the console processor of the VAX (4.2). **Trade-offs.** The pdp64 returns to the PDP-11 split and drops job 3: every device speaks virtio through one transport (chapter 2), so the loader and the kernel share one driver design and the loader needs no firmware to read a disk. The cost is a driver for the boot disk in the second stage, small because a virtio device is a handful of structures. **Benefits.** There is no firmware API to specify, no compatibility layer, no resident management code and no closed blob at the bottom of the trust chain (x86 firmware also keeps resident system-management code that the operating system cannot see, unverified; arm64 and RISC-V servers need trusted firmware and usually UEFI beside it, unverified, though OpenBSD's arm64 and riscv64 ports do boot through `efiboot`, read); the failure cases reduce to one, the first block did not load, and the monitor is the recovery. **Impact.** *Kernel:* no firmware services to call or to fix. *Compiler:* builds the ROM, loader and tools. *Hardware:* a boot ROM of a few hundred bytes to a few kilobytes, with a driver per boot device (not specified more closely).

## 4.4 The reset state and the first block

**What happens at power-on.** The **controller chip** (the chip that holds the boot ROM, `boot.md`) brings up the memory and holds every core in **reset** (a state in which a core executes nothing and keeps no state). The ROM runs on core 0. On the PDP-11 the equivalent was the processor's own power-up and the ROM or the front panel; here it is a small program in the controller that does five things in order: find a boot device, read block 0 into low memory, check that it looks like a boot block, set core 0's registers, and start core 0 at the block. If it finds no device or no boot block, it runs the monitor (4.10). In pseudocode:

```
rom_entry():                                  # core 0; every other core is held in reset
    quick_memory_check()                      # a short test of the first pages (repo: `boot.md`, job 1)
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

read_block(dev, n, address):                  # the standard disk: one virtio-blk request (5.6.2)
    build a three-descriptor chain: request header (type = read, sector = n),
                                    a 512-byte buffer at `address`, a one-byte status
    FENCE; write the queue's doorbell; poll the used ring until the chain returns
    return status == OK
```

The ROM polls (checks in a loop) rather than using interrupts. Inference, not stated: the ROM runs before any software has programmed the interrupt controller (2.6.3: how the interrupt controller is programmed is not specified), so there is nothing to interrupt it; polling needs no set-up, and 2.7.8 shows the polled form. It needs a driver for each kind of boot device; for the standard disk that is the virtio-blk reader of chapter 5: find the function in the bus's configuration space, set up one queue, read one block. Which device comes first, and how the ROM names a device in `r0`, are not specified (F10 of `decisions-pending.md` leaves the order after the disk open).

**The first few pages of memory.** The **vector table** (the table of handlers that an exception or an interrupt jumps through, chapter 6) is **one whole page**, 512 entries of 8 bytes, at address 0, because the system register `VBR` (vector base register) is zero at reset (6.12). The PDP-11's was a fixed table of a few hundred bytes at 0 to 0377, and its boot programs lived elsewhere. The author summarised the PDP-11 way (2026-10-22) as "load 512 byte block 0 then jmp 0", "not precisely true, but directionally true"; here the "jmp 0" becomes a jump to the address block 0 was loaded to, because the first page holds the vectors. Block 0 is loaded **above** the table, at 0x1000 in this chapter's example (the address is "to be chosen"; `docs/boot.md`), so that the first stage runs without overwriting the vectors. The stack pointer `r14` starts at the top of the first 64 KB, so the first stage has a stack before it has run an instruction. `r1` points at the **boot-information block** (4.6). The author's rule of errata 102 is that no device window is mapped in **the first few pages**, where "the boot stuff is loaded"; how many pages that is, is not decided.

![Memory when block 0 is loaded](figures/boot-block0-memory.svg)

**4.4.1** At reset the controller brings up memory, holds every core in reset, and looks for a boot device in a fixed order: disk or flash, then SD card, then the serial line. *(P)*

**4.4.2** It reads block 0 of the first device that answers (for the standard disk, a virtio-blk read request) into low memory, checks the `0x55AA` signature in the last two bytes, and starts core 0 at that address. It does not parse a partition table. *(P)*

**4.4.3** Core 0 starts in kernel mode at priority 7 with translation off (every address physical), `VBR` zero and the user-memory guard clear; `r0` holds the boot device number, `r1` the address of the boot-information block, `r14` the top of the first 64 KB of memory, and the other registers are zero. *(P)* The first few pages of the physical address space are reserved for the boot code and boot data, and no device window is mapped there (2.3.6, *(D)*); how many pages is not decided. *(P)*

**4.4.4** If no boot device answers, or a key is held at power-up, the monitor runs on the serial console. *(P)*

**Not specified here:** where block 0 is loaded (0x1000 is an illustration); how the ROM finds the boot device's windows before any software has assigned them (2.4.1 says the processor assigns windows; the ROM is the first software to do it, and the repository does not say where it puts them or whether it leaves them for the kernel); which fields of the boot-information block the ROM fills and which the second stage adds (the natural reading, since the ROM knows the memory, the cores and the device, is that the ROM fills the block and the second stage adds the command line and the screen, 4.6; not stated); and the number of reserved pages.

*Commentary.* **Chain.** PDP-11: ROM or keys read block 0 and jump, the boot device in registers. VAX: a console or a boot ROM does the same with the boot block and registers `r1` to `r5` (4.2). PC: the BIOS reads one 512-byte sector to a fixed address (unverified: the address); the IBM mainframes' IPL record and the Alpha console's boot block are the same idea (unverified); ARM boards load a first-stage loader from the boot medium (unverified). UEFI: no block 0, a file run from a FAT partition. pdp64: the PDP-11 step again, with the reset state written down. **Trade-offs.** A boot ROM with a driver per boot device is more code in the controller than a "jump to a fixed flash address" scheme and much less than firmware; the first block must fit in one sector. **Benefits.** The first stage is the same on every board, and the first kernel code makes no guesses about the reset state, which earlier machines left to the console (inference: the VAX console and the PC's BIOS each defined their own). **Impact.** *Compiler:* the first block is 446 bytes of assembler. *Hardware:* the ROM reads one block and starts one core.

## 4.5 The disk: a GPT around the BSD label

**What a partition is, and why V7 had none on the disk.** A disk is one long run of blocks, and a computer wants several regions of it: a root file system, a swap area, a place for the users' files. A **partition** is such a region, and something has to record where each begins and ends. There are three places for the record, and the chain from the PDP-11 visits each. V7 put it **in the kernel**: the disk driver compiles in a table (`hp_sizes[8]` in V7's `hp.c`), so changing the layout means a new kernel; 4.3BSD's `vaxmba/hp.c` also compiles in its size tables (`rp06_sizes[8]`, `rm03_sizes[8]` and others). The 4.3BSD-Tahoe `disklabel.h` (1988: its header is dated 6/27/88) put it **on the disk**: a **disk label**, a structure in one of the first blocks holding the disk's geometry and a table of its partitions, "in block 0 or 1, possibly offset from the beginning to leave room for a bootstrap", marked by the magic number `0x82564557`. 2.11BSD's block 0 holds the bootstrap and its block 1 the label, the same two places as here. OpenBSD's label is its descendant: the same magic number, **16 partitions** (`MAXPARTITIONS16`, against Tahoe's 8) and sector counts beyond 32 bits (`d_secperunith` holds the high part). The third place is the PC's, a **table in the first sector** (the MBR table of 4.2, then the GPT).

**Why the pdp64 has both a GPT and a label.** The author (errata 50, 2026-10-22, message 2631): "fine, we will have the gpt wrapper for the disk label." The disk carries a GPT with a protective MBR, so that other operating systems and partitioning tools recognise it, and the operating system's own partition (type `GPT_UUID_OPENBSD`) holds the BSD label, which says where the root file system, swap and the rest are. The label alone would be smaller and unreadable to everything else; the wrapper costs a GPT reader in the second stage and the kernel. The author added (errata 51, "follow the majority as far as boot block offset"): inside the OS partition the label is at **sector 1, offset 0**, the sector that most of OpenBSD's ports use, leaving sector 0 for a boot block.

**The first stage lives in the protective MBR.** Block 0 of a GPT disk is the protective MBR, 512 bytes: 446 bytes of code, the table (one entry, type `0xEE`), then `0xAA55` (the bytes `0x55`, `0xAA`: the `0x55AA` of 4.4.2). The first stage has 446 bytes. It cannot understand a GPT or a file system in that space and does not try: it carries a **block list**, three numbers per piece of the second stage (first block, number of blocks, load address), written into its code area by the **`installboot`** tool at installation; it reads those blocks and jumps to the first. The BSDs already do this. OpenBSD 4.6's `installboot(8)` page for the sparc says the first-stage program "loads the second stage program from a set of filesystem block numbers that have been hard-coded into it by the installboot program"; on the PC `installboot` patches `biosboot` with the location of `/boot`, and `biosboot(8)` says to re-run it whenever `boot(8)` is changed, "as its inode may change" (read). Because the boot-code bytes are the only place the pdp64 keeps block-list data, a damaged GPT cannot stop the machine reaching the second stage, which can repair it.

```
first_stage():                                # at LOAD (0x1000): 446 bytes of code plus the block list
    # entering state: kernel mode, priority 7, r0 = boot device, r1 = boot-information block, r14 = a stack
    for entry in block_list:                  # entries written by installboot: (start, count, address)
        read_blocks(r0, entry.start, entry.count, entry.address)     # (see the open question below)
        if failed: goto monitor_or_halt       # what to do on failure is not specified
    jump to block_list[0].address             # the second stage, with r0 and r1 unchanged
```

The pseudocode hides a question the repository does not answer: **how the first stage reads blocks.** 4.3.1 says the ROM offers no services after boot, and a virtio-blk read needs a queue, three descriptors, a doorbell and a poll (4.4). Whether that fits in 446 bytes beside the list is not established. The PDP-11 primary bootstrap carried its own disk driver (the `hpcs1` and `hpcs2` writes of 4.1) and the PC's called the BIOS. Three ways out, none decided: the first stage holds a small polled virtio-blk reader of its own (the PDP-11 way, consistent with 4.3.1); or the ROM leaves a read routine and tells the first stage where it is (a firmware call in miniature, against 4.3.1); or the ROM loads more than block 0, the whole 8 KB boot area of 4.5.3 for example, so the first stage has room for the reader. The question is in 4.13.

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

The **superblock** (the file system's first record: its size, its block size and where its tables are) sits at byte 8192 of the partition, after the 8 KB boot area that the BSD tradition reserves for the bootstraps (4.3BSD-Tahoe's `disklabel.h` comments the area as "primary (block 0) and secondary (block 1-15) bootstraps", read; errata 51: sector 0 the primary bootstrap, sectors 1 to 15 the label and a secondary bootstrap; the VAX's `raboot` of 4.2 loads sectors 1 to 15). The second stage can live in the boot area, in a small boot partition, or as a file in the root file system; whether a dedicated boot partition is needed is open (4.13), since the block list can point at any of them.

*Commentary.* **Chain.** V7: sizes in the driver, nothing on the disk. 4.3BSD-Tahoe: the label on the disk. PC: an MBR table of four 32-bit entries, then the GPT with a protective MBR. pdp64: the GPT outside, the BSD label inside. OpenBSD's tree has seven architecture headers with the label at sector 1 offset 0 (amd64, i386, arm, arm64, riscv64, hppa, powerpc64) and Alpha and SPARC64 at sector 0 (offsets 64 and 128); the port adds one header of a dozen lines. **Trade-offs.** The label alone is the smallest design and unreadable to other systems' tools; the GPT wrapper costs a GPT reader in the second stage and the kernel (OpenBSD's kernel already has one) and gives a disk other systems recognise. **Benefits.** The first stage does not depend on a GPT that may be damaged. The label code, `disklabel`, `newfs` and `installboot` come with OpenBSD. BSDs on UEFI machines combine the same pieces, a GPT with the label inside an OpenBSD-type partition and a FAT partition for the loader (inference: OpenBSD's `disklabel.h` defines `GPT_UUID_OPENBSD` and `GPT_UUID_EFI_SYSTEM` and its `efiboot` reads the latter); Linux has no label of its own (unverified). **Impact.** *Kernel:* the label code and tools come with OpenBSD. *Compiler, hardware:* none.

## 4.6 The second stage and the hand-off

**What the second stage is for.** The first stage put a bigger program in memory. The second stage does what the PDP-11's `boot` did, with more to read: it finds the disk, reads the partition table, reads the label, finds the root file system, finds the kernel by name in it, loads the kernel and enters it. Because it is a C program loaded from disk it can be as large as it needs and be replaced by copying a file. It has its own drivers (the virtio-blk reader, now complete) and no firmware to call. As a sketch:

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

**The hand-off: how the kernel learns about the machine.** The PDP-11 had four registers and a kernel built for the machine. A kernel that is to run on any pdp64 has to be told: how much memory there is and where (ranges, since memory is not always one block), how many cores, where the bus's root complex is (so that it can **enumerate**, walk the bus and list what is attached, 2.4), which device it was loaded from, where the console is, and the command line. The way to tell it is a **boot-information block**, a structure in memory whose address is in `r1`. The chain: the PDP-11 passed registers, as did the VAX (`r10`, `r11` to `boot`, 4.2); UEFI passes a memory map and **ACPI tables** or a **device tree** through configuration tables (4.2), and an operating system for several architectures carries a parser for each. The VAX's restart parameter block is a crash-dump record, not a hand-off (4.2); the Alpha's hardware restart parameter block, in OpenBSD's `alpha/include/rpb.h` (read), is a larger record of the same kind: the magic "HWRPB", the page size, the primary CPU, and offsets to per-CPU, console-terminal and memory-data tables, taken from DEC's system programmer's manual. The VAX and Alpha blocks are fixed-layout records of the machine; x86 and ARM servers pass ACPI tables, arm64 and RISC-V a device tree (OpenBSD's loaders look for both, 4.2). The pdp64's hand-off is small because the bus describes its own devices: the block names memory, cores, the root complex, the boot device, the console and the screen if one was set up, and the kernel finds everything else by enumeration.

![The boot-information block](figures/boot-bootinfo.svg)

**4.6.1** The second stage is a program in C that understands the root file system, reads the GPT and the label, loads `/bsd` (an ELF file) and jumps to it with `r0` and `r1` as before and a command line in the boot-information block. *(P)*

**4.6.2** The boot-information block names the memory ranges, the core count, the address of the root complex and the identity of the boot device and the console; the kernel enumerates every other device by PCI Express enumeration (section 2.4). *(P)*

**4.6.3** The block's layout is defined once, in a grammar from which the headers are generated, and carries a checksum and a version. *(P)*

**4.6.4** The boot-information block carries the video device's base address, size, pitch and pixel format when the boot loader has set it up, and nothing about the device's clock or power state is changed behind the kernel: its pixel clock stays up until the kernel's driver owns the device. *(D)*

Statement 4.6.4 exists so that the loader can set up a picture for the boot messages and the kernel can keep drawing on it until its own driver takes over, without the screen flickering or going blank: the **framebuffer** the loader set up is described in the block, and the device is left as it is. (That the PC learned this the hard way is the assistant's earlier wording and is unverified.)

*Commentary.* **Chain.** PDP-11: a kernel configured at build time, three or four registers. VAX: registers again (`r10`, `r11`), and a restart block. Alpha: the hardware restart parameter block. UEFI-era systems: ACPI tables or a device tree. pdp64: one block, because the bus is enumerable. **Trade-offs.** A fixed-layout block with a checksum has two failure cases (bad checksum, unknown version), against the parser a device tree or ACPI needs. OpenBSD's arm64 and riscv64 ports already parse a device tree and attach drivers from it, which could save kernel code if the port reuses many of their drivers (4.13). **Benefits.** Because the bus describes its own devices, the block shrinks to memory, cores and the bus controller's address, and the generated header cannot disagree with the loader. **Impact.** *Kernel:* reads a structure. *Compiler:* generates the header from one grammar. *Hardware:* none.

## 4.7 Starting the other cores

**The problem the PDP-11 did not have.** A PDP-11 had one processor, so "start the machine" was one thing. A pdp64 may have several **cores** (processors on one chip; chapter 7), and at reset only core 0 runs the boot code. The kernel has to start the others, each with its own stack and its own idea of who it is. The precedents, from the boot review (`boot.md`; counts measured there in Linux `7be4bc52` and re-counted for this chapter): on x86 the boot core sends INIT and START-UP signals through the interrupt controller (Linux's comment: "INIT, INIT, STARTUP sequence"), the START-UP carrying an address below one megabyte; the other core wakes in the 8086's **real mode** (4.2) and a hand-written **trampoline** (a short program that takes a processor from a limited mode to its full one, through two more modes) must walk it into 64-bit mode. Linux's `arch/x86/kernel/smpboot.c` is 1,528 lines and `arch/x86/realmode` another 1,258. arm64 asks firmware through a call, PSCI, in 124 lines (`arch/arm64/kernel/psci.c`), or has the waiting cores **spin** (loop on a word in memory) on a **spin table** until the boot core writes an address there, in 127 (`smp_spin_table.c`); RISC-V asks the firmware to start a **hart** (its word for a core) in 108 lines (`cpu_ops_sbi.c`) or spins in 58 (`cpu_ops_spinwait.c`). That the VAX console processor started the VAX's other processors is unverified.

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

**4.7.1** The controller holds every core except core 0 in reset; a write to a core's start register in the controller gives it an entry address and an argument and releases it into kernel mode at priority 7, with its core number in `r0` and the argument in `r1`. *(P)*

**4.7.2** A stuck core is reset by a write to a core-reset register. *(P)*

*Other chapters.* This is option 1 of boot decision B2 and of R2 in `decisions-pending.md`, which recommend it and leave it proposed (the other options were the x86 signals, a firmware call, a spin table and a table that all cores start from). Chapter 7 states the same rule as 7.8.1 and loads `r0` only, where 4.7.1 loads `r1` too; the difference is to settle (4.13). Waiting uses `WFE` and `SEV` (7.6); an **inter-processor interrupt**, a signal from one core to another, is a write to a per-core register of the interrupt controller (7.8.2).

*Commentary.* **Chain.** PDP-11: one processor, nothing to start. VAX: the console processor started the others (unverified). x86: INIT and START-UP signals and a trampoline through three modes. arm64 and RISC-V: a firmware call or a spin loop. pdp64: a register write. **Trade-offs.** With no mode ladder the whole protocol is one write, at the cost of a small register block in the controller. **Benefits.** No trampoline, no firmware call, fewer lines than any system counted, and one recovery path, a core reset. **Impact.** *Kernel:* starting a core is a register write. *Compiler:* none. *Hardware:* a start register and a reset hold per core.

## 4.8 Starting the devices

**The INIT bit.** On the Unibus every device had a **control and status register** (CSR) with a bit that told the device "initialise yourself" and a bit that said it was ready: you wrote `INIT`, waited for `READY`, and the device was in a known state (the RK11 has `GO` and `RDY` in its CSR and the RX02 floppy controller a bit named `RX_INIT`; 5.1 shows the driver code for each). All the work happened behind the register, in the device's own logic. The pdp64 keeps the idea and makes it a conversation: under virtio (2.7.3) the driver writes **zero** to the device's `device_status` byte, which resets it, then sets the bits `ACKNOWLEDGE`, `DRIVER`, `FEATURES_OK` and `DRIVER_OK` in order, each meaning "I have got this far", and the device answers by refusing or accepting the features the driver chose. That is the `INIT` and `READY` of the CSR spread over a few steps. Said plainly: `INIT` and `READY` are the PDP-11's way of starting a device, statement 4.8.1 keeps them, and the virtio `device_status` handshake is their descendant. 5.1 and 5.5 explain the idea and what a driver does with it, and 2.7.3 gives the bits and `init_device(fn)`, the pdp64's device start, so they are not repeated here. At boot the ROM runs it for the boot disk (4.4), the second stage again for the devices it uses, and each kernel driver at attach.

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

**4.8.1** A device is initialised by writing its `INIT` bit and waiting for `READY`; a device that wants firmware is given it through a descriptor operation once the root file system is available, and a device the boot depends on needs no firmware. *(P)*

*How the statement reads under virtio.* 4.8.1 is the PDP-11 form, one `INIT` bit and one `READY` bit (errata 29); under virtio (errata 95) it is the `device_status` handshake above. How a virtio device is handed firmware is not specified: virtio has no firmware operation of its own, so a request type or a separate device would have to be defined (4.13).

*Commentary.* **Chain.** PDP-11: the CSR's `INIT` bit, nothing more. PC: PCI Express devices initialised through configuration space and per-device driver code, firmware blobs loaded from files. VAX: the console and some adapters loaded microcode from storage (unverified). pdp64: the virtio handshake, firmware by descriptor. **Trade-offs.** A reset bit and a status register make the simplest device, with one failure case, a timeout. A firmware window lets a device be cheap (no flash) and makes an update a file replacement, at the cost of a header format and a device that rejects a wrong image safely; boot-critical devices are excluded because a device whose firmware is on a disk it must itself read cannot start. NVMe has a firmware-download command that needs a working queue first (unverified; not found in the QEMU headers read). **Impact.** *Kernel:* a device start is the 2.7.3 handshake. *Compiler:* none. *Hardware:* a status register per device.

## 4.9 Why UEFI is not used

**4.9.1** The pdp64 does not use UEFI: its boot is the block-0 route of sections 4.4 and 4.5, its hand-off is the boot-information block, and its devices describe themselves. UEFI firmware is not part of the specification and is not built. *(D)*

**4.9.2** The hand-off and the second stage are kept simple enough that a UEFI shim could be written by someone who wanted one. *(D)*

Both statements are the author's decision of 2026-11-10 (errata 109). The record, in his words (the 2026-10-22 messages are in the decision log, thread 1889, messages 2614 and 2620; the 2026-11-10 ones are quoted from errata 109 and 110 and are not in that log). On 2026-10-22 he asked, of boot, "look into uefi; is it worth it at all? can't we do what pdp11 used to do, load 512 byte block 0 then jmp 0? (not precisely true, but directionally true)", and asked how UEFI plays into partitions and the GPT; the review (`boot.md`) answered that UEFI was not worth it as the machine's own boot, and the earlier text's 4.6.1 and 4.6.2 were the assistant's proposals, tagged *(P)*, never a decision. On 2026-11-10 he asked "i thought we did decide to allow uefi? check all the threads where we discussed it" (no decision to allow UEFI was found in any recorded message), then "or we kept the originnal simple pdp11 boot block method?", and, given three options, chose "option 2, block 0 with a shim possible".

**Is UEFI an open specification, and what does an open-source system do with it?** The author asked, after the decision (2026-11-10): "if uefi isn't an open spec how are all the open source os supporting it? it requires binary firmware blobs?" By what could be checked:

* **The specification** is published by the UEFI Forum, the industry body that maintains it, and can be read without charge (general knowledge, unverified: it is not on this machine, and whether implementing it needs a membership, a licence or a compliance test is not known here). The closed part is elsewhere.
* **An open-source implementation exists.** EDK II, the TianoCore project's reference implementation, is under BSD-2-Clause-Patent (read: `/home/david/claude/qemu-src/pc-bios/edk2-licenses.txt`, and `/usr/share/doc/ovmf/copyright`, "Upstream-Name: edk2"). Built images are on this machine (QEMU's `pc-bios/edk2-*.fd.bz2` and `/usr/share/OVMF`, including `OVMF_CODE_4M.secboot.fd`), so an emulated PC boots under open firmware. The source is not here (`roms/edk2` is empty), so nothing about its size or contents was read.
* **Open-source operating systems write the loader side.** OpenBSD's `efiboot` (read) runs on top of firmware already on the machine and calls its services; it ships no firmware. NetBSD has its own `efiboot` in `sys/arch/i386/stand/efiboot`, which calls `ExitBootServices` like OpenBSD's (read). Linux takes the other route: the kernel is itself a PE/COFF image that the firmware loads, "the EFI boot stub" (`Documentation/admin-guide/efi-stub.rst`, read), so no separate loader exists; the stub still runs on firmware already present. None of the three ships firmware, and a loader needs no blob.
* **The proprietary blobs are in the firmware shipped on real PCs:** the vendor's builds, and the CPU vendor's initialisation code that brings up memory and the chipset, which many boards include as a binary (unverified, not on this machine). That is a property of how PCs are made, not of the UEFI specification.
* **Secure Boot** adds a chain of signed loaders and keys kept in the firmware's variable store (unverified; the `secboot` image names above are all that was seen).

The author's conclusion (2026-11-10): "I guess leaving the door open to uefe support but having the classic mbr fallback, gpt wrapper is a good choice then." That **confirms option 2** of errata 109 and decides nothing new (errata 110). The two routes share one disk: block 0 of the pdp64 disk already has the protective MBR and GPT layout (errata 50, 4.5), so the classic route (the ROM reads block 0) and a future UEFI route (a firmware, or the shim, reads the GPT and a FAT system partition) read the same disk without repartitioning it.

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

*Commentary.* **Chain.** PDP-11 and VAX: no firmware services. PC: the BIOS, then UEFI to give one installer a way to boot on any machine offering it. OpenBSD's arm64 and riscv64 ports use UEFI and a device tree, with loaders of 7,195 and 4,513 lines; for amd64 the loaders total 15,440 lines, a BIOS boot block of 862 lines and a second stage of 189 beside the UEFI loader of 4,593 (counted; the total includes `libsa`, 6,319). pdp64: block 0, with the door left open. **Trade-offs.** UEFI firmware would let existing generic loaders run unchanged and offer a standard memory map and a secure-boot chain; it costs a large firmware, adds failure modes (variable storage, drivers, boot-order state), enlarges the attack surface, and still needs a device tree or ACPI to describe the devices. A shim gives the first benefit without the rest, at the price of a services layer and a PE/COFF build. **Benefits.** The pdp64 has one architecture and one platform description, the case UEFI was not built for. **Impact.** *Kernel:* no firmware interface, no memory-map translation in the machine itself; a shim would translate the boot-information block. *Compiler:* no PE/COFF unless a shim is built. *Hardware:* no firmware stack.

## 4.10 Recovery

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

**4.10.1** The controller's ROM includes a monitor reached on the serial console when nothing boots: examine and deposit memory and registers, load a program over the serial line, start at an address or from a named device, reset a core, reset the machine. *(P)*

**4.10.2** A hardware watchdog restarts the machine if the kernel hangs. *(P)*

*Commentary.* **Chain.** PDP-11: `ODT`, the front panel and `/boot.bu`. VAX: the console processor (unverified). PC and UEFI: a setup screen and rescue media (unverified). ARM and RISC-V boards: the console of U-Boot and the debug console of OpenSBI (unverified). pdp64: a monitor in ROM and a watchdog. **Trade-offs.** A monitor is a few hundred bytes of ROM (an estimate) and needs a serial port. **Benefits.** It is the recovery path that needs the least code. **Impact.** *Kernel:* the way in when nothing boots. *Compiler:* none. *Hardware:* a serial port and the ROM bytes.

## 4.11 Five boots side by side

The five referents in the author's order, and the pdp64 as the sixth, as the chains of 4.1 and 4.2 and 4.3 to 4.10 give them. A dagger marks a cell that rests on general knowledge, unverified; the last column says which of the five the pdp64 resembles.

![Five boots and the pdp64](figures/boot-five-boots.svg)

The pdp64 (f), in one paragraph: the ROM in the controller chip runs on core 0, reads block 0 through a virtio-blk request, checks `0x55AA`, and starts core 0 at it with `r0`, `r1` and `r14` set (4.4); the first stage, in the protective MBR's 446 bytes, reads the blocks on its list (4.5); the second stage reads the GPT, the label and the root file system, fills in the boot-information block and loads `/bsd` (4.6); the kernel enumerates the bus and starts the other cores by register writes (4.7). 

| Property | (a) PDP-11 | (b) VAX | (c) C64 | (d) x86 BIOS, MBR | (e) GPT, UEFI | (f) pdp64, and which it resembles |
|---|---|---|---|---|---|---|
| Who runs first | the processor, then the operator's keys or a ROM† | the console processor† | the 6510 from its reset vector† | the processor at `0xFFFFFFF0`† | the same, then the firmware† | the ROM on core 0: like (a) and (b), without the operator |
| Where the first code lives | front panel or boot ROM | console ROM and storage† | the KERNAL ROM† | firmware flash† | firmware flash† | a ROM in the controller chip: like (a) and (c) |
| How big the first code may be | a few dozen words (keys)†, a ROM's size†; block 0 of 512 bytes (read) | the boot block; the 750 loaded 7.5 KB next (read) | the ROM's 8 KB† | 446 bytes in the MBR (read) | the loader file, any size† | the ROM's size; 446 bytes in block 0: like (d) |
| How it finds the next stage | block 0 reads a name (`boot`) by walking inodes; `boot` reads `hp(0,0)unix` (read) | the boot block loads sectors 1 to 15; `boot` opens a name (read) | it does not: `LOAD` by the user† | the active flag in the table, then `INT 13h` reads (read) | the boot variables and the GPT's type, then a name on FAT† | a block list in block 0, then the GPT, the label and a name: like (b) and (a) |
| What the hand-off carries | registers (2.11BSD: `r0`, `r1`, `r3`, a check word) (read) | `r10`, `r11` to `boot` (read) | nothing: the program owns the machine† | registers and the BIOS's memory map† | the memory map and ACPI or a device tree (read) | `r0`, `r1` and the boot-information block: like (a) in registers, like (e) in a description |
| How it is repaired | keys, `ODT`†, the backup `/boot.bu` (read for the last) | the console† | the ROM cannot be damaged by storage; a cartridge† | re-write the MBR from another disk† | the firmware's setup and boot manager† | the monitor, a core reset, a watchdog (4.10): like (a); a damaged GPT does not stop the first stage (4.5) |
| What is open source | the BSD and V7 stages (the sources here); ROMs† | the BSD stages (read); the console† | the ROMs are Commodore's† | the loaders, in OpenBSD (read); the BIOS is a vendor's† | the specification is published†; EDK II is BSD-2-Clause-Patent (read, 4.9); shipped firmware often not† | everything, by decision (4.3.2) |
| How many programs before the kernel | 3 (ROM or keys, block 0, `boot`) | 3 (console, boot block, `boot`) | 1 (ROM) or 2 with a cartridge† | 4 (BIOS, `mbr.S`, `biosboot`, `/boot`) (read) | 3 or more, with firmware phases† | 3 (ROM, block 0, second stage): like (a) and (b) |
| What recovery exists | `ODT` and the front panel† | the console† | reset, a cartridge† | the BIOS setup, a rescue disk† | the setup, rescue media, a fallback loader name† | the monitor and the watchdog (4.10), the same disk readable by a UEFI route (4.9) |

Property by property, the pdp64's boot is the PDP-11's and the VAX's: a ROM, a first block, a second stage that finds a file by name, a hand-off in registers. It takes three things from the PC: the protective MBR and its 446 bytes (d), the GPT (e), and, in the boot-information block, a description of the machine (e) that the PDP-11 and the VAX did not pass. From the C64 it takes the ROM as the first code, undamaged by what is on storage; the C64 had no second stage. It differs from all five in that every stage is open source and no stage calls firmware after the ROM.

## 4.12 What was checked, and what was not

The rule of the project is: check, do not guess. The handbooks and specifications are not on this machine. What each fact rests on:

* **Unix sources** (`/home/david/claude/facetlang/unixtree`, files are gzipped): V7M `sys/mdec/hpuboot.s` (285 lines), `sys/sas/boot.c` (272 lines), the `boot(8)` page, `sas/htboot.s` (the M9312 comment), `dev/hp.c` (24 entries); 2.11BSD `man4/cons.4` (`ODT`), `mdec/rkuboot.s` (the `nop` and `br` that DEC's ROMs require, `r0` and `r1`), `pdpstand/boot.c` (the `r2` comment); V7 `usr/sys/dev/hp.c` (`hp_sizes[8]`, "cyl 44 thru 429"); 2.11BSD's `boot(8)` page, `sys/mdec/hpuboot.s` (the 512 and 494 bytes), `sys/pdpstand/srt0.s` (`r0`, `r1`, `r3`) and `boot.c` (`checkword`), `sys/h/disklabel.h`; 4.3BSD-Tahoe `h/disklabel.h` (the block 0 or 1 comment, the 8 KB boot-area comment, `0x82564557`, 8 partitions), `mdec/raboot.c` (registers, 7.5 KB, `0x50000`, `BOOTLAST`), `vaxstand/boot.c` (`r10`, `r11`, `Boot`, `:`), `vaxstand/saio.h` (the default name), `vax/rpb.h`; 4.3BSD `vaxmba/hp.c` (size tables); OpenBSD 4.6 `sparc/stand/installboot/installboot.8`.
* **OpenBSD** (`/home/david/claude/kernel-src/openbsd`, commit `2114d7b7`): `sys/sys/disklabel.h` (`DOSPARTOFF` 446, the signature at `0x1fe`, type `0xee`, "EFI PART", `gpt_header`, `gpt_partition`, `NGPTPARTITIONS` 128, `GPTMINPARTSIZE` 128, `GPTPARTNAMESIZE` 36, `MAXPARTITIONS16`, `d_secperunith`, both GUIDs); the `arch/*/include/disklabel.h` label sectors; `arch/amd64/stand` (`mbr.S` 521 lines, `biosboot.S` 862 and `biosboot.8` ("roughly 512 bytes of code", the `installboot` patching, "its inode may change"), `boot/` 189, `libsa` 6,319, `efiboot` 4,593, 15,440 in all); `arch/arm64/stand/efiboot` (7,195 lines, `start.S` 176, `self_reloc.c` 124) and riscv64 (4,513); the service counts; the `ExitBootServices` retry.
* **Other trees:** OpenBSD `share/man/man9/loadfirmware.9`, `arch/alpha/include/rpb.h`, `arch/sparc64/stand/ofwboot`, the `sbi_*` calls in `arch/riscv64`; NetBSD `share/man/man9/firmload.9` and `sys/arch/i386/stand/efiboot`; QEMU `pc-bios` (the `openbios`, `u-boot` and `opensbi` image names), `hw/acpi/ich9_tco.c`, `hw/watchdog/wdt_i6300esb.c`; Linux `include/linux/firmware.h` and `Documentation/admin-guide/efi-stub.rst`.
* **Linux** (`/home/david/claude/kernel-src/linux`, `7be4bc52`), re-counted: `smpboot.c` 1,528 lines, `arch/x86/realmode` 1,258 (`.c`, `.h`, `.S`), PSCI 124, spin table 127, RISC-V SBI start 108 and spin 58.
* **EDK II:** the licence in `qemu-src/pc-bios/edk2-licenses.txt` and `/usr/share/doc/ovmf/copyright`; the x86-64 code image 3,653,632 bytes uncompressed; the `secboot` image names in `/usr/share/OVMF`; no source in `roms/edk2`.
* **The repository:** the statements of this chapter against `docs/errata.md` (47, 48, 50, 51, 95, 101, 102, 103, 109, 110), `docs/boot.md`, `docs/decisions-pending.md` (B2 and R2, P7, F10), chapters 2, 5, 6 and 7 (2.3.6, 2.4, 2.7.3, 2.9.4, 5.6.2, 6.12, 7.4.2, 7.6, 7.8), and the author's messages of 2026-10-22 in `docs/decision-log` (threads 1889, messages 2614, 2620, 2631).
* **Unverified** (general knowledge): the front panel's switches and keys and the bootstrap loader of a few words; that a console switch or command chose the boot device; that `ODT` can examine, deposit and start; the date of the IBM PC and the 8086; the BIOS's four jobs and its other services; real mode and the 1 MB limit; the reset vector `0xFFFFFFF0`, the load address `0x7C00` and the boot-device order; the whole Commodore 64 boot (`0xFFFC`, KERNAL, `CBM80` at `0x8000`, BASIC, datasette, 1541); the VAX console processor, VMB and that the console started other processors; the name SRM for the Alpha console; the IBM mainframe IPL record; ARM first-stage loaders; resident system-management code in x86 firmware; the roles of U-Boot and OpenSBI consoles; NVMe firmware download; the UEFI boot manager, NVRAM variables and Secure Boot; that the UEFI specification requires PE32+ images and FAT on the system partition, and that a machine-type code would be assigned by its owners; the publication terms of the UEFI specification; whether PC firmware arms a chipset watchdog; that the PC learned the video lesson of 4.6.4 "the hard way".
* **Decided by the author and recorded in `errata.md`:** everything stated as a decision with a tag *(D)*; the pseudocode of this chapter is an illustration, and nothing in it is a decision. The author's 2026-11-10 words are quoted from errata 109 and 110, which are not in the decision log.

## 4.13 Still open

**Decisions the author has asked for, or that follow from the author's, and that are not made:** (a) the address block 0 is loaded to (0x1000 is the example; errata 102(a)) and how many pages "the first few" are; (b) how the first stage reads blocks: a small reader of its own in 446 bytes, a routine the ROM leaves, or a larger first stage loaded by the ROM (4.5); (c) how the ROM finds and maps the boot device's windows before any software has (4.4); (d) who fills which fields of the boot-information block, the ROM, the second stage or both (4.4, 4.6), and its layout, order and widths (4.6.3); (e) the partition type of the boot partition, and whether a dedicated boot partition is needed, since the block list can point at the second-stage file in the root file system or at the 8 KB boot area (4.5); (f) the device-tree option: whether the boot-information block is replaced or accompanied by a device tree if the OpenBSD arm64 and riscv64 drivers are reused (4.6); (g) the registers of the core start block, whether a started core begins with translation off, and the difference between 4.7.1 (`r0` and `r1`) and 7.8.1 (`r0`) (4.7); (h) how a virtio device is given firmware, and whether the `INIT` and `READY` words of 4.8.1 are restated over virtio (4.8); (i) the order of the other boot media after the virtio-blk disk (F10); (j) the monitor's commands, the serial speed and what is kept in non-volatile memory (boot order, serial speed: `boot.md`); (k) the shim: the path of the loader it runs, the services it offers, the machine-type number (4.9), none to be settled until someone wants one.

**Facts still to check against their own documents:** the PDP-11 power-up behaviour and the M9312's ROM contents (only its contract with block 0 was read); the VAX console, VMB and the Alpha console's boot protocol (only the restart block was read); the C64 boot; the x86 reset vector and START-UP rules; PSCI, the SBI hart calls and the spin table as specified; what the UEFI specification requires of a loader and of firmware, including the machine-type registry; the size of a UEFI services layer, which only an implementation could give.
