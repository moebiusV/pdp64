# 9. The instruction set

[← manual index](00-index.md)

**The instruction set is built around one idea: the length of an instruction is known from its first two bits, so the cheapest instructions are two bytes and nothing is longer than six.** The chapter covers how the 64 opcodes are divided, the properties and principles that hold throughout, the registers, the format and the addressing modes, each group of instructions, faults, restart and memory management, position-independent code, what is rejected, the idioms of the PDP-11 and VAX that are restored, lost or replaced, the comparison with the PDP-11 and VAX, what is taken from LoongArch, and what is open. Every instruction has its entry (syntax, encoding drawing, operation, flags, exceptions) in the section of its group below; the atomic instructions are in section 7.12 and the system instructions in section 6.7; the [reference tables](dictionary/index.md) hold the second page, the aliases, the constants and the lists of mnemonics and opcodes. The full text with every encoding is [`../pdp64-isa.md`](../../pdp64-isa.md); every number here comes from the grammars that the tools are generated from.

## 9.1 How the opcode space is divided

**9.1.1** Every instruction begins with a 16-bit parcel with four fields: `len` (2 bits), `opcode` (6 bits), `reg` (4 bits) and `mode` or `rm` (4 bits).

![The first parcel of every instruction](figures/format-parcel0.svg)

**9.1.2** There are 64 opcodes on the first page. An operation gets a top-level opcode if its common case is register to register, because only then can it be two bytes; every other operation lives in an escape group and costs nothing for it.

**9.1.3** Six escape groups, `001100 (0x0C)` to `010001 (0x11)`, read a sub-opcode from the second parcel: `BESC` (bits, fields, rotates, UTF-8), `MBLK` (block memory), `AESC` (divide, remainder, absolute, minimum, maximum, set), `MESC` (unaligned access, ALU to memory), `FESC` (fused multiply-add, binary32 and binary16, divide, square root, classify) and `ATOM` (atomics).

**9.1.4** Three groups, `010010 (0x12)` to `010100 (0x14)`, take their sub-opcode from the register field: `XFER` (indirect jump and call, tag dispatch), `SOP` (single-operand instructions, jump, call, push, pop) and `SYS` (system control).

**9.1.5** Every other run of opcodes is one kind, and its low bits select the operation directly: twelve moves (`000000 (0x00)`-`001011 (0x0B)`), thirteen ALU operations (`010110 (0x16)`-`100010 (0x22)`), four floating-point operations (`100100 (0x24)`-`100111 (0x27)`), three compare-and-branch forms (`101000 (0x28)`-`101010 (0x2A)`) and sixteen branches (`110000 (0x30)`-`111111 (0x3F)`).

**9.1.6** Fifty-eight of the sixty-four opcodes are assigned, one ALU slot (`100011 (0x23)`) is spare and five (`101011 (0x2B)`-`101111 (0x2F)`) are reserved.

**9.1.7** When `len` is `11`, the instruction is a single parcel from a second page of 64 opcodes, 45 defined and 19 reserved, each an exact abbreviation of a first-page instruction.

*Commentary.* **Precedent.** The PDP-11 partitioned its opcodes by the addressing modes of the first word; the VAX by operand specifiers parsed in sequence; x86 by prefixes, opcode, ModR/M and SIB read one after another. Each step down that list costs more front-end logic before the address of the next instruction is known. **Trade-offs.** Putting an operation in an escape group makes its shortest form four bytes, since the sub-opcode lives in the second parcel, so the allocation is a frequency sort, and five groups sit in escapes for that reason (divide and remainder, rotate by a register count, floating-point divide and square root, and the read-modify-write memory forms), where the cost is nothing or almost nothing. **Improvements.** The six second-parcel escapes sit together so that "read a sub-opcode" is one range comparison on bits 13 to 8; the three register-field escapes sit together so that one range compare enables the mux that already feeds the register file's address inputs; the other runs are contiguous so their low bits are wired straight to the function selects. **Benefits.** The decoder is a few comparators and wires, and a new instruction usually costs a sub-opcode, not an opcode. **Modern comparables.** RISC-V groups its major opcodes by format and AArch64 by top-level encoding class; the pdp64 groups by the one property that matters most to its front end, whether the sub-opcode needs the second parcel. **Impact.** *Kernel:* Nothing in the kernel depends on the opcode map except the privileged group, which sits in one place. *Compiler:* The instruction selector gets the two-byte form for every register-to-register operation and must charge four bytes for anything in an escape group, which its cost model has to know. *Hardware:* The decoder is a few range comparisons and wires: six escape groups are one compare on bits 13 to 8, three register-field escapes are one compare that enables a mux already feeding the register file, and every run's low bits go straight to its function select.

## 9.2 Properties and principles

**9.2.1** The length of an instruction is a function of its `len` field alone: 0, 1 or 2 extension parcels, for 2, 4 or 6 bytes. *(D)*

**9.2.2** At most one operand of an instruction may be a memory reference; the other, where present, is a register. The block operations are the one admitted exception. *(D)*

**9.2.3** No instruction is longer than six bytes. *(D)*

**9.2.4** A register is always written in full: narrow loads sign- or zero-extend, and there is no partial-register write. *(D)*

**9.2.5** Anything that changes what an instruction means is, by default, visible state set by an instruction that names it, not hidden state; whether a mode bit is worth its cost is decided case by case (errata 83). Compatibility is by conversion instructions where that is cheap. *(D)*

**9.2.6** Every instruction can be restarted after a fault, and exceptions are precise; the machine has no hidden instruction state. *(D)*

**9.2.7** Floating point is done in the general registers; there is no separate floating-point register file. *(D)*

**9.2.8** Memory is sequentially consistent between processors. *(D)*

**9.2.9** The ALU has one width, 64 bits; sizes appear only on loads, stores and conversions. *(D)*

**9.2.10** Addresses are canonical: 39, 48 or 57 bits of virtual address, according to the three, four or five levels of the page table (6.4.1), and a physical address of 40 to 64 bits, 40 in the present implementation (2.3.6). *(D)*

**9.2.11** Instructions are aligned to two bytes; quad data accesses are naturally aligned, and the explicit unaligned forms exist for the cases that need them. *(D)*

**9.2.12** An instruction does what its name says and nothing else; no flag is set that its entry does not list. *(D)*

*Commentary.* **Precedent.** 9.2.2 is x86's ModR/M idea made architectural; it is also what lets the exception machinery be small (the PDP-11 recorded at most two register side effects per instruction because it had two specifiers; with one memory operand there is at most one). 9.2.6 exists because the Motorola 68000, which was very nearly this machine, could not restart an instruction after a bus error and so could not do demand paging until its successor retrofitted a fault model. 9.2.4 is the rule x86-64 adopted for 32-bit writes and failed to apply to the 8- and 16-bit forms. 9.2.7 is the arrangement RISC-V standardised as Zfinx. **Trade-offs.** 9.2.9 means narrow arithmetic is done wide and converted, which costs an extension instruction after some narrow operations; whether that cost is large enough to justify 32-bit forms of add and subtract is an open question that the compiled corpus can answer (appendix B). 9.2.8 is the cheapest model on a small in-order core and the most expensive on a large speculative one. 9.2.10 lets the page table have three levels, as RISC-V's Sv39 does, or four or five as x86-64, AArch64 and Sv48 and Sv57 do, at a longer walk for each level. **Improvements.** The rules are soft defaults: each says what it protects and what breaking it costs. **Benefits.** Together they make the machine small, restartable and easy for a compiler; the measured code size is in chapter 1. **Modern comparables.** AArch64 and RISC-V have fixed-length register-to-register encodings and weak memory models; x86-64 has memory operands and total store order; the pdp64 takes memory operands, strong ordering and a bounded fault surface. **Impact.** *Kernel:* Restartable instructions and precise exceptions mean a page-fault handler repairs the mapping and returns, with no instruction-specific cases, and sequential consistency means no barrier code. *Compiler:* One memory operand keeps instruction selection and register allocation simple; a register written in full removes partial-register merges; the single ALU width costs an extension instruction after some narrow arithmetic. *Hardware:* One address generator, at most one register side effect, a single-entry undo buffer, no byte-lane multiplexing and a two-bit length are what keep the die small.

## 9.3 State: registers and flags

**9.3.1** There are sixteen 64-bit general registers, `R0` to `R15`. `R14` is the stack pointer `SP`, with three copies (kernel, supervisor, user) chosen by the current mode; `R13` is the frame pointer by convention only; the others carry no meaning to the hardware. *(D)*

**9.3.2** The program counter is not a general register, and `R7` is an ordinary general register, not a view of the program counter; the program counter is read with `LEA 0(PC), Rn`. *(D)*

**9.3.3** The processor status word is 16 bits. *(D)*

![The processor status word](figures/psw.svg)

(Bit positions as in System v1: `C` 0, `V` 1, `Z` 2, `N` 3, `T` 4, priority 5-7, current mode 8-9, previous mode 10-11, `UA` 12.)

**9.3.4** The flags form two groups, `C` and `{N, Z, V}`, and no instruction writes part of `{N, Z, V}` or writes it conditionally. Moves, loads, stores and the compare-and-branch instructions write no flags; shifts write the same flags for every count; rotates and the funnel shift write none; the by-one left shift sets `V` to `N` xor `C`. *(D)*

**9.3.5** `DP`, the direct-page base, has three copies by mode. It makes `d(DP)` the shortest address form (a 12-bit displacement in four bytes); in kernel mode it is the per-CPU pointer, and in user mode the thread pointer. *(D)*

**9.3.6** Other special registers: `FPSR` (five sticky floating-point flags), `ASID`, `PTBR`, `DMW0` and `DMW1`, `EPC`, `EPSW`, `EVA`, `ECAUSE`, `VBR`, `MMUCTL`; the system registers are read and written by `MFSR` and `MTSR` with an 8-bit register number. *(D)*

**9.3.7** A bit `DIT` in the status word (its position is unspecified) promises data-independent timing: while it is set no data-dependent timing effect of any kind remains, neither in instruction latency (divide, `MSCN`, `MCMP` and floating point included), nor in frequency or power management (a core that scales frequency holds it steady while the bit is set, or says in a feature register that it cannot), nor from any data-dependent prefetcher or value predictor (a core may have one, but it is off while the bit is set). User code may set it for its own use. *(D)*

*Commentary.* **Precedent.** The PDP-11's PC and SP were ordinary registers and its flags were set by nearly every instruction. The VAX put the PC in R15. **Trade-offs.** Keeping the PC out of the register file means a jump to a computed address uses `JMP`, not a write to a register, so that writing `SP` has no control-flow consequence and the hazard logic treats it like any other destination. Condition codes are kept (rather than a flagless design) because compare-and-branch and flag-setting arithmetic make for dense code; the flag rules make them cheap for an out-of-order implementation, because the compiled corpus shows that 68% of instructions write a flag and only 1.5% read one. **Improvements.** The status word carries a user-memory guard bit (9.14) and the per-mode `DP` serves two jobs, the per-CPU pointer in the kernel and the thread pointer in user mode. **Benefits.** An exception handler finds a kernel stack and a per-CPU pointer without first searching for them; a threaded program's thread-local variable is one instruction. **Modern comparables.** x86-64 keeps `FS` and `GS` base registers for the same two jobs; AArch64 has `TPIDR_EL0` and `TPIDR_EL1`; RISC-V uses `tp` and the supervisor scratch register. **Impact.** *Kernel:* Banked stack and direct-page registers let entry find a kernel stack and a per-CPU pointer with no code, and the status word is saved by one `PUSHX`. *Compiler:* The flag rules decide when a compare may fuse with its branch (1,893 pairs stay separate because a second branch reads the flags) and what the compiler may move between a compare and a branch. *Hardware:* Two flag groups need one or two rename targets, not one per bit; the register file is 16 by 64 with two read ports and one write (about 250 lookup tables of distributed memory); the banked copies are a three-way mux.

## 9.4 The instruction format

**9.4.1** The first parcel holds `len`, the opcode and two four-bit fields; `len` is the number of extension parcels (0, 1 or 2) when it is less than 3. *(D)*

![The extension parcels and the second page](figures/format-extension.svg)

**9.4.2** Instructions are parcel-aligned and little-endian; an instruction may cross any boundary of 8 bytes, a cache line or a page. *(D)*

**9.4.3** Most instructions are two or four bytes: register-to-register work and the whole conversion set is one parcel; any memory operand within ±2 KB is two; displacements to ±128 MB, 32-bit immediates and branches to ±4 GB are three. *(D)*

**9.4.4** Where an addressing mode names no base register (immediate, absolute, PC-relative), the register nibble of the second parcel carries payload, so those modes reach 16 bits at four bytes and 32 bits at six. *(D)*

**9.4.5** A constant wider than 32 bits is loaded from a literal pool with `MOVQ =K, Rd`, written with an explicit `=`; nothing is pooled silently. *(D)*

*Commentary.* **Precedent.** The PDP-11 had the length in the first word, but as a function of both of its six-bit specifiers; UTF-8 made "the leading unit says how long" famous, but what matters here is that length is the *primary* partition, so the payload is budgeted by what each form needs and not carved from a fixed width. **Trade-offs.** Byte-granular encoding, as in x86, buys perhaps a tenth of the code size and costs a full alignment rotator and cross-line splice logic in the fetch path on a 64-bit datapath; the pdp64 refuses it. Forcing an instruction to stay inside an eight-byte window would simplify fetch and would cost 5% to 10% of code size in padding. **Improvements.** The `len` code `11` selects a second page of one-parcel abbreviations; the measured average is near three bytes per instruction. **Benefits.** The front end is a two-bit counter, a two-deep parcel buffer and no feedback. **Modern comparables.** Thumb-2 and RISC-V's compressed instructions mix 16- and 32-bit forms too, with the length read from the low bits. **Impact.** *Kernel:* Page-2 forms make kernel text smaller with no source change. *Compiler:* The assembler picks the shortest form, branch relaxation is a length choice, and the cost model knows only 2, 4 and 6 bytes. *Hardware:* The fetch unit is a two-bit down-counter and a two-deep parcel buffer with no feedback.

## 9.5 Addressing modes

**9.5.1** Four bits select one of eight modes, present at four bytes and longer. *(D)*

| Mode | Syntax | Effect |
|---|---|---|
| `0000` | `d(Rn)` | base plus displacement |
| `0001` | `d(Rn)(Rx*s)` | scaled index, `s` in {1, 2, 4, 8} |
| `0010` | `d(PC)` | PC-relative; the base is the first parcel of the instruction |
| `0011` | `d(DP)` | direct page |
| `0100` | `#imm` | immediate, sign-extended |
| `0101` | `@abs` | absolute, sign-extended |
| `0110` | `(Rn)+d` | post-increment by `d` (default: the operand size) |
| `0111` | `-(Rn)` or `(Rn)-d` | pre-decrement by the operand size, or by `d` |

**9.5.2** The deferred modes of the PDP-11 are removed; indirection is done with `JMPI`, `CALLI` and a load. *(D)*

**9.5.3** At most one register side effect occurs per instruction, and it is committed at retirement; a fault discards it. *(D)*

*Commentary.* **Precedent.** The PDP-11 had eight modes for each of eight registers, with a deferred flavour of each, and it made `*p++` and `*--p` single instructions. **Trade-offs.** Dropping the deferred modes removes the case where a fault occurs after a register has been updated at an address that itself came from a load; keeping the strided autoincrement costs nothing, because the undo information was already a delta (the PDP-11's `MMR1` recorded an amount for the same reason). **Improvements.** The increment is a stride, so walking an array of 16-byte records is one instruction; the PC-relative modes count from the instruction itself, so a branch needs no adjustment and `LEA` reads the PC. **Benefits.** Address generation is one adder pass, never load-then-add, which is the difference between one cycle and a long path on an FPGA. **Modern comparables.** AArch64 has pre- and post-indexed forms with an immediate; x86 has scaled index with a base; RISC-V has base plus immediate only. **Impact.** *Kernel:* A strided autoincrement walks a table of records, and `d(DP)` reaches the per-CPU structure in one instruction. *Compiler:* The modes match C idioms (`*p++`, `a[i]`) one-to-one, and dropping the deferred modes removes the cases the selector would otherwise have to consider. *Hardware:* Address generation is one adder pass, never load-then-add, and the PC-relative base is the first parcel, so no adjustment is needed.

## 9.6 Moves, conversions and address formation

<!-- notation -->
**The instructions.** Every instruction has an entry in the section of its group, laid out as in a processor reference manual: its mnemonics, its syntax, its encoding (a drawing of the parcels and the numbers), its operation in pseudocode, the flags it writes, the exceptions it can take, and where the manual explains the matter it touches (*Cf.*). Every instruction, the atomic and the system instructions included, has its official entry below (sections 9.13 and 9.14 for those two groups); the chapters on the kernel and on several processors give the reasons, and an entry may point back to them for a fuller explanation. In the pseudocode, ← is assignment, = and ≠ compare, × and ÷ multiply and divide, and `M[a]` is memory at address `a`. Numbers that are encodings (opcodes, sub-opcodes, field values) are written in binary with the hexadecimal value in brackets behind, as `010011 (0x13)`. Masks are binary too, with a subscript 2 to mark the base (`Rn & 111₂` keeps the low three bits). The entries are generated from `spec/pdp64-mnemonics.hbnf`, the one place where the numbers of the architecture are written, so an encoding here cannot disagree with the assembler or the simulators; the words (operation, flags, exceptions) are checked against the reference executor, `common/pdp64exec.c`, which `sim64` and QEMU share, and the Status line of each entry says whether the executor implements the instruction. The one-parcel second page, the aliases, the constants and the lists of the mnemonics and the opcodes are in the [reference tables](dictionary/index.md).

**The stories.** An instruction that is not common (the PDP-11 core and the operations every architecture has carry none) is followed by *Why it is here*: the machine the idea came from and the reason it was chosen, with the measurements that bear on it. Where no reason is recorded, the paragraph says so. The documents behind the paragraphs are listed in [appendix F](appendix-f-evidence.md).

**Notation.** `Rd` is the destination register (the `reg` field of parcel 0), `Rs` the first source (`low`), `Rt` the second (`t` of parcel 1), `Ru` the third (`x`); the assembler writes the destination last. `rm` is a general operand: a register at `len = 00`, or a memory operand, an immediate or an absolute address by one of the eight addressing modes (section 9.5). `EA(rm)` is its effective address. `M[a]` is memory, `M8[a]` one byte. `sext` and `zext` sign- and zero-extend. A `len = 01` instruction is two parcels (four bytes) and a `len = 10` instruction three (six bytes); `len = 11` is page 2. `N Z V C` are the condition flags. In the drawings the bits of a parcel are numbered from 15 at the left, a shaded box is a fixed value, and a white box is a field that varies.
<!-- /notation -->

*Cf. section 6.4 for the memory types that decide whether an access is cached, and section 6.8 for what a faulting load leaves behind.*

**9.6.1** `MOVQ`, `MOVL`, `MOVW` and `MOVB` load and store 64, 32, 16 and 8 bits; the loads sign-extend. `MOVZL`, `MOVZW` and `MOVZB` load with zero extension. *(opcodes `000000 (0x00)`-`001010 (0x0A)`)*

**9.6.2** With a register operand, the same opcodes are the conversion set: `MOVB R1, R2` sign-extends the low byte, `MOVZW R1, R2` zero-extends the low word.

**9.6.3** `LEA` forms an effective address; `LEA 0(PC), Rn` reads the program counter. *(opcode `001011 (0x0B)`)*

**9.6.4** Moves, loads and stores write no flags. *(D)*

**9.6.5** The explicit unaligned forms `MOVUB`, `MOVUW`, `MOVUL` and `MOVUQ` exist in both directions, in the memory escape. *(D)*

**9.6.6** Page 2 abbreviates the common cases to one parcel: loads and stores through `(rn)`, loads and stores at small offsets from `SP`, `LEA` from `SP`, and `MOVQ #imm, rd` with a four-bit immediate. *(D)*

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

![Encoding of MOV](figures/r20-mem-0.svg)

The chart is the layout `r20-mem-0`, Moves, address formation and the ALU, one parcel (`len = 00`): `reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `MOVQ` | `000000 (0x00)`, `000001 (0x01)` |
| `MOVL` | `000010 (0x02)`, `000011 (0x03)` |
| `MOVW` | `000100 (0x04)`, `000101 (0x05)` |
| `MOVB` | `000110 (0x06)`, `000111 (0x07)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-mem-0`](dictionary/by-encoding.md#r20-mem-0), [`r20-mem-1`](dictionary/by-encoding.md#r20-mem-1), [`r20-mem-1-2`](dictionary/by-encoding.md#r20-mem-1-2), [`r20-mem-1-3`](dictionary/by-encoding.md#r20-mem-1-3), [`r20-mem-1-4`](dictionary/by-encoding.md#r20-mem-1-4), [`r20-mem-2`](dictionary/by-encoding.md#r20-mem-2), [`r20-mem-2-2`](dictionary/by-encoding.md#r20-mem-2-2), [`r20-mem-2-3`](dictionary/by-encoding.md#r20-mem-2-3), [`r20-mem-2-4`](dictionary/by-encoding.md#r20-mem-2-4).

**Operation**

```
size = 8 (MOVQ), 4 (MOVL), 2 (MOVW) or 1 (MOVB) bytes
load :  Rd ← sext(M[EA(rm)], size)          ; len = 00: Rd ← sext(Rs[8×size-1:0])
store:  M[EA(rm)] ← Rs[8×size-1:0]          ; len = 00: Rd ← sext(Rs[8×size-1:0])
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

A register is always written in full: a narrow load sign-extends to 64 bits and there is no partial-register write anywhere. At `len = 00` the same opcodes are the conversion set: `MOVB R1, R2` sign-extends the low byte of `R1` into `R2`. Page 2 abbreviates the loads and stores through `(rn)`, at small offsets from `SP` and from a register, and `MOVQ #imm, rd` with a 4-bit immediate (see the page-2 table).

**Cf.** 6.4 for the memory type that decides whether the access is cached; 6.8 for what a faulting access leaves behind.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-movq"></a>
#### MOVQ

![MOVQ, opcode 000000, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/movq/06.svg)

![MOVQ, opcode 000000, three parcels (modes index) (6 bytes)](figures/w/movq/07.svg)

![MOVQ, opcode 000000, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/movq/08.svg)

![MOVQ, opcode 000000, three parcels (modes dp) (6 bytes)](figures/w/movq/09.svg)

![MOVQ, opcode 000001, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/movq/15.svg)

![MOVQ, opcode 000001, three parcels (modes index) (6 bytes)](figures/w/movq/16.svg)

![MOVQ, opcode 000001, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/movq/17.svg)

![MOVQ, opcode 000001, three parcels (modes dp) (6 bytes)](figures/w/movq/18.svg)

![MOVQ, opcode 000000, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/movq/02.svg)

![MOVQ, opcode 000000, two parcels (modes index) (4 bytes)](figures/w/movq/03.svg)

![MOVQ, opcode 000000, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/movq/04.svg)

![MOVQ, opcode 000000, two parcels (modes dp) (4 bytes)](figures/w/movq/05.svg)

![MOVQ, opcode 000001, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/movq/11.svg)

![MOVQ, opcode 000001, two parcels (modes index) (4 bytes)](figures/w/movq/12.svg)

![MOVQ, opcode 000001, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/movq/13.svg)

![MOVQ, opcode 000001, two parcels (modes dp) (4 bytes)](figures/w/movq/14.svg)

![MOVQ, opcode 000000, one parcel (2 bytes)](figures/w/movq/01.svg)

![MOVQ, opcode 000001, one parcel (2 bytes)](figures/w/movq/10.svg)

```
MOVQ rm, Rd
MOVQ Rs, rm
```

| Mnemonic | Opcode |
|---|---|
| `MOVQ` | `000000 (0x00)`, `000001 (0x01)` |

Operation, flags and exceptions as for the entry MOV above; 18 layout forms, each a chart of its own (above).

<a id="w-movl"></a>
#### MOVL

![MOVL, opcode 000010, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/movl/06.svg)

![MOVL, opcode 000010, three parcels (modes index) (6 bytes)](figures/w/movl/07.svg)

![MOVL, opcode 000010, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/movl/08.svg)

![MOVL, opcode 000010, three parcels (modes dp) (6 bytes)](figures/w/movl/09.svg)

![MOVL, opcode 000011, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/movl/15.svg)

![MOVL, opcode 000011, three parcels (modes index) (6 bytes)](figures/w/movl/16.svg)

![MOVL, opcode 000011, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/movl/17.svg)

![MOVL, opcode 000011, three parcels (modes dp) (6 bytes)](figures/w/movl/18.svg)

![MOVL, opcode 000010, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/movl/02.svg)

![MOVL, opcode 000010, two parcels (modes index) (4 bytes)](figures/w/movl/03.svg)

![MOVL, opcode 000010, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/movl/04.svg)

![MOVL, opcode 000010, two parcels (modes dp) (4 bytes)](figures/w/movl/05.svg)

![MOVL, opcode 000011, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/movl/11.svg)

![MOVL, opcode 000011, two parcels (modes index) (4 bytes)](figures/w/movl/12.svg)

![MOVL, opcode 000011, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/movl/13.svg)

![MOVL, opcode 000011, two parcels (modes dp) (4 bytes)](figures/w/movl/14.svg)

![MOVL, opcode 000010, one parcel (2 bytes)](figures/w/movl/01.svg)

![MOVL, opcode 000011, one parcel (2 bytes)](figures/w/movl/10.svg)

```
MOVL, MOVW, MOVB likewise
```

| Mnemonic | Opcode |
|---|---|
| `MOVL` | `000010 (0x02)`, `000011 (0x03)` |

Operation, flags and exceptions as for the entry MOV above; 18 layout forms, each a chart of its own (above).

<a id="w-movw"></a>
#### MOVW

![MOVW, opcode 000100, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/movw/06.svg)

![MOVW, opcode 000100, three parcels (modes index) (6 bytes)](figures/w/movw/07.svg)

![MOVW, opcode 000100, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/movw/08.svg)

![MOVW, opcode 000100, three parcels (modes dp) (6 bytes)](figures/w/movw/09.svg)

![MOVW, opcode 000101, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/movw/15.svg)

![MOVW, opcode 000101, three parcels (modes index) (6 bytes)](figures/w/movw/16.svg)

![MOVW, opcode 000101, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/movw/17.svg)

![MOVW, opcode 000101, three parcels (modes dp) (6 bytes)](figures/w/movw/18.svg)

![MOVW, opcode 000100, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/movw/02.svg)

![MOVW, opcode 000100, two parcels (modes index) (4 bytes)](figures/w/movw/03.svg)

![MOVW, opcode 000100, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/movw/04.svg)

![MOVW, opcode 000100, two parcels (modes dp) (4 bytes)](figures/w/movw/05.svg)

![MOVW, opcode 000101, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/movw/11.svg)

![MOVW, opcode 000101, two parcels (modes index) (4 bytes)](figures/w/movw/12.svg)

![MOVW, opcode 000101, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/movw/13.svg)

![MOVW, opcode 000101, two parcels (modes dp) (4 bytes)](figures/w/movw/14.svg)

![MOVW, opcode 000100, one parcel (2 bytes)](figures/w/movw/01.svg)

![MOVW, opcode 000101, one parcel (2 bytes)](figures/w/movw/10.svg)

| Mnemonic | Opcode |
|---|---|
| `MOVW` | `000100 (0x04)`, `000101 (0x05)` |

Operation, flags and exceptions as for the entry MOV above; 18 layout forms, each a chart of its own (above).

<a id="w-movb"></a>
#### MOVB

![MOVB, opcode 000110, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/movb/06.svg)

![MOVB, opcode 000110, three parcels (modes index) (6 bytes)](figures/w/movb/07.svg)

![MOVB, opcode 000110, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/movb/08.svg)

![MOVB, opcode 000110, three parcels (modes dp) (6 bytes)](figures/w/movb/09.svg)

![MOVB, opcode 000111, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/movb/15.svg)

![MOVB, opcode 000111, three parcels (modes index) (6 bytes)](figures/w/movb/16.svg)

![MOVB, opcode 000111, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/movb/17.svg)

![MOVB, opcode 000111, three parcels (modes dp) (6 bytes)](figures/w/movb/18.svg)

![MOVB, opcode 000110, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/movb/02.svg)

![MOVB, opcode 000110, two parcels (modes index) (4 bytes)](figures/w/movb/03.svg)

![MOVB, opcode 000110, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/movb/04.svg)

![MOVB, opcode 000110, two parcels (modes dp) (4 bytes)](figures/w/movb/05.svg)

![MOVB, opcode 000111, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/movb/11.svg)

![MOVB, opcode 000111, two parcels (modes index) (4 bytes)](figures/w/movb/12.svg)

![MOVB, opcode 000111, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/movb/13.svg)

![MOVB, opcode 000111, two parcels (modes dp) (4 bytes)](figures/w/movb/14.svg)

![MOVB, opcode 000110, one parcel (2 bytes)](figures/w/movb/01.svg)

![MOVB, opcode 000111, one parcel (2 bytes)](figures/w/movb/10.svg)

| Mnemonic | Opcode |
|---|---|
| `MOVB` | `000110 (0x06)`, `000111 (0x07)` |

Operation, flags and exceptions as for the entry MOV above; 18 layout forms, each a chart of its own (above).


### MOVZ: Move zero-extended (32, 16 and 8 bits)

**Mnemonics:** `MOVZL`, `MOVZW`, `MOVZB`

**Syntax**

```
MOVZL rm, Rd
MOVZW rm, Rd
MOVZB rm, Rd
```

**Encoding**

![Encoding of MOVZ](figures/r20-mem-0.svg)

The chart is the layout `r20-mem-0`, Moves, address formation and the ALU, one parcel (`len = 00`): `reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `MOVZL` | `001000 (0x08)` |
| `MOVZW` | `001001 (0x09)` |
| `MOVZB` | `001010 (0x0A)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-mem-0`](dictionary/by-encoding.md#r20-mem-0), [`r20-mem-1`](dictionary/by-encoding.md#r20-mem-1), [`r20-mem-1-2`](dictionary/by-encoding.md#r20-mem-1-2), [`r20-mem-1-3`](dictionary/by-encoding.md#r20-mem-1-3), [`r20-mem-1-4`](dictionary/by-encoding.md#r20-mem-1-4), [`r20-mem-2`](dictionary/by-encoding.md#r20-mem-2), [`r20-mem-2-2`](dictionary/by-encoding.md#r20-mem-2-2), [`r20-mem-2-3`](dictionary/by-encoding.md#r20-mem-2-3), [`r20-mem-2-4`](dictionary/by-encoding.md#r20-mem-2-4).

**Operation**

```
Rd ← zext(M[EA(rm)], size)      ; len = 00: Rd ← zext(Rs[8×size-1:0])
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

There is no zero-extending 64-bit move (it would be `MOVQ`). At `len = 00` these are the zero-extending half of the conversion set.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-movzl"></a>
#### MOVZL

![MOVZL, opcode 001000, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/movzl/06.svg)

![MOVZL, opcode 001000, three parcels (modes index) (6 bytes)](figures/w/movzl/07.svg)

![MOVZL, opcode 001000, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/movzl/08.svg)

![MOVZL, opcode 001000, three parcels (modes dp) (6 bytes)](figures/w/movzl/09.svg)

![MOVZL, opcode 001000, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/movzl/02.svg)

![MOVZL, opcode 001000, two parcels (modes index) (4 bytes)](figures/w/movzl/03.svg)

![MOVZL, opcode 001000, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/movzl/04.svg)

![MOVZL, opcode 001000, two parcels (modes dp) (4 bytes)](figures/w/movzl/05.svg)

![MOVZL, opcode 001000, one parcel (2 bytes)](figures/w/movzl/01.svg)

```
MOVZL rm, Rd
```

| Mnemonic | Opcode |
|---|---|
| `MOVZL` | `001000 (0x08)` |

Operation, flags and exceptions as for the entry MOVZ above; 9 layout forms, each a chart of its own (above).

<a id="w-movzw"></a>
#### MOVZW

![MOVZW, opcode 001001, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/movzw/06.svg)

![MOVZW, opcode 001001, three parcels (modes index) (6 bytes)](figures/w/movzw/07.svg)

![MOVZW, opcode 001001, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/movzw/08.svg)

![MOVZW, opcode 001001, three parcels (modes dp) (6 bytes)](figures/w/movzw/09.svg)

![MOVZW, opcode 001001, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/movzw/02.svg)

![MOVZW, opcode 001001, two parcels (modes index) (4 bytes)](figures/w/movzw/03.svg)

![MOVZW, opcode 001001, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/movzw/04.svg)

![MOVZW, opcode 001001, two parcels (modes dp) (4 bytes)](figures/w/movzw/05.svg)

![MOVZW, opcode 001001, one parcel (2 bytes)](figures/w/movzw/01.svg)

```
MOVZW rm, Rd
```

| Mnemonic | Opcode |
|---|---|
| `MOVZW` | `001001 (0x09)` |

Operation, flags and exceptions as for the entry MOVZ above; 9 layout forms, each a chart of its own (above).

<a id="w-movzb"></a>
#### MOVZB

![MOVZB, opcode 001010, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/movzb/06.svg)

![MOVZB, opcode 001010, three parcels (modes index) (6 bytes)](figures/w/movzb/07.svg)

![MOVZB, opcode 001010, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/movzb/08.svg)

![MOVZB, opcode 001010, three parcels (modes dp) (6 bytes)](figures/w/movzb/09.svg)

![MOVZB, opcode 001010, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/movzb/02.svg)

![MOVZB, opcode 001010, two parcels (modes index) (4 bytes)](figures/w/movzb/03.svg)

![MOVZB, opcode 001010, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/movzb/04.svg)

![MOVZB, opcode 001010, two parcels (modes dp) (4 bytes)](figures/w/movzb/05.svg)

![MOVZB, opcode 001010, one parcel (2 bytes)](figures/w/movzb/01.svg)

```
MOVZB rm, Rd
```

| Mnemonic | Opcode |
|---|---|
| `MOVZB` | `001010 (0x0A)` |

Operation, flags and exceptions as for the entry MOVZ above; 9 layout forms, each a chart of its own (above).


<a id="w-lea"></a>
### LEA: Load effective address

![LEA, opcode 001011, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/lea/06.svg)

![LEA, opcode 001011, three parcels (modes index) (6 bytes)](figures/w/lea/07.svg)

![LEA, opcode 001011, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/lea/08.svg)

![LEA, opcode 001011, three parcels (modes dp) (6 bytes)](figures/w/lea/09.svg)

![LEA, opcode 001011, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/lea/02.svg)

![LEA, opcode 001011, two parcels (modes index) (4 bytes)](figures/w/lea/03.svg)

![LEA, opcode 001011, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/lea/04.svg)

![LEA, opcode 001011, two parcels (modes dp) (4 bytes)](figures/w/lea/05.svg)

![LEA, opcode 001011, one parcel (2 bytes)](figures/w/lea/01.svg)

**Mnemonics:** `LEA`

**Syntax**

```
LEA d(Rn), Rd
LEA d(PC), Rd
LEA d(Rn)(Rx×s), Rd
```

**Encoding**

![Encoding of LEA](figures/r20-mem-0.svg)

The chart is the layout `r20-mem-0`, Moves, address formation and the ALU, one parcel (`len = 00`): `reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `LEA` | `001011 (0x0B)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-mem-0`](dictionary/by-encoding.md#r20-mem-0), [`r20-mem-1`](dictionary/by-encoding.md#r20-mem-1), [`r20-mem-1-2`](dictionary/by-encoding.md#r20-mem-1-2), [`r20-mem-1-3`](dictionary/by-encoding.md#r20-mem-1-3), [`r20-mem-1-4`](dictionary/by-encoding.md#r20-mem-1-4), [`r20-mem-2`](dictionary/by-encoding.md#r20-mem-2), [`r20-mem-2-2`](dictionary/by-encoding.md#r20-mem-2-2), [`r20-mem-2-3`](dictionary/by-encoding.md#r20-mem-2-3), [`r20-mem-2-4`](dictionary/by-encoding.md#r20-mem-2-4).

**Operation**

```
Rd ← EA(rm)          ; no memory access
```

**Flags** None written.

**Exceptions** The operand must name memory; `len = 00` (a register) and the immediate mode are reserved. No memory access is made, so the instruction takes no memory fault. A reserved encoding aborts with the illegal-instruction vector.

`LEA 0(PC), Rd` is how the program counter is read: it puts the address of the `LEA` itself in `Rd`. At `len = 10` it forms any address within ±2 GB of itself PC-relatively in six bytes. The base of every PC-relative displacement is the address of the first parcel of the instruction.

**Why it is here.** The PDP-11 and the VAX made the program counter a register (R7, R15). Here the program counter is kept out of the register file, because every register write would then be a potential branch, and a read-only view of it (R7 as a view of the PC) is refused, because it would fix for ever *which* PC is meant (ARM32 is stuck with `PC+8`). `LEA 0(PC), Rn` gives the capability without the commitment: the address of the instruction itself, in one instruction. The same instruction forms any address PC-relatively, which is what makes position-independent code free (section 9.16).

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


### MOVU: Unaligned load and store

**Mnemonics:** `MOVUB`, `MOVUW`, `MOVUL`, `MOVUQ`

**Syntax**

```
MOVUQ rm, Rd        ; load, any alignment
MOVUQ Rs, rm        ; store, any alignment
MOVUW, MOVUL, MOVUB likewise
```

**Encoding**

![Encoding of MOVU](figures/r20-mesc-1.svg)

The chart is the layout `r20-mesc-1`, Memory escape (MESC), two parcels (`len = 01`): Addressing modes (`low`) that use this layout: `base` 0000, `index` 0001, `pcrel` 0010, `dp` 0011, `imm` 0100, `abs` 0101, `postinc` 0110, `predec` 0111. `low` of parcel 0 is an addressing mode; parcel 1 holds the sub-opcode, `rm` and the first 8 bits of the displacement.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MOVUB` | `001111 (0x0F)` | `0000 (0x0)` |
| `MOVUW` | `001111 (0x0F)` | `0010 (0x2)` |
| `MOVUL` | `001111 (0x0F)` | `0100 (0x4)` |
| `MOVUQ` | `001111 (0x0F)` | `0110 (0x6)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-mesc-1`](dictionary/by-encoding.md#r20-mesc-1), [`r20-mesc-2`](dictionary/by-encoding.md#r20-mesc-2).

**Operation**

```
size = 1, 2, 4 or 8 bytes
load :  Rd ← sext(M[EA(rm)], size)            ; the access may cross an alignment boundary
store:  M[EA(rm)] ← Rs[8×size-1:0]
```

**Flags** None written.

**Exceptions** Page and protection faults and bus errors as for any memory operand; **no alignment fault**.

The ordinary moves fault on a misaligned address (the alignment fault is the tag check of section 9.5); these are the explicit forms for data that is not aligned, in `MESC`.

**Why it is here.** Data alignment is architectural on this machine (9.2.11): an ordinary quad access to an address that is not a multiple of 8 aborts, and that abort doubles as the tag check for tagged pointers; a load form that ignores low pointer bits is rejected for that reason. Packed on-disk and network structures still need unaligned access, so `MESC` carries explicit unaligned forms rather than weakening the rule for every load. No further reason is recorded for these four.

**Cf.** 6.4, 6.8.

**Status** specified; **not yet implemented** in the reference executor.

<a id="w-movub"></a>
#### MOVUB

![MOVUB, opcode 001111, three parcels, sub-opcode 0000 (modes base, index, pcrel, dp, imm, abs, postinc, predec) (6 bytes)](figures/w/movub/02.svg)

![MOVUB, opcode 001111, two parcels, sub-opcode 0000 (modes base, index, pcrel, dp, imm, abs, postinc, predec) (4 bytes)](figures/w/movub/01.svg)

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MOVUB` | `001111 (0x0F)` | `0000 (0x0)` |

Operation, flags and exceptions as for the entry MOVU above; 2 layout forms, each a chart of its own (above).

<a id="w-movuw"></a>
#### MOVUW

![MOVUW, opcode 001111, three parcels, sub-opcode 0010 (modes base, index, pcrel, dp, imm, abs, postinc, predec) (6 bytes)](figures/w/movuw/02.svg)

![MOVUW, opcode 001111, two parcels, sub-opcode 0010 (modes base, index, pcrel, dp, imm, abs, postinc, predec) (4 bytes)](figures/w/movuw/01.svg)

```
MOVUW, MOVUL, MOVUB likewise
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MOVUW` | `001111 (0x0F)` | `0010 (0x2)` |

Operation, flags and exceptions as for the entry MOVU above; 2 layout forms, each a chart of its own (above).

<a id="w-movul"></a>
#### MOVUL

![MOVUL, opcode 001111, three parcels, sub-opcode 0100 (modes base, index, pcrel, dp, imm, abs, postinc, predec) (6 bytes)](figures/w/movul/02.svg)

![MOVUL, opcode 001111, two parcels, sub-opcode 0100 (modes base, index, pcrel, dp, imm, abs, postinc, predec) (4 bytes)](figures/w/movul/01.svg)

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MOVUL` | `001111 (0x0F)` | `0100 (0x4)` |

Operation, flags and exceptions as for the entry MOVU above; 2 layout forms, each a chart of its own (above).

<a id="w-movuq"></a>
#### MOVUQ

![MOVUQ, opcode 001111, three parcels, sub-opcode 0110 (modes base, index, pcrel, dp, imm, abs, postinc, predec) (6 bytes)](figures/w/movuq/02.svg)

![MOVUQ, opcode 001111, two parcels, sub-opcode 0110 (modes base, index, pcrel, dp, imm, abs, postinc, predec) (4 bytes)](figures/w/movuq/01.svg)

```
MOVUQ rm, Rd
MOVUQ Rs, rm
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MOVUQ` | `001111 (0x0F)` | `0110 (0x6)` |

Operation, flags and exceptions as for the entry MOVU above; 2 layout forms, each a chart of its own (above).
<!-- /entries:9.6 -->

## 9.7 Integer arithmetic

*Cf. section 6.2 for the divide-by-zero vector (`DIV`, `DIVU`, `MOD`, `MODU`).*

**9.7.1** `ADD`, `SUB`, `CMP`, `MUL` and `MULH` are two bytes with register operands; `MULHU` (high half of an unsigned product), `DIV`, `DIVU`, `MOD` and `MODU` are in the arithmetic escape. *(D)*

**9.7.2** `CMP` is written `CMP Rd, rm`, register first, and computes `Rd - rm`. *(D)*

**9.7.3** `ADD` sets `C` on a carry; `SUB` and `CMP` set `C` on a borrow, the PDP-11 sense, so `BHIS` and `BCC` mean "no borrow", unsigned greater or equal. *(D)*

**9.7.4** `ADC` and `SBC` add and subtract the carry; `INC`, `DEC`, `NEG`, `CLR` and `TST` are single-operand forms that work on a register or memory. *(opcode group `SOP`)*

**9.7.5** `SET cc, Rd` (write 1 if the condition holds, else 0) is in the arithmetic escape. *(D)*

**9.7.6** `ABS`, `MIN`, `MINU`, `MAX` and `MAXU` are assembler aliases, not native instructions: `ABS` is the absolute value, and the others the smaller or the larger of two registers, signed or unsigned, with `N` and `Z` from the result, `C` unchanged, and `V` cleared (set by `ABS` on the most negative number). *(D)* Their expansion is open *(P)*: the flag-driven conditional select has no form yet, and a candidate over the branch-free `MASKEQZ` and `MASKNEZ` (a comparison, `SET` into a scratch register, the two masks and `BIS`) needs a scratch register and changes `C`. The present assembler still encodes the five words as sub-opcodes of the arithmetic escape; their dictionary entries show that encoding as the build's, not the design's. *(D)*

*Commentary.* **Precedent.** `ADD`, `SUB`, `CMP`, `BIT`, `BIS`, `BIC` and the single-operand set are the PDP-11's, unchanged in name and meaning except for the order of `CMP`'s operands. **Trade-offs.** The PDP-11 wrote `CMP a, b` to compute `a - b`; since the destination of an ALU operation here must be a register, a literal `src, dst` reading would force every comparison against an immediate or memory to be reversed, so the register comes first. Divide is in the escape group, at four bytes, because compilers turn division by a constant into `MULH` plus a shift, so a real divide is rare. **Improvements.** The high-half multiply that bignum code needs is present; a second unsigned multiply is the same instruction as the first and is not provided. **Benefits.** `SET` replaces a branch around a move for the very common "store the truth value of a comparison", and absolute value, minimum and maximum (as aliases) remove a compare-and-branch from small loops. **Modern comparables.** RISC-V has `MULH`, `MULHU` and `MULHSU`, and AArch64 `SMULH` and `UMULH`; x86 has a one-operand multiply that produces both halves; AArch64's conditional select and set instructions are the nearest to `SET`. **Use.** `MULH` and `MULHU` are for multi-precision arithmetic and for division by constants; `ADC` and `SBC` carry a multi-word add or subtract; `MIN`, `MAX` and `ABS` (aliases) appear under a tenth of a percent of compiled code but each replaces a branch. **Impact.** *Kernel:* `ADC` and `SBC` carry multiword arithmetic for the kernel's 128-bit counters and for the bignum code in the base system. *Compiler:* `MULH` turns division by a constant into a multiply and a shift; `SET` materialises a comparison without a branch; `CMP` takes the register first, as the compiler orders its operands. *Hardware:* One adder on the carry chain; on an FPGA the multiplier is built from two to four multiplier blocks over four to eight cycles; the divide is a sequencer.

<!-- entries:9.7 -->
<a id="w-add"></a>
### ADD: Add

![ADD, opcode 010110, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/add/06.svg)

![ADD, opcode 010110, three parcels (modes index) (6 bytes)](figures/w/add/07.svg)

![ADD, opcode 010110, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/add/08.svg)

![ADD, opcode 010110, three parcels (modes dp) (6 bytes)](figures/w/add/09.svg)

![ADD, opcode 010110, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/add/02.svg)

![ADD, opcode 010110, two parcels (modes index) (4 bytes)](figures/w/add/03.svg)

![ADD, opcode 010110, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/add/04.svg)

![ADD, opcode 010110, two parcels (modes dp) (4 bytes)](figures/w/add/05.svg)

![ADD, opcode 010110, one parcel (2 bytes)](figures/w/add/01.svg)

**Mnemonics:** `ADD`

**Syntax**

```
ADD rm, Rd
```

**Encoding**

![Encoding of ADD](figures/r20-mem-0.svg)

The chart is the layout `r20-mem-0`, Moves, address formation and the ALU, one parcel (`len = 00`): `reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `ADD` | `010110 (0x16)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-mem-0`](dictionary/by-encoding.md#r20-mem-0), [`r20-mem-1`](dictionary/by-encoding.md#r20-mem-1), [`r20-mem-1-2`](dictionary/by-encoding.md#r20-mem-1-2), [`r20-mem-1-3`](dictionary/by-encoding.md#r20-mem-1-3), [`r20-mem-1-4`](dictionary/by-encoding.md#r20-mem-1-4), [`r20-mem-2`](dictionary/by-encoding.md#r20-mem-2), [`r20-mem-2-2`](dictionary/by-encoding.md#r20-mem-2-2), [`r20-mem-2-3`](dictionary/by-encoding.md#r20-mem-2-3), [`r20-mem-2-4`](dictionary/by-encoding.md#r20-mem-2-4).

**Operation**

```
Rd ← Rd + rm
```

**Flags** `N` and `Z` from the result, `V` set on signed overflow, `C` set on a carry out of bit 63.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

All ALU operations are 64 bits, with no size field. Page 2 has `ADD #imm, rd` with a 4-bit immediate and `ADD #(8*n), SP`.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-sub"></a>
### SUB: Subtract

![SUB, opcode 010111, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/sub/06.svg)

![SUB, opcode 010111, three parcels (modes index) (6 bytes)](figures/w/sub/07.svg)

![SUB, opcode 010111, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/sub/08.svg)

![SUB, opcode 010111, three parcels (modes dp) (6 bytes)](figures/w/sub/09.svg)

![SUB, opcode 010111, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/sub/02.svg)

![SUB, opcode 010111, two parcels (modes index) (4 bytes)](figures/w/sub/03.svg)

![SUB, opcode 010111, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/sub/04.svg)

![SUB, opcode 010111, two parcels (modes dp) (4 bytes)](figures/w/sub/05.svg)

![SUB, opcode 010111, one parcel (2 bytes)](figures/w/sub/01.svg)

**Mnemonics:** `SUB`

**Syntax**

```
SUB rm, Rd
```

**Encoding**

![Encoding of SUB](figures/r20-mem-0.svg)

The chart is the layout `r20-mem-0`, Moves, address formation and the ALU, one parcel (`len = 00`): `reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `SUB` | `010111 (0x17)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-mem-0`](dictionary/by-encoding.md#r20-mem-0), [`r20-mem-1`](dictionary/by-encoding.md#r20-mem-1), [`r20-mem-1-2`](dictionary/by-encoding.md#r20-mem-1-2), [`r20-mem-1-3`](dictionary/by-encoding.md#r20-mem-1-3), [`r20-mem-1-4`](dictionary/by-encoding.md#r20-mem-1-4), [`r20-mem-2`](dictionary/by-encoding.md#r20-mem-2), [`r20-mem-2-2`](dictionary/by-encoding.md#r20-mem-2-2), [`r20-mem-2-3`](dictionary/by-encoding.md#r20-mem-2-3), [`r20-mem-2-4`](dictionary/by-encoding.md#r20-mem-2-4).

**Operation**

```
Rd ← Rd - rm
```

**Flags** `N` and `Z` from the result, `V` set on signed overflow, `C` set on a **borrow** (the PDP-11 sense): `C` = 1 when the unsigned operand being subtracted is the larger.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

Page 2 has `SUB #(8*n), SP`.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-cmp"></a>
### CMP: Compare

![CMP, opcode 011010, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/cmp/06.svg)

![CMP, opcode 011010, three parcels (modes index) (6 bytes)](figures/w/cmp/07.svg)

![CMP, opcode 011010, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/cmp/08.svg)

![CMP, opcode 011010, three parcels (modes dp) (6 bytes)](figures/w/cmp/09.svg)

![CMP, opcode 011010, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/cmp/02.svg)

![CMP, opcode 011010, two parcels (modes index) (4 bytes)](figures/w/cmp/03.svg)

![CMP, opcode 011010, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/cmp/04.svg)

![CMP, opcode 011010, two parcels (modes dp) (4 bytes)](figures/w/cmp/05.svg)

![CMP, opcode 011010, one parcel (2 bytes)](figures/w/cmp/01.svg)

**Mnemonics:** `CMP`

**Syntax**

```
CMP Rd, rm        ; register first
```

**Encoding**

![Encoding of CMP](figures/r20-mem-0.svg)

The chart is the layout `r20-mem-0`, Moves, address formation and the ALU, one parcel (`len = 00`): `reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `CMP` | `011010 (0x1A)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-mem-0`](dictionary/by-encoding.md#r20-mem-0), [`r20-mem-1`](dictionary/by-encoding.md#r20-mem-1), [`r20-mem-1-2`](dictionary/by-encoding.md#r20-mem-1-2), [`r20-mem-1-3`](dictionary/by-encoding.md#r20-mem-1-3), [`r20-mem-1-4`](dictionary/by-encoding.md#r20-mem-1-4), [`r20-mem-2`](dictionary/by-encoding.md#r20-mem-2), [`r20-mem-2-2`](dictionary/by-encoding.md#r20-mem-2-2), [`r20-mem-2-3`](dictionary/by-encoding.md#r20-mem-2-3), [`r20-mem-2-4`](dictionary/by-encoding.md#r20-mem-2-4).

**Operation**

```
tmp ← Rd - rm         ; the result is discarded
```

**Flags** `N` and `Z` from the result, `V` set on signed overflow, `C` set on a **borrow** (the PDP-11 sense): `C` = 1 when the unsigned operand being subtracted is the larger.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

**The operands are in the order register, then the other operand**, the reverse of the PDP-11 `CMP src,dst`: `CMP Rd, rm` computes `Rd - rm`, so a compare of a register against an immediate or memory operand does not reverse its branch condition. After `CMP`, `BHIS`/`BCC` mean unsigned `>=` (no borrow) and `BLO`/`BCS` mean a borrow occurred.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-mul"></a>
<a id="w-mulu"></a>
### MUL: Multiply, low 64 bits

![MUL, opcode 011110, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/mul/06.svg)

![MUL, opcode 011110, three parcels (modes index) (6 bytes)](figures/w/mul/07.svg)

![MUL, opcode 011110, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/mul/08.svg)

![MUL, opcode 011110, three parcels (modes dp) (6 bytes)](figures/w/mul/09.svg)

![MUL, opcode 011110, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/mul/02.svg)

![MUL, opcode 011110, two parcels (modes index) (4 bytes)](figures/w/mul/03.svg)

![MUL, opcode 011110, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/mul/04.svg)

![MUL, opcode 011110, two parcels (modes dp) (4 bytes)](figures/w/mul/05.svg)

![MUL, opcode 011110, one parcel (2 bytes)](figures/w/mul/01.svg)

**Mnemonics:** `MUL`  (aliases: `MULU`)

**Syntax**

```
MUL rm, Rd
```

**Encoding**

![Encoding of MUL](figures/r20-mem-0.svg)

The chart is the layout `r20-mem-0`, Moves, address formation and the ALU, one parcel (`len = 00`): `reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `MUL` | `011110 (0x1E)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-mem-0`](dictionary/by-encoding.md#r20-mem-0), [`r20-mem-1`](dictionary/by-encoding.md#r20-mem-1), [`r20-mem-1-2`](dictionary/by-encoding.md#r20-mem-1-2), [`r20-mem-1-3`](dictionary/by-encoding.md#r20-mem-1-3), [`r20-mem-1-4`](dictionary/by-encoding.md#r20-mem-1-4), [`r20-mem-2`](dictionary/by-encoding.md#r20-mem-2), [`r20-mem-2-2`](dictionary/by-encoding.md#r20-mem-2-2), [`r20-mem-2-3`](dictionary/by-encoding.md#r20-mem-2-3), [`r20-mem-2-4`](dictionary/by-encoding.md#r20-mem-2-4).

**Operation**

```
Rd ← (Rd × rm)[63:0]         ; sign-agnostic
```

**Flags** `N` and `Z` from the result, `V` set when the signed 128-bit product does not fit in 64 bits, `C` unchanged.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

The low 64 bits of a two's-complement product are the same whether the operands are read as signed or unsigned, so there is one low-half multiply. The mnemonic `MULU` is an alias of `MUL`. The high half is `MULH` (signed) and `MULHU` (unsigned).

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-mulu"></a>
**`MULU`** is an alias of `MUL`: the assembler writes it as that word.


<a id="w-mulh"></a>
### MULH: Multiply, high 64 bits, signed

![MULH, opcode 011111, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/mulh/06.svg)

![MULH, opcode 011111, three parcels (modes index) (6 bytes)](figures/w/mulh/07.svg)

![MULH, opcode 011111, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/mulh/08.svg)

![MULH, opcode 011111, three parcels (modes dp) (6 bytes)](figures/w/mulh/09.svg)

![MULH, opcode 011111, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/mulh/02.svg)

![MULH, opcode 011111, two parcels (modes index) (4 bytes)](figures/w/mulh/03.svg)

![MULH, opcode 011111, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/mulh/04.svg)

![MULH, opcode 011111, two parcels (modes dp) (4 bytes)](figures/w/mulh/05.svg)

![MULH, opcode 011111, one parcel (2 bytes)](figures/w/mulh/01.svg)

**Mnemonics:** `MULH`

**Syntax**

```
MULH rm, Rd
```

**Encoding**

![Encoding of MULH](figures/r20-mem-0.svg)

The chart is the layout `r20-mem-0`, Moves, address formation and the ALU, one parcel (`len = 00`): `reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `MULH` | `011111 (0x1F)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-mem-0`](dictionary/by-encoding.md#r20-mem-0), [`r20-mem-1`](dictionary/by-encoding.md#r20-mem-1), [`r20-mem-1-2`](dictionary/by-encoding.md#r20-mem-1-2), [`r20-mem-1-3`](dictionary/by-encoding.md#r20-mem-1-3), [`r20-mem-1-4`](dictionary/by-encoding.md#r20-mem-1-4), [`r20-mem-2`](dictionary/by-encoding.md#r20-mem-2), [`r20-mem-2-2`](dictionary/by-encoding.md#r20-mem-2-2), [`r20-mem-2-3`](dictionary/by-encoding.md#r20-mem-2-3), [`r20-mem-2-4`](dictionary/by-encoding.md#r20-mem-2-4).

**Operation**

```
Rd ← (sext(Rd) × sext(rm))[127:64]
```

**Flags** `N` and `Z` from the result, `V` cleared, `C` unchanged.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

With `MULH`, division by a constant is a multiply by a reciprocal and a shift, which is what compilers emit.

**Why it is here.** The low 64 bits of a two's-complement product are identical signed or unsigned, so a second multiply (`MULU`) would duplicate `MUL`; what the architecture needs in that place is the *high* half of the product. Without it a 64 by 64 to 128-bit multiply, every bignum multiply, 128-bit fixed point and divide-by-a-constant by multiplying by the reciprocal are impossible. `MULH` is that instruction. It is also why a divide is rare in compiled code: compilers turn division by a constant into `MULH` and a shift.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


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

![Encoding of ADDM](figures/r20-mesc-1.svg)

The chart is the layout `r20-mesc-1`, Memory escape (MESC), two parcels (`len = 01`): Addressing modes (`low`) that use this layout: `base` 0000, `index` 0001, `pcrel` 0010, `dp` 0011, `imm` 0100, `abs` 0101, `postinc` 0110, `predec` 0111. `low` of parcel 0 is an addressing mode; parcel 1 holds the sub-opcode, `rm` and the first 8 bits of the displacement.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `ADDM` | `001111 (0x0F)` | `1000 (0x8)` |
| `SUBM` | `001111 (0x0F)` | `1001 (0x9)` |
| `BICM` | `001111 (0x0F)` | `1010 (0xA)` |
| `BISM` | `001111 (0x0F)` | `1011 (0xB)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-mesc-1`](dictionary/by-encoding.md#r20-mesc-1), [`r20-mesc-2`](dictionary/by-encoding.md#r20-mesc-2).

**Operation**

```
ADDM: M[EA] ← M[EA] + Rs
SUBM: M[EA] ← M[EA] - Rs
BICM: M[EA] ← M[EA] AND NOT Rs
BISM: M[EA] ← M[EA] OR Rs
```

**Flags** As for `ADD`, `SUB`, `BIC` and `BIS`.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires. Write permission is checked during the read access, so the write cannot fault after the read has succeeded.

Parcel 0's low nibble is a mode, as in the ordinary memory format, so these are `MESC` forms with a memory destination (`len >= 01`). `INC`, `DEC`, `NEG`, `COM` and `CLR` on a memory operand are in `SOP`.

**Why it is here.** These are the read-modify-write forms with a memory destination. An instruction with a memory destination is at least four bytes anyway, so they live in `MESC` at no cost; the opcode map follows one rule, that a top-level opcode is for an operation whose common case is register to register. They cover the case where the second operand is a register, for example `BISM Rmask, flags(DP)`. The compiled corpus has 265 sites (1.6 KB), so they earn their place in the escape group but not in the opcode space.

**Status** specified; **not yet implemented** in the reference executor.

<a id="w-addm"></a>
#### ADDM

![ADDM, opcode 001111, three parcels, sub-opcode 1000 (modes base, index, pcrel, dp, imm, abs, postinc, predec) (6 bytes)](figures/w/addm/02.svg)

![ADDM, opcode 001111, two parcels, sub-opcode 1000 (modes base, index, pcrel, dp, imm, abs, postinc, predec) (4 bytes)](figures/w/addm/01.svg)

```
ADDM Rs, rm
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `ADDM` | `001111 (0x0F)` | `1000 (0x8)` |

Operation, flags and exceptions as for the entry ADDM above; 2 layout forms, each a chart of its own (above).

<a id="w-subm"></a>
#### SUBM

![SUBM, opcode 001111, three parcels, sub-opcode 1001 (modes base, index, pcrel, dp, imm, abs, postinc, predec) (6 bytes)](figures/w/subm/02.svg)

![SUBM, opcode 001111, two parcels, sub-opcode 1001 (modes base, index, pcrel, dp, imm, abs, postinc, predec) (4 bytes)](figures/w/subm/01.svg)

```
SUBM Rs, rm
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `SUBM` | `001111 (0x0F)` | `1001 (0x9)` |

Operation, flags and exceptions as for the entry ADDM above; 2 layout forms, each a chart of its own (above).

<a id="w-bicm"></a>
#### BICM

![BICM, opcode 001111, three parcels, sub-opcode 1010 (modes base, index, pcrel, dp, imm, abs, postinc, predec) (6 bytes)](figures/w/bicm/02.svg)

![BICM, opcode 001111, two parcels, sub-opcode 1010 (modes base, index, pcrel, dp, imm, abs, postinc, predec) (4 bytes)](figures/w/bicm/01.svg)

```
BICM Rs, rm
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `BICM` | `001111 (0x0F)` | `1010 (0xA)` |

Operation, flags and exceptions as for the entry ADDM above; 2 layout forms, each a chart of its own (above).

<a id="w-bism"></a>
#### BISM

![BISM, opcode 001111, three parcels, sub-opcode 1011 (modes base, index, pcrel, dp, imm, abs, postinc, predec) (6 bytes)](figures/w/bism/02.svg)

![BISM, opcode 001111, two parcels, sub-opcode 1011 (modes base, index, pcrel, dp, imm, abs, postinc, predec) (4 bytes)](figures/w/bism/01.svg)

```
BISM Rs, rm
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `BISM` | `001111 (0x0F)` | `1011 (0xB)` |

Operation, flags and exceptions as for the entry ADDM above; 2 layout forms, each a chart of its own (above).


<a id="w-inc"></a>
### INC: Increment

![INC, opcode 010011, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/inc/06.svg)

![INC, opcode 010011, three parcels (modes index) (6 bytes)](figures/w/inc/07.svg)

![INC, opcode 010011, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/inc/08.svg)

![INC, opcode 010011, three parcels (modes dp) (6 bytes)](figures/w/inc/09.svg)

![INC, opcode 010011, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/inc/02.svg)

![INC, opcode 010011, two parcels (modes index) (4 bytes)](figures/w/inc/03.svg)

![INC, opcode 010011, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/inc/04.svg)

![INC, opcode 010011, two parcels (modes dp) (4 bytes)](figures/w/inc/05.svg)

![INC, opcode 010011, one parcel (2 bytes)](figures/w/inc/01.svg)

**Mnemonics:** `INC`

**Syntax**

```
INC rm
```

**Encoding**

![Encoding of INC](figures/r20-sop-0.svg)

The chart is the layout `r20-sop-0`, Single operand (SOP), one parcel (`len = 00`): The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `INC` | `010011 (0x13)` | `0010 (0x2)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sop-0`](dictionary/by-encoding.md#r20-sop-0), [`r20-sop-1`](dictionary/by-encoding.md#r20-sop-1), [`r20-sop-1-2`](dictionary/by-encoding.md#r20-sop-1-2), [`r20-sop-1-3`](dictionary/by-encoding.md#r20-sop-1-3), [`r20-sop-1-4`](dictionary/by-encoding.md#r20-sop-1-4), [`r20-sop-2`](dictionary/by-encoding.md#r20-sop-2), [`r20-sop-2-2`](dictionary/by-encoding.md#r20-sop-2-2), [`r20-sop-2-3`](dictionary/by-encoding.md#r20-sop-2-3), [`r20-sop-2-4`](dictionary/by-encoding.md#r20-sop-2-4).

**Operation**

```
rm ← rm + 1
```

**Flags** `N`, `Z` and `V` as for `ADD`; `C` **unchanged**.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-dec"></a>
### DEC: Decrement

![DEC, opcode 010011, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/dec/06.svg)

![DEC, opcode 010011, three parcels (modes index) (6 bytes)](figures/w/dec/07.svg)

![DEC, opcode 010011, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/dec/08.svg)

![DEC, opcode 010011, three parcels (modes dp) (6 bytes)](figures/w/dec/09.svg)

![DEC, opcode 010011, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/dec/02.svg)

![DEC, opcode 010011, two parcels (modes index) (4 bytes)](figures/w/dec/03.svg)

![DEC, opcode 010011, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/dec/04.svg)

![DEC, opcode 010011, two parcels (modes dp) (4 bytes)](figures/w/dec/05.svg)

![DEC, opcode 010011, one parcel (2 bytes)](figures/w/dec/01.svg)

**Mnemonics:** `DEC`

**Syntax**

```
DEC rm
```

**Encoding**

![Encoding of DEC](figures/r20-sop-0.svg)

The chart is the layout `r20-sop-0`, Single operand (SOP), one parcel (`len = 00`): The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `DEC` | `010011 (0x13)` | `0011 (0x3)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sop-0`](dictionary/by-encoding.md#r20-sop-0), [`r20-sop-1`](dictionary/by-encoding.md#r20-sop-1), [`r20-sop-1-2`](dictionary/by-encoding.md#r20-sop-1-2), [`r20-sop-1-3`](dictionary/by-encoding.md#r20-sop-1-3), [`r20-sop-1-4`](dictionary/by-encoding.md#r20-sop-1-4), [`r20-sop-2`](dictionary/by-encoding.md#r20-sop-2), [`r20-sop-2-2`](dictionary/by-encoding.md#r20-sop-2-2), [`r20-sop-2-3`](dictionary/by-encoding.md#r20-sop-2-3), [`r20-sop-2-4`](dictionary/by-encoding.md#r20-sop-2-4).

**Operation**

```
rm ← rm - 1
```

**Flags** `N`, `Z` and `V` as for `SUB`; `C` **unchanged**.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-neg"></a>
### NEG: Negate

![NEG, opcode 010011, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/neg/06.svg)

![NEG, opcode 010011, three parcels (modes index) (6 bytes)](figures/w/neg/07.svg)

![NEG, opcode 010011, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/neg/08.svg)

![NEG, opcode 010011, three parcels (modes dp) (6 bytes)](figures/w/neg/09.svg)

![NEG, opcode 010011, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/neg/02.svg)

![NEG, opcode 010011, two parcels (modes index) (4 bytes)](figures/w/neg/03.svg)

![NEG, opcode 010011, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/neg/04.svg)

![NEG, opcode 010011, two parcels (modes dp) (4 bytes)](figures/w/neg/05.svg)

![NEG, opcode 010011, one parcel (2 bytes)](figures/w/neg/01.svg)

**Mnemonics:** `NEG`

**Syntax**

```
NEG rm
```

**Encoding**

![Encoding of NEG](figures/r20-sop-0.svg)

The chart is the layout `r20-sop-0`, Single operand (SOP), one parcel (`len = 00`): The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `NEG` | `010011 (0x13)` | `0100 (0x4)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sop-0`](dictionary/by-encoding.md#r20-sop-0), [`r20-sop-1`](dictionary/by-encoding.md#r20-sop-1), [`r20-sop-1-2`](dictionary/by-encoding.md#r20-sop-1-2), [`r20-sop-1-3`](dictionary/by-encoding.md#r20-sop-1-3), [`r20-sop-1-4`](dictionary/by-encoding.md#r20-sop-1-4), [`r20-sop-2`](dictionary/by-encoding.md#r20-sop-2), [`r20-sop-2-2`](dictionary/by-encoding.md#r20-sop-2-2), [`r20-sop-2-3`](dictionary/by-encoding.md#r20-sop-2-3), [`r20-sop-2-4`](dictionary/by-encoding.md#r20-sop-2-4).

**Operation**

```
rm ← 0 - rm
```

**Flags** `N` and `Z` from the result, `V` set on signed overflow, `C` set on a **borrow** (the PDP-11 sense): `C` = 1 when the unsigned operand being subtracted is the larger. (`C` = 1 unless the operand was 0.)

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-adc"></a>
### ADC: Add carry

![ADC, opcode 010011, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/adc/06.svg)

![ADC, opcode 010011, three parcels (modes index) (6 bytes)](figures/w/adc/07.svg)

![ADC, opcode 010011, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/adc/08.svg)

![ADC, opcode 010011, three parcels (modes dp) (6 bytes)](figures/w/adc/09.svg)

![ADC, opcode 010011, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/adc/02.svg)

![ADC, opcode 010011, two parcels (modes index) (4 bytes)](figures/w/adc/03.svg)

![ADC, opcode 010011, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/adc/04.svg)

![ADC, opcode 010011, two parcels (modes dp) (4 bytes)](figures/w/adc/05.svg)

![ADC, opcode 010011, one parcel (2 bytes)](figures/w/adc/01.svg)

**Mnemonics:** `ADC`

**Syntax**

```
ADC rm
```

**Encoding**

![Encoding of ADC](figures/r20-sop-0.svg)

The chart is the layout `r20-sop-0`, Single operand (SOP), one parcel (`len = 00`): The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `ADC` | `010011 (0x13)` | `0110 (0x6)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sop-0`](dictionary/by-encoding.md#r20-sop-0), [`r20-sop-1`](dictionary/by-encoding.md#r20-sop-1), [`r20-sop-1-2`](dictionary/by-encoding.md#r20-sop-1-2), [`r20-sop-1-3`](dictionary/by-encoding.md#r20-sop-1-3), [`r20-sop-1-4`](dictionary/by-encoding.md#r20-sop-1-4), [`r20-sop-2`](dictionary/by-encoding.md#r20-sop-2), [`r20-sop-2-2`](dictionary/by-encoding.md#r20-sop-2-2), [`r20-sop-2-3`](dictionary/by-encoding.md#r20-sop-2-3), [`r20-sop-2-4`](dictionary/by-encoding.md#r20-sop-2-4).

**Operation**

```
rm ← rm + C
```

**Flags** `N` and `Z` from the result, `V` set on signed overflow, `C` set on a carry out of bit 63.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

With `ADD`, multi-word addition.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-sbc"></a>
### SBC: Subtract carry

![SBC, opcode 010011, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/sbc/06.svg)

![SBC, opcode 010011, three parcels (modes index) (6 bytes)](figures/w/sbc/07.svg)

![SBC, opcode 010011, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/sbc/08.svg)

![SBC, opcode 010011, three parcels (modes dp) (6 bytes)](figures/w/sbc/09.svg)

![SBC, opcode 010011, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/sbc/02.svg)

![SBC, opcode 010011, two parcels (modes index) (4 bytes)](figures/w/sbc/03.svg)

![SBC, opcode 010011, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/sbc/04.svg)

![SBC, opcode 010011, two parcels (modes dp) (4 bytes)](figures/w/sbc/05.svg)

![SBC, opcode 010011, one parcel (2 bytes)](figures/w/sbc/01.svg)

**Mnemonics:** `SBC`

**Syntax**

```
SBC rm
```

**Encoding**

![Encoding of SBC](figures/r20-sop-0.svg)

The chart is the layout `r20-sop-0`, Single operand (SOP), one parcel (`len = 00`): The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `SBC` | `010011 (0x13)` | `0111 (0x7)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sop-0`](dictionary/by-encoding.md#r20-sop-0), [`r20-sop-1`](dictionary/by-encoding.md#r20-sop-1), [`r20-sop-1-2`](dictionary/by-encoding.md#r20-sop-1-2), [`r20-sop-1-3`](dictionary/by-encoding.md#r20-sop-1-3), [`r20-sop-1-4`](dictionary/by-encoding.md#r20-sop-1-4), [`r20-sop-2`](dictionary/by-encoding.md#r20-sop-2), [`r20-sop-2-2`](dictionary/by-encoding.md#r20-sop-2-2), [`r20-sop-2-3`](dictionary/by-encoding.md#r20-sop-2-3), [`r20-sop-2-4`](dictionary/by-encoding.md#r20-sop-2-4).

**Operation**

```
rm ← rm - C
```

**Flags** `N` and `Z` from the result, `V` set on signed overflow, `C` set on a **borrow** (the PDP-11 sense): `C` = 1 when the unsigned operand being subtracted is the larger.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


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

![Encoding of DIV](figures/r20-aesc-1.svg)

The chart is the layout `r20-aesc-1`, Arithmetic (AESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `DIV` | `001110 (0x0E)` | `00000000 (0x00)` |
| `DIVU` | `001110 (0x0E)` | `00000001 (0x01)` |
| `MOD` | `001110 (0x0E)` | `00000010 (0x02)` |
| `MODU` | `001110 (0x0E)` | `00000011 (0x03)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-aesc-1`](dictionary/by-encoding.md#r20-aesc-1), [`r20-aesc-2`](dictionary/by-encoding.md#r20-aesc-2).

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

**Cf.** 6.2 (the divide-by-zero vector).

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-div"></a>
#### DIV

![DIV, opcode 001110, three parcels, sub-opcode 00000000 (6 bytes)](figures/w/div/02.svg)

![DIV, opcode 001110, two parcels, sub-opcode 00000000 (4 bytes)](figures/w/div/01.svg)

```
DIV Ra, Rb, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `DIV` | `001110 (0x0E)` | `00000000 (0x00)` |

Operation, flags and exceptions as for the entry DIV above; 2 layout forms, each a chart of its own (above).

<a id="w-divu"></a>
#### DIVU

![DIVU, opcode 001110, three parcels, sub-opcode 00000001 (6 bytes)](figures/w/divu/02.svg)

![DIVU, opcode 001110, two parcels, sub-opcode 00000001 (4 bytes)](figures/w/divu/01.svg)

```
DIVU Ra, Rb, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `DIVU` | `001110 (0x0E)` | `00000001 (0x01)` |

Operation, flags and exceptions as for the entry DIV above; 2 layout forms, each a chart of its own (above).

<a id="w-mod"></a>
#### MOD

![MOD, opcode 001110, three parcels, sub-opcode 00000010 (6 bytes)](figures/w/mod/02.svg)

![MOD, opcode 001110, two parcels, sub-opcode 00000010 (4 bytes)](figures/w/mod/01.svg)

```
MOD Ra, Rb, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MOD` | `001110 (0x0E)` | `00000010 (0x02)` |

Operation, flags and exceptions as for the entry DIV above; 2 layout forms, each a chart of its own (above).

<a id="w-modu"></a>
#### MODU

![MODU, opcode 001110, three parcels, sub-opcode 00000011 (6 bytes)](figures/w/modu/02.svg)

![MODU, opcode 001110, two parcels, sub-opcode 00000011 (4 bytes)](figures/w/modu/01.svg)

```
MODU Ra, Rb, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MODU` | `001110 (0x0E)` | `00000011 (0x03)` |

Operation, flags and exceptions as for the entry DIV above; 2 layout forms, each a chart of its own (above).


<a id="w-mulhu"></a>
### MULHU: Multiply, high 64 bits, unsigned

![MULHU, opcode 001110, three parcels, sub-opcode 00000100 (6 bytes)](figures/w/mulhu/02.svg)

![MULHU, opcode 001110, two parcels, sub-opcode 00000100 (4 bytes)](figures/w/mulhu/01.svg)

**Mnemonics:** `MULHU`

**Syntax**

```
MULHU Ra, Rb, Rd
```

**Encoding**

![Encoding of MULHU](figures/r20-aesc-1.svg)

The chart is the layout `r20-aesc-1`, Arithmetic (AESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MULHU` | `001110 (0x0E)` | `00000100 (0x04)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-aesc-1`](dictionary/by-encoding.md#r20-aesc-1), [`r20-aesc-2`](dictionary/by-encoding.md#r20-aesc-2).

**Operation**

```
Rd ← (Ra × Rb)[127:64]    ; unsigned
```

**Flags** None written.

**Exceptions** None.

`MULHSU` (signed by unsigned) is reserved and not committed.

**Why it is here.** The unsigned partner of `MULH`, for the same reason (the high half of the product). It is in `AESC`, where arithmetic belongs. `MULHSU`, signed times unsigned for a bignum's top limb, is reserved because it can be built from `MULH` with one correction.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-abs"></a>
### ABS: Absolute value (assembler alias)

![ABS, opcode 001110, three parcels, sub-opcode 00001000 (6 bytes)](figures/w/abs/02.svg)

![ABS, opcode 001110, two parcels, sub-opcode 00001000 (4 bytes)](figures/w/abs/01.svg)

**Mnemonics:** `ABS`

**Alias** *(D)* `ABS` is an assembler alias, not a native instruction (the author's decision, errata 98). Meaning: `Rd <- |Rs|`, with the flags below, which the alias must keep or the decision that defines it must change. Expansion: open *(P)*; the flag-driven conditional select (`CMOV`, `CSEL`) is on hold and has no form in the records (ISA section 12 item 15); the only select the records define is the branch-free `MASKEQZ`/`MASKNEZ` (errata 85), which reads a register and no flag. A candidate over it, not decided: compare the operands, `SET` the condition into a scratch register, then `MASKEQZ`, `MASKNEZ` and `BIS` (the constant-time select `d = c ? a : b` of the `MASKEQZ` entry) for the minimum and maximum, and the same around the negated value for `ABS`; it needs a scratch register and leaves `C` as the comparison set it, which the native word does not do, so the flags would change. Which expansion, and whether the select the author meant is this one, is the author's question. The present assembler still encodes the word as the arithmetic-escape sub-opcode of the chart below.

**Syntax**

```
ABS Rs, Rd
```

**Encoding** (the present encoding of the build, as the grammar gives it; not the design)

![Encoding of ABS](figures/r20-aesc-1.svg)

The chart is the layout `r20-aesc-1`, Arithmetic (AESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `ABS` | `001110 (0x0E)` | `00001000 (0x08)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-aesc-1`](dictionary/by-encoding.md#r20-aesc-1), [`r20-aesc-2`](dictionary/by-encoding.md#r20-aesc-2).

**Operation**

```
Rd ← |Rs|
```

**Flags** `N` and `Z` from the result, `V` set if `Rs` is the most negative value (the result is then still negative), `C` unchanged.

**Exceptions** None.

**Why it is here.** Integer absolute value is the counterpart of `FABS`. It was added as a native sub-opcode and the author then decided (2026-11-10) that it is an assembler alias over the conditional select, which is not yet defined. The cost of the native word was about 150 to 250 lookup tables, no new operation by the folding rule (integer against float and signed against unsigned are qualifiers), and the compiler's work of recognising `x < 0 ? -x : x`, which is the real cost. The compiled corpus has 18 uses of `abs` and 5 of its unsigned form, under 0.1% of code, so the case is clarity and the idiom more than size.

**Status** by decision an assembler alias (errata 98); the present assembler, simulator, QEMU and LLVM still encode and execute the word as the arithmetic-escape sub-opcode shown above, so the word is implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


### MINMAX: Minimum and maximum, signed and unsigned (assembler aliases)

**Mnemonics:** `MIN`, `MINU`, `MAX`, `MAXU`

**Alias** *(D)* `MIN`, `MINU`, `MAX` and `MAXU` are assembler aliases, not native instructions (the author's decision, errata 98). Meaning: the smaller or the larger of `Ra` and `Rb`, signed for `MIN` and `MAX` and unsigned for `MINU` and `MAXU`, with the flags below, which an alias must keep or the decision that defines it must change. Expansion: open *(P)*; the flag-driven conditional select (`CMOV`, `CSEL`) is on hold and has no form in the records (ISA section 12 item 15); the only select the records define is the branch-free `MASKEQZ`/`MASKNEZ` (errata 85), which reads a register and no flag. A candidate over it, not decided: compare the operands, `SET` the condition into a scratch register, then `MASKEQZ`, `MASKNEZ` and `BIS` (the constant-time select `d = c ? a : b` of the `MASKEQZ` entry) for the minimum and maximum, and the same around the negated value for `ABS`; it needs a scratch register and leaves `C` as the comparison set it, which the native word does not do, so the flags would change. Which expansion, and whether the select the author meant is this one, is the author's question. The present assembler still encodes each word as an arithmetic-escape sub-opcode, as the chart below shows.

**Syntax**

```
MIN Ra, Rb, Rd
MINU Ra, Rb, Rd
MAX Ra, Rb, Rd
MAXU Ra, Rb, Rd
```

**Encoding** (the present encoding of the build, as the grammar gives it; not the design)

![Encoding of MINMAX](figures/r20-aesc-1.svg)

The chart is the layout `r20-aesc-1`, Arithmetic (AESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MIN` | `001110 (0x0E)` | `00010000 (0x10)` |
| `MINU` | `001110 (0x0E)` | `00010001 (0x11)` |
| `MAX` | `001110 (0x0E)` | `00010010 (0x12)` |
| `MAXU` | `001110 (0x0E)` | `00010011 (0x13)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-aesc-1`](dictionary/by-encoding.md#r20-aesc-1), [`r20-aesc-2`](dictionary/by-encoding.md#r20-aesc-2).

**Operation**

```
MIN : Rd ← smaller of Ra, Rb (signed)         MINU: unsigned
MAX : Rd ← larger of Ra, Rb (signed)          MAXU: unsigned
```

**Flags** `N` and `Z` from the result, `V` = 0, `C` unchanged.

**Exceptions** None.

**Why it is here.** The integer counterparts of `FMIN` and `FMAX`, provided with `ABS`; the author decided (2026-11-10) that they are assembler aliases over the conditional select, which is not yet defined. By the folding rule they add no operation, and the native hardware reused the subtract-and-compare that `CMP` already does plus a 64-bit select. The corpus has 171 uses of `MIN` and 52 of `MAX` across 95 files, under 0.1% of code in all. A general conditional select is the alternative; it is open (9.21) for want of a speed model.

**Status** by decision an assembler alias (errata 98); the present assembler, simulator, QEMU and LLVM still encode and execute the word as the arithmetic-escape sub-opcode shown above, so the word is implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-min"></a>
#### MIN

![MIN, opcode 001110, three parcels, sub-opcode 00010000 (6 bytes)](figures/w/min/02.svg)

![MIN, opcode 001110, two parcels, sub-opcode 00010000 (4 bytes)](figures/w/min/01.svg)

```
MIN Ra, Rb, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MIN` | `001110 (0x0E)` | `00010000 (0x10)` |

Operation, flags and exceptions as for the entry MINMAX above; 2 layout forms, each a chart of its own (above).

<a id="w-minu"></a>
#### MINU

![MINU, opcode 001110, three parcels, sub-opcode 00010001 (6 bytes)](figures/w/minu/02.svg)

![MINU, opcode 001110, two parcels, sub-opcode 00010001 (4 bytes)](figures/w/minu/01.svg)

```
MINU Ra, Rb, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MINU` | `001110 (0x0E)` | `00010001 (0x11)` |

Operation, flags and exceptions as for the entry MINMAX above; 2 layout forms, each a chart of its own (above).

<a id="w-max"></a>
#### MAX

![MAX, opcode 001110, three parcels, sub-opcode 00010010 (6 bytes)](figures/w/max/02.svg)

![MAX, opcode 001110, two parcels, sub-opcode 00010010 (4 bytes)](figures/w/max/01.svg)

```
MAX Ra, Rb, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MAX` | `001110 (0x0E)` | `00010010 (0x12)` |

Operation, flags and exceptions as for the entry MINMAX above; 2 layout forms, each a chart of its own (above).

<a id="w-maxu"></a>
#### MAXU

![MAXU, opcode 001110, three parcels, sub-opcode 00010011 (6 bytes)](figures/w/maxu/02.svg)

![MAXU, opcode 001110, two parcels, sub-opcode 00010011 (4 bytes)](figures/w/maxu/01.svg)

```
MAXU Ra, Rb, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MAXU` | `001110 (0x0E)` | `00010011 (0x13)` |

Operation, flags and exceptions as for the entry MINMAX above; 2 layout forms, each a chart of its own (above).


<a id="w-set"></a>
### SET: Set a register from a condition

![SET, opcode 001110, three parcels, sub-opcode 00100000 (6 bytes)](figures/w/set/02.svg)

![SET, opcode 001110, two parcels, sub-opcode 00100000 (4 bytes)](figures/w/set/01.svg)

**Mnemonics:** `SET`

**Syntax**

```
SET cc, Rd        ; for example SET EQ, R1
```

**Encoding**

![Encoding of SET](figures/r20-aesc-1.svg)

The chart is the layout `r20-aesc-1`, Arithmetic (AESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `SET` | `001110 (0x0E)` | `00100000 (0x20)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-aesc-1`](dictionary/by-encoding.md#r20-aesc-1), [`r20-aesc-2`](dictionary/by-encoding.md#r20-aesc-2).

**Operation**

```
Rd ← 1 if condition cc holds on the current flags, else 0
```

**Flags** None written.

**Exceptions** None.

The condition is the `x` field of parcel 1, numbered as the low nibble of the branch opcodes (`al` 0, `ne` 1, `eq` 2, ... `los` 14).

**Why it is here.** The first instruction written with a condition word: one instruction, `SET cc, Rd`, rather than one opcode per condition, with the condition in a field numbered like the low nibble of the branch opcodes. It turns a comparison used as a value into 0 or 1 without a branch. gcc `-Os` for amd64 emits 673 `set<cc>` on the corpus, and `SET` would remove about six bytes per site, around 0.4% of code; the compiler's first pass turns such a comparison into branches before its second pass sees it, so the saving is not reached in compiled code.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).
<!-- /entries:9.7 -->

## 9.8 Logic, shifts and rotates

**9.8.1** `AND`, `BIC` (bit clear), `BIS` (bit set, the or), `XOR` and `BIT` (test) are two-byte ALU operations; `COM` is one's complement. *(opcodes `011000 (0x18)`, `011001 (0x19)`, `011011 (0x1B)`, `011100 (0x1C)`, `011101 (0x1D)`)*

**9.8.2** `SHL`, `SHR` and `SAR` shift by a count taken from `rm` (a register, an immediate, or memory); `ASL` and `ASR` are the by-one forms in two bytes. *(D)*

**9.8.3** A shift count of 64 or more shifts the value entirely away; `C` receives the last bit that left. *(D)*

**9.8.4** `ROR` rotates right by a register count and `RORI` by an immediate; `ROL Rd, Rs, #n` assembles to `RORI` with `64 - n`; `RORI32` rotates the low 32 bits and sign-extends. Rotates write no flags. *(D)*

**9.8.5** `DSHR` is a double-width funnel shift. It writes no flags. *(D)*

*Commentary.* **Precedent.** The PDP-11 had `ASL`, `ASR`, `ROL` and `ROR` by one through the carry; x86's `SHRD` and ARM's `EXTR` are the funnel shifts. **Trade-offs.** One rotate direction is enough, so there is no by-one `ROL` in a two-byte slot; rotates are not through the carry because a carry chain is fragile when the carry flag is shared. **Improvements.** The shift count comes from `rm`, not from a fixed register like x86's `CL`, which costs a register shuffle in every hand-written loop. **Benefits.** Multi-precision shifting is `DSHR`, two instructions for any distance. **Modern comparables.** RISC-V and AArch64 have rotates by register and by immediate; x86 has `ROL`/`ROR` through the carry as well. **Use.** `RORI` and `RORI32` are for hashes and ciphers, which rotate by constants; `DSHR` shifts a bignum. **Impact.** *Kernel:* Bit tests and mask operations on the status and page-table words are single instructions. *Compiler:* The shift count may be any register, immediate or memory operand, so the compiler never has to move a count into a fixed register; hashes and ciphers rotate by constants. *Hardware:* The barrel shifter (about 450 lookup tables) serves shifts and rotates, and writing no flag for rotates removes a result path.

<!-- entries:9.8 -->
<a id="w-bic"></a>
### BIC: Bit clear

![BIC, opcode 011000, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/bic/06.svg)

![BIC, opcode 011000, three parcels (modes index) (6 bytes)](figures/w/bic/07.svg)

![BIC, opcode 011000, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/bic/08.svg)

![BIC, opcode 011000, three parcels (modes dp) (6 bytes)](figures/w/bic/09.svg)

![BIC, opcode 011000, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/bic/02.svg)

![BIC, opcode 011000, two parcels (modes index) (4 bytes)](figures/w/bic/03.svg)

![BIC, opcode 011000, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/bic/04.svg)

![BIC, opcode 011000, two parcels (modes dp) (4 bytes)](figures/w/bic/05.svg)

![BIC, opcode 011000, one parcel (2 bytes)](figures/w/bic/01.svg)

**Mnemonics:** `BIC`

**Syntax**

```
BIC rm, Rd
```

**Encoding**

![Encoding of BIC](figures/r20-mem-0.svg)

The chart is the layout `r20-mem-0`, Moves, address formation and the ALU, one parcel (`len = 00`): `reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `BIC` | `011000 (0x18)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-mem-0`](dictionary/by-encoding.md#r20-mem-0), [`r20-mem-1`](dictionary/by-encoding.md#r20-mem-1), [`r20-mem-1-2`](dictionary/by-encoding.md#r20-mem-1-2), [`r20-mem-1-3`](dictionary/by-encoding.md#r20-mem-1-3), [`r20-mem-1-4`](dictionary/by-encoding.md#r20-mem-1-4), [`r20-mem-2`](dictionary/by-encoding.md#r20-mem-2), [`r20-mem-2-2`](dictionary/by-encoding.md#r20-mem-2-2), [`r20-mem-2-3`](dictionary/by-encoding.md#r20-mem-2-3), [`r20-mem-2-4`](dictionary/by-encoding.md#r20-mem-2-4).

**Operation**

```
Rd ← Rd AND NOT rm
```

**Flags** `N` and `Z` from the result, `V` cleared, `C` unchanged.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

The assembler also accepts `BIC #imm, rm` as `AND #~imm, rm`.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-bis"></a>
### BIS: Bit set (inclusive or)

![BIS, opcode 011001, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/bis/06.svg)

![BIS, opcode 011001, three parcels (modes index) (6 bytes)](figures/w/bis/07.svg)

![BIS, opcode 011001, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/bis/08.svg)

![BIS, opcode 011001, three parcels (modes dp) (6 bytes)](figures/w/bis/09.svg)

![BIS, opcode 011001, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/bis/02.svg)

![BIS, opcode 011001, two parcels (modes index) (4 bytes)](figures/w/bis/03.svg)

![BIS, opcode 011001, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/bis/04.svg)

![BIS, opcode 011001, two parcels (modes dp) (4 bytes)](figures/w/bis/05.svg)

![BIS, opcode 011001, one parcel (2 bytes)](figures/w/bis/01.svg)

**Mnemonics:** `BIS`

**Syntax**

```
BIS rm, Rd
```

**Encoding**

![Encoding of BIS](figures/r20-mem-0.svg)

The chart is the layout `r20-mem-0`, Moves, address formation and the ALU, one parcel (`len = 00`): `reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `BIS` | `011001 (0x19)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-mem-0`](dictionary/by-encoding.md#r20-mem-0), [`r20-mem-1`](dictionary/by-encoding.md#r20-mem-1), [`r20-mem-1-2`](dictionary/by-encoding.md#r20-mem-1-2), [`r20-mem-1-3`](dictionary/by-encoding.md#r20-mem-1-3), [`r20-mem-1-4`](dictionary/by-encoding.md#r20-mem-1-4), [`r20-mem-2`](dictionary/by-encoding.md#r20-mem-2), [`r20-mem-2-2`](dictionary/by-encoding.md#r20-mem-2-2), [`r20-mem-2-3`](dictionary/by-encoding.md#r20-mem-2-3), [`r20-mem-2-4`](dictionary/by-encoding.md#r20-mem-2-4).

**Operation**

```
Rd ← Rd OR rm
```

**Flags** `N` and `Z` from the result, `V` cleared, `C` unchanged.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-bit"></a>
### BIT: Bit test

![BIT, opcode 011011, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/bit/06.svg)

![BIT, opcode 011011, three parcels (modes index) (6 bytes)](figures/w/bit/07.svg)

![BIT, opcode 011011, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/bit/08.svg)

![BIT, opcode 011011, three parcels (modes dp) (6 bytes)](figures/w/bit/09.svg)

![BIT, opcode 011011, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/bit/02.svg)

![BIT, opcode 011011, two parcels (modes index) (4 bytes)](figures/w/bit/03.svg)

![BIT, opcode 011011, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/bit/04.svg)

![BIT, opcode 011011, two parcels (modes dp) (4 bytes)](figures/w/bit/05.svg)

![BIT, opcode 011011, one parcel (2 bytes)](figures/w/bit/01.svg)

**Mnemonics:** `BIT`

**Syntax**

```
BIT rm, Rd
```

**Encoding**

![Encoding of BIT](figures/r20-mem-0.svg)

The chart is the layout `r20-mem-0`, Moves, address formation and the ALU, one parcel (`len = 00`): `reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `BIT` | `011011 (0x1B)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-mem-0`](dictionary/by-encoding.md#r20-mem-0), [`r20-mem-1`](dictionary/by-encoding.md#r20-mem-1), [`r20-mem-1-2`](dictionary/by-encoding.md#r20-mem-1-2), [`r20-mem-1-3`](dictionary/by-encoding.md#r20-mem-1-3), [`r20-mem-1-4`](dictionary/by-encoding.md#r20-mem-1-4), [`r20-mem-2`](dictionary/by-encoding.md#r20-mem-2), [`r20-mem-2-2`](dictionary/by-encoding.md#r20-mem-2-2), [`r20-mem-2-3`](dictionary/by-encoding.md#r20-mem-2-3), [`r20-mem-2-4`](dictionary/by-encoding.md#r20-mem-2-4).

**Operation**

```
tmp ← Rd AND rm         ; the result is discarded
```

**Flags** `N` and `Z` from the result, `V` cleared, `C` unchanged.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-xor"></a>
### XOR: Exclusive or

![XOR, opcode 011100, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/xor/06.svg)

![XOR, opcode 011100, three parcels (modes index) (6 bytes)](figures/w/xor/07.svg)

![XOR, opcode 011100, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/xor/08.svg)

![XOR, opcode 011100, three parcels (modes dp) (6 bytes)](figures/w/xor/09.svg)

![XOR, opcode 011100, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/xor/02.svg)

![XOR, opcode 011100, two parcels (modes index) (4 bytes)](figures/w/xor/03.svg)

![XOR, opcode 011100, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/xor/04.svg)

![XOR, opcode 011100, two parcels (modes dp) (4 bytes)](figures/w/xor/05.svg)

![XOR, opcode 011100, one parcel (2 bytes)](figures/w/xor/01.svg)

**Mnemonics:** `XOR`

**Syntax**

```
XOR rm, Rd
```

**Encoding**

![Encoding of XOR](figures/r20-mem-0.svg)

The chart is the layout `r20-mem-0`, Moves, address formation and the ALU, one parcel (`len = 00`): `reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `XOR` | `011100 (0x1C)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-mem-0`](dictionary/by-encoding.md#r20-mem-0), [`r20-mem-1`](dictionary/by-encoding.md#r20-mem-1), [`r20-mem-1-2`](dictionary/by-encoding.md#r20-mem-1-2), [`r20-mem-1-3`](dictionary/by-encoding.md#r20-mem-1-3), [`r20-mem-1-4`](dictionary/by-encoding.md#r20-mem-1-4), [`r20-mem-2`](dictionary/by-encoding.md#r20-mem-2), [`r20-mem-2-2`](dictionary/by-encoding.md#r20-mem-2-2), [`r20-mem-2-3`](dictionary/by-encoding.md#r20-mem-2-3), [`r20-mem-2-4`](dictionary/by-encoding.md#r20-mem-2-4).

**Operation**

```
Rd ← Rd XOR rm
```

**Flags** `N` and `Z` from the result, `V` cleared, `C` unchanged.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-and"></a>
### AND: And

![AND, opcode 011101, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/and/06.svg)

![AND, opcode 011101, three parcels (modes index) (6 bytes)](figures/w/and/07.svg)

![AND, opcode 011101, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/and/08.svg)

![AND, opcode 011101, three parcels (modes dp) (6 bytes)](figures/w/and/09.svg)

![AND, opcode 011101, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/and/02.svg)

![AND, opcode 011101, two parcels (modes index) (4 bytes)](figures/w/and/03.svg)

![AND, opcode 011101, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/and/04.svg)

![AND, opcode 011101, two parcels (modes dp) (4 bytes)](figures/w/and/05.svg)

![AND, opcode 011101, one parcel (2 bytes)](figures/w/and/01.svg)

**Mnemonics:** `AND`

**Syntax**

```
AND rm, Rd
```

**Encoding**

![Encoding of AND](figures/r20-mem-0.svg)

The chart is the layout `r20-mem-0`, Moves, address formation and the ALU, one parcel (`len = 00`): `reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `AND` | `011101 (0x1D)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-mem-0`](dictionary/by-encoding.md#r20-mem-0), [`r20-mem-1`](dictionary/by-encoding.md#r20-mem-1), [`r20-mem-1-2`](dictionary/by-encoding.md#r20-mem-1-2), [`r20-mem-1-3`](dictionary/by-encoding.md#r20-mem-1-3), [`r20-mem-1-4`](dictionary/by-encoding.md#r20-mem-1-4), [`r20-mem-2`](dictionary/by-encoding.md#r20-mem-2), [`r20-mem-2-2`](dictionary/by-encoding.md#r20-mem-2-2), [`r20-mem-2-3`](dictionary/by-encoding.md#r20-mem-2-3), [`r20-mem-2-4`](dictionary/by-encoding.md#r20-mem-2-4).

**Operation**

```
Rd ← Rd AND rm
```

**Flags** `N` and `Z` from the result, `V` cleared, `C` unchanged.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


### SHIFT: Shift left, shift right logical, shift right arithmetic

**Mnemonics:** `SHL`, `SHR`, `SAR`

**Syntax**

```
SHL rm, Rd
SHR rm, Rd
SAR rm, Rd
```

**Encoding**

![Encoding of SHIFT](figures/r20-mem-0.svg)

The chart is the layout `r20-mem-0`, Moves, address formation and the ALU, one parcel (`len = 00`): `reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `SHL` | `100000 (0x20)` |
| `SHR` | `100001 (0x21)` |
| `SAR` | `100010 (0x22)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-mem-0`](dictionary/by-encoding.md#r20-mem-0), [`r20-mem-1`](dictionary/by-encoding.md#r20-mem-1), [`r20-mem-1-2`](dictionary/by-encoding.md#r20-mem-1-2), [`r20-mem-1-3`](dictionary/by-encoding.md#r20-mem-1-3), [`r20-mem-1-4`](dictionary/by-encoding.md#r20-mem-1-4), [`r20-mem-2`](dictionary/by-encoding.md#r20-mem-2), [`r20-mem-2-2`](dictionary/by-encoding.md#r20-mem-2-2), [`r20-mem-2-3`](dictionary/by-encoding.md#r20-mem-2-3), [`r20-mem-2-4`](dictionary/by-encoding.md#r20-mem-2-4).

**Operation**

```
n ← rm                                 ; the count: a register, an immediate, or memory
SHL: Rd ← (n ≥ 64) ? 0 : Rd << n
SHR: Rd ← (n ≥ 64) ? 0 : Rd >>u n
SAR: Rd ← (n ≥ 64) ? (Rd < 0 ? -1 : 0) : Rd >>s n
```

**Flags** `N` and `Z` from the result, `V` cleared, `C` the last bit shifted out (bit 63 for `SHL`, bit 0 for `SHR` and `SAR`). **The same flags are written for every count**: a count of zero gives `N` and `Z` from the unchanged operand, `V` = 0 and `C` = 0.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

The count is read as an unsigned 64-bit value, so a count of 64 or more shifts the value entirely away. Page 2 has the three shifts by an immediate 0 to 15. `ASL` and `ASR` (in `SOP`) are the by-one forms in two bytes; rotates are in `BESC`.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-shl"></a>
#### SHL

![SHL, opcode 100000, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/shl/06.svg)

![SHL, opcode 100000, three parcels (modes index) (6 bytes)](figures/w/shl/07.svg)

![SHL, opcode 100000, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/shl/08.svg)

![SHL, opcode 100000, three parcels (modes dp) (6 bytes)](figures/w/shl/09.svg)

![SHL, opcode 100000, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/shl/02.svg)

![SHL, opcode 100000, two parcels (modes index) (4 bytes)](figures/w/shl/03.svg)

![SHL, opcode 100000, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/shl/04.svg)

![SHL, opcode 100000, two parcels (modes dp) (4 bytes)](figures/w/shl/05.svg)

![SHL, opcode 100000, one parcel (2 bytes)](figures/w/shl/01.svg)

```
SHL rm, Rd
```

| Mnemonic | Opcode |
|---|---|
| `SHL` | `100000 (0x20)` |

Operation, flags and exceptions as for the entry SHIFT above; 9 layout forms, each a chart of its own (above).

<a id="w-shr"></a>
#### SHR

![SHR, opcode 100001, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/shr/06.svg)

![SHR, opcode 100001, three parcels (modes index) (6 bytes)](figures/w/shr/07.svg)

![SHR, opcode 100001, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/shr/08.svg)

![SHR, opcode 100001, three parcels (modes dp) (6 bytes)](figures/w/shr/09.svg)

![SHR, opcode 100001, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/shr/02.svg)

![SHR, opcode 100001, two parcels (modes index) (4 bytes)](figures/w/shr/03.svg)

![SHR, opcode 100001, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/shr/04.svg)

![SHR, opcode 100001, two parcels (modes dp) (4 bytes)](figures/w/shr/05.svg)

![SHR, opcode 100001, one parcel (2 bytes)](figures/w/shr/01.svg)

```
SHR rm, Rd
```

| Mnemonic | Opcode |
|---|---|
| `SHR` | `100001 (0x21)` |

Operation, flags and exceptions as for the entry SHIFT above; 9 layout forms, each a chart of its own (above).

<a id="w-sar"></a>
#### SAR

![SAR, opcode 100010, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/sar/06.svg)

![SAR, opcode 100010, three parcels (modes index) (6 bytes)](figures/w/sar/07.svg)

![SAR, opcode 100010, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/sar/08.svg)

![SAR, opcode 100010, three parcels (modes dp) (6 bytes)](figures/w/sar/09.svg)

![SAR, opcode 100010, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/sar/02.svg)

![SAR, opcode 100010, two parcels (modes index) (4 bytes)](figures/w/sar/03.svg)

![SAR, opcode 100010, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/sar/04.svg)

![SAR, opcode 100010, two parcels (modes dp) (4 bytes)](figures/w/sar/05.svg)

![SAR, opcode 100010, one parcel (2 bytes)](figures/w/sar/01.svg)

```
SAR rm, Rd
```

| Mnemonic | Opcode |
|---|---|
| `SAR` | `100010 (0x22)` |

Operation, flags and exceptions as for the entry SHIFT above; 9 layout forms, each a chart of its own (above).


<a id="w-clr"></a>
### CLR: Clear

![CLR, opcode 010011, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/clr/06.svg)

![CLR, opcode 010011, three parcels (modes index) (6 bytes)](figures/w/clr/07.svg)

![CLR, opcode 010011, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/clr/08.svg)

![CLR, opcode 010011, three parcels (modes dp) (6 bytes)](figures/w/clr/09.svg)

![CLR, opcode 010011, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/clr/02.svg)

![CLR, opcode 010011, two parcels (modes index) (4 bytes)](figures/w/clr/03.svg)

![CLR, opcode 010011, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/clr/04.svg)

![CLR, opcode 010011, two parcels (modes dp) (4 bytes)](figures/w/clr/05.svg)

![CLR, opcode 010011, one parcel (2 bytes)](figures/w/clr/01.svg)

**Mnemonics:** `CLR`

**Syntax**

```
CLR rm
```

**Encoding**

![Encoding of CLR](figures/r20-sop-0.svg)

The chart is the layout `r20-sop-0`, Single operand (SOP), one parcel (`len = 00`): The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `CLR` | `010011 (0x13)` | `0000 (0x0)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sop-0`](dictionary/by-encoding.md#r20-sop-0), [`r20-sop-1`](dictionary/by-encoding.md#r20-sop-1), [`r20-sop-1-2`](dictionary/by-encoding.md#r20-sop-1-2), [`r20-sop-1-3`](dictionary/by-encoding.md#r20-sop-1-3), [`r20-sop-1-4`](dictionary/by-encoding.md#r20-sop-1-4), [`r20-sop-2`](dictionary/by-encoding.md#r20-sop-2), [`r20-sop-2-2`](dictionary/by-encoding.md#r20-sop-2-2), [`r20-sop-2-3`](dictionary/by-encoding.md#r20-sop-2-3), [`r20-sop-2-4`](dictionary/by-encoding.md#r20-sop-2-4).

**Operation**

```
rm ← 0
```

**Flags** `N` = 0, `Z` = 1, `V` = 0, `C` = 0.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-com"></a>
### COM: Complement

![COM, opcode 010011, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/com/06.svg)

![COM, opcode 010011, three parcels (modes index) (6 bytes)](figures/w/com/07.svg)

![COM, opcode 010011, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/com/08.svg)

![COM, opcode 010011, three parcels (modes dp) (6 bytes)](figures/w/com/09.svg)

![COM, opcode 010011, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/com/02.svg)

![COM, opcode 010011, two parcels (modes index) (4 bytes)](figures/w/com/03.svg)

![COM, opcode 010011, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/com/04.svg)

![COM, opcode 010011, two parcels (modes dp) (4 bytes)](figures/w/com/05.svg)

![COM, opcode 010011, one parcel (2 bytes)](figures/w/com/01.svg)

**Mnemonics:** `COM`

**Syntax**

```
COM rm
```

**Encoding**

![Encoding of COM](figures/r20-sop-0.svg)

The chart is the layout `r20-sop-0`, Single operand (SOP), one parcel (`len = 00`): The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `COM` | `010011 (0x13)` | `0001 (0x1)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sop-0`](dictionary/by-encoding.md#r20-sop-0), [`r20-sop-1`](dictionary/by-encoding.md#r20-sop-1), [`r20-sop-1-2`](dictionary/by-encoding.md#r20-sop-1-2), [`r20-sop-1-3`](dictionary/by-encoding.md#r20-sop-1-3), [`r20-sop-1-4`](dictionary/by-encoding.md#r20-sop-1-4), [`r20-sop-2`](dictionary/by-encoding.md#r20-sop-2), [`r20-sop-2-2`](dictionary/by-encoding.md#r20-sop-2-2), [`r20-sop-2-3`](dictionary/by-encoding.md#r20-sop-2-3), [`r20-sop-2-4`](dictionary/by-encoding.md#r20-sop-2-4).

**Operation**

```
rm ← NOT rm
```

**Flags** `N` and `Z` from the result, `V` = 0, `C` = 1 (the PDP-11 rule).

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

A two-byte instruction for a register operand.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-tst"></a>
### TST: Test

![TST, opcode 010011, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/tst/06.svg)

![TST, opcode 010011, three parcels (modes index) (6 bytes)](figures/w/tst/07.svg)

![TST, opcode 010011, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/tst/08.svg)

![TST, opcode 010011, three parcels (modes dp) (6 bytes)](figures/w/tst/09.svg)

![TST, opcode 010011, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/tst/02.svg)

![TST, opcode 010011, two parcels (modes index) (4 bytes)](figures/w/tst/03.svg)

![TST, opcode 010011, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/tst/04.svg)

![TST, opcode 010011, two parcels (modes dp) (4 bytes)](figures/w/tst/05.svg)

![TST, opcode 010011, one parcel (2 bytes)](figures/w/tst/01.svg)

**Mnemonics:** `TST`

**Syntax**

```
TST rm
```

**Encoding**

![Encoding of TST](figures/r20-sop-0.svg)

The chart is the layout `r20-sop-0`, Single operand (SOP), one parcel (`len = 00`): The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `TST` | `010011 (0x13)` | `0101 (0x5)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sop-0`](dictionary/by-encoding.md#r20-sop-0), [`r20-sop-1`](dictionary/by-encoding.md#r20-sop-1), [`r20-sop-1-2`](dictionary/by-encoding.md#r20-sop-1-2), [`r20-sop-1-3`](dictionary/by-encoding.md#r20-sop-1-3), [`r20-sop-1-4`](dictionary/by-encoding.md#r20-sop-1-4), [`r20-sop-2`](dictionary/by-encoding.md#r20-sop-2), [`r20-sop-2-2`](dictionary/by-encoding.md#r20-sop-2-2), [`r20-sop-2-3`](dictionary/by-encoding.md#r20-sop-2-3), [`r20-sop-2-4`](dictionary/by-encoding.md#r20-sop-2-4).

**Operation**

```
set flags from rm; nothing is written
```

**Flags** `N` and `Z` from the operand, `V` = 0, `C` = 0.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-asl"></a>
### ASL: Arithmetic shift left by one

![ASL, opcode 010011, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/asl/06.svg)

![ASL, opcode 010011, three parcels (modes index) (6 bytes)](figures/w/asl/07.svg)

![ASL, opcode 010011, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/asl/08.svg)

![ASL, opcode 010011, three parcels (modes dp) (6 bytes)](figures/w/asl/09.svg)

![ASL, opcode 010011, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/asl/02.svg)

![ASL, opcode 010011, two parcels (modes index) (4 bytes)](figures/w/asl/03.svg)

![ASL, opcode 010011, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/asl/04.svg)

![ASL, opcode 010011, two parcels (modes dp) (4 bytes)](figures/w/asl/05.svg)

![ASL, opcode 010011, one parcel (2 bytes)](figures/w/asl/01.svg)

**Mnemonics:** `ASL`

**Syntax**

```
ASL rm
```

**Encoding**

![Encoding of ASL](figures/r20-sop-0.svg)

The chart is the layout `r20-sop-0`, Single operand (SOP), one parcel (`len = 00`): The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `ASL` | `010011 (0x13)` | `1000 (0x8)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sop-0`](dictionary/by-encoding.md#r20-sop-0), [`r20-sop-1`](dictionary/by-encoding.md#r20-sop-1), [`r20-sop-1-2`](dictionary/by-encoding.md#r20-sop-1-2), [`r20-sop-1-3`](dictionary/by-encoding.md#r20-sop-1-3), [`r20-sop-1-4`](dictionary/by-encoding.md#r20-sop-1-4), [`r20-sop-2`](dictionary/by-encoding.md#r20-sop-2), [`r20-sop-2-2`](dictionary/by-encoding.md#r20-sop-2-2), [`r20-sop-2-3`](dictionary/by-encoding.md#r20-sop-2-3), [`r20-sop-2-4`](dictionary/by-encoding.md#r20-sop-2-4).

**Operation**

```
C ← rm[63] ; rm ← rm << 1
```

**Flags** `N` and `Z` from the result, `C` the bit shifted out of bit 63, `V` = `N` xor `C` (set if the sign changed: the PDP-11 rule).

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

The by-one form of `SHL` in two bytes.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-asr"></a>
### ASR: Arithmetic shift right by one

![ASR, opcode 010011, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/asr/06.svg)

![ASR, opcode 010011, three parcels (modes index) (6 bytes)](figures/w/asr/07.svg)

![ASR, opcode 010011, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/asr/08.svg)

![ASR, opcode 010011, three parcels (modes dp) (6 bytes)](figures/w/asr/09.svg)

![ASR, opcode 010011, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/asr/02.svg)

![ASR, opcode 010011, two parcels (modes index) (4 bytes)](figures/w/asr/03.svg)

![ASR, opcode 010011, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/asr/04.svg)

![ASR, opcode 010011, two parcels (modes dp) (4 bytes)](figures/w/asr/05.svg)

![ASR, opcode 010011, one parcel (2 bytes)](figures/w/asr/01.svg)

**Mnemonics:** `ASR`

**Syntax**

```
ASR rm
```

**Encoding**

![Encoding of ASR](figures/r20-sop-0.svg)

The chart is the layout `r20-sop-0`, Single operand (SOP), one parcel (`len = 00`): The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `ASR` | `010011 (0x13)` | `1001 (0x9)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sop-0`](dictionary/by-encoding.md#r20-sop-0), [`r20-sop-1`](dictionary/by-encoding.md#r20-sop-1), [`r20-sop-1-2`](dictionary/by-encoding.md#r20-sop-1-2), [`r20-sop-1-3`](dictionary/by-encoding.md#r20-sop-1-3), [`r20-sop-1-4`](dictionary/by-encoding.md#r20-sop-1-4), [`r20-sop-2`](dictionary/by-encoding.md#r20-sop-2), [`r20-sop-2-2`](dictionary/by-encoding.md#r20-sop-2-2), [`r20-sop-2-3`](dictionary/by-encoding.md#r20-sop-2-3), [`r20-sop-2-4`](dictionary/by-encoding.md#r20-sop-2-4).

**Operation**

```
C ← rm[0] ; rm ← rm >>s 1
```

**Flags** `N` and `Z` from the result, `C` the bit shifted out of bit 0, `V` = 0.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

The by-one form of `SAR` in two bytes.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).
<!-- /entries:9.8 -->

## 9.9 Bits, bytes and text

**9.9.1** The bit-and-field escape provides `CLZ`, `CTZ`, `CLO`, `CTO` (count leading and trailing zeros and ones), `POPCNT`, `BSWAP`, `BSWAPW`, `BSWAPL` and `BITREV`. *(opcode `001100 (0x0C)`)*

**9.9.2** `EXTB` and `EXTZB` extract a bitfield at a position and width, sign- or zero-extended, and `INSB` inserts one; the position and width are in the third parcel, so these are six bytes. *(D)*

**9.9.3** `XNORPOP` computes the population count of the exclusive-nor of two registers. *(D)*

**9.9.4** `CLMULL` and `CLMULH` are the low and high halves of a carry-less multiply; no polynomial is built into the architecture. *(D)*

**9.9.5** `UTF8LEN`, `UTF8DEC` and `UTF8ENC` find the length of, decode and encode a UTF-8 sequence, and reject overlong forms, surrogates, out-of-range values and bad continuation bytes. *(D)*

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

![Encoding of COUNT](figures/r20-besc-1.svg)

The chart is the layout `r20-besc-1`, Bits and fields (BESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `CLZ` | `001100 (0x0C)` | `00000000 (0x00)` |
| `CTZ` | `001100 (0x0C)` | `00000001 (0x01)` |
| `CLO` | `001100 (0x0C)` | `00000010 (0x02)` |
| `CTO` | `001100 (0x0C)` | `00000011 (0x03)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-besc-1`](dictionary/by-encoding.md#r20-besc-1), [`r20-besc-2`](dictionary/by-encoding.md#r20-besc-2).

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

**Why it is here.** `BESC` is the bit-manipulation group: bit manipulation is not an extension on a machine that does filesystem work, bignum arithmetic and the like. The counts are the VAX `FFS` and `FFC` idiom (find first set, find first clear). LoongArch is the model for putting them in the base: it has `CLO`, `CLZ`, `CTO`, `CTZ` there, which is the decisive argument for giving `BESC` a top-level opcode. The compiler emits none of them, since C has no operator for them; the corpus shows zero uses.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-clz"></a>
#### CLZ

![CLZ, opcode 001100, three parcels, sub-opcode 00000000 (6 bytes)](figures/w/clz/02.svg)

![CLZ, opcode 001100, two parcels, sub-opcode 00000000 (4 bytes)](figures/w/clz/01.svg)

```
CLZ Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `CLZ` | `001100 (0x0C)` | `00000000 (0x00)` |

Operation, flags and exceptions as for the entry COUNT above; 2 layout forms, each a chart of its own (above).

<a id="w-ctz"></a>
#### CTZ

![CTZ, opcode 001100, three parcels, sub-opcode 00000001 (6 bytes)](figures/w/ctz/02.svg)

![CTZ, opcode 001100, two parcels, sub-opcode 00000001 (4 bytes)](figures/w/ctz/01.svg)

```
CTZ Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `CTZ` | `001100 (0x0C)` | `00000001 (0x01)` |

Operation, flags and exceptions as for the entry COUNT above; 2 layout forms, each a chart of its own (above).

<a id="w-clo"></a>
#### CLO

![CLO, opcode 001100, three parcels, sub-opcode 00000010 (6 bytes)](figures/w/clo/02.svg)

![CLO, opcode 001100, two parcels, sub-opcode 00000010 (4 bytes)](figures/w/clo/01.svg)

```
CLO Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `CLO` | `001100 (0x0C)` | `00000010 (0x02)` |

Operation, flags and exceptions as for the entry COUNT above; 2 layout forms, each a chart of its own (above).

<a id="w-cto"></a>
#### CTO

![CTO, opcode 001100, three parcels, sub-opcode 00000011 (6 bytes)](figures/w/cto/02.svg)

![CTO, opcode 001100, two parcels, sub-opcode 00000011 (4 bytes)](figures/w/cto/01.svg)

```
CTO Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `CTO` | `001100 (0x0C)` | `00000011 (0x03)` |

Operation, flags and exceptions as for the entry COUNT above; 2 layout forms, each a chart of its own (above).


<a id="w-popcnt"></a>
### POPCNT: Population count

![POPCNT, opcode 001100, three parcels, sub-opcode 00000100 (6 bytes)](figures/w/popcnt/02.svg)

![POPCNT, opcode 001100, two parcels, sub-opcode 00000100 (4 bytes)](figures/w/popcnt/01.svg)

**Mnemonics:** `POPCNT`

**Syntax**

```
POPCNT Rs, Rd
```

**Encoding**

![Encoding of POPCNT](figures/r20-besc-1.svg)

The chart is the layout `r20-besc-1`, Bits and fields (BESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `POPCNT` | `001100 (0x0C)` | `00000100 (0x04)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-besc-1`](dictionary/by-encoding.md#r20-besc-1), [`r20-besc-2`](dictionary/by-encoding.md#r20-besc-2).

**Operation**

```
Rd ← number of one bits in Rs
```

**Flags** None written.

**Exceptions** None.

**Why it is here.** One of the counts of `BESC`; it is also the building block of `XNORPOP`. A compiler needs `__builtin_popcount` to emit it, so the corpus shows no use (see `COUNT`).

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


### BSWAP: Byte swap

**Mnemonics:** `BSWAP`, `BSWAPW`, `BSWAPL`

**Syntax**

```
BSWAP Rs, Rd
BSWAPW Rs, Rd
BSWAPL Rs, Rd
```

**Encoding**

![Encoding of BSWAP](figures/r20-besc-1.svg)

The chart is the layout `r20-besc-1`, Bits and fields (BESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `BSWAP` | `001100 (0x0C)` | `00000101 (0x05)` |
| `BSWAPW` | `001100 (0x0C)` | `00000110 (0x06)` |
| `BSWAPL` | `001100 (0x0C)` | `00000111 (0x07)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-besc-1`](dictionary/by-encoding.md#r20-besc-1), [`r20-besc-2`](dictionary/by-encoding.md#r20-besc-2).

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

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-bswap"></a>
#### BSWAP

![BSWAP, opcode 001100, three parcels, sub-opcode 00000101 (6 bytes)](figures/w/bswap/02.svg)

![BSWAP, opcode 001100, two parcels, sub-opcode 00000101 (4 bytes)](figures/w/bswap/01.svg)

```
BSWAP Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `BSWAP` | `001100 (0x0C)` | `00000101 (0x05)` |

Operation, flags and exceptions as for the entry BSWAP above; 2 layout forms, each a chart of its own (above).

<a id="w-bswapw"></a>
#### BSWAPW

![BSWAPW, opcode 001100, three parcels, sub-opcode 00000110 (6 bytes)](figures/w/bswapw/02.svg)

![BSWAPW, opcode 001100, two parcels, sub-opcode 00000110 (4 bytes)](figures/w/bswapw/01.svg)

```
BSWAPW Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `BSWAPW` | `001100 (0x0C)` | `00000110 (0x06)` |

Operation, flags and exceptions as for the entry BSWAP above; 2 layout forms, each a chart of its own (above).

<a id="w-bswapl"></a>
#### BSWAPL

![BSWAPL, opcode 001100, three parcels, sub-opcode 00000111 (6 bytes)](figures/w/bswapl/02.svg)

![BSWAPL, opcode 001100, two parcels, sub-opcode 00000111 (4 bytes)](figures/w/bswapl/01.svg)

```
BSWAPL Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `BSWAPL` | `001100 (0x0C)` | `00000111 (0x07)` |

Operation, flags and exceptions as for the entry BSWAP above; 2 layout forms, each a chart of its own (above).


<a id="w-bitrev"></a>
### BITREV: Reverse the bits

![BITREV, opcode 001100, three parcels, sub-opcode 00001000 (6 bytes)](figures/w/bitrev/02.svg)

![BITREV, opcode 001100, two parcels, sub-opcode 00001000 (4 bytes)](figures/w/bitrev/01.svg)

**Mnemonics:** `BITREV`

**Syntax**

```
BITREV Rs, Rd
```

**Encoding**

![Encoding of BITREV](figures/r20-besc-1.svg)

The chart is the layout `r20-besc-1`, Bits and fields (BESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `BITREV` | `001100 (0x0C)` | `00001000 (0x08)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-besc-1`](dictionary/by-encoding.md#r20-besc-1), [`r20-besc-2`](dictionary/by-encoding.md#r20-besc-2).

**Operation**

```
Rd ← Rs with bit i moved to bit 63-i
```

**Flags** None written.

**Exceptions** None.

**Why it is here.** Part of the `BESC` group, borrowed with the other LoongArch bit operations (`REVB`, `REVH`, `BITREV`). No workload from the corpus is recorded.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-ror"></a>
### ROR: Rotate right by a register count

![ROR, opcode 001100, three parcels, sub-opcode 00010000 (6 bytes)](figures/w/ror/02.svg)

![ROR, opcode 001100, two parcels, sub-opcode 00010000 (4 bytes)](figures/w/ror/01.svg)

**Mnemonics:** `ROR`

**Syntax**

```
ROR Ra, Rb, Rd
```

**Encoding**

![Encoding of ROR](figures/r20-besc-1.svg)

The chart is the layout `r20-besc-1`, Bits and fields (BESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `ROR` | `001100 (0x0C)` | `00010000 (0x10)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-besc-1`](dictionary/by-encoding.md#r20-besc-1), [`r20-besc-2`](dictionary/by-encoding.md#r20-besc-2).

**Operation**

```
Rd ← Ra rotated right by (Rb mod 64)
```

**Flags** None written (rotates write no flags).

**Exceptions** None.

There is no rotate left instruction: `ROL rs, #n, rd` is an assembler spelling of `RORI rs, #(64-n), rd`. No rotate is through carry; multi-word shifting uses `DSHR`.

**Why it is here.** One rotate direction suffices and `ROR` is the one to keep: `ROL x, #n` is exactly `ROR x, #(64-n)`, and a funnel shifter yields `ROR` directly. No rotate is through carry (see `DSHR`). `ROR` is in `BESC`, not the ALU group: cryptographic code rotates by compile-time constants, so a four-byte immediate form is needed either way, and the register-count form has almost no users. Rotates write no flags.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-rori"></a>
<a id="w-rol"></a>
### RORI: Rotate right by an immediate

![RORI, opcode 001100, three parcels, sub-opcode 00010001 (6 bytes)](figures/w/rori/02.svg)

![RORI, opcode 001100, two parcels, sub-opcode 00010001 (4 bytes)](figures/w/rori/01.svg)

**Mnemonics:** `RORI`  (aliases: `ROL`)

**Syntax**

```
RORI Rs, #n, Rd
ROL Rs, #n, Rd        ; assembles to RORI Rs, #(64-n), Rd
```

**Encoding**

![Encoding of RORI](figures/r20-besc-1-2.svg)

The chart is the layout `r20-besc-1-2`, Bits and fields (BESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `RORI` | `001100 (0x0C)` | `00010001 (0x11)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-besc-1-2`](dictionary/by-encoding.md#r20-besc-1-2), [`r20-besc-2-2`](dictionary/by-encoding.md#r20-besc-2-2).

**Operation**

```
Rd ← Rs rotated right by (n mod 64)
```

**Flags** None written.

**Exceptions** None.

Four bytes: the count is in the low byte of parcel 1.

**Why it is here.** It has its own mnemonic because an immediate count and a register count are different encodings. `ROL Rs, #n, Rd` is accepted by the assembler as `RORI Rs, #(64-n), Rd`: the complement costs nothing at assembly time, so there is no reason to make programmers do it, and a register-count `ROL` is rejected so that one mnemonic stays one instruction.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-rol"></a>
**`ROL`** is an alias of `RORI`: the assembler writes it as that word.


<a id="w-rori32"></a>
### RORI32: Rotate right by an immediate, 32 bits

![RORI32, opcode 001100, three parcels, sub-opcode 00010010 (6 bytes)](figures/w/rori32/02.svg)

![RORI32, opcode 001100, two parcels, sub-opcode 00010010 (4 bytes)](figures/w/rori32/01.svg)

**Mnemonics:** `RORI32`

**Syntax**

```
RORI32 Rs, #n, Rd
```

**Encoding**

![Encoding of RORI32](figures/r20-besc-1-2.svg)

The chart is the layout `r20-besc-1-2`, Bits and fields (BESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `RORI32` | `001100 (0x0C)` | `00010010 (0x12)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-besc-1-2`](dictionary/by-encoding.md#r20-besc-1-2), [`r20-besc-2-2`](dictionary/by-encoding.md#r20-besc-2-2).

**Operation**

```
Rd ← sext32(ror32(Rs[31:0], n mod 32))
```

**Flags** None written.

**Exceptions** None.

The 32-bit rotate with the result sign-extended like every 32-bit result; the primitive of most hash functions and ciphers.

**Why it is here.** A 32-bit rotate by a constant, the shape of crypto and hash inner loops, estimated together with `CBCC` at 22 KB (1.3%) of the compiled image. The result is sign-extended like the rest of the 32-bit operations, so that no instruction is needed after it. It removes 44 `MOVL` instructions in the corpus (the demand analysis already removes nearly all of them).

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-dshr"></a>
### DSHR: Double-width funnel shift right

![DSHR, opcode 001100, three parcels, sub-opcode 00100000 (6 bytes)](figures/w/dshr/02.svg)

![DSHR, opcode 001100, two parcels, sub-opcode 00100000 (4 bytes)](figures/w/dshr/01.svg)

**Mnemonics:** `DSHR`

**Syntax**

```
DSHR Ra, Rb, #n, Rd
```

**Encoding**

![Encoding of DSHR](figures/r20-besc-1.svg)

The chart is the layout `r20-besc-1`, Bits and fields (BESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `DSHR` | `001100 (0x0C)` | `00100000 (0x20)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-besc-1`](dictionary/by-encoding.md#r20-besc-1), [`r20-besc-2-3`](dictionary/by-encoding.md#r20-besc-2-3).

**Operation**

```
t ← Ra:Rb                    ; 128 bits, Ra the high half
Rd ← (t >> n)[63:0]          ; n = 0..63
```

**Flags** None written.

**Exceptions** None.

x86 `SHRD`, ARM `EXTR`. Six bytes (the count is in parcel 2). A 128-bit left shift by k is `DSHR hi, hi, lo, #(64-k)` then `SHL #k, lo`.

**Why it is here.** A double-width funnel shift (x86 `SHRD`, ARM `EXTR`), the right primitive for multi-word shifting. Two instructions shift a 128-bit value by any distance, where rotate-through-carry takes one bit per instruction, and that is why no rotate is through carry. It also subsumes `ROR` when both sources are the same register. It leaves every flag alone.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


### EXTB: Extract a bit field

**Mnemonics:** `EXTB`, `EXTZB`

**Syntax**

```
EXTB Rs, #pos, #width, Rd        ; sign-extended
EXTZB Rs, #pos, #width, Rd       ; zero-extended
```

**Encoding**

![Encoding of EXTB](figures/r20-besc-1.svg)

The chart is the layout `r20-besc-1`, Bits and fields (BESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `EXTB` | `001100 (0x0C)` | `00100001 (0x21)` |
| `EXTZB` | `001100 (0x0C)` | `00100010 (0x22)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-besc-1`](dictionary/by-encoding.md#r20-besc-1), [`r20-besc-2-3`](dictionary/by-encoding.md#r20-besc-2-3).

**Operation**

```
Rd ← ext((Rs >> pos)[width-1:0])          ; sext for EXTB, zext for EXTZB; width 0 or > 64 means 64
```

**Flags** None written.

**Exceptions** None.

Six bytes (position and width are in parcel 2), so these exist at `len = 10` only.

**Why it is here.** Bit-field extract and insert are the VAX `EXTV`, `EXTZV` and `INSV` idiom. The compiler does not use them: the shift-pair extraction pattern occurs 151 times in 26 files of the corpus, about 600 bytes at best (0.03%), and there are four true bit-field extracts in all. They are for hand-written protocol and bit-stream code.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-extb"></a>
#### EXTB

![EXTB, opcode 001100, three parcels, sub-opcode 00100001 (6 bytes)](figures/w/extb/02.svg)

![EXTB, opcode 001100, two parcels, sub-opcode 00100001 (4 bytes)](figures/w/extb/01.svg)

```
EXTB Rs, #pos, #width, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `EXTB` | `001100 (0x0C)` | `00100001 (0x21)` |

Operation, flags and exceptions as for the entry EXTB above; 2 layout forms, each a chart of its own (above).

<a id="w-extzb"></a>
#### EXTZB

![EXTZB, opcode 001100, three parcels, sub-opcode 00100010 (6 bytes)](figures/w/extzb/02.svg)

![EXTZB, opcode 001100, two parcels, sub-opcode 00100010 (4 bytes)](figures/w/extzb/01.svg)

```
EXTZB Rs, #pos, #width, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `EXTZB` | `001100 (0x0C)` | `00100010 (0x22)` |

Operation, flags and exceptions as for the entry EXTB above; 2 layout forms, each a chart of its own (above).


<a id="w-insb"></a>
### INSB: Insert a bit field

![INSB, opcode 001100, three parcels, sub-opcode 00100011 (6 bytes)](figures/w/insb/02.svg)

![INSB, opcode 001100, two parcels, sub-opcode 00100011 (4 bytes)](figures/w/insb/01.svg)

**Mnemonics:** `INSB`

**Syntax**

```
INSB Rs, #pos, #width, Rd
```

**Encoding**

![Encoding of INSB](figures/r20-besc-1.svg)

The chart is the layout `r20-besc-1`, Bits and fields (BESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `INSB` | `001100 (0x0C)` | `00100011 (0x23)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-besc-1`](dictionary/by-encoding.md#r20-besc-1), [`r20-besc-2-3`](dictionary/by-encoding.md#r20-besc-2-3).

**Operation**

```
mask ← ((1 << width) - 1) << pos
Rd ← (Rd AND NOT mask) OR ((Rs << pos) AND mask)
```

**Flags** None written.

**Exceptions** None.

Six bytes. `Rd` is both source and destination.

**Why it is here.** The VAX `INSV` idiom, with `EXTB`. No use in the compiled corpus is recorded.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-xnorpop"></a>
### XNORPOP: Population count of the equality of two words

![XNORPOP, opcode 001100, three parcels, sub-opcode 00110000 (6 bytes)](figures/w/xnorpop/02.svg)

![XNORPOP, opcode 001100, two parcels, sub-opcode 00110000 (4 bytes)](figures/w/xnorpop/01.svg)

**Mnemonics:** `XNORPOP`

**Syntax**

```
XNORPOP Ra, Rb, Rd
```

**Encoding**

![Encoding of XNORPOP](figures/r20-besc-1.svg)

The chart is the layout `r20-besc-1`, Bits and fields (BESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `XNORPOP` | `001100 (0x0C)` | `00110000 (0x30)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-besc-1`](dictionary/by-encoding.md#r20-besc-1), [`r20-besc-2`](dictionary/by-encoding.md#r20-besc-2).

**Operation**

```
Rd ← popcount(NOT (Ra XOR Rb))
```

**Flags** None written.

**Exceptions** None.

For binary-activation networks, Hamming distance and bitset intersection cardinality. It does **not** serve sub-1-bit language models (section 8.3).

**Why it is here.** It serves binary-activation networks, Hamming distance, bitset intersection counts and counting a collector's mark bitmap. It does not serve sub-1-bit language models: their activations (in the LittleBit work) are FP16 and the inner loop is a conditional add, not a popcount. The sub-1-bit kernel is bandwidth-bound and belongs to a bus-mastering accelerator, not an opcode (chapter 8).

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


### CLMUL: Carry-less multiply

**Mnemonics:** `CLMULL`, `CLMULH`

**Syntax**

```
CLMULL Ra, Rb, Rd
CLMULH Ra, Rb, Rd
```

**Encoding**

![Encoding of CLMUL](figures/r20-besc-1.svg)

The chart is the layout `r20-besc-1`, Bits and fields (BESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `CLMULL` | `001100 (0x0C)` | `00110001 (0x31)` |
| `CLMULH` | `001100 (0x0C)` | `00110010 (0x32)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-besc-1`](dictionary/by-encoding.md#r20-besc-1), [`r20-besc-2`](dictionary/by-encoding.md#r20-besc-2).

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

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-clmull"></a>
#### CLMULL

![CLMULL, opcode 001100, three parcels, sub-opcode 00110001 (6 bytes)](figures/w/clmull/02.svg)

![CLMULL, opcode 001100, two parcels, sub-opcode 00110001 (4 bytes)](figures/w/clmull/01.svg)

```
CLMULL Ra, Rb, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `CLMULL` | `001100 (0x0C)` | `00110001 (0x31)` |

Operation, flags and exceptions as for the entry CLMUL above; 2 layout forms, each a chart of its own (above).

<a id="w-clmulh"></a>
#### CLMULH

![CLMULH, opcode 001100, three parcels, sub-opcode 00110010 (6 bytes)](figures/w/clmulh/02.svg)

![CLMULH, opcode 001100, two parcels, sub-opcode 00110010 (4 bytes)](figures/w/clmulh/01.svg)

```
CLMULH Ra, Rb, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `CLMULH` | `001100 (0x0C)` | `00110010 (0x32)` |

Operation, flags and exceptions as for the entry CLMUL above; 2 layout forms, each a chart of its own (above).


<a id="w-utf8len"></a>
### UTF8LEN: Length of a UTF-8 sequence from its leading byte

![UTF8LEN, opcode 001100, three parcels, sub-opcode 01000000 (6 bytes)](figures/w/utf8len/02.svg)

![UTF8LEN, opcode 001100, two parcels, sub-opcode 01000000 (4 bytes)](figures/w/utf8len/01.svg)

**Mnemonics:** `UTF8LEN`

**Syntax**

```
UTF8LEN Rs, Rd
```

**Encoding**

![Encoding of UTF8LEN](figures/r20-besc-1.svg)

The chart is the layout `r20-besc-1`, Bits and fields (BESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `UTF8LEN` | `001100 (0x0C)` | `01000000 (0x40)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-besc-1`](dictionary/by-encoding.md#r20-besc-1), [`r20-besc-2`](dictionary/by-encoding.md#r20-besc-2).

**Operation**

```
Rd ← length (1 to 4) implied by the leading byte Rs[7:0]; 0 if it cannot begin a valid sequence
```

**Flags** None written.

**Exceptions** None.

**Why it is here.** Most of what UTF-8 needs is general bit manipulation, but the validity rules are where the bugs are, so the group has three instructions. `UTF8LEN` is the one that is nearly free: `CLO` on the leading byte, mapped to 1, 2, 3 or 4.

**Status** specified; **not yet implemented** in the reference executor.


<a id="w-utf8dec"></a>
### UTF8DEC: Decode a UTF-8 sequence

![UTF8DEC, opcode 001100, three parcels, sub-opcode 01000001 (6 bytes)](figures/w/utf8dec/02.svg)

![UTF8DEC, opcode 001100, two parcels, sub-opcode 01000001 (4 bytes)](figures/w/utf8dec/01.svg)

**Mnemonics:** `UTF8DEC`

**Syntax**

```
UTF8DEC Rs, Rd
```

**Encoding**

![Encoding of UTF8DEC](figures/r20-besc-1.svg)

The chart is the layout `r20-besc-1`, Bits and fields (BESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `UTF8DEC` | `001100 (0x0C)` | `01000001 (0x41)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-besc-1`](dictionary/by-encoding.md#r20-besc-1), [`r20-besc-2`](dictionary/by-encoding.md#r20-besc-2).

**Operation**

```
Rs holds up to 4 bytes, leading byte in bits 7..0
Rd ← the scalar value
V  ← 1 if the sequence is not a valid encoding
```

**Flags** `V` set for a bad continuation byte, an overlong form, a surrogate (U+D800 to U+DFFF), a value above U+10FFFF, or a leading byte of `11000000 (0xC0)`, `11000001 (0xC1)` or `11110101 (0xF5)` to `11111111 (0xFF)`; the length consumed is reported in a scratch field of the status word (details in the instruction-set text, section 4.6.1).

**Exceptions** None.

**Why it is here.** Not for speed but for correctness: overlong forms, surrogates, values above U+10FFFF and the bytes that can never begin a sequence are each a historical security hole, each is three comparators in hardware, and software implementations get them wrong or omit them for speed (about 300 lookup tables).

**Status** specified; **not yet implemented** in the reference executor.


<a id="w-utf8enc"></a>
### UTF8ENC: Encode a Unicode scalar value

![UTF8ENC, opcode 001100, three parcels, sub-opcode 01000010 (6 bytes)](figures/w/utf8enc/02.svg)

![UTF8ENC, opcode 001100, two parcels, sub-opcode 01000010 (4 bytes)](figures/w/utf8enc/01.svg)

**Mnemonics:** `UTF8ENC`

**Syntax**

```
UTF8ENC Rs, Rd
```

**Encoding**

![Encoding of UTF8ENC](figures/r20-besc-1.svg)

The chart is the layout `r20-besc-1`, Bits and fields (BESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `UTF8ENC` | `001100 (0x0C)` | `01000010 (0x42)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-besc-1`](dictionary/by-encoding.md#r20-besc-1), [`r20-besc-2`](dictionary/by-encoding.md#r20-besc-2).

**Operation**

```
Rd ← the UTF-8 bytes of the scalar value Rs, leading byte in bits 7..0
V  ← 1 if Rs is not a Unicode scalar value
```

**Flags** `V` set if `Rs` is not a Unicode scalar value (a surrogate or above U+10FFFF).

**Exceptions** None.

**Why it is here.** The encoding half of the UTF-8 pair; it refuses surrogates and values above U+10FFFF so that an encoder cannot produce what a decoder must reject.

**Status** specified; **not yet implemented** in the reference executor.
<!-- /entries:9.9 -->

## 9.10 Branches and control flow

*Cf. section 6.7 for `TRAP`, `RTI` and `RTT`, and section 6.2 for how a trap enters the kernel; section 9.16 for `CALLI` and `JMPI` in position-independent code.*

**9.10.1** There is an unconditional branch `BR` and fourteen conditional branches, two bytes with an 8-bit displacement, four with 16 bits, six with 32 bits, counting two-byte parcels from the first parcel of the branch: ±256 bytes, ±64 KB, ±4 GB. *(opcodes `110000 (0x30)`-`111110 (0x3E)`)*

**9.10.2** The conditions are `ne`, `eq`, `pl`, `mi`, `vc`, `vs`, `cc`/`hs`, `cs`/`lo`, `ge`, `lt`, `gt`, `le`, `hi` and `los`.

**9.10.3** `SOB Rn, dst` subtracts one from `Rn` and branches if the result is nonzero, forward or backward. *(opcode `111111 (0x3F)`)*

**9.10.4** `CBCC` compares a register with a 5-bit immediate and branches (four bytes, ±1024 parcels); `CBW` takes a 16-bit immediate and a 16-bit displacement (six bytes); `CBRR` compares two registers and branches. None writes the flags. *(D)*

**9.10.5** `JMP` and `CALL` take any address mode; `RET` returns; `JMPI` and `CALLI` jump and call through a pointer in memory; `JTAG` dispatches on the tag in the low three bits of a register; `BTAG` and `BNTAG` branch on a tag. *(D)*

**9.10.6** A call pushes the return address on the stack; there is no link register. *(D)*

*Commentary.* **Precedent.** The complete PDP-11 branch set, which the long-branch problem of the PDP-11 (±256 bytes) made awkward, here reaches ±4 GB with no long-branch opcode and no trampoline, because the displacement widens with the length. `SOB` was the PDP-11's, which could only branch backward. **Trade-offs.** A compare-and-branch that writes no flags cannot feed a second branch that reads them, so a three-way compare is compare-then-branch; the compiler fuses only where the flags are dead afterwards, which costs about 0.4% in code size. **Improvements.** The tag branches serve a Lisp or other tagged runtime in one instruction. **Benefits.** Branch relaxation in the assembler is choosing a length. **Modern comparables.** RISC-V and MIPS are compare-and-branch machines with no flags; AArch64 has `CBZ` and `TBZ`; x86 uses flags like the pdp64's branches. **Use.** `JMPI` and `CALLI` are the shared-library call and the virtual call; `JTAG` is the dispatch of a dynamic-language interpreter. **Impact.** *Kernel:* `JMPI`, `CALLI` and `JTAG` are the shared-library call, the virtual call and the dispatch of an interpreter; `SOB` and `CBCC` are the loops of the kernel's inner routines. *Compiler:* Branch relaxation is choosing a length; fusing a compare and a branch is legal only where the flags are dead afterwards, so the compiler needs a flag-liveness analysis. *Hardware:* The next-PC mux takes the load-return path for the indirect forms; the compare-and-branch compare runs in the branch unit beside the ALU; displacements count parcels, so no shifter is needed.

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

![Encoding of BCC](figures/r20-br-0.svg)

The chart is the layout `r20-br-0`, Conditional branches, one parcel (`len = 00`): The displacement is signed and counts 2-byte parcels from the first parcel of the instruction.

| Mnemonic | Opcode |
|---|---|
| `BR` | `110000 (0x30)` |
| `BNE` | `110001 (0x31)` |
| `BEQ` | `110010 (0x32)` |
| `BPL` | `110011 (0x33)` |
| `BMI` | `110100 (0x34)` |
| `BVC` | `110101 (0x35)` |
| `BVS` | `110110 (0x36)` |
| `BCC` | `110111 (0x37)` |
| `BCS` | `111000 (0x38)` |
| `BGE` | `111001 (0x39)` |
| `BLT` | `111010 (0x3A)` |
| `BGT` | `111011 (0x3B)` |
| `BLE` | `111100 (0x3C)` |
| `BHI` | `111101 (0x3D)` |
| `BLOS` | `111110 (0x3E)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-br-0`](dictionary/by-encoding.md#r20-br-0), [`r20-br-1`](dictionary/by-encoding.md#r20-br-1), [`r20-br-2`](dictionary/by-encoding.md#r20-br-2).

**Operation**

```
if cond(c) then PC ← address of this instruction + 2 × disp
```

**Flags** None written.

**Exceptions** None; a branch to an unmapped or non-executable address faults on the fetch of the target.

Condition numbers: `al` 0 (`BR`), `ne` 1, `eq` 2, `pl` 3, `mi` 4, `vc` 5, `vs` 6, `cc`/`hs` 7, `cs`/`lo` 8, `ge` 9, `lt` 10, `gt` 11, `le` 12, `hi` 13, `los` 14. Conditions on the flags: `ne` `!Z`; `eq` `Z`; `pl` `!N`; `mi` `N`; `vc` `!V`; `vs` `V`; `cc` `!C`; `cs` `C`; `ge` `N == V`; `lt` `N != V`; `gt` `!Z and N == V`; `le` `Z or N != V`; `hi` `!C and !Z`; `los` `C or Z`. The displacement counts 2-byte parcels; the branch reaches ±4 GB with no long-branch instruction.

**Cf.** 6.7 for `TRAP`, `RTI` and `RTT`.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-br"></a>
#### BR

![BR, opcode 110000, three parcels (6 bytes)](figures/w/br/03.svg)

![BR, opcode 110000, two parcels (4 bytes)](figures/w/br/02.svg)

![BR, opcode 110000, one parcel (2 bytes)](figures/w/br/01.svg)

```
BR target
```

| Mnemonic | Opcode |
|---|---|
| `BR` | `110000 (0x30)` |

Operation, flags and exceptions as for the entry BCC above; 3 layout forms, each a chart of its own (above).

<a id="w-bne"></a>
#### BNE

![BNE, opcode 110001, three parcels (6 bytes)](figures/w/bne/03.svg)

![BNE, opcode 110001, two parcels (4 bytes)](figures/w/bne/02.svg)

![BNE, opcode 110001, one parcel (2 bytes)](figures/w/bne/01.svg)

```
BNE target
```

| Mnemonic | Opcode |
|---|---|
| `BNE` | `110001 (0x31)` |

Operation, flags and exceptions as for the entry BCC above; 3 layout forms, each a chart of its own (above).

<a id="w-beq"></a>
#### BEQ

![BEQ, opcode 110010, three parcels (6 bytes)](figures/w/beq/03.svg)

![BEQ, opcode 110010, two parcels (4 bytes)](figures/w/beq/02.svg)

![BEQ, opcode 110010, one parcel (2 bytes)](figures/w/beq/01.svg)

```
BEQ target ... and the rest
```

| Mnemonic | Opcode |
|---|---|
| `BEQ` | `110010 (0x32)` |

Operation, flags and exceptions as for the entry BCC above; 3 layout forms, each a chart of its own (above).

<a id="w-bpl"></a>
#### BPL

![BPL, opcode 110011, three parcels (6 bytes)](figures/w/bpl/03.svg)

![BPL, opcode 110011, two parcels (4 bytes)](figures/w/bpl/02.svg)

![BPL, opcode 110011, one parcel (2 bytes)](figures/w/bpl/01.svg)

| Mnemonic | Opcode |
|---|---|
| `BPL` | `110011 (0x33)` |

Operation, flags and exceptions as for the entry BCC above; 3 layout forms, each a chart of its own (above).

<a id="w-bmi"></a>
#### BMI

![BMI, opcode 110100, three parcels (6 bytes)](figures/w/bmi/03.svg)

![BMI, opcode 110100, two parcels (4 bytes)](figures/w/bmi/02.svg)

![BMI, opcode 110100, one parcel (2 bytes)](figures/w/bmi/01.svg)

| Mnemonic | Opcode |
|---|---|
| `BMI` | `110100 (0x34)` |

Operation, flags and exceptions as for the entry BCC above; 3 layout forms, each a chart of its own (above).

<a id="w-bvc"></a>
#### BVC

![BVC, opcode 110101, three parcels (6 bytes)](figures/w/bvc/03.svg)

![BVC, opcode 110101, two parcels (4 bytes)](figures/w/bvc/02.svg)

![BVC, opcode 110101, one parcel (2 bytes)](figures/w/bvc/01.svg)

| Mnemonic | Opcode |
|---|---|
| `BVC` | `110101 (0x35)` |

Operation, flags and exceptions as for the entry BCC above; 3 layout forms, each a chart of its own (above).

<a id="w-bvs"></a>
#### BVS

![BVS, opcode 110110, three parcels (6 bytes)](figures/w/bvs/03.svg)

![BVS, opcode 110110, two parcels (4 bytes)](figures/w/bvs/02.svg)

![BVS, opcode 110110, one parcel (2 bytes)](figures/w/bvs/01.svg)

| Mnemonic | Opcode |
|---|---|
| `BVS` | `110110 (0x36)` |

Operation, flags and exceptions as for the entry BCC above; 3 layout forms, each a chart of its own (above).

<a id="w-bcc"></a>
#### BCC

![BCC, opcode 110111, three parcels (6 bytes)](figures/w/bcc/03.svg)

![BCC, opcode 110111, two parcels (4 bytes)](figures/w/bcc/02.svg)

![BCC, opcode 110111, one parcel (2 bytes)](figures/w/bcc/01.svg)

| Mnemonic | Opcode |
|---|---|
| `BCC` | `110111 (0x37)` |

Operation, flags and exceptions as for the entry BCC above; 3 layout forms, each a chart of its own (above).

<a id="w-bcs"></a>
#### BCS

![BCS, opcode 111000, three parcels (6 bytes)](figures/w/bcs/03.svg)

![BCS, opcode 111000, two parcels (4 bytes)](figures/w/bcs/02.svg)

![BCS, opcode 111000, one parcel (2 bytes)](figures/w/bcs/01.svg)

| Mnemonic | Opcode |
|---|---|
| `BCS` | `111000 (0x38)` |

Operation, flags and exceptions as for the entry BCC above; 3 layout forms, each a chart of its own (above).

<a id="w-bge"></a>
#### BGE

![BGE, opcode 111001, three parcels (6 bytes)](figures/w/bge/03.svg)

![BGE, opcode 111001, two parcels (4 bytes)](figures/w/bge/02.svg)

![BGE, opcode 111001, one parcel (2 bytes)](figures/w/bge/01.svg)

| Mnemonic | Opcode |
|---|---|
| `BGE` | `111001 (0x39)` |

Operation, flags and exceptions as for the entry BCC above; 3 layout forms, each a chart of its own (above).

<a id="w-blt"></a>
#### BLT

![BLT, opcode 111010, three parcels (6 bytes)](figures/w/blt/03.svg)

![BLT, opcode 111010, two parcels (4 bytes)](figures/w/blt/02.svg)

![BLT, opcode 111010, one parcel (2 bytes)](figures/w/blt/01.svg)

| Mnemonic | Opcode |
|---|---|
| `BLT` | `111010 (0x3A)` |

Operation, flags and exceptions as for the entry BCC above; 3 layout forms, each a chart of its own (above).

<a id="w-bgt"></a>
#### BGT

![BGT, opcode 111011, three parcels (6 bytes)](figures/w/bgt/03.svg)

![BGT, opcode 111011, two parcels (4 bytes)](figures/w/bgt/02.svg)

![BGT, opcode 111011, one parcel (2 bytes)](figures/w/bgt/01.svg)

| Mnemonic | Opcode |
|---|---|
| `BGT` | `111011 (0x3B)` |

Operation, flags and exceptions as for the entry BCC above; 3 layout forms, each a chart of its own (above).

<a id="w-ble"></a>
#### BLE

![BLE, opcode 111100, three parcels (6 bytes)](figures/w/ble/03.svg)

![BLE, opcode 111100, two parcels (4 bytes)](figures/w/ble/02.svg)

![BLE, opcode 111100, one parcel (2 bytes)](figures/w/ble/01.svg)

| Mnemonic | Opcode |
|---|---|
| `BLE` | `111100 (0x3C)` |

Operation, flags and exceptions as for the entry BCC above; 3 layout forms, each a chart of its own (above).

<a id="w-bhi"></a>
#### BHI

![BHI, opcode 111101, three parcels (6 bytes)](figures/w/bhi/03.svg)

![BHI, opcode 111101, two parcels (4 bytes)](figures/w/bhi/02.svg)

![BHI, opcode 111101, one parcel (2 bytes)](figures/w/bhi/01.svg)

| Mnemonic | Opcode |
|---|---|
| `BHI` | `111101 (0x3D)` |

Operation, flags and exceptions as for the entry BCC above; 3 layout forms, each a chart of its own (above).

<a id="w-blos"></a>
#### BLOS

![BLOS, opcode 111110, three parcels (6 bytes)](figures/w/blos/03.svg)

![BLOS, opcode 111110, two parcels (4 bytes)](figures/w/blos/02.svg)

![BLOS, opcode 111110, one parcel (2 bytes)](figures/w/blos/01.svg)

| Mnemonic | Opcode |
|---|---|
| `BLOS` | `111110 (0x3E)` |

Operation, flags and exceptions as for the entry BCC above; 3 layout forms, each a chart of its own (above).

<a id="w-bhis"></a>
#### BHIS

An alias of [`BCC`](#w-bcc): the assembler writes it as that word.

<a id="w-blo"></a>
#### BLO

An alias of [`BCS`](#w-bcs): the assembler writes it as that word.


<a id="w-sob"></a>
### SOB: Subtract one and branch

![SOB, opcode 111111, three parcels (6 bytes)](figures/w/sob/02.svg)

![SOB, opcode 111111, two parcels (4 bytes)](figures/w/sob/01.svg)

**Mnemonics:** `SOB`

**Syntax**

```
SOB Rn, target
```

**Encoding**

![Encoding of SOB](figures/r20-sob-1.svg)

The chart is the layout `r20-sob-1`, SOB, two parcels (`len = 01`): The displacement is signed and counts parcels.

| Mnemonic | Opcode |
|---|---|
| `SOB` | `111111 (0x3F)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sob-1`](dictionary/by-encoding.md#r20-sob-1), [`r20-sob-2`](dictionary/by-encoding.md#r20-sob-2).

**Operation**

```
Rn ← Rn - 1
if Rn ≠ 0 then PC ← address of this instruction + 2 × disp
```

**Flags** None written.

**Exceptions** None.

From the PDP-11, where it could branch only backward; here the signed displacement goes either way. Four bytes at least.

**Why it is here.** Taken from the PDP-11, at the branch group's one free opcode. The PDP-11's could only branch backward (a 6-bit unsigned displacement); this one branches either way. Against the `cbnz` idiom of other architectures it does not save bytes (`DEC` plus `BNE` is also four) but it saves an instruction issue, a cycle per iteration on a machine that does not pipeline: same size, one instruction fewer (static `dec; bne` pairs exist).

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


### CBCC: Compare and branch on condition

**Mnemonics:** `CBNE`, `CBEQ`, `CBPL`, `CBMI`, `CBVC`, `CBVS`, `CBCC`, `CBCS`, `CBGE`, `CBLT`, `CBGT`, `CBLE`, `CBHI`, `CBLOS`  (aliases: `CBHIS`, `CBLO`)

**Syntax**

```
CBNE Rd, #imm, target
CBEQ Ra, Rb, target ... and the rest
```

**Encoding**

![Encoding of CBCC](figures/r20-cb-1.svg)

The chart is the layout `r20-cb-1`, Compare and branch, two parcels (`len = 01`): `low` is the condition; the immediate and the displacement are signed.

| Mnemonic | Opcode | `low` |
|---|---|---|
| `CBNE` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `0001 (0x1)`, `0001 (0x1)`, `0001 (0x1)` |
| `CBEQ` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `0010 (0x2)`, `0010 (0x2)`, `0010 (0x2)` |
| `CBPL` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `0011 (0x3)`, `0011 (0x3)`, `0011 (0x3)` |
| `CBMI` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `0100 (0x4)`, `0100 (0x4)`, `0100 (0x4)` |
| `CBVC` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `0101 (0x5)`, `0101 (0x5)`, `0101 (0x5)` |
| `CBVS` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `0110 (0x6)`, `0110 (0x6)`, `0110 (0x6)` |
| `CBCC` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `0111 (0x7)`, `0111 (0x7)`, `0111 (0x7)` |
| `CBCS` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `1000 (0x8)`, `1000 (0x8)`, `1000 (0x8)` |
| `CBGE` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `1001 (0x9)`, `1001 (0x9)`, `1001 (0x9)` |
| `CBLT` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `1010 (0xA)`, `1010 (0xA)`, `1010 (0xA)` |
| `CBGT` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `1011 (0xB)`, `1011 (0xB)`, `1011 (0xB)` |
| `CBLE` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `1100 (0xC)`, `1100 (0xC)`, `1100 (0xC)` |
| `CBHI` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `1101 (0xD)`, `1101 (0xD)`, `1101 (0xD)` |
| `CBLOS` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `1110 (0xE)`, `1110 (0xE)`, `1110 (0xE)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-cb-1`](dictionary/by-encoding.md#r20-cb-1), [`r20-cb-1-2`](dictionary/by-encoding.md#r20-cb-1-2), [`r20-cb-2`](dictionary/by-encoding.md#r20-cb-2), [`r20-cb-2-2`](dictionary/by-encoding.md#r20-cb-2-2), [`r20-cb-2-3`](dictionary/by-encoding.md#r20-cb-2-3).

**Operation**

```
tmp ← Rd - (imm or Rb)         ; as CMP, for the decision only
if cond(c) on that comparison then PC ← address of this instruction + 2 × disp
```

**Flags** **None written**: the instruction computes the comparison for its own decision and leaves `N Z V C` as they were.

**Exceptions** None.

Three encodings, chosen by the assembler: `CBCC` (`101000 (0x28)`, a 5-bit signed immediate -16 to 15, a displacement of ±1024 parcels at four bytes or 27 bits at six), `CBW` (`101001 (0x29)`, a 16-bit immediate and a 16-bit displacement, six bytes) and `CBRR` (`101010 (0x2A)`, two registers, ±2,048 parcels at four bytes or 28 bits at six). There is no `len = 00` form. A target in another section is refused.

**Why it is here.** A fused compare-and-branch in the reserved opcode `101000 (0x28)`, estimated with `RORI32` at 22 KB (1.3%) of the image. The wide-immediate `CBCC` removes 11,735 instructions (3.4%) and 1,828 bytes; `CBRR`, the register-register compare-and-branch, removes 4,631 instructions (1.4%) and 142 bytes. It is not a replacement for flags: LoongArch and RISC-V chose fused compare-and-branch instead of flags, and this architecture declines that (9.20) because it needs a comparator in the branch unit and a third read port; here the fused form is added beside the flags. `CBCC` writes no flags.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-cbne"></a>
#### CBNE

![CBNE, opcode 101000, three parcels (6 bytes)](figures/w/cbne/02.svg)

![CBNE, opcode 101001, three parcels (6 bytes)](figures/w/cbne/03.svg)

![CBNE, opcode 101010, three parcels (6 bytes)](figures/w/cbne/05.svg)

![CBNE, opcode 101000, two parcels (4 bytes)](figures/w/cbne/01.svg)

![CBNE, opcode 101010, two parcels (4 bytes)](figures/w/cbne/04.svg)

```
CBNE Rd, #imm, target
```

| Mnemonic | Opcode | `low` |
|---|---|---|
| `CBNE` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `0001 (0x1)`, `0001 (0x1)`, `0001 (0x1)` |

Operation, flags and exceptions as for the entry CBCC above; 5 layout forms, each a chart of its own (above).

<a id="w-cbeq"></a>
#### CBEQ

![CBEQ, opcode 101000, three parcels (6 bytes)](figures/w/cbeq/02.svg)

![CBEQ, opcode 101001, three parcels (6 bytes)](figures/w/cbeq/03.svg)

![CBEQ, opcode 101010, three parcels (6 bytes)](figures/w/cbeq/05.svg)

![CBEQ, opcode 101000, two parcels (4 bytes)](figures/w/cbeq/01.svg)

![CBEQ, opcode 101010, two parcels (4 bytes)](figures/w/cbeq/04.svg)

```
CBEQ Ra, Rb, target ... and the rest
```

| Mnemonic | Opcode | `low` |
|---|---|---|
| `CBEQ` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `0010 (0x2)`, `0010 (0x2)`, `0010 (0x2)` |

Operation, flags and exceptions as for the entry CBCC above; 5 layout forms, each a chart of its own (above).

<a id="w-cbpl"></a>
#### CBPL

![CBPL, opcode 101000, three parcels (6 bytes)](figures/w/cbpl/02.svg)

![CBPL, opcode 101001, three parcels (6 bytes)](figures/w/cbpl/03.svg)

![CBPL, opcode 101010, three parcels (6 bytes)](figures/w/cbpl/05.svg)

![CBPL, opcode 101000, two parcels (4 bytes)](figures/w/cbpl/01.svg)

![CBPL, opcode 101010, two parcels (4 bytes)](figures/w/cbpl/04.svg)

| Mnemonic | Opcode | `low` |
|---|---|---|
| `CBPL` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `0011 (0x3)`, `0011 (0x3)`, `0011 (0x3)` |

Operation, flags and exceptions as for the entry CBCC above; 5 layout forms, each a chart of its own (above).

<a id="w-cbmi"></a>
#### CBMI

![CBMI, opcode 101000, three parcels (6 bytes)](figures/w/cbmi/02.svg)

![CBMI, opcode 101001, three parcels (6 bytes)](figures/w/cbmi/03.svg)

![CBMI, opcode 101010, three parcels (6 bytes)](figures/w/cbmi/05.svg)

![CBMI, opcode 101000, two parcels (4 bytes)](figures/w/cbmi/01.svg)

![CBMI, opcode 101010, two parcels (4 bytes)](figures/w/cbmi/04.svg)

| Mnemonic | Opcode | `low` |
|---|---|---|
| `CBMI` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `0100 (0x4)`, `0100 (0x4)`, `0100 (0x4)` |

Operation, flags and exceptions as for the entry CBCC above; 5 layout forms, each a chart of its own (above).

<a id="w-cbvc"></a>
#### CBVC

![CBVC, opcode 101000, three parcels (6 bytes)](figures/w/cbvc/02.svg)

![CBVC, opcode 101001, three parcels (6 bytes)](figures/w/cbvc/03.svg)

![CBVC, opcode 101010, three parcels (6 bytes)](figures/w/cbvc/05.svg)

![CBVC, opcode 101000, two parcels (4 bytes)](figures/w/cbvc/01.svg)

![CBVC, opcode 101010, two parcels (4 bytes)](figures/w/cbvc/04.svg)

| Mnemonic | Opcode | `low` |
|---|---|---|
| `CBVC` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `0101 (0x5)`, `0101 (0x5)`, `0101 (0x5)` |

Operation, flags and exceptions as for the entry CBCC above; 5 layout forms, each a chart of its own (above).

<a id="w-cbvs"></a>
#### CBVS

![CBVS, opcode 101000, three parcels (6 bytes)](figures/w/cbvs/02.svg)

![CBVS, opcode 101001, three parcels (6 bytes)](figures/w/cbvs/03.svg)

![CBVS, opcode 101010, three parcels (6 bytes)](figures/w/cbvs/05.svg)

![CBVS, opcode 101000, two parcels (4 bytes)](figures/w/cbvs/01.svg)

![CBVS, opcode 101010, two parcels (4 bytes)](figures/w/cbvs/04.svg)

| Mnemonic | Opcode | `low` |
|---|---|---|
| `CBVS` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `0110 (0x6)`, `0110 (0x6)`, `0110 (0x6)` |

Operation, flags and exceptions as for the entry CBCC above; 5 layout forms, each a chart of its own (above).

<a id="w-cbcc"></a>
#### CBCC

![CBCC, opcode 101000, three parcels (6 bytes)](figures/w/cbcc/02.svg)

![CBCC, opcode 101001, three parcels (6 bytes)](figures/w/cbcc/03.svg)

![CBCC, opcode 101010, three parcels (6 bytes)](figures/w/cbcc/05.svg)

![CBCC, opcode 101000, two parcels (4 bytes)](figures/w/cbcc/01.svg)

![CBCC, opcode 101010, two parcels (4 bytes)](figures/w/cbcc/04.svg)

| Mnemonic | Opcode | `low` |
|---|---|---|
| `CBCC` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `0111 (0x7)`, `0111 (0x7)`, `0111 (0x7)` |

Operation, flags and exceptions as for the entry CBCC above; 5 layout forms, each a chart of its own (above).

<a id="w-cbcs"></a>
#### CBCS

![CBCS, opcode 101000, three parcels (6 bytes)](figures/w/cbcs/02.svg)

![CBCS, opcode 101001, three parcels (6 bytes)](figures/w/cbcs/03.svg)

![CBCS, opcode 101010, three parcels (6 bytes)](figures/w/cbcs/05.svg)

![CBCS, opcode 101000, two parcels (4 bytes)](figures/w/cbcs/01.svg)

![CBCS, opcode 101010, two parcels (4 bytes)](figures/w/cbcs/04.svg)

| Mnemonic | Opcode | `low` |
|---|---|---|
| `CBCS` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `1000 (0x8)`, `1000 (0x8)`, `1000 (0x8)` |

Operation, flags and exceptions as for the entry CBCC above; 5 layout forms, each a chart of its own (above).

<a id="w-cbge"></a>
#### CBGE

![CBGE, opcode 101000, three parcels (6 bytes)](figures/w/cbge/02.svg)

![CBGE, opcode 101001, three parcels (6 bytes)](figures/w/cbge/03.svg)

![CBGE, opcode 101010, three parcels (6 bytes)](figures/w/cbge/05.svg)

![CBGE, opcode 101000, two parcels (4 bytes)](figures/w/cbge/01.svg)

![CBGE, opcode 101010, two parcels (4 bytes)](figures/w/cbge/04.svg)

| Mnemonic | Opcode | `low` |
|---|---|---|
| `CBGE` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `1001 (0x9)`, `1001 (0x9)`, `1001 (0x9)` |

Operation, flags and exceptions as for the entry CBCC above; 5 layout forms, each a chart of its own (above).

<a id="w-cblt"></a>
#### CBLT

![CBLT, opcode 101000, three parcels (6 bytes)](figures/w/cblt/02.svg)

![CBLT, opcode 101001, three parcels (6 bytes)](figures/w/cblt/03.svg)

![CBLT, opcode 101010, three parcels (6 bytes)](figures/w/cblt/05.svg)

![CBLT, opcode 101000, two parcels (4 bytes)](figures/w/cblt/01.svg)

![CBLT, opcode 101010, two parcels (4 bytes)](figures/w/cblt/04.svg)

| Mnemonic | Opcode | `low` |
|---|---|---|
| `CBLT` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `1010 (0xA)`, `1010 (0xA)`, `1010 (0xA)` |

Operation, flags and exceptions as for the entry CBCC above; 5 layout forms, each a chart of its own (above).

<a id="w-cbgt"></a>
#### CBGT

![CBGT, opcode 101000, three parcels (6 bytes)](figures/w/cbgt/02.svg)

![CBGT, opcode 101001, three parcels (6 bytes)](figures/w/cbgt/03.svg)

![CBGT, opcode 101010, three parcels (6 bytes)](figures/w/cbgt/05.svg)

![CBGT, opcode 101000, two parcels (4 bytes)](figures/w/cbgt/01.svg)

![CBGT, opcode 101010, two parcels (4 bytes)](figures/w/cbgt/04.svg)

| Mnemonic | Opcode | `low` |
|---|---|---|
| `CBGT` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `1011 (0xB)`, `1011 (0xB)`, `1011 (0xB)` |

Operation, flags and exceptions as for the entry CBCC above; 5 layout forms, each a chart of its own (above).

<a id="w-cble"></a>
#### CBLE

![CBLE, opcode 101000, three parcels (6 bytes)](figures/w/cble/02.svg)

![CBLE, opcode 101001, three parcels (6 bytes)](figures/w/cble/03.svg)

![CBLE, opcode 101010, three parcels (6 bytes)](figures/w/cble/05.svg)

![CBLE, opcode 101000, two parcels (4 bytes)](figures/w/cble/01.svg)

![CBLE, opcode 101010, two parcels (4 bytes)](figures/w/cble/04.svg)

| Mnemonic | Opcode | `low` |
|---|---|---|
| `CBLE` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `1100 (0xC)`, `1100 (0xC)`, `1100 (0xC)` |

Operation, flags and exceptions as for the entry CBCC above; 5 layout forms, each a chart of its own (above).

<a id="w-cbhi"></a>
#### CBHI

![CBHI, opcode 101000, three parcels (6 bytes)](figures/w/cbhi/02.svg)

![CBHI, opcode 101001, three parcels (6 bytes)](figures/w/cbhi/03.svg)

![CBHI, opcode 101010, three parcels (6 bytes)](figures/w/cbhi/05.svg)

![CBHI, opcode 101000, two parcels (4 bytes)](figures/w/cbhi/01.svg)

![CBHI, opcode 101010, two parcels (4 bytes)](figures/w/cbhi/04.svg)

| Mnemonic | Opcode | `low` |
|---|---|---|
| `CBHI` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `1101 (0xD)`, `1101 (0xD)`, `1101 (0xD)` |

Operation, flags and exceptions as for the entry CBCC above; 5 layout forms, each a chart of its own (above).

<a id="w-cblos"></a>
#### CBLOS

![CBLOS, opcode 101000, three parcels (6 bytes)](figures/w/cblos/02.svg)

![CBLOS, opcode 101001, three parcels (6 bytes)](figures/w/cblos/03.svg)

![CBLOS, opcode 101010, three parcels (6 bytes)](figures/w/cblos/05.svg)

![CBLOS, opcode 101000, two parcels (4 bytes)](figures/w/cblos/01.svg)

![CBLOS, opcode 101010, two parcels (4 bytes)](figures/w/cblos/04.svg)

| Mnemonic | Opcode | `low` |
|---|---|---|
| `CBLOS` | `101000 (0x28)`, `101001 (0x29)`, `101010 (0x2A)` | `1110 (0xE)`, `1110 (0xE)`, `1110 (0xE)` |

Operation, flags and exceptions as for the entry CBCC above; 5 layout forms, each a chart of its own (above).

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

![Encoding of BTAG](figures/r20-tag-1.svg)

The chart is the layout `r20-tag-1`, Tag branches, two parcels (`len = 01`): `sense` is 0 for `BTAG` and 1 for `BNTAG`; `tag` is the 3-bit tag.

| Mnemonic | Opcode |
|---|---|
| `BTAG` | `010101 (0x15)` |
| `BNTAG` | `010101 (0x15)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-tag-1`](dictionary/by-encoding.md#r20-tag-1), [`r20-tag-2`](dictionary/by-encoding.md#r20-tag-2).

**Operation**

```
BTAG : if (Rn & 111₂) = tag then PC ← address of this instruction + 2 × disp
BNTAG: if (Rn & 111₂) ≠ tag then PC ← address of this instruction + 2 × disp
```

**Flags** None written.

**Exceptions** None.

For runtimes that keep a 3-bit type tag in the low bits of a pointer (`lowtag`). Four bytes at least; the displacement is 16 bits (32 at `len = 10`).

**Why it is here.** The tag branches `BTAG` and `BNTAG` and the table dispatch `JTAG` make tagged pointers cheap to use rather than merely possible: three bits of tag and one of sense fit the `low` nibble exactly, so parcel 1 is a full displacement. Because quad-aligned objects have zero in the low three bits, the tag is free, and an unaligned access is a fault. The compiler for C never emits them (the corpus shows none); they are for Lisp and other tagged runtimes.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-btag"></a>
#### BTAG

![BTAG, opcode 010101, three parcels (6 bytes)](figures/w/btag/02.svg)

![BTAG, opcode 010101, two parcels (4 bytes)](figures/w/btag/01.svg)

```
BTAG Rn, #tag, target
```

| Mnemonic | Opcode |
|---|---|
| `BTAG` | `010101 (0x15)` |

Operation, flags and exceptions as for the entry BTAG above; 2 layout forms, each a chart of its own (above).

<a id="w-bntag"></a>
#### BNTAG

![BNTAG, opcode 010101, three parcels (6 bytes)](figures/w/bntag/02.svg)

![BNTAG, opcode 010101, two parcels (4 bytes)](figures/w/bntag/01.svg)

```
BNTAG Rn, #tag, target
```

| Mnemonic | Opcode |
|---|---|
| `BNTAG` | `010101 (0x15)` |

Operation, flags and exceptions as for the entry BTAG above; 2 layout forms, each a chart of its own (above).


<a id="w-jmp"></a>
### JMP: Jump

![JMP, opcode 010011, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/jmp/06.svg)

![JMP, opcode 010011, three parcels (modes index) (6 bytes)](figures/w/jmp/07.svg)

![JMP, opcode 010011, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/jmp/08.svg)

![JMP, opcode 010011, three parcels (modes dp) (6 bytes)](figures/w/jmp/09.svg)

![JMP, opcode 010011, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/jmp/02.svg)

![JMP, opcode 010011, two parcels (modes index) (4 bytes)](figures/w/jmp/03.svg)

![JMP, opcode 010011, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/jmp/04.svg)

![JMP, opcode 010011, two parcels (modes dp) (4 bytes)](figures/w/jmp/05.svg)

![JMP, opcode 010011, one parcel (2 bytes)](figures/w/jmp/01.svg)

**Mnemonics:** `JMP`

**Syntax**

```
JMP rm        ; a register, or an address by any memory mode
```

**Encoding**

![Encoding of JMP](figures/r20-sop-0.svg)

The chart is the layout `r20-sop-0`, Single operand (SOP), one parcel (`len = 00`): The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `JMP` | `010011 (0x13)` | `1100 (0xC)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sop-0`](dictionary/by-encoding.md#r20-sop-0), [`r20-sop-1`](dictionary/by-encoding.md#r20-sop-1), [`r20-sop-1-2`](dictionary/by-encoding.md#r20-sop-1-2), [`r20-sop-1-3`](dictionary/by-encoding.md#r20-sop-1-3), [`r20-sop-1-4`](dictionary/by-encoding.md#r20-sop-1-4), [`r20-sop-2`](dictionary/by-encoding.md#r20-sop-2), [`r20-sop-2-2`](dictionary/by-encoding.md#r20-sop-2-2), [`r20-sop-2-3`](dictionary/by-encoding.md#r20-sop-2-3), [`r20-sop-2-4`](dictionary/by-encoding.md#r20-sop-2-4).

**Operation**

```
PC ← (register operand) ? Rm : EA(rm)
```

**Flags** None written.

**Exceptions** A jump to an unmapped or non-executable address faults on the fetch of the target.

A switch is a `CMP` against the limit, a `BHIS` to the default and a `JMP` through a scaled index.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-call"></a>
### CALL: Call

![CALL, opcode 010011, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/call/06.svg)

![CALL, opcode 010011, three parcels (modes index) (6 bytes)](figures/w/call/07.svg)

![CALL, opcode 010011, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/call/08.svg)

![CALL, opcode 010011, three parcels (modes dp) (6 bytes)](figures/w/call/09.svg)

![CALL, opcode 010011, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/call/02.svg)

![CALL, opcode 010011, two parcels (modes index) (4 bytes)](figures/w/call/03.svg)

![CALL, opcode 010011, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/call/04.svg)

![CALL, opcode 010011, two parcels (modes dp) (4 bytes)](figures/w/call/05.svg)

![CALL, opcode 010011, one parcel (2 bytes)](figures/w/call/01.svg)

**Mnemonics:** `CALL`

**Syntax**

```
CALL rm
```

**Encoding**

![Encoding of CALL](figures/r20-sop-0.svg)

The chart is the layout `r20-sop-0`, Single operand (SOP), one parcel (`len = 00`): The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `CALL` | `010011 (0x13)` | `1101 (0xD)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sop-0`](dictionary/by-encoding.md#r20-sop-0), [`r20-sop-1`](dictionary/by-encoding.md#r20-sop-1), [`r20-sop-1-2`](dictionary/by-encoding.md#r20-sop-1-2), [`r20-sop-1-3`](dictionary/by-encoding.md#r20-sop-1-3), [`r20-sop-1-4`](dictionary/by-encoding.md#r20-sop-1-4), [`r20-sop-2`](dictionary/by-encoding.md#r20-sop-2), [`r20-sop-2-2`](dictionary/by-encoding.md#r20-sop-2-2), [`r20-sop-2-3`](dictionary/by-encoding.md#r20-sop-2-3), [`r20-sop-2-4`](dictionary/by-encoding.md#r20-sop-2-4).

**Operation**

```
t ← (register operand) ? Rm : EA(rm)
SP ← SP - 8 ; M[SP] ← address of the next instruction
PC ← t
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

The return address is on the data stack where every unwinder and debugger expects it. `RET` pops it.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


### JMPI: Jump and call through memory

**Mnemonics:** `JMPI`, `CALLI`

**Syntax**

```
JMPI rm        ; PC ← M[EA]
CALLI rm       ; push the return address, then PC ← M[EA]
```

**Encoding**

![Encoding of JMPI](figures/r20-xfer-0.svg)

The chart is the layout `r20-xfer-0`, Indirect transfers (XFER), one parcel (`len = 00`): The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `JMPI` | `010010 (0x12)` | `0000 (0x0)` |
| `CALLI` | `010010 (0x12)` | `0001 (0x1)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-xfer-0`](dictionary/by-encoding.md#r20-xfer-0), [`r20-xfer-1`](dictionary/by-encoding.md#r20-xfer-1), [`r20-xfer-1-2`](dictionary/by-encoding.md#r20-xfer-1-2), [`r20-xfer-1-3`](dictionary/by-encoding.md#r20-xfer-1-3), [`r20-xfer-1-4`](dictionary/by-encoding.md#r20-xfer-1-4), [`r20-xfer-2`](dictionary/by-encoding.md#r20-xfer-2), [`r20-xfer-2-2`](dictionary/by-encoding.md#r20-xfer-2-2), [`r20-xfer-2-3`](dictionary/by-encoding.md#r20-xfer-2-3), [`r20-xfer-2-4`](dictionary/by-encoding.md#r20-xfer-2-4).

**Operation**

```
JMPI : PC ← M[EA(rm)]
CALLI: t ← M[EA(rm)] ; SP ← SP - 8 ; M[SP] ← address of the next instruction ; PC ← t
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires. For `CALLI` the order is specified: load the target, then push, then transfer; a fault on the load leaves nothing changed.

The one deferred reference the architecture admits, for control transfer only: the PLT stub (`JMPI got_slot(PC)`) and virtual-method dispatch (`CALLI vtbl_off(Robj)`). It needs a memory operand, so it is four bytes at least.

**Why it is here.** Exactly one deferred reference, for control transfer only, in `XFER`: the PLT stub of every dynamically linked program (`JMPI got_slot(PC)`) and virtual-method dispatch (`CALLI vtbl_off(Robj)`), each two instructions and a scratch register without it. It is admitted because it breaks none of the reasons deferred modes are removed (no register is side-effected, the reference is in the branch path and not the operand path, a fault is clean by ordering). Jump tables through `JMPI` are not smaller, because the table entries are 8 bytes against 8 for a case in a compare chain.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-jmpi"></a>
#### JMPI

![JMPI, opcode 010010, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/jmpi/06.svg)

![JMPI, opcode 010010, three parcels (modes index) (6 bytes)](figures/w/jmpi/07.svg)

![JMPI, opcode 010010, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/jmpi/08.svg)

![JMPI, opcode 010010, three parcels (modes dp) (6 bytes)](figures/w/jmpi/09.svg)

![JMPI, opcode 010010, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/jmpi/02.svg)

![JMPI, opcode 010010, two parcels (modes index) (4 bytes)](figures/w/jmpi/03.svg)

![JMPI, opcode 010010, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/jmpi/04.svg)

![JMPI, opcode 010010, two parcels (modes dp) (4 bytes)](figures/w/jmpi/05.svg)

![JMPI, opcode 010010, one parcel (2 bytes)](figures/w/jmpi/01.svg)

```
JMPI rm
```

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `JMPI` | `010010 (0x12)` | `0000 (0x0)` |

Operation, flags and exceptions as for the entry JMPI above; 9 layout forms, each a chart of its own (above).

<a id="w-calli"></a>
#### CALLI

![CALLI, opcode 010010, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/calli/06.svg)

![CALLI, opcode 010010, three parcels (modes index) (6 bytes)](figures/w/calli/07.svg)

![CALLI, opcode 010010, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/calli/08.svg)

![CALLI, opcode 010010, three parcels (modes dp) (6 bytes)](figures/w/calli/09.svg)

![CALLI, opcode 010010, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/calli/02.svg)

![CALLI, opcode 010010, two parcels (modes index) (4 bytes)](figures/w/calli/03.svg)

![CALLI, opcode 010010, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/calli/04.svg)

![CALLI, opcode 010010, two parcels (modes dp) (4 bytes)](figures/w/calli/05.svg)

![CALLI, opcode 010010, one parcel (2 bytes)](figures/w/calli/01.svg)

```
CALLI rm
```

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `CALLI` | `010010 (0x12)` | `0001 (0x1)` |

Operation, flags and exceptions as for the entry JMPI above; 9 layout forms, each a chart of its own (above).


<a id="w-jtag"></a>
### JTAG: Jump through a tag table

![JTAG, opcode 010010, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/jtag/06.svg)

![JTAG, opcode 010010, three parcels (modes index) (6 bytes)](figures/w/jtag/07.svg)

![JTAG, opcode 010010, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/jtag/08.svg)

![JTAG, opcode 010010, three parcels (modes dp) (6 bytes)](figures/w/jtag/09.svg)

![JTAG, opcode 010010, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/jtag/02.svg)

![JTAG, opcode 010010, two parcels (modes index) (4 bytes)](figures/w/jtag/03.svg)

![JTAG, opcode 010010, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/jtag/04.svg)

![JTAG, opcode 010010, two parcels (modes dp) (4 bytes)](figures/w/jtag/05.svg)

![JTAG, opcode 010010, one parcel (2 bytes)](figures/w/jtag/01.svg)

**Mnemonics:** `JTAG`

**Syntax**

```
JTAG d(Rb)(Rx×s)
```

**Encoding**

![Encoding of JTAG](figures/r20-xfer-0.svg)

The chart is the layout `r20-xfer-0`, Indirect transfers (XFER), one parcel (`len = 00`): The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `JTAG` | `010010 (0x12)` | `0010 (0x2)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-xfer-0`](dictionary/by-encoding.md#r20-xfer-0), [`r20-xfer-1`](dictionary/by-encoding.md#r20-xfer-1), [`r20-xfer-1-2`](dictionary/by-encoding.md#r20-xfer-1-2), [`r20-xfer-1-3`](dictionary/by-encoding.md#r20-xfer-1-3), [`r20-xfer-1-4`](dictionary/by-encoding.md#r20-xfer-1-4), [`r20-xfer-2`](dictionary/by-encoding.md#r20-xfer-2), [`r20-xfer-2-2`](dictionary/by-encoding.md#r20-xfer-2-2), [`r20-xfer-2-3`](dictionary/by-encoding.md#r20-xfer-2-3), [`r20-xfer-2-4`](dictionary/by-encoding.md#r20-xfer-2-4).

**Operation**

```
PC ← M[Rb + d + 8 × (Rx & 111₂)]
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

Legal only with the scaled-index mode (`0001`). Dispatches on the low three bits of a tagged pointer through a table of eight entries; the 3-bit tag cannot index out of range.

**Why it is here.** The table-dispatch partner of `BTAG`. It is legal only in the scaled-index mode, the one mode with a free register slot for the tagged value. It replaces the PDP-11 dispatch-table idiom `@(Rn)+` better, because it needs no pointer register and cannot index out of range.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).
<!-- /entries:9.10 -->

## 9.11 The stack and block operations

*Cf. section 6.8 for restarting a block operation after a fault (progress is held in registers) and section 6.4 for the page faults it can take; section 7.2 for how block operations order their accesses.*

**9.11.1** `PUSH` and `POP` move one register; `PUSHM` and `POPM` move a set named by a mask (a short mask form is in page 2). A mask containing `R14` is reserved. *(D)*

**9.11.2** `PUSHX` and `POPX` save and restore the exception state `EPSW` and `EPC` in one instruction each; both words are checked before either is accessed, so an abort leaves nothing changed. *(D)*

**9.11.3** The block operations `MCPY`, `MMOV` (overlap-safe), `MSET`, `MCMP`, `MSCN` and `MSCNN` take a destination pointer, a source pointer or value and a count in registers; `MVAL` validates a buffer as UTF-8. *(opcode `001101 (0x0D)`)*

**9.11.4** A block operation keeps its progress in its registers: when it completes, the count is zero and the pointers are one past the end; when it stops early or is interrupted, they point where it stopped, and it restarts by running again. *(D)*

**9.11.5** An implementation may move more than a byte per step, provided the registers are consistent with byte-at-a-time progress wherever an exception can be taken. *(D)*

*Commentary.* **Precedent.** The VAX's `MOVC5` is the canonical argument against such instructions: its operands could be memory, its architectural definition needed the original values to survive, and so it required hidden state and a first-part-done bit in the status word to resume. The PDP-10 had a block transfer, and x86's `REP MOVS` keeps its progress in registers as the pdp64's do. **Trade-offs.** This is the one admitted exception to the one-memory-operand rule, accepted because its mechanism, hidden state, is absent: the state is the registers, which are already architectural. A large copy can evict the whole data cache, and a non-temporal variant is an open question. **Improvements.** ARM reached the same design in 2022 with `FEAT_MOPS`, whose specification says the registers are updated so that progress is not lost. **Benefits.** The block-move sequencer is three counters and a byte-lane selector, about 1,500 transistors. **Modern comparables.** x86 `REP MOVSB` and `REP STOSB` with fast-string microcode; AArch64 `CPYP`/`CPYM`/`CPYE` and `SETP`/`SETM`/`SETE`; s390 `MVC`. **Use.** `memcpy`, `memmove`, `memset`, `memcmp` and `memchr` in the C library; `MVAL` in parsers and kernels. **Impact.** *Kernel:* `PUSHM`, `POPM`, `PUSHX` and `POPX` shorten entry, exit and the context switch, and the block operations are `copyin`, `copyout`, page clearing and `memcpy`. *Compiler:* A prologue and an epilogue are one instruction each, and `memcpy` and `memset` lower to the block operations. *Hardware:* The block-move sequencer is three counters and a byte-lane selector, about 1,500 transistors, with no hidden state.

<!-- entries:9.11 -->
<a id="w-pushm"></a>
### PUSHM: Push registers by mask

![PUSHM, opcode 010011, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/pushm/06.svg)

![PUSHM, opcode 010011, three parcels (modes index) (6 bytes)](figures/w/pushm/07.svg)

![PUSHM, opcode 010011, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/pushm/08.svg)

![PUSHM, opcode 010011, three parcels (modes dp) (6 bytes)](figures/w/pushm/09.svg)

![PUSHM, opcode 010011, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/pushm/02.svg)

![PUSHM, opcode 010011, two parcels (modes index) (4 bytes)](figures/w/pushm/03.svg)

![PUSHM, opcode 010011, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/pushm/04.svg)

![PUSHM, opcode 010011, two parcels (modes dp) (4 bytes)](figures/w/pushm/05.svg)

![PUSHM, opcode 010011, one parcel (2 bytes)](figures/w/pushm/01.svg)

**Mnemonics:** `PUSHM`

**Syntax**

```
PUSHM #mask        ; a 16-bit immediate, bit n is Rn
```

**Encoding**

![Encoding of PUSHM](figures/r20-sop-0.svg)

The chart is the layout `r20-sop-0`, Single operand (SOP), one parcel (`len = 00`): The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `PUSHM` | `010011 (0x13)` | `1010 (0xA)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sop-0`](dictionary/by-encoding.md#r20-sop-0), [`r20-sop-1`](dictionary/by-encoding.md#r20-sop-1), [`r20-sop-1-2`](dictionary/by-encoding.md#r20-sop-1-2), [`r20-sop-1-3`](dictionary/by-encoding.md#r20-sop-1-3), [`r20-sop-1-4`](dictionary/by-encoding.md#r20-sop-1-4), [`r20-sop-2`](dictionary/by-encoding.md#r20-sop-2), [`r20-sop-2-2`](dictionary/by-encoding.md#r20-sop-2-2), [`r20-sop-2-3`](dictionary/by-encoding.md#r20-sop-2-3), [`r20-sop-2-4`](dictionary/by-encoding.md#r20-sop-2-4).

**Operation**

```
for n = 0 to 15, if mask bit n:
    SP ← SP - 8 ; M[SP] ← Rn
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires. A mask that includes `R14` (`SP`) is reserved.

Four bytes (mode `0100`, immediate). The registers are pushed in ascending order, so `POPM` with the same mask restores them. Page 2 has an 8-bit mask for `R8` to `R15`.

**Why it is here.** The VAX procedure entry mask was the useful half of `CALLS`; `PUSHM` and `POPM` keep that half without the frame (hardware call frames ran slower than the sequence on later VAXes). They are in `SOP` because a 16-bit mask does not fit beside `MBLK`'s sub-opcode; that uses `SOP`'s last two free slots. The second page has 8-bit forms for `R8` to `R15`, because all 2,392 push sites and 2,392 pop sites in the measured corpus use a mask within `R8` to `R15`.

**Cf.** 6.8 for the restart rule.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-popm"></a>
### POPM: Pop registers by mask

![POPM, opcode 010011, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/popm/06.svg)

![POPM, opcode 010011, three parcels (modes index) (6 bytes)](figures/w/popm/07.svg)

![POPM, opcode 010011, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/popm/08.svg)

![POPM, opcode 010011, three parcels (modes dp) (6 bytes)](figures/w/popm/09.svg)

![POPM, opcode 010011, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/popm/02.svg)

![POPM, opcode 010011, two parcels (modes index) (4 bytes)](figures/w/popm/03.svg)

![POPM, opcode 010011, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/popm/04.svg)

![POPM, opcode 010011, two parcels (modes dp) (4 bytes)](figures/w/popm/05.svg)

![POPM, opcode 010011, one parcel (2 bytes)](figures/w/popm/01.svg)

**Mnemonics:** `POPM`

**Syntax**

```
POPM #mask
```

**Encoding**

![Encoding of POPM](figures/r20-sop-0.svg)

The chart is the layout `r20-sop-0`, Single operand (SOP), one parcel (`len = 00`): The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `POPM` | `010011 (0x13)` | `1011 (0xB)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sop-0`](dictionary/by-encoding.md#r20-sop-0), [`r20-sop-1`](dictionary/by-encoding.md#r20-sop-1), [`r20-sop-1-2`](dictionary/by-encoding.md#r20-sop-1-2), [`r20-sop-1-3`](dictionary/by-encoding.md#r20-sop-1-3), [`r20-sop-1-4`](dictionary/by-encoding.md#r20-sop-1-4), [`r20-sop-2`](dictionary/by-encoding.md#r20-sop-2), [`r20-sop-2-2`](dictionary/by-encoding.md#r20-sop-2-2), [`r20-sop-2-3`](dictionary/by-encoding.md#r20-sop-2-3), [`r20-sop-2-4`](dictionary/by-encoding.md#r20-sop-2-4).

**Operation**

```
for n = 15 down to 0, if mask bit n:
    Rn ← M[SP] ; SP ← SP + 8
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

The mirror of `PUSHM`; four bytes, with an 8-bit-mask form on page 2.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-push"></a>
### PUSH: Push

![PUSH, opcode 010011, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/push/06.svg)

![PUSH, opcode 010011, three parcels (modes index) (6 bytes)](figures/w/push/07.svg)

![PUSH, opcode 010011, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/push/08.svg)

![PUSH, opcode 010011, three parcels (modes dp) (6 bytes)](figures/w/push/09.svg)

![PUSH, opcode 010011, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/push/02.svg)

![PUSH, opcode 010011, two parcels (modes index) (4 bytes)](figures/w/push/03.svg)

![PUSH, opcode 010011, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/push/04.svg)

![PUSH, opcode 010011, two parcels (modes dp) (4 bytes)](figures/w/push/05.svg)

![PUSH, opcode 010011, one parcel (2 bytes)](figures/w/push/01.svg)

**Mnemonics:** `PUSH`

**Syntax**

```
PUSH rm
```

**Encoding**

![Encoding of PUSH](figures/r20-sop-0.svg)

The chart is the layout `r20-sop-0`, Single operand (SOP), one parcel (`len = 00`): The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `PUSH` | `010011 (0x13)` | `1110 (0xE)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sop-0`](dictionary/by-encoding.md#r20-sop-0), [`r20-sop-1`](dictionary/by-encoding.md#r20-sop-1), [`r20-sop-1-2`](dictionary/by-encoding.md#r20-sop-1-2), [`r20-sop-1-3`](dictionary/by-encoding.md#r20-sop-1-3), [`r20-sop-1-4`](dictionary/by-encoding.md#r20-sop-1-4), [`r20-sop-2`](dictionary/by-encoding.md#r20-sop-2), [`r20-sop-2-2`](dictionary/by-encoding.md#r20-sop-2-2), [`r20-sop-2-3`](dictionary/by-encoding.md#r20-sop-2-3), [`r20-sop-2-4`](dictionary/by-encoding.md#r20-sop-2-4).

**Operation**

```
v ← rm ; SP ← SP - 8 ; M[SP] ← v
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

A one-parcel instruction for a register operand.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-pop"></a>
### POP: Pop

![POP, opcode 010011, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/pop/06.svg)

![POP, opcode 010011, three parcels (modes index) (6 bytes)](figures/w/pop/07.svg)

![POP, opcode 010011, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/pop/08.svg)

![POP, opcode 010011, three parcels (modes dp) (6 bytes)](figures/w/pop/09.svg)

![POP, opcode 010011, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/pop/02.svg)

![POP, opcode 010011, two parcels (modes index) (4 bytes)](figures/w/pop/03.svg)

![POP, opcode 010011, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/pop/04.svg)

![POP, opcode 010011, two parcels (modes dp) (4 bytes)](figures/w/pop/05.svg)

![POP, opcode 010011, one parcel (2 bytes)](figures/w/pop/01.svg)

**Mnemonics:** `POP`

**Syntax**

```
POP rm
```

**Encoding**

![Encoding of POP](figures/r20-sop-0.svg)

The chart is the layout `r20-sop-0`, Single operand (SOP), one parcel (`len = 00`): The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `POP` | `010011 (0x13)` | `1111 (0xF)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sop-0`](dictionary/by-encoding.md#r20-sop-0), [`r20-sop-1`](dictionary/by-encoding.md#r20-sop-1), [`r20-sop-1-2`](dictionary/by-encoding.md#r20-sop-1-2), [`r20-sop-1-3`](dictionary/by-encoding.md#r20-sop-1-3), [`r20-sop-1-4`](dictionary/by-encoding.md#r20-sop-1-4), [`r20-sop-2`](dictionary/by-encoding.md#r20-sop-2), [`r20-sop-2-2`](dictionary/by-encoding.md#r20-sop-2-2), [`r20-sop-2-3`](dictionary/by-encoding.md#r20-sop-2-3), [`r20-sop-2-4`](dictionary/by-encoding.md#r20-sop-2-4).

**Operation**

```
v ← M[SP] ; SP ← SP + 8 ; rm ← v
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


### MCPY: Copy a block of bytes

**Mnemonics:** `MCPY`, `MMOV`

**Syntax**

```
MCPY Rd, Rs, Rn        ; destination pointer, source pointer, count
MMOV Rd, Rs, Rn        ; correct for overlap
```

**Encoding**

![Encoding of MCPY](figures/r20-mblk-1.svg)

The chart is the layout `r20-mblk-1`, Block memory (MBLK), two parcels (`len = 01`): `reg` is the destination pointer, `low` the source pointer (or the value register), `Rn` the count register.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MCPY` | `001101 (0x0D)` | `00000000 (0x00)` |
| `MMOV` | `001101 (0x0D)` | `00000001 (0x01)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-mblk-1`](dictionary/by-encoding.md#r20-mblk-1), [`r20-mblk-2`](dictionary/by-encoding.md#r20-mblk-2).

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

**Cf.** 6.8 (restart, progress faults); 7.2 (ordering of the accesses).

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-mcpy"></a>
#### MCPY

![MCPY, opcode 001101, three parcels, sub-opcode 00000000 (6 bytes)](figures/w/mcpy/02.svg)

![MCPY, opcode 001101, two parcels, sub-opcode 00000000 (4 bytes)](figures/w/mcpy/01.svg)

```
MCPY Rd, Rs, Rn
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MCPY` | `001101 (0x0D)` | `00000000 (0x00)` |

Operation, flags and exceptions as for the entry MCPY above; 2 layout forms, each a chart of its own (above).

<a id="w-mmov"></a>
#### MMOV

![MMOV, opcode 001101, three parcels, sub-opcode 00000001 (6 bytes)](figures/w/mmov/02.svg)

![MMOV, opcode 001101, two parcels, sub-opcode 00000001 (4 bytes)](figures/w/mmov/01.svg)

```
MMOV Rd, Rs, Rn
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MMOV` | `001101 (0x0D)` | `00000001 (0x01)` |

Operation, flags and exceptions as for the entry MCPY above; 2 layout forms, each a chart of its own (above).


<a id="w-mset"></a>
### MSET: Fill a block of bytes

![MSET, opcode 001101, three parcels, sub-opcode 00000010 (6 bytes)](figures/w/mset/02.svg)

![MSET, opcode 001101, two parcels, sub-opcode 00000010 (4 bytes)](figures/w/mset/01.svg)

**Mnemonics:** `MSET`

**Syntax**

```
MSET Rd, Rv, Rn
```

**Encoding**

![Encoding of MSET](figures/r20-mblk-1.svg)

The chart is the layout `r20-mblk-1`, Block memory (MBLK), two parcels (`len = 01`): `reg` is the destination pointer, `low` the source pointer (or the value register), `Rn` the count register.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MSET` | `001101 (0x0D)` | `00000010 (0x02)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-mblk-1`](dictionary/by-encoding.md#r20-mblk-1), [`r20-mblk-2`](dictionary/by-encoding.md#r20-mblk-2).

**Operation**

```
while Rn ≠ 0:  M8[Rd] ← Rv[7:0] ; Rd ← Rd + 1 ; Rn ← Rn - 1
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

`MSET` with `Rv = 0` is the range-zeroing instruction: `bzero` and the clear of `calloc` are one instruction.

**Why it is here.** With a zero value it is the range-zeroing instruction, so `bzero` and the clearing of `calloc` need no separate opcode.

**Cf.** 6.8.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-mcmp"></a>
### MCMP: Compare two blocks of bytes

![MCMP, opcode 001101, three parcels, sub-opcode 00000011 (6 bytes)](figures/w/mcmp/02.svg)

![MCMP, opcode 001101, two parcels, sub-opcode 00000011 (4 bytes)](figures/w/mcmp/01.svg)

**Mnemonics:** `MCMP`

**Syntax**

```
MCMP Rd, Rs, Rn
```

**Encoding**

![Encoding of MCMP](figures/r20-mblk-1.svg)

The chart is the layout `r20-mblk-1`, Block memory (MBLK), two parcels (`len = 01`): `reg` is the destination pointer, `low` the source pointer (or the value register), `Rn` the count register.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MCMP` | `001101 (0x0D)` | `00000011 (0x03)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-mblk-1`](dictionary/by-encoding.md#r20-mblk-1), [`r20-mblk-2`](dictionary/by-encoding.md#r20-mblk-2).

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

**Cf.** 6.8.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


### MSCN: Scan a block for a byte, or for a byte not equal to it

**Mnemonics:** `MSCN`, `MSCNN`

**Syntax**

```
MSCN Rd, Rv, Rn
MSCNN Rd, Rv, Rn
```

**Encoding**

![Encoding of MSCN](figures/r20-mblk-1.svg)

The chart is the layout `r20-mblk-1`, Block memory (MBLK), two parcels (`len = 01`): `reg` is the destination pointer, `low` the source pointer (or the value register), `Rn` the count register.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MSCN` | `001101 (0x0D)` | `00000100 (0x04)` |
| `MSCNN` | `001101 (0x0D)` | `00000101 (0x05)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-mblk-1`](dictionary/by-encoding.md#r20-mblk-1), [`r20-mblk-2`](dictionary/by-encoding.md#r20-mblk-2).

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

**Why it is here.** `MSCN` is `LOCC` and `memchr`; `MSCNN` fills the `SKPC` gap (the first byte that is *not* equal). Both cost no opcode and almost no hardware. With an explicit count `MSCN` gives `strnlen`, and with `MCPY` a bounded `strcpy` in two instructions. NUL-terminated string instructions (the System/z `MVST`, `SRST`, `CLST`) are rejected, because they encode an unbounded read, the largest single source of memory-safety failures in C (9.17).

**Cf.** 6.8.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-mscn"></a>
#### MSCN

![MSCN, opcode 001101, three parcels, sub-opcode 00000100 (6 bytes)](figures/w/mscn/02.svg)

![MSCN, opcode 001101, two parcels, sub-opcode 00000100 (4 bytes)](figures/w/mscn/01.svg)

```
MSCN Rd, Rv, Rn
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MSCN` | `001101 (0x0D)` | `00000100 (0x04)` |

Operation, flags and exceptions as for the entry MSCN above; 2 layout forms, each a chart of its own (above).

<a id="w-mscnn"></a>
#### MSCNN

![MSCNN, opcode 001101, three parcels, sub-opcode 00000101 (6 bytes)](figures/w/mscnn/02.svg)

![MSCNN, opcode 001101, two parcels, sub-opcode 00000101 (4 bytes)](figures/w/mscnn/01.svg)

```
MSCNN Rd, Rv, Rn
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MSCNN` | `001101 (0x0D)` | `00000101 (0x05)` |

Operation, flags and exceptions as for the entry MSCN above; 2 layout forms, each a chart of its own (above).


<a id="w-mval"></a>
### MVAL: Validate a block as UTF-8

![MVAL, opcode 001101, three parcels, sub-opcode 00000110 (6 bytes)](figures/w/mval/02.svg)

![MVAL, opcode 001101, two parcels, sub-opcode 00000110 (4 bytes)](figures/w/mval/01.svg)

**Mnemonics:** `MVAL`

**Syntax**

```
MVAL Rd, Rn
```

**Encoding**

![Encoding of MVAL](figures/r20-mblk-1.svg)

The chart is the layout `r20-mblk-1`, Block memory (MBLK), two parcels (`len = 01`): `reg` is the destination pointer, `low` the source pointer (or the value register), `Rn` the count register.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MVAL` | `001101 (0x0D)` | `00000110 (0x06)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-mblk-1`](dictionary/by-encoding.md#r20-mblk-1), [`r20-mblk-2`](dictionary/by-encoding.md#r20-mblk-2).

**Operation**

```
scan Rn bytes at Rd; stop at the first byte that cannot be part of a valid UTF-8 sequence (the rules of UTF8DEC)
```

**Flags** On completion `Rn` is 0 and the buffer is valid; otherwise `Rd` points at the offending sequence and `Rn` counts the bytes remaining (details in the instruction-set text, section 4.7.1).

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

The `UTF8DEC` comparators wired to the block sequencer.

**Why it is here.** The UTF-8 validity comparators already built for `UTF8DEC`, wired to the `MBLK` streaming sequencer already built for `MCPY`, so it costs no opcode and almost no hardware. The alternative, a SWAR loop (SIMD within a register), runs at about two to three cycles a byte and is respectable, which is why the justification is cost and not throughput.

**Cf.** 6.8.

**Status** specified; **not yet implemented** in the reference executor.
<!-- /entries:9.11 -->

## 9.12 Floating point

**9.12.1** Floating point uses the general registers: a `binary64` value fills one register, and the instruction, not the register, decides how its bits are read. *(D)*

**9.12.2** `FADD`, `FSUB`, `FMUL` and `FCMP` are two-byte instructions; `FDIV`, `FSQRT`, the fused multiply-add family, `FABS`, `FMIN`, `FMAX`, `FCLASS`, the roundings and the `binary32` forms are in the floating-point escape; `binary16` has seventeen operations and conversions. *(D)*

**9.12.3** The five IEEE flags (invalid, divide by zero, overflow, underflow, inexact) accumulate in `FPSR`; no floating-point operation traps; `FSFLAGS` reads and clears them. *(D)*

**9.12.4** Every NaN that an operation creates is the canonical quiet NaN. *(D)*

**9.12.5** There are no rounding-mode or precision mode bits: the precision is in the opcode, and so is the rounding mode wherever it is not nearest-even. *(D)*

**9.12.6** There are no transcendental instructions. *(D)*

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

![Encoding of FADD](figures/r20-mem-0.svg)

The chart is the layout `r20-mem-0`, Moves, address formation and the ALU, one parcel (`len = 00`): `reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `FADD` | `100100 (0x24)` |
| `FSUB` | `100101 (0x25)` |
| `FMUL` | `100110 (0x26)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-mem-0`](dictionary/by-encoding.md#r20-mem-0), [`r20-mem-1`](dictionary/by-encoding.md#r20-mem-1), [`r20-mem-1-2`](dictionary/by-encoding.md#r20-mem-1-2), [`r20-mem-1-3`](dictionary/by-encoding.md#r20-mem-1-3), [`r20-mem-1-4`](dictionary/by-encoding.md#r20-mem-1-4), [`r20-mem-2`](dictionary/by-encoding.md#r20-mem-2), [`r20-mem-2-2`](dictionary/by-encoding.md#r20-mem-2-2), [`r20-mem-2-3`](dictionary/by-encoding.md#r20-mem-2-3), [`r20-mem-2-4`](dictionary/by-encoding.md#r20-mem-2-4).

**Operation**

```
Rd ← Rd + rm   (FADD)
Rd ← Rd - rm   (FSUB)
Rd ← Rd × rm   (FMUL)       ; IEEE 754 binary64, round to nearest even
```

**Flags** None written. The five IEEE exception flags are ORed into `FPSR`; no instruction traps.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires. Floating-point exceptions never trap.

Floating-point values live in the general registers; there is no separate register file and no mode bit. A NaN result is the canonical quiet NaN `0x7FF8000000000000`. The alternative spellings `FADDD`, `FSUBD`, `FMULD` are aliases.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-fadd"></a>
#### FADD

![FADD, opcode 100100, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/fadd/06.svg)

![FADD, opcode 100100, three parcels (modes index) (6 bytes)](figures/w/fadd/07.svg)

![FADD, opcode 100100, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/fadd/08.svg)

![FADD, opcode 100100, three parcels (modes dp) (6 bytes)](figures/w/fadd/09.svg)

![FADD, opcode 100100, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/fadd/02.svg)

![FADD, opcode 100100, two parcels (modes index) (4 bytes)](figures/w/fadd/03.svg)

![FADD, opcode 100100, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/fadd/04.svg)

![FADD, opcode 100100, two parcels (modes dp) (4 bytes)](figures/w/fadd/05.svg)

![FADD, opcode 100100, one parcel (2 bytes)](figures/w/fadd/01.svg)

```
FADD rm, Rd
```

| Mnemonic | Opcode |
|---|---|
| `FADD` | `100100 (0x24)` |

Operation, flags and exceptions as for the entry FADD above; 9 layout forms, each a chart of its own (above).

<a id="w-fsub"></a>
#### FSUB

![FSUB, opcode 100101, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/fsub/06.svg)

![FSUB, opcode 100101, three parcels (modes index) (6 bytes)](figures/w/fsub/07.svg)

![FSUB, opcode 100101, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/fsub/08.svg)

![FSUB, opcode 100101, three parcels (modes dp) (6 bytes)](figures/w/fsub/09.svg)

![FSUB, opcode 100101, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/fsub/02.svg)

![FSUB, opcode 100101, two parcels (modes index) (4 bytes)](figures/w/fsub/03.svg)

![FSUB, opcode 100101, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/fsub/04.svg)

![FSUB, opcode 100101, two parcels (modes dp) (4 bytes)](figures/w/fsub/05.svg)

![FSUB, opcode 100101, one parcel (2 bytes)](figures/w/fsub/01.svg)

```
FSUB rm, Rd
```

| Mnemonic | Opcode |
|---|---|
| `FSUB` | `100101 (0x25)` |

Operation, flags and exceptions as for the entry FADD above; 9 layout forms, each a chart of its own (above).

<a id="w-fmul"></a>
#### FMUL

![FMUL, opcode 100110, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/fmul/06.svg)

![FMUL, opcode 100110, three parcels (modes index) (6 bytes)](figures/w/fmul/07.svg)

![FMUL, opcode 100110, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/fmul/08.svg)

![FMUL, opcode 100110, three parcels (modes dp) (6 bytes)](figures/w/fmul/09.svg)

![FMUL, opcode 100110, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/fmul/02.svg)

![FMUL, opcode 100110, two parcels (modes index) (4 bytes)](figures/w/fmul/03.svg)

![FMUL, opcode 100110, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/fmul/04.svg)

![FMUL, opcode 100110, two parcels (modes dp) (4 bytes)](figures/w/fmul/05.svg)

![FMUL, opcode 100110, one parcel (2 bytes)](figures/w/fmul/01.svg)

```
FMUL rm, Rd
```

| Mnemonic | Opcode |
|---|---|
| `FMUL` | `100110 (0x26)` |

Operation, flags and exceptions as for the entry FADD above; 9 layout forms, each a chart of its own (above).

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

![FCMP, opcode 100111, three parcels (modes base, postinc, predec) (6 bytes)](figures/w/fcmp/06.svg)

![FCMP, opcode 100111, three parcels (modes index) (6 bytes)](figures/w/fcmp/07.svg)

![FCMP, opcode 100111, three parcels (modes pcrel, imm, abs) (6 bytes)](figures/w/fcmp/08.svg)

![FCMP, opcode 100111, three parcels (modes dp) (6 bytes)](figures/w/fcmp/09.svg)

![FCMP, opcode 100111, two parcels (modes base, postinc, predec) (4 bytes)](figures/w/fcmp/02.svg)

![FCMP, opcode 100111, two parcels (modes index) (4 bytes)](figures/w/fcmp/03.svg)

![FCMP, opcode 100111, two parcels (modes pcrel, imm, abs) (4 bytes)](figures/w/fcmp/04.svg)

![FCMP, opcode 100111, two parcels (modes dp) (4 bytes)](figures/w/fcmp/05.svg)

![FCMP, opcode 100111, one parcel (2 bytes)](figures/w/fcmp/01.svg)

**Mnemonics:** `FCMP`  (aliases: `FCMPD`)

**Syntax**

```
FCMP Rd, rm        ; register first
```

**Encoding**

![Encoding of FCMP](figures/r20-mem-0.svg)

The chart is the layout `r20-mem-0`, Moves, address formation and the ALU, one parcel (`len = 00`): `reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `FCMP` | `100111 (0x27)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-mem-0`](dictionary/by-encoding.md#r20-mem-0), [`r20-mem-1`](dictionary/by-encoding.md#r20-mem-1), [`r20-mem-1-2`](dictionary/by-encoding.md#r20-mem-1-2), [`r20-mem-1-3`](dictionary/by-encoding.md#r20-mem-1-3), [`r20-mem-1-4`](dictionary/by-encoding.md#r20-mem-1-4), [`r20-mem-2`](dictionary/by-encoding.md#r20-mem-2), [`r20-mem-2-2`](dictionary/by-encoding.md#r20-mem-2-2), [`r20-mem-2-3`](dictionary/by-encoding.md#r20-mem-2-3), [`r20-mem-2-4`](dictionary/by-encoding.md#r20-mem-2-4).

**Operation**

```
N ← Rd < rm ; Z ← Rd = rm ; V ← unordered ; C ← 0
```

**Flags** `N` set if `Rd < rm`, `Z` if equal, `V` if the operands are unordered (either is a NaN), `C` cleared. A signalling NaN raises `NV` in `FPSR`.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

The signed branches do not treat the unordered case cleanly (`BLT` after an unordered compare takes `N xor V` = 1); this is an open item of the instruction set.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

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

![Encoding of FDIV](figures/r20-fesc-1.svg)

The chart is the layout `r20-fesc-1`, Floating point (FESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FDIV` | `010000 (0x10)` | `00000000 (0x00)` |
| `FSQRT` | `010000 (0x10)` | `00000001 (0x01)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-fesc-1`](dictionary/by-encoding.md#r20-fesc-1), [`r20-fesc-2`](dictionary/by-encoding.md#r20-fesc-2).

**Operation**

```
FDIV : Rd ← Rd ÷ Rs
FSQRT: Rd ← sqrt(Rs)
```

**Flags** No integer flag is written. The IEEE exception flags raised are ORed into `FPSR` (`NX` inexact, `UF` underflow, `OF` overflow, `DZ` divide by zero, `NV` invalid); nothing traps.

**Exceptions** None.

`FDIV` and `FSQRT` are multi-cycle sequencer operations and rarely appear in a two-byte form, so they are in `FESC`. The alternative spellings `FDIVD`, `FSQRTD` are aliases.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-fdiv"></a>
#### FDIV

![FDIV, opcode 010000, three parcels, sub-opcode 00000000 (6 bytes)](figures/w/fdiv/02.svg)

![FDIV, opcode 010000, two parcels, sub-opcode 00000000 (4 bytes)](figures/w/fdiv/01.svg)

```
FDIV Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FDIV` | `010000 (0x10)` | `00000000 (0x00)` |

Operation, flags and exceptions as for the entry FDIV above; 2 layout forms, each a chart of its own (above).

<a id="w-fsqrt"></a>
#### FSQRT

![FSQRT, opcode 010000, three parcels, sub-opcode 00000001 (6 bytes)](figures/w/fsqrt/02.svg)

![FSQRT, opcode 010000, two parcels, sub-opcode 00000001 (4 bytes)](figures/w/fsqrt/01.svg)

```
FSQRT Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FSQRT` | `010000 (0x10)` | `00000001 (0x01)` |

Operation, flags and exceptions as for the entry FDIV above; 2 layout forms, each a chart of its own (above).

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

![Encoding of FSINGLE](figures/r20-fesc-1.svg)

The chart is the layout `r20-fesc-1`, Floating point (FESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FADD32` | `010000 (0x10)` | `00001000 (0x08)` |
| `FSUB32` | `010000 (0x10)` | `00001001 (0x09)` |
| `FMUL32` | `010000 (0x10)` | `00001010 (0x0A)` |
| `FDIV32` | `010000 (0x10)` | `00001011 (0x0B)` |
| `FSQRT32` | `010000 (0x10)` | `00001100 (0x0C)` |
| `FCMP32` | `010000 (0x10)` | `00001101 (0x0D)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-fesc-1`](dictionary/by-encoding.md#r20-fesc-1), [`r20-fesc-2`](dictionary/by-encoding.md#r20-fesc-2).

**Operation**

```
Rd ← Rd op Rs  (FADD32 FSUB32 FMUL32 FDIV32); Rd ← sqrt(Rs) (FSQRT32)
FCMP32: flags as FCMP, comparing Rd with Rs
```

**Flags** No integer flag is written. The IEEE exception flags raised are ORed into `FPSR` (`NX` inexact, `UF` underflow, `OF` overflow, `DZ` divide by zero, `NV` invalid); nothing traps. `FCMP32` writes `N Z V C` as `FCMP` does.

**Exceptions** None.

A `binary32` lives in the low 32 bits of a register, sign-extended to 64 like every 32-bit result. Results are correctly rounded to nearest even. The alternative spellings `FADDS`, `FSUBS`, ... are aliases.

**Why it is here.** `binary64` has first-class opcodes because on a 64-bit machine it is the common case; `binary32` is in `FESC` with the same operations, held in the low 32 bits of a register and sign-extended like every other 32-bit value (see also the ABI). The naming rule is an `F` in front of the integer mnemonic (`FADD`) and a size suffix for the other formats (`FADD16`); the older spellings (`FADDS` and so on) are aliases.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-fadd32"></a>
#### FADD32

![FADD32, opcode 010000, three parcels, sub-opcode 00001000 (6 bytes)](figures/w/fadd32/02.svg)

![FADD32, opcode 010000, two parcels, sub-opcode 00001000 (4 bytes)](figures/w/fadd32/01.svg)

```
FADD32 Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FADD32` | `010000 (0x10)` | `00001000 (0x08)` |

Operation, flags and exceptions as for the entry FSINGLE above; 2 layout forms, each a chart of its own (above).

<a id="w-fsub32"></a>
#### FSUB32

![FSUB32, opcode 010000, three parcels, sub-opcode 00001001 (6 bytes)](figures/w/fsub32/02.svg)

![FSUB32, opcode 010000, two parcels, sub-opcode 00001001 (4 bytes)](figures/w/fsub32/01.svg)

```
FSUB32 Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FSUB32` | `010000 (0x10)` | `00001001 (0x09)` |

Operation, flags and exceptions as for the entry FSINGLE above; 2 layout forms, each a chart of its own (above).

<a id="w-fmul32"></a>
#### FMUL32

![FMUL32, opcode 010000, three parcels, sub-opcode 00001010 (6 bytes)](figures/w/fmul32/02.svg)

![FMUL32, opcode 010000, two parcels, sub-opcode 00001010 (4 bytes)](figures/w/fmul32/01.svg)

```
FMUL32 Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FMUL32` | `010000 (0x10)` | `00001010 (0x0A)` |

Operation, flags and exceptions as for the entry FSINGLE above; 2 layout forms, each a chart of its own (above).

<a id="w-fdiv32"></a>
#### FDIV32

![FDIV32, opcode 010000, three parcels, sub-opcode 00001011 (6 bytes)](figures/w/fdiv32/02.svg)

![FDIV32, opcode 010000, two parcels, sub-opcode 00001011 (4 bytes)](figures/w/fdiv32/01.svg)

```
FDIV32 Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FDIV32` | `010000 (0x10)` | `00001011 (0x0B)` |

Operation, flags and exceptions as for the entry FSINGLE above; 2 layout forms, each a chart of its own (above).

<a id="w-fsqrt32"></a>
#### FSQRT32

![FSQRT32, opcode 010000, three parcels, sub-opcode 00001100 (6 bytes)](figures/w/fsqrt32/02.svg)

![FSQRT32, opcode 010000, two parcels, sub-opcode 00001100 (4 bytes)](figures/w/fsqrt32/01.svg)

```
FSQRT32 Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FSQRT32` | `010000 (0x10)` | `00001100 (0x0C)` |

Operation, flags and exceptions as for the entry FSINGLE above; 2 layout forms, each a chart of its own (above).

<a id="w-fcmp32"></a>
#### FCMP32

![FCMP32, opcode 010000, three parcels, sub-opcode 00001101 (6 bytes)](figures/w/fcmp32/02.svg)

![FCMP32, opcode 010000, two parcels, sub-opcode 00001101 (4 bytes)](figures/w/fcmp32/01.svg)

```
FCMP32 Rd, Rs
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FCMP32` | `010000 (0x10)` | `00001101 (0x0D)` |

Operation, flags and exceptions as for the entry FSINGLE above; 2 layout forms, each a chart of its own (above).

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

![Encoding of FMADD](figures/r20-fesc-1.svg)

The chart is the layout `r20-fesc-1`, Floating point (FESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FMADD` | `010000 (0x10)` | `00010000 (0x10)` |
| `FMSUB` | `010000 (0x10)` | `00010001 (0x11)` |
| `FNMADD` | `010000 (0x10)` | `00010010 (0x12)` |
| `FNMSUB` | `010000 (0x10)` | `00010011 (0x13)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-fesc-1`](dictionary/by-encoding.md#r20-fesc-1), [`r20-fesc-2`](dictionary/by-encoding.md#r20-fesc-2).

**Operation**

```
FMADD : Rd ← Rs×Rt + Ru
FMSUB : Rd ← Rs×Rt - Ru
FNMADD: Rd ← -(Rs×Rt) - Ru
FNMSUB: Rd ← -(Rs×Rt) + Ru          ; each rounded once
```

**Flags** No integer flag is written. The IEEE exception flags raised are ORed into `FPSR` (`NX` inexact, `UF` underflow, `OF` overflow, `DZ` divide by zero, `NV` invalid); nothing traps.

**Exceptions** None.

Four register operands are available at `len = 01`. The alternative spellings `FMADDD`, ... are aliases.

**Why it is here.** The whole fused multiply-add family is in `FESC`, because its absence would be the single worst gap in the floating-point set: one rounding instead of two, and the inner step of dot products, polynomial evaluation and every matrix kernel. `FESC` gives it four register operands. It replaces the VAX `POLY`, which was the best answer before fused multiply-add.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-fmadd"></a>
#### FMADD

![FMADD, opcode 010000, three parcels, sub-opcode 00010000 (6 bytes)](figures/w/fmadd/02.svg)

![FMADD, opcode 010000, two parcels, sub-opcode 00010000 (4 bytes)](figures/w/fmadd/01.svg)

```
FMADD Rs, Rt, Ru, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FMADD` | `010000 (0x10)` | `00010000 (0x10)` |

Operation, flags and exceptions as for the entry FMADD above; 2 layout forms, each a chart of its own (above).

<a id="w-fmsub"></a>
#### FMSUB

![FMSUB, opcode 010000, three parcels, sub-opcode 00010001 (6 bytes)](figures/w/fmsub/02.svg)

![FMSUB, opcode 010000, two parcels, sub-opcode 00010001 (4 bytes)](figures/w/fmsub/01.svg)

```
FMSUB Rs, Rt, Ru, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FMSUB` | `010000 (0x10)` | `00010001 (0x11)` |

Operation, flags and exceptions as for the entry FMADD above; 2 layout forms, each a chart of its own (above).

<a id="w-fnmadd"></a>
#### FNMADD

![FNMADD, opcode 010000, three parcels, sub-opcode 00010010 (6 bytes)](figures/w/fnmadd/02.svg)

![FNMADD, opcode 010000, two parcels, sub-opcode 00010010 (4 bytes)](figures/w/fnmadd/01.svg)

```
FNMADD Rs, Rt, Ru, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FNMADD` | `010000 (0x10)` | `00010010 (0x12)` |

Operation, flags and exceptions as for the entry FMADD above; 2 layout forms, each a chart of its own (above).

<a id="w-fnmsub"></a>
#### FNMSUB

![FNMSUB, opcode 010000, three parcels, sub-opcode 00010011 (6 bytes)](figures/w/fnmsub/02.svg)

![FNMSUB, opcode 010000, two parcels, sub-opcode 00010011 (4 bytes)](figures/w/fnmsub/01.svg)

```
FNMSUB Rs, Rt, Ru, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FNMSUB` | `010000 (0x10)` | `00010011 (0x13)` |

Operation, flags and exceptions as for the entry FMADD above; 2 layout forms, each a chart of its own (above).

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

![Encoding of FMADD32](figures/r20-fesc-1.svg)

The chart is the layout `r20-fesc-1`, Floating point (FESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FMADD32` | `010000 (0x10)` | `00011000 (0x18)` |
| `FMSUB32` | `010000 (0x10)` | `00011001 (0x19)` |
| `FNMADD32` | `010000 (0x10)` | `00011010 (0x1A)` |
| `FNMSUB32` | `010000 (0x10)` | `00011011 (0x1B)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-fesc-1`](dictionary/by-encoding.md#r20-fesc-1), [`r20-fesc-2`](dictionary/by-encoding.md#r20-fesc-2).

**Operation**

```
As FMADD, in binary32, rounded once
```

**Flags** No integer flag is written. The IEEE exception flags raised are ORed into `FPSR` (`NX` inexact, `UF` underflow, `OF` overflow, `DZ` divide by zero, `NV` invalid); nothing traps.

**Exceptions** None.

**Why it is here.** The `binary32` forms of the fused multiply-add family.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-fmadd32"></a>
#### FMADD32

![FMADD32, opcode 010000, three parcels, sub-opcode 00011000 (6 bytes)](figures/w/fmadd32/02.svg)

![FMADD32, opcode 010000, two parcels, sub-opcode 00011000 (4 bytes)](figures/w/fmadd32/01.svg)

```
FMADD32 Rs, Rt, Ru, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FMADD32` | `010000 (0x10)` | `00011000 (0x18)` |

Operation, flags and exceptions as for the entry FMADD32 above; 2 layout forms, each a chart of its own (above).

<a id="w-fmsub32"></a>
#### FMSUB32

![FMSUB32, opcode 010000, three parcels, sub-opcode 00011001 (6 bytes)](figures/w/fmsub32/02.svg)

![FMSUB32, opcode 010000, two parcels, sub-opcode 00011001 (4 bytes)](figures/w/fmsub32/01.svg)

```
FMSUB32 ...
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FMSUB32` | `010000 (0x10)` | `00011001 (0x19)` |

Operation, flags and exceptions as for the entry FMADD32 above; 2 layout forms, each a chart of its own (above).

<a id="w-fnmadd32"></a>
#### FNMADD32

![FNMADD32, opcode 010000, three parcels, sub-opcode 00011010 (6 bytes)](figures/w/fnmadd32/02.svg)

![FNMADD32, opcode 010000, two parcels, sub-opcode 00011010 (4 bytes)](figures/w/fnmadd32/01.svg)

```
FNMADD32 ...
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FNMADD32` | `010000 (0x10)` | `00011010 (0x1A)` |

Operation, flags and exceptions as for the entry FMADD32 above; 2 layout forms, each a chart of its own (above).

<a id="w-fnmsub32"></a>
#### FNMSUB32

![FNMSUB32, opcode 010000, three parcels, sub-opcode 00011011 (6 bytes)](figures/w/fnmsub32/02.svg)

![FNMSUB32, opcode 010000, two parcels, sub-opcode 00011011 (4 bytes)](figures/w/fnmsub32/01.svg)

```
FNMSUB32 ...
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FNMSUB32` | `010000 (0x10)` | `00011011 (0x1B)` |

Operation, flags and exceptions as for the entry FMADD32 above; 2 layout forms, each a chart of its own (above).

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

![Encoding of FSIGN](figures/r20-fesc-1.svg)

The chart is the layout `r20-fesc-1`, Floating point (FESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FNEG` | `010000 (0x10)` | `00100000 (0x20)` |
| `FABS` | `010000 (0x10)` | `00100001 (0x21)` |
| `FCOPYSIGN` | `010000 (0x10)` | `00100010 (0x22)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-fesc-1`](dictionary/by-encoding.md#r20-fesc-1), [`r20-fesc-2`](dictionary/by-encoding.md#r20-fesc-2).

**Operation**

```
FNEG     : Rd ← Rs with the sign bit flipped
FABS     : Rd ← Rs with the sign bit cleared
FCOPYSIGN: Rd ← magnitude of Rs, sign of Rt
```

**Flags** None. These operate on the bits, do not canonicalise a NaN and raise no exception flag.

**Exceptions** None.

**Why it is here.** Sign and selection operations (negate, absolute value and the like) work on the bits, do not canonicalise a NaN and raise no flag, so they cost almost nothing. The PowerPC 601 floating-point set has the same operations (stated from memory, not checked against a manual). No separate reason is recorded for these three.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-fneg"></a>
#### FNEG

![FNEG, opcode 010000, three parcels, sub-opcode 00100000 (6 bytes)](figures/w/fneg/02.svg)

![FNEG, opcode 010000, two parcels, sub-opcode 00100000 (4 bytes)](figures/w/fneg/01.svg)

```
FNEG Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FNEG` | `010000 (0x10)` | `00100000 (0x20)` |

Operation, flags and exceptions as for the entry FSIGN above; 2 layout forms, each a chart of its own (above).

<a id="w-fabs"></a>
#### FABS

![FABS, opcode 010000, three parcels, sub-opcode 00100001 (6 bytes)](figures/w/fabs/02.svg)

![FABS, opcode 010000, two parcels, sub-opcode 00100001 (4 bytes)](figures/w/fabs/01.svg)

```
FABS Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FABS` | `010000 (0x10)` | `00100001 (0x21)` |

Operation, flags and exceptions as for the entry FSIGN above; 2 layout forms, each a chart of its own (above).

<a id="w-fcopysign"></a>
#### FCOPYSIGN

![FCOPYSIGN, opcode 010000, three parcels, sub-opcode 00100010 (6 bytes)](figures/w/fcopysign/02.svg)

![FCOPYSIGN, opcode 010000, two parcels, sub-opcode 00100010 (4 bytes)](figures/w/fcopysign/01.svg)

```
FCOPYSIGN Rs, Rt, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FCOPYSIGN` | `010000 (0x10)` | `00100010 (0x22)` |

Operation, flags and exceptions as for the entry FSIGN above; 2 layout forms, each a chart of its own (above).


### FMIN: Floating minimum and maximum, binary64

**Mnemonics:** `FMIN`, `FMAX`  (aliases: `FMIND`, `FMAXD`)

**Syntax**

```
FMIN Rs, Rt, Rd
FMAX Rs, Rt, Rd
```

**Encoding**

![Encoding of FMIN](figures/r20-fesc-1.svg)

The chart is the layout `r20-fesc-1`, Floating point (FESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FMIN` | `010000 (0x10)` | `00100011 (0x23)` |
| `FMAX` | `010000 (0x10)` | `00100100 (0x24)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-fesc-1`](dictionary/by-encoding.md#r20-fesc-1), [`r20-fesc-2`](dictionary/by-encoding.md#r20-fesc-2).

**Operation**

```
if Rs is a NaN then Rd ← Rt ; else if Rt is a NaN then Rd ← Rs ; else Rd ← smaller (FMIN) or larger (FMAX)
if both are NaNs the result is the canonical quiet NaN
```

**Flags** No integer flag is written. The IEEE exception flags raised are ORed into `FPSR` (`NX` inexact, `UF` underflow, `OF` overflow, `DZ` divide by zero, `NV` invalid); nothing traps.

**Exceptions** None.

The alternative spellings `FMIND`, `FMAXD` are aliases.

**Why it is here.** The floating counterparts of the integer `MIN` and `MAX`. A NaN operand loses to a number and two NaNs give the canonical quiet NaN.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-fmin"></a>
#### FMIN

![FMIN, opcode 010000, three parcels, sub-opcode 00100011 (6 bytes)](figures/w/fmin/02.svg)

![FMIN, opcode 010000, two parcels, sub-opcode 00100011 (4 bytes)](figures/w/fmin/01.svg)

```
FMIN Rs, Rt, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FMIN` | `010000 (0x10)` | `00100011 (0x23)` |

Operation, flags and exceptions as for the entry FMIN above; 2 layout forms, each a chart of its own (above).

<a id="w-fmax"></a>
#### FMAX

![FMAX, opcode 010000, three parcels, sub-opcode 00100100 (6 bytes)](figures/w/fmax/02.svg)

![FMAX, opcode 010000, two parcels, sub-opcode 00100100 (4 bytes)](figures/w/fmax/01.svg)

```
FMAX Rs, Rt, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FMAX` | `010000 (0x10)` | `00100100 (0x24)` |

Operation, flags and exceptions as for the entry FMIN above; 2 layout forms, each a chart of its own (above).

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

![Encoding of FCLASS](figures/r20-fesc-1.svg)

The chart is the layout `r20-fesc-1`, Floating point (FESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FCLASS` | `010000 (0x10)` | `00101000 (0x28)` |
| `FCLASS32` | `010000 (0x10)` | `00101001 (0x29)` |
| `FCLASS16` | `010000 (0x10)` | `01011100 (0x5C)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-fesc-1`](dictionary/by-encoding.md#r20-fesc-1), [`r20-fesc-2`](dictionary/by-encoding.md#r20-fesc-2).

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

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-fclass"></a>
#### FCLASS

![FCLASS, opcode 010000, three parcels, sub-opcode 00101000 (6 bytes)](figures/w/fclass/02.svg)

![FCLASS, opcode 010000, two parcels, sub-opcode 00101000 (4 bytes)](figures/w/fclass/01.svg)

```
FCLASS Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FCLASS` | `010000 (0x10)` | `00101000 (0x28)` |

Operation, flags and exceptions as for the entry FCLASS above; 2 layout forms, each a chart of its own (above).

<a id="w-fclass32"></a>
#### FCLASS32

![FCLASS32, opcode 010000, three parcels, sub-opcode 00101001 (6 bytes)](figures/w/fclass32/02.svg)

![FCLASS32, opcode 010000, two parcels, sub-opcode 00101001 (4 bytes)](figures/w/fclass32/01.svg)

```
FCLASS32 Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FCLASS32` | `010000 (0x10)` | `00101001 (0x29)` |

Operation, flags and exceptions as for the entry FCLASS above; 2 layout forms, each a chart of its own (above).

<a id="w-fclass16"></a>
#### FCLASS16

![FCLASS16, opcode 010000, three parcels, sub-opcode 01011100 (6 bytes)](figures/w/fclass16/02.svg)

![FCLASS16, opcode 010000, two parcels, sub-opcode 01011100 (4 bytes)](figures/w/fclass16/01.svg)

```
FCLASS16 Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FCLASS16` | `010000 (0x10)` | `01011100 (0x5C)` |

Operation, flags and exceptions as for the entry FCLASS above; 2 layout forms, each a chart of its own (above).

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

![Encoding of FRINT](figures/r20-fesc-1.svg)

The chart is the layout `r20-fesc-1`, Floating point (FESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FRINT` | `010000 (0x10)` | `00110000 (0x30)` |
| `FRINTZ` | `010000 (0x10)` | `00110001 (0x31)` |
| `FRINTM` | `010000 (0x10)` | `00110010 (0x32)` |
| `FRINTP` | `010000 (0x10)` | `00110011 (0x33)` |
| `FRINTA` | `010000 (0x10)` | `00110100 (0x34)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-fesc-1`](dictionary/by-encoding.md#r20-fesc-1), [`r20-fesc-2`](dictionary/by-encoding.md#r20-fesc-2).

**Operation**

```
FRINT : Rd ← Rs rounded to nearest, ties to even
FRINTZ: toward zero         FRINTM: toward -infinity
FRINTP: toward +infinity    FRINTA: to nearest, ties away from zero (C round())
```

**Flags** No integer flag is written. The IEEE exception flags raised are ORed into `FPSR` (`NX` inexact, `UF` underflow, `OF` overflow, `DZ` divide by zero, `NV` invalid); nothing traps.

**Exceptions** None.

The rounding mode is in the opcode, never in a mode bit. The alternative spellings `FRINTD`, `FRINTDZ`, ... are aliases.

**Why it is here.** Rounding to an integral value in each direction (nearest even, toward zero, down, up) is in the set, and `FRINTA`, ties away from zero, serves C's `round()`, which is common in libm; it is a qualifier of the round operation and so costs no new operation.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-frint"></a>
#### FRINT

![FRINT, opcode 010000, three parcels, sub-opcode 00110000 (6 bytes)](figures/w/frint/02.svg)

![FRINT, opcode 010000, two parcels, sub-opcode 00110000 (4 bytes)](figures/w/frint/01.svg)

```
FRINT Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FRINT` | `010000 (0x10)` | `00110000 (0x30)` |

Operation, flags and exceptions as for the entry FRINT above; 2 layout forms, each a chart of its own (above).

<a id="w-frintz"></a>
#### FRINTZ

![FRINTZ, opcode 010000, three parcels, sub-opcode 00110001 (6 bytes)](figures/w/frintz/02.svg)

![FRINTZ, opcode 010000, two parcels, sub-opcode 00110001 (4 bytes)](figures/w/frintz/01.svg)

```
FRINTZ Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FRINTZ` | `010000 (0x10)` | `00110001 (0x31)` |

Operation, flags and exceptions as for the entry FRINT above; 2 layout forms, each a chart of its own (above).

<a id="w-frintm"></a>
#### FRINTM

![FRINTM, opcode 010000, three parcels, sub-opcode 00110010 (6 bytes)](figures/w/frintm/02.svg)

![FRINTM, opcode 010000, two parcels, sub-opcode 00110010 (4 bytes)](figures/w/frintm/01.svg)

```
FRINTM Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FRINTM` | `010000 (0x10)` | `00110010 (0x32)` |

Operation, flags and exceptions as for the entry FRINT above; 2 layout forms, each a chart of its own (above).

<a id="w-frintp"></a>
#### FRINTP

![FRINTP, opcode 010000, three parcels, sub-opcode 00110011 (6 bytes)](figures/w/frintp/02.svg)

![FRINTP, opcode 010000, two parcels, sub-opcode 00110011 (4 bytes)](figures/w/frintp/01.svg)

```
FRINTP Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FRINTP` | `010000 (0x10)` | `00110011 (0x33)` |

Operation, flags and exceptions as for the entry FRINT above; 2 layout forms, each a chart of its own (above).

<a id="w-frinta"></a>
#### FRINTA

![FRINTA, opcode 010000, three parcels, sub-opcode 00110100 (6 bytes)](figures/w/frinta/02.svg)

![FRINTA, opcode 010000, two parcels, sub-opcode 00110100 (4 bytes)](figures/w/frinta/01.svg)

```
FRINTA Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FRINTA` | `010000 (0x10)` | `00110100 (0x34)` |

Operation, flags and exceptions as for the entry FRINT above; 2 layout forms, each a chart of its own (above).

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

![Encoding of FCVT](figures/r20-fesc-1.svg)

The chart is the layout `r20-fesc-1`, Floating point (FESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FCVTDQ` | `010000 (0x10)` | `00111000 (0x38)` |
| `FCVTDQU` | `010000 (0x10)` | `00111110 (0x3E)` |
| `FCVTQD` | `010000 (0x10)` | `00111001 (0x39)` |
| `FCVTQUD` | `010000 (0x10)` | `00111111 (0x3F)` |
| `FCVTDS` | `010000 (0x10)` | `00111010 (0x3A)` |
| `FCVTSD` | `010000 (0x10)` | `00111011 (0x3B)` |
| `FCVTSL` | `010000 (0x10)` | `00111100 (0x3C)` |
| `FCVTLS` | `010000 (0x10)` | `00111101 (0x3D)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-fesc-1`](dictionary/by-encoding.md#r20-fesc-1), [`r20-fesc-2`](dictionary/by-encoding.md#r20-fesc-2).

**Operation**

```
float to integer: truncate toward zero, then saturate; a NaN gives the largest value
integer to float: round to nearest even
```

**Flags** No integer flag is written. The IEEE exception flags raised are ORed into `FPSR` (`NX` inexact, `UF` underflow, `OF` overflow, `DZ` divide by zero, `NV` invalid); nothing traps. A NaN or an out-of-range value raises `NV` and saturates.

**Exceptions** None.

Integer results are 64-bit (`FCVTDQ`, `FCVTDQU`) or 32-bit sign-extended (`FCVTSL`). Unsigned conversion of a negative value is invalid and gives 0.

**Why it is here.** `FCVTDQU` and `FCVTQUD` convert unsigned 64-bit integers to and from `binary64`. C needs both, and without them each takes a branch and several instructions.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-fcvtdq"></a>
#### FCVTDQ

![FCVTDQ, opcode 010000, three parcels, sub-opcode 00111000 (6 bytes)](figures/w/fcvtdq/02.svg)

![FCVTDQ, opcode 010000, two parcels, sub-opcode 00111000 (4 bytes)](figures/w/fcvtdq/01.svg)

```
FCVTDQ Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FCVTDQ` | `010000 (0x10)` | `00111000 (0x38)` |

Operation, flags and exceptions as for the entry FCVT above; 2 layout forms, each a chart of its own (above).

<a id="w-fcvtdqu"></a>
#### FCVTDQU

![FCVTDQU, opcode 010000, three parcels, sub-opcode 00111110 (6 bytes)](figures/w/fcvtdqu/02.svg)

![FCVTDQU, opcode 010000, two parcels, sub-opcode 00111110 (4 bytes)](figures/w/fcvtdqu/01.svg)

```
FCVTDQU Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FCVTDQU` | `010000 (0x10)` | `00111110 (0x3E)` |

Operation, flags and exceptions as for the entry FCVT above; 2 layout forms, each a chart of its own (above).

<a id="w-fcvtqd"></a>
#### FCVTQD

![FCVTQD, opcode 010000, three parcels, sub-opcode 00111001 (6 bytes)](figures/w/fcvtqd/02.svg)

![FCVTQD, opcode 010000, two parcels, sub-opcode 00111001 (4 bytes)](figures/w/fcvtqd/01.svg)

```
FCVTQD Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FCVTQD` | `010000 (0x10)` | `00111001 (0x39)` |

Operation, flags and exceptions as for the entry FCVT above; 2 layout forms, each a chart of its own (above).

<a id="w-fcvtqud"></a>
#### FCVTQUD

![FCVTQUD, opcode 010000, three parcels, sub-opcode 00111111 (6 bytes)](figures/w/fcvtqud/02.svg)

![FCVTQUD, opcode 010000, two parcels, sub-opcode 00111111 (4 bytes)](figures/w/fcvtqud/01.svg)

```
FCVTQUD Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FCVTQUD` | `010000 (0x10)` | `00111111 (0x3F)` |

Operation, flags and exceptions as for the entry FCVT above; 2 layout forms, each a chart of its own (above).

<a id="w-fcvtds"></a>
#### FCVTDS

![FCVTDS, opcode 010000, three parcels, sub-opcode 00111010 (6 bytes)](figures/w/fcvtds/02.svg)

![FCVTDS, opcode 010000, two parcels, sub-opcode 00111010 (4 bytes)](figures/w/fcvtds/01.svg)

```
FCVTDS Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FCVTDS` | `010000 (0x10)` | `00111010 (0x3A)` |

Operation, flags and exceptions as for the entry FCVT above; 2 layout forms, each a chart of its own (above).

<a id="w-fcvtsd"></a>
#### FCVTSD

![FCVTSD, opcode 010000, three parcels, sub-opcode 00111011 (6 bytes)](figures/w/fcvtsd/02.svg)

![FCVTSD, opcode 010000, two parcels, sub-opcode 00111011 (4 bytes)](figures/w/fcvtsd/01.svg)

```
FCVTSD Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FCVTSD` | `010000 (0x10)` | `00111011 (0x3B)` |

Operation, flags and exceptions as for the entry FCVT above; 2 layout forms, each a chart of its own (above).

<a id="w-fcvtsl"></a>
#### FCVTSL

![FCVTSL, opcode 010000, three parcels, sub-opcode 00111100 (6 bytes)](figures/w/fcvtsl/02.svg)

![FCVTSL, opcode 010000, two parcels, sub-opcode 00111100 (4 bytes)](figures/w/fcvtsl/01.svg)

```
FCVTSL Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FCVTSL` | `010000 (0x10)` | `00111100 (0x3C)` |

Operation, flags and exceptions as for the entry FCVT above; 2 layout forms, each a chart of its own (above).

<a id="w-fcvtls"></a>
#### FCVTLS

![FCVTLS, opcode 010000, three parcels, sub-opcode 00111101 (6 bytes)](figures/w/fcvtls/02.svg)

![FCVTLS, opcode 010000, two parcels, sub-opcode 00111101 (4 bytes)](figures/w/fcvtls/01.svg)

```
FCVTLS Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FCVTLS` | `010000 (0x10)` | `00111101 (0x3D)` |

Operation, flags and exceptions as for the entry FCVT above; 2 layout forms, each a chart of its own (above).


<a id="w-fsflags"></a>
### FSFLAGS: Swap the floating-point exception flags

![FSFLAGS, opcode 010000, three parcels, sub-opcode 01000000 (6 bytes)](figures/w/fsflags/02.svg)

![FSFLAGS, opcode 010000, two parcels, sub-opcode 01000000 (4 bytes)](figures/w/fsflags/01.svg)

**Mnemonics:** `FSFLAGS`

**Syntax**

```
FSFLAGS Rs, Rd
```

**Encoding**

![Encoding of FSFLAGS](figures/r20-fesc-1.svg)

The chart is the layout `r20-fesc-1`, Floating point (FESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FSFLAGS` | `010000 (0x10)` | `01000000 (0x40)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-fesc-1`](dictionary/by-encoding.md#r20-fesc-1), [`r20-fesc-2`](dictionary/by-encoding.md#r20-fesc-2).

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

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


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

![Encoding of FHALF](figures/r20-fesc-1.svg)

The chart is the layout `r20-fesc-1`, Floating point (FESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FADD16` | `010000 (0x10)` | `01010000 (0x50)` |
| `FSUB16` | `010000 (0x10)` | `01010001 (0x51)` |
| `FMUL16` | `010000 (0x10)` | `01010010 (0x52)` |
| `FDIV16` | `010000 (0x10)` | `01010011 (0x53)` |
| `FSQRT16` | `010000 (0x10)` | `01010100 (0x54)` |
| `FCMP16` | `010000 (0x10)` | `01010101 (0x55)` |
| `FMADD16` | `010000 (0x10)` | `01011000 (0x58)` |
| `FMSUB16` | `010000 (0x10)` | `01011001 (0x59)` |
| `FNMADD16` | `010000 (0x10)` | `01011010 (0x5A)` |
| `FNMSUB16` | `010000 (0x10)` | `01011011 (0x5B)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-fesc-1`](dictionary/by-encoding.md#r20-fesc-1), [`r20-fesc-2`](dictionary/by-encoding.md#r20-fesc-2).

**Operation**

```
as the binary32 words, in binary16: Rd ← Rd op Rs ; the fused forms take Rs, Rt, Ru, Rd
a half lives in the low 16 bits of a register, sign-extended to 64
```

**Flags** No integer flag is written. The IEEE exception flags raised are ORed into `FPSR` (`NX` inexact, `UF` underflow, `OF` overflow, `DZ` divide by zero, `NV` invalid); nothing traps. `FCMP16` writes `N Z V C` as `FCMP`.

**Exceptions** None.

Results are correctly rounded to nearest even, tininess judged after rounding; a NaN result is the canonical `0x7E00`. Half `FMIN`, `FMAX`, `FRINT*`, bfloat16 and conversions to and from 64-bit integers are open items.

**Why it is here.** Half precision began as a GPU format (NVIDIA's `half`, 2002), spread to machine learning and image formats, and is in CPUs (x86 `F16C` and AVX-512 FP16, ARMv8.2, RISC-V `Zfh` and `Zfhmin`); this account is from memory and not checked against a manual. Two levels are possible: conversions only (about 500 to 1,000 lookup tables, no new operation by the folding rule) and full arithmetic (about 2,000 to 3,500 tables; estimates), and the existing double datapath can compute half correctly rounded. The architecture has both conversions and arithmetic. The leftovers (half `FMIN`, `FRINT*`, bfloat16, 64-bit integer conversions) are open items. 16-bit *integer* arithmetic is not provided: the ALU has one width (9.2.9).

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-fadd16"></a>
#### FADD16

![FADD16, opcode 010000, three parcels, sub-opcode 01010000 (6 bytes)](figures/w/fadd16/02.svg)

![FADD16, opcode 010000, two parcels, sub-opcode 01010000 (4 bytes)](figures/w/fadd16/01.svg)

```
FADD16 Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FADD16` | `010000 (0x10)` | `01010000 (0x50)` |

Operation, flags and exceptions as for the entry FHALF above; 2 layout forms, each a chart of its own (above).

<a id="w-fsub16"></a>
#### FSUB16

![FSUB16, opcode 010000, three parcels, sub-opcode 01010001 (6 bytes)](figures/w/fsub16/02.svg)

![FSUB16, opcode 010000, two parcels, sub-opcode 01010001 (4 bytes)](figures/w/fsub16/01.svg)

```
FSUB16 Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FSUB16` | `010000 (0x10)` | `01010001 (0x51)` |

Operation, flags and exceptions as for the entry FHALF above; 2 layout forms, each a chart of its own (above).

<a id="w-fmul16"></a>
#### FMUL16

![FMUL16, opcode 010000, three parcels, sub-opcode 01010010 (6 bytes)](figures/w/fmul16/02.svg)

![FMUL16, opcode 010000, two parcels, sub-opcode 01010010 (4 bytes)](figures/w/fmul16/01.svg)

```
FMUL16 Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FMUL16` | `010000 (0x10)` | `01010010 (0x52)` |

Operation, flags and exceptions as for the entry FHALF above; 2 layout forms, each a chart of its own (above).

<a id="w-fdiv16"></a>
#### FDIV16

![FDIV16, opcode 010000, three parcels, sub-opcode 01010011 (6 bytes)](figures/w/fdiv16/02.svg)

![FDIV16, opcode 010000, two parcels, sub-opcode 01010011 (4 bytes)](figures/w/fdiv16/01.svg)

```
FDIV16 Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FDIV16` | `010000 (0x10)` | `01010011 (0x53)` |

Operation, flags and exceptions as for the entry FHALF above; 2 layout forms, each a chart of its own (above).

<a id="w-fsqrt16"></a>
#### FSQRT16

![FSQRT16, opcode 010000, three parcels, sub-opcode 01010100 (6 bytes)](figures/w/fsqrt16/02.svg)

![FSQRT16, opcode 010000, two parcels, sub-opcode 01010100 (4 bytes)](figures/w/fsqrt16/01.svg)

```
FSQRT16 Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FSQRT16` | `010000 (0x10)` | `01010100 (0x54)` |

Operation, flags and exceptions as for the entry FHALF above; 2 layout forms, each a chart of its own (above).

<a id="w-fcmp16"></a>
#### FCMP16

![FCMP16, opcode 010000, three parcels, sub-opcode 01010101 (6 bytes)](figures/w/fcmp16/02.svg)

![FCMP16, opcode 010000, two parcels, sub-opcode 01010101 (4 bytes)](figures/w/fcmp16/01.svg)

```
FCMP16 Rd, Rs
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FCMP16` | `010000 (0x10)` | `01010101 (0x55)` |

Operation, flags and exceptions as for the entry FHALF above; 2 layout forms, each a chart of its own (above).

<a id="w-fmadd16"></a>
#### FMADD16

![FMADD16, opcode 010000, three parcels, sub-opcode 01011000 (6 bytes)](figures/w/fmadd16/02.svg)

![FMADD16, opcode 010000, two parcels, sub-opcode 01011000 (4 bytes)](figures/w/fmadd16/01.svg)

```
FMADD16 Rs, Rt, Ru, Rd ...
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FMADD16` | `010000 (0x10)` | `01011000 (0x58)` |

Operation, flags and exceptions as for the entry FHALF above; 2 layout forms, each a chart of its own (above).

<a id="w-fmsub16"></a>
#### FMSUB16

![FMSUB16, opcode 010000, three parcels, sub-opcode 01011001 (6 bytes)](figures/w/fmsub16/02.svg)

![FMSUB16, opcode 010000, two parcels, sub-opcode 01011001 (4 bytes)](figures/w/fmsub16/01.svg)

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FMSUB16` | `010000 (0x10)` | `01011001 (0x59)` |

Operation, flags and exceptions as for the entry FHALF above; 2 layout forms, each a chart of its own (above).

<a id="w-fnmadd16"></a>
#### FNMADD16

![FNMADD16, opcode 010000, three parcels, sub-opcode 01011010 (6 bytes)](figures/w/fnmadd16/02.svg)

![FNMADD16, opcode 010000, two parcels, sub-opcode 01011010 (4 bytes)](figures/w/fnmadd16/01.svg)

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FNMADD16` | `010000 (0x10)` | `01011010 (0x5A)` |

Operation, flags and exceptions as for the entry FHALF above; 2 layout forms, each a chart of its own (above).

<a id="w-fnmsub16"></a>
#### FNMSUB16

![FNMSUB16, opcode 010000, three parcels, sub-opcode 01011011 (6 bytes)](figures/w/fnmsub16/02.svg)

![FNMSUB16, opcode 010000, two parcels, sub-opcode 01011011 (4 bytes)](figures/w/fnmsub16/01.svg)

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FNMSUB16` | `010000 (0x10)` | `01011011 (0x5B)` |

Operation, flags and exceptions as for the entry FHALF above; 2 layout forms, each a chart of its own (above).


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

![Encoding of FCVTH](figures/r20-fesc-1.svg)

The chart is the layout `r20-fesc-1`, Floating point (FESC), two parcels (`len = 01`): From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FCVTSH` | `010000 (0x10)` | `01100000 (0x60)` |
| `FCVTHS` | `010000 (0x10)` | `01100001 (0x61)` |
| `FCVTDH` | `010000 (0x10)` | `01100010 (0x62)` |
| `FCVTHD` | `010000 (0x10)` | `01100011 (0x63)` |
| `FCVTHL` | `010000 (0x10)` | `01100100 (0x64)` |
| `FCVTLH` | `010000 (0x10)` | `01100101 (0x65)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-fesc-1`](dictionary/by-encoding.md#r20-fesc-1), [`r20-fesc-2`](dictionary/by-encoding.md#r20-fesc-2).

**Operation**

```
narrowing: round to nearest even ; widening: exact
FCVTHL of a NaN or an infinity is invalid and saturates; truncating a fraction is inexact
```

**Flags** No integer flag is written. The IEEE exception flags raised are ORed into `FPSR` (`NX` inexact, `UF` underflow, `OF` overflow, `DZ` divide by zero, `NV` invalid); nothing traps.

**Exceptions** None.

**Why it is here.** The conversion half of the `binary16` support (see `FHALF`). The conversions are the part machine-learning code needs most, because a half is normally loaded and stored with `MOVW`, converted, computed in single or double, and converted back.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-fcvtsh"></a>
#### FCVTSH

![FCVTSH, opcode 010000, three parcels, sub-opcode 01100000 (6 bytes)](figures/w/fcvtsh/02.svg)

![FCVTSH, opcode 010000, two parcels, sub-opcode 01100000 (4 bytes)](figures/w/fcvtsh/01.svg)

```
FCVTSH Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FCVTSH` | `010000 (0x10)` | `01100000 (0x60)` |

Operation, flags and exceptions as for the entry FCVTH above; 2 layout forms, each a chart of its own (above).

<a id="w-fcvths"></a>
#### FCVTHS

![FCVTHS, opcode 010000, three parcels, sub-opcode 01100001 (6 bytes)](figures/w/fcvths/02.svg)

![FCVTHS, opcode 010000, two parcels, sub-opcode 01100001 (4 bytes)](figures/w/fcvths/01.svg)

```
FCVTHS Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FCVTHS` | `010000 (0x10)` | `01100001 (0x61)` |

Operation, flags and exceptions as for the entry FCVTH above; 2 layout forms, each a chart of its own (above).

<a id="w-fcvtdh"></a>
#### FCVTDH

![FCVTDH, opcode 010000, three parcels, sub-opcode 01100010 (6 bytes)](figures/w/fcvtdh/02.svg)

![FCVTDH, opcode 010000, two parcels, sub-opcode 01100010 (4 bytes)](figures/w/fcvtdh/01.svg)

```
FCVTDH Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FCVTDH` | `010000 (0x10)` | `01100010 (0x62)` |

Operation, flags and exceptions as for the entry FCVTH above; 2 layout forms, each a chart of its own (above).

<a id="w-fcvthd"></a>
#### FCVTHD

![FCVTHD, opcode 010000, three parcels, sub-opcode 01100011 (6 bytes)](figures/w/fcvthd/02.svg)

![FCVTHD, opcode 010000, two parcels, sub-opcode 01100011 (4 bytes)](figures/w/fcvthd/01.svg)

```
FCVTHD Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FCVTHD` | `010000 (0x10)` | `01100011 (0x63)` |

Operation, flags and exceptions as for the entry FCVTH above; 2 layout forms, each a chart of its own (above).

<a id="w-fcvthl"></a>
#### FCVTHL

![FCVTHL, opcode 010000, three parcels, sub-opcode 01100100 (6 bytes)](figures/w/fcvthl/02.svg)

![FCVTHL, opcode 010000, two parcels, sub-opcode 01100100 (4 bytes)](figures/w/fcvthl/01.svg)

```
FCVTHL Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FCVTHL` | `010000 (0x10)` | `01100100 (0x64)` |

Operation, flags and exceptions as for the entry FCVTH above; 2 layout forms, each a chart of its own (above).

<a id="w-fcvtlh"></a>
#### FCVTLH

![FCVTLH, opcode 010000, three parcels, sub-opcode 01100101 (6 bytes)](figures/w/fcvtlh/02.svg)

![FCVTLH, opcode 010000, two parcels, sub-opcode 01100101 (4 bytes)](figures/w/fcvtlh/01.svg)

```
FCVTLH Rs, Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FCVTLH` | `010000 (0x10)` | `01100101 (0x65)` |

Operation, flags and exceptions as for the entry FCVTH above; 2 layout forms, each a chart of its own (above).
<!-- /entries:9.12 -->

## 9.13 Atomics and ordering

*Cf. chapter 7, section 7.12 (the atomic and ordering instructions), section 7.3 (the atomics in detail) and section 7.2 (the memory model).*

**9.13.1** The atomic escape `ATOM` (opcode `010001 (0x11)`) holds `CAS`, `SWAP`, `XADD`, `XAND`, `XOR_`, `XXOR`, `XMAX`, `XMIN`, `XMAXU` and `XMINU`, each with a `_DB` variant that adds a barrier, and `LL` and `SC`; `FENCE`, `WFE`, `SEV`, `ISYNC` and `HINT` are in `SYS`. Their semantics, ordering rules and the reservation monitor are in chapter 7. *(opcode `010001 (0x11)`)*

**9.13.2** `CAS` operates on 4 or 8 bytes; an 8-byte compare-and-swap may span two adjacent 4-byte fields, because the usual lock-and-count fast path of an operating system is exactly that (an 8-byte whole over two 4-byte members). *(D)* The encoding of the `CAS` size is unspecified. *(S)*

*Commentary.* The official entry of each instruction is below, in this section; chapter 7 gives the reasons, the memory model and the use. **Impact.** *Kernel:* the entries below are all a kernel needs to write its locks; chapter 7 explains how they compose. *Compiler:* a lock acquire is one `_DB` instruction. *Hardware:* a reservation monitor beside the data cache.

<!-- entries:9.13 -->
### CAS: Compare and swap

**Mnemonics:** `CAS`, `CASDB`

**Syntax**

```
CAS expected, new, (address)        ; operand placement and size encoding unspecified; size is 4 or 8 bytes
CASDB ...                            ; with a full barrier
```

**Encoding**

![Encoding of CAS](figures/r20-atom-1.svg)

The chart is the layout `r20-atom-1`, Atomics (ATOM), two parcels (`len = 01`): From `len = 01`. The placement of the operands is not specified.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `CAS` | `010001 (0x11)` | `00000000 (0x00)` |
| `CASDB` | `010001 (0x11)` | `00000001 (0x01)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-atom-1`](dictionary/by-encoding.md#r20-atom-1), [`r20-atom-2`](dictionary/by-encoding.md#r20-atom-2).

**Operation**

```
old ← M[address]                         ; 4 or 8 bytes, naturally aligned
if old = expected then M[address] ← new
result ← old          ; the program compares result with expected to learn whether the swap happened
```

**Flags** Not specified beyond "none for the read-modify-write forms"; `SC` reports success in its result register.

**Exceptions** Page fault, protection fault, alignment fault (the address must be naturally aligned) or bus error. The access is atomic with respect to every initiator, cores and devices alike.

The sub-opcodes and the semantics of this group are specified; the placement of the operands of each form is unspecified, and the forms below name the roles.

**Why it is here.** The barrier-fused variants are taken from LoongArch's pragmatism: a lock acquire is one instruction rather than an atomic followed by a `FENCE`, and that pair is in every critical section of the system. With the other multiprocessor operations the atomics make the seventeen-operation SMP umbrella (7.1). They are defined on a reservation monitor and not on a bus lock (2.5).

**Cf.** 7.12 (the atomic instructions), 7.3 (the atomics in detail: the reservation monitor), 7.2 (the memory model).

**Status** specified; **not yet implemented** in the reference executor.

<a id="w-cas"></a>
#### CAS

![CAS, opcode 010001, three parcels, sub-opcode 00000000 (6 bytes)](figures/w/cas/02.svg)

![CAS, opcode 010001, two parcels, sub-opcode 00000000 (4 bytes)](figures/w/cas/01.svg)

```
CAS expected, new, (address)
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `CAS` | `010001 (0x11)` | `00000000 (0x00)` |

Operation, flags and exceptions as for the entry CAS above; 2 layout forms, each a chart of its own (above).

<a id="w-casdb"></a>
#### CASDB

![CASDB, opcode 010001, three parcels, sub-opcode 00000001 (6 bytes)](figures/w/casdb/02.svg)

![CASDB, opcode 010001, two parcels, sub-opcode 00000001 (4 bytes)](figures/w/casdb/01.svg)

```
CASDB ...
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `CASDB` | `010001 (0x11)` | `00000001 (0x01)` |

Operation, flags and exceptions as for the entry CAS above; 2 layout forms, each a chart of its own (above).


### SWAP: Atomic exchange

**Mnemonics:** `SWAP`, `SWAPDB`

**Syntax**

```
SWAP value, (address)
SWAPDB ...
```

**Encoding**

![Encoding of SWAP](figures/r20-atom-1.svg)

The chart is the layout `r20-atom-1`, Atomics (ATOM), two parcels (`len = 01`): From `len = 01`. The placement of the operands is not specified.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `SWAP` | `010001 (0x11)` | `00000010 (0x02)` |
| `SWAPDB` | `010001 (0x11)` | `00000011 (0x03)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-atom-1`](dictionary/by-encoding.md#r20-atom-1), [`r20-atom-2`](dictionary/by-encoding.md#r20-atom-2).

**Operation**

```
old ← M[address] ; M[address] ← value ; result ← old
```

**Flags** Not specified beyond "none for the read-modify-write forms"; `SC` reports success in its result register.

**Exceptions** Page fault, protection fault, alignment fault (the address must be naturally aligned) or bus error. The access is atomic with respect to every initiator, cores and devices alike.

The sub-opcodes and the semantics of this group are specified; the placement of the operands of each form is unspecified, and the forms below name the roles.

**Why it is here.** One of the read-modify-write atomics of the `ATOM` group (see `CAS`). No separate reason is recorded for it.

**Cf.** 7.12 (the atomic instructions), 7.3 (the atomics in detail: the reservation monitor), 7.2 (the memory model).

**Status** specified; **not yet implemented** in the reference executor.

<a id="w-swap"></a>
#### SWAP

![SWAP, opcode 010001, three parcels, sub-opcode 00000010 (6 bytes)](figures/w/swap/02.svg)

![SWAP, opcode 010001, two parcels, sub-opcode 00000010 (4 bytes)](figures/w/swap/01.svg)

```
SWAP value, (address)
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `SWAP` | `010001 (0x11)` | `00000010 (0x02)` |

Operation, flags and exceptions as for the entry SWAP above; 2 layout forms, each a chart of its own (above).

<a id="w-swapdb"></a>
#### SWAPDB

![SWAPDB, opcode 010001, three parcels, sub-opcode 00000011 (6 bytes)](figures/w/swapdb/02.svg)

![SWAPDB, opcode 010001, two parcels, sub-opcode 00000011 (4 bytes)](figures/w/swapdb/01.svg)

```
SWAPDB ...
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `SWAPDB` | `010001 (0x11)` | `00000011 (0x03)` |

Operation, flags and exceptions as for the entry SWAP above; 2 layout forms, each a chart of its own (above).


### XADD: Atomic fetch and add

**Mnemonics:** `XADD`, `XADDDB`

**Syntax**

```
XADD value, (address)
XADDDB ...
```

**Encoding**

![Encoding of XADD](figures/r20-atom-1.svg)

The chart is the layout `r20-atom-1`, Atomics (ATOM), two parcels (`len = 01`): From `len = 01`. The placement of the operands is not specified.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `XADD` | `010001 (0x11)` | `00000100 (0x04)` |
| `XADDDB` | `010001 (0x11)` | `00000101 (0x05)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-atom-1`](dictionary/by-encoding.md#r20-atom-1), [`r20-atom-2`](dictionary/by-encoding.md#r20-atom-2).

**Operation**

```
old ← M[address] ; M[address] ← old + value ; result ← old
```

**Flags** Not specified beyond "none for the read-modify-write forms"; `SC` reports success in its result register.

**Exceptions** Page fault, protection fault, alignment fault (the address must be naturally aligned) or bus error. The access is atomic with respect to every initiator, cores and devices alike.

The sub-opcodes and the semantics of this group are specified; the placement of the operands of each form is unspecified, and the forms below name the roles.

**Why it is here.** One of the fetch-and-operate atomics of `ATOM` (see `CAS`), in the place of the PDP-11's read-modify-write instructions, which were indivisible on the Unibus through the `DATIP`/`DATO` pair (7.1).

**Cf.** 7.12 (the atomic instructions), 7.3 (the atomics in detail: the reservation monitor), 7.2 (the memory model).

**Status** specified; **not yet implemented** in the reference executor.

<a id="w-xadd"></a>
#### XADD

![XADD, opcode 010001, three parcels, sub-opcode 00000100 (6 bytes)](figures/w/xadd/02.svg)

![XADD, opcode 010001, two parcels, sub-opcode 00000100 (4 bytes)](figures/w/xadd/01.svg)

```
XADD value, (address)
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `XADD` | `010001 (0x11)` | `00000100 (0x04)` |

Operation, flags and exceptions as for the entry XADD above; 2 layout forms, each a chart of its own (above).

<a id="w-xadddb"></a>
#### XADDDB

![XADDDB, opcode 010001, three parcels, sub-opcode 00000101 (6 bytes)](figures/w/xadddb/02.svg)

![XADDDB, opcode 010001, two parcels, sub-opcode 00000101 (4 bytes)](figures/w/xadddb/01.svg)

```
XADDDB ...
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `XADDDB` | `010001 (0x11)` | `00000101 (0x05)` |

Operation, flags and exceptions as for the entry XADD above; 2 layout forms, each a chart of its own (above).


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

![Encoding of XAND](figures/r20-atom-1.svg)

The chart is the layout `r20-atom-1`, Atomics (ATOM), two parcels (`len = 01`): From `len = 01`. The placement of the operands is not specified.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `XAND` | `010001 (0x11)` | `00000110 (0x06)` |
| `XANDDB` | `010001 (0x11)` | `00000111 (0x07)` |
| `XOR_` | `010001 (0x11)` | `00001000 (0x08)` |
| `XOR_DB` | `010001 (0x11)` | `00001001 (0x09)` |
| `XXOR` | `010001 (0x11)` | `00001010 (0x0A)` |
| `XXORDB` | `010001 (0x11)` | `00001011 (0x0B)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-atom-1`](dictionary/by-encoding.md#r20-atom-1), [`r20-atom-2`](dictionary/by-encoding.md#r20-atom-2).

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

The sub-opcodes and the semantics of this group are specified; the placement of the operands of each form is unspecified, and the forms below name the roles.

**Why it is here.** The fetch-and-and, or and xor atomics of `ATOM` (see `CAS`). No separate reason is recorded for them.

**Cf.** 7.12 (the atomic instructions), 7.3 (the atomics in detail: the reservation monitor), 7.2 (the memory model).

**Status** specified; **not yet implemented** in the reference executor.

<a id="w-xand"></a>
#### XAND

![XAND, opcode 010001, three parcels, sub-opcode 00000110 (6 bytes)](figures/w/xand/02.svg)

![XAND, opcode 010001, two parcels, sub-opcode 00000110 (4 bytes)](figures/w/xand/01.svg)

```
XAND value, (address)
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `XAND` | `010001 (0x11)` | `00000110 (0x06)` |

Operation, flags and exceptions as for the entry XAND above; 2 layout forms, each a chart of its own (above).

<a id="w-xanddb"></a>
#### XANDDB

![XANDDB, opcode 010001, three parcels, sub-opcode 00000111 (6 bytes)](figures/w/xanddb/02.svg)

![XANDDB, opcode 010001, two parcels, sub-opcode 00000111 (4 bytes)](figures/w/xanddb/01.svg)

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `XANDDB` | `010001 (0x11)` | `00000111 (0x07)` |

Operation, flags and exceptions as for the entry XAND above; 2 layout forms, each a chart of its own (above).

<a id="w-xor-"></a>
#### XOR_

![XOR_, opcode 010001, three parcels, sub-opcode 00001000 (6 bytes)](figures/w/xor-/02.svg)

![XOR_, opcode 010001, two parcels, sub-opcode 00001000 (4 bytes)](figures/w/xor-/01.svg)

```
XOR_ value, (address)
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `XOR_` | `010001 (0x11)` | `00001000 (0x08)` |

Operation, flags and exceptions as for the entry XAND above; 2 layout forms, each a chart of its own (above).

<a id="w-xor-db"></a>
#### XOR_DB

![XOR_DB, opcode 010001, three parcels, sub-opcode 00001001 (6 bytes)](figures/w/xor-db/02.svg)

![XOR_DB, opcode 010001, two parcels, sub-opcode 00001001 (4 bytes)](figures/w/xor-db/01.svg)

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `XOR_DB` | `010001 (0x11)` | `00001001 (0x09)` |

Operation, flags and exceptions as for the entry XAND above; 2 layout forms, each a chart of its own (above).

<a id="w-xxor"></a>
#### XXOR

![XXOR, opcode 010001, three parcels, sub-opcode 00001010 (6 bytes)](figures/w/xxor/02.svg)

![XXOR, opcode 010001, two parcels, sub-opcode 00001010 (4 bytes)](figures/w/xxor/01.svg)

```
XXOR value, (address)
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `XXOR` | `010001 (0x11)` | `00001010 (0x0A)` |

Operation, flags and exceptions as for the entry XAND above; 2 layout forms, each a chart of its own (above).

<a id="w-xxordb"></a>
#### XXORDB

![XXORDB, opcode 010001, three parcels, sub-opcode 00001011 (6 bytes)](figures/w/xxordb/02.svg)

![XXORDB, opcode 010001, two parcels, sub-opcode 00001011 (4 bytes)](figures/w/xxordb/01.svg)

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `XXORDB` | `010001 (0x11)` | `00001011 (0x0B)` |

Operation, flags and exceptions as for the entry XAND above; 2 layout forms, each a chart of its own (above).


### XMAX: Atomic fetch and minimum or maximum

**Mnemonics:** `XMAX`, `XMAXDB`, `XMIN`, `XMINDB`, `XMAXU`, `XMAXUDB`, `XMINU`, `XMINUDB`

**Syntax**

```
XMAX value, (address)
XMIN ..., XMAXU ..., XMINU ...
each with a DB form
```

**Encoding**

![Encoding of XMAX](figures/r20-atom-1.svg)

The chart is the layout `r20-atom-1`, Atomics (ATOM), two parcels (`len = 01`): From `len = 01`. The placement of the operands is not specified.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `XMAX` | `010001 (0x11)` | `00001100 (0x0C)` |
| `XMAXDB` | `010001 (0x11)` | `00001101 (0x0D)` |
| `XMIN` | `010001 (0x11)` | `00001110 (0x0E)` |
| `XMINDB` | `010001 (0x11)` | `00001111 (0x0F)` |
| `XMAXU` | `010001 (0x11)` | `00010000 (0x10)` |
| `XMAXUDB` | `010001 (0x11)` | `00010001 (0x11)` |
| `XMINU` | `010001 (0x11)` | `00010010 (0x12)` |
| `XMINUDB` | `010001 (0x11)` | `00010011 (0x13)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-atom-1`](dictionary/by-encoding.md#r20-atom-1), [`r20-atom-2`](dictionary/by-encoding.md#r20-atom-2).

**Operation**

```
old ← M[address] ; M[address] ← max(old, value) (XMAX, XMAXU) or min (XMIN, XMINU) ; result ← old
signed for XMAX and XMIN, unsigned for the U forms
```

**Flags** Not specified beyond "none for the read-modify-write forms"; `SC` reports success in its result register.

**Exceptions** Page fault, protection fault, alignment fault (the address must be naturally aligned) or bus error. The access is atomic with respect to every initiator, cores and devices alike.

The sub-opcodes and the semantics of this group are specified; the placement of the operands of each form is unspecified, and the forms below name the roles.

**Why it is here.** The fetch-and-minimum and maximum atomics, borrowed from LoongArch's richer atomic set: each is a couple of hundred lookup tables and saves a compare-and-swap retry loop.

**Cf.** 7.12 (the atomic instructions), 7.3 (the atomics in detail: the reservation monitor), 7.2 (the memory model).

**Status** specified; **not yet implemented** in the reference executor.

<a id="w-xmax"></a>
#### XMAX

![XMAX, opcode 010001, three parcels, sub-opcode 00001100 (6 bytes)](figures/w/xmax/02.svg)

![XMAX, opcode 010001, two parcels, sub-opcode 00001100 (4 bytes)](figures/w/xmax/01.svg)

```
XMAX value, (address)
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `XMAX` | `010001 (0x11)` | `00001100 (0x0C)` |

Operation, flags and exceptions as for the entry XMAX above; 2 layout forms, each a chart of its own (above).

<a id="w-xmaxdb"></a>
#### XMAXDB

![XMAXDB, opcode 010001, three parcels, sub-opcode 00001101 (6 bytes)](figures/w/xmaxdb/02.svg)

![XMAXDB, opcode 010001, two parcels, sub-opcode 00001101 (4 bytes)](figures/w/xmaxdb/01.svg)

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `XMAXDB` | `010001 (0x11)` | `00001101 (0x0D)` |

Operation, flags and exceptions as for the entry XMAX above; 2 layout forms, each a chart of its own (above).

<a id="w-xmin"></a>
#### XMIN

![XMIN, opcode 010001, three parcels, sub-opcode 00001110 (6 bytes)](figures/w/xmin/02.svg)

![XMIN, opcode 010001, two parcels, sub-opcode 00001110 (4 bytes)](figures/w/xmin/01.svg)

```
XMIN ..., XMAXU ..., XMINU ...
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `XMIN` | `010001 (0x11)` | `00001110 (0x0E)` |

Operation, flags and exceptions as for the entry XMAX above; 2 layout forms, each a chart of its own (above).

<a id="w-xmindb"></a>
#### XMINDB

![XMINDB, opcode 010001, three parcels, sub-opcode 00001111 (6 bytes)](figures/w/xmindb/02.svg)

![XMINDB, opcode 010001, two parcels, sub-opcode 00001111 (4 bytes)](figures/w/xmindb/01.svg)

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `XMINDB` | `010001 (0x11)` | `00001111 (0x0F)` |

Operation, flags and exceptions as for the entry XMAX above; 2 layout forms, each a chart of its own (above).

<a id="w-xmaxu"></a>
#### XMAXU

![XMAXU, opcode 010001, three parcels, sub-opcode 00010000 (6 bytes)](figures/w/xmaxu/02.svg)

![XMAXU, opcode 010001, two parcels, sub-opcode 00010000 (4 bytes)](figures/w/xmaxu/01.svg)

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `XMAXU` | `010001 (0x11)` | `00010000 (0x10)` |

Operation, flags and exceptions as for the entry XMAX above; 2 layout forms, each a chart of its own (above).

<a id="w-xmaxudb"></a>
#### XMAXUDB

![XMAXUDB, opcode 010001, three parcels, sub-opcode 00010001 (6 bytes)](figures/w/xmaxudb/02.svg)

![XMAXUDB, opcode 010001, two parcels, sub-opcode 00010001 (4 bytes)](figures/w/xmaxudb/01.svg)

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `XMAXUDB` | `010001 (0x11)` | `00010001 (0x11)` |

Operation, flags and exceptions as for the entry XMAX above; 2 layout forms, each a chart of its own (above).

<a id="w-xminu"></a>
#### XMINU

![XMINU, opcode 010001, three parcels, sub-opcode 00010010 (6 bytes)](figures/w/xminu/02.svg)

![XMINU, opcode 010001, two parcels, sub-opcode 00010010 (4 bytes)](figures/w/xminu/01.svg)

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `XMINU` | `010001 (0x11)` | `00010010 (0x12)` |

Operation, flags and exceptions as for the entry XMAX above; 2 layout forms, each a chart of its own (above).

<a id="w-xminudb"></a>
#### XMINUDB

![XMINUDB, opcode 010001, three parcels, sub-opcode 00010011 (6 bytes)](figures/w/xminudb/02.svg)

![XMINUDB, opcode 010001, two parcels, sub-opcode 00010011 (4 bytes)](figures/w/xminudb/01.svg)

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `XMINUDB` | `010001 (0x11)` | `00010011 (0x13)` |

Operation, flags and exceptions as for the entry XMAX above; 2 layout forms, each a chart of its own (above).


### LLSC: Load-linked and store-conditional

**Mnemonics:** `LL`, `SC`

**Syntax**

```
LL (address), Rd
SC value, (address), result
```

**Encoding**

![Encoding of LLSC](figures/r20-atom-1.svg)

The chart is the layout `r20-atom-1`, Atomics (ATOM), two parcels (`len = 01`): From `len = 01`. The placement of the operands is not specified.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `LL` | `010001 (0x11)` | `00100000 (0x20)` |
| `SC` | `010001 (0x11)` | `00100001 (0x21)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-atom-1`](dictionary/by-encoding.md#r20-atom-1), [`r20-atom-2`](dictionary/by-encoding.md#r20-atom-2).

**Operation**

```
LL: Rd ← M[address] ; take a reservation on the granule containing address
SC: if the reservation is intact then M[address] ← value ; result ← 0 (success)
    else nothing is written ; result ← 1 (failure)
a write to the granule by any initiator, core or device, clears the reservation
```

**Flags** Not specified beyond "none for the read-modify-write forms"; `SC` reports success in its result register.

**Exceptions** Page fault, protection fault, alignment fault (the address must be naturally aligned) or bus error. The access is atomic with respect to every initiator, cores and devices alike.

A short `LL`/`SC` sequence must eventually succeed if no other initiator keeps writing the granule (the RISC-V guarantee for constrained sequences). The sub-opcodes and the semantics of this group are specified; the placement of the operands of each form is unspecified, and the forms below name the roles. The result convention shown for `SC` is the usual one and is unspecified.

**Why it is here.** Load-linked and store-conditional, with the reservation a monitor, because a monitor maps onto the exclusive access of AXI and of FPGA and modern memory systems, where the Unibus's locked read-modify-write (`DATIP`/`DATO`) does not scale as cores multiply. A short sequence must eventually succeed if no other initiator keeps writing the granule, the RISC-V rule.

**Cf.** 7.12 (the atomic instructions), 7.3 (the atomics in detail: the reservation monitor), 7.2 (the memory model).

**Status** specified; **not yet implemented** in the reference executor.

<a id="w-ll"></a>
#### LL

![LL, opcode 010001, three parcels, sub-opcode 00100000 (6 bytes)](figures/w/ll/02.svg)

![LL, opcode 010001, two parcels, sub-opcode 00100000 (4 bytes)](figures/w/ll/01.svg)

```
LL (address), Rd
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `LL` | `010001 (0x11)` | `00100000 (0x20)` |

Operation, flags and exceptions as for the entry LLSC above; 2 layout forms, each a chart of its own (above).

<a id="w-sc"></a>
#### SC

![SC, opcode 010001, three parcels, sub-opcode 00100001 (6 bytes)](figures/w/sc/02.svg)

![SC, opcode 010001, two parcels, sub-opcode 00100001 (4 bytes)](figures/w/sc/01.svg)

```
SC value, (address), result
```

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `SC` | `010001 (0x11)` | `00100001 (0x21)` |

Operation, flags and exceptions as for the entry LLSC above; 2 layout forms, each a chart of its own (above).
<!-- /entries:9.13 -->

## 9.14 System instructions, exceptions and interrupts

*Cf. chapter 6, section 6.7 (system instructions, exceptions and interrupts), section 6.2 (exceptions and interrupts) and section 6.3 (system registers).*

**9.14.1** The system escape `SYS` (opcode `010100 (0x14)`) holds the privileged and system instructions: `TRAP`, `TRAPL`, `RTI`, `RTT`, `RET`, `HALT`, `BPT`, `MTPS`, `MFPS`, `SPL`, `MFSR`, `MTSR`, `MTDP`, `MFDP`, `MFCPUID`, `PROBER`, `PROBEW`, `PUSHX`, `POPX`, and the translation and cache maintenance instructions (`TLBI`, `TLBIA`, `TLBSYNC`, `MTASID`, `MFASID`, `ICINV`, `ICINVA`). The user-memory guard instructions `STUA` and `CLUA` are described with them. *(opcode `010100 (0x14)`)*

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

![Encoding of NOP](figures/r20-sysn-0.svg)

The chart is the layout `r20-sysn-0`, System, no operand, one parcel (`len = 00`): The `reg` field is the class (0); class 0 takes a minor opcode from `low`.

| Mnemonic | Opcode | `reg` | `low` |
|---|---|---|---|
| `NOP` | `010100 (0x14)` | `0000 (0x0)` | `0000 (0x0)` |
| `LPAD` | `010100 (0x14)` | `0000 (0x0)` | `1001 (0x9)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sysn-0`](dictionary/by-encoding.md#r20-sysn-0), [`r20-sysn-1`](dictionary/by-encoding.md#r20-sysn-1), [`r20-sysn-2`](dictionary/by-encoding.md#r20-sysn-2).

**Operation**

```
nothing
```

**Flags** None written.

**Exceptions** None.

`LPAD` marks a legal target of an indirect jump or call; no instruction enforces it in ABI version 1.

**Why it is here.** `NOP` is common and has no story; `LPAD` is the landing pad. Landing pads mark the legal targets of indirect jumps and calls so that jump-oriented attacks can be stopped at the transfer, as Intel's indirect-branch tracking and ARM's branch target identification do and OpenBSD enforces. ABI version 1 leaves them off (an open item of the instruction set, 9.21), and the assembler provides `.lpad`; the kernel pain-points and mitigations reports record why deciding later is more expensive (appendix A, section A.1).

**Cf.** Appendix A, section A.1 (landing pads).

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-nop"></a>
#### NOP

![NOP, opcode 010100, three parcels (6 bytes)](figures/w/nop/03.svg)

![NOP, opcode 010100, two parcels (4 bytes)](figures/w/nop/02.svg)

![NOP, opcode 010100, one parcel (2 bytes)](figures/w/nop/01.svg)

```
NOP
```

| Mnemonic | Opcode | `reg` | `low` |
|---|---|---|---|
| `NOP` | `010100 (0x14)` | `0000 (0x0)` | `0000 (0x0)` |

Operation, flags and exceptions as for the entry NOP above; 3 layout forms, each a chart of its own (above).

<a id="w-lpad"></a>
#### LPAD

![LPAD, opcode 010100, three parcels (6 bytes)](figures/w/lpad/03.svg)

![LPAD, opcode 010100, two parcels (4 bytes)](figures/w/lpad/02.svg)

![LPAD, opcode 010100, one parcel (2 bytes)](figures/w/lpad/01.svg)

```
LPAD
```

| Mnemonic | Opcode | `reg` | `low` |
|---|---|---|---|
| `LPAD` | `010100 (0x14)` | `0000 (0x0)` | `1001 (0x9)` |

Operation, flags and exceptions as for the entry NOP above; 3 layout forms, each a chart of its own (above).


### RTI: Return from interrupt or exception

**Mnemonics:** `RTI`, `RTT`

**Syntax**

```
RTI
RTT
```

**Encoding**

![Encoding of RTI](figures/r20-sysn-0.svg)

The chart is the layout `r20-sysn-0`, System, no operand, one parcel (`len = 00`): The `reg` field is the class (0); class 0 takes a minor opcode from `low`.

| Mnemonic | Opcode | `reg` | `low` |
|---|---|---|---|
| `RTI` | `010100 (0x14)` | `0000 (0x0)` | `0001 (0x1)` |
| `RTT` | `010100 (0x14)` | `0000 (0x0)` | `0010 (0x2)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sysn-0`](dictionary/by-encoding.md#r20-sysn-0), [`r20-sysn-1`](dictionary/by-encoding.md#r20-sysn-1), [`r20-sysn-2`](dictionary/by-encoding.md#r20-sysn-2).

**Operation**

```
PC ← EPC ; PSW ← EPSW           ; a PSW with the reserved mode 2 in either mode field aborts
RTT: and then set the trace bit T after the return
```

**Flags** Replaced by `EPSW`, including the flags.

**Exceptions** Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector.

`RTT` sets the trace bit *after* the return rather than before, which is what lets a debugger single-step out of its own trap handler.

**Why it is here.** `RTT` looks redundant against `RTI`, and stays: it sets the trace bit *after* the return rather than before, which is what lets a debugger single-step out of its own trap handler.

**Cf.** 6.2 (exceptions and interrupts), 6.7.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-rti"></a>
#### RTI

![RTI, opcode 010100, three parcels (6 bytes)](figures/w/rti/03.svg)

![RTI, opcode 010100, two parcels (4 bytes)](figures/w/rti/02.svg)

![RTI, opcode 010100, one parcel (2 bytes)](figures/w/rti/01.svg)

```
RTI
```

| Mnemonic | Opcode | `reg` | `low` |
|---|---|---|---|
| `RTI` | `010100 (0x14)` | `0000 (0x0)` | `0001 (0x1)` |

Operation, flags and exceptions as for the entry RTI above; 3 layout forms, each a chart of its own (above).

<a id="w-rtt"></a>
#### RTT

![RTT, opcode 010100, three parcels (6 bytes)](figures/w/rtt/03.svg)

![RTT, opcode 010100, two parcels (4 bytes)](figures/w/rtt/02.svg)

![RTT, opcode 010100, one parcel (2 bytes)](figures/w/rtt/01.svg)

```
RTT
```

| Mnemonic | Opcode | `reg` | `low` |
|---|---|---|---|
| `RTT` | `010100 (0x14)` | `0000 (0x0)` | `0010 (0x2)` |

Operation, flags and exceptions as for the entry RTI above; 3 layout forms, each a chart of its own (above).


<a id="w-ret"></a>
### RET: Return from subroutine

![RET, opcode 010100, three parcels (6 bytes)](figures/w/ret/03.svg)

![RET, opcode 010100, two parcels (4 bytes)](figures/w/ret/02.svg)

![RET, opcode 010100, one parcel (2 bytes)](figures/w/ret/01.svg)

**Mnemonics:** `RET`

**Syntax**

```
RET
```

**Encoding**

![Encoding of RET](figures/r20-sysn-0.svg)

The chart is the layout `r20-sysn-0`, System, no operand, one parcel (`len = 00`): The `reg` field is the class (0); class 0 takes a minor opcode from `low`.

| Mnemonic | Opcode | `reg` | `low` |
|---|---|---|---|
| `RET` | `010100 (0x14)` | `0000 (0x0)` | `0011 (0x3)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sysn-0`](dictionary/by-encoding.md#r20-sysn-0), [`r20-sysn-1`](dictionary/by-encoding.md#r20-sysn-1), [`r20-sysn-2`](dictionary/by-encoding.md#r20-sysn-2).

**Operation**

```
PC ← M[SP] ; SP ← SP + 8
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

Not privileged, though it is in the system escape: it is the two-byte partner of `CALL`.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-halt"></a>
### HALT: Halt the processor

![HALT, opcode 010100, three parcels (6 bytes)](figures/w/halt/03.svg)

![HALT, opcode 010100, two parcels (4 bytes)](figures/w/halt/02.svg)

![HALT, opcode 010100, one parcel (2 bytes)](figures/w/halt/01.svg)

**Mnemonics:** `HALT`

**Syntax**

```
HALT
```

**Encoding**

![Encoding of HALT](figures/r20-sysn-0.svg)

The chart is the layout `r20-sysn-0`, System, no operand, one parcel (`len = 00`): The `reg` field is the class (0); class 0 takes a minor opcode from `low`.

| Mnemonic | Opcode | `reg` | `low` |
|---|---|---|---|
| `HALT` | `010100 (0x14)` | `0000 (0x0)` | `0100 (0x4)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sysn-0`](dictionary/by-encoding.md#r20-sysn-0), [`r20-sysn-1`](dictionary/by-encoding.md#r20-sysn-1), [`r20-sysn-2`](dictionary/by-encoding.md#r20-sysn-2).

**Operation**

```
stop the processor
```

**Flags** None written.

**Exceptions** Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector.

**Cf.** 6.6.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-bpt"></a>
### BPT: Breakpoint

![BPT, opcode 010100, three parcels (6 bytes)](figures/w/bpt/03.svg)

![BPT, opcode 010100, two parcels (4 bytes)](figures/w/bpt/02.svg)

![BPT, opcode 010100, one parcel (2 bytes)](figures/w/bpt/01.svg)

**Mnemonics:** `BPT`

**Syntax**

```
BPT
```

**Encoding**

![Encoding of BPT](figures/r20-sysn-0.svg)

The chart is the layout `r20-sysn-0`, System, no operand, one parcel (`len = 00`): The `reg` field is the class (0); class 0 takes a minor opcode from `low`.

| Mnemonic | Opcode | `reg` | `low` |
|---|---|---|---|
| `BPT` | `010100 (0x14)` | `0000 (0x0)` | `0101 (0x5)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sysn-0`](dictionary/by-encoding.md#r20-sysn-0), [`r20-sysn-1`](dictionary/by-encoding.md#r20-sysn-1), [`r20-sysn-2`](dictionary/by-encoding.md#r20-sysn-2).

**Operation**

```
take the breakpoint vector with EPC = the address of the next instruction
```

**Flags** None written.

**Exceptions** Enters the kernel by the `BPT` vector.

A trap like any other, but kept as its own two-byte instruction because a debugger patches it over an existing instruction, so it must be the shortest instruction the machine has.

**Why it is here.** `BPT` is a trap vector, but a debugger patches it over an existing instruction, so it must be the shortest instruction the machine has; that is why it is kept although `IOT` and `EMT` are not.

**Cf.** 6.2.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-fence"></a>
### FENCE: Memory fence

![FENCE, opcode 010100, three parcels (6 bytes)](figures/w/fence/03.svg)

![FENCE, opcode 010100, two parcels (4 bytes)](figures/w/fence/02.svg)

![FENCE, opcode 010100, one parcel (2 bytes)](figures/w/fence/01.svg)

**Mnemonics:** `FENCE`

**Syntax**

```
FENCE
```

**Encoding**

![Encoding of FENCE](figures/r20-sysn-0.svg)

The chart is the layout `r20-sysn-0`, System, no operand, one parcel (`len = 00`): The `reg` field is the class (0); class 0 takes a minor opcode from `low`.

| Mnemonic | Opcode | `reg` | `low` |
|---|---|---|---|
| `FENCE` | `010100 (0x14)` | `0000 (0x0)` | `0110 (0x6)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sysn-0`](dictionary/by-encoding.md#r20-sysn-0), [`r20-sysn-1`](dictionary/by-encoding.md#r20-sysn-1), [`r20-sysn-2`](dictionary/by-encoding.md#r20-sysn-2).

**Operation**

```
order the memory accesses before it against those after it, for every initiator that observes them
```

**Flags** None written.

**Exceptions** None.

Owed to devices (one `FENCE` separates writing a device's registers from setting its go bit) and to other cores.

**Why it is here.** The memory model is sequentially consistent, so `FENCE` is needed only for what is outside the model: devices and the framebuffer (one `FENCE` between writing a device's registers and setting its go bit, section 3.15) and instruction streams. The `_DB` barrier forms of the atomics exist so that a `FENCE` is not needed in a lock acquire.

**Cf.** 7.2 (the memory model), 2.2 (what the processor owes the bus).

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-wfe"></a>
<a id="w-wait"></a>
### WFE: Wait for an event

![WFE, opcode 010100, three parcels (6 bytes)](figures/w/wfe/03.svg)

![WFE, opcode 010100, two parcels (4 bytes)](figures/w/wfe/02.svg)

![WFE, opcode 010100, one parcel (2 bytes)](figures/w/wfe/01.svg)

**Mnemonics:** `WFE`  (aliases: `WAIT`)

**Syntax**

```
WFE
```

**Encoding**

![Encoding of WFE](figures/r20-sysn-0.svg)

The chart is the layout `r20-sysn-0`, System, no operand, one parcel (`len = 00`): The `reg` field is the class (0); class 0 takes a minor opcode from `low`.

| Mnemonic | Opcode | `reg` | `low` |
|---|---|---|---|
| `WFE` | `010100 (0x14)` | `0000 (0x0)` | `0111 (0x7)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sysn-0`](dictionary/by-encoding.md#r20-sysn-0), [`r20-sysn-1`](dictionary/by-encoding.md#r20-sysn-1), [`r20-sysn-2`](dictionary/by-encoding.md#r20-sysn-2).

**Operation**

```
sleep until an interrupt is pending or another core executes SEV
```

**Flags** None written.

**Exceptions** Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector.

`WAIT` is an assembler alias. Whether `WFE` wakes on a pending but masked interrupt (the idle-loop question) is open.

**Why it is here.** `WAIT` was a PDP-11 instruction (sleep until an interrupt); `WFE` subsumes it: it sleeps until an interrupt or another core's `SEV`, and on a uniprocessor it behaves exactly as `WAIT` did. `WFE` and `SEV` belong to the multiprocessor operations (7.6). The wake rule (whether a pending but masked interrupt wakes it) is open item P1.

**Cf.** 7.6 (waiting and signalling).

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-wait"></a>
**`WAIT`** is an alias of `WFE`: the assembler writes it as that word.


<a id="w-sev"></a>
### SEV: Send an event

![SEV, opcode 010100, three parcels (6 bytes)](figures/w/sev/03.svg)

![SEV, opcode 010100, two parcels (4 bytes)](figures/w/sev/02.svg)

![SEV, opcode 010100, one parcel (2 bytes)](figures/w/sev/01.svg)

**Mnemonics:** `SEV`

**Syntax**

```
SEV
```

**Encoding**

![Encoding of SEV](figures/r20-sysn-0.svg)

The chart is the layout `r20-sysn-0`, System, no operand, one parcel (`len = 00`): The `reg` field is the class (0); class 0 takes a minor opcode from `low`.

| Mnemonic | Opcode | `reg` | `low` |
|---|---|---|---|
| `SEV` | `010100 (0x14)` | `0000 (0x0)` | `1000 (0x8)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sysn-0`](dictionary/by-encoding.md#r20-sysn-0), [`r20-sysn-1`](dictionary/by-encoding.md#r20-sysn-1), [`r20-sysn-2`](dictionary/by-encoding.md#r20-sysn-2).

**Operation**

```
wake every core waiting in WFE
```

**Flags** None written.

**Exceptions** None.

**Why it is here.** The signalling half of `WFE`, so that a core waiting for a lock can sleep instead of spinning and be woken by the core that releases it.

**Cf.** 7.6.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


### TLBA: Invalidate all translations; wait for translation invalidations; invalidate the whole instruction cache

**Mnemonics:** `TLBIA`, `TLBSYNC`, `ICINVA`

**Syntax**

```
TLBIA
TLBSYNC
ICINVA
```

**Encoding**

![Encoding of TLBA](figures/r20-sysn-0.svg)

The chart is the layout `r20-sysn-0`, System, no operand, one parcel (`len = 00`): The `reg` field is the class (0); class 0 takes a minor opcode from `low`.

| Mnemonic | Opcode | `reg` | `low` |
|---|---|---|---|
| `TLBIA` | `010100 (0x14)` | `0000 (0x0)` | `1010 (0xA)` |
| `TLBSYNC` | `010100 (0x14)` | `0000 (0x0)` | `1011 (0xB)` |
| `ICINVA` | `010100 (0x14)` | `0000 (0x0)` | `1100 (0xC)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sysn-0`](dictionary/by-encoding.md#r20-sysn-0), [`r20-sysn-1`](dictionary/by-encoding.md#r20-sysn-1), [`r20-sysn-2`](dictionary/by-encoding.md#r20-sysn-2).

**Operation**

```
TLBIA   : invalidate every translation-buffer entry on this core and, by broadcast, on the others
TLBSYNC : wait until the invalidations this core started have completed on every core
ICINVA  : invalidate the whole instruction cache
```

**Flags** None written.

**Exceptions** Privileged (`TLBIA`, `TLBSYNC`); the reference executor treats `ICINVA` as a no-op.

**Why it is here.** `TLBI` and `TLBIA` broadcast, `TLBSYNC` waits for the other cores, and `ICINV` and `ICINVA` invalidate the instruction cache: a Lisp runtime that compiles a function cannot work without an instruction-cache invalidate.

**Cf.** 7.5 (translation and instruction-cache coherence).

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-tlbia"></a>
#### TLBIA

![TLBIA, opcode 010100, three parcels (6 bytes)](figures/w/tlbia/03.svg)

![TLBIA, opcode 010100, two parcels (4 bytes)](figures/w/tlbia/02.svg)

![TLBIA, opcode 010100, one parcel (2 bytes)](figures/w/tlbia/01.svg)

```
TLBIA
```

| Mnemonic | Opcode | `reg` | `low` |
|---|---|---|---|
| `TLBIA` | `010100 (0x14)` | `0000 (0x0)` | `1010 (0xA)` |

Operation, flags and exceptions as for the entry TLBA above; 3 layout forms, each a chart of its own (above).

<a id="w-tlbsync"></a>
#### TLBSYNC

![TLBSYNC, opcode 010100, three parcels (6 bytes)](figures/w/tlbsync/03.svg)

![TLBSYNC, opcode 010100, two parcels (4 bytes)](figures/w/tlbsync/02.svg)

![TLBSYNC, opcode 010100, one parcel (2 bytes)](figures/w/tlbsync/01.svg)

```
TLBSYNC
```

| Mnemonic | Opcode | `reg` | `low` |
|---|---|---|---|
| `TLBSYNC` | `010100 (0x14)` | `0000 (0x0)` | `1011 (0xB)` |

Operation, flags and exceptions as for the entry TLBA above; 3 layout forms, each a chart of its own (above).

<a id="w-icinva"></a>
#### ICINVA

![ICINVA, opcode 010100, three parcels (6 bytes)](figures/w/icinva/03.svg)

![ICINVA, opcode 010100, two parcels (4 bytes)](figures/w/icinva/02.svg)

![ICINVA, opcode 010100, one parcel (2 bytes)](figures/w/icinva/01.svg)

```
ICINVA
```

| Mnemonic | Opcode | `reg` | `low` |
|---|---|---|---|
| `ICINVA` | `010100 (0x14)` | `0000 (0x0)` | `1100 (0xC)` |

Operation, flags and exceptions as for the entry TLBA above; 3 layout forms, each a chart of its own (above).


### PUSHX: Push and pop the exception state

**Mnemonics:** `PUSHX`, `POPX`

**Syntax**

```
PUSHX
POPX
```

**Encoding**

![Encoding of PUSHX](figures/r20-sysx-0.svg)

The chart is the layout `r20-sysx-0`, System, SYSX, one parcel (`len = 00`): Class 0, minor 15: the sub-opcode is in parcel 1.

| Mnemonic | Opcode | `reg` | `low` | Sub-opcode |
|---|---|---|---|---|
| `PUSHX` | `010100 (0x14)` | `0000 (0x0)` | `1111 (0xF)` | `00000000 (0x00)` |
| `POPX` | `010100 (0x14)` | `0000 (0x0)` | `1111 (0xF)` | `00000001 (0x01)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sysx-0`](dictionary/by-encoding.md#r20-sysx-0), [`r20-sysx-1`](dictionary/by-encoding.md#r20-sysx-1).

**Operation**

```
PUSHX: SP ← SP - 16 ; M[SP] ← EPSW ; M[SP + 8] ← EPC
POPX : EPSW ← M[SP] ; EPC ← M[SP + 8] ; SP ← SP + 16
```

**Flags** None written.

**Exceptions** Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector. `SP` must be 8-byte aligned (a misaligned-access abort); both words are checked before either is touched.

Four bytes (the `SYSX` escape, sub-opcodes 0 and 1) and two bytes on page 2. For a handler that wants to be interrupted: it can save the exception state and lower the priority.

**Why it is here.** A handler that can be interrupted must save `EPC` and `EPSW` before it lowers the priority; with only `MFSR` that costs two moves and two stores (sixteen bytes) on every such kernel entry, and the same to restore. The instructions may not show up high in the instruction count, but they save bytes and cycles in a tight, very often used kernel loop. Page 2 has the two-byte forms.

**Cf.** 6.2, 6.7.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-pushx"></a>
#### PUSHX

![PUSHX, opcode 010100, two parcels, sub-opcode 00000000 (4 bytes)](figures/w/pushx/02.svg)

![PUSHX, opcode 010100, one parcel, sub-opcode 00000000 (2 bytes)](figures/w/pushx/01.svg)

```
PUSHX
```

| Mnemonic | Opcode | `reg` | `low` | Sub-opcode |
|---|---|---|---|---|
| `PUSHX` | `010100 (0x14)` | `0000 (0x0)` | `1111 (0xF)` | `00000000 (0x00)` |

Operation, flags and exceptions as for the entry PUSHX above; 2 layout forms, each a chart of its own (above).

<a id="w-popx"></a>
#### POPX

![POPX, opcode 010100, two parcels, sub-opcode 00000001 (4 bytes)](figures/w/popx/02.svg)

![POPX, opcode 010100, one parcel, sub-opcode 00000001 (2 bytes)](figures/w/popx/01.svg)

```
POPX
```

| Mnemonic | Opcode | `reg` | `low` | Sub-opcode |
|---|---|---|---|---|
| `POPX` | `010100 (0x14)` | `0000 (0x0)` | `1111 (0xF)` | `00000001 (0x01)` |

Operation, flags and exceptions as for the entry PUSHX above; 2 layout forms, each a chart of its own (above).


<a id="w-isync"></a>
### ISYNC: Instruction synchronisation

![ISYNC, opcode 010100, two parcels, sub-opcode 00000010 (4 bytes)](figures/w/isync/02.svg)

![ISYNC, opcode 010100, one parcel, sub-opcode 00000010 (2 bytes)](figures/w/isync/01.svg)

**Mnemonics:** `ISYNC`

**Syntax**

```
ISYNC
```

**Encoding**

![Encoding of ISYNC](figures/r20-sysx-0.svg)

The chart is the layout `r20-sysx-0`, System, SYSX, one parcel (`len = 00`): Class 0, minor 15: the sub-opcode is in parcel 1.

| Mnemonic | Opcode | `reg` | `low` | Sub-opcode |
|---|---|---|---|---|
| `ISYNC` | `010100 (0x14)` | `0000 (0x0)` | `1111 (0xF)` | `00000010 (0x02)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sysx-0`](dictionary/by-encoding.md#r20-sysx-0), [`r20-sysx-1`](dictionary/by-encoding.md#r20-sysx-1).

**Operation**

```
make earlier writes to PTBR, ASID, MMUCTL and VBR, and earlier ICINVs, take effect for the instructions that follow
```

**Flags** None written.

**Exceptions** Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector. A non-zero pad byte is an illegal instruction.

The architecture promises the effect only after the next `ISYNC`; an in-order implementation may make it immediate, and software must not rely on that.

**Why it is here.** Taken from the out-of-order readiness review: it makes earlier writes to `PTBR`, `ASID`, `MMUCTL` and `VBR` take effect for what follows, so an in-order machine may make them immediate and a speculative one has a place to serialise. It serves the aim that the architecture is efficient on both in-order and out-of-order cores (1.4.4).

**Cf.** 7.5, 6.3.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-hint"></a>
### HINT: Hint

![HINT, opcode 010100, two parcels, sub-opcode 00000011 (4 bytes)](figures/w/hint/02.svg)

![HINT, opcode 010100, one parcel, sub-opcode 00000011 (2 bytes)](figures/w/hint/01.svg)

**Mnemonics:** `HINT`

**Syntax**

```
HINT #n        ; n = 0 to 255
```

**Encoding**

![Encoding of HINT](figures/r20-sysx-0.svg)

The chart is the layout `r20-sysx-0`, System, SYSX, one parcel (`len = 00`): Class 0, minor 15: the sub-opcode is in parcel 1.

| Mnemonic | Opcode | `reg` | `low` | Sub-opcode |
|---|---|---|---|---|
| `HINT` | `010100 (0x14)` | `0000 (0x0)` | `1111 (0xF)` | `00000011 (0x03)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sysx-0`](dictionary/by-encoding.md#r20-sysx-0), [`r20-sysx-1`](dictionary/by-encoding.md#r20-sysx-1).

**Operation**

```
no architectural effect
```

**Flags** None written.

**Exceptions** None.

Defined codes: 0 a plain no-op hint, 1 pause (spin-wait), 2 speculation barrier. Every other code is a reserved hint that executes as a no-op; software shall not use it. Not privileged.

**Why it is here.** Defined with `ISYNC`: a no-op with a byte of code, defined for `0` (plain), `1` (pause, for spin-wait loops) and `2` (speculation barrier), every other code a reserved hint that executes as a no-op so that a later machine can give it a meaning without breaking an old binary.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


### MFSR: Move from and to a system register

**Mnemonics:** `MFSR`, `MTSR`

**Syntax**

```
MFSR Rd, name
MTSR name, Rs
```

**Encoding**

![Encoding of MFSR](figures/r20-sysreg-0.svg)

The chart is the layout `r20-sysreg-0`, System registers (MFSR, MTSR), one parcel (`len = 00`): Class 0: the system register number is in parcel 1.

| Mnemonic | Opcode | `reg` | `low` |
|---|---|---|---|
| `MFSR` | `010100 (0x14)` | `0000 (0x0)` | `1101 (0xD)` |
| `MTSR` | `010100 (0x14)` | `0000 (0x0)` | `1110 (0xE)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sysreg-0`](dictionary/by-encoding.md#r20-sysreg-0), [`r20-sysreg-1`](dictionary/by-encoding.md#r20-sysreg-1).

**Operation**

```
MFSR: Rd ← system register `name`
MTSR: system register `name` ← Rs         ; read-only registers are an illegal instruction
```

**Flags** None written.

**Exceptions** Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector. An unassigned system register is an illegal instruction.

The register is chosen by name (a number in parcel 1); the instruction is four bytes. A write to `PTBR`, `ASID` or `MMUCTL` flushes the translation buffer.

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

**Cf.** 6.3 (system registers).

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-mfsr"></a>
#### MFSR

![MFSR, opcode 010100, two parcels (4 bytes)](figures/w/mfsr/02.svg)

![MFSR, opcode 010100, one parcel (2 bytes)](figures/w/mfsr/01.svg)

```
MFSR Rd, name
```

| Mnemonic | Opcode | `reg` | `low` |
|---|---|---|---|
| `MFSR` | `010100 (0x14)` | `0000 (0x0)` | `1101 (0xD)` |

Operation, flags and exceptions as for the entry MFSR above; 2 layout forms, each a chart of its own (above).

<a id="w-mtsr"></a>
#### MTSR

![MTSR, opcode 010100, two parcels (4 bytes)](figures/w/mtsr/02.svg)

![MTSR, opcode 010100, one parcel (2 bytes)](figures/w/mtsr/01.svg)

```
MTSR name, Rs
```

| Mnemonic | Opcode | `reg` | `low` |
|---|---|---|---|
| `MTSR` | `010100 (0x14)` | `0000 (0x0)` | `1110 (0xE)` |

Operation, flags and exceptions as for the entry MFSR above; 2 layout forms, each a chart of its own (above).


### MTPS: Move to and from the processor status word

**Mnemonics:** `MTPS`, `MFPS`

**Syntax**

```
MTPS Rs
MFPS Rd
```

**Encoding**

![Encoding of MTPS](figures/r20-sys-0.svg)

The chart is the layout `r20-sys-0`, System, one parcel (`len = 00`): The `reg` field is the class; the other classes take a register or a 4-bit immediate from `low`.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `MTPS` | `010100 (0x14)` | `0001 (0x1)` |
| `MFPS` | `010100 (0x14)` | `0010 (0x2)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sys-0`](dictionary/by-encoding.md#r20-sys-0), [`r20-sys-1`](dictionary/by-encoding.md#r20-sys-1), [`r20-sys-2`](dictionary/by-encoding.md#r20-sys-2).

**Operation**

```
MTPS: PSW ← Rs          ; in user mode only the flags N Z V C are written
MFPS: Rd ← PSW
```

**Flags** `MTPS` writes the flags from `Rs`; `MFPS` writes none.

**Exceptions** A `MTPS` value with the reserved mode 2 in a mode field aborts.

**Cf.** 6.1 (modes and the status word).

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-mtps"></a>
#### MTPS

![MTPS, opcode 010100, three parcels (6 bytes)](figures/w/mtps/03.svg)

![MTPS, opcode 010100, two parcels (4 bytes)](figures/w/mtps/02.svg)

![MTPS, opcode 010100, one parcel (2 bytes)](figures/w/mtps/01.svg)

```
MTPS Rs
```

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `MTPS` | `010100 (0x14)` | `0001 (0x1)` |

Operation, flags and exceptions as for the entry MTPS above; 3 layout forms, each a chart of its own (above).

<a id="w-mfps"></a>
#### MFPS

![MFPS, opcode 010100, three parcels (6 bytes)](figures/w/mfps/03.svg)

![MFPS, opcode 010100, two parcels (4 bytes)](figures/w/mfps/02.svg)

![MFPS, opcode 010100, one parcel (2 bytes)](figures/w/mfps/01.svg)

```
MFPS Rd
```

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `MFPS` | `010100 (0x14)` | `0010 (0x2)` |

Operation, flags and exceptions as for the entry MTPS above; 3 layout forms, each a chart of its own (above).


<a id="w-spl"></a>
### SPL: Set the interrupt priority level

![SPL, opcode 010100, three parcels (6 bytes)](figures/w/spl/03.svg)

![SPL, opcode 010100, two parcels (4 bytes)](figures/w/spl/02.svg)

![SPL, opcode 010100, one parcel (2 bytes)](figures/w/spl/01.svg)

**Mnemonics:** `SPL`

**Syntax**

```
SPL #n        ; n = 0 to 7
```

**Encoding**

![Encoding of SPL](figures/r20-sys-0.svg)

The chart is the layout `r20-sys-0`, System, one parcel (`len = 00`): The `reg` field is the class; the other classes take a register or a 4-bit immediate from `low`.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `SPL` | `010100 (0x14)` | `0011 (0x3)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sys-0`](dictionary/by-encoding.md#r20-sys-0), [`r20-sys-1`](dictionary/by-encoding.md#r20-sys-1), [`r20-sys-2`](dictionary/by-encoding.md#r20-sys-2).

**Operation**

```
PSW.priority ← n
```

**Flags** None written. The condition flags are untouched.

**Exceptions** Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector. A priority above 7 is an illegal instruction.

Kept despite `MTPS` writing the whole word because it sets the priority alone: a kernel raising priority around a critical section must not clobber the flags.

**Why it is here.** `SPL` stays although `MTPS` writes the whole status word: it sets the priority alone, leaving the condition codes untouched, so a kernel raising priority around a critical section does not clobber flags. It is the PDP-11 instruction of the same name.

**Cf.** 6.2.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


### TRAP: System call and trap

**Mnemonics:** `TRAP`, `TRAPL`

**Syntax**

```
TRAP #n        ; n = 0 to 15, two bytes
TRAPL #n       ; n = 0 to 255, four bytes
```

**Encoding**

![Encoding of TRAP](figures/r20-sys-0.svg)

The chart is the layout `r20-sys-0`, System, one parcel (`len = 00`): The `reg` field is the class; the other classes take a register or a 4-bit immediate from `low`.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `TRAP` | `010100 (0x14)` | `0100 (0x4)` |
| `TRAPL` | `010100 (0x14)` | `1111 (0xF)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sys-0`](dictionary/by-encoding.md#r20-sys-0), [`r20-sys-1`](dictionary/by-encoding.md#r20-sys-1), [`r20-sys-2`](dictionary/by-encoding.md#r20-sys-2), [`r20-sys-1-3`](dictionary/by-encoding.md#r20-sys-1-3).

**Operation**

```
enter the kernel by vector (TRAP_BASE + n), with EPC = the address of the next instruction
```

**Flags** None written.

**Exceptions** Enters the kernel; not privileged.

The replacement for the PDP-11 `IOT` and `EMT`. `TRAPL` reaches the vectors 0 to 255 with `n` in the high byte of parcel 1.

**Why it is here.** `TRAPL` exists so that the vector range of 256 and the two-byte common case can both be kept: `TRAP #n` for `n` below 16 is two bytes and the long form reaches 256. `IOT` and `EMT`, which were `TRAP` at two particular vectors on the PDP-11, are not provided.

**Cf.** 6.2, 6.5 (system calls).

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-trap"></a>
#### TRAP

![TRAP, opcode 010100, three parcels (6 bytes)](figures/w/trap/03.svg)

![TRAP, opcode 010100, two parcels (4 bytes)](figures/w/trap/02.svg)

![TRAP, opcode 010100, one parcel (2 bytes)](figures/w/trap/01.svg)

```
TRAP #n
```

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `TRAP` | `010100 (0x14)` | `0100 (0x4)` |

Operation, flags and exceptions as for the entry TRAP above; 3 layout forms, each a chart of its own (above).

<a id="w-trapl"></a>
#### TRAPL

![TRAPL, opcode 010100, three parcels (6 bytes)](figures/w/trapl/03.svg)

![TRAPL, opcode 010100, two parcels (4 bytes)](figures/w/trapl/02.svg)

![TRAPL, opcode 010100, one parcel (2 bytes)](figures/w/trapl/01.svg)

```
TRAPL #n
```

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `TRAPL` | `010100 (0x14)` | `1111 (0xF)` |

Operation, flags and exceptions as for the entry TRAP above; 3 layout forms, each a chart of its own (above).


<a id="w-tlbi"></a>
### TLBI: Invalidate a translation

![TLBI, opcode 010100, three parcels (6 bytes)](figures/w/tlbi/03.svg)

![TLBI, opcode 010100, two parcels (4 bytes)](figures/w/tlbi/02.svg)

![TLBI, opcode 010100, one parcel (2 bytes)](figures/w/tlbi/01.svg)

**Mnemonics:** `TLBI`

**Syntax**

```
TLBI Rs
```

**Encoding**

![Encoding of TLBI](figures/r20-sys-0.svg)

The chart is the layout `r20-sys-0`, System, one parcel (`len = 00`): The `reg` field is the class; the other classes take a register or a 4-bit immediate from `low`.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `TLBI` | `010100 (0x14)` | `0101 (0x5)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sys-0`](dictionary/by-encoding.md#r20-sys-0), [`r20-sys-1`](dictionary/by-encoding.md#r20-sys-1), [`r20-sys-2`](dictionary/by-encoding.md#r20-sys-2).

**Operation**

```
invalidate the translation-buffer entry for the page containing the address in Rs, on this core and by broadcast on the others
```

**Flags** None written.

**Exceptions** Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector.

**Why it is here.** It broadcasts: a translation changed by one core must be invalidated on all of them, and `TLBSYNC` waits for it.

**Cf.** 7.5, 6.4.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


### MTASID: Move to and from the address-space identifier

**Mnemonics:** `MTASID`, `MFASID`

**Syntax**

```
MTASID Rs
MFASID Rd
```

**Encoding**

![Encoding of MTASID](figures/r20-sys-0.svg)

The chart is the layout `r20-sys-0`, System, one parcel (`len = 00`): The `reg` field is the class; the other classes take a register or a 4-bit immediate from `low`.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `MTASID` | `010100 (0x14)` | `0110 (0x6)` |
| `MFASID` | `010100 (0x14)` | `0111 (0x7)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sys-0`](dictionary/by-encoding.md#r20-sys-0), [`r20-sys-1`](dictionary/by-encoding.md#r20-sys-1), [`r20-sys-2`](dictionary/by-encoding.md#r20-sys-2).

**Operation**

```
MTASID: ASID ← Rs[15:0]          ; the translation buffer is flushed in the reference executor
MFASID: Rd ← ASID
```

**Flags** None written.

**Exceptions** Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector.

The `ASID` tags translation-buffer entries so a context switch is one store.

**Why it is here.** The `ASID` tags translation-buffer entries so a context switch is one store and no flush. No further reason is recorded.

**Cf.** 6.4.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-mtasid"></a>
#### MTASID

![MTASID, opcode 010100, three parcels (6 bytes)](figures/w/mtasid/03.svg)

![MTASID, opcode 010100, two parcels (4 bytes)](figures/w/mtasid/02.svg)

![MTASID, opcode 010100, one parcel (2 bytes)](figures/w/mtasid/01.svg)

```
MTASID Rs
```

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `MTASID` | `010100 (0x14)` | `0110 (0x6)` |

Operation, flags and exceptions as for the entry MTASID above; 3 layout forms, each a chart of its own (above).

<a id="w-mfasid"></a>
#### MFASID

![MFASID, opcode 010100, three parcels (6 bytes)](figures/w/mfasid/03.svg)

![MFASID, opcode 010100, two parcels (4 bytes)](figures/w/mfasid/02.svg)

![MFASID, opcode 010100, one parcel (2 bytes)](figures/w/mfasid/01.svg)

```
MFASID Rd
```

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `MFASID` | `010100 (0x14)` | `0111 (0x7)` |

Operation, flags and exceptions as for the entry MTASID above; 3 layout forms, each a chart of its own (above).


### MTDP: Move to and from the direct pointer

**Mnemonics:** `MTDP`, `MFDP`

**Syntax**

```
MTDP Rs
MFDP Rd
```

**Encoding**

![Encoding of MTDP](figures/r20-sys-0.svg)

The chart is the layout `r20-sys-0`, System, one parcel (`len = 00`): The `reg` field is the class; the other classes take a register or a 4-bit immediate from `low`.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `MTDP` | `010100 (0x14)` | `1000 (0x8)` |
| `MFDP` | `010100 (0x14)` | `1001 (0x9)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sys-0`](dictionary/by-encoding.md#r20-sys-0), [`r20-sys-1`](dictionary/by-encoding.md#r20-sys-1), [`r20-sys-2`](dictionary/by-encoding.md#r20-sys-2).

**Operation**

```
MTDP: DP ← Rs
MFDP: Rd ← DP
```

**Flags** None written.

**Exceptions** None.

`DP` is the thread pointer in user mode and the per-CPU pointer in kernel mode; there is one copy per mode.

**Why it is here.** `DP` descends from the 6502's zero page and is kept for code density (a 12-bit displacement in four bytes); it is also the thread pointer in user mode and, in kernel mode, the per-CPU pointer that an SMP kernel wants (7.4). `MTDP` and `MFDP` read and write the current mode's copy.

**Cf.** 7.4 (per-CPU state).

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-mtdp"></a>
#### MTDP

![MTDP, opcode 010100, three parcels (6 bytes)](figures/w/mtdp/03.svg)

![MTDP, opcode 010100, two parcels (4 bytes)](figures/w/mtdp/02.svg)

![MTDP, opcode 010100, one parcel (2 bytes)](figures/w/mtdp/01.svg)

```
MTDP Rs
```

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `MTDP` | `010100 (0x14)` | `1000 (0x8)` |

Operation, flags and exceptions as for the entry MTDP above; 3 layout forms, each a chart of its own (above).

<a id="w-mfdp"></a>
#### MFDP

![MFDP, opcode 010100, three parcels (6 bytes)](figures/w/mfdp/03.svg)

![MFDP, opcode 010100, two parcels (4 bytes)](figures/w/mfdp/02.svg)

![MFDP, opcode 010100, one parcel (2 bytes)](figures/w/mfdp/01.svg)

```
MFDP Rd
```

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `MFDP` | `010100 (0x14)` | `1001 (0x9)` |

Operation, flags and exceptions as for the entry MTDP above; 3 layout forms, each a chart of its own (above).


<a id="w-mtdmw"></a>
### MTDMW: Move to a direct-mapping window

![MTDMW, opcode 010100, three parcels (6 bytes)](figures/w/mtdmw/03.svg)

![MTDMW, opcode 010100, two parcels (4 bytes)](figures/w/mtdmw/02.svg)

![MTDMW, opcode 010100, one parcel (2 bytes)](figures/w/mtdmw/01.svg)

**Mnemonics:** `MTDMW`

**Syntax**

```
MTDMW Rs
```

**Encoding**

![Encoding of MTDMW](figures/r20-sys-0.svg)

The chart is the layout `r20-sys-0`, System, one parcel (`len = 00`): The `reg` field is the class; the other classes take a register or a 4-bit immediate from `low`.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `MTDMW` | `010100 (0x14)` | `1010 (0xA)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sys-0`](dictionary/by-encoding.md#r20-sys-0), [`r20-sys-1`](dictionary/by-encoding.md#r20-sys-1), [`r20-sys-2`](dictionary/by-encoding.md#r20-sys-2).

**Operation**

```
DMW0 ← Rs          ; storage only: the operand names no window and the format of the windows is unspecified
```

**Flags** None written.

**Exceptions** Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector.

The direct-mapping windows have no defined format.

**Why it is here.** Taken from LoongArch's direct-mapping windows, which stop the kernel taking translation-buffer misses on its own text. The windows are deferred: the instruction is storage only.

**Cf.** 6.4.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-mfcpuid"></a>
### MFCPUID: Read the processor identifier

![MFCPUID, opcode 010100, three parcels (6 bytes)](figures/w/mfcpuid/03.svg)

![MFCPUID, opcode 010100, two parcels (4 bytes)](figures/w/mfcpuid/02.svg)

![MFCPUID, opcode 010100, one parcel (2 bytes)](figures/w/mfcpuid/01.svg)

**Mnemonics:** `MFCPUID`

**Syntax**

```
MFCPUID Rd
```

**Encoding**

![Encoding of MFCPUID](figures/r20-sys-0.svg)

The chart is the layout `r20-sys-0`, System, one parcel (`len = 00`): The `reg` field is the class; the other classes take a register or a 4-bit immediate from `low`.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `MFCPUID` | `010100 (0x14)` | `1011 (0xB)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sys-0`](dictionary/by-encoding.md#r20-sys-0), [`r20-sys-1`](dictionary/by-encoding.md#r20-sys-1), [`r20-sys-2`](dictionary/by-encoding.md#r20-sys-2).

**Operation**

```
Rd ← CPUID
```

**Flags** None written.

**Exceptions** None.

The index of this core, for per-CPU data.

**Why it is here.** Part of the multiprocessor operations, because per-CPU data needs each core to know which one it is.

**Cf.** 7.4, 7.8.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


<a id="w-icinv"></a>
### ICINV: Invalidate the instruction cache for an address

![ICINV, opcode 010100, three parcels (6 bytes)](figures/w/icinv/03.svg)

![ICINV, opcode 010100, two parcels (4 bytes)](figures/w/icinv/02.svg)

![ICINV, opcode 010100, one parcel (2 bytes)](figures/w/icinv/01.svg)

**Mnemonics:** `ICINV`

**Syntax**

```
ICINV Rs
```

**Encoding**

![Encoding of ICINV](figures/r20-sys-0.svg)

The chart is the layout `r20-sys-0`, System, one parcel (`len = 00`): The `reg` field is the class; the other classes take a register or a 4-bit immediate from `low`.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `ICINV` | `010100 (0x14)` | `1100 (0xC)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sys-0`](dictionary/by-encoding.md#r20-sys-0), [`r20-sys-1`](dictionary/by-encoding.md#r20-sys-1), [`r20-sys-2`](dictionary/by-encoding.md#r20-sys-2).

**Operation**

```
invalidate the instruction-cache line containing the address in Rs
```

**Flags** None written.

**Exceptions** The reference executor treats it as a no-op; privilege as for the other cache-maintenance instructions.

**Why it is here.** Instruction-cache invalidation, by address (`ICINV`) and whole (`ICINVA`). The reason is the one given for `TLBA`: a runtime that compiles a function cannot work without it.

**Cf.** 7.5.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).


### PROBE: Probe an address for read or write access

**Mnemonics:** `PROBER`, `PROBEW`

**Syntax**

```
PROBER Rd, Rs
PROBEW Rd, Rs
```

**Encoding**

![Encoding of PROBE](figures/r20-sys-0.svg)

The chart is the layout `r20-sys-0`, System, one parcel (`len = 00`): The `reg` field is the class; the other classes take a register or a 4-bit immediate from `low`.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `PROBER` | `010100 (0x14)` | `1101 (0xD)` |
| `PROBEW` | `010100 (0x14)` | `1110 (0xE)` |

**All the layouts of this entry** (a chart for each, with its fields and the sub-opcode of each mnemonic, in [the bit layouts of every opcode](dictionary/by-encoding.md)): [`r20-sys-0`](dictionary/by-encoding.md#r20-sys-0), [`r20-sys-1-2`](dictionary/by-encoding.md#r20-sys-1-2), [`r20-sys-2`](dictionary/by-encoding.md#r20-sys-2).

**Operation**

```
Rd ← 1 if the address in Rs is readable (PROBER) or writable (PROBEW) in the previous mode, else 0
no fault is taken
```

**Flags** None written.

**Exceptions** Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector.

Taken from the VAX `PROBER` and `PROBEW`: the kernel validates a user address before using it.

**Why it is here.** Taken from the VAX `PROBER` and `PROBEW`: the kernel validates a user address before using it, and it replaces the `nofault` global of the V7 kernel for the address-validation case.

**Cf.** 6.5 (the user-memory guard), 6.4.

**Status** implemented in the reference executor (`common/pdp64exec.c`, shared by `sim64` and QEMU).

<a id="w-prober"></a>
#### PROBER

![PROBER, opcode 010100, three parcels (6 bytes)](figures/w/prober/03.svg)

![PROBER, opcode 010100, two parcels (4 bytes)](figures/w/prober/02.svg)

![PROBER, opcode 010100, one parcel (2 bytes)](figures/w/prober/01.svg)

```
PROBER Rd, Rs
```

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `PROBER` | `010100 (0x14)` | `1101 (0xD)` |

Operation, flags and exceptions as for the entry PROBE above; 3 layout forms, each a chart of its own (above).

<a id="w-probew"></a>
#### PROBEW

![PROBEW, opcode 010100, three parcels (6 bytes)](figures/w/probew/03.svg)

![PROBEW, opcode 010100, two parcels (4 bytes)](figures/w/probew/02.svg)

![PROBEW, opcode 010100, one parcel (2 bytes)](figures/w/probew/01.svg)

```
PROBEW Rd, Rs
```

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `PROBEW` | `010100 (0x14)` | `1110 (0xE)` |

Operation, flags and exceptions as for the entry PROBE above; 3 layout forms, each a chart of its own (above).
<!-- /entries:9.14 -->

## 9.15 Faults, restart and memory management

*Cf. chapter 6, section 6.8 (faults, restart and memory management) and section 6.4 (memory management).*

**9.15.1** A fault is a trap, an abort, a progress stop in a block operation or a machine check, and every instruction either completes or is annulled and restarted with no state to undo (`MCPY` and its kin keep their progress in registers); the page-table format, the memory types and the translation registers are in the kernel chapter. *(D)*

*Commentary.* The instruction-set consequence is the restart rule: the register update of an auto-increment mode is held until the instruction retires. **Impact.** *Kernel:* see 6.8. *Compiler:* no scheduling restriction arises from faults. *Hardware:* a single-entry undo buffer and a read-only walker.

## 9.16 Position-independent code

**9.16.1** Position-independent code costs nothing extra on this machine: every access to code or data in the same module is PC-relative by an ordinary addressing mode, so there is no GOT register and no prologue to set one up. *(D)*

**9.16.2** A call to an imported function is `CALLI got_slot(PC)` and a PLT stub is the single instruction `JMPI got_slot(PC)`; an imported variable's address is one `MOVQ got_slot(PC), Rd`. *(D)*

**9.16.3** A position-independent access to a global is no longer than an absolute one: four bytes within 32 KB and six within 2 GB, against six for a 32-bit absolute address. *(D)*

**9.16.4** The thread pointer is `DP`, so the local-exec thread-local model is one four-byte `MOVQ tls_offset(DP), Rd`. *(D)*

**9.16.5** A branch at the middle length reaches 4 GB, so no linker veneers are needed for any binary smaller than that; the assembler's and the linker's branch relaxation both reduce to choosing a length. *(D)*

**9.16.6** `R12` is the linker's scratch register. The ABI (appendix D) decides that imports are called without a PLT stub; lazy against eager binding is open. *(D for `R12` and no stub; open for binding)*

*Commentary.* **Precedent.** On i386 a position-independent executable reserved `%ebx` (one of eight registers) for the GOT base and set it in every prologue, which cost a few percent of size and speed; x86-64 fixed that with RIP-relative addressing, and AArch64 needs linker veneers because its branches reach only 128 MB. **Trade-offs.** The two-byte PC-relative form is the shortest, so position-independent data access is slightly smaller than absolute access; the price is a GOT load per imported call site where a PLT stub would cost a load per function. **Improvements.** Position-independence is a side effect of three decisions made for other reasons: PC-relative as an ordinary mode (adopted because the PC left the register file), variable-length encoding (for density) and `DP` (a 6502 zero-page descendant kept for density), which is exactly the thread pointer. **Benefits.** OpenBSD builds everything position-independent by default, and here that costs nothing. **Modern comparables.** x86-64 RIP-relative addressing; AArch64 `ADRP` with a GOT load and veneers for far calls. **Impact.** *Kernel:* a loader applies only relocations for data pointers, and write-xor-execute and randomisation come with no code penalty. *Compiler:* `-fPIE` is the default and emits the same instructions as `-fno-pic` for local data; no reserved register, no per-function setup. *Hardware:* nothing; the PC-relative mode is in the address adder already.

## 9.17 What was rejected

**9.17.1** The architecture refuses, by design, every feature that adds hidden state, an unbounded instruction, a second operand path or a mode bit that changes what other instructions mean. *(D)*

**9.17.2** From the PDP-11 and VAX it refuses general memory-to-memory operands, deferred addressing as a general form (only `JMPI` and `CALLI` are deferred), unbounded instructions with hidden microstate (`MOVC5`, `EDITPC`), packed decimal, hardware call frames (`CALLS`, `CALLG`), the PC as a general register, multiple floating-point formats, `POLY`, the `IOT`, `EMT`, `WAIT` and `RESET` instructions, a distinct low-half unsigned multiply, and the PDP-11's compare operand order. *(D)*

**9.17.3** From x86 it refuses partial-register writes that preserve upper bits, operand-size and `REX` prefixes, segmentation, flag writes that vary by instruction, implicit registers for multiply, divide and shift count, the x87 stack, transcendental instructions and byte-granular instruction fetch. *(D)*

**9.17.4** From the RISC family it refuses a register hardwired to zero (a sixteenth of a 16-register file), fused compare-and-branch in place of flags, branch delay slots, register windows and software-refilled translation buffers. *(D)*

**9.17.5** It also refuses features of its own invention: NUL-terminated string instructions (`MSCN` with an explicit maximum gives a bounded `strlen`), `CRC32` words (carry-less multiply is the primitive under every CRC), reciprocal-estimate instructions, NaN payload propagation, a 32-bit profile, an eight-byte instruction alignment, `MOVT` and `MOVK` partial-immediate inserts, hardware tag checking, store-with-write-barrier, a self-synchronising encoding, and a scalar instruction for sub-1-bit inference (the accelerator of chapter 8 does it). *(D)*

*Commentary.* **Precedent.** The VAX's `EDITPC` is a bytecode interpreter in microcode, and DEC needed a separate control chip for the PDP-11's commercial instruction set and shipped none; the VAX's hardware call frames ran slower than the equivalent sequence on later models; ARM32's `PC+8` and MIPS's delay slot expose one implementation's pipeline forever. **Trade-offs.** Each refusal gives up a real convenience: the lost `MOV (R1)+,(R2)+` copy loop, the byte-wide `ADDB`, the inline-argument `JSR`. Section 9.18 says what replaces each. **Improvements.** The common pattern is that a refused feature was either subsumed by a more general one (`MCPY` for the copy loop) or paid its cost in every implementation for a few users (`EDITPC`). **Benefits.** An instruction set a small in-order core can implement completely and a compiler can target without exceptions. **Modern comparables.** RISC-V and AArch64 also refuse memory-to-memory operands and delay slots; AArch64 keeps flags where RISC-V refuses them. **Impact.** *Kernel:* no instruction has a restart state except the three that keep their progress in architectural registers, so a fault is always restartable. *Compiler:* no special cases: every operand rule is uniform, one memory operand and the rest registers. *Hardware:* no microcode engine, no second operand path, no hidden-state latch, no alignment rotator in the fetch path.

## 9.18 Idioms: restored, lost and replaced

**9.18.1** Several idioms that the PDP-11 and VAX had and later RISC designs dropped are restored: subtract-one-and-branch (`SOB`, here in both directions), probe an address without faulting (`PROBER`, `PROBEW`), bit-field extract and insert, find-first-set (`CTZ`, `CLZ`), byte swap, block move, fill, compare and scan with their progress held in registers, the register-save mask (`PUSHM`, `POPM`, the useful half of `CALLS`), and carry-less multiply. *(D)*

**9.18.2** The VAX's counted-string instructions are largely present: `MOVC3` is `MCPY`, `CMPC3` is `MCMP`, `LOCC` is `MSCN`, `SKPC` is `MSCNN`, and `MOVC5` is `MCPY` plus `MSET`. Table-translated move, table scans and substring search are absent because a per-byte table lookup stops a block operation from streaming. *(D)*

**9.18.3** Deliberately lost, with their replacements: memory-to-memory `MOV` (replaced by `MCPY`); autoincrement-deferred and the dispatch-table idiom (replaced by `JTAG` for tag dispatch and a scaled-index `JMP` for the rest); `JSR Rn` and `RTS Rn` with inline arguments and cheap coroutines (replaced by `CALL` and `RET` with the return address on the stack where every unwinder and debugger expects it); the VAX `CASE` and `INDEX` instructions (replaced by a compare, branch and scaled `JMP`); byte and word ALU operations (`MOVZB`, the operation, `MOVB`: three instructions where the PDP-11 had one); and the flag set and clear instructions. *(D)*

**9.18.4** Subsumed, so not losses: `SXT` (the conversion moves), `SWAB` (`BSWAP`), `MARK` (the convention it served is gone), `ASH` and `ASHC` (the shifts take a register count), `MFPI` and `MTPI` (`PROBER` with the previous-mode bits and the user-memory guard), `MULU` (identical to `MUL` in the low half), and `ROL` (an assembler alias for `ROR`). *(D)*

**9.18.5** Measurements decide what is included: the compiler uses `SET cc, rd` (about 0.4% of code), not integer `ABS`, `MIN` or `MAX` (under 0.1%), not the bit-field instructions (0.03%) and not the auto-increment modes (0.1%); the second opcode page is about 7% of the instructions emitted. *(D)*

*Commentary.* **Precedent.** The PDP-11's `JSR Rn` put the return address in a register of the caller's choosing, which made coroutines a pair of `JSR`s and inline arguments free; the VAX replaced it with `CALLS` and a frame, which was slower than the code it replaced. **Trade-offs.** The most frequently felt loss in hand-written code is the byte-wide read-modify-write; the compiler never notices it. A bounds-checked `INDEX` for Pascal and Ada is a possible addition. **Improvements.** `SOB` branches either way, with four reaches; the block operations keep their progress in registers, which is what the VAX got wrong, so a fault restarts for free. **Benefits.** The code a compiler emits is the code the table above measures, and the extras are for the people who write assembler. **Modern comparables.** x86 keeps `LOOP` and the string instructions with `REP`; AArch64 has bit-field moves and no memory-to-memory forms; RISC-V has none of them in the base. **Impact.** *Kernel:* `PROBER` and `PROBEW` replace the `nofault` global in the user-copy routines. *Compiler:* idioms the compiler never emits are not built for it, so the compiler's instruction selection stays small. *Hardware:* each restored idiom is a few hundred gates of existing datapath, and each lost one is a decode that never existed.

## 9.19 Side by side: the PDP-11, the VAX and the pdp64

**9.19.1** The word is 64 bits against the PDP-11's 16 and the VAX's 32, the registers are 16 as on the VAX, the virtual address is 39, 48 or 57 bits with 40 physical in the present implementation, and the instruction count is 58 assigned opcodes plus 45 on the second page, against the VAX's 304. *(D)*

**9.19.2** The program counter is not a register, there is no argument pointer, and the frame pointer and the linker scratch are ordinary software conventions. *(D)*

**9.19.3** An instruction has one or two operands (three for the block operations) and at most one memory operand, against the PDP-11's two and the VAX's six. *(D)*

**9.19.4** The condition codes are the same four, `N`, `Z`, `V` and `C`; floating point is in the base and in the general registers, with three IEEE formats (half, single, double) and no mode bits that change the meaning of other instructions, where the PDP-11 had `FPS.FD`, `FL` and `FT` and the VAX had rounding bits in the status word. *(D)*

**9.19.5** An instruction is two, four or six bytes (one to three parcels of 16 bits) with a one-parcel second page, against the PDP-11's two to six and the VAX's one to more than fifty. *(D)*

*Commentary.* **Precedent.** The PDP-11 and VAX instruction formats, with their encodings drawn side by side, are in the instruction-set text, section 13. **Trade-offs.** The pdp64 keeps what made the PDP-11 pleasant, orthogonal addressing and a small register set, and what made the VAX powerful, flags, a register-save mask and string operations, and drops what made both expensive: memory-to-memory operands and unbounded instructions. **Improvements.** The compiler's code averages about 3.3 bytes an instruction, measured on the fair corpus before the second page. **Benefits.** A processor that is smaller than either predecessor while running 64-bit code. **Modern comparables.** The closest family is AArch64 in the number of registers and addressing modes and RISC-V compressed in density; neither has flags and a variable length together. **Impact.** *Kernel:* the exception model is the PDP-11's with the VAX's per-mode stacks. *Compiler:* one memory operand makes instruction selection a register-allocation problem, as on a RISC. *Hardware:* a decoder that reads two bits to find the length, and no microcode.

## 9.20 What was taken from LoongArch, and what was not

**9.20.1** LoongArch64 is the most recent clean-room instruction set designed without an ideological commitment: it borrowed from MIPS, RISC-V and ARM as each had the better answer, which is the posture of the pdp64.

**9.20.2** Adopted from it: bit manipulation in the base (`CLO`, `CLZ`, `CTZ`, bit-field moves, byte reverse), atomics with the barrier folded in (the `_DB` variants), a richer atomic set (fetch-and-minimum and maximum), and memory type as a page attribute. *(D)*

**9.20.3** Declined, with reasons: `R0` hardwired to zero (a sixteenth of a 16-register file, and `CLR` and `NEG` are one parcel already); no condition codes (a third read port in the branch unit against a four-bit latch); `FCSR` rounding-mode bits (hidden state that changes other instructions); four PC-relative address-formation instructions (one `LEA` carries 32 bits); 32 registers (this encoding has no bit to spare for the field); and separate vector register files (chapter 8). *(D)*

**9.20.4** Under consideration: separate floating-point condition flags, software-visible translation-buffer manipulation (to pin an entry for a real-time kernel), and a conditional select for constant-time code. *(P)*

*Commentary.* **Precedent.** LoongArch has a fixed 32-bit encoding with room for two register fields and a displacement, so it can afford compare-and-branch and needs four instructions to form an address; this machine's variable length reverses both trade-offs. **Trade-offs.** The direct-mapping windows LoongArch uses to avoid translation-buffer misses on kernel text are deferred: `DMW0` and `DMW1` are stored without effect (6.3). **Improvements.** The same idea is right or wrong depending on the encoding around it, and each adoption is judged against this encoding. **Benefits.** Borrowing the tested parts saves design time and avoids their bugs. **Modern comparables.** LoongArch itself; the RISC-V bit-manipulation extensions (Zbb, Zbs) do much of the same. **Impact.** *Kernel:* atomics with barriers make a lock acquire one instruction. *Compiler:* bit operations in the base mean the compiler can use them without a feature test. *Hardware:* each adopted idea is a few hundred lookup tables and each declined one is a block not built.

## 9.21 What is still open in the instruction set

**9.21.1** Open, with the reasoning in appendix B or in the instruction-set text, section 12: the thin 6-bit displacement of the shortest scaled-index form; the landing-pad decision (optional first, mandatory later); atomics against the bus (the lock against the monitor; the monitor is chosen); worst-case instruction latency for the block operations (an interrupt-latency claim must state the block granularity); the floating-point condition flags (the signed branches do not treat unordered cleanly); the block operations and the cache (a streaming memory type or a non-temporal variant); directed rounding for arithmetic (a rounding field in the instruction); the leftovers of half precision (minimum, maximum, rounding, bfloat16); conditional select; lazy against eager binding in the ABI; the verification of the memory model against published litmus tests; and the coherence protocol beyond four cores (the design supports at least four and prefers sixteen or more, errata 92; the leanings are in `docs/smp-decisions.md`). *(P and open)*

**9.21.2** Settled: the reserved-opcode discipline (a top-level opcode is for an operation whose common case is register to register), the fourth parcel (absent; the code `11` is a second page of 64 one-parcel opcodes), UTF-8 scope (`MVAL` is committed), and the measured length distribution (2, 4, 6 and 8 bytes at 46.5, 42.8, 10.6 and 0.1 percent, before the second page). *(D)*

*Commentary.* **Trade-offs.** None of the open items blocks the first implementation; the three that must be settled before silicon, the memory model verification, the coherence choice and the worst-case latency figure, are verification tasks, not design changes. **Impact.** *Kernel:* the open items touching the kernel are the user-memory guard, the floating-point state and the block-operation granularity. *Compiler:* conditional select and directed rounding would change instruction selection. *Hardware:* the coherence protocol must be chosen before the cache is built, not after.
