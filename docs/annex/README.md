# The annex: the patterns each decision enables and the failures it avoids

[← pdp64 index](../../README.md)

This directory is the source of a second volume, the **annex** to the manual of the pdp64. It is not part of the manual. It will be built as a volume of its own, with buildabook's Volume feature, and its numbers will be computed in the same way as the manual's.

## What the annex is, and how it differs from the manual

The manual says **what is**: the pdp64 as it is decided, one statement at a time, with the commentary a reader needs to follow it. It does not argue, and it does not tell the story of what went wrong on other machines.

The annex says **why, and what it buys**. For one design decision at a time I tell:

* the problem as other machines met it, with the code a programmer or a kernel had to write because of it;
* the decision, in one sentence;
* the **patterns it enables**: things a programmer can now write, shorter or safer or for the first time;
* the **patterns it saves us from**: the real flaws, errata, exploits and workarounds of other processors and systems, each one taken from a source the repository holds or from a primary source I fetched and read;
* what it costs, honestly, and what it puts out of reach;
* where the manual states it.

I like to have the patterns that each decision enables or saves us from written down, because a decision that is only stated can be undone by someone who does not remember why it was made. A decision with its story is harder to lose.

Every entry shows its code twice where the decision changes the code: the **before** (what a program had to say without the decision, usually on another machine, sometimes as far back as the 1970s) and the **after** (what it says on the pdp64). When the decision removes the thing altogether, I show only the before and say plainly that it is no longer needed.

## The reader, and the rules of writing

The reader is a first-year computer science student of the 1970s who knows a little PDP-11 assembly. Each simple term is defined in a sentence or two where it first appears in an entry; the more recent the topic, the fuller the explanation. I write in the first person, in plain words, with the story first (the problem, then the decision, then what it buys). An entry says nothing is undecided and carries no status mark. It cites no errata and no decision-register row. A past flaw is stated only if I could verify it in a source I name; a foreign snippet is stated only if it is a real one, quoted from a source or assembled here with a toolchain.

## The template of an entry

`00-template.md` is the template. In short, an entry has these parts, in this order:

1. the title, a short name of the pattern or the decision;
2. **The decision**, one sentence;
3. **The problem**, as a story (the PDP-11 or another machine, what went wrong);
4. **Before** and **after**: code, with the instruction and byte counts under it;
5. **What it enables**: the patterns, each with a short snippet where one makes the point;
6. **What it saves us from**: the real past flaws, each with its source;
7. **What it costs**;
8. **What it puts off limits**;
9. **Where the manual states it**: a citation token.

## The planned parts

1. Memory model and atomics
2. Translation and the TLB
3. Interrupts and the timer
4. Privilege, returns and registers
5. Virtualization and the IOMMU
6. Vector blocks and resume
7. Encoding and the instruction set
8. The security corpus
9. The toolchain and the ports

Old code may also come from the TOPS-10 and TOPS-20 sources, the ITS sources and the ancient Unix archive (fetched, with the file, edition, address and date named).

The pilot (`01-` to `14-`) takes entries from all of these. `PILOT-NOTES.md` says which sources each used and what could not be verified.

## Numbering, and the tokens for now

Sections and entries are numbered by buildabook, never by hand: **write names, never numbers**, as `docs/manual-src/README.md` describes. For now I use the syntax of the manual's source:

| what | in the source |
|---|---|
| an entry or a section (its identity) | `## {{#annex-sequential-consistency}} Title` |
| a citation of an entry of the annex | `{{r:annex-sequential-consistency}}` |
| a citation of a statement of the manual | `{{r:memory-is-sequentially-consistent}}` (the name of the statement in `docs/manual-src`) |

A name is `[a-z0-9][a-z0-9-]*` and unique. An entry's name starts with `annex-` so that it cannot collide with a name of the manual. **The token syntax will be updated when the new version of buildabook lands** (with the Volume feature, a citation that crosses from one volume to the other will need its own form; the owner's request named the tokens `{{st:name}}` for a statement and `{{h:name}}` for a heading, which `docs/manual-src/README.md` does not define yet, so for now every citation is `{{r:name}}`). Until then these files are not read by any generator: `tools/mkmanual.py` does not look in this directory.

## What is in this directory

* `00-template.md`: the template.
* `01-...md` to `14-...md`: the pilot entries.
* `snippets/`: the assembler of the entries (`*.S`, assembled with `build/as64`; `foreign/` holds the code of other machines, with the toolchain and the source of each in `PILOT-NOTES.md`).
* `PILOT-NOTES.md`: sources, what could not be verified, the estimate for the whole annex.

To assemble a pdp64 snippet from the top of the repository:

    gcc -E -P -x assembler-with-cpp -Ibuild docs/annex/snippets/NAME.S -o /tmp/NAME.s
    build/as64 -o /tmp/NAME.o /tmp/NAME.s
    build/ld64 -o /tmp/NAME.x /tmp/NAME.o
    build/sim64 [-K] /tmp/NAME.x ; echo $?        (0 is success, for the snippets that run)
