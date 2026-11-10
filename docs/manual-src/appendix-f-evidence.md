# Appendix F. The evidence behind the manual

[← manual index](00-index.md)

**The manual states decisions; these are the documents that hold the evidence, the surveys and the long arguments they were drawn from.** Each is a document of the repository, not a chapter of this manual, and each says in its own opening what it is based on and what it did not check. They are listed with what they hold and their status; the *Why it is here* paragraphs of the instruction entries and the *Impact* lines cite them.

## F.1 The architecture, in full

| Document | What it holds |
|---|---|
| [`pdp64-isa.md`](../pdp64-isa.md) | the full instruction-set text with every encoding, the rejected features, the idioms lost and restored, the comparison with the PDP-11 and the VAX |
| [`pdp64-system-architecture.md`](../pdp64-system-architecture.md) | privilege, exceptions, interrupts, memory management and boot as an operating system sees them, with what is undefined stated plainly |
| [`pdp64-system-design.md`](../pdp64-system-design.md) | System v1: the options, how others do it, and how the choices serve the project's goals |
| [`boot.md`](../boot.md) | boot and bring-up: how the main systems start themselves, whether UEFI is worth having, and the proposal |
| [`pdp64-in-order-and-out-of-order.md`](../pdp64-in-order-and-out-of-order.md) and [`pdp64-ooo-readiness.md`](../pdp64-ooo-readiness.md) | what the in-order design point costs and buys, and what the architecture must decide to stay ready for an out-of-order core |
| [`pdp64-fpga-plan.md`](../pdp64-fpga-plan.md) and [`pdp64-lb64-accelerator.md`](../pdp64-lb64-accelerator.md) | the FPGA build plan and the inference accelerator |
| [`abi.md`](../abi.md) and [`asm-syntax.md`](../asm-syntax.md) | the ABI and the assembly language (appendices D and E are drawn from them) |
| [`roadmap.md`](../roadmap.md) | the order of work from the present toolchain to an OpenBSD that can be logged into |

## F.2 The record of decisions

| Document | What it holds |
|---|---|
| [`errata.md`](../errata.md) | every decision, numbered, with the reasons |
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
| [`smp-decisions.md`](../smp-decisions.md) | the open symmetric-multiprocessing decisions, proposals awaiting the author's annotations (tag P) |
| [`crypto-secure-core.md`](../crypto-secure-core.md), [`security-proposals.md`](../security-proposals.md), [`study-proposals.md`](../study-proposals.md), [`retire-stage-candidates.md`](../retire-stage-candidates.md) | the proposals on the secure core, the security mechanisms, the studied instructions and the retire-stage mechanisms, with the author's replies in errata 84 to 86 |
| [`priority-lists.md`](../priority-lists.md) | the lists of priorities that errata 83 settled |

The data behind the tables is in `docs/codegen-data/`, the generators are in `tools/`, and the sources of the design discussions are `chat01.txt` and the archive of the working session.

## F.4 The encoding: the measurements

**F.4.1** The encoding, the compiler, the assembler, the linker, the simulator and the timing model were built and measured together; the sources of the numbers below are [`encoding-proposal.md`](../encoding-proposal.md) (the study, sections 6 and 12) and [`encoding-work/integration.md`](../encoding-work/integration.md) (section 4 is the final table, made on the integrated tree), with the reports of each phase in [`encoding-work/`](../encoding-work/README.md). The baseline is the first encoding (the earlier iteration of 1.8) with the compiler as it was before the work. There is no baseline of the first encoding with the new compiler: several of the compiler's passes use instructions only the prefix-coded encodings have. Relaxation is on by default; the model of timing is an in-order toy with ideal memory (128 exact checks of its own pipeline), not hardware.

**F.4.2** The static size on the 841-file corpus (instruction bytes from `as64 --stats`):

