# 10. Conclusion: from FPGA to silicon

[← manual index](00-index.md)

**The pdp64 is to be built first on an FPGA, with at least four cores and a clock aimed at 200 to 300 MHz, as an in-order core that an out-of-order design can follow; it aims to repeat none of the processor flaws of the last decade; and it reaches silicon only after an OpenBSD built by the project's own toolchain can be logged into over `ssh`.** The chapter is for a reader who has followed the PDP-11 from a cabinet of boards to a chip and asks what the pdp64's path to a chip is. It gives the first implementation and its estimated size (10.1, 10.2), the reasons the first cores are in order and how a faster one stays possible (10.3), the security aims (10.4), the finish line (10.5) and what remains (10.6). A figure tagged *(E)* is an estimate, not a measurement. A fact about another machine that could not be checked against a source on hand is marked *unverified*.

## 10.1 The first implementation: an FPGA

What you know: the PDP-11/70 was a processor of several boards, and DEC later put the PDP-11 on a few chips (the LSI-11, whose processor handbook is of 1975-76) and then on one (the T-11; all *unverified* here). A new architecture today starts one step earlier. An **FPGA** (field-programmable gate array: a chip whose wiring can be loaded again and again) holds a processor described in a hardware description language, a **soft core**. Its logic is built from **lookup tables** (LUTs: each a small memory that implements any function of six inputs), multiplier blocks and **block RAMs** (the RAM that the chip provides in fixed-size pieces).

**10.1.1** The first implementation is a soft core on an FPGA. *(D)* (R20 and R22, "modern fpga so insane high clock specs"; R24, "if we're implementing the 8502 in fpga")

**10.1.2** The clock the FPGA design aims at is 200 to 300 MHz. *(D)* (errata 99)

**10.1.3** The design supports at least four cores, and sixteen or more is the preferred ceiling that no decision may preclude; the initial device has four cores, hoped to fit the FPGA (R338: "for initial device 4 cores is enough hopefully that fits on the fpga"). *(D)* (errata 92)

**10.1.4** A complete core, with the floating-point unit, the memory-management unit, two 8 KB first-level caches and the bus bridge, is about 16,000 six-input lookup tables, 10 to 16 multiplier blocks and 11 block RAMs, with an error of about ±40%: the register file is 250 lookup tables of distributed RAM, the 64-bit ALU 600, the barrel shifter 450, the caches 300 and 500 plus 8 block RAMs, the bus bridge 600. The figures are for the original sixteen-register design; the decoder and the thirty-two-register file of the pdp64 have not been estimated separately. *(E)*

**10.1.5** Block RAM, not logic, is the scarce resource: the caches, the translation buffer, the framebuffer and the blitter's scratch memory compete for it. *(E)*

*Commentary.* **Chain.** PDP-11: a processor of boards, then of chips, each smaller than the last (10.2). VAX: the MicroVAX 78032 was the VAX reduced to a subset so that it fitted one chip (10.2). Soft cores: RISC-V's Rocket and VexRiscv are the usual FPGA reference points (*unverified*), and the plan ranks the compiler back end as the first schedule risk, as it is for any new architecture (`pdp64-fpga-plan.md`, section 11). The pdp64 is designed so that a first core fits an FPGA and the same description can go to silicon. **Trade-offs.** On an FPGA the 64-bit carry chain (the adder's chain of carries) is slow and sets the clock, the barrel shifter (the unit that shifts by any count in one step) is a large tree of multiplexers, and the flags serialise branch resolution behind the ALU. None of this argues for changing the instruction set. It says where pipeline stages go: a first-level cache that is indexed by the page offset and tagged with the physical address takes the translation buffer off the critical path, and a comparator for branch conditions that runs beside the ALU buys a stage (`pdp64-fpga-plan.md`, section 3; no core has been timed, so these are *unverified* expectations). The architecture helps in several places: one memory operand means one address generator, no deferred modes means address generation is one adder pass, the length comes from a prefix of the first parcel, there is no unaligned data path and no partial-register write (the same document, section 8). **Impact.** *Kernel:* none. *Compiler:* none. *Hardware:* the first device is a four-core design whose size is estimated in 10.1.4.

## 10.2 The chip: a transistor budget

What you know: how small a PDP-11 could be made. These figures are the project's historical table (`pdp64-isa.md`, section 10); the sources of the counts are not on this machine, so every one is *unverified*.

| Device | Year | Transistors | What it was |
|---|---|---|---|
| DEC T-11 | 1981 | about 12,000 | a complete PDP-11 integer core, no memory management, no floating point |
| ARM1 | 1985 | about 25,000 | 32-bit RISC, no memory management, no floating point |
| Motorola 68000 | 1979 | about 68,000 | 32-bit, orthogonal like the PDP-11; could not restart an instruction after a bus error |
| DEC J-11 | 1983 | about 120,000 (40,000 and 80,000 on two chips) | the full PDP-11/70: memory management, split instruction and data space, floating point |
| MicroVAX 78032 | 1984 | 125,000 | a subset of the VAX (175 of 304 instructions), no floating point |
| Intel 80386 | 1985 | about 275,000 | 32-bit, paging, segmentation |

