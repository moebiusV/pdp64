#!/usr/bin/env python3
"""
bench.py -- the numbers of the comparison of the vectorising approaches (llvm/README.md, llvm/vector-usage.md).

For each kernel of docs/encoding-work/arch-data/vec-forms/{kernels.c,games,blas,seg} and llvm/bench/simple.c, and for each VARIANT (flags of llc), it
compiles the kernel file with clang (-O2, the host's vectoriser off) and llc, links it with bench_main.c (compiled once with the scalar llc: its set-up loops are
subtracted by running -DK_none), runs sim64 with -P and -V, and prints for each kernel and variant:

   pinsn   instructions executed (sim64 -P #instructions; a vec block counts ONE: the `vec` instruction, its body is not stepped by the profile)
   vops    vector instructions executed (one for each strip: sim64 -V "ops")
   strips, elems, blocks   the other -V counters
   total   pinsn + vops: every instruction that was issued, scalar or vector
   fbytes  static size of the kernel file's text (the sum of its functions)
   result  the exit status of the program (a cross-check of the variants against each other)

usage: bench.py [-k kernel,...] [-v variant,...] [--csv file] [--keep dir]
"""
import argparse, os, re, subprocess, sys, tempfile, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
R = os.path.dirname(os.path.dirname(HERE))
B = os.path.join(R, 'build')
LLC = os.path.join(os.path.dirname(R), 'llvm-build', 'bin', 'llc')
VF = os.path.join(R, 'docs', 'encoding-work', 'arch-data', 'vec-forms')
SRCS = [os.path.join(VF, 'kernels.c'), os.path.join(VF, 'games', 'games.c'), os.path.join(VF, 'blas', 'blas.c'),
        os.path.join(VF, 'seg', 'seg.c'), os.path.join(HERE, 'simple.c')]
VARIANTS = {
    'scalar': [],
    'vecloop': ['-pdp64-vecloop'],                           # approach (b): one vec block for the whole loop
    'strip': ['-pdp64-vecloop', '-pdp64-vecloop-strip'],     # approach (a): a vec block for each strip in a scalar loop, one for the remainder
}
CFLAGS = ['-O2', '-m64', '-fno-builtin-memset', '-fno-builtin-memcpy', '-fno-stack-protector', '-mlong-double-64', '-mno-sse', '-mno-mmx',
          '-fno-vectorize', '-fno-slp-vectorize', '-fno-unroll-loops', '-ffp-contract=fast', '-ffast-math', '-w', '-S', '-emit-llvm']

def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)

