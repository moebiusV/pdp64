# 9. The instruction set

[← manual index](00-index.md)

**The instruction set is built around one idea: the first parcel of an instruction says both what the instruction is and how long it is, so the commonest instructions are two bytes and nothing is longer than six, one literal excepted.** The chapter covers how the opcode space is divided into prefix-coded leaves, the properties and principles that hold throughout, the registers, the format and the addressing modes, each group of instructions, faults, restart and memory management, position-independent code, what is rejected, the idioms of the PDP-11 and VAX that are restored, lost or replaced and the idioms of the compiler, the comparison with the PDP-11 and VAX, what is taken from LoongArch, and what is open. Every instruction has its entry (syntax, bit-layout chart, operation, flags, exceptions) in the section of its group below; the atomic instructions are in section 7.12 and the system instructions in section 6.13; the [reference tables](dictionary/index.md) hold the aliases, the constants, the lists of mnemonics and the chart of every leaf. The grammars the tools are generated from are described in [`../../spec/README.md`](../../spec/README.md); every number here comes from them or from the measurements cited.

## 9.1 How the opcode space is divided

**9.1.1** Every instruction begins with a 16-bit parcel (the unit of instruction encoding), and the first parcel alone fixes what the instruction is and how long it is: its top 3 to 16 bits are a prefix, and the prefix selects a leaf. *(D)*

**9.1.2** A leaf is a group of mnemonics that share one form. A form lists the operand shapes (how each operand is written in assembly, and how many bits each part of it has); the leaf fixes where every field lies. After the prefix comes the sub-opcode, which selects one mnemonic of the leaf, and then the pieces of the operands: register fields from bit 0 of the first parcel upward, the last register operand lowest, displacements and immediates after them, the widest field last. No bit is padding. The encoding has 207 forms in 268 leaves.

**9.1.3** The prefixes form a prefix code (a set of bit strings none of which begins another, so that the first parcel matches at most one leaf and the match needs no look-ahead). The lengths were chosen by an optimiser that was given the compiled corpus, so the shortest prefixes belong to the forms the compiler emits most. *(D)*

**9.1.4** A leaf is one, two or three parcels long, which is two, four or six bytes; 36, 166 and 65 of the leaves are of those lengths. One leaf, `MOVQL`, is five parcels (ten bytes) because it carries a 64-bit literal. *(D)*

**9.1.5** 3,278 of the 65,536 patterns of a first parcel (5.0%) match no prefix and are illegal instructions; so is a sub-opcode that no mnemonic uses and a hot-register index beyond the table (9.4.6), so that a wild jump fails early and nothing is undefined.

**9.1.6** The assembly language and the mnemonics of the base specification are kept. The leaves add 54 words to them: the four fused pairs (`MOVCALL`, `POPRET`, `POPMRET`, `MOV2`), `MASKEQZ` and `MASKNEZ`, `BSEL`, `MOVQL`, the checked arithmetic `ADDV`, `SUBV` and `MULV`, the fourteen `TRAPCC` words, the deferred-fault and user-qualified moves (`.D` and `.U`, fourteen words), and the seven AES and eight SHA words. Each entry says what is still to be worked out.

*Commentary.* **Precedent.** The PDP-11 partitioned its opcodes by the addressing modes of the first word; the VAX by operand specifiers parsed in sequence; x86 by prefixes, opcode, ModR/M and SIB read one after another. The prefix code is the device of a Huffman code (the commonest symbols get the shortest strings) applied to the first parcel, with the length of the instruction as a by-product of the match. **Trade-offs.** The decoder reads up to 16 bits to find the length. In the timing model the decoder pays one cycle of length-decode latency on every taken branch and refill, and fetch-wait is 7.2% of the cycles at four bytes per cycle (1.7% for the first iteration's encoding, whose length was two bits, 1.8). What the prefix buys is density: on the 841-file corpus the new compiler's output is 11.04% smaller than the old compiler's output for the first encoding; the encoding alone, measured on the old compiler's code, was 6.48% smaller for an earlier prefix-coded iteration (1.8) and 9.66% smaller with the four fused pairs, and most of the saving in instructions executed is the compiler (appendix F, F.4). **Improvements.** Every bit is a prefix, sub-opcode or operand bit, so an unused code is an illegal instruction and not a silent no-op; the fields of every leaf come from the grammar, so no table is written twice. **Benefits.** The common operations, a register move, a load from the stack, a branch on a register against zero, cost two bytes with no look at a second parcel, and the rare ones are as long as they need to be. **Modern comparables.** Thumb-2 and RISC-V's compressed instructions mix 16- and 32-bit forms with the length in a few bits; x86 finds the length by parsing; the prefix code here is the general case of the first and avoids the second. **Impact.** *Kernel:* nothing in the kernel depends on the opcode map; a debugger and the fault handler's step-over read the same generated table as the assembler. *Compiler:* the cost model charges 2, 4 or 6 bytes (10 for `MOVQL`) and knows which operands fit a one-parcel form, the hot registers above all (9.4.6). *Hardware:* the length is a function of up to 16 bits of the first parcel, a lookup in the fetch path; a front end that decodes several instructions a cycle needs such a lookup at each parcel position, a cost that the timing model does not measure beyond the one cycle above.

## 9.2 Properties and principles

**9.2.1** The length of an instruction is a function of its first parcel alone: the prefix selects the leaf, and the leaf has 1, 2 or 3 parcels, for 2, 4 or 6 bytes. *(D)*

**9.2.2** At most one operand of an instruction may be a memory reference; the other, where present, is a register. The block operations are the one admitted exception. *(D)*

**9.2.3** No instruction is longer than six bytes, with one exception: `MOVQL` carries a 64-bit literal and is ten bytes, the literal not being counted as part of the instruction. *(D)*

**9.2.4** A register is always written in full: narrow loads sign- or zero-extend, and there is no partial-register write. *(D)*

**9.2.5** Anything that changes what an instruction means is, by default, visible state set by an instruction that names it, not hidden state; whether a mode bit is worth its cost is decided case by case (errata 83). Compatibility is by conversion instructions where that is cheap. *(D)*

**9.2.6** Every instruction can be restarted after a fault, and exceptions are precise; the machine has no hidden instruction state. *(D)*

**9.2.7** Floating point is done in the general registers; there is no separate floating-point register file. *(D)*

**9.2.8** Memory is sequentially consistent between processors. *(D)*

**9.2.9** The ALU has one width, 64 bits; sizes appear only on loads, stores and conversions. *(D)*

**9.2.10** Addresses are canonical: 39, 48 or 57 bits of virtual address, according to the three, four or five levels of the page table (6.6.1), and a physical address of 40 to 64 bits, 40 in the present implementation (2.3.5). *(D)*

**9.2.11** Instructions are aligned to two bytes; quad data accesses are naturally aligned, and the explicit unaligned forms exist for the cases that need them. *(D)*

**9.2.12** An instruction does what its name says and nothing else; no flag is set that its entry does not list. *(D)*

**9.2.13** Measured on the 841-file corpus of the compiler (instruction bytes, `as64 --stats`), the output of the new compiler is 964,158 bytes in 296,070 instructions (3.26 bytes an instruction), 11.04% fewer bytes than the old compiler's 1,083,870 for the first encoding (1.8); over six large programs it executes 24.21% fewer instructions and 28.94% fewer bytes than the same programs on the first encoding, an average of 2.934 bytes an executed instruction against 3.129. The fused pairs account for 19,786 instructions of the corpus. Linker relaxation (9.5.5) takes a further 3.76% off the text of the corpus. The tables and their provenance are in appendix F.

*Commentary.* **Precedent.** 9.2.2 is x86's ModR/M idea made architectural; it is also what lets the exception machinery be small (the PDP-11 recorded at most two register side effects per instruction because it had two specifiers; with one memory operand there is at most one). 9.2.6 exists because the Motorola 68000, which was very nearly this machine, could not restart an instruction after a bus error and so could not do demand paging until its successor retrofitted a fault model. 9.2.4 is the rule x86-64 adopted for 32-bit writes and failed to apply to the 8- and 16-bit forms. 9.2.7 is the arrangement RISC-V standardised as Zfinx. **Trade-offs.** 9.2.9 means narrow arithmetic is done wide and converted, which costs an extension instruction after some narrow operations. 9.2.8 is the cheapest model on a small in-order core and the most expensive on a large speculative one. 9.2.10 lets the page table have three levels, as RISC-V's Sv39 does, or four or five as x86-64, AArch64 and Sv48 and Sv57 do, at a longer walk for each level. **Improvements.** The rules are soft defaults: each says what it protects and what breaking it costs. **Benefits.** Together they make the machine small, restartable and easy for a compiler; the measured code size is in chapter 1. **Modern comparables.** AArch64 and RISC-V have fixed-length register-to-register encodings and weak memory models; x86-64 has memory operands and total store order; the pdp64 takes memory operands, strong ordering and a bounded fault surface. **Impact.** *Kernel:* Restartable instructions and precise exceptions mean a page-fault handler repairs the mapping and returns, with no instruction-specific cases, and sequential consistency means no barrier code. *Compiler:* One memory operand keeps instruction selection and register allocation simple; a register written in full removes partial-register merges; the single ALU width costs an extension instruction after some narrow arithmetic. *Hardware:* One address generator, at most one register side effect, a single-entry undo buffer, no byte-lane multiplexing and a length that is a lookup on one parcel are what keep the die small.

## 9.3 State: registers and flags

**9.3.1** There are thirty-two 64-bit general registers, `R0` to `R31`. `R14` is the stack pointer `SP`, with three copies (kernel, supervisor, user) chosen by the current mode; `R13` is the frame pointer by convention only; the others carry no meaning to the hardware. *(D)*

**9.3.2** The program counter is not a general register, and `R7` is an ordinary general register, not a view of the program counter; the program counter is read with `LEA 0(PC), Rn`. *(D)*

**9.3.3** The processor status word is 16 bits. *(D)*

![The processor status word](figures/psw.svg)

(Bit positions as in System v1: `C` 0, `V` 1, `Z` 2, `N` 3, `T` 4, priority 5-7, current mode 8-9, previous mode 10-11, `UA` 12.)

**9.3.4** The flags form two groups, `C` and `{N, Z, V}`, and no instruction writes part of `{N, Z, V}` or writes it conditionally. Moves, loads, stores and the compare-and-branch instructions write no flags; shifts write the same flags for every count; rotates and the funnel shift write none; the by-one left shift sets `V` to `N` xor `C`. *(D)*

**9.3.5** `DP`, the direct-page base, has three copies by mode. It makes `d(DP)` an address form that needs no base register (a 28-bit displacement in six bytes; the grammar has loads through `d(DP)` and no store); in kernel mode it is the per-CPU pointer, and in user mode the thread pointer. *(D)*

**9.3.6** Other special registers: `FPSR` (five sticky floating-point flags), `ASID`, `PTBR`, `DMW0` and `DMW1`, `EPC`, `EPSW`, `EVA`, `ECAUSE`, `VBR`, `MMUCTL`; the system registers are read and written by `MFSR` and `MTSR` with an 8-bit register number. *(D)*

**9.3.7** A bit `DIT` in the status word promises data-independent timing: while it is set no data-dependent timing effect of any kind remains, neither in instruction latency (divide, `MSCN`, `MCMP` and floating point included), nor in frequency or power management (a core that scales frequency holds it steady while the bit is set, or says in a feature register that it cannot), nor from any data-dependent prefetcher or value predictor (a core may have one, but it is off while the bit is set). User code may set it for its own use. *(D)* Open: the position of the bit in the status word, and which instructions take constant time while it is clear ([J.9.2](appendix-j-open.md#j92)).

**9.3.8** A register-save mask (`PUSHM`, `POPM`, `POPMRET`) names the registers by bit: bit n is `R`n, and the mask is 32 bits. The forms carry the mask in 8 bits (two bytes), 16 or 24 bits (four bytes) and 32 bits (six bytes); the fused `POPMRET` has an 8-bit field scaled by 256, which names `R8` to `R15` and no other register. A mask containing `R14` is reserved. Masks are written in binary with the hexadecimal in brackets: the mask of `R8` to `R11` is `0000 1111 0000 0000` (0x0F00), and the 8-bit field of `POPMRET` that names `R8` to `R15` is `1111 1111` (0xFF, which is 0xFF00 as a mask).

**9.3.9** `R16` to `R31` are ordinary registers to the hardware. `R24`, `R25` and `R26` are among the sixteen hot registers of the four-bit fields (9.4.6). *(D)*

*Commentary.* **Precedent.** The PDP-11's PC and SP were ordinary registers and its flags were set by nearly every instruction. The VAX put the PC in R15. **Trade-offs.** Keeping the PC out of the register file means a jump to a computed address uses `JMP`, not a write to a register, so that writing `SP` has no control-flow consequence and the hazard logic treats it like any other destination. Condition codes are kept (rather than a flagless design) because compare-and-branch and flag-setting arithmetic make for dense code; the flag rules make them cheap for an out-of-order implementation, because the compiled corpus shows that 68% of instructions write a flag and only 1.5% read one. **Improvements.** The status word carries a user-memory guard bit (9.14) and the per-mode `DP` serves two jobs, the per-CPU pointer in the kernel and the thread pointer in user mode. **Benefits.** An exception handler finds a kernel stack and a per-CPU pointer without first searching for them; a threaded program's thread-local variable is one instruction. **Modern comparables.** x86-64 keeps `FS` and `GS` base registers for the same two jobs; AArch64 has `TPIDR_EL0` and `TPIDR_EL1`; RISC-V uses `tp` and the supervisor scratch register. **Impact.** *Kernel:* Banked stack and direct-page registers let entry find a kernel stack and a per-CPU pointer with no code, and the status word is saved by one `PUSHX`. *Compiler:* The flag rules decide when a compare may fuse with its branch (1,893 pairs stay separate because a second branch reads the flags) and what the compiler may move between a compare and a branch. *Hardware:* Two flag groups need one or two rename targets, not one per bit; the register file is 32 by 64 bits; the banked copies are a three-way mux.

## 9.4 The instruction format

**9.4.1** An instruction is one, two or three parcels (two, four or six bytes; `MOVQL` is five); the first parcel holds the prefix, the sub-opcode and the operand pieces that fit, and the later parcels hold the rest. The bit layout of every leaf is a chart in the [reference tables](dictionary/by-encoding.md). *(D)*

**9.4.2** Instructions are parcel-aligned and little-endian; an instruction may cross any boundary of 8 bytes, a cache line or a page. *(D)*

**9.4.3** Most instructions are two or four bytes. Register-to-register work and the whole conversion set are one parcel; so is a memory operand through a hot base register with a displacement of up to three bits, a load or store from the stack pointer at a small offset, and a constant of up to seven bits. A base register with a 12-bit displacement, a post-increment or pre-decrement with a 12-bit stride, a scaled index with a 6- or 8-bit displacement, a pc-relative address within ±32 KiB and an immediate of up to 18 bits are two parcels. Displacements to ±128 MiB, absolute addresses, 32-bit immediates and branches to ±4 GiB are three. *(D)*

**9.4.4** Where an addressing mode names no base register (immediate, absolute, PC-relative), no field is spent on one: the later parcels are all value, so those modes reach 16 bits at four bytes and 32 bits at six. *(D)*

**9.4.5** A constant wider than 32 bits is either written in the instruction, `MOVQL #imm64, Rd`, which is ten bytes with the literal in the four later parcels, or loaded from a literal pool with `MOVQ =K, Rd`, written with an explicit `=`; nothing is pooled silently, and a `MOVQ #imm` whose constant fits no `MOVQ` form is assembled as `MOVQL`. *(D)*

**9.4.6** In a one-parcel form a 3-bit register field is not a register number but an index into a table of the eight hottest registers, `R0 R1 R8 R2 SP R3 R9 R10`. A 4-bit field indexes the sixteen hottest, `R0 R1 R8 R2 SP R3 R9 R10 R11 R4 R15 R5 R24 R25 R26 R6`. The tables are part of the ABI, and the compiler's register allocator prefers the hot registers. *(D)*

*Commentary.* **Precedent.** The PDP-11 had the length in the first word, but as a function of both of its six-bit specifiers; Thumb-2 and RISC-V's compressed instructions mix 16- and 32-bit forms with the length in a few bits. Here the length and the identity of the instruction are one match on the prefix. **Trade-offs.** Byte-granular encoding, as in x86, buys perhaps a tenth of the code size and costs a full alignment rotator and cross-line splice logic in the fetch path on a 64-bit datapath; this CPU refuses it. A hot-register index buys a one-parcel form and costs a rule for the compiler: a value that lives in one of the eight (for the 4-bit fields, sixteen) hottest registers is cheaper to use, which the allocator learns, and the ABI cannot move the tables without changing the encoding. Forcing an instruction to stay inside an eight-byte window would simplify fetch and would cost 5% to 10% of code size in padding. **Improvements.** `MOVQL` takes a 64-bit constant in one instruction instead of a literal-pool load, at ten bytes against six, the literal not counting against the three-parcel rule (errata 85). **Benefits.** The measured average is 2.7 to 3.3 bytes an instruction (9.2.13). **Modern comparables.** AArch64 and RISC-V have fixed or two-length encodings; x86 has byte-granular ones; this CPU has parcel-granular ones with three common lengths. **Impact.** *Kernel:* a one-parcel form is cheaper in kernel text with no source change. *Compiler:* the assembler picks the shortest form, branch and call relaxation is a length choice, and the cost model knows 2, 4 and 6 bytes and which registers are hot. *Hardware:* the fetch unit has a parcel buffer and a length lookup on the first parcel; no instruction crosses more than two parcel-aligned windows of eight bytes except the ten-byte `MOVQL`.

## 9.5 Addressing modes

**9.5.1** The addressing mode is not a field: it is the leaf, whose form lists the shape of each operand. The assembly language has the eight modes below, and the assembler gives each operand the shortest leaf that holds it. *(D)*

| Syntax | Effect | One parcel | Two parcels | Three parcels |
|---|---|---|---|---|
| `d(Rn)` | base plus displacement | a hot base register with a displacement of 1 to 3 bits; `d(SP)` with a displacement of 4 to 7 bits | 8-, 10- or 12-bit displacement (scaled by the size of the access in most forms) | 28-bit signed displacement, ±128 MiB |
| `d(Rn)(Rx*s)` | scaled index, `s` in {1, 2, 4, 8} | none | 6- or 8-bit displacement, or none with a 5-bit base and index | 22-bit displacement |
| `d(PC)` | PC-relative; the base is the first parcel of the instruction | none | 12-, 14- or 16-bit byte displacement: ±2 KiB, ±8 KiB, ±32 KiB | 32-bit displacement, ±2 GiB |
| `d(DP)` | direct page, loads only | none | none | 28-bit displacement |
| `#imm` | immediate, sign-extended | 3 to 7 bits | up to 18 bits | 32 bits (`MOVQL`: 64 bits, five parcels) |
| `@abs` | absolute, sign-extended | none | none | 32-bit address |
| `(Rn)+d` | post-increment by a stride `d` (0: the operand size) | none | 12-bit stride | none |
| `-(Rn)` or `(Rn)-d` | pre-decrement by a stride (0: the operand size) | none | 12-bit stride | none |

**9.5.2** The deferred modes of the PDP-11 are removed; indirection is done with `JMPI`, `CALLI` and a load. *(D)*

**9.5.3** At most one register side effect occurs per instruction, and it is committed at retirement; a fault discards it. *(D)*

Open: the displacement of the shortest scaled-index form, and a store through `d(DP)` ([J.9.5](appendix-j-open.md#j95)).

**9.5.4** A pc-relative operand is measured in bytes from the first parcel of the instruction; the field counts bytes for a memory operand and parcels for a branch or call. A branch has a field of 6 to 9 bits in one parcel (±64 to ±512 bytes), 16 bits in two (±64 KiB) and 32 bits in three (±4 GiB); a `CALL` has 18 bits in two parcels (±256 KiB) and 32 in three; a `LEA` or a load through `d(PC)` reaches ±2 KiB to ±32 KiB in two parcels and ±2 GiB in three. The dictionary lists the width and reach of every operand shape.

**9.5.5** The assembler cannot know the distance to a symbol in another object, so it writes such a `CALL` or `LEA` of a data symbol in its long form (six bytes) with a relocation; the linker lays out the sections, gives each such instruction the shortest form that reaches (a 4-byte `CALL` within ±256 KiB, a 4-byte `LEA` or pc-relative load within ±32 KiB, a 4-byte `JMP` or `MOVCALL` within ±64 KiB) and moves everything behind it. It grows each instruction from its shortest form, so the lengths only grow and the iteration ends. Relaxation is on by default; `as64 --no-relax` and `ld64 --no-relax` give the unrelaxed bytes. *(D)*

*Commentary on 9.5.1, 9.5.4 and 9.5.5.* **Precedent.** The PDP-11 chose the mode in each six-bit specifier; x86 chooses it in ModR/M and SIB; here the leaf chooses it, and the cost of a mode is the length of the leaf that has it. **Trade-offs.** The scaled index is the thin case: its shortest form has a 6-bit displacement, and `d(DP)` has only the six-byte load form, so a thread-local access through `DP` costs six bytes. Relaxation turns the assembler's guess into the linker's measurement: it saved 3.76% of the text of the corpus (an upper bound for the reach of the 4-byte call, since the corpus stub places symbols right behind each file) and 1.65% of the linked text of the six large programs; external calls, 6 bytes each, are the bulk. **Improvements.** The stride of the post-increment and pre-decrement is the same field in every leaf, so an array of 16-byte records is one instruction per element; the scaled index takes a conversion of a narrower index in the compiler (`bs_ec`'s inner loop, 31% fewer instructions). **Benefits.** An object file from `as64` is correct without relaxation and smaller with it, and a program linked either way produces the same output on the six large programs. **Modern comparables.** RISC-V's linker relaxes `call` and `lui`/`addi` pairs for the same reason; AArch64 needs linker veneers for far branches. **Impact.** *Kernel:* the kernel is relaxed like any other program, and text near the reach limits is smaller by the 4-byte forms. *Compiler:* it emits the long form for an external symbol and leaves the choice to the linker; it prefers scaled index and strided autoincrement where its loops allow (appendix F, F.4). *Hardware:* nothing: the address adder takes a field and a base in every leaf.

*Commentary.* **Precedent.** The PDP-11 had eight modes for each of eight registers, with a deferred flavour of each, and it made `*p++` and `*--p` single instructions. **Trade-offs.** Dropping the deferred modes removes the case where a fault occurs after a register has been updated at an address that itself came from a load; keeping the strided autoincrement costs nothing, because the undo information was already a delta (the PDP-11's `MMR1` recorded an amount for the same reason). **Improvements.** The increment is a stride, so walking an array of 16-byte records is one instruction; the PC-relative modes count from the instruction itself, so a branch needs no adjustment and `LEA` reads the PC. **Benefits.** Address generation is one adder pass, never load-then-add, which is the difference between one cycle and a long path on an FPGA. **Modern comparables.** AArch64 has pre- and post-indexed forms with an immediate; x86 has scaled index with a base; RISC-V has base plus immediate only. **Impact.** *Kernel:* A strided autoincrement walks a table of records, and `d(DP)` reaches the per-CPU structure in one instruction. *Compiler:* The modes match C idioms (`*p++`, `a[i]`) one-to-one, and dropping the deferred modes removes the cases the selector would otherwise have to consider. *Hardware:* Address generation is one adder pass, never load-then-add, and the PC-relative base is the first parcel, so no adjustment is needed.

## 9.6 Moves, conversions and address formation

<!-- notation -->
**The instructions.** Every instruction has an entry in the section of its group, laid out as in a processor reference manual: its mnemonics, its syntax, its encoding (the chart of its layout and the list of all its layouts, each with a chart of its own), its operation in pseudocode, the flags it writes, the exceptions it can take, and where the manual explains the matter it touches (*Cf.*). Every instruction, the atomic and the system instructions included, has its official entry below (sections 9.13 and 9.14 for those two groups); the chapters on the kernel and on several processors give the reasons, and an entry may point back to them for a fuller explanation. In the pseudocode, ← is assignment, = and ≠ compare, × and ÷ multiply and divide, and `M[a]` is memory at address `a`. Numbers that are encodings (prefixes, sub-opcodes, field values) are written in binary. Masks are binary too, with a subscript 2 to mark the base (`Rn & 111₂` keeps the low three bits). The layouts are generated from the grammars of the encodings, `spec/pdp64-enc.hbnf` and the grammar of the CPU, so a chart here cannot disagree with the assembler, the linker or the simulator. The aliases, the constants, the lists of the mnemonics and the bit layouts of every opcode are in the [reference tables](dictionary/index.md).

**The stories.** An instruction that is not common (the PDP-11 core and the operations every architecture has carry none) is followed by *Why it is here*: the machine the idea came from and the reason it was chosen, with the measurements that bear on it. Where no reason is recorded, the paragraph says so. The documents behind the paragraphs are listed in [appendix F](appendix-f-evidence.md).

**Notation.** `Rd` is the destination register, `Rs` the first source, `Rt` the second, `Ru` the third; the assembler writes the destination last, and the operands of a chart are numbered `op1`, `op2`, ... in the order of the assembly syntax. `rm` is a general operand: a register, or a memory operand, an immediate, a pc-relative or an absolute address, by the addressing forms that the layouts of the instruction give (section 9.5). `EA(rm)` is its effective address. `M[a]` is memory, `M8[a]` one byte. `sext` and `zext` sign- and zero-extend. `N Z V C` are the condition flags. In the charts the bits of a parcel are numbered from 15 at the left, a shaded box is a fixed value, and a white box is a field that varies.

**Registers.** The pdp64 has 32 registers, `R0` to `R31`. A register field of an instruction is the full number of bits (5), or fewer where the field names one of the hot registers; the entries that name `R0` to `R15` apply to `R16` to `R31` too; the hot-register tables are part of the ABI: the 3-bit fields hold, in order, `R0` `R1` `R8` `R2` `SP` `R3` `R9` `R10`; the 4-bit fields hold, in order, `R0` `R1` `R8` `R2` `SP` `R3` `R9` `R10` `R11` `R4` `R15` `R5` `R24` `R25` `R26` `R6`. `PUSHM` and `POPM` take a 32-bit mask (errata 87).
<!-- /notation -->

*Cf. section 6.7 for the memory types that decide whether an access is cached, and section 6.4 for what a faulting load leaves behind.*

**9.6.1** `MOVQ`, `MOVL`, `MOVW` and `MOVB` load and store 64, 32, 16 and 8 bits; the loads sign-extend. `MOVZL`, `MOVZW` and `MOVZB` load with zero extension.

**9.6.2** With a register operand, the same opcodes are the conversion set: `MOVB R1, R2` sign-extends the low byte, `MOVZW R1, R2` zero-extends the low word.

**9.6.3** `LEA` forms an effective address; `LEA 0(PC), Rn` reads the program counter.

**9.6.4** Moves, loads and stores write no flags. *(D)*

**9.6.5** The explicit unaligned forms `MOVUB`, `MOVUW`, `MOVUL` and `MOVUQ` exist in both directions. *(D)*


**9.6.6** The one-parcel forms abbreviate the common cases: loads and stores through a hot base register or the stack pointer at small offsets, `LEA` from `SP`, and `MOVQ #imm, rd` with an immediate of up to seven bits. *(D)*

**9.6.7** A load may be qualified `.D` (deferred fault: a load that can be hoisted above its guard, because a fault that the kernel finds invalid poisons the register instead of stopping the program, and the fault is taken at the instruction that writes the flags from a poisoned source), and a load or store may be qualified `.U` (the memory operand is accessed with user privilege, so that the user-memory guard of 6.10 is not opened and closed around a copy). *(D)* Details pending ([J.9.12](appendix-j-open.md#j912)).

*Commentary.* **Precedent.** The PDP-11 had `MOV` and `MOVB` with a byte sign-extended into a register; the VAX had a sized `MOV` for every width. **Trade-offs.** Keeping the sized loads costs four extra opcodes against a quad-only design, but without `MOVL` a struct field load becomes two `MOVW`s, a shift and an or, and ELF, timestamps and most on-disk and wire structures are full of 32- and 16-bit fields. **Improvements.** There is no separate `CVT` group: the conversions are the moves with a register source, so they cost nothing. **Benefits.** No partial-register state anywhere. **Modern comparables.** AArch64 and RISC-V have the same sized loads with sign and zero extension; x86-64 keeps 8- and 16-bit register writes that preserve the upper bits, which makes narrow writes depend on the old value. **Use.** `LEA 0(PC)` is how a position-independent program finds itself; the unaligned forms are for packed on-disk and network structures. **Impact.** *Kernel:* `LEA 0(PC)` lets position-independent kernel code find itself; the unaligned forms read packed on-disk and network structures. *Compiler:* Sized loads avoid the shift, mask and or of a struct-field read, and the conversions are moves, so no separate conversion selection exists. *Hardware:* No partial-register write anywhere; the conversions reuse the load-extend path.

<!-- entries:9.6 -->
### MOV: Move, load and store (64, 32, 16 and 8 bits)

**Mnemonics:** `MOVQ`, `MOVL`, `MOVW`, `MOVB`

**Syntax**

```
MOVQ rm, Rd        ; load
MOVQ Rs, rm        ; store
MOVL, MOVW, MOVB likewise
```

**Encoding**

![Encoding of MOV](figures/LDF-B28-1.svg)

The chart is the leaf `LDF-B28-1`, LDF.B28, prefix `011101`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `op2` is `reg5`: register, 5 bits. `sub` (4 bits) selects the mnemonic: `movq` 0000, `movl` 0001, `movw` 0010, `movb` 0011, `movzl` 0100, `movzw` 0101, `movzb` 0110, `add` 0111, `sub` 1000, `bic` 1001, `bis` 1010, `xor` 1011, `and` 1100, `mul` 1101, `mulh` 1110, `shl` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`LDF-B28-1`](dictionary/by-encoding.md#LDF-B28-1), [`LDF-X22-1`](dictionary/by-encoding.md#LDF-X22-1), [`LDF-PI12-1`](dictionary/by-encoding.md#LDF-PI12-1), [`LDF-PD12-1`](dictionary/by-encoding.md#LDF-PD12-1), [`LDF-PC32-1`](dictionary/by-encoding.md#LDF-PC32-1), [`LDF-A32-1`](dictionary/by-encoding.md#LDF-A32-1), [`LDFI-I32-1`](dictionary/by-encoding.md#LDFI-I32-1), [`STF-B28-1`](dictionary/by-encoding.md#STF-B28-1), [`STF-X22-1`](dictionary/by-encoding.md#STF-X22-1), [`STF-PI12-1`](dictionary/by-encoding.md#STF-PI12-1), [`STF-PD12-1`](dictionary/by-encoding.md#STF-PD12-1), [`STF-PC32-1`](dictionary/by-encoding.md#STF-PC32-1), [`STF-A32-1`](dictionary/by-encoding.md#STF-A32-1), [`DPF-D28-1`](dictionary/by-encoding.md#DPF-D28-1), [`RRF-1`](dictionary/by-encoding.md#RRF-1), [`RRF5-1`](dictionary/by-encoding.md#RRF5-1), [`RR5-1`](dictionary/by-encoding.md#RR5-1), [`STBu6-a-1`](dictionary/by-encoding.md#STBu6-a-1), [`LDX0-a-1`](dictionary/by-encoding.md#LDX0-a-1), [`LDPC12H-a-1`](dictionary/by-encoding.md#LDPC12H-a-1), [`LDI14H-a-1`](dictionary/by-encoding.md#LDI14H-a-1), [`LDPC14H-a-1`](dictionary/by-encoding.md#LDPC14H-a-1), [`STBs8H-a-1`](dictionary/by-encoding.md#STBs8H-a-1), [`LDBu8H-a-1`](dictionary/by-encoding.md#LDBu8H-a-1), [`LDI16H-a-1`](dictionary/by-encoding.md#LDI16H-a-1), [`STX0-a-1`](dictionary/by-encoding.md#STX0-a-1), [`IMMh43-a-1`](dictionary/by-encoding.md#IMMh43-a-1), [`LDI12-a-1`](dictionary/by-encoding.md#LDI12-a-1), [`LDPC16H-a-1`](dictionary/by-encoding.md#LDPC16H-a-1), [`STBu10H-a-1`](dictionary/by-encoding.md#STBu10H-a-1), [`LDBu10H-a-1`](dictionary/by-encoding.md#LDBu10H-a-1), [`LDHHH1-a-1`](dictionary/by-encoding.md#LDHHH1-a-1), [`STHHH1-a-1`](dictionary/by-encoding.md#STHHH1-a-1), [`LDBs6-a-1`](dictionary/by-encoding.md#LDBs6-a-1), [`LDSPh4-a-1`](dictionary/by-encoding.md#LDSPh4-a-1), [`IMMh45-a-1`](dictionary/by-encoding.md#IMMh45-a-1), [`STSPh4-a-1`](dictionary/by-encoding.md#STSPh4-a-1), [`LDBu12H-a-1`](dictionary/by-encoding.md#LDBu12H-a-1), [`STBu12H-a-1`](dictionary/by-encoding.md#STBu12H-a-1), [`LDHHH3-a-1`](dictionary/by-encoding.md#LDHHH3-a-1), [`LDPC12-a-1`](dictionary/by-encoding.md#LDPC12-a-1), [`IMMh47-a-1`](dictionary/by-encoding.md#IMMh47-a-1), [`LDBu8-a-1`](dictionary/by-encoding.md#LDBu8-a-1), [`STBs6-a-1`](dictionary/by-encoding.md#STBs6-a-1), [`LDX6H-a-1`](dictionary/by-encoding.md#LDX6H-a-1), [`STX6H-a-1`](dictionary/by-encoding.md#STX6H-a-1), [`LDBs10-a-1`](dictionary/by-encoding.md#LDBs10-a-1), [`STBs8-a-1`](dictionary/by-encoding.md#STBs8-a-1), [`LDFI-I32-2`](dictionary/by-encoding.md#LDFI-I32-2), [`STBu8H-b-1`](dictionary/by-encoding.md#STBu8H-b-1), [`LDBu6-b-1`](dictionary/by-encoding.md#LDBu6-b-1), [`STX0-b-1`](dictionary/by-encoding.md#STX0-b-1), [`STBs6-b-1`](dictionary/by-encoding.md#STBs6-b-1), [`LDX0-b-1`](dictionary/by-encoding.md#LDX0-b-1), [`STBu10H-b-1`](dictionary/by-encoding.md#STBu10H-b-1), [`LDBu8H-b-1`](dictionary/by-encoding.md#LDBu8H-b-1), [`STHHH1-b-1`](dictionary/by-encoding.md#STHHH1-b-1), [`STBu12H-b-1`](dictionary/by-encoding.md#STBu12H-b-1), [`LDPC12H-b-1`](dictionary/by-encoding.md#LDPC12H-b-1), [`STBs8H-b-1`](dictionary/by-encoding.md#STBs8H-b-1), [`LDS12H-b-1`](dictionary/by-encoding.md#LDS12H-b-1), [`STX4H-b-1`](dictionary/by-encoding.md#STX4H-b-1), [`LDBu12H-b-1`](dictionary/by-encoding.md#LDBu12H-b-1), [`LDBs6-b-1`](dictionary/by-encoding.md#LDBs6-b-1), [`STBu6-b-1`](dictionary/by-encoding.md#STBu6-b-1), [`LDI12-d-2`](dictionary/by-encoding.md#LDI12-d-2).

**Operation**

```
size = 8 (MOVQ), 4 (MOVL), 2 (MOVW) or 1 (MOVB) bytes
load :  Rd ← sext(M[EA(rm)], size)          ; len = 00: Rd ← sext(Rs[8×size-1:0])
store:  M[EA(rm)] ← Rs[8×size-1:0]          ; len = 00: Rd ← sext(Rs[8×size-1:0])
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

A register is always written in full: a narrow load sign-extends to 64 bits and there is no partial-register write anywhere. The register-to-register forms of the sized moves are the conversion set: `MOVB R1, R2` sign-extends the low byte of `R1` into `R2`.

**Cf.** 6.7 for the memory type that decides whether the access is cached; 6.4 for what a faulting access leaves behind.

<a id="w-movq"></a>
#### MOVQ

![MOVQ: LDF.B28, prefix 011101, sub-opcode 0000; operands b5d28s-x1, reg5; 6 bytes](figures/w/movq/01.svg)

![MOVQ: LDF.X22, prefix 01001, sub-opcode 0000; operands x5-5d22s, reg5; 6 bytes](figures/w/movq/02.svg)

![MOVQ: LDF.PC32, prefix 1010100, sub-opcode 0000; operands pc32-u1, reg5; 6 bytes](figures/w/movq/05.svg)

![MOVQ: LDF.A32, prefix 1010101, sub-opcode 0000; operands abs32, reg5; 6 bytes](figures/w/movq/06.svg)

![MOVQ: LDFI.I32, prefix 1010110, sub-opcode 1111; operands imm32s, reg5; 6 bytes](figures/w/movq/07.svg)

![MOVQ: STF.B28, prefix 1010111, sub-opcode 000; operands reg5, b5d28s-x1; 6 bytes](figures/w/movq/08.svg)

![MOVQ: STF.X22, prefix 100001, sub-opcode 000; operands reg5, x5-5d22s; 6 bytes](figures/w/movq/09.svg)

![MOVQ: STF.PC32, prefix 11010001, sub-opcode 000; operands reg5, pc32-u1; 6 bytes](figures/w/movq/12.svg)

![MOVQ: STF.A32, prefix 11010010, sub-opcode 000; operands reg5, abs32; 6 bytes](figures/w/movq/13.svg)

![MOVQ: DPF.D28, prefix 11101111010, sub-opcode 0000; operands dpd28s-x1, reg5; 6 bytes](figures/w/movq/14.svg)

![MOVQ: LDF.PI12, prefix 011111, sub-opcode 0000; operands pi5-s12, reg5; 4 bytes](figures/w/movq/03.svg)

![MOVQ: LDF.PD12, prefix 100000, sub-opcode 0000; operands pd5-s12, reg5; 4 bytes](figures/w/movq/04.svg)

![MOVQ: STF.PI12, prefix 1011001, sub-opcode 000; operands reg5, pi5-s12; 4 bytes](figures/w/movq/10.svg)

![MOVQ: STF.PD12, prefix 1011010, sub-opcode 000; operands reg5, pd5-s12; 4 bytes](figures/w/movq/11.svg)

![MOVQ: RRF5, prefix 1111001100100101, sub-opcode 000000; operands reg5, reg5; 4 bytes](figures/w/movq/16.svg)

![MOVQ: STBu6/a, prefix 111100101111000, sub-opcode 0; operands reg5, b5d6u-xsz; 4 bytes](figures/w/movq/18.svg)

![MOVQ: LDX0/a, prefix 1111000101101, sub-opcode 00; operands x5-5d0s, reg5; 4 bytes](figures/w/movq/19.svg)

![MOVQ: LDPC12H/a, prefix 11110010010010, sub-opcode 00; operands pc12-u1, reg4; 4 bytes](figures/w/movq/20.svg)

![MOVQ: LDI14H/a, prefix 11110010011001; operands imm14s, reg4; 4 bytes](figures/w/movq/21.svg)

![MOVQ: LDPC14H/a, prefix 111100000111, sub-opcode 00; operands pc14-u1, reg4; 4 bytes](figures/w/movq/22.svg)

![MOVQ: STBs8H/a, prefix 111100110000000, sub-opcode 0; operands reg4, b4d8s-xsz; 4 bytes](figures/w/movq/23.svg)

![MOVQ: LDBu8H/a, prefix 1111000101110, sub-opcode 00; operands b4d8u-xsz, reg5; 4 bytes](figures/w/movq/24.svg)

![MOVQ: LDI16H/a, prefix 111100001000; operands imm16s, reg4; 4 bytes](figures/w/movq/25.svg)

![MOVQ: STX0/a, prefix 11110010011110, sub-opcode 0; operands reg5, x5-5d0s; 4 bytes](figures/w/movq/26.svg)

![MOVQ: LDI12/a, prefix 111100110000010; operands imm12s, reg5; 4 bytes](figures/w/movq/28.svg)

![MOVQ: LDPC16H/a, prefix 1110110010, sub-opcode 00; operands pc16-u1, reg4; 4 bytes](figures/w/movq/29.svg)

![MOVQ: STBu10H/a, prefix 1111000110010, sub-opcode 0; operands reg4, b4d10u-xsz; 4 bytes](figures/w/movq/30.svg)

![MOVQ: LDBu10H/a, prefix 11101111101, sub-opcode 00; operands b4d10u-xsz, reg5; 4 bytes](figures/w/movq/31.svg)

![MOVQ: LDBs6/a, prefix 11110010100011, sub-opcode 00; operands b5d6s-xsz, reg5; 4 bytes](figures/w/movq/34.svg)

![MOVQ: LDBu12H/a, prefix 111001010, sub-opcode 00; operands b4d12u-xsz, reg5; 4 bytes](figures/w/movq/38.svg)

![MOVQ: STBu12H/a, prefix 11101111110, sub-opcode 0; operands reg4, b4d12u-xsz; 4 bytes](figures/w/movq/39.svg)

![MOVQ: LDPC12/a, prefix 1111000111100, sub-opcode 00; operands pc12-u1, reg5; 4 bytes](figures/w/movq/41.svg)

![MOVQ: LDBu8/a, prefix 111100001110, sub-opcode 00; operands b5d8u-xsz, reg5; 4 bytes](figures/w/movq/43.svg)

![MOVQ: STBs6/a, prefix 111100110001010, sub-opcode 0; operands reg5, b5d6s-xsz; 4 bytes](figures/w/movq/44.svg)

![MOVQ: LDX6H/a, prefix 111001110, sub-opcode 00; operands x4-4d6s, reg5; 4 bytes](figures/w/movq/45.svg)

![MOVQ: STX6H/a, prefix 1110110110, sub-opcode 0; operands reg5, x4-4d6s; 4 bytes](figures/w/movq/46.svg)

![MOVQ: LDBs10/a, prefix 1110110111, sub-opcode 00; operands b5d10s-xsz, reg5; 4 bytes](figures/w/movq/47.svg)

![MOVQ: STBs8/a, prefix 1111001000011, sub-opcode 0; operands reg5, b5d8s-xsz; 4 bytes](figures/w/movq/48.svg)

![MOVQ: RRF, prefix 0010, sub-opcode 0000; operands reg4, reg4; 2 bytes](figures/w/movq/15.svg)

![MOVQ: RR5, prefix 000, sub-opcode 000; operands reg5, reg5; 2 bytes](figures/w/movq/17.svg)

![MOVQ: IMMh43/a, prefix 111000101; operands imm3s, reg4; 2 bytes](figures/w/movq/27.svg)

![MOVQ: LDHHH1/a, prefix 1011011, sub-opcode 00; operands b3d1u-xsz, reg3; 2 bytes](figures/w/movq/32.svg)

![MOVQ: STHHH1/a, prefix 11010111, sub-opcode 0; operands reg3, b3d1u-xsz; 2 bytes](figures/w/movq/33.svg)

![MOVQ: LDSPh4/a, prefix 100100, sub-opcode 00; operands spd4u-xsz, reg4; 2 bytes](figures/w/movq/35.svg)

![MOVQ: IMMh45/a, prefix 1011101; operands imm5s, reg4; 2 bytes](figures/w/movq/36.svg)

![MOVQ: STSPh4/a, prefix 1011110, sub-opcode 0; operands reg4, spd4u-xsz; 2 bytes](figures/w/movq/37.svg)

![MOVQ: LDHHH3/a, prefix 01011, sub-opcode 00; operands b3d3u-xsz, reg3; 2 bytes](figures/w/movq/40.svg)

![MOVQ: IMMh47/a, prefix 01100; operands imm7s, reg4; 2 bytes](figures/w/movq/42.svg)

```
MOVQ rm, Rd
MOVQ Rs, rm
```

Operation, flags and exceptions as for the entry MOV above; 48 layout forms, each a chart of its own (above).

<a id="w-movl"></a>
#### MOVL

![MOVL: LDF.B28, prefix 011101, sub-opcode 0001; operands b5d28s-x1, reg5; 6 bytes](figures/w/movl/01.svg)

![MOVL: LDF.X22, prefix 01001, sub-opcode 0001; operands x5-5d22s, reg5; 6 bytes](figures/w/movl/02.svg)

![MOVL: LDF.PC32, prefix 1010100, sub-opcode 0001; operands pc32-u1, reg5; 6 bytes](figures/w/movl/05.svg)

![MOVL: LDF.A32, prefix 1010101, sub-opcode 0001; operands abs32, reg5; 6 bytes](figures/w/movl/06.svg)

![MOVL: LDFI.I32, prefix 110111101, sub-opcode 00; operands imm32s, reg5; 6 bytes](figures/w/movl/07.svg)

![MOVL: STF.B28, prefix 1010111, sub-opcode 001; operands reg5, b5d28s-x1; 6 bytes](figures/w/movl/08.svg)

![MOVL: STF.X22, prefix 100001, sub-opcode 001; operands reg5, x5-5d22s; 6 bytes](figures/w/movl/09.svg)

![MOVL: STF.PC32, prefix 11010001, sub-opcode 001; operands reg5, pc32-u1; 6 bytes](figures/w/movl/12.svg)

![MOVL: STF.A32, prefix 11010010, sub-opcode 001; operands reg5, abs32; 6 bytes](figures/w/movl/13.svg)

![MOVL: DPF.D28, prefix 11101111010, sub-opcode 0001; operands dpd28s-x1, reg5; 6 bytes](figures/w/movl/14.svg)

![MOVL: LDF.PI12, prefix 011111, sub-opcode 0001; operands pi5-s12, reg5; 4 bytes](figures/w/movl/03.svg)

![MOVL: LDF.PD12, prefix 100000, sub-opcode 0001; operands pd5-s12, reg5; 4 bytes](figures/w/movl/04.svg)

![MOVL: STF.PI12, prefix 1011001, sub-opcode 001; operands reg5, pi5-s12; 4 bytes](figures/w/movl/10.svg)

![MOVL: STF.PD12, prefix 1011010, sub-opcode 001; operands reg5, pd5-s12; 4 bytes](figures/w/movl/11.svg)

![MOVL: RRF5, prefix 1111001100100101, sub-opcode 000001; operands reg5, reg5; 4 bytes](figures/w/movl/16.svg)

![MOVL: STBu6/a, prefix 111100101111000, sub-opcode 1; operands reg5, b5d6u-xsz; 4 bytes](figures/w/movl/18.svg)

![MOVL: LDX0/a, prefix 1111000101101, sub-opcode 01; operands x5-5d0s, reg5; 4 bytes](figures/w/movl/19.svg)

![MOVL: LDPC12H/a, prefix 11110010010010, sub-opcode 01; operands pc12-u1, reg4; 4 bytes](figures/w/movl/20.svg)

![MOVL: LDPC14H/a, prefix 111100000111, sub-opcode 01; operands pc14-u1, reg4; 4 bytes](figures/w/movl/21.svg)

![MOVL: STBs8H/a, prefix 111100110000000, sub-opcode 1; operands reg4, b4d8s-xsz; 4 bytes](figures/w/movl/22.svg)

![MOVL: LDBu8H/a, prefix 1111000101110, sub-opcode 01; operands b4d8u-xsz, reg5; 4 bytes](figures/w/movl/23.svg)

![MOVL: STX0/a, prefix 11110010011110, sub-opcode 1; operands reg5, x5-5d0s; 4 bytes](figures/w/movl/24.svg)

![MOVL: LDPC16H/a, prefix 1110110010, sub-opcode 01; operands pc16-u1, reg4; 4 bytes](figures/w/movl/25.svg)

![MOVL: STBu10H/a, prefix 1111000110010, sub-opcode 1; operands reg4, b4d10u-xsz; 4 bytes](figures/w/movl/26.svg)

![MOVL: LDBu10H/a, prefix 11101111101, sub-opcode 01; operands b4d10u-xsz, reg5; 4 bytes](figures/w/movl/27.svg)

![MOVL: LDBs6/a, prefix 11110010100011, sub-opcode 01; operands b5d6s-xsz, reg5; 4 bytes](figures/w/movl/30.svg)

![MOVL: LDBu12H/a, prefix 111001010, sub-opcode 01; operands b4d12u-xsz, reg5; 4 bytes](figures/w/movl/33.svg)

![MOVL: STBu12H/a, prefix 11101111110, sub-opcode 1; operands reg4, b4d12u-xsz; 4 bytes](figures/w/movl/34.svg)

![MOVL: LDPC12/a, prefix 1111000111100, sub-opcode 01; operands pc12-u1, reg5; 4 bytes](figures/w/movl/36.svg)

![MOVL: LDBu8/a, prefix 111100001110, sub-opcode 01; operands b5d8u-xsz, reg5; 4 bytes](figures/w/movl/37.svg)

![MOVL: STBs6/a, prefix 111100110001010, sub-opcode 1; operands reg5, b5d6s-xsz; 4 bytes](figures/w/movl/38.svg)

![MOVL: LDX6H/a, prefix 111001110, sub-opcode 01; operands x4-4d6s, reg5; 4 bytes](figures/w/movl/39.svg)

![MOVL: STX6H/a, prefix 1110110110, sub-opcode 1; operands reg5, x4-4d6s; 4 bytes](figures/w/movl/40.svg)

![MOVL: LDBs10/a, prefix 1110110111, sub-opcode 01; operands b5d10s-xsz, reg5; 4 bytes](figures/w/movl/41.svg)

![MOVL: STBs8/a, prefix 1111001000011, sub-opcode 1; operands reg5, b5d8s-xsz; 4 bytes](figures/w/movl/42.svg)

![MOVL: RRF, prefix 0010, sub-opcode 0001; operands reg4, reg4; 2 bytes](figures/w/movl/15.svg)

![MOVL: RR5, prefix 000, sub-opcode 001; operands reg5, reg5; 2 bytes](figures/w/movl/17.svg)

![MOVL: LDHHH1/a, prefix 1011011, sub-opcode 01; operands b3d1u-xsz, reg3; 2 bytes](figures/w/movl/28.svg)

![MOVL: STHHH1/a, prefix 11010111, sub-opcode 1; operands reg3, b3d1u-xsz; 2 bytes](figures/w/movl/29.svg)

![MOVL: LDSPh4/a, prefix 100100, sub-opcode 01; operands spd4u-xsz, reg4; 2 bytes](figures/w/movl/31.svg)

![MOVL: STSPh4/a, prefix 1011110, sub-opcode 1; operands reg4, spd4u-xsz; 2 bytes](figures/w/movl/32.svg)

![MOVL: LDHHH3/a, prefix 01011, sub-opcode 01; operands b3d3u-xsz, reg3; 2 bytes](figures/w/movl/35.svg)

```
MOVL, MOVW, MOVB likewise
```

Operation, flags and exceptions as for the entry MOV above; 42 layout forms, each a chart of its own (above).

<a id="w-movw"></a>
#### MOVW

![MOVW: LDF.B28, prefix 011101, sub-opcode 0010; operands b5d28s-x1, reg5; 6 bytes](figures/w/movw/01.svg)

![MOVW: LDF.X22, prefix 01001, sub-opcode 0010; operands x5-5d22s, reg5; 6 bytes](figures/w/movw/02.svg)

![MOVW: LDF.PC32, prefix 1010100, sub-opcode 0010; operands pc32-u1, reg5; 6 bytes](figures/w/movw/05.svg)

![MOVW: LDF.A32, prefix 1010101, sub-opcode 0010; operands abs32, reg5; 6 bytes](figures/w/movw/06.svg)

![MOVW: LDFI.I32, prefix 110111101, sub-opcode 01; operands imm32s, reg5; 6 bytes](figures/w/movw/07.svg)

![MOVW: STF.B28, prefix 1010111, sub-opcode 010; operands reg5, b5d28s-x1; 6 bytes](figures/w/movw/08.svg)

![MOVW: STF.X22, prefix 100001, sub-opcode 010; operands reg5, x5-5d22s; 6 bytes](figures/w/movw/09.svg)

![MOVW: STF.PC32, prefix 11010001, sub-opcode 010; operands reg5, pc32-u1; 6 bytes](figures/w/movw/12.svg)

![MOVW: STF.A32, prefix 11010010, sub-opcode 010; operands reg5, abs32; 6 bytes](figures/w/movw/13.svg)

![MOVW: DPF.D28, prefix 11101111010, sub-opcode 0010; operands dpd28s-x1, reg5; 6 bytes](figures/w/movw/14.svg)

![MOVW: LDF.PI12, prefix 011111, sub-opcode 0010; operands pi5-s12, reg5; 4 bytes](figures/w/movw/03.svg)

![MOVW: LDF.PD12, prefix 100000, sub-opcode 0010; operands pd5-s12, reg5; 4 bytes](figures/w/movw/04.svg)

![MOVW: STF.PI12, prefix 1011001, sub-opcode 010; operands reg5, pi5-s12; 4 bytes](figures/w/movw/10.svg)

![MOVW: STF.PD12, prefix 1011010, sub-opcode 010; operands reg5, pd5-s12; 4 bytes](figures/w/movw/11.svg)

![MOVW: RRF5, prefix 1111001100100101, sub-opcode 000010; operands reg5, reg5; 4 bytes](figures/w/movw/16.svg)

![MOVW: STBu8H/b, prefix 111100101111011, sub-opcode 0; operands reg4, b4d8u-xsz; 4 bytes](figures/w/movw/17.svg)

![MOVW: LDBu6/b, prefix 11110010010101, sub-opcode 00; operands b5d6u-xsz, reg5; 4 bytes](figures/w/movw/18.svg)

![MOVW: STX0/b, prefix 11110010011101, sub-opcode 0; operands reg5, x5-5d0s; 4 bytes](figures/w/movw/19.svg)

![MOVW: STBs6/b, prefix 111100110000100, sub-opcode 0; operands reg5, b5d6s-xsz; 4 bytes](figures/w/movw/20.svg)

![MOVW: LDX0/b, prefix 1111000110001, sub-opcode 00; operands x5-5d0s, reg5; 4 bytes](figures/w/movw/21.svg)

![MOVW: STBu10H/b, prefix 1111000110111, sub-opcode 0; operands reg4, b4d10u-xsz; 4 bytes](figures/w/movw/22.svg)

![MOVW: LDBu8H/b, prefix 1111000111010, sub-opcode 00; operands b4d8u-xsz, reg5; 4 bytes](figures/w/movw/23.svg)

![MOVW: STBu12H/b, prefix 11110000000, sub-opcode 0; operands reg4, b4d12u-xsz; 4 bytes](figures/w/movw/25.svg)

![MOVW: LDPC12H/b, prefix 11110010101100, sub-opcode 00; operands pc12-u1, reg4; 4 bytes](figures/w/movw/26.svg)

![MOVW: STBs8H/b, prefix 111100110001100, sub-opcode 0; operands reg4, b4d8s-xsz; 4 bytes](figures/w/movw/27.svg)

![MOVW: LDS12H/b, prefix 11110010101111, sub-opcode 00; operands spd12u-xsz, reg4; 4 bytes](figures/w/movw/28.svg)

![MOVW: STX4H/b, prefix 111100010101, sub-opcode 0; operands reg5, x4-4d4s; 4 bytes](figures/w/movw/29.svg)

![MOVW: LDBu12H/b, prefix 111001111, sub-opcode 00; operands b4d12u-xsz, reg5; 4 bytes](figures/w/movw/30.svg)

![MOVW: LDBs6/b, prefix 11110010110100, sub-opcode 00; operands b5d6s-xsz, reg5; 4 bytes](figures/w/movw/31.svg)

![MOVW: STBu6/b, prefix 111100110001111, sub-opcode 0; operands reg5, b5d6u-xsz; 4 bytes](figures/w/movw/32.svg)

![MOVW: RRF, prefix 0010, sub-opcode 0010; operands reg4, reg4; 2 bytes](figures/w/movw/15.svg)

![MOVW: STHHH1/b, prefix 11011011, sub-opcode 0; operands reg3, b3d1u-xsz; 2 bytes](figures/w/movw/24.svg)

Operation, flags and exceptions as for the entry MOV above; 32 layout forms, each a chart of its own (above).

<a id="w-movb"></a>
#### MOVB

![MOVB: LDF.B28, prefix 011101, sub-opcode 0011; operands b5d28s-x1, reg5; 6 bytes](figures/w/movb/01.svg)

![MOVB: LDF.X22, prefix 01001, sub-opcode 0011; operands x5-5d22s, reg5; 6 bytes](figures/w/movb/02.svg)

![MOVB: LDF.PC32, prefix 1010100, sub-opcode 0011; operands pc32-u1, reg5; 6 bytes](figures/w/movb/05.svg)

![MOVB: LDF.A32, prefix 1010101, sub-opcode 0011; operands abs32, reg5; 6 bytes](figures/w/movb/06.svg)

![MOVB: LDFI.I32, prefix 110111101, sub-opcode 10; operands imm32s, reg5; 6 bytes](figures/w/movb/07.svg)

![MOVB: STF.B28, prefix 1010111, sub-opcode 011; operands reg5, b5d28s-x1; 6 bytes](figures/w/movb/08.svg)

![MOVB: STF.X22, prefix 100001, sub-opcode 011; operands reg5, x5-5d22s; 6 bytes](figures/w/movb/09.svg)

![MOVB: STF.PC32, prefix 11010001, sub-opcode 011; operands reg5, pc32-u1; 6 bytes](figures/w/movb/12.svg)

![MOVB: STF.A32, prefix 11010010, sub-opcode 011; operands reg5, abs32; 6 bytes](figures/w/movb/13.svg)

![MOVB: DPF.D28, prefix 11101111010, sub-opcode 0011; operands dpd28s-x1, reg5; 6 bytes](figures/w/movb/14.svg)

![MOVB: LDF.PI12, prefix 011111, sub-opcode 0011; operands pi5-s12, reg5; 4 bytes](figures/w/movb/03.svg)

![MOVB: LDF.PD12, prefix 100000, sub-opcode 0011; operands pd5-s12, reg5; 4 bytes](figures/w/movb/04.svg)

![MOVB: STF.PI12, prefix 1011001, sub-opcode 011; operands reg5, pi5-s12; 4 bytes](figures/w/movb/10.svg)

![MOVB: STF.PD12, prefix 1011010, sub-opcode 011; operands reg5, pd5-s12; 4 bytes](figures/w/movb/11.svg)

![MOVB: RRF5, prefix 1111001100100101, sub-opcode 000011; operands reg5, reg5; 4 bytes](figures/w/movb/16.svg)

![MOVB: STBu8H/b, prefix 111100101111011, sub-opcode 1; operands reg4, b4d8u-xsz; 4 bytes](figures/w/movb/17.svg)

![MOVB: LDBu6/b, prefix 11110010010101, sub-opcode 01; operands b5d6u-xsz, reg5; 4 bytes](figures/w/movb/18.svg)

![MOVB: STX0/b, prefix 11110010011101, sub-opcode 1; operands reg5, x5-5d0s; 4 bytes](figures/w/movb/19.svg)

![MOVB: STBs6/b, prefix 111100110000100, sub-opcode 1; operands reg5, b5d6s-xsz; 4 bytes](figures/w/movb/20.svg)

![MOVB: LDX0/b, prefix 1111000110001, sub-opcode 01; operands x5-5d0s, reg5; 4 bytes](figures/w/movb/21.svg)

![MOVB: LDI12/d, prefix 11110010100111, sub-opcode 1; operands imm12s, reg5; 4 bytes](figures/w/movb/22.svg)

![MOVB: STBu10H/b, prefix 1111000110111, sub-opcode 1; operands reg4, b4d10u-xsz; 4 bytes](figures/w/movb/23.svg)

![MOVB: LDBu8H/b, prefix 1111000111010, sub-opcode 01; operands b4d8u-xsz, reg5; 4 bytes](figures/w/movb/24.svg)

![MOVB: STBu12H/b, prefix 11110000000, sub-opcode 1; operands reg4, b4d12u-xsz; 4 bytes](figures/w/movb/26.svg)

![MOVB: LDPC12H/b, prefix 11110010101100, sub-opcode 01; operands pc12-u1, reg4; 4 bytes](figures/w/movb/27.svg)

![MOVB: STBs8H/b, prefix 111100110001100, sub-opcode 1; operands reg4, b4d8s-xsz; 4 bytes](figures/w/movb/28.svg)

![MOVB: LDS12H/b, prefix 11110010101111, sub-opcode 01; operands spd12u-xsz, reg4; 4 bytes](figures/w/movb/29.svg)

![MOVB: STX4H/b, prefix 111100010101, sub-opcode 1; operands reg5, x4-4d4s; 4 bytes](figures/w/movb/30.svg)

![MOVB: LDBu12H/b, prefix 111001111, sub-opcode 01; operands b4d12u-xsz, reg5; 4 bytes](figures/w/movb/31.svg)

![MOVB: LDBs6/b, prefix 11110010110100, sub-opcode 01; operands b5d6s-xsz, reg5; 4 bytes](figures/w/movb/32.svg)

![MOVB: STBu6/b, prefix 111100110001111, sub-opcode 1; operands reg5, b5d6u-xsz; 4 bytes](figures/w/movb/33.svg)

![MOVB: RRF, prefix 0010, sub-opcode 0011; operands reg4, reg4; 2 bytes](figures/w/movb/15.svg)

![MOVB: STHHH1/b, prefix 11011011, sub-opcode 1; operands reg3, b3d1u-xsz; 2 bytes](figures/w/movb/25.svg)

Operation, flags and exceptions as for the entry MOV above; 33 layout forms, each a chart of its own (above).


### MOVZ: Move zero-extended (32, 16 and 8 bits)

**Mnemonics:** `MOVZL`, `MOVZW`, `MOVZB`

**Syntax**

```
MOVZL rm, Rd
MOVZW rm, Rd
MOVZB rm, Rd
```

**Encoding**

![Encoding of MOVZ](figures/LDF-B28-1.svg)

The chart is the leaf `LDF-B28-1`, LDF.B28, prefix `011101`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `op2` is `reg5`: register, 5 bits. `sub` (4 bits) selects the mnemonic: `movq` 0000, `movl` 0001, `movw` 0010, `movb` 0011, `movzl` 0100, `movzw` 0101, `movzb` 0110, `add` 0111, `sub` 1000, `bic` 1001, `bis` 1010, `xor` 1011, `and` 1100, `mul` 1101, `mulh` 1110, `shl` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`LDF-B28-1`](dictionary/by-encoding.md#LDF-B28-1), [`LDF-X22-1`](dictionary/by-encoding.md#LDF-X22-1), [`LDF-PI12-1`](dictionary/by-encoding.md#LDF-PI12-1), [`LDF-PD12-1`](dictionary/by-encoding.md#LDF-PD12-1), [`LDF-PC32-1`](dictionary/by-encoding.md#LDF-PC32-1), [`LDF-A32-1`](dictionary/by-encoding.md#LDF-A32-1), [`LDFI-I32-2`](dictionary/by-encoding.md#LDFI-I32-2), [`DPF-D28-1`](dictionary/by-encoding.md#DPF-D28-1), [`RRF-1`](dictionary/by-encoding.md#RRF-1), [`RRF5-1`](dictionary/by-encoding.md#RRF5-1), [`LDBu6-b-1`](dictionary/by-encoding.md#LDBu6-b-1), [`LDX0-b-1`](dictionary/by-encoding.md#LDX0-b-1), [`LDBu8H-b-1`](dictionary/by-encoding.md#LDBu8H-b-1), [`LDPC12H-b-1`](dictionary/by-encoding.md#LDPC12H-b-1), [`LDS12H-b-1`](dictionary/by-encoding.md#LDS12H-b-1), [`LDBu12H-b-1`](dictionary/by-encoding.md#LDBu12H-b-1), [`LDBs6-b-1`](dictionary/by-encoding.md#LDBs6-b-1), [`LDFI-I32-3`](dictionary/by-encoding.md#LDFI-I32-3), [`LDX0-a-1`](dictionary/by-encoding.md#LDX0-a-1), [`LDPC12H-a-1`](dictionary/by-encoding.md#LDPC12H-a-1), [`LDPC14H-a-1`](dictionary/by-encoding.md#LDPC14H-a-1), [`LDBu8H-a-1`](dictionary/by-encoding.md#LDBu8H-a-1), [`LDPC16H-a-1`](dictionary/by-encoding.md#LDPC16H-a-1), [`LDBu10H-a-1`](dictionary/by-encoding.md#LDBu10H-a-1), [`LDHHH1-a-1`](dictionary/by-encoding.md#LDHHH1-a-1), [`LDBs6-a-1`](dictionary/by-encoding.md#LDBs6-a-1), [`LDSPh4-a-1`](dictionary/by-encoding.md#LDSPh4-a-1), [`LDBu12H-a-1`](dictionary/by-encoding.md#LDBu12H-a-1), [`LDHHH3-a-1`](dictionary/by-encoding.md#LDHHH3-a-1), [`LDPC12-a-1`](dictionary/by-encoding.md#LDPC12-a-1), [`LDBu8-a-1`](dictionary/by-encoding.md#LDBu8-a-1), [`LDX6H-a-1`](dictionary/by-encoding.md#LDX6H-a-1), [`LDBs10-a-1`](dictionary/by-encoding.md#LDBs10-a-1).

**Operation**

```
Rd ← zext(M[EA(rm)], size)      ; len = 00: Rd ← zext(Rs[8×size-1:0])
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

There is no zero-extending 64-bit move (it would be `MOVQ`). The register-to-register forms are the zero-extending half of the conversion set.

<a id="w-movzl"></a>
#### MOVZL

![MOVZL: LDF.B28, prefix 011101, sub-opcode 0100; operands b5d28s-x1, reg5; 6 bytes](figures/w/movzl/01.svg)

![MOVZL: LDF.X22, prefix 01001, sub-opcode 0100; operands x5-5d22s, reg5; 6 bytes](figures/w/movzl/02.svg)

![MOVZL: LDF.PC32, prefix 1010100, sub-opcode 0100; operands pc32-u1, reg5; 6 bytes](figures/w/movzl/05.svg)

![MOVZL: LDF.A32, prefix 1010101, sub-opcode 0100; operands abs32, reg5; 6 bytes](figures/w/movzl/06.svg)

![MOVZL: LDFI.I32, prefix 110111101, sub-opcode 11; operands imm32s, reg5; 6 bytes](figures/w/movzl/07.svg)

![MOVZL: DPF.D28, prefix 11101111010, sub-opcode 0100; operands dpd28s-x1, reg5; 6 bytes](figures/w/movzl/08.svg)

![MOVZL: LDF.PI12, prefix 011111, sub-opcode 0100; operands pi5-s12, reg5; 4 bytes](figures/w/movzl/03.svg)

![MOVZL: LDF.PD12, prefix 100000, sub-opcode 0100; operands pd5-s12, reg5; 4 bytes](figures/w/movzl/04.svg)

![MOVZL: RRF5, prefix 1111001100100101, sub-opcode 000100; operands reg5, reg5; 4 bytes](figures/w/movzl/10.svg)

![MOVZL: LDBu6/b, prefix 11110010010101, sub-opcode 10; operands b5d6u-xsz, reg5; 4 bytes](figures/w/movzl/11.svg)

![MOVZL: LDX0/b, prefix 1111000110001, sub-opcode 10; operands x5-5d0s, reg5; 4 bytes](figures/w/movzl/12.svg)

![MOVZL: LDBu8H/b, prefix 1111000111010, sub-opcode 10; operands b4d8u-xsz, reg5; 4 bytes](figures/w/movzl/13.svg)

![MOVZL: LDPC12H/b, prefix 11110010101100, sub-opcode 10; operands pc12-u1, reg4; 4 bytes](figures/w/movzl/14.svg)

![MOVZL: LDS12H/b, prefix 11110010101111, sub-opcode 10; operands spd12u-xsz, reg4; 4 bytes](figures/w/movzl/15.svg)

![MOVZL: LDBu12H/b, prefix 111001111, sub-opcode 10; operands b4d12u-xsz, reg5; 4 bytes](figures/w/movzl/16.svg)

![MOVZL: LDBs6/b, prefix 11110010110100, sub-opcode 10; operands b5d6s-xsz, reg5; 4 bytes](figures/w/movzl/17.svg)

![MOVZL: RRF, prefix 0010, sub-opcode 0100; operands reg4, reg4; 2 bytes](figures/w/movzl/09.svg)

```
MOVZL rm, Rd
```

Operation, flags and exceptions as for the entry MOVZ above; 17 layout forms, each a chart of its own (above).

<a id="w-movzw"></a>
#### MOVZW

![MOVZW: LDF.B28, prefix 011101, sub-opcode 0101; operands b5d28s-x1, reg5; 6 bytes](figures/w/movzw/01.svg)

![MOVZW: LDF.X22, prefix 01001, sub-opcode 0101; operands x5-5d22s, reg5; 6 bytes](figures/w/movzw/02.svg)

![MOVZW: LDF.PC32, prefix 1010100, sub-opcode 0101; operands pc32-u1, reg5; 6 bytes](figures/w/movzw/05.svg)

![MOVZW: LDF.A32, prefix 1010101, sub-opcode 0101; operands abs32, reg5; 6 bytes](figures/w/movzw/06.svg)

![MOVZW: LDFI.I32, prefix 1110101001, sub-opcode 0; operands imm32s, reg5; 6 bytes](figures/w/movzw/07.svg)

![MOVZW: DPF.D28, prefix 11101111010, sub-opcode 0101; operands dpd28s-x1, reg5; 6 bytes](figures/w/movzw/08.svg)

![MOVZW: LDF.PI12, prefix 011111, sub-opcode 0101; operands pi5-s12, reg5; 4 bytes](figures/w/movzw/03.svg)

![MOVZW: LDF.PD12, prefix 100000, sub-opcode 0101; operands pd5-s12, reg5; 4 bytes](figures/w/movzw/04.svg)

![MOVZW: RRF5, prefix 1111001100100101, sub-opcode 000101; operands reg5, reg5; 4 bytes](figures/w/movzw/10.svg)

![MOVZW: LDBu6/b, prefix 11110010010101, sub-opcode 11; operands b5d6u-xsz, reg5; 4 bytes](figures/w/movzw/11.svg)

![MOVZW: LDX0/b, prefix 1111000110001, sub-opcode 11; operands x5-5d0s, reg5; 4 bytes](figures/w/movzw/12.svg)

![MOVZW: LDBu8H/b, prefix 1111000111010, sub-opcode 11; operands b4d8u-xsz, reg5; 4 bytes](figures/w/movzw/13.svg)

![MOVZW: LDPC12H/b, prefix 11110010101100, sub-opcode 11; operands pc12-u1, reg4; 4 bytes](figures/w/movzw/14.svg)

![MOVZW: LDS12H/b, prefix 11110010101111, sub-opcode 11; operands spd12u-xsz, reg4; 4 bytes](figures/w/movzw/15.svg)

![MOVZW: LDBu12H/b, prefix 111001111, sub-opcode 11; operands b4d12u-xsz, reg5; 4 bytes](figures/w/movzw/16.svg)

![MOVZW: LDBs6/b, prefix 11110010110100, sub-opcode 11; operands b5d6s-xsz, reg5; 4 bytes](figures/w/movzw/17.svg)

![MOVZW: RRF, prefix 0010, sub-opcode 0101; operands reg4, reg4; 2 bytes](figures/w/movzw/09.svg)

```
MOVZW rm, Rd
```

Operation, flags and exceptions as for the entry MOVZ above; 17 layout forms, each a chart of its own (above).

<a id="w-movzb"></a>
#### MOVZB

![MOVZB: LDF.B28, prefix 011101, sub-opcode 0110; operands b5d28s-x1, reg5; 6 bytes](figures/w/movzb/01.svg)

![MOVZB: LDF.X22, prefix 01001, sub-opcode 0110; operands x5-5d22s, reg5; 6 bytes](figures/w/movzb/02.svg)

![MOVZB: LDF.PC32, prefix 1010100, sub-opcode 0110; operands pc32-u1, reg5; 6 bytes](figures/w/movzb/05.svg)

![MOVZB: LDF.A32, prefix 1010101, sub-opcode 0110; operands abs32, reg5; 6 bytes](figures/w/movzb/06.svg)

![MOVZB: LDFI.I32, prefix 1110101001, sub-opcode 1; operands imm32s, reg5; 6 bytes](figures/w/movzb/07.svg)

![MOVZB: DPF.D28, prefix 11101111010, sub-opcode 0110; operands dpd28s-x1, reg5; 6 bytes](figures/w/movzb/08.svg)

![MOVZB: LDF.PI12, prefix 011111, sub-opcode 0110; operands pi5-s12, reg5; 4 bytes](figures/w/movzb/03.svg)

![MOVZB: LDF.PD12, prefix 100000, sub-opcode 0110; operands pd5-s12, reg5; 4 bytes](figures/w/movzb/04.svg)

![MOVZB: RRF5, prefix 1111001100100101, sub-opcode 000110; operands reg5, reg5; 4 bytes](figures/w/movzb/10.svg)

![MOVZB: LDX0/a, prefix 1111000101101, sub-opcode 10; operands x5-5d0s, reg5; 4 bytes](figures/w/movzb/11.svg)

![MOVZB: LDPC12H/a, prefix 11110010010010, sub-opcode 10; operands pc12-u1, reg4; 4 bytes](figures/w/movzb/12.svg)

![MOVZB: LDPC14H/a, prefix 111100000111, sub-opcode 10; operands pc14-u1, reg4; 4 bytes](figures/w/movzb/13.svg)

![MOVZB: LDBu8H/a, prefix 1111000101110, sub-opcode 10; operands b4d8u-xsz, reg5; 4 bytes](figures/w/movzb/14.svg)

![MOVZB: LDPC16H/a, prefix 1110110010, sub-opcode 10; operands pc16-u1, reg4; 4 bytes](figures/w/movzb/15.svg)

![MOVZB: LDBu10H/a, prefix 11101111101, sub-opcode 10; operands b4d10u-xsz, reg5; 4 bytes](figures/w/movzb/16.svg)

![MOVZB: LDBs6/a, prefix 11110010100011, sub-opcode 10; operands b5d6s-xsz, reg5; 4 bytes](figures/w/movzb/18.svg)

![MOVZB: LDBu12H/a, prefix 111001010, sub-opcode 10; operands b4d12u-xsz, reg5; 4 bytes](figures/w/movzb/20.svg)

![MOVZB: LDPC12/a, prefix 1111000111100, sub-opcode 10; operands pc12-u1, reg5; 4 bytes](figures/w/movzb/22.svg)

![MOVZB: LDBu8/a, prefix 111100001110, sub-opcode 10; operands b5d8u-xsz, reg5; 4 bytes](figures/w/movzb/23.svg)

![MOVZB: LDX6H/a, prefix 111001110, sub-opcode 10; operands x4-4d6s, reg5; 4 bytes](figures/w/movzb/24.svg)

![MOVZB: LDBs10/a, prefix 1110110111, sub-opcode 10; operands b5d10s-xsz, reg5; 4 bytes](figures/w/movzb/25.svg)

![MOVZB: RRF, prefix 0010, sub-opcode 0110; operands reg4, reg4; 2 bytes](figures/w/movzb/09.svg)

![MOVZB: LDHHH1/a, prefix 1011011, sub-opcode 10; operands b3d1u-xsz, reg3; 2 bytes](figures/w/movzb/17.svg)

![MOVZB: LDSPh4/a, prefix 100100, sub-opcode 10; operands spd4u-xsz, reg4; 2 bytes](figures/w/movzb/19.svg)

![MOVZB: LDHHH3/a, prefix 01011, sub-opcode 10; operands b3d3u-xsz, reg3; 2 bytes](figures/w/movzb/21.svg)

```
MOVZB rm, Rd
```

Operation, flags and exceptions as for the entry MOVZ above; 25 layout forms, each a chart of its own (above).


<a id="w-lea"></a>
### LEA: Load effective address

![LEA: LDF.B28, prefix 1010001, sub-opcode 110; operands b5d28s-x1, reg5; 6 bytes](figures/w/lea/01.svg)

![LEA: LDF.X22, prefix 011110, sub-opcode 110; operands x5-5d22s, reg5; 6 bytes](figures/w/lea/02.svg)

![LEA: LDF.PC32, prefix 11001100, sub-opcode 110; operands pc32-u1, reg5; 6 bytes](figures/w/lea/05.svg)

![LEA: LDF.A32, prefix 11001101, sub-opcode 110; operands abs32, reg5; 6 bytes](figures/w/lea/06.svg)

![LEA: DPF.D28, prefix 111100000110, sub-opcode 110; operands dpd28s-x1, reg5; 6 bytes](figures/w/lea/07.svg)

![LEA: LDF.PI12, prefix 1010010, sub-opcode 110; operands pi5-s12, reg5; 4 bytes](figures/w/lea/03.svg)

![LEA: LDF.PD12, prefix 1010011, sub-opcode 110; operands pd5-s12, reg5; 4 bytes](figures/w/lea/04.svg)

![LEA: LEASx12H/a, prefix 1111001100101000; operands spd12s-x1, reg4; 4 bytes](figures/w/lea/08.svg)

![LEA: LDX0/a, prefix 1111000101101, sub-opcode 11; operands x5-5d0s, reg5; 4 bytes](figures/w/lea/09.svg)

![LEA: LDPC12H/a, prefix 11110010010010, sub-opcode 11; operands pc12-u1, reg4; 4 bytes](figures/w/lea/10.svg)

![LEA: LDPC14H/a, prefix 111100000111, sub-opcode 11; operands pc14-u1, reg4; 4 bytes](figures/w/lea/11.svg)

![LEA: LDBu8H/a, prefix 1111000101110, sub-opcode 11; operands b4d8u-xsz, reg5; 4 bytes](figures/w/lea/12.svg)

![LEA: LDPC16H/a, prefix 1110110010, sub-opcode 11; operands pc16-u1, reg4; 4 bytes](figures/w/lea/13.svg)

![LEA: LDBu10H/a, prefix 11101111101, sub-opcode 11; operands b4d10u-xsz, reg5; 4 bytes](figures/w/lea/14.svg)

![LEA: LDBs6/a, prefix 11110010100011, sub-opcode 11; operands b5d6s-xsz, reg5; 4 bytes](figures/w/lea/17.svg)

![LEA: LEAS12H/a, prefix 1111001100101111; operands spd12u-x8, reg4; 4 bytes](figures/w/lea/18.svg)

![LEA: LDBu12H/a, prefix 111001010, sub-opcode 11; operands b4d12u-xsz, reg5; 4 bytes](figures/w/lea/20.svg)

![LEA: LDPC12/a, prefix 1111000111100, sub-opcode 11; operands pc12-u1, reg5; 4 bytes](figures/w/lea/22.svg)

![LEA: LDBu8/a, prefix 111100001110, sub-opcode 11; operands b5d8u-xsz, reg5; 4 bytes](figures/w/lea/23.svg)

![LEA: LDX6H/a, prefix 111001110, sub-opcode 11; operands x4-4d6s, reg5; 4 bytes](figures/w/lea/24.svg)

![LEA: LDBs10/a, prefix 1110110111, sub-opcode 11; operands b5d10s-xsz, reg5; 4 bytes](figures/w/lea/25.svg)

![LEA: LEAS14H/a, prefix 11110010110111; operands spd14u-x8, reg4; 4 bytes](figures/w/lea/26.svg)

![LEA: LDHHH1/a, prefix 1011011, sub-opcode 11; operands b3d1u-xsz, reg3; 2 bytes](figures/w/lea/15.svg)

![LEA: LEASPh4/a, prefix 11011000; operands spd4u-x8, reg4; 2 bytes](figures/w/lea/16.svg)

![LEA: LDSPh4/a, prefix 100100, sub-opcode 11; operands spd4u-xsz, reg4; 2 bytes](figures/w/lea/19.svg)

![LEA: LDHHH3/a, prefix 01011, sub-opcode 11; operands b3d3u-xsz, reg3; 2 bytes](figures/w/lea/21.svg)

**Mnemonics:** `LEA`

**Syntax**

```
LEA d(Rn), Rd
LEA d(PC), Rd
LEA d(Rn)(Rx×s), Rd
```

**Encoding**

![Encoding of LEA](figures/LDF-B28-2.svg)

The chart is the leaf `LDF-B28-2`, LDF.B28, prefix `1010001`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `op2` is `reg5`: register, 5 bits. `sub` (3 bits) selects the mnemonic: `shr` 000, `sar` 001, `fadd` 010, `fsub` 011, `fmul` 100, `bit` 101, `lea` 110, `movub` 111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`LDF-B28-2`](dictionary/by-encoding.md#LDF-B28-2), [`LDF-X22-2`](dictionary/by-encoding.md#LDF-X22-2), [`LDF-PI12-2`](dictionary/by-encoding.md#LDF-PI12-2), [`LDF-PD12-2`](dictionary/by-encoding.md#LDF-PD12-2), [`LDF-PC32-2`](dictionary/by-encoding.md#LDF-PC32-2), [`LDF-A32-2`](dictionary/by-encoding.md#LDF-A32-2), [`DPF-D28-2`](dictionary/by-encoding.md#DPF-D28-2), [`LEASx12H-a-1`](dictionary/by-encoding.md#LEASx12H-a-1), [`LDX0-a-1`](dictionary/by-encoding.md#LDX0-a-1), [`LDPC12H-a-1`](dictionary/by-encoding.md#LDPC12H-a-1), [`LDPC14H-a-1`](dictionary/by-encoding.md#LDPC14H-a-1), [`LDBu8H-a-1`](dictionary/by-encoding.md#LDBu8H-a-1), [`LDPC16H-a-1`](dictionary/by-encoding.md#LDPC16H-a-1), [`LDBu10H-a-1`](dictionary/by-encoding.md#LDBu10H-a-1), [`LDHHH1-a-1`](dictionary/by-encoding.md#LDHHH1-a-1), [`LEASPh4-a-1`](dictionary/by-encoding.md#LEASPh4-a-1), [`LDBs6-a-1`](dictionary/by-encoding.md#LDBs6-a-1), [`LEAS12H-a-1`](dictionary/by-encoding.md#LEAS12H-a-1), [`LDSPh4-a-1`](dictionary/by-encoding.md#LDSPh4-a-1), [`LDBu12H-a-1`](dictionary/by-encoding.md#LDBu12H-a-1), [`LDHHH3-a-1`](dictionary/by-encoding.md#LDHHH3-a-1), [`LDPC12-a-1`](dictionary/by-encoding.md#LDPC12-a-1), [`LDBu8-a-1`](dictionary/by-encoding.md#LDBu8-a-1), [`LDX6H-a-1`](dictionary/by-encoding.md#LDX6H-a-1), [`LDBs10-a-1`](dictionary/by-encoding.md#LDBs10-a-1), [`LEAS14H-a-1`](dictionary/by-encoding.md#LEAS14H-a-1).

**Operation**

```
Rd ← EA(rm)          ; no memory access
```

**Flags** None written.

**Exceptions** The operand must name memory (a register or an immediate is not a form). No memory access is made, so the instruction takes no memory fault. A reserved encoding aborts with the illegal-instruction vector.

`LEA 0(PC), Rd` is how the program counter is read: it puts the address of the `LEA` itself in `Rd`. The base of every PC-relative displacement is the address of the first parcel of the instruction.

**Why it is here.** The PDP-11 and the VAX made the program counter a register (R7, R15). Here the program counter is kept out of the register file, because every register write would then be a potential branch, and a read-only view of it (R7 as a view of the PC) is refused, because it would fix for ever *which* PC is meant (ARM32 is stuck with `PC+8`). `LEA 0(PC), Rn` gives the capability without the commitment: the address of the instruction itself, in one instruction. The same instruction forms any address PC-relatively, which is what makes position-independent code free (section 9.16).


### MOVU: Unaligned load and store

**Mnemonics:** `MOVUB`, `MOVUW`, `MOVUL`, `MOVUQ`

**Syntax**

```
MOVUQ rm, Rd        ; load, any alignment
MOVUQ Rs, rm        ; store, any alignment
MOVUW, MOVUL, MOVUB likewise
```

**Encoding**

![Encoding of MOVU](figures/LDF-B28-2.svg)

The chart is the leaf `LDF-B28-2`, LDF.B28, prefix `1010001`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `op2` is `reg5`: register, 5 bits. `sub` (3 bits) selects the mnemonic: `shr` 000, `sar` 001, `fadd` 010, `fsub` 011, `fmul` 100, `bit` 101, `lea` 110, `movub` 111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`LDF-B28-2`](dictionary/by-encoding.md#LDF-B28-2), [`LDF-X22-2`](dictionary/by-encoding.md#LDF-X22-2), [`LDF-PI12-2`](dictionary/by-encoding.md#LDF-PI12-2), [`LDF-PD12-2`](dictionary/by-encoding.md#LDF-PD12-2), [`LDF-PC32-2`](dictionary/by-encoding.md#LDF-PC32-2), [`LDF-A32-2`](dictionary/by-encoding.md#LDF-A32-2), [`STF-B28-1`](dictionary/by-encoding.md#STF-B28-1), [`STF-X22-1`](dictionary/by-encoding.md#STF-X22-1), [`STF-PI12-1`](dictionary/by-encoding.md#STF-PI12-1), [`STF-PD12-1`](dictionary/by-encoding.md#STF-PD12-1), [`STF-PC32-1`](dictionary/by-encoding.md#STF-PC32-1), [`STF-A32-1`](dictionary/by-encoding.md#STF-A32-1), [`DPF-D28-2`](dictionary/by-encoding.md#DPF-D28-2), [`LDF-B28-3`](dictionary/by-encoding.md#LDF-B28-3), [`LDF-X22-3`](dictionary/by-encoding.md#LDF-X22-3), [`LDF-PI12-3`](dictionary/by-encoding.md#LDF-PI12-3), [`LDF-PD12-3`](dictionary/by-encoding.md#LDF-PD12-3), [`LDF-PC32-3`](dictionary/by-encoding.md#LDF-PC32-3), [`LDF-A32-3`](dictionary/by-encoding.md#LDF-A32-3), [`DPF-D28-3`](dictionary/by-encoding.md#DPF-D28-3), [`LDF-B28-4`](dictionary/by-encoding.md#LDF-B28-4), [`LDF-X22-4`](dictionary/by-encoding.md#LDF-X22-4), [`LDF-PI12-4`](dictionary/by-encoding.md#LDF-PI12-4), [`LDF-PD12-4`](dictionary/by-encoding.md#LDF-PD12-4), [`LDF-PC32-4`](dictionary/by-encoding.md#LDF-PC32-4), [`LDF-A32-4`](dictionary/by-encoding.md#LDF-A32-4), [`DPF-D28-4`](dictionary/by-encoding.md#DPF-D28-4).

**Operation**

```
size = 1, 2, 4 or 8 bytes
load :  Rd ← sext(M[EA(rm)], size)            ; the access may cross an alignment boundary
store:  M[EA(rm)] ← Rs[8×size-1:0]
```

**Flags** None written.

**Exceptions** Page and protection faults and bus errors as for any memory operand; **no alignment fault**.

The ordinary moves fault on a misaligned address (the alignment fault is the tag check of section 9.5); these are the explicit forms for data that is not aligned.

**Why it is here.** Data alignment is architectural on this machine (9.2.11): an ordinary quad access to an address that is not a multiple of 8 aborts, and that abort doubles as the tag check for tagged pointers; a load form that ignores low pointer bits is rejected for that reason. Packed on-disk and network structures still need unaligned access, so the architecture has explicit unaligned forms rather than weakening the rule for every load. No further reason is recorded for these four.

**Cf.** 6.6, 6.4.

<a id="w-movub"></a>
#### MOVUB

![MOVUB: LDF.B28, prefix 1010001, sub-opcode 111; operands b5d28s-x1, reg5; 6 bytes](figures/w/movub/01.svg)

![MOVUB: LDF.X22, prefix 011110, sub-opcode 111; operands x5-5d22s, reg5; 6 bytes](figures/w/movub/02.svg)

![MOVUB: LDF.PC32, prefix 11001100, sub-opcode 111; operands pc32-u1, reg5; 6 bytes](figures/w/movub/05.svg)

![MOVUB: LDF.A32, prefix 11001101, sub-opcode 111; operands abs32, reg5; 6 bytes](figures/w/movub/06.svg)

![MOVUB: STF.B28, prefix 1010111, sub-opcode 100; operands reg5, b5d28s-x1; 6 bytes](figures/w/movub/07.svg)

![MOVUB: STF.X22, prefix 100001, sub-opcode 100; operands reg5, x5-5d22s; 6 bytes](figures/w/movub/08.svg)

![MOVUB: STF.PC32, prefix 11010001, sub-opcode 100; operands reg5, pc32-u1; 6 bytes](figures/w/movub/11.svg)

![MOVUB: STF.A32, prefix 11010010, sub-opcode 100; operands reg5, abs32; 6 bytes](figures/w/movub/12.svg)

![MOVUB: DPF.D28, prefix 111100000110, sub-opcode 111; operands dpd28s-x1, reg5; 6 bytes](figures/w/movub/13.svg)

![MOVUB: LDF.PI12, prefix 1010010, sub-opcode 111; operands pi5-s12, reg5; 4 bytes](figures/w/movub/03.svg)

![MOVUB: LDF.PD12, prefix 1010011, sub-opcode 111; operands pd5-s12, reg5; 4 bytes](figures/w/movub/04.svg)

![MOVUB: STF.PI12, prefix 1011001, sub-opcode 100; operands reg5, pi5-s12; 4 bytes](figures/w/movub/09.svg)

![MOVUB: STF.PD12, prefix 1011010, sub-opcode 100; operands reg5, pd5-s12; 4 bytes](figures/w/movub/10.svg)

Operation, flags and exceptions as for the entry MOVU above; 13 layout forms, each a chart of its own (above).

<a id="w-movuw"></a>
#### MOVUW

![MOVUW: LDF.B28, prefix 110111001, sub-opcode 0; operands b5d28s-x1, reg5; 6 bytes](figures/w/movuw/01.svg)

![MOVUW: LDF.X22, prefix 11001011, sub-opcode 0; operands x5-5d22s, reg5; 6 bytes](figures/w/movuw/02.svg)

![MOVUW: LDF.PC32, prefix 1110100111, sub-opcode 0; operands pc32-u1, reg5; 6 bytes](figures/w/movuw/05.svg)

![MOVUW: LDF.A32, prefix 1110101000, sub-opcode 0; operands abs32, reg5; 6 bytes](figures/w/movuw/06.svg)

![MOVUW: STF.B28, prefix 1010111, sub-opcode 101; operands reg5, b5d28s-x1; 6 bytes](figures/w/movuw/07.svg)

![MOVUW: STF.X22, prefix 100001, sub-opcode 101; operands reg5, x5-5d22s; 6 bytes](figures/w/movuw/08.svg)

![MOVUW: STF.PC32, prefix 11010001, sub-opcode 101; operands reg5, pc32-u1; 6 bytes](figures/w/movuw/11.svg)

![MOVUW: STF.A32, prefix 11010010, sub-opcode 101; operands reg5, abs32; 6 bytes](figures/w/movuw/12.svg)

![MOVUW: DPF.D28, prefix 11110010001101, sub-opcode 0; operands dpd28s-x1, reg5; 6 bytes](figures/w/movuw/13.svg)

![MOVUW: LDF.PI12, prefix 110111011, sub-opcode 0; operands pi5-s12, reg5; 4 bytes](figures/w/movuw/03.svg)

![MOVUW: LDF.PD12, prefix 110111100, sub-opcode 0; operands pd5-s12, reg5; 4 bytes](figures/w/movuw/04.svg)

![MOVUW: STF.PI12, prefix 1011001, sub-opcode 101; operands reg5, pi5-s12; 4 bytes](figures/w/movuw/09.svg)

![MOVUW: STF.PD12, prefix 1011010, sub-opcode 101; operands reg5, pd5-s12; 4 bytes](figures/w/movuw/10.svg)

```
MOVUW, MOVUL, MOVUB likewise
```

Operation, flags and exceptions as for the entry MOVU above; 13 layout forms, each a chart of its own (above).

<a id="w-movul"></a>
#### MOVUL

![MOVUL: LDF.B28, prefix 110111001, sub-opcode 1; operands b5d28s-x1, reg5; 6 bytes](figures/w/movul/01.svg)

![MOVUL: LDF.X22, prefix 11001011, sub-opcode 1; operands x5-5d22s, reg5; 6 bytes](figures/w/movul/02.svg)

![MOVUL: LDF.PC32, prefix 1110100111, sub-opcode 1; operands pc32-u1, reg5; 6 bytes](figures/w/movul/05.svg)

![MOVUL: LDF.A32, prefix 1110101000, sub-opcode 1; operands abs32, reg5; 6 bytes](figures/w/movul/06.svg)

![MOVUL: STF.B28, prefix 1010111, sub-opcode 110; operands reg5, b5d28s-x1; 6 bytes](figures/w/movul/07.svg)

![MOVUL: STF.X22, prefix 100001, sub-opcode 110; operands reg5, x5-5d22s; 6 bytes](figures/w/movul/08.svg)

![MOVUL: STF.PC32, prefix 11010001, sub-opcode 110; operands reg5, pc32-u1; 6 bytes](figures/w/movul/11.svg)

![MOVUL: STF.A32, prefix 11010010, sub-opcode 110; operands reg5, abs32; 6 bytes](figures/w/movul/12.svg)

![MOVUL: DPF.D28, prefix 11110010001101, sub-opcode 1; operands dpd28s-x1, reg5; 6 bytes](figures/w/movul/13.svg)

![MOVUL: LDF.PI12, prefix 110111011, sub-opcode 1; operands pi5-s12, reg5; 4 bytes](figures/w/movul/03.svg)

![MOVUL: LDF.PD12, prefix 110111100, sub-opcode 1; operands pd5-s12, reg5; 4 bytes](figures/w/movul/04.svg)

![MOVUL: STF.PI12, prefix 1011001, sub-opcode 110; operands reg5, pi5-s12; 4 bytes](figures/w/movul/09.svg)

![MOVUL: STF.PD12, prefix 1011010, sub-opcode 110; operands reg5, pd5-s12; 4 bytes](figures/w/movul/10.svg)

Operation, flags and exceptions as for the entry MOVU above; 13 layout forms, each a chart of its own (above).

<a id="w-movuq"></a>
#### MOVUQ

![MOVUQ: LDF.B28, prefix 1110100100; operands b5d28s-x1, reg5; 6 bytes](figures/w/movuq/01.svg)

![MOVUQ: LDF.X22, prefix 110111010; operands x5-5d22s, reg5; 6 bytes](figures/w/movuq/02.svg)

![MOVUQ: LDF.PC32, prefix 11101110101; operands pc32-u1, reg5; 6 bytes](figures/w/movuq/05.svg)

![MOVUQ: LDF.A32, prefix 11101110110; operands abs32, reg5; 6 bytes](figures/w/movuq/06.svg)

![MOVUQ: STF.B28, prefix 1010111, sub-opcode 111; operands reg5, b5d28s-x1; 6 bytes](figures/w/movuq/07.svg)

![MOVUQ: STF.X22, prefix 100001, sub-opcode 111; operands reg5, x5-5d22s; 6 bytes](figures/w/movuq/08.svg)

![MOVUQ: STF.PC32, prefix 11010001, sub-opcode 111; operands reg5, pc32-u1; 6 bytes](figures/w/movuq/11.svg)

![MOVUQ: STF.A32, prefix 11010010, sub-opcode 111; operands reg5, abs32; 6 bytes](figures/w/movuq/12.svg)

![MOVUQ: DPF.D28, prefix 111100101110010; operands dpd28s-x1, reg5; 6 bytes](figures/w/movuq/13.svg)

![MOVUQ: LDF.PI12, prefix 1110100101; operands pi5-s12, reg5; 4 bytes](figures/w/movuq/03.svg)

![MOVUQ: LDF.PD12, prefix 1110100110; operands pd5-s12, reg5; 4 bytes](figures/w/movuq/04.svg)

![MOVUQ: STF.PI12, prefix 1011001, sub-opcode 111; operands reg5, pi5-s12; 4 bytes](figures/w/movuq/09.svg)

![MOVUQ: STF.PD12, prefix 1011010, sub-opcode 111; operands reg5, pd5-s12; 4 bytes](figures/w/movuq/10.svg)

```
MOVUQ rm, Rd
MOVUQ Rs, rm
```

Operation, flags and exceptions as for the entry MOVU above; 13 layout forms, each a chart of its own (above).


<a id="w-mov2"></a>
### MOV2: Two register moves

![MOV2: FX.MOV2, prefix 0011; operands reg3, reg3, reg3, reg3; 2 bytes](figures/w/mov2/01.svg)

**Mnemonics:** `MOV2`

**Syntax**

```
MOV2 Ra, Rb, Rc, Rd
```

**Encoding**

![Encoding of MOV2](figures/FX-MOV2-1.svg)

The chart is the leaf `FX-MOV2-1`, FX.MOV2, prefix `0011`. `op1` is `reg3`: register, 3 bits (an index into the hot-register table). `op2` is `reg3`: register, 3 bits (an index into the hot-register table). `op3` is `reg3`: register, 3 bits (an index into the hot-register table). `op4` is `reg3`: register, 3 bits (an index into the hot-register table).

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`FX-MOV2-1`](dictionary/by-encoding.md#FX-MOV2-1).

**Operation**

```
Rb ← Ra
Rd ← Rc           ; in this order
```

**Flags** None written.

**Exceptions** None.

*(D)* `MOVQ Ra, Rb` followed by `MOVQ Rc, Rd`, fused (errata 87). The four operands are 3-bit fields: only the eight hot registers (`R0 R1 R8 R2 SP R3 R9 R10`, the ABI table of the encoding) can be named, and the instruction takes one sixteenth of the first-parcel space, which is why the grammar gives it a prefix of four bits. If `Rb` is `Rc` the second move reads the new value, as two instructions would.

**Why it is here.** The author decided the four fused pairs in errata 87 (`movcall`, `popmret`, `popret`, `mov2`) and left the fusing to the compiler: the assembler never fuses. The reason is the measurement of `docs/encoding-proposal.md` section 8 (static size of the training corpus, in the encoding): `MOVQ Ra, Rb` followed by `MOVQ Rc, Rd` occurs 6,742 times and saves 0.50%, the smallest gain of the four and the dearest in code space: four 3-bit register fields use one sixteenth of the first-parcel space and can name only the eight hot registers. The encoding study lists both as costs, and one instruction that writes two registers (the rename width of an out-of-order core).

**Cf.** Appendix D (the hot-register tables).


<a id="w-movql"></a>
### MOVQL: Move a 64-bit literal

![MOVQL: MOVQL, prefix 11101110100; operands imm64s, reg5; 10 bytes](figures/w/movql/01.svg)

**Mnemonics:** `MOVQL`

**Syntax**

```
MOVQL #imm64, Rd
```

**Encoding**

![Encoding of MOVQL](figures/MOVQL-1.svg)

The chart is the leaf `MOVQL-1`, MOVQL, prefix `11101110100`. `op1` is `imm64s`: signed 64-bit immediate, -9223372036854775808 to 9223372036854775807. `op2` is `reg5`: register, 5 bits.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`MOVQL-1`](dictionary/by-encoding.md#MOVQL-1).

**Operation**

```
Rd ← imm64
```

**Flags** None written.

**Exceptions** None.

*(D)* Errata 85: `MOVQL #imm64, Rd` is accepted, and breaking the three-parcel rule for it is acceptable because a 64-bit literal is not counted as part of the instruction. The instruction is five parcels, ten bytes: the literal is inside the instruction, so the length is still known from parcel 0 and the fetch has no exception for a trailing literal (`docs/encoding-proposal.md` section 3). The assembler uses it for a `MOVQ #imm, Rd` that fits no `MOVQ` form (errata 87, assumption 6).

**Why it is here.** The author accepted it in the second round of security answers (errata 85, proposal P18). A 64-bit constant otherwise comes from the literal pool; the literal inside the instruction is one instruction, and it is not counted against the three-parcel rule because it is data, not instruction. The encoding work found no use of a trailing literal worth its exception to the fetch rule, so the literal is part of a five-parcel instruction (`docs/encoding-proposal.md` section 3).


### MOVD: Deferred-fault load

**Mnemonics:** `MOVQ.D`, `MOVL.D`, `MOVW.D`, `MOVB.D`, `MOVZL.D`, `MOVZW.D`, `MOVZB.D`

**Syntax**

```
MOVQ.D d(Rn), Rd
MOVL.D ..., MOVW.D ..., MOVB.D ...
MOVZL.D ..., MOVZW.D ..., MOVZB.D ...
```

**Encoding**

![Encoding of MOVD](figures/LDU-B28-1.svg)

The chart is the leaf `LDU-B28-1`, LDU.B28, prefix `011011`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `op2` is `reg5`: register, 5 bits. `sub` (4 bits) selects the mnemonic: `movq.u` 0000, `movl.u` 0001, `movw.u` 0010, `movb.u` 0011, `movzl.u` 0100, `movzw.u` 0101, `movzb.u` 0110, `movq.d` 0111, `movl.d` 1000, `movw.d` 1001, `movb.d` 1010, `movzl.d` 1011, `movzw.d` 1100, `movzb.d` 1101, `movq.ud` 1110, `movl.ud` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`LDU-B28-1`](dictionary/by-encoding.md#LDU-B28-1), [`LDU-B12-1`](dictionary/by-encoding.md#LDU-B12-1), [`LDU-X6-1`](dictionary/by-encoding.md#LDU-X6-1).

**Operation**

```
Rd ← M[EA]                     ; as the load without .D, when the access succeeds
when the access faults: the fault is precise as always; the kernel's handler repairs the cause and restarts,
    or, if the access is invalid, marks Rd as poisoned in the saved state and goes on at the next instruction
```

**Flags** None written.

**Exceptions** The ordinary faults of a load (page fault, protection fault, alignment fault, bus error), precise; what the handler does with them is the difference.

*(D)* The deferred-fault load is item 10 of `docs/study-proposals.md` (the poison bit), whose three leanings the author accepted (errata 86): the fault is taken at the instruction that writes the flags from a poisoned source; the kernel decides a deferred load's fault; the kernel dispatcher, not the hardware, tests the argument registers for poison. Base and indexed operands only (a mode that needs a base register needs `LEA` first). Details pending ([J.9.12](appendix-j-open.md#j912)).

**Why it is here.** The poison bit of item 10 of the study (`docs/study-proposals.md`) wants a load that can be hoisted above its guard: it either gives a value or a poisoned value, and a use of a poisoned value is the fault the guard would have prevented. That removes the recovery code of if-conversion and software pipelining, gives a deterministic Spectre version 1 form (a deferred, bounds-checked address computation yields poison, not a branch the predictor can train), and makes a chain of checks one fault. The author accepted the three leanings of the proposal (errata 86).

**Cf.** 6.4, docs/study-proposals.md item 10.

<a id="w-movq-d"></a>
#### MOVQ.D

![MOVQ.D: LDU.B28, prefix 011011, sub-opcode 0111; operands b5d28s-x1, reg5; 6 bytes](figures/w/movq-d/01.svg)

![MOVQ.D: LDU.B12, prefix 011100, sub-opcode 0111; operands b5d12s-x1, reg5; 4 bytes](figures/w/movq-d/02.svg)

![MOVQ.D: LDU.X6, prefix 01000, sub-opcode 0111; operands x5-5d6s, reg5; 4 bytes](figures/w/movq-d/03.svg)

```
MOVQ.D d(Rn), Rd
```

Operation, flags and exceptions as for the entry MOVD above; 3 layout forms, each a chart of its own (above).

<a id="w-movl-d"></a>
#### MOVL.D

![MOVL.D: LDU.B28, prefix 011011, sub-opcode 1000; operands b5d28s-x1, reg5; 6 bytes](figures/w/movl-d/01.svg)

![MOVL.D: LDU.B12, prefix 011100, sub-opcode 1000; operands b5d12s-x1, reg5; 4 bytes](figures/w/movl-d/02.svg)

![MOVL.D: LDU.X6, prefix 01000, sub-opcode 1000; operands x5-5d6s, reg5; 4 bytes](figures/w/movl-d/03.svg)

```
MOVL.D ..., MOVW.D ..., MOVB.D ...
```

Operation, flags and exceptions as for the entry MOVD above; 3 layout forms, each a chart of its own (above).

<a id="w-movw-d"></a>
#### MOVW.D

![MOVW.D: LDU.B28, prefix 011011, sub-opcode 1001; operands b5d28s-x1, reg5; 6 bytes](figures/w/movw-d/01.svg)

![MOVW.D: LDU.B12, prefix 011100, sub-opcode 1001; operands b5d12s-x1, reg5; 4 bytes](figures/w/movw-d/02.svg)

![MOVW.D: LDU.X6, prefix 01000, sub-opcode 1001; operands x5-5d6s, reg5; 4 bytes](figures/w/movw-d/03.svg)

Operation, flags and exceptions as for the entry MOVD above; 3 layout forms, each a chart of its own (above).

<a id="w-movb-d"></a>
#### MOVB.D

![MOVB.D: LDU.B28, prefix 011011, sub-opcode 1010; operands b5d28s-x1, reg5; 6 bytes](figures/w/movb-d/01.svg)

![MOVB.D: LDU.B12, prefix 011100, sub-opcode 1010; operands b5d12s-x1, reg5; 4 bytes](figures/w/movb-d/02.svg)

![MOVB.D: LDU.X6, prefix 01000, sub-opcode 1010; operands x5-5d6s, reg5; 4 bytes](figures/w/movb-d/03.svg)

Operation, flags and exceptions as for the entry MOVD above; 3 layout forms, each a chart of its own (above).

<a id="w-movzl-d"></a>
#### MOVZL.D

![MOVZL.D: LDU.B28, prefix 011011, sub-opcode 1011; operands b5d28s-x1, reg5; 6 bytes](figures/w/movzl-d/01.svg)

![MOVZL.D: LDU.B12, prefix 011100, sub-opcode 1011; operands b5d12s-x1, reg5; 4 bytes](figures/w/movzl-d/02.svg)

![MOVZL.D: LDU.X6, prefix 01000, sub-opcode 1011; operands x5-5d6s, reg5; 4 bytes](figures/w/movzl-d/03.svg)

```
MOVZL.D ..., MOVZW.D ..., MOVZB.D ...
```

Operation, flags and exceptions as for the entry MOVD above; 3 layout forms, each a chart of its own (above).

<a id="w-movzw-d"></a>
#### MOVZW.D

![MOVZW.D: LDU.B28, prefix 011011, sub-opcode 1100; operands b5d28s-x1, reg5; 6 bytes](figures/w/movzw-d/01.svg)

![MOVZW.D: LDU.B12, prefix 011100, sub-opcode 1100; operands b5d12s-x1, reg5; 4 bytes](figures/w/movzw-d/02.svg)

![MOVZW.D: LDU.X6, prefix 01000, sub-opcode 1100; operands x5-5d6s, reg5; 4 bytes](figures/w/movzw-d/03.svg)

Operation, flags and exceptions as for the entry MOVD above; 3 layout forms, each a chart of its own (above).

<a id="w-movzb-d"></a>
#### MOVZB.D

![MOVZB.D: LDU.B28, prefix 011011, sub-opcode 1101; operands b5d28s-x1, reg5; 6 bytes](figures/w/movzb-d/01.svg)

![MOVZB.D: LDU.B12, prefix 011100, sub-opcode 1101; operands b5d12s-x1, reg5; 4 bytes](figures/w/movzb-d/02.svg)

![MOVZB.D: LDU.X6, prefix 01000, sub-opcode 1101; operands x5-5d6s, reg5; 4 bytes](figures/w/movzb-d/03.svg)

Operation, flags and exceptions as for the entry MOVD above; 3 layout forms, each a chart of its own (above).


### MOVUSER: User-qualified load and store

**Mnemonics:** `MOVQ.U`, `MOVL.U`, `MOVW.U`, `MOVB.U`, `MOVZL.U`, `MOVZW.U`, `MOVZB.U`

**Syntax**

```
MOVQ.U d(Rn), Rd
MOVQ.U Rs, d(Rn)
MOVL.U ..., MOVW.U ..., MOVB.U ...
MOVZL.U ..., MOVZW.U ..., MOVZB.U ...    ; loads only
```

**Encoding**

![Encoding of MOVUSER](figures/LDU-B28-1.svg)

The chart is the leaf `LDU-B28-1`, LDU.B28, prefix `011011`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `op2` is `reg5`: register, 5 bits. `sub` (4 bits) selects the mnemonic: `movq.u` 0000, `movl.u` 0001, `movw.u` 0010, `movb.u` 0011, `movzl.u` 0100, `movzw.u` 0101, `movzb.u` 0110, `movq.d` 0111, `movl.d` 1000, `movw.d` 1001, `movb.d` 1010, `movzl.d` 1011, `movzw.d` 1100, `movzb.d` 1101, `movq.ud` 1110, `movl.ud` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`LDU-B28-1`](dictionary/by-encoding.md#LDU-B28-1), [`STU-B28-1`](dictionary/by-encoding.md#STU-B28-1), [`LDU-B12-1`](dictionary/by-encoding.md#LDU-B12-1), [`STU-B12-1`](dictionary/by-encoding.md#STU-B12-1), [`LDU-X6-1`](dictionary/by-encoding.md#LDU-X6-1), [`STU-X6-1`](dictionary/by-encoding.md#STU-X6-1).

**Operation**

```
the access of MOVQ, MOVL, MOVW, MOVB and MOVZ* with the operand checked as a user-mode access:
the page must be present, have U = 1, and permit R (a load) or W (a store); a kernel page takes the protection abort
whatever PSW.UA says
```

**Flags** None written.

**Exceptions** The faults of the access, as a user-mode access. In user mode the encoding is a privileged-instruction abort.

*(D)* Item 18 of `docs/study-proposals.md`: user access is an attribute of one memory operand, so it cannot outlive the instruction, cannot leak across an interrupt, and `RTI` re-executes the instruction with the attribute. The author accepted the five leanings (errata 86): a fixup table in place of `pcb_onfault`, the `.U` spelling, keeping `PSW.UA`, `STUA` and `CLUA` until the OpenBSD port confirms, `ECAUSE` bit 15 to say that the access was user-qualified, and the atomics taking the user form once the operand placement of `ATOM` is fixed. (Not to be confused with `MOVU`, the unaligned move.) Details pending ([J.9.12](appendix-j-open.md#j912)).

**Why it is here.** Copying between the kernel and the user is where kernels pay for the user-memory guard. x86 opens a window with `STAC` and closes it with `CLAC` (35 and 53 sites in the kernel-assembly corpus), and a forgotten `CLAC` on an error path is the bug class; Arm's `LDTR` and `STTR` make the access itself unprivileged (52 sites), but only for plain loads and stores. Item 18 of the study makes user access an attribute of one operand, so that no window exists to leave open and the range check of the copy routines (`addr + len` against the top of the user half) disappears into the hardware: a kernel address faults at the first byte. The author accepted its five leanings (errata 86) and kept `PSW.UA`, `STUA` and `CLUA` until the OpenBSD port confirms.

**Cf.** 6.10 (the user-memory guard), docs/study-proposals.md item 18.

<a id="w-movq-u"></a>
#### MOVQ.U

![MOVQ.U: LDU.B28, prefix 011011, sub-opcode 0000; operands b5d28s-x1, reg5; 6 bytes](figures/w/movq-u/01.svg)

![MOVQ.U: STU.B28, prefix 11001000, sub-opcode 00; operands reg5, b5d28s-x1; 6 bytes](figures/w/movq-u/02.svg)

![MOVQ.U: LDU.B12, prefix 011100, sub-opcode 0000; operands b5d12s-x1, reg5; 4 bytes](figures/w/movq-u/03.svg)

![MOVQ.U: STU.B12, prefix 11001010, sub-opcode 00; operands reg5, b5d12s-x1; 4 bytes](figures/w/movq-u/04.svg)

![MOVQ.U: LDU.X6, prefix 01000, sub-opcode 0000; operands x5-5d6s, reg5; 4 bytes](figures/w/movq-u/05.svg)

![MOVQ.U: STU.X6, prefix 1010000, sub-opcode 00; operands reg5, x5-5d6s; 4 bytes](figures/w/movq-u/06.svg)

```
MOVQ.U d(Rn), Rd
MOVQ.U Rs, d(Rn)
```

Operation, flags and exceptions as for the entry MOVUSER above; 6 layout forms, each a chart of its own (above).

<a id="w-movl-u"></a>
#### MOVL.U

![MOVL.U: LDU.B28, prefix 011011, sub-opcode 0001; operands b5d28s-x1, reg5; 6 bytes](figures/w/movl-u/01.svg)

![MOVL.U: STU.B28, prefix 11001000, sub-opcode 01; operands reg5, b5d28s-x1; 6 bytes](figures/w/movl-u/02.svg)

![MOVL.U: LDU.B12, prefix 011100, sub-opcode 0001; operands b5d12s-x1, reg5; 4 bytes](figures/w/movl-u/03.svg)

![MOVL.U: STU.B12, prefix 11001010, sub-opcode 01; operands reg5, b5d12s-x1; 4 bytes](figures/w/movl-u/04.svg)

![MOVL.U: LDU.X6, prefix 01000, sub-opcode 0001; operands x5-5d6s, reg5; 4 bytes](figures/w/movl-u/05.svg)

![MOVL.U: STU.X6, prefix 1010000, sub-opcode 01; operands reg5, x5-5d6s; 4 bytes](figures/w/movl-u/06.svg)

```
MOVL.U ..., MOVW.U ..., MOVB.U ...
```

Operation, flags and exceptions as for the entry MOVUSER above; 6 layout forms, each a chart of its own (above).

<a id="w-movw-u"></a>
#### MOVW.U

![MOVW.U: LDU.B28, prefix 011011, sub-opcode 0010; operands b5d28s-x1, reg5; 6 bytes](figures/w/movw-u/01.svg)

![MOVW.U: STU.B28, prefix 11001000, sub-opcode 10; operands reg5, b5d28s-x1; 6 bytes](figures/w/movw-u/02.svg)

![MOVW.U: LDU.B12, prefix 011100, sub-opcode 0010; operands b5d12s-x1, reg5; 4 bytes](figures/w/movw-u/03.svg)

![MOVW.U: STU.B12, prefix 11001010, sub-opcode 10; operands reg5, b5d12s-x1; 4 bytes](figures/w/movw-u/04.svg)

![MOVW.U: LDU.X6, prefix 01000, sub-opcode 0010; operands x5-5d6s, reg5; 4 bytes](figures/w/movw-u/05.svg)

![MOVW.U: STU.X6, prefix 1010000, sub-opcode 10; operands reg5, x5-5d6s; 4 bytes](figures/w/movw-u/06.svg)

Operation, flags and exceptions as for the entry MOVUSER above; 6 layout forms, each a chart of its own (above).

<a id="w-movb-u"></a>
#### MOVB.U

![MOVB.U: LDU.B28, prefix 011011, sub-opcode 0011; operands b5d28s-x1, reg5; 6 bytes](figures/w/movb-u/01.svg)

![MOVB.U: STU.B28, prefix 11001000, sub-opcode 11; operands reg5, b5d28s-x1; 6 bytes](figures/w/movb-u/02.svg)

![MOVB.U: LDU.B12, prefix 011100, sub-opcode 0011; operands b5d12s-x1, reg5; 4 bytes](figures/w/movb-u/03.svg)

![MOVB.U: STU.B12, prefix 11001010, sub-opcode 11; operands reg5, b5d12s-x1; 4 bytes](figures/w/movb-u/04.svg)

![MOVB.U: LDU.X6, prefix 01000, sub-opcode 0011; operands x5-5d6s, reg5; 4 bytes](figures/w/movb-u/05.svg)

![MOVB.U: STU.X6, prefix 1010000, sub-opcode 11; operands reg5, x5-5d6s; 4 bytes](figures/w/movb-u/06.svg)

Operation, flags and exceptions as for the entry MOVUSER above; 6 layout forms, each a chart of its own (above).

<a id="w-movzl-u"></a>
#### MOVZL.U

![MOVZL.U: LDU.B28, prefix 011011, sub-opcode 0100; operands b5d28s-x1, reg5; 6 bytes](figures/w/movzl-u/01.svg)

![MOVZL.U: LDU.B12, prefix 011100, sub-opcode 0100; operands b5d12s-x1, reg5; 4 bytes](figures/w/movzl-u/02.svg)

![MOVZL.U: LDU.X6, prefix 01000, sub-opcode 0100; operands x5-5d6s, reg5; 4 bytes](figures/w/movzl-u/03.svg)

```
MOVZL.U ..., MOVZW.U ..., MOVZB.U ...
```

Operation, flags and exceptions as for the entry MOVUSER above; 3 layout forms, each a chart of its own (above).

<a id="w-movzw-u"></a>
#### MOVZW.U

![MOVZW.U: LDU.B28, prefix 011011, sub-opcode 0101; operands b5d28s-x1, reg5; 6 bytes](figures/w/movzw-u/01.svg)

![MOVZW.U: LDU.B12, prefix 011100, sub-opcode 0101; operands b5d12s-x1, reg5; 4 bytes](figures/w/movzw-u/02.svg)

![MOVZW.U: LDU.X6, prefix 01000, sub-opcode 0101; operands x5-5d6s, reg5; 4 bytes](figures/w/movzw-u/03.svg)

Operation, flags and exceptions as for the entry MOVUSER above; 3 layout forms, each a chart of its own (above).

<a id="w-movzb-u"></a>
#### MOVZB.U

![MOVZB.U: LDU.B28, prefix 011011, sub-opcode 0110; operands b5d28s-x1, reg5; 6 bytes](figures/w/movzb-u/01.svg)

![MOVZB.U: LDU.B12, prefix 011100, sub-opcode 0110; operands b5d12s-x1, reg5; 4 bytes](figures/w/movzb-u/02.svg)

![MOVZB.U: LDU.X6, prefix 01000, sub-opcode 0110; operands x5-5d6s, reg5; 4 bytes](figures/w/movzb-u/03.svg)

Operation, flags and exceptions as for the entry MOVUSER above; 3 layout forms, each a chart of its own (above).
<!-- /entries:9.6 -->

## 9.7 Integer arithmetic

*Cf. section 6.3 for the divide-by-zero vector (`DIV`, `DIVU`, `MOD`, `MODU`).*

**9.7.1** `ADD`, `SUB`, `CMP`, `MUL` and `MULH` are two bytes with register operands; `MULHU` (high half of an unsigned product), `DIV`, `DIVU`, `MOD` and `MODU` are in the arithmetic escape. *(D)*

**9.7.2** `CMP` is written `CMP Rd, rm`, register first, and computes `Rd - rm`. *(D)*

**9.7.3** `ADD` sets `C` on a carry; `SUB` and `CMP` set `C` on a borrow, the PDP-11 sense, so `BHIS` and `BCC` mean "no borrow", unsigned greater or equal. *(D)*

**9.7.4** `ADC` and `SBC` add and subtract the carry; `INC`, `DEC`, `NEG`, `CLR` and `TST` are single-operand forms that work on a register or memory.

**9.7.5** `SET cc, Rd` (write 1 if the condition holds, else 0) is in the arithmetic escape. *(D)*

**9.7.6** `ABS`, `MIN`, `MINU`, `MAX` and `MAXU` are assembler aliases, not native instructions: `ABS` is the absolute value, and the others the smaller or the larger of two registers, signed or unsigned. *(D)* Open: their expansion, and with it the flags they leave ([J.9.1](appendix-j-open.md#j91)).

*Commentary.* **Precedent.** `ADD`, `SUB`, `CMP`, `BIT`, `BIS`, `BIC` and the single-operand set are the PDP-11's, unchanged in name and meaning except for the order of `CMP`'s operands. **Trade-offs.** The PDP-11 wrote `CMP a, b` to compute `a - b`; since the destination of an ALU operation here must be a register, a literal `src, dst` reading would force every comparison against an immediate or memory to be reversed, so the register comes first. Divide is in the escape group, at four bytes, because compilers turn division by a constant into `MULH` plus a shift, so a real divide is rare. **Improvements.** The high-half multiply that bignum code needs is present; a second unsigned multiply is the same instruction as the first and is not provided. **Benefits.** `SET` replaces a branch around a move for the very common "store the truth value of a comparison", and absolute value, minimum and maximum (as aliases) remove a compare-and-branch from small loops. **Modern comparables.** RISC-V has `MULH`, `MULHU` and `MULHSU`, and AArch64 `SMULH` and `UMULH`; x86 has a one-operand multiply that produces both halves; AArch64's conditional select and set instructions are the nearest to `SET`. **Use.** `MULH` and `MULHU` are for multi-precision arithmetic and for division by constants; `ADC` and `SBC` carry a multi-word add or subtract; `MIN`, `MAX` and `ABS` (aliases) appear under a tenth of a percent of compiled code but each replaces a branch. **Impact.** *Kernel:* `ADC` and `SBC` carry multiword arithmetic for the kernel's 128-bit counters and for the bignum code in the base system. *Compiler:* `MULH` turns division by a constant into a multiply and a shift; `SET` materialises a comparison without a branch; `CMP` takes the register first, as the compiler orders its operands. *Hardware:* One adder on the carry chain; on an FPGA the multiplier is built from two to four multiplier blocks over four to eight cycles; the divide is a sequencer.

<!-- entries:9.7 -->
<a id="w-add"></a>
### ADD: Add

![ADD: LDF.B28, prefix 011101, sub-opcode 0111; operands b5d28s-x1, reg5; 6 bytes](figures/w/add/01.svg)

![ADD: LDF.X22, prefix 01001, sub-opcode 0111; operands x5-5d22s, reg5; 6 bytes](figures/w/add/02.svg)

![ADD: LDF.PC32, prefix 1010100, sub-opcode 0111; operands pc32-u1, reg5; 6 bytes](figures/w/add/05.svg)

![ADD: LDF.A32, prefix 1010101, sub-opcode 0111; operands abs32, reg5; 6 bytes](figures/w/add/06.svg)

![ADD: LDFI.I32, prefix 1010110, sub-opcode 0000; operands imm32s, reg5; 6 bytes](figures/w/add/07.svg)

![ADD: DPF.D28, prefix 11101111010, sub-opcode 0111; operands dpd28s-x1, reg5; 6 bytes](figures/w/add/08.svg)

![ADD: SPADJF, prefix 111100101110110, sub-opcode 0; operands imm32s, k-sp; 6 bytes](figures/w/add/11.svg)

![ADD: LDF.PI12, prefix 011111, sub-opcode 0111; operands pi5-s12, reg5; 4 bytes](figures/w/add/03.svg)

![ADD: LDF.PD12, prefix 100000, sub-opcode 0111; operands pd5-s12, reg5; 4 bytes](figures/w/add/04.svg)

![ADD: RRF5, prefix 1111001100100101, sub-opcode 000111; operands reg5, reg5; 4 bytes](figures/w/add/10.svg)

![ADD: LDI12H/b, prefix 111100101111001, sub-opcode 0; operands imm12s, reg4; 4 bytes](figures/w/add/13.svg)

![ADD: LDBu6/c, prefix 11110010011011, sub-opcode 00; operands b5d6u-xsz, reg5; 4 bytes](figures/w/add/14.svg)

![ADD: LDBu8H/c, prefix 1111000110011, sub-opcode 00; operands b4d8u-xsz, reg5; 4 bytes](figures/w/add/16.svg)

![ADD: LDI14H/b, prefix 1111000110101, sub-opcode 0; operands imm14s, reg4; 4 bytes](figures/w/add/17.svg)

![ADD: LDS12H/c, prefix 11110010101001, sub-opcode 00; operands spd12u-xsz, reg4; 4 bytes](figures/w/add/18.svg)

![ADD: LDI18H/b, prefix 111001100, sub-opcode 0; operands imm18s, reg4; 4 bytes](figures/w/add/20.svg)

![ADD: LDI12/b, prefix 11110010101011, sub-opcode 0; operands imm12s, reg5; 4 bytes](figures/w/add/21.svg)

![ADD: LDX0/c, prefix 1111000111011, sub-opcode 00; operands x5-5d0s, reg5; 4 bytes](figures/w/add/22.svg)

![ADD: LDPC16H/c, prefix 1110110101, sub-opcode 00; operands pc16-u1, reg4; 4 bytes](figures/w/add/23.svg)

![ADD: LDBu8/c, prefix 111100010011, sub-opcode 00; operands b5d8u-xsz, reg5; 4 bytes](figures/w/add/24.svg)

![ADD: RRF, prefix 0010, sub-opcode 0111; operands reg4, reg4; 2 bytes](figures/w/add/09.svg)

![ADD: RR5, prefix 000, sub-opcode 010; operands reg5, reg5; 2 bytes](figures/w/add/12.svg)

![ADD: SPADJ6/a, prefix 111000111, sub-opcode 0; operands imm6u-x8, k-sp; 2 bytes](figures/w/add/15.svg)

![ADD: IMMh43/b, prefix 11011010, sub-opcode 0; operands imm3s, reg4; 2 bytes](figures/w/add/19.svg)

**Mnemonics:** `ADD`

**Syntax**

```
ADD rm, Rd
```

**Encoding**

![Encoding of ADD](figures/LDF-B28-1.svg)

The chart is the leaf `LDF-B28-1`, LDF.B28, prefix `011101`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `op2` is `reg5`: register, 5 bits. `sub` (4 bits) selects the mnemonic: `movq` 0000, `movl` 0001, `movw` 0010, `movb` 0011, `movzl` 0100, `movzw` 0101, `movzb` 0110, `add` 0111, `sub` 1000, `bic` 1001, `bis` 1010, `xor` 1011, `and` 1100, `mul` 1101, `mulh` 1110, `shl` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`LDF-B28-1`](dictionary/by-encoding.md#LDF-B28-1), [`LDF-X22-1`](dictionary/by-encoding.md#LDF-X22-1), [`LDF-PI12-1`](dictionary/by-encoding.md#LDF-PI12-1), [`LDF-PD12-1`](dictionary/by-encoding.md#LDF-PD12-1), [`LDF-PC32-1`](dictionary/by-encoding.md#LDF-PC32-1), [`LDF-A32-1`](dictionary/by-encoding.md#LDF-A32-1), [`LDFI-I32-1`](dictionary/by-encoding.md#LDFI-I32-1), [`DPF-D28-1`](dictionary/by-encoding.md#DPF-D28-1), [`RRF-1`](dictionary/by-encoding.md#RRF-1), [`RRF5-1`](dictionary/by-encoding.md#RRF5-1), [`SPADJF-1`](dictionary/by-encoding.md#SPADJF-1), [`RR5-1`](dictionary/by-encoding.md#RR5-1), [`LDI12H-b-1`](dictionary/by-encoding.md#LDI12H-b-1), [`LDBu6-c-1`](dictionary/by-encoding.md#LDBu6-c-1), [`SPADJ6-a-1`](dictionary/by-encoding.md#SPADJ6-a-1), [`LDBu8H-c-1`](dictionary/by-encoding.md#LDBu8H-c-1), [`LDI14H-b-1`](dictionary/by-encoding.md#LDI14H-b-1), [`LDS12H-c-1`](dictionary/by-encoding.md#LDS12H-c-1), [`IMMh43-b-1`](dictionary/by-encoding.md#IMMh43-b-1), [`LDI18H-b-1`](dictionary/by-encoding.md#LDI18H-b-1), [`LDI12-b-1`](dictionary/by-encoding.md#LDI12-b-1), [`LDX0-c-1`](dictionary/by-encoding.md#LDX0-c-1), [`LDPC16H-c-1`](dictionary/by-encoding.md#LDPC16H-c-1), [`LDBu8-c-1`](dictionary/by-encoding.md#LDBu8-c-1).

**Operation**

```
Rd ← Rd + rm
```

**Flags** `N` and `Z` from the result, `V` set on signed overflow, `C` set on a carry out of bit 63.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

All ALU operations are 64 bits, with no size field.


<a id="w-sub"></a>
### SUB: Subtract

![SUB: LDF.B28, prefix 011101, sub-opcode 1000; operands b5d28s-x1, reg5; 6 bytes](figures/w/sub/01.svg)

![SUB: LDF.X22, prefix 01001, sub-opcode 1000; operands x5-5d22s, reg5; 6 bytes](figures/w/sub/02.svg)

![SUB: LDF.PC32, prefix 1010100, sub-opcode 1000; operands pc32-u1, reg5; 6 bytes](figures/w/sub/05.svg)

![SUB: LDF.A32, prefix 1010101, sub-opcode 1000; operands abs32, reg5; 6 bytes](figures/w/sub/06.svg)

![SUB: LDFI.I32, prefix 1010110, sub-opcode 0001; operands imm32s, reg5; 6 bytes](figures/w/sub/07.svg)

![SUB: DPF.D28, prefix 11101111010, sub-opcode 1000; operands dpd28s-x1, reg5; 6 bytes](figures/w/sub/08.svg)

![SUB: SPADJF, prefix 111100101110110, sub-opcode 1; operands imm32s, k-sp; 6 bytes](figures/w/sub/11.svg)

![SUB: LDF.PI12, prefix 011111, sub-opcode 1000; operands pi5-s12, reg5; 4 bytes](figures/w/sub/03.svg)

![SUB: LDF.PD12, prefix 100000, sub-opcode 1000; operands pd5-s12, reg5; 4 bytes](figures/w/sub/04.svg)

![SUB: RRF5, prefix 1111001100100101, sub-opcode 001000; operands reg5, reg5; 4 bytes](figures/w/sub/10.svg)

![SUB: LDI12H/b, prefix 111100101111001, sub-opcode 1; operands imm12s, reg4; 4 bytes](figures/w/sub/13.svg)

![SUB: LDBu6/c, prefix 11110010011011, sub-opcode 01; operands b5d6u-xsz, reg5; 4 bytes](figures/w/sub/14.svg)

![SUB: LDBu8H/c, prefix 1111000110011, sub-opcode 01; operands b4d8u-xsz, reg5; 4 bytes](figures/w/sub/16.svg)

![SUB: LDI14H/b, prefix 1111000110101, sub-opcode 1; operands imm14s, reg4; 4 bytes](figures/w/sub/17.svg)

![SUB: LDS12H/c, prefix 11110010101001, sub-opcode 01; operands spd12u-xsz, reg4; 4 bytes](figures/w/sub/18.svg)

![SUB: LDI18H/b, prefix 111001100, sub-opcode 1; operands imm18s, reg4; 4 bytes](figures/w/sub/20.svg)

![SUB: LDI12/b, prefix 11110010101011, sub-opcode 1; operands imm12s, reg5; 4 bytes](figures/w/sub/21.svg)

![SUB: LDX0/c, prefix 1111000111011, sub-opcode 01; operands x5-5d0s, reg5; 4 bytes](figures/w/sub/22.svg)

![SUB: LDPC16H/c, prefix 1110110101, sub-opcode 01; operands pc16-u1, reg4; 4 bytes](figures/w/sub/23.svg)

![SUB: LDBu8/c, prefix 111100010011, sub-opcode 01; operands b5d8u-xsz, reg5; 4 bytes](figures/w/sub/24.svg)

![SUB: RRF, prefix 0010, sub-opcode 1000; operands reg4, reg4; 2 bytes](figures/w/sub/09.svg)

![SUB: RR5, prefix 000, sub-opcode 011; operands reg5, reg5; 2 bytes](figures/w/sub/12.svg)

![SUB: SPADJ6/a, prefix 111000111, sub-opcode 1; operands imm6u-x8, k-sp; 2 bytes](figures/w/sub/15.svg)

![SUB: IMMh43/b, prefix 11011010, sub-opcode 1; operands imm3s, reg4; 2 bytes](figures/w/sub/19.svg)

**Mnemonics:** `SUB`

**Syntax**

```
SUB rm, Rd
```

**Encoding**

![Encoding of SUB](figures/LDF-B28-1.svg)

The chart is the leaf `LDF-B28-1`, LDF.B28, prefix `011101`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `op2` is `reg5`: register, 5 bits. `sub` (4 bits) selects the mnemonic: `movq` 0000, `movl` 0001, `movw` 0010, `movb` 0011, `movzl` 0100, `movzw` 0101, `movzb` 0110, `add` 0111, `sub` 1000, `bic` 1001, `bis` 1010, `xor` 1011, `and` 1100, `mul` 1101, `mulh` 1110, `shl` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`LDF-B28-1`](dictionary/by-encoding.md#LDF-B28-1), [`LDF-X22-1`](dictionary/by-encoding.md#LDF-X22-1), [`LDF-PI12-1`](dictionary/by-encoding.md#LDF-PI12-1), [`LDF-PD12-1`](dictionary/by-encoding.md#LDF-PD12-1), [`LDF-PC32-1`](dictionary/by-encoding.md#LDF-PC32-1), [`LDF-A32-1`](dictionary/by-encoding.md#LDF-A32-1), [`LDFI-I32-1`](dictionary/by-encoding.md#LDFI-I32-1), [`DPF-D28-1`](dictionary/by-encoding.md#DPF-D28-1), [`RRF-1`](dictionary/by-encoding.md#RRF-1), [`RRF5-1`](dictionary/by-encoding.md#RRF5-1), [`SPADJF-1`](dictionary/by-encoding.md#SPADJF-1), [`RR5-1`](dictionary/by-encoding.md#RR5-1), [`LDI12H-b-1`](dictionary/by-encoding.md#LDI12H-b-1), [`LDBu6-c-1`](dictionary/by-encoding.md#LDBu6-c-1), [`SPADJ6-a-1`](dictionary/by-encoding.md#SPADJ6-a-1), [`LDBu8H-c-1`](dictionary/by-encoding.md#LDBu8H-c-1), [`LDI14H-b-1`](dictionary/by-encoding.md#LDI14H-b-1), [`LDS12H-c-1`](dictionary/by-encoding.md#LDS12H-c-1), [`IMMh43-b-1`](dictionary/by-encoding.md#IMMh43-b-1), [`LDI18H-b-1`](dictionary/by-encoding.md#LDI18H-b-1), [`LDI12-b-1`](dictionary/by-encoding.md#LDI12-b-1), [`LDX0-c-1`](dictionary/by-encoding.md#LDX0-c-1), [`LDPC16H-c-1`](dictionary/by-encoding.md#LDPC16H-c-1), [`LDBu8-c-1`](dictionary/by-encoding.md#LDBu8-c-1).

**Operation**

```
Rd ← Rd - rm
```

**Flags** `N` and `Z` from the result, `V` set on signed overflow, `C` set on a **borrow** (the PDP-11 sense): `C` = 1 when the unsigned operand being subtracted is the larger.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.


<a id="w-cmp"></a>
### CMP: Compare

![CMP: CMF.B28, prefix 111000000, sub-opcode 0; operands reg5, b5d28s-x1; 6 bytes](figures/w/cmp/01.svg)

![CMP: CMF.X22, prefix 11010011, sub-opcode 0; operands reg5, x5-5d22s; 6 bytes](figures/w/cmp/02.svg)

![CMP: CMF.PC32, prefix 1110101010, sub-opcode 0; operands reg5, pc32-u1; 6 bytes](figures/w/cmp/05.svg)

![CMP: CMF.A32, prefix 1110101011, sub-opcode 0; operands reg5, abs32; 6 bytes](figures/w/cmp/06.svg)

![CMP: CMF.I32, prefix 1110101100, sub-opcode 0; operands reg5, imm32s; 6 bytes](figures/w/cmp/07.svg)

![CMP: CMF.PI12, prefix 111000001, sub-opcode 0; operands reg5, pi5-s12; 4 bytes](figures/w/cmp/03.svg)

![CMP: CMF.PD12, prefix 111000010, sub-opcode 0; operands reg5, pd5-s12; 4 bytes](figures/w/cmp/04.svg)

![CMP: RRF5, prefix 1111001100100101, sub-opcode 010110; operands reg5, reg5; 4 bytes](figures/w/cmp/09.svg)

![CMP: CMBu8H/a, prefix 1111001100101011; operands reg4, b4d8u-xsz; 4 bytes](figures/w/cmp/10.svg)

![CMP: CMI12H/a, prefix 1111001100101101; operands reg4, imm12s; 4 bytes](figures/w/cmp/11.svg)

![CMP: CMBu10H/a, prefix 11110010101000; operands reg4, b4d10u-xsz; 4 bytes](figures/w/cmp/12.svg)

![CMP: CMBu6/a, prefix 1111001100101110; operands reg5, b5d6u-xsz; 4 bytes](figures/w/cmp/13.svg)

![CMP: CMBu8/a, prefix 11110010101010; operands reg5, b5d8u-xsz; 4 bytes](figures/w/cmp/14.svg)

![CMP: CMPC16H/a, prefix 111100010001; operands reg4, pc16-u1; 4 bytes](figures/w/cmp/15.svg)

![CMP: CMI18H/a, prefix 1110111000; operands reg4, imm18s; 4 bytes](figures/w/cmp/16.svg)

![CMP: CMS12H/a, prefix 1111001100110001; operands reg4, spd12u-xsz; 4 bytes](figures/w/cmp/17.svg)

![CMP: CMX0/a, prefix 111100110001101; operands reg5, x5-5d0s; 4 bytes](figures/w/cmp/18.svg)

![CMP: CMI12/a, prefix 111100110010000; operands reg5, imm12s; 4 bytes](figures/w/cmp/19.svg)

![CMP: RRF, prefix 01010, sub-opcode 110; operands reg4, reg4; 2 bytes](figures/w/cmp/08.svg)

**Mnemonics:** `CMP`

**Syntax**

```
CMP Rd, rm        ; register first
```

**Encoding**

![Encoding of CMP](figures/CMF-B28-1.svg)

The chart is the leaf `CMF-B28-1`, CMF.B28, prefix `111000000`. `op1` is `reg5`: register, 5 bits. `op2` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `sub` (1 bit) selects the mnemonic: `cmp` 0, `fcmp` 1.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`CMF-B28-1`](dictionary/by-encoding.md#CMF-B28-1), [`CMF-X22-1`](dictionary/by-encoding.md#CMF-X22-1), [`CMF-PI12-1`](dictionary/by-encoding.md#CMF-PI12-1), [`CMF-PD12-1`](dictionary/by-encoding.md#CMF-PD12-1), [`CMF-PC32-1`](dictionary/by-encoding.md#CMF-PC32-1), [`CMF-A32-1`](dictionary/by-encoding.md#CMF-A32-1), [`CMF-I32-1`](dictionary/by-encoding.md#CMF-I32-1), [`RRF-2`](dictionary/by-encoding.md#RRF-2), [`RRF5-1`](dictionary/by-encoding.md#RRF5-1), [`CMBu8H-a-1`](dictionary/by-encoding.md#CMBu8H-a-1), [`CMI12H-a-1`](dictionary/by-encoding.md#CMI12H-a-1), [`CMBu10H-a-1`](dictionary/by-encoding.md#CMBu10H-a-1), [`CMBu6-a-1`](dictionary/by-encoding.md#CMBu6-a-1), [`CMBu8-a-1`](dictionary/by-encoding.md#CMBu8-a-1), [`CMPC16H-a-1`](dictionary/by-encoding.md#CMPC16H-a-1), [`CMI18H-a-1`](dictionary/by-encoding.md#CMI18H-a-1), [`CMS12H-a-1`](dictionary/by-encoding.md#CMS12H-a-1), [`CMX0-a-1`](dictionary/by-encoding.md#CMX0-a-1), [`CMI12-a-1`](dictionary/by-encoding.md#CMI12-a-1).

**Operation**

```
tmp ← Rd - rm         ; the result is discarded
```

**Flags** `N` and `Z` from the result, `V` set on signed overflow, `C` set on a **borrow** (the PDP-11 sense): `C` = 1 when the unsigned operand being subtracted is the larger.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

**The operands are in the order register, then the other operand**, the reverse of the PDP-11 `CMP src,dst`: `CMP Rd, rm` computes `Rd - rm`, so a compare of a register against an immediate or memory operand does not reverse its branch condition. After `CMP`, `BHIS`/`BCC` mean unsigned `>=` (no borrow) and `BLO`/`BCS` mean a borrow occurred.


<a id="w-mul"></a>
<a id="w-mulu"></a>
### MUL: Multiply, low 64 bits

![MUL: LDF.B28, prefix 011101, sub-opcode 1101; operands b5d28s-x1, reg5; 6 bytes](figures/w/mul/01.svg)

![MUL: LDF.X22, prefix 01001, sub-opcode 1101; operands x5-5d22s, reg5; 6 bytes](figures/w/mul/02.svg)

![MUL: LDF.PC32, prefix 1010100, sub-opcode 1101; operands pc32-u1, reg5; 6 bytes](figures/w/mul/05.svg)

![MUL: LDF.A32, prefix 1010101, sub-opcode 1101; operands abs32, reg5; 6 bytes](figures/w/mul/06.svg)

![MUL: LDFI.I32, prefix 1010110, sub-opcode 0110; operands imm32s, reg5; 6 bytes](figures/w/mul/07.svg)

![MUL: DPF.D28, prefix 11101111010, sub-opcode 1101; operands dpd28s-x1, reg5; 6 bytes](figures/w/mul/08.svg)

![MUL: LDF.PI12, prefix 011111, sub-opcode 1101; operands pi5-s12, reg5; 4 bytes](figures/w/mul/03.svg)

![MUL: LDF.PD12, prefix 100000, sub-opcode 1101; operands pd5-s12, reg5; 4 bytes](figures/w/mul/04.svg)

![MUL: RRF5, prefix 1111001100100101, sub-opcode 001101; operands reg5, reg5; 4 bytes](figures/w/mul/10.svg)

![MUL: LDI12H/c, prefix 11110010011111, sub-opcode 10; operands imm12s, reg4; 4 bytes](figures/w/mul/11.svg)

![MUL: LDI12/d, prefix 1111000110110, sub-opcode 11; operands imm12s, reg5; 4 bytes](figures/w/mul/12.svg)

![MUL: LDPC12H/d, prefix 1111001000010, sub-opcode 001; operands pc12-u1, reg4; 4 bytes](figures/w/mul/13.svg)

![MUL: RRF, prefix 0010, sub-opcode 1101; operands reg4, reg4; 2 bytes](figures/w/mul/09.svg)

**Mnemonics:** `MUL`  (aliases: `MULU`)

**Syntax**

```
MUL rm, Rd
```

**Encoding**

![Encoding of MUL](figures/LDF-B28-1.svg)

The chart is the leaf `LDF-B28-1`, LDF.B28, prefix `011101`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `op2` is `reg5`: register, 5 bits. `sub` (4 bits) selects the mnemonic: `movq` 0000, `movl` 0001, `movw` 0010, `movb` 0011, `movzl` 0100, `movzw` 0101, `movzb` 0110, `add` 0111, `sub` 1000, `bic` 1001, `bis` 1010, `xor` 1011, `and` 1100, `mul` 1101, `mulh` 1110, `shl` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`LDF-B28-1`](dictionary/by-encoding.md#LDF-B28-1), [`LDF-X22-1`](dictionary/by-encoding.md#LDF-X22-1), [`LDF-PI12-1`](dictionary/by-encoding.md#LDF-PI12-1), [`LDF-PD12-1`](dictionary/by-encoding.md#LDF-PD12-1), [`LDF-PC32-1`](dictionary/by-encoding.md#LDF-PC32-1), [`LDF-A32-1`](dictionary/by-encoding.md#LDF-A32-1), [`LDFI-I32-1`](dictionary/by-encoding.md#LDFI-I32-1), [`DPF-D28-1`](dictionary/by-encoding.md#DPF-D28-1), [`RRF-1`](dictionary/by-encoding.md#RRF-1), [`RRF5-1`](dictionary/by-encoding.md#RRF5-1), [`LDI12H-c-1`](dictionary/by-encoding.md#LDI12H-c-1), [`LDI12-d-1`](dictionary/by-encoding.md#LDI12-d-1), [`LDPC12H-d-1`](dictionary/by-encoding.md#LDPC12H-d-1).

**Operation**

```
Rd ← (Rd × rm)[63:0]         ; sign-agnostic
```

**Flags** `N` and `Z` from the result, `V` set when the signed 128-bit product does not fit in 64 bits, `C` unchanged.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

The low 64 bits of a two's-complement product are the same whether the operands are read as signed or unsigned, so there is one low-half multiply. The mnemonic `MULU` is an alias of `MUL`. The high half is `MULH` (signed) and `MULHU` (unsigned).

<a id="w-mulu"></a>
**`MULU`** is an alias of `MUL`: the assembler writes it as that word.


<a id="w-mulh"></a>
### MULH: Multiply, high 64 bits, signed

![MULH: LDF.B28, prefix 011101, sub-opcode 1110; operands b5d28s-x1, reg5; 6 bytes](figures/w/mulh/01.svg)

![MULH: LDF.X22, prefix 01001, sub-opcode 1110; operands x5-5d22s, reg5; 6 bytes](figures/w/mulh/02.svg)

![MULH: LDF.PC32, prefix 1010100, sub-opcode 1110; operands pc32-u1, reg5; 6 bytes](figures/w/mulh/05.svg)

![MULH: LDF.A32, prefix 1010101, sub-opcode 1110; operands abs32, reg5; 6 bytes](figures/w/mulh/06.svg)

![MULH: LDFI.I32, prefix 1010110, sub-opcode 0111; operands imm32s, reg5; 6 bytes](figures/w/mulh/07.svg)

![MULH: DPF.D28, prefix 11101111010, sub-opcode 1110; operands dpd28s-x1, reg5; 6 bytes](figures/w/mulh/08.svg)

![MULH: LDF.PI12, prefix 011111, sub-opcode 1110; operands pi5-s12, reg5; 4 bytes](figures/w/mulh/03.svg)

![MULH: LDF.PD12, prefix 100000, sub-opcode 1110; operands pd5-s12, reg5; 4 bytes](figures/w/mulh/04.svg)

![MULH: RRF5, prefix 1111001100100101, sub-opcode 001110; operands reg5, reg5; 4 bytes](figures/w/mulh/10.svg)

![MULH: LDPC12H/d, prefix 1111001000010, sub-opcode 010; operands pc12-u1, reg4; 4 bytes](figures/w/mulh/11.svg)

![MULH: RRF, prefix 0010, sub-opcode 1110; operands reg4, reg4; 2 bytes](figures/w/mulh/09.svg)

**Mnemonics:** `MULH`

**Syntax**

```
MULH rm, Rd
```

**Encoding**

![Encoding of MULH](figures/LDF-B28-1.svg)

The chart is the leaf `LDF-B28-1`, LDF.B28, prefix `011101`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `op2` is `reg5`: register, 5 bits. `sub` (4 bits) selects the mnemonic: `movq` 0000, `movl` 0001, `movw` 0010, `movb` 0011, `movzl` 0100, `movzw` 0101, `movzb` 0110, `add` 0111, `sub` 1000, `bic` 1001, `bis` 1010, `xor` 1011, `and` 1100, `mul` 1101, `mulh` 1110, `shl` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`LDF-B28-1`](dictionary/by-encoding.md#LDF-B28-1), [`LDF-X22-1`](dictionary/by-encoding.md#LDF-X22-1), [`LDF-PI12-1`](dictionary/by-encoding.md#LDF-PI12-1), [`LDF-PD12-1`](dictionary/by-encoding.md#LDF-PD12-1), [`LDF-PC32-1`](dictionary/by-encoding.md#LDF-PC32-1), [`LDF-A32-1`](dictionary/by-encoding.md#LDF-A32-1), [`LDFI-I32-1`](dictionary/by-encoding.md#LDFI-I32-1), [`DPF-D28-1`](dictionary/by-encoding.md#DPF-D28-1), [`RRF-1`](dictionary/by-encoding.md#RRF-1), [`RRF5-1`](dictionary/by-encoding.md#RRF5-1), [`LDPC12H-d-1`](dictionary/by-encoding.md#LDPC12H-d-1).

**Operation**

```
Rd ← (sext(Rd) × sext(rm))[127:64]
```

**Flags** `N` and `Z` from the result, `V` cleared, `C` unchanged.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

With `MULH`, division by a constant is a multiply by a reciprocal and a shift, which is what compilers emit.

**Why it is here.** The low 64 bits of a two's-complement product are identical signed or unsigned, so a second multiply (`MULU`) would duplicate `MUL`; what the architecture needs in that place is the *high* half of the product. Without it a 64 by 64 to 128-bit multiply, every bignum multiply, 128-bit fixed point and divide-by-a-constant by multiplying by the reciprocal are impossible. `MULH` is that instruction. It is also why a divide is rare in compiled code: compilers turn division by a constant into `MULH` and a shift.


### ADDM: ALU operation with a memory destination

**Mnemonics:** `ADDM`, `SUBM`, `BICM`, `BISM`

**Syntax**

```
ADDM Rs, rm
SUBM Rs, rm
BICM Rs, rm
BISM Rs, rm
```

**Encoding**

![Encoding of ADDM](figures/STF-B28-2.svg)

The chart is the leaf `STF-B28-2`, STF.B28, prefix `11001110`. `op1` is `reg5`: register, 5 bits. `op2` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `sub` (2 bits) selects the mnemonic: `addm` 00, `subm` 01, `bicm` 10, `bism` 11.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`STF-B28-2`](dictionary/by-encoding.md#STF-B28-2), [`STF-X22-2`](dictionary/by-encoding.md#STF-X22-2), [`STF-PI12-2`](dictionary/by-encoding.md#STF-PI12-2), [`STF-PD12-2`](dictionary/by-encoding.md#STF-PD12-2), [`STF-PC32-2`](dictionary/by-encoding.md#STF-PC32-2), [`STF-A32-2`](dictionary/by-encoding.md#STF-A32-2).

**Operation**

```
ADDM: M[EA] ← M[EA] + Rs
SUBM: M[EA] ← M[EA] - Rs
BICM: M[EA] ← M[EA] AND NOT Rs
BISM: M[EA] ← M[EA] OR Rs
```

**Flags** As for `ADD`, `SUB`, `BIC` and `BIS`.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires. Write permission is checked during the read access, so the write cannot fault after the read has succeeded.

The forms with a memory destination are in the ordinary memory families of the encoding, with every addressing form (errata 87).

**Why it is here.** These are the read-modify-write forms with a memory destination. They cover the case where the second operand is a register, for example `BISM Rmask, flags(DP)`. The compiled corpus has 265 sites (1.6 KB) for them, measured for the original encoding, which is why they are not worth an opcode of their own there.

<a id="w-addm"></a>
#### ADDM

![ADDM: STF.B28, prefix 11001110, sub-opcode 00; operands reg5, b5d28s-x1; 6 bytes](figures/w/addm/01.svg)

![ADDM: STF.X22, prefix 1011000, sub-opcode 00; operands reg5, x5-5d22s; 6 bytes](figures/w/addm/02.svg)

![ADDM: STF.PC32, prefix 110111110, sub-opcode 00; operands reg5, pc32-u1; 6 bytes](figures/w/addm/05.svg)

![ADDM: STF.A32, prefix 110111111, sub-opcode 00; operands reg5, abs32; 6 bytes](figures/w/addm/06.svg)

![ADDM: STF.PI12, prefix 11001111, sub-opcode 00; operands reg5, pi5-s12; 4 bytes](figures/w/addm/03.svg)

![ADDM: STF.PD12, prefix 11010000, sub-opcode 00; operands reg5, pd5-s12; 4 bytes](figures/w/addm/04.svg)

```
ADDM Rs, rm
```

Operation, flags and exceptions as for the entry ADDM above; 6 layout forms, each a chart of its own (above).

<a id="w-subm"></a>
#### SUBM

![SUBM: STF.B28, prefix 11001110, sub-opcode 01; operands reg5, b5d28s-x1; 6 bytes](figures/w/subm/01.svg)

![SUBM: STF.X22, prefix 1011000, sub-opcode 01; operands reg5, x5-5d22s; 6 bytes](figures/w/subm/02.svg)

![SUBM: STF.PC32, prefix 110111110, sub-opcode 01; operands reg5, pc32-u1; 6 bytes](figures/w/subm/05.svg)

![SUBM: STF.A32, prefix 110111111, sub-opcode 01; operands reg5, abs32; 6 bytes](figures/w/subm/06.svg)

![SUBM: STF.PI12, prefix 11001111, sub-opcode 01; operands reg5, pi5-s12; 4 bytes](figures/w/subm/03.svg)

![SUBM: STF.PD12, prefix 11010000, sub-opcode 01; operands reg5, pd5-s12; 4 bytes](figures/w/subm/04.svg)

```
SUBM Rs, rm
```

Operation, flags and exceptions as for the entry ADDM above; 6 layout forms, each a chart of its own (above).

<a id="w-bicm"></a>
#### BICM

![BICM: STF.B28, prefix 11001110, sub-opcode 10; operands reg5, b5d28s-x1; 6 bytes](figures/w/bicm/01.svg)

![BICM: STF.X22, prefix 1011000, sub-opcode 10; operands reg5, x5-5d22s; 6 bytes](figures/w/bicm/02.svg)

![BICM: STF.PC32, prefix 110111110, sub-opcode 10; operands reg5, pc32-u1; 6 bytes](figures/w/bicm/05.svg)

![BICM: STF.A32, prefix 110111111, sub-opcode 10; operands reg5, abs32; 6 bytes](figures/w/bicm/06.svg)

![BICM: STF.PI12, prefix 11001111, sub-opcode 10; operands reg5, pi5-s12; 4 bytes](figures/w/bicm/03.svg)

![BICM: STF.PD12, prefix 11010000, sub-opcode 10; operands reg5, pd5-s12; 4 bytes](figures/w/bicm/04.svg)

```
BICM Rs, rm
```

Operation, flags and exceptions as for the entry ADDM above; 6 layout forms, each a chart of its own (above).

<a id="w-bism"></a>
#### BISM

![BISM: STF.B28, prefix 11001110, sub-opcode 11; operands reg5, b5d28s-x1; 6 bytes](figures/w/bism/01.svg)

![BISM: STF.X22, prefix 1011000, sub-opcode 11; operands reg5, x5-5d22s; 6 bytes](figures/w/bism/02.svg)

![BISM: STF.PC32, prefix 110111110, sub-opcode 11; operands reg5, pc32-u1; 6 bytes](figures/w/bism/05.svg)

![BISM: STF.A32, prefix 110111111, sub-opcode 11; operands reg5, abs32; 6 bytes](figures/w/bism/06.svg)

![BISM: STF.PI12, prefix 11001111, sub-opcode 11; operands reg5, pi5-s12; 4 bytes](figures/w/bism/03.svg)

![BISM: STF.PD12, prefix 11010000, sub-opcode 11; operands reg5, pd5-s12; 4 bytes](figures/w/bism/04.svg)

```
BISM Rs, rm
```

Operation, flags and exceptions as for the entry ADDM above; 6 layout forms, each a chart of its own (above).


<a id="w-inc"></a>
### INC: Increment

![INC: SOF.B28, prefix 11101110111, sub-opcode 0010; operands b5d28s-x1; 6 bytes](figures/w/inc/01.svg)

![INC: SOF.X22, prefix 1110101101, sub-opcode 0010; operands x5-5d22s; 6 bytes](figures/w/inc/02.svg)

![INC: SOF.PC32, prefix 111100000100, sub-opcode 0010; operands pc32-u1; 6 bytes](figures/w/inc/05.svg)

![INC: SOF.A32, prefix 111100000101, sub-opcode 0010; operands abs32; 6 bytes](figures/w/inc/06.svg)

![INC: SOF.PI12, prefix 11101111000, sub-opcode 0010; operands pi5-s12; 4 bytes](figures/w/inc/03.svg)

![INC: SOF.PD12, prefix 11101111001, sub-opcode 0010; operands pd5-s12; 4 bytes](figures/w/inc/04.svg)

![INC: SOBu12H/a, prefix 11110010011010, sub-opcode 01; operands b4d12u-xsz; 4 bytes](figures/w/inc/08.svg)

![INC: SOX4/a, prefix 11110010101110, sub-opcode 01; operands x5-5d4s; 4 bytes](figures/w/inc/09.svg)

![INC: SOBs12/a, prefix 1111000111111, sub-opcode 01; operands b5d12s-xsz; 4 bytes](figures/w/inc/10.svg)

![INC: SOPR, prefix 11010100, sub-opcode 010; operands reg5; 2 bytes](figures/w/inc/07.svg)

**Mnemonics:** `INC`

**Syntax**

```
INC rm
```

**Encoding**

![Encoding of INC](figures/SOF-B28-1.svg)

The chart is the leaf `SOF-B28-1`, SOF.B28, prefix `11101110111`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `sub` (4 bits) selects the mnemonic: `clr` 0000, `com` 0001, `inc` 0010, `dec` 0011, `neg` 0100, `tst` 0101, `adc` 0110, `sbc` 0111, `asl` 1000, `asr` 1001, `push` 1010, `pop` 1011, `jmp` 1100, `call` 1101, `jmpi` 1110, `calli` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SOF-B28-1`](dictionary/by-encoding.md#SOF-B28-1), [`SOF-X22-1`](dictionary/by-encoding.md#SOF-X22-1), [`SOF-PI12-1`](dictionary/by-encoding.md#SOF-PI12-1), [`SOF-PD12-1`](dictionary/by-encoding.md#SOF-PD12-1), [`SOF-PC32-1`](dictionary/by-encoding.md#SOF-PC32-1), [`SOF-A32-1`](dictionary/by-encoding.md#SOF-A32-1), [`SOPR-1`](dictionary/by-encoding.md#SOPR-1), [`SOBu12H-a-1`](dictionary/by-encoding.md#SOBu12H-a-1), [`SOX4-a-1`](dictionary/by-encoding.md#SOX4-a-1), [`SOBs12-a-1`](dictionary/by-encoding.md#SOBs12-a-1).

**Operation**

```
rm ← rm + 1
```

**Flags** `N`, `Z` and `V` as for `ADD`; `C` **unchanged**.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.


<a id="w-dec"></a>
### DEC: Decrement

![DEC: SOF.B28, prefix 11101110111, sub-opcode 0011; operands b5d28s-x1; 6 bytes](figures/w/dec/01.svg)

![DEC: SOF.X22, prefix 1110101101, sub-opcode 0011; operands x5-5d22s; 6 bytes](figures/w/dec/02.svg)

![DEC: SOF.PC32, prefix 111100000100, sub-opcode 0011; operands pc32-u1; 6 bytes](figures/w/dec/05.svg)

![DEC: SOF.A32, prefix 111100000101, sub-opcode 0011; operands abs32; 6 bytes](figures/w/dec/06.svg)

![DEC: SOF.PI12, prefix 11101111000, sub-opcode 0011; operands pi5-s12; 4 bytes](figures/w/dec/03.svg)

![DEC: SOF.PD12, prefix 11101111001, sub-opcode 0011; operands pd5-s12; 4 bytes](figures/w/dec/04.svg)

![DEC: SOBu12H/a, prefix 11110010011010, sub-opcode 10; operands b4d12u-xsz; 4 bytes](figures/w/dec/08.svg)

![DEC: SOX4/a, prefix 11110010101110, sub-opcode 10; operands x5-5d4s; 4 bytes](figures/w/dec/09.svg)

![DEC: SOBs12/a, prefix 1111000111111, sub-opcode 10; operands b5d12s-xsz; 4 bytes](figures/w/dec/10.svg)

![DEC: SOPR, prefix 11010100, sub-opcode 011; operands reg5; 2 bytes](figures/w/dec/07.svg)

**Mnemonics:** `DEC`

**Syntax**

```
DEC rm
```

**Encoding**

![Encoding of DEC](figures/SOF-B28-1.svg)

The chart is the leaf `SOF-B28-1`, SOF.B28, prefix `11101110111`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `sub` (4 bits) selects the mnemonic: `clr` 0000, `com` 0001, `inc` 0010, `dec` 0011, `neg` 0100, `tst` 0101, `adc` 0110, `sbc` 0111, `asl` 1000, `asr` 1001, `push` 1010, `pop` 1011, `jmp` 1100, `call` 1101, `jmpi` 1110, `calli` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SOF-B28-1`](dictionary/by-encoding.md#SOF-B28-1), [`SOF-X22-1`](dictionary/by-encoding.md#SOF-X22-1), [`SOF-PI12-1`](dictionary/by-encoding.md#SOF-PI12-1), [`SOF-PD12-1`](dictionary/by-encoding.md#SOF-PD12-1), [`SOF-PC32-1`](dictionary/by-encoding.md#SOF-PC32-1), [`SOF-A32-1`](dictionary/by-encoding.md#SOF-A32-1), [`SOPR-1`](dictionary/by-encoding.md#SOPR-1), [`SOBu12H-a-1`](dictionary/by-encoding.md#SOBu12H-a-1), [`SOX4-a-1`](dictionary/by-encoding.md#SOX4-a-1), [`SOBs12-a-1`](dictionary/by-encoding.md#SOBs12-a-1).

**Operation**

```
rm ← rm - 1
```

**Flags** `N`, `Z` and `V` as for `SUB`; `C` **unchanged**.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.


<a id="w-neg"></a>
### NEG: Negate

![NEG: SOF.B28, prefix 11101110111, sub-opcode 0100; operands b5d28s-x1; 6 bytes](figures/w/neg/01.svg)

![NEG: SOF.X22, prefix 1110101101, sub-opcode 0100; operands x5-5d22s; 6 bytes](figures/w/neg/02.svg)

![NEG: SOF.PC32, prefix 111100000100, sub-opcode 0100; operands pc32-u1; 6 bytes](figures/w/neg/05.svg)

![NEG: SOF.A32, prefix 111100000101, sub-opcode 0100; operands abs32; 6 bytes](figures/w/neg/06.svg)

![NEG: SOF.PI12, prefix 11101111000, sub-opcode 0100; operands pi5-s12; 4 bytes](figures/w/neg/03.svg)

![NEG: SOF.PD12, prefix 11101111001, sub-opcode 0100; operands pd5-s12; 4 bytes](figures/w/neg/04.svg)

![NEG: SOPR, prefix 11010100, sub-opcode 100; operands reg5; 2 bytes](figures/w/neg/07.svg)

**Mnemonics:** `NEG`

**Syntax**

```
NEG rm
```

**Encoding**

![Encoding of NEG](figures/SOF-B28-1.svg)

The chart is the leaf `SOF-B28-1`, SOF.B28, prefix `11101110111`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `sub` (4 bits) selects the mnemonic: `clr` 0000, `com` 0001, `inc` 0010, `dec` 0011, `neg` 0100, `tst` 0101, `adc` 0110, `sbc` 0111, `asl` 1000, `asr` 1001, `push` 1010, `pop` 1011, `jmp` 1100, `call` 1101, `jmpi` 1110, `calli` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SOF-B28-1`](dictionary/by-encoding.md#SOF-B28-1), [`SOF-X22-1`](dictionary/by-encoding.md#SOF-X22-1), [`SOF-PI12-1`](dictionary/by-encoding.md#SOF-PI12-1), [`SOF-PD12-1`](dictionary/by-encoding.md#SOF-PD12-1), [`SOF-PC32-1`](dictionary/by-encoding.md#SOF-PC32-1), [`SOF-A32-1`](dictionary/by-encoding.md#SOF-A32-1), [`SOPR-1`](dictionary/by-encoding.md#SOPR-1).

**Operation**

```
rm ← 0 - rm
```

**Flags** `N` and `Z` from the result, `V` set on signed overflow, `C` set on a **borrow** (the PDP-11 sense): `C` = 1 when the unsigned operand being subtracted is the larger. (`C` = 1 unless the operand was 0.)

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.


<a id="w-adc"></a>
### ADC: Add carry

![ADC: SOF.B28, prefix 11101110111, sub-opcode 0110; operands b5d28s-x1; 6 bytes](figures/w/adc/01.svg)

![ADC: SOF.X22, prefix 1110101101, sub-opcode 0110; operands x5-5d22s; 6 bytes](figures/w/adc/02.svg)

![ADC: SOF.PC32, prefix 111100000100, sub-opcode 0110; operands pc32-u1; 6 bytes](figures/w/adc/05.svg)

![ADC: SOF.A32, prefix 111100000101, sub-opcode 0110; operands abs32; 6 bytes](figures/w/adc/06.svg)

![ADC: SOF.PI12, prefix 11101111000, sub-opcode 0110; operands pi5-s12; 4 bytes](figures/w/adc/03.svg)

![ADC: SOF.PD12, prefix 11101111001, sub-opcode 0110; operands pd5-s12; 4 bytes](figures/w/adc/04.svg)

![ADC: SOPR, prefix 11010100, sub-opcode 110; operands reg5; 2 bytes](figures/w/adc/07.svg)

**Mnemonics:** `ADC`

**Syntax**

```
ADC rm
```

**Encoding**

![Encoding of ADC](figures/SOF-B28-1.svg)

The chart is the leaf `SOF-B28-1`, SOF.B28, prefix `11101110111`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `sub` (4 bits) selects the mnemonic: `clr` 0000, `com` 0001, `inc` 0010, `dec` 0011, `neg` 0100, `tst` 0101, `adc` 0110, `sbc` 0111, `asl` 1000, `asr` 1001, `push` 1010, `pop` 1011, `jmp` 1100, `call` 1101, `jmpi` 1110, `calli` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SOF-B28-1`](dictionary/by-encoding.md#SOF-B28-1), [`SOF-X22-1`](dictionary/by-encoding.md#SOF-X22-1), [`SOF-PI12-1`](dictionary/by-encoding.md#SOF-PI12-1), [`SOF-PD12-1`](dictionary/by-encoding.md#SOF-PD12-1), [`SOF-PC32-1`](dictionary/by-encoding.md#SOF-PC32-1), [`SOF-A32-1`](dictionary/by-encoding.md#SOF-A32-1), [`SOPR-1`](dictionary/by-encoding.md#SOPR-1).

**Operation**

```
rm ← rm + C
```

**Flags** `N` and `Z` from the result, `V` set on signed overflow, `C` set on a carry out of bit 63.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

With `ADD`, multi-word addition.


<a id="w-sbc"></a>
### SBC: Subtract carry

![SBC: SOF.B28, prefix 11101110111, sub-opcode 0111; operands b5d28s-x1; 6 bytes](figures/w/sbc/01.svg)

![SBC: SOF.X22, prefix 1110101101, sub-opcode 0111; operands x5-5d22s; 6 bytes](figures/w/sbc/02.svg)

![SBC: SOF.PC32, prefix 111100000100, sub-opcode 0111; operands pc32-u1; 6 bytes](figures/w/sbc/05.svg)

![SBC: SOF.A32, prefix 111100000101, sub-opcode 0111; operands abs32; 6 bytes](figures/w/sbc/06.svg)

![SBC: SOF.PI12, prefix 11101111000, sub-opcode 0111; operands pi5-s12; 4 bytes](figures/w/sbc/03.svg)

![SBC: SOF.PD12, prefix 11101111001, sub-opcode 0111; operands pd5-s12; 4 bytes](figures/w/sbc/04.svg)

![SBC: SOPR, prefix 11010100, sub-opcode 111; operands reg5; 2 bytes](figures/w/sbc/07.svg)

**Mnemonics:** `SBC`

**Syntax**

```
SBC rm
```

**Encoding**

![Encoding of SBC](figures/SOF-B28-1.svg)

The chart is the leaf `SOF-B28-1`, SOF.B28, prefix `11101110111`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `sub` (4 bits) selects the mnemonic: `clr` 0000, `com` 0001, `inc` 0010, `dec` 0011, `neg` 0100, `tst` 0101, `adc` 0110, `sbc` 0111, `asl` 1000, `asr` 1001, `push` 1010, `pop` 1011, `jmp` 1100, `call` 1101, `jmpi` 1110, `calli` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SOF-B28-1`](dictionary/by-encoding.md#SOF-B28-1), [`SOF-X22-1`](dictionary/by-encoding.md#SOF-X22-1), [`SOF-PI12-1`](dictionary/by-encoding.md#SOF-PI12-1), [`SOF-PD12-1`](dictionary/by-encoding.md#SOF-PD12-1), [`SOF-PC32-1`](dictionary/by-encoding.md#SOF-PC32-1), [`SOF-A32-1`](dictionary/by-encoding.md#SOF-A32-1), [`SOPR-1`](dictionary/by-encoding.md#SOPR-1).

**Operation**

```
rm ← rm - C
```

**Flags** `N` and `Z` from the result, `V` set on signed overflow, `C` set on a **borrow** (the PDP-11 sense): `C` = 1 when the unsigned operand being subtracted is the larger.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.


### DIV: Divide and remainder, signed and unsigned

**Mnemonics:** `DIV`, `DIVU`, `MOD`, `MODU`

**Syntax**

```
DIV Ra, Rb, Rd
DIVU Ra, Rb, Rd
MOD Ra, Rb, Rd
MODU Ra, Rb, Rd
```

**Encoding**

![Encoding of DIV](figures/R3-1.svg)

The chart is the leaf `R3-1`, R3, prefix `1110100001`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `op3` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R3-1`](dictionary/by-encoding.md#R3-1).

**Operation**

```
if Rb = 0 then divide-by-zero abort
DIV : Rd ← Ra ÷ Rb  (signed, rounded toward zero; INT_MIN ÷ -1 = INT_MIN)
DIVU: Rd ← Ra ÷ Rb  (unsigned)
MOD : Rd ← Ra mod Rb (signed, the sign of Ra; any value mod -1 = 0)
MODU: Rd ← Ra mod Rb (unsigned)
```

**Flags** None written.

**Exceptions** Division by zero aborts with the divide-by-zero vector (cause `DIVZERO`). There is no overflow trap: `INT_MIN / -1` returns `INT_MIN`.

Division by a constant is a `MULH` and a shift, so a real divide is rare; this is why divide has no two-byte form.

**Cf.** 6.3 (the divide-by-zero vector).

<a id="w-div"></a>
#### DIV

![DIV: R3, prefix 1110100001, sub-opcode 0001010; operands reg5, reg5, reg5; 4 bytes](figures/w/div/01.svg)

```
DIV Ra, Rb, Rd
```

Operation, flags and exceptions as for the entry DIV above; 1 layout form, each a chart of its own (above).

<a id="w-divu"></a>
#### DIVU

![DIVU: R3, prefix 1110100001, sub-opcode 0001011; operands reg5, reg5, reg5; 4 bytes](figures/w/divu/01.svg)

```
DIVU Ra, Rb, Rd
```

Operation, flags and exceptions as for the entry DIV above; 1 layout form, each a chart of its own (above).

<a id="w-mod"></a>
#### MOD

![MOD: R3, prefix 1110100001, sub-opcode 0001100; operands reg5, reg5, reg5; 4 bytes](figures/w/mod/01.svg)

```
MOD Ra, Rb, Rd
```

Operation, flags and exceptions as for the entry DIV above; 1 layout form, each a chart of its own (above).

<a id="w-modu"></a>
#### MODU

![MODU: R3, prefix 1110100001, sub-opcode 0001101; operands reg5, reg5, reg5; 4 bytes](figures/w/modu/01.svg)

```
MODU Ra, Rb, Rd
```

Operation, flags and exceptions as for the entry DIV above; 1 layout form, each a chart of its own (above).


<a id="w-mulhu"></a>
### MULHU: Multiply, high 64 bits, unsigned

![MULHU: R3, prefix 1110100001, sub-opcode 0001110; operands reg5, reg5, reg5; 4 bytes](figures/w/mulhu/01.svg)

**Mnemonics:** `MULHU`

**Syntax**

```
MULHU Ra, Rb, Rd
```

**Encoding**

![Encoding of MULHU](figures/R3-1.svg)

The chart is the leaf `R3-1`, R3, prefix `1110100001`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `op3` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R3-1`](dictionary/by-encoding.md#R3-1).

**Operation**

```
Rd ← (Ra × Rb)[127:64]    ; unsigned
```

**Flags** None written.

**Exceptions** None.

**Why it is here.** The unsigned partner of `MULH`, for the same reason (the high half of the product). `MULHSU`, signed times unsigned for a bignum's top limb, is reserved because it can be built from `MULH` with one correction.


<a id="w-abs"></a>
### ABS: Absolute value (assembler alias)

**Mnemonics:** `ABS`

**Alias** *(D)* `ABS` is an assembler alias, not a native instruction (the author's decision, errata 98). Meaning: `Rd <- |Rs|`. Open: its expansion, and with it the flags it leaves ([J.9.1](appendix-j-open.md#j91)).

**Syntax**

```
ABS Rs, Rd
```

**Encoding** None of its own: the assembler expands an alias into other instructions. Open: the expansion ([J.9.1](appendix-j-open.md#j91)).

**Operation**

```
Rd ← |Rs|
```

**Flags** Open with the expansion ([J.9.1](appendix-j-open.md#j91)).

**Exceptions** None.

**Why it is here.** Integer absolute value is the counterpart of `FABS`. The author decided (2026-11-10) that it is an assembler alias, not a native instruction (errata 98); the compiler's work of recognising `x < 0 ? -x : x` is the real cost, and the expansion is open ([J.9.1](appendix-j-open.md#j91)). The compiled corpus has 18 uses of `abs` and 5 of its unsigned form, under 0.1% of code, so the case is clarity and the idiom more than size.


<a id="w-min"></a>
<a id="w-minu"></a>
<a id="w-max"></a>
<a id="w-maxu"></a>
### MINMAX: Minimum and maximum, signed and unsigned (assembler aliases)

**Mnemonics:** `MIN`, `MINU`, `MAX`, `MAXU`

**Alias** *(D)* `MIN`, `MINU`, `MAX` and `MAXU` are assembler aliases, not native instructions (the author's decision, errata 98). Meaning: the smaller or the larger of `Ra` and `Rb`, signed for `MIN` and `MAX` and unsigned for `MINU` and `MAXU`. Open: their expansion, and with it the flags they leave ([J.9.1](appendix-j-open.md#j91)).

**Syntax**

```
MIN Ra, Rb, Rd
MINU Ra, Rb, Rd
MAX Ra, Rb, Rd
MAXU Ra, Rb, Rd
```

**Encoding** None of its own: the assembler expands an alias into other instructions. Open: the expansion ([J.9.1](appendix-j-open.md#j91)).

**Operation**

```
MIN : Rd ← smaller of Ra, Rb (signed)         MINU: unsigned
MAX : Rd ← larger of Ra, Rb (signed)          MAXU: unsigned
```

**Flags** Open with the expansion ([J.9.1](appendix-j-open.md#j91)).

**Exceptions** None.

**Why it is here.** The integer counterparts of `FMIN` and `FMAX`, provided with `ABS`; the author decided (2026-11-10) that they are assembler aliases, not native instructions (errata 98). The corpus has 171 uses of `MIN` and 52 of `MAX` across 95 files, under 0.1% of code in all. Their expansion is open ([J.9.1](appendix-j-open.md#j91)).


<a id="w-set"></a>
### SET: Set a register from a condition

![SET: SETF, prefix 11101110011, sub-opcode 000000000000; operands imm4u, reg5; 4 bytes](figures/w/set/01.svg)

**Mnemonics:** `SET`

**Syntax**

```
SET cc, Rd        ; for example SET EQ, R1
```

**Encoding**

![Encoding of SET](figures/SETF-1.svg)

The chart is the leaf `SETF-1`, SETF, prefix `11101110011`. `op1` is `imm4u`: unsigned 4-bit immediate, 0 to 15. `op2` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SETF-1`](dictionary/by-encoding.md#SETF-1).

**Operation**

```
Rd ← 1 if condition cc holds on the current flags, else 0
```

**Flags** None written.

**Exceptions** None.

The condition is numbered as the low nibble of the branch opcodes (`al` 0, `ne` 1, `eq` 2, ... `los` 14).

**Why it is here.** The first instruction written with a condition word: one instruction, `SET cc, Rd`, rather than one opcode per condition, with the condition numbered like the low nibble of the branch opcodes. It turns a comparison used as a value into 0 or 1 without a branch. gcc `-Os` for amd64 emits 673 `set<cc>` on the corpus, and `SET` would remove about six bytes per site, around 0.4% of code; the compiler's first pass turns such a comparison into branches before its second pass sees it, so the saving is not reached in compiled code.


### MASK: Mask by a condition register

**Mnemonics:** `MASKEQZ`, `MASKNEZ`

**Syntax**

```
MASKEQZ Ra, Rc, Rd
MASKNEZ Ra, Rc, Rd
```

**Encoding**

![Encoding of MASK](figures/R3-1.svg)

The chart is the leaf `R3-1`, R3, prefix `1110100001`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `op3` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R3-1`](dictionary/by-encoding.md#R3-1).

**Operation**

```
MASKEQZ: Rd ← (Rc = 0) ? 0 : Ra
MASKNEZ: Rd ← (Rc ≠ 0) ? 0 : Ra
```

**Flags** None written.

**Exceptions** None.

*(D)* Errata 85: the branch-free select is adopted. `Rc` is tested whole, all 64 bits, so any non-zero value is true; no flag is read or written, and the latency is fixed. `Rd` may be `Ra` or `Rc`. A constant-time select `d = c ? a : b` is `MASKEQZ a, c, t`, `MASKNEZ b, c, d`, `BIS t, d`. The semantics are those of LoongArch `maskeqz` and `masknez` and of RISC-V Zicond (the crypto study states this from memory). Open: whether a flag-reading select is added ([J.9.1](appendix-j-open.md#j91)).

**Why it is here.** The author adopted the branch-free select (errata 85) when the crypto study asked for it: constant-time code must choose between two values without a branch, and a flag-reading conditional move would put a secret in a flag. `MASKEQZ` and `MASKNEZ` are the select of LoongArch and of RISC-V Zicond (stated from memory in the study, not checked against a manual); the pair and an `OR` make `c ? a : b` in three instructions, against two for `CMP` and a conditional move, but the conditional move would be used at 783 sites in 284,641 instructions (0.28%), and the case for the pair is the constant-time idiom, where the condition is already a register. The author confirmed the pair and wrote "looks good" on the section (errata 86). About 100 look-up tables, one cycle (the study's estimate).

**Cf.** 9.7 (SET), docs/crypto-secure-core.md section 2.

<a id="w-maskeqz"></a>
#### MASKEQZ

![MASKEQZ: R3, prefix 1110100001, sub-opcode 0010110; operands reg5, reg5, reg5; 4 bytes](figures/w/maskeqz/01.svg)

```
MASKEQZ Ra, Rc, Rd
```

Operation, flags and exceptions as for the entry MASK above; 1 layout form, each a chart of its own (above).

<a id="w-masknez"></a>
#### MASKNEZ

![MASKNEZ: R3, prefix 1110100001, sub-opcode 0010111; operands reg5, reg5, reg5; 4 bytes](figures/w/masknez/01.svg)

```
MASKNEZ Ra, Rc, Rd
```

Operation, flags and exceptions as for the entry MASK above; 1 layout form, each a chart of its own (above).


### OVF: Add, subtract and multiply, trapping on signed overflow

**Mnemonics:** `ADDV`, `SUBV`, `MULV`

**Syntax**

```
ADDV Rs, Rd
SUBV Rs, Rd
MULV Rs, Rd
```

**Encoding**

![Encoding of OVF](figures/R2-1.svg)

The chart is the leaf `R2-1`, R2, prefix `111100000010`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R2-1`](dictionary/by-encoding.md#R2-1).

**Operation**

```
t ← Rd op Rs                 ; op is +, - or ×, on signed 64-bit values
if t does not fit in 64 bits then abort at this instruction (vector CHECK), Rd unwritten
else Rd ← t
```

**Flags** None written.

**Exceptions** Aborts with the `CHECK` vector on signed overflow, with `EPC` at the instruction and the destination unwritten; a blind restart faults again unless the handler changed an operand.

*(D)* Errata 85: `TRAPCC` with the fused `ADDV`, `SUBV` and `MULV` forms. The tables of the grammars hold the two-register form (`Rd <- Rd op Rs`, like `ADD`, `SUB`, `MUL`) and no immediate or memory form. Open: whether the form has two registers or three ([J.9.4](appendix-j-open.md#j94)). Open: the number of the `CHECK` vector ([J.9.4](appendix-j-open.md#j94)).

**Why it is here.** Checked arithmetic is what clang `-ftrapv` and `__builtin_*_overflow`, Rust's debug overflow checks, Swift's default arithmetic and Ada's `Constraint_Error` need. The author decided `TRAPCC` with the fused `ADDV`, `SUBV` and `MULV` and no compare-and-trap form (errata 85), the fused forms as the case where one non-destructive instruction beats `ADD` and `TRAPCC`. The corpus cannot size the use: it contains no `BVS` or `BVC` at all, because the overflow builtins were not implemented in the compiler that produced it, and the study says that sanitiser builds are the target. The record gives the precedent only for the trap, not for the fused forms.

**Cf.** 9.14 (TRAPCC), docs/study-proposals.md item 9.

<a id="w-addv"></a>
#### ADDV

![ADDV: R2, prefix 111100000010, sub-opcode 0001000000; operands reg5, reg5; 4 bytes](figures/w/addv/01.svg)

```
ADDV Rs, Rd
```

Operation, flags and exceptions as for the entry OVF above; 1 layout form, each a chart of its own (above).

<a id="w-subv"></a>
#### SUBV

![SUBV: R2, prefix 111100000010, sub-opcode 0001000001; operands reg5, reg5; 4 bytes](figures/w/subv/01.svg)

```
SUBV Rs, Rd
```

Operation, flags and exceptions as for the entry OVF above; 1 layout form, each a chart of its own (above).

<a id="w-mulv"></a>
#### MULV

![MULV: R2, prefix 111100000010, sub-opcode 0001000010; operands reg5, reg5; 4 bytes](figures/w/mulv/01.svg)

```
MULV Rs, Rd
```

Operation, flags and exceptions as for the entry OVF above; 1 layout form, each a chart of its own (above).
<!-- /entries:9.7 -->

## 9.8 Logic, shifts and rotates

**9.8.1** `AND`, `BIC` (bit clear), `BIS` (bit set, the or), `XOR` and `BIT` (test) are two-byte ALU operations; `COM` is one's complement.

**9.8.2** `SHL`, `SHR` and `SAR` shift by a count taken from `rm` (a register, an immediate, or memory); `ASL` and `ASR` are the by-one forms in two bytes. *(D)*

**9.8.3** A shift count of 64 or more shifts the value entirely away; `C` receives the last bit that left. *(D)*

**9.8.4** `ROR` rotates right by a register count and `RORI` by an immediate; `ROL Rd, Rs, #n` assembles to `RORI` with `64 - n`; `RORI32` rotates the low 32 bits and sign-extends. Rotates write no flags. *(D)*

**9.8.5** `DSHR` is a double-width funnel shift. It writes no flags. *(D)*

*Commentary.* **Precedent.** The PDP-11 had `ASL`, `ASR`, `ROL` and `ROR` by one through the carry; x86's `SHRD` and ARM's `EXTR` are the funnel shifts. **Trade-offs.** One rotate direction is enough, so there is no by-one `ROL` in a two-byte slot; rotates are not through the carry because a carry chain is fragile when the carry flag is shared. **Improvements.** The shift count comes from `rm`, not from a fixed register like x86's `CL`, which costs a register shuffle in every hand-written loop. **Benefits.** Multi-precision shifting is `DSHR`, two instructions for any distance. **Modern comparables.** RISC-V and AArch64 have rotates by register and by immediate; x86 has `ROL`/`ROR` through the carry as well. **Use.** `RORI` and `RORI32` are for hashes and ciphers, which rotate by constants; `DSHR` shifts a bignum. **Impact.** *Kernel:* Bit tests and mask operations on the status and page-table words are single instructions. *Compiler:* The shift count may be any register, immediate or memory operand, so the compiler never has to move a count into a fixed register; hashes and ciphers rotate by constants. *Hardware:* The barrel shifter (about 450 lookup tables) serves shifts and rotates, and writing no flag for rotates removes a result path.

<!-- entries:9.8 -->
<a id="w-bic"></a>
### BIC: Bit clear

![BIC: LDF.B28, prefix 011101, sub-opcode 1001; operands b5d28s-x1, reg5; 6 bytes](figures/w/bic/01.svg)

![BIC: LDF.X22, prefix 01001, sub-opcode 1001; operands x5-5d22s, reg5; 6 bytes](figures/w/bic/02.svg)

![BIC: LDF.PC32, prefix 1010100, sub-opcode 1001; operands pc32-u1, reg5; 6 bytes](figures/w/bic/05.svg)

![BIC: LDF.A32, prefix 1010101, sub-opcode 1001; operands abs32, reg5; 6 bytes](figures/w/bic/06.svg)

![BIC: LDFI.I32, prefix 1010110, sub-opcode 0010; operands imm32s, reg5; 6 bytes](figures/w/bic/07.svg)

![BIC: DPF.D28, prefix 11101111010, sub-opcode 1001; operands dpd28s-x1, reg5; 6 bytes](figures/w/bic/08.svg)

![BIC: LDF.PI12, prefix 011111, sub-opcode 1001; operands pi5-s12, reg5; 4 bytes](figures/w/bic/03.svg)

![BIC: LDF.PD12, prefix 100000, sub-opcode 1001; operands pd5-s12, reg5; 4 bytes](figures/w/bic/04.svg)

![BIC: RRF5, prefix 1111001100100101, sub-opcode 001001; operands reg5, reg5; 4 bytes](figures/w/bic/10.svg)

![BIC: LDI12H/c, prefix 11110010011111, sub-opcode 11; operands imm12s, reg4; 4 bytes](figures/w/bic/11.svg)

![BIC: LDI12/d, prefix 11110010100111, sub-opcode 0; operands imm12s, reg5; 4 bytes](figures/w/bic/12.svg)

![BIC: LDPC12H/d, prefix 1111001000010, sub-opcode 000; operands pc12-u1, reg4; 4 bytes](figures/w/bic/13.svg)

![BIC: RRF, prefix 0010, sub-opcode 1001; operands reg4, reg4; 2 bytes](figures/w/bic/09.svg)

**Mnemonics:** `BIC`

**Syntax**

```
BIC rm, Rd
```

**Encoding**

![Encoding of BIC](figures/LDF-B28-1.svg)

The chart is the leaf `LDF-B28-1`, LDF.B28, prefix `011101`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `op2` is `reg5`: register, 5 bits. `sub` (4 bits) selects the mnemonic: `movq` 0000, `movl` 0001, `movw` 0010, `movb` 0011, `movzl` 0100, `movzw` 0101, `movzb` 0110, `add` 0111, `sub` 1000, `bic` 1001, `bis` 1010, `xor` 1011, `and` 1100, `mul` 1101, `mulh` 1110, `shl` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`LDF-B28-1`](dictionary/by-encoding.md#LDF-B28-1), [`LDF-X22-1`](dictionary/by-encoding.md#LDF-X22-1), [`LDF-PI12-1`](dictionary/by-encoding.md#LDF-PI12-1), [`LDF-PD12-1`](dictionary/by-encoding.md#LDF-PD12-1), [`LDF-PC32-1`](dictionary/by-encoding.md#LDF-PC32-1), [`LDF-A32-1`](dictionary/by-encoding.md#LDF-A32-1), [`LDFI-I32-1`](dictionary/by-encoding.md#LDFI-I32-1), [`DPF-D28-1`](dictionary/by-encoding.md#DPF-D28-1), [`RRF-1`](dictionary/by-encoding.md#RRF-1), [`RRF5-1`](dictionary/by-encoding.md#RRF5-1), [`LDI12H-c-1`](dictionary/by-encoding.md#LDI12H-c-1), [`LDI12-d-2`](dictionary/by-encoding.md#LDI12-d-2), [`LDPC12H-d-1`](dictionary/by-encoding.md#LDPC12H-d-1).

**Operation**

```
Rd ← Rd AND NOT rm
```

**Flags** `N` and `Z` from the result, `V` cleared, `C` unchanged.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

The assembler also accepts `BIC #imm, rm` as `AND #~imm, rm`.


<a id="w-bis"></a>
### BIS: Bit set (inclusive or)

![BIS: LDF.B28, prefix 011101, sub-opcode 1010; operands b5d28s-x1, reg5; 6 bytes](figures/w/bis/01.svg)

![BIS: LDF.X22, prefix 01001, sub-opcode 1010; operands x5-5d22s, reg5; 6 bytes](figures/w/bis/02.svg)

![BIS: LDF.PC32, prefix 1010100, sub-opcode 1010; operands pc32-u1, reg5; 6 bytes](figures/w/bis/05.svg)

![BIS: LDF.A32, prefix 1010101, sub-opcode 1010; operands abs32, reg5; 6 bytes](figures/w/bis/06.svg)

![BIS: LDFI.I32, prefix 1010110, sub-opcode 0011; operands imm32s, reg5; 6 bytes](figures/w/bis/07.svg)

![BIS: DPF.D28, prefix 11101111010, sub-opcode 1010; operands dpd28s-x1, reg5; 6 bytes](figures/w/bis/08.svg)

![BIS: LDF.PI12, prefix 011111, sub-opcode 1010; operands pi5-s12, reg5; 4 bytes](figures/w/bis/03.svg)

![BIS: LDF.PD12, prefix 100000, sub-opcode 1010; operands pd5-s12, reg5; 4 bytes](figures/w/bis/04.svg)

![BIS: RRF5, prefix 1111001100100101, sub-opcode 001010; operands reg5, reg5; 4 bytes](figures/w/bis/10.svg)

![BIS: LDBu6/c, prefix 11110010011011, sub-opcode 11; operands b5d6u-xsz, reg5; 4 bytes](figures/w/bis/12.svg)

![BIS: LDI12H/c, prefix 11110010011111, sub-opcode 00; operands imm12s, reg4; 4 bytes](figures/w/bis/13.svg)

![BIS: LDBu8H/c, prefix 1111000110011, sub-opcode 11; operands b4d8u-xsz, reg5; 4 bytes](figures/w/bis/14.svg)

![BIS: LDS12H/c, prefix 11110010101001, sub-opcode 11; operands spd12u-xsz, reg4; 4 bytes](figures/w/bis/15.svg)

![BIS: LDX0/c, prefix 1111000111011, sub-opcode 11; operands x5-5d0s, reg5; 4 bytes](figures/w/bis/16.svg)

![BIS: LDPC16H/c, prefix 1110110101, sub-opcode 11; operands pc16-u1, reg4; 4 bytes](figures/w/bis/17.svg)

![BIS: LDBu8/c, prefix 111100010011, sub-opcode 11; operands b5d8u-xsz, reg5; 4 bytes](figures/w/bis/18.svg)

![BIS: RRF, prefix 0010, sub-opcode 1010; operands reg4, reg4; 2 bytes](figures/w/bis/09.svg)

![BIS: RR5, prefix 000, sub-opcode 110; operands reg5, reg5; 2 bytes](figures/w/bis/11.svg)

**Mnemonics:** `BIS`

**Syntax**

```
BIS rm, Rd
```

**Encoding**

![Encoding of BIS](figures/LDF-B28-1.svg)

The chart is the leaf `LDF-B28-1`, LDF.B28, prefix `011101`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `op2` is `reg5`: register, 5 bits. `sub` (4 bits) selects the mnemonic: `movq` 0000, `movl` 0001, `movw` 0010, `movb` 0011, `movzl` 0100, `movzw` 0101, `movzb` 0110, `add` 0111, `sub` 1000, `bic` 1001, `bis` 1010, `xor` 1011, `and` 1100, `mul` 1101, `mulh` 1110, `shl` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`LDF-B28-1`](dictionary/by-encoding.md#LDF-B28-1), [`LDF-X22-1`](dictionary/by-encoding.md#LDF-X22-1), [`LDF-PI12-1`](dictionary/by-encoding.md#LDF-PI12-1), [`LDF-PD12-1`](dictionary/by-encoding.md#LDF-PD12-1), [`LDF-PC32-1`](dictionary/by-encoding.md#LDF-PC32-1), [`LDF-A32-1`](dictionary/by-encoding.md#LDF-A32-1), [`LDFI-I32-1`](dictionary/by-encoding.md#LDFI-I32-1), [`DPF-D28-1`](dictionary/by-encoding.md#DPF-D28-1), [`RRF-1`](dictionary/by-encoding.md#RRF-1), [`RRF5-1`](dictionary/by-encoding.md#RRF5-1), [`RR5-1`](dictionary/by-encoding.md#RR5-1), [`LDBu6-c-1`](dictionary/by-encoding.md#LDBu6-c-1), [`LDI12H-c-1`](dictionary/by-encoding.md#LDI12H-c-1), [`LDBu8H-c-1`](dictionary/by-encoding.md#LDBu8H-c-1), [`LDS12H-c-1`](dictionary/by-encoding.md#LDS12H-c-1), [`LDX0-c-1`](dictionary/by-encoding.md#LDX0-c-1), [`LDPC16H-c-1`](dictionary/by-encoding.md#LDPC16H-c-1), [`LDBu8-c-1`](dictionary/by-encoding.md#LDBu8-c-1).

**Operation**

```
Rd ← Rd OR rm
```

**Flags** `N` and `Z` from the result, `V` cleared, `C` unchanged.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.


<a id="w-bit"></a>
### BIT: Bit test

![BIT: LDF.B28, prefix 1010001, sub-opcode 101; operands b5d28s-x1, reg5; 6 bytes](figures/w/bit/01.svg)

![BIT: LDF.X22, prefix 011110, sub-opcode 101; operands x5-5d22s, reg5; 6 bytes](figures/w/bit/02.svg)

![BIT: LDF.PC32, prefix 11001100, sub-opcode 101; operands pc32-u1, reg5; 6 bytes](figures/w/bit/05.svg)

![BIT: LDF.A32, prefix 11001101, sub-opcode 101; operands abs32, reg5; 6 bytes](figures/w/bit/06.svg)

![BIT: LDFI.I32, prefix 1010110, sub-opcode 1110; operands imm32s, reg5; 6 bytes](figures/w/bit/07.svg)

![BIT: DPF.D28, prefix 111100000110, sub-opcode 101; operands dpd28s-x1, reg5; 6 bytes](figures/w/bit/08.svg)

![BIT: LDF.PI12, prefix 1010010, sub-opcode 101; operands pi5-s12, reg5; 4 bytes](figures/w/bit/03.svg)

![BIT: LDF.PD12, prefix 1010011, sub-opcode 101; operands pd5-s12, reg5; 4 bytes](figures/w/bit/04.svg)

![BIT: RRF5, prefix 1111001100100101, sub-opcode 010101; operands reg5, reg5; 4 bytes](figures/w/bit/10.svg)

![BIT: LDI12/d, prefix 111100110000111; operands imm12s, reg5; 4 bytes](figures/w/bit/11.svg)

![BIT: LDPC12H/d, prefix 111100110001110, sub-opcode 1; operands pc12-u1, reg4; 4 bytes](figures/w/bit/12.svg)

![BIT: RRF, prefix 01010, sub-opcode 101; operands reg4, reg4; 2 bytes](figures/w/bit/09.svg)

**Mnemonics:** `BIT`

**Syntax**

```
BIT rm, Rd
```

**Encoding**

![Encoding of BIT](figures/LDF-B28-2.svg)

The chart is the leaf `LDF-B28-2`, LDF.B28, prefix `1010001`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `op2` is `reg5`: register, 5 bits. `sub` (3 bits) selects the mnemonic: `shr` 000, `sar` 001, `fadd` 010, `fsub` 011, `fmul` 100, `bit` 101, `lea` 110, `movub` 111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`LDF-B28-2`](dictionary/by-encoding.md#LDF-B28-2), [`LDF-X22-2`](dictionary/by-encoding.md#LDF-X22-2), [`LDF-PI12-2`](dictionary/by-encoding.md#LDF-PI12-2), [`LDF-PD12-2`](dictionary/by-encoding.md#LDF-PD12-2), [`LDF-PC32-2`](dictionary/by-encoding.md#LDF-PC32-2), [`LDF-A32-2`](dictionary/by-encoding.md#LDF-A32-2), [`LDFI-I32-1`](dictionary/by-encoding.md#LDFI-I32-1), [`DPF-D28-2`](dictionary/by-encoding.md#DPF-D28-2), [`RRF-2`](dictionary/by-encoding.md#RRF-2), [`RRF5-1`](dictionary/by-encoding.md#RRF5-1), [`LDI12-d-3`](dictionary/by-encoding.md#LDI12-d-3), [`LDPC12H-d-2`](dictionary/by-encoding.md#LDPC12H-d-2).

**Operation**

```
tmp ← Rd AND rm         ; the result is discarded
```

**Flags** `N` and `Z` from the result, `V` cleared, `C` unchanged.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.


<a id="w-xor"></a>
### XOR: Exclusive or

![XOR: LDF.B28, prefix 011101, sub-opcode 1011; operands b5d28s-x1, reg5; 6 bytes](figures/w/xor/01.svg)

![XOR: LDF.X22, prefix 01001, sub-opcode 1011; operands x5-5d22s, reg5; 6 bytes](figures/w/xor/02.svg)

![XOR: LDF.PC32, prefix 1010100, sub-opcode 1011; operands pc32-u1, reg5; 6 bytes](figures/w/xor/05.svg)

![XOR: LDF.A32, prefix 1010101, sub-opcode 1011; operands abs32, reg5; 6 bytes](figures/w/xor/06.svg)

![XOR: LDFI.I32, prefix 1010110, sub-opcode 0100; operands imm32s, reg5; 6 bytes](figures/w/xor/07.svg)

![XOR: DPF.D28, prefix 11101111010, sub-opcode 1011; operands dpd28s-x1, reg5; 6 bytes](figures/w/xor/08.svg)

![XOR: LDF.PI12, prefix 011111, sub-opcode 1011; operands pi5-s12, reg5; 4 bytes](figures/w/xor/03.svg)

![XOR: LDF.PD12, prefix 100000, sub-opcode 1011; operands pd5-s12, reg5; 4 bytes](figures/w/xor/04.svg)

![XOR: RRF5, prefix 1111001100100101, sub-opcode 001011; operands reg5, reg5; 4 bytes](figures/w/xor/10.svg)

![XOR: LDBu6/c, prefix 1111001100101100; operands b5d6u-xsz, reg5; 4 bytes](figures/w/xor/12.svg)

![XOR: LDI12H/c, prefix 11110010011111, sub-opcode 01; operands imm12s, reg4; 4 bytes](figures/w/xor/13.svg)

![XOR: LDBu8H/c, prefix 111100110000101; operands b4d8u-xsz, reg5; 4 bytes](figures/w/xor/14.svg)

![XOR: LDS12H/c, prefix 1111001100110000; operands spd12u-xsz, reg4; 4 bytes](figures/w/xor/15.svg)

![XOR: LDX0/c, prefix 111100110001001; operands x5-5d0s, reg5; 4 bytes](figures/w/xor/16.svg)

![XOR: LDPC16H/c, prefix 111100001111; operands pc16-u1, reg4; 4 bytes](figures/w/xor/17.svg)

![XOR: LDBu8/c, prefix 11110010110001; operands b5d8u-xsz, reg5; 4 bytes](figures/w/xor/18.svg)

![XOR: RRF, prefix 0010, sub-opcode 1011; operands reg4, reg4; 2 bytes](figures/w/xor/09.svg)

![XOR: RR5, prefix 000, sub-opcode 100; operands reg5, reg5; 2 bytes](figures/w/xor/11.svg)

**Mnemonics:** `XOR`

**Syntax**

```
XOR rm, Rd
```

**Encoding**

![Encoding of XOR](figures/LDF-B28-1.svg)

The chart is the leaf `LDF-B28-1`, LDF.B28, prefix `011101`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `op2` is `reg5`: register, 5 bits. `sub` (4 bits) selects the mnemonic: `movq` 0000, `movl` 0001, `movw` 0010, `movb` 0011, `movzl` 0100, `movzw` 0101, `movzb` 0110, `add` 0111, `sub` 1000, `bic` 1001, `bis` 1010, `xor` 1011, `and` 1100, `mul` 1101, `mulh` 1110, `shl` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`LDF-B28-1`](dictionary/by-encoding.md#LDF-B28-1), [`LDF-X22-1`](dictionary/by-encoding.md#LDF-X22-1), [`LDF-PI12-1`](dictionary/by-encoding.md#LDF-PI12-1), [`LDF-PD12-1`](dictionary/by-encoding.md#LDF-PD12-1), [`LDF-PC32-1`](dictionary/by-encoding.md#LDF-PC32-1), [`LDF-A32-1`](dictionary/by-encoding.md#LDF-A32-1), [`LDFI-I32-1`](dictionary/by-encoding.md#LDFI-I32-1), [`DPF-D28-1`](dictionary/by-encoding.md#DPF-D28-1), [`RRF-1`](dictionary/by-encoding.md#RRF-1), [`RRF5-1`](dictionary/by-encoding.md#RRF5-1), [`RR5-1`](dictionary/by-encoding.md#RR5-1), [`LDBu6-c-2`](dictionary/by-encoding.md#LDBu6-c-2), [`LDI12H-c-1`](dictionary/by-encoding.md#LDI12H-c-1), [`LDBu8H-c-2`](dictionary/by-encoding.md#LDBu8H-c-2), [`LDS12H-c-2`](dictionary/by-encoding.md#LDS12H-c-2), [`LDX0-c-2`](dictionary/by-encoding.md#LDX0-c-2), [`LDPC16H-c-2`](dictionary/by-encoding.md#LDPC16H-c-2), [`LDBu8-c-2`](dictionary/by-encoding.md#LDBu8-c-2).

**Operation**

```
Rd ← Rd XOR rm
```

**Flags** `N` and `Z` from the result, `V` cleared, `C` unchanged.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.


<a id="w-and"></a>
### AND: And

![AND: LDF.B28, prefix 011101, sub-opcode 1100; operands b5d28s-x1, reg5; 6 bytes](figures/w/and/01.svg)

![AND: LDF.X22, prefix 01001, sub-opcode 1100; operands x5-5d22s, reg5; 6 bytes](figures/w/and/02.svg)

![AND: LDF.PC32, prefix 1010100, sub-opcode 1100; operands pc32-u1, reg5; 6 bytes](figures/w/and/05.svg)

![AND: LDF.A32, prefix 1010101, sub-opcode 1100; operands abs32, reg5; 6 bytes](figures/w/and/06.svg)

![AND: LDFI.I32, prefix 1010110, sub-opcode 0101; operands imm32s, reg5; 6 bytes](figures/w/and/07.svg)

![AND: DPF.D28, prefix 11101111010, sub-opcode 1100; operands dpd28s-x1, reg5; 6 bytes](figures/w/and/08.svg)

![AND: LDF.PI12, prefix 011111, sub-opcode 1100; operands pi5-s12, reg5; 4 bytes](figures/w/and/03.svg)

![AND: LDF.PD12, prefix 100000, sub-opcode 1100; operands pd5-s12, reg5; 4 bytes](figures/w/and/04.svg)

![AND: RRF5, prefix 1111001100100101, sub-opcode 001100; operands reg5, reg5; 4 bytes](figures/w/and/10.svg)

![AND: LDI12H/b, prefix 1111001100101001; operands imm12s, reg4; 4 bytes](figures/w/and/12.svg)

![AND: LDBu6/c, prefix 11110010011011, sub-opcode 10; operands b5d6u-xsz, reg5; 4 bytes](figures/w/and/13.svg)

![AND: LDBu8H/c, prefix 1111000110011, sub-opcode 10; operands b4d8u-xsz, reg5; 4 bytes](figures/w/and/14.svg)

![AND: LDI14H/b, prefix 11110010100110; operands imm14s, reg4; 4 bytes](figures/w/and/15.svg)

![AND: LDS12H/c, prefix 11110010101001, sub-opcode 10; operands spd12u-xsz, reg4; 4 bytes](figures/w/and/16.svg)

![AND: LDI18H/b, prefix 1110110011; operands imm18s, reg4; 4 bytes](figures/w/and/18.svg)

![AND: LDI12/b, prefix 111100110001000; operands imm12s, reg5; 4 bytes](figures/w/and/19.svg)

![AND: LDX0/c, prefix 1111000111011, sub-opcode 10; operands x5-5d0s, reg5; 4 bytes](figures/w/and/20.svg)

![AND: LDPC16H/c, prefix 1110110101, sub-opcode 10; operands pc16-u1, reg4; 4 bytes](figures/w/and/21.svg)

![AND: LDBu8/c, prefix 111100010011, sub-opcode 10; operands b5d8u-xsz, reg5; 4 bytes](figures/w/and/22.svg)

![AND: RRF, prefix 0010, sub-opcode 1100; operands reg4, reg4; 2 bytes](figures/w/and/09.svg)

![AND: RR5, prefix 000, sub-opcode 101; operands reg5, reg5; 2 bytes](figures/w/and/11.svg)

![AND: IMMh43/b, prefix 111001011; operands imm3s, reg4; 2 bytes](figures/w/and/17.svg)

**Mnemonics:** `AND`

**Syntax**

```
AND rm, Rd
```

**Encoding**

![Encoding of AND](figures/LDF-B28-1.svg)

The chart is the leaf `LDF-B28-1`, LDF.B28, prefix `011101`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `op2` is `reg5`: register, 5 bits. `sub` (4 bits) selects the mnemonic: `movq` 0000, `movl` 0001, `movw` 0010, `movb` 0011, `movzl` 0100, `movzw` 0101, `movzb` 0110, `add` 0111, `sub` 1000, `bic` 1001, `bis` 1010, `xor` 1011, `and` 1100, `mul` 1101, `mulh` 1110, `shl` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`LDF-B28-1`](dictionary/by-encoding.md#LDF-B28-1), [`LDF-X22-1`](dictionary/by-encoding.md#LDF-X22-1), [`LDF-PI12-1`](dictionary/by-encoding.md#LDF-PI12-1), [`LDF-PD12-1`](dictionary/by-encoding.md#LDF-PD12-1), [`LDF-PC32-1`](dictionary/by-encoding.md#LDF-PC32-1), [`LDF-A32-1`](dictionary/by-encoding.md#LDF-A32-1), [`LDFI-I32-1`](dictionary/by-encoding.md#LDFI-I32-1), [`DPF-D28-1`](dictionary/by-encoding.md#DPF-D28-1), [`RRF-1`](dictionary/by-encoding.md#RRF-1), [`RRF5-1`](dictionary/by-encoding.md#RRF5-1), [`RR5-1`](dictionary/by-encoding.md#RR5-1), [`LDI12H-b-2`](dictionary/by-encoding.md#LDI12H-b-2), [`LDBu6-c-1`](dictionary/by-encoding.md#LDBu6-c-1), [`LDBu8H-c-1`](dictionary/by-encoding.md#LDBu8H-c-1), [`LDI14H-b-2`](dictionary/by-encoding.md#LDI14H-b-2), [`LDS12H-c-1`](dictionary/by-encoding.md#LDS12H-c-1), [`IMMh43-b-2`](dictionary/by-encoding.md#IMMh43-b-2), [`LDI18H-b-2`](dictionary/by-encoding.md#LDI18H-b-2), [`LDI12-b-2`](dictionary/by-encoding.md#LDI12-b-2), [`LDX0-c-1`](dictionary/by-encoding.md#LDX0-c-1), [`LDPC16H-c-1`](dictionary/by-encoding.md#LDPC16H-c-1), [`LDBu8-c-1`](dictionary/by-encoding.md#LDBu8-c-1).

**Operation**

```
Rd ← Rd AND rm
```

**Flags** `N` and `Z` from the result, `V` cleared, `C` unchanged.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.


### SHIFT: Shift left, shift right logical, shift right arithmetic

**Mnemonics:** `SHL`, `SHR`, `SAR`

**Syntax**

```
SHL rm, Rd
SHR rm, Rd
SAR rm, Rd
```

**Encoding**

![Encoding of SHIFT](figures/LDF-B28-1.svg)

The chart is the leaf `LDF-B28-1`, LDF.B28, prefix `011101`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `op2` is `reg5`: register, 5 bits. `sub` (4 bits) selects the mnemonic: `movq` 0000, `movl` 0001, `movw` 0010, `movb` 0011, `movzl` 0100, `movzw` 0101, `movzb` 0110, `add` 0111, `sub` 1000, `bic` 1001, `bis` 1010, `xor` 1011, `and` 1100, `mul` 1101, `mulh` 1110, `shl` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`LDF-B28-1`](dictionary/by-encoding.md#LDF-B28-1), [`LDF-X22-1`](dictionary/by-encoding.md#LDF-X22-1), [`LDF-PI12-1`](dictionary/by-encoding.md#LDF-PI12-1), [`LDF-PD12-1`](dictionary/by-encoding.md#LDF-PD12-1), [`LDF-PC32-1`](dictionary/by-encoding.md#LDF-PC32-1), [`LDF-A32-1`](dictionary/by-encoding.md#LDF-A32-1), [`LDFI-I32-1`](dictionary/by-encoding.md#LDFI-I32-1), [`DPF-D28-1`](dictionary/by-encoding.md#DPF-D28-1), [`RRF-1`](dictionary/by-encoding.md#RRF-1), [`RRF5-1`](dictionary/by-encoding.md#RRF5-1), [`RR5-1`](dictionary/by-encoding.md#RR5-1), [`LDI12-d-1`](dictionary/by-encoding.md#LDI12-d-1), [`SHIh43-a-1`](dictionary/by-encoding.md#SHIh43-a-1), [`SHIh44-a-1`](dictionary/by-encoding.md#SHIh44-a-1), [`LDPC12H-d-1`](dictionary/by-encoding.md#LDPC12H-d-1), [`LDF-B28-2`](dictionary/by-encoding.md#LDF-B28-2), [`LDF-X22-2`](dictionary/by-encoding.md#LDF-X22-2), [`LDF-PI12-2`](dictionary/by-encoding.md#LDF-PI12-2), [`LDF-PD12-2`](dictionary/by-encoding.md#LDF-PD12-2), [`LDF-PC32-2`](dictionary/by-encoding.md#LDF-PC32-2), [`LDF-A32-2`](dictionary/by-encoding.md#LDF-A32-2), [`DPF-D28-2`](dictionary/by-encoding.md#DPF-D28-2), [`RRF-2`](dictionary/by-encoding.md#RRF-2).

**Operation**

```
n ← rm                                 ; the count: a register, an immediate, or memory
SHL: Rd ← (n ≥ 64) ? 0 : Rd << n
SHR: Rd ← (n ≥ 64) ? 0 : Rd >>u n
SAR: Rd ← (n ≥ 64) ? (Rd < 0 ? -1 : 0) : Rd >>s n
```

**Flags** `N` and `Z` from the result, `V` cleared, `C` the last bit shifted out (bit 63 for `SHL`, bit 0 for `SHR` and `SAR`). **The same flags are written for every count**: a count of zero gives `N` and `Z` from the unchanged operand, `V` = 0 and `C` = 0.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

The count is read as an unsigned 64-bit value, so a count of 64 or more shifts the value entirely away. Small immediate counts have one-parcel forms (the layouts of this entry); `ASL` and `ASR` are the by-one forms; rotates are `ROR` and `RORI`.

<a id="w-shl"></a>
#### SHL

![SHL: LDF.B28, prefix 011101, sub-opcode 1111; operands b5d28s-x1, reg5; 6 bytes](figures/w/shl/01.svg)

![SHL: LDF.X22, prefix 01001, sub-opcode 1111; operands x5-5d22s, reg5; 6 bytes](figures/w/shl/02.svg)

![SHL: LDF.PC32, prefix 1010100, sub-opcode 1111; operands pc32-u1, reg5; 6 bytes](figures/w/shl/05.svg)

![SHL: LDF.A32, prefix 1010101, sub-opcode 1111; operands abs32, reg5; 6 bytes](figures/w/shl/06.svg)

![SHL: LDFI.I32, prefix 1010110, sub-opcode 1000; operands imm32s, reg5; 6 bytes](figures/w/shl/07.svg)

![SHL: DPF.D28, prefix 11101111010, sub-opcode 1111; operands dpd28s-x1, reg5; 6 bytes](figures/w/shl/08.svg)

![SHL: LDF.PI12, prefix 011111, sub-opcode 1111; operands pi5-s12, reg5; 4 bytes](figures/w/shl/03.svg)

![SHL: LDF.PD12, prefix 100000, sub-opcode 1111; operands pd5-s12, reg5; 4 bytes](figures/w/shl/04.svg)

![SHL: RRF5, prefix 1111001100100101, sub-opcode 001111; operands reg5, reg5; 4 bytes](figures/w/shl/10.svg)

![SHL: LDI12/d, prefix 1111000110110, sub-opcode 00; operands imm12s, reg5; 4 bytes](figures/w/shl/12.svg)

![SHL: LDPC12H/d, prefix 1111001000010, sub-opcode 011; operands pc12-u1, reg4; 4 bytes](figures/w/shl/15.svg)

![SHL: RRF, prefix 0010, sub-opcode 1111; operands reg4, reg4; 2 bytes](figures/w/shl/09.svg)

![SHL: RR5, prefix 000, sub-opcode 111; operands reg5, reg5; 2 bytes](figures/w/shl/11.svg)

![SHL: SHIh43/a, prefix 1011100, sub-opcode 00; operands imm3u, reg4; 2 bytes](figures/w/shl/13.svg)

![SHL: SHIh44/a, prefix 100110, sub-opcode 00; operands imm4u, reg4; 2 bytes](figures/w/shl/14.svg)

```
SHL rm, Rd
```

Operation, flags and exceptions as for the entry SHIFT above; 15 layout forms, each a chart of its own (above).

<a id="w-shr"></a>
#### SHR

![SHR: LDF.B28, prefix 1010001, sub-opcode 000; operands b5d28s-x1, reg5; 6 bytes](figures/w/shr/01.svg)

![SHR: LDF.X22, prefix 011110, sub-opcode 000; operands x5-5d22s, reg5; 6 bytes](figures/w/shr/02.svg)

![SHR: LDF.PC32, prefix 11001100, sub-opcode 000; operands pc32-u1, reg5; 6 bytes](figures/w/shr/05.svg)

![SHR: LDF.A32, prefix 11001101, sub-opcode 000; operands abs32, reg5; 6 bytes](figures/w/shr/06.svg)

![SHR: LDFI.I32, prefix 1010110, sub-opcode 1001; operands imm32s, reg5; 6 bytes](figures/w/shr/07.svg)

![SHR: DPF.D28, prefix 111100000110, sub-opcode 000; operands dpd28s-x1, reg5; 6 bytes](figures/w/shr/08.svg)

![SHR: LDF.PI12, prefix 1010010, sub-opcode 000; operands pi5-s12, reg5; 4 bytes](figures/w/shr/03.svg)

![SHR: LDF.PD12, prefix 1010011, sub-opcode 000; operands pd5-s12, reg5; 4 bytes](figures/w/shr/04.svg)

![SHR: RRF5, prefix 1111001100100101, sub-opcode 010000; operands reg5, reg5; 4 bytes](figures/w/shr/10.svg)

![SHR: LDI12/d, prefix 1111000110110, sub-opcode 01; operands imm12s, reg5; 4 bytes](figures/w/shr/11.svg)

![SHR: LDPC12H/d, prefix 1111001000010, sub-opcode 100; operands pc12-u1, reg4; 4 bytes](figures/w/shr/14.svg)

![SHR: RRF, prefix 01010, sub-opcode 000; operands reg4, reg4; 2 bytes](figures/w/shr/09.svg)

![SHR: SHIh43/a, prefix 1011100, sub-opcode 01; operands imm3u, reg4; 2 bytes](figures/w/shr/12.svg)

![SHR: SHIh44/a, prefix 100110, sub-opcode 01; operands imm4u, reg4; 2 bytes](figures/w/shr/13.svg)

```
SHR rm, Rd
```

Operation, flags and exceptions as for the entry SHIFT above; 14 layout forms, each a chart of its own (above).

<a id="w-sar"></a>
#### SAR

![SAR: LDF.B28, prefix 1010001, sub-opcode 001; operands b5d28s-x1, reg5; 6 bytes](figures/w/sar/01.svg)

![SAR: LDF.X22, prefix 011110, sub-opcode 001; operands x5-5d22s, reg5; 6 bytes](figures/w/sar/02.svg)

![SAR: LDF.PC32, prefix 11001100, sub-opcode 001; operands pc32-u1, reg5; 6 bytes](figures/w/sar/05.svg)

![SAR: LDF.A32, prefix 11001101, sub-opcode 001; operands abs32, reg5; 6 bytes](figures/w/sar/06.svg)

![SAR: LDFI.I32, prefix 1010110, sub-opcode 1010; operands imm32s, reg5; 6 bytes](figures/w/sar/07.svg)

![SAR: DPF.D28, prefix 111100000110, sub-opcode 001; operands dpd28s-x1, reg5; 6 bytes](figures/w/sar/08.svg)

![SAR: LDF.PI12, prefix 1010010, sub-opcode 001; operands pi5-s12, reg5; 4 bytes](figures/w/sar/03.svg)

![SAR: LDF.PD12, prefix 1010011, sub-opcode 001; operands pd5-s12, reg5; 4 bytes](figures/w/sar/04.svg)

![SAR: RRF5, prefix 1111001100100101, sub-opcode 010001; operands reg5, reg5; 4 bytes](figures/w/sar/10.svg)

![SAR: LDI12/d, prefix 1111000110110, sub-opcode 10; operands imm12s, reg5; 4 bytes](figures/w/sar/11.svg)

![SAR: LDPC12H/d, prefix 1111001000010, sub-opcode 101; operands pc12-u1, reg4; 4 bytes](figures/w/sar/14.svg)

![SAR: RRF, prefix 01010, sub-opcode 001; operands reg4, reg4; 2 bytes](figures/w/sar/09.svg)

![SAR: SHIh43/a, prefix 1011100, sub-opcode 10; operands imm3u, reg4; 2 bytes](figures/w/sar/12.svg)

![SAR: SHIh44/a, prefix 100110, sub-opcode 10; operands imm4u, reg4; 2 bytes](figures/w/sar/13.svg)

```
SAR rm, Rd
```

Operation, flags and exceptions as for the entry SHIFT above; 14 layout forms, each a chart of its own (above).


<a id="w-clr"></a>
### CLR: Clear

![CLR: SOF.B28, prefix 11101110111, sub-opcode 0000; operands b5d28s-x1; 6 bytes](figures/w/clr/01.svg)

![CLR: SOF.X22, prefix 1110101101, sub-opcode 0000; operands x5-5d22s; 6 bytes](figures/w/clr/02.svg)

![CLR: SOF.PC32, prefix 111100000100, sub-opcode 0000; operands pc32-u1; 6 bytes](figures/w/clr/05.svg)

![CLR: SOF.A32, prefix 111100000101, sub-opcode 0000; operands abs32; 6 bytes](figures/w/clr/06.svg)

![CLR: SOF.PI12, prefix 11101111000, sub-opcode 0000; operands pi5-s12; 4 bytes](figures/w/clr/03.svg)

![CLR: SOF.PD12, prefix 11101111001, sub-opcode 0000; operands pd5-s12; 4 bytes](figures/w/clr/04.svg)

![CLR: SOBu12H/a, prefix 11110010011010, sub-opcode 00; operands b4d12u-xsz; 4 bytes](figures/w/clr/08.svg)

![CLR: SOX4/a, prefix 11110010101110, sub-opcode 00; operands x5-5d4s; 4 bytes](figures/w/clr/09.svg)

![CLR: SOBs12/a, prefix 1111000111111, sub-opcode 00; operands b5d12s-xsz; 4 bytes](figures/w/clr/10.svg)

![CLR: SOPR, prefix 11010100, sub-opcode 000; operands reg5; 2 bytes](figures/w/clr/07.svg)

**Mnemonics:** `CLR`

**Syntax**

```
CLR rm
```

**Encoding**

![Encoding of CLR](figures/SOF-B28-1.svg)

The chart is the leaf `SOF-B28-1`, SOF.B28, prefix `11101110111`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `sub` (4 bits) selects the mnemonic: `clr` 0000, `com` 0001, `inc` 0010, `dec` 0011, `neg` 0100, `tst` 0101, `adc` 0110, `sbc` 0111, `asl` 1000, `asr` 1001, `push` 1010, `pop` 1011, `jmp` 1100, `call` 1101, `jmpi` 1110, `calli` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SOF-B28-1`](dictionary/by-encoding.md#SOF-B28-1), [`SOF-X22-1`](dictionary/by-encoding.md#SOF-X22-1), [`SOF-PI12-1`](dictionary/by-encoding.md#SOF-PI12-1), [`SOF-PD12-1`](dictionary/by-encoding.md#SOF-PD12-1), [`SOF-PC32-1`](dictionary/by-encoding.md#SOF-PC32-1), [`SOF-A32-1`](dictionary/by-encoding.md#SOF-A32-1), [`SOPR-1`](dictionary/by-encoding.md#SOPR-1), [`SOBu12H-a-1`](dictionary/by-encoding.md#SOBu12H-a-1), [`SOX4-a-1`](dictionary/by-encoding.md#SOX4-a-1), [`SOBs12-a-1`](dictionary/by-encoding.md#SOBs12-a-1).

**Operation**

```
rm ← 0
```

**Flags** `N` = 0, `Z` = 1, `V` = 0, `C` = 0.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.


<a id="w-com"></a>
### COM: Complement

![COM: SOF.B28, prefix 11101110111, sub-opcode 0001; operands b5d28s-x1; 6 bytes](figures/w/com/01.svg)

![COM: SOF.X22, prefix 1110101101, sub-opcode 0001; operands x5-5d22s; 6 bytes](figures/w/com/02.svg)

![COM: SOF.PC32, prefix 111100000100, sub-opcode 0001; operands pc32-u1; 6 bytes](figures/w/com/05.svg)

![COM: SOF.A32, prefix 111100000101, sub-opcode 0001; operands abs32; 6 bytes](figures/w/com/06.svg)

![COM: SOF.PI12, prefix 11101111000, sub-opcode 0001; operands pi5-s12; 4 bytes](figures/w/com/03.svg)

![COM: SOF.PD12, prefix 11101111001, sub-opcode 0001; operands pd5-s12; 4 bytes](figures/w/com/04.svg)

![COM: SOPR, prefix 11010100, sub-opcode 001; operands reg5; 2 bytes](figures/w/com/07.svg)

**Mnemonics:** `COM`

**Syntax**

```
COM rm
```

**Encoding**

![Encoding of COM](figures/SOF-B28-1.svg)

The chart is the leaf `SOF-B28-1`, SOF.B28, prefix `11101110111`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `sub` (4 bits) selects the mnemonic: `clr` 0000, `com` 0001, `inc` 0010, `dec` 0011, `neg` 0100, `tst` 0101, `adc` 0110, `sbc` 0111, `asl` 1000, `asr` 1001, `push` 1010, `pop` 1011, `jmp` 1100, `call` 1101, `jmpi` 1110, `calli` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SOF-B28-1`](dictionary/by-encoding.md#SOF-B28-1), [`SOF-X22-1`](dictionary/by-encoding.md#SOF-X22-1), [`SOF-PI12-1`](dictionary/by-encoding.md#SOF-PI12-1), [`SOF-PD12-1`](dictionary/by-encoding.md#SOF-PD12-1), [`SOF-PC32-1`](dictionary/by-encoding.md#SOF-PC32-1), [`SOF-A32-1`](dictionary/by-encoding.md#SOF-A32-1), [`SOPR-1`](dictionary/by-encoding.md#SOPR-1).

**Operation**

```
rm ← NOT rm
```

**Flags** `N` and `Z` from the result, `V` = 0, `C` = 1 (the PDP-11 rule).

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

A two-byte instruction for a register operand.


<a id="w-tst"></a>
### TST: Test

![TST: SOF.B28, prefix 11101110111, sub-opcode 0101; operands b5d28s-x1; 6 bytes](figures/w/tst/01.svg)

![TST: SOF.X22, prefix 1110101101, sub-opcode 0101; operands x5-5d22s; 6 bytes](figures/w/tst/02.svg)

![TST: SOF.PC32, prefix 111100000100, sub-opcode 0101; operands pc32-u1; 6 bytes](figures/w/tst/05.svg)

![TST: SOF.A32, prefix 111100000101, sub-opcode 0101; operands abs32; 6 bytes](figures/w/tst/06.svg)

![TST: SOF.PI12, prefix 11101111000, sub-opcode 0101; operands pi5-s12; 4 bytes](figures/w/tst/03.svg)

![TST: SOF.PD12, prefix 11101111001, sub-opcode 0101; operands pd5-s12; 4 bytes](figures/w/tst/04.svg)

![TST: SOBu12H/a, prefix 11110010011010, sub-opcode 11; operands b4d12u-xsz; 4 bytes](figures/w/tst/08.svg)

![TST: SOX4/a, prefix 11110010101110, sub-opcode 11; operands x5-5d4s; 4 bytes](figures/w/tst/09.svg)

![TST: SOBs12/a, prefix 1111000111111, sub-opcode 11; operands b5d12s-xsz; 4 bytes](figures/w/tst/10.svg)

![TST: SOPR, prefix 11010100, sub-opcode 101; operands reg5; 2 bytes](figures/w/tst/07.svg)

**Mnemonics:** `TST`

**Syntax**

```
TST rm
```

**Encoding**

![Encoding of TST](figures/SOF-B28-1.svg)

The chart is the leaf `SOF-B28-1`, SOF.B28, prefix `11101110111`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `sub` (4 bits) selects the mnemonic: `clr` 0000, `com` 0001, `inc` 0010, `dec` 0011, `neg` 0100, `tst` 0101, `adc` 0110, `sbc` 0111, `asl` 1000, `asr` 1001, `push` 1010, `pop` 1011, `jmp` 1100, `call` 1101, `jmpi` 1110, `calli` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SOF-B28-1`](dictionary/by-encoding.md#SOF-B28-1), [`SOF-X22-1`](dictionary/by-encoding.md#SOF-X22-1), [`SOF-PI12-1`](dictionary/by-encoding.md#SOF-PI12-1), [`SOF-PD12-1`](dictionary/by-encoding.md#SOF-PD12-1), [`SOF-PC32-1`](dictionary/by-encoding.md#SOF-PC32-1), [`SOF-A32-1`](dictionary/by-encoding.md#SOF-A32-1), [`SOPR-1`](dictionary/by-encoding.md#SOPR-1), [`SOBu12H-a-1`](dictionary/by-encoding.md#SOBu12H-a-1), [`SOX4-a-1`](dictionary/by-encoding.md#SOX4-a-1), [`SOBs12-a-1`](dictionary/by-encoding.md#SOBs12-a-1).

**Operation**

```
set flags from rm; nothing is written
```

**Flags** `N` and `Z` from the operand, `V` = 0, `C` = 0.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.


<a id="w-asl"></a>
### ASL: Arithmetic shift left by one

![ASL: SOF.B28, prefix 11101110111, sub-opcode 1000; operands b5d28s-x1; 6 bytes](figures/w/asl/01.svg)

![ASL: SOF.X22, prefix 1110101101, sub-opcode 1000; operands x5-5d22s; 6 bytes](figures/w/asl/02.svg)

![ASL: SOF.PC32, prefix 111100000100, sub-opcode 1000; operands pc32-u1; 6 bytes](figures/w/asl/05.svg)

![ASL: SOF.A32, prefix 111100000101, sub-opcode 1000; operands abs32; 6 bytes](figures/w/asl/06.svg)

![ASL: SOF.PI12, prefix 11101111000, sub-opcode 1000; operands pi5-s12; 4 bytes](figures/w/asl/03.svg)

![ASL: SOF.PD12, prefix 11101111001, sub-opcode 1000; operands pd5-s12; 4 bytes](figures/w/asl/04.svg)

![ASL: SOPR, prefix 111000011, sub-opcode 00; operands reg5; 2 bytes](figures/w/asl/07.svg)

**Mnemonics:** `ASL`

**Syntax**

```
ASL rm
```

**Encoding**

![Encoding of ASL](figures/SOF-B28-1.svg)

The chart is the leaf `SOF-B28-1`, SOF.B28, prefix `11101110111`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `sub` (4 bits) selects the mnemonic: `clr` 0000, `com` 0001, `inc` 0010, `dec` 0011, `neg` 0100, `tst` 0101, `adc` 0110, `sbc` 0111, `asl` 1000, `asr` 1001, `push` 1010, `pop` 1011, `jmp` 1100, `call` 1101, `jmpi` 1110, `calli` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SOF-B28-1`](dictionary/by-encoding.md#SOF-B28-1), [`SOF-X22-1`](dictionary/by-encoding.md#SOF-X22-1), [`SOF-PI12-1`](dictionary/by-encoding.md#SOF-PI12-1), [`SOF-PD12-1`](dictionary/by-encoding.md#SOF-PD12-1), [`SOF-PC32-1`](dictionary/by-encoding.md#SOF-PC32-1), [`SOF-A32-1`](dictionary/by-encoding.md#SOF-A32-1), [`SOPR-2`](dictionary/by-encoding.md#SOPR-2).

**Operation**

```
C ← rm[63] ; rm ← rm << 1
```

**Flags** `N` and `Z` from the result, `C` the bit shifted out of bit 63, `V` = `N` xor `C` (set if the sign changed: the PDP-11 rule).

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

The by-one form of `SHL`.


<a id="w-asr"></a>
### ASR: Arithmetic shift right by one

![ASR: SOF.B28, prefix 11101110111, sub-opcode 1001; operands b5d28s-x1; 6 bytes](figures/w/asr/01.svg)

![ASR: SOF.X22, prefix 1110101101, sub-opcode 1001; operands x5-5d22s; 6 bytes](figures/w/asr/02.svg)

![ASR: SOF.PC32, prefix 111100000100, sub-opcode 1001; operands pc32-u1; 6 bytes](figures/w/asr/05.svg)

![ASR: SOF.A32, prefix 111100000101, sub-opcode 1001; operands abs32; 6 bytes](figures/w/asr/06.svg)

![ASR: SOF.PI12, prefix 11101111000, sub-opcode 1001; operands pi5-s12; 4 bytes](figures/w/asr/03.svg)

![ASR: SOF.PD12, prefix 11101111001, sub-opcode 1001; operands pd5-s12; 4 bytes](figures/w/asr/04.svg)

![ASR: SOPR, prefix 111000011, sub-opcode 01; operands reg5; 2 bytes](figures/w/asr/07.svg)

**Mnemonics:** `ASR`

**Syntax**

```
ASR rm
```

**Encoding**

![Encoding of ASR](figures/SOF-B28-1.svg)

The chart is the leaf `SOF-B28-1`, SOF.B28, prefix `11101110111`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `sub` (4 bits) selects the mnemonic: `clr` 0000, `com` 0001, `inc` 0010, `dec` 0011, `neg` 0100, `tst` 0101, `adc` 0110, `sbc` 0111, `asl` 1000, `asr` 1001, `push` 1010, `pop` 1011, `jmp` 1100, `call` 1101, `jmpi` 1110, `calli` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SOF-B28-1`](dictionary/by-encoding.md#SOF-B28-1), [`SOF-X22-1`](dictionary/by-encoding.md#SOF-X22-1), [`SOF-PI12-1`](dictionary/by-encoding.md#SOF-PI12-1), [`SOF-PD12-1`](dictionary/by-encoding.md#SOF-PD12-1), [`SOF-PC32-1`](dictionary/by-encoding.md#SOF-PC32-1), [`SOF-A32-1`](dictionary/by-encoding.md#SOF-A32-1), [`SOPR-2`](dictionary/by-encoding.md#SOPR-2).

**Operation**

```
C ← rm[0] ; rm ← rm >>s 1
```

**Flags** `N` and `Z` from the result, `C` the bit shifted out of bit 0, `V` = 0.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

The by-one form of `SAR`.
<!-- /entries:9.8 -->

## 9.9 Bits, bytes and text

**9.9.1** The bit-and-field escape provides `CLZ`, `CTZ`, `CLO`, `CTO` (count leading and trailing zeros and ones), `POPCNT`, `BSWAP`, `BSWAPW`, `BSWAPL` and `BITREV`.

**9.9.2** `EXTB` and `EXTZB` extract a bitfield at a position and width, sign- or zero-extended, and `INSB` inserts one; the position and the width are 6-bit fields (a width of 64 cannot be written), so these are six bytes. *(D)*

**9.9.3** `XNORPOP` computes the population count of the exclusive-nor of two registers. *(D)*

**9.9.4** `CLMULL` and `CLMULH` are the low and high halves of a carry-less multiply; no polynomial is built into the architecture. *(D)*

**9.9.5** `UTF8LEN`, `UTF8DEC` and `UTF8ENC` find the length of, decode and encode a UTF-8 sequence, and reject overlong forms, surrogates, out-of-range values and bad continuation bytes. *(D)*

**9.9.6** `BSEL` selects bit by bit between two registers under the control of a third: it is `Ch` and `Maj` of SHA-2 in one instruction each, and the constant-time swap of two registers in two. *(D)*

**9.9.7** The secure core has instructions for the AES round (`AESES`, `AESESM`, `AESDS`, `AESDSM`), for its key schedule (`AESKS1`, `AESKS2`, `AESIM`) and for the SHA-256 and SHA-512 functions (`SHA256SIG0` and the others); each takes a time independent of its operands. *(D)* Details pending ([J.9.12](appendix-j-open.md#j912)).

*Commentary.* **Precedent.** The PDP-11 had `SWAB`; the VAX had bit-field instructions and a table-driven `CRC`; x86 added `POPCNT`, `LZCNT` and `PCLMULQDQ` late, and committed `CRC32` to one polynomial. **Trade-offs.** A bit unit is one shared structure: `POPCNT`, `XNORPOP` and a garbage collector's mark-bitmap scan all want the same 64-input adder tree, and `CLZ` and its relatives want a priority encoder over the same operand. **Improvements.** A carry-less multiply stands in for a `CRC` instruction: no polynomial is baked in, and the same instruction serves CRC, the Galois-counter-mode authentication used in TLS, and hashing. Every UTF-8 security hole of the past is three comparators, which an instruction cannot omit and software often does. **Benefits.** The bit unit and the UTF-8 decoder together cost less than 5% of the die. **Modern comparables.** RISC-V's bit-manipulation and carry-less-multiply extensions, AArch64's `CLZ`, `RBIT`, `REV` and `PMULL`, and x86's `PCLMULQDQ`. **Use.** `POPCNT` for bitsets and Hamming distance; `XNORPOP` for binary-weight neural networks and bitset intersection; `CLMUL` for CRC, GCM and fingerprinting; `UTF8*` for text validation in parsers and kernels. **Impact.** *Kernel:* `CTZ` and `CLZ` find the first set bit in a run-queue or free-page bitmap; `POPCNT` counts bits in bitmaps; `BSWAP` converts network byte order. *Compiler:* The compiler maps `__builtin_clz`, `__builtin_popcount` and `__builtin_bswap` directly, and a carry-less multiply is the primitive for CRC and hashing code. *Hardware:* One bit unit holds a shared 64-input adder tree and a priority encoder, and the UTF-8 comparators are about 300 lookup tables.

<!-- entries:9.9 -->
### COUNT: Count leading and trailing zeros and ones

**Mnemonics:** `CLZ`, `CTZ`, `CLO`, `CTO`

**Syntax**

```
CLZ Rs, Rd
CTZ Rs, Rd
CLO Rs, Rd
CTO Rs, Rd
```

**Encoding**

![Encoding of COUNT](figures/R2-1.svg)

The chart is the leaf `R2-1`, R2, prefix `111100000010`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R2-1`](dictionary/by-encoding.md#R2-1).

**Operation**

```
CLZ: Rd ← number of leading zero bits of Rs        (64 if Rs = 0)
CTZ: Rd ← number of trailing zero bits of Rs       (64 if Rs = 0)
CLO: Rd ← number of leading one bits of Rs         (64 if Rs = all ones)
CTO: Rd ← number of trailing one bits of Rs        (64 if Rs = all ones)
```

**Flags** None written.

**Exceptions** None.

`CTZ` is the VAX `FFS`. Bit manipulation is core on a machine that does filesystem and bignum work, not an extension.

**Why it is here.** Bit manipulation is not an extension on a machine that does filesystem work, bignum arithmetic and the like. The counts are the VAX `FFS` and `FFC` idiom (find first set, find first clear), and LoongArch, which has `CLO`, `CLZ`, `CTO` and `CTZ` in its base, is the model for putting them there. The compiler emits none of them, since C has no operator for them; the corpus shows zero uses.

<a id="w-clz"></a>
#### CLZ

![CLZ: R2, prefix 111100000010, sub-opcode 0000000000; operands reg5, reg5; 4 bytes](figures/w/clz/01.svg)

```
CLZ Rs, Rd
```

Operation, flags and exceptions as for the entry COUNT above; 1 layout form, each a chart of its own (above).

<a id="w-ctz"></a>
#### CTZ

![CTZ: R2, prefix 111100000010, sub-opcode 0000000001; operands reg5, reg5; 4 bytes](figures/w/ctz/01.svg)

```
CTZ Rs, Rd
```

Operation, flags and exceptions as for the entry COUNT above; 1 layout form, each a chart of its own (above).

<a id="w-clo"></a>
#### CLO

![CLO: R2, prefix 111100000010, sub-opcode 0000000010; operands reg5, reg5; 4 bytes](figures/w/clo/01.svg)

```
CLO Rs, Rd
```

Operation, flags and exceptions as for the entry COUNT above; 1 layout form, each a chart of its own (above).

<a id="w-cto"></a>
#### CTO

![CTO: R2, prefix 111100000010, sub-opcode 0000000011; operands reg5, reg5; 4 bytes](figures/w/cto/01.svg)

```
CTO Rs, Rd
```

Operation, flags and exceptions as for the entry COUNT above; 1 layout form, each a chart of its own (above).


<a id="w-popcnt"></a>
### POPCNT: Population count

![POPCNT: R2, prefix 111100000010, sub-opcode 0000000100; operands reg5, reg5; 4 bytes](figures/w/popcnt/01.svg)

**Mnemonics:** `POPCNT`

**Syntax**

```
POPCNT Rs, Rd
```

**Encoding**

![Encoding of POPCNT](figures/R2-1.svg)

The chart is the leaf `R2-1`, R2, prefix `111100000010`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R2-1`](dictionary/by-encoding.md#R2-1).

**Operation**

```
Rd ← number of one bits in Rs
```

**Flags** None written.

**Exceptions** None.

**Why it is here.** One of the counts; it is also the building block of `XNORPOP`. A compiler needs `__builtin_popcount` to emit it, so the corpus shows no use (see `COUNT`).


### BSWAP: Byte swap

**Mnemonics:** `BSWAP`, `BSWAPW`, `BSWAPL`

**Syntax**

```
BSWAP Rs, Rd
BSWAPW Rs, Rd
BSWAPL Rs, Rd
```

**Encoding**

![Encoding of BSWAP](figures/R2-1.svg)

The chart is the leaf `R2-1`, R2, prefix `111100000010`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R2-1`](dictionary/by-encoding.md#R2-1).

**Operation**

```
BSWAP : Rd ← Rs with all 8 bytes reversed
BSWAPW: Rd ← Rs with the bytes of each 16-bit word reversed
BSWAPL: Rd ← Rs with the bytes of each 32-bit long reversed
```

**Flags** None written.

**Exceptions** None.

The generalisation of the PDP-11 `SWAB` to 64 bits.

**Why it is here.** The PDP-11 `SWAB` swapped the bytes of a word; `BSWAP` generalises it to 64 bits, with word and long variants. `SWAB` is therefore subsumed, not lost (9.18).

<a id="w-bswap"></a>
#### BSWAP

![BSWAP: R2, prefix 111100000010, sub-opcode 0000000101; operands reg5, reg5; 4 bytes](figures/w/bswap/01.svg)

```
BSWAP Rs, Rd
```

Operation, flags and exceptions as for the entry BSWAP above; 1 layout form, each a chart of its own (above).

<a id="w-bswapw"></a>
#### BSWAPW

![BSWAPW: R2, prefix 111100000010, sub-opcode 0000000110; operands reg5, reg5; 4 bytes](figures/w/bswapw/01.svg)

```
BSWAPW Rs, Rd
```

Operation, flags and exceptions as for the entry BSWAP above; 1 layout form, each a chart of its own (above).

<a id="w-bswapl"></a>
#### BSWAPL

![BSWAPL: R2, prefix 111100000010, sub-opcode 0000000111; operands reg5, reg5; 4 bytes](figures/w/bswapl/01.svg)

```
BSWAPL Rs, Rd
```

Operation, flags and exceptions as for the entry BSWAP above; 1 layout form, each a chart of its own (above).


<a id="w-bitrev"></a>
### BITREV: Reverse the bits

![BITREV: R2, prefix 111100000010, sub-opcode 0000001000; operands reg5, reg5; 4 bytes](figures/w/bitrev/01.svg)

**Mnemonics:** `BITREV`

**Syntax**

```
BITREV Rs, Rd
```

**Encoding**

![Encoding of BITREV](figures/R2-1.svg)

The chart is the leaf `R2-1`, R2, prefix `111100000010`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R2-1`](dictionary/by-encoding.md#R2-1).

**Operation**

```
Rd ← Rs with bit i moved to bit 63-i
```

**Flags** None written.

**Exceptions** None.

**Why it is here.** Borrowed with the other LoongArch bit operations (`REVB`, `REVH`, `BITREV`). No workload from the corpus is recorded.


<a id="w-ror"></a>
### ROR: Rotate right by a register count

![ROR: R3, prefix 1110100001, sub-opcode 0000000; operands reg5, reg5, reg5; 4 bytes](figures/w/ror/01.svg)

**Mnemonics:** `ROR`

**Syntax**

```
ROR Ra, Rb, Rd
```

**Encoding**

![Encoding of ROR](figures/R3-1.svg)

The chart is the leaf `R3-1`, R3, prefix `1110100001`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `op3` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R3-1`](dictionary/by-encoding.md#R3-1).

**Operation**

```
Rd ← Ra rotated right by (Rb mod 64)
```

**Flags** None written (rotates write no flags).

**Exceptions** None.

There is no rotate left instruction: `ROL rs, #n, rd` is an assembler spelling of `RORI rs, #(64-n), rd`. No rotate is through carry; multi-word shifting uses `DSHR`.

**Why it is here.** One rotate direction suffices and `ROR` is the one to keep: `ROL x, #n` is exactly `ROR x, #(64-n)`, and a funnel shifter yields `ROR` directly. No rotate is through carry (see `DSHR`). `ROR` is a bit operation and not an ALU operation: cryptographic code rotates by compile-time constants, so an immediate form is needed either way, and the register-count form has almost no users. Rotates write no flags.


<a id="w-rori"></a>
<a id="w-rol"></a>
### RORI: Rotate right by an immediate

![RORI: RRI, prefix 111100000011, sub-opcode 0000; operands reg5, imm6u, reg5; 4 bytes](figures/w/rori/01.svg)

**Mnemonics:** `RORI`  (aliases: `ROL`)

**Syntax**

```
RORI Rs, #n, Rd
ROL Rs, #n, Rd        ; assembles to RORI Rs, #(64-n), Rd
```

**Encoding**

![Encoding of RORI](figures/RRI-1.svg)

The chart is the leaf `RRI-1`, RRI, prefix `111100000011`. `op1` is `reg5`: register, 5 bits. `op2` is `imm6u`: unsigned 6-bit immediate, 0 to 63. `op3` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`RRI-1`](dictionary/by-encoding.md#RRI-1).

**Operation**

```
Rd ← Rs rotated right by (n mod 64)
```

**Flags** None written.

**Exceptions** None.

**Why it is here.** It has its own mnemonic because an immediate count and a register count are different encodings. `ROL Rs, #n, Rd` is accepted by the assembler as `RORI Rs, #(64-n), Rd`: the complement costs nothing at assembly time, so there is no reason to make programmers do it, and a register-count `ROL` is rejected so that one mnemonic stays one instruction.

<a id="w-rol"></a>
**`ROL`** is an alias of `RORI`: the assembler writes it as that word.


<a id="w-rori32"></a>
### RORI32: Rotate right by an immediate, 32 bits

![RORI32: RRI, prefix 111100000011, sub-opcode 0001; operands reg5, imm6u, reg5; 4 bytes](figures/w/rori32/01.svg)

**Mnemonics:** `RORI32`

**Syntax**

```
RORI32 Rs, #n, Rd
```

**Encoding**

![Encoding of RORI32](figures/RRI-1.svg)

The chart is the leaf `RRI-1`, RRI, prefix `111100000011`. `op1` is `reg5`: register, 5 bits. `op2` is `imm6u`: unsigned 6-bit immediate, 0 to 63. `op3` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`RRI-1`](dictionary/by-encoding.md#RRI-1).

**Operation**

```
Rd ← sext32(ror32(Rs[31:0], n mod 32))
```

**Flags** None written.

**Exceptions** None.

The 32-bit rotate with the result sign-extended like every 32-bit result; the primitive of most hash functions and ciphers.

**Why it is here.** A 32-bit rotate by a constant, the shape of crypto and hash inner loops, estimated together with `CBCC` at 22 KB (1.3%) of the compiled image. The result is sign-extended like the rest of the 32-bit operations, so that no instruction is needed after it. It removes 44 `MOVL` instructions in the corpus (the demand analysis already removes nearly all of them).


<a id="w-dshr"></a>
### DSHR: Double-width funnel shift right

![DSHR: BFx, prefix 1001110, sub-opcode 00000000000000000000; operands reg5, reg5, imm6u, reg5; 6 bytes](figures/w/dshr/01.svg)

**Mnemonics:** `DSHR`

**Syntax**

```
DSHR Ra, Rb, #n, Rd
```

**Encoding**

![Encoding of DSHR](figures/BFx-1.svg)

The chart is the leaf `BFx-1`, BFx, prefix `1001110`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `op3` is `imm6u`: unsigned 6-bit immediate, 0 to 63. `op4` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`BFx-1`](dictionary/by-encoding.md#BFx-1).

**Operation**

```
t ← Ra:Rb                    ; 128 bits, Ra the high half
Rd ← (t >> n)[63:0]          ; n = 0..63
```

**Flags** None written.

**Exceptions** None.

x86 `SHRD`, ARM `EXTR`. A 128-bit left shift by k is `DSHR hi, hi, lo, #(64-k)` then `SHL #k, lo`.

**Why it is here.** A double-width funnel shift (x86 `SHRD`, ARM `EXTR`), the right primitive for multi-word shifting. Two instructions shift a 128-bit value by any distance, where rotate-through-carry takes one bit per instruction, and that is why no rotate is through carry. It also subsumes `ROR` when both sources are the same register. It leaves every flag alone.


### EXTB: Extract a bit field

**Mnemonics:** `EXTB`, `EXTZB`

**Syntax**

```
EXTB Rs, #pos, #width, Rd        ; sign-extended
EXTZB Rs, #pos, #width, Rd       ; zero-extended
```

**Encoding**

![Encoding of EXTB](figures/BFy-1.svg)

The chart is the leaf `BFy-1`, BFy, prefix `11000110`. `op1` is `reg5`: register, 5 bits. `op2` is `imm6u`: unsigned 6-bit immediate, 0 to 63. `op3` is `imm6u`: unsigned 6-bit immediate, 0 to 63. `op4` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`BFy-1`](dictionary/by-encoding.md#BFy-1).

**Operation**

```
Rd ← ext((Rs >> pos)[width-1:0])          ; sext for EXTB, zext for EXTZB; width 0 or > 64 means 64
```

**Flags** None written.

**Exceptions** None.

Position and width are immediate operands; a width of 64 cannot be encoded (errata 87, assumption 8).

**Why it is here.** Bit-field extract and insert are the VAX `EXTV`, `EXTZV` and `INSV` idiom. The compiler does not use them: the shift-pair extraction pattern occurs 151 times in 26 files of the corpus, about 600 bytes at best (0.03%), and there are four true bit-field extracts in all. They are for hand-written protocol and bit-stream code.

<a id="w-extb"></a>
#### EXTB

![EXTB: BFy, prefix 11000110, sub-opcode 000000000000000000; operands reg5, imm6u, imm6u, reg5; 6 bytes](figures/w/extb/01.svg)

```
EXTB Rs, #pos, #width, Rd
```

Operation, flags and exceptions as for the entry EXTB above; 1 layout form, each a chart of its own (above).

<a id="w-extzb"></a>
#### EXTZB

![EXTZB: BFy, prefix 11000110, sub-opcode 000000000000000001; operands reg5, imm6u, imm6u, reg5; 6 bytes](figures/w/extzb/01.svg)

```
EXTZB Rs, #pos, #width, Rd
```

Operation, flags and exceptions as for the entry EXTB above; 1 layout form, each a chart of its own (above).


<a id="w-insb"></a>
### INSB: Insert a bit field

![INSB: BFy, prefix 11000110, sub-opcode 000000000000000010; operands reg5, imm6u, imm6u, reg5; 6 bytes](figures/w/insb/01.svg)

**Mnemonics:** `INSB`

**Syntax**

```
INSB Rs, #pos, #width, Rd
```

**Encoding**

![Encoding of INSB](figures/BFy-1.svg)

The chart is the leaf `BFy-1`, BFy, prefix `11000110`. `op1` is `reg5`: register, 5 bits. `op2` is `imm6u`: unsigned 6-bit immediate, 0 to 63. `op3` is `imm6u`: unsigned 6-bit immediate, 0 to 63. `op4` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`BFy-1`](dictionary/by-encoding.md#BFy-1).

**Operation**

```
mask ← ((1 << width) - 1) << pos
Rd ← (Rd AND NOT mask) OR ((Rs << pos) AND mask)
```

**Flags** None written.

**Exceptions** None.

Six bytes. `Rd` is both source and destination.

**Why it is here.** The VAX `INSV` idiom, with `EXTB`. No use in the compiled corpus is recorded.


<a id="w-xnorpop"></a>
### XNORPOP: Population count of the equality of two words

![XNORPOP: R3, prefix 1110100001, sub-opcode 0000001; operands reg5, reg5, reg5; 4 bytes](figures/w/xnorpop/01.svg)

**Mnemonics:** `XNORPOP`

**Syntax**

```
XNORPOP Ra, Rb, Rd
```

**Encoding**

![Encoding of XNORPOP](figures/R3-1.svg)

The chart is the leaf `R3-1`, R3, prefix `1110100001`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `op3` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R3-1`](dictionary/by-encoding.md#R3-1).

**Operation**

```
Rd ← popcount(NOT (Ra XOR Rb))
```

**Flags** None written.

**Exceptions** None.

For binary-activation networks, Hamming distance and bitset intersection cardinality. It does **not** serve sub-1-bit language models (section 8.3).

**Why it is here.** It serves binary-activation networks, Hamming distance, bitset intersection counts and counting a collector's mark bitmap. It does not serve sub-1-bit language models: their activations (in the LittleBit work) are FP16 and the inner loop is a conditional add, not a popcount. The sub-1-bit kernel is bandwidth-bound and belongs to a bus-mastering accelerator, not an opcode (chapter 8).


### CLMUL: Carry-less multiply

**Mnemonics:** `CLMULL`, `CLMULH`

**Syntax**

```
CLMULL Ra, Rb, Rd
CLMULH Ra, Rb, Rd
```

**Encoding**

![Encoding of CLMUL](figures/R3-1.svg)

The chart is the leaf `R3-1`, R3, prefix `1110100001`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `op3` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R3-1`](dictionary/by-encoding.md#R3-1).

**Operation**

```
p ← carry-less (polynomial over GF(2)) product of Ra and Rb      ; 128 bits
CLMULL: Rd ← p[63:0]
CLMULH: Rd ← p[127:64]
```

**Flags** None written.

**Exceptions** None.

The primitive under every CRC (with a Barrett reduction), GF(2^k) arithmetic and GCM; no polynomial is committed to the architecture.

**Why it is here.** Carry-less multiply is the primitive beneath every CRC polynomial (a CRC is a carry-less multiply plus a Barrett reduction), GF(2^k) erasure codes and AES-GCM. It is chosen over a `CRC` instruction because x86 and ARM each committed a polynomial to the architecture; there are no `CRC32` or `CRC32C` words.

<a id="w-clmull"></a>
#### CLMULL

![CLMULL: R3, prefix 1110100001, sub-opcode 0000010; operands reg5, reg5, reg5; 4 bytes](figures/w/clmull/01.svg)

```
CLMULL Ra, Rb, Rd
```

Operation, flags and exceptions as for the entry CLMUL above; 1 layout form, each a chart of its own (above).

<a id="w-clmulh"></a>
#### CLMULH

![CLMULH: R3, prefix 1110100001, sub-opcode 0000011; operands reg5, reg5, reg5; 4 bytes](figures/w/clmulh/01.svg)

```
CLMULH Ra, Rb, Rd
```

Operation, flags and exceptions as for the entry CLMUL above; 1 layout form, each a chart of its own (above).


<a id="w-utf8len"></a>
### UTF8LEN: Length of a UTF-8 sequence from its leading byte

![UTF8LEN: R2, prefix 111100000010, sub-opcode 0000001001; operands reg5, reg5; 4 bytes](figures/w/utf8len/01.svg)

**Mnemonics:** `UTF8LEN`

**Syntax**

```
UTF8LEN Rs, Rd
```

**Encoding**

![Encoding of UTF8LEN](figures/R2-1.svg)

The chart is the leaf `R2-1`, R2, prefix `111100000010`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R2-1`](dictionary/by-encoding.md#R2-1).

**Operation**

```
Rd ← length (1 to 4) implied by the leading byte Rs[7:0]; 0 if it cannot begin a valid sequence
```

**Flags** None written.

**Exceptions** None.

**Why it is here.** Most of what UTF-8 needs is general bit manipulation, but the validity rules are where the bugs are, so the group has three instructions. `UTF8LEN` is the one that is nearly free: `CLO` on the leading byte, mapped to 1, 2, 3 or 4.


<a id="w-utf8dec"></a>
### UTF8DEC: Decode a UTF-8 sequence

![UTF8DEC: R2, prefix 111100000010, sub-opcode 0000001010; operands reg5, reg5; 4 bytes](figures/w/utf8dec/01.svg)

**Mnemonics:** `UTF8DEC`

**Syntax**

```
UTF8DEC Rs, Rd
```

**Encoding**

![Encoding of UTF8DEC](figures/R2-1.svg)

The chart is the leaf `R2-1`, R2, prefix `111100000010`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R2-1`](dictionary/by-encoding.md#R2-1).

**Operation**

```
Rs holds up to 4 bytes, leading byte in bits 7..0
Rd ← the scalar value
V  ← 1 if the sequence is not a valid encoding
```

**Flags** `V` set for a bad continuation byte, an overlong form, a surrogate (U+D800 to U+DFFF), a value above U+10FFFF, or a leading byte of `11000000 (0xC0)`, `11000001 (0xC1)` or `11110101 (0xF5)` to `11111111 (0xFF)`; the length consumed is reported in a scratch field of the status word (details in the instruction-set text, section 4.6.1).

**Exceptions** None.

**Why it is here.** Not for speed but for correctness: overlong forms, surrogates, values above U+10FFFF and the bytes that can never begin a sequence are each a historical security hole, each is three comparators in hardware, and software implementations get them wrong or omit them for speed (about 300 lookup tables).


<a id="w-utf8enc"></a>
### UTF8ENC: Encode a Unicode scalar value

![UTF8ENC: R2, prefix 111100000010, sub-opcode 0000001011; operands reg5, reg5; 4 bytes](figures/w/utf8enc/01.svg)

**Mnemonics:** `UTF8ENC`

**Syntax**

```
UTF8ENC Rs, Rd
```

**Encoding**

![Encoding of UTF8ENC](figures/R2-1.svg)

The chart is the leaf `R2-1`, R2, prefix `111100000010`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R2-1`](dictionary/by-encoding.md#R2-1).

**Operation**

```
Rd ← the UTF-8 bytes of the scalar value Rs, leading byte in bits 7..0
V  ← 1 if Rs is not a Unicode scalar value
```

**Flags** `V` set if `Rs` is not a Unicode scalar value (a surrogate or above U+10FFFF).

**Exceptions** None.

**Why it is here.** The encoding half of the UTF-8 pair; it refuses surrogates and values above U+10FFFF so that an encoder cannot produce what a decoder must reject.


<a id="w-bsel"></a>
### BSEL: Bitwise select

![BSEL: R4, prefix 11000101, sub-opcode 1100; operands reg5, reg5, reg5, reg5; 4 bytes](figures/w/bsel/01.svg)

**Mnemonics:** `BSEL`

**Syntax**

```
BSEL Rm, Ra, Rb, Rd
```

**Encoding**

![Encoding of BSEL](figures/R4-1.svg)

The chart is the leaf `R4-1`, R4, prefix `11000101`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `op3` is `reg5`: register, 5 bits. `op4` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R4-1`](dictionary/by-encoding.md#R4-1).

**Operation**

```
Rd ← (Rm AND Ra) OR (NOT Rm AND Rb)       ; bit by bit
```

**Flags** None written.

**Exceptions** None.

*(D)* One of the select instructions of the secure-core design, which the author approved (errata 85 and 86: the select instructions "looks good"); it is one of the stage 1 words of `docs/crypto-secure-core.md` section 3. `Ch(e, f, g)` of SHA-2 is `BSEL e, f, g`; `Maj(a, b, c)` is `BSEL (a XOR b), c, b`; a mask-controlled swap of two registers is two `BSEL`. Three sources and a destination: the four register fields of the three-operand group.

**Why it is here.** A bit select takes three sources and a destination, the four register fields of the three-operand group. Its case in the crypto proposal is SHA-2 (`Ch` and `Maj` are one `BSEL` each) and the constant-time swap: the X25519 ladder swaps ten limbs per step, 50 instructions with the mask pair against about 25 with `BSEL`. It is the select of ARM (`BSL`) and of x86 ternary logic, and it serves MD5 and SHA-1 round functions, blends and bit insertion. It is one of the select instructions of the secure core.


### AESR: AES round on a 128-bit block in two registers

**Mnemonics:** `AESES`, `AESESM`, `AESDS`, `AESDSM`

**Syntax**

```
AESES Ra, Rb, Rd
AESESM Ra, Rb, Rd
AESDS Ra, Rb, Rd
AESDSM Ra, Rb, Rd
```

**Encoding**

![Encoding of AESR](figures/R3-1.svg)

The chart is the leaf `R3-1`, R3, prefix `1110100001`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `op3` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R3-1`](dictionary/by-encoding.md#R3-1).

**Operation**

```
the 16 bytes of the block are Rb:Ra (Ra holds bytes 0 to 7, columns 0 and 1; Rb bytes 8 to 15)
AESES  : ShiftRows, then SubBytes
AESESM : ShiftRows, SubBytes, then MixColumns
AESDS  : inverse ShiftRows, then inverse SubBytes
AESDSM : inverse ShiftRows, inverse SubBytes, then inverse MixColumns
Rd ← the 8 bytes of the new state that belong to columns 0 and 1; with Ra and Rb exchanged, columns 2 and 3
```

**Flags** None written.

**Exceptions** None.

*(D)* The author asked for constant-time AES and SHA instructions "or whichever opcodes would speed up and enable aes and sha" for the secure core (errata 85) and approved its design (errata 86); the words are those of `docs/crypto-secure-core.md` section 3.2. Any two registers hold a block (no even-odd pairing): a round on one block is `AESESM Ra, Rb, T` and `AESESM Rb, Ra, Rb`, with the round key XORed by `XOR` with a memory operand. The latency is fixed and the instruction reads and writes no memory, so it has no cache-timing channel. The definitions are those of FIPS 197. Details pending ([J.9.12](appendix-j-open.md#j912)).

**Why it is here.** Constant-time software AES takes about 1,000 instructions a block (BearSSL's bitsliced code, scaled; the proposal's estimate), and table AES leaks through the cache. The author asked for constant-time AES and SHA instructions "or whichever opcodes would speed up and enable aes and sha" for the secure core (errata 85). The design is RISC-V's scalar cryptography (`aes64es` and its kin): the state is in the general registers, so no vector register file is needed and, unlike the AES drivers of OpenBSD for x86 and ARM, no `fpu_kernel_enter()` bracket either: a kernel AES loop saves nothing and is preemptible with the ordinary register save. A block costs 42 instructions for AES-128, 20 to 25 times fewer than the software sequence (estimates). Precedent for the pair-in-registers shape: RISC-V; the other machines (x86 AES-NI, ARM `AESE`) use vector registers.

**Cf.** docs/crypto-secure-core.md section 3.

<a id="w-aeses"></a>
#### AESES

![AESES: R3, prefix 1110100001, sub-opcode 0011000; operands reg5, reg5, reg5; 4 bytes](figures/w/aeses/01.svg)

```
AESES Ra, Rb, Rd
```

Operation, flags and exceptions as for the entry AESR above; 1 layout form, each a chart of its own (above).

<a id="w-aesesm"></a>
#### AESESM

![AESESM: R3, prefix 1110100001, sub-opcode 0011001; operands reg5, reg5, reg5; 4 bytes](figures/w/aesesm/01.svg)

```
AESESM Ra, Rb, Rd
```

Operation, flags and exceptions as for the entry AESR above; 1 layout form, each a chart of its own (above).

<a id="w-aesds"></a>
#### AESDS

![AESDS: R3, prefix 1110100001, sub-opcode 0011010; operands reg5, reg5, reg5; 4 bytes](figures/w/aesds/01.svg)

```
AESDS Ra, Rb, Rd
```

Operation, flags and exceptions as for the entry AESR above; 1 layout form, each a chart of its own (above).

<a id="w-aesdsm"></a>
#### AESDSM

![AESDSM: R3, prefix 1110100001, sub-opcode 0011011; operands reg5, reg5, reg5; 4 bytes](figures/w/aesdsm/01.svg)

```
AESDSM Ra, Rb, Rd
```

Operation, flags and exceptions as for the entry AESR above; 1 layout form, each a chart of its own (above).


### AESK: AES key schedule steps

**Mnemonics:** `AESKS1`, `AESKS2`, `AESIM`

**Syntax**

```
AESKS1 Rs, #n, Rd
AESKS2 Ra, Rb, Rd
AESIM Rs, Rd
```

**Encoding**

![Encoding of AESK](figures/RRI-1.svg)

The chart is the leaf `RRI-1`, RRI, prefix `111100000011`. `op1` is `reg5`: register, 5 bits. `op2` is `imm6u`: unsigned 6-bit immediate, 0 to 63. `op3` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`RRI-1`](dictionary/by-encoding.md#RRI-1), [`R3-1`](dictionary/by-encoding.md#R3-1), [`R2-1`](dictionary/by-encoding.md#R2-1).

**Operation**

```
AESKS1: Rd ← (SubWord(RotWord(Rs[63:32])) XOR rcon(n)), replicated in both halves   ; n = 10: no round constant (AES-256)
AESKS2: Rd[31:0] ← Ra[31:0] XOR Rb[63:32] ; Rd[63:32] ← Ra[63:32] XOR Rd[31:0]
AESIM : Rd ← InvMixColumns of the two columns in Rs         ; for the decryption key schedule
```

**Flags** None written.

**Exceptions** None.

*(D)* As `AESR`. The key schedule of AES-128 takes three instructions per round. Details pending ([J.9.12](appendix-j-open.md#j912)).

**Why it is here.** The key schedule and the inverse mix of the round key complete the round instructions: three instructions per round of the AES-128 schedule, about 30 for the whole schedule instead of about 150, once per key; `AESIM` adds 18 for the decryption schedule. The same precedent as `AESR`.

<a id="w-aesks1"></a>
#### AESKS1

![AESKS1: RRI, prefix 111100000011, sub-opcode 0011; operands reg5, imm6u, reg5; 4 bytes](figures/w/aesks1/01.svg)

```
AESKS1 Rs, #n, Rd
```

Operation, flags and exceptions as for the entry AESK above; 1 layout form, each a chart of its own (above).

<a id="w-aesks2"></a>
#### AESKS2

![AESKS2: R3, prefix 1110100001, sub-opcode 0011100; operands reg5, reg5, reg5; 4 bytes](figures/w/aesks2/01.svg)

```
AESKS2 Ra, Rb, Rd
```

Operation, flags and exceptions as for the entry AESK above; 1 layout form, each a chart of its own (above).

<a id="w-aesim"></a>
#### AESIM

![AESIM: R2, prefix 111100000010, sub-opcode 0000110111; operands reg5, reg5; 4 bytes](figures/w/aesim/01.svg)

```
AESIM Rs, Rd
```

Operation, flags and exceptions as for the entry AESK above; 1 layout form, each a chart of its own (above).


### SHA256: The SHA-256 functions

**Mnemonics:** `SHA256SIG0`, `SHA256SIG1`, `SHA256SUM0`, `SHA256SUM1`

**Syntax**

```
SHA256SIG0 Rs, Rd
SHA256SIG1 Rs, Rd
SHA256SUM0 Rs, Rd
SHA256SUM1 Rs, Rd
```

**Encoding**

![Encoding of SHA256](figures/R2-1.svg)

The chart is the leaf `R2-1`, R2, prefix `111100000010`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R2-1`](dictionary/by-encoding.md#R2-1).

**Operation**

```
on the low 32 bits x of Rs; the result is in the low 32 bits of Rd, the upper bits zero
SIG0: ror(x,7)  XOR ror(x,18) XOR shr(x,3)
SIG1: ror(x,17) XOR ror(x,19) XOR shr(x,10)
SUM0: ror(x,2)  XOR ror(x,13) XOR ror(x,22)
SUM1: ror(x,6)  XOR ror(x,11) XOR ror(x,25)
```

**Flags** None written.

**Exceptions** None.

*(D)* As `AESR`. Rotations and three-input exclusive ors, one cycle in hardware, no data-dependent timing. Details pending: whether the 32-bit result is zero-extended, as the study has it, or sign-extended, as every other 32-bit result of the machine is (`RORI32`) ([J.9.12](appendix-j-open.md#j912)).

**Why it is here.** The SHA-2 rounds are rotations and three-input exclusive ors, which the integer instructions do in several steps; the RISC-V scalar cryptography extension has the eight functions as instructions. The crypto proposal counts the gain honestly: the primitives remove half the work, not nineteen twentieths, because a round still needs the adds and the register traffic (about 1,200 against 2,500 instructions for a 64-byte block with `BSEL`, estimates).

<a id="w-sha256sig0"></a>
#### SHA256SIG0

![SHA256SIG0: R2, prefix 111100000010, sub-opcode 0000111000; operands reg5, reg5; 4 bytes](figures/w/sha256sig0/01.svg)

```
SHA256SIG0 Rs, Rd
```

Operation, flags and exceptions as for the entry SHA256 above; 1 layout form, each a chart of its own (above).

<a id="w-sha256sig1"></a>
#### SHA256SIG1

![SHA256SIG1: R2, prefix 111100000010, sub-opcode 0000111001; operands reg5, reg5; 4 bytes](figures/w/sha256sig1/01.svg)

```
SHA256SIG1 Rs, Rd
```

Operation, flags and exceptions as for the entry SHA256 above; 1 layout form, each a chart of its own (above).

<a id="w-sha256sum0"></a>
#### SHA256SUM0

![SHA256SUM0: R2, prefix 111100000010, sub-opcode 0000111010; operands reg5, reg5; 4 bytes](figures/w/sha256sum0/01.svg)

```
SHA256SUM0 Rs, Rd
```

Operation, flags and exceptions as for the entry SHA256 above; 1 layout form, each a chart of its own (above).

<a id="w-sha256sum1"></a>
#### SHA256SUM1

![SHA256SUM1: R2, prefix 111100000010, sub-opcode 0000111011; operands reg5, reg5; 4 bytes](figures/w/sha256sum1/01.svg)

```
SHA256SUM1 Rs, Rd
```

Operation, flags and exceptions as for the entry SHA256 above; 1 layout form, each a chart of its own (above).


### SHA512: The SHA-512 functions

**Mnemonics:** `SHA512SIG0`, `SHA512SIG1`, `SHA512SUM0`, `SHA512SUM1`

**Syntax**

```
SHA512SIG0 Rs, Rd
SHA512SIG1 Rs, Rd
SHA512SUM0 Rs, Rd
SHA512SUM1 Rs, Rd
```

**Encoding**

![Encoding of SHA512](figures/R2-1.svg)

The chart is the leaf `R2-1`, R2, prefix `111100000010`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R2-1`](dictionary/by-encoding.md#R2-1).

**Operation**

```
on the 64 bits x of Rs
SIG0: ror(x,1)  XOR ror(x,8)  XOR shr(x,7)
SIG1: ror(x,19) XOR ror(x,61) XOR shr(x,6)
SUM0: ror(x,28) XOR ror(x,34) XOR ror(x,39)
SUM1: ror(x,14) XOR ror(x,18) XOR ror(x,41)
```

**Flags** None written.

**Exceptions** None.

*(D)* As `SHA256`. The definitions are those of FIPS 180-4.

**Why it is here.** See `SHA256`: the four 64-bit functions of SHA-512, with the same gain of about two (about 1,500 against 3,100 instructions for a 128-byte block, estimates).

<a id="w-sha512sig0"></a>
#### SHA512SIG0

![SHA512SIG0: R2, prefix 111100000010, sub-opcode 0000111100; operands reg5, reg5; 4 bytes](figures/w/sha512sig0/01.svg)

```
SHA512SIG0 Rs, Rd
```

Operation, flags and exceptions as for the entry SHA512 above; 1 layout form, each a chart of its own (above).

<a id="w-sha512sig1"></a>
#### SHA512SIG1

![SHA512SIG1: R2, prefix 111100000010, sub-opcode 0000111101; operands reg5, reg5; 4 bytes](figures/w/sha512sig1/01.svg)

```
SHA512SIG1 Rs, Rd
```

Operation, flags and exceptions as for the entry SHA512 above; 1 layout form, each a chart of its own (above).

<a id="w-sha512sum0"></a>
#### SHA512SUM0

![SHA512SUM0: R2, prefix 111100000010, sub-opcode 0000111110; operands reg5, reg5; 4 bytes](figures/w/sha512sum0/01.svg)

```
SHA512SUM0 Rs, Rd
```

Operation, flags and exceptions as for the entry SHA512 above; 1 layout form, each a chart of its own (above).

<a id="w-sha512sum1"></a>
#### SHA512SUM1

![SHA512SUM1: R2, prefix 111100000010, sub-opcode 0000111111; operands reg5, reg5; 4 bytes](figures/w/sha512sum1/01.svg)

```
SHA512SUM1 Rs, Rd
```

Operation, flags and exceptions as for the entry SHA512 above; 1 layout form, each a chart of its own (above).
<!-- /entries:9.9 -->

## 9.10 Branches and control flow

*Cf. section 6.13 for `TRAP`, `RTI` and `RTT`, and section 6.3 for how a trap enters the kernel; section 9.16 for `CALLI` and `JMPI` in position-independent code.*

**9.10.1** There is an unconditional branch `BR` and fourteen conditional branches, two bytes with a field of 6 to 9 bits, four with 16 bits, six with 32 bits, counting two-byte parcels from the first parcel of the branch: ±64 to ±512 bytes, ±64 KiB, ±4 GiB.

**9.10.2** The conditions are `ne`, `eq`, `pl`, `mi`, `vc`, `vs`, `cc`/`hs`, `cs`/`lo`, `ge`, `lt`, `gt`, `le`, `hi` and `los`.

**9.10.3** `SOB Rn, dst` subtracts one from `Rn` and branches if the result is nonzero, forward or backward. It is four bytes, with a 16-bit field of parcels (±64 KiB).

**9.10.4** `CBCC` compares a register with zero, with an immediate or with a second register and branches on the condition, and writes no flags. It is one parcel for `CBEQ` and `CBNE` against zero (a field of 4 to 7 bits: ±16 to ±128 bytes); two parcels for an immediate of 3 to 10 bits or a second register, with a field of 8 to 14 bits (±256 bytes to ±16 KiB); three parcels for a 16-bit immediate with a 12-bit field (±4 KiB), an 8-bit immediate with a 20-bit field (±1 MiB) or two registers with a 24-bit field (±16 MiB). *(D)*

**9.10.5** `JMP` and `CALL` take any address mode; `RET` returns; `JMPI` and `CALLI` jump and call through a pointer in memory; `JTAG` dispatches on the tag in the low three bits of a register; `BTAG` and `BNTAG` branch on a tag. *(D)*

**9.10.6** A call pushes the return address on the stack; there is no link register. *(D)*

**9.10.7** Four pairs of instructions are fused into one. `MOVCALL Rs, Rd, label` is `MOVQ Rs, Rd` followed by `CALL label`, in four bytes (a 16-bit field of parcels, ±64 KiB) or six (32 bits); `POPRET Rd` is `POP Rd` followed by `RET`, and `POPMRET #mask` is `POPM #mask` followed by `RET` (the 8-bit mask field, scaled by 256, names `R8` to `R15`), each in two bytes; `MOV2 Ra, Rb, Rc, Rd` is `MOVQ Ra, Rb` followed by `MOVQ Rc, Rd`, in two bytes, with all four registers in the 3-bit hot table. The assembler never fuses: choosing a fused instruction is the compiler's job. A fused instruction is restarted whole after a fault. *(D)*

**9.10.8** A `CBCC` for which no form reaches (a label in another object, an operand pair that no form holds) is assembled as `CMP` followed by `BCC`. This writes the flags, which `CBCC` does not, and executes two instructions for one; the compiler forms a `CBCC` only where the flags are dead after the branch, so the program is unchanged. On the 841-file corpus 13 sites need the pair; in the six large programs 12 sites need it and 79,894 pairs are executed, 0.014% of the instructions.

*Commentary.* **Precedent.** The complete PDP-11 branch set, which the long-branch problem of the PDP-11 (±256 bytes) made awkward, here reaches ±4 GB with no long-branch opcode and no trampoline, because the displacement widens with the length. `SOB` was the PDP-11's, which could only branch backward. **Trade-offs.** A compare-and-branch that writes no flags cannot feed a second branch that reads them, so a three-way compare is compare-then-branch; the compiler fuses only where the flags are dead afterwards, which costs about 0.4% in code size. **Improvements.** The tag branches serve a Lisp or other tagged runtime in one instruction. **Benefits.** Branch relaxation in the assembler is choosing a length. **Modern comparables.** RISC-V and MIPS are compare-and-branch machines with no flags; AArch64 has `CBZ` and `TBZ`; x86 uses flags like the pdp64's branches. **Use.** `JMPI` and `CALLI` are the shared-library call and the virtual call; `JTAG` is the dispatch of a dynamic-language interpreter. **Impact.** *Kernel:* `JMPI`, `CALLI` and `JTAG` are the shared-library call, the virtual call and the dispatch of an interpreter; `SOB` and `CBCC` are the loops of the kernel's inner routines. *Compiler:* Branch relaxation is choosing a length; fusing a compare and a branch is legal only where the flags are dead afterwards, so the compiler needs a flag-liveness analysis. *Hardware:* The next-PC mux takes the load-return path for the indirect forms; the compare-and-branch compare runs in the branch unit beside the ALU; displacements count parcels, so no shifter is needed.

*Commentary on 9.10.4, 9.10.7 and 9.10.8.* **Precedent.** The PDP-11 branched on the flags of the previous instruction only; compare-and-branch machines (MIPS, RISC-V) branch on two registers in one instruction, and the long-branch problem of both was solved by a longer encoding, here by the three lengths of `CBCC`. Macro-op fusion in current x86 and ARM cores joins a compare and a branch in the decoder; here the compiler does the joining and the instruction set names the result. **Trade-offs.** The reach of the shortest `CBCC` forms was set from the corpus: the optimiser trained on the compiler's own output, priced a `CBCC` that no form reaches as the `CMP` and `BCC` that the assembler substitutes, and offered the three-parcel forms; the cost is that one-parcel `CBCC` reaches less than in the earlier prefix-coded iteration (1.8), and lz4 fetches 1.2% more bytes for it (appendix F). The four fused pairs save two bytes a pair: 39,674 bytes (4.16%) in the corpus when the compiler was first given them. **Improvements.** The fused call has a three-parcel form, so a call beyond ±64 KiB is still one instruction; and the assembler's `CMP` plus `BCC` makes every program assemble, so a form that does not reach is a slower program and never an error. **Benefits.** Fusion is a decision of the compiler, so the instruction set stays free of microarchitectural pairing rules, and a core that does not fuse in hardware loses nothing. **Modern comparables.** The fused pairs are the ones the compiled corpus shows most often adjacent: a move before a call, a pop before a return. **Impact.** *Kernel:* `POPRET` and `POPMRET` are the epilogue of every function and `MOVCALL` the call of every wrapper; they are smaller kernel text with no source change. *Compiler:* it must know the flags are dead before forming `CBCC`, fuse after register allocation, and keep a mask of `R24` to `R31` out of `POPMRET` (the field names `R8` to `R15` only). *Hardware:* a fused instruction is decoded as two operations that retire together; a hardware implementation may execute them as one or two.

<!-- entries:9.10 -->
### BCC: Branch on condition

**Mnemonics:** `BR`, `BNE`, `BEQ`, `BPL`, `BMI`, `BVC`, `BVS`, `BCC`, `BCS`, `BGE`, `BLT`, `BGT`, `BLE`, `BHI`, `BLOS`  (aliases: `BHIS`, `BLO`)

**Syntax**

```
BR target
BNE target
BEQ target ... and the rest
```

**Encoding**

![Encoding of BCC](figures/BRF-1.svg)

The chart is the leaf `BRF-1`, BRF, prefix `1111000101100`. `op1` is `pc32-u2`: pc-relative, 32 bits counted in 2-byte units (-4294967296 to 4294967294 bytes). `sub` (3 bits) selects the mnemonic: `br` 000, `bne` 001, `beq` 010, `bpl` 011, `bmi` 100, `bvc` 101, `bvs` 110, `bcc` 111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`BRF-1`](dictionary/by-encoding.md#BRF-1), [`BR2-16-a-1`](dictionary/by-encoding.md#BR2-16-a-1), [`BR1-6-a-1`](dictionary/by-encoding.md#BR1-6-a-1), [`BR1-7-a-1`](dictionary/by-encoding.md#BR1-7-a-1), [`BR1-8-a-1`](dictionary/by-encoding.md#BR1-8-a-1), [`BR1-9-a-1`](dictionary/by-encoding.md#BR1-9-a-1), [`BR2-16-b-1`](dictionary/by-encoding.md#BR2-16-b-1), [`BR1-6-b-1`](dictionary/by-encoding.md#BR1-6-b-1), [`BR2-16-c-1`](dictionary/by-encoding.md#BR2-16-c-1), [`BRF-2`](dictionary/by-encoding.md#BRF-2), [`BR2-16-c-2`](dictionary/by-encoding.md#BR2-16-c-2), [`BRF-3`](dictionary/by-encoding.md#BRF-3), [`BRF-4`](dictionary/by-encoding.md#BRF-4).

**Operation**

```
if cond(c) then PC ← address of this instruction + 2 × disp
```

**Flags** None written.

**Exceptions** None; a branch to an unmapped or non-executable address faults on the fetch of the target.

Condition numbers: `al` 0 (`BR`), `ne` 1, `eq` 2, `pl` 3, `mi` 4, `vc` 5, `vs` 6, `cc`/`hs` 7, `cs`/`lo` 8, `ge` 9, `lt` 10, `gt` 11, `le` 12, `hi` 13, `los` 14. Conditions on the flags: `ne` `!Z`; `eq` `Z`; `pl` `!N`; `mi` `N`; `vc` `!V`; `vs` `V`; `cc` `!C`; `cs` `C`; `ge` `N == V`; `lt` `N != V`; `gt` `!Z and N == V`; `le` `Z or N != V`; `hi` `!C and !Z`; `los` `C or Z`. The displacement counts 2-byte parcels; the reach of each form is in its chart.

**Cf.** 6.13 for `TRAP`, `RTI` and `RTT`.

<a id="w-br"></a>
#### BR

![BR: BRF, prefix 1111000101100, sub-opcode 000; operands pc32-u2; 6 bytes](figures/w/br/01.svg)

![BR: BR2_16/a, prefix 1111001100100110; operands pc16-u2; 4 bytes](figures/w/br/02.svg)

![BR: BR1_6/a, prefix 1110110000; operands pc6-u2; 2 bytes](figures/w/br/03.svg)

![BR: BR1_7/a, prefix 111001000; operands pc7-u2; 2 bytes](figures/w/br/04.svg)

![BR: BR1_8/a, prefix 11011001; operands pc8-u2; 2 bytes](figures/w/br/05.svg)

![BR: BR1_9/a, prefix 1100001; operands pc9-u2; 2 bytes](figures/w/br/06.svg)

```
BR target
```

Operation, flags and exceptions as for the entry BCC above; 6 layout forms, each a chart of its own (above).

<a id="w-bne"></a>
#### BNE

![BNE: BRF, prefix 1111000101100, sub-opcode 001; operands pc32-u2; 6 bytes](figures/w/bne/01.svg)

![BNE: BR2_16/b, prefix 111100101111101, sub-opcode 1; operands pc16-u2; 4 bytes](figures/w/bne/02.svg)

![BNE: BR1_6/b, prefix 111001001, sub-opcode 1; operands pc6-u2; 2 bytes](figures/w/bne/03.svg)

```
BNE target
```

Operation, flags and exceptions as for the entry BCC above; 3 layout forms, each a chart of its own (above).

<a id="w-beq"></a>
#### BEQ

![BEQ: BRF, prefix 1111000101100, sub-opcode 010; operands pc32-u2; 6 bytes](figures/w/beq/01.svg)

![BEQ: BR2_16/b, prefix 111100101111101, sub-opcode 0; operands pc16-u2; 4 bytes](figures/w/beq/02.svg)

![BEQ: BR1_6/b, prefix 111001001, sub-opcode 0; operands pc6-u2; 2 bytes](figures/w/beq/03.svg)

```
BEQ target ... and the rest
```

Operation, flags and exceptions as for the entry BCC above; 3 layout forms, each a chart of its own (above).

<a id="w-bpl"></a>
#### BPL

![BPL: BRF, prefix 1111000101100, sub-opcode 011; operands pc32-u2; 6 bytes](figures/w/bpl/01.svg)

![BPL: BR2_16/c, prefix 1111000110000, sub-opcode 000; operands pc16-u2; 4 bytes](figures/w/bpl/02.svg)

Operation, flags and exceptions as for the entry BCC above; 2 layout forms, each a chart of its own (above).

<a id="w-bmi"></a>
#### BMI

![BMI: BRF, prefix 1111000101100, sub-opcode 100; operands pc32-u2; 6 bytes](figures/w/bmi/01.svg)

![BMI: BR2_16/c, prefix 1111000110000, sub-opcode 001; operands pc16-u2; 4 bytes](figures/w/bmi/02.svg)

Operation, flags and exceptions as for the entry BCC above; 2 layout forms, each a chart of its own (above).

<a id="w-bvc"></a>
#### BVC

![BVC: BRF, prefix 1111000101100, sub-opcode 101; operands pc32-u2; 6 bytes](figures/w/bvc/01.svg)

![BVC: BR2_16/c, prefix 1111000110000, sub-opcode 010; operands pc16-u2; 4 bytes](figures/w/bvc/02.svg)

Operation, flags and exceptions as for the entry BCC above; 2 layout forms, each a chart of its own (above).

<a id="w-bvs"></a>
#### BVS

![BVS: BRF, prefix 1111000101100, sub-opcode 110; operands pc32-u2; 6 bytes](figures/w/bvs/01.svg)

![BVS: BR2_16/c, prefix 1111000110000, sub-opcode 011; operands pc16-u2; 4 bytes](figures/w/bvs/02.svg)

Operation, flags and exceptions as for the entry BCC above; 2 layout forms, each a chart of its own (above).

<a id="w-bcc"></a>
#### BCC

![BCC: BRF, prefix 1111000101100, sub-opcode 111; operands pc32-u2; 6 bytes](figures/w/bcc/01.svg)

![BCC: BR2_16/c, prefix 1111000110000, sub-opcode 100; operands pc16-u2; 4 bytes](figures/w/bcc/02.svg)

Operation, flags and exceptions as for the entry BCC above; 2 layout forms, each a chart of its own (above).

<a id="w-bcs"></a>
#### BCS

![BCS: BRF, prefix 11110010001110, sub-opcode 00; operands pc32-u2; 6 bytes](figures/w/bcs/01.svg)

![BCS: BR2_16/c, prefix 1111000110000, sub-opcode 101; operands pc16-u2; 4 bytes](figures/w/bcs/02.svg)

Operation, flags and exceptions as for the entry BCC above; 2 layout forms, each a chart of its own (above).

<a id="w-bge"></a>
#### BGE

![BGE: BRF, prefix 11110010001110, sub-opcode 01; operands pc32-u2; 6 bytes](figures/w/bge/01.svg)

![BGE: BR2_16/c, prefix 1111000110000, sub-opcode 110; operands pc16-u2; 4 bytes](figures/w/bge/02.svg)

Operation, flags and exceptions as for the entry BCC above; 2 layout forms, each a chart of its own (above).

<a id="w-blt"></a>
#### BLT

![BLT: BRF, prefix 11110010001110, sub-opcode 10; operands pc32-u2; 6 bytes](figures/w/blt/01.svg)

![BLT: BR2_16/c, prefix 1111000110000, sub-opcode 111; operands pc16-u2; 4 bytes](figures/w/blt/02.svg)

Operation, flags and exceptions as for the entry BCC above; 2 layout forms, each a chart of its own (above).

<a id="w-bgt"></a>
#### BGT

![BGT: BRF, prefix 11110010001110, sub-opcode 11; operands pc32-u2; 6 bytes](figures/w/bgt/01.svg)

![BGT: BR2_16/c, prefix 11110010100000, sub-opcode 00; operands pc16-u2; 4 bytes](figures/w/bgt/02.svg)

Operation, flags and exceptions as for the entry BCC above; 2 layout forms, each a chart of its own (above).

<a id="w-ble"></a>
#### BLE

![BLE: BRF, prefix 111100101110011, sub-opcode 0; operands pc32-u2; 6 bytes](figures/w/ble/01.svg)

![BLE: BR2_16/c, prefix 11110010100000, sub-opcode 01; operands pc16-u2; 4 bytes](figures/w/ble/02.svg)

Operation, flags and exceptions as for the entry BCC above; 2 layout forms, each a chart of its own (above).

<a id="w-bhi"></a>
#### BHI

![BHI: BRF, prefix 111100101110011, sub-opcode 1; operands pc32-u2; 6 bytes](figures/w/bhi/01.svg)

![BHI: BR2_16/c, prefix 11110010100000, sub-opcode 10; operands pc16-u2; 4 bytes](figures/w/bhi/02.svg)

Operation, flags and exceptions as for the entry BCC above; 2 layout forms, each a chart of its own (above).

<a id="w-blos"></a>
#### BLOS

![BLOS: BRF, prefix 1111001100100010; operands pc32-u2; 6 bytes](figures/w/blos/01.svg)

![BLOS: BR2_16/c, prefix 11110010100000, sub-opcode 11; operands pc16-u2; 4 bytes](figures/w/blos/02.svg)

Operation, flags and exceptions as for the entry BCC above; 2 layout forms, each a chart of its own (above).

<a id="w-bhis"></a>
#### BHIS

An alias of [`BCC`](#w-bcc): the assembler writes it as that word.

<a id="w-blo"></a>
#### BLO

An alias of [`BCS`](#w-bcs): the assembler writes it as that word.


<a id="w-sob"></a>
### SOB: Subtract one and branch

![SOB: SOB, prefix 11101111011; operands reg5, pc16-u2; 4 bytes](figures/w/sob/01.svg)

**Mnemonics:** `SOB`

**Syntax**

```
SOB Rn, target
```

**Encoding**

![Encoding of SOB](figures/SOB-1.svg)

The chart is the leaf `SOB-1`, SOB, prefix `11101111011`. `op1` is `reg5`: register, 5 bits. `op2` is `pc16-u2`: pc-relative, 16 bits counted in 2-byte units (-65536 to 65534 bytes).

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SOB-1`](dictionary/by-encoding.md#SOB-1).

**Operation**

```
Rn ← Rn - 1
if Rn ≠ 0 then PC ← address of this instruction + 2 × disp
```

**Flags** None written.

**Exceptions** None.

From the PDP-11, where it could branch only backward; here the signed displacement goes either way. Four bytes at least.

**Why it is here.** Taken from the PDP-11. The PDP-11's could only branch backward (a 6-bit unsigned displacement); this one branches either way. Against the `cbnz` idiom of other architectures it does not save bytes (`DEC` plus `BNE` is also four in the original encoding) but it saves an instruction issue, a cycle per iteration on a machine that does not pipeline: same size, one instruction fewer (static `dec; bne` pairs exist).


### CBCC: Compare and branch on condition

**Mnemonics:** `CBNE`, `CBEQ`, `CBPL`, `CBMI`, `CBVC`, `CBVS`, `CBCC`, `CBCS`, `CBGE`, `CBLT`, `CBGT`, `CBLE`, `CBHI`, `CBLOS`  (aliases: `CBHIS`, `CBLO`)

**Syntax**

```
CBNE Rd, #imm, target
CBEQ Ra, Rb, target ... and the rest
```

**Encoding**

![Encoding of CBCC](figures/CBI4-8H-a-1.svg)

The chart is the leaf `CBI4-8H-a-1`, CBI4_8H/a, prefix `111100101110111`. `op1` is `reg4`: register, 4 bits (an index into the hot-register table). `op2` is `imm4s`: signed 4-bit immediate, -8 to 7. `op3` is `pc8-u2`: pc-relative, 8 bits counted in 2-byte units (-256 to 254 bytes). `sub` (1 bit) selects the mnemonic: `cbeq` 0, `cbne` 1.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`CBI4-8H-a-1`](dictionary/by-encoding.md#CBI4-8H-a-1), [`CBR8H-a-1`](dictionary/by-encoding.md#CBR8H-a-1), [`CBZ2-12H-a-1`](dictionary/by-encoding.md#CBZ2-12H-a-1), [`CBI5-8H-a-1`](dictionary/by-encoding.md#CBI5-8H-a-1), [`CBI3-8-a-1`](dictionary/by-encoding.md#CBI3-8-a-1), [`CBI6-8H-a-1`](dictionary/by-encoding.md#CBI6-8H-a-1), [`CBI10-8H-a-1`](dictionary/by-encoding.md#CBI10-8H-a-1), [`CB3I8-20H-a-1`](dictionary/by-encoding.md#CB3I8-20H-a-1), [`CB3R24H-a-1`](dictionary/by-encoding.md#CB3R24H-a-1), [`CBI5-10H-a-1`](dictionary/by-encoding.md#CBI5-10H-a-1), [`CBR8-a-1`](dictionary/by-encoding.md#CBR8-a-1), [`CB3I16-12-a-1`](dictionary/by-encoding.md#CB3I16-12-a-1), [`CBZ1-4-a-1`](dictionary/by-encoding.md#CBZ1-4-a-1), [`CBI6-10H-a-1`](dictionary/by-encoding.md#CBI6-10H-a-1), [`CBR10H-a-1`](dictionary/by-encoding.md#CBR10H-a-1), [`CBI8-10H-a-1`](dictionary/by-encoding.md#CBI8-10H-a-1), [`CBI3-12H-a-1`](dictionary/by-encoding.md#CBI3-12H-a-1), [`CBI3-10-a-1`](dictionary/by-encoding.md#CBI3-10-a-1), [`CBZ2-14H-a-1`](dictionary/by-encoding.md#CBZ2-14H-a-1), [`CBI4-8-a-1`](dictionary/by-encoding.md#CBI4-8-a-1), [`CBI5-8-a-1`](dictionary/by-encoding.md#CBI5-8-a-1), [`CBDI-1`](dictionary/by-encoding.md#CBDI-1), [`CBDR-1`](dictionary/by-encoding.md#CBDR-1), [`CBR8H-c-1`](dictionary/by-encoding.md#CBR8H-c-1), [`CB3I16-12H-c-1`](dictionary/by-encoding.md#CB3I16-12H-c-1), [`CBI4-8H-c-1`](dictionary/by-encoding.md#CBI4-8H-c-1), [`CBR8-c-1`](dictionary/by-encoding.md#CBR8-c-1), [`CB3R24H-c-1`](dictionary/by-encoding.md#CB3R24H-c-1), [`CBI6-8H-c-1`](dictionary/by-encoding.md#CBI6-8H-c-1), [`CB3I12-16-c-1`](dictionary/by-encoding.md#CB3I12-16-c-1), [`CBR10H-c-1`](dictionary/by-encoding.md#CBR10H-c-1), [`CBI8-8H-c-1`](dictionary/by-encoding.md#CBI8-8H-c-1), [`CBI4-10H-c-1`](dictionary/by-encoding.md#CBI4-10H-c-1), [`CBI3-8-c-1`](dictionary/by-encoding.md#CBI3-8-c-1), [`CB3I16-12H-b-1`](dictionary/by-encoding.md#CB3I16-12H-b-1), [`CBR8H-b-1`](dictionary/by-encoding.md#CBR8H-b-1), [`CBI8-8H-b-1`](dictionary/by-encoding.md#CBI8-8H-b-1), [`CBZ2-12H-b-1`](dictionary/by-encoding.md#CBZ2-12H-b-1), [`CB3I8-20-b-1`](dictionary/by-encoding.md#CB3I8-20-b-1), [`CBR8-b-1`](dictionary/by-encoding.md#CBR8-b-1), [`CBI3-8-b-1`](dictionary/by-encoding.md#CBI3-8-b-1), [`CBI4-10H-b-1`](dictionary/by-encoding.md#CBI4-10H-b-1), [`CB3R24H-b-1`](dictionary/by-encoding.md#CB3R24H-b-1), [`CBI4-8-b-1`](dictionary/by-encoding.md#CBI4-8-b-1).

**Operation**

```
tmp ← Rd - (imm or Rb)         ; as CMP, for the decision only
if cond(c) on that comparison then PC ← address of this instruction + 2 × disp
```

**Flags** **None written**: the instruction computes the comparison for its own decision and leaves `N Z V C` as they were.

**Exceptions** None.

The family has several forms for each condition (the layouts of this entry): the second operand is a register or an immediate of some width, and the reach differs. A `cbCC` that no form reaches is assembled by `as64` as `CMP` and `bCC`, which **writes the flags** (errata 87, assumption 6; the integration measured 17 such sites in 34,524, errata 90).

**Why it is here.** A fused compare-and-branch, estimated with `RORI32` at 22 KB (1.3%) of the image of the original encoding. There the wide-immediate form removes 11,735 instructions (3.4%) and 1,828 bytes, and the register-register compare-and-branch removes 4,631 instructions (1.4%) and 142 bytes. It is not a replacement for flags: LoongArch and RISC-V chose fused compare-and-branch instead of flags, and this architecture declines that (9.20) because it needs a comparator in the branch unit and a third read port; here the fused form is added beside the flags. `CBCC` writes no flags.

<a id="w-cbne"></a>
#### CBNE

![CBNE: CB3I8_20H/a, prefix 111100110000011, sub-opcode 1; operands reg4, imm8s, pc20-u2; 6 bytes](figures/w/cbne/08.svg)

![CBNE: CB3R24H/a, prefix 111100110000110, sub-opcode 1; operands reg4, reg4, pc24-u2; 6 bytes](figures/w/cbne/09.svg)

![CBNE: CB3I16_12/a, prefix 11110010100101, sub-opcode 1; operands reg5, imm16s, pc12-u2; 6 bytes](figures/w/cbne/12.svg)

![CBNE: CBI4_8H/a, prefix 111100101110111, sub-opcode 1; operands reg4, imm4s, pc8-u2; 4 bytes](figures/w/cbne/01.svg)

![CBNE: CBR8H/a, prefix 111100101111010, sub-opcode 1; operands reg4, reg4, pc8-u2; 4 bytes](figures/w/cbne/02.svg)

![CBNE: CBZ2_12H/a, prefix 111100101111110, sub-opcode 1; operands reg4, k-imm0, pc12-u2; 4 bytes](figures/w/cbne/03.svg)

![CBNE: CBI5_8H/a, prefix 11110010011000, sub-opcode 1; operands reg4, imm5s, pc8-u2; 4 bytes](figures/w/cbne/04.svg)

![CBNE: CBI3_8/a, prefix 111100110000001, sub-opcode 1; operands reg5, imm3s, pc8-u2; 4 bytes](figures/w/cbne/05.svg)

![CBNE: CBI6_8H/a, prefix 1111000101111, sub-opcode 1; operands reg4, imm6s, pc8-u2; 4 bytes](figures/w/cbne/06.svg)

![CBNE: CBI10_8H/a, prefix 111000110, sub-opcode 1; operands reg4, imm10s, pc8-u2; 4 bytes](figures/w/cbne/07.svg)

![CBNE: CBI5_10H/a, prefix 111100001011, sub-opcode 1; operands reg4, imm5s, pc10-u2; 4 bytes](figures/w/cbne/10.svg)

![CBNE: CBR8/a, prefix 1111000110100, sub-opcode 1; operands reg5, reg5, pc8-u2; 4 bytes](figures/w/cbne/11.svg)

![CBNE: CBI6_10H/a, prefix 11101111111, sub-opcode 1; operands reg4, imm6s, pc10-u2; 4 bytes](figures/w/cbne/14.svg)

![CBNE: CBR10H/a, prefix 1111000111101, sub-opcode 1; operands reg4, reg4, pc10-u2; 4 bytes](figures/w/cbne/15.svg)

![CBNE: CBI8_10H/a, prefix 111001101, sub-opcode 1; operands reg4, imm8s, pc10-u2; 4 bytes](figures/w/cbne/16.svg)

![CBNE: CBI3_12H/a, prefix 111100010000, sub-opcode 1; operands reg4, imm3s, pc12-u2; 4 bytes](figures/w/cbne/17.svg)

![CBNE: CBI3_10/a, prefix 1111000111110, sub-opcode 1; operands reg5, imm3s, pc10-u2; 4 bytes](figures/w/cbne/18.svg)

![CBNE: CBZ2_14H/a, prefix 1111001000000, sub-opcode 1; operands reg4, k-imm0, pc14-u2; 4 bytes](figures/w/cbne/19.svg)

![CBNE: CBI4_8/a, prefix 11110010110010, sub-opcode 1; operands reg5, imm4s, pc8-u2; 4 bytes](figures/w/cbne/20.svg)

![CBNE: CBI5_8/a, prefix 1111001000101, sub-opcode 1; operands reg5, imm5s, pc8-u2; 4 bytes](figures/w/cbne/21.svg)

![CBNE: CBZ1_4/a, prefix 100101, sub-opcode 1; operands reg5, k-imm0, pc4-u2; 2 bytes](figures/w/cbne/13.svg)

```
CBNE Rd, #imm, target
```

Operation, flags and exceptions as for the entry CBCC above; 21 layout forms, each a chart of its own (above).

<a id="w-cbeq"></a>
#### CBEQ

![CBEQ: CB3I8_20H/a, prefix 111100110000011, sub-opcode 0; operands reg4, imm8s, pc20-u2; 6 bytes](figures/w/cbeq/08.svg)

![CBEQ: CB3R24H/a, prefix 111100110000110, sub-opcode 0; operands reg4, reg4, pc24-u2; 6 bytes](figures/w/cbeq/09.svg)

![CBEQ: CB3I16_12/a, prefix 11110010100101, sub-opcode 0; operands reg5, imm16s, pc12-u2; 6 bytes](figures/w/cbeq/12.svg)

![CBEQ: CBI4_8H/a, prefix 111100101110111, sub-opcode 0; operands reg4, imm4s, pc8-u2; 4 bytes](figures/w/cbeq/01.svg)

![CBEQ: CBR8H/a, prefix 111100101111010, sub-opcode 0; operands reg4, reg4, pc8-u2; 4 bytes](figures/w/cbeq/02.svg)

![CBEQ: CBZ2_12H/a, prefix 111100101111110, sub-opcode 0; operands reg4, k-imm0, pc12-u2; 4 bytes](figures/w/cbeq/03.svg)

![CBEQ: CBI5_8H/a, prefix 11110010011000, sub-opcode 0; operands reg4, imm5s, pc8-u2; 4 bytes](figures/w/cbeq/04.svg)

![CBEQ: CBI3_8/a, prefix 111100110000001, sub-opcode 0; operands reg5, imm3s, pc8-u2; 4 bytes](figures/w/cbeq/05.svg)

![CBEQ: CBI6_8H/a, prefix 1111000101111, sub-opcode 0; operands reg4, imm6s, pc8-u2; 4 bytes](figures/w/cbeq/06.svg)

![CBEQ: CBI10_8H/a, prefix 111000110, sub-opcode 0; operands reg4, imm10s, pc8-u2; 4 bytes](figures/w/cbeq/07.svg)

![CBEQ: CBI5_10H/a, prefix 111100001011, sub-opcode 0; operands reg4, imm5s, pc10-u2; 4 bytes](figures/w/cbeq/10.svg)

![CBEQ: CBR8/a, prefix 1111000110100, sub-opcode 0; operands reg5, reg5, pc8-u2; 4 bytes](figures/w/cbeq/11.svg)

![CBEQ: CBI6_10H/a, prefix 11101111111, sub-opcode 0; operands reg4, imm6s, pc10-u2; 4 bytes](figures/w/cbeq/14.svg)

![CBEQ: CBR10H/a, prefix 1111000111101, sub-opcode 0; operands reg4, reg4, pc10-u2; 4 bytes](figures/w/cbeq/15.svg)

![CBEQ: CBI8_10H/a, prefix 111001101, sub-opcode 0; operands reg4, imm8s, pc10-u2; 4 bytes](figures/w/cbeq/16.svg)

![CBEQ: CBI3_12H/a, prefix 111100010000, sub-opcode 0; operands reg4, imm3s, pc12-u2; 4 bytes](figures/w/cbeq/17.svg)

![CBEQ: CBI3_10/a, prefix 1111000111110, sub-opcode 0; operands reg5, imm3s, pc10-u2; 4 bytes](figures/w/cbeq/18.svg)

![CBEQ: CBZ2_14H/a, prefix 1111001000000, sub-opcode 0; operands reg4, k-imm0, pc14-u2; 4 bytes](figures/w/cbeq/19.svg)

![CBEQ: CBI4_8/a, prefix 11110010110010, sub-opcode 0; operands reg5, imm4s, pc8-u2; 4 bytes](figures/w/cbeq/20.svg)

![CBEQ: CBI5_8/a, prefix 1111001000101, sub-opcode 0; operands reg5, imm5s, pc8-u2; 4 bytes](figures/w/cbeq/21.svg)

![CBEQ: CBZ1_4/a, prefix 100101, sub-opcode 0; operands reg5, k-imm0, pc4-u2; 2 bytes](figures/w/cbeq/13.svg)

```
CBEQ Ra, Rb, target ... and the rest
```

Operation, flags and exceptions as for the entry CBCC above; 21 layout forms, each a chart of its own (above).

<a id="w-cbpl"></a>
#### CBPL

![CBPL: CBDI, prefix 111000100, sub-opcode 00; operands reg5, imm6s, pc10-u2; 4 bytes](figures/w/cbpl/01.svg)

![CBPL: CBDR, prefix 11010101, sub-opcode 00; operands reg5, reg5, pc12-u2; 4 bytes](figures/w/cbpl/02.svg)

Operation, flags and exceptions as for the entry CBCC above; 2 layout forms, each a chart of its own (above).

<a id="w-cbmi"></a>
#### CBMI

![CBMI: CBDI, prefix 111000100, sub-opcode 01; operands reg5, imm6s, pc10-u2; 4 bytes](figures/w/cbmi/01.svg)

![CBMI: CBDR, prefix 11010101, sub-opcode 01; operands reg5, reg5, pc12-u2; 4 bytes](figures/w/cbmi/02.svg)

Operation, flags and exceptions as for the entry CBCC above; 2 layout forms, each a chart of its own (above).

<a id="w-cbvc"></a>
#### CBVC

![CBVC: CBDI, prefix 111000100, sub-opcode 10; operands reg5, imm6s, pc10-u2; 4 bytes](figures/w/cbvc/01.svg)

![CBVC: CBDR, prefix 11010101, sub-opcode 10; operands reg5, reg5, pc12-u2; 4 bytes](figures/w/cbvc/02.svg)

Operation, flags and exceptions as for the entry CBCC above; 2 layout forms, each a chart of its own (above).

<a id="w-cbvs"></a>
#### CBVS

![CBVS: CBDI, prefix 111000100, sub-opcode 11; operands reg5, imm6s, pc10-u2; 4 bytes](figures/w/cbvs/01.svg)

![CBVS: CBDR, prefix 11010101, sub-opcode 11; operands reg5, reg5, pc12-u2; 4 bytes](figures/w/cbvs/02.svg)

Operation, flags and exceptions as for the entry CBCC above; 2 layout forms, each a chart of its own (above).

<a id="w-cbcc"></a>
#### CBCC

![CBCC: CB3I16_12H/c, prefix 11110010010100, sub-opcode 01; operands reg4, imm16s, pc12-u2; 6 bytes](figures/w/cbcc/02.svg)

![CBCC: CB3R24H/c, prefix 11110010100100, sub-opcode 01; operands reg4, reg4, pc24-u2; 6 bytes](figures/w/cbcc/05.svg)

![CBCC: CB3I12_16/c, prefix 1111000111001, sub-opcode 01; operands reg5, imm12s, pc16-u2; 6 bytes](figures/w/cbcc/07.svg)

![CBCC: CBR8H/c, prefix 11110010010011, sub-opcode 01; operands reg4, reg4, pc8-u2; 4 bytes](figures/w/cbcc/01.svg)

![CBCC: CBI4_8H/c, prefix 11110010100001, sub-opcode 01; operands reg4, imm4s, pc8-u2; 4 bytes](figures/w/cbcc/03.svg)

![CBCC: CBR8/c, prefix 111100001001, sub-opcode 01; operands reg5, reg5, pc8-u2; 4 bytes](figures/w/cbcc/04.svg)

![CBCC: CBI6_8H/c, prefix 111100001010, sub-opcode 01; operands reg4, imm6s, pc8-u2; 4 bytes](figures/w/cbcc/06.svg)

![CBCC: CBR10H/c, prefix 111100001101, sub-opcode 01; operands reg4, reg4, pc10-u2; 4 bytes](figures/w/cbcc/08.svg)

![CBCC: CBI8_8H/c, prefix 1110110100, sub-opcode 01; operands reg4, imm8s, pc8-u2; 4 bytes](figures/w/cbcc/09.svg)

![CBCC: CBI4_10H/c, prefix 111100010010, sub-opcode 01; operands reg4, imm4s, pc10-u2; 4 bytes](figures/w/cbcc/10.svg)

![CBCC: CBI3_8/c, prefix 11110010110101, sub-opcode 01; operands reg5, imm3s, pc8-u2; 4 bytes](figures/w/cbcc/11.svg)

Operation, flags and exceptions as for the entry CBCC above; 11 layout forms, each a chart of its own (above).

<a id="w-cbcs"></a>
#### CBCS

![CBCS: CB3I16_12H/c, prefix 11110010010100, sub-opcode 00; operands reg4, imm16s, pc12-u2; 6 bytes](figures/w/cbcs/02.svg)

![CBCS: CB3R24H/c, prefix 11110010100100, sub-opcode 00; operands reg4, reg4, pc24-u2; 6 bytes](figures/w/cbcs/05.svg)

![CBCS: CB3I12_16/c, prefix 1111000111001, sub-opcode 00; operands reg5, imm12s, pc16-u2; 6 bytes](figures/w/cbcs/07.svg)

![CBCS: CBR8H/c, prefix 11110010010011, sub-opcode 00; operands reg4, reg4, pc8-u2; 4 bytes](figures/w/cbcs/01.svg)

![CBCS: CBI4_8H/c, prefix 11110010100001, sub-opcode 00; operands reg4, imm4s, pc8-u2; 4 bytes](figures/w/cbcs/03.svg)

![CBCS: CBR8/c, prefix 111100001001, sub-opcode 00; operands reg5, reg5, pc8-u2; 4 bytes](figures/w/cbcs/04.svg)

![CBCS: CBI6_8H/c, prefix 111100001010, sub-opcode 00; operands reg4, imm6s, pc8-u2; 4 bytes](figures/w/cbcs/06.svg)

![CBCS: CBR10H/c, prefix 111100001101, sub-opcode 00; operands reg4, reg4, pc10-u2; 4 bytes](figures/w/cbcs/08.svg)

![CBCS: CBI8_8H/c, prefix 1110110100, sub-opcode 00; operands reg4, imm8s, pc8-u2; 4 bytes](figures/w/cbcs/09.svg)

![CBCS: CBI4_10H/c, prefix 111100010010, sub-opcode 00; operands reg4, imm4s, pc10-u2; 4 bytes](figures/w/cbcs/10.svg)

![CBCS: CBI3_8/c, prefix 11110010110101, sub-opcode 00; operands reg5, imm3s, pc8-u2; 4 bytes](figures/w/cbcs/11.svg)

Operation, flags and exceptions as for the entry CBCC above; 11 layout forms, each a chart of its own (above).

<a id="w-cbge"></a>
#### CBGE

![CBGE: CB3I16_12H/b, prefix 11110010010001, sub-opcode 01; operands reg4, imm16s, pc12-u2; 6 bytes](figures/w/cbge/01.svg)

![CBGE: CB3I8_20/b, prefix 1111000111000, sub-opcode 01; operands reg5, imm8s, pc20-u2; 6 bytes](figures/w/cbge/05.svg)

![CBGE: CB3R24H/b, prefix 11110010110011, sub-opcode 01; operands reg4, reg4, pc24-u2; 6 bytes](figures/w/cbge/09.svg)

![CBGE: CBR8H/b, prefix 11110010010111, sub-opcode 01; operands reg4, reg4, pc8-u2; 4 bytes](figures/w/cbge/02.svg)

![CBGE: CBI8_8H/b, prefix 1110110001, sub-opcode 01; operands reg4, imm8s, pc8-u2; 4 bytes](figures/w/cbge/03.svg)

![CBGE: CBZ2_12H/b, prefix 11110010100010, sub-opcode 01; operands reg4, k-imm0, pc12-u2; 4 bytes](figures/w/cbge/04.svg)

![CBGE: CBR8/b, prefix 111100001100, sub-opcode 01; operands reg5, reg5, pc8-u2; 4 bytes](figures/w/cbge/06.svg)

![CBGE: CBI3_8/b, prefix 11110010101101, sub-opcode 01; operands reg5, imm3s, pc8-u2; 4 bytes](figures/w/cbge/07.svg)

![CBGE: CBI4_10H/b, prefix 111100010100, sub-opcode 01; operands reg4, imm4s, pc10-u2; 4 bytes](figures/w/cbge/08.svg)

![CBGE: CBI4_8/b, prefix 1111001000100, sub-opcode 01; operands reg5, imm4s, pc8-u2; 4 bytes](figures/w/cbge/10.svg)

Operation, flags and exceptions as for the entry CBCC above; 10 layout forms, each a chart of its own (above).

<a id="w-cblt"></a>
#### CBLT

![CBLT: CB3I16_12H/b, prefix 11110010010001, sub-opcode 00; operands reg4, imm16s, pc12-u2; 6 bytes](figures/w/cblt/01.svg)

![CBLT: CB3I8_20/b, prefix 1111000111000, sub-opcode 00; operands reg5, imm8s, pc20-u2; 6 bytes](figures/w/cblt/05.svg)

![CBLT: CB3R24H/b, prefix 11110010110011, sub-opcode 00; operands reg4, reg4, pc24-u2; 6 bytes](figures/w/cblt/09.svg)

![CBLT: CBR8H/b, prefix 11110010010111, sub-opcode 00; operands reg4, reg4, pc8-u2; 4 bytes](figures/w/cblt/02.svg)

![CBLT: CBI8_8H/b, prefix 1110110001, sub-opcode 00; operands reg4, imm8s, pc8-u2; 4 bytes](figures/w/cblt/03.svg)

![CBLT: CBZ2_12H/b, prefix 11110010100010, sub-opcode 00; operands reg4, k-imm0, pc12-u2; 4 bytes](figures/w/cblt/04.svg)

![CBLT: CBR8/b, prefix 111100001100, sub-opcode 00; operands reg5, reg5, pc8-u2; 4 bytes](figures/w/cblt/06.svg)

![CBLT: CBI3_8/b, prefix 11110010101101, sub-opcode 00; operands reg5, imm3s, pc8-u2; 4 bytes](figures/w/cblt/07.svg)

![CBLT: CBI4_10H/b, prefix 111100010100, sub-opcode 00; operands reg4, imm4s, pc10-u2; 4 bytes](figures/w/cblt/08.svg)

![CBLT: CBI4_8/b, prefix 1111001000100, sub-opcode 00; operands reg5, imm4s, pc8-u2; 4 bytes](figures/w/cblt/10.svg)

Operation, flags and exceptions as for the entry CBCC above; 10 layout forms, each a chart of its own (above).

<a id="w-cbgt"></a>
#### CBGT

![CBGT: CB3I16_12H/b, prefix 11110010010001, sub-opcode 10; operands reg4, imm16s, pc12-u2; 6 bytes](figures/w/cbgt/01.svg)

![CBGT: CB3I8_20/b, prefix 1111000111000, sub-opcode 10; operands reg5, imm8s, pc20-u2; 6 bytes](figures/w/cbgt/05.svg)

![CBGT: CB3R24H/b, prefix 11110010110011, sub-opcode 10; operands reg4, reg4, pc24-u2; 6 bytes](figures/w/cbgt/09.svg)

![CBGT: CBR8H/b, prefix 11110010010111, sub-opcode 10; operands reg4, reg4, pc8-u2; 4 bytes](figures/w/cbgt/02.svg)

![CBGT: CBI8_8H/b, prefix 1110110001, sub-opcode 10; operands reg4, imm8s, pc8-u2; 4 bytes](figures/w/cbgt/03.svg)

![CBGT: CBZ2_12H/b, prefix 11110010100010, sub-opcode 10; operands reg4, k-imm0, pc12-u2; 4 bytes](figures/w/cbgt/04.svg)

![CBGT: CBR8/b, prefix 111100001100, sub-opcode 10; operands reg5, reg5, pc8-u2; 4 bytes](figures/w/cbgt/06.svg)

![CBGT: CBI3_8/b, prefix 11110010101101, sub-opcode 10; operands reg5, imm3s, pc8-u2; 4 bytes](figures/w/cbgt/07.svg)

![CBGT: CBI4_10H/b, prefix 111100010100, sub-opcode 10; operands reg4, imm4s, pc10-u2; 4 bytes](figures/w/cbgt/08.svg)

![CBGT: CBI4_8/b, prefix 1111001000100, sub-opcode 10; operands reg5, imm4s, pc8-u2; 4 bytes](figures/w/cbgt/10.svg)

Operation, flags and exceptions as for the entry CBCC above; 10 layout forms, each a chart of its own (above).

<a id="w-cble"></a>
#### CBLE

![CBLE: CB3I16_12H/b, prefix 11110010010001, sub-opcode 11; operands reg4, imm16s, pc12-u2; 6 bytes](figures/w/cble/01.svg)

![CBLE: CB3I8_20/b, prefix 1111000111000, sub-opcode 11; operands reg5, imm8s, pc20-u2; 6 bytes](figures/w/cble/05.svg)

![CBLE: CB3R24H/b, prefix 11110010110011, sub-opcode 11; operands reg4, reg4, pc24-u2; 6 bytes](figures/w/cble/09.svg)

![CBLE: CBR8H/b, prefix 11110010010111, sub-opcode 11; operands reg4, reg4, pc8-u2; 4 bytes](figures/w/cble/02.svg)

![CBLE: CBI8_8H/b, prefix 1110110001, sub-opcode 11; operands reg4, imm8s, pc8-u2; 4 bytes](figures/w/cble/03.svg)

![CBLE: CBZ2_12H/b, prefix 11110010100010, sub-opcode 11; operands reg4, k-imm0, pc12-u2; 4 bytes](figures/w/cble/04.svg)

![CBLE: CBR8/b, prefix 111100001100, sub-opcode 11; operands reg5, reg5, pc8-u2; 4 bytes](figures/w/cble/06.svg)

![CBLE: CBI3_8/b, prefix 11110010101101, sub-opcode 11; operands reg5, imm3s, pc8-u2; 4 bytes](figures/w/cble/07.svg)

![CBLE: CBI4_10H/b, prefix 111100010100, sub-opcode 11; operands reg4, imm4s, pc10-u2; 4 bytes](figures/w/cble/08.svg)

![CBLE: CBI4_8/b, prefix 1111001000100, sub-opcode 11; operands reg5, imm4s, pc8-u2; 4 bytes](figures/w/cble/10.svg)

Operation, flags and exceptions as for the entry CBCC above; 10 layout forms, each a chart of its own (above).

<a id="w-cbhi"></a>
#### CBHI

![CBHI: CB3I16_12H/c, prefix 11110010010100, sub-opcode 10; operands reg4, imm16s, pc12-u2; 6 bytes](figures/w/cbhi/02.svg)

![CBHI: CB3R24H/c, prefix 11110010100100, sub-opcode 10; operands reg4, reg4, pc24-u2; 6 bytes](figures/w/cbhi/05.svg)

![CBHI: CB3I12_16/c, prefix 1111000111001, sub-opcode 10; operands reg5, imm12s, pc16-u2; 6 bytes](figures/w/cbhi/07.svg)

![CBHI: CBR8H/c, prefix 11110010010011, sub-opcode 10; operands reg4, reg4, pc8-u2; 4 bytes](figures/w/cbhi/01.svg)

![CBHI: CBI4_8H/c, prefix 11110010100001, sub-opcode 10; operands reg4, imm4s, pc8-u2; 4 bytes](figures/w/cbhi/03.svg)

![CBHI: CBR8/c, prefix 111100001001, sub-opcode 10; operands reg5, reg5, pc8-u2; 4 bytes](figures/w/cbhi/04.svg)

![CBHI: CBI6_8H/c, prefix 111100001010, sub-opcode 10; operands reg4, imm6s, pc8-u2; 4 bytes](figures/w/cbhi/06.svg)

![CBHI: CBR10H/c, prefix 111100001101, sub-opcode 10; operands reg4, reg4, pc10-u2; 4 bytes](figures/w/cbhi/08.svg)

![CBHI: CBI8_8H/c, prefix 1110110100, sub-opcode 10; operands reg4, imm8s, pc8-u2; 4 bytes](figures/w/cbhi/09.svg)

![CBHI: CBI4_10H/c, prefix 111100010010, sub-opcode 10; operands reg4, imm4s, pc10-u2; 4 bytes](figures/w/cbhi/10.svg)

![CBHI: CBI3_8/c, prefix 11110010110101, sub-opcode 10; operands reg5, imm3s, pc8-u2; 4 bytes](figures/w/cbhi/11.svg)

Operation, flags and exceptions as for the entry CBCC above; 11 layout forms, each a chart of its own (above).

<a id="w-cblos"></a>
#### CBLOS

![CBLOS: CB3I16_12H/c, prefix 11110010010100, sub-opcode 11; operands reg4, imm16s, pc12-u2; 6 bytes](figures/w/cblos/02.svg)

![CBLOS: CB3R24H/c, prefix 11110010100100, sub-opcode 11; operands reg4, reg4, pc24-u2; 6 bytes](figures/w/cblos/05.svg)

![CBLOS: CB3I12_16/c, prefix 1111000111001, sub-opcode 11; operands reg5, imm12s, pc16-u2; 6 bytes](figures/w/cblos/07.svg)

![CBLOS: CBR8H/c, prefix 11110010010011, sub-opcode 11; operands reg4, reg4, pc8-u2; 4 bytes](figures/w/cblos/01.svg)

![CBLOS: CBI4_8H/c, prefix 11110010100001, sub-opcode 11; operands reg4, imm4s, pc8-u2; 4 bytes](figures/w/cblos/03.svg)

![CBLOS: CBR8/c, prefix 111100001001, sub-opcode 11; operands reg5, reg5, pc8-u2; 4 bytes](figures/w/cblos/04.svg)

![CBLOS: CBI6_8H/c, prefix 111100001010, sub-opcode 11; operands reg4, imm6s, pc8-u2; 4 bytes](figures/w/cblos/06.svg)

![CBLOS: CBR10H/c, prefix 111100001101, sub-opcode 11; operands reg4, reg4, pc10-u2; 4 bytes](figures/w/cblos/08.svg)

![CBLOS: CBI8_8H/c, prefix 1110110100, sub-opcode 11; operands reg4, imm8s, pc8-u2; 4 bytes](figures/w/cblos/09.svg)

![CBLOS: CBI4_10H/c, prefix 111100010010, sub-opcode 11; operands reg4, imm4s, pc10-u2; 4 bytes](figures/w/cblos/10.svg)

![CBLOS: CBI3_8/c, prefix 11110010110101, sub-opcode 11; operands reg5, imm3s, pc8-u2; 4 bytes](figures/w/cblos/11.svg)

Operation, flags and exceptions as for the entry CBCC above; 11 layout forms, each a chart of its own (above).

<a id="w-cbhis"></a>
#### CBHIS

An alias of [`CBCC`](#w-cbcc): the assembler writes it as that word.

<a id="w-cblo"></a>
#### CBLO

An alias of [`CBCS`](#w-cbcs): the assembler writes it as that word.


### BTAG: Branch on pointer tag

**Mnemonics:** `BTAG`, `BNTAG`

**Syntax**

```
BTAG Rn, #tag, target
BNTAG Rn, #tag, target
```

**Encoding**

![Encoding of BTAG](figures/TAG-1.svg)

The chart is the leaf `TAG-1`, TAG, prefix `1110101111`. `op1` is `reg5`: register, 5 bits. `op2` is `imm3u`: unsigned 3-bit immediate, 0 to 7. `op3` is `pc13-u2`: pc-relative, 13 bits counted in 2-byte units (-8192 to 8190 bytes). `sub` (1 bit) selects the mnemonic: `btag` 0, `bntag` 1.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`TAG-1`](dictionary/by-encoding.md#TAG-1).

**Operation**

```
BTAG : if (Rn & 111₂) = tag then PC ← address of this instruction + 2 × disp
BNTAG: if (Rn & 111₂) ≠ tag then PC ← address of this instruction + 2 × disp
```

**Flags** None written.

**Exceptions** None.

For runtimes that keep a 3-bit type tag in the low bits of a pointer (`lowtag`). The displacement is signed and counts parcels.

**Why it is here.** The tag branches `BTAG` and `BNTAG` and the table dispatch `JTAG` make tagged pointers cheap to use rather than merely possible. Because quad-aligned objects have zero in the low three bits, the tag is free, and an unaligned access is a fault. The compiler for C never emits them (the corpus shows none); they are for Lisp and other tagged runtimes.

<a id="w-btag"></a>
#### BTAG

![BTAG: TAG, prefix 1110101111, sub-opcode 0; operands reg5, imm3u, pc13-u2; 4 bytes](figures/w/btag/01.svg)

```
BTAG Rn, #tag, target
```

Operation, flags and exceptions as for the entry BTAG above; 1 layout form, each a chart of its own (above).

<a id="w-bntag"></a>
#### BNTAG

![BNTAG: TAG, prefix 1110101111, sub-opcode 1; operands reg5, imm3u, pc13-u2; 4 bytes](figures/w/bntag/01.svg)

```
BNTAG Rn, #tag, target
```

Operation, flags and exceptions as for the entry BTAG above; 1 layout form, each a chart of its own (above).


<a id="w-jmp"></a>
### JMP: Jump

![JMP: SOF.B28, prefix 11101110111, sub-opcode 1100; operands b5d28s-x1; 6 bytes](figures/w/jmp/01.svg)

![JMP: SOF.X22, prefix 1110101101, sub-opcode 1100; operands x5-5d22s; 6 bytes](figures/w/jmp/02.svg)

![JMP: SOF.PC32, prefix 111100000100, sub-opcode 1100; operands pc32-u1; 6 bytes](figures/w/jmp/05.svg)

![JMP: SOF.A32, prefix 111100000101, sub-opcode 1100; operands abs32; 6 bytes](figures/w/jmp/06.svg)

![JMP: CALLF, prefix 111100101110100, sub-opcode 1; operands pc32-u2; 6 bytes](figures/w/jmp/07.svg)

![JMP: SOF.PI12, prefix 11101111000, sub-opcode 1100; operands pi5-s12; 4 bytes](figures/w/jmp/03.svg)

![JMP: SOF.PD12, prefix 11101111001, sub-opcode 1100; operands pd5-s12; 4 bytes](figures/w/jmp/04.svg)

![JMP: CALL2_16/j, prefix 1111001100101010; operands pc16-u2; 4 bytes](figures/w/jmp/09.svg)

![JMP: SOBu12H/x, prefix 11110010011100, sub-opcode 00; operands b4d12u-xsz; 4 bytes](figures/w/jmp/10.svg)

![JMP: SOBs12/x, prefix 1111001000001, sub-opcode 00; operands b5d12s-xsz; 4 bytes](figures/w/jmp/11.svg)

![JMP: SOX4/x, prefix 11110010110110, sub-opcode 00; operands x5-5d4s; 4 bytes](figures/w/jmp/12.svg)

![JMP: SOPR, prefix 1110101110, sub-opcode 0; operands reg5; 2 bytes](figures/w/jmp/08.svg)

**Mnemonics:** `JMP`

**Syntax**

```
JMP rm        ; a register, or an address by any memory mode
```

**Encoding**

![Encoding of JMP](figures/SOF-B28-1.svg)

The chart is the leaf `SOF-B28-1`, SOF.B28, prefix `11101110111`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `sub` (4 bits) selects the mnemonic: `clr` 0000, `com` 0001, `inc` 0010, `dec` 0011, `neg` 0100, `tst` 0101, `adc` 0110, `sbc` 0111, `asl` 1000, `asr` 1001, `push` 1010, `pop` 1011, `jmp` 1100, `call` 1101, `jmpi` 1110, `calli` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SOF-B28-1`](dictionary/by-encoding.md#SOF-B28-1), [`SOF-X22-1`](dictionary/by-encoding.md#SOF-X22-1), [`SOF-PI12-1`](dictionary/by-encoding.md#SOF-PI12-1), [`SOF-PD12-1`](dictionary/by-encoding.md#SOF-PD12-1), [`SOF-PC32-1`](dictionary/by-encoding.md#SOF-PC32-1), [`SOF-A32-1`](dictionary/by-encoding.md#SOF-A32-1), [`CALLF-1`](dictionary/by-encoding.md#CALLF-1), [`SOPR-3`](dictionary/by-encoding.md#SOPR-3), [`CALL2-16-j-1`](dictionary/by-encoding.md#CALL2-16-j-1), [`SOBu12H-x-1`](dictionary/by-encoding.md#SOBu12H-x-1), [`SOBs12-x-1`](dictionary/by-encoding.md#SOBs12-x-1), [`SOX4-x-1`](dictionary/by-encoding.md#SOX4-x-1).

**Operation**

```
PC ← (register operand) ? Rm : EA(rm)
```

**Flags** None written.

**Exceptions** A jump to an unmapped or non-executable address faults on the fetch of the target.

A switch is a `CMP` against the limit, a `BHIS` to the default and a `JMP` through a scaled index.


<a id="w-call"></a>
### CALL: Call

![CALL: SOF.B28, prefix 11101110111, sub-opcode 1101; operands b5d28s-x1; 6 bytes](figures/w/call/01.svg)

![CALL: SOF.X22, prefix 1110101101, sub-opcode 1101; operands x5-5d22s; 6 bytes](figures/w/call/02.svg)

![CALL: SOF.PC32, prefix 111100000100, sub-opcode 1101; operands pc32-u1; 6 bytes](figures/w/call/05.svg)

![CALL: SOF.A32, prefix 111100000101, sub-opcode 1101; operands abs32; 6 bytes](figures/w/call/06.svg)

![CALL: CALLF, prefix 111100101110100, sub-opcode 0; operands pc32-u2; 6 bytes](figures/w/call/07.svg)

![CALL: SOF.PI12, prefix 11101111000, sub-opcode 1101; operands pi5-s12; 4 bytes](figures/w/call/03.svg)

![CALL: SOF.PD12, prefix 11101111001, sub-opcode 1101; operands pd5-s12; 4 bytes](figures/w/call/04.svg)

![CALL: CALL2_16/c, prefix 1111001100100111; operands pc16-u2; 4 bytes](figures/w/call/09.svg)

![CALL: CALL2_18/c, prefix 11110010010110; operands pc18-u2; 4 bytes](figures/w/call/10.svg)

![CALL: SOBu12H/x, prefix 11110010011100, sub-opcode 01; operands b4d12u-xsz; 4 bytes](figures/w/call/11.svg)

![CALL: SOBs12/x, prefix 1111001000001, sub-opcode 01; operands b5d12s-xsz; 4 bytes](figures/w/call/12.svg)

![CALL: SOX4/x, prefix 11110010110110, sub-opcode 01; operands x5-5d4s; 4 bytes](figures/w/call/13.svg)

![CALL: SOPR, prefix 1110101110, sub-opcode 1; operands reg5; 2 bytes](figures/w/call/08.svg)

**Mnemonics:** `CALL`

**Syntax**

```
CALL rm
```

**Encoding**

![Encoding of CALL](figures/SOF-B28-1.svg)

The chart is the leaf `SOF-B28-1`, SOF.B28, prefix `11101110111`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `sub` (4 bits) selects the mnemonic: `clr` 0000, `com` 0001, `inc` 0010, `dec` 0011, `neg` 0100, `tst` 0101, `adc` 0110, `sbc` 0111, `asl` 1000, `asr` 1001, `push` 1010, `pop` 1011, `jmp` 1100, `call` 1101, `jmpi` 1110, `calli` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SOF-B28-1`](dictionary/by-encoding.md#SOF-B28-1), [`SOF-X22-1`](dictionary/by-encoding.md#SOF-X22-1), [`SOF-PI12-1`](dictionary/by-encoding.md#SOF-PI12-1), [`SOF-PD12-1`](dictionary/by-encoding.md#SOF-PD12-1), [`SOF-PC32-1`](dictionary/by-encoding.md#SOF-PC32-1), [`SOF-A32-1`](dictionary/by-encoding.md#SOF-A32-1), [`CALLF-1`](dictionary/by-encoding.md#CALLF-1), [`SOPR-3`](dictionary/by-encoding.md#SOPR-3), [`CALL2-16-c-1`](dictionary/by-encoding.md#CALL2-16-c-1), [`CALL2-18-c-1`](dictionary/by-encoding.md#CALL2-18-c-1), [`SOBu12H-x-1`](dictionary/by-encoding.md#SOBu12H-x-1), [`SOBs12-x-1`](dictionary/by-encoding.md#SOBs12-x-1), [`SOX4-x-1`](dictionary/by-encoding.md#SOX4-x-1).

**Operation**

```
t ← (register operand) ? Rm : EA(rm)
SP ← SP - 8 ; M[SP] ← address of the next instruction
PC ← t
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

The return address is on the data stack where every unwinder and debugger expects it. `RET` pops it.


### JMPI: Jump and call through memory

**Mnemonics:** `JMPI`, `CALLI`

**Syntax**

```
JMPI rm        ; PC ← M[EA]
CALLI rm       ; push the return address, then PC ← M[EA]
```

**Encoding**

![Encoding of JMPI](figures/SOF-B28-1.svg)

The chart is the leaf `SOF-B28-1`, SOF.B28, prefix `11101110111`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `sub` (4 bits) selects the mnemonic: `clr` 0000, `com` 0001, `inc` 0010, `dec` 0011, `neg` 0100, `tst` 0101, `adc` 0110, `sbc` 0111, `asl` 1000, `asr` 1001, `push` 1010, `pop` 1011, `jmp` 1100, `call` 1101, `jmpi` 1110, `calli` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SOF-B28-1`](dictionary/by-encoding.md#SOF-B28-1), [`SOF-X22-1`](dictionary/by-encoding.md#SOF-X22-1), [`SOF-PI12-1`](dictionary/by-encoding.md#SOF-PI12-1), [`SOF-PD12-1`](dictionary/by-encoding.md#SOF-PD12-1), [`SOF-PC32-1`](dictionary/by-encoding.md#SOF-PC32-1), [`SOF-A32-1`](dictionary/by-encoding.md#SOF-A32-1), [`SOBu12H-x-1`](dictionary/by-encoding.md#SOBu12H-x-1), [`SOBs12-x-1`](dictionary/by-encoding.md#SOBs12-x-1), [`SOX4-x-1`](dictionary/by-encoding.md#SOX4-x-1).

**Operation**

```
JMPI : PC ← M[EA(rm)]
CALLI: t ← M[EA(rm)] ; SP ← SP - 8 ; M[SP] ← address of the next instruction ; PC ← t
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires. For `CALLI` the order is specified: load the target, then push, then transfer; a fault on the load leaves nothing changed.

The one deferred reference the architecture admits, for control transfer only: the PLT stub (`JMPI got_slot(PC)`) and virtual-method dispatch (`CALLI vtbl_off(Robj)`). It needs a memory operand.

**Why it is here.** Exactly one deferred reference, for control transfer only: the PLT stub of every dynamically linked program (`JMPI got_slot(PC)`) and virtual-method dispatch (`CALLI vtbl_off(Robj)`), each two instructions and a scratch register without it. It is admitted because it breaks none of the reasons deferred modes are removed (no register is side-effected, the reference is in the branch path and not the operand path, a fault is clean by ordering). Jump tables through `JMPI` are not smaller than a compare chain, because a table entry is 8 bytes and a case in a compare chain is also 8.

<a id="w-jmpi"></a>
#### JMPI

![JMPI: SOF.B28, prefix 11101110111, sub-opcode 1110; operands b5d28s-x1; 6 bytes](figures/w/jmpi/01.svg)

![JMPI: SOF.X22, prefix 1110101101, sub-opcode 1110; operands x5-5d22s; 6 bytes](figures/w/jmpi/02.svg)

![JMPI: SOF.PC32, prefix 111100000100, sub-opcode 1110; operands pc32-u1; 6 bytes](figures/w/jmpi/05.svg)

![JMPI: SOF.A32, prefix 111100000101, sub-opcode 1110; operands abs32; 6 bytes](figures/w/jmpi/06.svg)

![JMPI: SOF.PI12, prefix 11101111000, sub-opcode 1110; operands pi5-s12; 4 bytes](figures/w/jmpi/03.svg)

![JMPI: SOF.PD12, prefix 11101111001, sub-opcode 1110; operands pd5-s12; 4 bytes](figures/w/jmpi/04.svg)

![JMPI: SOBu12H/x, prefix 11110010011100, sub-opcode 10; operands b4d12u-xsz; 4 bytes](figures/w/jmpi/07.svg)

![JMPI: SOBs12/x, prefix 1111001000001, sub-opcode 10; operands b5d12s-xsz; 4 bytes](figures/w/jmpi/08.svg)

![JMPI: SOX4/x, prefix 11110010110110, sub-opcode 10; operands x5-5d4s; 4 bytes](figures/w/jmpi/09.svg)

```
JMPI rm
```

Operation, flags and exceptions as for the entry JMPI above; 9 layout forms, each a chart of its own (above).

<a id="w-calli"></a>
#### CALLI

![CALLI: SOF.B28, prefix 11101110111, sub-opcode 1111; operands b5d28s-x1; 6 bytes](figures/w/calli/01.svg)

![CALLI: SOF.X22, prefix 1110101101, sub-opcode 1111; operands x5-5d22s; 6 bytes](figures/w/calli/02.svg)

![CALLI: SOF.PC32, prefix 111100000100, sub-opcode 1111; operands pc32-u1; 6 bytes](figures/w/calli/05.svg)

![CALLI: SOF.A32, prefix 111100000101, sub-opcode 1111; operands abs32; 6 bytes](figures/w/calli/06.svg)

![CALLI: SOF.PI12, prefix 11101111000, sub-opcode 1111; operands pi5-s12; 4 bytes](figures/w/calli/03.svg)

![CALLI: SOF.PD12, prefix 11101111001, sub-opcode 1111; operands pd5-s12; 4 bytes](figures/w/calli/04.svg)

![CALLI: SOBu12H/x, prefix 11110010011100, sub-opcode 11; operands b4d12u-xsz; 4 bytes](figures/w/calli/07.svg)

![CALLI: SOBs12/x, prefix 1111001000001, sub-opcode 11; operands b5d12s-xsz; 4 bytes](figures/w/calli/08.svg)

![CALLI: SOX4/x, prefix 11110010110110, sub-opcode 11; operands x5-5d4s; 4 bytes](figures/w/calli/09.svg)

```
CALLI rm
```

Operation, flags and exceptions as for the entry JMPI above; 9 layout forms, each a chart of its own (above).


<a id="w-jtag"></a>
### JTAG: Jump through a tag table

![JTAG: JTAG3, prefix 11110010001111; operands x5-5d22s; 6 bytes](figures/w/jtag/01.svg)

![JTAG: JTAG2, prefix 11110010010000; operands x5-5d6s; 4 bytes](figures/w/jtag/02.svg)

**Mnemonics:** `JTAG`

**Syntax**

```
JTAG d(Rb)(Rx×s)
```

**Encoding**

![Encoding of JTAG](figures/JTAG3-1.svg)

The chart is the leaf `JTAG3-1`, JTAG3, prefix `11110010001111`. `op1` is `x5-5d22s`: memory at base + (index << scale) + signed 22-bit displacement; base register, 5 bits, index register, 5 bits.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`JTAG3-1`](dictionary/by-encoding.md#JTAG3-1), [`JTAG2-1`](dictionary/by-encoding.md#JTAG2-1).

**Operation**

```
PC ← M[Rb + d + 8 × (Rx & 111₂)]
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

Legal only with the scaled-index mode (`0001`). Dispatches on the low three bits of a tagged pointer through a table of eight entries; the 3-bit tag cannot index out of range.

**Why it is here.** The table-dispatch partner of `BTAG`. It is legal only in the scaled-index mode, the one mode with a free register slot for the tagged value. It replaces the PDP-11 dispatch-table idiom `@(Rn)+` better, because it needs no pointer register and cannot index out of range.


<a id="w-movcall"></a>
### MOVCALL: Move a register and call

![MOVCALL: FX.MOVCALL3, prefix 100010; operands reg5, reg5, pc32-u2; 6 bytes](figures/w/movcall/01.svg)

![MOVCALL: FX.MOVCALL2, prefix 100011; operands reg5, reg5, pc16-u2; 4 bytes](figures/w/movcall/02.svg)

**Mnemonics:** `MOVCALL`

**Syntax**

```
MOVCALL Rs, Rd, target
```

**Encoding**

![Encoding of MOVCALL](figures/FX-MOVCALL3-1.svg)

The chart is the leaf `FX-MOVCALL3-1`, FX.MOVCALL3, prefix `100010`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `op3` is `pc32-u2`: pc-relative, 32 bits counted in 2-byte units (-4294967296 to 4294967294 bytes).

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`FX-MOVCALL3-1`](dictionary/by-encoding.md#FX-MOVCALL3-1), [`FX-MOVCALL2-1`](dictionary/by-encoding.md#FX-MOVCALL2-1).

**Operation**

```
Rd ← Rs
SP ← SP - 8 ; M[SP] ← address of the next instruction
PC ← target
```

**Flags** None written.

**Exceptions** The store of the return address can fault (the memory faults of `CALL`): the instruction restarts whole, because the first half reads a register that the second half does not change.

*(D)* One of the four fused pairs of errata 87: `MOVQ Rs, Rd` followed by `CALL target`, in one instruction. The target is a pc-relative field in parcels, measured from the first parcel of the fused instruction (errata 87, assumption 9); the instruction is two parcels (a 16-bit field) or three (a 32-bit field), and the linker grows it from its shortest form like a `CALL` (`docs/relaxation.md`). **The assembler never fuses**: the compiler writes `MOVCALL` where it wants it. An instruction that writes two registers (`Rd` and the stack pointer) and stores to memory is a two-micro-operation instruction for an out-of-order core (errata 87).

**Why it is here.** The author decided the four fused pairs in errata 87 (`movcall`, `popmret`, `popret`, `mov2`) and left the fusing to the compiler: the assembler never fuses. The reason is the measurement of `docs/encoding-proposal.md` section 8 (static size of the training corpus, in the encoding): `MOVQ Rs, Rd` followed by `CALL` occurs 11,123 times, and fusing it alone shrinks the code by 2.39%, the largest of the four; all four together fuse 20,428 pairs and save 3.18% of the bytes and about 1.1% of the executed instructions. The call keeps its reach (four or six bytes). The cost, named in the encoding study: a new mnemonic, and one instruction that writes two registers (the destination and the stack pointer), which is two micro-operations for an out-of-order core. The record gives no earlier machine for this particular pair; the reasoning is the fourth priority of the definitive list (errata 83), fewer instructions executed, where coalescing is good.

**Cf.** 9.5 (the pc-relative operand and the relaxation), 6.4 (restart after a fault).


<a id="w-popret"></a>
### POPRET: Pop a register and return

![POPRET: FX.POPRET, prefix 11101111100; operands reg5; 2 bytes](figures/w/popret/01.svg)

**Mnemonics:** `POPRET`

**Syntax**

```
POPRET Rd
```

**Encoding**

![Encoding of POPRET](figures/FX-POPRET-1.svg)

The chart is the leaf `FX-POPRET-1`, FX.POPRET, prefix `11101111100`. `op1` is `reg5`: register, 5 bits.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`FX-POPRET-1`](dictionary/by-encoding.md#FX-POPRET-1).

**Operation**

```
Rd ← M[SP] ; SP ← SP + 8
PC ← M[SP] ; SP ← SP + 8
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

*(D)* `POP Rd` followed by `RET`, fused (errata 87). The register is the one the function restores last, usually a callee-saved register or the frame pointer. One parcel of 16 bits, with the register in a 5-bit field.

**Why it is here.** The author decided the four fused pairs in errata 87 (`movcall`, `popmret`, `popret`, `mov2`) and left the fusing to the compiler: the assembler never fuses. The reason is the measurement of `docs/encoding-proposal.md` section 8 (static size of the training corpus, in the encoding): `POP Rd` followed by `RET` and `POPM` followed by `RET` (`POPMRET`) occur 4,862 times together and save 1.00% of the bytes; this is the epilogue of nearly every function. The fault of the second half restarts the whole instruction, which is idempotent because the first half reads a register the second does not change and `POPM` is already specified restartable (decision 2 of the encoding study).


<a id="w-popmret"></a>
### POPMRET: Pop several registers and return

![POPMRET: FX.POPMRET, prefix 11010110; operands imm8u-x256; 2 bytes](figures/w/popmret/01.svg)

**Mnemonics:** `POPMRET`

**Syntax**

```
POPMRET #mask
```

**Encoding**

![Encoding of POPMRET](figures/FX-POPMRET-1.svg)

The chart is the leaf `FX-POPMRET-1`, FX.POPMRET, prefix `11010110`. `op1` is `imm8u-x256`: unsigned 8-bit immediate times 256, 0 to 65280.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`FX-POPMRET-1`](dictionary/by-encoding.md#FX-POPMRET-1).

**Operation**

```
for each bit i set in mask, highest register first:
    Ri ← M[SP] ; SP ← SP + 8
PC ← M[SP] ; SP ← SP + 8
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires. A fault after some registers have been popped leaves them popped: the instruction restarts whole and pops them again, which is idempotent because the stack pointer is restored with the rest of the state at the start of the instruction.

*(D)* `POPM #mask` followed by `RET`, fused (errata 87): the epilogue of every function that saved registers with `PUSHM`. The mask is an 8-bit field scaled by 256, so the instruction names `R8` to `R15`; any other set of registers is `POPM` and `RET`. One parcel.

**Why it is here.** See `POPRET`: the two are measured together (4,862 pairs, 1.00% of the bytes). The mask is an 8-bit field scaled by 256 because one parcel has no room for a wider one; the epilogue that restores `R8` to `R15` is the common case the corpus shows, and any other set stays `POPM` and `RET`.
<!-- /entries:9.10 -->

## 9.11 The stack and block operations

*Cf. section 6.4 for restarting a block operation after a fault (progress is held in registers) and section 6.6 for the page faults it can take; section 7.2 for how block operations order their accesses.*

**9.11.1** `PUSH` and `POP` move one register; `PUSHM` and `POPM` move a set named by a mask (a mask of 8 bits is two bytes). A mask containing `R14` is reserved. *(D)*

**9.11.2** `PUSHX` and `POPX` save and restore the exception state `EPSW` and `EPC` in one instruction each; both words are checked before either is accessed, so an abort leaves nothing changed. *(D)*

**9.11.3** The block operations `MCPY`, `MMOV` (overlap-safe), `MSET`, `MCMP`, `MSCN` and `MSCNN` take a destination pointer, a source pointer or value and a count in registers; `MVAL` validates a buffer as UTF-8.

**9.11.4** A block operation keeps its progress in its registers: when it completes, the count is zero and the pointers are one past the end; when it stops early or is interrupted, they point where it stopped, and it restarts by running again. *(D)*

**9.11.5** An implementation may move more than a byte per step, provided the registers are consistent with byte-at-a-time progress wherever an exception can be taken. *(D)*

Open: the worst-case latency of a block operation ([J.9.7](appendix-j-open.md#j97)) and whether the block operations have a form that does not fill the data cache ([J.9.8](appendix-j-open.md#j98)).

*Commentary.* **Precedent.** The VAX's `MOVC5` is the canonical argument against such instructions: its operands could be memory, its architectural definition needed the original values to survive, and so it required hidden state and a first-part-done bit in the status word to resume. The PDP-10 had a block transfer, and x86's `REP MOVS` keeps its progress in registers as the pdp64's do. **Trade-offs.** This is the one admitted exception to the one-memory-operand rule, accepted because its mechanism, hidden state, is absent: the state is the registers, which are already architectural. **Improvements.** ARM reached the same design in 2022 with `FEAT_MOPS`, whose specification says the registers are updated so that progress is not lost. **Benefits.** The block-move sequencer is three counters and a byte-lane selector, about 1,500 transistors. **Modern comparables.** x86 `REP MOVSB` and `REP STOSB` with fast-string microcode; AArch64 `CPYP`/`CPYM`/`CPYE` and `SETP`/`SETM`/`SETE`; s390 `MVC`. **Use.** `memcpy`, `memmove`, `memset`, `memcmp` and `memchr` in the C library; `MVAL` in parsers and kernels. **Impact.** *Kernel:* `PUSHM`, `POPM`, `PUSHX` and `POPX` shorten entry, exit and the context switch, and the block operations are `copyin`, `copyout`, page clearing and `memcpy`. *Compiler:* A prologue and an epilogue are one instruction each, and `memcpy` and `memset` lower to the block operations. *Hardware:* The block-move sequencer is three counters and a byte-lane selector, about 1,500 transistors, with no hidden state.

<!-- entries:9.11 -->
<a id="w-pushm"></a>
### PUSHM: Push registers by mask

![PUSHM: PUSHMF, prefix 111100101110101, sub-opcode 0; operands imm32u; 6 bytes](figures/w/pushm/01.svg)

![PUSHM: PUSHM16b/a, prefix 111100101111100, sub-opcode 0; operands imm16u-x256; 4 bytes](figures/w/pushm/02.svg)

![PUSHM: PUSHM24/a, prefix 1100000, sub-opcode 0; operands imm24u-x256; 4 bytes](figures/w/pushm/04.svg)

![PUSHM: PUSHM8/a, prefix 1011111, sub-opcode 0; operands imm8u-x256; 2 bytes](figures/w/pushm/03.svg)

**Mnemonics:** `PUSHM`

**Syntax**

```
PUSHM #mask        ; a 16-bit immediate, bit n is Rn
```

**Encoding**

![Encoding of PUSHM](figures/PUSHMF-1.svg)

The chart is the leaf `PUSHMF-1`, PUSHMF, prefix `111100101110101`. `op1` is `imm32u`: unsigned 32-bit immediate, 0 to 4294967295. `sub` (1 bit) selects the mnemonic: `pushm` 0, `popm` 1.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`PUSHMF-1`](dictionary/by-encoding.md#PUSHMF-1), [`PUSHM16b-a-1`](dictionary/by-encoding.md#PUSHM16b-a-1), [`PUSHM8-a-1`](dictionary/by-encoding.md#PUSHM8-a-1), [`PUSHM24-a-1`](dictionary/by-encoding.md#PUSHM24-a-1).

**Operation**

```
for n = 0 to 15, if mask bit n:
    SP ← SP - 8 ; M[SP] ← Rn
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires. A mask that includes `R14` (`SP`) is reserved.

The registers are pushed in ascending order, so `POPM` with the same mask restores them. The mask is the low 32 bits of the number (errata 87, assumption 7); the one-parcel form takes an 8-bit mask scaled by 256, which names `R8` to `R15`.

**Why it is here.** The VAX procedure entry mask was the useful half of `CALLS`; `PUSHM` and `POPM` keep that half without the frame (hardware call frames ran slower than the sequence on later VAXes). The one-parcel forms take an 8-bit mask for `R8` to `R15`, because all 2,392 push sites and 2,392 pop sites in the measured corpus use a mask within `R8` to `R15`.

**Cf.** 6.4 for the restart rule.


<a id="w-popm"></a>
### POPM: Pop registers by mask

![POPM: PUSHMF, prefix 111100101110101, sub-opcode 1; operands imm32u; 6 bytes](figures/w/popm/01.svg)

![POPM: PUSHM16b/a, prefix 111100101111100, sub-opcode 1; operands imm16u-x256; 4 bytes](figures/w/popm/02.svg)

![POPM: PUSHM24/a, prefix 1100000, sub-opcode 1; operands imm24u-x256; 4 bytes](figures/w/popm/04.svg)

![POPM: PUSHM8/a, prefix 1011111, sub-opcode 1; operands imm8u-x256; 2 bytes](figures/w/popm/03.svg)

**Mnemonics:** `POPM`

**Syntax**

```
POPM #mask
```

**Encoding**

![Encoding of POPM](figures/PUSHMF-1.svg)

The chart is the leaf `PUSHMF-1`, PUSHMF, prefix `111100101110101`. `op1` is `imm32u`: unsigned 32-bit immediate, 0 to 4294967295. `sub` (1 bit) selects the mnemonic: `pushm` 0, `popm` 1.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`PUSHMF-1`](dictionary/by-encoding.md#PUSHMF-1), [`PUSHM16b-a-1`](dictionary/by-encoding.md#PUSHM16b-a-1), [`PUSHM8-a-1`](dictionary/by-encoding.md#PUSHM8-a-1), [`PUSHM24-a-1`](dictionary/by-encoding.md#PUSHM24-a-1).

**Operation**

```
for n = 15 down to 0, if mask bit n:
    Rn ← M[SP] ; SP ← SP + 8
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

The mirror of `PUSHM`.


<a id="w-push"></a>
### PUSH: Push

![PUSH: SOF.B28, prefix 11101110111, sub-opcode 1010; operands b5d28s-x1; 6 bytes](figures/w/push/01.svg)

![PUSH: SOF.X22, prefix 1110101101, sub-opcode 1010; operands x5-5d22s; 6 bytes](figures/w/push/02.svg)

![PUSH: SOF.PC32, prefix 111100000100, sub-opcode 1010; operands pc32-u1; 6 bytes](figures/w/push/05.svg)

![PUSH: SOF.A32, prefix 111100000101, sub-opcode 1010; operands abs32; 6 bytes](figures/w/push/06.svg)

![PUSH: PUSHI3, prefix 1111001100100011; operands imm32s; 6 bytes](figures/w/push/08.svg)

![PUSH: SOF.PI12, prefix 11101111000, sub-opcode 1010; operands pi5-s12; 4 bytes](figures/w/push/03.svg)

![PUSH: SOF.PD12, prefix 11101111001, sub-opcode 1010; operands pd5-s12; 4 bytes](figures/w/push/04.svg)

![PUSH: PUSHI2, prefix 1111001100100100; operands imm16s; 4 bytes](figures/w/push/09.svg)

![PUSH: SOBu12H/a, prefix 111100101111111, sub-opcode 0; operands b4d12u-xsz; 4 bytes](figures/w/push/10.svg)

![PUSH: SOX4/a, prefix 111100110001011, sub-opcode 0; operands x5-5d4s; 4 bytes](figures/w/push/11.svg)

![PUSH: SOBs12/a, prefix 11110010110000, sub-opcode 0; operands b5d12s-xsz; 4 bytes](figures/w/push/12.svg)

![PUSH: SOPR, prefix 111000011, sub-opcode 10; operands reg5; 2 bytes](figures/w/push/07.svg)

**Mnemonics:** `PUSH`

**Syntax**

```
PUSH rm
```

**Encoding**

![Encoding of PUSH](figures/SOF-B28-1.svg)

The chart is the leaf `SOF-B28-1`, SOF.B28, prefix `11101110111`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `sub` (4 bits) selects the mnemonic: `clr` 0000, `com` 0001, `inc` 0010, `dec` 0011, `neg` 0100, `tst` 0101, `adc` 0110, `sbc` 0111, `asl` 1000, `asr` 1001, `push` 1010, `pop` 1011, `jmp` 1100, `call` 1101, `jmpi` 1110, `calli` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SOF-B28-1`](dictionary/by-encoding.md#SOF-B28-1), [`SOF-X22-1`](dictionary/by-encoding.md#SOF-X22-1), [`SOF-PI12-1`](dictionary/by-encoding.md#SOF-PI12-1), [`SOF-PD12-1`](dictionary/by-encoding.md#SOF-PD12-1), [`SOF-PC32-1`](dictionary/by-encoding.md#SOF-PC32-1), [`SOF-A32-1`](dictionary/by-encoding.md#SOF-A32-1), [`SOPR-2`](dictionary/by-encoding.md#SOPR-2), [`PUSHI3-1`](dictionary/by-encoding.md#PUSHI3-1), [`PUSHI2-1`](dictionary/by-encoding.md#PUSHI2-1), [`SOBu12H-a-2`](dictionary/by-encoding.md#SOBu12H-a-2), [`SOX4-a-2`](dictionary/by-encoding.md#SOX4-a-2), [`SOBs12-a-2`](dictionary/by-encoding.md#SOBs12-a-2).

**Operation**

```
v ← rm ; SP ← SP - 8 ; M[SP] ← v
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.


<a id="w-pop"></a>
### POP: Pop

![POP: SOF.B28, prefix 11101110111, sub-opcode 1011; operands b5d28s-x1; 6 bytes](figures/w/pop/01.svg)

![POP: SOF.X22, prefix 1110101101, sub-opcode 1011; operands x5-5d22s; 6 bytes](figures/w/pop/02.svg)

![POP: SOF.PC32, prefix 111100000100, sub-opcode 1011; operands pc32-u1; 6 bytes](figures/w/pop/05.svg)

![POP: SOF.A32, prefix 111100000101, sub-opcode 1011; operands abs32; 6 bytes](figures/w/pop/06.svg)

![POP: SOF.PI12, prefix 11101111000, sub-opcode 1011; operands pi5-s12; 4 bytes](figures/w/pop/03.svg)

![POP: SOF.PD12, prefix 11101111001, sub-opcode 1011; operands pd5-s12; 4 bytes](figures/w/pop/04.svg)

![POP: SOBu12H/a, prefix 111100101111111, sub-opcode 1; operands b4d12u-xsz; 4 bytes](figures/w/pop/08.svg)

![POP: SOX4/a, prefix 111100110001011, sub-opcode 1; operands x5-5d4s; 4 bytes](figures/w/pop/09.svg)

![POP: SOBs12/a, prefix 11110010110000, sub-opcode 1; operands b5d12s-xsz; 4 bytes](figures/w/pop/10.svg)

![POP: SOPR, prefix 111000011, sub-opcode 11; operands reg5; 2 bytes](figures/w/pop/07.svg)

**Mnemonics:** `POP`

**Syntax**

```
POP rm
```

**Encoding**

![Encoding of POP](figures/SOF-B28-1.svg)

The chart is the leaf `SOF-B28-1`, SOF.B28, prefix `11101110111`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `sub` (4 bits) selects the mnemonic: `clr` 0000, `com` 0001, `inc` 0010, `dec` 0011, `neg` 0100, `tst` 0101, `adc` 0110, `sbc` 0111, `asl` 1000, `asr` 1001, `push` 1010, `pop` 1011, `jmp` 1100, `call` 1101, `jmpi` 1110, `calli` 1111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SOF-B28-1`](dictionary/by-encoding.md#SOF-B28-1), [`SOF-X22-1`](dictionary/by-encoding.md#SOF-X22-1), [`SOF-PI12-1`](dictionary/by-encoding.md#SOF-PI12-1), [`SOF-PD12-1`](dictionary/by-encoding.md#SOF-PD12-1), [`SOF-PC32-1`](dictionary/by-encoding.md#SOF-PC32-1), [`SOF-A32-1`](dictionary/by-encoding.md#SOF-A32-1), [`SOPR-2`](dictionary/by-encoding.md#SOPR-2), [`SOBu12H-a-2`](dictionary/by-encoding.md#SOBu12H-a-2), [`SOX4-a-2`](dictionary/by-encoding.md#SOX4-a-2), [`SOBs12-a-2`](dictionary/by-encoding.md#SOBs12-a-2).

**Operation**

```
v ← M[SP] ; SP ← SP + 8 ; rm ← v
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.


### MCPY: Copy a block of bytes

**Mnemonics:** `MCPY`, `MMOV`

**Syntax**

```
MCPY Rd, Rs, Rn        ; destination pointer, source pointer, count
MMOV Rd, Rs, Rn        ; correct for overlap
```

**Encoding**

![Encoding of MCPY](figures/R3-1.svg)

The chart is the leaf `R3-1`, R3, prefix `1110100001`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `op3` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R3-1`](dictionary/by-encoding.md#R3-1).

**Operation**

```
MCPY:                            ; ascending; overlap is undefined
  while Rn ≠ 0:  M8[Rd] ← M8[Rs] ; Rd ← Rd + 1 ; Rs ← Rs + 1 ; Rn ← Rn - 1
MMOV: as MCPY, but the direction is chosen from the pointers so that an overlapping copy is correct
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires. The three registers are updated as work completes, so a fault leaves a consistent state and the instruction restarts from its registers.

The one granted exception to the one-memory-operand rule. All three registers are architectural state: on completion `Rn` is 0 and `Rd` and `Rs` point one past the end. An implementation may move more than a byte per step, so long as the register state at every point where an exception can be taken is consistent with a byte-at-a-time copy. The accesses made inside one block operation are unordered with respect to each other.

**Why it is here.** The block operations are the one granted exception to the one-memory-operand rule (an exception to a principle is allowed where there is a clear benefit), made safe by keeping the progress in architectural registers: the VAX `MOVC5` kept it in hidden microstate, which is why it is rejected, and ARM reached the same design in 2022 with `FEAT_MOPS`. The names `MCPY`, `MMOV` and `MSET` follow the memory operations of IBM System z; `MCMP` and `MSCN` complete the set. `MCPY` replaces the PDP-11 `MOV (R1)+,(R2)+` loop, and the `rep movsb` of x86, with one restartable instruction.

**Cf.** 6.4 (restart, progress faults); 7.2 (ordering of the accesses).

<a id="w-mcpy"></a>
#### MCPY

![MCPY: R3, prefix 1110100001, sub-opcode 0000100; operands reg5, reg5, reg5; 4 bytes](figures/w/mcpy/01.svg)

```
MCPY Rd, Rs, Rn
```

Operation, flags and exceptions as for the entry MCPY above; 1 layout form, each a chart of its own (above).

<a id="w-mmov"></a>
#### MMOV

![MMOV: R3, prefix 1110100001, sub-opcode 0000101; operands reg5, reg5, reg5; 4 bytes](figures/w/mmov/01.svg)

```
MMOV Rd, Rs, Rn
```

Operation, flags and exceptions as for the entry MCPY above; 1 layout form, each a chart of its own (above).


<a id="w-mset"></a>
### MSET: Fill a block of bytes

![MSET: R3, prefix 1110100001, sub-opcode 0000110; operands reg5, reg5, reg5; 4 bytes](figures/w/mset/01.svg)

**Mnemonics:** `MSET`

**Syntax**

```
MSET Rd, Rv, Rn
```

**Encoding**

![Encoding of MSET](figures/R3-1.svg)

The chart is the leaf `R3-1`, R3, prefix `1110100001`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `op3` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R3-1`](dictionary/by-encoding.md#R3-1).

**Operation**

```
while Rn ≠ 0:  M8[Rd] ← Rv[7:0] ; Rd ← Rd + 1 ; Rn ← Rn - 1
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

`MSET` with `Rv = 0` is the range-zeroing instruction: `bzero` and the clear of `calloc` are one instruction.

**Why it is here.** With a zero value it is the range-zeroing instruction, so `bzero` and the clearing of `calloc` need no separate opcode.

**Cf.** 6.4.


<a id="w-mcmp"></a>
### MCMP: Compare two blocks of bytes

![MCMP: R3, prefix 1110100001, sub-opcode 0000111; operands reg5, reg5, reg5; 4 bytes](figures/w/mcmp/01.svg)

**Mnemonics:** `MCMP`

**Syntax**

```
MCMP Rd, Rs, Rn
```

**Encoding**

![Encoding of MCMP](figures/R3-1.svg)

The chart is the leaf `R3-1`, R3, prefix `1110100001`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `op3` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R3-1`](dictionary/by-encoding.md#R3-1).

**Operation**

```
while Rn ≠ 0:
    x ← M8[Rd] ; y ← M8[Rs]
    if x ≠ y then  flags ← flags of (x - y) ; stop      ; pointers left AT the differing byte
    Rd ← Rd + 1 ; Rs ← Rs + 1 ; Rn ← Rn - 1
if equal:  N = 0, Z = 1, V = 0, C = 0
```

**Flags** From the first differing byte as for `CMP` of the two bytes (`C` set if `x < y` unsigned, `N` and `V` from the signed difference); for equal blocks `N` = 0, `Z` = 1, `V` = 0, `C` = 0.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

When the instruction stops at a difference, `Rd` and `Rs` point at the differing bytes and `Rn` is the count remaining, so the position of the difference is in the registers.

**Why it is here.** Seven of the VAX's ten character-string instructions are present (`MOVC3`, `CMPC3`, `LOCC` and `SKPC` among them); the rejected ones are `EDITPC` and packed decimal. `MCMP` is the `CMPC3` equivalent.

**Cf.** 6.4.


### MSCN: Scan a block for a byte, or for a byte not equal to it

**Mnemonics:** `MSCN`, `MSCNN`

**Syntax**

```
MSCN Rd, Rv, Rn
MSCNN Rd, Rv, Rn
```

**Encoding**

![Encoding of MSCN](figures/R3-1.svg)

The chart is the leaf `R3-1`, R3, prefix `1110100001`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `op3` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R3-1`](dictionary/by-encoding.md#R3-1).

**Operation**

```
while Rn ≠ 0:
    hit ← (M8[Rd] = Rv[7:0])             ; MSCNN: hit ← (M8[Rd] ≠ Rv[7:0])
    if hit then  Z = 1 ; stop              ; Rd points AT the byte found
    Rd ← Rd + 1 ; Rn ← Rn - 1
not found: Z = 0
```

**Flags** **All four flags are written**: `Z` = 1 if the byte was found, else 0; `N`, `V` and `C` are cleared.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

`MSCN` is `memchr`; with an explicit count it gives `strnlen`, and composing it with `MCPY` gives a bounded `strcpy` in two instructions. There are no NUL-terminated string instructions.

**Why it is here.** `MSCN` is `LOCC` and `memchr`; `MSCNN` fills the `SKPC` gap (the first byte that is *not* equal). Both cost almost no hardware. With an explicit count `MSCN` gives `strnlen`, and with `MCPY` a bounded `strcpy` in two instructions. NUL-terminated string instructions (the System/z `MVST`, `SRST`, `CLST`) are rejected, because they encode an unbounded read, the largest single source of memory-safety failures in C (9.17).

**Cf.** 6.4.

<a id="w-mscn"></a>
#### MSCN

![MSCN: R3, prefix 1110100001, sub-opcode 0001000; operands reg5, reg5, reg5; 4 bytes](figures/w/mscn/01.svg)

```
MSCN Rd, Rv, Rn
```

Operation, flags and exceptions as for the entry MSCN above; 1 layout form, each a chart of its own (above).

<a id="w-mscnn"></a>
#### MSCNN

![MSCNN: R3, prefix 1110100001, sub-opcode 0001001; operands reg5, reg5, reg5; 4 bytes](figures/w/mscnn/01.svg)

```
MSCNN Rd, Rv, Rn
```

Operation, flags and exceptions as for the entry MSCN above; 1 layout form, each a chart of its own (above).


<a id="w-mval"></a>
### MVAL: Validate a block as UTF-8

![MVAL: R2, prefix 111100000010, sub-opcode 0000001100; operands reg5, reg5; 4 bytes](figures/w/mval/01.svg)

**Mnemonics:** `MVAL`

**Syntax**

```
MVAL Rd, Rn
```

**Encoding**

![Encoding of MVAL](figures/R2-1.svg)

The chart is the leaf `R2-1`, R2, prefix `111100000010`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R2-1`](dictionary/by-encoding.md#R2-1).

**Operation**

```
scan Rn bytes at Rd; stop at the first byte that cannot be part of a valid UTF-8 sequence (the rules of UTF8DEC)
```

**Flags** On completion `Rn` is 0 and the buffer is valid; otherwise `Rd` points at the offending sequence and `Rn` counts the bytes remaining (details in the instruction-set text, section 4.7.1).

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

The `UTF8DEC` comparators wired to the block sequencer.

**Why it is here.** The UTF-8 validity comparators already built for `UTF8DEC`, wired to the streaming sequencer already built for `MCPY`, so it costs almost no hardware. The alternative, a SWAR loop (SIMD within a register), runs at about two to three cycles a byte and is respectable, which is why the justification is cost and not throughput.

**Cf.** 6.4.
<!-- /entries:9.11 -->

## 9.12 Floating point

**9.12.1** Floating point uses the general registers: a `binary64` value fills one register, and the instruction, not the register, decides how its bits are read. *(D)*

**9.12.2** `FADD`, `FSUB`, `FMUL` and `FCMP` are two-byte instructions; `FDIV`, `FSQRT`, the fused multiply-add family, `FABS`, `FMIN`, `FMAX`, `FCLASS`, the roundings and the `binary32` forms are in the floating-point escape; `binary16` has seventeen operations and conversions. *(D)*

**9.12.3** The five IEEE flags (invalid, divide by zero, overflow, underflow, inexact) accumulate in `FPSR`; no floating-point operation traps; `FSFLAGS` reads and clears them. *(D)*

**9.12.4** Every NaN that an operation creates is the canonical quiet NaN. *(D)*

**9.12.5** There are no rounding-mode or precision mode bits: the precision is in the opcode, and so is the rounding mode wherever it is not nearest-even. *(D)*

**9.12.6** There are no transcendental instructions. *(D)*

Open: how a floating-point comparison sets flags that the signed branches can use ([J.9.9](appendix-j-open.md#j99)), and directed rounding and the remaining half-precision operations ([J.9.10](appendix-j-open.md#j910)).

*Commentary.* **Precedent.** The PDP-11's FP11 had `AC0` to `AC5` and mode bits for single and double precision; the VAX had F, D, G and H formats. **Trade-offs.** An integer operation applied to a register holding a `binary64` destroys it, with no trap and no tag; that is intended and the ABI states it. A separate register file would cost a second set of read ports and a floating-point context; on a small implementation the register file is among the largest blocks. **Improvements.** The fused multiply-add is the largest single addition to the datapath (about 9,000 transistors) and the least negotiable; the IEEE exception flags are recorded without traps, which is what C99 `<fenv.h>` needs. **Benefits.** No transfer instructions between files and a single calling convention. **Modern comparables.** RISC-V Zfinx and Zdinx use the integer register file for the same reason; AArch64 and x86 have separate vector and floating-point files. **Use.** `FCLASS` begins every library maths function; `FMA` is the building block of accurate polynomial evaluation. **Impact.** *Kernel:* There is no separate floating-point state to save at a context switch beyond the registers already saved, and the sticky flags go with the status word. *Compiler:* One calling convention for integers and floats, fused multiply-add contraction, and no rounding-mode state for the compiler to track. *Hardware:* No second register file (one of the largest blocks of a small floating-point unit); the floating-point unit with fused multiply-add is about 34,000 transistors.

<!-- entries:9.12 -->
### FADD: Floating add, subtract and multiply, binary64

**Mnemonics:** `FADD`, `FSUB`, `FMUL`  (aliases: `FADDD`, `FSUBD`, `FMULD`)

**Syntax**

```
FADD rm, Rd
FSUB rm, Rd
FMUL rm, Rd
```

**Encoding**

![Encoding of FADD](figures/LDF-B28-2.svg)

The chart is the leaf `LDF-B28-2`, LDF.B28, prefix `1010001`. `op1` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `op2` is `reg5`: register, 5 bits. `sub` (3 bits) selects the mnemonic: `shr` 000, `sar` 001, `fadd` 010, `fsub` 011, `fmul` 100, `bit` 101, `lea` 110, `movub` 111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`LDF-B28-2`](dictionary/by-encoding.md#LDF-B28-2), [`LDF-X22-2`](dictionary/by-encoding.md#LDF-X22-2), [`LDF-PI12-2`](dictionary/by-encoding.md#LDF-PI12-2), [`LDF-PD12-2`](dictionary/by-encoding.md#LDF-PD12-2), [`LDF-PC32-2`](dictionary/by-encoding.md#LDF-PC32-2), [`LDF-A32-2`](dictionary/by-encoding.md#LDF-A32-2), [`LDFI-I32-1`](dictionary/by-encoding.md#LDFI-I32-1), [`DPF-D28-2`](dictionary/by-encoding.md#DPF-D28-2), [`RRF-2`](dictionary/by-encoding.md#RRF-2), [`RRF5-1`](dictionary/by-encoding.md#RRF5-1), [`LDPC12H-d-1`](dictionary/by-encoding.md#LDPC12H-d-1), [`LDPC12H-d-2`](dictionary/by-encoding.md#LDPC12H-d-2).

**Operation**

```
Rd ← Rd + rm   (FADD)
Rd ← Rd - rm   (FSUB)
Rd ← Rd × rm   (FMUL)       ; IEEE 754 binary64, round to nearest even
```

**Flags** None written. The five IEEE exception flags are ORed into `FPSR`; no instruction traps.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires. Floating-point exceptions never trap.

Floating-point values live in the general registers; there is no separate register file and no mode bit. A NaN result is the canonical quiet NaN `0x7FF8000000000000`. The alternative spellings `FADDD`, `FSUBD`, `FMULD` are aliases.

<a id="w-fadd"></a>
#### FADD

![FADD: LDF.B28, prefix 1010001, sub-opcode 010; operands b5d28s-x1, reg5; 6 bytes](figures/w/fadd/01.svg)

![FADD: LDF.X22, prefix 011110, sub-opcode 010; operands x5-5d22s, reg5; 6 bytes](figures/w/fadd/02.svg)

![FADD: LDF.PC32, prefix 11001100, sub-opcode 010; operands pc32-u1, reg5; 6 bytes](figures/w/fadd/05.svg)

![FADD: LDF.A32, prefix 11001101, sub-opcode 010; operands abs32, reg5; 6 bytes](figures/w/fadd/06.svg)

![FADD: LDFI.I32, prefix 1010110, sub-opcode 1011; operands imm32s, reg5; 6 bytes](figures/w/fadd/07.svg)

![FADD: DPF.D28, prefix 111100000110, sub-opcode 010; operands dpd28s-x1, reg5; 6 bytes](figures/w/fadd/08.svg)

![FADD: LDF.PI12, prefix 1010010, sub-opcode 010; operands pi5-s12, reg5; 4 bytes](figures/w/fadd/03.svg)

![FADD: LDF.PD12, prefix 1010011, sub-opcode 010; operands pd5-s12, reg5; 4 bytes](figures/w/fadd/04.svg)

![FADD: RRF5, prefix 1111001100100101, sub-opcode 010010; operands reg5, reg5; 4 bytes](figures/w/fadd/10.svg)

![FADD: LDPC12H/d, prefix 1111001000010, sub-opcode 110; operands pc12-u1, reg4; 4 bytes](figures/w/fadd/11.svg)

![FADD: RRF, prefix 01010, sub-opcode 010; operands reg4, reg4; 2 bytes](figures/w/fadd/09.svg)

```
FADD rm, Rd
```

Operation, flags and exceptions as for the entry FADD above; 11 layout forms, each a chart of its own (above).

<a id="w-fsub"></a>
#### FSUB

![FSUB: LDF.B28, prefix 1010001, sub-opcode 011; operands b5d28s-x1, reg5; 6 bytes](figures/w/fsub/01.svg)

![FSUB: LDF.X22, prefix 011110, sub-opcode 011; operands x5-5d22s, reg5; 6 bytes](figures/w/fsub/02.svg)

![FSUB: LDF.PC32, prefix 11001100, sub-opcode 011; operands pc32-u1, reg5; 6 bytes](figures/w/fsub/05.svg)

![FSUB: LDF.A32, prefix 11001101, sub-opcode 011; operands abs32, reg5; 6 bytes](figures/w/fsub/06.svg)

![FSUB: LDFI.I32, prefix 1010110, sub-opcode 1100; operands imm32s, reg5; 6 bytes](figures/w/fsub/07.svg)

![FSUB: DPF.D28, prefix 111100000110, sub-opcode 011; operands dpd28s-x1, reg5; 6 bytes](figures/w/fsub/08.svg)

![FSUB: LDF.PI12, prefix 1010010, sub-opcode 011; operands pi5-s12, reg5; 4 bytes](figures/w/fsub/03.svg)

![FSUB: LDF.PD12, prefix 1010011, sub-opcode 011; operands pd5-s12, reg5; 4 bytes](figures/w/fsub/04.svg)

![FSUB: RRF5, prefix 1111001100100101, sub-opcode 010011; operands reg5, reg5; 4 bytes](figures/w/fsub/10.svg)

![FSUB: LDPC12H/d, prefix 1111001000010, sub-opcode 111; operands pc12-u1, reg4; 4 bytes](figures/w/fsub/11.svg)

![FSUB: RRF, prefix 01010, sub-opcode 011; operands reg4, reg4; 2 bytes](figures/w/fsub/09.svg)

```
FSUB rm, Rd
```

Operation, flags and exceptions as for the entry FADD above; 11 layout forms, each a chart of its own (above).

<a id="w-fmul"></a>
#### FMUL

![FMUL: LDF.B28, prefix 1010001, sub-opcode 100; operands b5d28s-x1, reg5; 6 bytes](figures/w/fmul/01.svg)

![FMUL: LDF.X22, prefix 011110, sub-opcode 100; operands x5-5d22s, reg5; 6 bytes](figures/w/fmul/02.svg)

![FMUL: LDF.PC32, prefix 11001100, sub-opcode 100; operands pc32-u1, reg5; 6 bytes](figures/w/fmul/05.svg)

![FMUL: LDF.A32, prefix 11001101, sub-opcode 100; operands abs32, reg5; 6 bytes](figures/w/fmul/06.svg)

![FMUL: LDFI.I32, prefix 1010110, sub-opcode 1101; operands imm32s, reg5; 6 bytes](figures/w/fmul/07.svg)

![FMUL: DPF.D28, prefix 111100000110, sub-opcode 100; operands dpd28s-x1, reg5; 6 bytes](figures/w/fmul/08.svg)

![FMUL: LDF.PI12, prefix 1010010, sub-opcode 100; operands pi5-s12, reg5; 4 bytes](figures/w/fmul/03.svg)

![FMUL: LDF.PD12, prefix 1010011, sub-opcode 100; operands pd5-s12, reg5; 4 bytes](figures/w/fmul/04.svg)

![FMUL: RRF5, prefix 1111001100100101, sub-opcode 010100; operands reg5, reg5; 4 bytes](figures/w/fmul/10.svg)

![FMUL: LDPC12H/d, prefix 111100110001110, sub-opcode 0; operands pc12-u1, reg4; 4 bytes](figures/w/fmul/11.svg)

![FMUL: RRF, prefix 01010, sub-opcode 100; operands reg4, reg4; 2 bytes](figures/w/fmul/09.svg)

```
FMUL rm, Rd
```

Operation, flags and exceptions as for the entry FADD above; 11 layout forms, each a chart of its own (above).

<a id="w-faddd"></a>
#### FADDD

An alias of [`FADD`](#w-fadd): the assembler writes it as that word.

<a id="w-fsubd"></a>
#### FSUBD

An alias of [`FSUB`](#w-fsub): the assembler writes it as that word.

<a id="w-fmuld"></a>
#### FMULD

An alias of [`FMUL`](#w-fmul): the assembler writes it as that word.


<a id="w-fcmp"></a>
<a id="w-fcmpd"></a>
### FCMP: Floating compare, binary64

![FCMP: CMF.B28, prefix 111000000, sub-opcode 1; operands reg5, b5d28s-x1; 6 bytes](figures/w/fcmp/01.svg)

![FCMP: CMF.X22, prefix 11010011, sub-opcode 1; operands reg5, x5-5d22s; 6 bytes](figures/w/fcmp/02.svg)

![FCMP: CMF.PC32, prefix 1110101010, sub-opcode 1; operands reg5, pc32-u1; 6 bytes](figures/w/fcmp/05.svg)

![FCMP: CMF.A32, prefix 1110101011, sub-opcode 1; operands reg5, abs32; 6 bytes](figures/w/fcmp/06.svg)

![FCMP: CMF.I32, prefix 1110101100, sub-opcode 1; operands reg5, imm32s; 6 bytes](figures/w/fcmp/07.svg)

![FCMP: CMF.PI12, prefix 111000001, sub-opcode 1; operands reg5, pi5-s12; 4 bytes](figures/w/fcmp/03.svg)

![FCMP: CMF.PD12, prefix 111000010, sub-opcode 1; operands reg5, pd5-s12; 4 bytes](figures/w/fcmp/04.svg)

![FCMP: RRF5, prefix 1111001100100101, sub-opcode 010111; operands reg5, reg5; 4 bytes](figures/w/fcmp/09.svg)

![FCMP: RRF, prefix 01010, sub-opcode 111; operands reg4, reg4; 2 bytes](figures/w/fcmp/08.svg)

**Mnemonics:** `FCMP`  (aliases: `FCMPD`)

**Syntax**

```
FCMP Rd, rm        ; register first
```

**Encoding**

![Encoding of FCMP](figures/CMF-B28-1.svg)

The chart is the leaf `CMF-B28-1`, CMF.B28, prefix `111000000`. `op1` is `reg5`: register, 5 bits. `op2` is `b5d28s-x1`: memory at base register, 5 bits + signed 28-bit displacement times 1, -134217728 to 134217727 bytes. `sub` (1 bit) selects the mnemonic: `cmp` 0, `fcmp` 1.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`CMF-B28-1`](dictionary/by-encoding.md#CMF-B28-1), [`CMF-X22-1`](dictionary/by-encoding.md#CMF-X22-1), [`CMF-PI12-1`](dictionary/by-encoding.md#CMF-PI12-1), [`CMF-PD12-1`](dictionary/by-encoding.md#CMF-PD12-1), [`CMF-PC32-1`](dictionary/by-encoding.md#CMF-PC32-1), [`CMF-A32-1`](dictionary/by-encoding.md#CMF-A32-1), [`CMF-I32-1`](dictionary/by-encoding.md#CMF-I32-1), [`RRF-2`](dictionary/by-encoding.md#RRF-2), [`RRF5-1`](dictionary/by-encoding.md#RRF5-1).

**Operation**

```
N ← Rd < rm ; Z ← Rd = rm ; V ← unordered ; C ← 0
```

**Flags** `N` set if `Rd < rm`, `Z` if equal, `V` if the operands are unordered (either is a NaN), `C` cleared. A signalling NaN raises `NV` in `FPSR`.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

The signed branches do not treat the unordered case cleanly (`BLT` after an unordered compare takes `N xor V` = 1). Open: how floating-point comparisons set flags that the signed branches can use ([J.9.9](appendix-j-open.md#j99)).

<a id="w-fcmpd"></a>
**`FCMPD`** is an alias of `FCMP`: the assembler writes it as that word.


### FDIV: Floating divide and square root, binary64

**Mnemonics:** `FDIV`, `FSQRT`  (aliases: `FDIVD`, `FSQRTD`)

**Syntax**

```
FDIV Rs, Rd
FSQRT Rs, Rd
```

**Encoding**

![Encoding of FDIV](figures/R2-1.svg)

The chart is the leaf `R2-1`, R2, prefix `111100000010`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R2-1`](dictionary/by-encoding.md#R2-1).

**Operation**

```
FDIV : Rd ← Rd ÷ Rs
FSQRT: Rd ← sqrt(Rs)
```

**Flags** No integer flag is written. The IEEE exception flags raised are ORed into `FPSR` (`NX` inexact, `UF` underflow, `OF` overflow, `DZ` divide by zero, `NV` invalid); nothing traps.

**Exceptions** None.

`FDIV` and `FSQRT` are multi-cycle sequencer operations and rarely appear in a one-parcel form. The alternative spellings `FDIVD`, `FSQRTD` are aliases.

<a id="w-fdiv"></a>
#### FDIV

![FDIV: R2, prefix 111100000010, sub-opcode 0000010000; operands reg5, reg5; 4 bytes](figures/w/fdiv/01.svg)

```
FDIV Rs, Rd
```

Operation, flags and exceptions as for the entry FDIV above; 1 layout form, each a chart of its own (above).

<a id="w-fsqrt"></a>
#### FSQRT

![FSQRT: R2, prefix 111100000010, sub-opcode 0000010001; operands reg5, reg5; 4 bytes](figures/w/fsqrt/01.svg)

```
FSQRT Rs, Rd
```

Operation, flags and exceptions as for the entry FDIV above; 1 layout form, each a chart of its own (above).

<a id="w-fdivd"></a>
#### FDIVD

An alias of [`FDIV`](#w-fdiv): the assembler writes it as that word.

<a id="w-fsqrtd"></a>
#### FSQRTD

An alias of [`FSQRT`](#w-fsqrt): the assembler writes it as that word.


### FSINGLE: Floating arithmetic, binary32

**Mnemonics:** `FADD32`, `FSUB32`, `FMUL32`, `FDIV32`, `FSQRT32`, `FCMP32`  (aliases: `FADDS`, `FSUBS`, `FMULS`, `FDIVS`, `FSQRTS`, `FCMPS`)

**Syntax**

```
FADD32 Rs, Rd
FSUB32 Rs, Rd
FMUL32 Rs, Rd
FDIV32 Rs, Rd
FSQRT32 Rs, Rd
FCMP32 Rd, Rs
```

**Encoding**

![Encoding of FSINGLE](figures/R2-1.svg)

The chart is the leaf `R2-1`, R2, prefix `111100000010`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R2-1`](dictionary/by-encoding.md#R2-1).

**Operation**

```
Rd ← Rd op Rs  (FADD32 FSUB32 FMUL32 FDIV32); Rd ← sqrt(Rs) (FSQRT32)
FCMP32: flags as FCMP, comparing Rd with Rs
```

**Flags** No integer flag is written. The IEEE exception flags raised are ORed into `FPSR` (`NX` inexact, `UF` underflow, `OF` overflow, `DZ` divide by zero, `NV` invalid); nothing traps. `FCMP32` writes `N Z V C` as `FCMP` does.

**Exceptions** None.

A `binary32` lives in the low 32 bits of a register, sign-extended to 64 like every 32-bit result. Results are correctly rounded to nearest even. The alternative spellings `FADDS`, `FSUBS`, ... are aliases.

**Why it is here.** `binary64` has first-class opcodes because on a 64-bit machine it is the common case; `binary32` has the same operations, held in the low 32 bits of a register and sign-extended like every other 32-bit value (see also the ABI). The naming rule is an `F` in front of the integer mnemonic (`FADD`) and a size suffix for the other formats (`FADD16`); the older spellings (`FADDS` and so on) are aliases.

<a id="w-fadd32"></a>
#### FADD32

![FADD32: R2, prefix 111100000010, sub-opcode 0000010010; operands reg5, reg5; 4 bytes](figures/w/fadd32/01.svg)

```
FADD32 Rs, Rd
```

Operation, flags and exceptions as for the entry FSINGLE above; 1 layout form, each a chart of its own (above).

<a id="w-fsub32"></a>
#### FSUB32

![FSUB32: R2, prefix 111100000010, sub-opcode 0000010011; operands reg5, reg5; 4 bytes](figures/w/fsub32/01.svg)

```
FSUB32 Rs, Rd
```

Operation, flags and exceptions as for the entry FSINGLE above; 1 layout form, each a chart of its own (above).

<a id="w-fmul32"></a>
#### FMUL32

![FMUL32: R2, prefix 111100000010, sub-opcode 0000010100; operands reg5, reg5; 4 bytes](figures/w/fmul32/01.svg)

```
FMUL32 Rs, Rd
```

Operation, flags and exceptions as for the entry FSINGLE above; 1 layout form, each a chart of its own (above).

<a id="w-fdiv32"></a>
#### FDIV32

![FDIV32: R2, prefix 111100000010, sub-opcode 0000010101; operands reg5, reg5; 4 bytes](figures/w/fdiv32/01.svg)

```
FDIV32 Rs, Rd
```

Operation, flags and exceptions as for the entry FSINGLE above; 1 layout form, each a chart of its own (above).

<a id="w-fsqrt32"></a>
#### FSQRT32

![FSQRT32: R2, prefix 111100000010, sub-opcode 0000010110; operands reg5, reg5; 4 bytes](figures/w/fsqrt32/01.svg)

```
FSQRT32 Rs, Rd
```

Operation, flags and exceptions as for the entry FSINGLE above; 1 layout form, each a chart of its own (above).

<a id="w-fcmp32"></a>
#### FCMP32

![FCMP32: R2, prefix 111100000010, sub-opcode 0000010111; operands reg5, reg5; 4 bytes](figures/w/fcmp32/01.svg)

```
FCMP32 Rd, Rs
```

Operation, flags and exceptions as for the entry FSINGLE above; 1 layout form, each a chart of its own (above).

<a id="w-fadds"></a>
#### FADDS

An alias of [`FADD32`](#w-fadd32): the assembler writes it as that word.

<a id="w-fsubs"></a>
#### FSUBS

An alias of [`FSUB32`](#w-fsub32): the assembler writes it as that word.

<a id="w-fmuls"></a>
#### FMULS

An alias of [`FMUL32`](#w-fmul32): the assembler writes it as that word.

<a id="w-fdivs"></a>
#### FDIVS

An alias of [`FDIV32`](#w-fdiv32): the assembler writes it as that word.

<a id="w-fsqrts"></a>
#### FSQRTS

An alias of [`FSQRT32`](#w-fsqrt32): the assembler writes it as that word.

<a id="w-fcmps"></a>
#### FCMPS

An alias of [`FCMP32`](#w-fcmp32): the assembler writes it as that word.


### FMADD: Fused multiply-add, binary64

**Mnemonics:** `FMADD`, `FMSUB`, `FNMADD`, `FNMSUB`  (aliases: `FMADDD`, `FMSUBD`, `FNMADDD`, `FNMSUBD`)

**Syntax**

```
FMADD Rs, Rt, Ru, Rd
FMSUB Rs, Rt, Ru, Rd
FNMADD Rs, Rt, Ru, Rd
FNMSUB Rs, Rt, Ru, Rd
```

**Encoding**

![Encoding of FMADD](figures/R4-1.svg)

The chart is the leaf `R4-1`, R4, prefix `11000101`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `op3` is `reg5`: register, 5 bits. `op4` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R4-1`](dictionary/by-encoding.md#R4-1).

**Operation**

```
FMADD : Rd ← Rs×Rt + Ru
FMSUB : Rd ← Rs×Rt - Ru
FNMADD: Rd ← -(Rs×Rt) - Ru
FNMSUB: Rd ← -(Rs×Rt) + Ru          ; each rounded once
```

**Flags** No integer flag is written. The IEEE exception flags raised are ORed into `FPSR` (`NX` inexact, `UF` underflow, `OF` overflow, `DZ` divide by zero, `NV` invalid); nothing traps.

**Exceptions** None.

The alternative spellings `FMADDD`, ... are aliases.

**Why it is here.** The whole fused multiply-add family is in the instruction set because its absence would be the single worst gap in the floating-point set: one rounding instead of two, and the inner step of dot products, polynomial evaluation and every matrix kernel. It has four register operands. It replaces the VAX `POLY`, which was the best answer before fused multiply-add.

<a id="w-fmadd"></a>
#### FMADD

![FMADD: R4, prefix 11000101, sub-opcode 0000; operands reg5, reg5, reg5, reg5; 4 bytes](figures/w/fmadd/01.svg)

```
FMADD Rs, Rt, Ru, Rd
```

Operation, flags and exceptions as for the entry FMADD above; 1 layout form, each a chart of its own (above).

<a id="w-fmsub"></a>
#### FMSUB

![FMSUB: R4, prefix 11000101, sub-opcode 0001; operands reg5, reg5, reg5, reg5; 4 bytes](figures/w/fmsub/01.svg)

```
FMSUB Rs, Rt, Ru, Rd
```

Operation, flags and exceptions as for the entry FMADD above; 1 layout form, each a chart of its own (above).

<a id="w-fnmadd"></a>
#### FNMADD

![FNMADD: R4, prefix 11000101, sub-opcode 0010; operands reg5, reg5, reg5, reg5; 4 bytes](figures/w/fnmadd/01.svg)

```
FNMADD Rs, Rt, Ru, Rd
```

Operation, flags and exceptions as for the entry FMADD above; 1 layout form, each a chart of its own (above).

<a id="w-fnmsub"></a>
#### FNMSUB

![FNMSUB: R4, prefix 11000101, sub-opcode 0011; operands reg5, reg5, reg5, reg5; 4 bytes](figures/w/fnmsub/01.svg)

```
FNMSUB Rs, Rt, Ru, Rd
```

Operation, flags and exceptions as for the entry FMADD above; 1 layout form, each a chart of its own (above).

<a id="w-fmaddd"></a>
#### FMADDD

An alias of [`FMADD`](#w-fmadd): the assembler writes it as that word.

<a id="w-fmsubd"></a>
#### FMSUBD

An alias of [`FMSUB`](#w-fmsub): the assembler writes it as that word.

<a id="w-fnmaddd"></a>
#### FNMADDD

An alias of [`FNMADD`](#w-fnmadd): the assembler writes it as that word.

<a id="w-fnmsubd"></a>
#### FNMSUBD

An alias of [`FNMSUB`](#w-fnmsub): the assembler writes it as that word.


### FMADD32: Fused multiply-add, binary32

**Mnemonics:** `FMADD32`, `FMSUB32`, `FNMADD32`, `FNMSUB32`  (aliases: `FMADDS`, `FMSUBS`, `FNMADDS`, `FNMSUBS`)

**Syntax**

```
FMADD32 Rs, Rt, Ru, Rd
FMSUB32 ...
FNMADD32 ...
FNMSUB32 ...
```

**Encoding**

![Encoding of FMADD32](figures/R4-1.svg)

The chart is the leaf `R4-1`, R4, prefix `11000101`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `op3` is `reg5`: register, 5 bits. `op4` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R4-1`](dictionary/by-encoding.md#R4-1).

**Operation**

```
As FMADD, in binary32, rounded once
```

**Flags** No integer flag is written. The IEEE exception flags raised are ORed into `FPSR` (`NX` inexact, `UF` underflow, `OF` overflow, `DZ` divide by zero, `NV` invalid); nothing traps.

**Exceptions** None.

**Why it is here.** The `binary32` forms of the fused multiply-add family.

<a id="w-fmadd32"></a>
#### FMADD32

![FMADD32: R4, prefix 11000101, sub-opcode 0100; operands reg5, reg5, reg5, reg5; 4 bytes](figures/w/fmadd32/01.svg)

```
FMADD32 Rs, Rt, Ru, Rd
```

Operation, flags and exceptions as for the entry FMADD32 above; 1 layout form, each a chart of its own (above).

<a id="w-fmsub32"></a>
#### FMSUB32

![FMSUB32: R4, prefix 11000101, sub-opcode 0101; operands reg5, reg5, reg5, reg5; 4 bytes](figures/w/fmsub32/01.svg)

```
FMSUB32 ...
```

Operation, flags and exceptions as for the entry FMADD32 above; 1 layout form, each a chart of its own (above).

<a id="w-fnmadd32"></a>
#### FNMADD32

![FNMADD32: R4, prefix 11000101, sub-opcode 0110; operands reg5, reg5, reg5, reg5; 4 bytes](figures/w/fnmadd32/01.svg)

```
FNMADD32 ...
```

Operation, flags and exceptions as for the entry FMADD32 above; 1 layout form, each a chart of its own (above).

<a id="w-fnmsub32"></a>
#### FNMSUB32

![FNMSUB32: R4, prefix 11000101, sub-opcode 0111; operands reg5, reg5, reg5, reg5; 4 bytes](figures/w/fnmsub32/01.svg)

```
FNMSUB32 ...
```

Operation, flags and exceptions as for the entry FMADD32 above; 1 layout form, each a chart of its own (above).

<a id="w-fmadds"></a>
#### FMADDS

An alias of [`FMADD32`](#w-fmadd32): the assembler writes it as that word.

<a id="w-fmsubs"></a>
#### FMSUBS

An alias of [`FMSUB32`](#w-fmsub32): the assembler writes it as that word.

<a id="w-fnmadds"></a>
#### FNMADDS

An alias of [`FNMADD32`](#w-fnmadd32): the assembler writes it as that word.

<a id="w-fnmsubs"></a>
#### FNMSUBS

An alias of [`FNMSUB32`](#w-fnmsub32): the assembler writes it as that word.


### FSIGN: Sign operations on the bits

**Mnemonics:** `FNEG`, `FABS`, `FCOPYSIGN`

**Syntax**

```
FNEG Rs, Rd
FABS Rs, Rd
FCOPYSIGN Rs, Rt, Rd
```

**Encoding**

![Encoding of FSIGN](figures/R2-1.svg)

The chart is the leaf `R2-1`, R2, prefix `111100000010`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R2-1`](dictionary/by-encoding.md#R2-1), [`R3-1`](dictionary/by-encoding.md#R3-1).

**Operation**

```
FNEG     : Rd ← Rs with the sign bit flipped
FABS     : Rd ← Rs with the sign bit cleared
FCOPYSIGN: Rd ← magnitude of Rs, sign of Rt
```

**Flags** None. These operate on the bits, do not canonicalise a NaN and raise no exception flag.

**Exceptions** None.

**Why it is here.** Sign and selection operations (negate, absolute value and the like) work on the bits, do not canonicalise a NaN and raise no flag, so they cost almost nothing. The PowerPC 601 floating-point set has the same operations (stated from memory, not checked against a manual). No separate reason is recorded for these three.

<a id="w-fneg"></a>
#### FNEG

![FNEG: R2, prefix 111100000010, sub-opcode 0000011000; operands reg5, reg5; 4 bytes](figures/w/fneg/01.svg)

```
FNEG Rs, Rd
```

Operation, flags and exceptions as for the entry FSIGN above; 1 layout form, each a chart of its own (above).

<a id="w-fabs"></a>
#### FABS

![FABS: R2, prefix 111100000010, sub-opcode 0000011001; operands reg5, reg5; 4 bytes](figures/w/fabs/01.svg)

```
FABS Rs, Rd
```

Operation, flags and exceptions as for the entry FSIGN above; 1 layout form, each a chart of its own (above).

<a id="w-fcopysign"></a>
#### FCOPYSIGN

![FCOPYSIGN: R3, prefix 1110100001, sub-opcode 0010011; operands reg5, reg5, reg5; 4 bytes](figures/w/fcopysign/01.svg)

```
FCOPYSIGN Rs, Rt, Rd
```

Operation, flags and exceptions as for the entry FSIGN above; 1 layout form, each a chart of its own (above).


### FMIN: Floating minimum and maximum, binary64

**Mnemonics:** `FMIN`, `FMAX`  (aliases: `FMIND`, `FMAXD`)

**Syntax**

```
FMIN Rs, Rt, Rd
FMAX Rs, Rt, Rd
```

**Encoding**

![Encoding of FMIN](figures/R3-1.svg)

The chart is the leaf `R3-1`, R3, prefix `1110100001`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `op3` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R3-1`](dictionary/by-encoding.md#R3-1).

**Operation**

```
if Rs is a NaN then Rd ← Rt ; else if Rt is a NaN then Rd ← Rs ; else Rd ← smaller (FMIN) or larger (FMAX)
if both are NaNs the result is the canonical quiet NaN
```

**Flags** No integer flag is written. The IEEE exception flags raised are ORed into `FPSR` (`NX` inexact, `UF` underflow, `OF` overflow, `DZ` divide by zero, `NV` invalid); nothing traps.

**Exceptions** None.

The alternative spellings `FMIND`, `FMAXD` are aliases.

**Why it is here.** The floating counterparts of the integer `MIN` and `MAX`. A NaN operand loses to a number and two NaNs give the canonical quiet NaN.

<a id="w-fmin"></a>
#### FMIN

![FMIN: R3, prefix 1110100001, sub-opcode 0010100; operands reg5, reg5, reg5; 4 bytes](figures/w/fmin/01.svg)

```
FMIN Rs, Rt, Rd
```

Operation, flags and exceptions as for the entry FMIN above; 1 layout form, each a chart of its own (above).

<a id="w-fmax"></a>
#### FMAX

![FMAX: R3, prefix 1110100001, sub-opcode 0010101; operands reg5, reg5, reg5; 4 bytes](figures/w/fmax/01.svg)

```
FMAX Rs, Rt, Rd
```

Operation, flags and exceptions as for the entry FMIN above; 1 layout form, each a chart of its own (above).

<a id="w-fmind"></a>
#### FMIND

An alias of [`FMIN`](#w-fmin): the assembler writes it as that word.

<a id="w-fmaxd"></a>
#### FMAXD

An alias of [`FMAX`](#w-fmax): the assembler writes it as that word.


### FCLASS: Classify a floating-point value

**Mnemonics:** `FCLASS`, `FCLASS32`, `FCLASS16`  (aliases: `FCLASSD`, `FCLASSS`)

**Syntax**

```
FCLASS Rs, Rd
FCLASS32 Rs, Rd
FCLASS16 Rs, Rd
```

**Encoding**

![Encoding of FCLASS](figures/R2-1.svg)

The chart is the leaf `R2-1`, R2, prefix `111100000010`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R2-1`](dictionary/by-encoding.md#R2-1).

**Operation**

```
Rd ← a bit vector with exactly one bit set:
bit 0 -infinity      bit 1 -normal      bit 2 -subnormal   bit 3 -zero
bit 4 +zero          bit 5 +subnormal   bit 6 +normal      bit 7 +infinity
bit 8 signalling NaN bit 9 quiet NaN
```

**Flags** None.

**Exceptions** None.

Every libm function begins with this dispatch. The alternative spellings `FCLASSD`, `FCLASSS` are aliases.

**Why it is here.** Every libm function begins with this dispatch: one instruction returns which of ten kinds a value is (signalling or quiet NaN, infinity, normal, subnormal, zero, each signed), where software needs several compares and masks. It is justified by a workload, library mathematics, and not by compiled C, as the tag branches are. Nothing in the corpus emits it, because the compiler does not use it.

<a id="w-fclass"></a>
#### FCLASS

![FCLASS: R2, prefix 111100000010, sub-opcode 0000011010; operands reg5, reg5; 4 bytes](figures/w/fclass/01.svg)

```
FCLASS Rs, Rd
```

Operation, flags and exceptions as for the entry FCLASS above; 1 layout form, each a chart of its own (above).

<a id="w-fclass32"></a>
#### FCLASS32

![FCLASS32: R2, prefix 111100000010, sub-opcode 0000011011; operands reg5, reg5; 4 bytes](figures/w/fclass32/01.svg)

```
FCLASS32 Rs, Rd
```

Operation, flags and exceptions as for the entry FCLASS above; 1 layout form, each a chart of its own (above).

<a id="w-fclass16"></a>
#### FCLASS16

![FCLASS16: R2, prefix 111100000010, sub-opcode 0000110000; operands reg5, reg5; 4 bytes](figures/w/fclass16/01.svg)

```
FCLASS16 Rs, Rd
```

Operation, flags and exceptions as for the entry FCLASS above; 1 layout form, each a chart of its own (above).

<a id="w-fclassd"></a>
#### FCLASSD

An alias of [`FCLASS`](#w-fclass): the assembler writes it as that word.

<a id="w-fclasss"></a>
#### FCLASSS

An alias of [`FCLASS32`](#w-fclass32): the assembler writes it as that word.


### FRINT: Round to an integral value, binary64

**Mnemonics:** `FRINT`, `FRINTZ`, `FRINTM`, `FRINTP`, `FRINTA`  (aliases: `FRINTD`, `FRINTDZ`, `FRINTDM`, `FRINTDP`, `FRINTDA`)

**Syntax**

```
FRINT Rs, Rd
FRINTZ Rs, Rd
FRINTM Rs, Rd
FRINTP Rs, Rd
FRINTA Rs, Rd
```

**Encoding**

![Encoding of FRINT](figures/R2-1.svg)

The chart is the leaf `R2-1`, R2, prefix `111100000010`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R2-1`](dictionary/by-encoding.md#R2-1).

**Operation**

```
FRINT : Rd ← Rs rounded to nearest, ties to even
FRINTZ: toward zero         FRINTM: toward -infinity
FRINTP: toward +infinity    FRINTA: to nearest, ties away from zero (C round())
```

**Flags** No integer flag is written. The IEEE exception flags raised are ORed into `FPSR` (`NX` inexact, `UF` underflow, `OF` overflow, `DZ` divide by zero, `NV` invalid); nothing traps.

**Exceptions** None.

The rounding mode is in the instruction, never in a mode bit. The alternative spellings `FRINTD`, `FRINTDZ`, ... are aliases.

**Why it is here.** Rounding to an integral value in each direction (nearest even, toward zero, down, up) is in the set, and `FRINTA`, ties away from zero, serves C's `round()`, which is common in libm; it is a qualifier of the round operation and so costs no new operation.

<a id="w-frint"></a>
#### FRINT

![FRINT: R2, prefix 111100000010, sub-opcode 0000011100; operands reg5, reg5; 4 bytes](figures/w/frint/01.svg)

```
FRINT Rs, Rd
```

Operation, flags and exceptions as for the entry FRINT above; 1 layout form, each a chart of its own (above).

<a id="w-frintz"></a>
#### FRINTZ

![FRINTZ: R2, prefix 111100000010, sub-opcode 0000011101; operands reg5, reg5; 4 bytes](figures/w/frintz/01.svg)

```
FRINTZ Rs, Rd
```

Operation, flags and exceptions as for the entry FRINT above; 1 layout form, each a chart of its own (above).

<a id="w-frintm"></a>
#### FRINTM

![FRINTM: R2, prefix 111100000010, sub-opcode 0000011110; operands reg5, reg5; 4 bytes](figures/w/frintm/01.svg)

```
FRINTM Rs, Rd
```

Operation, flags and exceptions as for the entry FRINT above; 1 layout form, each a chart of its own (above).

<a id="w-frintp"></a>
#### FRINTP

![FRINTP: R2, prefix 111100000010, sub-opcode 0000011111; operands reg5, reg5; 4 bytes](figures/w/frintp/01.svg)

```
FRINTP Rs, Rd
```

Operation, flags and exceptions as for the entry FRINT above; 1 layout form, each a chart of its own (above).

<a id="w-frinta"></a>
#### FRINTA

![FRINTA: R2, prefix 111100000010, sub-opcode 0000100000; operands reg5, reg5; 4 bytes](figures/w/frinta/01.svg)

```
FRINTA Rs, Rd
```

Operation, flags and exceptions as for the entry FRINT above; 1 layout form, each a chart of its own (above).

<a id="w-frintd"></a>
#### FRINTD

An alias of [`FRINT`](#w-frint): the assembler writes it as that word.

<a id="w-frintdz"></a>
#### FRINTDZ

An alias of [`FRINTZ`](#w-frintz): the assembler writes it as that word.

<a id="w-frintdm"></a>
#### FRINTDM

An alias of [`FRINTM`](#w-frintm): the assembler writes it as that word.

<a id="w-frintdp"></a>
#### FRINTDP

An alias of [`FRINTP`](#w-frintp): the assembler writes it as that word.

<a id="w-frintda"></a>
#### FRINTDA

An alias of [`FRINTA`](#w-frinta): the assembler writes it as that word.


### FCVT: Floating conversions

**Mnemonics:** `FCVTDQ`, `FCVTDQU`, `FCVTQD`, `FCVTQUD`, `FCVTDS`, `FCVTSD`, `FCVTSL`, `FCVTLS`

**Syntax**

```
FCVTDQ Rs, Rd        ; binary64 to signed quad
FCVTDQU Rs, Rd       ; binary64 to unsigned quad
FCVTQD Rs, Rd        ; signed quad to binary64
FCVTQUD Rs, Rd       ; unsigned quad to binary64
FCVTDS Rs, Rd        ; binary64 to binary32
FCVTSD Rs, Rd        ; binary32 to binary64
FCVTSL Rs, Rd        ; binary32 to signed 32-bit integer
FCVTLS Rs, Rd        ; signed 32-bit integer to binary32
```

**Encoding**

![Encoding of FCVT](figures/R2-1.svg)

The chart is the leaf `R2-1`, R2, prefix `111100000010`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R2-1`](dictionary/by-encoding.md#R2-1).

**Operation**

```
float to integer: truncate toward zero, then saturate; a NaN gives the largest value
integer to float: round to nearest even
```

**Flags** No integer flag is written. The IEEE exception flags raised are ORed into `FPSR` (`NX` inexact, `UF` underflow, `OF` overflow, `DZ` divide by zero, `NV` invalid); nothing traps. A NaN or an out-of-range value raises `NV` and saturates.

**Exceptions** None.

Integer results are 64-bit (`FCVTDQ`, `FCVTDQU`) or 32-bit sign-extended (`FCVTSL`). Unsigned conversion of a negative value is invalid and gives 0.

**Why it is here.** `FCVTDQU` and `FCVTQUD` convert unsigned 64-bit integers to and from `binary64`. C needs both, and without them each takes a branch and several instructions.

<a id="w-fcvtdq"></a>
#### FCVTDQ

![FCVTDQ: R2, prefix 111100000010, sub-opcode 0000100001; operands reg5, reg5; 4 bytes](figures/w/fcvtdq/01.svg)

```
FCVTDQ Rs, Rd
```

Operation, flags and exceptions as for the entry FCVT above; 1 layout form, each a chart of its own (above).

<a id="w-fcvtdqu"></a>
#### FCVTDQU

![FCVTDQU: R2, prefix 111100000010, sub-opcode 0000100111; operands reg5, reg5; 4 bytes](figures/w/fcvtdqu/01.svg)

```
FCVTDQU Rs, Rd
```

Operation, flags and exceptions as for the entry FCVT above; 1 layout form, each a chart of its own (above).

<a id="w-fcvtqd"></a>
#### FCVTQD

![FCVTQD: R2, prefix 111100000010, sub-opcode 0000100010; operands reg5, reg5; 4 bytes](figures/w/fcvtqd/01.svg)

```
FCVTQD Rs, Rd
```

Operation, flags and exceptions as for the entry FCVT above; 1 layout form, each a chart of its own (above).

<a id="w-fcvtqud"></a>
#### FCVTQUD

![FCVTQUD: R2, prefix 111100000010, sub-opcode 0000101000; operands reg5, reg5; 4 bytes](figures/w/fcvtqud/01.svg)

```
FCVTQUD Rs, Rd
```

Operation, flags and exceptions as for the entry FCVT above; 1 layout form, each a chart of its own (above).

<a id="w-fcvtds"></a>
#### FCVTDS

![FCVTDS: R2, prefix 111100000010, sub-opcode 0000100011; operands reg5, reg5; 4 bytes](figures/w/fcvtds/01.svg)

```
FCVTDS Rs, Rd
```

Operation, flags and exceptions as for the entry FCVT above; 1 layout form, each a chart of its own (above).

<a id="w-fcvtsd"></a>
#### FCVTSD

![FCVTSD: R2, prefix 111100000010, sub-opcode 0000100100; operands reg5, reg5; 4 bytes](figures/w/fcvtsd/01.svg)

```
FCVTSD Rs, Rd
```

Operation, flags and exceptions as for the entry FCVT above; 1 layout form, each a chart of its own (above).

<a id="w-fcvtsl"></a>
#### FCVTSL

![FCVTSL: R2, prefix 111100000010, sub-opcode 0000100101; operands reg5, reg5; 4 bytes](figures/w/fcvtsl/01.svg)

```
FCVTSL Rs, Rd
```

Operation, flags and exceptions as for the entry FCVT above; 1 layout form, each a chart of its own (above).

<a id="w-fcvtls"></a>
#### FCVTLS

![FCVTLS: R2, prefix 111100000010, sub-opcode 0000100110; operands reg5, reg5; 4 bytes](figures/w/fcvtls/01.svg)

```
FCVTLS Rs, Rd
```

Operation, flags and exceptions as for the entry FCVT above; 1 layout form, each a chart of its own (above).


<a id="w-fsflags"></a>
### FSFLAGS: Swap the floating-point exception flags

![FSFLAGS: R2, prefix 111100000010, sub-opcode 0000101001; operands reg5, reg5; 4 bytes](figures/w/fsflags/01.svg)

**Mnemonics:** `FSFLAGS`

**Syntax**

```
FSFLAGS Rs, Rd
```

**Encoding**

![Encoding of FSFLAGS](figures/R2-1.svg)

The chart is the leaf `R2-1`, R2, prefix `111100000010`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R2-1`](dictionary/by-encoding.md#R2-1).

**Operation**

```
old ← FPSR
FPSR ← Rs[4:0]
Rd ← old
```

**Flags** None.

**Exceptions** None.

`FPSR` is the sticky five-bit register (`NX` bit 0, `UF` 1, `OF` 2, `DZ` 3, `NV` 4). C99 `<fenv.h>` is built on this one instruction.

**Why it is here.** IEEE 754 requires five status flags, and C99 `<fenv.h>` needs software access to them. The architecture has a sticky five-bit `FPSR`, laid out as RISC-V's `fflags`, written by every operation that can raise a flag and never trapping, and one swap instruction to read and write it. It is a record of what happened, not a mode, so the rule against mode bits is untouched.


### FHALF: Floating arithmetic, binary16

**Mnemonics:** `FADD16`, `FSUB16`, `FMUL16`, `FDIV16`, `FSQRT16`, `FCMP16`, `FMADD16`, `FMSUB16`, `FNMADD16`, `FNMSUB16`

**Syntax**

```
FADD16 Rs, Rd
FSUB16 Rs, Rd
FMUL16 Rs, Rd
FDIV16 Rs, Rd
FSQRT16 Rs, Rd
FCMP16 Rd, Rs
FMADD16 Rs, Rt, Ru, Rd ...
```

**Encoding**

![Encoding of FHALF](figures/R2-1.svg)

The chart is the leaf `R2-1`, R2, prefix `111100000010`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R2-1`](dictionary/by-encoding.md#R2-1), [`R4-1`](dictionary/by-encoding.md#R4-1).

**Operation**

```
as the binary32 words, in binary16: Rd ← Rd op Rs ; the fused forms take Rs, Rt, Ru, Rd
a half lives in the low 16 bits of a register, sign-extended to 64
```

**Flags** No integer flag is written. The IEEE exception flags raised are ORed into `FPSR` (`NX` inexact, `UF` underflow, `OF` overflow, `DZ` divide by zero, `NV` invalid); nothing traps. `FCMP16` writes `N Z V C` as `FCMP`.

**Exceptions** None.

Results are correctly rounded to nearest even, tininess judged after rounding; a NaN result is the canonical `0x7E00`. Open: the remaining half-precision operations ([J.9.10](appendix-j-open.md#j910)).

**Why it is here.** Half precision began as a GPU format (NVIDIA's `half`, 2002), spread to machine learning and image formats, and is in CPUs (x86 `F16C` and AVX-512 FP16, ARMv8.2, RISC-V `Zfh` and `Zfhmin`); this account is from memory and not checked against a manual. Two levels are possible: conversions only (about 500 to 1,000 lookup tables, no new operation by the folding rule) and full arithmetic (about 2,000 to 3,500 tables; estimates), and the existing double datapath can compute half correctly rounded. The architecture has both conversions and arithmetic. Open: the remaining half-precision operations ([J.9.10](appendix-j-open.md#j910)). 16-bit *integer* arithmetic is not provided: the ALU has one width (9.2.9).

<a id="w-fadd16"></a>
#### FADD16

![FADD16: R2, prefix 111100000010, sub-opcode 0000101010; operands reg5, reg5; 4 bytes](figures/w/fadd16/01.svg)

```
FADD16 Rs, Rd
```

Operation, flags and exceptions as for the entry FHALF above; 1 layout form, each a chart of its own (above).

<a id="w-fsub16"></a>
#### FSUB16

![FSUB16: R2, prefix 111100000010, sub-opcode 0000101011; operands reg5, reg5; 4 bytes](figures/w/fsub16/01.svg)

```
FSUB16 Rs, Rd
```

Operation, flags and exceptions as for the entry FHALF above; 1 layout form, each a chart of its own (above).

<a id="w-fmul16"></a>
#### FMUL16

![FMUL16: R2, prefix 111100000010, sub-opcode 0000101100; operands reg5, reg5; 4 bytes](figures/w/fmul16/01.svg)

```
FMUL16 Rs, Rd
```

Operation, flags and exceptions as for the entry FHALF above; 1 layout form, each a chart of its own (above).

<a id="w-fdiv16"></a>
#### FDIV16

![FDIV16: R2, prefix 111100000010, sub-opcode 0000101101; operands reg5, reg5; 4 bytes](figures/w/fdiv16/01.svg)

```
FDIV16 Rs, Rd
```

Operation, flags and exceptions as for the entry FHALF above; 1 layout form, each a chart of its own (above).

<a id="w-fsqrt16"></a>
#### FSQRT16

![FSQRT16: R2, prefix 111100000010, sub-opcode 0000101110; operands reg5, reg5; 4 bytes](figures/w/fsqrt16/01.svg)

```
FSQRT16 Rs, Rd
```

Operation, flags and exceptions as for the entry FHALF above; 1 layout form, each a chart of its own (above).

<a id="w-fcmp16"></a>
#### FCMP16

![FCMP16: R2, prefix 111100000010, sub-opcode 0000101111; operands reg5, reg5; 4 bytes](figures/w/fcmp16/01.svg)

```
FCMP16 Rd, Rs
```

Operation, flags and exceptions as for the entry FHALF above; 1 layout form, each a chart of its own (above).

<a id="w-fmadd16"></a>
#### FMADD16

![FMADD16: R4, prefix 11000101, sub-opcode 1000; operands reg5, reg5, reg5, reg5; 4 bytes](figures/w/fmadd16/01.svg)

```
FMADD16 Rs, Rt, Ru, Rd ...
```

Operation, flags and exceptions as for the entry FHALF above; 1 layout form, each a chart of its own (above).

<a id="w-fmsub16"></a>
#### FMSUB16

![FMSUB16: R4, prefix 11000101, sub-opcode 1001; operands reg5, reg5, reg5, reg5; 4 bytes](figures/w/fmsub16/01.svg)

Operation, flags and exceptions as for the entry FHALF above; 1 layout form, each a chart of its own (above).

<a id="w-fnmadd16"></a>
#### FNMADD16

![FNMADD16: R4, prefix 11000101, sub-opcode 1010; operands reg5, reg5, reg5, reg5; 4 bytes](figures/w/fnmadd16/01.svg)

Operation, flags and exceptions as for the entry FHALF above; 1 layout form, each a chart of its own (above).

<a id="w-fnmsub16"></a>
#### FNMSUB16

![FNMSUB16: R4, prefix 11000101, sub-opcode 1011; operands reg5, reg5, reg5, reg5; 4 bytes](figures/w/fnmsub16/01.svg)

Operation, flags and exceptions as for the entry FHALF above; 1 layout form, each a chart of its own (above).


### FCVTH: Conversions to and from binary16

**Mnemonics:** `FCVTSH`, `FCVTHS`, `FCVTDH`, `FCVTHD`, `FCVTHL`, `FCVTLH`

**Syntax**

```
FCVTSH Rs, Rd        ; binary32 to half
FCVTHS Rs, Rd        ; half to binary32
FCVTDH Rs, Rd        ; binary64 to half
FCVTHD Rs, Rd        ; half to binary64
FCVTHL Rs, Rd        ; half to signed 32-bit integer, toward zero
FCVTLH Rs, Rd        ; signed 32-bit integer to half
```

**Encoding**

![Encoding of FCVTH](figures/R2-1.svg)

The chart is the leaf `R2-1`, R2, prefix `111100000010`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R2-1`](dictionary/by-encoding.md#R2-1).

**Operation**

```
narrowing: round to nearest even ; widening: exact
FCVTHL of a NaN or an infinity is invalid and saturates; truncating a fraction is inexact
```

**Flags** No integer flag is written. The IEEE exception flags raised are ORed into `FPSR` (`NX` inexact, `UF` underflow, `OF` overflow, `DZ` divide by zero, `NV` invalid); nothing traps.

**Exceptions** None.

**Why it is here.** The conversion half of the `binary16` support (see `FHALF`). The conversions are the part machine-learning code needs most, because a half is normally loaded and stored with `MOVW`, converted, computed in single or double, and converted back.

<a id="w-fcvtsh"></a>
#### FCVTSH

![FCVTSH: R2, prefix 111100000010, sub-opcode 0000110001; operands reg5, reg5; 4 bytes](figures/w/fcvtsh/01.svg)

```
FCVTSH Rs, Rd
```

Operation, flags and exceptions as for the entry FCVTH above; 1 layout form, each a chart of its own (above).

<a id="w-fcvths"></a>
#### FCVTHS

![FCVTHS: R2, prefix 111100000010, sub-opcode 0000110010; operands reg5, reg5; 4 bytes](figures/w/fcvths/01.svg)

```
FCVTHS Rs, Rd
```

Operation, flags and exceptions as for the entry FCVTH above; 1 layout form, each a chart of its own (above).

<a id="w-fcvtdh"></a>
#### FCVTDH

![FCVTDH: R2, prefix 111100000010, sub-opcode 0000110011; operands reg5, reg5; 4 bytes](figures/w/fcvtdh/01.svg)

```
FCVTDH Rs, Rd
```

Operation, flags and exceptions as for the entry FCVTH above; 1 layout form, each a chart of its own (above).

<a id="w-fcvthd"></a>
#### FCVTHD

![FCVTHD: R2, prefix 111100000010, sub-opcode 0000110100; operands reg5, reg5; 4 bytes](figures/w/fcvthd/01.svg)

```
FCVTHD Rs, Rd
```

Operation, flags and exceptions as for the entry FCVTH above; 1 layout form, each a chart of its own (above).

<a id="w-fcvthl"></a>
#### FCVTHL

![FCVTHL: R2, prefix 111100000010, sub-opcode 0000110101; operands reg5, reg5; 4 bytes](figures/w/fcvthl/01.svg)

```
FCVTHL Rs, Rd
```

Operation, flags and exceptions as for the entry FCVTH above; 1 layout form, each a chart of its own (above).

<a id="w-fcvtlh"></a>
#### FCVTLH

![FCVTLH: R2, prefix 111100000010, sub-opcode 0000110110; operands reg5, reg5; 4 bytes](figures/w/fcvtlh/01.svg)

```
FCVTLH Rs, Rd
```

Operation, flags and exceptions as for the entry FCVTH above; 1 layout form, each a chart of its own (above).
<!-- /entries:9.12 -->

## 9.13 Atomics and ordering

*Cf. chapter 7, section 7.12 (the atomic and ordering instructions), section 7.3 (the atomics in detail) and section 7.2 (the memory model).*

**9.13.1** The atomic group `ATOM` holds `CAS`, `SWAP`, `XADD`, `XAND`, `XOR_`, `XXOR`, `XMAX`, `XMIN`, `XMAXU` and `XMINU`, each with a `_DB` variant that adds a barrier, and `LL` and `SC`; `FENCE`, `WFE`, `SEV`, `ISYNC` and `HINT` are in `SYS`. Their semantics, ordering rules and the reservation monitor are in chapter 7.

**9.13.2** `CAS` operates on 4 or 8 bytes; an 8-byte compare-and-swap may span two adjacent 4-byte fields, because the usual lock-and-count fast path of an operating system is exactly that (an 8-byte whole over two 4-byte members). *(D)* Open: the encoding of the `CAS` size and the placement of the operands of the atomics ([J.9.3](appendix-j-open.md#j93)).

*Commentary.* The official entry of each instruction is below, in this section; chapter 7 gives the reasons, the memory model and the use. **Impact.** *Kernel:* the entries below are all a kernel needs to write its locks; chapter 7 explains how they compose. *Compiler:* a lock acquire is one `_DB` instruction. *Hardware:* a reservation monitor beside the data cache.

<!-- entries:9.13 -->
### CAS: Compare and swap

**Mnemonics:** `CAS`, `CASDB`

**Syntax**

```
CAS expected, new, (address)        ; size is 4 or 8 bytes; operand placement open (J.9.3)
CASDB ...                            ; with a full barrier
```

**Encoding**

![Encoding of CAS](figures/R4-1.svg)

The chart is the leaf `R4-1`, R4, prefix `11000101`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `op3` is `reg5`: register, 5 bits. `op4` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R4-1`](dictionary/by-encoding.md#R4-1).

**Operation**

```
old ← M[address]                         ; 4 or 8 bytes, naturally aligned
if old = expected then M[address] ← new
result ← old          ; the program compares result with expected to learn whether the swap happened
```

**Flags** Not specified beyond "none for the read-modify-write forms"; `SC` reports success in its result register.

**Exceptions** Page fault, protection fault, alignment fault (the address must be naturally aligned) or bus error. The access is atomic with respect to every initiator, cores and devices alike.

The sub-opcodes and the semantics of this group are specified. The forms below name the roles; the placement of the operands (three registers with the address in a register, four for `CAS` and `CASDB`, in the order written) is open ([J.9.3](appendix-j-open.md#j93)).

**Why it is here.** The barrier-fused variants are taken from LoongArch's pragmatism: a lock acquire is one instruction rather than an atomic followed by a `FENCE`, and that pair is in every critical section of the system. With the other multiprocessor operations the atomics make the seventeen-operation SMP umbrella (7.1). They are defined on a reservation monitor and not on a bus lock (2.5).

**Cf.** 7.12 (the atomic instructions), 7.3 (the atomics in detail: the reservation monitor), 7.2 (the memory model).

<a id="w-cas"></a>
#### CAS

![CAS: R4, prefix 11000101, sub-opcode 1101; operands reg5, reg5, reg5, reg5; 4 bytes](figures/w/cas/01.svg)

```
CAS expected, new, (address)
```

Operation, flags and exceptions as for the entry CAS above; 1 layout form, each a chart of its own (above).

<a id="w-casdb"></a>
#### CASDB

![CASDB: R4, prefix 11000101, sub-opcode 1110; operands reg5, reg5, reg5, reg5; 4 bytes](figures/w/casdb/01.svg)

```
CASDB ...
```

Operation, flags and exceptions as for the entry CAS above; 1 layout form, each a chart of its own (above).


### SWAP: Atomic exchange

**Mnemonics:** `SWAP`, `SWAPDB`

**Syntax**

```
SWAP value, (address)
SWAPDB ...
```

**Encoding**

![Encoding of SWAP](figures/R3-1.svg)

The chart is the leaf `R3-1`, R3, prefix `1110100001`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `op3` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R3-1`](dictionary/by-encoding.md#R3-1).

**Operation**

```
old ← M[address] ; M[address] ← value ; result ← old
```

**Flags** Not specified beyond "none for the read-modify-write forms"; `SC` reports success in its result register.

**Exceptions** Page fault, protection fault, alignment fault (the address must be naturally aligned) or bus error. The access is atomic with respect to every initiator, cores and devices alike.

The sub-opcodes and the semantics of this group are specified. The forms below name the roles; the placement of the operands (three registers with the address in a register, four for `CAS` and `CASDB`, in the order written) is open ([J.9.3](appendix-j-open.md#j93)).

**Why it is here.** One of the read-modify-write atomics (see `CAS`). No separate reason is recorded for it.

**Cf.** 7.12 (the atomic instructions), 7.3 (the atomics in detail: the reservation monitor), 7.2 (the memory model).

<a id="w-swap"></a>
#### SWAP

![SWAP: R3, prefix 1110100001, sub-opcode 0011111; operands reg5, reg5, reg5; 4 bytes](figures/w/swap/01.svg)

```
SWAP value, (address)
```

Operation, flags and exceptions as for the entry SWAP above; 1 layout form, each a chart of its own (above).

<a id="w-swapdb"></a>
#### SWAPDB

![SWAPDB: R3, prefix 1110100001, sub-opcode 0100000; operands reg5, reg5, reg5; 4 bytes](figures/w/swapdb/01.svg)

```
SWAPDB ...
```

Operation, flags and exceptions as for the entry SWAP above; 1 layout form, each a chart of its own (above).


### XADD: Atomic fetch and add

**Mnemonics:** `XADD`, `XADDDB`

**Syntax**

```
XADD value, (address)
XADDDB ...
```

**Encoding**

![Encoding of XADD](figures/R3-1.svg)

The chart is the leaf `R3-1`, R3, prefix `1110100001`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `op3` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R3-1`](dictionary/by-encoding.md#R3-1).

**Operation**

```
old ← M[address] ; M[address] ← old + value ; result ← old
```

**Flags** Not specified beyond "none for the read-modify-write forms"; `SC` reports success in its result register.

**Exceptions** Page fault, protection fault, alignment fault (the address must be naturally aligned) or bus error. The access is atomic with respect to every initiator, cores and devices alike.

The sub-opcodes and the semantics of this group are specified. The forms below name the roles; the placement of the operands (three registers with the address in a register, four for `CAS` and `CASDB`, in the order written) is open ([J.9.3](appendix-j-open.md#j93)).

**Why it is here.** One of the fetch-and-operate atomics (see `CAS`), in the place of the PDP-11's read-modify-write instructions, which were indivisible on the Unibus through the `DATIP`/`DATO` pair (7.1).

**Cf.** 7.12 (the atomic instructions), 7.3 (the atomics in detail: the reservation monitor), 7.2 (the memory model).

<a id="w-xadd"></a>
#### XADD

![XADD: R3, prefix 1110100001, sub-opcode 0011101; operands reg5, reg5, reg5; 4 bytes](figures/w/xadd/01.svg)

```
XADD value, (address)
```

Operation, flags and exceptions as for the entry XADD above; 1 layout form, each a chart of its own (above).

<a id="w-xadddb"></a>
#### XADDDB

![XADDDB: R3, prefix 1110100001, sub-opcode 0011110; operands reg5, reg5, reg5; 4 bytes](figures/w/xadddb/01.svg)

```
XADDDB ...
```

Operation, flags and exceptions as for the entry XADD above; 1 layout form, each a chart of its own (above).


### XAND: Atomic fetch and and, or, xor

**Mnemonics:** `XAND`, `XANDDB`, `XOR`, `XOR_DB`, `XXOR`, `XXORDB`

**Syntax**

```
XAND value, (address)
XOR_ value, (address)        ; the trailing underscore keeps the mnemonic distinct from XOR
XXOR value, (address)
each with a DB form
```

**Encoding**

![Encoding of XAND](figures/R3-1.svg)

The chart is the leaf `R3-1`, R3, prefix `1110100001`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `op3` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R3-1`](dictionary/by-encoding.md#R3-1).

**Operation**

```
old ← M[address]
XAND: M[address] ← old AND value
XOR_: M[address] ← old OR value
XXOR: M[address] ← old XOR value
result ← old
```

**Flags** Not specified beyond "none for the read-modify-write forms"; `SC` reports success in its result register.

**Exceptions** Page fault, protection fault, alignment fault (the address must be naturally aligned) or bus error. The access is atomic with respect to every initiator, cores and devices alike.

The sub-opcodes and the semantics of this group are specified. The forms below name the roles; the placement of the operands (three registers with the address in a register, four for `CAS` and `CASDB`, in the order written) is open ([J.9.3](appendix-j-open.md#j93)).

**Why it is here.** The fetch-and-and, or and xor atomics (see `CAS`). No separate reason is recorded for them.

**Cf.** 7.12 (the atomic instructions), 7.3 (the atomics in detail: the reservation monitor), 7.2 (the memory model).

<a id="w-xand"></a>
#### XAND

![XAND: R3, prefix 1110100001, sub-opcode 0100001; operands reg5, reg5, reg5; 4 bytes](figures/w/xand/01.svg)

```
XAND value, (address)
```

Operation, flags and exceptions as for the entry XAND above; 1 layout form, each a chart of its own (above).

<a id="w-xanddb"></a>
#### XANDDB

![XANDDB: R3, prefix 1110100001, sub-opcode 0100010; operands reg5, reg5, reg5; 4 bytes](figures/w/xanddb/01.svg)

Operation, flags and exceptions as for the entry XAND above; 1 layout form, each a chart of its own (above).

<a id="w-xor-"></a>
#### XOR_

![XOR_: R3, prefix 1110100001, sub-opcode 0100011; operands reg5, reg5, reg5; 4 bytes](figures/w/xor-/01.svg)

```
XOR_ value, (address)
```

Operation, flags and exceptions as for the entry XAND above; 1 layout form, each a chart of its own (above).

<a id="w-xor-db"></a>
#### XOR_DB

![XOR_DB: R3, prefix 1110100001, sub-opcode 0100100; operands reg5, reg5, reg5; 4 bytes](figures/w/xor-db/01.svg)

Operation, flags and exceptions as for the entry XAND above; 1 layout form, each a chart of its own (above).

<a id="w-xxor"></a>
#### XXOR

![XXOR: R3, prefix 1110100001, sub-opcode 0100101; operands reg5, reg5, reg5; 4 bytes](figures/w/xxor/01.svg)

```
XXOR value, (address)
```

Operation, flags and exceptions as for the entry XAND above; 1 layout form, each a chart of its own (above).

<a id="w-xxordb"></a>
#### XXORDB

![XXORDB: R3, prefix 1110100001, sub-opcode 0100110; operands reg5, reg5, reg5; 4 bytes](figures/w/xxordb/01.svg)

Operation, flags and exceptions as for the entry XAND above; 1 layout form, each a chart of its own (above).


### XMAX: Atomic fetch and minimum or maximum

**Mnemonics:** `XMAX`, `XMAXDB`, `XMIN`, `XMINDB`, `XMAXU`, `XMAXUDB`, `XMINU`, `XMINUDB`

**Syntax**

```
XMAX value, (address)
XMIN ..., XMAXU ..., XMINU ...
each with a DB form
```

**Encoding**

![Encoding of XMAX](figures/R3-1.svg)

The chart is the leaf `R3-1`, R3, prefix `1110100001`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `op3` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R3-1`](dictionary/by-encoding.md#R3-1).

**Operation**

```
old ← M[address] ; M[address] ← max(old, value) (XMAX, XMAXU) or min (XMIN, XMINU) ; result ← old
signed for XMAX and XMIN, unsigned for the U forms
```

**Flags** Not specified beyond "none for the read-modify-write forms"; `SC` reports success in its result register.

**Exceptions** Page fault, protection fault, alignment fault (the address must be naturally aligned) or bus error. The access is atomic with respect to every initiator, cores and devices alike.

The sub-opcodes and the semantics of this group are specified. The forms below name the roles; the placement of the operands (three registers with the address in a register, four for `CAS` and `CASDB`, in the order written) is open ([J.9.3](appendix-j-open.md#j93)).

**Why it is here.** The fetch-and-minimum and maximum atomics, borrowed from LoongArch's richer atomic set: each is a couple of hundred lookup tables and saves a compare-and-swap retry loop.

**Cf.** 7.12 (the atomic instructions), 7.3 (the atomics in detail: the reservation monitor), 7.2 (the memory model).

<a id="w-xmax"></a>
#### XMAX

![XMAX: R3, prefix 1110100001, sub-opcode 0100111; operands reg5, reg5, reg5; 4 bytes](figures/w/xmax/01.svg)

```
XMAX value, (address)
```

Operation, flags and exceptions as for the entry XMAX above; 1 layout form, each a chart of its own (above).

<a id="w-xmaxdb"></a>
#### XMAXDB

![XMAXDB: R3, prefix 1110100001, sub-opcode 0101000; operands reg5, reg5, reg5; 4 bytes](figures/w/xmaxdb/01.svg)

Operation, flags and exceptions as for the entry XMAX above; 1 layout form, each a chart of its own (above).

<a id="w-xmin"></a>
#### XMIN

![XMIN: R3, prefix 1110100001, sub-opcode 0101001; operands reg5, reg5, reg5; 4 bytes](figures/w/xmin/01.svg)

```
XMIN ..., XMAXU ..., XMINU ...
```

Operation, flags and exceptions as for the entry XMAX above; 1 layout form, each a chart of its own (above).

<a id="w-xmindb"></a>
#### XMINDB

![XMINDB: R3, prefix 1110100001, sub-opcode 0101010; operands reg5, reg5, reg5; 4 bytes](figures/w/xmindb/01.svg)

Operation, flags and exceptions as for the entry XMAX above; 1 layout form, each a chart of its own (above).

<a id="w-xmaxu"></a>
#### XMAXU

![XMAXU: R3, prefix 1110100001, sub-opcode 0101011; operands reg5, reg5, reg5; 4 bytes](figures/w/xmaxu/01.svg)

Operation, flags and exceptions as for the entry XMAX above; 1 layout form, each a chart of its own (above).

<a id="w-xmaxudb"></a>
#### XMAXUDB

![XMAXUDB: R3, prefix 1110100001, sub-opcode 0101100; operands reg5, reg5, reg5; 4 bytes](figures/w/xmaxudb/01.svg)

Operation, flags and exceptions as for the entry XMAX above; 1 layout form, each a chart of its own (above).

<a id="w-xminu"></a>
#### XMINU

![XMINU: R3, prefix 1110100001, sub-opcode 0101101; operands reg5, reg5, reg5; 4 bytes](figures/w/xminu/01.svg)

Operation, flags and exceptions as for the entry XMAX above; 1 layout form, each a chart of its own (above).

<a id="w-xminudb"></a>
#### XMINUDB

![XMINUDB: R3, prefix 1110100001, sub-opcode 0101110; operands reg5, reg5, reg5; 4 bytes](figures/w/xminudb/01.svg)

Operation, flags and exceptions as for the entry XMAX above; 1 layout form, each a chart of its own (above).


### LLSC: Load-linked and store-conditional

**Mnemonics:** `LL`, `SC`

**Syntax**

```
LL (address), Rd
SC value, (address), result
```

**Encoding**

![Encoding of LLSC](figures/R3-1.svg)

The chart is the leaf `R3-1`, R3, prefix `1110100001`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `op3` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R3-1`](dictionary/by-encoding.md#R3-1).

**Operation**

```
LL: Rd ← M[address] ; take a reservation on the granule containing address
SC: if the reservation is intact then M[address] ← value ; result ← 0 (success)
    else nothing is written ; result ← 1 (failure)
a write to the granule by any initiator, core or device, clears the reservation
```

**Flags** Not specified beyond "none for the read-modify-write forms"; `SC` reports success in its result register.

**Exceptions** Page fault, protection fault, alignment fault (the address must be naturally aligned) or bus error. The access is atomic with respect to every initiator, cores and devices alike.

A short `LL`/`SC` sequence must eventually succeed if no other initiator keeps writing the granule (the RISC-V guarantee for constrained sequences). The sub-opcodes and the semantics of this group are specified. The forms below name the roles; the placement of the operands (three registers with the address in a register, four for `CAS` and `CASDB`, in the order written) is open ([J.9.3](appendix-j-open.md#j93)). The result convention of `SC` is part of the open placement ([J.9.3](appendix-j-open.md#j93)).

**Why it is here.** Load-linked and store-conditional, with the reservation a monitor, because a monitor maps onto the exclusive access of AXI and of FPGA and modern memory systems, where the Unibus's locked read-modify-write (`DATIP`/`DATO`) does not scale as cores multiply. A short sequence must eventually succeed if no other initiator keeps writing the granule, the RISC-V rule.

**Cf.** 7.12 (the atomic instructions), 7.3 (the atomics in detail: the reservation monitor), 7.2 (the memory model).

<a id="w-ll"></a>
#### LL

![LL: R3, prefix 1110100001, sub-opcode 0101111; operands reg5, reg5, reg5; 4 bytes](figures/w/ll/01.svg)

```
LL (address), Rd
```

Operation, flags and exceptions as for the entry LLSC above; 1 layout form, each a chart of its own (above).

<a id="w-sc"></a>
#### SC

![SC: R3, prefix 1110100001, sub-opcode 0110000; operands reg5, reg5, reg5; 4 bytes](figures/w/sc/01.svg)

```
SC value, (address), result
```

Operation, flags and exceptions as for the entry LLSC above; 1 layout form, each a chart of its own (above).
<!-- /entries:9.13 -->

## 9.14 System instructions, exceptions and interrupts

*Cf. chapter 6, section 6.13 (system instructions, exceptions and interrupts), section 6.3 (exceptions and interrupts) and section 6.5 (system registers).*

**9.14.1** The system group `SYS` holds the privileged and system instructions: `TRAP`, `TRAPL`, `RTI`, `RTT`, `RET`, `HALT`, `BPT`, `MTPS`, `MFPS`, `SPL`, `MFSR`, `MTSR`, `MTDP`, `MFDP`, `MFCPUID`, `PROBER`, `PROBEW`, `PUSHX`, `POPX`, and the translation and cache maintenance instructions (`TLBI`, `TLBIA`, `TLBSYNC`, `MTASID`, `MFASID`, `ICINV`, `ICINVA`). The user-memory guard instructions `STUA` and `CLUA` are described with them.

*Commentary.* The official entry of each instruction is below, in this section; the kernel chapter gives the modes, the entry sequence, the system registers and the reasons. **Impact.** *Kernel:* the entries below are the complete list of what the kernel may execute that user code may not, and of what both may; chapter 6 explains how they are used. *Compiler:* none, apart from `TRAP` in system-call stubs. *Hardware:* a class decode and one privilege check.

<!-- entries:9.14 -->
### NOP: No operation and landing pad

**Mnemonics:** `NOP`, `LPAD`

**Syntax**

```
NOP
LPAD
```

**Encoding**

![Encoding of NOP](figures/SYS0-1.svg)

The chart is the leaf `SYS0-1`, SYS0, prefix `11101110010`. `sub` (5 bits) selects the mnemonic: `nop` 00000, `rti` 00001, `rtt` 00010, `ret` 00011, `halt` 00100, `bpt` 00101, `fence` 00110, `wfe` 00111, `sev` 01000, `lpad` 01001, `tlbia` 01010, `tlbsync` 01011, `icinva` 01100, `pushx` 01101, `popx` 01110, `isync` 01111, `trapcc.ne` 10000, `trapcc.eq` 10001, `trapcc.pl` 10010, `trapcc.mi` 10011, `trapcc.vc` 10100, `trapcc.vs` 10101, `trapcc.cc` 10110, `trapcc.cs` 10111, `trapcc.ge` 11000, `trapcc.lt` 11001, `trapcc.gt` 11010, `trapcc.le` 11011, `trapcc.hi` 11100, `trapcc.los` 11101, `syspg0` 11110, `syspg1` 11111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SYS0-1`](dictionary/by-encoding.md#SYS0-1).

**Operation**

```
nothing
```

**Flags** None written.

**Exceptions** None.

`LPAD` marks a legal target of an indirect jump or call; no instruction enforces it in ABI version 1.

**Why it is here.** `NOP` is common and has no story; `LPAD` is the landing pad. Landing pads mark the legal targets of indirect jumps and calls so that jump-oriented attacks can be stopped at the transfer, as Intel's indirect-branch tracking and ARM's branch target identification do and OpenBSD enforces. ABI version 1 leaves them off (open: when they become mandatory, [J.D.2](appendix-j-open.md#jd2)), and the assembler provides `.lpad`; the kernel pain-points and mitigations reports record why deciding later is more expensive (appendix A, section A.1).

**Cf.** Appendix A, section A.1 (landing pads).

<a id="w-nop"></a>
#### NOP

![NOP: SYS0, prefix 11101110010, sub-opcode 00000; operands no operand; 2 bytes](figures/w/nop/01.svg)

```
NOP
```

Operation, flags and exceptions as for the entry NOP above; 1 layout form, each a chart of its own (above).

<a id="w-lpad"></a>
#### LPAD

![LPAD: SYS0, prefix 11101110010, sub-opcode 01001; operands no operand; 2 bytes](figures/w/lpad/01.svg)

```
LPAD
```

Operation, flags and exceptions as for the entry NOP above; 1 layout form, each a chart of its own (above).


### RTI: Return from interrupt or exception

**Mnemonics:** `RTI`, `RTT`

**Syntax**

```
RTI
RTT
```

**Encoding**

![Encoding of RTI](figures/SYS0-1.svg)

The chart is the leaf `SYS0-1`, SYS0, prefix `11101110010`. `sub` (5 bits) selects the mnemonic: `nop` 00000, `rti` 00001, `rtt` 00010, `ret` 00011, `halt` 00100, `bpt` 00101, `fence` 00110, `wfe` 00111, `sev` 01000, `lpad` 01001, `tlbia` 01010, `tlbsync` 01011, `icinva` 01100, `pushx` 01101, `popx` 01110, `isync` 01111, `trapcc.ne` 10000, `trapcc.eq` 10001, `trapcc.pl` 10010, `trapcc.mi` 10011, `trapcc.vc` 10100, `trapcc.vs` 10101, `trapcc.cc` 10110, `trapcc.cs` 10111, `trapcc.ge` 11000, `trapcc.lt` 11001, `trapcc.gt` 11010, `trapcc.le` 11011, `trapcc.hi` 11100, `trapcc.los` 11101, `syspg0` 11110, `syspg1` 11111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SYS0-1`](dictionary/by-encoding.md#SYS0-1).

**Operation**

```
PC ← EPC ; PSW ← EPSW           ; a PSW with the reserved mode 2 in either mode field aborts
RTT: and then set the trace bit T after the return
```

**Flags** Replaced by `EPSW`, including the flags.

**Exceptions** Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector.

`RTT` sets the trace bit *after* the return rather than before, which is what lets a debugger single-step out of its own trap handler.

**Why it is here.** `RTT` looks redundant against `RTI`, and stays: it sets the trace bit *after* the return rather than before, which is what lets a debugger single-step out of its own trap handler.

**Cf.** 6.3 (exceptions and interrupts), 6.13.

<a id="w-rti"></a>
#### RTI

![RTI: SYS0, prefix 11101110010, sub-opcode 00001; operands no operand; 2 bytes](figures/w/rti/01.svg)

```
RTI
```

Operation, flags and exceptions as for the entry RTI above; 1 layout form, each a chart of its own (above).

<a id="w-rtt"></a>
#### RTT

![RTT: SYS0, prefix 11101110010, sub-opcode 00010; operands no operand; 2 bytes](figures/w/rtt/01.svg)

```
RTT
```

Operation, flags and exceptions as for the entry RTI above; 1 layout form, each a chart of its own (above).


<a id="w-ret"></a>
### RET: Return from subroutine

![RET: SYS0, prefix 11101110010, sub-opcode 00011; operands no operand; 2 bytes](figures/w/ret/01.svg)

**Mnemonics:** `RET`

**Syntax**

```
RET
```

**Encoding**

![Encoding of RET](figures/SYS0-1.svg)

The chart is the leaf `SYS0-1`, SYS0, prefix `11101110010`. `sub` (5 bits) selects the mnemonic: `nop` 00000, `rti` 00001, `rtt` 00010, `ret` 00011, `halt` 00100, `bpt` 00101, `fence` 00110, `wfe` 00111, `sev` 01000, `lpad` 01001, `tlbia` 01010, `tlbsync` 01011, `icinva` 01100, `pushx` 01101, `popx` 01110, `isync` 01111, `trapcc.ne` 10000, `trapcc.eq` 10001, `trapcc.pl` 10010, `trapcc.mi` 10011, `trapcc.vc` 10100, `trapcc.vs` 10101, `trapcc.cc` 10110, `trapcc.cs` 10111, `trapcc.ge` 11000, `trapcc.lt` 11001, `trapcc.gt` 11010, `trapcc.le` 11011, `trapcc.hi` 11100, `trapcc.los` 11101, `syspg0` 11110, `syspg1` 11111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SYS0-1`](dictionary/by-encoding.md#SYS0-1).

**Operation**

```
PC ← M[SP] ; SP ← SP + 8
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

Not privileged: it is the partner of `CALL`.


<a id="w-halt"></a>
### HALT: Halt the processor

![HALT: SYS0, prefix 11101110010, sub-opcode 00100; operands no operand; 2 bytes](figures/w/halt/01.svg)

**Mnemonics:** `HALT`

**Syntax**

```
HALT
```

**Encoding**

![Encoding of HALT](figures/SYS0-1.svg)

The chart is the leaf `SYS0-1`, SYS0, prefix `11101110010`. `sub` (5 bits) selects the mnemonic: `nop` 00000, `rti` 00001, `rtt` 00010, `ret` 00011, `halt` 00100, `bpt` 00101, `fence` 00110, `wfe` 00111, `sev` 01000, `lpad` 01001, `tlbia` 01010, `tlbsync` 01011, `icinva` 01100, `pushx` 01101, `popx` 01110, `isync` 01111, `trapcc.ne` 10000, `trapcc.eq` 10001, `trapcc.pl` 10010, `trapcc.mi` 10011, `trapcc.vc` 10100, `trapcc.vs` 10101, `trapcc.cc` 10110, `trapcc.cs` 10111, `trapcc.ge` 11000, `trapcc.lt` 11001, `trapcc.gt` 11010, `trapcc.le` 11011, `trapcc.hi` 11100, `trapcc.los` 11101, `syspg0` 11110, `syspg1` 11111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SYS0-1`](dictionary/by-encoding.md#SYS0-1).

**Operation**

```
stop the processor
```

**Flags** None written.

**Exceptions** Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector.

**Cf.** 6.12.


<a id="w-bpt"></a>
### BPT: Breakpoint

![BPT: SYS0, prefix 11101110010, sub-opcode 00101; operands no operand; 2 bytes](figures/w/bpt/01.svg)

**Mnemonics:** `BPT`

**Syntax**

```
BPT
```

**Encoding**

![Encoding of BPT](figures/SYS0-1.svg)

The chart is the leaf `SYS0-1`, SYS0, prefix `11101110010`. `sub` (5 bits) selects the mnemonic: `nop` 00000, `rti` 00001, `rtt` 00010, `ret` 00011, `halt` 00100, `bpt` 00101, `fence` 00110, `wfe` 00111, `sev` 01000, `lpad` 01001, `tlbia` 01010, `tlbsync` 01011, `icinva` 01100, `pushx` 01101, `popx` 01110, `isync` 01111, `trapcc.ne` 10000, `trapcc.eq` 10001, `trapcc.pl` 10010, `trapcc.mi` 10011, `trapcc.vc` 10100, `trapcc.vs` 10101, `trapcc.cc` 10110, `trapcc.cs` 10111, `trapcc.ge` 11000, `trapcc.lt` 11001, `trapcc.gt` 11010, `trapcc.le` 11011, `trapcc.hi` 11100, `trapcc.los` 11101, `syspg0` 11110, `syspg1` 11111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SYS0-1`](dictionary/by-encoding.md#SYS0-1).

**Operation**

```
take the breakpoint vector with EPC = the address of the next instruction
```

**Flags** None written.

**Exceptions** Enters the kernel by the `BPT` vector.

A trap like any other, but kept as its own two-byte instruction because a debugger patches it over an existing instruction, so it must be the shortest instruction the machine has.

**Why it is here.** `BPT` is a trap vector, but a debugger patches it over an existing instruction, so it must be the shortest instruction the machine has; that is why it is kept although `IOT` and `EMT` are not.

**Cf.** 6.3.


<a id="w-fence"></a>
### FENCE: Memory fence

![FENCE: SYS0, prefix 11101110010, sub-opcode 00110; operands no operand; 2 bytes](figures/w/fence/01.svg)

**Mnemonics:** `FENCE`

**Syntax**

```
FENCE
```

**Encoding**

![Encoding of FENCE](figures/SYS0-1.svg)

The chart is the leaf `SYS0-1`, SYS0, prefix `11101110010`. `sub` (5 bits) selects the mnemonic: `nop` 00000, `rti` 00001, `rtt` 00010, `ret` 00011, `halt` 00100, `bpt` 00101, `fence` 00110, `wfe` 00111, `sev` 01000, `lpad` 01001, `tlbia` 01010, `tlbsync` 01011, `icinva` 01100, `pushx` 01101, `popx` 01110, `isync` 01111, `trapcc.ne` 10000, `trapcc.eq` 10001, `trapcc.pl` 10010, `trapcc.mi` 10011, `trapcc.vc` 10100, `trapcc.vs` 10101, `trapcc.cc` 10110, `trapcc.cs` 10111, `trapcc.ge` 11000, `trapcc.lt` 11001, `trapcc.gt` 11010, `trapcc.le` 11011, `trapcc.hi` 11100, `trapcc.los` 11101, `syspg0` 11110, `syspg1` 11111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SYS0-1`](dictionary/by-encoding.md#SYS0-1).

**Operation**

```
order the memory accesses before it against those after it, for every initiator that observes them
```

**Flags** None written.

**Exceptions** None.

Owed to devices (one `FENCE` separates writing a device's registers from setting its go bit) and to other cores.

**Why it is here.** The memory model is sequentially consistent, so `FENCE` is needed only for what is outside the model: devices and the framebuffer (one `FENCE` between writing a device's registers and setting its go bit, section 3.13) and instruction streams. The `_DB` barrier forms of the atomics exist so that a `FENCE` is not needed in a lock acquire.

**Cf.** 7.2 (the memory model), 2.2 (what the processor owes the bus).


<a id="w-wfe"></a>
<a id="w-wait"></a>
### WFE: Wait for an event

![WFE: SYS0, prefix 11101110010, sub-opcode 00111; operands no operand; 2 bytes](figures/w/wfe/01.svg)

**Mnemonics:** `WFE`  (aliases: `WAIT`)

**Syntax**

```
WFE
```

**Encoding**

![Encoding of WFE](figures/SYS0-1.svg)

The chart is the leaf `SYS0-1`, SYS0, prefix `11101110010`. `sub` (5 bits) selects the mnemonic: `nop` 00000, `rti` 00001, `rtt` 00010, `ret` 00011, `halt` 00100, `bpt` 00101, `fence` 00110, `wfe` 00111, `sev` 01000, `lpad` 01001, `tlbia` 01010, `tlbsync` 01011, `icinva` 01100, `pushx` 01101, `popx` 01110, `isync` 01111, `trapcc.ne` 10000, `trapcc.eq` 10001, `trapcc.pl` 10010, `trapcc.mi` 10011, `trapcc.vc` 10100, `trapcc.vs` 10101, `trapcc.cc` 10110, `trapcc.cs` 10111, `trapcc.ge` 11000, `trapcc.lt` 11001, `trapcc.gt` 11010, `trapcc.le` 11011, `trapcc.hi` 11100, `trapcc.los` 11101, `syspg0` 11110, `syspg1` 11111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SYS0-1`](dictionary/by-encoding.md#SYS0-1).

**Operation**

```
sleep until an interrupt is pending or another core executes SEV
```

**Flags** None written.

**Exceptions** Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector.

`WAIT` is an assembler alias.

**Why it is here.** `WAIT` was a PDP-11 instruction (sleep until an interrupt); `WFE` subsumes it: it sleeps until an interrupt or another core's `SEV`, and on a uniprocessor it behaves exactly as `WAIT` did. `WFE` and `SEV` belong to the multiprocessor operations (7.6).

**Cf.** 7.6 (waiting and signalling).

<a id="w-wait"></a>
**`WAIT`** is an alias of `WFE`: the assembler writes it as that word.


<a id="w-sev"></a>
### SEV: Send an event

![SEV: SYS0, prefix 11101110010, sub-opcode 01000; operands no operand; 2 bytes](figures/w/sev/01.svg)

**Mnemonics:** `SEV`

**Syntax**

```
SEV
```

**Encoding**

![Encoding of SEV](figures/SYS0-1.svg)

The chart is the leaf `SYS0-1`, SYS0, prefix `11101110010`. `sub` (5 bits) selects the mnemonic: `nop` 00000, `rti` 00001, `rtt` 00010, `ret` 00011, `halt` 00100, `bpt` 00101, `fence` 00110, `wfe` 00111, `sev` 01000, `lpad` 01001, `tlbia` 01010, `tlbsync` 01011, `icinva` 01100, `pushx` 01101, `popx` 01110, `isync` 01111, `trapcc.ne` 10000, `trapcc.eq` 10001, `trapcc.pl` 10010, `trapcc.mi` 10011, `trapcc.vc` 10100, `trapcc.vs` 10101, `trapcc.cc` 10110, `trapcc.cs` 10111, `trapcc.ge` 11000, `trapcc.lt` 11001, `trapcc.gt` 11010, `trapcc.le` 11011, `trapcc.hi` 11100, `trapcc.los` 11101, `syspg0` 11110, `syspg1` 11111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SYS0-1`](dictionary/by-encoding.md#SYS0-1).

**Operation**

```
wake every core waiting in WFE
```

**Flags** None written.

**Exceptions** None.

**Why it is here.** The signalling half of `WFE`, so that a core waiting for a lock can sleep instead of spinning and be woken by the core that releases it.

**Cf.** 7.6.


### TLBA: Invalidate all translations; wait for translation invalidations; invalidate the whole instruction cache

**Mnemonics:** `TLBIA`, `TLBSYNC`, `ICINVA`

**Syntax**

```
TLBIA
TLBSYNC
ICINVA
```

**Encoding**

![Encoding of TLBA](figures/SYS0-1.svg)

The chart is the leaf `SYS0-1`, SYS0, prefix `11101110010`. `sub` (5 bits) selects the mnemonic: `nop` 00000, `rti` 00001, `rtt` 00010, `ret` 00011, `halt` 00100, `bpt` 00101, `fence` 00110, `wfe` 00111, `sev` 01000, `lpad` 01001, `tlbia` 01010, `tlbsync` 01011, `icinva` 01100, `pushx` 01101, `popx` 01110, `isync` 01111, `trapcc.ne` 10000, `trapcc.eq` 10001, `trapcc.pl` 10010, `trapcc.mi` 10011, `trapcc.vc` 10100, `trapcc.vs` 10101, `trapcc.cc` 10110, `trapcc.cs` 10111, `trapcc.ge` 11000, `trapcc.lt` 11001, `trapcc.gt` 11010, `trapcc.le` 11011, `trapcc.hi` 11100, `trapcc.los` 11101, `syspg0` 11110, `syspg1` 11111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SYS0-1`](dictionary/by-encoding.md#SYS0-1).

**Operation**

```
TLBIA   : invalidate every translation-buffer entry on this core and, by broadcast, on the others
TLBSYNC : wait until the invalidations this core started have completed on every core
ICINVA  : invalidate the whole instruction cache
```

**Flags** None written.

**Exceptions** Privileged (`TLBIA`, `TLBSYNC`)

**Why it is here.** `TLBI` and `TLBIA` broadcast, `TLBSYNC` waits for the other cores, and `ICINV` and `ICINVA` invalidate the instruction cache: a Lisp runtime that compiles a function cannot work without an instruction-cache invalidate.

**Cf.** 7.5 (translation and instruction-cache coherence).

<a id="w-tlbia"></a>
#### TLBIA

![TLBIA: SYS0, prefix 11101110010, sub-opcode 01010; operands no operand; 2 bytes](figures/w/tlbia/01.svg)

```
TLBIA
```

Operation, flags and exceptions as for the entry TLBA above; 1 layout form, each a chart of its own (above).

<a id="w-tlbsync"></a>
#### TLBSYNC

![TLBSYNC: SYS0, prefix 11101110010, sub-opcode 01011; operands no operand; 2 bytes](figures/w/tlbsync/01.svg)

```
TLBSYNC
```

Operation, flags and exceptions as for the entry TLBA above; 1 layout form, each a chart of its own (above).

<a id="w-icinva"></a>
#### ICINVA

![ICINVA: SYS0, prefix 11101110010, sub-opcode 01100; operands no operand; 2 bytes](figures/w/icinva/01.svg)

```
ICINVA
```

Operation, flags and exceptions as for the entry TLBA above; 1 layout form, each a chart of its own (above).


### PUSHX: Push and pop the exception state

**Mnemonics:** `PUSHX`, `POPX`

**Syntax**

```
PUSHX
POPX
```

**Encoding**

![Encoding of PUSHX](figures/SYS0-1.svg)

The chart is the leaf `SYS0-1`, SYS0, prefix `11101110010`. `sub` (5 bits) selects the mnemonic: `nop` 00000, `rti` 00001, `rtt` 00010, `ret` 00011, `halt` 00100, `bpt` 00101, `fence` 00110, `wfe` 00111, `sev` 01000, `lpad` 01001, `tlbia` 01010, `tlbsync` 01011, `icinva` 01100, `pushx` 01101, `popx` 01110, `isync` 01111, `trapcc.ne` 10000, `trapcc.eq` 10001, `trapcc.pl` 10010, `trapcc.mi` 10011, `trapcc.vc` 10100, `trapcc.vs` 10101, `trapcc.cc` 10110, `trapcc.cs` 10111, `trapcc.ge` 11000, `trapcc.lt` 11001, `trapcc.gt` 11010, `trapcc.le` 11011, `trapcc.hi` 11100, `trapcc.los` 11101, `syspg0` 11110, `syspg1` 11111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SYS0-1`](dictionary/by-encoding.md#SYS0-1).

**Operation**

```
PUSHX: SP ← SP - 16 ; M[SP] ← EPSW ; M[SP + 8] ← EPC
POPX : EPSW ← M[SP] ; EPC ← M[SP + 8] ; SP ← SP + 16
```

**Flags** None written.

**Exceptions** Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector. `SP` must be 8-byte aligned (a misaligned-access abort); both words are checked before either is touched.

For a handler that wants to be interrupted: it can save the exception state and lower the priority.

**Why it is here.** A handler that can be interrupted must save `EPC` and `EPSW` before it lowers the priority; with only `MFSR` that costs two moves and two stores (sixteen bytes) on every such kernel entry, and the same to restore. The instructions may not show up high in the instruction count, but they save bytes and cycles in a tight, very often used kernel loop.

**Cf.** 6.3, 6.13.

<a id="w-pushx"></a>
#### PUSHX

![PUSHX: SYS0, prefix 11101110010, sub-opcode 01101; operands no operand; 2 bytes](figures/w/pushx/01.svg)

```
PUSHX
```

Operation, flags and exceptions as for the entry PUSHX above; 1 layout form, each a chart of its own (above).

<a id="w-popx"></a>
#### POPX

![POPX: SYS0, prefix 11101110010, sub-opcode 01110; operands no operand; 2 bytes](figures/w/popx/01.svg)

```
POPX
```

Operation, flags and exceptions as for the entry PUSHX above; 1 layout form, each a chart of its own (above).


<a id="w-isync"></a>
### ISYNC: Instruction synchronisation

![ISYNC: SYS0, prefix 11101110010, sub-opcode 01111; operands no operand; 2 bytes](figures/w/isync/01.svg)

**Mnemonics:** `ISYNC`

**Syntax**

```
ISYNC
```

**Encoding**

![Encoding of ISYNC](figures/SYS0-1.svg)

The chart is the leaf `SYS0-1`, SYS0, prefix `11101110010`. `sub` (5 bits) selects the mnemonic: `nop` 00000, `rti` 00001, `rtt` 00010, `ret` 00011, `halt` 00100, `bpt` 00101, `fence` 00110, `wfe` 00111, `sev` 01000, `lpad` 01001, `tlbia` 01010, `tlbsync` 01011, `icinva` 01100, `pushx` 01101, `popx` 01110, `isync` 01111, `trapcc.ne` 10000, `trapcc.eq` 10001, `trapcc.pl` 10010, `trapcc.mi` 10011, `trapcc.vc` 10100, `trapcc.vs` 10101, `trapcc.cc` 10110, `trapcc.cs` 10111, `trapcc.ge` 11000, `trapcc.lt` 11001, `trapcc.gt` 11010, `trapcc.le` 11011, `trapcc.hi` 11100, `trapcc.los` 11101, `syspg0` 11110, `syspg1` 11111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SYS0-1`](dictionary/by-encoding.md#SYS0-1).

**Operation**

```
make earlier writes to PTBR, ASID, MMUCTL and VBR, and earlier ICINVs, take effect for the instructions that follow
```

**Flags** None written.

**Exceptions** Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector. A non-zero pad byte is an illegal instruction.

The architecture promises the effect only after the next `ISYNC`; an in-order implementation may make it immediate, and software must not rely on that.

**Why it is here.** Taken from the out-of-order readiness review: it makes earlier writes to `PTBR`, `ASID`, `MMUCTL` and `VBR` take effect for what follows, so an in-order machine may make them immediate and a speculative one has a place to serialise. It serves the aim that the architecture is efficient on both in-order and out-of-order cores (1.4.4).

**Cf.** 7.5, 6.5.


<a id="w-hint"></a>
### HINT: Hint

![HINT: SYSI, prefix 011010, sub-opcode 11; operands imm8u; 2 bytes](figures/w/hint/01.svg)

**Mnemonics:** `HINT`

**Syntax**

```
HINT #n        ; n = 0 to 255
```

**Encoding**

![Encoding of HINT](figures/SYSI-1.svg)

The chart is the leaf `SYSI-1`, SYSI, prefix `011010`. `op1` is `imm8u`: unsigned 8-bit immediate, 0 to 255. `sub` (2 bits) selects the mnemonic: `spl` 00, `trap` 01, `trapl` 10, `hint` 11.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SYSI-1`](dictionary/by-encoding.md#SYSI-1).

**Operation**

```
no architectural effect
```

**Flags** None written.

**Exceptions** None.

Defined codes: 0 a plain no-op hint, 1 pause (spin-wait), 2 speculation barrier. Every other code is a reserved hint that executes as a no-op; software shall not use it. Not privileged.

**Why it is here.** Defined with `ISYNC`: a no-op with a byte of code, defined for `0` (plain), `1` (pause, for spin-wait loops) and `2` (speculation barrier), every other code a reserved hint that executes as a no-op so that a later machine can give it a meaning without breaking an old binary.


### MFSR: Move from and to a system register

**Mnemonics:** `MFSR`, `MTSR`

**Syntax**

```
MFSR Rd, name
MTSR name, Rs
```

**Encoding**

![Encoding of MFSR](figures/MFSR-1.svg)

The chart is the leaf `MFSR-1`, MFSR, prefix `111100101110000`. `op1` is `reg5`: register, 5 bits. `op2` is `imm12u`: unsigned 12-bit immediate, 0 to 4095.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`MFSR-1`](dictionary/by-encoding.md#MFSR-1), [`MTSR-1`](dictionary/by-encoding.md#MTSR-1).

**Operation**

```
MFSR: Rd ← system register `name`
MTSR: system register `name` ← Rs         ; read-only registers are an illegal instruction
```

**Flags** None written.

**Exceptions** Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector. An unassigned system register is an illegal instruction.

The register is chosen by name. A write to `PTBR`, `ASID` or `MMUCTL` flushes the translation buffer.

| Name | Number | Access |
|---|---|---|
| `PTBR` | 0 | read and write |
| `EPC` | 1 | read and write |
| `EVA` | 2 | read only |
| `ECAUSE` | 3 | read only |
| `DMW0` | 4 | read and write |
| `DMW1` | 5 | read and write |
| `USP` | 6 | read and write |
| `SSP` | 7 | read and write |
| `EPSW` | 8 | read and write |
| `VBR` | 9 | read and write |
| `MMUCTL` | 10 | read and write |
| `ASID` | 11 | read and write |
| `CPUID` | 12 | read only |

**Why it is here.** A paging operating system must install a page table and learn why it was entered, which needs instructions to write `PTBR` and read `EPC`, `EVA` and `ECAUSE`. One general pair reaches all of the system registers by number. The user and supervisor stack pointers are in the set because any kernel must read and write the user stack pointer to build a signal frame, copy a process or switch context.

**Cf.** 6.5 (system registers).

<a id="w-mfsr"></a>
#### MFSR

![MFSR: MFSR, prefix 111100101110000; operands reg5, imm12u; 4 bytes](figures/w/mfsr/01.svg)

```
MFSR Rd, name
```

Operation, flags and exceptions as for the entry MFSR above; 1 layout form, each a chart of its own (above).

<a id="w-mtsr"></a>
#### MTSR

![MTSR: MTSR, prefix 111100101110001; operands imm12u, reg5; 4 bytes](figures/w/mtsr/01.svg)

```
MTSR name, Rs
```

Operation, flags and exceptions as for the entry MFSR above; 1 layout form, each a chart of its own (above).


### MTPS: Move to and from the processor status word

**Mnemonics:** `MTPS`, `MFPS`

**Syntax**

```
MTPS Rs
MFPS Rd
```

**Encoding**

![Encoding of MTPS](figures/SYSR-1.svg)

The chart is the leaf `SYSR-1`, SYSR, prefix `11000100`. `op1` is `reg5`: register, 5 bits. `sub` (3 bits) selects the mnemonic: `mtps` 000, `mfps` 001, `tlbi` 010, `mtasid` 011, `mfasid` 100, `mtdp` 101, `mfdp` 110, `mtdmw` 111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SYSR-1`](dictionary/by-encoding.md#SYSR-1).

**Operation**

```
MTPS: PSW ← Rs          ; in user mode only the flags N Z V C are written
MFPS: Rd ← PSW
```

**Flags** `MTPS` writes the flags from `Rs`; `MFPS` writes none.

**Exceptions** A `MTPS` value with the reserved mode 2 in a mode field aborts.

**Cf.** 6.2 (modes and the status word).

<a id="w-mtps"></a>
#### MTPS

![MTPS: SYSR, prefix 11000100, sub-opcode 000; operands reg5; 2 bytes](figures/w/mtps/01.svg)

```
MTPS Rs
```

Operation, flags and exceptions as for the entry MTPS above; 1 layout form, each a chart of its own (above).

<a id="w-mfps"></a>
#### MFPS

![MFPS: SYSR, prefix 11000100, sub-opcode 001; operands reg5; 2 bytes](figures/w/mfps/01.svg)

```
MFPS Rd
```

Operation, flags and exceptions as for the entry MTPS above; 1 layout form, each a chart of its own (above).


<a id="w-spl"></a>
### SPL: Set the interrupt priority level

![SPL: SYSI, prefix 011010, sub-opcode 00; operands imm8u; 2 bytes](figures/w/spl/01.svg)

**Mnemonics:** `SPL`

**Syntax**

```
SPL #n        ; n = 0 to 7
```

**Encoding**

![Encoding of SPL](figures/SYSI-1.svg)

The chart is the leaf `SYSI-1`, SYSI, prefix `011010`. `op1` is `imm8u`: unsigned 8-bit immediate, 0 to 255. `sub` (2 bits) selects the mnemonic: `spl` 00, `trap` 01, `trapl` 10, `hint` 11.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SYSI-1`](dictionary/by-encoding.md#SYSI-1).

**Operation**

```
PSW.priority ← n
```

**Flags** None written. The condition flags are untouched.

**Exceptions** Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector. A priority above 7 is an illegal instruction.

Kept despite `MTPS` writing the whole word because it sets the priority alone: a kernel raising priority around a critical section must not clobber the flags.

**Why it is here.** `SPL` stays although `MTPS` writes the whole status word: it sets the priority alone, leaving the condition codes untouched, so a kernel raising priority around a critical section does not clobber flags. It is the PDP-11 instruction of the same name.

**Cf.** 6.3.


### TRAP: System call and trap

**Mnemonics:** `TRAP`, `TRAPL`

**Syntax**

```
TRAP #n        ; n = 0 to 15, two bytes
TRAPL #n       ; n = 0 to 255, four bytes
```

**Encoding**

![Encoding of TRAP](figures/SYSI-1.svg)

The chart is the leaf `SYSI-1`, SYSI, prefix `011010`. `op1` is `imm8u`: unsigned 8-bit immediate, 0 to 255. `sub` (2 bits) selects the mnemonic: `spl` 00, `trap` 01, `trapl` 10, `hint` 11.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SYSI-1`](dictionary/by-encoding.md#SYSI-1).

**Operation**

```
enter the kernel by vector (TRAP_BASE + n), with EPC = the address of the next instruction
```

**Flags** None written.

**Exceptions** Enters the kernel; not privileged.

The replacement for the PDP-11 `IOT` and `EMT`. In these encodings `TRAP` and `TRAPL` are one word with an 8-bit vector number (`docs/encoding-proposal.md`).

**Why it is here.** In the original encoding `TRAPL` existed so that the vector range of 256 and the two-byte common case could both be kept (`TRAP #n` for `n` below 16 is two bytes, and the long form reaches 256); here one word carries an 8-bit vector number. `IOT` and `EMT`, which were `TRAP` at two particular vectors on the PDP-11, are not provided.

**Cf.** 6.3, 6.10 (system calls).

<a id="w-trap"></a>
#### TRAP

![TRAP: SYSI, prefix 011010, sub-opcode 01; operands imm8u; 2 bytes](figures/w/trap/01.svg)

```
TRAP #n
```

Operation, flags and exceptions as for the entry TRAP above; 1 layout form, each a chart of its own (above).

<a id="w-trapl"></a>
#### TRAPL

![TRAPL: SYSI, prefix 011010, sub-opcode 10; operands imm8u; 2 bytes](figures/w/trapl/01.svg)

```
TRAPL #n
```

Operation, flags and exceptions as for the entry TRAP above; 1 layout form, each a chart of its own (above).


<a id="w-tlbi"></a>
### TLBI: Invalidate a translation

![TLBI: SYSR, prefix 11000100, sub-opcode 010; operands reg5; 2 bytes](figures/w/tlbi/01.svg)

**Mnemonics:** `TLBI`

**Syntax**

```
TLBI Rs
```

**Encoding**

![Encoding of TLBI](figures/SYSR-1.svg)

The chart is the leaf `SYSR-1`, SYSR, prefix `11000100`. `op1` is `reg5`: register, 5 bits. `sub` (3 bits) selects the mnemonic: `mtps` 000, `mfps` 001, `tlbi` 010, `mtasid` 011, `mfasid` 100, `mtdp` 101, `mfdp` 110, `mtdmw` 111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SYSR-1`](dictionary/by-encoding.md#SYSR-1).

**Operation**

```
invalidate the translation-buffer entry for the page containing the address in Rs, on this core and by broadcast on the others
```

**Flags** None written.

**Exceptions** Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector.

**Why it is here.** It broadcasts: a translation changed by one core must be invalidated on all of them, and `TLBSYNC` waits for it.

**Cf.** 7.5, 6.8.


### MTASID: Move to and from the address-space identifier

**Mnemonics:** `MTASID`, `MFASID`

**Syntax**

```
MTASID Rs
MFASID Rd
```

**Encoding**

![Encoding of MTASID](figures/SYSR-1.svg)

The chart is the leaf `SYSR-1`, SYSR, prefix `11000100`. `op1` is `reg5`: register, 5 bits. `sub` (3 bits) selects the mnemonic: `mtps` 000, `mfps` 001, `tlbi` 010, `mtasid` 011, `mfasid` 100, `mtdp` 101, `mfdp` 110, `mtdmw` 111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SYSR-1`](dictionary/by-encoding.md#SYSR-1).

**Operation**

```
MTASID: ASID ← Rs[15:0]          
MFASID: Rd ← ASID
```

**Flags** None written.

**Exceptions** Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector.

The `ASID` tags translation-buffer entries so a context switch is one store.

**Why it is here.** The `ASID` tags translation-buffer entries so a context switch is one store and no flush. No further reason is recorded.

**Cf.** 6.8.

<a id="w-mtasid"></a>
#### MTASID

![MTASID: SYSR, prefix 11000100, sub-opcode 011; operands reg5; 2 bytes](figures/w/mtasid/01.svg)

```
MTASID Rs
```

Operation, flags and exceptions as for the entry MTASID above; 1 layout form, each a chart of its own (above).

<a id="w-mfasid"></a>
#### MFASID

![MFASID: SYSR, prefix 11000100, sub-opcode 100; operands reg5; 2 bytes](figures/w/mfasid/01.svg)

```
MFASID Rd
```

Operation, flags and exceptions as for the entry MTASID above; 1 layout form, each a chart of its own (above).


### MTDP: Move to and from the direct pointer

**Mnemonics:** `MTDP`, `MFDP`

**Syntax**

```
MTDP Rs
MFDP Rd
```

**Encoding**

![Encoding of MTDP](figures/SYSR-1.svg)

The chart is the leaf `SYSR-1`, SYSR, prefix `11000100`. `op1` is `reg5`: register, 5 bits. `sub` (3 bits) selects the mnemonic: `mtps` 000, `mfps` 001, `tlbi` 010, `mtasid` 011, `mfasid` 100, `mtdp` 101, `mfdp` 110, `mtdmw` 111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SYSR-1`](dictionary/by-encoding.md#SYSR-1).

**Operation**

```
MTDP: DP ← Rs
MFDP: Rd ← DP
```

**Flags** None written.

**Exceptions** None.

`DP` is the thread pointer in user mode and the per-CPU pointer in kernel mode; there is one copy per mode.

**Why it is here.** `DP` descends from the 6502's zero page and is kept for code density (a short displacement from `DP`); it is also the thread pointer in user mode and, in kernel mode, the per-CPU pointer that an SMP kernel wants (7.4). `MTDP` and `MFDP` read and write the current mode's copy.

**Cf.** 7.4 (per-CPU state).

<a id="w-mtdp"></a>
#### MTDP

![MTDP: SYSR, prefix 11000100, sub-opcode 101; operands reg5; 2 bytes](figures/w/mtdp/01.svg)

```
MTDP Rs
```

Operation, flags and exceptions as for the entry MTDP above; 1 layout form, each a chart of its own (above).

<a id="w-mfdp"></a>
#### MFDP

![MFDP: SYSR, prefix 11000100, sub-opcode 110; operands reg5; 2 bytes](figures/w/mfdp/01.svg)

```
MFDP Rd
```

Operation, flags and exceptions as for the entry MTDP above; 1 layout form, each a chart of its own (above).


<a id="w-mtdmw"></a>
### MTDMW: Move to a direct-mapping window

![MTDMW: SYSR, prefix 11000100, sub-opcode 111; operands reg5; 2 bytes](figures/w/mtdmw/01.svg)

**Mnemonics:** `MTDMW`

**Syntax**

```
MTDMW Rs
```

**Encoding**

![Encoding of MTDMW](figures/SYSR-1.svg)

The chart is the leaf `SYSR-1`, SYSR, prefix `11000100`. `op1` is `reg5`: register, 5 bits. `sub` (3 bits) selects the mnemonic: `mtps` 000, `mfps` 001, `tlbi` 010, `mtasid` 011, `mfasid` 100, `mtdp` 101, `mfdp` 110, `mtdmw` 111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SYSR-1`](dictionary/by-encoding.md#SYSR-1).

**Operation**

```
DMW0 ← Rs          ; stored; it has no effect on translation
```

**Flags** None written.

**Exceptions** Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector.

The direct-mapping windows are stored and have no effect on translation.

**Why it is here.** Taken from LoongArch's direct-mapping windows, which stop the kernel taking translation-buffer misses on its own text. The instruction is storage only: the windows have no effect on translation.

**Cf.** 6.9.


<a id="w-mfcpuid"></a>
### MFCPUID: Read the processor identifier

![MFCPUID: SYSR, prefix 1110100000, sub-opcode 0; operands reg5; 2 bytes](figures/w/mfcpuid/01.svg)

**Mnemonics:** `MFCPUID`

**Syntax**

```
MFCPUID Rd
```

**Encoding**

![Encoding of MFCPUID](figures/SYSR-2.svg)

The chart is the leaf `SYSR-2`, SYSR, prefix `1110100000`. `op1` is `reg5`: register, 5 bits. `sub` (1 bit) selects the mnemonic: `mfcpuid` 0, `icinv` 1.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SYSR-2`](dictionary/by-encoding.md#SYSR-2).

**Operation**

```
Rd ← CPUID
```

**Flags** None written.

**Exceptions** None.

The index of this core, for per-CPU data.

**Why it is here.** Part of the multiprocessor operations, because per-CPU data needs each core to know which one it is.

**Cf.** 7.4, 7.8.


<a id="w-icinv"></a>
### ICINV: Invalidate the instruction cache for an address

![ICINV: SYSR, prefix 1110100000, sub-opcode 1; operands reg5; 2 bytes](figures/w/icinv/01.svg)

**Mnemonics:** `ICINV`

**Syntax**

```
ICINV Rs
```

**Encoding**

![Encoding of ICINV](figures/SYSR-2.svg)

The chart is the leaf `SYSR-2`, SYSR, prefix `1110100000`. `op1` is `reg5`: register, 5 bits. `sub` (1 bit) selects the mnemonic: `mfcpuid` 0, `icinv` 1.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SYSR-2`](dictionary/by-encoding.md#SYSR-2).

**Operation**

```
invalidate the instruction-cache line containing the address in Rs
```

**Flags** None written.

**Exceptions** Privileged, as for the other cache-maintenance instructions.

**Why it is here.** Instruction-cache invalidation, by address (`ICINV`) and whole (`ICINVA`). The reason is the one given for `TLBA`: a runtime that compiles a function cannot work without it.

**Cf.** 7.5.


### PROBE: Probe an address for read or write access

**Mnemonics:** `PROBER`, `PROBEW`

**Syntax**

```
PROBER Rd, Rs
PROBEW Rd, Rs
```

**Encoding**

![Encoding of PROBE](figures/R2-1.svg)

The chart is the leaf `R2-1`, R2, prefix `111100000010`. `op1` is `reg5`: register, 5 bits. `op2` is `reg5`: register, 5 bits. `xsub` selects the mnemonic.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`R2-1`](dictionary/by-encoding.md#R2-1).

**Operation**

```
Rd ← 1 if the address in Rs is readable (PROBER) or writable (PROBEW) in the previous mode, else 0
no fault is taken
```

**Flags** None written.

**Exceptions** Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector.

Taken from the VAX `PROBER` and `PROBEW`: the kernel validates a user address before using it.

**Why it is here.** Taken from the VAX `PROBER` and `PROBEW`: the kernel validates a user address before using it, and it replaces the `nofault` global of the V7 kernel for the address-validation case.

**Cf.** 6.10 (the user-memory guard), 6.6.

<a id="w-prober"></a>
#### PROBER

![PROBER: R2, prefix 111100000010, sub-opcode 0000001110; operands reg5, reg5; 4 bytes](figures/w/prober/01.svg)

```
PROBER Rd, Rs
```

Operation, flags and exceptions as for the entry PROBE above; 1 layout form, each a chart of its own (above).

<a id="w-probew"></a>
#### PROBEW

![PROBEW: R2, prefix 111100000010, sub-opcode 0000001111; operands reg5, reg5; 4 bytes](figures/w/probew/01.svg)

```
PROBEW Rd, Rs
```

Operation, flags and exceptions as for the entry PROBE above; 1 layout form, each a chart of its own (above).


### TRAPCC: Trap on condition

**Mnemonics:** `TRAPCC.NE`, `TRAPCC.EQ`, `TRAPCC.PL`, `TRAPCC.MI`, `TRAPCC.VC`, `TRAPCC.VS`, `TRAPCC.CC`, `TRAPCC.CS`, `TRAPCC.GE`, `TRAPCC.LT`, `TRAPCC.GT`, `TRAPCC.LE`, `TRAPCC.HI`, `TRAPCC.LOS`

**Syntax**

```
TRAPCC.cc          ; one word for each of the 14 conditions: TRAPCC.EQ, TRAPCC.VS, TRAPCC.HI ...
```

**Encoding**

![Encoding of TRAPCC](figures/SYS0-1.svg)

The chart is the leaf `SYS0-1`, SYS0, prefix `11101110010`. `sub` (5 bits) selects the mnemonic: `nop` 00000, `rti` 00001, `rtt` 00010, `ret` 00011, `halt` 00100, `bpt` 00101, `fence` 00110, `wfe` 00111, `sev` 01000, `lpad` 01001, `tlbia` 01010, `tlbsync` 01011, `icinva` 01100, `pushx` 01101, `popx` 01110, `isync` 01111, `trapcc.ne` 10000, `trapcc.eq` 10001, `trapcc.pl` 10010, `trapcc.mi` 10011, `trapcc.vc` 10100, `trapcc.vs` 10101, `trapcc.cc` 10110, `trapcc.cs` 10111, `trapcc.ge` 11000, `trapcc.lt` 11001, `trapcc.gt` 11010, `trapcc.le` 11011, `trapcc.hi` 11100, `trapcc.los` 11101, `syspg0` 11110, `syspg1` 11111.

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`SYS0-1`](dictionary/by-encoding.md#SYS0-1).

**Operation**

```
if condition cc holds on the flags then take the CHECK trap
    EPC ← address of the next instruction ; EVA ← address of this instruction
```

**Flags** None written.

**Exceptions** The `CHECK` trap, when the condition holds. A *trap*, not an abort: the instruction completes, `EPC` is the next instruction, and `RTI` resumes after the check.

*(D)* Errata 85 and 86: `TRAPCC` is a trap and not an abort, there is no compare-and-trap form, and the fused `ADDV`, `SUBV` and `MULV` carry the register-only cases. There is one word for each of the 14 conditions, in two bytes with no operand: the condition numbers are those of the branches (`ne` 1 ... `los` 14; `al` is not a word). After `ADD` the check for signed overflow is `TRAPCC.VS` (`docs/study-proposals.md` item 9 calls it `ADD; TRAPV`). `EVA` is the address of the `TRAPCC` itself, the one trap that defines it, so a handler need not decode backwards from `EPC`. Open: the number of the `CHECK` vector ([J.9.4](appendix-j-open.md#j94)).

**Why it is here.** A check that costs two bytes and no branch. The comparison with the alternatives is in the study (`docs/study-proposals.md` item 9): `ADD #1, 8(R2)` and a check is four plus two bytes and the add keeps its immediate and memory forms, where `ADD` and a `BVS` to a shared stub is six bytes and two instructions; and the same instruction checks what is not overflow (a bounds check after `CMP`, unsigned overflow after `ADD`). The OpenBSD kernels of i386, hppa and sparc64 already deliver integer-overflow traps as `SIGFPE` (`FPE_INTOVF`), so the signal route exists. The author made it a trap and not an abort (errata 85 and 86), so a handler that promotes a fixnum to a bignum can repair the register and resume; the one case where a trap defines `EVA`.

**Cf.** 6.4 (traps and aborts), docs/study-proposals.md item 9.

<a id="w-trapcc-ne"></a>
#### TRAPCC.NE

![TRAPCC.NE: SYS0, prefix 11101110010, sub-opcode 10000; operands no operand; 2 bytes](figures/w/trapcc-ne/01.svg)

Operation, flags and exceptions as for the entry TRAPCC above; 1 layout form, each a chart of its own (above).

<a id="w-trapcc-eq"></a>
#### TRAPCC.EQ

![TRAPCC.EQ: SYS0, prefix 11101110010, sub-opcode 10001; operands no operand; 2 bytes](figures/w/trapcc-eq/01.svg)

Operation, flags and exceptions as for the entry TRAPCC above; 1 layout form, each a chart of its own (above).

<a id="w-trapcc-pl"></a>
#### TRAPCC.PL

![TRAPCC.PL: SYS0, prefix 11101110010, sub-opcode 10010; operands no operand; 2 bytes](figures/w/trapcc-pl/01.svg)

Operation, flags and exceptions as for the entry TRAPCC above; 1 layout form, each a chart of its own (above).

<a id="w-trapcc-mi"></a>
#### TRAPCC.MI

![TRAPCC.MI: SYS0, prefix 11101110010, sub-opcode 10011; operands no operand; 2 bytes](figures/w/trapcc-mi/01.svg)

Operation, flags and exceptions as for the entry TRAPCC above; 1 layout form, each a chart of its own (above).

<a id="w-trapcc-vc"></a>
#### TRAPCC.VC

![TRAPCC.VC: SYS0, prefix 11101110010, sub-opcode 10100; operands no operand; 2 bytes](figures/w/trapcc-vc/01.svg)

Operation, flags and exceptions as for the entry TRAPCC above; 1 layout form, each a chart of its own (above).

<a id="w-trapcc-vs"></a>
#### TRAPCC.VS

![TRAPCC.VS: SYS0, prefix 11101110010, sub-opcode 10101; operands no operand; 2 bytes](figures/w/trapcc-vs/01.svg)

Operation, flags and exceptions as for the entry TRAPCC above; 1 layout form, each a chart of its own (above).

<a id="w-trapcc-cc"></a>
#### TRAPCC.CC

![TRAPCC.CC: SYS0, prefix 11101110010, sub-opcode 10110; operands no operand; 2 bytes](figures/w/trapcc-cc/01.svg)

Operation, flags and exceptions as for the entry TRAPCC above; 1 layout form, each a chart of its own (above).

<a id="w-trapcc-cs"></a>
#### TRAPCC.CS

![TRAPCC.CS: SYS0, prefix 11101110010, sub-opcode 10111; operands no operand; 2 bytes](figures/w/trapcc-cs/01.svg)

Operation, flags and exceptions as for the entry TRAPCC above; 1 layout form, each a chart of its own (above).

<a id="w-trapcc-ge"></a>
#### TRAPCC.GE

![TRAPCC.GE: SYS0, prefix 11101110010, sub-opcode 11000; operands no operand; 2 bytes](figures/w/trapcc-ge/01.svg)

Operation, flags and exceptions as for the entry TRAPCC above; 1 layout form, each a chart of its own (above).

<a id="w-trapcc-lt"></a>
#### TRAPCC.LT

![TRAPCC.LT: SYS0, prefix 11101110010, sub-opcode 11001; operands no operand; 2 bytes](figures/w/trapcc-lt/01.svg)

Operation, flags and exceptions as for the entry TRAPCC above; 1 layout form, each a chart of its own (above).

<a id="w-trapcc-gt"></a>
#### TRAPCC.GT

![TRAPCC.GT: SYS0, prefix 11101110010, sub-opcode 11010; operands no operand; 2 bytes](figures/w/trapcc-gt/01.svg)

Operation, flags and exceptions as for the entry TRAPCC above; 1 layout form, each a chart of its own (above).

<a id="w-trapcc-le"></a>
#### TRAPCC.LE

![TRAPCC.LE: SYS0, prefix 11101110010, sub-opcode 11011; operands no operand; 2 bytes](figures/w/trapcc-le/01.svg)

Operation, flags and exceptions as for the entry TRAPCC above; 1 layout form, each a chart of its own (above).

<a id="w-trapcc-hi"></a>
#### TRAPCC.HI

![TRAPCC.HI: SYS0, prefix 11101110010, sub-opcode 11100; operands no operand; 2 bytes](figures/w/trapcc-hi/01.svg)

Operation, flags and exceptions as for the entry TRAPCC above; 1 layout form, each a chart of its own (above).

<a id="w-trapcc-los"></a>
#### TRAPCC.LOS

![TRAPCC.LOS: SYS0, prefix 11101110010, sub-opcode 11101; operands no operand; 2 bytes](figures/w/trapcc-los/01.svg)

Operation, flags and exceptions as for the entry TRAPCC above; 1 layout form, each a chart of its own (above).
<!-- /entries:9.14 -->

## 9.15 Faults, restart and memory management

*Cf. chapter 6, section 6.4 (faults and restart) and sections 6.6 to 6.9 (memory management).*

**9.15.1** A fault is a trap, an abort, a progress stop in a block operation or a machine check, and every instruction either completes or is annulled and restarted with no state to undo (`MCPY` and its kin keep their progress in registers); the page-table format, the memory types and the translation registers are in the kernel chapter. *(D)*

**9.15.2** A fused instruction (`MOVCALL`, `POPRET`, `POPMRET`, `MOV2`) is restarted whole after a fault: no part of it is visible as a separate instruction. *(D)*

*Commentary.* The instruction-set consequence is the restart rule: the register update of an auto-increment mode is held until the instruction retires. **Impact.** *Kernel:* see 6.4. *Compiler:* no scheduling restriction arises from faults. *Hardware:* a single-entry undo buffer and a read-only walker.

## 9.16 Position-independent code

**9.16.1** Position-independent code costs nothing extra on this machine: every access to code or data in the same module is PC-relative by an ordinary addressing mode, so there is no GOT register and no prologue to set one up. *(D)*

**9.16.2** A call to an imported function is `CALLI got_slot(PC)` and a PLT stub is the single instruction `JMPI got_slot(PC)`; an imported variable's address is one `MOVQ got_slot(PC), Rd`. *(D)*

**9.16.3** A position-independent access to a global is no longer than an absolute one: four bytes within 32 KB and six within 2 GB, against six for a 32-bit absolute address. *(D)*

**9.16.4** The thread pointer is `DP`, so the local-exec thread-local model is one six-byte `MOVQ tls_offset(DP), Rd`. *(D)*

**9.16.5** A six-byte branch reaches ±4 GiB, so no linker veneers are needed for any binary smaller than that; the assembler's and the linker's branch relaxation both reduce to choosing a length. *(D)*

**9.16.6** `R12` is the linker's scratch register. The ABI (appendix D) decides that imports are called without a PLT stub. *(D)* Open: lazy against eager binding ([J.D.2](appendix-j-open.md#jd2)).

*Commentary.* **Precedent.** On i386 a position-independent executable reserved `%ebx` (one of eight registers) for the GOT base and set it in every prologue, which cost a few percent of size and speed; x86-64 fixed that with RIP-relative addressing, and AArch64 needs linker veneers because its branches reach only 128 MB. **Trade-offs.** The two-byte PC-relative form is the shortest, so position-independent data access is slightly smaller than absolute access; the price is a GOT load per imported call site where a PLT stub would cost a load per function. **Improvements.** Position-independence is a side effect of three decisions made for other reasons: PC-relative as an ordinary mode (adopted because the PC left the register file), variable-length encoding (for density) and `DP` (a 6502 zero-page descendant kept for density), which is exactly the thread pointer. **Benefits.** OpenBSD builds everything position-independent by default, and here that costs nothing. **Modern comparables.** x86-64 RIP-relative addressing; AArch64 `ADRP` with a GOT load and veneers for far calls. **Impact.** *Kernel:* a loader applies only relocations for data pointers, and write-xor-execute and randomisation come with no code penalty. *Compiler:* `-fPIE` is the default and emits the same instructions as `-fno-pic` for local data; no reserved register, no per-function setup. *Hardware:* nothing; the PC-relative mode is in the address adder already.

## 9.17 What was rejected

**9.17.1** The architecture refuses, by design, every feature that adds hidden state, an unbounded instruction, a second operand path or a mode bit that changes what other instructions mean. *(D)*

**9.17.2** From the PDP-11 and VAX it refuses general memory-to-memory operands, deferred addressing as a general form (only `JMPI` and `CALLI` are deferred), unbounded instructions with hidden microstate (`MOVC5`, `EDITPC`), packed decimal, hardware call frames (`CALLS`, `CALLG`), the PC as a general register, multiple floating-point formats, `POLY`, the `IOT`, `EMT`, `WAIT` and `RESET` instructions, a distinct low-half unsigned multiply, and the PDP-11's compare operand order. *(D)*

**9.17.3** From x86 it refuses partial-register writes that preserve upper bits, operand-size and `REX` prefixes, segmentation, flag writes that vary by instruction, implicit registers for multiply, divide and shift count, the x87 stack, transcendental instructions and byte-granular instruction fetch. *(D)*

**9.17.4** From the RISC family it refuses a register hardwired to zero (a thirty-second of a 32-register file), fused compare-and-branch in place of flags, branch delay slots, register windows and software-refilled translation buffers. *(D)*

**9.17.5** It also refuses features of its own invention: NUL-terminated string instructions (`MSCN` with an explicit maximum gives a bounded `strlen`), `CRC32` words (carry-less multiply is the primitive under every CRC), reciprocal-estimate instructions, NaN payload propagation, a 32-bit profile, an eight-byte instruction alignment, `MOVT` and `MOVK` partial-immediate inserts, hardware tag checking, store-with-write-barrier, a self-synchronising encoding, and a scalar instruction for sub-1-bit inference (the accelerator of chapter 8 does it). *(D)*

*Commentary.* **Precedent.** The VAX's `EDITPC` is a bytecode interpreter in microcode, and DEC needed a separate control chip for the PDP-11's commercial instruction set and shipped none; the VAX's hardware call frames ran slower than the equivalent sequence on later models; ARM32's `PC+8` and MIPS's delay slot expose one implementation's pipeline forever. **Trade-offs.** Each refusal gives up a real convenience: the lost `MOV (R1)+,(R2)+` copy loop, the byte-wide `ADDB`, the inline-argument `JSR`. Section 9.18 says what replaces each. **Improvements.** The common pattern is that a refused feature was either subsumed by a more general one (`MCPY` for the copy loop) or paid its cost in every implementation for a few users (`EDITPC`). **Benefits.** An instruction set a small in-order core can implement completely and a compiler can target without exceptions. **Modern comparables.** RISC-V and AArch64 also refuse memory-to-memory operands and delay slots; AArch64 keeps flags where RISC-V refuses them. **Impact.** *Kernel:* no instruction has a restart state except the three that keep their progress in architectural registers, so a fault is always restartable. *Compiler:* no special cases: every operand rule is uniform, one memory operand and the rest registers. *Hardware:* no microcode engine, no second operand path, no hidden-state latch, no alignment rotator in the fetch path.

## 9.18 Idioms: restored, lost and replaced

**9.18.1** Several idioms that the PDP-11 and VAX had and later RISC designs dropped are restored: subtract-one-and-branch (`SOB`, here in both directions), probe an address without faulting (`PROBER`, `PROBEW`), bit-field extract and insert, find-first-set (`CTZ`, `CLZ`), byte swap, block move, fill, compare and scan with their progress held in registers, the register-save mask (`PUSHM`, `POPM`, the useful half of `CALLS`), and carry-less multiply. *(D)*

**9.18.2** The VAX's counted-string instructions are largely present: `MOVC3` is `MCPY`, `CMPC3` is `MCMP`, `LOCC` is `MSCN`, `SKPC` is `MSCNN`, and `MOVC5` is `MCPY` plus `MSET`. Table-translated move, table scans and substring search are absent because a per-byte table lookup stops a block operation from streaming. *(D)*

**9.18.3** Deliberately lost, with their replacements: memory-to-memory `MOV` (replaced by `MCPY`); autoincrement-deferred and the dispatch-table idiom (replaced by `JTAG` for tag dispatch and a scaled-index `JMP` for the rest); `JSR Rn` and `RTS Rn` with inline arguments and cheap coroutines (replaced by `CALL` and `RET` with the return address on the stack where every unwinder and debugger expects it); the VAX `CASE` and `INDEX` instructions (replaced by a compare, branch and scaled `JMP`); byte and word ALU operations (`MOVZB`, the operation, `MOVB`: three instructions where the PDP-11 had one); and the flag set and clear instructions. *(D)*

**9.18.4** Subsumed, so not losses: `SXT` (the conversion moves), `SWAB` (`BSWAP`), `MARK` (the convention it served is gone), `ASH` and `ASHC` (the shifts take a register count), `MFPI` and `MTPI` (`PROBER` with the previous-mode bits and the user-memory guard), `MULU` (identical to `MUL` in the low half), and `ROL` (an assembler alias for `ROR`). *(D)*

**9.18.5** Measurements decide what is included, and the compiler uses more of the set than the first compiler did: `SET cc, rd`, `ABS`, `MIN` and `MAX` (the last three assembler aliases, 9.7.6), the bit-field instructions, the strided auto-increment modes and the scaled index are all emitted, and the fused pairs are 19,786 instructions of the corpus. *(D)*

**9.18.6** The compiler fuses a move before a call (`MOVCALL`), a pop before a return (`POPRET`, `POPMRET`) and two register moves (`MOV2`); the pairs are matched by dynamic programming after register allocation, two bytes saved a pair, 39,674 bytes (4.16%) in the corpus when fusion was first added. The mask of a `POPMRET` names `R8` to `R15`, so a save of `R24` to `R31` does not fuse.

**9.18.7** A dense `switch` is a jump table with eight-byte entries placed after the return (the analogue of the VAX `CASEL`); any other `switch` is a binary search, which costs 0.27% in static size and takes the opcode dispatch of Lua from 225.1 million to 148.7 million instructions executed. The jump tables are 3.4% to 5.0% fewer cycles on Lua in the timing model and 806 bytes smaller.

**9.18.8** Signed division by a power of two, and a pointer difference, are shifts; signed division and remainder of an `int` by a constant are a multiply and a shift (2 to 6 and 6 to 10 bytes longer than the plain code, 30% to 67% fewer cycles in micro-benchmarks). Unsigned and 64-bit division by a constant needs a `MULH`-based tree and is not done.

**9.18.9** An array index is scaled by the addressing mode and not by a shift and an add, including an index that is converted from a narrower type first (the inner loop of the `bs_ec` benchmark, 31% fewer instructions); a walk down an array is a strided post-increment; multiplication by 5 or 9 is a `LEA`.

*Commentary on 9.18.6 to 9.18.9.* **Precedent.** The VAX back end of the portable C compiler used `CASEL`, the autoincrement modes and `INDEX` for these jobs; this list is what survived of that table on this CPU. **Trade-offs.** Each pass was measured against its cost: the size-for-speed passes (division by constants, jump tables) lengthen the code a little and shorten the run a lot, and the static-single-assignment form was left off because it ran 3.2% to 5.1% slower in the timing model. **Impact.** *Kernel:* a switch in a driver or a system-call dispatch is a table. *Compiler:* every item is a switchable pass with its own flag, so a regression can be bisected. *Hardware:* none of these needs an instruction that the entries do not already describe.

*Commentary.* **Precedent.** The PDP-11's `JSR Rn` put the return address in a register of the caller's choosing, which made coroutines a pair of `JSR`s and inline arguments free; the VAX replaced it with `CALLS` and a frame, which was slower than the code it replaced. **Trade-offs.** The most frequently felt loss in hand-written code is the byte-wide read-modify-write; the compiler never notices it. **Improvements.** `SOB` branches either way, with four reaches; the block operations keep their progress in registers, which is what the VAX got wrong, so a fault restarts for free. **Benefits.** The code a compiler emits is the code the table above measures, and the extras are for the people who write assembler. **Modern comparables.** x86 keeps `LOOP` and the string instructions with `REP`; AArch64 has bit-field moves and no memory-to-memory forms; RISC-V has none of them in the base. **Impact.** *Kernel:* `PROBER` and `PROBEW` replace the `nofault` global in the user-copy routines. *Compiler:* idioms the compiler never emits are not built for it, so the compiler's instruction selection stays small. *Hardware:* each restored idiom is a few hundred gates of existing datapath, and each lost one is a decode that never existed.

## 9.19 Side by side: the PDP-11, the VAX and the pdp64

**9.19.1** The word is 64 bits against the PDP-11's 16 and the VAX's 32, the registers are 32, the virtual address is 39, 48 or 57 bits with 40 physical in the present implementation, and the instruction count is 304 instruction words in 268 leaves, against the VAX's 304. *(D)*

**9.19.2** The program counter is not a register, there is no argument pointer, and the frame pointer and the linker scratch are ordinary software conventions. *(D)*

**9.19.3** An instruction has one or two operands (three for the block operations) and at most one memory operand, against the PDP-11's two and the VAX's six. *(D)*

**9.19.4** The condition codes are the same four, `N`, `Z`, `V` and `C`; floating point is in the base and in the general registers, with three IEEE formats (half, single, double) and no mode bits that change the meaning of other instructions, where the PDP-11 had `FPS.FD`, `FL` and `FT` and the VAX had rounding bits in the status word. *(D)*

**9.19.5** An instruction is two, four or six bytes (one to three parcels of 16 bits), or ten with a 64-bit literal, against the PDP-11's two to six and the VAX's one to more than fifty. *(D)*

*Commentary.* **Precedent.** The PDP-11 and VAX instruction formats, with their encodings drawn side by side, are in the instruction-set text, section 13. **Trade-offs.** The pdp64 keeps what made the PDP-11 pleasant, orthogonal addressing and a small register set, and what made the VAX powerful, flags, a register-save mask and string operations, and drops what made both expensive: memory-to-memory operands and unbounded instructions. **Improvements.** The compiler's code averages 3.26 bytes an instruction on the 841-file corpus and 2.93 executed. **Benefits.** A processor that is smaller than either predecessor while running 64-bit code. **Modern comparables.** The closest family is AArch64 in the number of registers and addressing modes and RISC-V compressed in density; neither has flags and a variable length together. **Impact.** *Kernel:* the exception model is the PDP-11's with the VAX's per-mode stacks. *Compiler:* one memory operand makes instruction selection a register-allocation problem, as on a RISC. *Hardware:* a decoder that finds the length from a prefix of the first parcel, and no microcode.

## 9.20 What was taken from LoongArch, and what was not

**9.20.1** LoongArch64 is the most recent clean-room instruction set designed without an ideological commitment: it borrowed from MIPS, RISC-V and ARM as each had the better answer, which is the posture of the pdp64.

**9.20.2** Adopted from it: bit manipulation in the base (`CLO`, `CLZ`, `CTZ`, bit-field moves, byte reverse), atomics with the barrier folded in (the `_DB` variants), a richer atomic set (fetch-and-minimum and maximum), and memory type as a page attribute, and 32 registers, which the prefix-coded encoding has the bits for. *(D)*

**9.20.3** Declined, with reasons: `R0` hardwired to zero (a thirty-second of a 32-register file, and `CLR` and `NEG` are one parcel already); no condition codes (a third read port in the branch unit against a four-bit latch); `FCSR` rounding-mode bits (hidden state that changes other instructions); four PC-relative address-formation instructions (one `LEA` carries 32 bits); and separate vector register files (chapter 8). *(D)*

Open: whether a flag-reading conditional select is added ([J.9.1](appendix-j-open.md#j91)) and how floating-point comparisons set flags ([J.9.9](appendix-j-open.md#j99)).

**9.20.4** A branch-free conditional select for constant-time code, `MASKEQZ` and `MASKNEZ`, is adopted, and so is the bit select `BSEL` (9.9.6). *(D)*

*Commentary.* **Precedent.** LoongArch has a fixed 32-bit encoding with room for two register fields and a displacement, so it can afford compare-and-branch and needs four instructions to form an address; this machine's variable length reverses both trade-offs. **Improvements.** The same idea is right or wrong depending on the encoding around it, and each adoption is judged against this encoding. **Benefits.** Borrowing the tested parts saves design time and avoids their bugs. **Modern comparables.** LoongArch itself; the RISC-V bit-manipulation extensions (Zbb, Zbs) do much of the same. **Impact.** *Kernel:* atomics with barriers make a lock acquire one instruction. *Compiler:* bit operations in the base mean the compiler can use them without a feature test. *Hardware:* each adopted idea is a few hundred lookup tables and each declined one is a block not built.

## 9.21 What is still open in the instruction set

**9.21.1** Open, each with its discussion in appendix J: the displacement of the shortest scaled-index form and a store through `d(DP)` ([J.9.5](appendix-j-open.md#j95)); the page-bit mechanisms and the reserved system words ([J.9.6](appendix-j-open.md#j96)); the schedule of landing pads and lazy against eager binding in the ABI ([J.D.2](appendix-j-open.md#jd2)); the worst-case latency of the block operations ([J.9.7](appendix-j-open.md#j97)); the block operations and the cache ([J.9.8](appendix-j-open.md#j98)); the floating-point condition flags ([J.9.9](appendix-j-open.md#j99)); directed rounding and the remaining half-precision operations ([J.9.10](appendix-j-open.md#j910)); the conditional select and the expansion of `ABS`, `MIN` and `MAX` ([J.9.1](appendix-j-open.md#j91)); constant-time execution ([J.9.2](appendix-j-open.md#j92)); the operand placement of the atomics and the size of `CAS` ([J.9.3](appendix-j-open.md#j93)); and the coherence protocol beyond four cores with the verification of the memory model ([J.9.11](appendix-j-open.md#j911)).

**9.21.2** Settled: the instruction length (one to three parcels, with `MOVQL` the one exception), the prefix code in place of a reserved-opcode map, and UTF-8 scope (`MVAL` is committed). *(D)*

**9.21.3** Open in the encodings: the number of the `CHECK` vector and the register form of `ADDV`, `SUBV` and `MULV` ([J.9.4](appendix-j-open.md#j94)); the poison bit, the specification of the user-qualified moves, and the semantics of the AES and SHA words ([J.9.12](appendix-j-open.md#j912)).

*Commentary.* **Trade-offs.** None of the open items blocks the first implementation; the three that must be settled before silicon, the memory model verification, the coherence choice and the worst-case latency figure, are verification tasks, not design changes. **Impact.** *Kernel:* the open items touching the kernel are the page-bit mechanisms, the floating-point flags and the block-operation granularity. *Compiler:* the conditional select and directed rounding are the two open items that change instruction selection. *Hardware:* the coherence protocol must be chosen before the cache is built, not after.
