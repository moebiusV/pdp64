#!/bin/sh
# Linker relaxation (docs/relaxation.md): the generated program of tests/relax/gen_relax.py (calls, leas, branches across them, pools, paddings, tables of code
# addresses) and every program of tests/sim run relaxed (as64 --relax, ld64) and unrelaxed (ld64 --no-relax): the same result; every relaxed image decoded with
# the C decoder and checked (tools/relaxcheck.c: every instruction where the assembler's own list says it is, branches and calls on instruction starts, pool loads
# aligned, symbols on instruction starts); the text is smaller; errors still reported.  `--mutate`: ld64 with a deliberate fault each, which must be caught.
set -u
cd "$(dirname "$0")/.."
B=${BUILD:-build}; fail=0; n=0
tools/build-sim64.sh > /dev/null
gcc -g -w -Icommon -I"$B" -o "$B/relaxcheck" tools/relaxcheck.c common/pdp64enc.c "$B/pdp64-tab.c" || exit 1
W=$B/relax; mkdir -p $W
LD=$B/ld64
[ "${1:-}" = "--mutate" ] && { LD=$B/ld64-mut; MUT=1; } || MUT=0

# link OBJS relaxed and unrelaxed, run both, check the relaxed (and the unrelaxed) image; $1 name, $2 expected exit, rest objects.  Sets $rsize $nsize.
case_run() {
	t=$1; want=$2; shift 2
	if ! $LD --dump-map "$W/$t.map" -o "$W/$t.x" "$@" 2> "$W/$t.lderr"; then echo "FAIL $t: link: $(head -1 "$W/$t.lderr")"; return 1; fi
	$LD --no-relax --dump-map "$W/$t.nmap" -o "$W/$t.nx" "$@" 2>> "$W/$t.lderr" || { echo "FAIL $t: link --no-relax: $(head -1 "$W/$t.lderr")"; return 1; }
	"$B/sim64" "$W/$t.x" > "$W/$t.out" 2> "$W/$t.err"; r1=$?
	"$B/sim64" "$W/$t.nx" > "$W/$t.nout" 2> "$W/$t.nerr"; r2=$?
	if [ $r1 != $want ] || [ $r2 != $want ] || ! cmp -s "$W/$t.out" "$W/$t.nout"; then echo "FAIL $t: exit $r1 (relaxed) $r2 (unrelaxed), wanted $want, or the output differs"; return 1; fi
	for v in "" n; do
		python3 tools/check-relax.py "$W/$t.${v}map" > "$W/$t.${v}starts" || { echo "FAIL $t: starts"; return 1; }
		if ! "$B/relaxcheck" "$W/$t.${v}x" "$W/$t.${v}starts" > "$W/$t.${v}rc" 2>&1; then echo "FAIL $t (${v:-relaxed}${v:+unrelaxed}): $(head -2 "$W/$t.${v}rc" | tr '\n' ' ')"; return 1; fi
	done
	rsize=$(stat -c %s "$W/$t.x"); nsize=$(stat -c %s "$W/$t.nx")
	return 0
}
textsize() { "$B/ld64" --no-relax -M -o /dev/null "$@" 2>/dev/null | sed -n 1p | sed 's/.*+//'; }

