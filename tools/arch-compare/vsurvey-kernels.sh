#!/bin/bash
# vsurvey-kernels.sh OUTDIR -- compile vsurvey-kernels.c (20 small loops) with clang for 13 vector targets and keep the assembly in OUTDIR/<target>.s;
# then: python3 -I vsurvey-kmn.py OUTDIR/avx2.s sad dot_i8 ...   prints the mnemonics of each function.  The survey used clang 19.1.7 (Debian), -O3 -fno-unroll-loops -fno-slp-vectorize.
here=$(cd "$(dirname "$0")" && pwd); out=${1:?outdir}; mkdir -p "$out"
declare -A T
T[avx2]="--target=x86_64-linux-gnu -mavx2 -mfma"
T[avx512vnni]="--target=x86_64-linux-gnu -mavx512f -mavx512bw -mavx512vl -mavx512dq -mavx512vnni -mavx512vbmi -mfma"
T[avxvnni]="--target=x86_64-linux-gnu -mavx2 -mavxvnni -mfma"
T[sse41]="--target=x86_64-linux-gnu -msse4.1"
T[neon]="--target=aarch64-linux-gnu -march=armv8-a"
T[neondot]="--target=aarch64-linux-gnu -march=armv8.4-a+dotprod+i8mm"
T[sve2]="--target=aarch64-linux-gnu -march=armv9-a+sve2"
T[rvv]="--target=riscv64-linux-gnu -march=rv64gcv_zvl128b -mrvv-vector-bits=zvl"
T[lasx]="--target=loongarch64-linux-gnu -mlasx"
T[p10]="--target=powerpc64le-linux-gnu -mcpu=power10"
T[msa]="--target=mips64el-linux-gnuabi64 -march=mips64r6 -mmsa"
T[z15]="--target=s390x-linux-gnu -march=z15"
T[hvx]="--target=hexagon-unknown-elf -mcpu=hexagonv68 -mhvx -mhvx-length=128b"
for t in "${!T[@]}"; do clang -O3 -S -fno-unroll-loops -fno-slp-vectorize ${T[$t]} -o "$out/$t.s" "$here/vsurvey-kernels.c" 2> "$out/$t.err" || echo "FAIL $t"; done
