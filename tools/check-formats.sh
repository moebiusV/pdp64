#!/bin/sh
# Generate the C parser/writer for the instruction formats from spec/pdp64.hbnf and round-trip the hand-encoded
# vectors in tests/formats.c.  HBNF=path to the hbnf binary (tools/build-hbnf.sh), HBNF_TEMPLATES=its templates.
set -e
cd "$(dirname "$0")/.."
HBNF=${HBNF:-/tmp/claude-1000/alpine/hbnf}
TPL=${HBNF_TEMPLATES:-/tmp/claude-1000/alpine/hbnf-templates}
[ -x "$HBNF" ] || { HBNF=/tmp/claude-1000/hbnf-bin; TPL=/tmp/claude-1000/hbnf/templates; }
python3 tools/mkgrammar.py
B=${BUILD:-build}; mkdir -p "$B"
"$HBNF" build/pdp64.hbnf --backend=c --templates="$TPL" > "$B/pdp64-parser.c"
gcc -w -Ias64 -I"$B" -o "$B/formats" tests/formats.c
"$B/formats"
