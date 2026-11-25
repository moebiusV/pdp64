#!/bin/sh
# The encodings of one instruction are interchangeable (one word names the operation and the assembler picks the form): every instruction of tests/forms/check_forms.py, assembled as
# the shortest form and as `.encode 1`, `.encode 2`, `.encode 3`, leaves the same registers, flags and memory under sim64.
set -e
cd "$(dirname "$0")/.."
tools/build-as64.sh > /dev/null
tools/build-sim64.sh > /dev/null
B=${BUILD:-build}
python3 tests/forms/check_forms.py "$B/as64" "$B/ld64" "$B/sim64" "$B/forms" > "$B/forms.out" || { grep -v '^SKIP' "$B/forms.out"; exit 1; }
grep -v '^SKIP' "$B/forms.out"
