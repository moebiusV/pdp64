#!/usr/bin/env python3
"""proof.py OUTDIR : buildabook's rendered Markdown (raw-typst comments removed) against what the old resolver (HEAD tools/manual/bookrefs.py) makes of the
original source.  Prints, per file, equal or the differing lines; then the per-name check: every definition's computed number against its old number
(names.tsv), and every citation (all {{s:..|=name}} tokens) against the old text."""
import os, re, sys, csv, difflib
O = sys.argv[1]
PDP = '/tmp/nest/pdp'
sys.path.insert(0, PDP + '/tools/manual')
import bookrefs
book = bookrefs.Book(PDP + '/book/outline.txt', PDP + '/book/sources.txt')
SRC = PDP + '/docs/manual-src'
files = {fn: open(os.path.join(SRC, fn), encoding='utf-8').read() for fn in book.file_uuid if os.path.exists(os.path.join(SRC, fn))}
old = book.resolve_all(files)
bad = 0
for fn in files:
    new = open(os.path.join(O, 'bk/rendered', fn), encoding='utf-8').read()
    new = re.sub(r'<!--raw-typst [^\n]*-->\n', '', new)
    if new == old[fn]:
        print('equal      %s' % fn)
        continue
    d = [l for l in difflib.unified_diff(old[fn].split('\n'), new.split('\n'), 'old', 'buildabook', n=0, lineterm='') if not l.startswith(('---', '+++', '@@'))]
    bad += 1
    print('DIFFERENT  %s: %d differing lines' % (fn, len(d)))
    for l in d[:int(os.environ.get('SHOW', '6'))]:
        print('    ' + l[:150])
# per-name proof: the number_map.csv number of every row against the old number
rows = {r['uuid']: r for r in csv.DictReader(open(os.path.join(O, 'bk/number_map.csv')))}
n = ok = 0
for line in open(os.path.join(O, 'names.tsv')):
    u, kind, name, num, fn = line.rstrip('\n').split('\t')
    n += 1
    got = rows[u]['rendered'].lstrip('§')
    if got == num:
        ok += 1
    else:
        print('NUMBER  %s %s: old %s, buildabook %s' % (kind, name, num, got))
print('definitions: %d, equal to the old number: %d' % (n, ok))
# citation count
srcs = [open(os.path.join(O, 'src', fn), encoding='utf-8').read() for fn in files]
cit = sum(len(re.findall(r'\{\{s:id\d+\|p\|=', t)) for t in srcs)
print('s tokens in the converted source: %d (definitions %d)' % (cit, n))
sys.exit(1 if bad or ok != n else 0)
