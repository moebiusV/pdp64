#!/bin/sh
# Assemble tests/ld/main.s and lib.s, link them, and compare the linked code words and the map with the expected ones (worked out with the Python model of the
# encoding, docs/codegen-data/encoding/enc.py); the relaxed link against the model's own relaxation; the 32-bit limits of a symbol's immediate or absolute address.
set -e
cd "$(dirname "$0")/.."
B=${BUILD:-build}
tools/build-as64.sh > /dev/null
gcc -g -w -Ias64 -Icommon -I"$B" -o "$B/ld64" ld64/ld64.c common/pdp64enc.c "$B/pdp64-tab.c"
fail=0
T=tests/ld
"$B/as64" --no-relax -o "$B/ldmain.o" $T/main.s
"$B/as64" --no-relax -o "$B/ldlib.o" $T/lib.s
"$B/ld64" -M -o "$B/ld.out" "$B/ldmain.o" "$B/ldlib.o" > "$B/ld.map"
python3 - "$B/ld.out" "$B/ld.map" $T <<'PY' || fail=1
import struct, sys
d = open(sys.argv[1], 'rb').read()
T = sys.argv[3]
want = open(T + '/link.words').read().split()
got = ['%04x' % struct.unpack_from('<H', d, 0x1000 + 2 * i)[0] for i in range(len(want))]
m = [l.split() for l in open(sys.argv[2]) if l.startswith('0x')]
wm = [l.split() for l in open(T + '/link.map')]
flags = struct.unpack_from('<I', d, 0x30)[0]
bad = got != want or m != wm or flags != 2
print(('DIFF ' if bad else 'ok   ') + 'link (words, map, e_flags %d)' % flags)
if got != want: print('  got ', ' '.join(got)); print('  want', ' '.join(want))
sys.exit(1 if bad else 0)
PY
# the relaxed link (the default) against the model's own relaxation
"$B/as64" -o "$B/ldmainr.o" $T/main.s && "$B/as64" -o "$B/ldlibr.o" $T/lib.s && "$B/ld64" -o "$B/ldr.out" "$B/ldmainr.o" "$B/ldlibr.o" && python3 tools/check-ld-relax.py "$B/ldr.out" || fail=1
# the 32-bit field of a symbol's immediate or absolute address is range checked: the last data address below 2 GB links, one at 2 GB is refused
# with the symbol named, and the top 2 GB of the address space (a sign-extended 32-bit value) links
"$B/as64" --no-relax -o "$B/ldhigh.o" $T/high.s
"$B/ld64" -Ttext 0x7fffe000 -o "$B/ldhigh.out" "$B/ldhigh.o" 2> "$B/ldhigh.err" || { echo "DIFF link below 2 GB: refused"; fail=1; }
if "$B/ld64" -Ttext 0x7ffff000 -o "$B/ldhigh.out" "$B/ldhigh.o" 2> "$B/ldhigh.err"; then echo "DIFF link at 2 GB: accepted"; fail=1
elif grep -q "relocation to target out of range (value 2147483648" "$B/ldhigh.err"; then echo "ok   link at 2 GB (refused, symbol named)"
else echo "DIFF link at 2 GB: wrong message: $(head -1 $B/ldhigh.err)"; fail=1; fi
"$B/ld64" -Ttext 0xffffffff7ffff000 -o "$B/ldhigh.out" "$B/ldhigh.o" 2> "$B/ldhigh.err" && echo "ok   link in the top 2 GB (sign-extended)" || { echo "DIFF link in the top 2 GB: $(head -1 $B/ldhigh.err)"; fail=1; }
# an object of another instruction set (the earlier iterations of the design: e_flags 0 or 1) is refused
python3 - "$B/ldmain.o" "$B/ldold.o" <<'PY'
import struct, sys
d = bytearray(open(sys.argv[1], 'rb').read()); struct.pack_into('<I', d, 0x30, 1); open(sys.argv[2], 'wb').write(d)
PY
if "$B/ld64" -o "$B/ldold.out" "$B/ldold.o" "$B/ldlib.o" 2> "$B/ldold.err"; then echo "DIFF an object of another instruction set: linked"; fail=1
elif grep -q "not the pdp64" "$B/ldold.err"; then echo "ok   an object of another instruction set (refused)"
else echo "DIFF an object of another instruction set: wrong message"; fail=1; fi
exit $fail
