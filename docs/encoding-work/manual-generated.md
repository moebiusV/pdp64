# The generated parts of the three manuals

[← encoding work](README.md)

What `tools/mkmanual.py` generates for each CPU (pdp64/r20, pdp64/16, pdp64/32), from what, what is left for the hand-written text, and which statements of the generated entries the repository does not settle. The shape is errata 93: one hand-written source (`docs/manual-src/`, README there), three generated and committed manuals (`docs/manual/pdp64-r20/`, `pdp64-16/`, `pdp64-32/`).

## 1. Numbers

| | pdp64/r20 | pdp64/16 | pdp64/32 |
|---|---|---|---|
| mnemonic words (instructions and aliases) | 270 (234 and 36) | 340 (304 and 36) | 340 (304 and 36) |
| of them only in the prefix-coded CPUs (`mn-ext`) | 0 | 70 | 70 |
| instruction entries in chapter 9 | 106 | 125 | 125 |
| implemented in the reference executor | 200 of 234 | 241 of 304 | 241 of 304 |
| bit-layout charts of the layouts (one SVG each) | 67 (+1 page-2 chart) | 270 (one for each leaf) | 268 |
| charts of single instruction words (`figures/w/WORD.svg`, `dictionary/by-word.md`) | 234 files, 897 charts | 304 files, 1,178 charts | 304 files, 1,178 charts |
| SVG files in `figures/` | 305 | 577 | 575 |
| dictionary pages | 8 | 6 | 6 |
| book (built to try it, not committed) | 199 pages, 4.8 MB | 258 pages, 4.8 MB | 259 pages, 4.8 MB |

The r20 count looks for `MN_...` names in `common/pdp64exec.c` and counts as implemented the words that the executor handles by falling through (`nop`, `fence`, `sev`, `lpad`, `icinva` fall to the `default: return` of the class-0 switch, `jmpi` is the fall-through of the XFER group); the 34 it does not count are the atomics, the unaligned moves and `addm` and its kin, `utf8len`, `utf8dec`, `utf8enc` and `mval`. The prefix-coded count reads the table of words in `common/pdp64exec_enc.inc` and is exact. Of the 70 new words 32 are implemented (the four fused pairs, `maskeqz`, `masknez`, `bsel`, `addv`, `subv`, `mulv`, `movql`, the 14 `trapcc`, the seven `.u` moves); 38 are not (the seven `.d` and seven `.ud` moves, the seven AES words, the eight SHA words, `msha256`, `msha512`, `maesctr` and `syspg0` to `syspg5`).

## 2. What is generated, from what

| Output (in each `docs/manual/pdp64-M/`) | Source |
|---|---|
| the chapters and appendices | `docs/manual-src/*.md` with the member blocks resolved (`tools/manual/assemble.py`) |
| the entries of chapter 9 (between the `<!-- entries:N.N -->` markers), the notation paragraph, the link tables of 6.7 and 7.12 | `tools/manual/isa_part1..4.py`, `isa_stories.py`, `isa_stories_ext.py`, `isa_enc.py`, `memberprose.py`; the words of the member from `spec/pdp64-mnemonics.hbnf` (and, for pdp64/16 and /32, group `mn-ext` of `spec/pdp64-enc.hbnf`) |
| `dictionary/index.md`, `by-mnemonic.md`, `aliases.md`, `constants.md` | the same; the counts are per member |
| `dictionary/by-opcode.md`, `page2.md` (pdp64/r20 only) | `spec/pdp64-mnemonics.hbnf` |
| `dictionary/by-encoding.md`: the chart of every opcode, with its legend, the index of the mnemonics, and for the prefix-coded CPUs the hot-register tables and the operand shapes with their widths and reach | the grammars (section 3) |
| `figures/*.svg` | the grammars (section 3); `format-parcel0`, `format-extension`, `psw` and `page2` only where the text still refers to them |

## 3. The charts and the model that an hbnf backend can replace

