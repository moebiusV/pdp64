# Linker relaxation (pdp64/16 and pdp64/32)

The assembler cannot know how far a symbol of another file is, so an external `call f` is assembled in its longest form (6 bytes) and so is `lea sym, rd` of a
data symbol.  The encodings have shorter forms (a `call` of 4 bytes reaches +-1 MiB; `lea` and the pc-relative loads of 4 bytes reach +-32 KiB).  Once the
linker has put the sections at their addresses the distance is known, so the linker chooses the form.  This document describes the object format that
makes it possible, the algorithm of `ld64`, what it cannot do, how it is checked and what it saves.  The decision (errata 89): the author asked for the
relaxation of external `call` and `lea`; the rest of what is described here is how the implementer made that correct.

Only the new encodings are relaxed.  The original encoding (pdp64/r20) is untouched: its lengths come from the parcel's `len` bits and its objects
are linked as before.

## 1. The object format

`as64 -m pdp64/16 --relax` (or `pdp64/32`) makes a **relaxation object**.  `--relax` is off by default: an object made without it is the object of
the phase-1 assembler, byte for byte, and links as before.  A relaxation object differs in three ways.

**e_flags.**  The low four bits are the encoding (1 or 2) as before.  Two new bits (`as64/relocs.h`):

| flag | value | meaning |
|---|---|---|
| `EF_PDP64_RELAX` | 0x10 | the object follows the rules below; `ld64` may change the length of its instructions |
| `EF_PDP64_NOADJ_TEXT` | 0x20 | (with RELAX) `.text` holds something that depends on a distance and is not a relocation; the linker leaves this object's `.text` exactly as it is |

The executable carries only the encoding.  `ld64` refuses the flags in an object of the original encoding.

**A relocation on every instruction that holds the address of a symbol.**  Without `--relax`, `as64` resolves a reference to a label of the same section
itself and records a relocation only for an external symbol or one of another section.  With `--relax` it records the relocation for the local
labels too, with the value already in the instruction (so the object, linked without relaxation, is the same program).  The types are the old ones:
`R_PDP64_INSN_PC` (a `d(pc)` operand, bytes), `R_PDP64_INSN_BR` (a branch or call field, parcels), `R_PDP64_INSN_ABS` (an immediate or absolute address).  The
symbol is the section symbol of the object's `.text` or `.data` (with the offset in the addend) for a local label, the symbol itself for a global.  The
relocation is the mark of a relaxable site: no second record is made, because the instruction has exactly one operand that holds an address, and the
relocation says where it is, what it refers to and in which unit.  A literal-pool load (`mul =K, r0`) refers to the pool entry, a local symbol, and is a
site like any other.

**A relocation on every padding.**  `.even`, `.align N` and the alignment of the literal pool (`.pool`, 8) in `.text` leave a padding whose length depends on the
position.  Each such padding gets `R_PDP64_ALIGN` (type 6): `r_offset` is where the padding starts, the symbol is 0 and the addend is
`(bytes of padding) << 32 | alignment`.  A padding of 0 bytes that only asks for 2-byte alignment is not recorded (positions in `.text` change by even amounts).

**Position-dependent constants.**  A number the assembler computes from the position of two labels of `.text` (`.word L1 - L0`, `#L1 - L0`, an assignment
`x = L1 - L0`) is correct only if nothing between the labels changes length, and it carries no relocation.  Likewise a `d(pc)` written as a number, and an
instruction that has two operands with an address (so that one relocation cannot cover it).  `as64` sets `NOADJ_TEXT` when it meets one of them.  The
linker then does not change that object's `.text` at all; its relocations are applied at the lengths the assembler chose.  (Differences of labels of `.data`
are constants too, but `.data` never changes length.)

`--dump-lens FILE` is unchanged (per instruction: source line, parcels, offset in `.text`); `tools/check-relax.py` uses it.

## 2. What `ld64` does

Input objects are read as before.  An object is **adjustable** if it has `RELAX` and not `NOADJ_TEXT` and `--no-relax` was not given.  In the `.text` of an
adjustable object, the relocations of types INSN_PC, INSN_BR, INSN_ABS and ALIGN are the **sites**.  Everything between them is a stretch of bytes that is
copied.  Per input section there is a sorted list of sites: offset in the object, length in the object (`len0`), length now (`cur`).

