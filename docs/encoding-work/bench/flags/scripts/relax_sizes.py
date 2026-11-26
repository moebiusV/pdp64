#!/usr/bin/env python3
# relax_sizes.py LABEL : for each out/LABEL/*.s, the text size after ld64 relaxation (the object linked alone with stub definitions
# for its undefined symbols), and plain (as64 --no-relax, instruction bytes). Adds to out/LABEL.json fields relax_text, plain_text, cbexp.
import os, sys, json, re, subprocess, glob
from concurrent.futures import ThreadPoolExecutor
W = '/tmp/flags-work'; B = '/tmp/flags-pdp64/build'
def sh(c): return subprocess.run(c, capture_output=True, text=True)
def one(args):
    label, x = args
    if 'fail' in x: return x
    d = f'{W}/out/{label}'; n = x['name']; s = f'{d}/{n}.s'
    o = f'{d}/{n}.relax.o'
    stubs = set(); x['relax_text'] = None
    for it in range(4):
        st = f'{d}/{n}.stub.s'
        open(st, 'w').write('\t.text\n\t.globl _start\n_start:\tret\n' + ''.join(f'\t.globl {s_}\n{s_}:\tret\n' for s_ in sorted(stubs)))
        sh([B + '/as64', '-o', f'{d}/{n}.stub.o', st])
        r = sh([B + '/ld64', '--stats', '-o', f'{d}/{n}.x', o, f'{d}/{n}.stub.o'])
        und = set(re.findall(r'undefined symbol (\S+)', r.stdout + r.stderr))
        if not und:
            m = re.search(r'all sites and paddings: (\d+) -> (\d+) bytes', r.stderr + r.stdout)
            if m: x['relax_delta'] = int(m.group(2)) - int(m.group(1)) - (2 - 2)
            x['relax_text'] = x['plain_bytes'] + x.get('relax_delta', 0)
            m = re.search(r'conditional branch and sob\s+(\d+) sites\s+(\d+) ->\s+(\d+) bytes', r.stderr + r.stdout)
            if m: x['relax_condbr_sites'] = int(m.group(1)); x['relax_condbr_bytes'] = int(m.group(3))
            break
        stubs |= und
    for f in (f'{d}/{n}.stub.s', f'{d}/{n}.stub.o', f'{d}/{n}.x'):
        if os.path.exists(f): os.unlink(f)
    # plain text: link the no-relax object the same way
    return x
if __name__ == '__main__':
    label = sys.argv[1]
    res = json.load(open(f'{W}/out/{label}.json'))
    with ThreadPoolExecutor(10) as ex:
        res = list(ex.map(one, [(label, x) for x in res]))
    json.dump(res, open(f'{W}/out/{label}.json', 'w'))
    ok = [x for x in res if 'fail' not in x]
    print(label, 'relaxed text total', sum(x['relax_text'] or 0 for x in ok), 'none:', sum(1 for x in ok if x['relax_text'] is None), 'plain bytes', sum(x['plain_bytes'] for x in ok))
