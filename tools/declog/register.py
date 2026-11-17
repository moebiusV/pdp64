#!/usr/bin/env python3
"""register.py PROJECT: build the decision register of a project from its ledger parts.

Reads docs/decision-log/data/PROJECT/{ledger/*.md, rationale/*.json, oq-appendix.md, part2*/*.md, part2-extra.json} and the messages*.jsonl,
resolves every cited message id (regids.py), and writes
  data/PROJECT/register.json      rows with the old ids kept as 'source' (private)
  data/PROJECT/id-map.json        old ids -> R numbers (private, for replacing ids in the other documents)
  data/PROJECT/register.md        the published register (copied by publish.py)
and, with --rewrite, a copy of the ledger parts in data/PROJECT/ledger-before-register/ and the ledger parts with every id replaced by [R<n>].
Rows are ordered by the message time (ties: thread, sequence); numbers are never reused.
"""
import collections, glob, json, os, re, shutil, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import regids
from part1 import esc

DATA = regids.DATA
DECISIVE = {'decided', 'changed', 'reversed', 'approved-proposal', 'rejected'}
FORBID = [(re.compile(r'/home/\S+'), '[path]'), (re.compile(r'silentpc', re.I), '[other machine]'), (re.compile(r'opusplan', re.I), '[session]'),
          (re.compile(r'claude[_ -]?(?:code|cli|web|opus|sonnet)?|opus|sonnet|haiku', re.I), '[assistant]'),
          (re.compile(r'\b(?:david|matthew)\b', re.I), '[name]')]
STOP = set('the a an of to and or in on for is are be it this that with as at by we i you not do does if so but from have has was were will would should can could what how why then them they our your its his her than there their which who'.split())


def scrub(t):
    n = 0
    for rx, rep in FORBID:
        t, k = rx.subn(rep, t)
        n += k
    return t, n


def load_blocks(project, ldir=None):
    blocks = []
    bk = os.path.join(DATA, project, 'ledger-before-register')
    ldir = ldir or (bk if os.path.isdir(bk) else os.path.join(DATA, project, 'ledger'))
    for f in sorted(glob.glob(os.path.join(ldir, '*.md')), key=lambda p: (len(os.path.basename(p)), p)):
        cur = None
        for line in open(f):
            line = line.rstrip('\n')
            if line.startswith('## Summary'):
                cur = None; continue
            if line.startswith('### '):
                cur = [line[4:].strip(), []]; blocks.append(cur)
            elif line.startswith('## '):
                cur = None
            elif cur is not None and line.strip():
                cur[1].append(line)
    return blocks


def strip_cat(name):
    return re.sub(r'\s*\([^()]*\)\s*$', '', name)


def norm(s):
    s = s.replace('’', "'").replace('‘', "'").replace('“', '"').replace('”', '"')
    return ' '.join(s.split())


def kind_words(line, start, end):
    """kind word ('decided', 'potential', ...) of the dated entry that holds the span, if any"""
    best = None
    for m in re.finditer(r'\d{4}-\d\d-\d\d (?:potential|[a-z-]+):', line):
        if m.start() < start:
            best = m.group(0).split()[1].rstrip(':')
    return best


def collect(project):
    idx = regids.load_index(project)
    cites = collections.defaultdict(list)     # (thread, seq) -> list of dict
    unresolved = collections.defaultdict(list)
    repairs = {}
    msgs = {}

    def scan(text, subject, linekind):
        for tok, msg, span in regids.tokens_in(text, idx):
            if msg is None:
                if regids.looks_like_id(tok):
                    unresolved[tok].append(subject)
                continue
            k = (str(msg['thread']), str(msg['seq']))
            msgs[k] = msg
            how = regids.resolve2(tok, idx)[1]
            if how != 'exact':
                repairs[tok] = how
            kw = kind_words(text, span[0], span[1]) if linekind == 'decided' else None
            cites[k].append(dict(subject=subject, linekind=linekind, kw=kw, line=text, tok=tok))

    blocks = load_blocks(project)
    names = {n for n, _ in blocks}
    for name, lines in blocks:
        sub = strip_cat(name)
        for l in lines:
            lk = 'decided' if l.startswith('- Decided') else 'other'
            scan(l, sub, lk)
    rdir = os.path.join(DATA, project, 'rationale')
    for f in sorted(glob.glob(os.path.join(rdir, '*.json'))):
        for r in json.load(open(f)):
            if r['subject'] not in names:
                continue
            sub = strip_cat(r['subject'])
            for x in r.get('rationale', []):
                scan(x.get('text', '') + ' ' + x.get('id', ''), sub, 'rationale')
            for x in r.get('precedents', []):
                scan(x.get('note', '') + ' ' + x.get('id', ''), sub, 'precedent')
    ap = os.path.join(DATA, project, 'oq-appendix.md')
    if os.path.exists(ap):
        sub = 'open questions'
        for l in open(ap):
            m = re.match(r'#+ (.*)', l)
            if m:
                sub = m.group(1).strip()
            scan(l, 'open questions', 'appendix')
    return idx, cites, unresolved, repairs, msgs


