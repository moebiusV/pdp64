#!/usr/bin/env python3
"""Extract the author's own messages from the ai-conversations (Chronicle) database for a topic.

Read-only: the database is opened with mode=ro.  Writes OUT/threads.json (one record per
selected thread, with hit counts and a class) and OUT/messages.jsonl (one record per human
user message of the selected threads, in thread/sequence order).

  extract.py --topic pdp64 --terms 'pdp[- ]?11(?!\\d)|pdp-?64|commodore 64' --weak '(?<![0-9a-z_])c64(?![0-9a-z_])' --out DIR

Classes: A = a strong term in the thread title or in visible text (user text, assistant text,
artifacts; never thinking or tool content); B = only the weak term in visible text.
`incidental` is a hint for review (no strong term in any user message and at most 2 strong
hits overall), never a decision.

Harness text that the CLI stores as user messages (task notifications, subagent hand-backs,
system reminders, continuation summaries) is not the author's own words and is dropped; the
count dropped is reported.  Long pasted material is kept as its first PASTE_HEAD and its last
PASTE_TAIL characters (the instruction usually follows the paste) with the length of the gap.
"""
import argparse, json, os, re, sqlite3, sys

DB = '/home/david/claude/ai-conversations/conversations.db'
PASTE_LIMIT = 3000
PASTE_HEAD = 300
PASTE_TAIL = 900
HARNESS = ('<task-notification', 'Another Claude session', '<system-reminder', 'This session is being continued',
           '[SYSTEM', '<local-command', '<command-', 'Caveat:', '[Request interrupted', '<user-prompt-submit-hook',
           '[Subagent hand-back', '<agent-message')
SOCIAL = ('grok_x',)   # X posts and DMs are kept apart from the AI threads in Chronicle; grok_x threads are AI chats


def cli_extras(path, known=()):
    """Author text in a Claude Code session file that is not an ordinary user message: messages typed while the
    assistant was working (queued_command attachments), the feedback typed when a plan or tool use was rejected
    ("the user said: ..."), and the answers to the assistant's questions.  Returns [(seq, ts, text, kind)] with
    seq 'j<line>'; texts already in `known` are skipped.  Chronicle's importer does not keep these."""
    out, seen = [], set(known)

    def add(i, ts, text, kind):
        text = (text or '').strip()
        if not text or text in seen or text.startswith(HARNESS):
            return
        seen.add(text)
        out.append(('j%d' % i, ts, text, kind))

    def feedback(c):
        m = re.search(r"the user said:\s*(.*)\Z", c, re.S)
        return m.group(1) if m else None

    for i, line in enumerate(open(path, errors='replace')):
        try:
            o = json.loads(line)
        except ValueError:
            continue
        ts = o.get('timestamp', '')
        if o.get('type') == 'attachment' and o.get('attachment', {}).get('type') == 'queued_command':
            p = o['attachment'].get('prompt', '')
            if isinstance(p, str):
                if p.lstrip().startswith("The user doesn't want to proceed"):
                    f = feedback(p)
                    if f:
                        add(i, ts, f, 'feedback')
                else:
                    add(i, ts, p, 'queued')
        elif o.get('type') == 'user' and isinstance(o.get('message', {}).get('content'), list):
            for b in o['message']['content']:
                if b.get('type') != 'tool_result':
                    continue
                c = b.get('content')
                if isinstance(c, list):
                    c = ' '.join(x.get('text', '') for x in c if isinstance(x, dict))
                c = str(c)
                if c.lstrip().startswith("The user doesn't want to proceed"):
                    f = feedback(c)
                    if f:
                        add(i, ts, f, 'feedback')
                elif c.startswith('Your questions have been answered') or c.startswith('User has answered'):
                    add(i, ts, re.sub(r'\s*You can now continue with these answers in mind\.?\s*$', '', c), 'answer')
    return out


