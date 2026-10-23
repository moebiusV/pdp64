# DEC PDP-64

**Digital Equity Collective's Pragmatic Digital Processor, 64 bit.**
*A 64-bit successor to the PDP-11 instruction set and architecture.*

**The manual: [read it online](https://moebiusv.github.io/pdp64/docs/manual/00-index.html), or [as a PDF](book/pdp64-manual.pdf)** ([online](https://moebiusv.github.io/pdp64/book/pdp64-manual.pdf)) (source: [`docs/manual/`](docs/manual/00-index.md)). Ten chapters (introduction, bus, graphics, boot, device drivers, kernel, multiple processors, vectors and AI, the instruction set, the path to silicon), every instruction with its own entry in chapter 9 (syntax, encoding drawing, operation, flags, exceptions), the [reference tables](docs/manual/dictionary/index.md) ([online](https://moebiusv.github.io/pdp64/docs/manual/dictionary/index.html)), and appendices on improvements, pending decisions, a glossary, the ABI and the assembly language.


The PDP-11 and the VAX-11 were pleasant, even fun, to program in assembly language. Afterward computer design went in many directions and that pleasure was largely lost. The pdp64 brings the two machines forward with what fifty years of compilers and operating systems have shown: which instructions get things done and which do not, what a CPU is used for, and which instructions it needs most. The PDP-11 is a source, not an obligation: what earned its place stayed, what did not was dropped, and what fifty years showed to be missing was added. Some of the results are unexpected. A second unsigned multiply is the same instruction as the first, while the high half of the product, which bignums need, is missing. A rotate by a register count has almost no users, because cryptographic code rotates by constants. Division is rare, because compilers turn division by a constant into a multiply. Dedicated absolute-value, minimum and maximum instructions are worth under a tenth of a percent of code. CRC instructions are unnecessary once carry-less multiply exists.

The pdp64 is a 64-bit, little-endian, LP64 architecture with support for several cores, designed to be efficient with in-order and out-of-order implementations. It has sixteen general registers; variable-length instructions of 2, 4 or 6 bytes in 16-bit parcels, plus a second page of one-parcel abbreviations of the common cases; the PDP-11's orthogonal addressing modes; and a modern base: bit counts, 64-bit divide, IEEE 754 binary64, binary32 and binary16 with exception flags, block operations, atomics and UTF-8 instructions. It also has instructions for cryptography (rotation and bit reversal, byte swap, carry-less multiply, bit counts, wide multiply) and for inference (the population-count and XNOR instructions that binary and sub-1-bit networks need; see the [LB64 accelerator](docs/pdp64-lb64-accelerator.md)).

The toolchain is written from one source of truth, a set of [hbnf](https://github.com/moebiusV/hbnf) grammars, so that the assembler, linker, emulator, compiler back end and [QEMU](https://www.qemu.org/) target cannot drift apart.

## Design principles

In order of priority:

1. **Code size.**
2. **Easy recoverability:** fewer possible errors and an easier recovery path, so less recovery code.
3. **Speed and efficiency through fewer gates and tighter hot loops,** by careful choice of instructions.

All rules are soft: a rule gives way when breaking it is worth more than it costs. The first implementations are in order, and nothing is specified that is safe only because the core does not speculate. An instruction is judged by its weight in the loops where it is used, not by how rarely it appears.

**Code size.** The opcode map is sorted by frequency: common instructions get short encodings, rare ones long, and a second page of one-parcel abbreviations covers the commonest forms in two bytes. Instructions are chosen so that common jobs take the fewest instructions. The choices are checked against compiled C: on 841 source files (bearssl, mbedtls, lua, zlib and others; 827 that every compiler accepts) the compiler's output, in code and data, is the same size as `gcc -Os` and 7% smaller than `clang -Os` on amd64, with 1.18 and 1.09 times as many (shorter) instructions.

**Easy recoverability.** Fewer possible errors means less recovery code, and an easier recovery path means less recovery code. The architecture makes surprises rare and recovery short: at most one memory operand per instruction; a register is always written in full; quad accesses are naturally aligned; every instruction can be restarted after a fault, because exceptions are precise and side effects are deferred, so a fault handler restarts blindly with no instruction-specific cases; an instruction does what its name says and nothing else; exception entry is made in registers and cannot itself fault; and a user-memory guard turns a stray kernel pointer into a clean fault. Mode bits are accepted where they keep these benefits (`MMUCTL`, `UA`).

**Speed and efficiency.** Fewer instructions mean fewer gates. Instructions are grouped by theme so that one circuit serves a family, and the low bits of an opcode are wired straight to the function they select. Speed comes from instruction choice in the hot loops: system-call entry and exit (exception state in registers, `PUSHX` and `POPX`, banked stack pointers), the context switch, copies to and from user memory, atomics, string and block loops (`MCPY`, `MSCN`) and interrupt entry. The [kernel assembly survey](docs/kernel-asm-survey.md) counts what four kernels write in assembly; its path-length figures (system-call entry in 4 to 5 instructions) are estimates, not measurements.

**The system around the processor.** Each device (Ethernet, USB, disk) is eight memory-mapped registers in the ordinary address space and moves its data by DMA. A driver is small, and the CPU only sets up a transfer. The architecture is the processor, the bus and the devices together; the instruction set is its stable core, and the bus ([Q64](docs/pdp64-q64-bus.md)) is specified as carefully as the instructions. Open decisions, with the options weighed against these principles, are in [`docs/decisions-pending.md`](docs/decisions-pending.md).

## What to read

**Start with the manual: [`docs/manual/`](docs/manual/00-index.md)** ([online](https://moebiusv.github.io/pdp64/docs/manual/00-index.html)). It is the ordered account of the whole architecture, with a reference entry for every instruction, [reference tables](docs/manual/dictionary/index.md), and the open decisions, written as numbered statements with commentary and an impact line for each. The documents below are the sources it is drawn from.

1. **The architecture.** [`pdp64-isa.md`](docs/pdp64-isa.md) is the instruction set, [`pdp64-fpga-plan.md`](docs/pdp64-fpga-plan.md) the implementation plan, [`pdp64-lb64-accelerator.md`](docs/pdp64-lb64-accelerator.md) the sub-1-bit inference accelerator. The founding documents, as received under the working name 11/64W, are in [`docs/orig/`](docs/orig/).
2. **The system.** [`pdp64-system-architecture.md`](docs/pdp64-system-architecture.md): privilege, exceptions, interrupts, memory management, boot, and the operating-system port plan. [`pdp64-system-design.md`](docs/pdp64-system-design.md): the options compared with the PDP-11, VAX, x86-64, AArch64, RISC-V and MIPS, and how each choice measures against the goals. [`pdp64-in-order-and-out-of-order.md`](docs/pdp64-in-order-and-out-of-order.md): what the in-order design point costs and buys, and what out-of-order needs. [`pdp64-ooo-readiness.md`](docs/pdp64-ooo-readiness.md): the review of the instruction set for out-of-order. [`pdp64-q64-bus.md`](docs/pdp64-q64-bus.md): the bus and devices. [`boot.md`](docs/boot.md): how the machine and its other cores start. [`roadmap.md`](docs/roadmap.md): the finish line before silicon (toolchain, emulator, an OpenBSD reachable over ssh) and the order of work.
3. **Compiled C.** [`codegen-analysis.md`](docs/codegen-analysis.md): code size against `gcc -Os` and `clang -Os`, instruction lengths, which instructions are used, cost centres and what each candidate change could save.
4. **Conventions.** [`abi.md`](docs/abi.md): the calling convention. [`asm-syntax.md`](docs/asm-syntax.md): the assembly language. [`sim64.md`](docs/sim64.md): the emulator and its system-call stand-in.
5. **Research reports.** [`kernel-asm-survey.md`](docs/kernel-asm-survey.md): what Linux, FreeBSD, NetBSD and OpenBSD write in assembly. [`kernel-pain-points.md`](docs/kernel-pain-points.md): what hurts kernel developers, from the source trees, mailing lists and papers. [`hardware-vulnerabilities.md`](docs/hardware-vulnerabilities.md): processor, memory and system flaws that needed mitigations, the rules that keep the pdp64 from repeating them, and the evidence on constant-time modes. [`openbsd-mitigations.md`](docs/openbsd-mitigations.md): OpenBSD's exploit mitigations and what the pdp64 gives for free. [`architecture-recommendations.md`](docs/architecture-recommendations.md): changes to the instruction set, modes and devices that the research suggests. [`fact-check-2026-10-22.md`](docs/fact-check-2026-10-22.md): statements about other machines and standards compared with a source.
6. **The record of decisions.** [`errata.md`](docs/errata.md) numbers every decision with the problem, the choice and the reason. [`CHANGES-SINCE-R20.md`](docs/CHANGES-SINCE-R20.md) is the reasoned history of the instruction set's changes. [`handoff.md`](handoff.md) describes moving the work to another machine: what is not in git, the rebuild order and the state.

## The toolchain

    spec/       the grammars: formats (pdp64.hbnf.in), syntax (pdp64-asm.hbnf), the numbers (pdp64-mnemonics.hbnf), ELF records (elf.hbnf)
    tools/      mkgrammar.py (the generator), mkmanual.py (the instruction entries of the manual), build-hbnf.sh, build-as64.sh,
                build-sim64.sh, build-pcc.sh, the checks (check-all.sh runs them all), pdp64test.sh and pdp64test-all.sh (C programs
                under sim64), pdp64size.sh (code size against other targets), check-drift.py
    as64/       the assembler
    ld64/       the linker (ELF, e_machine 0xF064)
    sim64/      the reference emulator
    common/     the reference executor and the field-width calibration shared by the assembler, the emulator and QEMU
    qemu/       the QEMU target sources (the QEMU tree is kept outside this repository)
    llvm/       the LLVM back end sources (the LLVM tree is kept outside this repository)
    tests/      format vectors, syntax cases, assembly and emulator programs with hand-worked expected results, QEMU machine tests
    book/       the sources of the PDF edition of the manual
    docs/       the documents above; docs/manual/ is the manual

The C compiler is the `pdp64` back end of [pcc](https://github.com/moebiusV/pcc), the Portable C Compiler, in `arch/pdp64`.

## Building and checking

`tools/build-hbnf.sh` builds the grammar compiler ([hbnf](https://github.com/moebiusV/hbnf)) in a rootless container. `tools/check-all.sh` then generates the grammars, builds the assembler, linker and emulator and runs every check: format vectors, syntax cases, assembled programs against hand-worked words, the link test, the drift test (every mnemonic's encoding against its number), the generated-header freshness check, the emulator programs and the QEMU machine tests. `tools/build-pcc.sh` builds the compiler and `tools/pdp64test-all.sh` runs the C programs under six flag sets.

## Status

- **Specification:** the manual, the grammars and the research are described above.
- **Assembler, linker, emulator:** the reference executor implements the integer core, bit and block operations, binary64 floating point with flags, and the system instructions; the atomics, the memory escape (`MESC`), the UTF-8 instructions, `MVAL` and `FCLASS32` are specified and not yet implemented.
- **QEMU target:** boots a kernel image and runs the machine tests (53 run, 0 failed, 3 skipped) and 516 C test runs.
- **Compiler:** all 841 files of the benchmark corpus compile and assemble; the code is the size of `gcc -Os`.
- **LLVM back end:** the machine-code layer (assembler, disassembler, ELF object writer); no code generator yet.
- **Open:** the register-level specification of the C64- and Blit-derived devices, and the decisions in `docs/decisions-pending.md`.

## Licence

BSD 2-clause, for everything in this repository: see [`COPYING`](COPYING).

## Repositories

| Repository | What it is here |
|---|---|
| [moebiusV/pdp64](https://github.com/moebiusV/pdp64) | this repository: the specification, documents, assembler, linker, emulator, tests and the QEMU and LLVM target sources |
| [moebiusV/hbnf](https://github.com/moebiusV/hbnf) | the grammar compiler; every parser, encoder and header here is generated by it |
| [moebiusV/pcc](https://github.com/moebiusV/pcc) | the Portable C Compiler with the `pdp64` back end (`arch/pdp64`); upstream is [PortableCC/pcc](https://github.com/PortableCC/pcc) |
| [moebiusV/v7unix-toolchain](https://github.com/moebiusV/v7unix-toolchain) | the PDP-11 and V7 Unix toolchain; its benchmark corpus tooling and C test programs are used by `tools/pdp64size.sh` and `tools/pdp64test-all.sh` |
| [QEMU](https://gitlab.com/qemu-project/qemu) | the emulator the target is written for (release 11.1.2) |

## SEE ALSO

**Documents** (in `docs/`)
: the manual in `manual/`; the architecture in [`pdp64-isa.md`](docs/pdp64-isa.md), [`pdp64-fpga-plan.md`](docs/pdp64-fpga-plan.md), [`pdp64-lb64-accelerator.md`](docs/pdp64-lb64-accelerator.md), [`pdp64-q64-bus.md`](docs/pdp64-q64-bus.md), [`pdp64-system-architecture.md`](docs/pdp64-system-architecture.md), [`pdp64-system-design.md`](docs/pdp64-system-design.md), [`pdp64-in-order-and-out-of-order.md`](docs/pdp64-in-order-and-out-of-order.md), [`pdp64-ooo-readiness.md`](docs/pdp64-ooo-readiness.md), [`boot.md`](docs/boot.md), [`roadmap.md`](docs/roadmap.md); conventions in [`abi.md`](docs/abi.md), [`asm-syntax.md`](docs/asm-syntax.md), [`sim64.md`](docs/sim64.md); research in [`kernel-asm-survey.md`](docs/kernel-asm-survey.md), [`kernel-pain-points.md`](docs/kernel-pain-points.md), [`hardware-vulnerabilities.md`](docs/hardware-vulnerabilities.md), [`openbsd-mitigations.md`](docs/openbsd-mitigations.md), [`architecture-recommendations.md`](docs/architecture-recommendations.md), [`codegen-analysis.md`](docs/codegen-analysis.md); decisions in [`decisions-pending.md`](docs/decisions-pending.md), [`errata.md`](docs/errata.md), [`CHANGES-SINCE-R20.md`](docs/CHANGES-SINCE-R20.md); the founding documents in [`orig/`](docs/orig/).

**Grammars, the single source of truth** (in `spec/`)
: [`pdp64-mnemonics.hbnf`](spec/pdp64-mnemonics.hbnf) (every number), [`pdp64.hbnf.in`](spec/pdp64.hbnf.in) (bit formats), [`pdp64-asm.hbnf`](spec/pdp64-asm.hbnf) (assembly syntax), [`elf.hbnf`](spec/elf.hbnf) (object records).

**Programs**
: [`as64/`](as64/) assembler, [`ld64/`](ld64/) linker, [`sim64/`](sim64/) emulator, [`qemu/`](qemu/) and [`llvm/`](llvm/) targets, [`tools/`](tools/) generator, builds and checks (`check-all.sh`), [`tests/`](tests/).

**Repositories**
: [moebiusV/pdp64](https://github.com/moebiusV/pdp64) (this repository), [moebiusV/hbnf](https://github.com/moebiusV/hbnf) (grammar compiler), [moebiusV/pcc](https://github.com/moebiusV/pcc) (C compiler with the `pdp64` back end; upstream [PortableCC/pcc](https://github.com/PortableCC/pcc)), [moebiusV/v7unix-toolchain](https://github.com/moebiusV/v7unix-toolchain) (corpus tooling, C tests), [QEMU](https://gitlab.com/qemu-project/qemu) ([qemu.org](https://www.qemu.org/)).
