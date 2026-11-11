# DEC PDP-64: the instruction set architecture, its narrative and its rationale

[← pdp64 index](../README.md)

**Digital Equity Collective's Pragmatic Digital Processor, 64 bit** — an update and refresh of the PDP-11 instruction set and architecture for the modern world.

There is one CPU, the **pdp64**: thirty-two 64-bit registers and a prefix-coded instruction encoding, in which the first 16-bit parcel of an instruction says both what the instruction is and how long it is. Words are 16 bits, longs are 32, quads are 64, and PDP-11 terminology is used throughout. Two earlier iterations of the design (the original encoding with sixteen registers, called r20, and a prefix-coded encoding with sixteen registers, called pdp64/16) were built and measured against it and superseded; they are no longer CPUs (the author, 2026-11-10; errata 122 and 123), and the git tags `pre-single-cpu` and `pre-code-removal` keep their manuals and code. The measured comparison by which the 32-register encoding was chosen is in [`encoding-work/`](encoding-work/README.md).

**What this document is, and what it is not.** It is the narrative and the reasoning behind the instruction set: the priorities, the rules and when they may be broken, why each group of instructions has the shape it has, what was taken from the PDP-11, the VAX and others and what was refused, and the arguments for the contested decisions. **The reference is elsewhere.** The ordered account of the architecture is the [manual](manual/00-index.md) (chapter 9 is the instruction set; every instruction has its entry there); the reference tables of every leaf, mnemonic, alias and constant are the manual's [dictionary](manual/dictionary/index.md); what is decided, what is pending and what was rejected is [`decisions-and-status.md`](decisions-and-status.md), with the author's words in the [decision register](decision-register.md) and the numbered decisions in [`errata.md`](errata.md) (the later entries win over older text). The numbers (prefixes, sub-opcodes, field positions) are written once, in the grammar [`spec/pdp64/pdp64.hbnf`](../spec/pdp64/pdp64.hbnf) with the vocabulary of [`spec/pdp64-mnemonics.hbnf`](../spec/pdp64-mnemonics.hbnf), and the tables are generated from them ([`spec/pdp64/tables.md`](../spec/pdp64/tables.md)). **This text therefore carries no opcode numbers and no bit layouts: they may still change when the open items are decided and the encoding optimiser is run again, and where this text and the grammar disagree, the grammar is right.** An earlier, handwritten version of this document described the original encoding; it was replaced by this one (git history keeps it).

> The implementation plan ([`pdp64-fpga-plan.md`](pdp64-fpga-plan.md)) covers the FPGA build. The LB64 document ([`pdp64-lb64-accelerator.md`](pdp64-lb64-accelerator.md)) is a proposed design for a sub-1-bit inference accelerator and is the worked example of the section on what the architecture owes devices: a substantial device that needs no instruction-set change at all (proposed, not decided).

---

## 1. Design priorities

Ranked, because they conflict:

1. **Security and safety.** An error that can never arise is the ideal; failing that, an error that is easy to detect; failing that, an error that is cheap to recover from. Restart and recovery go together: every instruction is restartable after a fault with no instruction-specific cases, and a fault handler restarts blindly. An instruction does what its name says and nothing else, because a predictable machine is easier to reason about (for people and for tools) and needs less defensive code.
2. **Opcode choice.** Fewer instructions executed means fewer memory fetches, and memory fetch is the slowest part of a modern processor. An opcode that coalesces several operations is good. This is about the instructions a program executes, not the number of opcodes the machine has.
3. **Opcode encoding.** Pack the instructions densely, with rare instructions in longer encodings, which also saves fetches.
4. **Speed and power,** served by a low gate count: fewer opcodes, addressing modes, flags and error conditions mean less logic, less heat and a higher clock, and they make out-of-order execution cheaper to build.
5. **Good compiler target.** Consistent behaviour, so optimized code is easy to produce and few edge cases leave optimization on the table.
6. **Pleasant in assembler.** Few opcodes and addressing modes, and related instructions behaving alike. A PDP-11 programmer should recognize the language.

Four standing constraints sit beside the ranking and are not traded against it:

* **Ready for out-of-order execution from the start.** The first implementations are in order, but nothing is specified that is safe only because the core does not speculate or reorder, and a feature that serves priority 1 in an out-of-order core is looked at seriously (errata 68).
* **Every rule is soft** (section 1.1).
* **An instruction is judged by its weight in the loops where it is used,** executions times what it saves, not by how rarely it appears.
* **Occam: do not multiply entities without benefit.** It applies at every level of the ranking.

Three rules govern everything below:

> **At most one operand of any instruction may be a memory reference.**
>
> **No instruction is longer than three parcels (six bytes), one 64-bit literal excepted.**
>
> **A register is always written in full.**

Mode bits are decided case by case. Hidden state that changes what unrelated instructions mean is a strange side effect (priority 1) and must be saved at every context switch, so the default is that a mode is visible state, set by an instruction that names it. A bit in a register that is saved anyway (the status word, say) costs nothing extra and is accepted (errata 83).

### 1.1 When a rule may be broken

A principle held past the point where it costs more than it saves is an ideology, and the machines in section 10 that failed did so from both directions — VAX from no principle, the pure RISCs from too much. The rule for departing from one:

> **An exception is admissible when (a) the benefit is named and concrete, (b) the cost is bounded and written down, and (c) the mechanism that made the principle necessary is absent from the exception.**

Clause (c) does the work. It is not enough that an exception be useful; the specific failure the rule was protecting against has to be structurally impossible in the exception.

The worked example is the block operations (section 4.7). VAX's `MOVC5` is the canonical argument for the one-memory-operand rule: it issues an unbounded number of memory references and needs hidden intermediate state plus `PSL<FPD>` to resume. The pdp64 block operations do the same job and are *not* that, because their operands come from registers and are consumed as progress. There is no hidden state to save, because the state is the registers, and they are already architectural. The mechanism is absent, so the exception is admissible. Section 7.5 writes down the cost.

**No rule is absolute.** Every rule here is a default that records a benefit worth protecting and the failure it prevents, and it yields when breaking it is worth more than it costs, with the cost written down. The strongest default says what a break would cost:

- **Mode state.** Hidden state that changes the meaning of unrelated instructions must be saved and restored across a context switch and is a strange side effect. A mode bit is accepted when it keeps those benefits away (a machine-wide bit set once at boot, a bit in the status word that is saved anyway) or when its benefit outweighs its written-down cost. (The sticky floating-point status register `FPSR`, section 4.9, is not an exception: it never changes what an instruction does, it only records what an instruction did.) Accepted: `MMUCTL`, the user-memory guard `UA`, and the data-independent-timing bit `DIT` (manual 9.3.7).
- **Natural alignment for quad accesses** (section 7.4). This is load-bearing for every tagged runtime (section 6.2), and relaxing it converts a trapped bug into silent corruption. That is the cost of breaking it, and it is large; it is a cost to weigh, not a prohibition.

### 1.2 The decision order

Section 1.1 says when a principle may be broken. This says how to choose between two designs that both work; it applies the ranking of section 1 to the usual cases. The tests apply in order, and an earlier one is not traded against a later one. The first is priority 1, the second is priority 3, and the third (Occam) is the standing constraint of section 1, which is why it is not a rung.

> **1. No strange side effects.** An instruction does what its name says and nothing else. Nothing is left in a register the mnemonic does not mention, no flag is set that the entry does not list, no state persists that the next instruction can observe without asking. This is why the flag rules of section 4.3 had to be written, why section 9.8 refuses mode bits, and why the operation order of `CALLI` is specified (section 4.8) and not left to the implementation.
>
> **2. Do not displace an instruction into a longer encoding.** A new instruction may take unused code space. It may not push an existing, common instruction into a form that costs more bytes, unless the displaced operation is rare enough that aggregate code size is unaffected. The test is frequency-weighted: lengthening something common from two bytes to four is a real regression, lengthening something rare is noise. (In the first encoding this meant keeping a slot; in the prefix code the encoding optimiser applies the same test to the whole corpus at once, by giving the shortest prefixes to the forms that occur most.)
>
> **3. Occam. Do not multiply entities without benefit.** Prefer one instruction that covers three cases to three that each cover one, when they share their hardware. Prefer a sub-opcode in a group that already exists to a new group. Prefer an assembler alias to an instruction. Count the gates and the verification surface, not just the opcodes.

**An example of rule 3.** `JMPI`, `CALLI` and `JTAG` share one group because they share one property: the next program counter comes from the load-return path, so they share one decode comparison and one multiplexer input instead of being three unrelated cases whose common hardware is invisible in the encoding.

**One known rule-2 exception stands.** Rotate-left by one has no instruction of its own; `ROL` is an assembler alias for a right rotate by the complement. By the frequency test that is acceptable: rotate-by-one is rare in compiled code, the crypto code uses rotate by compile-time constants other than one, and multi-precision shifting uses `DSHR` (section 4.6). Restoring it would recreate the left/right asymmetry that section 4.5 removes.

---

## 2. Programmer-visible state

### 2.1 General registers

Thirty-two registers, `R0`–`R31`, 64 bits each (manual 9.3.1).

| Register | Role | Hardware knows? |
|---|---|---|
| `R0`–`R13`, `R15`–`R31` | general | no |
| `R13` / `FP` | frame pointer | **no** — ABI convention only |
| `R14` / `SP` | stack pointer | **yes** — three copies, kernel / supervisor / user, switched with the mode |

**`SP` is `R14` and `FP` is `R13`, matching VAX.** The PDP-11 has `SP` at `R6`.

Cost: `-(SP)` and `(SP)+` still assemble and still mean push and pop, because `SP` is a register *name* and the mode syntax is unchanged. What breaks is hand-written PDP-11 code that spells the stack pointer `R6`, which silently means an ordinary register. The assembler should warn on `-(R6)` and `(R6)+` for this reason. Binary compatibility with the PDP-11 is not a goal; the claim is mnemonic compatibility — instruction names and operand syntax, not register numbering — and the trade lines up with the architecture the pdp64 succeeds.

**Roles the ABI assigns (version 1: [manual appendix D](manual/appendix-d-abi.md), source [`abi.md`](abi.md); the hardware knows none of them).** Arguments travel in the low registers and the result in `R0` (with `R1` for a 128-bit pair); some registers are caller-saved and the rest callee-saved; `R12` is the linker's scratch register; `R13` is the optional frame pointer and `R14` the stack pointer. The stack pointer is a multiple of 8 at all times, because quad data accesses must be naturally aligned (section 7.4); nothing is wider than a quad, so there is no 16-byte alignment. The data model is LP64 and little-endian.

**Hot registers.** In a one-parcel form a short register field is not a register number but an index into a table of the hottest registers (the table for a 3-bit field has eight entries, the table for a 4-bit field sixteen); the compiler's register allocator prefers them. The tables are part of the ABI and are generated with the encoding ([`spec/pdp64/tables.md`](../spec/pdp64/tables.md), manual 9.4.6); they are chosen by the encoding optimiser and may change when it is run again.

Not taken from VAX: `R12` as the argument pointer. VAX's `AP` exists to serve `CALLS`/`CALLG`, which section 11 rejects, so `R12` is an ordinary register here. VAX's `R15` is the program counter; the pdp64's is general (section 9.3).

**Why `SP` is in the register file and the program counter is not.** The mode-switched copies are the *only* way `SP` differs from any other register; it exists so that a trap arriving in user mode has a kernel stack without first having to find one, which is the PDP-11's arrangement and remains correct. Everything else about `SP` is ordinary. **Writing `SP` has no control-flow consequence** — it is a data write that happens to hold a pointer, and the hazard logic treats it like any other destination. Writing the program counter redirects execution, which makes every register write a potential branch. That asymmetry, not importance or convention, is why one is in the file and the other is not. Section 9.3 has the full argument, including why `R7` is not a view of the program counter (errata 100).

**`R13` as the frame pointer is convention and nothing more.** No instruction, no trap and no page walk knows about `R13`. The reason to put it high rather than low is the register-save mask (`PUSHM`/`POPM`): a prologue wants the callee-saved registers contiguous so that one instruction saves them, and `R13` adjacent to `R14` is a tight cluster. AArch64 puts its frame pointer at `X29` for the same reason, and could have put it anywhere.

### 2.2 Special registers and the status word

| Register | Width | Notes |
|---|---|---|
| `PC` | 64 | not a register of the file; read with `LEA 0(PC), Rn` |
| `PSW` (status word) | 16 | the flags `N Z V C`, the trace bit, the interrupt priority, the current and previous mode, the user-memory guard `UA`; layout in manual 6.2 (bit positions are the System v1 positions) |
| `FPSR` | 5 | sticky floating-point exception flags (section 4.9); saved with the status word as part of the thread context |
| `DP` | 64 | direct page base; three copies, kernel / supervisor / user |
| `ASID` | 16 | address space identifier |
| `PTBR`, `KTBR` | 64 | page table bases: one per address space, and the kernel's (split translation, section 8.2) |
| `DMW0`, `DMW1` | 64 | direct mapping window configuration (section 8.3) |
| `EPC`, `EPSW`, `EVA`, `ECAUSE` | 64/16/64/16 | exception program counter, saved status word, faulting address, cause |
| `VBR` | 64 | vector base |
| `MMUCTL` | 64 | translation enable and control |

The system registers are read and written by `MFSR` and `MTSR` with an 8-bit register number (manual 9.3.6, 6.5), which leaves room for the registers still to come. The number of `KTBR` and the full list are open (J.6.4). A flag `DIT` in the status word promises data-independent timing (manual 9.3.7; its position and what is constant-time while it is clear are open, J.9.2).

**The status word and the flags.** The flags are the PDP-11's four, in two groups: `C`, and `{N, Z, V}`. No instruction writes part of `{N, Z, V}` or writes it conditionally. Moves, loads, stores and the compare-and-branch instructions write no flags; shifts write the same flags for every count; rotates and the funnel shift write none (section 4.3). The mode field has three modes with the PDP-11's encoding (kernel, supervisor, user); supervisor is defined, banked and unused (manual 6.2.1; whether it has a use is open, J.6.9).

**`DP` is primarily an encoding feature.** It makes `d(DP)` an address form that needs no base register: global data is reached with one instruction and no relocation. It is the durable form of the 6502 zero page — not "a register file in memory," which was a 1975 economy, but "the shortest address form the ISA has," which is permanent.

**`DP`'s three mode-switched copies serve two distinct jobs**, and because the copies are separate the two do not conflict:

| Copy | Role |
|---|---|
| kernel | the **per-CPU pointer** (section 17.4) — every SMP kernel builds one by hand; here it is a register that already exists |
| user | the **thread pointer** (section 19.3) — which makes local-exec thread-local storage one load |

`DP` exists for code density; it is also what both an SMP kernel and a threaded C runtime need most, in the mode where each needs it.

### 2.3 Floating point

**Floating point operates in the general registers.** There is no FP register file.

A `binary64` value occupies one register exactly. Registers hold raw bits and the instruction decides the interpretation: `FADD R1, R2` reads them as `binary64`, `ADD R1, R2` reads them as integers, and nothing distinguishes the two at rest.

What this buys: no second register file, no second set of read ports, no transfer instructions, no separate FP context in the process control block, no split calling convention. On a small implementation the FP register file is among the largest single blocks on the die. RISC-V standardized this arrangement as Zfinx for exactly this reason.

**Consequence, stated explicitly for the ABI document:** an integer operation on a register holding a `binary64` destroys it, with no trap and no tag. This is intended behavior.

`binary32` values occupy the low 32 bits, sign-extended — the same convention as the 32-bit move, so one rule covers narrow integers and narrow floats alike; `binary16` likewise.

The calling convention follows from this: floating-point values are passed and returned in the general registers exactly as integers are, and `long double` is `double`. Floating-point exception flags are recorded in `FPSR` and never trap (section 4.9). Any NaN that an arithmetic or conversion operation creates is the canonical quiet NaN.

---

## 3. Instruction format

### 3.1 The prefix code: what and how long, in one match

Instructions are 1 to 3 **16-bit parcels**, parcel-aligned: 2, 4 or 6 bytes (the one exception is `MOVQL`, which carries a 64-bit literal and is ten bytes, the literal not counted as part of the instruction: manual 9.2.3). Every instruction begins with a parcel whose top 3 to 16 bits are a **prefix**; the prefixes form a **prefix code** (a set of bit strings none of which begins another, so that the first parcel matches at most one leaf and the match needs no look-ahead). The prefix selects a **leaf**, a group of mnemonics that share one *form*; the form lists the operand shapes and the leaf fixes where every field lies. After the prefix comes the sub-opcode, which selects one mnemonic of the leaf, and then the pieces of the operands: register fields from bit 0 of the first parcel upward, the last register operand lowest, displacements and immediates after them, the widest field last. No bit is padding. The grammar `spec/pdp64/pdp64.hbnf` is the definition; the manual's [chart of every leaf](manual/dictionary/by-encoding.md) is generated from it; the counts (forms, leaves, how many are one, two and three parcels) are in `spec/pdp64/tables.md` and manual 9.1.

The lengths of the prefixes were chosen by an optimiser (`tools/encopt`, whose C translation is a work item) that was given the compiled corpus, so the shortest prefixes belong to the forms the compiler emits most. It will be run again once the open items are decided.

**The prefix is the Huffman code of the first parcel** (the commonest symbols get the shortest strings), with the length of the instruction as a by-product of the match. What matters for the front end is that **length is a function of the first parcel alone**:

| Architecture | Length is a function of |
|---|---|
| **pdp64** | the prefix of parcel 0 (a lookup on at most 16 bits) |
| PDP-11 | both 6-bit mode/register specifiers of word 0 |
| x86 | prefixes, opcode, ModR/M and SIB, in sequence |
| VAX | every operand specifier, parsed in order, some requiring a memory reference first |

Each row down that table costs more front-end logic and more serialization before the next instruction's address is known. The pdp64 row is a lookup, not a parse, and it needs only the first parcel. It is not free: the lookup is up to 16 bits wide, a front end that decodes several instructions a cycle needs one at each parcel position, and in the timing model the decoder pays one cycle of length-decode latency on every taken branch and refill (manual 9.1, commentary). The first encoding's two-bit length field was cheaper to decode and denser nowhere.

A first-parcel pattern that matches no prefix is an illegal instruction; so is a sub-opcode no mnemonic uses and a hot-register index beyond the table, so a wild jump fails early and nothing is undefined (manual 9.1.5).

### 3.2 What lands at each length

The density argument depends on this distribution. **Most instructions are not six bytes.**

| Parcels | Bytes | What it holds (manual 9.4.3) |
|---|---|---|
| 1 | 2 | register-to-register work and the whole conversion set; a memory operand through a hot base register with a small displacement, a load or store from the stack pointer at a small offset; a constant of a few bits; `PUSH`, `POP`; single-operand operations on a register; short branches; the fused pairs; the one-parcel system words |
| 2 | 4 | a base register with a 12-bit displacement, post-increment and pre-decrement with a stride, scaled index, PC-relative within ±32 KiB; immediates of up to 18 bits; branches within ±64 KiB; `SOB`; the compare-and-branch forms; most of the bit, block, floating-point and atomic groups |
| 3 | 6 | displacements to ±128 MiB; 32-bit immediates, absolute addresses and PC-relative offsets (±2 GiB); branches within ±4 GiB; bitfield operations that need a position and a width |
| 5 | 10 | `MOVQL #imm64, Rd` |

