#!/usr/bin/env python3
"""strip-total.py [OUTDIR] -- the tables of docs/encoding-work/vec-strip.md section 3 to 5 from the synthesis results of run-strip.sh (OUTDIR/strip-32.tsv, strip-16.tsv, strip-8.tsv, ref-32.tsv).

Totals are composed as silicon-total.py composes the wave-1 vector unit (variant B: one array of 8 x 8 products, flip-flop registers): registers + lane ALU + rounding shifts + multiplier array with
the vdacc tree + vsad (an estimate) + reductions (vacc and vmaxacc, vminacc) + narrowing store + vfir (+ 112 halo flip-flops) + segment load and store + vtbl + load/store alignment and merge + strip
control (4 adders and an estimate of 2,000, which do not depend on the strip); wave 2 adds compare and select (vceq, vcgt, vcgtu, vbsl) and the conversions; the floating-point lanes are the fma32 lanes
(SNB/4).  NAND2 equivalents = NAND + NOT/2 + 6 per flip-flop (+ 4 per latch).  FPGA: LUT4 of synth_ecp5 and LUT1-6 of synth_xilinx -family xc7, the multipliers (MULT18X18D, DSP48E1), flip-flops apart;
the register file maps to distributed RAM, counted in LUT sites (TRELLIS_DPR16X4 as 4 LUT4, RAM32M as 4 LUT6 sites: the packing of real tools may take more or less) and listed in its own row.
The Xilinx compare uses w_vcmp2 (fixed comparators, no dynamic shifts) instead of w_vcmp_mw, whose Xilinx netlist is a mapping artifact (89,804 LUT6 at 256 bits)."""
import sys, os
here = os.path.dirname(os.path.abspath(__file__))
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, 'strip-results')
WIDTHS = (32, 16, 8)
COLS = ('nand', 'dff', 'latch', 'e_lut', 'e_ff', 'e_mult', 'e_dpr', 'e_ram', 'x_lut', 'x_ff', 'x_dsp', 'x_ramb', 'x_ramsites')
def load(fn):
    d = {}
    for ln in open(fn):
        p = ln.split('\t')
        if len(p) < 15: continue
        try: d[(int(p[0]), p[1])] = dict(zip(COLS, (int(x) for x in p[2:15])))
        except ValueError: pass
    return d
D = {}
for n in WIDTHS: D.update(load(os.path.join(out, 'strip-%d.tsv' % n)))
R = load(os.path.join(out, 'ref-32.tsv'))
def g(n, m, c): return D[(n, 'w_' + m)][c]
def nand(n, m): r = D[(n, 'w_' + m)]; return r['nand'] + 6 * r['dff'] + 4 * r['latch']
def e4(n, m): r = D[(n, 'w_' + m)]; return r['e_lut'] + 4 * r['e_dpr']
def x6(n, m): r = D[(n, 'w_' + m)]; return r['x_lut'] + r['x_ramsites']
def k(x): return '{:,}'.format(int(round(x)))
md = []
# ---- 1. the check at 256 bits
PAIRS = [('fma32x8', 'fma32xn'), ('cvt_both8', 'cvt_both'), ('ms8x8', 'ms8x8'), ('ms8x8_notree', 'ms8x8_notree'), ('lanealu_mw', 'lanealu_mw'), ('lanealu_mw_noavg', 'lanealu_mw_noavg'),
         ('shiftround_mw', 'shiftround_mw'), ('shiftlane_mw', 'shiftlane_mw'), ('segload', 'segload'), ('segstore', 'segstore'), ('vacc_naive', 'vacc_naive'), ('vmmacc', 'vmmacc'),
         ('narrow_both', 'narrow_both'), ('vfir_added', 'vfir_added'), ('dacc_tree', 'dacc_tree'), ('sum32_bu', 'sum_bu'), ('vsad_bu', 'vsad_bu'), ('vtbl_g16', 'vtbl_g16'), ('vcmp_mw', 'vcmp_mw'),
         ('vbsl', 'vbsl'), ('vregs16_r3', 'vregs16_r3'), ('vmem_ld', 'vmem_ld'), ('vmem_st', 'vmem_st')]
