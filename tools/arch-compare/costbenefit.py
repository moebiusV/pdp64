#!/usr/bin/env python3
"""costbenefit.py DIR -- the numbers of docs/encoding-work/vec-cost-benefit.md for the kernels of games and of language-model inference (DIR/games: games.c, pcc-scalar-games.s,
vecbench-games.csv, k_*.vec.s): pcc's scalar code, the hand-written vec form, and what clang's vectorizers did on six instruction sets.  Writes DIR/games/games-summary.md.
Uses the functions of vecforms.py."""
import re, sys, csv
D = sys.argv[1]
ns = {}
src = open(__file__.replace('costbenefit.py', 'vecforms.py')).read()
sys.argv = ['vecforms', D]
exec(src.split("# ---- the eight kernels")[0], ns)
vecform, scalar = ns['vecform'], ns['scalar']
G = D + '/games'
KS = [('k_q8dot', 16, 'LLM: the int8 dot product of a quantized layer'), ('k_q4dot', 16, 'LLM: the 4-bit weights of a quantized layer (two weights a byte)'),
      ('k_rmsnorm', 8, 'LLM: a normalization (a reduction, then a map)'), ('k_softmax', 8, 'LLM: attention scores (max, exp, sum, scale)'),
      ('k_blend', 16, 'games: alpha blending of 8-bit channels'), ('k_mix16', 16, 'games: audio mixing, saturating 16-bit add'),
      ('k_vtx', 8, 'games: a 4x4 matrix on vertices (three output rows)')]
sc = scalar(G + '/pcc-scalar-games.s')
rows = list(csv.DictReader(open(G + '/vecbench-games.csv')))
L = ['## pdp64: pcc scalar code and the hand-written vec form', '',
     '| kernel | use | pcc scalar: function | pcc scalar: loop for each element | vec form: function | in the vec block | block operations for each element (256-bit strip) |', '|---|---|---:|---|---:|---:|---:|']
for k, lanes, use in KS:
    n, b = vecform(G + '/%s.vec.s' % k)
    s = sc[k]
    L.append('| %s | %s | %d | %s | %d | %d | %.2f |' % (k, use, s[0], ', '.join(map(str, s[1])), n, b, b / lanes))
L += ['', '## What clang\'s vectorizers did (the whole function; "vectorized" if the compiler reported a vector loop)', '',
      '| kernel | AVX2 | AVX-512 | NEON | RISC-V V | LASX |', '|---|---|---|---|---|---|']
for k, lanes, use in KS:
    cells = []
    fast = k in ('k_rmsnorm', 'k_softmax', 'k_vtx')
    for t in ['x86-avx2', 'x86-avx512', 'aarch64-neon', 'riscv-v', 'loongarch-lasx']:
        v = [r for r in rows if r['kernel'] == k and r['target'] == t and r['mode'] == 'vec' and r['opt'] == ('-Ofast' if fast else '-O3')][0]
        s = [r for r in rows if r['kernel'] == k and r['target'] == t and r['mode'] == 'scalar' and r['opt'] == ('-Ofast' if fast else '-O3')][0]
        cells.append('%s: %s instructions against %s scalar' % ('vectorized' if v['vf_x_ic'] else 'not vectorized', v['instructions'], s['instructions']))
    L.append('| %s | %s |' % (k, ' | '.join(cells)))
open(G + '/games-summary.md', 'w').write('\n'.join(L) + '\n')
print('\n'.join(L))
