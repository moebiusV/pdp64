#!/usr/bin/env python3
"""summarize.py results.tsv: print, for each store-miss latency L and buffer depth d, the slowdown of TSO and SC against the relaxed model (cycles ratio - 1, in %), per program, with and without ownership prefetch."""
import sys, collections
f = sys.argv[1]; L_sel = sys.argv[2:] or ["10","30","100"]
d = collections.defaultdict(dict)
for ln in open(f).read().splitlines()[1:]:
    p, m, ins, by, cyc, exsb, st, da, dm, scs, fw = ln.split("\t")
    d[p][m] = (int(cyc), int(ins), int(by), int(exsb), int(st), int(da), int(dm))
progs = sorted(d)
print("insns per program:", ", ".join(f"{p} {d[p]['R_L30_d8'][1]}" for p in progs))
for L in L_sel:
  for dep in (8, 2):
    print(f"\n== store-miss latency {L}, buffer depth {dep}: run time against the relaxed model with 8 buffer entries, % longer ==")
    print("%-8s %8s %8s %8s %8s   %s" % ("prog", "TSO,no-pf", "TSO,pf", "SC,no-pf", "SC,pf", "R cycles"))
    sums = collections.defaultdict(float)
    for p in progs:
        r = d[p][f"R_L{L}_d8"][0]
        vals = [100.0 * (d[p][f"{k}_L{L}_d{dep}"][0] / r - 1) for k in ("T0", "T1", "S0", "S1")]
        for k, v in zip(("T0","T1","S0","S1"), vals): sums[k] += d[p][f"{k}_L{L}_d{dep}"][0]
        sums["R"] += r
        print("%-8s %8.1f %8.1f %8.1f %8.1f   %d" % ((p,) + tuple(vals) + (r,)))
    print("%-8s %8.1f %8.1f %8.1f %8.1f   (total cycles of all programs)" % (("ALL",) + tuple(100.0 * (sums[k] / sums["R"] - 1) for k in ("T0","T1","S0","S1"))))
