# Phase 2 report: sim64 and the executor for pdp64/r20, pdp64/16, pdp64/32

Worktree <worktree>, branch enc-prefix, commits 2ece7fe..acf1d7f on top of phase 1 (bb79182); nothing pushed; main checkouts, pcc and pcc-enc untouched. `tools/check-all.sh` passes at HEAD (exit 0).
Honest note on "every commit green": acf1d7f (first sim64 commit) had a stale generated manual page (fixed by 6b5afeb) and 49012d2 added tests/sim/bitfield.s before the QEMU skip file (220a19d); all later commits and HEAD are green. History was not rewritten.

## 1. What was built
- `common/pdp64exec.c` (shared with QEMU) now has `exec_fmt`: the old step() split in decode + execute. `common/pdp64exec_enc.inc` (compiled in with -DPDP64_ENC; QEMU's gen copy is built without it) decodes pdp64/16 and /32 through `common/pdp64enc` and either builds the same `struct fmt` and runs the old code (moves, ALU, SOP, XFER, SYS, BESC/AESC/MBLK/FESC: one semantics for the three encodings), or executes the new words itself. `eoperand` builds the memory operand from the codec's operand kinds (B, X, PI, PD, PC, A, d(dp)); (rn)+ / -(rn) without a stride use the access size (8 outside the moves).
- `struct pdp64_cpu`: `r[32]`, `enc`. pushm/popm masks are 32 bits (r0 ascending pushed, r31 popped first), r14 = sp, r13 = fp as before. sim64 takes the encoding from e_flags (&0xF), `-m r20|16|32` overrides. r16-r31 cannot be decoded in pdp64/16.
- Implemented new words: movcall, popmret, popret, mov2 (sequential: the second move sees the first); maskeqz, masknez, bsel; movql; trapcc.CC; addv/subv/mulv; movub/uw/ul/uq (little-endian bytes, no alignment fault, sign-extending, a store checks both ends first); addm/subm/bicm/bism (flags of add/sub/bic/bis, write permission checked with the read); utf8len; fclass32 (also for the old encoding: it was missing); `.u` moves (plain, there is no MMU); the merged SOP/SYS group, hint, pushx/popx/isync, mfsr/mtsr, set, spl, trap/trapl.
- Unimplemented, trapping as `unimplemented instruction NAME` (exit 139; illegal-instruction exception with -K): the whole ATOM group (cas, swap, xadd, xand, xor_, xxor, xmax, xmin, xmaxu, xminu, +db, ll, sc: operand placement and size encoding are not fixed in the ISA text, errata 45 gives only the monitor), aeses aesesm aesds aesdsm aesks1 aesks2 aesim, sha256sig0/1 sha256sum0/1 sha512*, msha256, msha512, maesctr (the docs say "to be checked against FIPS"; only the stage-1 prose exists), utf8dec (the "length in the status word scratch field" is undefined), utf8enc (result for an invalid scalar undefined), mval (stopping point inside a truncated sequence undefined), the deferred loads `.d` / `.ud` (poison bits not in the executor), syspg0-5 (placeholders). MESC/ATOM-style user-qualified atomics: not applicable.
- Fused instructions and restart: a fault in the second half is an abort of the whole instruction; the executor saves the state at the start of every instruction (-K) and restores registers on an abort, which is exact for these four (the first half writes a register that the second half does not need; popm/pop are loads only). Tested with -K (tests/sim-enc/fused.s): movcall whose push faults (r2 and sp rolled back, handler repairs sp, the restart completes, the pushed return address is the address after the whole fused instruction); movcall whose target is unmapped (the movcall itself completes, the fault is the fetch at the target, EPC = target); popret and popmret whose `ret` pop faults (the register(s) popped before are rolled back; restart pops again). Mutation check: switching off the restore for movcall/popret makes the test fail.
- `sim64 -P file`: per-pc counts (hex pc, count, bytes, category), totals of executed instructions and bytes, 11 categories (other, frame_load, frame_store, regmove, pushpop, memref, branch, call_ret_jmp, block, fused, lea; the same classes for all encodings). A block instruction is one executed instruction. The totals equal the trace in each encoding (checked).
- `tools/encdis` (new): a disassembler of pdp64/16 and /32 executables (was missing).

## 2. Bugs found
In the original code (fixed, tested): the executor read position and width of `extb extzb insb dshr` from the wrong field and ignored both (tests/sim/bitfield.s; found by the cross-encoding differential test; the QEMU binary in <work>/qemu-build still has it: tests/sim/bitfield.noqemu skips the test under QEMU until qemu/build.sh is run, then delete the file).
In my own work (found by the first 32-register run, fixed): pushm/popm of r16+ dropped the upper half of the mask. No bug was found in as64, ld64 or the codec by the end-to-end runs; there were none to fix.
Findings about tables/docs (errata 88): (a) addv/subv/mulv are two-register in the tables (rd <- rd op rs), the study proposal says three registers; (b) the tables have no store to d(dp) (`movq r3, 24(dp)` has no form in either new encoding; loads exist); (c) a cbCC far target / large immediate without a form becomes cmp + bCC which clobbers the flags (known; hit by tests/sim/cbrori in pdp64/32, which is therefore excluded there) and, much more important, it executes two instructions (see the Lua number below); (d) trapcc vector 16 and its EVA convention are assumed.

## 3. Tests
- `tools/check-sim64.sh`: every tests/sim test runs in r20, 16 and 32 (NAME.noenc excludes the 12 that write instruction words with `.word`): 139 runs. tests/sim-enc: `diff.s` (generated, 1551 cases x 2 states of the original ISA: moves of all widths, all addressing modes incl. 70 KB displacements, ALU, shifts, single-operand, push/pop/pushm/popm, call/jmp, all 14 branch conditions x cb forms x set, sob, tag branches, bit/arith escapes, block instructions, all FP escapes incl. binary16, system registers of user mode): the log of registers, flags and a memory window is byte-identical in the three encodings (addresses normalised); newops.s / newops32.s / fused.s (expectations computed in Python, not by the simulator; r16-r31 in ALU, addressing, branches, call, push, pushm/popm of any mask); 11 `unimpl-*` tests (exit 139 and the message names the mnemonic); the profile check.
- `tools/check-exec-enc.sh` (tests/exectest-enc.c): every first parcel of both tables through the executor, 3 runs each with random following parcels: 3277 = 5.00% illegal in each table and exactly those fault as illegal (also the sub-opcodes beyond a leaf), no decoded instruction names a register beyond the encoding's (pdp64/16: < r16), no "unimplemented" message other than the listed words. The decode itself is the codec checked against the Python prototype in phase 1 (tools/check-enc.py: 19,631/18,182 vectors, 43,724/36,284 first-parcel patterns, 0 mismatches); the executor calls that same decoder, so there is no second decode to compare.

## 4. End to end (no compiler change)
Scripts: scratchpad/enc2/run6.py (six programs), runsmall.py (c-testsuite, gcc-torture), measure.py, expansions.py, fdelta.py/mixdelta.py (diagnosis); crt32.s is the dyn crt.s with setjmp/longjmp saving r24-r31 as well (pcc32's callee-saved set is r8-r15 and r24-r31). Builds: pcc16 assembly with `as64` (r20 and `-m pdp64/16`), pcc32 assembly with `-m pdp64/32`, `ld64`, `sim64 -P`. The 16-register and 32-register assembly are the cached outputs of the earlier work (dyn/work/s16, s32).
- Six programs (lz4, zlib, Lua 5.4.7, BearSSL hash / symmetric / elliptic-curve kernels): stdout byte-identical to the host gcc build and exit status 0 in all three encodings (18 of 18). The 32-register runs are the first real execution of 32-register code.
- c-testsuite: 213 programs, results (status and stdout) identical in the three encodings (206 pass in r20 as before); gcc-torture: 169 programs, 168 identical in the three (147 pass in r20 as before); the one difference, pr116799, is a program whose main falls off the end: its exit status is an address-dependent leftover in r0 in all three (19 / 47 / 1) and it already fails in r20.

## 5. Exact measurements (sim64 -P, the same six programs)
"All code" = crt + stand-in libc + program (libc is compiled by the same pcc, 1.7% of executed instructions). Static text = text segment of the linked image.

## Executed instructions, bytes (all code: crt + stand-in libc + program)

| program | encoding | executed instr | executed bytes | bytes/instr | static text (linked) |
|---|---|---|---|---|---|
| lz4 | pdp64/r20 | 139,660,315 | 398,515,750 | 2.853 | 21,688 |
| lz4 | pdp64/16 | 139,660,316 | 370,808,712 | 2.655 | 20,712 |
| lz4 | pdp64/32 | 131,676,889 | 353,132,526 | 2.682 | 21,176 |
| zlib | pdp64/r20 | 172,934,529 | 491,311,946 | 2.841 | 53,042 |
| zlib | pdp64/16 | 172,937,696 | 470,162,638 | 2.719 | 49,938 |
| zlib | pdp64/32 | 157,939,732 | 450,030,684 | 2.849 | 51,340 |
| lua | pdp64/r20 | 233,250,134 | 886,211,648 | 3.799 | 106,774 |
| lua | pdp64/16 | 233,319,048 | 741,896,910 | 3.180 | 102,380 |
| lua | pdp64/32 | 261,838,854 | 903,740,706 | 3.452 | 105,296 |
| bs_hash | pdp64/r20 | 65,301,679 | 195,789,896 | 2.998 | 12,582 |
| bs_hash | pdp64/16 | 65,301,679 | 186,579,486 | 2.857 | 11,990 |
| bs_hash | pdp64/32 | 65,122,462 | 192,050,136 | 2.949 | 12,480 |
| bs_sym | pdp64/r20 | 73,616,137 | 195,959,992 | 2.662 | 17,728 |
| bs_sym | pdp64/16 | 73,616,137 | 185,990,334 | 2.526 | 16,808 |
| bs_sym | pdp64/32 | 70,876,720 | 213,770,936 | 3.016 | 17,944 |
| bs_ec | pdp64/r20 | 71,053,228 | 197,437,052 | 2.779 | 14,792 |
| bs_ec | pdp64/16 | 71,053,228 | 185,943,650 | 2.617 | 14,010 |
| bs_ec | pdp64/32 | 68,540,902 | 209,822,552 | 3.061 | 14,710 |
| **all six** | r20 | 755,816,022 | 2,365,226,284 | 3.129 | 226,606 |
| **all six** | 16 | 755,888,104 | 2,141,381,730 | 2.833 | 215,838 |
| **all six** | 32 | 755,995,559 | 2,322,547,540 | 3.072 | 222,946 |

## Program code only (crt and the stand-in libc excluded)

| program | encoding | executed instr | executed bytes | bytes/instr | static program text | frame loads | frame stores | regmove | pushpop | memref | branch | call/ret/jmp | block | fused | lea |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| lz4 | r20 | 132,225,335 | 379,724,568 | 2.872 | 18,000 | 21,593,553 | 4,058,658 | 12,905,772 | 2,279,952 | 20,057,771 | 16,986,822 | 12,399,229 | 1 | 0 | 7,670,056 |
| lz4 | 16 | 132,225,336 | 352,818,936 | 2.668 | 17,240 | 21,593,553 | 4,058,658 | 12,905,772 | 2,279,952 | 20,057,771 | 16,986,822 | 12,399,229 | 1 | 0 | 7,670,056 |
| lz4 | 32 | 124,241,874 | 334,341,794 | 2.691 | 17,504 | 11,061,864 | 2,020,688 | 17,341,251 | 2,266,140 | 19,906,080 | 16,986,822 | 12,399,229 | 1 | 0 | 8,046,274 |
| zlib | r20 | 170,822,300 | 485,874,640 | 2.844 | 49,350 | 14,778,254 | 130,920 | 1,718,330 | 102,092 | 37,007,419 | 41,856,604 | 194,519 | 0 | 0 | 1,641,229 |
| zlib | 16 | 170,825,467 | 465,327,882 | 2.724 | 46,462 | 14,778,254 | 130,920 | 1,718,330 | 102,092 | 37,007,419 | 41,856,604 | 194,519 | 0 | 0 | 1,641,229 |
| zlib | 32 | 155,827,455 | 444,594,214 | 2.853 | 47,668 | 6,867 | 6,059 | 1,786,680 | 526 | 36,900,263 | 41,856,602 | 194,519 | 0 | 0 | 1,641,277 |
| lua | r20 | 230,584,310 | 878,133,988 | 3.808 | 103,066 | 7,080,894 | 3,419,693 | 18,612,730 | 2,805,268 | 32,732,495 | 113,464,537 | 4,851,453 | 22 | 0 | 2,948,757 |
| lua | 16 | 230,653,357 | 734,190,482 | 3.183 | 98,878 | 7,080,887 | 3,419,690 | 18,612,893 | 2,805,314 | 32,733,497 | 113,465,457 | 4,851,530 | 23 | 0 | 2,948,789 |
| lua | 32 | 259,174,228 | 895,755,424 | 3.456 | 101,604 | 67,410 | 66,446 | 19,519,526 | 2,804,994 | 32,725,698 | 113,340,381 | 4,851,471 | 32 | 0 | 2,981,659 |
| bs_hash | r20 | 65,175,928 | 195,445,152 | 2.999 | 8,894 | 94,239 | 36,882 | 4,772,142 | 76,478 | 12,015,445 | 1,777,237 | 752,649 | 0 | 0 | 8,551,811 |
| bs_hash | 16 | 65,175,928 | 186,247,386 | 2.858 | 8,518 | 94,239 | 36,882 | 4,772,142 | 76,478 | 12,015,445 | 1,777,237 | 752,649 | 0 | 0 | 8,551,811 |
| bs_hash | 32 | 64,996,815 | 191,710,968 | 2.950 | 8,808 | 0 | 1 | 5,124,492 | 76,478 | 12,015,445 | 1,777,237 | 752,649 | 0 | 0 | 8,547,714 |
| bs_sym | r20 | 73,462,943 | 195,557,924 | 2.662 | 14,034 | 9,483,172 | 5,670,544 | 5,829,618 | 83,182 | 10,585,098 | 1,528,936 | 762,997 | 0 | 0 | 1,978,983 |
| bs_sym | 16 | 73,462,943 | 185,596,236 | 2.526 | 13,330 | 9,483,172 | 5,670,544 | 5,829,618 | 83,182 | 10,585,098 | 1,528,936 | 762,997 | 0 | 0 | 1,978,983 |
| bs_sym | 32 | 70,723,648 | 213,372,442 | 3.017 | 14,268 | 7,100,249 | 4,219,985 | 6,702,545 | 83,180 | 9,786,040 | 1,528,936 | 762,997 | 0 | 0 | 2,003,527 |
| bs_ec | r20 | 70,765,036 | 196,668,586 | 2.779 | 11,094 | 1,940,706 | 631,582 | 7,365,602 | 243,920 | 10,920,053 | 2,824,405 | 288,723 | 0 | 0 | 6,436,255 |
| bs_ec | 16 | 70,765,036 | 185,195,164 | 2.617 | 10,528 | 1,940,706 | 631,582 | 7,365,602 | 243,920 | 10,920,053 | 2,824,405 | 288,723 | 0 | 0 | 6,436,255 |
| bs_ec | 32 | 68,252,838 | 209,062,778 | 3.063 | 11,030 | 2,660 | 50 | 7,604,968 | 82,188 | 10,897,725 | 2,824,405 | 288,723 | 0 | 0 | 6,809,631 |
| **all six** | r20 | 743,035,852 | 2,331,404,858 | 3.138 | 204,438 | 54,970,818 | 13,948,279 | 51,204,194 | 5,590,892 | 123,318,281 | 178,438,541 | 19,249,570 | 23 | 0 | 29,227,091 |
| **all six** | 16 | 743,108,067 | 2,109,376,086 | 2.839 | 194,956 | 54,970,811 | 13,948,276 | 51,204,357 | 5,590,938 | 123,319,283 | 178,439,461 | 19,249,647 | 24 | 0 | 29,227,123 |
| **all six** | 32 | 743,216,858 | 2,288,837,620 | 3.080 | 200,882 | 18,239,050 | 6,313,229 | 58,079,462 | 5,313,506 | 122,231,251 | 178,314,383 | 19,249,588 | 33 | 0 | 30,030,082 |

## Differences

| program | 32 vs 16: instr | 32 vs 16: bytes | 32 vs 16: frame ld+st | 16 vs r20: instr | 16 vs r20: bytes | 16 vs r20: static text | 32 vs 16: static text |
|---|---|---|---|---|---|---|---|
| lz4 | -6.04% | -5.24% | -49.00% | +0.00% | -7.09% | -4.22% | +1.53% |
| zlib | -8.78% | -4.46% | -99.91% | +0.00% | -4.23% | -5.85% | +2.60% |
| lua | +12.37% | +22.01% | -98.73% | +0.03% | -16.39% | -4.06% | +2.76% |
| bs_hash | -0.27% | +2.93% | -100.00% | +0.00% | -4.71% | -4.23% | +3.40% |
| bs_sym | -3.73% | +14.97% | -25.30% | +0.00% | -5.09% | -5.02% | +7.04% |
| bs_ec | -3.55% | +12.89% | -99.89% | +0.00% | -5.83% | -5.10% | +4.77% |
| **all six** | +0.01% | +8.51% | -64.38% | +0.01% | -9.52% | -4.64% | +3.04% |

Reading the numbers (all exact counts, not estimates):
- pdp64/r20 -> pdp64/16, same assembly: executed instructions +0.01% (only cbCC that need cmp+bCC: 69,638 executed pairs in the six programs), executed bytes -9.5% (2,331 M -> 2,109 M, program code), bytes per executed instruction 3.138 -> 2.839 (all code 3.129 -> 2.833) against the model's 2.822 for the corpus-trained A16: the real value is 0.6% above the model (0.4% for all code). Linked images 226,606 -> 215,838 bytes (-4.75%), program text -4.64%; the model's static saving for the corpus is larger (it compares with a different baseline and counts only instruction bytes, no pools and alignment).
- pdp64/16 -> pdp64/32 (the 32-register code of pcc32):
  * executed instructions, raw: +0.01% (743.11 M -> 743.22 M). Per program: lz4 -6.0%, zlib -8.8%, Lua +12.4%, bs_hash -0.3%, bs_sym -3.7%, bs_ec -3.6%. The Lua +12.4% is entirely cbCC expansion: in pdp64/32 68 static cbCC sites (against 1 in pdp64/16) have no form that reaches (immediate beyond the 8-bit field with a target beyond the 12-bit field; the opcode dispatch chain of luaV_execute is 80+ `cbeq r0,#N,far`), and each executes as cmp + bCC: 38,758,565 extra executed instructions in Lua, 38,864,207 in the six (16: 69,638). Counting each expanded pair as the one cbCC it replaces, 32 vs 16 is **-5.21% executed instructions** (lz4 -6.04, zlib -8.78, Lua -4.41, bs_hash -0.43, bs_sym -3.73, bs_ec -3.55), against the earlier estimate of 4.3% (category-weighted; 4.9% uniform; its bounds -1.0% to +9.5%). The raw figure is what pdp64/32 as specified in the phase-1 tables really costs; the adjusted figure is what the register file alone buys. Which of them the compiler sees depends on whether it keeps cbCC where the target is far (it can use a branch around, or the tables could get a longer cbCC).
  * executed frame loads+stores: 68.92 M -> 24.55 M, **-64.4%** (frame loads 54.97 M -> 18.24 M, stores 13.95 M -> 6.31 M) against the earlier estimate of 55% (bounds 31%-72%); per program zlib -99.9%, Lua -98.7%, bs_hash -100%, bs_ec -99.9%, lz4 -49%, bs_sym -25%. Register-to-register moves rise 51.2 M -> 58.1 M (+13.4%).
  * executed bytes: +8.5% raw (2,109 M -> 2,289 M); bytes per executed instruction 2.839 -> 3.080 raw. With the cmp half of every expanded pair removed from both (instructions and bytes; 16: 69,638 pairs, 32: 38.86 M pairs, 155 M bytes) it is 2.838 -> 3.029 and the executed bytes are +1.15% (lz4 -5.2%, zlib -4.5%, Lua +0.9%, bs_hash +2.7%, bs_sym +15.0%, bs_ec +12.9%). Against the encoding report's estimates 2.980 (A32) and 2.879 (A32r): raw 3.4% / 7.0% above them, adjusted 1.6% / 5.2% above. Reasons: the 4-bit hot table and the 5-bit cold forms (the new r24-r31 callee-saved registers are only partly hot), and the expansion pairs; the crypto kernels pay most as the report said (per program bytes/instr 16 -> 32, cmp halves removed: lz4 2.668 -> 2.691, zlib 2.724 -> 2.853, Lua 3.183 -> 3.361, bs_hash 2.858 -> 2.948, bs_sym 2.526 -> 3.017, bs_ec 2.617 -> 3.063).
  * static: linked images 215,838 -> 222,946 bytes (+3.3%; program text 194,956 -> 200,882, +3.0%; the phase-1 model said +3.6% on the corpus).
  * net: with the cbCC problem as it is, pdp64/32 saves nothing in instruction count and costs 8.5% more executed bytes and 3% more static text than pdp64/16; if far/wide cbCC kept a single instruction it would execute 5.2% fewer instructions and 64% fewer frame accesses for 1.2% more executed bytes and 3% more static text.

- Caveats: one stand-in libc, six programs, pcc32 is the earlier copy (8 extra caller-saved + 8 extra callee-saved, not tuned for the encoding or for hot registers); fused pairs are not emitted by the old compiler, so the numbers are for unfused code; the pdp64/16 and /32 sizes include the cbCC expansion the assembler does (phase 1), nothing else.

## 6. Not done / limits
- No hbnf second implementation of the new decoders (phase-1 decision); no EPSW poison/secret masks (the old executor has none either); no atomics, AES/SHA, UTF-8 decode/encode, MVAL (see 1); trapcc outside -K ends the program with a message.
- The QEMU target is unchanged (old encoding only) and its installed binary predates the executor fix.
- flaginv (flag-invariant test) still runs only the original encoding.
