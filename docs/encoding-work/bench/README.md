# Benchmarks and measurements, kept

*A dated record (2026-11-19 to 2026-11-25), saved because the owner asked that all benchmark results be kept (errata 204). The numbers and what they mean are in the study documents named below; this directory holds the programs and files that produced them, so that they can be run again. Nothing here is part of the architecture.*

## `vector-resume/` (the design of resume, the review of the vector block)

The programs and scripts behind `docs/encoding-work/vector-resume-design.md` and `best-of-breed-vector.md` (their appendices list the raw numbers).

* `*.s`, `*.S`: the benchmark blocks (the matrix micro-kernel, float and int8 dot products with and without accumulators, the 2D tile block, the in-place accumulator block `inpl.S`), assembled with `as64` and run with `sim64 -V` (the vector cycle model 1, 16-byte port); `-K -x LO:HI` makes the first access to each page fault once.
* `bench.py`, `fault.py`, `fault2.py`: the drivers that run the blocks and print cycles and the ratio to the warm uninterrupted run.
* `scratch-resume-simulator.patch`: the change to `common/pdp64exec.c`, `common/pdp64exec.h`, `common/pdp64exec_vec.inc` and `sim64/sim64.c` that built resume in place into a scratch copy, with the hook that injects an interrupt after a strip once the vector-cycle count passes the next tick. It is a measuring tool, **not** the implementation of resume.

## `holes-gates/` (gate counts of the studies)

The small Verilog models and the scripts that count them with yosys by the repository's method (`tools/gates`, `docs/encoding-work/vec-gates.md`), behind `closing-holes-by-construction.md`, `vector-resume-design.md` and `nested-virtualization-estimate.md`.

* `*.v`: `h1.v` (the ways to keep a guest's translations from going stale: a directory of walked table pages, a generation number, an arena and its comparators), `h6.v` (the registers after a return: a flash clear with a mask, a marker bit for each register), `h7.v` (the floating-point flags cleared on a context write), `nest.v` (the pieces of nested virtualization), `resume.v` (the resume record, its token and checks, the bound's comparator).
* `count.sh`, `gates.sh`: the scripts. `st.*`: the yosys statistics each run printed (the translation buffer `tlb32` with a 16 and a 32-bit tag, the register-redirect and trap blocks). The reference block `tlb32` came to 7,581 against the 7,589 of `docs/encoding-work/arch-data/core-gates-blocks.tsv`; the register file moves by about 4,500 gates with the way it is written, so every comparison uses the same coding style on both sides.

## What is not kept, and why

* The pages that the studies quote (specifications, papers, vendor documentation) were read on 2026-11-19 and are cited by address and date in each study; their text is not copied here (they are not ours).
* The mutation checks of the security corpus and of the implementations (a deliberately broken scratch copy of the model, shown to fail the test) are described in `docs/security-corpus.md` and in errata 194, 196 and 201; the scratch copies were whole source trees and are not kept.
* Hypervisor cycle figures (the cost of a guest exit and entry) have no measurement in the repository; the study `closing-holes-by-construction.md` used an assumption (3 cycles for a table read, 20 for an exit and an entry), and a verification of real figures is under way.
