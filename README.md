# pdp64

A 64-bit PDP-11. The architecture documents are in `docs/11-64W/` (ISA revision 20, written under the working name 11/64W), kept as they arrived.
`docs/CHANGES-SINCE-R20.md` records everything decided or changed since: read that first.

The numbers of the architecture are written once, in the enum rules of `spec/pdp64-mnemonics.hbnf`; the bit formats and the assembly syntax are
hbnf grammars (`spec/pdp64.hbnf.in`, `spec/pdp64-asm.hbnf`); everything else is generated from or measured against them.

    spec/       the grammars (formats, syntax, mnemonics, ELF records)
    tools/      mkgrammar.py (the generator), build-hbnf.sh, build-as64.sh, and the checks (check-all.sh runs every one)
    as64/       the assembler: glue between the generated parsers and the object file
    tests/      format vectors, syntax cases, and assembly programs with hand-worked expected words
    docs/       errata.md (decisions against the ISA), abi.md, asm-syntax.md, CHANGES-SINCE-R20.md

Planned, not written: `sim64` (reference emulator), `ld64` (linker), the pcc back end (`~/claude/pcc/arch/pdp64`), a QEMU target.
