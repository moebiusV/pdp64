# The source of the manuals

[← pdp64 index](../../README.md)

This directory is the one place where the hand-written text of the manual of the pdp64 is written. `tools/mkmanual.py` assembles from it the manual and writes it, together with the generated parts (the instruction entries, the dictionary, the bit-layout charts, read from the grammar of the encoding), into `docs/manual/`. The generated manual is committed, and `tools/check-all.sh` (through `tools/mkmanual.py --check`) fails if a committed file differs from what the generator produces. **Never edit a file under `docs/manual/`: edit this directory (or the generators under `tools/manual/`) and run `tools/mkmanual.py`.**

(The text of earlier manuals was written here with member blocks; the git tag `pre-single-cpu` has it.)

## What is here

`00-index.md` to `10-conclusion.md` and `appendix-a-...` to `appendix-e-...`: the chapters and the five appendices (A improvements, B glossary, C the ABI, D the assembler and the object format, E the evidence). The design notes (the former appendices B, G, H, I and J) are not here: their sources are in `docs/design/src/` and `tools/mkmanual.py` writes them to `docs/design/` (see `docs/design/README.md`). The generated regions (`<!-- entries:{{r:name}} -->` ... `<!-- /entries:{{r:name}} -->` in a section, and `<!-- notation -->`) are empty here; the generator fills them. Do not put text between those markers.

## The syntax of the source

There is one manual, so the source has no conditional text: no member blocks, no inline alternatives, no placeholders for a CPU's name. Text is written once, for the pdp64. `tools/mkmanual.py` refuses the markers of the old three-manual source (`<!-- member: ... -->`, `[[16 32: ...]]`, `@@MEMBER@@`) if one comes back. (The old source, with its member blocks, is in the git tag `pre-single-cpu`.)

* Links that leave the manual are written relative to the generated manual (`docs/manual/`): `../pdp64-isa.md` reaches `docs/pdp64-isa.md`, `../../README.md` the root. Links inside the manual (`09-isa.md#...`, `dictionary/index.md`, `figures/...`) are as in the generated manual.
* The book (`book/pdp64.pdf`) is made from the generated manual; `book/outline.txt` and `book/sources.txt` need a line for each chapter or appendix.

## Numbers and cross-references: write names, never numbers

**No number is written in this directory.** The numbers of sections (`6.14`), numbered statements (`6.14.9`) and figures (`Figure 5.1`) are computed from the order of the text, and the numbers of chapters and appendices from the order of `book/outline.txt` (the same file buildabook reads). A section, a statement or a figure has a **name**, which is its identity; every citation is a token that names what it cites. `tools/mkmanual.py` replaces the tokens by the numbers while it assembles the manual, so `docs/manual/` (what GitHub shows, and what the book is made from) has real numbers and no token. Insert, delete or move a section, a statement or a whole chapter and every number and every citation follows on the next run; nothing is renumbered by hand. The code is `tools/manual/bookrefs.py`; `docs/encoding-work/numbering-migration-design.md` tells why it is built this way.

A name is `[a-z0-9][a-z0-9-]*` and unique in the book. Write it from the first words of the heading or the statement (`kernel-modes`, `psw-has-three-modes`). **Once a name is committed it is not changed** (it is cited): a better name is made with `python3 tools/manual/rename_name.py OLD NEW docs/manual-src/*.md tools/manual/*.py tools/mkmanual.py`, which renames the definition and every citation.

| what | in the source | in the manual |
|---|---|---|
| chapter heading | `# {{c:id01006\|n}}. The kernel` (the uuid of the chapter in `book/outline.txt`) | `# 6. The kernel` |
| appendix heading | `# Appendix {{c:id03004\|n}}. The ABI` | `# Appendix C. The ABI` |
| section | `## {{#kernel-modes}} Modes and the status word` | `## 6.2 Modes and the status word` |
| numbered subsection | `### {{#vm-walk}} The walk` (an item of its section, like a statement) | `### 6.7.3 The walk` |
| statement | `**{{#psw-has-three-modes}}** There are three modes...` (at the start of a line) | `**6.2.1** There are three modes...` |
| figure | `![{{#fig-psw}}The status word](figures/psw.svg)` | `![The status word](figures/psw.svg)`; its number is `5.1` for the first figure of chapter 5 |
| citation | `section {{r:kernel-modes}}`, `(see {{r:psw-has-three-modes}})`, `Figure {{r:fig-psw}}` | `section 6.2`, `(see 6.2.1)`, `Figure 5.1` |
| a chapter or an appendix in words | `chapter {{c:id01006\|n}}`, `appendix {{c:id03004\|n}}` | `chapter 6`, `appendix C` |
| a link to a section | `[{{r:kernel-modes}}]({{u:kernel-modes}})` | `[6.2](06-kernel.md#62-modes-and-the-status-word)` |
| the contents list of `00-index.md` | `{{n}}. [**Title**](file.md)` | `1. [**Title**](file.md)`, counted |
| in a Python string of the generators | `'... (section {{r:name}})'`; for a home section `R('name')` in `tools/mkmanual.py` | the same |

