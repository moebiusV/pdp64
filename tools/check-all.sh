#!/bin/sh
# Every check: the structural check of the old JSON spec, the format round trips, the syntax tests, the assembler tests, the drift test.
set -e
cd "$(dirname "$0")/.."
python3 tools/specgen.py check
tools/check-formats.sh | grep -c '^ok' | sed 's/$/ format vectors ok/'
tools/check-asmsyntax.sh | grep -c '^ok' | sed 's/$/ syntax tests ok/'
tools/check-as64.sh
python3 tools/check-drift.py
