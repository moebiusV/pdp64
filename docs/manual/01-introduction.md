# 1. Introduction

[← manual index](00-index.md)

**The pdp64 is a 64-bit successor to the PDP-11, designed to be as pleasant to program as the PDP-11 and the VAX-11 were, and as small to build as the PDP-11 was.** It is a little-endian machine with sixteen 64-bit registers, instructions of two, four or six bytes, and the PDP-11's addressing modes and branches, brought up to date with what fifty years of compilers and operating systems have shown to matter. It is a 64-bit machine that supports several cores from the start (symmetric multiprocessing, chapter 7), and it is designed to be efficient with in-order and out-of-order execution implementations (1.4.4). This chapter says why it exists, what made its ancestors good, and the principles the rest of the book follows.

## 1.1 Why the machine exists

**1.1.1** The PDP-11 and the VAX-11 were pleasant, even fun, to program in assembly language.

**1.1.2** Afterward computer design went in many directions, and that pleasure was largely lost.

**1.1.3** The pdp64 carries it forward, using the lessons of the last fifty years: which instructions are needed to get things done and which are not, what a processor is actually used for, and which instructions it needs the most.

**1.1.4** The PDP-11 is a source, not an obligation. What earned its place stayed, what did not was dropped, and what fifty years showed to be missing was added.

*Commentary.* **Precedent.** The claim in 1.1.1 is old and widely made of the PDP-11: a small, regular instruction set that a programmer could learn in a week and keep in mind, with a set of addressing modes that fit the C language so closely that the language and the machine seem to have grown together. **Improvements.** The measurements overturned several received ideas, which is the reason the project looked rather than copied. A second unsigned multiply turned out to be the same instruction as the first, while the instruction that returns the *high half* of a product, which multi-precision arithmetic needs, was missing. A rotate by a register count has almost no users, because cryptographic code rotates by constants. A divide is rare, because compilers turn division by a constant into a multiply and a shift. Dedicated absolute-value, minimum and maximum instructions are worth under a tenth of a percent of compiled code. And CRC instructions become unnecessary once a carry-less multiply exists. **Benefits.** A machine built on these findings is small enough for a single engineer to hold in mind, and, as later chapters show, small enough to fit in a modest FPGA. **Modern comparables.** The same re-examination produced the RISC designs of the 1980s and, more recently, the compact RISC-V and LoongArch instruction sets; the pdp64 differs by keeping the PDP-11's memory operands, addressing modes and variable-length encoding where those were found to save code and to cost little.

## 1.2 What made the PDP-10, the PDP-11 and the VAX-11 good to program

**1.2.1** The PDP-10 gave a programmer one word per instruction that said everything: the operation, the register, the index register, the indirect bit and the address.

**1.2.2** The PDP-10's registers were also memory: the sixteen accumulators answered to the addresses 0 to 15.

**1.2.3** The PDP-10 had half-word and byte operations, stack and skip instructions, and a procedure call that was one instruction.

**1.2.4** The PDP-11 made every instruction and every addressing mode available with every register, so that the language had few exceptions to remember.

**1.2.5** The PDP-11's program counter and stack pointer were ordinary registers, and its autoincrement and autodecrement modes made `*p++` and `*--p` single instructions.

**1.2.6** The PDP-11 had no input or output instructions: a device was a few memory locations, and a driver was an ordinary program.

**1.2.7** The VAX-11 widened the PDP-11 to 32 bits and added three-operand arithmetic, a complete virtual-memory system, and instructions for the jobs programs actually do: procedure calls, queues, character strings, array indexing and polynomial evaluation.

