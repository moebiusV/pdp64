# Boot and bring-up: how the machine starts and how the other chips and cores are started

[← pdp64 index](../README.md)

**Status: first draft, 2026-10-22, for the author's review.** Nothing here is decided unless it says so. This document reviews how the main systems start themselves (first instruction, firmware, the hand-off to the kernel, the other processors, the devices), asks whether UEFI is worth having, and compares it with the PDP-11's way (read block 0, jump to it). It then sets out five decisions in the same form as [`decisions-pending.md`](decisions-pending.md) (need, explanation, five options, what other systems do, what the PDP-11 and VAX did, a recommendation judged by the author's three principles) and ends with one concrete proposal.

**Evidence labels.** *(measured)* is a count I made in the source trees on this machine (Linux `7be4bc52` and OpenBSD `2114d7b7` as cloned for the kernel survey; sizes are lines of `.c`, `.S` and `.h` files, which count comments and blank lines). *(read in source)* is something I read in those trees or in the old Unix sources under `../facetlang/unixtree`. *(not confirmed in the sources read)* is from my general knowledge: the architecture and firmware specifications (UEFI, PSCI, SBI, ACPI) were not opened for this draft and should be checked before a decision rests on them.

## Contents

* [What the documents already say](#what-the-documents-already-say)
* [What booting has to do](#what-booting-has-to-do)
* [How the main systems do it](#how-the-main-systems-do-it)
* [How the PDP-11 and the VAX did it](#how-the-pdp-11-and-the-vax-did-it)
* [Is UEFI worth it?](#is-uefi-worth-it)
* [What a BIOS is for, and whether the pdp64 needs one](#what-a-bios-is-for-and-whether-the-pdp64-needs-one)
* [Decisions B1 to B5](#decisions-b1-to-b5-b6-and-b7-follow-the-disk-layout-section)
* [Disk layout and partitions](#disk-layout-and-partitions)
* [A concrete proposal: the pdp64 boot sequence](#a-concrete-proposal-the-pdp64-boot-sequence)
* [Recovery: when boot fails](#recovery-when-boot-fails)
* [What to verify next](#what-to-verify-next)

## What the documents already say

Little, and all of it open. The system architecture ([`pdp64-system-architecture.md`](pdp64-system-architecture.md) section 9) records two facts and four open questions. *Established:* the machine comes up with the direct-mapping window `DMW0` covering physical memory (ISA 8.3), and resetting the bus is a bus-controller register write, not an instruction. Since errata 44 the System v1 reset state is `MMUCTL` = 0, every address physical, and the QEMU virt machine starts in kernel mode at priority 7 at the entry point of the ELF given with `-kernel`; vector 0 ("reset") exists in the vector table but the virt machine does not use it. *Open:* the reset state and which registers are defined, the reset vector and where the first instruction comes from, the firmware or boot ROM and what it hands to the kernel, and the boot protocol for releasing secondary cores (ISA 17.4 lists it as "still to be built, device side"). The bus document (`pdp64-q64-bus.md`) lists the interrupt controller and the secondary-core boot protocol as open item 6 and the device convention (eight registers plus DMA) as decided in outline, with the register layout undefined. So the author's question has a plain answer: **boot has not been designed.**

## What booting has to do

Seven jobs, in order. Different systems put them in different places, and that is the whole subject.

1. **Power and clocks:** bring up the supply rails and the clock generators. On a real chip this is a small hard-wired sequencer; on the FPGA board it is the board's own logic.
2. **Memory:** make the DRAM usable. On real silicon this is the hardest part of boot (the controller must be trained to the exact timing of the installed memory; on x86 and ARM servers it is thousands of lines of vendor firmware). On the FPGA the vendor's memory-controller block does it. Until it is done the first code must run from on-chip memory or ROM.
3. **The first code:** some instruction fetch must start from somewhere that holds code at power-up: a ROM, a flash, or a block read from a device by hard-wired logic.
4. **Finding and loading the operating system:** read it from a disk, flash, network or serial line into RAM, which needs a driver for at least one boot device and enough file-system knowledge to find the kernel.
5. **The hand-off:** tell the kernel what machine it is on: how much memory and where, which devices exist and where their registers and interrupts are, how many processors, where it was loaded from, the command line.
6. **The other processors:** get the secondary cores from reset into the kernel, each with its own stack and its own idea of who it is.
7. **The devices:** each device must be initialised (reset, configured, sometimes given firmware) before a driver can use it.

## How the main systems do it

| System | First code | Who loads the OS | Hand-off to the kernel | How the other CPUs start |
|---|---|---|---|---|
| **x86 PC** | the processor fetches from a fixed address at the top of 4 GB, where a firmware flash holds BIOS or UEFI (or coreboot) *(not confirmed in the sources read)* | firmware; a BIOS reads one 512-byte sector (the "boot sector") and jumps to it, a UEFI firmware runs a loader file from a FAT partition | the E820 memory map or the UEFI memory map, plus ACPI tables for devices and processors | the boot processor sends INIT and START-UP inter-processor interrupts (INIT, INIT, SIPI) through the local APIC; each other processor starts in 16-bit real mode at a page-aligned address below 1 MB and must climb to protected and then 64-bit mode through a hand-written trampoline *(read in source: `arch/x86/kernel/smpboot.c` "Wake up AP by INIT, INIT, STARTUP sequence", 1,528 lines; `arch/x86/realmode` 1,258 lines (measured))* |
| **ARM64 (servers, phones, boards)** | ROM code in the SoC, then trusted-firmware stages (BL1, BL2, BL31) and a bootloader (U-Boot or UEFI) *(not confirmed in the sources read)* | the bootloader or UEFI loads the kernel image | a device tree blob, or ACPI tables plus the UEFI memory map | a firmware call, PSCI `CPU_ON`, made through an `hvc` or `smc` instruction (`arch/arm64/kernel/psci.c`, 124 lines); or on simple boards a **spin table**: secondary cores park in a wait loop on a memory address and the boot core writes the entry address there and signals (`smp_spin_table.c`, 127 lines) *(both read in source)* |
| **RISC-V** | machine-mode firmware (OpenSBI), which also stays resident and offers services | OpenSBI hands control to a loader (U-Boot or UEFI) and then the kernel | a device tree (or ACPI) | the kernel asks the firmware to start a "hart" with `sbi_hsm_hart_start` (`cpu_ops_sbi.c`, 108 lines), or a spin-wait fallback (`cpu_ops_spinwait.c`, 58 lines) *(read in source)* |
| **PowerPC / POWER** | an Open Firmware or OPAL layer; on the Linux side the boot code includes a client for Open Firmware, `prom_init.c` | the firmware | a device tree built by the firmware client (`prom_init.c`, 3,460 lines (measured)) | firmware calls or a spin table, per platform; `arch/powerpc/kernel/smp.c` is 1,828 lines (measured) |
| **IBM mainframe (s390)** | **IPL**: the hardware reads a record from the chosen device with a built-in channel program and loads the program status word it contains: a first-block bootstrap done by logic, not firmware *(not confirmed in the sources read)* | the IPL record loads a bigger loader | a small fixed block of low-memory data | the `SIGP` (signal processor) instruction, with an order to start a given CPU (`arch/s390/kernel/smp.c`, 1,155 lines; `arch/s390/boot`, 4,152 lines (measured)) |
| **MIPS** | firmware (YAMON, U-Boot) or a boot ROM | the firmware | a device tree or a boot-argument block | a cluster power controller starts cores (`smp-cps.c`, 976 lines) |
| **SPARC64** | OpenBoot firmware, a Forth-based monitor | the firmware | the firmware's device tree, queried by the kernel | firmware calls, `smp_64.c` is 1,563 lines (measured) |
| **Alpha** | the SRM console firmware | the console reads **block 0 of the boot device** (which carries a checksum and a pointer to the next stage) and jumps | the **HWRPB**, a hardware restart parameter block, a fixed-layout record of the machine | the console starts the secondary CPUs *(not confirmed in the sources read)* |

**What this shows.**

* **Every system has a first stage that is smaller than the rest.** The BIOS boot sector, the s390 IPL record, the Alpha boot block and the PDP-11 block 0 are all "load a small block and jump", and the later stages do the real work.
* **Only x86 needs the trampoline.** A secondary x86 core wakes up in the 16-bit mode the 8086 had in 1978 and must be walked through three modes, which is where 1,258 lines of real-mode code and much recovery code come from. A machine that is always 64-bit (the pdp64) has no such ladder: a core can start in its normal mode at the address it is given.
* **The secondary-core start is small everywhere it is a firmware call or a register.** The arm64 PSCI and spin-table paths are 124 and 127 lines, the RISC-V ones 108 and 58, against 1,528 lines for the x86 start-up code.
* **The hand-off is where the standards fight.** x86 uses ACPI, arm64 and RISC-V use device trees (and ACPI on servers), PowerPC and SPARC use Open Firmware trees, the mainframe and Alpha use a fixed block. A kernel that must support several carries a parser for each.
* **Real firmware is large.** OpenBSD's loaders in `sys/arch/*/stand`, which only load a kernel and read its device description, are 15,440 lines for amd64 (`libsa` 6,319; `efiboot` 4,593; the BIOS boot block `biosboot` 862 and the second stage `boot` 189), 7,195 for the arm64 UEFI loader and 4,513 for the riscv64 one (measured). That is only the part OpenBSD writes; the firmware underneath (UEFI, OpenSBI, trusted firmware) is separate code.

## How the PDP-11 and the VAX did it

**PDP-11.** A small bootstrap, either a ROM on the processor board (the M9312 console-emulator ROMs offered one per device) or a short program keyed in from the front panel, read **block 0 of the boot device into low memory and jumped to it**. The V7 source on disk shows the second stage: `usr/mdec/hpuboot.s` and `rpuboot.s`, about 250 lines of PDP-11 assembler each (read in source), which a block 0 loads; it sets up a stack, clears memory, reads a pathname, finds the file system's `unix` and jumps to it. The comment at its top says the entry is made "by `jsr pc,*$0`", so the loaded program may simply return to the boot code. In the other direction the console had `ODT`, a monitor in ROM for examining and depositing memory and starting at an address (not confirmed in the sources read), which doubled as the recovery path when nothing booted.

**VAX.** A **console processor** (on the VAX-11/780 a separate small computer) did power-up self-test and then read block 0 of the boot device, the boot block, into memory and started it with registers describing the boot device. The kernel was handed a **restart parameter block** (`vax/rpb.s` and `rpb.h` are in 4.3BSD; read in source) with the machine's state, and the 4.3BSD second stage `stand/boot.c` takes its arguments in `r10` and `r11` ("determine whether boot stops to ask for system name and which device boot comes from", read in source). The console processor also started other processors on multiprocessor models (not confirmed in the sources read).

**What they got right.** A tiny first stage; a fixed-layout hand-off block (the RPB; Alpha's HWRPB followed the same idea); a human recovery path (the console); and a boot that needed nothing the machine's own logic did not already have. The pdp64's FPGA plan lists a "kernel that boots" as phase 6 and a PDP-11/V7 descendant as the goal, so this is the lineage.

## Is UEFI worth it?

**What UEFI is.** A firmware specification, not a boot protocol: a large set of services the firmware offers to a loader (boot services such as memory allocation and file access, runtime services such as the clock and reset, a standard way to describe the memory map, a partition format (GPT), an executable format (PE/COFF) and a driver model), usually implemented by the open-source EDK II or by a vendor's firmware *(not confirmed in the sources read)*. Its aim is that one operating-system installer boots on any machine that offers it.

**What it would give the pdp64.**

* Existing operating-system loaders that expect it (a generic OpenBSD or Linux UEFI loader) would run unchanged.
* A standard memory-map hand-off, standard partition and file access (FAT on an EFI system partition), a runtime clock and reset call.
* A secure-boot signature chain, if ever wanted.

**What it would cost.**

* **A great deal of firmware.** UEFI firmware stacks are measured in hundreds of thousands to millions of lines of C *(not confirmed in the sources read)*; the pdp64 would need an EDK II port to its architecture (PE/COFF, calling convention, exception handling, timers, the whole platform layer). That is a compiler, linker and format project (PE/COFF instead of the toolchain's ELF) before any boot code runs. It is the opposite of principle 1 (code size) and principle 3 (gates and flash space).
* **More failure modes, so more recovery code** (principle 2). UEFI adds its own failure cases: variable storage corruption, driver faults, boot-order and boot-manager state, firmware updates. The PDP-11 way has one failure case, "block 0 did not load", with an obvious recovery (the console monitor).
* **Large attack surface.** Firmware bugs have been a recurring source of vulnerabilities, and the firmware runs at the highest privilege *(not confirmed in the sources read; to be listed in the hardware-vulnerabilities document)*.
* **It does not remove the need for a platform description.** UEFI still needs ACPI or a device tree to describe the devices; arm64 and riscv64 OpenBSD use UEFI **and** a device tree (the `efiboot` loaders above, 7,195 and 4,513 lines, are OpenBSD's own code for that).
* **It is the heavyweight answer to a problem the pdp64 does not have:** a world of many incompatible machines and many installers. The pdp64 is one architecture with one platform description and one first operating system.

**Verdict, by the principles.** Not worth it as the machine's own boot mechanism. It fails principle 1 (size), principle 2 (more failure modes) and principle 3 (more gates and flash) outright, and what it offers (generic loaders) is not wanted when the first operating system is one the author controls. The cheap way to keep the door open is to keep the hand-off block (B3) simple and to make the second-stage loader replaceable, so a UEFI shim could be added later by someone who wants it. OpenBSD itself still ships a BIOS-style loader beside the UEFI one on amd64 (`biosboot` and `boot` above), which shows that the block-0 route remains normal practice for a system this small. **The author's instinct is right**: load a small first block, jump to it, and let the heavy work be ordinary programs compiled with the project's own compiler.

## What a BIOS is for, and whether the pdp64 needs one

**The name and the history.** BIOS means Basic Input/Output System. On the original IBM PC (1981) the BIOS was the ROM firmware, and it did four separate jobs that are worth pulling apart, because the name has stuck to all four *(this section is from general knowledge and not confirmed in the sources read; the specifications were not opened)*:

1. **Hardware bring-up and self-test** (the power-on self-test, POST): initialise the chipset, size the memory, check the basics.
2. **The first code:** find a boot device, read its first sector (the 512-byte boot sector) into memory at a fixed address and jump to it.
3. **A runtime library of services**, called by software interrupt from real mode: video (`INT 10h`), disk (`INT 13h`), keyboard (`INT 16h`), the memory map (`INT 15h`) and others. This is the "I/O" in the name. MS-DOS and every boot loader used these calls as their drivers, which is why a 512-byte boot sector could read the rest of the disk without containing a disk driver.
4. **Configuration:** a setup screen and a small battery-backed memory (CMOS) for the clock and the settings.

**What the role is in a UEFI system.** UEFI is the later firmware standard and it replaces jobs 2 and 3: instead of reading a boot sector it runs a loader program from a file on a FAT partition, and instead of software interrupts it offers **boot services and protocols** (block I/O, simple text, a graphics output protocol, file access) that a loader calls, plus a few **runtime services** (clock, reset, variables) that remain usable by the operating system after boot. Job 1 (bring-up) and job 4 (setup) stay, and many people still say "the BIOS" for the setup screen. Machines may carry a **compatibility support module** that emulates the old BIOS services for operating systems that still expect them, which is being phased out *(not confirmed in the sources read)*. UEFI systems on x86 also keep a firmware that stays resident after boot, **system management mode** code, which the operating system cannot see and which has been a source of security problems *(not confirmed in the sources read)*.

**Apart from the x86 lineage, the same roles exist under other names.** Every architecture has some platform firmware, and it has the same jobs: bring up clocks, memory (including the memory-training code, which is the largest part on real silicon) and the buses; provide the first code; give the loader a way to read a boot device; describe the machine to the kernel; and sometimes offer a few runtime calls. Open Firmware on SPARC and PowerPC, U-Boot and the trusted-firmware stages on ARM, OpenSBI on RISC-V, the SRM console on Alpha, the console processor on the VAX, the boot ROMs and `ODT` monitor on the PDP-11 all fill the role *(not confirmed in the sources read)*. What differs is how much of job 3 they provide. A BIOS or UEFI firmware provides device drivers to the loader through its services; the PDP-11 boot ROMs carried a small driver per device; Open Firmware provides device access through its client interface. A loader on a machine with **no** firmware services has to carry its own drivers, which is why OpenBSD's `libsa` (the loader's support library: file systems and device access) is 6,319 lines on amd64 (measured).

**Does the pdp64 need one?** It needs jobs 1, 2 and 4 in a minimal form, and it can do without job 3 entirely:

| Job | The pdp64 answer |
|---|---|
| 1. Bring-up and self-test | the controller chip's sequencer and, on the FPGA, the vendor's memory-controller block; a short memory check in the ROM monitor |
| 2. The first code | the controller's boot ROM reads block 0 (decision B1) |
| 3. A runtime library of services | **none.** The device registers are already uniform (decision R5): the second-stage loader and the kernel talk to the same registers, so the loader needs no firmware to read a disk, and the loader's driver code is the same code the kernel's drivers are built from. This also matches decision P7 (no firmware calls). The only thing the kernel asks of the firmware afterwards is a reset, and that is a controller register |
| 4. Configuration | a few settings in the controller's non-volatile memory (boot order, serial speed), changed from the ROM monitor |

So **the pdp64's "BIOS" is the controller's boot ROM and its monitor, a few hundred bytes to a few kilobytes, with no resident services and nothing to call after boot.** That is the PDP-11 and VAX arrangement (ROM bootstrap plus console), not the PC's. The cost is that the second-stage loader must carry the drivers for its boot devices; the benefit is that there is no firmware API to specify, no compatibility layer, no system management code, and no failure modes beyond "the first block did not load". Under the principles that is the smaller (1), simpler (2), cheaper (3) choice.

## Decisions B1 to B5 (B6 and B7 follow the disk-layout section)

### B1. The first code: where the first instruction comes from

**The need.** At power-up something must already hold code or the machine cannot start. The choice fixes the reset state, what the controller chip must contain, and what recovery looks like.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **A boot ROM in the controller chip that loads block 0 of the boot device into RAM and starts the first core at it** (the PDP-11 and VAX way; the s390 IPL and the Alpha console do the same in hardware or firmware) | tiny; one failure case; recovery by the console monitor; the first stage is the same on every board | the ROM must contain a driver for each boot device it supports (disk, SD card, flash, serial); one fixed first-block format to define |
| 2 | **A reset vector in flash: the core fetches its first instruction from a fixed address in a flash or ROM that holds a full firmware** (the x86 and ARM way) | flexible; the firmware can be updated | firmware to write, store and update; more failure modes |
| 3 | **UEFI or a similar firmware standard** | existing loaders work | everything in the previous section |
| 4 | **The platform preloads RAM and starts the core** (the way the QEMU `-kernel` option, a JTAG loader and an FPGA debug probe work) | the simplest for development | not a boot mechanism for a real machine |
| 5 | **A serial-line bootstrap only** (the controller waits for a program to be sent over the UART, like a ROM monitor's load command) | the smallest; no disk drivers in ROM | slow; useful as the recovery path but not as the way to start every time |

**What other systems do and what the PDP-11 and VAX did** are in the sections above: option 1 is theirs, option 2 is the x86 and ARM way, option 4 is the emulator way.

**Settled by the author (errata 49):** drivers are trivially small, because devices are eight memory-mapped registers, so the cost of option 1 (the second stage carries its own drivers) is small and accepted.

**Recommendation.** Option 1 as the normal path, with option 5 as the fallback built into the same ROM (the monitor of the Recovery section). Under the principles: option 1 is the smallest first stage (1), has one failure case (2) and the ROM is a few hundred bytes of fixed code per boot device (3). Cost to build: the first-block format, a small ROM program, and for the FPGA a boot loader in block RAM that runs before anything else.

### B2. Starting the other cores

**The need.** The secondary cores must go from reset to running kernel code, each knowing its own identity and stack.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **Cores are held in reset by the controller; a write to a per-core "start" register in the controller gives an entry address and an argument and releases that core into kernel mode at the entry point, priority 7, with the core number in `r0` and the argument in `r1`** | no trampoline, no firmware call, no spin loop; the whole protocol is one register write; nothing to recover from but a stuck core, which a core-reset register handles | a small register block in the controller; the convention on `r0` and `r1` to write down |
| 2 | **INIT and START-UP signals through the interrupt controller** (the x86 way) | works with the interrupt controller already planned (R1, R2) | the start-up vector convention; the core must start from a known state |
| 3 | **A firmware call (PSCI or SBI style)** | one call interface; works across vendors | needs resident firmware (decision P7 recommends none) |
| 4 | **Spin table: cores park in `WFE` on a mailbox in memory; the boot core writes the entry address and `SEV`s** (the ARM board way) | no controller logic | busy waiting at boot; trust in the mailbox; depends on the `WFE` rule (decision P1) |
| 5 | **All cores start at the reset vector and sort themselves out by core number** (a simple scheme some microcontrollers use) | no per-core start logic | every core runs the first-stage code; races over the boot device; only the lowest-numbered core must proceed and the rest must wait |

**What other systems do:** option 2 is x86, option 3 is arm64 PSCI and RISC-V SBI, option 4 is the ARM spin table and the RISC-V fallback (the table above). **What the PDP-11 and VAX did:** the PDP-11 had one processor; on VAX multiprocessors the console processor started the others (not confirmed in the sources read), which is option 1 with the console in the controller's role.

**Recommendation.** Option 1. The pdp64 has no real-mode ladder, so a core can start in its normal mode at any address: the x86 trampoline problem (1,258 lines of real-mode code plus the start-up code) does not exist. A register write is the smallest protocol that exists (principles 1 and 3); a stuck core is recovered by a core-reset register (principle 2). It also covers decision R2 (inter-processor interrupts and starting the other cores). Cost to build: the register block in the controller and a QEMU model.

### B3. The hand-off: what the kernel is told about the machine

**The need.** The kernel must learn the memory size and layout, the devices and where their registers and interrupts are, the number of cores and where it was loaded from.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **A flat device tree blob (FDT) in memory, generated per platform and handed over by address in `r1`** (what arm64 and riscv64 OpenBSD already parse) | the kernel already has a parser in other ports, tools to build one exist, a standard | a parser in every program that reads it (small, a few thousand lines in libfdt) *(not confirmed in the sources read)*; a text source format and a compiler for it |
| 2 | **A fixed-layout boot-information block in the style of the VAX RPB and Alpha HWRPB**, with its layout defined once in a grammar so the headers are generated: memory ranges, boot device, console device, core count, a table of devices (kind, base address, interrupt level and vector), kernel command line, ABI version, checksum | the simplest to read (a struct); no parser; one place defines it | a project-specific format; no existing tools; the kernel code to read it is new |
| 3 | **ACPI tables** | what x86 and arm64 servers use | large, and needs an interpreter for its byte code in the kernel; not for a small machine |
| 4 | **Self-describing devices only**: each device has an identification register (decision R5) and the kernel scans a fixed address range to find them | no table at all; the PDP-11 `config` approach made automatic | memory size and core count are still needed from somewhere; interrupt wiring is not discoverable |
| 5 | **Probe by touching addresses and catching the bus error** (V7's approach) | nothing to build | unreliable for anything but presence; slow |

**What other systems do:** x86 uses ACPI, arm64 and riscv64 a device tree, PowerPC and SPARC an Open Firmware tree, VAX the RPB, Alpha the HWRPB (table above). **What the PDP-11 and VAX did:** the PDP-11 configured the kernel at build time for the machine and probed device addresses; the VAX passed the RPB.

**Updated after errata 49 (the bus is a device that enumerates what is on it):** option 4 now becomes the natural base: the hand-off need only name memory ranges, the core count, the address of the bus controller and the slots of the boot device and console, and the kernel enumerates the devices (`pdp64-q64-bus.md` section 13). The recommendation below stands for the part of the hand-off that remains.

**Recommendation.** Option 1 or option 2, and I would pick **option 2 for the first system and keep the door open for option 1**. Option 2 is the smallest to read and costs the least recovery code (a struct with a checksum has two failure cases, bad checksum and unknown version); principle 1 and 2 favour it. Option 1 has one strong argument: OpenBSD's arm64 and riscv64 ports already have the code to read a device tree and to attach drivers from it, so a device tree could save kernel code when the port reuses their drivers (not confirmed in the sources read: the drivers directory is not in the sparse tree). If the port ends up reusing many of OpenBSD's existing drivers, switch to option 1; if the devices are the pdp64's own eight-register devices (decision R5), option 2 is simpler. Cost to build: the layout in a grammar (the bus document already says layouts should be generated), a generated header, one reader in the loader and the kernel.

### B4. Device initialisation: the protocol behind the bus

**The need.** Each device must be reset to a known state, configured, and sometimes given firmware, before a driver can use it. The author's proposal: most of the initialisation happens behind the bus; the processor writes a register that says "initialise yourself", and possibly another register carries values or a binary firmware blob for the device to load.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **A reset bit and a status register only: the device initialises itself from built-in logic or ROM when the bit is written, and reports ready in the status register** (the Unibus control-and-status-register "INIT" bit) | the simplest; one failure case (timeout); the device is self-contained | every device must carry its own firmware |
| 2 | **Option 1 plus a firmware window: an optional pair of registers (address, length) and a "go" bit: the processor puts a firmware image in memory, tells the device where it is, and the device reads it by DMA and loads itself; the image starts with a small header (device identifier, version, length, checksum) that the device checks** (the author's proposal) | devices can be cheap (no flash); firmware updates are a file replacement; one convention for all devices; the same mechanism works for FPGA-based devices | a header format to define; the device must reject a wrong image safely; the kernel needs the image (from the boot file system) before the device is usable, so **boot-critical devices cannot depend on it** |
| 3 | **Firmware from the device's own flash** | no host involvement | per-device flash and update tooling; unrecoverable if the flash is corrupted |
| 4 | **A command queue interface: the host sends an "download firmware" command through the device's normal queue** (the NVMe way) | uses the device's ordinary interface | needs a working command queue before initialisation: the circular problem; much more complex |
| 5 | **Programmed I/O: the driver streams the blob through a data register word by word** | no DMA needed for initialisation | slow; more driver code |

**What other systems do.** PCI Express devices are initialised through their configuration space and per-device driver code; many devices (network, wireless, GPU, storage) need firmware blobs that the driver loads at attach time (Linux's `request_firmware`, OpenBSD's `firmload(9)`; the firmware files are shipped in a separate package, `fw_update`) *(not confirmed in the sources read)*. **The PDP-11 and VAX:** Unibus controllers had a control and status register with an initialise bit and nothing more; the VAX console and some adapters (the 780's microcode was loaded from the console floppy) loaded microcode from storage **(not confirmed in the sources read)**.

**Recommendation.** Option 2 with one rule: **boot-critical devices (the boot disk or flash controller, the console, the interrupt controller) must work from option 1 alone**, with their minimal firmware built in, and may use the blob window only to load an improved image after boot. That keeps the boot path free of any chicken-and-egg problem (a disk needs firmware that is on the disk) and gives every other device the convenience of the blob. The `init` bit and the status register become part of the uniform device layout of decision R5 (an ID and version register first; then control with an `INIT` bit; status with `READY` and `ERROR`; the firmware-address, firmware-length and `FWGO` registers optional). Cost to build: the layout, the header format, a QEMU model, a driver helper.

### B5. Standards: UEFI, ACPI, device trees

**The need.** Whether the pdp64 adopts any external firmware or description standard.

**Options.**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **None: the project's own block-0 boot, its own boot-information block and its own device layout** | the least code; everything under the project's control; fits the principles | the existing generic loaders cannot be used; the project writes its own second stage |
| 2 | **Device tree only** (no UEFI) | existing parsers and tools; the OpenBSD arm64 and riscv64 ports use it | a compiler for the tree source; a second description format beside the project's own |
| 3 | **UEFI with ACPI** | generic loaders; the PC-style ecosystem | the cost list in the UEFI section |
| 4 | **UEFI with a device tree** (what OpenBSD does on arm64 and riscv64) | the arm64 and riscv64 approach, mature | both costs |
| 5 | **Start with option 1 and add a UEFI shim later if asked** | no cost now; the door stays open | a later shim is a real project |

**Recommendation.** Option 1, with the remark of option 5: keep the hand-off block simple enough that someone who wants a UEFI shim can write one. UEFI is not worth it for the pdp64 itself (see the UEFI section for the reasons).

## Disk layout and partitions

**The need.** The boot code and the kernel must know where on a disk the boot program, the root file system and the swap space are. That is the job of a **partition scheme** (a table that divides a disk into named regions) and of the program that reads it.

**How Unix did it, from the sources on disk.**

* **V7 (1979):** no table on the disk at all. The partitions are an array compiled into each disk driver: `hp_sizes[8]` in `usr/sys/dev/hp.c` holds, for each of eight partitions, a size in blocks and a starting cylinder, with a comment per entry ("cyl 44 thru 429", "cyl 44 thru 410 (rp04, rp05)") *(read in source)*. To change the layout you edit the driver and recompile the kernel, exactly as the author remembered.
* **4.3BSD (1986):** the same arrangement (the 4.3BSD tree has no disk-label header; read in source).
* **4.3BSD-Tahoe (1988):** the **disk label** arrives. `sys/h/disklabel.h` (version 7.10, 27 June 1988, copyright 1987 and 1988) says each disk "has a label which includes information about the hardware disk geometry, filesystem partitions, and drive specific information. The label is in block 0 or 1, possibly offset from the beginning to leave room for a bootstrap" *(read in source)*. It has a magic number, `0x82564557`, and up to eight partitions. The idea of a label written on the disk itself already existed elsewhere (Sun's disks carried one) *(not confirmed in the sources read)*; the BSD version is the one OpenBSD inherited.
* **OpenBSD today:** the same label, with the **same magic number** `0x82564557`, extended to 16 partitions per disk (`MAXPARTITIONS16`) and to sector counts beyond 32 bits (fields such as `d_secperunith` hold the high part) *(read in source: `sys/sys/disklabel.h`)*. So OpenBSD's own scheme is a direct descendant of the 1988 BSD label, not of V7's compiled-in table.

**Does it vary across architectures?** The *label* barely does; the *outer wrapper* does.

* **Where the BSD label sits.** In the OpenBSD tree, seven architecture headers put it at sector 1 (offset 0): amd64, i386, arm, arm64, riscv64, hppa and powerpc64; Alpha and SPARC64 put it at sector 0 (Alpha at offset 64); armv7 has a header too; the other architectures in the tree (m88k, mips64, powerpc) have no header of their own *(measured and read in `sys/arch/*/include/disklabel.h`)*. Sector 1 is chosen so that sector 0 stays free for a boot block, which is what the 1988 header's comment says.
* **What surrounds it.** The PC uses the **MBR** (a table of four partitions in sector 0, with 446 bytes of boot code, from the 1980s) or **GPT**; Sun used its own label in sector 0, old Macs an Apple partition map, the Amiga its rigid-disk block, IBM mainframes a volume table of contents, and Alpha's firmware reads a BSD label *(none of these confirmed in the sources read)*. A BSD system on a PC puts its label **inside** one MBR or GPT partition; on a SPARC or Alpha it uses the whole disk. The OpenBSD kernel reads GPT and MBR (`spoofgpt` and the `gpt_*` routines in `kern/subr_disk.c`, with the GPT type identifiers for an EFI system partition and an OpenBSD partition in `sys/disklabel.h`) and builds the BSD view from them *(read in source)*.

**How UEFI and GPT fit.** **GPT** (GUID partition table) is part of the UEFI specification: a header in the second block, an array of partition entries (each with a type GUID, start, end, name), a checksum, and a backup copy at the end of the disk, preceded by a "protective MBR" in block 0 so that old tools see the disk as used *(not confirmed in the sources read)*. UEFI firmware itself understands GPT and FAT: it finds the **EFI system partition** (a FAT file system with a known type GUID), runs a loader file from it, and that loader (OpenBSD's `efiboot`) then reads the BSD label inside the OpenBSD partition to find the root file system. So under UEFI the firmware does the partition parsing and the boot sector no longer exists; under a BIOS the boot sector code in the MBR does it, in 446 bytes, which is why PC boot sectors are so cramped.

**Is it a worry for the BIOS or the boot sector?** Only minimally, if the design is right. The first stage needs to find *one thing*, the second-stage loader, and nothing else. If block 0 carries a short **block list** (start block, count, load address), it never parses a partition table (decision B1 and the proposal below). The second stage, written in C, is the program that reads the label, finds the root partition and the kernel file. That is how V7's second stage and OpenBSD's `biosboot` and `boot` split the work.

> **DECIDED (errata 50): option 2, GPT with a protective MBR, and a BSD label inside a partition of the OS's own type.** The author: "we will have the gpt wrapper for the disk label." My recommendation below was option 1 (the label alone); the author chose the wrapper, so the disk is recognised by other systems and tools. The consequence for block 0 is worked through in decision B8 below.

**Decision B6: the partition scheme**

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **The BSD disk label only, at block 1 of the disk (block 0 is the boot block); no outer table** (the arrangement of the 1988 header and of OpenBSD on non-PC machines) | the OpenBSD kernel and tools already support it (`disklabel`, `newfs`, `installboot`); 16 partitions and 64-bit sizes; the port adds one small header (`LABELSECTOR` 1, `LABELOFFSET` 0); nothing for the ROM to parse | other operating systems and partitioning tools do not recognise the disk, which matters only for dual-boot or moving disks between machines |
| 2 | **GPT with a protective MBR, and an OpenBSD partition holding the BSD label** (what OpenBSD does on UEFI systems) | other tools recognise it; large disks; checksummed and replicated | block 0 becomes the protective MBR (our first-stage code must live in its 446 boot-code bytes); a GPT parser in the second stage and the kernel (OpenBSD has one); more failure cases (bad checksum, backup mismatch) |
| 3 | **MBR as the outer table** | tiny and universal | four partitions, 32-bit sizes (about 2 TB with 512-byte sectors), a 1980s format |
| 4 | **A new minimal partition table defined in the project's grammar** (a magic number, 16 entries of type, 64-bit start and size, a checksum) | exactly what the project needs; generated headers | new tools and new kernel code, with no existing support |
| 5 | **A table compiled into the driver, V7 style** | no parsing code at all | repartitioning means recompiling; unusable for any normal installation |

**What current systems do:** PCs use MBR or GPT; UEFI systems require GPT and FAT on the system partition; arm64 and RISC-V servers use GPT with UEFI; the BSDs wrap their label inside the platform's partition; Linux has no scheme of its own and reads whichever the platform uses *(not confirmed in the sources read)*. **What the PDP-11 and VAX did:** V7's compiled-in table on the PDP-11; 4.3BSD's compiled-in table on the VAX; the label from 1988 on.

**Recommendation (superseded by the author's choice of option 2, errata 50).** **Option 1**, with option 2 as an optional wrapper to be added only if someone wants the disk to be recognised by other systems. Under the principles: it reuses code OpenBSD already has (1: less new code), the kernel and the tools already handle it, so there is no new partition-table code to get wrong (2: less recovery code), and the ROM and block 0 need no parser (3: fewer gates). It also keeps block 0 entirely ours, which option 2 would not (the protective MBR). Cost to build: `sys/arch/pdp64/include/disklabel.h` (about a dozen lines), an `installboot` that writes block 0 and the block list, and the second stage reading the label.

**Offsets inside the partition: follow the majority (errata 51).** The author's rule is to do what most systems do. In OpenBSD's tree, of the nine architecture headers, **seven put the label at sector 1 with offset 0**; Alpha (sector 0, offset 64) and SPARC64 (sector 0, offset 128) are the minority (measured: `LABELSECTOR` and `LABELOFFSET` in `sys/arch/*/include/disklabel.h`). The boot area is the BSD tradition of **8192 bytes (`BBSIZE`) at the start of the partition**, with the file system's superblock after it at offset 8192 (`SBOFF` = `BBOFF` + `BBSIZE`), and the label header says the boot area holds "primary (block 0) and secondary (block 1-15) bootstraps" (read in source: `ufs/ffs/fs.h` and `sys/disklabel.h` of OpenBSD 4.6; `d_bbsize` in the label records the boot-area size). So, **inside the pdp64's BSD partition:**

| Sector (512 bytes) | Contents |
|---|---|
| 0 | the partition's own boot block (the primary bootstrap of the BSD convention) |
| 1 | the disk label, at offset 0 |
| 2 to 15 | the rest of the 8 KB boot area (room for a secondary bootstrap, 7 KB) |
| 16 on | the file system, starting with its superblock at offset 8192 |

The disk-level boot block is separate: with the GPT (errata 50) the first stage is in the protective MBR's 446 bytes at disk LBA 0, and the BSD partition's own boot block is the BSD tradition's second place a bootstrap can sit. Decision B8 chooses how the first stage finds the second stage; note that OpenBSD's own `installboot` writes the position of the second-stage *file* into the first stage's block list *(not confirmed in the sources read)*, so a **dedicated boot partition is optional**: the block list in the protective MBR can point straight at the blocks of the second-stage file in the root file system, or at the partition's 8 KB boot area.

**Decision B7: the boot software is open source (the author's requirement).** The author has said that the bootstrap, loader and the "BIOS" are open source and part of the specification: the boot ROM and its monitor, the first-block program, the second-stage loader and any boot tools (installer, `installboot`) are published with the project and are reviewed and changed like the rest. This is recorded as errata 47. The licence is the BSD licence (errata 48, "bsd license for everything"). The consequence for the design is good: no closed firmware blob sits at the bottom of the trust chain, and every stage can be rebuilt from source by the project's own compiler.

**Decision B8: how the first stage finds the second stage on a GPT disk**

**The need.** With a GPT (errata 50), block 0 is the **protective MBR**: a normal MBR sector whose partition table holds one entry of type `0xEE` covering the disk, so that old tools see the disk as used. It still has **446 bytes of boot code** before the table and the `0x55AA` signature (the same layout the PC has used since the 1980s, *not confirmed in the sources read*). The first stage can live in those 446 bytes. The question is how it finds the second stage, and whether the ROM itself understands the GPT.

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **A block list in the protective MBR's boot-code area (start block, count, load address), written by `installboot`; the second stage sits in a small dedicated boot partition (or a fixed range of blocks), and neither the ROM nor the first stage parses the GPT** | the ROM stays the simplest it can be (read block 0, jump); the first stage is a few dozen bytes; a damaged GPT does not stop booting, which is a recovery path | `installboot` must rewrite the list when the second stage moves; the list can go stale if someone repartitions without running it |
| 2 | **The ROM parses the GPT: it finds the first partition whose type is a "pdp64 boot" identifier and loads its first blocks** | no list to maintain; the boot partition is found by type, like a UEFI system finds its system partition | a GPT parser in the ROM (header check, CRC32, entry scan); a damaged GPT stops booting |
| 3 | **The second stage in a fixed gap after the GPT structures and before the first partition** (the way some PC boot loaders embed their code after the MBR) | no partition and no list | the gap has no owner and any partitioning tool can overwrite it |
| 4 | **A boot partition with a FAT file system holding the loader, as a UEFI system partition does** | the UEFI-style layout; tools understand it | a FAT driver in the ROM or first stage, far more code than the rest |
| 5 | **The partition marked bootable by a GPT attribute bit is loaded** | uses the table's own flag | the same parser as option 2 and a flag convention to maintain |

**What current systems do** *(not confirmed in the sources read)*: BIOS PCs with GPT use the protective MBR's boot code to find a "BIOS boot partition" (option 1 and 2 combined); UEFI systems parse the GPT in firmware and read a FAT system partition (option 4); OpenBSD on UEFI machines does exactly that, with `efiboot` on the FAT partition and the BSD label inside the OpenBSD partition (read in source: the GPT type identifiers for both are in `sys/sys/disklabel.h`). **What the PDP-11 and VAX did:** block 0 held a boot block, with no partition table to parse.

**Recommendation.** **Option 1**: the first stage in the protective MBR's 446 bytes carries a block list to the second stage in a small boot partition, and nothing before the second stage parses the GPT. That keeps the ROM and the first stage minimal (principles 1 and 3), and the most important recovery property (principle 2): **a damaged or missing GPT does not prevent the machine from reaching the second stage, which can repair it**. The second stage, written in C, then reads the GPT, validates its checksums, finds the OpenBSD-type partition and reads the BSD label inside it. Cost to build: `installboot` writes the block list into the protective MBR and the second stage into the boot partition; the second stage includes a GPT reader (OpenBSD's kernel already has one: `spoofgpt` and the `gpt_*` routines in `kern/subr_disk.c`, so the port reuses it).

## A concrete proposal: the pdp64 boot sequence

This is one coherent boot built from the recommendations B1 to B5. It is a proposal, not a decision.

1. **Reset.** The controller chip brings up clocks and (on real silicon or via the vendor block on the FPGA) the memory, with core 0 held in reset and all other cores held in reset.
2. **The controller's boot ROM** looks for a boot device in a fixed order (disk or flash, then SD card, then the serial line). It reads **block 0 (512 bytes) of the first device that answers** (on a GPT disk, the protective MBR) into physical address 0x1000 *(an address to be chosen)*, checks the `0x55AA` signature in its last two bytes, and starts core 0 (it does not parse the partition table).
3. **The reset state of core 0** is fixed and documented: kernel mode, priority 7, `MMUCTL` = 0 (every address physical), `UA` = 0, `VBR` = 0, `r0` = the boot device number, `r1` = the address of the **boot-information block** (B3, option 2), `r14` = the top of the first 64 KB of RAM, all other registers zero; the program counter is the address block 0 was loaded to. A reset vector in the vector table (vector 0, at `VBR` + 0) is then only needed for a second reset after the machine is running.
4. **Block 0** is the primary boot program, in the 446 boot-code bytes of the protective MBR (errata 50), a few hundred bytes of assembler at most (the V7 `hpuboot.s` is about 250 lines; OpenBSD's `biosboot.S` is the same idea). Its job is only to read the next blocks from a list it carries (start block, count, load address) and jump to them. The list is how it avoids understanding a file system or the GPT (decision B8). The second stage lives in a small boot partition and `installboot` writes the list.
5. **The second-stage loader** (written in C and compiled with the project's compiler; the analogue of OpenBSD's `/boot`, 189 lines for the top level plus a library of file-system and device code) understands the root file system, finds `/bsd` (an ELF file, the toolchain's own object format), loads it, and jumps to its entry point with `r0` and `r1` as before and a command line in the boot-information block.
6. **The kernel** reads the boot-information block, sets up its page tables, turns on translation (`MMUCTL`, then `ISYNC`), initialises the interrupt controller and the console, and **starts the other cores** by writing each core's start register (B2) with the address of its per-core entry code and a pointer to its per-core structure.
7. **Each device** is initialised by the driver writing the `INIT` bit and waiting for `READY` (B4); a device that wants firmware gets it through the blob window after the root file system is up.

## Recovery: when boot fails

Under your principle of less recovery code the most valuable single feature is a way in when nothing works. The PDP-11's console `ODT` and the VAX console processor are the model. **A boot monitor in the controller's ROM,** reached on the serial console when no boot device answers or when a key is held at power-up, with a handful of commands: examine and deposit memory and registers, load a program over the serial line (the option 5 of B1), start at an address, start from a named device, reset a core, and reset the machine. A few hundred bytes of code; it needs a working serial port and nothing else. It is also what you use to bring up a new board before any boot device works. The bus document already reserves a bus-controller reset register; the monitor's reset command writes it. A hardware watchdog (decision P7's recommendation) restarts the machine if the kernel hangs.

## What to verify next

These statements are not confirmed against their specifications; each is a short job with the browser or the manuals, and none changes the recommendation unless it turns out wrong:

* The x86 reset vector location and the BIOS boot-sector convention; the INIT and START-UP sequence's start-address rules.
* PSCI `CPU_ON`, the SBI hart-state-management extension, and the ARM spin-table convention as specified.
* What UEFI requires of a loader and of the firmware, and the real size of EDK II.
* The Alpha SRM boot block and HWRPB; the s390 IPL record format; the VAX console boot protocol, the 11/780 microcode loading, and how multiprocessor VAXes started their other processors; the PDP-11 power-up behaviour and the M9312 boot ROMs.
* The OpenBSD device-tree and firmware-loading code (the sparse tree has no `sys/dev`).
* The size of an FDT parser (libfdt) and whether the OpenBSD arm64 and riscv64 drivers could be reused without the device tree.