*Where the layouts come from.* pdp64/r20: `spec/pdp64.hbnf.in` (the head `len:2 opc:6 reg:4 low:4` and the guarded alternatives of the body are read, and the guards are evaluated for every opcode, length, `reg`, `low` and sub-opcode, which gives each opcode its body), `spec/pdp64-mnemonics.hbnf` (every number), `spec/pdp64-system.hbnf` (the status word) and the new `spec/pdp64-layout.hbnf` (what a field is *for* in each class: `Rd`, `Rs`, `mode`, `class`, the split of `low` in the tag branch, the merge of `reg` and `low` into the 8-bit displacement of the short branch; the one-line notes under the charts). pdp64/16 and /32: `spec/pdp64-enc.hbnf` and `spec/pdp64-NN/pdp64-NN.hbnf` through `tools/encgram.py` (`leaf_pieces`: prefix, sub-opcode, operand pieces with their bit positions). Nothing about a layout is written in the Python: the two literal tables that stayed there are the order of the classes and their titles (`MN_KINDS`, `KINDTITLE` in `layouts.py`, headings only).

*The neutral model* (what a replacement has to produce; `tools/manual/layouts.py`): a chart is a dict with `id`, `title`, `rows` (a list of `(row label, [(field label, width in bits, value or None), ...])`, one row for each 16-bit parcel, fields in record order, bit 15 first, a field that crosses a parcel boundary cut and its second part labelled `(cont.)`), `legend` (lines of Markdown under the chart), `mns` and, for a leaf, `fields` (`opN.part=pK[hi:lo]`). A value is a string of bits for a fixed field (shaded) and `None` for a variable one. The drawing is the single function `svg_rows(rows)`: deterministic, no timestamp, byte-stable (`tools/mkmanual.py --check` compares every file), two fills (`#e8e8e8` fixed, white variable), all in that function. An hbnf backend that emits SVG for the same rows replaces `svg_rows` and nothing else; one that emits the whole chart replaces `r20_charts` and `Enc.chart`, whose result is the dict above, without touching the dictionary assembly (`by_encoding_page`, `encoding`).

*What is a chart.* Two kinds. The charts of the layouts (`dictionary/by-encoding.md`, `figures/ID.svg`): for pdp64/16 and /32 one for each leaf (the sub-opcode of each mnemonic is in the legend); for pdp64/r20 one for each distinct layout (class, length, body), the opcode field white when the class has several opcodes and a table giving each mnemonic its numbers. These are the charts that the entries of chapter 9 embed and list, and the book contains. The chart of every instruction word (`dictionary/by-word.md`, `figures/w/WORD.svg`): the layout with that word's own bits filled in (opcode or prefix, sub-opcode, fixed fields, operand fields named), one chart for each form the grammar gives the word, stacked in one SVG file for each word (one file for each word keeps the count at 234 and 304 instead of 897 and 1,178 and keeps a page of the web manual to one image for each word; `movq` has 51 forms and a 120 KB file). Aliases have the chart of the word they stand for. The entry of each instruction links to the chart of each of its words. These pages are in the web manuals and not in the books (they would add some 300 pages to each book; the books keep the charts of the layouts).

## 4. The entries for the 70 words of `mn-ext` (pdp64/16 and /32)

Nineteen entries (`tools/manual/isa_part4.py`, stories in `isa_stories_ext.py`). Each says in its notes how firm it is.

