#!/usr/bin/env python3
"""vecforms.py DIR -- the tables of docs/encoding-work/vec-forms.md and gemm-forms.md from the files of docs/encoding-work/arch-data/vec-forms (DIR):

  *.vec.s, *.vecfir.s                the vec forms written by hand (the pdp64 `vec` block, proposed notation of vec-forms.md)
  pcc-scalar.s, vecbench.csv         the scalar code of pcc and clang's builds for the eight kernels of vec-forms.md (kernels.c)
  handasm.tsv                        hand-written assembly: instructions and bytes of functions (tools/arch-compare/handasm.py)
  blas/*.vec.s, blas/k_sgemm_nt.*.s  the forms for the BLAS calls of cugpt and cngpt (gemm-forms.md), blas/pcc-scalar-blas.s, blas/vecbench-blas.csv, blas/openblas-loops.tsv
Writes DIR/vec-forms-summary.md and DIR/blas/gemm-forms-summary.md."""
import re, sys, csv, os
D = sys.argv[1]
TARGETS = ['x86-avx2', 'x86-avx512', 'aarch64-neon', 'aarch64-sve', 'riscv-v', 'loongarch-lasx']

def vecform(path):
    txt = open(path).read()
    n = body = 0; inblk = False; hasend = 'vend' in txt
    for ln in txt.split('\n'):
        s = ln.split(';')[0].strip()
        if not s: continue
        s = re.sub(r'^[.\w$]+:\s*', '', s)
        if not s or s.startswith('.'): continue
        n += 1
        mn = s.split()[0]
        if mn == 'vec':
            inblk = True
            if not hasend: body = 1; inblk = False
            continue
        if mn == 'vend': inblk = False; continue
        if inblk: body += 1
    return n, body

def scalar(path):
    f = None; fn = {}
    for ln in open(path):
        s = ln.split(';')[0].rstrip()
        if not s.strip(): continue
        m = re.match(r'^(\.?[A-Za-z_][\w.$]*):', s)
        if m and not m.group(1).startswith('.L'): f = m.group(1); fn[f] = []; continue
        if f is None: continue
        if m: fn[f].append(('label', m.group(1))); continue
        t = s.strip()
        if t.startswith('.'): continue
        fn[f].append(('ins', t))
    out = {}
    for k, items in fn.items():
        n = sum(1 for i in items if i[0] == 'ins')
        lab = {it[1]: i for i, it in enumerate(items) if it[0] == 'label'}
        loops = []
        for i, it in enumerate(items):
            if it[0] == 'ins':
                tg = it[1].split(',')[-1].split()[-1]
                if tg in lab and lab[tg] <= i and re.match(r'(b|cb|sob|jmp)', it[1]): loops.append((lab[tg], i))
        inner = [l for l in loops if not any(o != l and l[0] <= o[0] and o[1] <= l[1] for o in loops)]
        out[k] = (n, sorted(sum(1 for it in items[a:b + 1] if it[0] == 'ins') for a, b in inner))
    return out

def compiled(rows, ks, fast):
    L = ['| kernel | target | function: vector build | function: scalar build | main loop | width x interleave | main loop instructions per element |', '|---|---|---:|---:|---:|---|---:|']
    for k in ks:
        for t in TARGETS:
            opt = '-Ofast' if k in fast else '-O3'
            v = [r for r in rows if r['kernel'] == k and r['target'] == t and r['mode'] == 'vec' and r['opt'] == opt]
            s = [r for r in rows if r['kernel'] == k and r['target'] == t and r['mode'] == 'scalar' and r['opt'] == opt]
            if not v: continue
            v, s = v[0], s[0]
            m = re.match(r'(s?)(\d+)x(\d+)', v['vf_x_ic'])
            scal = bool(m and m.group(1))
            w = int(m.group(2)) * int(m.group(3)) if m and not scal else 0
            ml = int(v['main_loop_instructions'])
            if m and not scal and ml <= 2 and int(v['instructions']) > 20:
                per = '(loop not found: it holds calls)'; vf = '%s x %s' % (m.group(2), m.group(3))
            elif not m:
                per = '%s (not vectorized)' % s['main_loop_instructions']; vf = '-'
            elif scal:
                per = 'scalable: %d per strip of VL elements (x%s)' % (ml, m.group(2)); vf = 'scalable x%s (interleave %s)' % (m.group(2), m.group(3))
            else:
                per = ('%.2f' % (ml / w)) if w and ml else '-'; vf = '%s x %s' % (m.group(2), m.group(3))
            L.append('| %s | %s | %s | %s | %s | %s | %s |' % (k, t, v['instructions'], s['instructions'], v['main_loop_instructions'], vf, per))
    return L

