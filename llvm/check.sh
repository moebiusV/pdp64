#!/bin/sh
#
# check.sh -- the tests of the LLVM back end: compile each llvm/tests/*.ll with llc, assemble with as64, link with ld64 against the same tiny crt as
# tools/pdp64test.sh, run under sim64 and compare the printed value of test() with the `; expect: N` of the first line.  Then the C programs of
# tests/c/*.c (first line `/* expect: N ... */`) go through clang -S -emit-llvm (the host's clang; target-independent flags, triple and data layout
# dropped) and llc the same way; the C results are reported, they do not decide the exit status.
#
# usage: llvm/check.sh [-v] [--no-c] [--c-only] [--host] [test.ll ...]
#   -v        show the failing output, keep nothing else
#   --no-c    only the .ll tests;  --c-only  only the C programs
#   --host    also check the expected values against the host's x86 compiler (tests the tests, not the back end)
# environment: LLC (default ../llvm-build/bin/llc), LLC_OPT (default -O2), CLANG (default clang), KEEP=dir to keep the .s files there,
#   COPT (default -O1) the optimisation level of clang for the C programs, CDIRS="a.c b.c" more C programs; tests/c-new/*.c are run too when that directory exists
#
set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
R=$(dirname "$here")
B=$R/build
LLC=${LLC:-$(dirname "$R")/llvm-build/bin/llc}
LLC_OPT=${LLC_OPT:--O2}
CLANG=${CLANG:-clang}
verbose=0; doll=1; doc=1; host=0; files=
for a in "$@"; do
	case $a in
	-v) verbose=1;;
	--no-c) doc=0;;
	--c-only) doll=0;;
	--host) host=1;;
	*) files="$files $a";;
	esac
done
explicit=$files
"$R/tools/gen-llvm-td.py" --check || echo "warning: llvm/target/PDP64/gen is stale (tools/gen-llvm-td.py)" >&2
[ -x "$LLC" ] || { echo "no llc at $LLC (llvm/build.sh)" >&2; exit 2; }
for t in as64 ld64 sim64; do [ -x "$B/$t" ] || { echo "no $B/$t" >&2; exit 2; }; done
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# a private copy of the tools: they may be rebuilt by other work while this runs
mkdir "$tmp/bin" && cp "$B/as64" "$B/ld64" "$B/sim64" "$tmp/bin/" && B=$tmp/bin
LLCF="-mtriple=pdp64-unknown-elf $LLC_OPT"

# the crt of tools/pdp64test.sh (memcpy, memmove and memset are the block instructions)
cat > "$tmp/crt.s" <<'EOT'
	.text
	.globl	_start
_start:	call	main
	trap	#0
	.globl	write
write:	trap	#1
	ret
	.globl	memcpy
memcpy:	movq	r0, r3
	mcpy	r0, r1, r2
	movq	r3, r0
	ret
	.globl	memmove
memmove: movq	r0, r3
	mmov	r0, r1, r2
	movq	r3, r0
	ret
	.globl	memset
memset:	movq	r0, r3
	mset	r0, r1, r2
	movq	r3, r0
	ret
EOT
"$B/as64" -o "$tmp/crt.o" "$tmp/crt.s" || exit 2
$LLC $LLCF "$here/tests/lib/main.ll" -o "$tmp/main.s" && "$B/as64" -o "$tmp/main.o" "$tmp/main.s" || { echo "the driver tests/lib/main.ll does not build" >&2; exit 2; }

