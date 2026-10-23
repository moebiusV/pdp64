# Appendix F. The evidence behind the manual

[← manual index](00-index.md)

**The manual states decisions; these are the documents that hold the evidence, the surveys and the long arguments they were drawn from.** Each is a document of the repository, not a chapter of this manual, and each says in its own opening what it is based on and what it did not check. They are listed with what they hold and their status; the *Why it is here* paragraphs of the instruction entries and the *Impact* lines cite them.

## F.1 The architecture, in full

| Document | What it holds |
|---|---|
| [`pdp64-isa.md`](../pdp64-isa.md) | the full instruction-set text with every encoding, the revision history, the rejected features, the idioms lost and restored, the comparison with the PDP-11 and the VAX |
| [`pdp64-system-architecture.md`](../pdp64-system-architecture.md) | privilege, exceptions, interrupts, memory management and boot as an operating system sees them, with what is undefined stated plainly |
| [`pdp64-system-design.md`](../pdp64-system-design.md) | System v1: the options, how others do it, and how the choices serve the project's goals |
| [`pdp64-q64-bus.md`](../pdp64-q64-bus.md) | the system bus and its devices |
| [`boot.md`](../boot.md) | boot and bring-up: how the main systems start themselves, whether UEFI is worth having, and the proposal |
| [`pdp64-in-order-and-out-of-order.md`](../pdp64-in-order-and-out-of-order.md) and [`pdp64-ooo-readiness.md`](../pdp64-ooo-readiness.md) | what the in-order design point costs and buys, and what the architecture must decide to stay ready for an out-of-order core |
| [`pdp64-fpga-plan.md`](../pdp64-fpga-plan.md) and [`pdp64-lb64-accelerator.md`](../pdp64-lb64-accelerator.md) | the FPGA build plan and the inference accelerator |
| [`abi.md`](../abi.md) and [`asm-syntax.md`](../asm-syntax.md) | the ABI and the assembly language (appendices D and E are drawn from them) |
| [`roadmap.md`](../roadmap.md) | the order of work from the present toolchain to an OpenBSD that can be logged into |

## F.2 The record of decisions

| Document | What it holds |
|---|---|
| [`errata.md`](../errata.md) | every decision, numbered, with the reasons |
| [`CHANGES-SINCE-R20.md`](../CHANGES-SINCE-R20.md) | the changes to the instruction set from revision 20 on: instructions dropped, moved, added, the design errors found, the measurements |
| [`decisions-pending.md`](../decisions-pending.md) | every open decision, with the need, five options, the survey of what other systems do and what the PDP-11 and VAX did (appendix B is drawn from it) |
| [`fact-check-2026-10-22.md`](../fact-check-2026-10-22.md) | the comparison of statements about the outside world with a source where one could be read; the claims it could not check are marked "not confirmed" in the manual |

## F.3 Measurements and surveys

| Document | What it holds |
|---|---|
| [`codegen-analysis.md`](../codegen-analysis.md) | what compiled C says about the instruction set: instruction use, operand forms, the instructions never emitted |
| [`kernel-asm-survey.md`](../kernel-asm-survey.md) | what Linux, FreeBSD, NetBSD and OpenBSD write in assembly, and what pdp64 can learn from it |
| [`kernel-pain-points.md`](../kernel-pain-points.md) | what hurts kernel developers: tight loops, pain points and workarounds in the current kernels, from the source trees and the mailing lists, compared with pdp64 |
| [`hardware-vulnerabilities.md`](../hardware-vulnerabilities.md) | the processor, memory and system flaws of the last decade that needed mitigations, and the rules that keep pdp64 from repeating them, including the evidence on constant-time modes |
| [`openbsd-mitigations.md`](../openbsd-mitigations.md) | OpenBSD's memory-safety and exploit mitigations, what pdp64 gives for free and what would make the rest soft and easy |
| [`sim64.md`](../sim64.md) | the reference emulator |

The data behind the tables is in `docs/codegen-data/`, the generators are in `tools/`, and the sources of the design discussions are `chat01.txt` and the archive of the working session.
