# 4. Boot, the BIOS, the disk label and the GPT

[← manual index](00-index.md)

**The machine starts the way the PDP-11 did: a small ROM in the controller chip loads one block from the boot device and jumps to it, and every later stage is an ordinary program, open source, compiled by the project's own compiler.** This chapter is written for a reader who has keyed a bootstrap in on a PDP-11 front panel, used a boot ROM, or typed `boot` at the `:` prompt of Unix Version 7 or 2.11BSD, or who is learning computing from the start, and who has not met anything invented after the 1970s: no BIOS, no UEFI, no partition table, no device tree, no start-up of a second processor, no firmware update. It follows the author's order (errata 110): the PDP-11 boot (4.1), then the systems that came between, the VAX, the Commodore 64, the PC's BIOS with the MBR, and the GPT with UEFI (4.2), each with the one thing it added; then the pdp64's boot, stage by stage (4.3 to 4.9), with the numbered decisions where the reader meets them; then the five boots and the pdp64 side by side (4.11). The wider review of how other systems boot is [`boot.md`](../boot.md). A fact about an older or another machine that could not be checked on this computer is marked *unverified* and listed in 4.12.

*How to read this chapter.* A term is defined where it first appears, as the technical word followed by a plain restatement. Boxes-and-arrows pictures are the kind a textbook draws for a linked list: a box is a piece of memory, a register or a program, an arrow says what is handed on. Code blocks are pseudocode (C-like, `#` starts a comment) unless the text says they are PDP-11 assembly; the PDP-11 code is quoted from the V7M sources on this machine. The decisions are the numbered statements. Where a statement is decided and its details are not yet worked out, the text says `Details pending` and points to appendix J.

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

**The second stage, `boot`.** `boot` is an ordinary C program (`sys/sas/boot.c`, 272 lines, counted). The V7M page: "When read into location 0 and executed, *boot* sets up memory management, relocates itself into high memory, and types `Boot` and `:` on the console. Then it reads from the console a device specification followed immediately by a pathname", for example `hp(0,0)unix`: the device, the unit, and the block offset of the file system on it. "*Boot* finds the corresponding file on the given device, loads that file into memory location zero, sets up memory management as required, and calls the program by executing a `trap` instruction." So there were two prompts, `#` from the first stage (type `boot`) and `:` from the second (type `hp(0,0)unix`). There were two stages because block 0 holds 512 bytes of program, enough to find a file by name but not also a menu, a device table and an error message for every disk; and a bigger program with all of that can be an ordinary compiled file, replaced by copying a new one in. The page also provides `/boot.bu`, "a backup copy of the bootstrap", the PDP-11's first recovery measure.

**2.11BSD**, the same kernel grown up, is explicit about the limit and about what the stages hand on. Its `boot(8)` page: "a primary bootstrap (limited to 512 bytes) ... must reside in block zero of the boot device (the disklabel resides in block one) ... `disklabel(8)` is normally used to place a copy of the appropriate bootstrap in block zero of new file systems"; copies are kept in `/mdec`. The header of its `hpuboot.s` says "assembled size must be <= 512; if > 494, the 16-byte a.out header must be removed" and that features "had to be removed to make room". The next stage receives the machine **in registers**: the comment in `pdpstand/srt0.s` reads "the bootstrap passes the cputype through in r0", `r1` holds the controller's register address and `r3` the boot device's major and minor number; `pdpstand/boot.c` declares a `checkword` that is "one's complements of bootopts", and its comment says "If r2 (checkword) was the complement of bootopts, this is an automatic reboot, otherwise do it the hard way": `r2` carries the check word, so that the program can tell an unattended reboot, which passed its options, from a person typing at the prompt (read). That is the PDP-11 form of what the pdp64 does with `r0`, `r1` and the boot-information block (4.4, 4.6).

