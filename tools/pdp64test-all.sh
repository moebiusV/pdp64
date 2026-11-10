#!/bin/sh
#
# pdp64test-all.sh -- the pdp64 test programs (first line "/* expect: N */") with a ccom, for a target, under several flag sets.
#
# usage: [PDP64CCOM=ccom] [PDP64TOOLS=dir] [PDP64TESTS=dirs] pdp64test-all.sh ["flags" ...]
# (the defaults of pdp64test.sh: this tree's build/ and the ccom of tools/build-pcc.sh)
# Tests: $PDP64TESTS (default: the a64tests of the v7unix-toolchain at ../facetlang/pdp11/v7unix-toolchain next to this repository, tests/c and tests/c-new of the pdp64 repository, space separated).
# Flag sets: the defaults (all optimizations), then each optimization off in turn, and -xssa, -xccp.
#
set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
: ${PDP64TESTS:="$here/../../facetlang/pdp11/v7unix-toolchain/tools/a64tests $here/../tests/c $here/../tests/c-new"}
if [ $# -eq 0 ]; then
	set -- "" "-xno-dmr" "-xno-temps" "-xno-deljumps" "-xno-inline" "-xno-dce" "-xssa" "-xno-tailcall" "-xccp"
fi
pass=0; fail=0
for flags in "$@"; do
	for d in $PDP64TESTS; do
	for t in "$d"/*.c; do
		want=$(sed -n '1s/.*expect: \(-\{0,1\}[0-9]*\).*/\1/p' "$t")
		got=$("$here/pdp64test.sh" $flags "$t" 2>&1 | tail -1)
		if [ "$got" = "$want" ]; then pass=$((pass+1))
		else fail=$((fail+1)); echo "FAIL [$flags] $(basename "$t"): want $want, got $got"; fi
	done
	done
done
echo "pdp64test-all: $pass passed, $fail failed"
[ $fail -eq 0 ]
