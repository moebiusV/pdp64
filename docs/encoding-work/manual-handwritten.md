Status: history. Superseded by the single manual (docs/manual-src, docs/manual). Kept for the record; do not use it to learn the current design. Out of date: the three manuals and their per-encoding hand-written text

# The hand-written text of the manuals of pdp64/16 and pdp64/32

[← encoding work](README.md)

What was written in `docs/manual-src/` for the two prefix-coded CPUs, the system-level corrections made for all three manuals, what was checked, and what the repository did not let the text settle. The mechanism is `docs/manual-src/README.md`; the generated parts are `manual-generated.md`.

## 1. Method

Each member-specific passage is a member block (`<!-- member: r20 -->` followed by `<!-- member: 16 32 -->`) or an inline `[[r20: ...]][[16 32: ...]]`, written so that the manual of pdp64/r20 is byte-identical where only the prefix-coded CPUs are concerned. Numbers (statements, sections) are literal and were written for each member; `tools/mkmanual.py --check`, `tools/check-manual-src.py` and `tools/mkbook.sh --check` pass at every commit. Every number comes from `spec/pdp64-16/tables.md`, `spec/pdp64-32/tables.md`, the generated `dictionary/by-encoding.md`, `docs/encoding-work/integration.md`, `pcc2.md`, `phase3-pcc.md`, `docs/encoding-proposal.md` and `docs/errata.md`. `tools/check-all.sh` was not run: it needs `build/` and `tools/build-hbnf.sh` needs the network.

## 2. Member-specific text (pdp64/16 and pdp64/32 only)