def committed():
    c = {}
    try:
        for ln in open(os.path.join(here, 'vec-silicon-blocks.tsv')):
            p = ln.split()
            if len(p) >= 3: c[p[0]] = int(p[1]) + 6 * int(p[2]) + (4 * int(p[3]) if len(p) > 3 else 0)
    except OSError: pass
    f = {}
    try:
        for ln in open(os.path.join(here, 'fpga-blocks.tsv')):
            p = ln.split()
            if len(p) >= 10 and not ln.startswith('#'): f[p[1]] = (int(p[2]), int(p[4]), int(p[6]), int(p[8]))
    except OSError: pass
    return c, f
CN, CF = committed()
md.append('## Check: the parameterised blocks at 256 bits against the existing ones\n')
md.append('`ref` is the module of vec2.v, vec3.v, mem2.v or fp2.v synthesised again by this run (strip-synth.sh, the commands of gates2.sh and fpga.sh); `w_` is the parameterised module of vecw.v at SNB = 32; `committed` is the study\'s file (vec-silicon-blocks.tsv, fpga-blocks.tsv).  NAND2 equivalents with flip-flops at 6; LUT4 and LUT6 as the flows give them (for the register file the distributed RAM sites are added: see the header of strip-total.py).  diff = w_ against ref.\n')
md.append('| block | NAND2 ref | NAND2 w_ | diff | NAND2 committed | LUT4 ref | LUT4 w_ | diff | LUT4 committed | LUT6 ref | LUT6 w_ | diff | LUT6 committed | DSP ecp5 ref / w_ | DSP xc7 ref / w_ |')
md.append('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|')
worst = {}
for rn, wn in PAIRS:
    r = R.get((32, rn)); w = D.get((32, 'w_' + wn))
    if not r or not w: md.append('| %s | missing | | | | | | | | | | | | | |' % rn); continue
    rn_ = r['nand'] + 6 * r['dff'] + 4 * r['latch']; wn_ = w['nand'] + 6 * w['dff'] + 4 * w['latch']
    re4 = r['e_lut'] + 4 * r['e_dpr']; we4 = w['e_lut'] + 4 * w['e_dpr']
    rx6 = r['x_lut'] + r['x_ramsites']; wx6 = w['x_lut'] + w['x_ramsites']
    def df(a, b): return (100.0 * (b - a) / a) if a else (0.0 if b == 0 else 999.0)
    ds = (df(rn_, wn_), df(re4, we4), df(rx6, wx6))
    worst[rn] = max(abs(x) for x in ds)
    cf = CF.get(rn)
    md.append('| %s | %s | %s | %+.1f%% | %s | %s | %s | %+.1f%% | %s | %s | %s | %+.1f%% | %s | %d / %d | %d / %d |' % (
        rn, k(rn_), k(wn_), ds[0], k(CN[rn]) if rn in CN else '-', k(re4), k(we4), ds[1], k(cf[0]) if cf else '-', k(rx6), k(wx6), ds[2], k(cf[2]) if cf else '-', r['e_mult'], w['e_mult'], r['x_dsp'], w['x_dsp']))
over = sorted(((v, n) for n, v in worst.items() if v > 3.0), reverse=True)
md.append('\nBlocks where w_ at 256 bits differs from ref by more than 3%% in NAND2, LUT4 or LUT6: %s.\n' % (', '.join('%s %.1f%%' % (n, v) for v, n in over) if over else 'none'))
# ---- 2. per block at three widths
BLK = [('vregs16_r3', 'vector register file, 16 x strip, 3 read, 1 write'), ('lanealu_mw', 'lane ALU, all widths (with avg)'), ('shiftround_mw', 'shifts with rounding'),
       ('narrow_both', 'narrowing store with rounding shift'), ('ms8x8', 'array of 8 x 8 products with the vdacc tree'), ('ms8x8_notree', '  (the array without the tree)'), ('dacc_tree', '  (the vdacc tree alone)'),
       ('vacc_naive', 'vacc, one tree per source type'), ('vmmacc', 'vmaxacc, vminacc'), ('sum_bu', 'sum of the bytes (the tree of vsad / vacc.bu)'), ('vsad_bu', 'vsad.bu standalone'),
       ('vtbl_g16', 'vtbl.b (register form)'), ('vcmp_mw', 'compare (vceq, vcgt, vcgtu), study form'), ('vcmp2', 'compare, fixed comparators (no dynamic shift)'), ('vbsl', 'vbsl'),
       ('cvt_both', 'conversions vcvt.f.l, vcvt.l.f, SNB/4 lanes each'), ('vfir_added', 'vfir (without the 112 halo flip-flops)'), ('segload', 'segment load (de-interleave)'), ('segstore', 'segment store (interleave)'),
       ('vmem_ld', 'load alignment with widening'), ('vmem_st', 'store merge'), ('fma32xn', 'floating-point multiply-add lanes (SNB/4)')]
