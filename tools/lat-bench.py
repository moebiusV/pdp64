#!/usr/bin/env python3
"""lat-bench.py [OUTDIR] -- the two cycle models of docs/sim64.md on the benchmark kernels (docs/encoding-work/vec-latency.md).

Builds the kernels exactly as tools/strip-bench.py does (it is run up to its `# the runs` line: the `lv` build of llvm/bench, 46 kernels, and the hand-written kernels that give the same result, the
driver's set-up subtracted) and runs sim64 -V --vmix over a grid of the model parameters; one run prints model 1 and model 2 both.  Grid (strip, port, latency table, strips in flight, memory latency):
  main:        strip 8 16 32, port 8 16 32, table fpga asic, vpipe 1 2 4, vmemlat 2 4 8                       (162 runs a kernel), and strip 64 at port 16
  tables:      the sensitivity tables OUTDIR/tables/{fpga-lo,fpga-hi,asic-lo,asic-hi,unit}.txt at strip 8 16 32, port 16, vpipe 1, vmemlat 4
  classes:     each class of the model set to latency 1 (ld and st: 0) in the fpga and the asic table, strip 16 and 32, port 16, vpipe 1, vmemlat 4
Writes OUTDIR/bench.tsv (every run, driver subtracted), OUTDIR/bench.md (the tables of the document).  Needs build/sim64 (tools/build-sim64.sh) and the LLVM tools of ../llvm-build; OUTDIR/tables from lat-table.py.
Also checks that the results (exit status and a hash of the data) do not depend on the model: the runs with -V and without agree for every program.
"""
import os, re, sys, math, subprocess, shutil
from concurrent.futures import ThreadPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'gates', 'latency-results')
sys.argv = [sys.argv[0], OUT]
src = open(os.path.join(HERE, 'strip-bench.py')).read()
g = {'__file__': os.path.join(HERE, 'strip-bench.py'), '__name__': 'stripbench'}
exec(compile(src[:src.index('# the runs')], 'strip-bench.py', 'exec'), g)
progs = g['progs']; sim64 = g['sim64']; tmp = g['tmp']; dropped_note = None
TAB = os.path.join(OUT, 'tables')
CLASSES = ['alu', 'cmp', 'bsl', 'shift', 'narrow', 'mul8', 'mul16', 'mulh16', 'mul32', 'mul64', 'dot', 'dacc', 'sad', 'acc', 'mmacc', 'fir', 'tbl', 'lseg', 'sseg', 'cvt', 'fma', 'fma64', 'ld', 'st', 'misc']
# class sensitivity tables
cdir = os.path.join(tmp, 'cls'); os.makedirs(cdir)
for fam in ('fpga', 'asic'):
    for c in CLASSES:
        open(os.path.join(cdir, '%s-%s.txt' % (fam, c)), 'w').write('%s 0 1\n%s@8 0 1\n%s@16 0 1\n%s@32 0 1\n' % ((c,) * 4) if c in ('ld', 'st') else '%s 1 1\n%s@8 1 1\n%s@16 1 1\n%s@32 1 1\n' % ((c,) * 4))
# a file does not carry the family's other classes, so the class tables need the family table: write them as the family's full file plus the override
def famfile(fam): return os.path.join(OUT, 'latency-%s.txt' % fam)
for fam in ('fpga', 'asic'):
    for c in CLASSES:
        f = os.path.join(cdir, '%s-%s.txt' % (fam, c))
        ov = open(f).read(); open(f, 'w').write(open(famfile(fam)).read() + ov)		# later lines win
CONFIGS = []		# (strip, port, lat, vpipe, vmemlat, kind)
for s in (8, 16, 32):
    for p in (8, 16, 32):
        for lat in ('fpga', 'asic'):
            for vp in (1, 2, 4):
                for vm in (2, 4, 8): CONFIGS.append((s, p, lat, vp, vm, 'main'))
