# Measurements for docs/encoding-work/rejudge-holes-rti-resume-hv.md

Every program here was run for that document; the results beside them are the saved output. The kept traces are not (about 30 MB); `run_traces.sh` makes them again.

| file | what it measures | how to run | result file |
|---|---|---|---|
| `gates.v`, `run_gates.sh` | gates (the repository's yosys method, NAND2 equivalents, flip-flop 6): tracking bits in the register file, the epoch word for the arena, the resume token, a hardware tag allocator, a flash clear of the vector registers | `sh run_gates.sh` | `gates-results.txt` |
| `tags.py`, `run_traces.sh` | what hardware that tracks "this register holds the user's value" would do at each return to a lesser mode of the repository's kernels (traced on the QEMU model); two designs, T0 and T1 | `sh run_traces.sh` | `tags-results.txt`, `tags-t1-exceptions.txt` |
| `vecscan.py` | how many registers each vector block changes, and which accumulator blocks the in-place refusal would stop | `python3 vecscan.py DIR` | `vecscan-results.txt` (vec-forms), `vecscan-tests-results.txt` (tests and the resume study's kernels) |
| `latency.py` | vector cycles of a whole block under `sim64 -V`: how long an interrupt waits if it must wait for the block | `python3 latency.py WORKDIR` | `latency-results.tsv` |
| `movql.sh` | executed and static counts of the ten-byte `MOVQL` in compiled programs | `sh movql.sh WORKDIR` | `movql-results.tsv`, `movql-static.txt` |
