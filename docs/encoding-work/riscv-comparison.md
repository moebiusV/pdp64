# RISC-V against pdp64/32: static size of the corpus, measured the same way

Measured 2026-11-10. Nothing in pcc, `main` or the manual was changed; scripts in `tools/riscv-compare/`, raw results in `docs/encoding-work/riscv-data/`. The question (the author): how many bytes and instructions does RISC-V need for the code that pdp64/32 compiles, at a comparable level of optimization.

## 0. Summary

* **Measured**: the static size (instruction count and instruction bytes; constant pools and alignment padding not counted) of the 841-file corpus of `integration.md`, compiled by **pcc for pdp64/32** (the numbers of `integration.md`, reproduced here byte for byte), **pcc for amd64 and i386** (the only other pcc back ends that compile the corpus completely), and **clang 21 for RISC-V (rv64gc and rv64g), AArch64, x86-64, i386, Arm (A32, T32) and MIPS64** at -O0, -O1, -O2, -O3 and -Os (-O0 for RISC-V only; Arm and MIPS64 at -O2 and -Os).
* **pcc against pcc (same front end, same optimizer, same files)**: pcc amd64 needs **1.43 times the instruction bytes and 1.33 times the instructions** of pdp64/32 with the flags the project uses for amd64, or 1.37 and 1.29 with the flag set of pdp64/32 (`-xccp -xtailcall`, no `-xssa`); pcc i386 needs 1.39 and 1.52 (1.34 and 1.46). This is the apples-to-apples row that exists.
* **pcc has no working RISC-V back end** (section 9): `arch/riscv` is an unfinished 32-bit port (`long` and pointers are 32 bits, `long long` is a register pair, the output is not accepted by an assembler as written, a recursive function overwrites its caller's frame). Making it compile the corpus and run the six programs is a port, not a fix: about 2,000 to 2,500 of its 5,591 lines to rewrite, estimated at 20 to 40 agent-hours for the corpus and as much again for the programs (9.3). I stopped there, as instructed.
* **clang for RISC-V against pcc for pdp64/32**. pcc has one optimization level, `-O` (section 2), whose nearest clang levels are -O1 and -Os. rv64gc -Os needs **1.22 times the instruction bytes and 1.36 times the instructions**; rv64gc -O1 1.35 and 1.49; -O2 1.76 and 1.81; -O3 2.60 and 2.52; -O0 2.27 and 2.32. Without the C extension (rv64g, every instruction 4 bytes): -Os 1.66 and 1.35; -O1 1.84 and 1.49. 53.5% of the instructions of rv64gc -Os are 2-byte compressed ones.
* **Compiler and architecture are mixed in every clang ratio.** pcc's optimizer is weaker than clang's at the same level and the pdp64 back end carries target passes written for this project (`doc/PDP64-OPT.md`). The clang rows say what a mature optimizer gets from RISC-V; they do not say what pcc would get. The same clang gives x86-64 -Os 1.21 times the pdp64/32 bytes and 1.04 times the instructions, AArch64 -Os 1.34 and 1.09, Arm Thumb-2 -Os 0.91 and 1.35.
* **Dynamic counts (instructions executed, bytes fetched) for the six programs were not made** (section 8): the mains, the stand-in libc and the crt of the pdp64 runs are not on this machine, the installed `qemu-riscv64` has no plugin interface, and the installed LLVM has no RISC-V linker. Static results only.

## 1. What was measured and how

Per file and configuration: compile the preprocessed file to an object (pcc: `ccom` to assembly, then assemble), then

* **instructions** and **instruction bytes**: pdp64/32: the statistics line of `as64 --stats` (`N instructions, B bytes`), as `tools/pdp64size.py` does; every other architecture: `llvm-objdump -d` of the object, an instruction's length being the distance to the next listing line; nop padding and data words in `.text` are recognised and left out (`objstat.py`);
* **.text bytes**: the size of the `.text` section of the object (pdp64: instructions + constant pools + padding);
* for RISC-V, the number of `R_RISCV_CALL` relocations (unrelaxed `auipc`+`jalr` pairs), for the estimate of 5.3.

Ratios are the configuration divided by pdp64/32 **on the files both compiled**. pcc compiles all 841 on pdp64, amd64 and i386. clang compiles 840 for RISC-V and AArch64 (`651.i`, `gcc.c-torture/execute/pr60003.c`: `__builtin_longjmp` is not supported there), 840 for i386 (`506.i`, c-testsuite `00220.c`: an array initializer error), 841 for x86-64 and Arm, 822 and 823 for MIPS64.

## 2. The pdp64 numbers: what they were measured on

The work files of `integration.md` (`scratchpad/int/corp.py`, `corpus.py`, `runtm.py`, ...) are not on this machine. I re-derived the measurement from the repository and the pcc tree and **reproduced it exactly**:

| | integration.md | here |
|---|---:|---:|
| pdp64/32, instruction bytes, 841 files | 964,158 | **964,158** |
| pdp64/16, instruction bytes | 934,470 | **934,470** |
| pdp64/32, instructions | 296,070 | 296,082 |
| pdp64/16, instructions | 300,821 | 300,820 |
| pdp64/32, `.text` of the objects | 1,197,018 | 1,197,088 |

(Instruction counts differ by 12 and 1, and `.text` by 70 bytes, probably the assembler's expansion of far `cbCC` into `cmp`+`bCC`, which the statistics line counts and the report may not; the instruction bytes agree to the byte, so I take the file set, the flags and the counting method to be the same.)

* **The 841 files** are the "fair" set of `tools/pdp64size.py`: the files that `tools/corpus.py` compiles with `ours -O` for aarch64, amd64 and i386 alike (from `/tmp/co-final/results.jsonl`, 900 files of 12 corpora minus the failures). By corpus: bearssl 294, c-testsuite 213, gcc-torture 169 (every 8th execute test), mbedtls 101, lua 34, zlib 15, chibicc 8, lz4 5, cjson 2. List: `tools/riscv-compare/fair.txt`.
* **Preprocessing** (`prep.py`, as `pdp64size.py`'s `preprocess`): `gcc -E -P -undef -nostdinc -std=gnu99 -D__STDC_VERSION__=199901L -D__STDC_HOSTED__=1`, the corpus's `-I` and `-D`, the **musl headers of aarch64** (`~/claude/corpora/sysroot/aarch64/include`) with `-D__aarch64__ -D__LP64__ -D_LP64`: pdp64 is LP64, little-endian, signed `char`, and takes aarch64's text. For the other architectures the same command with their own musl headers and architecture defines (the `ARCH` table of `corpus.py`).
* **Compiler and flags**: pcc `enc-prefix` as of `integration.md` (`~/claude/pcc-enc`; it is a copy of the files, its git metadata is gone; `mip/optim2.c` is of 2026-11-04 12:06 and the test `ccp_signedness.c` for the `-xccp` fix is present), built as `tools/build-pcc.sh` does (`-DPDP64_REGS32` for /32), run as `ccom -m pdp64/32 in.i out.s`. **`-m pdp64/32` turns on by default `-xdmr -xtemps -xdeljumps -xinline -xdce -xtailcall -xccp`** (`pdp64_xdefaults`, `arch/pdp64/local2.c`) **and all the target's own passes** (`doc/PDP64-OPT.md`: the four fused pairs, availability, jump threading, `lea` folding, switch dispatch, auto-increment, sob, read-modify-write, bic, field insert, set-on-condition, min/max, multiply by `lea`, divide by power of two and by magic constant, jump tables, tail calls). **`-xssa` stays off.** (The older r20 numbers used `-xdmr -xtemps -xdeljumps -xinline -xdce`.)
* **Assembler**: `build/as64 -m pdp64/32 --stats`, the integrated one of the repository; the statistics are of the unrelaxed object.
* **Which pcc level this is**: the pcc driver maps `-O`, `-O1` and `-Os` to the same `Oflag=1` ("optimize for space only", `cc/cc/cc.c`); there is no -O2 or -O3 in pcc. `integration.md` 4 states the pdp64 compile as "all optimisations on by default". The nearest clang rows are therefore **-O1 and -Os**. -O0, -O2 and -O3 are given because they were asked for; -O2 and -O3 unroll and inline heavily (see `memcpy-a2.c` in 5.1).
* **How instructions are counted**: `as64` counts the instructions the machine executes; a **fused pair** (`movcall`, `popmret`, `popret`, `mov2`; 19,786 emitted in the corpus at /32) is **one** instruction. `llvm-objdump` counts the instructions of the RISC-V object: there is **no macro-op fusion** in the count (`lui`+`addi`, `slli`+`add` are two instructions); pseudo-instructions (`li`, `la`, `call`, `ret`, `mv`) count as what they expand to.

## 3. The other rows: compilers and flags

| row | compiler and flags |
|---|---|
| pdp64/32, pdp64/16 (pcc) | `ccom32 -m pdp64/32`, `ccom -m pdp64/16`, nothing else (section 2) |
| pcc amd64, project flags | the same pcc tree (same `mip`) built for `x86_64-unknown-linux`: `ccom -xdmr -xtemps -xdeljumps -xinline -xdce -xssa -xabs` on the x86-64 text, assembled by `gcc -m64 -c -x assembler`; these are the flags `tools/corpus.py` gives `ours -O` for amd64 (`-xssa` is on for amd64 and i386 there, off for aarch64) |
| pcc amd64, pdp64's flag set | `-xdmr -xtemps -xdeljumps -xinline -xdce -xccp -xtailcall -xabs` (no `-xssa`): the optimizer flags pdp64/32 turns on. `-xccp` is machine independent (`mip/optim2.c`); `-xtailcall` exists in pdp64's `peep.h` only and does nothing here; the other pdp64 passes have no counterpart in `arch/amd64` and `arch/i386` (which have their own peephole, `x86peep.h`) |
| pcc i386 | both flag sets without `-xabs`; assembled by `gcc -m32` |
| clang rv64gc, rv64g | `clang --target=riscv64-linux-gnu -march=rv64gc` (or `rv64g`) `-mabi=lp64d -fno-pic -std=gnu99 -w -fno-asynchronous-unwind-tables -fno-unwind-tables -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=int-conversion -Wno-error=incompatible-pointer-types -O0/-O1/-O2/-O3/-Os -c -x c` (clang 21.1.8; the `-Wno-error` flags because clang 21 rejects the old-style C of gcc-torture otherwise; `-mrelax`, clang's default, only matters at link time) |
| clang AArch64 | `--target=aarch64-linux-gnu -fno-pic` and the same common flags; -O1 -O2 -O3 -Os |
| clang x86-64, i386 | `--target=x86_64-linux-gnu` or `i386-linux-gnu -fno-pic -fcf-protection=none`; -O1 -O2 -O3 -Os |
| clang Arm | `--target=arm-linux-gnueabi -marm` (A32) and `-mthumb` (T32); -O2 -Os |
| clang MIPS64 | `--target=mips64-linux-gnuabi64 -fno-pic -mno-abicalls`; -O2 -Os; 18 and 19 files do not compile ("Cannot select GPRel", a limit of that flag combination) |

**No GCC rows.** There is no GCC for RISC-V on this machine (`riscv64-*-gcc` is absent from `/usr/bin` and from `corpora/gcc-cross`, which has pdp11 and vax); a build of GCC 14.2 and binutils 2.43.1 for `riscv64-unknown-elf` was started and stopped when the author dropped the GCC rows. The finished binutils half (GNU `as` and `ld` for RISC-V) served the probes of section 9.

## 4. Tools and scripts

`tools/riscv-compare/README.md` has the commands. `prep.py` (preprocess), `build-ccoms.sh` (pcc ccoms from scratch copies of the pcc tree), `pdp64-static.py` (the pdp64 numbers as `pdp64size.py`), `pcc-static.py` (pcc amd64 and i386), `ref-static.py` and `run-refs.py` (the clang matrix), `objstat.py` (objdump-based counting), `summarize.py` (tables), `rodata-cst.py`, `pcc-compile.py` and `diag-riscv-backend.sh` (section 9), `Makefile`. Raw results in `docs/encoding-work/riscv-data/`: `static-wide.csv` (one row per file; instructions and instruction bytes of every configuration), `static-summary.md` (the generated tables below), `pdp64-32-static.csv`, `pcc-riscv64-status-stock.tsv` and `pcc-riscv64-status-with-va_list.tsv`, `diag-output.txt`.

## 5. Results

### 5.0 Headline table

Instructions and instruction bytes are sums over the files each configuration compiled. "ratio" columns are the configuration over pdp64/32 on the files both compiled; the two "w/o memcpy-a2" columns leave out `memcpy-a2.c` (5.1). Padding (not counted) is the assembler's nop fill between functions. `.text` is the whole section: pdp64 includes its constant pools and padding, the others instructions and padding.

| configuration | files ok | instructions | instruction bytes | B/insn | insn ratio | bytes ratio | insn ratio w/o memcpy-a2 | bytes ratio w/o memcpy-a2 | padding bytes (not counted) | .text bytes | .text ratio |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| pdp64/32 (pcc) | 841 | 296,082 | 964,158 | 3.256 | 1.000 | 1.000 | 1.000 | 1.000 | 0 | 1,197,088 | 1.000 |
| pdp64/16 (pcc) | 841 | 300,820 | 934,470 | 3.106 | 1.016 | 0.969 | 1.021 | 0.958 | 0 | 1,167,454 | 0.975 |
| pcc amd64, project flags | 841 | 394,661 | 1,378,842 | 3.494 | 1.333 | 1.430 | 1.312 | 1.553 | 5,328 | 1,384,170 | 1.156 |
| pcc amd64, pdp64's flag set | 841 | 380,422 | 1,324,031 | 3.480 | 1.285 | 1.373 | 1.250 | 1.475 | 5,338 | 1,329,369 | 1.111 |
| pcc i386, project flags | 841 | 450,216 | 1,336,953 | 2.970 | 1.521 | 1.387 | 1.571 | 1.531 | 3,407 | 1,340,360 | 1.120 |
| pcc i386, pdp64's flag set | 841 | 432,219 | 1,290,989 | 2.987 | 1.460 | 1.339 | 1.493 | 1.466 | 3,415 | 1,294,404 | 1.081 |
| clang-aarch64-O1 | 840 | 359,316 | 1,437,264 | 4.000 | 1.214 | 1.491 | 1.188 | 1.551 | 0 | 1,437,264 | 1.201 |
| clang-aarch64-O2 | 840 | 530,502 | 2,122,008 | 4.000 | 1.792 | 2.201 | 1.248 | 1.630 | 0 | 2,122,008 | 1.773 |
| clang-aarch64-O3 | 840 | 682,452 | 2,729,808 | 4.000 | 2.305 | 2.831 | 1.466 | 1.915 | 0 | 2,729,808 | 2.281 |
| clang-aarch64-Os | 840 | 323,558 | 1,294,232 | 4.000 | 1.093 | 1.342 | 1.029 | 1.344 | 0 | 1,294,232 | 1.081 |
| clang-arm-a32-O2 | 841 | 474,372 | 1,899,484 | 4.004 | 1.602 | 1.970 | 1.343 | 1.757 | 0 | 1,911,296 | 1.597 |
| clang-arm-a32-Os | 841 | 333,182 | 1,334,628 | 4.006 | 1.125 | 1.384 | 1.117 | 1.462 | 0 | 1,345,948 | 1.124 |
| clang-arm-t32-O2 | 841 | 587,804 | 1,263,660 | 2.150 | 1.985 | 1.311 | 1.664 | 1.184 | 0 | 1,263,660 | 1.056 |
| clang-arm-t32-Os | 841 | 399,966 | 879,302 | 2.198 | 1.351 | 0.912 | 1.385 | 0.989 | 0 | 879,302 | 0.735 |
| clang-i386-O1 | 840 | 388,223 | 1,298,076 | 3.344 | 1.311 | 1.346 | 1.450 | 1.517 | 136,984 | 1,435,060 | 1.199 |
| clang-i386-O2 | 840 | 546,526 | 2,181,074 | 3.991 | 1.846 | 2.262 | 1.552 | 1.666 | 61,002 | 2,242,076 | 1.873 |
| clang-i386-O3 | 840 | 683,507 | 2,969,759 | 4.345 | 2.309 | 3.080 | 1.769 | 1.937 | 67,383 | 3,037,142 | 2.537 |
| clang-i386-Os | 840 | 352,948 | 1,162,536 | 3.294 | 1.192 | 1.206 | 1.291 | 1.316 | 0 | 1,162,536 | 0.971 |
| clang-mips64-O2 | 822 | 607,838 | 2,440,832 | 4.016 | 2.337 | 2.877 | 1.517 | 2.002 | 291,996 | 2,732,828 | 2.625 |
| clang-mips64-Os | 823 | 394,403 | 1,587,636 | 4.025 | 1.514 | 1.869 | 1.290 | 1.703 | 119,372 | 1,707,008 | 1.638 |
| clang-rv64g-O0 | 840 | 687,679 | 2,750,716 | 4.000 | 2.323 | 2.853 | 2.232 | 2.915 | 0 | 2,750,716 | 2.298 |
| clang-rv64g-O1 | 840 | 442,166 | 1,768,664 | 4.000 | 1.494 | 1.835 | 1.492 | 1.949 | 0 | 1,768,664 | 1.478 |
| clang-rv64g-O2 | 840 | 533,527 | 2,134,108 | 4.000 | 1.802 | 2.214 | 1.528 | 1.995 | 0 | 2,134,108 | 1.783 |
| clang-rv64g-O3 | 840 | 744,825 | 2,979,300 | 4.000 | 2.516 | 3.090 | 1.765 | 2.306 | 0 | 2,979,300 | 2.489 |
| clang-rv64g-Os | 840 | 400,604 | 1,602,416 | 4.000 | 1.353 | 1.662 | 1.311 | 1.712 | 0 | 1,602,416 | 1.339 |
| clang-rv64gc-O0 | 840 | 687,678 | 2,190,060 | 3.185 | 2.323 | 2.272 | 2.232 | 2.321 | 0 | 2,190,060 | 1.830 |
| clang-rv64gc-O1 | 840 | 442,417 | 1,302,946 | 2.945 | 1.494 | 1.351 | 1.493 | 1.422 | 0 | 1,302,946 | 1.088 |
| clang-rv64gc-O2 | 840 | 534,464 | 1,699,782 | 3.180 | 1.805 | 1.763 | 1.532 | 1.471 | 0 | 1,699,782 | 1.420 |
| clang-rv64gc-O3 | 840 | 745,776 | 2,508,016 | 3.363 | 2.519 | 2.601 | 1.769 | 1.705 | 0 | 2,508,016 | 2.095 |
| clang-rv64gc-Os | 840 | 401,302 | 1,176,196 | 2.931 | 1.355 | 1.220 | 1.314 | 1.247 | 0 | 1,176,196 | 0.983 |
| clang-x86_64-O1 | 841 | 341,020 | 1,300,666 | 3.814 | 1.152 | 1.349 | 1.246 | 1.498 | 121,686 | 1,422,352 | 1.188 |
| clang-x86_64-O2 | 841 | 472,399 | 2,066,069 | 4.374 | 1.596 | 2.143 | 1.348 | 1.653 | 60,395 | 2,126,464 | 1.776 |
| clang-x86_64-O3 | 841 | 623,033 | 2,919,140 | 4.685 | 2.104 | 3.028 | 1.540 | 1.908 | 64,785 | 2,983,925 | 2.493 |
| clang-x86_64-Os | 841 | 308,089 | 1,163,506 | 3.777 | 1.041 | 1.207 | 1.100 | 1.299 | 0 | 1,163,506 | 0.972 |

What the table says:

* **pcc against pcc.** pcc amd64: 1.43 (project flags) or 1.37 (pdp64's flag set) times the instruction bytes, 1.33 or 1.29 times the instructions of pdp64/32; pcc i386: 1.39 or 1.34 times the bytes, 1.52 or 1.46 times the instructions. pdp64/16 is 3.1% smaller in bytes and 1.6% larger in instructions than pdp64/32 (`integration.md` 4.1).
* **RISC-V, rv64gc.** Instructions: **1.36 (Os), 1.49 (O1), 1.80 (O2), 2.52 (O3)** times pdp64/32; bytes 1.22 (Os), 1.35 (O1), 1.76 (O2), 2.60 (O3). Bytes per instruction 2.93 (Os) and 2.95 (O1) against 3.26: shorter instructions on average, more of them. **-O2 and -O3 are larger than -O1 and -Os** because clang unrolls and inlines: the instruction count of the corpus grows by 21% from -O1 to -O2 and by a further 40% to -O3; in `gcc-torture` the bytes are 2.2 times as many at -O2 as at -Os.
* **rv64g (no C extension)**: exactly 4.000 bytes per instruction; 1.36 times the bytes of rv64gc at -Os (1,602,416 against 1,176,196) and at -O1. Of rv64gc -Os's 401,302 instructions 214,506 (53.5%) are 2-byte compressed ones (-O1 52.7%, -O2 41.0%, -O3 31.9%, -O0 40.8%; derived as (4 x instructions - bytes) / 2).
* **Other architectures, same clang.** x86-64 -Os: 1.21 times the bytes, 1.04 times the instructions; i386 -Os 1.21 and 1.19; AArch64 -Os 1.34 (4 bytes each) and 1.09; Arm A32 -Os 1.38 and 1.13; **Arm Thumb-2 -Os 0.91 times the bytes and 1.35 times the instructions**; MIPS64 -Os 1.87 and 1.51 (822 files). At -O1: x86-64 1.35 and 1.15, AArch64 1.49 and 1.21.
* **The whole `.text`** (last column): pdp64's `.text` holds 232,930 bytes of constant pools and padding (19.5% of it); the clang targets keep constants in the instruction stream (counted) or in `.rodata` (RISC-V's merged constant sections: 2,684 bytes at -Os). Against pdp64's whole `.text` rv64gc is **0.98 (Os), 1.09 (O1), 1.42 (O2)** times. The instruction-bytes ratio is what was asked for; the `.text` ratio is the other reading of "code size". Neither counts jump tables or string data (clang puts them in `.rodata`).

### 5.1 Without `memcpy-a2.c`

`gcc.c-torture/execute/memcpy-a2.c` (file 611) is 27% of pdp64/32's corpus bytes (258,116 bytes, 65,538 instructions; `integration.md` 4.1 gives the same share) and is mostly block copies of structs of one size; pdp64 has block-copy instructions. clang -Os for rv64gc needs 98,421 instructions and 295,728 bytes there, at -O2 181,347 and 661,280. Without it (the last two ratio columns): rv64gc -Os **1.25 bytes, 1.31 instructions**; -O1 1.42 and 1.49; -O2 1.47 and 1.53; pcc amd64 1.55 and 1.31 (1.48 and 1.25 with pdp64's flags); pcc i386 1.53 and 1.57. The complete table without that file is in `riscv-data/static-summary.md`.

### 5.2 By corpus (instruction bytes)

| corpus (files) | pdp64/32 (pcc) | pcc amd64, project flags | pcc i386, project flags | clang-aarch64-O2 | clang-aarch64-Os | clang-rv64g-O2 | clang-rv64g-Os | clang-rv64gc-O2 | clang-rv64gc-Os |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bearssl (294) | 137,366 | 214,199 | 243,861 | 221,272 | 165,824 | 318,544 | 255,608 | 240,062 | 189,012 |
| c-testsuite (213) | 13,554 | 19,889 | 19,195 | 20,404 | 17,748 | 24,556 | 20,888 | 18,996 | 16,170 |
| chibicc (8) | 39,386 | 65,634 | 60,368 | 83,584 | 68,888 | 94,064 | 80,592 | 70,646 | 59,722 |
| cjson (2) | 11,404 | 17,810 | 17,305 | 23,856 | 19,344 | 27,572 | 22,208 | 19,488 | 15,408 |
| gcc-torture (169) | 279,130 | 314,969 | 286,968 | 994,676 [168] | 366,904 [168] | 749,148 [168] | 415,676 [168] | 678,648 [168] | 311,744 [168] |
| lua (34) | 99,376 | 157,671 | 157,447 | 199,212 | 157,176 | 224,964 | 186,160 | 162,802 | 132,206 |
| lz4 (5) | 26,686 | 45,810 | 46,837 | 50,892 | 42,864 | 65,060 | 59,900 | 46,906 | 42,718 |
| mbedtls (101) | 322,226 | 490,451 | 454,557 | 468,376 | 410,068 | 567,964 | 507,336 | 417,148 | 370,214 |
| zlib (15) | 35,030 | 52,409 | 50,415 | 59,736 | 45,416 | 62,236 | 54,048 | 45,086 | 39,002 |

(`[168]`: `651.i` missing for clang.) rv64gc -Os against pdp64/32 per corpus: chibicc 1.52, lz4 1.60, bearssl 1.38, cjson 1.35, lua 1.33, c-testsuite 1.19, mbedtls 1.15, gcc-torture 1.12, zlib 1.11.

### 5.3 RISC-V with the linker's relaxation, estimated

An unrelaxed RISC-V object spends 8 bytes and two instructions on every call (`auipc`+`jalr`, an `R_RISCV_CALL` relocation); the linker shrinks it to one `jal` (4 bytes, 1 instruction) if the target is within 1 MiB. pdp64's own relaxation (6-byte call to 4) is a further 3.76% of its linked text and is **not** in the 964,158. The estimate subtracts 4 bytes and 1 instruction per `R_RISCV_CALL`; it ignores `gp`-relative relaxation of data addresses, which needs a linked image:

| configuration | call relocations | instruction bytes, calls relaxed | bytes ratio | instructions, calls relaxed | insn ratio |
|---|---:|---:|---:|---:|---:|
| clang-rv64g-O0 | 34,879 | 2,611,200 | 2.708 | 652,800 | 2.205 |
| clang-rv64g-O1 | 23,961 | 1,672,820 | 1.735 | 418,205 | 1.413 |
| clang-rv64g-O2 | 24,619 | 2,035,632 | 2.111 | 508,908 | 1.719 |
| clang-rv64g-O3 | 29,691 | 2,860,536 | 2.967 | 715,134 | 2.416 |
| clang-rv64g-Os | 23,384 | 1,508,880 | 1.565 | 377,220 | 1.274 |
| clang-rv64gc-O0 | 34,879 | 2,050,544 | 2.127 | 652,799 | 2.205 |
| clang-rv64gc-O1 | 23,957 | 1,207,118 | 1.252 | 418,460 | 1.413 |
| clang-rv64gc-O2 | 24,619 | 1,601,306 | 1.661 | 509,845 | 1.722 |
| clang-rv64gc-O3 | 29,687 | 2,389,268 | 2.478 | 716,089 | 2.419 |
| clang-rv64gc-Os | 23,389 | 1,082,640 | 1.123 | 377,913 | 1.276 |

On this estimate rv64gc -Os needs 1.12 times the bytes and 1.28 times the instructions of unrelaxed pdp64/32; relaxing pdp64/32 as well takes about 3.8% off its text.

## 6. Caveats

1. **The compilers differ**: pcc (pdp64, amd64, i386) against clang 21 (the rest). pcc's optimizer is weaker, so every pcc against clang gap mixes compiler and architecture. Only the pcc rows differ in back end alone, and even they differ in the work put into the back end: pdp64's was written for this project with its own passes, amd64 and i386 are the stock ports with the fork's changes.
2. **The pdp64 instruction count excludes the constant pools and padding** that sit in `.text` (232,930 bytes at /32), so the instruction-bytes ratio favours pdp64 against architectures that build constants from instructions (RISC-V `lui`/`addi` sequences are in the RISC-V count). The `.text` column is the other reading.
3. **Static, not dynamic**: size and instruction count of the code compiled, not of the code executed; static counts weigh every function alike (section 8).
4. **Instruction counting**: pdp64's fused pairs count one; RISC-V has no fusion in the count; RISC-V pseudo-instructions count as their expansions; the RISC-V `call` is counted unrelaxed (5.3); x86 counts `llvm-objdump` instructions.
5. **Padding** (alignment nops) is left out of the instruction counts everywhere (pcc amd64 5,328 bytes; clang x86-64 -O1 121,686 bytes of alignment nops; RISC-V objects before linking have none).
6. **Files**: clang did not compile `651.i` (RISC-V, AArch64), `506.i` (i386) and 18 to 19 MIPS64 files; ratios are on the common files.
7. **Only rv64gc and rv64g**: no rv32, no vector, no Zba/Zbb bit-manipulation extensions (not part of the common Linux target; they would shorten address arithmetic and rotates).
8. **-O0 is a reference**: pcc has no unoptimized pdp64 number in `integration.md` to compare it with.
9. **Corpus and preprocessing** are those of the pdp64 numbers with each architecture's musl headers; the RISC-V text differs from the aarch64 text only by the architecture macros (`-D__riscv -D__riscv_xlen=64`).
10. **Compressed fraction** (53.5% at -Os) is what clang's register allocation gives; it is reported, not tuned.

## 7. The answer in a sentence

Against pcc's own pdp64/32, the other pcc back ends that compile the corpus (amd64, i386) need 1.3 to 1.5 times the bytes and instructions; clang's nearest RISC-V level (-Os with the C extension) needs 1.22 times the bytes and 1.36 times the instructions, 1.12 and 1.28 with calls relaxed; how much of that is the architecture and how much clang against pcc cannot be separated here, because pcc cannot produce RISC-V code (section 9).

## 8. What could not be done

1. **pcc for RISC-V**: not compilable and not repairable within the scope set (section 9). There is no pcc-against-pcc RISC-V row.
2. **Dynamic counts for the six programs** (lz4, zlib, Lua, three BearSSL kernels; `integration.md` 4.2: 572,801,956 instructions executed and 1,680,662,586 bytes fetched at /32). Not made, for these reasons, each checked:
   * the mains (`scratchpad/dyn/progs/`), the stand-in libc (`rt/libc.c`, `libc2.c`) and the crt (`crt32.s`) are not on this machine (searched under `~/claude`, `/tmp` and the sibling worktrees `pdp64-enc-*`). `docs/dynamic-spill-estimate.md` describes them in words only (lz4 fast and HC round trip; zlib deflate and inflate at 3 levels; Lua 5.4.7 running a 40-line script, without its io, os, math, coroutine and debug libraries; BearSSL hashes, AES + ChaCha20-Poly1305 + GHASH, curve25519 + P-256; the libc was written for the runs and compiled by the same pcc). New mains would be six different programs and their counts would not be comparable with 572,801,956; I did not present such numbers;
   * the installed `qemu-riscv64` 10.2.1 has no `-plugin` option, so it cannot count instructions except through `-d exec` logging of every translated block; a plugin build means building QEMU from `~/claude/qemu-src` (11.1.2); not attempted;
   * the installed LLVM has no RISC-V linker (`/usr/bin/rust-lld` points to a missing `lld-21`); the GNU `ld` for RISC-V from this session's binutils build works, so linking is possible;
   * the pdp64 side would have to be rebuilt with the same reconstructed programs, and its libc and crt for `sim64` are lost as well.
   What would settle it: the lost `scratchpad/dyn` and `scratchpad/int` directories, or an instruction to reconstruct the six programs for both targets, a plugin-enabled `qemu-riscv64` (about half an hour of build) and a musl for RISC-V (source in `corpora/musl`).
3. **GCC for RISC-V** (dropped on the author's instruction), **rv32**, vector and bit-manipulation extensions.
4. The old-compiler pdp64/r20 row was not re-measured (`integration.md`: 1,083,870 bytes, 338,313 instructions).

## 9. pcc's RISC-V back end: status

*The author's question: did pcc not have a working RISC-V back end? Diagnosis only; nothing was fixed and nothing in pcc was changed (builds are scratch copies; the one edit that lets `configure` accept the target is in the copy).*

### 9.1 Facts

* `arch/riscv` (in `~/claude/status-check/pcc`, HEAD `41e5c3694648a4b3c4df9b9729c69761e172fa0a`; the same files as `pcc-enc`'s): `code.c` 1,154 lines, `local.c` 1,165, `local2.c` 1,496, `table.c` 1,105, `order.c` 220, `macdefs.h` 451, **5,591 lines**; no `peep.h` (aarch64 has 1,674 lines of it, pdp64 2,887) and no `test/` directory (pdp64 has `arch/pdp64/test`). Its last commits: "Convert riscv to NEWNEED as well" (2023-08-22) and "new date 20230706". The copyright of the port: Tim Kelly, 2022.
* `configure.ac` accepts `riscv32` and `riscv64` for **NetBSD only**; `riscv64-unknown-linux` is "not (yet) supported by pcc". `tools/corpus-build.sh` configures `riscv64-unknown-netbsd`. The fork's `doc/SIZE-REPORT.md` says riscv64 "compiles nothing: every file stops with `invalid function definition`" ("unfinished ports the fork did not work on"). I confirmed the sentence and found its cause.
* **Root cause of "invalid function definition"**: the back end never defines `__builtin_va_list` (the pdp64 and aarch64 back ends define it in `bjobcode`: `arch/pdp64/code.c:412`, `arch/aarch64/code.c:572`). musl's headers use `typedef __builtin_va_list va_list;`, so every file that includes them stops at the first such line. That one is shallow. In my run (the Linux target made available by the one-line change; flags `-xdmr -xtemps -xdeljumps -xinline -xdce -xccp -xtailcall`) 214 of the 841 files stop there, 123 more fail otherwise and 504 do not mention it and exit 0, which does not mean they are right (below). With `typedef char *__builtin_va_list;` (the pdp64 definition) prepended to the text, 621 of 841 pass and **220 fail** in pass 2 with "Cannot generate code, node ... op X": `=` (82), `>>` (39), `FUNARG` (22), internal errors (18), `SCONV` (11), `==`, `|`, `USTCALL`, `OREG`, `>=`, `!=`, `ULT`, `UGT`, `<`, `&`, `ULE`: the table has no rule for those at the types the corpus uses (`riscv-data/pcc-riscv64-status-*.tsv`).
* **It is an RV32 back end**, which is the deep problem: `SZLONG` = `SZINT` = 32 and `SZPOINT` = 32 in `macdefs.h`; `long long` is a register pair (class C; 71 of the 146 table rules concern the pair); the integer `ld`, `sd`, `lwu`, the `addw` family, `lui`, `auipc` and `fcvt.l` appear nowhere in the table or the code (`grep -w`); the header says "The classes used on riscv32 are". `sizeof(long)` and `sizeof(void *)` are 4 (probe `sizes` in `diag-output.txt`), so LP64 text such as the corpus's is compiled with wrong sizes (86 of the 621 files that pass give "shift larger than type" as their first message: 64-bit constants shifted in 32-bit longs).
* **Even as an RV32 back end its output cannot be used as written**: (a) the comment string is `;`, which GNU `as` and clang's assembler read as a statement separator, and six debugging `printf`s (`code.c:973,982,1051,1055`, `local2.c:190,836`) put `; movargs: ...` and `; r: 0x...` lines into the assembly: **0 of 120** sampled outputs assemble as they are; (b) it emits `subi`, which does not exist in RISC-V: after stripping the comments and rewriting `subi` as `addi` 53 of the 120 assemble; (c) **temporaries that need a stack slot are addressed at `0(fp)`, `4(fp)`, `8(fp)`**, which is the caller's saved frame pointer and return address. With those two repairs by `sed` (not made in pcc), under `qemu-riscv32` (`diag-riscv-backend.sh`): `return a*3+1` gives 16 (right), `g(g(5))` gives 7 (right), a loop summing 0..9 gives 45 (right), and **`fib(10)` dies with a segmentation fault** (expected 55). Straight-line and leaf code works; a recursive call with a spilled temporary corrupts the caller.
* The varargs builtins (`riscv_builtin_stdarg_start`, `_va_arg`) are RV32 word-slot versions without a register save area; `mygenswitch` is marked "XXX - fix genswitch"; `local.c` notes "XXX cannot takes addresses of PARAMs"; `code.c` shows no sign of the psABI struct rules (up to 16 bytes in registers, larger by reference; the `STARG` code carries a debug print); there is no 64-bit constant materialisation (`lui`/`addi`/`slli`); FP compares go through an `fcomp` table in `local2.c`, but conversions to and from 64-bit `long` (`fcvt.l`) do not exist.

### 9.2 Shallow bug or large unfinished port?

**A large unfinished port.** The first error is a one-line shallow bug, but behind it stands a 32-bit back end that was never made 64-bit, never made assembler-clean, never given tests, and has a frame-layout fault. What is missing against what `mips64` and `aarch64` implement in the same tree:

| part | state | needed (rough lines) |
|---|---|---|
| sizes and registers (`macdefs.h`) | RV32 sizes, long long pairs, 77 register numbers with pair classes | LP64 sizes, no class C, 31 + 32 registers in psABI numbering (about 100 changed) |
| table (`table.c`) | 146 rules, 32-bit words, pairs; no W-forms, no 64-bit loads or stores, no `lui`/`auipc`, comparisons mostly absent | **rewrite**: loads and stores by type, `add`/`addw` families, shifts, extension of `int` in 64-bit registers, compare-and-branch for all relops with the `LC` label template (as `mips64`'s table), set-on-condition, FP convert and compare, constants (800 to 1,000 lines) |
| calling convention (`code.c`) | 8 argument registers of 32 bits; no struct passing; varargs without save area; debug prints | 8 x 64-bit argument registers, structs up to 16 bytes in registers and larger by reference, varargs area, two-register struct returns, `__builtin_va_list` (300 to 400 lines) |
| frame, prologue, epilogue (`local2.c`) | 32-bit slots; temporaries at positive offsets from `fp` | 8-byte slots, correct temporary placement, 12-bit offset range with `lui` for big frames (150 to 250 lines) |
| tree rewrite (`local.c`) | 32-bit conversions | 64-bit `SCONV`/`PCONV`, pointer arithmetic, bit-fields (150 to 250 lines) |
| output (`local2.c`) | `;` comments, `subi`, debug prints | `#` comments, real mnemonics, `-march` attributes, far branches and calls (50 to 100 lines) |
| `configure.ac` | Linux target not accepted | one line |
| target optimizer passes (`peep.h`) | none | optional: the shared passes (`-xtemps -xdeljumps -xinline -xdce -xccp`) work through `mip` |
| tests | none | a harness like `arch/pdp64/test`, run under `qemu-riscv64` (user mode works on this machine) |

### 9.3 Estimate

* **Lines**: about **2,000 to 2,500 of the 5,591 rewritten or new**; the register-file descriptions, helpers and `order.c` stay with edits. The `aarch64` back end of the same tree (LP64, 31 integer and 32 FP registers, structs up to 16 bytes in registers as in RISC-V) compiles 845 of 900 corpus files today and is the closer template than the RV32 code; its flag-based compares would become compare-and-branch (the `mips64` table shows the form).
* **Work**: to "all 841 files compile and assemble" about **20 to 40 agent-hours** (a table rewrite, the calling convention, then iteration over failure classes; the 220 that fail now are the first batch); to "the six programs link and print what the host gcc prints" **about as much again**, because code-generation faults show only when code runs (the pdp64 back end reached its state with a harness of 963 tests per target and a miscompile hunt such as `-xccp` and c-testsuite 00104). Uncertainty a factor of two either way; the largest unknown is how many runtime faults the shared optimizer passes (`-xtemps`, `-xdmr`) expose in a fresh 64-bit back end.
* **Options**: (a) keep pcc against pcc to amd64 and i386, as here; (b) compare RISC-V through clang, as here, accepting the compiler difference; (c) write the RV64 back end as a new `arch/riscv64` derived from `aarch64` (shortest road: about 1,500 changed lines, 20 to 30 agent-hours to the corpus). Even then the row is "pcc with a basic RV64 back end", without the target passes that the pdp64 back end has, not a statement about RISC-V's best.

## 10. How to reproduce

    cd tools/riscv-compare
    make WORK=/scratch/rv prep ccoms          # preprocess for 6 architectures; build ccom for pdp64/16, /32, amd64, i386, riscv64 from PCCENC (default ~/claude/pcc-enc)
    make WORK=/scratch/rv pdp64 pccx86        # 964,158 and 934,470 are the check against integration.md
    python3 run-refs.py /scratch/rv           # the clang matrix, 1 to 4 minutes per configuration on two cores
    python3 summarize.py /scratch/rv ../../docs/encoding-work/riscv-data
    # section 9: binutils for riscv64-unknown-elf in /scratch/rv/gccx/prefix, the same pcc tree configured for riscv32 in /scratch/rv/pcc/rv32, qemu-riscv32
    sh diag-riscv-backend.sh /scratch/rv
    python3 pcc-compile.py /scratch/rv/i-rv /scratch/rv/s-rv0 /scratch/rv/pcc/rv/cc/ccom/riscv64-unknown-linux-ccom -j 2 -- -xdmr -xtemps -xdeljumps -xinline -xdce -xccp -xtailcall
    # the same on copies of the .i files with the line `typedef char *__builtin_va_list;` prepended gives the 621/220 split

Tool versions: clang 21.1.8, llvm-objdump 21, host gcc (x86-64) for preprocessing, binutils 2.43.1 for the RISC-V probes, qemu 10.2.1. pcc: `~/claude/pcc-enc` for pdp64, amd64, i386; `~/claude/status-check/pcc` at `41e5c36` for the RISC-V diagnosis (its `arch/riscv` and `mip` are identical to pcc-enc's).