Compiled code sits overwhelmingly in the first two rows. The measured averages are in manual 9.2.13 and appendix F (about 3.3 bytes per instruction in the compiler's output; about 2.9 per executed instruction on the large programs). This is Thumb-2 territory, and better than a fixed 32-bit RISC encoding.

The bound is a claim about **carriers, not about the instruction stream**: the decode register holds any instruction of three parcels in one 64-bit word with room to spare, as do the assembler, the disassembler, the simulator and the compiler back end. It says nothing about what a sequence of instructions occupies in memory.

Byte-granular encoding — x86's and the 6502's — remains rejected. Both were 8-bit-bus machines where a byte was the natural fetch unit. On a 64-bit datapath it buys roughly a tenth of the code size and costs a full alignment rotator plus cross-line splice logic in the front end.

### 3.3 Alignment and fetch

**Instructions are aligned to 2 bytes and may cross any boundary**, including 8-byte, cache-line and page boundaries. There is no padding rule and no assembler alignment obligation.

**Byte order is little-endian**, for data and for instructions: a parcel is a 16-bit little-endian unit in memory. The charts number bits most significant first: a parcel's bit 15 is the first bit of its record.

A worst-case instruction — six bytes at offset 6 — spans two aligned quads, so the fetch path needs a two-deep parcel buffer. Forcing instructions inside an 8-byte window would buy that simplification, and it would cost 5–10% of code size in padding plus an alignment obligation propagated through the assembler, the linker and every hand-written stub. Not worth it. (`MOVQL` is ten bytes; it crosses at most one more window, and the literal is not decoded.)

### 3.4 The reach of the operands

An addressing mode is not a field: it is the leaf, whose form lists the shape of each operand (section 5). The reach grows with the length of the leaf:

- a displacement of a few bits in one parcel (a hot base register), 8 to 12 bits in two parcels, 28 bits in three;
- an immediate, absolute or PC-relative operand names no base register, so no field is spent on one and the later parcels are all value: 16 bits at four bytes and 32 bits at six;
- a branch has a field of 6 to 9 bits in one parcel, 16 bits in two and 32 bits in three, counting parcels from the first parcel of the branch.

The dictionary lists the width and reach of every operand shape (manual 9.4 and 9.5); the figures above are the ones the manual states and are not repeated per instruction here. Immediates are sign-extended; displacement fields are two's complement. The assembler gives each operand the shortest leaf that holds it.

### 3.5 The one-memory-operand rule

**At most one operand may be a memory reference.** The other, where present, is a plain register.

This is x86's ModR/M idea, made architectural rather than left as an artifact of the encoding. In descending order of value:

- the operand sequencer handles one specifier, not two;
- at most **one** register side effect per instruction;
- the fault matrix collapses to the one in section 7.3;
- the freed bits are what pay for thirty-two registers and a useful displacement.

The one departure is the block operations (section 4.7), admitted under section 1.1 and costed in section 7.5.

---

## 4. The instruction groups

The instruction set is described, one entry per instruction, in chapter 9 of the manual; the encoding of every leaf is in the dictionary. This section keeps the *reasons*: why each group has the shape it has. The numbers are not repeated.

**Opcode and length are orthogonal.** `ADD` means `ADD` at every length, with only the operand's reach changing. In the prefix code each leaf has the length its operands need, and the optimiser gives the commonest leaves the shortest prefixes. The old question "does this operation deserve a top-level opcode?" has become "what does the corpus say its common form is?": an operation whose common case is register-to-register gets a one-parcel leaf, and an operation whose common case has a memory operand, an immediate or three registers is two or three parcels whatever its prefix, so it costs nothing to be rare. (That was the allocation rule of the first encoding, which had a fixed opcode field and parcel-1 escape groups; the prefix code applies it automatically.)

### 4.1 Moves and conversions

Sub-quad sizes are kept. C `int` is 32 bits in every ABI worth targeting, and ELF, timestamps, and most on-disk and wire structures are full of 32- and 16-bit fields. Without a 32-bit load a struct field load becomes two 16-bit loads, a shift, and an or. `MOVQ`, `MOVL`, `MOVW`, `MOVB` load and store 64, 32, 16 and 8 bits with sign extension; `MOVZL`, `MOVZW`, `MOVZB` load with zero extension.

**A register is always written in full.** Narrow loads sign- or zero-extend to the full 64 bits; there is no partial-register write anywhere in the machine. This is the rule x86-64 arrived at for 32-bit writes and failed to apply to the 8- and 16-bit forms, where preserved upper bits make every narrow write a read-modify-write of an architectural register — a merge dependency, and the most expensive surviving x86 legacy.

**With a register operand the same mnemonics are the conversion set.** `MOVB R1, R2` sign-extends the low byte; `MOVZW R1, R2` zero-extends the low word. There is no `CVT` group. This follows the rule: conversion instructions, never mode bits.

**The base of every PC-relative displacement is the address of the first parcel of the instruction itself** — for `d(PC)` operands, for `LEA d(PC), Rn`, for `CALL d(PC)` and for all branches. A PC-relative *operand* displacement counts bytes; a *branch* displacement counts 2-byte parcels. The reason for the start rather than the end of the instruction is that the displacement then does not depend on the length chosen for the instruction itself: an assembler that picks the length from the displacement would otherwise have the displacement depend on the length and iterate, while with this rule every instruction only ever grows, so branch relaxation is monotone and terminates (section 9.9).

**`LEA` is also how the program counter is read.** `LEA 0(PC), Rn` puts the address of the `LEA` itself in a register in one instruction, with no ambiguity about which program counter is meant (section 9.3). The six-byte form forms any address within ±2 GiB of itself PC-relatively — one instruction where LoongArch needs a pair (section 15).

**64-bit constants.** `MOVQL #imm64, Rd` carries the literal in the instruction (ten bytes, the one instruction longer than six, errata 85); a constant that fits 32 bits sign-extended is one immediate instruction of at most three parcels; the alternative is a PC-relative constant pool, written `MOVQ =K, Rd` with an explicit `=` (nothing is pooled silently, and a `MOVQ #imm` whose constant fits no `MOVQ` form is assembled as `MOVQL`).

**One-parcel forms abbreviate the common cases** — loads and stores through a hot base register and through the stack pointer at small offsets, `LEA` from `SP`, a short immediate — and they are not separate mnemonics: the assembler chooses the shortest leaf that holds the operands (section 4.13).

**Unaligned moves.** `MOVUB`, `MOVUW`, `MOVUL`, `MOVUQ` perform the two accesses in a defined order for the cases that need them (section 7.4).

### 4.2 ALU, register destination

`ADD`, `SUB`, `BIC`, `BIS`, `CMP` and `BIT` are the PDP-11's double-operand set, unchanged in name and meaning — with one exception, the order of `CMP`'s operands, below. `XOR`, `AND`, `MUL`, `MULH`, `SHL`, `SHR`, `SAR` are what a 64-bit machine needs and a 16-bit one did in software.

**`CMP` computes `reg − rm` and is written `CMP Rd, rm`, register first.** PDP-11 `CMP a,b` computes `a−b`. Here the destination of an ALU operation must be a register, so a literal `src,dst` reading would force every comparison of a register against an immediate or a memory operand to reverse its branch condition, and every compiler would pay for it. `CMP a,b` followed by `BLT` still reads "branch if a < b", as on the PDP-11; only which side must be a register differs. `BIT` is symmetric and unchanged. The floating-point compare is register-first in the same way.

**Flags.** `ADD` sets `C` on a carry out. `SUB` and `CMP` set `C` on a *borrow* (the PDP-11 sense), so `BHIS`/`BCC` mean "no borrow", unsigned `≥`, and `BLO`/`BCS` mean a borrow occurred. `V` is signed overflow.

**ALU operations are 64 bits, always.** No size field. This eliminates byte-lane multiplexing in the ALU and, with section 4.1, eliminates partial-register writes entirely. Narrow arithmetic is done wide and converted at the store, which is what compilers do anyway.

Shift counts come from the second operand — a register, an immediate, or memory. No dedicated shift-count register. x86's `CL` saves opcode bits and costs a permanent register shuffle in every hand-written loop.

#### 4.2.1 `MUL` is sign-agnostic; `MULH` replaces `MULU`

There is no separate `MULU`: **the low 64 bits of a two's-complement product are identical whether the operands are read as signed or unsigned.** Signedness affects only the bits above the word, so one low-half multiply serves both, and a second instruction would duplicate it. The assembler accepts `MULU` as an alias for `MUL`.

The *high* half is needed too: without it 64 × 64 → 128 is impossible, and every bignum multiply, 128-bit fixed-point operation and divide-by-constant-via-reciprocal is unimplementable.

| | |
|---|---|
| `MUL` | low 64 bits of the product. Sign-agnostic |
| `MULH` | high 64 bits, operands read as signed |
| `MULHU` | high 64 bits, operands read as unsigned |

This is RISC-V's arrangement (`MUL`, `MULH`, `MULHU`, `MULHSU`) and it is correct for the same reason. `MULHSU` — signed times unsigned, needed when a bignum's signed top limb meets an unsigned one — is a candidate rather than a commitment, since the only caller is a bignum library's innermost loop and it can be synthesized with one correction step.

With `MULH` present, divide-by-constant becomes multiply-by-reciprocal, which is what every compiler emits and is roughly thirty times faster than the `DIV` sequencer. `DIV`, `DIVU`, `MOD`, `MODU` stay for the general case, in the less common leaves: **compilers turn division by a constant into `MULH` plus a shift**, so a genuine runtime-variable divide is rare, and a 32-cycle non-restoring sequencer does not notice one extra parcel of decode.

#### 4.2.2 Shift and rotate flag semantics

The flag semantics of every shift and rotate are stated, including the zero-count and count-≥-64 cases that x86 leaves undefined, and leave no ambiguity between a plain rotate and a rotate through carry (section 4.5).

| Operation | `C` | `N`, `Z` | `V` |
|---|---|---|---|
| `SHL` | last bit shifted out of bit 63 | from the result | cleared |
| `ASL` | last bit shifted out of bit 63 | from the result | `N` xor `C` (the PDP-11 rule: set if the sign changed) |
| `SHR`, `SAR`, `ASR` | last bit shifted out of bit 0 | from the result | cleared |
| `ROR`, `RORI`, `RORI32`, `DSHR` | **unchanged** | **unchanged** | **unchanged** (no flags are written) |

Three rules behind that table (manual 9.3.4 and 9.8):

- **Shifts write the same flags for every count.** A count of zero gives `N` and `Z` from the unchanged operand, `V` = 0 (for `ASL`, `N` xor `C` with `C` = 0) and `C` = 0. This is not x86's rule, where a zero count leaves the flags undefined or unchanged: a flag write that depends on the data is a problem for any implementation that renames the flags, and a defined, uniform write is not.
- **A count of 64 or more** shifts the value entirely away: `SHL`/`SHR` give zero, `SAR` gives the sign, and `C` takes the last bit that left. The count is treated as the unsigned value it is, so there is no surprise at exactly 64 the way there is on machines that mask the count to six bits. `ROR` is the exception and does take its count modulo 64, because a rotate by 64 is the identity by definition.
- **No rotate is through carry, and rotates write no flags.** A rotate is a plain 64-bit rotate. Multi-precision shifting uses `DSHR` (section 4.6), not a carry chain, and `DSHR` leaves every flag alone — a funnel shift in a loop must not disturb a carry the surrounding code is maintaining. Software that wants the wrapped bit tests it with a shift.

### 4.3 Flags

**Condition codes are retained, and every ALU operation writes all four uniformly.** x86's arrangement, where `INC` and `DEC` write some flags and not others, exists to make one obsolete instruction a byte shorter and has complicated every implementation since. Moves and loads write no flags (the current rule: manual 9.3.4 and 9.6.4; the PDP-11's `MOV` wrote `N` and `Z`).

Flags are the cheap choice here. Fused compare-and-branch needs a comparator in the branch unit and a third register read port; flags need a four-bit latch. They become expensive only under register renaming, and the flag rules make that cheap too: the compiled corpus shows that 68% of instructions write a flag and only 1.5% read one (manual 9.3). LoongArch and RISC-V both chose the other way; section 15 says why that does not move us.

### 4.4 Branches

The conditional branches are the complete PDP-11 branch set, unchanged, with four reaches and no long-branch instruction and no trampolines: the displacement is signed, **counts 2-byte parcels from the first parcel of the branch instruction itself** (section 4.1), and its field grows with the length (manual 9.10.1). Branch relaxation in the assembler reduces to choosing a length.

**Condition numbers.** The condition of a branch is its number in the family: `ne`, `eq`, `pl`, `mi`, `vc`, `vs`, `cc`/`hs`, `cs`/`lo`, `ge`, `lt`, `gt`, `le`, `hi`, `los`, plus the unconditional `BR`. The instructions that take a condition as a word of their own (`SET`, `TRAPCC`) use the same names; the numbers are in the grammar and the dictionary's constants.

**`SOB Rn, dst`** — subtract one from `Rn`, branch if the result is nonzero. Restored from the PDP-11, where it could only branch *backward*, its 6-bit displacement being unsigned and subtracted from the program counter. Here the displacement is signed and counts parcels, so it branches either way, and `Rn` is one of thirty-two rather than one of eight. `SOB` is four bytes.

`SOB` does not save bytes — `DEC Rn` plus `BNE` is also four — but it saves an instruction issue, which on a non-pipelined machine is a cycle per loop iteration. It folds the decrement in, which is why it earns its place where a fused compare-and-branch against zero would not have.

**`CBCC` — compare and branch** (manual 9.10.4). `CBCC` compares a register with zero, with an immediate or with a second register and branches on the condition. **It writes no flags**: that is the current design and differs from the first iteration, where the fused branch wrote the flags of `CMP`. The reason is the flag rule above: a fused instruction that also writes flags would be an instruction doing more than its name says. The compiler forms a `CBCC` only where the flags are dead after the branch; where no form reaches (a label in another object, an operand pair no form holds) the assembler emits `CMP` and `BCC` instead (manual 9.10.8). Which forms exist and their reach are in the dictionary; they depend on the encoding optimiser and are not repeated here.

**The fused pairs** (manual 9.10.7). Four pairs of instructions that the compiler emits adjacent so often that they became one instruction each: `MOVCALL` (a register move followed by a call), `POPRET` and `POPMRET` (a pop, or a masked pop, followed by a return), and `MOV2` (two register moves). The assembler never fuses; choosing a fused instruction is the compiler's job. A fused instruction is restarted whole after a fault (manual 9.15.2). They are the commonest idioms of compiled code and the reason for the 6.48% to 9.66% density gain of the early prefix-coded iterations (manual 9.1, commentary).

### 4.5 Single-operand instructions, rotates, and the stack

`CLR`, `COM`, `INC`, `DEC`, `NEG`, `TST`, `ADC`, `SBC` are the PDP-11's single-operand set. `ASL` and `ASR` are the by-one forms of `SHL` and `SAR` in a one-parcel encoding — two bytes against four. They earn that because halving and doubling are frequent; rotate-by-one is not.

The PDP-11's `SWAB` and `SXT` are absent. `SWAB` is subsumed by `BSWAP`; `SXT` is subsumed by the conversion set, which is strictly more general (section 14.3).

#### 4.5.1 Why one rotate direction, and why it is `ROR`

`ROL x, #n` is exactly `ROR x, #(64 − n)`, so for an **immediate** count the assembler complements the operand and emits `RORI` (the immediate-count rotate) — same instruction, same length, no cost whatever. Only a register-held count needs an extra `NEG`, and immediate counts dominate overwhelmingly in the code that rotates at all: SHA-256's σ and Σ functions, BLAKE2, ChaCha20, SipHash and xxHash all rotate by compile-time constants.

AArch64 reaches the same conclusion more firmly — it has **no `ROL` instruction at all**. RISC-V's Zbb extension provides `ROL` and `ROR` for register counts but only `RORI` for immediates, for precisely this reason.

Right is also the direction the hardware prefers. A funnel shifter that forms `{x, x}`, shifts right by *n* and keeps the low 64 bits yields `ROR` directly; `SHR` is the same structure with the upper half zeroed and `SAR` with it sign-filled. `SHL` is the one operation needing the shift amount complemented. Three of the four ALU shifts are the shifter's natural direction, so matching the rotate to them is consistency rather than coin-flipping.

**Rotate-through-carry is not the right fix.** The PDP-11's `ROL` and `ROR` were 17-bit rotates through `C`, which is what makes `ASL lo` followed by `ROL hi` shift a multi-word value. Their only real use is multi-precision shifting one bit per instruction, and the modern primitive for that is a double-width funnel shift — x86's `SHLD`/`SHRD`, ARM's `EXTR`. A 128-bit shift by *k* becomes two instructions instead of *k* iterations. `DSHR` (section 4.6) is that instruction, so rotate-through-carry has no customer.

`RORI32` rotates the low 32 bits and sign-extends the result like every other 32-bit result, so the compiler's convention for 32-bit values needs no fix-up after it. `ROL` has no 32-bit form.

#### 4.5.2 The stack

`PUSH` and `POP` are one parcel and exist because the autoincrement modes cost an extra parcel, and stack traffic is where those modes get used. **`PUSHM #mask` and `POPM #mask`** save and restore a register set: bit *n* of the mask is `Rn`, the mask is 32 bits, and the forms carry it in 8 bits (two bytes), 16 or 24 bits (four) and 32 bits (six); a mask containing `R14` is reserved (manual 9.3.8). `PUSHM` stores the lowest-numbered register at the highest address.

`CALL dst` pushes the return address on `SP`; `RET` pops it. Section 14.2 compares this with the PDP-11's `JSR`/`RTS`.

### 4.6 Bit, field and rotate instructions

Bit manipulation is not an extension on a machine that does filesystem work, bignum work or garbage collection — LoongArch treats it as core, with `CLO`/`CLZ`/`CTO`/`CTZ`, `BSTRINS`/`BSTRPICK`, `BYTEPICK`, `REVB`, `REVH` and `BITREV` all in the base ISA, and that is the right call. The set is `CLZ`, `CTZ`, `CLO`, `CTO`, `POPCNT`, `BSWAP`/`BSWAPW`/`BSWAPL`, `BITREV`, `ROR`/`RORI`/`RORI32`, `DSHR`, `EXTB`/`EXTZB`/`INSB`, `XNORPOP`, `CLMULL`/`CLMULH` and the UTF-8 words (manual 9.8 and 9.9). Operations that need three registers or a position and a width are longer than two bytes whatever their prefix.

#### 4.6.1 UTF-8

Most of what UTF-8 needs is general bit manipulation, which the set above provides. `UTF8LEN Rd, Rs` is the exception that is nearly free: it is `CLO` on the low byte, mapped to a length, with an invalid leading byte giving 0. A shifter and a four-entry table.

`UTF8DEC` and `UTF8ENC` earn their place for a different reason — not speed, but that the **validity rules are where the bugs are**. `V` is set for any of:

- a continuation byte not matching `(b & 0xC0) == 0x80`;
- an **overlong** encoding — a 2-byte form below U+0080, a 3-byte below U+0800, a 4-byte below U+10000;
- a **surrogate**, U+D800 through U+DFFF, which is not a scalar value;
- a value above U+10FFFF;
- a leading byte of `0xC0`, `0xC1`, or `0xF5`–`0xFF`, which can never begin a valid sequence.

Every one of those is a historical security hole, and every one is three comparators. Software implementations get them wrong or omit them for speed; an instruction cannot. Cost is roughly 300 LUTs of comparator and mux, estimated in the implementation plan. (Where `UTF8DEC` leaves the consumed length and which flag it uses are in its dictionary entry.)

#### 4.6.2 `XNORPOP`

When **both** operands of an inner product are binary (±1), it reduces exactly to

```
dot(a, b) = n − 2 · popcount(a ⊕ b)
```

which is the XNOR-net kernel. `XNORPOP Rd, Ra, Rb` computes `popcount(¬(Ra ⊕ Rb))` — the same quantity with the complement folded in, so the caller needs no `COM` — handling 64 elements at a time and replacing `XOR`, `COM` and `POPCNT`. It is cheap because `POPCNT`'s adder tree is already being built for its own sake. Its uses are binary-activation networks, Hamming distance, bitset intersection cardinality, and counting a garbage collector's mark bitmap.

> **`XNORPOP` does not serve sub-1-bit quantized language models.** In Samsung's LittleBit and LittleBit-2 the *weights* are ±1 but the **activations are FP16**, so the inner loop is not a popcount. It is a conditional add or subtract of a real value under a one-bit control, which is why the authors call the method MatMul-free: there are no multiplies in the contraction, but there is no popcount either.

**The scalar ISA should not try to serve it.** The LittleBit kernel is two binary-factor contractions with an on-chip rank-r intermediate, and its op count equals its weight-bit count exactly, so it is bandwidth-bound with no arithmetic intensity to exploit. It wants a bus-mastering accelerator with its own DMA and hundreds of sign-flip-accumulate lanes: the device route of manual chapter 8, with the LB64 design as the worked, *proposed* example. Nothing in that design needs an instruction (section 16).

#### 4.6.3 `CLMUL`, and why not `CRC`

`CLMULL`/`CLMULH Rd, Ra, Rb` compute the low and high 64 bits of the 128-bit carry-less product of `Ra` and `Rb` — polynomial multiplication over GF(2), which is an AND-XOR tree with no carry propagation and therefore *cheaper* than an ordinary multiplier of the same width.

This is deliberately chosen over a `CRC` instruction. x86 (SSE4.2 `CRC32`) and ARM (`CRC32B/H/W/X`) both committed a polynomial to the architecture — x86 chose CRC-32C/Castagnoli, ARM chose the Ethernet CRC-32 — and a program needing the other one gets no help. Carry-less multiply is the *primitive beneath* all of them: any CRC of any polynomial reduces to `CLMUL` plus a Barrett reduction, and the same instruction serves GF(2^k) arithmetic for Reed–Solomon erasure coding and the GF(2^128) multiply at the heart of AES-GCM. **There are no `CRC32` or `CRC32C` instructions.** One instruction, no polynomial baked in, three unrelated users. The VAX `CRC` instruction that section 11 rejects was table-driven and committed to one polynomial per table; this is the better answer to the same need.

#### 4.6.4 `DSHR` — the funnel shift

`DSHR Rd, Ra, Rb, #n` forms the 128-bit concatenation `Ra:Rb`, shifts it right by *n*, and writes the low 64 bits to `Rd`. Three registers and an immediate, so it is a long (six-byte) instruction. This is x86's `SHRD` and ARM's `EXTR`, and it is the general tool for everything that rotate-through-carry served one bit at a time:

```
        ; shift the 128-bit value hi:lo left by k
        DSHR    hi, hi, lo, #(64-k)
        SHL     lo, #k
```

