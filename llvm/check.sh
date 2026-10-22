#!/bin/sh
# The oracle test of the pdp64 LLVM machine-code layer: llvm-mc against as64.
#   llvm/check.sh              the generated tables are fresh, tests/asm and tests/sim assemble to the same bytes and relocations,
#                              the forms test (llvm/forms.py) agrees with as64 on a few thousand instructions, the refused programs
#                              (tests/asm-err) are refused, and the disassembly of every program assembles to itself
#   LLVM_MC=path               the llvm-mc to test (default ~/claude/llvm-build/bin/llvm-mc)
set -e
cd "$(dirname "$0")/.."
tools/build-as64.sh > /dev/null
tools/gen-llvm-td.py --check
python3 llvm/oracle.py "$@"
python3 llvm/forms.py
python3 llvm/negative.py
