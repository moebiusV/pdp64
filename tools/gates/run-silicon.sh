#!/bin/bash
# run-silicon.sh [OUTDIR] -- re-runs every measurement of docs/encoding-work/vec-silicon.md: the baseline blocks (gates.sh over blocks.v, core.v, aes.v, decode.v) and the new blocks
# (gates2.sh over vec2.v, vec3.v, fp2.v, mem2.v), writes OUTDIR/vec-silicon-blocks.tsv (module, NAND2 equivalents of logic, flip-flops, latches) and OUTDIR/core-silicon-blocks.tsv,
# then prints the tables (silicon-total.py).  OUTDIR defaults to this directory.  About 15 minutes on 12 cores.  Needs yosys on the path (or Y=...).
here=$(cd "$(dirname "$0")" && pwd); out=${1:-$here}; Y=${Y:-yosys}; export Y
tmp=$(mktemp -d)
# the baseline of vec-gates.md and the core
sh "$here/gates.sh" "$Y" blocks.v | awk '{print $1 "\t" $2 "\t" $3 "\t0"}' > "$tmp/base.tsv"
for f in core.v aes.v decode.v; do sh "$here/gates.sh" "$Y" $f; done > "$out/core-silicon-blocks.tsv"
V2="lanealu_mw lanealu_mw_noavg lanealu_w lanealu_w_noavg vavg_mw shiftlane_mw shiftround_mw shiftlane_wl shiftround_wl shiftlane_w shiftround_w narrow_w2b narrow_l2w narrow_both
 narrow_w2b_plain narrow_l2w_plain narrow_both_plain vmul16_lo vmulh16_sep vmla16_sep vdotw_sep vdotb_sep vdotb_s dacc_tree vdaccb_sep vdaccw_sep vsad_bu sum32_bu vacc_shared32
 vacc_shared64 vacc_naive vacc_b vacc_w vacc_l vacc_q vmmacc vtbl_g16 vtbl_one vcmp_mw vbsl segload segstore vregs16_r3 vregs16_r2 vregs16_r4 vregs16_latch"
V3="ms16_lo ms16_hi ms16_hi_mla ms16_all vmul16_full ms8x8 ms8x8_notree vfir_added mul32s"
F2="fma32 fma32x2 fma32x8 tile_state gemm_seq gather_agen32 gather_insert gather_full cvt_i2f cvt_f2i cvt_both8"
M2="vmem_ld vmem_ld_plain vmem_st"
{ "$here/gates2.sh" vec2.v $V2; "$here/gates2.sh" vec3.v $V3; "$here/gates2.sh" fp2.v $F2; "$here/gates2.sh" mem2.v $M2; } > "$tmp/new.tsv"
cat "$tmp/base.tsv" "$tmp/new.tsv" > "$out/vec-silicon-blocks.tsv"
rm -rf "$tmp"
python3 "$here/silicon-total.py" "$out/vec-silicon-blocks.tsv" "$out/core-silicon-blocks.tsv"
