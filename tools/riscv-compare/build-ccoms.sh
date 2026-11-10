#!/bin/sh
# build-ccoms.sh PCCTREE DIR -- build the pcc ccom of PCCTREE for pdp64 (16 and 32 registers), amd64, i386 into DIR/<name>/ (scratch copies; PCCTREE is not modified).
# Also builds riscv64 (DIR/rv) with the one-line configure.ac change that lets `configure --target=riscv64-unknown-linux` pick arch/riscv (pcc accepts riscv64
# for NetBSD only); the diagnosis section of the report used that build.  CFLAGS as tools/build-pcc.sh: -g -O1 -std=gnu89 -w -fcommon.
set -eu
T=$1; D=$2; mkdir -p "$D"
for ent in pdp16:pdp64-unknown-linux: pdp32:pdp64-unknown-linux:-DPDP64_REGS32 amd64:x86_64-unknown-linux: i386:i386-unknown-linux: rv:riscv64-unknown-linux:; do
	n=${ent%%:*}; r=${ent#*:}; tr=${r%%:*}; extra=${r#*:}
	mkdir -p "$D/$n"
	(cd "$T" && tar cf - --exclude='*.o' --exclude='*-ccom' --exclude=build-pcc .) | tar xf - -C "$D/$n"
	if [ "$n" = rv ]; then
		sed -i '/^\t    aarch64) targmach=aarch64 ;;$/a\	    riscv64) targmach=riscv64 targmachdir=riscv ;;' "$D/$n/configure.ac"
		(cd "$D/$n" && autoconf 2>/dev/null)
	fi
	(cd "$D/$n" && ./configure --target=$tr >cfg.log 2>&1 && cd cc/ccom && make CFLAGS="-g -O1 -std=gnu89 -w -fcommon $extra" >mk.log 2>&1)
	ls "$D/$n"/cc/ccom/*-ccom
done
