#!/usr/bin/env python3
"""strip-bench.py [OUTDIR] -- the cycle model of docs/sim64.md on the benchmark kernels at several strips and memory ports (docs/encoding-work/vec-strip.md, section 6).

Builds each kernel of llvm/bench (the `lv` variant of llvm/bench/bench.py: clang without passes, opt -O2 -mtriple=pdp64 with LoopVectorize, llc with PDP64VecLoop) with its driver
bench_main.c, and the hand-written kernels of docs/encoding-work/arch-data/vec-forms (k_*.vec.s, k_put8h.vecfir.s) with the same driver; subtracts the set-up of the driver (run with no kernel); and
runs sim64 -V -S STRIP --vport=PORT --vcommit=COMMIT for the strips 8, 16, 32, 64 bytes and ports 8, 16, 32 bytes a cycle (commit 1), and commit 0 and 2 at port 16.
Writes OUTDIR/bench.tsv (every run) and OUTDIR/bench.md (the tables).  Needs build/sim64, as64, ld64, and the LLVM tools of ../llvm-build.
"""
import os, re, sys, subprocess, tempfile, shutil, math
from concurrent.futures import ThreadPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__)); R = os.path.dirname(HERE)
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'gates', 'strip-results')
os.makedirs(OUT, exist_ok=True)
BH = os.path.join(R, 'llvm', 'bench')
src = open(os.path.join(BH, 'bench.py')).read()
g = {'__file__': os.path.join(BH, 'bench.py'), '__name__': 'bench'}
exec(compile(src[:src.index('\ndef main():')], 'bench.py', 'exec'), g)		# the prefix of bench.py: paths, SRCS, CFLAGS, run, ll_of, ll_of_lv
B = g['B']; LLC = g['LLC']; OPT = g['OPT']; VF = g['VF']; SRCS = g['SRCS']; CFLAGS = g['CFLAGS']; run = g['run']; ll_of_lv = g['ll_of_lv']
tmp = tempfile.mkdtemp()
bdir = os.path.join(tmp, 'bin'); os.mkdir(bdir)
for t in ('as64', 'ld64', 'sim64'): shutil.copy(os.path.join(B, t), bdir)
as64, ld64, sim64 = [os.path.join(bdir, t) for t in ('as64', 'ld64', 'sim64')]
open(os.path.join(tmp, 'crt.s'), 'w').write("""	.text
	.globl	_start
_start:	call	main
	trap	#0
	.globl	write
write:	trap	#1
	ret
	.globl	memcpy
memcpy:	movq	r0, r3
	mcpy	r0, r1, r2
	movq	r3, r0
	ret
	.globl	memmove
memmove: movq	r0, r3
	mmov	r0, r1, r2
	movq	r3, r0
	ret
	.globl	memset
memset:	movq	r0, r3
	mset	r0, r1, r2
	movq	r3, r0
	ret
""")
assert run([as64, '-o', os.path.join(tmp, 'crt.o'), os.path.join(tmp, 'crt.s')]).returncode == 0

def llc(ll, out):
    r = run([LLC, '-mtriple=pdp64-unknown-elf', '-O2', ll, '-o', out])
    if r.returncode: raise SystemExit('llc failed: ' + r.stderr[:300])
def asm_link(sfiles, out):
    objs = []
    for s in sfiles:
        o = s[:-2] + '.o'
        r = run([as64, '-o', o, s])
        if r.returncode: return 'as64 %s: %s' % (s, r.stderr.strip()[:200])
        objs.append(o)
    r = run([ld64, '-o', out, os.path.join(tmp, 'crt.o')] + objs)
    return 'ld64: ' + r.stderr.strip()[:200] if r.returncode else None

# the kernels of the sources
kernels = []
for s in SRCS:
    for m in re.finditer(r'^[a-z][a-z0-9_ ]*[ \*](k_[a-z0-9_]+)\(', open(s).read(), flags=re.M):
        kernels.append((m.group(1), s))
kll = {}
for s in SRCS:
    o = os.path.join(tmp, os.path.basename(s)[:-2] + '.lv.ll')
    ll_of_lv(s, o); kll[s] = o
ksn = {}
for s in SRCS:
    ksn[s] = os.path.join(tmp, os.path.basename(s)[:-2] + '.lv.s'); llc(kll[s], ksn[s])
