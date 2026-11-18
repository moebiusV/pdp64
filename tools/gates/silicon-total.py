#!/usr/bin/env python3
"""silicon-total.py BLOCKS.tsv CORE.tsv -- the tables of docs/encoding-work/vec-silicon.md from the synthesised blocks.
BLOCKS.tsv: module, NAND2 equivalents of logic, flip-flops, latches (run-silicon.sh: gates.sh for blocks.v and gates2.sh for vec2.v, vec3.v, fp2.v, mem2.v).
CORE.tsv: the three-column output of gates.sh over core.v, aes.v, decode.v (the core of core-total.py).
Counting unit: a flip-flop is 6 NAND2 equivalents (as total.py and core-total.py), a latch 4; an inverter counts 0.5 in the logic counts (gates.sh).  Prints markdown and a SUMMARY line block."""
import sys, subprocess, os
here = os.path.dirname(os.path.abspath(__file__))
B = {}
for ln in open(sys.argv[1]):
    p = ln.split()
    if len(p) < 3: continue
    B[p[0]] = (int(p[1]), int(p[2]), int(p[3]) if len(p) > 3 else 0)
def eq(m): n, f, l = B[m]; return n + 6 * f + 4 * l
def k(x): return '%.1f k' % (x / 1000.0) if abs(x) >= 1000 else '%d' % round(x)
def kk(x): return '%d' % round(x)

# --- the survey's estimates (vec-survey.md section 5.1, 5.2), low and high
rows = []		# name, measured, survey lo, survey hi, how measured (module names), note
def row(name, meas, lo, hi, how, standalone=None):
    rows.append((name, meas, lo, hi, how, standalone))
