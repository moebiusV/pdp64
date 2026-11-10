#!/usr/bin/env python3
"""ref-static.py -- static size of the corpus compiled by GCC or clang to an object: for each preprocessed file, `CMD -c -x c -o x.o file.i`, counted with objstat.py.
usage: ref-static.py INDIR OUTDIR [-j N] -- compiler and flags...        writes OUTDIR/static.csv (columns as pcc-static.py)"""
import os, sys, subprocess, tempfile, concurrent.futures as cf
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import objstat
indir, out = sys.argv[1:3]
rest = sys.argv[3:]; jobs = 2
if rest[:1] == ['-j']: jobs = int(rest[1]); rest = rest[2:]
assert rest[:1] == ['--']; cmd = rest[1:]
os.makedirs(out, exist_ok=True)
def one(n):
    with tempfile.TemporaryDirectory() as w:
        o = w + '/x.o'
        try:
            p = subprocess.run(cmd + ['-c', '-x', 'c', '-o', o, '%s/%s.i' % (indir, n)], capture_output=True, text=True, errors='replace', timeout=300)
        except subprocess.TimeoutExpired:
            return [n, 'fail', 0, 0, 0, 0, 0, 0, 0, 'timeout']
        if p.returncode or not os.path.exists(o):
            m = [x for x in (p.stderr or p.stdout).strip().split('\n') if 'error' in x]
            return [n, 'fail', 0, 0, 0, 0, 0, 0, 0, (m[0] if m else 'exit %d' % p.returncode)[:150].replace(',', ';')]
        i, b, t, d, pn, pb, nc = objstat.count_obj(o)
        return [n, 'ok', i, b, t, d, pn, pb, nc, '']
names = sorted(f[:-2] for f in os.listdir(indir) if f.endswith('.i'))
with cf.ThreadPoolExecutor(jobs) as ex, open(out + '/static.csv', 'w') as f:
    f.write('file,status,ins,ibytes,text,data_in_text,pad_ins,pad_bytes,calls,msg\n')
    for r in ex.map(one, names):
        f.write(','.join(str(x) for x in r) + '\n')
