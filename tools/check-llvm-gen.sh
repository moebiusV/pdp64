#!/bin/sh
# The generated files of the LLVM back end (llvm/target/PDP64/gen) are what tools/gen-llvm-td.py writes from the grammar now.
set -e
cd "$(dirname "$0")/.."
tools/build-as64.sh > /dev/null
tools/gen-llvm-td.py --check
