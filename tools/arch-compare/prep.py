#!/usr/bin/env python3
"""prep.py -- preprocess the fair corpus (fair.txt: "corpus<TAB>path relative to the corpora tree (ROOT of corpus.py, in the toolchain repository)") for an architecture.

usage: prep.py ARCH OUTDIR [-j N]       ARCH = aarch64 (the text pdp64 gets) or riscv64

Exactly the preprocessing of tools/pdp64size.py / corpus.py (gcc -E -P -undef -nostdinc -std=gnu99, the architecture's musl headers
under <corpora>/sysroot/<arch>/include, the corpus's -I and -D); per architecture only the arch defines differ.
Writes OUTDIR/NNN.i and OUTDIR/index.tsv (NNN, corpus, source).  corpus.py comes from the v7unix-toolchain repository (TOOLCHAIN=).
"""
import os, sys, concurrent.futures as cf
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TOOLCHAIN = os.environ.get('TOOLCHAIN', os.path.join(os.path.dirname(REPO), 'facetlang', 'pdp11', 'v7unix-toolchain')) + '/tools'
sys.path.insert(0, TOOLCHAIN)
import corpus
from corpus import ROOT, ARCH, CORPORA, run
HERE = os.path.dirname(os.path.abspath(__file__))
arch, out = sys.argv[1], sys.argv[2]
jobs = int(sys.argv[4]) if len(sys.argv) > 4 else 8
a = ARCH[arch]

def pre(item):
    n, corp, src = item
    c = CORPORA[corp]
    incs = []
    for i in c['inc']:
        incs += ['-I', os.path.join(ROOT, i)]
    incs += ['-I', os.path.dirname(src)]
    sysinc = os.path.join(ROOT, 'sysroot', a['musl'], 'include')
    std = ['-std=gnu99', '-D__STDC_VERSION__=199901L', '-D__STDC_HOSTED__=1']
    r = run(['gcc', '-E', '-P', '-undef', '-nostdinc'] + std + a['cpp'] + c['defs'] + incs + ['-isystem', sysinc, src])
    if r.returncode:
        return n, corp, src, 'cpp: ' + r.stderr.strip().split('\n')[0][:150]
    open('%s/%03d.i' % (out, n), 'w').write(r.stdout)
    return n, corp, src, ''

os.makedirs(out, exist_ok=True)
items = []
for n, l in enumerate(open(os.path.join(HERE, 'fair.txt'))):
    corp, rel = l.rstrip('\n').split('\t')
    items.append((n, corp, os.path.join(ROOT, rel)))
with cf.ThreadPoolExecutor(jobs) as ex, open(out + '/index.tsv', 'w') as ix:
    for n, corp, src, err in ex.map(pre, items):
        ix.write('%03d\t%s\t%s\t%s\n' % (n, corp, src.replace(ROOT + '/', ''), err))
