#!/usr/bin/env python3
"""rodata-cst.py INDIR -- bytes of numeric constants that clang puts outside .text for RISC-V (merged constant sections .rodata.cst4/8/16/32, and
.sdata/.sbss are not counted), summed over the corpus, for one level: the counterpart of the constant pools that pdp64 keeps inside .text.
usage: rodata-cst.py INDIR LEVEL      e.g.  rodata-cst.py /scratch/i-rv -Os"""
import os, re, sys, subprocess, tempfile, concurrent.futures as cf
indir, level = sys.argv[1:3]
cmd = ['clang', '--target=riscv64-linux-gnu', '-march=rv64gc', '-mabi=lp64d', '-fno-pic', '-std=gnu99', '-w', '-fno-asynchronous-unwind-tables',
       '-fno-unwind-tables', '-Wno-error=implicit-function-declaration', '-Wno-error=implicit-int', '-Wno-error=int-conversion',
       '-Wno-error=incompatible-pointer-types', level]
def one(n):
    with tempfile.TemporaryDirectory() as w:
        o = w + '/x.o'
        if subprocess.run(cmd + ['-c', '-x', 'c', '-o', o, '%s/%s.i' % (indir, n)], capture_output=True).returncode:
            return 0, 0
        s = subprocess.run(['llvm-readelf-21', '-S', '-W', o], capture_output=True, text=True).stdout
        cst = tot = 0
        for l in s.split('\n'):
            m = re.search(r'\]\s+(\.\S+)\s+\w+\s+[0-9a-f]+\s+[0-9a-f]+\s+([0-9a-f]+)', l)
            if m and m.group(1).startswith('.rodata.cst'):
                cst += int(m.group(2), 16)
        return cst, 1
names = sorted(f[:-2] for f in os.listdir(indir) if f.endswith('.i'))
with cf.ThreadPoolExecutor(2) as ex:
    r = list(ex.map(one, names))
print('level %s: constant-section bytes %d over %d files' % (level, sum(a for a, b in r), sum(b for a, b in r)))
