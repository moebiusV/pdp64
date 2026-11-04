#!/bin/sh
# The executor against the tables of the prefix-coded encodings, over every first parcel (tests/exectest-enc.c).
set -e
cd "$(dirname "$0")/.."
tools/build-sim64.sh > /dev/null
B=${BUILD:-build}
gcc -g -w -std=gnu11 -DPDP64_ENC -Ias64 -Icommon -I"$B" -o "$B/exectest-enc" tests/exectest-enc.c common/pdp64exec.c common/calib.c common/p2.c common/pdp64enc.c "$B/pdp64-16-tab.c" "$B/pdp64-32-tab.c" "$B/fmtp.o" -lm
"$B/exectest-enc"
