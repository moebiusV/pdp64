# DEC PDP-64

**Digital Equity Collective's Pragmatic Digital Processor, 64 bit.**
*An update and refresh of the PDP-11 instruction set and architecture for the modern world.*

The PDP-11 and the VAX-11 were famous for being pleasant, even fun, to program in assembly language. Afterward computer design went in many directions, and
that fun was largely lost. This project brings them forward with the lessons of the last fifty years: which instructions are needed to get things done and which
are not, what a CPU is actually used for, and which instructions it needs the most. The PDP-11 is a source, not an obligation: what earned its place stayed, what
did not was dropped, and what fifty years showed to be missing was added. Some of the answers were surprising. A second unsigned multiply turned out to be the same
instruction as the first, while the high half of the product, which bignums need, was missing. A rotate by a register count has almost no users, because crypto
rotates by constants; a divide is rare, because compilers turn division by a constant into a multiply; dedicated absolute-value, minimum and maximum instructions are
worth under a tenth of a percent of code; and CRC instructions are unnecessary once carry-less multiply exists.

The design was optimized in layers. The first layer is gate count. Fewer instructions mean fewer gates, and the instructions are grouped by common theme so that
one circuit serves a whole family of them. Their layout puts the common instructions in the short encodings and the rare ones in the long: the opcode map is sorted by
frequency, and the low bits of an opcode are wired straight to the function it selects. The second layer is code count: the instructions are chosen so that the
common jobs take the fewest instructions, and the architecture is set up so that surprises and failure modes happen less often, and when one does happen the code
that recovers is shorter and simpler. That is why there are no mode bits, at most one memory operand per instruction, a register is always written in full, quad
accesses are naturally aligned, every instruction can be restarted after a fault, and an instruction does what its name says and nothing else. The third layer is the
system around the processor. Each device (Ethernet, USB, disk) is presented as eight memory-mapped registers, eight addresses in the ordinary address space, and moves
its data by DMA. That makes a driver trivial to write and keeps the multitasking burden off the CPU, which only sets up a transfer, so that more of it is left for you
and for the important things you are running. The architecture is the processor, the bus and the devices together; the instruction set is its stable core, and the bus ([Q64](docs/pdp64-q64-bus.md)) is specified as carefully as the instructions. The choices were checked against compiled C, not
guessed: on 841 real source files (bearssl, mbedtls, lua, zlib and others) the first compiler's output is about 3% smaller than amd64's and 11% smaller than aarch64's
in code and data, with about the same number of instructions.

