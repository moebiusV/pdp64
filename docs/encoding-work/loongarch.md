Status: record, dated 2026-11-17. It describes what was measured on that day; the current state is in `docs/manual` and `docs/decisions-and-status.md`, and where this document disagrees, those win. The findings in section 7 are the assistant's analysis, not decisions: the author decides J.9.13.

# LoongArch64 against pdp64: static size of the corpus, and the bounds-check question

The author asked (2026-11-16): compile the corpus for LoongArch64 ("loongson64") so there is real data to compare against; see whether adding the fused bounds-check operations a Linux kernel developer asked about (open item J.9.13, errata 138) is a net win; and whether LoongArch's form is the best one, since a band check (a lower and an upper bound together) was expected and LoongArch's operations look like an upper bound or a lower bound only.

Scripts are in `tools/arch-compare/` (`prep.py`, `run-refs.py`, `la-summary.py`, `boundscan.py`, `bounds-price.py`, `la-mnemonics.py`); raw results are in `docs/encoding-work/arch-data/loongarch/` and `docs/encoding-work/arch-data/loongarch-summary.md`.

## 0. Summary

* **Size.** On the 840 files that both compile, clang for LoongArch64 at -Os needs **1.51 times the instruction bytes and 1.23 times the instructions** of pdp64 (pcc); without file 611 (`memcpy-a2.c`) 1.59 and 1.21. At -O1 1.63 and 1.33; at -O2 2.34 and 1.90. LoongArch is a fixed 32-bit encoding, so its bytes are four times its instruction count; the instruction count is the fairer comparison, and 1.23 is what the register-memory model and the prefix code save. The compilers differ (pcc against clang), as in `arch-comparison.md`.
* **LoongArch's bounds-check instructions are never used.** `ASRTLE.D`, `ASRTGT.D` and the fused `LDGT`, `LDLE`, `STGT`, `STLE` (26 encodings with the floating-point forms) do not appear in the corpus at any level, in the plain or the sanitized build: neither clang nor gcc selects them from C (only the intrinsics `__builtin_loongarch_asrtle_d` and `__builtin_loongarch_asrtgt_d`), and the Linux kernel's own LoongArch code does not use them (a search of the tree on this machine). So the corpus gives no count of them; the data is a census of the checks that exist.
* **The census.** With `-fsanitize=bounds` the corpus holds 834 checks in 146 of 840 files (the sanitizer guards the arrays whose size it knows: 8.3% of the 10,078 subscripts with a variable index). Of them **69% are one unsigned compare of an index with a bound** (60% against a constant, 8% against a variable), **21% test an index that carries an offset that may wrap** (`a[i+1]` with `i` a signed `int`: a true band `lo <= i < hi`), 10% are several checks merged by the optimiser, and 0.2% are signed compares. 99.8% are unsigned: a negative index is a huge unsigned number, so the lower bound of zero costs nothing.
* **What the checks cost on LoongArch**: 2,269 instructions (+0.63%) at -Os for 508 checks, **4.5 instructions a check**: a compare-and-branch, the trap (`amswap.w $zero, $ra, $zero`, an illegal encoding that LLVM uses), and, because `bgeu` has no immediate form, an `ori` to load a constant bound (483 of the 2,269).
* **For pdp64**, the one-sided check is already one instruction of 4 bytes, `CBHIS rs, rb|#imm, fail`. A compare-and-trap `CHK` ties it in instructions and bytes (it saves a shared stub and nothing else). A two-bound `CHK2` saves one instruction at each of the 21% band sites: 176 instructions and 704 bytes on this corpus, 0.06% of its instructions. If every one of the 10,078 variable subscripts were checked, as Ada, Rust and Go do before their optimisers remove the provable ones, the guards would cost about 13,200 instructions (4.5%) with `CBHIS`, and `CHK2` would save about 2,100 of them (0.7%).
* **Findings (section 7):** `CHK` is not a net win. `CHK2` is a small net win that appears only where checks are dense (a language that checks every subscript) and costs no opcode patterns in the three-register group. LoongArch's form is not the best one for the checks as compilers make them: no immediate form (60% of the sites), a band takes two instructions, and the fused address forms check an address against a bound, not an index against a length, which is not what a subscript check is; no compiler or kernel uses them.

