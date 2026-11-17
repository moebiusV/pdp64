#!/usr/bin/env python3
"""la-summary.py WORK OUTDIR -- the LoongArch64 rows against pdp64: the tables of docs/encoding-work/loongarch.md.

Reads WORK/r-pdp64/static.csv (pdp64-static.py) and WORK/ref/clang-loongarch64*/static.csv (run-refs.py), the bounds census WORK/bounds-O2
(boundscan.py) and the mnemonic histograms WORK/mn-*.csv (la-mnemonics.py); copies the raw per-file results to OUTDIR/loongarch/ and writes
OUTDIR/loongarch-summary.md.  Ratios are on the files both compiled (840 of 841: 651.i uses __builtin_longjmp, which clang for LoongArch refuses),
with and without file 611 (memcpy-a2.c, 27% of the pdp64 bytes), as in static-summary.md."""
import csv, os, sys, shutil, collections

W, OUT = sys.argv[1:3]
os.makedirs(OUT + '/loongarch', exist_ok=True)
EXCL = '611'


def load(p):
    return {r['file']: r for r in csv.DictReader(open(p)) if r['status'] == 'ok'}


pd = load(W + '/r-pdp64/static.csv')
cfgs = [('clang-loongarch64-O1', '-O1'), ('clang-loongarch64-O2', '-O2'), ('clang-loongarch64-O3', '-O3'), ('clang-loongarch64-Os', '-Os'),
        ('clang-loongarch64-ubsan-O2', '-O2, bounds checks as traps'), ('clang-loongarch64-ubsan-Os', '-Os, bounds checks as traps')]
data = {}
for d, label in cfgs:
    data[d] = load('%s/ref/%s/static.csv' % (W, d))
    shutil.copy('%s/ref/%s/static.csv' % (W, d), '%s/loongarch/%s-static.csv' % (OUT, d))
shutil.copy(W + '/r-pdp64/static.csv', OUT + '/loongarch/pdp64-static.csv')
common = set(pd).intersection(*[set(v) for v in data.values()])
lines = []
P = lambda f: [pd[x] for x in sorted(f)]


def tot(rows, k):
    return sum(int(r[k]) for r in rows)


for title, fs in (('files both compiled (%d)' % len(common), common), ('the same without file %s (%d)' % (EXCL, len(common - {EXCL})), common - {EXCL})):
    pb, pi = tot(P(fs), 'ibytes'), tot(P(fs), 'ins')
    lines += ['', '### ' + title, '', '| configuration | instructions | instruction bytes | insn ratio | bytes ratio | .text bytes | padding instructions |', '|---|---:|---:|---:|---:|---:|---:|',
              '| pdp64 (pcc) | {:,} | {:,} | 1.000 | 1.000 | {:,} | 0 |'.format(pi, pb, tot(P(fs), 'text'))]
    for d, label in cfgs:
        rows = [data[d][x] for x in sorted(fs)]
        i, b = tot(rows, 'ins'), tot(rows, 'ibytes')
        lines.append('| clang LoongArch64 {} | {:,} | {:,} | {:.3f} | {:.3f} | {:,} | {:,} |'.format(label, i, b, i / pi, b / pb, tot(rows, 'text'), tot(rows, 'pad_ins')))
# what the checks cost on LoongArch
for lv in ('O2', 'Os'):
    a, b = data['clang-loongarch64-' + lv], data['clang-loongarch64-ubsan-' + lv]
    fs = set(a) & set(b)
    ra, rb = [a[x] for x in sorted(fs)], [b[x] for x in sorted(fs)]
    lines += ['', '- bounds checks as traps, -%s: +%s instructions (+%.2f%%), +%s bytes (+%.2f%%) on %d files' % (lv, '{:,}'.format(tot(rb, 'ins') - tot(ra, 'ins')), 100.0 * (tot(rb, 'ins') - tot(ra, 'ins')) / tot(ra, 'ins'),
              '{:,}'.format(tot(rb, 'ibytes') - tot(ra, 'ibytes')), 100.0 * (tot(rb, 'ibytes') - tot(ra, 'ibytes')) / tot(ra, 'ibytes'), len(fs))]


def mn(p):
    return {r['mnemonic']: int(r['count']) for r in csv.DictReader(open(p))} if os.path.exists(p) else {}


a, b = mn(W + '/mn-Os.csv'), mn(W + '/mn-ubsan-Os.csv')
if a:
    shutil.copy(W + '/mn-Os.csv', OUT + '/loongarch/mnemonics-Os.csv')
    shutil.copy(W + '/mn-ubsan-Os.csv', OUT + '/loongarch/mnemonics-ubsan-Os.csv')
    ta = sum(a.values())
    lines += ['', '### Most used instructions, clang -Os (%s instructions, %d mnemonics)' % ('{:,}'.format(ta), len(a)), '', '| mnemonic | count | share |', '|---|---:|---:|']
    for k, v in sorted(a.items(), key=lambda kv: -kv[1])[:20]:
        lines.append('| `%s` | %s | %.1f%% |' % (k, '{:,}'.format(v), 100.0 * v / ta))
    lines += ['', 'The bound-check instructions: ' + ', '.join('`%s` %d' % (k, a.get(k, 0)) for k in ('asrtle.d', 'asrtgt.d', 'ldgt.b', 'ldgt.w', 'ldgt.d', 'ldle.b', 'ldle.w', 'ldle.d', 'stgt.w', 'stgt.d', 'stle.w', 'stle.d')) + ' (the plain and the sanitized build alike).']
    inc = sorted(((b.get(k, 0) - a.get(k, 0), k) for k in set(a) | set(b)), reverse=True)[:6]
    lines += ['', 'What the checks add, -Os (instructions): ' + ', '.join('`%s` %+d' % (k, d) for d, k in inc) + '. The trap itself is `amswap.w $zero, $ra, $zero`, an illegal encoding LLVM uses for `ubsantrap`: %d of them, one per check.' % b.get('amswap.w', 0) + ' ' + ('Each check costs %.1f instructions on average.' % ((sum(b.values()) - ta) / b['amswap.w']) if b.get('amswap.w') else '')]
open(OUT + '/loongarch-summary.md', 'w').write('\n'.join(lines) + '\n')
print('\n'.join(lines))
