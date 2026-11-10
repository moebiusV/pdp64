# The source of the manuals

[← pdp64 index](../../README.md)

The pdp64 is **pdp64/32**. Two earlier encodings, **pdp64/r20** and **pdp64/16**, were tested against it and are documented as the comparison; each of the three has its own complete manual (`docs/manual/pdp64-r20/`, `docs/manual/pdp64-16/`, `docs/manual/pdp64-32/`; landing page `docs/manual/00-index.md`). This directory is the one place where the hand-written text of the three is written; the manual of the pdp64 is `pdp64-32`. `tools/mkmanual.py` assembles from it the manual of each member and writes it, together with the generated parts (the instruction entries, the dictionary, the bit-layout charts), into `docs/manual/pdp64-<member>/`. The three generated manuals are committed, and `tools/check-all.sh` (through `tools/mkmanual.py --check`) fails if a committed file differs from what the generator produces. **Never edit a file under `docs/manual/pdp64-*/`: edit this directory (or the generators under `tools/manual/`) and run `tools/mkmanual.py`.**

## What is here

`00-index.md` to `10-conclusion.md` and `appendix-a-...` to `appendix-j-...`: the chapters and appendices, as they were when the manual was one. Appendices H, I and J are assembled from the fragment files of `appendix-parts/` (next section). The generated regions (`<!-- entries:9.6 -->` ... `<!-- /entries:9.6 -->`, and `<!-- notation -->`) are empty here; the generator fills them. Do not put text between those markers.

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

## The body and the three appendices: proposed, deferred, open

