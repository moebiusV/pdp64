# Plan for bringing the manual up to the architecture family

Status on 2026-11-04. This is a plan, not an update: **`docs/manual/` has not been touched** by the integration of the encoding work.
The manual describes one machine, revision 20 (`pdp64/r20`, parcel 0 = `len opcode reg low`). The repository now has a family of three
members: `pdp64/r20` (the original encoding), `pdp64/16` (prefix-coded, 16 registers) and `pdp64/32` (prefix-coded, 32 registers), with
new instructions that exist only in the two new encodings (the 70 words of group `mn-ext` in `spec/pdp64-enc.hbnf`). What follows says what
in the manual is generated, what is written by hand, what the new encodings and the new instructions invalidate, and what the work costs.

## 1. What is generated, and from what

`tools/mkmanual.py` (619 lines) rewrites, on every run and in `--check` mode in `tools/check-all.sh`:

| Output | Content | Source of the numbers | Source of the words |
|---|---|---|---|
| `docs/manual/dictionary/by-mnemonic.md`, `by-opcode.md`, `aliases.md`, `constants.md`, `index.md`, `page2.md` (6 pages) | the reference tables of the dictionary | `spec/pdp64-mnemonics.hbnf` (opcode numbers, groups, aliases), `spec/pdp64-system.hbnf` (system registers, constants), `common/pdp64exec.c` (which instruction the executor implements) | `tools/manual/isa_entries.py`, `isa_common.py` |
| `docs/manual/figures/*.svg` (112 files) | one encoding diagram per entry plus `format-parcel0`, `format-extension`, `psw`, `page2` | the same, via `fig()` in `mkmanual.py`: every diagram draws the **r20** fields `len 2 / opcode 6 / reg 4 / low 4` | `mkmanual.py` |
| the regions between `<!-- entries:9.N -->` and `<!-- /entries:9.N -->` in `docs/manual/09-isa.md` (3,998 of its 4,337 lines: 106 instruction entries in sections 9.6 to 9.14) and the block `<!-- notation -->` | the instruction entries (syntax, encoding diagram, operation, flags, exceptions, notes) | mnemonics file | `tools/manual/isa_entries.py`, `isa_part1.py` .. `isa_part3.py`, `isa_stories.py` (96, 133, 171, 101 and 148 lines of Python holding the prose) |
| the tables "the instruction entries for this section are in chapter 9" in `06-kernel.md` (6.7) and `07-smp.md` (7.12) | links into the chapter 9 entries | entries | `mkmanual.py` |
| `book/pdp64-manual.pdf`, `book/build/` | the book (Typst) | `docs/manual/*.md` through `tools/mkchapters.py`, `tools/mkbook.sh` | `book/outline.txt`, `book/sources.txt` |

The words of a generated entry are hand-written, but in the Python files under `tools/manual/`; the markdown between the markers is overwritten.
**Never edit a generated region in `docs/manual/09-isa.md`: change `tools/manual/*.py` or `mkmanual.py` and run `tools/mkmanual.py`.**

## 2. What is written by hand

`docs/manual/00-index.md` .. `10-conclusion.md`, `appendix-a` .. `appendix-f`, and in chapter 9 the sections that are not entries:
9.1 how the opcode space is divided, 9.2 properties and principles, 9.3 state: registers and flags, 9.4 the instruction format, 9.5 addressing modes,
the introductions of 9.6 to 9.14, 9.15 faults, restart and memory management, 9.16 position-independent code, 9.17 what was rejected, 9.18 idioms,
9.19 side by side (PDP-11, VAX), 9.20 LoongArch, 9.21 what is still open. The numbers inside these sections are literal and are checked only by
`tools/mkbook.sh --check` for the heading numbers.

## 3. What the new work invalidates or leaves unsaid

### 3.1 In the generated parts (fix in the generator, regenerate)

1. **Every encoding diagram** (112 SVG) draws the r20 parcel. For a family each entry needs either one diagram per member or a diagram for r20 plus a pointer to the
   per-member tables `spec/pdp64-16/tables.md` and `spec/pdp64-32/tables.md` (the prefix-coded layout has no `len` field; the leaves are
   prefix codes of 3 to 9 bits, forms listed in the grammars). The generator must read the grammars through `tools/encgram.py`, as `tools/mkenc.py` does.
