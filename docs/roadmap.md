# Roadmap: from here to an OpenBSD you can ssh into

[← pdp64 index](../README.md)

**Priority (errata 54): the manual for the architecture, not only the instruction set, is the primary deliverable; the assembler, linker, compiler back ends and emulator are also important and are advanced as needed to write and check it. So design and documentation come first in the order below.** **Status: first draft, 2026-10-22, for the author's review.** Nothing here is decided unless it says so. The goal (errata 52, stated by the author) is what the project must have **before it goes onto silicon**: an **assembler, a linker, a compiler back end (LLVM), an emulator, and a port of OpenBSD that you can ssh into**. This document says where each stands, what stands between the project and the goal, in what order to do it, and which pending decisions gate which step. Sizes marked *(measured)* are line counts in the OpenBSD tree on this machine (`sys/arch/*`, lines of `.c`, `.S`, `.h`); everything marked *(estimate)* is my judgement; facts about OpenBSD's build requirements are *(not confirmed in the sources read)*.

## The finish line, stated testably

A host machine runs the emulator with the OpenBSD kernel and userland built by the project's own toolchain; from another terminal on the host, **`ssh user@localhost -p 2222` gives a login shell on the emulated pdp64**. That one test needs, in order: a toolchain that builds OpenBSD, a machine model with a console, a disk and a network card, a kernel that boots, a userland with a network stack and `sshd`, and a way to get entropy for the keys.

## Where each of the five stands

