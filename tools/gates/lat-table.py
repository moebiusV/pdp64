#!/usr/bin/env python3
"""lat-table.py [OUTDIR] -- the depth table and the latency tables of docs/encoding-work/vec-latency.md.

Reads OUTDIR/depth.tsv (depth-synth.sh: SNB, module, flow, ltp, levels, dsp, cells), and writes
  OUTDIR/depth.md                  the depth of every module, flow and width; the depth and latency of every class
  OUTDIR/latency-fpga.txt, latency-asic.txt, tables/{fpga-lo,fpga-hi,asic-lo,asic-hi,unit}.txt     the latency tables (`class latency interval`, `class@strip ...` for a strip of 8, 16 bytes)
  sim64/latency-fpga.txt, latency-asic.txt, sim64/vlatency-defaults.h   the same two tables mid, the built-in defaults of sim64 (--latency=fpga|asic)
EVERY number derived here is an ASSUMPTION about delay, clock and pipeline: depth is measured (levels), the rest is parameters (PARAMS below).
latency = max(1, ceil(levels x delay_per_level / (period - register_overhead))) + dsp_stages x dsp_cycles  (cycles; 'ld' and 'st': 0 is allowed, the alignment stage of the memory instructions)
"""
import os, sys, math
HERE = os.path.dirname(os.path.abspath(__file__)); R = os.path.dirname(os.path.dirname(HERE))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'latency-results')
rows = {}		# (snb, module, flow) -> (ltp, levels, dsp, cells)
for ln in open(os.path.join(OUT, 'depth.tsv')):
    f = ln.rstrip('\n').split('\t')
    if len(f) < 7: continue
    rows[(int(f[0]), f[1], f[2])] = (int(f[3]), float(f[4]), int(f[5]), int(f[6]))
