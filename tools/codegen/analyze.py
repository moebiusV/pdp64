#!/usr/bin/env python3
"""analyze.py RUN: statistics of a pdp64size run (/tmp/p64opt/RUN/results.json and the kept .s files) -> /tmp/p64opt/analysis/*.csv, analysis.json"""
import json, sys, os, re, glob, collections, csv

run = sys.argv[1]
D = '/tmp/p64opt/%s' % run
OUT = '/tmp/p64opt/analysis'
os.makedirs(OUT, exist_ok=True)
res = json.load(open(D + '/results.json'))
by = collections.defaultdict(dict)
for x in res:
    if 'ins' in x:
        by[x['src']][x['arch']] = x
ARCHS = ('pdp64', 'amd64', 'gcc-Os', 'clang-Os')
fair = {s: v for s, v in by.items() if all(a in v for a in ARCHS)}
corp = {s: v['pdp64']['corp'] for s, v in fair.items()}
J = {}


def w(name, header, rows):
    with open('%s/%s.csv' % (OUT, name), 'w', newline='') as f:
        c = csv.writer(f)
        c.writerow(header)
        c.writerows(rows)


# (a) totals
corps = sorted(set(corp.values()))
rows = []
for c in corps + ['ALL']:
    ss = [s for s in fair if c == 'ALL' or corp[s] == c]
    r = [c, len(ss)]
    t = {}
    for a in ARCHS:
        t[a] = (sum(fair[s][a]['ins'] for s in ss), sum(fair[s][a]['image'] for s in ss))
        r += list(t[a])
    for ref in ('gcc-Os', 'clang-Os', 'amd64'):
        r += ['%.3f' % (t['pdp64'][0] / t[ref][0]), '%.3f' % (t['pdp64'][1] / t[ref][1])]
    rows.append(r)
    J.setdefault('totals', {})[c] = {a: t[a] for a in ARCHS}
w('totals', ['corpus', 'files'] + ['%s_%s' % (a, k) for a in ARCHS for k in ('ins', 'bytes')] +
  ['pdp64/%s_%s' % (ref, k) for ref in ('gcc-Os', 'clang-Os', 'amd64') for k in ('ins', 'bytes')], rows)

# (b) lengths
H = collections.Counter()
for s in fair:
    for k, v in fair[s]['pdp64']['hist'].items():
        H[int(k)] += v
n = sum(H.values())
nb = sum(k * v for k, v in H.items())
J['pdp64_len'] = dict(hist=dict(H), n=n, bytes=nb, avg=nb / n)
XL = {}
for a in ('gcc-Os', 'clang-Os'):
    h = collections.Counter()
    for s in fair:
        for k, v in fair[s][a].get('xlen', {}).items():
            h[int(k)] += v
    XL[a] = h
    J[a + '_len'] = dict(hist=dict(h), n=sum(h.values()), bytes=sum(k * v for k, v in h.items()),
                         avg=sum(k * v for k, v in h.items()) / max(1, sum(h.values())))
w('lengths_pdp64', ['bytes', 'instructions'], sorted(H.items()))
for a in XL:
    w('lengths_' + a, ['bytes', 'instructions'], sorted(XL[a].items()))

# (c) pdp64 mnemonics, shapes, pairs, bigrams, trigrams, cost centres
MN = collections.Counter(); PR = collections.Counter(); MO = collections.Counter(); ML = collections.Counter()
BG = collections.Counter(); TG = collections.Counter(); CA = collections.Counter(); LG = collections.Counter()
for s in fair:
    x = fair[s]['pdp64']
    MN.update(x['mn']); PR.update(x['pair']); MO.update(x['modes']); ML.update(x['modelen'])
    BG.update(x['bigram']); TG.update(x['trigram']); CA.update(x['cats']); LG.update(x['longs'])
tot = sum(MN.values())
cum = 0
rows = []
for i, (k, v) in enumerate(MN.most_common(), 1):
    cum += v
    rows.append([i, k, v, '%.2f' % (100 * v / tot), '%.2f' % (100 * cum / tot)])
w('mnemonics_pdp64', ['rank', 'mnemonic', 'count', 'share%', 'cumulative%'], rows)
w('shapes_pdp64', ['mode', 'operands', 'in 2-byte', 'in 4-byte', 'in 6-byte', 'in 8-byte'],
  [[m, v] + [ML['%s/%d' % (m, l)] for l in (2, 4, 6, 8)] for m, v in MO.most_common()])
