#!/bin/sh
# Build a static hbnf from github.com/moebiusV/hbnf (origin/main) plus tools/hbnf-numbers.patch (any number form everywhere) without root and without a docker daemon:
# an Alpine edge rootfs run under bwrap (user namespaces), GNAT 15 from Alpine, gprbuild and mustache-ada from
# the ada-on-alpine overlay's .apk files.  Result: $OUT/hbnf (static, runs on the host), and the templates dir.
#
#   tools/build-hbnf.sh [WORKDIR]      default /tmp/claude-1000/alpine ; output WORKDIR/hbnf and WORKDIR/hbnf-templates
set -eu
W=${1:-/tmp/claude-1000/alpine}
APKS=${HBNF_APKS:-$HOME/claude/ada-on-alpine/.work/packages}
mkdir -p "$W"; cd "$W"
if [ ! -d root/bin ]; then
	[ -f mini.tar.gz ] || curl -sfL -o mini.tar.gz https://dl-cdn.alpinelinux.org/alpine/edge/releases/x86_64/alpine-minirootfs-3.24.0-x86_64.tar.gz
	mkdir -p root && tar xzf mini.tar.gz -C root
	printf 'https://dl-cdn.alpinelinux.org/alpine/edge/main\nhttps://dl-cdn.alpinelinux.org/alpine/edge/community\n' > root/etc/apk/repositories
fi
BW="bwrap --unshare-user --uid 0 --gid 0 --bind root / --proc /proc --dev /dev --ro-bind /etc/resolv.conf /etc/resolv.conf --setenv PATH /usr/sbin:/usr/bin:/sbin:/bin"
$BW apk --usermode --no-cache add gcc-gnat musl-dev git make gmp >/dev/null
mkdir -p root/pkgs root/work && cp "$APKS"/*.apk root/pkgs/
$BW sh -c 'apk --usermode --no-cache add --allow-untrusted /pkgs/*.apk >/dev/null'
rm -rf root/work/hbnf
$BW sh -c 'cd /work && git clone -q https://github.com/moebiusV/hbnf.git'
# upstream libhbnf.gpr lists too few sources (lookahead, tree_sitter, wire-ada_lang, wire-zig are missing): list them all
python3 - <<'PY'
import glob, os, re
d = 'root/work/hbnf/'
fs = sorted(os.path.basename(f) for f in glob.glob(d + 'hbnf*.ad[sb]') if os.path.basename(f) != 'hbnf.adb')
s = open(d + 'libhbnf.gpr').read()
s = re.sub(r'for Source_Files use\s*\(.*?\);', 'for Source_Files use\n     (' + ', '.join('"%s"' % f for f in fs) + ');', s, flags=re.S)
open(d + 'libhbnf.gpr', 'w').write(s)
PY
( cd root/work/hbnf && patch -p0 -s hbnf_grammar.adb < "$OLDPWD/../claude/pdp64/tools/hbnf-numbers.patch" ) 2>/dev/null || ( cd root/work/hbnf && patch -s hbnf_grammar.adb < "$HOME/claude/pdp64/tools/hbnf-numbers.patch" )
$BW sh -c 'ADALIB=$(gcc -print-file-name=adalib); mkdir -p /work/linklibs
ln -sf $ADALIB/libgnat.a /work/linklibs/libgnat-15.a; ln -sf $ADALIB/libgnarl.a /work/linklibs/libgnarl-15.a
cd /work/hbnf && LIBRARY_PATH=/work/linklibs gprbuild -P hbnf.gpr -p -XLIBRARY_TYPE=static -q 2>&1 | grep -i "error\|failed" || true'
cp root/work/hbnf/hbnf "$W/hbnf"; rm -rf "$W/hbnf-templates"; cp -r root/work/hbnf/templates "$W/hbnf-templates"
echo "built $W/hbnf (use --templates=$W/hbnf-templates)"
