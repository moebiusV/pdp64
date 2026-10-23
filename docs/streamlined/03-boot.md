# 3. Boot, the BIOS, the disk label and the GPT

[← streamlined index](00-index.md)

**The machine starts the way the PDP-11 did: a small ROM in the controller chip loads one block from the boot device and jumps to it, and every later stage is an ordinary program, open source, compiled by the project's own compiler.** This chapter says what starts the machine, what takes the place of a BIOS, how the disk is laid out, how other cores and devices are started, and why UEFI is not used. The full review of how other systems boot is [`../boot.md`](../boot.md). Tags: *(D)* decided; *(P)* proposed and not yet settled.

## 3.1 What takes the place of a BIOS

**3.1.1** The pdp64's "BIOS" is the controller chip's boot ROM and its monitor. It brings up the machine, loads the first block, and offers a console monitor when nothing boots. It has no resident services and nothing is called after boot. *(P)*

**3.1.2** The boot software is open source and part of the specification: the ROM and monitor, the first-block program, the second-stage loader and the boot tools. *(D, errata 47)*

**3.1.3** Everything in the project, the boot software included, is under the BSD 2-clause licence. *(D, errata 48)*

*Commentary.* **Precedent.** A BIOS did four jobs: hardware bring-up and self-test, the first code (read the boot sector and jump), a runtime library of device services called by software interrupt (the "I/O" in its name), and configuration. UEFI replaced the second and third with a loader file and a set of boot and runtime services, and the other architectures have the same roles under other names: Open Firmware on SPARC and PowerPC, U-Boot with trusted firmware on ARM, OpenSBI on RISC-V, the SRM console on Alpha, the console processor on the VAX, and the boot ROMs and `ODT` monitor on the PDP-11. **Trade-offs.** The pdp64 needs only the first, second and fourth jobs in a small form. The third disappears because the devices have one uniform register layout (chapter 5) that the loader and the kernel share, so the loader needs no firmware to read a disk. The cost is that the second-stage loader carries its own drivers, which the author has settled is small because a driver drives eight registers. **Improvements.** There is no firmware API to specify, no compatibility layer, no resident management code and no closed blob at the bottom of the trust chain. **Benefits.** The failure cases reduce to one: the first block did not load, and the monitor is the recovery. **Modern comparables.** x86 firmware keeps resident system-management code that the operating system cannot see; arm64 and RISC-V servers need trusted firmware and, usually, UEFI beside it.

## 3.2 The reset state and the first block

**3.2.1** At reset the controller brings up memory, holds every core in reset, and looks for a boot device in a fixed order: disk or flash, then SD card, then the serial line. *(P)*

**3.2.2** It reads block 0 of the first device that answers into low memory, checks the `0x55AA` signature in the last two bytes, and starts core 0 at that address. It does not parse a partition table. *(P)*

**3.2.3** Core 0 starts in kernel mode at priority 7 with translation off (every address physical), `VBR` zero and the user-memory guard clear; `r0` holds the boot device number, `r1` the address of the boot-information block, `r14` the top of the first 64 KB of memory, and the other registers are zero. *(P)*

**3.2.4** If no boot device answers, or a key is held at power-up, the monitor runs on the serial console. *(P)*

*Commentary.* **Precedent.** The PDP-11 read block 0 of the boot device into low memory and jumped to it, from a boot ROM or a few words keyed in on the front panel; the VAX console processor did the same with the boot block and passed the boot device in registers; the mainframe's IPL record and the Alpha console's boot block are the same idea. In V7 the second stage was about 250 lines of PDP-11 assembler that read a pathname and loaded the kernel. **Trade-offs.** A boot ROM with a driver per boot device is more code in the controller than a "jump to a fixed flash address" scheme, and much less than firmware; the first block must fit in one sector. **Improvements.** The reset state is specified in full, a thing the earlier machines left to the console. **Benefits.** The first stage is the same on every board. **Modern comparables.** A PC's BIOS reads one 512-byte sector; ARM boards load a first-stage loader from the boot medium; UEFI runs a file from a FAT partition.

## 3.3 The disk: a GPT around the BSD label