*Commentary.* **Precedent.** These are the qualities the author has in mind, stated here as the book's starting point rather than as a history. The PDP-10's simplicity of format and its habit of making the machine's own state addressable (1.2.1, 1.2.2) are the origin of the idea that the machine should hold together in the head. The PDP-11's orthogonality (1.2.4) is the property that mattered most to assembly programmers and, later, to compiler writers: an instruction that takes a register takes an address, an immediate or a stack slot with the same syntax. Its memory-mapped devices (1.2.6) are the reason the pdp64's devices are still eight addresses each (chapter 5). **Trade-offs.** Each of these qualities had a price that the later machines paid. The VAX-11's richness (1.2.7) bought programmability and cost an unbounded amount of hidden state in its longest instructions, so that a page fault in the middle of a character move could not be resumed without a special bit in the status word. The Motorola 68000, which took the PDP-11's orthogonality and widened it, could not restart an instruction after a bus error and so could not support demand-paged virtual memory until its successor patched the problem. **Improvements.** The pdp64 keeps what made programming pleasant and removes what made implementation hard: no hidden instruction state (every instruction can be restarted), at most one memory operand, a fixed small maximum instruction length, and no mode bits that change what unrelated instructions mean unless their benefit outweighs the cost. **Benefits.** The measurements in the instruction-set chapter show where this paid off: the processor fits in about 16,000 FPGA lookup tables and the compiler's code is the size of `gcc -Os`. **Modern comparables.** Of today's architectures, x86-64 kept the memory operands and variable-length encoding of this lineage; AArch64 and RISC-V chose fixed-length register-to-register encodings; the pdp64 sits between them, closer to x86 in the form of its instructions and closer to RISC-V in the discipline of its encoding.

## 1.3 More minimal than its ancestors, where hindsight allows

**1.3.1** In several ways the pdp64 is more minimal than the PDP-11 and the VAX-11: it gives up theoretical completeness where fifty years of use showed the completeness was never exercised, and it spends what that saves on power that was.

**1.3.2** Not every instruction works with every addressing mode on every operand: at most one operand of an instruction is a memory reference. *(D)*

**1.3.3** The deferred addressing modes are gone; an indirection is a `JMPI`, a `CALLI` or an ordinary load. *(D)*

**1.3.4** The ALU has one width, there is no arithmetic in the narrow sizes, and there is no conversion opcode group: conversions are moves. *(D)*

**1.3.5** There is one rotate direction, and no slot exists only to complete a table.

**1.3.6** The VAX's packed decimal, string editing and `CALLS`/`CALLG` procedure-call instructions are absent. *(D, instruction-set text, "explicitly rejected")*

**1.3.7** There are no transcendental instructions, no separate floating-point register file and no rounding-mode bits. *(D)*

**1.3.8** What the saving buys is power that programs use: a bit unit (population count, count of leading and trailing zeros, byte reversal, bitfields, a carry-less multiply), block operations that restart from their registers, a fused multiply-add with the IEEE exception flags, the full set of atomics, UTF-8 instructions, and a user-memory guard. *(D)*

*Commentary.* **Precedent.** The PDP-11 was orthogonal, any operation with any mode on any register, and the VAX carried that to completeness: every operation in every data type, with up to six operands, each operand of any mode. Both were designed when memory was dear and compilers were weak, and the completeness did two things at once: it made assembly programming regular and pleasant, and it made a compiler's job simple. **Trade-offs.** The completeness was never free. It bought a decoder that had to parse specifier after specifier before the next instruction's address was known, and an instruction that could fault in the middle with unbounded state to save. What hindsight lets the pdp64 do is separate the two benefits: keep the regularity that programmers and compilers use (every register is general, every mode means the same thing everywhere it is allowed) and drop the completeness that nobody exercised (a memory-to-memory arithmetic instruction, a deferred mode on every operand, a sized version of every operation). The price is a few more instructions in rare cases, such as a load and a store where the VAX had one memory-to-memory move. **Improvements.** Each piece of dropped completeness was weighed against what it freed: the one memory operand lets the fault matrix collapse to three rows with the third empty and pays for sixteen registers and a 12-bit displacement in the same parcel; dropping the sized ALU removes byte-lane multiplexing and partial-register writes altogether; dropping the transcendentals leaves the `FMA` datapath, which is what accurate library maths is built from. **Benefits.** The decoder is small, the exception machinery is small, and the die area that completeness would have used goes to a bit unit and a block-move sequencer that together cost less than 5% of the core. **Modern comparables.** The RISC machines of the 1980s went further and made every instruction register to register except loads and stores; x86 kept one memory operand and survived on it; the pdp64 takes the middle position, which keeps the compact code of a memory operand and the restartability of a load/store design.

## 1.4 The principles

**1.4.1** The design follows these principles, in this order: **code size**; **easy recoverability**, meaning fewer possible errors and an easier recovery path, so less recovery code; **speed and efficiency through fewer gates and tighter hot loops**, by careful choice of instructions. *(D, README; recorded by the author 2026-10-22)*

