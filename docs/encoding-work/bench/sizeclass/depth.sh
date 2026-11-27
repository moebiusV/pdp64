#!/bin/sh
# depth.sh: the longest gate path (yosys ltp, NAND2 and NOT levels) of the blocks that sit on an access or on an SP write.
here=$(cd "$(dirname "$0")" && pwd); t=$(mktemp)
for m in stacklimit_cmp sizeclass_ea colourcheck; do
	yosys -q -p "read_verilog $here/blocks.v; synth -top $m -flatten; abc -g NAND; opt_clean; tee -o $t ltp -noff" >/dev/null 2>&1
	echo "$m	$(grep -o 'length=[0-9]*' $t | head -1)"
done; rm -f $t
