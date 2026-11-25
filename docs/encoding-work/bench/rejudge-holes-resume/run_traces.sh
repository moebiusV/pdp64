#!/bin/sh
# run_traces.sh SCRATCHDIR: make the traces tags.py needs (about 30 MB; not kept) and run it.  Needs build/as64, build/ld64, the QEMU model beside the checkout (as ../rti-mask-reuse/tools/run_trace.sh).
R=$(cd "$(dirname "$0")/../../../.." && pwd); H=$R/docs/encoding-work/bench; S=${1:-/tmp/rejudge-traces}; export SCR=$S; mkdir -p $S
Q=${PDP64_QEMU:-$(dirname "$R")/qemu-build/qemu-system-pdp64}
cd "$R"
MACHINE=pdp64-virt,kernel-mode=on sh $H/rti-mask-reuse/tools/run_trace.sh mini-kernel tests/qemu/mini-kernel.S
MACHINE=pdp64-virt,kernel-mode=on sh $H/rti-mask-reuse/tools/run_trace.sh twoproc $H/rti-mask-reuse/asm/twoproc.S
MACHINE=pdp64-virt,kernel-mode=on,hypervisor=on sh $H/rti-mask-reuse/tools/run_trace.sh hv-first tests/qemu/hv-first.S
for t in mini-kernel twoproc hv-first; do
  M=pdp64-virt,kernel-mode=on; [ $t = hv-first ] && M=$M,hypervisor=on
  timeout 300 $Q -M $M -display none -monitor none -serial none -nodefaults -accel tcg,one-insn-per-tb=on -d exec,cpu,nochain -D $S/$t.cpu.trace -kernel $S/$t.x </dev/null >/dev/null 2>&1
  python3 $H/rejudge-holes-resume/tags.py $t $S
done
