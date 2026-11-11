#!/bin/sh
# encopt's tests: (1) the exact solver against brute force on random instances (the three objectives in turn), (2) hand-made instances (static; static, fetch and exec with
# three different answers), (3) the whole pipeline on the current statistics of the pdp64 corpus and the profile of five programs (tests/current.encopt, written by export.py):
# the committed selection reproduces the leaves of the grammar, the optima of the three objectives are proved and byte-identical to the committed ones, (4) the corrected
# reader of the exporter and the weights file (tests/test_reader.py), (5) with the compiler and simulator built: the profile collector on tests/c.
set -e
cd "$(dirname "$0")"
make -s encopt tests/test_random >/dev/null
fail=0
echo "== random instances against brute force"
tests/test_random "${ENCOPT_RANDOM:-150}" 20261110
echo "== small instance"
./encopt -q tests/small.encopt | diff - tests/small.expected && echo "small: identical to tests/small.expected"
echo "== current statistics: the committed selection"
./encopt -q -C tests/current.encopt | diff - tests/current.committed && echo "committed: identical to tests/current.committed"
echo "== the three objectives on the hand-made instance tests/small2.encopt (static picks A, fetch B, exec C)"
for o in static fetch exec; do
	./encopt -q -O $o tests/small2.encopt | diff - tests/small2.$o.expected && echo "small2 $o: identical to tests/small2.$o.expected"
done
./encopt -q -O fetch tests/small.encopt >/dev/null 2>&1 && echo "small (version 1 input) accepts -O fetch"
echo "== current statistics, no reserve (budget 65,536 patterns): the optimum of each objective (exact search)"
for o in static fetch exec; do
	f=tests/current.$o; [ $o = static ] && f=tests/current.optimum
	./encopt -q -O $o tests/current.encopt -o /tmp/encopt-check.$$
	diff /tmp/encopt-check.$$ $f && echo "$o: identical to $f (deterministic)"
	grep -q '^status optimal$' /tmp/encopt-check.$$ || { echo "FAIL: the $o optimum is not proved"; fail=1; }
	grep -E '^(objective |status|objective-credit|metrics encopt)' /tmp/encopt-check.$$
done
rm -f /tmp/encopt-check.$$
echo "== an objective that needs a profile is refused without one"
grep -v '^demand' tests/current.encopt > /tmp/encopt-nodem.$$; ( grep '^demand' tests/current.encopt | awk '{ $3 = 0; print }' ) >> /tmp/encopt-nodem.$$
if ./encopt -q -O fetch /tmp/encopt-nodem.$$ >/dev/null 2>/tmp/encopt-err.$$; then echo "FAIL: -O fetch without dynamic counts was accepted"; fail=1; else echo "refused: $(cat /tmp/encopt-err.$$)"; fi
rm -f /tmp/encopt-nodem.$$ /tmp/encopt-err.$$
echo "== the corrected reader (set cc,rd is a condition and a register, not a label) and the weights file"
if command -v python3 >/dev/null 2>&1; then python3 -I tests/test_reader.py || fail=1; else echo "(no python3: skipped)"; fi
echo "== the profile collector (needs build/pcc/ccom, as64, ld64, sim64)"
B=../../build
if [ -x $B/pcc/ccom ] && [ -x $B/as64 ] && [ -x $B/ld64 ] && [ -x $B/sim64 ] && command -v python3 >/dev/null 2>&1; then
	python3 -I profile.py -o /tmp/encopt-prof.$$ --tests ../../tests/c --summary /tmp/encopt-prof.$$.sum 2>&1 | tail -3
	grep -q '^encopt-weights 1$' /tmp/encopt-prof.$$ && grep -q '^weight dynamic [0-9]* ret$' /tmp/encopt-prof.$$ && echo "profile: weights written, the counts add up to the instructions of sim64 -P (checked inside profile.py)" || { echo "FAIL: the profile"; fail=1; }
	rm -f /tmp/encopt-prof.$$ /tmp/encopt-prof.$$.sum
else echo "(compiler or simulator not built: skipped)"; fi
echo "== the grammar of the repository against the committed selection of the snapshot"
if [ -f ../encgram.py ] && command -v python3 >/dev/null 2>&1; then
	if python3 -I export.py --compare-leaves tests/current.committed 2>&1; then echo "grammar: its 268 leaves are the leaves encopt assigns to the committed selection"
	else echo "NOTE: spec/pdp64/pdp64.hbnf differs from the snapshot tests/current.committed: the encoding changed since the export; re-run export.py (README)"; fi
else echo "(not inside the pdp64 repository: grammar comparison skipped)"; fi
exit $fail
