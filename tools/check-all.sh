#!/bin/sh
# Every check: the format round trips, the syntax tests, the assembler tests, the drift test.
set -e
cd "$(dirname "$0")/.."
tools/check-formats.sh | grep -c '^ok' | sed 's/$/ format vectors ok/'
tools/check-asmsyntax.sh | grep -c '^ok' | sed 's/$/ syntax tests ok/'
tools/check-as64.sh
python3 tools/check-drift.py
tools/export-pcc-headers.sh --check
tools/check-ld64.sh
tools/check-sim64.sh
tools/check-p2.sh
tools/check-p2.sh --mutate
if [ -x "${PDP64_QEMU:-$HOME/claude/qemu-build/qemu-system-pdp64}" ]; then
	tools/check-qemu.sh
else
	echo "check-qemu: skipped (no qemu-system-pdp64; see qemu/README.md)"
fi
