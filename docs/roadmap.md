# Roadmap: from here to an OpenBSD you can ssh into

[← pdp64 index](../README.md)

**Status: first draft, 2026-10-22, for the author's review.** Nothing here is decided unless it says so. The goal (errata 52, stated by the author) is what the project must have **before it goes onto silicon**: an **assembler, a linker, a compiler back end (LLVM), an emulator, and a port of OpenBSD that you can ssh into**. This document says where each stands, what stands between the project and the goal, in what order to do it, and which pending decisions gate which step. Sizes marked *(measured)* are line counts in the OpenBSD tree on this machine (`sys/arch/*`, lines of `.c`, `.S`, `.h`); everything marked *(estimate)* is my judgement; facts about OpenBSD's build requirements are *(not confirmed in the sources read)*.

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

## The order of work (proposed, with a testable exit for each step)

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
