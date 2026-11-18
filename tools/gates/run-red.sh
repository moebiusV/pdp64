#!/bin/bash
# run-red.sh [OUTDIR] -- the four floating-point reductions of vecred.v at strips of 16, 32 and 64 bytes, by the flows of strip-synth.sh (NAND2, ECP5 LUT4, xc7 LUT6): red.tsv (one line a module).
# resumable (the stat files stay in OUTDIR/stat).  About 20 minutes on 12 cores.  Used by docs/encoding-work/vec-isa.md section 8 and errata 173.
here=$(cd "$(dirname "$0")" && pwd); OUT=${1:-$here/strip-results}; mkdir -p "$OUT/stat"
export STATDIR=$OUT/stat JOBS=${JOBS:-6}
: > "$OUT/red.tsv"
for s in 16 32 64; do
	"$here/strip-synth.sh" $s vecred.v fadd32 red_naive red_chunk red_part red_exact red_round >> "$OUT/red.tsv"
done
cat "$OUT/red.tsv"
