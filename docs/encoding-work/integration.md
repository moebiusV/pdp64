# Integration report: the encoding work merged, the compiler combined, the final table

Branch `enc-int` of `<worktree>` (from `enc-hb`). Nothing was merged into `main`, nothing was pushed. pcc: `<work>/pcc-enc`, branch `enc-prefix` of pcc, **one small commit was made there** (see 3.2).
Work files: `scratchpad/int/` (scripts `corp.py`, `corpus.py`, `build6.py`, `runtm.py`, `norelax.py`, `runsmall.py`, `final.py`, logs, `final.md`).

## 1. The merges

Order and result (each merge was followed by a rebuild and a complete `tools/check-all.sh`; logs `scratchpad/int/ca-*.log`):

| # | Merge | Conflicts | Resolution | check-all after |
|---|---|---|---|---|
| 1 | `enc-cb` | none: fast-forward of `enc-hb` | | rc 0 (1 min 15 s) |
| 2 | `enc-ld` | `docs/errata.md` (both added entry 89), `spec/README.md` (the "Commands" list), `docs/codegen-data/encoding/asm_vs_model.py` (doc string) | errata: the relaxation entry became **91**; README: both command lists combined, grammar wins (`export_forms.py OUTDIR`); doc string: the grammar text plus `--no-relax`. `tools/check-ld-relax.py` still read `spec/pdp64-NN/forms.json`: now `encgram.load(tag, ROOT)`. `docs/relaxation.md` "errata 89" -> 91. The default (relaxation on) is kept. `tools/mk_ld_tests.py` was already on the grammar in `enc-hb` and merged without a conflict (the file that enc-ld edited was in `docs/codegen-data/encoding/` and untouched by enc-ld). | rc 0 (2 min 4 s): relax 80 run, 0 failed; mutants 7, all caught |
| 3 | `enc-tm` | none; no file read `forms.json` | | rc 0: timing 128 checks, 0 failed |
| 4 | `main` (head at the time `d40516b`, then `d40516b` again after the coordinator's note; the merge that was made includes the fpga-plan row) | `docs/errata.md` (entry 91 on both sides) | main's core-count entry became **92**; its numbering note rewritten; `docs/smp-decisions.md` "errata 91" -> 92, and its statement that the encoding branches are unmerged updated | rc 0 |

Errata numbering of the integrated tree (gap-free 80..92): 87 phase 1 (the author's decisions), 88 sim64 (phase 2), 89 grammars are the source of truth (the author's correction), 90 cbCC reach, **91 linker relaxation (was 89 on `enc-ld`)**, **92 core counts (was 91 on main)**. Cross-references changed: `docs/relaxation.md` (two places, "errata 91"), `docs/smp-decisions.md` (two places). The references to 87 and 88 in code comments (`common/pdp64exec_enc.inc`) and docs are unchanged and right; `spec/README.md` "entry 89" refers to the grammar entry and is right.

Nothing was red after any merge; the first run of each was green. The wall time of a check-all is 1-2 minutes.

## 2. The tools in the repository for the new compiler

* `tools/build-pcc.sh`: builds `build/pcc/ccom` (16 registers: r20 and /16) and `build/pcc/ccom32` (`-DPDP64_REGS32`, /32) from `PCC` (default `<work>/pcc`; the new targets need `PCC=<work>/pcc-enc` until the branch is merged into pcc's main).
* `tools/pdp64test.sh`, `tools/pdp64test-all.sh`: target-aware (`-m pdp64/r20|16|32`), default tools in `build/`, tests from `tests/c` plus the 21 programs of the new targets in `tests/c-new` (copied from pcc's `arch/pdp64/test/c`).
* `tools/pdp64size.py`: `PDP64_TARGET=pdp64/16|pdp64/32` selects `ccom -m`, `as64 -m` and counts instruction bytes with `as64 --stats` (the r20 length walk and its statistics stay r20-only). Not exercised here on the full fair corpus (it needs the v7unix-toolchain corpus builds); the measurements below use `corp.py` on the 841 preprocessed files.

## 3. The combination with the compiler

### 3.1 Build and tests (integrated as64, ld64, sim64; default relaxation; re-optimised grammars)

* Compiler: pcc-enc `enc-prefix` with the fix of 3.2, built by `arch/pdp64/test/build-ccom.sh` (`ccom`, `ccom32`).
* pcc's harness, run from the repository (`tools/pdp64test-all.sh -m ...`, each test under the flag sets of the harness): **r20 602/602, pdp64/16 963/963, pdp64/32 963/963** (the earlier 602, 954, 954 plus the new test `ccp_signedness` under 9 flag sets).
* All 841 corpus files compile and assemble with the integrated `as64` for /16 and /32 (and r20): 841/841, 0 failures. Linked one at a time with a stub (the relaxation measurement) 840 of 841: `pr79286.c` does not link, relaxed or not (a 64-bit constant used as a displacement; the same as before).
* The six programs (lz4, zlib, Lua, three BearSSL kernels; the stand-in libc and crt of `scratchpad/dyn/rt`, `crt32.s` for /32): linked and run on r20 (old compiler), /16 and /32 (new compiler, default relaxation): **18 of 18 print exactly the host gcc output and exit 0**; also run linked `--no-relax`: same.
* c-testsuite: 213 programs, results (status and stdout) identical in the three encodings, **206 pass in each** (as before); gcc-torture: 169 programs, 168 identical in the three, **147 pass in each**; the one that differs, `pr116799`, has a `main` without a return value (exit status = an address; errata 88), as before.
* `tools/check-all.sh` on the final tree: see section 6.

### 3.2 What the combination found: a compiler bug (fixed, committed in pcc-enc)

With the new compiler and the integrated tools, c-testsuite `00104` returned 1 on /16 and /32 (0 on r20): `int x = ~0; if (x != 0xffffffff) return 1;`. The cause is in the compiler's `-xccp` (conditional constant propagation, new in the phase 4 of the compiler, on for the new targets): a temporary holding the `int` value -1 was read as `unsigned` without normalising the value to the type of the read, so it compared 0xffffffffffffffff with 0xffffffff. This is not an incompatibility between the compiler and the toolchain; it was in the compiler and was not found before because the last c-testsuite run was made with the phase 3 compiler (before `-xccp`). Fix: `cp_eval` normalises a TEMP's value to the type of the read (`mip/optim2.c`), commit `5e580523` in `<work>/pcc-enc` (branch `enc-prefix`): "pdp64 ccp: a temporary read in another type than it was written in is normalised ...", with the test `arch/pdp64/test/c/ccp_signedness.c` (copied to `tests/c-new/`). After the fix: ct 206/206/206 and gt 147/147/147. The sizes below are of the fixed compiler.

No other incompatibility was found: the merged grammars accept everything the compiler emits (0 assembler failures), the compiler needed no change for the re-optimised `cbCC` lengths (the compiler forms a `cbCC` where the codes are dead and the assembler expands the ones that do not reach; after re-optimisation that is 0 sites in the /16 corpus, 13 in /32, and 6+6 sites / 79,894 executed pairs in the six /32 programs).

## 4. The final table

Compilers: **old** = the pcc before the work (= `ccom -m pdp64/r20` of pcc-enc, whose output is byte-identical to it on all 841 files; flags of the original harness `-xdmr -xtemps -xdeljumps -xinline -xdce`); **new** = pcc-enc `enc-prefix` HEAD with all optimisations on by default (`-m pdp64/16` or `/32`). There is no "r20 with the new compiler": the compiler's new optimisations exist only for the new targets by design (r20's output must not change) and several of them use instructions r20 does not have. Assemblers and linker are the integrated ones (default relaxation unless stated).

### 4.1 Static, the 841-file corpus (bytes of instructions; `as64 --stats`, r20: the length walk of `pdp64size.py`)

| | pdp64/r20, old compiler | pdp64/16, new | pdp64/32, new |
|---|---:|---:|---:|
| instruction bytes, 841 files | 1,083,870 | **934,470** (-13.78%) | **964,158** (-11.04%) |
| without `memcpy-a2.c` (27% of the bytes) | 785,836 | 676,354 (-13.93%) | 706,042 (-10.15%) |
| instructions | 338,313 | 300,821 | 296,070 |
| /32 against /16 | | | +3.18% (+4.39% without memcpy-a2), -1.58% instructions |
| fused pairs emitted (movcall / popmret / popret / mov2) | 0 | 10,757 / 2,246 / 2,609 / 4,049 = 19,661 | 11,531 / 1,608 / 2,586 / 4,061 = 19,786 |
| cbCC substituted by cmp + bCC (far, no form) | 0 | **0** | **13** |
| text section of the objects (instructions + pools + padding), 840 files, before linking | 1,305,878 | 1,167,388 | 1,197,018 |
| the same linked with relaxation (one file at a time with a stub) | not applicable | **1,122,322** (-3.86% against unrelaxed) | **1,152,010** (-3.76%) |
| (without memcpy-a2) | | 909,272 -> 881,394 (-3.07%) | 938,902 -> 911,082 (-2.96%) |

Relaxation applies to the text of the object (instruction bytes plus constants in text plus padding): 45,066 bytes /16 and 45,008 bytes /32; by category /16: external call 20,333 sites, -40,666 bytes; data lea 12,787 sites, -1,802; pc-relative loads -1,588; `jmp` to another section -718; branches -266. The corpus stub places symbols right behind the file, so the saving is an upper bound for the 4-byte call's reach.

### 4.2 The six large programs (stand-in libc and crt included, "all code")

Linked text (relaxed), executed instructions and bytes (`sim64 -P`), fused instructions executed, frame loads and stores executed:

| program | enc | instructions | bytes | B/insn | linked text | fused executed | frame ld+st |
|---|---|---:|---:|---:|---:|---:|---:|
| lz4 | r20 | 139,660,315 | 398,515,750 | 2.853 | 21,688 | 0 | 25,652,492 |
| lz4 | 16 | 133,184,861 | 338,970,284 | 2.545 | 18,624 | 4,409,842 | 24,582,187 |
| lz4 | 32 | 124,310,598 | 339,453,504 | 2.731 | 19,368 | 5,129,967 | 12,881,936 |
| zlib | r20 | 172,934,529 | 491,311,946 | 2.841 | 53,042 | 0 | 14,909,660 |
| zlib | 16 | 155,852,368 | 420,931,112 | 2.701 | 47,494 | 105,187 | 14,905,140 |
| zlib | 32 | 140,984,531 | 401,341,246 | 2.847 | 48,406 | 54,395 | 12,086 |
| lua | r20 | 233,250,134 | 886,211,648 | 3.799 | 106,774 | 0 | 10,508,510 |
| lua | 16 | 137,624,333 | 373,646,346 | 2.715 | 91,506 | 4,651,438 | 9,633,670 |
| lua | 32 | 128,261,142 | 389,278,300 | 3.035 | 94,466 | 4,374,183 | 134,164 |
| bs_hash | r20 | 65,301,679 | 195,789,896 | 2.998 | 12,582 | 0 | 133,837 |
| bs_hash | 16 | 63,532,270 | 182,763,088 | 2.877 | 11,110 | 432,238 | 113,296 |
| bs_hash | 32 | 63,407,145 | 185,486,460 | 2.925 | 11,508 | 430,020 | 2,186 |
| bs_sym | r20 | 73,616,137 | 195,959,992 | 2.662 | 17,728 | 0 | 15,155,516 |
| bs_sym | 16 | 72,035,816 | 176,833,198 | 2.455 | 15,648 | 224,289 | 14,923,987 |
| bs_sym | 32 | 69,421,025 | 202,420,622 | 2.916 | 16,656 | 216,136 | 11,239,652 |
| bs_ec | r20 | 71,053,228 | 197,437,052 | 2.779 | 14,792 | 0 | 2,576,533 |
| bs_ec | 16 | 47,525,581 | 139,906,128 | 2.944 | 12,390 | 256,617 | 1,045,423 |
| bs_ec | 32 | 46,417,515 | 162,682,454 | 3.505 | 13,000 | 176,713 | 6,171 |
| ALL | r20 | 755,816,022 | 2,365,226,284 | 3.129 | 226,606 | 0 | 68,936,548 |
| ALL | 16 | 609,755,229 | 1,633,050,156 | 2.678 | 196,772 | 10,079,611 | 65,203,703 |
| ALL | 32 | 572,801,956 | 1,680,662,586 | 2.934 | 203,404 | 10,381,414 | 24,276,195 |

Totals, six programs: against pdp64/r20 with the old compiler,

| | pdp64/16, new | pdp64/32, new | /32 against /16 |
|---|---:|---:|---:|
| instructions executed | 609,755,229 (-19.32%) | 572,801,956 (-24.21%) | -6.06% |
| bytes executed (fetched) | 1,633,050,156 (-30.96%) | 1,680,662,586 (-28.94%) | **+2.92%** |
| bytes per instruction | 2.678 (r20 3.129) | 2.934 | |
| linked text | 196,772 (-13.17%) | 203,404 (-10.24%) | **+3.37%** |
| frame loads + stores executed | 65,203,703 (-5.41%) | 24,276,195 (-64.78%) | **-62.77%** |
| fused instructions executed | 10,079,611 | 10,381,414 | |
| cmp+bCC pairs made by the assembler from far cbCC, static / executed (link without relaxation, `norelax.py`) | 0 / 0 | 12 / 79,894 (0.014% of instructions) | |

Relaxation on the programs (same objects, `ld64 --no-relax` against the default): linked text /16 200,232 -> 196,772 (-1.73%), /32 206,816 -> 203,404 (-1.65%); bytes executed /16 -0.38%, /32 -0.37%; instructions executed differ by 7,385 and 7,050 (Lua hashes addresses; output identical).

### 4.3 The timing model (merged `sim64 --timing`; ideal memory, no BTB, in-order, issue width 1 or 2, fetch window W bytes/cycle)

Source of the numbers: **a fresh sweep made for this report on the integrated tree** (set A of `scratchpad/int/runtm.py`: `iw` 1 and 2 x W 2, 4, 8, 16, plus a wide reference), not the timing agent's `scratchpad/tm/res` (those were made with an older compiler, before the `cbCC` re-optimisation and the ccp fix). Parameters as `docs/timing-model.md`; the prefix-coded encodings pay a length-decode latency of 1 cycle on every taken branch and refill (`ldecp=1`, r20 0). The model is an in-order toy that is checked to implement its stated pipeline (128 exact checks); it is not hardware: no out-of-order, no wrong path, no store forwarding.

Cycles, all six programs summed:

| model | r20, old compiler | /16, new | /32, new | /16 vs r20 | /32 vs r20 | /32 vs /16 |
|---|---:|---:|---:|---:|---:|---:|
| A.i1.W4 | 1,133,787,653 | 914,840,325 | 842,065,005 | -19.31% | -25.73% | -7.95% |
| A.i1.W16 | 1,132,005,940 | 910,610,350 | 833,536,996 | -19.56% | -26.37% | -8.46% |
| A.i2.W4 | 1,001,691,461 | 789,767,576 | 735,251,238 | -21.16% | -26.60% | -6.90% |
| A.i2.W16 | 980,828,946 | 770,126,819 | 705,190,596 | -21.48% | -28.10% | -8.43% |
| A.i1.W2 | 1,305,661,982 | 1,007,176,894 | 1,002,176,356 | -22.86% | -23.24% | -0.50% |
| A.i1.W8 | 1,132,498,455 | 912,321,819 | 837,462,140 | -19.44% | -26.05% | -8.21% |
| A.i2.W2 | 1,288,661,988 | 987,870,315 | 999,051,010 | -23.34% | -22.47% | +1.13% |
| A.i2.W8 | 981,906,949 | 772,869,876 | 711,994,647 | -21.29% | -27.49% | -7.88% |
| A.wide.i1 | 1,125,317,958 | 887,359,174 | 805,361,520 | -21.15% | -28.43% | -9.24% |
| A.wide.i2 | 964,565,423 | 746,360,902 | 675,351,572 | -22.62% | -29.98% | -9.51% |

Reading (all from the table above and the next ones):

* At every width from 4 bytes/cycle up the programs are **execute-bound**: widening the fetch from 4 to 16 bytes/cycle takes 0.2% (r20), 0.5% (/16) and 1.0% (/32) off the cycles at issue width 1. Fetch-wait is 1.6-1.7% of the cycles for r20 and 5-9% for the prefix-coded members (the length-decode latency on taken branches), execute-wait (load-use dominates) 25-39%. At 2 bytes/cycle the encodings that fetch fewer bytes win (r20 1,306 M, /16 1,007 M); there /32 loses its advantage (issue 2: /32 is 1.1% slower than /16).
* Dual issue takes 11.7% (r20), 13.7% (/16) and 12.7% (/32) off the cycles of every member (r20 1,134 M -> 1,002 M at W4).
* pdp64/16 against r20 (old compiler): -19.3% to -21.5% cycles at W>=4 (the instruction count is -19.3%, so the saving in cycles is the saving in instructions: the byte savings buy nothing at these widths); pdp64/32 against r20: -25.7% to -28.1%.
* **pdp64/32 against pdp64/16 under identical conditions (the same compiler, the same assembler/linker/grammars, the same model): -6.9% to -9.5% cycles at W>=4** (-7.95% at W4 issue 1; -8.43% at W16 issue 2; -9.2%/-9.5% with the wide reference), for -6.06% instructions, -62.8% frame accesses, +2.9% bytes executed and +3.4% text. By program (W4 / issue 1): lz4 -9.1%, zlib -13.1%, Lua -6.8%, bs_hash -0.3%, bs_sym -7.3%, bs_ec -1.8%. The extra register field costs fetch bandwidth, which does not matter at W>=4 and matters at W=2 (-0.5%/+1.1%).
* The Lua gain of both prefix-coded members (-45% to -49% cycles against r20) is the switch dispatch of the new compiler (a binary search instead of a chain of compares in `luaV_execute`), not the encoding; `lz4` is the one program where /16 is slower than r20 (+1.3% to +1.7%; the cause was not analysed).

Per program, cycles:

A.i1.W4
| program | r20 | /16 | /32 | 16 vs r20 | 32 vs r20 | 32 vs 16 |
|---|---|---|---|---|---|---|
| lz4 | 206,025,216 | 208,789,234 | 189,843,778 | +1.3% | -7.9% | -9.1% |
| zlib | 244,662,988 | 230,180,030 | 200,135,131 | -5.9% | -18.2% | -13.1% |
| lua | 401,927,445 | 219,602,156 | 204,704,605 | -45.4% | -49.1% | -6.8% |
| bs_hash | 86,193,503 | 84,369,161 | 84,129,972 | -2.1% | -2.4% | -0.3% |
| bs_sym | 102,328,004 | 101,076,741 | 93,671,685 | -1.2% | -8.5% | -7.3% |
| bs_ec | 92,650,497 | 70,823,003 | 69,579,834 | -23.6% | -24.9% | -1.8% |
A.i2.W16
| program | r20 | /16 | /32 | 16 vs r20 | 32 vs r20 | 32 vs 16 |
|---|---|---|---|---|---|---|
| lz4 | 170,888,225 | 173,802,360 | 155,881,820 | +1.7% | -8.8% | -10.3% |
| zlib | 214,142,347 | 199,660,759 | 176,959,606 | -6.8% | -17.4% | -11.4% |
| lua | 365,782,842 | 186,237,800 | 172,103,632 | -49.1% | -52.9% | -7.6% |
| bs_hash | 67,613,449 | 67,098,772 | 66,826,822 | -0.8% | -1.2% | -0.4% |
| bs_sym | 86,557,558 | 85,602,703 | 77,744,082 | -1.1% | -10.2% | -9.2% |
| bs_ec | 75,844,525 | 57,724,425 | 55,674,634 | -23.9% | -26.6% | -3.6% |

Fetch-wait and execute-wait shares of the cycles (all six programs):

| model | enc | fetch-wait | execute-wait | cycles/insn |
|---|---|---|---|---|
| A.i1.W4 | r20 | 1.7% | 31.6% | 1.500 |
| A.i1.W4 | 16 | 5.5% | 27.9% | 1.500 |
| A.i1.W4 | 32 | 7.2% | 24.8% | 1.470 |
| A.i1.W16 | r20 | 1.6% | 31.7% | 1.498 |
| A.i1.W16 | 16 | 5.0% | 28.0% | 1.493 |
| A.i1.W16 | 32 | 6.2% | 25.1% | 1.455 |
| A.i2.W4 | r20 | 3.1% | 38.0% | 1.325 |
| A.i2.W4 | 16 | 6.5% | 34.0% | 1.295 |
| A.i2.W4 | 32 | 8.6% | 30.3% | 1.284 |
| A.i2.W16 | r20 | 1.7% | 38.9% | 1.298 |
| A.i2.W16 | 16 | 5.5% | 34.9% | 1.263 |
| A.i2.W16 | 32 | 6.9% | 31.7% | 1.231 |

### 4.4 Against the earlier predictions

| Quantity | Predicted | Measured now | Why it differs |
|---|---|---|---|
| /16 corpus size | Python model A16 1,013,598 (-6.48% against 1,083,870 in the study; no fused pairs); C16 979,192 (-9.66%) with the four fused pairs | **934,470** (-13.78%) | The model measured the *old* compiler's code. The compiler of the work adds fusion (-39,674 B = 4.16% in phase 3), then call-argument liveness, block-local value reuse, `lea`/threading, tail calls, jump tables, autoinc and strength reduction (phase 3 953,370; phase 4 941,166), and the re-optimised grammars with three-parcel `cbCC` (-0.7%: 934,470). 4.6% below C16. The re-optimisation of the grammar is trained on the new compiler's code; the study's was on the old. |
| /32 corpus size | A32r 1,040,280 / C32 1,007,172 | **964,158** (-4.3% against C32) | the same reasons |
| /32 over /16, static | +3.6% (model) | **+3.18%** (+4.39% without the outlier file) | more compiler passes use the 32 registers; the re-optimisation shrank both |
| bytes per executed instruction, /16 | 2.822 (model, A16, the old compiler's code and six programs) | **2.678** | fewer short register moves and more fused pairs executed: executed instructions fell 19.3% and bytes 31.0% |
| 32 registers, executed instructions | `docs/dynamic-spill-estimate.md` estimator B: -4.3% (band -1.0% .. +9.5%) | **-6.06%** | inside the band; the estimator was built from a 16-register profile and a static delta, the cause of the difference was not analysed |
| 32 registers, frame loads/stores | -55% (band -31% .. -72%) | **-62.8%** | inside the band |
| pdp64/32 against /16 in bytes fetched | +0.01% (phase 2), +1.4% (first cbCC measurement) | **+2.92%** | after the `cbCC` fix /16 profited more than /32 (cbreach.md); the compiler's 32-register code fetches 6.8% less than the 16-register code run as /32 |
| relaxation | 9% of the corpus text (study), 3.5% (ldrelax.md, old compiler/grammar) | 3.86% (/16) and 3.76% (/32) of corpus text; 1.73% / 1.65% of the programs' linked text | external calls are 6 bytes and shrink to 4: 20,333 sites x 2 B; few calls in whole programs |
| far `cbCC` | 38.8 M executed cmp+bCC pairs in Lua (phase 2) | 0 (/16), 79,894 in all six programs (/32) | the 38.8 M belonged to the old compiler's compare chain |
| timing, prefix-coded against r20 | `frag-timing` partial: /16 about -10%, /32 about -17% | -19.3% and -25.7% at W4 issue 1 | the partial totals had Lua r20 truncated at 200 M steps; the compiler had no switch dispatch or phase 4 passes |

### 4.5 Answer to "how well does the optimizer do"

With the old compiler on pdp64/r20 as the baseline, the new compiler with the prefix-coded encodings and default relaxation gives, on the 841-file corpus, 13.8% (/16) and 11.0% (/32) fewer instruction bytes (a further 3.8% off the text when linked with relaxation), and on six large programs 19.3% (/16) and 24.2% (/32) fewer instructions executed, 31.0% and 28.9% fewer bytes fetched, and, in an in-order model with ideal memory and a 4-byte fetch, 19.3% and 25.7% fewer cycles (21.2% and 26.6% with issue width 2). Most of the executed-instruction saving is the compiler (fusion, availability, switch dispatch, indexing, jump tables), most of the size saving is the encoding; the fewer-registers-vs-more question is answered by the table: 32 registers cost 3.2% in corpus bytes and 2.9% in fetched bytes and give 6.1% fewer instructions, 63% fewer frame accesses and 7-9% fewer cycles in the model.

## 5. Known problems and what is left undone

* The manual (`docs/manual/`) is not updated; `docs/manual-update-plan.md` lists what, and the effort (about 16 working days).
* The pcc branch `enc-prefix` is not merged into pcc's main; `tools/build-pcc.sh` needs `PCC=<work>/pcc-enc`. The pcc driver `cc` is not built for pdp64 (every tool calls `ccom`).
* `pdp64size.py` for the new targets was edited but not run on the fair corpus (the v7unix-toolchain corpus builds were not re-made); the numbers here come from `corp.py`.
* The "r20 with the new compiler" column does not exist (see 4). The model of the table's "old compiler" r20 is pcc-enc's `-m pdp64/r20`, identical in output to the old compiler on all 841 files.
* Timing: a single fresh sweep (set A, ideal memory, no BTB). The cache/ldec variants (sets B, C) of the timing agent were not re-run on the integrated tree; the agent's earlier sweeps (`scratchpad/tm/res`) are of an older compiler. The model is an in-order toy.
* `pr79286.c` does not link in the stub-link relaxation measurement (840 of 841), relaxed or not (a 64-bit constant used as a displacement); `pr116799` differs between encodings (no return value from `main`; exit status is an address). 7 c-testsuite and 22 gcc-torture programs fail in all encodings alike (as before; mostly the stand-in libc).
* QEMU does not execute pdp64/16 or /32 (its executor copy is built without `PDP64_ENC`); the atomics, a number of crypto words and `mval`/`utf8dec`/`utf8enc` are not implemented in the executor (errata 88).
* The 3-parcel `cbCC` and the other form choices were trained on the corpus only (not on the six programs): the one-parcel `cbCC` shrank in /32 (cbreach.md) which costs lz4 about 1.2% in fetched bytes; a profile-tuned variant was not tried.
* The compiler does not use `movuw/movul/movuq` (the unaligned-access idiom: 10% of lz4's instructions), `mulh`-based 64-bit division by constants, loop-invariant motion or live-range splitting (`pcc2.md`).
* The commit-msg hook of the author strips the `Co-Authored-By` trailer from commit messages; it was left.
* `tools/build-hbnf.sh` needs network access (upstream hbnf, Alpine rootfs); the clean-checkout verification below used the already built hbnf of `/tmp/hbnf-latest` unless stated.

## 6. Verification from a clean checkout

`git worktree add --detach` of `enc-int` at commit `22efcc8` in a scratch directory (no `build/`), hbnf built from scratch with `HBNF_REF=dd34982ab66ad47312e57b92eb25b4ece75ed57d tools/build-hbnf.sh` (2 min 28 s, the commit of `hbnf.commit`; warnings of upstream's Ada only), then `tools/check-all.sh`: **rc 0 in 2 min 1 s**: 63 format vectors, 42 syntax tests, the model/codec/drift checks of both encodings (0 mismatches), `check-grammar-enc` (hbnf's decoder against the codec: 262,144 sequences per encoding, 0 disagreements), manual/book/pcc-header checks, ld64 tests, sim64 (231 run, 0 failed), exectest-enc, p2diff (86,040 runs, 0 mismatches), timing (128 checks), relax (80 run) and 7 mutants (all caught), flaginv, QEMU (53 run, 0 failed, 4 skipped), the LLVM tables. Then `PCC=<work>/pcc-enc tools/build-pcc.sh` built `ccom` and `ccom32` and `tools/pdp64test.sh -m pdp64/r20|16|32` ran `tests/c-new/ccp_signedness.c` (0 in all three). The full C harness and the program runs of section 3 were made in the working tree with the same sources.
The tree `enc-int` after this report differs from `22efcc8` only by this section.
