#!/usr/bin/env python3
"""measure.py: the flags measurement, both sides, one corpus.  Called by tools/measure-flags.sh (which builds the two sides); see README.md of this directory.

  measure.py --work DIR --out PREFIX [--jobs N] [--subset N] [--info key=value ...] \
             --base-tools DIR --base-ccom PATH [--base-ccom-args "-m pdp64/32"] \
             --cur-tools DIR  --cur-ccom PATH  [--cur-ccom-args ""] --src-tree DIR

*-tools is a directory holding that side's as64, ld64 and sim64; --src-tree is a checkout (the base commit: the sources of the tests and of the programs).
Writes PREFIX.txt (key = value lines, the numbers the manual cites) and PREFIX.md (the tables).  Everything under --work is scratch.
The same preprocessed text goes to both compilers, the same programs to both simulators; only files and programs that both sides build are counted.
"""
import argparse, collections, glob, hashlib, os, re, subprocess, sys, threading
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
OB = os.environ.get('OPENBSD_SRC', '/home/matthew/claude/openbsd-src')
PRESETS = ['name=scalar,iw=1,W=8,N=32', 'name=dual,iw=2,W=16,N=48,dq=6,btb=64',
           'name=scalar-c,iw=1,W=8,N=32,ic=1,dc=1', 'name=dual-c,iw=2,W=16,N=48,dq=6,btb=64,ic=1,dc=1']
INFTREES_FLAGS = ['-xno-temps']       # pcc cannot compile inftrees.c otherwise; the same flag on both sides

ap = argparse.ArgumentParser()
ap.add_argument('--work', required=True); ap.add_argument('--out', required=True)
ap.add_argument('--jobs', type=int, default=os.cpu_count() or 4); ap.add_argument('--subset', type=int, default=0)
ap.add_argument('--info', action='append', default=[])
ap.add_argument('--base-tools', required=True); ap.add_argument('--base-ccom', required=True); ap.add_argument('--base-ccom-args', default='')
ap.add_argument('--cur-tools', required=True); ap.add_argument('--cur-ccom', required=True); ap.add_argument('--cur-ccom-args', default='')
ap.add_argument('--src-tree', required=True, help='a checkout whose tests/ and docs/encoding-work/bench/sc/src are the sources of the corpus and of the programs')
A = ap.parse_args()
W = os.path.abspath(A.work)
SIDES = {'base': dict(tools=A.base_tools, ccom=A.base_ccom, args=A.base_ccom_args.split()),
         'now': dict(tools=A.cur_tools, ccom=A.cur_ccom, args=A.cur_ccom_args.split())}
TREE = A.src_tree

# the headers' <machine/...>: a little-endian LP64 machine's (the experiment's own stand-in directory was not kept; amd64's gives the same adler32 and the same size of the corpus)
MACHINE_INC = W + '/inc'
CPPF = ['-E', '-P', '-undef', '-nostdinc', '-D__pcc__', '-D__LP64__', '-D_LP64', '-I' + MACHINE_INC, '-I' + OB + '/sys', '-isystem', OB + '/include',
        '-idirafter', OB + '/lib/libc/include', '-idirafter', OB + '/lib/libc/hidden', '-idirafter', OB + '/sys/lib/libkern', '-I' + OB + '/lib/libcrypto',
        '-I' + OB + '/lib/libcrypto/bn', '-I' + OB + '/lib/libm/src', '-I' + OB + '/lib/libc/gdtoa',
        '-idirafter', HERE + '/inc2', '-include', HERE + '/prelude.h', '-w']


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=900, **kw)


