# Handoff: current working notes

[← pdp64 index](README.md)

Brought up to date 2026-11-18 (first written 2026-11-10 for the single-CPU state; sections 4, 5 and 7 and the pcc row of section 2 changed since). It says what exists, where it lives, how to rebuild it, the order of the work that is next, and what the working rules are. The source of truth for decisions is [`docs/decisions-and-status.md`](docs/decisions-and-status.md) (the ledger), with the author's words in [`docs/decision-register.md`](docs/decision-register.md) and the numbered decisions in [`docs/errata.md`](docs/errata.md); the map of all documents is [`docs/README.md`](docs/README.md). Where this file disagrees with them, they win.

## 1. What the project is now

One CPU, the **pdp64**: thirty-two registers, prefix-coded encoding. Two earlier iterations (the original encoding r20 with sixteen registers, and a prefix-coded encoding with sixteen registers, pdp64/16) were measured against it and superseded; they are no longer CPUs and their manuals, code and tests were removed (errata 122, 123). The git tags `pre-single-cpu` (last commit with their manuals and tools) and `pre-code-removal` (last commit with their code) keep them. The comparison by which the 32-register encoding was chosen is in `docs/encoding-work/`.

There is one manual, [`docs/manual/`](docs/manual/00-index.md), generated from `docs/manual-src/`: the body holds decided material, appendix H proposed, I deferred, J the open items. The manual describes the architecture as it is to be; the state of the implementations is in [`docs/implementation-status.md`](docs/implementation-status.md).

## 2. The repositories

Sibling directories of this repository; paths are relative to its root and every script takes them from environment variables.

