#!/bin/sh
# Generate the parsers and tables from the grammars and build as64.  HBNF and HBNF_TEMPLATES as in check-formats.sh.
# as64 reads a superset of the grammar of spec/ (build/x: the words and registers r16-r31 of the pdp64 encoding, tools/mkenc.py) and carries the
# tables of the encoding (build/pdp64-tab.c, from spec/pdp64/pdp64.hbnf).
set -e
cd "$(dirname "$0")/.."
HBNF=${HBNF:-/tmp/hbnf-latest/hbnf}
TPL=${HBNF_TEMPLATES:-/tmp/hbnf-latest/hbnf-templates}
B=${BUILD:-build}; mkdir -p "$B"
python3 tools/mkgrammar.py
python3 tools/mkenc.py
cp spec/common.hbnf spec/ascii.hbnf "$B/x/"
(cd "$B/x" && "$HBNF" pdp64-asm.hbnf --backend=c --templates="$TPL" --ast --spans --no-compact --no-overlay) > "$B/x/pdp64-asm-parser.c"
(cd "$B" && "$HBNF" elf.hbnf       --backend=c --templates="$TPL") > "$B/elf-parser.c"
CFLAGS=${CFLAGS:--g -w}
gcc $CFLAGS -Ias64 -Icommon -I"$B/x" -I"$B" -o "$B/as64" as64/as64.c as64/asmp.c common/pdp64enc.c "$B/pdp64-tab.c"
echo "built $B/as64"