def cell(n, m, f): return k(f(n, m))
md.append('## Every block at the three strips\n')
md.append('NAND2 equivalents (flip-flops at 6), then ECP5 LUT4 (distributed RAM at 4 LUT4 a DPR16X4), Xilinx xc7 LUT6 (RAM32M at 4 sites), the multipliers MULT18X18D / DSP48E1.  Ratio: the block at 128 (64) bits over the block at 256 bits.\n')
md.append('| block | NAND2 256 | 128 | 64 | ratio 128 | ratio 64 | LUT4 256 | 128 | 64 | LUT6 256 | 128 | 64 | MULT18 256 / 128 / 64 | DSP48 256 / 128 / 64 |')
md.append('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|')
def rat(a, b): return '%.2f' % (b / a) if a else '-'
for m, desc in BLK:
    if (32, 'w_' + m) not in D: continue
    nn = [nand(n, m) for n in WIDTHS]; ee = [e4(n, m) for n in WIDTHS]; xx = [x6(n, m) for n in WIDTHS]
    mu = [D[(n, 'w_' + m)]['e_mult'] for n in WIDTHS]; ds = [D[(n, 'w_' + m)]['x_dsp'] for n in WIDTHS]
    md.append('| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |' % (desc, k(nn[0]), k(nn[1]), k(nn[2]), rat(nn[0], nn[1]), rat(nn[0], nn[2]), k(ee[0]), k(ee[1]), k(ee[2]), k(xx[0]), k(xx[1]), k(xx[2]),
        ' / '.join(map(str, mu)), ' / '.join(map(str, ds))))
# ---- 3. the totals
def comp(n):
    """the wave-1, wave-2, fp totals at strip n: dict of unit -> (nand2, lut4, lut6, ff4, ff6, mult, dsp)"""
    NB = {32: 32, 16: 16, 8: 8}[n]
    def blk(m, xm=None):
        r = D[(n, 'w_' + m)]; rx = D[(n, 'w_' + (xm or m))]
        return (r['nand'] + 6 * r['dff'] + 4 * r['latch'], r['e_lut'] + 4 * r['e_dpr'], rx['x_lut'] + rx['x_ramsites'], r['e_ff'], rx['x_ff'], r['e_mult'], rx['x_dsp'])
    def add(*bs): return tuple(sum(b[i] for b in bs) for i in range(7))
    est = lambda nand_, lut: (nand_, lut, lut, 0, 0, 0, 0)
    U = {}
    U['registers 16 x strip'] = blk('vregs16_r3')
    U['lane ALU'] = blk('lanealu_mw')
    U['shifts with rounding'] = blk('shiftround_mw')
    U['multiplier array + vdacc tree'] = blk('ms8x8')
    U['vsad (estimate: 8 NAND2 and 8 LUT a byte)'] = est(25 * NB, 8 * NB)
    U['reductions (vacc, vmaxacc, vminacc)'] = add(blk('vacc_naive'), blk('vmmacc'))
    U['narrowing store'] = blk('narrow_both')
    vf = blk('vfir_added'); U['vfir (+ 112 halo flip-flops)'] = (vf[0] + 6 * 112, vf[1], vf[2], vf[3] + 112, vf[4] + 112, 0, 0)
    U['segment load and store'] = add(blk('segload'), blk('segstore'))
    U['vtbl.b'] = blk('vtbl_g16')
    U['load alignment and store merge'] = add(blk('vmem_ld'), blk('vmem_st'))
    U['strip control (4 adders + estimate; not scaled)'] = (4 * 660 + 2000, 4 * 64 + 500, 4 * 64 + 500, 0, 0, 0, 0)
    W1 = add(*U.values())
    W2u = {}
    W2u['compare, select (vcmp_mw for NAND2 and ECP5, vcmp2 for Xilinx) + vbsl'] = add(blk('vcmp_mw', 'vcmp2'), blk('vbsl'))
    W2u['conversions'] = blk('cvt_both')
    W2 = add(*W2u.values())
    FP = blk('fma32xn')
    return U, W1, W2u, W2, FP
