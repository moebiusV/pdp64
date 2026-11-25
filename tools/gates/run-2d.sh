#!/bin/sh
# run-2d.sh [--quick] [OUTDIR] -- the whole measurement of docs/encoding-work/vec-2d.md, rerun: the tile benchmarks (run2d.py: 8 kernels x 9 tile sizes x scalar, compiler LoopVectorize, hand loop of
# 1D blocks, hand vec2 block, and the checked pairs, at strips 16, 32, 64, ports 8, 16, 32 and the row-cost and memory-latency sensitivities; every form must write the bytes of the scalar build),
# the tables (sum2d.py -> OUTDIR/summary.md), the pages a tile touches (pages2d.py), the loop nests of the benchmark sources (nests2d.py, needs ../llvm-build) and the silicon of the row advance
# (tile2d.v, yosys).  Default OUTDIR: tools/gates/2d-results.  Takes about 25 minutes (--quick: two tile sizes, a minute).  Needs build/sim64, as64, ld64 (tools/build-sim64.sh), clang and the LLVM tools
# of ../llvm-build (llvm-pdp64/bench/bench.py), yosys.
set -e
cd "$(dirname "$0")/../.."
Q=; if [ "$1" = "--quick" ]; then Q=--quick; shift; fi
OUT=${1:-tools/gates/2d-results}
mkdir -p "$OUT"
JOBS=${JOBS:-6} python3 tools/gates/run2d.py $Q "$OUT"
python3 tools/gates/sum2d.py "$OUT"
python3 tools/gates/pages2d.py > "$OUT/pages.txt"
python3 tools/gates/nests2d.py > "$OUT/nests.md"
sh tools/gates/gates.sh yosys tile2d.v > "$OUT/silicon.tsv"
echo "run-2d: wrote $OUT (tiles.tsv, summary.md, pages.txt, nests.md, silicon.tsv)"
