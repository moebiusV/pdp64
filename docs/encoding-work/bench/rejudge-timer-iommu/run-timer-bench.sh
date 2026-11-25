#!/bin/sh
# run from the repository root. Cycles of the timing model (tools: build/sim64 --timing, docs/timing-model.md) for 1000 reads of the time by
# a load from a kernel-kept page and by a system call, with the cost of a trap `sys` = 20 (the model's default), 100 and 300 cycles.
B=build; D=docs/encoding-work/bench/rejudge-timer-iommu; T=${TMPDIR:-/tmp}/rj$$; mkdir -p "$T"
for t in tnone tload tsys; do
  $B/as64 -o "$T/$t.o" $D/$t.s && $B/ld64 -o "$T/$t.x" "$T/$t.o" || exit 1
done
for sys in 1 20 100 300; do
  for t in tnone tload tsys; do
    printf "sys=%s %s: " $sys $t
    $B/sim64 --timing=name=$t,sys=$sys,pred=perfect,ld=3 "$T/$t.x" 2>&1 >/dev/null | grep '^tm' | sed 's/.* insns=\([0-9]*\).* cycles=\([0-9]*\).*/insns=\1 cycles=\2/'
  done
done