row('vavg, vavgu (all lane widths): added to the lane ALU', eq('lanealu_mw') - eq('lanealu_mw_noavg'), 1000, 2000, 'lanealu_mw - lanealu_mw_noavg', 'vavg_mw: %d' % eq('vavg_mw'))
row('vsts rounding shift + saturating narrow (w to b and l to w), added to the plain saturating narrow', eq('narrow_both') - eq('narrow_both_plain'), 2000, 4000, 'narrow_both - narrow_both_plain', 'narrow_both: %d' % eq('narrow_both'))
row('vmulh, vmulhu, vmulhr (.w) on the shared 16 x 16 array', eq('ms16_hi') - eq('vmul16_full'), 1000, 2000, 'ms16_hi - vmul16_full', 'vmulh16_sep: %d' % eq('vmulh16_sep'))
row('vmla vector by vector on the shared array', eq('ms16_hi_mla') - eq('ms16_hi'), 0, 1000, 'ms16_hi_mla - ms16_hi (the difference is inside the noise of the mapper, a few hundred)', 'vmla16_sep: %d' % eq('vmla16_sep'))
row('vdot.w on the shared array', eq('ms16_all') - eq('ms16_hi_mla'), 3000, 4000, 'ms16_all - ms16_hi_mla', 'vdotw_sep: %d' % eq('vdotw_sep'))
row('vdacc: the reduction tree over the 8 lanes of a vdot', eq('ms8x8') - eq('ms8x8_notree'), 1500, 1500, 'ms8x8 - ms8x8_notree (the tree alone, dacc_tree: %d)' % eq('dacc_tree'), 'vdaccb_sep: %d; vdaccw_sep: %d' % (eq('vdaccb_sep'), eq('vdaccw_sep')))
row('vsarr, vshrr (.w .l): the rounding added to the shifter', eq('shiftround_wl') - eq('shiftlane_wl'), 2000, 3000, 'shiftround_wl - shiftlane_wl', 'shiftround_wl: %d' % eq('shiftround_wl'))
row('vsad.bu: the tree if vacc.bu does not exist (the abdu comes from the lane ALU)', eq('sum32_bu'), 500, 500, 'sum32_bu', 'vsad_bu: %d' % eq('vsad_bu'))
row('vtbl.b (32 lanes, groups of 16)', eq('vtbl_g16'), 10000, 12000, 'vtbl_g16', 'vtbl_one: %d' % eq('vtbl_one'))
row('vceq, vcgt, vcgtu (4 widths) and vbsl', eq('vcmp_mw') + eq('vbsl'), 2000, 4000, 'vcmp_mw + vbsl', None)
row('vcvt.f.l and vcvt.l.f, 8 lanes each', eq('cvt_both8'), 3000, 5000, 'cvt_both8 (cvt_i2f %d, cvt_f2i %d a lane)' % (eq('cvt_i2f'), eq('cvt_f2i')), None)
row('the reductions: vacc (b bu w wu l lu q) and vmaxacc/vminacc (the same)', eq('vacc_naive') + eq('vmmacc'), 6000, 6000, 'vacc_naive + vmmacc (vacc_shared64: %d, per type b %d w %d l %d q %d; the survey counted one type, reduce16 2 x %d)' % (eq('vacc_shared64'), eq('vacc_b'), eq('vacc_w'), eq('vacc_l'), eq('vacc_q'), 2979), None)
row('the lane ALU, all widths (add, sub, saturating, min, max, abs, abd; avg excluded)', eq('lanealu_mw_noavg'), 19000, 22000, 'lanealu_mw_noavg (the survey: lane ALU 7,000 + saturation/min/max 12,000 to 15,000)', None)
row('the lane shifts (left, logical right, arithmetic right), all widths', eq('shiftlane_mw'), 3000, 3000, 'shiftlane_mw', None)
vfir = B['vfir_added'][0] + 6 * (B['vfir_added'][1] + 112)
row('vfir.w on the shared multipliers (window select, tap select, 16 x 32-bit accumulators, 112 halo flops)', vfir, 3000, 6000, 'vfir_added + 112 halo flops x 6', None)
row('segment loads and stores (2 to 4 fields; bytes, halfwords, words)', eq('segload') + eq('segstore'), 2000, 5000, 'segload + segstore', 'segload %d, segstore %d' % (eq('segload'), eq('segstore')))
row('the 256-bit load alignment with widening, and the store merge', eq('vmem_ld') + eq('vmem_st'), 10000, 10000, 'vmem_ld + vmem_st (without widening: vmem_ld_plain %d)' % eq('vmem_ld_plain'), None)
row('vector register file, 16 x 256 bits, 3 read, 1 write, flip-flops', eq('vregs16_r3'), 56800, 56800, 'vregs16_r3 (survey: 8 registers 28,400 x 2)', 'latches: %d; 2 read ports: %d; 4: %d' % (eq('vregs16_latch'), eq('vregs16_r2'), eq('vregs16_r4')))
row('vdot.b, .bu, .bsu: 8 lanes of 4 byte products (signed bytes: vdotb_s %d)' % eq('vdotb_s'), eq('vdotb_sep'), 37000, 37000, 'vdotb_sep (9 x 9 multipliers with the sign flags)', 'vdotb_s (dot4 x 8): %d' % eq('vdotb_s'))
row('the 16 x 16 integer multipliers (vmul with the full product)', eq('vmul16_full'), 48000, 48000, 'vmul16_full (low half only, vmul16_lo: %d)' % eq('vmul16_lo'), None)
row('8 floating-point multiply-add lanes (single, fused, 74-bit frame)', eq('fma32x8'), 79000, 79000, 'fma32x8 (one fma32: %d; two flat: %d)' % (eq('fma32'), eq('fma32x2')), None)
gat = eq('gather_full')
row('gather (vldx), one lane a cycle: address, counter, merge', gat, 4000, 6000, 'gather_full (a 32-lane parallel address generator alone: %d)' % eq('gather_agen32'), None)
tile_fma = 64 * eq('fma32'); tile_state = eq('tile_state')
tile = tile_fma + tile_state
row('the tile: 64 fused multiply-adds, 2,048 accumulator flops, row read and write', tile, 665000, 665000, '64 x fma32 + tile_state (hierarchical count: 64 identical copies; the 20,000 of the survey for broadcast and write-back is in tile_state)', None)
seq = eq('gemm_seq')
dma = 20000
sram_lo = int(524288 * 1.5); sram_hi = int(524288 * 2.0)
row('the whole-GEMM unit: the tile + the sequencer (%d) + a DMA engine (20,000, estimated) + 64 KB of SRAM at 6T (1.5 NAND2 eq a bit) to 2.0 with periphery' % seq, tile + seq + dma + sram_lo, 1219000, 1744000, 'tile + gemm_seq + 20,000 + 524,288 bits x 1.5 .. 2.0; high: %s' % kk(tile + seq + dma + sram_hi), None)

import re
BASE = {'lanealu16', 'lanealu16plain', 'mul8s', 'mul16s', 'mul24u', 'add32', 'add48', 'add64', 'shr48', 'norm48', 'dot4', 'reduce16', 'vregs', 'segload8', 'gather1', 'firsum8'}
def file_of(m):
    if m in BASE: return 'blocks.v'
    if m.startswith(('ms', 'vmul16_full', 'vfir_added', 'mul32s')): return 'vec3.v'
    if m.startswith(('fma', 'tile', 'gemm', 'gather', 'cvt')): return 'fp2.v'
    if m.startswith('vmem'): return 'mem2.v'
    return 'vec2.v'
