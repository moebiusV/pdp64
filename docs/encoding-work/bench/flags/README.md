# Should the pdp64 have flags at all? The no-flags experiment

## Repeating the measurement: `tools/measure-flags.sh`

The measurement below was first made by hand, in an experiment (sections 1 to 8, kept as the record of that run: its numbers are those of 2026-11-26 and of the compiler variant of `noflags-peep.patch`). The flags were then removed from the machine (commit d4362464), and the measurement is now one script that repeats it from a clean checkout; **the numbers the manual cites are those of the script**, in `results-final.txt` (read by `tools/mkmanual.py` through `@@MEASURE:key@@`; `tools/check-manual-src.py` and `mkmanual.py --check` fail if a cited key is missing) and, as tables, `results-final.md`.

```
tools/measure-flags.sh                         # the full run: about 30 seconds on 12 processors, writes results-final.txt and results-final.md here
tools/measure-flags.sh --corpus-subset 40      # a quick run (about 40 files, every third program), about 25 seconds, written to /tmp
tools/measure-flags.sh --jobs 4 --out /tmp/x   # options: --jobs N, --corpus-subset N, --out PREFIX, --keep (keep the scratch directory)
```

What it does:

1. **Base side** (the flags still there): the pdp64 tools of commit `8d8d07f6` (the parent of d4362464) and pcc `82d5006b` (the last commit before 7e1bf616, which stopped emitting flag instructions), pcc built as the experiment built it (32 registers, `-DPDP64_REGS32`, run with `-m pdp64/32`). **Now side**: this repository's HEAD (as64, ld64, sim64) and pcc's HEAD (`../pcc`). Both sides are made from `git archive` into a scratch directory under `/tmp`; no working tree or its `build/` is read or written, and the scratch directory is removed at the end.
2. The same corpus goes through both sides, the **same preprocessed text** to both compilers: the OpenBSD files of `scripts/measure.py` (libz, libc, `sys/crypto`, libm, the `usr.bin` programs and more: 1,104 files tried; pcc compiles about 625), `tests/c`, `tests/c-new` and `docs/encoding-work/bench/sc/src` of the base commit. Each file is assembled by that side's `as64` plain (`--no-relax`) and relaxed (the text size after `ld64` linked the object alone against stubs); static instructions and bytes are summed over the files **both** sides compile, and the mnemonics are counted by kind.
3. The 36 programs that run (zlib, the cryptographic hashes, the libc sorts and strings, the eight `bench/sc` programs, 24 small tests) are linked with the same `scripts/run/crt.s` and `main.c` and run on each side's `sim64` with four timing presets (`scalar`, `dual`, `scalar-c`, `dual-c`: `tools/timing.py`); instructions executed, bytes fetched and cycles are summed, and **every program must print the same on both sides** (the result says how many do).
4. Then `results-final.txt` (the pinned commits, tool versions, every number) and `results-final.md` (the tables) are written. Two runs give identical files (checked: three runs).

It needs: `gcc` and `python3`, `git`, an `hbnf` binary to generate the assembler's parser (`HBNF` and `HBNF_TEMPLATES`; default `/tmp/hbnf-latest/hbnf`, else `/tmp/hbnf` with `../hbnf/templates`; `tools/build-hbnf.sh` builds one), the OpenBSD sources (`OPENBSD_SRC`, default `../openbsd-src`) and `../pcc` (`PCC`). The pins can be overridden with `BASE_PDP`, `BASE_PCC`, `NOW_PDP`, `NOW_PCC`; a result made with other pins says so.

Two things to know when reading the result:

