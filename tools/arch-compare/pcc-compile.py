#!/usr/bin/env python3
"""pcc-compile.py -- compile the preprocessed corpus (prep.py output) with a pcc ccom.

usage: pcc-compile.py INDIR OUTDIR CCOM [-j N] -- ccom flags...
Writes OUTDIR/NNN.s, OUTDIR/NNN.err for failures and OUTDIR/status.tsv (NNN, ok|fail|timeout, first error line).
"""
import os, sys, subprocess, concurrent.futures as cf
indir, out, ccom = sys.argv[1:4]
rest = sys.argv[4:]
jobs = 8
if rest[:1] == ['-j']:
    jobs = int(rest[1]); rest = rest[2:]
assert rest[:1] == ['--']
flags = rest[1:]
os.makedirs(out, exist_ok=True)
def one(n):
    i = '%s/%s.i' % (indir, n); s = '%s/%s.s' % (out, n)
    try:
        r = subprocess.run([ccom] + flags + [i, s], capture_output=True, text=True, errors='replace', timeout=120)
    except subprocess.TimeoutExpired:
        return n, 'timeout', ''
    if r.returncode or not os.path.exists(s) or os.path.getsize(s) == 0:
        msg = (r.stderr + r.stdout).strip()
        open('%s/%s.err' % (out, n), 'w').write(msg)
        if os.path.exists(s): os.remove(s)
        lines = [l for l in msg.split('\n') if l.strip()]
        return n, 'fail', (lines[0] if lines else 'exit %d' % r.returncode)[:200]
    return n, 'ok', ''
names = sorted(f[:-2] for f in os.listdir(indir) if f.endswith('.i'))
with cf.ThreadPoolExecutor(jobs) as ex, open(out + '/status.tsv', 'w') as st:
    for n, s, m in ex.map(one, names):
        st.write('%s\t%s\t%s\n' % (n, s, m))
