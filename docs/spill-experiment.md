# Register-spill measurement: what would 32 registers remove on the pcc/pdp64 corpus

[← pdp64 index](../README.md)

Static counts over the 841-file corpus compiled by pcc, with the 16-register back end and copies of it given 24 and 32 registers (assembly text only; the 32-register code was not assembled or run).


## Method (same as the project's)
- Corpus: the 841 files from `fair_files()` of tools/pdp64size.py (RESULTS=/tmp/co-final/results.jsonl, sources in ~/claude/corpora), each preprocessed once with `gcc -E` against the aarch64 musl headers, exactly as pdp64size.py does (`tools/pdp64size.py` imported unmodified for preprocess/parse/shape).
- Compiler: pcc `ccom` built from a copy of ~/claude/pcc HEAD (d44d98a4), flags `-xdmr -xtemps -xdeljumps -xinline -xdce` (the project's `ccomflags('pdp64')`). Static counts: the project's rule (text-section lines that are not directives, labels or comments). Static, not executed counts.
- Baseline sanity: 16-register copy compiles 841/841 files; all 841 assemble with build/as64. Total 338,313 instructions (all 841 files). docs/codegen-data/pdp64-after-errata39.csv last row: 335,877 for the 827-file set; the extra 14 files and the small gap explain the difference. The 370,115 figure of docs/codegen-analysis.md is an older compiler. Consistent.

## The 32-register back end (copy of arch/pdp64)
- macdefs.h: MAXREGS 16 -> 32; RSTATUS/ROVERLAP extended; pass-2 numbers 16..31 are r16..r31 (names added to rnames[] in local2.c); COLORMAP limit 13 -> 29. Existing internal numbering kept (r12 scratch, r13 FP, r14 SP untouched, still not allocated).
- ABI split chosen: r16-r23 caller-saved (TEMPREG, clobbered by a call), r24-r31 callee-saved (PERMREG). So 8+8 -> allocatable 16 caller-saved (r0-r7, r16-r23) and 13 callee-saved (r8-r11, r15, r24-r31); r12/r13/r14 as before.
- local2.c: prologue/epilogue save set includes i>=24; pushm mask printed with %u (mask now exceeds 16 bits; the text only, no encoding).
- peep.h (the text-level peephole and liveness pass) had 16-bit register masks and refused names above r15; widened to 64-bit masks, call clobber set extended to r16-r23, ret-reads extended to r24-r31, rename allowed for r16+. Without this the peephole would have been unsound.
- Variants: r24 = 24 registers (r16-r19 caller-saved, r20-r23 callee-saved); r32t = 32 with r16-r27 caller-saved / r28-r31 callee-saved; r32p = 32 with r16-r19 caller-saved / r20-r31 callee-saved (sensitivity of the split).
- All variants compile 841/841. The new registers are used: in r32, r24 appears 5,359 times, r25 3,500, ... r16 797, r23 94 (textual occurrences in the assembly).

## Results (static instruction counts, 841 files)

| metric | 16 reg (base) | 24 reg | 32 reg (8t+8p) | 32 reg (12t+4p) | 32 reg (4t+12p) |
|---|---|---|---|---|---|
| total instructions | 338,313 | 334,564 | 333,872 | 334,413 | 333,709 |
| removed | | 3,749 (1.11%) | 4,441 (1.31%) | 3,900 (1.15%) | 4,604 (1.36%) |
| frame loads, sp/fp-relative mov to reg | 15,515 | 10,752 | 9,871 | 10,658 | 9,649 |
| frame stores | 8,447 | 6,193 | 5,812 | 6,143 | 5,717 |
| frame mem total (load+store) | 23,962 | 16,945 | 15,683 | 16,801 | 15,366 |
| frame mem removed | | 7,017 (29%) | 8,279 (35%) | 7,161 | 8,596 |
| sp/fp ALU forms (add/sub/cmp... on frame slot) | 1,476 | 1,096 | 988 | 1,084 | 970 |
| push/pop + pushm/popm instructions (callee-save) | 10,424 | 10,308 | 10,294 | 10,292 | 10,308 |
| callee-saved register slots saved (pushm popcount + pushes/pops) | 23,476 | 26,022 | 26,442 | 27,036 | 26,622 |
| movq reg,reg | 46,197 | 49,859 | 50,477 | 49,868 | 50,626 |
| register-register extensions (movl/movzb.. r,r) | 8,844 | 9,090 | 9,148 | 9,101 | 9,179 |
| sub/add #n,sp and fp/sp setup (frame adjust) | 3,661 | 3,309 | 3,277 | 3,299 | 3,269 |
| lea of a frame address (address of locals; not a memory access) | 6,593 | 6,131 | 6,072 | 6,131 | 6,046 |

Key reading: 32 registers remove about 8,300 frame loads and stores (35% of them) but only 4,441 instructions net (1.31% of the baseline), because the registers that replace the spills cost moves (+4,280 `movq reg,reg`, +304 extensions) and more callee-saved slots (+2,966 slots saved, +0 to -130 in push/pop instruction count since pushm is one instruction whatever the mask). Net = -8,279 frame mem - 521 lea - 384 frame adjust - 488 frame ALU +4,280 moves +304 ext, etc.
The 24-register configuration gets 84% of the instruction reduction of 32 (3,749 vs 4,441) and 85% of the frame-memory reduction.
Callee-saved push/pop instruction count barely changes (it is one `pushm`/`popm` per function whatever the mask); the number of saved registers rises 13% (23,476 -> 26,442), which at runtime is 8 bytes of stack traffic each, not visible in an instruction count.

## Spill versus named local
Not distinguishable in the .s: pcc does not mark spill slots in the output, and named locals that stay in memory (address taken, arrays, structs) are also sp-relative. So the "frame mem" rows count all sp/fp-relative loads and stores (no distinction, as you allowed). The drop between configurations is the best available estimate of spill traffic eliminated: 8,279 of 23,962 (35%) in r32; the remaining 15,683 are named locals, aggregates, stack-passed arguments and spills that 29 registers still do not hold. Frame accesses are at most 23,962/338,313 = 7.1% of baseline instructions (including real locals); the configuration difference removes 8,279 of them (2.4% of the baseline), and the net instruction reduction after the added moves is 1.31%.
Callee-save pushes/pops: 10,424 instructions = 3.1% of the baseline (4,836 pushm/popm, 5,588 push/pop of one register), unchanged by more registers.
Register-to-register `movq`: 46,197 = 13.7% of baseline.

## Per project (instructions base16 -> r32; frame mem base -> r32)
| project | files | base | r32 | removed | % | frame mem |
|---|---|---|---|---|---|---|
| bearssl | 294 | 53,615 | 52,008 | 1,607 | 3.00% | 5,313 -> 2,577 |
| c-testsuite | 213 | 4,668 | 4,661 | 7 | 0.15% | 171 -> 166 |
| chibicc | 8 | 14,349 | 14,275 | 74 | 0.52% | 1,331 -> 1,170 |
| cjson | 2 | 4,655 | 4,604 | 51 | 1.10% | 243 -> 97 |
| gcc-torture | 169 | 81,172 | 81,136 | 36 | 0.04% | 450 -> 416 |
| lua | 34 | 38,693 | 38,077 | 616 | 1.59% | 1,657 -> 711 |
| lz4 | 5 | 10,492 | 10,174 | 318 | 3.03% | 1,424 -> 847 |
| mbedtls | 101 | 117,729 | 116,428 | 1,301 | 1.11% | 12,465 -> 9,419 |
| zlib | 15 | 12,940 | 12,509 | 431 | 3.33% | 908 -> 280 |
(gcc-torture is dominated by one huge straight-line file, memcpy-a2.c, where registers do not matter. The 841-file counts differ from the documented 827 fair set by 14 files: gcc-torture 169 vs 158, zlib 15 vs 12.)

## Functions
- 8,650 text labels/functions compared. With 32 registers: instruction count changed in 581 (6.7%); of these 44 got longer; any counter at all differing in 728. 279 of 841 files have different assembly. 24 registers: 574 changed, 42 longer, 724 with any difference, 274 files differ.
- Ten largest reductions (r32): luaV_execute (lua lvm.c) -272 (3416->3144, frame mem 360->48); zlib inflate -169; inflate_table -88; bearssl br_aes_ct_bitslice_Sbox -72; inflateBack -67; LZ4HC_InsertAndGetWiderMatch -49; LZ4_compress_generic_validated -48; mbedtls ssl_parse_client_hello -47; br_aes_ct_bitslice_decrypt -47; mbedtls poly1305_process -45. (Ten largest for 24 registers are in rep.out; luaV_execute -234, inflate -137.)
- Reductions are concentrated: luaV_execute alone is 6% of the total removal; the top ten are 884 of 4,441 (20%).

## Instruction lengths
- Baseline length histogram (exact, from assembling all 841 files with as64 and walking .text): 2-byte 187,420 (55.4%), 4-byte 98,164 (29.0%), 6-byte 52,729 (15.6%); total 338,313; 1,083,870 bytes of instructions.
- Exact lengths of the baseline's categories (exact.py): frame loads 13,410 two-byte / 1,976 four-byte / 129 six-byte (86% one-parcel, mean 2.29 bytes); frame stores 7,048 / 1,311 / 88 (83% one-parcel, mean 2.35); `movq reg,reg` always 2 bytes; pushm/popm and push/pop of a register always 2 bytes. So spill-type loads and stores are mostly the short form, not 4-byte as one might expect; what replaces them (register moves) is also 2 bytes.
- The 32-register code cannot be assembled (no encoding for r16+), so exact lengths of the new code do not exist. Estimate only: assigning each instruction the most common baseline length of its mnemonic+operand-shape form gives 71.5% of the 4,441 removed instructions as 2-byte forms and about -11,358 bytes of ~1,092,594 (1.0%); 24 registers: 69.8%, -9,712 bytes. This estimate is crude (modal length ignores displacement size, which pushes it toward 2 bytes) and assumes r16-r31 fit wherever r0-r15 do, which a real encoding may not. Treat it as an order of magnitude only.

## Limitations (read these before quoting a number)
- Static counts only; no executed (dynamic) counts, so loop-resident spills weigh the same as straight-line ones. The question as asked (fraction of executed instructions) is not answered by this.
- Correctness of the 32-register code was not verified (cannot assemble or run it); the figures assume the allocator and my peephole widening are right. The compile is clean and the registers are used, nothing more is claimed.
- The 16-register back end is pcc's graph-colouring allocator with no live-range splitting and its own spill heuristics; a better allocator would spill less at 16 and gain less from 32 (the converse also possible). "Spills avoided" is a property of pcc, not of the ISA alone.
- The caller/callee split biases the result: r32 (8t+8p) 4,441; r32t (12t+4p) 3,900; r32p (4t+12p) 4,604 (range 3,900-4,604, 1.15-1.36%). pcc prefers callee-saved registers for values live across calls, so more callee-saved gives fewer spills but more saved slots (26,442 vs 27,036 vs 26,622).
- pushm/popm with a mask above 16 bits is not an ISA instruction; they are counted as one instruction each. If 32 registers needed a second pushm, callee-save instructions would increase.
- Frame loads/stores include real named locals and stack-passed arguments; only the difference between configurations is spill-attributable.
- The corpus is the project's: gcc-torture and c-testsuite files are tiny test programs; the libraries (bearssl, mbedtls, lua, zlib, lz4, cjson, chibicc) are where the effect is (0.5-3.3%).
- The LLVM back end has only its machine-code layer (no code generator yet), so an LLVM measurement is impossible and was not attempted.
- Not measured: code-size effect of wider register fields in the encoding, decode cost, context-switch cost of the 16 extra registers.
