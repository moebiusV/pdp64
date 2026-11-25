#!/usr/bin/env python3
"""convert.py -- port the pdp64 manual-src from {{#name}} / {{r:name}} to buildabook nested sections.

  python3 convert.py PDPDIR OUTDIR [--files f1,f2,...]

Reads PDPDIR/docs/manual-src/*.md, PDPDIR/book/outline.txt, PDPDIR/book/sources.txt (the HEAD state, via the old tools/manual/bookrefs.py for the
OLD numbers), writes in OUTDIR:
  outline.txt     the old outline with, under each chapter/appendix/front matter that has names, a block of rows
                  (sections s1, statements and numbered subsections s2, figures s1 after `s:count:1`)
  src/*.md        the source with {{#name}} -> {{s:idNNNNN|=name}}, {{r:name}} -> the same token, in citations
  names.tsv       uuid TAB kind TAB name TAB old-number TAB file
"""
import os, re, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__))))
PDP, OUT = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.join(PDP, 'tools', 'manual'))
import bookrefs
SRC = os.path.join(PDP, 'docs', 'manual-src')
book = bookrefs.Book(os.path.join(PDP, 'book', 'outline.txt'), os.path.join(PDP, 'book', 'sources.txt'))
order = [p for p in book.file_uuid]                       # book order of the files that are chapters/appendices/front matter
files = {fn: open(os.path.join(SRC, fn), encoding='utf-8').read() for fn in order if os.path.exists(os.path.join(SRC, fn))}
book.number(files)
defs = book.defs                                           # name -> dict(kind, num, file, line, heading)

# ---- ids: sequential in book order, from id10001 (the outline's own ids are all below 10000)
ids, nxt = {}, 10001
bykind = {}
for fn in files:
    ds = sorted((d['line'], n) for n, d in defs.items() if d['file'] == fn)
    for _, n in ds:
        ids[n] = 'id%05d' % nxt
        nxt += 1
PF = os.environ.get('PFLAG', '|p')
tok = lambda n: '{{s:%s%s|=%s}}' % (ids[n], PF, n)

# ---- source rewrite
def rewrite(text):
    out = []
    for line in text.split('\n'):
        m = re.match(r'^(#{2,3}) \{\{#(%s)\}\}(.*)$' % bookrefs.NAME, line)
        if m:
            line = '%s %s%s' % (m.group(1), tok(m.group(2)), m.group(3))
        else:
            m = re.match(r'^\*\*\{\{#(%s)\}\}\*\*(.*)$' % bookrefs.NAME, line)
            if m:
                line = '**%s**%s' % (tok(m.group(1)), m.group(2))
            else:
                m = re.match(r'^!\[\{\{#(%s)\}\}(.*)$' % bookrefs.NAME, line)
                if m:
                    line = '![%s' % m.group(2)                   # the figure has no marker in the text: its outline row is tied to the image path
        out.append(line)
    t = '\n'.join(out)
    t = bookrefs.ordinals(t)                              # {{n}}. lists: no buildabook counterpart; written out as 1. 2. 3. (the proof only)
    t = re.sub(r'\{\{u:(%s)\}\}' % bookrefs.NAME, lambda m: book.anchor(m.group(1)), t)     # the link target: no buildabook counterpart; the old literal (1 use)
    t = re.sub(r'\{\{r:(%s)\}\}' % bookrefs.NAME, lambda m: tok(m.group(1)) , t)
    return t
os.makedirs(os.path.join(OUT, 'src'), exist_ok=True)
for fn, t in files.items():
    open(os.path.join(OUT, 'src', fn), 'w', encoding='utf-8').write(rewrite(t))

# ---- the outline
rows = {}      # file -> list of lines
names = []
for fn, text in files.items():
    ds = sorted(((d['line'], n, d) for n, d in defs.items() if d['file'] == fn))
    if not ds: continue
    L = ['# >>> names %s' % fn, 's:root:chapter']
    figs = []
    for _, n, d in ds:
        if d['kind'] == 'section':
            title = re.sub(r'^#+ ', '', d['heading']); title = re.sub(r'\{\{#[^}]*\}\}\s*', '', title).strip()
            L.append('s1:%s  %s' % (ids[n], title))
        elif d['kind'] == 'item':
            L.append('s2:%s  %s' % (ids[n], n))
        else:
            path = re.search(r'\]\((figures/[^)?]*)', d['heading']).group(1)
            figs.append('s1:%s  %s' % (ids[n], path))
        names.append('%s\t%s\t%s\t%s\t%s' % (ids[n], d['kind'], n, d['num'], fn))
    if figs:
        L.append('s:count:1')
        L += figs
    L.append('s:root:section')
    L.append('# <<< names %s' % fn)
    rows[fn] = L
res = []
uuid2file = book.file_uuid
file_of = {u: f for f, u in uuid2file.items()}
for line in open(os.path.join(PDP, 'book', 'outline.txt'), encoding='utf-8'):
    line = line.rstrip('\n')
    res.append(line)
    m = re.match(r'^[cna]:(id\d{5})\b', line)
    if m and file_of.get(m.group(1)) in rows:
        res += rows[file_of[m.group(1)]]
open(os.path.join(OUT, 'outline.txt'), 'w', encoding='utf-8').write('\n'.join(res) + '\n')
open(os.path.join(OUT, 'names.tsv'), 'w').write('\n'.join(names) + '\n')
print('%d names -> %d rows (%d sections, %d statements/items, %d figures)' % (len(names), len(names),
      sum(1 for d in defs.values() if d['kind'] == 'section'), sum(1 for d in defs.values() if d['kind'] == 'item'), sum(1 for d in defs.values() if d['kind'] == 'figure')))
