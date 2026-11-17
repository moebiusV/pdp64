#!/usr/bin/env python3
"""assemble.py TOPIC TITLE DATADIR SHARED OUT.md [--extra FILE.json]

Assembles the decision log for a topic from:
  DATADIR/threads.json, messages.jsonl   (extract.py)
  SHARED/condensed.jsonl                 (condensation agents; Part I lines)
  DATADIR/part2/*.md                     (consolidation agents; Part II chains: "## category" / "### subject" / bullets)
  DATADIR/part2-extra.json (optional)    hand additions {"subject": {"now": line, "lines": [..]}} (each added line carries its source id)
into one Markdown file: title, how to read it, a table of contents, Part I (month / day / thread), Part II (category /
subject), appendices (sources, threads mentioned only in passing, where the repository differs from the chains).
Single-line point form throughout.
"""
import collections, json, os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import part1

topic, title, data, shared, out = sys.argv[1:6]
TERMS_TEXT = sys.argv[6] if len(sys.argv) > 6 else 'pdp-11, pdp11, pdp64, pdp-64, commodore 64'
CATS = ["01 Principles and priorities", "02 Bus", "03 Graphics and the C64 devices", "04 Boot", "05 Drivers and devices",
        "06 Kernel, modes and memory management", "07 Multiple processors", "08 Vector work and accelerators",
        "09.1 Instruction set: encoding", "09.2 Instruction set: registers", "09.3 Instruction set: addressing modes",
        "09.4 Instruction set: alignment and memory model", "09.5 Instruction set: instruction groups",
        "09.6 Instruction set: fused pairs and compiler idioms", "10 FPGA and silicon", "11 Toolchain",
        "12 Documentation and process"]
if topic != 'pdp64':
    CATS = ["01 Goals and priorities", "02 Language and compiler design", "03 Bootstrap and port to Linux",
            "04 Code generation and targets", "05 Runtime and library", "06 Testing and verification",
            "07 Packaging and release", "08 Documentation and process", "09 Relation to hbnf, pcc and other projects"]
esc = part1.esc


def parse_fragment(path):
    """-> {cat: [(subject, [lines])]}"""
    res = collections.OrderedDict()
    cat = subj = None
    for line in open(path):
        line = line.rstrip('\n')
        if line.startswith('## '):
            cat = line[3:].strip(); res.setdefault(cat, []); subj = None
        elif line.startswith('### '):
            subj = (line[4:].strip(), []); res[cat].append(subj)
        elif line.strip() and subj is not None:
            subj[1].append(line)
    return res


def first_date(lines):
    ds = [m.group(1) for l in lines for m in [re.search(r'(\d{4}-\d\d-\d\d)', l)] if m]
    return min(ds) if ds else '9999'


def esc_line(l):
    m = re.match(r'^(\s*- )(.*)$', l)
    if not m:
        return esc(l)
    return m.group(1) + esc(m.group(2))


def slug(s, seen):
    s = re.sub(r'[^\w\s-]', '', s.lower()).strip()
    s = re.sub(r'\s+', '-', s)
    n = seen[s]; seen[s] += 1
    return s if n == 0 else '%s-%d' % (s, n)


# ---- Part II
frag = collections.OrderedDict((c, []) for c in CATS)
pdir = os.path.join(data, 'part2')
for fn in sorted(os.listdir(pdir)):
    if fn.endswith('.md'):
        for cat, subs in parse_fragment(os.path.join(pdir, fn)).items():
            frag.setdefault(cat, [])
            if not fn.startswith('E-'):
                frag[cat] += subs
# E-why first in its category
for fn in sorted(os.listdir(pdir)):
    if fn.startswith('E-'):
        for cat, subs in parse_fragment(os.path.join(pdir, fn)).items():
            frag[cat] = subs + frag[cat]
extra = {}
if os.path.exists(os.path.join(data, 'part2-extra.json')):
    extra = json.load(open(os.path.join(data, 'part2-extra.json')))
for cat, subs in frag.items():
    for subj in subs:
        if subj[0] in extra:
            e = extra[subj[0]]
            rest = [l for l in subj[1] if not l.startswith('- Now:')]
            add = ['- ' + x for x in e['lines']]
            k = next((i for i, l in enumerate(rest) if l.startswith('- Potential:')), len(rest))
            subj[1][:] = ['- Now: ' + e['now']] + rest[:k] + add + rest[k:]
