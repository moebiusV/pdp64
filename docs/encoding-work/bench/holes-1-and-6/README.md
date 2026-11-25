# Holes 1 and 6: programs and raw results

*A dated record (2026-11-25). The study is `docs/encoding-work/bench-holes-1-and-6.md`; this directory holds what produced its numbers, so that they can be run again. Nothing here is part of the architecture. The earlier gate models are in `../holes-gates/`; the files `gates/h1.v` and `gates/h6.v` here are copies of them, so that the references can be reproduced from this directory alone.*

Tools needed: the pdp64 checkout built (`build/as64`, `build/ld64`, `build/sim64`, `build/pcc/ccom`), `yosys` 0.52, Python 3, a C compiler and, for part B, `clang` and the LLVM back end's `llc` (`../llvm-build/bin/llc`). Part A also needs a **scratch** build of the QEMU model with the hook (below); the installed model and the repositories are never changed.

## `part-a/` hole 1 (stale translations after a guest reset in place)

* `scratch-trace-hook.patch`: the change that turns a copy of the QEMU target (`qemu-pdp64`, `target-pdp64`) into the tracing model: `mmu.c`, `op_helper.c`, `cpu.h` and the generated copy of the executor (`gen/pdp64exec.c`). Apply it to a **copy** of the target sources in a scratch QEMU tree and build there (`qemu-pdp64/build.sh` with `QEMU_SRC` and `QEMU_BUILD` pointing at scratch directories). With the environment variable `PDP64_TLOG=FILE` set the model writes the trace; without it the model behaves as before. It is a measuring tool, not part of the model.
* `runtrace.sh`: assembles one of the hypervisor tests and runs it on the scratch model, writing `NAME.trace`.
* `traces/`: the six traces the study replays (`hv-first`, `hv-stage2`, `hv-timer`, `hv-vtimer`, `sec-hv-reset-inplace`, `sec-hv-reset-mmuctl`); the format is described at the top of `replay.py`.
* `replay.py`: plays a trace under today's rule, flush at every entry, the arena with its flag, and the directory of walked table pages (sizes and the two rules for a full directory are options); reports walks, table reads (logged and at the manual's full depth), stale translations served, discards (true and false) and evictions.
* `synth.py`: generates the synthetic trace of a guest that churns its stage-2 tables.
* `run_all.py TRACE_DIR OUT_DIR`: runs both and writes the tables.
* `results/`: `recorded.txt` and `recorded.json` (the six traces, translation buffer unbounded and of 32 entries), `synthetic.txt` and `synthetic.json` (R = 4 to 64 regions, edits before every 1st, 10th, 100th entry or never; directories of 8, 16, 32 and 64 slots, with and without the flush-everything rule on overflow).

## `gates/` gate counts (hole 1 and hole 6)

* `count.sh`, `run_gates.sh`: the repository's method (yosys, `synth -flatten`, `abc -g NAND`); `run_gates.sh` prints every figure of the study, reproduces the earlier references first, and adds the longest topological path (`ltp -noff`).
* `h1b.v`: the directory of walked table pages with a dependency mark in each buffer entry, and the whole arena proposal for one buffer. `h6b.v`: the mask taken from a system register (sticky and one-shot) and the stash at one, two, four levels and for the 16 caller-saved registers.
* `gates-results.txt`: the output of `run_gates.sh`. The tool's result moves by about 10 gates between runs.

## `part-b/` hole 6 (the registers after a return)

* `c/kern.c`: the syscall-like handlers written for the study (copy-in and copy-out, table lookups, checksum, CRC-32, one ChaCha20 block, a dispatcher).
* `compile_corpus.sh OUT`: compiles `tests/c`, `tests/c-new` and `c/kern.c` with pcc and with the LLVM back end (run from the pdp64 checkout). `asm/`: the assembly it produced, kept.
* `regs_static.py`: per function, the registers written and not callee-saved (an upper bound). `regs_dynamic.py`: runs drivers under `sim64` and lists the registers that changed. `corpus_summary.py`: the statistics of the study. `handwritten.py`: the same for the return paths of `tests/qemu/mini-kernel.S`, `tests/qemu/hv-first.S` and `tests/sec-open/sim/sec-regs-carry.S`.
* `syscall_bench.py`, `syscall_table.py`: the loop of 1,000 system calls in the variants of the return path, counted with `sim64 -K -t`, and the same bodies as ordinary functions under `--timing` (the timing model refuses kernel mode).
* `results/`: `corpus-summary.txt`, `dyn-kern.json`, `dyn-corpus.json`, `handwritten.txt`, `syscall-bench.json`, `syscall-table.txt`.

## What this directory does not hold

* The scratch QEMU build, the compiled traces' image files and the dynamic-run drivers (they are made again by the scripts).
* `RTI #mask`, the mask register and the stash do not exist in `sim64` or the QEMU model, so the study counts their sequences rather than running them; the figures that stand for them say so.
* The exit and entry cost of a guest on the pdp64: nobody has measured it; the study uses the published figures of other machines collected in `docs/encoding-work/table-coherence-verified.md` and gives the costs of the rules as a share of them.
