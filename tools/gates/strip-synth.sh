#!/bin/bash
# strip-synth.sh SNB "FILE.v ..." MODULE... -- synthesise each module with the flows of the gate study, for a strip of SNB bytes (vecw.v reads the macro SNB, read_verilog -D SNB=n; the
# other files ignore it).  Three yosys runs a module, as gates2.sh and fpga.sh do (the same commands):
#   NAND2:  synth -top M -flatten; abc -g NAND; opt_clean; stat          NAND2 equivalents = NAND + NOT/2
#   ECP5:   synth_ecp5 -top M          LUT4 (a carry cell CCU2C counts 2), flip-flops, MULT18X18D, RAM cells (DP16KD, TRELLIS_DPR16X4)
#   xc7:    synth_xilinx -family xc7 -flatten -top M    LUT1-6, flip-flops, DSP48E1, RAMB, and the distributed RAM cells (RAM32M, RAM64M, RAM32X1D, RAM64X1D, RAM32X1S, RAM64X1S ...)
# -flatten for xc7: synth_xilinx keeps the hierarchy, and fpga.sh then adds the cell counts of every module section and of the design-hierarchy total, which counts a wrapper and its core twice and an
# N-instance block (N+1)/N times: fpga-blocks.tsv's Xilinx column is inflated by that for every module with a submodule; ECP5 flattens by itself and is not affected.
# Resumable: with STATDIR set the stat file of each module, width and flow is kept there and not made again if it exists.
# One line a module, tab separated: SNB, module, nand2, dff, latch, ecp5_lut4, ecp5_ff, ecp5_mult, ecp5_dpr16x4, ecp5_dp16kd, xc7_lut, xc7_ff, xc7_dsp, xc7_ramb, xc7_ramcells(LUT6 sites).
# The modules run in parallel (JOBS, default 8).  A behavioural count: not timing, not placement.
Y=${Y:-yosys}; here=$(cd "$(dirname "$0")" && pwd); N=${1:?SNB}; FILES=${2:?files}; shift 2; JOBS=${JOBS:-8}
RD=""; for f in $FILES; do RD="$RD $here/$f"; done
tmp=$(mktemp -d); SD=${STATDIR:-$tmp}; mkdir -p "$SD"
one() {
	m=$1; t=$SD/$N.$m; o=$tmp/$N.$m
	[ -s $t.n ] || "$Y" -q -p "read_verilog -D SNB=$N $RD; synth -top $m -flatten; abc -g NAND; opt_clean; tee -q -o $t.n.tmp stat" >/dev/null 2>$o.ne && mv $t.n.tmp $t.n
	[ -s $t.e ] || "$Y" -q -p "read_verilog -D SNB=$N $RD; synth_ecp5 -top $m; tee -q -o $t.e.tmp stat" >/dev/null 2>$o.ee && mv $t.e.tmp $t.e
	[ -s $t.x ] || "$Y" -q -p "read_verilog -D SNB=$N $RD; synth_xilinx -family xc7 -flatten -top $m; tee -q -o $t.x.tmp stat" >/dev/null 2>$o.xe && mv $t.x.tmp $t.x
	{
	printf '%s\t%s' "$N" "$m"
	awk '/\$_NAND_/ {n=$2} /\$_NOT_/ {i=$2} /\$_DFF|\$_SDFF|\$_DFFE|\$_SDFFE|\$_ADFF/ {f+=$2} /\$_DLATCH/ {l+=$2} END {printf "\t%d\t%d\t%d", n + i/2, f+0, l+0}' $t.n 2>/dev/null || printf '\t-\t-\t-'
	awk '/CCU2C/ {c+=$2} / LUT4 / {l+=$2} /TRELLIS_FF/ {f+=$2} /MULT18X18D/ {mu+=$2} /TRELLIS_DPR16X4/ {d+=$2} /DP16KD/ {k+=$2} END {printf "\t%d\t%d\t%d\t%d\t%d", l+2*c, f+0, mu+0, d+0, k+0}' $t.e 2>/dev/null || printf '\t-\t-\t-\t-\t-'
	awk '/ LUT[1-6] / {l+=$2} /FD[CPRS]E?|FDCE|FDRE|FDPE|FDSE/ {f+=$2} /DSP48E1/ {d+=$2} /RAMB/ {r+=$2} /RAM(32|64)M|RAM(32|64)X1[SD]|RAM(128|256)X1[SD]/ {x=$2; if ($1 ~ /RAM(32|64)M/) rc+=4*x; else if ($1 ~ /X1D/) rc+=2*x; else rc+=x} END {printf "\t%d\t%d\t%d\t%d\t%d\n", l+0, f+0, d+0, r+0, rc+0}' $t.x 2>/dev/null || printf '\t-\t-\t-\t-\t-\n'
	} > $o.out
}
for m in "$@"; do
	one $m &
	while [ $(jobs -r | wc -l) -ge $JOBS ]; do sleep 1; done
done
wait
for m in "$@"; do cat $tmp/$N.$m.out; done
rm -rf $tmp