PREC = '(older; the later line takes precedence)'
for cat, subs in frag.items():
    for name, lines in subs:
        dated = [i for i, l in enumerate(lines) if re.match(r'^- \d{4}-\d\d-\d\d ', l)]
        for i, l in enumerate(lines):
            if '(relation unclear' in l and dated and i != dated[-1] and not l.startswith('- Now:'):
                lines[i] = re.sub(r'\(relation unclear[^)]*\)', PREC, l)
for cat in frag:
    frag[cat].sort(key=lambda s: first_date(s[1]))

# ---- counts and appendices
T = json.load(open(os.path.join(data, 'threads.json')))['threads']
p1, st, TT = part1.build(data, shared)
checks = []
ids = set()
for cat, subs in frag.items():
    for name, lines in subs:
        for l in lines:
            if l.startswith('- Check:'):
                checks.append((cat, name, l[2:]))
            ids.update(re.findall(r'\[([^\]\[]+#j?\d+)\]', l))
nrec = len(ids)

n99 = sum(1 for fn in os.listdir(os.path.join(data, 'dec-out')) for l in open(os.path.join(data, 'dec-out', fn)) if '"cat": "99' in l)
L = []
L += ['# ' + title, '']
dates = sorted(json.loads(l)['ts'][:10] for l in open(os.path.join(data, 'messages.jsonl')))
L += ['## About this log', '',
      '- What it is: the author\'s own instructions to AI assistants about the %s, in order (Part I), and from the start of the design his decisions, changes and open ideas, grouped by the structure of the manual (Part II).' % topic,
      '- Form: single-line points, so that it can be annotated; each point ends with its source `[thread#message]`.',
      '- Source `thread#message`: the thread number in the conversation archive (Chronicle) and the message number in it; `j` numbers are messages found only in the Claude Code session files (typed while the assistant was working, feedback on a rejected plan, answers to questions); `h` numbers are prompts found only in `history.jsonl`; `silentpc` threads are sessions copied from the other machine.',
      '- Part I: one line per message of the author. A message of %d characters or fewer is quoted whole; a longer one is a one-line condensation with his key words quoted. Times are UTC as recorded.' % part1.SHORT,
      '- Part II statuses: decided; approved-proposal (he accepted the assistant\'s proposal); changed; reversed; rejected; potential (an idea he raised or entertained, not rejected and not decided); unclear (what a reply referred to cannot be told from the record).',
      '- Precedence (the author, 2026-11-10): more recent decisions have greater precedence; where two lines of a subject disagree, the later one stands, and an earlier line whose relation to a later one the lines do not settle is marked as older.',
      '- Each subject starts with `Now:`, the latest line that stands, then the chain oldest to newest; `(superseded <date>)` and `(changes <date> ...)` mark replacements; `(relation unclear)` marks a pair the lines do not settle.',
      '- `Errata:` names the entry of the repository that records the same decision; `Check:` quotes repository text that differs from the chain\'s current state (collected in Appendix B).',
      '- Coverage: %d threads, %s to %s; %d messages of the author in Part I; %d decision records in Part II, %d more in Appendix D.' % (
          len(T), dates[0], dates[-1], st['lines'], nrec, n99),
      '- Not yet included: the ChatGPT archive (the conversation archive holds none; import it and rebuild).',
      '- Checked, not guessed: every line is a condensation of a recorded message and carries its source; condensations were written by assistant agents from the messages and have not been read by the author; see Appendix A for the method.', '']

# TOC
seen = collections.Counter()
for h in ['About this log', 'Contents']:
    slug(h, seen)
toc = ['## Contents', '', '- [About this log](#about-this-log)']
p1_heads = [l for l in p1 if l.startswith('## ')]
toc.append('- [Part I. The instructions, in order](#part-i-the-instructions-in-order)')
slug('Part I. The instructions, in order', seen)
for h in p1_heads:
    toc.append('  - [%s](#%s)' % (h[3:], slug(h[3:], seen)))
toc.append('- [Part II. The decisions, by the structure of the manual](#part-ii-the-decisions-by-the-structure-of-the-manual)')
slug('Part II. The decisions, by the structure of the manual', seen)
catanch = {}
for cat, subs in frag.items():
    if not subs:
        continue
    a = slug(cat, seen); catanch[cat] = a
    toc.append('  - [%s](#%s)' % (cat, a))
    for name, _ in subs:
        toc.append('    - [%s](#%s)' % (esc(name), slug(name, seen)))
for h in ['Appendix A. Sources and method', 'Appendix B. Where the repository differs from the chains',
          'Appendix C. Threads that mention the terms only in passing', 'Appendix D. Decisions outside the design of the %s' % topic]:
    toc.append('- [%s](#%s)' % (h, slug(h, seen)))
