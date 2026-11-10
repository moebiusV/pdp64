#!/bin/sh
# The drift test of the encoding grammars (spec/pdp64-enc.hbnf, spec/pdp64/pdp64.hbnf), the source of truth of the encoding.
#
#   1. hbnf accepts each grammar (the syntax, the references, the widths) and generates a decoder from it (parse_bits);
#   2. everything is generated again from the grammars, into a scratch directory: a checked-in generated file that differs (spec/pdp64/tables.md) fails,
#      and so does a generated table that is not the one recorded in tests/enc/generated.sha256 (the C tables of the codec, the field accessors, the assembly
#      grammar of as64 and its name tables).  After a deliberate change of a grammar: tools/check-grammar-enc.sh --update, and review the diff;
#   3. hbnf's decoder against the codec built from the generated tables, on every first parcel and four tails each: the same legal and illegal patterns, the
#      same length, the same leaf, the same raw value in every field (tests/enc/hbdec.c).
#
# HBNF and HBNF_TEMPLATES as in tools/build-as64.sh.
set -e
cd "$(dirname "$0")/.."
HBNF=${HBNF:-/tmp/claude-1000/hbnf-latest/hbnf}
TPL=${HBNF_TEMPLATES:-/tmp/claude-1000/hbnf-latest/hbnf-templates}
T=$(mktemp -d "${TMPDIR:-/tmp}/grammar-enc.XXXXXX")
trap 'rm -rf "$T"' EXIT
GOLD=tests/enc/generated.sha256
FILES="pdp64-tab.c pdp64-hbfields.h x/pdp64-mnemonics.hbnf x/pdp64-asm.hbnf x/pdp64-groups.h x/pdp64-extnames.h x/pdp64-mnnames.h"
export BUILD=$T
python3 tools/mkgrammar.py
python3 tools/mkenc.py --check
sum=$(cd "$T" && sha256sum $FILES)
if [ "$1" = "--update" ]; then
	printf '%s\n' "$sum" > "$GOLD"
	echo "check-grammar-enc: $GOLD rewritten"
	exit 0
fi
if ! printf '%s\n' "$sum" | diff - "$GOLD" > "$T/diff"; then
	cat "$T/diff"
	echo "check-grammar-enc: the generated files are not the ones recorded in $GOLD (a grammar changed? run tools/check-grammar-enc.sh --update and review)"
	exit 1
fi
"$HBNF" spec/pdp64/pdp64.hbnf --backend=c --templates="$TPL" > "$T/pdp64-hbdec.c"
gcc -O1 -w -DHBDEC="\"pdp64-hbdec.c\"" -DHBFIELDS="\"pdp64-hbfields.h\"" -I"$T" -Icommon -o "$T/hbdec" tests/enc/hbdec.c common/pdp64enc.c "$T/pdp64-tab.c"
"$T/hbdec"
echo "check-grammar-enc: ok"
