#!/bin/sh
# Preprocess an assembly test (NAME.S) with the C preprocessor, so that it can use the generated constants of build/pdp64-consts.h by name:
#   tools/pp-asm.sh in.S out.s
set -e
cd "$(dirname "$0")/.."
B=${BUILD:-build}
gcc -E -P -x assembler-with-cpp -I"$B" "$1" -o "$2"
