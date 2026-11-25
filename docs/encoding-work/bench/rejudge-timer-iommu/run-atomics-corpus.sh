#!/bin/sh
# usage: run-atomics-corpus.sh KERNEL_MODULE_DIR WORKDIR   (WORKDIR: an empty scratch directory, outside the repository)
# For each .ko.xz: decompress, disassemble to WORKDIR/NAME.txt, empty the object; then count with atomics-corpus.py.
D=${1:?}; W=${2:?}; HERE=$(cd "$(dirname "$0")" && pwd)
find "$D" -name '*.ko.xz' | xargs -P 12 -I{} sh -c 'b=$(basename {} .xz); xz -dc {} > "$0/$b" && objdump -d --no-show-raw-insn "$0/$b" > "$0/$b.txt" 2>/dev/null; : > "$0/$b"' "$W"
find "$W" -name '*.txt' | python3 -I "$HERE/atomics-corpus.py" - > "$HERE/atomics-corpus-result.txt" 2>&1
