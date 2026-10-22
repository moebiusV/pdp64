# pdp64: everything decided or changed since ISA revision 20 arrived

[← pdp64 index](../README.md)

On 2026-10-21 a tar, `pdp64-docs-2026-10-21.tar`, appeared in `~/claude/pcc`: three documents about a 64-bit PDP-11 (`11-64W-isa-r20.md`, the
FPGA plan, the LB64 accelerator note) and a README. Revision 20 of the ISA was a paper design, "nothing here has been synthesized, measured or taped
out". We were asked for a [pcc](https://github.com/moebiusV/pcc) back end, an assembler (in the spirit of V7 `as`), a linker if needed, and a plan for a [QEMU](https://www.qemu.org/) target. This file records
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
| Opcode map | 64 top-level slots: **57 assigned** (`0x28` `cbCC`, `0x29` its wide form), the spare ALU slot `0x23`, **6 reserved** `0x2A`-`0x2F`. (It was 55 assigned and 8 reserved at revision 20; ISA §4.16 said 56 assigned; see §2.) |
| Mnemonic words | **266**, of which 36 are aliases (the five of ISA 4.15, the 29 old floating-point spellings, and `cbhis`, `cblo`): 230 instructions (247 and 213 after binary16, errata 27, and 230 and 196 before it; the second page added 16 `cb` words and `rori32`, errata 31; `mfsr` and `mtsr` added 2, errata 32). |
| Operations, folded | **95** (91, plus `FSFLAGS`, plus `SET`, plus the fused compare-and-branch `cbCC`, plus the system-register move `mfsr`/`mtsr`; the unsigned conversions, `FRINTDA` and `rori32` are qualifiers and add none). "add" is one operation whether it adds integers or floats, in memory or in a register; width, precision, barrier, direction, extension, immediate form, indirect form, signedness, high/low half and branch condition are qualifiers (§13.1). |
| Assembled today | everything except `ATOM`, `MESC` and `TRAPL`; `tools/check-drift.py` lists the rest by name. |
| Written | the grammars, the generator, `as64` (assembler), tests, this documentation. |
| Not written | `sim64` (emulator), `ld64` (linker), the pcc back end, QEMU. |
| Checks | `tools/check-all.sh`: 11 instruction-format vectors, 34 syntax cases, 6 assembled programs compared word for word with hand-worked expectations, and a drift test over every mnemonic plus the opcode-map checks. All pass. |

The repository is `~/claude/pdp64` (git, `main`). The commit history is listed in §13.3.

---

## 2. Design errors found in ISA r20

Writing the encoding down as something a machine could check turned up the following. Each entry: what the document says, what is wrong, what we do.
[`errata.md`](errata.md) has the same list in the order it was found; the numbers in parentheses refer to it.

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
| **`CRC32`/`CRC32C`** (added for a short while, eight words) | `BESC` `0x34`-`0x3B` | The user withdrew them: carry-less multiply already covers every polynomial (errata 20). |
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
| `SET cc, rd` (AESC `0x20`) | set register to 1 or 0 from a condition (errata 25): the first instruction written with a condition word, `set eq, r1`; one sub-opcode with the condition in a field |
| `ABS`, `MIN`, `MINU`, `MAX`, `MAXU` (AESC `0x08`, `0x10`-`0x13`) | integer absolute value and minimum/maximum, signed and unsigned (errata 23); add no operation (the float forms exist) |
| `FRINTDA` (FESC `0x34`) | round half away from zero, for `round()` (errata 19) |

### 3.5 Aliases