# run_ll name file.ll expect : 0 pass, 1 fail
run_one() {
	n=$1; ll=$2; want=$3
	if ! $LLC $LLCF ${XFLAGS:-} "$ll" -o "$tmp/$n.s" 2> "$tmp/$n.err"; then why="llc failed: $(head -2 "$tmp/$n.err")"; return 1; fi
	[ -n "${KEEP:-}" ] && { mkdir -p "$KEEP"; cp "$tmp/$n.s" "$KEEP/$n.s"; }
	if ! "$B/as64" -o "$tmp/$n.o" "$tmp/$n.s" > "$tmp/$n.err" 2>&1; then why="as64 failed"; return 1; fi
	if ! "$B/ld64" -o "$tmp/$n.x" "$tmp/crt.o" "$tmp/main.o" "$tmp/$n.o" > "$tmp/$n.err" 2>&1; then why="ld64 failed"; return 1; fi
	case $want in
	fault|fault:*)
		# `; expect: fault` the program must stop with a fault of the check instructions: sim64's message "check failed" and the exit status 139;
		# `; expect: fault:REGEX` any fault whose message matches (sim64 prints it with the exit status 139)
		pat=${want#fault:}; [ "$want" = fault ] && pat="check failed"
		got=$(timeout 20 "$B/sim64" "$tmp/$n.x" 2> "$tmp/$n.err"); rc=$?
		if [ $rc != 139 ] || ! grep -q "$pat" "$tmp/$n.err"; then why="wanted the fault '$pat' (status 139), got status $rc: $(head -1 "$tmp/$n.err")"; return 1; fi;;
	*)
		got=$(timeout 20 "$B/sim64" "$tmp/$n.x" 2> "$tmp/$n.err")
		if [ "$got" != "$want" ]; then why="got '$got' want '$want'"; return 1; fi;;
	esac
	# `; asm: REGEX` / `; noasm: REGEX` lines of the test: the assembly must / must not match (egrep)
	if [ -n "$ll" ]; then
		sed -n 's/^; asm: //p' "$ll" | while IFS= read -r pat; do grep -Eq -- "$pat" "$tmp/$n.s" || { echo "asm lacks: $pat" > "$tmp/$n.asm"; }; done
		[ -n "${XFLAGS:-}" ] && sed -n 's/^; asm-vec: //p' "$ll" | while IFS= read -r pat; do grep -Eq -- "$pat" "$tmp/$n.s" || { echo "asm lacks (vec variant): $pat" > "$tmp/$n.asm"; }; done
		sed -n 's/^; noasm: //p' "$ll" | while IFS= read -r pat; do grep -Eq -- "$pat" "$tmp/$n.s" && { echo "asm has: $pat" > "$tmp/$n.asm"; }; done
		if [ -s "$tmp/$n.asm" ]; then why=$(cat "$tmp/$n.asm"); rm -f "$tmp/$n.asm"; return 1; fi
	fi
	return 0
}

