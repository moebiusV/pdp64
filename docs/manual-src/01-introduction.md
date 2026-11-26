# {{c:id01001|n}}. Introduction

[← manual index](00-index.md)

**The pdp64 is a 64-bit computer architecture in the PDP-11 line: one CPU, with thirty-two 64-bit registers and instructions of two, four or six bytes, that reaches everything outside itself over PCI Express, where the standard disk, network card, display and sound device are virtio devices (one standard interface, with one driver routine for every kind of device).** It keeps what made the PDP-11 pleasant to program: devices that are memory locations, a stack pointer that is an ordinary register, autoincrement addressing, a small set of regular rules. It changes what fifty years of machines and compilers showed to be a mistake or a missing piece. The manual is written for a first-year computer-science student or an experienced PDP-11 assembly programmer, and assumes that neither knows anything that happened in computer architecture after the 1970s.

This chapter has three jobs. It says what the machine is and how to read the manual ({{r:what-the-pdp64-is}}, {{r:who-the-manual-is-for}}). It puts the road from the PDP-11 to the pdp64 in one table, with my own account of where the design began ({{r:road-from-the-pdp-11}}). And it states the principles the design follows and the measurements that back them ({{r:what-made-the-pdp-machines-good}} to {{r:how-the-encoding-was-chosen}}). After {{r:road-from-the-pdp-11}} the chapters can be read in any order: each starts from what a PDP-11 programmer knows of its subject.

## {{#what-the-pdp64-is}} What the pdp64 is

If you have programmed a PDP-11 you know a machine with eight 16-bit registers (R6 the stack pointer, R7 the program counter), a 64 KB address, devices at addresses near the top of the Unibus address space, and one processor. The pdp64 is that machine grown up in each respect, and the figure shows what surrounds the processor.

