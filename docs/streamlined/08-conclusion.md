# 8. Conclusion: from FPGA to silicon

[← streamlined index](00-index.md)

**The pdp64 is built to be run first on a modest FPGA, to be small enough that its whole core is about sixteen thousand lookup tables or ninety thousand transistors, and to reach silicon only after an OpenBSD built by the project's own toolchain can be logged into over `ssh`.** This chapter gives the FPGA plan and its numbers, the transistor budget for a chip, why the first implementations are in order and how the architecture is kept ready for a faster one, and the path from today's state to the finish line. Tags: *(D)* decided; *(E)* an estimate, not a measurement.

## 8.1 The FPGA plan

**8.1.1** The first implementation is a soft core on a system-on-chip FPGA whose hard ARM cores serve as the bring-up harness: they load programs, run the tests and provide the console while the pdp64 core is still being debugged. *(D, plan)*

**8.1.2** The first board is the Terasic DE10-Nano (Cyclone V SE: about 110,000 logic elements, dual Cortex-A9, 1 GB of memory on the hard processor, HDMI, and the MiSTer ecosystem); the Digilent Zybo Z7-20 or the AMD Kria KV260 are the move when timing becomes the limit; the open-toolchain ULX3S is kept in view but loses the hard-core harness. *(D, plan)*

**8.1.3** A complete core is about 16,000 six-input lookup tables, 10 to 16 multiplier blocks and 11 block RAMs, with an error of about ±40%: the register file is 250 lookup tables of distributed RAM, the 64-bit ALU 600, the barrel shifter 450, the caches 300 and 500 plus 8 block RAMs, the bus bridge 600. *(E)*

**8.1.4** Block RAM, not logic, is the scarce resource: the caches, the translation buffer, the framebuffer and the blitter scratch compete for about 5.5 megabits. *(E)*

**8.1.5** The realistic clock is 50 to 80 MHz on the Cyclone V, 90 to 130 MHz on a Zynq 7020 and 180 to 250 MHz on an UltraScale+; a correct 40 MHz machine is worth more than a fast broken one, and 60 MHz is already some fifty times a PDP-11/70. *(E)*

**8.1.6** The work is staged in phases, each ending in a demonstration and a regression suite: specification and tools; an integer core; exceptions; the memory-management unit; the memory system; floating point; a booting kernel; peripherals; and, optionally and last, a second core. *(D, plan)*

**8.1.7** Phase 2, the fault model, is not optional and does not move; the block operations are built with it, because their whole specification is about what state is visible when an exception arrives. *(D, plan)*

*Commentary.* **Precedent.** The PDP-11's own microprocessor, the T-11, was about 12,000 transistors, a complete integer core without a memory-management unit or floating point; the J-11 that implemented the full PDP-11/70 was about 120,000. The MicroVAX 78032 was 125,000 transistors for a subset of the VAX, with 175 of its 304 instructions and no floating point. **Trade-offs.** The 64-bit carry chain is slow on an FPGA and gates the clock more than it would in silicon, the barrel shifter is a large multiplexer tree, and flags serialise branch resolution behind the ALU; none of that argues for changing the instruction set, only for where the pipeline registers go, for example a virtually indexed, physically tagged first-level cache so that the translation buffer is off the critical path. A multiplier built from two to four multiplier blocks over four to eight cycles closes timing where a full combinational one will not. **Improvements.** The register-transfer description is kept vendor-neutral, with every vendor primitive in one thin directory (under 500 lines), so that moving between boards costs that directory and nothing else. **Benefits.** A single engineer working part-time can reach a booting system with floating point in roughly 10 to 19 months, by the plan's wide-error-bar estimate, with phases 2 and 3 the ones that historically double. **Modern comparables.** The RISC-V soft cores Rocket and VexRiscv are the usual FPGA reference points; the plan treats the compiler back end as the schedule risk, as it is for any new architecture.

## 8.2 The chip: a transistor budget

**8.2.1** For a non-pipelined or short-pipeline implementation in a modern process, the whole core excluding caches is estimated at about 92,000 transistors. *(E)*

| Block | Transistors (E) |
|---|---|
| register file, 16 × 64, two read ports and one write | ~6,000 |
| ALU, shifter, address adder | ~15,000 |
| decode and sequencer | ~6,500 |
| bit unit (popcount tree, count zeros, bitfields) | ~3,500 |
| block-move sequencer | ~1,500 |
| UTF-8 decode and validity | ~1,200 |
| translation buffer (32 entries), walker, window compare | ~19,000 |
| floating-point unit with fused multiply-add, classify, min and max | ~34,000 |
| control, status word, exceptions, undo buffer | ~5,500 |
| **total, excluding caches** | **~92,000** |

**8.2.2** The bit unit and the UTF-8 decoder together cost less than 5% of the die; the fused multiply-add datapath is the largest single addition and the least negotiable. *(E)*

*Commentary.* **Precedent.** The figure sits between the T-11 and the MicroVAX: it is a 64-bit machine with floating point and memory management below the 78032's 125,000 transistors, which had neither. **Trade-offs.** The estimate is not a measurement and excludes caches, which dominate the area of a real chip; an implementation of the translation buffer as a content-addressable memory is larger than the figure assumes, which is why the FPGA build uses a four-way set-associative one. **Benefits.** A chip this size fits in the budget of a small process node with room for caches and the bus controller. **Modern comparables.** The ARM1 of 1985 was about 25,000 transistors without a memory-management unit or floating point; the Intel 80386 about 275,000.

