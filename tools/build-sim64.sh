#!/bin/sh
# Build sim64 (the emulator) and ld64.  The generated parsers and tables come from tools/build-as64.sh.
set -e
cd "$(dirname "$0")/.."
B=${BUILD:-build}
tools/build-as64.sh > /dev/null
CFLAGS=${CFLAGS:--g -w}
python3 tools/mk-exec-tm.py "$B"
gcc $CFLAGS -std=gnu11 -Ias64 -Icommon -I"$B" -o "$B/sim64" sim64/sim64.c "$B/pdp64exec_tm.c" common/timing.c common/pdp64enc.c "$B/pdp64-tab.c" -lm
gcc $CFLAGS -Ias64 -Icommon -I"$B" -o "$B/ld64" ld64/ld64.c common/pdp64enc.c "$B/pdp64-tab.c"
echo "built $B/sim64"
