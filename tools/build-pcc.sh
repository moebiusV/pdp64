#!/bin/sh
# Build the pdp64 pcc ccom from the tracked files of the pcc working tree (PCC, default ~/claude/pcc) into build/pcc/ccom.
# An unchanged source tree is not rebuilt.
set -eu
cd "$(dirname "$0")/.."
PCC=${PCC:-$HOME/claude/pcc}
d=$PWD/build/pcc
id=$(cd "$PCC" && git ls-files -z -- cc mip common os configure.ac arch/pdp64 cc2 | xargs -0 sha1sum | sha1sum | cut -c1-40)
if [ -x "$d/ccom" ] && [ "$(cat "$d/.srcid" 2>/dev/null)" = "$id" ]; then echo "pcc: unchanged"; exit 0; fi
rm -rf "$d"; mkdir -p "$d"
(cd "$PCC" && git ls-files -z | tar --null -T - -cf -) | tar xf - -C "$d"
rm -f "$d"/cc/ccom/*-ccom "$d"/cc/ccom/*-cc2
(cd "$d" && ./configure --target=pdp64-unknown-linux >cfg.log 2>&1 && cd cc/ccom && make CFLAGS='-g -O1 -std=gnu89 -w -fcommon' >mk.log 2>&1)
c=$(ls -t "$d"/cc/ccom/*-ccom | head -1)
ln -sf "$c" "$d/ccom"; echo "$id" > "$d/.srcid"; echo "built $d/ccom"
