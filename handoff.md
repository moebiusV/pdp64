# Handoff: moving the pdp64 work to a larger machine

[← pdp64 index](README.md)

Written 2026-10-22, brought up to date after errata 63 (the manual, the instruction entries in the chapters, and the device and bus decisions of the day). It says what exists, where it lives, what is not in git, how to rebuild everything and in what order, what is half-done, and what is
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
| the full TUHS Unix source archive (V7, 32V, 3BSD, 4.xBSD, 2.11BSD, Ultrix, old NetBSD/OpenBSD/FreeBSD, Linux 0.96 and 2.6.33) | `~/claude/facetlang/unixtree` | 2.2 GB | rsync it, or fetch from tuhs.org; used as the source for claims about the PDP-11 and VAX Unix kernels |
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
| the manual | the streamlined set `docs/streamlined/` (ten chapters, five appendices) with the generated instruction entries inside chapters 6, 7 and 9, the reference tables `docs/streamlined/dictionary/` and the SVG figures `docs/streamlined/figures/` are written and published at https://moebiusv.github.io/pdp64/ ; see section 10 |
| bus and devices (errata 49 to 51, 58 to 61) | decided on paper only: the bus is a device (registers ID, CONTROL, STATUS, SLOT, INFO, MAPADDR, MAPCTL, EVENT), the common device registers and 32-byte descriptor with an ownership bit, storage interfaces (SCSI, ATA, SATA, NVMe) on the same pattern, a device window of at least eight registers, the GPT wrapper, boot offsets; bit 39 of the physical address selects device space (P19, errata 60: **not yet in the QEMU memory map or `spec/pdp64-system.hbnf`**) |
| vector, graphics and AI work (errata 59) | decided: no SIMD register file; memory-mapped devices (graphics terminal, LB64 and companions, array languages); the register-level C64 devices are a stub awaiting the author's documents |
| operating system | decided (errata 41): OpenBSD first, through the LLVM back end (the critical path: selection, calling convention, clang; needs the bigger machine); Unix/32V with pcc is the fallback if OpenBSD proves too hard; 3BSD dropped; nothing written |

**The goal before silicon (errata 52):** assembler, linker, LLVM compiler back end, emulator, and an OpenBSD port that can be logged into with ssh; the roadmap with the order of work is [`docs/roadmap.md`](docs/roadmap.md).

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
* **Running when this was written:** the kernel pain-points research agent, round 2 (`docs/kernel-pain-points.md` and its companions were delivered and pushed in round 1; round 2 adds more primary sources, the cost of constant-time modes, what operating-system people asked vendors for, and boot pain points). When it reports: check that no browser is left (`pgrep -af 'chrome|browse.py|uc_driver'`), that no clone is left in `~/claude/kernel-msgs`, that no request to lwn.net was made after the block, spot-check its claims, link its documents from the manual, run a clean-clone `tools/check-all.sh`, then push.
* **Known open spec items:** the `DMW` format and `MMUCTL`; bus atomics; `pushm`/`popm`/`pushx`/`popx` aborts can leave earlier stores; block copy more than one byte per step against the sequential-consistency promise; the architecture-text items of the readiness review still to be written into the ISA.
* **Web research** (the kernel mailing lists, the handbooks listed in `docs/fact-check-2026-10-22.md` section 12) uses the browser skill, not `WebFetch`. The author wants to be told
  before `browse.py` is started because it opens a visible window; never `kill` it, use `./browsectl quit`. Chrome was found left running after a quit, which needs a WSL shutdown to clear (seen again after the verification run of 2026-10-22: ten chrome processes outlived `browsectl quit`, and `browse.py` keeps a defunct chrome child from its start).

## 7. Decisions taken, and decisions open

