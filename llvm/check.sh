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
	if ! $LLC $LLCF "$ll" -o "$tmp/$n.s" 2> "$tmp/$n.err"; then why="llc failed"; return 1; fi
	[ -n "${KEEP:-}" ] && { mkdir -p "$KEEP"; cp "$tmp/$n.s" "$KEEP/$n.s"; }
	if ! "$B/as64" -o "$tmp/$n.o" "$tmp/$n.s" > "$tmp/$n.err" 2>&1; then why="as64 failed"; return 1; fi
	if ! "$B/ld64" -o "$tmp/$n.x" "$tmp/crt.o" "$tmp/main.o" "$tmp/$n.o" > "$tmp/$n.err" 2>&1; then why="ld64 failed"; return 1; fi
	got=$(timeout 20 "$B/sim64" "$tmp/$n.x" 2> "$tmp/$n.err")
	if [ "$got" != "$want" ]; then why="got '$got' want '$want'"; return 1; fi
	return 0
}

pass=0; fail=0; failed=
if [ $doll = 1 ]; then
	[ -z "$files" ] && files=$(ls "$here"/tests/*.ll)
	for f in $files; do
		n=$(basename "$f" .ll)
		want=$(sed -n '1s/^; *expect: *\(-\{0,1\}[0-9][0-9]*\).*/\1/p' "$f")
		[ -n "$want" ] || { echo "SKIP $n: no expect line"; continue; }
		if [ $host = 1 ]; then
			printf '#include <stdio.h>\nint test(void);\nint main(void){printf("%%d\\n", test());return 0;}\n' > "$tmp/hm.c"
			hv=$($CLANG -w -O1 -x ir "$f" -x c "$tmp/hm.c" -o "$tmp/h.$n" 2>/dev/null && "$tmp/h.$n")
			[ "$hv" = "$want" ] || echo "HOST DISAGREES $n: x86 says '$hv', expect line says '$want'"
		fi
		why=
		if run_one "$n" "$f" "$want"; then pass=$((pass+1)); echo "ok   $n"
		else
			fail=$((fail+1)); failed="$failed $n"; echo "FAIL $n: $why"
			[ $verbose = 1 ] && head -5 "$tmp/$n.err"
		fi
	done
	echo "llvm tests: $pass passed, $fail failed"
fi

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
[ $fail = 0 ]
