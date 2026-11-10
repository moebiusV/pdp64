#!/bin/sh
# Copy the files the QEMU target needs from their single sources (the shared core, the table codec and its tables generated from
# spec/pdp64/pdp64.hbnf) into qemu/target-pdp64/gen/.  The copies are generated: never edit them.
#   qemu/sync.sh           regenerate the parser (tools/build-as64.sh) and copy
#   qemu/sync.sh --check   fail if a copy differs from its source (no copying)
set -e
cd "$(dirname "$0")/.."
B=${BUILD:-build}
D=qemu/target-pdp64/gen
tools/build-as64.sh > /dev/null
mkdir -p "$D"
# source -> name in gen/
LIST="common/pdp64exec.c common/pdp64exec.h common/pdp64exec_enc.inc common/fmt.h common/pdp64enc.c common/pdp64enc.h $B/pdp64-tab.c $B/pdp64-consts.h"
stale=0
for f in $LIST; do
	g="$D/$(basename "$f")"
	if [ "${1:-}" = "--check" ]; then
		cmp -s "$f" "$g" || { echo "stale: $g (source $f)"; stale=1; }
	else
		cp "$f" "$g"
	fi
done
if [ "${1:-}" = "--check" ]; then
	# nothing extra may be lying around either
	for g in "$D"/*; do
		case " $LIST " in *"/$(basename "$g") "*) ;; *) echo "extra: $g"; stale=1;; esac
	done
	[ $stale = 0 ] && echo "qemu/target-pdp64/gen is up to date"
	exit $stale
fi
echo "synced $D"