# the driver with a hash of every global array added (FNV-1a over the bytes, written to standard output): the exit status of bench_main.c is a few elements and 7 bits
dsrc = open(os.path.join(BH, 'bench_main.c')).read()
HASH = '''    { uint64_t h = 1469598103934665603ULL;
      const void *a[] = { g_fa, g_fb, g_fc, g_fd, g_da, g_db, g_dc, g_ba, g_bb, g_bc, g_ha, g_hb, g_hc, g_ia, g_ib, g_hist };
      const unsigned long n[] = { sizeof g_fa, sizeof g_fb, sizeof g_fc, sizeof g_fd, sizeof g_da, sizeof g_db, sizeof g_dc, sizeof g_ba, sizeof g_bb, sizeof g_bc, sizeof g_ha, sizeof g_hb, sizeof g_hc, sizeof g_ia, sizeof g_ib, sizeof g_hist };
      for (int k = 0; k < 16; k++) for (unsigned long i = 0; i < n[k]; i++) { h ^= ((const uint8_t *)a[k])[i]; h *= 1099511628211ULL; }
      h ^= (uint64_t)(unsigned)r; h *= 1099511628211ULL;
      write(1, &h, 8); }
'''
assert '    return (r + (int)g_fc[7]' in dsrc
dsrc = dsrc.replace('int main(void)', 'long write(int, const void *, unsigned long);\nint main(void)', 1).replace('    return (r + (int)g_fc[7]', HASH + '    return (r + (int)g_fc[7]', 1)
open(os.path.join(tmp, 'bench_main.c'), 'w').write(dsrc)
def driver(k):
    mll = os.path.join(tmp, 'main.%s.ll' % k)
    r = run(['clang'] + CFLAGS[:-2] + ['-S', '-emit-llvm', '-DK_' + k, '-o', mll + '.0', os.path.join(tmp, 'bench_main.c')])
    txt = open(mll + '.0').read()
    txt = re.sub(r'^target (datalayout|triple).*\n', '', txt, flags=re.M)
    txt = re.sub(r'"(target-cpu|target-features|tune-cpu)"="[^"]*"', '', txt)
    open(mll, 'w').write(txt)
    msn = os.path.join(tmp, 'main.%s.s' % k); llc(mll, msn)
    return msn
progs = []		# (name, variant, exe)
msn = driver('none'); e = asm_link([ksn[SRCS[0]], msn], os.path.join(tmp, 'none.x'))
if e: raise SystemExit(e)
progs.append(('none', 'base', os.path.join(tmp, 'none.x')))
for k, s in kernels:
    msn = driver(k); x = os.path.join(tmp, k + '.lv.x')
    e = asm_link([ksn[s], msn], x)
    if e: print('skip', k, e); continue
    progs.append((k, 'lv', x))
hand_skipped = []
HAND = [('k_prep8', 'k_prep8.vec.s'), ('k_put8h', 'k_put8h.vec.s'), ('k_put8h', 'k_put8h.vecfir.s'), ('k_dctop_sum', 'k_dctop_sum.vec.s'), ('k_dctop_fill', 'k_dctop_fill.vec.s'),
        ('k_fmac', 'k_fmac.vec.s'), ('k_sad', 'k_sad.vec.s'), ('k_ssm', 'k_ssm.vec.s')]
for k, f in HAND:
    d = os.path.join(tmp, 'hand_' + f); os.makedirs(d, exist_ok=True)
    hs = os.path.join(d, 'k.s'); open(hs, 'w').write('\t.text\n\t.globl\t%s\n' % k + open(os.path.join(VF, f)).read())	# the listings have no .globl
    x = os.path.join(d, 'k.x')
    e = asm_link([hs, driver(k)], x)
    if e: print('skip hand', f, e); hand_skipped.append(f); continue
    progs.append((k + ('(fir)' if 'vecfir' in f else ''), 'hand', x))

