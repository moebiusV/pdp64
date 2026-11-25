# What sequential consistency costs an in-order pdp64 core, and the gates and power of the structures it needs

Written 2026-11-25 for `docs/encoding-work/why-not-sequential-consistency.md`. Everything here is new; nothing existing was changed. The work was done in a separate git worktree under `/tmp` (the main tree and its `build/` directory were not touched).

## 1. What was measured and how

**The model.** `timing-sc.patch` adds a store-buffer model to the trace-driven in-order timing model of `sim64` (`common/timing.c`, `docs/timing-model.md`). The patch is against the working-tree version of `common/timing.c` of 2026-11-25 (the file carries other agents' uncommitted changes; the patch touches only the new parameters, the new `sb` stall cause and the store events). New parameters, all with defaults that leave the old results unchanged when `dc=0`:

| parameter | meaning |
|---|---|
| `cm` | 0 relaxed (stores complete in parallel, a load never waits), 1 TSO (stores complete in order, a load passes them), 2 SC (as TSO, and a load waits until every older store is performed; a load of a word that a buffered store holds is forwarded and does not wait) |
| `sbd` | store buffer entries (default 8); a store waits for a free entry |
| `sbp` | 1: ownership of the store's line is requested when the store issues (misses overlap); 0: the request starts when the store reaches the head of the buffer (misses add up) |
| `smiss` | cycles for a store to get ownership of a line that is not in the D-cache (a store that hits takes 1) |
| `sup` | percent of lines that another core owns at each store: a store to them pays `smiss` even on a hit (a crude stand-in for shared data; the single-core model has no coherence traffic) |

The stall is charged to the issue stage (an in-order core stops at the load), and appears as `ex_sb` in the result line. The data cache must be on (`dc=1`). The model has no memory dependences, no atomics and no block instructions in the store buffer (a block instruction bypasses it).

**The programs** (`src/*.c`, C compiled with `pcc`, 21.8 million instructions in all, 3.2 bytes an instruction on average; `build.sh` builds them): `sort` (quicksort of 16,384 words), `hash` (a 256 KB open-addressing table), `copy` (a loop copy and clear of 128 KB arrays), `matmul` (48 x 48 integers), `sha` (SHA-256 over 64 KB), `lz` (a small LZ77 compressor), `list` (a shuffled linked list of 12,000 nodes, built, walked and reversed), `hist` (a byte histogram). **I wrote these eight programs because the earlier dynamic study's images (zlib, crypto and sort under LLVM) are not on this machine and the compilation chain for them was not reproducible here**; they are a mix of store-miss-heavy, store-hit-heavy and compute-bound code, not a standard suite.

**Runs.** `run_matrix.py SIM64 OUT.tsv [dsz]` runs each program once with 30 models (store-miss latency L = 10, 30, 100 cycles with the load-miss latency set to the same L; buffer depth 8 and 2; relaxed R, TSO without and with ownership prefetch T0 and T1, SC without and with S0 and S1). D-cache 16 KB (`results-dsz16k.tsv`) and 64 KB (`results-dsz64k.tsv`), 32-byte lines, 2 ways. `summarize.py` prints the tables (`summary-dsz16k.txt`, `summary-dsz64k.txt`): the run time as a percentage longer than the relaxed model with 8 buffer entries. `run_share.py` varies `sup` (`results-share.tsv`). `run_fetch.py` varies the fetch width and issue width (`results-fetch.tsv`).

## 2. Results (in-order model, one core)

Total run time of all eight programs against the relaxed model (8-entry buffer; D-cache 16 KB; the 64 KB cache changes them by up to 4 points (SC without prefetch at L = 100: 25.0% against 21.0%)):

| store-miss latency L | TSO, no prefetch | TSO, prefetch | SC, no prefetch | SC, prefetch |
|---|---|---|---|---|
| 10 cycles | 0.1% | 0.0% | 1.2% | 0.9% |
| 30 cycles | 2.8% | 0.0% | 6.5% | 3.7% |
| 100 cycles | 14.9% | 0.1% | 21.0% | 9.3% |

With a 2-entry buffer (against the same 8-entry relaxed baseline): L = 30: TSO 4.8% / 2.6% (no prefetch / prefetch), SC 6.6% / 4.5%; L = 100: TSO 17.6% / 10.4%, SC 18.0% / 12.1%. The buffer depth, not the memory model, is then the main cost.

Per program, SC with ownership prefetch, L = 30 and 100: `copy` 26.4% and 47.9%, `hash` 11.6% and 20.2%, `list` 12.5% and 17.2%, `sort` 2.2% and 6.0%, `lz` 0.6% and 2.7%, `matmul` 0.2% and 1.0%, `sha` 0.0% and 0.0%, `hist` 0.0% and 0.0% (`summary-dsz16k.txt`). The store-miss-heavy loops that write to cold memory (copy and clear, a table insert, building a list) carry the cost; compute-bound and store-hit code carries none.

Sharing (`results-share.tsv`, prefetch on, depth 8): SC against TSO is 3.7%, 5.4%, 11.1% at L = 30 and 9.1%, 14.1%, 30.1% at L = 100 when 0%, 5%, 20% of the lines are owned by another core at each store. TSO against relaxed is 0.0% to 0.2% throughout.

Fetch width against instruction count (`results-fetch.tsv`, relaxed store model): going from 16 to 4 bytes a cycle of instruction fetch lengthens the total run time by 0.9% on a 1-issue core and by 4.2% on a 2-issue core; the cycles an instruction costs (CPI 1.86 here for 1-issue) come from loads, misses and branch mispredictions. Fetch starvation (`fe_seq`) is zero at 8 bytes a cycle on every program.

## 3. What the numbers are not

* **One core, no coherence traffic**, except for the crude `sup` knob. They count capacity and cold misses of stores. A real shared-memory workload also has invalidation misses, which `sup` stands in for but does not model.
* **An upper bound for the rule "a load waits for all older stores"**, not a model of any shipped core. A speculative in-order core that lets the load go and holds the commit of everything younger could do better; it is not modelled. In a single-core model it would cost nothing more than TSO.
* My eight programs, not a standard suite; the store-miss latency is a free parameter, not a measured memory system.
* The relaxed model here still has an 8-entry buffer and prefetched ownership. A relaxed core could also reorder stores to hide more; that is not modelled either.

## 4. Gates and power (`gates/`)

`gates/sc_blocks.v` models the structures; `gates/count.sh` counts NAND2 equivalents by the method of `tools/gates/gates.sh` (yosys `synth`, `abc -g NAND`, count = NAND + half the inverters; a flip-flop counts 6); `gates/gate-results.txt` has the counts; `gates/power.py` and `gates/power-results.txt` give a power estimate under stated assumptions (1 fF per NAND2 equivalent, 0.9 V, 1 GHz, stated activity factors): **an estimate, not a measurement**. Cross-check: CACTI 3.2 search energies from Cain and Lipasti 2004, Table 2 (see `SOURCES.md`).

The baseline is the scalar in-order core of `tools/gates/core-total.py`: 219 k to 308 k NAND2 equivalents (middle 263 k), no caches, no branch predictor; 32 mW of logic at the assumed constants.

## 5. Rerun

1. Build a `sim64` from the patched `common/timing.c` (as `tools/build-sim64.sh` does, with `common/timing.c` replaced).
2. `./build.sh` (needs `build/pcc/ccom`, `build/as64`, `build/ld64`), then `./run_matrix.py PATH-TO-SIM64 results.tsv 16384 && ./summarize.py results.tsv`.
3. Gates: `cd gates && ./count.sh sc_blocks.v lq_snoop N=64` (yosys needed).
