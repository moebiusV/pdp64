#!/bin/sh
# compile_corpus.sh OUTDIR : every C file of tests/c, tests/c-new and the study's kern.c with pcc and with the LLVM back end
R=${PDP64:-$(pwd)}; SIB=$(dirname "$R")   # run from the pdp64 checkout; the llvm-build of ../llvm-build and pcc in build/pcc
O=$1; mkdir -p $O
for f in $R/tests/c/*.c $R/tests/c-new/*.c $R/docs/encoding-work/bench/holes-1-and-6/part-b/c/*.c; do
  n=$(basename $f .c); d=$(basename $(dirname $f)); case $f in */part-b/c/*) d=kern;; */tests/c-new/*) d=tests-c-new;; *) d=tests-c;; esac
  gcc -E -P -undef -D__pcc__ -D__LP64__ -D_LP64 $f > $O/$n.i 2>/dev/null && $R/build/pcc/ccom $O/$n.i $O/$n.pcc.s 2>/dev/null || echo "pcc FAIL $n"
  clang -S -emit-llvm -O1 -m64 -fno-builtin -ffreestanding -fno-stack-protector -mlong-double-64 -mno-sse -mno-mmx -fno-vectorize -fno-slp-vectorize -fno-unroll-loops -w -o $O/$n.ll0 $f 2>/dev/null &&
  sed -e '/^target datalayout/d' -e '/^target triple/d' -e 's/"target-cpu"="[^"]*"//g' -e 's/"target-features"="[^"]*"//g' -e 's/"tune-cpu"="[^"]*"//g' $O/$n.ll0 > $O/$n.ll &&
  $SIB/llvm-build/bin/llc -mtriple=pdp64-unknown-elf -O2 $O/$n.ll -o $O/$n.llvm.s 2>/dev/null || echo "llvm FAIL $n"
  echo "$d" > $O/$n.dir
done