**The map.**  An offset `x` in the object's section becomes `x + sum(cur - len0)` over the sites that end at or before `x`.  The section's size, the
address of every symbol (`isec_addr`), the place `P` of every relocation, and the *addend* of a relocation against a section symbol or a symbol with an
offset (`sym + 8` is the old offset `value + 8`, which is mapped, not `map(value) + 8`) all go through this one function.  So moves, in one place: global and
local symbols, the entry point, `D64` and `D32` relocations in `.data` (tables of code addresses) and in `.text`, pc-relative references
between sections, literal-pool references (a site against a local symbol), and the start of every input section after a shrunk one.  The sizes of symbols
are not recorded by `as64` (no `.size`), so there is nothing to fix; there is no debug information.

**The lengths.**  An instruction site starts at the shortest form of its instruction: the codec decodes the instruction the assembler wrote into a mnemonic and
operands (`enc_decode`), puts 0 in the address operand and asks for the shortest form (`enc_len`).  Then rounds:

1. lay the sections out: each input section follows the one before at its alignment; every padding is as long as its alignment asks at its new place (`pad =
   (A - pos mod A) mod A`, nops where there are two bytes at an even offset, as the assembler fills them); the class bases follow (`.data` on the next page after
   `.text`, as before);
2. for every instruction site compute the value of its operand on that layout (`S + A - P` for a pc-relative operand, `S + A` for an absolute one) and ask the codec
   for the shortest form **of at least the present length** that takes it (`enc_encode_n`); if it is longer than the present length, the instruction grows;
3. if any instruction grew, repeat.

At the end the sections are written: stretches copied, each site encoded for the final layout (the codec places the field in the form; the operands other than the address
are those of the assembler's instruction, and `ld64` decodes what it wrote and compares it with the assembler's instruction before accepting it), paddings filled, then the other relocations
applied through the same map.

**Why it ends.**  Lengths only grow, each is at most the longest form (6 bytes, 5 parcels), and a round that grows nothing is the last.  A padding is not a state:
it is recomputed from the lengths in every layout, so it has no part in the argument (it is not monotone: removing two bytes before an `.align 8` can make the padding
six bytes longer).  **Why it is right:** in the last round nothing grew, so the layout in which the values were measured is the layout that is written, and every
instruction has the form that `enc_encode_n` returned for its value, of exactly its length; if there is no such form (a distance beyond the longest form) the
link fails and names the symbol.  The text segment of one input object is placed on the alignment of its largest `.align`, which the object's section header
records, so positions inside the section are positions modulo every alignment in it.

**Minimality.**  When no padding lies between a site and its target the system is monotone (a longer instruction can only make the other distances longer), the iteration
starts from the bottom and the result is the *least* fixed point: no site can be shortened without another becoming too short.  When there are paddings the
result is correct, but a padding that happened to be long in an early round can leave an instruction longer than necessary.  Starting from the shortest forms
(growth) and not from the assembler's (shrinking) is what makes this safe: a distance that is not monotone (an alignment, the page between `.text` and
`.data`, which makes a `lea` of data longer when the text before it shrinks and the data does not move) can only make an instruction grow later, never leave
it too short.  The assembler's own relaxation (growth from the shortest, one pass of lengths per round) is the same scheme.

**Cost.**  Each round is linear in the sites (a binary search per address).  The generated test (126,000 sites) needs 2 rounds; the six programs 2 or 3.

## 3. Options

    as64 -m pdp64/16|pdp64/32 --relax [--no-relax] [--dump-lens f] -o obj file.s
    ld64 [--no-relax] [--stats] [--dump-map f] [-M] [-o out] objects...

`ld64 --no-relax` links relaxation objects as they were assembled: the same image, byte for byte, as the link of the same program assembled without `--relax`
(`tools/check-relax.sh` compares them).  An executable linked with relaxation is the same program as the one linked without (the differential runs below).  `--stats`
prints the sites by category and the bytes they gained; `--dump-map` writes, per input `.text`, where it went and the length change of every site, which is what
`tools/check-relax.py` needs to find every instruction of the linked image.

## 4. The reaches (from `spec/pdp64-NN/forms.json`)

A pc-relative field counts parcels (2 bytes) for calls and branches and bytes for memory operands.  Range is the value of the signed field times the unit.

