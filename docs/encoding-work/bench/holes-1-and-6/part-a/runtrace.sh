#!/bin/sh
# runtrace.sh QEMU_BINARY SRC NAME OUTDIR : assemble a hypervisor test of the pdp64 checkout (run from its root) and run it on the SCRATCH model (the model of qemu-pdp64 with
# scratch-trace-hook.patch applied, built in a scratch directory; never the installed one), writing the trace to OUTDIR/NAME.trace.
#   example: sh docs/encoding-work/bench/holes-1-and-6/part-a/runtrace.sh /path/to/scratch/qemu-system-pdp64 tests/qemu/hv-first.S hv-first /path/to/out
# The programs traced: tests/qemu/hv-first.S hv-stage2.S hv-timer.S hv-vtimer.S, tests/qemu/sec-hv-reset-mmuctl.S, tests/sec-open/qemu/sec-hv-reset-inplace.S
Q=$1; src=$2; t=$3; OUT=$4
mkdir -p "$OUT"
case $src in *.S) gcc -E -P -x assembler-with-cpp -Ibuild -Itests/qemu "$src" -o "$OUT/$t.s";; *) cp "$src" "$OUT/$t.s";; esac
build/as64 -o "$OUT/$t.o" "$OUT/$t.s" && build/ld64 -o "$OUT/$t.x" "$OUT/$t.o" || exit 1
PDP64_TLOG="$OUT/$t.trace" timeout 60 "$Q" -M pdp64-virt,kernel-mode=on,hypervisor=on -display none -monitor none -serial stdio -nodefaults -kernel "$OUT/$t.x" < /dev/null > "$OUT/$t.stdout" 2> "$OUT/$t.stderr"
echo "$t exit=$? trace lines=$(wc -l < "$OUT/$t.trace")"
