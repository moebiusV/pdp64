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
bad = got != want or m != wm or flags != 0
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
# an object with an e_flags bit that is not defined (the earlier iterations of the design held a number in the low four bits) is refused
python3 - "$B/ldmain.o" "$B/ldold.o" <<'PY'
import struct, sys
d = bytearray(open(sys.argv[1], 'rb').read()); struct.pack_into('<I', d, 0x30, 2); open(sys.argv[2], 'wb').write(d)
PY
if "$B/ld64" -o "$B/ldold.out" "$B/ldold.o" "$B/ldlib.o" 2> "$B/ldold.err"; then echo "DIFF an object with an undefined e_flags bit: linked"; fail=1
elif grep -q "unknown e_flags" "$B/ldold.err"; then echo "ok   an object with an undefined e_flags bit (refused)"
else echo "DIFF an object with an undefined e_flags bit: wrong message"; fail=1; fi
# the table of check sites (errata 152): the records of two objects, concatenated in the order of the objects, each naming the `bpt` of its check, a file and a line and
# the kind; __start___bug_table and __stop___bug_table bound them; the same linked with and without relaxation
for mode in "--no-relax" ""; do
	"$B/as64" $mode -o "$B/ldchk1.o" $T/chk1.s && "$B/as64" $mode -o "$B/ldchk2.o" $T/chk2.s
	"$B/ld64" $mode -M -o "$B/ldchk.out" "$B/ldchk1.o" "$B/ldchk2.o" > "$B/ldchk.map" || { echo "DIFF check table: link failed"; fail=1; continue; }
	for ins in "ctcc r1, #16" "cteq r2" "chk2 r6, r7, r8"; do n=$(echo "$ins" | tr -c 'a-z0-9\n' _); printf '\t.text\n\t%s\n' "$ins" > "$B/ldchk-$n.s"; "$B/as64" $mode -o "$B/ldchk-$n.o" "$B/ldchk-$n.s"; done
	python3 - "$B/ldchk.out" "$B/ldchk.map" "$mode" "$B" <<'PY' || fail=1
import struct, sys
d = open(sys.argv[1], 'rb').read()
sym = {l.split()[1]: int(l.split()[0], 16) for l in open(sys.argv[2]) if l.startswith('0x')}
a, b = sym['__start___bug_table'], sym['__stop___bug_table']
phdrs = [struct.unpack_from('<IIQQQQQQ', d, 64 + 56 * i) for i in range(2)]
def at(addr):
    for t, f, off, va, pa, fs, ms, al in phdrs:
        if va <= addr < va + fs: return off + addr - va
    raise SystemExit('address %#x is in no segment' % addr)
want = [(1, 'one.c', 7), (2, 'one.c', 9), (3, 'two.c', 31)]
got = []
ok = (b - a) == 12 * len(want)
for i in range((b - a) // 12):
    P = a + 12 * i
    s, f, line, flags = struct.unpack_from('<iiHH', d, at(P))
    site, fl = P + s, P + 4 + f
    o = at(fl); name = d[o:d.index(b'\0', o)].decode()
    got.append((flags >> 5, name, line))
    ins = ['ctcc_r1___16', 'cteq_r2', 'chk2_r6__r7__r8'][i]
    od = open('%s/ldchk-%s.o' % (sys.argv[4], ins), 'rb').read(); so = struct.unpack_from('<Q', od, 0x28)[0]
    toff, tsz = struct.unpack_from('<QQ', od, so + 64 + 24)
    wi = od[toff:toff + tsz]
    if d[at(site):at(site) + len(wi)] != wi: ok = False; print('  record %d: the site %#x does not hold %s' % (i, site, ins))
print(('ok   ' if ok and got == want else 'DIFF ') + 'table of check sites (%s)' % (sys.argv[3] or 'relaxed'))
if got != want: print('  got ', got); print('  want', want)
sys.exit(0 if ok and got == want else 1)
PY
done
exit $fail
