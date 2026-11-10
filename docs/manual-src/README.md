# The source of the manuals

[← pdp64 index](../../README.md)

The pdp64 is **pdp64/32**. Two earlier encodings, **pdp64/r20** and **pdp64/16**, were tested against it and are documented as the comparison; each of the three has its own complete manual (`docs/manual/pdp64-r20/`, `docs/manual/pdp64-16/`, `docs/manual/pdp64-32/`; landing page `docs/manual/00-index.md`). This directory is the one place where the hand-written text of the three is written; the manual of the pdp64 is `pdp64-32`. `tools/mkmanual.py` assembles from it the manual of each member and writes it, together with the generated parts (the instruction entries, the dictionary, the bit-layout charts), into `docs/manual/pdp64-<member>/`. The three generated manuals are committed, and `tools/check-all.sh` (through `tools/mkmanual.py --check`) fails if a committed file differs from what the generator produces. **Never edit a file under `docs/manual/pdp64-*/`: edit this directory (or the generators under `tools/manual/`) and run `tools/mkmanual.py`.**

## What is here

`00-index.md` to `10-conclusion.md` and `appendix-a-...` to `appendix-f-...`: the chapters and appendices, as they were when the manual was one. The generated regions (`<!-- entries:9.6 -->` ... `<!-- /entries:9.6 -->`, and `<!-- notation -->`) are empty here; the generator fills them. Do not put text between those markers.

## The syntax of a member block

Text outside any block is in the manual of every member.

    <!-- member: 16 32 -->
    these lines are only in the manuals of pdp64/16 and pdp64/32
    <!-- /member -->

    <!-- member: !r20 -->        the same, written as "every member but r20"
    <!-- /member -->

* The member names are `r20`, `16` and `32`. A list is either all positive (`16 32`) or all negated (`!r20`).
* Each marker is on a line of its own. Blocks do not nest. A block may enclose whole sections, headings included.
* Inline: `[[16 32: some words]]` is the words in those manuals and nothing in the others (the words end at the first `]]`, with no line break inside). Use it for a number or a name that differs: `[[r20: 16]][[16: 16]][[32: 32]]`.
* `@@MEMBER@@` is replaced by `pdp64/r20`, `pdp64/16` or `pdp64/32`; `@@ID@@` by `r20`, `16` or `32`; `@@PDF@@` by the file name of the book (`pdp64-16.pdf`).
* A file whose first line is `<!-- members: 16 32 -->` exists only in those manuals (a chapter or appendix that only the prefix-coded CPUs have). Then `book/outline.txt` needs a line `@16,32:c:idNNNNN    Title` for it, and `book/sources.txt` a line for its token.
* Links that leave the manual are written relative to the generated manual (`docs/manual/pdp64-<member>/`): `../../pdp64-isa.md` reaches `docs/pdp64-isa.md`, `../../../README.md` the root. Links inside the manual (`09-isa.md#...`, `dictionary/index.md`, `figures/...`) are as in the generated manual.

## Numbers and cross-references

The numbers of chapters, sections (`## 9.2`) and numbered statements (`**9.2.3**`) are **literal** in the text, as they always were, and the text cites them (`section 9.5`, `(6.13)`). The policy is: **the author of a member block writes the numbers that the manual of that member must have**; the generator does not renumber. Where a block adds or removes numbered sections or statements, the author gives the numbers of each member (by blocks that carry the whole alternative, or by inline `[[...]]` for a single number). `tools/mkmanual.py --check` then **verifies, for each of the three generated manuals**: the sections of each chapter are numbered 1 to n without a gap or a repeat; the statements of each section are numbered 1 to n; every relative link names an existing file (and, for a link into the manual, an existing heading); every `section N.M` or `section N.M.K` reference names a section or statement that exists in that manual. A failure names the manual and the place. (The numbers in the headings are also compared with the book's outline by `tools/mkbook.sh --check`.)

## Regenerate and check

    python3 tools/mkmanual.py            write the three manuals (or: python3 tools/mkmanual.py 16  for one)
    python3 tools/mkmanual.py --check    fail on any difference, stale file or broken number or link
    python3 tools/check-manual-src.py    the tests of the assembly mechanism itself
    tools/mkbook.sh --check              the book checks, for the three books (tools/mkbook.sh builds book/pdp64-r20.pdf, -16.pdf, -32.pdf)

## Where the manual of each member needs its own text

The text was written when there was one CPU, so it describes pdp64/r20. The places where pdp64/16 and pdp64/32 differ (the list is section 3.2 of `docs/manual-update-plan.md`): chapter 9, sections 9.1 (how the opcode space is divided; the length of an instruction), 9.2 (the principles and the measured sizes), 9.3 (registers: `r16` to `r31` in pdp64/32; the ABI split), 9.4 (the instruction format) and 9.5 (addressing modes, per-member forms, the pc-relative widths and the linker relaxation), 9.10 (`cbCC` reach, the fused `movcall`, `popret`, `popmret`), 9.13 (atomics, encodings per member), 9.18, 9.19 and 9.21 (idioms, side by side, open items); chapter 1 (the table of how to find the next instruction, the pitch of 2 to 6 bytes, the figures of merit); chapters 6, 7 and 8 (`trapcc`, the deferred and user-qualified moves, the core counts of errata 92); appendix C (the glossary: `parcel`, `len` and `page` are r20 terms; `leaf`, `prefix`, `form`, `hot register`, `fused instruction`, `relaxation`, `family`), appendix D (registers `r16` to `r31`, the callee-saved split, the `pushm` and `popm` masks, the hot tables), appendix E (`-m pdp64/16|32|r20`, `--no-relax`, `--stats`, the shortest-form rule per member), appendix F (the measurements), appendices A and B (decisions that errata 87 to 92 closed), and `00-index.md` (the manual's own introduction). The generated parts (the instruction entries of chapter 9, the dictionary, the figures) are produced per member by the generators.

Until a member block is written, the manuals of pdp64/16 and pdp64/32 carry the text of pdp64/r20 in those places.
