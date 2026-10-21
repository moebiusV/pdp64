#!/bin/sh
# Generate the three parsers from the grammars and build as64.  HBNF and HBNF_TEMPLATES as in check-formats.sh.
set -e
cd "$(dirname "$0")/.."
HBNF=${HBNF:-/tmp/claude-1000/alpine/hbnf}
TPL=${HBNF_TEMPLATES:-/tmp/claude-1000/alpine/hbnf-templates}
B=${BUILD:-build}; mkdir -p "$B"
python3 tools/mkgrammar.py
(cd spec && "$HBNF" pdp64-asm.hbnf --backend=c --templates="$TPL" --ast --spans) > "$B/pdp64-asm-parser.c"
("$HBNF" "$B/pdp64.hbnf" --backend=c --templates="$TPL") > "$B/pdp64-parser.c"
(cd spec && "$HBNF" elf.hbnf       --backend=c --templates="$TPL") > "$B/elf-parser.c"
CFLAGS=${CFLAGS:--g -w}
# each generated parser exports parse_bytes, emit_bytes and friends: rename them in the format parser's object
RENAME="-Demit_bits=fmt_emit_bits -Demit_bytes=fmt_emit_bytes -Dparse_bits=fmt_parse_bits -Dparse_bytes=fmt_parse_bytes -Dfree_arena=fmt_free_arena"
gcc $CFLAGS $RENAME -Ias64 -I"$B" -c as64/fmtp.c -o "$B/fmtp.o"
gcc $CFLAGS -Ias64 -I"$B" -o "$B/as64" as64/as64.c as64/asmp.c "$B/fmtp.o"
echo "built $B/as64"
