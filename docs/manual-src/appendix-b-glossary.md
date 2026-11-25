# Appendix {{a:id03003|n}}. Glossary

[← manual index](00-index.md)

**Terms the manual uses, collected in one place.** Each entry gives the plain meaning and, in brackets, the chapter or section where the manual deals with it. Terms for the instruction groups (the "escape" opcodes) are listed by name and opcode; the full encodings are in the instruction-set text [`pdp64-isa.md`](../pdp64-isa.md).

## {{#architecture-and-encoding}} Architecture and encoding

| Term | Meaning |
|---|---|
| **pdp64** | the 64-bit extension of the PDP-11 this manual describes, as the PDP-11 extended the PDP-10's ideas down and the VAX extended the PDP-11 up (chapter {{c:id01001|n}}) |
| **earlier iteration** | pdp64/r20 (the original encoding) or pdp64/16 (a 16-register prefix code): a design built and measured before the pdp64 was chosen, superseded by it, and no longer a CPU ({{r:how-the-encoding-was-chosen}}) |
| **parcel** | a 16-bit unit of instruction encoding; an instruction is one to three parcels, two to six bytes, or five parcels for `MOVQ` of a 64-bit constant ({{r:instruction-format}}) |
| **leaf** | a group of mnemonics with one form, selected by a prefix of the first parcel; a sub-opcode picks the mnemonic ({{r:how-the-opcode-space-is-divided}}) |
| **prefix** | the top 3 to 16 bits of the first parcel; the prefixes form a prefix code (no prefix begins another), so the first parcel matches at most one leaf and fixes the length of the instruction ({{r:how-the-opcode-space-is-divided}}) |
| **form** | the list of operand shapes of a leaf: how each operand is written in assembly and how many bits each part has ({{r:how-the-opcode-space-is-divided}}) |
| **sub-opcode** | the field after the prefix that selects one mnemonic of the leaf ({{r:how-the-opcode-space-is-divided}}) |
| **hot register** | one of the eight (3-bit field) or sixteen (4-bit field) most-used registers, which a register field of a one-parcel form names by an index into a table; the tables are part of the ABI ({{r:instruction-format}}, appendix {{a:id03004|n}}) |
| **fused instruction** | `MOVCALL`, `POPRET`, `POPMRET` or `MOV2`: one instruction for a pair that the compiler finds adjacent ({{r:branches-and-control-flow}}) |
| **relaxation** | the linker's choice, after the sections are laid out, of the shortest form that reaches for a call or an address; on by default ({{r:addressing-modes}}) |
| **`CBCC`** | compare-immediate-and-branch on condition, the one fused compare and branch ({{r:branches-and-control-flow}}) |
| **`RORI32`** | rotate right by an immediate, 32-bit, sign-extended result |
| **`SOB`** | subtract one and branch, either direction ({{r:branches-and-control-flow}}) |
| **`MCPY`, `MMOV`, `MSET`, `MCMP`, `MSCN`, `MSCNN`** | the block operations: copy, move (overlap-safe), fill, compare, scan for a byte, scan for the first byte not equal; progress is held in registers so a fault restarts for free ({{r:stack-and-block-operations}}) |
| **`MVAL`** | block scan of valid UTF-8, one of the string instructions of the same family ({{r:bits-bytes-and-text}}) |
| **`PUSHM`, `POPM`** | push and pop a register set named by a mask; the useful half of the VAX's `CALLS` without the frame ({{r:stack-and-block-operations}}) |
| **`JMPI`, `CALLI`** | jump and call through a memory word; the only deferred forms, used for PLT stubs and imports ({{r:branches-and-control-flow}}, {{r:position-independent-code}}) |
| **`JTAG`, `TAGOP`** | multiway dispatch on a pointer's low tag bits, and the tag-branch group ({{r:branches-and-control-flow}}) |
| **`LPAD`** | marks a legal target of an indirect jump or call; optional in ABI version 1 (appendix {{r:page-bit-that-enforces-landing-pads}}) |
| **`CLMUL`** | carry-less multiply, the primitive under every CRC and Galois-field operation ({{r:bits-bytes-and-text}}) |
| **`XNORPOP`, `POPCNT`** | bit-population instructions used by binary operations and bitsets ({{r:inference-array-languages-and-the-bit}}) |
| **`SET cc, rd`** | set a register to 0 or 1 from a condition ({{r:integer-arithmetic}}) |
| **`DP`** | the direct pointer: in user mode it is the thread pointer, in kernel mode the per-CPU pointer; a descendant of the 6502's zero page ({{r:state-registers-and-flags}}, {{r:position-independent-code}}) |
| **`PSW`** | the processor status word: flags, mode, priority and the guard bit ({{r:modes-and-the-status-word}}) |
| **`N Z V C`** | the four condition flags: negative, zero, overflow, carry ({{r:state-registers-and-flags}}) |
| **canonical address** | a 64-bit address whose bits above the top bit of the virtual address (bit 38, 47 or 56 with three, four or five levels) equal that bit; any other value faults, so software cannot hide tags in the high bits ({{r:from-segments-to-pages-virtual-memory}}) |
| **`lowtag`** | a type tag stored in the low bits of a pointer, free because objects are quad-aligned (instruction-set text, section {{r:modes-and-the-status-word}}; not otherwise used in this manual) |
| **SWAR** | SIMD within a register: using one wide scalar register as several narrow lanes through masking and carry-aware arithmetic (instruction-set text, glossary; the manual's bit and byte instructions of {{r:bits-bytes-and-text}} make it effective) |
| **`FPSR`** | the sticky floating-point exception flag register, read and written by `FSFLAGS` ({{r:floating-point}}) |

## {{#memory-protection-and-the-kernel}} Memory, protection and the kernel

| Term | Meaning |
|---|---|
| **`MT`** | memory type, a two-bit page attribute: normal cached, normal uncached, device strongly ordered ({{r:address-space}}, {{r:page-table-entry}}) |
| **`ASID`** | address space identifier: tags translation-buffer entries so a context switch flushes nothing ({{r:accessed-dirty-tlb-and-asids}}) |
| **`G` bit** | global: a translation-buffer entry that ignores the `ASID` ({{r:accessed-dirty-tlb-and-asids}}) |
| **TLB** | translation lookaside buffer: the cache of page-table entries; `TLBI` invalidates one, `TLBIA` all, `TLBSYNC` waits for other cores ({{r:translation-and-instruction-cache-coherence}}) |
| **`DMW`** | direct mapping window: a region translated by a fixed offset with no page table; stored without effect, the format is open ({{r:splitting-the-space-and-the-layout}}) |
| **`MMUCTL`** | the register that enables translation and sets the table base ({{r:system-registers-mfsr-and-mtsr}}, {{r:accessed-dirty-tlb-and-asids}}) |
| **virtual address, physical address** | the number a program uses, and the number the memory answers to; the page tables translate one into the other ({{r:from-segments-to-pages-virtual-memory}}) |
| **page, frame, page table** | a 4 KB piece of virtual space, a 4 KB piece of physical memory, and the tree of tables of 512 entries that says which frame holds which page ({{r:from-segments-to-pages-virtual-memory}}) |
| **PTE** | page-table entry: one 64-bit word with the valid, permission, accessed, dirty, global and memory-type bits and the physical page number ({{r:page-table-entry}}) |
| **leaf, pointer** | the two kinds of page-table entry: one that maps a page (`R`, `W` or `X` set) and one that points to the next table ({{r:page-table-entry}}) |
| **`KT11`, `PAR`, `PDR`** | the PDP-11's memory-management unit, with eight pairs of page address and page descriptor registers for each mode ({{r:kernel-what-you-already-know}}, {{r:from-segments-to-pages-virtual-memory}}) |
| **`EPC`, `EPSW`, `EVA`, `ECAUSE`** | the registers that exception entry writes: where to resume, the old status word, the faulting address, the vector number ({{r:exceptions-interrupts-and-traps}}) |
| **`VBR`** | the vector base register: where the table of 512 eight-byte entries begins ({{r:exceptions-interrupts-and-traps}}) |
| **`ISYNC`** | makes earlier writes to system registers take effect: wait for earlier instructions, discard later ones, fetch again ({{r:system-registers-mfsr-and-mtsr}}) |
| **`MFSR`, `MTSR`** | move from and to a system register, by number ({{r:system-registers-mfsr-and-mtsr}}) |
| **software-managed `A`, `D`** | accessed and dirty bits set by the kernel's page-fault handler, never by the walker ({{r:accessed-dirty-tlb-and-asids}}) |
| **shootdown** | removing a stale translation from the buffers of other cores; on the pdp64 `TLBI` broadcasts and `TLBSYNC` waits ({{r:accessed-dirty-tlb-and-asids}}) |
| **walker** | the hardware that reads page-table entries on a translation-buffer miss ({{r:from-segments-to-pages-virtual-memory}}) |
| **`STUA` / `CLUA`** | set and clear the user-access guard bit, which lets kernel code touch user memory only inside the copy routines ({{r:user-memory-guard-and-system-calls}}) |
| **`PROBER` / `PROBEW`** | test whether an address is readable or writable in a given mode without faulting ({{r:user-memory-guard-and-system-calls}}, {{r:kernel-system-instructions-exceptions}}) |
| **PIE** | position-independent executable: loadable at any address; costs nothing here ({{r:position-independent-code}}) |
| **GOT, PLT** | global offset table and procedure linkage table: the indirection that lets position-independent code reach imported symbols ({{r:position-independent-code}}) |
| **ABI** | application binary interface: calling convention, register use, data layout; version 1 is given in appendix {{a:id03004|n}} |
| **trap, exception, interrupt** | a deliberate entry (`TRAP #n`), a fault raised by an instruction, and a signal from a device; all enter through the vector table ({{r:exceptions-interrupts-and-traps}}) |
| **precise fault** | a fault after which every earlier instruction has completed and no later one has changed state ({{r:faults-and-restart-what-precise-means}}) |
| **`SPL`** | set the interrupt priority level ({{r:exceptions-interrupts-and-traps}}) |
| **`WFE`, `SEV`** | wait for an event and send an event: the idle and wake-up pair ({{r:waiting-signalling-and-interrupting-another}}) |
| **`FENCE`** | orders memory accesses; owed to devices and to other cores ({{r:what-the-processor-owes-the-bus}}, {{r:memory-ordering-from-sequential-consistency}}) |
| **`ATOM`, monitor** | the atomic operations, built on a reservation monitor as in AXI and ARM, not a locked bus cycle ({{r:atomic-operations}}) |
| **SMP** | symmetric multiprocessing: several identical cores sharing memory (chapter {{c:id01007|n}}) |
| **core class** | the read-only register of each core that gives its class and capacity, so that software can tell an in-order core from an out-of-order one ({{r:each-core-has-a-read}}) |
| **secure mode** | the mode of a core in which every timing channel is removed (every instruction and cache fetch takes a time independent of its data), with private cache lines and no periodic tick; on every core or on one secure core, by the rule of {{r:at-least-one-core-can-run-secure}} |
| **coherence, snooping MSI** | the protocol that keeps each core's cache consistent with the others; snooping means each cache watches the bus; MSI is its three states (modified, shared, invalid) ({{r:cache-coherence}}) |
| **sequential consistency** | the memory model in which all cores see all accesses in one order; the pdp64 declares it ({{r:memory-ordering-from-sequential-consistency}}) |
| **hypervisor** | a small kernel whose programs are whole operating systems; it runs at the hypervisor level, `H` = 1 ({{r:running-a-kernel-under-a-kernel}}, {{r:hypervisor-mode-is-one-state}}) |
| **guest, host** | a guest is an operating system that runs under a hypervisor as if it owned the machine; the host is the real machine ({{r:running-a-kernel-under-a-kernel}}) |
| **`H`** | the state bit, outside the status word, that says the hypervisor is running ({{r:hypervisor-mode-is-one-state}}) |
| **`HVE`** | the strap, fixed by the machine, that says it has a hypervisor mode; with it clear `H` is always 0 ({{r:hypervisor-mode-is-one-state}}) |
| **exit** | the event by which a guest stops and the hypervisor starts: a trapped instruction, a hypercall, an interrupt or a fault in stage 2; `HEXITR` says which ({{r:hexitr-says-why-the-guest}}) |
| **hypercall** | a `TRAP` number routed to the hypervisor by the trap-control register; the guest's system call to the hypervisor ({{r:halt-always-exits-exit-code}}) |
| **world switch** | the exit of one guest and the entry of the next, with the hypervisor saving and loading the guest's state between them ({{r:world-switch-an-exit-followed}}) |
| **`GENTER`** | `GENTER #mask` enters a guest from the hypervisor; the mask names the registers it keeps ({{r:genter-enters-a-guest-before}}, {{r:rti-mask-is-the-only}}) |
| **stage 1, stage 2** | the guest's own page tables, and the hypervisor's tables that turn a guest-physical address into a real one ({{r:translation-of-a-guest}}) |
| **guest tag** | the 16-bit number, allocated by the hardware, that marks the translation-buffer entries of one guest ({{r:gtbr-holds-the-whole}}) |
| **arena** | the one run of real pages in which the hypervisor keeps its stage-2 tables, so that the hardware knows when a table has changed ({{r:guest-never-sees-a-stale}}) |
| **epoch word** | the word in memory that a core adds one to when it has changed the arena, and that other cores read at entry to a guest ({{r:guest-never-sees-a-stale}}) |

## {{#bus-devices-and-boot}} The bus, devices and boot

| Term | Meaning |
|---|---|
| **Unibus, Q-bus** | the PDP-11's buses; PCI Express keeps their programming model, with devices in the address space ({{r:address-space}}) |
| **`DATIP` / `DATO`** | Unibus and Q-bus transaction types forming a locked read-modify-write ({{r:atomics-on-the-bus}}) |
| **window** | a region of the physical address space that a device's base-address register describes, a whole number of pages, found by enumeration ({{r:enumeration}}, {{r:what-a-driver-is}}) |
| **root complex** | the root of the PCI Express bus: it enumerates the functions, assigns their windows, and reports arrivals and departures ({{r:enumeration}}) |
| **bridge** | a function that is itself a bus: it presents the functions behind it, so arbitrary buses (PCI Express, USB) can be connected to the bus and enumerated to any depth ({{r:function-may-itself-be}}) |
| **MMIO** | memory-mapped input/output: device registers reached by ordinary loads and stores ({{r:what-a-driver-is}}) |
| **DMA** | direct memory access: a device moving data to or from memory without the processor ({{r:dma-and-the-buffer-memory}}) |
| **virtqueue, descriptor, available ring, used ring, doorbell** | the common device protocol: a table of 16-byte descriptors in memory, a ring in which the driver offers chains, a ring in which the device returns them, and a write that tells the device to look ({{r:interface-a-driver-programs}}) |
| **`device_status`** | the common-configuration field through which the driver and the device handshake; writing zero resets the device ({{r:interface-a-driver-programs}}, {{r:life-of-a-driver}}) |
| **virtio** | a standard family of devices of the same queue-and-descriptor shape, the pdp64's device interface ({{r:interface-a-driver-programs}}) |
| **virtio-blk** | the standard disk: a virtqueue of read, write and flush requests ({{r:storage-is-virtio-blk}}, {{r:disk-is-virtio-blk-my}}) |
| **NVMe, SCSI, ATA, SATA** | storage interfaces, each a command queue in memory and a doorbell, which is the same device pattern ({{r:interface-a-driver-programs}}); an NVMe device may be attached as any PCI Express device may, but the standard disk is virtio-blk |
| **driver, strategy routine, device switch, probe, attach** | the kernel code for one kind of device; the routine that queues one block transfer; the table of such routines indexed by the major device number (`bdevsw`, `cdevsw`); the routines that test whether a device is present and set it up ({{r:drivers-what-you-already-know}}, {{r:life-of-a-driver}}) |
| **`INIT` and `READY`** | the PDP-11 CSR's reset command and done bit; on the pdp64 the `device_status` handshake ({{r:life-of-a-driver}}) |
| **softc, `cfattach`** | OpenBSD's per-device structure and the table of a driver's `match` and `attach` functions ({{r:where-drivers-run}}) |
| **HDMI transmitter** | the chip that takes a pixel stream and does the link protocol; the pdp64 side is a pixel generator and registers ({{r:how-the-terminal-drives-hdmi}}) |
| **Blit** | Rob Pike's bit-mapped windowing terminal: an 8 MHz Motorola 68000 machine that received downloaded code, characters and editing messages from its host over a serial line and drew every pixel itself (its description as a precursor of the X11 protocol and of NeWS is stated by no source read ; the lineage the sources confirm runs from its `mux` to 8½ and `rio`); a framebuffer in the address space and a bit-block-transfer operation, done in software, that moves rectangles of pixels; with the C64, one of the two machines the pdp64's terminal is based on ({{r:teletype-one-line-at-a-time}}) |
| **blitter, raster operation** | a device that copies and combines rectangles of pixels; the raster operation says how source and destination combine ({{r:pdp64-terminal-blit-bitmap-and-c64-pokes}}) |
| **scanout, tearing, double buffering** | the display reading the picture out of memory row by row at a fixed rate; the seam where a picture changed during the reading shows old above and new below; drawing the next frame in a hidden second picture and swapping at the vertical blank ({{r:scanout-tearing-and-double-buffering}}) |
| **glyph map, glyph atlas** | a table of slots each holding the picture of one glyph, filled by a TrueType engine ({{r:form-of-the-terminal}}); the GPU form is one texture holding every glyph the screen uses ({{r:why-a-terminal-emulator-uses}}) |
| **rio, NeWS** | Plan 9's window system, in which each window is a private screen served as files, a descendant of the Blit's `mux` through 8½; and Sun's window server that programs downloaded from the host could extend ({{r:windows-from-the-blit-to-rio}}) |
| **mixer, ring buffer, underrun** | the program that sums the sample streams of several programs into one after converting their rates and formats; the circular buffer the sound device reads at the converter's clock; the reader reaching samples not yet written, audio's tear ({{r:audio-path-samples-mixers}}) |
| **GPU, shader** | a graphics processing unit, thousands of simple lanes; a shader is a small program it runs for every vertex or every pixel ({{r:gpu-pipelines-vertices-shaders}}) |
| **bootstrap, boot ROM, block 0** | the program that loads programs; the ROM in the controller chip that reads the first block of the boot device into memory and jumps to it; that first 512-byte block ({{r:boot-what-you-already-know}}, {{r:reset-state-and-the-first-block}}) |
| **BIOS** | the PC's firmware: bring-up and self-test, the first sector, a library of services called by software interrupt, and setup; the pdp64's "BIOS" is its boot ROM and monitor, with no resident services; open source ({{r:boot-what-came-between}}, {{r:what-takes-the-place-of-a-bios}}) |
| **first stage, second stage, `installboot`** | the program in block 0, which carries a list of where the next program lies; the C program that reads the label and the file system and loads `/bsd`; the tool that writes the first stage and its list ({{r:what-takes-the-place-of-a-bios}}, {{r:disk-a-gpt-around-the-bsd}}, {{r:second-stage-and-the-hand-off}}) |
| **partition, MBR, protective MBR** | a named region of a disk; the PC's first sector, with 446 bytes of boot code, a four-entry table and `0xAA55`; the MBR of a GPT disk, with one entry of type `0xEE` covering the disk ({{r:boot-what-came-between}}, {{r:disk-a-gpt-around-the-bsd}}) |
| **GPT, disk label** | the GUID partition table wrapped around the disk's own label so other systems see the disk is in use; the BSD label that names the root, swap and other partitions inside one partition ({{r:boot-what-came-between}}, {{r:disk-a-gpt-around-the-bsd}}) |
| **boot-information block** | the structure whose address the second stage passes in `r1`: memory ranges, cores, the root complex, the boot device, the console, the screen, the command line ({{r:second-stage-and-the-hand-off}}) |
| **UEFI, PE/COFF, shim** | the PC's later firmware standard, which runs a loader file of the PE/COFF format and offers it boot services; not used by the pdp64; a shim is the small program that would offer those services over virtio to an existing loader ({{r:boot-what-came-between}}, {{r:why-uefi-is-not-used}}) |
| **`ODT`, monitor** | the PDP-11's console debugger; the ROM's console program for examine, deposit, load and start ({{r:boot-what-you-already-know}}) |
| **INIT, START-UP, spin table, hart** | x86's signals that start another core; ARM's table the waiting cores poll; RISC-V's word for a core; the pdp64 writes a start register instead ({{r:starting-the-other-cores}}) |
| **APL, K** | array languages whose primitives work on whole arrays; one primitive maps to one descriptor ({{r:inference-array-languages-and-the-bit}}) |

## {{#process-and-sources}} Process and sources

| Term | Meaning |
|---|---|
| **fair corpus** | the 827 or 841 C files that every back end compiles, used for all size comparisons ({{r:does-the-instruction-set-matter}}) |
| **`pcc`** | the portable C compiler the project extends to emit pdp64 code ({{r:does-the-instruction-set-matter}}) |
| **`sim64`, QEMU** | the instruction-set simulator and the full-system emulator the tests run on ({{r:how-the-encoding-was-chosen}}, {{r:finish-line}}; not otherwise described in this manual) |
| **Impact** | the line ending each decision's commentary: effect on the kernel, on the compiler and on the hardware layout (index) |