The word before a citation (`section`, `statement`, `Figure`) is ordinary text. Unnumbered headings (`## Contents`, `### MOV`) and a number that is not a citation (a decimal, `FreeBSD 5.3`, a section of another document such as ``docs/pdp64-isa.md` section 7.2``) stay as they are. The statements and sections are the Nth marker of their chapter in the order of the file; a statement stands before nothing but its own section's text, and a section's statements are numbered from 1 again.

The checks. `tools/mkmanual.py` stops, naming the file and the line, on a citation of a name that does not exist, a name defined twice, a `{{#name}}` where it has no number (anywhere but the start of a `##` or `###` heading, of a statement or of a figure line, or in a file that is not a chapter or an appendix of the outline) and a statement before the first section of its file. `tools/lint-literal-numbers.py` (in `tools/check-all.sh`) fails on a literal number that equals the number of an existing section, statement or figure and stands where a citation stands (after `section`, `statement`, `Figure`, `see`, `§` or an opening parenthesis): write the name. A number of another document that looks like a citation is allowed once in `tools/manual/literal-keep.txt`. `tools/mkmanual.py --check` also verifies the generated manual: the sections of each chapter are numbered 1 to n and the statements of each section 1 to n (a check of the resolver), every relative link names an existing file and, for a link into the manual, an existing heading, and every `section N.M` reference in the result names a section or statement that exists. The same check runs over the generated design notes of `docs/design/` (their own numbers `J.n.k`; the design notes still cite the manual by number, as it was when each note was written). `tools/mkbook.sh --check` compares the chapter, part and appendix numbers that the resolver computes with the numbers in buildabook's `number_map.csv`.

## The body, and what stays out of it

**The rule (mine, 2026-11-10).** "The manual is about the arch as it is to be, not as it is right now." The chapters state only what is decided, as the architecture. Matters that are undecided are kept outside the manual: they do not appear in the chapters, no chapter carries proposals, deferred matters or the discussion of open questions, and the manual cites no errata and no decision-register rows. "The main body of the manual shouldn't have a whiff of them". Since 2026-11-25 those matters live in the design notes, `docs/design/` (its README describes them and how they are written): the open items, the proposed designs, the deferred matters, the list of pending decisions and the evolution of the design. The manual has no appendix for them and no pointer to them except the one sentence of the index and of the statement `chapters-state-the-architecture` of the introduction.

* **A decision is a decision, even with its details not yet worked out** (I said on 2026-11-10: "just because we don't have the details hammered out, doesn't mean they aren't full fledged decisions"). When I have decided something (a Decided line of the ledger, or my own words such as "we will", "we recommend", "i like", "yes", "agreed") it stays in the body as a decided statement, stated as the architecture. The chapters carry no "Details pending" or "Details to be determined" note and no status mark; the part that is not yet worked out is kept in the open items of the design notes. A decision is never moved to the proposed designs or called open or proposed because its details are missing.
* **Proposed** (`docs/design/proposed.md`): an idea or design that the assistant suggested and I have not accepted, or that I have not spoken to: a sketch, a list of options for a mechanism.
* **Deferred** (`docs/design/deferred.md`): a matter that I have decided to put off, "later". It is not open (there is a decision, and it is to wait) and it is not proposed.
* **Open** (`docs/design/open-items.md`): a question that the architecture must answer and has not. An open item is not an idea to be considered; the machine cannot be built or its software finished without an answer.
* **No status marks.** The chapters carry no tag on a statement: a statement of the body describes the architecture as it is decided, and the manual does not mark a statement as decided, proposed or stub. The generators print no such marks into the chapters.
* **A feature that is neither decided nor deferred is not mentioned in the body at all**, however much it was discussed (the cases are the three native graphics and sound devices, and the bus name that would mean PCI Express plus the pdp64's own additions, which the manual does not use until such additions are decided).

### Moving material out of the body (the steps)

1. Cut the statement, section or paragraph from the chapter file. Never leave a stub, a "see appendix" sentence or a pointer to the design notes behind.
2. Paste it into the fragment of that chapter and kind, `docs/design/src/appendix-parts/<NN>-<kind>.md` (the README of `docs/design/` describes the fragments). A statement keeps the number it had, written out, and gets a label: `**2.3.3** (moved from chapter 2) text...`; a section keeps its heading: `### 2.3 Title (moved from chapter 2)`. (The fragments are not in the computed numbering: they carry the numbers the matter had when it moved, and the marker `{{#name}}` is removed with the text.)
3. Nothing is renumbered: the sections and statements that remain number themselves. A citation of the moved matter is a citation of a name that no longer exists, and `tools/mkmanual.py` stops on it, naming the file and the line: remove the sentence (step 4) or cite what remains.
4. Remove from the body every sentence that discusses the moved matter. A proposal, a deferral, an open question and an alternative leave the chapter completely.
5. Run `python3 tools/mkmanual.py`, then `python3 tools/mkmanual.py --check` and `tools/mkbook.sh --check`.

## Regenerate and check

    python3 tools/mkmanual.py            write the manual and the design notes
    python3 tools/mkmanual.py --check    fail on any difference, stale file or broken number or link
    python3 tools/check-manual-src.py    the tests of the assembly mechanism and of the computed numbers
    python3 tools/lint-literal-numbers.py   fail on a number written where a citation by name belongs
    tools/mkbook.sh --check              the book checks (tools/mkbook.sh builds book/pdp64.pdf)
