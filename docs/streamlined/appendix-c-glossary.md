# Appendix C. Glossary

[← streamlined index](00-index.md)

**Terms the book uses, collected in one place.** Each entry gives the plain meaning and, in brackets, the chapter or section where the book deals with it. Terms for the instruction groups (the "escape" opcodes) are listed by name and opcode; the full encodings are in the instruction-set text [`../pdp64-isa.md`](../pdp64-isa.md).

## C.1 Architecture and encoding

| Term | Meaning |
|---|---|
| **pdp64** | the 64-bit extension of the PDP-11 this book describes, as the PDP-11 extended the PDP-10's ideas down and the VAX extended the PDP-11 up (chapter 1) |
| **parcel** | a 16-bit unit of instruction encoding; an instruction is one to three parcels, two to six bytes (9.4) |
| **`len`** | bits 15 and 14 of the first parcel: the number of extension parcels for `00`, `01` and `10`; the value `11` selects the second opcode page (9.4) |
| **page 1, page 2** | the two opcode maps. Page 1 has 64 top-level opcodes, 58 assigned; page 2 (`len = 11`) has 64 one-parcel entries, 45 defined, each an exact abbreviation of a page-1 instruction (9.1) |
| **top-level opcode** | the six bits that select an instruction group; reserved for an operation whose common case is register-to-register (9.1) |
| **escape opcode** | a top-level opcode that selects a group by a sub-opcode: `BESC` (bits, `0x0C`), `MBLK` (block memory, `0x0D`), `AESC` (arithmetic, `0x0E`), `MESC` (unaligned and memory ALU, `0x0F`), `FESC` (floating point, `0x10`), `ATOM` (atomics, `0x11`), `XFER` (indirect transfers, `0x12`), `SOP` (single operand, `0x13`), `SYS` (system, `0x14`), `TAGOP` (tag branch, `0x15`) |
| **`CBCC`** | compare-immediate-and-branch on condition, opcode `0x28`, the one fused compare and branch (9.10) |
| **`RORI32`** | rotate right by an immediate, 32-bit, sign-extended result, a `BESC` sub-opcode |
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
| **`PSW`** | the processor status word: flags, mode, priority and the guard bit (6.1) |
| **`N Z V C`** | the four condition flags: negative, zero, overflow, carry (9.3) |
| **canonical address** | a 64-bit address whose bits above 38 equal bit 38; any other value faults, so software cannot hide tags in the high bits (6.4) |
| **`lowtag`** | a type tag stored in the low bits of a pointer, free because objects are quad-aligned (instruction-set text, section 6.2; not otherwise used in this book) |
| **SWAR** | SIMD within a register: using one wide scalar register as several narrow lanes through masking and carry-aware arithmetic (instruction-set text, glossary; the book's bit and byte instructions of 9.9 make it effective) |
| **`FPSR`** | the sticky floating-point exception flag register, read and written by `FSFLAGS` (9.12) |
| **ulp** | unit in the last place: the spacing between adjacent floating-point numbers, the unit of rounding error |
| **Payne–Hanek** | the argument-reduction algorithm that computes x mod π/2 to full precision for large x; what hardware transcendentals cannot do (instruction-set text, section 9.7.1; the book's account of floating point is 9.12) |
| **Table Maker's Dilemma** | that correct rounding of a transcendental may need unboundedly many bits to resolve a near-tie, so no fixed-time circuit can guarantee it (instruction-set text, section 9.7.1) |
| **block floating point** | integer mantissas sharing one exponent, used by the LB64 accelerator so fixed-point accumulation is exact (8.3) |

## C.2 Memory, protection and the kernel

| Term | Meaning |
|---|---|
| **`MT`** | memory type, a two-bit page attribute: normal cached, normal uncached, device strongly ordered (2.1, 6.4) |
| **`ASID`** | address space identifier: tags translation-buffer entries so a context switch flushes nothing (6.4) |
| **`G` bit** | global: a translation-buffer entry that ignores the `ASID` (6.4) |
| **TLB** | translation lookaside buffer: the cache of page-table entries; `TLBI` invalidates one, `TLBIA` all, `TLBSYNC` waits for other cores (7.5) |
| **`DMW`** | direct mapping window: a region translated by a fixed offset with no page table; deferred (errata 44) |
| **`MMUCTL`** | the register that enables translation and sets the table base (6.3, 6.4) |
| **walker** | the hardware that reads page-table entries on a translation-buffer miss (9.15) |
| **`STUA` / `CLUA`** | set and clear the user-access guard bit, which lets kernel code touch user memory only inside the copy routines (errata 43, 6.5) |
| **`PROBER` / `PROBEW`** | test whether an address is readable or writable in a given mode without faulting (9.14) |
| **W^X** | write xor execute: no page is both writable and executable; OpenBSD enforces it (appendix A) |
| **PIE** | position-independent executable: loadable at any address; costs nothing here (9.16) |
| **GOT, PLT** | global offset table and procedure linkage table: the indirection that lets position-independent code reach imported symbols (9.16) |
| **ABI** | application binary interface: calling convention, register use, data layout; version 1 is accepted (errata 46) |
| **trap, exception, interrupt** | a deliberate entry (`TRAP #n`), a fault raised by an instruction, and a signal from a device; all enter through the vector table (6.2) |
| **precise fault** | a fault after which every earlier instruction has completed and no later one has changed state (9.15) |
| **`SPL`** | set the interrupt priority level (6.2) |
| **`WFE`, `SEV`** | wait for an event and send an event: the idle and wake-up pair (7.6) |
| **`FENCE`** | orders memory accesses; owed to devices and to other cores (2.2, 7.2) |
| **`ATOM`, monitor** | the atomic operations, built on a reservation monitor as in AXI and ARM, not a locked bus cycle (errata 45, 7.3) |
| **SMP** | symmetric multiprocessing: several identical cores sharing memory (chapter 7) |
| **coherence, snooping MSI** | the protocol that keeps each core's cache consistent with the others; snooping means each cache watches the bus; MSI is its three states (modified, shared, invalid) (7.7) |
| **sequential consistency** | the memory model in which all cores see all accesses in one order; the pdp64 declares it (7.2) |

## C.3 The bus, devices and boot

| Term | Meaning |
|---|---|
| **Q64** | the system bus: the PDP-11 Q-bus lineage widened to 64-bit data and 40-bit addresses (2.1) |
| **Unibus, Q-bus** | the PDP-11's buses; Q64 keeps their programming model, with devices in the address space (2.1) |
| **`DATIP` / `DATO`** | Unibus and Q-bus transaction types forming a locked read-modify-write (2.5) |
| **space bit** | bit 39 of the physical address: set selects device space, clear selects memory (2.1.6, errata 60) |
| **slot** | a device's own 4 KB (or larger) window of device space, found by enumeration (2.6, 5.1) |
| **bus controller** | the device that is the bus: it enumerates slots, maps them, and reports arrivals and departures (2.6) |
| **MMIO** | memory-mapped input/output: device registers reached by ordinary loads and stores (5.1) |
| **DMA** | direct memory access: a device moving data to or from memory without the processor (5.4) |
| **ring, descriptor, `OWN`, doorbell** | the common device protocol: a ring of 32-byte descriptors in memory, each with an ownership bit the host sets and the device clears, and a register written to tell the device to look (5.2) |
| **`ID` / `CONTROL` / `STATUS` / `RING_BASE` / `RING_SIZE` / `DOORBELL` / `IRQ` / `DEVICE`** | the eight common registers every device starts with (5.2) |
| **`INIT`, `READY`** | the control bit that makes a device initialise itself and the status bit that says it has (5.2, 5.3) |
| **virtio** | a standard family of virtual devices of the same ring-and-descriptor shape; the emulator's first drivers (5.5, appendix B) |
| **NVMe, SCSI, ATA, SATA** | storage interfaces, each a command queue in memory and a doorbell, which is the same device pattern (errata 61, 5.5) |
| **HDMI transmitter** | the chip that takes a pixel stream and does the link protocol; the pdp64 side is a pixel generator and registers (3.3) |
| **`VIC-64X`, `SID-64X`, `BLT64`** | the video, sound and blitter devices of the graphics terminal (chapter 3) |
| **blitter, raster operation** | a device that copies and combines rectangles of pixels; the raster operation says how source and destination combine (3.1) |
| **BIOS, boot ROM** | the first software that runs: it brings the hardware up, finds the disk label and loads the next stage; open source (4.1, errata 47) |
| **GPT, disk label** | the GUID partition table wrapped around the disk's own label so other systems see the disk is in use (4.3, errata 50) |
| **LB64, MX64, VEC64** | the inference accelerator and its companions: sign-flip-accumulate layers, floating-point multiply-accumulate for attention, and element-wise vector work (8.3) |
| **APL, K** | array languages whose primitives work on whole arrays; one primitive maps to one descriptor (8.4) |

## C.4 Process and sources

| Term | Meaning |
|---|---|
| **errata** | the numbered decision log of the project; every decision in the book cites its item (`../errata.md`) |
| **revision 20** | the last full revision of the instruction-set text before the streamlined set; changes since are in `../CHANGES-SINCE-R20.md` |
| **fair corpus** | the 827 or 841 C files that every back end compiles, used for all size comparisons (1.5) |
| **`pcc`** | the portable C compiler the project extends to emit pdp64 code (1.5) |
| **`sim64`, QEMU** | the instruction-set simulator and the full-system emulator the tests run on (1.5, 10.4; not otherwise described in this book) |
| **(D), (P), (S)** | the tags on a numbered statement: decided, proposed, stub (index) |
| **Impact** | the line ending each decision's commentary: effect on the kernel, on the compiler and on the hardware layout (index) |
