# The pdp64 architecture, streamlined

[← pdp64 index](../../README.md)

**This is the short, ordered account of the pdp64: what it is, why, and how each part works.** The other documents in this repository are the working record, with every revision, correction and decision in the order it happened. This set is the same material arranged to be read straight through, with the history and the arguments moved to commentary. Nothing in the other documents was changed or removed to make it.

## Contents

1. [**Introduction**](01-introduction.md): why the machine exists, what made the PDP-10, PDP-11 and VAX-11 good to program, and the principles the design follows.
2. [**The bus**](02-bus.md): Q64, the way devices are reached and described, the bus as a device, enumeration and hot-plug, and the default eight-register devices with their DMA design.
3. [**Boot, the BIOS, the disk label and the GPT**](03-boot.md): what starts the machine, what takes the place of a BIOS, how the disk is laid out, and why UEFI is not used.
4. [**The instruction set**](04-isa.md): how the opcode space is divided, the properties and principles of the architecture, the registers, the format, the addressing modes, and then each group of instructions, with exceptions, faults and memory management at the end.
5. [**Conclusion: from FPGA to silicon**](05-conclusion.md): the FPGA plan, the transistor budget, the path to an OpenBSD you can log into, and what is still open.
6. [**Appendix A. Possible improvements not decided on yet**](appendix-a-improvements.md): ideas that nobody has turned into a decision, with their benefits and costs.
7. [**Appendix B. Decisions pending**](appendix-b-decisions-pending.md): every open decision with its question, proposed answer, precedent, trade-offs and benefits.

## How to read it

**Each section is a few numbered aphorisms followed by a commentary.** The aphorisms say what is true of the machine, in plain short statements, and read on their own as the main text. The commentary under them gives, as they apply: the *Precedent* (what earlier machines did), the *Trade-offs* (what the choice costs), the *Improvements* (what was changed from the precedent), the *Benefits*, the *Modern comparables* (what current architectures do), and, for an instruction that is not obvious, its *Use*. An instruction as plain as `MOV` or `ADD` needs no statement of use. The form is the one the author chose (errata 56); the reference entries of the full manual (errata 57) will follow the layout of the classic CPU manuals, in which every instruction has its encoding diagram, its operation and its effects.

**Each aphorism carries a status.** *(D)* means decided, with the erratum or the revision that fixed it where useful. *(P)* means a proposal that the author has not yet settled. An aphorism with no tag describes the architecture as it is built and tested.

**Numbers.** Where a figure is measured, the text says what was measured; where it is an estimate, it says so. A claim about another machine is the author's account, checked as far as the fact-check record shows ([`../fact-check-2026-10-22.md`](../fact-check-2026-10-22.md) and the verification appendix of [`../decisions-pending.md`](../decisions-pending.md)).

**Where the rest is.** The full instruction set text is [`../pdp64-isa.md`](../pdp64-isa.md); every decision with its reasons is [`../errata.md`](../errata.md) and [`../CHANGES-SINCE-R20.md`](../CHANGES-SINCE-R20.md); the decisions still open, with five options each, are [`../decisions-pending.md`](../decisions-pending.md).