| File | Sections |
|---|---|
| `09-isa.md` | chapter introduction; 9.1 (prefix code, leaves, forms, lengths, illegal patterns, the 70 new words, commentary with the measured cost and gain); 9.2.1, 9.2.3 and a new 9.2.13 (measured sizes); 9.3.1, 9.3.5 and new 9.3.8 (register-save masks) and 9.3.9 (pdp64/32: `R16`-`R31`, the draft split); 9.4.1, 9.4.3 to 9.4.5 and a new 9.4.6 (hot-register tables); 9.5.1 (a table of modes by length), new 9.5.4 (pc-relative widths) and 9.5.5 (linker relaxation); the opcode annotations of 9.6 to 9.14 (r20 only); 9.6.6, 9.9.2, 9.10.1, 9.10.3, 9.10.4, new 9.10.7 (fused pairs) and 9.10.8 (far `CBCC`); 9.11.1; new 9.13.3 (ATOM operand placement, open, P); new 9.15.2; 9.16.4, 9.16.5; 9.17.4; 9.18.5 and new 9.18.6 to 9.18.9 (the compiler's idioms); 9.19; 9.20.2 to 9.20.5; 9.21.1, 9.21.2 and a new 9.21.3 (open items of the encodings) |
| `01-introduction.md` | register count; 1.5.2, 1.5.3; two cells of the table of 1.6; 1.3 commentary; a new 1.8 "The three CPUs" (all three manuals; links to the other two) |
| `00-index.md` | the sentence naming the CPU; item 11 |
| `06-kernel.md` | 6.2 vector 16 (check, P); 6.5.2, 6.7.2 (`TRAP`/`TRAPL` are one word with an 8-bit number); new 6.5.4 (`.U` moves, P), 6.7.8 (`TRAPCC`), 6.8.7 (deferred loads, poison, P) |
| `07-smp.md` | 7.1.3, 7.4.2 and its commentary (six-byte `MOVQ d(DP), Rd`), 7.12.1; new 7.12.5 (atomics, P) |
| `appendix-c-glossary.md` | the r20 terms (`len`, page 1 and 2, top-level and escape opcode) are r20 rows; leaf, prefix, form, sub-opcode, hot register, fused instruction, relaxation added |
| `appendix-d-abi.md` | the register row; new D.3 (hot tables), D.4 (masks; pdp64/32 `R16`-`R31`, P), D.5 (the old D.3) |
| `appendix-e-assembler.md` | registers, compare and branch, length; new bullets: invocation, words of the CPU, relaxation objects |
| `appendix-f-evidence.md` | new F.4 (the integration table, the six programs, the timing model, predictions against measurements, what is not established) |
| `appendix-a-improvements.md` | A.8 and A.9 for the leaf table (no page 2) |

## 3. System-level corrections (all three manuals)

These change the pdp64/r20 manual too (the full list of its differences from the generated manual of branch `man-gen` is in section 6).

* **PCI Express (errata 75, 79, 80, 81):** a note at the head of chapters 2, 4 and 5; 2.1.1, 2.1.5 (was the AXI proposal) and 2.7; the transport (R4), DMA protection (R6) and USB/virtio (Q10) items of appendix B closed (B.2.7, B.2.9, B.2.14); the mapping of the bus atomics onto PCI Express stays open (7.13). Chapter 3 already carried the iteration-two note.
* **Cores (errata 92, 76, 85, 86):** 7.7.1 (four cores of the first device), new 7.7.3 (at least four, sixteen or more preferred, D) and 7.7.4 (the protocol beyond four, P), 7.8.5 (mixed cores, D), 7.8.6 (the secure core, D), 7.8.7 (dedicated cores, P); 9.21.1; 10.1.6 (the other cores are no longer "optional and last"), new 10.1.8 (the FPGA fit, E); B.2.6; glossary rows for core class, secure core, dedicated core.
* **Closed or approved items:** A.1 to A.5 each gain a statement of what errata 84 to 86 decided; B.1.9 and B.2.3 gain the replies of errata 85 and 86.

## 4. Figures

`format-parcel0.svg` and `format-extension.svg` are r20 figures; their references are inside the r20 blocks of 9.1 and 9.4, so the manuals of pdp64/16 and pdp64/32 no longer get the files (the generator removes them). `psw.svg` is kept in the three manuals: it is drawn from `spec/pdp64-system.hbnf`, the status word is common to the three CPUs, and a prefix-coded manual that dropped it would lose the status word.

## 5. What the repository does not settle (tagged P or S in the text)

* **The reach of the 4-byte `CALL`.** The grammar (`CALL2_18`, shape `pc18-u2`) gives an 18-bit field of parcels, ±256 KiB; `docs/relaxation.md` and `spec/README.md` say ±1 MiB (20 bits), which is the figure before the re-optimisation. The manual follows the grammar (9.5.4, 9.5.5).
* **The `CBCC` reaches.** `spec/README.md` says "a target up to 4 KB, 2 MB, 32 MB away" for the three-parcel forms; the shapes (`pc12-u2`, `pc20-u2`, `pc24-u2`) are ±4 KiB, ±1 MiB, ±16 MiB. The manual follows the shapes. The count of far `CBCC` is 0 and 13 (integration report); `spec/README.md` still says 4 and 17.
* **The ABI split of `R16`-`R31`.** `docs/abi.md` calls it a draft (`R24`-`R26` callee-saved); the compiler implements `R16`-`R23` clobbered and `R24`-`R31` saved. Tagged P (9.3.9, D.4.2).
* **`TRAPCC`:** the vector number 16 and `EVA` are the implementer's assumption (errata 88); `ADDV`/`SUBV`/`MULV` are an abort in the executor (P).
* **The operand placement of the atomics, the size of `CAS`, the deferred and user-qualified moves (poison bit, `.UD`), AES/SHA semantics, `BSEL`, `SYSPG`:** P or S as in the entries.
* **The coherence protocol beyond four cores, dedicated cores:** `docs/smp-decisions.md` is a set of proposals; only its framing (errata 92) is D.
* **Figures that the text quotes and the repository does not recompute:** the counts of forms and leaves (208/270 and 207/268), of leaves by length and of unassigned first parcels are written as literals in 9.1.2, 9.1.4 and 9.1.5; a re-optimisation of the grammars makes them stale, and no check compares them with `tables.md`.

## 6. Differences of the generated pdp64/r20 manual from branch `man-gen`

`00-index.md` (sentence naming the CPU, link to the landing page); `01-introduction.md` (new 1.8); `02-bus.md` (note, 2.1.1, 2.1.5, 2.7); `04-boot.md`, `05-drivers.md` (the note); `06-kernel.md` (none after the last commit); `07-smp.md` (7.7.1, 7.7.3, 7.7.4, 7.8.5 to 7.8.7, 7.13); `09-isa.md` (9.21.1 only); `10-conclusion.md` (10.1.6, 10.1.8); `appendix-a` (A.1.2 to A.5.2); `appendix-b` (B.1.9.2, B.2.3.2, B.2.6.1, B.2.7.1, B.2.9.1, B.2.14.1); `appendix-c` (family, core class, secure core, dedicated core); `appendix-e` (the invocation bullet); `appendix-f` (rows for the new decision documents). Nothing else.

## 7. Found in the generated parts (not edited here)

* The entry TRAP in the manuals of pdp64/16 and /32 still shows `TRAP #n ; n = 0 to 15, two bytes` and `TRAPL #n ; n = 0 to 255, four bytes` in its syntax block, while its own text says both are one word with an 8-bit number.
* The text of the PUSHM/POPM entry says "The second page has 8-bit forms for `R8` to `R15`" (a page-2 statement) in both prefix-coded manuals.