# the runs
CONFIGS = [(s, p, 1) for s in (8, 16, 32, 64) for p in (8, 16, 32)] + [(s, 16, c) for s in (8, 16, 32, 64) for c in (0, 2)]
pat = re.compile(r'vec blocks (\d+) strips (\d+) ops (\d+) elems (\d+)')
pat2 = re.compile(r'vec model strip (\d+) port (\d+) commit (\d+): scalar (\d+) vector (\d+) \(compute (\d+) memory (\d+) memory-bound strips (\d+)\) total (\d+)')
def sim(job):
    (name, var, x), (s, p, c) = job
    r = subprocess.run([sim64, '-V', '-S', str(s), '--vport=%d' % p, '--vcommit=%d' % c, x], capture_output=True, timeout=300)
    r.stderr = r.stderr.decode('utf-8', 'replace'); r.stdout = r.stdout.hex()
    m = pat.search(r.stderr); m2 = pat2.search(r.stderr)
    if not m or not m2: return job, None
    return job, dict(rc=r.returncode, blocks=int(m.group(1)), strips=int(m.group(2)), vops=int(m.group(3)), elems=int(m.group(4)), scalar=int(m2.group(4)), vector=int(m2.group(5)),
                     comp=int(m2.group(6)), mem=int(m2.group(7)), mstrips=int(m2.group(8)), total=int(m2.group(9)), out=r.stdout)
jobs = [(pr, cf) for pr in progs for cf in CONFIGS]
res = {}
with ThreadPoolExecutor(max_workers=int(os.environ.get('JOBS', '10'))) as ex:
    for job, r in ex.map(sim, jobs): res[(job[0][0], job[0][1], job[1])] = r
base = {cf: res[('none', 'base', cf)] for cf in CONFIGS}
rows = {}	# (name, var) -> {cfg: dict}
for (name, var, x) in progs:
    if var == 'base': continue
    d = {}
    for cf in CONFIGS:
        r = res[(name, var, cf)]; b = base[cf]
        if r is None: continue
        d[cf] = dict(rc=r['rc'], out=r['out'], blocks=r['blocks'] - b['blocks'], strips=r['strips'] - b['strips'], vops=r['vops'] - b['vops'], scalar=r['scalar'] - b['scalar'], vector=r['vector'] - b['vector'],
                     comp=r['comp'] - b['comp'], mem=r['mem'] - b['mem'], mstrips=r['mstrips'] - b['mstrips'], total=r['total'] - b['total'])
    rows[(name, var)] = d

with open(os.path.join(OUT, 'bench.tsv'), 'w') as f:
    f.write('kernel\tvariant\tstrip\tport\tcommit\trc\tblocks\tstrips\tvops\tscalar_cycles\tvector_cycles\tcompute\tmemory\tmem_bound_strips\ttotal_cycles\n')
    for (name, var), d in rows.items():
        for cf, r in d.items():
            f.write('%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n' % (name, var, cf[0], cf[1], cf[2], r['rc'], r['blocks'], r['strips'], r['vops'], r['scalar'], r['vector'], r['comp'], r['mem'], r['mstrips'], r['total']))

# ---- the tables
def gm(v): return math.exp(sum(math.log(x) for x in v) / len(v)) if v else float('nan')
# a hand-written kernel counts only if the program gives the same result as the lv build of the same kernel (the cause of a difference was not investigated)
dropped = []
for (name, var) in list(rows):
    if var == 'hand':
        lv = rows.get((name.replace('(fir)', ''), 'lv'))
        if not lv or (lv[(32, 16, 1)]['rc'], lv[(32, 16, 1)]['out']) != (rows[(name, var)][(32, 16, 1)]['rc'], rows[(name, var)][(32, 16, 1)]['out']):
            dropped.append(name); del rows[(name, var)]
blk = [(k, d) for k, d in rows.items() if d and d[(32, 16, 1)]['blocks'] > 0]
noblk = [k for k, d in rows.items() if d and d[(32, 16, 1)]['blocks'] == 0]
md = []
md.append('Model: one cycle for each vector instruction in a strip (a vfir one for each tap), a commit of 1 cycle for each strip, a vend 1 cycle, the strip is the greater of its compute cycles and the cycles its memory instructions hold the port (bytes / port, rounded up for each instruction), scalar instructions 1 cycle each (a vec is one of them).  Per kernel the set-up of the driver is subtracted.')
md.append('%d programs ran (%d kernels `lv` and %d hand-written); %d of them have a vec block (%d lv, %d hand); without a block (no vector code in the lv build, the strip cannot matter): %s.' % (
    len(rows), sum(1 for k in rows if k[1] == 'lv'), sum(1 for k in rows if k[1] == 'hand'), len(blk), sum(1 for k, d in blk if k[1] == 'lv'), sum(1 for k, d in blk if k[1] == 'hand'), ' '.join(k[0] for k in noblk) or 'none'))
