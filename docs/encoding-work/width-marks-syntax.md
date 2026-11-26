# Width marks on operands: the syntax, the conflicts, the map (design only)

I write this for someone who knows a little PDP-11 assembly. On the PDP-11 you wrote `MOVB` and the "B" said how much to move. The owner has decided (errata 223, R545) that here the mnemonic names only the operation and the width is a mark on the operand, in bits: `.8 .16 .32 .64`, with `.u8 .u16 .u32` for zero-extending and `.s8 .s16 .s32` as an optional explicit signed spelling. Nothing in the encoding changes; the assembler picks the opcode that exists. Nothing is implemented. I checked the assembler and the grammar, and I built a scratch copy of the parser (not in the repository) to see what lexes.

## 1. The list: every word that carries a width, a precision, a signedness or an extension

Registers first: there is no floating-point register file. A float lives in an ordinary integer register `r0..r31`, so the mark goes on `r1`, not on `f1` (`f1` is not a register; it would be read as a symbol).

| Family | Words today | Count | The operation, and the operand that carries the width |
|---|---|---|---|
| sign-extending move | MOVB MOVW MOVL (MOVQ is the plain move) | 3 | `mov`: the memory operand (load or store); with a register source it is a sign-extend of the low bits of that register |
| zero-extending load | MOVZB MOVZW MOVZL | 3 | `mov` with a `.u` mark on the source |
| user-qualified moves | MOVQ.U MOVL.U MOVW.U MOVB.U MOVZL.U MOVZW.U MOVZB.U | 7 | the same, checked as a user access. The `.U` says who, not how wide: it stays a mnemonic suffix (decision A) |
| byte swap | BSWAPW BSWAPL (BSWAP is 64) | 2 | `bswap`: the register operand, `.16` or `.32` |
| rotate | ROR32 (ROR is 64; ROL an alias) | 1 | `ror`: the register operands, `.32` |
| atomics, 4-byte | CASL SWAPL AADDL AANDL ABISL AXORL AMAXL AMINL AMAXUL AMINUL SCL LLL | 12 | the memory operand `(r).32`. The U of AMAXU/AMINU is a signedness of the comparison, not a width: it stays (decision B) |
| single-precision arithmetic | FADD32 FSUB32 FMUL32 FDIV32 FSQRT32 FMADD32 FNMSUB32 FCLASS32 | 8 | `fadd` etc.: the register operands carry `.32` |
| single sign operations | FABS32 FNEG32 | 2 | aliases of AND and XOR with the constant sign bit: `fabs r1.32, r2` |
| single compare-and-branch | FCBEQ32 FCBNE32 FCBLT32 FCBLE32 FCBOR32 FCBUO32 and the aliases FCBGT32 FCBGE32 | 8 | `fcbeq`: the two registers carry `.32` |
| conversions | FCVTDQ FCVTDQU FCVTQD FCVTQUD FCVTDS FCVTSD FCVTSL FCVTLS FCVTSH FCVTHS FCVTDH FCVTHD FCVTHL FCVTLH | 14 | one `fcvt`; the source and the destination each carry their format (section 4) |

Sum of the words that go: 3+3+7+2+1+12+8+2+8+14 = **60 words**. The owner's "about 37" counted his own list (without the 7 user moves and the 14 conversions, which his text names only as "where a conversion names it"); counted completely it is 60 (46 without the conversions, 39 without the conversions and the user moves).

Words that look sized and are not (they stay): `EXTB EXTZB INSB` (B is bit field, not byte; EXTZB is zero-extending: signedness in the name, decision B), `DIVU MODU MULHU MINU MAXU CBHI CBLOS` (unsigned comparisons or arithmetic: operations), `FCVTDQU/FCVTQUD` (unsigned: carried by the `.u64` mark below, so they are inside the 14), `LEA` (an address, no width), `PUSH POP PUSHM POPM` (64-bit always), `CLZ CTZ CLO CTO POPCNT BITREV XNORPOP` (64 only; no 32 variants exist), `CLMULL CLMULH` (L is low, H is high), `MCPY MSET...` (bytes counted by a register). `ABS MIN MINU MAX MAXU` are being turned into aliases by another agent and are not listed.

The vector words are the one big family I did not fold in: 359 of the 365 `v...` words have a dotted element suffix (`.b .w .l .q .d .f`, `.bu`, and conversions such as `.b.l`, `.l.f`). Those letters name lanes, not an operand, and the letters mean bytes, words, longs, quads: the very meaning the owner left behind. I recommend leaving them for a later decision (decision C). The dot inside their names causes no conflict with marks, because a mark is digits (section 3).

## 2. The syntax

