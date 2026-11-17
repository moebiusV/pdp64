#!/usr/bin/env python3
"""build_ctx.py: for each project's ledger subjects, collect the source messages (the author's words) and the end of the assistant turn
before each, rank them by signs of a stated rationale or a named precedent, and write batches for the rationale sweep.

  build_ctx.py PROJECT   -> docs/decision-log/data/PROJECT/rationale-in/NN.json   (a list of subjects with their sources)
                            docs/decision-log/data/PROJECT/rationale-none.json     (subjects with no sign: "none stated in the record")
"""
import collections, glob, json, os, re, sqlite3, sys

D = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'docs', 'decision-log', 'data')
DB = '/home/david/claude/ai-conversations/conversations.db'
SPRE = [('silentpc', '/home/david/claude/silentpc-archive/dot-claude/projects'),
        ('silentpc-opusplan', '/home/david/claude/silentpc-archive/dot-claude-opusplan/projects')]
AUTH_CUT, ASST_CUT, MAXSRC, BATCH = 700, 900, 5, 90000
RAT = re.compile(r"\b(because|since|so that|so we|so it|reason|why|in order to|to avoid|which means|that way|the point|better|worse|instead of|rather than|prefer|simpler|cheaper|faster|safer|safety|security|compat\w*|precedent|like the|as in|same as|just like|modeled|based on|otherwise|trade-?off|benefit|cost|less code|fewer|easier|harder|matches|consistent|standard|nobody|no one|everyone)\b", re.I)
PREC = re.compile(r"\b(PDP-?11|VAX|x86|amd64|AArch64|ARM\w*|RISC-?V|MIPS|SPARC|POWER\w*|PowerPC|s390x|6502|8502|C64|C128|Amiga|Unix|V[67]|BSD|OpenBSD|NetBSD|FreeBSD|Linux|Plan ?9|9front|QNX|Multics|TOPS-?10|DEC|IBM|LLVM|GCC|clang|pcc|yacc|bison|lex|ANTLR|PEG|ABNF|EBNF|BNF|META ?II|IMP\d*|Lua|newLISP|Lisp|Ada|Rust|Zig|Go|Python|C99|POSIX|PCIe|NVMe|USB|virtio|IOMMU|UEFI|OpenFirmware|ELF|Mach-O|SIMH|QEMU|Wayland|X11|ncurses|termcap|xterm|Blit|SID|VIC|JSON|YAML|TOML|XML|RFC ?\d+|TCP|Ethernet|9P|git|Debian|Alpine|apk|aports)\b")
seen_db = {}
db = sqlite3.connect('file:%s?mode=ro' % DB, uri=True)


def jsonl_assistant(tid):
    label, sid = tid.split(':')[0], tid.split(':')[1] if ':' in tid else ''
    res = []
    for lab, root in SPRE:
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
                            res.append((seq, o.get('timestamp', ''), cc))
    return res


JC = {}


def assistant_before(thread, seq, ts):
    t = str(thread)
    if t.isdigit():
        if isinstance(seq, str):
            r = db.execute("select content from messages where thread_id=? and role='assistant' and content_type='text' and created_at<? order by sequence_num desc limit 1", (int(t), ts)).fetchone()
        else:
            r = db.execute("select content from messages where thread_id=? and role='assistant' and content_type='text' and sequence_num<? order by sequence_num desc limit 1", (int(t), seq)).fetchone()
        return (r[0] if r else '') or ''
    if t.startswith('hist-'):
        return ''
    if t not in JC:
        JC[t] = jsonl_assistant(t)
    prev = [x for x in JC[t] if (x[1] < ts if isinstance(seq, str) else x[0] < seq)]
    return prev[-1][2] if prev else ''


CHAINS = {'pdp64': ['/part2/A-instruction-set-fpga.md', '/part2/E-why-32.md', '/part2/B-toolchain.md', '/part2/C-documentation-process.md', '/part2/D-system.md'],
          'imp72': ['/part2c/imp72.md'], 'hbnf': ['/part2/hbnf-1.md', '/part2/hbnf-2.md', '/part2/hbnf-3.md']}