# ---- the assumed delays: (delay per level ns, clock period ns, register overhead ns per stage, DSP stage cycles)
PARAMS = {
    'fpga-lo':  ('ecp5', 0.6,   10.0, 0.5,  1),
    'fpga':     ('ecp5', 0.9,   10.0, 0.75, 2),
    'fpga-hi':  ('ecp5', 1.2,   10.0, 1.0,  3),
    'asic-lo':  ('nand', 0.05,  1.0,  0.1,  0),
    'asic':     ('nand', 0.075, 0.75, 0.1,  0),
    'asic-hi':  ('nand', 0.1,   0.5,  0.1,  0),
}
# ---- the classes: modules whose depths combine; mode 'local' = the depth of the lane (measured at the strip of 8 bytes, which holds the widest lane: at 16 and 32 bytes the lane-wise blocks of the
# study contain a structural false path through the carries of neighbouring bytes, section 3), 'wide' = the depth at the strip itself (trees and networks);  'max' or 'sum' of the parts
CLASSES = [
    ('alu',    'max', [('w_lanealu_mw', 'local')], 'lane ALU add sub logic min max abs average, saturating'),
    ('cmp',    'max', [('w_vcmp2', 'local')], 'vceq vcgt vcgtu'),
    ('bsl',    'max', [('w_vbsl', 'local')], 'vbsl'),
    ('shift',  'max', [('w_shiftround_mw', 'local')], 'vshl vshr vsar and the rounding vsarr vshrr'),
    ('narrow', 'max', [('w_narrow_both', 'local')], 'the narrowing of vsts (rounding shift, saturation)'),
    ('mul8',   'max', [('w_ms8x8_notree', 'local')], 'vmul.b and the 8 x 8 products of vdot.b'),
    ('mul16',  'max', [('ms16_lo', 'fixed')], 'vmul.w (low half)'),
    ('mulh16', 'max', [('ms16_hi_mla', 'fixed')], 'vmulh vmulhu vmulhr vmla on halfwords'),
    ('mul32',  'max', [('mul32s', 'fixed')], 'vmul.l and 32-bit multiplies'),
    ('mul64',  'max', [('mul64', 'fixed')], 'vmul.q: the scalar 64 x 64 multiplier as the lane multiplier'),
    ('dot',    'max', [('w_ms8x8_notree', 'local'), ('ms16_all', 'fixed')], 'vdot vdotu vdotsu (the larger of the byte and the halfword form)'),
    ('dacc',   'max', [('w_ms8x8', 'wide')], 'vdacc: products, then the reduction tree into a scalar'),
    ('sad',    'max', [('w_vsad_bu', 'wide')], 'vsad.bu'),
    ('acc',    'max', [('w_vacc_naive', 'wide'), ('w_sum_bu', 'wide')], 'vacc'),
    ('mmacc',  'max', [('w_vmmacc', 'wide')], 'vmaxacc vminacc'),
    ('fir',    'sum', [('ms16_lo', 'fixed'), ('w_vfir_added', 'wide')], 'vfir: one tap = a 16-bit multiply and the add of the window (ESTIMATE: the sum of the two blocks)'),
    ('tbl',    'max', [('w_vtbl_g16', 'wide')], 'vtbl'),
    ('lseg',   'max', [('w_segload', 'wide')], 'vlseg2..4 de-interleave (after the load alignment)'),
    ('sseg',   'max', [('w_segstore', 'wide')], 'vsseg2..4 interleave (before the store merge)'),
    ('cvt',    'max', [('w_cvt_both', 'local')], 'vcvt between 32-bit integers and binary32'),
    ('fma',    'max', [('fma32', 'fixed')], 'binary32 add sub mul fma (one lane of fma32x8)'),
    ('fma64',  'sum', [('mul53', 'fixed'), ('shr106', 'fixed'), ('add106', 'fixed'), ('norm106', 'fixed')], 'binary64 add sub mul fma (ESTIMATE: the sum of the four blocks of core.v; not a synthesised block)'),
    ('ld',     'max', [('w_vmem_ld', 'wide')], 'load alignment and widening, after the memory\'s own latency (vmemlat)'),
    ('st',     'max', [('w_vmem_st', 'wide')], 'store merge'),
    ('misc',   'zero', [], 'vclr, vlen: a register write'),
]
SCALAR = [('alu64', 'alu64', 'scalar ALU'), ('shift64', 'shift64', 'scalar shifts'), ('bitops64', 'bitops64', 'bit counts and reversal'), ('mul64', 'mul64', 'scalar 64 x 64 multiplier'),
          ('div64', 'div64', 'one iteration of the divider (64 iterations, 1 quotient bit each: 64 cycles when one iteration fits a cycle)'), ('tlb32', 'tlb32', 'translation buffer match and read'),
          ('ldalign', 'ldalign', 'scalar load alignment'), ('stmerge', 'stmerge', 'scalar store merge'), ('clmul64', 'clmul64', 'carry-less multiply'), ('fma32 (scalar)', 'fma32', 'scalar binary32 fma'),
          ('mul53', 'mul53', 'double-precision multiplier 53 x 53')]
def get(mod, flow, snb): return rows.get((snb, mod, flow))
def depth(cls, flow, strip):
    """(levels, dsp) of the class at the strip (bytes) in the flow; None if a part is missing"""
    name, how, parts, _ = cls
    if how == 'zero': return (0.0, 0)
    vals = []
    for m, mode in parts:
        snb = 8 if mode == 'local' else strip if mode == 'wide' else 32
        v = get(m, flow, snb)
        if v is None and mode == 'local': v = get(m, flow, 8)
        if v is None: return None
        vals.append((v[1], v[2]))
    if how == 'sum': return (sum(v[0] for v in vals), sum(v[1] for v in vals))
    return max(vals)
def cycles(levels, dsp, par):
    fl, d, P, o, dc = par
    return max(1, math.ceil(levels * d / (P - o) - 1e-9)) + dsp * dc if levels > 0 or dsp else 1
def lat(cls, par, strip):
    dep = depth(cls, par[0], strip)
    if dep is None: return None
    c = cycles(dep[0], dep[1], par)
    if cls[0] in ('ld', 'st'): c = c - 1 if c > 1 else 0		# the alignment stage after the one the cache access already contains
    return c
tables = {}
for t, par in PARAMS.items():
    tables[t] = {s: {c[0]: lat(c, par, s) for c in CLASSES} for s in (8, 16, 32)}