**1.4.2** All the rules are soft rules: a rule gives way when breaking it is worth more than it costs, with the cost written down. *(D, errata 42)*

**1.4.3** Between two designs that both work, prefer by this order: the one with no strange side effects (an instruction does what its name says and nothing else); the one that does not push an existing instruction into a longer encoding; and the simpler one (do not multiply entities without benefit).

**1.4.4** The architecture is designed to be efficient with in-order and out-of-order implementations. The first implementations are in order; nothing is specified in a way that is safe only because the core does not speculate or reorder, and nothing is specified that an out-of-order core could implement only at a large cost. *(D, the author 2026-10-23, errata 68)*

**1.4.5** An instruction is judged by its weight in the loops where it is used, not by how often it appears: a rarely used instruction that sits inside a critical, tight hot loop can earn its place. The measure is profile-weighted (executions multiplied by the instructions and bytes it saves), not a static count. *(D, the author 2026-10-23, errata 68)*

*Commentary.* **Precedent.** The earlier statement of the constraints, still in the instruction-set text, ranked low transistor count first, bounded fault surface second, pleasantness in assembler third, a good compiler target fourth and code density fifth. The author's present ordering puts code size first and folds the gate count into the third principle with speed. The two orderings agree on almost everything, because a small, regular machine is also compact in code and cheap in gates; they differ in which wins when they conflict, and this book follows the present one. **Trade-offs.** "Easy recoverability" is the principle that most often changes a decision. It means counting the cost of an option not only in gates and bytes but in the code a kernel must write to handle its failures: a feature that adds a new fault, a new error return or a new half-finished state costs recovery code in every system that uses it, and a feature that makes an operation repeatable from the start costs none. **Improvements.** The soft-rules principle replaced an earlier text that listed two rules as having no exceptions: "no mode bits" and "natural alignment of quad accesses". They remain strong defaults, because breaking either has a large cost, but each is now weighed like any other choice. Three mode bits are accepted in the design on those terms: the translation-enable bit that is set once at boot, the user-memory guard that lives in the status word, and the sticky floating-point flags, which never change what an instruction does. **Benefits.** A reader can tell why a choice was made by asking which principle it serves. **Modern comparables.** Most architectures state no priorities; the RISC-V project's published principle of keeping the base small and the extensions optional is the nearest in spirit.

## 1.5 What has been built and measured

**1.5.1** The machine is specified by machine-readable grammars; the assembler, linker, simulator, a compiler back end and the QEMU target are generated from or checked against them, so that the numbers cannot drift apart.

**1.5.2** On 827 real source files that every compiler accepts, the first compiler's output, in code and data, is within 0.2% of `gcc -Os` and 6.5% smaller than `clang -Os` on amd64, using 1.19 and 1.10 times as many (shorter) instructions.

**1.5.3** 516 C test programs pass on the simulator and on QEMU.

**1.5.4** The finish line before silicon is an assembler, a linker, an LLVM compiler back end, an emulator, and a port of OpenBSD that can be logged into with `ssh`. *(D, errata 52)*

*Commentary.* **Precedent.** The habit of generating every tool from one description, rather than writing each and hoping they agree, is the discipline that other instruction-set projects adopted late; here it was the starting rule, and it is why a change to an opcode number is made once. **Trade-offs.** The measurements are of compiled C at the compiler's size-optimising setting; they are static counts of what is written, not run-time measurements, and the compiler is one of two planned (the LLVM back end, which OpenBSD needs, is at the stage where its assembler and object writer agree with the project's own on every form tested). **Benefits.** The comparison gives the architecture a number against which later changes are measured: the last change to the flags cost 0.39% in code size and was accepted for the benefit it gave to faster future implementations. **Modern comparables.** `gcc` and `clang` at `-Os` are the standard measuring sticks for code size on x86-64 and AArch64; the pdp64 figure is compared with them on the same source files.

## 1.6 Does the instruction set matter?

**1.6.1** The instruction set is not interchangeable with any other: it fixes what every implementation must preserve, and so what a processor costs to build, to verify, to program and to secure.

**1.6.2** The common view, that a good implementation hides the instruction set, is true of one thing: the peak speed of a very large core, where a great deal of hardware can absorb almost any encoding.

**1.6.3** It is not true of the cost of a small core, the size of the code, the amount of software a system needs, or the number of ways a system can fail; those follow the instruction set, and they can be measured.