# result equality
bad = []
for (name, var), d in rows.items():
    outs = {(r['rc'], r['out']) for cf, r in d.items()}
    if len(outs) != 1: bad.append((name, var, sorted({(cf[0], r['rc']) for cf, r in d.items()})))
md.append('Hand-written kernels of vec-forms (k_*.vec.s, run with the same driver): used: %s; assembled but dropped, the program\'s result differs from the lv build of the same kernel (the cause was not investigated: the listings take their own register arguments, the driver calls with the C convention): %s; not assembled by the current as64 (older syntax): %s.' % (' '.join(k[0] for k in rows if k[1] == 'hand') or 'none', ' '.join(dropped) or 'none', ' '.join(hand_skipped) or 'none'))
md.append('Results (exit status and a hash of every global array of the driver, written to standard output) of the kernels at all %d (strip, port, commit) settings: identical for %d of %d programs.%s' % (
    len(CONFIGS), len(rows) - len(bad), len(rows), ''.join('  DIFFERS: %s %s exit status by strip %s.' % (n, v, ' '.join('%d:%d' % x for x in dd)) for n, v, dd in bad)))
def cls(d, p=16):
    v32 = d[(32, p, 1)]['vector']; v16 = d[(16, p, 1)]['vector']; v8 = d[(8, p, 1)]['vector']
    r = v16 / v32 if v32 else 1
    return r
md.append('\n### Per kernel (port 16 bytes a cycle, commit 1): vector instructions executed, strips, model cycles in total (scalar + vector), slowdown against strip 32\n')
md.append('| kernel | build | vec instrs (at 32) | strips 32 / 16 / 8 | cycles 32 | cycles 16 | cycles 8 | slow 16 | slow 8 | vector cycles 16/32 | memory / compute cycles at 32 | scalar share at 32 | class |')
md.append('|---|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|')
summ = []
for (name, var), d in sorted(blk, key=lambda t: (t[0][1], t[0][0])):
    c = {s: d[(s, 16, 1)] for s in (8, 16, 32, 64)}
    t32, t16, t8 = c[32]['total'], c[16]['total'], c[8]['total']
    sh = c[32]['scalar'] / t32
    r = c[16]['vector'] / c[32]['vector']
    r8 = c[8]['vector'] / c[16]['vector']
    if sh > 0.5: cl = 'scalar-dominated'
    elif r >= 1.9 and r8 >= 1.9: cl = 'compute-bound'
    elif r <= 1.2: cl = 'memory-bound at 32'
    else: cl = 'between'
    summ.append((name, var, t16 / t32, t8 / t32, cl, sh, c))
    md.append('| %s | %s | %d | %d / %d / %d | %d | %d | %d | %.3f | %.3f | %.2f | %.2f | %.2f | %s |' % (name, var, c[32]['vops'], c[32]['strips'], c[16]['strips'], c[8]['strips'], t32, t16, t8, t16 / t32, t8 / t32, r, c[32]['mem'] / max(1, c[32]['comp']), sh, cl))
def stat(sel, label):
    if not sel: return
    s16 = [x[2] for x in sel]; s8 = [x[3] for x in sel]
    md.append('| %s | %d | %.3f | %.3f | %s %.3f | %s %.3f |' % (label, len(sel), gm(s16), gm(s8), max(sel, key=lambda x: x[2])[0], max(s16), max(sel, key=lambda x: x[3])[0], max(s8)))
md.append('\n### Summary at port 16, commit 1 (geometric mean and worst case of cycles(strip) / cycles(32) over the kernels with a block)\n')
md.append('| set | kernels | geomean 16 | geomean 8 | worst 16 | worst 8 |\n|---|---:|---:|---:|---|---|')
stat(summ, 'all with a block'); stat([x for x in summ if x[1] == 'lv'], 'lv only'); stat([x for x in summ if x[1] == 'hand'], 'hand-written only')
stat([x for x in summ if x[4] != 'scalar-dominated'], 'not scalar-dominated')
for cl in ('compute-bound', 'memory-bound at 32', 'between', 'scalar-dominated'):
    stat([x for x in summ if x[4] == cl], cl)