## 1. What was measured and how

The corpus is the 841 files of `arch-comparison.md` (`tools/arch-compare/fair.txt`). Each file is preprocessed with the musl headers of the target and the architecture's defines (`prep.py`); LoongArch has no sysroot in the corpora tree and no entry in the toolchain repository's `corpus.py`, so the headers were made with `make install-headers` of musl (`ARCH=loongarch64`) into a scratch directory, and the defines are kept in `prep.py` (`SYSROOTS=` names the directory). clang 21.1.8, `--target=loongarch64-linux-gnu -fno-pic`, the flags of `run-refs.py`, at -O1, -O2, -O3 and -Os, and at -O2 and -Os with `-fsanitize=bounds -fsanitize-trap=bounds`. Instructions and bytes are counted by `objstat.py` from `llvm-objdump-21 -d`; alignment padding is not counted. 840 of 841 files compile (651.i uses `__builtin_longjmp`, which clang refuses for LoongArch, as for the other targets).

**The pdp64 row was reproduced first**: pcc of the branch `single-pdp64` built from a scratch copy, `as64 --stats`: 841 files, **296,082 instructions, 964,158 instruction bytes, 1,197,088 `.text` bytes**, the numbers of `arch-comparison.md` section 2 to the byte. Both sides are the unrelaxed objects: pdp64's external calls are 6 bytes before the linker shortens them, and LoongArch's `pcaddu18i` plus `jirl` pairs (22,412 of them, two instructions a call) are 8 bytes before `ld` relaxes them to `bl`; neither side has had that gain.

## 2. The size of the corpus

### files both compiled (840)

| configuration | instructions | instruction bytes | insn ratio | bytes ratio | .text bytes | padding instructions |
|---|---:|---:|---:|---:|---:|---:|
| pdp64 (pcc) | 296,059 | 964,086 | 1.000 | 1.000 | 1,197,016 | 0 |
| clang LoongArch64 -O1 | 393,895 | 1,575,580 | 1.330 | 1.634 | 1,692,704 | 29,281 |
| clang LoongArch64 -O2 | 563,559 | 2,254,236 | 1.904 | 2.338 | 2,360,828 | 26,648 |
| clang LoongArch64 -O3 | 772,692 | 3,090,768 | 2.610 | 3.206 | 3,189,864 | 24,774 |
| clang LoongArch64 -Os | 362,924 | 1,451,696 | 1.226 | 1.506 | 1,451,696 | 0 |
| clang LoongArch64 -O2, bounds checks as traps | 566,322 | 2,265,288 | 1.913 | 2.350 | 2,371,512 | 26,556 |
| clang LoongArch64 -Os, bounds checks as traps | 365,193 | 1,460,772 | 1.234 | 1.515 | 1,460,772 | 0 |

### the same without file 611 (839)

| configuration | instructions | instruction bytes | insn ratio | bytes ratio | .text bytes | padding instructions |
|---|---:|---:|---:|---:|---:|---:|
| pdp64 (pcc) | 230,521 | 705,970 | 1.000 | 1.000 | 938,900 | 0 |
| clang LoongArch64 -O1 | 316,209 | 1,264,836 | 1.372 | 1.792 | 1,330,704 | 16,467 |
| clang LoongArch64 -O2 | 329,725 | 1,318,900 | 1.430 | 1.868 | 1,382,636 | 15,934 |
| clang LoongArch64 -O3 | 378,026 | 1,512,104 | 1.640 | 2.142 | 1,577,432 | 16,332 |
| clang LoongArch64 -Os | 279,678 | 1,118,712 | 1.213 | 1.585 | 1,118,712 | 0 |
| clang LoongArch64 -O2, bounds checks as traps | 332,488 | 1,329,952 | 1.442 | 1.884 | 1,393,320 | 15,842 |
| clang LoongArch64 -Os, bounds checks as traps | 281,883 | 1,127,532 | 1.223 | 1.597 | 1,127,532 | 0 |

- bounds checks as traps, -O2: +2,763 instructions (+0.49%), +11,052 bytes (+0.49%) on 840 files

- bounds checks as traps, -Os: +2,269 instructions (+0.63%), +9,076 bytes (+0.63%) on 840 files

