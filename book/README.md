# The book form of the manual

[← pdp64 index](../README.md)

`pdp64-r20.pdf`, `pdp64-16.pdf` and `pdp64-32.pdf` are the manuals of the three CPUs (`docs/manual/pdp64-r20/`, `pdp64-16/`, `pdp64-32/`, each generated from the hand-written text of `docs/manual-src/` and the instruction entries by `tools/mkmanual.py`) typeset by [buildabook](https://github.com/moebiusV/buildabook) and Typst. It is tracked in git. It is built and committed separately from the manual sources, so the copy in git can be older than the manual. To build it:

    python3 tools/mkmanual.py        # regenerate the three manuals: the instruction entries, the reference tables and the figures
    tools/mkbook.sh [r20|16|32 ...]  # book/build-MEMBER/ -> book/pdp64-MEMBER.pdf (all three by default)

Needs `buildabook` (on `PATH`, in `$BUILDABOOK`, or at `../buildabook/buildabook`; build it from its repository with `gprbuild -P buildabook.gpr`, no hbnf needed), `typst` 0.15 or later (it fetches the `cmarker` 0.1.8 package on first use) and the fonts EB Garamond and DejaVu Sans Mono.

| file | what |
|---|---|
| `outline.txt` | the order of the books, in buildabook's outline language (parts, chapters, divisions, appendices; the numbers are computed from the position, never written); a line that starts with `@16,32:` is only in the books of those members |
| `sources.txt` | which Markdown file of the manual makes each outline entry (`@ID@` is the member) |
| `book.conf` | buildabook's configuration: title, author, and the paths (`@MEMBER@` and `@ID@` are replaced for each book) |
| `template.typ` | the Typst template, in buildabook's template contract, forked from its default for a technical reference (letter pages, small tables, monospace code) |
| `pdp64-r20.pdf`, `pdp64-16.pdf`, `pdp64-32.pdf` | the built books |
| `build-r20/`, `build-16/`, `build-32/` | intermediate files (not tracked): the chapter files, the file map, buildabook's `rendered/book.typ` and `number_map.csv` |

`tools/mkchapters.py` prepares the chapter files, because the Markdown of the manual is written for the web: each heading becomes `{{c:id01001}} — Title` (buildabook supplies the number), links between the pages become plain text, links to other files of the repository become GitHub links, and HTML comments are removed. It also checks the number in each source heading (`# 6. The kernel`, `# Appendix B. ...`) against buildabook's own number map and fails if they disagree, because the section numbers inside the text (6.7, 7.12) are literal. `tools/mkbook.sh --check` runs only the checks and is part of `tools/check-all.sh` (it is skipped where buildabook is not installed).