* **The cycles are the weaker figures.** The two sides run on two different simulators (the timing model and the linked layout changed with the instruction set), so cycles are not compared on one machine as they were in the experiment. The script runs a control: the programs whose compiled code is the same text on both sides (12 of 36 at the time of writing) still differ by 1.8% (scalar) and 5.9% (dual) in cycles, which is the simulator and the layout, not the compiler. Instructions executed and bytes fetched do not have this effect.
* **The stand-in headers.** The experiment's own directory of `<machine/...>` headers was not kept; the script uses the amd64 headers of the OpenBSD tree (little-endian LP64), and the corpus then is 624 files (the experiment had 622; the groups agree but sys/crypto, 24 against 23). The base compiler is the later pcc `82d5006b`, so totals differ a little from the experiment's tables below (165,978 instructions against 171,249).
* The script measures the real flag-free compiler and machine, not the experiment's variant: it includes the floating-point compare-and-branch, `setCC`, the long forms of the unsigned compare-and-branch and the flag-free fallback, which the experiment estimated.

Helpers: `scripts/measure.py` (corpus, programs, tables), `scripts/prog/`, `scripts/run/`, `scripts/inc2/`, `scripts/prelude.h` (inputs). The other scripts of `scripts/` are the experiment's own, with the paths of its machine.

---

# The no-flags experiment as first run (the record)

Run on 2026-11-26 as the experiment of `docs/encoding-work/instruction-pass.md`, section C11: make the compiler form a compare-and-branch (`cbCC`) for **every** integer comparison, never emit an instruction that reads the flags, assemble the same corpus, count bytes and instructions, then run programs. The test written there: **under about 1% more bytes and fewer instructions executed: flags are a feature kept for heritage alone; several percent more bytes: they earn their place.** Nothing in the main tree, `../pcc`, `../llvm-pdp64` or the shared `build/` was touched: the work was done in a git worktree of HEAD (`as64`, `ld64`, `sim64`, `encdis` built there) and on a copy of `../pcc` (the 32-register `ccom`, `-m pdp64/32`, every optimisation on by default), all under `/tmp`. The plain-words page is `../../flags-experiment.md`.

## 1. Verdict (against the pass's own test)

| measure | baseline pcc to no-flags pcc | the test asks |
|---|---|---|
| static bytes (622 files, as64 plain) | **+0.54%** (+0.58% with the estimated flag-free fallback for the far unsigned branches, first caveat below) | under about 1% |
| static bytes after ld64 relaxation | +0.57% (+0.60%) | |
| static instructions | +0.16% (+0.19%) | |
| instructions executed (36 programs, 70.6 M) | **-0.04%** (fewer) | fewer |
| bytes fetched (executed) | +1.58% | |
| cycles, scalar core / dual-issue core (sim64 timing model, ideal memory) | -0.21% / -0.89% | |