SUBJ = {}


def chain_edges(project, idx):
    """(older message key, newer message key) pairs from the part2 chains"""
    edges = set()
    SUBJ.clear()
    files = sorted(glob.glob(os.path.join(DATA, project, 'part2*', '*.md')))
    for f in files:
        subj, items = None, []

        def flush():
            if not items:
                return
            # drop repeated lines (the 'Now:' copy)
            seen, its = set(), []
            for it in items:
                if it['key'] in seen:
                    continue
                seen.add(it['key']); its.append(it)
            its.sort(key=lambda it: (it['ts'], it['key']))
            has_in = set()
            for it in its:
                if it['changes']:
                    d, pref = it['changes']
                    for e in its:
                        if e is not it and e['date'] == d and e['key'] != it['key'] and (norm(pref).lower()[:30] in norm(e['text']).lower()):
                            edges.add((e['key'], it['key'])); has_in.add(e['key'])
            for i, e in enumerate(its):
                if e['superseded'] and e['kind'] in DECISIVE and e['key'] not in has_in:
                    for n in its[i + 1:]:
                        if n['kind'] in DECISIVE and n['key'] != e['key'] and n['ts'] >= e['ts']:
                            edges.add((e['key'], n['key'])); break
        for line in open(f):
            line = line.rstrip('\n')
            if line.startswith('### '):
                flush(); items = []; subj = line[4:].strip(); continue
            m = re.match(r'^- (?:Now: )?(\d{4}-\d\d-\d\d) ([a-z-]+):? (.*)$', line)
            if not m:
                continue
            ids = [(t, msg) for t, msg, sp in regids.tokens_in(line, idx) if msg]
            if not ids:
                continue
            msg = ids[0][1]
            SUBJ.setdefault((str(msg['thread']), str(msg['seq'])), subj)
            ch = re.search(r'\(changes (\d{4}-\d\d-\d\d) ([^)]*)\)', line)
            items.append(dict(date=m.group(1), kind=m.group(2), text=m.group(3), key=(str(msg['thread']), str(msg['seq'])), ts=msg['ts'],
                              superseded=bool(re.search(r'\(superseded \d{4}', line)), changes=(ch.group(1), ch.group(2)) if ch else None))
        flush()
    return edges


def pick_text(msg, cs, limit=300):
    full = norm(msg['text'])
    low = norm(msg['text']).lower()
    if len(full) <= limit:
        return full
    frags = []
    for c in cs:
        for q in re.findall(r'"([^"]{6,})"', c['line']):
            for part in re.split(r'\.\.\.|…', norm(q)):
                part = part.strip(' .;,')
                if len(part) >= 6 and part.lower() in low:
                    i = low.index(part.lower()); frags.append((i, i + len(part)))
    # sentences
    sents = [(m.start(), m.end()) for m in re.finditer(r'[^.!?]+[.!?]*\s*', full)]
    if frags:
        spans = []
        for a, b in sorted(set(frags)):
            sa = max([s for s, e in sents if s <= a] or [a]); sb = min([e for s, e in sents if e >= b] or [b])
            spans.append([sa, sb])
        spans = merge(spans)
        if sum(e - s for s, e in spans) > limit:
            spans = merge([[a, b] for a, b in sorted(set(frags))])
    else:
        words = collections.Counter()
        for c in cs:
            for w in re.findall(r'[a-z0-9_/-]{3,}', (c['subject'] + ' ' + c['line']).lower()):
                if w not in STOP:
                    words[w] += 1
        sc = []
        for s, e in sents:
            ws = set(re.findall(r'[a-z0-9_/-]{3,}', full[s:e].lower()))
            sc.append((sum(1 for w in ws if w in words) / (1 + 0.02 * len(ws)), s, e))
        chosen, tot = [], 0
        for v, s, e in sorted(sc, reverse=True):
            if tot + (e - s) <= limit:
                chosen.append([s, e]); tot += e - s
        spans = merge(sorted(chosen)) or [[0, limit]]
    out = ' ... '.join(full[s:e].strip() for s, e in spans)
    if len(out) > limit:
        out = out[:limit - 3].rsplit(' ', 1)[0] + '...'
    return out


