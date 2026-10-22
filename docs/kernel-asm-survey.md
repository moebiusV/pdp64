# What real kernels write in assembly: a survey of Linux, FreeBSD, NetBSD and OpenBSD, and what pdp64 can learn from it

[← pdp64 index](../README.md)

**Status: research survey, 2026-10-22.** Written against the pdp64 design as of errata 40 (`docs/errata.md`, items 32 to 40), System v1 (`pdp64-system-architecture.md` section 15) and the out-of-order readiness review (`pdp64-ooo-readiness.md`). It changes no ISA text: every recommendation here is a proposal for the author. The data and the script are in `docs/codegen-data/kernelasm/` and `tools/kernelasm.py`; every number below says how it was measured.

## Contents

1. [The question](#1-the-question)
2. [Sources and method](#2-sources-and-method)
3. [The big picture: how much assembly, and where](#3-the-big-picture-how-much-assembly-and-where)
4. [The compiler-invisible instructions, class by class](#4-the-compiler-invisible-instructions-class-by-class)
5. [Architectures at a glance](#5-architectures-at-a-glance)
6. [Linux against the BSDs](#6-linux-against-the-bsds)
7. [What pdp64 should take](#7-what-pdp64-should-take)
8. [Entry, exit and context-switch path lengths](#8-entry-exit-and-context-switch-path-lengths)
9. [Part II (not yet written)](#9-part-ii-not-yet-written)
10. [What this survey does not show](#10-what-this-survey-does-not-show)
- [Appendix A: the compiler-invisible inventory, per architecture](#appendix-a-the-compiler-invisible-inventory-per-architecture)
- [Appendix B: class by architecture by kernel](#appendix-b-class-by-architecture-by-kernel)
- [Appendix C: how the path lengths were counted](#appendix-c-how-the-path-lengths-were-counted)
- [Appendix D: coverage matrix, what was surveyed and what was missing](#appendix-d-coverage-matrix)

## 1. The question

A compiler can only emit what its code generator knows how to ask for. Ask a C compiler to write `a + b` and you get an add; ask it to switch the processor to user mode and it has no way to say so, because C has no word for "return from an exception". Every operating system kernel therefore contains a small amount of **hand-written assembly** (programs written by a person in the processor's own instruction names, not generated from C). The authors of those kernels wrote assembly exactly where C cannot do the job: reading and writing privileged registers, entering and leaving the kernel, switching from one thread to another, invalidating the translation cache, doing an atomic update, touching user memory from kernel code, waiting for an interrupt.

That makes the hand-written assembly of a kernel a precise inventory of what an instruction set must offer beyond what compiled code uses. pdp64 already learned this once. The author added `pushx` and `popx` (save and restore the exception state, `EPC` and `EPSW`, in one instruction each; errata 37) because the System v1 entry path needs them on every nested kernel entry and a compiler will never emit them. This survey asks the same question on a larger scale: **which instructions do real kernels rely on that C compilers do not emit, on every architecture, and which of them does pdp64 already have, cover by a short sequence, or lack?**

The method is plain. Count the instruction mnemonics (the instruction names, such as `swapgs` or `eret`) in the hand-written assembly of four kernels on fourteen architectures; count the same names in what clang and gcc generate for the project's "fair corpus" of ordinary C; the names that kernels use and compilers (almost) never emit are the **compiler-invisible** instructions. Then sort them by purpose and compare with pdp64.

## 2. Sources and method

**Sources** (shallow, blobless, sparse clones, kept outside the repository in `~/claude/kernel-src/`; nothing from them is copied into the repository, only counts of mnemonic names):

| Kernel | Repository | Revision | Date of revision |
|---|---|---|---|
| Linux | github.com/torvalds/linux | `7be4bc52fd9e0e55dc9a2e0232b89427d2c4b614` | 2026-10-21 |
| FreeBSD | github.com/freebsd/freebsd-src | `3200a274272d28cf6d2385a8ea46959f313866de` | 2026-10-22 |
| NetBSD | github.com/NetBSD/src | `cdcd52a8183344cabc6a4296b4bbe7e7c5fd3cdc` | 2026-10-21 |
| OpenBSD | github.com/openbsd/src | `2114d7b7c8fbfd8d285dd7b5b5eb44e1f6b70f55` | 2026-10-22 |

The directories taken are listed in `docs/codegen-data/kernelasm/sources.txt` (Linux `arch/<a>/{kernel,lib,mm,boot,include,entry,kvm}` for eleven architectures plus a few more; FreeBSD `sys/{amd64,i386,x86,arm64,arm,riscv,powerpc}`; NetBSD `sys/arch/` for thirteen families and `sys/lib/libkern/arch`; OpenBSD `sys/arch/` for thirteen families). Excluded on purpose: `crypto` directories (SIMD cipher kernels would drown the statistics), the user-space `vdso` pages, linker scripts, device-tree sources, and the large floating-point emulation packages of m68k (Linux `fpsp040`, `ifpsp060`, `math-emu`; NetBSD `060sp/dist`). Coverage is tabulated in Appendix D.

**Extraction.** Assembler files (`.S`, `.s`) are read statement by statement: comments, preprocessor lines and labels are removed, the line is split at `;`, and the first word is the mnemonic. Bodies of `#define` macros in assembler files are kept, because kernels keep instructions there. A word with an upper-case letter is a macro invocation and is counted separately (`kernel_macros.csv`), except for a small table of macros that are one instruction (such as `SWAPGS` or `RFI`). In C and header files every `asm`, `__asm__`, `asm volatile`, `asm goto` and `asm_inline` is found, the string literals of its template (up to the first colon) are joined, `\n` is turned into a separator, and the result is parsed like assembler; a few well-known identifier macros between the strings (`LOCK_PREFIX`, `_ASM_MOV`) are expanded, and strings that are arguments of `ALTERNATIVE`-style macros are included. A second pass resolves macros whose mnemonic is a stringized argument. **Normalisation** is applied identically to the kernel side and to the compiler side so that the two can be compared: x86 size suffixes and condition codes are folded (`movq` and `movl` are `mov`; every `jcc` is `j.cc`), `lock` and `rep` stay part of the name (`lock cmpxchg`, `rep movs`); ARM 32-bit condition codes and the flag-setting `s` are removed; AArch64 `b.eq` is `b.cond`; RISC-V `.aq`/`.rl` and the compressed `c.` prefix are removed; PowerPC record and hint suffixes are removed; SPARC and m68k assembler synonyms and size suffixes are folded; VAX operand-count suffixes are removed (`addl3` is `addl`). Details are in the header of `tools/kernelasm.py`.

**Compiler side.** The assembly files of the comparison agent's fair corpus in `/tmp/p64opt/archcmp/<dir>/*.s` (gcc and clang, `-Os`), merged per family: x86 four directories (1,280,687 instruction lines), AArch64 two (616,592), ARM 32-bit three (930,218), RISC-V four (1,297,230), MIPS one (393,696), PowerPC four (1,434,267), LoongArch two (639,932), m68k two (752,766), SPARC two (696,304), s390 two (535,703), VAX one (253,923); pdp64 itself (336,408) is for reference. **Alpha, PA-RISC and m88k have no compiled data** (clang 21 has no target for them), so for those three the "compiler-invisible" column is not a measurement: all their kernel mnemonics are listed and marked with an asterisk.

**Definition.** A kernel mnemonic is *compiler-invisible* when its count in the family's compiled corpus is below 0.001% of that corpus's instructions (below 1 in 100,000). Most are not just rare but absent. The threshold is in `tools/kernelasm.py` (`do_join`).

**Classification.** Each compiler-invisible mnemonic is assigned a purpose by a table in the tool (`CLASS_TABLE`, plus a few regular-expression rules); what no rule matches is `other` (assembler pseudo-instructions, SIMD and cryptographic instructions, and the long tail). The classes are the ones of the task brief plus three the data asked for (interrupt masking, I/O and device access, speculation control).

**Validation.** Three checks were made.
(1) *Per-file spot checks.* For eight hand-picked files the tool's count of a mnemonic was compared with a plain regular-expression count of lines beginning with it. The table is below; where they differ, the reason is understood (for `push` the raw regex counts only the first word of a line after a tab, the tool also counts macro bodies and `;`-separated statements; for m68k `moveml` the tool reports `movem` after normalisation).
(2) *Sample dumps.* `tools/kernelasm.py sample FAMILY KERNEL N` prints the mnemonic histogram of random assembler files; those for VAX, x86, AArch64, m68k, Alpha and SPARC were read against the sources, which found and fixed: assembler directives without a dot (m68k `global`), operand fragments at the start of continued strings (`x0,`, `ishst`), macro names that coincide with mnemonics (`mfspr()` as a C macro hid the real instruction until C macros were excluded from the macro filter), and SPARC/m68k/VAX synonyms that made ordinary instructions look invisible.
(3) *Whole-tree comparison.* Counts per kernel and mnemonic against a word search of the whole family's files: the tool is always lower than the raw count, because the raw count includes comments, function names such as `wrmsr()` and user-space stubs; ratios run from 9% to 100%.

| File (kernel) | Mnemonic | Tool count | Raw regex count |
|---|---|---:|---:|
| `arch/x86/entry/entry_64.S` (Linux) | `swapgs` | 15 | 15 |
| `arch/arm64/kernel/entry.S` (Linux) | `eret` / `msr` / `mrs` / `isb` | 2 / 20 / 18 / 6 | 2 / 20 / 18 / 6 |
| `sys/arm64/arm64/exception.S` (FreeBSD) | `stp` / `ldp` / `msr` | 19 / 17 / 10 | 19 / 17 / 10 |
| `sys/arch/riscv64/riscv64/locore.S` (OpenBSD) | `csrw` / `sfence.vma` | 9 / 5 | 9 / 5 |
| `sys/arch/vax/vax/subr.S` (NetBSD) | `rei` / `mtpr` / `ldpctx` / `svpctx` | 9 / 16 / 4 / 2 | 9 / 16 / 4 / 2 |
| `sys/arch/vax/vax/subr.S` (NetBSD) | `mfpr` | 12 | 14 (two inside comments) |
| `sys/arch/m68k/m68k/trap_subr.s` (NetBSD) | `rte` | 6 | 6 |
| `arch/powerpc/kernel/exceptions-64s.S` (Linux) | `rfid` / `hrfid` / `mfspr` / `mtspr` | 1 / 1 / 21 / 17 | 1 / 1 / 21 / 17 |
| `sys/arch/sparc64/sparc64/locore.s` (OpenBSD) | `wrpr` / `rdpr` / `membar` / `done` | 185 / 122 / 113 / 3 | 185 / 122 / 113 / 3 |
| `sys/arch/sparc64/sparc64/locore.s` (OpenBSD) | `retry` | 28 | 26 (two after a label on the same line) |
| `arch/x86/entry/entry_64.S` (Linux) | `push` | 48 | 2 (raw regex does not see `pushq`, the tool folds the size suffix) |
| `sys/arch/m68k/m68k/trap_subr.s` (NetBSD) | `moveml` | 0 (counted as `movem`, 23) | 23 |

*Whole-tree check* (tool count against a word search of the same family's files in the same kernel, comments and function names included): x86 Linux `swapgs` 19 against 57, `sysret` 3 against 34 (the rest are macro uses such as `SYSRETQ`, comments and function names), x86 FreeBSD `wrmsr` 56 against 217 (C wrapper calls), AArch64 OpenBSD `mrs` 67 against 69, RISC-V Linux `csrrw` 11 against 11, MIPS NetBSD `mtc0` 221 against 242, VAX `ldpctx` 4 against 8, SPARC NetBSD `wrpr` 324 against 333, Alpha Linux `call_pal` 40 against 43, LoongArch Linux `ertn` 9 against 14. Two kinds of disagreement were found and left: Linux AArch64 `ldtr` (0 against 7) and Linux RISC-V `fence`, both through macros.

**Known blind spots of the extraction** (they bias counts downward, never upward): instructions hidden behind macros (Linux RISC-V `fence` is written through a macro, so only 1 Linux use is seen against 63 in the BSDs; Linux AArch64 `ldtr`/`sttr` appear through `USER()` wrappers, so Linux shows 0 against 36 in NetBSD and OpenBSD; Linux x86 atomics partly through `LOCK_PREFIX` patterns); mnemonics supplied as macro arguments that the second pass cannot resolve; `.byte`/`.inst`-encoded instructions (counted in `kernel_extraction_stats.csv`: 18 in Linux x86, 47 in Linux ARM, 50 in Linux m68k, 44 in Linux SPARC, a few elsewhere); and the static nature of every count (a count is the number of times an instruction is *written*, not how often it executes).

## 3. The big picture: how much assembly, and where

| Architecture | Kernel | asm files | asm lines | inline asm blocks | distinct mnemonics | statements in .S/.s | statements in C/H | distinct classified compiler-invisible | their occurrences |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| x86 (i386, amd64) | linux | 73 | 13224 | 598 | 207 | 4822 | 1116 | 113 | 740 |
| x86 (i386, amd64) | freebsd | 35 | 10285 | 386 | 175 | 5028 | 505 | 110 | 762 |
| x86 (i386, amd64) | netbsd | 82 | 20406 | 101 | 148 | 7719 | 135 | 73 | 673 |
| x86 (i386, amd64) | openbsd | 71 | 17859 | 379 | 200 | 7269 | 643 | 103 | 1019 |
| AArch64 | linux | 44 | 6698 | 200 | 198 | 2366 | 749 | 49 | 476 |
| AArch64 | freebsd | 22 | 4773 | 127 | 99 | 1881 | 356 | 33 | 325 |
| AArch64 | netbsd | 13 | 4263 | 45 | 95 | 1943 | 69 | 28 | 342 |
| AArch64 | openbsd | 15 | 4504 | 121 | 86 | 1951 | 161 | 30 | 390 |
| ARM 32-bit | linux | 164 | 24590 | 339 | 107 | 7938 | 618 | 37 | 1764 |
| ARM 32-bit | freebsd | 23 | 6391 | 83 | 75 | 3360 | 253 | 29 | 430 |
| ARM 32-bit | netbsd | 52 | 11718 | 104 | 103 | 5004 | 86 | 34 | 1078 |
| ARM 32-bit | openbsd | 27 | 4864 | 107 | 62 | 2192 | 153 | 27 | 338 |
| RISC-V | linux | 50 | 4575 | 111 | 112 | 1536 | 188 | 28 | 192 |
| RISC-V | freebsd | 9 | 1798 | 82 | 110 | 693 | 222 | 40 | 145 |
| RISC-V | netbsd | 6 | 1890 | 66 | 73 | 480 | 133 | 24 | 115 |
| RISC-V | openbsd | 9 | 1087 | 107 | 73 | 350 | 139 | 27 | 125 |
| MIPS | linux | 32 | 6932 | 316 | 179 | 1900 | 1324 | 55 | 535 |
| MIPS | netbsd | 32 | 14213 | 84 | 140 | 4816 | 548 | 37 | 871 |
| MIPS | openbsd | 16 | 2815 | 28 | 66 | 879 | 85 | 20 | 186 |
| PowerPC | linux | 99 | 32194 | 545 | 301 | 13911 | 767 | 99 | 3251 |
| PowerPC | freebsd | 20 | 7433 | 280 | 197 | 2847 | 600 | 85 | 898 |
| PowerPC | netbsd | 23 | 6922 | 407 | 246 | 2859 | 1133 | 97 | 1338 |
| PowerPC | openbsd | 11 | 1831 | 172 | 157 | 790 | 445 | 60 | 307 |
| LoongArch | linux | 21 | 3503 | 131 | 119 | 1203 | 197 | 41 | 313 |
| m68k | linux | 10 | 4475 | 302 | 123 | 1660 | 947 | 26 | 238 |
| m68k | netbsd | 44 | 14076 | 205 | 104 | 3062 | 440 | 14 | 103 |
| SPARC | linux | 120 | 22750 | 447 | 132 | 12255 | 1063 | 33 | 1961 |
| SPARC | netbsd | 20 | 17737 | 160 | 130 | 8044 | 289 | 32 | 1480 |
| SPARC | openbsd | 12 | 7050 | 73 | 115 | 3690 | 121 | 30 | 835 |
| s390 (z/Architecture) | linux | 13 | 1795 | 306 | 184 | 846 | 431 | 67 | 228 |
| Alpha | linux | 46 | 5971 | 167 | 169 | 3017 | 505 | 14 | 139 |
| Alpha | netbsd | 20 | 3097 | 68 | 72 | 964 | 60 | 11 | 103 |
| Alpha | openbsd | 27 | 3607 | 72 | 79 | 1482 | 106 | 10 | 106 |
| VAX | netbsd | 14 | 4290 | 90 | 106 | 2034 | 200 | 22 | 249 |
| PA-RISC | netbsd | 19 | 7722 | 63 | 95 | 2639 | 118 | 26 | 451 |
| PA-RISC | openbsd | 12 | 5573 | 76 | 137 | 2619 | 98 | 25 | 464 |
| m88k | openbsd | 15 | 4281 | 35 | 56 | 1184 | 29 | 8 | 241 |

*How measured:* "asm files" and "asm lines" count the `.S`/`.s` files taken and their non-blank lines (comments included); "inline asm blocks" count `asm` statements in `.c`/`.h` files; "distinct mnemonics" and the two "statements" columns are from the extraction; the last two columns count the compiler-invisible mnemonics that fell into a named class (not `other`) and their occurrences. Alpha, PA-RISC and m88k have no compiler baseline, so for them every mnemonic is taken as invisible. The SPARC occurrences are inflated by alternate-space loads and stores (section 4.9).

Four things stand out.

> **Surprise 1: the totals look alike, the shapes do not.** Over the architectures present, Linux has 672 assembler files (126,707 lines) and 3,462 inline blocks; NetBSD 325 files (106,334 lines) and 1,393 blocks; OpenBSD 215 files (53,471 lines) and 1,170 blocks; FreeBSD 109 files (30,680 lines) and 958 blocks. But they cover different numbers of architectures (Linux 11, NetBSD 11 including VAX and PA-RISC, OpenBSD 10, FreeBSD 5), so the per-architecture figures matter more: on x86 the four kernels have 13,224 (Linux), 10,285 (FreeBSD), 20,406 (NetBSD) and 17,859 (OpenBSD) lines of assembler files. The BSDs keep a *larger* hand-written core on x86 than Linux does; Linux has the larger inline-assembly population (598 blocks against 101 in NetBSD).

> **Surprise 2: the extreme ends are VAX and SPARC.** The NetBSD VAX port needs only 4,290 lines and 14 files for a whole kernel, and 22 compiler-invisible mnemonics, because the machine does in microcode what everyone else does in assembly (section 5). SPARC needs the most assembly per port (Linux 22,750 lines; NetBSD 17,737 in only 20 files; OpenBSD 7,050) because of register windows and the explicit management of the MMU through alternate-space loads and stores.

> **Surprise 3: most of what the kernels write is ordinary.** Of the 51,454 assembler statements in Linux (extraction count), the large majority are ordinary moves, loads, stores, branches and arithmetic: exactly what a compiler emits. The classified compiler-invisible instructions are 3% to 34% of the statements of a port (their occurrences divided by the sum of the two statement columns; typically 10% to 25%: x86 9% to 14%, AArch64 15% to 19%, RISC-V 11% to 26%, PowerPC 22% to 34%, the lowest being NetBSD m68k 3% and Linux Alpha 4%). The remaining three quarters or more is hand-scheduled bulk code (string routines, checksums, register saves of entry paths) that is written by hand for speed or because it must not touch a stack.

> **Surprise 4: s390 and RISC-V need comparatively little assembler.** Linux s390 has 13 assembler files (1,795 lines) and 306 inline blocks; Linux RISC-V 50 files (4,575 lines), against 164 files (24,590 lines) for Linux ARM. Their kernels are written in C with small inline fragments, because the instruction sets have long instructions that do the work (s390 `mvc`, `stmg`) or very regular system-register access (RISC-V).

**Where each family keeps it.** Linux's x86 population is in `arch/x86/entry` (the entry code, 15 `swapgs`), in `arch/x86/include/asm` (inline fragments for atomics, bit operations, user access, MSR and control-register access, per-CPU access) and in `arch/x86/lib`. The BSDs keep almost everything in `locore`, `exception`, `support` and `cpu_switch` files, with the machine-dependent headers (`cpufunc.h`, `atomic.h`) holding the inline fragments. Section 6 compares the styles.

## 4. The compiler-invisible instructions, class by class

The classes, ranked by the number of architectures that need an instruction of the class (ties broken by total occurrences). "Architectures" counts the families that have at least one compiler-invisible mnemonic of the class in the kernels; Alpha, PA-RISC and m88k are counted although they have no baseline. Occurrences are static counts over the four kernels (L Linux, F FreeBSD, N NetBSD, O OpenBSD).

| Rank | Class | Architectures | Distinct mnemonics | Occurrences | L | F | N | O |
|---:|---|---:|---:|---:|---:|---:|---:|---:|
| 1 | atomics and exclusive access | 14 | 118 | 1206 | 552 | 289 | 159 | 206 |
| 2 | exception entry/return and system call | 14 | 48 | 941 | 308 | 89 | 293 | 251 |
| 3 | privileged register access | 13 | 165 | 11005 | 5226 | 970 | 3140 | 1669 |
| 4 | cache maintenance | 12 | 48 | 1026 | 345 | 84 | 492 | 105 |
| 5 | memory barrier and ordering | 11 | 35 | 2887 | 1016 | 363 | 892 | 616 |
| 6 | TLB and MMU maintenance | 10 | 63 | 875 | 419 | 136 | 205 | 115 |
| 7 | context and FPU/vector state | 10 | 73 | 619 | 170 | 58 | 295 | 96 |
| 8 | spin-wait, idle and hints | 10 | 24 | 277 | 88 | 46 | 84 | 59 |
| 9 | bit manipulation | 9 | 23 | 92 | 76 | 4 | 12 | 0 |
| 10 | debug and breakpoints | 7 | 11 | 107 | 66 | 0 | 28 | 13 |
| 11 | user-memory access | 6 | 32 | 2363 | 1057 | 206 | 757 | 343 |
| 12 | timers and counters | 6 | 19 | 141 | 63 | 24 | 25 | 29 |
| 13 | hypervisor, secure and firmware calls | 6 | 27 | 120 | 71 | 18 | 4 | 27 |
| 14 | string and memory block | 5 | 40 | 435 | 116 | 47 | 108 | 164 |
| 15 | interrupt masking | 4 | 11 | 654 | 159 | 147 | 169 | 179 |
| 16 | CPU identification and feature | 3 | 6 | 83 | 26 | 11 | 19 | 27 |
| 17 | I/O and device access | 2 | 10 | 221 | 16 | 37 | 99 | 69 |
| 18 | speculation control | 2 | 3 | 54 | 33 | 0 | 0 | 21 |
| 19 | random numbers | 2 | 3 | 22 | 5 | 0 | 8 | 9 |
| 20 | per-CPU and thread base | 1 | 5 | 83 | 25 | 31 | 14 | 13 |

The unclassified remainder (`other`: assembler pseudo-instructions, SIMD, cryptography, and the long tail) is in Appendix A.

The rest of this section takes the classes in that order. Each chapter has a table of the instruction names actually used (the ten most frequent per architecture; the full lists are in Appendix A), the one-sentence meaning of each, and a paragraph on what the table shows. An asterisk on an architecture means that it has no compiler baseline. Each chapter ends with "pdp64", what pdp64 has or lacks.

### 4.1 Atomics and exclusive access

| Architecture | Instructions used (total occurrences; L Linux, F FreeBSD, N NetBSD, O OpenBSD) |
|---|---|
| x86 (i386, amd64) | `lock cmpxchg` 36 LFN, `cmpxchg` 28 LNO, `btr` 21 LNO, `bts` 21 LN, `lock add` 18 LFN, `lock cmpxchg8b` 13 LF, `lock dec` 13 LO, `xadd` 10 LO, `cmpxchg8b` 9 LFNO, `lock bts` 8 LF; and 10 more |
| AArch64 | `ldxr` 28 LFNO, `stxr` 21 LFNO, `stlxr` 18 LFNO, `ldaxr` 11 LNO, `cas` 7 LF, `ldar` 5 LFN, `stlr` 4 LF, `stset` 4 LF, `casal` 3 LO, `swp` 3 LF; and 21 more |
| ARM 32-bit | `strex` 59 LFNO, `ldrex` 55 LFNO, `ldrexd` 22 LF, `strexd` 20 LF, `clrex` 12 FNO, `ldrexb` 3 LN, `strexb` 3 LN, `ldrexh` 2 L, `strexh` 2 L, `swpb` 2 LN; and 1 more |
| RISC-V | `lr.w` 10 LFN, `sc.w` 7 LFN, `amoadd.w` 5 LF, `lr.d` 5 LFN, `sc.d` 4 FN, `amoadd.d` 3 F, `amoand.w` 3 FO, `amoor.d` 3 F, `amoor.w` 3 FO, `amoand.d` 2 F; and 4 more |
| MIPS | `ll` 25 LNO, `sc` 25 LNO, `lld` 9 LNO, `scd` 9 LNO |
| PowerPC | `stwcx` 88 LFNO, `lwarx` 77 LFNO, `stdcx` 39 LFO, `ldarx` 31 LFO, `stbcx` 14 LF, `lbarx` 12 LF, `sthcx` 12 LF, `lharx` 10 LF |
| LoongArch | `ll.w` 11 L, `sc.w` 11 L, `ll.d` 4 L, `sc.d` 3 L, `amswap_db.d` 1 L, `amswap_db.w` 1 L, `sc.q` 1 L |
| m68k | `cas` 10 LN, `tas` 3 LN |
| SPARC | `casxa` 27 LNO, `ldstub` 26 LN, `casx` 16 LO, `cas` 7 LO, `casa` 5 LNO, `swap` 4 LN, `swapa` 2 L |
| s390 (z/Architecture) | `csg` 4 L, `cdsg` 3 L |
| Alpha * | `stl_c` 29 LNO, `ldq_l` 27 LNO, `stq_c` 27 LNO, `ldl_l` 26 LNO |
| VAX | `bbssi` 7 N, `bbcci` 5 N, `insqti` 1 N, `insque` 1 N, `remqhi` 1 N, `remque` 1 N |
| PA-RISC * | `ldcw` 4 N |
| m88k * | `xmem` 8 O |

What they do:

- `lock cmpxchg` (x86): compare and exchange.
- `cmpxchg` (x86): compare and exchange.
- `btr` (x86): bit test and reset.
- `bts` (x86): bit test and set.
- `ldxr` (arm64): load exclusive (start of a load-linked sequence).
- `stxr` (arm64): store exclusive (the store-conditional).
- `stlxr` (arm64): store exclusive with release.
- `ldaxr` (arm64): load exclusive with acquire.
- `strex` (arm): store exclusive.
- `ldrex` (arm): load exclusive.
- `ldrexd` (arm): load exclusive doubleword.
- `strexd` (arm): store exclusive doubleword.
- `lr.w` (riscv): load-reserved word.
- `sc.w` (riscv): store-conditional word.
- `amoadd.w` (riscv): atomic add word, old value returned.
- `lr.d` (riscv): load-reserved doubleword.
- `ll` (mips): load linked.
- `sc` (mips): store conditional.
- `lld` (mips): load linked doubleword.
- `scd` (mips): store conditional doubleword.
- `stwcx` (ppc): store word conditional.
- `lwarx` (ppc): load word and reserve.
- `stdcx` (ppc): store doubleword conditional.
- `ldarx` (ppc): load doubleword and reserve.
- `ll.w` (loongarch): load-linked word.
- `sc.w` (loongarch): store-conditional word.
- `ll.d` (loongarch): load-linked doubleword.
- `sc.d` (loongarch): store-conditional doubleword.
- `cas` (m68k): compare and swap.
- `tas` (m68k): test and set a byte atomically.
- `casxa` (sparc): 64-bit compare and swap in an alternate address space.
- `ldstub` (sparc): load byte and set it to all-ones atomically.
- `casx` (sparc): 64-bit compare and swap.
- `cas` (sparc): compare and swap.
- `csg` (s390): compare and swap, 64-bit.
- `cdsg` (s390): 128-bit compare double and swap.
- `stl_c` (alpha): store conditional longword.
- `ldq_l` (alpha): load locked quadword.
- `stq_c` (alpha): store conditional quadword.
- `ldl_l` (alpha): load locked longword.
- `bbssi` (vax): branch on bit set and set, interlocked.
- `bbcci` (vax): branch on bit clear and clear, interlocked.
- `insqti` (vax): insert at queue tail, interlocked.
- `insque` (vax): insert into queue.
- `ldcw` (hppa): load and clear word (the only atomic).
- `xmem` (m88k): exchange register with memory.

Every architecture in the survey has an atomic read-modify-write; only the shape differs. There are three families of designs. **Load-linked / store-conditional** (a pair: read a location and ask the hardware to watch it; write it only if nobody else wrote it in between): MIPS `ll`/`sc`, ARM `ldrex`/`strex`, AArch64 `ldxr`/`stxr` (and the acquire/release variants), PowerPC `lwarx`/`stwcx.`, Alpha `ldl_l`/`stl_c`, RISC-V `lr`/`sc`, LoongArch `ll`/`sc`. **Compare-and-swap and its relatives** (one instruction that writes a new value only if the old one matches): x86 `lock cmpxchg`, m68k `cas`, SPARC `casa`, s390 `cs`/`csg`, AArch64 `cas` from the 8.1 large-system extension. **Fetch-and-operate** (read the old value and add, and, or, xor in memory in one step): RISC-V `amoadd` and friends, AArch64 `ldadd`/`stadd`/`ldclr`/`stset`, LoongArch `amadd_db`, s390 `laa`/`lan`/`lao`, x86 `lock xadd`. The oldest designs have only a test-and-set: m68k `tas`, SPARC `ldstub`, PA-RISC `ldcw` (the only atomic instruction the architecture has), VAX `bbssi`/`bbcci` (branch on a bit and set or clear it as an interlocked operation) and its interlocked queue instructions.

> **Surprise: the same kernel carries two atomic implementations.** Linux AArch64 uses `ldxr`/`stxr` loops in 12 and 9 places and patches them to the single-instruction `cas`/`ldadd` forms at boot when the processor has the extension; FreeBSD and OpenBSD AArch64 contain both too (FreeBSD 4 `cas`, 11 `ldxr`; OpenBSD 8 `stlxr` and a few `ldaddal`). A machine that has both a load-linked pair and a compare-and-swap, as pdp64 does, is the common end state, not an extravagance. On x86 the bit-test family is not atomic by itself: `bts`/`btr` appear 21 times each without a `lock` prefix (non-atomic bit operations in bitmaps) and 8 and 5 times with it (`lock bts`, `lock btr`).

**pdp64:** has the full set: `CAS`, `SWAP`, `XADD`, `XAND`, `XOR_`, `XXOR`, `XMAX`/`XMIN`/`XMAXU`/`XMINU` (more than any surveyed architecture), `LL`/`SC`, and `_DB` forms that fold a barrier in (the LoongArch `_db` idea). An atomic bit test-and-set is two or three instructions (`xor_` of a mask, then a test of the returned old value), the same as RISC-V; the 13 uses of `lock bts`/`lock btr` in four kernels do not justify an instruction. Not present: a double-width compare-and-swap (x86 `cmpxchg16b` 4 uses, `cmpxchg8b` 22, AArch64 `casp` 2, RISC-V `amocas.q` 1, s390 `cdsg`, PowerPC `lqarx`); pdp64 is 64-bit native and has `LL`/`SC` for multi-word updates, so the case is weak (section 7, item 9). The clearing of the reservation on an exception (AArch64 `clrex`, used 2 times) is a rule, not an instruction, and readiness item 7 already covers writing it into the ISA.

### 4.2 Exception entry, return and system call

| Architecture | Instructions used (total occurrences; L Linux, F FreeBSD, N NetBSD, O OpenBSD) |
|---|---|
| x86 (i386, amd64) | `ljmp` 91 LFNO, `iret` 62 LFNO, `lret` 31 LFNO, `lcall` 26 LFNO, `syscall` 15 LFO, `sysret` 9 LFNO, `int` 2 F, `sysexit` 1 L, `ud1` 1 L |
| AArch64 | `eret` 27 LFNO, `svc` 7 FO |
| ARM 32-bit | `swi` 9 LFNO, `udf` 4 FNO, `eret` 2 NO, `rfeia` 2 L, `svc` 2 L |
| RISC-V | `ecall` 14 LFNO, `sret` 14 LFNO, `mret` 1 L |
| MIPS | `eret` 17 LN, `rfe` 7 LN, `syscall` 5 NO, `deret` 1 L |
| PowerPC | `rfi` 89 LFN, `rfid` 20 LFO, `sc` 11 LFNO, `rfci` 7 LFN, `rfmci` 3 LFN, `hrfid` 2 L, `rfdi` 2 LF |
| LoongArch | `ertn` 9 L |
| m68k | `rte` 17 LN |
| SPARC | `retry` 95 LNO, `rett` 17 LN, `done` 13 LNO, `tne` 9 LNO |
| s390 (z/Architecture) | `lpswe` 15 L, `lpsw` 1 L, `svc` 1 L |
| Alpha * | `call_pal` 180 LNO |
| VAX | `rei` 28 N, `chmk` 5 N |
| PA-RISC * | `rfir` 38 NO, `rfi` 12 NO, `be` 4 NO, `ble` 4 NO |
| m88k * | `tb0` 6 O, `tb1` 3 O |

What they do:

- `ljmp` (x86): far jump: loads a new code segment and address (mode switches in boot and real-mode code).
- `iret` (x86): return from an interrupt or exception: pops instruction pointer, code segment, flags (and stack pointer on a privilege change) in one step.
- `lret` (x86): far return: pops a return address and a code segment (used to change segments in boot code).
- `lcall` (x86): far call through a segment.
- `eret` (arm64): exception return: PC from ELR, state from SPSR.
- `svc` (arm64): supervisor call.
- `swi` (arm): software interrupt (old name for svc).
- `udf` (arm): permanently undefined.
- `eret` (arm): exception return: PC from ELR, state from SPSR.
- `rfeia` (arm): return from exception (increment after).
- `ecall` (riscv): environment call: system call from user, SBI call from supervisor.
- `sret` (riscv): return from supervisor trap.
- `mret` (riscv): return from machine trap.
- `eret` (mips): exception return: PC from ELR, state from SPSR.
- `rfe` (mips): return from exception, loading PC and CPSR from memory.
- `syscall` (mips): system call.
- `deret` (mips): return from debug.
- `rfi` (ppc): return from interruption.
- `rfid` (ppc): return from interrupt (64-bit).
- `sc` (ppc): system call (or hypervisor call).
- `rfci` (ppc): return from critical interrupt (embedded PowerPC).
- `ertn` (loongarch): return from exception.
- `rte` (m68k): return from exception.
- `retry` (sparc): return from trap and re-execute the trapping instruction.
- `rett` (sparc): return from trap (SPARC v8).
- `done` (sparc): return from trap, skipping the trapping instruction.
- `lpswe` (s390): load the extended (128-bit) PSW.
- `lpsw` (s390): load program-status word (PC, flags, mode) and branch.
- `svc` (s390): supervisor call.
- `call_pal` (alpha): call privileged architecture library code: the kernel interface; one instruction, a function number selects swpipl, rti, swpctx, tbi, halt, imb and others.
- `rei` (vax): return from exception or interrupt: pops PC and PSL and may switch modes and stacks.
- `chmk` (vax): change mode to kernel: the system call instruction.
- `rfi` (hppa): return from interruption.

All fourteen architectures have a *return-from-exception* instruction, and it is the single most universal compiler-invisible instruction there is: `iret`, `eret`, `sret`/`mret`, `rte`, `rfi`/`rfid`, `retry`/`done`, `rei`, `ertn`, `lpswe`, PAL `rti`. Only a few have a *separate fast entry* instruction: x86 `syscall`/`sysenter` and its partner `sysret`/`sysexit`. They exist because the older mechanism (a software interrupt through a descriptor table, with a stack switch and segment checks) was too slow; Linux uses `sysret` only when returning to a "clean" 64-bit context and falls back to the slower `iret` otherwise (`iret` 62 uses against `sysret` 9 in the four kernels). Everyone else enters the kernel by the same exception mechanism whether the cause is a fault, an interrupt or a system call instruction (`svc`, `ecall`, `trap`, `ta`, `sc`, `chmk`).

> **Surprise: SPARC's `retry` and `done`.** Two return instructions, one that re-executes the trapping instruction and one that skips it. They are used 108 times in the three SPARC kernels (95 `retry` and 13 `done`; one OpenBSD file, `sparc64/locore.s`, has 28 and 3). pdp64 gets the same effect from the rule that `EPC` holds the faulting instruction for an abort and the next instruction for a trap or interrupt; no second return is needed.

What the hardware saves is the real difference. x86 pushes five words; AArch64, RISC-V, MIPS, LoongArch, PowerPC and pdp64 save the return address and status in *registers*; s390 swaps whole program-status words in fixed low memory; the VAX and m68k push a frame; Alpha's PALcode does it in privileged software below the kernel. And almost every architecture masks interrupts on entry (x86 interrupt gates clear `IF`; AArch64 sets `DAIF`; RISC-V clears `SIE` and keeps the old value in `SPIE`; PowerPC clears `EE`; MIPS sets `EXL`; SPARC clears `PSTATE.IE`; stated from the architecture manuals, not measured here), which is what pdp64's errata 40 (priority 7 on every entry) now does.

**pdp64:** `RTI`, `RTT`, `TRAP #n`/`TRAPL #n` (vector 256 + n), `BPT`; `EPC`/`EPSW`/`EVA`/`ECAUSE` in registers; `PUSHX`/`POPX` for the nested case; priority 7 on entry (errata 40). Nothing missing. The comparison of path lengths is in section 8.

### 4.3 Privileged register access

| Architecture | Instructions used (total occurrences; L Linux, F FreeBSD, N NetBSD, O OpenBSD) |
|---|---|
| x86 (i386, amd64) | `wrmsr` 161 LFNO, `rdmsr` 129 LFNO, `lgdt` 77 LFNO, `lidt` 34 LFNO, `lldt` 24 LFNO, `ltr` 24 LFNO, `clts` 18 LFNO, `str` 18 LFNO, `sgdt` 16 LFNO, `sidt` 15 LFNO; and 10 more |
| AArch64 | `msr` 401 LFNO, `mrs` 262 LFNO, `sys` 3 LF, `sysl` 1 F |
| ARM 32-bit | `mcr` 1830 LFNO, `mrc` 481 LFNO, `msr` 147 LFNO, `mrs` 106 LFNO, `mcrr` 28 LFN, `mrrc` 11 LFNO |
| RISC-V | `csrw` 109 LFNO, `csrr` 84 LFNO, `csrrw` 35 LFNO, `csrs` 30 LFNO, `csrc` 28 LFNO, `csrsi` 11 FNO, `csrci` 6 FNO, `csrrci` 5 FNO, `csrrc` 2 L, `csrrwi` 2 FO; and 2 more |
| MIPS | `mtc0` 312 LNO, `mfc0` 310 LNO, `dmtc2` 73 L, `dmtc0` 68 LNO, `dmfc2` 63 L, `dmfc0` 47 LNO, `dvpe` 3 L, `mfcr` 3 N, `dmt` 2 L, `evpe` 2 L; and 15 more |
| PowerPC | `mtspr` 1054 LFNO, `mfspr` 792 LFNO, `mfmsr` 237 LFNO, `mtmsr` 195 LFNO, `mtcr` 137 LFNO, `mtmsrd` 80 LFNO, `mfsrr1` 41 LFNO, `mtsprg1` 40 FNO, `mtsrr1` 37 LFNO, `mtibatu` 35 LFN; and 36 more |
| LoongArch | `csrrd` 66 L, `csrwr` 50 L, `csrxchg` 18 L, `iocsrrd.d` 1 L, `iocsrrd.w` 1 L |
| m68k | `movec` 98 LN, `pmove` 40 LN, `stop` 3 LN, `reset` 2 N |
| SPARC | `wrpr` 691 LNO, `rdpr` 487 LNO, `rd` 282 LNO |
| s390 (z/Architecture) | `lctlg` 10 L, `sam64` 10 L, `spka` 9 L, `epsw` 6 L, `lra` 6 L, `sam31` 5 L, `stctg` 5 L, `sacf` 4 L, `spx` 3 L, `stap` 3 L; and 15 more |
| VAX | `mfpr` 42 N, `mtpr` 40 N, `movpsl` 11 N |
| PA-RISC * | `mtctl` 231 NO, `mfctl` 194 NO, `mtsp` 146 NO, `mfsp` 43 NO, `rsm` 16 NO, `ssm` 10 NO, `mtsm` 5 NO |
| m88k * | `ldcr` 119 O, `stcr` 58 O, `fldcr` 19 O, `xcr` 17 O, `fstcr` 11 O |

What they do:

- `wrmsr` (x86): write a model-specific register (the x86 "system register file", numbered in a 32-bit space).
- `rdmsr` (x86): read a model-specific register.
- `lgdt` (x86): load the global descriptor table register.
- `lidt` (x86): load the interrupt descriptor table register (the address of the vector table).
- `msr` (arm64): move general register (or an immediate for some) to system register.
- `mrs` (arm64): move system register to general register.
- `sys` (arm64): generic system instruction (cache, TLB operations).
- `mcr` (arm): move to coprocessor register (cp15 = system control).
- `mrc` (arm): move from coprocessor register.
- `msr` (arm): move general register (or an immediate for some) to system register.
- `mrs` (arm): move system register to general register.
- `csrw` (riscv): write a CSR.
- `csrr` (riscv): read a CSR.
- `csrrw` (riscv): swap a CSR with a register.
- `csrs` (riscv): set bits in a CSR.
- `mtc0` (mips): move to coprocessor 0.
- `mfc0` (mips): move from coprocessor 0 (the system-control registers).
- `dmtc2` (mips): move to coprocessor 2 (Octeon crypto).
- `dmtc0` (mips): 64-bit move to CP0.
- `mtspr` (ppc): move to special-purpose register.
- `mfspr` (ppc): move from special-purpose register.
- `mfmsr` (ppc): read the machine state register.
- `mtmsr` (ppc): write it.
- `csrrd` (loongarch): read CSR.
- `csrwr` (loongarch): swap CSR with register.
- `csrxchg` (loongarch): masked exchange with a CSR.
- `movec` (m68k): move to or from a control register (VBR, CACR, USP, MMU registers).
- `pmove` (m68k): move to or from an MMU register.
- `stop` (m68k): load the status register and halt until an interrupt.
- `reset` (m68k): assert the reset line to external devices.
- `wrpr` (sparc): write a privileged register.
- `rdpr` (sparc): read a privileged register.
- `rd` (sparc): read a state register.
- `lctlg` (s390): load control registers.
- `sam64` (s390): set addressing mode to 64-bit.
- `mfpr` (vax): move from processor register.
- `mtpr` (vax): move to processor register (IPL, page-table base, TLB invalidate, ...).
- `movpsl` (vax): read the processor status longword.
- `mtctl` (hppa): move to control register.
- `mfctl` (hppa): move from control register.
- `ldcr` (m88k): load control register.
- `stcr` (m88k): store control register.

This is the largest class by far: 11,221 of the 23,211 classified occurrences (48%), and every architecture has an instruction pair to read and write a numbered or named system register. The names differ and the idea is the same: x86 `rdmsr`/`wrmsr` (a 32-bit number space) and `mov` to and from `%cr0`..`%cr4`, the descriptor-table loads `lgdt`/`lidt`/`ltr`; AArch64 `mrs`/`msr` (a named-register space: the kernel names about a hundred distinct registers); ARM 32-bit `mrc`/`mcr` with coprocessor numbers (372 distinct `mcr` operand patterns); RISC-V `csrr`/`csrw`/`csrs`/`csrc`/`csrrw`; MIPS `mfc0`/`mtc0` (coprocessor 0); PowerPC `mfspr`/`mtspr` plus a long list of extended names (`mtsprg1`, `mtibatu`, `mfdar`; 324 distinct special-register operands); SPARC `rdpr`/`wrpr`; m68k `movec`; s390 `lctlg`/`stctg`; LoongArch `csrrd`/`csrwr`/`csrxchg`; Alpha one `call_pal` with 37 distinct function names; PA-RISC `mfctl`/`mtctl`; VAX `mtpr`/`mfpr` with a processor-register number.

Which registers do kernels actually touch? From the operand tables (`kernel_sysreg_operands.csv`, occurrence counts in the four kernels): AArch64 `tpidr_el1` 44 (the per-CPU pointer), `sctlr_el1` 38, `ttbr1_el1` 28, `sp_el0` 23, `tpidrro_el0` 21, `daif` 18; RISC-V `sstatus` 65 (with the `csr_` spelling), `sscratch` 34, `stvec` 19, `satp` 16, `sepc` 16; PowerPC `srr1` 99, `srr0` 72, the `mas*` TLB registers of the embedded chips, `hid0` 54, `sprg_thread` 35; MIPS `cop_0_status` 146 and the kernel-reserved registers `k0`/`k1` 101; x86 control registers `cr0` 23, `cr4` 11, `cr3` 4. In every case the list is the same short set of ideas: status/mask, exception return address, exception cause and bad address, vector base, page-table base, address-space tag, a scratch or per-CPU pointer, a timer, feature/identification registers.

> **Surprise: the atomic read-modify-write of a status register.** RISC-V's `csrrs` and `csrrc` (read and set, read and clear) and AArch64's immediate forms `msr daifset`/`daifclr` (28 uses) exist because interrupt enabling and the user-access permission bit live in a status register that is changed with one instruction. RISC-V has 58 uses of `csrs`/`csrc` alone. On pdp64 the equivalent registers are few (the priority is changed by `SPL`; the flags by `MTPS`), so the cost is limited to the user-access guard bit proposed in section 4.9.

**pdp64:** `MFSR`/`MTSR` with an 8-bit register number; 13 numbers are defined (`ptbr`, `epc`, `eva`, `ecause`, `dmw0`, `dmw1`, `usp`, `ssp`, `epsw`, `vbr`, `mmuctl`, `asid`, `cpuid`) and 243 are free. The survey supports the design (a general pair, not one instruction per register) and shows what is missing from the register file, not from the instruction set: identification and feature registers (section 4.14).

### 4.4 Cache maintenance

| Architecture | Instructions used (total occurrences; L Linux, F FreeBSD, N NetBSD, O OpenBSD) |
|---|---|
| x86 (i386, amd64) | `wbinvd` 17 LFNO, `clflushopt` 11 FO, `clflush` 9 LFO, `invd` 6 FN, `prefetcht0` 2 L, `clwb` 1 F |
| AArch64 | `stnp` 24 LN, `dc` 23 LFNO, `prfm` 22 LF, `ic` 19 LFNO, `ldnp` 4 N |
| ARM 32-bit | `pld` 85 LFN, `dccimvacne` 2 L, `dcimvaclo` 1 L, `pldw` 1 L |
| RISC-V | `cbo.clean` 2 FO, `cbo.flush` 2 FO, `cbo.inval` 2 FO |
| MIPS | `cache` 276 LNO, `pref` 5 L, `synci` 5 LN, `cachee` 1 L |
| PowerPC | `dcbf` 42 LFNO, `dcbst` 28 LFNO, `dcbt` 23 LFN, `icbi` 23 LFNO, `dcbz` 17 LFNO, `dcba` 7 N, `dcbi` 7 LNO, `dcbtst` 2 LF, `dcbzl` 1 O |
| LoongArch | `cacop` 1 L |
| m68k | `cpush` 20 L, `cpusha` 10 L, `cpushp` 10 L, `cinva` 3 L, `cinvp` 2 L |
| SPARC | `flush` 151 LNO, `prefetch` 48 L, `prefetcha` 4 L |
| s390 (z/Architecture) | `sske` 2 L, `iske` 1 L, `rrbe` 1 L |
| Alpha * | `imb` 1 L |
| PA-RISC * | `fdc` 58 NO, `fic` 40 NO, `fdce` 2 NO, `fice` 2 NO |

What they do:

- `wbinvd` (x86): write back and invalidate all caches.
- `clflushopt` (x86): flush one cache line, weakly ordered.
- `clflush` (x86): flush one cache line.
- `invd` (x86): invalidate caches without writing back.
- `stnp` (arm64): store pair, non-temporal.
- `dc` (arm64): data-cache maintenance by address or set.
- `prfm` (arm64): prefetch.
- `ic` (arm64): instruction-cache maintenance.
- `pld` (arm): preload data.
- `cbo.clean` (riscv): cache-block clean.
- `cbo.flush` (riscv): cache-block flush.
- `cbo.inval` (riscv): cache-block invalidate.
- `cache` (mips): cache operation by address or index.
- `synci` (mips): instruction-cache sync by address.
- `dcbf` (ppc): flush data-cache block.
- `dcbst` (ppc): store (clean) it.
- `dcbt` (ppc): data-cache prefetch.
- `icbi` (ppc): invalidate instruction-cache block.
- `cacop` (loongarch): cache operation.
- `cpush` (m68k): push (write back) and invalidate cache lines.
- `flush` (sparc): instruction-cache flush of one word.
- `prefetch` (sparc): prefetch.
- `sske` (s390): set storage key.
- `iske` (s390): insert storage key.
- `rrbe` (s390): reset reference bit.
- `imb` (alpha): instruction memory barrier.

Twelve architectures have data- or instruction-cache maintenance instructions. They exist for three reasons: *coherence of instruction fetch* after the kernel writes code (every architecture with a separate instruction cache: ARM `mcr` cp15, AArch64 `ic`, PowerPC `icbi`, RISC-V `fence.i`, MIPS `synci`, SPARC `flush`); *DMA* with devices that do not snoop the processor cache (ARM, MIPS `cache` 276 uses, PowerPC `dcbf`/`dcbst`/`dcbi`, PA-RISC `fdc`/`fic` 100 uses, AArch64 `dc civac`); and *zeroing and prefetch* for speed (PowerPC `dcbz`, `dcbt`; ARM `pld` 85; AArch64 `prfm` 22; MIPS `pref`). x86 and s390 need few because their caches are coherent with DMA and instruction fetch (x86 has `clflush`/`clflushopt`/`clwb` 21 uses for persistent memory and device buffers, `wbinvd` 17 for power management and virtualization).

The count is dominated by the BSDs here (NetBSD 492 of 1,026), which carry the cache code of many embedded ports with non-coherent caches.

**pdp64:** instruction-cache invalidate `ICINV`/`ICINVA` (not privileged, because a JIT needs it); the data cache is transparently coherent between cores and with devices only through uncached mappings plus `FENCE` (ISA section 17.3). That is the x86/s390 position, the right one for a machine without non-coherent DMA masters. If a non-coherent device is ever added, three operations are needed (clean, invalidate, flush by address); they can be `SYSX` sub-opcodes, no new top-level opcode (section 7, item 7). Prefetch hints are decided already (`HINT`, errata 39).

### 4.5 Memory barriers and ordering

| Architecture | Instructions used (total occurrences; L Linux, F FreeBSD, N NetBSD, O OpenBSD) |
|---|---|
| x86 (i386, amd64) | `lfence` 152 LFNO, `mfence` 35 LFNO, `sfence` 22 LFNO |
| AArch64 | `isb` 187 LFNO, `dsb` 176 LFNO, `dmb` 20 LFN |
| ARM 32-bit | `dsb` 101 LFNO, `isb` 63 LFNO, `dmb` 17 LFN |
| RISC-V | `fence` 64 LFNO, `fence.i` 11 LFNO |
| MIPS | `sync` 40 LNO, `ehb` 21 LN, `sync.l` 16 N, `sync.p` 16 N, `jr.hb` 14 LNO, `ssnop` 8 N, `syncw` 6 LN, `synciobdma` 2 L |
| PowerPC | `isync` 662 LFNO, `sync` 483 LFNO, `eieio` 52 LFNO, `msync` 50 LFN, `lwsync` 14 LF, `mbar` 10 LFN, `hwsync` 6 L |
| LoongArch | `dbar` 6 L, `ibar` 5 L |
| SPARC | `membar` 533 LNO |
| s390 (z/Architecture) | `bcr` 1 L |
| Alpha * | `mb` 23 LNO, `wmb` 2 LN, `excb` 1 N |
| PA-RISC * | `sync` 60 NO, `syncdma` 8 NO |

What they do:

- `lfence` (x86): load fence; also, since Spectre, a barrier that stops speculative execution.
- `mfence` (x86): full memory fence.
- `sfence` (x86): store fence.
- `isb` (arm64): instruction synchronisation barrier: flush the pipeline so earlier system-register writes take effect.
- `dsb` (arm64): data synchronisation barrier: wait for all earlier memory and maintenance operations.
- `dmb` (arm64): data memory barrier: order memory accesses only.
- `dsb` (arm): data synchronisation barrier: wait for all earlier memory and maintenance operations.
- `isb` (arm): instruction synchronisation barrier: flush the pipeline so earlier system-register writes take effect.
- `dmb` (arm): data memory barrier: order memory accesses only.
- `fence` (riscv): memory fence with predecessor and successor sets.
- `fence.i` (riscv): instruction-fetch fence.
- `sync` (mips): memory barrier.
- `ehb` (mips): execution hazard barrier.
- `sync.l` (mips): sync, load-ordering form.
- `sync.p` (mips): sync, pipeline form.
- `isync` (ppc): instruction synchronise (context-synchronising).
- `sync` (ppc): full memory barrier.
- `eieio` (ppc): order device accesses.
- `msync` (ppc): memory synchronise (embedded).
- `dbar` (loongarch): data barrier.
- `ibar` (loongarch): instruction barrier.
- `membar` (sparc): memory barrier with masks.
- `bcr` (s390): branch on condition register (with mask 14: serialisation).
- `mb` (alpha): memory barrier.
- `wmb` (alpha): write memory barrier.
- `excb` (alpha): exception barrier.
- `sync` (hppa): full memory barrier.

> **Surprise: the commonest "barrier" is not about memory at all.** Sorting by use, the dominant barrier on most architectures is the *context-synchronising* one, the instruction that says "everything I changed in the system registers is now in effect": AArch64 `isb` 187 against `dmb` 20; PowerPC `isync` 662 against `sync` 483 and `lwsync` 14; RISC-V `fence.i`; LoongArch `ibar`; MIPS `ehb`/`jr.hb`; SPARC `membar #Sync` 533 (every kernel entry sequence ends memory-mapped register changes with one); s390 serialising `bcr`. A kernel changes the page-table base, the translation enable, the vector base, and then must not run another instruction until it is in effect. Memory ordering proper (`dmb`, `lwsync`, `mfence`, RISC-V `fence`) is the minority use.

The x86 `lfence` (152 uses; OpenBSD 108) is the other surprise: on current x86 it is a *speculation barrier* (section 4.18), not a memory fence.

**pdp64:** `FENCE` for memory (the model is sequentially consistent, so one fence is enough; x86, the closest of the surveyed architectures to that model, needs only three fence instructions in these kernels: `mfence` 35, `sfence` 22, `lfence` 152). The context-synchronising instruction **is already decided**: `ISYNC` (errata 39; `SYSX` sub-opcode 2, page-2 `0x2C`). The survey is the strongest evidence yet for it: 187 `isb`, 662 `isync`, 533 SPARC `membar #Sync`.

### 4.6 TLB and MMU maintenance

| Architecture | Instructions used (total occurrences; L Linux, F FreeBSD, N NetBSD, O OpenBSD) |
|---|---|
| x86 (i386, amd64) | `invlpg` 16 LFNO, `invpcid` 14 LFNO, `invept` 3 FO, `invvpid` 2 FO, `invlpgb` 1 F, `tlbsync` 1 F |
| AArch64 | `tlbi` 76 LFNO |
| RISC-V | `sfence.vma` 30 LFNO, `sinval.vma` 2 F, `hfence.gvma` 1 F, `sfence.inval.ir` 1 F, `sfence.w.inval` 1 F |
| MIPS | `tlbwi` 31 LNO, `tlbp` 17 LNO, `tlbr` 14 LNO, `tlbwr` 10 LNO, `ginvt` 1 L |
| PowerPC | `tlbwe` 109 LFN, `ptesync` 105 LFNO, `tlbsync` 49 LFNO, `tlbre` 36 LFN, `slbmte` 32 LFO, `tlbie` 28 LFNO, `tlbsx` 24 LFN, `slbia` 22 LFNO, `slbie` 15 LFO, `slbmfee` 12 LFO; and 6 more |
| LoongArch | `invtlb` 7 L, `tlbfill` 6 L, `tlbsrch` 4 L, `tlbwr` 4 L, `lddir` 3 L, `ldpte` 2 L, `tlbclr` 1 L, `tlbflush` 1 L, `tlbrd` 1 L |
| m68k | `ptestr` 18 LN, `pflusha` 14 LN, `pflush` 9 LN, `pflushs` 3 N, `pflushan` 2 L, `ploadr` 2 L, `ploadw` 1 L, `ptestw` 1 L |
| SPARC | `flushw` 52 LNO |
| s390 (z/Architecture) | `idte` 7 L, `ipte` 3 L, `ptlb` 2 L, `cspg` 1 L |
| PA-RISC * | `idtlba` 11 NO, `idtlbp` 11 NO, `iitlba` 4 NO, `iitlbp` 4 NO, `pdtlb` 2 NO, `pdtlbe` 2 NO, `pitlb` 2 NO, `pitlbe` 2 NO |

What they do:

- `invlpg` (x86): invalidate the TLB entry of one page.
- `invpcid` (x86): invalidate TLB entries by address-space tag (PCID) or all.
- `invept` (x86): invalidate guest-physical mappings (virtualization).
- `invvpid` (x86): invalidate guest TLB by virtual-processor tag.
- `tlbi` (arm64): TLB invalidate (by all, address, ASID, with or without broadcast).
- `sfence.vma` (riscv): TLB fence (by address and ASID).
- `sinval.vma` (riscv): fine-grained invalidate.
- `hfence.gvma` (riscv): guest TLB fence.
- `sfence.inval.ir` (riscv): order invalidations against later accesses.
- `tlbwi` (mips): write TLB entry at index.
- `tlbp` (mips): probe the TLB.
- `tlbr` (mips): read a TLB entry.
- `tlbwr` (mips): write TLB entry.
- `tlbwe` (ppc): write a TLB entry (embedded PowerPC).
- `ptesync` (ppc): barrier for page-table updates.
- `tlbsync` (ppc): wait for tlbie to complete.
- `tlbre` (ppc): read a TLB entry.
- `invtlb` (loongarch): TLB invalidate with an operation code (all, by ASID, by address...).
- `tlbfill` (loongarch): fill TLB entry.
- `tlbsrch` (loongarch): search the TLB.
- `tlbwr` (loongarch): write TLB entry.
- `ptestr` (m68k): test translation of an address (read).
- `pflusha` (m68k): flush all.
- `pflush` (m68k): flush an address-translation cache entry.
- `flushw` (sparc): spill all register windows.
- `idte` (s390): invalidate DAT table entry.
- `ipte` (s390): invalidate page-table entry.
- `ptlb` (s390): purge the TLB.

Two groups hide in this table. The first, the **invalidate** instructions (x86 `invlpg`/`invpcid`, AArch64 `tlbi`, RISC-V `sfence.vma`, PowerPC `tlbie`, s390 `ipte`/`idte`/`ptlb`, LoongArch `invtlb`, PA-RISC purges), is what any hardware-walked MMU needs. The second, the **software TLB refill** instructions (MIPS `tlbp`/`tlbr`/`tlbwi`/`tlbwr`; PowerPC embedded `tlbwe`/`tlbre`/`tlbsx` and the `slb*` family; PA-RISC `idtlba`/`iitlba`; LoongArch `tlbsrch`/`tlbfill`/`lddir`/`ldpte`; m68k `pflush`/`ptest`/`pload`), exists because those machines do not walk the page table in hardware, or walk it partly (LoongArch's `lddir`/`ldpte` are helper instructions for the refill handler). Five of the fourteen architectures need a hand-written TLB refill handler; x86, AArch64, RISC-V, s390 and the VAX do not.

AArch64 and RISC-V show the operand forms a kernel wants: all entries (`tlbi vmalle1is`), one address (`vale1is`, `vae1is`), one address-space tag (`aside1is`: FreeBSD 2, OpenBSD 2), address plus tag. RISC-V `sfence.vma` appears with no operand, with an address, and with an address-space tag in each of the BSDs and Linux. Broadcast to other cores is a variant (`is` = inner shareable) in AArch64 and implicit or by software interrupt elsewhere; x86 needs an inter-processor interrupt and AMD has `invlpgb` (1 use).

**pdp64:** `TLBI rN` (one address), `TLBIA` (all), `TLBSYNC` (completion of the broadcast), all broadcasting; hardware walker, software accessed/dirty bits; none of the software-refill machinery. That is the right side of the table. **What is missing is invalidate by address-space tag**: used for process exit and for ASID recycling without a global flush (AArch64 `aside1is`, RISC-V `sfence.vma` with an ASID, x86 `invpcid` type 1 and 2: 14 uses, LoongArch `invtlb` operation codes). Section 7, item 5.

### 4.7 Context and floating-point/vector state

| Architecture | Instructions used (total occurrences; L Linux, F FreeBSD, N NetBSD, O OpenBSD) |
|---|---|
| x86 (i386, amd64) | `pusha` 44 LFNO, `popa` 36 LFNO, `fxsave` 13 LFNO, `fninit` 12 LFNO, `fxrstor` 12 FNO, `fnstsw` 8 LFNO, `xsave` 8 FNO, `fnclex` 7 LFNO, `ldmxcsr` 7 LFNO, `fwait` 6 LO; and 10 more |
| ARM 32-bit | `vmsr` 5 LFNO, `vmrs` 4 LFO |
| RISC-V | `fscsr` 8 LFNO, `frcsr` 7 LFNO, `vsetvli` 7 LF, `vl8r.v` 4 O, `vs8r.v` 4 O, `vsetvl` 4 LFO, `frflags` 1 N, `fsflags` 1 N, `fsrm` 1 N |
| MIPS | `ctc1` 25 LNO, `cfc1` 22 LNO |
| PowerPC | `evmergehi` 17 N, `evmergelo` 17 N, `evstdw` 16 N, `evldw` 15 N, `mffs` 14 LFNO, `evmergehilo` 11 N, `mtfsf` 8 FNO, `mfvscr` 7 LFNO, `mtvscr` 7 LFNO, `mtfsb0` 6 N; and 8 more |
| LoongArch | `movgr2frh.w` 33 L, `movgr2cf` 16 L, `movgr2scr` 12 L, `movscr2gr` 8 L, `movfcsr2gr` 3 L, `movgr2fcsr` 3 L |
| m68k | `frestore` 20 LN, `fsave` 20 LN |
| SPARC | `saved` 17 LNO, `restored` 10 NO |
| s390 (z/Architecture) | `lfpc` 3 L, `stfpc` 3 L, `stamy` 2 L, `lamy` 1 L, `lmh` 1 L, `lpq` 1 L, `plo` 1 L, `stm` 1 L |
| VAX | `pushr` 26 N, `popr` 22 N, `ldpctx` 4 N, `svpctx` 2 N |

What they do:

- `pusha` (x86): push all general registers (32-bit).
- `popa` (x86): pop all general registers.
- `fxsave` (x86): save legacy FPU and SSE state (512 bytes).
- `fninit` (x86): initialise the x87 unit.
- `vmsr` (arm): write FPU status.
- `vmrs` (arm): read FPU status.
- `fscsr` (riscv): swap the FP control and status register.
- `frcsr` (riscv): read it.
- `vsetvli` (riscv): set vector length and type.
- `frestore` (m68k): restore it.
- `fsave` (m68k): save the FPU internal state.
- `saved` (sparc): tell the hardware a window was saved.
- `restored` (sparc): tell the hardware a window was restored.
- `pushr` (vax): push registers named by a mask.
- `popr` (vax): pop registers named by a mask.
- `ldpctx` (vax): load process context: load the registers, stack pointers and page-table registers from the PCB.
- `svpctx` (vax): save process context: store registers and stack pointers into the process control block, switch to the interrupt stack.

This class is where architectures differ most. The VAX has `svpctx`/`ldpctx` (6 uses in NetBSD) that save and load a whole process control block in one instruction each (sidebar in section 5). The m68k, s390 and (old) x86 have *multiple-register* instructions (`movem`, `stmg`/`lmg`, `pusha`) so a context switch is a handful of instructions. SPARC has register windows: `save`, `restore`, and the trap-time `flushw`, `saved`, `restored`. RISC-V, MIPS, AArch64 and LoongArch have none of these and use long runs of ordinary load/store pairs (`stp`/`ldp` runs in AArch64, not compiler-invisible and so not in the table). Floating-point and vector state is the other half: x86 has 20 invisible mnemonics for it (`fxsave`, `xsave` and `xsaveopt`/`xsavec`/`xsaves`, `fnsave`, `ldmxcsr`, `fninit`, `emms`), PowerPC AltiVec/SPE moves, RISC-V `vsetvli` and `fscsr`, s390 `lfpc`.

**pdp64:** `PUSHM`/`POPM` (mask-driven register save and restore, the VAX `pushr`/`popr` and m68k `movem` idea), `PUSHX`/`POPX`, `MFSR usp/ssp`, and *no floating-point state to save*: floating point lives in the general registers (ISA section 2.3), so the 180 FPU-state-instruction occurrences of x86 have no counterpart. The only extra state is `FPSR` (5 bits, saved with the `PSW`). The survey confirms this design decision: lazy FPU switching, `xsave` feature masks, and trap-on-first-use logic are among the most intricate assembly in the x86 and ARM kernels.

### 4.8 Spin-wait, idle and hints

| Architecture | Instructions used (total occurrences; L Linux, F FreeBSD, N NetBSD, O OpenBSD) |
|---|---|
| x86 (i386, amd64) | `hlt` 57 LFNO, `pause` 30 LFNO, `mwait` 9 LFNO, `monitor` 7 LFNO, `monitorx` 1 L, `mwaitx` 1 L |
| AArch64 | `wfe` 20 LFNO, `wfi` 15 LFNO, `sev` 13 LFO, `hint` 9 LFN, `sevl` 4 L, `yield` 4 LFNO |
| ARM 32-bit | `wfe` 9 LFNO, `wfi` 9 LFNO, `sev` 6 LFNO |
| RISC-V | `wfi` 14 LFNO |
| MIPS | `wait` 12 LNO |
| PowerPC | `stop` 2 O, `nap` 1 F, `wait` 1 L |
| LoongArch | `idle` 5 L |
| s390 (z/Architecture) | `sigp` 12 L |
| Alpha * | `halt` 1 O |
| VAX | `halt` 35 N |

What they do:

- `hlt` (x86): halt until an interrupt.
- `pause` (x86): spin-loop hint: tells the core this is a busy-wait.
- `mwait` (x86): wait for a write to a monitored address, or an interrupt.
- `monitor` (x86): arm the address monitor for mwait.
- `wfe` (arm64): wait for event.
- `wfi` (arm64): wait for interrupt.
- `sev` (arm64): send event to all cores.
- `hint` (arm64): generic hint encoding.
- `wfe` (arm): wait for event.
- `wfi` (arm): wait for interrupt.
- `sev` (arm): send event to all cores.
- `wfi` (riscv): wait for interrupt.
- `wait` (mips): wait for interrupt.
- `stop` (ppc): load the status register and halt until an interrupt.
- `nap` (ppc): low-power wait.
- `wait` (ppc): wait for interrupt.
- `idle` (loongarch): wait for interrupt.
- `sigp` (s390): signal processor (inter-CPU command).
- `halt` (alpha): halt.
- `halt` (vax): halt.

Two different needs share this class. **Idle**: stop the processor until an interrupt (`hlt`, `wfi`, `wait`, `idle`, `stop`, PA-RISC and VAX `halt`, Power `nap`). **Spin-wait**: a hint inside a busy-wait loop (x86 `pause`, 30 uses; AArch64 `yield`; RISC-V `pause`, encoded as a no-op fence) and the "wait for a write to this address" pair (`monitor`/`mwait`, 18 uses; AArch64 `wfe`+`sev`).

> **Surprise: the idle race.** Every architecture that has an idle instruction has also solved the lost-wake-up problem: the kernel checks "is there work?", finds none, and executes the idle instruction; an interrupt arriving *between* the check and the idle would be handled and then the processor would sleep with work pending. x86 solves it with the one-instruction interrupt shadow of `sti` (so `sti; hlt` is atomic); AArch64 `wfi` and RISC-V `wfi` wake on a pending interrupt even when it is masked (the kernel then unmasks and takes it); AArch64 `wfe` has a sticky event register. System v1 says `WFE` "sleeps until an interrupt is taken", and every handler now runs at priority 7 from entry (errata 40): an idle loop of "check, lower the priority, `WFE`" has the lost-wake-up window, and a loop of "check, `WFE` at priority 7" never wakes. This is the one finding of the survey that is a defect in the present text rather than a missing instruction (section 7, item 1).

**pdp64:** `WFE`/`SEV`; the spin-wait pause and the speculation barrier are **decided** (`HINT #1`, `HINT #2`; errata 39). Not needed: `monitor`/`mwait` (the `WFE`/`SEV` pair gives the same, and `mwait` on x86 is mostly used by power-management idle).

### 4.9 User-memory access

| Architecture | Instructions used (total occurrences; L Linux, F FreeBSD, N NetBSD, O OpenBSD) |
|---|---|
| x86 (i386, amd64) | `clac` 53 LFNO, `stac` 35 LFNO |
| AArch64 | `ldtr` 17 NO, `sttr` 16 NO, `ldtrb` 7 FNO, `sttrb` 6 NO, `ldtrh` 3 N, `sttrh` 3 N |
| ARM 32-bit | `ldrt` 184 LFNO, `strt` 178 FNO, `ldrbt` 45 LFNO, `strbt` 41 FNO, `ldrht` 3 N, `strht` 2 FN |
| m68k | `moves` 12 L |
| SPARC | `stxa` 612 LNO, `ldxa` 468 LNO, `sta` 219 LNO, `lda` 127 LNO, `stda` 67 LNO, `ldda` 65 LNO, `stba` 44 LNO, `lduba` 37 LNO, `stha` 25 LNO, `stwa` 24 LNO; and 5 more |
| s390 (z/Architecture) | `mvcos` 8 L, `sturg` 2 L |

What they do:

- `clac` (x86): clear the AC flag: forbid it again (SMAP on).
- `stac` (x86): set the AC flag: allow the kernel to touch user pages (SMAP off).
- `ldtr` (arm64): load as if unprivileged (user permissions).
- `sttr` (arm64): store as if unprivileged.
- `ldtrb` (arm64): byte load as unprivileged.
- `sttrb` (arm64): byte store as unprivileged.
- `ldrt` (arm): load as user.
- `strt` (arm): store as user.
- `ldrbt` (arm): byte load as user.
- `strbt` (arm): byte store as user.
- `moves` (m68k): move to or from the alternate address space (user data space) selected by SFC and DFC.
- `stxa` (sparc): store extended word to an alternate address space.
- `ldxa` (sparc): load extended word from an alternate address space (ASI).
- `sta` (sparc): store word to an alternate address space.
- `lda` (sparc): load word from an alternate address space.
- `mvcos` (s390): move with optional specifications (copy between address spaces).
- `sturg` (s390): store using real address.

Kernels copy data to and from user programs constantly (`read`, `write`, every system call argument), and every architecture has had to decide how kernel code may touch user memory safely. Three designs appear.

*A guard bit that the kernel flips around each access*: x86 `stac`/`clac` (SMAP, 88 uses: FreeBSD 50, Linux 32, NetBSD 4, OpenBSD 2), AArch64 PAN and RISC-V `sstatus.SUM` (both reached through `msr`/`csrs`, not separate instructions). Three of the largest architectures chose this one.

*A special load/store that translates as if user mode*: AArch64 `ldtr`/`sttr` (17 and 16 in NetBSD and OpenBSD; Linux uses them through macros and shows 0), ARM `ldrt`/`strt` (453 occurrences in all four kernels), MIPS EVA `lwe`/`swe` (not seen by the extraction, because Linux reaches them through macros; only `cachee` appears), m68k `moves` (alternate function codes), s390 `mvcos`/`mvcp`/`mvcs`, and the PDP-11's own `mfpi`/`mtpi` (which pdp64 dropped in favour of `PROBER`/`PROBEW`, ISA section 14.3). SPARC does the same with alternate-space loads and stores (`lda`/`sta` with a user-space tag, 1,748 occurrences), but that figure also contains MMU-register and physical-address accesses, which use the same instructions, so it cannot be read as user copies alone.

*Probe, then use ordinary instructions*: VAX `prober`/`probew`, the design pdp64 chose. A probe protects against a bad range but not against a page that becomes invalid between the probe and the access; on a machine with a copy routine that can be restarted that matters little.

The special loads have a security advantage the guard bit lacks: the translation uses the user permissions, so a *kernel* address passed in by a hostile program faults instead of being read. They also cost one instruction per access (an AArch64 copy loop uses them in place of ordinary loads), where the guard bit costs two instructions per copy. The guard bit costs nothing per access and no new opcodes.

**pdp64:** `PROBER`/`PROBEW`; kernel mode may read and write user pages, may not execute them (D11); **there is no guard against a stray kernel dereference of a user pointer**, which the design document lists as a cost. This survey adds evidence to that open item: three mainstream architectures (x86, AArch64, RISC-V) and the security-conscious BSD (OpenBSD turns SMAP on) arrived at a guard bit. Section 7, item 2.

### 4.10 Timers and counters

| Architecture | Instructions used (total occurrences; L Linux, F FreeBSD, N NetBSD, O OpenBSD) |
|---|---|
| x86 (i386, amd64) | `rdtsc` 19 LFNO, `rdtscp` 10 FO, `rdpmc` 6 LFO |
| MIPS | `rdhwr` 8 LNO |
| PowerPC | `mftb` 32 LFNO, `mftbu` 11 LFNO, `mttbl` 9 LNO, `mttbu` 5 LNO, `mftbl` 3 LN |
| LoongArch | `rdtime.d` 1 L, `rdtimeh.w` 1 L, `rdtimel.w` 1 L |
| s390 (z/Architecture) | `stpt` 12 L, `stcke` 4 L, `spt` 3 L, `stckf` 2 L, `sckc` 1 L, `stckc` 1 L |
| Alpha * | `rpcc` 12 LNO |

What they do:

- `rdtsc` (x86): read the time-stamp counter.
- `rdtscp` (x86): read it with the processor id, partly ordered.
- `rdpmc` (x86): read a performance counter.
- `rdhwr` (mips): read a hardware register (thread pointer, cycle counter).
- `mftb` (ppc): read the time base.
- `rdtime.d` (loongarch): read the stable counter.
- `stpt` (s390): store CPU timer.
- `spt` (s390): set CPU timer.
- `stckf` (s390): store clock fast.
- `rpcc` (alpha): read process cycle counter.

A kernel needs the time in two places: in the kernel for scheduling and timekeeping, and, increasingly, in *user space* through a mapped page (the vDSO) so that reading the clock is not a system call. The user-readable counter is therefore a mainstream instruction: x86 `rdtsc`/`rdtscp` (29 uses), RISC-V `rdtime`/`rdcycle`, PowerPC `mftb`, s390 `stck`/`stckf`, MIPS `rdhwr`, LoongArch `rdtime.d`, Alpha `rpcc`; AArch64 reads `cntvct_el0` through `mrs`. x86 `rdpmc` and the PowerPC and AArch64 performance-monitor registers are the rest.

**pdp64:** the virt machine has a memory-mapped free-running counter and compare register; there is no user-readable counter instruction. The readiness review lists "unprivileged `rdcycle`/`rdinstret`" under "do later". The timekeeping use (a vDSO-style clock read) is a distinct and earlier need than the performance-counter use. Section 7, item 3.

### 4.11 Hypervisor, secure and firmware calls

| Architecture | Instructions used (total occurrences; L Linux, F FreeBSD, N NetBSD, O OpenBSD) |
|---|---|
| x86 (i386, amd64) | `vmcall` 5 L, `vmrun` 5 LFO, `clgi` 4 FO, `vmload` 4 LFO, `vmread` 4 LFO, `vmwrite` 4 FO, `vmlaunch` 3 LFO, `vmmcall` 3 L, `vmresume` 3 LFO, `vmsave` 3 LFO; and 6 more |
| AArch64 | `hvc` 10 LFO, `smc` 5 LO |
| ARM 32-bit | `smc` 6 LFNO, `hvc` 4 LNO |
| RISC-V | `hlvx.hu` 2 F |
| LoongArch | `hvcl` 6 L, `gcsrrd` 1 L, `gcsrwr` 1 L, `gcsrxchg` 1 L |
| s390 (z/Architecture) | `diag` 33 L, `sie` 1 L |

What they do:

- `vmcall` (x86): call the hypervisor (Intel).
- `vmrun` (x86): run a guest (AMD).
- `vmload` (x86): load guest state (AMD).
- `hvc` (arm64): hypervisor call.
- `smc` (arm64): secure monitor call (firmware).
- `smc` (arm): secure monitor call (firmware).
- `hvc` (arm): hypervisor call.
- `hlvx.hu` (riscv): hypervisor load with execute permission.
- `diag` (s390): diagnose: call to the hypervisor.
- `sie` (s390): start interpretive execution (run a guest).

Two things live in this class: *virtualisation* (x86 `vmcall`/`vmlaunch`/`vmresume`/`vmrun`, the `vm*` family; LoongArch `hvcl`; s390 `sie` and `diag`; RISC-V `hlv`/`hsv`/`hfence`) and *calls to firmware or a monitor below the kernel* (AArch64 `hvc` and `smc`, which carry the power-management calls that bring other cores up and shut the machine down; RISC-V `ecall` from supervisor mode into the SBI, 14 `ecall` uses; PowerPC `sc 1`/`hvc`; Alpha `call_pal` and the console service `cserve`).

**pdp64:** no hypervisor extension and none is planned; the supervisor mode exists in the PSW with no user. What every secondary-core boot and every power-off needs is a *firmware call*, and since `RESET` was dropped (errata, ISA section 4.11.1) there is no instruction to ask for one. A convention (a reserved range of `TRAPL` vector numbers handled by firmware) costs no opcodes. Section 7, item 8.

### 4.12 String and memory-block primitives

| Architecture | Instructions used (total occurrences; L Linux, F FreeBSD, N NetBSD, O OpenBSD) |
|---|---|
| x86 (i386, amd64) | `cld` 163 LFNO, `lods` 54 LNO, `stos` 48 LNO, `movnti` 41 LFO, `std` 20 LFNO, `repe cmps` 14 LO, `movntdq` 9 FO, `repne movs` 8 O, `rep vmmcall` 7 LO, `repne scas` 7 LO; and 12 more |
| AArch64 | `cpye` 1 L, `cpym` 1 L, `cpyp` 1 L, `sete` 1 L, `setm` 1 L, `setp` 1 L |
| PowerPC | `lswx` 4 N, `stswx` 4 N, `lswi` 1 N, `stswi` 1 N |
| s390 (z/Architecture) | `mvcl` 3 L, `tr` 2 L, `cksm` 1 L, `clcle` 1 L |
| VAX | `locc` 10 N, `cmpc3` 3 N, `scanc` 1 N, `skpc` 1 N |

What they do:

- `cld` (x86): clear direction flag: string operations go upward (the ABI requires it, so kernels clear it at every entry).
- `lods` (x86): load from memory and step.
- `stos` (x86): store accumulator to memory and step: block fill with rep.
- `movnti` (x86): non-temporal store (bypasses the cache).
- `mvcl` (s390): move long (interruptible block move).
- `tr` (s390): translate.
- `locc` (vax): locate a character.
- `cmpc3` (vax): compare characters.
- `scanc` (vax): scan characters through a table.
- `skpc` (vax): skip characters.

x86 is the outlier: 397 of the 435 occurrences. Note first what is *not* in the table: the plain `rep movs` and `rep stos`, which gcc and clang do emit at `-Os` for block copies and fills, are not compiler-invisible. What the kernels add is the rest of the string family: `lods` 54, `stos` without `rep` 48, the comparing and scanning forms (`repe cmps` 14, `repne scas` 7, `repe scas` 6, mostly OpenBSD, for string length and comparison), and the non-temporal stores `movnti` 41 (Linux 34, for clearing pages without polluting the cache). The family also needs `cld`, which is the single most frequent instruction of the whole x86 survey (163 uses in all four kernels): the ABI says the direction flag is clear on function entry and a kernel cannot trust it after an interrupt from user code, so the entry paths clear it. s390 has `mvc`/`clc`/`xc`/`oc`/`tr`/`trt`/`srst`/`mvst`, the VAX `movc3`/`movc5`/`cmpc3`/`locc`/`scanc`, PowerPC the string instructions `lswx`/`stswx`; and AArch64 and Linux have started to use `cpyp`/`cpym`/`cpye` and `setp`/`setm`/`sete` (FEAT_MOPS, 1 use each so far, in Linux).

**pdp64:** `MCPY`, `MMOV`, `MSET`, `MCMP`, `MSCN`, `MSCNN`, `MVAL` with progress left in registers (the `rep` idea without the direction flag, the s390 `mvcle` and the AArch64 FEAT_MOPS design: ISA section 4.7 already notes that). The survey supports the design; there is no direction flag to clear at every entry.

### 4.13 Bit manipulation

| Architecture | Instructions used (total occurrences; L Linux, F FreeBSD, N NetBSD, O OpenBSD) |
|---|---|
| x86 (i386, amd64) | `popcnt` 4 F, `tzcnt` 1 L |
| RISC-V | `orc.b` 7 L, `clz` 1 L, `cpop` 1 L, `ctz` 1 L |
| MIPS | `dins` 21 LN, `dclz` 8 LN, `clo` 1 L, `dclo` 1 L |
| PowerPC | `popcntd` 1 L |
| LoongArch | `bitrev.4b` 2 L, `bitrev.w` 1 L |
| m68k | `bfffo` 9 LN, `bchg` 4 L, `bfclr` 3 L, `bfset` 3 L, `bfchg` 2 L |
| SPARC | `popc` 6 L |
| Alpha * | `cttz` 8 L, `ctlz` 3 L, `ctpop` 2 L |
| VAX | `ffs` 2 N |

What they do:

- `popcnt` (x86): population count.
- `tzcnt` (x86): trailing-zero count.
- `orc.b` (riscv): bytewise or-combine (strlen helper).
- `bfffo` (m68k): find first set bit in a bit field.
- `popc` (sparc): population count.
- `cttz` (alpha): count trailing zeros.
- `ctlz` (alpha): count leading zeros.
- `ctpop` (alpha): population count.
- `ffs` (vax): find first set bit.

Small class (92 occurrences), included for completeness. The kernels write `bsf`/`bsr` (find first/last set) and `bt` forms in x86 inline assembly for `ffs`/`fls` and bitmaps, `bfffo` and `bfextu` bit-field instructions in m68k, `cntlzw`/`cntlzd` on PowerPC, `clz`/`ctz`/`cpop` from RISC-V's Zbb in Linux (1 use each so far), `rbit`/`cls` on AArch64, `ctlz`/`cttz` on Alpha, `ffs`/`ffc` on VAX.

**pdp64:** `POPCNT`, `CLZ`, `CTZ`, `BSWAP`, `BITREV`, bit-field operations; fully covered.

### 4.14 Interrupt masking

| Architecture | Instructions used (total occurrences; L Linux, F FreeBSD, N NetBSD, O OpenBSD) |
|---|---|
| x86 (i386, amd64) | `popf` 135 LFNO, `cli` 133 LFNO, `sti` 133 LFNO, `pushf` 127 LFNO |
| ARM 32-bit | `cpsid` 24 LFNO, `cpsie` 14 LNO, `cps` 3 NO |
| MIPS | `di` 9 LN, `ei` 2 LN |
| PowerPC | `wrteei` 48 LFN, `wrtee` 26 LFN |

What they do:

- `popf` (x86): pop the flags register (restores the interrupt state).
- `cli` (x86): clear interrupt flag: disable interrupts.
- `sti` (x86): set interrupt flag: enable interrupts (effective after the next instruction, so "sti; hlt" cannot lose a wake-up).
- `pushf` (x86): push the flags register (used to save the interrupt state).
- `cpsid` (arm): disable interrupts.
- `cpsie` (arm): enable interrupts.
- `cps` (arm): change processor state.
- `di` (mips): disable interrupts.
- `ei` (mips): enable interrupts.
- `wrteei` (ppc): write external-interrupt enable immediate.
- `wrtee` (ppc): write external-interrupt enable from a register.

Four architectures have a dedicated instruction for the global interrupt mask: x86 `cli`/`sti` (266 uses) and `pushf`/`popf` (262 uses; the save-and-restore pair that implements "disable interrupts, remember whether they were on"), ARM `cpsid`/`cpsie`, PowerPC `wrteei`/`wrtee`, MIPS `di`/`ei`. The others change a bit in a status register (AArch64 `msr daifset`, RISC-V `csrc sstatus`). None has a *priority level* in hardware except the VAX (`mtpr` to the interrupt-priority register), m68k (the mask in the status register), SPARC (`pil`) and PDP-11 lineage; NetBSD and OpenBSD therefore implement `spl` in software on x86 and AArch64 (a priority variable in the per-CPU structure that the interrupt entry code checks; from the sources' design, not counted here).

**pdp64:** `SPL #n` sets the priority (eight levels, as the PDP-11), `MFPS` reads, `MTPS` writes; entry forces 7. This is the VAX/PDP-11 position, and the BSD kernels have spent decades emulating it in software. It is the design the survey most clearly vindicates. A save/restore of the old level is `MFPS` then `SPL`, then `MTPS` (which also rewrites the flags and mode bits; harmless in kernel mode). A register-operand `SPL` would remove the `MTPS` but has no evidence in the survey (zero uses of such an instruction anywhere) and is not proposed.

### 4.15 CPU identification and feature detection

| Architecture | Instructions used (total occurrences; L Linux, F FreeBSD, N NetBSD, O OpenBSD) |
|---|---|
| x86 (i386, amd64) | `cpuid` 73 LFNO, `rdpid` 1 F |
| s390 (z/Architecture) | `stidp` 2 L, `stsi` 1 L |
| Alpha * | `amask` 3 LNO, `implver` 3 LNO |

What they do:

- `cpuid` (x86): report processor identity and feature flags.
- `rdpid` (x86): read the processor id.
- `stidp` (s390): store CPU id.
- `stsi` (s390): store system information.
- `amask` (alpha): architecture feature mask.
- `implver` (alpha): implementation version.

x86 `cpuid` is used 73 times in the four kernels; AArch64, ARM and RISC-V read identification registers through `mrs`/`mrc`/`csrr`; s390 has `stidp`/`stfle`/`stsi`; Alpha `amask`/`implver`; PowerPC `mfpvr`. The purpose is to select code at boot: Linux patches instructions in place at start-up (section 6), the BSDs branch on a feature word or select an implementation through a function pointer.

**pdp64:** `MFCPUID`/`cpuid` returns only the core number; "where identification beyond the core number (features, ISA version) is reported" is an open item in the architecture document. The survey says a version-and-feature register is needed by a first kernel. It costs a `mfsr` number, no instruction (section 7, item 4).

### 4.16 Random numbers

| Architecture | Instructions used (total occurrences; L Linux, F FreeBSD, N NetBSD, O OpenBSD) |
|---|---|
| x86 (i386, amd64) | `rdrand` 12 LNO, `rdseed` 9 LNO |
| PowerPC | `darn` 1 O |

What they do:

- `rdrand` (x86): hardware random number.
- `rdseed` (x86): hardware seed for a generator.
- `darn` (ppc): deliver a random number.

x86 `rdrand`/`rdseed` (21 uses), PowerPC `darn`, s390 `prno`, AArch64 `rndr` (through `mrs`). Used for early-boot entropy and address-space randomisation. No other architecture in the survey has one.

**pdp64:** nothing; a memory-mapped entropy device (a virtio-rng-style device on the Q64 bus) does the job and keeps the ISA free of it. Not proposed.

### 4.17 I/O and device access

| Architecture | Instructions used (total occurrences; L Linux, F FreeBSD, N NetBSD, O OpenBSD) |
|---|---|
| x86 (i386, amd64) | `out` 103 LFNO, `in` 67 LFNO, `rep ins` 17 LFN, `rep outs` 17 LFN, `repne ins` 6 O, `repne outs` 6 O |
| s390 (z/Architecture) | `tsch` 2 L, `ssch` 1 L, `stsch` 1 L, `tpi` 1 L |

What they do:

- `out` (x86): write to an I/O port.
- `in` (x86): read from an I/O port.
- `rep ins` (x86): repeat: block read from an I/O port.
- `rep outs` (x86): repeat: block write to an I/O port.
- `tsch` (s390): test subchannel.
- `ssch` (s390): start subchannel (I/O).
- `stsch` (s390): store subchannel.

Only x86 (`in`/`out`, `ins`/`outs` with `rep`: 216 occurrences) and s390 (channel I/O: `ssch`, `tsch`, `stsch`) have I/O instructions at all. Everyone else, and pdp64, uses memory-mapped device registers with a memory type that forbids reordering and caching. Nothing to add.

### 4.18 Breakpoints, speculation and control-flow integrity

| Architecture | Instructions used (total occurrences; L Linux, F FreeBSD, N NetBSD, O OpenBSD) |
|---|---|
| x86 (i386, amd64) | `int3` 56 LNO |
| AArch64 | `udf` 2 NO, `hlt` 1 L |
| RISC-V | `unimp` 3 NO |
| MIPS | `tne` 2 LN, `tge` 1 N, `tlt` 1 N |
| PowerPC | `twi` 13 L, `tdi` 1 L |
| SPARC | `sir` 26 NO |
| VAX | `bpt` 1 N |

| Architecture | Instructions used (total occurrences; L Linux, F FreeBSD, N NetBSD, O OpenBSD) |
|---|---|
| x86 (i386, amd64) | `endbr64` 47 LO, `wruss` 1 L |
| AArch64 | `bti` 6 O |

What they do:

- `int3` (x86): one-byte breakpoint.
- `udf` (arm64): permanently undefined.
- `hlt` (arm64): halt until an interrupt.
- `unimp` (riscv): illegal instruction.
- `twi` (ppc): trap word immediate.
- `tdi` (ppc): trap doubleword immediate.
- `sir` (sparc): software-initiated reset.
- `bpt` (vax): breakpoint.

What they do:

- `endbr64` (x86): landing pad for indirect branches (CET).
- `wruss` (x86): write user shadow stack.
- `bti` (arm64): branch target landing pad.

Breakpoints are universal and trivial (`int3`, `brk`, `ebreak`, `break`, `trap`, `bpt`); Linux x86 has 50 of the 56 `int3` uses, because it patches running kernel code with a breakpoint while it rewrites it (`kprobes`, static calls, alternatives). The class that has grown in the last decade is **speculation control** and **control-flow integrity**: x86 `endbr64` (47 uses: Linux 32, OpenBSD 15) and AArch64 `bti` (6, OpenBSD) mark the legal targets of indirect branches; x86 `lfence` as a speculation barrier (OpenBSD 108 of 152 uses; Linux 7), `verw` as a buffer-clearing instruction (7); AArch64 `csdb`, `sb`, `ssbb` do not appear as such in the extraction (they pass through macros). The count is small but it is the newest class and it changed the code of every entry path.

**pdp64:** `BPT`; `LPAD` for landing pads (the `endbr64` and `bti` analogue); the speculation barrier is **decided** (`HINT #2`, errata 39, and the readiness review's rule that mitigations must be barriers and not mode bits).

### 4.19 Per-CPU and thread base

| Architecture | Instructions used (total occurrences; L Linux, F FreeBSD, N NetBSD, O OpenBSD) |
|---|---|
| x86 (i386, amd64) | `swapgs` 65 LFNO, `rdfsbase` 7 LF, `rdgsbase` 4 LF, `wrgsbase` 4 LF, `wrfsbase` 3 LF |

What they do:

- `swapgs` (x86): swap the GS base with a saved kernel value: gives the kernel its per-CPU pointer on entry.
- `rdfsbase` (x86): read the FS base (thread pointer).
- `rdgsbase` (x86): read the GS base from user or kernel code.
- `wrgsbase` (x86): write it.

> **Surprise: the scratch-register problem, and who needs `swapgs`.** At the first instruction of an exception handler a kernel has no free register and does not yet have a usable stack, but it needs to find *its own* data. Every architecture invented a trick, and the tricks are the content of this class even though most are not separate instructions. x86: `swapgs` (65 uses, all four kernels) swaps the user's `GS` base for a saved kernel one so that `%gs`-relative addressing reaches per-CPU data. AArch64: `tpidr_el1` (44 operand uses) holds the per-CPU pointer and `sp_el0` the current task. RISC-V: `sscratch` (34 uses), exchanged with the thread pointer in a single `csrrw` at the very first instruction. MIPS: two registers, `k0` and `k1`, are *reserved for the kernel by the ABI* (101 uses). LoongArch: three kernel-scratch CSRs (`KS0`..`KS2`, 36). PowerPC: the `sprg` registers (35+). SPARC: the alternate global-register set that a trap switches to. m68k and the VAX push everything on the stack and need no scratch.

**pdp64:** nothing needed, by construction: `R14` and `DP` are banked per mode, `DP` in kernel mode is the per-CPU pointer, and `PUSHM` saves every register with only `SP`. Entry needs no scratch register, no swap, no reserved register. The survey counts seven architectures that pay for this problem.

## 5. Architectures at a glance

One portrait per architecture: the instructions that make its kernel different.

**x86 (i386 and amd64).** A kernel that carries a long history. Entry: `swapgs`, `syscall`/`sysret` beside the old `int`/`iret`; segment machinery that only boot code still needs (`ljmp` 91, `lret`, `lcall`, `lgdt`, `lidt`, `ltr`, 24 uses of each of the table loads); the model-specific register file (`rdmsr` 129, `wrmsr` 161); the flag save-and-restore pair (`pushf`/`popf` 262); the direction flag (`cld` 163); I/O ports; the `lock` prefix on read-modify-write instructions (Linux alone has 36 `lock cmpxchg`, 13 `lock cmpxchg8b`); SMAP (`stac`/`clac`); virtualisation (`vmlaunch` family, 50 uses); the mitigations (`lfence`, `verw`, `endbr64`). Four kernels, 10,300 to 20,400 lines of assembler files each.

**AArch64.** The cleanest of the modern privileged architectures. Entry is by a vector table of 16 slots; the kernel entry macro saves 30 registers in 15 `stp` instructions. System registers by name (`mrs`/`msr`, 105 distinct); barriers that are mostly `isb`/`dsb`; TLB maintenance by named operation (`tlbi vale1is`); exclusive pairs and, since version 8.1, the single-instruction atomics; `eret`; unprivileged loads `ldtr`/`sttr`; `hvc`/`smc` for firmware. Among the smaller hand-written cores (Linux 6,698 lines in 44 files).

**ARM 32-bit.** The biggest compiler-invisible population in its time: coprocessor-15 moves (`mcr`/`mrc`, 372 distinct patterns) do cache, TLB and MMU control; `cpsid`/`cpsie`; `ldrex`/`strex`; `ldrt`/`strt`; `rfe`/`srs`; banked registers per mode. Linux ARM has 164 assembler files, the most of any Linux port.

**RISC-V.** The privileged interface is a set of control and status registers and a handful of instructions: `csrr`, `csrw`, `csrs`, `csrc`, `csrrw` (and the immediate forms) cover everything privileged; `sret`/`mret`, `ecall`, `wfi`, `sfence.vma`, `fence`/`fence.i`, `lr`/`sc` and `amo*`. About 120 compiler-invisible mnemonics in total; `sscratch` swapped with `tp` at entry.

**MIPS.** Coprocessor 0 (`mfc0`/`mtc0`/`dmfc0`; `mtc0` alone 221 uses in NetBSD), a software-refilled TLB (`tlbp`, `tlbr`, `tlbwi`, `tlbwr`), `eret`, `cache` by index and address (276 uses), `ll`/`sc`, `sync`, and the delay-slot and hazard instructions (`ehb`, `ssnop`, `jr.hb`). `k0` and `k1` are kernel-reserved registers.

**PowerPC.** The largest hand-written population (Linux 13,911 assembler statements, 3,251 occurrences of classified instructions): `mfspr`/`mtspr` with hundreds of register names, the exception returns `rfi`/`rfid`/`hrfid`/`rfci`/`rfmci` for the different exception levels, the segment and TLB instructions of the server (`slb*`) and embedded (`tlbwe`, MAS registers) lines, `isync` (662 uses) and `sync` (483), reservations `lwarx`/`stwcx.`, `dcbz`/`dcbf`/`icbi`.

**LoongArch.** A MIPS-like system with RISC-V-like CSRs: `csrrd`/`csrwr`/`csrxchg`, `ertn`, `invtlb` with an operation code, software-assisted refill (`tlbsrch`, `tlbfill`, `lddir`, `ldpte`), `dbar`/`ibar`, `ll`/`sc` and the barrier-fused atomics (`amadd_db`, whose idea pdp64 adopted: ISA section 15). Only Linux has the port.

**m68k.** `movem` saves any subset of sixteen registers in one instruction, `rte`, `trap #n`, `movec` for control registers, `moves` for alternate address spaces, `cinv`/`cpush`, `pflush`/`ptest`, `tas`/`cas`. A syscall entry in NetBSD is six instructions and the exit eight (section 8).

**SPARC (v9).** Register windows: `save`/`restore` allocate and release a window; a trap handler uses `saved`/`restored`/`flushw`; `retry`/`done`; privileged registers through `rdpr`/`wrpr` (324 uses in NetBSD's SPARC code); the MMU and cache controlled by alternate-space loads and stores (`ldxa`/`stxa`, 1,080 occurrences); `membar #Sync` 533; `casa`, `ldstub`. The architecture with the most assembler per port.

**s390 (z/Architecture).** The program-status word model: `lpswe` loads PC, condition code and mode in one step; the old PSW is saved in fixed low memory; control registers `lctlg`/`stctg`; `mvc`/`clc`/`xc` string operations of up to 256 bytes; `cs`/`csg`/`cdsg` and the fetch-and-operate `laa`/`lan`/`lao`; channel I/O; `sie` for guests; `stmg`/`lmg` for context saves. Only Linux; written mostly as inline assembly.

**Alpha.** The kernel interface is *one instruction*: `call_pal`, which calls PALcode (privileged architecture library: software in a special mode that implements the privileged operations). The NetBSD kernel uses `pal_osf1_swpipl` (set interrupt priority level, 17 uses), `halt` 13, `cserve` 12, `gentrap` 8, `rdps` 5, `whami` 4, `wrkgp`, `wrvptptr`, `tbi` (TLB invalidate), `imb`, `swpctx` (context switch), `rti`, `callsys`. Memory barriers `mb`/`wmb`/`trapb`/`excb`, `ldl_l`/`stl_c`, `rpcc`. A hardware designer's way to leave the hardware simple and move the operating-system interface into replaceable software, which is relevant to pdp64 as a road not taken.

**VAX.** See the sidebar below.

**PA-RISC and m88k** (NetBSD and OpenBSD hppa, OpenBSD m88k) have no compiler baseline; the kernels show the control-register moves (`mfctl`/`mtctl`, `ldcr`/`stcr`), `rfi`/`rte`, TLB purge instructions, the single atomic `ldcw` on PA-RISC and `xmem` on m88k.

> **Sidebar: what the VAX did in hardware that every later machine does in software.** The NetBSD VAX port is the closest relative of pdp64 in the survey and the most instructive, because of what its assembly does *not* contain. (1) **Context switch by instruction.** `svpctx` stores the registers, the stack pointers and the page-table registers of the running process into the process control block named by a processor register and switches to the interrupt stack; `ldpctx` loads all of them for the next process. The switch routine of NetBSD (`Swtchto`) is `svpctx`, a few moves, `ldpctx`, `rei`: about ten instructions. (2) **System call by instruction with a stack per mode.** `chmk` changes the mode to kernel and switches to the kernel stack; the syscall entry is about ten instructions including `pushr` (one instruction saves twelve registers named by a mask). (3) **Validated return.** `rei` pops the PC and status and checks them. (4) **Address probing.** `prober`/`probew` check a range for a given mode. (5) **Interlocked queues and bit operations**: `bbssi`/`bbcci`, `insqhi`/`remqhi`. (6) **Priority levels**: `mtpr` to `IPL` (40 uses). (7) **String instructions** `movc3`/`movc5`/`locc`/`cmpc3`. What pdp64 takes from this: the register-save mask (`PUSHM`/`POPM`: VAX `pushr`/`popr`, 48 uses), the probe (`PROBER`/`PROBEW`: VAX), the priority levels (`SPL`), and the progress-in-registers block instructions in place of `movc5`'s hidden state (ISA section 4.7). What it deliberately does not take: the hardware process control block (the survey's own numbers explain why, section 8: pdp64's pushm/pushx switch path is a handful of instructions already, and a PCB format would fix the register file in the architecture), the `calls`/`ret` frame, the microcoded queues (pdp64 has `CAS`), and `mtpr` as a numbered register file with side effects (pdp64's `MFSR`/`MTSR` registers are plain).

## 6. Linux against the BSDs

The four kernels solve the same problems with visibly different habits.

**Linux patches itself; the BSDs choose at run time or at link time.** Linux contains `ALTERNATIVE`-style macros that put two instruction sequences in the source and rewrite the code once at boot according to the processor's features: the textual count of those macros in the surveyed directories is 262 lines on x86, 269 on PowerPC, 187 on AArch64, 137 on s390, 128 on RISC-V, 112 on ARM, 29 on LoongArch (a `grep` count over `arch/*`, not part of the extraction). The BSDs use a feature test at run time (FreeBSD's amd64 trap entry tests the CPU feature word to decide whether to read the `FS`/`GS` base, as seen in its `exception.S`), function-pointer selection (`DEFINE_IFUNC` appears in 24 files of FreeBSD's machine directories), or, for OpenBSD, a code-patching facility (`codepatch`, 145 lines in amd64, arm64 and i386). The consequence for the asm inventory: Linux's alternatives hide the *second* instruction of each pair inside macro arguments, and the extraction takes both.

**Linux writes more of its assembly inline, in headers; the BSDs write more in `.S` files.** Statement counts from the extraction: Linux 51,454 in assembler files and 7,905 in C/H (13% inline); FreeBSD 13,809 and 1,936 (12%); NetBSD 39,564 and 3,211 (7.5%); OpenBSD 22,406 and 1,980 (8%). On x86 specifically: Linux 4,822 and 1,116 (19%), FreeBSD 5,028 and 505 (9%), NetBSD 7,719 and 135 (1.7%), OpenBSD 7,269 and 643 (8%). NetBSD x86 is almost entirely `.S`; Linux x86 inline fragments define the atomics, bit operations, user-access, MSR and per-CPU interface in headers (`arch/x86/include/asm`), whereas FreeBSD puts the same in `cpufunc.h` and `atomic.h` and OpenBSD in `cpufunc.h`.

**Same architecture, same job, different instruction.** User-memory access on x86: Linux wraps accesses in `stac`/`clac` pairs (32 uses), FreeBSD uses them 50 times, NetBSD 4 and OpenBSD 2 (OpenBSD's `copyin` is in one place; the count shows that the BSDs with fewer sites concentrate the guard in the copy routines). User access on AArch64: NetBSD and OpenBSD write the `ldtr`/`sttr` forms in `copyin`/`copyout` assembly; Linux uses them through the `USER()` fixup macro so they are invisible to the extraction; FreeBSD uses `ldtrb` once. Speculation: OpenBSD x86 has 108 `lfence` uses, Linux 7 and FreeBSD 31, because OpenBSD and FreeBSD write it out in the entry and exit paths, while Linux reaches it through alternatives and macros that the extraction sees only in part. Control-flow integrity: Linux x86 has 32 `endbr64`, OpenBSD 15, FreeBSD and NetBSD none; AArch64 `bti` appears only in OpenBSD in this snapshot.

**Priorities.** The BSDs have more *explicit trap-return and locore code per port*; Linux has more *breadth* (eleven architectures here against five for FreeBSD) and far more **mitigation and patching machinery**. Linux almost alone uses `int3` for patching running code (50 of 56 uses) and has `kvm` assembly for guests (VMX/SVM entry). NetBSD keeps ports for very old hardware (VAX, m68k, hppa, sparc32) whose assembly is the closest to pdp64's own era; its VAX, m68k and SPARC files are the best reference for a machine with a small instruction set.

**Hand-written but generic.** Where Linux differs most is how the entry code is *generated*: macros such as `kernel_entry` (AArch64), `SAVE_ALL`/`RESTORE_ALL` (LoongArch, m68k), `PUSH_AND_CLEAR_REGS` (x86) expand to long runs of the same instruction; the BSDs write them out in `locore`. For the static count this means Linux's `stp` runs are counted once (the macro body) while the BSDs' are counted at each place.

## 7. What pdp64 should take

**Already decided or in the design, and supported by the survey** (no new recommendation; the survey's evidence is added):

| Item | Where decided | What the survey adds |
|---|---|---|
| `MFSR`/`MTSR` as a general pair with an 8-bit register number | errata 32 | All 13 architectures with a register file do the same; kernels touch 5 to 100 distinct registers (section 4.3) |
| `PUSHX`/`POPX` | errata 37 | The VAX `pushr` (one instruction saves 12 registers) and the m68k `movem` show the same gain; RISC kernels spend 15 to 60 instructions on the register save that pdp64 spends two on (section 8) |
| Priority 7 on every entry | errata 40 | x86, AArch64, RISC-V, PowerPC, MIPS and SPARC all mask interrupts on entry (manuals); the VAX and m68k raise the priority |
| `ISYNC` | errata 39 | 187 `isb`, 662 `isync`, 533 SPARC `membar #Sync`, `fence.i`, `ibar`: the context-synchronising barrier is the most used barrier in four of the six major architectures (section 4.5) |
| `HINT #1` pause, `#2` speculation barrier, prefetch | errata 39, readiness 6 | x86 `pause` 30 uses, `lfence` 152, `mwait` 18; AArch64 `yield`; RISC-V `pause`; `prfm`/`pld`/`dcbt` 100+ (sections 4.4, 4.8, 4.18) |
| Reservation and `LL`/`SC` rules, TLB and page-table visibility rules | readiness 7, 10 | `clrex` (2), the dummy `stwcx.` that Linux PowerPC performs at a context switch (known practice, not counted here), and the AArch64 and Power reservation text (section 4.1) |
| `TLBI`, `TLBIA`, `TLBSYNC`, broadcast | ISA section 17 | Hardware-walker side of the table; none of the software refill instructions of MIPS/PowerPC-embedded/PA-RISC/LoongArch (section 4.6) |
| Banked `R14`/`DP` and `PUSHM` | ISA section 2 | Removes the scratch-register problem that seven architectures pay for (section 4.19) |
| `MCPY` family with progress in registers | ISA section 4.7 | x86 `rep` (397 occurrences), s390 `mvc`/`mvcle`, VAX `movc`, AArch64 FEAT_MOPS (section 4.12) |
| Atomics set, `_DB` forms | ISA section 4.11 | All three designs (LL/SC, CAS, fetch-and-op) appear on one architecture or another; pdp64 has all (section 4.1) |
| No FPU state to save | ISA section 2.3 | x86 has 20 invisible FPU/vector-state mnemonics (section 4.7) |
| Perf counters and `rdcycle` "do later" | readiness 7, 8 | See item 3 below: the timekeeping use is separate and earlier |

**New proposals, ranked by evidence and cost.** Encoding costs refer to `SYSX` (class 0 minor 15, sub-opcode in parcel 1: 254 free) and to `mfsr` numbers 13 to 255; none uses a page-1 top-level opcode.

| # | Proposal | Evidence | Cost | Verdict |
|---|---|---|---|---|
| 1 | **Specify that `WFE` wakes when an interrupt becomes pending even if the priority masks it, without taking it** (RISC-V and AArch64 `wfi` rule); and that `SEV` is sticky for one wait | The lost-wake-up race is solved on x86 (the `sti` shadow), AArch64 and RISC-V; every kernel has an idle loop (`hlt` 57, `wfi` 29, `wait`, `idle`, `stop`). Present text ("sleeps until an interrupt is taken") plus errata 40 gives either a race or a hang | Zero opcodes; text; one line in the core | **Add (text)** |
| 2 | **User-memory guard bit**: PSW bit 12 (`UA`); with `UA` = 0 a kernel-mode data access to a `U` page faults; two `SYSX` sub-opcodes (`STUA`, `CLUA`, four bytes, or page-2 forms if a spare opcode is wanted) set and clear it; `MTPS` and the entry/`RTI` path handle it like any PSW bit (entry clears it, `EPSW` keeps it) | x86 `stac`/`clac` 88 uses, AArch64 PAN, RISC-V `SUM`; OpenBSD enables SMAP; D11 lists the missing guard as a known cost; copy routines (`MCPY` from user memory) would be the only users: two instructions per copy | One PSW bit (bits 12 to 15 are reserved), 2 of 254 `SYSX` sub-opcodes, no page-1 opcode | **Add** (answers D11) |
| 3 | **`RDTIME rd`**: an unprivileged read of the free-running counter that the virt timer already has (64-bit, constant frequency, monotonic, the same on every core); kernel can trap or disable it with a bit in a system register if needed | x86 `rdtsc`/`rdtscp` 29 uses, RISC-V `rdtime`, PowerPC `mftb`, s390 `stck`, MIPS `rdhwr`, LoongArch `rdtime`, AArch64 `cntvct`; every `clock_gettime` fast path | One `SYSX` sub-opcode (the 8-bit pad holds the register), plus a counter definition | **Add** (earlier than the "do later" performance counters) |
| 4 | **Feature and identification registers**: `mfsr` numbers 13 (`isa`: version, extensions present, page-size and address-width fields) and 14 (`features2`, reserved) | `cpuid` 73 uses; `mrs` of the ID registers; `stfle`; `amask`/`implver`; the architecture document lists it as open | `mfsr` numbers only | **Add** |
| 5 | **TLB invalidate by address-space tag** (`TLBIASID rN`, the ASID in `rN`, broadcast like `TLBI`) | AArch64 `aside1is` (FreeBSD 2, OpenBSD 2), RISC-V `sfence.vma` with an ASID operand, x86 `invpcid` 14 uses, LoongArch `invtlb` codes; needed at process exit and ASID recycling instead of `TLBIA` | One `SYSX` sub-opcode | **Add, medium priority** (`TLBIA` works until the first ASID rollover) |
| 6 | **Reserve** `SYSX` sub-opcodes for data-cache clean, invalidate and flush by address | 12 architectures, but all of them have non-coherent DMA or persistent memory; x86 and s390, coherent, use 21 and 4 | 3 reserved sub-opcodes, no implementation | **Reserve only**, implement when a non-coherent master exists |
| 7 | **Firmware-call convention**: a reserved range of `TRAPL` vector numbers for calls from kernel mode to the machine's firmware (power off, start a secondary core, reset), with a register convention | AArch64 `hvc`/`smc` (15), RISC-V SBI `ecall` (14), Power `hvc`, s390 `diag`; `RESET` was dropped, so there is no way to ask | Text only | **Specify** |
| 8 | **Double-width compare-and-swap** (`CAS2`: 128 bits at 8-aligned address) | x86 `cmpxchg16b` 4 uses, AArch64 `casp` 2, RISC-V `amocas.q` 1, s390 `cdsg`; one Linux-driven use (lock-free freelist with a tag); pdp64 has `LL`/`SC` | An `ATOM` sub-opcode | **Do not add now**; evidence is Linux-only |
| 9 | **`rdrand`-style instruction** | x86 21 uses, Power `darn`, s390 `prno` | An instruction | **Do not add**; a Q64 entropy device suffices |

**Not needed, with the reason.** `swapgs`, scratch CSRs and reserved registers (banked `DP`/`SP`); `pause` as a separate opcode (decided as `HINT #1`); `isb` (decided as `ISYNC`); `lock` prefixes, `bts`/`btr` atomics (2-3 instructions with `xor_`); `mwait`/`monitor` (`WFE`/`SEV`); the string `rep` family and `cld` (no direction flag); `xsave`/`fxsave`/lazy FPU (no FPU state); `rdmsr`-style 32-bit register spaces (`mfsr`); I/O port instructions (memory-mapped devices); software TLB refill instructions (hardware walker); hardware context switch (`svpctx`/`ldpctx`; section 5 sidebar); register windows; PALcode; segment registers; hypervisor instructions (none planned; supervisor mode is the place for them if ever).

## 8. Entry, exit and context-switch path lengths

The three paths a kernel runs most often are the system call, the generic exception (a fault or an interrupt) and the thread switch. The table counts the *assembly instructions executed on the common straight-line path*, from the hardware event to the call of the C dispatcher (entry), from the return of the C code to the privileged return instruction (exit), and for the switch routine (from the call to the return into the new thread). **How counted:** by reading the source and the entry macros; the "counted" entries are the tool's instruction count over the routine's line range (`C`, conditional paths included, so an upper bound); "estimated" entries (`E`) expand macros by hand and treat feature-patched and mitigation-only instructions as absent unless noted. All figures are approximate (plus or minus 25%), static, and exclude the C code. Details are in Appendix C. The pdp64 row is a paper estimate from System v1, not a measurement (a dynamic measurement is being made separately).

| Architecture and kernel | System call entry | System call exit | Generic exception entry / exit | Context switch | Method |
|---|---:|---:|---:|---:|---|
| x86-64, Linux | about 45 | about 30 | about 45 / 35 | 17 | switch: C (`__switch_to_asm`, 6 push, 6 pop, 2 mov, jmp, plus 2 canary moves); others E (`entry_SYSCALL_64`, `PUSH_AND_CLEAR_REGS` 15 push + 10 clear, page-table switch 3) |
| x86-64, FreeBSD | 34 | 27 | not counted | about 70 on the common path (170 statements in `cpu_switch`) | C on `fast_syscall_common` ranges; switch E |
| AArch64, Linux | about 60 | about 45 | about 60 / 45 | 21 | switch C; `kernel_entry` / `kernel_exit` E (15 `stp` + about 30 bookkeeping; 15 `ldp` + about 25) |
| AArch64, FreeBSD | about 50 | about 45 | about 50 / 45 | 46 (all paths) | E from `save_registers`, `restore_registers`; switch C |
| ARM 32-bit, Linux | about 35 | about 20 | not counted | 27 | C on `vector_swi` (27), `restore_user_regs` ranges |
| RISC-V, Linux | about 66 | about 45 | about 66 / 45 | about 39 | E: `handle_exception` (32 statements + 26 register stores in a macro) and `ret_from_exception`; switch C 9 + 30 macro statements |
| RISC-V, FreeBSD | about 45 | about 45 | about 45 / 45 | 86 (all paths) | C on `save_registers`/`load_registers` (both modes counted, so an upper bound) |
| MIPS, Linux | about 55 | about 45 | about 55 / 45 | about 35 | E (`SAVE_SOME`, `handle_sys64`, `resume`) |
| PowerPC 64, Linux | about 60 | about 55 | not counted | about 55 | E (`system_call_common`, `_switch` 7 direct + register-save macros) |
| LoongArch, Linux | about 70 | about 45 | not counted | about 25 | C `handle_syscall` 30 + `SAVE_ALL` 36; switch C 8 + macros |
| m68k, Linux | about 26 | about 25 | about 25 / 25 | about 15 | C on `system_call`, `ret_from_exception` (22 and 25) |
| m68k, NetBSD | **6** | **8** | similar | about 25 (with FPU save) | C on `trap0`, `rei`, `cpu_switchto` |
| s390, Linux | about 35 | about 25 | not counted | 15 | C `system_call` 23 + 12 macro; `__switch_to_asm` 15 |
| Alpha, Linux | 34 | 32 | not counted | 13 | C on `entSys`, `ret_from_sys_call`, `alpha_switch_to` (PALcode saves part in hardware, not counted) |
| VAX, NetBSD | **about 11** | **about 8** | similar | **about 10** | C on the `syscall` entry in `intvec.S`, `Swtchto` in `subr.S` |
| **pdp64, System v1** | **4 to 5** | **4** | 5 / 4 (+1 `MFSR` for the cause) | **about 9** | paper estimate from section 15, errata 37 and 40; not a measurement |

What the table shows. (1) **Two clusters.** The machines that save registers one at a time (x86-64, AArch64, RISC-V, MIPS, PowerPC, LoongArch) spend 40 to 70 instructions on entry and 30 to 55 on exit; the machines with a multiple-register save (m68k `moveml`, VAX `pushr`, s390 `stmg`) spend 6 to 12. (2) **x86 pays twice**: its entry is long because the hardware pushes a frame *and* the software then saves 15 registers *and* clears them, and because of the page-table switch of the Meltdown mitigation (3 instructions each way here); the AArch64 entry has 15 `stp` plus about 30 instructions of bookkeeping (task pointer, debug state, pointer-authentication and tag-check state). (3) **The thread switch is short everywhere** (9 to 40 instructions) except where state is large. (4) **pdp64's path is short by construction:** the hardware vectors through the table with `EPC`/`EPSW` in registers, priority already 7 (errata 40), and the stack and per-CPU pointer already banked. A system-call entry is `PUSHX`, `PUSHM`, then `SPL #0` (the handler is ready to be interrupted) and the call: **about 4 to 5 instructions**; exit is `SPL #7`, `POPM`, `POPX`, `RTI`: **4 instructions**; a generic exception entry that must also read the cause adds one `MFSR`. A thread switch (`PUSHM` of the callee-saved set, store `SP`, load `SP`, `POPM`, `MTASID`, `MTSR ptbr`, `ISYNC`, return) is **about 9 to 10**. Compare 45/30 (Linux x86-64), 60/45 (Linux AArch64), 10/9 (NetBSD VAX), 6/8 (NetBSD m68k): pdp64 is in the VAX and m68k cluster, which is what the register-based entry with `pushx` and `pushm` was designed to achieve.

## 9. Part II (not yet written)

A second document is planned: `kernel-pain-points`, thirty years of kernel and operating-system mailing-list discussion of tight loops, critical paths and their workarounds, compared with pdp64. It needs web research and has not been started. This survey is its data foundation: the instruction classes of section 4 are the list of places where those discussions happen.

## 10. What this survey does not show

- **Static, not dynamic.** A count is how often an instruction is written, not how often it runs. A single `iret` in a hot path outweighs a hundred `cpuid` calls in boot code. The entry/exit counts of section 8 are the closest thing to dynamic, and they are approximate.
- **Which kernels are well represented.** Linux covers eleven architectures; NetBSD eleven (including VAX and PA-RISC); OpenBSD ten (including PA-RISC and m88k); FreeBSD five. A "kernel uses X" statement for an architecture means the kernels that have the port: AArch64, ARM, RISC-V, PowerPC, x86 and (except FreeBSD) MIPS and SPARC have three or four; LoongArch and s390 only Linux; VAX only NetBSD; m68k Linux and NetBSD; Alpha Linux, NetBSD, OpenBSD; PA-RISC and m88k only BSDs (m88k only OpenBSD).
- **Missing kernels and architectures.** OpenBSD no longer has a VAX port (the `sys/arch/vax` directory does not exist in the checkout), nor m68k, s390 or LoongArch; Linux has no VAX port; FreeBSD has no MIPS, SPARC, Alpha, VAX or PA-RISC tree in this checkout (removed upstream or never present); NetBSD has no s390 or LoongArch tree; Linux architectures not surveyed: ARC, C-SKY, Hexagon, MicroBlaze, Nios II, OpenRISC, PA-RISC, SuperH, Xtensa, UML. NetBSD ports not surveyed: the m68k ports other than hp300, sun3, mac68k and amiga, SuperH, ia64, and the many ARM and MIPS SoC trees beyond the architecture directories.
- **Assembly missing from the sparse checkouts.** Only the directories in `sources.txt`. Hand-written assembly elsewhere is not counted: crypto and checksum routines (excluded on purpose), the `vdso`, KVM and Xen subtrees beyond `arch/*/kvm` and `arch/x86/xen`, BSD `sys/crypto`, `sys/contrib`, DTrace and hypervisor trees (`bhyve`, `vmm`) in FreeBSD outside `sys/amd64`, boot loaders beyond `boot` directories, and `libkern` routines except under `sys/lib/libkern/arch`.
- **Extraction limits.** Instructions behind macros (RISC-V `fence`, AArch64 `ldtr` in Linux, atomics generated by macro families) are under-counted; instructions encoded as `.byte`/`.inst` are not counted; the second pass resolves only literal macro arguments. Section 2 gives the validation figures.
- **Compiler side.** The compiled corpus is ordinary user-space C (BearSSL and similar) compiled at `-Os`; kernel-style code would use more atomics and barriers (compilers emit `ldxr`, `lock` and `dmb` for C11 atomics, and the corpus contains a few); the "invisible" threshold of 0.001% is a choice. The RISC-V corpus directory has about 2,300 distinct "mnemonics", most of them one-off data-section fragments; they do not affect the invisible set. Alpha, PA-RISC and m88k have no compiled baseline.
- **Classification.** The class of an instruction is by table; a few instructions serve two purposes (SPARC alternate-space accesses are user copies, MMU access and physical access at once; x86 `lfence` is a memory fence and a speculation barrier; PowerPC `sync` orders memory and device accesses). The SPARC user-memory count is therefore an upper bound.
- **Path lengths.** Estimated by reading, not by running a kernel; mitigations and feature-patched alternatives are treated as absent unless noted; conditional paths are included in the counted ranges.
- **pdp64 side.** The mapping uses the documents as of errata 40; the Part II document and the dynamic null-system-call measurement may refine items 1, 2 and 3 of section 7.

## Appendix A: the compiler-invisible inventory, per architecture

Every mnemonic that a kernel writes and the compiled corpus (almost) never emits, with its class and its count in each kernel (L Linux, F FreeBSD, N NetBSD, O OpenBSD) and in the corpus ("compiler"). Mnemonics of class `other` are listed in one line per architecture when they occur at least three times. Families marked with an asterisk have no compiler baseline. The same data, with every row, is in `docs/codegen-data/kernelasm/classified.csv`.

### A.1 x86 (i386, amd64)

Compiled corpus: 1280687 instruction lines. 157 classified invisible mnemonics, 25 other (three or more uses).

| Mnemonic | Class | L | F | N | O | Compiler |
|---|---|---:|---:|---:|---:|---:|
| `ljmp` | exception entry/return and system call | 17 | 2 | 27 | 45 | 0 |
| `iret` | exception entry/return and system call | 14 | 8 | 12 | 28 | 0 |
| `lret` | exception entry/return and system call | 8 | 8 | 12 | 3 | 0 |
| `lcall` | exception entry/return and system call | 5 | 5 | 8 | 8 | 0 |
| `syscall` | exception entry/return and system call | 7 | 7 | 0 | 1 | 0 |
| `sysret` | exception entry/return and system call | 3 | 2 | 2 | 2 | 0 |
| `int` | exception entry/return and system call | 0 | 2 | 0 | 0 | 0 |
| `sysexit` | exception entry/return and system call | 1 | 0 | 0 | 0 | 0 |
| `ud1` | exception entry/return and system call | 1 | 0 | 0 | 0 | 0 |
| `wrmsr` | privileged register access | 27 | 56 | 30 | 48 | 0 |
| `rdmsr` | privileged register access | 22 | 47 | 19 | 41 | 0 |
| `lgdt` | privileged register access | 23 | 12 | 25 | 17 | 0 |
| `lidt` | privileged register access | 12 | 4 | 7 | 11 | 0 |
| `lldt` | privileged register access | 8 | 6 | 4 | 6 | 0 |
| `ltr` | privileged register access | 5 | 8 | 4 | 7 | 0 |
| `clts` | privileged register access | 1 | 15 | 1 | 1 | 0 |
| `str` | privileged register access | 2 | 5 | 5 | 6 | 0 |
| `sgdt` | privileged register access | 3 | 5 | 3 | 5 | 0 |
| `sidt` | privileged register access | 2 | 5 | 3 | 5 | 0 |
| `sldt` | privileged register access | 3 | 5 | 2 | 5 | 0 |
| `verw` | privileged register access | 1 | 2 | 1 | 3 | 0 |
| `xgetbv` | privileged register access | 1 | 2 | 1 | 2 | 0 |
| `xsetbv` | privileged register access | 1 | 2 | 1 | 2 | 0 |
| `wrpkru` | privileged register access | 1 | 2 | 0 | 2 | 0 |
| `rdpkru` | privileged register access | 1 | 2 | 0 | 1 | 0 |
| `lmsw` | privileged register access | 1 | 1 | 0 | 0 | 0 |
| `wrmsrns` | privileged register access | 0 | 2 | 0 | 0 | 0 |
| `lar` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `smsw` | privileged register access | 0 | 1 | 0 | 0 | 0 |
| `popf` | interrupt masking | 46 | 34 | 30 | 25 | 0 |
| `cli` | interrupt masking | 16 | 31 | 29 | 57 | 0 |
| `sti` | interrupt masking | 5 | 34 | 30 | 64 | 0 |
| `pushf` | interrupt masking | 43 | 34 | 24 | 26 | 0 |
| `invlpg` | TLB and MMU maintenance | 1 | 4 | 3 | 8 | 0 |
| `invpcid` | TLB and MMU maintenance | 1 | 1 | 3 | 9 | 0 |
| `invept` | TLB and MMU maintenance | 0 | 1 | 0 | 2 | 0 |
| `invvpid` | TLB and MMU maintenance | 0 | 1 | 0 | 1 | 0 |
| `invlpgb` | TLB and MMU maintenance | 0 | 1 | 0 | 0 | 0 |
| `tlbsync` | TLB and MMU maintenance | 0 | 1 | 0 | 0 | 0 |
| `wbinvd` | cache maintenance | 7 | 2 | 4 | 4 | 0 |
| `clflushopt` | cache maintenance | 0 | 8 | 0 | 3 | 0 |
| `clflush` | cache maintenance | 1 | 2 | 0 | 6 | 0 |
| `invd` | cache maintenance | 0 | 2 | 4 | 0 | 0 |
| `prefetcht0` | cache maintenance | 2 | 0 | 0 | 0 | 0 |
| `clwb` | cache maintenance | 0 | 1 | 0 | 0 | 0 |
| `lfence` | memory barrier and ordering | 7 | 31 | 6 | 108 | 0 |
| `mfence` | memory barrier and ordering | 4 | 17 | 2 | 12 | 0 |
| `sfence` | memory barrier and ordering | 5 | 10 | 1 | 6 | 0 |
| `lock cmpxchg` | atomics and exclusive access | 3 | 21 | 12 | 0 | 0 |
| `cmpxchg` | atomics and exclusive access | 8 | 0 | 14 | 6 | 0 |
| `btr` | atomics and exclusive access | 8 | 0 | 8 | 5 | 4 |
| `bts` | atomics and exclusive access | 16 | 0 | 5 | 0 | 1 |
| `lock add` | atomics and exclusive access | 7 | 6 | 5 | 0 | 0 |
| `lock cmpxchg8b` | atomics and exclusive access | 8 | 5 | 0 | 0 | 0 |
| `lock dec` | atomics and exclusive access | 2 | 0 | 0 | 11 | 0 |
| `xadd` | atomics and exclusive access | 2 | 0 | 0 | 8 | 0 |
| `cmpxchg8b` | atomics and exclusive access | 3 | 3 | 2 | 1 | 0 |
| `lock bts` | atomics and exclusive access | 3 | 5 | 0 | 0 | 0 |
| `lock xadd` | atomics and exclusive access | 0 | 7 | 0 | 0 | 0 |
| `lock or` | atomics and exclusive access | 5 | 0 | 0 | 1 | 0 |
| `lock and` | atomics and exclusive access | 5 | 0 | 0 | 0 | 0 |
| `lock btr` | atomics and exclusive access | 0 | 5 | 0 | 0 | 0 |
| `lock xor` | atomics and exclusive access | 4 | 0 | 0 | 0 | 0 |
| `cmpxchg16b` | atomics and exclusive access | 2 | 0 | 0 | 0 | 0 |
| `lock cmpxchg16b` | atomics and exclusive access | 0 | 2 | 0 | 0 | 0 |
| `lock inc` | atomics and exclusive access | 2 | 0 | 0 | 0 | 0 |
| `lock sub` | atomics and exclusive access | 2 | 0 | 0 | 0 | 0 |
| `btc` | atomics and exclusive access | 1 | 0 | 0 | 0 | 1 |
| `hlt` | spin-wait, idle and hints | 17 | 9 | 13 | 18 | 0 |
| `pause` | spin-wait, idle and hints | 5 | 10 | 5 | 10 | 0 |
| `mwait` | spin-wait, idle and hints | 2 | 3 | 2 | 2 | 0 |
| `monitor` | spin-wait, idle and hints | 1 | 2 | 2 | 2 | 0 |
| `monitorx` | spin-wait, idle and hints | 1 | 0 | 0 | 0 | 0 |
| `mwaitx` | spin-wait, idle and hints | 1 | 0 | 0 | 0 | 0 |
| `clac` | user-memory access | 22 | 28 | 2 | 1 | 0 |
| `stac` | user-memory access | 10 | 22 | 2 | 1 | 0 |
| `swapgs` | per-CPU and thread base | 19 | 19 | 14 | 13 | 0 |
| `rdfsbase` | per-CPU and thread base | 1 | 6 | 0 | 0 | 0 |
| `rdgsbase` | per-CPU and thread base | 1 | 3 | 0 | 0 | 0 |
| `wrgsbase` | per-CPU and thread base | 3 | 1 | 0 | 0 | 0 |
| `wrfsbase` | per-CPU and thread base | 1 | 2 | 0 | 0 | 0 |
| `pusha` | context and FPU/vector state | 2 | 5 | 30 | 7 | 0 |
| `popa` | context and FPU/vector state | 2 | 1 | 26 | 7 | 0 |
| `fxsave` | context and FPU/vector state | 3 | 3 | 2 | 5 | 0 |
| `fninit` | context and FPU/vector state | 7 | 2 | 1 | 2 | 0 |
| `fxrstor` | context and FPU/vector state | 0 | 2 | 2 | 8 | 0 |
| `fnstsw` | context and FPU/vector state | 3 | 3 | 1 | 1 | 0 |
| `xsave` | context and FPU/vector state | 0 | 5 | 2 | 1 | 0 |
| `fnclex` | context and FPU/vector state | 1 | 3 | 1 | 2 | 0 |
| `ldmxcsr` | context and FPU/vector state | 1 | 3 | 1 | 2 | 0 |
| `fwait` | context and FPU/vector state | 3 | 0 | 0 | 3 | 0 |
| `xrstor` | context and FPU/vector state | 0 | 3 | 2 | 0 | 0 |
| `xsaveopt` | context and FPU/vector state | 0 | 3 | 2 | 0 | 0 |
| `fnsave` | context and FPU/vector state | 1 | 1 | 1 | 1 | 0 |
| `stmxcsr` | context and FPU/vector state | 0 | 3 | 1 | 0 | 0 |
| `frstor` | context and FPU/vector state | 0 | 1 | 1 | 1 | 0 |
| `xrstors` | context and FPU/vector state | 0 | 1 | 0 | 1 | 0 |
| `emms` | context and FPU/vector state | 1 | 0 | 0 | 0 | 0 |
| `fldenv` | context and FPU/vector state | 0 | 1 | 0 | 0 | 0 |
| `fnstenv` | context and FPU/vector state | 0 | 1 | 0 | 0 | 0 |
| `xsaves` | context and FPU/vector state | 0 | 1 | 0 | 0 | 0 |
| `cld` | string and memory block | 33 | 36 | 47 | 47 | 0 |
| `lods` | string and memory block | 6 | 0 | 13 | 35 | 0 |
| `stos` | string and memory block | 5 | 0 | 10 | 33 | 0 |
| `movnti` | string and memory block | 34 | 2 | 0 | 5 | 0 |
| `std` | string and memory block | 5 | 2 | 9 | 4 | 0 |
| `repe cmps` | string and memory block | 2 | 0 | 0 | 12 | 0 |
| `movntdq` | string and memory block | 0 | 6 | 0 | 3 | 0 |
| `repne movs` | string and memory block | 0 | 0 | 0 | 8 | 0 |
| `rep vmmcall` | string and memory block | 4 | 0 | 0 | 3 | 0 |
| `repne scas` | string and memory block | 5 | 0 | 0 | 2 | 0 |
| `repe scas` | string and memory block | 0 | 1 | 2 | 3 | 0 |
| `movntiq` | string and memory block | 3 | 0 | 0 | 0 | 0 |
| `repne stos` | string and memory block | 0 | 0 | 0 | 3 | 0 |
| `repnz scas` | string and memory block | 1 | 0 | 0 | 2 | 0 |
| `rep xcryptcbc` | string and memory block | 0 | 0 | 0 | 2 | 0 |
| `rep xstorerng` | string and memory block | 0 | 0 | 0 | 2 | 0 |
| `scas` | string and memory block | 2 | 0 | 0 | 0 | 0 |
| `rep movsbcall` | string and memory block | 1 | 0 | 0 | 0 | 0 |
| `rep ret` | string and memory block | 0 | 0 | 1 | 0 | 0 |
| `rep stosbcall` | string and memory block | 1 | 0 | 0 | 0 | 0 |
| `rep stosqrep` | string and memory block | 1 | 0 | 0 | 0 | 0 |
| `repz cmps` | string and memory block | 0 | 0 | 1 | 0 | 0 |
| `popcnt` | bit manipulation | 0 | 4 | 0 | 0 | 0 |
| `tzcnt` | bit manipulation | 1 | 0 | 0 | 0 | 0 |
| `cpuid` | CPU identification and feature | 21 | 10 | 17 | 25 | 0 |
| `rdpid` | CPU identification and feature | 0 | 1 | 0 | 0 | 0 |
| `rdtsc` | timers and counters | 1 | 6 | 2 | 10 | 0 |
| `rdtscp` | timers and counters | 0 | 9 | 0 | 1 | 0 |
| `rdpmc` | timers and counters | 1 | 2 | 0 | 3 | 0 |
| `rdrand` | random numbers | 4 | 0 | 4 | 4 | 0 |
| `rdseed` | random numbers | 1 | 0 | 4 | 4 | 0 |
| `out` | I/O and device access | 4 | 16 | 49 | 34 | 0 |
| `in` | I/O and device access | 3 | 9 | 32 | 23 | 0 |
| `rep ins` | I/O and device access | 2 | 6 | 9 | 0 | 0 |
| `rep outs` | I/O and device access | 2 | 6 | 9 | 0 | 0 |
| `repne ins` | I/O and device access | 0 | 0 | 0 | 6 | 0 |
| `repne outs` | I/O and device access | 0 | 0 | 0 | 6 | 0 |
| `vmcall` | hypervisor, secure and firmware calls | 5 | 0 | 0 | 0 | 0 |
| `vmrun` | hypervisor, secure and firmware calls | 2 | 1 | 0 | 2 | 0 |
| `clgi` | hypervisor, secure and firmware calls | 0 | 1 | 0 | 3 | 0 |
| `vmload` | hypervisor, secure and firmware calls | 2 | 1 | 0 | 1 | 0 |
| `vmread` | hypervisor, secure and firmware calls | 1 | 1 | 0 | 2 | 0 |
| `vmwrite` | hypervisor, secure and firmware calls | 0 | 1 | 0 | 3 | 0 |
| `vmlaunch` | hypervisor, secure and firmware calls | 1 | 1 | 0 | 1 | 0 |
| `vmmcall` | hypervisor, secure and firmware calls | 3 | 0 | 0 | 0 | 0 |
| `vmresume` | hypervisor, secure and firmware calls | 1 | 1 | 0 | 1 | 0 |
| `vmsave` | hypervisor, secure and firmware calls | 1 | 1 | 0 | 1 | 0 |
| `stgi` | hypervisor, secure and firmware calls | 0 | 1 | 0 | 1 | 0 |
| `vmclear` | hypervisor, secure and firmware calls | 0 | 1 | 0 | 1 | 0 |
| `vmptrld` | hypervisor, secure and firmware calls | 0 | 1 | 0 | 1 | 0 |
| `vmptrst` | hypervisor, secure and firmware calls | 0 | 1 | 0 | 1 | 0 |
| `vmxoff` | hypervisor, secure and firmware calls | 0 | 1 | 0 | 1 | 0 |
| `vmxon` | hypervisor, secure and firmware calls | 0 | 1 | 0 | 1 | 0 |
| `int3` | debug and breakpoints | 50 | 0 | 2 | 4 | 0 |
| `endbr64` | speculation control | 32 | 0 | 0 | 15 | 0 |
| `wruss` | speculation control | 1 | 0 | 0 | 0 | 0 |

Other (not classified): `aesdec` 65, `aesenc` 65, `loop` 60, `nop` 46, `vmovdqa` 38, `aeskeygenassist` 31, `vorpd` 12, `clc` 11, `pslldq` 8, `pshufb` 6, `vmovdqa64` 6, `aesdeclast` 5, `aesenclast` 5, `fdiv` 5, `ffree` 5, `pclmulqdq` 4, `psrldq` 4, `b` 3, `daa` 3, `lahf` 3, `lss` 3, `pextrw` 3, `stc` 3, `vpxor` 3, `w` 3.

### A.2 AArch64

Compiled corpus: 616592 instruction lines. 69 classified invisible mnemonics, 36 other (three or more uses).

| Mnemonic | Class | L | F | N | O | Compiler |
|---|---|---:|---:|---:|---:|---:|
| `eret` | exception entry/return and system call | 19 | 2 | 1 | 5 | 0 |
| `svc` | exception entry/return and system call | 0 | 6 | 0 | 1 | 0 |
| `msr` | privileged register access | 116 | 100 | 92 | 93 | 0 |
| `mrs` | privileged register access | 86 | 48 | 61 | 67 | 0 |
| `sys` | privileged register access | 1 | 2 | 0 | 0 | 0 |
| `sysl` | privileged register access | 0 | 1 | 0 | 0 | 0 |
| `tlbi` | TLB and MMU maintenance | 13 | 27 | 19 | 17 | 0 |
| `stnp` | cache maintenance | 16 | 0 | 8 | 0 | 0 |
| `dc` | cache maintenance | 11 | 3 | 5 | 4 | 0 |
| `prfm` | cache maintenance | 17 | 5 | 0 | 0 | 0 |
| `ic` | cache maintenance | 7 | 5 | 4 | 3 | 0 |
| `ldnp` | cache maintenance | 0 | 0 | 4 | 0 | 0 |
| `isb` | memory barrier and ordering | 51 | 33 | 39 | 64 | 0 |
| `dsb` | memory barrier and ordering | 30 | 34 | 39 | 73 | 0 |
| `dmb` | memory barrier and ordering | 7 | 6 | 7 | 0 | 0 |
| `ldxr` | atomics and exclusive access | 12 | 11 | 3 | 2 | 0 |
| `stxr` | atomics and exclusive access | 9 | 7 | 3 | 2 | 0 |
| `stlxr` | atomics and exclusive access | 4 | 5 | 1 | 8 | 0 |
| `ldaxr` | atomics and exclusive access | 2 | 0 | 1 | 8 | 0 |
| `cas` | atomics and exclusive access | 3 | 4 | 0 | 0 | 0 |
| `ldar` | atomics and exclusive access | 2 | 2 | 1 | 0 | 0 |
| `stlr` | atomics and exclusive access | 2 | 2 | 0 | 0 | 0 |
| `stset` | atomics and exclusive access | 3 | 1 | 0 | 0 | 0 |
| `casal` | atomics and exclusive access | 1 | 0 | 0 | 2 | 0 |
| `swp` | atomics and exclusive access | 1 | 2 | 0 | 0 | 0 |
| `casp` | atomics and exclusive access | 2 | 0 | 0 | 0 | 0 |
| `clrex` | atomics and exclusive access | 0 | 1 | 1 | 0 | 0 |
| `ldaddal` | atomics and exclusive access | 0 | 0 | 0 | 2 | 0 |
| `ldxp` | atomics and exclusive access | 2 | 0 | 0 | 0 | 0 |
| `stadd` | atomics and exclusive access | 2 | 0 | 0 | 0 | 0 |
| `stclr` | atomics and exclusive access | 2 | 0 | 0 | 0 | 0 |
| `steor` | atomics and exclusive access | 2 | 0 | 0 | 0 | 0 |
| `stlrh` | atomics and exclusive access | 2 | 0 | 0 | 0 | 0 |
| `swpal` | atomics and exclusive access | 0 | 0 | 0 | 2 | 0 |
| `ldadd` | atomics and exclusive access | 0 | 1 | 0 | 0 | 0 |
| `ldadda` | atomics and exclusive access | 1 | 0 | 0 | 0 | 0 |
| `ldarb` | atomics and exclusive access | 1 | 0 | 0 | 0 | 0 |
| `ldarh` | atomics and exclusive access | 1 | 0 | 0 | 0 | 0 |
| `ldaxrh` | atomics and exclusive access | 1 | 0 | 0 | 0 | 0 |
| `ldclral` | atomics and exclusive access | 0 | 0 | 0 | 1 | 0 |
| `ldsetal` | atomics and exclusive access | 0 | 0 | 0 | 1 | 0 |
| `ldxrb` | atomics and exclusive access | 0 | 1 | 0 | 0 | 0 |
| `stlrb` | atomics and exclusive access | 1 | 0 | 0 | 0 | 0 |
| `stxp` | atomics and exclusive access | 1 | 0 | 0 | 0 | 0 |
| `stxrb` | atomics and exclusive access | 0 | 1 | 0 | 0 | 0 |
| `swpb` | atomics and exclusive access | 0 | 1 | 0 | 0 | 0 |
| `wfe` | spin-wait, idle and hints | 11 | 2 | 3 | 4 | 0 |
| `wfi` | spin-wait, idle and hints | 5 | 3 | 5 | 2 | 0 |
| `sev` | spin-wait, idle and hints | 1 | 4 | 0 | 8 | 0 |
| `hint` | spin-wait, idle and hints | 6 | 2 | 1 | 0 | 0 |
| `sevl` | spin-wait, idle and hints | 4 | 0 | 0 | 0 | 0 |
| `yield` | spin-wait, idle and hints | 1 | 1 | 1 | 1 | 0 |
| `ldtr` | user-memory access | 0 | 0 | 14 | 3 | 0 |
| `sttr` | user-memory access | 0 | 0 | 14 | 2 | 0 |
| `ldtrb` | user-memory access | 0 | 1 | 4 | 2 | 0 |
| `sttrb` | user-memory access | 0 | 0 | 4 | 2 | 0 |
| `ldtrh` | user-memory access | 0 | 0 | 3 | 0 | 0 |
| `sttrh` | user-memory access | 0 | 0 | 3 | 0 | 0 |
| `cpye` | string and memory block | 1 | 0 | 0 | 0 | 0 |
| `cpym` | string and memory block | 1 | 0 | 0 | 0 | 0 |
| `cpyp` | string and memory block | 1 | 0 | 0 | 0 | 0 |
| `sete` | string and memory block | 1 | 0 | 0 | 0 | 0 |
| `setm` | string and memory block | 1 | 0 | 0 | 0 | 0 |
| `setp` | string and memory block | 1 | 0 | 0 | 0 | 0 |
| `hvc` | hypervisor, secure and firmware calls | 7 | 1 | 0 | 2 | 0 |
| `smc` | hypervisor, secure and firmware calls | 3 | 0 | 0 | 2 | 0 |
| `udf` | debug and breakpoints | 0 | 0 | 1 | 1 | 0 |
| `hlt` | debug and breakpoints | 1 | 0 | 0 | 0 | 0 |
| `bti` | speculation control | 0 | 0 | 0 | 6 | 0 |

Other (not classified): `aese` 116, `aesmc` 97, `aesd` 94, `aesimc` 86, `w` 70, `st1` 47, `l` 43, `nop` 39, `a` 38, `ishst` 33, `h` 22, `nsh` 19, `ish` 16, `op` 16, `sy` 10, `x` 10, `movz` 9, `asm_op` 8, `llsc_asm_op` 8, `lse_asm_op` 8, `op_llsc` 8, `op_lse` 8, `type` 8, `al` 7, `nopdmb` 7, `stgm` 5, `acq_` 4, `mb_` 4, `rel_` 4, `andnot` 3, `at` 3, `ldgm` 3, `nopisb` 3, `nshst` 3, `rdffr` 3, `wrffr` 3.

### A.3 ARM 32-bit

Compiled corpus: 930218 instruction lines. 45 classified invisible mnemonics, 15 other (three or more uses).

| Mnemonic | Class | L | F | N | O | Compiler |
|---|---|---:|---:|---:|---:|---:|
| `swi` | exception entry/return and system call | 2 | 2 | 4 | 1 | 0 |
| `udf` | exception entry/return and system call | 0 | 2 | 1 | 1 | 0 |
| `eret` | exception entry/return and system call | 0 | 0 | 1 | 1 | 0 |
| `rfeia` | exception entry/return and system call | 2 | 0 | 0 | 0 | 0 |
| `svc` | exception entry/return and system call | 2 | 0 | 0 | 0 | 0 |
| `mcr` | privileged register access | 1210 | 64 | 492 | 64 | 0 |
| `mrc` | privileged register access | 308 | 44 | 73 | 56 | 0 |
| `msr` | privileged register access | 64 | 15 | 56 | 12 | 0 |
| `mrs` | privileged register access | 38 | 15 | 41 | 12 | 0 |
| `mcrr` | privileged register access | 14 | 1 | 13 | 0 | 0 |
| `mrrc` | privileged register access | 8 | 1 | 1 | 1 | 0 |
| `cpsid` | interrupt masking | 8 | 3 | 9 | 4 | 0 |
| `cpsie` | interrupt masking | 6 | 0 | 6 | 2 | 0 |
| `cps` | interrupt masking | 0 | 0 | 2 | 1 | 0 |
| `pld` | cache maintenance | 1 | 36 | 48 | 0 | 0 |
| `dccimvacne` | cache maintenance | 2 | 0 | 0 | 0 | 0 |
| `dcimvaclo` | cache maintenance | 1 | 0 | 0 | 0 | 0 |
| `pldw` | cache maintenance | 1 | 0 | 0 | 0 | 0 |
| `dsb` | memory barrier and ordering | 2 | 6 | 41 | 52 | 0 |
| `isb` | memory barrier and ordering | 3 | 5 | 26 | 29 | 0 |
| `dmb` | memory barrier and ordering | 4 | 1 | 12 | 0 | 0 |
| `strex` | atomics and exclusive access | 22 | 24 | 3 | 10 | 0 |
| `ldrex` | atomics and exclusive access | 19 | 24 | 2 | 10 | 0 |
| `ldrexd` | atomics and exclusive access | 11 | 11 | 0 | 0 | 0 |
| `strexd` | atomics and exclusive access | 10 | 10 | 0 | 0 | 0 |
| `clrex` | atomics and exclusive access | 0 | 4 | 6 | 2 | 0 |
| `ldrexb` | atomics and exclusive access | 2 | 0 | 1 | 0 | 0 |
| `strexb` | atomics and exclusive access | 2 | 0 | 1 | 0 | 0 |
| `ldrexh` | atomics and exclusive access | 2 | 0 | 0 | 0 | 0 |
| `strexh` | atomics and exclusive access | 2 | 0 | 0 | 0 | 0 |
| `swpb` | atomics and exclusive access | 1 | 0 | 1 | 0 | 0 |
| `swp` | atomics and exclusive access | 1 | 0 | 0 | 0 | 0 |
| `wfe` | spin-wait, idle and hints | 1 | 2 | 3 | 3 | 0 |
| `wfi` | spin-wait, idle and hints | 4 | 1 | 3 | 1 | 0 |
| `sev` | spin-wait, idle and hints | 1 | 1 | 1 | 3 | 0 |
| `ldrt` | user-memory access | 2 | 65 | 92 | 25 | 0 |
| `strt` | user-memory access | 0 | 64 | 89 | 25 | 0 |
| `ldrbt` | user-memory access | 4 | 13 | 20 | 8 | 0 |
| `strbt` | user-memory access | 0 | 12 | 21 | 8 | 0 |
| `ldrht` | user-memory access | 0 | 0 | 3 | 0 | 0 |
| `strht` | user-memory access | 0 | 1 | 1 | 0 | 0 |
| `vmsr` | context and FPU/vector state | 1 | 1 | 1 | 2 | 0 |
| `vmrs` | context and FPU/vector state | 1 | 1 | 0 | 2 | 0 |
| `smc` | hypervisor, secure and firmware calls | 1 | 1 | 2 | 2 | 0 |
| `hvc` | hypervisor, secure and firmware calls | 1 | 0 | 2 | 1 | 0 |

Other (not classified): `teq` 307, `it` 27, `reteq` 23, `vadd.u32` 22, `vmovl.u16` 21, `vmov` 14, `vld1.64` 13, `retne` 12, `vstmia` 11, `retls` 8, `veor` 7, `vldmia` 7, `vmov.f64` 7, `rb` 4, `negs` 3.

### A.4 RISC-V

Compiled corpus: 1297230 instruction lines. 55 classified invisible mnemonics, 23 other (three or more uses).

| Mnemonic | Class | L | F | N | O | Compiler |
|---|---|---:|---:|---:|---:|---:|
| `ecall` | exception entry/return and system call | 5 | 3 | 4 | 2 | 0 |
| `sret` | exception entry/return and system call | 4 | 5 | 2 | 3 | 0 |
| `mret` | exception entry/return and system call | 1 | 0 | 0 | 0 | 0 |
| `csrw` | privileged register access | 51 | 21 | 19 | 18 | 0 |
| `csrr` | privileged register access | 38 | 20 | 15 | 11 | 1 |
| `csrrw` | privileged register access | 11 | 14 | 5 | 5 | 0 |
| `csrs` | privileged register access | 16 | 6 | 4 | 4 | 0 |
| `csrc` | privileged register access | 11 | 5 | 5 | 7 | 0 |
| `csrsi` | privileged register access | 0 | 2 | 6 | 3 | 0 |
| `csrci` | privileged register access | 0 | 2 | 2 | 2 | 0 |
| `csrrci` | privileged register access | 0 | 1 | 3 | 1 | 0 |
| `csrrc` | privileged register access | 2 | 0 | 0 | 0 | 0 |
| `csrrwi` | privileged register access | 0 | 1 | 0 | 1 | 0 |
| `csrwi` | privileged register access | 0 | 1 | 0 | 1 | 0 |
| `csrrs` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `sfence.vma` | TLB and MMU maintenance | 9 | 6 | 6 | 9 | 0 |
| `sinval.vma` | TLB and MMU maintenance | 0 | 2 | 0 | 0 | 0 |
| `hfence.gvma` | TLB and MMU maintenance | 0 | 1 | 0 | 0 | 0 |
| `sfence.inval.ir` | TLB and MMU maintenance | 0 | 1 | 0 | 0 | 0 |
| `sfence.w.inval` | TLB and MMU maintenance | 0 | 1 | 0 | 0 | 0 |
| `cbo.clean` | cache maintenance | 0 | 1 | 0 | 1 | 0 |
| `cbo.flush` | cache maintenance | 0 | 1 | 0 | 1 | 0 |
| `cbo.inval` | cache maintenance | 0 | 1 | 0 | 1 | 0 |
| `fence` | memory barrier and ordering | 1 | 2 | 24 | 37 | 0 |
| `fence.i` | memory barrier and ordering | 4 | 1 | 4 | 2 | 0 |
| `lr.w` | atomics and exclusive access | 6 | 3 | 1 | 0 | 0 |
| `sc.w` | atomics and exclusive access | 3 | 3 | 1 | 0 | 0 |
| `amoadd.w` | atomics and exclusive access | 1 | 4 | 0 | 0 | 0 |
| `lr.d` | atomics and exclusive access | 1 | 3 | 1 | 0 | 0 |
| `sc.d` | atomics and exclusive access | 0 | 3 | 1 | 0 | 0 |
| `amoadd.d` | atomics and exclusive access | 0 | 3 | 0 | 0 | 0 |
| `amoand.w` | atomics and exclusive access | 0 | 2 | 0 | 1 | 0 |
| `amoor.d` | atomics and exclusive access | 0 | 3 | 0 | 0 | 0 |
| `amoor.w` | atomics and exclusive access | 0 | 2 | 0 | 1 | 0 |
| `amoand.d` | atomics and exclusive access | 0 | 2 | 0 | 0 | 0 |
| `amoswap.d` | atomics and exclusive access | 0 | 2 | 0 | 0 | 0 |
| `amoswap.w` | atomics and exclusive access | 0 | 2 | 0 | 0 | 0 |
| `amocas.q` | atomics and exclusive access | 1 | 0 | 0 | 0 | 0 |
| `amoxor.d` | atomics and exclusive access | 1 | 0 | 0 | 0 | 0 |
| `wfi` | spin-wait, idle and hints | 2 | 5 | 6 | 1 | 0 |
| `fscsr` | context and FPU/vector state | 3 | 3 | 1 | 1 | 0 |
| `frcsr` | context and FPU/vector state | 3 | 2 | 1 | 1 | 0 |
| `vsetvli` | context and FPU/vector state | 5 | 2 | 0 | 0 | 1 |
| `vl8r.v` | context and FPU/vector state | 0 | 0 | 0 | 4 | 0 |
| `vs8r.v` | context and FPU/vector state | 0 | 0 | 0 | 4 | 0 |
| `vsetvl` | context and FPU/vector state | 2 | 1 | 0 | 1 | 0 |
| `frflags` | context and FPU/vector state | 0 | 0 | 1 | 0 | 0 |
| `fsflags` | context and FPU/vector state | 0 | 0 | 1 | 0 | 0 |
| `fsrm` | context and FPU/vector state | 0 | 0 | 1 | 0 | 0 |
| `orc.b` | bit manipulation | 7 | 0 | 0 | 0 | 0 |
| `clz` | bit manipulation | 1 | 0 | 0 | 0 | 0 |
| `cpop` | bit manipulation | 1 | 0 | 0 | 0 | 0 |
| `ctz` | bit manipulation | 1 | 0 | 0 | 0 | 0 |
| `hlvx.hu` | hypervisor, secure and firmware calls | 0 | 2 | 0 | 0 | 0 |
| `unimp` | debug and breakpoints | 0 | 0 | 1 | 2 | 0 |

Other (not classified): `la` 99, `fmv.s.x` 32, `lla` 31, `jal` 14, `move` 13, `asm_op` 9, `w` 6, `regname` 5, `sstatus` 5, `time` 5, `auipc` 4, `hvip` 4, `lr.` 4, `nop` 4, `sc.` 4, `amo` 3, `cycle` 3, `d` 3, `see` 3, `sie` 3, `sra` 3, `th.sync.s` 3, `vsatp` 3.

### A.5 MIPS

Compiled corpus: 393696 instruction lines. 63 classified invisible mnemonics, 32 other (three or more uses).

| Mnemonic | Class | L | F | N | O | Compiler |
|---|---|---:|---:|---:|---:|---:|
| `eret` | exception entry/return and system call | 7 | 0 | 10 | 0 | 0 |
| `rfe` | exception entry/return and system call | 2 | 0 | 5 | 0 | 0 |
| `syscall` | exception entry/return and system call | 0 | 0 | 4 | 1 | 0 |
| `deret` | exception entry/return and system call | 1 | 0 | 0 | 0 | 0 |
| `mtc0` | privileged register access | 70 | 0 | 221 | 21 | 0 |
| `mfc0` | privileged register access | 97 | 0 | 188 | 25 | 0 |
| `dmtc2` | privileged register access | 73 | 0 | 0 | 0 | 0 |
| `dmtc0` | privileged register access | 7 | 0 | 5 | 56 | 0 |
| `dmfc2` | privileged register access | 63 | 0 | 0 | 0 | 0 |
| `dmfc0` | privileged register access | 10 | 0 | 18 | 19 | 0 |
| `dvpe` | privileged register access | 3 | 0 | 0 | 0 | 0 |
| `mfcr` | privileged register access | 0 | 0 | 3 | 0 | 0 |
| `dmt` | privileged register access | 2 | 0 | 0 | 0 | 0 |
| `evpe` | privileged register access | 2 | 0 | 0 | 0 | 0 |
| `cfc0` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `cfcmsa` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `ctc0` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `ctcmsa` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `dmfgc0` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `dmtgc0` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `emt` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `mfgc0` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `mfhc0` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `mfpc` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `mfps` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `mtcr` | privileged register access | 0 | 0 | 1 | 0 | 0 |
| `mtgc0` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `mthc0` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `mtm0` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `di` | interrupt masking | 3 | 0 | 6 | 0 | 0 |
| `ei` | interrupt masking | 1 | 0 | 1 | 0 | 0 |
| `tlbwi` | TLB and MMU maintenance | 1 | 0 | 20 | 10 | 0 |
| `tlbp` | TLB and MMU maintenance | 2 | 0 | 10 | 5 | 0 |
| `tlbr` | TLB and MMU maintenance | 2 | 0 | 9 | 3 | 0 |
| `tlbwr` | TLB and MMU maintenance | 1 | 0 | 5 | 4 | 0 |
| `ginvt` | TLB and MMU maintenance | 1 | 0 | 0 | 0 | 0 |
| `cache` | cache maintenance | 34 | 0 | 240 | 2 | 0 |
| `pref` | cache maintenance | 5 | 0 | 0 | 0 | 0 |
| `synci` | cache maintenance | 4 | 0 | 1 | 0 | 0 |
| `cachee` | cache maintenance | 1 | 0 | 0 | 0 | 0 |
| `sync` | memory barrier and ordering | 17 | 0 | 22 | 1 | 0 |
| `ehb` | memory barrier and ordering | 15 | 0 | 6 | 0 | 0 |
| `sync.l` | memory barrier and ordering | 0 | 0 | 16 | 0 | 0 |
| `sync.p` | memory barrier and ordering | 0 | 0 | 16 | 0 | 0 |
| `jr.hb` | memory barrier and ordering | 7 | 0 | 6 | 1 | 0 |
| `ssnop` | memory barrier and ordering | 0 | 0 | 8 | 0 | 0 |
| `syncw` | memory barrier and ordering | 5 | 0 | 1 | 0 | 0 |
| `synciobdma` | memory barrier and ordering | 2 | 0 | 0 | 0 | 0 |
| `ll` | atomics and exclusive access | 17 | 0 | 2 | 6 | 0 |
| `sc` | atomics and exclusive access | 17 | 0 | 2 | 6 | 0 |
| `lld` | atomics and exclusive access | 3 | 0 | 1 | 5 | 0 |
| `scd` | atomics and exclusive access | 3 | 0 | 1 | 5 | 0 |
| `wait` | spin-wait, idle and hints | 7 | 0 | 4 | 1 | 0 |
| `ctc1` | context and FPU/vector state | 4 | 0 | 18 | 3 | 0 |
| `cfc1` | context and FPU/vector state | 4 | 0 | 7 | 11 | 0 |
| `dins` | bit manipulation | 18 | 0 | 3 | 0 | 1 |
| `dclz` | bit manipulation | 2 | 0 | 6 | 0 | 0 |
| `clo` | bit manipulation | 1 | 0 | 0 | 0 | 0 |
| `dclo` | bit manipulation | 1 | 0 | 0 | 0 | 0 |
| `rdhwr` | timers and counters | 5 | 0 | 2 | 1 | 0 |
| `tne` | debug and breakpoints | 1 | 0 | 1 | 0 | 0 |
| `tge` | debug and breakpoints | 0 | 0 | 1 | 0 | 0 |
| `tlt` | debug and breakpoints | 0 | 0 | 1 | 0 | 0 |

Other (not classified): `li` 479, `b` 412, `blt` 44, `add` 23, `bal` 22, `v3mulu` 18, `la` 16, `mttc0` 15, `dextu` 14, `dsll32` 10, `teqi` 10, `bge` 8, `bgt` 8, `bltu` 8, `bbit1` 7, `dsrl32` 7, `sub` 7, `ble` 6, `reg` 6, `asm_op` 5, `op` 5, `pfx` 5, `addi` 4, `dla` 4, `mftc0` 4, `beqzl` 3, `bitswap` 3, `dli` 3, `dsra32` 3, `dsrav` 3, `mttgpr` 3, `sel` 3.

### A.6 PowerPC

Compiled corpus: 1434267 instruction lines. 129 classified invisible mnemonics, 54 other (three or more uses).

| Mnemonic | Class | L | F | N | O | Compiler |
|---|---|---:|---:|---:|---:|---:|
| `rfi` | exception entry/return and system call | 61 | 14 | 14 | 0 | 0 |
| `rfid` | exception entry/return and system call | 5 | 12 | 0 | 3 | 0 |
| `sc` | exception entry/return and system call | 4 | 4 | 2 | 1 | 0 |
| `rfci` | exception entry/return and system call | 3 | 3 | 1 | 0 | 0 |
| `rfmci` | exception entry/return and system call | 1 | 1 | 1 | 0 | 0 |
| `hrfid` | exception entry/return and system call | 2 | 0 | 0 | 0 | 0 |
| `rfdi` | exception entry/return and system call | 1 | 1 | 0 | 0 | 0 |
| `mtspr` | privileged register access | 893 | 74 | 66 | 21 | 0 |
| `mfspr` | privileged register access | 652 | 69 | 51 | 20 | 0 |
| `mfmsr` | privileged register access | 127 | 23 | 78 | 9 | 0 |
| `mtmsr` | privileged register access | 53 | 17 | 114 | 11 | 0 |
| `mtcr` | privileged register access | 70 | 33 | 23 | 11 | 0 |
| `mtmsrd` | privileged register access | 66 | 11 | 2 | 1 | 0 |
| `mfsrr1` | privileged register access | 2 | 18 | 18 | 3 | 0 |
| `mtsprg1` | privileged register access | 0 | 20 | 16 | 4 | 0 |
| `mtsrr1` | privileged register access | 17 | 13 | 6 | 1 | 0 |
| `mtibatu` | privileged register access | 4 | 5 | 26 | 0 | 0 |
| `mtsrr0` | privileged register access | 17 | 13 | 3 | 2 | 0 |
| `mfsprg1` | privileged register access | 0 | 17 | 14 | 3 | 0 |
| `mtdbatu` | privileged register access | 4 | 10 | 20 | 0 | 0 |
| `mtsprg2` | privileged register access | 0 | 16 | 10 | 7 | 0 |
| `mfdbatu` | privileged register access | 4 | 0 | 24 | 0 | 0 |
| `mtibatl` | privileged register access | 4 | 2 | 20 | 0 | 0 |
| `mfibatu` | privileged register access | 4 | 0 | 21 | 0 | 0 |
| `mfibatl` | privileged register access | 4 | 0 | 20 | 0 | 0 |
| `mtsprg3` | privileged register access | 0 | 16 | 5 | 3 | 0 |
| `mfdar` | privileged register access | 5 | 8 | 4 | 4 | 0 |
| `mfdbatl` | privileged register access | 4 | 0 | 16 | 0 | 0 |
| `mfsprg2` | privileged register access | 0 | 10 | 7 | 3 | 0 |
| `mtdbatl` | privileged register access | 4 | 6 | 10 | 0 | 0 |
| `mfsrin` | privileged register access | 5 | 1 | 8 | 0 | 0 |
| `mtsrin` | privileged register access | 6 | 1 | 6 | 1 | 0 |
| `mfdsisr` | privileged register access | 4 | 5 | 2 | 2 | 0 |
| `mfsprg` | privileged register access | 8 | 4 | 0 | 1 | 0 |
| `mfsprg0` | privileged register access | 0 | 4 | 2 | 7 | 0 |
| `mfsprg3` | privileged register access | 0 | 5 | 4 | 2 | 0 |
| `mtsr` | privileged register access | 1 | 3 | 5 | 2 | 0 |
| `mfpvr` | privileged register access | 4 | 3 | 3 | 0 | 0 |
| `mtsdr1` | privileged register access | 1 | 2 | 5 | 2 | 0 |
| `mfsdr1` | privileged register access | 2 | 0 | 6 | 0 | 0 |
| `mfsrr0` | privileged register access | 3 | 5 | 0 | 0 | 0 |
| `mtdcr` | privileged register access | 5 | 0 | 3 | 0 | 0 |
| `mtdec` | privileged register access | 3 | 1 | 3 | 1 | 0 |
| `mtsprg` | privileged register access | 6 | 2 | 0 | 0 | 0 |
| `mtsprg0` | privileged register access | 0 | 3 | 3 | 2 | 0 |
| `mfdcr` | privileged register access | 5 | 0 | 1 | 0 | 0 |
| `mfsr` | privileged register access | 1 | 0 | 3 | 2 | 0 |
| `mtdar` | privileged register access | 3 | 0 | 2 | 0 | 0 |
| `mfdec` | privileged register access | 0 | 2 | 1 | 0 | 0 |
| `mtdsisr` | privileged register access | 1 | 0 | 2 | 0 | 0 |
| `mfpmr` | privileged register access | 1 | 1 | 0 | 0 | 0 |
| `mtpmr` | privileged register access | 1 | 1 | 0 | 0 | 0 |
| `mtpid` | privileged register access | 0 | 0 | 1 | 0 | 0 |
| `wrteei` | interrupt masking | 18 | 6 | 24 | 0 | 0 |
| `wrtee` | interrupt masking | 13 | 5 | 8 | 0 | 0 |
| `tlbwe` | TLB and MMU maintenance | 73 | 10 | 26 | 0 | 0 |
| `ptesync` | TLB and MMU maintenance | 84 | 19 | 1 | 1 | 0 |
| `tlbsync` | TLB and MMU maintenance | 30 | 9 | 8 | 2 | 0 |
| `tlbre` | TLB and MMU maintenance | 16 | 7 | 13 | 0 | 0 |
| `slbmte` | TLB and MMU maintenance | 18 | 11 | 0 | 3 | 0 |
| `tlbie` | TLB and MMU maintenance | 17 | 5 | 4 | 2 | 0 |
| `tlbsx` | TLB and MMU maintenance | 18 | 1 | 5 | 0 | 0 |
| `slbia` | TLB and MMU maintenance | 12 | 5 | 2 | 3 | 0 |
| `slbie` | TLB and MMU maintenance | 4 | 8 | 0 | 3 | 0 |
| `slbmfee` | TLB and MMU maintenance | 3 | 6 | 0 | 3 | 0 |
| `tlbia` | TLB and MMU maintenance | 10 | 0 | 1 | 0 | 0 |
| `tlbivax` | TLB and MMU maintenance | 4 | 3 | 2 | 0 | 0 |
| `tlbld` | TLB and MMU maintenance | 4 | 2 | 2 | 0 | 0 |
| `tlbiel` | TLB and MMU maintenance | 3 | 1 | 0 | 1 | 0 |
| `slbmfev` | TLB and MMU maintenance | 3 | 1 | 0 | 0 | 0 |
| `tlbli` | TLB and MMU maintenance | 1 | 1 | 1 | 0 | 0 |
| `dcbf` | cache maintenance | 19 | 8 | 13 | 2 | 0 |
| `dcbst` | cache maintenance | 10 | 3 | 13 | 2 | 0 |
| `dcbt` | cache maintenance | 15 | 1 | 7 | 0 | 0 |
| `icbi` | cache maintenance | 11 | 2 | 7 | 3 | 0 |
| `dcbz` | cache maintenance | 9 | 2 | 4 | 2 | 0 |
| `dcba` | cache maintenance | 0 | 0 | 7 | 0 | 0 |
| `dcbi` | cache maintenance | 1 | 0 | 5 | 1 | 0 |
| `dcbtst` | cache maintenance | 1 | 1 | 0 | 0 | 0 |
| `dcbzl` | cache maintenance | 0 | 0 | 0 | 1 | 0 |
| `isync` | memory barrier and ordering | 280 | 136 | 217 | 29 | 0 |
| `sync` | memory barrier and ordering | 260 | 38 | 165 | 20 | 0 |
| `eieio` | memory barrier and ordering | 24 | 7 | 5 | 16 | 0 |
| `msync` | memory barrier and ordering | 13 | 30 | 7 | 0 | 0 |
| `lwsync` | memory barrier and ordering | 10 | 4 | 0 | 0 | 0 |
| `mbar` | memory barrier and ordering | 3 | 2 | 5 | 0 | 0 |
| `hwsync` | memory barrier and ordering | 6 | 0 | 0 | 0 | 0 |
| `stwcx` | atomics and exclusive access | 36 | 26 | 5 | 21 | 0 |
| `lwarx` | atomics and exclusive access | 37 | 18 | 1 | 21 | 0 |
| `stdcx` | atomics and exclusive access | 15 | 16 | 0 | 8 | 0 |
| `ldarx` | atomics and exclusive access | 13 | 11 | 0 | 7 | 0 |
| `stbcx` | atomics and exclusive access | 8 | 6 | 0 | 0 | 0 |
| `lbarx` | atomics and exclusive access | 8 | 4 | 0 | 0 | 0 |
| `sthcx` | atomics and exclusive access | 6 | 6 | 0 | 0 | 0 |
| `lharx` | atomics and exclusive access | 6 | 4 | 0 | 0 | 0 |
| `stop` | spin-wait, idle and hints | 0 | 0 | 0 | 2 | 0 |
| `nap` | spin-wait, idle and hints | 0 | 1 | 0 | 0 | 0 |
| `wait` | spin-wait, idle and hints | 1 | 0 | 0 | 0 | 0 |
| `evmergehi` | context and FPU/vector state | 0 | 0 | 17 | 0 | 0 |
| `evmergelo` | context and FPU/vector state | 0 | 0 | 17 | 0 | 0 |
| `evstdw` | context and FPU/vector state | 0 | 0 | 16 | 0 | 0 |
| `evldw` | context and FPU/vector state | 0 | 0 | 15 | 0 | 0 |
| `mffs` | context and FPU/vector state | 5 | 2 | 4 | 3 | 0 |
| `evmergehilo` | context and FPU/vector state | 0 | 0 | 11 | 0 | 0 |
| `mtfsf` | context and FPU/vector state | 0 | 2 | 2 | 4 | 0 |
| `mfvscr` | context and FPU/vector state | 3 | 1 | 1 | 2 | 0 |
| `mtvscr` | context and FPU/vector state | 3 | 1 | 1 | 2 | 0 |
| `mtfsb0` | context and FPU/vector state | 0 | 0 | 6 | 0 | 0 |
| `stvxl` | context and FPU/vector state | 0 | 0 | 3 | 1 | 0 |
| `evmra` | context and FPU/vector state | 2 | 0 | 1 | 0 | 0 |
| `evxor` | context and FPU/vector state | 2 | 0 | 1 | 0 | 0 |
| `evldd` | context and FPU/vector state | 0 | 0 | 2 | 0 | 0 |
| `evlddx` | context and FPU/vector state | 2 | 0 | 0 | 0 | 0 |
| `evstddx` | context and FPU/vector state | 2 | 0 | 0 | 0 | 0 |
| `lvxl` | context and FPU/vector state | 0 | 0 | 1 | 1 | 0 |
| `evstdd` | context and FPU/vector state | 0 | 0 | 1 | 0 | 0 |
| `lswx` | string and memory block | 0 | 0 | 4 | 0 | 0 |
| `stswx` | string and memory block | 0 | 0 | 4 | 0 | 0 |
| `lswi` | string and memory block | 0 | 0 | 1 | 0 | 0 |
| `stswi` | string and memory block | 0 | 0 | 1 | 0 | 0 |
| `popcntd` | bit manipulation | 1 | 0 | 0 | 0 | 0 |
| `mftb` | timers and counters | 13 | 6 | 8 | 5 | 0 |
| `mftbu` | timers and counters | 2 | 1 | 5 | 3 | 0 |
| `mttbl` | timers and counters | 4 | 0 | 3 | 2 | 0 |
| `mttbu` | timers and counters | 2 | 0 | 2 | 1 | 0 |
| `mftbl` | timers and counters | 2 | 0 | 1 | 0 | 0 |
| `darn` | random numbers | 0 | 0 | 0 | 1 | 0 |
| `twi` | debug and breakpoints | 13 | 0 | 0 | 0 | 0 |
| `tdi` | debug and breakpoints | 1 | 0 | 0 | 0 | 0 |

Other (not classified): `bf` 161, `streg` 128, `ldreg` 74, `rotlw` 74, `subi` 58, `mfctr` 50, `clrrdi` 46, `bcl` 43, `blrl` 34, `mtxer` 26, `ba` 25, `mfxer` 21, `ldptr` 18, `bt` 14, `clrrwi` 13, `lfsu` 13, `bdnzf` 12, `bla` 12, `stptr` 11, `asm_op` 10, `fmuls` 10, `op` 10, `fsel` 9, `cmpli` 8, `bdnzt` 7, `extrwi` 7, `fsubs` 7, `lptrarx` 6, `stfsx` 6, `stptrcx` 6, `bnl` 5, `cmpptr` 5, `dssall` 5, `stptru` 5, `tdne` 5, `beqa` 4, `beql` 4, `fnmsubs` 4, `insrdi` 4, `stint` 4, `tdnei` 4, `twnei` 4, `bdneq` 3, `clrrptri` 3, `cmp` 3, `cmpi` 3, `ldbrx` 3, `ldint` 3, `ldregu` 3, `lvewx` 3, `miso` 3, `rotrdi` 3, `stvewx` 3, `tweqi` 3.

### A.7 LoongArch

Compiled corpus: 639932 instruction lines. 41 classified invisible mnemonics, 8 other (three or more uses).

| Mnemonic | Class | L | F | N | O | Compiler |
|---|---|---:|---:|---:|---:|---:|
| `ertn` | exception entry/return and system call | 9 | 0 | 0 | 0 | 0 |
| `csrrd` | privileged register access | 66 | 0 | 0 | 0 | 0 |
| `csrwr` | privileged register access | 50 | 0 | 0 | 0 | 0 |
| `csrxchg` | privileged register access | 18 | 0 | 0 | 0 | 0 |
| `iocsrrd.d` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `iocsrrd.w` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `invtlb` | TLB and MMU maintenance | 7 | 0 | 0 | 0 | 0 |
| `tlbfill` | TLB and MMU maintenance | 6 | 0 | 0 | 0 | 0 |
| `tlbsrch` | TLB and MMU maintenance | 4 | 0 | 0 | 0 | 0 |
| `tlbwr` | TLB and MMU maintenance | 4 | 0 | 0 | 0 | 0 |
| `lddir` | TLB and MMU maintenance | 3 | 0 | 0 | 0 | 0 |
| `ldpte` | TLB and MMU maintenance | 2 | 0 | 0 | 0 | 0 |
| `tlbclr` | TLB and MMU maintenance | 1 | 0 | 0 | 0 | 0 |
| `tlbflush` | TLB and MMU maintenance | 1 | 0 | 0 | 0 | 0 |
| `tlbrd` | TLB and MMU maintenance | 1 | 0 | 0 | 0 | 0 |
| `cacop` | cache maintenance | 1 | 0 | 0 | 0 | 0 |
| `dbar` | memory barrier and ordering | 6 | 0 | 0 | 0 | 0 |
| `ibar` | memory barrier and ordering | 5 | 0 | 0 | 0 | 0 |
| `ll.w` | atomics and exclusive access | 11 | 0 | 0 | 0 | 0 |
| `sc.w` | atomics and exclusive access | 11 | 0 | 0 | 0 | 0 |
| `ll.d` | atomics and exclusive access | 4 | 0 | 0 | 0 | 0 |
| `sc.d` | atomics and exclusive access | 3 | 0 | 0 | 0 | 0 |
| `amswap_db.d` | atomics and exclusive access | 1 | 0 | 0 | 0 | 0 |
| `amswap_db.w` | atomics and exclusive access | 1 | 0 | 0 | 0 | 0 |
| `sc.q` | atomics and exclusive access | 1 | 0 | 0 | 0 | 0 |
| `idle` | spin-wait, idle and hints | 5 | 0 | 0 | 0 | 0 |
| `movgr2frh.w` | context and FPU/vector state | 33 | 0 | 0 | 0 | 0 |
| `movgr2cf` | context and FPU/vector state | 16 | 0 | 0 | 0 | 4 |
| `movgr2scr` | context and FPU/vector state | 12 | 0 | 0 | 0 | 0 |
| `movscr2gr` | context and FPU/vector state | 8 | 0 | 0 | 0 | 0 |
| `movfcsr2gr` | context and FPU/vector state | 3 | 0 | 0 | 0 | 0 |
| `movgr2fcsr` | context and FPU/vector state | 3 | 0 | 0 | 0 | 0 |
| `bitrev.4b` | bit manipulation | 2 | 0 | 0 | 0 | 0 |
| `bitrev.w` | bit manipulation | 1 | 0 | 0 | 0 | 3 |
| `rdtime.d` | timers and counters | 1 | 0 | 0 | 0 | 0 |
| `rdtimeh.w` | timers and counters | 1 | 0 | 0 | 0 | 0 |
| `rdtimel.w` | timers and counters | 1 | 0 | 0 | 0 | 0 |
| `hvcl` | hypervisor, secure and firmware calls | 6 | 0 | 0 | 0 | 0 |
| `gcsrrd` | hypervisor, secure and firmware calls | 1 | 0 | 0 | 0 | 0 |
| `gcsrwr` | hypervisor, secure and firmware calls | 1 | 0 | 0 | 0 | 0 |
| `gcsrxchg` | hypervisor, secure and firmware calls | 1 | 0 | 0 | 0 | 0 |

Other (not classified): `li.w` 28, `asm_op` 21, `la.pcrel` 17, `op` 13, `am` 8, `x86mttop` 8, `pcaddi` 6, `x86mtflag` 3.

### A.8 m68k

Compiled corpus: 752766 instruction lines. 28 classified invisible mnemonics, 34 other (three or more uses).

| Mnemonic | Class | L | F | N | O | Compiler |
|---|---|---:|---:|---:|---:|---:|
| `rte` | exception entry/return and system call | 1 | 0 | 16 | 0 | 0 |
| `movec` | privileged register access | 93 | 0 | 5 | 0 | 0 |
| `pmove` | privileged register access | 14 | 0 | 26 | 0 | 0 |
| `stop` | privileged register access | 2 | 0 | 1 | 0 | 0 |
| `reset` | privileged register access | 0 | 0 | 2 | 0 | 0 |
| `ptestr` | TLB and MMU maintenance | 9 | 0 | 9 | 0 | 0 |
| `pflusha` | TLB and MMU maintenance | 6 | 0 | 8 | 0 | 0 |
| `pflush` | TLB and MMU maintenance | 6 | 0 | 3 | 0 | 0 |
| `pflushs` | TLB and MMU maintenance | 0 | 0 | 3 | 0 | 0 |
| `pflushan` | TLB and MMU maintenance | 2 | 0 | 0 | 0 | 0 |
| `ploadr` | TLB and MMU maintenance | 2 | 0 | 0 | 0 | 0 |
| `ploadw` | TLB and MMU maintenance | 1 | 0 | 0 | 0 | 0 |
| `ptestw` | TLB and MMU maintenance | 1 | 0 | 0 | 0 | 0 |
| `cpush` | cache maintenance | 20 | 0 | 0 | 0 | 0 |
| `cpusha` | cache maintenance | 10 | 0 | 0 | 0 | 0 |
| `cpushp` | cache maintenance | 10 | 0 | 0 | 0 | 0 |
| `cinva` | cache maintenance | 3 | 0 | 0 | 0 | 0 |
| `cinvp` | cache maintenance | 2 | 0 | 0 | 0 | 0 |
| `cas` | atomics and exclusive access | 8 | 0 | 2 | 0 | 0 |
| `tas` | atomics and exclusive access | 1 | 0 | 2 | 0 | 0 |
| `moves` | user-memory access | 12 | 0 | 0 | 0 | 0 |
| `frestore` | context and FPU/vector state | 8 | 0 | 12 | 0 | 0 |
| `fsave` | context and FPU/vector state | 7 | 0 | 13 | 0 | 0 |
| `bfffo` | bit manipulation | 8 | 0 | 1 | 0 | 4 |
| `bchg` | bit manipulation | 4 | 0 | 0 | 0 | 2 |
| `bfclr` | bit manipulation | 3 | 0 | 0 | 0 | 2 |
| `bfset` | bit manipulation | 3 | 0 | 0 | 0 | 0 |
| `bfchg` | bit manipulation | 2 | 0 | 0 | 0 | 0 |

Other (not classified): `movl` 870, `bsr` 193, `movw` 107, `movc` 103, `nop` 58, `movb` 48, `movml` 40, `dbf` 27, `andi` 25, `movsb` 25, `movql` 24, `movsl` 19, `l` 16, `ori` 15, `putn` 13, `roxl` 12, `movpw` 11, `subi` 10, `fnop` 9, `b` 8, `w` 8, `movea` 7, `addi` 6, `divu` 6, `fmovemd` 6, `move.` 6, `asm_op` 5, `movq` 5, `movsw` 5, `mvzw` 5, `dbeq` 4, `byterev` 3, `move16` 3, `plpar` 3.

### A.9 SPARC

Compiled corpus: 696304 instruction lines. 38 classified invisible mnemonics, 35 other (three or more uses).

| Mnemonic | Class | L | F | N | O | Compiler |
|---|---|---:|---:|---:|---:|---:|
| `retry` | exception entry/return and system call | 37 | 0 | 30 | 28 | 0 |
| `rett` | exception entry/return and system call | 13 | 0 | 4 | 0 | 0 |
| `done` | exception entry/return and system call | 6 | 0 | 4 | 3 | 0 |
| `tne` | exception entry/return and system call | 7 | 0 | 1 | 1 | 0 |
| `wrpr` | privileged register access | 172 | 0 | 324 | 195 | 0 |
| `rdpr` | privileged register access | 153 | 0 | 207 | 127 | 0 |
| `rd` | privileged register access | 152 | 0 | 101 | 29 | 0 |
| `flushw` | TLB and MMU maintenance | 19 | 0 | 22 | 11 | 1 |
| `flush` | cache maintenance | 66 | 0 | 65 | 20 | 0 |
| `prefetch` | cache maintenance | 48 | 0 | 0 | 0 | 0 |
| `prefetcha` | cache maintenance | 4 | 0 | 0 | 0 | 0 |
| `membar` | memory barrier and ordering | 235 | 0 | 181 | 117 | 0 |
| `casxa` | atomics and exclusive access | 1 | 0 | 12 | 14 | 0 |
| `ldstub` | atomics and exclusive access | 17 | 0 | 9 | 0 | 0 |
| `casx` | atomics and exclusive access | 14 | 0 | 0 | 2 | 0 |
| `cas` | atomics and exclusive access | 6 | 0 | 0 | 1 | 0 |
| `casa` | atomics and exclusive access | 2 | 0 | 1 | 2 | 0 |
| `swap` | atomics and exclusive access | 3 | 0 | 1 | 0 | 0 |
| `swapa` | atomics and exclusive access | 2 | 0 | 0 | 0 | 0 |
| `stxa` | user-memory access | 372 | 0 | 154 | 86 | 0 |
| `ldxa` | user-memory access | 217 | 0 | 138 | 113 | 0 |
| `sta` | user-memory access | 185 | 0 | 30 | 4 | 0 |
| `lda` | user-memory access | 65 | 0 | 60 | 2 | 0 |
| `stda` | user-memory access | 41 | 0 | 13 | 13 | 0 |
| `ldda` | user-memory access | 40 | 0 | 15 | 10 | 0 |
| `stba` | user-memory access | 19 | 0 | 16 | 9 | 0 |
| `lduba` | user-memory access | 21 | 0 | 12 | 4 | 0 |
| `stha` | user-memory access | 11 | 0 | 9 | 5 | 0 |
| `stwa` | user-memory access | 5 | 0 | 17 | 2 | 0 |
| `lduwa` | user-memory access | 10 | 0 | 5 | 6 | 0 |
| `lduha` | user-memory access | 11 | 0 | 6 | 3 | 0 |
| `ldsba` | user-memory access | 0 | 0 | 6 | 6 | 0 |
| `ldsha` | user-memory access | 0 | 0 | 3 | 3 | 0 |
| `ldswa` | user-memory access | 0 | 0 | 1 | 0 | 0 |
| `saved` | context and FPU/vector state | 1 | 0 | 8 | 8 | 0 |
| `restored` | context and FPU/vector state | 0 | 0 | 5 | 5 | 0 |
| `popc` | bit manipulation | 6 | 0 | 0 | 0 | 0 |
| `sir` | debug and breakpoints | 0 | 0 | 20 | 6 | 0 |

Other (not classified): `mov` 241, `mulscc` 131, `stw` 103, `faligndata` 82, `addxcc` 79, `fsrc2` 72, `fdtos` 32, `addccc` 14, `blt` 13, `x` 12, `beq` 11, `ld` 11, `st` 11, `addc` 10, `pstate` 10, `reg` 9, `umul` 8, `tnz` 7, `xcc` 7, `alignaddr` 6, `subxcc` 6, `asi` 5, `bgt` 5, `bneg` 5, `pil` 5, `d` 4, `h` 4, `movnz` 4, `ub` 4, `uh` 4, `fprs` 3, `movz` 3, `smul` 3, `tlu` 3, `unimp` 3.

### A.10 s390 (z/Architecture)

Compiled corpus: 535703 instruction lines. 67 classified invisible mnemonics, 9 other (three or more uses).

| Mnemonic | Class | L | F | N | O | Compiler |
|---|---|---:|---:|---:|---:|---:|
| `lpswe` | exception entry/return and system call | 15 | 0 | 0 | 0 | 0 |
| `lpsw` | exception entry/return and system call | 1 | 0 | 0 | 0 | 0 |
| `svc` | exception entry/return and system call | 1 | 0 | 0 | 0 | 0 |
| `lctlg` | privileged register access | 10 | 0 | 0 | 0 | 0 |
| `sam64` | privileged register access | 10 | 0 | 0 | 0 | 0 |
| `spka` | privileged register access | 9 | 0 | 0 | 0 | 0 |
| `epsw` | privileged register access | 6 | 0 | 0 | 0 | 0 |
| `lra` | privileged register access | 6 | 0 | 0 | 0 | 0 |
| `sam31` | privileged register access | 5 | 0 | 0 | 0 | 0 |
| `stctg` | privileged register access | 5 | 0 | 0 | 0 | 0 |
| `sacf` | privileged register access | 4 | 0 | 0 | 0 | 0 |
| `spx` | privileged register access | 3 | 0 | 0 | 0 | 0 |
| `stap` | privileged register access | 3 | 0 | 0 | 0 | 0 |
| `stnsm` | privileged register access | 2 | 0 | 0 | 0 | 0 |
| `stosm` | privileged register access | 2 | 0 | 0 | 0 | 0 |
| `stpx` | privileged register access | 2 | 0 | 0 | 0 | 0 |
| `ecag` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `ecctr` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `lcctl` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `lpp` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `lsctl` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `qctri` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `qsi` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `sck` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `sckpf` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `ssm` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `stfl` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `tprot` | privileged register access | 1 | 0 | 0 | 0 | 0 |
| `idte` | TLB and MMU maintenance | 7 | 0 | 0 | 0 | 0 |
| `ipte` | TLB and MMU maintenance | 3 | 0 | 0 | 0 | 0 |
| `ptlb` | TLB and MMU maintenance | 2 | 0 | 0 | 0 | 0 |
| `cspg` | TLB and MMU maintenance | 1 | 0 | 0 | 0 | 0 |
| `sske` | cache maintenance | 2 | 0 | 0 | 0 | 0 |
| `iske` | cache maintenance | 1 | 0 | 0 | 0 | 0 |
| `rrbe` | cache maintenance | 1 | 0 | 0 | 0 | 0 |
| `bcr` | memory barrier and ordering | 1 | 0 | 0 | 0 | 0 |
| `csg` | atomics and exclusive access | 4 | 0 | 0 | 0 | 0 |
| `cdsg` | atomics and exclusive access | 3 | 0 | 0 | 0 | 0 |
| `sigp` | spin-wait, idle and hints | 12 | 0 | 0 | 0 | 0 |
| `mvcos` | user-memory access | 8 | 0 | 0 | 0 | 0 |
| `sturg` | user-memory access | 2 | 0 | 0 | 0 | 0 |
| `lfpc` | context and FPU/vector state | 3 | 0 | 0 | 0 | 0 |
| `stfpc` | context and FPU/vector state | 3 | 0 | 0 | 0 | 0 |
| `stamy` | context and FPU/vector state | 2 | 0 | 0 | 0 | 0 |
| `lamy` | context and FPU/vector state | 1 | 0 | 0 | 0 | 0 |
| `lmh` | context and FPU/vector state | 1 | 0 | 0 | 0 | 0 |
| `lpq` | context and FPU/vector state | 1 | 0 | 0 | 0 | 0 |
| `plo` | context and FPU/vector state | 1 | 0 | 0 | 0 | 0 |
| `stm` | context and FPU/vector state | 1 | 0 | 0 | 0 | 0 |
| `mvcl` | string and memory block | 3 | 0 | 0 | 0 | 0 |
| `tr` | string and memory block | 2 | 0 | 0 | 0 | 0 |
| `cksm` | string and memory block | 1 | 0 | 0 | 0 | 0 |
| `clcle` | string and memory block | 1 | 0 | 0 | 0 | 0 |
| `stidp` | CPU identification and feature | 2 | 0 | 0 | 0 | 0 |
| `stsi` | CPU identification and feature | 1 | 0 | 0 | 0 | 0 |
| `stpt` | timers and counters | 12 | 0 | 0 | 0 | 0 |
| `stcke` | timers and counters | 4 | 0 | 0 | 0 | 0 |
| `spt` | timers and counters | 3 | 0 | 0 | 0 | 0 |
| `stckf` | timers and counters | 2 | 0 | 0 | 0 | 0 |
| `sckc` | timers and counters | 1 | 0 | 0 | 0 | 0 |
| `stckc` | timers and counters | 1 | 0 | 0 | 0 | 0 |
| `tsch` | I/O and device access | 2 | 0 | 0 | 0 | 0 |
| `ssch` | I/O and device access | 1 | 0 | 0 | 0 | 0 |
| `stsch` | I/O and device access | 1 | 0 | 0 | 0 | 0 |
| `tpi` | I/O and device access | 1 | 0 | 0 | 0 | 0 |
| `diag` | hypervisor, secure and firmware calls | 33 | 0 | 0 | 0 | 0 |
| `sie` | hypervisor, secure and firmware calls | 1 | 0 | 0 | 0 | 0 |

Other (not classified): `brc` 18, `jz` 13, `jnz` 12, `bras` 7, `tmhh` 6, `nop` 5, `nop.insn` 4, `mc` 3, `nopr` 3.

### A.11 Alpha *

Compiled corpus: none instruction lines. 16 classified invisible mnemonics, 87 other (three or more uses).

| Mnemonic | Class | L | F | N | O | Compiler |
|---|---|---:|---:|---:|---:|---:|
| `call_pal` | exception entry/return and system call | 40 | 0 | 66 | 74 | 0 |
| `imb` | cache maintenance | 1 | 0 | 0 | 0 | 0 |
| `mb` | memory barrier and ordering | 8 | 0 | 5 | 10 | 0 |
| `wmb` | memory barrier and ordering | 1 | 0 | 1 | 0 | 0 |
| `excb` | memory barrier and ordering | 0 | 0 | 1 | 0 | 0 |
| `stl_c` | atomics and exclusive access | 22 | 0 | 4 | 3 | 0 |
| `ldq_l` | atomics and exclusive access | 13 | 0 | 9 | 5 | 0 |
| `stq_c` | atomics and exclusive access | 13 | 0 | 9 | 5 | 0 |
| `ldl_l` | atomics and exclusive access | 19 | 0 | 4 | 3 | 0 |
| `halt` | spin-wait, idle and hints | 0 | 0 | 0 | 1 | 0 |
| `cttz` | bit manipulation | 8 | 0 | 0 | 0 | 0 |
| `ctlz` | bit manipulation | 3 | 0 | 0 | 0 | 0 |
| `ctpop` | bit manipulation | 2 | 0 | 0 | 0 | 0 |
| `amask` | CPU identification and feature | 1 | 0 | 1 | 1 | 0 |
| `implver` | CPU identification and feature | 1 | 0 | 1 | 1 | 0 |
| `rpcc` | timers and counters | 7 | 0 | 2 | 3 | 0 |

Other (not classified): `stq` 710, `ldq` 535, `addq` 334, `nop` 311, `lda` 276, `mov` 261, `beq` 260, `bne` 227, `subq` 213, `or` 199, `and` 196, `ldq_u` 168, `br` 139, `ldiq` 103, `bis` 94, `ret` 91, `cmpbge` 81, `ldt` 76, `stt` 75, `stq_u` 72, `srl` 68, `sll` 63, `cmpult` 57, `cmovne` 52, `unop` 52, `extql` 48, `mskql` 43, `cmoveq` 42, `extqh` 41, `mskqh` 38, `xor` 38, `andnot` 32, `bic` 32, `ldl` 32, `jmp` 29, `jsr` 29, `zap` 29, `zapnot` 29, `insbl` 25, `cmplt` 24, `negq` 23, `cmpeq` 22, `cmpule` 20, `inswl` 20, `stl` 20, `wh64` 20, `extbl` 17, `insqh` 17, `insql` 17, `blt` 16, `extwl` 16, `ldgp` 16, `ble` 14, `addl` 13, `bgt` 13, `bsr` 13, `mskbl` 13, `blbc` 12, `subl` 12, `cmovlt` 11.

### A.12 VAX

Compiled corpus: 253923 instruction lines. 22 classified invisible mnemonics, 13 other (three or more uses).

| Mnemonic | Class | L | F | N | O | Compiler |
|---|---|---:|---:|---:|---:|---:|
| `rei` | exception entry/return and system call | 0 | 0 | 28 | 0 | 0 |
| `chmk` | exception entry/return and system call | 0 | 0 | 5 | 0 | 0 |
| `mfpr` | privileged register access | 0 | 0 | 42 | 0 | 0 |
| `mtpr` | privileged register access | 0 | 0 | 40 | 0 | 0 |
| `movpsl` | privileged register access | 0 | 0 | 11 | 0 | 0 |
| `bbssi` | atomics and exclusive access | 0 | 0 | 7 | 0 | 0 |
| `bbcci` | atomics and exclusive access | 0 | 0 | 5 | 0 | 0 |
| `insqti` | atomics and exclusive access | 0 | 0 | 1 | 0 | 0 |
| `insque` | atomics and exclusive access | 0 | 0 | 1 | 0 | 0 |
| `remqhi` | atomics and exclusive access | 0 | 0 | 1 | 0 | 0 |
| `remque` | atomics and exclusive access | 0 | 0 | 1 | 0 | 0 |
| `halt` | spin-wait, idle and hints | 0 | 0 | 35 | 0 | 0 |
| `pushr` | context and FPU/vector state | 0 | 0 | 26 | 0 | 0 |
| `popr` | context and FPU/vector state | 0 | 0 | 22 | 0 | 0 |
| `ldpctx` | context and FPU/vector state | 0 | 0 | 4 | 0 | 0 |
| `svpctx` | context and FPU/vector state | 0 | 0 | 2 | 0 | 0 |
| `locc` | string and memory block | 0 | 0 | 10 | 0 | 0 |
| `cmpc3` | string and memory block | 0 | 0 | 3 | 0 | 0 |
| `scanc` | string and memory block | 0 | 0 | 1 | 0 | 0 |
| `skpc` | string and memory block | 0 | 0 | 1 | 0 | 0 |
| `ffs` | bit manipulation | 0 | 0 | 2 | 0 | 1 |
| `bpt` | debug and breakpoints | 0 | 0 | 1 | 0 | 0 |

Other (not classified): `bsbw` 35, `sobgtr` 32, `brw` 22, `jsb` 21, `rsb` 20, `blbc` 15, `bbc` 12, `blbs` 9, `callg` 7, `caseb` 7, `bvs` 5, `bbs` 4, `bcs` 4.

### A.13 PA-RISC *

Compiled corpus: none instruction lines. 26 classified invisible mnemonics, 55 other (three or more uses).

| Mnemonic | Class | L | F | N | O | Compiler |
|---|---|---:|---:|---:|---:|---:|
| `rfir` | exception entry/return and system call | 0 | 0 | 17 | 21 | 0 |
| `rfi` | exception entry/return and system call | 0 | 0 | 7 | 5 | 0 |
| `be` | exception entry/return and system call | 0 | 0 | 2 | 2 | 0 |
| `ble` | exception entry/return and system call | 0 | 0 | 2 | 2 | 0 |
| `mtctl` | privileged register access | 0 | 0 | 119 | 112 | 0 |
| `mfctl` | privileged register access | 0 | 0 | 84 | 110 | 0 |
| `mtsp` | privileged register access | 0 | 0 | 72 | 74 | 0 |
| `mfsp` | privileged register access | 0 | 0 | 22 | 21 | 0 |
| `rsm` | privileged register access | 0 | 0 | 10 | 6 | 0 |
| `ssm` | privileged register access | 0 | 0 | 7 | 3 | 0 |
| `mtsm` | privileged register access | 0 | 0 | 3 | 2 | 0 |
| `idtlba` | TLB and MMU maintenance | 0 | 0 | 6 | 5 | 0 |
| `idtlbp` | TLB and MMU maintenance | 0 | 0 | 6 | 5 | 0 |
| `iitlba` | TLB and MMU maintenance | 0 | 0 | 2 | 2 | 0 |
| `iitlbp` | TLB and MMU maintenance | 0 | 0 | 2 | 2 | 0 |
| `pdtlb` | TLB and MMU maintenance | 0 | 0 | 1 | 1 | 0 |
| `pdtlbe` | TLB and MMU maintenance | 0 | 0 | 1 | 1 | 0 |
| `pitlb` | TLB and MMU maintenance | 0 | 0 | 1 | 1 | 0 |
| `pitlbe` | TLB and MMU maintenance | 0 | 0 | 1 | 1 | 0 |
| `fdc` | cache maintenance | 0 | 0 | 30 | 28 | 0 |
| `fic` | cache maintenance | 0 | 0 | 21 | 19 | 0 |
| `fdce` | cache maintenance | 0 | 0 | 1 | 1 | 0 |
| `fice` | cache maintenance | 0 | 0 | 1 | 1 | 0 |
| `sync` | memory barrier and ordering | 0 | 0 | 25 | 35 | 0 |
| `syncdma` | memory barrier and ordering | 0 | 0 | 4 | 4 | 0 |
| `ldcw` | atomics and exclusive access | 0 | 0 | 4 | 0 | 0 |

Other (not classified): `stw` 500, `ldw` 467, `nop` 346, `addc` 336, `sh3add` 248, `ldo` 229, `bv` 199, `copy` 185, `ldil` 163, `shd` 147, `sh2add` 135, `zdep` 103, `extru` 101, `ldi` 99, `sh1add` 86, `add` 83, `stws` 81, `addb` 80, `ldws` 79, `fstds` 70, `sub` 70, `depi` 68, `fldds` 64, `b` 62, `addi` 52, `stwm` 49, `ldwm` 47, `pdc` 38, `addib` 35, `blr` 35, `dep` 24, `vshd` 14, `bl` 13, `or` 12, `xor` 12, `stwas` 11, `ldbs` 10, `diag` 9, `extrs` 9, `idtlbt` 8, `stbs` 8, `stbys` 8, `andcm` 7, `movib` 6, `addil` 5, `ldb` 4, `ldsid` 4, `ldwx` 4, `movb` 4, `mtsar` 4, `subi` 4, `gr0` 3, `ldcws` 3, `sh2addl` 3, `sth` 3.

### A.14 m88k *

Compiled corpus: none instruction lines. 8 classified invisible mnemonics, 36 other (three or more uses).

| Mnemonic | Class | L | F | N | O | Compiler |
|---|---|---:|---:|---:|---:|---:|
| `tb0` | exception entry/return and system call | 0 | 0 | 0 | 6 | 0 |
| `tb1` | exception entry/return and system call | 0 | 0 | 0 | 3 | 0 |
| `ldcr` | privileged register access | 0 | 0 | 0 | 119 | 0 |
| `stcr` | privileged register access | 0 | 0 | 0 | 58 | 0 |
| `fldcr` | privileged register access | 0 | 0 | 0 | 19 | 0 |
| `xcr` | privileged register access | 0 | 0 | 0 | 17 | 0 |
| `fstcr` | privileged register access | 0 | 0 | 0 | 11 | 0 |
| `xmem` | atomics and exclusive access | 0 | 0 | 0 | 8 | 0 |

Other (not classified): `or` 186, `subu` 72, `bb1` 63, `addu` 62, `st.d` 56, `bcnd` 45, `br.n` 45, `br` 42, `jmp.n` 37, `cmp` 29, `jmp` 27, `clr` 24, `or.u` 23, `st.b` 21, `st.h` 21, `ld.d` 19, `ld.hu` 18, `bsr` 16, `ld.bu` 13, `bcnd.n` 12, `extu` 12, `ld.usr` 12, `bb1.n` 11, `mask` 11, `divu` 10, `st.b.usr` 10, `bsr.n` 8, `ld.b.usr` 8, `st.usr` 8, `bb0` 6, `ld.h` 6, `ld.h.usr` 6, `st.h.usr` 6, `ld.b` 5, `mak` 4, `xor` 3.


## Appendix B: class by architecture by kernel

Distinct compiler-invisible mnemonics and total occurrences for each class, architecture and kernel. Cells are `distinct/occurrences`; a dash means none.

### exception entry/return and system call

| Architecture | Linux | FreeBSD | NetBSD | OpenBSD | All |
|---|---:|---:|---:|---:|---:|
| x86 (i386, amd64) | 8/56 | 7/34 | 5/61 | 6/87 | 9/238 |
| AArch64 | 1/19 | 2/8 | 1/1 | 2/6 | 2/34 |
| ARM 32-bit | 3/6 | 2/4 | 3/6 | 3/3 | 5/19 |
| RISC-V | 3/10 | 2/8 | 2/6 | 2/5 | 3/29 |
| MIPS | 3/10 | - | 3/19 | 1/1 | 4/30 |
| PowerPC | 7/77 | 6/35 | 4/18 | 2/4 | 7/134 |
| LoongArch | 1/9 | - | - | - | 1/9 |
| m68k | 1/1 | - | 1/16 | - | 1/17 |
| SPARC | 4/63 | - | 4/39 | 3/32 | 4/134 |
| s390 (z/Architecture) | 3/17 | - | - | - | 3/17 |
| Alpha * | 1/40 | - | 1/66 | 1/74 | 1/180 |
| VAX | - | - | 2/33 | - | 2/33 |
| PA-RISC * | - | - | 4/28 | 4/30 | 4/58 |
| m88k * | - | - | - | 2/9 | 2/9 |

### privileged register access

| Architecture | Linux | FreeBSD | NetBSD | OpenBSD | All |
|---|---:|---:|---:|---:|---:|
| x86 (i386, amd64) | 18/115 | 19/182 | 14/106 | 16/162 | 20/565 |
| AArch64 | 3/203 | 4/151 | 2/153 | 2/160 | 4/667 |
| ARM 32-bit | 6/1642 | 6/140 | 6/676 | 5/145 | 6/2603 |
| RISC-V | 7/130 | 10/73 | 8/59 | 10/53 | 12/315 |
| MIPS | 23/341 | - | 6/436 | 4/121 | 25/898 |
| PowerPC | 36/1994 | 35/424 | 41/634 | 25/125 | 46/3177 |
| LoongArch | 5/136 | - | - | - | 5/136 |
| m68k | 3/109 | - | 4/34 | - | 4/143 |
| SPARC | 3/477 | - | 3/632 | 3/351 | 3/1460 |
| s390 (z/Architecture) | 25/79 | - | - | - | 25/79 |
| VAX | - | - | 3/93 | - | 3/93 |
| PA-RISC * | - | - | 7/317 | 7/328 | 7/645 |
| m88k * | - | - | - | 5/224 | 5/224 |

### interrupt masking

| Architecture | Linux | FreeBSD | NetBSD | OpenBSD | All |
|---|---:|---:|---:|---:|---:|
| x86 (i386, amd64) | 4/110 | 4/133 | 4/113 | 4/172 | 4/528 |
| ARM 32-bit | 2/14 | 1/3 | 3/17 | 3/7 | 3/41 |
| MIPS | 2/4 | - | 2/7 | - | 2/11 |
| PowerPC | 2/31 | 2/11 | 2/32 | - | 2/74 |

### TLB and MMU maintenance

| Architecture | Linux | FreeBSD | NetBSD | OpenBSD | All |
|---|---:|---:|---:|---:|---:|
| x86 (i386, amd64) | 2/2 | 6/9 | 2/6 | 4/20 | 6/37 |
| AArch64 | 1/13 | 1/27 | 1/19 | 1/17 | 1/76 |
| RISC-V | 1/9 | 5/11 | 1/6 | 1/9 | 5/35 |
| MIPS | 5/7 | - | 4/44 | 4/22 | 5/73 |
| PowerPC | 16/300 | 15/89 | 11/65 | 8/18 | 16/472 |
| LoongArch | 9/29 | - | - | - | 9/29 |
| m68k | 7/27 | - | 4/23 | - | 8/50 |
| SPARC | 1/19 | - | 1/22 | 1/11 | 1/52 |
| s390 (z/Architecture) | 4/13 | - | - | - | 4/13 |
| PA-RISC * | - | - | 8/20 | 8/18 | 8/38 |

### cache maintenance

| Architecture | Linux | FreeBSD | NetBSD | OpenBSD | All |
|---|---:|---:|---:|---:|---:|
| x86 (i386, amd64) | 3/10 | 5/15 | 2/8 | 3/13 | 6/46 |
| AArch64 | 4/51 | 3/13 | 4/21 | 2/7 | 5/92 |
| ARM 32-bit | 4/5 | 1/36 | 1/48 | - | 4/89 |
| RISC-V | - | 3/3 | - | 3/3 | 3/6 |
| MIPS | 4/44 | - | 2/241 | 1/2 | 4/287 |
| PowerPC | 7/66 | 6/17 | 7/56 | 6/11 | 9/150 |
| LoongArch | 1/1 | - | - | - | 1/1 |
| m68k | 5/45 | - | - | - | 5/45 |
| SPARC | 3/118 | - | 1/65 | 1/20 | 3/203 |
| s390 (z/Architecture) | 3/4 | - | - | - | 3/4 |
| Alpha * | 1/1 | - | - | - | 1/1 |
| PA-RISC * | - | - | 4/53 | 4/49 | 4/102 |

### memory barrier and ordering

| Architecture | Linux | FreeBSD | NetBSD | OpenBSD | All |
|---|---:|---:|---:|---:|---:|
| x86 (i386, amd64) | 3/16 | 3/58 | 3/9 | 3/126 | 3/209 |
| AArch64 | 3/88 | 3/73 | 3/85 | 2/137 | 3/383 |
| ARM 32-bit | 3/9 | 3/12 | 3/79 | 2/81 | 3/181 |
| RISC-V | 2/5 | 2/3 | 2/28 | 2/39 | 2/75 |
| MIPS | 5/46 | - | 7/75 | 2/2 | 8/123 |
| PowerPC | 7/596 | 6/217 | 5/399 | 3/65 | 7/1277 |
| LoongArch | 2/11 | - | - | - | 2/11 |
| SPARC | 1/235 | - | 1/181 | 1/117 | 1/533 |
| s390 (z/Architecture) | 1/1 | - | - | - | 1/1 |
| Alpha * | 2/9 | - | 3/7 | 1/10 | 3/26 |
| PA-RISC * | - | - | 2/29 | 2/39 | 2/68 |

### atomics and exclusive access

| Architecture | Linux | FreeBSD | NetBSD | OpenBSD | All |
|---|---:|---:|---:|---:|---:|
| x86 (i386, amd64) | 17/81 | 8/54 | 6/46 | 6/32 | 20/213 |
| AArch64 | 22/57 | 13/39 | 6/10 | 9/28 | 31/134 |
| ARM 32-bit | 10/72 | 5/73 | 6/14 | 3/22 | 11/181 |
| RISC-V | 6/13 | 12/32 | 4/4 | 2/2 | 14/51 |
| MIPS | 4/40 | - | 4/6 | 4/22 | 4/68 |
| PowerPC | 8/129 | 8/91 | 2/6 | 4/57 | 8/283 |
| LoongArch | 7/32 | - | - | - | 7/32 |
| m68k | 2/9 | - | 2/4 | - | 2/13 |
| SPARC | 7/45 | - | 4/23 | 4/19 | 7/87 |
| s390 (z/Architecture) | 2/7 | - | - | - | 2/7 |
| Alpha * | 4/67 | - | 4/26 | 4/16 | 4/109 |
| VAX | - | - | 6/16 | - | 6/16 |
| PA-RISC * | - | - | 1/4 | - | 1/4 |
| m88k * | - | - | - | 1/8 | 1/8 |

### spin-wait, idle and hints

| Architecture | Linux | FreeBSD | NetBSD | OpenBSD | All |
|---|---:|---:|---:|---:|---:|
| x86 (i386, amd64) | 6/27 | 4/24 | 4/22 | 4/32 | 6/105 |
| AArch64 | 6/28 | 5/12 | 4/10 | 4/15 | 6/65 |
| ARM 32-bit | 3/6 | 3/4 | 3/7 | 3/7 | 3/24 |
| RISC-V | 1/2 | 1/5 | 1/6 | 1/1 | 1/14 |
| MIPS | 1/7 | - | 1/4 | 1/1 | 1/12 |
| PowerPC | 1/1 | 1/1 | - | 1/2 | 3/4 |
| LoongArch | 1/5 | - | - | - | 1/5 |
| s390 (z/Architecture) | 1/12 | - | - | - | 1/12 |
| Alpha * | - | - | - | 1/1 | 1/1 |
| VAX | - | - | 1/35 | - | 1/35 |

### user-memory access

| Architecture | Linux | FreeBSD | NetBSD | OpenBSD | All |
|---|---:|---:|---:|---:|---:|
| x86 (i386, amd64) | 2/32 | 2/50 | 2/4 | 2/2 | 2/88 |
| AArch64 | - | 1/1 | 6/42 | 4/9 | 6/52 |
| ARM 32-bit | 2/6 | 5/155 | 6/226 | 4/66 | 6/453 |
| m68k | 1/12 | - | - | - | 1/12 |
| SPARC | 12/997 | - | 15/485 | 14/266 | 15/1748 |
| s390 (z/Architecture) | 2/10 | - | - | - | 2/10 |

### per-CPU and thread base

| Architecture | Linux | FreeBSD | NetBSD | OpenBSD | All |
|---|---:|---:|---:|---:|---:|
| x86 (i386, amd64) | 5/25 | 5/31 | 1/14 | 1/13 | 5/83 |

### context and FPU/vector state

| Architecture | Linux | FreeBSD | NetBSD | OpenBSD | All |
|---|---:|---:|---:|---:|---:|
| x86 (i386, amd64) | 10/24 | 18/42 | 14/73 | 13/41 | 20/180 |
| ARM 32-bit | 2/2 | 2/2 | 1/1 | 2/4 | 2/9 |
| RISC-V | 4/13 | 4/8 | 5/5 | 5/11 | 9/37 |
| MIPS | 2/8 | - | 2/25 | 2/14 | 2/47 |
| PowerPC | 7/19 | 4/6 | 16/99 | 6/13 | 18/137 |
| LoongArch | 6/75 | - | - | - | 6/75 |
| m68k | 2/15 | - | 2/25 | - | 2/40 |
| SPARC | 1/1 | - | 2/13 | 2/13 | 2/27 |
| s390 (z/Architecture) | 8/13 | - | - | - | 8/13 |
| VAX | - | - | 4/54 | - | 4/54 |

### string and memory block

| Architecture | Linux | FreeBSD | NetBSD | OpenBSD | All |
|---|---:|---:|---:|---:|---:|
| x86 (i386, amd64) | 14/103 | 5/47 | 7/83 | 15/164 | 22/397 |
| AArch64 | 6/6 | - | - | - | 6/6 |
| PowerPC | - | - | 4/10 | - | 4/10 |
| s390 (z/Architecture) | 4/7 | - | - | - | 4/7 |
| VAX | - | - | 4/15 | - | 4/15 |

### bit manipulation

| Architecture | Linux | FreeBSD | NetBSD | OpenBSD | All |
|---|---:|---:|---:|---:|---:|
| x86 (i386, amd64) | 1/1 | 1/4 | - | - | 2/5 |
| RISC-V | 4/10 | - | - | - | 4/10 |
| MIPS | 4/22 | - | 2/9 | - | 4/31 |
| PowerPC | 1/1 | - | - | - | 1/1 |
| LoongArch | 2/3 | - | - | - | 2/3 |
| m68k | 5/20 | - | 1/1 | - | 5/21 |
| SPARC | 1/6 | - | - | - | 1/6 |
| Alpha * | 3/13 | - | - | - | 3/13 |
| VAX | - | - | 1/2 | - | 1/2 |

### CPU identification and feature

| Architecture | Linux | FreeBSD | NetBSD | OpenBSD | All |
|---|---:|---:|---:|---:|---:|
| x86 (i386, amd64) | 1/21 | 2/11 | 1/17 | 1/25 | 2/74 |
| s390 (z/Architecture) | 2/3 | - | - | - | 2/3 |
| Alpha * | 2/2 | - | 2/2 | 2/2 | 2/6 |

### timers and counters

| Architecture | Linux | FreeBSD | NetBSD | OpenBSD | All |
|---|---:|---:|---:|---:|---:|
| x86 (i386, amd64) | 2/2 | 3/17 | 1/2 | 3/14 | 3/35 |
| MIPS | 1/5 | - | 1/2 | 1/1 | 1/8 |
| PowerPC | 5/23 | 2/7 | 5/19 | 4/11 | 5/60 |
| LoongArch | 3/3 | - | - | - | 3/3 |
| s390 (z/Architecture) | 6/23 | - | - | - | 6/23 |
| Alpha * | 1/7 | - | 1/2 | 1/3 | 1/12 |

### random numbers

| Architecture | Linux | FreeBSD | NetBSD | OpenBSD | All |
|---|---:|---:|---:|---:|---:|
| x86 (i386, amd64) | 2/5 | - | 2/8 | 2/8 | 2/21 |
| PowerPC | - | - | - | 1/1 | 1/1 |

### I/O and device access

| Architecture | Linux | FreeBSD | NetBSD | OpenBSD | All |
|---|---:|---:|---:|---:|---:|
| x86 (i386, amd64) | 4/11 | 4/37 | 4/99 | 4/69 | 6/216 |
| s390 (z/Architecture) | 4/5 | - | - | - | 4/5 |

### hypervisor, secure and firmware calls

| Architecture | Linux | FreeBSD | NetBSD | OpenBSD | All |
|---|---:|---:|---:|---:|---:|
| x86 (i386, amd64) | 8/16 | 14/14 | - | 14/20 | 16/50 |
| AArch64 | 2/10 | 1/1 | - | 2/4 | 2/15 |
| ARM 32-bit | 2/2 | 1/1 | 2/4 | 2/3 | 2/10 |
| RISC-V | - | 1/2 | - | - | 1/2 |
| LoongArch | 4/9 | - | - | - | 4/9 |
| s390 (z/Architecture) | 2/34 | - | - | - | 2/34 |

### debug and breakpoints

| Architecture | Linux | FreeBSD | NetBSD | OpenBSD | All |
|---|---:|---:|---:|---:|---:|
| x86 (i386, amd64) | 1/50 | - | 1/2 | 1/4 | 1/56 |
| AArch64 | 1/1 | - | 1/1 | 1/1 | 2/3 |
| RISC-V | - | - | 1/1 | 1/2 | 1/3 |
| MIPS | 1/1 | - | 3/3 | - | 3/4 |
| PowerPC | 2/14 | - | - | - | 2/14 |
| SPARC | - | - | 1/20 | 1/6 | 1/26 |
| VAX | - | - | 1/1 | - | 1/1 |

### speculation control

| Architecture | Linux | FreeBSD | NetBSD | OpenBSD | All |
|---|---:|---:|---:|---:|---:|
| x86 (i386, amd64) | 2/33 | - | - | 1/15 | 2/48 |
| AArch64 | - | - | - | 1/6 | 1/6 |


## Appendix C: how the path lengths were counted

Each row of the table in section 8 was obtained by reading the entry assembler of the kernel named, at the revision of section 2, and counting instructions on the common path. The tool counted statements in line ranges (`C`) with the same parser as the survey: `entry_64.S` lines 177 to 217 (`__switch_to_asm`) for Linux x86-64; `arm64/kernel/entry.S` lines 833 to 860 (`cpu_switch_to`) and the `kernel_entry`/`kernel_exit` macros (lines 208 to 346 and 347 onward); `arm/kernel/entry-common.S` lines 171 to 293 (`vector_swi`, 27 statements), `entry-armv.S` lines 512 to 594 (`__switch_to`, 27); `riscv/kernel/entry.S` lines 128 to 243 (`handle_exception`, 32 plus macro statements for the 26 register stores of `save_from_x6_to_x31` and the `REG_S`/`REG_L` runs), 252 to 323 (`ret_from_exception`, 13 plus the register reloads), 426 to 476 (`__switch_to`); `m68k/kernel/entry.S` lines 202 to 240 (`system_call`, 22) and 241 to 288 (`ret_from_exception`, 25); `s390/kernel/entry.S` lines 253 to 288 (23) and 155 to 176 (15); `alpha/kernel/entry.S` lines 474 to 530, 530 to 600, 673 to 694; `loongarch/kernel/entry.S` lines 22 to 81 (30), `stackframe.h` `SAVE_ALL` 36; FreeBSD `sys/amd64/amd64/exception.S` lines 525 to 570 (34) and 571 to 600 (27), `cpu_switch.S` lines 72 to 302 (170 statements in total, including every conditional path); FreeBSD `sys/arm64/arm64/swtch.S` 142 to 228 (46); NetBSD `sys/arch/vax/vax/intvec.S` the `syscall` entry (a handful of pushes, `pushr`, three `mfpr`/`movl`, `calls`), `subr.S` `Swtchto`; NetBSD `sys/arch/m68k/m68k/trap_subr.s` `trap0` (6 before the call, 8 after) and `rei`, `switch_subr.s` `cpu_switchto`.

**Rules.** An instruction counts once per execution on the path; a loop counts once; a conditional branch around mitigation code or a feature-patched alternative counts as absent unless the text says otherwise; `.if` blocks of macros are counted for the user-mode case; the C dispatcher and everything it calls is excluded. The `E` figures expand the macro by reading it (for example the AArch64 `kernel_entry` for exception level 0: 15 `stp`, the clearing of the argument registers, `sp_el0`, the task pointer, debug-state and tag-check bookkeeping, `elr`/`spsr` reads and stores). **Roughness:** plus or minus 25%; the counted ranges include both user and kernel variants and so are upper bounds; the ranges where the first instruction is a hardware-vectored entry do not include the vector-table stub (4 instructions on AArch64, none elsewhere).

**pdp64 row.** Entry: the hardware sets `EPC`, `EPSW`, the priority to 7 and the vector; the handler executes `PUSHX`, `PUSHM #mask`, `SPL #0`, call (4 to 5). Exit: `SPL #7`, `POPM`, `POPX`, `RTI` (4). Context switch: `PUSHM`, store `SP` in the old thread, load it from the new, `POPM`, `MTASID`, `MTSR ptbr`, `ISYNC`, return. Nothing here was run; the author's dynamic measurement of a null system call is being made separately.

## Appendix D: coverage matrix

What was surveyed. Each cell shows `asm files / inline blocks` for the family in the kernel; "none" means the kernel has no such port in the checkout (or the port was removed upstream), "not surveyed" that the port exists but its directories were not taken.

| Architecture | Linux | FreeBSD | NetBSD | OpenBSD | Compiler baseline |
|---|---|---|---|---|---|
| x86 (i386, amd64) | 73 / 598 | 35 / 386 | 82 / 101 | 71 / 379 | yes |
| AArch64 | 44 / 200 | 22 / 127 | 13 / 45 | 15 / 121 | yes |
| ARM 32-bit | 164 / 339 | 23 / 83 | 52 / 104 | 27 / 107 | yes |
| RISC-V | 50 / 111 | 9 / 82 | 6 / 66 | 9 / 107 | yes |
| MIPS | 32 / 316 | none (removed) | 32 / 84 | 16 / 28 | yes |
| PowerPC | 99 / 545 | 20 / 280 | 23 / 407 | 11 / 172 | yes |
| LoongArch | 21 / 131 | none | none | none | yes |
| m68k | 10 / 302 | none | 44 / 205 | none | yes |
| SPARC | 120 / 447 | none (removed) | 20 / 160 | 12 / 73 | yes |
| s390 (z/Architecture) | 13 / 306 | none | none | none | yes |
| Alpha | 46 / 167 | none (removed) | 20 / 68 | 27 / 72 | none |
| VAX | none | none | 14 / 90 | none (port removed) | yes |
| PA-RISC | not surveyed | none | 19 / 63 | 12 / 76 | none |
| m88k | none | none | none (m88k ports not taken) | 15 / 35 | none |

**Directories taken** (full list in `docs/codegen-data/kernelasm/sources.txt`): Linux `arch/<a>/{kernel,lib,mm,boot,include,entry,kvm}` for x86, arm64, arm, riscv, mips, powerpc, loongarch, m68k, sparc, s390, alpha, plus `arch/x86/{realmode,power,xen,um}`, `arch/arm/{vfp,probes,nwfpe}`, `arch/arm64/{hyp,net,tools}`, `arch/powerpc/{boot,mm,sysdev}`, `arch/s390/{purgatory,hypfs}`, `arch/riscv/purgatory`, `arch/mips/vdso`, `arch/loongarch/vdso` (those that exist; `vdso` paths are then excluded by the extraction); FreeBSD `sys/{amd64,i386,x86,arm64,arm,riscv,powerpc,libkern}`; NetBSD `sys/arch/{vax,m68k,alpha,sparc64,sparc,amd64,x86,i386,aarch64,riscv,hppa}`, `sys/arch/arm/{arm,arm32,include,vfp,cortex}`, `sys/arch/mips/{mips,include}`, `sys/arch/powerpc/{powerpc,include,oea,booke,ibm4xx}`, `sys/arch/{hp300/hp300,sun3/sun3,mac68k/mac68k,amiga/amiga}`, `sys/lib/libkern/arch`; OpenBSD `sys/arch/{amd64,i386,arm64,armv7,arm,riscv64,powerpc,powerpc64,sparc64,mips64,alpha,hppa,m88k}`, `sys/lib/libkern/arch`.

**Known to be missing**, by name: Linux ARC, C-SKY, Hexagon, MicroBlaze, Nios II, OpenRISC, PA-RISC, SuperH, Xtensa, UML; Linux `arch/*/crypto`, `vdso`, Xen beyond `arch/x86/xen`, selftests; NetBSD ia64, SuperH (sh3, sh5), MIPS and ARM SoC trees, the m68k ports other than the four listed, `sys/dev` drivers with inline assembly; OpenBSD SuperH, `loongson`, `octeon` and `landisk`; FreeBSD `sys/contrib`, `sys/crypto`, `sys/cddl`, `sys/dev`; the `libkern`/`libc` string routines beyond `sys/lib/libkern/arch`.