def ll_of(src, out):
    r = run(['clang'] + CFLAGS + ['-o', out + '.0', src])
    if r.returncode:
        sys.exit('clang failed on %s: %s' % (src, r.stderr))
    txt = open(out + '.0').read()
    txt = re.sub(r'^target (datalayout|triple).*\n', '', txt, flags=re.M)
    txt = re.sub(r'"(target-cpu|target-features|tune-cpu)"="[^"]*"', '', txt)
    open(out, 'w').write(txt)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('-k'); ap.add_argument('-v'); ap.add_argument('--csv'); ap.add_argument('--keep')
    a = ap.parse_args()
    tmp = tempfile.mkdtemp()
    bdir = os.path.join(tmp, 'bin'); os.mkdir(bdir)
    for t in ('as64', 'ld64', 'sim64'):
        shutil.copy(os.path.join(B, t), bdir)
    as64, ld64, sim64 = [os.path.join(bdir, t) for t in ('as64', 'ld64', 'sim64')]
    crt = os.path.join(HERE, '..', 'tests', 'lib')
    # the crt of check.sh
    open(os.path.join(tmp, 'crt.s'), 'w').write("""	.text
	.globl	_start
_start:	call	main
	trap	#0
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
    kernels = []
    for s in SRCS:
        for m in re.finditer(r'^[a-z][a-z0-9_ ]*[ \*](k_[a-z0-9_]+)\(', open(s).read(), flags=re.M):
            kernels.append((m.group(1), s))
    if a.k:
        want = a.k.split(',')
        kernels = [k for k in kernels if k[0] in want]
    variants = a.v.split(',') if a.v else list(VARIANTS)
    # the driver, once (scalar llc)
    def llc(ll, flags, out):
        r = run([LLC, '-mtriple=pdp64-unknown-elf', '-O2'] + flags + [ll, '-o', out])
        if r.returncode:
            return r.stderr.strip().splitlines()[0] if r.stderr.strip() else 'llc failed'
        return None
    def asm_link(sfiles, out):
        objs = []
        for s in sfiles:
            o = s[:-2] + '.o'
            r = run([as64, '-o', o, s])
            if r.returncode:
                return None, 'as64: ' + r.stderr.strip().splitlines()[0]
            objs.append(o)
        r = run([ld64, '-M', '-o', out, os.path.join(tmp, 'crt.o')] + objs)
        if r.returncode:
            return None, 'ld64: ' + r.stderr.strip().splitlines()[0]
        return r.stdout, None
    def sim(x):
        r = run([sim64, '-P', x + '.prof', '-V', x], timeout=120)
        m = re.search(r'#instructions (\d+)', open(x + '.prof').read()) if os.path.exists(x + '.prof') else None
        v = re.search(r'vec blocks (\d+) strips (\d+) ops (\d+) elems (\d+)', r.stderr)
        return (r.returncode, int(m.group(1)) if m else None, [int(g) for g in v.groups()] if v else [0, 0, 0, 0])
    rows = []
    kll = {}
    for s in SRCS:
        o = os.path.join(tmp, os.path.basename(s)[:-2] + '.ll')
        ll_of(s, o)
        kll[s] = o
    # main: one .ll per kernel (the macro), the scalar llc
    results = {}
    def build_run(k, src, vname):
        flags = VARIANTS[vname]
        tag = '%s.%s' % (k, vname)
        # the kernel file
        ksn = os.path.join(tmp, '%s.%s.s' % (os.path.basename(src)[:-2], vname))
        if not os.path.exists(ksn):
            e = llc(kll[src], flags, ksn)
            if e: return None, e
        # the driver
        mll = os.path.join(tmp, 'main.%s.ll' % k)
        r = run(['clang'] + CFLAGS[:-2] + ['-S', '-emit-llvm', '-D' + ('K_' + k if k else 'K_none'), '-o', mll + '.0', os.path.join(HERE, 'bench_main.c')])
        txt = open(mll + '.0').read()
        txt = re.sub(r'^target (datalayout|triple).*\n', '', txt, flags=re.M)
        txt = re.sub(r'"(target-cpu|target-features|tune-cpu)"="[^"]*"', '', txt)
        open(mll, 'w').write(txt)
        msn = os.path.join(tmp, 'main.%s.s' % k)
        e = llc(mll, [], msn)
        if e: return None, e
        x = os.path.join(tmp, tag + '.x')
        out, e = asm_link([ksn, msn], x)
        if e: return None, e
        # the size of the kernel file's text: the symbols of the map between the first kernel symbol and the driver's main
        syms = []
        for ln in out.splitlines():
            m = re.match(r'0x([0-9a-f]+) (\S+)', ln)
            if m: syms.append((int(m.group(1), 16), m.group(2)))
        text = re.search(r'text 0x([0-9a-f]+) \+0x([0-9a-f]+)', out)
        tend = int(text.group(1), 16) + int(text.group(2), 16)
        syms.sort()
        fb = 0
        for i, (ad, nm) in enumerate(syms):
            if nm.startswith('k_'):
                nxt = syms[i + 1][0] if i + 1 < len(syms) else tend
                if nm == k or k == 'none': fb += nxt - ad
        rc, pi, v = sim(x)
        return dict(rc=rc, pinsn=pi, blocks=v[0], strips=v[1], vops=v[2], elems=v[3], fbytes=fb), None
    # pcc's own scalar code for the same kernels (the listings of the vec-forms study): the static size of each function
    pcc = {}
    srcs = [os.path.join(VF, 'pcc-scalar.s'), os.path.join(VF, 'games', 'pcc-scalar-games.s'), os.path.join(VF, 'blas', 'pcc-scalar-blas.s'), os.path.join(VF, 'seg', 'pcc-scalar-seg.s')]
    open(os.path.join(tmp, 'stub.s'), 'w').write('\t.text\n\t.globl main\nmain:\tret\n\t.globl expf\nexpf:\tret\n\t.globl sqrtf\nsqrtf:\tret\n\t.globl abs\nabs:\tret\n')
    pf = []
    for i, sp in enumerate(srcs + [os.path.join(tmp, 'stub.s')]):
        if os.path.exists(sp):
            d = os.path.join(tmp, 'pcc%d.s' % i); shutil.copy(sp, d); pf.append(d)
    out, e = asm_link(pf, os.path.join(tmp, 'pcc.x'))
    if out:
        syms = sorted((int(m.group(1), 16), m.group(2)) for m in re.finditer(r'^0x([0-9a-f]+) (\S+)', out, flags=re.M))
        tm = re.search(r'text 0x([0-9a-f]+) \+0x([0-9a-f]+)', out)
        tend = int(tm.group(1), 16) + int(tm.group(2), 16)
        for i, (ad, nm) in enumerate(syms):
            if nm.startswith('k_'):
                pcc[nm] = (syms[i + 1][0] if i + 1 < len(syms) else tend) - ad
    base = {}
    for vname in variants:
        r, e = build_run('none', SRCS[0], vname)
        if e: sys.exit('driver: ' + e)
        base[vname] = r
    print('%-14s %-8s %9s %7s %7s %7s %8s %9s %6s %6s' % ('kernel', 'variant', 'pinsn', 'blocks', 'strips', 'vops', 'elems', 'total', 'fbytes', 'pcc'))
    for k, src in kernels:
        for vname in variants:
            r, e = build_run(k, src, vname)
            if e:
                print('%-14s %-8s  (%s)' % (k, vname, e[:70])); continue
            b = base[vname]
            row = dict(kernel=k, variant=vname, pinsn=r['pinsn'] - b['pinsn'], blocks=r['blocks'], strips=r['strips'], vops=r['vops'], elems=r['elems'], fbytes=r['fbytes'], rc=r['rc'])
            row['total'] = row['pinsn'] + row['vops']; row['pcc'] = pcc.get(k, 0)
            rows.append(row)
            print('%-14s %-8s %9d %7d %7d %7d %8d %9d %6d %6s  rc=%d' % (k, vname, row['pinsn'], row['blocks'], row['strips'], row['vops'], row['elems'], row['total'], row['fbytes'], pcc.get(k, '-'), row['rc']))
    if a.csv:
        with open(a.csv, 'w') as f:
            f.write('kernel,variant,pinsn,blocks,strips,vops,elems,total,fbytes,pccbytes,rc\n')
            for r in rows:
                f.write('%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d\n' % (r['kernel'], r['variant'], r['pinsn'], r['blocks'], r['strips'], r['vops'], r['elems'], r['total'], r['fbytes'], r['pcc'], r['rc']))
    if a.keep:
        os.makedirs(a.keep, exist_ok=True)
        for f in os.listdir(tmp):
            if f.endswith('.s') or f.endswith('.ll'):
                shutil.copy(os.path.join(tmp, f), a.keep)
    shutil.rmtree(tmp)

main()