def merge(spans):
    spans = sorted(spans); out = []
    for s, e in spans:
        if out and s <= out[-1][1] + 1:
            out[-1][1] = max(out[-1][1], e)
        else:
            out.append([s, e])
    return out


def row_kind(msg, cs):
    ks = set()
    for c in cs:
        if c['linekind'] == 'decided':
            kw = c['kw']
            if kw in DECISIVE:
                ks.add('decision')
            elif kw == 'potential' or kw is None:
                ks.add('question' if '?' in msg['text'] else 'context') if kw == 'potential' else ks.add('decision')
            else:
                ks.add('context')
        elif c['linekind'] == 'rationale':
            ks.add('rationale')
        else:
            ks.add('context')
    for k in ('decision', 'question', 'rationale', 'context'):
        if k in ks:
            return k
    return 'context'


def build(project):
    idx, cites, unresolved, repairs, msgs = collect(project)
    edges = chain_edges(project, idx)
    keys = set(cites)
    # add chain partners of cited rows (decision messages replaced by or replacing a cited decision)
    changed = True
    extra = set()
    while changed:
        changed = False
        for a, b in edges:
            if (a in keys) != (b in keys):
                for k in (a, b):
                    if k not in keys:
                        keys.add(k); extra.add(k); changed = True
    allm = {}
    for fn in regids.FILES:
        p = os.path.join(DATA, project, fn)
        if os.path.exists(p):
            for l in open(p):
                m = json.loads(l); allm[(str(m['thread']), str(m['seq']))] = m
    order = sorted(keys, key=lambda k: (allm[k]['ts'], k[0], k[1]))
    num = {k: i + 1 for i, k in enumerate(order)}
    rows = []
    scrubbed = 0
    for k in order:
        m = allm[k]; cs = cites.get(k, [])
        if not cs:
            cs = [dict(subject='', linekind='decided', kw='decided', line='', tok='')]
        text, n = scrub(pick_text(m, cs)); scrubbed += n
        subs = list(dict.fromkeys(c['subject'] for c in cs if c['subject'])) or ([SUBJ[k]] if k in SUBJ else [])
        sup = sorted(num[a] for a, b in edges if b == k and a in num)
        by = sorted(num[b] for a, b in edges if a == k and b in num)
        rows.append(dict(n=num[k], date=m['ts'][:10], ts=m['ts'], kind=row_kind(m, cs) if k in cites else 'decision', text=text, subjects=subs[:5],
                         more_subjects=max(0, len(subs) - 5), supersedes=sup, superseded_by=by,
                         source=dict(thread=k[0], seq=k[1], tokens=sorted({c['tok'] for c in cs if c['tok']}), added_from_chain=(k in extra))))
    bynum = {r['n']: r for r in rows}
    ex = os.path.join(DATA, project, 'register-extra.json')
    if os.path.exists(ex):
        # events with no message of the author (an erratum event): appended after the message rows, numbered on
        for e in json.load(open(ex)):
            n = len(rows) + 1
            r = dict(n=n, date=e['date'], ts=e['date'] + 'T23:59:59Z', kind=e['kind'], text=scrub(e['text'])[0], subjects=e['subjects'], more_subjects=0,
                     supersedes=e.get('supersedes', []), superseded_by=[], source=dict(thread='', seq='', tokens=[], added_from_chain=False, event=e['source']))
            rows.append(r); bynum[n] = r
            for m in r['supersedes']:
                bynum[m]['superseded_by'].append(n)
    for r in rows:
        if not r['subjects']:
            for n in r['supersedes'] + r['superseded_by']:
                if bynum[n]['subjects']:
                    r['subjects'] = list(bynum[n]['subjects']); r['more_subjects'] = bynum[n]['more_subjects']; break
    return rows, unresolved, repairs, scrubbed, idx, num, allm


HEAD = """# Decision register of {title}

- The rule: this register is append-only. Row numbers are never reused or renumbered. A row replaced by a later decision stays, and points forward ("superseded by R-m"); the later row points back ("supersedes R-n"). Later events (an item done, a decision superseded) are added as new rows with the next number, at the end.
- What a row is: one message of the author that the status document of the project cites (as a decision, a rationale, a context or a question), in his own words trimmed to the relevant sentences; the status document refers to it as [R<n>]. Rows are ordered by the time of the message, so the numbers increase with time.
- Row: R-number | date | kind (decision, rationale, context, question) | the author's words | the subjects it bears on | "supersedes R-n" when it replaces an earlier decision on the same subject | "superseded by R-m" or "current".

"""