def cli_paths():
    """session uuid -> file, for the local Claude Code config folders"""
    res = {}
    for cfg in ('.claude', '.claude-opusplan'):
        base = os.path.join(os.path.expanduser('~'), cfg, 'projects')
        if os.path.isdir(base):
            for proj in os.listdir(base):
                d = os.path.join(base, proj)
                if os.path.isdir(d):
                    for fn in os.listdir(d):
                        if fn.endswith('.jsonl'):
                            res[fn[:-6]] = os.path.join(d, fn)
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--topic', required=True)
    ap.add_argument('--terms', required=True, help='strong regex, case-insensitive')
    ap.add_argument('--weak', default='', help='weak regex (whole-word forms), case-insensitive')
    ap.add_argument('--out', required=True)
    ap.add_argument('--db', default=DB)
    ap.add_argument('--jsonl-root', action='append', default=[], metavar='LABEL=DIR',
                    help='a copy of a Claude Code projects/ directory from another machine, read directly (e.g. silentpc=/path/dot-claude/projects); repeatable')
    ap.add_argument('--history', action='append', default=[], metavar='LABEL=FILE',
                    help='a Claude Code history.jsonl (every prompt typed, with project and session id); prompts of sessions whose session file no longer exists are imported as history-only threads')
    ap.add_argument('--project-regex', default='', help='history prompts from projects whose path matches are relevant even without a search term')
    a = ap.parse_args()
    strong = re.compile(a.terms, re.I)
    weak = re.compile(a.weak, re.I) if a.weak else None
    os.makedirs(a.out, exist_ok=True)
    c = sqlite3.connect('file:%s?mode=ro' % a.db, uri=True)
    plat = dict(c.execute('select id,name from platforms'))
    threads = {}
    paths = cli_paths()
    for tid, pid, title, ca, ua, psid in c.execute('select id,platform_id,title,created_at,updated_at,platform_thread_id from threads'):
        threads[tid] = dict(id=tid, platform=plat[pid], title=title or '', created=ca, updated=ua, session=psid,
                            strong_title=bool(strong.search(title or '')), strong_user=0, strong_asst=0, weak_hits=0)
    # visible text only
    q = "select thread_id, role, content from messages where content_type in ('text','artifact')"
    for tid, role, text in c.execute(q):
        if not text:
            continue
        t = threads[tid]
        n = len(strong.findall(text))
        if n:
            if role == 'user':
                t['strong_user'] += n
            else:
                t['strong_asst'] += n
        elif weak and weak.search(text):
            t['weak_hits'] += 1
    sel = []
    for t in threads.values():
        s = t['strong_title'] or t['strong_user'] or t['strong_asst']
        if s:
            t['cls'] = 'A'
        elif t['weak_hits']:
            t['cls'] = 'B'
        else:
            continue
        t['incidental_hint'] = (not t['strong_user']) and (t['strong_user'] + t['strong_asst'] <= 2)
        sel.append(t)
    ext = {}   # thread id -> list of (seq, ts, text) human messages of an external JSONL session
    for spec in a.jsonl_root:
        label, root = spec.split('=', 1)
        for proj in sorted(os.listdir(root)):
            pdir = os.path.join(root, proj)
            for fn in sorted(os.listdir(pdir)):
                if not fn.endswith('.jsonl'):
                    continue
                tid = '%s:%s' % (label, fn[:-6][:8])
                t = dict(id=tid, platform='claude_cli@' + label, title='', created=None, updated=None, project=proj,
                         session=fn[:-6], strong_title=False, strong_user=0, strong_asst=0, weak_hits=0)
                hum = []
                for seq, line in enumerate(open(os.path.join(pdir, fn), errors='replace')):
                    try:
                        o = json.loads(line)
                    except ValueError:
                        continue
                    if o.get('type') not in ('user', 'assistant'):
                        continue
                    ts = o.get('timestamp', '')
                    t['created'] = t['created'] or ts
                    t['updated'] = ts or t['updated']
                    cc = o.get('message', {}).get('content')
                    if isinstance(cc, list):
                        cc = '\n'.join(b.get('text', '') for b in cc if b.get('type') == 'text')
                    if not isinstance(cc, str) or not cc.strip():
                        continue
                    n = len(strong.findall(cc))
                    if n:
                        t['strong_user' if o['type'] == 'user' else 'strong_asst'] += n
                    elif weak and weak.search(cc):
                        t['weak_hits'] += 1
                    if o['type'] == 'user':
                        hum.append((seq, ts, cc.strip()))
                ekinds = {}
                for xs, xts, xtext, xk in cli_extras(os.path.join(pdir, fn), known={x for _, _, x in hum}):
                    hum.append((xs, xts, xtext)); ekinds[(xs)] = xk
                    n = len(strong.findall(xtext))
                    if n:
                        t['strong_user'] += n
                t['_kinds'] = ekinds
                hum.sort(key=lambda h: (h[1], str(h[0])))
                for _, _, x in hum:
                    if not x.startswith(HARNESS):
                        t['title'] = x.replace('\n', ' ')[:70]
                        break
                if t['strong_user'] or t['strong_asst']:
                    t['cls'] = 'A'
                elif t['weak_hits']:
                    t['cls'] = 'B'
                else:
                    continue
                t['incidental_hint'] = (not t['strong_user']) and (t['strong_user'] + t['strong_asst'] <= 2)
                sel.append(t)
                ext[tid] = hum
    # prompts of sessions whose files are gone (history.jsonl)
    import glob, datetime
    have_sessions = set()
    for root in [os.path.join(os.path.expanduser('~'), cfg, 'projects') for cfg in ('.claude', '.claude-opusplan')] + \
            [spec.split('=', 1)[1] for spec in a.jsonl_root]:
        for pth in glob.glob(root + '/*/*.jsonl'):
            have_sessions.add(os.path.basename(pth)[:-6])
    preg = re.compile(a.project_regex, re.I) if a.project_regex else None
    for spec in a.history:
        label, hf = spec.split('=', 1)
        groups = {}
        for line in open(hf, errors='replace'):
            try:
                h = json.loads(line)
            except ValueError:
                continue
            sid = h.get('sessionId') or 'none'
            if sid in have_sessions:
                continue
            txt = (h.get('display') or '').strip()
            for pc in (h.get('pastedContents') or {}).values():
                body = pc.get('content') if isinstance(pc, dict) else None
                if body:
                    txt += '\n[pasted %d characters: %s ... %s]' % (len(body), body[:300].replace('\n', ' '), body[-300:].replace('\n', ' '))
            if not txt:
                continue
            groups.setdefault((sid, h.get('project') or ''), []).append((h.get('timestamp', 0), txt))
        for (sid, proj), items in groups.items():
            items.sort()
            nstrong = sum(len(strong.findall(x)) for _, x in items)
            if not (nstrong or (preg and preg.search(proj))):
                continue
            tid = 'hist-%s:%s' % (label, sid[:8])
            iso = lambda ms: datetime.datetime.fromtimestamp(ms / 1000, datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.000Z')
            t = dict(id=tid, platform='claude_cli@%s (history only)' % label, title=items[0][1].replace('\n', ' ')[:70],
                     created=iso(items[0][0]), updated=iso(items[-1][0]), project=proj, session=sid,
                     strong_title=False, strong_user=nstrong, strong_asst=0, weak_hits=0, cls='A', history_only=True)
            t['incidental_hint'] = (nstrong == 0)
            sel.append(t)
            ext[tid] = [('h%d' % i, iso(ms), x) for i, (ms, x) in enumerate(items)]
    sel.sort(key=lambda t: (t['created'] or '', str(t['id'])))
    dropped = {}
    nmsg = 0
    with open(os.path.join(a.out, 'messages.jsonl'), 'w') as f:
        for t in sel:
            kinds = t.get('_kinds', {})
            if t['id'] in ext:
                rows = ext[t['id']]
                kinds = t.get('_kinds', {})
            else:
                rows = c.execute("select sequence_num, created_at, content from messages where thread_id=? and role='user' "
                                 "and content_type='text' order by sequence_num", (t['id'],)).fetchall()
                sid = t.get('session')
                if t['platform'] == 'claude_cli' and sid in paths:
                    known = {(x or '').strip() for _, _, x in rows}
                    ex = cli_extras(paths[sid], known)
                    kinds = {xs: xk for xs, _, _, xk in ex}
                    rows = list(rows) + [(xs, xts, xtext) for xs, xts, xtext, _ in ex]
            keep = 0
            for seq, ts, text in rows:
                text = (text or '').strip()
                if not text:
                    continue
                if text.startswith(HARNESS):
                    dropped[t['id']] = dropped.get(t['id'], 0) + 1
                    continue
                rec = dict(thread=t['id'], platform=t['platform'], seq=seq, ts=ts)
                if seq in kinds:
                    rec['kind'] = kinds[seq]
                if len(text) > PASTE_LIMIT:
                    rec['pasted_chars'] = len(text)
                    rec['text'] = text[:PASTE_HEAD] + '\n[... %d characters pasted ...]\n' % (len(text) - PASTE_HEAD - PASTE_TAIL) + text[-PASTE_TAIL:]
                else:
                    rec['text'] = text
                f.write(json.dumps(rec, ensure_ascii=False) + '\n')
                keep += 1
                nmsg += 1
            t['human_messages'] = keep
            t['harness_dropped'] = dropped.get(t['id'], 0)
    for t in sel:
        t.pop('_kinds', None)
    json.dump(dict(topic=a.topic, terms=a.terms, weak=a.weak, db=a.db, threads=sel), open(os.path.join(a.out, 'threads.json'), 'w'),
              indent=1, ensure_ascii=False)
    print('%s: %d threads (A %d, B %d), %d human messages, %d harness messages dropped, %d incidental hints' % (
        a.topic, len(sel), sum(t['cls'] == 'A' for t in sel), sum(t['cls'] == 'B' for t in sel), nmsg,
        sum(dropped.values()), sum(t['incidental_hint'] for t in sel)))


if __name__ == '__main__':
    sys.exit(main())
