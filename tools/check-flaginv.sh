#!/bin/sh
# The flag invariant (errata 39) over every instruction form: tests/flaginv.py writes the forms, tests/flaginv.c runs them on random states.
set -e
cd "$(dirname "$0")/.."
tools/build-sim64.sh > /dev/null
B=${BUILD:-build}
python3 tests/flaginv.py "$B/as64" "$B/flaginv-forms.txt"
gcc -g -w -std=gnu11 -Ias64 -Icommon -I"$B" -o "$B/flaginv" tests/flaginv.c common/pdp64exec.c common/calib.c common/p2.c "$B/fmtp.o" -lm
"$B/flaginv" "$B/flaginv-forms.txt"
