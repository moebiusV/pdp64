#!/bin/sh
# count.sh FILE.v module... : the repository's method (yosys 0.52, synth -flatten, abc -g NAND; NAND2 + 0.5 per inverter; a flip-flop = 6 NAND2; a flip-flop with a synchronous clear = 6 + 1 for its gate)
f=$1; shift
st=$(mktemp)
for m in "$@"; do
  yosys -q -p "read_verilog $f; synth -top $m -flatten; abc -g NAND; opt_clean; tee -q -o $st stat" >/dev/null 2>&1 || { echo "$m FAILED"; continue; }
  awk -v m=$m '/\$_NAND_/{n=$2} /\$_NOT_/{i=$2} /\$_SDFF/{s+=$2} /\$_DFF|\$_DLATCH/{d+=$2} END{ff=d+s; logic=n+i/2+s; printf "%s\tlogic %d\tff %d\ttotal %d\n", m, logic, ff, logic+6*ff}' $st
done
rm -f $st
