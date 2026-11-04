#!/bin/sh
# Build the pdp64 pcc ccom from the tracked files of the pcc working tree (PCC, default ~/claude/pcc) into build/pcc/:
#	build/pcc/ccom	16 registers: -m pdp64/r20 (the original, default), -m pdp64/16
#	build/pcc/ccom32	32 registers (-DPDP64_REGS32): -m pdp64/32        (only if the tree has the 32-register back end)
# The prefix-coded targets need the pcc branch enc-prefix (PCC=~/claude/pcc-enc until it is merged into pcc's main).
# An unchanged source tree is not rebuilt.
set -eu
cd "$(dirname "$0")/.."
PCC=${PCC:-$HOME/claude/pcc}
d=$PWD/build/pcc
id=$(cd "$PCC" && git ls-files -z -- cc mip common os configure.ac arch/pdp64 cc2 | xargs -0 sha1sum | sha1sum | cut -c1-40)
if [ -x "$d/ccom" ] && [ "$(cat "$d/.srcid" 2>/dev/null)" = "$id" ]; then echo "pcc: unchanged"; exit 0; fi
rm -rf "$d"; mkdir -p "$d"
variants=16
(cd "$PCC" && grep -q PDP64_REGS32 arch/pdp64/macdefs.h) && variants="16 32"
for v in $variants; do
	w=$d/regs$v; extra=; out=ccom
	[ $v = 32 ] && { extra=-DPDP64_REGS32; out=ccom32; }
	mkdir -p "$w"
	(cd "$PCC" && git ls-files -z | tar --null -T - -cf -) | tar xf - -C "$w"
	rm -f "$w"/cc/ccom/*-ccom "$w"/cc/ccom/*-cc2
	(cd "$w" && ./configure --target=pdp64-unknown-linux >cfg.log 2>&1 && cd cc/ccom && make CFLAGS="-g -O1 -std=gnu89 -w -fcommon $extra" >mk.log 2>&1)
	c=$(ls -t "$w"/cc/ccom/*-ccom | head -1)
	ln -sf "$c" "$d/$out"; echo "built $d/$out"
done
echo "$id" > "$d/.srcid"
