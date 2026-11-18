#!/bin/sh
# Write the header the pcc back end includes (mnemonic spellings) into the back end's directory, or with --check
# say whether the copy there is current.  It is generated, but committed with the back end, so building pcc does not need hbnf.
#   tools/export-pcc-headers.sh [--check] [DIR]      default DIR: $PCC/arch/pdp64, PCC being ../pcc (a sibling of this repository) unless set
set -e
cd "$(dirname "$0")/.."
mode=export; [ "$1" = --check ] && { mode=check; shift; }
DEST=${1:-${PCC:-$(dirname "$PWD")/pcc}/arch/pdp64}
B=${BUILD:-build}
python3 tools/mkgrammar.py
# the checkout at $PCC may be on any branch, but tools/build-pcc.sh builds the branch single-pdp64, and master carries the same file: say which one this is
BR=$(git -C "${DEST%/arch/pdp64}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
[ -n "$BR" ] && [ "$BR" != single-pdp64 ] && echo "note: $DEST is on the pcc branch $BR; the back end that tools/build-pcc.sh builds is the branch single-pdp64, so commit this header on both (they carry the same file)" >&2
if [ "$mode" = check ]; then
	[ -d "$DEST" ] || { echo "pcc headers: $DEST does not exist yet, nothing to check"; exit 0; }
	cmp -s "$B/pdp64-names.h" "$DEST/pdp64-names.h" || { echo "pcc headers: $DEST/pdp64-names.h is stale; run tools/export-pcc-headers.sh"; exit 1; }
	echo "pcc headers: current"
else
	mkdir -p "$DEST"
	cp "$B/pdp64-names.h" "$DEST/"
	echo "wrote $DEST/pdp64-names.h"
fi
