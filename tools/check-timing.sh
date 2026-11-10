#!/bin/sh
# The timing model against microbenchmarks with hand-derived cycle counts (tests/timing/check_timing.py), 
cd "$(dirname "$0")/.."
tools/build-sim64.sh > /dev/null || exit 1
out=$(python3 tests/timing/check_timing.py "${BUILD:-build}") || { echo "$out" | grep -v '^ok'; exit 1; }
echo "$out" | tail -n 1
