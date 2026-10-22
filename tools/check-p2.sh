#!/bin/sh
# The differential test of page 2: every page-2 word against the page-1 instruction it abbreviates, on the shared core (tests/p2diff.c).
# With --mutate it flips one case and must fail (the proof that a mismatch is caught).
set -e
cd "$(dirname "$0")/.."
tools/build-sim64.sh > /dev/null
B=${BUILD:-build}
python3 tests/p2diff.py "$B/as64" "$B/p2pairs.txt"
gcc -g -w -std=gnu11 -Ias64 -Icommon -I"$B" -o "$B/p2diff" tests/p2diff.c common/pdp64exec.c common/calib.c common/p2.c "$B/fmtp.o" -lm
if [ "${1:-}" = --mutate ]; then
	if "$B/p2diff" "$B/p2pairs.txt" mutate > /dev/null; then echo "FAIL p2diff: the deliberate mismatch was not caught"; exit 1; fi
	echo "ok   p2diff catches a mismatch"
else
	"$B/p2diff" "$B/p2pairs.txt"
fi