For the other architectures, `arch-data/static-summary.md` gives at -Os (instruction ratio, bytes ratio against pdp64, on 840 or 841 files): AArch64 1.09 and 1.34; x86-64 1.04 and 1.21; RISC-V rv64gc 1.36 and 1.22; Arm Thumb-2 1.35 and 0.91; MIPS64 1.51 and 1.87. LoongArch64 (1.23 and 1.51) sits between AArch64 and MIPS64: the same fixed width as AArch64 with more instructions, because it has no pre- or post-indexed addressing, no compare-and-branch against an immediate, and a longer call.

## 3. What LoongArch uses

### Most used
| mnemonic | count | share |
|---|---:|---:|
| `addi.d` | 42,306 | 11.6% |
| `move` | 41,525 | 11.4% |
| `ld.d` | 35,688 | 9.8% |
| `ori` | 30,958 | 8.5% |
| `st.d` | 25,535 | 7.0% |
| `pcaddu18i` | 22,412 | 6.2% |
| `jirl` | 21,932 | 6.0% |
| `bne` | 14,902 | 4.1% |
| `pcalau12i` | 12,006 | 3.3% |
| `add.d` | 10,975 | 3.0% |
| `b` | 7,100 | 2.0% |
| `beqz` | 6,662 | 1.8% |
| `ld.bu` | 6,426 | 1.8% |
| `ret` | 6,106 | 1.7% |
| `ld.w` | 5,411 | 1.5% |
| `bnez` | 4,265 | 1.2% |
| `ldx.bu` | 4,042 | 1.1% |
| `st.w` | 3,765 | 1.0% |
| `addi.w` | 3,501 | 1.0% |
| `lu12i.w` | 3,146 | 0.9% |

The instructions that carry the difference from pdp64 are visible in the list: `move` (11.4%: register copies), `ori` (8.5%: constants, and every compare against an immediate that a branch cannot hold), `pcaddu18i` with `jirl` (a call is two instructions) and `pcalau12i` with `addi.d` (an address is two). `alsl.d` (a shifted add, 615 uses) and `bstrpick.d` (2,156) are the scaled-index and extension helpers; `ldx` and `stx` (register plus register, no displacement; 6,244 uses) are the only indexed forms, and they do not scale.

## 4. The bounds-check instructions of LoongArch

Read in the QEMU source (`target/loongarch/tcg`), LLVM (`LoongArchInstrInfo.td`) and GCC 14.2 (`config/loongarch`):

* `ASRTLE.D rj, rk` raises the bound-check exception (BCE) if rj > rk, `ASRTGT.D rj, rk` if rj <= rk: an **unsigned 64-bit compare of two registers**, no immediate. The faulting address register (BADV) is set to rj.
* `LDGT`, `LDLE`, `STGT`, `STLE` in the B, H, W and D sizes (16 encodings), and the floating-point forms `FLDGT`, `FLDLE`, `FSTGT`, `FSTLE` in S and D (8): the same compare of rj with rk, then the access at the **address in rj** with no offset. `GT` requires the address to be above the bound register (a lower bound, exclusive), `LE` at or below it (an upper bound, inclusive). The check is of an address against an address; it does not scale an index, takes no immediate, and does not allow for the size of the access (`LDLE.D` with rj equal to rk passes and reads 8 bytes from the bound).
* LLVM defines them with **no selection pattern**: they exist for the assembler and the disassembler. `ASRTLE.D` and `ASRTGT.D` are selected only from the intrinsics. GCC has only the two `asrt` builtins and no `ldgt`, `ldle`, `stgt` or `stle` at all. In the corpus the count of every one of these is **0** at every level, plain and sanitized, and the Linux tree on this machine (3,514 `.c` and 7,017 `.h` files) has no use of them in `arch/loongarch`.
* So each of LoongArch's two one-sided forms exists, and the author's reading is right: there is an upper-bound form and a lower-bound form and no band form. A band `lo <= a <= hi` is two instructions (`ASRTGT` and `ASRTLE`) or an `addi` and one.

## 5. The census of bounds checks

