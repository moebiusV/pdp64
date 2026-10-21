# pdp64: everything decided or changed since ISA revision 20 arrived

On 2026-10-21 a tar, `pdp64-docs-2026-10-21.tar`, appeared in `~/claude/pcc`: three documents about a 64-bit PDP-11 (`11-64W-isa-r20.md`, the
FPGA plan, the LB64 accelerator note) and a README. Revision 20 of the ISA was a paper design, "nothing here has been synthesized, measured or taped
out". We were asked for a pcc back end, an assembler (in the spirit of V7 `as`), a linker if needed, and a plan for a QEMU target. This file records
**every decision, correction, clarification and dropped or changed instruction made since**, and why. Nothing in `docs/11-64W/` was edited; where
this file and those documents disagree, this file is the later word.

The machine's name is **pdp64**. The documents call it 11/64W; the user corrected this ("the name isn't 11/64W it is pdp64").

Contents

1. [Where things stand](#1-where-things-stand)
2. [Design errors found in ISA r20](#2-design-errors-found-in-isa-r20)
3. [Instructions dropped, moved, added or changed](#3-instructions-dropped-moved-added-or-changed)
4. [Things the ISA left unspecified, now specified](#4-things-the-isa-left-unspecified-now-specified)
5. [The ABI](#5-the-abi)
6. [The assembly language](#6-the-assembly-language)
7. [The object format and the assembler's model](#7-the-object-format-and-the-assemblers-model)
8. [Why a grammar is the source, and how it is arranged](#8-why-a-grammar-is-the-source-and-how-it-is-arranged)
9. [Errors in our own work, found and fixed](#9-errors-in-our-own-work-found-and-fixed)
10. [Changes to hbnf (upstream) and workarounds](#10-changes-to-hbnf-upstream-and-workarounds)
11. [Environment decisions](#11-environment-decisions)
12. [What is still open or unwritten](#12-what-is-still-open-or-unwritten)
13. [Appendix: the operation inventory, the files, the history](#13-appendix)

---

## 1. Where things stand

| | |
|---|---|
| Opcode map | 64 top-level slots: **55 assigned**, the spare ALU slot `0x23`, **8 reserved** `0x28`-`0x2F`. (ISA §4.16 says 56 assigned; see §2.) |
| Mnemonic words | **203**, of which 5 are assembler aliases (`bhis`, `blo`, `mulu`, `wait`, `rol`): 198 instructions. |
| Operations, folded | **93** (91 before the flags operation and the CRC pair were added; the unsigned conversions and `FRINTDA` are qualifiers and add none). "add" is one operation whether it adds integers or floats, in memory or in a register; width, precision, barrier, direction, extension, immediate form, indirect form, signedness, high/low half and branch condition are qualifiers (§13.1). |
| Assembled today | 167 words (the whole integer core, bit/divide/block escapes, `FESC`, SYS). Not yet: `ATOM` (22), `MESC` (8), `TRAPL` (1). `tools/check-drift.py` lists them by name. |
| Written | the grammars, the generator, `as64` (assembler), tests, this documentation. |
| Not written | `sim64` (emulator), `ld64` (linker), the pcc back end, QEMU. |
| Checks | `tools/check-all.sh`: 11 instruction-format vectors, 34 syntax cases, 6 assembled programs compared word for word with hand-worked expectations, and a drift test over every mnemonic plus the opcode-map checks. All pass. |

The repository is `~/claude/pdp64` (git, `main`). The commit history is listed in §13.3.

---

## 2. Design errors found in ISA r20

Writing the encoding down as something a machine could check turned up the following. Each entry: what the document says, what is wrong, what we do.
`errata.md` has the same list in the order it was found; the numbers in parentheses refer to it.

### 2.1 Outright errors

* **Stale opcode bits in three diagrams (errata 1).** §4.6 (BESC), §4.7 (MBLK) and §4.8 (TAGOP) draw parcel 0 with opcode bits `000011` (BESC, MBLK) and
  `001110` (TAGOP), left over from an earlier numbering. The map in §4.16 (and every other section) says `0x0C`, `0x0D`, `0x15` = `001100`, `001101`,
  `010101`. **We follow §4.16.**
* **The opcode count is wrong (errata 2).** §4.16 says "fifty-six of sixty-four assigned, eight reserved", plus "one spare ALU slot". The map it prints
  has 12 moves/LEA + 6 escapes + 4 (XFER, SOP, SYS, TAGOP) + 13 ALU + 4 FP + 16 branches = **55** assigned; with the spare ALU slot `0x23` and the
  eight reserved at `0x28`-`0x2F` that is 55 + 1 + 8 = 64. The document's 56 + 8 + 1 = 65 cannot be. The checker asserts 55 / 1 / 8.
* **`PUSHM` and `POPM` cannot be encoded where the document puts them (errata 4).** §4.7 places them in `MBLK` and says "parcel 1 is a 16-bit mask". But
  every `MBLK` instruction carries an 8-bit sub-opcode in parcel 1, so a 16-bit mask leaves no room for the sub-opcode at `len=01`; and §4.14's second
  rule forbids deciding the parcel-0 interpretation per sub-opcode. We moved them (§3).
* **`SYS` cannot be built three contradictory ways at once (errata 5).** §4.11 says `reg` and `rm` combine into eight bits of sub-opcode; §4.3.1 says
  `SYS` takes its sub-opcode from the `reg` field alone (that is why `SYS` sits with `XFER` and `SOP` at `0x12`-`0x14`); and §4.11.1 insists `TRAP #n`
  is a two-byte instruction with 256 vectors, which needs an 8-bit operand in a two-byte instruction that has only 8 bits left in total. We chose a
  class/minor split (§4.4).
* **`JTAG Rn, table` has nowhere to put `Rn` (errata 6).** `XFER`'s `reg` field is the sub-opcode, `rm`/mode give the table address, and nothing is
  left for the tagged register. We restricted `JTAG` to the scaled-index mode and made the index register the tagged register (§3.3).
* **`SOB Rn, dst` does not fit its own branch encoding at `len=00` (errata 8).** §4.4 gives conditional branches an 8-bit displacement in bits 7..0 at
  `len=00`, but `SOB` needs `Rn` in the `reg` field, which is the top of those bits. §3.1.1 does list `SOB` among the two-parcel forms, so the document
  agrees with itself only if `SOB` never exists at `len=00`; we made that explicit.

### 2.2 Things the document needs and never states

* **The PC base for PC-relative operands and branches (errata 3).** §9.3 argues at length that "reading the PC" forces an architectural commitment about
  *which* PC and that `LEA 0(PC),Rn` avoids it because "mode 0010's displacement is defined relative to a stated point". That point is never stated.
  Decision in §4.1.
* **Scaled index at `len > 1` (errata 7).** §5 gives mode `0001` only at `len=01`: `rm4 rx4 s2 d6`. §12 item 1 itself calls the 6-bit displacement
  "thin". What happens to the extra bits at `len=10`, `len=11` is not given. Decision in §4.2.
* **Numbers for the sub-opcodes (errata 9).** The document names the sub-operations of `BESC`, `MBLK`, `AESC`, `MESC`, `FESC`, `ATOM` and `SYS` and
  numbers none of them. Without numbers there is no encoding. Decision in §4.5.
* **Byte order.** The ISA never says whether pdp64 is little- or big-endian. Decision: **little-endian**, and instruction parcels are little-endian
  16-bit units in memory (§4.6).
* **Operand roles for the register-escape forms.** Which of `reg`, `rm`, `t`, `x` is destination, which source, for `BESC`/`AESC`/`MBLK`. Decision in §4.4.

### 2.3 Real problems the document knew about and left open

* **FP compare and the integer flags (§12 item 7, errata 14).** `FCMPD` writes the integer `PSW` flags, which has no clean way to say "unordered". We
  fixed one concrete behaviour (`N` = a<b, `Z` = a==b, `V` = unordered, `C` = 0) and noted that the signed branches do not treat unordered cleanly
  (`BLT` after an unordered compare takes `N xor V` = 1). This is **still open**.
* **Predecrement syntax collides with negative displacements (errata 15).** §5 writes mode `0111` as `-d(Rn)`, which is exactly how a negative base
  displacement is written. Decision in §6.

---

## 3. Instructions dropped, moved, added or changed

### 3.1 Dropped

| What | Where it was | Why |
|---|---|---|
| **`FRECPED`, `FRSQRTED`** (reciprocal and reciprocal-square-root *estimates*) | `FESC`, ISA §4.10 | The machine has `FDIVD`, `FSQRTD` and the fused multiply-add family, so a software Newton loop buys speed only if the hardware divide is slow, which this design does not chase. Each estimate needs a lookup table in hardware **and** an exact specification (ARM and RISC-V fix the algorithm and table; the ISA says only "not correctly rounded", so two implementations would return different bits for the same program). No document names a user, and §1.2 rule 3 says not to multiply entities without benefit. Sub-opcodes `0x40`, `0x41` of `FESC` are free again. (errata 16) |
| **`.org`, `.section` directives** | assembler | Never implemented; dropped at the user's direction ("drop those unimplemented things"). |
| **`IOT`, `EMT` aliases** | ISA §4.15 | The instructions were already gone in r17 (they are `TRAP #n`); only the assembler aliases remained, and they were unimplemented. Dropped at the user's direction. |
| V7 `as` warts: octal-by-default numbers, `<string>`, `'\e`, `\/ \< \>` and `[ ]` in expressions, `.if`, `.stabs`, 8-character symbols | assembler | "We don't need to copy asv7 warts or anachronisms." (§6) |

### 3.2 Moved

| What | From | To | Why |
|---|---|---|---|
| **`PUSHM #mask`, `POPM #mask`** | `MBLK` (ISA §4.7) | `SOP` slots `0xA` and `0xB` (`reg` = 10, 11), the mask a 16-bit immediate (mode `0100`) | A 16-bit mask plus a sub-opcode does not fit `MBLK`'s parcel 1 (§2.1). `SOP` had exactly two free slots, the mask-as-immediate form needs no new mechanism, and the instruction stays four bytes. **Cost: `SOP` now has no free slots left.** Mask bit *n* is `Rn`; `PUSHM` stores the lowest-numbered register at the highest address. |

### 3.3 Changed semantics (the document is silent or ambiguous; we fixed one meaning)

* **`CMP` computes `reg - rm` and is written `CMP Rd, rm` (errata 13).** PDP-11 `CMP a,b` computes `a-b`. Here the destination of an ALU operation must
  be a register, so a literal `src,dst` reading would force every comparison of a register against an immediate or memory operand to reverse its branch
  condition, and every compiler would pay for it. The encoding computes `reg - rm`; the assembler writes the register first. `CMP a,b` followed by
  `BLT` still reads "branch if a < b", as on the PDP-11; only which side must be a register differs. `BIT` is symmetric and unchanged.
* **Flags, stated (errata 14).** `SUB` and `CMP` set `C` on a *borrow* (the PDP-11 sense), so `BHIS`/`BCC` mean "no borrow", unsigned `>=`. `ADD` sets
  `C` on a carry out. `V` is signed overflow. (Shifts and rotates were already specified in §4.2.1.)
* **`JTAG` is legal only in the scaled-index mode (errata 6).** `JTAG d(Rb)(Rx*s)`: the scale is ignored; `PC <- [Rb + d + 8*(Rx & 7)]`; `Rx` is the
  tagged register. Rationale: the mode that already carries a base *and* an index register is the only one with a free register slot for the tagged
  value.
* **`SOB` exists from `len=01` (errata 8).** Displacement 16/32/48 bits, counted in parcels, signed (so it branches either way, as the document says).
* **`TRAP` is split (errata 5).** `TRAP #n` for `n < 16` is two bytes (`SYS` class 4, `n` in the `rm` nibble); `TRAP #n` for 16 <= `n` < 256 is the new
  four-byte `TRAPL` (class 15, `n` in the high byte of parcel 1). The assembler picks. This keeps §4.11.1's goal (256 vectors) and §3.1.1's goal (the
  common case in two bytes) at the cost of a second mnemonic.
* **`RORI` is its own mnemonic (errata 10).** The document has `ROR` taking "a register or immediate count". Register-count `ROR rs, rt, rd` and
  immediate-count `RORI rs, #n, rd` are different encodings (the count sits in the low byte of parcel 1, 6 bits used), so they get different sub-opcodes
  and mnemonics. `ROL rs, #n, rd` assembles to `RORI` with `64-n` (ISA §4.15), and `ROL` with a register count is rejected.
* **`PROBER`/`PROBEW rd, rs`** carry the second register in parcel 1 (`rd:4 pad:12`), at `len=01`.
* **`MESC` (errata 11).** Parcel 1 is `sub:4 rm:4 disp:8` at `len=01` (ISA §4.13), widening to 24 / 40 bits at greater lengths; the scaled-index mode
  is not available in `MESC` (no room for `rx`/`s`).
* **`ALU` slot `0x23` (spare).** The grammar treats the whole run `ADD` ... `FCMPD` as the memory-operand class, so a reserved opcode `0x23` *decodes*
  like an ALU instruction. Execution must trap it; decoding it cleanly is harmless and removes a special case.

### 3.4 Added

| What | Why |
|---|---|
| `TRAPL` (SYS class 15) | see above |
| `RORI` (BESC `0x11`) | see above |
| `FSFLAGS` (FESC `0x40`) | **floating-point exception flags**, the one thing missing for IEEE 754 conformance (errata 17); a sticky FPSR written and read by one swap operation |
| `FCVTDQU`, `FCVTQUD` (FESC `0x3E`, `0x3F`) | unsigned 64-bit to and from double (errata 18) |
| `FRINTDA` (FESC `0x34`) | round half away from zero, for `round()` (errata 19) |
| `CRC32{B,W,L,Q}`, `CRC32C{B,W,L,Q}` (BESC `0x34`-`0x3B`) | the user asked for them; reverses ISA 4.6.3 (errata 20) |

### 3.5 Aliases

The five aliases (`bhis`, `blo`, `mulu`, `wait`, `rol`) are implemented, as **words of the group they stand for, numbered above the group's own
encodings** (branch group `bhis`=64, `blo`=65; ALU `mulu`=64; no-operand SYS `wait`=16; BESC `rol`=256). A number above the encoding range cannot be
confused with an opcode, and the grammar stays one source. **Not implemented:** `BIC #imm, rm` → `AND #~imm, rm` (listed in ISA §4.15).

---

## 4. Things the ISA left unspecified, now specified

### 4.1 PC-relative addressing and branches (errata 3)

* **Base:** the address of the **first parcel of the instruction itself**, for `d(PC)` operands, `LEA d(PC),Rn`, `CALL d(PC)` and all branches.
* **Unit:** a PC-relative *operand* displacement is in **bytes**; a **branch** displacement is in **2-byte parcels** (the reach table in §4.4 requires
  this: 8 bits give +-256 bytes only if counted in parcels).
* **Why the start of the instruction, not the end:** the displacement then does not depend on the length chosen for the instruction itself. An assembler
  that picks `len` from the displacement would otherwise have the displacement depend on `len` and iterate; with this rule every instruction only ever
  grows, so relaxation is monotone and terminates. `LEA 0(PC),Rn` yields the address of the `LEA`.

### 4.2 Addressing-mode payloads (errata 7)

| Mode | `len=01` | `len=10` | `len=11` | Notes |
|---|---|---|---|---|
| 0 base `d(Rn)`; 6 post-increment; 7 pre-decrement | `rm4 d12` | d28 | d44 | as ISA §3.3 |
| 1 scaled index | `rm4 rx4 s2 d6` | d22 | d38 | each extra parcel adds 16 displacement bits (the document gave only the first column) |
| 2 PC-relative, 4 immediate, 5 absolute | d16 | d32 | d48 | the `rm` nibble is reclaimed (ISA §3.3) |
| 3 direct page `d(DP)` | `pad4 d12` | d28 | d44 | the 4 bits parcel 1 does not use are padding, zero |

Immediates are sign-extended; displacement fields are two's complement truncated to the field width. These widths are not written anywhere in our code:
`as64` **measures** them by asking the generated encoder how many bits it will accept (§8).

### 4.3 Which field is which (register-escape forms)

For `BESC`, `AESC`, `MBLK` the assembler writes the destination **last**: `op rs, rd`, `op ra, rb, rd`. In the encoding: parcel 0 `reg` = `rd`, `low` =
the first source; parcel 1 `t` = the second source. `MBLK` is the exception: `mcpy rd, rs, rn` is *destination pointer, source pointer, count*, with
`reg` = destination pointer, `low` = source pointer, `t` = count (`mval rd, rn` has `low` unused). `DSHR ra, rb, #n, rd`: `low`=`ra`, `t`=`rb`, shift
count in `pos` of parcel 2 (so it needs `len` 2). `EXTB`/`EXTZB`/`INSB rs, #pos, #width, rd`: `pos`, `width` in parcel 2.
`TAGOP`: `reg` is the tested register; `low` = sense (1 bit, `BTAG`=0, `BNTAG`=1) in the high bit and the tag (3 bits) below it.

### 4.4 The `SYS` group (errata 5)

`reg` is a 4-bit **class**; `rm` (`low`) is a register operand, a 4-bit immediate, or, in class 0, the minor opcode.

| Class (`reg`) | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| | no operand (minor in `rm`) | `mtps` | `mfps` | `spl #n` | `trap #n` | `tlbi` | `mtasid` | `mfasid` | `mtdp` | `mfdp` | `mtdmw` | `mfcpuid` | `icinv` | `prober` | `probew` | `trapl #n` |

Class 0 minors: 0 `nop`, 1 `rti`, 2 `rtt`, 3 `ret`, 4 `halt`, 5 `bpt`, 6 `fence`, 7 `wfe`, 8 `sev`, 9 `lpad`, 10 `tlbia`, 11 `tlbsync`, 12 `icinva`.
Two-byte forms where the operand is a register or a 4-bit number; the classes that need a second operand (`prober`, `probew`, `trapl`) are four bytes.

### 4.5 Sub-opcode numbering (errata 9)

Assigned so related operations share a range; the table is `spec/pdp64-mnemonics.hbnf`, the only place the numbers are written.

* `BESC`: counts `0x00`-`0x08` (clz, ctz, clo, cto, popcnt, bswap, bswapw, bswapl, bitrev); rotate `0x10` (`ror`), `0x11` (`rori`); field and funnel `0x20`
  (`dshr`), `0x21`-`0x23` (`extb`, `extzb`, `insb`); polynomial/popcount `0x30`-`0x32` (`xnorpop`, `clmull`, `clmulh`); UTF-8 `0x40`-`0x42`.
* `AESC`: `div` 0, `divu` 1, `mod` 2, `modu` 3, `mulhu` 4. `MBLK`: `mcpy` ... `mval` 0-6. `MESC`: `movub`, `movuw`, `movul`, `movuq` are the loads 0, 2, 4, 6 (the store form is the load number + 1, as for the moves;
  not assembled yet), `addm`, `subm`, `bicm`, `bism` 8-11. `FESC`: by kind (divide/sqrt, `binary32` forms, FMA, sign/select, classify, round, convert). `ATOM`: plain then
  barrier-fused (`_db`) pairs, then `ll`/`sc`.
* Top level: the moves are `0x00`-`0x0B` with the store form always **load + 1**; branches `0x30`-`0x3E` and `SOB` `0x3F`; ALU `0x16`-`0x22`, FP `0x24`-`0x27`.

### 4.6 Byte and bit order

* **Little-endian** data (the ISA never said). Instruction **parcels are 16-bit little-endian units in memory**.
* The grammars read bits **most significant first** (hbnf's convention, the order of the packet diagrams in the ISA), so the decoder works on parcels that
  have been byte-swapped into big-endian order, and the assembler swaps them back when it writes. A parcel's bit 15 is the first bit of its record.

### 4.7 Instruction lengths

* An instruction is `len` + 1 parcels (2, 4, 6 or 8 bytes); the assembler picks the *smallest* `len` for which every field fits, per the rules above.
* Minimum lengths: `LEA` and `XFER` (`JMPI`, `CALLI`, `JTAG`) 4 bytes (they need a memory operand); `SOB`, `BTAG`/`BNTAG` 4 bytes; `PUSHM`/`POPM` 4 bytes;
  all `BESC`/`AESC`/`MBLK` forms 4 bytes; `DSHR`, `EXTB`, `EXTZB`, `INSB` 6 bytes (ISA §4.14: they need parcel 2).

### 4.8 Structural facts the grammar now states and checks

* The six parcel-1 escapes are contiguous `0x0C`-`0x11`; `XFER`, `SOP`, `SYS` adjacent `0x12`-`0x14` (ISA §4.3.1); the sixteen branch slots are `0x30`-`0x3F`;
  checked by `tools/check-drift.py` from the grammar's own numbers.

---

## 5. The ABI

The ISA (§19.5) leaves the ABI open; a compiler cannot emit a call without one. **Version 1, accepted by the user** (`docs/abi.md`):

| Decision | Choice | Alternatives considered | Why |
|---|---|---|---|
| Data model | **LP64**: `int` 32, `long` and pointers 64, `short` 16, `char` 8 (signed), `long long` 64 | ILP64 (`int` 64); LLP64 | The ISA's own sub-quad loads (`MOVL`, `MOVW`) and the world's 32-bit file formats assume `int` is 32 bits; ILP64 breaks code that typedefs 32-bit types to `int`. Signed `char` matches PDP-11/x86 tradition; `MOVZB` exists for unsigned. |
| `long double` | same as `double` | software binary128 | there is no hardware for more |
| Argument registers | **R0-R5** | 4 (PDP-11 style), 8 (AArch64) | only 13 registers are usable (R12 linker scratch, R13 frame pointer, R14 stack pointer); 8 leaves too few callee-saved, 4 spills too often |
| Floating point | in general registers, exactly like integers (the ISA's design); `binary32` in the low 32 bits, sign-extended | (none: the ISA decided) | one homogeneous save area makes varargs simpler than x86-64 |
| Results | `R0`; `R0:R1` for a 128-bit pair or struct <= 16 bytes; larger structs through a hidden pointer in `R0` | | same shape as x86-64 |
| Struct arguments | <= 16 bytes in registers; larger by value on the stack | AArch64's invisible reference | pcc already does this for amd64, and `MCPY` makes the copy cheap |
| Callee-saved | R8-R11, R15 (and R13 as optional frame pointer); caller-saved R0-R7, R12 | | `PUSHM`/`POPM` take any mask in one instruction |
| Stack alignment | **8 bytes** | 16 | **quad data accesses must be naturally aligned (ISA §7.4: a misaligned quad access aborts), and the 2-byte parcel alignment is for instructions only**; nothing is wider than a quad. |
| Red zone | none (v1) | 128 bytes | would save a stack adjustment in leaf functions; measure first |
| Symbols | no leading underscore | V7's `_` | modern ELF |
| Landing pads | off in v1; `.lpad` provided | mandatory | ISA §12 item 3 undecided |
| Varargs | callee spills R0-R5 into a save area below the stack arguments | | |
| PIC | globals via `d(PC)`; imports via `MOVQ got(PC),Rd`; calls via `CALLI got(PC)`; TLS local-exec `MOVQ off(DP),Rd` | | the ISA's own §19 |

The only point the user questioned was the stack alignment ("why not 2 bytes instead of 8?"): the answer is the quad-alignment rule above.

---

## 6. The assembly language

Documented in `docs/asm-syntax.md`; grammar `spec/pdp64-asm.hbnf`. The design instruction was: *use the V7 assembler's layout, but don't copy its warts, and
make numbers, characters and strings C's.* The decisions, in the order the user gave them:

* **Statements and comments.** One statement per line. `;` starts a comment (the ISA document's own examples use `;`). V7's `/` comment and `;`
  statement separator are gone because **`/` is division** (user: "/ is div, not a comment").
* **Numbers** are C's: decimal by default (`010` is ten; the user: "numbers default to decimal, the 0x 0b 0o notation is for when we want it"), `0x`, `0b`, `0o`.
  V7's octal-by-default was a wart.
* **Characters and strings** are C's: `'a'`, `'\n'`, `"text\n"`, escapes `\n \t \r \a \b \f \v \0 \\ \' \" \xHH \ooo`, plus `\uXXXX` and `\UXXXXXXXX`
  (written as UTF-8). V7's `<string>` is gone ("<> is not a string").
* **Names and labels follow ELF**, which has no restrictions on symbol names beyond NUL. A bareword is letters, digits, `_`, `.`, `$` and any non-ASCII code
  point, **a name may start with a digit as long as the whole bareword is not a number** (`3dfx:` is a label; `3`, `0x3d`, `0b101`, `0o17` are numbers;
  `1f`/`1b` are local-label references). A bareword of digits only is a numeric local label. Anything else goes in double quotes (`"odd name!"`).
  The user: "the bareword with : terminal fully qualifies it." A mnemonic or register name cannot be a label. Names are never truncated (V7 kept 7-8 characters).
* **UTF-8 clean.** The source must be valid UTF-8 and the generated parser refuses anything else (a stray byte, a truncated sequence, an overlong form, a
  surrogate), in names, strings, characters and comments alike. A NUL byte is refused too. In a string, UTF-8 text is copied as bytes; `'é'` is the code
  point 0xE9 (as is `'é'`).
* **Operators** are C's (`* / % & << >>`, `+ - | ^`, unary `- ~ !`, parentheses). `*`, `/`, `%`, `&` and the shifts need constants; `+`/`-` accept one
  relocatable symbol; the difference of two symbols of one section is a constant.
* **Directives:** `.text .data .bss .globl .comm .byte .word .long .quad .ascii .even .align .space .lpad` (`.word` is 16 bits, `.long` 32, `.quad` 64:
  the ISA's PDP-11 terminology). `.align n` aligns to n bytes (a power of two). Text padding is a one-parcel `nop`.
* **Mnemonics are lowercase.** (An `hbnf` limitation: numbered enum values are refused under case-insensitive matching.)
* **Registers** are `r0`-`r15`; `sp` = `r14`, `fp` = `r13`; `pc` and `dp` appear only as a base register. `r` followed only by digits is reserved: `r16` is an error, not a name.
* **Operand modes** (ISA §5): `rN`; `#expr`; `@expr`; `expr(rN)`, `(rN)`; `expr(rN)(rX*s)`; `expr(pc)`; `expr(dp)`; `(rN)+`, `(rN)+d`; `-(rN)`, `(rN)-d`;
  a bare expression is a PC-relative reference.
* **Pre-decrement is `-(rN)` / `(rN)-d` (errata 15).** The ISA's `-d(Rn)` is also a negative base displacement; here `-d(rN)` is *always* base+displacement.
* **Destination last**, except `cmp` (register first; §3.3).
* **Not taken from V7:** octal-by-default numbers, `<string>`, `'\e`, `\/ \< \>` and `[ ]` in expressions, `.if`, `.stabs`, truncated symbols.
* **Register-indirect without displacement** `(r1)` is a base-register operand, not a parenthesised expression (a grammar bug we had; §9).

---

## 7. The object format and the assembler's model

`as64` writes **ELF64 relocatable** objects (the user: "an ELF linker is ok"; no existing linker has a back end for this ISA, so `ld64` will be a small
purpose-built ELF linker).

* **Machine number:** `e_machine = 0xF064`, a private-use value; nobody has assigned pdp64 one.
* **Sections:** `.text`, `.data`, `.bss`, `.symtab`, `.strtab`, `.rela.text`, `.rela.data`, `.shstrtab`. Records come from the generated grammar (`elf.hbnf`).
* **Symbols:** locals first, then globals; numeric local labels never appear in the symbol table (a relocation against one becomes section symbol + offset).
* **Relocation types** (`as64/relocs.h`), five, because the width of an instruction field is derivable from the instruction itself: `D64` and `D32` (data),
  and three **instruction** relocations that patch the last `16*len` bits of the instruction whose first parcel is at `r_offset` (the field width comes from
  the `len` bits of that parcel, and the linker may not change it):
  `INSN_ABS` (`S + A`, immediate/absolute operand), `INSN_PC` (`S + A - P`, bytes), `INSN_BR` (`(S + A - P) / 2`, parcels).
* **The code model** (a decision, not in the ISA): a reference to a symbol *in the same section* is resolved by the assembler, whatever distance; a
  **branch or `d(PC)` to another section or an undefined symbol is a 32-bit field with a relocation** (reach +-2 GB, "small code model"); an **immediate or
  absolute operand naming a symbol is the full 48-bit field** (always correct for the 39-bit canonical space, 8 bytes). The ISA's §19.2 point that
  PC-relative data access is *shorter* than absolute (4-6 bytes vs 8) therefore shows up directly in the assembler's output.
* **Relaxation:** every instruction starts at its minimum length and only grows; the passes repeat until nothing changes. Forward references to labels
  defined later are not mistaken for externals (all labels are known before the first pass).
* **Errors** are reported once, in the final pass (the earlier passes only measure).

---

## 8. Why a grammar is the source, and how it is arranged

The user's instruction, repeated three times: *the whole point of using an hbnf grammar is a single source of truth, so things don't drift*; and *one change to
the grammar and nothing drifts downstream.* The design that follows:

| Fact | Written in exactly one place | Consumed by |
|---|---|---|
| every opcode, sub-opcode, group opcode, addressing-mode number, store opcode, alias, **register number** (`r0`..`r15`, `sp`=14, `fp`=13, `pc`, `dp`) | enum rules of `spec/pdp64-mnemonics.hbnf` | the assembly parser (as enums), the bit-format grammar (via `mkgrammar.py`), a generated C header of named constants, the drift test |
| instruction bit layout (`len opc reg low` plus extension fields by class) | `spec/pdp64.hbnf.in` (a template: numbers come in by name) | the generated decoder and encoder (hbnf `parse_bytes` / `emit_bytes`) |
| assembly syntax | `spec/pdp64-asm.hbnf` | the generated text parser |
| ELF record layouts | `spec/elf.hbnf` | the generated record writer (and, later, `ld64`'s reader) |
| displacement widths, which mode uses which field shape, size of `reg`/`low`, the longest `len` | the bit grammar | **measured**, at startup, by asking the generated encoder how many bits it will take (it refuses a value that does not fit); never copied into C |

* **`tools/mkgrammar.py`** reads the enum rules, writes `build/pdp64.hbnf` (the template with every name replaced by its number), `build/pdp64-consts.h` (one
  `#define` per enumerator: `MN_ALU_CMP`, `AMODE_IMM`, `OPGROUP_SOP` ...), and `build/pdp64-groups.h` (the mnemonic groups in match order and the macro the
  parse-tree walker uses to read a mnemonic's number).
* **`tools/check-drift.py`** assembles one instruction for every mnemonic the assembler can encode, reads the encoding back and compares it with the number the
  grammar gives: 122 words checked, 0 differ. It also checks the opcode map (55 assigned; only `0x23` and `0x28`-`0x2F` free; escapes contiguous; branches
  `0x30`-`0x3F`). Before it existed those checks lived in a hand-written JSON spec that **repeated the opcode map**; when `FRECPED`/`FRSQRTED` were dropped it
  was the one file that had to be edited by hand, which is the failure the grammar is meant to prevent, so it was **retired** (`spec/pdp64.json` and
  `tools/specgen.py` are gone).
* **What still lives in C**, and must be shared with the emulator: the *roles* of the fields for each mnemonic (§4.3), the default stride of
  post-increment/pre-decrement by move size, and which shapes the escape groups take. `check-drift.py` guards the numbers but not these conventions.
  Putting an operand-role table in the mnemonic file is the next step.
* **Parcel-1 layouts that used to be arithmetic in C** (shifts of 8, 12) are named fields in the grammar: `RORI`'s `count`, `pos`/`width` of the bit-field
  group, `PROBER`'s `rd`, `TRAPL`'s `n`.

---

## 9. Errors in our own work, found and fixed

Recorded because the point of the exercise was to find where designs and tools drift or contradict themselves.

* **Fields cut to a length not yet chosen.** The first `build()` masked displacements to a width before the final instruction length was known. Fixed by
  computing the signed value and minimum length first and masking in a `finalize()` step.
* **Duplicated size counting** in the layout pass for data directives, and **error messages printed once per pass**: fixed (sizes counted in one place; errors only in the final pass).
* **Off-by-one in the width calibration** (the loop already stopped at the true width; a later `++` doubled it) and a fixed 8-bit branch range: fixed by measuring `reg`/`low` widths too.
* **`hbnf` matches enum words in the order written, as plain prefixes** (a union of plain words is sorted for you, but `|` is ordered choice and a
  mnemonic can be followed by an operand that starts with letters). `rori` was read as `ror` + junk, `r10` as `r1` + `0`, `bitrev` as `bit` + `rev`. We first
  worked around it by generating a longest-first copy and a safe group order. **That workaround is gone.** The grammar now names a `word` token, which makes every
  literal of two or more letters a *whole-word* keyword in any order; the one-letter alternatives that remain in number prefixes (`x`/`X` in `0x`, `f`/`b` in
  `1f`, the escape letters) are written as small character-class rules (`xch = %x78 | %x58`), which keyword mode leaves at character level. The registers are not
  open-ended, though: **`r16` is an assembler error** (user: "only r0 .. r15 are defined, plus aliases"). A name cannot be `r` followed only by digits, so `r16`
  is neither a register nor a name, whereas `r2d2` is an ordinary name.
* **The alias group made a cycle** (`bhis`/`bhi`, `blo`/`blos` precede each other), so no group order existed. Fixed by making aliases words of their target
  groups, numbered above the encodings.
* **`(r1)` was parsed as a parenthesised expression**, because the optional displacement `[expr]` swallowed `(r1)` and could not back out. Found only when the
  prefix test used register-indirect for the first time. Fixed with two ordered alternatives (with and without displacement), for both indexed and based modes.
* **A digit-led bareword was always taken for a number**, and `0b101` for the local-label reference `0b`. Fixed by giving numbers ordered precedence and
  requiring a number to be a whole bareword (lookahead), with the classification repeated in the assembler's expression reader.
* **Hand-computed test expectations were wrong twice** (several words of `digitnames`, where I had assumed a branch to itself; and `0x2b` where `N*2+1` with
  `N = 100/7*3` is 85 = `0x55`): the assembler was right each time. The lesson kept: the expectations are worked from the ISA by hand, then compared, and a
  disagreement is investigated before either side is changed.
* **Generated artifacts committed by mistake** (Python bytecode, a generated grammar): removed, `.gitignore`d.
* **A first version of the plan said to fork the C port of V7 `as`/`ld`.** After the grammar parser and generated encoder existed nothing of those 3,100 lines of
  16-bit PDP-11 code would have survived, so `as64` is new (it keeps V7's *layout*, not its code). `ld64` may still reuse `modern/usr/src/cmd/ld.c`'s symbol and
  archive logic.

---

## 10. Changes to hbnf (upstream) and workarounds

`hbnf` is the user's own project (`github.com/moebiusV/hbnf`). Findings and what was done:

| Finding | Status |
|---|---|
| **A number is not a number.** Enum values, bit positions, widths, repeat counts and constants each converted the lexer's number token themselves; `0b` in an enum value raised `CONSTRAINT_ERROR`. | **Fixed and pushed** (`c99c7cc`, "A number is a number"): one `Number_Value`, decimal/`0x`/`0b`/`0o` everywhere, `0o` new, `tests/numbers.sh`, `WIRE.md`. Rebased over a 60-file upstream commit and re-tested (`numbers`, `enumval` incl. Rust/Zig/Ada, `wire`). |
| `libhbnf.gpr` lists too few sources (`hbnf_lookahead`, `hbnf_tree_sitter`, `hbnf_wire-ada_lang`, `hbnf_wire-zig` are missing), so a plain `gprbuild` of the repository fails to link. | **Not fixed upstream.** `tools/build-hbnf.sh` lists every source. |
| Numbered enum values are refused under case-insensitive matching ("an alternative is not a plain literal"). | **Open.** Mnemonics are lowercase. |
| Enum words are matched in written order as plain prefixes; a word-boundary check after a keyword cannot work because whitespace is skipped before the lookahead is evaluated. | Documented; worked around in the generator. |
| In keyword mode, `hexnum = "0" ( "x" | "X" ) 1*HEXDIG` could not match `0x41`. | **Not an hbnf bug; no change made.** `hbnf`'s own `schema.sh` states the intended rule (with a `word` token, `"a"` is a keyword and `aa` must be rejected), and a patch that made single letters characters broke that test, so it was discarded. The fix is on our side: a group of letter alternatives makes the rule a phrase, but the same letters as a rule of their own (`xch = %x78 | %x58`) stay character-level. |
| The alternation `|` is ordered choice, `/` is the union that finds an order; for plain words `/` sorts longest first and keeps numbers in written order, but for a word followed by something that can begin with letters (an operand) there is genuine ambiguity and `/` is refused. | Behaviour as designed; explains why the generator exists. |

---

## 11. Environment decisions

* **No sudo and no docker daemon here** (the machine is WSL2 with Docker Desktop's pipe as the default context). `hbnf` needs GNAT 15 (Ada 2022
  container aggregates); the host has GNAT 14. `tools/build-hbnf.sh` therefore builds `hbnf` inside an **Alpine edge rootfs run under `bwrap` with user
  namespaces and `apk --usermode`**, no daemon and no root, using `gprbuild` and `mustache-ada` from the user's `ada-on-alpine` package files. The result
  is a static binary that runs on the host.
* **Keep dependencies current:** the user asked that `hbnf`, `pcc` and the toolchain be current with their origins before work; they were (`pcc` 0 commits
  behind upstream and its fork; `hbnf` is at origin/main plus our change).
* **Web access** (e.g. fetching the QEMU source later) is through the browser skill, not WebFetch, per the project instructions.

---

## 12. What is still open or unwritten

Not built: `sim64`, `ld64`, the pcc back end (`arch/pdp64`, to be copied from `arch/amd64`), a QEMU target (`target/pdp64`, a `pdp64-virt` machine, `qemu-pdp64`).
The plan is in `~/.claude-opusplan/plans/pdp64-toolchain.md`.

Assembler gaps: `ATOM` (22), `MESC` (8), `TRAPL`; the `BIC #imm` alias; PIC relocations (GOT, PLT, TLS types are not defined yet); division and
shifts of symbolic values.

Open design items (ISA §12 plus ours): **IEEE 754 directed rounding for arithmetic**: the standard requires round toward +infinity, -infinity and zero as well as to-nearest for add, subtract, multiply, divide, square root, fused multiply-add and the conversions; the ISA §9.8 says the mode lives in the opcode but gives no such opcodes for arithmetic, only for `FRINT*`. Options: (a) a 2-bit static rounding field in the instruction (the `FESC` two-register forms have a free nibble; the four top-level operations have none), (b) a rounding-mode register, which §1.1 forbids and §12 item 10 already worries about for `fesetround`, (c) three more opcodes per operation. Needs a decision; FP compare vs the signed branches for unordered operands (§2.3); atomics against Q64 (`DATIP`/`DATO` lock vs AXI exclusive
monitor); mandatory landing pads; worst-case instruction latency of `MBLK`; measured length distribution (the 4-byte case); a possible `d6(SP)` form; the red
zone; `long double`; whether the operand-role table should move into the mnemonic file (recommended).

---

## 13. Appendix

### 13.1 The 91 operations, folded

Fold rules: width (`q l w b`), zero/sign extension, precision (`s d`), integer vs float, memory-destination form, barrier (`_db`), load/store direction, unsigned,
high/low half, immediate vs register form, indirect form, by-one forms (`asl`, `asr`), register-mask form (`pushm`), and branch condition are *qualifiers*. A
different value of one of these is not a different operation.

* Moves and address: move, lea (2)
* Arithmetic and logic: add, subtract, multiply, divide, remainder, and, or, xor, and-not, compare, bit test, shift left, shift right logical, shift right
  arithmetic, rotate, funnel shift, clear, complement, increment, decrement, negate, test, add-with-carry, subtract-with-carry (24)
* Stack and control: push, pop, jump, call, jump through tag table, branch on condition, subtract-one-and-branch, branch on tag (8)
* Bit manipulation: count leading zeros, count trailing zeros, population count, byte swap, bit reverse, extract field, insert field, xnor-popcount,
  carry-less multiply, UTF-8 length, UTF-8 decode, UTF-8 encode (12; `clo`/`cto` fold with `clz`/`ctz` as the inverted forms)
* Block memory: copy, fill, compare, scan, UTF-8 validate (5)
* Floating point only: square root, fused multiply-add, absolute value, copy sign, minimum, maximum, classify, round to integral, convert (9)
* Unaligned move (1)
* **Atomics (10):** compare-and-swap, swap, fetch-and-add, -and, -or, -xor, -max, -min, load-linked, store-conditional
* **Other SMP (7):** fence, wait-for-event, send-event, TLB invalidate, TLB sync, instruction-cache invalidate, read CPU id
* **System (12):** no-op, return-from-interrupt, halt, breakpoint, landing pad, processor-status access, set priority, trap, address-space-id access, direct-page
  access, direct-map-window write, address probe
* Return (1)

(SMP total 17; system 12.) By comparison, from memory and unverified: the original PDP-11 is roughly 60 operations folded this way; VAX roughly 300 words,
perhaps 120 operations.

### 13.2 Files

```
spec/pdp64-mnemonics.hbnf   every number (the single source)           as64/as64.c     assembler core, ELF writer
spec/pdp64.hbnf.in          bit formats (template)                       as64/asmp.c     generated-parser walker
spec/pdp64-asm.hbnf         assembly syntax                              as64/fmtp.c     generated encoder/decoder wrapper
spec/elf.hbnf               ELF records                                  as64/relocs.h   relocation constants
tools/mkgrammar.py          generator                                    tools/check-*.sh, check-drift.py, check-all.sh
docs/errata.md  abi.md  asm-syntax.md  CHANGES-SINCE-R20.md (this)      tests/          formats.c, asmsyntax.c, asm/*.s + expected words
```

### 13.3 History (commits in `~/claude/pdp64`, oldest first)

ISA documents, spec, errata (`b9cc3e4`); ABI v1 and CMP/flag decisions (`f0b2837`); hbnf build script (`2ed1f9d`); bit-format grammar (`01908fa`); assembly syntax grammar (`100cca1`);
mnemonic numbers in hex then binary and the hbnf numbers change (`90ab54c`, `d2334ab`, then upstream `c99c7cc` and the local patch removed `ca4cf63`, `ba6f84c`);
`as64` walker and core (`44dc7f1`, `0eea194`); C numbers/strings/comments and the dropped features (`ab671a3`); UTF-8 and ELF names (`d8a044c`); bareword-colon labels (`269e445`);
single source of numbers (`b04cb3b`); named layouts, generated enum/group order, register-indirect fix, drift test (`c1bfc6e`); bytecode untracked (`4b0ceb5`);
`FRECPED`/`FRSQRTED` dropped (`38852f4`); JSON spec retired.