for lat in ('fpga', 'asic'): CONFIGS.append((64, 16, lat, 1, 4, 'main'))
for s in (8, 16, 32):
    for t in ('fpga-lo', 'fpga-hi', 'asic-lo', 'asic-hi', 'unit'): CONFIGS.append((s, 16, os.path.join(TAB, t + '.txt'), 1, 4, 'table'))
for s in (32, 16):
    for fam in ('fpga', 'asic'):
        for c in CLASSES: CONFIGS.append((s, 16, os.path.join(cdir, '%s-%s.txt' % (fam, c)), 1, 4, 'class'))
CONFIGS.append((32, 16, os.path.join(TAB, 'unit.txt'), 16, 1, 'unit16'))
pat1 = re.compile(r'vec blocks (\d+) strips (\d+) ops (\d+) elems (\d+)')
pat2 = re.compile(r'vec model strip (\d+) port (\d+) commit (\d+): scalar (\d+) vector (\d+) \(compute (\d+) memory (\d+) memory-bound strips (\d+)\) total (\d+)')
pat3 = re.compile(r'vec model2 latency (\S+) strip (\d+) port (\d+) commit (\d+) vpipe (\d+) vmemlat (\d+): scalar (\d+) vector (\d+) \(blocks with a hidden accumulator (\d+), with a scalar dependence (\d+)\) total (\d+)')
pat4 = re.compile(r'vec mix (.*)')
def sim(job):
    (name, var, x), cf = job
    s, p, lat, vp, vm, kind = cf
    r = subprocess.run([sim64, '-V', '--vmix', '-S', str(s), '--vport=%d' % p, '--latency=' + lat, '--vpipe=%d' % vp, '--vmemlat=%d' % vm, x], capture_output=True, timeout=600)
    e = r.stderr.decode('utf-8', 'replace'); o = r.stdout.hex()
    m1, m2, m3, m4 = pat1.search(e), pat2.search(e), pat3.search(e), pat4.search(e)
    if not (m1 and m2 and m3 and m4): return job, None
    mix = dict(zip(m4.group(1).split()[0::2], map(int, m4.group(1).split()[1::2])))
    return job, dict(rc=r.returncode, out=o, blocks=int(m1.group(1)), strips=int(m1.group(2)), vops=int(m1.group(3)), s1=int(m2.group(4)), v1=int(m2.group(5)), t1=int(m2.group(9)),
                     comp=int(m2.group(6)), mem=int(m2.group(7)), v2=int(m3.group(8)), t2=int(m3.group(11)), hid=int(m3.group(9)), sdep=int(m3.group(10)), mix=mix)
def plain(prog):
    name, var, x = prog
    r = subprocess.run([sim64, x], capture_output=True, timeout=600)
    return prog, (r.returncode, r.stdout.hex())
jobs = [(pr, cf) for pr in progs for cf in CONFIGS]
res = {}
with ThreadPoolExecutor(max_workers=int(os.environ.get('JOBS', '10'))) as ex:
    for job, r in ex.map(sim, jobs): res[(job[0][0], job[0][1], job[1])] = r
    plainres = {pr[0] + '/' + pr[1]: r for pr, r in ex.map(plain, progs)}
base = {cf: res[('none', 'base', cf)] for cf in CONFIGS}
rows = {}
for (name, var, x) in progs:
    if var == 'base': continue
    d = {}
    for cf in CONFIGS:
        r = res[(name, var, cf)]; b = base[cf]
        if r is None: continue
        mix = {k: r['mix'][k] - b['mix'][k] for k in r['mix']}
        d[cf] = dict(rc=r['rc'], out=r['out'], blocks=r['blocks'] - b['blocks'], strips=r['strips'] - b['strips'], vops=r['vops'] - b['vops'], s1=r['s1'] - b['s1'], v1=r['v1'] - b['v1'],
                     t1=r['t1'] - b['t1'], comp=r['comp'] - b['comp'], mem=r['mem'] - b['mem'], v2=r['v2'] - b['v2'], t2=r['t2'] - b['t2'], hid=r['hid'] - b['hid'], sdep=r['sdep'] - b['sdep'], mix=mix)
    rows[(name, var)] = d
