# The pdp64 architecture manual

[← pdp64 index](../../README.md)

**A PDF of the whole manual (the chapters, with every instruction, the reference tables and the appendices): [`book/pdp64-manual.pdf`](../../book/pdp64-manual.pdf).**

**This is the manual of the pdp64, a 64-bit architecture with SMP support designed to be efficient with in-order and out-of-order implementations: what it is, why, and how each part works.** It is the statement of the architecture, arranged to be read straight through; every instruction has its complete entry in chapter 9.

## Contents

1. [**Introduction**](01-introduction.md): why the machine exists, what made the PDP-10, PDP-11 and VAX-11 good to program, and the principles the design follows.
2. [**The bus**](02-bus.md): Q64, the address space, what the processor owes the bus, failures, coherence, atomics, and the bus as a device with enumeration and hot-plug.
3. [**Graphics: the terminal and its devices**](03-graphics.md): the terminal, based on the Commodore 64 and the Blit terminal (video, sound and blitter), modernised, as memory-mapped devices, how it drives HDMI and the other ports, the framebuffer, and the question of a standard graphics card. The register-level specification is a stub.
4. [**Boot, the BIOS, the disk label and the GPT**](04-boot.md): what starts the machine, what takes over, how the disk is laid out, and how the kernel is found.
5. [**The device driver model**](05-drivers.md): memory-mapped registers and DMA as a driver sees them, the eight-register convention and its descriptor, the life of a driver, the default devices, errors and recovery.
6. [**The kernel: modes, exceptions and memory management**](06-kernel.md): the status word and the modes, exception and interrupt entry, the vector table, the system registers, the page table, the user-memory guard and the first kernel.
7. [**Multiple processors**](07-smp.md): everything the architecture adds so that a second core is easy: the seventeen operations, the memory model, per-CPU state, translation coherence, waiting and signalling, starting cores.
8. [**Vector work, AI and array languages: the device route**](08-vectors.md): why there is no SIMD register file, and how neural-network inference and the array languages APL and K are served by memory-mapped devices.
9. [**The instruction set**](09-isa.md): how the opcode space is divided, the properties and principles of the architecture, the registers, the format, the addressing modes, and each group of instructions.
10. [**Conclusion: from FPGA to silicon**](10-conclusion.md): the FPGA plan, the transistor budget, the path to an OpenBSD you can log into, and what is still open.
11. [**The instruction reference tables**](dictionary/index.md): the one-parcel second page, the assembler aliases, the architectural constants (status word, vectors, page-table entry, system registers, conditions), and the lists of the mnemonics and the opcodes. The entry for each instruction (syntax, encoding drawing, operation, flags, exceptions) is in chapter 9 in the section of its group, with the atomic instructions in section 7.12 and the system instructions in section 6.7.
12. [**Appendix A. Possible improvements not decided on**](appendix-a-improvements.md): ideas that nobody has turned into a decision, with their benefits and costs.
13. [**Appendix B. Decisions pending**](appendix-b-decisions-pending.md): every open decision with its question, proposed answer, precedent, trade-offs and benefits.
14. [**Appendix C. Glossary**](appendix-c-glossary.md): the manual's terms in one place, by architecture, kernel, devices and process.
15. [**Appendix D. The ABI, version 1**](appendix-d-abi.md): data model, registers, arguments and results, variadic calls, position-independent code.
16. [**Appendix E. The assembly language and the object format**](appendix-e-assembler.md): source syntax, directives, operand modes, the literal pool, and ELF.
17. [**Appendix F. The evidence behind the manual**](appendix-f-evidence.md): the long documents the manual is drawn from: the full instruction-set text, the system and bus documents, the record of decisions, and the surveys and measurements.

## How to read it

**Each section is a few numbered aphorisms followed by a commentary.** The aphorisms say what is true of the machine, in plain short statements, and read on their own as the main text. The commentary under them gives, as they apply: the *Precedent* (what earlier machines did), the *Trade-offs* (what the choice costs), the *Improvements* (how the pdp64 departs from the precedent), the *Benefits*, the *Modern comparables* (what current architectures do), and, for an instruction that is not obvious, its *Use*. Every decision also carries an *Impact* line saying what it means for an efficient **kernel**, for efficient **compilation** and for an efficient **hardware layout**: the three things a processor designer asks of a choice. An instruction as plain as `MOV` or `ADD` needs no statement of use. The reference entries follow the layout of the classic CPU manuals, in which every instruction has its encoding diagram, its operation and its effects.

**Each aphorism carries a status.** *(D)* means decided. *(P)* means a proposal that is not decided. *(S)* means a stub: the statement names what is left unspecified. An aphorism with no tag describes the architecture as it is built and tested.

**Numbers.** Where a figure is measured, the text says what was measured; where it is an estimate, it says so. Claims about other machines are checked against the fact-check record listed in [appendix F](appendix-f-evidence.md).

**The PDF.** The same text as a book, [`book/pdp64-manual.pdf`](../../book/pdp64-manual.pdf), built by [buildabook](https://github.com/moebiusV/buildabook) and Typst from the sources of this directory (`tools/mkbook.sh`; see `book/README.md`).

**Evidence documents.** All of them are listed in [appendix F](appendix-f-evidence.md): the full instruction set text ([`../pdp64-isa.md`](../pdp64-isa.md)), the record of decisions ([`../errata.md`](../errata.md), [`../CHANGES-SINCE-R20.md`](../CHANGES-SINCE-R20.md)) and the open decisions with five options each ([`../decisions-pending.md`](../decisions-pending.md)).
