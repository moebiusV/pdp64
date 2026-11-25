#!/bin/sh
# count.sh -- NAND2 equivalents of each module of blocks.v (the method of tools/gates/gates.sh; run from this directory)
for m in $(grep -o '^module [a-z0-9_]*' blocks.v | awk '{print $2}'); do
	yosys -q -p "read_verilog blocks.v; synth -top $m -flatten; abc -g NAND; opt_clean; tee -q -o /tmp/g.$$.stat stat" >/dev/null 2>&1
	out=$(cat /tmp/g.$$.stat)
	nand=$(echo "$out" | awk '/\$_NAND_/ {n=$2} END {print n+0}')
	not=$(echo "$out" | awk '/\$_NOT_/ {n=$2} END {print n+0}')
	echo "$m	$(awk -v a=$nand -v b=$not 'BEGIN{printf "%d", a + b/2}')"
done