2. **`by-opcode.md`** and the opcode tables are r20 only. The prefix-coded encodings have no opcode numbers in the r20 sense: they have leaves with a prefix and a
   sub-opcode (`sub`). A `by-encoding` page per member (leaf, prefix, length, forms) can be generated from the same dictionary as `tables.md`.
3. **New instruction entries.** The 70 words of `mn-ext` are not in `spec/pdp64-mnemonics.hbnf` and have no entries: `movcall`, `popret`, `popmret`, `mov2` (the four fused
   pairs), `maskeqz`, `masknez`, `bsel`, `movql`, `addv`, `subv`, `mulv`, `trapcc.CC` (14), the deferred/user-qualified moves `mov*.d/.u/.ud` (18), the AES and SHA
   instructions (`aeses`, `aesesm`, `aesds`, `aesdsm`, `aesks1`, `aesks2`, `aesim`, `sha256sig0/1`, `sha256sum0/1`, `sha512sig0/1`, `sha512sum0/1`, `msha256`, `msha512`, `maesctr`),
   `syspg0` .. `syspg5` (placeholders). `mkmanual.py --check` passes today because it only knows the r20 mnemonics file; the entries need an
   "availability" line (r20 / 16 / 32 / 16 and 32 only) and prose in `tools/manual/isa_part*.py`. Instructions of the original ISA that
   exist in all three (the unaligned and memory-form words `movub/uw/ul/uq`, `addm/subm/bicm/bism`, the atomics) need the same line; the atomics
   are not yet implemented by the executor (`docs/errata.md` 88).
4. **Register tables.** Entries that name `r0`-`r15` need a note for `r16`-`r31` (pdp64/32 only); `pushm`/`popm` masks are 32 bits there.
5. **Operand tables**: the 3-bit and 4-bit hot-register tables (part of the ABI) and the immediate/displacement widths per form are properties of the
   encoding; they belong in a new generated section, from the grammars.
6. **`index.md`** counts ("the specification has N mnemonic words") must count per member.

### 3.2 In the hand-written parts

