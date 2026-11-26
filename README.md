# DEC PDP-64

Parent: [All Projects](https://moebiusv.github.io/) | Git Repo: [github.com/moebiusV/pdp64](https://github.com/moebiusV/pdp64) | `git clone https://github.com/moebiusV/pdp64`

**Digital Equity Collective's Pragmatic Digital Processor, 64 bit.**
*A 64-bit successor to the PDP-11 instruction set and architecture.*

*It is a 16-bit-word machine in the PDP-11's sense: a **word** is 16 bits, as it was on the PDP-11, a **long** is 32 bits and a **quad** is 64 bits; the width letters of the notation are `b`, `w`, `l` and `q` (8, 16, 32 and 64 bits), the PDP-11's and the VAX's.*

*It began as a mashup of the PDP-11 and the Commodore 64 with secure extensions, and grew into a 64-bit symmetric-multiprocessing CPU with more security and more convenience: the history is [the evolution of the design](docs/design/evolution.md), a design note outside the manual.*

**The principles every decision is judged by: [read them online](https://moebiusv.github.io/pdp64/docs/principles.html)**, [`docs/principles.md`](docs/principles.md): safety first, then speed measured as run time, then fewer instructions, dense encoding, a good compiler target, and an instruction set pleasant enough to keep in your head.

**The manual: [read it online](https://moebiusv.github.io/pdp64/docs/manual/00-index.html)**, [`docs/manual/`](docs/manual/00-index.md); it is also a book (`book/pdp64.pdf`; hand-written source: [`docs/manual-src/`](docs/manual-src/README.md)). Ten chapters (introduction, bus, graphics, boot, device drivers, kernel, multiple processors, vectors and AI, the instruction set, the path to silicon), every instruction with its own entry in chapter 9 (syntax, encoding drawing, operation, exceptions), the [reference tables](docs/manual/dictionary/index.md) ([online](https://moebiusv.github.io/pdp64/docs/manual/dictionary/index.html)), and five appendices (A to E: improvements, the glossary, the ABI, the assembly language, the evidence).


The PDP-11 and the VAX-11 were pleasant, even fun, to program in assembly language. Afterward computer design went in many directions and that pleasure was largely lost. The pdp64 brings the two machines forward with what fifty years of compilers and operating systems have shown: which instructions get things done and which do not, what a CPU is used for, and which instructions it needs most. The PDP-11 is a source, not an obligation: what earned its place stayed, what did not was dropped, and what fifty years showed to be missing was added. Some of the results are unexpected. A second unsigned multiply is the same instruction as the first, while the high half of the product, which bignums need, is missing. A rotate by a register count has almost no users, because cryptographic code rotates by constants. Division is rare, because compilers turn division by a constant into a multiply. Dedicated absolute-value, minimum and maximum instructions are worth under a tenth of a percent of code. CRC instructions are unnecessary once carry-less multiply exists.

The pdp64 is a 64-bit, little-endian, LP64 architecture with support for several cores, designed to be efficient with in-order and out-of-order implementations. It has 32 general registers; variable-length instructions of 2, 4 or 6 bytes in 16-bit parcels; the PDP-11's orthogonal addressing modes; and a modern base: bit counts, 64-bit divide, IEEE 754 binary64 and binary32 (binary16 for conversion only) with exception flags, block operations, atomics and UTF-8 instructions. It also has instructions for cryptography (rotation and bit reversal, byte swap, carry-less multiply, bit counts, wide multiply) and for inference (the population-count and XNOR instructions that binary and sub-1-bit networks need; see the [LB64 accelerator](docs/pdp64-lb64-accelerator.md)). It has hypervisor support for cloud use, and it supports seL4.

**The pdp64 has 32 registers (`r0`-`r31`) and a prefix-coded instruction encoding** (parcel 0 begins with a variable-length prefix) that adds to the PDP-11 instruction set a few instructions (four fused pairs the compiler emits: `movcall`, `popret`, `popmret`, `mov2`; selects; compare-and-branch in place of condition codes (the machine has no flags); overflow-trapping arithmetic; the AES and SHA words). Its grammar is `spec/pdp64/pdp64.hbnf` (the source of truth; `spec/README.md` says how to change it). There is one CPU, and the tools call it `pdp64`. It is exclusively a 32-register machine: the earlier sixteen-register iterations (the original encoding, r20, and a prefix-coded one, pdp64/16) were built and measured against it, superseded and removed, and no tool has an option that selects another machine. The measured comparison by which the 32-register encoding was chosen is in [`docs/encoding-work/`](docs/encoding-work/README.md), above all `integration.md`; the last commit that carries their manuals and tools is the git tag `pre-single-cpu`, and the last that carries their code is `pre-code-removal`. The manual is [`docs/manual/`](docs/manual/00-index.md); [`docs/manual-update-plan.md`](docs/manual-update-plan.md) records the plan by which it was brought to the new encoding.

The toolchain is written from one source of truth, a set of [hbnf](https://github.com/moebiusV/hbnf) grammars, so that the assembler, linker, emulator, compiler back end and [QEMU](https://www.qemu.org/) target cannot drift apart.

## Design principles

In order of priority (the full statement, with the reason for each, is [`docs/principles.md`](docs/principles.md)):

1. **Security and safety:** errors that can never arise; failing that, errors that are easy to detect; failing that, errors that are cheap to recover from. Restart and recovery go together, and an instruction does what its name says and nothing else.
2. **Speed, measured as actual run time, and power,** served by a low gate count.
3. **Fewer instructions executed, and fewer fetches:** strong proxies for speed, and only proxies; where a measured run time disagrees with a count, run time wins.
4. **Dense encoding:** common instructions short, rare ones longer.
5. **A good compiler target.**
6. **Pleasant in assembler,** which is the same thing as a coherent set a programmer can keep in their head.

Constraints stand beside the ranking. There is one binary on every implementation: nothing is specified that is safe only because a core is in order, narrow or small (a core may speculate, but software always sees sequential consistency). Measure, do not guess. All rules are soft: a rule gives way when breaking it is worth more than it costs. An instruction is judged by its weight in the loops where it is used, not by how rarely it appears. Do not multiply entities without benefit. And prior work and the effort of a change are never a reason.

**Security and safety.** The ideal is an error that can never arise; the next best is one that is easy to detect, and then one that is cheap to recover from. The architecture makes surprises rare and recovery short: at most one memory operand per instruction; a register is always written in full; a plain access works at any address, and one that crosses a page changes nothing if either page faults; every instruction can be restarted after a fault, because exceptions are precise and side effects are deferred, so a fault handler restarts blindly with no instruction-specific cases; an instruction does what its name says and nothing else; exception entry is made in registers and cannot itself fault; and the user-qualified moves (`.U`) make a copy to or from user memory fault cleanly instead of trusting a stray kernel pointer. A mode bit is decided case by case: by default a mode is visible state, and a bit in a register that is saved anyway costs nothing extra (`MMUCTL`, `DIT`).

**Opcode choice and encoding.** The encoding is a prefix code chosen by an optimiser from the compiled corpus: common instructions get short encodings, rare ones long, and the one-parcel forms cover the commonest cases in two bytes. Instructions are chosen so that common jobs take the fewest instructions. The choices are checked against compiled C: on 841 source files (bearssl, mbedtls, lua, zlib and others; 827 that every compiler accepts) the compiler's output, in code and data, is the same size as `gcc -Os` and 7% smaller than `clang -Os` on amd64, with 1.18 and 1.09 times as many (shorter) instructions.

**Speed and power.** Fewer opcodes and addressing modes, and no flags, mean fewer gates, less heat and a higher clock. Instructions are grouped by theme so that one circuit serves a family, and the low bits of an opcode are wired straight to the function they select. Speed comes from instruction choice in the hot loops: system-call entry and exit (exception state in registers, `PUSHX` and `POPX`, banked stack pointers), the context switch, copies to and from user memory, atomics, string and block loops (`MCPY`, `MSCN`) and interrupt entry. The [kernel assembly survey](docs/kernel-asm-survey.md) counts what four kernels write in assembly; its path-length figures (system-call entry in 4 to 5 instructions) are estimates, not measurements.

**The system around the processor.** The bus is PCI Express, backward compatible, with security and convenience circuitry added on the processor side; USB is a standard device (its controller interface is not yet decided), and the disk and the standard network, graphics and audio devices are virtio (the disk is virtio-blk; an NVMe disk may be attached as any PCI Express device may). A driver is small, and the CPU only sets up a transfer. The architecture is the processor, the bus and the devices together; the instruction set is its stable core, and the bus (chapter 2 of [the manual](docs/manual/02-bus.md)) is specified as carefully as the instructions. Open items, with the options weighed against these principles, are in the design notes outside the manual ([`docs/design/open-items.md`](docs/design/open-items.md), items J.n.k).

## What to read

**Start with the manual: [`docs/manual/`](docs/manual/00-index.md)** ([online](https://moebiusv.github.io/pdp64/docs/manual/00-index.html)), the manual of the pdp64. It is the ordered account of the whole architecture as it is to be, with a reference entry for every instruction, reference tables ([the dictionary](docs/manual/dictionary/index.md)), written as numbered statements. What is proposed, deferred, open or waiting for the author is kept outside it, in the [design notes](docs/design/README.md) (Volume II of the book when volumes land). **The map of every document in `docs/`, saying which are current, which are dated records and which are history, is [`docs/README.md`](docs/README.md).** What is decided and what is not is the ledger, [`docs/decisions-and-status.md`](docs/decisions-and-status.md), which is the source of truth that every document and the manual follow; the author's words are the [decision register](docs/decision-register.md). The documents below are the sources the manual is drawn from or companions to it.

1. **The architecture.** [`pdp64-isa.md`](docs/pdp64-isa.md) is the narrative and rationale of the instruction set (the reference is chapter 9 of the manual), [`pdp64-fpga-plan.md`](docs/pdp64-fpga-plan.md) the implementation plan, [`pdp64-lb64-accelerator.md`](docs/pdp64-lb64-accelerator.md) a proposed (not decided) sub-1-bit inference accelerator. The founding documents, as received under the working name 11/64W, are in [`docs/orig/`](docs/orig/).
2. **The system.** [`pdp64-system-architecture.md`](docs/pdp64-system-architecture.md): the System v1 record of privilege, exceptions, interrupts, memory management, boot, and the operating-system port plan (a dated record; chapter 6 of the manual is current). [`pdp64-q64-bus.md`](docs/pdp64-q64-bus.md): the internal design document on the bus, PCI Express and the additions to it that are under consideration (the manual does not use the bus name of this document until they are decided). [`pdp64-system-design.md`](docs/pdp64-system-design.md): the options compared with the PDP-11, VAX, x86-64, AArch64, RISC-V and MIPS, and how each choice measures against the goals. [`pdp64-in-order-and-out-of-order.md`](docs/pdp64-in-order-and-out-of-order.md): what the in-order design point costs and buys, and what out-of-order needs. [`pdp64-ooo-readiness.md`](docs/pdp64-ooo-readiness.md): the review of the instruction set for out-of-order. [Chapter 2 of the manual](docs/manual/02-bus.md): the bus and devices. [`boot.md`](docs/boot.md): how the machine and its other cores start. [`roadmap.md`](docs/roadmap.md): the finish line before silicon (toolchain, emulator, an OpenBSD reachable over ssh) and the order of work.
3. **Compiled C.** [`codegen-analysis.md`](docs/codegen-analysis.md): code size against `gcc -Os` and `clang -Os`, instruction lengths, which instructions are used, cost centres and what each candidate change could save.
4. **Conventions.** [`abi.md`](docs/abi.md): the calling convention. [`asm-syntax.md`](docs/asm-syntax.md): the assembly language. [`sim64.md`](docs/sim64.md): the emulator and its system-call stand-in.
5. **Research reports.** [`kernel-asm-survey.md`](docs/kernel-asm-survey.md): what Linux, FreeBSD, NetBSD and OpenBSD write in assembly. [`kernel-pain-points.md`](docs/kernel-pain-points.md): what hurts kernel developers, from the source trees, mailing lists and papers. [`hardware-vulnerabilities.md`](docs/hardware-vulnerabilities.md): processor, memory and system flaws that needed mitigations, the rules that keep the pdp64 from repeating them, and the evidence on constant-time modes. [`openbsd-mitigations.md`](docs/openbsd-mitigations.md): OpenBSD's exploit mitigations and what the pdp64 gives for free. [`architecture-recommendations.md`](docs/architecture-recommendations.md): changes to the instruction set, modes and devices that the research suggests. [`fact-check-2026-10-22.md`](docs/fact-check-2026-10-22.md): statements about other machines and standards compared with a source.
6. **The record of decisions.** [`errata.md`](docs/errata.md) numbers every decision with the problem, the choice and the reason. [`CHANGES-SINCE-R20.md`](docs/CHANGES-SINCE-R20.md) is the reasoned history of the instruction set's changes. [`handoff.md`](handoff.md) is the working notes: the repositories, the rebuild order, the state and the order of work.
7. **Implementation state.** [`docs/implementation-status.md`](docs/implementation-status.md) is the one place for what the tools, the simulator, QEMU, LLVM and the compiler do or lack today, as against what the architecture decides (the manual does not describe the state of implementations).
8. **Decisions and status.** [`decisions-and-status.md`](docs/decisions-and-status.md) lists each design and implementation choice with its rationale and precedents, and says whether it is done, left to do, rejected or left in the air against the current docs and code. The author's messages it cites are rows [R<n>] of the [decision register](docs/decision-register.md). A plain-text form for choosing among the open options and typing questions, so that decisions can be fed back quickly, is generated into [`docs/feedback/`](docs/feedback/) by the tools of [`tools/feedback/`](tools/feedback/README).
8. **Feedback form.** [`docs/feedback/`](docs/feedback/) holds a plain-text form of the open items, proposals and confirmations for answering in a pager-with-editor; `tools/feedback/mkfeedback.py` generates it and `tools/feedback/ingest.py` reads the answers back (see [`tools/feedback/README`](tools/feedback/README)).

## The toolchain

    spec/       the grammars: the drop-in directory grammars.d/ of numbered parts (the numbers, the syntax, the encoding), its masters pdp64/pdp64.hbnf and pdp64-asm.hbnf, ELF records (elf.hbnf)
    tools/      mkgrammar.py and mkenc.py (the generators), mkmanual.py (the instruction entries of the manual), build-hbnf.sh, build-as64.sh,
                build-sim64.sh, build-pcc.sh, encopt/ (the encoding optimiser), feedback/ (the decision form), the checks (check-all.sh runs them all), pdp64test.sh and pdp64test-all.sh (C programs
                under sim64), pdp64size.sh (code size against other targets), check-drift-enc.py
    as64/       the assembler
    ld64/       the linker (ELF, e_machine 0xF064)
    sim64/      the reference emulator
    common/     the reference executor and the table codec of the encoding, shared by the assembler, the linker, the emulator and QEMU
    tests/      format vectors, syntax cases, assembly and emulator programs with hand-worked expected results, QEMU machine tests
    book/       the sources of the PDF edition of the manual
    docs/       the documents above; docs/manual/ holds the manual of the pdp64 (generated from docs/manual-src/)

The C compiler is the `pdp64` back end of [pcc](https://github.com/moebiusV/pcc), the Portable C Compiler, in `arch/pdp64`.

## Building and checking

    tools/build-hbnf.sh                       the grammar compiler (once)
    tools/check-all.sh                        build as64, ld64, sim64 and run every check
    PCC=../pcc tools/build-pcc.sh       build/pcc/ccom, the compiler (the pcc tree: one machine, no -m machine option)
    tools/pdp64test-all.sh                    the C test programs (963 runs: 107 programs under nine flag sets)
    as64 x.s; ld64 -o x.out x.o; sim64 [-P profile] [--timing=SPEC] x.out      assemble, link, run (there is one target: no option selects an encoding)


`tools/build-hbnf.sh` builds the grammar compiler ([hbnf](https://github.com/moebiusV/hbnf)) in a rootless container. `tools/check-all.sh` then generates the grammars, builds the assembler, linker and emulator and runs every check: syntax cases, assembled programs against hand-worked words, the link test, the codec against the Python model, the drift test (every mnemonic's encoding), the generated-header freshness check, the emulator programs, the timing model, relaxation and the QEMU machine tests. `tools/build-pcc.sh` builds the compiler and `tools/pdp64test-all.sh` runs the C programs under nine flag sets.

## Status

- **Specification:** the manual, the grammars and the research are described above.
- **Assembler, linker, emulator:** the reference executor implements the integer core, bit and block operations, binary64 floating point with exception flags, and the system instructions; the 24 atomic words (two sizes) with the reservation of `LL` and `SC`; the memory escape (`MESC`), the UTF-8 instructions, `MVAL` and `FCLASS32` are specified and not yet implemented.
- **QEMU target:** boots a kernel image and runs the machine tests (see `tools/check-qemu.sh`) and the C test programs (`PDP64RUN=qemu`).
- **Compiler:** all 841 files of the benchmark corpus compile and assemble for the pdp64; the code is 11.0% smaller than the first iteration's on the corpus, and the six large programs execute 24% fewer instructions (`docs/encoding-work/integration.md`).
- **LLVM back end** (now the repository [llvm-pdp64](https://github.com/moebiusV/llvm-pdp64)): a code generator for the pdp64 encoding (scalar code, the check instructions, vector blocks made from loops; stages 1 to 2b), with no integrated assembler yet (`llvm-pdp64/README.md`).
- **Order of work (the author, 2026-11-10):** resolve the open items, starting with those that affect the opcodes; re-run the encoding optimiser; update the grammar; regenerate the assembler tables, the manual and the pcc headers; the tools, pcc, QEMU and the LLVM back end are on the new encoding (`handoff.md`). The opcodes may still change when the open items are decided. The pcc RISC-V back end is a separate project, not part of this one.
- **Tags:** `pre-single-cpu` and `pre-code-removal` keep the manuals, tools and code of the two earlier iterations.
- **Open:** the open items ([`docs/design/open-items.md`](docs/design/open-items.md)), each with its options and their pros and cons (among them the C64- and Blit-derived devices, whose earlier chat is recorded in `docs/c64-devices-from-chat.md`); `docs/decisions-pending.md` is the record of the earlier question list.

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
: the manual in `manual/`; the architecture in [`pdp64-isa.md`](docs/pdp64-isa.md), [`pdp64-fpga-plan.md`](docs/pdp64-fpga-plan.md), [`pdp64-lb64-accelerator.md`](docs/pdp64-lb64-accelerator.md), [`pdp64-system-architecture.md`](docs/pdp64-system-architecture.md), [`pdp64-system-design.md`](docs/pdp64-system-design.md), [`pdp64-in-order-and-out-of-order.md`](docs/pdp64-in-order-and-out-of-order.md), [`pdp64-ooo-readiness.md`](docs/pdp64-ooo-readiness.md), [`boot.md`](docs/boot.md), [`roadmap.md`](docs/roadmap.md); conventions in [`abi.md`](docs/abi.md), [`asm-syntax.md`](docs/asm-syntax.md), [`sim64.md`](docs/sim64.md); research in [`kernel-asm-survey.md`](docs/kernel-asm-survey.md), [`kernel-pain-points.md`](docs/kernel-pain-points.md), [`hardware-vulnerabilities.md`](docs/hardware-vulnerabilities.md), [`openbsd-mitigations.md`](docs/openbsd-mitigations.md), [`architecture-recommendations.md`](docs/architecture-recommendations.md), [`codegen-analysis.md`](docs/codegen-analysis.md); decisions in [`decisions-and-status.md`](docs/decisions-and-status.md), [`decision-register.md`](docs/decision-register.md), [`errata.md`](docs/errata.md); records in [`decisions-pending.md`](docs/decisions-pending.md) and [`CHANGES-SINCE-R20.md`](docs/CHANGES-SINCE-R20.md); the map of all documents [`docs/README.md`](docs/README.md); the founding documents in [`orig/`](docs/orig/).

**Grammars, the single source of truth** (in `spec/`)
: [`grammars.d/`](spec/grammars.d) (every number, the parts), [`pdp64/pdp64.hbnf`](spec/pdp64/pdp64.hbnf) (the encoding), [`pdp64-asm.hbnf`](spec/pdp64-asm.hbnf) (assembly syntax), [`elf.hbnf`](spec/elf.hbnf) (object records).

**Programs**
: [`as64/`](as64/) assembler, [`ld64/`](ld64/) linker, [`sim64/`](sim64/) emulator, [qemu-pdp64](https://github.com/moebiusV/qemu-pdp64) and [llvm-pdp64](https://github.com/moebiusV/llvm-pdp64) (the QEMU and LLVM targets, in repositories of their own), [`tools/`](tools/) generator, builds and checks (`check-all.sh`), [`tests/`](tests/).

**Repositories**
: [moebiusV/pdp64](https://github.com/moebiusV/pdp64) (this repository), [moebiusV/hbnf](https://github.com/moebiusV/hbnf) (grammar compiler), [moebiusV/pcc](https://github.com/moebiusV/pcc) (C compiler with the `pdp64` back end; upstream [PortableCC/pcc](https://github.com/PortableCC/pcc)), [moebiusV/v7unix-toolchain](https://github.com/moebiusV/v7unix-toolchain) (corpus tooling, C tests), [QEMU](https://gitlab.com/qemu-project/qemu) ([qemu.org](https://www.qemu.org/)).