## 8.3 In order now, ready for out of order

**8.3.1** The first implementations, on the FPGA and in silicon, are small in-order cores without speculation; the architecture is kept ready for a large out-of-order design. *(D, errata 38)*

**8.3.2** The condition flags were the structural obstacle: 68.2% of compiled instructions wrote a flag and only 1.5% read one, so they were reorganised into two groups that nothing writes in part, and moves, loads, stores and the compare-and-branch instructions write none. *(D, errata 39)*

**8.3.3** An in-order, non-speculative core has none of the speculative side channels of the last decade today; the rules that keep a future faster core from repeating them are collected in the hardware-vulnerabilities report, and include no speculation across protection domains, no shared predictor state across privilege boundaries without a flush, and operand-independent timing for a declared set of instructions. *(D as a design aim; the rules are proposals)*

**8.3.4** Sequential consistency is nearly free on a small in-order core and is the most expensive memory model for a large speculative one; if a large core is built it may be necessary to move to total store order, which is the least painful retreat. *(P)*

*Commentary.* **Precedent.** One instruction set has often spanned in-order and out-of-order cores: the ARM small cores beside the large ones, the RISC-V Rocket beside the BOOM, x86 from the Pentium to the P6, Alpha from the 21064 to the 21264. The VAX's long, orthogonal instructions with many side effects are generally blamed for making its later fast implementations so hard. **Trade-offs.** Readiness has a cost, visible here as the compiled-code size paid for the flag changes (0.39%) and as design effort spent on a core that may never be built. **Improvements.** The pain-points report finds that the pdp64 avoids the largest classes of kernel pain by design (barriers, floating-point state, a faulting entry, remote translation flushes, the speculative family) and is exposed in a few places: a single page-table base if a core ever speculates, software accessed and dirty bits, uncached DMA buffers, and no specified constant-time or Rowhammer protection. **Benefits.** Any of these can be addressed in the specification while it is still being written, which is cheaper than after silicon. **Modern comparables.** The common vulnerability-driven changes of recent years, page-table isolation and speculation barriers, are what a speculative core of this architecture would have to add.

## 8.4 The finish line, and the path to it

**8.4.1** Before silicon the project delivers five things: an assembler, a linker, an LLVM compiler back end, an emulator, and a port of OpenBSD that can be logged into with `ssh`. *(D, errata 52)*

**8.4.2** The architecture manual, which includes the instruction set but covers the whole machine, is the primary deliverable; the toolchain is advanced as needed to write and check it. *(D, errata 54)*

**8.4.3** Today the assembler and linker exist, with the atomics still to be added to the assembler and shared libraries still to be added to the linker; the pcc compiler back end passes 516 C tests on the simulator and on QEMU; the LLVM back end has its machine-code layer, checked against the project's own assembler on 62 programs and 6,304 instruction forms with no disagreement; the simulator and QEMU run a kernel-mode machine with exceptions, a memory-management unit, a timer and a console; no part of OpenBSD is ported. *(measured)*

**8.4.4** The long pole is the LLVM back end and clang. OpenBSD's kernel and base cannot be built by pcc, and the fallback of porting Unix/32V with pcc would not reach the goal, because it has no network stack and no `ssh`. *(D, errata 41 and the roadmap)*

**8.4.5** The path, in order, with a test for each step: finish the toolchain gaps (atomics, the user-memory guard, the ABI version); an LLVM back end that passes the C tests; clang, the compiler runtime and `lld`; a machine model for the operating system with an enumerating bus, a disk, a network card and an entropy source (virtio devices first, for speed); the kernel booting to single-user; the userland to a login prompt; the network and `sshd`, and then `ssh user@localhost -p 2222` gives a shell; and finally the same system on the FPGA. *(P, roadmap)*

*Commentary.* **Precedent.** OpenBSD's riscv64 port is its newest and smallest, and it measures at 35,600 lines of machine-dependent code, of which 14,873 are the core, 11,771 platform drivers, 4,513 the loader and 4,443 headers; arm64 is 61,613 and amd64 79,167. **Trade-offs.** The pdp64 port should be smaller than the riscv64 one in several places: no firmware tables to parse, uniform eight-register devices instead of a platform's driver zoo, a trivial loader, no cache-maintenance code and no floating-point state code; the core machine-dependent code of about 15,000 lines is the part that has to be written by hand *(estimate)*. The LLVM back end is estimated at three to six months for one experienced engineer, a figure that has not been tested. **Benefits.** An OpenBSD that can be logged into is a demonstration that the architecture, the toolchain and the operating-system interface are complete in the way that matters to users, and it forces every piece (the compiler, the linker, the bus, the devices, the boot) to work together. **Modern comparables.** OpenBSD ports to new architectures have followed this shape; the RISC-V port is the nearest in kind.

## 8.5 What remains open

Everything not yet settled is collected, with its options and its benefits, in appendix B; the ideas that nobody has yet turned into a decision are in appendix A. The principal open choices are the transport and interrupt controller (chapters 2 and 6), the details of the device layout, the interrupt controller and virtualization position, the vector-math position, and the several smaller instruction-set proposals.
