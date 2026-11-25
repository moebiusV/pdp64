#!/bin/sh
# run_gates.sh : the gate counts of the study of holes 1 and 6, by the repository's method (yosys 0.52, synth -flatten, abc -g NAND; a NAND2 is 1, an inverter 0.5, a flip-flop 6).
# h1.v and h6.v are copies of the models of ../../holes-gates (the references are reproduced first); h1b.v and h6b.v are new.  Output: module, logic, flip-flops, total.
here=$(dirname "$0"); t=$(mktemp -d)
cat "$here/h1.v" "$here/h1b.v" > "$t/h1all.v"; cat "$here/h6.v" "$here/h6b.v" > "$t/h6all.v"
echo "== hole 1: references (reproduce the earlier study) =="
sh "$here/count.sh" "$t/h1all.v" tlb32 tlb32t tlb32tall arena u_base u_a u_d d8s1 d16s1 snoopdir u_c3
echo "== hole 1: the arena, whole proposal for one buffer, and the directory of table pages with a dependency bitmap in each buffer entry =="
sh "$here/count.sh" "$t/h1all.v" u_base_tag u_arena_full u_dir8_1 u_dir16_1 u_dir8_2 u_dir16_2 u_dir32_2 u_dir64_2
echo "== hole 6: references =="
sh "$here/count.sh" "$t/h6all.v" rf_base2 rf_flash rf_lazy2 rf_taint rf_bank2
echo "== hole 6: mask in a system register, one-shot mask register, stash of 31 registers (1, 2, 4 levels) and of 16 =="
sh "$here/count.sh" "$t/h6all.v" rf_flash_reg rf_flash_reg1 rf_stash1 rf_stash2 rf_stash4 rf_stash16
echo "== longest topological path in NAND and inverter levels (yosys ltp -noff after the same synthesis; behavioural depth, not timing) =="
depth() { f=$1; shift; for m in "$@"; do yosys -q -p "read_verilog $f; synth -top $m -flatten; abc -g NAND; opt_clean; tee -q -o $t/ltp.txt ltp -noff" >/dev/null 2>&1; echo "$m	$(grep -o 'length=[0-9]*' $t/ltp.txt | head -1)"; done; }
depth "$t/h6all.v" rf_base2 rf_flash rf_lazy2 rf_flash_reg rf_stash1
depth "$t/h1all.v" u_base_tag u_arena_full u_dir16_2
rm -rf "$t"
