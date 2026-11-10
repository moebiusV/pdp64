#!/bin/sh
# Assemble, link and run tests/sim/*.s under sim64; compare the exit status with tests/sim/NAME.exit (default 0) and, if there is a
# NAME.out, the standard output.  Each test checks its own results and exits with the number of the first check that failed, so the
# expected status is normally 0; a test of an error expects the status in its .exit file.  NAME.flags, if there is one, holds extra
# sim64 arguments (-k: kernel mode, for the privileged instructions; -K and -i: System v1, see docs/sim64.md; -m pdp64 is accepted and ignored).  NAME.S is NAME.s run through the C
# preprocessor with build/pdp64-consts.h, so a test can use the architecture's numbers by name (PSW_PRI, VECTOR_ILLEGAL...).
# Every test runs twice: with the plain objects (as64 --no-relax) and relaxed (the default, as64 and ld64 relax: docs/relaxation.md), with the same expectations.
set -u
cd "$(dirname "$0")/.."
tools/build-sim64.sh > /dev/null
B=${BUILD:-build}; fail=0; n=0
runtest() {	# src name mode dir
	s=$1; t=$2; enc=$3; dir=$4
	case $enc in relaxed) mflag="--relax"; sfx="_r";; *) mflag="--no-relax"; sfx="_p";; esac
	if ! "$B/as64" $mflag -o "$B/sim_$t$sfx.o" "$s" 2> "$B/sim_$t$sfx.err"; then echo "FAIL $t ($enc): assembly: $(head -1 "$B/sim_$t$sfx.err")"; fail=$((fail+1)); return; fi
	if ! "$B/ld64" -o "$B/sim_$t$sfx.x" "$B/sim_$t$sfx.o" 2>> "$B/sim_$t$sfx.err"; then echo "FAIL $t ($enc): link: $(head -1 "$B/sim_$t$sfx.err")"; fail=$((fail+1)); return; fi
	flags=; [ -f "$dir/$t.flags" ] && flags=$(cat "$dir/$t.flags")
	"$B/sim64" $flags "$B/sim_$t$sfx.x" > "$B/sim_$t$sfx.stdout" 2> "$B/sim_$t$sfx.stderr"
	rc=$?
	want=0; [ -f "$dir/$t.exit" ] && want=$(cat "$dir/$t.exit")
	ok=1
	[ "$rc" = "$want" ] || ok=0
	[ -f "$dir/$t.out" ] && ! cmp -s "$B/sim_$t$sfx.stdout" "$dir/$t.out" && ok=0
	[ -f "$dir/$t.errgrep" ] && ! grep -q -F -- "$(cat "$dir/$t.errgrep")" "$B/sim_$t$sfx.stderr" && ok=0
	n=$((n+1))
	if [ $ok = 1 ]; then echo "ok   $t ($enc)"; else echo "FAIL $t ($enc): exit $rc, wanted $want $(head -c 200 "$B/sim_$t$sfx.stderr" | head -2 | tr '\n' ' ')"; fail=$((fail+1)); fi
}
for dir in tests/sim; do
for s in $dir/*.s $dir/*.S; do
	[ -f "$s" ] || continue
	t=$(basename "$s"); t=${t%.*}
	case "$s" in *.S) tools/pp-asm.sh "$s" "$B/sim_$t.pp.s" || { echo "FAIL $t: preprocessing"; fail=$((fail+1)); continue; }; s="$B/sim_$t.pp.s";; esac
	for e in plain relaxed; do
		runtest "$s" "$t" "$e" "$dir"
	done
done
done
# the profile: the totals of -P are the number of instructions and the bytes of the -t trace
for e in x; do
	sfx=_$e; src=tests/sim/alu.s; mflag="--no-relax"
	"$B/as64" $mflag -o "$B/sim_prof$sfx.o" $src && "$B/ld64" -o "$B/sim_prof$sfx.x" "$B/sim_prof$sfx.o" && "$B/sim64" -t -P "$B/sim_prof$sfx.prof" "$B/sim_prof$sfx.x" > /dev/null 2> "$B/sim_prof$sfx.trace"
	if python3 - "$B/sim_prof$sfx.prof" "$B/sim_prof$sfx.trace" <<'PY'
import sys, re
h = {}; per = 0; perb = 0
for l in open(sys.argv[1]):
    if l.startswith('#instructions'): h['n'] = int(l.split()[1])
    elif l.startswith('#bytes'): h['b'] = int(l.split()[1])
    elif not l.startswith('#'):
        a, c, b, k = l.split(); per += int(c); perb += int(c) * int(b)
n = b = 0
for l in open(sys.argv[2]):
    m = re.match(r'^[0-9a-f]{8}:((?: [0-9a-f]{4})+)', l)
    if m: n += 1; b += 2 * len(m.group(1).split())
sys.exit(0 if (h['n'], h['b']) == (n, b) == (per, perb) else 1)
PY
	then echo "ok   profile"; n=$((n+1)); else echo "FAIL profile: -P totals differ from the trace"; fail=$((fail+1)); fi
done
echo "sim64: $n run, $fail failed"
[ $fail = 0 ]
