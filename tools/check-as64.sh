#!/bin/sh
# Assemble tests/asm/*.s with as64 and compare the .text words (little-endian parcels) with tests/asm/NAME.words,
# which were worked out by hand from the ISA.
set -e
cd "$(dirname "$0")/.."
tools/build-as64.sh > /dev/null
B=${BUILD:-build}; fail=0
for s in tests/asm/*.s; do
	n=$(basename "$s" .s)
	"$B/as64" $(cat tests/asm/$n.flags 2>/dev/null) -o "$B/$n.o" "$s"
	python3 - "$B/$n.o" "tests/asm/$n" <<'PY' || fail=1
import struct, sys
d = open(sys.argv[1], 'rb').read()
shoff = struct.unpack_from('<Q', d, 0x28)[0]
off, size = struct.unpack_from('<QQ', d, shoff + 64 * 1 + 24)
got = ' '.join('%04x' % struct.unpack_from('<H', d, off + 2 * i)[0] for i in range(size // 2))
want = ' '.join(open(sys.argv[2] + '.words').read().split())
if '...' in want:
    # a long run of zero parcels is written `...`; NAME.total is the number of parcels (tests with a 64 KB gap)
    total = int(open(sys.argv[2] + '.total').read())
    h, tl = (x.split() for x in want.split('...'))
    g = got.split()
    mid = g[len(h):len(g) - len(tl)]
    want = got if (len(g) == total and g[:len(h)] == h and (g[len(g) - len(tl):] if tl else []) == tl and all(x == '0000' for x in mid)) else want
bad = got != want
if bad: print('  .text got ', got); print('  .text want', want)
import os
if os.path.exists(sys.argv[2] + '.bytes'):
    off, size = struct.unpack_from('<QQ', d, shoff + 64 * 2 + 24)
    gd = ' '.join('%02x' % b for b in d[off:off + size])
    wd = ' '.join(open(sys.argv[2] + '.bytes').read().split())
    if gd != wd: bad = True; print('  .data got ', gd); print('  .data want', wd)
print(('DIFF ' if bad else 'ok   ') + sys.argv[1])
if bad: sys.exit(1)
PY
done
# programs that must be refused: tests/asm-err/NAME.s with the expected text of the message in NAME.err
for s in tests/asm-err/*.s; do
	n=$(basename "$s" .s)
	if "$B/as64" -o "$B/err_$n.o" "$s" 2> "$B/err_$n.msg"; then echo "FAIL $n: accepted"; fail=1
	elif grep -q "$(cat tests/asm-err/$n.err)" "$B/err_$n.msg"; then echo "ok   $n (refused)"
	else echo "FAIL $n: wrong message: $(head -1 $B/err_$n.msg)"; fail=1; fi
done
exit $fail
