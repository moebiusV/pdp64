#!/bin/sh
# depth.sh -- longest path in gate levels (yosys ltp after abc -g NAND) of some modules of blocks.v. A behavioural depth, not timing.
T=${TMPDIR:-/tmp}/d.$$
for m in "$@"; do
	yosys -q -p "read_verilog blocks.v; synth -top $m -flatten; abc -g NAND; opt_clean; tee -q -o $T.ltp ltp -noff" >/dev/null 2>&1
	echo "$m	$(sed -n 's/.*length=\([0-9]*\)).*/\1/p' $T.ltp | head -1) levels"
done