Two instructions for any *k*, against *k* iterations of shift-and-rotate-through-carry. It also covers 128-bit rotates, extraction of a 64-bit field straddling a word boundary — which is what a bit-stream reader does on every symbol — and, with both sources the same register, `DSHR Rd, Rn, Rn, #n` **is** a rotate right by *n*. That last identity is the useful check that `DSHR` is the right primitive and `ROR` is its one-register special case.

#### 4.6.5 `BSEL`, and the cryptographic words

`BSEL` selects bit by bit between two registers under the control of a third: `Ch` and `Maj` of SHA-2 in one instruction each, and the constant-time swap of two registers in two (manual 9.9.6, decided). The AES round, key-schedule and SHA-256 and SHA-512 words of the secure core (manual 9.9.7; [`crypto-secure-core.md`](crypto-secure-core.md)) are decided in principle, each taking a time independent of its operands; their semantics are not yet specified (J.9.12).

### 4.7 Block memory operations

The granted exception to the one-memory-operand rule (section 3.5), admitted under section 1.1. `MCPY Rd, Rs, Rn` is *destination pointer, source pointer, count*; `MMOV` is the same but correct for overlap; `MSET Rd, Rv, Rn` fills `Rn` bytes with the low byte of `Rv`; `MCMP` compares; `MSCN` scans for the low byte of `Rv` and `MSCNN` for the first byte **not** equal to it; `MVAL Rd, Rn` validates `Rn` bytes as UTF-8 (manual 9.11).

**Semantics, stated as a loop because that is exactly what it is.** For `MCPY`:

```
while Rn ≠ 0:
    byte at (Rd) ← byte at (Rs)
    Rd ← Rd + 1;  Rs ← Rs + 1;  Rn ← Rn − 1
```

All three registers are updated as work completes. On completion `Rn` is 0 and `Rd`, `Rs` point one past the end. `MCMP` and `MSCN` stop early and leave the pointers at the byte that stopped them, so they give both the result and the position — which is what `memcmp`, `strcmp`, `memchr` and `strchr` all actually need.

**Why this is not VAX `MOVC5`.** `MOVC5` takes its operands from general specifiers, which may themselves be memory, and its architectural definition requires the original operand values to survive the instruction. That forces hidden intermediate state and `PSL<FPD>` to resume from the middle. These instructions take their operands from registers and *consume them as progress*. There is no hidden state because the state is the registers, and the registers are already saved and restored by every context switch that exists. Section 1.1 clause (c): the mechanism is absent.

This is the same design ARM reached in 2022 with `FEAT_MOPS`, whose specification says the registers "are updated to reflect the bytes that were actually set before the fault, so progress is not lost," and the same one IBM reached decades earlier with System/360's `MVCL` and `MVCLE`, which are interruptible with progress in the register pair. ARM splits each operation into a prologue, main and epilogue instruction so that implementations may choose their own block size; that complication is unnecessary here, because section 7.5 gets the same freedom from a weaker statement.

**Implementations may move more than a byte per step.** The architectural requirement is only that at every point where an exception can be taken, the register state is *consistent with* byte-at-a-time progress. A 64-byte-per-cycle engine satisfies this by only becoming interruptible at block boundaries and updating all three registers atomically with each block. Nothing in the architecture reveals the block size.

What another core may observe: the accesses inside one block operation are unordered with respect to one another and only the final memory and the register progress are defined (errata 39 item 7; manual 7.5.8). The rest of the ordering, the tearing, the publishing fence and the behaviour on faults are open (manual J.7.6).

**`MSET` with `Rv = 0` is the range-zeroing instruction**, so `bzero` and `calloc`'s clear are one instruction. It needs no separate opcode.

#### 4.7.1 `MVAL` — whole-buffer UTF-8 validation

`MVAL Rd, Rn` scans `Rn` bytes at `(Rd)` and stops at the first byte that cannot be part of a valid UTF-8 sequence, by the rules of section 4.6.1. On completion `Rn` is 0 and the buffer is valid; otherwise `Rd` addresses the offending byte and `Rn` holds the bytes remaining, so the caller gets the offset for free.

**It costs almost no hardware.** `MVAL` is the validity comparators — already built for `UTF8DEC` — wired to the streaming sequencer, already built for `MCPY`. The instruction is a connection between two existing blocks.

The case for `MVAL` is not throughput. The alternative is a SWAR loop (see the glossary) at roughly two to three cycles per byte, which is respectable. The case is the one section 4.6.1 makes for the per-character case: **every program that accepts text from outside itself must validate it, and the validity rules are the part software omits for speed or gets wrong.** A terminal emulator, a JSON or XML parser, a filesystem with UTF-8 names, an HTTP server, anything reading a file someone else wrote. An instruction that cannot be wrong, for an operation performed on every input, at the cost of a wire between two existing units.

### 4.8 Tag branches and transfers through memory

**`BTAG`/`BNTAG Rn, #tag, dst`** branch if the three low bits of `Rn` equal (or differ from) a tag. Like `SOB` they are four bytes at least. See section 6.3 for why they and `JTAG` exist.

**`JMPI dst`, `CALLI dst`, `JTAG`** take their target *from memory* rather than computing it: `JMPI`: `PC ← [EA]`; `CALLI`: push the return address, then `PC ← [EA]`; `JTAG`: `PC ← [Rb + d + 8 × (Rx & 7)]`, tag dispatch (section 6.3). Each needs a memory operand, so each is four bytes at least. The scaled-index form of `JTAG` carries a base *and* an index register: the index register is the tagged register, the scale is ignored (the stride is always 8) and `Rb + d` is the table's address.

**Grouping them is the point.** All three need exactly one thing the rest of the machine does not: the next program counter sourced from the load-return path instead of from the address generator. That is one multiplexer input and one decode comparison when they share a group, against three scattered decode cases when they do not. One group is fewer entities, less verification surface, and marginally fewer gates — section 1.2 rule 3.

#### 4.8.1 One deferred reference, admitted

Section 5.2 removes every deferred addressing mode. This group admits exactly one deferred reference, for control transfer only, and section 1.1's test is what admits it.

**The benefit.** Four patterns that are two instructions and a scratch register without it, and one instruction without one:

```
        ; PLT stub, dynamic linking
        JMPI    got_slot(PC)            ; otherwise: MOVQ got_slot(PC),Rt ; JMP (Rt)

        ; virtual method dispatch
        CALLI   vtbl_off(Robj)          ; otherwise: MOVQ vtbl_off(Robj),Rt ; CALL (Rt)

        ; call through a function pointer in a struct
        CALLI   handler(Rdev)

        ; tail call through a jump table
        JMPI    (Rtab)(Ridx*8)
```

Every cross-module call in dynamically linked code goes through the first; every virtual call in an object system or a CLOS-style dispatcher is the second.

**Why clause (c) of section 1.1 is satisfied.** The objection to deferred modes was specific: *a fault can occur mid-specifier, after a register has already been side-effected, at an address that itself came from a load that may also have faulted.* Taking those in turn:

- **No register is side-effected.** `JMPI` and `JTAG` write no register at all, so there is nothing to undo.
- **The deferred reference is in the branch path, not the operand path.** The operand sequencer still handles at most one memory specifier, so the one-memory-operand rule holds unchanged.
- **The fault is clean by ordering.** If the target load faults, nothing has happened: the program counter still addresses the instruction, no register has changed, and `RTI` re-executes it. An ordinary abort, not a restart problem.

`CALLI` writes `SP`, so its order is **specified: load the target, then push, then transfer.** A fault on the load leaves nothing changed; a fault on the push is an ordinary `-(SP)` fault handled by buffer-and-commit (section 7.2). The reverse order would leave a return address on the stack for a call that never happened, and is forbidden.

The mechanism the rule protected against is structurally absent, which is the test. What remains is one extra memory reference in the branch path — a cycle on a non-pipelined machine, a load-to-branch dependency on a pipelined one, which is what the two-instruction sequence costs anyway. **The fault matrix (section 7.3) has one row** for this group and no other.

### 4.9 Floating point

`binary64` gets first-class two-byte instructions (`FADD`, `FSUB`, `FMUL`, `FCMP`), since on a 64-bit machine it is the common case; the rest of the floating-point set (divide, square root, the fused multiply-add family, sign and selection, classify, round, convert, `binary32` and `binary16`) is in longer leaves (manual 9.12; the dictionary lists every word).

**Spelling.** A floating-point operation is the integer operation with an `f` in front (`FADD`, `FSUB`, `FMUL`, `FDIV`, `FSQRT`, `FMADD`, `FABS`, `FMIN`, `FMAX`, `FCMP`, `FCLASS`, `FRINT`…). The default width is `binary64`, the machine's native float; any other width is a **decimal suffix in bits**: `FADD` is `binary64`, `FADD32` is `binary32`, and `FADD16` is `binary16` (half precision). The rounding variants of `FRINT` are one letter (`FRINTZ`, `FRINTM`, `FRINTP`, `FRINTA`). The spellings `FADDD`, `FADDS`, `FMIND`, `FRINTDZ` … are assembler aliases under the rule of section 4.13; the disassembler never prints them.

`FDIV` and `FSQRT` are in the less common leaves: both are multi-cycle sequencer operations that rarely appear in a two-byte register-to-register form, so the extra parcel of decode is free against their latency.

**`FCMP rd, rm` is register-first, like `CMP`**: it computes `rd − rm` (section 4.2). It sets `N` if `rd < rm`, `Z` if they are equal, `V` if they are unordered, and clears `C`. The signed branches do not yet separate "unordered" cleanly (`BLT` after an unordered compare takes `N xor V` = 1); this is open (J.9.9).

**Operand roles.** For the floating-point words with more than two registers the assembler writes the destination last: `FMADD rs, rt, ru, rd` = `rs·rt + ru`; `FMSUB` = `rs·rt − ru`; `FNMADD` = `−(rs·rt) − ru`; `FNMSUB` = `−(rs·rt) + ru`; each rounded once (section 9.7 explains why they are in the base set). `FDIV rs, rd` is `rd ← rd / rs`. `FCOPYSIGN rs, rt, rd` takes the magnitude of `rs` and the sign of `rt`. `FNEG`, `FABS` and `FCOPYSIGN` work on the bits and do not canonicalize a NaN.

