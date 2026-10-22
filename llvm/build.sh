#!/bin/sh
# Build what milestone M1 (the machine-code layer) needs: llvm-tblgen, the MC libraries, llvm-mc, llvm-objdump, llvm-readobj, llvm-objcopy.
#
#   llvm/build.sh [-j N]       install.sh + configure + ninja; the result is $LLVM_BUILD/bin/llvm-mc
#
# LLVM_SRC (default ~/claude/llvm-project, tag llvmorg-21.1.8) and LLVM_BUILD (default ~/claude/llvm-build) name the two trees.
# The defaults are for a small machine (3 GB, 2 cores): one compile job, one link job, the BFD linker with --no-keep-memory,
# assertions on (they catch an encoder that disagrees with the tables).  On a bigger machine:  llvm/build.sh -j 16  with
# LLVM_USE_LINKER=lld, and add the targets you want (clang, llc ...) to TARGETS.
set -e
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
L=${LLVM_SRC:-$HOME/claude/llvm-project}
B=${LLVM_BUILD:-$HOME/claude/llvm-build}
J=1
[ "${1:-}" = -j ] && J=$2
[ -d "$L/.git" ] || git clone --depth 1 --branch llvmorg-21.1.8 https://github.com/llvm/llvm-project.git "$L"
"$here/install.sh" "$L"
LINKER=${LLVM_USE_LINKER:-bfd}
TARGETS=${TARGETS:-"llvm-tblgen llvm-mc llvm-objdump llvm-readobj llvm-objcopy"}
if [ ! -f "$B/build.ninja" ]; then
	cmake -G Ninja -S "$L/llvm" -B "$B" -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=ON \
		-DLLVM_TARGETS_TO_BUILD="${LLVM_TARGETS:-}" -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=PDP64 \
		-DLLVM_PARALLEL_LINK_JOBS=1 -DLLVM_USE_LINKER=$LINKER \
		-DCMAKE_C_COMPILER=${CC:-clang} -DCMAKE_CXX_COMPILER=${CXX:-clang++} \
		-DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF \
		-DLLVM_ENABLE_ZLIB=OFF -DLLVM_ENABLE_ZSTD=OFF -DLLVM_ENABLE_LIBXML2=OFF -DLLVM_ENABLE_TERMINFO=OFF \
		${LLVM_USE_LINKER_FLAGS:--DCMAKE_EXE_LINKER_FLAGS=-Wl,--no-keep-memory}
fi
ninja -C "$B" -j "$J" $TARGETS
echo "built $B/bin/llvm-mc"
