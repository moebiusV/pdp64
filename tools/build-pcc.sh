#!/bin/sh
# Build the pdp64 pcc ccom from the tracked files of the pcc working tree (PCC, default ../pcc, a sibling of this repository) into build/pcc/:
#	build/pcc/ccom		the compiler of the pdp64 (32 registers, the encoding of spec/pdp64/pdp64.hbnf); `-m pdp64` is accepted, any other target refused
# This needs the pcc branch `single-pdp64` (one target); the master of moebiusV/pcc still builds the earlier iterations, which these tools no longer assemble.
# An unchanged source tree is not rebuilt.
set -eu
cd "$(dirname "$0")/.."
PCC=${PCC:-$(dirname "$PWD")/pcc}
d=$PWD/build/pcc
id=$(cd "$PCC" && git ls-files -z -- cc mip common os configure.ac arch/pdp64 cc2 | xargs -0 sha1sum | sha1sum | cut -c1-40)
if [ -x "$d/ccom" ] && [ "$(cat "$d/.srcid" 2>/dev/null)" = "$id" ]; then echo "pcc: unchanged"; exit 0; fi
if (cd "$PCC" && grep -q PDP64_REGS32 arch/pdp64/macdefs.h); then echo "pcc: $PCC still has the PDP64_REGS32 switch: use the branch single-pdp64" >&2; exit 1; fi
rm -rf "$d"; mkdir -p "$d"
w=$d/src
mkdir -p "$w"
(cd "$PCC" && git ls-files -z | tar --null -T - -cf -) | tar xf - -C "$w"
rm -f "$w"/cc/ccom/*-ccom "$w"/cc/ccom/*-cc2
(cd "$w" && ./configure --target=pdp64-unknown-linux >cfg.log 2>&1 && cd cc/ccom && make CFLAGS="-g -O1 -std=gnu89 -w -fcommon" >mk.log 2>&1)
c=$(ls -t "$w"/cc/ccom/*-ccom | head -1)
ln -sf "$c" "$d/ccom"; echo "built $d/ccom"
echo "$id" > "$d/.srcid"
