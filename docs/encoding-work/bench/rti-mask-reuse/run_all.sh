#!/bin/sh
# run_all.sh : regenerate everything in results/ (needs the pdp64 checkout built: build/as64, build/ld64; the QEMU model qemu-system-pdp64 beside it; yosys 0.52 for the gates).
# SCR is a scratch directory for the traces (about 30 MB); the traces themselves are not kept.
here=$(cd "$(dirname "$0")" && pwd); root=$(cd "$here/../../../.." && pwd)
export SCR=${SCR:-/tmp/rti-mask-reuse}; mkdir -p "$SCR"
cd "$root"
for t in mini-kernel; do MACHINE=pdp64-virt,kernel-mode=on "$here/tools/run_trace.sh" $t tests/qemu/$t.S; done
MACHINE=pdp64-virt,kernel-mode=on "$here/tools/run_trace.sh" twoproc "$here/asm/twoproc.S"
for t in hv-first hv-timer hv-vtimer hv-stage2 sec-hv-reset-mmuctl; do MACHINE=pdp64-virt,kernel-mode=on,hypervisor=on "$here/tools/run_trace.sh" $t tests/qemu/$t.S; done
MACHINE=pdp64-virt,kernel-mode=on,hypervisor=on "$here/tools/run_trace.sh" sec-hv-reset-inplace tests/sec-open/qemu/sec-hv-reset-inplace.S
python3 "$here/tools/replay.py" --out "$here/results" mini-kernel twoproc hv-first hv-timer hv-vtimer hv-stage2 sec-hv-reset-mmuctl sec-hv-reset-inplace > /dev/null
python3 "$here/tools/summary.py" > "$here/results/summary.txt"
python3 "$here/tools/corpus_masks.py" "$here/../holes-1-and-6/part-b/asm" > "$here/results/corpus-masks.txt"
sh "$here/gates/run_gates.sh" > "$here/results/gates-results.txt"