w('pairs_pdp64', ['mnemonic shapes', 'count', 'share%'], [[k, v, '%.2f' % (100 * v / tot)] for k, v in PR.most_common(60)])
w('bigrams_pdp64', ['first ; second', 'count', 'share of instructions %'], [[k, v, '%.2f' % (100 * v / tot)] for k, v in BG.most_common(60)])
w('trigrams_pdp64', ['first ; second ; third', 'count'], [[k, v] for k, v in TG.most_common(40)])
w('long_forms_pdp64', ['length mnemonic shapes', 'count'], [[k, v] for k, v in LG.most_common(40)])
ti = sum(v for k, v in CA.items() if not k.startswith('bytes:'))
tb = sum(v for k, v in CA.items() if k.startswith('bytes:'))
w('costcentres_pdp64', ['category', 'instructions', 'ins%', 'bytes', 'bytes%'],
  [[k[6:], CA[k[6:]], '%.1f' % (100 * CA[k[6:]] / ti), v, '%.1f' % (100 * v / tb)] for k, v in sorted(CA.items(), key=lambda kv: -kv[1]) if k.startswith('bytes:')])
J['pdp64_mn'] = dict(MN)

# x86: mnemonic and operand shapes from the kept .s of gcc and clang, on the same files
FOLD = re.compile(r'^(mov|add|sub|cmp|test|lea|and|or|xor|shl|shr|sar|sal|imul|inc|dec|neg|not|push|pop|adc|sbb|cmov\w+|set\w+)([bwlq])$')


def x86shape(op):
    op = op.strip()
    if op.startswith('$'):
        return 'imm'
    if op.startswith('%') and '(' not in op:
        return 'reg'
    if '%rip' in op:
        return 'rip'
    if '(' in op:
        return 'mem-index' if op.count('%') >= 2 else 'mem-base'
    if op.startswith('*'):
        return 'indirect'
    return 'sym'


def x86stats(arch):
    mn = collections.Counter(); sh = collections.Counter(); pr = collections.Counter(); bg = collections.Counter()
    for s in fair:
        path = '%s/s/%s_%s.s' % (D, arch, s.replace('/', '_'))
        if not os.path.exists(path):
            continue
        prev = None
        sec = 'text'
        for line in open(path, errors='replace'):
            line = line.split('#')[0].strip()
            while True:
                m = re.match(r'^[\w.$]+:\s*(.*)$', line)
                if not m:
                    break
                line = m.group(1).strip()
                prev = None
            if not line:
                continue
            if line.startswith('.'):
                w0 = line.split()[0]
                if w0 == '.text':
                    sec = 'text'
                elif w0 in ('.data', '.bss', '.rodata') or (w0 == '.section' and '.text' not in line):
                    sec = 'data'
                elif w0 == '.section':
                    sec = 'text'
                continue
            if sec != 'text':
                continue
            parts = line.split(None, 1)
            m0 = parts[0]
            if m0 in ('rep', 'repz', 'repnz', 'lock') and len(parts) > 1:
                parts = parts[1].split(None, 1)
                m0 = m0 + ' ' + parts[0]
            ops = []
            if len(parts) > 1:
                cur, depth = '', 0
                for ch in parts[1]:
                    if ch == '(':
                        depth += 1
                    elif ch == ')':
                        depth -= 1
                    if ch == ',' and depth == 0:
                        ops.append(cur); cur = ''
                    else:
                        cur += ch
                ops.append(cur)
            f = FOLD.match(m0)
            mf = f.group(1) if f else m0
            if mf.startswith(('j', 'call')):
                shapes = ('target',)
            else:
                shapes = tuple(x86shape(o) for o in ops)
            mn[mf] += 1
            for x in shapes:
                sh[x] += 1
            key = mf + ' ' + ','.join(shapes)
            pr[key] += 1
            if prev:
                bg[prev + ' ; ' + key] += 1
            prev = key
    return mn, sh, pr, bg


for a in ('gcc-Os', 'clang-Os'):
    mn, sh, pr, bg = x86stats(a)
    t = sum(mn.values())
    cum = 0
    rows = []
    for i, (k, v) in enumerate(mn.most_common(40), 1):
        cum += v
        rows.append([i, k, v, '%.2f' % (100 * v / t), '%.2f' % (100 * cum / t)])
    w('mnemonics_' + a, ['rank', 'mnemonic (size suffix folded)', 'count', 'share%', 'cumulative%'], rows)
    w('shapes_' + a, ['operand shape', 'count', 'share of operands %'], [[k, v, '%.1f' % (100 * v / sum(sh.values()))] for k, v in sh.most_common()])
    w('pairs_' + a, ['mnemonic shapes', 'count', 'share%'], [[k, v, '%.2f' % (100 * v / t)] for k, v in pr.most_common(40)])
    w('bigrams_' + a, ['first ; second', 'count'], [[k, v] for k, v in bg.most_common(40)])
    J[a + '_mn'] = dict(mn)

json.dump(J, open('/tmp/p64opt/analysis.json', 'w'), indent=1, default=str)
print('files in the common set:', len(fair), 'pdp64 instructions', tot)
