#!/usr/bin/env python3
"""gen3-table.py DIR W: reads DIR/tr-NAME.wW written by gen3 (one run per trace) and prints the tables of colour-width-3-or-4.md.
Percentages are of the SMALL chunks freed (the slab-model frees); the pass probability columns assume the stale pointer is used after j reuses of its slot, j geometric (mean mu)."""
import sys, glob, statistics, re
d, W = sys.argv[1], sys.argv[2]
rows = {}
for f in sorted(glob.glob('%s/tr-*.w%s' % (d, W))):
    nm = re.search(r'tr-(\w+)\.w', f).group(1); L = open(f).read().split('\n')
    h = L[0].split(); fs = int(h[7]); ch = {int(a.split(':')[0]): int(a.split(':')[1]) for a in L[1].split()[1:]}
    pol = {}
    for l in L[2:]:
        if not l.startswith('pol'): continue
        t = l.split(); n = t[1]; i = t.index('w'); dist = [int(x) for x in t[t.index('first-recurrence-distance') + 1:i]]; w = [float(x) for x in t[i + 1:]]
        pol[n] = dict(recur=int(t[5]), viol=int(t[7]), dist=dist, w=w)
    rows[nm] = dict(fs=fs, ch=ch, pol=pol, allocs=int(h[1]), reuses=int(h[5]))
def pct(a, b): return 100.0 * a / b if b else 0.0
print('Table 1 (W=%s): small frees; share of them whose slot is reused at least k times before the page drains or the trace ends (percent), k = 1, 2, 3, 6' % W)
print('%-7s %9s %7s %6s %6s %6s' % ('trace', 'frees', '>=1', '>=2', '>=3', '>=6'))
cols = {1: [], 2: [], 3: [], 6: []}
for nm, r in rows.items():
    v = [pct(r['ch'].get(k, 0) if k <= 8 else 0, r['fs']) for k in (1, 2, 3, 6)]
    for k, x in zip((1, 2, 3, 6), v): cols[k].append(x)
    print('%-7s %9d %7.1f %6.1f %6.1f %6.1f' % (nm, r['fs'], *v))
print('%-7s %9s %7.1f %6.1f %6.1f %6.1f' % ('median', '', *[statistics.median(cols[k]) for k in (1, 2, 3, 6)]))
print('%-7s %9s %7.1f %6.1f %6.1f %6.1f' % ('mean', '', *[statistics.mean(cols[k]) for k in (1, 2, 3, 6)]))
print()
print('Table 2 (W=%s): expected pass probability of a stale pointer, percent of frees, if it is used after j reuses of its slot with j geometric of mean mu (j=0 is caught: the slot is free)' % W)
for mu_i, mu in enumerate((0.5, 1, 2, 4)):
    print(' mu = %s' % mu)
    print(' %-7s %8s %8s %8s %8s %8s %8s %8s %8s' % ('trace', 'A6', 'A3', 'F14', 'F6', 'F14b', 'F6b', 'E6', 'E3'))
    acc = {k: [] for k in ('A6', 'A3', 'F14', 'F6', 'F14b', 'F6b', 'E6', 'E3')}
    for nm, r in rows.items():
        v = {k: pct(r['pol'][k]['w'][mu_i], r['fs']) for k in acc}
        for k in acc: acc[k].append(v[k])
        print(' %-7s %8.3f %8.3f %8.3f %8.3f %8.3f %8.3f %8.3f %8.3f' % (nm, *[v[k] for k in acc]))
    print(' %-7s %s' % ('median', ' '.join('%8.3f' % statistics.median(acc[k]) for k in acc)))
    print(' %-7s %s' % ('mean', ' '.join('%8.3f' % statistics.mean(acc[k]) for k in acc)))
print()
print('Table 3: the guaranteed window = the smallest first-recurrence distance seen over all traces (reuses of the slot after which a colour can first repeat), and neighbour violations')
for k in ('A6', 'A3', 'F14', 'F6', 'F14b', 'F6b', 'E6', 'E3'):
    first = 99; viol = 0; ex = 0
    for r in rows.values():
        p = r['pol'][k]; viol += p['viol']
        for j, c in enumerate(p['dist'], 1):
            if c: first = min(first, j)
    print(' %-4s first possible recurrence at reuse %2d (so caught for %2d reuses, deterministic); neighbour violations %d' % (k, first, first - 1, viol))
