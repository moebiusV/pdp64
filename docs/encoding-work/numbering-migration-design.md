# Computed numbers for the pdp64 manual: investigation and design

(Carried out. In the repository the resolver is `tools/manual/bookrefs.py`, the one-time converter `tools/manual/tokenize_numbers.py` (with the confirmed lists `tokenize_numbers.force.txt` and `.keep.txt`), the rename tool `tools/manual/rename_name.py`, the lint `tools/lint-literal-numbers.py` (allow list `tools/manual/literal-keep.txt`); the old number of every name is in `numbering-migration-names.tsv` (old number, name, kind, file, line of the pre-migration source). The scratch paths below, `/tmp/mig-design/...`, are those of the investigation.)

Scratch directory: `/tmp/mig-design/` (nothing in the pdp64 or buildabook repositories was touched; every experiment ran on copies; no git command was run).
Prototype and scripts: `/tmp/mig-design/proto/` (see its `README.md`; `run-all.sh` reproduces every proof below).

## 0. The answer in six lines

* buildabook (unchanged) cannot number statements, and cannot number sections as `6.14` or accept readable names (an id is `id` plus digits; a sub-entry's minor is typed by hand). It is fast and is right for chapters, parts and appendices.
* **Recommendation: a small Python resolver in pdp64 (`tools/manual/bookrefs.py`, 170 lines, written and tested here) that numbers sections (`6.14`), numbered statements (`6.14.9`) and figures (`Figure 5.1`) from the ORDER OF THE TEXT, takes chapter and appendix numbers from `book/outline.txt` (the same file buildabook reads), and resolves every citation, which is a token with a stable name.** `tools/mkmanual.py` resolves while it assembles, so `docs/manual/*.md` (what GitHub shows) has real numbers, and the PDF is made from it as today, so book and GitHub cannot disagree. `tools/mkbook.sh --check` compares the resolver's chapter, part and appendix numbers with buildabook's `number_map.csv`.
* Nothing in buildabook has to change. (Optional later: give buildabook the same `{{#name}}` / `{{r:name}}` feature so other books can use it; section 3.4.)
* Syntax: `## {{#kernel-modes}} Modes and the status word`, `**{{#psw-has-three-modes}}** Text...`, `section {{r:kernel-modes}}`, `chapter {{c:id01006|n}}`, `![{{#fig-psw}}alt](figures/psw.svg)`, `Figure {{r:fig-psw}}`.
* **Round-trip proof (all 16 files of `docs/manual-src/`, not only chapter 6):** the conversion script turns 666 literal numbers into names (150 sections, 462 statements, 9 numbered subsections, 45 figures) 953 citations (and 1 link) in the Markdown, 120 chapter/appendix words in the Markdown, and in the Python generators' strings 184 citations and 27 chapter/appendix words into tokens; resolving gives back every file **byte for byte**; the generated `docs/manual/` (16 chapters, dictionary, 2,111 figures) and `docs/design/` from the converted tree are **byte-identical** to the committed ones; `mkmanual.py --check` passes; the PDF built from them has identical text (`pdftotext`), 597 pages. Chapter 6 alone: 17 sections, 87 statements and subsections, 8 figures, 200 citation tokens; every one resolves to its old number (`proto/chapter6/proof.tsv`).
* The conversion cannot judge by itself whether a number is a citation. It converts only a number that names an existing section, statement or figure AND stands where a citation stands; 225 conversions rest on a "weak" cue and 201 numbers were left literal (decimals, versions such as `FreeBSD 5.3`, `11/70 handbook 1.4`, citations of other documents such as `ISA 7.4`); a person must read those two lists once (they are in `proto/out/report.txt`; I read chapter 6's whole list and about half of the others' weak list, and corrected the rules until no wrong conversion was left that I could find, but the migration agent must read all of them).

## 1. What buildabook supports (read from LANGUAGE.md, README.md, grammars/outline.hbnf, src/outline.adb, src/tokens.adb, src/emit.adb; each point tested with the binary)

**Outline grammar** (`grammars/outline.hbnf`): a line is `[entry] eol`; `entry = content | directive`; `content = prefix ":" uuid [title]` (title is free text to the end of the line); `directive = prefix ":" name ":" value`, `name` one of `label number count default none`; `prefix` one of `c p a d n u s k`; `uuid = "id" 1*DIGIT ["." 1*DIGIT]`. Comment lines start with `#`. **A uuid is `id` plus digits only: it cannot be a readable name.**

**Kinds and numbers.** `c` chapter (arabic), `p` part (roman), `a` appendix (letter), `d`/`n`/`u` unnumbered, `s` section, `k` sub-entry. `count`, `label`, `number` directives are positional. A chapter, part and appendix number is a counter of position in the file.
* `s:idNNNNN Title` is a child of the nearest chapter/division; **its counter is computed and resets at each chapter, but it renders only `§N` (or `N` with `|n`)**, never `6.14`. It is one level; there is no level below it. (Tested: `{{s:id00006}}` gives `§2`; `{{s:id00007|n}}` gives `1`; `{{c:id01001|n}}.{{s:id..|n}}` could be composed to `6.14`, verbose.)
* `k:idNNNNN.MINOR` renders `§N.M` where N is the parent chapter's number and **M is the MINOR typed in the uuid: not computed** (tested: `k:id01001.7` then `k:id01001.2` render `§1.7` and `§1.2`). So sub-entries give nothing that is not already literal.
* No statement-level kind exists.

**Tokens** (`src/tokens.adb`): `{{c:..}} {{p:..}} {{a:..}} {{s:..}} {{d:..}} {{k:id.minor}} {{cc:ids}}` (the prefix is a checksum against the kind of the uuid), flags `|n` (number only), `|s` (short label), `|page`, `|sort`; `{{toc}}`, `{{anchor:id}}`, `{{page:id}}`. Any unresolved token is reported with file and line and fails the build. Sections and sub-entries produce no file and no page. A source file is attached to an entry by `filemap.txt` (pdp64's `mkchapters.py` writes it).

**How numbers get into Typst.** They do not: the Ada program resolves every token to plain text while it writes `rendered/*.md`, then emits `rendered/book.typ` with one `#chapter(...)` per entry; cmarker renders the Markdown. Only page references are Typst lookups (`pageof`, `pgan`). So the number engine is the Ada code in `outline.adb` and `tokens.adb`; the template cannot be involved.

**`number_map.csv`** (`buildabook number-map`, also written by every `typst` run): header `uuid,kind,title,label,short,style,n,rendered,parent`, CRLF line ends, Excel quoting. One row per outline row in file order; for chapters `n` is the number and `rendered` is `Chapter 6`; for sections `n` is the counter and `parent` the chapter's uuid; sub-entries have empty `n`. pdp64's `mkchapters.py` already reads it for the heading check.

**Performance** (measured). Synthetic outline with 4,000 `s:` rows and 12,000 tokens in 10 chapters: `buildabook typst` 0.054 s; 40,000 rows and 120,000 tokens: 0.53 s (linear). The real manual: `tools/mkbook.sh` 5.4 s in all, almost all of it Typst. The prototype's Python resolver numbers and resolves the whole manual (666 names, 953 citations) in 0.008 s and a synthetic 4,000 statements with 8,000 citations in 0.029 s. `mkmanual.py --check` takes 0.30 s before and 0.33 s after. Speed is not a criterion.

**One more fact that matters.** `docs/manual/` is not made by buildabook: it is made by `tools/mkmanual.py` from `docs/manual-src/` plus the generated parts, and it is committed; the book is made from it. Whatever computes the numbers must therefore run inside `mkmanual.py` (so the committed Markdown has real numbers), and `mkmanual.py --check` must not need buildabook (it must work where the Ada tool is not installed, as `tools/check-all.sh` assumes).

## 2. The structure of the manual, as measured (the literal numbers to be replaced)

In `docs/manual-src/` (16 files): 12 chapter headings `# 6. Title` and 5 appendix headings `# Appendix B. Title`; 150 section headings `## 6.14 Title` (chapters) and `## A.1 Title`/`## C.1` (appendices); 462 statements `**6.14.9** text` at the start of a line; 9 numbered subsections `### 2.7.1 Title` (in sections that have no statements, so the item counter is shared); 45 figures cited by position (`Figure 5.1` is the first image of chapter 5; four such citations); 953 citations `section 6.14`, `(6.16.4)`, `statements 6.6.1, 6.7.1`, table cells `| 9.4 |`, `Commentary on 2.3.5`; 120 `chapter N` / `appendix X`; 1 link `[5.10](05-drivers.md#510-dma-...)` whose label and anchor carry the number; 3 markers `<!-- entries:9.6 -->` (keys of the generated instruction entries). Plus: 184 citations and 27 chapter/appendix words in Python strings (`tools/mkmanual.py`, `tools/manual/*.py`, incl. the generated instruction entries and the SVG figures), 123 uses of an unused `sect` argument of `E()` (dead data: nothing reads `e['sect']`; 90 of them are `'9.6'`-like strings), and the structural uses of numbers in `mkmanual.py` (`HOME` maps 100+ instruction ids to `'9.6'`...`'9.14'`, `('06-kernel.md','6.13','9.14')`, a sort by `[int(x)...]`, `section_bounds(text, '9.6')`).
The numbers verified today (`assemble.outline()`) are contiguity of sections 1..n and statements 1..n per section; mixed `###` and `**` items in one section never occur; items are contiguous everywhere.
Other literal numbers outside the manual: the design notes (`docs/design/src/**`: `J.3.2`, `**2.3.3** (moved from chapter 2)`, `NN-open.md` fragments keyed by chapter number) and about 40 other documents, C comments and grammar files that cite `section N.M` (243 warnings in `check-refs.py` today).

## 3. The options

### 3.1 The options

* **A. Outline rows.** Sections as `s:` rows (and, where possible, `k:` rows) in `book/outline.txt`; citations `{{c:..|n}}.{{s:..|n}}`; statements impossible.
* **B. Statement kind in buildabook.** Add to buildabook (Ada) a scan of the chapter sources for statement/section markers and a token `{{r:name}}`, plus names in the uuid grammar (hbnf regeneration). Numbers computed in the Ada build.
* **C. Resolver in pdp64 (recommended).** Python module run by `tools/mkmanual.py`; names are slugs; chapter/appendix numbers from `outline.txt` and cross-checked against `number_map.csv`; resolved text goes into `docs/manual/`; the book is built from it as today.
* **D. Resolver in mkchapters.py only (book path only).** Names resolved when the book's chapter files are made, from buildabook's `number_map.csv`; `docs/manual/` keeps literal numbers.

### 3.2 Comparison

| | A. outline rows | B. buildabook statement kind | **C. pdp64 resolver** | D. mkchapters only |
|---|---|---|---|---|
| Statements `6.14.9` computed | **No** (no kind; 462 rows would still give per-chapter counters) | Yes | **Yes** | Yes (in the book only) |
| Sections `6.14` computed | Only as `§N` plus a composed token; 150 extra rows in `outline.txt` | Yes | **Yes** | Yes (book only) |
| Readable stable names | No: `id` + digits (`{{s:id05014}}`) | Only after changing the grammar (hbnf regenerate) | **Yes** (`{{r:kernel-modes}}`) | Yes |
| What the GitHub reader sees (`docs/manual/*.md`) | Numbers would need a second engine anyway (mkmanual must read `number_map.csv`, so buildabook becomes a hard dependency of `--check`) | Same problem: mkmanual would need a second engine or buildabook | **Real numbers, identical to today's files (proved byte for byte)** | **Literal numbers: the check "numbers agree with the text" stays hand work for the GitHub copy; the problem remains** |
| One engine for book and GitHub | No | No (two) | **Yes** | No |
| Insert a section/statement | Edit text AND outline (two files, a fresh digits id) | One edit | **One edit (text only)** | One edit, but GitHub copy stale |
| Check "numbers agree with the text" | becomes trivially true for the book only | trivially true for the book only | **Trivially true everywhere** (the numbers are computed once, then printed) | not trivial |
| Build time | fine | fine | **fine** (0.03 s) | fine |
| Share of the 666 numbers / 1,137 citations convertible by script (953 + 1 in the Markdown, 184 in strings) | statements: 0 | all, names must be digits | **all names, 100%; 953/953 + 184 citations tokenised, 15 forced after a human reading, 201 left literal on purpose** | same as C |
| Risk | high: outline becomes the manual's index (700 rows), not a real answer | medium: new Ada code in the owner's tool, hbnf grammar change, two engines to keep equal | **low: Python only, everything proved on the whole manual, all current checks keep working on the resolved text** | low but does not solve the stated goal |
| Change in buildabook | none, but unsuitable | **yes**: grammar (uuid), new scan (about 150 lines of Ada), new tests, docs | **none** | none |

**Why not B.** It is the most elegant for the book alone, but `docs/manual/` is generated outside buildabook and committed, so a Python implementation would still be needed (two engines that must be kept equal, plus a check between them, which is the very thing the owner wants to stop doing); or `mkmanual.py --check` would need the Ada binary, which `check-all.sh` deliberately does not require. B can still follow later as a courtesy to buildabook's other books (3.4).

### 3.3 Recommendation

**C.** Chapters, parts and appendices: computed by the outline, as now; the resolver reads `book/outline.txt` with a 25-line reader of buildabook's own rules (kinds `c p a`, directives `label number count default none`), and `tools/mkbook.sh --check` fails if its answer differs from buildabook's `number_map.csv` for any chapter, part or appendix (tested: they agree on all 3 parts, 10 chapters, 5 appendices). Sections, statements, figures: computed from the order of the text, per file. Citations: tokens. Nothing is renumbered by hand again; deleting, inserting or moving a statement, a section or a whole chapter changes every number and every citation on the next `mkmanual.py` run.

### 3.4 What would change in buildabook (nothing now; optional later)
If the owner wants the feature in the tool: (1) accept `[a-z0-9-]` names after `id`-less uuid in `grammars/outline.hbnf` (or keep outline untouched and let the new feature live only in the Markdown, as in the prototype, which needs no grammar change at all); (2) a pre-pass beside `Register_Anchors` in `src/build.adb` that numbers `{{#name}}` markers per chapter file and a new token `{{r:name}}` in `src/tokens.adb`; (3) tests and LANGUAGE.md. The pdp64 prototype is its specification (`bookrefs.py` and `tests.py`). Not needed for the migration.

## 4. The exact syntax

Source files: `docs/manual-src/*.md` and the strings of `tools/mkmanual.py`, `tools/manual/*.py`. A name is `[a-z0-9][a-z0-9-]*`, unique in the book, and is identity: it is never a number. After the resolver has run nothing of this syntax is left (the generated manual has no `{{`).

| what | source | resolves to |
|---|---|---|
| chapter heading | `# {{c:id01006|n}}. The kernel: modes...` | `# 6. The kernel: modes...` (buildabook's own token, `|n`: the number only) |
| appendix heading | `# Appendix {{a:id03004|n}}. The ABI, version 1` | `# Appendix C. The ABI, version 1` |
| section | `## {{#kernel-modes}} Modes and the status word` | `## 6.2 Modes and the status word` |
| numbered subsection | `### {{#vm-walk}} The walk` | `### 6.7.3 The walk` (an item of its section, like a statement) |
| statement | `**{{#psw-has-three-modes}}** There are three modes...` | `**6.2.1** There are three modes...` (the Nth marker of the section; must stand at the start of a line) |
| figure | `![{{#fig-drv-structures}}The structure of a driver](figures/drv-structures.svg)` | `![The structure of a driver](figures/...)`; the figure's number is `5.1` (Nth image marker of the chapter) |
| citation | `section {{r:kernel-modes}}`, `(see {{r:psw-has-three-modes}})`, `Figure {{r:fig-drv-structures}}` | `section 6.2`, `(see 6.2.1)`, `Figure 5.1` |
| chapter / appendix word | `chapter {{c:id01006|n}}`, `appendix {{a:id03004|n}}` | `chapter 6`, `appendix C` |
| link into the manual | `[{{r:dma-and-the-buffers-memory}}]({{u:dma-and-the-buffers-memory}})` | `[5.10](05-drivers.md#510-dma-and-the-buffers-memory)` (the slug is rebuilt from the resolved heading) |
| key of generated entries | `<!-- entries:{{r:moves-conversions-and-address-formation}} -->` | `<!-- entries:9.6 -->` |
| in Python | `'... (section {{r:name}})'`; for a home section `R('name')` (the number as a string) | the same |

Rules enforced by the resolver (`bookrefs.py`): a name defined twice is an error; an unknown name or uuid is an error; a `{{#..}}` that is not at the start of a `##`/`###` heading, of a statement or of an image line is an error (so is one in a file that is not a numbered chapter or appendix, e.g. `00-index.md`); a statement before the first numbered section of its file is an error; code fences are skipped when numbering. Unnumbered headings (`## Contents`, `### MOV`) are not touched. Why this syntax: the marker stands exactly where the number stood, so the source diff of the migration is small and the text still reads in the order of the old text (`**{{#there-are-three-modes}}** There are three modes` names itself from its first words); the citation word before it (`section`, `statements`) stays typed text.

Names. Generated from the current numbering: a section from its title (first 6 words, at most 44 characters), a statement from its first words (5 words, at most 40), a figure from its alt text (`fig-` and 5 words); leading and trailing stop words dropped; a collision is resolved by prefixing the chapter key (`isa-system-instructions-exceptions`), then a counter. A few are awkward (`trapcc-cc-fourteen-words-one`, `while-h-1-the-hypervisor`): polish them by hand once after conversion with `proto/rename_name.py OLD NEW FILES...` (renaming changes the name everywhere; after that names are frozen).

## 5. The conversion algorithm (`proto/convert_to_names.py`, rerunnable on any pre-migration commit)

1. Read all `docs/manual-src/*.md` (not README.md). Outside code fences, scan the CURRENT numbering: `## N.M Title` and `### N.M.K Title` (a `##`/`###` whose number has 1/2 dots), `**N.M.K** text` at line start, and standalone image lines `![alt](figures/...)` numbered per chapter. Give each a name; refuse a number defined twice.
2. Rewrite headings and statements in place; `# N. Title` and `# Appendix X. Title` become chapter/appendix tokens by the outline (`c:`/`a:` rows of `book/outline.txt`); `<!-- entries:N.M -->` becomes `entries:{{r:name}}`; an image line gets `{{#name}}` at the start of its alt text.
3. In every other line, protect inline code, link targets, `<a id>` and existing tokens; then for each number `N.M[.K]` or `A.M[.K]` (not preceded by a digit, `.`, `$`, `~`, `x`, not followed by a letter or `%`) that **names an existing section, statement or figure**:
   * after `Figure`: a figure token; `[N.M](file#slug)` with a number as its label: `[{{r:}}]({{u:}})`;
   * reject (leave literal, write to the report): a following unit (`KB`, `MB`, `bytes`, `megabits`, `x`, `%`, also `2.7 to 3.3 bytes`), a preceding `$ ~ x digit .`, a preceding version word (`FreeBSD OpenBSD Linux handbook revision version ISA spec kernel ...`), a number that follows a rejected number in a list (`handbook 3.2, 3.5`);
   * strong cue (convert): `section(s)`, `statement(s)`, `see`, `cf.`, `§`, an opening parenthesis, a list that continues a converted citation (`6.6.1, 6.7.1`, `to`, `and`, `;`), a table cell that holds only the number;
   * weak cue (convert and report): `of`, `in`, `from`, `on`, `by`, `that`, `what`, `which`, `is`..., a sentence start, `, ` or `; ` before `)`;
   * no cue: leave and report (`proto/force.txt` lists the 15 that I read and confirmed as citations: `file:line:num`);
   * a number after `section`/`statement` that names nothing is reported (`ISA section 17.3` is another document).
4. `chapter N` and `appendix X` become `chapter {{c:id..|n}}` / `appendix {{a:id..|n}}` by the outline.
5. Python files: with `tokenize`, only inside string literals that are not docstrings or lone strings (a float or an index is never touched); `cf='6.7 for the memory type...'` strings start with a citation (the argument name `cf=` is the cue); a converted string followed by `.format(` is reported (none was). The `sect` argument of `E()` is dead data and not converted (delete it: 123 call-site arguments and one parameter).
6. Write `names.tsv` (old number, name, kind, file, line) and `report.txt`.

Proof tools: `roundtrip.py` (resolve the converted tree, compare with the original byte for byte; list any name whose computed number differs from its old literal one), `chapter6_proof.py`, `apply_prototype.py` (applies the whole thing to a copy of the tree, runs the real `mkmanual.py` and `mkbook.sh`).

## 6. The proof (all reproduced by `proto/run-all.sh`)

| check | result |
|---|---|
| `resolve(convert(manual-src))` equals `manual-src`, 16 files | 0 files differ |
| computed number of each of the 666 names equals its old literal number | 0 differ |
| leftover tokens after resolving | 0 |
| chapter 6: 17 sections, 87 statements/subsections, 8 figures, 200 citations | every definition and citation resolves to the old number (`chapter6/proof.tsv`, 313 rows); resolved file equals the old file |
| real `tools/mkmanual.py` run on the converted tree (converted `tools/manual/*.py` strings, patched `mkmanual.py`) | `docs/manual/` (16 chapters, 5 dictionary pages, 2,111 figures) and `docs/design/` byte-identical to the originals; `mkmanual.py --check` passes |
| book built by `tools/mkbook.sh` from it | 597 pages; `pdftotext` identical to the book built from the original tree; `buildabook check`: all tokens resolved |
| outline reader vs buildabook `number_map.csv` (3 parts, 10 chapters, 5 appendices) | agree |
| lint: literal citation of an existing number in the token source and the generator strings | 0 |
| renumbering: one section and one statement inserted before 6.2 | 103 chapter-6 names move; `section 6.10`, cited 8 times, reads 6.11 in all 8 places, in other chapters as well; errors tested: unknown name, duplicate name, unnumbered file, bad uuid |
| GitHub-readable Markdown | `proto/chapter6/06-kernel.resolved.md` (equal to the committed text) vs `proto/chapter6/06-kernel.src.md` (what the author edits) |

Excerpt (chapter 6, token source then what the reader sees):

    ## {{#running-a-kernel-under-a-kernel}} Running a kernel under a kernel: virtualization
    **{{#exit-enters-the-hypervisor-through}}** An exit enters the hypervisor through a **vector table** ... `VBR` is the hypervisor level's own ({{r:while-h-1-the-hypervisor}}) ...
    | 17 to 20 | exits to the hypervisor ({{r:exit-enters-the-hypervisor-through}}) |

    ## 6.16 Running a kernel under a kernel: virtualization
    **6.16.16** An exit enters the hypervisor through a **vector table** ... `VBR` is the hypervisor level's own (6.16.4) ...
    | 17 to 20 | exits to the hypervisor (6.16.16) |

## 7. Every file kind that must change

| file kind | what changes | how |
|---|---|---|
| `docs/manual-src/00..10-*.md`, `appendix-*.md` (16) | headings, statements, citations, entries markers, figure alt text, the one numbered link | `convert_to_names.py` (666 names, 953 + 1 citations, 120 chapter/appendix words); then review the report; polish names |
| `docs/manual-src/00-index.md` Contents list | typed `1. ... 16.` list: write `1.` on every item (Markdown numbers it; GitHub shows 1..16); chapter words become tokens | by hand (3 lines of the script already handle the words) |
| `docs/manual-src/README.md` | the section "Numbers and cross-references" and step 3 of "Moving material out of the body" (the renumber-and-correct step disappears: move the text with its `{{#name}}`) | by hand, from section 4 and 8 of this document |
| `tools/manual/bookrefs.py` (new) | the resolver (copy `proto/bookrefs.py`) | add |
| `tools/mkmanual.py` | import; `BOOK`, `raw_sources()` (numbers `docs/manual-src` in outline order), `R(name)`; `sources()` returns resolved text; `build()` resolves tokens of generated text, `FIGS` and `DFIGS`; `HOME`, `embed` keys, `sec_link`, the `where` sort, `('06-kernel.md','6.13','9.14')` use names via `R()`; its 11 strings become tokens | the prototype's `apply_prototype.py` shows every edit (about 40 changed lines) |
| `tools/manual/*.py` strings (isa_part1..4, isa_stories*, isa_enc, isa_entries, isa_vec, bootfigs, busfigs, drvfigs, gfxfigs, introfigs, kernfigs, smpfigs, vecfigs) and the generated instruction entries (the `cf=` and `notes=` strings) | 184 citations and 27 chapter/appendix words become tokens; resolved at the end of `build()`, so the entries, the dictionary and the SVG figures (2,111) resolve too | script; delete the dead `sect` argument of `E()` and its 123 arguments |
| `tools/manual/assemble.py` | `outline()` takes a chapter's number from the outline (today from the file name prefix `NN-`; `ch = str(int(m.group(1)))`) so that a renumbered chapter still verifies; keep the contiguity and link checks (now sanity checks); `verify()`'s `section N.M` check stays for any literal that remains; `assemble_parts` titles likewise from the outline; the `resolve()` function is where an unresolved `{{` would be caught | edit |
| `tools/check-manual-src.py` | add the tests of `proto/tests.py`; the `good` fixture uses tokens | edit |
| `tools/check-refs.py` | `targets()` reads the manual's numbers from `docs/manual-src` literally; after the migration it must read them from the resolved `docs/manual/*.md` (or `bookrefs`), otherwise 1,037 documents' citations look bad; drop the strict "bare `(N.M)` in manual-src" rule (the lint replaces it) | edit (verified: unchanged, it reports 22 bad in the manual sources and 1,037 in other documents) |
| `tools/mkchapters.py` | none required: it reads the resolved `docs/manual`, `{{` escape unaffected. The heading check ("`# 6.` equals the outline's number") becomes tautological; keep as a defence or delete | optional |
| `tools/mkbook.sh` | in `--check` (and the build) call the cross-check `bookrefs.check_against_buildabook(read_outline(outline.txt), build/number_map.csv)`; comments | edit |
| `book/README.md`, `book/outline.txt`, `book/sources.txt`, `book/book.conf`, `book/template.typ` | README sentence "section numbers inside the text are literal" is false afterwards; the rest unchanged | edit README only |
| `tools/check-all.sh` | add `tools/lint-literal-numbers.py` (the lint) after `check-manual-src.py` | edit |
| `docs/design/src/**` (design notes and `appendix-parts/*.md`, 28 files) | NOT part of this migration (see risks): they cite the manual's numbers "as they were when each note was written", and the fragments are named by chapter number (`06-open.md`) and carry `J.6.n` | phase 2 |
| the ~40 other documents, C comments, grammars citing `section N.M` | unchanged; stale on the first renumbering, as today | keep a legacy map (`names.tsv`, old number to name) and a lookup tool; convert with the same script if wanted |

## 8. The checks that replace the literal-number checks

| check today | replaced by |
|---|---|
| sections of a chapter numbered 1..n, statements 1..n per section (`assemble.outline`) | true by construction; the check stays as a cheap sanity check on the resolved text (it would catch a resolver bug) |
| every `section N.M[.K]` names an existing target (`assemble.verify`) | the resolver: an unknown name is an error; **plus the lint** `lint_literal.py` (to become `tools/lint-literal-numbers.py`): a literal number that equals an existing section/statement/figure, standing after `section`, `statement`, `Figure`, `see`, `§` or `(`, in `docs/manual-src` or in the generators' strings, is an error ("write `{{r:name}}`"); decimals, versions and numbers of other documents are not in the numbering and pass; a deliberate exception goes in an allow list |
| the number in each source heading agrees with the outline (`mkchapters.py`) | trivially true: the heading is `{{c:uuid|n}}`; kept as a cheap defence |
| buildabook's numbers agree with the text | `check_against_buildabook` in `mkbook.sh --check`: the resolver's chapter, part and appendix numbers equal `number_map.csv` |
| (new) a name is defined twice, a citation of an unknown name, a marker in an unnumbered file | the resolver, at every `mkmanual.py` run |
| (new) generated output has no leftover token | `BR.leftover()` over the output in `mkmanual.py --check` |
| (new) what moved | optional: `docs/manual-src/names.tsv` regenerated by `mkmanual.py` makes a renumbering visible in a diff |

## 9. Risks

1. **A wrong classification** (a decimal turned into a citation, or a citation left literal) is invisible to the round trip, because a mistaken token still resolves to the same digits until the first renumbering. Mitigation: read `report.txt` (225 weak conversions, 201 left literal); I found and fixed in the rules `about 5.5 megabits`, `FreeBSD 5.3`, `versions 1.1 and 1.4`, `handbook 3.2, 3.5`, `2.7 to 3.3 bytes`, `Figure 5.1` (a figure, not section 5.1); the lint catches a left-literal citation; the migration agent must do a second reading.
2. **Awkward names.** Generated from first words; freeze them only after one polish pass (`rename_name.py`). After the commit, names are identity.
3. **Concurrent edits** to `docs/manual-src/` while the conversion runs: do it from a clean commit in one commit (the script is deterministic and rerunnable on the pre-migration state).
4. **Design notes** (`docs/design/`): fragments are named by chapter number (`06-open.md`), carry `J.6.n` numbers and moved statements keep their old literal numbers (`**2.3.3** (moved from chapter 2)`): they remain a second literal numbering; inserting a chapter still breaks them. Phase 2: key fragments by file stem, let notes cite by name.
5. **File name prefixes** (`06-kernel.md`) are used as chapter numbers by `assemble.outline` and `assemble_parts`; fix as in section 7 (take the number from the outline).
6. **Two outline readers** (the resolver's 25-line reader and buildabook): guarded by the cross-check; the reader handles only `c p a` and the five directives; an unknown directive in `outline.txt` would raise.
7. **Tokens in generator strings**: `{{` is the escape in `.format()` and f-strings; the converter reports it (none today); strings in Python pass through `%` formatting safely.
8. **Import order**: `HOME` is built at import, so `R()` numbers `docs/manual-src` lazily (the prototype shows it works).
9. **Other documents** (about 40, 243 warnings today) keep literal numbers and go stale at the first renumbering; unchanged from today's situation but now more likely to be noticed.
10. **GitHub anchors** contain the number (`#62-modes...`): one in-manual link (handled by `{{u:}}`) and one external link found; optional: emit `<a id="name"></a>` for stable deep links (changes generated output; off by default).
11. **Code fences**: tokens are replaced in code too; there is no `{{` in the manual sources today (checked); keep it so (the resolver errors on unknown tokens).
12. Statements in list items, tables or block quotes cannot be numbered (none today).

## 10. Steps for the migration agent

0. Wait until the current edits are committed. Start from a clean tree. Build buildabook; `tools/mkbook.sh` and `python3 tools/mkmanual.py --check` pass before starting.
1. Add `tools/manual/bookrefs.py` (copy `/tmp/mig-design/proto/bookrefs.py`), `tools/lint-literal-numbers.py` (copy `lint_literal.py`, take its `nums` from `bookrefs`), `tools/manual/rename_name.py` (optional).
2. Run `convert_to_names.py docs/manual-src OUT book/outline.txt book/sources.txt --py tools/mkmanual.py tools/manual/*.py` (the `--py` list has to include `tools/mkmanual.py` and all `tools/manual/*.py` except `assemble.py`, `layouts.py`, `memberprose.py`, `isa_common.py`), review `OUT/report.txt` fully (weak conversions and "left literal" lines; add confirmed ones to `force.txt`, rerun), copy `OUT/*.md` over `docs/manual-src/` and `OUT/py/*` over the generators.
3. Delete the dead `sect` argument of `E()` and its call-site arguments; re-run.
4. Patch `tools/mkmanual.py` as `apply_prototype.py` does (sources numbered and resolved; `build()` resolves the generated text, `FIGS`, `DFIGS`; `HOME` and the entry keys by `R(name)`).
5. `python3 tools/mkmanual.py` and `git diff --stat docs/`: **there must be no change under `docs/manual/` or `docs/design/`** (the proof; any diff is a bug).
6. Patch `assemble.py` (chapter number from the outline, not from the file name), `check-refs.py` (targets from the resolved manual), `mkbook.sh` (cross-check), `check-all.sh` (lint), `check-manual-src.py` (tests from `proto/tests.py`), `00-index.md` list numbering, `docs/manual-src/README.md`, `book/README.md`.
7. Polish the generated names once (`rename_name.py`), rerun step 5, then `python3 tools/mkmanual.py --check`, `python3 tools/check-manual-src.py`, `tools/mkbook.sh --check`, `tools/check-all.sh`; build the book (`tools/mkbook.sh`) and compare `pdftotext` with the committed PDF.
8. Prove renumbering works on the real tree: insert a throwaway section in chapter 6, run `mkmanual.py`, confirm every citation and every figure moved and the checks pass, revert.
9. Commit (the conversion in one commit; the tools in another). Keep `names.tsv` (old number to name) in the commit message or under `docs/manual-src/` for converting the other documents later.
10. Phase 2, if wanted: design notes (fragments by file stem; notes cite by name), the other documents.
