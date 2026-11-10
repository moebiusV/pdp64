#!/usr/bin/env python3
"""run-refs.py WORKDIR -- the reference matrix: clang at -O0 -O1 -O2 -O3 -Os for the architectures below, on the preprocessed
corpus in WORKDIR/i-<tag>; results in WORKDIR/ref/<tool>-<arch>-<O>/static.csv.  Existing results are kept (delete a directory to redo it)."""
import os, sys, subprocess, shutil
W = sys.argv[1]
HERE = os.path.dirname(os.path.abspath(__file__))
COMMON = ['-std=gnu99', '-w', '-fno-asynchronous-unwind-tables', '-fno-unwind-tables']
CLANGW = ['-Wno-error=implicit-function-declaration', '-Wno-error=implicit-int', '-Wno-error=int-conversion', '-Wno-error=incompatible-pointer-types']
LV = ['-O0', '-O1', '-O2', '-O3', '-Os']
LV1 = LV[1:]      # -O0 only for RISC-V (the reference rows); the other architectures run -O1 -O2 -O3 -Os
cfg = []   # (tool, arch-name, input tag, [compiler cmd], levels)
for l in LV:
    cfg.append(('clang', 'rv64gc', 'rv', ['clang', '--target=riscv64-linux-gnu', '-march=rv64gc', '-mabi=lp64d', '-fno-pic'] + CLANGW, l))
for l in LV:
    cfg.append(('clang', 'rv64g', 'rv', ['clang', '--target=riscv64-linux-gnu', '-march=rv64g', '-mabi=lp64d', '-fno-pic'] + CLANGW, l))
for l in LV1:
    cfg.append(('clang', 'aarch64', 'a64', ['clang', '--target=aarch64-linux-gnu', '-fno-pic'] + CLANGW, l))
for l in LV1:
    cfg.append(('clang', 'x86_64', 'amd64', ['clang', '--target=x86_64-linux-gnu', '-fno-pic', '-fcf-protection=none'] + CLANGW, l))
for l in LV1:
    cfg.append(('clang', 'i386', 'i386', ['clang', '--target=i386-linux-gnu', '-fno-pic', '-fcf-protection=none'] + CLANGW, l))
for l in ('-O2', '-Os'):
    cfg.append(('clang', 'arm-a32', 'arm', ['clang', '--target=arm-linux-gnueabi', '-marm', '-fno-pic'] + CLANGW, l))
    cfg.append(('clang', 'arm-t32', 'arm', ['clang', '--target=arm-linux-gnueabi', '-mthumb', '-fno-pic'] + CLANGW, l))
    cfg.append(('clang', 'mips64', 'mips64', ['clang', '--target=mips64-linux-gnuabi64', '-fno-pic', '-mno-abicalls'] + CLANGW, l))
only = sys.argv[2:]
for tool, arch, tag, cmd, l in cfg:
    name = '%s-%s%s' % (tool, arch, l)
    if only and not any(o in name for o in only):
        continue
    out = '%s/ref/%s' % (W, name)
    if os.path.exists(out + '/static.csv') and os.path.getsize(out + '/static.csv') > 0 and os.path.exists(out + '/done'):
        continue
    print('==', name, flush=True)
    subprocess.run(['python3', HERE + '/ref-static.py', '%s/i-%s' % (W, tag), out, '-j', '2', '--'] + cmd + COMMON + [l], check=True)
    open(out + '/done', 'w').write(' '.join(cmd + COMMON + [l]) + '\n')
