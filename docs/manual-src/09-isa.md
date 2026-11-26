# {{c:id01009|n}}. The instruction set

[← manual index](00-index.md)

**The instruction set is built around one idea: the first parcel of an instruction says both what the instruction is and how long it is, so the commonest instructions are two bytes and nothing is longer than six, one literal excepted.** The chapter covers how the opcode space is divided into prefix-coded leaves, the properties and principles that hold throughout, the registers, the format and the addressing modes, each group of instructions, faults, restart and memory management, position-independent code, what is rejected, the idioms of the PDP-11 and VAX that are restored, lost or replaced and the idioms of the compiler, the comparison with the PDP-11 and VAX, and what is taken from LoongArch. Every instruction has its entry (syntax, bit-layout chart, operation, exceptions) in the section of its group below; the atomic instructions are in section {{r:atomics-and-ordering}} and the system instructions in section {{r:isa-system-instructions-exceptions}}; the [reference tables](dictionary/index.md) hold the aliases, the constants, the lists of mnemonics and the chart of every leaf. The grammars the tools are generated from are described in [`../../spec/README.md`](../../spec/README.md); every number here comes from them or from the measurements cited.

## {{#how-the-opcode-space-is-divided}} How the opcode space is divided

**{{#every-instruction-begins}}** Every instruction begins with a 16-bit parcel (the unit of instruction encoding), and the first parcel alone fixes what the instruction is and how long it is: its top 3 to 16 bits are a prefix, and the prefix selects a leaf.

**{{#leaf-is-a-group}}** A leaf is a group of mnemonics that share one form. A form lists the operand shapes (how each operand is written in assembly, and how many bits each part of it has); the leaf fixes where every field lies. After the prefix comes the sub-opcode, which selects one mnemonic of the leaf, and then the pieces of the operands: register fields from bit 0 of the first parcel upward, the last register operand lowest, displacements and immediates after them, the widest field last. No bit is padding. The encoding has 182 forms in 240 leaves.

**{{#prefixes-form-a-prefix-code}}** The prefixes form a prefix code (a set of bit strings none of which begins another, so that the first parcel matches at most one leaf and the match needs no look-ahead). The lengths were chosen by an optimiser that was given the compiled corpus, so the shortest prefixes belong to the forms the compiler emits most.

**{{#leaf-is-one-two-or}}** A leaf is one, two or three parcels long, which is two, four or six bytes; 32, 138 and 69 of the leaves are of those lengths. One leaf, the move of a 64-bit constant (`MOVQ #imm64, Rd`), is five parcels (ten bytes) because it carries a 64-bit literal.

**{{#illegal-first-parcel-patterns}}** 3,278 of the 65,536 patterns of a first parcel (5.0%) match no prefix and are illegal instructions; so is a sub-opcode that no mnemonic uses and a hot-register index beyond the table ({{r:one-parcel-form-register-index}}), so that a wild jump fails early and nothing is undefined.

**{{#assembly-language-and-the-mnemonics}}** The assembly language and the mnemonics of the PDP-11 are kept for the instructions that the machine keeps; `CMP`, `TST`, `BIT`, `ADC`, `SBC`, the flag branches and the instructions that set and clear flags are not among them, because there are no flags ({{r:machine-has-no-condition-codes}}). The leaves add words to them: the compare-and-branch family (`CBCC` for integers, `FCBCC` for floating point) and the compare into a register (`SETCC`), the four fused pairs (`MOVCALL`, `POPRET`, `POPMRET`, `MOV2`), `MASKEQZ` and `MASKNEZ`, `BSEL`, the checked arithmetic `ADDV`, `SUBV` and `MULV`, the user-qualified moves (`.U`, seven words), and the seven AES and eight SHA words.

*Commentary.* **Precedent.** The PDP-11 partitioned its opcodes by the addressing modes of the first word; the VAX by operand specifiers parsed in sequence; x86 by prefixes, opcode, ModR/M and SIB read one after another. The prefix code is the device of a Huffman code (the commonest symbols get the shortest strings) applied to the first parcel, with the length of the instruction as a by-product of the match. **Trade-offs.** The decoder reads up to 16 bits to find the length. In the timing model the decoder pays one cycle of length-decode latency on every taken branch and refill, and fetch-wait is 7.2% of the cycles at four bytes per cycle. What the prefix buys is density: the 841-file corpus is 964,158 bytes, 3.26 bytes an instruction, and the instructions executed fall with the compiler and the fused pairs (appendix {{c:id03006|n}}, {{r:encoding-the-measurements}}). **Improvements.** Every bit is a prefix, sub-opcode or operand bit, so an unused code is an illegal instruction and not a silent no-op; the fields of every leaf come from the grammar, so no table is written twice. **Benefits.** The common operations, a register move, a load from the stack, a branch on a register against zero, cost two bytes with no look at a second parcel, and the rare ones are as long as they need to be. **Modern comparables.** Thumb-2 and RISC-V's compressed instructions mix 16- and 32-bit forms with the length in a few bits; x86 finds the length by parsing; the prefix code here is the general case of the first and avoids the second. **Impact.** *Kernel:* nothing in the kernel depends on the opcode map; a debugger and the fault handler's step-over read the same generated table as the assembler. *Compiler:* the cost model charges 2, 4 or 6 bytes (10 for `MOVQ` of a 64-bit constant) and knows which operands fit a one-parcel form, the hot registers above all ({{r:one-parcel-form-register-index}}). *Hardware:* the length is a function of up to 16 bits of the first parcel, a lookup in the fetch path; a front end that decodes several instructions a cycle needs such a lookup at each parcel position, a cost that the timing model does not measure beyond the one cycle above.

## {{#properties-and-principles}} Properties and principles

**{{#length-of-an-instruction}}** The length of an instruction is a function of its first parcel alone: the prefix selects the leaf, and the leaf has 1, 2 or 3 parcels, for 2, 4 or 6 bytes.

**{{#at-most-one-memory-operand}}** At most one operand of an instruction may be a memory reference; the other, where present, is a register. The block operations are the one admitted exception.

**{{#no-instruction-is-longer-than}}** No instruction is longer than six bytes, with one exception: `MOVQ #imm64, Rd` carries a 64-bit literal and is ten bytes, the literal not being counted as part of the instruction.

**{{#register-is-always-written}}** A register is always written in full: narrow loads sign- or zero-extend, and there is no partial-register write.

**{{#anything-that-changes-what}}** Anything that changes what an instruction means is, by default, visible state set by an instruction that names it, not hidden state; whether a mode bit is worth its cost is decided case by case. Compatibility is by conversion instructions where that is cheap.

**{{#every-instruction-can-be-restarted}}** Every instruction can be restarted after a fault, and exceptions are precise; the machine has no hidden instruction state that a program can see. The one exception is the hidden resume record of a vector block that an exception interrupted: a program sees nothing of it except its token and the time it saves, an implementation need not keep one, and it is discarded as {{r:vector-block-that-an-exception}} says, after which the block starts again from its first strip.

**{{#floating-point-is-done}}** Floating point is done in the general registers; there is no separate floating-point register file.

**{{#isa-memory-is-sequentially-consistent}}** Memory is sequentially consistent between processors.

**{{#alu-has-one-width-64}}** The ALU has one width, 64 bits; sizes appear only on loads, stores and conversions.

**{{#addresses-are-canonical-39-48}}** Addresses are canonical: 39, 48 or 57 bits of virtual address, according to the three, four or five levels of the page table ({{r:virtual-addresses-are-translated}}), and a physical address of 40 to 64 bits, 40 in the present implementation ({{r:no-bit-of-the-physical}}).

**{{#instructions-are-aligned-to-two}}** Instructions are aligned to two bytes; a plain load or store works at any address, aligned or not ({{r:plain-access-at-any-address}}), and the atomics, the operands of the vector blocks and `PUSHX` and `POPX` keep the alignment fault, as does a plain access that is not aligned to its size to strongly ordered device memory ({{r:strongly-ordered-device-access-faults}}).

**{{#instruction-does-what-its-name}}** An instruction does what its name says and nothing else: it writes its result and leaves nothing behind, because the machine has no condition codes for it to leave.

**{{#measured-on-the-841-file}}** Measured on the 841-file corpus of the compiler (instruction bytes, `as64 --stats`), the output of the compiler is 964,158 bytes in 296,070 instructions (3.26 bytes an instruction); over six large programs the average is 2.934 bytes an executed instruction ({{r:how-the-encoding-was-chosen}}). The fused pairs account for 19,786 instructions of the corpus. Linker relaxation ({{r:assembler-cannot-know-the-distance}}) takes a further 3.76% off the text of the corpus. The tables and their provenance are in appendix {{c:id03006|n}}.

*Commentary.* **Precedent.** {{r:at-most-one-memory-operand}} is x86's ModR/M idea made architectural; it is also what lets the exception machinery be small (the PDP-11 recorded at most two register side effects per instruction because it had two specifiers; with one memory operand there is at most one). {{r:every-instruction-can-be-restarted}} exists because the Motorola 68000, which was very nearly this machine, could not restart an instruction after a bus error and so could not do demand paging until its successor retrofitted a fault model. {{r:register-is-always-written}} is the rule x86-64 adopted for 32-bit writes and failed to apply to the 8- and 16-bit forms. {{r:floating-point-is-done}} is the arrangement RISC-V standardised as Zfinx. **Trade-offs.** {{r:alu-has-one-width-64}} means narrow arithmetic is done wide and converted, which costs an extension instruction after some narrow operations. {{r:isa-memory-is-sequentially-consistent}} is the cheapest model on a small in-order core and the most expensive on a large speculative one. {{r:addresses-are-canonical-39-48}} lets the page table have three levels, as RISC-V's Sv39 does, or four or five as x86-64, AArch64 and Sv48 and Sv57 do, at a longer walk for each level. **Improvements.** The rules are soft defaults: each says what it protects and what breaking it costs. **Benefits.** Together they make the machine small, restartable and easy for a compiler; the measured code size is in chapter {{c:id01001|n}}. **Modern comparables.** AArch64 and RISC-V have fixed-length register-to-register encodings and weak memory models; x86-64 has memory operands and total store order; the pdp64 takes memory operands, strong ordering and a bounded fault surface. **Impact.** *Kernel:* Restartable instructions and precise exceptions mean a page-fault handler repairs the mapping and returns, with no instruction-specific cases, and sequential consistency means no barrier code. *Compiler:* One memory operand keeps instruction selection and register allocation simple; a register written in full removes partial-register merges; the single ALU width costs an extension instruction after some narrow arithmetic. *Hardware:* One address generator, at most one register side effect, a single-entry undo buffer, no byte-lane multiplexing and a length that is a lookup on one parcel are what keep the die small.

## {{#state-registers-and-status-word}} State: registers and the status word

**{{#there-are-thirty-two-64}}** There are thirty-two 64-bit general registers, `R0` to `R31`. `R14` is the stack pointer `SP`, with three copies (kernel, supervisor, user) chosen by the current mode; `R13` is the frame pointer by convention only; the others carry no meaning to the hardware.

**{{#program-counter-is-not}}** The program counter is not a general register, and `R7` is an ordinary general register, not a view of the program counter; the program counter is read with `LEA 0(PC), Rn`.

**{{#processor-status-word-is-16}}** The processor status word is 16 bits.

![{{#isa-fig-processor-status-word}}The processor status word](figures/psw.svg)

(Bit positions: `T` 4, priority 5-7, current mode 8-9, previous mode 10-11. Bits 0 to 3, which held `C`, `V`, `Z` and `N` on the PDP-11, are reserved and read as zero.)

**{{#status-word-has-no-condition-codes}}** The machine has no condition codes: no instruction writes or reads `N`, `Z`, `V` or `C`. The PDP-11 set them as a side effect of nearly every instruction and branched on whatever the last instruction had left; here every decision is a compare-and-branch that compares two values and branches in one instruction ({{r:branches-and-control-flow}}), a comparison that is wanted as a number is `SETCC` ({{r:setcc-writes-zero-or-one}}), and every ALU instruction writes its result and nothing else. `MFPS` returns bits 0 to 3 as zero, and `MTPS` is privileged, because there is no part of the status word that user mode may write. The only flags that remain are the five sticky exception flags of the floating-point register `FPSR` ({{r:five-ieee-flags-invalid-divide}}), which are not condition codes: no branch reads them.

**{{#dp-the-direct-page-base}}** `DP`, the direct-page base, has three copies by mode. It makes `d(DP)` an address form that needs no base register (a 28-bit displacement in six bytes; the grammar has loads through `d(DP)` and no store); in kernel mode it is the per-CPU pointer, and in user mode the thread pointer.

**{{#other-special-registers}}** Other special registers: `FPSR` (five sticky floating-point flags), `ASID`, `PTBR`, `EPC`, `EPSW`, `EVA`, `ECAUSE`, `VBR`, `MMUCTL`; the system registers are read and written by `MFSR` and `MTSR` with an 8-bit register number.

**{{#bit-dit-in-the-status}}** A bit `DIT` in the status word promises data-independent timing: while it is set no data-dependent timing effect of any kind remains, neither in instruction latency (divide, `MSCN`, `MCMP` and floating point included), nor in frequency or power management (a core that scales frequency holds it steady while the bit is set, or says in a feature register that it cannot), nor from any data-dependent prefetcher or value predictor (a core may have one, but it is off while the bit is set). User code may set it for its own use.

**{{#register-save-mask-pushm-popm}}** A register-save mask (`PUSHM`, `POPM`, `POPMRET`) names the registers by bit: bit n is `R`n, and the mask is 32 bits. The forms carry the mask in 8 bits (two bytes), 16 or 24 bits (four bytes) and 32 bits (six bytes); the fused `POPMRET` has an 8-bit field scaled by 256, which names `R8` to `R15` and no other register. A mask containing `R14` is reserved. Masks are written in binary with the hexadecimal in brackets: the mask of `R8` to `R11` is `0000 1111 0000 0000` (0x0F00), and the 8-bit field of `POPMRET` that names `R8` to `R15` is `1111 1111` (0xFF, which is 0xFF00 as a mask).

**{{#r16-to-r31-are-ordinary}}** `R16` to `R31` are ordinary registers to the hardware. `R24`, `R25` and `R26` are among the sixteen hot registers of the four-bit fields ({{r:one-parcel-form-register-index}}).

*Commentary.* **Precedent.** The PDP-11's PC and SP were ordinary registers and its condition codes were set by nearly every instruction. The VAX put the PC in R15. **Trade-offs.** Keeping the PC out of the register file means a jump to a computed address uses `JMP`, not a write to a register, so that writing `SP` has no control-flow consequence and the hazard logic treats it like any other destination. There are no condition codes, a hidden register that every arithmetic instruction might write; the reason is given with the branches ({{r:machine-has-no-condition-codes}}). **Improvements.** The status word carries a user-memory guard bit ({{r:isa-system-instructions-exceptions}}) and the per-mode `DP` serves two jobs, the per-CPU pointer in the kernel and the thread pointer in user mode. **Benefits.** An exception handler finds a kernel stack and a per-CPU pointer without first searching for them; a threaded program's thread-local variable is one instruction. **Modern comparables.** x86-64 keeps `FS` and `GS` base registers for the same two jobs; AArch64 has `TPIDR_EL0` and `TPIDR_EL1`; RISC-V uses `tp` and the supervisor scratch register. **Impact.** *Kernel:* Banked stack and direct-page registers let entry find a kernel stack and a per-CPU pointer with no code, and the status word is saved by one `PUSHX`. *Compiler:* There is no condition-code state to track, so a comparison and its branch are one instruction and the compiler may schedule any instruction anywhere that the registers allow. *Hardware:* No condition-code rename targets and no flag latch to save and restore; the register file is 32 by 64 bits; the banked copies are a three-way mux.

## {{#instruction-format}} The instruction format

**{{#instruction-is-one-two-or}}** An instruction is one, two or three parcels (two, four or six bytes; `MOVQ` with a 64-bit constant is five parcels); the first parcel holds the prefix, the sub-opcode and the operand pieces that fit, and the later parcels hold the rest. The bit layout of every leaf is a chart in the [reference tables](dictionary/by-encoding.md).

**{{#instructions-are-parcel-aligned}}** Instructions are parcel-aligned and little-endian; an instruction may cross any boundary of 8 bytes, a cache line or a page.

**{{#most-instructions-are-two-or}}** Most instructions are two or four bytes. Register-to-register work and the whole conversion set are one parcel; so is a memory operand through a hot base register with a displacement of up to three bits, a load or store from the stack pointer at a small offset, and a constant of up to seven bits. A base register with a 12-bit displacement, a post-increment or pre-decrement with a 12-bit stride, a scaled index with a 6- or 8-bit displacement, a pc-relative address within ±32 KiB and an immediate of up to 18 bits are two parcels. Displacements to ±128 MiB, absolute addresses, 32-bit immediates and branches to ±4 GiB are three.

**{{#where-an-addressing-mode-names}}** Where an addressing mode names no base register (immediate, absolute, PC-relative), no field is spent on one: the later parcels are all value, so those modes reach 16 bits at four bytes and 32 bits at six.

**{{#constant-wider-than-32-bits}}** A constant wider than 32 bits is either written in the instruction, `MOVQ #imm64, Rd`, which is ten bytes with the literal in the four later parcels, or loaded from a literal pool with `MOVQ =K, Rd`, written with an explicit `=`; nothing is pooled silently. `MOVQ #imm` is one mnemonic for every size of constant: the assembler picks the two-, four-, six- or ten-byte form that holds it.

**{{#one-parcel-form-register-index}}** In a one-parcel form a 3-bit register field is not a register number but an index into a table of the eight hottest registers, `R0 R1 R8 R2 SP R3 R9 R10`. A 4-bit field indexes the sixteen hottest, `R0 R1 R8 R2 SP R3 R9 R10 R11 R4 R15 R5 R24 R25 R26 R6`. The tables are part of the ABI, and the compiler's register allocator prefers the hot registers.

*Commentary.* **Precedent.** The PDP-11 had the length in the first word, but as a function of both of its six-bit specifiers; Thumb-2 and RISC-V's compressed instructions mix 16- and 32-bit forms with the length in a few bits. Here the length and the identity of the instruction are one match on the prefix. **Trade-offs.** Byte-granular encoding, as in x86, buys perhaps a tenth of the code size and costs a full alignment rotator and cross-line splice logic in the fetch path on a 64-bit datapath; this CPU refuses it. A hot-register index buys a one-parcel form and costs a rule for the compiler: a value that lives in one of the eight (for the 4-bit fields, sixteen) hottest registers is cheaper to use, which the allocator learns, and the ABI cannot move the tables without changing the encoding. Forcing an instruction to stay inside an eight-byte window would simplify fetch and would cost 5% to 10% of code size in padding. **Improvements.** `MOVQ #imm64, Rd` takes a 64-bit constant in one instruction instead of a literal-pool load, at ten bytes against six, the literal not counting against the three-parcel rule. **Benefits.** The measured average is 2.7 to 3.3 bytes an instruction ({{r:measured-on-the-841-file}}). **Modern comparables.** AArch64 and RISC-V have fixed or two-length encodings; x86 has byte-granular ones; this CPU has parcel-granular ones with three common lengths. **Impact.** *Kernel:* a one-parcel form is cheaper in kernel text with no source change. *Compiler:* the assembler picks the shortest form, branch and call relaxation is a length choice, and the cost model knows 2, 4 and 6 bytes and which registers are hot. *Hardware:* the fetch unit has a parcel buffer and a length lookup on the first parcel; no instruction crosses more than two parcel-aligned windows of eight bytes except the ten-byte `MOVQ` of a 64-bit constant.

## {{#addressing-modes}} Addressing modes

**{{#addressing-mode-is-not}}** The addressing mode is not a field: it is the leaf, whose form lists the shape of each operand. The assembly language has the eight modes below, and the assembler gives each operand the shortest leaf that holds it.

| Syntax | Effect | One parcel | Two parcels | Three parcels |
|---|---|---|---|---|
| `d(Rn)` | base plus displacement | a hot base register with a displacement of 1 to 3 bits; `d(SP)` with a displacement of 4 to 7 bits | 8-, 10- or 12-bit displacement (scaled by the size of the access in most forms) | 28-bit signed displacement, ±128 MiB |
| `d(Rn)(Rx*s)` | scaled index, `s` in {1, 2, 4, 8} | none | 6- or 8-bit displacement, or none with a 5-bit base and index | 22-bit displacement |
| `d(PC)` | PC-relative; the base is the first parcel of the instruction | none | 12-, 14- or 16-bit byte displacement: ±2 KiB, ±8 KiB, ±32 KiB | 32-bit displacement, ±2 GiB |
| `d(DP)` | direct page, loads only | none | none | 28-bit displacement |
| `#imm` | immediate, sign-extended | 3 to 7 bits | up to 18 bits | 32 bits (a `MOVQ` of a wider constant: 64 bits, five parcels) |
| `@abs` | absolute, sign-extended | none | none | 32-bit address |
| `(Rn)+d` | post-increment by a stride `d` (0: the operand size) | none | 12-bit stride | none |
| `-(Rn)` or `(Rn)-d` | pre-decrement by a stride (0: the operand size) | none | 12-bit stride | none |

**{{#deferred-modes-of-the-pdp}}** The deferred modes of the PDP-11 are removed; indirection is done with `JMPI`, `CALLI` and a load.

**{{#at-most-one-register-side-effect}}** At most one register side effect occurs per instruction, and it is committed at retirement; a fault discards it.

**{{#pc-relative-operand-is-measured}}** A pc-relative operand is measured in bytes from the first parcel of the instruction; the field counts bytes for a memory operand and parcels for a branch or call. A branch has a field of 6 to 9 bits in one parcel (±64 to ±512 bytes), 16 bits in two (±64 KiB) and 32 bits in three (±4 GiB); a `CALL` has 18 bits in two parcels (±256 KiB) and 32 in three; a `LEA` or a load through `d(PC)` reaches ±2 KiB to ±32 KiB in two parcels and ±2 GiB in three. The dictionary lists the width and reach of every operand shape.

**{{#assembler-cannot-know-the-distance}}** The assembler cannot know the distance to a symbol in another object, so it writes such a `CALL` or `LEA` of a data symbol in its long form (six bytes) with a relocation; the linker lays out the sections, gives each such instruction the shortest form that reaches (a 4-byte `CALL` within ±256 KiB, a 4-byte `LEA` or pc-relative load within ±32 KiB, a 4-byte `JMP` or `MOVCALL` within ±64 KiB) and moves everything behind it. It grows each instruction from its shortest form, so the lengths only grow and the iteration ends. Relaxation is on by default; `as64 --no-relax` and `ld64 --no-relax` give the unrelaxed bytes.

*Commentary on {{r:addressing-mode-is-not}}, {{r:pc-relative-operand-is-measured}} and {{r:assembler-cannot-know-the-distance}}.* **Precedent.** The PDP-11 chose the mode in each six-bit specifier; x86 chooses it in ModR/M and SIB; here the leaf chooses it, and the cost of a mode is the length of the leaf that has it. **Trade-offs.** The scaled index is the thin case: its shortest form has a 6-bit displacement, and `d(DP)` has only the six-byte load form, so a thread-local access through `DP` costs six bytes. Relaxation turns the assembler's guess into the linker's measurement: it saved 3.76% of the text of the corpus (an upper bound for the reach of the 4-byte call, since the corpus stub places symbols right behind each file) and 1.65% of the linked text of the six large programs; external calls, 6 bytes each, are the bulk. **Improvements.** The stride of the post-increment and pre-decrement is the same field in every leaf, so an array of 16-byte records is one instruction per element; the scaled index takes a conversion of a narrower index in the compiler (`bs_ec`'s inner loop, 31% fewer instructions). **Benefits.** An object file from `as64` is correct without relaxation and smaller with it, and a program linked either way produces the same output on the six large programs. **Modern comparables.** RISC-V's linker relaxes `call` and `lui`/`addi` pairs for the same reason; AArch64 needs linker veneers for far branches. **Impact.** *Kernel:* the kernel is relaxed like any other program, and text near the reach limits is smaller by the 4-byte forms. *Compiler:* it emits the long form for an external symbol and leaves the choice to the linker; it prefers scaled index and strided autoincrement where its loops allow (appendix {{c:id03006|n}}, {{r:encoding-the-measurements}}). *Hardware:* nothing: the address adder takes a field and a base in every leaf.

*Commentary.* **Precedent.** The PDP-11 had eight modes for each of eight registers, with a deferred flavour of each, and it made `*p++` and `*--p` single instructions. **Trade-offs.** Dropping the deferred modes removes the case where a fault occurs after a register has been updated at an address that itself came from a load; keeping the strided autoincrement costs nothing, because the undo information was already a delta (the PDP-11's `MMR1` recorded an amount for the same reason). **Improvements.** The increment is a stride, so walking an array of 16-byte records is one instruction; the PC-relative modes count from the instruction itself, so a branch needs no adjustment and `LEA` reads the PC. **Benefits.** Address generation is one adder pass, never load-then-add, which is the difference between one cycle and a long path on an FPGA. **Modern comparables.** AArch64 has pre- and post-indexed forms with an immediate; x86 has scaled index with a base; RISC-V has base plus immediate only. **Impact.** *Kernel:* A strided autoincrement walks a table of records, and `d(DP)` reaches the per-CPU structure in one instruction. *Compiler:* The modes match C idioms (`*p++`, `a[i]`) one-to-one, and dropping the deferred modes removes the cases the selector would otherwise have to consider. *Hardware:* Address generation is one adder pass, never load-then-add, and the PC-relative base is the first parcel, so no adjustment is needed.

## {{#moves-conversions-and-address-formation}} Moves, conversions and address formation

<!-- notation -->
<!-- /notation -->

*Cf. section {{r:page-table-entry}} for the memory types that decide whether an access is cached, and section {{r:faults-and-restart-what-precise-means}} for what a faulting load leaves behind.*

**{{#movq-movl-movw-and-movb}}** `MOVQ`, `MOVL`, `MOVW` and `MOVB` load and store 64, 32, 16 and 8 bits; the loads sign-extend. `MOVZL`, `MOVZW` and `MOVZB` load with zero extension.

**{{#register-operand-the-same-opcodes}}** With a register operand, the same opcodes are the conversion set: `MOVB R1, R2` sign-extends the low byte, `MOVZW R1, R2` zero-extends the low word.

**{{#lea-forms-an-effective-address}}** `LEA` forms an effective address; `LEA 0(PC), Rn` reads the program counter.

**{{#moves-loads-and-stores-write}}** A move, a load or a store writes its destination and nothing else.

**{{#plain-access-at-any-address}}** A plain load or store works at any address in memory: there is no alignment fault for memory, and so no separate unaligned move. The one place it does not is strongly ordered device memory, below. A plain access is a `MOV` form and any instruction whose memory operand is read or written once (the stack, the arithmetic with a memory operand, the read-modify-write forms). An access that is not aligned to its size is one access for the program and, where it crosses a boundary of a cache line or of a page, two for the machine; the core that executes it sees it whole, and **nothing of it changes if any part of it faults**: a store that crosses into a page that faults writes none of its bytes, a load that does leaves its destination register as it was, and the fault is precise on whichever page refuses it, with `EVA` the address of the access when its first page refuses and the first byte of the second page when that one does. To the other cores and to devices the two halves are two accesses, in ascending address order ({{r:quad-accesses-are-naturally-aligned}}). The atomics keep the alignment fault ({{r:atomic-word-must-be-naturally}}); so do `PUSHX` and `POPX` and the operands of the vector blocks, and the block copies move bytes and have none to make. Normal cached and uncached memory and device weakly ordered memory (memory types 0, 1 and 2, {{r:memory-type-of-a-page}}) take such an access as just described. Strongly ordered device memory (type 3) does not: every access to it goes to the device in the order written, one at a time and never combined, so an access that is not aligned to its size would be two transactions on the device, a clear-on-read register read twice or a data register written in halves. A plain access that is not aligned to its size to a page of that type takes the misalignment fault, precise, with nothing performed: no byte read or written, no register of the device touched, the destination register as it was, `EVA` the address of the access and `EPC` the instruction ({{r:strongly-ordered-device-access-faults}}). The registers of a device are accessed at their own width ({{r:registers-are-naturally-aligned}}), so a driver that maps them as the device type never meets the fault.

**{{#strongly-ordered-device-access-faults}}** An access that touches two pages is judged by the stricter of the two: if either page is strongly ordered device memory and the access is not aligned to its size, it takes the misalignment fault, however little of it lies in that page. The memory type of a page is the stricter of its types in the stages of translation that map it (the larger code), and with translation off the address decides: a physical address at which a device answers is strongly ordered.


**{{#a-mis-tagged-pointer-is-not-a-fault}}** A runtime that keeps a 3-bit type tag in the low bits of a pointer cannot rely on a fault to find a pointer with the wrong tag: the access through it simply works, at an address that is not aligned. The check is explicit and is one four-byte instruction, `BNTAG Rn, #T, slow`, placed before the access, which is then made with the tag taken off by the displacement, `MOVQ k-T(Rn), Rd`; on the way that has the right tag the branch is not taken. One check covers every access made through the same pointer, so a cell whose `car` and `cdr` are both read is checked once; and where a loop already tests its pointer (a list walk that tests for the end) `BTAG` makes that test and the type check at once, so the check costs nothing. An array index is bounds checked by `CTCC` as before, and a pointer whose tag is checked before a loop is not checked again inside it. A table dispatch on the tag is `JTAG`.

**{{#one-parcel-forms-abbreviate}}** The one-parcel forms abbreviate the common cases: loads and stores through a hot base register or the stack pointer at small offsets, `LEA` from `SP`, and `MOVQ #imm, rd` with an immediate of up to seven bits.

**{{#load-may-be-qualified-u}}** A load or store may be qualified `.U` (the memory operand is accessed with user privilege, which is how the kernel reaches user memory past the user-memory guard of {{r:user-memory-guard-and-system-calls}}); the block copy has the same qualifier for each of its sides, `MCPY.UR` and `MCPY.UW`.

*Commentary.* **Precedent.** The PDP-11 had `MOV` and `MOVB` with a byte sign-extended into a register; the VAX had a sized `MOV` for every width. **Trade-offs.** Keeping the sized loads costs four extra opcodes against a quad-only design, but without `MOVL` a struct field load becomes two `MOVW`s, a shift and an or, and ELF, timestamps and most on-disk and wire structures are full of 32- and 16-bit fields. **Improvements.** There is no separate `CVT` group: the conversions are the moves with a register source, so they cost nothing. **Benefits.** No partial-register state anywhere. **Modern comparables.** AArch64 and RISC-V have the same sized loads with sign and zero extension; x86-64 keeps 8- and 16-bit register writes that preserve the upper bits, which makes narrow writes depend on the old value. **Use.** `LEA 0(PC)` is how a position-independent program finds itself; a plain load reads a packed on-disk or network structure at whatever address it has. **Impact.** *Kernel:* `LEA 0(PC)` lets position-independent kernel code find itself; the plain moves read packed on-disk and network structures where they lie. *Compiler:* Sized loads avoid the shift, mask and or of a struct-field read, and the conversions are moves, so no separate conversion selection exists. *Hardware:* No partial-register write anywhere; the conversions reuse the load-extend path.

<!-- entries:{{r:moves-conversions-and-address-formation}} -->
<!-- /entries:{{r:moves-conversions-and-address-formation}} -->

## {{#integer-arithmetic}} Integer arithmetic

*Cf. section {{r:exceptions-interrupts-and-traps}} for the divide-by-zero vector (`DIV`, `DIVU`, `MOD`, `MODU`).*

**{{#add-sub-mul-and-mulh-are-two-bytes}}** `ADD`, `SUB`, `MUL` and `MULH` are two bytes with register operands; `MULHU` (high half of an unsigned product), `DIV`, `DIVU`, `MOD` and `MODU` are in the arithmetic escape.

**{{#comparison-is-cbcc-or-setcc}}** There is no compare instruction that leaves its answer in a flag: `CBCC` compares and branches ({{r:cbcc-compares-a-register}}) and `SETCC` compares and writes 0 or 1 ({{r:setcc-writes-zero-or-one}}). In both the left operand is written first, `cblt Ra, Rb, L` branching when `Ra < Rb`.

**{{#add-and-sub-write-only-the-result}}** `ADD` and `SUB` write their result and nothing else. The carry out of an addition and the borrow of a subtraction are not kept anywhere: when a program wants one it computes it as a comparison, as {{r:multi-word-arithmetic-without-a-carry}} shows.

**{{#single-operand-forms}}** `INC`, `DEC`, `NEG` and `CLR` are single-operand forms that work on a register or memory.

**{{#setcc-writes-zero-or-one}}** `SETCC Ra, Rb, Rd` (or `SETCC Ra, #imm, Rd`) writes 1 into `Rd` if the comparison holds and 0 if it does not, for the ten conditions of the compare-and-branch: `SETEQ`, `SETNE`, `SETLT`, `SETLE`, `SETGT`, `SETGE` and the unsigned `SETCS` (lower, also `SETLO`), `SETCC` (higher or the same, also `SETHIS`), `SETHI` and `SETLOS`. It is how a comparison used as a value is written. The immediate is 8 bits, signed, and is sign-extended to 64 bits for the unsigned conditions too; the instruction is four bytes, and the destination may be one of the sources.

```
        setlt   r1, r2, r3      ; r3 = 1 if r1 < r2 (signed), else 0
        setlos  r1, #9, r4      ; r4 = 1 if r1 <= 9 as an unsigned number
```

**{{#abs-min-minu-max}}** `ABS`, `MIN`, `MINU`, `MAX` and `MAXU` are assembler aliases, not native instructions: `ABS` is the absolute value, and the others the smaller or the larger of two registers, signed or unsigned.

**{{#range-check-on-a-register}}** A range check on a register value, such as an array index, is made with `CBCC` ({{r:cbcc-compares-a-register}}; one unsigned compare tests `0 <= i < n`, because a negative index is a large unsigned number) or with the compare-and-trap words `CT<cc>` ({{r:isa-system-instructions-exceptions}}), which keep a table of check sites, with the trap-if-zero and the two-bound check `CHK2`; `ADDV`, `SUBV` and `MULV` check signed overflow.

**{{#multi-word-arithmetic-without-a-carry}}** A number wider than a register is added a register at a time, and the carry out of one word must reach the next. On the PDP-11 every `ADD` left its carry in the `C` flag, and `ADC` (add carry) added that flag into the next word; a double-word addition `a1:a0 += b1:b0`, with `a1:a0` in `r3:r2` and `b1:b0` in `r5:r4`, was three instructions (the high words first, so that the carry the low words leave is the one `ADC` finds):

```
        add     r5, r3          / PDP-11: a1 += b1
        add     r4, r2          / a0 += b0, and C = the carry out of it
        adc     r3              / a1 += C
```

Here no instruction leaves a carry behind, so each carry is computed as a number. The carry out of `ADD Rb, Ra` (`Ra` := `Ra` + `Rb`) is 1 exactly when the new sum is lower than an addend, as unsigned numbers (a sum that wrapped past 2^64 is smaller than what was added), and `SETLO Ra, Rb, Rt` writes that 0 or 1 in `Rt` in one instruction (`CBLO Ra, Rb, L` branches on it instead). The same addition is four instructions (the carry out of the top word is not wanted, so none is computed):

```
        add     r4, r2          ; a0 += b0
        setlo   r2, r4, r6      ; t = 1 if that carried (the new a0 is lower than b0)
        add     r5, r3          ; a1 += b1
        add     r6, r3          ; a1 += t
```

For a third word, or when the carry out of the second is wanted, each word after the first adds the carry in first and then the other word, and ORs the two carries (each addition can carry, and the two cannot both do so):

```
        add     r7, r2          ; a_i += carry in (r7)
        setlo   r2, r7, r8      ; carry of that addition
        add     r4, r2          ; a_i += b_i
        setlo   r2, r4, r7      ; carry of that addition (r7 is free again)
        bis     r8, r7          ; carry out, in r7 to be the carry in of the next word
```

The borrow of a subtraction `SUB Rb, Ra` is the comparison made before it: `SETLO Ra, Rb, Rt` gives 1 when `Ra` is lower than `Rb`, unsigned, and then `SUB Rb, Ra` follows. `MULH` and `MULHU` give the high half of a product, which is the other part that multi-word multiplication needs.

*Commentary.* **Precedent.** `ADD`, `SUB`, `BIS`, `BIC` and the single-operand set are the PDP-11's, unchanged in name and meaning; the PDP-11's `CMP`, `TST`, `BIT`, `ADC` and `SBC` existed to set or read condition codes, which this machine does not have. The specification of RISC-V gives the same test for the carry out of an unsigned addition: the sum is compared with an addend and a branch is taken if it is lower. **Trade-offs.** A carry costs an extra instruction in a multi-word add where `ADC` was free, and multi-word arithmetic is rare. Divide is in the escape group, at four bytes, because compilers turn division by a constant into `MULH` plus a shift, so a real divide is rare. **Improvements.** The high-half multiply that bignum code needs is present; a second unsigned multiply is the same instruction as the first and is not provided. **Benefits.** `SETCC` replaces a branch around a move for the very common "store the truth value of a comparison", and gives the carry of an addition in one instruction; absolute value, minimum and maximum (as aliases) remove a compare-and-branch from small loops. **Modern comparables.** RISC-V has `MULH`, `MULHU` and `MULHSU`, and AArch64 `SMULH` and `UMULH`; x86 has a one-operand multiply that produces both halves; **Use.** `MULH` and `MULHU` are for multi-precision arithmetic and for division by constants; `SETLO` carries a multi-word add or subtract; `MIN`, `MAX` and `ABS` (aliases) appear under a tenth of a percent of compiled code but each replaces a branch. **Impact.** *Kernel:* `SETLO` carries multiword arithmetic for the kernel's 128-bit counters and for the bignum code in the base system. *Compiler:* `MULH` turns division by a constant into a multiply and a shift; `SETCC` materialises a comparison without a branch. *Hardware:* One adder on the carry chain; on an FPGA the multiplier is built from two to four multiplier blocks over four to eight cycles; the divide is a sequencer.

<!-- entries:{{r:integer-arithmetic}} -->
<!-- /entries:{{r:integer-arithmetic}} -->

## {{#logic-shifts-and-rotates}} Logic, shifts and rotates

**{{#bic-bit-clear-bis-bit}}** `AND`, `BIC` (bit clear), `BIS` (bit set, the or) and `XOR` are two-byte ALU operations; `COM` is one's complement. A test of bits is `AND` into a scratch register and a compare-and-branch against zero.

**{{#shl-shr-and-sar-shift}}** `SHL`, `SHR` and `SAR` shift by a count taken from `rm` (a register, an immediate, or memory); `ASL` and `ASR` are the by-one forms in two bytes.

**{{#shift-count-of-64-or}}** A shift count of 64 or more shifts the value entirely away.

**{{#ror-rotates-right}}** `ROR` rotates right by a register or a constant count (the assembler picks the form: two bytes for a constant count from -8 to 7 of a register that is both source and destination and is one of r0 to r15, a negative count rotating left, and four bytes otherwise); `ROL` is an assembler spelling of the same instruction with the count complemented, `ROL Rs, #n, Rd` being `ROR Rs, #(64-n), Rd`, and takes a constant only, because the count of `ROR` is taken modulo 64 and a rotate left by a register count is `ROR` by the negated register; `ROR32` rotates the low 32 bits and sign-extends.

**{{#dshr-is-a-double-width}}** `DSHR` is a double-width funnel shift.

*Commentary.* **Precedent.** The PDP-11 had `ASL`, `ASR`, `ROL` and `ROR` by one through the carry; x86's `SHRD` and ARM's `EXTR` are the funnel shifts. **Trade-offs.** One rotate direction is enough, so there is no by-one `ROL` in a two-byte slot; there is no carry for a rotate to pass through. **Improvements.** The shift count comes from `rm`, not from a fixed register like x86's `CL`, which costs a register shuffle in every hand-written loop. **Benefits.** Multi-precision shifting is `DSHR`, two instructions for any distance. **Modern comparables.** RISC-V and AArch64 have rotates by register and by immediate; x86 has `RCL`/`RCR` through the carry as well. **Use.** `ROR` with a constant and `ROR32` are for hashes and ciphers, which rotate by constants; `DSHR` shifts a bignum. **Impact.** *Kernel:* Bit tests and mask operations on the status and page-table words are single instructions. *Compiler:* The shift count may be any register, immediate or memory operand, so the compiler never has to move a count into a fixed register; hashes and ciphers rotate by constants. *Hardware:* The barrel shifter (about 450 lookup tables) serves shifts and rotates,.

<!-- entries:{{r:logic-shifts-and-rotates}} -->
<!-- /entries:{{r:logic-shifts-and-rotates}} -->

## {{#bits-bytes-and-text}} Bits, bytes and text

**{{#bit-and-field-escape-provides}}** The bit-and-field escape provides `CLZ`, `CTZ`, `CLO`, `CTO` (count leading and trailing zeros and ones), `POPCNT`, `BSWAP`, `BSWAPW`, `BSWAPL` and `BITREV`.

**{{#extb-and-extzb-extract}}** `EXTB` and `EXTZB` extract a bitfield at a position and width, sign- or zero-extended, and `INSB` inserts one; the position and the width are 6-bit fields (a width of 64 cannot be written), so these are six bytes.

**{{#xnorpop-computes-the-population-count}}** `XNORPOP` computes the population count of the exclusive-nor of two registers.

**{{#clmull-and-clmulh}}** `CLMULL` and `CLMULH` are the low and high halves of a carry-less multiply; no polynomial is built into the architecture.

**{{#utf8len-utf8dec-and-utf8enc-find}}** `UTF8LEN`, `UTF8DEC` and `UTF8ENC` find the length of, decode and encode a UTF-8 sequence, and reject overlong forms, surrogates, out-of-range values and bad continuation bytes: `UTF8DEC` gives all ones in `Rd` for an invalid sequence (a value that is not a scalar value) and `UTF8ENC` gives all ones for a value that is not a Unicode scalar value, so no flag is needed to tell; the length consumed is `UTF8LEN` of the leading byte.

**{{#bsel-selects-bit-by-bit}}** `BSEL` selects bit by bit between two registers under the control of a third: it is `Ch` and `Maj` of SHA-2 in one instruction each, and the constant-time swap of two registers in two.

**{{#core-that-has-the-secure}}** A core that has the secure mode has instructions for the AES round (`AESES`, `AESESM`, `AESDS`, `AESDSM`), for its key schedule (`AESKS1`, `AESKS2`, `AESIM`) and for the SHA-256 and SHA-512 functions (`SHA256SIG0` and the others); each takes a time independent of its operands.

*Commentary.* **Precedent.** The PDP-11 had `SWAB`; the VAX had bit-field instructions and a table-driven `CRC`; x86 added `POPCNT`, `LZCNT` and `PCLMULQDQ` late, and committed `CRC32` to one polynomial. **Trade-offs.** A bit unit is one shared structure: `POPCNT`, `XNORPOP` and a garbage collector's mark-bitmap scan all want the same 64-input adder tree, and `CLZ` and its relatives want a priority encoder over the same operand. **Improvements.** A carry-less multiply stands in for a `CRC` instruction: no polynomial is baked in, and the same instruction serves CRC, the Galois-counter-mode authentication used in TLS, and hashing. Every UTF-8 security hole of the past is three comparators, which an instruction cannot omit and software often does. **Benefits.** The bit unit and the UTF-8 decoder together cost less than 5% of the die. **Modern comparables.** RISC-V's bit-manipulation and carry-less-multiply extensions, AArch64's `CLZ`, `RBIT`, `REV` and `PMULL`, and x86's `PCLMULQDQ`. **Use.** `POPCNT` for bitsets and Hamming distance; `XNORPOP` for binary-weight neural networks and bitset intersection; `CLMUL` for CRC, GCM and fingerprinting; `UTF8*` for text validation in parsers and kernels. **Impact.** *Kernel:* `CTZ` and `CLZ` find the first set bit in a run-queue or free-page bitmap; `POPCNT` counts bits in bitmaps; `BSWAP` converts network byte order. *Compiler:* The compiler maps `__builtin_clz`, `__builtin_popcount` and `__builtin_bswap` directly, and a carry-less multiply is the primitive for CRC and hashing code. *Hardware:* One bit unit holds a shared 64-input adder tree and a priority encoder, and the UTF-8 comparators are about 300 lookup tables.

<!-- entries:{{r:bits-bytes-and-text}} -->
<!-- /entries:{{r:bits-bytes-and-text}} -->

## {{#branches-and-control-flow}} Branches and control flow

*Cf. section {{r:kernel-system-instructions-exceptions}} for `TRAP`, `RTI #mask` and `RTT #mask`, and section {{r:exceptions-interrupts-and-traps}} for how a trap enters the kernel; section {{r:position-independent-code}} for `CALLI` and `JMPI` in position-independent code.*

**{{#machine-has-no-condition-codes}}** The machine has no condition codes. On the PDP-11 almost every instruction left four one-bit **flags** behind (`N` the result was negative, `Z` zero, `V` signed overflow, `C` carry out), and a branch looked at the flags that the previous instruction had left, so a decision was two instructions joined by a hidden register:

```
        cmp     r0, r1          / PDP-11: sets N, Z, V, C from r0 - r1
        blt     L               / reads them: branch if r0 < r1 (signed)
```

Here a decision is one instruction that compares two values, branches and writes nothing:

```
        cblt    r0, r1, L       ; branch if r0 < r1 (signed)
```

The same holds for a test against a constant, `cbeq r3, #5, L`, and for an unsigned comparison, `cblo r0, sp, L`. A comparison that is wanted as a number, not as a branch, is `SETLT`, `SETLO` and their relatives ({{r:setcc-writes-zero-or-one}}), which write 0 or 1 into a register; floating point has its own compare-and-branch with the unordered case ({{r:fcbcc-compares-two-registers}}).

I took the flags out because they were state that every arithmetic instruction might write and any later instruction might read. A core must keep that state in order, the status word must save it, a fast core must rename it, and every instruction needs a rule for which flags it writes (does a move set `Z`? does a shift set `V`?). Without them an instruction writes its result and nothing else. What it costs was measured on the output of the compiler, made to use no instruction that reads a flag, over 622 files (the C library, zlib, the kernel's cryptography, the math library and the tests of the compiler) and 36 programs. About nine comparisons in ten were already a compare-and-branch; the rest, a comparison against a constant wider than 16 bits or against memory, and a comparison kept as a value, cost half a percent more code (0.54%) and executed 0.04% fewer instructions (70.65 million, against 70.62 million). The programs ran in 0.2% to 0.9% fewer cycles on the timing model, which does not charge for the comparison inside a compare-and-branch; hardware pays for it with a comparator in the branch unit (548 gates of logic), where the unit that kept the flags was 178 gates and four flip-flops. The case for removing the flags is the simpler specification and the shorter list of what an instruction may leave behind, not the area.

**{{#there-is-an-unconditional-branch}}** There is one unconditional branch, `BR`; `JMP label` is `BR label`. It is two bytes with a field of 6 to 9 bits, four with 16 bits or six with 32 bits, counting two-byte parcels from the first parcel of the branch: ±64 to ±512 bytes, ±64 KiB, ±4 GiB. Every conditional branch is a compare-and-branch (`CBCC` for integers, `FCBCC` for floating point), except `SOB` and the tag branches `BTAG` and `BNTAG`.

**{{#cbcc-conditions}}** The conditions of `CBCC` are `eq` and `ne`, the signed `lt`, `le`, `gt` and `ge`, and the unsigned `cs` (lower, also written `lo`), `cc` (higher or the same, also `hs`), `hi` (higher) and `los` (lower or the same). `cs` and `cc` are the PDP-11's names `BCS` and `BCC` (`BLO` and `BHIS`), which tested the carry flag; here no carry is kept and the words `lo` and `hs` say what is compared. In the generic name `CBCC` the letters `CC` stand for a condition, and `cbcc` is the one condition `cc`.

**{{#sob-rn-dst-subtracts-one}}** `SOB Rn, dst` subtracts one from `Rn` and branches if the result is nonzero, forward or backward. It is four bytes, with a 16-bit field of parcels (±64 KiB).

**{{#cbcc-compares-a-register}}** `CBCC` compares a register with zero, with an immediate or with a second register, branches on the condition, and writes nothing. The left operand is the register first named: `cblt Ra, Rb, L` branches if `Ra < Rb`. The immediate is a signed number of at most 16 bits; a wider constant is loaded into a register first. The compare of `CBEQ` or `CBNE` with zero is two bytes (a reach of 32 bytes), or four bytes with a reach of 16 KB; a small immediate or two registers take four bytes (a reach from 256 bytes to 4 KB, by the widths of the immediate and of the register fields); six bytes hold a 12-bit immediate (a reach of 64 KB), a 16-bit immediate (4 KB) or two registers, any of the 32 (16 MB), and for these all ten conditions have the long forms alike, the unsigned ones exactly as the signed.

A range check is one unsigned compare-and-branch, and a `switch` is a bounds check followed by the indexed jump:

```
        cbhis   r1, #8, default ; unsigned: also catches a negative index
        lea     table(pc), r2   ; the table of eight-byte entries
        jmp     0(r2)(r1*8)     ; the indexed jump
```

**{{#jmp-and-call-take-any}}** `JMP` and `CALL` take any address mode; `RET` returns; `JMPI` and `CALLI` jump and call through a pointer in memory; `JTAG` dispatches on the tag in the low three bits of a register; `BTAG` and `BNTAG` branch on a tag.

**{{#call-pushes-the-return-address}}** A call pushes the return address on the stack; there is no link register.

**{{#fcbcc-compares-two-registers}}** `FCBCC` compares two binary64 values held in registers and branches: `fcblt Ra, Rb, L`. The conditions are `eq`, `ne`, `lt`, `le`, `uo` (taken if either operand is a NaN) and `or` (taken if neither is); `FCBGT` and `FCBGE` are the spellings of `FCBLT` and `FCBLE` with the registers exchanged, and the `32` forms (`FCBEQ32` to `FCBOR32`) compare binary32. The rules are IEEE's, as in C: with a NaN operand `eq`, `lt`, `le`, `gt` and `ge` are false and `ne` is true; a signaling NaN also sets the invalid flag of `FPSR`, a quiet one does not. There is no "not less than" branch: the negation of `lt` is not `ge` when an operand can be a NaN, so a branch is never inverted by changing its condition, and the unordered case has the words of its own. The instruction is four bytes for registers of the hot set and a target within 1 KB, and six bytes otherwise (a target within 4 MB); a farther target is refused. There is no immediate form.

```
        fcblt   r1, r2, 1f      ; if (x < y) goto 1f;  false for a NaN
        fcbuo   r1, r2, nan     ; if either is a NaN
```

**{{#four-pairs-of-instructions}}** Four pairs of instructions are fused into one. `MOVCALL Rs, Rd, label` is `MOVQ Rs, Rd` followed by `CALL label`, in four bytes (a 16-bit field of parcels, ±64 KiB) or six (32 bits); `POPRET Rd` is `POP Rd` followed by `RET`, and `POPMRET #mask` is `POPM #mask` followed by `RET` (the 8-bit mask field, scaled by 256, names `R8` to `R15`), each in two bytes; `MOV2 Ra, Rb, Rc, Rd` is `MOVQ Ra, Rb` followed by `MOVQ Rc, Rd`, in two bytes, with all four registers in the 3-bit hot table. The assembler never fuses: choosing a fused instruction is the compiler's job. A fused instruction is restarted whole after a fault.

**{{#cbcc-for-which-no-form}}** A `CBCC` for which no form reaches (a target beyond 16 MB, or in another object file) is assembled as the opposite compare-and-branch over a `BR` to the target; neither writes anything, so the program is the same, longer by the `BR`:

```
        cbne    r1, r2, 1f      ; written: cbeq r1, r2, far
        br      far
1:
```

*Commentary.* **Precedent.** The PDP-11 branch set tested its four condition codes, and its long-branch problem (±256 bytes) made it awkward; here `BR` reaches ±4 GB with no long-branch opcode and no trampoline, because the displacement widens with the length. `SOB` was the PDP-11's, which could only branch backward. **Trade-offs.** A compare-and-branch leaves nothing for a second branch to read, so a three-way decision is two compare-and-branches; that, and the comparisons that are kept as values, is the half percent of code the measurement above gives. **Improvements.** The tag branches serve a Lisp or other tagged runtime in one instruction. **Benefits.** Branch relaxation in the assembler is choosing a length. **Modern comparables.** The specification of RISC-V says its conditional branches compare two registers "rather than use condition codes". **Use.** `JMPI` and `CALLI` are the shared-library call and the virtual call; `JTAG` is the dispatch of a dynamic-language interpreter. **Impact.** *Kernel:* `JMPI`, `CALLI` and `JTAG` are the shared-library call, the virtual call and the dispatch of an interpreter; `SOB` and `CBCC` are the loops of the kernel's inner routines. *Compiler:* Branch relaxation is choosing a length; there is no flag-liveness analysis to make, because no instruction writes a flag. *Hardware:* The next-PC mux takes the load-return path for the indirect forms; the compare-and-branch compare runs in the branch unit beside the ALU; displacements count parcels, so no shifter is needed.

*Commentary on {{r:cbcc-compares-a-register}}, {{r:four-pairs-of-instructions}} and {{r:cbcc-for-which-no-form}}.* **Precedent.** The PDP-11 branched on the flags of the previous instruction only. The `CBCC` forms, two, four and six bytes long, trade reach against length: a branch that is near and compares small things is short, and one that is far or compares wide things is longer. The compiler joins moves with calls and pops with returns, as the instruction set names the fused pairs. **Trade-offs.** The reach of the shortest `CBCC` forms was set from the corpus: the optimiser trained on the compiler's own output, priced a `CBCC` that no form reaches as the opposite branch over a `BR` that the assembler substitutes, and offered the three-parcel forms; the cost is that one-parcel `CBCC` reaches less than in the earlier prefix-coded iteration ({{r:how-the-encoding-was-chosen}}), and lz4 fetches 1.2% more bytes for it (appendix {{c:id03006|n}}). The four fused pairs save two bytes a pair: 39,674 bytes (4.16%) in the corpus when the compiler was first given them. **Improvements.** The fused call has a three-parcel form, so a call beyond ±64 KiB is still one instruction; and the assembler's opposite branch over a `BR` makes every program assemble, so a form that does not reach is a slower program and never an error. **Benefits.** Fusion is a decision of the compiler, so the instruction set stays free of microarchitectural pairing rules, and a core that does not fuse in hardware loses nothing. **Modern comparables.** The fused pairs are the ones the compiled corpus shows most often adjacent: a move before a call, a pop before a return. **Impact.** *Kernel:* `POPRET` and `POPMRET` are the epilogue of every function and `MOVCALL` the call of every wrapper; they are smaller kernel text with no source change. *Compiler:* it fuses after register allocation, and keep a mask of `R24` to `R31` out of `POPMRET` (the field names `R8` to `R15` only). *Hardware:* a fused instruction is decoded as two operations that retire together; a hardware implementation may execute them as one or two.

<!-- entries:{{r:branches-and-control-flow}} -->
<!-- /entries:{{r:branches-and-control-flow}} -->

## {{#stack-and-block-operations}} The stack and block operations

*Cf. section {{r:faults-and-restart-what-precise-means}} for restarting a block operation after a fault (progress is held in registers) and section {{r:from-segments-to-pages-virtual-memory}} for the page faults it can take; section {{r:accesses-inside-one-block-operation}} for how block operations order their accesses.*

**{{#push-and-pop-move-one}}** `PUSH` and `POP` move one register; `PUSHM` and `POPM` move a set named by a mask (a mask of 8 bits is two bytes). A mask containing `R14` is reserved.

**{{#pushx-and-popx-save}}** `PUSHX` and `POPX` save and restore the exception state `EPSW` and `EPC` in one instruction each; both words are checked before either is accessed, so an abort leaves nothing changed.

**{{#block-operations-mcpy-mmov-overlap}}** The block operations `MCPY`, `MMOV` (overlap-safe), `MSET`, `MCMP`, `MSCN` and `MSCNN` take a destination pointer, a source pointer or value and a count in registers; `MVAL` validates a buffer as UTF-8.

**{{#mcmp-and-mscn-report-in-registers}}** `MCMP`, `MSCN` and `MSCNN` report their result in registers, not in flags. `MCMP` leaves `Rn` zero when the blocks are equal; when it stops at a difference, `Rn` is not zero and `Rd` and `Rs` point at the first bytes that differ (the order of those two bytes is two byte loads and a compare-and-branch). `MSCN` and `MSCNN`, which scan for a byte, leave `Rn` zero when no byte was found, and otherwise `Rn` is not zero and `Rd` points at the byte found.

**{{#block-operation-keeps-its-progress}}** A block operation keeps its progress in its registers: when it completes, the count is zero and the pointers are one past the end; when it stops early or is interrupted, they point where it stopped, and it restarts by running again.

**{{#implementation-may-move-more-than}}** An implementation may move more than a byte per step, provided the registers are consistent with byte-at-a-time progress wherever an exception can be taken.

*Commentary.* **Precedent.** The VAX's `MOVC5` is the canonical argument against such instructions: its operands could be memory, its architectural definition needed the original values to survive, and so it required hidden state and a first-part-done bit in the status word to resume. The PDP-10 had a block transfer, and x86's `REP MOVS` keeps its progress in registers as the pdp64's do. **Trade-offs.** This is the one admitted exception to the one-memory-operand rule, accepted because its mechanism, hidden state, is absent: the state is the registers, which are already architectural. **Improvements.** ARM reached the same design in 2022 with `FEAT_MOPS`, whose specification says the registers are updated so that progress is not lost. **Benefits.** The block-move sequencer is three counters and a byte-lane selector, about 1,500 transistors. **Modern comparables.** x86 `REP MOVSB` and `REP STOSB` with fast-string microcode; AArch64 `CPYP`/`CPYM`/`CPYE` and `SETP`/`SETM`/`SETE`; s390 `MVC`. **Use.** `memcpy`, `memmove`, `memset`, `memcmp` and `memchr` in the C library; `MVAL` in parsers and kernels. **Impact.** *Kernel:* `PUSHM`, `POPM`, `PUSHX` and `POPX` shorten entry, exit and the context switch, and the block operations are `copyin`, `copyout`, page clearing and `memcpy`. *Compiler:* A prologue and an epilogue are one instruction each, and `memcpy` and `memset` lower to the block operations. *Hardware:* The block-move sequencer is three counters and a byte-lane selector, about 1,500 transistors, with no hidden state.

<!-- entries:{{r:stack-and-block-operations}} -->
<!-- /entries:{{r:stack-and-block-operations}} -->

## {{#floating-point}} Floating point

**{{#floating-point-uses-the-general}}** Floating point uses the general registers: a `binary64` value fills one register, and the instruction, not the register, decides how its bits are read.

**{{#fadd-fsub-fmul-are-two-bytes}}** `FADD`, `FSUB` and `FMUL` are two-byte instructions; `FDIV`, `FSQRT`, the fused multiply-add family, `FABS`, `FMIN`, `FMAX`, `FCLASS`, the roundings and the `binary32` forms are in the floating-point escape; `binary16` has six conversions and no arithmetic.

**{{#five-ieee-flags-invalid-divide}}** The five IEEE flags (invalid, divide by zero, overflow, underflow, inexact) accumulate in `FPSR`; no floating-point operation traps; `FSFLAGS` reads and clears them. They are sticky exception records, not condition codes: no branch reads them, and a comparison is the compare-and-branch `FCBCC` ({{r:fcbcc-compares-two-registers}}).

**{{#every-nan-that-an-operation}}** Every NaN that an operation creates is the canonical quiet NaN.

**{{#there-are-no-rounding-mode}}** There are no rounding-mode or precision mode bits: the precision is in the opcode, and so is the rounding mode wherever it is not nearest-even.

**{{#isa-no-transcendental-instructions}}** There are no transcendental instructions.

*Commentary.* **Precedent.** The PDP-11's FP11 had `AC0` to `AC5` and mode bits for single and double precision; the VAX had F, D, G and H formats. **Trade-offs.** An integer operation applied to a register holding a `binary64` destroys it, with no trap and no tag; that is intended and the ABI states it. A separate register file would cost a second set of read ports and a floating-point context; on a small implementation the register file is among the largest blocks. **Improvements.** The fused multiply-add is the largest single addition to the datapath (about 9,000 transistors) and the least negotiable; the IEEE exception flags are recorded without traps, which is what C99 `<fenv.h>` needs. **Benefits.** No transfer instructions between files and a single calling convention. **Modern comparables.** RISC-V Zfinx and Zdinx use the integer register file for the same reason; AArch64 and x86 have separate vector and floating-point files. **Use.** `FCLASS` begins every library maths function; `FMA` is the building block of accurate polynomial evaluation. **Impact.** *Kernel:* There is no separate floating-point state to save at a context switch beyond the registers already saved, and the sticky flags are one register, `FPSR`, which a context switch saves with the rest. *Compiler:* One calling convention for integers and floats, fused multiply-add contraction, and no rounding-mode state for the compiler to track. *Hardware:* No second register file (one of the largest blocks of a small floating-point unit); the floating-point unit with fused multiply-add is about 34,000 transistors.

<!-- entries:{{r:floating-point}} -->
<!-- /entries:{{r:floating-point}} -->

## {{#atomics-and-ordering}} Atomics and ordering

*Cf. chapter {{c:id01007|n}}, section {{r:atomic-operations}} (atomic operations), section {{r:multiprocessor-instructions-at-a-glance}} (the multiprocessor instructions at a glance) and section {{r:memory-ordering-from-sequential-consistency}} (the memory model).*

**{{#atomic-group-atom-holds-cas}}** The atomic group `ATOM` holds `CAS`, `SWAP`, `AADD`, `AAND`, `ABIS`, `AXOR`, `AMAX`, `AMIN`, `AMAXU` and `AMINU`, and `LL` and `SC`, in two sizes: the bare name is the 8-byte word and the name with an `L` after the operation the 4-byte word, 24 words in all, all four bytes long; `FENCE`, `WFE`, `SEV`, `ISYNC` and `HINT` are in `SYS`. Their semantics, ordering rules and the reservation monitor are in chapter {{c:id01007|n}}.

**{{#atomic-words-are-alu-names}}** The fetch-and-operate words are the names of the machine's own instructions with an `A` for atomic in front: `AADD`, `AAND`, `ABIS`, `AXOR`, `AMAX`, `AMIN`, `AMAXU` and `AMINU` do to memory what `ADD`, `AND`, `BIS` (the inclusive or), `XOR`, `MAX`, `MIN`, `MAXU` and `MINU` do to a register, and return the old value; `CAS`, `SWAP`, `LL` and `SC` keep their plain names. Like every instruction with a destination they write it last: `AADD Rs, (Ra), Rd`.

**{{#cas-operates-on-4-or}}** `CAS` operates on 4 bytes (`CASL`) or 8 bytes (`CAS`), and every atomic has the register fields of {{r:every-atomic-has-three-register}} and the address `(Ra)` with no offset, `CAS Rs, (Ra), Rd` with the expected and the old value in `Rd` (`LL` has two operands, `LL (Ra), Rd`); an aligned 8-byte compare-and-swap may cover two adjacent 4-byte fields, because the usual lock-and-count fast path of an operating system is exactly that (an 8-byte whole over two 4-byte members).

*Commentary.* The official entry of each instruction is below, in this section; chapter {{c:id01007|n}} gives the reasons, the memory model and the use. **Impact.** *Kernel:* the entries below are all a kernel needs to write its locks; chapter {{c:id01007|n}} explains how they compose. *Compiler:* a lock acquire is one instruction. *Hardware:* a reservation monitor beside the data cache.

<!-- entries:{{r:atomics-and-ordering}} -->
<!-- /entries:{{r:atomics-and-ordering}} -->

## {{#isa-system-instructions-exceptions}} System instructions, exceptions and interrupts

*Cf. chapter {{c:id01006|n}}, section {{r:kernel-system-instructions-exceptions}} (system instructions, exceptions and interrupts), section {{r:exceptions-interrupts-and-traps}} (exceptions and interrupts) and section {{r:system-registers-mfsr-and-mtsr}} (system registers).*

**{{#system-group-sys-holds}}** The system group `SYS` holds the privileged and system instructions: `TRAP`, `RTI #mask`, `RTT #mask`, `RET`, `HALT`, `BPT`, `MTPS`, `MFPS`, `SPL`, `MFSR`, `MTSR`, `MTDP`, `MFDP`, `PROBER`, `PROBEW`, `PUSHX`, `POPX`, `GENTER #mask`, and the translation and cache maintenance instructions (`TLBI`, `TLBIA`, `TLBIAS`, `TLBIGP`, `TLBSYNC`, `ICINV`, `ICINVA`).

*Commentary.* The official entry of each instruction is below, in this section; the kernel chapter gives the modes, the entry sequence, the system registers and the reasons. **Impact.** *Kernel:* the entries below are the complete list of what the kernel may execute that user code may not, and of what both may; chapter {{c:id01006|n}} explains how they are used. *Compiler:* none, apart from `TRAP` in system-call stubs. *Hardware:* a class decode and one privilege check.

<!-- entries:{{r:isa-system-instructions-exceptions}} -->
<!-- /entries:{{r:isa-system-instructions-exceptions}} -->

## {{#faults-restart-and-memory-management}} Faults, restart and memory management

*Cf. chapter {{c:id01006|n}}, section {{r:faults-and-restart-what-precise-means}} (faults and restart) and sections {{r:from-segments-to-pages-virtual-memory}} to {{r:splitting-the-space-and-the-layout}} (memory management).*

**{{#fault-is-a-trap}}** A fault is a trap, an abort, a progress stop in a block operation or a machine check, and every instruction either completes or is annulled and restarted with no state to undo (`MCPY` and its kin keep their progress in registers); the page-table format, the memory types and the translation registers are in the kernel chapter.

**{{#fused-instruction-movcall-popret-popmret}}** A fused instruction (`MOVCALL`, `POPRET`, `POPMRET`, `MOV2`) is restarted whole after a fault: no part of it is visible as a separate instruction.

*Commentary.* The instruction-set consequence is the restart rule: the register update of an auto-increment mode is held until the instruction retires. **Impact.** *Kernel:* see {{r:faults-and-restart-what-precise-means}}. *Compiler:* no scheduling restriction arises from faults. *Hardware:* a single-entry undo buffer and a read-only walker.

## {{#position-independent-code}} Position-independent code

**{{#position-independent-code-costs-nothing}}** Position-independent code costs nothing extra on this machine: every access to code or data in the same module is PC-relative by an ordinary addressing mode, so there is no GOT register and no prologue to set one up.

**{{#call-to-an-imported-function}}** A call to an imported function is `CALLI got_slot(PC)` and a PLT stub is the single instruction `JMPI got_slot(PC)`; an imported variable's address is one `MOVQ got_slot(PC), Rd`.

**{{#position-independent-access}}** A position-independent access to a global is no longer than an absolute one: four bytes within 32 KB and six within 2 GB, against six for a 32-bit absolute address.

**{{#thread-pointer-is-dp-so}}** The thread pointer is `DP`, so the local-exec thread-local model is one six-byte `MOVQ tls_offset(DP), Rd`.

**{{#six-byte-branch-reaches-4}}** A six-byte branch reaches ±4 GiB, so no linker veneers are needed for any binary smaller than that; the assembler's and the linker's branch relaxation both reduce to choosing a length.

**{{#r12-is-the-linker}}** `R12` is the linker's scratch register. The ABI (appendix {{c:id03004|n}}) decides that imports are called without a PLT stub.

*Commentary.* **Precedent.** On i386 a position-independent executable reserved `%ebx` (one of eight registers) for the GOT base and set it in every prologue, which cost a few percent of size and speed; x86-64 fixed that with RIP-relative addressing, and AArch64 needs linker veneers because its branches reach only 128 MB. **Trade-offs.** The two-byte PC-relative form is the shortest, so position-independent data access is slightly smaller than absolute access; the price is a GOT load per imported call site where a PLT stub would cost a load per function. **Improvements.** Position-independence is a side effect of three decisions made for other reasons: PC-relative as an ordinary mode (adopted because the PC left the register file), variable-length encoding (for density) and `DP` (a 6502 zero-page descendant kept for density), which is exactly the thread pointer. **Benefits.** OpenBSD builds everything position-independent by default, and here that costs nothing. **Modern comparables.** x86-64 RIP-relative addressing; AArch64 `ADRP` with a GOT load and veneers for far calls. **Impact.** *Kernel:* a loader applies only relocations for data pointers, and write-xor-execute and randomisation come with no code penalty. *Compiler:* `-fPIE` is the default and emits the same instructions as `-fno-pic` for local data; no reserved register, no per-function setup. *Hardware:* nothing; the PC-relative mode is in the address adder already.

## {{#what-was-rejected}} What was rejected

**{{#architecture-refuses-by-design-every}}** The architecture refuses, by design, every feature that adds hidden state, an unbounded instruction, a second operand path or a mode bit that changes what other instructions mean.

**{{#from-the-pdp-11}}** From the PDP-11 and VAX it refuses general memory-to-memory operands, deferred addressing as a general form (only `JMPI` and `CALLI` are deferred), unbounded instructions with hidden microstate (`MOVC5`, `EDITPC`), packed decimal, hardware call frames (`CALLS`, `CALLG`), the PC as a general register, multiple floating-point formats, `POLY`, the `IOT`, `EMT`, `WAIT` and `RESET` instructions, a distinct low-half unsigned multiply, and the PDP-11's compare operand order.

**{{#from-x86-it-refuses-partial}}** From x86 it refuses partial-register writes that preserve upper bits, operand-size and `REX` prefixes, segmentation, condition codes altogether, implicit registers for multiply, divide and shift count, the x87 stack, transcendental instructions and byte-granular instruction fetch.

**{{#from-the-risc-family}}** From the RISC family it refuses a register hardwired to zero (a thirty-second of a 32-register file), branch delay slots, register windows and software-refilled translation buffers.

**{{#also-refuses-features}}** It also refuses features of its own invention: NUL-terminated string instructions (`MSCN` with an explicit maximum gives a bounded `strlen`), `CRC32` words (carry-less multiply is the primitive under every CRC), reciprocal-estimate instructions, NaN payload propagation, a 32-bit profile, an eight-byte instruction alignment, `MOVT` and `MOVK` partial-immediate inserts, hardware tag checking, store-with-write-barrier, a self-synchronising encoding, and a scalar instruction for sub-1-bit inference (the accelerator of chapter {{c:id01008|n}} does it).

*Commentary.* **Precedent.** The VAX's `EDITPC` is a bytecode interpreter in microcode, and DEC needed a separate control chip for the PDP-11's commercial instruction set and shipped none; the VAX's hardware call frames ran slower than the equivalent sequence on later models; ARM32's `PC+8` and MIPS's delay slot expose one implementation's pipeline forever. **Trade-offs.** Each refusal gives up a real convenience: the lost `MOV (R1)+,(R2)+` copy loop, the byte-wide `ADDB`, the inline-argument `JSR`. Section {{r:idioms-restored-lost-and-replaced}} says what replaces each. **Improvements.** The common pattern is that a refused feature was either subsumed by a more general one (`MCPY` for the copy loop) or paid its cost in every implementation for a few users (`EDITPC`). **Benefits.** An instruction set a small in-order core can implement completely and a compiler can target without exceptions. **Modern comparables.** RISC-V and AArch64 also refuse memory-to-memory operands and delay slots; **Impact.** *Kernel:* no instruction has a restart state except the three that keep their progress in architectural registers, so a fault is always restartable. *Compiler:* no special cases: every operand rule is uniform, one memory operand and the rest registers. *Hardware:* no microcode engine, no second operand path, no hidden-state latch, no alignment rotator in the fetch path.

## {{#idioms-restored-lost-and-replaced}} Idioms: restored, lost and replaced

**{{#several-idioms-that-the-pdp}}** Several idioms that the PDP-11 and VAX had and later RISC designs dropped are restored: subtract-one-and-branch (`SOB`, here in both directions), probe an address without faulting (`PROBER`, `PROBEW`), bit-field extract and insert, find-first-set (`CTZ`, `CLZ`), byte swap, block move, fill, compare and scan with their progress held in registers, the register-save mask (`PUSHM`, `POPM`, the useful half of `CALLS`), and carry-less multiply.

**{{#vax-counted-string-instructions}}** The VAX's counted-string instructions are largely present: `MOVC3` is `MCPY`, `CMPC3` is `MCMP`, `LOCC` is `MSCN`, `SKPC` is `MSCNN`, and `MOVC5` is `MCPY` plus `MSET`. Table-translated move, table scans and substring search are absent because a per-byte table lookup stops a block operation from streaming.

**{{#deliberately-lost-with-their}}** Deliberately lost, with their replacements: memory-to-memory `MOV` (replaced by `MCPY`); autoincrement-deferred and the dispatch-table idiom (replaced by `JTAG` for tag dispatch and a scaled-index `JMP` for the rest); `JSR Rn` and `RTS Rn` with inline arguments and cheap coroutines (replaced by `CALL` and `RET` with the return address on the stack where every unwinder and debugger expects it); the VAX `CASE` and `INDEX` instructions (replaced by a compare, branch and scaled `JMP`); byte and word ALU operations (`MOVZB`, the operation, `MOVB`: three instructions where the PDP-11 had one); and the flag set and clear instructions, which a machine with no flags has no use for.

**{{#subsumed-so-not-losses-sxt}}** Subsumed, so not losses: `SXT` (the conversion moves), `SWAB` (`BSWAP`), `MARK` (the convention it served is gone), `ASH` and `ASHC` (the shifts take a register count), `MFPI` and `MTPI` (`PROBER` with the previous-mode bits and the user-memory guard), `MULU` (identical to `MUL` in the low half), and `ROL` (an assembler alias for `ROR`).

**{{#measurements-decide-what-is-included}}** Measurements decide what is included, and the compiler uses more of the set than the first compiler did: `SETCC`, `ABS`, `MIN` and `MAX` (the last three assembler aliases, {{r:abs-min-minu-max}}), the bit-field instructions, the strided auto-increment modes and the scaled index are all emitted, and the fused pairs are 19,786 instructions of the corpus.

**{{#compiler-fuses-a-move-before}}** The compiler fuses a move before a call (`MOVCALL`), a pop before a return (`POPRET`, `POPMRET`) and two register moves (`MOV2`); the pairs are matched by dynamic programming after register allocation, two bytes saved a pair, 39,674 bytes (4.16%) in the corpus when fusion was first added. The mask of a `POPMRET` names `R8` to `R15`, so a save of `R24` to `R31` does not fuse.

**{{#dense-switch-is-a-jump}}** A dense `switch` is a bounds check, one unsigned compare-and-branch to the default (`cbhis`), and a jump through a table with eight-byte entries placed after the return (the analogue of the VAX `CASEL`); any other `switch` is a binary search, which costs 0.27% in static size and takes the opcode dispatch of Lua from 225.1 million to 148.7 million instructions executed. The jump tables are 3.4% to 5.0% fewer cycles on Lua in the timing model and 806 bytes smaller.

**{{#signed-division-by-a-power}}** Signed division by a power of two, and a pointer difference, are shifts; signed division and remainder of an `int` by a constant are a multiply and a shift (2 to 6 and 6 to 10 bytes longer than the plain code, 30% to 67% fewer cycles in micro-benchmarks). Unsigned and 64-bit division by a constant needs a `MULH`-based tree and is not done.

**{{#array-index-is-scaled}}** An array index is scaled by the addressing mode and not by a shift and an add, including an index that is converted from a narrower type first (the inner loop of the `bs_ec` benchmark, 31% fewer instructions); a walk down an array is a strided post-increment; multiplication by 5 or 9 is a `LEA`.

*Commentary on {{r:compiler-fuses-a-move-before}} to {{r:array-index-is-scaled}}.* **Precedent.** The VAX back end of the portable C compiler used `CASEL`, the autoincrement modes and `INDEX` for these jobs; this list is what survived of that table on this CPU. **Trade-offs.** Each pass was measured against its cost: the size-for-speed passes (division by constants, jump tables) lengthen the code a little and shorten the run a lot, and the static-single-assignment form was left off because it ran 3.2% to 5.1% slower in the timing model. **Impact.** *Kernel:* a switch in a driver or a system-call dispatch is a table. *Compiler:* every item is a switchable pass with its own flag, so a regression can be bisected. *Hardware:* none of these needs an instruction that the entries do not already describe.

*Commentary.* **Precedent.** The PDP-11's `JSR Rn` put the return address in a register of the caller's choosing, which made coroutines a pair of `JSR`s and inline arguments free; the VAX replaced it with `CALLS` and a frame, which was slower than the code it replaced. **Trade-offs.** The most frequently felt loss in hand-written code is the byte-wide read-modify-write; the compiler never notices it. **Improvements.** `SOB` branches either way, with four reaches; the block operations keep their progress in registers, which is what the VAX got wrong, so a fault restarts for free. **Benefits.** The code a compiler emits is the code the table above measures, and the extras are for the people who write assembler. **Modern comparables.** x86 keeps `LOOP` and the string instructions with `REP`; AArch64 has bit-field moves and no memory-to-memory forms; RISC-V has none of them in the base. **Impact.** *Kernel:* `PROBER` and `PROBEW` replace the `nofault` global in the user-copy routines. *Compiler:* idioms the compiler never emits are not built for it, so the compiler's instruction selection stays small. *Hardware:* each restored idiom is a few hundred gates of existing datapath, and each lost one is a decode that never existed.

## {{#side-by-side-the-pdp-11}} Side by side: the PDP-11, the VAX and the pdp64

**{{#word-is-64-bits-against}}** The word is 64 bits against the PDP-11's 16 and the VAX's 32, the registers are 32, the virtual address is 39, 48 or 57 bits with 40 physical in the present implementation, and the instruction count is @@COUNT:words@@ instruction words in @@COUNT:leaves@@ leaves (@@COUNT:vector@@ of them in the vector family), against the VAX's 304.

**{{#isa-program-counter-is-not}}** The program counter is not a register, there is no argument pointer, and the frame pointer and the linker scratch are ordinary software conventions.

**{{#instruction-has-one-or-two}}** An instruction has one or two operands (three for the block operations) and at most one memory operand, against the PDP-11's two and the VAX's six.

**{{#no-condition-codes-and-no-fp-mode-bits}}** The PDP-11 and the VAX had the four condition codes `N`, `Z`, `V` and `C`; the pdp64 has none, and branches on a comparison of two registers. Floating point is in the base and in the general registers, with three IEEE formats (half, single, double; the half only converted) and no mode bits that change the meaning of other instructions, where the PDP-11 had `FPS.FD`, `FL` and `FT` and the VAX had rounding bits in the status word.

**{{#instruction-is-two-four-or}}** An instruction is two, four or six bytes (one to three parcels of 16 bits), or ten with a 64-bit literal, against the PDP-11's two to six and the VAX's one to more than fifty.

*Commentary.* **Precedent.** The PDP-11 and VAX instruction formats, with their encodings drawn side by side, are in the instruction-set text, section 13. **Trade-offs.** The pdp64 keeps what made the PDP-11 pleasant, orthogonal addressing and a small register set, and what made the VAX powerful, a register-save mask and string operations, and drops what made both expensive: memory-to-memory operands and unbounded instructions. **Improvements.** The compiler's code averages 3.26 bytes an instruction on the 841-file corpus and 2.93 executed. **Benefits.** A processor that is smaller than either predecessor while running 64-bit code. **Modern comparables.** The closest family is AArch64 in the number of registers and addressing modes and RISC-V compressed in density; **Impact.** *Kernel:* the exception model is the PDP-11's with the VAX's per-mode stacks. *Compiler:* one memory operand makes instruction selection a register-allocation problem, as on a RISC. *Hardware:* a decoder that finds the length from a prefix of the first parcel, and no microcode.

## {{#what-was-taken-from-loongarch}} What was taken from LoongArch, and what was not

**{{#loongarch64-is-the-most-recent}}** LoongArch64 is the most recent clean-room instruction set designed without an ideological commitment: it borrowed from MIPS, RISC-V and ARM as each had the better answer, which is the posture of the pdp64.

**{{#adopted-from-it-bit-manipulation}}** Adopted from it: bit manipulation in the base (`CLO`, `CLZ`, `CTZ`, bit-field moves, byte reverse), a richer atomic set (fetch-and-minimum and maximum), memory type as a page attribute, and 32 registers, which the prefix-coded encoding has the bits for.

**{{#declined-with-reasons-r0-hardwired}}** Declined, with reasons: `R0` hardwired to zero (a thirty-second of a 32-register file, and `CLR` and `NEG` are one parcel already); `FCSR` rounding-mode bits (hidden state that changes other instructions); four PC-relative address-formation instructions (one `LEA` carries 32 bits); and separate vector register files (chapter {{c:id01008|n}}).

**{{#branch-free-conditional-select}}** A branch-free conditional select for constant-time code, `MASKEQZ` and `MASKNEZ`, is adopted, and so is the bit select `BSEL` ({{r:bsel-selects-bit-by-bit}}).

*Commentary.* **Precedent.** LoongArch has a fixed 32-bit encoding with room for two register fields and a displacement, and needs four instructions to form an address; this machine's variable length reverses that trade-off. **Improvements.** The same idea is right or wrong depending on the encoding around it, and each adoption is judged against this encoding. **Benefits.** Borrowing the tested parts saves design time and avoids their bugs. **Modern comparables.** LoongArch itself; the RISC-V bit-manipulation extensions (Zbb, Zbs) do much of the same. **Impact.** *Kernel:* atomics with barriers make a lock acquire one instruction. *Compiler:* bit operations in the base mean the compiler can use them without a feature test. *Hardware:* each adopted idea is a few hundred lookup tables and each declined one is a block not built.
