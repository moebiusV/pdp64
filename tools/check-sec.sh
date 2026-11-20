#!/bin/sh
# The security corpus (docs/security-corpus.md, errata 201): the probes that FIND a hole on the current implementation.
#   tools/check-sec.sh           run every probe of tests/sec-open (sim64 and the QEMU machine) and report each as FOUND (exit status 1 to 250: the number of the failed check),
#                                PASS (exit 0: the hole is gone, so the probe belongs in tests/sim or tests/qemu and the index row must say pass) or BROKEN (anything else: assembly,
#                                link, crash, timeout).  Exits 0 whatever it finds, except for BROKEN.
#   tools/check-sec.sh --check   as above, and fail (exit 1) if the index disagrees with the facts: a FOUND probe whose row of docs/security-corpus.md is not FOUND, a probe that passes
#                                but is still in tests/sec-open or whose row says FOUND, a test file that no row names, a row that names a test file that does not exist.
# The passing probes (tests/sim/sec-*, tests/qemu/sec-*) are run by tools/check-sim64.sh and tools/check-qemu.sh with every other test.
# Conventions of a probe: it exits 0 when the implementation does NOT have the hole and with the number of the first failed check otherwise.  NAME.flags and NAME.qargs are as in
# check-sim64.sh and check-qemu.sh.  A probe of tests/sec-open/sim runs on both sim64 and QEMU (as a test of tests/sim does); one of tests/sec-open/qemu on QEMU only.
set -u
cd "$(dirname "$0")/.."
MODE=run; [ "${1:-}" = "--check" ] && MODE=check
Q=${PDP64_QEMU:-$(dirname "$PWD")/qemu-build/qemu-system-pdp64}
tools/build-sim64.sh > /dev/null
B=${BUILD:-build}; broken=0; found=0; passed=0; FOUNDLIST=""; PASSLIST=""
build() {	# src name  -> $B/sec_NAME.x
	s=$1; t=$2
	case "$s" in *.S) tools/pp-asm.sh "$s" "$B/sec_$t.pp.s" || return 1; s="$B/sec_$t.pp.s";; esac
	"$B/as64" -o "$B/sec_$t.o" "$s" 2> "$B/sec_$t.err" && "$B/ld64" -o "$B/sec_$t.x" "$B/sec_$t.o" 2>> "$B/sec_$t.err"
}
report() {	# name where rc
	t=$1; w=$2; rc=$3
	if [ "$rc" = 0 ]; then echo "PASS  $t ($w): the hole is not there any more"; passed=$((passed+1)); PASSLIST="$PASSLIST $t"
	elif [ "$rc" -ge 1 ] && [ "$rc" -le 250 ]; then echo "FOUND $t ($w): failed check $rc"; found=$((found+1)); FOUNDLIST="$FOUNDLIST $t"
	else echo "BROKEN $t ($w): exit $rc"; broken=$((broken+1)); fi
}
for kind in sim qemu; do
for s in tests/sec-open/$kind/*.S tests/sec-open/$kind/*.s; do
	[ -f "$s" ] || continue
	dir=$(dirname "$s"); t=$(basename "$s"); t=${t%.*}
	if ! build "$s" "$t"; then echo "BROKEN $t: assembly or link: $(head -1 "$B/sec_$t.err")"; broken=$((broken+1)); continue; fi
	flags=; [ -f "$dir/$t.flags" ] && flags=$(cat "$dir/$t.flags")
	if [ $kind = sim ]; then
		"$B/sim64" $flags "$B/sec_$t.x" > /dev/null 2>&1; report "$t" sim64 $?
	fi
	if [ -x "$Q" ]; then
		machine=pdp64-virt,kernel-mode=on
		for f in $flags; do case "$f" in -H) machine=pdp64-virt,kernel-mode=on,hypervisor=on;; esac; done
		extra=; [ -f "$dir/$t.qargs" ] && extra=$(cat "$dir/$t.qargs")
		timeout 30 "$Q" -M "$machine" -display none -monitor none -serial none -nodefaults $extra -kernel "$B/sec_$t.x" < /dev/null > /dev/null 2>&1; report "$t" qemu $?
	else echo "skip  $t (qemu): no $Q"; fi
done
done
echo "sec-open: $found found, $passed passed (fixed), $broken broken"
[ $broken = 0 ] || exit 1
[ $MODE = check ] || exit 0
# the index
python3 - "$FOUNDLIST" "$PASSLIST" <<'PY'
import sys, re, os, glob
found = set(sys.argv[1].split()); passed = set(sys.argv[2].split())
rows = {}
for l in open('docs/security-corpus.md'):
    if l.startswith('| SEC-'):
        c = [x.strip() for x in l.strip().strip('|').split('|')]
        rows[c[0]] = c
bad = 0
tests_named = {}
for sid, c in rows.items():
    status = c[-1]
    for t in re.findall(r'`([^`]+)`', c[4]):
        tests_named.setdefault(t, []).append((sid, status))
def isfound(st): return st.startswith('FOUND')
for t in found:
    if not any(isfound(st) for _, st in tests_named.get(t, [])):
        print('check-sec: %s found a hole that the index does not list as FOUND' % t); bad = 1
for t in passed:
    print('check-sec: %s passes but is still in tests/sec-open: move it and mark the row pass' % t); bad = 1
for t, v in tests_named.items():
    for sid, st in v:
        if isfound(st) and t.startswith('sec-') and t not in found and os.path.exists(glob.glob('tests/sec-open/*/%s.*' % t)[0] if glob.glob('tests/sec-open/*/%s.*' % t) else '/nonexistent'):
            print('check-sec: %s says FOUND but the probe %s did not find it' % (sid, t)); bad = 1
# every test file named exists; every sec- file is named
have = set()
for pat in ('tests/sim/sec-*', 'tests/qemu/sec-*', 'tests/sec-open/*/sec-*'):
    for f in glob.glob(pat):
        b = os.path.basename(f)
        if b.endswith(('.S', '.s')): have.add(b.rsplit('.', 1)[0])
for t in have:
    if t not in tests_named: print('check-sec: probe %s is not in the index' % t); bad = 1
for t in tests_named:
    if t.startswith('sec-') and t not in have: print('check-sec: the index names %s, which does not exist' % t); bad = 1
    if not t.startswith('sec-'):
        if not (glob.glob('tests/sim/%s.*' % t) or glob.glob('tests/qemu/%s.*' % t) or glob.glob('tools/%s*' % t) or glob.glob('tools/*/%s*' % t)):
            print('check-sec: the index names %s, which does not exist' % t); bad = 1
print('check-sec: %d holes indexed, %d probes found in the index' % (len(rows), len(have)))
sys.exit(bad)
PY
