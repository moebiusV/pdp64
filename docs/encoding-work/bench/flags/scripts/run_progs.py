#!/usr/bin/env python3
# run_progs.py LABEL pcc CCOM [extra ccom flags via CCOM_EXTRA, env as for corpus.py] | run_progs.py LABEL llvm
# compile each program (its sources + a driver), link with the crt, run on sim64 with the timing model, write out/LABEL.run.json
import os, sys, subprocess, glob, json, re, hashlib
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, '/tmp/flags-work')
import corpus
from corpus import W, OB, AS, PD, LLC, CPPF, CLANGF, run
B = PD + '/build'
SIM = B + '/sim64'; LD = B + '/ld64'
PRESETS = ['name=scalar,iw=1,W=8,N=32', 'name=dual,iw=2,W=16,N=48,dq=6,btb=64',
           'name=scalar-c,iw=1,W=8,N=32,ic=1,dc=1', 'name=dual-c,iw=2,W=16,N=48,dq=6,btb=64,ic=1,dc=1']
INFTREES_FLAGS = ['-xno-temps']       # pcc cannot compile inftrees.c otherwise (a baseline compiler error): used for both variants
P = W + '/prog'
def programs():
    z = ['adler32', 'compress', 'crc32', 'deflate', 'inflate', 'inffast', 'inftrees', 'trees', 'uncompr']
    progs = {
        'zlib': [P + '/zlibd.c', P + '/zutil_stub.c', P + '/stubs.c'] + [OB + '/lib/libz/%s.c' % f for f in z],
        'crypto': [P + '/crypto.c', P + '/stubs.c'] + [OB + '/sys/crypto/%s.c' % f for f in ('md5', 'sha1', 'sha2', 'blf', 'rmd160', 'poly1305')],
        'libc-sort-string': [P + '/libcd.c', P + '/stubs.c'] + [OB + '/lib/libc/stdlib/%s.c' % f for f in ('qsort', 'heapsort', 'bsearch', 'strtol')] +
                            [OB + '/lib/libc/string/%s.c' % f for f in ('strlcat', 'strlcpy', 'strstr', 'strspn', 'strcmp', 'strlen', 'strncmp', 'strpbrk', 'memchr')],
    }
    for g in ('/home/matthew/claude/pdp64/docs/encoding-work/bench/sc/src', PD + '/tests/c', PD + '/tests/c-new'):
        for f in sorted(glob.glob(g + '/*.c')):
            progs[os.path.basename(os.path.dirname(f)) .replace('src', 'bench-sc') + '/' + os.path.basename(f)[:-2]] = [f]
    return progs

def compile_one(label, kind, ccom, src, d):
    n = hashlib.md5(src.encode()).hexdigest()[:8] + '_' + os.path.basename(src)[:-2]
    s = d + '/' + n + '.s'; o = d + '/' + n + '.o'
    if not os.path.exists(o):
        if kind == 'pcc':
            r = run(['gcc'] + CPPF + ['-I' + os.path.dirname(src), src])
            if r.returncode: return None, 'cpp ' + r.stderr[:200]
            i = d + '/' + n + '.i'; open(i, 'w').write(r.stdout)
            extra = corpus.EXTRA + (INFTREES_FLAGS if src.endswith('inftrees.c') else [])
            r = run([ccom, '-m', 'pdp64/32'] + extra + [i, s], env=corpus.ENV)
            if r.returncode or not os.path.exists(s): return None, 'ccom ' + r.stderr[:200]
        else:
            ll = d + '/' + n + '.ll'
            r = run(['clang'] + CLANGF + ['-I' + os.path.dirname(src), src, '-o', ll])
            if r.returncode: return None, 'clang ' + r.stderr[:200]
            t = open(ll).read()
            t = re.sub(r'^target (datalayout|triple) = .*\n', '', t, flags=re.M)
            t = re.sub(r' "(target-cpu|target-features|tune-cpu)"="[^"]*"', '', t)
            open(ll, 'w').write(t)
            r = run([LLC, '-mtriple=pdp64-unknown-elf', '-O2', ll, '-o', s])
            if r.returncode: return None, 'llc ' + r.stderr[:200]
        r = run([AS, '-o', o, s])
        if r.returncode: return None, 'as64 ' + r.stderr[:200]
    return o, None

def one(a):
    label, kind, ccom, name, srcs = a
    d = W + '/runout/' + label
    res = dict(name=name)
    objs = []
    for s in srcs:
        o, e = compile_one(label, kind, ccom, s, d)
        if e: res['fail'] = os.path.basename(s) + ': ' + e; return res
        objs.append(o)
    x = d + '/' + name.replace('/', '_') + '.x'
    r = run([LD, '-o', x, W + '/run/crt.o', W + '/run/main.o'] + objs)
    if r.returncode: res['fail'] = 'ld64: ' + (r.stderr + r.stdout)[:300]; return res
    cmd = [SIM] + ['--timing=' + p for p in PRESETS] + [x]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    except subprocess.TimeoutExpired:
        res['fail'] = 'sim timeout'; return res
    lines = (r.stdout + r.stderr).split('\n')
    res['output'] = ' '.join(l for l in lines if l and not l.startswith('tm ')).strip()[:200]
    res['rc'] = r.returncode
    for l in lines:
        if l.startswith('tm '):
            kv = dict(t.split('=', 1) for t in l[3:].split())
            res[kv['name']] = dict(insns=int(kv['insns']), bytes=int(kv['bytes']), cycles=int(kv['cycles']), branches=int(kv['branches']), cond=int(kv['cond']), mispred=int(kv['mispred']))
    # static size of the program's own objects
    return res

if __name__ == '__main__':
    label, kind = sys.argv[1], sys.argv[2]
    ccom = sys.argv[3] if kind == 'pcc' else None
    os.makedirs(W + '/runout/' + label, exist_ok=True)
    progs = programs()
    with ThreadPoolExecutor(8) as ex:
        results = list(ex.map(one, [(label, kind, ccom, n, s) for n, s in progs.items()]))
    json.dump(results, open(W + '/out/' + label + '.run.json', 'w'), indent=1)
    ok = [r for r in results if 'fail' not in r]
    print(label, 'programs ok', len(ok), 'of', len(results))
    for r in results:
        if 'fail' in r: print('  FAIL', r['name'], r['fail'][:150])