| Entry | Words | Tag | In the executor |
|---|---|---|---|
| MOVCALL, POPRET, POPMRET, MOV2 | the four fused pairs | (D), errata 87 | yes |
| MASK | `maskeqz`, `masknez` | (D), errata 85 | yes |
| BSEL | `bsel` | (P): "adopt" in the crypto proposal, not separately confirmed | yes |
| MOVQL | `movql` | (D), errata 85 | yes |
| OVF | `addv`, `subv`, `mulv` | (D), errata 85; the three-register form of the proposal is (P) | yes (two-register form) |
| TRAPCC | 14 words | (D), errata 85 and 86 (trap, not abort); the vector number 16 is (P) | yes |
| MOVD | `.d` loads (7) | (P): the poison bit of item 10 is not decided | no |
| MOVUSER | `.u` moves (7) | (P): item 18, leanings accepted (errata 86), not specified in full | as a plain move |
| MOVUSERD | `.ud` loads (7) | (P): the combination has no text of its own | no |
| AESR, AESK | seven AES words | (P): crypto proposal sections 3 to 5 await the author | no |
| SHA256, SHA512 | eight words | (P) | no |
| MSHA, MAESCTR | three words | (P): stage 2, "only after measurement" | no |
| SYSPG | `syspg0` to `syspg5` | (S): placeholders | no |

## 5. Statements the repository does not settle (open, tagged in the entries)

* The `CHECK` vector number 16 is in `docs/study-proposals.md` item 9 and in the executor; `spec/pdp64-system.hbnf` has no such vector.
* `POPMRET` names `R8` to `R15`: the grammar has an 8-bit field scaled by 256 (`imm8u-x256`); that the scaled mask is a bit mask of `R8` to `R15` is read from the grammar and from the `pushm8` of the original second page, not from a sentence of the repository.
* The two-register form of `addv`, `subv`, `mulv` is the grammar's; the proposal has three registers (errata 88 notes it).
* The spelling of the deferred load: the proposal says `.S`, the grammar `.d`. The combination `.ud` is described as the composition of two qualifiers; the repository has no text for it.
* AES and SHA: all semantics are the proposal's, to be checked against FIPS 197 and 180-4 (the proposal says so); the SHA-256 result is zero-extended there while every other 32-bit result is sign-extended; the register pair of the AES round is fixed by the proposal (any two registers, low half first) and by nothing else.
* The placement of the operands of the atomics is still open in the ISA text; the manuals of pdp64/16 and /32 say that the grammars assume three registers (errata 87 (4)) and tag it (P).
* The text under the entries that are common to the three CPUs is the text of pdp64/r20 with the sentences that state a layout of the original encoding left out (`tools/mkmanual.py --dropped`), with replacement notes and rewritten stories (`isa_enc.py`); every changed field, what it said, what replaced it and whether it carried meaning is in `manual-dropped-sentences.md` (58 fields of 44 entries; what carried meaning was restored for the member); byte counts that differ between the CPUs are not stated.

## 6. Left for the hand-written text (`docs/manual-src/`, section 3.2 of `docs/manual-update-plan.md`)

Chapter 9, sections 9.1 to 9.5 (the opcode space, the principles, the registers, the format, the addressing modes), 9.10, 9.13, 9.18, 9.19, 9.21; chapter 1 (the table of how to find the next instruction); chapters 6, 7, 8 (`trapcc`, the deferred and user-qualified moves, the core counts); appendices A to F; `00-index.md`. Until it is written the manuals of pdp64/16 and /32 carry the pdp64/r20 text there and the three figures `format-parcel0`, `format-extension` and `psw` (drawn from the grammar of pdp64/r20), which a member block removes. A prefix-coded manual that no longer refers to a figure no longer gets the file.

## 7. Checks

`tools/mkmanual.py --check` (in `tools/check-all.sh`) regenerates the three manuals and fails on a stale, missing or orphan file, on a chart that differs from the grammar, on a word with no chart (the per-word charts and the layout charts), on a chart with no mnemonic, on two words with the same file name, on a prefix-coded member whose charts are not exactly its leaves, on a section or statement number that is not contiguous, on a broken link or a section reference without a target. `tools/check-manual-src.py` tests the assembly itself. `tools/mkbook.sh --check` checks the three books (the outline marks the pdp64/r20-only pages with `@r20:`). A build of the books found one problem, fixed: the HTML anchors of the dictionary pages stopped `cmarker` (they are removed for the book).
