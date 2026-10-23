#!/bin/sh
# Build the manual as a book with buildabook (github.com/moebiusV/buildabook) and Typst.
#
#   tools/mkbook.sh            build book/pdp64-manual.pdf (tracked in git: rebuild and commit it after every change to the manual)
#   tools/mkbook.sh --check    only the checks: buildabook's number map and `buildabook check`, and that the number in each
#                              source heading is the number the outline gives the entry (part of tools/check-all.sh)
#
# book/outline.txt (the order), book/sources.txt (which Markdown makes each entry), book/book.conf and book/template.typ are
# the inputs; book/build/ is made fresh.  buildabook is found on PATH, or in $BUILDABOOK, or at ~/claude/buildabook/buildabook.
set -eu
cd "$(dirname "$0")/.."
ROOT=$(pwd)
BAB=${BUILDABOOK:-$(command -v buildabook || true)}
[ -n "$BAB" ] || BAB=$HOME/claude/buildabook/buildabook
if [ ! -x "$BAB" ]; then
	if [ "${1:-}" = "--check" ]; then echo "mkbook: skipped (buildabook not found; put it on PATH or set BUILDABOOK)"; exit 0; fi
	echo "mkbook: buildabook not found (put it on PATH or set BUILDABOOK)" >&2
	exit 1
fi
mkdir -p book/build
cd book/build
cp ../outline.txt ../book.conf ../template.typ .
"$BAB" number-map >/dev/null
python3 "$ROOT/tools/mkchapters.py"
if [ "${1:-}" = "--check" ]; then
	"$BAB" check
	exit 0
fi
"$BAB" typst
rm -rf rendered/figures
cp -r figures rendered/figures
typst compile --root . rendered/book.typ pdp64-manual.pdf
cp pdp64-manual.pdf ../pdp64-manual.pdf
echo "wrote book/pdp64-manual.pdf ($(pdfinfo ../pdp64-manual.pdf 2>/dev/null | sed -n 's/^Pages: *//p') pages)"
