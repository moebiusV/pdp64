#!/bin/sh
# Build the manuals as books with buildabook (github.com/moebiusV/buildabook) and Typst: one book for each member of the family.
#
#   tools/mkbook.sh [MEMBER...]            build book/pdp64-MEMBER.pdf (MEMBER: r20, 16, 32; default all three; tracked in git)
#   tools/mkbook.sh --check [MEMBER...]    only the checks: buildabook's number map and `buildabook check`, and that the number in each
#                                          source heading is the number the outline gives the entry (part of tools/check-all.sh)
#
# book/outline.txt (the order; a line that starts with @16,32: is only in the books of those members), book/sources.txt (which Markdown makes each
# entry; @ID@ is the member), book/book.conf and book/template.typ are the inputs; book/build-MEMBER/ is made fresh.  The Markdown is the generated
# manual of the member, docs/manual/pdp64-MEMBER/ (tools/mkmanual.py).  buildabook is found on PATH, or in $BUILDABOOK, or at ~/claude/buildabook/buildabook.
set -eu
cd "$(dirname "$0")/.."
ROOT=$(pwd)
CHECK=0
MEMBERS=
for a in "$@"; do
	case "$a" in
	--check) CHECK=1 ;;
	r20|16|32) MEMBERS="$MEMBERS $a" ;;
	*) echo "usage: mkbook.sh [--check] [r20|16|32 ...]" >&2; exit 2 ;;
	esac
done
[ -n "$MEMBERS" ] || MEMBERS="r20 16 32"
BAB=${BUILDABOOK:-$(command -v buildabook || true)}
[ -n "$BAB" ] || BAB=$HOME/claude/buildabook/buildabook
if [ ! -x "$BAB" ]; then
	if [ "$CHECK" = 1 ]; then echo "mkbook: skipped (buildabook not found; put it on PATH or set BUILDABOOK)"; exit 0; fi
	echo "mkbook: buildabook not found (put it on PATH or set BUILDABOOK)" >&2
	exit 1
fi
for M in $MEMBERS; do
	case "$M" in r20) NAME=pdp64/r20 ;; *) NAME=pdp64/$M ;; esac
	B=book/build-$M
	rm -rf "$B"
	mkdir -p "$B"
	cp book/template.typ "$B/"
	python3 tools/mkchapters.py "$M" --outline > "$B/outline.txt"
	sed -e "s|@MEMBER@|$NAME|g" -e "s|@ID@|$M|g" book/book.conf > "$B/book.conf"
	(
		cd "$B"
		"$BAB" number-map >/dev/null
		python3 "$ROOT/tools/mkchapters.py" "$M"
		if [ "$CHECK" = 1 ]; then
			"$BAB" check
			exit 0
		fi
		"$BAB" typst
		rm -rf rendered/figures
		cp -r figures rendered/figures
		typst compile --root . rendered/book.typ "pdp64-$M.pdf"
		cp "pdp64-$M.pdf" "../pdp64-$M.pdf"
		echo "wrote book/pdp64-$M.pdf ($(pdfinfo "../pdp64-$M.pdf" 2>/dev/null | sed -n 's/^Pages: *//p') pages)"
	)
done
