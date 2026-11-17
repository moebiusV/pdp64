#!/usr/bin/env python3
"""vecscan.py -- how much of a codec's C is data-parallel, and what shape it has: the data for the vector decision (J.8.5).

usage: vecscan.py COMPILE_COMMANDS.json OUTDIR [-j N] [-f REGEX]       (compile_commands.json of a meson build of dav1d with enable_asm=false)

For each C file whose name matches REGEX (default: the pixel kernels: cdef, itx, mc, ipred, loopfilter, looprestoration, filmgrain, at both bit depths)
the file is compiled with clang at -O3 for these targets, with the vectorizer and with it off:
    x86_64 -mavx2    aarch64 (NEON)    riscv64 -march=rv64gcv    loongarch64 -mlasx
(`-fno-vectorize -fno-slp-vectorize` for the scalar row).  Per target and mode: instructions and instruction bytes of the object (llvm-objdump-21),
and the loops the vectorizer made ("vectorized loop" and SLP remarks).  The AVX2 and AArch64 IR is then read: every block of a vectorized loop body
(`vector.body`) is classified:
    map        loads, element operations and stores only
    reduce     a vector accumulator (a vector phi besides the induction variable) or an @llvm.vector.reduce
    shuffle    shufflevector in the body (a lane permutation, widening interleave)
    masked     masked loads and stores, or a select driven by a compare
    gather     @llvm.masked.gather or scatter
and for each its numbers: element operations per iteration (the chain a memory-to-memory vector instruction would have to be repeated for),
load streams, store streams, the element width.  Writes OUTDIR/size.csv, OUTDIR/loops.csv and OUTDIR/summary.md."""
import os, re, sys, json, shlex, subprocess, tempfile, collections, concurrent.futures as cf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import objstat

TARGETS = [('x86_64-avx2', ['--target=x86_64-linux-gnu', '-mavx2', '-mfma']),
           ('aarch64', ['--target=aarch64-linux-gnu']),
           ('riscv64-v', ['--target=riscv64-linux-gnu', '-march=rv64gcv', '-mabi=lp64d']),
           ('loongarch64-lasx', ['--target=loongarch64-linux-gnu', '-mlasx'])]
SYS = {'x86_64-avx2': 'x86_64', 'aarch64': 'aarch64', 'riscv64-v': 'riscv64', 'loongarch64-lasx': 'loongarch64'}
DEFAULT = r'(cdef|itx|mc|ipred|loopfilter|looprestoration|filmgrain)_tmpl\.c$|itx_1d\.c$'


def flags_of(entry):
    """the -I, -D and -std flags of one compile command (the build directory is the entry's)"""
    a = shlex.split(entry['command'])
    out = []
    i = 1
    while i < len(a):
        x = a[i]
        if x in ('-I', '-D', '-isystem'):
            out += [x, a[i + 1]]; i += 2; continue
        if x.startswith(('-I', '-D', '-std=')):
            out.append(x)
        i += 1
    bd = [x for x in out if x.startswith('-DBITDEPTH')]
    return out, bd[0] if bd else 'common'


def run(cmd, cwd):
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, errors='replace', timeout=600)


LOOP = re.compile(r'vectorized loop \(vectorization width: (\d+), interleaved count: (\d+)\)')
MISS = re.compile(r'loop not vectorized: ([^\[\n]*?) \[-Rpass-analysis=loop-vectorize\]')
SLP = re.compile(r'(Stores SLP vectorized|SLP vectorized with cost)')


def classify_ir(ir):
    """-> list of dicts, one per `vector.body` block of the IR"""
    res = []
    fn = None
    blocks = collections.OrderedDict()
    cur = None
    for ln in ir.split('\n'):
        m = re.match(r'^define .*@([\w.$"-]+)\(', ln)
        if m:
            fn = m.group(1); blocks = collections.OrderedDict(); cur = None
            continue
        if ln == '}' and fn:
            for lab, body in blocks.items():
                if lab.startswith('vector.body'):
                    res.append(analyse(fn, lab, body))
            fn = None
            continue
        if fn:
            m = re.match(r'^([\w.$-]+):', ln)
            if m and not ln.startswith(' '):
                cur = m.group(1); blocks[cur] = []
            elif cur is not None:
                blocks[cur].append(ln)
    return res


VT = re.compile(r'<(?:vscale x )?(\d+) x (i\d+|float|double|half|bfloat)>')


