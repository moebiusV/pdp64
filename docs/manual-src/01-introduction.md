# 1. Introduction

[← manual index](00-index.md)

**The pdp64 is a 64-bit computer architecture in the PDP-11 line: one CPU, with thirty-two 64-bit registers and instructions of two, four or six bytes, that reaches everything outside itself over PCI Express, where the standard disk, network card, display and sound device are virtio devices (one standard interface, with one driver routine for every kind of device).** It keeps what made the PDP-11 pleasant to program: devices that are memory locations, a stack pointer that is an ordinary register, autoincrement addressing, a small set of regular rules. It changes what fifty years of machines and compilers showed to be a mistake or a missing piece. The manual is written for a first-year computer-science student or an experienced PDP-11 assembly programmer, and assumes that neither knows anything that happened in computer architecture after the 1970s (errata 103).

This chapter has three jobs. It says what the machine is and how to read the manual (1.1, 1.2). It puts the road from the PDP-11 to the pdp64 in one table, with the author's own account of where the design began (1.3). And it states the principles the design follows and the measurements that back them (1.4 to 1.8). After 1.3 the chapters can be read in any order: each starts from what a PDP-11 programmer knows of its subject.

## 1.1 What the pdp64 is

If you have programmed a PDP-11 you know a machine with eight 16-bit registers (R6 the stack pointer, R7 the program counter), a 64 KB address, devices at addresses near the top of the Unibus address space, and one processor. The pdp64 is that machine grown up in each respect, and the figure shows what surrounds the processor.

![The pdp64 as a system](figures/intro-machine.svg)

**1.1.1** The pdp64 is a little-endian machine with thirty-two 64-bit general registers, `R0` to `R31`; `R14` is the stack pointer and the program counter is not a register. An instruction is two, four or six bytes long (ten for the one instruction that carries a 64-bit constant), and its first 16 bits fix what it is and how long it is (chapter 9). *(D)*

**1.1.2** A program uses virtual addresses of 39, 48 or 57 bits, according to a page table of three, four or five levels, and the number is discoverable at run time; a physical address is 40 to 64 bits wide (6.6). The PDP-11 had 16 bits of virtual address and 18 or 22 of physical. *(D)*

**1.1.3** There is one CPU architecture and one manual. Two earlier designs were built and measured against it and are history (1.8). *(D)*

**1.1.4** The machine has several cores from the start: at least four, with sixteen or more as the ceiling that no decision may preclude; all cores see one memory, which is sequentially consistent (chapter 7). *(D)*

**1.1.5** The processor has no input or output instructions: a device is a few memory locations that ordinary loads and stores reach, as on the PDP-11. The bus is PCI Express, so an ordinary PCI Express card works on it unchanged; the standard devices are virtio devices (the disk is virtio-blk) and USB controllers, and the kernel finds them by enumeration, not by switch settings (chapters 2 and 5). *(D)*

*Commentary.* **Chain.** The PDP-11 had 16-bit words and no step beyond. The VAX-11 widened it to 32 bits (1.4). The author's choice, on 2026-08-30, was to skip the 32-bit step: "let's skip 32 bit version and go straight to 64bit" (R29) and "basically upgrade pdp-11 straight to 64 bit" (R30). **Trade-off.** Eight 16-bit registers become thirty-two 64-bit ones, so a register number needs five bits instead of three, and the instruction encoding changes with it (1.8). **Impact.** *Kernel:* the status word, vectors and modes stay recognisable (chapter 6). *Compiler:* 64-bit integers and pointers are one register each. *Hardware:* one register file, one ALU width.

## 1.2 Who the manual is for, and how to read it

You know the PDP-11, or you are learning computing from the start. Either way the manual assumes you have met nothing invented after the 1970s: not the PCI bus, the tree of page tables, the out-of-order core, the GPU or virtio.

**1.2.1** The manual is written for two readers: a first-year computer-science student and an experienced PDP-11 assembly programmer. Neither is assumed to know anything of computer architecture that came after the 1970s, so every later idea is explained where it first appears. *(D)* (errata 103)

**1.2.2** A term is defined where it first appears, as the technical word followed by a plain restatement: a prefix code (a set of bit patterns none of which begins another, so the first bits of an instruction tell the decoder what it is). In the figures a box is a piece of memory or a register and an arrow is an address stored in it, as a textbook draws a linked list. Code blocks are pseudocode (C-like, with `#` starting a comment) unless the text says they are PDP-11 or pdp64 assembly.

