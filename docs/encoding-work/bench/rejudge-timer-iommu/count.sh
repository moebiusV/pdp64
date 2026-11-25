#!/bin/sh
# count.sh -- NAND2 equivalents of each module of blocks.v (the method of tools/gates/gates.sh: synth, abc to NAND, NAND2 + half an inverter;
# flip-flops are not in these figures: count them apart, 6 NAND2 each). Run from this directory; yosys is needed.
T=${TMPDIR:-/tmp}/g.$$
for m in $(grep -o '^module [A-Za-z0-9_]*' blocks.v | awk '{print $2}'); do
	yosys -q -p "read_verilog blocks.v; synth -top $m -flatten; abc -g NAND; opt_clean; tee -q -o $T.stat stat" >/dev/null 2>&1
	nand=$(awk '/\$_NAND_/ {n=$2} END {print n+0}' $T.stat)
	not=$(awk '/\$_NOT_/ {n=$2} END {print n+0}' $T.stat)
	ff=$(awk '/DFF/ {n+=$2} END {print n+0}' $T.stat)
	echo "$m	logic $(awk -v a=$nand -v b=$not 'BEGIN{printf "%d", a + b/2}')	flipflops $ff"
done
