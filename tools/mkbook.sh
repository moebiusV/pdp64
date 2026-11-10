#!/bin/sh
# Build the manual as a book with buildabook (github.com/moebiusV/buildabook) and Typst.
#
#   tools/mkbook.sh            build book/pdp64.pdf (tracked in git)
#   tools/mkbook.sh --check    only the checks: buildabook's number map and `buildabook check`, and that the number in each source heading
#                              is the number the outline gives the entry (part of tools/check-all.sh)
#
# book/outline.txt (the order), book/sources.txt (which Markdown makes each entry), book/book.conf and book/template.typ are the inputs;
# book/build/ is made fresh.  The Markdown is the generated manual, docs/manual/ (tools/mkmanual.py).  buildabook is found on PATH, or in
# $BUILDABOOK, or at ~/claude/buildabook/buildabook.
set -eu
cd "$(dirname "$0")/.."
ROOT=$(pwd)
CHECK=0
for a in "$@"; do
	case "$a" in
	--check) CHECK=1 ;;
	*) echo "usage: mkbook.sh [--check]" >&2; exit 2 ;;
	esac
done
BAB=${BUILDABOOK:-$(command -v buildabook || true)}
[ -n "$BAB" ] || BAB=$HOME/claude/buildabook/buildabook
if [ ! -x "$BAB" ]; then
	if [ "$CHECK" = 1 ]; then echo "mkbook: skipped (buildabook not found; put it on PATH or set BUILDABOOK)"; exit 0; fi
	echo "mkbook: buildabook not found (put it on PATH or set BUILDABOOK)" >&2
	exit 1
fi
B=book/build
rm -rf "$B"
mkdir -p "$B"
cp book/template.typ book/outline.txt book/book.conf "$B/"
(
	cd "$B"
	"$BAB" number-map >/dev/null
	python3 "$ROOT/tools/mkchapters.py"
	if [ "$CHECK" = 1 ]; then
		"$BAB" check
		exit 0
	fi
	"$BAB" typst
	rm -rf rendered/figures
	cp -r figures rendered/figures
	typst compile --root . rendered/book.typ pdp64.pdf
	cp pdp64.pdf ../pdp64.pdf
	echo "wrote book/pdp64.pdf ($(pdfinfo ../pdp64.pdf 2>/dev/null | sed -n 's/^Pages: *//p') pages)"
)