A 64-bit, little-endian, LP64 successor to the PDP-11: sixteen general registers, variable-length instructions of 2, 4, 6 or 8 bytes in 16-bit parcels, the
PDP-11's orthogonal addressing modes, and a modern base (bit counts, 64-bit divide, IEEE 754 binary64, binary32 and binary16 with exception flags, block operations,
atomics, UTF-8 instructions). The toolchain here is written from one source of truth, a set of [hbnf](https://github.com/moebiusV/hbnf) grammars, so that the assembler, linker, emulator, compiler
back end and [QEMU](https://www.qemu.org/) target cannot drift apart. It also has optimizations for crypto (bit rotation and reversal, byte swap, carry-less multiply, bit counts, wide multiply) and for AI (the
population-count and XNOR instructions that binary and sub-1-bit inference needs, and the LB64 accelerator companion document).

## What to read, in order

1. **The architecture, updated: [`docs/`](docs/).** The three founding documents with every change and decision since revision 20 applied in
   place and the machine renamed pdp64: [`pdp64-isa.md`](docs/pdp64-isa.md) is the ISA (revision 20, updated 2026-10-21),
   [`pdp64-fpga-plan.md`](docs/pdp64-fpga-plan.md) the implementation plan,
   [`pdp64-lb64-accelerator.md`](docs/pdp64-lb64-accelerator.md) the sub-1-bit inference accelerator. Each ends with its list of changes since r20.
   The documents **as they arrived**, under the working name 11/64W, are kept unedited in [`docs/orig/`](docs/orig/) as the baseline.
2. **The system: [`docs/pdp64-system-architecture.md`](docs/pdp64-system-architecture.md)** (privilege, exceptions, interrupts, memory management, boot, and the Unix/32V port plan) **and the bus: [`docs/pdp64-q64-bus.md`](docs/pdp64-q64-bus.md)** (Q64 and the devices). Both say what is established, decided and open.
3. **Everything decided or changed since, with the reasons: [`docs/CHANGES-SINCE-R20.md`](docs/CHANGES-SINCE-R20.md).** It is the reasoned history of the updates above and the
   record against the baseline; where it disagrees with the original r20 documents, it wins. It holds, in order: where things stand (§1); the design errors found in the ISA (§2); instructions dropped, moved, added or
   changed (§3); what the ISA left unspecified and is now specified (§4); the ABI (§5); the assembly language (§6); the object format (§7); why a grammar is the
   source (§8); errors in our own work, found and fixed (§9); changes to hbnf (§10); the environment (§11); what is still open (§12); an appendix with the
   opcode map (§13); the measurements behind the proposals (§14).
4. **Each decision, numbered: [`docs/errata.md`](docs/errata.md)**, items 1-30, each with the problem, the choice and the reason.
5. [`docs/abi.md`](docs/abi.md): the calling convention (registers, stack, structures, variadic calls). [`docs/asm-syntax.md`](docs/asm-syntax.md): the assembly
   language. [`docs/sim64.md`](docs/sim64.md): the emulator and its system-call stand-in.

## The decisions, and where their reasons are

| Decision | Where |
|---|---|
| The ISA's opcode diagrams are stale; the real count is 55 assigned, one spare ALU slot, 8 reserved (not "56") | errata 1, 2; CHANGES §2 |
| PC-relative addresses are measured from the first parcel of the instruction; branch displacements count parcels | errata 3 |
| `PUSHM`/`POPM` moved to `SOP` with a 16-bit mask immediate (the ISA's place for them cannot hold a mask) | errata 4 |
| `SYS`, `JTAG`, scaled index, `SOB`, `RORI`, `MESC`: the missing bit allocations | errata 5-8, 10, 11 |
| Sub-opcode numbers are assigned in one place and generated everywhere else | errata 9; CHANGES §8 |
| The machine is called pdp64 | errata 12 |
| `CMP` writes the register first and computes `reg - rm`; subtraction sets C on borrow (PDP-11 sense); logic operations leave C | errata 13, 14 |
| Pre-decrement is written `-(rN)` | errata 15 |
| `FRECPED`/`FRSQRTED` dropped (a Newton loop on the existing divide and FMA is enough) | errata 16 |
| IEEE exception flags added: a sticky flag word and one swap instruction `fsflags` | errata 17 |
| Unsigned 64-bit conversions and round-half-away added | errata 18, 19 |
| CRC instructions added, then withdrawn (carry-less multiply suffices) | errata 20 |
| `fcmp` is register-first; `FESC` operand roles fixed | errata 21, 22 |
| Integer `abs`, `min`, `max`, `minu`, `maxu` added | errata 23; CHANGES §14 |
| Floating-point spelling: `fadd` is binary64, `fadd32` binary32, `fadd16` reserved; old spellings stay as aliases | errata 24 |
| `set cc, rd` added; a conditional select is on hold pending evidence | errata 25; CHANGES §14 |
| NaN results are the canonical quiet NaN | errata 26 |
| The first operating system is a port of Unix/32V; OpenBSD follows if an LLVM back end is easy enough; the system architecture document lists what that needs and what is undefined | errata 30; [system architecture](docs/pdp64-system-architecture.md) |
| Devices (Ethernet, USB, disk) are eight memory-mapped registers plus DMA: trivial drivers, no multitasking burden on the CPU; no ISA change, layouts to be written | errata 29; ISA §16 |
| Half precision (binary16) added: 17 `FESC` words, arithmetic and conversions, correctly rounded, with flags | errata 27; CHANGES §14 |
| ABI v1: LP64, signed `char`, `long double` = double, arguments in `r0`-`r5` (floats too), 8-byte stack alignment, no red zone, no leading underscore; variadic calls put every argument in slots | CHANGES §5; abi.md |
| Assembly syntax: C-style numbers, characters and strings; `;` comments; names follow ELF (UTF-8, quoted names, digit-led names); lowercase mnemonics; nothing copied from V7 `as` for its own sake | CHANGES §6; asm-syntax.md |
| An instruction at an odd address is an assembler error (the compiler writes `.even`) | CHANGES, "Toolchain status" |
| The grammar is the single source of truth: numbers live once, in enum rules; the generator writes the rest | CHANGES §8 |
| Open: directed rounding for IEEE arithmetic, half-precision extras (min/max, rounding, int64 conversions, bfloat16), a conditional select, the integer width spelling (`movq` against `mov:l`), linker relaxation, a short `d(sp)` form | CHANGES §12, §14 |

## The toolchain

    spec/       the grammars: formats (pdp64.hbnf.in), syntax (pdp64-asm.hbnf), the numbers (pdp64-mnemonics.hbnf), ELF records (elf.hbnf)
    tools/      mkgrammar.py (the generator), build-hbnf.sh, build-as64.sh, build-sim64.sh, build-pcc.sh, the checks (check-all.sh runs them all),
                pdp64test.sh / pdp64test-all.sh (C programs under sim64), pdp64size.sh (code size against other targets), check-drift.py
    as64/       the assembler
    ld64/       the linker (ELF, e_machine 0xF064)
    sim64/      the reference emulator (user mode)
    common/     field-width calibration shared by the assembler and the emulator
    tests/      format vectors, syntax cases, assembly and emulator programs with hand-worked expected results
    docs/       the documents above
    qemu/       the QEMU target (under way; the QEMU source tree itself is kept outside this repository)

The C compiler is the `pdp64` back end of [pcc](https://github.com/moebiusV/pcc) (the Portable C Compiler), in `arch/pdp64`.

## Building and checking

`tools/build-hbnf.sh` builds the grammar compiler ([hbnf](https://github.com/moebiusV/hbnf)) in a rootless container; `tools/check-all.sh` then generates the grammars, builds
the assembler, linker and emulator and runs every check: format vectors, syntax cases, assembled programs against hand-worked words, the link test, the drift
test (every mnemonic's encoding against its number), the generated-header freshness check, and the emulator programs. `tools/build-pcc.sh` builds the compiler
and `tools/pdp64test-all.sh` runs 81 C programs under six flag sets.

## Status (2026-10-21)

Assembled: 196 words (all but `ATOM`, `MESC` and `trapl`). Emulated: the integer core, bit and block operations, binary64 floating point with flags; not yet:
`btag`, `extb`/`insb`, binary32, atomics, privileged instructions. Compiler: all 841 files of the benchmark corpus compile and assemble; 1.03 times amd64's
instructions and 0.97 times its bytes; 486 of 486 C test runs pass. See CHANGES §14 for the numbers and what they say.

## Repositories

| Repository | What it is here |
|---|---|
| [moebiusV/pdp64](https://github.com/moebiusV/pdp64) | this repository: the specification, documents, assembler, linker, emulator, tests, and the QEMU target sources |
| [moebiusV/hbnf](https://github.com/moebiusV/hbnf) | the grammar compiler; every parser, encoder and header here is generated by it |
| [moebiusV/pcc](https://github.com/moebiusV/pcc) | the Portable C Compiler with the `pdp64` back end (`arch/pdp64`); upstream is [PortableCC/pcc](https://github.com/PortableCC/pcc) |
| [moebiusV/v7unix-toolchain](https://github.com/moebiusV/v7unix-toolchain) | the PDP-11 and V7 Unix toolchain; its benchmark corpus tooling and C test programs (`a64tests`) are borrowed by `tools/pdp64size.sh` and `tools/pdp64test-all.sh` |
| [QEMU](https://gitlab.com/qemu-project/qemu) | the emulator the target is written for (release 11.1.2); its source tree is kept outside this repository |

## SEE ALSO

**Documents** (in `docs/`)
: Updated architecture: [`pdp64-isa.md`](docs/pdp64-isa.md) (the ISA), [`pdp64-fpga-plan.md`](docs/pdp64-fpga-plan.md),
  [`pdp64-lb64-accelerator.md`](docs/pdp64-lb64-accelerator.md), [`pdp64-q64-bus.md`](docs/pdp64-q64-bus.md) (the bus and devices), [`pdp64-system-architecture.md`](docs/pdp64-system-architecture.md) (privilege, exceptions, memory management, boot);
  history and decisions: [`CHANGES-SINCE-R20.md`](docs/CHANGES-SINCE-R20.md) (every change since, with reasons), [`errata.md`](docs/errata.md) (decisions 1-30);
  conventions: [`abi.md`](docs/abi.md) (calling convention), [`asm-syntax.md`](docs/asm-syntax.md) (assembly language), [`sim64.md`](docs/sim64.md) (emulator);
  baseline as received (working name 11/64W): [`orig/`](docs/orig/); index: [`README.md`](README.md).

**Grammars, the single source of truth** (in `spec/`)
: [`pdp64-mnemonics.hbnf`](spec/pdp64-mnemonics.hbnf) (every number), [`pdp64.hbnf.in`](spec/pdp64.hbnf.in) (bit formats),
  [`pdp64-asm.hbnf`](spec/pdp64-asm.hbnf) (assembly syntax), [`elf.hbnf`](spec/elf.hbnf) (object records).

**Programs**
: [`as64/`](as64/) assembler, [`ld64/`](ld64/) linker, [`sim64/`](sim64/) emulator,
  [`tools/`](tools/) generator, builds and checks (`check-all.sh`), [`tests/`](tests/).

**Repositories**
: [moebiusV/pdp64](https://github.com/moebiusV/pdp64) (this repository),
  [moebiusV/hbnf](https://github.com/moebiusV/hbnf) (grammar compiler),
  [moebiusV/pcc](https://github.com/moebiusV/pcc) (C compiler with the `pdp64` back end; upstream [PortableCC/pcc](https://github.com/PortableCC/pcc)),
  [moebiusV/v7unix-toolchain](https://github.com/moebiusV/v7unix-toolchain) (corpus tooling, C tests),
  [QEMU](https://gitlab.com/qemu-project/qemu) ([qemu.org](https://www.qemu.org/)).
