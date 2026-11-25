#!/usr/bin/env python3
"""evolution.py: write docs/design/src/appendix-g-evolution.md, "The evolution of the design", from the pdp64 rationale sweep (tools/mkmanual.py copies it to docs/design/evolution.md).

G.1 how it grew: the founding question (the author's account and his earliest messages) and the stages, each with its date and time.
G.2 the influences, inspirations and precedents in the order they were introduced: one line each, date and time first.
Sources: docs/decision-log/data/pdp64/{rationale/*.json, dec-out/*.jsonl, messages*.jsonl}; the author's first chats of 2026-08-23.
"""
import collections, glob, json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from part1 import esc

R = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
D = os.path.join(R, 'docs', 'decision-log', 'data') + '/'
OUT = os.path.join(R, 'docs', 'design', 'src', 'appendix-g-evolution.md')
M = {}
for f in glob.glob(D + '*/messages.broad.jsonl') + glob.glob(D + 'hbnf/messages.all.jsonl') + glob.glob(D + '*/messages.jsonl'):
    for l in open(f):
        m = json.loads(l); M.setdefault('%s:%s' % (m['thread'], m['seq']), m)
TS = {}
for f in glob.glob(D + 'pdp64/dec-out/*.jsonl'):
    for l in open(f):
        try:
            r = json.loads(l)
        except ValueError:
            continue
        TS[r['id']] = r['ts']


def stamp(ts):
    return ts[:10] + ' ' + ts[11:16]


def msg_ts(src):
    return M[src]['ts'] if src in M else ''


CANON = {}
if os.path.exists(D + 'shared/precedent-canon.json'):
    CANON = json.load(open(D + 'shared/precedent-canon.json'))
canon = lambda n: CANON.get(n.strip(), n.strip())
ev = []
for f in sorted(glob.glob(D + 'pdp64/rationale/*.json')):
    for r in json.load(open(f)):
        for x in r['precedents']:
            src = x.get('id', '').strip('[]')
            if src not in M:
                continue
            ev.append(dict(name=canon(x['name']), stance=x['stance'], by=x['named_by'], ts=M[src]['ts'][:16],
                           subject=re.sub(r'\s*\([^()]*\)\s*$', '', r['subject']), note=x.get('note', '').strip(), src=src))
# the referents named in the first chats of 2026-08-23 (before the design had a name), from the author's own questions
for name, src, note in [
        ('Blit terminal', '813:0', 'asked how much memory it needs and whether the PDP-11 could use it'),
        ('Plan 9', '813:8', 'asked how Plan 9 did demand paging'),
        ('VAX ISA and DEC Alpha', '813:14', 'asked how the VAX instruction set compares with the Alpha and the PDP-11'),
        ('DEUNA and DELUA network cards', '813:16', 'asked about their history and how much of the sockets API and TCP stack they provided'),
        ('SIMH', '813:22', 'asked what it supports'),
        ('Qbus and Unibus against PCI and SCSI', '813:24', 'asked how they differ from modern buses'),
        ('Linux and Plan 9 virtual memory', '519:0', 'asked which is better for the 32V virtual-memory retrofit')]:
    if src in M:
        ev.append(dict(name=canon(name), stance='considered', by='author', ts=M[src]['ts'][:16], subject='', note=note, src=src))
norm = lambda n: re.sub(r'[^a-z0-9]+', ' ', n.lower()).strip()
g = collections.OrderedDict()
for e in sorted(ev, key=lambda e: e['ts']):
    g.setdefault(norm(e['name']), []).append(e)
WHO = {'author': 'named by the author', 'assistant, accepted': 'proposed by the assistant, accepted', 'assistant, not taken up': 'proposed by the assistant, not taken up'}
lines = []
for k, es in g.items():
    f = es[0]
    later = []
    seen = {f['stance']}
    for e in es[1:]:
        if e['stance'] not in seen:
            seen.add(e['stance']); later.append('%s %s' % (e['stance'], stamp(e['ts'])))
    txt = '- %s · %s · %s · %s' % (stamp(f['ts']), esc(f['name']), WHO.get(f['by'], f['by']), f['stance'])
    body = esc(f['note']) if f['note'] else ''
    if f['subject']:
        body = (esc(f['subject']) + (': ' + body if body else ''))
    if body:
        txt += ' — ' + body
    txt += ' (%s)' % esc(f['src'])
    if later:
        txt += '; later ' + ', '.join(later[:3])
    lines.append(txt)

