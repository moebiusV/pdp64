#!/bin/sh
# Assemble, link and run tests/sim/*.s under qemu-system-pdp64 -M pdp64-virt, with the same expectations as check-sim64.sh
# (NAME.exit, NAME.out).  qemu/build.sh builds the emulator; PDP64_QEMU overrides its path.
set -u
cd "$(dirname "$0")/.."
Q=${PDP64_QEMU:-$HOME/claude/qemu-build/qemu-system-pdp64}
[ -x "$Q" ] || { echo "check-qemu: $Q not found (qemu/build.sh)"; exit 1; }
tools/build-sim64.sh > /dev/null
qemu/sync.sh --check > /dev/null || { echo "check-qemu: qemu/target-pdp64/gen is stale (qemu/sync.sh)"; exit 1; }
B=${BUILD:-build}; fail=0; n=0
for s in tests/sim/*.s; do
	t=$(basename "$s" .s)
	if ! "$B/as64" -o "$B/qemu_$t.o" "$s" 2> "$B/qemu_$t.err"; then echo "FAIL $t: assembly: $(head -1 "$B/qemu_$t.err")"; fail=$((fail+1)); continue; fi
	if ! "$B/ld64" -o "$B/qemu_$t.x" "$B/qemu_$t.o" 2>> "$B/qemu_$t.err"; then echo "FAIL $t: link: $(head -1 "$B/qemu_$t.err")"; fail=$((fail+1)); continue; fi
	"$Q" -M pdp64-virt -display none -monitor none -serial none -nodefaults -kernel "$B/qemu_$t.x" > "$B/qemu_$t.stdout" 2> "$B/qemu_$t.stderr"
	rc=$?
	want=0; [ -f "tests/sim/$t.exit" ] && want=$(cat "tests/sim/$t.exit")
	ok=1
	[ "$rc" = "$want" ] || ok=0
	[ -f "tests/sim/$t.out" ] && ! cmp -s "$B/qemu_$t.stdout" "tests/sim/$t.out" && ok=0
	n=$((n+1))
	if [ $ok = 1 ]; then echo "ok   $t"; else echo "FAIL $t: exit $rc, wanted $want $(head -c 200 "$B/qemu_$t.stderr" | head -2 | tr '\n' ' ')"; fail=$((fail+1)); fi
done
echo "qemu: $n run, $fail failed"
[ $fail = 0 ]