tables['unit'] = {s: {c[0]: (0 if c[0] in ('ld', 'st') else 1) for c in CLASSES} for s in (8, 16, 32)}
missing = sorted({c[0] for c in CLASSES for s in (8, 16, 32) for t in PARAMS if tables[t][s][c[0]] is None})
if missing: sys.exit('missing depth for classes: %s' % ' '.join(missing))
HDR = {
 'fpga': 'ASSUMED latencies, cycles: levels of LUT4 (synth_ecp5) x 0.9 ns per level with routing / (10 ns clock - 0.75 ns register overhead), rounded up; a multiplier primitive on the path adds 2 cycles',
 'fpga-lo': 'ASSUMED latencies (optimistic): 0.6 ns per LUT4 level, 10 ns clock, 0.5 ns register overhead, 1 cycle a DSP stage',
 'fpga-hi': 'ASSUMED latencies (pessimistic): 1.2 ns per LUT4 level, 10 ns clock, 1.0 ns register overhead, 3 cycles a DSP stage',
 'asic': 'ASSUMED latencies, cycles: NAND2/NOT levels (synth -flatten; abc -g NAND) x 0.075 ns per level / (0.75 ns clock - 0.1 ns register overhead), rounded up',
 'asic-lo': 'ASSUMED latencies (optimistic): 0.05 ns per gate level, 1 ns clock (1 GHz), 0.1 ns register overhead',
 'asic-hi': 'ASSUMED latencies (pessimistic): 0.1 ns per gate level, 0.5 ns clock (2 GHz), 0.1 ns register overhead',
 'unit': 'every class 1 cycle (ld, st: 0): the instruction-count model, for the sanity check against model 1',
}
def table_text(t):
    L = ['# sim64 latency table "%s": one line a class: name latency interval (cycles).  The line `name@8` or `name@16` is for that strip in bytes only; a line without @ is the default (the strip of 32; 64 uses it too).' % t,
         '# %s.' % HDR[t], '# Depth is measured (tools/gates/depth-synth.sh); every latency here follows from assumed delays (tools/gates/lat-table.py).  The interval is 1: every class is pipelined.',
         '# ld, st: the cycles of load alignment and store merge on top of --vmemlat (the cache)']
    for c in CLASSES:
        n = c[0]; d = tables[t][32][n]
        L.append('%s %d 1' % (n, d))
        for s in (16, 8):
            if tables[t][s][n] != d: L.append('%s@%d %d 1' % (n, s, tables[t][s][n]))
    return '\n'.join(L) + '\n'
os.makedirs(os.path.join(OUT, 'tables'), exist_ok=True)
for t in tables:
    txt = table_text(t)
    if t in ('fpga', 'asic'):
        open(os.path.join(OUT, 'latency-%s.txt' % t), 'w').write(txt)
        open(os.path.join(R, 'sim64', 'latency-%s.txt' % t), 'w').write(txt)
    else: open(os.path.join(OUT, 'tables', t + '.txt'), 'w').write(txt)
def crow(t, s): return '{' + ', '.join('[VC_%s]={%d,1}' % (c[0].upper(), tables[t][s][c[0]]) for c in CLASSES) + '}'
with open(os.path.join(R, 'sim64', 'vlatency-defaults.h'), 'w') as f:
    f.write('/* Generated by tools/gates/lat-table.py from the logic depth of docs/encoding-work/vec-latency.md: DO NOT EDIT.  The built-in latency tables of the second cycle model of sim64: for each strip of 8, 16 and 32 bytes,\n'
            '   each class (enum VC_* of pdp64exec.h) its latency and its interval in cycles.  ASSUMED values (depth is measured; the delay per level and the clock are assumptions): the text of each table is sim64/latency-fpga.txt and latency-asic.txt. */\n')
    for fam in ('fpga', 'asic'):
        f.write('static const int vlat_%s[3][VC_N][2] = {\n' % fam)
        for s in (8, 16, 32): f.write('\t%s,\n' % crow(fam, s))
        f.write('};\n')
# ---- depth.md
md = []
fm = lambda v: '-' if v is None else ('%.1f' % v[1]).rstrip('0').rstrip('.')
mods = []
for (snb, m, fl) in rows:
    if m not in mods: mods.append(m)