| Piece | State today | What remains for the goal |
|---|---|---|
| **Assembler** (`as64`) | done and tested; the LLVM assembler (`llvm-mc`) agrees with it on everything it can express | the atomics (`ATOM`, 22 words) are in the ISA but **not implemented in `as64`**; `MESC` (8 words) likewise; the odd cases are small |
| **Linker** (`ld64`) | links static programs; five relocation types | **shared libraries and dynamic linking** (OpenBSD's userland is position-independent by default and uses a run-time linker): a GOT and PLT, more relocation types, thread-local storage; or move to LLVM's linker `lld` |
| **Compiler back end** | the pcc back end is complete for C (510 tests pass; code size within 0.2% of `gcc -Os`); the **LLVM back end has its machine-code layer** (milestone 1: assembler, disassembler, object writer; 62 of 62 oracle programs agree, 6,304 of 6,304 instruction forms agree) | **the rest of LLVM**: instruction selection, calling convention, tied operands, flags model, frames, position-independent code, atomics, thread-local storage, then **clang** (the C front end for the target) and `lld` and the compiler runtime (`compiler-rt` builtins for 128-bit integers, soft float, atomics). **This is the long pole.** |
| **Emulator** | `sim64` (user programs, a kernel-mode option with exceptions and injected interrupts) and **QEMU** (a user-mode machine and a kernel-mode machine with an MMU walker, timer, console, interrupts; 43 `sim64` programs and 52 QEMU tests pass) | the **bus controller**, a **disk**, a **network card**, an **entropy source**, an interrupt controller for more than the timer and console; a boot path (`-kernel` is enough to start with) |
| **OpenBSD port** | **nothing written** (the plan and its prerequisites are in the documents) | the kernel's machine-dependent code, the loader, the C library and run-time linker pieces, drivers for the devices above, and the userland build; sizes below |

## Why LLVM is the long pole, and why pcc cannot stand in for it

OpenBSD's base system is built with clang on arm64 and riscv64 and uses clang-specific features in places *(not confirmed in the sources read)*; pcc cannot build the OpenBSD kernel or its userland (the kernel uses GNU C extensions, inline assembly in the GNU style and attributes that pcc does not support). So the OpenBSD port waits for **clang with a working pdp64 back end**, not for pcc. The pcc back end remains useful for the C test suite, for bring-up of the simulator and for the fallback (Unix/32V, errata 41), but **the 32V fallback would not reach this goal**: it has no network stack and no `ssh` (Unix/32V predates TCP/IP). Falling back to 32V would give a shell on the emulator, not an ssh login.

My earlier estimate for a first back end that compiles C correctly, with the machine-code layer, was three to six months for one engineer who has written an LLVM back end before, plus clang, `lld` and the runtime in further weeks *(estimate, unmeasured; system architecture document, section 14.10)*. Milestone 1 (the machine-code layer) took about 75 minutes of agent time on a small machine; it says nothing yet about the hard parts.

## How big is the OpenBSD port? (measured on the riscv64 port, the newest and smallest in the tree)

| Part of `sys/arch/riscv64` | Lines | What it is |
|---|---|---|
| `riscv64/` (the core) | 14,873 | page tables (`pmap.c` 2,187), start-up and the machine (`machdep.c` 1,082), CPU and SMP (`cpu.c` 1,027), interrupts (`intr.c` 769), traps (`trap.c` 289), `locore.S` (268) and the rest |
| `dev/` | 11,771 | the platform's drivers (interrupt controller, timer, serial and so on) |
| `stand/` | 4,513 | the UEFI loader |
| `include/` | 4,443 | headers |
| **total** | **35,600** | (arm64 61,613; amd64 79,167; hppa 46,902; Alpha 54,312, same measure) |

**What this suggests for the pdp64** *(estimate)*: the core machine-dependent code is the part that must be written by hand and is of the order of **15,000 lines** if the pdp64 is like riscv64. The pdp64's design should make several parts smaller: no real-mode ladder or firmware tables to parse (boot.md), uniform eight-register devices (decision R5) instead of the platform driver zoo (the riscv64 `dev/` is 11,771 lines for its own platform), a trivial loader (boot.md, versus the 4,513-line UEFI one), no cache-maintenance code and no FPU-state code (hardware-vulnerabilities and pain-points reports). Outside `sys/arch` the port also needs machine-dependent parts of the C library (system-call stubs, `setjmp`, byte order and atomics), the run-time linker, the start-up code, the signal return path, and kernel and userland build configuration, which are not in the sparse tree measured here.

## The manual (a deliverable, errata 53)

**What the author asked for.** A comprehensive manual that shows **every opcode** and explains what it does, how it works, why it is included, and the whole story behind it; the **stories of clusters of instructions** and of decisions; **the bus and the BIOS and boot** material; and **the default bus, disk, USB and network drivers**, each an eight-register device with its DMA and memory-mapped design.

**How it is produced.** The numbers must not drift from the grammar (the project's rule: one source of truth), so the manual is **generated where it can be and written where it cannot**:

* **Generated** by a new tool, `tools/mkmanual.py`, from `spec/pdp64-mnemonics.hbnf` (the enumerations: every mnemonic word, its opcode, sub-opcode and page-2 abbreviation), from `as64 --limits` (field widths and encodings, as the LLVM generator already does), from `common/pdp64exec.c` (the flags each instruction writes and its privilege, via the same tables the invariant test reads), and from the data files (`mnemonics_pdp64.csv` for how often the compiler emits each instruction, `instructions_used.csv`, the kernel survey counts). Each instruction's **reference entry** is generated: name, encoding diagram, operand forms, lengths, flags, privilege, faults, the page-2 form, the assembler spelling, how often it is used.
* **Written** (and kept in a source database that the tool merges, `docs/manual-src/`, one small file per instruction or cluster): **what it does in plain words, how it works, the rationale and the whole story**: the revision in which it was added or dropped, the errata and decisions that shaped it, what the PDP-11, VAX, x86, AArch64 and RISC-V do, what the corpus and the kernels show. Most of this prose already exists in the ISA (sections 4, 9, 10, 11, 14), the errata and `CHANGES-SINCE-R20.md`, so the task is mostly to gather, correct against the grammar and complete it, not to invent it. A check (like the drift test) fails if an instruction has no entry or an entry names an opcode the grammar does not.
* **Clusters and decisions as stories:** one chapter per family (moves, ALU, shifts, bit and byte, multiply and divide, block operations, floating point, atomics, system), each telling why the cluster exists and what was rejected, drawn from ISA sections 9 to 11 and 14, the errata and the decision documents.

**Contents (proposed).**

1. **Introduction and principles:** the author's three principles in order, "all rules are soft", the PDP-11 and VAX lineage.
2. **The machine:** state, registers, flags, instruction format, addressing modes, memory model, faults and restart, memory management, exceptions and System v1.
3. **The instruction set, by cluster:** a story for each cluster, then the **reference entry for every instruction** (about 270 words and 230 instructions at the last count).
4. **The system:** privilege, interrupts, the timer and console; the bus (Q64 and its transactions, the bus as a device, enumeration, mapping, hot-plug, work in flight when a device leaves); boot (the boot ROM and monitor, the first block, the loader, the hand-off, starting other cores, disk layout and the GPT wrapper); security (the hardware-vulnerability rules, constant time, OpenBSD's mitigations, execute-only code).
5. **The devices:** the uniform eight-register layout, the DMA descriptor format, the memory-mapped design, and the default **bus controller, disk, network card, USB and entropy** devices, each with its register table, its descriptor format, its initialisation and its failure behaviour, plus a driver walk-through.
6. **The toolchain:** the assembler, linker, compiler back ends, simulator, QEMU target, the LLVM target and how to build and test them.
7. **Appendices:** the encoding tables, the generated opcode index, the glossary, the history (errata in order), the sources.

**What needs design before it can be documented.** The reference part is mostly existing material. **The devices part does not exist yet**: the uniform register layout, the DMA descriptor format and the personalities of the disk, network card and USB device are open items (bus document section 9 and decision R5), and the manual cannot describe designs that have not been made. So the plan has a **design step for the devices** first (a proposal document for the author to review, in the form of the decisions document), then the chapter. USB is the hard one in eight registers: a USB host controller normally exposes rings and many registers (xHCI); the proposal to examine is that the controller chip does the protocol and the enumeration and presents **each USB device as a slot on the pdp64 bus** (an eight-register device of its own: a USB disk looks like a disk, and so on), which fits the bus-as-a-device design; to be worked out, not a decision.

**Order of work (proposed).** (1) The generator and the reference entries, which are mechanical and independent of everything else; (2) the cluster stories and the "whole story" prose, gathered from the existing documents and checked against the grammar; (3) the device design document (uniform layout, DMA descriptors, the personalities of the bus controller, disk, network card, USB, entropy) for the author's review, then the devices chapter; (4) the bus, boot and security chapters, assembled from `boot.md`, the bus document, `hardware-vulnerabilities.md` and `openbsd-mitigations.md` once those settle; (5) the toolchain chapter and appendices. The published form (a single book, or a directory of chapters on the project's Pages site, plus section 1 manual pages for the command-line tools as the project standard asks) is for the author to choose.

## The order of work (proposed, with a testable exit for each step)

**Design and documentation come first (errata 54):** the device designs (`devices.md`), the open decisions, the boot and bus designs and the manual of the previous section are the primary work; the table below is the engineering path to the finish line, advanced as the documents need it (for example, the assembler must accept every instruction the manual shows, the simulator and QEMU must run the examples, and the LLVM back end is on the critical path to the ssh goal).

| Step | Work | Exit test |
|---|---|---|
| **R0** | Finish the toolchain gaps: `ATOM` (and the atomics decision P11: the monitor) in the grammar, `as64`, `sim64`, QEMU and LLVM; `MESC`; the `UA` guard (errata 43); the `ABI` version field (errata 46); the literal-pool rule if accepted (P18) | all `check-all` tests green with the new instructions; atomics tested under two cores in QEMU |
| **R1** | **LLVM selection and the calling convention** (tied operands, the flags model, frames, atomics lowering, position-independent code) | `llc` compiles the 510 C tests and they pass under `sim64`; size within a stated percentage of pcc |
| **R2** | **clang, `compiler-rt` builtins, `lld`** (static first, then dynamic with a GOT and PLT) | clang builds a static `libc` subset and a test program, and the program runs |
| **R3** | **The machine model for the OS**: the bus controller and enumeration (bus document section 13), a disk, a network card, an entropy source, a clock; **fastest to ssh: virtio-mmio devices already in QEMU**, using the existing virtio drivers in OpenBSD, with the project's own eight-register devices (decision Q10, R5) added afterwards for silicon | the machine model boots a bare-metal test that reads a disk block, sends a packet and reads random bytes |
| **R4** | **The kernel**: machine-dependent code (traps, page tables, interrupts, start-up), the loader (boot.md), drivers for the model's devices | the cross-built kernel boots to single-user mode on the console |
| **R5** | **Userland**: C library and run-time linker pieces, the base system cross-built with clang, an installer or a prebuilt disk image | multi-user boot to a login prompt on the console |
| **R6** | **Network and ssh**: the network driver, entropy for the keys (decision P9), `sshd` | **the finish line:** `ssh user@localhost -p 2222` gives a shell |
| **R7** | Before silicon: re-run everything against the FPGA board (the FPGA plan), the native eight-register devices, the boot ROM and monitor (boot.md) | the same OpenBSD boots on the FPGA |

**Parallelism.** R0, and the model side of R3, do not depend on LLVM; R4's start-up and trap code can be written and assembled with `as64` while R1 and R2 are in progress, and tested on the simulator in assembly. The critical path is R1 and R2 (LLVM). That is the work for the larger machine you mentioned.

## Which pending decisions gate which step

| Decision (see `decisions-pending.md`, `boot.md`, bus document) | Gates |
|---|---|
| P11 atomics (decided: monitor) and the `ATOM` encodings | R0, and OpenBSD's kernel locks (R4) |
| P2 `UA` guard (decided), P10 `MMUCTL` (decided) | R4 (kernel start-up and copy routines) |
| P18 literal pool and execute-only | R1 (code generation) and the linker (R2) |
| R1 interrupt controller, R2 starting other cores (single core is enough for the first ssh) | R4 (single core first) |
| R5 device layout, bus section 13 (N1 to N3), Q10 (virtio or the eight-register layout) | R3, R4 |
| P9 entropy | R6 (keys) |
| P13 `long double` (decided: stays `double`, ABI version 2 for 128-bit) | R2 (`compiler-rt` and the C library) |
| P3 `rdtime`, P4 feature registers, P5 `TLBIASID` | not on the critical path; useful early |
| boot.md B1 to B8 | R4 (loader) and R7 (silicon); QEMU's `-kernel` skips them until then |

## Risks, and what would change the plan

* **The LLVM back end is the schedule.** If it proves harder than estimated, the plan has no fallback to the goal (the fallback, 32V with pcc, does not reach ssh). The mitigation is to start R1 early and to measure progress against the 510 tests.
* **The OpenBSD userland build** may assume a native or an established cross build; bootstrapping a new architecture involves a cross-compiled first userland *(not confirmed in the sources read)*. The first step of R5 should be to read OpenBSD's cross-build procedure.
* **Entropy and time** for `sshd` in the emulator: the emulator can feed a seed and a clock; the real boards need the entropy device (P9).
* **Virtio first, eight registers later** is a real trade-off: virtio gets to ssh faster (existing drivers) and the eight-register devices are the architecture's own design (principles 1 and 2: simple, small drivers). Decision R3 above takes the fast route for the emulator and keeps the native devices for silicon; it is a proposal for the author to confirm.