**The rule (the author's, 2026-11-10; errata entry 120).** "The manual is about the arch as it is to be, not as it is right now." The chapters describe the architecture as it is to be decided. They do not carry proposals, deferred matters or the discussion of open questions: "the main body of the manual shouldn't have a whiff of them". Those live in three appendices, which are written in fragments, one file for each chapter and kind, so that several people can edit them at the same time.

* **A decision is a decision, even with its details not yet worked out** (the author, 2026-11-10: "just because we don't have the details hammered out, doesn't mean they aren't full fledged decisions. just mark them with 'details tbd/pending'"). When the author has decided something (a Decided line of the ledger, an erratum headed DECISION, or his own words such as "we will", "we recommend", "i like", "yes", "agreed") it stays in the body as a decided statement, stated as the architecture. The part of it that is not yet worked out is marked in one short sentence in the body: `Details pending ([J.3.2](appendix-j-open.md#j32)).` (or `Details to be determined.` when there is nothing to discuss), and the discussion of that part goes in the open-items appendix. A decision is never moved to appendix H or called open or proposed because its details are missing.
* **Proposed** (appendix H): an idea or design that the assistant suggested and the author has not accepted, or that the author has not spoken to: a statement tagged *(P)*, a sketch, a list of options for a mechanism.
* **Deferred** (appendix I): a matter that the author has decided to put off, "later". It is not open (there is a decision, and it is to wait) and it is not proposed.
* **Open** (appendix J): a question that the architecture must answer and has not; a statement tagged *(S)* (a stub) names one. An open item is not an idea to be considered; the machine cannot be built or its software finished without an answer.
* **The tags.** *(D)* (decided by the author) stays in the body, unchanged: a decided statement keeps it, and a statement with no tag describes the architecture as it is built and tested. *(P)* and *(S)* are no longer used in the body; a statement moved to appendix H keeps *(P)* and one moved to appendix J keeps *(S)* until it is rewritten as an entry. The generators print tags from the grammar and from `tools/manual/isa_*.py` (the notes of chapter 9 carry `*(D)*`, `*(P)*`, `*(S)*`); the chapter 9 agent moves the *(P)* and *(S)* material out and the *(D)* tags stay as they are.
* **A feature that is neither decided nor deferred is not mentioned in the body at all**, however much it was discussed (errata 120 names the cases: the three native graphics and sound devices, and the bus name that would mean PCI Express plus the pdp64's own additions, which the manual does not use until such additions are decided).

### The fragment files

`docs/manual-src/appendix-parts/<NN>-<kind>.md`, where `<NN>` is the chapter number with two digits (`02`, `10`) or the letter of an appendix (`d`), and `<kind>` is `proposed`, `deferred` or `open`. One file for each chapter and each kind; a file may be absent or empty. `tools/mkmanual.py` assembles them, in chapter order and then appendix order, into `appendix-h-proposed.md`, `appendix-i-deferred.md` and `appendix-j-open.md` (between the markers `<!-- parts:proposed -->`, `<!-- parts:deferred -->`, `<!-- parts:open -->`, which nobody edits), with a heading `## H.2 Chapter 2: The bus` (for an appendix, `## J.D Appendix D: The ABI, version 1`) before each non-empty fragment; an appendix with no fragments says "Nothing is proposed.", "Nothing is deferred." or "There are no open items." A fragment is a source like any other: member blocks and `[[16 32: ...]]` work in it, a first line `<!-- members: 16 32 -->` makes it exist for those members only, and it is written without its own chapter heading. The three generated manuals pick the fragments up like any other source. Fragment names that do not fit the pattern, or that name no chapter, fail the build.

### Moving material out of the body (the steps)

1. Cut the statement, section or paragraph from the chapter file. Never leave a stub or a "see appendix" sentence behind, except for an open item (below).
2. Paste it into the fragment of that chapter and kind. A statement keeps its number and gets a label: `**2.3.3** (moved from chapter 2) text...`; a section keeps its heading: `### 2.3 Title (moved from chapter 2)`. Its tag stays. The numbers in the fragment are labels: they are not renumbered, need not be contiguous, and a number defined only in a fragment is a valid target for a citation (`tools/mkmanual.py --check` knows them).
3. Renumber the chapter: the sections and statements that remain are numbered 1 to n again (the check insists), and every citation of a number that moved or shifted, anywhere in `docs/manual-src/` and in the glossary, is corrected: a citation of a statement that moved reads `H.2` or `appendix H, 2.3.3`, and the plain old number now means the new statement of the body.
4. Remove from the body every sentence that discusses the moved matter. A proposal, a deferral and an alternative leave the chapter completely.
5. For an open item, leave one sentence (below).
6. Run `python3 tools/mkmanual.py`, then `python3 tools/mkmanual.py --check` and `tools/mkbook.sh --check`.

### An open item in the body

One short sentence with a pointer, and nothing more:

    Open: how many pages the first few are ([J.3.2](appendix-j-open.md#j32)).

The pointer is an ordinary link to the anchor of the entry, rendered by the book as plain text (`J.3.2`); the check fails if the anchor does not exist. The sentence says what is open in a few words and not what the options are. It is written as a statement of its own, not hidden in a commentary paragraph.

### An entry of the open-items appendix (fragment `NN-open.md`)

Each entry is an anchor line, a level-3 heading numbered `J.<chapter>.<n>` (`J.D.<n>` for appendix D), and the parts below, in this order. The numbers run 1 to n in the fragment and are never reused once cited. Write the register of the manual: plain declarative prose for a first-year student and an experienced PDP-11 programmer (errata 103); define a term where it first occurs; no implementation remarks ("where things stand"); no recommendation except the labelled leaning.

    <a id="j32"></a>
    ### J.3.2 The first few pages

    **Issue.** What the question is, in two to five sentences, with the numbers or the facts that
    give it its edges.

    **Why it matters.** What cannot be decided, built or ported until it is answered.

    **Options.**

    1. *Name of the option.* What it is, in a sentence or two. For: ... Against: ...
    2. *Name of the option.* ... For: ... Against: ...
    (five or six, each with its own pros and cons)

    **Precedents.** What other machines or systems did, one line each, marked *(verified)* or
    *(unverified)* as the source says.

    **The author's referents.** The machines, systems or standards that the author named when
    he spoke of it, in a short line, with his words where they are short.

    **The assistant's leaning.** (Optional.) One option and why, labelled as the assistant's, not a decision.

    **Where the body refers to it.** Section numbers (`2.4.3`) of the sentences that carry the pointer.

Proposed and deferred entries (appendices H and I) have no template: they are the moved statements, with their numbers and tags, and any commentary that belonged to them.

## Regenerate and check

    python3 tools/mkmanual.py            write the three manuals (or: python3 tools/mkmanual.py 16  for one)
    python3 tools/mkmanual.py --check    fail on any difference, stale file or broken number or link
    python3 tools/check-manual-src.py    the tests of the assembly mechanism itself
    tools/mkbook.sh --check              the book checks, for the three books (tools/mkbook.sh builds book/pdp64-r20.pdf, -16.pdf, -32.pdf)

## Where the manual of each member needs its own text

The text was written when there was one CPU, so it describes pdp64/r20. The places where pdp64/16 and pdp64/32 differ (the list is section 3.2 of `docs/manual-update-plan.md`): chapter 9, sections 9.1 (how the opcode space is divided; the length of an instruction), 9.2 (the principles and the measured sizes), 9.3 (registers: `r16` to `r31` in pdp64/32; the ABI split), 9.4 (the instruction format) and 9.5 (addressing modes, per-member forms, the pc-relative widths and the linker relaxation), 9.10 (`cbCC` reach, the fused `movcall`, `popret`, `popmret`), 9.13 (atomics, encodings per member), 9.18, 9.19 and 9.21 (idioms, side by side, open items); chapter 1 (the table of how to find the next instruction, the pitch of 2 to 6 bytes, the figures of merit); chapters 6, 7 and 8 (`trapcc`, the deferred and user-qualified moves, the core counts of errata 92); appendix C (the glossary: `parcel`, `len` and `page` are r20 terms; `leaf`, `prefix`, `form`, `hot register`, `fused instruction`, `relaxation`, `family`), appendix D (registers `r16` to `r31`, the callee-saved split, the `pushm` and `popm` masks, the hot tables), appendix E (`-m pdp64/16|32|r20`, `--no-relax`, `--stats`, the shortest-form rule per member), appendix F (the measurements), appendices A and B (decisions that errata 87 to 92 closed), and `00-index.md` (the manual's own introduction). The generated parts (the instruction entries of chapter 9, the dictionary, the figures) are produced per member by the generators.

Until a member block is written, the manuals of pdp64/16 and pdp64/32 carry the text of pdp64/r20 in those places.
