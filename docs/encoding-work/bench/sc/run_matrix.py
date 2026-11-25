#!/usr/bin/env python3
"""run_matrix.py: run every img/*.x under the patched sim64 with a matrix of store-buffer models; write results.tsv.
usage: run_matrix.py SIM64 OUT.tsv [dsz]
Models (dmiss = smiss = L): R = relaxed, T0/T1 = TSO without/with ownership prefetch, S0/S1 = SC without/with prefetch; buffer depth 8 and 2."""
import subprocess, sys, glob, os, re
sim, out = sys.argv[1], sys.argv[2]
dsz = sys.argv[3] if len(sys.argv) > 3 else "16384"
specs = []
for L in (10, 30, 100):
    for d in (8, 2):
        base = f"dc=1,dsz={dsz},dmiss={L},smiss={L},sbd={d}"
        specs += [(f"R_L{L}_d{d}", base+",cm=0"), (f"T0_L{L}_d{d}", base+",cm=1,sbp=0"), (f"T1_L{L}_d{d}", base+",cm=1,sbp=1"),
                  (f"S0_L{L}_d{d}", base+",cm=2,sbp=0"), (f"S1_L{L}_d{d}", base+",cm=2,sbp=1")]
rows = []
for img in sorted(glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)), "img", "*.x"))):
    cmd = [sim] + [f"--timing=name={n},{s}" for n, s in specs] + [img]
    p = subprocess.run(cmd, capture_output=True, text=True)
    for line in p.stderr.splitlines():
        if not line.startswith("tm "): continue
        kv = dict(x.split("=", 1) for x in line.split()[1:] if "=" in x)
        rows.append((os.path.basename(img)[:-2], kv["name"], kv["insns"], kv["bytes"], kv["cycles"], kv.get("ex_sb", "0"), kv.get("stores", "0"), kv.get("dacc", "0"), kv.get("dmiss", "0"), kv.get("sc_stalls", "0"), kv.get("sc_fwd", "0")))
with open(out, "w") as f:
    f.write("prog\tmodel\tinsns\tbytes\tcycles\tex_sb\tstores\tdacc\tdmiss\tsc_stalls\tsc_fwd\n")
    for r in rows: f.write("\t".join(r) + "\n")
print(len(rows), "rows ->", out)
