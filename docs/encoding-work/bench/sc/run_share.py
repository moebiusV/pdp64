#!/usr/bin/env python3
"""run_share.py SIM64 OUT.tsv: the same programs with a share of the stores going to lines that another core owns (sup = 0, 5, 20 percent), L = 30 and 100, buffer depth 8, ownership prefetch on: relaxed, TSO and SC."""
import subprocess, sys, glob, os
sim, out = sys.argv[1], sys.argv[2]
specs = []
for L in (30, 100):
    for sup in (0, 5, 20):
        base = f"dc=1,dmiss={L},smiss={L},sbd=8,sup={sup},sbp=1"
        specs += [(f"R_L{L}_s{sup}", base+",cm=0"), (f"T_L{L}_s{sup}", base+",cm=1"), (f"S_L{L}_s{sup}", base+",cm=2")]
rows = []
for img in sorted(glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)), "img", "*.x"))):
    p = subprocess.run([sim] + [f"--timing=name={n},{s}" for n, s in specs] + [img], capture_output=True, text=True)
    for line in p.stderr.splitlines():
        if not line.startswith("tm "): continue
        kv = dict(x.split("=", 1) for x in line.split()[1:] if "=" in x)
        rows.append((os.path.basename(img)[:-2], kv["name"], kv["cycles"]))
with open(out, "w") as f:
    f.write("prog\tmodel\tcycles\n")
    for r in rows: f.write("\t".join(r) + "\n")
print(len(rows), "rows")
