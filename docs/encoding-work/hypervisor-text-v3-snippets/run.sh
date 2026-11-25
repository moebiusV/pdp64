#!/bin/sh
# Assemble and, where it can run, run every snippet.  From the top of the repository:  docs/encoding-work/hypervisor-text-v3-snippets/run.sh
# Needs build/as64, build/ld64, build/sim64 (tools/build-as64.sh, tools/build-sim64.sh).  Scratch files go to $TMPDIR (default /tmp).
cd "$(dirname "$0")/../../.." || exit 1
B=build; D=docs/encoding-work/hypervisor-text-v3-snippets; T=${TMPDIR:-/tmp}/hv3-snippets; mkdir -p "$T"
run() {	# name flags: assemble, link, run
	n=$1; fl=$2
	gcc -E -P -x assembler-with-cpp -I$B -Itests/qemu $D/$n.S -o $T/$n.s || { echo "FAIL $n: preprocess"; return; }
	$B/as64 -o $T/$n.o $T/$n.s 2> $T/$n.err || { echo "ASSEMBLY FAILS $n: $(head -1 $T/$n.err)"; return; }
	$B/ld64 -o $T/$n.x $T/$n.o || { echo "FAIL $n: link"; return; }
	$B/sim64 $fl $T/$n.x; echo "ran  $n [sim64 $fl]: exit $? (0 is success)"
}
asm() { n=$1; gcc -E -P -x assembler-with-cpp -I$B $D/$n.S -o $T/$n.s; if $B/as64 -o $T/$n.o $T/$n.s 2> $T/$n.err; then echo "assembles  $n (not run)"; else echo "ASSEMBLY FAILS $n: $(head -1 $T/$n.err)"; fi; }
run story-spl-caught -H
run ex01-02-guest -H
run ex03-hypercall -H
run ex05-virtual-line -H
run ex08-return-mask -K
run ex08-vector-sum ""
run ex08-vector-sum "-S 32"
run ex08-vector-sum "-S 64"
asm ex02-timing-bits
asm ex04-stage2-entry
asm ex05-timer
asm ex07-guest-names
asm ex01-start-new
