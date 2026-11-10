#!/usr/bin/env python3
"""summarize.py WORKDIR OUTDIR -- read the per-configuration static.csv files and write
  OUTDIR/static-wide.csv   one row per corpus file, columns <config>:ins, <config>:ibytes (status != ok -> empty)
  OUTDIR/static-summary.md the tables used by the report (totals, common subset with pdp64/32, ratios, per-corpus bytes)
Configurations: pdp64/32 and pdp64/16 (WORKDIR/r-p32, r-p16), pcc amd64/i386 (r-pcc-<arch>-<A|C>), the GCC/clang matrix (WORKDIR/ref/<name>)."""
import os, sys, csv, collections
W, OUT = sys.argv[1:3]
os.makedirs(OUT, exist_ok=True)
index = [l.rstrip('\n').split('\t') for l in open(W + '/i-a64/index.tsv')]
corp = {r[0]: r[1] for r in index}
cfgs = collections.OrderedDict()
def add(name, d):
    p = d + '/static.csv'
    if os.path.exists(p) and os.path.exists(d + '/done'):
        cfgs[name] = {r['file']: r for r in csv.DictReader(open(p))}
for n, d in (('pdp64/32 (pcc)', 'r-p32'), ('pdp64/16 (pcc)', 'r-p16')):
    if os.path.exists(W + '/' + d + '/static.csv'):
        cfgs[n] = {r['file']: r for r in csv.DictReader(open(W + '/' + d + '/static.csv'))}
for a in ('amd64', 'i386'):
    for v, lab in (('A', "project flags"), ('C', "pdp64's flag set")):
        add('pcc %s, %s' % (a, lab), '%s/r-pcc-%s-%s' % (W, a, v))
if os.path.isdir(W + '/ref'):
    order = ['O0', 'O1', 'O2', 'O3', 'Os']
    names = sorted(os.listdir(W + '/ref'), key=lambda s: (s.split('-O')[0], order.index('O' + s.split('-O')[1]) if 'O' + s.split('-O')[1] in order else 9))
    for nm in names:
        add(nm, W + '/ref/' + nm)
base = cfgs['pdp64/32 (pcc)']
def tot(rows, files, k):
    return sum(int(rows[f][k] or 0) for f in files)
def okf(rows):
    return [f for f, r in rows.items() if r['status'] == 'ok']
with open(OUT + '/static-wide.csv', 'w') as f:
    w = csv.writer(f)
    keys = list(cfgs)
    w.writerow(['file', 'corpus'] + [c + ':' + k for c in keys for k in ('ins', 'ibytes')])
    for f_ in sorted(base):
        row = [f_, corp.get(f_, '')]
        for c in keys:
            r = cfgs[c].get(f_)
            ok = r and r['status'] == 'ok'
            row += [r['ins'] if ok else '', r['ibytes'] if ok else '']
        w.writerow(row)
bok = set(okf(base))
L = []
L.append('| configuration | files ok | instructions | instruction bytes | B/insn | insn ratio | bytes ratio | insn ratio w/o memcpy-a2 | bytes ratio w/o memcpy-a2 | padding bytes (not counted) | .text bytes | .text ratio |')
L.append('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|')
for c, rows in cfgs.items():
    ok = okf(rows)
    com = [f for f in ok if f in bok]
    com2 = [f for f in com if f != '611']
    ins, by = tot(rows, ok, 'ins'), tot(rows, ok, 'ibytes')
    r = lambda fl, k: (tot(rows, fl, k) / tot(base, fl, k)) if fl and tot(base, fl, k) else 0
    pad = tot(rows, ok, 'pad_bytes') if 'pad_bytes' in next(iter(rows.values())) else 0
    txt = tot(rows, ok, 'text')
    L.append('| %s | %d | %s | %s | %.3f | %.3f | %.3f | %.3f | %.3f | %s | %s | %.3f |' % (c, len(ok), format(ins, ','), format(by, ','), by / ins if ins else 0,
             r(com, 'ins'), r(com, 'ibytes'), r(com2, 'ins'), r(com2, 'ibytes'), format(pad, ','), format(txt, ','), r(com, 'text')))
