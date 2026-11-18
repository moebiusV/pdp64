#!/bin/bash
# fpga.sh FILE.v [MODULE...] -- the blocks of the gate study mapped to FPGA cells by yosys: synth_ecp5 (Lattice ECP5: 4-input LUTs, 18x18 multipliers) and synth_xilinx -family xc7
# (Xilinx 7 series: LUTs of 1 to 6 inputs, DSP48E1).  One line a module, tab separated: module, ecp5 LUT4, ecp5 flip-flops, ecp5 MULT18X18D, ecp5 RAM blocks and distributed RAM,
# xc7 LUTs, xc7 flip-flops, xc7 DSP48E1, xc7 RAMB.  The modules run in parallel (JOBS, default 8).  A behavioural count of the same Verilog as gates.sh: not timing, not placement.
Y=${Y:-yosys}; here=$(cd "$(dirname "$0")" && pwd); F=${1:?file}; shift; JOBS=${JOBS:-8}
tmp=$(mktemp -d)
MODS=${*:-$(grep -o '^module [A-Za-z0-9_]*' "$here/$F" | awk '{print $2}')}
one() {
	m=$1
	"$Y" -q -p "read_verilog $here/$F; synth_ecp5 -top $m; tee -q -o $tmp/$m.e stat" >/dev/null 2>$tmp/$m.ee
	"$Y" -q -p "read_verilog $here/$F; synth_xilinx -family xc7 -flatten -top $m; tee -q -o $tmp/$m.x stat" >/dev/null 2>$tmp/$m.xe
	{
	printf '%s' "$m"
	awk '/CCU2C/ {c+=$2} /LUT4/ {l+=$2} /L6MUX21|PFUMX/ {mx+=$2} /TRELLIS_FF/ {f+=$2} /MULT18X18D/ {mu+=$2} /DP16KD|TRELLIS_DPR16X4/ {r+=$2} END {printf "\t%d\t%d\t%d\t%d", l+2*c, f+0, mu+0, r+0}' $tmp/$m.e 2>/dev/null || printf '\t-\t-\t-\t-'
	awk '/ LUT[1-6] / {l+=$2} /FD[CPRS]E?|FDCE|FDRE|FDPE|FDSE/ {f+=$2} /DSP48E1/ {d+=$2} /RAMB/ {r+=$2} END {printf "\t%d\t%d\t%d\t%d\n", l+0, f+0, d+0, r+0}' $tmp/$m.x 2>/dev/null || printf '\t-\t-\t-\t-\n'
	} > $tmp/$m.out
}
for m in $MODS; do
	one $m &
	while [ $(jobs -r | wc -l) -ge $JOBS ]; do sleep 1; done
done
wait
for m in $MODS; do cat $tmp/$m.out; done
rm -rf $tmp
