#!/bin/sh
# measure-flags.sh: repeat the flags measurement (what removing the flags cost the pdp64) from a clean checkout; see docs/encoding-work/bench/flags/README.md.
#
#   tools/measure-flags.sh [--jobs N] [--corpus-subset N] [--out PREFIX] [--keep]
#
#   --jobs N            parallel jobs (default: all processors)
#   --corpus-subset N   a quick run: about N of the corpus's files and every third program (a minute or two); the default is the full corpus
#   --out PREFIX        write PREFIX.txt and PREFIX.md (default docs/encoding-work/bench/flags/results-final; a subset run defaults to a scratch name)
#   --keep              keep the scratch directory (the default removes it)
#
# BASE side (the flags still there): pdp64 at BASE_PDP (the parent of the commit that removed them), as64 ld64 sim64 built from it, and pcc at BASE_PCC built the way
# the experiment built it (32 registers, -m pdp64/32).  NOW side: this repository's HEAD (NOW_PDP) and pcc's HEAD (NOW_PCC, in PCC, default ../pcc).  Both sides come from
# `git archive` into a scratch directory under /tmp: nothing in the working trees or their build directories is read or written.  The pins can be overridden in the
# environment (BASE_PDP, BASE_PCC, NOW_PDP, NOW_PCC); the hashes used are written to the result.  Needs: gcc, python3, git, hbnf (HBNF and HBNF_TEMPLATES, default
# /tmp/hbnf-latest/hbnf, else /tmp/hbnf with ../hbnf/templates; tools/build-hbnf.sh builds one) and the OpenBSD sources (OPENBSD_SRC, default ../openbsd-src).
set -eu
cd "$(dirname "$0")/.."
ROOT=$PWD
BASE_PDP=${BASE_PDP:-8d8d07f6}      # the commit before d4362464, which took the flags out
BASE_PCC=${BASE_PCC:-82d5006b}      # pcc's last commit before 7e1bf616 (no flag instruction is emitted)
NOW_PDP=${NOW_PDP:-HEAD}
PCC=${PCC:-$(dirname "$ROOT")/pcc}
NOW_PCC=${NOW_PCC:-HEAD}
JOBS=$(nproc 2>/dev/null || echo 4); SUBSET=0; OUT=; KEEP=0
while [ $# -gt 0 ]; do
	case "$1" in
	--jobs) JOBS=$2; shift ;;
	--corpus-subset) SUBSET=$2; shift ;;
	--out) OUT=$2; shift ;;
	--keep) KEEP=1 ;;
	*) echo "usage: measure-flags.sh [--jobs N] [--corpus-subset N] [--out PREFIX] [--keep]" >&2; exit 2 ;;
	esac
	shift
done
FL=docs/encoding-work/bench/flags
if [ -z "$OUT" ]; then
	if [ "$SUBSET" = 0 ]; then OUT=$FL/results-final; else OUT=${TMPDIR:-/tmp}/measure-flags-subset-$$; fi
fi
case "$OUT" in /*) ;; *) OUT=$ROOT/$OUT ;; esac
export OPENBSD_SRC=${OPENBSD_SRC:-$(dirname "$ROOT")/openbsd-src}
[ -d "$OPENBSD_SRC/lib" ] || { echo "measure-flags: the OpenBSD sources are not at $OPENBSD_SRC (set OPENBSD_SRC)" >&2; exit 1; }
if [ -z "${HBNF:-}" ]; then
	if [ -x /tmp/hbnf-latest/hbnf ]; then HBNF=/tmp/hbnf-latest/hbnf; HBNF_TEMPLATES=${HBNF_TEMPLATES:-/tmp/hbnf-latest/hbnf-templates}
	elif [ -x /tmp/hbnf ]; then HBNF=/tmp/hbnf; HBNF_TEMPLATES=${HBNF_TEMPLATES:-$(dirname "$ROOT")/hbnf/templates}
	else echo "measure-flags: no hbnf (set HBNF and HBNF_TEMPLATES, or run tools/build-hbnf.sh)" >&2; exit 1; fi
fi
export HBNF HBNF_TEMPLATES
resolve() { git -C "$1" rev-parse --verify "$2^{commit}"; }
BP=$(resolve "$ROOT" "$BASE_PDP"); NP=$(resolve "$ROOT" "$NOW_PDP")
BC=$(resolve "$PCC" "$BASE_PCC"); NC=$(resolve "$PCC" "$NOW_PCC")
W=$(mktemp -d "${TMPDIR:-/tmp}/measure-flags.XXXXXX")
cleanup() { if [ "$KEEP" = 1 ]; then echo "measure-flags: scratch kept in $W" >&2; else rm -rf "$W"; fi; }
trap cleanup EXIT INT TERM
echo "measure-flags: scratch $W; base pdp64 $BP, pcc $BC; now pdp64 $NP, pcc $NC" >&2

# the pdp64 tools of a side: as64, ld64, sim64 (tools/build-sim64.sh of that commit)
build_pdp() {	# dir commit
	mkdir -p "$1"; git -C "$ROOT" archive "$2" | tar x -C "$1"
	(cd "$1" && tools/build-sim64.sh) >"$1/build.log" 2>&1 || { cat "$1/build.log" >&2; echo "measure-flags: the pdp64 tools of $2 did not build" >&2; exit 1; }
}
# pcc's ccom of a side
build_pcc() {	# dir commit cflags
	mkdir -p "$1"; git -C "$PCC" archive "$2" | tar x -C "$1"
	(cd "$1" && ./configure --target=pdp64-unknown-linux >cfg.log 2>&1 && cd cc/ccom && make CFLAGS="-g -O1 -std=gnu89 -w -fcommon $3" >../../mk.log 2>&1) || { echo "measure-flags: pcc $2 did not build (see $1/mk.log)" >&2; exit 1; }
	ls "$1"/cc/ccom/*-ccom | head -1
}
build_pdp "$W/pdp-base" "$BP" &
p1=$!
build_pdp "$W/pdp-now" "$NP" &
p2=$!
wait $p1; wait $p2
BCCOM=$(build_pcc "$W/pcc-base" "$BC" -DPDP64_REGS32)
NCCOM=$(build_pcc "$W/pcc-now" "$NC" "")
# the pcc of the base commit has a machine option; the flag-free one has none
mkdir -p "$W/scratch"
ver() { "$@" 2>&1 | head -1; }
python3 "$ROOT/$FL/scripts/measure.py" --work "$W/scratch" --out "$OUT" --jobs "$JOBS" --subset "$SUBSET" \
	--info "base pdp64 commit=$BP" --info "base pcc commit=$BC" --info "base pcc build=32 registers (-DPDP64_REGS32), run with -m pdp64/32" \
	--info "now pdp64 commit=$NP" --info "now pcc commit=$NC" \
	--info "openbsd sources=$(git -C "$OPENBSD_SRC" rev-parse --short HEAD 2>/dev/null || echo 'not a git tree')" \
	--info "subset=$SUBSET" --info "gcc=$(ver gcc --version)" --info "python=$(ver python3 --version)" \
	--info "host=$(uname -sm)" \
	--base-tools "$W/pdp-base/build" --base-ccom "$BCCOM" --base-ccom-args "-m pdp64/32" \
	--cur-tools "$W/pdp-now/build" --cur-ccom "$NCCOM" --cur-ccom-args "" --src-tree "$W/pdp-base" >"$W/measure.out"
echo "measure-flags: wrote $OUT.txt and $OUT.md" >&2