# the stages
def first(subject, key=None):
    for fn in sorted(glob.glob(D + 'pdp64/part2/[A-E]*.md')):
        cur = None
        for l in open(fn):
            l = l.rstrip('\n')
            if l.startswith('### '):
                cur = l[4:]
            elif l.startswith('## '):
                cur = None
            elif cur == subject and l.startswith('- 20'):
                m = re.search(r'\[([^\]\[]+#\d+)\]', l)
                if m:
                    yield l, m.group(1), TS.get(m.group(1), '')


def stage(subject, text, phrase=None):
    cands = sorted(first(subject), key=lambda t: t[2])
    if phrase:
        cands = [c for c in cands if phrase.lower() in c[0].lower()]
    if not cands:
        print('WARNING: no record for', subject, phrase)
        return None
    pick = 0
    l, i, ts = cands[pick]
    return '- %s — %s (%s)' % (stamp(ts), text, esc(i.split('#')[0]))


stages = [
    '- 2026-08-23 05:50 — the founding question, in his first message about it: an Ethernet card "that held the entire tcp ip udp icmp stack inside itself ... so that a pdp11 could plug it in and use it", and whether the PDP-11 could use the Blit terminal (813:0)',
    '- 2026-08-23 05:58 — wider addresses: "was there a 22 bit pdp11?" (813:6); at 06:19: "What if all addresses were expanded to 22 bit? ... an update to the pdp11 arch" (813:10)',
    '- 2026-08-23 06:21 — "Is there pdp11 fpga?" (813:12); at 06:46: "Could I have dozens of pdp11 on a postage stamp? How about the blit?" with 24-bit colour and 1024x768 (813:18)',
    '- 2026-08-23 19:54 — "combine 8 pdp11 systems plus one blit system and a smart nic ethernet card all together on one silicon die" (519:2)',
    '- 2026-08-28 19:31 — "if one implemented pdp11 without the peripherals, what is involved?" (792:0)',
    stage('MMU and FP units included', 'the first design brief: "assume mmu and fp units"; in the same message the C64 graphics and audio, a modern USB keyboard and mouse and an NVMe disk are asked for', 'assume mmu and fp units'),
    stage('Mashup of PDP-11 with C64 / M8502', 'the 8502 chosen over the plain C64 as the partner: "they seem much closer to each other"; the same message fixes little-endian and a 200 to 300 MHz FPGA clock', 'm8502 is sounding pretty sweet'),
    "- %s — the Blit as the terminal, mashed up with the C64: \"could we revamp the blit to be c64 adjacent\", since \"c64 is superior to blit terminal in many ways\" (531:0)" % stamp(TS.get('531:0#6', '2026-08-29T00:29')),
    "- %s — the terminal takes the C64's audio: a Blitter terminal \"based on a modernized and updated c64 with sid chip and also modern 48 bit audio and 48 bit pixels\" (1889:2704)" % stamp(TS.get('1889:2704#2', '2026-10-23T00:00')),
    stage('Register width', 'the 32-bit step skipped: "skip 32 bit version and go straight to 64bit"', 'skip 32 bit version'),
    stage('Widening the PDP-11 to 64 bits', 'and the widening stated: "basically upgrade pdp-11 straight to 64 bit"', 'upgrade pdp-11 straight to 64 bit'),
    stage('Data alignment', 'a constraint on the widening: "only 2 byte memory alignment; don\'t put 8 byte memory alignment constraints"', 'only 2 byte memory alignment'),
    stage('Standard GPU, NIC and audio interfaces', 'devices become standard hardware on the bus: "we can put standard gpu on the bus too?"', 'standard gpu on the bus'),
    stage('SMP and its decisions document', 'multiprocessing enters: what the design needs "to allow smp, symmetric mutiprocessing"', 'allow smp'),
    stage('In-order cores, ready for out-of-order', 'the ambition of a large machine: "ready for the out of order large scale design"', 'out of order large scale'),
    stage('Mode bits and the "no mode bits" rule', 'the early rule of no mode bits becomes "a very soft rule"', 'very soft rule'),
    stage('Design priority list', 'the priorities written down: "code size, easy recoverability, and speed/efficiency through fewer gates and tighter hot loops"', 'code size, easy recoverability'),
    stage('Constant-time execution', 'security as a design goal: "there should be constant time flag ... so instructions always take an equal amount of time"', 'constant time flag'),
    stage('Address space (VAX I/O space)', 'the VAX idea of a device space in the address map is added to the book', 'vax does this io space'),
    '- 2026-11-04 00:07 — the bus becomes PCI Express with NVMe and USB, with the security fixes of the pain-points document',
    stage('Dedicated core classes', 'cores dedicated to devices: "also one core for audio processing, doing midi, dsp, etc."', 'one core for audio processing'),
    stage('Prefix-coded encodings, 16-register and 32-register grammars', 'a new instruction encoding: "an encoding scheme that minimizes code size and fits them all in with 32 reg and with 16 reg"', 'encoding scheme that minimizes code size'),
    stage('The pdp64 family', '"the pdp64 now has children, the pdp64/32 and pdp64/16"', 'now has children'),
    stage('Core counts', 'the first device: "4 cores is enough hopefully that fits on the fpga"', '4 cores is enough'),
    "- 2026-11-08 02:37 — the link between Commodore and DEC found: \"I found the evidence, there IS a link between C64 and DEC!\" (1882:354). The source, a Commodore history of the industrial designer Ira Velinsky, shows one designer who worked for both companies (section 1.1). The author's own description, 2026-11-10 06:47: \"the smoking gun that there was indeed intercourse between dec and commodore\" (1882:j7644)",
    stage('Bus update to virtio-only', 'virtio across the board for the devices, approved for the bus chapter', 'go ahead and update the bus chapter'),
    '- 2026-11-10 05:30 — "pdp64/32 is the decided upon pdp64"; r20 and pdp64/16 are tested alternatives, no longer part of it (1882:j4575)',
]
stages = sorted((x for x in stages if x), key=lambda x: x[2:18])
head = ['# The evolution of the design', '', '[← manual index](../manual/00-index.md)', '',
        '**The design began as a small question and grew by steps.** In the author\'s words of 2026-11-10: "we started off as a pdp16 modernized a tiny bit, then got more and more ambitious", and "the initial idea was, could a pdp16 run effectively today with a blit terminal and off-loaded 8-register nic", with "the blit being a mashup with the c64 for audio". This appendix lists, in point form, how it grew and which influences, inspirations and precedents entered, each with the date and time (UTC) of the message in which it first appeared.', '',
        '## G.1 How it grew', '']