def files(how):
    fs = sorted({file_of(t) for t in re.findall(r'[a-z0-9_]+', how) if t in B})
    return ', '.join(fs)
print('| block | measured (NAND2 eq) | survey (NAND2 eq) | measured / survey (against the middle) | file | module(s) | the separate or standalone form |\n|---|---:|---:|---:|---|---|---|')
for n, m, lo, hi, how, st in rows:
    mid = (lo + hi) / 2.0
    s = kk(lo) if lo == hi else '%d to %d' % (lo, hi)
    r = m / mid if mid else float('nan')
    flag = ' **(>30%)**' if mid and (r > 1.3 or 0 < r < 0.7) else ''
    print('| %s | %s | %s | %.2f%s | %s | %s | %s |' % (n, kk(m), s, r, flag, files(how), how, st or ''))
print()

# --- the sets
M = {}
M['vregs'] = eq('vregs16_r3'); M['vregs_latch'] = eq('vregs16_latch')
M['alu'] = eq('lanealu_mw'); M['alu_noavg'] = eq('lanealu_mw_noavg')
M['shift_r'] = eq('shiftround_mw'); M['shift'] = eq('shiftlane_mw')
M['mulA'] = eq('ms16_all') + eq('vdotb_sep') + eq('dacc_tree')			# monolithic array + separate vdot.b array + the vdacc tree
M['mulB'] = eq('ms8x8')									# the array of 8 x 8 products shared by everything, with the vdacc tree
M['vsad'] = 800										# estimated: 256 two-input selects to feed the abdu into the tree of vacc
M['red'] = eq('vacc_naive') + eq('vmmacc')
M['narrow'] = eq('narrow_both')
M['vfir'] = vfir
M['seg'] = eq('segload') + eq('segstore')
M['vtbl'] = eq('vtbl_g16')
M['ldst'] = eq('vmem_ld') + eq('vmem_st')
M['ctl'] = 4 * eq('add64') + 2000 if 'add64' in B else 4 * 660 + 2000
M['w2'] = eq('vcmp_mw') + eq('vbsl') + eq('cvt_both8')
M['fp'] = eq('fma32x8')
M['gather'] = gat
M['tile'] = tile
M['gemm'] = (tile + seq + dma + sram_lo, tile + seq + dma + sram_hi)
M['mul_plain'] = eq('vmul16_full'); M['dotb_s'] = eq('vdotb_s')
M['narrow_plain'] = eq('narrow_both_plain')

def wave1(mul, regs, alu_noavg=False):
    return regs + M['alu'] + M['shift_r'] + mul + M['vsad'] + M['red'] + M['narrow'] + M['vfir'] + M['seg'] + M['vtbl'] + M['ldst'] + M['ctl']
# the proposal, in the survey's grouping: A (the array as the survey assumed it: monolithic 16 x 16 shared, a separate vdot.b array) and B (one array of 8 x 8 products)
w1A = wave1(M['mulA'], M['vregs']); w1B = wave1(M['mulB'], M['vregs'])
w1B_l = wave1(M['mulB'], M['vregs_latch'])
w2 = M['w2']
as_is = M['vregs'] + M['alu_noavg'] + M['shift'] + M['mul_plain'] + M['dotb_s'] + M['narrow_plain'] + M['red'] + M['vfir'] + M['seg'] + M['ctl'] + M['ldst'] + M['gather']
print('| the proposed vector unit | A: monolithic array + separate vdot.b array | B: one array of 8 x 8 products | B with latch registers |\n|---|---:|---:|---:|')
print('| wave 1, 16 integer lanes | %s | %s | %s |' % (kk(w1A), kk(w1B), kk(w1B_l)))
print('| wave 1 and 2, 16 integer lanes | %s | %s | %s |' % (kk(w1A + w2), kk(w1B + w2), kk(w1B_l + w2)))
print('| wave 1 and 2 with 8 floating-point lanes | %s | %s | %s |' % (kk(w1A + w2 + M['fp']), kk(w1B + w2 + M['fp']), kk(w1B_l + w2 + M['fp'])))
print()
print('| the family as it stands | NAND2 eq |\n|---|---:|')
print('| vector unit, 16 integer lanes (ALU without avg, plain shifts, vmul + vdot.b arrays, plain narrow, reductions, vfir, segments, control, load/store, gather, 16 registers) | %s |' % kk(as_is))
print('| + 8 floating-point lanes | %s |' % kk(as_is + M['fp']))
print('| + the tile (alone) | %s |' % kk(M['tile']))
print('| + the whole-GEMM unit (contains the tile): low to high | %s to %s |' % (kk(M['gemm'][0]), kk(M['gemm'][1])))
print('| total, integer lanes, with the GEMM unit | %s to %s |' % (kk(as_is + M['gemm'][0]), kk(as_is + M['gemm'][1])))
print('| total, floating-point lanes, with the GEMM unit | %s to %s |' % (kk(as_is + M['fp'] + M['gemm'][0]), kk(as_is + M['fp'] + M['gemm'][1])))
print()

