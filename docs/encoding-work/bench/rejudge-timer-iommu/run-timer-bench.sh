#!/bin/sh
# run from the repository root. Instructions executed (sim64 -K -P) for 1000 iterations of reading the time by a system call, by a load from a kernel-kept page, and of the empty loop.
# (sim64 -K has no cycle model: --timing does not work with -K, so cycles are the instruction count plus the assumed trap cost; the run ends at the step limit, the counts are still right)
B=build; T=${TMPDIR:-/tmp}/rj$$; mkdir -p $T
for t in syscall page empty; do
  cpp -P -I $B docs/encoding-work/bench/rejudge-timer-iommu/$t.S > $T/$t.s &&
  $B/as64 -o $T/$t.o $T/$t.s && $B/ld64 -o $T/$t.x $T/$t.o && $B/sim64 -K -P $T/$t.prof $T/$t.x 2>/dev/null
  printf "%s: " $t; grep '^#instructions' $T/$t.prof
done
rm -rf $T