**1.6.4** Each of the rows below is a measurement or an estimate from this project, and each is explained in the chapter named beside it.

| What differs | The figure | Where |
|---|---|---|
| The logic of a complete implementation, same company and era | the PDP-11's T-11, a full integer core, was about 12,000 transistors; the MicroVAX 78032, a subset of the VAX with no floating point, about 125,000 | 10.1, 10.2 |
| What it takes to find where the next instruction starts | pdp64: two bits of the first parcel; PDP-11: both operand specifiers; x86: prefixes, opcode, ModR/M and SIB in sequence; VAX: every specifier in order | 9.4 |
| Whether flags block a faster implementation | 68.2% of compiled instructions wrote a flag and 1.5% read one, so the flag rules were changed at a measured cost of 0.39% in code size | 9.3, 10.3 |
| Size of compiled code | for the same 827 source files and the same compiler family, the pdp64 output is 0.86 times the size of its amd64 output, and 1.002 times `gcc -Os` | 1.5 |
| System-call path, instructions in and out (paper estimates) | x86-64 Linux about 45 and 30; AArch64 about 60 and 45; RISC-V about 66 and 45; VAX about 11 and 8; m68k 6 and 8; pdp64 4 to 5 and 4 | 6.5 |
| Lines of kernel code to start a second core | x86: 1,528 plus 1,258 of real-mode code; arm64: 124 or 127; RISC-V: 108 or 58; pdp64: one register write | 4.5, 7.8 |
| Machine-dependent code in an OpenBSD port | riscv64 35,600 lines; arm64 61,613; amd64 79,167 | 10.4 |
| Errata, workaround and quirk lines per 1,000 code lines in Linux's architecture directories | x86 0.8; arm64 0.7; arm 0.5; powerpc 0.4; mips 0.3; m68k 0.1; riscv 0.1; s390 0.0 | pain-points report |
| Hardware-erratum options in Linux's configuration | arm64 64; arm 32; riscv 14 | pain-points report |

*Commentary.* **Precedent.** The view that instruction sets are equivalent has real support. Published comparisons of x86 and ARM implementations (the 2013 study usually cited is "Power Struggles: Revisiting the RISC vs. CISC Debate on Contemporary ARM and x86 Architectures", an unverified citation here) found that at the same performance level the instruction set explains little of the difference in power or speed, and the very large cores of both families have converged. The pdp64 does not dispute that. **Trade-offs.** The claim is about steady-state performance of comparable large cores, and the table is about other costs. The table's figures are measurements of real machines and real software, not controlled experiments: some of the differences between architectures in the Linux figures are partly a matter of age and deployment (x86 is the oldest and most widely deployed), and the system-call and start-up figures are estimates and line counts of what is written, not run times. They show that the instruction set is correlated with these costs, and the chapters show the mechanism in each case. **Improvements.** Each row is a place where this design made a different choice from the architecture it is compared with, and the choices were made against these costs, not against peak speed. **Benefits.** A reader who thinks the instruction set does not matter can check any row against its chapter: the answer is in what the instruction set obliges an implementation to do (precise exceptions, ordering, flag behaviour, instruction length, restart) and in the code a system must then write. **Modern comparables.** RISC-V's own case for a clean base instruction set and x86's survival by microarchitecture are the two sides of the argument.

## 1.7 How the book is organised

**1.7.1** Chapter 2 is the bus. Chapter 3 is graphics: the terminal, based on the C64 and the Blit and modernised, and how it drives HDMI and the other ports. Chapter 4 is boot. Chapter 5 is the device driver model. Chapter 6 is the kernel: modes, exceptions and memory management. Chapter 7 is multiple processors. Chapter 8 is vector work, AI and array languages, done by devices. Chapter 9 is the instruction set. Chapter 10 is the path to silicon.

**1.7.2** Each section states its aphorisms first and its commentary after; the status tag *(D)* or *(P)* marks what is decided and what is proposed.

*Commentary.* **Precedent.** The form follows the old commentary traditions, in which a short text can be read straight through and the discussion of each line sits beneath it; and the layout of the classic CPU manuals for the reference material, in which every instruction has a fixed entry (errata 56 and 57). **Benefits.** A designer who wants only the architecture reads the aphorisms; one who wants the reasons reads on.
