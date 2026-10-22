#!/bin/sh
# Configure and build qemu-system-pdp64 out of tree (default ~/claude/qemu-build) from ~/claude/qemu-src.
# usage: qemu/build.sh [-j N]      (a first build takes a long time on two cores: run it in the background)
set -e
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
Q=${QEMU_SRC:-$HOME/claude/qemu-src}
B=${QEMU_BUILD:-$HOME/claude/qemu-build}
J=2; [ "${1:-}" = "-j" ] && J=$2
"$here/install.sh" "$Q"
mkdir -p "$B"
cd "$B"
if [ ! -f build.ninja ]; then
	"$Q/configure" --target-list=pdp64-softmmu --disable-docs --disable-tools --disable-guest-agent --disable-user \
		--disable-werror --disable-plugins --disable-vnc --disable-gtk --disable-sdl --disable-opengl --disable-curses \
		--disable-slirp --disable-kvm --disable-xen --disable-capstone --disable-libusb --disable-fdt --disable-selinux \
		--disable-attr --disable-linux-aio --disable-linux-io-uring --disable-bzip2 --disable-zstd --disable-snappy \
		--disable-lzo --disable-gnutls --disable-nettle --disable-gcrypt --disable-curl
fi
ninja -j"$J" qemu-system-pdp64
echo "built $B/qemu-system-pdp64"