One rule: **a mark is a dot and a width glued to the end of the operand it describes, no space.** It follows the operand's last character, whatever the addressing mode. The assembler's operands today: `#imm`, `@abs`, `(r)+[stride]`, `-(r)`, `(r)-stride`, `(r)(r*s)`, `d(r)(r*s)`, `(r)`, `d(r)`, `(r,r,s)`, `d(r,r,s)`, `r+d`, a bare symbol or expression, `=const`, and a register.

| Operand | Example |
|---|---|
| register | `r1.32` |
| based | `(r1).8`  `8(r1).16`  `(sp).u8` |
| post-increment | `(r1)+.32`  `(r1)+4.32` (the stride 0 or none is the size of the access, so the mark sets the stride: `(r1)+.8` steps by 1) |
| pre-decrement | `-(r1).8`  `(r1)-.8` |
| indexed | `(r1)(r2*4).16`  `8(r1)(r2*4).u16`  `(r1,r2,4).32` |
| absolute, symbol | `@0x100.8`  `msg.u8`  `msg+4.16` |
| pool, pc-relative | `=0x123456789ABC.64` is pointless (a constant has no width); `8(pc).32` is fine |
| immediate | no mark: `#5.8` is refused (a constant is not narrowed by a mark) |

One example for every family (the destination is last):

```
mov   (r1).8, r2          ; load a byte, sign-extend      was MOVB
mov   (r1).u16, r2        ; load 16 bits, zero-extend      was MOVZW
mov   r2, 4(r1).32        ; store the low 32 bits of r2    was MOVL
mov   r1.8, r2            ; sign-extend the low byte       was MOVB r1,r2
mov   r1.u8, r2           ; zero-extend the low byte       was MOVZB r1,r2
mov.u (r1).u8, r2         ; user-space load                was MOVZB.U
mov   (r1)+.16, r2        ; load with post-increment by 2
aadd  r1, (r2).32, r3     ; 4-byte atomic add              was AADDL
cas   r1, (r2).32, r3     ; 4-byte compare-and-swap        was CASL
bswap r1.32, r2           ; swap the bytes of each long    was BSWAPL
ror   r1.32, #5, r2       ; 32-bit rotate                  was ROR32
fadd  r1.32, r2.32        ; single add                     was FADD32 r1,r2
fmadd r1.32, r2.32, r3.32, r4.32   ; was FMADD32
fcbeq r1.32, r2.32, label ; was FCBEQ32
fcvt  r1.64, r2.32        ; double to single               was FCVTDS
```

Marks on the *register* of a move say how much of it counts (a store, a sign-extend); on the memory operand they say how much memory is touched.

## 3. Lexer conflicts

