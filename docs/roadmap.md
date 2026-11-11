<!-- {% raw %} -->
# Roadmap: from here to an OpenBSD you can ssh into

[← pdp64 index](../README.md)

Status: plan, updated 2026-11-10 to the current order of work. Decisions are in `docs/decisions-and-status.md` and the open items in Appendix J of the manual; this document does not decide anything. Opcode numbers and encodings are not fixed until the open items that affect them are decided, so this plan does not state any; the generated tables (`spec/pdp64/tables.md`, the manual dictionary) do.

Priority: the manual for the architecture is the primary deliverable; the assembler, linker, compiler back ends and emulators advance as needed to write and check it. The goal is what the project must have before it goes onto silicon: an assembler, a linker, an LLVM back end, an emulator, and a port of OpenBSD that you can ssh into. Sizes marked *(measured)* are line counts in the OpenBSD tree (`sys/arch/*`, lines of `.c`, `.S`, `.h`); everything marked *(estimate)* is a judgement; facts about OpenBSD's build requirements are *(not confirmed in the sources read)*.

## The order of work now

1. **Decide the open items**, starting with those that affect opcodes (Appendix J of the manual; the ledger). Nothing downstream is final before these, because opcode numbers and encodings may still change.
2. **Run the encoding optimizer** (`tools/encopt` 1.1, in C: no code-space reserve, three objectives, static, fetch and exec, errata 136; which objective the real run uses is the author's choice, `docs/encoding-work/optimizer.md` section 11) on the decided instruction set and compiler output to fix the prefix-coded encoding.
3. **Update the hbnf grammar** (`spec/pdp64/pdp64.hbnf`, `spec/pdp64-mnemonics.hbnf`): the grammars are the source of truth for the encodings.
4. **Regenerate** from the grammars: the assembler tables, the manual (dictionary and tables), the pcc headers and the tables of the LLVM back end (the author, 2026-11-10: the hbnf also emits what the LLVM back end uses, "two birds, one stone"; errata 137).
5. **Port** LLVM (of course, once the operations are settled and the pcc back end, as64, ld64, sim64 and the hbnf are updated: errata 137), pcc, as64, QEMU and sim64 to the new encoding and run their tests.
6. Then the OpenBSD port as laid out below (machine model, kernel, userland, network and ssh).

The pcc RISC-V back end is a separate project and is not on this path.

## The finish line, stated testably

A host machine runs the emulator with the OpenBSD kernel and userland built by the project's own toolchain; from another terminal on the host, `ssh user@localhost -p 2222` gives a login shell on the emulated pdp64. That one test needs, in order: a toolchain that builds OpenBSD, a machine model with a console, a disk and a network card, a kernel that boots, a userland with a network stack and `sshd`, and a way to get entropy for the keys.

## Where each of the five stands

The test counts in this table were measured in October 2026 on the old encodings; they are history until the new encoding is ported (the live state is in `docs/implementation-status.md`).

| Piece | State today | What remains for the goal |
|---|---|---|
| Assembler (`as64`) | see `docs/implementation-status.md` (implementation facts are kept there, not in the manual); the LLVM assembler (`llvm-mc`) was checked against it | state of the atomics and other late instructions: see `docs/implementation-status.md` |
| Linker (`ld64`) | links static programs; five relocation types | shared libraries and dynamic linking (OpenBSD's userland is position-independent by default and uses a run-time linker): a GOT and PLT, more relocation types, thread-local storage; or move to LLVM's linker `lld` |
| Compiler back end | the pcc back end is complete for C (510 tests passed and code size was within 0.2% of `gcc -Os` when last measured; unverified today, the encoding is being changed); the LLVM back end has its machine-code layer (milestone 1: assembler, disassembler, object writer; 62 of 62 oracle programs agree, 6,304 of 6,304 instruction forms agree) | the rest of LLVM: instruction selection, calling convention, tied operands, flags model, frames, position-independent code, atomics, thread-local storage, then clang (the C front end for the target) and `lld` and the compiler runtime (`compiler-rt` builtins for 128-bit integers, soft float, atomics). This is the long pole. |
| Emulator | `sim64` (user programs, a kernel-mode option with exceptions and injected interrupts) and QEMU (a user-mode machine and a kernel-mode machine with an MMU walker, timer, console, interrupts; 43 `sim64` programs and 52 QEMU tests pass) | the machine model of the manual: PCI Express (Q64) with virtio devices (errata 95: virtio-blk disk, errata 101; network; entropy; console), an interrupt path for them (MSI and MSI-X), and a boot path (`-kernel` is enough to start with; the real route is block 0, errata 109) |
| OpenBSD port | nothing written (the plan and its prerequisites are in the documents) | the kernel's machine-dependent code, the loader, the C library and run-time linker pieces, drivers for the devices above, and the userland build; sizes below |

## Why LLVM is the long pole, and why pcc cannot stand in for it

OpenBSD's base system is built with clang on arm64 and riscv64 and uses clang-specific features in places *(not confirmed in the sources read)*; pcc cannot build the OpenBSD kernel or its userland (the kernel uses GNU C extensions, inline assembly in the GNU style and attributes that pcc does not support). So the OpenBSD port waits for clang with a working pdp64 back end, not for pcc. The pcc back end remains useful for the C test suite, for bring-up of the simulator and for the fallback (Unix/32V), but the 32V fallback would not reach this goal: it has no network stack and no `ssh` (Unix/32V predates TCP/IP). Falling back to 32V would give a shell on the emulator, not an ssh login.

The estimate for a first back end that compiles C correctly, with the machine-code layer, was three to six months for one engineer who has written an LLVM back end before, plus clang, `lld` and the runtime in further weeks *(estimate, unmeasured; system architecture document, section 14.10)*. Milestone 1 (the machine-code layer) took about 75 minutes of work on a small machine; it says nothing yet about the hard parts.

## How big is the OpenBSD port? (measured on the riscv64 port, the newest and smallest in the tree)

| Part of `sys/arch/riscv64` | Lines | What it is |
|---|---|---|
| `riscv64/` (the core) | 14,873 | page tables (`pmap.c` 2,187), start-up and the machine (`machdep.c` 1,082), CPU and SMP (`cpu.c` 1,027), interrupts (`intr.c` 769), traps (`trap.c` 289), `locore.S` (268) and the rest |
| `dev/` | 11,771 | the platform's drivers (interrupt controller, timer, serial and so on) |
| `stand/` | 4,513 | the UEFI loader |
| `include/` | 4,443 | headers |
| total | 35,600 | (arm64 61,613; amd64 79,167; hppa 46,902; Alpha 54,312, same measure) |

What this suggests for the pdp64 *(estimate)*: the core machine-dependent code is the part that must be written by hand and is of the order of 15,000 lines if the pdp64 is like riscv64. The pdp64's design should make several parts smaller: no real-mode ladder or firmware tables to parse (boot.md), virtio devices found through PCI Express configuration (errata 95) instead of the platform driver zoo (the riscv64 `dev/` is 11,771 lines for its own platform), a small loader on the block-0 route (errata 109, versus the 4,513-line UEFI one; a shim for UEFI stays possible), no cache-maintenance code and no FPU-state code (hardware-vulnerabilities and pain-points reports). Outside `sys/arch` the port also needs machine-dependent parts of the C library (system-call stubs, `setjmp`, byte order and atomics), the run-time linker, the start-up code, the signal return path, and kernel and userland build configuration, which are not in the sparse tree measured here.

## The manual (a deliverable)

The manual is the single manual of the architecture: hand-written chapters in `docs/manual-src`, generated into `docs/manual` by `tools/mkmanual.py` (the dictionary of instructions and the tables come from the grammars, so numbers cannot drift), and built into the book under `book/`. It describes the architecture as it is to be, not the state of the implementations (errata 120). `tools/mkmanual.py --check` fails if an instruction has no entry or an entry names an opcode the grammar does not. The decided, proposed (Appendix H), deferred (Appendix I) and open (Appendix J) material are kept apart. The manual is regenerated whenever the grammar changes (step 4 above).

## The path to the finish line (proposed, with a testable exit for each step)

Design and documentation come first: the device designs, the open decisions, the boot and bus designs and the manual of the previous section are the primary work; the table below is the engineering path to the finish line, advanced as the documents need it (for example, the assembler must accept every instruction the manual shows, the simulator and QEMU must run the examples, and the LLVM back end is on the critical path to the ssh goal).

| Step | Work | Exit test |
|---|---|---|
| R0 | Finish the toolchain gaps: `ATOM` (and the atomics decision P11: the monitor) in the grammar, `as64`, `sim64`, QEMU and LLVM; `MESC`; the `UA` guard; the `ABI` version field; the literal-pool rule if accepted (P18) | all `check-all` tests green with the new instructions; atomics tested under two cores in QEMU |
| R1 | LLVM selection and the calling convention (tied operands, the flags model, frames, atomics lowering, position-independent code) | `llc` compiles the 510 C tests and they pass under `sim64`; size within a stated percentage of pcc |
| R2 | clang, `compiler-rt` builtins, `lld` (static first, then dynamic with a GOT and PLT) | clang builds a static `libc` subset and a test program, and the program runs |
| R3 | The machine model for the OS: PCI Express enumeration (the bus chapter of the manual), virtio-blk disk, virtio network, entropy and a clock, using the existing virtio drivers in OpenBSD (virtio across the board, errata 95; there are no separate native devices) | the machine model boots a bare-metal test that reads a disk block, sends a packet and reads random bytes |
| R4 | The kernel: machine-dependent code (traps, page tables, interrupts, start-up), the loader (boot.md), drivers for the model's devices | the cross-built kernel boots to single-user mode on the console |
| R5 | Userland: C library and run-time linker pieces, the base system cross-built with clang, an installer or a prebuilt disk image | multi-user boot to a login prompt on the console |
| R6 | Network and ssh: the network driver, entropy for the keys (decision P9), `sshd` | the finish line: `ssh user@localhost -p 2222` gives a shell |
| R7 | Before silicon: re-run everything against the FPGA board (the FPGA plan), the boot ROM and monitor (the boot chapter of the manual) | the same OpenBSD boots on the FPGA |

Parallelism. R0, and the model side of R3, do not depend on LLVM; R4's start-up and trap code can be written and assembled with `as64` while R1 and R2 are in progress, and tested on the simulator in assembly. The critical path is R1 and R2 (LLVM). That is the work for a larger machine.

## Which pending decisions gate which step

| Open item or decision (see `docs/decisions-and-status.md` and Appendix J of the manual; old labels from `decisions-pending.md`) | Gates |
|---|---|
| P11 atomics (decided: monitor) and the `ATOM` encodings | R0, and OpenBSD's kernel locks (R4) |
| P2 `UA` guard (decided), P10 `MMUCTL` (decided) | R4 (kernel start-up and copy routines) |
| P18 literal pool and execute-only | R1 (code generation) and the linker (R2) |
| R1 interrupt controller, R2 starting other cores (single core is enough for the first ssh) | R4 (single core first) |
| device model: decided, virtio over PCI Express (errata 79, 95, 101); the open details are in Appendix J | R3, R4 |
| P9 entropy | R6 (keys) |
| P13 `long double` (decided: stays `double`, ABI version 2 for 128-bit) | R2 (`compiler-rt` and the C library) |
| P3 `rdtime`, P4 feature registers, P5 `TLBIASID` | not on the critical path; useful early |
| the boot details (the boot chapter; errata 109) | R4 (loader) and R7 (silicon); QEMU's `-kernel` skips them until then |

## Measuring each design choice on the OpenBSD port

The emulators answer whether a feature works. Whether it is worth its cost is answered only by the running system. Once QEMU and `sim64` are both working and the OpenBSD port boots, each adopted feature (errata 84: memory colouring, the stack limit register, page-gated landing pads, the `SYS` page bit, predictor isolation, residue checks, ECC and watchpoint reporting, the restart contract, and those studied) is measured on its own, switched on and off one at a time, for performance and for the errors it catches. The measurement list is the last section of [`retire-stage-candidates.md`](retire-stage-candidates.md). The QEMU back end is brought to parity with `sim64`, which is the simulator the first measurements use.

## Risks, and what would change the plan

* The LLVM back end is the schedule. If it proves harder than estimated, the plan has no fallback to the goal (the fallback, 32V with pcc, does not reach ssh). The mitigation is to start R1 early and to measure progress against the 510 tests.
* The OpenBSD userland build may assume a native or an established cross build; bootstrapping a new architecture involves a cross-compiled first userland *(not confirmed in the sources read)*. The first step of R5 should be to read OpenBSD's cross-build procedure.
* Entropy and time for `sshd` in the emulator: the emulator can feed a seed and a clock; the real boards need the entropy device (P9).
* Virtio across the board is decided (errata 95): existing drivers get to ssh fastest. The risk is that the open PCI Express additions (Appendix J) change the device model late.

<!-- {% endraw %} -->
