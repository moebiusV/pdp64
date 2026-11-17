#!/usr/bin/env python3
"""Part I of the decision log: the author's instructions in order, one line per message.

A module (`build(data, shared)`), also runnable: part1.py DATADIR SHARED OUT.md.

Threads flagged `incidental_hint` by extract.py (no strong term in any of the author's own messages, at most two
mentions overall) are not logged message by message; they are listed in the appendix with the reason.  A message of at
most SHORT characters is quoted whole (whitespace collapsed); a longer one is the agents' one-line condensation from
SHARED/condensed.jsonl.  Every line ends with its source [thread#seq].
"""
import collections, json, os, re, sys

SHORT = 160
OVERRIDE_FULL = {'1888', '1882', '592'}   # on-topic whatever the hint says
OVERRIDE_PASS = set()


def esc(s):
    s = s.replace('\\', '\\\\')
    for ch in '`*_[]<>|$':
        s = s.replace(ch, '\\' + ch)
    return re.sub(r'^(\s*)([#>+-])', r'\1\\\2', s)


def load(data, shared):
    T = {str(t['id']): t for t in json.load(open(os.path.join(data, 'threads.json')))['threads']}
    M = [json.loads(l) for l in open(os.path.join(data, 'messages.jsonl'))]
    C = {}
    for l in open(os.path.join(shared, 'condensed.jsonl')):
        r = json.loads(l); C[r['key']] = r['line']
    return T, M, C


def passing(t):
    tid = str(t['id'])
    return (t['incidental_hint'] and tid not in OVERRIDE_FULL) or tid in OVERRIDE_PASS


def build(data, shared):
    """returns (lines, stats): lines grouped as ## month / ### day / #### thread / bullets"""
    T, M, C = load(data, shared)
    byday = collections.OrderedDict()
    missing, n = [], 0
    for m in sorted(M, key=lambda m: (m['ts'], str(m['thread']), str(m['seq']))):
        t = T[str(m['thread'])]
        if passing(t):
            continue
        key = '%s:%s' % (m['thread'], m['seq'])
        if len(m['text']) <= SHORT and 'pasted_chars' not in m:
            line, verb = ' '.join(m['text'].split()), True
        elif key in C:
            line, verb = C[key], False
        else:
            missing.append(key); line, verb = '[no condensation yet]', False
        byday.setdefault(m['ts'][:10], collections.OrderedDict()).setdefault(str(m['thread']), []).append(
            (m['ts'][11:16], key, line, verb))
        n += 1
    L, month = [], None
    for day, th in byday.items():
        if day[:7] != month:
            month = day[:7]
            L += ['## ' + month, '']
        L += ['### ' + day, '']
        for tid, items in th.items():
            t = T[tid]
            L += ['#### %s (%s, thread %s)' % (esc(t['title'] or '(untitled)')[:90], t['platform'], tid), '']
            for hm, key, line, verb in items:
                L.append('- %s [%s] %s' % (hm, key.replace(':', '#'), ('"%s"' % esc(line)) if verb else esc(line)))
            L.append('')
    stats = dict(lines=n, days=len(byday), missing=missing, passing=sum(passing(t) for t in T.values()))
    return L, stats, T


if __name__ == '__main__':
    data, shared, out = sys.argv[1:4]
    L, st, T = build(data, shared)
    open(out, 'w').write('\n'.join(['# Part I. The instructions, in order', ''] + L) + '\n')
    print(st['lines'], 'lines;', len(st['missing']), 'without condensation')