pass=0; fail=0; failed=
rm -f "$tmp/res.pass" "$tmp/res.fail"
if [ $doll = 1 ]; then
	[ -z "$files" ] && files=$(ls "$here"/tests/*.ll)
	for f in $files; do
		n=$(basename "$f" .ll)
		want=$(sed -n '1s/^; *expect: *\(-\{0,1\}[0-9][0-9]*\|fault[^ ]*\).*/\1/p' "$f")
		[ -n "$want" ] || { echo "SKIP $n: no expect line"; continue; }
		if [ $host = 1 ] && [ "${want#fault}" = "$want" ]; then
			printf '#include <stdio.h>\nint test(void);\nint main(void){printf("%%d\\n", test());return 0;}\n' > "$tmp/hm.c"
			hv=$($CLANG -w -O1 -x ir "$f" -x c "$tmp/hm.c" -o "$tmp/h.$n" 2>/dev/null && "$tmp/h.$n")
			[ "$hv" = "$want" ] || echo "HOST DISAGREES $n: x86 says '$hv', expect line says '$want'"
		fi
		# `; llc: FLAGS` lines of a test are variants: the test is run once for each (no such line: once, with no extra flags)
		variants=$(sed -n 's/^; llc:\(.*\)$/\1/p' "$f")
		[ -n "$variants" ] || variants="-"
		echo "$variants" | while IFS= read -r v; do
			XFLAGS=$v; [ "$v" = "-" ] && { XFLAGS=; v=; }
			why=
			if run_one "$n" "$f" "$want"; then echo "ok   $n${v:+ [$v]}" >> "$tmp/res.pass"; echo "ok   $n${v:+ [$v]}"
			else echo "x" >> "$tmp/res.fail"; echo "FAIL $n${v:+ [$v]}: $why"; [ $verbose = 1 ] && head -5 "$tmp/$n.err"; fi
		done
	done
	pass=$( [ -f "$tmp/res.pass" ] && wc -l < "$tmp/res.pass" || echo 0 ); fail=$( [ -f "$tmp/res.fail" ] && wc -l < "$tmp/res.fail" || echo 0 )
	echo "llvm tests: $pass passed, $fail failed (a test with several \`; llc:\` variants counts once for each)"
fi


# the vector kernels: tests/vec/*.c, first line `/* expect: N  vec: K  flags: CLANGFLAGS */`.  Each is compiled by clang (-O2, no vectoriser) and run twice: with
# llc as it is (scalar) and with -pdp64-vecloop (the loops become vec blocks); both must print N, and the vec build must contain K blocks (`vec rS, rE` lines).
vsection() {
	cpass=0; cfail=0
	for f in "$@"; do
		[ -f "$f" ] || continue
		kn=v_$(basename "$f" .c)
		want=$(sed -n '1s/^\/\* *expect: *\(-\{0,1\}[0-9][0-9]*\).*/\1/p' "$f")
		wantvec=$(sed -n '1s/.*vec: *\([0-9][0-9]*\).*/\1/p' "$f")
		cflags=$(sed -n '1s/.*flags: *\(.*[^ ]\) *\*\/.*/\1/p' "$f")
		[ -n "$want" ] || continue
		if [ $host = 1 ]; then
			printf '#include <stdio.h>\nint test(void);\nint main(void){printf("%%d\\n", test());return 0;}\n' > "$tmp/hm.c"
			hv=$($CLANG -w -O1 $cflags -x c "$f" -x c "$tmp/hm.c" -o "$tmp/h.$kn" 2>/dev/null && "$tmp/h.$kn")
			[ "$hv" = "$want" ] || echo "HOST DISAGREES $kn: x86 says '$hv', expect line says '$want'"
		fi
		if ! $CLANG -S -emit-llvm -O2 -m64 -fno-builtin -ffreestanding -fno-stack-protector -mlong-double-64 -mno-sse -mno-mmx \
		    -fno-vectorize -fno-slp-vectorize -fno-unroll-loops -fno-discard-value-names -w $cflags -o "$tmp/$kn.ll0" "$f" 2> "$tmp/$kn.err"; then
			cfail=$((cfail+1)); echo "FAIL $kn: clang failed"; continue
		fi
		sed -e '/^target datalayout/d' -e '/^target triple/d' -e 's/"target-cpu"="[^"]*"//g' -e 's/"target-features"="[^"]*"//g' \
		    -e 's/"tune-cpu"="[^"]*"//g' "$tmp/$kn.ll0" > "$tmp/$kn.ll"
		for v in scalar vec strip; do
			XFLAGS=; [ $v = vec ] && XFLAGS=-pdp64-vecloop; [ $v = strip ] && XFLAGS="-pdp64-vecloop -pdp64-vecloop-strip"
			why=; ok=0
			if run_one "$kn.$v" "$tmp/$kn.ll" "$want"; then
				ok=1
				if [ $v != scalar ]; then
					nb=$(grep -c '^[[:space:]]*vec[[:space:]]' "$tmp/$kn.$v.s")
					wv=$wantvec; [ $v = strip ] && wv=$((wantvec * 2))   # the strip form has the block twice: in the loop and for the remainder
					if [ -n "$wantvec" ] && [ "$nb" != "$wv" ]; then why="$nb vec blocks, wanted $wv"; ok=0; fi
				fi
			fi
			if [ $ok = 1 ]; then cpass=$((cpass+1)); echo "ok   $kn [$v]"
			else cfail=$((cfail+1)); echo "FAIL $kn [$v]: $why"; fi
		done
	done
	echo "vector kernels (tests/vec) scalar, with -pdp64-vecloop and with -pdp64-vecloop-strip: $cpass passed, $cfail failed"
}

# the C programs: tests/c/*.c, and tests/c-new/*.c if that directory exists (CDIRS= adds more files)
csection() {
	label=$1; shift
	cpass=0; cfail=0
	for f in "$@"; do
		[ -f "$f" ] || continue
		n=c_$(basename "$f" .c)
		want=$(sed -n '1s/^\/\* *expect: *\(-\{0,1\}[0-9][0-9]*\).*/\1/p' "$f")
		[ -n "$want" ] || continue
		why=
		if $CLANG -S -emit-llvm ${COPT:--O1} -m64 -fno-builtin -ffreestanding -fno-stack-protector -mlong-double-64 -mno-sse -mno-mmx \
		    -fno-vectorize -fno-slp-vectorize -fno-unroll-loops -fno-discard-value-names -w -o "$tmp/$n.ll0" "$f" 2> "$tmp/$n.err" &&
		   sed -e '/^target datalayout/d' -e '/^target triple/d' -e 's/"target-cpu"="[^"]*"//g' -e 's/"target-features"="[^"]*"//g' \
		       -e 's/"tune-cpu"="[^"]*"//g' "$tmp/$n.ll0" > "$tmp/$n.ll"; then
			if run_one "$n" "$tmp/$n.ll" "$want"; then cpass=$((cpass+1)); echo "ok   $n"
			else cfail=$((cfail+1)); echo "FAIL $n: $why"; [ $verbose = 1 ] && head -5 "$tmp/$n.err"; fi
		else cfail=$((cfail+1)); echo "FAIL $n: clang failed"; fi
	done
	echo "C programs ($label) through clang + llc: $cpass passed, $cfail failed"
}
if [ $doc = 1 ] && [ -z "$explicit" ]; then
	csection tests/c "$R"/tests/c/*.c
	[ -d "$R/tests/c-new" ] && csection tests/c-new "$R"/tests/c-new/*.c
	[ -n "${CDIRS:-}" ] && csection CDIRS $CDIRS
fi
if [ $doc = 1 ] && [ -z "$explicit" ] && [ -d "$here/tests/vec" ]; then
	vsection "$here"/tests/vec/*.c
	fail=$((fail + cfail))
fi
[ $fail = 0 ]
