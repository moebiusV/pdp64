#!/bin/sh
# run_gates.sh: the gate counts of the re-judgement, by the repository's method (../holes-1-and-6/gates/count.sh: yosys, synth -flatten, abc -g NAND; NAND2 = 1, inverter 0.5, flip-flop 6).
here=$(cd "$(dirname "$0")" && pwd); g=$here/../holes-1-and-6/gates; t=$(mktemp -d)
cat "$g/h6.v" "$g/h6b.v" "$here/gates.v" > "$t/h6all.v"; cat "$g/h1.v" "$g/h1b.v" "$here/gates.v" > "$t/h1all.v"
echo "== registers (32 x 64, 3 read ports, 1 write port): reference, mask from the instruction, tracking bits =="
sh "$g/count.sh" "$t/h6all.v" rf_base2 rf_flash rf_w rf_t1 rf_taint rf_stash1 rf_bank2
echo "== arena: whole proposal for one buffer (reference), one more comparator per remote core, epoch word on the entering core, epoch increment =="
sh "$g/count.sh" "$t/h1all.v" u_arena_full arena arena_snoop_core arena_epoch_enter arena_epoch_inc
echo "== resume token =="
sh "$g/count.sh" "$t/h1all.v" tok_ctr32 tok_perm32 tok_perm48
echo "== guest tag from a hardware allocator =="
sh "$g/count.sh" "$t/h1all.v" tag_alloc
depth() { f=$1; shift; for m in "$@"; do yosys -q -p "read_verilog $f; synth -top $m -flatten; abc -g NAND; opt_clean; tee -q -o $t/ltp.txt ltp -noff" >/dev/null 2>&1; echo "$m	$(grep -o 'length=[0-9]*' $t/ltp.txt | head -1)"; done; }
echo "== vector registers (16 x 256): reference and with a flash clear =="
sh "$g/count.sh" "$t/h6all.v" vrf_base vrf_flash
echo "== longest path (levels, behavioural) =="
depth "$t/h6all.v" rf_base2 rf_flash rf_w rf_t1
rm -rf "$t"
