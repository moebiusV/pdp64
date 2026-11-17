#!/usr/bin/env python3
"""la-mnemonics.py -- the instructions a compiler uses on the corpus, by mnemonic, from its assembly output.

usage: la-mnemonics.py INDIR OUT.csv [-j N] -- compiler and flags...

For each preprocessed file INDIR/NNN.i: `CMD -S -x c -o - file.i`; every line of the output that begins with white space and a name that does not
begin with a dot is an instruction (labels, directives and comments are not).  Writes OUT.csv: mnemonic,count, most used first, and prints the
total.  Used for the LoongArch rows (what `alsl`, `bstrpick`, `ldx`, `bgeu`, `break` and the bound-check instructions count to).
"""
import os, re, sys, subprocess, collections, concurrent.futures as cf

indir, out = sys.argv[1:3]
rest = sys.argv[3:]
jobs = 2
if rest[:1] == ['-j']:
    jobs = int(rest[1]); rest = rest[2:]
assert rest[:1] == ['--']
cmd = rest[1:]
INSN = re.compile(r'^\s+([a-z][a-z0-9_.]*)\b')


def one(n):
    p = subprocess.run(cmd + ['-S', '-x', 'c', '-o', '-', '%s/%s.i' % (indir, n)], capture_output=True, text=True, errors='replace', timeout=300)
    c = collections.Counter()
    if p.returncode:
        return None, c
    for ln in p.stdout.split('\n'):
        m = INSN.match(ln)
        if m and not ln.lstrip().startswith(('.', '#')):
            c[m.group(1)] += 1
    return n, c


names = sorted(f[:-2] for f in os.listdir(indir) if f.endswith('.i'))
tot = collections.Counter()
ok = 0
with cf.ThreadPoolExecutor(jobs) as ex:
    for n, c in ex.map(one, names):
        if n is not None:
            ok += 1
            tot.update(c)
with open(out, 'w') as f:
    f.write('mnemonic,count\n')
    for k, v in tot.most_common():
        f.write('%s,%d\n' % (k, v))
print('%d files, %d instructions, %d mnemonics' % (ok, sum(tot.values()), len(tot)))
