#!/usr/bin/env python3
"""handkernels.py DAV1D_DIR CFGDIR_A64 CFGDIR_RV OUTDIR -- the hand-written SIMD kernels of dav1d, one exported function against the same function
on the other instruction sets.

dav1d writes its pixel kernels twice or three times in assembly: AArch64 NEON (src/arm/64/*.S), RISC-V vector (src/riscv/64/*.S) and x86 (src/x86/*.asm,
SSE, AVX2 and AVX-512; NASM, not assembled here).  This assembles every .S with clang (config.h with HAVE_ASM and the architecture switched on in
CFGDIR_*), reads the symbol table (llvm-readelf) for the global FUNC symbols dav1d_*, counts the instructions in each one's extent from llvm-objdump-21,
and joins the two ISAs on the name without the `dav1d_` prefix and the `_neon`/`_rvv`/... suffix.  Writes OUTDIR/funcs.csv (name, instructions and bytes per ISA)
and OUTDIR/handkernels.md (totals over the functions both have, and by family)."""
import os, re, sys, subprocess, glob, collections, csv

d, ca, cr, out = sys.argv[1:5]
os.makedirs(out, exist_ok=True)
SUF = re.compile(r'_(neon|rvv|sve2?|dotprod|i8mm|avx2|avx512icl|avx512|sse2|ssse3|sse4)$')
FAMILY = re.compile(r'^(cdef|ipred|mc|itx|filmgrain|loopfilter|looprestoration|msac|refmvs|pal|lf_mask)')


def sh(cmd, **k):
    return subprocess.run(cmd, capture_output=True, text=True, errors='replace', **k)


def kernels(isa, files, flags, cfg):
    res = {}
    for f in files:
        o = '%s/%s-%s.o' % (out, isa, os.path.basename(f))
        p = sh(['clang'] + flags + ['-c', '-x', 'assembler-with-cpp', '-I' + d, '-I' + d + '/src', '-I' + cfg, f, '-o', o])
        if p.returncode:
            print('skip', isa, f, (p.stderr.strip().split('\n') or [''])[0][:100])
            continue
        syms = {}
        for ln in sh(['llvm-readelf-21', '-sW', o]).stdout.split('\n'):
            m = re.match(r'\s*\d+:\s+([0-9a-f]+)\s+(\d+)\s+FUNC\s+GLOBAL\s+\S+\s+\S+\s+(dav1d_\S+)', ln)
            if m:
                syms[int(m.group(1), 16)] = (int(m.group(2)), m.group(3))
        ins = []
        for ln in sh(['llvm-objdump-21', '-d', '--no-show-raw-insn', o]).stdout.split('\n'):
            m = re.match(r'\s*([0-9a-f]+):\s+(\S+)', ln)
            if m:
                ins.append((int(m.group(1), 16), m.group(2)))
        addrs = [a for a, _ in ins]
        import bisect
        order = sorted(syms)
        end = (addrs[-1] + 4) if addrs else 0
        for k, a in enumerate(order):
            sz, name = syms[a]
            if sz == 0:							# the assembler macros of dav1d emit no .size here: the function runs to the next exported one
                sz = (order[k + 1] if k + 1 < len(order) else end) - a
            lo = bisect.bisect_left(addrs, a)
            hi = bisect.bisect_left(addrs, a + sz)
            vec = sum(1 for _, mn in ins[lo:hi] if re.match(r'(v|\.)', mn) or mn.startswith(('ld1', 'st1', 'ld2', 'ld3', 'ld4', 'st2', 'st3', 'st4', 'ushll', 'sshll', 'umull', 'smull', 'mla', 'mls', 'addv', 'uaddlv', 'ext', 'zip', 'uzp', 'trn', 'tbl', 'cmhi', 'cmgt', 'cmeq', 'bsl', 'bif', 'bit', 'sqadd', 'uqadd', 'sqsub', 'uqsub', 'umin', 'umax', 'smin', 'smax', 'abs', 'dup', 'ins', 'umov', 'fmla', 'fmul', 'fadd')))
            res[name] = dict(ins=hi - lo, bytes=sz, vec=vec, fam=re.sub(r'16$', '', os.path.splitext(os.path.basename(f))[0]))
    return res


