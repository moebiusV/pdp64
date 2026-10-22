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
# the 32-bit field of a symbol's immediate or absolute address is range checked: the last data address below 2 GB links, one at 2 GB is refused
# with the symbol named, and the top 2 GB of the address space (a sign-extended 32-bit value) links
"$B/as64" -o "$B/ldhigh.o" tests/ld/high.s
fail=0
"$B/ld64" -Ttext 0x7fffe000 -o "$B/ldhigh.out" "$B/ldhigh.o" 2> "$B/ldhigh.err" || { echo "DIFF link below 2 GB: refused"; fail=1; }
if "$B/ld64" -Ttext 0x7ffff000 -o "$B/ldhigh.out" "$B/ldhigh.o" 2> "$B/ldhigh.err"; then echo "DIFF link at 2 GB: accepted"; fail=1
elif grep -q "relocation to target out of range (value 2147483648" "$B/ldhigh.err"; then echo "ok   link at 2 GB (refused, symbol named)"
else echo "DIFF link at 2 GB: wrong message: $(head -1 $B/ldhigh.err)"; fail=1; fi
"$B/ld64" -Ttext 0xffffffff7ffff000 -o "$B/ldhigh.out" "$B/ldhigh.o" 2> "$B/ldhigh.err" && echo "ok   link in the top 2 GB (sign-extended)" || { echo "DIFF link in the top 2 GB: $(head -1 $B/ldhigh.err)"; fail=1; }
exit $fail
