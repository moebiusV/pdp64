#!/bin/sh
# Put the pdp64 target into a QEMU v11.1.x source tree (default ~/claude/qemu-src): apply qemu-core.patch (the small changes to
# QEMU's own files) and copy the new directories.  Idempotent.  The tree is a scratch clone; nothing here is committed to it.
set -e
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
Q=${1:-${QEMU_SRC:-$HOME/claude/qemu-src}}
[ -f "$Q/target/meson.build" ] || { echo "$Q is not a QEMU source tree" >&2; exit 1; }
"$here/sync.sh" --check > /dev/null || { echo "qemu/target-pdp64/gen is stale: run qemu/sync.sh" >&2; exit 1; }
cd "$Q"
if git apply --reverse --check "$here/qemu-core.patch" 2> /dev/null; then
	echo "qemu-core.patch already applied"
else
	git apply "$here/qemu-core.patch"
	echo "applied qemu-core.patch"
fi
mkdir -p target/pdp64 hw/pdp64 configs/devices/pdp64-softmmu
# replace the directories wholesale so that removed files do not linger
rm -rf target/pdp64 hw/pdp64
cp -r "$here/target-pdp64" target/pdp64
cp -r "$here/hw-pdp64" hw/pdp64
cp "$here/configs/targets/pdp64-softmmu.mak" configs/targets/
cp "$here/configs/devices/pdp64-softmmu/default.mak" configs/devices/pdp64-softmmu/
echo "installed into $Q"
