#!/usr/bin/env python3
"""vecforms.py DIR -- the tables of docs/encoding-work/vec-forms.md from the files of docs/encoding-work/arch-data/vec-forms (DIR):

  *.vec.s, *.vecfir.s   the vec forms written by hand (the pdp64 `vec` block, proposed notation of vec-forms.md)
  pcc-scalar.s          the scalar code of pcc for kernels.c
  vecbench.csv          clang's vectorized and scalar builds for six instruction sets (tools/arch-compare/vecbench.py)
  handasm.tsv           hand-written assembly: instructions and bytes of functions (tools/arch-compare/handasm.py)
Writes DIR/vec-forms-summary.md."""
import re, sys, csv, os, glob
D = sys.argv[1]
KS = ['k_prep8', 'k_put8h', 'k_dctop_sum', 'k_dctop_fill', 'k_fmac', 'k_sad', 'k_hist', 'k_ssm']
LANES = {'k_prep8': 16, 'k_put8h': 8, 'k_dctop_sum': 32, 'k_dctop_fill': 32, 'k_fmac': 8, 'k_sad': 16, 'k_hist': 4, 'k_ssm': 8}	# lanes in a 256-bit strip, from the widest lane of the block

def vecform(path):
    n = body = 0; inblk = False; hasend = 'vend' in open(path).read()
    for ln in open(path):
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

def scalar():
    f = None; fn = {}
    for ln in open(D + '/pcc-scalar.s'):
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

L = []
sc = scalar()
L += ['## pdp64: pcc scalar code and the hand-written vec forms', '',
      '| kernel | pcc scalar: function instructions | pcc scalar: inner loop instructions (per element) | vec form: instructions of the function | of them in the vec block | block operations per element (256-bit strip) |', '|---|---:|---|---:|---:|---:|']
for k in KS:
    p = D + '/%s.vec.s' % k
    n, b = vecform(p)
    s = sc.get(k, (0, []))
    L.append('| %s | %d | %s | %d | %d | %.2f |' % (k, s[0], ', '.join(map(str, s[1])), n, b, b / LANES[k] if b else 0))
n, b = vecform(D + '/k_put8h.vecfir.s')
L.append('| k_put8h, form B (sliding window `vfir`) | %d | %s | %d | %d | %.2f |' % (sc['k_put8h'][0], ', '.join(map(str, sc['k_put8h'][1])), n, b, b / LANES['k_put8h']))
L += ['']
rows = list(csv.DictReader(open(D + '/vecbench.csv')))
L += ['## Compiled by clang: the vectorized build and the scalar build, per instruction set', '',
      'Instructions of the whole function (every path), instructions of the main loop, the vectorization width x interleave count that the compiler reports ("scalable" where it does not print a number), and the main loop per element. The float kernels are at -Ofast, the others at -O3.', '',
      '| kernel | target | function: vector build | function: scalar build | main loop | width x interleave | main loop instructions per element |', '|---|---|---:|---:|---:|---|---:|']
for k in KS:
    for t in ['x86-avx2', 'x86-avx512', 'aarch64-neon', 'aarch64-sve', 'riscv-v', 'loongarch-lasx']:
        opt = '-Ofast' if k in ('k_fmac', 'k_ssm') else '-O3'
        v = [r for r in rows if r['kernel'] == k and r['target'] == t and r['mode'] == 'vec' and r['opt'] == opt]
        s = [r for r in rows if r['kernel'] == k and r['target'] == t and r['mode'] == 'scalar' and r['opt'] == opt]
        if not v: continue
        v, s = v[0], s[0]
        m = re.match(r'(s?)(\d+)x(\d+)', v['vf_x_ic'])
        scal = bool(m and m.group(1))
        w = int(m.group(2)) * int(m.group(3)) if m and not scal else 0
        ml = int(v['main_loop_instructions'])
        if m and not scal and ml <= 2 and int(v['instructions']) > 20:
            per = '(loop not found: it holds calls)'
            vf = '%s x %s' % (m.group(2), m.group(3))
        elif not m:
            per = '%s (not vectorized)' % s['main_loop_instructions']
            vf = '-'
        elif scal:
            per = 'scalable: %d per strip of VL elements (x%s)' % (ml, m.group(2))
            vf = 'scalable x%s (interleave %s)' % (m.group(2), m.group(3))
        else:
            per = ('%.2f' % (ml / w)) if w and ml else '-'
            vf = '%s x %s' % (m.group(2), m.group(3))
        L.append('| %s | %s | %s | %s | %s | %s | %s |' % (k, t, v['instructions'], s['instructions'], v['main_loop_instructions'], vf, per))
L += ['']
L += ['## Hand-written assembly, the same functions', '', '| ISA | function | instructions | bytes |', '|---|---|---:|---:|']
for ln in open(D + '/handasm.tsv'):
    a = ln.rstrip('\n').split('\t')
    L.append('| %s | %s | %s | %s |' % tuple(a))
open(D + '/vec-forms-summary.md', 'w').write('\n'.join(L) + '\n')
print('\n'.join(L))
