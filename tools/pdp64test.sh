#!/bin/sh
#
# pdp64test.sh -- compile a C file with the pdp64 ccom, assemble it with as64, link it with a tiny driver and run it
# under sim64: prints what `int test()` returns.  tools/pdp64test.sh of the pdp64 repository, with the target:
#
# usage: [PDP64CCOM=ccom] [PDP64TOOLS=dir-of-as64-ld64-sim64] pdp64test.sh [-m pdp64/16|pdp64/32|pdp64/r20] [ccom flags] x.c
# Defaults: this tree's build/as64, ld64, sim64; the ccom of tools/build-pcc.sh (build/pcc/ccom for r20 and /16, build/pcc/ccom32 for /32).
# With PDP64RUN=qemu the program runs under qemu-system-pdp64 -M pdp64-virt instead (pdp64/r20 only; PDP64_QEMU overrides the binary).
# Without -m the target is pdp64/r20 (the 32-register ccom: pdp64/32).
# PDP64CPP is the preprocessor command (default gcc -E -P -undef -D__pcc__ -D__LP64__ -D_LP64).
#
set -eu
B=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)/build
T=${PDP64TOOLS:-$B}
cpp=${PDP64CPP:-gcc -E -P -undef -D__pcc__ -D__LP64__ -D_LP64}
mode=
flags=
while [ $# -gt 1 ]; do
	case "$1" in
	-m) mode=$2; flags="$flags -m $2"; shift ;;
	*) flags="$flags $1" ;;
	esac
	shift
done
src=$1
case "$mode" in pdp64/32) : ${PDP64CCOM:=$B/pcc/ccom32} ;; *) : ${PDP64CCOM:=$B/pcc/ccom} ;; esac
ccom=$PDP64CCOM
if [ -z "$mode" ]; then
	mode=pdp64/r20
	case "$("$ccom" -m pdp64/32 </dev/null 2>&1 >/dev/null)" in *"built for pdp64/r20"*) ;; *) mode=pdp64/32 ;; esac
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
$cpp "$src" > "$tmp/t.i"
$ccom $flags "$tmp/t.i" "$tmp/t.s"
cat > "$tmp/main.c" <<'EOT'
int test(void);
long write(int, char *, long);
int main(void)
{
	char b[24];
	char *p = b + 24;
	long v = test();
	int neg = v < 0;
	unsigned long u = neg ? -(unsigned long)v : (unsigned long)v;
	*--p = '\n';
	do { *--p = '0' + (int)(u % 10); u /= 10; } while (u);
	if (neg) *--p = '-';
	write(1, p, b + 24 - p);
	return 0;
}
EOT
nomemcpy=0; grep -q "^memcpy:" "$tmp/t.s" && nomemcpy=1
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
$ccom ${mode:+-m $mode} "$tmp/main.c" "$tmp/main.s" 2>/dev/null || { $cpp "$tmp/main.c" > "$tmp/main.i"; $ccom ${mode:+-m $mode} $flags "$tmp/main.i" "$tmp/main.s"; }
if [ $nomemcpy = 1 ]; then awk '/^\t.globl\tmemcpy/{skip=6} skip>0{skip--; next} {print}' "$tmp/crt.s" > "$tmp/crt2.s" && mv "$tmp/crt2.s" "$tmp/crt.s"; fi
for f in t main crt; do "$T/as64" -m "$mode" -o "$tmp/$f.o" "$tmp/$f.s"; done
"$T/ld64" -o "$tmp/t.x" "$tmp/crt.o" "$tmp/main.o" "$tmp/t.o"
if [ "${PDP64RUN:-sim64}" = qemu ]; then
	exec ${PDP64_QEMU:-$HOME/claude/qemu-build/qemu-system-pdp64} -M pdp64-virt -display none -monitor none -serial none -nodefaults -kernel "$tmp/t.x"
fi
"$T/sim64" "$tmp/t.x"
