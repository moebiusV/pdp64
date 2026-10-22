#!/bin/sh
#
# archcmp-gccx -- unpack Debian/Ubuntu cross GCC packages into a private prefix (no root, no install): `apt-get download` the packages of
# each target and `dpkg -x` them below $GCCX/<triple>; a wrapper script $GCCX/bin/<triple>-gcc sets LD_LIBRARY_PATH (the cross binutils keep their
# libbfd next to them) and runs the cross compiler.  Compiler and assembler only (no libc): enough for `gcc -Os -c` of preprocessed C.
#
# usage: archcmp-gccx.sh [triple ...]      default: aarch64-linux-gnu riscv64-linux-gnu s390x-linux-gnu powerpc64-linux-gnu m68k-linux-gnu
#                                          sparc64-linux-gnu arm-linux-gnueabi loongarch64-linux-gnu
# GCCX (default /tmp/p64opt/gccx) is where the result goes; ARCHCMP_GCC_VER (default 15) the gcc major version of the distribution.
#
set -u
GCCX=${GCCX:-/tmp/p64opt/gccx}
V=${ARCHCMP_GCC_VER:-15}
T=${*:-aarch64-linux-gnu riscv64-linux-gnu s390x-linux-gnu powerpc64-linux-gnu m68k-linux-gnu sparc64-linux-gnu arm-linux-gnueabi loongarch64-linux-gnu}
mkdir -p "$GCCX/debs" "$GCCX/bin"
for t in $T; do
	[ -x "$GCCX/bin/$t-gcc" ] && { echo "$t: have"; continue; }
	d=$GCCX/x-$t
	mkdir -p "$d"
	(cd "$GCCX/debs" && for p in gcc-$V-$t cpp-$V-$t gcc-$V-$t-base binutils-$t; do apt-get download $p >/dev/null 2>&1 || echo "$t: cannot download $p"; done)
	for deb in "$GCCX"/debs/gcc-${V}-${t}_*.deb "$GCCX"/debs/cpp-${V}-${t}_*.deb "$GCCX"/debs/gcc-${V}-${t}-base_*.deb "$GCCX"/debs/binutils-${t}_*.deb; do
		[ -f "$deb" ] && dpkg -x "$deb" "$d"
	done
	cat > "$GCCX/bin/$t-gcc" <<W
#!/bin/sh
X=$d
LD_LIBRARY_PATH=\$X/usr/lib/x86_64-linux-gnu\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH} exec \$X/usr/bin/$t-gcc-$V -B\$X/usr/lib/gcc-cross/$t/$V/ -B\$X/usr/libexec/gcc-cross/$t/$V/ -B\$X/usr/$t/bin/ "\$@"
W
	chmod +x "$GCCX/bin/$t-gcc"
	echo "$t: $("$GCCX/bin/$t-gcc" --version 2>&1 | head -1)"
done