| repository | path | holds |
|---|---|---|
| pdp64 | `.` | the grammars (`spec/`), `as64`, `ld64`, `sim64`, the shared core `common/`, the QEMU target sources (`qemu/`), the LLVM target sources (`llvm/`, frozen), tests, tools, all documents |
| pcc | `../pcc` | the portable C compiler with the pdp64 back end in `arch/pdp64`; the branch `chk-builtins` (on `single-pdp64`, pushed to pcc's remote, not merged into master) adds the run-time checks: the built-ins, `-xchecks` (every subscript of an array of known size), the pass that drops the provable checks, and the check instructions `ctcc`, `cteq` with `.chk` lines; `-xchk-call` gives the old call form; no vectorizer |
| v7unix-toolchain | `../facetlang/pdp11/v7unix-toolchain` | corpus tooling for the size measurements and the C test programs |
| QEMU source | `../qemu-src` | `git clone --depth 1 --branch v11.1.2 https://gitlab.com/qemu-project/qemu.git ../qemu-src`; the target is installed into it by `qemu/build.sh` |
| LLVM source | `../llvm-project` | `llvmorg-21.1.8`; never committed |

Rules the author set: `pdp64` goes to `origin main`, pcc to its own remote; never rewrite pushed history; one commit per feature; the commit message ends with the co-author trailer used throughout the history (see `git log`). Not in git, and rebuildable or re-fetchable: the corpora, the cross compilers, the QEMU and LLVM trees and their build trees, and the kernel source trees used by the surveys.

## 3. Rebuilding, in order

1. Host tools: a C compiler, `make`, `python3`, `ninja`, `cmake`, `git`, `pkg-config`, and for QEMU the glib and pixman development packages.
2. `tools/build-hbnf.sh` (the grammar compiler, in a rootless container), then `tools/check-all.sh`: builds `as64`, `ld64`, `sim64`, regenerates the generated files and runs the syntax, assembly, link, codec, drift, simulator, timing, relaxation and QEMU checks. It must pass before anything else is trusted.
3. The compiler: `PCC=../pcc tools/build-pcc.sh` (needs the pcc branch `single-pdp64`; it refuses a tree that still has the `PDP64_REGS32` switch), then `tools/pdp64test-all.sh` (107 programs under nine flag sets, 963 runs; `PDP64RUN=qemu` runs them under QEMU).
4. QEMU: `qemu/build.sh`, then `tools/check-qemu.sh`.
5. The manual: `python3 tools/mkmanual.py` writes `docs/manual/` from `docs/manual-src/`; `python3 tools/mkmanual.py --check` and `tools/check-manual-src.py` check it. Never edit a generated page.
6. LLVM: the sources in `llvm/` are frozen for the original encoding and do not build against the current assembler's output; see `llvm/README.md`.

Assembly, linking and running: `as64 x.s; ld64 -o x.out x.o; sim64 x.out`. There is no option that selects an encoding (`-m pdp64` is accepted and the only value). The grammar `spec/pdp64/pdp64.hbnf` is the source of truth for the encoding; the tables, the assembler's syntax tables and the manual's dictionary are generated from it (`spec/README.md` says how to change it).

## 4. The order of work (the author, 2026-11-10; errata 125, 159) and where it stands

1. **Resolve the open items**: the opcode-affecting ones were settled enough to run the optimiser (the check instructions, the vector instructions in principle); the rest of appendix J stays open (the ledger has the list).
2. **Re-run the encoding optimiser**: **done 2026-11-17** (errata 158, 159, 160). `tools/encopt/export.py --corpus DIR` (DIR: pcc's assembly of the 841 files, compiled with `-xchecks`), `encopt`, again with `--prev` until the selection stops changing, then `export.py --corpus DIR --write-grammar RESULT --grammar-out OUT`. The model of the optimiser is `docs/codegen-data/encoding/cat.py`.
3. **Update the grammar**: **done** (159 forms, 217 leaves, no reserve, every opcode renumbered; 1 first parcel in 65,536 is illegal). The new instructions: `ct<cc>`, `cteq`/`ctne`, `chk2`, and the vector `check` (16) of `spec/pdp64-system.hbnf`. The vector instructions are not in the grammar yet.
4. **Regenerate**: **done** for the assembler tables, the tests (`mk_vectors.py`, `mk_asm_tests.py`, `mk_ld_tests.py`), the manual (`python3 tools/mkmanual.py`), `tests/enc/generated.sha256` (`tools/check-grammar-enc.sh --update`), the QEMU copies (`qemu/sync.sh`, then `qemu/build.sh -j 2`, about ten minutes on two cores). **Not done:** the pcc headers beyond the instruction names, and the LLVM tables.
5. **Port to the new encoding**: `as64`, `ld64`, `sim64`, QEMU and pcc are on the new encoding and green. **The LLVM back end is next and is to become the standard compiler for development (errata 159, R453)**: its machine-code layer (`llvm/`) still encodes the original encoding (milestone M1, frozen since errata 122), so the order is: regenerate its tables from the grammar (errata 137), port the machine-code layer and its oracle against `as64`, then a target machine and a code generator (`llc`, `clang`). The machine here has two cores and 3 GB of memory: a full clang build needs a larger one (R217). Vectorization will come from LLVM's vectorizers; pcc has none. The `vec` block maps to LLVM's explicit-vector-length loops (`docs/encoding-work/vec-isa.md` section 5 says how it is thought to).

The pcc RISC-V back end is **a separate project**, not any part of this one (the author, 2026-11-10).

After that: OpenBSD reachable over ssh (the roadmap is [`docs/roadmap.md`](docs/roadmap.md); the first operating system is OpenBSD, Unix/32V the fallback). An FFmpeg and dav1d backend (a capability bit for the vector unit and hand-written vector versions of the hot functions) is expected with the OpenBSD port.

## 5. State of the pieces

| piece | state |
|---|---|
| grammar, `as64`, `ld64` (with relaxation and the new section `__bug_table`), `sim64` | working on the new encoding; `as64` writes the check instructions and a record of the table of check sites (Linux's `struct bug_entry`, 12 bytes, relative pointers) for each; `ld64` puts the table read-only after `.text` and defines `__start___bug_table` and `__stop___bug_table`; the atomics and some cryptographic words are not implemented in the executor |
| pcc back end | working on the branch `chk-builtins`; emits the check instructions with `-xchecks`; the suite passes (93 programs under three flag sets) |
| QEMU | executes the new encoding and the check instructions (vector 16); the machine tests pass (56 run, 0 failed, 4 skipped) |
| LLVM | machine-code layer for the original encoding, frozen; the port is next (section 4); no code generator |
| vector, GEMM and accelerator operations | **decided to be added** (errata 157): the `vec` block with hidden vector registers and the operations of `docs/encoding-work/vec-isa.md`; the tile and the whole-GEMM instruction are kept under study; the decision aids are `vec-cost-benefit.md` (the table), `vec-forms.md`, `gemm-forms.md`, `vec-gates.md` (the gate counts: the yes and likely operations add 195,000 to 280,000 gates to a scalar core of 220,000 to 310,000, counted with yosys by `tools/gates`); not in the grammar, the assembler, `sim64` or the compiler |
| GPU | decided (errata 154) to use unified memory, a fast-VRAM region to be determined; no design yet |
| the manual | complete in structure; the entries `CT` and `CHK2` and the vector `check` are in; chapters 1, 7, 8 and 10 are being rewritten for the PDP-11 reader |
| tests | `tools/check-all.sh` is green on the new encoding; the simulator tests `checks.s` and `sys-check.S` cover the check instructions |

The detailed account, by chapter and statement, is [`docs/implementation-status.md`](docs/implementation-status.md) (not yet brought to the new encoding).

## 6. Working rules

* **The author's decisions win**; the more recent beats the older. Each decision is recorded with his words (the register) and, if it changes a document, an erratum. When he says "looks good" or "I like it" that is a decision in favour. A decision is a decision with details pending; do not drop it because the details are not written.
* **Documents follow the ledger.** Every document is current, a dated record (with a banner) or history (with a banner); the map is `docs/README.md`. No local user names, host names, absolute paths or tool or session ids in documents. No opcode numbers or bit layouts in prose: point to the generated tables.
* The grammars are the single source of truth; every number is stated once and generated downstream; semantics once in `common/pdp64exec.c`.
* The manual describes the architecture as it is to be, not as it is.
* Web research uses the browser skill. Politeness: wait at least ten seconds between page loads on any host, more on some; stop on a captcha; after a block back off with a growing delay.
* Do not delete the author's files without asking; keep `tools/check-all.sh` green.
* Records of studies are in `docs/encoding-work/` (the map is its `README.md`): `bounds-check-isas.md`, `loongarch.md`, `check-instructions.md` (the check instructions and the table), `vector-study.md`, `vec-forms.md`, `gemm-forms.md`, `vec-cost-benefit.md`, `vec-gates.md`, `vec-isa.md`; the numbers are in `docs/encoding-work/arch-data/`, the scripts in `tools/arch-compare/` and `tools/gates/`. The decision register is `docs/decision-register.md` (R453 is the last), the errata `docs/errata.md` (160 is the last).
* A permission block from the assistant's tool is not a refusal by the author: say so plainly and ask, never write "not allowed" in a document.

## 7. What is open, in the order it is needed

1. The LLVM port (section 4, step 5) and the machine to build it on.
2. The vector instructions in the grammar, `as64`, `sim64`, QEMU and the test suite; the rule for a block that holds accumulators across an interrupt (`vec-isa.md` section 4); a vectorizer through LLVM.
3. The cost-benefit analysis of the open operations (scatter-add, predication, number formats, the vector exponential, the tile, the whole-GEMM unit): dynamic counts need a simulator that runs them; the table says what is measured and what is estimated.
4. About 17,000 instructions in the corpus compiled with checks that are not the checks (copies of the index and loaded bounds, errata 160): not analysed.
5. The kernel's handler of vector 16 and the table of check sites; `docs/encoding-work/check-instructions.md` has the format and the trap.
6. The chronicle archive: `tools/chronicle-sync` of the ai-conversations project brings both machines' logs and databases in step; it was run in full on 2026-11-18 (both databases then held the same threads and social items) and is to be run again after more work.