mid = ['', '## G.2 The influences, inspirations and precedents, in the order they were introduced', '',
       '* Each line: date and time of the first message that named it · the referent · who named it · its stance when introduced (**chosen**: the choice follows it; **rejected**: turned down; **considered**: compared or cited, not decided) · the part of the design it bears on · the source in parentheses (archive thread and message number, or `j` for a message found only in the session files).',
       '* "Later" gives the first date and time at which its stance changed, where it did.',
       '* Only what the messages say: a referent proposed by the assistant is marked so, and counts as an influence only where its line says it was accepted.', '']


def scrub(t):
    """The manual does not use the name Q64 (the bus is PCI Express) and does not name the three native devices (errata of 2026-11-10)."""
    t = re.sub(r'\b(?:the )?[Qq]64 bus\b', lambda m: 'the bus' if m.group(0)[0] == 't' else 'The bus', t)
    t = re.sub(r'\bQ64\b', 'PCI Express', t)
    t = re.sub(r'\bq64\b', 'the bus', t)
    t = re.sub(r'`?\b(?:VIC-64X|SID-64X|BLT64)\b`?', 'the native device', t, flags=re.I)
    return t


open(OUT, 'w').write(scrub('\n'.join(head + stages + mid + lines) + '\n'))
print('%d stages, %d referents -> %s' % (len(stages), len(lines), OUT))