def chains(project):
    res = {}
    for rel in CHAINS[project]:
        path = D + '/' + project + rel
        if not os.path.exists(path):
            continue
        cur = None
        for line in open(path):
            line = line.rstrip('\n')
            if line.startswith('### '):
                cur = []; res[re.sub(r'\s*\([^()]*\)\s*$', '', line[4:].strip())] = cur
            elif line.startswith('## '):
                cur = None
            elif cur is not None and line.strip():
                cur.append(line)
    return res


def main(project):
    msgs = {}
    CH = chains(project)
    for f in glob.glob(D + '/*/messages.broad.jsonl') + glob.glob(D + '/hbnf/messages.all.jsonl') + glob.glob(D + '/*/messages.jsonl'):
        for l in open(f):
            m = json.loads(l)
            msgs.setdefault('%s:%s' % (m['thread'], m['seq']), m)
    subs = []
    for f in sorted(glob.glob(D + '/%s/ledger/*.md' % project), key=lambda p: (len(os.path.basename(p)), p)):
        cur = None
        for line in open(f):
            line = line.rstrip('\n')
            if line.startswith('## Summary'):
                cur = None
            elif line.startswith('### '):
                cur = dict(title=line[4:].strip(), lines=[]); subs.append(cur)
            elif line.startswith('## '):
                cur = None
            elif cur is not None and line.strip():
                cur['lines'].append(line)
    out_batches, none, cur, size, nb = [], [], [], 0, 0
    nsrc = 0
    for s in subs:
        ids = []
        for l in s['lines']:
            for m in re.finditer(r'\[([^\]\[]+?)#j?\d+\]', l):
                pass
        srcs = []
        chain = CH.get(re.sub(r'\s*\([^()]*\)\s*$', '', s['title']), [])
        s['chain'] = chain
        for l in s['lines'] + chain:
            for m in re.finditer(r'\[([^\]\[]+?)#\d+\]', l):
                if m.group(1) not in srcs:
                    srcs.append(m.group(1))
        decided = [m.group(1) for l in s['lines'] if l.startswith('- Decided') for m in re.finditer(r'\[([^\]\[]+?)#\d+\]', l)]
        cand = []
        for sr in srcs:
            m = msgs.get(sr)
            if not m:
                continue
            a = assistant_before(m['thread'], m['seq'], m['ts'])
            au = m['text']
            score = 2 * bool(RAT.search(au)) + 2 * bool(PREC.search(a[-ASST_CUT * 2:])) + 1 * bool(PREC.search(au)) + (3 if sr in decided else 0) + min(2, len(au) // 400)
            cand.append((score, sr, m, a))
        cand.sort(key=lambda x: -x[0])
        signal = any(RAT.search(c[2]['text']) or PREC.search(c[3][-ASST_CUT * 2:]) or PREC.search(c[2]['text']) for c in cand)
        if not signal:
            none.append(s['title']); continue
        srcrecs = []
        for score, sr, m, a in cand[:MAXSRC]:
            a = a.strip().replace('\n', ' ')
            srcrecs.append(dict(src=sr, ts=m['ts'][:16], author=m['text'][:AUTH_CUT] if len(m['text']) <= AUTH_CUT else m['text'][:AUTH_CUT // 2] + ' [...] ' + m['text'][-AUTH_CUT // 2:],
                                assistant_before=('...' + a[-ASST_CUT:]) if len(a) > ASST_CUT else a))
        rec = dict(subject=s['title'], block=s['lines'], chain_found=bool(chain), sources=srcrecs)
        n = len(json.dumps(rec, ensure_ascii=False))
        if size + n > BATCH and cur:
            out_batches.append(cur); cur, size = [], 0
        cur.append(rec); size += n; nsrc += len(srcrecs)
    if cur:
        out_batches.append(cur)
    od = os.path.join(D, project, 'rationale-in')
    os.makedirs(od, exist_ok=True)
    for f in glob.glob(od + '/*.json'):
        os.remove(f)
    for i, b in enumerate(out_batches, 1):
        json.dump(b, open(os.path.join(od, '%02d.json' % i), 'w'), ensure_ascii=False, indent=0)
    json.dump(none, open(os.path.join(D, project, 'rationale-none.json'), 'w'), ensure_ascii=False, indent=0)
    print('%s: %d subjects; %d with a sign of rationale or precedent in %d batches (%d sources); %d with none' % (project, len(subs), len(subs) - len(none), len(out_batches), nsrc, len(none)))


if __name__ == '__main__':
    for p in sys.argv[1:]:
        main(p)
