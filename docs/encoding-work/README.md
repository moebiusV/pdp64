# The encoding work: reports, in the order of events (2026-11-03 to 2026-11-04)

These are the reports of the agents that did the work on the prefix-coded encodings and everything that followed from it, copied unchanged
from their working notes (apart from the file names), plus the report of the integration. They are a record: where a later report overturns an earlier
statement, the earlier file is not edited; the table at the end of this page lists what was overturned, and dated notes stand in the documents that are
still read (`spec/README.md`, `docs/relaxation.md`, `docs/encoding-proposal.md`, `docs/errata.md`).

**Status: record. The encoding story ends with errata 94, 122 and 123: the single pdp64.** The work below compared three encodings (pdp64/r20, pdp64/16, pdp64/32) and
built the toolchain for all of them. The author then decided (errata 94, 122) that the 32-register prefix-coded encoding, formerly called pdp64/32, is the pdp64, and that
r20 and pdp64/16 are previous iterations; errata 123 removed their code, data and tests. There is one CPU, one manual (`docs/manual-src`, `docs/manual`), one grammar
(`spec/pdp64/pdp64.hbnf`). Names such as pdp64/16, pdp64/32, `-m pdp64/16` and paths such as `spec/pdp64-16/`, `spec/pdp64-NN/forms.json` and `docs/manual/pdp64-*` in these
reports are those of the time; they exist only in the git tags `pre-single-cpu` and `pre-code-removal`. These files are kept as the **evidence** for why pdp64/32 was chosen
(the sizes, the executed instructions and bytes, the cost of far `cbCC`, the relaxation gains, the timing results), not as a description of the design. The current design is
in `docs/manual` and `docs/decisions-and-status.md`; where a report disagrees, those win. A reader who wants only the conclusion reads `integration.md` (the final table) and
`arch-comparison.md` (the size against other architectures).

The architecture at the time of the work had three members: **pdp64/r20** (the original encoding, revision 20: `len opcode reg low`), **pdp64/16** (prefix-coded, 16 registers)
and **pdp64/32** (prefix-coded, 32 registers), selected by `-m` in one toolchain.

## What each file is

| File | Class | What it is |
|---|---|---|
| `README.md` | current | this page |
| `phase1.md`, `phase2.md`, `phase3-pcc.md`, `pcc2.md`, `hbnf.md`, `ldrelax.md`, `cbreach.md`, `timing.md` | record | the reports of the agents, in the order of the table below |
| `integration.md` | record | the merge and the final measurements of the three encodings on the real toolchain: the main evidence for the choice |
| `arch-comparison.md` | record | the static size of the 841-file corpus for pdp64/32 against amd64, i386, RISC-V, AArch64, Arm, MIPS64 (measured 2026-11-10) |
| `arch-data/` | record (data) | the raw results of `arch-comparison.md`: `static-wide.csv` (per file and configuration), `pdp64-32-static.csv`, `static-summary.md` (the table), `pcc-riscv64-status-*.tsv` (which files the RISC-V port of pcc compiled, stock and with `va_list`), `diag-output.txt` (the diagnostic of one run) |
| `optimizer.md` | record | the encoding optimizer (written by another agent; see its own banner) |
| `manual-generated.md`, `manual-handwritten.md`, `manual-dropped-sentences.md` | history | the notes on the three per-encoding manuals made in this period; superseded by the single manual |

## Who decided what

| Decision | By | Where |
|---|---|---|
| Replace the parcel-0 layout by a prefix-coded one, as two grammars (16 and 32 registers); the names pdp64/16 and /32; r20 stays; the four fused pairs exist and are the compiler's business; the hot-register tables are ABI | the author | errata 87 |
| The grammars (hbnf) are the single source of truth; undo the Python/JSON pivot; use the latest hbnf | the author ("i said grammar is the source of truth; undo your pivot to python. use latest hbnf.") | errata 89 |
| Linker relaxation of external `call` and of data-symbol `lea`; relaxation on by default | the author | errata 91 |
| Core counts (4 minimum, 16 or more preferred), mixed cores | the author | errata 92 |
| Everything marked "assumed" or "found" in the reports: semantics of the new words the ISA text left open, the executor choices, the unimplemented list, the cbCC cost model, the 3-parcel cbCC, the reaches chosen, the compiler's optimisations and which are on by default (`-xssa` off), the default of relaxation being a one-line change, the timing model's parameters | the implementing agents, each in its report and errata entry; none is a decision of the author until he says so | the reports below, errata 88, 90 |

## The order of events

