# Handoff: current working notes

[← pdp64 index](README.md)

Brought up to date 2026-11-10 for the single-CPU state. It says what exists, where it lives, how to rebuild it, the order of the work that is next, and what the working rules are. The source of truth for decisions is [`docs/decisions-and-status.md`](docs/decisions-and-status.md) (the ledger), with the author's words in [`docs/decision-register.md`](docs/decision-register.md) and the numbered decisions in [`docs/errata.md`](docs/errata.md); the map of all documents is [`docs/README.md`](docs/README.md). Where this file disagrees with them, they win.

## 1. What the project is now

One CPU, the **pdp64**: thirty-two registers, prefix-coded encoding. Two earlier iterations (the original encoding r20 with sixteen registers, and a prefix-coded encoding with sixteen registers, pdp64/16) were measured against it and superseded; they are no longer CPUs and their manuals, code and tests were removed (errata 122, 123). The git tags `pre-single-cpu` (last commit with their manuals and tools) and `pre-code-removal` (last commit with their code) keep them. The comparison by which the 32-register encoding was chosen is in `docs/encoding-work/`.

There is one manual, [`docs/manual/`](docs/manual/00-index.md), generated from `docs/manual-src/`: the body holds decided material, appendix H proposed, I deferred, J the open items. The manual describes the architecture as it is to be; the state of the implementations is in [`docs/implementation-status.md`](docs/implementation-status.md).

## 2. The repositories

Sibling directories of this repository; paths are relative to its root and every script takes them from environment variables.

| repository | path | holds |
|---|---|---|
| pdp64 | `.` | the grammars (`spec/`), `as64`, `ld64`, `sim64`, the shared core `common/`, the QEMU target sources (`qemu/`), the LLVM target sources (`llvm/`, frozen), tests, tools, all documents |
| pcc | `../pcc` | the portable C compiler with the pdp64 back end in `arch/pdp64`; the branch `single-pdp64` builds only the 32-register target (not yet merged into pcc's master) |
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

## 4. The order of work (the author, 2026-11-10; errata 125)

1. **Resolve the open items**, starting with those that affect the opcodes (appendix J of the manual; the ledger lists them). The status and decisions document is to get a form in which the author can choose options and type questions, for a quick feedback loop (`tools/feedback`, `docs/feedback`).
2. **Re-run the encoding optimiser** once the decisions that affect the opcodes are made and the mnemonics are settled. The optimiser (`tools/encopt`, version 1.1, in C) has no code-space reserve and three objectives, static, fetch and exec (errata 136); the choice of objective for the real run is the author's.
3. **Update the grammar** (`spec/pdp64/pdp64.hbnf`, and the mnemonic vocabulary), because it generates the assembler, the tables for chapter 9 of the manual and the compiler's headers.
4. **Regenerate** the assembler tables, the manual, the pcc headers and the tables of the LLVM back end (errata 137).
5. **Port to the new encoding**: the LLVM back end, QEMU, `as64`, pcc and `sim64`. Until then `sim64` and pcc are kept current with the present encoding, and they, and the LLVM sources, will change when the opcodes do.

The pcc RISC-V back end is **a separate project**, not any part of this one (the author, 2026-11-10).

After that: an LLVM code generator, then OpenBSD reachable over ssh (the roadmap is [`docs/roadmap.md`](docs/roadmap.md); the first operating system is OpenBSD, Unix/32V the fallback).

## 5. State of the pieces

| piece | state |
|---|---|
| grammar, `as64`, `ld64` (with relaxation), `sim64` (with the timing model) | working for the pdp64; the atomics and some cryptographic words are not implemented in the executor; the five words `ABS`, `MIN`, `MINU`, `MAX`, `MAXU` are still native in the tools though the decision makes them aliases |
| pcc back end | working on the branch `single-pdp64`; uses the four fused pairs, not yet the other new instructions |
| QEMU | executes the pdp64 encoding; machine tests and the C programs pass; target is to reach parity with `sim64` |
| LLVM | machine-code layer for the original encoding, frozen; port open; no code generator |
| the manual | complete in structure; chapters 1, 7, 8 and 10 are being rewritten for the PDP-11 reader |
| tests | after the removal, some simulator tests that wrote r20 words are gone and their cases are not yet rewritten (the list is in errata 123) |

The detailed account, by chapter and statement, is [`docs/implementation-status.md`](docs/implementation-status.md).

## 6. Working rules

* **The author's decisions win**; the more recent beats the older. Each decision is recorded with his words (the register) and, if it changes a document, an erratum. When he says "looks good" or "I like it" that is a decision in favour. A decision is a decision with details pending; do not drop it because the details are not written.
* **Documents follow the ledger.** Every document is current, a dated record (with a banner) or history (with a banner); the map is `docs/README.md`. No local user names, host names, absolute paths or tool or session ids in documents. No opcode numbers or bit layouts in prose: point to the generated tables.
* The grammars are the single source of truth; every number is stated once and generated downstream; semantics once in `common/pdp64exec.c`.
* The manual describes the architecture as it is to be, not as it is.
* Web research uses the browser skill. Politeness: wait at least ten seconds between page loads on any host, more on some; stop on a captcha; after a block back off with a growing delay.
* Do not delete the author's files without asking; keep `tools/check-all.sh` green.