def sources():
    out = []
    for p in sorted(glob.glob(OB + '/lib/libz/*.c')): out.append(('libz', p))
    for d in ['string', 'stdlib', 'gen', 'stdio', 'net', 'hash']:
        for p in sorted(glob.glob(OB + '/lib/libc/%s/*.c' % d)): out.append(('libc-' + d, p))
    for p in sorted(glob.glob(OB + '/sys/crypto/*.c')): out.append(('sys-crypto', p))
    EXT = [('libc-regex', 'lib/libc/regex'), ('libc-db', 'lib/libc/db/btree'), ('libc-db', 'lib/libc/db/hash'), ('libc-db', 'lib/libc/db/recno'), ('libc-db', 'lib/libc/db/mpool'),
           ('libc-gdtoa', 'lib/libc/gdtoa'), ('libc-time', 'lib/libc/time'), ('libc-crypt', 'lib/libc/crypt'), ('libc-locale', 'lib/libc/locale'), ('libc-quad', 'lib/libc/quad'),
           ('libc-softfloat', 'lib/libc/softfloat'), ('libedit', 'lib/libedit'), ('libcurses', 'lib/libcurses/tinfo'), ('libm', 'lib/libm/src'),
           ('ub-awk', 'usr.bin/awk'), ('ub-lex', 'usr.bin/lex'), ('ub-yacc', 'usr.bin/yacc'), ('ub-sort', 'usr.bin/sort'), ('ub-bc', 'usr.bin/bc'), ('ub-dc', 'usr.bin/dc'), ('ub-diff', 'usr.bin/diff'),
           ('ub-sed', 'usr.bin/sed'), ('ub-grep', 'usr.bin/grep'), ('ub-m4', 'usr.bin/m4'), ('ub-cmp', 'usr.bin/cmp'), ('ub-tsort', 'usr.bin/tsort'),
           ('libcrypto', 'lib/libcrypto/aes'), ('libcrypto', 'lib/libcrypto/bn'), ('libcrypto', 'lib/libcrypto/md5'), ('libcrypto', 'lib/libcrypto/sha'), ('libcrypto', 'lib/libcrypto/des'),
           ('libcrypto', 'lib/libcrypto/bf'), ('libcrypto', 'lib/libcrypto/chacha'), ('libcrypto', 'lib/libcrypto/curve25519'), ('libcrypto', 'lib/libcrypto/rc4')]
    for g, d in EXT:
        for p in sorted(glob.glob(OB + '/' + d + '/*.c')): out.append((g, p))
    for p in sorted(glob.glob(TREE + '/tests/c/*.c')): out.append(('tests-c', p))
    for p in sorted(glob.glob(TREE + '/tests/c-new/*.c')): out.append(('tests-c-new', p))
    for p in sorted(glob.glob(TREE + '/docs/encoding-work/bench/sc/src/*.c')): out.append(('bench-sc', p))
    return out


def preprocess(path, extra, dst):
    if os.path.exists(dst): return None
    r = run(['gcc'] + CPPF + extra + [path])
    if r.returncode: return 'cpp: ' + (r.stderr.strip().split('\n')[0][:150])
    tmp = '%s.%d.%d' % (dst, os.getpid(), threading.get_ident())
    open(tmp, 'w').write(r.stdout)
    os.replace(tmp, dst)          # atomic: programs share sources, and another thread may be reading the file
    return None


def compile_i(side, i, s, extra):
    S = SIDES[side]
    r = run([S['ccom']] + S['args'] + extra + [i, s])
    if r.returncode or not os.path.exists(s) or os.path.getsize(s) == 0:
        if os.path.exists(s): os.unlink(s)
        return 'ccom: ' + (r.stderr.strip().split('\n')[0][:150] or 'rc%d' % r.returncode)
    return None


def hist_of(s):
    h = collections.Counter()
    for line in open(s):
        line = line.split(';')[0].rstrip()
        if not line.strip() or line.lstrip().startswith('.'): continue
        if line[0] not in ' \t':
            m = re.match(r'^[A-Za-z_.$][\w.$]*:\s*(.*)$', line)
            line = m.group(1) if m else ''
        m = re.match(r'^\s*([a-z][a-z0-9.]*)\b', line)
        if m and not line.lstrip().startswith('.'): h[m.group(1)] += 1
    return dict(h)


def relax_text(side, d, n, plain_bytes):
    """text size after ld64 relaxation: the object linked alone against stubs for its undefined symbols"""
    T = SIDES[side]['tools']
    o = f'{d}/{n}.relax.o'; stubs = set()
    for _ in range(5):
        st = f'{d}/{n}.stub.s'
        open(st, 'w').write('\t.text\n\t.globl _start\n_start:\tret\n' + ''.join(f'\t.globl {x}\n{x}:\tret\n' for x in sorted(stubs)))
        run([T + '/as64', '-o', f'{d}/{n}.stub.o', st])
        r = run([T + '/ld64', '--stats', '-o', f'{d}/{n}.x', o, f'{d}/{n}.stub.o'])
        txt = r.stdout + r.stderr
        und = set(re.findall(r'undefined symbol (\S+)', txt))
        if not und:
            m = re.search(r'all sites and paddings: (\d+) -> (\d+) bytes', txt)
            for f in (f'{d}/{n}.stub.s', f'{d}/{n}.stub.o', f'{d}/{n}.x'):
                if os.path.exists(f): os.unlink(f)
            return plain_bytes + int(m.group(2)) - int(m.group(1)) if m else None
        stubs |= und
    return None