# ---- the eight kernels
KS = ['k_prep8', 'k_put8h', 'k_dctop_sum', 'k_dctop_fill', 'k_fmac', 'k_sad', 'k_ssm']
LANES = {'k_prep8': 16, 'k_put8h': 8, 'k_dctop_sum': 32, 'k_dctop_fill': 32, 'k_fmac': 8, 'k_sad': 16, 'k_ssm': 8}
sc = scalar(D + '/pcc-scalar.s')
L = ['## pdp64: pcc scalar code and the hand-written vec forms', '',
     '| kernel | pcc scalar: function instructions | pcc scalar: inner loop instructions (per element) | vec form: instructions of the function | of them in the vec block | block operations per element (256-bit strip) |', '|---|---:|---|---:|---:|---:|']
for k in KS:
    n, b = vecform(D + '/%s.vec.s' % k)
    s = sc.get(k, (0, []))
    L.append('| %s | %d | %s | %d | %d | %.2f |' % (k, s[0], ', '.join(map(str, s[1])), n, b, b / LANES[k] if b else 0))
n, b = vecform(D + '/k_put8h.vecfir.s')
L.append('| k_put8h, form B (sliding window `vfir`) | %d | %s | %d | %d | %.2f |' % (sc['k_put8h'][0], ', '.join(map(str, sc['k_put8h'][1])), n, b, b / LANES['k_put8h']))
L += ['', '## Compiled by clang: the vectorized build and the scalar build, per instruction set', '',
      'Instructions of the whole function (every path), instructions of the main loop, the vectorization width x interleave count that the compiler reports, and the main loop per element. The float kernels are at -Ofast, the others at -O3.', '']
rows = list(csv.DictReader(open(D + '/vecbench.csv')))
L += compiled(rows, KS, {'k_fmac', 'k_ssm'})
L += ['', '## Hand-written assembly, the same functions', '', '| ISA | function | instructions | bytes |', '|---|---|---:|---:|']
for ln in open(D + '/handasm.tsv'):
    L.append('| %s | %s | %s | %s |' % tuple(ln.rstrip('\n').split('\t')))
open(D + '/vec-forms-summary.md', 'w').write('\n'.join(L) + '\n')

# ---- the BLAS kernels
B = D + '/blas'
if os.path.isdir(B):
    KB = ['k_ddot', 'k_daxpy', 'k_dscal', 'k_dgemv_n', 'k_dgemv_t', 'k_dger']
    sb = scalar(B + '/pcc-scalar-blas.s')
    G = ['## pdp64: pcc scalar code and the hand-written vec forms (BLAS of cugpt and cngpt)', '',
         '| kernel | pcc scalar: function instructions | pcc scalar: inner loop per multiply-add or element | vec form: function | in the block | block operations per element (256-bit strip: 4 doubles) |', '|---|---:|---|---:|---:|---:|']
    for k in KB:
        n, b = vecform(B + '/%s.vec.s' % k)
        s = sb[k]
        G.append('| %s | %d | %s | %d | %d | %.2f |' % (k, s[0], ', '.join(map(str, s[1])), n, b, b / 4.0))
    G += ['', '### `sgemm`, the linear layer of cngpt (Y = X . W^T), two forms (the tile and the GEMM unit were removed, errata 170)', '',
          '| form | instructions of the function | in the block | multiply-adds per strip of the block (VL = 8 floats) | block operations per multiply-add |', '|---|---:|---:|---:|---:|']
    ss = sb['k_sgemm_nt']
    G.append('| pcc scalar (the triple loop) | %d | inner loop %s | 1 | %s per multiply-add |' % (ss[0], ', '.join(map(str, ss[1])), ss[1][0] if ss[1] else '-'))
    for name, f, macs in [('1. dot product for each output (`vec` over K)', 'k_sgemm_nt.dot.s', 8), ('2. register-blocked micro-kernel (8 accumulators, broadcast multiply-add)', 'k_sgemm_nt.ukr.s', 64)]:		# (forms 3 and 4, the tile and the GEMM unit, were removed from the ISA in wave 1, errata 170; their files are gone)
        n, b = vecform(B + '/' + f)
        G.append('| %s | %d | %d | %d | %.3f |' % (name, n, b, macs, b / macs))
    G += ['', '### Compiled by clang (the BLAS loops, -Ofast)', '']
    G += compiled(list(csv.DictReader(open(B + '/vecbench-blas.csv'))), KB + ['k_sgemm_nt'], set(KB + ['k_sgemm_nt']))
    G += ['', '### OpenBLAS: the main loop of its single-precision GEMM kernel, per instruction set', '', '| ISA | loop |', '|---|---|']
    for ln in open(B + '/openblas-loops.tsv'):
        a = ln.rstrip('\n').split('\t')
        G.append('| %s | %s |' % (a[0], a[1]))
    open(B + '/gemm-forms-summary.md', 'w').write('\n'.join(G) + '\n')
print(open(D + '/vec-forms-summary.md').read()[:200])
if os.path.isdir(B): print('\n'.join(G[:30]))
