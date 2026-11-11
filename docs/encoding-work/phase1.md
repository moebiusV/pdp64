Status: record, dated 2026-11-03 to 2026-11-04. It describes the state and the thinking of that time. The current state is in docs/manual and docs/decisions-and-status.md; where this document disagrees, those win. Out of date: the two-grammar naming (pdp64/16 and pdp64/32 as two machines, the r20 member), encoding-selecting `-m` options, paths that no longer exist (spec/pdp64-16, spec/pdp64-32, forms.json, docs/manual/pdp64-*, -m options) are in the git tags pre-single-cpu and pre-code-removal; the measurements stand as evidence for the choice of pdp64/32

# Phase 1 report: pdp64/16 and pdp64/32 encodings, shared codec, as64, ld64

Worktree <worktree>, branch enc-prefix (seven commits on top of 96b4180, none pushed, no history rewritten; main checkouts untouched; pcc-enc not needed).

## Baseline
The unmodified worktree built and `tools/check-all.sh` passed (exit 0, 47 s; output in scratchpad/baseline-check-all.txt). After the work `tools/check-all.sh` passes again with the same old checks unchanged (old format vectors, syntax tests, 
old assembled programs, drift over 420 mnemonics, ld64, sim64, p2diff, qemu...) plus the new ones. The old encoding is untouched; its objects have e_flags 0 and are byte-identical.