def analyse(fn, lab, body):
    loads = stores = ops = shuf = red = gather = masked = sel = conv = 0
    widths = collections.Counter()
    phis = 0
    for ln in body:
        s = ln.strip()
        if not s or s.startswith(';'):
            continue
        vm = VT.search(s)
        if re.search(r'= phi <', s):
            phis += 1
        if 'llvm.vector.reduce' in s:
            red += 1
        elif 'llvm.masked.gather' in s or 'llvm.masked.scatter' in s:
            gather += 1
        elif 'llvm.masked.load' in s or 'llvm.masked.store' in s:
            masked += 1
        elif re.search(r'= load <', s):
            loads += 1; widths[vm.group(2)] += 1 if vm else 0
        elif re.match(r'store <', s):
            stores += 1
        elif 'shufflevector' in s:
            shuf += 1
        elif re.search(r'= select <', s):
            sel += 1; masked += 1
        elif re.search(r'= (zext|sext|trunc|fptosi|sitofp|uitofp|fptoui|fpext|fptrunc|bitcast) <', s):
            conv += 1
        elif re.search(r'= (add|sub|mul|shl|lshr|ashr|and|or|xor|fadd|fsub|fmul|fdiv|sdiv|udiv|icmp|fcmp|call) ', s) and vm:
            ops += 1
    kind = 'gather' if gather else 'reduce' if (red or phis > 1) else 'shuffle' if shuf else 'masked' if masked else 'map'
    w = widths.most_common(1)[0][0] if widths else ''
    return dict(function=fn, kind=kind, ops=ops, loads=loads, stores=stores, shuffles=shuf, conv=conv, width=w, phis=phis)


def one(job):
    entry, cdir, root, tname, targs, mode = job
    fl, tag = flags_of(entry)
    src = os.path.normpath(os.path.join(cdir, entry['file'])) if not os.path.isabs(entry['file']) else entry['file']
    sysroot = (os.environ.get('SYSROOT_LA64') if tname.startswith('loongarch') and os.environ.get('SYSROOT_LA64') else os.path.join(root, 'sysroot', SYS[tname])) + '/include'
    base = ['clang'] + targs + ['-O3', '-w', '-fno-pic', '-ffreestanding'] + fl + ['-isystem', sysroot]
    if mode == 'scalar':
        base += ['-fno-vectorize', '-fno-slp-vectorize']
    else:
        base += ['-Rpass=(loop-vectorize|slp-vectorizer)', '-Rpass-analysis=loop-vectorize']
    with tempfile.TemporaryDirectory() as w:
        o = w + '/x.o'
        p = run(base + ['-c', src, '-o', o], cdir)
        if p.returncode or not os.path.exists(o):
            return dict(file=os.path.basename(src), tag=tag, target=tname, mode=mode, status='fail', msg=(p.stderr.strip().split('\n') or [''])[0][:120].replace(',', ';')), []
        i, b, t, d, pn, pb, nc = objstat.count_obj(o)
        loops = [(int(m.group(1)), int(m.group(2))) for m in LOOP.finditer(p.stderr)]
        slp = len(SLP.findall(p.stderr))
        miss = [m.group(1) for m in MISS.finditer(p.stderr)]
        rec = dict(file=os.path.basename(src), tag=tag, target=tname, mode=mode, status='ok', ins=i, ibytes=b, vloops=len(loops), slp=slp,
                   avgvf=(sum(l[0] for l in loops) / len(loops)) if loops else 0, missed=len(miss), reasons=';'.join(sorted(set(x[:60].replace(',', ' ') for x in miss))))
        ir = []
        if mode == 'vector' and tname in ('x86_64-avx2', 'aarch64'):
            q = run(base + ['-fno-discard-value-names', '-S', '-emit-llvm', src, '-o', '-'], cdir)		# the names are what marks vector.body
            if q.returncode == 0:
                for c in classify_ir(q.stdout):
                    c.update(file=os.path.basename(src), tag=tag, target=tname)
                    ir.append(c)
        return rec, ir


