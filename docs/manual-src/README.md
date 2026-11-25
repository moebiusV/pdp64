# The source of the manuals

[← pdp64 index](../../README.md)

This directory is the one place where the hand-written text of the manual of the pdp64 is written. `tools/mkmanual.py` assembles from it the manual and writes it, together with the generated parts (the instruction entries, the dictionary, the bit-layout charts, read from the grammar of the encoding), into `docs/manual/`. The generated manual is committed, and `tools/check-all.sh` (through `tools/mkmanual.py --check`) fails if a committed file differs from what the generator produces. **Never edit a file under `docs/manual/`: edit this directory (or the generators under `tools/manual/`) and run `tools/mkmanual.py`.**

(Earlier the text of three manuals, for pdp64/r20, pdp64/16 and pdp64/32, was written here with member blocks; pdp64/r20 and pdp64/16 are previous iterations, no longer CPUs with manuals.)

## What is here

`00-index.md` to `10-conclusion.md` and `appendix-a-...` to `appendix-e-...`: the chapters and the five appendices (A improvements, B glossary, C the ABI, D the assembler and the object format, E the evidence). The design notes (the former appendices B, G, H, I and J) are not here: their sources are in `docs/design/src/` and `tools/mkmanual.py` writes them to `docs/design/` (see `docs/design/README.md`). The generated regions (`<!-- entries:9.6 -->` ... `<!-- /entries:9.6 -->`, and `<!-- notation -->`) are empty here; the generator fills them. Do not put text between those markers.

## The syntax of the source

There is one manual, so the source has no conditional text: no member blocks, no inline alternatives, no placeholders for a CPU's name. Text is written once, for the pdp64. `tools/mkmanual.py` refuses the markers of the old three-manual source (`<!-- member: ... -->`, `[[16 32: ...]]`, `@@MEMBER@@`) if one comes back. (The old source, with its member blocks, is in the git tag `pre-single-cpu`.)

* Links that leave the manual are written relative to the generated manual (`docs/manual/`): `../pdp64-isa.md` reaches `docs/pdp64-isa.md`, `../../README.md` the root. Links inside the manual (`09-isa.md#...`, `dictionary/index.md`, `figures/...`) are as in the generated manual.
* The book (`book/pdp64.pdf`) is made from the generated manual; `book/outline.txt` and `book/sources.txt` need a line for each chapter or appendix.

## Numbers and cross-references

The numbers of chapters, sections (`## 9.2`) and numbered statements (`**9.2.3**`) are **literal** in the text, and the text cites them (`section 9.5`, `(6.13)`). The generator does not renumber. `tools/mkmanual.py --check` **verifies the generated manual**: the sections of each chapter are numbered 1 to n without a gap or a repeat; the statements of each section are numbered 1 to n; every relative link names an existing file (and, for a link into the manual, an existing heading); every `section N.M` or `section N.M.K` reference names a section or statement that exists. A failure names the place. The same check runs over the generated design notes of `docs/design/` (contiguous numbers, links with targets, references to their own numbers `J.n.k`). (The numbers in the headings are also compared with the book's outline by `tools/mkbook.sh --check`.)

## The body, and what stays out of it

**The rule (mine, 2026-11-10).** "The manual is about the arch as it is to be, not as it is right now." The chapters state only what is decided, as the architecture. Matters that are undecided are kept outside the manual: they do not appear in the chapters, no chapter carries proposals, deferred matters or the discussion of open questions, and the manual cites no errata and no decision-register rows. "The main body of the manual shouldn't have a whiff of them". Since 2026-11-25 those matters live in the design notes, `docs/design/` (its README describes them and how they are written): the open items, the proposed designs, the deferred matters, the list of pending decisions and the evolution of the design. The manual has no appendix for them and no pointer to them except the one sentence of the index and of 1.2.6.

* **A decision is a decision, even with its details not yet worked out** (I said on 2026-11-10: "just because we don't have the details hammered out, doesn't mean they aren't full fledged decisions"). When I have decided something (a Decided line of the ledger, or my own words such as "we will", "we recommend", "i like", "yes", "agreed") it stays in the body as a decided statement, stated as the architecture. The chapters carry no "Details pending" or "Details to be determined" note and no status mark; the part that is not yet worked out is kept in the open items of the design notes. A decision is never moved to the proposed designs or called open or proposed because its details are missing.
* **Proposed** (`docs/design/proposed.md`): an idea or design that the assistant suggested and I have not accepted, or that I have not spoken to: a sketch, a list of options for a mechanism.
* **Deferred** (`docs/design/deferred.md`): a matter that I have decided to put off, "later". It is not open (there is a decision, and it is to wait) and it is not proposed.
* **Open** (`docs/design/open-items.md`): a question that the architecture must answer and has not. An open item is not an idea to be considered; the machine cannot be built or its software finished without an answer.
* **No status marks.** The chapters carry no tag on a statement: a statement of the body describes the architecture as it is decided, and the manual does not mark a statement as decided, proposed or stub. The generators print no such marks into the chapters.
* **A feature that is neither decided nor deferred is not mentioned in the body at all**, however much it was discussed (the cases are the three native graphics and sound devices, and the bus name that would mean PCI Express plus the pdp64's own additions, which the manual does not use until such additions are decided).

### Moving material out of the body (the steps)

1. Cut the statement, section or paragraph from the chapter file. Never leave a stub, a "see appendix" sentence or a pointer to the design notes behind.
2. Paste it into the fragment of that chapter and kind, `docs/design/src/appendix-parts/<NN>-<kind>.md` (the README of `docs/design/` describes the fragments). A statement keeps its number and gets a label: `**2.3.3** (moved from chapter 2) text...`; a section keeps its heading: `### 2.3 Title (moved from chapter 2)`.
3. Renumber the chapter: the sections and statements that remain are numbered 1 to n again (the check insists), and every citation of a number that moved or shifted, anywhere in `docs/manual-src/` and in the glossary, is corrected.
4. Remove from the body every sentence that discusses the moved matter. A proposal, a deferral, an open question and an alternative leave the chapter completely.
5. Run `python3 tools/mkmanual.py`, then `python3 tools/mkmanual.py --check` and `tools/mkbook.sh --check`.

## Regenerate and check

    python3 tools/mkmanual.py            write the manual and the design notes
    python3 tools/mkmanual.py --check    fail on any difference, stale file or broken number or link
    python3 tools/check-manual-src.py    the tests of the assembly mechanism itself
    tools/mkbook.sh --check              the book checks (tools/mkbook.sh builds book/pdp64.pdf)
