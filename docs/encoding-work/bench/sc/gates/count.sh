#!/bin/sh
# count.sh MODULE'[-P PARAM=VALUE ...]' : NAND2 equivalents by the method of tools/gates/gates.sh (yosys synth, abc -g NAND; count = NAND + NOT/2; flip-flops apart)
# usage: count.sh sc_blocks.v top [param=value ...]
f=$1; top=$2; shift 2
chp=""; for p in "$@"; do chp="$chp chparam -set ${p%%=*} ${p#*=} $top;"; done
T=${TMPDIR:-/tmp}/g.$$
yosys -q -p "read_verilog -sv $f; hierarchy -top $top; $chp synth -top $top -flatten; abc -g NAND; opt_clean; tee -q -o $T.stat stat" >/dev/null 2>$T.err || { cat $T.err | head -5; exit 1; }
nand=$(awk '/\$_NAND_/ {n=$2} END {print n+0}' $T.stat)
not=$(awk '/\$_NOT_/ {n=$2} END {print n+0}' $T.stat)
ff=$(awk '/DFF|\$_SDFF|\$_DFFE/ {n+=$2} END {print n+0}' $T.stat)
logic=$(awk -v a=$nand -v b=$not 'BEGIN{printf "%d", a + b/2}')
echo "$top $* logic $logic flipflops $ff total_with_ff_as_6 $((logic + 6*ff))"
rm -f $T.stat $T.err