**1.2.3** The PDP-11 material is quoted from the Unix Version 6 and 7 and 2.11BSD sources and from the PDP-11/70 handbook; the pdp64 listings are illustrations written for the manual and are not part of the architecture. A fact about another machine that could not be checked against a source on hand is marked *unverified*.

**1.2.4** A chapter that has a history starts from the PDP-11 way, names the machines that came between with the one thing each added, and ends at the pdp64 way with the reason; these are the paragraphs headed **Chain**. The commentary under a decision also gives the **Trade-off** it makes and its **Impact** on an efficient kernel, on efficient compilation and on an efficient hardware layout (errata 58).

**1.2.5** A numbered statement such as 9.3.1 is a rule of the architecture. *(D)* means the author decided it; a statement with no tag describes the architecture as it is to be. *(E)* marks an estimate, not a measurement, and *(measured)* a figure that was measured, with its source.

**1.2.6** The body of the manual holds decided material only. Where a decision's details are not yet worked out, the statement ends with *Details pending* and the number of the open item, or with *Details to be determined*. A question the architecture must still answer is named in a few words, as *Open: ...*, with a pointer to its entry in appendix J. What has only been proposed is in appendix H, what has been put off in appendix I, and each open question, with its options and what each costs, in appendix J.

The chapters, and what a PDP-11 programmer brings to each:

| Chapter | What it covers | The PDP-11 starting point |
|---|---|---|
| 2 The bus | PCI Express, virtio, interrupts that are writes, the IOMMU | the Unibus and its registers |
| 3 Graphics | the terminal, HDMI, audio, windows | the teletype, then the Blit and the Commodore 64 |
| 4 Boot | the first block, the second stage, the other cores | the front panel and the boot ROM |
| 5 Drivers | the virtio transport, class drivers, interrupts and DMA | `rk.c` and the `bdevsw` table |
| 6 The kernel | modes, exceptions, page tables, system calls | the V7 kernel: `trap()`, the KT11, `mfpi` |
| 7 Multiple processors | memory model, atomics, per-core state, translation coherence | one processor and `spl()` |
| 8 Vector work | accelerators on the bus for neural networks and array languages | no vector unit; the FP11 for floating point |
| 9 The instruction set | formats, modes, every instruction | the PDP-11 instruction set |
| 10 Conclusion | the finish line, the security aims, what remains | |

The instruction reference tables, with a chart of every instruction's bit layout, sit beside chapter 9. The appendices are: A, improvements the author approved and has yet to specify; B, pointers to the proposals behind earlier decisions; C, the glossary; D, the application binary interface (how compiled code, the linker and the operating system agree); E, the assembly language and the object format; F, the evidence documents; G, how the design grew, with dates; H, proposed; I, deferred; J, open items.

## 1.3 The road from the PDP-11

The PDP-11 programmer's first question is which of what he knows still holds. The table answers it row by row; the commentary after it says where each row's history is told.

**1.3.1** The PDP-11 and the VAX-11 were pleasant, even fun, to program in assembly language; afterward computer design went in many directions and that pleasure was largely lost. The pdp64 carries it forward with the lessons of the last fifty years: which instructions are needed to get things done and which are not, what a processor is used for and which instructions it needs the most, to have "less possibility for error, fewer footguns, fewer surprises" and "the most bang for buck" (R197, 2026-10-22).

**1.3.2** The design began as a PDP-11 brought up to date by a little, and grew by decisions that each answered a question. The author's account (2026-11-10, appendix G): "we started off as a pdp16 modernized a tiny bit, then got more and more ambitious", and "the initial idea was, could a pdp16 run effectively today with a blit terminal and off-loaded 8-register nic", with "the blit being a mashup with the c64 for audio" (R393). In the author's usage a pdp16 is a 16-bit machine of the PDP-11 line (*inference*: R280, "pdp64 is an extension of pdp16"); the Blit is the Bell Labs bitmap terminal (3.3); an off-loaded network card is one that carries out the network protocols itself, so that the processor only hands it data.