# the same hand-kernel filter as strip-bench: the program must give the lv build's result
C0 = (32, 16, 'fpga', 1, 4, 'main')
dropped = []
for (name, var) in list(rows):
    if var == 'hand':
        lv = rows.get((name.replace('(fir)', ''), 'lv'))
        if not lv or (lv[C0]['rc'], lv[C0]['out']) != (rows[(name, var)][C0]['rc'], rows[(name, var)][C0]['out']): dropped.append(name); del rows[(name, var)]
with open(os.path.join(OUT, 'bench.tsv'), 'w') as f:
    f.write('kernel\tvariant\tstrip\tport\ttable\tvpipe\tvmemlat\tkind\trc\tblocks\tstrips\tvops\tscalar\tmodel1_vector\tmodel1_total\tmodel2_vector\tmodel2_total\thidden_blocks\tsdep_blocks\tmix\n')
    for (name, var), d in rows.items():
        for cf, r in d.items():
            s, p, lat, vp, vm, kind = cf
            f.write('%s\t%s\t%d\t%d\t%s\t%d\t%d\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\n' % (name, var, s, p, os.path.basename(lat), vp, vm, kind, r['rc'], r['blocks'], r['strips'], r['vops'], r['s1'], r['v1'], r['t1'], r['v2'], r['t2'], r['hid'], r['sdep'],
                    ' '.join('%s=%d' % (k, v) for k, v in r['mix'].items() if v)))
def gm(v): return math.exp(sum(math.log(x) for x in v) / len(v)) if v else float('nan')
blk = [(k, d) for k, d in rows.items() if d[C0]['blocks'] > 0]
noblk = [k for k, d in rows.items() if d[C0]['blocks'] == 0]
md = []
bad = [(n, v) for (n, v), d in rows.items() if len({(r['rc'], r['out']) for r in d.values()}) != 1]
bad2 = [(n, v) for (n, v), d in rows.items() if (d[C0]['rc'], d[C0]['out']) != plainres[n + '/' + v]]
md.append('%d programs ran (%d `lv`, %d hand-written: %s; dropped as strip-bench does: %s); %d have a vec block; without: %s.' % (len(rows), sum(1 for k in rows if k[1] == 'lv'), sum(1 for k in rows if k[1] == 'hand'),
          ' '.join(k[0] for k in rows if k[1] == 'hand') or 'none', ' '.join(dropped) or 'none', len(blk), ' '.join(k[0] for k in noblk)))
md.append('%d runs a program over %d configurations. Results (exit status and a hash of every global array) identical over all configurations: %d of %d programs; identical to a run without -V (no model): %d of %d.' % (len(CONFIGS), len(CONFIGS), len(rows) - len(bad), len(rows), len(rows) - len(bad2), len(rows)))
def cfg(s, p=16, lat='fpga', vp=1, vm=4): return (s, p, lat, vp, vm, 'main')
def tot2(d, c): return d[c]['t2']
md.append('\n### Per kernel, strip 32, port 16, commit 1: cycles in model 1 and model 2 (fpga and asic table, vpipe 1, vmemlat 4)\n')
md.append('| kernel | build | strips | vec instrs | scalar | model 1 total | model 2 fpga | ratio | model 2 asic | ratio | fpga, vpipe 2 | fpga, vpipe 4 | hidden-acc blocks | scalar-dep blocks | mix (instrs at strip 32, classes with 5% or more of the block\'s instructions) |')
md.append('|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|')
ratios = []
for (name, var), d in sorted(blk, key=lambda t: (t[0][1], t[0][0])):
    a = d[cfg(32)]; b = d[cfg(32, lat='asic')]; c2 = d[cfg(32, vp=2)]; c4 = d[cfg(32, vp=4)]
    mx = a['mix']; tv = sum(mx.values()) or 1
    mixs = ' '.join('%s %d' % (k, v) for k, v in sorted(mx.items(), key=lambda kv: -kv[1]) if v / tv >= 0.05)
    ratios.append((name, var, a['t2'] / a['t1'], b['t2'] / b['t1'], a, b))
    md.append('| %s | %s | %d | %d | %d | %d | %d | %.3f | %d | %.3f | %d | %d | %d | %d | %s |' % (name, var, a['strips'], a['vops'], a['s1'], a['t1'], a['t2'], a['t2'] / a['t1'], b['t2'], b['t2'] / b['t1'], c2['t2'], c4['t2'], a['hid'], a['sdep'], mixs))
