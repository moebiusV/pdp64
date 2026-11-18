#!/usr/bin/env python3
"""vectop.py FREQ.TSV ISA KIND [N] -- the N most frequent tokens of each class for one ISA and kind (asm or intr), all projects together."""
import sys, collections, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib; V = importlib.import_module("vsurvey-class")
isa, kind = sys.argv[2], sys.argv[3]
N = int(sys.argv[4]) if len(sys.argv) > 4 else 8
rows = V.classify(V.load(sys.argv[1]))
byc = collections.defaultdict(collections.Counter); tot = 0
for i,p,k,t,n,f,c in rows:
    if i == isa and k == kind and c not in ('scalar','free'):
        byc[c][t] += n; tot += n
print('%s %s: %d vector instructions' % (isa, kind, tot))
for c, cnt in sorted(byc.items(), key=lambda x: -sum(x[1].values())):
    print('%-6s %5.1f%%  %s' % (c, 100.0*sum(cnt.values())/tot, ' '.join('%s:%d' % x for x in cnt.most_common(N))))