def main():
    a = sys.argv[1:]
    cc, out = a[0], a[1]
    jobs, rx = 2, DEFAULT
    i = 2
    while i < len(a):
        if a[i] == '-j': jobs = int(a[i + 1]); i += 2
        elif a[i] == '-f': rx = a[i + 1]; i += 2
        else: i += 1
    root = os.environ.get('CORPORA', os.path.expanduser('~/claude/corpora'))
    cdir = os.path.dirname(os.path.abspath(cc))
    ents = [e for e in json.load(open(cc)) if re.search(rx, e['file'])]
    os.makedirs(out, exist_ok=True)
    work = []
    for e in ents:
        e = dict(e); e['directory'] = cdir
        for tname, targs in TARGETS:
            for mode in ('vector', 'scalar'):
                work.append((e, cdir, root, tname, targs, mode))
    recs, loops = [], []
    with cf.ThreadPoolExecutor(jobs) as ex:
        for r, l in ex.map(one, work):
            recs.append(r); loops += l
    cols = ['file', 'tag', 'target', 'mode', 'status', 'ins', 'ibytes', 'vloops', 'slp', 'avgvf', 'missed', 'msg']
    with open(out + '/size.csv', 'w') as f:
        f.write(','.join(cols) + '\n')
        for r in recs:
            f.write(','.join(str(r.get(c, '')) for c in cols) + '\n')
    lc = ['file', 'tag', 'target', 'function', 'kind', 'ops', 'loads', 'stores', 'shuffles', 'conv', 'width', 'phis']
    with open(out + '/loops.csv', 'w') as f:
        f.write(','.join(lc) + '\n')
        for r in loops:
            f.write(','.join(str(r.get(c, '')) for c in lc) + '\n')
    # summary
    L = ['| target | files ok | scalar instructions | vector instructions | ratio | scalar bytes | vector bytes | vectorized loops (vf avg) | SLP |', '|---|---:|---:|---:|---:|---:|---:|---:|---:|']
    for tname, _ in TARGETS:
        v = [r for r in recs if r['target'] == tname and r['mode'] == 'vector' and r['status'] == 'ok']
        s = {(r['file'], r['tag']): r for r in recs if r['target'] == tname and r['mode'] == 'scalar' and r['status'] == 'ok'}
        v = [r for r in v if (r['file'], r['tag']) in s]
        si = sum(s[(r['file'], r['tag'])]['ins'] for r in v); vi = sum(r['ins'] for r in v)
        sb = sum(s[(r['file'], r['tag'])]['ibytes'] for r in v); vb = sum(r['ibytes'] for r in v)
        nl = sum(r['vloops'] for r in v)
        vf = sum(r['avgvf'] * r['vloops'] for r in v) / nl if nl else 0
        L.append('| %s | %d | %s | %s | %.3f | %s | %s | %d (%.1f) | %d |' % (tname, len(v), '{:,}'.format(si), '{:,}'.format(vi), vi / si if si else 0, '{:,}'.format(sb), '{:,}'.format(vb), nl, vf, sum(r['slp'] for r in v)))
    reasons = collections.Counter()
    for r in recs:
        if r['target'] in ('x86_64-avx2', 'aarch64') and r['mode'] == 'vector' and r['status'] == 'ok':
            for x in r.get('reasons', '').split(';'):
                if x:
                    reasons[x] += 1
    L += ['', 'Loops the vectorizer looked at and left (x86-64 AVX2 and AArch64 together): vectorized %d, not vectorized %d.' % (
        sum(r.get('vloops', 0) for r in recs if r['mode'] == 'vector' and r['target'] in ('x86_64-avx2', 'aarch64') and r['status'] == 'ok'),
        sum(r.get('missed', 0) for r in recs if r['mode'] == 'vector' and r['target'] in ('x86_64-avx2', 'aarch64') and r['status'] == 'ok'))]
    L += ['', 'Why loops were left (the reasons the vectorizer gave, counted once per file and target): ' + '; '.join('%s %d' % kv for kv in reasons.most_common(8))]
    for tname in ('x86_64-avx2', 'aarch64'):
        ls = [r for r in loops if r['target'] == tname]
        k = collections.Counter(r['kind'] for r in ls)
        L += ['', '%s: %d vectorized loop bodies in the IR: %s' % (tname, len(ls), ', '.join('%s %d' % kv for kv in k.most_common()))]
        for kind in ('map', 'reduce', 'shuffle', 'masked', 'gather'):
            kk = [r for r in ls if r['kind'] == kind]
            if kk:
                ops = sorted(r['ops'] for r in kk)
                L.append('  %-8s %4d bodies; element operations per iteration: median %d, max %d; loads %.1f, stores %.1f on average' % (kind, len(kk), ops[len(ops) // 2], ops[-1], sum(r['loads'] for r in kk) / len(kk), sum(r['stores'] for r in kk) / len(kk)))
    open(out + '/summary.md', 'w').write('\n'.join(L) + '\n')
    print('\n'.join(L))


if __name__ == '__main__':
    main()