| # | Report | Branch (worktree) | What it did | Result in one line |
|---|---|---|---|---|
| 1 | [phase1.md](phase1.md) | `enc-prefix` (pdp64-enc) | the specification of the two encodings, the shared codec (`common/pdp64enc.c`), `as64` and `ld64` for pdp64/16 and /32, the Python model and the optimiser as oracle | both encodings assemble and link; model, codec and assembler agree on the 841-file corpus |
| 2 | [phase2.md](phase2.md) | `enc-prefix` | `sim64` and the shared executor for the three encodings, `sim64 -P` profile, the new instructions executed, tests | six large programs run identically in all three; Lua showed the cmp+bCC cost of far `cbCC` |
| 3 | [phase3-pcc.md](phase3-pcc.md) | pcc `enc-prefix` (pcc-enc) | compiler targets `-m pdp64/16|32` (second build for 32 registers), fusion, availability, switch dispatch, harness | 953,370 B (-12.0%) for /16 against 1,083,870 for r20 on the corpus |
| 4 | [pcc2.md](pcc2.md) | pcc `enc-prefix` | `-xccp`, `-xtailcall`, the VAX (Johnson) optimisations, jump tables, strength reduction, `-xssa` against the timing model (off) | 941,166 B /16, 973,436 B /32; the optimisation reference is `doc/PDP64-OPT.md` in pcc |
| 5 | [hbnf.md](hbnf.md) | `enc-hb` (pdp64-enc-hb) | the correction of the author: the grammars `spec/pdp64-16/*.hbnf`, `spec/pdp64-32/*.hbnf` are the source; `forms.json` deleted; `tools/encgram.py`, `tools/mkenc.py`; hbnf's own generated decoder checked against the codec | nothing changed in the generated tables (byte for byte); five hbnf gaps proposed to the author |
| 6 | [ldrelax.md](ldrelax.md) | `enc-ld` (pdp64-enc-ld) | linker relaxation in `ld64` with the object support in `as64`, on by default; `relaxcheck`; 7 mutants | -3.8% of corpus text, -1.8% of linked program text; the 4-byte `call` reaches +-1 MiB, not +-2 MB |
| 7 | [cbreach.md](cbreach.md) | `enc-cb` (pdp64-enc-cb) | the optimiser re-run on the new compiler's output, a correct cost model, three-parcel `cbCC` | far-`cbCC` substitutions 328 -> 4 (/16) and 866 -> 17 (/32); /32 is still +3.3% over /16 in size |
| 8 | [timing.md](timing.md) | `enc-tm` (pdp64-enc-tm) | `sim64 --timing`: a parameterised in-order pipeline model with 128 exact checks | the programs are execute-bound (load-use) at fetch width 4 and above; wide fetch gives 0.3% |
| 9 | [integration.md](integration.md) | `enc-int` (pdp64-enc-int) | the merge of branches 5-8 and main, pcc rebuilt on the merged tools, the final table | see that file |

The merge order was enc-cb (fast-forward), enc-ld, enc-tm, main. Phase 1, phase 2 and the pcc work were on `enc-prefix` of their repositories; `enc-hb`
branched from phase 2, `enc-ld` and `enc-tm` from phase 2 before the grammar migration, `enc-cb` from `enc-hb`.

## What was overturned later

| Earlier statement | Where | Overturned by | Now |
|---|---|---|---|
| tables come from `spec/pdp64-NN/forms.json` (the Python/JSON route) | phase 1, errata 87, `spec/README.md` of phase 1 | the author, errata 89 | the grammars; `encgram.load(tag, ROOT)` returns the dict that forms.json held |
| a 4-byte `call` reaches +-2 MB | errata 87, `docs/encoding-proposal.md` | ldrelax.md | +-1 MiB (20 bits counted in parcels); `jmp` and `movcall` have only the +-64 KiB 4-byte form |
| external calls cost 9% of the text and relaxation recovers it | phase 3 and the proposal | ldrelax.md | they cost 6 bytes each (10.4% of the corpus text) and relaxation recovers at most 2 of the 6: 3.5% of the corpus, 1.8% of linked programs |
| relaxation is opt-in (`--relax`) | ldrelax.md first version | the default commit of enc-ld | on by default; `--no-relax` opts out; r20 is not relaxed |
| far `cbCC` becomes `cmp` + `bCC` in 0.95% (/16) and 2.51% (/32) of the sites, 38.8 M executed pairs in Lua | phase 2, `docs/encoding-proposal.md` 0-11 | cbreach.md | the 38.8 M belonged to the old compiler's compare chain; after re-optimisation 4 and 17 sites in the corpus |
| model sizes A16 1,013,598 and C16 979,192; A32 / C32 1,007,172 | `docs/encoding-proposal.md` | phase 3, pcc2.md and integration.md | the real compiler and toolchain measurements; the model is the study, not the answer |
| `-xssa` might be worth turning on | phase 3 | pcc2.md | correct since a fix in `pp_avail`, but +3 to 5% cycles on both: off |
| pdp64/32 is on par with /16 in fetched bytes (+0.01% in phase 2, +1.4% in the first cbCC measurement) | phase 2, cbreach.md | cbreach.md, integration.md | +3.3% executed bytes and size; -5.9% executed instructions |
| `ccp` folded an int against an unsigned constant wrongly (c-testsuite 00104) | pcc2.md | integration (a fix in pcc `enc-prefix`) | fixed, test `ccp_signedness` |
* [manual-generated.md](manual-generated.md): the generated parts of the three manuals (charts from the grammars, the entries of the 70 new words, what is left for the hand-written text).
* [manual-dropped-sentences.md](manual-dropped-sentences.md): the review list of the sentences of the entries changed for pdp64/16 and pdp64/32.
* [manual-handwritten.md](manual-handwritten.md): the hand-written text of the manuals of pdp64/16 and pdp64/32, the system-level corrections made for all three, and what the repository does not settle.
