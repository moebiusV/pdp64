#!/bin/bash
# run-strip.sh [OUTDIR] [STAGE...] -- re-runs every measurement of docs/encoding-work/vec-strip.md.  OUTDIR defaults to tools/gates/strip-results.  Stages (default: all, in order):
#   synth   the width-dependent blocks of vecw.v at strips of 32, 16 and 8 bytes (256, 128, 64 bits) and the original blocks of vec2.v, vec3.v, mem2.v, fp2.v at 256 bits (the check):
#           OUTDIR/strip-32.tsv strip-16.tsv strip-8.tsv ref-32.tsv (strip-synth.sh: NAND2, ECP5, xc7).  About 20 minutes on 12 cores (JOBS, default 3 each of the four runs).
#   total   strip-total.py: the tables of the gate study at the three widths (OUTDIR/area.md, OUTDIR/area.tsv)
#   equiv   tools/strip-equiv.py: tests/sim and llvm/check.sh at the strips 8, 16, 32, 64 (sim64 -S, PDP64_VSTRIP): results must not depend on the strip (OUTDIR/equiv.md); a minute or two
#   bench   tools/strip-bench.py: the 46 kernels of llvm/bench (variant lv) and the hand-written kernels at strips 8, 16, 32, 64 bytes and ports 8, 16, 32 bytes a cycle under sim64 -S --vport
#           (OUTDIR/bench.tsv, OUTDIR/bench.md); needs build/sim64 (tools/build-sim64.sh) and the LLVM tools of ../llvm-build (under a minute)
# Needs yosys on the path (or Y=...), HBNF as for the other tools.
here=$(cd "$(dirname "$0")" && pwd); root=$(dirname "$(dirname "$here")")
case ${1:-} in synth|total|equiv|bench|'') out=$here/strip-results;; *) out=$1; shift;; esac
stages=${*:-synth total equiv bench}
mkdir -p "$out"
MODS="w_vcmp_mw w_fma32xn w_cvt_both w_ms8x8 w_ms8x8_notree w_lanealu_mw w_lanealu_mw_noavg w_shiftround_mw w_shiftlane_mw w_segload w_segstore w_vacc_naive w_vmmacc w_narrow_both w_vfir_added w_dacc_tree
 w_sum_bu w_vsad_bu w_vtbl_g16 w_vcmp2 w_vbsl w_vregs16_r3 w_vmem_ld w_vmem_st"
REF="vcmp_mw fma32x8 cvt_both8 ms8x8 ms8x8_notree lanealu_mw lanealu_mw_noavg shiftround_mw shiftlane_mw segload segstore vacc_naive vmmacc narrow_both vfir_added dacc_tree sum32_bu vsad_bu vtbl_g16
 vbsl vregs16_r3 vmem_ld vmem_st"
for s in $stages; do case $s in
synth)
	J=${JOBS:-3}
	export STATDIR="$out/stat"
	for n in 32 16 8; do JOBS=$J "$here/strip-synth.sh" $n "vecw.v fp2.v" $MODS > "$out/strip-$n.tsv" & done
	JOBS=$J "$here/strip-synth.sh" 32 "vec2.v vec3.v mem2.v fp2.v" $REF > "$out/ref-32.tsv" &
	wait;;
total) python3 "$here/strip-total.py" "$out" > "$out/area.md" && cat "$out/area.md";;
equiv) python3 "$root/tools/strip-equiv.py" "$out" > /dev/null && echo "$out/equiv.md";;
bench) python3 "$root/tools/strip-bench.py" "$out";;
*) echo "unknown stage $s" >&2; exit 2;;
esac; done