# --- the core
core = {}
for ln in open(sys.argv[2]):
    p = ln.split()
    if len(p) >= 3: core[p[0]] = int(p[1]) + 6 * int(p[2])
import tempfile
tmp3 = tempfile.NamedTemporaryFile('w', suffix='.tsv', delete=False)
for ln in open(sys.argv[1]):
    p = ln.split()
    if len(p) >= 3: tmp3.write('%s\t%s\t%s\n' % (p[0], p[1], p[2]))
tmp3.close()
out = subprocess.run([sys.executable, os.path.join(here, 'core-total.py'), sys.argv[2], tmp3.name], capture_output=True, text=True).stdout
os.unlink(tmp3.name)
for ln in out.splitlines():
    if ln.startswith('SCALAR'): _, clo, chi, cmid = ln.split(); clo, chi = int(clo), int(chi)
vlo = w1B_l + w2; vhi = w1A + w2
flo = vlo + M['fp']; fhi = vhi + M['fp']
T = (3.0, 4.0, 5.2)
def tr(e, t): return '%.2f M' % (e * t / 1e6)
sram_bits = 2 * 32 * 1024 * 8
def sram(t):
    return sram_bits * 6 * t
caches = (sram_bits * 6 * 1.063 * 1.15, sram_bits * 6 * 1.063 * 1.25, sram_bits * 6 * 1.063 * 1.35 * 1.125)
cases = [('(a) the scalar core, logic only', clo, chi),
         ('(b) core + the proposed vector unit, 16 integer lanes (waves 1 and 2)', clo + vlo, chi + vhi),
         ('(c) core + the proposed vector unit with 8 floating-point lanes', clo + flo, chi + fhi),
         ('(e) core + the family as it stands, integer lanes, with tile and GEMM unit', clo + as_is + M['gemm'][0], chi + as_is + M['gemm'][1]),
         ('(e) core + the family as it stands, floating-point lanes, with tile and GEMM unit', clo + as_is + M['fp'] + M['gemm'][0], chi + as_is + M['fp'] + M['gemm'][1])]
print('| case | NAND2 eq, low to high | transistors at 3.0 per eq (low end) | at 4.0 per eq (stated unit) | at 5.2 per eq (high end) |\n|---|---:|---:|---:|---:|')
for n, lo, hi in cases:
    print('| %s | %s to %s | %s to %s | %s to %s | %s to %s |' % (n, kk(lo), kk(hi), tr(lo, 3.0), tr(hi, 3.0), tr(lo, 4.0), tr(hi, 4.0), tr(lo, 5.2), tr(hi, 5.2)))
print()
print('| case with 32 KB + 32 KB of caches (3.85 M to 5.08 M transistors, middle 4.18 M) | transistors, low to high | SRAM share (middle) |\n|---|---:|---:|')
for n, lo, hi in cases:
    L = lo * 3.0 + caches[0]; H = hi * 5.2 + caches[2]; Mi = (lo + hi) / 2.0 * 4.0 + caches[1]
    print('| %s | %.2f M to %.2f M (middle %.2f M) | %.0f%% |' % (n, L / 1e6, H / 1e6, Mi / 1e6, 100 * caches[1] / Mi))
print()
print('SUMMARY core_eq %d %d' % (clo, chi))
for nme, v in (('w1A', w1A), ('w1B', w1B), ('w1B_latch', w1B_l), ('w2', w2), ('fp', M['fp']), ('as_is', as_is), ('tile', tile), ('gemm_lo', M['gemm'][0]), ('gemm_hi', M['gemm'][1]), ('vlo', vlo), ('vhi', vhi), ('flo', flo), ('fhi', fhi)):
    print('SUMMARY %s %d' % (nme, v))
print('SUMMARY caches_T %d %d %d' % caches)
