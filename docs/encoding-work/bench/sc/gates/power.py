#!/usr/bin/env python3
"""power.py: a simple estimate of the dynamic power of the extra structures, from the NAND2 counts of gate-results.txt.
Model (all constants are ASSUMPTIONS, not measurements):  P = sum over structures of  N_eq * alpha * C * V^2 * f
  N_eq   gates (NAND2 equivalents; a flip-flop counts 6)
  alpha  average fraction of those gates that switch in a cycle (stated per structure below)
  C      switched capacitance of one NAND2 equivalent, wire included: 1.0 fF
  V, f   0.9 V, 1 GHz
The baseline is the scalar in-order core of tools/gates (219 k to 308 k NAND2 equivalents, middle 263 k) at alpha 0.15, without caches and branch predictor.
CAM cross-check: Cain and Lipasti, ISCA 2004, Table 2 (CACTI 3.2, 0.09 micron): energy of one load-queue search, 2 read and 2 write ports."""
C = 1.0e-15; V = 0.9; F = 1.0e9
unit = C * V * V * F          # watts for one gate toggling every cycle
base_gates = 263471; base_alpha = 0.15
base = base_gates * base_alpha * unit
print("baseline scalar core, logic only: %.1f mW (%d NAND2 eq at alpha %.2f)" % (base * 1e3, base_gates, base_alpha))
def row(name, logic, ff, a_logic, a_ff):
    p = (logic * a_logic + 6 * ff * a_ff) * unit
    print("%-58s logic %6d ff %5d  alpha %.3f/%.3f  %6.2f mW  %5.2f%% of baseline" % (name, logic, ff, a_logic, a_ff, p * 1e3, 100 * p / base))
    return p
print()
print("-- in-order core")
row("store buffer, 8 entries, with forwarding CAM (TSO and SC alike)", 6540, 953, 0.12, 0.10)
row("ownership prefetch table, 4 entries", 1794, 174, 0.05, 0.05)
row("SC stall term (the only logic SC adds to TSO)", 3, 0, 0.25, 0.0)
print()
print("-- out-of-order core, snoop rate s = 0.05 invalidations per cycle (assumed); load queue entries written 0.3 per cycle")
for n, lg, ff in ((32, 9130, 1450), (64, 18834, 2892), (128, 38876, 5774)):
    row("load queue with snoop CAM, %d entries (R10000 method)" % n, lg, ff, 0.05 * 0.5, 0.3 / n + 0.01)
print()
print("-- post-retirement speculation (InvisiFence-style), 512-line L1, clock-gated state")
row("checkpoint + 2 bits per line + flash clear, model", 14219, 3073, 0.03, 0.02)
row("same with the paper's 'about one kilobyte' (8192 flops) + same logic", 14219, 8192, 0.03, 0.02)
print()
print("-- cross-check with CACTI 3.2 numbers (Cain and Lipasti 2004, Table 2, 0.09 micron, 2/2 ports), at s = 0.05 searches per cycle and 1 GHz")
for n, nj in ((16, 0.03), (32, 0.05), (64, 0.12), (128, 0.22)):
    p = nj * 1e-9 * 0.05 * F
    print("  %3d entries: %.2f nJ a search -> %5.1f mW   (%.0f%% of the %.1f mW baseline above, a mixed-process comparison)" % (n, nj, p * 1e3, 100 * p / base, base * 1e3))
