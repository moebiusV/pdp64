#!/usr/bin/env python3
# dynmix.py : dynamic count of the compare, branch and flag instructions of every runnable program, for each variant (sim64 -P, encdis -k)
import os, sys, glob, json, subprocess, re, collections
B = '/tmp/flags-pdp64/build'; W = '/tmp/flags-work'
from concurrent.futures import ThreadPoolExecutor
CLS = {'cmp': {'cmp'}, 'tst': {'tst', 'test'}, 'flag branch': set('beq bne bmi bpl bvc bvs bcc bcs bge blt bgt ble bhi blos'.split()),
       'set': {'set'}, 'adc/sbc': {'adc', 'sbc'}, 'fcmp': {'fcmp', 'fcmp32'},
       'cbCC': set('cbeq cbne cblt cbge cbgt cble cbcs cbcc cbhi cblos'.split()), 'br/jmp': {'br', 'jmp'}, 'sob': {'sob'}}
def one(a):
    lab, x = a
    p = f'/tmp/dm_{lab}_{os.path.basename(x)}.prof'
    subprocess.run([B + '/sim64', '-P', p, x], capture_output=True)
    r = subprocess.run([B + '/encdis', '-k', p, x], capture_output=True, text=True).stdout
    c = collections.Counter(); tot = 0
    for l in r.split('\n'):
        m = re.match(r'weight dynamic (\d+) (\S+)', l)
        if m:
            n = int(m.group(1)); tot += n; c['_' + m.group(2)] += n
            for k, s in CLS.items():
                if m.group(2) in s: c[k] += n
    os.unlink(p)
    c['total'] = tot
    return os.path.basename(x)[:-2], dict(c)
res = {}
for lab in ('base', 'nf', 'llvm'):
    names = [x['name'].replace('/', '_') for x in json.load(open(f'{W}/out/{lab}.run.json')) if 'fail' not in x]
    xs = [f'{W}/runout/{lab}/{n}.x' for n in names]
    with ThreadPoolExecutor(8) as ex:
        res[lab] = dict(ex.map(one, [(lab, x) for x in xs]))
mn = {l: collections.Counter() for l in res}
for l in res:
    for k, v in res[l].items():
        for a, b in v.items():
            if a.startswith('_'): mn[l][a[1:]] += b
json.dump({l: dict(c) for l, c in mn.items()}, open(W + '/out/dynmn.json', 'w'))
json.dump({l: {k: {a: b for a, b in v.items() if not a.startswith('_')} for k, v in d.items()} for l, d in res.items()}, open(W + '/out/dynmix.json', 'w'), indent=1)
for lab in res:
    t = collections.Counter()
    for k, v in res[lab].items():
        for a, b in v.items():
            if not a.startswith('_'): t[a] += b
    print(lab, dict(t))
