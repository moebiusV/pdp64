#!/usr/bin/env python3
"""merge.py SHARED: fold SHARED/cond-out/NN.json into SHARED/condensed.jsonl after checking, per batch, that the
keys returned are exactly the keys sent.  Prints what is missing or extra and exits 1 on any mismatch."""
import json, os, sys

shared = sys.argv[1]
bad = 0
have = {}
cf = os.path.join(shared, 'condensed.jsonl')
if os.path.exists(cf):
    for l in open(cf):
        r = json.loads(l); have[r['key']] = r['line']
for fn in sorted(os.listdir(os.path.join(shared, 'cond-batches'))):
    sent = {r['key'] for r in json.load(open(os.path.join(shared, 'cond-batches', fn)))}
    of = os.path.join(shared, 'cond-out', fn)
    if not os.path.exists(of):
        print(fn, 'no output yet'); bad = 1; continue
    try:
        got = json.load(open(of))
    except ValueError as e:
        print(fn, 'does not parse:', e); bad = 1; continue
    miss, extra = sent - set(got), set(got) - sent
    if miss or extra:
        print(fn, 'missing', len(miss), 'extra', len(extra), sorted(miss)[:5]); bad = 1
    for k, v in got.items():
        if k in sent and isinstance(v, str) and v.strip():
            have[k] = ' '.join(v.split())
        elif k in sent:
            print(fn, 'empty line for', k); bad = 1
with open(cf, 'w') as f:
    for k, v in have.items():
        f.write(json.dumps(dict(key=k, line=v), ensure_ascii=False) + '\n')
print(len(have), 'condensed lines in', cf)
sys.exit(bad)
