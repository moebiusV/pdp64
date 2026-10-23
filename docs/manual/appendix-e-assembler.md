# Appendix E. The assembly language and the object format

[← manual index](00-index.md)

**The assembler's source layout is the V7 assembler's, `as`; its lexical rules are C's.** This appendix is the syntax of a source file: lines, labels, numbers, strings, operators, directives, registers, the operand modes, the mnemonic conventions and the object format. The grammar itself is `spec/pdp64-asm.hbnf` (the machine-readable specification, whose text rules are checked by `tools/check-asmsyntax.sh`); the source of this appendix is [`../asm-syntax.md`](../asm-syntax.md). The mnemonics are in the [instruction dictionary](dictionary/index.md).

The grammar is `spec/pdp64-asm.hbnf` ([hbnf](https://github.com/moebiusV/hbnf) text rules); `tools/check-asmsyntax.sh` generates the parser and runs `tests/asmsyntax.c` over it,
and `tools/check-as64.sh` assembles `tests/asm/*.s` and compares the bytes with hand-worked expectations.

The layout of a source file is the V7 assembler's, `as`; the lexical rules are C's.

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
- **Registers.** `r0`..`r15`; `sp` is `r14`, `fp` is `r13`. `pc` and `dp` appear only as a base: `d(pc)`, `d(dp)`.
- **Operand modes** (ISA section 5): `rN`; `#expr`; `@expr`; `expr(rN)` and `(rN)`; `expr(rN)(rX*s)` with `s` 1, 2, 4 or 8; `expr(pc)`; `expr(dp)`;
  `(rN)+` and `(rN)+d`; `-(rN)` and `(rN)-d` (errata 15); a bare expression is a PC-relative reference.
- **Mnemonics** are lowercase (`movq`, `add`, `bne`). A multi-register instruction writes its destination last: `add src, rd`, `xnorpop ra, rb, rd`.
  `cmp` is the exception, `cmp rd, src`, because the encoding computes `rd - src` (errata 13).
- **Compare and branch.** `cbCC rd, #imm, label` compares `rd` with a 5-bit signed immediate (-16 to 15) and branches on the condition: `cbeq r3, #5, label`. The mnemonics are `cbne cbeq cbpl cbmi cbvc cbvs cbcc cbcs cbge cblt cbgt cble cbhi cblos` and the aliases of the branch group (ISA §4.4.1). With a register as the second operand, `cbCC ra, rb, label` compares two registers (`cbeq r1, r2, label`, ISA §4.4.1), in four bytes or, beyond 4 KB, six.
  `rori32 rs, #n, rd` rotates the low 32 bits right and sign-extends the result (ISA §4.6). The immediate of `cbCC` may be up to 16 bits (`cbeq r3, #255, label`); the assembler chooses the four-byte, the wide or the long encoding, and refuses a wide immediate whose target is more than 64 KB away (ISA §4.4.1).
- **Literal pool: `=expr`.** An operand written with a leading `=` is **syntactic sugar for a pooled constant, and nothing else**: `movq =0x123456789ABC, r1` puts the 64-bit value in the literal pool and loads it with
  one PC-relative `movq`. It is accepted where a quad memory source is (`movq`, `push`, the ALU group with the register first for `cmp`: `cmp rd, =K`, and the floating-point ALU ops), and refused for sized moves, shifts, stores,
  `lea` and a relocatable symbol. `=` always pools, even a small value; use `#imm` for a constant that fits the signed 32-bit field. A bare `#K` that does not fit that field is an **error** ("use =K to load it from the literal pool"):
  the assembler never pools silently. Entries are 8 bytes, 8-byte aligned, one per distinct value per pool, in order of first use, emitted into `.text` at the end of the section or at the directive **`.pool`** (flush now; code must
  jump over a mid-section pool). The `=` marks the sugar on the page, which is why it is allowed (errata 33).
- **Length.** The assembler chooses the shortest encoding, including the one-parcel forms of page 2 (ISA §4.18); those forms have no mnemonics of their own, so `movq (r3), r1` assembles to the one-parcel form when it fits and to the long form when it does not.

- **`llvm-mc`.** The LLVM back end's assembler (`llvm/`, ISA-checked against `as64` by `llvm/check.sh`) accepts this syntax with these exceptions: no literal pool (`=K` and `.pool`), no names that start with a digit, no non-ASCII names, and `.comm` needs its alignment written (`as64` implies 8). `(pc)` and `(dp)` without a displacement are accepted by `as64` (displacement 0) and by `llvm-mc`.
- **Object format.** ELF64, little-endian, `e_machine` 0xF064 (`EM_PDP64`); relocations `R_PDP64_D64`, `R_PDP64_D32`, `R_PDP64_INSN_ABS`, `R_PDP64_INSN_PC`, `R_PDP64_INSN_BR` (`as64/relocs.h`; LLVM: `ELFRelocs/PDP64.def`).

What it leaves out of V7 `as`: octal numbers by default, `<string>` and the `'\e` escape, `\/ \< \>` and `[ ]` in expressions, `.if`, `.stabs`,
symbols cut to eight characters.
