# Encoding study: scripts, tables and results

Working files of [`../../encoding-proposal.md`](../../encoding-proposal.md): the encoder/decoder prototype (`scheme.py`, `enc.py`, `proof.py`), the slot solver (`solve.py`), the entropy bound (`entropy.py`), the ablations (`abl.py`, `fuse_abl.py`), the leave-one-out check (`loo.py`) and the form tables of each candidate scheme (`tables-*.md`, `families-*.md`). The paths inside the scripts point at the measurement work directories used when they were written (the compiled corpus, the 32-register compile and the `sim64` profile) and need adjusting to rerun. `dynkeys.pkl` was not kept.

## The re-optimisation on the new compiler's output (section 12 of the proposal)

* `load.py`: `corpus(tag)` reads the compiled assembly of a tag; `PDP64_CORPUS_DIR_<TAG>` names its directory (`new16`, `new32`: `ccom -m pdp64/16|32` over the 841 files), `PDP64_CORPUS_EXCLUDE` / `PDP64_CORPUS_ONLY` (file name prefixes) leave projects out or keep only them. `m2.py` is the assembly reader.
* `export_forms.py OUTDIR --tag16 new16 --tag32 new32 --rounds 2 --lam 2 --keep-hot --refine 6 --cb3` writes the grammars (the command that produced `spec/`); without options it reproduces the original study's. `reopt.py` runs one configuration of the ablation; `loo_cb.py` the leave-projects-out check.
* `cbreach.py` (every `cbCC` site: distance, immediate, form or substitution), `cbforms.py` (the `cbCC` forms of a grammar and the code space they take), `distances.py` (the distances of the pc-relative operands and the reaches that cover them), `asm_vs_model.py 16|32 OUTDIR [TAG]` (real assembler against the model).
  `PDP64_SPEC_ROOT=DIR` makes `tools/encgram.py` read the grammars of another tree (an older `spec/`) to compare with.

## Status of the scripts

The two-grammar period (pdp64/16 and pdp64/32) is over: pdp64/32 is the pdp64, and `spec/pdp64/pdp64.hbnf` is its only grammar (errata 122). `mk_vectors.py`, `mk_asm_tests.py` and `mk_ld_tests.py` write the tests of that grammar (`tests/enc/vectors.txt`, `tests/asm`, `tests/ld`) and are current. The scripts that compare the two encodings or train one for a corpus (`export_forms.py`, `write_hbnf.py`, `asm_vs_model.py`, `cbreach.py`, `cbforms.py`, `distances.py`, `reopt.py`, `loo_cb.py`, `abl.py`) call `tools/encgram.py` with an encoding tag (`16`, `32`) and read `spec/pdp64-16/` and `spec/pdp64-32/`; they are history, not maintained, and run from the git tag `pre-code-removal`.
