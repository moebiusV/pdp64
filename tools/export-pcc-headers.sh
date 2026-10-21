#!/bin/sh
# Write the headers the pcc back end includes (mnemonic spellings, field limits) into the back end's directory, or with --check
# say whether the copies there are current.  They are generated, but committed with the back end, so building pcc does not need hbnf.
#   tools/export-pcc-headers.sh [--check] [DIR]      default DIR: ~/claude/pcc/arch/pdp64
set -e
cd "$(dirname "$0")/.."
mode=export; [ "$1" = --check ] && { mode=check; shift; }
DEST=${1:-$HOME/claude/pcc/arch/pdp64}
B=${BUILD:-build}
python3 tools/mkgrammar.py
"$B/as64" --limits > "$B/pdp64-limits.h"
if [ "$mode" = check ]; then
	[ -d "$DEST" ] || { echo "pcc headers: $DEST does not exist yet, nothing to check"; exit 0; }
	for h in pdp64-names.h pdp64-limits.h; do
		cmp -s "$B/$h" "$DEST/$h" || { echo "pcc headers: $DEST/$h is stale; run tools/export-pcc-headers.sh"; exit 1; }
	done
	echo "pcc headers: current"
else
	mkdir -p "$DEST"
	cp "$B/pdp64-names.h" "$B/pdp64-limits.h" "$DEST/"
	echo "wrote $DEST/pdp64-names.h and pdp64-limits.h"
fi