a64 = kernels('a64', sorted(f for f in glob.glob(d + '/src/arm/64/*.S') if not re.search(r'(sve|dotprod|i8mm|util|asm_debug|common|tmpl)', os.path.basename(f))),
              ['--target=aarch64-linux-gnu', '-march=armv8-a'], ca)
rv = kernels('rv', sorted(f for f in glob.glob(d + '/src/riscv/64/*.S') if not re.search(r'(cpu|common)', os.path.basename(f))),
             ['--target=riscv64-linux-gnu', '-march=rv64gcv', '-mabi=lp64d'], cr)


def norm(n):
    return SUF.sub('', n[len('dav1d_'):])


A = {norm(k): v for k, v in a64.items()}
R = {norm(k): v for k, v in rv.items()}
common = sorted(set(A) & set(R))
with open(out + '/funcs.csv', 'w') as f:
    w = csv.writer(f)
    w.writerow(['function', 'a64_ins', 'a64_bytes', 'rvv_ins', 'rvv_bytes'])
    for n in common:
        w.writerow([n, A[n]['ins'], A[n]['bytes'], R[n]['ins'], R[n]['bytes']])
fam = collections.defaultdict(lambda: [0, 0, 0, 0, 0])
for n in common:
    k = A[n]['fam']
    fam[k][0] += 1; fam[k][1] += A[n]['ins']; fam[k][2] += R[n]['ins']; fam[k][3] += A[n]['bytes']; fam[k][4] += R[n]['bytes']
L = ['AArch64 NEON: %d exported functions, %s instructions, %s bytes; RISC-V vector: %d exported functions, %s instructions, %s bytes; in common (same name): %d.' % (
    len(A), '{:,}'.format(sum(v['ins'] for v in A.values())), '{:,}'.format(sum(v['bytes'] for v in A.values())), len(R), '{:,}'.format(sum(v['ins'] for v in R.values())), '{:,}'.format(sum(v['bytes'] for v in R.values())), len(common)),
     '', '| family | functions | NEON instructions | RVV instructions | RVV / NEON | NEON bytes | RVV bytes | RVV / NEON |', '|---|---:|---:|---:|---:|---:|---:|---:|']
t = [0, 0, 0, 0, 0]
for k, v in sorted(fam.items()):
    L.append('| %s | %d | %s | %s | %.2f | %s | %s | %.2f |' % (k, v[0], '{:,}'.format(v[1]), '{:,}'.format(v[2]), v[2] / v[1] if v[1] else 0, '{:,}'.format(v[3]), '{:,}'.format(v[4]), v[4] / v[3] if v[3] else 0))
    t = [x + y for x, y in zip(t, v)]
L.append('| all | %d | %s | %s | %.2f | %s | %s | %.2f |' % (t[0], '{:,}'.format(t[1]), '{:,}'.format(t[2]), t[2] / t[1] if t[1] else 0, '{:,}'.format(t[3]), '{:,}'.format(t[4]), t[4] / t[3] if t[3] else 0))
va = sum(v['vec'] for v in a64.values()); vi = sum(v['ins'] for v in a64.values())
vr = sum(v['vec'] for v in rv.values()); ir_ = sum(v['ins'] for v in rv.values())
L += ['', 'Vector instructions as a share of the kernel text: NEON %.0f%%, RVV %.0f%% (a mnemonic that begins with v on RISC-V, a NEON mnemonic by list on AArch64: approximate).' % (100.0 * va / vi if vi else 0, 100.0 * vr / ir_ if ir_ else 0)]
open(out + '/handkernels.md', 'w').write('\n'.join(L) + '\n')
print('\n'.join(L))
