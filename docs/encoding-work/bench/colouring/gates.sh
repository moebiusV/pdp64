#!/bin/sh
# gates.sh [MODULE...]: the repository's counting flow on colour.v of this directory: NAND2 + 0.5 per inverter, flip-flops apart (as ../sizeclass/gates.sh).
here=$(cd "$(dirname "$0")" && pwd)
for m in ${@:-$(grep -o '^module [a-z0-9_]*' "$here/colour.v" | awk '{print $2}')}; do
	t=$(mktemp)
	yosys -q -p "read_verilog $here/colour.v; synth -top $m -flatten; abc -g NAND; opt_clean; tee -q -o $t stat" >/dev/null 2>&1
	nand=$(awk '/\$_NAND_/ {n=$2} END {print n+0}' $t); not=$(awk '/\$_NOT_/ {n=$2} END {print n+0}' $t)
	dff=$(awk '/\$_DFF|\$_SDFF|\$_DLATCH|\$_DFFE/ {n+=$2} END {print n+0}' $t); rm -f $t
	echo "$m	$(awk -v a=$nand -v b=$not 'BEGIN{printf "%d", a + b/2}')	$dff"
done
