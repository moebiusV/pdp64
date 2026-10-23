# The book form of the manual

[← pdp64 index](../README.md)

`pdp64-manual.pdf` is the manual (`docs/manual/`, with the instruction entries generated into its chapters) typeset by [buildabook](https://github.com/moebiusV/buildabook) and Typst. It is tracked in git. **The author builds and commits the PDF himself, elsewhere; do not rebuild or commit it from the working sessions** (the copy in git can therefore be older than the manual). To build it:

    python3 tools/mkmanual.py        # regenerate the instruction entries, the reference tables and the figures
    tools/mkbook.sh                  # book/build/ -> book/pdp64-manual.pdf

Needs `buildabook` (on `PATH`, in `$BUILDABOOK`, or at `../buildabook/buildabook`; build it from its repository with `gprbuild -P buildabook.gpr`, no hbnf needed), `typst` 0.15 or later (it fetches the `cmarker` 0.1.8 package on first use) and the fonts EB Garamond and DejaVu Sans Mono.

| file | what |
|---|---|
| `outline.txt` | the order of the book, in buildabook's outline language (parts, chapters, divisions, appendices; the numbers are computed from the position, never written) |
| `sources.txt` | which Markdown file of the manual makes each outline entry |
| `book.conf` | buildabook's configuration: title, author, and the paths |
| `template.typ` | the Typst template, in buildabook's template contract, forked from its default for a technical reference (letter pages, small tables, monospace code) |
| `pdp64-manual.pdf` | the built book |
| `build/` | intermediate files (not tracked): the chapter files, the file map, buildabook's `rendered/book.typ` and `number_map.csv` |

`tools/mkchapters.py` prepares the chapter files, because the Markdown of the manual is written for the web: each heading becomes `{{c:id01001}} — Title` (buildabook supplies the number), links between the pages become plain text, links to other files of the repository become GitHub links, and HTML comments are removed. It also checks the number in each source heading (`# 6. The kernel`, `# Appendix B. ...`) against buildabook's own number map and fails if they disagree, because the section numbers inside the text (6.7, 7.12) are literal. `tools/mkbook.sh --check` runs only the checks and is part of `tools/check-all.sh` (it is skipped where buildabook is not installed).
