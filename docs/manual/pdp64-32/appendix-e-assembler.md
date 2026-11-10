# Appendix E. The assembly language and the object format

[← manual index](00-index.md)

**The assembler's source layout is the V7 assembler's, `as`; its lexical rules are C's.** This appendix is the syntax of a source file: lines, labels, numbers, strings, operators, directives, registers, the operand modes, the mnemonic conventions and the object format. The grammar itself is `spec/pdp64-asm.hbnf`; the source of this appendix is [`../asm-syntax.md`](../../asm-syntax.md). The mnemonics are in the [instruction dictionary](dictionary/index.md).

The grammar is `spec/pdp64-asm.hbnf` ([hbnf](https://github.com/moebiusV/hbnf) text rules).

- **Lines.** One statement to a line. `;` starts a comment that runs to the end of the line.
- **Labels.** `name:` defines a label; `1:` defines a numeric label, referenced as `1b` (the nearest one before) or `1f` (the nearest after).
  `sym = expr` assigns. `.` is the location counter. Names are letters, digits, `_`, `.` and `$` and any non-ASCII code point (`café`, `ループ`); a name may start with a digit as long as the whole bareword is not a number (`3dfx:` is a label; `3`, `0x3d`, `0b101`, `0o17` are numbers; `1f` and `1b` are local
  references), and a bareword of digits only is a numeric local label. Names are case-sensitive and never truncated. ELF symbol names are any bytes, so a name with other characters is written in double quotes (`"odd name!"`). A mnemonic or register name cannot be a label, and neither can `r` followed only by digits: `r16` is an error, not a name (`r2d2` is a name).
- **UTF-8.** A source file is UTF-8, and the parser refuses anything that is not (a stray byte, an overlong form, a surrogate, a truncated sequence),
  in names, strings, characters and comments alike; a NUL byte is refused too. In a string, UTF-8 text is copied as bytes and `\u00e9`, `\U0001F600` are written as UTF-8;
  `'é'` is the code point 0xE9, as is `'\u00e9'`.
- **Numbers and characters** are C's: decimal by default (`010` is ten), `0x`, `0b` or `0o` when asked for; `'a'`, `'\n'`, `'\x41'`, `'\101'`.
- **Strings** are `"text\n"` with C's escapes (`\n \t \r \a \b \f \v \0 \\ \' \" \xHH \ooo`), in `.byte` and `.ascii`.
- **Operators** are C's: `* / % & << >>` and `+ - | ^`, unary `- ~ !`, and parentheses. `/` is division. `*`, `/`, `%`, `&` and the shifts need
  constants; `+` and `-` accept one relocatable symbol, and the difference of two symbols of one section is a constant.
- **Directives.** `.text .data .bss .globl .comm .byte .word .long .quad .ascii .even .align .space .lpad .pool`. `.word` is 16 bits, `.long` 32, `.quad` 64
  (the ISA's PDP-11 terminology). `.align n` aligns to n bytes (a power of two).
- **Registers.** `r0`..`r31`; `sp` is `r14`, `fp` is `r13`. `pc` and `dp` appear only as a base: `d(pc)`, `d(dp)`.
- **Operand modes** (ISA section 5): `rN`; `#expr`; `@expr`; `expr(rN)` and `(rN)`; `expr(rN)(rX*s)` with `s` 1, 2, 4 or 8; `expr(pc)`; `expr(dp)`;
  `(rN)+` and `(rN)+d`; `-(rN)` and `(rN)-d`; a bare expression is a PC-relative reference.
- **Mnemonics** are lowercase (`movq`, `add`, `bne`). A multi-register instruction writes its destination last: `add src, rd`, `xnorpop ra, rb, rd`.
  `cmp` is the exception, `cmp rd, src`, because the encoding computes `rd - src`.
- **Compare and branch.** `cbCC rd, #imm, label` compares `rd` with an immediate and branches on the condition: `cbeq r3, #5, label`; `cbCC ra, rb, label` compares two registers, and `cbeq` and `cbne` against zero have one-parcel forms. The mnemonics are `cbne cbeq cbpl cbmi cbvc cbvs cbcc cbcs cbge cblt cbgt cble cbhi cblos`. The assembler chooses among the one-, two- and three-parcel forms by the size of the immediate and the distance (the widths are in 9.10.4); when no form reaches, a label in another object or an operand pair that no form holds, it writes `cmp` followed by `bCC`, which writes the flags. `rori32 rs, #n, rd` rotates the low 32 bits right and sign-extends the result.
- **Literal pool: `=expr`.** An operand written with a leading `=` is syntactic sugar for a pooled constant and has no other meaning: `movq =0x123456789ABC, r1` puts the 64-bit value in the literal pool and loads it with
  one PC-relative `movq`. It is accepted where a quad memory source is (`movq`, `push`, the ALU group with the register first for `cmp`: `cmp rd, =K`, and the floating-point ALU ops), and refused for sized moves, shifts, stores,
  `lea` and a relocatable symbol. `=` always pools, even a small value; use `#imm` for a constant that fits the signed 32-bit field. A bare `#K` that does not fit that field is an error ("use =K to load it from the literal pool"):
  the assembler never pools silently. Entries are 8 bytes, 8-byte aligned, one per distinct value per pool, in order of first use, emitted into `.text` at the end of the section or at the directive **`.pool`** (flush now; code must
  jump over a mid-section pool). The `=` marks the sugar on the page, which is why it is allowed.
- **Length.** The assembler chooses the shortest form: the first form in the table's order, shorter first and then the order of the catalogue in the grammar, whose fields can hold the operands. Lengths only grow from one pass to the next, and every distance is measured on the layout of the previous pass. The one-parcel forms have no mnemonics of their own, so `movq (r3), r1` assembles to the one-parcel form when it fits and to a longer form when it does not. An unresolved symbol needs a form with a field of 32 bits or more and a relocation; a `movq #imm, rd` whose constant fits no `movq` form is assembled as `movql`.

- **Invocation.** `as64 -m pdp64/r20|pdp64/16|pdp64/32 [-o obj] file.s`: `-m` selects the encoding (the default is `pdp64/r20`; `r20`, `16`, `32` and `old` are accepted) and the object records it in its `e_flags`; `ld64 [-M] [-o out] objects...` refuses to link objects of different encodings. `--stats` prints the instruction counts and bytes, `--dump-lens file` writes the length chosen for every instruction, and `--no-relax` (for `as64` and for `ld64`) gives the plain object and links an object as the assembler laid it out.

- **Words of this CPU.** The qualified moves `movq.u`, `movq.d` and the others of 9.6.7; `trapcc.<cc>`, one parcel with no operand; `movql #imm64, rd`; the fused `movcall rs, rd, label`, `popret rd`, `popmret #mask` and `mov2 ra, rb, rc, rd`, which the assembler never chooses for itself; `pushm`, `popm` and `popmret` take a mask. `(r)+` and `-(r)` without a stride write stride 0, which means the size of the access, and `(r)+8` writes 8. `extb`, `extzb` and `insb` have a 6-bit position and width, so a width of 64 is refused. The 22 meaningless shapes the original assembler accepts (`clr #imm`, `jmp #imm`, a store to an immediate, `lea #imm` and the others) are refused.
- **Relaxation objects.** By default the assembler marks an object (`e_flags` 0x10, `EF_PDP64_RELAX`) and gives every instruction that holds the address of a symbol a relocation, local symbols included, and every padding of `.text` an `R_PDP64_ALIGN` (type 6; addend = padding bytes << 32 | alignment); the linker then gives each such instruction the shortest form that reaches. An object whose `.text` holds a distance that is not a relocation (a difference of two labels used as a number, a `d(pc)` written as a number) is marked `EF_PDP64_NOADJ_TEXT` (0x20) and its `.text` is left alone. A `cbCC` that the assembler expanded to `cmp` and `bCC` stays expanded. `--no-relax` opts out.

- **Object format.** ELF64, little-endian, `e_machine` 0xF064 (`EM_PDP64`); relocations `R_PDP64_D64`, `R_PDP64_D32`, `R_PDP64_INSN_ABS`, `R_PDP64_INSN_PC`, `R_PDP64_INSN_BR` (`as64/relocs.h`; LLVM: `ELFRelocs/PDP64.def`).

What it leaves out of V7 `as`: octal numbers by default, `<string>` and the `'\e` escape, `\/ \< \>` and `[ ]` in expressions, `.if`, `.stabs`,
symbols cut to eight characters.
