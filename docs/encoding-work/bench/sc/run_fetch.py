#!/usr/bin/env python3
"""run_fetch.py SIM64 OUT.tsv: instructions, bytes, cycles for each program at fetch widths W = 4, 8, 16 bytes a cycle and issue widths 1 and 2 (relaxed store model, D-cache on, L = 30)."""
import subprocess, sys, glob, os
sim, out = sys.argv[1], sys.argv[2]
specs = [(f"W{W}_iw{iw}", f"dc=1,dmiss=30,smiss=30,cm=0,W={W},iw={iw}") for W in (4, 8, 16) for iw in (1, 2)]
rows = []
for img in sorted(glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)), "img", "*.x"))):
    p = subprocess.run([sim] + [f"--timing=name={n},{s}" for n, s in specs] + [img], capture_output=True, text=True)
    for line in p.stderr.splitlines():
        if not line.startswith("tm "): continue
        kv = dict(x.split("=", 1) for x in line.split()[1:] if "=" in x)
        rows.append((os.path.basename(img)[:-2], kv["name"], kv["insns"], kv["bytes"], kv["cycles"], kv["fe_seq"], kv["fe_taken"], kv["fe_misp"], kv["ex_load"], kv["ex_dmiss"]))
with open(out, "w") as f:
    f.write("prog\tmodel\tinsns\tbytes\tcycles\tfe_seq\tfe_taken\tfe_misp\tex_load\tex_dmiss\n")
    for r in rows: f.write("\t".join(r) + "\n")
print(len(rows), "rows")
