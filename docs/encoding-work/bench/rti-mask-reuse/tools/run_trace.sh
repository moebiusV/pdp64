#!/bin/sh
# run_trace.sh NAME SRC.S  -> scratch/NAME.{x,map,sites,trace}; runs the program on qemu-system-pdp64 with one instruction per translation block (-d exec) so that the program counter
# of every executed instruction is logged.  Needs the pdp64 checkout's build/ (as64, ld64) and the QEMU model.  ARGS env: machine string.
set -e
ROOT=${ROOT:-$(cd "$(dirname "$0")/../../../../.." && pwd)}
Q=${PDP64_QEMU:-$(dirname "$ROOT")/qemu-build/qemu-system-pdp64}
SCR=${SCR:-/tmp/rti-mask-reuse}; mkdir -p "$SCR"
n=$1; s=$2; M=${MACHINE:-pdp64-virt,kernel-mode=on}
case "$s" in *.S) "$ROOT/tools/pp-asm.sh" "$s" "$SCR/$n.pp.s";; *) cp "$s" "$SCR/$n.pp.s";; esac
python3 "$(dirname "$0")/sites.py" "$SCR/$n.pp.s" "$SCR/$n.s"
"$ROOT/build/as64" -o "$SCR/$n.o" "$SCR/$n.s"
"$ROOT/build/ld64" -M -o "$SCR/$n.x" "$SCR/$n.o" > "$SCR/$n.map"
timeout 120 "$Q" -M "$M" -display none -monitor none -serial none -nodefaults -accel tcg,one-insn-per-tb=on -d exec,nochain -D "$SCR/$n.trace" -kernel "$SCR/$n.x" < /dev/null || echo "exit status $?"
wc -l < "$SCR/$n.trace"
