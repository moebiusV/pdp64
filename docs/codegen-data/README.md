# docs/codegen-data: measurements, tables and scripts behind the studies

This directory holds the data of the code-generation, encoding and kernel studies. It is evidence, not specification: the specification is the manual and the grammar
(`spec/pdp64/pdp64.hbnf`). Dated records of the studies are `docs/codegen-analysis.md`, `docs/encoding-proposal.md`, `docs/encoding-work/`, `docs/kernel-asm-survey.md` and
`docs/kernel-pain-points.md`.

**The old Python scripts run from a tag, not from `main`.** The scripts under `encoding/` that load the grammars by an encoding tag (`16` or `32`: `export_forms.py`,
`write_hbnf.py`, `asm_vs_model.py`, `cbreach.py`, `cbforms.py`, `distances.py`, `reopt.py`, `loo_cb.py`, `abl.py` and the others listed in `encoding/README.md`) belong to the
two-grammar period. The pdp64 is one CPU with one grammar now (errata 122, 123), and the grammars `spec/pdp64-16/`, `spec/pdp64-32/` and the tools that read them were removed.
They run from the git tag `pre-code-removal` (a checkout of that tag in a separate worktree); the tag `pre-single-cpu` holds the state before that. Do not try to run them
on `main`. See `encoding/README.md`.

| Path | What it is |
|---|---|
| `encoding/` | the encoding study: prototype, solver, ablations, form tables (see its README) |
| `archcmp/` | the static comparison of pdp64 with other architectures (`archcmp-*.csv`; `tools/archcmp.py`); the later and wider comparison is `docs/encoding-work/arch-comparison.md` |
| `kernelasm/` | the assembly found in the Linux and FreeBSD kernels, classified (`tools/kernelasm.py`; the revisions are in `sources.txt`) |
| `kernelpain/` | the kernel pain-points research data (`tools/kernelpain.py`; `RESUME.md` says what exists) |
| `verification/` | `claims.csv`, the claims checked for the kernel study |
| `analysis.json`, `*.csv` at this level | per-corpus statistics of pcc output and of gcc and clang for amd64: mnemonics, pairs, bigrams, trigrams, shapes, lengths, totals; `pdp64-after-*.csv` are the totals at successive dates (2026-10); they describe the compiler and the encoding of those dates |

The sizes in these files are those of the compiler and encoding of their date (the old encodings, 16 registers in the early files); the current ones are measured again by the
tools (`tools/pdp64size.sh`).