md.append('\n### Geometric mean of model 2 / model 1 cycles over the %d kernels with a block, strip 32, port 16 (worst case in brackets)\n' % len(blk))
md.append('| table | vmemlat | vpipe 1 | vpipe 2 | vpipe 4 |\n|---|---:|---|---|---|')
for lat in ('fpga', 'asic'):
    for vm in (2, 4, 8):
        row = []
        for vp in (1, 2, 4):
            v = [(d[cfg(32, 16, lat, vp, vm)]['t2'] / d[cfg(32, 16, lat, vp, vm)]['t1'], k[0]) for k, d in blk]
            row.append('%.3f (%s %.3f; best %.3f)' % (gm([x[0] for x in v]), max(v)[1], max(v)[0], min(v)[0]))
        md.append('| %s | %d | %s |' % (lat, vm, ' | '.join(row)))
def sl(model, s, p, lat, vp, vm, sel=None):
    v = []
    for k, d in (sel or blk):
        a = d[(s, p, lat, vp, vm, 'main')]; b = d[(32, p, lat, vp, vm, 'main')]
        v.append((a['t1'] / b['t1'] if model == 1 else a['t2'] / b['t2'], k[0]))
    return v
md.append('\n### Slowdown of a narrower strip against strip 32 (cycles(strip) / cycles(32), same port and parameters): geometric mean (worst kernel)\n')
md.append('| model | table | vpipe | vmemlat | port | strip 16 | strip 8 |\n|---|---|---:|---:|---:|---|---|')
for p in (8, 16, 32):
    v1 = [sl(1, s, p, 'fpga', 1, 4) for s in (16, 8)]
    md.append('| 1 | - | - | - | %d | %s |' % (p, ' | '.join('%.3f (%s %.3f)' % (gm([x[0] for x in v]), max(v)[1], max(v)[0]) for v in v1)))
    for lat in ('fpga', 'asic'):
        for vp in (1, 4):
            for vm in ((4,) if p != 16 or vp == 4 else (2, 4, 8)):
                v2 = [sl(2, s, p, lat, vp, vm) for s in (16, 8)]
                md.append('| 2 | %s | %d | %d | %d | %s |' % (lat, vp, vm, p, ' | '.join('%.3f (%s %.3f)' % (gm([x[0] for x in v]), max(v)[1], max(v)[0]) for v in v2)))
# memory / compute split by the vector cycles of the model
md.append('\n### Memory-bound or compute-bound (the vector cycles when the strip halves from 32 to 16: unchanged = ratio 1.2 or less, doubles = 1.9 or more), kernels with a block that are not scalar-dominated at strip 32 in model 1\n')
def vv(d, s, p, lat, vp, vm, m): return d[(s, p, lat, vp, vm, 'main')]['v1' if m == 1 else 'v2']
sd = [(k, d) for k, d in blk if d[cfg(32)]['s1'] / d[cfg(32)]['t1'] <= 0.5]
md.append('%d kernels. | model | port | unchanged / between / doubles |\n|---|---:|---|' % len(sd))
def split(m, p, lat='fpga', vp=1, vm=4):
    cnt = {'unchanged': 0, 'between': 0, 'doubles': 0}
    for k, d in sd:
        r = vv(d, 16, p, lat, vp, vm, m) / max(1, vv(d, 32, p, lat, vp, vm, m))
        cnt['unchanged' if r <= 1.2 else 'doubles' if r >= 1.9 else 'between'] += 1
    return '%d / %d / %d' % (cnt['unchanged'], cnt['between'], cnt['doubles'])