**3.3.1** The disk carries a GUID partition table with a protective MBR; the operating system's own partition holds the BSD disk label, which names the root, swap and other partitions. *(D, errata 50)*

**3.3.2** Block 0 is the protective MBR, so the first stage lives in its 446 boot-code bytes, carrying a short block list (start block, count, load address) to the second stage; neither the ROM nor the first stage parses the GPT. *(P, decision B8)*

**3.3.3** Inside the BSD partition, the label is at sector 1, offset 0; the boot area is 8192 bytes at the start of the partition; the file system begins after it, its superblock at offset 8192. *(D, errata 51)*

| Sector (512 bytes) of the BSD partition | Contents |
|---|---|
| 0 | the partition's own boot block |
| 1 | the disk label, at offset 0 |
| 2 to 15 | the rest of the 8 KB boot area |
| 16 on | the file system, superblock at offset 8192 |

**3.3.4** Sector counts are 64-bit throughout; the label has 16 partitions and its sizes carry high fields beyond 32 bits. *(D)*

*Commentary.* **Precedent.** V7 had no partition table on the disk: each driver compiled in an array of eight sizes and starting cylinders (`hp_sizes[8]` in `hp.c`), and changing the layout meant recompiling the kernel. The disk label arrived with 4.3BSD-Tahoe in 1988, in sector 0 or 1 "possibly offset from the beginning to leave room for a bootstrap", with the magic number `0x82564557`; OpenBSD's label is its descendant, with the same magic number, 16 partitions and 64-bit sizes. In the OpenBSD tree seven architecture headers put the label at sector 1 offset 0 (amd64, i386, arm, arm64, riscv64, hppa, powerpc64); Alpha and SPARC64 put it at sector 0. The PC used the MBR, a four-partition table in sector 0 with 446 bytes of boot code, and UEFI requires the GPT, whose header is in the second block, with a backup at the end of the disk and a protective MBR in block 0. **Trade-offs.** The label alone would have been the smallest design and would have been unreadable to other systems' tools; the GPT wrapper costs a GPT reader in the second stage and the kernel (OpenBSD's kernel already has one) and puts the protective MBR in block 0, and gives a disk that other operating systems and partitioning tools recognise. Following the majority on the offsets means the port adds one header of a dozen lines. **Improvements.** The first stage does not depend on a GPT that may be damaged, so a corrupted table cannot stop the machine reaching the second stage, which can repair it. **Benefits.** The label code, `disklabel`, `newfs` and `installboot` come with OpenBSD. **Modern comparables.** BSDs on UEFI machines use a GPT with the label inside an OpenBSD-type partition and a FAT partition for the loader; Linux has no scheme of its own.

## 3.4 The second stage and the hand-off

**3.4.1** The second stage is a program in C that understands the root file system, reads the GPT and the label, loads `/bsd` (an ELF file) and jumps to it with `r0` and `r1` as before and a command line in the boot-information block. *(P)*

**3.4.2** The boot-information block names the memory ranges, the core count, the address of the bus controller and the slots of the boot device and the console; the kernel enumerates every other device by asking the bus. *(P)*

**3.4.3** The block's layout is defined once, in a grammar from which the headers are generated, and carries a checksum and a version. *(P)*

*Commentary.* **Precedent.** The VAX passed a restart parameter block, the Alpha a hardware restart parameter block, both fixed-layout records of the machine; the PDP-11 configured the kernel for the machine at build time and probed device addresses; x86 uses ACPI tables, and arm64 and RISC-V use a device tree. **Trade-offs.** A fixed-layout block with a checksum has two failure cases (bad checksum, unknown version), against the parser a device tree or ACPI requires; a device tree has the advantage that OpenBSD's arm64 and riscv64 ports already parse one and attach drivers from it, which could save kernel code if the port reuses many of their drivers. **Improvements.** Because the bus describes its own devices, the block shrinks to memory, cores and the bus controller's address. **Benefits.** The hand-off is a struct; the generated header cannot disagree with the loader. **Modern comparables.** The device tree and ACPI are the two standard answers.

## 3.5 Starting the other cores and the devices

**3.5.1** The controller holds every core except core 0 in reset; a write to a core's start register in the controller gives it an entry address and an argument and releases it into kernel mode at priority 7, with its core number in `r0` and the argument in `r1`. *(P, decision B2)*

**3.5.2** A stuck core is reset by a write to a core-reset register. *(P)*

**3.5.3** A device is initialised by writing its `INIT` bit and waiting for `READY`; a device that wants firmware is given it through a descriptor operation once the root file system is available, and a device the boot depends on needs no firmware. *(P, decision B4)*

*Commentary.* **Precedent.** On x86 the boot core sends INIT and START-UP interrupts through the APIC and each other core wakes in 16-bit real mode, then has to be walked through protected mode into 64-bit mode by a trampoline: the Linux `smpboot.c` is 1,528 lines and the real-mode code another 1,258. arm64 uses a firmware call (PSCI) in 124 lines or a spin table in 127; RISC-V asks the firmware to start a hart in 108 lines or spins in 58. The VAX's console processor started its other processors. **Trade-offs.** The pdp64 has no mode ladder, so a core can start in its normal mode at any address and the whole protocol is one register write, at the cost of a small register block in the controller. **Improvements.** There is no trampoline and no firmware call. **Benefits.** Fewer lines than any system measured and one recovery path, a core reset. **Modern comparables.** PSCI, the SBI hart-state calls, and x86's INIT and START-UP sequence.

## 3.6 Why UEFI is not used

**3.6.1** The pdp64 does not use UEFI: its boot is the block-0 route of this chapter, its hand-off is the boot-information block, and its devices describe themselves. *(P, the author's inclination; a decision to confirm)*

**3.6.2** The hand-off and the second stage are kept simple enough that a UEFI shim could be written by someone who wanted one. *(P)*

*Commentary.* **Precedent.** UEFI is a firmware specification of boot services, runtime services, a memory map, the GPT, the PE/COFF executable format and a driver model, implemented usually by the open-source EDK II or by a vendor. Its aim is that one installer boots on any machine that offers it. OpenBSD's arm64 and riscv64 ports use UEFI and a device tree, and its own loaders for them are 7,195 and 4,513 lines; for amd64 the loaders total 15,440 lines, including a BIOS boot block of 862 lines and a second stage of 189 beside the UEFI loader of 4,593. **Trade-offs.** UEFI would let existing generic loaders run unchanged, offers a standard memory map and a secure-boot chain, and costs a great deal of firmware (an EDK II port to a new architecture, in a new executable format), adds failure modes (variable storage, drivers, boot-order state), enlarges the attack surface, and still needs a device tree or ACPI to describe the devices. **Improvements.** The pdp64 has one architecture and one platform description, which is the case UEFI was not built for. **Benefits.** Smaller (principle 1), fewer failures (principle 2), fewer gates and less flash (principle 3). **Modern comparables.** x86 servers, arm64 servers and RISC-V servers all use UEFI; OpenBSD itself still ships a BIOS-style loader beside the UEFI one on amd64.

## 3.7 Recovery

**3.7.1** The controller's ROM includes a monitor reached on the serial console when nothing boots: examine and deposit memory and registers, load a program over the serial line, start at an address or from a named device, reset a core, reset the machine. *(P)*

**3.7.2** A hardware watchdog restarts the machine if the kernel hangs. *(P, decision P7)*

*Commentary.* **Precedent.** The PDP-11's console `ODT`, a monitor in ROM for examining and depositing memory and starting at an address, and the VAX console processor were the way in when nothing booted. **Trade-offs.** A monitor is a few hundred bytes of ROM and needs a working serial port and nothing else. **Benefits.** The same monitor brings up a new board before any boot device works, and it is the simplest recovery path of all: it needs the least code to write. **Modern comparables.** U-Boot's console and OpenSBI's debug console fill this role; PC firmware has a setup screen.

## 3.8 Still open

The boot chapter's open items, in [`../boot.md`](../boot.md): the address the first block is loaded to, the partition type of the boot partition (and whether a dedicated boot partition is needed at all, since the first stage's block list can point at the second-stage file in the root file system), the device-tree option, the details of the GPT (to be checked against the UEFI specification), and the PDP-11 power-up behaviour and the VAX and Alpha boot protocols (to be checked against their manuals).