gen() {	# seed
	sd=$1; t=gen.$sd; d=$W/$t
	python3 tests/relax/gen_relax.py $d $sd
	"$B/as64" --relax --dump-lens $d/main.o.lens -o $d/main.o $d/main.s && "$B/as64" --relax --dump-lens $d/lib.o.lens -o $d/lib.o $d/lib.s || { echo "FAIL $t: assembly"; fail=$((fail+1)); return; }
	n=$((n+1))
	"$B/as64" --no-relax -o $d/mainp.o $d/main.s && "$B/as64" --no-relax -o $d/libp.o $d/lib.s
	if case_run $t 0 $d/main.o $d/lib.o; then
		# --no-relax of the relaxed objects is the link of the plain ones, byte for byte
		"$B/ld64" -o $W/$t.px $d/mainp.o $d/libp.o && cmp -s $W/$t.px $W/$t.nx || { echo "FAIL $t: ld64 --no-relax of the relaxed objects differs from the link of the objects without --relax"; fail=$((fail+1)); }
		rt=$(sed -n 's/^relaxcheck: \([0-9]*\) instructions.*/\1/p' $W/$t.rc)
		tr=$(sed -n 's/.*text \([0-9]*\) bytes.*/\1/p' $W/$t.lderr)
		echo "ok   generated program, seed $sd: $rt instructions, relaxed image $rsize bytes, unrelaxed $nsize"
		[ "$rsize" -lt "$nsize" ] || { echo "FAIL $t: the relaxed image is not smaller"; fail=$((fail+1)); }
	else fail=$((fail+1)); fi
}
if [ $MUT = 1 ]; then
	# each mutant of ld64 must fail the generated program (or a program of tests/sim) in some way
	mkdir -p $W/mut
	i=0
	while IFS='|' read -r file from to; do
		i=$((i+1))
		cp ld64/ld64.c ld64/relax.c $W/mut/
		python3 - "$W/mut/$file" "$from" "$to" <<'PY' || { echo "FAIL mutant $i: the text to change is not in $file"; fail=$((fail+1)); continue; }
import sys
f, a, b = sys.argv[1:4]
s = open(f).read()
if s.count(a) != 1: sys.exit(1)
open(f, 'w').write(s.replace(a, b))
PY
		gcc -g -w -Ias64 -Icommon -I"$B" -I$W/mut -o $LD $W/mut/ld64.c common/pdp64enc.c "$B/pdp64-tab.c" 2>"$W/mut/cc.err" || { echo "FAIL mutant $i: does not compile"; fail=$((fail+1)); continue; }
		if (fail=0; gen 1 > "$W/mut/out"; [ $fail = 0 ] && ! grep -q '^FAIL' "$W/mut/out"); then echo "FAIL mutant $i ($from -> $to) was not caught"; fail=$((fail+1)); else echo "ok   mutant $i caught"; fi
		n=$((n+1))
	done <<'MUTANTS'
ld64.c|return s->nsites ? x + s->cum[lo] : x;|return x;
ld64.c|t->cur = (uint32_t)((t->align - pos % t->align) % t->align);|t->cur = t->len0;
relax.c|if (n && (uint32_t)(2 * n) > t->cur) { t->cur = 2 * n; grown++; }|if (n) grown += 0;
ld64.c|else *V = (int64_t)isec_addr(&objs[s->obj], s->sec, (int64_t)s->value + r->addend);|else *V = (int64_t)(cbase[objs[s->obj].cls[s->sec]] + objs[s->obj].is[s->sec].outoff + s->value + r->addend);
ld64.c|*V = (int64_t)isec_addr(o, y->shndx, r->addend);|*V = (int64_t)(cbase[o->cls[y->shndx]] + o->is[y->shndx].outoff + r->addend);
ld64.c|else s->addr = isec_addr(&objs[s->obj], s->sec, (int64_t)s->value);|else s->addr = cbase[objs[s->obj].cls[s->sec]] + objs[s->obj].is[s->sec].outoff + s->value;
relax.c|memcpy(d, s->data + old, t->off - old);|memcpy(d, s->data + old, t->off - old); if (t->kind == SK_ALIGN && t->cur > 2) t->cur -= 2;
MUTANTS
	echo "relax mutants: $n run, $fail failed"
	[ $fail = 0 ]; exit $?
fi

