#!/usr/bin/env python3
"""pcc-static.py -- static size of the corpus compiled by a pcc back end: ccom, assemble with the host assembler the project uses for that
architecture (tools/corpus.py: clang's for aarch64/mips64/riscv64, gcc -m64/-m32 for amd64/i386), count with objstat.py.
usage: pcc-static.py INDIR OUTDIR ARCH CCOM [-j N] -- ccom flags...      writes OUTDIR/static.csv and OUTDIR/NNN.err
columns: file,status,ins,ibytes,text,data_in_text,pad_ins,pad_bytes,calls,msg"""
import os, sys, subprocess, tempfile, concurrent.futures as cf
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import objstat
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TOOLCHAIN = os.environ.get('TOOLCHAIN', os.path.join(os.path.dirname(REPO), 'facetlang', 'pdp11', 'v7unix-toolchain')) + '/tools'
sys.path.insert(0, TOOLCHAIN)
from corpus import ARCH
indir, out, arch, ccom = sys.argv[1:5]
rest = sys.argv[5:]; jobs = 8
if rest[:1] == ['-j']: jobs = int(rest[1]); rest = rest[2:]
assert rest[:1] == ['--']; flags = rest[1:]
asm = ARCH[arch]['asm']
os.makedirs(out, exist_ok=True)
def one(n):
    with tempfile.TemporaryDirectory() as w:
        s, o = w + '/x.s', w + '/x.o'
        try:
            p = subprocess.run([ccom] + flags + ['%s/%s.i' % (indir, n), s], capture_output=True, text=True, errors='replace', timeout=120)
        except subprocess.TimeoutExpired:
            return [n, 'fail', 0, 0, 0, 0, 0, 0, 0, 'ccom timeout']
        if p.returncode or not os.path.exists(s) or os.path.getsize(s) == 0:
            m = [x for x in (p.stderr or p.stdout).strip().split('\n') if x.strip() and 'warning' not in x]
            open('%s/%s.err' % (out, n), 'w').write(p.stderr + p.stdout)
            return [n, 'fail', 0, 0, 0, 0, 0, 0, 0, 'ccom: ' + (m[0] if m else 'exit %d' % p.returncode)[:150].replace(',', ';')]
        q = subprocess.run(asm + ['-o', o, s], capture_output=True, text=True, errors='replace')
        if q.returncode:
            open('%s/%s.err' % (out, n), 'w').write(q.stderr + q.stdout)
            return [n, 'fail', 0, 0, 0, 0, 0, 0, 0, 'as: ' + (q.stderr.strip().split('\n') or [''])[0][:150].replace(',', ';')]
        i, b, t, d, pn, pb, nc = objstat.count_obj(o)
        return [n, 'ok', i, b, t, d, pn, pb, nc, '']
names = sorted(f[:-2] for f in os.listdir(indir) if f.endswith('.i'))
with cf.ThreadPoolExecutor(jobs) as ex, open(out + '/static.csv', 'w') as f:
    f.write('file,status,ins,ibytes,text,data_in_text,pad_ins,pad_bytes,calls,msg\n')
    for r in ex.map(one, names):
        f.write(','.join(str(x) for x in r) + '\n')