`tools/arch-compare/boundscan.py` compiles each file to LLVM IR with `-fsanitize=bounds -fsanitize-trap=bounds` at -O2 and finds the conditional branches into a block that calls `@llvm.ubsantrap`, and classifies the compare that decides each (`arch-data/loongarch/bounds-O2-sites.csv`):

| class | sites | share | of them in a loop |
|---|---:|---:|---:|
| const | 503 | 60.3% | 257 |
| var | 68 | 8.2% | 45 |
| offset-nuw | 1 | 0.1% | 1 |
| band | 176 | 21.1% | 66 |
| combo | 84 | 10.1% | 28 |
| signed | 2 | 0.2% | 0 |
| all | 834 | 100% | 397 |

`offset-nuw` is a check of `x + c` or `x - c` that cannot wrap (`nuw`): one compare of `x` with an adjusted bound is the whole check. `band` is the same with `nsw` only or no flag: `x` may lie below the lower bound, so a compare of `x` alone is not enough. All but one of the offset sites are of this second kind: a signed index plus a constant, `a[i+1]` and `a[i-1]`. `combo` is two or more checks that the optimiser merged into one condition (`or`, `and`, `select`); each is priced as two compares.

**Limits.** The sanitizer inserts a check only where the compiler knows the size of the array; 8.3% of the 10,078 variable-index subscripts of the IR (the rest index through pointers of unknown extent, which C does not check and Ada, Rust and Go do). The sites are found in LLVM's IR after the optimiser, so a check that the optimiser proved is not there, and one it hoisted is counted once. The code is the corpus (a C test and library set), not the code of a language that checks every subscript. The count of 834 sites is therefore a floor for checks in C and a statement about this corpus, not about checked languages; the extrapolation to 10,078 checks is labelled as such.

## 6. What each form costs on pdp64

The sizes are those of J.9.13, from the grammar: `CBHIS` 4 bytes (a register or an immediate bound in the hot registers), `CMP` and `TRAPCC` 4 bytes (6 with an immediate), a band needs `lea -lo(rs), t` first (one instruction, 4 bytes, one scratch register), `CHK` a compare-and-trap of 4 bytes, `CHK2 rs, rlo, rhi` 4 bytes with the band included, `ASRTLE.D` as LoongArch has it (register against register, so a constant bound is loaded first):

| form | instructions added | bytes added | against cbhis (instructions) | against cbhis (bytes) |
|---|---:|---:|---:|---:|
| cbhis | 1096 | 4384 | +0 | +0 |
| cmp+trap | 2014 | 5916 | +918 | +1532 |
| CHK | 1096 | 4384 | +0 | +0 |
| CHK2 | 920 | 3680 | -176 | -704 |
| asrt | 1862 | 7448 | +766 | +3064 |

IR instructions of the sanitized build, 840 files: 402235; sites 834 (0.207 per 100 IR instructions).
Subscripts with a variable index (`getelementptr` with a non-constant index) in the same IR: 10078; the sanitizer guarded 834 of them (8.3%), the arrays whose size the compiler knows.
If a language that checks every subscript (Ada, Rust, Go) guarded all 10078, with the same mix of classes, option 1 (cbhis) would add about 13244 instructions and 52976 bytes before the optimiser removes the provable ones.

The forms are priced from the census classes with the per-site sizes above; `CHK2` is priced with the bounds in registers or in immediates and with no cost to load them, which favours it (a constant pair would need the two-immediate form of J.9.13, option 3, at 32 opcode patterns, or two moves). Opcode cost, from J.9.13: `CBHIS` and `TRAPCC` exist; `CHK` in the `R2` shape takes no pattern and one vector, in a one-parcel hot form 256 patterns (0.39% of the first-parcel space); `CHK2` in the `R3` shape takes no pattern (the group holds 51 of 128).

## 7. Findings (the assistant's analysis, not decisions)

