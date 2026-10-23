# The book form of the manual

[← pdp64 index](../README.md)

`pdp64-manual.pdf` is the manual (`docs/streamlined/`, including the generated instruction dictionary) typeset with Typst. It is tracked in git; **rebuild it after every change to the manual**:

    python3 tools/mkmanual.py        # regenerate the instruction dictionary
    python3 tools/mkbook.py --pdf    # book/build/rendered -> book/build/pdp64-manual.pdf -> book/pdp64-manual.pdf

Needs `typst` (0.15 or later; it fetches the `cmarker` 0.1.8 package on first use) and the fonts EB Garamond and DejaVu Sans Mono.

| file | what |
|---|---|
| `outline.txt` | the order of the book, in the outline language of [buildabook](https://github.com/moebiusV/buildabook) (parts, chapters, divisions, appendices; numbers are computed from the position, never written) |
| `filemap.txt` | which source file holds each outline entry |
| `template.typ` | the Typst template, in buildabook's template contract, forked for a technical reference (letter pages, small tables, monospace code) |
| `pdp64-manual.pdf` | the built book |
| `build/` | intermediate files (not tracked) |

`tools/mkbook.py` does the work of `buildabook typst` because buildabook needs the `HBNF_Config` Ada crate, which is not available on this machine; the inputs are in buildabook's formats, so the real tool can build the same book. The chapter and appendix numbers come from the outline, and the build fails if a source file's own number (`# 6. The kernel`) disagrees, because the section numbers inside the text (6.7, 7.12) are literal. `python3 tools/mkbook.py --check` runs that check and is part of `tools/check-all.sh`.

Links between the chapters become plain text in the PDF (the section numbers stay); links to other files of the repository become links to GitHub.