**By the test, flags are heritage only for integer code**: the corpus grows by about half a percent, not several, and fewer instructions are executed. The baseline compiler already turns about 90% of its comparisons into `cbCC` (12,499 `cbCC` against 1,239 `CMP`, 70 `TST` and 164 `SET` in the corpus); what is left for flags in compiled integer code is small (of the instructions executed, 1.6% are a flag branch and 1.6% the `CMP` before it; after the change 0.013% remain, all of them the assembler's own fallback). LLVM, which has never used them, is 21% fewer instructions and 15% fewer bytes than pcc on the same 354 files (the gap has nothing to do with flags).

What the verdict does **not** cover, and where it could be wrong (details in sections 4 and 7):

* **Floating point keeps flags**: `FCMP` writes N, Z, V and the branch after it reads them; 201 sites in the corpus (all in libm), and LLVM's output has the same 93 `FCMP`+flag branch pairs. No integer-only change removes them; a floating-point compare-and-branch or compare-into-register would be new instructions.
* **The four unsigned compare-and-branch conditions (`cs cc hi los`) have no long form.** `as64` measured: with an immediate they reach somewhere between 1.2 and 6 KB, register against register about 1 KB, and a farther target is turned by the assembler back into `CMP` + `bCC`, which **writes and reads the flags**; the signed conditions and `eq`/`ne` have six-byte forms that reach 40 KB and more. This happens at 3 sites in the baseline and **46 in the no-flags build** (an unsigned compare against a wide constant or a memory operand goes through r12 and so uses the register form), and the 9,468 executions of those in the programs are the only flag reads left in the no-flags runs. An ISA without flags would give the unsigned conditions long forms (six bytes, like the signed ones); I did not implement a flag-free fallback in the assembler (`cbNOT` over a `br`) and instead counted the sites and estimated it (+1 instruction, +4 bytes each: +0.04% in bytes).
* **The corpus is mostly C library code compiled by a compiler that already prefers `cbCC`.** It has little floating point (libm is compiled, not run), no interpreter and no database, and the programs are 12 of 100,000 instructions or more. The old figure of 18.5% of instructions touching flags (instruction-pass.md) was for a compiler that did not yet fuse compare and branch.
* **The timing model gives the compare inside `cbCC` no cost of its own** (a flag branch and a `cbCC` both resolve at issue; a compare and the flag branch after it just cannot issue in the same cycle on the dual preset). Real hardware needs a comparator in the branch stage (about 550 NAND2-equivalents, section 6), which the model does not charge. So the cycle gain is optimistic; treat the cycles as "not worse".

## 2. What was built

* `noflags-peep.patch`: the patch against `arch/pdp64/peep.h` of pcc (305 lines of diff; 0e986e01 plus nothing else). With the environment variable `PDP64_NOFLAGS` set, after the compiler's own optimisation passes a new pass `pp_noflags` rewrites every flag reader that follows a flag writer, and the SET idiom is made flag-free:
  * `cmp ra,rb` / `cmp ra,#imm` (16-bit immediate) / `tst ra` then branches: each branch becomes `cbCC` (a chain of branches after one compare, as a three-way switch compare has, is handled);
  * `cmp ra,mem` and `cmp ra,#wide`: the compare becomes a load of the operand into the scratch register r12 (`movq mem,r12`; `movq #imm,r12` or `movq =K,r12`), the branches `cbCC ra,r12`;
  * an ALU instruction whose result is then tested for zero (`and ...; beq`): `cbeq rd,#0`; the signed senses (`sub; bgt`) the same; carry of an add: `cbcs`/`cbcc sum,addend` (no site in the corpus needed it);
  * a comparison used as a value (`cbX a,b,Lf ; movq #1,rd ; br|ret ; Lf: clr rd` which the baseline turns into `CMP` + `SET`): `movq #1,rd ; cb(not X) a,b,L ; clr rd ; L:` (three instructions, the sequence the LLVM back end writes) when rd is neither operand; otherwise the branchy form that the compiler writes before its own idiom pass.
  * Whatever the pass cannot rewrite is counted (`PDP64_NOFLAGS_LOG=1`): 201 sites, all `FCMP`.
  The patch is gated on the environment variable so that one binary builds both variants.
* `scripts/`: `corpus.py` (compile every source with pcc or with clang + `llc -O2`, assemble with `as64 --no-relax`, histogram the mnemonics), `relax_sizes.py` (the size after `ld64` relaxation), `run_progs.py` (compile, link with the crt of `tools/pdp64test.sh`, run on `sim64` with four timing presets), `dynmix.py` (executed instructions by kind: `sim64 -P` and `encdis -k`), `summarize.py` (the tables below), `flagsites.py`, `carrysites.py`, `cppflags.sh`, `prelude.h`, `inc2/` (the few header stand-ins), `prog/` (the drivers I wrote: `zlibd.c`, `crypto.c`, `libcd.c`, `stubs.c`, `zutil_stub.c`), `gates/flags.v` and `run-all.sh` (the order of the commands).
* `results/`: `tables.md` (all tables), `static-per-file.csv`, `static-kinds-per-file.csv` (every file's instructions, bytes and number of each kind of compare, branch and flag instruction, for the three builds), `dynamic.csv`, `dynmix.json`, `noflags-site-classes.txt`, `carry-sites.txt`, `gates.txt`.

Method notes. Corpus: the OpenBSD files named in instruction-pass.md section 5 (libz, libc string, stdlib, gen, stdio, net, hash; `sys/crypto`), widened with libc regex, db, time, crypt, locale, quad, softfloat, gdtoa, libedit, curses, libm and eleven `usr.bin` programs, plus `tests/c`, `tests/c-new` and `docs/encoding-work/bench/sc/src`: 1,104 files tried, preprocessed with the host `gcc -E` (OpenBSD headers, a few stand-ins), compiled by pcc (`-m pdp64/32`, defaults) and by clang (the recipe of the instruction pass) + `llc -O2` (../llvm-build-22). The corpus of 841 files of the earlier passes is not on this machine. "Relaxed" is the plain size plus the change that `ld64` reports for the object's own sites (each object linked alone against stubs for its undefined symbols); the assembler's own count is the plain one.

## 3. Static results

### T1. What compiled

| group | files | pcc compiles | LLVM compiles | both |
|---|---:|---:|---:|---:|
| libz | 15 | 14 | 10 | 9 |
| libc-string | 79 | 71 | 73 | 68 |
| libc-stdlib | 66 | 52 | 32 | 32 |
| libc-gen | 125 | 89 | 58 | 58 |
| libc-stdio | 103 | 33 | 22 | 22 |
| libc-net | 47 | 40 | 28 | 26 |
| libc-hash | 7 | 3 | 1 | 1 |
| sys-crypto | 28 | 23 | 21 | 20 |
| libc-regex | 5 | 4 | 2 | 2 |
| libc-db | 29 | 28 | 1 | 1 |
| libc-gdtoa | 20 | 0 | 0 | 0 |
| libc-time | 7 | 7 | 2 | 2 |
| libc-crypt | 6 | 5 | 2 | 2 |
| libc-locale | 49 | 32 | 24 | 23 |
| libc-quad | 26 | 0 | 0 | 0 |
| libc-softfloat | 24 | 0 | 0 | 0 |
| libedit | 24 | 3 | 0 | 0 |
| libcurses | 52 | 0 | 0 | 0 |
| libm | 225 | 145 | 76 | 48 |
| ub-awk | 8 | 0 | 0 | 0 |
| ub-lex | 20 | 2 | 1 | 1 |
| ub-yacc | 12 | 12 | 5 | 5 |
| ub-sort | 7 | 7 | 1 | 1 |
| ub-bc | 1 | 0 | 0 | 0 |
| ub-dc | 6 | 0 | 0 | 0 |
| ub-diff | 4 | 4 | 0 | 0 |
| ub-sed | 4 | 4 | 0 | 0 |
| ub-grep | 6 | 0 | 0 | 0 |
| ub-m4 | 7 | 5 | 0 | 0 |
| ub-cmp | 4 | 4 | 0 | 0 |
| ub-tsort | 1 | 0 | 0 | 0 |
| libcrypto | 53 | 2 | 0 | 0 |
| tests-c | 5 | 5 | 5 | 5 |
| tests-c-new | 21 | 20 | 21 | 20 |
| bench-sc | 8 | 8 | 8 | 8 |
| **all** | **1104** | **622** | **393** | **354** |

### T2. Static totals, pcc, the files pcc compiles (622 files)

| | instructions | bytes, plain | bytes, relaxed by ld64 | cbCC the assembler turned back into CMP+Bxx |
|---|---:|---:|---:|---:|
| baseline | 171249 | 504840 | 485818 | 3 |
| SET given up only (no setcc idiom) | 171577 | 505296 | 486306 | 3 |
| no flags (variant) | 171531 | 507586 | 488580 | 46 |
| change, SET only | +328 (+0.19%) | +456 (+0.09%) | +488 (+0.10%) | |
| **change, no flags** | **+282 (+0.16%)** | **+2746 (+0.54%)** | **+2762 (+0.57%)** | +43 sites |
| no flags, plus the flag-free fallback for those sites (estimate: one more instruction and four more bytes each) | +325 (+0.19%) | +2918 (+0.58%) | +2934 (+0.60%) | |

### T4. Static count of each kind of compare, branch and flag instruction (same 622 files for the two pcc builds; LLVM on the 393 files it compiles)

| kind | pcc baseline | pcc no-flags | LLVM (own files) |
|---|---:|---:|---:|
| CMP | 1239 | 0 | 0 |
| TST | 70 | 0 | 0 |
| flag branches (Bxx) | 1969 | 201 | 93 |
| SET | 164 | 0 | 0 |
| ADC/SBC | 0 | 0 | 0 |
| FCMP | 201 | 201 | 93 |
| compare-and-branch (cbCC) | 12499 | 14431 | 5921 |
| br/jmp | 6269 | 6317 | 1963 |
| sob | 64 | 64 | 0 |
| all instructions (by mnemonic count) | 171246 | 171485 | 70059 |

The Bxx left in the no-flags build, and the CMP, follow an FCMP (floating-point compare), and are floating-point only; the LLVM ones likewise. `fcmp`, `fcmp32`: the flags remain for floating-point in both compilers.

### T5. The files all three builds compile (354 files)

| | instructions | bytes (plain) | bytes per instruction |
|---|---:|---:|---:|
| pcc baseline | 82950 | 232964 | 2.81 |
| pcc no flags | 83142 | 234200 | 2.82 |
| LLVM -O2 | 65598 | 198618 | 3.03 |
| LLVM against pcc no-flags | -21.1% | -15.2% | |

Reading T2: giving up `SET` alone (the compiler's idiom pass off) costs +0.19% instructions and +0.09% bytes; the rest of the byte growth is the compare-and-branch forms that need an operand in a register. Where the bytes go, by kind of site (counts from the compiler log, `results/noflags-site-classes.txt`; byte change of a typical pair measured with `as64`):

| site | count | instructions | bytes each |
|---|---:|---|---|
| `cmp reg,#wide ; bCC` (immediate above 16 bits) becomes `movq #imm,r12 ; cbCC reg,r12` | 623 | same (2 and 2) | +4 (6 to 10) |
| `cmp reg,mem ; bCC` becomes `movq mem,r12 ; cbCC` | 475 | same | +2 (6 to 8) |
| ALU result tested against zero: `and ..; beq` becomes `and ..; cbeq r,#0` | 583 | same | 0 when the target is near (the 2-byte `cbeq` against zero), +2 otherwise |
| `sub ..; bgt|ble` | 43 | same | +2 |
| `cmp ; bCC` the baseline could not fuse (flags judged live, label or range) becomes one `cbCC` | 39 | -1 each | -2 |
| `tst ; bCC` | 28 | -1 each | 0 to -2 |
| `cmp ; set` made flag-free | 27 | +1 | +4 (4 to 8) |
| `FCMP` + flag branch (unchanged) | 201 | | |

By group (pcc): `libc-regex` is the worst group (+3.3%, 4 files), the tests (+1.1% to +4.4%, 25 files of a few hundred bytes) are noisy, and `sys/crypto`, `libz`, `libc-stdio` and `libc-hash`, the code the pass cared about, are -0.04% to +0.4% (`results/tables.md`, T3).


## 4. Dynamic results

Twelve programs run for 100,000 instructions or more on `sim64` (zlib deflate and inflate of 50 KB of text from the OpenBSD `libz`; MD5, SHA-1, SHA-256, SHA-512, RIPEMD-160, Blowfish and Poly1305 over 64 KB from `sys/crypto`; qsort, heapsort, bsearch, strtol and the string routines of OpenBSD libc; the eight programs of `bench/sc`: sort, hash, copy, matmul, sha, lz, list, hist; and `divmagic`), and 24 small test programs (`tests/c`, `tests/c-new`; `c-new/switch_tree` does not assemble with either pcc build: a pcc output problem that was there before). **Every program prints the same result under the baseline, the no-flags build and LLVM** (checksums equal). Timing presets are those of `tools/timing.py`: `scalar` (one issue, 8 bytes/cycle fetch, ideal memory), `dual` (two issue, 16 bytes, BTB), and the same two with 16 KB caches.

### T6. Dynamic: the programs that run on sim64 (programs of 100,000 instructions or more)

| program | insns base | insns no-flags | % | bytes fetched base | % | scalar cycles base | % | dual cycles base | % | LLVM insns | LLVM scalar cycles | LLVM dual cycles | output |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| zlib | 18169459 | 18174216 | +0.03 | 55544944 | +0.62 | 28163820 | -0.16 | 24507147 | -0.23 | 13889991 | 19156863 | 13999537 | equal |
| crypto | 17837016 | 17852391 | +0.09 | 47308902 | +0.55 | 23339746 | +0.09 | 18826957 | +0.02 | 16268017 | 17920015 | 13427901 | equal |
| libc-sort-string | 6284747 | 6284745 | -0.00 | 17993330 | +0.41 | 11362577 | -1.34 | 9492169 | -2.38 | 5486085 | 8493306 | 5898637 | equal |
| bench-sc/copy | 820401 | 820401 | +0.00 | 3380856 | +0.00 | 1116529 | +0.00 | 689957 | +0.00 | 378011 | 542741 | 361955 | equal |
| bench-sc/hash | 1436749 | 1436749 | +0.00 | 5189680 | +0.00 | 2689197 | +0.00 | 2266732 | +0.00 | 1244753 | 1751883 | 1459278 | equal |
| bench-sc/hist | 3542132 | 3542132 | +0.00 | 12008248 | +13.10 | 5313558 | +0.00 | 4329708 | -6.81 | 4032870 | 5509128 | 3836659 | equal |
| bench-sc/list | 492117 | 492117 | +0.00 | 1632316 | +0.00 | 912555 | +0.00 | 744527 | +0.00 | 504108 | 972510 | 744494 | equal |
| bench-sc/lz | 5135319 | 5135319 | +0.00 | 15752876 | +5.79 | 7637015 | +0.05 | 5778188 | -2.15 | 3359999 | 4795466 | 3786288 | equal |
| bench-sc/matmul | 2185197 | 2185197 | +0.00 | 6186840 | +0.00 | 3214099 | +0.00 | 2731752 | +0.00 | 809563 | 1268546 | 1026196 | equal |
| bench-sc/sha | 5836934 | 5786758 | -0.86 | 16114100 | +0.41 | 7191121 | -0.70 | 5325363 | -0.92 | 6858898 | 7460428 | 4991531 | equal |
| bench-sc/sort | 2431075 | 2431075 | +0.00 | 8547896 | +0.38 | 4280211 | +0.00 | 3446054 | -0.48 | 3064958 | 4243710 | 2877435 | equal |
| c-new/divmagic | 6425676 | 6425676 | +0.00 | 16918026 | +0.00 | 9466083 | +0.00 | 7416103 | +0.00 | 7146734 | 9678117 | 5723670 | equal |
| **total (12 programs)** | 70596822 | 70566776 | -0.04 | 206578014 | +1.58 | 104686511 | -0.21 | 85554657 | -0.89 | 63043987 | 81792713 | 58133581 | |

Totals of the same programs for the other timing presets (cycles; base, no-flags, % ; LLVM):

| preset | baseline | no flags | % | LLVM |
|---|---:|---:|---:|---:|
| scalar | 104686511 | 104464125 | -0.21 | 81792713 |
| dual | 85554657 | 84789992 | -0.89 | 58133581 |
| scalar-c | 120451672 | 120165913 | -0.24 | 97097268 |
| dual-c | 101577369 | 100778766 | -0.79 | 74127244 |

### T8. Executed compare, branch and flag instructions (all 36 programs, sim64 -P)

| kind | pcc baseline | pcc no flags | LLVM |
|---|---:|---:|---:|
| cmp | 1098620 | 9468 | 16024 |
| tst | 103 | 36 | 36 |
| flag branch | 1129184 | 9468 | 16024 |
| set | 42145 | 36 | 36 |
| cbCC | 6366570 | 7528395 | 8195209 |
| br/jmp | 1215526 | 1230957 | 927304 |
| sob | 260177 | 260177 | 0 |
| total | 70645362 | 70615693 | 63051047 |

`pcc` needed `-xno-temps` for `inftrees.c` only (a compiler error otherwise, in the baseline compiler; the same flag in both variants). Two things in the dynamic table are not about flags in the ISA: the `sha` and `jtab` rows have fewer instructions because the baseline compiler left three compare-and-branch pairs as `cmp ; blt` (it judges the flags live, conservatively, at a label) and the pass fuses them: a small gain that comes from the compiler being freed of the flag bookkeeping, not from the instruction set. And `hist` (+13% bytes) is the wide-constant case: `cmp r15,#98304 ; blt` is six bytes plus two, against `movq #98304,r12 ; cblt` ten plus four, in the loop; the compiler should hold such a constant in a register across the loop, and does not.

The numbers of the table are those of the whole run, driver included; the same programs under LLVM execute 10.7% fewer instructions, 21.7% fewer cycles (scalar) and 31.4% fewer (dual) than the no-flags pcc on the twelve (`T6`); the programs the compilers can both compile give the static comparison of T5.


## 5. The carry cases

* `ADC` and `SBC` (the add-with-carry and subtract-with-borrow of the PDP-11, for multi-word arithmetic) are emitted **zero times** by pcc (baseline, 171,249 instructions) and by LLVM (70,114), and no assembly file of the repository (`tests/`, the hypervisor snippets) uses them. The compilers have no multi-word type that needs them: the registers are 64 bits wide and `__int128` is not supported. So the number of multi-precision sites in this corpus that depend on `ADC` is **0**.
* **Add with carry out, as an idiom** (`s = a + b; if (s < a)`): the sites where an `add` is followed within six instructions by an unsigned test of the sum against an addend are **6 in the baseline** (plus 5 where the baseline recompares with `cmp`), **7 in the no-flags build, and 1 in LLVM's output** (`results/carry-sites.txt`): about 0.004% of the instructions. With the carry flag the idiom is `add b,a ; set cs,t` (after the add the carry is already there); without it, the test of the sum is a compare-and-branch against the addend, which the compiler does anyway (`add b,a ; cbcs a,b,L`): no extra instruction when the carry is used as a branch condition; when it is wanted as a 0 or 1 in a register (a carry into the next word) it is `movq #1,t ; cbcs a,b,L ; clr t ; L:` (three instructions against two with `ADC`/`SET`).
* **A double-word add `(a1:a0) += (b1:b0)`** without a carry flag: `add b0,a0 ; clr t ; cbcc a0,b0,L ; inc t ; L: add t,a1 ; add b1,a1` = **6 instructions against 2** (`add ; adc`), 14 bytes against 4 (the branch is taken half the time on random data, and the sequence has a mispredictable branch; a branch-free version needs a compare-into-register instruction that this machine does not have). A triple-word add is 10 against 3, and so on: three instructions per extra word. The cost matters only to code that adds multi-word numbers (bignum, a 128-bit counter); `mulh` (high half of a multiply) already gives the other multiply half. 0 sites in the corpus, but the corpus has no bignum code (libcrypto's `bn` did not compile with pcc: missing headers).

## 6. What the flags cost the hardware and the context

From the repository's own documents (`docs/pdp64-ooo-readiness.md`, dated 2026-10-22, which the author later acted on in part; `docs/manual/06-kernel.md`; `docs/encoding-work/hypervisor-text-v3.md`; `docs/encoding-work/vec-gates.md`); the "[M]" numbers there were made on the earlier 16-register compiler.

* **State.** The four flags N, Z, V, C are bits 3 to 0 of the 16-bit processor status word. They are saved with the status word (exception entry saves `EPSW`, the hypervisor exit saves `HEPSW`: "the guest's whole status word") and cleared on exception entry. So **four bits, in a word that is saved anyway**: no extra register in a context switch or in a world switch, no instruction to save them. Without flags those four bits are reserved and `MFPS`/`MTPS` (the user-mode `MTPS`, which writes only the flags) lose their flag use.
* **Pipeline.** In an in-order core flags are one more result per flag-writing instruction and a one-cycle dependence between a compare and its branch (which the timing model charges and `cbCC` avoids). In a wide out-of-order core they are a hidden register to rename: the ooo-readiness review counts 68.2% of the corpus's instructions writing a flag at the time, and its decisions (flags are two independent groups, `{C}` and `{N,Z,V}`; moves, loads, stores and `cbCC` write none) brought that to **16.7% in its static count** (56,098 of 336,408). By my dynamic profile of the baseline pcc programs, **36% of the instructions executed write flags** (the ALU group: `add sub and bis bic xor inc dec shl shr sar mul` and so on) **and 1.6% read them**; the no-flags build has 34.5% writing and 0.013% reading: the writes are still there (the instructions are the same), only the reasons for them are gone. Move elimination at rename, which the review found blocked while moves wrote flags, is no longer an issue for flags since moves no longer write them.
* **Gates.** A flag unit (four flip-flops with per-flag write enable and source selection, the 64-input zero detect on the result, and the evaluation of the 14 conditions) synthesised with `tools/gates/gates.sh` (yosys, abc to NAND2): **178 NAND2-equivalents of logic plus 4 flip-flops**. For scale, from the same script: the `cbCC` comparator (equality, signed and unsigned less-than on two 64-bit registers) is 548, a 64-bit adder 675, the 64-bit ALU 4,058, and the scalar core 219 k to 308 k (`vec-gates.md`). So the flag unit is **about 0.06% to 0.09% of the scalar core**; the comparator that the no-flags machine needs in the branch stage already exists for `cbCC`. This estimate counts only the flag register and the condition decode (`gates/flags.v`); it does not count the wires that bring the carry and overflow out of the ALU, the wider decode of the 14 branch words, `SET`, `TRAPCC`, or the verification effort, and it does not count the out-of-order rename of the flags, for which the repository has no number. **The gate saving is small; the case for removing flags is a simpler specification and a shorter list of "which instruction writes which flag", not area.**

## 7. What could not be run, and the limits

* **The corpus of the earlier passes (841 files, 370,115 instructions) and the six large programs (lz4, zlib, Lua, three BearSSL groups) are not on this machine.** I used 622 files that pcc compiles (of 1,104 tried; 393 for LLVM; both 354) and 12 programs of 100,000 instructions or more. pcc fails on the others for front-end reasons (`undefined struct or union` from FILE-using stdio headers, `redeclaration of cimagl` in libm, K&R and missing headers; first error per file in `results/static-per-file.csv`); `libc/gdtoa`, `quad`, `softfloat`, `libcurses`, `awk`, `grep` and `dc` give no file at all.
* **No floating-point program was run**: libm is compiled (145 files) and counted statically; no driver exercises it.
* **No flag-free fallback for the far unsigned `cbCC`** (no long form exists, section 1): the 46 sites are counted and estimated, not built; the assembler's own expansion (`CMP` + `bCC`) remains in the no-flags objects and is the only flag reader in the dynamic runs (9,468 executions, 0.013%).
* **`c-new/switch_tree.c` does not assemble** in either pcc build (an output the assembler rejects at line 262); `libz/inftrees.c` compiles only with `-xno-temps` (same flags both variants).
* **The cycle numbers are the model's**: ideal memory for `scalar` and `dual`, 16 KB caches for the `-c` presets, no cost for the comparator of `cbCC`. They are not a silicon measurement.
* **The variant is a compiler experiment, not a design**: the scratch register r12 holds the wide constant and the memory operand (a smarter compiler would keep the constant in a register across a loop, and would choose `cbCC` against zero for more tests); the assembler and the hardware were not changed (the ISA still has flags; the test is what a compiler that never reads them costs).
* **Gate counts** are for the flag unit alone, as stated above.

## 8. Tables

The full tables, including T3 (by group) and T7 (all 36 programs), are in `results/tables.md`; the raw per-file and per-program numbers are in the CSV files there.