for p in (8, 16, 32):
    md.append('| model 1 | %d | %s |' % (p, split(1, p)))
    for lat in ('fpga', 'asic'):
        for vp in (1, 4): md.append('| model 2, %s, vpipe %d | %d | %s |' % (lat, vp, p, split(2, p, lat, vp)))
# table sensitivity
md.append('\n### Sensitivity to the latency table: geometric mean of model 2 / model 1 over the kernels with a block, port 16, vpipe 1, vmemlat 4\n')
md.append('| table | strip 8 | strip 16 | strip 32 |\n|---|---|---|---|')
for t in ('unit', 'fpga-lo', 'fpga', 'fpga-hi', 'asic-lo', 'asic', 'asic-hi'):
    row = []
    for s in (8, 16, 32):
        key = (s, 16, 'fpga' if t == 'fpga' else 'asic' if t == 'asic' else os.path.join(TAB, t + '.txt'), 1, 4, 'main' if t in ('fpga', 'asic') else 'table')
        row.append('%.3f' % gm([d[key]['t2'] / d[key]['t1'] for k, d in blk]))
    md.append('| %s | %s |' % (t, ' | '.join(row)))
ku = (32, 16, os.path.join(TAB, 'unit.txt'), 16, 1, 'unit16')
md.append('\nSanity check (model 2 with the unit table, 16 strips in flight, memory latency 1, strip 32, port 16) against model 1: geometric mean of model 2 / model 1 = %.3f, range %.3f to %.3f over the %d kernels.' % (
    gm([d[ku]['t2'] / d[ku]['t1'] for k, d in blk]), min(d[ku]['t2'] / d[ku]['t1'] for k, d in blk), max(d[ku]['t2'] / d[ku]['t1'] for k, d in blk), len(blk)))
# class sensitivity
md.append('\n### Class sensitivity: one class set to latency 1 (ld, st: 0), all else as the table; geometric mean of cycles / cycles with the table, and the largest single-kernel gain; kernels that use the class; port 16, vpipe 1, vmemlat 4\n')
md.append('| class | instrs run (all kernels, strip 32) | kernels using it | fpga strip 32: geomean (best kernel) | fpga strip 16 | asic strip 32 | asic strip 16 |\n|---|---:|---:|---|---|---|---|')
tabc = {}
for c in CLASSES:
    use = [k for k, d in blk if d[cfg(32)]['mix'].get(c, 0) > 0]
    tot = sum(d[cfg(32)]['mix'].get(c, 0) for k, d in blk)
    cells = []
    for fam in ('fpga', 'asic'):
        for s in (32, 16):
            f = os.path.join(cdir, '%s-%s.txt' % (fam, c))
            v = [(d[(s, 16, f, 1, 4, 'class')]['t2'] / d[cfg(s, 16, fam)]['t2'], k[0]) for k, d in blk]
            cells.append('%.4f (%s %.3f)' % (gm([x[0] for x in v]), min(v)[1], min(v)[0]) if use else '1.0000 (-)')
            tabc[(c, fam, s)] = gm([x[0] for x in v])
    md.append('| %s | %d | %d | %s |' % (c, tot, len(use), ' | '.join(cells)))
open(os.path.join(OUT, 'bench.md'), 'w').write('\n'.join(md) + '\n')
print('\n'.join(md))
shutil.rmtree(tmp, ignore_errors=True)
