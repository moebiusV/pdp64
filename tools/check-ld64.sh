#!/bin/sh
# Assemble tests/ld/main.s and lib.s, link them, and compare the linked code words and the map with the hand-worked expectations.
set -e
cd "$(dirname "$0")/.."
B=${BUILD:-build}
tools/build-as64.sh > /dev/null
RENAME="-Demit_bits=x_emit_bits"
gcc -g -w -Ias64 -I"$B" -o "$B/ld64" ld64/ld64.c
"$B/as64" -o "$B/ldmain.o" tests/ld/main.s
"$B/as64" -o "$B/ldlib.o" tests/ld/lib.s
"$B/ld64" -M -o "$B/ld.out" "$B/ldmain.o" "$B/ldlib.o" > "$B/ld.map"
python3 - "$B/ld.out" "$B/ld.map" <<'PY'
import struct, sys
d = open(sys.argv[1], 'rb').read()
want = open('tests/ld/link.words').read().split()
got = ['%04x' % struct.unpack_from('<H', d, 0x1000 + 2 * i)[0] for i in range(len(want))]
m = [l.split() for l in open(sys.argv[2]) if l.startswith('0x')]
wm = [l.split() for l in open('tests/ld/link.map')]
bad = got != want or m != wm
print(('DIFF ' if bad else 'ok   ') + 'link (words and map)')
if got != want: print('  got ', ' '.join(got)); print('  want', ' '.join(want))
sys.exit(1 if bad else 0)
PY