**Now one rule (errata 24):** a word numbered 0x100 above another word of its group is an alias of it. The 29 old floating-point spellings use it. The original five aliases (`bhis`, `blo`, `mulu`, `wait`, `rol`) are implemented, as **words of the group they stand for, numbered above the group's own
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
* The grammars read bits **most significant first** ([hbnf](https://github.com/moebiusV/hbnf)'s convention, the order of the packet diagrams in the ISA), so the decoder works on parcels that
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

The ISA (§19.5) leaves the ABI open; a compiler cannot emit a call without one. **Version 1, accepted by the user** ([`docs/abi.md`](abi.md)):

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

Documented in [`docs/asm-syntax.md`](asm-syntax.md); grammar `spec/pdp64-asm.hbnf`. The design instruction was: *use the V7 assembler's layout, but don't copy its warts, and
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

Built since this section was first written: `ld64`, `sim64` (docs/sim64.md), the pcc back end (`arch/pdp64` in moebiusV/pcc). Not built: the QEMU target
(`target/pdp64`, a `pdp64-virt` machine, user mode); it is under way, as the `qemu/` directory of this repository plus a QEMU source tree kept outside it.

Assembler gaps: `ATOM` (22), `MESC` (8), `TRAPL`; the `BIC #imm` alias; PIC relocations (GOT, PLT, TLS types are not defined yet); division and
shifts of symbolic values.

Open design items (ISA §12 plus ours): **IEEE 754 directed rounding for arithmetic**: the standard requires round toward +infinity, -infinity and zero as well as to-nearest for add, subtract, multiply, divide, square root, fused multiply-add and the conversions; the ISA §9.8 says the mode lives in the opcode but gives no such opcodes for arithmetic, only for `FRINT*`. Options: (a) a 2-bit static rounding field in the instruction (the `FESC` two-register forms have a free nibble; the four top-level operations have none), (b) a rounding-mode register, which §1.1 forbids and §12 item 10 already worries about for `fesetround`, (c) three more opcodes per operation. Needs a decision; FP compare vs the signed branches for unordered operands (§2.3); atomics against Q64 (`DATIP`/`DATO` lock vs AXI exclusive
monitor); mandatory landing pads; worst-case instruction latency of `MBLK`; measured length distribution (the 4-byte case); a possible `d6(SP)` form; the red
zone; `long double`; whether the operand-role table should move into the mnemonic file (recommended).

---

### Design item: the fourth parcel and the length code `11` (raised 2026-10-22, **decided the same day**: see the decided design below)

**The question.** The `len` field of parcel 0 has two bits, so an instruction is 1, 2, 3 or 4 parcels (2 to 8 bytes). ISA §9.6 gives the reason there are four lengths as "`len` is two bits, and two bits
encode exactly four lengths". Do we need the fourth, and if not, what should the code `11` mean?

**What the fourth parcel buys.** It is used by the forms that carry a 44-bit base-register displacement or a 48-bit immediate, absolute address or PC-relative displacement (ISA §3.3), and by 48-bit branch
displacements and a few others. Hand-written code can use them; the compiler almost never does.

**What it costs the compiler, measured.** On the 841-file fair corpus with the optimizing flags (the pcc back end, 373,635 instructions after the first round of optimization): **49 instructions are eight bytes (0.013%)**
(the earlier compile of the same corpus, 405,744 instructions, had 49 as well; with the pcctests included there were 255). In the earlier compile they were mostly `cmp reg,#imm` with a constant wider than 32 bits. The compiler
uses 32-bit PC-relative addresses with a relocation, not 48-bit absolute ones. Replacing each by a PC-relative constant-pool load adds about four bytes: about 200 bytes of 1.25 MB, **0.016%**.

**What dropping it would change.** Immediate, absolute and PC-relative fields shrink from 48 to 32 bits (PC-relative reach stays about ±2 GB in bytes; an absolute address is a 32-bit sign-extended one, so kernel code in
the high address window would use PC-relative addressing); the base-register displacement shrinks from 44 to 28 bits (±128 MB); a 64-bit constant comes from a pool, as the ISA already says for `binary64`
literals. No instruction form of the escape groups needs the fourth parcel. "No instruction exceeds one `uint64_t`" (ISA §1) holds trivially, and the fault matrix (ISA §7.3) is unchanged, since six bytes at
two-byte alignment can still span two pages.

**The options for the length code `11`**, once the fourth parcel is gone:

| Option | What `11` means | Notes |
|---|---|---|
| A. Keep four parcels | four parcels | the status quo; no change |
| B. Three parcels, `11` reserved | reserved | simplest; wastes a quarter of the length space, but keeps it free for later |
| C. Three parcels, `11` is a second page of one-parcel instructions | one parcel, opcode from a second map of 64 | the length rule stays a function of `len` alone; adds 64 opcodes of two bytes, with the format `opc:6 reg:4 low:4`, so `low` can be a four-bit immediate, a second register, or the register of a register-deferred memory operand `(rN)`; a memory operand with a displacement needs the displacement inside the two bytes (a small offset from `sp`, with part of the offset carried in the opcode bits), otherwise it needs an extension parcel |
| D. Three parcels, `11` is a page of some other fixed length | e.g. two parcels | more opcodes, none of them short; less attractive |

**What option C could buy.** Two sets of measurements, both static counts on the 827-file fair corpus compiled by the pcc back end with the optimizing flags (the final output of 2026-10-22: 370,115
instructions, 1,672,166 bytes of image). The savings are in the image, two bytes per site. The first set is mine (register-and-immediate instructions whose immediate fits 4 signed bits, -8 to 7, counted from
the assembly output); the second is from [`codegen-analysis.md`](codegen-analysis.md) §9.

| Candidate one-parcel form | Sites | Saving | Share of image | One-parcel opcodes it takes |
|---|---|---|---|---|
| small immediates: `movq #imm4,rd` (7,838 sites), `shl` (2,146), `shr` (833), `and` (498), `sar` (97), `xor` (92), `bis` (84), `mul` (43), `add` (34) | 11,665 | 23,330 bytes | 1.4% | about 8 |
| register-deferred load or store `(rN)`, all widths | 12,941 | 25,882 bytes | 1.5% | about 11 (7 loads: `movq movl movw movb movzl movzw movzb`; 4 stores) |
| quad load or store at `d(sp)`, `d` a multiple of 8 below 512 | 11,928 | 23,856 bytes | 1.4% | about 8 (a 6-bit offset is 4 bits of `low` and 2 bits of the opcode, so each of load and store takes four opcodes) |
| **Together** | **36,534** | **73,068 bytes** | **4.4%** | **about 27 of 64** |

The immediate ranges are examples: a shift count wants 0 to 15 and not -8 to 7, and each instruction has its own best 4-bit range, so the 11,665 is a floor for some rows and a rough figure for others. The
`add` and `sub` rows are small because compilers add larger constants; the `sub` row is zero because `sub` sites are mostly frame adjustments.

Two more candidates are not one-parcel forms and do not compete for those 64 opcodes. They would use the eight reserved top-level opcodes (`0x28` to `0x2F`) or sub-opcodes of an escape group:

| Candidate | Sites | Saving | Share of image |
|---|---|---|---|
| a fused compare-with-5-bit-immediate-and-branch in 4 bytes (`cmp r,#imm ; bCC` is 6 bytes now) | 6,390 of 18,787 pairs (immediate in -16..15) | 12,780 bytes | 0.8% |
| `rol32 rs,#n,rd`, a 32-bit rotate by a constant (now about 14 bytes and 5 instructions) | 896 | about 8,960 bytes | 0.5%, a third of the code of the hash files (sha1, md5, sha256, ripemd160), the worst in the corpus |

**Not to be added:** a 2-byte `cmp #imm4,rd` (3,030 sites) saves the same two bytes at the same sites as the fused compare-and-branch, so only one of them is counted. With the fused form and the three one-parcel
rows the total is **about 86 KB, 5.1% of the image** (73,068 + 12,780 bytes). Two caveats: the groups were counted separately and could overlap in places I have not checked, and none of the forms has been specified.
It is also an estimate of bytes only: the number of instructions executed does not change for the one-parcel forms, and the fused compare-and-branch removes one.

**The linker is a separate and larger item.** 36,555 six-byte pc-relative `call` and `lea sym` forms, 4.4% of the image, would be four bytes if a linker relaxed references to symbols in range, or if there were a
short section-relative relocation. That needs no encoding change at all, only the linker and the assembler's relocation, and is the largest single item in the compiled-code analysis. It does not depend on this
decision.

An earlier version of this section estimated "about 2%" from the first compile of the corpus and the immediates alone, measured against the instruction bytes (2.2%); against the image, with the final output, the immediates are 1.4%.

**Costs and risks of changing it.**
* The encoding changes: the grammar (`spec/pdp64.hbnf.in`), the opcode map and its counts, the assembler, linker, `sim64` and the shared core, the QEMU target's length decode, the pcc back end's tables, the documents. The
  grammar being the single source makes this mechanical, and `tools/check-all.sh` would catch drift; it is still a large change.
* Option C adds a second opcode page to the decoder, which the ISA's own test (§1.2, rule 3, Occam) must justify against the gate count: the first-stage decode is a function of `len`, then a page select.
* ISA §1.2 rule 2 (do not displace a common instruction into a longer encoding) is satisfied: nothing common gets longer; the fourth parcel's users are rare.
* The text that says "any address is an eight-byte instruction" (ISA §3.3) and §9.6 would change. (Done: see the status below.)

**How to decide.** (1) The analysis of the compiled code is done ([`codegen-analysis.md`](codegen-analysis.md)); the candidates above come from it. (2) Specify the candidate
one-parcel forms, choose the immediate ranges per instruction and re-measure the saving, on the final corpus, against `gcc -Os` and `clang -Os`; check that the 27 or so opcodes fit with room to spare and that the groups do not overlap. (3) Decide A, B or C by the ISA's order of tests (§1.2): no strange side effects, no displacement into a
longer encoding, then Occam. (This was the plan when the item was raised. It was decided the same day; the ISA no longer has four parcels.)

### Decided design: the second page (2026-10-22, errata 31)

**Status.** Decided 2026-10-22 (errata 31, the author's decision). The ISA document is updated: §3.1, §3.1.1, §3.1.2 (new), §3.3, §4.4, §4.4.1 (new, `cbCC`), §4.6 (`rori32`), §4.14, §4.15, §4.16, §4.17, §4.18 (new, the page-2 map), §5, §7.3, §9.5, §9.6 (rewritten, with the old argument kept as history), §9.9 (the decision and its reasons), §11, §12 item 18 (resolved), §13, §14.4, §18, §19.2 and §19.4, Appendix A. The grammar, assembler, linker, emulator, QEMU target and tests are changed by the implementation of this item; the counts after the change are in the table of §1. [`asm-syntax.md`](asm-syntax.md) gives the new syntax.

**Implemented and measured (2026-10-22).** The grammar, assembler, linker, shared core, `sim64` and QEMU target implement the second page, `cbCC` and `rori32`; `tools/check-all.sh` passes, including a
differential test that runs every page-2 word and the long form it abbreviates on the same random states (10,496 instructions, 8 states each, 83,968 runs, no mismatch, and it fails when one case is corrupted).
The compiler is unchanged (the assembler chooses the forms). On the 827-file fair corpus, same byte metric as before (text, read-only data and data): **1,548,484 bytes, down from 1,672,166 (-123,682 bytes, -7.4%)**,
against the estimate of 118.6 KB (7.1%); the instruction count is unchanged at 370,115. Against the references, bytes: **1.031 times `gcc -Os`** (was 1.113) and **0.961 times `clang -Os`** (was 1.038), and 0.860 times our amd64 pcc.
Page-2 words in the output: 61,463 (122,926 bytes); instruction lengths 2 / 4 / 6 bytes = 59.9 / 29.0 / 11.1 %, none of 8. Three files grew by 4 to 8 bytes (the literal pool, below). Sites per family, measured against
the estimate: `(rn)` loads and stores 12,941 (9,089), `lea` from `sp` 3,674 (3,614), `movq` at `d(sp)` 8,514 (11,419), `movl` at `d(sp)` 8,643 (9,416), `d(rn)` 5,891 (5,849), `pushm8`/`popm8` 4,786 (4,784),
`sub`/`add` on `sp` 3,567 (3,561), four-bit immediates 13,447 (11,622). `cbCC` and `rori32` contribute nothing yet: the compiler does not emit them. Corrections found by the tests: the offsets of opcodes `0x1A`
to `0x1D` are 4, 8, 12, 16 (the formula of the specification was wrong). Per-file numbers are in `docs/codegen-data/`.

**Compiler work on the second page (2026-10-22), measured.** Same 827 files, same byte metric, references fixed (`gcc -Os` 282,329 instructions and 1,502,539 bytes; `clang -Os` 306,128 and 1,610,855);
all 504 C tests pass under `sim64` and under QEMU:

| Step | Instructions | Bytes | Bytes / `gcc -Os` | Bytes / `clang -Os` |
|---|---|---|---|---|
| before the second page (compiler of the first round) | 370,115 | 1,672,166 | 1.113 | 1.038 |
| second-page assembler, compiler unchanged | 370,115 | 1,548,484 | 1.031 | 0.961 |
| `lea d(rX),rX` becomes `inc`, `dec` or `add #d` when the flags are dead | 370,115 | 1,528,818 | 1.017 | 0.949 |
| wide constants as the explicit `=K` | 369,376 | 1,526,252 | 1.016 | 0.947 |
| `cmp rX,#imm ; bCC` and `tst rX ; bCC` become `cbCC` | 354,670 | 1,511,120 | 1.006 | 0.938 |
| `rori32` for unsigned 32-bit rotates by constants | 350,459 | 1,502,024 | 1.000 | 0.932 |
| `br L` to a bare `ret` becomes `ret` | **350,466** | **1,501,592** | **0.999** | **0.932** |

The compiler is now **level with `gcc -Os` in bytes (0.999) and 7% smaller than `clang -Os`**, with 1.24 times the instructions of `gcc -Os` and 1.14 times those of `clang -Os`. Emitted in the output (static counts): `cbCC` 14,717;
`rori32` 970; `inc` 8,806; `dec` 881; `=K` 335. Instruction lengths 2 / 4 / 6 bytes = 58.7 / 29.7 / 11.7 %, no 8-byte instructions, **3.06 bytes per instruction** (3.36 before the second page). Data: `docs/codegen-data/pdp64-after-compiler.csv`.
What did not pay: a `.pool` after each function (372 bytes worse than one pool at the end of `.text`, because literals stop being shared); getting the frame into the short `sp` forms (about 4,400 accesses are still long, up to 8.8 KB, but it needs
object boundaries in the frame that pass 1 does not give the back end).

**New open items from the compiler work.** (1) A wider-immediate `cbCC` (a 6-byte form with a 16-bit immediate): 11,821 `cmp reg,imm` remain unfused, mostly with immediates outside -16..15 (`#255`, `#47`).
(2) `rori32` zero-extends while the compiler keeps unsigned 32-bit values sign-extended, so each rotate costs a `movl` unless later code looks only at the low 32 bits (it does in hash code); whether `rori32` should sign-extend is
a convention question. (3) Aligning address-taken locals to 8 bytes would make 1,247 `lea` of locals short: needs a hook in pass 1.

**A deviation, resolved.** To keep the C tests passing without a compiler change, the first implementation pooled a constant wider than 32 bits silently, which contradicted the rule that one mnemonic assembles to one instruction (ISA §4.14). **Decided by the author (errata 33): the pooling is explicit sugar, `movq =K, rd`; a bare too-wide `#K` is an error.** The assembler has the `=` form and the `.pool` directive; the compiler emits `=K` for such constants.

The author chose option C with the explicit map (C1), asked for further candidates to be searched for, and asked for the fused compare-and-branch and the 32-bit rotate to be added. This is the specification.

**Lengths.** `len` = 00, 01, 10 give 1, 2, 3 parcels (page 1, as before, without the 4-parcel form); **`len` = 11 is one parcel of page 2**, in the layout `11 opc:6 reg:4 low:4`, with the opcode map below.
Page 1 loses its 48-bit forms: the immediate, absolute and PC-relative payload is 16 or 32 bits, the base-register displacement 12 or 28, the scaled-index displacement 6 or 22, the direct-page displacement 12 or 28, a
branch displacement 16 or 32 bits.

**The rule for every page-2 form:** it is *exactly* the operation of the page-1 instruction it abbreviates: the same result, the same flags, the same faults. An assembler that picks the shortest encoding can therefore
never change what a program does. A mnemonic still assembles to exactly one instruction (§4.14): the assembler chooses the length, as it does for branches.

**The map** (opcode numbers are those of page 2; `reg` is the register named first, `low` the field named second):

| Opcode | Instruction | `reg` | `low` | Long form it abbreviates |
|---|---|---|---|---|
| `0x00` `0x02` `0x04` `0x06` | `movq`, `movl`, `movw`, `movb` load: `rd <- M[(rn)]`, sign-extended | `rd` | `rn` | `mov (rn),rd` (base mode, displacement 0) |
| `0x01` `0x03` `0x05` `0x07` | `movq`, `movl`, `movw`, `movb` store: `M[(rn)] <- rs` | `rs` | `rn` | the same, store |
| `0x08` `0x09` `0x0A` | `movzl`, `movzw`, `movzb` load from `(rn)` | `rd` | `rn` | `movz (rn),rd` |
| `0x0B` | `lea 8*d(sp),rd` | `rd` | `d` (0 to 15) | `lea 8*d(sp),rd` |
| `0x0C` `0x0D` | `movq` load from `sp`: offset `8 * ((opc & 1) * 16 + low)`, 0 to 248 | `rd` | offset, low 4 bits | `movq d(sp),rd` |
| `0x0E` | `movq` store to `sp`: offset `8 * low`, 0 to 120 | `rs` | offset | `movq rs,d(sp)` |
| `0x10` `0x11` | `movl` load from `sp`: offset `4 * ((opc & 1) * 16 + low)`, 0 to 124 | `rd` | offset low 4 bits | `movl d(sp),rd` |
| `0x12` `0x13` | `movl` store to `sp`: offset `4 * ((opc & 1) * 16 + low)`, 0 to 124 | `rs` | offset low 4 bits | `movl rs,d(sp)` |
| `0x14` to `0x17` | `movq` load from `rn` at offset `8 * (1 + (opc & 3))`, i.e. 8, 16, 24, 32 | `rd` | `rn` | `movq d(rn),rd` |
| `0x18` `0x19` | `movq` store to `rn` at offset `8 * (1 + (opc & 1))`, i.e. 8, 16 | `rs` | `rn` | `movq rs,d(rn)` |
| `0x1A` to `0x1D` | `movl` load from `rn` at offset `4 * (1 + (opc - 0x1A))`, i.e. 4, 8, 12, 16 for `0x1A`, `0x1B`, `0x1C`, `0x1D` | `rd` | `rn` | `movl d(rn),rd` |
| `0x1E` | `pushm8`: push registers `r8` to `r15` named by the 8-bit mask `reg:low` (bit `i` is `r(8+i)`) | mask high | mask low | `pushm #(mask << 8)` |
| `0x1F` | `popm8`, the mask as for `pushm8` | mask high | mask low | `popm #(mask << 8)` |
| `0x20` | `sub #(8*n),sp`, `n = reg:low` (0 to 255) | n high | n low | `sub #(8*n),sp` |
| `0x21` | `add #(8*n),sp` | n high | n low | `add #(8*n),sp` |
| `0x22` | `movq #imm,rd`, `imm` sign-extended 4 bits (-8 to 7) | `rd` | imm | `movq #imm,rd` |
| `0x23` `0x24` `0x25` | `shl`, `shr`, `sar` by `low` (0 to 15) | `rd` | count | `shl #n,rd` etc. |
| `0x26` `0x27` `0x28` | `and`, `bis`, `xor` with `imm` sign-extended 4 bits | `rd` | imm | `and #imm,rd` etc. |
| `0x29` | `add #imm,rd`, `imm` sign-extended 4 bits | `rd` | imm | `add #imm,rd` |

Reserved in page 2: every opcode not listed (`0x0F`, `0x2A` to `0x3F`, 23 of the 64). A reserved opcode is an illegal-instruction abort.

(`0x0C` gives offsets 0 to 120 and `0x0D` offsets 128 to 248 in steps of 8, the low four bits of the offset being `low`. In the same way `0x10`/`0x11` and `0x12`/`0x13` use the opcode's low bit as bit 4 of the offset field.
The opcode numbers of page 2 are independent of those of page 1: for example `0x28` of page 2 is `xor #imm,rd`, while `0x28` of page 1 is the new `cbCC`.)

**Two further instructions in page 1:**
* **`cbCC rd,#imm,target`**: compare-immediate-and-branch, in the reserved top-level opcode **`0x28`**. Meaning: compute `rd - imm` as `cmp rd,#imm` does (same flags), then branch if the condition `CC` holds.
  `len = 01` (4 bytes): parcel 0 `01 0x28 rd cond` (`low` is the branch condition number, as for `set`); parcel 1 `imm:5 disp:11`, `imm` signed (-16 to 15) and `disp` signed, in parcels from the first parcel of
  the instruction, ±1024 parcels. `len = 10` (6 bytes): parcel 1 `imm:5 disp-high:11`, parcel 2 `disp-low:16`, a 27-bit displacement. The assembler picks the length (as for `bCC`); the immediate must fit 5 bits,
  and the compiler emits `cbCC` only then. Mnemonics: `cbne cbeq cbpl cbmi cbvc cbvs cbcc cbcs cbge cblt cbgt cble cbhi cblos` and the aliases of the branch group. Condition names and numbers are those of `bCC` and `set`.
* **`rori32 rs,#n,rd`**: a `BESC` sub-opcode with the format of `rori` (`sub:8 count:8` in parcel 1): `rd <- zero-extend( ror32( rs[31:0], n mod 32 ) )` (**superseded by errata 34: sign-extended**). The result was zero-extended because unsigned 32-bit values
  are kept zero-extended by the compiler and rotates of hash and crypto code are unsigned; a signed rotate is `rori32` followed by `movl rd,rd`.

**Estimated saving**, static counts on the 827-file fair corpus compiled with the optimizing flags (the final output of 2026-10-22, 370,115 instructions, 1,672,166 bytes of image), two bytes per site, from
a script over the assembly output (`/tmp/p64opt/cand.py`, results in this section):

| Family | Sites | Saving | Share of image |
|---|---|---|---|
| `(rn)` loads and stores, all widths (`0x00` to `0x0A`) | 9,089 | 18.2 KB | 1.1% |
| `lea 8*d(sp),rd` (`0x0B`) | 3,614 | 7.2 KB | 0.4% |
| `movq` at `d(sp)`: load 7,698, store 3,721 | 11,419 | 22.8 KB | 1.4% |
| `movl` at `d(sp)`: load 6,170, store 3,246 | 9,416 | 18.8 KB | 1.1% |
| `movq`/`movl` at `d(rn)` with the small offsets above | 5,849 | 11.7 KB | 0.7% |
| `pushm8`, `popm8` (all 2,392 + 2,392 sites use a mask of `r8` to `r15`) | 4,784 | 9.6 KB | 0.6% |
| `sub`/`add #(8*n),sp` | 3,561 | 7.1 KB | 0.4% |
| four-bit immediates (`movq` 7,838, `shl` 2,146, `shr` 833, `and` 498, `sar` 97, `xor` 92, `bis` 84, `add` 34) | 11,622 | 23.2 KB | 1.4% |
| **Page 2 together** | **59,354** | **118.6 KB** | **7.1%** |
| `cbCC` (immediate in -16 to 15) | 6,390 | 12.8 KB | 0.8% |
| `rori32` | 896 | 9.0 KB | 0.5% |
| **All** | **66,640** | **140.4 KB** | **8.4%** |

Caveats: the counts are static; the families are distinct instruction shapes and do not overlap, but I have not checked the interaction of one saving with another (a shorter instruction can bring a jump
within a shorter encoding); the offset and immediate ranges were chosen from the histograms of the same corpus, so the estimate is optimistic for other programs; the page uses 41 of its 64 opcodes. The two pieces of
evidence that are not about the encoding: the compiler emits `lea 1(rX),rX` 7,852 times and `lea -1(rX),rX` 395 times where the two-byte `inc` and `dec` exist (about 16 KB, 1.0%), and the 36,555 six-byte external
`call` and `lea sym` forms (4.4%) need linker relaxation, not an encoding.

**What changes.** The grammar (`spec/pdp64.hbnf.in`, `spec/pdp64-mnemonics.hbnf`); the assembler (it chooses the shortest form for each of the above, and relocations lose the 48-bit forms: a symbol immediate
or absolute address is 32 bits, sign-extended); the linker; the shared execution core (page-2 forms are decoded to the long form they abbreviate and executed by the same code, so the semantics are written once); `sim64`;
the QEMU target (a length of 1 parcel for `len = 11`); the documents (ISA §3, §4, §9.6, §12, §13, §14, glossary). The compiler needs no change for the page-2 forms (the assembler selects them); it needs the peephole rules for
`cbCC`, `rori32` and `inc`/`dec`, which are measured separately.

### Added: system-register moves for a paging operating system (2026-10-22, errata 32)

The system architecture document ([`pdp64-system-architecture.md`](pdp64-system-architecture.md) §3) listed registers a kernel needs and no instruction to reach them. `mfsr rd,name` and `mtsr name,rs` (class-0 minors 13 and 14 of
`SYS`, four bytes, system-register number in parcel 1) reach `ptbr`, `epc`, `eva`, `ecause`, `dmw0`, `dmw1`, `usp` and `ssp`; both are privileged. Details and reasons are in errata 32.

### Decided: a wide-immediate `cbCC` and a sign-extending `rori32` (2026-10-22, errata 34)

Specification: errata 34. In short: `rori32` result is sign-extended (ISA §4.6 and the earlier text of errata 31 say zero-extended: superseded); `cbCC` gains the encoding `10 0x29 rd cond | imm:16 | disp:16` (six bytes,
reach +-64 KB) and the assembler picks the shortest of the three `cbCC` encodings. The expected effect is about 11,800 fewer instructions and about no change in bytes; the measured effect is recorded here when the work is done.

**Implemented and measured (2026-10-22).** Same 827 files and byte metric; all 504 C tests pass under `sim64` and under QEMU.

| Step | Instructions | Bytes | Bytes / `gcc -Os` | Bytes / `clang -Os` | Instr. / `gcc -Os` | Instr. / `clang -Os` |
|---|---|---|---|---|---|---|
| before (end of the previous round) | 350,466 | 1,501,592 | 0.999 | 0.932 | 1.241 | 1.145 |
| `rori32` sign-extends: no `movl` after it | 350,422 | 1,501,500 | 0.999 | 0.932 | 1.241 | 1.145 |
| wide-immediate `cbCC` | **338,687** | **1,499,672** | **0.998** | **0.931** | **1.200** | **1.106** |

As predicted in errata 34: **the wide `cbCC` removed 11,735 instructions (3.4%) and only 1,828 bytes (0.12%)**, which fall where the branch was four bytes; sign-extending `rori32` saved 44 instructions (the demand analysis had already removed
nearly every `movl` after a rotate). 11,821 wide `cbCC` were emitted (26,460 `cbCC` in all); 644 `cmp reg,#imm ; bCC` remain, all with an immediate beyond 16 bits. The compiler emits the wide form only in a function of at most 9,000
instructions with the label inside it (so that every label is within the 64 KB reach); no function in the corpus was skipped (the largest has fewer than 6,000). Instruction lengths 2 / 4 / 6 bytes = 57.5 / 26.9 / 15.5 %, average
3.16 bytes (it was 3.06: a six-byte `cbCC` replaces a four-byte and a two-byte instruction). Three files of 827 grew by 2 to 4 bytes (a tie where alignment of nearby code differs). Data: `docs/codegen-data/pdp64-after-cbw.csv`.

**New open items.** (1) A **register-register compare-and-branch**: 4,714 `cmp reg,reg ; bCC` pairs remain (1.4% of instructions); a one-parcel-plus-displacement form would save those instructions and, only where the branch was four
bytes, some bytes (between none and about 9 KB, probably a few KB; the length split is not measured). A further 5,356 `cmp reg,mem ; bCC` pairs cannot be fused, since the memory operand has no room. (2) The assembler **refuses**
a wide `cbCC` whose target is beyond 64 KB, where it could fall back; a fallback would make the compiler's 9,000-instruction rule unnecessary, at the price of the assembler emitting two instructions for one mnemonic (against ISA §4.14).

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

## Toolchain status (2026-10-21, end of day)

* **ld64**, **sim64** (docs/sim64.md) and the pcc back end (`~/claude/pcc/arch/pdp64`) exist. `tools/check-all.sh` runs the format vectors, the
  syntax cases (42), the assembler programs, the link test, the drift test (214 checked, 0 differ), the header freshness check and the emulator
  programs (7). Compiled C runs under `sim64` through `tools/pdp64test.sh` in the toolchain repo (79 of 81 default-flag tests at this writing).
* Found by running code: the format template named an alias (`fcmpd`) so every opcode above the ALU decoded as a memory instruction (the generator now
  refuses alias numbers and the vectors assert the decoded shape); `(sp)` without a displacement was read as a parenthesized symbol; `.even` mis-counted
  during layout; sections lost their alignment; NaN results are now canonical (errata 26).
* Assembler rules made explicit: an instruction at an odd address is an error; `r<digits>`, `sp`, `fp` cannot be unquoted symbol names.
* Fair-corpus measurement (841 files): 1.05x the instructions of amd64 and aarch64, 0.98x / 0.89x their bytes; instruction lengths 2/4/6/8 bytes =
  46.5 / 42.8 / 10.6 / 0.1 %; 35,000 six-byte cross-section `call`/`lea`. Compiler-side wishes recorded by the back-end work: sized (32/16/8-bit) ALU
  memory operands or `addw`-style 32-bit arithmetic (`movl` is 10% of instructions, wrap-correct `int` costs 4%), a short `d(sp)` form (not
  measured), linker relaxation of cross-section references.

## 14. What the measurements say about the instructions we did and did not add

These are the figures behind the decisions and the proposals still open. Method: the "fair corpus" is the 841 files of the benchmark set (bearssl, c-testsuite,
chibicc, cjson, gcc-torture, lua, lz4, mbedtls, zlib) that the aarch64, amd64 and i386 builds of our compiler all compile.

**Conditional selection and set-on-condition (`CMOV`, `CSEL`, `SET`).** gcc `-Os` for amd64 on the corpus emits 284,641 instructions, 11.0% of them conditional
branches, 783 `cmov` and 673 `set<cc>`. A `set cc, rd` removes about six bytes per site (compare, branch, two moves, jump, versus compare and set), which is about
0.4% of code. A conditional select is size-neutral (it replaces a short branch around a move with one instruction of the same length) and pays only in speed, by
removing a misprediction. Floating-point values live in the general registers, so one integer select would also serve as a floating-point select. Decision:
`set cc, rd` was added (errata 25, cheap and useful for `return a < b`); the select is on hold until there is a speed model to justify it. The compiler
cannot yet use `set`: pass 1 turns a comparison used as a value into branches before the back end sees it, so it needs a hook in shared code that has not been made.

**Integer `ABS`, `MIN`, `MAX`.** gcc's intermediate form shows `ABS` at 18 sites and `ABSU` at 5, `MIN` at 171 and `MAX` at 52, across 95 files (zlib's deflate, lz4,
cJSON, mbedtls bignum, chibicc, lua). Added at the user's request (errata 23); the measured gain is under 0.1% of code, so the case for them is clarity and
the idiom, not size. Recognizing them in the compiler is a shared front-end change that has not been made.

**Bit-fields (`EXTB`, `EXTZB`, `INSB`).** The shift-pair extraction pattern occurs 151 times in 26 files of the corpus, about 600 bytes at best (0.03%); the
compiler does not use the instructions.

**Auto-increment (`(rN)+`, `-(rN)`).** Of 10,547 `lea n(rX),rX` in the corpus only 437 have a dereference through the same register next to them (about 0.1%);
the compiler does not emit the modes. They remain in the ISA for hand-written code and for the string and block idioms.

**Half precision (`binary16`).** Added at the user's request (errata 27): seventeen `FESC` words, `fadd16`..`fclass16` and six conversions (`fcvtsh`, `fcvths`,
`fcvtdh`, `fcvthd`, `fcvthl`, `fcvtlh`). Estimates made before the decision, unmeasured: conversions only about 500-1,000 LUTs on the FPGA plan, full arithmetic
2,000-3,500 LUTs. Open: half `fmin`/`fmax`/`frint*`, `fneg16`/`fabs16`, int64 conversions, bfloat16.

**Directed rounding.** IEEE 754 requires rounding toward +infinity, -infinity and zero for arithmetic as well as to nearest. Three ways to provide it are open: a
static two-bit field in the instruction, a mode register, or more opcodes. The cost of each is in section 12; none is chosen.

**Code generated by the first compiler** (pcc back end, 2026-10-21; fair corpus, optimized flags): 405,744 instructions and 1,762,610 bytes, 1.03 times amd64 and
1.04 times aarch64 in instructions, 0.97 and 0.89 times in bytes. Instruction lengths 2 / 4 / 6 / 8 bytes = 46.5 / 42.8 / 10.6 / 0.1 %, 3.30 bytes on
average. Costs the ISA could remove: about 35,000 six-byte cross-section `call` and `lea` (linker relaxation or a short relocation); memory operands that are
quad only, so `movl` is 10% of all instructions; no 32-bit arithmetic, so a wrap-correct `int` costs 4.1% of instructions and 1.9% of bytes (`-mnowrap`, which
assumes no signed overflow, gives 0.99 and 0.96 times amd64); a short `d(sp)` form (not measured).

**Sized integer arithmetic.** Considered and decided against (errata 28, the user's decision): arithmetic stays 64-bit, narrow values are extended by `movb movw movl`
(sign) and `movzb movzw movzl` (zero), and the compiler re-extends where needed. Cost measured on the fair corpus: 4.3% of instructions are re-extensions, 2.1% are
narrow loads consumed by the next instruction, and only 146 of those would fuse into a sized memory operand.

**QEMU.** `qemu-system-pdp64 -M pdp64-virt -kernel prog` runs the sim64 programs through the same shared core and generated decoder (qemu/README.md); the 9 assembly tests and all 492 C test runs give the same results as under sim64.

**Devices.** Ethernet, USB and disk devices are each eight memory-mapped registers plus DMA (errata 29, the author's decision): trivial drivers and no multitasking burden
on the processor. No ISA change; the layouts and the DMA descriptor format are not yet written (ISA section 16).

**Operating system plan.** The first operating system is a port of Unix/32V; OpenBSD follows if an LLVM back end proves easy enough (errata 30). The system architecture document ([`pdp64-system-architecture.md`](pdp64-system-architecture.md)) lists what that needs and
what is still undefined.
