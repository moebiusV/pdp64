# DEC PDP-64

**Digital Equity Collective's Pragmatic Digital Processor, 64 bit.**
*An update and refresh of the PDP-11 instruction set and architecture for the modern world.*

The architecture documents are in `docs/11-64W/` (ISA revision 20, written under the working name 11/64W), kept as they arrived.
`docs/CHANGES-SINCE-R20.md` records everything decided or changed since: read that first. `docs/errata.md` lists each decision made where the ISA was open
or wrong; `docs/abi.md` is the calling convention (LP64, little-endian); `docs/asm-syntax.md` is the assembly language; `docs/sim64.md` the emulator.

The numbers of the architecture are written once, in the enum rules of `spec/pdp64-mnemonics.hbnf`; the bit formats and the assembly syntax are
hbnf grammars (`spec/pdp64.hbnf.in`, `spec/pdp64-asm.hbnf`); everything else is generated from or measured against them, so that nothing drifts.

    spec/       the grammars (formats, syntax, mnemonics, ELF records)
    tools/      mkgrammar.py (the generator), build-hbnf.sh, build-as64.sh, build-sim64.sh, build-pcc.sh, and the checks (check-all.sh runs them all);
                pdp64test*.sh run C programs under sim64, pdp64size.sh measures code size against other targets
    as64/       the assembler: glue between the generated parsers and the object file
    ld64/       the linker (ELF, e_machine 0xF064)
    sim64/      the reference emulator (user mode, a stand-in system-call interface)
    common/     field-width calibration shared by the assembler and the emulator
    tests/      format vectors, syntax cases, assembly programs with hand-worked words, emulator programs with hand-worked results
    docs/       the documents above

The C compiler is the `pdp64` back end of pcc (`arch/pdp64` in moebiusV/pcc). The QEMU target (`qemu/`) is under way.