L += toc + ['']

# Part I (re-slug headings consumed above in the same order so anchors match)
L += ['# Part I. The instructions, in order', ''] + p1

# Part II (anchors: slugs were assigned in toc order, so rebuild in the same order for headings; Markdown autoslugs them)
L += ['# Part II. The decisions, by the structure of the manual', '']
for cat, subs in frag.items():
    if not subs:
        continue
    L += ['## ' + cat, '']
    for name, lines in subs:
        L += ['### ' + esc(name)]
        L += [esc_line(l) for l in lines]
        L += ['']

# Appendices
L += ['# Appendix A. Sources and method', '',
      '- Archive: the Chronicle database (`ai-conversations/conversations.db`): claude.ai, Grok, Grok via X and Claude Code sessions of this machine.',
      '- Other machine (silentpc): its `.claude` and `.claude-opusplan` `projects/` folders and `history.jsonl` files were copied with scp; sessions are read directly from the files; prompts of sessions whose files no longer exist are taken from `history.jsonl`.',
      '- Messages Chronicle does not keep (typed while the assistant was working, feedback typed when a plan was rejected, answers to the assistant\'s questions) were read from the session files.',
      '- Selection: a thread is included when its title or visible text (the author\'s and the assistant\'s text, not thinking or tool output) contains a strong term (%s) or, for a few, only a whole-word weak term.' % TERMS_TEXT,
      '- Passing mentions: no message of the author in the thread contains a term and the thread has at most two mentions overall; they are listed in Appendix C, not logged message by message.',
      '- Harness text that the session files store as user messages (task notifications, subagent reports, reminders) is not the author\'s and is excluded.',
      '- Condensation: assistant agents wrote the one-line forms and the Part II records from the messages (with the end of the assistant\'s previous turn for context); a consolidation pass grouped them into subjects and cross-checked them against `docs/errata.md`, `docs/decisions-pending.md`, `docs/priority-lists.md` and `docs/smp-decisions.md`.',
      '- Spot-check: 20 random Part II records were compared with their source messages: the wording is faithful in all 20; the status of one is doubtful (592#27, a question recorded as decided). The Part I lines were checked for completeness (every selected message has one), not line by line.',
      '- Limits: the condensations and the status of each record are not reviewed by the author; a short reply is only interpreted where the assistant\'s previous turn makes its referent plain.', '']
L += ['# Appendix B. Where the repository differs from the chains', '']
if checks:
    cur = None
    for cat, name, l in checks:
        L.append('- %s: %s' % (esc(name), esc(l[len('Check: '):] if l.startswith('Check: ') else l)))
else:
    L.append('- None found.')
L += ['']
L += ['# Appendix C. Threads that mention the terms only in passing', '']
for t in sorted(TT.values(), key=lambda t: (t['created'] or '', str(t['id']))):
    if part1.passing(t):
        L.append('- %s, %s, thread %s: %s (%d mentions, %d messages by the author)' % (
            (t['created'] or '')[:10], t['platform'], t['id'], esc(t['title'] or '(untitled)')[:80],
            t['strong_user'] + t['strong_asst'] + t['weak_hits'], t['human_messages']))
# records the agents marked as not about this topic's design (kept so nothing is lost)
other = []
od = os.path.join(data, 'dec-out')
for fn in sorted(os.listdir(od)):
    for l in open(os.path.join(od, fn)):
        try:
            r = json.loads(l)
        except ValueError:
            continue
        if r['cat'].startswith('99'):
            other.append(r)
L += ['# Appendix D. Decisions outside the design of the %s' % topic, '',
      '- Records the extraction judged to concern other work (other compiler back ends and repository housekeeping); they are not in Part II. Their messages are in Part I.', '']
topics = collections.OrderedDict()
for r in sorted(other, key=lambda r: r['ts']):
    topics.setdefault(r['topic'], []).append(r)
for tp, rs in topics.items():
    L.append('- %s' % esc(tp))
    for r in rs:
        L.append('  - %s %s: %s [%s]' % (r['ts'][:10], r['status'], esc(r['line']), esc(r['id'])))
L += ['']
open(out, 'w').write('\n'.join(L) + '\n')
print('%s: %d lines of Markdown; Part I %d lines; Part II %d subjects, %d records; %d Check lines' % (
    out, len(L), st['lines'], sum(len(s) for s in frag.values()), nrec, len(checks)))