md.append('### Depth of every block (longest path in levels: NAND2/NOT gates; ECP5 LUT4 levels, carry hops 0.1 and PFUMX/L6MUX21 0.5; Xilinx LUT6 levels, carry hops 0.1 and MUXF 0.5), strips of 32 / 16 / 8 bytes where the block is parameterised\n')
md.append('| block | nand 32 / 16 / 8 | ltp nand 32 | ecp5 32 / 16 / 8 | ltp ecp5 32 | xc7 32 / 16 / 8 | ltp xc7 32 | multiplier primitives on the critical path (ecp5, xc7, at 32) | cells on the ecp5 path (32) |')
md.append('|---|---|---:|---|---:|---|---:|---|---:|')
for m in mods:
    def trip(fl):
        v = [get(m, fl, s) for s in (32, 16, 8)]
        if m.startswith('w_') or m.startswith('lat_'): return ' / '.join(fm(x) for x in v)
        return fm(v[0])
    g32 = lambda fl: get(m, fl, 32) or get(m, fl, 8)
    ltp = lambda fl: str(g32(fl)[0]) if g32(fl) else '-'
    dsp = ', '.join(str(g32(fl)[2]) if g32(fl) else '-' for fl in ('ecp5', 'xc7'))
    md.append('| %s | %s | %s | %s | %s | %s | %s | %s | %s |' % (m, trip('nand'), ltp('nand'), trip('ecp5'), ltp('ecp5'), trip('xc7'), ltp('xc7'), dsp, g32('ecp5')[3] if g32('ecp5') else '-'))
md.append('\nlevels of the xc7 flow for `w_vcmp_mw` are an artefact of the study\'s own form of the compare (a dynamic shift: it maps to 90,000 LUT6, vec-strip.md section 3); `w_vcmp2` is the fixed-comparator form that the class uses.')
md.append('\n### The classes: the blocks, the depth at strip 32 (and 16, 8 where it differs), and the latency in cycles under the assumed delays\n')
md.append('| class | what | blocks (mode) | NAND2 levels 32 / 16 / 8 | LUT4 levels 32 / 16 / 8 | DSP on path (ecp5) | LUT6 levels 32 | fpga-lo | **fpga** | fpga-hi | asic-lo | **asic** | asic-hi | fpga / asic at strip 16 | at strip 8 |')
md.append('|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---|')
for c in CLASSES:
    n = c[0]
    def trip2(fl):
        v = [depth(c, fl, s) for s in (32, 16, 8)]
        if c[1] == 'zero': return '0'
        if len({x for x in v}) == 1: return fm((0, v[0][0])) if False else ('%g' % round(v[0][0], 1))
        return ' / '.join('%g' % round(x[0], 1) for x in v)
    d32e = depth(c, 'ecp5', 32); d32x = depth(c, 'xc7', 32)
    md.append('| %s | %s | %s | %s | %s | %d | %s | %d | **%d** | %d | %d | **%d** | %d | %d / %d | %d / %d |' % (n, c[3], ', '.join('%s (%s)' % (m, mo) for m, mo in c[2]) or '-', trip2('nand'), trip2('ecp5'), d32e[1] if d32e else 0,
        ('%g' % round(d32x[0], 1)) if d32x else '-', tables['fpga-lo'][32][n], tables['fpga'][32][n], tables['fpga-hi'][32][n], tables['asic-lo'][32][n], tables['asic'][32][n], tables['asic-hi'][32][n],
        tables['fpga'][16][n], tables['asic'][16][n], tables['fpga'][8][n], tables['asic'][8][n]))
md.append('\nParameters (ASSUMED): ' + '; '.join('%s: %s levels, %.3g ns a level, clock %g ns, %.3g ns register overhead a stage, %d cycles a multiplier primitive' % (t, p[0], p[1], p[2], p[3], p[4]) for t, p in PARAMS.items()) + '.')
md.append('\n### The scalar core\'s long operations (not used by sim64: both models count 1 cycle a scalar instruction): depth and latency in the same conversion, mid assumptions\n')
md.append('| block | what | NAND2 levels | LUT4 levels | DSP on path (ecp5) | LUT6 levels | fpga cycles | asic cycles |')
md.append('|---|---|---:|---:|---:|---:|---:|---:|')
for lab, m, what in SCALAR:
    n = get(m, 'nand', 32); e = get(m, 'ecp5', 32); x = get(m, 'xc7', 32)
    if not (n and e and x): continue
    md.append('| %s | %s | %g | %g | %d | %g | %d | %d |' % (lab, what, n[1], e[1], e[2], x[1], cycles(e[1], e[2], PARAMS['fpga']), cycles(n[1], n[2], PARAMS['asic'])))
open(os.path.join(OUT, 'depth.md'), 'w').write('\n'.join(md) + '\n')
print('\n'.join(md))