def corpus_one(a):
    name, group, path = a
    ipath = f'{W}/i/{name}.i'
    res = dict(name=name, group=group)
    err = preprocess(path, ['-I' + os.path.dirname(path), '-idirafter', os.path.dirname(path) + '/..'], ipath)
    if err: res['fail'] = err; return res
    for side in SIDES:
        d = f'{W}/out/{side}'; s = f'{d}/{name}.s'; r_ = {}
        err = compile_i(side, ipath, s, [])
        if err: r_['fail'] = err; res[side] = r_; continue
        T = SIDES[side]['tools']
        for mode, flag in (('plain', ['--no-relax']), ('relax', [])):
            o = f'{d}/{name}.{mode}.o'
            r = run([T + '/as64'] + flag + ['--stats', '-o', o, s])
            if r.returncode: r_['fail'] = 'as64: ' + (r.stderr.strip().split('\n')[0][:150]); break
            m = re.search(r'(\d+) instructions, (\d+) bytes', r.stdout + r.stderr)
            r_[mode + '_insn'] = int(m.group(1)); r_[mode + '_bytes'] = int(m.group(2))
            if mode == 'plain':
                m = re.search(r'\((\d+) cbCC expanded', r.stdout + r.stderr)
                r_['expanded'] = int(m.group(1)) if m else 0
        if 'fail' not in r_:
            r_['hist'] = hist_of(s)
            r_['relax_text'] = relax_text(side, d, name, r_['plain_bytes'])
        res[side] = r_
        for f in (s, f'{d}/{name}.plain.o', f'{d}/{name}.relax.o'):
            if os.path.exists(f): os.unlink(f)
    os.unlink(ipath)
    return res


def programs():
    P = HERE + '/prog'
    z = ['adler32', 'compress', 'crc32', 'deflate', 'inflate', 'inffast', 'inftrees', 'trees', 'uncompr']
    progs = {
        'zlib': [P + '/zlibd.c', P + '/zutil_stub.c', P + '/stubs.c'] + [OB + '/lib/libz/%s.c' % f for f in z],
        'crypto': [P + '/crypto.c', P + '/stubs.c'] + [OB + '/sys/crypto/%s.c' % f for f in ('md5', 'sha1', 'sha2', 'blf', 'rmd160', 'poly1305')],
        'libc-sort-string': [P + '/libcd.c', P + '/stubs.c'] + [OB + '/lib/libc/stdlib/%s.c' % f for f in ('qsort', 'heapsort', 'bsearch', 'strtol')] +
                            [OB + '/lib/libc/string/%s.c' % f for f in ('strlcat', 'strlcpy', 'strstr', 'strspn', 'strcmp', 'strlen', 'strncmp', 'strpbrk', 'memchr')],
    }
    for g, label in ((TREE + '/docs/encoding-work/bench/sc/src', 'bench-sc'), (TREE + '/tests/c', 'c'), (TREE + '/tests/c-new', 'c-new')):
        for f in sorted(glob.glob(g + '/*.c')):
            progs[label + '/' + os.path.basename(f)[:-2]] = [f]
    return progs


_locks = {}
_locks_guard = threading.Lock()


def obj_of(side, src, d):
    """compile one program source for a side (the preprocessed text is shared; programs share sources, so one thread builds an object at a time); returns (object, error)"""
    n = hashlib.md5(src.encode()).hexdigest()[:8] + '_' + os.path.basename(src)[:-2]
    with _locks_guard: lk = _locks.setdefault((side, n), threading.Lock())
    with lk:
        return obj_of_locked(side, src, d, n)


def obj_of_locked(side, src, d, n):
    o = f'{d}/{n}.o'
    if os.path.exists(o): return o, None
    T = SIDES[side]['tools']
    i = f'{W}/pi/{n}.i'
    err = preprocess(src, ['-I' + os.path.dirname(src)], i)
    if err and not os.path.exists(i): return None, err
    s = f'{d}/{n}.s'
    err = compile_i(side, i, s, INFTREES_FLAGS if src.endswith('inftrees.c') else [])
    if err: return None, err
    r = run([T + '/as64', '-o', o, s])
    if r.returncode: return None, 'as64 ' + r.stderr[:200]
    return o, None