**1.3.3** The first design brief (2026-08-29) was "use pdp-11 as the base, fold in the good parts of c64" (R20), "taking the best isa/architecture and improving it with the good stuff of the other one" (R23). The steps that followed are in appendix G; the ones that shaped this chapter are the 64-bit step (1.1), the little-endian rule ("none of this middle endian stuff", R22), the bus (PCI Express, errata 80; virtio across the board, errata 95), several cores (errata 92) and the priorities of 1.6. The "off-loaded 8-register nic" of the first idea was replaced by virtio devices (errata 95).

The figure gives the road in three tracks, the processor, the bus and the terminal, each from the PDP-11 to the pdp64 through the steps between; the table that follows gives the same road row by row.

![The road from the PDP-11 in three tracks](figures/intro-road.svg)

| What | The PDP-11 | The pdp64 | Why | Where |
|---|---|---|---|---|
| Registers | eight visible at a time, of 16 bits; R6 stack pointer, R7 program counter (11/70 handbook 1.4) | thirty-two of 64 bits; `R14` stack pointer; the program counter is not a register and `R7` is ordinary (*D*) | 64-bit data; on the programs measured, 32 registers cut the frame loads and stores executed from 65.2 to 24.3 million against 16 (1.8.3); a write to a register never jumps | 9.3 |
| Byte order | little-endian words; a 32-bit long is two words, high word first (*inference*, V7 `l3.c`) | little-endian throughout, no middle-endian long (R22) | one rule for every width | 9.4 |
| Instruction length | 2, 4 or 6 bytes: one word, plus one for each operand that has an index, an immediate or an address (handbook 3.2, 3.5) | 2, 4 or 6 bytes; the first 16 bits alone fix the length (*D*) | a decoder that must read one operand after another to know where the next instruction starts is slow | 9.1, 9.4 |
| Operands | two, each any addressing mode, so memory to memory | at most one memory operand; the other is a register (*D*) | only one operand can fault, so restart is simple; 5-bit registers and 12-bit displacements fit in four bytes | 9.2, 6.4 |
| Addressing | eight modes with a deferred (indirect) form of each; autoincrement and autodecrement; index with a following word | autoincrement and autodecrement kept, with a stride; base plus displacement, scaled index, PC-relative, direct page, immediate, absolute; deferred forms removed (*D*) | a deferred mode is a second memory reference inside one operand | 9.5 |
| Flags | N, Z, V, C written by most instructions | the same four; moves, loads, stores and compare-and-branch write none; no instruction writes part of N, Z, V (*D*) | with the PDP-11 rule 68.2% of compiled instructions wrote a flag and 1.5% read one; flags are what blocks a fast implementation (1.6.4) | 9.3.4 |
| Branches | conditional branch with an 8-bit word offset, reach 256 bytes | 14 conditions; the field grows with the length: about 64 to 512 bytes, 64 KiB, 4 GiB; compare-and-branch; subtract-one-and-branch both ways | long jumps needed a trampoline | 9.10 |
| Calls | `JSR Rn` keeps the return address in a register of the caller's choosing | `CALL` pushes it on the stack: no link register; `PUSHM` and `POPM` save a set of registers (*D*) | every unwinder and debugger expects the return address on the stack | 9.10, 9.18 |
| Devices | registers at fixed addresses set by switches on the card; vectors on the data lines | still memory locations, no input or output instructions; found by enumeration; one virtio interface | one driver routine serves every device | 2, 5 |
| Interrupts and traps | a vector pair (new PC, new PS) in low memory; the old PS and PC are pushed on the kernel stack | vectors and a three-bit priority kept; entry writes the old state into registers and cannot fault | the push could fault; the PDP-11 needed a journal to undo it | 6.3, 6.4 |
| Memory management | the KT11: eight segments of up to 8 KB for each mode, base and length; swapping whole images | page tables of three, four or five levels; a translation buffer with address-space numbers | pages are handed out singly and need no contiguous memory | 6.6 to 6.8 |
| Modes | kernel, supervisor, user; a stack pointer for each | kept (*D*) | the PDP-11 arrangement was already right | 6.2 |
| Floating point | the FP11 with mode bits for double precision, long integers and truncation | IEEE 754 half, single and double precision in the general registers, with a fused multiply-add; no mode bits (*D*) | one result format, no hidden state | 9.12 |
| Processors | one; the V7 kernel guards itself by raising the priority (`spl`) | several cores, sequentially consistent memory, atomics (*D*) | a second core must be easy to add | 7 |
| Boot | a ROM reads one block from the disk and jumps to it | the same (*D*) | it is small and every stage after it is ordinary software | 4 |
| Terminal | a teletype, then video terminals with escape codes | text and graphics set by simple stores, in the spirit of the Blit and the Commodore 64 | the author based the design on both machines (R20, R291, R393) | 3 |

