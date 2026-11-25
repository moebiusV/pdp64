#!/bin/sh
# runbook.sh OUTDIR BUILDABOOK : make a book dir from the converted tree and build rendered/*.md
set -e
O=$1; B=${2:-/tmp/nest/bab/buildabook}
rm -rf $O/bk; mkdir -p $O/bk/chapters
cp $O/outline.txt $O/bk/; cp $O/src/*.md $O/bk/chapters/
cp /tmp/nest/pdp/book/template.typ $O/bk/
cat > $O/bk/book.conf <<'C'
title "pdp64"
build {
 outline outline.txt
 src chapters
 out rendered
 template template.typ
 number-map number_map.csv
}
C
cd $O/bk
: > filemap.txt
grep -E '^[nca]:' /tmp/nest/pdp/book/sources.txt | while read tok p; do f=$(basename $p); [ -f chapters/$f ] && echo "${tok#*:}:$f" >> filemap.txt; done
/usr/bin/time -f "buildabook typst: %es %MKB" $B typst
