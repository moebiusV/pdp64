#!/bin/sh
# run_gates.sh : the gate counts of the study of RTI mask reuse, by the repository's method (count.sh: yosys, synth -flatten, abc -g NAND; a NAND2 is 1, an inverter 0.5, a flip-flop 6).
here=$(dirname "$0")
echo "== references: the register file today, the flash clear with the mask from the instruction (design B) =="
sh "$here/count.sh" "$here/latch.v" rf_base2 rf_imm
echo "== design A1 (one latch, GENTER writes it), A2 (short and long forms), A2 with the latch readable and writable by MFSR and MTSR, A2 with two latches, A2 per nesting level (2, 4, 8), A3 one latch per kind of return (4) =="
sh "$here/count.sh" "$here/latch.v" rf_a1 rf_a2 rf_a2_sr rf_a2_lvl rf_a2_nest2 rf_a2_nest4 rf_a2_nest8 rf_a3
t=$(mktemp -d)
echo "== longest topological path in NAND and inverter levels =="
for m in rf_base2 rf_imm rf_a1 rf_a2 rf_a2_nest4; do yosys -q -p "read_verilog $here/latch.v; synth -top $m -flatten; abc -g NAND; opt_clean; tee -q -o $t/ltp.txt ltp -noff" >/dev/null 2>&1; echo "$m	$(grep -o 'length=[0-9]*' $t/ltp.txt | head -1)"; done
rm -rf "$t"