gen 1
gen 2
# every program of tests/sim relaxed: the images are checked (check-sim64.sh runs them and compares the results)
for dir in tests/sim; do
	for s in $dir/*.s; do
		t=$(basename "$s" .s)
		[ -f "$dir/$t.same" ] && continue
		[ $t = fused ] && continue		# calls an unmapped address on purpose
		for e in x; do
			o=$W/s_$t.$e.o
			"$B/as64" --relax --dump-lens $o.lens -o $o "$s" 2>/dev/null || { echo "FAIL $t ($e): assembly"; fail=$((fail+1)); continue; }
			$LD --dump-map $W/s_$t.$e.map -o $W/s_$t.$e.x $o 2>$W/s_$t.$e.err || { echo "FAIL $t ($e): link"; fail=$((fail+1)); continue; }
			python3 tools/check-relax.py $W/s_$t.$e.map > $W/s_$t.$e.starts
			n=$((n+1))
			"$B/relaxcheck" $W/s_$t.$e.x $W/s_$t.$e.starts > $W/s_$t.$e.rc 2>&1 || { echo "FAIL $t ($e): $(head -2 $W/s_$t.$e.rc | tr '\n' ' ')"; fail=$((fail+1)); }
		done
	done
done
echo "ok   $n images so far decode and are consistent"
# NOADJ_TEXT: the object is marked, the text is not adjusted, the program runs; a relaxed object and an unrelaxed one of the same encoding link together
for e in x; do
	"$B/as64" --relax --dump-lens $W/noadj.$e.o.lens -o $W/noadj.$e.o tests/relax/noadj.s && "$B/as64" --relax --dump-lens $W/noadjlib.$e.o.lens -o $W/noadjlib.$e.o tests/relax/noadj-lib.s || { echo "FAIL noadj ($e): assembly"; fail=$((fail+1)); continue; }
	flags=$(python3 -c "import struct,sys; print(struct.unpack_from('<I', open(sys.argv[1],'rb').read(), 0x30)[0])" $W/noadj.$e.o)
	n=$((n+1))
	if [ $flags = $(( 2 | 0x30 )) ]; then
		if case_run noadj$e 0 $W/noadj.$e.o $W/noadjlib.$e.o; then echo "ok   noadj ($e): e_flags $flags, the text is as assembled"; [ "$rsize" = "$nsize" ] || { echo "FAIL noadj ($e): the text of a NOADJ object changed"; fail=$((fail+1)); }
		else fail=$((fail+1)); fi
	else echo "FAIL noadj ($e): e_flags $flags (wanted RELAX|NOADJ_TEXT)"; fail=$((fail+1)); fi
done
# the 2 GB limit is still reported, with the symbol named
for e in x; do
	"$B/as64" --relax -o $W/high$e.o tests/ld/high.s
	n=$((n+1))
	$LD -Ttext 0x7fffe000 -o $W/high.x $W/high$e.o 2>$W/high.err || { echo "FAIL relaxed link below 2 GB: refused"; fail=$((fail+1)); }
	if $LD -Ttext 0x7ffff000 -o $W/high.x $W/high$e.o 2>$W/high.err; then echo "FAIL relaxed link at 2 GB: accepted"; fail=$((fail+1))
	elif grep -q "relocation to target out of range (value 2147483648" $W/high.err; then echo "ok   relaxed link at 2 GB (refused, symbol named)"
	else echo "FAIL relaxed link at 2 GB: wrong message: $(head -1 $W/high.err)"; fail=$((fail+1)); fi
done
# --no-relax objects have no relaxation flags; the default is a relaxation object
"$B/as64" -o $W/x.o tests/relax/noadj-lib.s && "$B/as64" --no-relax -o $W/y.o tests/relax/noadj-lib.s && python3 - $W/x.o $W/y.o <<'PY' && echo "ok   as64 makes relaxation objects by default; --no-relax does not" || { echo "FAIL as64 default flags"; fail=$((fail+1)); }
import struct, sys
f = [struct.unpack_from('<I', open(p, 'rb').read(), 0x30)[0] for p in sys.argv[1:3]]
sys.exit(0 if f == [0x12, 0x2] else 1)
PY
n=$((n+1))
echo "relax: $n run, $fail failed"
[ $fail = 0 ]
