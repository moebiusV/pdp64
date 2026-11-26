# Does the pdp64 need condition codes? An experiment

I measured this on 2026-11-26. The details, tables and scripts are in `bench/flags/README.md`; this page is the short version.

**The question.** On the PDP-11 you compare two numbers with `CMP`, which leaves four one-bit **flags** behind (N: the result was negative, Z: zero, V: signed overflow, C: carry out), and then a branch such as `BEQ` or `BLT` reads them. Almost every arithmetic instruction sets the flags, so they are a small piece of hidden state that every instruction may write. The pdp64 has these flags, and it also has a second kind of branch, **compare-and-branch** (`CBEQ r0,r1,label`): it compares two registers (or a register and a small constant) and branches in one instruction, touching no flags. Newer machines (RISC-V, for one) have only that kind. So: if the compiler used compare-and-branch for every comparison, what would the flags still be good for?

**What I did.** I took the compiler for the pdp64 (pcc) and made a copy that never writes an instruction reading the flags for integer code. A comparison against a constant too big for the instruction, or against a number in memory, loads the operand into a spare register first and then does the compare-and-branch. A test of a result against zero (`AND ...; BEQ`) becomes `CBEQ r,#0`. A comparison whose answer is wanted as 0 or 1 becomes `MOVQ #1,r; CBNE a,b,L; CLR r; L:`. I compiled the same C sources with both compilers: 622 files of the OpenBSD C library, zlib, the kernel's crypto code, the math library and our own tests (the compiler could not read the other 482), and I ran 36 programs on our simulator (zlib compressing and expanding 50 KB, seven hash and cipher routines over 64 KB, sorting and string routines, and our own benchmark programs). Every program printed the same answer with both compilers, and with LLVM, the second compiler that exists for the machine and that never uses flags.

**What I found.**

| | baseline | no flags |
|---|---:|---:|
| code size, 622 files | 504,840 bytes | 507,586 bytes (**+0.54%**) |
| instructions in the code | 171,249 | 171,531 (+0.16%) |
| instructions executed, 36 programs | 70.65 million | 70.62 million (**-0.04%**) |
| bytes of instructions fetched | 206.7 million | 210.0 million (+1.6%) |
| cycles on the simulator's one-issue core | 104.8 million | 104.6 million (-0.2%) |

In the baseline the compiler already used compare-and-branch for about nine comparisons in ten, so little was left to change. The growth in bytes comes from a few sites: a comparison against a constant above 16 bits (`CMP r,#98304` is six bytes plus a two-byte branch; the no-flags form is ten plus four) and a comparison against memory. Our own test of this question was "under about 1% more bytes and fewer instructions executed means the flags are kept only because the PDP-11 had them". That is what I got. For compiled integer code, the flags are heritage.

**What I did not settle.**

1. **Floating point still needs them.** `FCMP` sets N, Z and V and a branch reads them; 201 places in the math library do this, and so does LLVM's output. Removing the flags means a new floating-point compare.
2. **Four branch conditions are short-ranged.** Compare-and-branch for the unsigned comparisons (higher, lower or the same and so on) has no six-byte form: against a register it reaches about 1 KB, and a farther target makes the assembler fall back to `CMP` plus a flag branch. That happened 3 times in the baseline and 46 times with no flags, and it is the only flag use left in the runs (0.013% of the instructions executed). The fix is six-byte forms for those four; I only estimated its cost (+0.04% in bytes).
3. **The programs are a sample**, mostly C library code. They have no interpreter and no floating-point program; the simulator charges no extra time for the comparison inside a compare-and-branch, which a real core pays for with a comparator in the branch unit (about 550 gates against about 180 for the whole flag register and the logic that picks a condition, in a core of 219,000 to 308,000).
4. **Carry.** `ADC` and `SBC` (add and subtract with the carry, for numbers wider than a register) are used by nothing: no compiled code and no assembly file contains them. The idiom "did the add overflow" occurs 6 times in 171,000 instructions and costs nothing extra without flags if it is used as a branch. A two-word add would take six instructions instead of two.

**What would go.** Four bits of the status word that are saved anyway, `CMP`, `TST`, `SET`, `ADC`, `SBC`, the fourteen flag branches, the flag-reading traps, and the question of which instruction writes which flag (for instance `fneg32` and `fabs32`, which are an `XOR` or an `AND` with the sign mask, would simply write nothing; today they set N and Z).