def prog_one(a):
    side, name, srcs = a
    d = f'{W}/runout/{side}'; T = SIDES[side]['tools']
    res = dict(name=name)
    objs = []
    asm = hashlib.md5()
    for s in srcs:
        o, e = obj_of(side, s, d)
        if e: res['fail'] = os.path.basename(s) + ': ' + e; return res
        objs.append(o)
        asm.update(open(o[:-2] + '.s', 'rb').read())
    res['asm'] = asm.hexdigest()
    x = d + '/' + name.replace('/', '_') + '.x'
    r = run([T + '/ld64', '-o', x, f'{d}/crt.o', f'{d}/main.o'] + objs)
    if r.returncode: res['fail'] = 'ld64: ' + (r.stderr + r.stdout)[:300]; return res
    try:
        r = subprocess.run([T + '/sim64'] + ['--timing=' + p for p in PRESETS] + [x], capture_output=True, text=True, timeout=1200)
    except subprocess.TimeoutExpired:
        res['fail'] = 'sim timeout'; return res
    lines = (r.stdout + r.stderr).split('\n')
    res['output'] = ' '.join(l for l in lines if l and not l.startswith('tm ')).strip()[:200]
    res['rc'] = r.returncode
    for l in lines:
        if l.startswith('tm '):
            kv = dict(t.split('=', 1) for t in l[3:].split())
            res[kv['name']] = dict(insns=int(kv['insns']), bytes=int(kv['bytes']), cycles=int(kv['cycles']))
    if 'scalar' not in res: res['fail'] = 'no timing line'
    if os.path.exists(x): os.unlink(x)
    return res


def setup_runtime(side):
    d = f'{W}/runout/{side}'; T = SIDES[side]['tools']; S = SIDES[side]
    r = run([T + '/as64', '-o', d + '/crt.o', HERE + '/run/crt.s'])
    assert r.returncode == 0, r.stderr
    r = run([S['ccom']] + S['args'] + [HERE + '/run/main.c', d + '/main.s'])
    assert r.returncode == 0, r.stderr
    r = run([T + '/as64', '-o', d + '/main.o', d + '/main.s'])
    assert r.returncode == 0, r.stderr


def pct(a, b): return 100.0 * (b - a) / a if a else 0.0


