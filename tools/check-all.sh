#!/bin/sh
# Every check: the syntax tests, the assembler and linker tests, the encoding checks, the manual, the simulator, timing, relaxation and flag tests, QEMU.
set -e
cd "$(dirname "$0")/.."
tools/check-asmsyntax.sh | grep -c '^ok' | sed 's/$/ syntax tests ok/'
tools/check-as64.sh
tools/check-enc.sh
tools/check-grammar-enc.sh
python3 tools/check-manual-src.py
python3 tools/mkmanual.py --check
tools/mkbook.sh --check
tools/export-pcc-headers.sh --check
tools/check-ld64.sh
tools/check-sim64.sh
tools/check-timing.sh
tools/check-exec-enc.sh
tools/check-relax.sh | tail -n 1
tools/check-relax.sh --mutate | tail -n 1
tools/check-flaginv.sh | tail -n 1
if [ -x "${PDP64_QEMU:-$(dirname "$PWD")/qemu-build/qemu-system-pdp64}" ]; then
	tools/check-qemu.sh
else
	echo "check-qemu: skipped (no qemu-system-pdp64; see qemu/README.md)"
fi
