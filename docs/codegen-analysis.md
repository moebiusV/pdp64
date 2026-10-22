# Code generation and instruction use: what compiled C says about the ISA

[← pdp64 index](../README.md)

> Update 2026-10-22: the figures below are from before the second page and the compiler work that followed. After them the compiler is level with `gcc -Os` in bytes (0.999) and 7% smaller than `clang -Os`; see `CHANGES-SINCE-R20.md` §12 and `codegen-data/pdp64-after-compiler.csv`.

**Note (2026-10-22):** the instruction-length statistics here (and the 2/4/6/8-byte distribution) predate the second page and the removal of the fourth parcel (ISA §4.18, errata 31); this document records the compiler's output before that change.

**Status: draft, 2026-10-22.** This document reports what the pcc back end for pdp64 produces on real C, how that compares with gcc and clang on amd64,
and what the instruction mix says about the instruction set. Every number says how it was measured. The measurements are *static* (they count instructions in
the compiler's output, not instructions executed), so they say how much code a program takes and which instructions the compiler chooses, not how fast it runs.

The machine-readable data behind the tables is in [`codegen-data/`](codegen-data/) (CSV, one file per table, and `analysis.json`).

## 1. How it was measured

| item | what was done |
|---|---|
| Corpus | The "fair corpus": 827 C files from nine projects (bearssl 294, c-testsuite 213, gcc-torture 158, mbedtls 101, lua 34, zlib 12, chibicc 8, lz4 5, cjson 2) that every compiler below compiled. Fourteen more files (zlib 3, gcc-torture 11) are accepted by our pcc back ends but not by gcc or clang with these flags, and are left out of every column. The file list, the include directories and the defines are those of `tools/corpus.py` in the v7unix-toolchain repository. |
| Preprocessing | Each file is preprocessed once per header set with the host `gcc -E` against musl headers: pdp64 gets the AArch64 musl set (LP64, little-endian, signed char, the same text as our aarch64 build); the three amd64 columns get the x86-64 musl set. |
| pdp64 | pcc `ccom` from `~/claude/pcc` (commit named in section 2) with `-xdmr -xtemps -xdeljumps -xinline -xdce`, then `as64`. |
| pcc amd64 | our own amd64 pcc back end with the same flags plus `-xabs`, for continuity with earlier reports. |
| gcc -Os | `gcc -m64 -fno-pie -fcf-protection=none -std=gnu99 -w -fno-asynchronous-unwind-tables -fno-unwind-tables -Os` (the amd64 entry of `corpus.py`), once with `-S` and once with `-c`. |
| clang -Os | `clang --target=x86_64-linux-gnu -fno-pic -fcf-protection=none`, the same common flags and `-Os`. |
| Instructions | The number of instruction lines of the compiler's `-S` output (for pdp64 the `.s` that `as64` accepts): lines that are not directives, labels or comments. Padding the assembler adds (`.even` no-ops) is not counted. |
| Bytes | text + read-only data + data, no bss, as GNU `size` prints for the x86 objects (text includes `.rodata`); for pdp64 the sizes of `.text`, `.data` and `.rodata` read from the ELF section headers. pdp64 keeps strings and constants in `.text` (so that references to them are 4 bytes), which is why the comparison uses the sum and not `.text` alone. |
| Lengths | pdp64: the `len` bits (15..14) of each instruction's first parcel, walking `.text`; x86: `objdump -d`, bytes between instruction starts (alignment no-ops that gcc and clang insert are included and some assembler lines are not instructions, so the totals differ from the line counts by under 3%). |
| Caveats | The corpus is not representative everywhere. `memcpy-a2.c` alone is 96% of the pdp64 image of gcc-torture (503 KB, against gcc's 390 KB for the file); the c-testsuite and gcc-torture files are small test programs that gcc folds to almost nothing; a few sources repeat the same compare-and-abort test thousands of times, which inflates the call and compare counts. Section 2 therefore also gives the totals without `memcpy-a2.c` and for the seven libraries alone. |

Tools: `tools/pdp64size.sh` is the measurement (`tools/pdp64size.sh --set fair --arch pdp64,amd64,gcc-Os,clang-Os --out DIR --keep DIR/s`); the scripts in `tools/codegen/` turn its `results.json` and the kept `.s` files into the tables below (`analyze.py`, `candidates.py`, `never.py`, `mdtables.py`, `fill.py` with `doc_template.md`; they read and write under `/tmp/p64opt`).

## 2. Code size against gcc and clang

All 827 files, per corpus (instructions are line counts of the compiler output; bytes are text + read-only data + data):

| corpus | files | pdp64 ins | pdp64 bytes | gcc -Os ins | gcc -Os bytes | clang -Os ins | clang -Os bytes | pcc amd64 ins | pcc amd64 bytes | ins / gcc | bytes / gcc | ins / clang | bytes / clang |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| bearssl | 294 | 56600 | 215145 | 44536 | 202004 | 50161 | 218622 | 58039 | 246451 | 1.27 | 1.07 | 1.13 | 0.98 |
| c-testsuite | 213 | 5025 | 21198 | 3339 | 15148 | 3922 | 18220 | 5571 | 23224 | 1.50 | 1.40 | 1.28 | 1.16 |
| chibicc | 8 | 15484 | 70484 | 14833 | 75019 | 16615 | 82351 | 17582 | 83253 | 1.04 | 0.94 | 0.93 | 0.86 |
| cjson | 2 | 5089 | 15978 | 4490 | 14703 | 5173 | 17745 | 5458 | 18201 | 1.13 | 1.09 | 0.98 | 0.90 |
| gcc-torture | 158 | 93554 | 524879 | 55872 | 412008 | 59192 | 450373 | 101034 | 499388 | 1.67 | 1.27 | 1.58 | 1.17 |
| lua | 34 | 41291 | 152448 | 38540 | 157421 | 40713 | 164118 | 44949 | 176540 | 1.07 | 0.97 | 1.01 | 0.93 |
| lz4 | 5 | 11550 | 38962 | 8291 | 32733 | 11579 | 45380 | 12330 | 47578 | 1.39 | 1.19 | 1.00 | 0.86 |
| mbedtls | 101 | 129859 | 573914 | 103566 | 542316 | 108757 | 557531 | 135505 | 640003 | 1.25 | 1.06 | 1.19 | 1.03 |
| zlib | 12 | 11663 | 59158 | 8862 | 51187 | 10016 | 56515 | 11326 | 65211 | 1.32 | 1.16 | 1.16 | 1.05 |
| **all** | 827 | 370115 | 1672166 | 282329 | 1502539 | 306128 | 1610855 | 391794 | 1799849 | 1.31 | 1.11 | 1.21 | 1.04 |


Summary, pdp64 against the references (same files):

| set | files | instructions / gcc -Os | bytes / gcc -Os | instructions / clang -Os | bytes / clang -Os |
|---|---|---|---|---|---|
| all | 827 | 1.31 | 1.11 | 1.21 | 1.04 |
| without `memcpy-a2.c` | 826 | 1.23 | 1.06 | 1.13 | 1.00 |
| the seven libraries only (no c-testsuite, no gcc-torture) | 456 | 1.22 | 1.05 | 1.12 | 0.99 |

The goal set for every pcc target is code within 5% of `gcc -Os` in bytes. On the libraries pdp64 is at 1.05 of gcc and 0.99 of clang; on the whole corpus the figure is
1.11 of gcc, because gcc is far better on the small test programs (it evaluates them at compile time) and on code with data kept in a struct (it keeps the members in registers; pcc keeps them in the
frame). The instruction count is higher than either (1.31 of gcc, 1.21 of clang) and the average instruction is shorter (section 3), so the two roughly cancel in bytes.

### How the figure moved in this round

The same 827 files, pdp64 only, one row per compiler change (`~/claude/pcc`, `arch/pdp64`); a row's figures include the earlier rows:

| step | commit | instructions | bytes | bytes / gcc -Os | bytes / clang -Os |
|---|---|---|---|---|---|
| start of the round | a0693fb9 | 402912 | 1753184 | 1.167 | 1.088 |
| no frame pointer with `-xdmr` (`pushm`, `sub`, sp-relative locals); signed `int` results are not re-extended (signed overflow is undefined; `<<` and unsigned still are); `int`/`unsigned` conversions no longer retype the operation under them | 0a6f4ed8 | 381032 | 1709620 | 1.138 | 1.061 |
| demand analysis in `peep.h`: an extension (`movl r,r`) after which only the low 32 bits are looked at is removed; `ret` reads `r1` only for a struct pair | 953d6b0c | 374301 | 1696136 | 1.129 | 1.053 |
| `push`/`pop` for one saved register; `call f; ret` becomes `jmp f` when no address of the frame can have been passed | 71ea1721 | 373589 | 1683998 | 1.121 | 1.045 |
| an address of the frame written fp-minus-constant does not force a frame; `movq sp,rN` for `lea 0(sp),rN` | 6ebbea4c | 370940 | 1674494 | 1.114 | 1.040 |
| `rol` for 64-bit rotates by constants | 9907b902 | 370115 | 1672166 | 1.113 | 1.038 |

Changes measured and not adopted: re-extending signed `int` results too (`-mwrap`) costs 2.3% of the instructions and 1.0% of the bytes; `-xssa` (a pass-2 option, not a back-end choice) makes the code 0.4% smaller and 1.2% longer in instructions.

The frame-pointer change is a policy change: with `-xdmr` a function that does not take the address of the frame (`__builtin_frame_address`) has no frame pointer, as gcc's default; without `-xdmr`, and in every variadic function, there still is one.
The re-extension policy is explained in section 8.

## 3. Instruction length

pdp64 instructions are 2, 4, 6 or 8 bytes. Counts over the 827 files, from the ELF `.text` of each object (370115 instructions, 1244148 bytes):

| bytes | instructions | share |
|---|---|---|
| 2 | 159568 | 43.1% |
| 4 | 169184 | 45.7% |
| 6 | 41314 | 11.2% |
| 8 | 49 | 0.0% |


The average is **3.36 bytes per instruction**. For comparison the x86-64 output of the same files (`objdump -d`), average **3.66** (gcc -Os) and **3.78** (clang -Os):

| bytes | gcc -Os instructions | share | clang -Os instructions | share |
|---|---|---|---|---|
| 1 | 19112 | 6.9% | 19575 | 6.4% |
| 2 | 66569 | 24.2% | 66275 | 21.7% |
| 3 | 63624 | 23.1% | 76964 | 25.2% |
| 4 | 33960 | 12.3% | 35104 | 11.5% |
| 5 | 55989 | 20.3% | 57248 | 18.7% |
| 6 | 14892 | 5.4% | 17695 | 5.8% |
| 7 | 13665 | 5.0% | 26467 | 8.7% |
| 8 | 4601 | 1.7% | 4992 | 1.6% |
| 9 | 2169 | 0.8% | 391 | 0.1% |
| 10 | 410 | 0.1% | 809 | 0.3% |
| 11 | 216 | 0.1% | 246 | 0.1% |
| 12 | 6 | 0.0% | 44 | 0.0% |

pdp64 has 43% two-byte instructions; x86 has 28-31% one- and two-byte ones. 88% of the six-byte pdp64 instructions are pc-relative operands that reach another section or an external symbol (section 5). The distribution answers the question the ISA document leaves open (section 12 there): a short form for the common memory operand would pay, see section 9.

## 4. Which instructions the compiler uses

68 of the 213 mnemonics appear in the output; the other 145 never do. The 25 most frequent, as a share of all instructions (static count; the x86 columns fold size suffixes, `movl`/`movq` are `mov`, and count `callq`/`retq` as written by clang):

| rank | pdp64 | share | cum. | gcc -Os (x86-64) | share | cum. | clang -Os (x86-64) | share | cum. |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `movq` | 25.13% | 25.13% | `mov` | 32.76% | 32.76% | `mov` | 34.67% | 34.67% |
| 2 | `lea` | 11.42% | 36.55% | `cmp` | 7.83% | 40.59% | `callq` | 6.69% | 41.36% |
| 3 | `call` | 8.54% | 45.09% | `call` | 7.58% | 48.17% | `jne` | 6.22% | 47.58% |
| 4 | `movl` | 7.02% | 52.11% | `jne` | 6.03% | 54.20% | `cmp` | 5.55% | 53.13% |
| 5 | `cmp` | 6.51% | 58.62% | `xor` | 4.45% | 58.66% | `push` | 4.30% | 57.43% |
| 6 | `br` | 4.68% | 63.31% | `push` | 4.40% | 63.05% | `pop` | 4.23% | 61.67% |
| 7 | `beq` | 4.61% | 67.92% | `lea` | 4.22% | 67.27% | `add` | 3.93% | 65.60% |
| 8 | `movzb` | 3.54% | 71.46% | `pop` | 3.83% | 71.10% | `xor` | 3.92% | 69.52% |
| 9 | `clr` | 2.85% | 74.31% | `je` | 3.53% | 74.63% | `test` | 3.16% | 72.68% |
| 10 | `add` | 2.59% | 76.90% | `test` | 3.02% | 77.65% | `lea` | 3.03% | 75.70% |
| 11 | `tst` | 2.25% | 79.15% | `jmp` | 2.97% | 80.62% | `movups` | 2.76% | 78.47% |
| 12 | `bne` | 2.22% | 81.37% | `add` | 2.83% | 83.45% | `je` | 2.52% | 80.99% |
| 13 | `blt` | 1.93% | 83.30% | `inc` | 2.64% | 86.10% | `jmp` | 2.48% | 83.47% |
| 14 | `ret` | 1.82% | 85.12% | `ret` | 2.26% | 88.35% | `inc` | 2.39% | 85.86% |
| 15 | `movzl` | 1.49% | 86.62% | `sub` | 1.72% | 90.07% | `retq` | 1.97% | 87.83% |
| 16 | `shl` | 1.22% | 87.83% | `and` | 0.98% | 91.05% | `and` | 1.13% | 88.95% |
| 17 | `sub` | 1.11% | 88.95% | `imul` | 0.80% | 91.85% | `sub` | 1.07% | 90.02% |
| 18 | `and` | 1.09% | 90.04% | `movups` | 0.70% | 92.55% | `shr` | 0.80% | 90.81% |
| 19 | `shr` | 0.94% | 90.98% | `shr` | 0.63% | 93.18% | `imul` | 0.72% | 91.54% |
| 20 | `bis` | 0.86% | 91.83% | `movzbl` | 0.62% | 93.79% | `or` | 0.63% | 92.17% |
| 21 | `xor` | 0.85% | 92.68% | `or` | 0.50% | 94.29% | `movzbl` | 0.59% | 92.75% |
| 22 | `movb` | 0.83% | 93.51% | `sal` | 0.46% | 94.75% | `shl` | 0.49% | 93.24% |
| 23 | `push` | 0.78% | 94.29% | `rep movsb` | 0.44% | 95.19% | `movzwl` | 0.43% | 93.67% |
| 24 | `pop` | 0.74% | 95.03% | `ja` | 0.28% | 95.47% | `movaps` | 0.39% | 94.06% |
| 25 | `pushm` | 0.65% | 95.68% | `movslq` | 0.27% | 95.74% | `roll` | 0.35% | 94.41% |


Observations:

* `movq` and `movl` together are 32% of pdp64's instructions, against 33-35% for `mov` on x86; pdp64 splits them because narrow values need the sized forms (`movq` 25.2%, `movl` 7.0%). `lea` is 11.4% on pdp64 against 4.2% (gcc) and 3.0% (clang): it is how pdp64 adds a constant to a register without clobbering it, how it takes the address of a symbol or a local, and the way it indexes.
* The first 14 pdp64 mnemonics make up 85% of the code, the first 25 make up 96%. 68 of the 213 are used at all.
* gcc and clang use `push`/`pop` for 8.2-8.5% of their instructions (saving callee-saved registers one at a time); pdp64 uses `pushm`/`popm` once per function (1.3% of the instructions) and `push`/`pop` for 1.5%.
* x86 compares with `test`/`cmp` (9-11% together) and branches with `je`/`jne` and friends (10-12%); pdp64 has `cmp`/`tst` at 8.7% and conditional branches at 9.7% (it has no fused compare-and-branch; section 9).
* `xor reg,reg` is 4.2% of gcc's code (zeroing a register); pdp64 has `clr` for that (2.9%), two bytes.
* The multiply, divide and shift families are small on every machine (under 3% together), which is what the ISA argues.

### Instructions that are used (static counts, 827 files)

| mnemonic | group | count |
|---|---|---|
| movq | mov | 93024 |
| lea | lea | 42258 |
| call | sop | 31620 |
| movl | mov | 25970 |
| cmp | alu | 24100 |
| br | branch | 17333 |
| beq | branch | 17076 |
| movzb | movz | 13098 |
| clr | sop | 10558 |
| add | alu | 9593 |
| tst | sop | 8327 |
| bne | branch | 8206 |
| blt | branch | 7148 |
| ret | sys-none | 6739 |
| movzl | movz | 5530 |
| shl | alu | 4503 |
| sub | alu | 4123 |
| and | alu | 4046 |
| shr | alu | 3462 |
| bis | alu | 3171 |
| xor | alu | 3151 |
| movb | mov | 3055 |
| push | sop | 2894 |
| pop | sop | 2744 |
| popm | sop | 2393 |
| pushm | sop | 2393 |
| mul | alu | 2204 |
| movzw | movz | 1552 |
| inc | sop | 941 |
| movw | mov | 886 |
| bcs | branch | 855 |
| bcc | branch | 738 |
| jmp | sop | 646 |
| asl | sop | 640 |
| blos | branch | 521 |
| bge | branch | 502 |
| dec | sop | 482 |
| sar | alu | 462 |
| calli | xfer | 451 |
| neg | sop | 440 |
| ble | branch | 407 |
| com | sop | 383 |
| bhi | branch | 343 |
| rori | besc | 235 |
| bgt | branch | 222 |
| mcpy | mblk | 154 |
| div | aesc | 110 |
| fcmp | alu | 99 |
| fcvtqd | fesc | 52 |
| mod | aesc | 44 |
| modu | aesc | 42 |
| divu | aesc | 39 |
| fcvtsd | fesc | 21 |
| fcvtdq | fesc | 18 |
| bpl | branch | 16 |
| fmul | alu | 14 |
| asr | sop | 13 |
| fadd | alu | 11 |
| fadd32 | fesc | 11 |
| fcvtls | fesc | 11 |
| fdiv | fesc | 10 |
| fcvtds | fesc | 7 |
| fsub | alu | 7 |
| fmul32 | fesc | 4 |
| fneg | fesc | 3 |
| fcmp32 | fesc | 2 |
| fcvtqud | fesc | 1 |
| fcvtsl | fesc | 1 |


### Instructions that are never emitted, and why

145 of the 213 mnemonics do not occur in the output. This is what C compiled by this back end looks like, not what the machine can do: most of the zeros are instructions a compiler emits only from an intrinsic, a library call, system code or an idiom pass that is not written.

| why it is not emitted | instructions |
|---|---|
| system code: privileged or system-level, from assembly or inline asm in an operating system, not from C | `bpt`, `fence`, `halt`, `icinv`, `icinva`, `lpad`, `mfasid`, `mfcpuid`, `mfdp`, `mfps`, `mtasid`, `mtdmw`, `mtdp`, `mtps`, `prober`, `probew`, `rti`, `rtt`, `sev`, `spl`, `tlbi`, `tlbia`, `tlbsync`, `trap`, `trapl`, `wfe` |
| intrinsic: __sync_* and __atomic_* builtins, not implemented in the back end; ATOM is not assembled yet | `cas`, `casdb`, `ll`, `sc`, `swap`, `swapdb`, `xadd`, `xadddb`, `xand`, `xanddb`, `xmax`, `xmaxdb`, `xmaxu`, `xmaxudb`, `xmin`, `xmindb`, `xminu`, `xminudb`, `xor_`, `xor_db`, `xxor`, `xxordb` |
| libm builtins and fenv: sqrt, fma, rint, copysign, fmin/fmax and the exception flags are library calls or intrinsics; contraction a*b+c to fma is not done | `fclass`, `fclass32`, `fcopysign`, `fmadd`, `fmadd32`, `fmax`, `fmin`, `fmsub`, `fmsub32`, `fnmadd`, `fnmadd32`, `fnmsub`, `fnmsub32`, `frint`, `frinta`, `frintm`, `frintp`, `frintz`, `fsflags`, `fsqrt`, `fsqrt32` |
| intrinsic: __builtin_clz, ctz, popcount, bswap; no C operator (an idiom pass could find bswap and popcount loops; gcc and clang do) | `bitrev`, `bswap`, `bswapl`, `bswapw`, `clo`, `clz`, `cto`, `ctz`, `popcnt` |
| binary16: no C type for it (_Float16 is not accepted by this pcc) | `fadd16`, `fcmp16`, `fcvths`, `fcvtsh`, `fdiv16`, `fmadd16`, `fmul16`, `fsqrt16`, `fsub16` |
| binary16: no C type for it here | `fclass16`, `fcvtdh`, `fcvthd`, `fcvthl`, `fcvtlh`, `fmsub16`, `fnmadd16`, `fnmsub16` |
| intrinsic only (population-count dot products, carry-less multiply, UTF-8) | `clmulh`, `clmull`, `utf8dec`, `utf8enc`, `utf8len`, `xnorpop` |
| library: memmove, memset, memcmp, memchr, strchr live in libc; the compiler emits mcpy for small struct copies only | `mcmp`, `mmov`, `mscn`, `mscnn`, `mset`, `mval` |
| idiom: x<0?-x:x and a<b?a:b; a shared pass-1 or middle-end change (not done) | `abs`, `max`, `maxu`, `min`, `minu` |
| MESC (not assembled): x op= y on a 64-bit object in memory; pcc has the path (FINDMOPS), the table does not use it yet | `addm`, `bicm`, `bism`, `subm` |
| intrinsic: explicit unaligned accesses; the compiler uses byte copies for packed structs | `movub`, `movul`, `movuq`, `movuw` |
| language: tagged pointers (a dynamic-language runtime, not C) | `bntag`, `btag`, `jtag` |
| idiom: bit-field extract and insert; pcc reads fields with shifts (the FIELDOPS path is not used) | `extb`, `extzb`, `insb` |
| multi-word arithmetic: needs a long-long or bignum lowering; the machine has 64-bit registers so C code does not need it | `adc`, `sbc` |
| idiom: x & ~y and a mask test; the compiler uses and with the complemented constant and and+tst | `bic`, `bit` |
| overflow tests: __builtin_*_overflow (not implemented) | `bvc`, `bvs` |
| float arithmetic is rare in the corpus (no instance of float division or subtraction); the instructions are used (fadd32, fmul32) where float code occurs | `fdiv32`, `fsub32` |
| idiom: divide by a constant (multiply by a reciprocal) and 128-bit arithmetic; pcc does not do the division strength reduction | `mulh`, `mulhu` |
| used only after floating-point compares | `bmi` |
| intrinsic or idiom: funnel shift (128-bit shifts, bignum) | `dshr` |
| fabs: libm builtin (fabs); fneg is used | `fabs` |
| double to unsigned 64-bit: the corpus converts to unsigned long once, through fcvtqud/fcvtdq; rare in C that is not numeric | `fcvtdqu` |
| idiom: a switch as a jump table (JMPI table(pc)(r*8)); equal in bytes to a compare chain below ~8 cases because the table entries are 8 bytes | `jmpi` |
| padding only: the assembler inserts it for .even; the compiler never asks | `nop` |
| idiom or intrinsic: rotate by a register count; rotates by a constant are emitted (as rol, which assembles to rori) for 64-bit values only: a 32-bit rotate has no instruction and is shl/shr/bis | `ror` |
| idiom: a comparison used as a value; pass 1 turns it into branches before pass 2 sees it (a shared change) | `set` |
| idiom: a counted loop (dec; bne); pcc does not choose it (same size, one instruction fewer) | `sob` |


## 5. Operand forms and addressing modes

Every operand of every instruction, by form (static count; "pcrel" includes the target of every branch and call as well as pc-relative data; "index" is `d(rb)(rx*s)`):

| operand form | operands | share | in 2-byte instr. | 4 | 6 | 8 |
|---|---|---|---|---|---|---|
| reg | 351023 | 57.6% | 183138 | 149075 | 18761 | 49 |
| pcrel | 107102 | 17.6% | 48044 | 22503 | 36555 | 0 |
| base | 81244 | 13.3% | 0 | 79954 | 1290 | 0 |
| imm | 57984 | 9.5% | 0 | 54890 | 3045 | 49 |
| index | 11730 | 1.9% | 0 | 11306 | 424 | 0 |
| abs | 1 | 0.0% | 0 | 1 | 0 | 0 |


For x86 (AT&T operands of the same files; "target" is a branch or call target, "rip" is `sym(%rip)`):

| form | gcc -Os operands | share | clang -Os operands | share |
|---|---|---|---|---|
| reg | 272262 | 60.1% | 309628 | 61.5% |
| imm | 52118 | 11.5% | 56242 | 11.2% |
| mem-base | 58954 | 13.0% | 59618 | 11.8% |
| mem-index | 3816 | 0.8% | 4888 | 1.0% |
| rip | 5202 | 1.1% | 13376 | 2.7% |
| target | 60943 | 13.4% | 59577 | 11.8% |
| sym | 11 | 0.0% | 0 | 0% |

* Register operands are 58% of pdp64's operands and 60-61% of x86's; immediates are 9.5% against 11.5%; memory operands (base + index) are 15% on both.
* Post-increment and pre-decrement are **never** used: the compiler does not emit them (the `AUTOINC` path of pcc is not enabled for pdp64; in an earlier output of the same compiler about 440 of the 10,500 `lea n(rX),rX` sat next to a dereference through the same register, so at most 0.1% of the code would change).
* Absolute addressing (`@n`) appears once. `d(dp)` and `d(pc)` as a base register of data are used only as pc-relative references.
* The 6-byte instructions: 36555 of the 41314 are a pc-relative operand to another section or an external symbol (`call` 22221, `lea sym,r` 12825).

The 6- and 8-byte forms, by mnemonic and operand form:

| rank | bytes, mnemonic, operand forms | count |
|---|---|---|
| 1 | `6 call pcrel` | 22176 |
| 2 | `6 lea pcrel,reg` | 12825 |
| 3 | `6 and imm,reg` | 1091 |
| 4 | `6 cmp reg,imm` | 641 |
| 5 | `6 movq imm,reg` | 559 |
| 6 | `6 add imm,reg` | 544 |
| 7 | `6 movq pcrel,reg` | 377 |
| 8 | `6 movl base,reg` | 371 |
| 9 | `6 jmp pcrel` | 285 |
| 10 | `6 movl pcrel,reg` | 264 |
| 11 | `6 movq base,reg` | 234 |
| 12 | `6 movl reg,base` | 183 |
| 13 | `6 movq reg,base` | 179 |
| 14 | `6 movl reg,pcrel` | 144 |
| 15 | `6 movq reg,pcrel` | 137 |


## 6. Instruction pairs and triples

The 20 most frequent mnemonic-and-operand-form pairs in pdp64 output (static count; x86 for comparison below):

| rank | mnemonic, operand forms | count | share of instructions |
|---|---|---|---|
| 1 | `movq reg,reg` | 46263 | 12.50% |
| 2 | `call pcrel` | 31588 | 8.53% |
| 3 | `lea base,reg` | 22237 | 6.01% |
| 4 | `lea pcrel,reg` | 20017 | 5.41% |
| 5 | `movq base,reg` | 19803 | 5.35% |
| 6 | `cmp reg,imm` | 18787 | 5.08% |
| 7 | `movq imm,reg` | 18200 | 4.92% |
| 8 | `br pcrel` | 17333 | 4.68% |
| 9 | `beq pcrel` | 17076 | 4.61% |
| 10 | `movl base,reg` | 14612 | 3.95% |
| 11 | `clr reg` | 9568 | 2.59% |
| 12 | `movzb index,reg` | 8779 | 2.37% |
| 13 | `tst reg` | 8327 | 2.25% |
| 14 | `bne pcrel` | 8206 | 2.22% |
| 15 | `movq reg,base` | 7576 | 2.05% |
| 16 | `blt pcrel` | 7148 | 1.93% |
| 17 | `ret ` | 6739 | 1.82% |
| 18 | `add reg,reg` | 6462 | 1.75% |
| 19 | `movl reg,base` | 6021 | 1.63% |
| 20 | `cmp reg,reg` | 4702 | 1.27% |


The same for gcc -Os on amd64:

| rank | mnemonic, operand forms | count | share |
|---|---|---|---|
| 1 | `mov reg,reg` | 32938 | 11.67% |
| 2 | `call target` | 21407 | 7.58% |
| 3 | `mov mem-base,reg` | 20978 | 7.43% |
| 4 | `mov imm,reg` | 20646 | 7.31% |
| 5 | `jne target` | 17020 | 6.03% |
| 6 | `push reg` | 11936 | 4.23% |
| 7 | `xor reg,reg` | 11799 | 4.18% |
| 8 | `mov reg,mem-base` | 11573 | 4.10% |
| 9 | `pop reg` | 10804 | 3.83% |
| 10 | `cmp imm,reg` | 10355 | 3.67% |
| 11 | `lea mem-base,reg` | 10139 | 3.59% |
| 12 | `je target` | 9965 | 3.53% |
| 13 | `jmp target` | 8379 | 2.97% |
| 14 | `test reg,reg` | 7943 | 2.81% |
| 15 | `inc reg` | 7336 | 2.60% |


The most frequent adjacent instructions in the pdp64 output (labels between instructions are ignored, so a pair can straddle a basic block boundary; calls to the same function repeated thousands of times in a few test files inflate several rows):

| rank | adjacent pair | count | share of instructions |
|---|---|---|---|
| 1 | `movq reg,reg ; call pcrel` | 11114 | 3.00% |
| 2 | `movq reg,reg ; movq reg,reg` | 9726 | 2.63% |
| 3 | `cmp reg,imm ; beq pcrel` | 8625 | 2.33% |
| 4 | `call pcrel ; lea base,reg` | 8468 | 2.29% |
| 5 | `br pcrel ; lea pcrel,reg` | 7112 | 1.92% |
| 6 | `lea pcrel,reg ; movq reg,reg` | 6948 | 1.88% |
| 7 | `cmp reg,imm ; blt pcrel` | 6578 | 1.78% |
| 8 | `beq pcrel ; call pcrel` | 6446 | 1.74% |
| 9 | `movq reg,reg ; movzb index,reg` | 6148 | 1.66% |
| 10 | `call pcrel ; movq reg,reg` | 5406 | 1.46% |
| 11 | `lea pcrel,reg ; movq imm,reg` | 5153 | 1.39% |
| 12 | `lea base,reg ; cmp reg,imm` | 4530 | 1.22% |
| 13 | `movzb index,reg ; cmp reg,imm` | 4144 | 1.12% |
| 14 | `blt pcrel ; br pcrel` | 4117 | 1.11% |
| 15 | `lea base,reg ; movq reg,reg` | 4076 | 1.10% |
| 16 | `movq base,reg ; movq base,reg` | 3886 | 1.05% |
| 17 | `tst reg ; bne pcrel` | 3875 | 1.05% |
| 18 | `tst reg ; beq pcrel` | 3841 | 1.04% |
| 19 | `movq imm,reg ; call pcrel` | 3771 | 1.02% |
| 20 | `movq imm,reg ; movq reg,reg` | 3478 | 0.94% |
| 21 | `beq pcrel ; cmp reg,imm` | 3347 | 0.90% |
| 22 | `clr reg ; br pcrel` | 3345 | 0.90% |
| 23 | `movq imm,reg ; br pcrel` | 3305 | 0.89% |
| 24 | `call pcrel ; tst reg` | 3222 | 0.87% |
| 25 | `call pcrel ; clr reg` | 2850 | 0.77% |


and the most frequent three in a row:

| rank | three in a row | count |
|---|---|---|
| 1 | `beq pcrel ; call pcrel ; lea base,reg` | 6157 |
| 2 | `lea pcrel,reg ; movq reg,reg ; movzb index,reg` | 6144 |
| 3 | `lea base,reg ; cmp reg,imm ; blt pcrel` | 4380 |
| 4 | `cmp reg,imm ; beq pcrel ; call pcrel` | 4231 |
| 5 | `br pcrel ; lea pcrel,reg ; movq reg,reg` | 4196 |
| 6 | `call pcrel ; lea base,reg ; cmp reg,imm` | 4187 |
| 7 | `movzb index,reg ; cmp reg,imm ; beq pcrel` | 4103 |
| 8 | `cmp reg,imm ; blt pcrel ; br pcrel` | 4099 |
| 9 | `movq reg,reg ; movzb index,reg ; cmp reg,imm` | 4096 |
| 10 | `blt pcrel ; br pcrel ; lea pcrel,reg` | 4096 |
| 11 | `movq reg,reg ; movq reg,reg ; movq reg,reg` | 3432 |
| 12 | `movq reg,reg ; movq reg,reg ; call pcrel` | 3315 |
| 13 | `movq reg,reg ; call pcrel ; movq reg,reg` | 3222 |
| 14 | `cmp reg,imm ; beq pcrel ; cmp reg,imm` | 3148 |


What the pairs suggest (the sections after this one price them):

* **Compare and branch** (`cmp`/`tst` followed by a conditional branch) is 32427 pairs, 8.8% of all instructions. There is no fused instruction.
* **Argument set-up** (`movq reg,reg ; call`, `lea ... ; call`) is the largest group after that: a call is often preceded by one to three moves of arguments into `r0`-`r5`.
* **A narrow load followed by a compare with a constant** (`movzb ...; cmp r,#n`): 4997 sites. The compare cannot take the narrow operand because ALU operands in memory are always 64-bit (decision, errata 28) and an instruction has at most one memory operand, which would also have to hold the constant.
* **`lea sym,r ; movq r,r`** and **`movq imm,r`** are address and constant materialisation: the cost of a machine with no 64-bit immediate and with pc-relative data.

## 7. Where the bytes go

Every instruction of the 827 files in one cost centre (static; "frame" is `push fp`/`movq sp,fp`/`pushm`/`popm`/`sub`/`add` on `sp` and the other frame set-up; "constant" is `clr r` and `movq #n,r`; "address-of-symbol-N" is `lea sym,r` in an N-byte encoding, 6 when the symbol is in another section; "re-extension" is `movl r,r` and the like on the same register; "call-external" is a 6-byte `call`, i.e. to another section or an undefined symbol):

| cost centre | instructions | share | bytes | share of instruction bytes |
|---|---|---|---|---|
| load-store | 67481 | 18.2% | 273186 | 22.0% |
| alu-other | 48449 | 13.1% | 160118 | 12.9% |
| call-external | 22231 | 6.0% | 133386 | 10.7% |
| branch | 53367 | 14.4% | 117380 | 9.4% |
| compare | 32528 | 8.8% | 105228 | 8.5% |
| constant | 28758 | 7.8% | 97132 | 7.8% |
| register-move | 46223 | 12.5% | 92446 | 7.4% |
| address-of-symbol-6 | 12825 | 3.5% | 76950 | 6.2% |
| frame | 14077 | 3.8% | 44952 | 3.6% |
| call-near | 9840 | 2.7% | 39360 | 3.2% |
| shift | 9080 | 2.5% | 33846 | 2.7% |
| address-of-symbol-4 | 7192 | 1.9% | 28768 | 2.3% |
| ret | 6739 | 1.8% | 13478 | 1.1% |
| re-extension | 5768 | 1.6% | 11536 | 0.9% |
| extension-other | 4061 | 1.1% | 8122 | 0.7% |
| global-access-6 | 1138 | 0.3% | 6828 | 0.5% |
| global-access-4 | 204 | 0.1% | 816 | 0.1% |
| block-move | 154 | 0.0% | 616 | 0.0% |


Reading the table:

* **Cross-section references.** `call-external` plus the 6-byte `address-of-symbol` and `global-access` forms are 36555 instructions and cost 73110 bytes more than the 4-byte forms would (4.4% of the image). `as64` resolves a pc-relative reference inside a section itself (4 bytes) but must emit a 32-bit relocation for anything else (6 bytes); the compiler already keeps strings and constants in `.text` for this reason (that change alone cut the 6-byte `lea` count by a third), but cannot do anything about external functions and writable data.
* **Frame and return** are 4.7% of the instruction bytes. With no frame pointer a function that saves callee-saved registers costs `pushm` + `sub` + `add` + `popm` + `ret` = 18 bytes; with a frame pointer it was 24.
* **Re-extension** (`movl r,r`) is 0.9% of the bytes. Before this round's policy change it was 4.3% of the instructions.
* **Constants** are 7.8% of the instruction bytes: `movq #n,r` is 4 bytes for 16-bit values and 6 or 8 above, and there is no shorter form.
* **Compare** (`cmp`/`tst`) 8.5%, **branch** 9.4%: together a fifth of the bytes.
* **Block moves** are negligible in C: 154 `mcpy` in the whole corpus (the compiler uses it only for struct copies of three or more words).
* The loads and stores are the largest group, 22.0% of the instruction bytes, and nearly all are 4 bytes: any memory operand costs a second parcel, which is the encoding's central trade (section 9 prices a short form).

### Where the image is not code

The image is 1672166 bytes in the 827 files; the instructions are 1244148 of them (74%). The rest is data and read-only data, which is the same for the three ISAs apart from alignment and the width of pointers (64 bits in all three).

## 8. Compiler conventions that shape the numbers

* **Re-extension.** A 32-bit `int` or `unsigned` is kept sign-extended in a 64-bit register, because the ALU is 64-bit only (decision, errata 28: no sized ALU operations). A signed `int` result needs no re-extension, since signed overflow is undefined; an unsigned result does (it wraps at 32 bits), and so does a left shift, which pass 1 uses to read bit-fields. `peep.h` then removes an extension whose register is read only through its low 32 bits: the demand analysis follows a value through `add`, `sub`, `and`, `bis`, `xor`, `mul`, `shl`, moves and narrow stores. The tests that pin the policy are `tests/c/extend.c` and the `a64tests` set (all 498 runs pass).
* **Frame.** With `-xdmr` the frame has no frame pointer: the callee-saved registers are saved with `pushm` (`push` for one), locals and the outgoing argument area are addressed from `sp`, and nothing is pushed or popped around a call because the arguments beyond the sixth are stored into a preallocated area at `0(sp)`. A tail call (`call f; ret`) becomes `jmp f` when no address of the frame may have been passed.
* **Constants and strings** are in `.text` (a pc-relative reference within a section is 4 bytes). Odd-sized read-only objects go to `.data`.
* **Calls** to a function defined in the same file are 4 bytes; every other call is 6.
* **Comparisons as values** become compare, branch, load 1, branch, clear. pdp64's `set cc,rd` is not used because pass 1 turns the comparison into branches before pass 2 sees it.

## 9. What the instruction set could gain, priced

Each item is the count of sites in the 827 files where the pattern occurs in the *actual* pdp64 output, times the bytes a hypothetical instruction would save. They are static estimates of image size, assuming the new instruction does exactly the job described and the encoding is as stated; none is an instruction proposal by itself.

| pattern in the pdp64 output | sites | estimated bytes saved |
|---|---|---|
| narrow load; cmp reg,#imm (a sized compare with memory) | 4997 | n/a |
| movl mem,r; op: a 32-bit load fused into the operation | 4690 | n/a |
| immediate beyond 16 bits (a 6- or 8-byte instruction) | 3094 | 6286 |
| movzl r,r; shr #n,r (extzb) | 2112 | n/a |
| rotate left by a constant: shl, shr, bis (32/64-bit) | 898 | n/a |
| set cc,rd (a comparison as a value) | 561 | 4488 |
| inc/dec on a quad in memory | 468 | 2808 |
| read-modify-write of a 32-bit int in memory (needs sized operands) | 434 | 2604 |
| addm/subm/bism/bicm (MESC read-modify-write, quad) | 265 | 1590 |
| divide or remainder by a constant (mulh, shifts) | 137 | n/a |
| min/max/minu/maxu ra,rb,rd | 82 | 328 |
| and/xor on a quad in memory (no memory-destination form) | 55 | n/a |
| abs rs,rd | 6 | 24 |
| shl #a; shr/sar #b (a bit-field extract: extb/extzb) | 4 | n/a |


and from the operand statistics:

| idea | evidence (static count in the output) | estimated saving |
|---|---|---|
| A 2-byte load/store with a register-deferred operand `(rN)` (PDP-11 mode 1) | 12941 loads and stores use `0(rN)` as the whole operand | 2 bytes each = 25882 bytes, 1.5% of the image |
| A 2-byte load/store of a quad at a small multiple of 8 from `sp` (the d6(sp) form the ISA mentions) | 11928 quad loads and stores at `d(sp)` with 0 <= d < 512 and d a multiple of 8 | 2 bytes each = 23856 bytes, 1.4% |
| Compare-register-with-5-bit-immediate-and-branch in 4 bytes | 18787 `cmp r,#imm ; bCC` pairs, of which 6390 have the immediate in -16..15 and 12832 in -128..127 | 2 bytes and 1 instruction each for the first group = 12780 bytes (0.8%) |
| `tst r ; bCC` fused (compare with zero and branch) | 8327 pairs | 1 instruction each; the bytes are equal (2 + 2) |
| 32-bit rotate by a constant (`rol32 rs,#n,rd`) | 896 rotates in the output, each now 5 instructions and about 14 bytes (`mov`, `shl`, `movzl`, `shr`, `bis`) | about 10 bytes and 4 instructions each = 8960 bytes (0.5%); the SHA-1, MD5, SHA-256 and RIPEMD-160 files, the worst in the corpus (1.7-2.3x gcc), spend a third of their code on these |
| Linker relaxation or a 16-bit section-relative relocation, so that an external `call` or `lea sym` is 4 bytes when it is in range | 36555 six-byte pc-relative forms | 2 bytes each = 73110 bytes, 4.4%. By far the largest single item |
| Sized ALU memory operands (the decision of errata 28 refuses these) | `movl mem,r ; op` 4690 sites; `narrow load ; cmp r,#imm` 4997 sites (these need two operands in memory/immediate and would not fit anyway) | about 2 bytes each for the first group = 9380 bytes (0.6%): supports the decision |

## 10. Conclusions

What the data supports:

1. **The instruction set is dense.** pdp64 averages 3.36 bytes per instruction against 3.66 (gcc) and 3.78 (clang) on x86-64, with 43% of instructions in 2 bytes. It needs more instructions than x86 for the same C (1.31 of gcc, 1.21 of clang), mostly because it has no fused compare-and-branch, no sized ALU operands, no 64-bit immediate and no auto-increment in use, and takes 6 bytes for external references. The two effects nearly cancel: the code is 0.99 of clang's and 1.05 of gcc's size on the libraries.
2. **Instructions that earn their slot** (high static counts, no substitute): `movq`, `lea`, `call`, `movl`, `cmp`, the conditional branches and `br`, `movzb`/`movzl`/`movzw`, `clr`, `tst`, `add`, `sub`, `and`, `bis`, `xor`, `shl`, `shr`, `mul`, `ret`, `pushm`/`popm`, `inc`/`dec`, `asl`/`asr`, `neg`/`com`, `mcpy`, `div`/`mod`. `lea` alone is a tenth of the code.
3. **Instructions that the compiler does not need but that the system does**: the system, atomic and TLB words (system code); `clz`, `ctz`, `popcnt`, `bswap`, `ror` (idioms and intrinsics); the string and block words (libc); the UTF-8 and carry-less multiply words (intrinsics). Their absence from compiled C is expected and says nothing about their value; the claim in the README that dedicated `abs`, `min` and `max` are worth under a tenth of a percent of code is supported (82 sites for `min`/`max` and 6 for `abs` in 827 files).
4. **`set cc,rd` is worth little** in code size: 561 sites, about 4488 bytes (0.27%). Its value is the instruction count of the `x = a < b` idiom (5 instructions become 2), not bytes.
5. **Auto-increment** (`(rN)+`, `-(rN)`) has almost no sites in compiled C here (the pcc front end rarely forms them; at most 0.1% of the code): on this evidence its place in the instruction set is for assembly and for loops over arrays in hand-written code.
6. **`addm`/`subm`/`bicm`/`bism`** (MESC): 265 sites of 64-bit read-modify-write of memory in 827 files, about 1590 bytes. The `int` case (32-bit), which is the common one in C, is 434 sites and cannot use them.
7. **What the data suggests adding or changing**, in order of size: (a) a linker or assembler mechanism for 4-byte external references (4.4% of the image); (b) a 2-byte `(rN)` load/store (1.5%); (c) a 2-byte small-offset `sp` load/store (1.4%); (d) a 32-bit rotate (0.5% overall, much more in hash code); (e) a fused compare-immediate-and-branch (0.8% for the short immediates). Items (b) to (e) each need encoding space, which the ISA's reserved opcodes (`0x28`-`0x2F`) can supply.
8. **What compiler work (not ISA work) would help most**: keeping struct members in registers (the worst files are those whose local state is a struct that pcc leaves in memory); a 32-bit-rotate pattern; `inc`/`dec` and `set` once the shared pass-1 hook exists; the frame-less leaf is already done.

## 11. Reproducing

```
tools/build-pcc.sh                      # build/pcc/ccom from ~/claude/pcc
tools/pdp64size.sh --set fair --arch pdp64,amd64,gcc-Os,clang-Os --out DIR --keep DIR/s
# tables: DIR/results.json holds every figure above per file; docs/codegen-data/ holds the aggregated CSV files;
# tools/codegen/*.py rebuild them (see the list in section 1)
```

The static counts of the candidate sequences (section 9) come from regular-expression scans of the kept `.s` files, so a site is counted only if the instructions are literally adjacent in the output.