def main():
    for sub in ('i', 'pi', 'inc', 'out/base', 'out/now', 'runout/base', 'runout/now'):
        os.makedirs(f'{W}/{sub}', exist_ok=True)
    if not os.path.lexists(MACHINE_INC + '/machine'): os.symlink(OB + '/sys/arch/amd64/include', MACHINE_INC + '/machine')
    srcs = sources()
    tried_all = len(srcs)
    if A.subset:
        srcs = srcs[::max(1, len(srcs) // A.subset)]
    print('corpus: %d files of %d' % (len(srcs), tried_all), file=sys.stderr)
    items = [(g + '__' + os.path.basename(p)[:-2], g, p) for g, p in srcs]
    with ThreadPoolExecutor(A.jobs) as ex:
        cres = list(ex.map(corpus_one, items))
    ok = [r for r in cres if 'fail' not in r and 'fail' not in r['base'] and 'fail' not in r['now']]
    onlyb = [r for r in cres if 'fail' not in r and 'fail' not in r['base']]
    onlyn = [r for r in cres if 'fail' not in r and 'fail' not in r['now']]
    print('corpus: base %d, now %d, both %d' % (len(onlyb), len(onlyn), len(ok)), file=sys.stderr)
    errs = collections.Counter()
    for r in cres:
        if 'fail' in r: errs['cpp ' + r['fail'][:60]] += 1
        else:
            for side in SIDES:
                if 'fail' in r[side]: errs[side + ' ' + r[side]['fail'][:60]] += 1
    for e, n in errs.most_common(8): print('  %4d  %s' % (n, e), file=sys.stderr)
    for side in SIDES: setup_runtime(side)
    progs = programs()
    pnames = list(progs)
    if A.subset:
        pnames = pnames[::3]
    jobs = [(side, n, progs[n]) for n in pnames for side in SIDES]
    with ThreadPoolExecutor(max(1, A.jobs // 2)) as ex:
        pr = list(ex.map(prog_one, jobs))
    pres = {'base': {}, 'now': {}}
    for (side, n, _), r in zip(jobs, pr): pres[side][n] = r
    runnable = [n for n in pnames if 'fail' not in pres['base'][n] and 'fail' not in pres['now'][n]]
    same = [n for n in runnable if pres['base'][n]['output'] == pres['now'][n]['output'] and pres['base'][n]['rc'] == pres['now'][n]['rc']]
    big = [n for n in runnable if pres['base'][n]['scalar']['insns'] >= 100000]
    failed = {s: [(n, pres[s][n]['fail']) for n in pnames if 'fail' in pres[s][n]] for s in SIDES}
    report(cres, ok, onlyb, onlyn, pnames, runnable, same, big, pres, failed, tried_all)


KIND = collections.OrderedDict([
    ('cmp', lambda m: m in ('cmp', 'cmpb', 'cmpw', 'cmpl')),
    ('tst', lambda m: m in ('tst', 'test')),
    ('flag branch', lambda m: m in set('beq bne bmi bpl bvc bvs bcc bcs bge blt bgt ble bhi blos bhis blo'.split())),
    ('SET (flags)', lambda m: m == 'set'),
    ('setCC (compare into register)', lambda m: re.match(r'^set(eq|ne|lt|ge|gt|le|lo|los|hi|his|cc|cs)$', m) is not None),
    ('FCMP', lambda m: m in ('fcmp', 'fcmp32')),
    ('compare-and-branch (cbCC)', lambda m: re.match(r'^cb[a-z]+$', m) is not None),
    ('FP compare-and-branch (fcbCC)', lambda m: re.match(r'^fcb[a-z0-9]+$', m) is not None),
    ('br/jmp', lambda m: m in ('br', 'jmp')),
])


def kinds(rs, side):
    h = collections.Counter()
    for r in rs: h.update(r[side]['hist'])
    return {k: sum(v for m, v in h.items() if f(m)) for k, f in KIND.items()}, sum(h.values())


def report(cres, ok, onlyb, onlyn, pnames, runnable, same, big, pres, failed, tried_all):
    T = collections.OrderedDict()      # the text file
    L = []                             # the markdown
    p = lambda s='': L.append(s)
    for kv in A.info:
        k, v = kv.split('=', 1); T['pin.' + k] = v
    S = lambda side, f: sum(r[side][f] for r in ok)
    T['corpus.files_listed'] = tried_all
    T['corpus.files_tried'] = len(cres)
    T['corpus.files_base_compiles'] = len(onlyb)
    T['corpus.files_now_compiles'] = len(onlyn)
    T['corpus.files_both'] = len(ok)
    for side in ('base', 'now'):
        T['static.%s.insns' % side] = S(side, 'plain_insn')
        T['static.%s.bytes' % side] = S(side, 'plain_bytes')
        T['static.%s.bytes_relaxed' % side] = sum(r[side]['relax_text'] or 0 for r in ok)
        T['static.%s.cbcc_expanded' % side] = S(side, 'expanded')
    T['static.insns_pct'] = '%+.2f' % pct(T['static.base.insns'], T['static.now.insns'])
    T['static.bytes_pct'] = '%+.2f' % pct(T['static.base.bytes'], T['static.now.bytes'])
    T['static.bytes_relaxed_pct'] = '%+.2f' % pct(T['static.base.bytes_relaxed'], T['static.now.bytes_relaxed'])
    kb, tb = kinds(ok, 'base'); kn, tn = kinds(ok, 'now')
    for k in KIND:
        T['static.kind.base.' + k] = kb[k]; T['static.kind.now.' + k] = kn[k]
    cbb = kb['compare-and-branch (cbCC)']
    den = cbb + kb['cmp'] + kb['tst'] + kb['SET (flags)']
    T['static.base.cb_share_pct'] = '%.0f' % (100.0 * cbb / den) if den else '0'
    T['programs.listed'] = len(pnames)
    T['programs.run_both'] = len(runnable)
    T['programs.output_equal'] = len(same)
    T['programs.big'] = len(big)

    def tot(side, pr, f, ks): return sum(pres[side][n][pr][f] for n in ks)
    for tag, ks in (('all', runnable), ('big', big)):
        for pr in ('scalar', 'dual', 'scalar-c', 'dual-c'):
            for side in ('base', 'now'):
                T['dyn.%s.%s.%s.cycles' % (tag, pr, side)] = tot(side, pr, 'cycles', ks)
            T['dyn.%s.%s.cycles_pct' % (tag, pr)] = '%+.2f' % pct(T['dyn.%s.%s.base.cycles' % (tag, pr)], T['dyn.%s.%s.now.cycles' % (tag, pr)])
        for side in ('base', 'now'):
            T['dyn.%s.%s.insns' % (tag, side)] = tot(side, 'scalar', 'insns', ks)
            T['dyn.%s.%s.bytes_fetched' % (tag, side)] = tot(side, 'scalar', 'bytes', ks)
        T['dyn.%s.insns_pct' % tag] = '%+.2f' % pct(T['dyn.%s.base.insns' % tag], T['dyn.%s.now.insns' % tag])
        T['dyn.%s.bytes_fetched_pct' % tag] = '%+.2f' % pct(T['dyn.%s.base.bytes_fetched' % tag], T['dyn.%s.now.bytes_fetched' % tag])
    # control: programs whose compiled code is the same text on both sides differ in cycles only by the simulator (its timing model and the layout of the linked image)
    ctl = [n for n in runnable if pres['base'][n]['asm'] == pres['now'][n]['asm']]
    T['dyn.control.programs'] = len(ctl)
    for pr in ('scalar', 'dual'):
        a, b = tot('base', pr, 'cycles', ctl), tot('now', pr, 'cycles', ctl)
        T['dyn.control.%s.cycles_pct' % pr] = '%+.2f' % pct(a, b) if ctl else 'none'
    for side in ('base', 'now'):
        T['programs.failed.' + side] = ' '.join(n for n, _ in failed[side]) or 'none'

    def word(s): return 'more' if float(s) > 0 else 'fewer' if float(s) < 0 else 'the same number of'
    def absf(s): return '%.2f' % abs(float(s))
    T['manual.bytes_pct'] = absf(T['static.bytes_pct']); T['manual.bytes_word'] = word(T['static.bytes_pct'])
    T['manual.insns_pct'] = absf(T['dyn.all.insns_pct']); T['manual.insns_word'] = word(T['dyn.all.insns_pct'])
    T['manual.insns_base_million'] = '%.2f' % (T['dyn.all.base.insns'] / 1e6)
    T['manual.insns_now_million'] = '%.2f' % (T['dyn.all.now.insns'] / 1e6)
    cyc = [float(T['dyn.all.%s.cycles_pct' % pr]) for pr in ('scalar', 'dual')]
    T['manual.cycles_low_pct'] = '%.1f' % min(abs(c) for c in cyc); T['manual.cycles_high_pct'] = '%.1f' % max(abs(c) for c in cyc)
    if ctl:
        T['manual.control_scalar_pct'] = absf(T['dyn.control.scalar.cycles_pct']); T['manual.control_dual_pct'] = absf(T['dyn.control.dual.cycles_pct'])
    T['manual.cycles_word'] = 'fewer' if all(c < 0 for c in cyc) else 'more' if all(c > 0 for c in cyc) else 'different'

    p('# The flags measurement, repeated by `tools/measure-flags.sh`'); p()
    p('Generated; do not edit.  The numbers are in `results-final.txt`; the manual cites that file.  "base" is the compiler and tools before the flags were removed, "now" the flag-free ones.'); p()
    p('## Pins'); p()
    for kv in A.info:
        k, v = kv.split('=', 1); p('* %s: %s' % (k, v))
    p()
    p('## Verdict'); p()
    p('| measure | base | now | change |'); p('|---|---:|---:|---:|')
    p('| files compiled by both sides (of %d listed, %d tried) | | | %d |' % (tried_all, len(cres), len(ok)))
    p('| static instructions | %d | %d | %s%% |' % (T['static.base.insns'], T['static.now.insns'], T['static.insns_pct']))
    p('| static bytes (as64 plain) | %d | %d | %s%% |' % (T['static.base.bytes'], T['static.now.bytes'], T['static.bytes_pct']))
    p('| static bytes after ld64 relaxation | %d | %d | %s%% |' % (T['static.base.bytes_relaxed'], T['static.now.bytes_relaxed'], T['static.bytes_relaxed_pct']))
    p('| programs run on both sides (outputs equal) | | | %d (%d) |' % (len(runnable), len(same)))
    p('| instructions executed | %d | %d | %s%% |' % (T['dyn.all.base.insns'], T['dyn.all.now.insns'], T['dyn.all.insns_pct']))
    p('| bytes fetched | %d | %d | %s%% |' % (T['dyn.all.base.bytes_fetched'], T['dyn.all.now.bytes_fetched'], T['dyn.all.bytes_fetched_pct']))
    for pr in ('scalar', 'dual', 'scalar-c', 'dual-c'):
        p('| cycles, %s | %d | %d | %s%% |' % (pr, T['dyn.all.%s.base.cycles' % pr], T['dyn.all.%s.now.cycles' % pr], T['dyn.all.%s.cycles_pct' % pr]))
    p('Control: %d programs have the same compiled code on both sides (the assembly text of their sources is identical); their cycles differ by %s%% (scalar) and %s%% (dual) between the two simulators, which is the change of the timing model and of the linked layout, not of the code.  Read the cycle rows with that in mind; the instruction counts do not have this effect.' % (len(ctl), T['dyn.control.scalar.cycles_pct'], T['dyn.control.dual.cycles_pct']))
    p()
    p('## Static count of each kind of compare, branch and flag instruction (the %d files)' % len(ok)); p()
    p('| kind | base | now |'); p('|---|---:|---:|')
    for k in KIND: p('| %s | %d | %d |' % (k, kb[k], kn[k]))
    p('| all instructions (mnemonic count) | %d | %d |' % (tb, tn)); p()
    groups = collections.OrderedDict()
    for r in ok: groups.setdefault(r['group'], []).append(r)
    p('## By group (plain bytes)'); p()
    p('| group | files | base insns | now insns | % | base bytes | now bytes | % |'); p('|---|---:|---:|---:|---:|---:|---:|---:|')
    for g, rs in groups.items():
        a, b = sum(r['base']['plain_insn'] for r in rs), sum(r['now']['plain_insn'] for r in rs)
        c, d = sum(r['base']['plain_bytes'] for r in rs), sum(r['now']['plain_bytes'] for r in rs)
        p('| %s | %d | %d | %d | %+.2f | %d | %d | %+.2f |' % (g, len(rs), a, b, pct(a, b), c, d, pct(c, d)))
    p()
    p('## Programs'); p()
    p('| program | insns base | insns now | % | bytes fetched base | % | scalar cycles base | % | dual cycles base | % | output |'); p('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|')
    for n in runnable:
        b, c = pres['base'][n], pres['now'][n]
        p('| %s%s | %d | %d | %+.2f | %d | %+.2f | %d | %+.2f | %d | %+.2f | %s |' % (n, '' if n in big else ' (small)', b['scalar']['insns'], c['scalar']['insns'], pct(b['scalar']['insns'], c['scalar']['insns']),
          b['scalar']['bytes'], pct(b['scalar']['bytes'], c['scalar']['bytes']), b['scalar']['cycles'], pct(b['scalar']['cycles'], c['scalar']['cycles']),
          b['dual']['cycles'], pct(b['dual']['cycles'], c['dual']['cycles']), 'equal' if n in same else 'DIFFERENT'))
    p()
    p('Over the %d programs of 100,000 instructions or more: instructions %s%%, cycles scalar %s%%, dual %s%%.' % (len(big), T['dyn.big.insns_pct'], T['dyn.big.scalar.cycles_pct'], T['dyn.big.dual.cycles_pct'])); p()
    if any(failed[s] for s in failed):
        p('Programs that did not build or run: ' + '; '.join('%s: %s' % (s, ', '.join('%s (%s)' % (n, re.sub(r'/[0-9a-f]{8}_', '/', e.replace(W, '$WORK'))[:100]) for n, e in failed[s]) or 'none') for s in failed)); p()
    with open(A.out + '.txt', 'w') as f:
        f.write('# Result of tools/measure-flags.sh (generated; do not edit).  key = value; the manual cites this file (tools/mkmanual.py, @@MEASURE:name@@).\n')
        for k, v in T.items(): f.write('%s = %s\n' % (k, v))
    open(A.out + '.md', 'w').write('\n'.join(L) + '\n')
    print(open(A.out + '.txt').read())


main()
