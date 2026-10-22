# Handoff: moving the pdp64 work to a larger machine

[← pdp64 index](README.md)

Written 2026-10-22, brought up to date after errata 40 and the push of that day. It says what exists, where it lives, what is not in git, how to rebuild everything and in what order, what is half-done, and what is
waiting on a decision. The small machine this was built on has 3.9 GB of RAM and 2 cores; that was the main limit, and the build commands below give the
larger-machine settings.

## 1. The repositories

| repository | path | remote | branch | holds |
|---|---|---|---|---|
| pdp64 | `~/claude/pdp64` | `origin` git@github.com:moebiusV/pdp64.git | `main` | the architecture: grammars (`spec/*.hbnf`), `as64`, `ld64`, `sim64`, shared core `common/`, QEMU target sources (`qemu/`), LLVM target sources (`llvm/`), tests, tools, all documents |
| pcc | `~/claude/pcc` | `mine` git@github.com:moebiusV/pcc.git (and `origin`, the upstream https://github.com/PortableCC/pcc.git) | `master` | the portable C compiler with the pdp64 back end in `arch/pdp64` |
| v7unix-toolchain | `~/claude/facetlang/pdp11/v7unix-toolchain` | `origin` git@github.com:moebiusV/v7unix-toolchain.git | `main` | the corpus tooling (`tools/corpus.py`, `corpus-build.sh`) the size measurements use; nothing pdp64-specific is pending in it |

Push rules the author set: `pdp64` goes to `origin main`, `pcc` to `mine master`; never rewrite pushed history; one commit per feature; commit as
`git -c user.name="David Walther" -c user.email=tederific@gmail.com`; message ends with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

**State when this was last updated:** everything verified was pushed (`pdp64` `origin/main`, `pcc` `mine/master`), checked by a clean-clone `tools/check-all.sh` of the committed HEAD; the head commits are listed in section 9. **Before leaving the old machine:** run `git status` and `git log --oneline origin/main..HEAD` in `pdp64`, and `git log --oneline mine/master..HEAD` in `pcc`; push what
is committed and verified (the rule is a clean-clone `tools/check-all.sh` of the committed HEAD first). Uncommitted files at the time of writing: see section 6.

## 2. What is NOT in git (copy it, or rebuild it)

| what | where | size | how to get it on the new machine |
|---|---|---|---|
| benchmark corpora (sources and `.dl` downloads) | `~/claude/corpora` | 3.6 GB | rebuildable: `corpora/*/ *.dl` are downloads; `v7unix-toolchain/tools/corpus-build.sh amd64 aarch64 i386` builds the references; or `rsync` the directory |
| gcc cross compilers (vax-netbsdelf, pdp11-aout) | `~/claude/corpora/gcc-cross/prefix` | part of the above | rsync (slow to rebuild) |
| QEMU source (v11.1.2) | `~/claude/qemu-src` | 217 MB | `git clone --depth 1 --branch v11.1.2 https://gitlab.com/qemu-project/qemu.git ~/claude/qemu-src` |
| LLVM source (llvmorg-21.1.8) | `~/claude/llvm-project` | 2.5 GB | `git clone --depth 1 --branch llvmorg-21.1.8 https://github.com/llvm/llvm-project.git ~/claude/llvm-project` (the target is installed into it by `llvm/install.sh`; the tree itself is never committed) |
| build trees | `~/claude/qemu-build`, `~/claude/llvm-build` | 172 MB, 70 MB | rebuild |
| size reference numbers (gcc and clang `-Os`, our amd64 pcc) | `/tmp/p64opt/refs-gcc-clang-amd64.json` and `docs/codegen-data/refs-gcc-clang-amd64.csv` | small | the CSV is in git; the JSON is a scratch file that `tools/pdp64size.py` can regenerate with `TOOLCHAIN=` set |
| scratch results of the compiler runs | `/tmp/p64opt/*` | | disposable; lost on reboot; every number in the documents says how it was measured |
| kernel sources for the survey | `~/claude/kernel-src` (sparse, 328 MB), `~/claude/kernel-history` (2.9 GB, partial blobless clones, **incomplete: the clones were killed**) | | re-clone with `tools/kernelasm.py` and `tools/kernelpain.py` (they print the clone commands); never committed |
| browser data | `~/claude/browse-output` (28 GB: scraped data and `facebook.db`, the browse queue) | 28 GB | **the author's own data, not part of this project**; only the browser skill is needed on the new machine (`~/.claude/skills/browser.md`, `~/claude/browse-output/browsectl`) |

## 3. Rebuilding, in order

1. Clone the three repositories (section 1) and the corpora; install the host tools: a C compiler, `make`, `python3`, `ninja`, `cmake`, `clang` 21 (the LLVM work
   needs a recent clang or gcc and, for speed, `lld`), `git`, `pkg-config`, `libglib2.0-dev`, `libpixman-1-dev` for QEMU.
2. `cd ~/claude/pdp64 && tools/build-hbnf.sh` (the grammar tool), then `tools/check-all.sh`. This builds `as64`, `ld64`, `sim64`, regenerates the headers, runs the
   format, syntax, drift, link, simulator and (if present) QEMU tests, and the generated-file freshness checks. **It must pass before anything else is trusted.**
3. The C compiler: `tools/build-pcc.sh` (output `build/pcc/ccom`), then the C tests: `PDP64CCOM=$HOME/claude/pdp64/build/pcc/ccom tools/pdp64test-all.sh`
   (510 tests under `sim64`; the same with `PDP64RUN=qemu` once QEMU is built).
4. QEMU: `qemu/build.sh -j 8` (installs the target into `~/claude/qemu-src`, configures, builds `~/claude/qemu-build/qemu-system-pdp64`). Then `tools/check-qemu.sh`.
5. LLVM: `LLVM_USE_LINKER=lld TARGETS="llvm-tblgen llvm-mc llvm-objdump llvm-readobj llvm-objcopy" llvm/build.sh -j 16`, then `llvm/check.sh`. On the small machine this took
   about 12 minutes for the first two tools and needed 440 MB; `llvm-objdump` and `llvm-readobj` (389 more steps) were never built and are untested. Details: `docs/pdp64-system-architecture.md`
   section 14.
6. Sizes: `tools/pdp64size.sh` (needs `TOOLCHAIN=~/claude/facetlang/pdp11/v7unix-toolchain` and the corpus builds). The last verified result is in section 5.

## 4. The state of the work

| piece | state |
|---|---|
| ISA, grammars, `as64`, `ld64`, `sim64` | working; the numbers (opcodes, fields, page-2 table) come from `spec/*.hbnf`; semantics once in `common/pdp64exec.c` |
| pcc back end | working; 510 C tests pass under `sim64` and QEMU; sizes in section 5 |
| QEMU machines | working: the user-mode machine and the kernel-mode machine of System v1 (exceptions, interrupts with priority 7 on entry, MMU walker, timer, console); 43 sim64 programs and 52 QEMU tests pass; the mini-kernel test and the dynamic `pushx`/`popx` measurement exist or are queued (section 6) |
| LLVM back end | milestone 1 (assembler, disassembler, ELF object writer, checked against `as64`) done and verified against the ISA of the morning of 2026-10-22; `isync`/`hint` are in the generator and the generated files (committed, fresh) but **`llvm-mc` has not been rebuilt and `llvm/check.sh` not rerun since errata 39**: that re-check is the next job and goes into section 14.8 of the system architecture document; no code generator yet |
| System v1 specification | accepted (`pdp64-system-architecture.md` section 15) |
| Errata 39 (flag cleanup, `ISYNC`, `HINT`) | done, verified and pushed (compiler, core, grammar, tests, invariant checker `tools/check-flaginv.sh`) |
| Errata 40 (priority 7 on every exception and interrupt entry) | decided; documentation committed; core, QEMU and tests committed (`06e4a05`); see section 9 for whether it is pushed |
| operating system | planned: first a 3BSD port (the licence of the 3BSD sources is **unestablished**), OpenBSD later if the LLVM back end proves easy; nothing written |

## 5. Numbers (827 fair-corpus files, bytes = text + rodata + data)

| point | instructions | bytes | against `gcc -Os` | against `clang -Os` |
|---|---|---|---|---|
| before errata 39 | 334,056 | 1,499,530 | 0.998 | 0.931 |
| after the compiler half of errata 39 | 335,877 | 1,505,382 | 1.002 | 0.935 |

Measured by `tools/pdp64size.sh`; references in `docs/codegen-data/`. The flag-reliance checker `tools/flagreliance.py` reports 0 sites on the new output, 2,908 on the old.

## 6. What is half-done

* **Uncommitted changes** in `~/claude/pdp64` (partial output of the two stopped survey and comparison agents, deliberately not committed): `tools/archcmp.py`, `tools/kernelasm.py`, `tools/kernelpain.py`, and CSVs under `docs/codegen-data/archcmp/` and `docs/codegen-data/kernelasm/`. They are
  work in progress: finish or discard them; do not commit them unchecked. In `~/claude/pcc`: only an untracked `pdp64-docs-2026-10-21.tar`.
* **Stopped agents** (their committed work is in git; their briefs are only in the session transcript): the cross-architecture comparison (`docs/arch-comparison.md` is not written; `tools/archcmp.py` exists; the totals file from a 13-file trial must not be quoted), the kernel-assembly survey (`docs/kernel-asm-survey.md` and `tools/kernelasm.py`
  partly written), the kernel pain-points research (`docs/kernel-pain-points.md` not written; Phase 1 had only begun cloning, and its clone directory `~/claude/kernel-history` is incomplete). Restart each with a fresh agent, one at a time on a small machine. **The LLVM re-check** (section 4) is queued first.
* **Known open spec items:** the `DMW` format and `MMUCTL`; bus atomics; `pushm`/`popm`/`pushx`/`popx` aborts can leave earlier stores; block copy more than one byte per step against the sequential-consistency promise; the architecture-text items of the readiness review still to be written into the ISA.
* **Web research** (the kernel mailing lists, the 3BSD sources and licence, the handbooks listed in `docs/fact-check-2026-10-22.md` section 12) uses the browser skill, not `WebFetch`. The author wants to be told
  before `browse.py` is started because it opens a visible window; never `kill` it, use `./browsectl quit`. Chrome was found left running after a quit, which needs a WSL shutdown to clear.

## 7. Decisions taken, and decisions open

Decided (all in `docs/errata.md`, items 1 to 40): the ISA (three parcels, page 2, `cbCC` forms, `rori32`, `=K` literal pool, `pushx`/`popx`, FP16), the ABI (`docs/abi.md`), System v1 (register-based exception entry,
vector table at `VBR + 8*vector`, software accessed/dirty bits, three-level page tables, MMUCTL, eight priority levels), devices as eight memory-mapped registers plus DMA, the first OS being a 3BSD port, and the
flag cleanup of errata 39: flags are two groups (`C` and `{N,Z,V}`), `cbCC` and moves, loads and stores write no flags, shifts write the same flags for every count, `mscn` writes all four, rotates and `dshr`
write no flags, `asl` keeps `V = N xor C`; new `ISYNC` and `HINT`; and errata 40: every exception and interrupt enters at priority 7 (a PDP-11 throwback, unverified against the handbook).

Open: the `DMW` register format and whether `MMUCTL` should exist at all (system design document); the Q64 bus transactions and the atomics question (`pdp64-q64-bus.md`); the 3BSD licence; the LLVM milestones
(selection, calling convention, tied operands, clang); the architecture-text items of the readiness review (`pdp64-ooo-readiness.md` section 2) still to be written into the ISA; out-of-order readiness is a design
aim while the FPGA and ASIC stay in order.

## 8. Rules of the house

* The grammars are the single source of truth; every number is stated once in an enum rule and generated downstream; semantics once in `common/pdp64exec.c`.
* The README is the only index of documents; originals in `docs/orig/` are never edited; never edit another agent's files without telling it.
* Do not `kill` `browse.py`; do not unset `VAX780`; do not delete the author's files without asking; `tools/check-all.sh` stays green.
* On a small machine: one heavy job at a time, `nice -n 10`, `ninja -j1`; an exit 137 is the system killing a process, not a test failure.

## 9. Commits at the time of writing

On 2026-10-22, after a clean-clone `tools/check-all.sh` of the committed HEAD (exit 0; sim64 43 of 43, QEMU 52 run, 0 failed, 3 skipped; C suite 516 of 516 under sim64 and QEMU): `pdp64` `main` = `06e4a05` plus the commit that adds this line (see `git log -1`), `pcc` `master` = `d44d98a4`. Both pushed.
