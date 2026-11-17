#!/usr/bin/env python3
"""vecbench.py KERNELS.c OUTDIR -- the seven kernels of vec-forms.md compiled by clang for the instruction sets that have vector forms, and counted.

For each kernel and target: the instructions and the bytes of the function (every path: prologue, overlap tests, the vector loop, the remainder loop), the
vectorization width and interleave count that the compiler reports, and the instructions of the main loop (the innermost loop with the most instructions that
is the vector loop when there is one).  Targets: x86-64 AVX2, x86-64 AVX-512, AArch64 NEON, AArch64 SVE, RISC-V rv64gcv, LoongArch LASX; and for comparison the scalar
build of each (`-fno-vectorize -fno-slp-vectorize`).  Float kernels are built at -O3 and at -Ofast (the reductions need reassociation); the integer ones at -O3."""
import re, subprocess, sys, os, collections, csv
src, out = sys.argv[1:3]
os.makedirs(out, exist_ok=True)
T = [('x86-avx2', ['--target=x86_64-linux-gnu', '-mavx2', '-mfma']),
     ('x86-avx512', ['--target=x86_64-linux-gnu', '-march=skylake-avx512', '-mprefer-vector-width=512']),
     ('aarch64-neon', ['--target=aarch64-linux-gnu']),
     ('aarch64-sve', ['--target=aarch64-linux-gnu', '-march=armv9-a+sve2']),
     ('riscv-v', ['--target=riscv64-linux-gnu', '-march=rv64gcv', '-mabi=lp64d']),
     ('loongarch-lasx', ['--target=loongarch64-linux-gnu', '-mlasx'])]
SRC = open(src).read().split('\n')
START = {}
for i, l in enumerate(SRC, 1):
    m = re.match(r'(?:\w+\s+)+\**(k_\w+)\(', l)
    if m: START[m.group(1)] = i
KERNELS = ['k_prep8', 'k_put8h', 'k_dctop_sum', 'k_dctop_fill', 'k_fmac', 'k_sad', 'k_hist', 'k_ssm']
FLOAT = {'k_fmac', 'k_ssm'}
def run(c): return subprocess.run(c, capture_output=True, text=True, errors='replace')
rows = []
for tn, tf in T:
    for mode in ('vec', 'scalar'):
        for opt in ('-O3', '-Ofast'):
            fl = tf + [opt, '-fno-unroll-loops'] + (['-fno-vectorize', '-fno-slp-vectorize'] if mode == 'scalar' else [])
            o = '%s/%s-%s%s.o' % (out, tn, mode, opt)
            p = run(['clang'] + fl + ['-c', src, '-o', o, '-Rpass=loop-vectorize', '-Rpass-missed=loop-vectorize'])
            if not os.path.exists(o):
                print('FAIL', tn, p.stderr[:200]); continue
            vf = {}
            for ln in p.stderr.split('\n'):
                m = re.search(r':(\d+):\d+: remark: vectorized loop \(vectorization width: (vscale x )?(\d+), interleaved count: (\d+)', ln)
                if m: vf.setdefault(int(m.group(1)), ((m.group(2) or '') and 's', int(m.group(3)), int(m.group(4))))
            dis = run(['llvm-objdump-21', '-d', '--no-show-raw-insn', '-M', 'intel'] + [o] if tn.startswith('x86') else ['llvm-objdump-21', '-d', '--no-show-raw-insn', o]).stdout
            syms = {}
            for ln in run(['llvm-readelf-21', '-sW', o]).stdout.split('\n'):
                m = re.match(r'\s*\d+:\s+([0-9a-f]+)\s+(\d+)\s+FUNC\s+GLOBAL\s+\S+\s+\S+\s+(k_\w+)', ln)
                if m: syms[m.group(3)] = (int(m.group(1), 16), int(m.group(2)))
            ins = []
            for ln in dis.split('\n'):
                m = re.match(r'\s*([0-9a-f]+):\s+(\S+)\s*(.*)', ln)
                if m: ins.append((int(m.group(1), 16), m.group(2), m.group(3)))
            for k in KERNELS:
                if k not in syms: continue
                a, sz = syms[k]
                body = [x for x in ins if a <= x[0] < a + sz]
                addr = {x[0]: i for i, x in enumerate(body)}
                loops = []
                for i, x in enumerate(body):
                    mt = re.search(r'<(\w+)(?:\+0x([0-9a-f]+))?>', x[2])
                    if mt and mt.group(1) in syms:
                        tg = syms[mt.group(1)][0] + (int(mt.group(2), 16) if mt.group(2) else 0)
                        if tg in addr and addr[tg] <= i and re.match(r'(j|b|cb|tb|loop)', x[1]):
                            loops.append((addr[tg], i))
                inner = [l for l in loops if not any(o2 != l and l[0] <= o2[0] and o2[1] <= l[1] for o2 in loops)]
                main = max((l[1] - l[0] + 1 for l in inner), default=0)
                lo = START[k]; hi = min([s for s in START.values() if s > lo] or [10**9])
                rows.append((tn, mode, opt, k, len(body), sz, main, ';'.join('%s%dx%d' % v for ln, v in sorted(vf.items()) if lo <= ln < hi)))
with open(out + '/vecbench.csv', 'w') as f:
    w = csv.writer(f); w.writerow(['target', 'mode', 'opt', 'kernel', 'instructions', 'bytes', 'main_loop_instructions', 'vf_x_ic'])
    w.writerows(rows)
print(len(rows), 'rows')
