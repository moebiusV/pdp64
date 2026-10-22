# pdp64 assembly syntax

> Repositories referenced: [moebiusV/pdp64](https://github.com/moebiusV/pdp64) (this one), [moebiusV/hbnf](https://github.com/moebiusV/hbnf) (the grammar compiler),
> [moebiusV/pcc](https://github.com/moebiusV/pcc) (the C compiler; upstream [PortableCC/pcc](https://github.com/PortableCC/pcc)),
> [moebiusV/v7unix-toolchain](https://github.com/moebiusV/v7unix-toolchain) (corpus tooling and C tests), [QEMU](https://gitlab.com/qemu-project/qemu).

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
- **Directives.** `.text .data .bss .globl .comm .byte .word .long .quad .ascii .even .align .space .lpad`. `.word` is 16 bits, `.long` 32, `.quad` 64
  (the ISA's PDP-11 terminology). `.align n` aligns to n bytes (a power of two).
- **Registers.** `r0`..`r15`; `sp` is `r14`, `fp` is `r13`. `pc` and `dp` appear only as a base: `d(pc)`, `d(dp)`.
- **Operand modes** (ISA section 5): `rN`; `#expr`; `@expr`; `expr(rN)` and `(rN)`; `expr(rN)(rX*s)` with `s` 1, 2, 4 or 8; `expr(pc)`; `expr(dp)`;
  `(rN)+` and `(rN)+d`; `-(rN)` and `(rN)-d` (errata 15); a bare expression is a PC-relative reference.
- **Mnemonics** are lowercase (`movq`, `add`, `bne`). A multi-register instruction writes its destination last: `add src, rd`, `xnorpop ra, rb, rd`.
  `cmp` is the exception, `cmp rd, src`, because the encoding computes `rd - src` (errata 13).

What it leaves out of V7 `as`: octal numbers by default, `<string>` and the `'\e` escape, `\/ \< \>` and `[ ]` in expressions, `.if`, `.stabs`,
symbols cut to eight characters.

## SEE ALSO

**Documents** (in `docs/`)
: [`11-64W/11-64W-isa-r20.md`](11-64W/11-64W-isa-r20.md) (the ISA, revision 20),
  [`11-64W-fpga-plan.md`](11-64W/11-64W-fpga-plan.md),
  [`11-64W-lb64-accelerator.md`](11-64W/11-64W-lb64-accelerator.md),
  [`CHANGES-SINCE-R20.md`](CHANGES-SINCE-R20.md) (every change and decision since, with reasons),
  [`errata.md`](errata.md) (decisions 1-26), [`abi.md`](abi.md) (calling convention),
  [`asm-syntax.md`](asm-syntax.md) (assembly language), [`sim64.md`](sim64.md) (emulator),
  [`README.md`](../README.md) (index).

**Grammars, the single source of truth** (in `spec/`)
: [`pdp64-mnemonics.hbnf`](../spec/pdp64-mnemonics.hbnf) (every number), [`pdp64.hbnf.in`](../spec/pdp64.hbnf.in) (bit formats),
  [`pdp64-asm.hbnf`](../spec/pdp64-asm.hbnf) (assembly syntax), [`elf.hbnf`](../spec/elf.hbnf) (object records).

**Programs**
: [`as64/`](../as64/) assembler, [`ld64/`](../ld64/) linker, [`sim64/`](../sim64/) emulator,
  [`tools/`](../tools/) generator, builds and checks (`check-all.sh`), [`tests/`](../tests/).

**Repositories**
: [moebiusV/pdp64](https://github.com/moebiusV/pdp64) (this repository),
  [moebiusV/hbnf](https://github.com/moebiusV/hbnf) (grammar compiler),
  [moebiusV/pcc](https://github.com/moebiusV/pcc) (C compiler with the `pdp64` back end; upstream [PortableCC/pcc](https://github.com/PortableCC/pcc)),
  [moebiusV/v7unix-toolchain](https://github.com/moebiusV/v7unix-toolchain) (corpus tooling, C tests),
  [QEMU](https://gitlab.com/qemu-project/qemu) ([qemu.org](https://www.qemu.org/)).
