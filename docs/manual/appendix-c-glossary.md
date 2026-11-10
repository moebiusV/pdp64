# Appendix C. Glossary

[← manual index](00-index.md)

**Terms the manual uses, collected in one place.** Each entry gives the plain meaning and, in brackets, the chapter or section where the manual deals with it. Terms for the instruction groups (the "escape" opcodes) are listed by name and opcode; the full encodings are in the instruction-set text [`pdp64-isa.md`](../pdp64-isa.md).

## C.1 Architecture and encoding

| Term | Meaning |
|---|---|
| **pdp64** | the 64-bit extension of the PDP-11 this manual describes, as the PDP-11 extended the PDP-10's ideas down and the VAX extended the PDP-11 up (chapter 1) |
| **earlier iteration** | pdp64/r20 (the original encoding) or pdp64/16 (a 16-register prefix code): a design built and measured before the pdp64 was chosen, superseded by it, and no longer a CPU (1.8) |
| **parcel** | a 16-bit unit of instruction encoding; an instruction is one to three parcels, two to six bytes, or five parcels for `MOVQL` (9.4) |
| **leaf** | a group of mnemonics with one form, selected by a prefix of the first parcel; a sub-opcode picks the mnemonic (9.1) |
| **prefix** | the top 3 to 16 bits of the first parcel; the prefixes form a prefix code (no prefix begins another), so the first parcel matches at most one leaf and fixes the length of the instruction (9.1) |
| **form** | the list of operand shapes of a leaf: how each operand is written in assembly and how many bits each part has (9.1) |
| **sub-opcode** | the field after the prefix that selects one mnemonic of the leaf (9.1) |
| **hot register** | one of the eight (3-bit field) or sixteen (4-bit field) most-used registers, which a register field of a one-parcel form names by an index into a table; the tables are part of the ABI (9.4, appendix D) |
| **fused instruction** | `MOVCALL`, `POPRET`, `POPMRET` or `MOV2`: one instruction for a pair that the compiler finds adjacent (9.10) |
| **relaxation** | the linker's choice, after the sections are laid out, of the shortest form that reaches for a call or an address; on by default (9.5) |
| **`CBCC`** | compare-immediate-and-branch on condition, the one fused compare and branch (9.10) |
| **`RORI32`** | rotate right by an immediate, 32-bit, sign-extended result |
| **`SOB`** | subtract one and branch, either direction (9.10) |
| **`MCPY`, `MMOV`, `MSET`, `MCMP`, `MSCN`, `MSCNN`** | the block operations: copy, move (overlap-safe), fill, compare, scan for a byte, scan for the first byte not equal; progress is held in registers so a fault restarts for free (9.11) |
| **`MVAL`** | block scan of valid UTF-8, one of the string instructions of the same family (9.9) |
| **`PUSHM`, `POPM`** | push and pop a register set named by a mask; the useful half of the VAX's `CALLS` without the frame (9.11) |
| **`JMPI`, `CALLI`** | jump and call through a memory word; the only deferred forms, used for PLT stubs and imports (9.10, 9.16) |
| **`JTAG`, `TAGOP`** | multiway dispatch on a pointer's low tag bits, and the tag-branch group (9.10) |
| **`LPAD`** | marks a legal target of an indirect jump or call; optional in ABI version 1 (appendix A.1) |
| **`CLMUL`** | carry-less multiply, the primitive under every CRC and Galois-field operation (9.9) |
| **`XNORPOP`, `POPCNT`** | bit-population instructions used by binary operations and bitsets (8.3) |
| **`SET cc, rd`** | set a register to 0 or 1 from a condition (9.7) |
| **`DP`** | the direct pointer: in user mode it is the thread pointer, in kernel mode the per-CPU pointer; a descendant of the 6502's zero page (9.3, 9.16) |
| **`PSW`** | the processor status word: flags, mode, priority and the guard bit (6.2) |
| **`N Z V C`** | the four condition flags: negative, zero, overflow, carry (9.3) |
| **canonical address** | a 64-bit address whose bits above the top bit of the virtual address (bit 38, 47 or 56 with three, four or five levels) equal that bit; any other value faults, so software cannot hide tags in the high bits (6.6) |
| **`lowtag`** | a type tag stored in the low bits of a pointer, free because objects are quad-aligned (instruction-set text, section 6.2; not otherwise used in this manual) |
| **SWAR** | SIMD within a register: using one wide scalar register as several narrow lanes through masking and carry-aware arithmetic (instruction-set text, glossary; the manual's bit and byte instructions of 9.9 make it effective) |
| **`FPSR`** | the sticky floating-point exception flag register, read and written by `FSFLAGS` (9.12) |

## C.2 Memory, protection and the kernel

| Term | Meaning |
|---|---|
| **`MT`** | memory type, a two-bit page attribute: normal cached, normal uncached, device strongly ordered (2.3, 6.7) |
| **`ASID`** | address space identifier: tags translation-buffer entries so a context switch flushes nothing (6.8) |
| **`G` bit** | global: a translation-buffer entry that ignores the `ASID` (6.8) |
| **TLB** | translation lookaside buffer: the cache of page-table entries; `TLBI` invalidates one, `TLBIA` all, `TLBSYNC` waits for other cores (7.5) |
| **`DMW`** | direct mapping window: a region translated by a fixed offset with no page table; stored without effect, the format is open (6.9) |
| **`MMUCTL`** | the register that enables translation and sets the table base (6.5, 6.8) |
| **virtual address, physical address** | the number a program uses, and the number the memory answers to; the page tables translate one into the other (6.6) |
| **page, frame, page table** | a 4 KB piece of virtual space, a 4 KB piece of physical memory, and the tree of tables of 512 entries that says which frame holds which page (6.6) |
| **PTE** | page-table entry: one 64-bit word with the valid, permission, accessed, dirty, global and memory-type bits and the physical page number (6.7) |
| **leaf, pointer** | the two kinds of page-table entry: one that maps a page (`R`, `W` or `X` set) and one that points to the next table (6.7) |
| **`KT11`, `PAR`, `PDR`** | the PDP-11's memory-management unit, with eight pairs of page address and page descriptor registers for each mode (6.1, 6.6) |
| **`EPC`, `EPSW`, `EVA`, `ECAUSE`** | the registers that exception entry writes: where to resume, the old status word, the faulting address, the vector number (6.3) |
| **`VBR`** | the vector base register: where the table of 512 eight-byte entries begins (6.3) |
| **`ISYNC`** | makes earlier writes to system registers take effect: wait for earlier instructions, discard later ones, fetch again (6.5) |
| **`MFSR`, `MTSR`** | move from and to a system register, by number (6.5) |
| **software-managed `A`, `D`** | accessed and dirty bits set by the kernel's page-fault handler, never by the walker (6.8) |
| **shootdown** | removing a stale translation from the buffers of other cores; on the pdp64 `TLBI` broadcasts and `TLBSYNC` waits (6.8) |
| **walker** | the hardware that reads page-table entries on a translation-buffer miss (6.6) |
| **`STUA` / `CLUA`** | set and clear the user-access guard bit, which lets kernel code touch user memory only inside the copy routines (6.10) |
| **`PROBER` / `PROBEW`** | test whether an address is readable or writable in a given mode without faulting (6.10, 6.13) |
| **PIE** | position-independent executable: loadable at any address; costs nothing here (9.16) |
| **GOT, PLT** | global offset table and procedure linkage table: the indirection that lets position-independent code reach imported symbols (9.16) |
| **ABI** | application binary interface: calling convention, register use, data layout; version 1 is given in appendix D |
| **trap, exception, interrupt** | a deliberate entry (`TRAP #n`), a fault raised by an instruction, and a signal from a device; all enter through the vector table (6.3) |
| **precise fault** | a fault after which every earlier instruction has completed and no later one has changed state (6.4) |
| **`SPL`** | set the interrupt priority level (6.3) |
| **`WFE`, `SEV`** | wait for an event and send an event: the idle and wake-up pair (7.6) |
| **`FENCE`** | orders memory accesses; owed to devices and to other cores (2.8, 7.2) |
| **`ATOM`, monitor** | the atomic operations, built on a reservation monitor as in AXI and ARM, not a locked bus cycle (7.3) |
| **SMP** | symmetric multiprocessing: several identical cores sharing memory (chapter 7) |
| **core class** | the read-only register of each core that gives its class and capacity, so that software can tell an in-order core from an out-of-order one (7.8.3) |
| **secure core** | a core with every timing channel removed (every instruction and cache fetch takes a time independent of its data), private cache lines and no periodic tick (7.8.5) |
| **dedicated core** | a core given to one job, graphics, network or audio; decided, with its details pending (7.8.6) |
| **coherence, snooping MSI** | the protocol that keeps each core's cache consistent with the others; snooping means each cache watches the bus; MSI is its three states (modified, shared, invalid) (7.7) |
| **sequential consistency** | the memory model in which all cores see all accesses in one order; the pdp64 declares it (7.2) |

## C.3 The bus, devices and boot

| Term | Meaning |
|---|---|
| **Unibus, Q-bus** | the PDP-11's buses; PCI Express keeps their programming model, with devices in the address space (2.3) |
| **`DATIP` / `DATO`** | Unibus and Q-bus transaction types forming a locked read-modify-write (2.10) |
| **window** | a region of the physical address space that a device's base-address register describes, a whole number of pages, found by enumeration (2.4, 5.3) |
| **root complex** | the root of the PCI Express bus: it enumerates the functions, assigns their windows, and reports arrivals and departures (2.4) |
| **bridge** | a function that is itself a bus: it presents the functions behind it, so arbitrary buses (PCI Express, USB) can be connected to the bus and enumerated to any depth (2.4.3) |
| **MMIO** | memory-mapped input/output: device registers reached by ordinary loads and stores (5.3) |
| **DMA** | direct memory access: a device moving data to or from memory without the processor (5.10) |
| **virtqueue, descriptor, available ring, used ring, doorbell** | the common device protocol: a table of 16-byte descriptors in memory, a ring in which the driver offers chains, a ring in which the device returns them, and a write that tells the device to look (5.4) |
| **`device_status`** | the common-configuration field through which the driver and the device handshake; writing zero resets the device (5.4, 5.5) |
| **virtio** | a standard family of devices of the same queue-and-descriptor shape, the pdp64's device interface (5.4) |
| **virtio-blk** | the standard disk: a virtqueue of read, write and flush requests (5.6.1, 5.6.2) |
| **NVMe, SCSI, ATA, SATA** | storage interfaces, each a command queue in memory and a doorbell, which is the same device pattern (5.4); an NVMe device may be attached as any PCI Express device may, but the standard disk is virtio-blk |
| **driver, strategy routine, device switch, probe, attach** | the kernel code for one kind of device; the routine that queues one block transfer; the table of such routines indexed by the major device number (`bdevsw`, `cdevsw`); the routines that test whether a device is present and set it up (5.1, 5.5) |
| **`INIT` and `READY`** | the PDP-11 CSR's reset command and done bit; on the pdp64 the `device_status` handshake (5.5) |
| **softc, `cfattach`** | OpenBSD's per-device structure and the table of a driver's `match` and `attach` functions (5.13) |
| **HDMI transmitter** | the chip that takes a pixel stream and does the link protocol; the pdp64 side is a pixel generator and registers (3.10) |
| **Blit** | Rob Pike's bit-mapped windowing terminal: an 8 MHz Motorola 68000 machine that received downloaded code, characters and editing messages from its host over a serial line and drew every pixel itself (its description as a precursor of the X11 protocol and of NeWS is stated by no source read *(S)*; the lineage the sources confirm runs from its `mux` to 8½ and `rio`); a framebuffer in the address space and a bit-block-transfer operation, done in software, that moves rectangles of pixels; with the C64, one of the two machines the pdp64's terminal is based on (3.1) |
| **blitter, raster operation** | a device that copies and combines rectangles of pixels; the raster operation says how source and destination combine (3.8) |
| **scanout, tearing, double buffering** | the display reading the picture out of memory row by row at a fixed rate; the seam where a picture changed during the reading shows old above and new below; drawing the next frame in a hidden second picture and swapping at the vertical blank (3.15) |
| **glyph map, glyph atlas** | a table of slots each holding the picture of one glyph, filled by a TrueType engine (3.9); the GPU form is one texture holding every glyph the screen uses (3.7) |
| **rio, NeWS** | Plan 9's window system, in which each window is a private screen served as files, a descendant of the Blit's `mux` through 8½; and Sun's window server that programs downloaded from the host could extend (3.18) |
| **mixer, ring buffer, underrun** | the program that sums the sample streams of several programs into one after converting their rates and formats; the circular buffer the sound device reads at the converter's clock; the reader reaching samples not yet written, audio's tear (3.17) |
| **GPU, shader** | a graphics processing unit, thousands of simple lanes; a shader is a small program it runs for every vertex or every pixel (3.6) |
| **bootstrap, boot ROM, block 0** | the program that loads programs; the ROM in the controller chip that reads the first block of the boot device into memory and jumps to it; that first 512-byte block (4.1, 4.4) |
| **BIOS** | the PC's firmware: bring-up and self-test, the first sector, a library of services called by software interrupt, and setup; the pdp64's "BIOS" is its boot ROM and monitor, with no resident services; open source (4.2, 4.3) |
| **first stage, second stage, `installboot`** | the program in block 0, which carries a list of where the next program lies; the C program that reads the label and the file system and loads `/bsd`; the tool that writes the first stage and its list (4.3, 4.5, 4.6) |
| **partition, MBR, protective MBR** | a named region of a disk; the PC's first sector, with 446 bytes of boot code, a four-entry table and `0xAA55`; the MBR of a GPT disk, with one entry of type `0xEE` covering the disk (4.2, 4.5) |
| **GPT, disk label** | the GUID partition table wrapped around the disk's own label so other systems see the disk is in use; the BSD label that names the root, swap and other partitions inside one partition (4.2, 4.5) |
| **boot-information block** | the structure whose address the second stage passes in `r1`: memory ranges, cores, the root complex, the boot device, the console, the screen, the command line (4.6) |
| **UEFI, PE/COFF, shim** | the PC's later firmware standard, which runs a loader file of the PE/COFF format and offers it boot services; not used by the pdp64; a shim is the small program that would offer those services over virtio to an existing loader (4.2, 4.9) |
| **`ODT`, monitor** | the PDP-11's console debugger; the ROM's console program for examine, deposit, load and start (4.1) |
| **INIT, START-UP, spin table, hart** | x86's signals that start another core; ARM's table the waiting cores poll; RISC-V's word for a core; the pdp64 writes a start register instead (4.7) |
| **APL, K** | array languages whose primitives work on whole arrays; one primitive maps to one descriptor (8.4) |

## C.4 Process and sources

| Term | Meaning |
|---|---|
| **errata** | the numbered decision log of the project (`../errata.md`, appendix F) |
| **fair corpus** | the 827 or 841 C files that every back end compiles, used for all size comparisons (1.5) |
| **`pcc`** | the portable C compiler the project extends to emit pdp64 code (1.5) |
| **`sim64`, QEMU** | the instruction-set simulator and the full-system emulator the tests run on (1.5, 10.4; not otherwise described in this manual) |
| **(D)** | the tag on a statement that the author decided (index) |
| **details pending** | the mark on a decided statement whose details are not yet worked out; it names the open item that discusses them (appendix J), or says that the details are to be determined (index) |
| **deferred** | a matter that the author has decided to put off; it is listed in appendix I and is not open (index) |
| **open item** | a question that the architecture must answer and has not; each has an entry in appendix J with the issue, the options and what each costs, and the body points to it in a few words (index) |
| **proposed** | an idea or design that nobody has decided; it is listed in appendix H and is not part of the architecture (index) |
| **Impact** | the line ending each decision's commentary: effect on the kernel, on the compiler and on the hardware layout (index) |
