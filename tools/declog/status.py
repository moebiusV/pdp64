#!/usr/bin/env python3
"""status.py PROJECT TITLE LEDGERDIR OUT.md [REPO_NOTE]

Assembles a project's status ledger (the ledger agents' Markdown, one file per chain group) into one document: what is left
to do and what is left in the air first, then what was rejected, then what is done, then the places where the current docs or
code differ from the author's decisions.  Single-line points.  Input blocks start with "### <subject> (<category>)" and have a
"- Status: DONE|TO DO|REJECTED|IN THE AIR - ..." line; "## Summary" sections of the parts are dropped and recomputed.
"""
import re, collections, glob, os, re, sys

project, title, ldir, out = sys.argv[1:5]
REGLINK = {'pdp64': 'decision-register.md', 'imp72': 'decision-register.md', 'hbnf': 'decision-register.md'}.get(project, 'decision-register.md')
REGISTER = os.path.exists(os.path.join(os.path.dirname(os.path.abspath(ldir.rstrip('/'))), 'id-map.json'))
note = sys.argv[5] if len(sys.argv) > 5 else ''
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from part1 import esc
import json as _j
_base = os.path.dirname(os.path.abspath(ldir.rstrip('/')))
if os.path.exists(os.path.join(_base, 'id-map.json')):
    import regids, register
    _IDX = regids.load_index(project)
    _CANON = {k: int(v[1:]) for k, v in _j.load(open(os.path.join(_base, 'id-map.json')))['canon'].items()}
    rid = lambda t: register.replace_ids(t, _IDX, _CANON)
else:
    rid = lambda t: t

blocks = []
for f in sorted(glob.glob(os.path.join(ldir, '*.md')), key=lambda p: (len(os.path.basename(p)), p)):
    cur = None
    for line in open(f):
        line = line.rstrip('\n')
        if line.startswith('## Summary'):
            cur = None; continue
        if line.startswith('### '):
            cur = [line[4:].strip(), []]; blocks.append(cur)
        elif line.startswith('## ') and not line.startswith('### '):
            cur = None
        elif cur is not None and line.strip():
            cur[1].append(line)
CANON = {}
_cf = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'docs', 'decision-log', 'data', 'shared', 'precedent-canon.json')
if os.path.exists(_cf):
    import json as _json
    CANON = _json.load(open(_cf))
canon = lambda n: CANON.get(n.strip(), n.strip())
RAT = {}
NONE = set()
rdir = os.path.join(os.path.dirname(os.path.abspath(ldir.rstrip('/'))), 'rationale')
if os.path.isdir(rdir):
    import json
    for f in sorted(glob.glob(os.path.join(rdir, '*.json'))):
        for r in json.load(open(f)):
            RAT[r['subject']] = r
    nf = os.path.join(os.path.dirname(os.path.abspath(ldir.rstrip('/'))), 'rationale-none.json')
    if os.path.exists(nf):
        NONE = set(json.load(open(nf)))
STAT = ['TO DO', 'IN THE AIR', 'REJECTED', 'DONE']
LABEL = {'TO DO': 'Left to do', 'IN THE AIR': 'Left in the air', 'REJECTED': 'Rejected or replaced', 'DONE': 'Done'}
HEAD = {'TO DO': 'Decided, and not yet in the current code or docs (or only partly).',
        'IN THE AIR': 'Only ideas, open questions, conflicting decisions, or points the record and the repository do not settle.',
        'REJECTED': 'Rejected, reversed, or replaced by a later decision (the later one has precedence).',
        'DONE': 'Implemented in the current code or stated in the current docs, with the evidence.'}


def status_of(lines):
    for l in lines:
        m = re.match(r'^- Status:\s*(TO DO|IN THE AIR|REJECTED|DONE)', l)
        if m:
            return m.group(1)
    return 'IN THE AIR'


by = collections.OrderedDict((s, []) for s in STAT)
for name, lines in blocks:
    by[status_of(lines)].append((name, lines))
n = len(blocks)
differs = [(name, l) for name, lines in blocks for l in lines if l.startswith('- Doc differs')]


def cat_of(name):
    m = re.search(r'\(([^()]*)\)\s*$', name)
    return m.group(1) if m else ''


def slug(s, seen):
    s = re.sub(r'[^\w\s-]', '', s.lower()).strip()
    s = re.sub(r'\s+', '-', s)
    k = seen[s]; seen[s] += 1
    return s if k == 0 else '%s-%d' % (s, k)


L = ['# ' + title, '', '## About this ledger', '',
     '- What it is: for each design and implementation choice the author made about %s over time, where it stands now against the current docs and code: what is done, what is left to do, what was rejected, and what is left in the air.' % project,
     '- Precedence (the author\'s rule): more recent decisions have greater precedence; each subject\'s status follows its latest standing line.',
     '- Each subject: `Status`, `Decided` (the latest standing line with its source `[R<n>]`, a row of the decision register), `Evidence` (file, line, quote or commit) or `not found: searched ...`, `Doc differs` where a doc or code says something else, `Left` for what remains.',
     '- The decision register: each of the author\'s messages cited here is a numbered row [R<n>] of the append-only [decision register](%s) (the date, the kind, his words, the subjects, and what a later row replaced); numbers are never reused, a replaced row points forward.' % REGLINK,
     '- Checked, not guessed: a status of DONE needs evidence; what could not be checked is IN THE AIR and says why.',
     '- `Rationale` is why he chose it, in his own words; `Precedent` is a system, language, standard or design named as a referent, with whether his choice follows it (chosen), he turned it down (rejected) or it was only compared (considered), and who named it (the author, or the assistant and he accepted it or did not take it up). Only what the messages say: nothing is added from outside. The precedents are indexed by name near the end.',
     '- The chains behind it are in the decision log of the same project; the evidence is as of the repositories read on 2026-11-10.']
