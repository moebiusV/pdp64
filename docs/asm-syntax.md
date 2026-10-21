# pdp64 assembly syntax

The grammar is `spec/pdp64-asm.hbnf` (hbnf text rules; `tools/check-asmsyntax.sh` generates the parser and runs `tests/asmsyntax.c`).
It is the syntax of the V7 assembler, `as`, with the pdp64 operand modes:

- statements end at a newline or `;`; `/` starts a comment; `name:` defines a label; `1:` a local label, referenced `1b` (back) and `1f` (forward);
  `name = expr` assigns; strings are `<...>`; `.text .data .bss .globl .comm .byte .word .long .quad .even .align .space .ascii .lpad .org .section`
  (`.word` is 16 bits, `.long` 32, `.quad` 64, as in the ISA's PDP-11 terminology).
- operand modes (ISA section 5): `rN`, `sp` (R14), `fp` (R13); `#expr`; `@expr`; `expr(rN)` and `(rN)`; `expr(rN)(rX*s)` with `s` 1, 2, 4, 8;
  `expr(pc)`; `expr(dp)`; `(rN)+` and `(rN)+d`; `-(rN)` and `(rN)-d` (errata 15); a bare expression is a PC-relative reference, as in V7.
- mnemonics are lowercase (`movq`, `add`, `bne`, `besc` groups by their own names, ISA section 4); hbnf does not yet allow numbered enum values under
  case-insensitive matching.

Differences from V7 `as`: numbers are C-style (decimal, `0x` hex, `0b` binary), not octal-by-default with a trailing dot for decimal;
the character `'x` is written `'x'`... (see the grammar); registers are `r0`..`r15`, not `r0`..`r7`.