![{{#fig-pdp64-as-a-system}}The pdp64 as a system](figures/intro-machine.svg)

**{{#pdp64-is-a-little-endian}}** The pdp64 is a little-endian machine with thirty-two 64-bit general registers, `R0` to `R31`; `R14` is the stack pointer and the program counter is not a register. An instruction is two, four or six bytes long (ten for the one instruction that carries a 64-bit constant), and its first 16 bits fix what it is and how long it is (chapter {{c:id01009|n}}).

**{{#program-uses-virtual-addresses}}** A program uses virtual addresses of 39, 48 or 57 bits, according to a page table of three, four or five levels, and the number is discoverable at run time; a physical address is 40 to 64 bits wide ({{r:from-segments-to-pages-virtual-memory}}). The PDP-11 had 16 bits of virtual address and 18 or 22 of physical.

**{{#there-is-one-cpu-architecture}}** There is one CPU architecture and one manual. Two earlier designs were built and measured against it and are history ({{r:how-the-encoding-was-chosen}}).

**{{#machine-has-several-cores-from}}** The machine has several cores from the start: at least four, with sixteen or more as the ceiling that no decision may preclude; all cores see one memory, which is sequentially consistent (chapter {{c:id01007|n}}).

**{{#processor-has-no-input-or}}** The processor has no input or output instructions: a device is a few memory locations that ordinary loads and stores reach, as on the PDP-11. The bus is PCI Express, so an ordinary PCI Express card works on it unchanged; the standard devices are virtio devices (the disk is virtio-blk) and USB controllers, and the kernel finds them by enumeration, not by switch settings (chapters {{c:id01002|n}} and {{c:id01005|n}}).

*Commentary.* **Chain.** The PDP-11 had 16-bit words and no step beyond. The VAX-11 widened it to 32 bits ({{r:what-made-the-pdp-machines-good}}). My choice, on 2026-08-30, was to skip the 32-bit step: "let's skip 32 bit version and go straight to 64bit" and "basically upgrade pdp-11 straight to 64 bit". **Trade-off.** Eight 16-bit registers become thirty-two 64-bit ones, so a register number needs five bits instead of three, and the instruction encoding changes with it ({{r:how-the-encoding-was-chosen}}). **Impact.** *Kernel:* the status word, vectors and modes stay recognisable (chapter {{c:id01006|n}}). *Compiler:* 64-bit integers and pointers are one register each. *Hardware:* one register file, one ALU width.

## {{#who-the-manual-is-for}} Who the manual is for, and how to read it

You know the PDP-11, or you are learning computing from the start. Either way the manual assumes you have met nothing invented after the 1970s: not the PCI bus, the tree of page tables, the out-of-order core, the GPU or virtio.

**{{#manual-is-written-for-two}}** The manual is written for two readers: a first-year computer-science student and an experienced PDP-11 assembly programmer. Neither is assumed to know anything of computer architecture that came after the 1970s, so every later idea is explained where it first appears.

**{{#term-is-defined-where}}** A term is defined where it first appears, as the technical word followed by a plain restatement: a prefix code (a set of bit patterns none of which begins another, so the first bits of an instruction tell the decoder what it is). In the figures a box is a piece of memory or a register and an arrow is an address stored in it, as a textbook draws a linked list. Code blocks are pseudocode (C-like, with `#` starting a comment) unless the text says they are PDP-11 or pdp64 assembly.

**{{#pdp-11-material-is-quoted}}** The PDP-11 material is quoted from the Unix Version 6 and 7 and 2.11BSD sources and from the PDP-11/70 handbook; the pdp64 listings are illustrations written for the manual and are not part of the architecture. A fact about another machine that could not be checked against a source on hand is marked *unverified*.

**{{#chapter-that-has-a-history}}** A chapter that has a history starts from the PDP-11 way, names the machines that came between with the one thing each added, and ends at the pdp64 way with the reason; these are the paragraphs headed **Chain**. The commentary under a decision also gives the **Trade-off** it makes and its **Impact** on an efficient kernel, on efficient compilation and on an efficient hardware layout.

**{{#numbered-statement-is-a-rule}}** A numbered statement such as {{r:there-are-thirty-two-64}} is a rule of the architecture and states it as it is to be. A figure marked (estimated) is an estimate, not a measurement, and one marked *(measured)* was measured, with its source.

**{{#chapters-state-the-architecture}}** The chapters state the architecture as it is to be. The design notes (proposals, deferred items, open questions, the history) are kept in the repository outside the manual, in `docs/design/`.

The chapters, and what a PDP-11 programmer brings to each:

| Chapter | What it covers | The PDP-11 starting point |
|---|---|---|
| 2 The bus | PCI Express, virtio, interrupts that are writes, the IOMMU | the Unibus and its registers |
| 3 Graphics | the terminal, HDMI, audio, windows | the teletype, then the Blit and the Commodore 64 |
| 4 Boot | the first block, the second stage, the other cores | the front panel and the boot ROM |
| 5 Drivers | the virtio transport, class drivers, interrupts and DMA | `rk.c` and the `bdevsw` table |
| 6 The kernel | modes, exceptions, page tables, system calls | the V7 kernel: `trap()`, the KT11, `mfpi` |
| 7 Multiple processors | memory model, atomics, per-core state, translation coherence | one processor and `spl()` |
| 8 Vector work | a standard vector and accelerator engine on the bus, a standard part like the FPU and the MMU, for neural networks and array languages | no vector unit; the FP11 for floating point |
| 9 The instruction set | formats, modes, every instruction | the PDP-11 instruction set |
| 10 Conclusion | the finish line, the security aims | |

The instruction reference tables, with a chart of every instruction's bit layout, sit beside chapter {{c:id01009|n}}. The appendices are: A, improvements I approved and has yet to specify; B, the glossary; C, the application binary interface (how compiled code, the linker and the operating system agree); D, the assembly language and the object format; E, the evidence documents.

## {{#road-from-the-pdp-11}} The road from the PDP-11

The PDP-11 programmer's first question is which of what he knows still holds. The table answers it row by row; the commentary after it says where each row's history is told.

**{{#pdp-11-and-the-vax}}** The PDP-11 and the VAX-11 were pleasant, even fun, to program in assembly language; afterward computer design went in many directions and that pleasure was largely lost. The pdp64 carries it forward with the lessons of the last fifty years: which instructions are needed to get things done and which are not, what a processor is used for and which instructions it needs the most, to have "less possibility for error, fewer footguns, fewer surprises" and "the most bang for buck".

**{{#design-began-as-a-pdp}}** The design began as a PDP-11 brought up to date by a little, and grew by decisions that each answered a question. My account (2026-11-10): "we started off as a pdp16 modernized a tiny bit, then got more and more ambitious", and "the initial idea was, could a pdp16 run effectively today with a blit terminal and off-loaded 8-register nic", with "the blit being a mashup with the c64 for audio". In my usage a pdp16 is a 16-bit machine of the PDP-11 line (*inference*: "pdp64 is an extension of pdp16"); the Blit is the Bell Labs bitmap terminal ({{r:blit-a-bitmap-and-the-blit}}); an off-loaded network card is one that carries out the network protocols itself, so that the processor only hands it data.

**{{#first-design-brief-2026-08}}** The first design brief (2026-08-29) was "use pdp-11 as the base, fold in the good parts of c64", "taking the best isa/architecture and improving it with the good stuff of the other one". The steps that shaped this chapter are the 64-bit step ({{r:what-the-pdp64-is}}), the little-endian rule ("none of this middle endian stuff"), the bus (PCI Express; virtio across the board), several cores and the priorities of {{r:principles}}. The "off-loaded 8-register nic" of the first idea was replaced by virtio devices.

The figure gives the road in three tracks, the processor, the bus and the terminal, each from the PDP-11 to the pdp64 through the steps between; the table that follows gives the same road row by row.

![{{#fig-road-from-the-pdp-11}}The road from the PDP-11 in three tracks](figures/intro-road.svg)

| What | The PDP-11 | The pdp64 | Why | Where |
|---|---|---|---|---|
| Registers | eight visible at a time, of 16 bits; R6 stack pointer, R7 program counter (11/70 handbook 1.4) | thirty-two of 64 bits; `R14` stack pointer; the program counter is not a register and `R7` is ordinary (*D*) | 64-bit data; on the programs measured, 32 registers cut the frame loads and stores executed from 65.2 to 24.3 million against 16 ({{r:encoding-was-chosen-for-performance}}); a write to a register never jumps | {{r:state-registers-and-flags}} |
| Byte order | little-endian words; a 32-bit long is two words, high word first (*inference*, V7 `l3.c`) | little-endian throughout, no middle-endian long | one rule for every width | {{r:instruction-format}} |
| Instruction length | 2, 4 or 6 bytes: one word, plus one for each operand that has an index, an immediate or an address (handbook 3.2, 3.5) | 2, 4 or 6 bytes; the first 16 bits alone fix the length (*D*) | a decoder that must read one operand after another to know where the next instruction starts is slow | {{r:how-the-opcode-space-is-divided}}, {{r:instruction-format}} |
| Operands | two, each any addressing mode, so memory to memory | at most one memory operand; the other is a register (*D*) | only one operand can fault, so restart is simple; 5-bit registers and 12-bit displacements fit in four bytes | {{r:properties-and-principles}}, {{r:faults-and-restart-what-precise-means}} |
| Addressing | eight modes with a deferred (indirect) form of each; autoincrement and autodecrement; index with a following word | autoincrement and autodecrement kept, with a stride; base plus displacement, scaled index, PC-relative, direct page, immediate, absolute; deferred forms removed (*D*) | a deferred mode is a second memory reference inside one operand | {{r:addressing-modes}} |
| Flags | N, Z, V, C written by most instructions | the same four; moves, loads, stores and compare-and-branch write none; no instruction writes part of N, Z, V (*D*) | with the PDP-11 rule 68.2% of compiled instructions wrote a flag and 1.5% read one; flags are what blocks a fast implementation ({{r:architecture-is-designed-to-be}}) | {{r:flags-form-two-groups-c}} |
| Branches | conditional branch with an 8-bit word offset, reach 256 bytes | 14 conditions; the field grows with the length: about 64 to 512 bytes, 64 KiB, 4 GiB; compare-and-branch; subtract-one-and-branch both ways | long jumps needed a trampoline | {{r:branches-and-control-flow}} |
| Calls | `JSR Rn` keeps the return address in a register of the caller's choosing | `CALL` pushes it on the stack: no link register; `PUSHM` and `POPM` save a set of registers (*D*) | every unwinder and debugger expects the return address on the stack | {{r:branches-and-control-flow}}, {{r:idioms-restored-lost-and-replaced}} |
| Devices | registers at fixed addresses set by switches on the card; vectors on the data lines | still memory locations, no input or output instructions; found by enumeration; one virtio interface | one driver routine serves every device | 2, 5 |
| Interrupts and traps | a vector pair (new PC, new PS) in low memory; the old PS and PC are pushed on the kernel stack | vectors and a three-bit priority kept; entry writes the old state into registers and cannot fault | the push could fault; the PDP-11 needed a journal to undo it | {{r:exceptions-interrupts-and-traps}}, {{r:faults-and-restart-what-precise-means}} |
| Memory management | the KT11: eight segments of up to 8 KB for each mode, base and length; swapping whole images | page tables of three, four or five levels; a translation buffer with address-space numbers | pages are handed out singly and need no contiguous memory | {{r:from-segments-to-pages-virtual-memory}} to {{r:accessed-dirty-tlb-and-asids}} |
| Modes | kernel, supervisor, user; a stack pointer for each | kept (*D*) | the PDP-11 arrangement was already right | {{r:modes-and-the-status-word}} |
| Floating point | the FP11 with mode bits for double precision, long integers and truncation | IEEE 754 single and double precision in the general registers, with a fused multiply-add, and conversions to and from half precision; no mode bits (*D*) | one result format, no hidden state | {{r:floating-point}} |
| Processors | one; the V7 kernel guards itself by raising the priority (`spl`) | several cores, sequentially consistent memory, atomics (*D*) | a second core must be easy to add | 7 |
| Boot | a ROM reads one block from the disk and jumps to it | the same (*D*) | it is small and every stage after it is ordinary software | 4 |
| Terminal | a teletype, then video terminals with escape codes | text and graphics set by simple stores, in the spirit of the Blit and the Commodore 64 | I based the design on both machines | 3 |

**{{#pdp-11-is-a-source}}** The PDP-11 is a source, not an obligation: what earned its place is kept, what did not is dropped, and what fifty years showed to be missing is added.

*Commentary.* **Chain.** Each row has its history in the chapter named: the instruction set in {{r:what-made-the-pdp-machines-good}} and {{r:more-minimal-than-its-ancestors}}, the bus in section {{r:bus-what-you-already-know}} (the Unibus, the Q-bus, the VAX interconnect, PCI, PCI Express, virtio), the terminal in {{r:teletype-one-line-at-a-time}} to {{r:pc-years-vga-svga-vesa}} (the teletype, the VT52, the Blit, the Commodore 64, VGA), boot in {{r:boot-what-you-already-know}} and {{r:boot-what-came-between}}, drivers in {{r:drivers-what-you-already-know}} and {{r:drivers-what-came-between}}, the kernel in {{r:kernel-what-you-already-know}}. The machines I named first, in the order of my messages, are the Blit, the VAX instruction set and the DEC Alpha, the Unibus and Q-bus against PCI (all 2026-08-23); the Commodore 64 with its SID sound chip, USB and NVMe, V7 Unix as the software base, the 6502 family and IEEE 754 floating point (2026-08-29); x86 and UTF-8's length-first coding (2026-08-30). **Trade-off.** The table lists what changed, and a change has a price: a load and a store where the PDP-11 had one memory-to-memory `mov`, a longer encoding for a deferred access, no compact `JSR Rn` for coroutines. {{r:idioms-restored-lost-and-replaced}} lists the idioms restored, lost and replaced. **Impact.** *Kernel:* chapters {{c:id01004|n}} to {{c:id01007|n}} follow the V7 kernel's order. *Compiler:* a register-to-register core with one memory operand, as a RISC compiler expects, and the PDP-11's addressing for the loops that want it. *Hardware:* a decoder that finds the length from a prefix and no microcode.

## {{#what-made-the-pdp-machines-good}} What made the PDP-10, the PDP-11 and the VAX-11 good to program

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

Three differences. The register is 64 bits and the store is 8 bytes, so each trip clears four times as much. `clr` is four bytes, because a memory operand with a post-increment needs a 12-bit stride field and a 5-bit register field (the leaf `SOF.PI12` of the grammar); `cmp` and `blo` are two bytes each here, because `r0` and `sp` are among the hot registers that a one-parcel form can name ({{r:one-parcel-form-register-index}}), so the loop is eight bytes where the PDP-11's is six. And a compare-and-branch, `cblo r0, sp, 1b`, can take the place of the last two (four bytes, no flags written).

**{{#pdp-10-gave-a-programmer}}** The PDP-10 gave a programmer one word per instruction that said everything: the operation, the register, the index register, the indirect bit and the address. *(unverified)*

**{{#pdp-10-registers-were}}** The PDP-10's registers were also memory: the sixteen accumulators answered to the addresses 0 to 15. *(unverified)*

**{{#pdp-10-had-half-word}}** The PDP-10 had half-word and byte operations, stack and skip instructions, and a procedure call that was one instruction (`PUSHJ`). *(unverified)*

**{{#pdp-11-made-every-addressing}}** The PDP-11 made every addressing mode available with every register, so that the language had few exceptions to remember (11/70 handbook, chapter 3: the general registers can be used as accumulators, pointers, stepping pointers and index registers).

**{{#pdp-11-program-counter}}** The PDP-11's program counter and stack pointer were ordinary registers (R7 and R6), and its autoincrement and autodecrement modes made `*p++` and `*--p` single instructions.

**{{#pdp-11-had-no-input}}** The PDP-11 had no input or output instructions: a device was a few memory locations, and a driver was an ordinary program.

**{{#vax-11-widened-the-pdp}}** The VAX-11 widened the PDP-11 to 32 bits and added three-operand arithmetic, a complete virtual-memory system, and instructions for the jobs programs actually do: procedure calls (`CALLS`), queues (`INSQUE`), character strings (`MOVC3`), array indexing (`INDEX`) and polynomial evaluation (`POLY`). (VAX architecture handbook, EK-VAXAR-RM-001)

*Commentary.* **Chain.** The PDP-10's simplicity of format and its habit of making the machine's own state addressable ({{r:pdp-10-gave-a-programmer}}, {{r:pdp-10-registers-were}}) are the origin of the idea that the machine should hold together in the head; the PDP-10 handbooks are not on this machine, so {{r:pdp-10-gave-a-programmer}} to {{r:pdp-10-had-half-word}} are general knowledge and unverified. The PDP-11's regularity ({{r:pdp-11-made-every-addressing}}) is what mattered most to assembly programmers and later to compiler writers: an instruction that takes a register takes an address, an immediate or a stack slot with the same syntax. Its memory-mapped devices ({{r:pdp-11-had-no-input}}) are the reason the pdp64's devices are still memory locations in the one address space (chapters {{c:id01002|n}} and {{c:id01005|n}}). The VAX-11's richness ({{r:vax-11-widened-the-pdp}}) bought programmability and cost hidden state in its longest instructions: a page fault in the middle of a character move could not be resumed without a bit in the status word, the "first part done" bit (`PSL_FPD`, 0x08000000, in 4.3BSD `psl.h`), which tells the microcode that the instruction is half done. The Motorola 68000 took the PDP-11's regularity and widened it, and could not restart an instruction after a bus error, so it could not support demand-paged virtual memory (memory fetched from disk when first touched) until its successor, the 68010, patched the fault model (both *unverified* here; the project's instruction-set text, section 10, records them). **Trade-offs.** Each of these qualities had a price that a later machine paid: the PDP-11's regularity a decoder that must read both operand fields to find an instruction's length ({{r:how-the-encoding-was-chosen}}), the VAX's richness hidden state in its longest instructions, the 68000's the lost restart. **Improvements.** The pdp64 keeps what made programming pleasant and removes what made implementation hard: no hidden instruction state (a vector block has some, and restarts from its entry), so every instruction can be restarted ({{r:every-instruction-can-be-restarted}}); at most one memory operand ({{r:at-most-one-memory-operand}}); a small fixed maximum instruction length ({{r:no-instruction-is-longer-than}}); and no mode bits that change what unrelated instructions mean unless the benefit outweighs the cost ({{r:between-two-designs-that-both}}). **Modern comparables.** x86-64 kept memory operands and a variable-length encoding. AArch64 has one length, 4 bytes (4.000 bytes an instruction on the 840 files that clang compiled, {{r:does-the-instruction-set-matter}}), and RISC-V has a 4-byte base with an optional 2-byte compressed form (2.93 bytes an instruction at `-Os` with it). The pdp64 sits between: closer to x86 in the form of its instructions and closer to RISC-V in the discipline of its encoding (`encoding-work/arch-comparison.md`, section 5).

## {{#more-minimal-than-its-ancestors}} More minimal than its ancestors, where hindsight allows

The PDP-11 was orthogonal (any operation with any addressing mode on any register), and the VAX carried that to completeness: every operation in every data type, with up to six operands, each of any mode.

**{{#several-ways-the-pdp64}}** In several ways the pdp64 is more minimal than the PDP-11 and the VAX-11: it gives up theoretical completeness where fifty years of use showed the completeness was never exercised, and spends what that saves on power that was (I said on 2026-10-23: "in hindsight, in some ways, we are even more minimal than the vax and pdp11; hindsight let us know which theoretical completeness we could trade for more power").

**{{#not-every-instruction-works}}** Not every instruction works with every addressing mode on every operand: at most one operand of an instruction is a memory reference.

**{{#deferred-addressing-modes-are-gone}}** The deferred addressing modes are gone; an indirection is a `JMPI`, a `CALLI` or an ordinary load.

**{{#alu-has-one-width-there}}** The ALU has one width, there is no arithmetic in the narrow sizes, and there is no conversion opcode group: conversions are moves.

**{{#there-is-one-rotate-direction}}** There is one rotate direction, and no slot exists only to complete a table.

**{{#vax-packed-decimal-string}}** The VAX's packed decimal, string editing and `CALLS` and `CALLG` procedure-call instructions are absent.

**{{#there-are-no-transcendental-instructions}}** There are no transcendental instructions, no separate floating-point register file and no rounding-mode bits.

**{{#what-the-saving-buys}}** What the saving buys is power that programs use: a bit unit (population count, count of leading and trailing zeros, byte reversal, bitfields, a carry-less multiply), block operations that restart from their registers, a fused multiply-add with the IEEE exception flags, the full set of atomics, UTF-8 instructions, and a user-memory guard.

*Commentary.* **Chain.** The completeness of the PDP-11 and the VAX made assembly programming regular and a compiler's job simple, and it was designed when memory was dear and compilers weak. It was never free. It bought a decoder that must parse specifier after specifier before the next instruction's address is known, and instructions that could fault in the middle with unbounded state to save ({{r:what-made-the-pdp-machines-good}}). What hindsight lets the pdp64 do is separate the two benefits: keep the regularity that programmers and compilers use (every register is general, every mode means the same wherever it is allowed) and drop the completeness that nobody exercised (a memory-to-memory arithmetic instruction, a deferred mode on every operand, a sized version of every operation). The RISC machines of the 1980s went further and made every instruction register to register except loads and stores; x86 kept one memory operand and has survived on it; the pdp64 takes the middle position. **Trade-offs.** The price is a few more instructions in rare cases, such as a load and a store where the VAX had a memory-to-memory move (`MCPY` covers the block case). Measurements that bear on what was dropped: a signed multiply and an unsigned multiply have the same low 64 bits, so a second multiply would duplicate the first, while the instruction that returns the high half is the one multi-precision arithmetic needs; a carry-less multiply is the primitive beneath every CRC, so no CRC instruction exists; in the first compiler's output on 827 files the multiply is 2,204 of about 370,000 instructions (0.6%) and the four divide instructions together 235 (0.06%) (`codegen-analysis.md`; the rejected features are in `pdp64-isa.md`, section 11). **Improvements.** Each piece of dropped completeness was weighed against what it freed: the one memory operand leaves an undo buffer of one entry and a fault matrix whose third row, an operand write, can never fault ({{r:faults-and-restart-what-precise-means}}), and it pays for thirty-two registers and a 12-bit displacement in four bytes; dropping the sized ALU removes byte-lane multiplexing and partial-register writes altogether; dropping the transcendentals leaves the multiply-add datapath, which accurate library mathematics is built from. **Impact.** *Kernel:* no instruction can leave half its work done, so the fault handler needs no journal. *Compiler:* instruction selection is register allocation with one memory operand, as on a RISC. *Hardware:* a small decoder, small exception machinery, and the area that completeness would have used goes to the bit unit, the block-move sequencer and the UTF-8 decoder, together under 7% of the core's estimated 92,000 transistors ({{r:chip-a-transistor-budget}}).

## {{#principles}} The principles

You know the PDP-11's one rule, that any instruction takes any operand in any mode. The pdp64 has several rules, ranked, and each can be broken for a reason.

**{{#design-follows-these-priorities}}** The design follows these priorities, in this order: **security and safety**, meaning errors that can never arise, then errors that are easy to detect, then errors that are cheap to recover from (restart and recovery go together, and an instruction does what its name says and nothing else); **opcode choice**, so that fewer instructions executed means fewer memory fetches; **opcode encoding**, dense, with rare instructions in longer encodings; **speed and power**, served by a low gate count; a **good compiler target**; and **pleasant in assembler**.

**{{#all-the-rules-are-soft}}** All the rules are soft rules: a rule gives way when breaking it is worth more than it costs, with the cost written down ("all the rules are soft rules").

**{{#between-two-designs-that-both}}** Between two designs that both work, prefer by this order: the one with no strange side effects (an instruction does what its name says and nothing else); the one that does not push an existing instruction into a longer encoding. Beside the ranking, at every level, do not multiply entities without benefit. Mode bits are decided case by case: by default a mode is visible state, and a bit in a register that is saved anyway costs nothing extra.

**{{#architecture-is-designed-to-be}}** The architecture is designed to be efficient with in-order and out-of-order implementations ("designed to be efficient with in-order and out-of-order execution implementations"). An in-order core runs instructions one after another in the order written. An out-of-order core runs whichever are ready, and makes the result look as if they had run in order. The first implementations are in order; nothing is specified in a way that is safe only because the core does not speculate or reorder, and nothing is specified that an out-of-order core could implement only at a large cost.

**{{#instruction-is-judged}}** An instruction is judged by its weight in the loops where it is used, not by how often it appears: a rarely used instruction that sits inside a critical, tight hot loop can earn its place. The measure is profile-weighted (executions multiplied by the instructions and bytes it saves), not a static count.

*Commentary.* **Chain.** The PDP-11's rule was regularity ({{r:what-made-the-pdp-machines-good}}) and the VAX's completeness ({{r:more-minimal-than-its-ancestors}}); the handbooks on this machine state no ranking of goals (*inference*: none was found in them). Most architectures since have stated none either (*unverified*); the nearest in spirit is RISC-V's published rule of a small base and optional extensions (*unverified*). **Trade-offs.** The priorities agree on almost everything, because a small, regular machine is also compact in code and cheap in gates; the stated order decides which wins when they conflict. Error prevention, detection and recovery is the principle that most often changes a decision. It means counting an option's cost not only in gates and bytes but in the code a kernel must write to handle its failures: a feature that adds a fault, an error return or a half-finished state costs recovery code in every system that uses it, and a feature that makes an operation repeatable from the start costs none. **Improvements.** The soft-rules principle covers the two strongest defaults, "no mode bits" and "natural alignment of quad accesses"; breaking either is weighed like any other choice. Four bits of the design were accepted on those terms: the translation-enable bit that is set once at boot, the user-memory guard in the status word, the data-independent-timing bit `DIT`, and the sticky floating-point flags, which never change what an instruction does. The priority list is written with the soft-rule test and the hot-loop weight as standing constraints, not ranks (the priority lists, `docs/priority-lists.md`). **Impact.** *Kernel:* a restartable instruction needs no recovery code. *Compiler:* weight by use steers the compiler's register use and the fused pairs ({{r:idioms-restored-lost-and-replaced}}). *Hardware:* the out-of-order constraint is why the flags are written as in {{r:flags-form-two-groups-c}} and why `CBCC` writes none.

## {{#does-the-instruction-set-matter}} Does the instruction set matter?

You may have heard that a good implementation hides the instruction set. I wrote this section for a reader who holds that view.

**{{#instruction-set-is-not-interchangeable}}** The instruction set is not interchangeable with any other: it fixes what every implementation must preserve, and so what a processor costs to build, to verify, to program and to secure.

**{{#common-view-that-a-good}}** The common view, that a good implementation hides the instruction set, is true of one thing: the peak speed of a very large core, where a great deal of hardware can absorb almost any encoding.

**{{#not-true-of-the-cost}}** It is not true of the cost of a small core, the size of the code, the amount of software a system needs, or the number of ways a system can fail; those follow the instruction set, and they can be measured.

**{{#each-of-the-rows-below}}** Each of the rows below is a measurement or an estimate, and each is explained in the chapter named beside it.

| What differs | The figure | Where |
|---|---|---|
| The logic of a complete implementation, same company and era | the PDP-11's T-11, a full integer core without memory management or floating point, about 12,000 transistors; the J-11, the full PDP-11/70 with both, about 120,000; the MicroVAX 78032, a subset of the VAX with no floating point, about 125,000 (all *unverified*) | {{r:chip-a-transistor-budget}} |
| What it takes to find where the next instruction starts | pdp64: a prefix of 3 to 16 bits of the first parcel; PDP-11: both operand specifiers; VAX: every specifier in order; x86: prefixes, opcode, ModR/M and SIB in sequence (*unverified*) | {{r:how-the-opcode-space-is-divided}}, {{r:instruction-format}} |
| Whether flags block a faster implementation | with the PDP-11 rule 68.2% of compiled instructions wrote a flag and 1.5% read one (229,389 and 4,999 of 336,408); with the pdp64's rules 16.7% write one, at a measured cost of 0.39% in code size | {{r:flags-form-two-groups-c}}, {{r:architecture-is-designed-to-be}} |
| Size of compiled code | 964,158 bytes of instructions on the 841-file corpus; clang `-Os` is 1.21 times that for x86-64, 1.34 for AArch64, 1.22 for RV64GC and 0.91 for Thumb-2; counting the pdp64's constant pools too, x86-64 and RV64GC are 0.97 and 0.98 times | {{r:measured-on-the-841-file}}, {{r:encoding-the-measurements}} |
| Lines of kernel code to start a second core (Linux) | x86: 1,528 plus 1,258 of real-mode code; arm64: 124 (PSCI) or 127 (spin table); RISC-V: 108 or 58 | {{r:starting-the-other-cores}} |
| Machine-dependent code in an OpenBSD port | riscv64 35,600 lines; arm64 61,613; amd64 79,167 | {{r:finish-line}} |
| Errata, workaround and quirk lines per 1,000 code lines in Linux's architecture directories | x86 0.8; arm64 0.7; arm 0.5; powerpc 0.4; mips 0.3; m68k 0.1; riscv 0.1; s390 0.0 | appendix {{c:id03006|n}} |
| Hardware-erratum options in Linux's configuration | arm64 64; arm 32; riscv 14 | appendix {{c:id03006|n}} |

The code-size row compares the pdp64's portable C compiler with clang for the others, on the files each compiled (840 or 841), so it measures compilers as well as instruction sets (`encoding-work/arch-comparison.md`, section 5). The flag figures are for the first compiler's output on 827 files (`pdp64-ooo-readiness.md`).

*Commentary.* **Chain.** The view that instruction sets are equivalent has real support. Published comparisons of x86 and ARM implementations (the 2013 study usually cited is "Power Struggles: Revisiting the RISC vs. CISC Debate on Contemporary ARM and x86 Architectures", a citation not verified) found that at the same performance level the instruction set explains little of the difference in power or speed, and the very large cores of both families have converged. The pdp64 does not dispute that. **Trade-offs.** The claim is about steady-state performance of comparable large cores, and the table is about other costs. The Linux figures are measurements of real software, not controlled experiments: part of the difference between architectures is age and deployment (x86 is the oldest and most widely deployed), and the start-up and line-count figures are counts of what is written, not run times. They show that the instruction set goes with these costs, and the chapters show the mechanism in each case. **Impact.** *Kernel:* fewer special cases to write and test. *Compiler:* fewer rules for the code generator. *Hardware:* a smaller decoder and a smaller verification effort, because what an instruction may leave behind is fixed by the architecture (precise exceptions, ordering, flag behaviour, length, restart). RISC-V's own case for a clean base and x86's survival by microarchitecture are the two sides of the argument.

## {{#how-the-encoding-was-chosen}} How the encoding was chosen

You know the PDP-11 instruction word: four bits of operation and two six-bit operand fields, each a three-bit mode and a three-bit register. The pdp64's encoding starts from a different idea, shown here.

![{{#fig-one-instruction-word}}One instruction word of the PDP-11 and of the pdp64](figures/intro-words.svg)

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

**{{#pdp64-has-thirty-two-registers}}** The pdp64 has thirty-two registers and an instruction encoded by a prefix code over the first parcel (a parcel is 16 bits; a prefix code is a set of bit patterns none of which begins another, so the first bits of an instruction tell the decoder what it is and how long), with 5-bit register fields in the two-parcel forms.

**{{#two-earlier-iterations-were-built}}** Two earlier iterations were built and measured against it and were superseded: pdp64/r20 (the original: sixteen registers, a first parcel of `len`, opcode, `reg` and `low`) and pdp64/16 (sixteen registers, a prefix code). They are no longer CPUs and have no manuals. They shared with the pdp64 the roles of the registers, the memory model, the exception mechanism, the page tables, the bus and the devices, the calling convention and the assembly language, and differed in how an instruction is encoded and in the size of the register file. The record of the comparison is in [`encoding-work/`](../encoding-work/) and the last commit that carries their manuals is the git tag `pre-single-cpu`.

**{{#encoding-was-chosen-for-performance}}** The encoding was chosen for performance, by testing the three on the same programs. Over six programs (lz4, zlib, Lua and three BearSSL kernels) compiled for each and run on the simulator, the pdp64 executes 572,801,956 instructions against 609,755,229 for pdp64/16 and 755,816,022 for pdp64/r20 (the original compiler for the latter); its frame loads and stores fall to 24,276,195 against 65,203,703 and 68,936,548; and on the in-order timing model (an ideal memory, no branch predictor, issue width 1 or 2) its cycle counts are 22.5 to 28.1% below pdp64/r20's across fetch windows of 2 to 16 bytes and 6.9 to 8.5% below pdp64/16's with a window of 4 bytes or more (the model is a check of the pipeline it states, not hardware). Its code is larger than pdp64/16's: 3.18% in instruction bytes over the 841-file corpus and 2.92% in bytes fetched over the six programs. *(measured; the record is [`encoding-work/integration.md`](../encoding-work/integration.md), section 4)*

*Commentary.* **Chain.** PDP-11: one length rule that reads both operand fields (shown above). VAX: every operand specifier in order, with no bound on the length. x86: prefixes, opcode, ModR/M and SIB read one after another (*unverified*). The pdp64: a prefix over the first parcel, which is the length-first idea of UTF-8 that I cited on 2026-08-30 ("utf8 showed the way encoding can be done"; that the prefix code descends from it is an *inference*). **Trade-offs.** The prefix code makes the decoder read up to 16 bits to find the length, and it costs a little code size against the 16-register prefix code; the measurements above are what it buys. **Impact.** *Kernel:* the system architecture does not depend on the encoding. *Compiler:* one back end. *Hardware:* one decoder and one register file.