**1.3.4** The PDP-11 is a source, not an obligation: what earned its place is kept, what did not is dropped, and what fifty years showed to be missing is added.

*Commentary.* **Chain.** Each row has its history in the chapter named: the instruction set in 1.4 and 1.5, the bus in section 2.1 (the Unibus, the Q-bus, the VAX interconnect, PCI, PCI Express, virtio), the terminal in 3.1 to 3.5 (the teletype, the VT52, the Blit, the Commodore 64, VGA), boot in 4.1 and 4.2, drivers in 5.1 and 5.2, the kernel in 6.1. The machines the author himself named first, in the order of his messages (appendix G.2), are the Blit, the VAX instruction set and the DEC Alpha, the Unibus and Q-bus against PCI (all 2026-08-23); the Commodore 64 with its SID sound chip, USB and NVMe, V7 Unix as the software base, the 6502 family and IEEE 754 floating point (2026-08-29); x86 and UTF-8's length-first coding (2026-08-30). **Trade-off.** The table lists what changed, and a change has a price: a load and a store where the PDP-11 had one memory-to-memory `mov`, a longer encoding for a deferred access, no compact `JSR Rn` for coroutines. 9.18 lists the idioms restored, lost and replaced. **Impact.** *Kernel:* chapters 4 to 7 follow the V7 kernel's order. *Compiler:* a register-to-register core with one memory operand, as a RISC compiler expects, and the PDP-11's addressing for the loops that want it. *Hardware:* a decoder that finds the length from a prefix and no microcode.

## 1.4 What made the PDP-10, the PDP-11 and the VAX-11 good to program

What you know: the PDP-11 loop. This is V7's start-up code clearing the user structure (`usr/sys/conf/mch.s`; the comments are added here):

```
        mov     $_u,r0          / r0 points at the user structure
1:      clr     (r0)+           / store zero where r0 points, then add 2 to r0
        cmp     r0,sp           / has r0 reached the stack pointer?
        blo     1b              / no (unsigned lower): go round again
```

`clr (r0)+` is one two-byte instruction that stores and steps the pointer: in C, `*p++ = 0`. The pdp64 keeps the instruction, and the whole loop is the same three lines (an illustration; `r0` already points at the start):

```
1:      clr     (r0)+           ; store 8 bytes of zero, then add 8 to r0 (a stride of 0 means the access size)
        cmp     r0, sp          ; has r0 reached the stack pointer?
        blo     1b              ; no (unsigned lower): go round again
```

Three differences. The register is 64 bits and the store is 8 bytes, so each trip clears four times as much. `clr` is four bytes, because a memory operand with a post-increment needs a 12-bit stride field and a 5-bit register field (the leaf `SOF.PI12` of the grammar); `cmp` and `blo` are two bytes each here, because `r0` and `sp` are among the hot registers that a one-parcel form can name (9.4.6), so the loop is eight bytes where the PDP-11's is six. And a compare-and-branch, `cblo r0, sp, 1b`, can take the place of the last two (four bytes, no flags written).

**1.4.1** The PDP-10 gave a programmer one word per instruction that said everything: the operation, the register, the index register, the indirect bit and the address. *(unverified)*

**1.4.2** The PDP-10's registers were also memory: the sixteen accumulators answered to the addresses 0 to 15. *(unverified)*

**1.4.3** The PDP-10 had half-word and byte operations, stack and skip instructions, and a procedure call that was one instruction (`PUSHJ`). *(unverified)*

**1.4.4** The PDP-11 made every addressing mode available with every register, so that the language had few exceptions to remember (11/70 handbook, chapter 3: the general registers can be used as accumulators, pointers, stepping pointers and index registers).

**1.4.5** The PDP-11's program counter and stack pointer were ordinary registers (R7 and R6), and its autoincrement and autodecrement modes made `*p++` and `*--p` single instructions.

**1.4.6** The PDP-11 had no input or output instructions: a device was a few memory locations, and a driver was an ordinary program.