1. **A compare-and-trap `CHK rs, rb` is not a net win.** It ties `CBHIS` in instructions and bytes at every class of site (1,096 instructions and 4,384 bytes for the 834 sites). It beats `CMP; TRAPCC` by 918 instructions and 1,532 bytes, but `CBHIS` already does. What it gives is a check with no failure stub and no branch-predictor entry, at the price of one vector and of reversing errata 85. J.9.13 option 1 (nothing new) stands against it.
2. **A two-bound `CHK2 rs, rlo, rhi` is a small net win where checks are dense.** It removes the `lea` at each band site: 176 instructions and 704 bytes of the corpus (0.06% and 0.07%); for a language that checks every subscript, an upper bound of about 2,100 instructions (0.7%) and 8.5 KB (0.9%) before the optimiser removes the provable checks. It costs no pattern in the `R3` group. The case for it rests on the addressing: the indexed mode `d(base)(index*scale)` carries the constant, so the sum `i+1` is not otherwise formed, and a check on it costs an instruction (`lea`). LoongArch can absorb the constant too (`alsl.d`, then `ld.w` with an offset), so the data do not show that bands matter more on one machine than the other; they show that on both the check on the sum costs an instruction that a band form removes. A bound that is a constant pair needs the two-immediate form or two loads, which this estimate does not charge.
3. **LoongArch's form is not the best one.** (a) *No immediate form.* 60% of the sites have a constant bound, and the sanitized -Os build adds 483 `ori` instructions for 508 checks, 21% of the whole cost of checking; `CBHIS rs, #imm` is one instruction. (b) *One-sided.* 69% of the checks are one-sided and the unsigned compare gives the lower bound of zero for free, so for them the one-sided form is the right shape; the other 21% are bands and take two instructions on LoongArch. (c) *The fused forms check an address, not an index.* A subscript check compares an index with a length, then the address is formed; `LDLE` compares the formed address with a bound address, with no offset and no scale, so it fits `access_ok`-style checks of a user pointer and not subscripts, and it is **never emitted** and never used by the Linux kernel for LoongArch. Twenty-six encodings (16 integer, 8 floating-point, 2 `asrt`) buy nothing measurable on this corpus. (d) *The cost remains 4.5 instructions a check* in the code clang writes, against 1 for `CBHIS` with an immediate.
4. **The expected answer to "why not a band?"** is that for the common case a band is not needed: C, Rust and Go index from zero, an unsigned compare is the whole check, and a band appears only where the subscript carries a signed offset (21% of the checks here) or the array starts at a lower bound other than zero (Pascal, Ada). LoongArch chose the two halves of a band and no band; pdp64 can choose either, and the data say the one-sided form is already served by `CBHIS`.
5. **What would change these findings:** a corpus of Ada, Rust or Go code, where checks are dense; a compiler pass that proves the offset cannot wrap (`nuw`) for indexes known to be unsigned, which would turn the band sites into one-sided ones (only 1 of 177 is `nuw` in this corpus); dynamic counts, which were not made.

## 8. What was not measured

* **Dynamic counts** (instructions executed, bytes fetched): the installed `qemu-loongarch64` has no `-plugin` option, no user-mode build or plugin exists here, and the six programs of `integration.md` are reconstructions without a LoongArch runtime. The count of sites inside loops (397 of 834, 48%) is the only proxy.
* **GCC** for LoongArch (a gcc 15 cross compiler is in a scratch directory of an earlier run): not run here.
* **A language that checks every subscript**: the 10,078 variable subscripts are a count of places, not of checks.
* **pcc against clang** differ in optimiser strength (`arch-comparison.md` section 0); the instruction counts mix compiler and architecture.

## 9. To reproduce

    make -C tools/arch-compare ...            # see tools/arch-compare/README.md for the pdp64 row and the other architectures
    (cd musl && ./configure is not needed: write config.mak with ARCH = loongarch64 and prefix = <dir>/loongarch64; make install-headers)
    SYSROOTS=<dir> python3 tools/arch-compare/prep.py loongarch64 <work>/i-la64 -j 2
    python3 tools/arch-compare/run-refs.py <work> loongarch64
    python3 tools/arch-compare/boundscan.py <work>/i-la64 <work>/bounds-O2 -j 2 -O 2
    python3 tools/arch-compare/bounds-price.py <work>/bounds-O2
    python3 tools/arch-compare/la-mnemonics.py <work>/i-la64 <work>/mn-Os.csv -j 2 -- clang --target=loongarch64-linux-gnu -fno-pic -w -Os
    python3 tools/arch-compare/la-summary.py <work> docs/encoding-work/arch-data
