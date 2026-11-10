#!/bin/sh
# Write the header the pcc back end includes (mnemonic spellings) into the back end's directory, or with --check
# say whether the copy there is current.  It is generated, but committed with the back end, so building pcc does not need hbnf.
#   tools/export-pcc-headers.sh [--check] [DIR]      default DIR: ~/claude/pcc/arch/pdp64
set -e
cd "$(dirname "$0")/.."
mode=export; [ "$1" = --check ] && { mode=check; shift; }
DEST=${1:-$HOME/claude/pcc/arch/pdp64}
B=${BUILD:-build}
python3 tools/mkgrammar.py
if [ "$mode" = check ]; then
	[ -d "$DEST" ] || { echo "pcc headers: $DEST does not exist yet, nothing to check"; exit 0; }
	cmp -s "$B/pdp64-names.h" "$DEST/pdp64-names.h" || { echo "pcc headers: $DEST/pdp64-names.h is stale; run tools/export-pcc-headers.sh"; exit 1; }
	echo "pcc headers: current"
else
	mkdir -p "$DEST"
	cp "$B/pdp64-names.h" "$DEST/"
	echo "wrote $DEST/pdp64-names.h"
fi
