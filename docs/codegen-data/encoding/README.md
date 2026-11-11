# Encoding study: scripts, tables and results

Working files of [`../../encoding-proposal.md`](../../encoding-proposal.md): the encoder/decoder prototype (`scheme.py`, `enc.py`, `proof.py`), the slot solver (`solve.py`), the entropy bound (`entropy.py`), the ablations (`abl.py`, `fuse_abl.py`), the leave-one-out check (`loo.py`) and the form tables of each candidate scheme (`tables-*.md`, `families-*.md`). The paths inside the scripts point at the measurement work directories used when they were written (the compiled corpus, the 32-register compile and the `sim64` profile) and need adjusting to rerun. `dynkeys.pkl` was not kept.

## The re-optimisation on the new compiler's output (section 12 of the proposal)

* `load.py`: `corpus(tag)` reads the compiled assembly of a tag; `PDP64_CORPUS_DIR_<TAG>` names its directory (`new16`, `new32`: `ccom -m pdp64/16|32` over the 841 files), `PDP64_CORPUS_EXCLUDE` / `PDP64_CORPUS_ONLY` (file name prefixes) leave projects out or keep only them. `m2.py` is the assembly reader.
* `export_forms.py OUTDIR --tag16 new16 --tag32 new32 --rounds 2 --lam 2 --keep-hot --refine 6 --cb3` writes the grammars (the command that produced `spec/`); without options it reproduces the original study's. `reopt.py` runs one configuration of the ablation; `loo_cb.py` the leave-projects-out check.
* `cbreach.py` (every `cbCC` site: distance, immediate, form or substitution), `cbforms.py` (the `cbCC` forms of a grammar and the code space they take), `distances.py` (the distances of the pc-relative operands and the reaches that cover them), `asm_vs_model.py 16|32 OUTDIR [TAG]` (real assembler against the model).
  `PDP64_SPEC_ROOT=DIR` makes `tools/encgram.py` read the grammars of another tree (an older `spec/`) to compare with.

## Status of the scripts

The two-grammar period (pdp64/16 and pdp64/32) is over: pdp64/32 is the pdp64, and `spec/pdp64/pdp64.hbnf` is its only grammar (errata 122). `mk_vectors.py`, `mk_asm_tests.py` and `mk_ld_tests.py` write the tests of that grammar (`tests/enc/vectors.txt`, `tests/asm`, `tests/ld`) and are current. The scripts that compare the two encodings or train one for a corpus (`export_forms.py`, `write_hbnf.py`, `asm_vs_model.py`, `cbreach.py`, `cbforms.py`, `distances.py`, `reopt.py`, `loo_cb.py`, `abl.py`) call `tools/encgram.py` with an encoding tag (`16`, `32`) and read `spec/pdp64-16/` and `spec/pdp64-32/`; they are history, not maintained, and run from the git tag `pre-code-removal`.

**Running the old scripts.** The scripts of the second group read the two grammars `spec/pdp64-16/` and `spec/pdp64-32/` and take an encoding tag (`16` or `32`); those directories, and the corpus directories (`new16`, `new32`) they use, exist only in the git tags `pre-single-cpu` and `pre-code-removal`. To run one, check out the tag `pre-code-removal` in a separate worktree (`git worktree add ../pdp64-old pre-code-removal`) and run the script from `docs/codegen-data/encoding/` of that tree, with its `tools/encgram.py`. On the current `main` they do not run (`encgram.load(root)` takes no tag). They are the evidence behind `docs/encoding-proposal.md` and `docs/encoding-work/`; the tables `tables-*.md` and `families-*.md` are the form tables of the candidate schemes of that study (16 and 32 registers; the single pdp64 grammar is `spec/pdp64/pdp64.hbnf`).

## Superseded by `encopt` (2026-11-10)

The selection of the optional forms (`solve.py`, `solve()`: greedy by bytes saved per code space, five exponents, a local search) is a heuristic with no bound: on the current statistics it is 0.9% above the optimum
(and the committed grammar contains 47 redundant leaves). **`tools/encopt/` supersedes it**: a C program that chooses the forms exactly (reductions, Lagrangian dual-ascent bounds, branch and bound, frontier dynamic
programme) and assigns the prefixes, with a proof status; its input is exported from these scripts' data by `tools/encopt/export.py` (which imports `load.py`, `cat.py`, `enc.py`, `variants.py`, `export_forms.py`
from here). The scripts in this directory stay as the history, as the model (`enc.py`, `scheme.py`: `export.py --verify` measures an `encopt` result with it) and as the source of the candidate forms (`cat.py`).
See `docs/encoding-work/optimizer.md`.

**Reader bug, found by `encopt`.** `m2.py` reads `set cc,rd` (and the system-register moves `mfsr`/`mtsr`) with their word operand as a label, so those instructions (337 to 342 in the corpus) were counted as unencodable in every figure of the scripts here. The scripts are history and are not edited; `tools/encopt/corpusfix.py` is the corrected reader used by `tools/encopt/export.py` (see `docs/encoding-work/optimizer.md`, section 10).