| | first encoding, old compiler | pdp64, new compiler |
|---|---:|---:|
| instruction bytes | 1,083,870 | 964,158 (-11.04%) |
| without `memcpy-a2.c` (27% of the bytes) | 785,836 | 706,042 (-10.15%) |
| instructions | 338,313 | 296,070 |
| fused pairs (`MOVCALL`, `POPMRET`, `POPRET`, `MOV2`) | 0 | 11,531, 1,608, 2,586, 4,061 = 19,786 |
| `CBCC` replaced by `CMP` and `BCC` | 0 | 13 |
| text of the objects (840 files, before linking) | 1,305,878 | 1,197,018 |
| the same linked with relaxation | not applicable | 1,152,010 (-3.76% against unrelaxed) |

Relaxation shortens the text of the objects by 45,008 bytes. The corpus stub places the symbols right behind each file, so the saving is an upper bound for the reach of the 4-byte call.

**F.4.3** Six large programs (lz4, zlib, Lua and three BearSSL kernels, linked with a stand-in C library, run on the simulator; all print exactly the host's output on all three encodings), totals:

| | first encoding, old compiler | pdp64, new compiler |
|---|---:|---:|
| instructions executed | 755,816,022 | 572,801,956 (-24.21%) |
| bytes fetched | 2,365,226,284 | 1,680,662,586 (-28.94%) |
| bytes per instruction | 3.129 | 2.934 |
| linked text (relaxed) | 226,606 | 203,404 (-10.24%) |
| fused instructions executed | 0 | 10,381,414 |
| frame loads and stores executed | 68,936,548 | 24,276,195 (-64.78%) |

Linking the same objects with `--no-relax` instead of the default makes the linked text 1.65% larger and changes the bytes executed by 0.4%.

**F.4.4** The timing model (in order, ideal memory, no branch predictor; issue width 1 or 2, fetch window W bytes a cycle; the prefix-coded encodings pay one cycle of length-decode latency on a taken branch and a refill), all six programs summed:

| model | first encoding, old compiler | pdp64, new compiler |
|---|---:|---:|
| issue 1, W = 4: cycles | 1,133,787,653 | 842,065,005 (-25.73%) |
| issue 2, W = 4: cycles | 1,001,691,461 | 735,251,238 (-26.60%) |
| issue 1, W = 2: cycles | 1,305,661,982 | 1,002,176,356 (-23.24%) |
| issue 1, W = 4: fetch-wait, execute-wait (share of cycles) | 1.7%, 31.6% | 7.2%, 24.8% |

At four bytes a cycle and above the programs are bound by execution and not by fetch (widening the fetch from 4 to 16 bytes a cycle takes 1.0% off the cycles at issue width 1); the saving in cycles is the saving in instructions, and the saving in bytes buys nothing at those widths. By program (issue 1, W = 4, against the first encoding): lz4 -7.9%, zlib -18.2%, Lua -49.1%, bs_hash -2.4%, bs_sym -8.5%, bs_ec -24.9%. The gain on Lua is the switch dispatch of the new compiler, not the encoding.

**F.4.5** The predictions of the study against the final measurement: the model of the study put the corpus at 1,040,280 bytes and, with the four fused pairs, 1,007,172; the measurement is 964,158, for the same reasons. The study put relaxation at 9% of the corpus text and a first measurement at 3.5%; the final measurement is 3.76%.

**F.4.6** What these measurements do not establish: the timing is one sweep of an in-order model with ideal memory; the cache variants were not re-run on the final compiler; the 3-parcel `CBCC` and the other form choices were trained on the corpus and not on the six programs, so a profile-tuned variant was not tried; one corpus file does not link in the stub measurement (a 64-bit constant used as a displacement); the compiler does not use `MOVUW`, `MOVUL`, `MOVUQ` (the unaligned-access idiom is 10% of the instructions of lz4), `MULH`-based division by 64-bit constants, loop-invariant motion or live-range splitting; QEMU does not yet execute this encoding; the atomics, a number of cryptographic words, `MVAL`, `UTF8DEC` and `UTF8ENC` are not implemented in the reference executor.