if note:
    L.append('- ' + note)
L += ['', '## Contents', '']
seen = collections.Counter(); slug('About this ledger', seen); slug('Contents', seen)
toc = []
secs = [('Summary', 'summary')]
slug('Summary', seen)
L += ['- [Summary](#summary)']
heads = []
for s in STAT:
    h = '%s (%d)' % (LABEL[s], len(by[s]))
    heads.append(h)
    L.append('- [%s](#%s)' % (h, slug(h, seen)))
slug('Precedents, by name', seen)
L.append('- [Precedents, by name](#precedents-by-name)')
_ap = os.path.join(os.path.dirname(os.path.abspath(ldir.rstrip('/'))), 'oq-appendix.md')
APP = rid(open(_ap).read()) if os.path.exists(_ap) else ''
L.append('- [Where the current docs or code differ from the decisions (%d)](#%s)' % (len(differs), slug('Where the current docs or code differ from the decisions (%d)' % len(differs), seen)))
if APP:
    for h in [re.sub(r'^#+ ', '', l) for l in APP.split('\n') if re.match(r'#{1,3} ', l)]:
        L.append('- [%s](#%s)' % (h, slug(h, seen)))
L += ['', '# Summary', '']
for s in STAT:
    L.append('- %s: %d of %d subjects' % (LABEL[s], len(by[s]), n))
cats = collections.Counter(cat_of(name) for name, _ in blocks)
L.append('')
for s in STAT:
    L.append('# %s (%d)' % (LABEL[s], len(by[s])))
    L += ['', '- ' + HEAD[s], '']
    cur = None
    for name, lines in sorted(by[s], key=lambda b: (cat_of(b[0]), b[0])):
        c = cat_of(name)
        if c != cur:
            L += ['## ' + esc(c or 'Other'), '']; cur = c
        L.append('### ' + esc(re.sub(r'\s*\([^()]*\)\s*$', '', name)))
        extra = []
        r = RAT.get(name)
        if r:
            for x in r.get('rationale', [])[:4]:
                extra.append('- Rationale: %s %s' % (esc(rid(x['text'])), esc(rid(x.get('id', '')))))
            for x in r.get('precedents', [])[:6]:
                extra.append('- Precedent: %s (%s; named by %s): %s %s' % (esc(canon(x['name'])), x['stance'], x['named_by'], esc(rid(x.get('note', ''))), esc(rid(x.get('id', '')))))
            if not r.get('rationale') and not r.get('precedents'):
                extra.append('- Rationale and precedent: none stated in the sources')
        elif name in NONE:
            extra.append('- Rationale and precedent: none stated in the sources')
        out_lines = []
        for l in lines:
            out_lines.append(re.sub(r'^(\s*- )(.*)$', lambda m: m.group(1) + esc(m.group(2)), l))
            if l.startswith('- Decided'):
                out_lines += extra; extra = []
        out_lines += extra
        L += out_lines
        L.append('')
prec = collections.OrderedDict()
for name, lines in blocks:
    r = RAT.get(name)
    if not r:
        continue
    for x in r.get('precedents', []):
        k = re.sub(r'[^a-z0-9]+', ' ', canon(x['name']).lower()).strip()
        prec.setdefault(k, [canon(x['name']), collections.defaultdict(list)])[1][x['stance']].append(re.sub(r'\s*\([^()]*\)\s*$', '', name))
L += ['# Precedents, by name', '',
      '- The systems, languages, standards and designs named as referents, with the subjects they shaped; chosen = his choice follows it, rejected = he turned it down, considered = compared or cited.', '']
for k, (nm, d) in sorted(prec.items(), key=lambda kv: (-sum(len(v) for v in kv[1][1].values()), kv[0])):
    parts = []
    for st in ('chosen', 'rejected', 'considered'):
        if d.get(st):
            u = list(dict.fromkeys(d[st]))
            parts.append('%s in %s' % (st, '; '.join(esc(t) for t in u[:6]) + (' and %d more' % (len(u) - 6) if len(u) > 6 else '')))
    L.append('- %s: %s' % (esc(nm), ', '.join(parts)))
L += ['', '# Where the current docs or code differ from the decisions (%d)' % len(differs), '']
for name, l in differs:
    L.append('- %s: %s' % (esc(re.sub(r'\s*\([^()]*\)\s*$', '', name)), esc(l[len('- Doc differs:'):].strip())))
if APP:
    L += ['', APP.rstrip('\n')]
open(out, 'w').write('\n'.join(L) + '\n')
print('%s: %d subjects: %s; %d differ lines -> %s' % (project, n, ', '.join('%d %s' % (len(by[s]), s.lower()) for s in STAT), len(differs), out))