| instruction | forms (bytes: field bits, reach each way) pdp64/16 | pdp64/32 |
|---|---|---|
| `call` | 4: PC16 64 KiB, PC18 256 KiB, PC20 1 MiB; 6: PC32 | same |
| `jmp`, `movcall` | 4: PC16 64 KiB; 6: PC32 | same |
| `br` | 2: 64, 256, 512 B; 4: 64 KiB; 6: PC32 | 2: 64, 256 B; 4: 64 KiB; 6 |
| `bCC` | 2: 64, 128, 256 B; 4: 64 KiB; 6 | 2: 64 B; 4: 64 KiB; 6 |
| `cbCC` | 2: 32, 64 B; 4: 256 B, 1 KiB, 4 KiB, 16 KiB; no 6-byte form (the assembler expands to `cmp` + `bCC`) | 2: 32 B; 4: 256 B to 16 KiB |
| `sob` | 4: 64 KiB | same |
| `lea sym`, `movq sym, rd`, ALU `sym, rd` | 4: PC12 2 KiB, PC14 8 KiB, PC16 32 KiB; 6: PC32 or absolute A32 | same |

The reach of the 4-byte `call` is +-1 MiB, not the +-2 MB of the encoding proposal (field 20 bits, unit 2 bytes).

## 5. What relaxation does not reach

* A call, jump or `lea` farther than the 4-byte form reaches stays at 6 bytes; the 6-byte forms reach +-2 GB (the 32-bit field: errors name the symbol).  `lea` of a
  data symbol reaches +-32 KiB only; in a program whose `.text` is longer than that, the data `lea` stays long for most of the data.  `.data` begins on the page after `.text`.
* There is no 2-byte `call`, `jmp`, `lea` or pc-relative load.  The shortest external call is 4 bytes.
* Indirect calls (`calli`, `jmpi` through a pointer, a call through a register) are one parcel plus a pointer in memory and are not touched; there is no PLT, no GOT and no shared object.
* The absolute forms (`@sym`, `#sym`) are relaxed when their value fits a shorter signed field (they do not, at `.text` 0x10000, below 2 KiB).
* A `cbCC` that the assembler had to expand (`cmp` + `bCC`, because the target was external, far, or the immediate wide) stays expanded: the linker does not turn two
  instructions back into one.
* An object with `NOADJ_TEXT` is not adjusted.  Only `.text` is adjusted; `.data` and `.bss` do not hold instructions.
* A label that is immediately before an `.align` that happened to need 0 bytes of padding is placed *after* the padding if the padding becomes longer (the
  label and the end of a zero-length padding are the same offset).  Where the padding is more than 0 the label stays before it.  Nothing in the compiler's output has a
  label before an `.align`.

## 6. Checks (`tools/check-relax.sh`, part of `tools/check-all.sh`)

* A program of 126,913 instructions generated by `tests/relax/gen_relax.py` for pdp64/16 and /32, in two objects: 5 kinds of forward branch and 3 of backward loop over
  0 to 150 external calls (the 6-byte calls of the assembler's layout against the 4-byte ones of the linker's, so the form of the branch differs between the two), branches near
  the 64 KiB reach, a call beyond the reach (700 KB), `lea` of external, local and `.comm` data, literal-pool loads, `.pool` in the middle, `.align 4/8/16/32`, `.even`
  after odd data, tables of code addresses in `.data` (`.quad f`, `.long f`), `calli` through them, `movcall`, a global that the other object calls, defined behind relaxed code.
  Its exit status is computed by the generator.  It runs relaxed and with `--no-relax`: same result, the relaxed image 17.3% smaller (1,215,936 against 1,469,888 bytes; 2 rounds).
* The result of every program of `tests/sim` and `tests/sim-enc` is the same relaxed (`check-sim64.sh` runs them as `16r` and `32r`, with `.same` tests: the log of 1551 cases is identical).
* **The self-consistency check** (`tools/relaxcheck.c`): the instruction offsets the assembler lists (`--dump-lens`) are moved by `--dump-map` to their addresses in the linked
  image; each is decoded by the C decoder; its length is the decoder's and ends at or before the next instruction; every `br`, `bCC`, `cbCC`, `sob`, `call`, `jmp`, `movcall`
  lands on one of those starts; any other pc-relative operand lands in the data segments or in `.text` outside every instruction; a load from `.text` (a literal pool) is at
  a multiple of its size; every global symbol in `.text` is an instruction start.  It is run on the relaxed and on the unrelaxed images of the generated program and on every relaxed `tests/sim` program.
* `tools/check-relax.sh --mutate`: seven mutants of `ld64` (an unmapped offset, paddings not recomputed, no growth, three symbol-address paths left unmapped, a padding of the wrong length)
  are each caught by the generated program.