**10.2.1** For a non-pipelined or short-pipeline implementation in a modern process, the whole core excluding caches is estimated at about 92,000 transistors. *(E)*

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

![The estimated transistors of a core](figures/conc-budget.svg)

**10.2.2** The bit unit, the block-move sequencer and the UTF-8 decoder together are about 6,200 of the 92,000 transistors, under 7% of the core; the fused multiply-add datapath is the largest single addition and the least negotiable. *(E)*

*Commentary.* **Chain.** The J-11 against the 78032 is the pair that shows what the instruction set costs: a complete PDP-11/70 with memory management and floating point in about 120,000 transistors against a VAX with its decimal, string-editing and H-float instructions removed and no floating point on the die in 125,000 (the project's reading of the table; *unverified*, and the two are not the same process, so only a rough comparison). The pdp64 sits below the 78032 with floating point and memory management included. **Trade-offs.** The estimate is not a measurement and excludes the caches, which dominate the area of a real chip. It was made for sixteen registers and the original encoding: a thirty-two-register file costs about twice the first row (*inference*), which brings the total to about 98,000, and the decoder for the prefix code has not been estimated. An implementation of the translation buffer as a content-addressable memory (one that compares an address against every entry at once) is larger than the figure assumes; the buffer's size and organisation are the implementation's choice (6.8). **Impact.** *Kernel:* none. *Compiler:* none. *Hardware:* a core of this size fits in a small process node with room for the caches and the bus controller.

## 10.3 In order first, ready for out of order

What you know: the PDP-11 executed one instruction at a time, in the order written. **In order** still means that. An **out-of-order** core looks ahead in the program, runs whichever instructions have their inputs ready and keeps the results hidden until it is sure the program, run in order, would have produced them; to run ahead past a branch it **speculates** (guesses which way the branch goes and runs on).

**10.3.1** The first implementations, on the FPGA and in silicon, are small in-order cores without speculation; the architecture is kept ready for a large out-of-order design. *(D)* (R220: "i'm ok with the fpga/asic being in order, but want to be ready for the out of order large scale design")

**10.3.2** The condition flags were the structural obstacle: with the PDP-11 rule 68.2% of compiled instructions wrote a flag and 1.5% read one, so the flags form two groups that nothing writes in part, and moves, loads, stores and the compare-and-branch instructions write none. *(D)*

**10.3.3** In-order and out-of-order cores may share a die if software can tell which is which; the architectural memory model and the instruction semantics are the same on every core. *(D)* (errata 92)

*Commentary.* **Chain.** One instruction set has often spanned in-order and out-of-order cores: ARM's small cores beside its large ones, RISC-V's Rocket beside the BOOM, x86 from the Pentium to the P6, Alpha from the 21064 to the 21264 (all *unverified*). The VAX's long, orthogonal instructions with many side effects are generally blamed for making its later fast implementations so hard (*unverified*; 1.4). The pdp64's answer is restartable instructions with no hidden state (9.2.6) and flags in two independent groups that can be renamed separately (9.3.4). **Trade-offs.** Readiness has a cost, visible here as the compiled-code size paid for the flag rules (0.39%, measured) and as design effort spent on a core that may never be built. The 68.2% and 1.5% are counts on the first compiler's output on 827 files; after the flag rules 16.7% of instructions write a flag (`pdp64-ooo-readiness.md`). **Impact.** *Kernel:* flags are not state that survives half an instruction. *Compiler:* a compare-and-branch instead of a test after a move, 0.39% more code. *Hardware:* a property fixed in the specification while it is still being written is cheaper than one retrofitted after silicon.

## 10.4 Security: what the design must not repeat

What you know: the PDP-11's protection was its modes and its memory-management unit, which checked an access before it happened. The flaws of the last decade came from machines that ran ahead of the check or whose timing depended on a secret. **Speculative execution** attacks (Spectre, Meltdown) read data that a protection check would refuse, through a trace the guess leaves in a cache. A **timing channel** is any way a program learns a secret by how long something takes. **Rowhammer** flips bits in the DRAM chips by reading a row of memory hard enough to disturb its neighbours.

**10.4.1** The design does not repeat the processor flaws of the last decade that needed mitigations: no Rowhammer, no Spectre, no timing-channel attacks (R253: "no hammer-row, no spectre, no timing channel attacks"). The flaws are documented so that they are not repeated, and the rules that keep a faster core from repeating them are collected in the hardware-vulnerabilities report. *(D)* Details pending ([J.10.1](appendix-j-open.md#j101)).

**10.4.2** An in-order, non-speculative core has none of the speculative side channels of the last decade, and an out-of-order core must keep that property. *(D)*

**10.4.3** At least one core is a secure core, with every timing channel removed (chapter 7). *(D)*

**10.4.4** A bit `DIT` in the status word promises data-independent timing while it is set (9.3.7). *(D)* Open: the position of the bit and which instructions are constant-time while it is clear ([J.9.2](appendix-j-open.md#j92)).

*Commentary.* **Chain.** The PDP-11 and the VAX had no speculation, and their protection was architectural, so the flaws of this section had no place to arise; they came with the speed-ups of the 1990s and 2000s, branch prediction and out-of-order execution (*unverified*). x86 and AArch64 answered the flaws with mitigations in software and microcode (page-table isolation, speculation barriers, flushes); the report lists them (appendix F). The pdp64's answer is to state, before a fast core exists, the rules that it must obey: no speculation across protection domains, no predictor state shared across a privilege boundary without a flush, no data-dependent prefetcher, a named set of instructions with a timing independent of their operands. The report numbers them C1 to C16 (section 5). The report's status column of 2026-10-22 marked four of the sixteen as not met: the published constant-time set (C7), the cache and translation-buffer rule (C9), the memory controller's rule against Rowhammer (C11, a property of the memory chips and the controller) and the default-deny rule for bus masters (C12); the architecture text has since taken up parts of two (the IOMMU of 2.11, the `DIT` bit of 9.3.7). **Trade-offs.** A constant-time mode costs speed, so the secure core carries the promise and the others keep their speed (the author's remark, R264: "for non-sensitive things, constant time isn't a priority"). **Impact.** *Kernel:* fewer mitigations to write in every entry path. *Compiler:* none. *Hardware:* each rule is a constraint on an out-of-order design, not a feature of the in-order one; the pain-points report finds the pdp64 avoids by design the largest classes of kernel pain: barriers (memory is sequentially consistent), floating-point state, a faulting entry, remote translation flushes and the speculative family (`kernel-pain-points.md`, the rows marked DESIGNED AWAY).

## 10.5 The finish line

What you know: Unix went from the PDP-11 to the VAX as UNIX/32V (June 1979, a direct port of Seventh Edition Unix) and then, in 3BSD, gained virtual memory; the sources of all three are on this machine. The author's chain for the pdp64 (R216, R230) went from "if we are going straight to 3bsd why not openbsd" to "forget 3bsd we'll do 32v port if openbsd proves too hard, but i suspect it is doable".

**10.5.1** Before silicon the project delivers five things: an assembler, a linker, an LLVM compiler back end, an emulator, and a port of OpenBSD that can be logged into with `ssh` (R265: "this pdp64 project final goal (before we put it on actual silicon) is assembler linker compiler backend (llvm) emulator and port of openbsd we can ssh into"). *(D)*

**10.5.2** The architecture manual, which includes the instruction set but covers the whole machine, is the primary deliverable; the toolchain is advanced as needed to write and check it (R267, R266). *(D)*

**10.5.3** The path to OpenBSD goes through the LLVM back end and clang. If OpenBSD proves too hard, a port of Unix/32V is the fallback (R230), and it would not reach the goal of 10.5.1: the Unix/32V sources have no network code (no `inet`, `tcp` or socket files) and so no `ssh`. *(D)*

**10.5.4** The finish line is reached through the LLVM back end and clang, a machine model of the system for the operating system with virtio devices, a booting kernel and userland, and the network with `sshd`, until `ssh` to the machine gives a shell; the same system then goes on the FPGA. *(D)* Details to be determined (the order of the steps and the test for each).

![The finish line: what builds what, and the test](figures/conc-finish.svg)

*Commentary.* **Chain.** Unix reached the VAX as Unix/32V, and the VAX's virtual memory came in 3BSD; OpenBSD descends from that BSD line, and its newest port, riscv64, is the nearest measured precedent: 35,600 lines of machine-dependent code, of which 14,873 are the core, 11,771 platform drivers, 4,513 the loader and 4,443 headers; arm64 is 61,613 and amd64 79,167 (counted in the OpenBSD tree on this machine, `roadmap.md`). OpenBSD builds its base with clang on arm64 and riscv64, and pcc cannot build its kernel or its userland (the kernel uses GNU C extensions and inline assembly); both are *unverified* here, and they are why the compiler is the long pole (the roadmap's assessment, an estimate). **Trade-offs.** The pdp64 port should be smaller than the riscv64 one in several places: no firmware tables to parse, one virtio interface for the devices instead of a platform's driver zoo, a trivial loader, no cache-maintenance code and no floating-point-state code; the core machine-dependent code of about 15,000 lines is the part that has to be written by hand *(E)*. The LLVM back end, estimated at three to six months for one engineer who has written one before, is the largest single item *(E)*; the figure has not been tested. **Benefits.** An OpenBSD that can be logged into shows that the architecture, the toolchain and the operating-system interface are complete in the way that matters to users, and it forces every piece (the compiler, the linker, the bus, the devices, the boot) to work together. **Impact.** *Kernel:* the port is the test of chapters 4 to 7. *Compiler:* it needs the atomics, thread-local storage and position-independent code of appendix D. *Hardware:* nothing beyond the architecture.

## 10.6 What remains

The questions the architecture has not yet answered are collected, chapter by chapter, with their options, in [appendix J](appendix-j-open.md); the entries `J.2.n` to `J.10.n` belong to chapters 2 to 10. A decision whose details are still to be worked out carries the words *Details pending* or *Details to be determined* in its chapter. The proposals that nobody has decided are in [appendix H](appendix-h-proposed.md), and what has been put off is in [appendix I](appendix-i-deferred.md).