- **Classification**: `FCLASS`, `FCLASS32` — a bit vector distinguishing signaling NaN, quiet NaN, ±infinity, ±normal, ±subnormal, ±zero. Every libm function begins with this dispatch.
- **Rounding to integral**: `FRINT` (to nearest, ties to even), `FRINTZ` (toward zero), `FRINTM` (toward −∞), `FRINTP` (toward +∞) and `FRINTA` (to nearest, ties away from zero, for C's `round()`). `FRINTA` is one more qualifier of the round operation and adds no operation.
- **Conversions** between `binary64`, `binary32`, `binary16` and the integers, including the unsigned 64-bit pair (an out-of-range value or NaN raises `NV` and saturates). C needs both unsigned conversions; without them each is a compare, a branch and several instructions.
- **`binary16` (half precision)**: arithmetic, fused multiply-add, classify and conversions to and from `binary32`, `binary64` and int32. A half lives in the low 16 bits of a register, sign-extended to 64 as a `binary32` is. The set is the `binary32` set minus what a half has little use for, so the decode and hardware are the existing ones with a different width, and the conversions are the part machine-learning code needs most. Left open: the remaining half operations and bfloat16 (J.9.10).

**There are no reciprocal or reciprocal-square-root estimate instructions** (section 9.9 gives the reason).

#### 4.9.1 Exception flags: `FPSR` and `FSFLAGS`

IEEE 754 requires five status flags — invalid operation, division by zero, overflow, underflow, inexact — and C99 `<fenv.h>` needs software access to them. The machine has a sticky five-bit register, **`FPSR`**, laid out as RISC-V's `fflags`: inexact, underflow, overflow, divide by zero, invalid, in bits 0 to 4. Every floating-point operation that can raise one of these ORs it into `FPSR` and **never traps**. One instruction reads and writes the register: `FSFLAGS rs, rd` does `rd ← FPSR; FPSR ← rs & 31`. A clear is a swap with zero, a test-and-clear is a swap with zero, a set is a swap with the bits. `FPSR` is part of the thread context and is saved with the status word. It is not a mode: it never changes what an instruction does, only records what an instruction did. Details: tininess is detected after rounding; a comparison raises `NV` only for a signaling NaN, not for a quiet one.

#### 4.9.2 NaN results are canonical

Every arithmetic or conversion result that is a NaN is the **canonical quiet NaN** — `0x7FF8000000000000` for `binary64`, `0x7FC00000` for `binary32`, `0x7E00` for `binary16` — whatever the operands carried: there is no payload propagation (the RISC-V rule). Without a rule the result would depend on the host that ran an emulator (x86 makes a negative NaN for 0/0), and hardware must do the same for results to match the reference emulator.

**There are no rounding-mode or precision mode bits.** Precision is in the opcode; rounding mode is in the opcode wherever it is not round-to-nearest-even. The PDP-11 FPP's `FPS.FD/FL/FT` mode bits are absent, on the grounds that whether `ADD` means single or double must not be invisible state you save and restore. Section 15 notes that this diverges from LoongArch, RISC-V, ARM and x86 alike. **One gap in the rule is open:** IEEE 754 also requires directed rounding (toward +∞, −∞, zero) for the arithmetic operations, and the instruction set has no such variants except the `FRINT*` family (J.9.10).

**There are no transcendental instructions**; section 9.7 has the argument.

### 4.10 System and atomic instructions

The system group holds the privileged and system instructions (manual 9.14): `RTI`, `RTT`, `RET`, `HALT`, `MTPS`, `MFPS`, `SPL`, `TRAP`/`TRAPL`, `BPT`, the translation and cache maintenance words (`TLBI`, `TLBIA`, `TLBSYNC`, `MTASID`, `MFASID`, `ICINV`, `ICINVA`), `MTDP`/`MFDP`, `MTDMW`, `MFSR`/`MTSR`, `MFCPUID`, `FENCE`, `WFE`, `SEV`, `PROBER`/`PROBEW`, `PUSHX`/`POPX`, `ISYNC`, `HINT`, `NOP` (which doubles as the landing pad, `LPAD`) and the user-memory-guard words `STUA` and `CLUA`. Which are privileged is in manual 6.2.5 and 6.2.6; the rest of the behaviour is in chapter 6.

**`TRAP #n` and `TRAPL #n`** enter the kernel through the vector table; the short form is two bytes so that the common system call is cheap (manual 6.10.2 and 6.13). The numbering of the vectors, and one sentence in chapter 6 that gives two different ranges for the system-call vectors, are for the author (see the report that accompanied this rewrite).

**`MFSR rd, name` and `MTSR name, rs`** read and write a **system register** chosen by name. Both are privileged (an abort outside kernel mode). There is one general pair because the short forms of the group are used up, and eight bits of register number leave room for the registers still to come (a timer compare, an interrupt mask). A write to a read-only register, or a number that is not assigned, is an illegal-instruction abort. What `EPC`, `EVA` and `ECAUSE` contain is defined with the exception entry sequence (manual 6.3; [`pdp64-system-architecture.md`](pdp64-system-architecture.md)).

**`PUSHX` and `POPX`** save and restore the exception state with one instruction each: `PUSHX` pushes `EPSW` and `EPC` on the stack of the current mode and `POPX` pops them. Both words are checked before either is accessed, so an abort leaves nothing changed even when the sixteen bytes straddle a page. A handler that may be interrupted begins with `PUSHX` and ends with `POPX; RTI`. Hardware pushes nothing on exception entry; entry writes only registers and cannot itself fault.

**`ISYNC` and `HINT #n`.** `ISYNC` (privileged, no flags) makes earlier writes to `PTBR`, `ASID`, `MMUCTL` and `VBR` and earlier `ICINV`/`ICINVA` take effect for the instructions that follow it: the architecture promises the effect only after the next `ISYNC` (a small in-order implementation may apply it at once, and software must not rely on that). `HINT #n` (not privileged, no flags) has no architectural effect for any `n`: `0` is a plain no-op hint, `1` a pause for spin-wait loops, `2` a speculation barrier, and every other value is a reserved hint that also executes as a no-op, so software may not use it yet and a later definition may give it a meaning (manual 7.10.1).

#### 4.10.1 Four PDP-11 instructions dropped

`IOT`, `EMT`, `WAIT` and `RESET` are not in the architecture. None has a use that another instruction does not already serve.

**`IOT` and `EMT` are `TRAP #n` under other names.** On the PDP-11 they were separate one-word opcodes because the frequently-used trap vectors deserved short encodings — `EMT` was RT-11's system-call entry, `IOT` some monitors'. `TRAP #n` and `TRAPL #n` here reach 256 vectors (two bytes for the first sixteen), so a dedicated opcode for two particular values of *n* buys nothing. The vectors themselves remain; only the aliases are absent.

**`WAIT` is subsumed by `WFE`.** `WAIT` sleeps until an interrupt; `WFE` sleeps until an interrupt *or* another core's `SEV`. When no other core sends `SEV`, `WFE` behaves exactly as `WAIT` did. The assembler accepts `WAIT` as an alias for `WFE` (section 4.13).

**`RESET` asserted the Unibus `INIT` line.** Resetting the bus is a device operation and belongs in a register of the root complex, not in the instruction set (manual 2.9.4) — section 16 says the architecture owes devices a memory type, an ordering instruction and atomics, and nothing else. A privileged instruction whose entire semantics are "poke the interconnect" is bus policy smuggled into the ISA.

**`BPT` stays, and for a specific reason.** It is also just a trap vector, but a debugger patches it over an existing instruction, so it must be *the shortest instruction the machine has* or it cannot overwrite a two-byte one. That is a structural requirement `TRAP #n` happens to satisfy too, but `BPT` makes it explicit and conventional.

Likewise `RTT` stays despite looking redundant against `RTI`: it sets the `T` bit *after* the return rather than before, which is what lets a debugger single-step out of its own trap handler instead of trapping immediately on the first instruction back. A subtle distinction with a real user.

And `SPL` stays despite `MTPS` writing the whole status word: it sets the priority field alone, leaving the condition codes untouched. A kernel raising priority around a critical section must not clobber flags, and with only `MTPS` that would be a read-modify-write.

**`PROBER` / `PROBEW Rd, Rs`** — test whether the address in `Rs` is readable (writable) in the current previous-mode, without faulting. `Rd` ← 0 or 1. Taken from VAX, where `PROBER`/`PROBEW` let a system service validate a user-supplied address before touching it. This replaces the `nofault` global hack that V6 and V7 `trap.c` need for the address-validation case, leaving `nofault` for genuine hardware probing.

#### 4.10.2 Atomics

The atomic group has, for each of compare-and-swap, swap, fetch-and-add, fetch-and-and/or/xor and fetch-and-min/max (signed and unsigned), a plain form and a `_DB` form that folds a full barrier in; `LL` and `SC` are the load-linked and store-conditional pair (manual 7.4 and 9.13). The barrier-fused variants are LoongArch's pragmatism (section 15): a lock acquire is one instruction rather than an atomic followed by a `FENCE`, which matters because that pair is in every critical section in the system. The `LL`/`SC` pair is kept for the operations `CAS` cannot express — multi-word updates and the ABA-sensitive cases. The atomics are defined on a monitor: a reservation that any initiator's write clears (manual 2.10, 7.4). The placement of the operands and the size field of `CAS` are open (J.9.3).

### 4.11 The decided additions to the base set

The mnemonics and the assembly language of the PDP-11 and the base specification are kept. The prefix-coded encoding added the following, each decided by the author (the ledger has the rows; manual 9.1.6 and the entries say what is still to be worked out in each):

- **the four fused pairs** `MOVCALL`, `POPRET`, `POPMRET`, `MOV2` (section 4.4);
- **the branch-free selects** `MASKEQZ` and `MASKNEZ` (from LoongArch), and the bit select `BSEL` (section 4.6.5); constant-time code needs a select that is not a branch, and the flag-reading conditional select is on hold (J.9.1);
- **`SET cc, Rd`** writes 1 or 0 from a condition, with no flag written: it removes about six bytes per site that would otherwise be compare, branch, two moves and a jump, about 0.4% of code on the measured corpus (section 14.4);
- **`MOVQL`**, the ten-byte 64-bit literal (section 4.1);
- **checked arithmetic** `ADDV`, `SUBV`, `MULV` and the fourteen `TRAPCC` words: trap on signed overflow, or when a condition holds, taking a check vector (the number of the vector and the register form of the checked arithmetic are open, J.9.4 and J.6.10);
- **deferred-fault loads (`.D`) and user-qualified moves (`.U`)** (manual 9.6.7): a load that can be hoisted above its guard because a fault the kernel finds invalid poisons the register instead of stopping the program, and a move that accesses its operand with user privilege so that no guard window is opened around a copy; decided, with the form of the poison bit and the semantics of the combination pending (J.9.12);
- **the AES and SHA words** of the secure core (section 4.6.5).

**`ABS`, `MIN`, `MINU`, `MAX` and `MAXU` are assembler aliases, not native instructions** (the author's decision of 2026-11-10, errata 98). They are the integer counterparts of `FABS`, `FMIN` and `FMAX`, and the fold into one rule: an assembler alias costs no instruction, and the measured gain of native words was under a tenth of a percent of code. Their meaning and flags stay as they were (`ABS` sets `N` and `Z` from the result and `V` when the operand is the most negative number, and leaves `C`; `MIN` and `MAX` set `N` and `Z`, clear `V` and leave `C`), and the alias must keep these flags or the decision that defines it must say that it changes them. **Their expansion is not decided:** the flag-driven conditional select is on hold and the only select defined is the branch-free `MASKEQZ`/`MASKNEZ`, which reads a register and no flag. A candidate over it (compare, `SET`, `MASKEQZ`, `MASKNEZ`, `BIS`) costs a scratch register and four or five instructions, and the flags would change. Which expansion is open (J.9.1). The grammars and tools still carry the five words as native mnemonics until the expansion is decided (see [`implementation-status.md`](implementation-status.md)).

### 4.12 Why a prefix code has no escape-parcel hazard

In the first encoding every instruction had a two-bit length field and six groups defined their own parcel-1 layout, which left one hazard that had to be ruled out by a written rule: *a sub-opcode that consumes more extension parcels than the length field declares* would leave the fetch length and the decoder's operand expectations silently disagreeing, and the machine would execute garbage with no fault raised. In the prefix code the hazard cannot be written: the prefix selects the leaf, the leaf has a fixed number of parcels (one, two or three), and the grammar generates the fetch length, the field positions and the assembler from the same record, so there is nothing for a rule to forbid (manual 9.2.1). The cost is a wider length lookup (section 3.1). Likewise, whether a field is a register or a mode is a property of the form, fixed per leaf by construction.

### 4.13 Assembler aliases

Some mnemonics assemble to another instruction rather than to one of their own. These are an assembler table, generated from the same machine-readable specification as the encoder, not architecture — but they are part of what "mnemonic compatibility" means in section 1, so they belong in the specification. The full list is the generated [aliases table](manual/dictionary/aliases.md); examples are `ROL rs, #n, rd` (to `RORI` with `64−n`), `MULU` (to `MUL`), `WAIT` (to `WFE`), `BHIS`/`BLO` (to `BCC`/`BCS`), the alternative floating-point spellings (`FADDD`, `FADDS` …) and the five aliases of errata 98. `IOT` and `EMT` are not aliases of `TRAP #n`; the instructions are absent (section 4.10.1).

**Two rules keep aliases from becoming a second, undocumented architecture.**

*One mnemonic assembles to one instruction.* `ROL rs, #n, rd` works because the complement is computed at assembly time and the result is a single `RORI`. `ROL` with a register count is **rejected**, with an error naming the two-instruction sequence (`NEG Rk` then `ROR`), rather than quietly emitting two instructions. Anyone counting cycles or sizing a branch displacement must be able to trust that one line of assembly is one instruction, and an assembler that silently expands macros under ordinary mnemonics destroys that. (The aliases for `ABS`, `MIN` and `MAX` of errata 98 will have to say plainly how they expand, since they cannot be one instruction: section 4.11.)

*The short forms are not mnemonics.* `MOVQ (R3), R1` assembles to the one-parcel form when the operands fit and to a longer form when they do not; there is no way to ask for either. A mnemonic still assembles to exactly one instruction, and the assembler chooses its length, as it does for branches. The disassembler prints the canonical mnemonic, so reassembling the text reproduces the same encoding.

*The disassembler never prints an alias.* `RORI rs, #57, rd` disassembles as `RORI rs, #57, rd`, not as `ROL rs, #7, rd`, so assembling and disassembling round-trips to the same encoding.

**There is one explicit exception to "one mnemonic, one instruction" in the operand, not the mnemonic: the literal-pool load `=K`.** `movq =0x123456789ABC, r1` is one instruction, a PC-relative `MOVQ` from a pooled 8-byte literal; the pool entry is the addition, and the `=` marks it plainly as assembler sugar, as in ARM's `ldr r0, =value`. A bare immediate too wide for the field is an error, never silently pooled ([`asm-syntax.md`](asm-syntax.md), manual appendix E).

### 4.14 Encoding conventions

**The numbers are written once, in `spec/pdp64/pdp64.hbnf` (the form and the prefix of every leaf) and `spec/pdp64-mnemonics.hbnf` (the vocabulary: groups, sub-opcodes, conditions, system registers); if this text and the grammar disagree the grammar is right.**

**Which field is which.** For the three-register groups the assembler writes the destination **last**: `op rs, rd`, `op ra, rb, rd`; the exception is `CMP`, register first (section 4.2). The block operations are the other exception: `MCPY rd, rs, rn` is *destination pointer, source pointer, count*. In the encoding the register fields are placed from bit 0 of the first parcel upward with the last register operand lowest. The dictionary's chart of each leaf shows every field.

**Byte and bit order.** Data is **little-endian**. Instruction parcels are 16-bit little-endian units in memory. The charts and the grammar number bits most significant first.

---

## 5. Addressing modes

The addressing mode is not a field: it is the leaf, whose form lists the shape of each operand. The assembly language has eight modes, and the assembler gives each operand the shortest leaf that holds it (manual 9.5.1):

| Syntax | Effect |
|---|---|
| `d(Rn)` | base plus displacement; `d=0` gives `(Rn)` |
| `d(Rn)(Rx*s)` | scaled index, `s ∈ {1,2,4,8}` |
| `d(PC)` | PC-relative; the base is the first parcel of the instruction, and `d` counts bytes |
| `d(DP)` | direct page, loads only |
| `#imm` | immediate, sign-extended |
| `@abs` | absolute, sign-extended |
| `(Rn)+d` | post-increment by a stride `d` (0: the operand size) |
| `-(Rn)` or `(Rn)-d` | pre-decrement by a stride (0: the operand size) |

The displacement widths that go with each length are in manual 9.5. (A store through `d(DP)` and the displacement of the shortest scaled-index form are open: J.9.5.)

**Pre-decrement syntax.** `-(Rn)` pre-decrements by the operand size and `(Rn)-d` by an explicit stride, the mirror of `(Rn)+d`. **`-d(Rn)` is always base + displacement**, never a pre-decrement, because it is how a negative base displacement is written.

### 5.1 Strided autoincrement

The displacement field of the autoincrement modes has no other use, so it becomes the step. The assembler writes `(Rn)+` and `-(Rn)` for the operand-size default and `(Rn)+8` or `(Rn)-16` for an explicit stride.

This costs nothing. The undo information (section 7.2) is a delta, and a variable delta is the same width as a fixed one — `MMR1` on the PDP-11 recorded an *amount* for precisely this reason. What it buys is strided array traversal in one instruction and a decrementing loop over an array of structures without a separate `ADD`.

### 5.2 What was removed

**Every deferred mode**: `@(Rn)+`, `@-(Rn)`, `@X(Rn)`. On the PDP-11 these were not separate modes at all — the low bit of the 3-bit mode field *was* the deferred bit, so every mode came in a direct and an indirect flavour for free. It is also the single most expensive thing in the encoding, because a deferred mode issues a **second memory reference inside operand evaluation**. That is precisely the machinery that makes VAX costly: a fault can occur mid-specifier, after a register has already been side-effected, at an address that itself came from a load that may also have faulted.

Removing them means operand evaluation performs at most one memory access, address generation is a single adder pass rather than load-then-add, and the undo buffer is one entry.

The form that mattered, `@#addr`, returns properly as the absolute mode. The dispatch-table idiom that `@(Rn)+` served is covered better by `JTAG` (section 6.3). Section 14.2 covers the rest.

**One case matters.** Indirect control transfer through a memory location — the PLT stub of every dynamically linked program and the vtable dispatch of every object system — takes two instructions and a scratch register without a deferred form. `JMPI` and `CALLI` (section 4.8.1) are that one case, admitted because no register is written before the deferred load, so the restart problem that motivated this whole removal is structurally absent. The general modes stay gone.

**`(Rn)+` and `-(Rn)` cost a parcel.** All memory addressing with a stride is two parcels at least, where the PDP-11 form is one. `PUSH`, `POP`, `PUSHM` and `POPM` at one parcel cover where those modes are used.

---

## 6. Width, modes, and pointer representation

### 6.1 The three width rules

1. **Registers are 64 bits. There is no other profile.** No prefix, no long mode, no operand-size override. x86's `REX` is a decode tax paid on every instruction of a 64-bit program to retain a 16-bit ancestor nobody runs.
2. **Sizes appear on loads, stores and conversions only** (section 4.1), with sign or zero extension in the opcode. The ALU has one width.
3. **Addresses are canonical** — see section 6.1.1.

#### 6.1.1 What "canonical" means: 39, 48 or 57 bits, and a physical address of 40 to 64

The page table has three, four or five levels of nine bits over 4 KB pages (manual 6.6; errata 96): 9 + 9 + 9 + 12 = 39 bits of virtual address with three levels, 48 with four and 57 with five. Nine bits per level is itself forced — 2⁹ entries × 8 bytes per entry is exactly one 4 KB page, so every table is one page and the walker never needs a table that straddles. The author's rule is that three, four and five levels are all fine, **as long as the number is discoverable at run time** ("good thing we already had dmw in the design"): how software discovers the number of levels and the implemented physical width is open (J.6.1).

**Why 39 bits is the floor, and why 40 is not a geometry.** The extra bit has nowhere to come from at three levels:

| Geometry | VA bits | Cost of getting there |
|---|---|---|
| 4 KB pages, 3 levels | **39** | the minimum |
| 4 KB pages, 4 levels | 48 | a fourth memory reference on every TLB miss, and another level of tables to allocate (allowed) |
| 4 KB pages, 5 levels | 57 | one more again (allowed) |
| 4 KB pages, 3 levels + a 2-entry top | 40 | an entire extra walk level to buy one bit — the worst trade on the table |
| 8 KB pages, 3 levels | 43 | 8 KB pages waste memory on small objects; Alpha made this choice |
| 16 KB pages, 3 levels | 47 | worse internal fragmentation again; ARM offers it |

**The physical address is 40 to 64 bits** (errata 102; an implementation chooses its width in that range; no bit of the physical address selects device space: errata 97). With a 40-bit physical address and 39 bits of virtual address, the kernel cannot map all of a fully-populated 1 TB physical space into one address space at once; it maps a window instead, which is what every kernel does anyway. x86-64 and AArch64 both ship configurations where PA exceeds VA for the same reason. The page-table entry for a physical address wider than 40 bits is open (J.6.2).

**Canonical** means every virtual-address bit above the top implemented bit equals that bit: the 64-bit address must be the sign extension of a 39-, 48- or 57-bit value. Two regions are usable (the lower half and the upper half), and an address between them aborts with `ECAUSE = NONCANON`; the translation is split by the top bit, the lower half through `PTBR` and the upper half through `KTBR` (section 8.2). This is the same arrangement as AArch64 in its three-level 4 KB configuration — what Linux calls `VA_BITS=39` — and the same rule as x86-64 at 48 bits.

Two benefits, one immediate and one deferred. Immediately, every address adder, TLB tag and comparator carries 39 bits instead of 64. Deferred: software cannot stash tags in the high bits, because an address with anything up there faults rather than working by accident, so the address space can be widened later; and it *has* been, by the allowance of four and five levels, without breaking a program. (This is the migration x86-64 cannot make cleanly, because its software stashed things in the high bits. Pointer colouring and tags in the pointer spend bits that this rule refuses to software, which is why they are open: manual appendix J.A.1.)

### 6.2 Low pointer bits are reserved to software

The natural-alignment rule of section 7.4 means any object containing a quad field — every cons cell, every boxed float, every vector header — is allocated on an 8-byte boundary. Bits 2..0 of a pointer to such an object are therefore always zero, and available.

> **Contract.** Bits 2..0 of a quad-aligned object pointer are permanently reserved to software. The architecture never assigns meaning to them, and no later definition may claim one.

This is the Lisp machine lowtag, obtained from allocator discipline rather than from tag hardware. Sixteen-byte allocation, which most collectors want anyway, yields a fourth bit.

Note the source. Two-byte *instruction* alignment (section 3.3) frees bit 0 on code pointers only; nothing in the ISA constrains where a `char*` may point. The three bits above come from the data-alignment requirement, not from the instruction encoding.

**The displacement field absorbs the tag.** Untagging costs no instruction and no cycle, because the offset the instruction was going to carry anyway is biased:

```
        ; R1 holds a cons pointer, lowtag = 1
        MOVQ    -1(R1), R2      ; car
        MOVQ    7(R1), R3       ; cdr
```

Both are two parcels. Different tags are different constants folded into the displacement field. `JMP -k(Rn)` works identically for tagged function pointers, since `JMP` targets the effective address.

**The alignment abort is the tag check.** Dereferencing a tagged pointer without biasing the displacement produces `ECAUSE = ALIGN` rather than a value read one to seven bytes off. This is tag checking on every quad access at no cost: no comparator, no tag bits in the datapath or the TLB, and no hardware that knows what a tag is.

Hardware tag checking on dereference — the Lisp machine feature — is not provided. It costs a comparator, tag bits in the datapath and a trap path, to buy what the above already gives approximately for free. Nor is there a load form that ignores the low bits: that would delete the alignment fault, which *is* the tag check, and convert a corrupted tag from a trap into silent corruption.

**Why bit 0 is safe here and is not on ARM.** ARM has 2-byte instruction alignment too, and spent bit 0 on Thumb interworking: `BX` with bit 0 set switches instruction sets. Software can never reclaim it. That mistake is foreclosed here by the founding rule — compatibility is conversion instructions, never mode bits — which rules out an interworking bit before it can be proposed.

The asymmetry with the canonical-address rule is deliberate. Low bits are earned by allocator discipline and granted to software permanently. High bits are architecturally refused, so the address space can be widened later without breaking every runtime that got greedy.

### 6.3 Instructions that make tagged pointers cheap

Section 6.2 makes tagged pointers *possible* at no cost. Three additions make them *cheap*, which is a different claim. Taking a plausible lowtag assignment — fixnum 0, cons 1, symbol 2, closure 3, string 4, vector 5, flonum 6, other 7 — here is what a runtime does all day:

| Operation | Without | With |
|---|---|---|
| extract tag | `AND #7, Rn` → `Rt` | same |
| test one type | `AND #7`, `CMP Rt, #tag`, `BEQ` — 3 instructions | **`BTAG Rn, #1, cons_case`** — 1 instruction |
| dispatch on type | bounds check, scale, load, jump — 4 instructions | **`JTAG typetab(Rb)(Rn*8)`** (the scale is ignored, `Rn` is the tagged register) — 1 instruction |
| `car` | bias the displacement | `MOVQ -1(R1), R2` — already free |
| fixnum arithmetic | untag, add, retag | `ADD` — already free, tag 0 |
| fixnum overflow | compare against bounds | `BVS` — already free |
| type error on deref | explicit check | `ECAUSE = ALIGN` — already free |

**`BTAG`/`BNTAG`** is a 3-bit comparison on the low bits of a register plus a branch — perhaps 20 LUTs, since the comparator is three XORs and an AND, and the branch path already exists. It collapses the commonest three-instruction sequence in a dynamically typed runtime to one.

**`JTAG`** is the eight-way dispatch at the top of `eval`, at the top of the garbage collector's scan loop, and at the top of every `print`, `equal` and `hash`. It is also what the PDP-11's `@(Rn)+` was really used for, done properly: one instruction, no pointer to maintain, bounds-safe because three bits cannot index outside eight entries.

Setting **fixnum to tag 0** is what makes the rest fall out: tagged fixnums add and subtract directly with no untagging, `V` reports overflow, and `BTAG Rn, #0` is the fixnum test. This is SBCL's arrangement.

What is deliberately *not* provided: a fused allocation instruction, and a store with a built-in GC write barrier. Both would bake a particular allocator or collector design into the architecture, and both are three or four ordinary instructions. The line is that the architecture supports tagging without knowing what the tags mean.

---

## 7. Faults and restart

This section is why the rest of the design looks the way it does. The kernel's view of it is chapter 6 of the manual (sections on faults and restart).

### 7.1 Four categories

| Category | Instruction | PC on entry | Restartable |
|---|---|---|---|
| **Trap** | completes | next instruction | n/a |
| **Abort** | annulled, no architectural effect | the faulting instruction | yes, by `RTI` |
| **Progress** | partially complete, progress in registers | the faulting instruction | yes, by `RTI` — section 7.5 |
| **Machine check** | indeterminate | best effort in `EPC` | no |

Traps: `TRAP #n`, `TRAPL #n`, `BPT`, the T-bit, `TRAPCC` and the checked-arithmetic words where they are defined as traps (manual 6.13.8). Floating-point exceptions are not among them: they set a flag in `FPSR` and never trap (section 4.9.1).

Aborts: page not present, protection violation, non-canonical address, misalignment, reserved instruction, privileged instruction outside kernel mode, divide by zero, landing-pad violation.

Progress: the block operations of section 4.7, and nothing else.

Machine checks: a posted write that times out, uncorrectable ECC, parity. These are the descendants of the PDP-11's vector 004 bus error and, like it, are not restartable. The `nofault` idiom from V6/V7 `trap.c` — set the global, do the probe, longjmp out of the handler instead of panicking — remains the correct kernel-side pattern for hardware probing, though `PROBER`/`PROBEW` covers the address-validation case properly.

**Loads and instruction fetches never produce machine checks for nonexistent memory.** A read timeout on the bus is reported as an abort with `ECAUSE = BUSFAULT`, precisely, at the faulting instruction (manual 6.4.3 and 2.9). On the PDP-11 a read timeout was an unrestartable bus error and therefore fatal to the process. Only posted writes remain imprecise, and a `FENCE` before a probe makes even those precise at a known point.

**Deferred-fault loads** (`.D`, section 4.11) move the point of the fault: a faulting deferred load poisons its destination register and the fault is taken at the first instruction that writes the flags from a poisoned source; the kernel decides it (manual 6.4.4). The restart rule is unchanged: the fault is precise at that later instruction.

### 7.2 The undo journal

The PDP-11 recorded autoincrement and autodecrement side effects in `MMR1` — two entries, each a 5-bit signed amount and a 3-bit register number — captured `MMR2` at every instruction fetch, and left the *undo* to software: read the journal, reverse the deltas, restart at `MMR2`. A good trade in 1972. A shift register and a latch, against VAX's per-instruction saved microstate and the `PSL<FPD>` machinery.

Two entries sufficed because a PDP-11 instruction has at most two specifiers, each performing at most one register side effect. The journal was **bounded by the encoding**. VAX had no such bound, which is exactly why it needed resumable microstate instead.

The one-memory-operand rule makes the bound tighter. Only one operand may be a memory mode, so an ordinary instruction performs **at most one** register side effect — even with the strided modes, where the delta is larger but there is still only one. One entry is small enough that it should not be exposed to software at all:

> **Rule.** The register update from an autoincrement or autodecrement mode is buffered and committed at instruction retirement. An abort discards the buffer. Software observes a precise exception at an instruction with no partial effects, and the handler repairs the mapping and executes `RTI`.

There is no `MMR1`, no undo protocol and no journal overflow. A fused instruction is restarted whole (manual 9.15.2).

### 7.3 The fault matrix

Every faulting reference an ordinary instruction can make, exhaustively:

| # | Reference | Max faults | Notes |
|---|---|---|---|
| 1 | instruction fetch | 2 | at most 3 parcels = 6 bytes at 2-byte alignment, spanning at most 2 pages |
| 2 | operand read | 2 | at most 8 bytes; 2 pages only via the explicit unaligned forms |
| 3 | operand write | 0 | by construction |
| 4 | branch target load | 2 | the deferred-transfer group only (section 4.8.1); no register is written before it, so a fault here is a clean abort |

Row 3 is zero because for any read-modify-write — the ALU-to-memory words and the single-operand operations with a memory destination — **write permission is checked during the read access**. If the page is absent or read-only, the abort happens before any state changes. If the read succeeds, the write cannot fault.

That is the entire restart problem for ordinary instructions, closed, on one page. The block operations are the exception and have their own rule. (`MOVQL` is ten bytes at parcel alignment and also spans at most two pages.)

### 7.4 Data alignment

Natural alignment is **required** for word, long and quad *data* accesses. Misalignment aborts with `ECAUSE = ALIGN`.

This removes the unaligned path entirely: no rotator on the load return, no dual-access sequencer, no cross-line splice. For cases that need it — packed on-disk structures, network headers, the kind of thing `filsys` deals with constantly — the explicit `MOVU*` forms perform the two accesses in a defined order and restart by the same rules.

The capability is an instruction, not a mode bit that changes what every other instruction means.

Two adjacent points, both load-bearing elsewhere:

- This is **data** alignment only. Instructions are parcel-aligned and unconstrained beyond that (section 3.3). The two rules are independent and neither implies the other.
- The quad-alignment requirement is what makes section 6.2 work, and the `ALIGN` abort is the specified tag-mismatch signal. **This rule may not be relaxed to permit unaligned quad accesses** (section 1.1). Doing so would silently break every tagged runtime built on the architecture, which is a far larger cost than the rotator and dual-access sequencer it would save.

Byte accesses are unconstrained, so the block operations have no alignment requirement at all. The same rule makes every aligned access atomic within its own size (manual 7.5.3, 7.5.6).

### 7.5 Progress-restartable instructions

The block group of section 4.7 cannot satisfy section 7.3. It makes an unbounded number of memory references and updates three registers. Its restart rule instead:

> **Rule.** A block instruction is interruptible. At every point at which an exception may be taken, `Rd`, `Rs`/`Rv` and `Rn` hold state consistent with byte-at-a-time progress through the operation, and all remaining work is described by those registers. `PC` addresses the block instruction itself. An abort or interrupt is taken with that state committed; `RTI` resumes the operation with no special handling, because re-executing the instruction with the updated registers *is* resumption.

What this costs, written down as section 1.1(b) requires:

- **The fault count is unbounded.** An `MCPY` of 1 MB may take 256 page faults. Each one is individually precise and individually cheap; there is no accumulation.
- **Three registers are written**, not one, so the buffer-and-commit arrangement of section 7.2 does not apply. The block group commits directly and must commit all three atomically with respect to interruption.
- **The source registers are destroyed.** A caller that needs the original pointers must keep copies. This is the price of having no hidden state, and it is a one-line note in the ABI rather than a hardware cost.
- **Worst-case latency is not bounded by the instruction.** This is the realtime concern, and it is why the rule says *interruptible* rather than *atomic*: the maximum interrupt latency is the implementation's block size, not the operation's length. An implementation claiming a latency bound must state its block granularity (J.9.7).

In exchange: `memcpy`, `memmove`, `memset`, `bzero`, `memcmp`, `memchr` and `strchr` are each one instruction, the implementation may run them at full memory bandwidth, and none of them needs a loop in software or a hidden microstate register in hardware.

---

## 8. Memory management

The kernel's account is chapter 6 of the manual (sections 6.6 to 6.10); this section keeps the reasons.

### 8.1 What survives from the 8722

The pdp64 takes two ideas from the C128 MMU: **map sets**, four shadow copies of the whole relocation register file selected by one store to `MAPSEL`, giving a constant-time context switch; and **`MMCOM`**, an explicit common region immune to remapping in every map set and every mode, making the map switch safe by construction rather than by care.

Neither carries over literally, since four shadow copies of a page table are impractical. Both carry over functionally:

| C128 MMU | pdp64 | Property preserved |
|---|---|---|
| four map sets, `MAPSEL` | **ASID**, 16 bits, `MTASID` | constant-time context switch: one store, zero flushes |
| `MMCOM` common region | **`G` bit** per page table entry | kernel text, vectors and trap stubs immune to address-space change, by architecture |

The realtime property that motivated map sets — a bounded, constant-cost context switch, belonging on the list with priority inheritance and preemption points — is preserved. The `G` bit does what `MMCOM` did: entries so marked ignore the ASID and survive every switch, so the code performing the switch cannot unmap itself.

### 8.2 Translation

Three, four or five levels, 4 KB pages (section 6.1.1). Leaves at the upper levels map 2 MB and 1 GB (and, where the levels exist, 512 GB and 256 TB) to preserve TLB reach. A hardware table walker; the accessed and dirty bits are managed by software (an access with `A` clear or a write with `D` clear faults and the kernel sets the bit; the walker never writes a page table: manual 6.8.1). Translation is off at reset (manual 6.8.2).

A software-refilled TLB (MIPS R2000, Alpha PALcode) removes the walker state machine entirely and saves perhaps three to five thousand transistors. With a multi-level table the miss handler runs often enough and long enough that the walker pays for itself.

**Split translation** (manual 6.9.1): the top bit of the virtual address selects the table, the lower half through `PTBR` (per address space) and the upper half through `KTBR` (the kernel's, one for the whole system); in user mode the upper half is never walked, so no kernel translation is present for a speculative access to find. The register number of `KTBR` and the layout of the root table are open (J.6.4).

Page table entry attributes (manual 6.7):

| Field | Meaning |
|---|---|
| `V` | valid |
| `R` `W` `X` | read, write, execute permission |
| `U` | user-accessible |
| `G` | global — ignores `ASID` (section 8.1) |
| `A` `D` | accessed, dirty |
| **`MT`** | **memory type** (two bits): normal cached, normal uncached, device strongly ordered, device weakly ordered |

The memory-type field exists because a framebuffer written by the CPU and scanned out by a raster engine, or filled by a blitter and read back by the CPU, needs either an uncached mapping or explicit flushes — and uncached-by-attribute is the right answer, because it is per-page rather than per-access and needs no cooperation from the code doing the writing. The four values are ARM's memory types and LoongArch's `DMW` cache attributes, reduced to the set that is distinguishable on a machine of this size. (A write-combining type for the framebuffer is open: J.3.10.) The physical page number sits in place in the entry; where the bits go for a physical address wider than 40 is open (J.6.2).

### 8.3 Direct mapping windows

Two windows, `DMW0` and `DMW1`, are system registers (manual 6.9.2). The intended design is LoongArch's `CSR.DMWn` — a window translated as `PA = VA − VirtualBase + PhysicalBase` with no page table reference, no TLB entry consumed and no walk, kernel-only — which is the better-designed descendant of MIPS's `KSEG0`. **Today the registers are stored and have no defined effect: the format of the windows is deferred until a kernel needs a window (errata 44).** Three reasons the windows belong in the design:

1. **The kernel stops taking TLB misses on its own text and data.** For a machine whose realtime story rests on bounded worst-case paths, removing the page walker from the kernel's own execution is worth more than its cost, which is one comparator pair and one adder.
2. **Physical memory is reachable without mapping it**, which is what a driver writing a DMA descriptor, a debugger reading a page frame, and a bootstrap before the page tables exist all need. (At reset translation is off and every address is physical; the windows are for a running kernel.)
3. **The wider tables of four and five levels** make a window the cheap way to address physical memory from the kernel; the author's remark was that it was a good thing the windows were already in the design.

`G`-bit entries and `DMW` overlap in purpose but not in kind: `G` keeps a *mapped* page present across address-space changes, `DMW` removes a region from mapping altogether. The kernel wants both — `DMW` for its static text and physical access, `G` for the vectors and trap stubs that must remain at fixed virtual addresses with ordinary permissions.

---

## 9. Rationale for the contested decisions

### 9.1 Thirty-two registers, not sixteen or eight

The 6502 has three architectural registers and compensates with zero page. Correct in 1975, when a register bit cost roughly a logic gate and 256 bytes of static RAM was cheaper than eight more registers.

Not correct now. A 32 × 64-bit file with two read ports and one write port is a few thousand to a few tens of thousands of transistors — among the cheapest structures on the die, and far cheaper than the spill traffic fewer registers would generate. The register file was never where the transistors went. Control was.

**Why thirty-two and not sixteen.** The first encoding had sixteen registers and a four-bit register field. The prefix-coded encoding has the bits for five-bit fields, and the author chose the 32-register encoding **for performance** (errata 94), after the three encodings were built and measured against each other on the same corpus and the same compiler (`encoding-work/`, above all `integration.md` section 4): on the 841-file corpus the compiler's output for the pdp64 is 11.04% smaller than for the first encoding, and on six large programs it executes 24.21% fewer instructions (manual 9.2.13 and appendix F). The sixteen-register prefix-coded variant was measured too and superseded. A register hardwired to zero was weighed and declined (section 15.2). The architecture is called the pdp64; the history of how the 32-register encoding was chosen is history, kept in the files named above, appendix G of the manual and section 1.8 of chapter 1.

What does transfer from the 6502 is the direct page as a **density** mechanism, which is why the `d(DP)` mode exists.

### 9.2 One memory operand

Section 3.5 and section 7.3. The load-bearing decision of the whole design, and the block operations are its one admitted exception.

### 9.3 The PC is not a register, and `R7` is not a read-only view of it

`R7`-as-`PC` is the PDP-11's most distinctive feature, and giving it up is the most painful choice here. Immediate, PC-relative and absolute addressing all fall out of ordinary modes applied to an ordinary register, with no dedicated encoding at all.

**The cost of a writable PC in the register file:**

- The general write port can target the PC, so **every register write is a potential branch**. Nothing may be committed to the register file before it is known that the instruction did not redirect control, which pulls branch resolution to writeback and puts the next-PC mux downstream of the whole datapath.
- Hazard logic must compare every destination against `R7` on every instruction.
- Every specifier decode must special-case `R7` to route the PC into the address adder rather than reading the file.
- Exception reporting must distinguish the PC as an operand from the PC as the instruction pointer.

Tolerable on a non-pipelined machine, a persistent tax beyond. ARM32 carried it; AArch64 dropped it.

**The read-only alternative (rejected).** If `R7` merely *read* as the PC and writes to it were reserved, almost all of that cost disappears: reading needs only a mux on the register read path, since the PC is already a flop in the fetch unit. No write hazard, no branch-on-write. It is cheap.

It is still the wrong trade, for a reason that has nothing to do with cost. **Reading the PC forces a definitional commitment about *which* PC.** ARM32 answered "the address of this instruction plus eight," because the original three-stage pipeline had already advanced the PC twice by the time the register file was read. That answer is permanent. It leaks a 1985 pipeline depth into the architecture forever, every implementation since has had to reproduce it, and ARM's own documentation lists it among the architecture's warts. It is the same error class as branch delay slots, which section 11 rejects for the same reason: an implementation detail promoted to an architectural promise.

There is no answer that avoids the commitment. "Address of this instruction" means the fetch unit must retain it past decode. "Address of the next instruction" means the value depends on the instruction's own length, so `MOVQ R7, R0` and `MOVQ R7, -8(SP)` yield different numbers. Either way a number is now specified forever.

And the capability is already present without the commitment:

```
        LEA     0(PC), R0       ; one instruction
```

The PC-relative displacement is defined relative to a stated point — the address of the first parcel of the instruction (section 4.1) — so `LEA 0(PC), R0` has one meaning (the address of the `LEA` itself) and the architecture never has to say what "reading R7" would produce. The six-byte form forms any address within ±2 GiB of itself PC-relatively, which is a strictly larger capability than a readable PC register offers.

So *(D)*: `R7` is an ordinary general register and is not a view of the program counter (the author's decision of 2026-11-10, errata 100); the PC is reached through the PC-relative mode and `LEA`, and the **syntax** is preserved — `MOV #5, R0`, `MOV foo(PC), R0` and `MOV @#addr, R0` all assemble. What is lost is encoding uniformity; what is gained is a clean register file, a clean hazard story, one more general register, and no number specified in perpetuity. The requirement is mnemonic compatibility, not binary compatibility.

**Everyone modern agrees.** AArch64: `PC` is not a GPR, read via `ADR`/`ADRP`. LoongArch64: `PC` is not a GPR, read via `PCADDI`, `PCADDU12I`, `PCADDU18I` and `PCALAU12I`. RISC-V: not a GPR, read via `AUIPC`. The convergence is independent teams finding the same hazard.

LoongArch needs *four* such instructions because its fixed 32-bit encoding carries only twenty bits of immediate, so a full address takes a pair. The variable-length encoding does it in one instruction within ±2 GiB. This is the clearest single case where variable-length beats fixed-width.

### 9.4 The first parcel says what and how long

Four consequences, all cheap:

- **Length is a function of the first parcel alone** — a lookup on the prefix, with no case analysis anywhere in hardware or in tooling (section 3.1).
- The register fields of every leaf are at fixed places counted from bit 0 of the first parcel, so they go straight to the register file address inputs.
- Displacement scales with length automatically, giving branches four reaches from one family with no long-branch instruction and no trampolines.
- Any instruction fits one 64-bit word, in the decode register and in every tool that has to carry one. Instructions in memory are 2, 4 or 6 bytes (ten for the literal move).

### 9.5 Decode as wires, not ROM

The 6502's real lesson is not the small register file. It is that decode is a PLA and a timing generator with no microcode ROM anywhere, because in 1975 a ROM bit was expensive relative to random logic.

The corresponding discipline: **lay out the encoding so the bits are the control signals.** In the prefix code that means: the prefix is one lookup and nothing else; the sub-opcode of a leaf is binary-aligned, so its low bits go straight to the function select; register fields are at fixed places, so they go straight to the register-file address inputs; the form says what the address-generation sequencer does. Every bit wired instead of decoded is microcode that never gets built. Together with one memory operand and no deferred modes, this is where the transistor budget comes from — not from having fewer instructions, but from having a decode that is mostly wire.

The honest cost is the width of the prefix lookup (section 3.1); the first encoding's decode was more nearly pure wire, and it was measured and superseded because the density and instruction-count gains of the prefix code were larger than the decode cost the timing model charges.

### 9.6 Why the parcel limit is three, and what `MOVQL` is

The parcel is 16 bits, and the leaf has one, two or three of them. The measurement that settled how long an instruction needs to be: in the first iteration's compiled code only 49 of 373,635 instructions (0.013%) needed a form longer than six bytes, and a 32-bit immediate and ±2 GiB addressing cover nearly every other constant. A 64-bit literal is the one case that wants more: `MOVQ =K, Rd` from a literal pool is what compilers already emit for `binary64` constants, and `MOVQL` (ten bytes, errata 85) takes the literal in the instruction for the cases where a pool load would be the worse choice. The literal is not counted against the three-parcel rule (manual 9.2.3). **Open:** whether this stays the only exception.

### 9.7 No transcendentals, and the FMA gap

**The ALU does not implement `sin`, `cos`, `tan`, `atan2`, `exp`, `log` or `pow`, and should not.**

#### 9.7.1 Which architectures had them, and how accurate they were

Two mainstream architectures ever put a transcendental function set in hardware, both in the early 1980s, and **neither was accurate**:

| Architecture | Set | Fate |
|---|---|---|
| **x87** (8087, 1980 →) | `FSIN`, `FCOS`, `FSINCOS`, `FPTAN`, `FPATAN`, `F2XM1`, `FYL2X`, `FYL2XP1` | still present for binary compatibility; avoided by every libm including Intel's own |
| **Motorola 68881/68882** (1984) | a *larger* set — `FSIN`, `FCOS`, `FTAN`, `FASIN`, `FACOS`, `FATAN`, `FSINH`…`FTANH`, `FETOX`, `FLOGN`, `FLOG2`, `FLOG10`, `FTENTOX`, `FTWOTOX` | **removed in the 68040**, which traps them to software |

The 68040 is the clearest verdict available: Motorola built the most complete transcendental set any microprocessor ever had, then deleted it one generation later and spent the area elsewhere.

**Why none of them is accurate.** `FSIN` accepts arguments up to 2⁶³ but reduces them modulo π using an internal **66-bit** value of π. Intel's own support staff give this as the explanation for `FSIN` disagreeing with a correct implementation, and direct callers to compiler libm routines that do full Payne–Hanek reduction instead. The failure is structural, not a bug:

- To reduce a double with a large exponent you need π to roughly 1100 bits. Sixty-six is not close, and the error grows with the argument.
- Near multiples of π/2 the reduction cancels catastrophically, so the few arguments where sine is most sensitive are the ones computed worst.
- No hardware is going to store a thousand bits of π for one instruction.

**And correct rounding is not generally achievable in fixed time.** The Table Maker's Dilemma: deciding how to round sin(x) to the nearest double requires computing enough extra bits to break the tie, and the number required is not bounded a priori. Proving tight bounds took the crlibm and CORE-MATH projects decades, function by function. Hardware cannot run an unbounded loop, which is why IEEE-754 lists these in clause 9 as *recommended* operations rather than required ones, and why conformance pressure never arrived.

**Software also won on speed**, which is what settled it. A microcoded `FSIN` was fifty to several hundred cycles and could not be pipelined. A polynomial chain of FMAs is twenty to forty cycles and pipelines perfectly on anything with more than one FP unit. Hardware lost to software on its own terms.

#### 9.7.2 What a modern architecture provides instead

The consensus that emerged is three tiers, and it is worth naming because it is the reason section 4.9 looks the way it does:

1. **The CPU provides the primitives**: FMA, correctly-rounded `FSQRT`, classification, round-to-integral, min/max, and (on most architectures, though not here — see section 9.9) low-precision reciprocal and rsqrt *estimates* as Newton–Raphson seeds. Itanium was the purest expression — no divide and no sqrt instruction at all, only `frcpa` and `frsqrta`, with software doing the iteration, and its libm was among the fastest and most accurate of its era.
2. **A GPU or accelerator provides fast approximate versions** at a few ulp, because graphics and neural-network activations do not need more. This is where the LB64 design (proposed) puts `exp` and `rsqrt`, as a consequence of this rule rather than an exception to it.
3. **Software provides correctly-rounded versions** when they are needed.

**The one modern exception is instructive.** ARM's SVE added `FTMAD`, `FTSMUL` and `FTSSEL` — trigonometric *helper* instructions. `FTMAD` multiplies by an absolute value and adds a Taylor coefficient selected by a 3-bit immediate and the operand's sign bit, with sine and cosine series terms built into the instruction, and its coefficients are documented as accurate for −π/4 < x ≤ π/4. So ARM put the **polynomial** in hardware and left **argument reduction** to software — precisely inverting what x87 attempted. If the pdp64 ever adds trigonometric support, that is the shape it should take.

**One historical idea worth recording.** VAX had `POLY`/`POLYD`/`POLYG`/`POLYH`: evaluate a polynomial by Horner's method from a coefficient table, in one instruction, plus `EMOD` for argument reduction. DEC concluded the right hardware primitive was polynomial *evaluation* rather than the functions themselves — one step more general than FMA, and the best answer anyone gave before FMA existed. With FMA present, `POLY` is a three-instruction loop, so it is not worth an opcode; but it would be a natural block-group member if measurement ever said otherwise.

#### 9.7.3 What libm needs from hardware

What libm wants from hardware is a short list, and FMA is the most important item on it:

| Need | Why | Status |
|---|---|---|
| **FMA** | Horner's method with a fused multiply-add is both faster and *more accurate* than separate operations, because the intermediate product is not rounded. Every polynomial kernel in every libm is a chain of FMAs. | present (section 4.9) |
| correctly-rounded `FSQRT` | required by IEEE-754; cannot be synthesized accurately | present |
| `FCLASS` | every libm function opens with a dispatch on NaN / infinity / zero / subnormal | present |
| `FRINT`, `FMIN`, `FMAX`, `FCOPYSIGN` | argument reduction and the special cases | present |
| reciprocal and rsqrt *estimates* | Newton–Raphson seeds; explicitly not correctly rounded | **not provided** (section 9.9) |

The ALU does not support the standard trig operations, deliberately. The one floating-point instruction that matters most for them is **FMA**: every numerical kernel and every libm function is built from it, and there is no good software substitute, so a floating-point set without it has its worst gap there.

### 9.8 Width and mode in the instruction, not in a register

The default (section 1) is that anything which changes what an instruction *means* belongs in the instruction, as visible state and not hidden state. Operand size is in the opcode (section 4.1), floating-point precision is in the opcode, rounding mode is in the opcode (section 4.9). Nothing is in a control register.

**Operand size in the opcode is not unusual.** ARM has `LDRB`/`LDRH`/`LDR`, RISC-V has `LB`/`LH`/`LW`/`LD`, MIPS the same; x86 uses prefixes, which is encoding rather than state. On that axis the pdp64 is conventional.

**Where modern architectures do use hidden state, and why:**

| Hidden state | Where | Why they did it |
|---|---|---|
| **FP rounding mode** — `FPCR`, `FCSR`, `MXCSR`, and the PDP-11's own `FPS` | ARM, RISC-V, x86, LoongArch, POWER — **universal** | IEEE-754 and C's `fesetround` define rounding as a *dynamic* property of the environment. Hardware followed the language standard. Encoding five modes on every FP opcode also costs bits a fixed-width encoding does not have |
| **FP precision** — x87's control-word precision field, the PDP-11's `FPS.FD` | x87, FP11 | same bit pressure, one generation earlier |
| **Vector element width and length** — `vtype`, `vl` | **RISC-V Vector** | the strongest case of the four. With 32 fixed bits, encoding element width × length × masking × operation would exhaust the opcode space. And `vl` buys *vector-length-agnostic binaries*: one executable runs correctly on a 128-bit and a 512-bit implementation. You cannot get that property from an opcode at all |
| **Instruction set mode** — ARM32's `T` bit | ARM32 | a transitional compatibility mechanism; section 6.2 shows what it permanently cost |

Most architectures do not use hidden state for operand width, but **everyone else uses it for floating-point rounding, and RISC-V Vector uses it for element width, and both have real reasons.**

**Why the pdp64 does not, in three parts.**

*The pdp64 has encoding room where they do not.* Every argument above reduces to bit pressure under a fixed-width encoding. The variable-length prefix-coded encoding means a rounding-mode variant costs a sub-opcode in a floating-point leaf, and sub-opcodes are the cheapest resource in the machine. The architectures that chose mode registers were not careless; they were out of bits.

*Hidden state is invisible coupling, and the failure mode is remote.* A mode register is state that must be saved and restored at every context switch, and a library that sets it and fails to restore it changes the behaviour of unrelated code elsewhere in the process. The canonical case is a DLL setting x87 precision to 24 bits and silently altering every floating-point result in the program — real, famous, and extremely hard to diagnose, because the symptom appears in code that is correct. An opcode cannot do that.

*It destroys interleaving.* With the format in the opcode, FP11-compatible code and IEEE code coexist in one process with nothing to switch. The same argument covers rounding. A function needing round-toward-zero and a function needing round-to-nearest can be inlined into each other, interleaved by a scheduler, or called in a loop, with no save-restore pair and no correctness hazard. With a mode register, every such boundary needs a barrier, and the compiler must assume the worst at every opaque call.

And the realtime argument from section 8.1 applies: mode state is more context to save, on the critical path of every switch.

**What this costs.** C's `fesetround` and `fegetround` specify a *dynamic* rounding mode, and the pdp64 has no register to put it in. A conforming implementation must keep the mode in thread-local storage and have the few routines that honour it dispatch on it — a branch, in code that is rare and already slow. This is a real incompatibility with a letter of the C standard and it is accepted knowingly: almost all code sets round-to-nearest once and never changes it, and the code that does change it is doing interval arithmetic or error analysis and can afford a branch. (The *exception flags* of `fenv.h` are a different matter: state the program only reads and clears, provided as the sticky `FPSR` of section 4.9.1. The rounding half is not settled: the directed-rounding variants IEEE 754 requires for arithmetic do not exist yet, J.9.10; that this incompatibility should be confirmed with whoever writes the libm port is a standing action.)

**One place the argument would reverse.** If the pdp64 ever acquires a vector unit, RISC-V's `vl` argument applies in full: vector-length-agnostic binaries are a property no opcode can provide, and they matter more as implementations diverge. That choice should be made on its own terms when it arises, not foreclosed here. The route the architecture takes is a vector *device* rather than a CPU extension (manual chapter 8), which sidesteps the question.

### 9.9 Decisions and their reasons

Each entry states what is decided and why.

**The PC base is the first parcel of the instruction.** Reading the PC forces a commitment about *which* PC (section 9.3), and a displacement is relative to a stated point; the point is the first parcel (section 4.1). Starting from the instruction rather than its end means the displacement does not depend on the length chosen for the instruction itself. An assembler that picks the length from the displacement would otherwise iterate, with the displacement depending on the length; with this rule every instruction only grows, relaxation is monotone, and it terminates ([`relaxation.md`](relaxation.md)). Branch displacements count parcels because the reach is stated in parcels.

**`CMP` is register-first** (section 4.2). A literal PDP-11 `src,dst` meaning would make every comparison of a register against an immediate or a memory operand reverse its branch condition; the encoding computes `reg − rm`, and `CMP a,b` followed by `BLT` still means "branch if a < b".

**`C` is a borrow on subtract** (section 4.2), the PDP-11 sense, so `BHIS`/`BCC` mean "no borrow", unsigned `≥`.

**The register-save mask is 32 bits** (section 4.5.2): `PUSHM`/`POPM` carry the mask in an immediate that is two, four or six bytes by its width, and a mask containing `R14` is reserved; the fused `POPMRET` names `R8` to `R15` only, so a save of the upper callee-saved registers does not fuse.

**There are no `FRECPED` or `FRSQRTED`.** The machine has `FDIV`, `FSQRT` and the fused multiply-add family, so a software Newton loop buys speed only if the hardware divide is slow, which this design does not chase. Each estimate needs a table in hardware and an exact specification: ARM and RISC-V pin down the algorithm and the table, while an estimate specified only as "not correctly rounded" lets two implementations return different bits for the same program. And no document names a user (section 1.2 rule 3).

**Floating-point exception flags** (section 4.9.1) exist because IEEE 754 requires five status flags and C99 `<fenv.h>` needs software access to them. They are a sticky register that is written by operations and read by one swap instruction, never trap, and are not a mode (section 1.1).

**Unsigned 64-bit conversions and `FRINTA`** (section 4.9) because C needs them: without the two unsigned conversions each is a compare, a branch and several instructions, and `FRINTA` is C's `round()`; both are qualifiers of existing operations.

**Integer `ABS`, `MIN`, `MAX`, `MINU`, `MAXU` and `SET cc, rd`** (section 4.11). The first group are the integer counterparts of the float operations and by the folding rule add no operation; by the author's decision they are assembler aliases, not native instructions (errata 98). `SET` removes about six bytes per site that would otherwise be compare, branch, two moves and a jump, about 0.4% of code on the measured corpus (section 14.4).

**Half precision** (section 4.9) is a third width in the same spelling rule, with the `binary32` set minus what a half has little use for.

**One spelling rule for floating point, and one alias rule** (sections 4.9, 4.13): `FADD` is `binary64`, a decimal suffix in bits names any other width, and the alternative spellings are aliases, so that the same operation is not spelled three ways.

**NaN results are canonical** (section 4.9.2). Without a rule the bits of a NaN would depend on the host that ran an emulator; the RISC-V rule (no payload propagation) is adopted and hardware must match.

**There are no CRC instructions** (section 4.6.3, section 11): carry-less multiply already covers every polynomial.

**There is no unconditional rule that a mnemonic is one length.** The assembler picks the shortest leaf for every operand shape and the linker relaxes calls and address formations (manual 9.5.5): the lengths only grow, so the iteration ends.

---

## 10. Historical comparison

Measured devices, for calibration:

| Device | Year | Process | Transistors | What it was |
|---|---|---|---|---|
| MOS 6502 | 1975 | 8 µm NMOS | ~3,500 | 8-bit, PLA decode, zero page |
| DEC T-11 | 1981 | 5 µm NMOS | 12,000 | complete PDP-11 integer core, no MMU, no FP |
| ARM1 | 1985 | 3 µm CMOS | ~25,000 | 32-bit RISC, no MMU, no FP |
| Intel 8086 | 1978 | 3 µm NMOS | ~29,000 | 16-bit, segmented, ModR/M |
| Motorola 68000 | 1979 | 3.5 µm NMOS | ~68,000 | 32-bit CISC; **could not restart instructions** |
| MIPS R2000 | 1986 | 2 µm CMOS | ~110,000 | 32-bit RISC, software-refill TLB |
| DEC J-11 | 1983 | 4 µm CMOS | ~120,000 (40K + 80K) | full PDP-11/70: MMU, split I/D, microcoded FP |
| MicroVAX 78032 | 1984 | 3 µm NMOS | 125,000 | **subset** VAX: 175 of 304 instructions, no FP |
| MicroVAX 78132 | 1984 | 3 µm NMOS | 32,141 | the FPU the 78032 did not contain |
| Intel 80386 | 1985 | 1.5 µm CMOS | ~275,000 | 32-bit, paging, segmentation |

The pair that settles the argument is J-11 against 78032. A complete PDP-11/70 — memory management, split instruction and data space, supervisor mode, microcoded FP11 floating point — cost about 120,000 CMOS transistors. A VAX with packed decimal, character strings and H-float amputated and left to macrocode emulation, and with no floating point on the die at all, cost 125,000 NMOS transistors. CMOS runs roughly twice the device count of NMOS for equivalent logic, so like-for-like the full PDP-11 lands near half the subset VAX.

Two cautionary entries. **The 68000 is very nearly this machine** — PDP-11-derived orthogonality, widened, no decimal or string instructions — and it could not support demand paging, because a bus error left unrecoverable internal state with no resume path. The 68010 retrofitted a fix by dumping microstate to the stack for `RTE`. That fix is expensive and ugly precisely because it was retrofitted; section 7 is architectural from the first draft, and that is the whole difference. **The NS32000** was a deliberate single-chip VAX-alike with a fully orthogonal memory-to-memory model, and it paid for that orthogonality in both silicon bugs and cycles per instruction.

### Estimated budget

Not measured, and made for the first iteration's sixteen-register file: a sanity check on the design point for a non-pipelined or short-pipeline implementation in a modern process. The one line that changes with the current design is the register file (thirty-two registers is about twice the sixteen-register figure below, and still among the cheapest blocks; the figure is an estimate, not a measurement), and the prefix decode is somewhat larger than the escape sub-decode it replaces. The FPGA plan ([`pdp64-fpga-plan.md`](pdp64-fpga-plan.md)) has the LUT-level estimates.

| Block | Transistors | Notes |
|---|---|---|
| register file, 16 × 64, 2R1W (first estimate; 32 registers about double) | ~6,000 | |
| ALU, shifter, address adder | ~15,000 | |
| decode and sequencer | ~6,500 | first estimate, escape sub-decode |
| bit unit: popcount tree, CLZ/CTZ, bitfield | ~3,500 | |
| block move sequencer | ~1,500 | |
| UTF-8 decode and validity | ~1,200 | |
| TLB, 32 entries, walker, DMW compare | ~19,000 | |
| FPU with FMA, classify, min/max | ~34,000 | the FMA datapath |
| control, PSW, exception, undo buffer | ~5,500 | progress category |
| **total, excluding caches** | **~92,000** | first estimate |

A 64-bit machine with floating point and memory management below the 78032's 125,000, which had neither. The FMA datapath is the largest single addition and the least negotiable (section 9.7). The bit unit and the UTF-8 decoder together cost less than 5% of the die and remove the three most common software workarounds.

---

## 11. Explicitly rejected

The decided refusals are listed in manual 9.17; this table keeps the reasons.

| Rejected | Source | Reason |
|---|---|---|
| **general memory-to-memory operands** | PDP-11, VAX | doubles the operand path, the register side-effect count and the fault matrix. The useful cases are all loops; the block operations serve them with progress in architectural registers instead |
| deferred addressing modes, as general operand forms | PDP-11, VAX | second memory reference inside operand evaluation. *`JMPI`/`CALLI` (section 4.8.1) are the one admitted exception — deferred transfer only, where no register is written before the load* |
| unbounded instructions with hidden microstate (`MOVC5`, `EDITPC`) | VAX | requires resumable microstate. Note the distinction from section 4.7, which is unbounded *without* hidden state |
| packed decimal arithmetic and `EDITPC` | VAX, PDP-11 CIS | `EDITPC` is a bytecode interpreter in microcode. DEC needed a separate control chip for the PDP-11 CIS and shipped none. *Note: the VAX **character-string** group is largely implemented, not rejected — see section 14.1* |
| `CRC` with a committed polynomial; `CRC32`/`CRC32C` instructions | VAX, x86 SSE4.2, ARMv8 | `CLMUL` is the primitive beneath every CRC and also serves GF(2^k) and GCM, without baking a polynomial into the architecture (section 4.6.3). |
| `FRECPED`, `FRSQRTED` (reciprocal and rsqrt estimates) | ARM, RISC-V, Itanium | `FDIV`, `FSQRT` and FMA exist, so Newton loops pay only if hardware divide is slow; each needs a hardware table and an exact specification, which "not correctly rounded" is not; no document names a user (section 9.9) |
| `CMP` with the PDP-11's literal `src,dst` operand order | PDP-11 | every compare of a register against an immediate or memory operand would reverse its branch condition (section 4.2) |
| `-d(Rn)` as the pre-decrement syntax | — | it is already a negative base displacement; `-(Rn)` and `(Rn)-d` are used (section 5) |
| NaN payload propagation | IEEE 754 implementations | results would depend on the host or implementation; every NaN result is the canonical quiet NaN (section 4.9.2) |
| `POLY` polynomial evaluation | VAX | the best pre-FMA answer, and superseded by FMA: a three-instruction loop (section 9.7.2) |
| `MULU` as a distinct low-half multiply | PDP-11 EIS, VAX | the low 64 bits of a two's-complement product are identical signed or unsigned; a second multiply would duplicate it, while the high half needs its own instruction (section 4.2.1) |
| `IOT`, `EMT` (also as assembler aliases) | PDP-11 | `TRAP #n` and `TRAPL #n` reach 256 vectors; a dedicated opcode for two particular values of *n* buys nothing (section 4.10.1). |
| `WAIT` | PDP-11 | subsumed by `WFE`, which waits for an interrupt *or* an inter-core event (section 4.10.1) |
| `RESET` | PDP-11 | resetting the bus is a root-complex register write, not an instruction. Section 16 says what the architecture owes devices, and bus policy is not on the list (section 4.10.1) |
| `ROL` as an instruction | PDP-11 | one rotate direction suffices; `ROL #n` is an assembler alias for `ROR #(64−n)` at no cost (sections 4.5.1, 4.13) |
| **NUL-terminated string instructions** | System/z `MVST`, `SRST`, `CLST` | they encode an unbounded read, which is the single most prolific source of memory-safety failures in C. `MSCN` with an explicit maximum gives `strnlen`, and composing it with `MCPY` gives a bounded `strcpy` in two instructions with the length known in between — which is the safer idiom anyway (section 14.2) |
| hardware call frames (`CALLS`/`CALLG`) | VAX | slower than the equivalent sequence on later VAXen; `PUSHM`/`POPM` keeps the useful part |
| multiple float formats | VAX | one IEEE family (`binary16`, `binary32`, `binary64`) |
| **transcendental instructions** | x87 | slow, and inaccurate for large arguments in a way software cannot repair (section 9.7) |
| PC in the general register file | PDP-11, ARM32 | every register write becomes a potential branch |
| **read-only `PC` view of `R7`** | ARM32 | cheap in hardware, but forces a permanent definitional commitment about *which* PC — ARM32's `PC+8`. `LEA 0(PC), Rn` has the capability without it (section 9.3) |
| preserved partial-register writes | x86 (`AH`/`AL`) | merge dependency on every narrow write. *The objection is to preserving upper bits, not to naming sub-widths. x86-64 fixed this for 32-bit writes by zero-extending and left it broken for 8- and 16-bit; section 4.1 applies the fix uniformly* |
| `REX` and operand-size prefixes | x86 | decode tax on every instruction; a mode bit in disguise |
| segmentation | x86 | solved by paging |
| non-uniform flag writes | x86 | `INC` not writing carry, to save one byte |
| implicit registers for multiply, divide, shift count | x86 | saves opcode bits, costs a permanent shuffle in every compiler and every hand-written loop |
| x87 register stack | x86 | |
| byte-granular instruction fetch | x86, 6502 | alignment rotator in the front end for ~10% density |
| decimal mode | 6502 | mode bit; same error class as `FPS.FD/FL/FT` |
| accumulator-centric register set | 6502 | 1975 economics |
| separate FP register file | most | largest single block saved on a small implementation |
| 32-bit profile | — | one architecture; `MOVL` retains 32-bit data, which is what is needed |
| a fourth parcel for general instructions | — | a longer form's only customer is the 64-bit literal, which `MOVQL` and the pool already serve (section 9.6); the limit is three parcels, one literal excepted |
| 8-byte instruction alignment | — | 5–10% padding plus an alignment obligation through assembler, linker and every hand-written stub, for a fetch path that is already cheap |
| `MOVT` / `MOVK` top-half insert | AArch64 | `MOVQL` and the constant pool cover 64-bit literals without a partial-write instruction to reconcile against section 4.1 |
| hardware tag checking on dereference | Lisp machines | a comparator, tag bits in the datapath and a trap path, to buy what sections 6.2 and 7.4 already give approximately free |
| a load form that ignores low pointer bits | — | deletes the alignment fault, which *is* the tag check; turns a corrupted tag into silent corruption |
| fused allocation; store-with-write-barrier | Lisp machines, JVMs | bakes a specific allocator or collector into the architecture, for three or four ordinary instructions |
| an instruction-set-switch bit in pointers | ARM Thumb `BX` | permanently consumes bit 0, which section 6.2 grants to software |
| self-synchronizing encoding | UTF-8 | a marker bit in every parcel is 6.25% of the encoding space and caps immediates at 15 bits per parcel. Landing pads get the security property for one opcode |
| `R0` hardwired to zero | LoongArch, MIPS, RISC-V, Alpha | costs a thirty-second of the register file to save instructions the pdp64 already has — `CLR` is one parcel and `TST` is one parcel (manual 9.20.3) |
| fused compare-and-branch **replacing** flags | LoongArch, RISC-V | a comparator in the branch unit and a third read port, versus a four-bit latch. The pdp64 has a fused compare-and-branch (`CBCC`) *beside* the flags, writing none, and `SOB` for the loop case |
| a scalar instruction for sub-1-bit model inference | LittleBit, BitNet-class models | the kernel is bandwidth-bound with its op count equal to its weight-bit count, so it wants a bus-mastering accelerator with its own DMA, not an opcode (section 4.6.2) |
| branch delay slots | MIPS | exposes one implementation's pipeline depth forever — the same error as ARM32's `PC+8` |
| register windows | SPARC | spill/fill traps, and it fixes the wrong problem |
| software-refilled TLB | MIPS, Alpha | cheaper; rejected on miss-cost grounds with a multi-level table |

---

## 12. Open items

The open items of the instruction set are discussed, each with its options and their pros and cons, in **appendix J of the manual** ([`manual/appendix-j-open.md`](manual/appendix-j-open.md), chapter 9 items J.9.1 to J.9.12, and the ABI items J.D.1 and J.D.2); the ledger lists their status. They are the work that comes before the encoding is frozen (see [`handoff.md`](../handoff.md) for the order of work). In short, and by the keys of appendix J:

- **J.9.1** the conditional select and the expansions of `ABS`, `MIN`, `MINU`, `MAX`, `MAXU`;
- **J.9.2** constant-time execution: what holds while `DIT` is clear, and where `DIT` lives;
- **J.9.3** the atomic group: where the operands go and the size of `CAS`; and against the bus, **J.7.4** atomics on uncached and device memory;
- **J.9.4** the checked arithmetic: the number of the `CHECK` vector and the register form (with **J.6.10**, the vector of `TRAPCC`);
- **J.9.5** addressing-mode gaps: the scaled-index displacement and a store through `d(DP)`;
- **J.9.6** the page-bit mechanisms and the six reserved system words;
- **J.9.7** the worst-case latency of the block operations: an implementation claiming an interrupt-latency figure must state its block granularity;
- **J.9.8** the block operations and the data cache: a one-megabyte `MCPY` evicts the whole data cache for data never read again; options are a non-temporal variant, a streaming memory type or a decision by length (the last a performance cliff with no architectural visibility);
- **J.9.9** the floating-point condition flags: `FCMP` writes the integer flags, which serializes FP compares against integer work, and the signed branches do not yet treat unordered cleanly; LoongArch's separate `FCC` bits are the comparison;
- **J.9.10** directed rounding for arithmetic and the remaining half-precision operations (the rounding mode lives in the opcode, section 9.8, and there are no such opcodes except `FRINT*`);
- **J.9.11** the coherence protocol beyond four cores and the verification of the memory model (sequential consistency is easy to violate accidentally through a store buffer that forwards incorrectly; litmus tests against the published SC suites belong before a second core exists);
- **J.9.12** the poison bit, the user-qualified moves and the cryptographic words;
- **J.D.2** landing pads (mandatory now or optional-then-mandatory: the decision gets more expensive the longer it waits; a tagged function pointer must still land on a landing pad, and so must every entry of a `JTAG` table), lazy against eager binding, and the red zone.

Resolved, for the record: a reserved-opcode discipline (replaced by the prefix code and the optimiser), the length of instructions (one to three parcels, `MOVQL` the one exception), and UTF-8 scope (`MVAL` is committed). Facts still unmeasured: the cost estimates of the half-precision conversions; the worst-case instruction latency of the block operations.

---

## 13. Side by side: PDP-11, VAX, pdp64

### 13.1 Architecture

| | PDP-11 | VAX | pdp64 |
|---|---|---|---|
| Word | 16 bits | 32 bits | 64 bits |
| General registers | 8 (`R0`–`R7`) | 16 (`R0`–`R15`) | 32 (`R0`–`R31`) |
| PC | `R7`, fully writable | `R15`, fully writable | **not a register** |
| SP | `R6`, per-mode copies | `R14`, per-mode copies | **`R14`**, per-mode copies |
| FP | software convention | `R13`, used by `CALLS`/`CALLG` | **`R13`**, software convention |
| AP | — | `R12`, for `CALLS`/`CALLG` | none — `R12` is general |
| Virtual address | 16 bits (18/22 physical) | 32 bits | 39, 48 or 57 bits (40 to 64 physical) |
| Instruction count | ~70 base, plus EIS/FIS/FP11/CIS options | 304 | 268 leaves in 207 forms (`spec/pdp64/tables.md`); the mnemonic count is in the dictionary |
| Instruction length | 1–3 words (2–6 bytes) | 1 to over 50 bytes | 1–3 parcels (2–6 bytes), plus the ten-byte literal move |
| Operands per instruction | 1 or 2 | 0 to 6 | 1 or 2, plus 3 for the block group and the fused `MOV2` |
| Memory operands per instruction | up to 2 | up to 6 | **1** |
| Addressing modes | 8 | 16 | 8 |
| Condition codes | N Z V C | N Z V C | N Z V C |
| Floating point | FP11 option, separate `AC0`–`AC5` | in the base, separate `F` registers | in the base, **in the GPRs** |
| FP formats | F, D | F, D, G, H | `binary16`, `binary32`, `binary64` |
| Mode bits affecting semantics | `FPS.FD/FL/FT` | `PSL` rounding, `FPD` | **none** |

### 13.2 Encoding, double-operand

**PDP-11** — one word, plus 0–2 extension words:

```
 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
+--+--------+-----------------+-----------------+
| b|   op   |   src specifier |  dst specifier  |
+--+--------+-----------------+-----------------+
```

Bit 15 is the byte flag, bits 14..12 the opcode, and each specifier is 3 bits of mode plus 3 bits of register. Seven double-operand instructions exist, and the encoding is *exactly* full: `MOV`=01, `CMP`=02, `BIT`=03, `BIC`=04, `BIS`=05, `ADD`=06 — and `SUB`=16, which is `ADD` with bit 15 set, because `ADD` had no byte form and the bit was free. That is the cleverness and the cramp in one place.

**VAX** — one or two opcode bytes, then one specifier byte per operand, each with 0–8 bytes of extension:

```
byte 0:    opcode                  (FD prefix selects a second opcode byte)
byte 1:    mmmm rrrr               specifier 1: 4-bit mode, 4-bit register
           [0-8 bytes extension]
byte n:    mmmm rrrr               specifier 2
           [0-8 bytes extension]
```

Modes `0`–`3` pack a 6-bit literal into the specifier byte itself, so `MOVL #5, R0` is three bytes. Mode `4` is *index*, a prefix that wraps the following specifier. Modes `9`, `B`, `D`, `F` are deferred — a memory read during operand evaluation. Length is not a function of any fixed field.

**pdp64** — one parcel, plus 0–2 extension parcels. The first parcel is a prefix (3 to 16 bits), then the sub-opcode, then the operand pieces that fit; the register fields are counted from bit 0 upward; the later parcels hold the displacement, the immediate or the second half of a split field. There is no fixed opcode field and no mode field: the prefix selects the leaf, and the leaf's form says what each operand is. The drawing of every leaf is in the manual's dictionary (`manual/dictionary/by-encoding.md`).

### 13.3 Operand specifiers

| | PDP-11 | VAX | pdp64 |
|---|---|---|---|
| Specifier | 6 bits | 8 bits + 0–8 extension | a field of the leaf (the form lists the shape) |
| Mode field | 3 bits | 4 bits | none: the mode is the leaf |
| Register field | 3 bits | 4 bits | 3 (hot-register index), 4 (hot-register index) or 5 bits |
| Deferred forms | **free** — low bit of mode is the indirect bit | 7 of 16 modes | **none** |
| Literals in the specifier | no | yes, 6-bit, modes 0–3 | yes, small immediates in one-parcel and two-parcel forms |
| Index as a prefix | no | yes, mode 4, wraps another specifier | no — one scaled-index mode |
| Register side effects | up to 2 per instruction | unbounded | 1, or 3 for the block operations |

The PDP-11's indirect bit is the detail to note. Making the low bit of the mode field mean "deferred" gave eight modes for the price of four designs. It is also the single most expensive thing in the encoding, because it made half the modes issue a memory reference during operand evaluation. The pdp64 deletes the deferred forms and has no second memory reference anywhere.

### 13.4 The front end

| | PDP-11 | VAX | pdp64 |
|---|---|---|---|
| Length known from | both specifiers of word 0 | nothing fixed; sequential parse | the prefix of parcel 0 |
| Memory refs during operand eval | up to 4 | unbounded | **1** |
| Restart mechanism | `MMR0`/`MMR1`/`MMR2`, software undo | `PSL<FPD>` + per-instruction microstate | hardware buffer, committed at retire |
| Restart state size | 2 journal entries + PC | implementation-defined, large | 1 buffered register write |
| Worst-case instruction | `MOV @X(R1), @Y(R2)` — 6 bytes, 4 memory refs | `MOVC5` — unbounded refs, resumable microstate | 6 bytes, 1 operand ref; block group with register progress |

### 13.5 Instruction-level correspondence

| PDP-11 | VAX | pdp64 | Note |
|---|---|---|---|
| `MOV` / `MOVB` | `MOVL` / `MOVB` / `MOVW` / `MOVQ` | `MOVQ`/`MOVL`/`MOVW`/`MOVB` + `MOVZ*` | size in the opcode; explicit extension |
| `ADD` `SUB` `BIC` `BIS` `CMP` `BIT` | same, plus sizes | same names, 64-bit only | unchanged mnemonics |
| `XOR` (register source only) | `XORL` etc. | `XOR`, full modes | generalized |
| `MUL` `DIV` `ASH` `ASHC` (EIS option) | in the base | `MUL` `MULH` `SHL` `SHR` `SAR`; `DIV` `DIVU` `MOD` `MODU` `MULHU` | in the base |
| `CLR` `COM` `INC` `DEC` `NEG` `TST` `ADC` `SBC` | same | single-operand forms | unchanged |
| `JMP @X(Rn)` (mode 7) | mode `9`/`B`/`D`/`F` deferred specifiers | **`JMPI`** `CALLI` | deferred *transfer* only; no deferred *operands* |
| `ASL` `ASR` (by one) | `ASHL` with a count | `ASL` `ASR` | unchanged |
| `ROL` `ROR` (by one, **through carry**) | `ROTL` with a count | `ROR` / `RORI`; `DSHR` for multi-precision | not through carry — section 4.5.1 |
| `SWAB` | `ROTL` | `BSWAP` | generalized to 64 bits |
| `SXT` | `CVTBL` etc. | conversion set | subsumed |
| `SOB` (backward only) | `SOBGEQ` `SOBGTR` `AOBLEQ` `AOBLSS` `ACB` | **`SOB`**, both directions | both directions, section 4.4 |
| `JSR Rn, dst` / `RTS Rn` | `CALLS` / `CALLG` / `RET` | `CALL` / `RET`, `PUSHM` / `POPM` | sections 14.2, 4.5.2 |
| `MARK` | — | — | dropped by DEC too |
| `TRAP` `EMT` `IOT` `BPT` | `CHMK` etc. | `TRAP` `TRAPL` `BPT` | `EMT`/`IOT` are `TRAP #n` (section 4.10.1) |
| `SEC` `CLC` `SCC` `CCC` | `BISPSW` `BICPSW` | `MTPS` | consolidated |
| `MFPI` `MTPI` `MFPD` `MTPD` | `PROBER` `PROBEW` | `PROBER` `PROBEW`, `.U` moves, the user-memory guard | VAX's form is better |
| — | `EDITPC` `MOVC5` `CMPC5` `MOVTC` `LOCC` `SKPC` `MATCHC` | `MCPY` `MMOV` `MSET` `MCMP` `MSCN` | same jobs, register progress (section 7.5) |
| — | `INSV` `EXTV` `EXTZV` `FFS` `FFC` | `INSB` `EXTB` `EXTZB` `CTZ` `CLZ` | section 4.6 |
| — | `CASEB` `CASEW` `CASEL` | **`JTAG`** for 8-way tag dispatch; bounds-check + table otherwise | section 6.3 |
| — | `INDEX` (with bounds check) | scaled-index mode, no bounds check | section 14.2 |
| — | `INSQHI` `REMQHI` interlocked queues | `CAS`, `LL`/`SC` | section 14.2 |
| — | `POLY` `CRC` | — | rejected |
| — | packed decimal group | — | rejected |
| — | — | `BTAG` `BNTAG` `JTAG` | new, section 6.3 |
| — | — | `POPCNT` `XNORPOP` `BITREV` `BSEL` | new, section 4.6 |
| — | — | `UTF8LEN` `UTF8DEC` `UTF8ENC` `MVAL` | new, section 4.6.1 |
| — | — | `FMADD` family, `FCLASS`, `FSFLAGS`, `binary16` | new, section 4.9 |
| — | — | `SET`, `MASKEQZ` `MASKNEZ`, `ADDV` `SUBV` `MULV`, `TRAPCC` | new, section 4.11 |
| — | — | `ABS` `MIN` `MAX` `MINU` `MAXU` | assembler aliases, errata 98 |
| — | — | `MOVCALL` `POPRET` `POPMRET` `MOV2`, `CBCC`, `MOVQL` | new, sections 4.4, 4.1 |
| — | — | `_DB` atomics | new, section 4.10.2 |

---

## 14. Idioms: lost, restored, replaced

### 14.1 Restored

| Idiom | Source | Here |
|---|---|---|
| **Subtract one and branch** | PDP-11 `SOB`, VAX `SOBGEQ`/`AOBLSS`/`ACB` | `SOB`, section 4.4. The PDP-11's could only go backward; this one goes either way with four reaches |
| **Probe an address without faulting** | VAX `PROBER`/`PROBEW` | `PROBER`/`PROBEW`, section 4.10.1. Replaces the `nofault` global for the address-validation case |
| **Bitfield extract and insert** | VAX `EXTV`/`EXTZV`/`INSV` | `EXTB`/`EXTZB`/`INSB`, section 4.6 |
| **Find first set / clear** | VAX `FFS`/`FFC` | `CTZ`/`CLZ`, section 4.6 |
| **Byte swap** | PDP-11 `SWAB` | `BSWAP`, section 4.6, generalized to 64 bits with word and long variants |
| **Block move, fill, compare, scan** | VAX `MOVC3`/`MOVC5`/`CMPC3`/`LOCC`/`SKPC`, System/360 `MVCL` | `MCPY`/`MMOV`/`MSET`/`MCMP`/`MSCN`/`MSCNN`, section 4.7 — with the progress in registers, which is what VAX got wrong |
| **Register save mask** | VAX procedure entry mask | `PUSHM`/`POPM`, section 4.5.2 — the useful half of `CALLS` without the frame |
| **Carry-less multiply** | — (modern: x86 `PCLMULQDQ`, ARM `PMULL`) | `CLMULL`/`CLMULH`, section 4.6.3 — the primitive VAX's `CRC` should have been |

#### 14.1.1 What "string instructions" meant, and how much of it is present

"String" is ambiguous in this context, and the VAX character-string group is largely present rather than rejected.

**VAX and PDP-11 CIS "strings" are counted byte strings** — a length and an address, passed as separate operands or as a descriptor. They have nothing to do with C's NUL-terminated convention, which post-dates both. Every one of these instructions takes an explicit length:

| VAX | What it does | pdp64 |
|---|---|---|
| `MOVC3` | move *len* bytes | **`MCPY`** |
| `MOVC5` | move with fill byte and truncation | `MCPY` + `MSET`, two instructions |
| `CMPC3`, `CMPC5` | compare *len* bytes | **`MCMP`** |
| `LOCC` | locate a byte — `memchr` | **`MSCN`** |
| `SKPC` | skip a byte — first byte *not* equal | **`MSCNN`** |
| `MOVTC` | move translated through a 256-byte table | **absent** — see below |
| `SCANC`, `SPANC` | scan using a table and a mask | **absent** |
| `MATCHC` | substring search — `strstr` | **absent** |
| `CRC` | table-driven CRC | `CLMUL` instead (section 4.6.3) |
| `EDITPC` | packed-decimal to character under a bytecode program | **rejected**, section 11 |

So seven of the ten are present or better, and the rejection is about `EDITPC` and the packed-decimal group rather than about character strings, as section 11 says.

**And `UTF8DEC`/`UTF8ENC`/`MVAL` are string instructions in the same tradition**, serving an encoding that did not exist in 1977. `MVAL` in particular is precisely the shape of `SCANC`: stream a buffer, stop at the first byte failing a predicate, leave the pointer there.

**The three absent, and whether they matter.** `MOVTC` — table-translated move — is the most defensible: charset conversion, case folding and `tr` all want it, and the 256-byte table can live on chip. It is absent because a table lookup per byte breaks the streaming model that lets the block group move a quad per cycle, so it would be the one slow member of a fast group. `SCANC`/`SPANC` are `MOVTC`'s predicate form with the same problem. `MATCHC` is a naive O(n·m) substring search, which is the wrong algorithm to put in silicon. All three are block-group candidates if measurement ever justifies them; none is justified now.

### 14.2 Deliberately lost, with what replaces them

**Memory-to-memory `MOV`.** `MOV (R1)+, (R2)+` in a loop was the PDP-11 copy idiom and it is gone. The replacement is better rather than merely adequate: `MCPY` is one instruction instead of a loop body, the implementation may move 64 bytes per cycle while the architecture says bytes, and restart is free. What is genuinely lost is the *general* case — a single move between two arbitrary computed addresses, which now takes a load and a store. Two instructions, one extra register. Accepted.

**`@(Rn)+` and the dispatch-table idiom.** Autoincrement-deferred walked a table of pointers, which made it the natural way to write an interpreter's dispatch and a driver's jump table. Replaced two ways: `JTAG` (section 4.8) for the tag-dispatch case, which is better because it needs no pointer register and cannot index out of range; and `MOVQ (Rn)+, Rt` followed by `JMP (Rt)` for the general case, which is two instructions where the PDP-11 had one. The threaded-code interpreter loop is the specific thing that gets worse, and that is the cost.

**`JSR Rn, dst` / `RTS Rn`.** The PDP-11's call was richer than the pdp64's. `JSR Rn, dst` computes the effective address, pushes the *old contents of `Rn`* onto the stack, puts the PC into `Rn`, and jumps. `RTS Rn` moves `Rn` to the PC and pops the saved value back into `Rn`.

So the return address lived in a register of the caller's choosing, not on the stack. Three things fell out of that:

1. **`JSR PC, dst`** was the degenerate case — push PC, jump — and that is exactly `CALL` here. Most code used this.
2. **Arguments inline after the call.** With the return address in `Rn`, the callee read its arguments with `(Rn)+` and returned past them. Compact, and the ancestor of VAX's `CALLG`. Gone, and not missed: it defeats every debugger, every unwinder and every calling convention written since.
3. **Cheap coroutines.** `JSR R5, other` from one routine and `JSR R5, back` from the other swap control with the linkage in a register rather than on a stack. A real capability, and absent. The replacement is an explicit stack switch, which is more instructions and more honest.

What `CALL`/`RET` gain here: no register burned, no push-and-shuffle of the old register value, and the return address exactly where every ABI, unwinder, profiler and debugger expects it. And it is the form that can be protected — landing pads and a shadow stack are both meaningless if the return address can live in any register the caller picked.

**VAX `CASEB`/`CASEW`/`CASEL`.** A bounds-checked, table-driven multiway dispatch in one instruction — good for a `switch` statement. Here a general `switch` is a compare against the limit, a branch to the default, and a `JMP` through a scaled index: three or four instructions (the compiler emits a jump table with eight-byte entries for a dense `switch`: manual 9.18.7). `JTAG` covers the 8-way tag case in one. The general case is a real regression and a candidate if measurement supports it.

**VAX `INDEX`.** Array index with bounds checking in one instruction, which is what Pascal and Ada want on every subscript. The scaled-index mode gives the scaling but no check. A bounds-checked variant is a plausible future member; noted rather than designed.

**Byte and word ALU operations.** `BISB`, `BICB`, `ADDB` have no equivalent — the ALU is 64-bit only (section 4.2). A byte-wide read-modify-write on memory becomes `MOVZB`, the operation, then `MOVB` back: three instructions where the PDP-11 had one. This is the most frequently felt loss in hand-written code and it is the direct price of having no partial-register writes and no byte-lane muxing in the ALU. The ALU-to-memory words `ADDM`, `SUBM`, `BICM` and `BISM` cover the quad case.

**Condition-code operate instructions.** `SEC`, `CLC`, `SEV`, `CCC` set and cleared individual flags in one word. `MTPS` writes the whole status word. Minor.

### 14.3 Subsumed, so not losses

- **`SXT`** set the destination to 0 or −1 from `N`. The conversion set (section 4.1) is strictly more general — `MOVB R1, R2` sign-extends any width from any register — so `SXT` was redundant and is dropped.
- **`SWAB`** swapped the bytes of a word. `BSWAP` does 64 bits, with `BSWAPW` and `BSWAPL` for the narrower cases.
- **`MARK`** was the PDP-11's stack-cleanup helper for the inline-argument convention. DEC's own T-11 omitted it as "little-used," and the convention it served is gone (section 14.2).
- **`ASH`/`ASHC`** shifted by a variable count. `SHL`/`SHR`/`SAR` take the count from the second operand, which includes a register.
- **`MFPI`/`MTPI`/`MFPD`/`MTPD`** moved data between address spaces for the kernel. `PROBER`/`PROBEW` plus ordinary loads under the previous-mode bits (and, in the current design, the user-memory guard and the `.U` moves) is the better arrangement, and it is VAX's.
- **`MULU`** was never distinct from `MUL`; section 4.2.1 explains why, and `MULH` occupies the slot. The mnemonic is accepted as an alias.
- **`IOT` and `EMT`** are `TRAP #n` at two particular vectors. **`WAIT`** is `WFE` when no `SEV` is sent. **`RESET`** is a root-complex register write. All four are dropped (section 4.10.1).
- **`ROL`** survives as an assembler alias rather than an instruction (section 4.13), which is the form the operation deserves.

### 14.4 What the measurements say about the instructions added and not added

The figures behind the decisions on added and rejected instructions. Method: the "fair corpus" is the 841-file benchmark set (bearssl, c-testsuite, chibicc, cjson, gcc-torture, lua, lz4, mbedtls, zlib and others) that the aarch64, amd64 and i386 builds of the project's C compiler all compile. **These were measured on the compiler output of the first iteration and are the reasons for the decisions; the current measured figures, for the pdp64, are in manual appendix F and `encoding-work/integration.md`.**

- **`SET`, and conditional selection.** gcc `-Os` for amd64 emits 284,641 instructions on the corpus, 11.0% conditional branches, 783 `cmov` and 673 `set<cc>`. A `set cc, rd` removes about six bytes per site, about 0.4% of code. A select is size-neutral and pays only in speed. `SET` exists; the select is on hold, and `ABS`, `MIN` and `MAX` wait on it as aliases (errata 98).
- **Integer `ABS`, `MIN`, `MAX`.** `ABS` at 18 sites and `ABSU` at 5, `MIN` at 171 and `MAX` at 52, across 95 files. The measured gain is under 0.1% of code; the case was clarity and the idiom, not size, and the decision to make them aliases follows from it.
- **Bit-fields (`EXTB`, `EXTZB`, `INSB`).** The shift-pair extraction pattern occurs 151 times in 26 files, about 600 bytes at best (0.03%).
- **Auto-increment.** Of 10,547 `lea n(rX),rX` only 437 have a dereference through the same register next to them (about 0.1%). They remain for hand-written code and the string and block idioms (the current compiler does emit the strided modes where its loops allow: manual 9.18.9).
- **Costs the first iteration's code showed and the prefix-coded encoding removed or reduced:** about 35,000 six-byte cross-section `call` and `lea` (linker relaxation takes a further 3.76% off the corpus: manual 9.5.5); `LEA 1(Rx), Rx` 7,852 times where `INC` exists; memory operands that are quad only, so `movl` is 10% of all instructions; no 32-bit arithmetic, so a wrap-correct `int` costs 4.1% of instructions and 1.9% of bytes.

---

## 15. What was taken from LoongArch, and what was not

LoongArch64 is worth studying here because it is the most recent clean-room ISA designed without an ideological commitment — it borrowed from MIPS, from RISC-V and from ARM as each had the better answer, which is exactly the posture section 1.1 adopts.

### 15.1 Adopted

| Idea | LoongArch form | Here |
|---|---|---|
| **Bit manipulation is core, not an extension** | `CLO`/`CLZ`/`CTO`/`CTZ`, `BSTRINS`/`BSTRPICK`, `BYTEPICK`, `REVB`/`REVH`/`BITREV`, all in the base ISA | section 4.6. This was the decisive argument for giving it a place in the base rather than leaving the functions scattered or absent |
| **Atomics with the barrier folded in** | `AMSWAP`, `AMADD`, `AMAND`, `AMOR`, `AMXOR`, `AMMAX`, `AMMIN`, each with a `_DB` variant | section 4.10.2. A lock acquire is one instruction rather than an atomic plus a `FENCE`, and that pair is in every critical section in the system |
| **Direct mapping windows** | `CSR.DMWn`, `VA = PA + FixedOffset`, with cache attributes selected by high VA bits | section 8.3 (format deferred). The kernel stops taking TLB misses on its own text, physical memory is reachable without mapping |
| **Memory type as a page attribute** | `DMW` cache attributes: strongly-ordered uncached, coherent cached, weakly-ordered uncached | `MT` field, section 8.2 |
| **A richer atomic set than the minimum** | fetch-and-min/max as well as add/and/or/xor | section 4.10.2. Each is a couple of hundred LUTs and saves a `CAS` retry loop |
| **Branch-free select** | `MASKEQZ`/`MASKNEZ` | section 4.11 (decided) |
| **32 general registers** | the register file | the prefix-coded encoding has the bits for them (section 9.1) |

### 15.2 Declined, with the reason

| Idea | Why not |
|---|---|
| **`R0` hardwired to zero** | Costs a thirty-second of the register file, and `CLR` and `NEG` are already one parcel each (manual 9.20.3). (An earlier text said the trade was good at 32 registers and not at 16; the author's decision stands as the manual states it: declined.) |
| **No condition codes; compare-and-branch instead** | A comparator in the branch unit plus a third register read port, versus a four-bit latch. LoongArch can afford it because its fixed 32-bit encoding has room for two register fields and a displacement in one instruction; a variable-length encoding makes `CMP`+`B` the same size. The pdp64 has `CBCC` beside the flags, and `SOB` for the loop case |
| **`FCSR` with a rounding-mode field** | LoongArch kept the mode bits, as did RISC-V, ARM and x86. The pdp64 is the outlier: the default of section 1 is visible state in the instruction, not invisible state that changes what other instructions mean, and rounding mode is the textbook case; it is decided case by case and can be reopened. The cost is more sub-opcodes, which is the cheapest thing we have |
| **Four PC-relative address-formation instructions** | `PCADDI`, `PCADDU12I`, `PCADDU18I` and `PCALAU12I` exist because a fixed 32-bit encoding carries twenty bits of immediate, so building a full address takes a pair. `LEA d(PC), Rn` in its six-byte form carries 32 bits in one instruction. This is the clearest case where variable-length beats fixed-width |
| **Separate vector register files (LSX, LASX)** | A second wide register file is the thing section 2.3 specifically avoided, and it would bring wide load/store paths entangled with section 7.4's alignment rules. Wide data-parallel work goes in a bus-mastering device with its own memory, which needs **no instruction-set change at all**; the LB64 document (proposed) is the worked case |

### 15.3 Under consideration

- **Separate FP condition flags.** LoongArch's eight one-bit `FCC` registers solve a real problem that appendix J records (J.9.9).
- **Software-visible TLB manipulation.** LoongArch has both a hardware walker *and* `TLBSRCH`, `TLBRD`, `TLBWR`, `TLBFILL` — so the kernel can manage entries directly when it knows better. The pdp64 has only `TLBI`/`TLBIA`. Being able to pin an entry is useful for a realtime kernel, and worth one system word.
- **A flag-reading conditional select.** With flags available, `CMOV` would be the natural form; the branch-free-select case matters for constant-time cryptographic code, where `MASKEQZ`/`MASKNEZ` and `BSEL` serve. On hold (J.9.1), and the aliases `ABS`, `MIN` and `MAX` of errata 98 sit on it.

---

## 16. What the architecture owes devices

Graphics, networking, storage and the C64-derived devices are all devices on the system bus (PCI Express, with the additions that appendix J.2.5 and [`pdp64-q64-bus.md`](pdp64-q64-bus.md) discuss), and **none of them touches the ISA**. The separation lets the device side churn without respecifying the processor.

What the ISA owes them is exactly three things (manual 2.8):

1. **A memory type per page** (`MT`, section 8.2), so a framebuffer can be mapped uncached and a command queue weakly ordered, without the code doing the writing having to know.
2. **An ordering instruction** (`FENCE`) with a defined meaning against the bus, so a driver can be sure a descriptor is visible before a doorbell write is.
3. **Atomics that reach device memory** (section 4.10.2), for queues shared between the processor and a device (what an atomic does on uncached and device memory is open: J.7.4).

**The device convention.** Devices are in the ordinary address space; the processor has no input or output instructions. The standard devices are **virtio devices** (and a USB controller): the disk is virtio-blk, and the network, graphics and audio devices are virtio-net, virtio-gpu and virtio-snd, found by PCI Express enumeration (the author, errata 75, 79, 95 and 101). The device moves its own data by DMA, so the processor only sets up a transfer and carries no multitasking burden for it, and more of the processor is left for the user and for the programs that matter. This costs the ISA nothing: it is bus and device design, and it uses only the three things above (the memory type of the register page, `FENCE` before a doorbell write, atomics for shared queues). The earlier convention of eight memory-mapped registers per device was withdrawn (errata 95). The chapters on the bus, graphics and drivers are manual chapters 2, 3 and 5.

Everything else — blitters, raster engines, command FIFOs, whether there is a GPU at all — is bus and device design, and belongs in the companion documents rather than here: the implementation plan for the display path, the bus document ([`pdp64-q64-bus.md`](pdp64-q64-bus.md)) for the additions to PCI Express, and the LB64 document for the sub-1-bit inference accelerator (proposed), which is the worked proof of this section, being a substantial bus-mastering device that needed **no instruction-set change at all**.

---

## 17. Symmetric multiprocessing

Multiple bus initiators exist — an accelerator is one — but a DMA master and a second CPU are different problems with different answers, and conflating them is the usual way this goes wrong. The manual's chapter 7 is the decided account; this section keeps the reasoning. Decided since: a system has at least four cores (errata 92); at least one core can run in secure mode, and every core if that is cheap (errata 132, J.7.7); apart from a possible single secure core, no core is dedicated to a role (errata 133).

### 17.1 The memory model is the whole question

Instructions are the easy part. The hard part is what a program is promised about the order in which another core sees its writes, and the choice is close to irreversible: software written against a weak model runs on a strong machine, but not the reverse.

| Model | Used by | Cost to implement | Cost to software |
|---|---|---|---|
| **Sequential consistency** | almost nobody, commercially | high on a speculative out-of-order core | **none** |
| TSO | x86, SPARC | store buffer with load forwarding | modest — store-load reordering only |
| Weak / relaxed | ARM, POWER, RISC-V RVWMO | cheapest in hardware | **high, and permanent** |

> **The pdp64 is sequentially consistent.** Stated here, once, and not revisited (manual 7.5.1).

On this machine sequential consistency is nearly free. A weak memory model is a tax paid by every piece of concurrent software ever written for the architecture, levied so that an aggressively speculative out-of-order core can reorder memory operations. **The first pdp64 implementations are in order and non-speculative,** so they have no reordering to permit and nothing to buy with the weakness. The architecture is ready for out-of-order execution from the start (section 1, errata 68): an out-of-order implementation keeps sequential consistency by letting loads execute early and re-checking them against other cores' writes before retirement, with stores buffered and drained in program order (`decisions-pending.md` Q5, [`pdp64-ooo-readiness.md`](pdp64-ooo-readiness.md), manual 7.7).

A store buffer is still allowed, and wanted, for write latency hiding: SC survives it provided loads snoop the buffer, stores drain in program order, and a load does not complete ahead of an older store to another address that is still in the buffer (or is replayed if it did). Without the last condition two cores that each store to one location and then load the other can both read the old values, the store-buffering outcome of total store order, which sequential consistency forbids (manual 7.5.2). The cost is that a store miss stalls later stores, which on two to four cores behind a shared L2 is acceptable.

The industry learned the hard way why this is not a close call. ARM's memory model took roughly a decade to formalize, academic papers are still finding corners in vendor implementations, and the C11/C++11 memory model exists in large part to paper over the differences between weak architectures. None of that complexity buys anything on a machine whose first implementations do not speculate, and a sequentially consistent out-of-order core pays for it in the load re-check rather than in a weaker contract. Being small is the advantage here.

**Two classes of problem do not arise.** In the first implementations non-speculative execution means no Spectre- or Meltdown-class speculative side channels; an out-of-order implementation must keep that property by the rules in `hardware-vulnerabilities.md`, which is a design obligation and not a free consequence. And the alignment requirement (section 7.4) means every access is naturally atomic within its own size — misaligned atomicity is a nightmare on x86 and ARM, and the pdp64 gets it free from a rule adopted for the datapath's sake and already paying for lowtags (section 6.2). That is the third return on one decision.

### 17.2 What the ISA needs

The instructions the multiprocessor needs are few and are in manual 7.3 and 7.4: `MFCPUID Rd` (which core am I; required for per-CPU data structures; there is no way to synthesize it), `ICINV`/`ICINVA` (invalidate an instruction-cache line, or all of it), `TLBSYNC` (wait for a broadcast `TLBI` to complete everywhere), `WFE`/`SEV` (sleep until another core signals, and the signal), and `TLBI`/`TLBIA` that **broadcast** to all cores. Short notes on the three non-obvious ones.

**`ICINV` exists because instruction caches are not coherent with data caches**, on this machine or on ARM or POWER. Making them coherent costs a snoop port on the I-cache for a case that almost never happens. But "almost never" is not never: a JIT, a trampoline, a loaded module, and a Lisp runtime compiling a function all write instructions as data and then execute them. Without `ICINV` they are unimplementable, which would be a hole on a machine whose section 6.3 goes out of its way to support Lisp runtimes. It is not privileged, for that reason (manual 6.2.6).

**Broadcast `TLBI` rather than software shootdown.** When one core unmaps a page, the others' TLBs must be invalidated. x86 does this with an inter-processor interrupt and a software handshake, which is slow and intricate. ARMv8 made `TLBI` broadcast by default, and for two to four cores that is both simpler in hardware and far faster. `TLBSYNC` is the completion barrier, because a broadcast that you cannot wait for is useless.

**`WFE`/`SEV` rather than a spin hint.** x86's `PAUSE` tells a spinning core to back off; ARM's `WFE` lets it actually stop until `SEV` or an interrupt arrives. The latter is better on an FPGA, where a spinning core is consuming memory bandwidth the other cores want. `WAIT` is accepted as an assembler alias for `WFE`, which serves as the uniprocessor idle. (`HINT #1` is the spin-wait pause.)

The atomics are already sufficient — `CAS`, `LL`/`SC`, the fetch-and-op family, and the `_DB` barrier-fused forms. Nothing more is needed there, and `_DB` was taken from LoongArch precisely because a lock acquire should be one instruction.

### 17.3 Cache coherence is a cache question, not an ISA question

For the four cores of the first device on one FPGA: **snooping MSI.** Three states, a snoop port on each D-cache, perhaps 500 LUTs and a state machine. MESI adds an Exclusive state to avoid a bus transaction when writing a clean line held by nobody else; at this core count the benefit is small and the state machine is meaningfully larger. Directory-based coherence scales further and is not needed below about eight cores. The design supports at least four cores and sixteen or more is the preferred ceiling that no decision may preclude (manual 7.6.3; the protocol beyond four cores is open, J.7.2 and J.9.11).

The important property is that **coherence is transparent to software**. Software-managed coherence — explicit flush and invalidate around every shared access — is cheaper in hardware and is where concurrency bugs go to live, because every missing flush is a race that reproduces once a week. The ISA owes nothing to a transparent coherence protocol, which is the correct division.

**Device DMA is the opposite case and gets the opposite answer.** An accelerator writing results the CPU has cached is also a coherence problem, but snooping the DMA path is expensive and the access pattern is known: large, infrequent, with an explicit handoff. Mapping those buffers uncached (section 8.2) and fencing at the doorbell costs nothing. So: transparent coherence between CPUs, explicit uncached mapping for accelerators. Two mechanisms, each where it is cheap.

### 17.4 What falls out for free, and what must be built

Already present without having been designed for it:

- **`DP` is the per-CPU pointer.** The direct page register has three mode-switched copies (section 2.2), so in kernel mode it can address the per-CPU structure in one instruction. A fast per-CPU base is something every SMP kernel builds by hand; here it is a register that already exists for an unrelated reason.
- **`ASID`** (section 8.1) already makes the context switch constant-time, which matters more with more cores competing for the TLB.
- **`G`-bit entries and the direct-mapping windows** (section 8.3) keep the kernel's own mappings out of the shootdown path entirely, since a global or window-mapped page is never invalidated by an address-space change.

To be built, device-side rather than in the ISA: an inter-processor interrupt path (decided as a need; how an interrupt reaches a core is open, J.6.3), a boot protocol for releasing secondary cores from reset (always used, since a system has at least four cores, errata 92; the mechanism is open, J.4.6; [`boot.md`](boot.md)), and a shared L2 or at minimum a coherent interconnect.

### 17.5 Explicitly avoided

| Avoided | Reason |
|---|---|
| **Weak or relaxed memory ordering** | section 17.1. Nothing to gain without speculation, and the cost to software is permanent |
| **Speculative execution** | not in the design point of the first implementations; also no Spectre-class channels |
| **Hardware transactional memory** | Intel TSX produced a decade of errata and side channels for a feature few programs used. `CAS` and `LL`/`SC` suffice |
| **Software-managed cache coherence between CPUs** | cheaper in hardware, and the bugs are races that reproduce weekly |
| **Coherent instruction caches** | a snoop port for a rare event; `ICINV` makes the rare event expressible instead |
| **IPI-based TLB shootdown as the primary mechanism** | broadcast `TLBI` is simpler and faster below eight cores. IPIs remain for scheduling |
| **A memory-model-dependent ABI** | with SC there is nothing for the ABI to say about ordering, which is the point |

### 17.6 The atomics against the bus: settled

The question this section used to leave open — the Unibus `DATIP`/`DATO` locked read-modify-write is a *lock*, while the exclusive access of the FPGA's memory fabric is a *monitor*, and the two are not the same primitive — was decided: the atomics are defined on a **monitor** (a reservation that a write by any initiator clears), and the locked pair is not an architectural primitive (errata 45; manual 2.10 and 7.4). What remains is what an atomic does on uncached and device memory (J.7.4).

---

## 18. Glossary

Terms used in this document. The manual's glossary is [appendix C](manual/appendix-c-glossary.md).

| Term | Meaning |
|---|---|
| **parcel** | a 16-bit unit of instruction encoding. Instructions are 1–3 parcels (section 3.1) |
| **prefix**, **prefix code** | the top 3 to 16 bits of the first parcel; a set of bit strings none of which begins another, so the first parcel selects at most one leaf (section 3.1) |
| **leaf**, **form** | a group of mnemonics that share one layout; a form lists the operand shapes, and the leaf fixes where every field lies (section 3.1) |
| **hot register** | one of the registers a short register field indexes (section 2.1); the table is part of the ABI |
| **`MOVQL`** | the ten-byte move of a 64-bit literal (section 4.1) |
| **`CBCC`** | compare and branch on condition, writing no flags (section 4.4) |
| **fused pair** | `MOVCALL`, `POPRET`, `POPMRET`, `MOV2`: two instructions the compiler emits adjacently, made one (section 4.4) |
| **`FPSR`** | the sticky five-bit floating-point exception flag register, read and written by `FSFLAGS` (section 4.9.1) |
| **`DMW`** | direct mapping window — a region translated as `PA = VA − base + physbase` with no page table reference (section 8.3; format deferred) |
| **`ASID`** | address space identifier, tagging TLB entries so a context switch flushes nothing (section 8.1) |
| **`MT`** | memory type, a two-bit page attribute selecting cached, uncached or device ordering (section 8.2) |
| **`lowtag`** | a type tag stored in the low bits of a pointer, available because quad-aligned objects have zero there (section 6.2) |
| **`DATIP` / `DATO`** | Unibus and Q-bus transaction types: data-in-pause and data-out, which together form a locked read-modify-write. Not architectural here; the atomics are monitor-based (section 17.6) |
| **SWAR** | **S**IMD **W**ithin **A** **R**egister: using one wide scalar register as several narrow lanes through masking and carry-aware arithmetic. The classic case is finding a zero byte in a 64-bit word with `(x − 0x0101010101010101) & ~x & 0x8080808080808080`. It is how byte-parallel work is done without a vector unit, and section 4.6's bit operations plus 64-bit registers make it effective here. The reference is Warren's *Hacker's Delight*; glibc's `strlen` is the canonical production example |
| **block floating point** | representing a vector as integer mantissas sharing one exponent. Used by the LB64 design (proposed) to make fixed-point accumulation exact, and the reason it needs no floating-point adders |
| **Payne–Hanek** | the argument-reduction algorithm that computes x mod π/2 to full precision for large x, using as many bits of π as the exponent requires. The thing hardware transcendentals cannot do (section 9.7.1) |
| **Table Maker's Dilemma** | that correctly rounding a transcendental function may require unboundedly many intermediate bits to resolve a near-tie, so no fixed-time circuit can guarantee it (section 9.7.1) |
| **ulp** | unit in the last place: the spacing between adjacent representable floating-point numbers, the unit in which rounding error is measured |

---

## 19. Position-independent code

Short answer: **yes, and cheaply — the architecture is in the x86-64 and AArch64 class rather than the i386 class.** PIE is a useful check because it exercises the features the design prunes (deferred modes and a writable `PC`); `JMPI` (section 4.8.1) closes the one gap. The manual's statement is section 9.16.

### 19.1 The requirements, checked

| Requirement | Mechanism | Cost |
|---|---|---|
| intra-module branches | PC-relative by construction (section 4.4) | native, 2–6 bytes |
| intra-module calls | `CALL d(PC)` | one instruction |
| module-local data | the PC-relative mode, `d(PC)` | one instruction |
| address formation | `LEA d(PC), Rn`, 32-bit in its six-byte form | one instruction |
| **GOT access** | `MOVQ got_slot(PC), Rd` | **one instruction, no GOT register** |
| **PLT stub** | `JMPI got_slot(PC)` | **one instruction, no scratch register** (section 4.8.1) |
| TLS, local-exec | `MOVQ d(DP), Rd` (section 19.3) | one instruction |
| load-time relocations | loader concern | unaffected |

**The decisive item is the GOT.** On i386, PIE reserved `%ebx` — one of eight registers — to hold the GOT base, and every function prologue had to establish it. That is why i386 PIE cost a measurable few percent in both size and speed. x86-64 fixed it with RIP-relative addressing: the GOT entry is reached directly from the program counter, so no register is reserved and no prologue code is needed.

**The pdp64 has that**, because the PC-relative mode is an ordinary addressing mode available to every instruction rather than a special case. `MOVQ got_slot(PC), Rd` loads an imported symbol's address in one instruction. No GOT pointer, no prologue, no reserved register.

### 19.2 PIE code can be *smaller* than non-PIE here

This inverts the usual expectation for small displacements and follows from the way the displacement grows with the length (section 3.4).

| Access to a global | Bytes |
|---|---|
| non-PIE, absolute (32-bit absolute address) | **6** |
| PIE, PC-relative, within ±32 KiB (16-bit byte displacement) | **4** |
| PIE, PC-relative, within ±2 GiB (32-bit byte displacement) | **6** |

An absolute address reaches only what a sign-extended 32-bit value can hold; PC-relative access within ±2 GiB needs no more bytes than that. **Position-independent data access is never longer than absolute**, per access, and is two bytes shorter within ±32 KiB: the opposite of the i386 experience, and a consequence of the variable-length encoding.

### 19.3 Thread-local storage

`DP` in user mode is the thread pointer (section 2.2), which makes the common TLS model one instruction:

```
        MOVQ    tls_offset(DP), R0      ; local-exec TLS, 6 bytes
```

(The `d(DP)` form is a three-parcel load with a 28-bit displacement, so six bytes; a short form and a store through `d(DP)` are open, J.9.5.) That is one instruction, as good as AArch64's `TPIDR_EL0` form and better than x86-64's, which needs a segment prefix. The other TLS models — initial-exec, local-dynamic, general-dynamic — need GOT entries and in the dynamic cases a `__tls_get_addr` call, exactly as elsewhere; nothing in the ISA makes them harder.

`DP` is the 6502 zero page's descendant, kept for code density, and its mode-switched copies are what a threaded runtime wants in user mode and an SMP kernel wants in kernel mode.

### 19.4 No veneers below 4 GiB

A conditional or unconditional branch in its six-byte form reaches ±4 GiB (section 4.4). AArch64's `BL` spans ±128 MB and large binaries therefore need linker-inserted veneers; ARM32's ±32 MB made them routine. **The pdp64 needs none below a binary of 4 GiB**, so branch-range veneer insertion — a persistent source of linker complexity and of surprising code growth — does not exist as a problem.

The assembler's branch relaxation reduces to choosing a length, and the linker's to the same ([`relaxation.md`](relaxation.md)).

### 19.5 What the ABI decides

The ISA is sufficient; three ABI questions belong in the ABI document ([`abi.md`](abi.md), manual appendix D, version 1), whose answers are noted below.

1. **A designated linker-scratch register — decided: `R12` (ABI version 1).** ARM32 reserves `R12`/`IP` and AArch64 `X16`/`X17` for veneers and PLT sequences. Pressure here is much lower — section 19.4 removes veneers for any binary below 4 GiB and `JMPI` removes the PLT's need for one — but linkers want a scratch register for lazy-binding resolver sequences and for `-fno-plt` call sites. `R12` is the natural choice, both because it is a register with no other role and because the number happens to match ARM32's convention.
2. **Lazy versus eager binding** (open; J.D.2). `JMPI got(PC)` makes a PLT stub one instruction, so the argument for lazy binding — avoiding resolver work for uncalled functions — is weaker than usual, while full RELRO with eager binding gets a security benefit. Worth measuring startup cost before choosing.
3. **Whether `-fno-plt` should be the default** (decided in ABI version 1: imports are called through `CALLI got(PC)`, i.e. without a PLT stub). Calling through `CALLI got(PC)` at the call site skips the PLT stub's extra transfer entirely, at the cost of a GOT load per call site rather than per function. One instruction either way, so this is a cache-behaviour question, not an instruction-count one.

### 19.6 Summary

Nothing about position-independent code is expensive on this architecture, and one aspect of it is cheaper than the position-dependent alternative. The three things that make it so were all adopted for unrelated reasons:

- **PC-relative addressing as an ordinary mode** (section 5), adopted because the program counter left the register file and the forms had to go somewhere — which turned out to be strictly better than a dedicated GOT register.
- **Variable-length encoding** (section 3.1), adopted for density, which makes a short PC-relative displacement cheaper than a long absolute address.
- **`DP`** (section 2.2), adopted for code density in 1970s terms, which is the thread pointer.

Indirect transfer through memory, for PLT stubs and vtables, is the one thing the removal of deferred modes in section 5.2 costs, and section 4.8.1 provides it as a contained exception.