md.append('\nClass (at port 16): compute-bound = the vector cycles double at both halvings (ratio 1.9 or more); memory-bound at 32 = the vector cycles hardly change from 32 to 16 (1.2 or less: a commit cost of 1 a strip is the allowance); between = the rest; scalar-dominated = more than half of the cycles at strip 32 are scalar instructions.')
# the split by port and by step: halving the strip leaves the vector cycles unchanged (memory-bound: the port is the limit at the larger strip, a commit cost of 1 a strip is allowed for: ratio up to 1.2), doubles them
# (compute-bound: 1.9 or more), or something between
def step(d, p, a, b):
    va = d[(a, p, 1)]['vector']; vb = d[(b, p, 1)]['vector']
    r = vb / va if va else 1
    return 'unchanged' if r <= 1.2 else 'doubles' if r >= 1.9 else 'between'
sd = [(k, d) for k, d in blk if d[(32, 16, 1)]['scalar'] / d[(32, 16, 1)]['total'] <= 0.5]
md.append('\n### Memory-bound or compute-bound, by port and by step (of the %d kernels with a block that are not scalar-dominated at strip 32; the vector cycles when the strip halves: unchanged = ratio 1.2 or less, doubles = 1.9 or more)\n' % len(sd))
md.append('| port | 32 to 16: unchanged / between / doubles | 16 to 8: unchanged / between / doubles | 64 to 32 (the vector cycles when the strip doubles back): unchanged / between / doubles |\n|---:|---|---|---|')
for p in (8, 16, 32):
    row = []
    for a, b in ((32, 16), (16, 8), (64, 32)):
        cnt = {x: sum(1 for k, d in sd if step(d, p, a, b) == x) for x in ('unchanged', 'between', 'doubles')}
        row.append('%d / %d / %d' % (cnt['unchanged'], cnt['between'], cnt['doubles']))
    md.append('| %d | %s |' % (p, ' | '.join(row)))
# sensitivity
md.append('\n### Sensitivity: geometric mean (and worst) slowdown against strip 32 of the same port and commit, over the %d kernels with a block\n' % len(blk))
md.append('| port (bytes a cycle) | commit | strip 16 | strip 8 | strip 64 (cycles against strip 32: below 1 is faster) |\n|---:|---:|---|---|---|')
for p in (8, 16, 32):
    for c in ((1,) if p != 16 else (0, 1, 2)):
        row = []
        for s in (16, 8, 64):
            v = [d[(s, p, c)]['total'] / d[(32, p, c)]['total'] for k, d in blk]
            row.append('%.3f (worst %.3f)' % (gm(v), max(v)) if s != 64 else '%.3f (fastest %.3f)' % (gm(v), min(v)))
        md.append('| %d | %d | %s |' % (p, c, ' | '.join(row)))
md.append('\n### Per kernel at the other ports (cycles at strip 32, slowdown at strip 16 and 8 against strip 32), commit 1\n')
md.append('| kernel | build | cycles 32 (port 8) | slow 16 | slow 8 | cycles 32 (port 32) | slow 16 | slow 8 |\n|---|---|---:|---:|---:|---:|---:|---:|')
for (name, var), d in sorted(blk, key=lambda t: (t[0][1], t[0][0])):
    f = lambda p: (d[(32, p, 1)]['total'], d[(16, p, 1)]['total'] / d[(32, p, 1)]['total'], d[(8, p, 1)]['total'] / d[(32, p, 1)]['total'])
    a, b = f(8), f(32)
    md.append('| %s | %s | %d | %.3f | %.3f | %d | %.3f | %.3f |' % (name, var, a[0], a[1], a[2], b[0], b[1], b[2]))
md.append('\n### Strips of 64 bytes (the speed-up over 32 at port 16, commit 1)\n')
md.append('| kernel | build | cycles 32 | cycles 64 | speed-up |\n|---|---|---:|---:|---:|')
for (name, var), d in sorted(blk, key=lambda t: (t[0][1], t[0][0])):
    a, b = d[(32, 16, 1)]['total'], d[(64, 16, 1)]['total']
    md.append('| %s | %s | %d | %d | %.3f |' % (name, var, a, b, a / b))
open(os.path.join(OUT, 'bench.md'), 'w').write('\n'.join(md) + '\n')
print('\n'.join(md))
shutil.rmtree(tmp, ignore_errors=True)