Decided (all in `docs/errata.md`, items 1 to 62; items 41 to 62 are summarised after this paragraph): the ISA (three parcels, page 2, `cbCC` forms, `rori32`, `=K` literal pool, `pushx`/`popx`, FP16), the ABI (`docs/abi.md`), System v1 (register-based exception entry,
vector table at `VBR + 8*vector`, software accessed/dirty bits, three-level page tables, MMUCTL, eight priority levels), devices as eight memory-mapped registers plus DMA, the OS order (errata 41), and the
flag cleanup of errata 39: flags are two groups (`C` and `{N,Z,V}`), `cbCC` and moves, loads and stores write no flags, shifts write the same flags for every count, `mscn` writes all four, rotates and `dshr`
write no flags, `asl` keeps `V = N xor C`; new `ISYNC` and `HINT`; errata 41: the OS order is OpenBSD first, 32V fallback, 3BSD dropped; and errata 40: every exception and interrupt enters at priority 7 (a PDP-11 throwback, unverified against the handbook).

Errata 41 to 62 in one line each: 41 OpenBSD first; 42 all rules soft; 43 the user-memory guard bit `UA` (`STUA`, `CLUA`; PSW bit 12); 44 `MMUCTL` stays, `DMW` deferred; 45 atomics are a monitor; 46 `long double` is `double` and the ABI is versioned; 47 boot software open source; 48 BSD 2-clause licence for everything; 49 the bus is a device; 50 a GPT wrapper around the BSD label; 51 majority offsets (label in sector 1, 8 KB boot area, superblock at 8192); 52 the goal before silicon; 53 the manual is the primary deliverable; 54 the manual is primary; 55 its published form; 56 aphorism then commentary; 57 the reference layout; 58 every decision states its impact on the kernel, the compiler and the hardware; 59 vector, graphics and AI work go to memory-mapped devices (APL and K); 60 bit 39 selects device space, and the book order; 61 storage interfaces share the device pattern and eight registers is a minimum; 62 the instruction dictionary, generated, with atomics in the SMP chapter and system instructions and faults in the kernel chapter. The decisions still open are in [`docs/decisions-pending.md`](docs/decisions-pending.md) and appendix B of the manual.

Open: the operand placement of the atomic instructions (the ISA text fixes only their sub-opcodes); the register-level definition of the C64-derived devices; the `DMW` register format (deferred); the Q64 bus transactions and the atomics question (`pdp64-q64-bus.md`); the LLVM milestones
(selection, calling convention, tied operands, clang); the architecture-text items of the readiness review (`pdp64-ooo-readiness.md` section 2) still to be written into the ISA; out-of-order readiness is a design
aim while the FPGA and ASIC stay in order.

## 8. Rules of the house

