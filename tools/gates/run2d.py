#!/usr/bin/env python3
"""run2d.py [--quick] [OUTDIR] -- the tile benchmarks of docs/encoding-work/vec-2d.md (errata 176).

For each graphics-shaped kernel (docs/encoding-work/arch-data/vec-forms/tiles/: tiles.c, k_NAME.vecrows.s, k_NAME.vec2d.s, the checked k_NAME.*.chk.s) and each tile size it builds:
  scalar  tiles.c with clang -O2 and the vectoriser off, then llc: the no-vectorisation baseline (compiler-made scalar code, 1 cycle an instruction in both models)
  lv      tiles.c through opt -O2 -mtriple=pdp64 (LoopVectorize, innermost loops only) and llc with PDP64VecLoop: the compiler's loop of 1D blocks
  rows    the hand-written scalar row loop around one 1D vec block (the existing form)
  2d      the hand-written vec2 block
  rows.chk, 2d.chk   (sad, mblend) the same with a bounds check per row / per tile (chk2)
with the driver tile-main.c (fills the planes, calls the kernel, writes the result and the destination plane to standard output), subtracts the driver with the call left out (NOCALL), checks that
every form writes the same bytes as the scalar build, and runs sim64 -V at strips 16, 32, 64, ports 8, 16, 32 (vrow 1, vmemlat 4, fpga table, vpipe 1) and, at port 16 and strips 16 and 32, the
sensitivities vrow 0 and 2 and vmemlat 2 and 8.  Writes OUTDIR/tiles.tsv (every run) and OUTDIR/summary.md.  Needs build/sim64, as64, ld64 and the LLVM tools of ../llvm-build (llvm/bench/bench.py).
tile sizes: 8x8 16x16 32x32 64x64 256x256 and the widths 8 16 32 64 128 with 16 rows (W: bytes of the row of the first stream; for gray and quant W is the pixels or floats of a row).
"""
import os, re, sys, subprocess, tempfile, shutil, hashlib
from concurrent.futures import ThreadPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__)); R = os.path.dirname(os.path.dirname(HERE))
args = [a for a in sys.argv[1:] if not a.startswith('--')]
QUICK = '--quick' in sys.argv
OUT = args[0] if args else os.path.join(HERE, '2d-results')
os.makedirs(OUT, exist_ok=True)
BH = os.path.join(R, 'llvm', 'bench')
src = open(os.path.join(BH, 'bench.py')).read()
g = {'__file__': os.path.join(BH, 'bench.py'), '__name__': 'bench'}
exec(compile(src[:src.index('\ndef main():')], 'bench.py', 'exec'), g)
B = g['B']; LLC = g['LLC']; CFLAGS = g['CFLAGS']; run = g['run']; ll_of = g['ll_of']; ll_of_lv = g['ll_of_lv']
TD = os.environ.get('TILES_DIR') or os.path.join(R, 'docs', 'encoding-work', 'arch-data', 'vec-forms', 'tiles')
tmp = tempfile.mkdtemp(prefix='run2d.')
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
""")
def must(cmd, what):
    r = run(cmd)
    if r.returncode: raise SystemExit('%s failed: %s' % (what, (r.stderr or r.stdout)[:400]))
must([as64, '-o', os.path.join(tmp, 'crt.o'), os.path.join(tmp, 'crt.s')], 'crt')
def llc(ll, out): must([LLC, '-mtriple=pdp64-unknown-elf', '-O2', ll, '-o', out], 'llc ' + ll)
def asm(sfile):
    o = sfile[:-2] + '.o'; must([as64, '-o', o, sfile], 'as64 ' + sfile); return o

KERNELS = ['sad', 'avg', 'mblend', 'blend', 'put8h', 'gray', 'thresh', 'quant']
CHK = ['sad', 'mblend']
TILES = [(8, 8), (16, 16), (32, 32), (64, 64), (256, 256), (8, 16), (32, 16), (64, 16), (128, 16)]
if QUICK: TILES = [(16, 16), (64, 16)]
# the compiler's two builds of tiles.c
tsrc = os.path.join(TD, 'tiles.c')
ll_s = os.path.join(tmp, 'tiles.s.ll'); ll_of(tsrc, ll_s); sn_s = os.path.join(tmp, 'tiles.scalar.s'); llc(ll_s, sn_s)
ll_l = os.path.join(tmp, 'tiles.lv.ll'); ll_of_lv(tsrc, ll_l); sn_l = os.path.join(tmp, 'tiles.lv.s'); llc(ll_l, sn_l)
objs = {'scalar': asm(sn_s), 'lv': asm(sn_l)}
# the hand kernels: the listings have no .globl, and the driver calls t_NAME
for k in KERNELS:
    for form in ('vecrows', 'vec2d'):
        for chk in ((False, True) if k in CHK else (False,)):
            nm = 'k_%s.%s%s.s' % (k, form, '.chk' if chk else '')
            body = open(os.path.join(TD, nm)).read()
            fn = 't_%s%s' % (k, '_chk' if chk else '')
            d = os.path.join(tmp, 'h_' + nm); os.makedirs(d)
            sp = os.path.join(d, 'k.s'); open(sp, 'w').write('\t.text\n\t.globl\t%s\n%s:\n%s' % (fn, fn, body))
            objs[(k, form, chk)] = asm(sp)
def driver(k, w, h, nocall=False):
    n = 'main.%s.%d.%d%s' % (k, w, h, '.n' if nocall else '')
    ll = os.path.join(tmp, n + '.ll')
    must(['clang'] + CFLAGS[:-2] + ['-S', '-emit-llvm', '-DK_' + k, '-DW=%d' % w, '-DH=%d' % h] + (['-DNOCALL'] if nocall else []) + ['-o', ll + '.0', os.path.join(TD, 'tile-main.c')], 'clang driver')
    txt = open(ll + '.0').read()
    txt = re.sub(r'^target (datalayout|triple).*\n', '', txt, flags=re.M)
    txt = re.sub(r'"(target-cpu|target-features|tune-cpu)"="[^"]*"', '', txt)
    open(ll, 'w').write(txt)
    s = os.path.join(tmp, n + '.s'); llc(ll, s); return asm(s)
def link(objl, out):
    must([ld64, '-o', out, os.path.join(tmp, 'crt.o')] + objl, 'ld64 ' + out)

progs = []		# (kernel, tile, variant, exe); variant 'base' is the driver with the call left out
for k in KERNELS:
    for (w, h) in TILES:
        base = driver(k, w, h, True); x = os.path.join(tmp, 'base.%s.%d.%d.x' % (k, w, h)); link([base, objs['scalar']], x); progs.append((k, (w, h), 'base', x))
        mo = driver(k, w, h)
        for var, ob in (('scalar', [objs['scalar']]), ('lv', [objs['lv']]), ('rows', [objs[(k, 'vecrows', False)]]), ('2d', [objs[(k, 'vec2d', False)]])):
            x = os.path.join(tmp, '%s.%s.%d.%d.x' % (var, k, w, h)); link([mo] + ob, x); progs.append((k, (w, h), var, x))
        if k in CHK:
            mc = driver(k + '_chk', w, h)
            for var, form in (('rows.chk', 'vecrows'), ('2d.chk', 'vec2d')):
                # the checked kernels have the driver of their own (K_sad_chk: t_sad_chk); the unchecked reference output comes from the scalar program of the same tile
                x = os.path.join(tmp, '%s.%s.%d.%d.x' % (var, k, w, h)); link([mc, objs[(k, form, True)], objs['scalar']], x); progs.append((k, (w, h), var, x))

# the runs
MAIN = [(s, p, 1, 4) for s in (16, 32, 64) for p in (8, 16, 32)]
SENS = [(s, 16, vr, vm) for s in (16, 32) for (vr, vm) in ((0, 4), (2, 4), (1, 2), (1, 8))]
CONFIGS = MAIN + (SENS if not QUICK else [])
pat1 = re.compile(r'vec blocks (\d+) strips (\d+) ops (\d+) elems (\d+)')
pat2 = re.compile(r'vec model strip (\d+) port (\d+) commit (\d+): scalar (\d+) vector (\d+) ')
pat3 = re.compile(r'vec model2 latency (\S+) strip (\d+) port (\d+) commit (\d+) vpipe (\d+) vmemlat (\d+): scalar (\d+) vector (\d+) ')
pat4 = re.compile(r'vec2 blocks (\d+) rows (\d+) vskips (\d+)')
def sim(job):
    (k, tile, var, x), cf = job
    s, p, vr, vm = cf
    r = subprocess.run([sim64, '-V', '-S', str(s), '--vport=%d' % p, '--vrow=%d' % vr, '--vmemlat=%d' % vm, x], capture_output=True, timeout=1200)
    e = r.stderr.decode('utf-8', 'replace')
    m1, m2, m3, m4 = pat1.search(e), pat2.search(e), pat3.search(e), pat4.search(e)
    if not (m1 and m2 and m3): return job, None
    return job, dict(rc=r.returncode, out=hashlib.md5(r.stdout).hexdigest(), blocks=int(m1.group(1)), strips=int(m1.group(2)), vops=int(m1.group(3)), s=int(m2.group(4)), v1=int(m2.group(5)),
                     v2=int(m3.group(8)), rows=int(m4.group(2)) if m4 else 0, skips=int(m4.group(3)) if m4 else 0)
jobs = []
for pr in progs:
    cfs = CONFIGS if pr[2] not in ('base', 'scalar') else CONFIGS[:1]
    for cf in cfs: jobs.append((pr, cf))
res = {}
with ThreadPoolExecutor(max_workers=int(os.environ.get('JOBS', '8'))) as ex:
    for job, r in ex.map(sim, jobs): res[((job[0][0], job[0][1], job[0][2]), job[1])] = r
def get(k, tile, var, cf):
    cfx = cf if var not in ('base', 'scalar') else CONFIGS[0]
    return res.get(((k, tile, var), cfx))
rows = []
bad = []
for k in KERNELS:
    for tile in TILES:
        ref = get(k, tile, 'scalar', CONFIGS[0])
        for var in ('scalar', 'lv', 'rows', '2d', 'rows.chk', '2d.chk'):
            if var.endswith('.chk') and k not in CHK: continue
            for cf in CONFIGS:
                r = get(k, tile, var, cf); b = get(k, tile, 'base', cf)
                if r is None or b is None or ref is None: bad.append((k, tile, var, cf, 'no result')); continue
                if r['rc'] != 0 or r['out'] != ref['out']: bad.append((k, tile, var, cf, 'output differs from the scalar build (rc %d)' % r['rc']))
                sc = r['s'] - b['s']
                rows.append((k, tile[0], tile[1], var) + cf + (sc, r['vops'] - b['vops'], r['strips'] - b['strips'], r['rows'] - b['rows'], sc + r['v1'] - b['v1'], sc + r['v2'] - b['v2']))
with open(os.path.join(OUT, 'tiles.tsv'), 'w') as f:
    f.write('kernel\tW\tH\tvariant\tstrip\tport\tvrow\tvmemlat\tscalar_insns\tvector_insns\tstrips\trows\tcycles_model1\tcycles_model2\n')
    for r in rows: f.write('\t'.join(map(str, r)) + '\n')
print('%d runs, %d rows, %d problems' % (len(jobs), len(rows), len(bad)))
for b in bad[:40]: print('PROBLEM', b)
if not os.environ.get('KEEP'): shutil.rmtree(tmp, ignore_errors=True)
else: print('kept', tmp)
sys.exit(1 if bad else 0)
