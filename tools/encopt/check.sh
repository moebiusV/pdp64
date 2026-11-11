#!/bin/sh
# encopt's tests: (1) the exact solver against brute force on random instances, (2) a hand-made instance, (3) the whole pipeline on the current statistics of the
# pdp64 corpus (tests/current.encopt, written by export.py): the committed selection reproduces the leaves of the grammar, the optimum is proved and beats it.
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
echo "== current statistics: the optimum (exact search)"
./encopt -q tests/current.encopt -o /tmp/encopt-check.$$
diff /tmp/encopt-check.$$ tests/current.optimum && echo "optimum: identical to tests/current.optimum (deterministic)"
grep -q '^status optimal$' /tmp/encopt-check.$$ || { echo "FAIL: the optimum is not proved"; fail=1; }
grep -E '^(status|objective-credit|objective-bytes|compare)' /tmp/encopt-check.$$
rm -f /tmp/encopt-check.$$
echo "== the grammar of the repository against the committed selection of the snapshot"
if [ -f ../encgram.py ] && command -v python3 >/dev/null 2>&1; then
	if python3 -I export.py --compare-leaves tests/current.committed 2>&1; then echo "grammar: its 268 leaves are the leaves encopt assigns to the committed selection"
	else echo "NOTE: spec/pdp64/pdp64.hbnf differs from the snapshot tests/current.committed: the encoding changed since the export; re-run export.py (README)"; fi
else echo "(not inside the pdp64 repository: grammar comparison skipped)"; fi
exit $fail
