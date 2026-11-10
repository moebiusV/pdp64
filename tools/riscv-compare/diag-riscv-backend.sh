#!/bin/sh
# diag-riscv-backend.sh WORK -- the probes of the report's section "pcc's RISC-V back end: status".
# needs: WORK/pcc/rv (riscv64 ccom, tools/riscv-compare/build-ccoms.sh), WORK/pcc/rv32 (the same tree configured for riscv32: see README),
#        WORK/gccx/prefix/bin/riscv64-unknown-elf-{as,ld} (build-gcc-riscv.sh), qemu-riscv32 (user mode).
# Prints, for each probe, what ccom says; for the rv32 run tests, the exit status of the program under qemu-riscv32.
W=${1:?WORK}
RV64=$W/pcc/rv/cc/ccom/riscv64-unknown-linux-ccom
RV32=$W/pcc/rv32/cc/ccom/riscv32-unknown-linux-ccom
B=$W/gccx/prefix/bin
T=$(mktemp -d)
cd "$T" || exit 1
probe() { printf '%s\n' "$2" > "$1.i"; echo "--- $1: $2"; "$RV64" "$1.i" "$1.s" 2>&1 | head -3; }
probe sizes 'char a[sizeof(long)==8?1:-1]; char b[sizeof(void*)==8?1:-1];'
probe valist 'typedef __builtin_va_list va_list; int f(int a){return a;}'
probe ll 'long long f(long long a, long long b){ return a*b + 0x123456789abcdefLL; }'
probe va 'int f(int n, ...){ __builtin_va_list ap; __builtin_va_start(ap,n); int x=__builtin_va_arg(ap,int); __builtin_va_end(ap); return x;}'
probe cmp 'int f(long a,long b){ return a<b; }'
# rv32 run tests: strip the debugging lines and the ';' comments (GNU as for RISC-V takes ';' as a statement separator) and rewrite the non-existent `subi`
cat > start.s <<'E'
	.globl _start
_start:
	call main
	li a7, 93
	ecall
E
"$B/riscv64-unknown-elf-as" -march=rv32im -mabi=ilp32 -o start.o start.s
run() {
	n=$1; printf '%s\n' "$2" > $n.i
	"$RV32" $n.i $n.s 2>/dev/null
	sed -i -E -e '/^;/d' -e 's/[ \t]*;.*$//' -e 's/subi (\w+), (\w+), ([0-9]+)/addi \1, \2, -\3/' $n.s
	"$B/riscv64-unknown-elf-as" -march=rv32im -mabi=ilp32 -o $n.o $n.s && "$B/riscv64-unknown-elf-ld" -m elf32lriscv -o $n.elf start.o $n.o && qemu-riscv32 ./$n.elf
	echo "run $n: exit $? (expected $3)"
}
run b 'int main(void){ int a=5; return a*3+1; }' 16
run c 'int g(int x){return x+1;} int main(void){ return g(g(5)); }' 7
run d 'int main(void){ int i,s=0; for(i=0;i<10;i++) s+=i; return s; }' 45
run fib 'int fib(int n){ if(n<2) return n; return fib(n-1)+fib(n-2); } int main(void){ return fib(10); }' 55
rm -f ./*.o ./*.elf
echo "(work files in $T)"