def render(project, title, rows):
    L = [HEAD.format(title=title)]
    for r in rows:
        f = ['R%d' % r['n'], r['date'], r['kind'], '"%s"' % esc(r['text']).replace('"', "'") if False else '"%s"' % esc(r['text'])]
        subs = '; '.join(esc(s) for s in r['subjects']) + (' and %d more' % r['more_subjects'] if r['more_subjects'] else '')
        f.append('subjects: ' + (subs or 'none'))
        if r['supersedes']:
            f.append('supersedes ' + ', '.join('R%d' % n for n in r['supersedes']))
        f.append('superseded by ' + ', '.join('R%d' % n for n in r['superseded_by']) if r['superseded_by'] else 'current')
        L.append('- ' + ' | '.join(f))
    return '\n'.join(L) + '\n'


def replace_ids(text, idx, canon, report=None):
    """replace every message id in text by R<n> (canon: 'thread:seq' -> n)"""
    out = []
    for b in regids.tokens_in(text, idx):
        pass
    # bracket groups
    def grp(m):
        parts = [x.strip() for x in m.group(1).split(',')]
        ids = [x for x in parts if regids.TOK.match(x) and regids.looks_like_id(x)]
        if not ids:
            return m.group(0)
        rs, rest = [], []
        for x in parts:
            if x in ids:
                msg = regids.resolve2(x, idx)[0]
                n = canon.get('%s:%s' % (msg['thread'], msg['seq'])) if msg else None
                if n is None:
                    if report is not None:
                        report.append(x)
                else:
                    rs.append(n)
            else:
                rest.append(x)
        rs = sorted(set(rs))
        body = ', '.join(['R%d' % n for n in rs] + rest)
        return '[%s]' % body if body else ''
    t = re.sub(r'\[([^\[\]]+)\]', grp, text)
    t = re.sub(r' +(?=[;,.)]|$)', lambda m: m.group(0) if False else '', t) if False else t

    def prose(m):
        msg = regids.resolve2(m.group(1), idx)[0]
        if msg is None:
            return m.group(0)
        n = canon.get('%s:%s' % (msg['thread'], msg['seq']))
        return 'R%d' % n if n else m.group(0)
    return regids.PROSE.sub(prose, t)


def main():
    project = sys.argv[1]
    rewrite = '--rewrite' in sys.argv
    titles = {'pdp64': 'the pdp64', 'imp72': 'imp72', 'hbnf': 'hbnf'}
    rows, unresolved, repairs, scrubbed, idx, num, allm = build(project)
    base = os.path.join(DATA, project)
    json.dump(rows, open(os.path.join(base, 'register.json'), 'w'), indent=1)
    canon = {'%s:%s' % k: n for k, n in num.items()}
    forms = {}
    for r in rows:
        for t in r['source']['tokens']:
            forms[t] = 'R%d' % r['n']
        if r['source'].get('event'):
            forms[r['source']['event']] = 'R%d' % r['n']
    json.dump(dict(project=project, note="canon: 'thread:seq' (thread as in the messages files) -> R number; forms: every id form cited in the ledgers -> R number; parse other documents with tools/declog/regids.py and look the resolved message up in canon",
                   canon={k: 'R%d' % v for k, v in canon.items()}, forms=forms), open(os.path.join(base, 'id-map.json'), 'w'), indent=1)
    open(os.path.join(base, 'register.md'), 'w').write(render(project, titles[project], rows))
    print(project, len(rows), 'rows;', sum(1 for r in rows if r['source']['added_from_chain']), 'added from chains;',
          sum(len(r['supersedes']) for r in rows), 'supersession links; scrubbed words:', scrubbed)
    print('unresolved:', {k: v[:2] for k, v in unresolved.items()})
    print('repairs:', repairs)
    if rewrite:
        bk = os.path.join(base, 'ledger-before-register')
        if not os.path.isdir(bk):
            shutil.copytree(os.path.join(base, 'ledger'), bk)
        for f in glob.glob(os.path.join(bk, '*.md')):
            t = open(f).read()
            rep = []
            t2 = replace_ids(t, idx, canon, rep)
            open(os.path.join(base, 'ledger', os.path.basename(f)), 'w').write(t2)
            if rep:
                print('dropped', os.path.basename(f), rep)


if __name__ == '__main__':
    main()
