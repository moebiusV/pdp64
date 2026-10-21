#!/bin/sh
# Generate the assembly-syntax parser from spec/pdp64-asm.hbnf and run tests/asmsyntax.c over it.
set -e
cd "$(dirname "$0")/.."
HBNF=${HBNF:-/tmp/claude-1000/alpine/hbnf}
TPL=${HBNF_TEMPLATES:-/tmp/claude-1000/alpine/hbnf-templates}
[ -x "$HBNF" ] || { HBNF=/tmp/claude-1000/hbnf-bin; TPL=/tmp/claude-1000/hbnf/templates; }
B=${BUILD:-build}; mkdir -p "$B"
(cd spec && "$HBNF" pdp64-asm.hbnf --backend=c --templates="$TPL") > "$B/pdp64-asm-parser.c"
gcc -w -I"$B" -o "$B/asmsyntax" tests/asmsyntax.c
"$B/asmsyntax"
