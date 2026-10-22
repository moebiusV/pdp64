#!/bin/sh
# Assemble, link and run tests/sim/*.s under sim64; compare the exit status with tests/sim/NAME.exit (default 0) and, if there is a
# NAME.out, the standard output.  Each test checks its own results and exits with the number of the first check that failed, so the
# expected status is normally 0; a test of an error expects the status in its .exit file.  NAME.flags, if there is one, holds extra
# sim64 arguments (-k: kernel mode, for the privileged instructions).
set -u
cd "$(dirname "$0")/.."
tools/build-sim64.sh > /dev/null
B=${BUILD:-build}; fail=0; n=0
for s in tests/sim/*.s; do
	t=$(basename "$s" .s)
	if ! "$B/as64" -o "$B/sim_$t.o" "$s" 2> "$B/sim_$t.err"; then echo "FAIL $t: assembly: $(head -1 "$B/sim_$t.err")"; fail=$((fail+1)); continue; fi
	if ! "$B/ld64" -o "$B/sim_$t.x" "$B/sim_$t.o" 2>> "$B/sim_$t.err"; then echo "FAIL $t: link: $(head -1 "$B/sim_$t.err")"; fail=$((fail+1)); continue; fi
	flags=; [ -f "tests/sim/$t.flags" ] && flags=$(cat "tests/sim/$t.flags")
	"$B/sim64" $flags "$B/sim_$t.x" > "$B/sim_$t.stdout" 2> "$B/sim_$t.stderr"
	rc=$?
	want=0; [ -f "tests/sim/$t.exit" ] && want=$(cat "tests/sim/$t.exit")
	ok=1
	[ "$rc" = "$want" ] || ok=0
	[ -f "tests/sim/$t.out" ] && ! cmp -s "$B/sim_$t.stdout" "tests/sim/$t.out" && ok=0
	n=$((n+1))
	if [ $ok = 1 ]; then echo "ok   $t"; else echo "FAIL $t: exit $rc, wanted $want $(head -c 200 "$B/sim_$t.stderr" | head -2 | tr '\n' ' ')"; fail=$((fail+1)); fi
done
echo "sim64: $n run, $fail failed"
[ $fail = 0 ]
