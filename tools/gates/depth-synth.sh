#!/bin/bash
# depth-synth.sh OUTFILE SNB "FILE.v ..." MODULE... -- the logic depth of each module in the three flows of vec-strip.md (same commands as strip-synth.sh):
#   nand:  synth -top M -flatten; abc -g NAND; opt_clean           gate levels (2-input NAND and NOT)
#   ecp5:  synth_ecp5 -top M                                          LUT4 levels
#   xc7:   synth_xilinx -family xc7 -flatten -top M                   LUT6 levels
# each followed by `ltp -noff` (yosys's own longest topological path: it counts every cell, a carry cell as a LUT) and `write_json`, from which lat-depth.py computes the weighted levels (see there).
# One line a module and flow, tab separated: SNB module flow ltp levels dsp cells.  Resumable: with STATDIR set the result of each (SNB, module, flow) is kept there and not made again.
# Runs JOBS (default 8) yosys in parallel.  A behavioural depth: not timing, not placement.
Y=${Y:-yosys}; here=$(cd "$(dirname "$0")" && pwd); OUT=${1:?out}; N=${2:?SNB}; FILES=${3:?files}; shift 3; JOBS=${JOBS:-8}
RD=""; for f in $FILES; do RD="$RD $here/$f"; done
tmp=$(mktemp -d); SD=${STATDIR:-$tmp}; mkdir -p "$SD"
one() {
	m=$1; f=$2; t=$SD/$N.$m.$f
	[ -s $t ] && return
	case $f in
	nand) S="synth -top $m -flatten; abc -g NAND; opt_clean";;
	ecp5) S="synth_ecp5 -top $m";;
	xc7)  S="synth_xilinx -family xc7 -flatten -top $m";;
	esac
	j=$tmp/$N.$m.$f.json
	"$Y" -q -p "read_verilog -D SNB=$N $RD; $S; tee -q -o $tmp/$N.$m.$f.ltp ltp -noff; write_json $j" >/dev/null 2>$tmp/$N.$m.$f.err || { echo "yosys failed: $N $m $f" >&2; return; }
	l=$(sed -n 's/.*length=\([0-9]*\)).*/\1/p' $tmp/$N.$m.$f.ltp | head -1)
	r=$(python3 "$here/lat-depth.py" $f $m $j) || { echo "lat-depth failed: $N $m $f" >&2; return; }
	printf '%s\t%s\t%s\t%s\t%s\n' "$N" "$m" "$f" "${l:-0}" "$(echo $r | tr ' ' '\t')" > $t.tmp && mv $t.tmp $t
	rm -f $j
}
for m in "$@"; do for f in nand ecp5 xc7; do
	one $m $f &
	while [ $(jobs -r | wc -l) -ge $JOBS ]; do sleep 0.5; done
done; done
wait
for m in "$@"; do for f in nand ecp5 xc7; do cat $SD/$N.$m.$f 2>/dev/null; done; done > "$OUT"
rm -rf $tmp