md.append('## The wave-1 vector unit, by unit\n')
C = {n: comp(n) for n in WIDTHS}
md.append('| unit | NAND2 256 | 128 | 64 | LUT4 256 | 128 | 64 | LUT6 256 | 128 | 64 |')
md.append('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|')
for u in C[32][0]:
    md.append('| %s | %s |' % (u, ' | '.join(k(C[n][0][u][i]) for i in (0, 1, 2) for n in WIDTHS)))
for u in C[32][2]:
    md.append('| (wave 2) %s | %s |' % (u, ' | '.join(k(C[n][2][u][i]) for i in (0, 1, 2) for n in WIDTHS)))
md.append('')
md.append('## Totals and the saving against the 256-bit strip\n')
md.append('Flip-flops are inside the NAND2 count (6 each); in the FPGA columns they are listed apart (LUT4 and LUT6 are logic and distributed RAM only).  The registers are 16 x strip bits of distributed RAM with 3 read ports (a copy of the array for each port) in both FPGA flows: no block RAM.\n')
md.append('| configuration | strip | NAND2 eq | saving | ECP5 LUT4 | saving | ECP5 FF | MULT18X18D | xc7 LUT6 | saving | xc7 FF | DSP48E1 |')
md.append('|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|')
TOT = {}
for cfgname, parts in (('wave 1, 16 integer lanes at 256 bits (8 at 64)', ('W1',)), ('wave 1 and 2', ('W1', 'W2')), ('wave 1 and 2 with floating-point lanes', ('W1', 'W2', 'FP'))):
    for n in WIDTHS:
        U, W1, W2u, W2, FP = C[n]
        T = {'W1': W1, 'W2': W2, 'FP': FP}
        tot = tuple(sum(T[p][i] for p in parts) for i in range(7))
        TOT[(cfgname, n)] = tot
    for n in WIDTHS:
        t = TOT[(cfgname, n)]; b = TOT[(cfgname, 32)]
        sv = lambda i: ('%.0f%%' % (100.0 * (1 - t[i] / b[i]))) if n != 32 else '-'
        md.append('| %s | %d bit | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |' % (cfgname if n == 32 else '', 8 * n, k(t[0]), sv(0), k(t[1]), sv(1), k(t[3]), t[5], k(t[2]), sv(2), k(t[4]), t[6]))
md.append('\nThe lane count follows the strip (the lane names refer to the 256-bit strip): at 128 bits 8 halfword lanes, 4 word lanes, 8 byte-product halfword lanes of the array (a vdot.b strip is 4 lanes of 4 products), 2 floating-point lanes; at 64 bits 4 halfword lanes, 2 word lanes, 1 doubleword lane, 2 floating-point lanes.')
md.append('Floating-point lane count: %s.' % ', '.join('%d bit %d fma32 lanes' % (8 * n, n // 4) for n in WIDTHS))
# ---- 4. fits
md.append('\n## Fit in the FPGA parts (wave 1 and 2 with floating-point lanes; the vector unit alone, not the scalar core, not the memory system)\n')
md.append('| strip | ECP5-85F: 84k LUT4, 156 18x18 | Artix-7 100T: 63k LUT6, 240 DSP48 | Artix-7 200T: 134k LUT6, 740 DSP48 |\n|---|---|---|---|')
for n in WIDTHS:
    t = TOT[('wave 1 and 2 with floating-point lanes', n)]
    t1 = TOT[('wave 1 and 2', n)]
    md.append('| %d bit | %.0f%% of the LUT4, %d of 156 multipliers (without fp lanes: %.0f%%, %d) | %.0f%% of the LUT6, %d of 240 DSP (without fp lanes: %.0f%%, %d) | %.0f%% of the LUT6, %d of 740 DSP (without fp lanes: %.0f%%) |' % (
        8 * n, 100.0 * t[1] / 84000, t[5], 100.0 * t1[1] / 84000, t1[5], 100.0 * t[2] / 63000, t[6], 100.0 * t1[2] / 63000, t1[6], 100.0 * t[2] / 134000, t[6], 100.0 * t1[2] / 134000))
# the machine-readable composition
with open(os.path.join(out, 'area.tsv'), 'w') as f:
    f.write('configuration\tstrip_bits\tnand2\tecp5_lut4\tecp5_ff\tecp5_mult18\txc7_lut6\txc7_ff\txc7_dsp48\n')
    for (cfgname, n), t in TOT.items():
        f.write('%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n' % (cfgname, 8 * n, t[0], t[1], t[3], t[5], t[2], t[4], t[6]))
print('\n'.join(md))
