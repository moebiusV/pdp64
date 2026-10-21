# pdp64

A 64-bit PDP-11. Architecture documents in `docs/11-64W/` (ISA revision 20). This repository holds the machine-readable specification and,
as they are written, the tools built from it:

    spec/pdp64.json     the encoding, the single source of truth
    tools/specgen.py    checks the spec and generates C tables (`specgen.py check | c | map`)
    docs/errata.md      what writing the spec found wrong or open in the ISA document, and what the spec decided

Planned (see the plan in the toolchain notes): `sim64` reference simulator, `as64` assembler and `ld64` linker (forks of the C ports of the V7 `as`
and `ld`), the pcc back end (`~/claude/pcc/arch/pdp64`), and a QEMU target.