**1.4.7** The VAX-11 widened the PDP-11 to 32 bits and added three-operand arithmetic, a complete virtual-memory system, and instructions for the jobs programs actually do: procedure calls (`CALLS`), queues (`INSQUE`), character strings (`MOVC3`), array indexing (`INDEX`) and polynomial evaluation (`POLY`). (VAX architecture handbook, EK-VAXAR-RM-001)

*Commentary.* **Chain.** The PDP-10's simplicity of format and its habit of making the machine's own state addressable (1.4.1, 1.4.2) are the origin of the idea that the machine should hold together in the head; the PDP-10 handbooks are not on this machine, so 1.4.1 to 1.4.3 are general knowledge and unverified. The PDP-11's regularity (1.4.4) is what mattered most to assembly programmers and later to compiler writers: an instruction that takes a register takes an address, an immediate or a stack slot with the same syntax. Its memory-mapped devices (1.4.6) are the reason the pdp64's devices are still memory locations in the one address space (chapters 2 and 5). The VAX-11's richness (1.4.7) bought programmability and cost hidden state in its longest instructions: a page fault in the middle of a character move could not be resumed without a bit in the status word, the "first part done" bit (`PSL_FPD`, 0x08000000, in 4.3BSD `psl.h`), which tells the microcode that the instruction is half done. The Motorola 68000 took the PDP-11's regularity and widened it, and could not restart an instruction after a bus error, so it could not support demand-paged virtual memory (memory fetched from disk when first touched) until its successor, the 68010, patched the fault model (both *unverified* here; the project's instruction-set text, section 10, records them). **Trade-offs.** Each of these qualities had a price that a later machine paid: the PDP-11's regularity a decoder that must read both operand fields to find an instruction's length (1.8), the VAX's richness hidden state in its longest instructions, the 68000's the lost restart. **Improvements.** The pdp64 keeps what made programming pleasant and removes what made implementation hard: no hidden instruction state, so every instruction can be restarted (9.2.6); at most one memory operand (9.2.2); a small fixed maximum instruction length (9.2.3); and no mode bits that change what unrelated instructions mean unless the benefit outweighs the cost (1.6.3). **Modern comparables.** x86-64 kept memory operands and a variable-length encoding. AArch64 has one length, 4 bytes (4.000 bytes an instruction on the 840 files that clang compiled, 1.7), and RISC-V has a 4-byte base with an optional 2-byte compressed form (2.93 bytes an instruction at `-Os` with it). The pdp64 sits between: closer to x86 in the form of its instructions and closer to RISC-V in the discipline of its encoding (`encoding-work/arch-comparison.md`, section 5).

## 1.5 More minimal than its ancestors, where hindsight allows

The PDP-11 was orthogonal (any operation with any addressing mode on any register), and the VAX carried that to completeness: every operation in every data type, with up to six operands, each of any mode.

**1.5.1** In several ways the pdp64 is more minimal than the PDP-11 and the VAX-11: it gives up theoretical completeness where fifty years of use showed the completeness was never exercised, and spends what that saves on power that was (the author, 2026-10-23, R272: "in hindsight, in some ways, we are even more minimal than the vax and pdp11; hindsight let us know which theoretical completeness we could trade for more power").

**1.5.2** Not every instruction works with every addressing mode on every operand: at most one operand of an instruction is a memory reference. *(D)*

**1.5.3** The deferred addressing modes are gone; an indirection is a `JMPI`, a `CALLI` or an ordinary load. *(D)*

**1.5.4** The ALU has one width, there is no arithmetic in the narrow sizes, and there is no conversion opcode group: conversions are moves. *(D)*

**1.5.5** There is one rotate direction, and no slot exists only to complete a table.

**1.5.6** The VAX's packed decimal, string editing and `CALLS` and `CALLG` procedure-call instructions are absent. *(D)*

**1.5.7** There are no transcendental instructions, no separate floating-point register file and no rounding-mode bits. *(D)*

**1.5.8** What the saving buys is power that programs use: a bit unit (population count, count of leading and trailing zeros, byte reversal, bitfields, a carry-less multiply), block operations that restart from their registers, a fused multiply-add with the IEEE exception flags, the full set of atomics, UTF-8 instructions, and a user-memory guard. *(D)*

*Commentary.* **Chain.** The completeness of the PDP-11 and the VAX made assembly programming regular and a compiler's job simple, and it was designed when memory was dear and compilers weak. It was never free. It bought a decoder that must parse specifier after specifier before the next instruction's address is known, and instructions that could fault in the middle with unbounded state to save (1.4). What hindsight lets the pdp64 do is separate the two benefits: keep the regularity that programmers and compilers use (every register is general, every mode means the same wherever it is allowed) and drop the completeness that nobody exercised (a memory-to-memory arithmetic instruction, a deferred mode on every operand, a sized version of every operation). The RISC machines of the 1980s went further and made every instruction register to register except loads and stores; x86 kept one memory operand and has survived on it; the pdp64 takes the middle position. **Trade-offs.** The price is a few more instructions in rare cases, such as a load and a store where the VAX had a memory-to-memory move (`MCPY` covers the block case). Measurements that bear on what was dropped: a signed multiply and an unsigned multiply have the same low 64 bits, so a second multiply would duplicate the first, while the instruction that returns the high half is the one multi-precision arithmetic needs; a carry-less multiply is the primitive beneath every CRC, so no CRC instruction exists; in the first compiler's output on 827 files the multiply is 2,204 of about 370,000 instructions (0.6%) and the four divide instructions together 235 (0.06%) (`codegen-analysis.md`; the rejected features are in `pdp64-isa.md`, section 11). **Improvements.** Each piece of dropped completeness was weighed against what it freed: the one memory operand leaves an undo buffer of one entry and a fault matrix whose third row, an operand write, can never fault (6.4), and it pays for thirty-two registers and a 12-bit displacement in four bytes; dropping the sized ALU removes byte-lane multiplexing and partial-register writes altogether; dropping the transcendentals leaves the multiply-add datapath, which accurate library mathematics is built from. **Impact.** *Kernel:* no instruction can leave half its work done, so the fault handler needs no journal. *Compiler:* instruction selection is register allocation with one memory operand, as on a RISC. *Hardware:* a small decoder, small exception machinery, and the area that completeness would have used goes to the bit unit, the block-move sequencer and the UTF-8 decoder, together under 7% of the core's estimated 92,000 transistors (10.2).

## 1.6 The principles

You know the PDP-11's one rule, that any instruction takes any operand in any mode. The pdp64 has several rules, ranked, and each can be broken for a reason.

**1.6.1** (errata 83, R323) The design follows these priorities, in this order: **security and safety**, meaning errors that can never arise, then errors that are easy to detect, then errors that are cheap to recover from (restart and recovery go together, and an instruction does what its name says and nothing else); **opcode choice**, so that fewer instructions executed means fewer memory fetches; **opcode encoding**, dense, with rare instructions in longer encodings; **speed and power**, served by a low gate count; a **good compiler target**; and **pleasant in assembler**. *(D)*

**1.6.2** All the rules are soft rules: a rule gives way when breaking it is worth more than it costs, with the cost written down (R242: "all the rules are soft rules"). *(D)*

**1.6.3** Between two designs that both work, prefer by this order: the one with no strange side effects (an instruction does what its name says and nothing else); the one that does not push an existing instruction into a longer encoding. Beside the ranking, at every level, do not multiply entities without benefit. Mode bits are decided case by case: by default a mode is visible state, and a bit in a register that is saved anyway costs nothing extra (errata 83).

**1.6.4** The architecture is designed to be efficient with in-order and out-of-order implementations (R297: "designed to be efficient with in-order and out-of-order execution implementations"). An in-order core runs instructions one after another in the order written. An out-of-order core runs whichever are ready, and makes the result look as if they had run in order. The first implementations are in order; nothing is specified in a way that is safe only because the core does not speculate or reorder, and nothing is specified that an out-of-order core could implement only at a large cost (R295, R220). *(D)*

**1.6.5** An instruction is judged by its weight in the loops where it is used, not by how often it appears: a rarely used instruction that sits inside a critical, tight hot loop can earn its place (R296). The measure is profile-weighted (executions multiplied by the instructions and bytes it saves), not a static count. *(D)*

*Commentary.* **Chain.** The PDP-11's rule was regularity (1.4) and the VAX's completeness (1.5); the handbooks on this machine state no ranking of goals (*inference*: none was found in them). Most architectures since have stated none either (*unverified*); the nearest in spirit is RISC-V's published rule of a small base and optional extensions (*unverified*). **Trade-offs.** The priorities agree on almost everything, because a small, regular machine is also compact in code and cheap in gates; the stated order decides which wins when they conflict. Error prevention, detection and recovery is the principle that most often changes a decision. It means counting an option's cost not only in gates and bytes but in the code a kernel must write to handle its failures: a feature that adds a fault, an error return or a half-finished state costs recovery code in every system that uses it, and a feature that makes an operation repeatable from the start costs none. **Improvements.** The soft-rules principle covers the two strongest defaults, "no mode bits" and "natural alignment of quad accesses"; breaking either is weighed like any other choice. Four bits of the design were accepted on those terms: the translation-enable bit that is set once at boot, the user-memory guard in the status word, the data-independent-timing bit `DIT`, and the sticky floating-point flags, which never change what an instruction does. The priority list is written with the soft-rule test and the hot-loop weight as standing constraints, not ranks (the priority lists, `docs/priority-lists.md`). **Impact.** *Kernel:* a restartable instruction needs no recovery code. *Compiler:* weight by use steers the compiler's register use and the fused pairs (9.18). *Hardware:* the out-of-order constraint is why the flags are written as in 9.3.4 and why `CBCC` writes none.

## 1.7 Does the instruction set matter?

You may have heard that a good implementation hides the instruction set. The author wrote this section for a reader who holds that view (R275).

**1.7.1** The instruction set is not interchangeable with any other: it fixes what every implementation must preserve, and so what a processor costs to build, to verify, to program and to secure.

**1.7.2** The common view, that a good implementation hides the instruction set, is true of one thing: the peak speed of a very large core, where a great deal of hardware can absorb almost any encoding.

**1.7.3** It is not true of the cost of a small core, the size of the code, the amount of software a system needs, or the number of ways a system can fail; those follow the instruction set, and they can be measured.

**1.7.4** Each of the rows below is a measurement or an estimate, and each is explained in the chapter named beside it.

| What differs | The figure | Where |
|---|---|---|
| The logic of a complete implementation, same company and era | the PDP-11's T-11, a full integer core without memory management or floating point, about 12,000 transistors; the J-11, the full PDP-11/70 with both, about 120,000; the MicroVAX 78032, a subset of the VAX with no floating point, about 125,000 (all *unverified*) | 10.2 |
| What it takes to find where the next instruction starts | pdp64: a prefix of 3 to 16 bits of the first parcel; PDP-11: both operand specifiers; VAX: every specifier in order; x86: prefixes, opcode, ModR/M and SIB in sequence (*unverified*) | 9.1, 9.4 |
| Whether flags block a faster implementation | with the PDP-11 rule 68.2% of compiled instructions wrote a flag and 1.5% read one (229,389 and 4,999 of 336,408); with the pdp64's rules 16.7% write one, at a measured cost of 0.39% in code size | 9.3.4, 1.6.4 |
| Size of compiled code | 964,158 bytes of instructions on the 841-file corpus; clang `-Os` is 1.21 times that for x86-64, 1.34 for AArch64, 1.22 for RV64GC and 0.91 for Thumb-2; counting the pdp64's constant pools too, x86-64 and RV64GC are 0.97 and 0.98 times | 9.2.13, F.4 |
| Lines of kernel code to start a second core (Linux) | x86: 1,528 plus 1,258 of real-mode code; arm64: 124 (PSCI) or 127 (spin table); RISC-V: 108 or 58 | 4.7 |
| Machine-dependent code in an OpenBSD port | riscv64 35,600 lines; arm64 61,613; amd64 79,167 | 10.5 |
| Errata, workaround and quirk lines per 1,000 code lines in Linux's architecture directories | x86 0.8; arm64 0.7; arm 0.5; powerpc 0.4; mips 0.3; m68k 0.1; riscv 0.1; s390 0.0 | appendix F |
| Hardware-erratum options in Linux's configuration | arm64 64; arm 32; riscv 14 | appendix F |

The code-size row compares the pdp64's portable C compiler with clang for the others, on the files each compiled (840 or 841), so it measures compilers as well as instruction sets (`encoding-work/arch-comparison.md`, section 5). The flag figures are for the first compiler's output on 827 files (`pdp64-ooo-readiness.md`).

*Commentary.* **Chain.** The view that instruction sets are equivalent has real support. Published comparisons of x86 and ARM implementations (the 2013 study usually cited is "Power Struggles: Revisiting the RISC vs. CISC Debate on Contemporary ARM and x86 Architectures", a citation not verified) found that at the same performance level the instruction set explains little of the difference in power or speed, and the very large cores of both families have converged. The pdp64 does not dispute that. **Trade-offs.** The claim is about steady-state performance of comparable large cores, and the table is about other costs. The Linux figures are measurements of real software, not controlled experiments: part of the difference between architectures is age and deployment (x86 is the oldest and most widely deployed), and the start-up and line-count figures are counts of what is written, not run times. They show that the instruction set goes with these costs, and the chapters show the mechanism in each case. **Impact.** *Kernel:* fewer special cases to write and test. *Compiler:* fewer rules for the code generator. *Hardware:* a smaller decoder and a smaller verification effort, because what an instruction may leave behind is fixed by the architecture (precise exceptions, ordering, flag behaviour, length, restart). RISC-V's own case for a clean base and x86's survival by microarchitecture are the two sides of the argument.

## 1.8 How the encoding was chosen

You know the PDP-11 instruction word: four bits of operation and two six-bit operand fields, each a three-bit mode and a three-bit register. The pdp64's encoding starts from a different idea, shown here.

![One instruction word of the PDP-11 and of the pdp64](figures/intro-words.svg)

How a decoder finds where the next instruction starts, for each:

```
# PDP-11: the length depends on both operand fields (handbook 3.3.4 and 3.5)
length(word):
    n = 2
    for each operand field f of the word:        # none, one or two of them
        if f.mode is 6 or 7: n += 2              # index: a word follows
        if f.mode is 2 or 3 and f.reg is 7: n += 2   # immediate or absolute: a word follows
    return n

# pdp64: the length depends on the first 16 bits only
length(parcel):
    leaf = the one leaf whose prefix (3 to 16 bits) begins parcel
    return 2 * leaf.parcels                      # 1, 2 or 3 parcels (5 for the 64-bit literal move)
```

**1.8.1** The pdp64 has thirty-two registers and an instruction encoded by a prefix code over the first parcel (a parcel is 16 bits; a prefix code is a set of bit patterns none of which begins another, so the first bits of an instruction tell the decoder what it is and how long), with 5-bit register fields in the two-parcel forms. *(D)*

**1.8.2** Two earlier iterations were built and measured against it and were superseded: pdp64/r20 (the original: sixteen registers, a first parcel of `len`, opcode, `reg` and `low`) and pdp64/16 (sixteen registers, a prefix code). They are no longer CPUs and have no manuals. They shared with the pdp64 the roles of the registers, the memory model, the exception mechanism, the page tables, the bus and the devices, the calling convention and the assembly language, and differed in how an instruction is encoded and in the size of the register file. The record of the comparison is in [`encoding-work/`](../encoding-work/) and the last commit that carries their manuals is the git tag `pre-single-cpu`. *(D)*

**1.8.3** The encoding was chosen for performance, by testing the three on the same programs. Over six programs (lz4, zlib, Lua and three BearSSL kernels) compiled for each and run on the simulator, the pdp64 executes 572,801,956 instructions against 609,755,229 for pdp64/16 and 755,816,022 for pdp64/r20 (the original compiler for the latter); its frame loads and stores fall to 24,276,195 against 65,203,703 and 68,936,548; and on the in-order timing model (an ideal memory, no branch predictor, issue width 1 or 2) its cycle counts are 22.5 to 28.1% below pdp64/r20's across fetch windows of 2 to 16 bytes and 6.9 to 8.5% below pdp64/16's with a window of 4 bytes or more (the model is a check of the pipeline it states, not hardware). Its code is larger than pdp64/16's: 3.18% in instruction bytes over the 841-file corpus and 2.92% in bytes fetched over the six programs. *(measured; the record is [`encoding-work/integration.md`](../encoding-work/integration.md), section 4)*

*Commentary.* **Chain.** PDP-11: one length rule that reads both operand fields (shown above). VAX: every operand specifier in order, with no bound on the length. x86: prefixes, opcode, ModR/M and SIB read one after another (*unverified*). The pdp64: a prefix over the first parcel, which is the length-first idea of UTF-8 that the author cited on 2026-08-30 (R29: "utf8 showed the way encoding can be done"; that the prefix code descends from it is an *inference*). **Trade-offs.** The prefix code makes the decoder read up to 16 bits to find the length, and it costs a little code size against the 16-register prefix code; the measurements above are what it buys. **Impact.** *Kernel:* the system architecture does not depend on the encoding. *Compiler:* one back end. *Hardware:* one decoder and one register file.
