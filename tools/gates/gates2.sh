#!/bin/bash
# gates2.sh FILE.v [MODULE...] -- the same flow and the same count as gates.sh (yosys: read_verilog; synth -top M -flatten; abc -g NAND; stat; NAND2 equivalents = NAND + NOT/2),
# but the modules run in parallel (JOBS, default 8), the scratch files are in a private temporary directory, and the output is in the order of the modules.  With no module names, every module of the file.
# Prints one line a module: module, NAND2 equivalents of logic, flip-flops (all $_DFF*), latches ($_DLATCH*), separated by tabs.
Y=${Y:-yosys}; here=$(dirname "$0"); F=${1:?file}; shift; JOBS=${JOBS:-8}
tmp=$(mktemp -d)
MODS=${*:-$(grep -o '^module [A-Za-z0-9_]*' "$here/$F" | awk '{print $2}')}
one() {
	m=$1
	"$Y" -q -p "read_verilog $here/$F; synth -top $m -flatten; abc -g NAND; opt_clean; tee -q -o $tmp/$m.stat stat" >/dev/null 2>$tmp/$m.err
	awk -v m=$m '/\$_NAND_/ {n=$2} /\$_NOT_/ {i=$2} /\$_DFF|\$_SDFF|\$_DFFE|\$_SDFFE|\$_ADFF/ {f+=$2} /\$_DLATCH/ {l+=$2} END {printf "%s\t%d\t%d\t%d\n", m, n + i/2, f+0, l+0}' $tmp/$m.stat > $tmp/$m.out
}
export -f one 2>/dev/null
for m in $MODS; do
	one $m &
	while [ $(jobs -r | wc -l) -ge $JOBS ]; do sleep 1; done
done
wait
for m in $MODS; do cat $tmp/$m.out; done
rm -rf $tmp
