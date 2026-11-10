# The pdp64 architecture manual

[← pdp64 index](../../../README.md)

**A PDF of the whole manual (the chapters, with every instruction, the reference tables and the appendices): [`book/pdp64-32.pdf`](../../../book/pdp64-32.pdf).**

**This is the manual of the pdp64, a 64-bit architecture with SMP support designed to be efficient with in-order and out-of-order implementations: what it is, why, and how each part works.** It is the statement of the architecture, arranged to be read straight through; every instruction has its complete entry in chapter 9. This manual describes pdp64/32, which is the pdp64; section 1.8 says how it relates to the encodings tested against it, and the [landing page](../00-index.md) links the three manuals.

## Contents

1. [**Introduction**](01-introduction.md): why the machine exists, what made the PDP-10, PDP-11 and VAX-11 good to program, and the principles the design follows.
2. [**The bus**](02-bus.md): what the Unibus did, and PCI Express, virtio, message-signalled interrupts and the IOMMU explained from it; Q64, the address space, enumeration and hot-plug, DMA and coherence, what the processor owes the bus, failures and atomics.
3. [**Graphics: the terminal and its devices**](03-graphics.md): the history of the display (teletype, escape-code terminal, the Blit, the Commodore 64, VGA and VESA, the GPU) for a reader who knows only the 1970s, scanout and tearing, what made graphics programming annoying, the terminal the author describes (peek/poke text and graphics, glyph slots filled by a TrueType engine), windows from the Blit to rio and NeWS, the audio path and mixers, a c64-mode core, HDMI output, the framebuffer, virtio-gpu, and open sketches of a mashup of GPU, video memory, C64 and Blit. The register-level specification is a stub.
4. [**Boot, the BIOS, the disk label and the GPT**](04-boot.md): what a PDP-11 did (the front panel, the boot ROM, block 0, `boot`, `ODT`), and from it what the PC added (the BIOS, the boot sector, UEFI), what takes the place of a BIOS, the reset state and the first block, the disk (the GPT around the BSD label), the second stage and the boot-information block, starting the other cores and the devices, why UEFI is not used and what a shim would be, and recovery.
5. [**The device driver model**](05-drivers.md): a PDP-11 driver (`rk.c`, `bdevsw`, the CSR, vectors) and what became of each part: the virtio transport and its queue, the life of a driver, the disk, the console, timer and entropy source (open), the network, graphics, sound and USB drivers, interrupts, DMA, errors, firmware, C and testing.
6. [**The kernel: modes, exceptions and memory management**](06-kernel.md): what a PDP-11 kernel did (status word, vectors, `trap()`, the eight page registers per mode, swapping), and from it the modes and the status word, exception and interrupt entry, precise faults, the system registers, virtual memory (pages, the tree of page tables, the page-table entry, accessed and dirty bits, the translation buffer, address-space numbers, direct-mapping windows, the layout of an address space), the user-memory guard, a system call, a page fault, a timer interrupt, a context switch and the idle loop in pseudocode, and the first pages and the first kernel.
7. [**Multiple processors**](07-smp.md): everything the architecture adds so that a second core is easy: the seventeen operations, the memory model, per-CPU state, translation coherence, waiting and signalling, starting cores.
8. [**Vector work, AI and array languages: the device route**](08-vectors.md): why there is no SIMD register file, and how neural-network inference and the array languages APL and K are served by memory-mapped devices.
9. [**The instruction set**](09-isa.md): how the opcode space is divided, the properties and principles of the architecture, the registers, the format, the addressing modes, and each group of instructions.
10. [**Conclusion: from FPGA to silicon**](10-conclusion.md): the FPGA plan, the transistor budget, the path to an OpenBSD you can log into, and what is still open.
11. [**The instruction reference tables**](dictionary/index.md): the assembler aliases, the architectural constants (status word, vectors, page-table entry, system registers, conditions), and the lists of the mnemonics and the bit-layout chart of every leaf. The entry for each instruction (syntax, encoding drawing, operation, flags, exceptions) is in chapter 9 in the section of its group, with the atomic instructions in section 7.12 and the system instructions in section 6.13.
12. [**Appendix A. Possible improvements not decided on**](appendix-a-improvements.md): ideas that nobody has turned into a decision, with their benefits and costs.
13. [**Appendix B. Decisions pending**](appendix-b-decisions-pending.md): every open decision with its question, proposed answer, precedent, trade-offs and benefits.
14. [**Appendix C. Glossary**](appendix-c-glossary.md): the manual's terms in one place, by architecture, kernel, devices and process.
15. [**Appendix D. The ABI, version 1**](appendix-d-abi.md): data model, registers, arguments and results, variadic calls, position-independent code.
16. [**Appendix E. The assembly language and the object format**](appendix-e-assembler.md): source syntax, directives, operand modes, the literal pool, and ELF.
17. [**Appendix F. The evidence behind the manual**](appendix-f-evidence.md): the long documents the manual is drawn from: the full instruction-set text, the system and bus documents, the record of decisions, and the surveys and measurements.
18. [**Appendix G. The evolution of the design**](appendix-g-evolution.md): how the design grew from a small question, and the influences, inspirations and precedents in the order they were introduced, each with its date and time.

## How to read it

**Each section is a few numbered aphorisms followed by a commentary.** The aphorisms say what is true of the machine, in plain short statements, and read on their own as the main text. The commentary under them gives, as they apply: the *Precedent* (what earlier machines did), the *Trade-offs* (what the choice costs), the *Improvements* (how the pdp64 departs from the precedent), the *Benefits*, the *Modern comparables* (what current architectures do), and, for an instruction that is not obvious, its *Use*. Every decision also carries an *Impact* line saying what it means for an efficient **kernel**, for efficient **compilation** and for an efficient **hardware layout**: the three things a processor designer asks of a choice. An instruction as plain as `MOV` or `ADD` needs no statement of use. The reference entries follow the layout of the classic CPU manuals, in which every instruction has its encoding diagram, its operation and its effects.

**Each aphorism carries a status.** *(D)* means decided. *(P)* means a proposal that is not decided. *(S)* means a stub: the statement names what is left unspecified. An aphorism with no tag describes the architecture as it is built and tested.

**Numbers.** Where a figure is measured, the text says what was measured; where it is an estimate, it says so. Claims about other machines are checked against the fact-check record listed in [appendix F](appendix-f-evidence.md).

**The PDF.** The same text as a book, [`book/pdp64-32.pdf`](../../../book/pdp64-32.pdf), built by [buildabook](https://github.com/moebiusV/buildabook) and Typst from the sources of this directory (`tools/mkbook.sh`; see `book/README.md`).

**Evidence documents.** All of them are listed in [appendix F](appendix-f-evidence.md): the full instruction set text ([`../pdp64-isa.md`](../../pdp64-isa.md)), the record of decisions ([`../errata.md`](../../errata.md)) and the open decisions with five options each ([`../decisions-pending.md`](../../decisions-pending.md)).
