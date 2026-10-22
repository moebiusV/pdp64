#!/bin/sh
# Build sim64 (the emulator) and ld64.  The generated parsers come from tools/build-as64.sh.
set -e
cd "$(dirname "$0")/.."
B=${BUILD:-build}
tools/build-as64.sh > /dev/null
[ -f "$B/fmtp.o" ]
CFLAGS=${CFLAGS:--g -w}
gcc $CFLAGS -std=gnu11 -Ias64 -Icommon -I"$B" -o "$B/sim64" sim64/sim64.c common/pdp64exec.c common/calib.c "$B/fmtp.o" -lm
gcc $CFLAGS -Ias64 -I"$B" -o "$B/ld64" ld64/ld64.c
echo "built $B/sim64"