**`ODT` and the console.** When nothing booted you were not stranded: the processor or the ROM carried a tiny monitor, **ODT** (Octal Debugging Technique, a console program that lets you type an address, see the word there, change it, and start a program at an address). A PDP-11 with a dead disk could still be inspected and a bootstrap keyed in. (2.11BSD's `cons(4)` page names it: "ODT (console debugger mode) prompt", entered by control-P on an 11/44, whose prompt is `>>>`, and by the front-panel halt switch on an 11/73, whose prompt is `@`; "the operation of the console in this mode varies per-processor" (read). That it can examine, deposit and start is general knowledge, unverified.)

**What a PDP-11 did not have.** It had no partition table on the disk: V7's `hp.c` compiled the disk's regions into the driver (`hp_sizes[8]`, eight pairs of a size and a first cylinder, with comments such as "cyl 44 thru 429"; the V7M version has 24 entries for three drive types), so changing the layout meant recompiling the kernel (4.5). It handed the kernel no description of the machine: the devices and their addresses were compiled in (chapter 6's vector table is that table) and the bootstrap passed three or four registers (4.6). It had one processor, so no other processor to start (4.7); no device that needed a program of its own before it would work; and no firmware, so no BIOS and no UEFI (4.2, 4.9). What the pdp64 keeps is the chain: a ROM that reads block 0 and jumps; a first stage that fits in a block; a second stage that is an ordinary program and finds the kernel by name.

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
| Bring-up | the processor and its ROM | the BIOS | the firmware | the controller chip |
| First code | ROM or front panel reads block 0 | BIOS reads the MBR | firmware runs a loader file | the boot ROM reads block 0 |
| Services for the loader | none: the bootstrap has its own driver | software interrupts | boot services | the loader has its own drivers |
| Finding the kernel | a name typed at `:` | partition boot record, `/boot` | the loader on a FAT partition | the second stage finds the kernel by name |
| Telling the kernel about the machine | registers | registers and the BIOS's memory map (unverified) | the memory map and ACPI or a device tree | the boot-information block |
| Starting other processors | none | INIT and START-UP signals | the same | the controller chip starts them (details pending, [J.4.6](appendix-j-open.md#j46)) |

![The PC path beside the pdp64 path](figures/boot-pc-vs-pdp64.svg)


## 4.3 What takes the place of a BIOS

**4.3.1** The pdp64's "BIOS" is the controller chip's boot ROM and its monitor. *(D)*

**4.3.2** The boot software is open source and part of the specification: the ROM and monitor, the first-block program, the second-stage loader and the boot tools. *(D)*

**4.3.3** Everything in the project, the boot software included, is under the BSD 2-clause licence. *(D)*

**Why there are stages.** The chain is a ROM, a first block, a second stage and a kernel, and each exists because the one before it is too small to do the next one's job. The ROM sits in the controller chip, where every byte costs silicon: it reads one block from the boot device and does nothing else. The first block is 512 bytes, enough to find and read the next program. Only the second stage, an ordinary program loaded from disk, can be as large as it needs to be to understand a file system and find a kernel in it. The PDP-11 had the same chain (the `#` and `:` prompts of 4.1).

![The boot stages as a chain](figures/boot-stages.svg)

**Why open source, and why it is in the specification.** The author's words (errata 47, 2026-10-22): "we'll have an open source boot sector boot loader as part of the spec; that is part of the spec that the boot loader/bios is open source." The firmware that ships on a PC is typically a vendor's build whose source the owner does not have (unverified), runs before anything the owner can inspect, and stays resident afterwards (4.2). In the pdp64 every stage after the controller's own sequencer is a published source file built by the project's compiler, and the ROM is in the same position, so no closed program sits at the root of the chain. The licence is that of the whole project (errata 48: "bsd license for everything"; the 2-clause variant is the assistant's choice of the common default, noted there). The UEFI specification itself is published (4.9), so what is closed on a PC is the shipped firmware and not the specification.

*Commentary.* **Chain.** The PDP-11's ROM and `ODT` did jobs 1, 2 and (as a monitor) 4 of the BIOS list; the PC added job 3, the services, so that a 512-byte sector could read a disk; UEFI turned job 2 into a loader file and job 3 into boot and runtime services. Other architectures fill the same roles under other names: Open Firmware on SPARC and PowerPC (OpenBSD's `sparc64/stand/ofwboot` is a loader for it, and QEMU carries `openbios-sparc64` and `openbios-ppc` images: read), U-Boot on ARM and PowerPC boards (QEMU carries `u-boot` images: read; its use on ARM is unverified), OpenSBI on RISC-V (QEMU carries `opensbi-riscv64-generic-fw_dynamic.bin`, and OpenBSD's riscv64 kernel calls it through `sbi_*` functions: read), the console of the Alpha (OpenBSD's `alpha/include/rpb.h` takes its restart block from DEC's system programmer's manual, 4.6; the name SRM is unverified) and the console processor of the VAX (4.2). x86 firmware also keeps resident system-management code that the operating system cannot see (unverified); arm64 and RISC-V servers need trusted firmware and usually UEFI beside it (unverified), though OpenBSD's arm64 and riscv64 ports do boot through `efiboot` (read). **Impact.** *Compiler:* builds the ROM, loader and tools.

## 4.4 The reset state and the first block

As on the PDP-11, a ROM reads block 0 of the boot device into low memory and starts core 0 there. The ROM is in the **controller chip** (the chip that holds the boot ROM, `boot.md`), which brings up the memory and holds every other core in **reset** (a state in which a core executes nothing and keeps no state). On the PDP-11 the equivalent was the processor's own power-up and the ROM or the front panel. The author summarised the PDP-11 way (2026-10-22) as "load 512 byte block 0 then jmp 0", "not precisely true, but directionally true"; here the "jmp 0" becomes a jump to the address block 0 was loaded to, because the first page holds the vectors.

**4.4.1** At reset the ROM in the controller chip reads block 0 of the boot device into low memory and starts core 0 at it, as the PDP-11's ROM did. *(D)*

Details pending: the address block 0 is loaded to and how many pages "the first few" are ([J.4.1](appendix-j-open.md#j41)); how the ROM finds the boot device and maps its windows before any software has assigned them ([J.4.3](appendix-j-open.md#j43)); which boot media the ROM tries, and in what order ([J.4.7](appendix-j-open.md#j47)); the state core 0 starts in ([J.4.9](appendix-j-open.md#j49)).

The ROM's job as pseudocode (an illustration of 4.4.1; the register state and the checks are pending):

```
rom_entry():                                  # core 0; every other core is held in reset
    for dev in boot_order:                    # the order is pending (J.4.7)
        if not bring_up(dev): continue        # enumerate the bus, find the device, initialise it (4.8)
        if not read_block(dev, 0, LOAD):      # LOAD: the address is pending (J.4.1)
            continue
        info = fill_boot_info(dev)            # the hand-off of 4.6
        set up core 0 (mode, stack, registers: pending, J.4.9)
        core0.pc = LOAD                       # the first instruction of block 0
        return                                # core 0 now runs the block; the ROM is done
    monitor()                                 # nothing booted: the monitor (4.10)
```

**The first few pages of memory.** The **vector table** (the table of handlers that an exception or an interrupt jumps through, chapter 6) is **one whole page**, 512 entries of 8 bytes, at address 0, because the system register `VBR` (vector base register) is zero at reset (6.12). The PDP-11's was a fixed table of a few hundred bytes at 0 to 0377, and its boot programs lived elsewhere. Block 0 is therefore loaded above the table, so that the first stage runs without overwriting the vectors. The author's rule of errata 102 is that no device window is mapped in **the first few pages**, where "the boot stuff is loaded" (2.3.5).

*Commentary.* **Chain.** PDP-11: ROM or keys read block 0 and jump, the boot device in registers. VAX: a console or a boot ROM does the same with the boot block and registers `r1` to `r5` (4.2). PC: the BIOS reads one 512-byte sector to a fixed address (unverified: the address); the IBM mainframes' IPL record and the Alpha console's boot block are the same idea (unverified); ARM boards load a first-stage loader from the boot medium (unverified). UEFI: no block 0, a file run from a FAT partition. pdp64: the PDP-11 step again.

## 4.5 The disk: a GPT around the BSD label

**What a partition is, and why V7 had none on the disk.** A disk is one long run of blocks, and a computer wants several regions of it: a root file system, a swap area, a place for the users' files. A **partition** is such a region, and something has to record where each begins and ends. There are three places for the record, and the chain from the PDP-11 visits each. V7 put it **in the kernel**: the disk driver compiles in a table (`hp_sizes[8]` in V7's `hp.c`), so changing the layout means a new kernel; 4.3BSD's `vaxmba/hp.c` also compiles in its size tables (`rp06_sizes[8]`, `rm03_sizes[8]` and others). The 4.3BSD-Tahoe `disklabel.h` (1988: its header is dated 6/27/88) put it **on the disk**: a **disk label**, a structure in one of the first blocks holding the disk's geometry and a table of its partitions, "in block 0 or 1, possibly offset from the beginning to leave room for a bootstrap", marked by the magic number `0x82564557`. 2.11BSD's block 0 holds the bootstrap and its block 1 the label, the same two places as here. OpenBSD's label is its descendant: the same magic number, **16 partitions** (`MAXPARTITIONS16`, against Tahoe's 8) and sector counts beyond 32 bits (`d_secperunith` holds the high part). The third place is the PC's, a **table in the first sector** (the MBR table of 4.2, then the GPT).

**Why the pdp64 has both a GPT and a label.** The author (errata 50, 2026-10-22, message 2631): "fine, we will have the gpt wrapper for the disk label." The disk carries a GPT with a protective MBR, so that other operating systems and partitioning tools recognise it, and the operating system's own partition (type `GPT_UUID_OPENBSD`) holds the BSD label, which says where the root file system, swap and the rest are. The label alone would be smaller and unreadable to everything else; the wrapper costs a GPT reader in the second stage and the kernel. The author added (errata 51, "follow the majority as far as boot block offset"): inside the OS partition the label is at **sector 1, offset 0**, the sector that most of OpenBSD's ports use, leaving sector 0 for a boot block.

**Block 0 is the protective MBR.** Because the disk uses the GPT wrapper (errata 50), block 0 is the protective MBR of that wrapper: 446 bytes of boot code, a partition table (one entry, type `0xEE`) and the signature `0xAA55` (the bytes `0x55`, `0xAA`). The first stage is the code in those 446 bytes.

**4.5.1** The disk carries a GUID partition table with a protective MBR; the operating system's own partition holds the BSD disk label, which names the root, swap and other partitions. *(D)*

**4.5.2** Block 0 is the protective MBR, so the first stage lives in its 446 boot-code bytes (errata 50). *(D)*

Details pending: what the first stage carries to find the second stage ([J.4.8](appendix-j-open.md#j48)), and how the first stage, which is one block of code, reads blocks from the disk ([J.4.2](appendix-j-open.md#j42)).

The first stage as pseudocode (an illustration of 4.5.2):

```
first_stage():                                # at LOAD: 446 bytes of code
    read the second stage from the disk       # where it lies and how it is read: pending (J.4.8, J.4.2)
    jump to the second stage, with the boot device and the boot-information block as the ROM gave them
```

**4.5.3** Inside the BSD partition, the label is at sector 1, offset 0; the boot area is 8192 bytes at the start of the partition; the file system begins after it, its superblock at offset 8192. *(D)*

| Sector (512 bytes) of the BSD partition | Contents |
|---|---|
| 0 | the partition's own boot block |
| 1 | the disk label, at offset 0 |
| 2 to 15 | the rest of the 8 KB boot area |
| 16 on | the file system, superblock at offset 8192 |

**4.5.4** Sector counts are 64-bit throughout; the label has 16 partitions and its sizes carry high fields beyond 32 bits. *(D)*

![The protective MBR, the GPT and the disk label](figures/boot-disk-layout.svg)

The **superblock** (the file system's first record: its size, its block size and where its tables are) sits at byte 8192 of the partition, after the 8 KB boot area that the BSD tradition reserves for the bootstraps (4.3BSD-Tahoe's `disklabel.h` comments the area as "primary (block 0) and secondary (block 1-15) bootstraps", read; errata 51: sector 0 the primary bootstrap, sectors 1 to 15 the label and a secondary bootstrap; the VAX's `raboot` of 4.2 loads sectors 1 to 15).

Details pending: where the second stage lies on the disk, and whether a dedicated boot partition is needed ([J.4.8](appendix-j-open.md#j48)).

*Commentary.* **Chain.** V7: sizes in the driver, nothing on the disk. 4.3BSD-Tahoe: the label on the disk. PC: an MBR table of four 32-bit entries, then the GPT with a protective MBR. pdp64: the GPT outside, the BSD label inside. OpenBSD's tree has seven architecture headers with the label at sector 1 offset 0 (amd64, i386, arm, arm64, riscv64, hppa, powerpc64) and Alpha and SPARC64 at sector 0 (offsets 64 and 128); the port adds one header of a dozen lines. **Trade-offs.** The label alone is the smallest design and unreadable to other systems' tools; the GPT wrapper costs a GPT reader in the second stage and the kernel (OpenBSD's kernel already has one) and gives a disk other systems recognise. **Benefits.** The label code, `disklabel`, `newfs` and `installboot` come with OpenBSD. BSDs on UEFI machines combine the same pieces, a GPT with the label inside an OpenBSD-type partition and a FAT partition for the loader (inference: OpenBSD's `disklabel.h` defines `GPT_UUID_OPENBSD` and `GPT_UUID_EFI_SYSTEM` and its `efiboot` reads the latter); Linux has no label of its own (unverified). **Impact.** *Kernel:* the label code and tools come with OpenBSD. *Compiler, hardware:* none.

## 4.6 The second stage and the hand-off

The second stage does what the PDP-11's `boot` did: it finds the kernel by name, loads it and enters it (4.1). Being an ordinary program loaded from disk, it can be as large as it needs and be replaced by copying a file. It has its own drivers and no firmware to call.

**The hand-off: how the kernel learns about the machine.** The PDP-11 had four registers and a kernel built for the machine. A kernel that is to run on any pdp64 has to be told about the machine it is on. The way to tell it is a **boot-information block**, a structure in memory. The chain: the PDP-11 passed registers, as did the VAX (`r10`, `r11` to `boot`, 4.2); UEFI passes a memory map and **ACPI tables** or a **device tree** through configuration tables (4.2), and an operating system for several architectures carries a parser for each. The VAX's restart parameter block is a crash-dump record, not a hand-off (4.2); the Alpha's hardware restart parameter block, in OpenBSD's `alpha/include/rpb.h` (read), is a larger record of the same kind: the magic "HWRPB", the page size, the primary CPU, and offsets to per-CPU, console-terminal and memory-data tables, taken from DEC's system programmer's manual. The VAX and Alpha blocks are fixed-layout records of the machine; x86 and ARM servers pass ACPI tables, arm64 and RISC-V a device tree (OpenBSD's loaders look for both, 4.2).

**4.6.1** The second stage carries its own drivers, finds the kernel, loads it and enters it (errata 49: drivers are small, so the second stage carries them). *(D)*

**4.6.2** The kernel is told about the machine through a boot-information block; because the bus describes its own devices, the kernel enumerates them and the block does not list them (2.4). *(D)*

Details pending: which fields the boot-information block has, who fills each, and its layout, widths, checksum and version ([J.4.4](appendix-j-open.md#j44)); how the second stage names the kernel and its file format.

The second stage as pseudocode (an illustration of 4.6.1 and 4.6.2; the file system, the file name and the format are pending):

```
second_stage():                               # loaded by the first stage
    dev = open_boot_device()                  # its own driver (4.6.1)
    read the GPT, then the BSD label of the OS partition (4.5)
    find the root file system and the kernel by name in it
    load the kernel into memory
    add to the boot-information block what only the second stage knows (4.6.3)
    jump to the kernel with the boot-information block
```

**4.6.3** The boot-information block carries the video device's base address, size, pitch and pixel format when the boot loader has set it up, and nothing about the device's clock or power state is changed behind the kernel: its pixel clock stays up until the kernel's driver owns the device. *(D)*

Statement 4.6.3 exists so that the loader can set up a picture for the boot messages and the kernel can keep drawing on it until its own driver takes over, without the screen flickering or going blank: the **framebuffer** the loader set up is described in the block, and the device is left as it is. (That the PC learned this the hard way is the assistant's earlier wording and is unverified.)

*Commentary.* **Chain.** PDP-11: a kernel configured at build time, three or four registers. VAX: registers again (`r10`, `r11`), and a restart block. Alpha: the hardware restart parameter block. UEFI-era systems: ACPI tables or a device tree. pdp64: a boot-information block.

## 4.7 Starting the other cores

**The problem the PDP-11 did not have.** A PDP-11 had one processor, so "start the machine" was one thing. A pdp64 may have several **cores** (processors on one chip; chapter 7), and at reset only core 0 runs the boot code. The kernel has to start the others, each with its own stack and its own idea of who it is. The precedents, from the boot review (`boot.md`; counts measured there in Linux `7be4bc52` and re-counted for this chapter): on x86 the boot core sends INIT and START-UP signals through the interrupt controller (Linux's comment: "INIT, INIT, STARTUP sequence"), the START-UP carrying an address below one megabyte; the other core wakes in the 8086's **real mode** (4.2) and a hand-written **trampoline** (a short program that takes a processor from a limited mode to its full one, through two more modes) must walk it into 64-bit mode. Linux's `arch/x86/kernel/smpboot.c` is 1,528 lines and `arch/x86/realmode` another 1,258. arm64 asks firmware through a call, PSCI, in 124 lines (`arch/arm64/kernel/psci.c`), or has the waiting cores **spin** (loop on a word in memory) on a **spin table** until the boot core writes an address there, in 127 (`smp_spin_table.c`); RISC-V asks the firmware to start a **hart** (its word for a core) in 108 lines (`cpu_ops_sbi.c`) or spins in 58 (`cpu_ops_spinwait.c`). That the VAX console processor started the VAX's other processors is unverified.

**4.7.1** At reset only core 0 runs; the controller chip provides the way in which the other cores are started. *(D)*

Details pending: how a core other than core 0 is started, and what state it starts in ([J.4.6](appendix-j-open.md#j46)).

## 4.8 Starting the devices

**The INIT bit.** On the Unibus every device had a **control and status register** (CSR) with a bit that told the device "initialise yourself" and a bit that said it was ready: you wrote `INIT`, waited for `READY`, and the device was in a known state (the RK11 has `GO` and `RDY` in its CSR and the RX02 floppy controller a bit named `RX_INIT`; 5.1 shows the driver code for each). All the work happened behind the register, in the device's own logic. The pdp64 keeps the idea and makes it a conversation: under virtio (2.7.3) the driver writes **zero** to the device's `device_status` byte, which resets it, then sets the bits `ACKNOWLEDGE`, `DRIVER`, `FEATURES_OK` and `DRIVER_OK` in order, each meaning "I have got this far", and the device answers by refusing or accepting the features the driver chose. That is the `INIT` and `READY` of the CSR spread over a few steps. Said plainly: `INIT` and `READY` are the PDP-11's way of starting a device, and the virtio `device_status` handshake is their descendant. 5.1 and 5.5 explain the idea and what a driver does with it, and 2.7.3 gives the bits and `init_device(fn)`, the pdp64's device start, so they are not repeated here.

**4.8.1** A device is initialised by a write to a register of the device that tells it to initialise itself, and the initialisation happens behind the bus; a device may also be given values, or a binary firmware image, that it loads. *(D)*

Details pending: how a virtio device is given firmware, and which devices need it ([J.4.5](appendix-j-open.md#j45)).

## 4.9 Why UEFI is not used

**4.9.1** The pdp64 does not use UEFI: its boot is the block-0 route of sections 4.4 and 4.5, its hand-off is the boot-information block, and its devices describe themselves. UEFI firmware is not part of the specification and is not built. *(D)*

**4.9.2** The hand-off and the second stage are kept simple enough that a UEFI shim could be written by someone who wanted one. *(D)*

Both statements are the author's decision of 2026-11-10 (errata 109). The record, in his words (the 2026-10-22 messages are in the decision log, thread 1889, messages 2614 and 2620; the 2026-11-10 ones are quoted from errata 109 and 110 and are not in that log). On 2026-10-22 he asked, of boot, "look into uefi; is it worth it at all? can't we do what pdp11 used to do, load 512 byte block 0 then jmp 0? (not precisely true, but directionally true)", and asked how UEFI plays into partitions and the GPT; the review (`boot.md`) answered that UEFI was not worth it as the machine's own boot, and the earlier text's proposals for the boot were never a decision. On 2026-11-10 he asked "i thought we did decide to allow uefi? check all the threads where we discussed it" (no decision to allow UEFI was found in any recorded message), then "or we kept the originnal simple pdp11 boot block method?", and, given three options, chose "option 2, block 0 with a shim possible".

**Is UEFI an open specification, and what does an open-source system do with it?** The author asked, after the decision (2026-11-10): "if uefi isn't an open spec how are all the open source os supporting it? it requires binary firmware blobs?" By what could be checked:

* **The specification** is published by the UEFI Forum, the industry body that maintains it, and can be read without charge (general knowledge, unverified: it is not on this machine, and whether implementing it needs a membership, a licence or a compliance test is not known here). The closed part is elsewhere.
* **An open-source implementation exists.** EDK II, the TianoCore project's reference implementation, is under BSD-2-Clause-Patent (read: `/home/david/claude/qemu-src/pc-bios/edk2-licenses.txt`, and `/usr/share/doc/ovmf/copyright`, "Upstream-Name: edk2"). Built images are on this machine (QEMU's `pc-bios/edk2-*.fd.bz2` and `/usr/share/OVMF`, including `OVMF_CODE_4M.secboot.fd`), so an emulated PC boots under open firmware. The source is not here (`roms/edk2` is empty), so nothing about its size or contents was read.
* **Open-source operating systems write the loader side.** OpenBSD's `efiboot` (read) runs on top of firmware already on the machine and calls its services; it ships no firmware. NetBSD has its own `efiboot` in `sys/arch/i386/stand/efiboot`, which calls `ExitBootServices` like OpenBSD's (read). Linux takes the other route: the kernel is itself a PE/COFF image that the firmware loads, "the EFI boot stub" (`Documentation/admin-guide/efi-stub.rst`, read), so no separate loader exists; the stub still runs on firmware already present. None of the three ships firmware, and a loader needs no blob.
* **The proprietary blobs are in the firmware shipped on real PCs:** the vendor's builds, and the CPU vendor's initialisation code that brings up memory and the chipset, which many boards include as a binary (unverified, not on this machine). That is a property of how PCs are made, not of the UEFI specification.
* **Secure Boot** adds a chain of signed loaders and keys kept in the firmware's variable store (unverified; the `secboot` image names above are all that was seen).

The author's conclusion (2026-11-10): "I guess leaving the door open to uefe support but having the classic mbr fallback, gpt wrapper is a good choice then." That **confirms option 2** of errata 109 and decides nothing new (errata 110). The two routes share one disk: block 0 of the pdp64 disk already has the protective MBR and GPT layout (errata 50, 4.5), so the classic route (the ROM reads block 0) and a future UEFI route (a firmware, or the shim, reads the GPT and a FAT system partition) read the same disk without repartitioning it.

*Commentary.* **Chain.** PDP-11 and VAX: no firmware services. PC: the BIOS, then UEFI to give one installer a way to boot on any machine offering it. OpenBSD's arm64 and riscv64 ports use UEFI and a device tree, with loaders of 7,195 and 4,513 lines; for amd64 the loaders total 15,440 lines, a BIOS boot block of 862 lines and a second stage of 189 beside the UEFI loader of 4,593 (counted; the total includes `libsa`, 6,319). pdp64: block 0, with the door left open. **Trade-offs.** UEFI firmware would let existing generic loaders run unchanged and offer a standard memory map and a secure-boot chain; it costs a large firmware, adds failure modes (variable storage, drivers, boot-order state), enlarges the attack surface, and still needs a device tree or ACPI to describe the devices. **Benefits.** The pdp64 has one architecture and one platform description, the case UEFI was not built for. **Impact.** *Kernel:* no firmware interface, no memory-map translation in the machine itself. *Hardware:* no firmware stack.

## 4.10 Recovery

**4.10.1** The controller's ROM includes a monitor, a small program that takes over when nothing boots and offers a way in to examine and start the machine. *(D)*

A PDP-11 with a dead disk was not a dead machine: `ODT` let you examine memory and key a bootstrap in (4.1), and V7 shipped `/boot.bu`, a backup of the second stage. The monitor is the pdp64's form of the same idea, and the ROM that reads block 0 (4.4) also holds it. Details pending: its commands, how it is reached, its console and speed, and what is kept in non-volatile memory ([J.4.10](appendix-j-open.md#j410)). As pseudocode (an illustration; the command letters and the prompt are not decided):

```
monitor():                                    # the ROM's console program
    loop:
        print("pdp64> ")
        line = read_line(console)
        case first word of line:
            "x" addr [n]    : print n words at addr                  # examine (the PDP-11's `addr/`)
            "d" addr value  : store value at addr                    # deposit
            "g" addr        : start core 0 at addr
            "b" device      : try to boot from this device
            otherwise       : print("?")
```

## 4.11 Five boots side by side

The five referents in the author's order, and the pdp64 as the sixth, as the chains of 4.1 and 4.2 and 4.3 to 4.9 give them. A dagger marks a cell that rests on general knowledge, unverified; the last column says which of the five the pdp64 resembles.

![Five boots and the pdp64](figures/boot-five-boots.svg)

The pdp64 (f), in one paragraph: the ROM in the controller chip runs on core 0, reads block 0 through a virtio-blk request and starts core 0 at it (4.4); the first stage in block 0 loads the second stage (4.5); the second stage finds the kernel by name and enters it with a boot-information block (4.6); the kernel enumerates the bus.

| Property | (a) PDP-11 | (b) VAX | (c) C64 | (d) x86 BIOS, MBR | (e) GPT, UEFI | (f) pdp64, and which it resembles |
|---|---|---|---|---|---|---|
| Who runs first | the processor, then the operator's keys or a ROM† | the console processor† | the 6510 from its reset vector† | the processor at `0xFFFFFFF0`† | the same, then the firmware† | the ROM on core 0: like (a) and (b), without the operator |
| Where the first code lives | front panel or boot ROM | console ROM and storage† | the KERNAL ROM† | firmware flash† | firmware flash† | a ROM in the controller chip: like (a) and (c) |
| How big the first code may be | a few dozen words (keys)†, a ROM's size†; block 0 of 512 bytes (read) | the boot block; the 750 loaded 7.5 KB next (read) | the ROM's 8 KB† | 446 bytes in the MBR (read) | the loader file, any size† | the ROM's size; block 0 of 512 bytes: like (a) |
| How it finds the next stage | block 0 reads a name (`boot`) by walking inodes; `boot` reads `hp(0,0)unix` (read) | the boot block loads sectors 1 to 15; `boot` opens a name (read) | it does not: `LOAD` by the user† | the active flag in the table, then `INT 13h` reads (read) | the boot variables and the GPT's type, then a name on FAT† | block 0 loads the second stage, which finds a name: like (b) and (a) |
| What the hand-off carries | registers (2.11BSD: `r0`, `r1`, `r3`, a check word) (read) | `r10`, `r11` to `boot` (read) | nothing: the program owns the machine† | registers and the BIOS's memory map† | the memory map and ACPI or a device tree (read) | the boot-information block: like (e) in being a description of the machine |
| How it is repaired | keys, `ODT`†, the backup `/boot.bu` (read for the last) | the console† | the ROM cannot be damaged by storage; a cartridge† | re-write the MBR from another disk† | the firmware's setup and boot manager† | by writing the disk from another machine: like (d) |
| What is open source | the BSD and V7 stages (the sources here); ROMs† | the BSD stages (read); the console† | the ROMs are Commodore's† | the loaders, in OpenBSD (read); the BIOS is a vendor's† | the specification is published†; EDK II is BSD-2-Clause-Patent (read, 4.9); shipped firmware often not† | everything, by decision (4.3.2) |
| How many programs before the kernel | 3 (ROM or keys, block 0, `boot`) | 3 (console, boot block, `boot`) | 1 (ROM) or 2 with a cartridge† | 4 (BIOS, `mbr.S`, `biosboot`, `/boot`) (read) | 3 or more, with firmware phases† | 3 (ROM, block 0, second stage): like (a) and (b) |
| What recovery exists | `ODT` and the front panel† | the console† | reset, a cartridge† | the BIOS setup, a rescue disk† | the setup, rescue media, a fallback loader name† | the same disk readable by a UEFI route (4.9) |

Property by property, the pdp64's boot is the PDP-11's and the VAX's: a ROM, a first block, a second stage that finds a file by name, a hand-off to the kernel. It takes two things from the PC: the protective MBR and the GPT (d, e), and, in the boot-information block, a description of the machine (e) that the PDP-11 and the VAX did not pass. From the C64 it takes the ROM as the first code, undamaged by what is on storage; the C64 had no second stage. It differs from all five in that every stage is open source.

## 4.12 What was checked, and what was not

The rule of the project is: check, do not guess. The handbooks and specifications are not on this machine. What each fact rests on:

* **Unix sources** (`/home/david/claude/facetlang/unixtree`, files are gzipped): V7M `sys/mdec/hpuboot.s` (285 lines), `sys/sas/boot.c` (272 lines), the `boot(8)` page, `sas/htboot.s` (the M9312 comment), `dev/hp.c` (24 entries); 2.11BSD `man4/cons.4` (`ODT`), `mdec/rkuboot.s` (the `nop` and `br` that DEC's ROMs require, `r0` and `r1`), `pdpstand/boot.c` (the `r2` comment); V7 `usr/sys/dev/hp.c` (`hp_sizes[8]`, "cyl 44 thru 429"); 2.11BSD's `boot(8)` page, `sys/mdec/hpuboot.s` (the 512 and 494 bytes), `sys/pdpstand/srt0.s` (`r0`, `r1`, `r3`) and `boot.c` (`checkword`), `sys/h/disklabel.h`; 4.3BSD-Tahoe `h/disklabel.h` (the block 0 or 1 comment, the 8 KB boot-area comment, `0x82564557`, 8 partitions), `mdec/raboot.c` (registers, 7.5 KB, `0x50000`, `BOOTLAST`), `vaxstand/boot.c` (`r10`, `r11`, `Boot`, `:`), `vaxstand/saio.h` (the default name), `vax/rpb.h`; 4.3BSD `vaxmba/hp.c` (size tables); OpenBSD 4.6 `sparc/stand/installboot/installboot.8`.
* **OpenBSD** (`/home/david/claude/kernel-src/openbsd`, commit `2114d7b7`): `sys/sys/disklabel.h` (`DOSPARTOFF` 446, the signature at `0x1fe`, type `0xee`, "EFI PART", `gpt_header`, `gpt_partition`, `NGPTPARTITIONS` 128, `GPTMINPARTSIZE` 128, `GPTPARTNAMESIZE` 36, `MAXPARTITIONS16`, `d_secperunith`, both GUIDs); the `arch/*/include/disklabel.h` label sectors; `arch/amd64/stand` (`mbr.S` 521 lines, `biosboot.S` 862 and `biosboot.8` ("roughly 512 bytes of code", the `installboot` patching, "its inode may change"), `boot/` 189, `libsa` 6,319, `efiboot` 4,593, 15,440 in all); `arch/arm64/stand/efiboot` (7,195 lines, `start.S` 176, `self_reloc.c` 124) and riscv64 (4,513); the `ExitBootServices` retry.
* **Other trees:** OpenBSD `share/man/man9/loadfirmware.9`, `arch/alpha/include/rpb.h`, `arch/sparc64/stand/ofwboot`, the `sbi_*` calls in `arch/riscv64`; NetBSD `share/man/man9/firmload.9` and `sys/arch/i386/stand/efiboot`; QEMU `pc-bios` (the `openbios`, `u-boot` and `opensbi` image names); Linux `include/linux/firmware.h` and `Documentation/admin-guide/efi-stub.rst`.
* **Linux** (`/home/david/claude/kernel-src/linux`, `7be4bc52`), re-counted: `smpboot.c` 1,528 lines, `arch/x86/realmode` 1,258 (`.c`, `.h`, `.S`), PSCI 124, spin table 127, RISC-V SBI start 108 and spin 58.
* **EDK II:** the licence in `qemu-src/pc-bios/edk2-licenses.txt` and `/usr/share/doc/ovmf/copyright`; the x86-64 code image 3,653,632 bytes uncompressed; the `secboot` image names in `/usr/share/OVMF`; no source in `roms/edk2`.
* **The repository:** the statements of this chapter against `docs/errata.md` (47, 48, 50, 51, 95, 101, 102, 103, 109, 110), `docs/boot.md`, chapters 2, 5 and 6 (2.3.5, 2.7.3, 5.1, 6.12), and the author's messages of 2026-10-22 in `docs/decision-log` (threads 1889, messages 2614, 2620, 2631).
* **Unverified** (general knowledge): the front panel's switches and keys and the bootstrap loader of a few words; that a console switch or command chose the boot device; that `ODT` can examine, deposit and start; the date of the IBM PC and the 8086; the BIOS's four jobs and its other services; real mode and the 1 MB limit; the reset vector `0xFFFFFFF0`, the load address `0x7C00` and the boot-device order; the whole Commodore 64 boot (`0xFFFC`, KERNAL, `CBM80` at `0x8000`, BASIC, datasette, 1541); the VAX console processor, VMB and that the console started other processors; the name SRM for the Alpha console; the IBM mainframe IPL record; ARM first-stage loaders; resident system-management code in x86 firmware; the UEFI boot manager, NVRAM variables and Secure Boot; that the UEFI specification requires PE32+ images and FAT on the system partition; the publication terms of the UEFI specification; that the PC learned the video lesson of 4.6.3 "the hard way".
* **Decided by the author and recorded in `errata.md`:** everything stated as a decision with a tag *(D)*. The author's 2026-11-10 words are quoted from errata 109 and 110, which are not in the decision log.

