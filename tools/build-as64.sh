#!/bin/sh
# Generate the parsers and tables from the grammars and build as64.  HBNF and HBNF_TEMPLATES as in check-formats.sh.
# hbnf reads the assembly grammar spec/pdp64-asm.hbnf as it is (the parts of spec/grammars.d/ that name asm, through the generated index: no copy, nothing patched), and as64
# carries the tables of the encoding (build/pdp64-tab.c, from the parts that name enc, read through spec/pdp64/pdp64.hbnf).
set -e
cd "$(dirname "$0")/.."
HBNF=${HBNF:-/tmp/hbnf-latest/hbnf}
TPL=${HBNF_TEMPLATES:-/tmp/hbnf-latest/hbnf-templates}
B=${BUILD:-build}; mkdir -p "$B"
python3 tools/mkgrammar.py
python3 tools/mkenc.py
"$HBNF" spec/pdp64-asm.hbnf --backend=c --templates="$TPL" --ast --spans --no-compact --no-overlay > "$B/x/pdp64-asm-parser.c"
"$HBNF" spec/elf.hbnf --backend=c --templates="$TPL" > "$B/elf-parser.c"
CFLAGS=${CFLAGS:--g -w}
gcc $CFLAGS -Ias64 -Icommon -I"$B/x" -I"$B" -o "$B/as64" as64/as64.c as64/asmp.c common/pdp64enc.c "$B/pdp64-tab.c"
echo "built $B/as64"