* `NOADJ_TEXT` (`tests/relax/noadj.s`: a `.word L1 - L0` table in `.text`): the text is as assembled and the program runs; the 2 GB limit is still reported with the symbol named; `as64 --relax` for pdp64/r20 is refused.

## 7. Measurements

Exact numbers from `ld64`, `sim64 -P` and the pcc-enc compiler of the tree `pcc-enc` (branch enc-prefix, `ccom -m pdp64/16` and `-m pdp64/32`, default flags), assembled
with `as64 --relax`, linked once with relaxation and once with `--no-relax` (which is the plain link).  Scripts: `scratchpad/ld/run6r.py`, `corpus.py`, `runsmall2.py` of the session.

### 7.1 The six programs (lz4, zlib, Lua 5.4.7, BearSSL hash, symmetric, elliptic-curve kernels; with the stand-in libc and crt)

Text segment of the linked image, bytes (the data segment is the same in both; the file is padded to pages, so its length does not change):

| program | pdp64/16 unrelaxed | relaxed | saved | pdp64/32 unrelaxed | relaxed | saved |
|---|---:|---:|---:|---:|---:|---:|
| lz4 | 19,408 | 19,200 | 208 (1.07%) | 19,856 | 19,656 | 200 (1.01%) |
| zlib | 48,586 | 48,302 | 284 (0.58%) | 49,684 | 49,384 | 300 (0.60%) |
| Lua | 94,140 | 91,634 | 2,506 (2.66%) | 96,784 | 94,406 | 2,378 (2.46%) |
| bs_hash | 11,520 | 11,336 | 184 (1.60%) | 11,988 | 11,812 | 176 (1.47%) |
| bs_sym | 16,216 | 16,056 | 160 (0.99%) | 17,320 | 17,144 | 176 (1.02%) |
| bs_ec | 13,314 | 13,060 | 254 (1.91%) | 14,004 | 13,742 | 262 (1.87%) |
| **all six** | 203,184 | 199,588 | **3,596 (1.77%)** | 209,636 | 206,144 | **3,492 (1.67%)** |

Where the bytes came from (all six, pdp64/16; sites are instructions with a relocation; the 32-register figures are within 3%):

| category | sites | bytes before | after | change |
|---|---:|---:|---:|---:|
| `call`/`movcall` to another input section (external) | 1,920 | 11,520 | 8,248 | **-3,272** |
| `jmp` to another input section | 67 | 402 | 280 | -122 |
| `lea` of a code symbol (a function address) | 807 | 3,298 | 3,236 | -62 |
| conditional branches and `sob` (they were local; shorter once the calls between them shrank) | 8,949 | 26,206 | 26,148 | -58 |
| pc-relative operand of another instruction (loads of data, pool) | 253 | 1,224 | 1,178 | -46 |
| `lea` of a data or bss symbol | 109 | 654 | 620 | -34 |
| `call`, `jmp` to the same input section | 2,493 | 9,972 | 9,972 | 0 |
| other (absolute operands, ALU with a symbol) | 131 | 548 | 548 | 0 |
| **total** | | 54,052 | 50,454 | **-3,598** |

(3,598 against 3,596 above: the 2 bytes are paddings.)  The calls the assembler already knew (the same input section: 4 bytes) do not change.  In these programs most calls are to a function of the same file
and the bytes of external calls are few (1,920 sites in 200 KB), so the saving is 1.8%, not the 9% of the corpus below.

Executed bytes and instructions (`sim64 -P`, whole run, program and libc; the output of every run equals the host build's and the unrelaxed run's):

| program | executed bytes unrelaxed (16) | relaxed | saved | executed instructions unrelaxed / relaxed | 32: bytes saved |
|---|---:|---:|---:|---|---:|
| lz4 | 359,155,688 | 356,587,516 | 0.72% | 134,036,776 / 134,036,776 | 0.75% |
| zlib | 423,680,070 | 423,552,972 | 0.03% | 157,363,476 / 157,363,476 | 0.03% |
| Lua | 425,150,938 | 423,050,248 | 0.49% | 148,660,151 / 148,664,103 | 0.56% |
| bs_hash | 184,334,432 | 183,728,734 | 0.33% | 63,561,746 / 63,561,746 | 0.32% |
| bs_sym | 183,513,414 | 182,884,680 | 0.34% | 72,927,238 / 72,927,238 | 0.30% |
| bs_ec | 185,029,604 | 184,711,882 | 0.17% | 70,602,259 / 70,602,259 | 0.15% |
| **all six** | 1,760,864,146 | 1,754,516,032 | **0.36%** | 647,151,646 / 647,155,598 | 0.37% |

