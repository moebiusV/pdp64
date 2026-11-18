#!/bin/sh
# gates.sh [yosys] -- the gate count of each block of blocks.v: yosys synthesises it, abc maps it to NAND2 and inverters; the count is NAND2 + 0.5 per inverter, a
# flip-flop is counted apart (and as 6 NAND2 in the totals of vec-gates.md).  Prints module, NAND2 equivalents of logic, flip-flops.
Y=${1:-yosys}; here=$(dirname "$0"); F=${2:-blocks.v}; MODS=${3:-}
for m in ${MODS:-$(grep -o '^module [a-z0-9_]*' "$here/$F" | awk '{print $2}')}; do
	"$Y" -q -p "read_verilog $here/$F; synth -top $m -flatten; abc -g NAND; opt_clean; tee -q -o /tmp/gates.$$.stat stat" >/dev/null 2>&1
	out=$(cat /tmp/gates.$$.stat)
	nand=$(echo "$out" | awk '/\$_NAND_/ {n=$2} END {print n+0}')
	not=$(echo "$out" | awk '/\$_NOT_/ {n=$2} END {print n+0}')
	dff=$(echo "$out" | awk '/\$_DFF|\$_SDFF|\$_DLATCH|\$_DFFE/ {n+=$2} END {print n+0}')
	echo "$m	$(awk -v a=$nand -v b=$not 'BEGIN{printf "%d", a + b/2}')	$dff"
done
