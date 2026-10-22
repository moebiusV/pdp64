#!/bin/sh
# Assemble, link and run the tests under qemu-system-pdp64 -M pdp64-virt, with the same expectations as check-sim64.sh (NAME.exit, NAME.out).
#   tests/sim/NAME.s|.S    the sim64 tests.  Without NAME.flags they run on the default machine (user mode, the system-call stand-in); with -k or -K in
#                          NAME.flags they run on the kernel-mode machine (-M pdp64-virt,kernel-mode=on).  A flag QEMU cannot give (-i, the instruction-
#                          count interrupt injection of sim64) skips the test: tests/qemu has the QEMU versions.
#   tests/qemu/NAME.s|.S   System v1 tests that need the QEMU machine (MMU, devices); always kernel-mode=on.  NAME.in is the standard input of the run
#                          (the console), NAME.qargs extra qemu arguments.
# PDP64_ONLY="name name" runs just those tests.  NAME.S is run through the C preprocessor with build/pdp64-consts.h first (tools/pp-asm.sh).  qemu/build.sh builds the emulator; PDP64_QEMU overrides its path.
set -u
cd "$(dirname "$0")/.."
Q=${PDP64_QEMU:-$HOME/claude/qemu-build/qemu-system-pdp64}
[ -x "$Q" ] || { echo "check-qemu: $Q not found (qemu/build.sh)"; exit 1; }
tools/build-sim64.sh > /dev/null
qemu/sync.sh --check > /dev/null || { echo "check-qemu: qemu/target-pdp64/gen is stale (qemu/sync.sh)"; exit 1; }
B=${BUILD:-build}; fail=0; n=0; skipped=0
for s in tests/sim/*.s tests/sim/*.S tests/qemu/*.s tests/qemu/*.S; do
	[ -f "$s" ] || continue
	dir=$(dirname "$s"); t=$(basename "$s"); t=${t%.*}; src=$s
	case "${PDP64_ONLY:-$t}" in *"$t"*) ;; *) continue;; esac
	machine=pdp64-virt; serial=none
	case "$dir" in *qemu) machine=pdp64-virt,kernel-mode=on; serial=stdio;; esac
	if [ -f "$dir/$t.flags" ]; then
		skip=
		for f in $(cat "$dir/$t.flags"); do
			case "$f" in -k|-K) machine=pdp64-virt,kernel-mode=on; serial=stdio;; -i|[0-9]*:[0-9]*:[0-9]*) skip="needs sim64 -i (injected interrupts)";; *) ;; esac
		done
		if [ -n "$skip" ]; then echo "skip $t ($skip)"; skipped=$((skipped+1)); continue; fi
	fi
	case "$s" in *.S) tools/pp-asm.sh "$s" "$B/qemu_$t.pp.s" || { echo "FAIL $t: preprocessing"; fail=$((fail+1)); continue; }; src="$B/qemu_$t.pp.s";; esac
	if ! "$B/as64" -o "$B/qemu_$t.o" "$src" 2> "$B/qemu_$t.err"; then echo "FAIL $t: assembly: $(head -1 "$B/qemu_$t.err")"; fail=$((fail+1)); continue; fi
	if ! "$B/ld64" -o "$B/qemu_$t.x" "$B/qemu_$t.o" 2>> "$B/qemu_$t.err"; then echo "FAIL $t: link: $(head -1 "$B/qemu_$t.err")"; fail=$((fail+1)); continue; fi
	input=/dev/null; [ -f "$dir/$t.in" ] && input="$dir/$t.in"
	extra=; [ -f "$dir/$t.qargs" ] && extra=$(cat "$dir/$t.qargs")
	timeout 30 "$Q" -M "$machine" -display none -monitor none -serial "$serial" -nodefaults $extra -kernel "$B/qemu_$t.x" < "$input" > "$B/qemu_$t.stdout" 2> "$B/qemu_$t.stderr"
	rc=$?
	want=0; [ -f "$dir/$t.exit" ] && want=$(cat "$dir/$t.exit")
	ok=1
	[ "$rc" = "$want" ] || ok=0
	[ -f "$dir/$t.out" ] && ! cmp -s "$B/qemu_$t.stdout" "$dir/$t.out" && ok=0
	n=$((n+1))
	if [ $ok = 1 ]; then echo "ok   $t"; else echo "FAIL $t: exit $rc, wanted $want $(head -c 200 "$B/qemu_$t.stderr" | head -2 | tr '\n' ' ')"; fail=$((fail+1)); fi
done
echo "qemu: $n run, $fail failed, $skipped skipped"
[ $fail = 0 ]