I ran the built `build/as64` (a copy taken before the other agent's change) and a scratch parser with a mark rule added (rule `mark = "." [u|s] (8|16|32|64) !idchar`, optional after an operand).

**There is a real conflict, and it is silent.** In this assembler the dot is an ordinary name character (`.L1`, `foo.bar`, `mcpy.ur`, `movb.u`). So today `movq r1.8, r2` is accepted: `r1.8` is read as a symbol of that name, an absolute load from an undefined external. Likewise `sp.8`, `1f.8`, `0x100.8`, `5.8`, `#5.8`, and `(r1)+.8` (a stride that is the symbol `.8`). The `r1.u8` and `r1.s8` spellings are symbols too. A mark after a closing parenthesis, `(r1).8`, is today a plain error (good: no meaning to collide with).

There are two layers to fix:
1. The names: `symbol` and `rname` must stop before a mark (`*( !mark idchar )`) and not start with one. A name that really ends in `.8 .16 .32 .64 .u8 ...` becomes unwritable without quotes (`"buf.8"`). I grepped the tests and the pcc output: no such name exists.
2. The registers: the words `r1`, `sp` are matched by hbnf's built-in whole-word scanner, which counts `.` and `-` as word characters, so `r1` never matches the front of `r1.8`. This is the same cause as an existing bug I found on the way: `movq r5-8, r2` (documented as a synonym of `-8(r5)`) is rejected, and `sp-8` is read as the symbol `sp` minus 8. Redefining the grammar's `wordchars` does not help (hbnf ignores it unless the grammar defines `word`, which it then renames and breaks). What worked in my scratch parser: a character-level register rule (`0x72 1*DIGIT | 0x73 0x70 ...` followed by a lookahead for a mark). Then `r1.8`, `r10.16`, `sp.8`, `(r1).8`, `8(r1).16`, `(r1)+.32`, `(r1)+4.32`, `-(r1).8`, `(r1)-.8`, `(r1)(r2*4).16`, `(r1,r2,4).16`, `@foo.8`, `foo.8`, `foo+4.16`, `r5+8.16`, `(pc).8`, `fadd r1.32, r2.32, r3.32` all lexed as the intended operand with a mark. Needing care: with no spaces allowed inside a mark, every mark rule must be written with character literals (`0x2E`, `0x38`), since a digit literal such as `"8"` lets the parser skip spaces and accept `.u 8`.

**Not conflicts:** the assembler has no floating-point literals, so `.5` is only a symbol; `0x.8` is an error today; the directives (`.word .byte .align .globl .encode ...`) start a statement, never an operand, and none of their names is digits; `.` alone is the location counter (`. .8` is not valid, `.+8.8` lexes as `.+8` with `.8`); local labels `1:`, `1f`, `1b` are digits-led and `1f.8` splits cleanly; struct offsets are expressions and end before the mark; the existing dotted mnemonics (`mcpy.ur`, `movb.u`, `vadd.b`, `vld.b.l`) end in letters, not digits, so no mnemonic collides with a mark; the vector registers `v0..v15` take no mark.

**Unresolved in my prototype:** the `.u8 .u16 .s8 .s32` spellings were rejected by the scratch parser even with the `u`/`s` written as character codes, while `.8 .16 .32 .64` lexed. I could not tell in the time whether this is my prototype or an hbnf quirk; the implementation must test it first. If it is a quirk, the fallback is `.u8` written as a rule of four whole spellings.

**Where `.s8` is needed:** nowhere in a move, an atomic, a swap, a rotate or a float word, where `.8 .16 .32` are signed by default. It is needed in `fcvt`, where `.32` already means the float format: the 32-bit integer is `.s32`, the unsigned 64-bit is `.u64` (a spelling the owner did not list; decision D). Elsewhere `.s8` is a harmless synonym.

## 4. The map to today's opcodes

Rule for all: the assembler reads the marks, then selects the word. An unmarked operand is 64 bits.

| Written | Becomes | Note |
|---|---|---|
| `mov (r).64` or `mov (r)` | MOVQ | |
| `mov (r).32 / .16 / .8, rd` | MOVL / MOVW / MOVB (load) | signed |
| `mov (r).u32 / .u16 / .u8, rd` | MOVZL / MOVZW / MOVZB | zero-extend |
| `mov rs, (r).32 / .16 / .8` | MOVL / MOVW / MOVB (store) | register is the low bits; `.u` on a store is an error (a store does not extend) |
| `mov rs.8, rd` etc. | MOVB with a register source | `.u8` gives MOVZB |
| `mov.u ...` | the .U word of the same width | |
| `aadd/cas/swap/aand/abis/axor/amax/amin/amaxu/aminu  ..., (r).32, ...`; `sc`, `ll` likewise | the L word | `.64` or none is the plain word; `.8 .16` are errors (no such atomic) |
| `bswap r.16 / .32, rd` | BSWAPW / BSWAPL | none or `.64` is BSWAP |
| `ror rs.32, #n, rd` | ROR32 | register form `ror ra, rb, rd` has no 32 word: `.32` there is an error; `rol` stays an alias |
| `fadd/fsub/fmul/fdiv/fsqrt/fmadd/fnmsub/fclass` with `.32` marks | the 32 word | `.64` or none is the plain word |
| `fabs/fneg r.32, rd` | AND / XOR with the single sign mask | as the aliases do today |
| `fcbCC ra.32, rb.32, label` | FCBCC32 | |
| `fcvt rs.F, rd.G` | FCVTxy | table below |

`fcvt` (the first mark is the source): float formats are `.16 .32 .64`; integers are `.s32`, plain (64-bit signed), `.u64`.

| Source, destination | Word |
|---|---|
| `.64`, plain | FCVTDQ |
| `.64`, `.u64` | FCVTDQU |
| plain, `.64` | FCVTQD |
| `.u64`, `.64` | FCVTQUD |
| `.64`, `.32` | FCVTDS |
| `.32`, `.64` | FCVTSD |
| `.32`, `.s32` | FCVTSL |
| `.s32`, `.32` | FCVTLS |
| `.32`, `.16` | FCVTSH |
| `.16`, `.32` | FCVTHS |
| `.64`, `.16` | FCVTDH |
| `.16`, `.64` | FCVTHD |
| `.16`, `.s32` | FCVTHL |
| `.s32`, `.16` | FCVTLH |

Errors, each a plain message, no suggestion of an old spelling: a width the operation does not have (`aadd ... (r).16`, `bswap r.8`, `fadd r.16`); marks that disagree across the operands of one float word (`fadd r1.32, r2.64`); a float word with an unmarked register and another marked (`fadd r1.32, r2`: the unmarked one is 64, so a mismatch too); `fcvt` between equal formats or two integers; a mark on an immediate or a literal-pool constant; `.u` on a store; a mark on the destination register of a load, `mov (r1).8, r2.8`: **refuse** (the register is always written in full; accepting it would suggest a partial write, which the architecture has none of); a mark on a register where the operation does not look at its width (`add r1.8, ...`).

Two-byte forms (hot registers, small displacements) and the choice among 2, 4, 6 and 10 bytes are decided by the operands as now; a mark only decides the opcode and, for `(r)+` and `-(r)` with no stride, the stride.

## 5. Defaults

An unmarked memory operand in a move is 64 bits (MOVQ). `mov r1, r2` is the plain 64-bit move; only a marked register source (`r1.8`) is the narrow conversion. `push r1` and `pop r1` are 64-bit and stay so: there is no sized push and I would refuse a mark on them. The default stride of `(r)+` is the size of the access, so `mov (r1)+.8, r2` steps by one, `mov (r1)+, r2` by eight. Atomic default: 8 bytes.

## 6. What else changes

- **as64** (`as64/asmenc.c`, `as64/as64.c`, `as64/asmir.h`, the tree walk in `as64/asmp.c`): the operand structure gets a width and a signedness; a table maps (mnemonic, width) to the word. About 300 lines. The grammar: `60-asm-syntax.hbnf`, the 5 core words (`30-mn-core.hbnf`), `80-mn-ext.hbnf` and the generated names lose 60 words; the old words stay in the encoding tables as internal names (no encoding change), which is the cheap route.
- **Disassembler** `tools/encdis.c` (185 lines): it prints operands in one function per operand kind; add the mark to each memory and register kind and print one word plus marks. Its `-a` round-trip mode must print the marked form. About 60 lines.
- **LLVM** (`../llvm-pdp64`): `PDP64AsmPrinter.cpp` and the instruction definitions in `target/PDP64/PDP64InstrInfo.td` (31 lines name a sized word), the generated `PDP64GenMnemonics.td` and `frozen-M1/.../PDP64InstrDefs.td` (written by `tools/gen-llvm-td.py`). The printer prints a mark by operand; the parser, if it reads assembly, needs the same rule as the assembler. About 41 definitions to re-spell, none re-numbered.
- **pcc** (`../pcc/arch/pdp64/table.c`, 28 lines with sized names; `local2.c`, 11; `peep.h`, 2787 lines, patterns written as text; `pdp64-names.h`): the emitted format strings change from `movb A,R` to `mov A.8,R`; the peephole patterns match text, so they change too. About 80 changed lines plus the peephole file reviewed.
- **QEMU** (`../qemu-pdp64`): only generated tables name the words; the generator input is the spec, so nothing by hand.
- **Tests** that use an old spelling: 70 files (`tests/sim` 44, `tests/qemu` 11, `tests/asm` 5, `tests/asm-err` 3, `tests/sec-open/sim` 2, one each in `asm-equiv c enc forms relax`); `tools` 32 files; `spec` 10.
- **Manual and annex**: 210 files under `docs/manual` (counting figure sources and generated pages), 353 files under `docs` in all, `docs/asm-syntax.md`, `spec/pdp64/tables.md`, `docs/manual/dictionary/by-mnemonic.md` (generated), and the grammar text in `docs/asm-syntax.md`. The manual change needs `mkbook --check`.

## 7. Risks and recommendation

Risks: (1) the silent acceptance today of `r1.8` as a symbol means that an unmarked-register error never fires until the grammar is changed: the register rule must go in with the mark rule or no mark is ever seen. (2) The `.u`/`.s` spellings lexed badly in my scratch parser. (3) `fcvt` is the only place where `.32` is ambiguous (float or integer), and it needs `.s32` and `.u64`. (4) The hbnf whole-word scanner is also the cause of the `r5-8` bug, so the fix may be shared. (5) pcc's text-matching peephole is the bulk of the work.

Recommendation: do it. The one-mnemonic-per-operation gain is real, the lexer fix is small and local, and the default (64 bits) and the register-written-in-full rule stay the same. Order: lexer and the register rule first, with a test that `r1.8` is never a symbol; then the assembler map; then `encdis`; then LLVM and pcc; the tests and manual last.

## Decisions I need from the owner

A. The user-space qualifier `.U` (7 words): keep as a mnemonic suffix `mov.u`, or an operand mark such as `.user`?
B. Signedness in the names that are not widths (`AMAXU AMINU EXTZB DIVU MODU MINU MAXU MULHU CBHI CBLOS`): leave as operations, as I assumed?
C. The 359 vector words with lane letters `b w l q d f`: leave for later, or move to marks too?
D. `fcvt` needs `.s32` for the 32-bit integer and `.u64` (not in your list) for the unsigned 64-bit; and a plain register means 64-bit integer. Agreed?
E. A mark on a load's destination register: refuse (my choice) or accept and ignore?
F. A name ending in a mark (`buf.8`) must now be quoted; no existing source has one. Agreed?