L.append('')
L.append('.text = the whole text section of the object: for pdp64 instructions + constant pools + padding (1,197,088 against 964,158 instruction bytes); for the others instructions + alignment padding.  Ratios are against pdp64/32 on the files both compiled (all 841 for pcc; the reference compilers lose the files listed in the report).')
L.append('')
L.append('Without memcpy-a2.c (file 611; 27% of the pdp64 bytes, a test that is mostly copies of one struct size; the reference compilers unroll it differently), common files:')
L.append('')
L.append('| configuration | instruction bytes | bytes ratio | instructions | insn ratio |')
L.append('|---|---:|---:|---:|---:|')
for c, rows in cfgs.items():
    ok = okf(rows)
    com = [f for f in ok if f in bok and f != '611']
    cb, ci = tot(base, com, 'ibytes'), tot(base, com, 'ins')
    rb, ri = tot(rows, com, 'ibytes'), tot(rows, com, 'ins')
    L.append('| %s | %s | %.3f | %s | %.3f |' % (c, format(rb, ','), rb / cb, format(ri, ','), ri / ci))
L.append('')
L.append('RISC-V linker relaxation, estimated: each R_RISCV_CALL relocation is an unrelaxed auipc+jalr pair (8 bytes, 2 instructions) that GNU ld or lld shrinks to one jal (4 bytes, 1 instruction) when the target is within 1 MiB; ratios are against pdp64/32 unrelaxed on the common files.  Compare pdp64/32, whose own relaxation (4-byte call instead of 6) is a further 3.76% of the linked text (integration.md 4.1).')
L.append('')
L.append('| configuration | call relocations | instruction bytes, calls relaxed | bytes ratio | instructions, calls relaxed | insn ratio |')
L.append('|---|---:|---:|---:|---:|---:|')
for c, rows in cfgs.items():
    if 'rv64' not in c:
        continue
    ok = okf(rows)
    com = [f for f in ok if f in bok]
    nc = tot(rows, com, 'calls')
    rb, ri = tot(rows, com, 'ibytes') - 4 * nc, tot(rows, com, 'ins') - nc
    cb, ci = tot(base, com, 'ibytes'), tot(base, com, 'ins')
    L.append('| %s | %s | %s | %.3f | %s | %.3f |' % (c, format(nc, ','), format(rb, ','), rb / cb, format(ri, ','), ri / ci))
L.append('')
L.append('Instruction bytes by corpus (all files each configuration compiled; the count of files in brackets), selected configurations:')
sel = [c for c in cfgs if c in ('pdp64/32 (pcc)', 'pcc amd64, project flags', 'pcc i386, project flags') or c in ('clang-rv64gc-O2', 'clang-rv64gc-Os', 'clang-rv64g-O2', 'clang-rv64g-Os', 'gcc-rv64gc-O2', 'gcc-rv64gc-Os', 'clang-aarch64-O2', 'clang-aarch64-Os')]
cs = sorted(set(corp.values()))
L.append('| corpus (files) | ' + ' | '.join(sel) + ' |')
L.append('|---|' + '---:|' * len(sel))
for c_ in cs:
    fl = [f for f in corp if corp[f] == c_]
    cells = []
    for c in sel:
        ok = [f for f in fl if cfgs[c].get(f, {}).get('status') == 'ok']
        cells.append(format(tot(cfgs[c], ok, 'ibytes'), ',') + ('' if len(ok) == len(fl) else ' [%d]' % len(ok)))
    L.append('| %s (%d) | ' % (c_, len(fl)) + ' | '.join(cells) + ' |')
open(OUT + '/static-summary.md', 'w').write('\n'.join(L) + '\n')
print('\n'.join(L))