* **Agents:** one agent at a time on this machine (3.9 GB); stop an agent that eats memory. "Push everything when the agent reports", after a clean-clone `tools/check-all.sh`. Web access only through the browser skill with the politeness rules (at least 10 seconds between page loads, one directive at a time, stop on a captcha until the author has passed it, no requests to lwn.net, archived copies through the Wayback Machine allowed).
* **Blocks (2026-10-23):** archive.org / the Wayback Machine blocked us for excessive requests today and lwn.net blocked us on 2026-10-22. No direct requests to lwn.net (use Wayback copies). After any 429, 503 or block back off and retry on a timer with a growing delay (at least 5 minutes, doubled each time; the author confirmed retries are fine and a Wayback block cleared after a short wait); use at least 60 seconds between Wayback requests; the 10-second rule is a floor, not a licence. To stop an agent use TaskStop and `./browsectl quit` at once (a message is read only at the agent's next tool round). The request counts by host are in the `queue` table of `~/claude/browse-output/facebook.db`.
* **Statements of the author supersede mine** unless they later agreed with me; the recent beats the old. Record each decision as an erratum with the author's words.

* **The author's principles, in order:** (1) code size; (2) easy recoverability, meaning fewer possible errors and an easier recovery path, so less recovery code; (3) speed and efficiency through fewer gates and tighter hot loops, by careful instruction choice. All rules are soft (errata 42). The README states them and gives the examples. Judge every option against them.

* The grammars are the single source of truth; every number is stated once in an enum rule and generated downstream; semantics once in `common/pdp64exec.c`.
* The README is the only index of documents; originals in `docs/orig/` are never edited; never edit another agent's files without telling it.
* Do not `kill` `browse.py`; do not unset `VAX780`; do not delete the author's files without asking; `tools/check-all.sh` stays green.
* On a small machine: one heavy job at a time, `nice -n 10`, `ninja -j1`; an exit 137 is the system killing a process, not a test failure.

## 9. Commits at the time of writing

On 2026-10-22 (later): `pdp64` `main` = `c3c794f` (documentation only since the last clean-clone `tools/check-all.sh`, which was at the commit that added the licence; the documentation commits since touch no code except `tools/mkmanual.py`, `tools/manual/` and one line of `tools/check-all.sh`, and `python3 tools/mkmanual.py --check` passes), `pcc` `master` = `d44d98a4`. Uncommitted and not mine to commit unchecked: `tools/archcmp.py` and the files under `docs/codegen-data/archcmp/` (the stopped comparison agent), `chat02.txt` (the author's). The earlier line:

On 2026-10-22, after a clean-clone `tools/check-all.sh` of the committed HEAD (exit 0; sim64 43 of 43, QEMU 52 run, 0 failed, 3 skipped; C suite 516 of 516 under sim64 and QEMU): `pdp64` `main` = `06e4a05` plus the commit that adds this line (see `git log -1`), `pcc` `master` = `d44d98a4`. Both pushed.

## 10. The manual

The manual is the directory [`docs/streamlined/`](docs/streamlined/00-index.md), published at https://moebiusv.github.io/pdp64/docs/streamlined/00-index.html (the legacy GitHub Pages build; `.md` is served as `.html`; a push shows after one or two minutes). Order of the chapters (set by the author): introduction, bus, graphics, boot, device drivers, kernel (modes, exceptions, memory management, system instructions, faults), multiple processors (including the atomic instructions), vectors and AI, the instruction set, conclusion; then the instruction reference tables, then appendices A (improvements), B (decisions pending), C (glossary), D (ABI), E (assembly language), F (the evidence documents).

* **Form of a section:** numbered statements (*(D)* decided, *(P)* proposed, *(S)* stub, no tag as built), then a *Commentary* with the *Precedent*, *Trade-offs*, *Improvements*, *Benefits*, *Modern comparables*, *Use* where useful, and an **Impact** line (*Kernel*, *Compiler*, *Hardware*; errata 58).
* **The stories** (*Why it is here*, errata 64) are `tools/manual/isa_stories.py`, keyed by entry id; they are written from the record only (the author's messages in the transcript `~/.claude-opusplan/projects/.../d4ecc0bd-....jsonl`, `chat01.txt`, the revision changelogs, the errata, the measurements), and a new instruction that is not common needs one.
* **The instruction entries** are generated *into the chapters*, between `<!-- entries:N.N -->` markers at the end of sections 9.6 to 9.12, 7.12 and 6.7 (never edit between the markers); `tools/mkmanual.py` also writes the reference tables `docs/streamlined/dictionary/` and the bit-layout figures `docs/streamlined/figures/*.svg` from `spec/pdp64-mnemonics.hbnf` and `spec/pdp64-system.hbnf` (the numbers) and `tools/manual/isa_*.py` (the words); never edit the generated pages; `python3 tools/mkmanual.py --check` is part of `tools/check-all.sh`. Entries are marked implemented or not by reading `common/pdp64exec.c`.
* **Known gaps:** the C64 devices (stub, section 3.2 of the graphics chapter); the atomic instructions, the memory escape (`MESC`), the UTF-8 instructions, `MVAL` and `FCLASS32` are specified but not implemented in the executor; `STUA` and `CLUA` are not in the grammar; the book form is `book/pdp64-manual.pdf`, tracked in git, built by `tools/mkbook.sh` (buildabook, from its repository `~/claude/buildabook`, builds without hbnf since 2026-10-23, plus Typst and `cmarker` 0.1.8; `book/README.md`): **the author builds and commits the PDF himself, elsewhere (instruction of 2026-10-23): do not rebuild or commit `book/pdp64-manual.pdf` from a working session; the copy in git can be older than the manual**; the README and the manual's index link to it.
* **Checks to run after editing the manual:** every relative link resolves; chapter and section references match the headings (the glossary and the introduction's evidence table cite sections by number); `python3 tools/mkmanual.py --check`.
