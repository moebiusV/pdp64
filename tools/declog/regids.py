"""regids.py: parse message ids of every form used in the ledger, rationale and appendix files, and resolve them to messages."""
import json, os, re, glob

DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'docs', 'decision-log', 'data')
TOK = re.compile(r'^(?:(?P<pre>(?:hist-)?silentpc(?:-opusplan)?):)?(?P<th>[0-9a-f]{8}|\d+)(?P<sep>[:#])(?P<seq>[jh]?\d+)(?:#\d+)?$')
# a token anywhere in prose (not only in brackets)
PROSE = re.compile(r'(?<![\w:#.\-/])((?:(?:hist-)?silentpc(?:-opusplan)?:)?(?:[0-9a-f]{8}|\d{3,5})[:#][jh]?\d+(?:#\d+)?)(?!\w)(?!:[jh]?\d)')
FILES = ['messages.jsonl', 'messages.broad.jsonl', 'messages.unseen.jsonl', 'messages.all.jsonl', 'messages.focus.jsonl']


def load_index(project):
    idx, order = {}, {}
    for fn in FILES:
        p = os.path.join(DATA, project, fn)
        if not os.path.exists(p):
            continue
        for l in open(p):
            m = json.loads(l)
            th = str(m['thread'])
            core = th.rsplit(':', 1)[-1]
            pre = th.rsplit(':', 1)[0] if ':' in th else ''
            idx.setdefault((core, str(m['seq'])), {})[th] = m
    return idx


def resolve(tok, idx):
    """tok -> (message, thread) or None"""
    m = TOK.match(tok)
    if not m:
        return None
    core, seq = m.group('th'), m.group('seq')
    c = idx.get((core, seq))
    if not c:
        return None
    pre = m.group('pre')
    if pre:
        for th, msg in c.items():
            if th == '%s:%s' % (pre, core):
                return msg
    if len(c) == 1 or not pre:
        th = sorted(c)[0]
        return c[th]
    # prefix given but not equal: prefer same hist-ness
    for th, msg in c.items():
        if th.startswith('hist-') == pre.startswith('hist-'):
            return msg
    return list(c.values())[0]


def tokens_in(text, idx):
    """every message id in text: list of (token, message or None, where) ; bracket groups first, then prose tokens that resolve"""
    out = []
    spans = []
    for b in re.finditer(r'\[([^\[\]]+)\]', text):
        parts = [x.strip() for x in b.group(1).split(',')]
        # "[1882#j4575, 1882#443]" or "[a:b#1, c:d#2]"
        ok = [x for x in parts if TOK.match(x)]
        if ok:
            spans.append(b.span())
            for x in ok:
                out.append((x, resolve2(x, idx)[0], b.span()))
        else:
            # "[533:2]" style inside nested text handled by TOK; groups like "[errata 94]" skipped
            pass
    for p in PROSE.finditer(text):
        if any(s <= p.start() < e for s, e in spans):
            continue
        r = resolve2(p.group(1), idx)[0]
        if r is not None:
            out.append((p.group(1), r, p.span()))
            spans.append(p.span())
    return out


def resolve2(tok, idx):
    """resolve with the repairs seen in the ledgers: a missing j/h prefix on the sequence number, a wrong thread number
    (the sequence number alone is unique).  returns (message, how) or (None, why)"""
    m = TOK.match(tok)
    if not m:
        return None, 'unparsed'
    r = resolve(tok, idx)
    if r is not None:
        return r, 'exact'
    core, seq = m.group('th'), m.group('seq')
    if seq[0].isdigit():
        for p in ('j', 'h'):
            c = idx.get((core, p + seq))
            if c:
                return list(c.values())[0], 'seq prefix %s added' % p
    cands = [msg for (c2, s2), d in idx.items() if s2 == seq for msg in d.values()]
    if seq[0] in 'jh' and len(cands) >= 1:
        # same seq in several threads: take it only if the thread numbers agree on core
        if len({str(x['thread']) for x in cands}) == 1:
            return cands[0], 'thread corrected'
    return None, 'not found'


def looks_like_id(tok):
    m = TOK.match(tok)
    if not m:
        return False
    th = m.group('th')
    return bool(m.group('pre')) or len(th) >= 3 or m.group('seq')[0] in 'jh'