| File and section | Statement that is r20-only or wrong for the family |
|---|---|
| `09-isa.md` 9.1 (opcode space) | "every instruction begins with a 16-bit parcel with four fields", the 64 opcodes of page 1, the six escape groups, the three register-field groups, "the length of an instruction is known from its first two bits": all r20. The prefix-coded encodings decide the length from a prefix code over the first parcel (`docs/encoding-proposal.md`, `spec/README.md`). New section needed: the three encodings, why two grammars, how the length is decoded. |
| `09-isa.md` 9.2 | the principles list ("two bytes cheapest, nothing longer than six") still true; add the measured sizes (this repository's integration report) |
| `09-isa.md` 9.3 | register file: r0-r15 only; r16-r31 in pdp64/32; the ABI split (r16-r23 caller-saved, r24-r31 callee-saved) |
| `09-isa.md` 9.4, 9.5 | instruction format and addressing modes: the format is r20's; per-member forms; scaled index and stride forms; PC-relative widths and the linker relaxation (4-byte `call` reaches +-1 MiB) |
| `09-isa.md` 9.10 | `cbCC` reach, `sob`, `bCC` per member; fused `movcall`, `popret`, `popmret`; far `cbCC` expanded by the assembler to `cmp` + `bCC` |
| `09-isa.md` 9.13 | atomics: unchanged semantically, but encodings per member |
| `09-isa.md` 9.18, 9.19, 9.21 | "idioms: restored, lost and replaced", side by side, open items: add the compiler's idioms (fusion, jump tables, divide by constants); remove closed items |
| `01-introduction.md` | "what it takes to find where the next instruction starts" table (line 96), the pitch of 2-to-6-byte instructions; the family; the figures of merit (static size, fetched bytes, instructions executed) |
| `appendix-c-glossary.md` | `parcel`, `len`, `page 1/page 2` entries: say they are r20 terms; add leaf, prefix, form, hot register, fused instruction, relaxation, family |
| `appendix-d-abi.md` | registers r16-r31, the callee-saved split, `pushm`/`popm` masks, the hot tables |
| `appendix-e-assembler.md` | `-m pdp64/16|32|r20`, `--no-relax`, `--stats`, `--dump-lens`, the relaxation objects, the shortest-form rule per member (line 35 speaks of page-2 forms) |
| `appendix-f-evidence.md` | the measurements: replace or add the integration table |
| `appendix-b-decisions-pending.md`, `appendix-a-improvements.md` | `STUA/CLUA` one-parcel forms (A.8.1): re-evaluate in the prefix-coded encodings; decisions pending that errata 87 to 92 closed |
| `06-kernel.md`, `07-smp.md`, `08-vectors.md` | `trapcc`, deferred/user-qualified moves, core counts (errata 92), the SMP decisions of `docs/smp-decisions.md`; the instruction-entry link tables |
| `00-index.md`, `10-conclusion.md`, `book/outline.txt`, `book/sources.txt` | a new chapter or part for the family, if added: outline numbering is literal in the text (`mkchapters.py` checks heading numbers) |

## 4. Work plan and effort

Effort is in working days of one person who knows the repository; "agent days" are the same work done by an AI agent with review, which is how the rest of
this repository was written (about a third of the calendar time, plus the author's review).

| Step | Work | Output | Effort |
|---|---|---|---|
| 1 | Decide the shape: one chapter-9 text with an availability column and per-member encoding tables (recommended), versus three parallel chapters (not recommended: 4,300 lines times three) | decision record in `docs/errata.md` | 0.5 |
| 2 | `mkmanual.py`: read the three encodings (`encgram.load`), add `mn-ext` and the new mnemonics to the entry machinery (`HOME`, availability), make `by-opcode.md` r20-only and add `by-encoding-16.md` and `-32.md`, the hot tables, the form lists | generator, dictionary pages | 3 |
| 3 | Diagrams: a prefix-coded layout figure generator (prefix, sub, operand pieces, up to three parcels) and one diagram per leaf family instead of per mnemonic (about 20 figures per member rather than 112); keep the r20 figures | `figures/*.svg` | 2 |
| 4 | Entries: availability line on all 106 entries; new entries for the 70 `mn-ext` words (about 20 entries after grouping: fused, mask/select, overflow-trapping arithmetic, `trapcc`, deferred and user moves, AES, SHA, `syspg`); update the prose in `tools/manual/isa_part*.py` and `isa_stories.py` | `tools/manual/*.py` | 4 |
| 5 | Hand-written chapter 9 sections 9.1 to 9.5, 9.10, 9.18, 9.19, 9.21: rewrite 9.1 and 9.4 for the family (the largest part), add the ABI, relaxation and fusion text | `09-isa.md` | 3 |
| 6 | Chapters 1, 6, 7, 8 and appendices A to F as listed in 3.2; the glossary and ABI appendix; the evidence appendix with the integration table | markdown | 3 |
| 7 | Book: outline and sources for any new entries; `tools/mkbook.sh` rebuild of the PDF; `tools/check-all.sh` (mkmanual, mkbook checks); publish | `book/pdp64-manual.pdf` | 1 |
| 8 | Review by the author; corrections | | 2 (the author's time, not counted below) |

Total: **16.5 working days of implementation** (about 5 to 6 days of agent time with review), plus the author's review. The risks are the figures (a new
generator, step 3) and the wording of 9.1/9.4 (a design statement the author has to agree to). Steps 2 to 4 can start now and need no decisions
beyond step 1; the numbers in them come from the grammars and cannot drift: `tools/check-all.sh` would fail if they did.

## 5. Do not forget

* The manual's count of instruction words and of implemented instructions (generated into `index.md`) changes when `mn-ext` is added; `book` checks then fail until the book is rebuilt.
* `docs/manual/dictionary/*` and `docs/manual/figures/*` are published on GitHub pages (`handoff.md` section 10): a half-updated dictionary is visible.
* The names `pdp64/16` and `pdp64/32` in the text mean the encodings; `r20` is the name of the original encoding, not of an architecture revision to retire.
