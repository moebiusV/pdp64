#!/bin/bash
# run-latency.sh [OUTDIR] [STAGE...] -- re-runs every measurement of docs/encoding-work/vec-latency.md.  OUTDIR defaults to tools/gates/latency-results.  Stages (default: all, in order):
#   depth    the logic depth (longest path, in levels) of the synthesisable blocks in the three flows (nand, ecp5, xc7), strips 32, 16, 8 bytes for the width-dependent ones: OUTDIR/depth.tsv
#            (depth-synth.sh: `ltp` and lat-depth.py; resumable through OUTDIR/stat).  About 30 minutes on 12 cores (JOBS, default 10).
#   table    lat-table.py: the depth table and the latency files from the depth and the assumed delays: OUTDIR/depth.md, OUTDIR/latency-{fpga,asic}.txt (copied to sim64/latency-*.txt by hand when changed)
#   build    tools/build-sim64.sh (sim64 with the second model)
#   bench    tools/lat-bench.py: the kernels of llvm-pdp64/bench under model 1 and model 2 over the grid (OUTDIR/bench.tsv, OUTDIR/bench.md); needs the LLVM tools of ../llvm-build (a few minutes)
# Needs yosys on the path (or Y=...), HBNF as for the other tools (export HBNF=/home/matthew/claude/hbnf/hbnf HBNF_TEMPLATES=/home/matthew/claude/hbnf/templates PATH=$HOME/.local/bin:$PATH).
here=$(cd "$(dirname "$0")" && pwd); root=$(dirname "$(dirname "$here")")
case ${1:-} in depth|table|build|bench|'') out=$here/latency-results;; *) out=$1; shift;; esac
stages=${*:-depth table build bench}
mkdir -p "$out"
WM="w_lanealu_mw w_lanealu_mw_noavg w_shiftround_mw w_shiftlane_mw w_narrow_both w_ms8x8 w_ms8x8_notree w_dacc_tree w_vacc_naive w_vmmacc w_sum_bu w_vsad_bu w_vfir_added w_vtbl_g16
 w_vcmp_mw w_vcmp2 w_vbsl lat_cmpsel lat_alushift w_segload w_segstore w_vmem_ld w_vmem_st w_vregs16_r3 w_cvt_both w_fma32xn"
for s in $stages; do case $s in
depth)
	export STATDIR="$out/stat" JOBS=${JOBS:-10}
	for n in 32 16 8; do "$here/depth-synth.sh" "$out/depth-w$n.tsv" $n "vecw.v fp2.v latw.v" $WM; done
	"$here/depth-synth.sh" "$out/depth-vec3.tsv" 32 "vec3.v" ms16_lo ms16_hi ms16_hi_mla ms16_all mul32s
	"$here/depth-synth.sh" "$out/depth-fp2.tsv" 32 "fp2.v" fma32x8 fma32 cvt_i2f cvt_f2i
	"$here/depth-synth.sh" "$out/depth-core.tsv" 32 "core.v" alu64 shift64 bitops64 mul64 div64 tlb32 ldalign stmerge clmul64 mul53 shr106 add106 norm106
	cat "$out"/depth-w32.tsv "$out"/depth-w16.tsv "$out"/depth-w8.tsv "$out"/depth-vec3.tsv "$out"/depth-fp2.tsv "$out"/depth-core.tsv > "$out/depth.tsv";;
table) python3 "$here/lat-table.py" "$out";;
build) "$root/tools/build-sim64.sh";;
bench) python3 "$root/tools/lat-bench.py" "$out";;
*) echo "unknown stage $s" >&2; exit 2;;
esac; done
