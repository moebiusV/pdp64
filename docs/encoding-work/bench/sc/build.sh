#!/bin/sh
# build.sh: compile each src/*.c with the pdp64 pcc, assemble with as64, link with ld64 to img/NAME.x.
# Layout assumed: this file is in DIR/ (with src/), and the repository build directory is DIR/../build (pcc/ccom, as64, ld64, sim64).
set -eu
W=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
B=$W/build
CCOM=${PDP64CCOM:-$B/pcc/ccom}
AS=${AS64:-$B/as64}
LD=${LD64:-$B/ld64}
mkdir -p "$W/bench-sc/img" "$W/bench-sc/tmp"
cd "$W/bench-sc"
cat > tmp/main.c <<'EOT'
int test(void);
int main(void) { return test(); }
EOT
cat > tmp/crt.s <<'EOT'
	.text
	.globl	_start
_start:	call	main
	trap	#0
	.globl	write
write:	trap	#1
	ret
EOT
$CCOM tmp/main.c tmp/main.s
$AS -o tmp/main.o tmp/main.s; $AS -o tmp/crt.o tmp/crt.s
for f in src/*.c; do
	n=$(basename $f .c)
	gcc -E -P -undef -D__pcc__ -D__LP64__ -D_LP64 $f > tmp/$n.i
	$CCOM tmp/$n.i tmp/$n.s
	$AS -o tmp/$n.o tmp/$n.s
	$LD -o img/$n.x tmp/crt.o tmp/main.o tmp/$n.o
	echo "built img/$n.x"
done
