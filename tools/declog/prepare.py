#!/usr/bin/env python3
"""Prepare agent batches for the decision log from extract.py's output.

  prepare.py cond DATADIR SHARED   -> SHARED/cond-batches/NN.json for every human message longer than
                                      SHORT characters that has no line yet in SHARED/condensed.jsonl
  (Part II batches are made by `prepare.py decisions`, added with the decision pass.)

A message of SHORT characters or fewer is its own one-line form (whitespace collapsed); longer
ones get a one-line condensation written by an agent into SHARED/cond-out/NN.json
({key: line}); merge.py folds those into condensed.jsonl.  Key = '<thread>:<seq>'.
"""
import json, os, re, sys

SHORT = 160
BATCH_CHARS = 55000
CUT = 2600


def key(m):
    return '%s:%s' % (m['thread'], m['seq'])


def cond(data, shared):
    msgs = [json.loads(l) for l in open(os.path.join(data, 'messages.jsonl'))]
    have = set()
    cf = os.path.join(shared, 'condensed.jsonl')
    if os.path.exists(cf):
        have = {json.loads(l)['key'] for l in open(cf)}
    todo = [m for m in msgs if len(m['text']) > SHORT and key(m) not in have]
    out = os.path.join(shared, 'cond-batches')
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        os.remove(os.path.join(out, f))
    batches, cur, size = [], [], 0
    for m in todo:
        t = m['text'] if len(m['text']) <= CUT else m['text'][:CUT // 2] + '\n[... cut ...]\n' + m['text'][-CUT // 2:]
        rec = dict(key=key(m), ts=m['ts'][:16], chars=len(m['text']), pasted=m.get('pasted_chars'), text=t)
        if size + len(t) > BATCH_CHARS and cur:
            batches.append(cur); cur, size = [], 0
        cur.append(rec); size += len(t)
    if cur:
        batches.append(cur)
    for i, b in enumerate(batches, 1):
        json.dump(b, open(os.path.join(out, '%02d.json' % i), 'w'), ensure_ascii=False, indent=0)
    print('%d messages, %d short, %d to condense in %d batches' % (len(msgs), sum(len(m['text']) <= SHORT for m in msgs), len(todo), len(batches)))


if __name__ == '__main__':
    if sys.argv[1] == 'cond':
        cond(sys.argv[2], sys.argv[3])


CTX_TAIL = 600
USER_CUT = 3000
DEC_BATCH_CHARS = 60000


TRIVIAL = re.compile(r'^(resume|keep going|continue|proceed|push it|commit push|commit and push|push|commit|update|keep waiting|pull|status|\.|q|go|go on|next|thanks|thank you|where you at\??|where are you at\??|progress\??|\?)\W*$', re.I)


def decisions(data, shared, threads, db='/home/david/claude/ai-conversations/conversations.db', jsonl_roots=(), skip_file=None, prefix='', ctx_tail=None, batch_chars=None, skip_trivial=False, messages='messages.jsonl'):
    global CTX_TAIL, DEC_BATCH_CHARS
    CTX_TAIL = ctx_tail or CTX_TAIL
    DEC_BATCH_CHARS = batch_chars or DEC_BATCH_CHARS
    """Part II batches: for each human message of the given threads, the tail of the assistant turn before it and the
    message (cut to USER_CUT).  Written as Markdown to DATA/dec-batches/NN.md."""
    import sqlite3
    msgs = [json.loads(l) for l in open(os.path.join(data, messages))]
    want = {str(t) for t in threads}
    msgs = [m for m in msgs if str(m['thread']) in want]
    if skip_trivial:
        msgs = [m for m in msgs if not TRIVIAL.match(m['text'].strip())]
    if skip_file:
        done = {(str(json.loads(l)['thread']), str(json.loads(l)['seq'])) for l in open(skip_file)}
        msgs = [m for m in msgs if (str(m['thread']), str(m['seq'])) not in done]
    c = sqlite3.connect('file:%s?mode=ro' % db, uri=True)
    blocks = []
    ctxcache = {}
    for m in msgs:
        tid = str(m['thread'])
        ctx = ''
        if tid.isdigit() and isinstance(m['seq'], str):
            r = c.execute("select content from messages where thread_id=? and role='assistant' and content_type='text' "
                          "and created_at<? order by sequence_num desc limit 1", (int(tid), m['ts'])).fetchone()
            ctx = (r[0] if r else '') or ''
        elif tid.isdigit():
            r = c.execute("select content from messages where thread_id=? and role='assistant' and content_type='text' "
                          "and sequence_num<? order by sequence_num desc limit 1", (int(tid), m['seq'])).fetchone()
            ctx = (r[0] if r else '') or ''
        else:
            if tid not in ctxcache:
                ctxcache[tid] = load_jsonl_assistant(tid, jsonl_roots)
            prev = [x for x in ctxcache[tid] if (x[0] < m['seq'] if isinstance(m['seq'], int) else True)]
            ctx = prev[-1][1] if prev else ''
        ctx = ctx.strip().replace('\n', ' ')
        if len(ctx) > CTX_TAIL:
            ctx = '...' + ctx[-CTX_TAIL:]
        txt = m['text']
        if len(txt) > USER_CUT:
            txt = txt[:USER_CUT // 2] + '\n[... cut ...]\n' + txt[-USER_CUT // 2:]
        blocks.append((m['ts'], '### [%s:%s] %s %s\nASSISTANT BEFORE: %s\nAUTHOR: %s\n' % (
            m['thread'], m['seq'], m['ts'][:16], m['platform'], ctx or '(none)', txt)))
    blocks.sort(key=lambda b: b[0])
    out = os.path.join(data, 'dec-batches')
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        if f.startswith(prefix) and (prefix or not f.startswith('x')):
            os.remove(os.path.join(out, f))
    batches, cur, size = [], [], 0
    for ts, b in blocks:
        if size + len(b) > DEC_BATCH_CHARS and cur:
            batches.append(cur); cur, size = [], 0
        cur.append(b); size += len(b)
    if cur:
        batches.append(cur)
    for i, b in enumerate(batches, 1):
        open(os.path.join(out, '%s%02d.md' % (prefix, i)), 'w').write('\n'.join(b))
    print('%d messages in %d decision batches' % (len(msgs), len(batches)))


def load_jsonl_assistant(tid, roots):
    label, sid = tid.split(':')
    res = []
    for spec in roots:
        lab, root = spec.split('=', 1)
        if lab != label:
            continue
        for proj in os.listdir(root):
            for fn in os.listdir(os.path.join(root, proj)):
                if fn.startswith(sid) and fn.endswith('.jsonl'):
                    for seq, line in enumerate(open(os.path.join(root, proj, fn), errors='replace')):
                        try:
                            o = json.loads(line)
                        except ValueError:
                            continue
                        if o.get('type') != 'assistant':
                            continue
                        cc = o.get('message', {}).get('content')
                        if isinstance(cc, list):
                            cc = '\n'.join(b.get('text', '') for b in cc if b.get('type') == 'text')
                        if isinstance(cc, str) and cc.strip():
                            res.append((seq, cc))
    return res


if __name__ == '__main__' and sys.argv[1] == 'decisions':
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('cmd'); ap.add_argument('data'); ap.add_argument('shared'); ap.add_argument('threads')
    ap.add_argument('--skip'); ap.add_argument('--prefix', default=''); ap.add_argument('--tail', type=int)
    ap.add_argument('--batch', type=int); ap.add_argument('--skip-trivial', action='store_true'); ap.add_argument('--messages', default='messages.jsonl')
    a = ap.parse_args()
    roots = ['silentpc=/home/david/claude/silentpc-archive/dot-claude/projects',
             'silentpc-opusplan=/home/david/claude/silentpc-archive/dot-claude-opusplan/projects']
    decisions(a.data, a.shared, a.threads.split(','), jsonl_roots=roots, skip_file=a.skip, prefix=a.prefix,
              ctx_tail=a.tail, batch_chars=a.batch, skip_trivial=a.skip_trivial, messages=a.messages)