## Naming (author's later decision)
pdp64 is the family; pdp64/16 (r0-r15, 4-bit fields) and pdp64/32 (r0-r31, 5-bit); the old encoding is named pdp64/r20. Directories spec/pdp64-16 and spec/pdp64-32; `as64 -m pdp64/16|pdp64/32|pdp64/r20` (also 16, 32, old, r20); e_flags & 0xF = 1, 2, 0 (EF_PDP64_ENC_* in as64/relocs.h).
Fusing is NOT done by the assembler (author's decision): `--fuse` was added in commit 2481770 and removed in ef0ec06 (history kept honest).

## Design decision: no hbnf for the new encodings
hbnf could express the prefix code only as one alternative per leaf (281 / 255) with the fields cut into pieces, plus a table to say what the pieces mean; I did not implement that route. The single source of truth is a forms table
(spec/pdp64-NN/forms.json: forms with operand specs, mnemonics, leaves with prefix and every field's bit positions), written by the optimiser (docs/codegen-data/encoding/export_forms.py; solve.py rerun with the four fused pairs forced in; A16, and A32r = RR5 form for 8 mnemonics). tools/mkenc.py (the analogue of mkgrammar.py) verifies it (prefix code, each leaf covers 16n bits exactly once, no pattern in two leaves) and generates: the C tables of the codec, the assembler grammar variant (spec grammar + group mn-ext with the words only the new encodings have + registers r16-r31, in build/x so the old parsers and asmsyntax test are unchanged), the names header, and spec/pdp64-NN/tables.md (checked by `mkenc.py --check`).
Honest limit: the hbnf-generated format parser/writer is not used for the new encodings, so there is no second (hbnf) implementation to cross-check the codec; the cross-check is the Python model (below).

## What exists
- common/pdp64enc.{h,c}: table-driven codec (encode = first form that fits in table order, optionally with a minimum length for relaxation; decode; length from parcel 0; field extract/insert for relocations). No bit position in the C.
- as64/asmenc.c (included by as64.c): statement -> codec instructions, relaxation (lengths only grow; every distance measured on the previous pass's layout, labels committed at the end of a pass, exactly the model's iteration), cbCC -> cmp+bCC when no form reaches, movq #imm -> movql when no movq form fits, r16-r31 only in pdp64/32 (error otherwise), 22 meaningless shapes refused, relocation type chosen from the unit of the chosen field (INSN_PC unit 1, INSN_BR unit 2, INSN_ABS), nop padding and .lpad through the codec. Options -m, --stats, --dump-lens (new). Old path unchanged (old mode now also rejects r16+ with a message instead of a parse error; the asmsyntax test still uses the original grammar).
- ld64: codec-based relocation for the new encodings (finds the pc-relative/absolute operand, applies unit, range check with the same messages), refuses mixed encodings, writes e_flags in the executable.
- New instructions and every ISA word: all 305 mnemonics of each table (22 ATOM, 8 MESC, TRAPL, SYSX words, MASKEQZ/MASKNEZ/BSEL/AES*/SHA*/MSHA*/MAESCTR, TRAPCC x14, ADDV/SUBV/MULV, MOVQL, .u/.d moves, the four fused mnemonics, syspg0-5 placeholders) assemble and decode back to their own opcode in both encodings (tools/check-drift-enc.py: 680 checks, 0 differ; 35 aliases assemble to what the word they stand for assembles to).
- Docs: spec/README.md (family, route, notation choices, hot tables, commands), docs/abi.md draft (hot-register tables), docs/asm-syntax.md (two lines), docs/errata.md entry 87 (decided vs assumed; the naming). Manual chapters not touched.
- Follow-up noted, not done: linker relaxation of external call/lea (the encoding is ready: 4-byte call reaches +-2 MB); sim64, pcc, disassembler.

## Tables produced (optimiser rerun with the four fused pairs forced)
- pdp64/16: 219 forms, 281 leaves, 3,277 of 65,536 first parcels illegal (5.0%). 3-bit hot table r0 r1 r8 r2 sp r3 r9 r10.
- pdp64/32: 196 forms, 255 leaves, 3,277 illegal. 3-bit table as above; 4-bit r0 r1 r8 r2 sp r3 r9 r10 r11 r4 r15 r5 r24 r25 r26 r6. Fewer forms than the report's A32 (267) because RR5 + mov2 take 18.75% of the code space.
- Model sizes of the corpus, no fused mnemonics in it: pdp64/16 1,016,300 bytes (report's A16 without fusion forms: 1,013,598; the four fused forms, SETF and the cbpl.. forms cost 0.27%); pdp64/32 1,052,526 (report's A32r 1,039,442: +1.3%, same cause), i.e. pdp64/32 is 3.6% larger than pdp64/16 on this code.

## Verification numbers
Real as64 vs the Python model on the corpus (841 files; scripts docs/codegen-data/encoding/asm_vs_model.py, outputs scratchpad/corpus-results.txt). Corpus as compiled today, no fused mnemonics, no fusing by the assembler:
- pdp64/16: all 841 assemble with no error. 338,617 hardware instructions (338,313 source instructions + 304 cbCC expanded to cmp+bCC); as64 .text instruction bytes 1,016,238; model 1,016,300. 839 of 841 files identical instruction by instruction; the 2 others (chibicc_hashmap, lz4_xxhash) differ only in literal-pool loads (`mul =K,r0`), where the model uses a pseudo distance of 32,000 bytes and as64 knows the pool (31 instructions, 62 bytes shorter). Parcels compared one by one in the files whose lengths agree: 336,396 instructions, 0 differ (248 pool loads left out for the same reason).
- pdp64/32: all 841 assemble. 334,602 hardware instructions (730 expansions); as64 1,052,526 bytes = model 1,052,526; 0 files differ; 334,267 instructions compared parcel by parcel, 0 differ (335 pool loads excluded).
- Round trip: every instruction so assembled (336,396 and 334,267) decoded back with the C decoder and compared with the model's source operands: 0 mismatches.
- Codec vs model (tools/check-enc.py): table layout recomputed by enc.py equals forms.json; 19,631 (pdp64/16) and 18,182 (pdp64/32) boundary vectors (min, max, 0, +-1 of every field of every mnemonic of every form, externals included): same form, same parcels, same decode, 0 mismatches; the decoder on 43,724 / 36,284 first-parcel patterns, 0 mismatches. Mutation check: a one-bit change in a table is caught.
- Fused mnemonics (corpus has none): tested by the vectors and boundary vectors (movcall incl. external, popmret, popret, mov2), the drift test, and tests/asm-pdp64-NN/fused.s (hand-made file with the four mnemonics, parcels from the model) assembled by the real as64 and checked.
- New tests, expectations from the Python prototype not from as64: tests/enc/vectors-16.txt (80), vectors-32.txt (95); tests/asm-pdp64-16 and -32 (basic, branch, far (relaxation over 70 KB, cbCC expansion), extern, modes, misc, fused; 32 also regs32), tests/asm-err-pdp64-NN (refused shapes, r16 in pdp64/16, odd branch, read-only sysreg, .bss...), tests/asm-err/{r16-old,fused-old}, tests/ld-pdp64-NN (linked words, map, e_flags, the 2 GB limits, mixed-encoding refusal). Wired: tools/check-enc.sh in tools/check-all.sh; check-as64.sh and check-ld64.sh loop over the three encodings.
- Not verified: ld64 on the whole corpus (no executable of the new encodings can be run until the simulator exists); the corpus programs themselves.

## Things in the report/tables that were wrong, ambiguous or needed a decision (and how resolved)
1. R2 listed `set` as a 2-register mnemonic but `set cc,rd` needs the condition: added form SETF (4 bytes), dropped from R2. R3 contained a junk placeholder `mfsr_`: dropped.
2. cbpl/cbmi/cbvc/cbvs had no form (optimiser never picked one; no corpus use): added narrow forced forms CBDI/CBDR so the ISA opcode exists.
3. Greedy pairing of fusion candidates in fusion.py/fuse.py pairs by position, not by gain; irrelevant now since the assembler does not fuse (the model's fused corpus totals are not reproduced; not claimed).
4. Literal-pool loads: model distance 32,000 is a pseudo value (see above).
5. Report text says MESC words get all modes and widths; the optimiser selected no narrow form for them, so only the 3-parcel forms exist. Same for `.u/.d` moves (fixed wide forms by design). extb/extzb/insb: 6-bit width cannot hold 64.
6. Post-increment without a stride: the model encodes 0; the old assembler writes the explicit size. I followed the model (0 = size of the access); semantics for the simulator to define.
7. pushm/popm masks appear in the 32-register corpus as negative numbers (#-16740608); normalised to the low 32 bits (error beyond; in pdp64/16 beyond 16 bits).
8. d(DP) uses base "register 16" in the model, a collision in pdp64/32; the codec uses a sentinel (255).
9. cbCC expansion to cmp+bCC clobbers the flags (cbCC does not): inherited from the report; documented, needs a decision for the compiler (it can avoid or accept).
10. ATOM: 3 registers, `ll`/`sc` also three (the middle one unused), cas/casdb four; roles are for the ISA to fix.
11. Relaxation fixpoint is not unique: a first implementation (updating label values mid-pass, as the old assembler does) disagreed with the model on 20 files; the fix is the model's Jacobi iteration. The old assembler is unchanged.

## Not done / limits
- No hbnf for the new instruction formats (see design decision); the disassembler tool does not exist (the codec decoder + tests/enc/encdrv serve).
- pcc-enc was not touched; sim64 not touched (phase 2). Linker relaxation not done (phase later).
- as64 for the new encodings does not implement `.pool`-specific range diagnostics beyond the generic "no form" message; error texts for out-of-range values in the new modes are generic ("no form of this instruction ... takes these operands").

## Commits (oldest first)
7f391f8 spec: forms tables of pdp64/16 and pdp64/32 exported from the optimiser
122e249 common: table-driven codec, tools/mkenc.py, check against the Python model
55f6ac2 spec: narrow forms for cbpl/cbmi/cbvc/cbvs; mkenc names header and r16-r31 grammar; codec minimum length
2481770 as64: assemble the whole ISA into pdp64/16 and pdp64/32 (-m, --fuse), e_flags
dc1102e ld64: relocations of the new encodings, mixed encodings refused, e_flags
ef0ec06 as64: no fusing; tests for both encodings; check-all wiring
bb79182 docs: spec README, hot-register tables in the ABI draft, errata 87
