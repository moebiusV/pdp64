#!/bin/sh
# Generate the assembly-syntax parser from spec/pdp64-asm.hbnf and run tests/asmsyntax.c over it.
set -e
cd "$(dirname "$0")/.."
HBNF=${HBNF:-/tmp/hbnf-latest/hbnf}
TPL=${HBNF_TEMPLATES:-/tmp/hbnf-latest/hbnf-templates}
[ -x "$HBNF" ] || { HBNF=/tmp/hbnf-bin; TPL=/tmp/hbnf/templates; }
B=${BUILD:-build}; mkdir -p "$B"
python3 tools/mkgrammar.py
(cd "$B" && "$HBNF" pdp64-asm.hbnf --backend=c --templates="$TPL" --no-compact --no-overlay) > "$B/pdp64-asm-parser.c"
gcc -w -I"$B" -o "$B/asmsyntax" tests/asmsyntax.c
"$B/asmsyntax"