The instruction counts are equal except in Lua (+3,952 relaxed in pdp64/16, -3,430 in pdp64/32): Lua hashes the addresses of its C strings and light functions (`luaS_new`'s cache, the
string table), and the addresses are not the same in the two images; the difference is entirely in `luaH_getshortstr`, `luaS_newlstr`, `luaH_free`, `luaS_newudata`, `memcmp`, `luaS_remove` (10 of 232 functions differ in the profile), and the output is the same.

### 7.2 The 841-file corpus (pcc-enc, one file at a time, with a stub object that defines the symbols the file leaves undefined)

Every external call and every external data symbol of a file is far from the stub only by the size of the file: a file of up to 32 KB has all its `lea` of data in the reach of the 4-byte forms.
The bytes are the file's `.text` (instructions, pools, constants in text and padding).  One file (`pr79286.c`, a constant of 64 bits as a displacement) does not link, with or without relaxation.

| | pdp64/16 | pdp64/32 |
|---|---:|---:|
| files | 840 | 840 |
| text unrelaxed | 1,175,076 | 1,209,256 |
| text relaxed | 1,130,052 | 1,164,178 |
| saved | **45,024 (3.83%)** | **45,078 (3.73%)** |
| without `memcpy-a2.c` (258 KB of text, 12,288 of the 12,787 data `lea`) | 916,960 -> 889,124 (-3.04%) | 948,068 -> 920,188 (-2.94%) |
| external `call`: sites, bytes saved | 20,342, 40,684 (3.46% of the text) | 20,343, 40,686 |
| `lea` of data/bss: sites, bytes saved | 12,787, 1,802 (0.15%) | 12,787, 1,810 |
| pc-relative loads, `movq sym` etc.: bytes saved | 1,604 | 1,410 |
| `jmp` to another section: sites, bytes saved | 364, 728 | 364, 728 |
| branches shortened because the calls between them shrank | 296 | 444 |

The corpus has 20,342 external calls, which cost 6 bytes each (122,052 bytes, 10.4% of the text); the 4-byte form gives back 2 of the 6, a third: the saving is 3.5%.  The 9% the earlier
estimate gave for external calls was the cost of the 6-byte form, not what the 4-byte form saves (the shortest external call is 4 bytes).  The `lea` of data saves 2 bytes a site at most, too.
Of the 12,787 data `lea` sites 12,288 are in `memcpy-a2.c`, a 258 KB text that the 32 KB reach of `lea` cannot span (402 of its sites are near enough and shrink); in the other 839 files all 499 sites shrink from 6 to 4 bytes
(2,994 -> 1,996).  In a program of more than 32 KB of text the data `lea` stays long for the data that lies farther than that, as the six programs show (17 of 109 sites).

### 7.3 Differential execution

* The six programs, 16 and 32 registers: output of the relaxed link, of the unrelaxed link and of the host build identical (12 of 12); `ld64 --no-relax` of the relaxation objects is byte for byte the link of the plain objects (12 of 12).
* c-testsuite (213 programs) and gcc-torture (169), each with the stand-in libc and crt, in 16 and 32 registers: the exit status and the standard output of the relaxed and the unrelaxed link are identical
  for 213 of 213 and 168 of 169 programs, in both encodings (206 and 147 of them exit 0, as before; the 7 and the rest that do not, fail the same way in both).  The one that differs is `pr116799`, a program whose `main`
  returns without a value, so its exit status is whatever `r0` holds, an address (it differs between pdp64/r20, /16 and /32 too, as errata 88 records).  Text of these links, all programs added: 700,604 -> 691,516
  (c-testsuite, pdp64/16), 811,616 -> 786,806 (gcc-torture, 16); 742,856 -> 735,456 and 583,414 -> 577,174 (32).

### 7.4 What the linked programs still have at 6 bytes

In Lua (91,634 bytes of text) 284 `movcall` and 6 `jmp` are 6 bytes: their only 4-byte form has a 16-bit field (reach +-64 KiB), unlike `call` (18 and 20 bits).  In zlib 12 `movcall`.  No `call` is
left long in these programs (7 and 3 indirect calls are not sites).  Beyond 1 MiB a `call` too would stay at 6 bytes (and beyond 2 GiB it cannot be linked).
