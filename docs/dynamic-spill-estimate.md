# Dynamic effect of 32 registers on pdp64: executed instructions and frame traffic

[← pdp64 index](../README.md)

Static baseline this extends: [`spill-experiment.md`](spill-experiment.md) (1.31% fewer instructions; 8,279 of 23,962 stack loads and stores, 35%).

## 1. Result in six lines

1. Programs actually run under sim64 (16-register pcc, output identical to a host gcc build of the same sources): lz4 (fast + HC round trip, 139.7 M instr), zlib (deflate/inflate round trip at 3 levels, 172.9 M), Lua 5.4.7 (interpreter running a 40-line script, 233.3 M), BearSSL hashes (65.3 M), BearSSL symmetric ciphers (AES, ChaCha20-Poly1305, GHASH; 73.6 M), BearSSL elliptic curves (curve25519 + P-256, 71.1 M) = 755.8 M executed instructions; plus 206 of 213 c-testsuite programs (1.8 M together) and 147 of 169 gcc-torture execute tests (1.4 M together), which are too small to say anything about the compiler (they mostly run my stand-in printf).
2. At 16 registers, frame loads/stores (sp/fp-relative mov, same classification as exact.py) are 10.1% of executed instructions in the six large programs (static corpus: 7.1%), register-to-register moves 7.1% (static 13.7%), push/pop/pushm/popm 0.8% (static 3.1%), memory-referencing instructions 26.4%, branches+calls+returns 26.6%. Executed length mix 54.2% 2-byte, 35.1% 4-byte, 10.7% 6-byte, 3.13 bytes per instruction (2.66 to 3.80 between programs).
3. Estimated dynamic saving from 32 registers, six large programs pooled: **4.3% of executed instructions (32.3 M of 755.8 M) by the category-weighted estimator B, 4.9% by the uniform estimator A**, per program 2.1% to 6.5% (B); the static figure is 1.31% (3.2% to 3.5% for the same code in zlib/lz4: these programs' code is more spill-prone than the corpus average). The honest uncertainty band from the hottest-first / coldest-first bounds is -1.0% to +9.5% for the pooled sum.
4. Estimated dynamic frame load/store reduction: **55% (B; 53% by A; hot/cold bounds 31% to 72%)** of the executed frame accesses, against 35% static. Dynamic frame traffic is concentrated in a few hot loops (zlib longest_match, LZ4HC match finder, luaV_execute, the Montgomery multiply, AES S-box), where 32 registers remove almost all of it.
5. Validation of the estimator on a change that CAN be run: a pcc variant with two callee-saved registers fewer (11 allocatable), measured against the 16-register build in the same programs, estimating the 11 to 16 saving from the 11-register profile. Pooled over 5 programs: measured 7.75%, B 9.17% (+18%), A 9.96%; per program B errs by -32% to +54% (A by -30% to +89%), and the measured value is inside the hot/cold bounds in all 5. So expect the 4.3% to be roughly right within a relative error of +-50% per program (3.6% if B's pooled bias carried over, which is not shown).
6. Caveat that matters: every number above is an estimate built from a static delta and a 16-register profile; the 32-register code cannot be assembled, so nothing 32-register was executed. Both estimators assume the removed instructions have the average dynamic weight of their function (A) or of their category within the function (B); the bounds show how wrong that can be (spills in loops).

## 2. What was built and run

- **Instrumented simulator**: `bin/sim64i.c` is a copy of sim64/sim64.c (original untouched) with a per-PC execution counter (uint32 per 2-byte parcel from 0x10000, dumped to a file at exit) and a step counter; the step limit widened from int to long. Linked against the project's common/pdp64exec.c, calib.c, p2.c and build/fmtp.o. It executes exactly as sim64 (block instructions mcpy/mmov/mset count as ONE executed instruction each regardless of length; they are 0.0% to 0.8% of the instructions: lz4 1.16 M, others under 55 k).
- **Runtime**: no libc exists in the project (tools/pdp64test.sh uses only a 5-routine crt). I wrote `rt/crt.s` (start, exit/write/read traps, memcpy/memmove/memset via block instructions, setjmp/longjmp, a __builtin_abort alias), `rt/libc.c` (stdio output with a printf core, string functions, a size-class malloc, qsort, rand) and `rt/libc2.c` (strtol/strtod, a few libm functions, ctype, stubs; only linked for Lua). libc.c and libc2.c are compiled by the same pcc16/pcc32 pair as the programs, so they take part in the estimate. They are NOT a real libc; the "program code only" tables exclude them from both counts and estimates (results nearly unchanged for the six large programs: libc is 1.7% of executed instructions).
- **Compilation**: same preprocessed text and ccom flags as the static experiment (`-xdmr -xtemps -xdeljumps -xinline -xdce`, musl aarch64 headers, corpus defines), compiled by `spill/pcc16` (assembled, linked with ld64, run) and by `spill/pcc32` (assembly only, for the static delta). Program sources are the corpus files (lz4/lib/lz4.c lz4hc.c; zlib 10 files; bearssl src files; lua 24 core/base/string/table files without io/os/math/coroutine/debug libs) plus a main of mine in `progs/`.
- **Correctness**: each large program's stdout is compared byte for byte with the same sources built by host gcc against the host libc; all six match, exit status 0. c-testsuite: stdout compared with the .expected file; gcc-torture: exit status 0 (abort gives 134).
- **Mapping**: PCs map to (object, assembly line, function) by walking each assembled .s with labels; instruction lengths are read from the object code; object text bases follow ld64's concatenation with each object's .text alignment, verified against the -M symbol map for every global symbol of every object; 100% of executed instructions map (unmapped = 0 in every run).
- **Classification** (dynlib.py `classify`, same rules as spill/exact.py plus branch/call/ret/block): frame_load / frame_store = mov with an sp/fp-based memory operand; regmove = movq reg,reg; csave = push/pop (incl. push fp / pop fp), pushm/popm; memory-referencing = any non-branch, non-lea instruction with a memory operand, plus push/pop/pushm/popm. Static check: running this classifier over the 841-file asm-base16 / asm-r32 reproduces frag-spill exactly: 338,313 -> 333,872 instructions (1.31%), frame ld/st 23,962 -> 15,683 (34.6%), regmoves 46,197 -> 50,477 (+4,280), csave_m 4,836 -> 4,746.
- Programs that did not run (excluded, not investigated): c-testsuite 00040 (loops until the step limit under pcc16, the 8-queens test), 00200, 00206, 00211, 00212 (wrong output), 00174 (needs sin), 00187 (needs fopen); gcc-torture: 16 wrong (several die with a misaligned data access fault in sim64, e.g. 20000707-1, 931004-5; others abort) and 6 unlinkable (alloca, open, __builtin_longjmp, __builtin_mul_overflow, __builtin_printf). Whether these are pcc16 code-generation faults or my runtime is not established.

## 3. The estimators

For a function f present in both builds (same file, same label), with dyn(f) executed instructions in the 16-register run and n16, n32 static instructions:
- **A (uniform)**: saved(f) = dyn(f) * (n16 - n32) / n16, and for frame ops dyn(f) * (fr16 - fr32) / n16. Assumes the removed instructions have the average dynamic weight of the function's code. Can exceed 100% of the real frame traffic (Lua: 168%), so its frame figure is unreliable where frame ops are cold relative to the function average.
- **B (by category)**: for each instruction category c (frame_load, frame_store, regmove, csave_m, csave_1, ext, branch, other, ...): saved_c = dyn_c(f) * (s16_c - s32_c) / s16_c, i.e. the removed (or added) instructions of a category are assumed to be spread over the category's executed instructions in proportion. This captures that frame ops sit in loops more than prologue code does. Categories new in the 32 build use the uniform weight. Used as the central estimate.
- **Bounds**: for each category the delta count k = |s16_c - s32_c|: if the 32-register code removes k instructions of that category, the saving is bounded by the k hottest (upper) or k coldest (lower) static instructions of that category in the 16-register profile; added instructions are charged the opposite way. These bound the loop-depth effect (a spill in a hot loop weighs more) but are loose: the lower bound is not a realistic outcome. Loop depth per removed instruction is NOT determined (the removed instructions are not identified; only counts differ), which is the acknowledged limitation.
- Functions without a counterpart in the 32 build contribute 0 (none executed in any large program: 0.000%).
- Static caveats inherited from frag-spill: pcc32 here is 8 extra caller-saved + 8 extra callee-saved registers; the new code is not encodable, so no bytes estimate; sp/fp-relative accesses include real locals, not only spills.

## 4. Validation of the estimator (a runnable change)

A copy of pcc16 (`pcc9/`, name historical) with allocatable r10 and r11 removed (11 allocatable registers; 9 did not compile in lua/zlib/bearssl) was built; its code assembles and runs. Using the 11-register profile as the base and the 16-register build as the "wider" one, estimators A and B predicted the saving, which was then measured by running both (all outputs identical to host gcc). zlib could not be validated (the 11-register ccom fails on inftrees.c: "Cannot generate code").

| program | executed instr, 11-reg build (profile used) | executed instr, 16-reg build (measured) | measured saving 11 to 16 | estimate B | [cold-first, hot-first] | estimate A | frame ld/st, 11-reg | frame ld/st, 16-reg (measured) | measured frame saving | estimate B | [cold, hot] | A |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| lz4 | 150,487,769 | 139,660,315 | 7.19% | 9.14% | [-3.87, 23.99]% | 7.09% | 43,026,568 | 25,652,602 | 40.4% | 44.9% | [5.9, 86.5]% | 41.8% |
| bs_hash | 72,404,837 | 65,301,679 | 9.81% | 15.08% | [5.95, 18.76]% | 13.48% | 16,461,164 | 7,019,275 | 57.4% | 80.2% | [56.1, 88.0]% | 72.5% |
| bs_sym | 80,865,984 | 73,616,137 | 8.97% | 6.13% | [0.73, 13.00]% | 6.76% | 25,686,582 | 15,852,477 | 38.3% | 29.2% | [19.2, 44.7]% | 29.7% |
| bs_ec | 77,708,242 | 71,053,228 | 8.56% | 6.69% | [2.12, 11.97]% | 5.99% | 9,892,210 | 2,578,563 | 73.9% | 58.6% | [38.0, 82.9]% | 57.7% |
| lua | 250,405,376 | 233,250,134 | 6.85% | 9.24% | [-0.13, 27.39]% | 12.95% | 37,319,023 | 10,513,200 | 71.8% | 67.4% | [11.1, 98.7]% | 107.0% |

Pooled over the five: measured 7.75% of the 11-register instruction count, B 9.17%, A 9.96%. The direction and magnitude are right and the measured value always lies between the cold-first and hot-first bounds, but B is not precise: per program it errs from -32% (bs_sym, bs_ec under-estimated) to +54% (bs_hash over-estimated). Note that this tests the weighting assumption for a smaller change (11 to 16, 7% saved) than 16 to 32 (4%), and removing registers from the allocator is not the same as adding them (the 32-register compiler also has its own preferences between caller- and callee-saved registers; frag-spill gives a 1.15% to 1.36% static range across splits).

## 5. Tables (generated by report.py)

"B" = category-weighted estimate, "A" = uniform estimate, "[cold, hot]" = bounds; "saved" columns are percentages of the program's executed instructions (instr) or of its executed frame loads+stores (frame); "static ... (same code)" = the static delta over the functions of that very program (all functions, executed or not).

## Group totals, whole program including the stand-in libc (crt+libc.c+libc2.c)

### all code

| group | programs | executed instr (16 reg) | frame ld/st % | reg moves % | push/pop/pushm/popm % | mem-ref instr % | branch+call+ret % | instr saved B (central) | B range [cold-first, hot-first] | instr saved A (uniform) | frame ld/st saved B (central) | B range [cold-first, hot-first] | frame saved A (uniform) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| big | 6 | 755,816,022 | 10.1 | 7.1 | 0.8 | 26.4 | 26.6 | 4.27% | [-0.95, 9.50]% | 4.89% | 55.2% | [31.4, 71.9]% | 53.1% |
| ct | 206 | 1,812,310 | 1.3 | 14.8 | 1.9 | 7.6 | 32.2 | 0.18% | [-0.33, 0.53]% | 0.42% | 18.7% | [9.4, 40.0]% | 41.8% |
| gt | 147 | 1,399,559 | 0.1 | 19.9 | 0.4 | 18.4 | 29.2 | 0.03% | [0.02, 0.04]% | 0.04% | 37.8% | [33.7, 47.4]% | 47.7% |

## Group totals, program code only (stand-in libc/crt excluded from counts and from the estimate)

### program code only

| group | programs | executed instr (16 reg) | frame ld/st % | reg moves % | push/pop/pushm/popm % | mem-ref instr % | branch+call+ret % | instr saved B (central) | B range [cold-first, hot-first] | instr saved A (uniform) | frame ld/st saved B (central) | B range [cold-first, hot-first] | frame saved A (uniform) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| big | 6 | 742,938,650 | 10.3 | 6.9 | 0.8 | 26.6 | 26.6 | 4.34% | [-0.97, 9.66]% | 4.98% | 55.2% | [31.4, 71.9]% | 53.1% |
| ct | 206 | 1,443,061 | 0.0 | 16.2 | 0.0 | 0.2 | 33.3 | 0.00% | [0.00, 0.00]% | 0.00% | 1.4% | [1.4, 1.4]% | 1.2% |
| gt | 147 | 1,383,621 | 0.1 | 19.8 | 0.3 | 18.4 | 29.2 | 0.01% | [0.01, 0.01]% | 0.03% | 22.1% | [22.1, 22.1]% | 59.5% |

## Per program: the six large programs

### large programs, all code

| program | executed instr | frame ld/st % | reg-move % | push/pop % | instr saved B % | [cold, hot] % | A % | frame saved B % | [cold, hot] % | A % | static instr saved % (same code) | static frame saved % |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| zlib | 172,934,529 | 8.6 | 1.0 | 0.1 | 6.52 | [3.91, 8.82] | 4.48 | 99.9 | [99.8, 100.0] | 31.4 | 3.53 | 72.0 |
| lz4 | 139,660,315 | 18.4 | 10.9 | 1.6 | 5.58 | [-4.72, 15.31] | 3.85 | 43.6 | [2.8, 81.6] | 36.5 | 3.22 | 32.6 |
| lua | 233,250,134 | 4.5 | 8.1 | 1.2 | 3.60 | [-4.10, 11.22] | 6.62 | 88.3 | [25.4, 99.7] | 168.1 | 1.76 | 58.6 |
| bs_ec | 71,053,228 | 3.6 | 10.5 | 0.4 | 2.51 | [1.18, 3.74] | 6.38 | 99.5 | [98.6, 99.7] | 156.4 | 4.21 | 69.4 |
| bs_sym | 73,616,137 | 21.5 | 8.0 | 0.1 | 2.21 | [1.17, 5.03] | 3.87 | 22.4 | [19.6, 28.6] | 28.1 | 3.36 | 35.8 |
| bs_hash | 65,301,679 | 10.7 | 7.4 | 0.1 | 2.14 | [0.77, 4.05] | 1.59 | 10.7 | [1.9, 22.2] | 6.4 | 1.35 | 29.4 |

### large programs, program code only (no libc)

| program | executed instr | frame ld/st % | reg-move % | push/pop % | instr saved B % | [cold, hot] % | A % | frame saved B % | [cold, hot] % | A % | static instr saved % (same code) | static frame saved % |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| zlib | 170,822,300 | 8.7 | 1.0 | 0.1 | 6.60 | [3.96, 8.93] | 4.54 | 99.9 | [99.8, 100.0] | 31.4 | 3.69 | 77.0 |
| lz4 | 132,225,335 | 19.4 | 9.8 | 1.7 | 5.89 | [-4.99, 16.17] | 4.07 | 43.6 | [2.8, 81.6] | 36.5 | 3.41 | 32.2 |
| lua | 230,487,108 | 4.6 | 8.1 | 1.2 | 3.65 | [-4.15, 11.35] | 6.70 | 88.4 | [25.4, 99.8] | 168.2 | 1.76 | 60.1 |
| bs_ec | 70,765,036 | 3.6 | 10.4 | 0.3 | 2.52 | [1.19, 3.75] | 6.40 | 99.7 | [98.8, 99.9] | 156.6 | 4.88 | 77.5 |
| bs_sym | 73,462,943 | 21.6 | 7.9 | 0.1 | 2.21 | [1.18, 5.04] | 3.88 | 22.4 | [19.6, 28.6] | 28.1 | 3.70 | 35.5 |
| bs_hash | 65,175,928 | 10.8 | 7.3 | 0.1 | 2.14 | [0.77, 4.06] | 1.59 | 10.7 | [1.9, 22.2] | 6.4 | 0.86 | 20.0 |

### c-testsuite, 15 largest savings of 206 (programs are tiny; mostly the stand-in printf)

| program | executed instr | frame ld/st % | reg-move % | push/pop % | instr saved B % | [cold, hot] % | A % | frame saved B % | [cold, hot] % | A % | static instr saved % (same code) | static frame saved % |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ct00182 | 4,880 | 12.8 | 8.2 | 7.6 | 8.13 | [5.39, 10.94] | 1.31 | 65.5 | [56.9, 85.6] | 13.5 | 1.97 | 38.1 |
| ct00180 | 485 | 10.3 | 9.7 | 8.2 | 6.19 | [3.51, 8.66] | 1.99 | 63.0 | [54.0, 84.0] | 25.4 | 2.26 | 38.1 |
| ct00217 | 1,035 | 9.3 | 6.8 | 8.9 | 4.77 | [1.93, 7.25] | 2.05 | 54.8 | [44.8, 78.1] | 29.1 | 2.26 | 38.1 |
| ct00186 | 17,599 | 10.0 | 8.2 | 8.4 | 4.62 | [1.93, 7.16] | 2.36 | 50.1 | [40.9, 71.5] | 31.0 | 2.25 | 38.1 |
| ct00179 | 6,491 | 8.9 | 9.0 | 8.7 | 3.56 | [1.25, 5.73] | 2.11 | 44.2 | [35.5, 64.5] | 31.3 | 2.02 | 36.6 |
| ct00195 | 1,312 | 6.7 | 8.5 | 7.9 | 1.97 | [-2.13, 3.89] | 2.28 | 38.4 | [15.9, 58.0] | 46.7 | 2.24 | 38.1 |
| ct00173 | 4,366 | 6.7 | 8.7 | 8.4 | 1.83 | [-0.02, 3.57] | 2.14 | 32.3 | [23.5, 53.1] | 41.8 | 2.22 | 38.1 |
| ct00175 | 8,279 | 6.0 | 8.5 | 8.7 | 1.06 | [-1.76, 2.81] | 2.20 | 25.4 | [9.7, 47.3] | 49.4 | 2.20 | 38.1 |
| ct00132 | 12,237 | 5.6 | 7.5 | 8.9 | 0.87 | [-1.49, 2.65] | 2.13 | 21.6 | [10.1, 47.6] | 50.6 | 2.24 | 38.1 |
| ct00169 | 12,342 | 7.5 | 9.9 | 6.4 | 0.70 | [-2.19, 2.63] | 2.33 | 14.7 | [5.9, 35.2] | 41.2 | 2.24 | 38.1 |
| ct00184 | 962 | 7.1 | 10.0 | 7.3 | 0.64 | [-2.08, 2.49] | 2.26 | 14.7 | [5.9, 35.3] | 42.1 | 2.26 | 38.1 |
| ct00164 | 4,949 | 7.1 | 10.7 | 8.9 | 0.64 | [-1.62, 2.24] | 2.11 | 13.7 | [6.3, 31.1] | 38.2 | 2.58 | 41.2 |
| ct00170 | 3,418 | 6.8 | 9.4 | 7.1 | 0.57 | [-1.84, 2.31] | 2.11 | 13.5 | [4.7, 33.9] | 40.7 | 2.22 | 36.6 |
| ct00185 | 11,958 | 7.1 | 10.2 | 7.5 | 0.54 | [-1.84, 2.17] | 1.98 | 12.6 | [4.7, 30.8] | 37.0 | 2.21 | 37.4 |
| ct00158 | 2,095 | 7.0 | 10.5 | 9.4 | 0.53 | [-1.91, 2.29] | 2.19 | 13.6 | [5.4, 32.7] | 41.1 | 2.23 | 38.1 |

### gcc-torture, 10 largest savings of 147

| program | executed instr | frame ld/st % | reg-move % | push/pop % | instr saved B % | [cold, hot] % | A % | frame saved B % | [cold, hot] % | A % | static instr saved % (same code) | static frame saved % |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| gt_20001124-1 | 62 | 12.9 | 4.8 | 4.8 | 14.52 | [14.52, 14.52] | 11.74 | 100.0 | [100.0, 100.0] | 74.4 | 2.97 | 43.4 |
| gt_20030626-2 | 559 | 16.1 | 7.0 | 7.9 | 10.94 | [6.80, 14.85] | 2.38 | 70.4 | [61.1, 92.2] | 19.5 | 2.25 | 38.1 |
| gt_vfprintf-chk-1 | 5,435 | 9.0 | 7.7 | 8.8 | 4.47 | [1.47, 6.81] | 2.36 | 54.2 | [45.0, 75.7] | 34.5 | 1.84 | 37.8 |
| gt_pr80421 | 3,181 | 5.4 | 2.9 | 4.2 | 4.33 | [3.93, 4.75] | 12.22 | 88.4 | [88.4, 88.4] | 246.6 | 2.84 | 44.1 |
| gt_20060420-1 | 1,085 | 3.1 | 12.1 | 0.6 | 0.84 | [0.18, 1.11] | 1.19 | 0.0 | [0.0, 0.0] | 0.0 | 2.21 | 36.6 |
| gt_vrp-5 | 29 | 0.0 | 17.2 | 13.8 | 0.00 | [0.00, 0.00] | 0.00 | 0.0 | [0.0, 0.0] | 0.0 | 2.24 | 38.1 |
| gt_va-arg-5 | 107 | 0.0 | 7.5 | 28.0 | 0.00 | [0.00, 0.00] | 0.00 | 0.0 | [0.0, 0.0] | 0.0 | 2.11 | 38.1 |
| gt_va-arg-12 | 69 | 8.7 | 5.8 | 23.2 | 0.00 | [0.00, 0.00] | 0.00 | 0.0 | [0.0, 0.0] | 0.0 | 2.17 | 35.9 |
| gt_tstdi-1 | 232 | 0.0 | 0.9 | 0.9 | 0.00 | [0.00, 0.00] | 0.00 | 0.0 | [0.0, 0.0] | 0.0 | 2.00 | 38.1 |
| gt_struct-ini-1 | 22 | 0.0 | 9.1 | 9.1 | 0.00 | [0.00, 0.00] | 0.00 | 0.0 | [0.0, 0.0] | 0.0 | 2.26 | 38.1 |

## Executed instruction length mix (16-register code, as assembled)

| group | 2-byte | 4-byte | 6-byte | bytes fetched | mean bytes/instr |
|---|---|---|---|---|---|
| big (all) | 54.2% | 35.1% | 10.7% | 2,365,226,284 | 3.13 |
| big (no libc) | 53.9% | 35.3% | 10.8% | 2,331,148,854 | 3.14 |
| ct (all) | 53.9% | 42.8% | 3.3% | 5,417,096 | 2.99 |
| ct (no libc) | 51.1% | 48.4% | 0.5% | 4,312,188 | 2.99 |
| gt (all) | 35.6% | 25.7% | 38.7% | 5,686,576 | 4.06 |
| gt (no libc) | 35.2% | 25.8% | 39.1% | 5,642,334 | 4.08 |

- lz4: 2/4/6-byte = 59.4/38.5/2.1%, 2.85 bytes/instr, block instr executed 1157187, frame loads 21,593,680 stores 4,058,922, push/pop(non-fp) 1,025,912, pushm+popm 1,254,534, frame-adjust (sub/add sp, fp setup) 7,680,560, lea of frame 2,387,703
- zlib: 2/4/6-byte = 59.2/39.5/1.3%, 2.84 bytes/instr, block instr executed 31, frame loads 14,782,255 stores 133,883, push/pop(non-fp) 788, pushm+popm 102,116, frame-adjust (sub/add sp, fp setup) 102,076, lea of frame 5,370
- bs_hash: 2/4/6-byte = 53.5/43.0/3.4%, 3.00 bytes/instr, block instr executed 19633, frame loads 6,193,940 stores 825,335, push/pop(non-fp) 3,556, pushm+popm 77,132, frame-adjust (sub/add sp, fp setup) 43,094, lea of frame 5,642
- bs_sym: 2/4/6-byte = 69.8/27.2/2.9%, 2.66 bytes/instr, block instr executed 30746, frame loads 10,115,247 stores 5,737,230, push/pop(non-fp) 2,636, pushm+popm 83,276, frame-adjust (sub/add sp, fp setup) 79,256, lea of frame 297,214
- bs_ec: 2/4/6-byte = 65.5/30.1/4.4%, 2.78 bytes/instr, block instr executed 53384, frame loads 1,944,480 stores 634,083, push/pop(non-fp) 190,080, pushm+popm 60,474, frame-adjust (sub/add sp, fp setup) 85,458, lea of frame 123,546
- lua: 2/4/6-byte = 39.2/31.6/29.2%, 3.80 bytes/instr, block instr executed 5866, frame loads 7,086,953 stores 3,426,247, push/pop(non-fp) 328,744, pushm+popm 2,568,954, frame-adjust (sub/add sp, fp setup) 1,199,836, lea of frame 26,045

## Where the savings come from (large programs): top functions by estimated B saving

**lz4** (total 139,660,315 instr)

| function | exec instr | share | static n16->n32 | static frame ld/st 16->32 | dyn frame ld/st | est saved B | est saved A | est frame saved B |
|---|---|---|---|---|---|---|---|---|
| lz4_lz4hc:LZ4HC_InsertAndGetWiderMatch | 46,728,572 | 33.5% | 553->504 | 170->79 | 18,511,998 | 7,388,637 | 4,140,506 | 9,862,638 |
| lz4_lz4:LZ4_decompress_generic | 2,722,615 | 1.9% | 623->580 | 112->60 | 742,223 | 315,263 | 187,917 | 344,174 |
| lz4_lz4:LZ4_compress_generic_validated | 2,594,837 | 1.9% | 722->674 | 220->128 | 865,877 | 139,877 | 172,509 | 349,208 |
| lz4_lz4hc:LZ4HC_encodeSequence | 842,890 | 0.6% | 123->117 | 7->0 | 105,378 | 89,976 | 41,116 | 105,378 |
| lz4_lz4hc:LZ4HC_compress_hashChain | 1,317,899 | 0.9% | 435->414 | 186->157 | 633,111 | 66,237 | 63,622 | 98,671 |
| lz4_lz4hc:LZ4HC_InsertAndFindBestMatch | 145,005 | 0.1% | 21->19 | 8->8 | 55,240 | 13,810 | 13,810 | 0 |

functions with negative estimated B (32-reg code longer): 3, sum -225,779 instr (0.16% of program)

executed instructions in functions without a counterpart in the 32-register build (crt asm etc.): 0 (0.000%)

**zlib** (total 172,934,529 instr)

| function | exec instr | share | static n16->n32 | static frame ld/st 16->32 | dyn frame ld/st | est saved B | est saved A | est frame saved B |
|---|---|---|---|---|---|---|---|---|
| zlib_deflate:longest_match | 140,421,095 | 81.2% | 135->128 | 4->0 | 14,690,996 | 11,167,410 | 7,281,093 | 14,690,996 |
| zlib_crc32:crc32_z | 937,612 | 0.5% | 292->280 | 16->0 | 59,490 | 38,233 | 38,532 | 59,490 |
| zlib_inffast:inflate_fast | 5,102,037 | 3.0% | 421->392 | 34->0 | 111,067 | 21,080 | 351,446 | 111,067 |
| zlib_trees:compress_block | 4,444,520 | 2.6% | 372->370 | 0->0 | 0 | 18,665 | 23,895 | 0 |
| zlib_inflate:inflate | 81,141 | 0.0% | 1798->1629 | 319->84 | 16,556 | 8,926 | 7,626 | 12,029 |
| zlib_trees:build_tree | 113,061 | 0.1% | 252->233 | 20->0 | 7,760 | 6,532 | 8,524 | 7,760 |

functions with negative estimated B (32-reg code longer): 1, sum -3 instr (0.00% of program)

executed instructions in functions without a counterpart in the 32-register build (crt asm etc.): 0 (0.000%)

**bs_hash** (total 65,301,679 instr)

| function | exec instr | share | static n16->n32 | static frame ld/st 16->32 | dyn frame ld/st | est saved B | est saved A | est frame saved B |
|---|---|---|---|---|---|---|---|---|
| bearssl_sha2small:br_sha2small_round | 31,148,600 | 47.7% | 345->337 | 17->17 | 4,065,712 | 837,346 | 722,286 | 0 |
| bearssl_sha1:br_sha1_round | 8,554,536 | 13.1% | 337->327 | 41->25 | 1,704,352 | 577,892 | 253,843 | 686,247 |
| bearssl_dec64be:br_range_dec64be | 581,916 | 0.9% | 26->24 | 2->0 | 65,568 | 18,831 | 44,762 | 65,568 |
| bearssl_md5:br_md5_round | 4,924,594 | 7.5% | 325->324 | 16->16 | 262,208 | 15,603 | 15,152 | 0 |
| libc:vfmt | 19,364 | 0.0% | 399->377 | 50->21 | 1,023 | 314 | 1,067 | 510 |
| crt.s:_start | 4 | 0.0% | 5->5 | 0->0 | 0 | 0 | 0 | 0 |

functions with negative estimated B (32-reg code longer): 1, sum -52,547 instr (0.08% of program)

executed instructions in functions without a counterpart in the 32-register build (crt asm etc.): 0 (0.000%)

**bs_sym** (total 73,616,137 instr)

| function | exec instr | share | static n16->n32 | static frame ld/st 16->32 | dyn frame ld/st | est saved B | est saved A | est frame saved B |
|---|---|---|---|---|---|---|---|---|
| bearssl_aes_ct64:br_aes_ct64_bitslice_Sbox | 6,913,085 | 9.4% | 241->197 | 60->1 | 1,721,100 | 1,262,140 | 1,262,140 | 1,692,415 |
| bearssl_aes_ct64_enc:br_aes_ct64_bitslice_encrypt | 3,092,480 | 4.2% | 139->116 | 43->0 | 878,592 | 324,122 | 511,705 | 878,592 |
| bearssl_chacha20_ct:br_chacha20_ct_run | 17,215,793 | 23.4% | 478->478 | 268->266 | 10,865,272 | 65,123 | 0 | 80,610 |
| bearssl_ghash_ctmul:br_ghash_ctmul | 10,395,702 | 14.1% | 406->386 | 139->111 | 1,712,152 | 16,105 | 512,103 | 344,371 |
| libc:vfmt | 12,276 | 0.0% | 399->377 | 50->21 | 744 | 276 | 676 | 399 |
| bearssl_aes_big_dec:br_aes_big_keysched_inv | 2,897 | 0.0% | 95->84 | 20->0 | 511 | 119 | 335 | 511 |

functions with negative estimated B (32-reg code longer): 2, sum -42,970 instr (0.06% of program)

executed instructions in functions without a counterpart in the 32-register build (crt asm etc.): 0 (0.000%)

**bs_ec** (total 71,053,228 instr)

| function | exec instr | share | static n16->n32 | static frame ld/st 16->32 | dyn frame ld/st | est saved B | est saved A | est frame saved B |
|---|---|---|---|---|---|---|---|---|
| bearssl_i31_montmul:br_i31_montymul | 48,545,348 | 68.3% | 209->194 | 17->0 | 2,523,448 | 1,635,303 | 3,484,115 | 2,523,448 |
| bearssl_i31_sub:br_i31_sub | 13,652,544 | 19.2% | 34->32 | 0->0 | 0 | 129,408 | 803,090 | 0 |
| bearssl_i31_add:br_i31_add | 3,410,182 | 4.8% | 34->32 | 0->0 | 0 | 32,324 | 200,598 | 0 |
| bearssl_i31_decmod:br_i31_decode_mod | 16,592 | 0.0% | 131->107 | 36->5 | 3,544 | 3,377 | 3,039 | 3,047 |
| bearssl_i32_div32:br_divrem | 26,514 | 0.0% | 92->82 | 11->0 | 2,898 | 2,002 | 2,881 | 2,898 |
| bearssl_i31_modpow:br_i31_modpow | 20,564 | 0.0% | 78->74 | 14->4 | 5,640 | 1,352 | 1,054 | 3,591 |

functions with negative estimated B (32-reg code longer): 2, sum -20,104 instr (0.03% of program)

executed instructions in functions without a counterpart in the 32-register build (crt asm etc.): 0 (0.000%)

**lua** (total 233,250,134 instr)

| function | exec instr | share | static n16->n32 | static frame ld/st 16->32 | dyn frame ld/st | est saved B | est saved A | est frame saved B |
|---|---|---|---|---|---|---|---|---|
| lua_lvm:luaV_execute | 178,431,128 | 76.5% | 3416->3144 | 360->48 | 8,677,823 | 6,505,864 | 14,207,630 | 7,495,994 |
| lua_ldo:luaD_precall | 9,935,102 | 4.3% | 81->76 | 5->0 | 880,201 | 965,049 | 613,277 | 880,201 |
| lua_lvm:luaV_finishset | 2,194,740 | 0.9% | 118->108 | 18->0 | 531,760 | 511,740 | 185,994 | 531,760 |
| lua_ltable:numusearray | 1,684,624 | 0.7% | 40->34 | 0->0 | 0 | 177,971 | 252,693 | 0 |
| lua_ldo:luaD_poscall | 740,334 | 0.3% | 106->104 | 5->0 | 86,492 | 103,097 | 13,968 | 86,492 |
| lua_lvm:luaV_finishget | 1,350,149 | 0.6% | 75->74 | 3->0 | 60,007 | 62,953 | 18,001 | 60,007 |

functions with negative estimated B (32-reg code longer): 4, sum -60,894 instr (0.03% of program)

executed instructions in functions without a counterpart in the 32-register build (crt asm etc.): 0 (0.000%)


## 6. Representativeness and limits

- Six large programs, 65 M to 233 M executed instructions each, are compute kernels (compression, hashing, big-number arithmetic, an interpreter loop) with the usual dominance of one hot function: longest_match is 81% of zlib's instructions, luaV_execute 77% of Lua's, br_i31_montymul 68% of bs_ec, LZ4HC_InsertAndGetWiderMatch 33% of lz4. The pooled figure is therefore the average of a handful of hot loops, not a profile of general-purpose code (no OS kernel, no pointer-chasing, no I/O). Functions whose hot code has no register pressure (md5 round: 325 to 324 instructions) save almost nothing.
- The 206 c-testsuite and 147 gcc-torture runs total 3.2 M instructions (0.4% of the large programs), most of it printf in my stand-in libc; their frame ld/st share (1.3% / 0.1%) and savings are not informative about the compiler (program code only: the c-testsuite programs execute 1.44 M instructions with almost no frame traffic).
- Not measured: bytes saved by 32 registers (no encoding for the 32-register code; the executed length per category was not tabulated); the cost of the larger context (saving and restoring more registers on a task switch); callee-saved push/pop in the 32 build beyond what pcc32 emitted.
- The unit of work is an executed instruction, as asked. A frame load is a memory access, a register move is not, so a 1% cut in instructions that is mostly frame loads/stores is worth more than 1% of time on a machine with load-use latency.
- Per-function and per-category output for every program is in `work/res/*.json`; the programs, the runtime and the drivers are in `progs/`, `rt/`, `run_ct.py`, `run_gt.py`, `progs_*.py`, `val9.py`, `report.py`, `agg.py`, `dynlib.py`, `static_check.py`.
