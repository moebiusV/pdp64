# The design notes

[← docs index](../README.md) · [manual](../manual/00-index.md)

The manual states the architecture as it is to be. The matters that are not decided, and the history, are kept here, outside the manual: they are notes of the design, not part of the specification.

| Note | What it holds | Source |
|---|---|---|
| [`open-items.md`](open-items.md) | each question the architecture must still answer, with the issue, the options and what each costs (items `J.n.k`) | `src/appendix-j-open.md` and the `NN-open.md` fragments of `src/appendix-parts/` |
| [`proposed.md`](proposed.md) | designs that nobody has decided, kept out of the chapters | `src/appendix-h-proposed.md` and the `NN-proposed.md` fragments |
| [`deferred.md`](deferred.md) | what has been decided to be put off | `src/appendix-i-deferred.md` and the `NN-deferred.md` fragments |
| [`decisions-pending.md`](decisions-pending.md) | pointers from the old list of pending decisions (items `B.n.k`) to the notes that now hold them | `src/appendix-b-decisions-pending.md` |
| [`evolution.md`](evolution.md) | how the design grew, with the dates | `src/appendix-g-evolution.md` |

The notes were appendices B, G, H, I and J of the manual. Their numbering (`J.3.1`, `B.2.11`, `P3`), the item labels and the anchors are unchanged, because other documents cite them, and the text is unchanged: where a note says "appendix J" or "the body of the manual" it speaks of the notes as they were written. A citation in a note of an appendix of the manual by letter (`D.1`, `appendix D`) uses the letters the manual had before 2026-11-25; the manual's appendices are now A (possible improvements), B (glossary), C (the ABI), D (the assembler and the object format) and E (the evidence). Citations of the chapters by number (`3.4.1`) name the statements as they were when the note was written; some of the statements that carried a pointer to an open item were deleted, and the following numbers of the section moved up.

**Generated files.** `open-items.md`, `proposed.md`, `deferred.md`, `decisions-pending.md`, `evolution.md` and `figures/` (the drawings that only a note shows, made by `tools/manual/*figs.py`) are written by `tools/mkmanual.py` from `src/`; never edit them. Edit `src/` and run `python3 tools/mkmanual.py`; `python3 tools/mkmanual.py --check` fails if a committed file differs, a section or item number is not contiguous, or a link or a reference to a number of the notes has no target (a citation of a chapter's number is not checked: the manual's numbers move without the notes). `src/appendix-g-evolution.md` was first written by `tools/declog/evolution.py` and has been edited by hand since; running that script would overwrite the edits.

## The fragment files

`docs/design/src/appendix-parts/<NN>-<kind>.md`, where `<NN>` is the chapter number with two digits (`02`, `10`) or the letter of an appendix (`d`), and `<kind>` is `proposed`, `deferred` or `open`. One file for each chapter and each kind; a file may be absent or empty. `tools/mkmanual.py` assembles them, in chapter order and then appendix order, into `src/appendix-h-proposed.md`, `src/appendix-i-deferred.md` and `src/appendix-j-open.md` (and so into `proposed.md`, `deferred.md` and `open-items.md`) (between the markers `<!-- parts:proposed -->`, `<!-- parts:deferred -->`, `<!-- parts:open -->`, which nobody edits), with a heading `## H.2 Chapter 2: The bus` (for an appendix, `## J.D Appendix D: The ABI, version 1`) before each non-empty fragment; an appendix with no fragments says "Nothing is proposed.", "Nothing is deferred." or "There are no open items." A fragment is a source like any other: it is written without its own chapter heading, and the generator picks the fragments up like any other source. Fragment names that do not fit the pattern, or that name no chapter, fail the build.

## An entry of the open items (fragment `NN-open.md`)

Each entry is an anchor line, a level-3 heading numbered `J.<chapter>.<n>` (`J.D.<n>` for the ABI, the former appendix D), and the parts below, in this order. The numbers run 1 to n in the fragment and are never reused once cited. Write the register of the manual: plain declarative prose for a first-year student and an experienced PDP-11 programmer; define a term where it first occurs; no implementation remarks ("where things stand"); no recommendation except the labelled leaning.

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

    **My referents.** The machines, systems or standards that I named when
    I spoke of it, in a short line, with my words where they are short.

    **My leaning.** (Optional.) One option and why, labelled as the assistant's, not a decision.

    **Where the body refers to it.** Section numbers (`2.4.3`) of the sentences that carried the pointer. (Since 2026-11-25 the chapters carry no pointer; the entries written before then keep the line, with the numbers as they were.)

Proposed and deferred entries have no template: they are the moved statements, with their numbers and tags, and any commentary that belonged to them.

