# The pdp64 manual on buildabook's nested sections: design, proof, what is missing

Scratch: `<scratch>/` (nothing in pdp64 or in the buildabook repository was touched; the HEAD files of the manual were read with `git show`).

| path | what |
|---|---|
| `<scratch>/bab/` | clone of buildabook at 96634dd, built unmodified (`<scratch>/bab/buildabook`) |
| `<scratch>/bab2/` | the same plus a 3-change prototype patch (`<scratch>/buildabook-prototype.patch`, 84 lines): flag `\|p`, appendices as section parents |
| `<scratch>/bw.sh` | runs a command in the Alpine root with bwrap (`CWD=/mnt/bab ./bw.sh gprbuild ...`; `/mnt` is `<scratch>`) |
| `<scratch>/pdp/` | HEAD copy of `docs/manual-src/`, `book/`, `tools/` (read-only source of the proof) |
| `<scratch>/work/` | `convert.py` (names to nested rows), `sync.py` (the generator), `runbook.sh`, `proof.py`, `run-all.sh` (reproduces everything), `out/` (the converted manual: `outline.txt`, `src/`, `names.tsv`, `bk/` = the build, `bk/number_map.csv`), `out3/` (author scenario), `out4/` (drift scenario) |

## 0. Verdict

Nested `s` rows are enough for the numbers, with four small changes in buildabook (two of them already prototyped here, section 4: M1 to M4) and one small generator in pdp64 (section 6) so that an author edits only the chapter. With them, **all 669 numbered names of the manual (150 sections, 474 statements and numbered subsections, 45 figures) get buildabook-computed numbers equal to the old literal numbers, and all 16 source files resolve byte for byte to what the old resolver (`tools/manual/bookrefs.py` at HEAD) makes of them** (one file differs only by buildabook's hard-wired table splitting, M3). Build time 0.05 s for a 740-line outline; outline file 29 KB (669 new rows, 25 KB).

Mapping: chapter or appendix = `c:` / `a:` row; **section = `s1:`; statement and numbered subsection (`###`) = `s2:`; figure = `s1:` in a run at the end of the chapter's rows after `s:count:1`**; all under `s:root:chapter`.

## 1. Build and tests (task 1)

* Host: Debian gnat 14.2 but no gprbuild; the Alpine root `/tmp/hbnf-latest/root` runs under bwrap: `bwrap --bind ROOT / --dev /dev --proc /proc --bind <scratch> /mnt --unshare-all --share-net --chdir /mnt/bab gprbuild -P buildabook.gpr -p -bargs -static -largs -static-libgcc -static` gives a static-pie ELF like the installed one. `build.sh` of the repository is docker (`ada-toolchain:edge`) and `Makefile.in` calls `gprbuild -P buildabook.gpr -p` (what `make` does); `make check` = `gprbuild -P tests/tests.gpr -p && tests/tests` plus `BUILDABOOK=./buildabook sh tests/nested.sh`.
* **Built; tests/nested.sh: 15 passed, 0 failed; aunit suite: 14 tests, 14 successful, 0 failures.**

## 2. How nested sections work in the files (task 2)

Read from `LANGUAGE.md`, `src/outline.adb`, `src/materialize.adb`, `src/tokens.adb`, and tried on small books (`<scratch>/t1`).

* **A section heading is not matched to its outline row.** Only the chapter file is matched: by `filemap.txt`, or (tried, works without a filemap) by the first `# ` heading containing the chapter token, and `# {{c:id01006|n}}. The kernel` is accepted. A section is just text that contains the token: `## {{s:id10255}} Modes` renders `## §6.2 Modes`. The token IS the link; nothing checks that the text order equals the outline order (section 8, risk 1).
* **Citation**: `{{s:id}}` renders the display of the row: `§6.2`, `§6.2.1`. Flags: `|n` the row's own counter only (`2`, not `6.2`), `|s` short label, `|page` a Typst page lookup. **Unknown flags are silently ignored** (tried), which is what lets the readable name ride in the token: `{{s:id10255|p|=modes-and-the-status-word}}`.
* **Display**: for a section without a label the path is always `§` plus the path; no flag drops the sign. `6.14` / `6.14.9` / `5.1` therefore need M1 (flag `|p`, prototyped) or a post-process that deletes `§` (valid today only because `§` occurs nowhere in `docs/manual-src/` except one README line).
* **Rendering**: tokens are resolved while `buildabook typst` writes `rendered/*.md` (plain text, numbers in place, e.g. `**6.2.1** There are three modes`), then `rendered/book.typ` has one `#chapter(...)` per MAPPED entry (unmapped entries only warn: used for the annex, section 9). Typst never sees numbers; cmarker renders the resolved Markdown. After every heading (levels 2 to 6) that contains an `s:` token buildabook plants `<!--raw-typst #pgan("id")-->` (the page anchor for `|page`); it is an HTML comment, invisible on GitHub but present in the file. It also splits every table of more than 40 data rows (hard-wired).
* `number_map.csv` header: `uuid,kind,title,label,short,style,n,rendered,parent,depth` (`depth` only for nested outlines; CRLF). Rows, from the prototype: `id10254,section,What you already know: the kernel of a PDP-11,,,arabic,1,§6.1,id01006,1`; `id10256,section,there-are-three-modes,,,arabic,1,§6.2.1,id01006,2`. `kind` is `section` for every depth; `parent` is the chapter.
* Rules met: the first section of a chapter must be `s1` (the one-layer rule), going up is free. A chapter's counters restart at `c`, `d`, `n`, `u` rows. **An `a:` row neither restarts nor becomes a parent**: sections placed after `a:id03003` count on from the previous chapter (`§2.3` in my test) and `s:root:chapter` after a division stops with `root:chapter needs a chapter before section` (M2).

## 3. The prototype and the proof (task 3)

`work/convert.py` reads the HEAD manual-src with the old `bookrefs.py` (the old numbers), allocates ids `id10001...` sequentially in book order, rewrites the source (`{{#name}}` to `{{s:idN|p|=name}}`, `{{r:name}}` likewise; figures lose their marker, the row is tied to the image path), writes the outline blocks and `names.tsv` (uuid, kind, name, old number, file). `work/runbook.sh` builds a book directory and runs `buildabook typst`. `work/proof.py` compares.

Results (`work/run-all.sh`):

* 669 definitions (150 / 474 / 45; chapter 6 alone: 17 sections, 87 statements and subsections, 8 figures = 112 rows); **669 of 669 computed numbers equal the old numbers** (figures `5.1` and appendix `A.1` included).
* 1,564 `s` tokens in the 16 files (669 definitions, 895 citations; the 188 token lines of chapter 6 and the citing files are all included, since cross-chapter citations resolve only if all rows exist); **every file equal to the old resolver's output** (raw-typst comments removed) **except `appendix-b-glossary.md`: three added lines, the split of its long table** (M3).
* Two things were converted outside buildabook for the proof: `{{n}}.` lists (16 lines of the index) written out as `1. 2. 3.`; one `{{u:name}}` link written as its old literal anchor.
* PDF: the book built from these `rendered/` files (176 pages, no dictionary entries) shows `6.2 Modes and the status word`, `6.2.1 There are three modes`, `A.1 A page bit that enforces landing pads`; `typst compile` 2.4 s; `buildabook typst` 0.05 s, 5 MB.
* Readable names: the name rides in the token (`|=name`). The outline row of a statement has the name as its title (so `number_map.csv` maps number to name), of a section the heading text, of a figure the image path. `sync.py` checks that a name belongs to one id only. Names stay available to authors by grep, in the text, next to the id.

## 4. What is missing in buildabook (M1 to M4 are needed; the rest can wait)

| | missing | size | where it bites |
|---|---|---|---|
| **M1** | a path without `§`: flag `\|p` (prototyped: `Display` parameter `Path_Only`, 4 lines) or a directive `s:sign:none` | tiny | every number: `6.14`, `6.14.9`, `Figure 5.1` |
| **M2** | appendices as parents of sections, restart counters, and `root:chapter` using the appendix's own text (`A`, `C`): prototyped (a `Root_Txt` string replaces `Chap_N`; 12 lines in `outline.adb`) | small | appendices A, B, C, E hold 50 names (`A.1`, `C.2.3`); also `d:` and `n:` as roots would be natural |
| **M3** | a resolve-only mode, e.g. `buildabook resolve --out DIR`: tokens resolved, NO `<!--raw-typst-->` page markers, NO table splitting, no `book.typ`, non-zero exit on any error. `docs/manual/` must be plain Markdown on GitHub: today `typst` output would have to be post-filtered (comments removed by regexp) and its 40-row table splitting cannot be switched off | small | the GitHub copy |
| **M4** | exit status: `buildabook typst` returns 0 although tokens failed (it writes `{{ERROR:...}}` and the message; only `check` returns 1); LANGUAGE.md says the build fails. A pipeline must call `check` first or the exit status must be fixed | tiny | all builds |
| M5 | an escape for `{{ }}`: there is none; any `{{` with a later `}}` anywhere in the file, also inside code fences, code spans and across lines, is parsed as a token (`={{1,2},{3,4}}` in a C snippet gives `Invalid token`). The manual has none today (the old `mkchapters.py` wrote `{ {`); the annex will quote real C and assembler. Ask: skip fenced and inline code, or `\{{` | small | annex, future text |
| M6 | a definition-site check: buildabook does not check that the tokens that define rows (heading or statement start) stand in the text in outline order, once each, nor that the heading level fits the depth (listed as not yet implemented in DESIGN-NESTING). Shown to fail silently: swapping two statements in the text prints `6.2.2` before `6.2.1` and nothing complains (`work/out4`) | medium | correctness, see risk 1 |
| M7 | figures: no kind, no named counter. Workaround proven: a run at the END of each chapter's rows after `s:count:1`, in image order, as `k2s.py` does for stacks. It works because the number depends on the row, not on its position in the text; the order is kept honest only by `sync.py`. A kind or counter family (`f:`) with its own label (`Figure`) would remove the trick | medium | 45 figures |
| M8 | links to a heading: `{{u:name}}` (1 use) needs the GitHub anchor, which is a slug of the resolved heading. Use an explicit `<a id="..."></a>` in the source heading and write the link by hand | none needed | 1 link |
| M9 | an ordered-list counter (`{{n}}.`, 16 lines of the index): write `1.` on every line (Markdown counts) or keep it out of buildabook | none | index |
| M10 | the uuid space: five digits, 99,999 names for a book, ids unrelated to names. `buildabook uuid s` prints the next free id. A name lookup (`buildabook find NAME`, over the `\|=name` annotation) would be convenient, not needed | optional | authors |
| M11 | volumes and cross-volume tokens (section 9) | large | annex |

Not needed: `s+`/`s-`, `|f`, heading styles for levels 4 to 6, `toc-depth` (sections are not listed in the contents; only the chapter-level entries are mapped).

## 5. What stays in pdp64's own tooling

* `tools/mkmanual.py`: assembly of the hand text with the generated parts (instruction entries, dictionary, 2,111 figures, layout charts). The generators emit tokens: `R('name')` in `tools/mkmanual.py` and the strings of `tools/manual/*.py` become `{{s:id|p|=name}}` via a lookup in the table `sync.py` builds from the sources (184 citations and 27 chapter/appendix words in Python strings today, found in the earlier proof).
* `tools/mkchapters.py` shrinks: link conversion, comment removal, sticky images, part files; its heading-number check, `book/sources.txt` and the filemap become unnecessary (buildabook matches `# {{c:id|n}}. Title` itself; verify with a book that has parts and unnumbered entries).
* `tools/lint-literal-numbers.py` stays (it catches a number typed where a citation belongs, now forever). `tools/check-manual-src.py` loses the resolver tests, keeps assembly tests. `tools/manual/bookrefs.py` and `rename_name.py` go (renaming a name is a text substitution of `|=old` by `|=new`: the id, which is the identity, does not change, so a rename can no longer break a citation).
* New: `sync.py` (about 130 lines, section 6), a staging step and `buildabook resolve` (M3) in `mkmanual.py`; `mkmanual.py --check` and `check-all.sh` then need the buildabook binary (today they do not). If that is unwelcome: commit `book/number_map.csv` (buildabook's own output) and let a 15-line substitution read it; the engine remains buildabook.
* The design notes `docs/design/` keep their own numbers (`J.3.2`), as now.

## 6. The authoring workflow

Weighed: (a) edit chapter AND outline: two edits, order errors silent (M6); (b) buildabook reads the statements from the text: no outline authority, large feature; (c) **chapter only, a generator writes the outline rows (recommended)**. Prototype `work/sync.py`, tested on the whole manual:

* The outline rows of the names are GENERATED between `# >>> names FILE` and `# <<< names FILE` in `book/outline.txt` (comments for buildabook), from the text of FILE, in text order. Outline stays buildabook's input, committed, human-readable; chapter, part and appendix rows are still hand-written.
* The author types a new name with `@` instead of an id: `**{{s:@|p|=psw-has-three-modes}}** text`, a heading `## {{s:@|p|=kernel-modes}} Title`, a citation `{{s:@|p|=kernel-modes}}` (the `@` of a definition allocates an id; of a citation looks it up). `sync.py` rewrites the `@` to the id in place and rewrites the blocks. `mkmanual.py` runs it first; `--check` fails if anything would change.
* Tried (`work/out3`): a new statement inserted after 6.2.1 with a citation of 6.2.3 and 6.2: one edit; sync; the old 6.2.2 became 6.2.3 and every citation followed. Drift (`work/out4`): `sync.py --check` says out of date; buildabook alone would print a wrong order.
* Ids: sequential here. Parallel branches adding names would take the same next id (buildabook then reports `duplicate UUID` at merge, safe but annoying): better one id range per file (file k: `idKK000` to `idKK999`; chapter 9 has 139 rows), decided before the migration.
* Alternative that removes the generator: a buildabook feature that takes `s` rows for a chapter from markers in its text. I would not ask for it: the outline would stop being the authority.

## 7. Conversion algorithm and steps for the migration agent

0. Precondition: M1 to M4 in buildabook (the owner's repository; the patch is a starting point; M2 needs a test for an appendix with sections). Work on a branch; the manual is being edited by someone else: do the conversion from a fresh `git show HEAD:` snapshot and re-run it after the last manual change (the script is idempotent and the proof is one command).
1. Decide the id scheme (ranges, section 6) and the figure convention (run at the end, or M7).
2. `convert.py` (adapt paths): for each hand source file in book order, number with the old `bookrefs.Book` (old numbers); definitions: `##` s1, `###` and `**{{#n}}**` s2, figure lines s1 in a run after `s:count:1`; write blocks into `book/outline.txt` with the markers; rewrite `{{#n}}` and `{{r:n}}` to `{{s:id|p|=n}}`; `{{n}}.` lists to `1.`; the one `{{u:}}` link to an explicit anchor.
3. Do the same `{{r:name}}` substitution in `tools/mkmanual.py`, `tools/manual/*.py` and `R('name')`; generated markers `<!-- entries:{{r:name}} -->` become `<!-- entries:{{s:id|p|=name}} -->` (the generator reads the resolved key `9.6`).
4. Add `sync.py` to `tools/`, call it first in `mkmanual.py`; stage the tokenised assembled files, run `buildabook check`, then `buildabook resolve` (M3) into `docs/manual/`.
5. `tools/check-all.sh`: add `sync.py --check`; remove `bookrefs` checks; `mkbook.sh` uses the same outline and `check` first (M4).
6. Prove: resolved `docs/manual/` equals the committed one for every file (`proof.py` does it against the old resolver; here the glossary differs only by M3); every old number equals `number_map.csv`; `mkmanual.py --check`; `mkbook.sh`, `pdftotext` equal to the old PDF text. Then delete `bookrefs.py`, `rename_name.py`, `sources.txt`, update `docs/manual-src/README.md` and `book/README.md`, `docs/encoding-work/numbering-migration-design.md`.

## 8. Risks

1. **Order drift** between the text and the outline is silent in buildabook (M6); sync's check is the only guard, so `--check` must be in `check-all.sh` and a commit hook.
2. **Stock buildabook cannot do appendices or `6.14`** (M1, M2): the migration waits for the owner's release, or runs on a patched build.
3. **`{{` in code** (M5): none now; the annex will need an escape.
4. buildabook becomes a hard dependency of the GitHub copy (today it is only for the book).
5. Sources are less readable: `{{s:id10255|p|=modes-and-the-status-word}}` is 17 characters longer than `{{r:modes...}}` (+4.7 KB over 775 KB); the name stays.
6. Figures are tied to the outline by image path; a figure that moves in the text without a sync run gets the wrong number.
7. Id collisions across branches (section 6). 5-digit namespace shared with the annex unless the annex is its own volume.
8. `typst` stage exit status 0 on failure (M4): any script that trusts it ships `{{ERROR:...}}`.
9. Heading anchors on GitHub change with the number (`#62-modes...`): the 1 internal link and any external deep link to a numbered heading.

## 9. Volumes and the annex (task 5)

* **State**: nothing in the source (no `volume` or `series` in `src/` or `grammars/`). `DESIGN-NESTING.md` (section "Parts, Books and volumes") decides: parts suffice for Books inside a book; a volume is a separate book in its own directory with its own outline, `book.conf`, PDF and cover, and the set is described by a `series.txt` in the top directory: `v:antelope   vol-01-a-to-b   Volume 1, A to B`, one line per volume; `buildabook series` builds all volumes, writes ONE combined number map, and a cross-volume citation names the volume: `{{c:antelope:id00042}}`, `|page` gives the page in that volume (a two-pass build). Details tbd: title page, combined index, chapter-number ranges; it is the last item of the order of work.
* **The annex** (`docs/annex/`: README, template, entries 01 to 14, snippets): each file starts `# Part N. Title` and holds `##` entries (`{{#annex-...}}`); subsections are unnumbered `###`. For buildabook: the parts are `c:` (label `Part`) or `p:` rows, each entry an `s1` row (names start `annex-`), no `s2` rows (no statements). It cites the manual: 37 `{{r:...}}` citations in entries 01 to 14, almost all of manual statements, so it needs cross-volume tokens. The README mentions the owner's `{{st:name}}` (statement) and `{{h:name}}` (heading): buildabook has one prefix `s` for both; add them only if a different display is wanted.
* **Without the Volume feature today**: one shared `outline.txt` (manual rows plus annex rows) and TWO filemaps/`book.conf`: an unmapped entry only warns and makes no `#chapter` call (checked: 1 chapter call for 1 mapped file), so each book contains only its own pages and `{{s:id}}` citations of manual statements resolve to manual numbers. Missing there: a "Volume" word before a foreign number, and `|page` into the other book. The annex rows would be one more block per file in the same outline, with its own id range.
* **Needed for the annex when volumes exist**: `series.txt`, the cross-volume token with `|page`, `s1` rows for entries under `c:`/`p:` rows (works now), the escape M5 (real C and assembly in the foreign snippets), and the generator `sync.py` run per volume.
