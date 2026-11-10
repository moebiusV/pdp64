#!/usr/bin/env python3
"""timing.py: run the sim64 timing model (--timing) on images for a list of parameter sets and print a table.

usage: timing.py [options] IMAGE...
  -c SPEC          a parameter set, "name=LABEL,W=8,iw=1,..." (repeatable; see `build/sim64 --timing-help`)
  -p PRESET        a named parameter set (repeatable): list with --presets
  -s KEY=V1,V2,..  sweep: every parameter set gets one copy per value (repeatable: cross product)
  --base SPEC      parameters added to every set (before -s)
  -n STEPS         stop after that many instructions (sim64 -n)
  --sim PATH       the sim64 binary (default build/sim64 next to this script's tree)
  --cols A,B,..    columns (default: image,name,insns,bytes,cycles,cpi,bpc,fe%,ex%,misp%)   --csv  comma separated
  --raw            print sim64's own `tm` lines
An IMAGE is a linked executable (ld64 output).  One sim64 run per image serves all parameter sets
(at most 32 per run; more are split).  Percentages are shares of the cycles: fe% = issue cycles lost waiting for instruction bytes (fetch-wait),
ex% = lost waiting for an operand, a unit or a long instruction (execute-wait), mispredict recovery is inside fe% (cause `misp`) and shown as misp%.
"""
import sys, os, subprocess, itertools, re, argparse

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

PRESETS = {
    # a small scalar core with an ideal memory system: one issue slot, 8 bytes/cycle fetch, bimodal predictor, no BTB
    'scalar': 'name=scalar,iw=1,W=8,N=32',
    # the same with real caches
    'scalar-c': 'name=scalar-c,iw=1,W=8,N=32,ic=1,dc=1',
    # dual issue, 16 bytes/cycle fetch, a BTB, ideal memory
    'dual': 'name=dual,iw=2,W=16,N=48,dq=6,btb=64',
    'dual-c': 'name=dual-c,iw=2,W=16,N=48,dq=6,btb=64,ic=1,dc=1',
    # fetch-starved: 2 bytes per cycle
    'w2': 'name=w2,iw=1,W=2,N=16',
    # infinite fetch (the code is never fetch-bound): the execute-bound reference
    'wide': 'name=wide,iw=1,W=64,N=128,tkb=0,btb=4096',
}

def parse_args():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('images', nargs='*')
    ap.add_argument('-c', action='append', default=[])
    ap.add_argument('-p', action='append', default=[])
    ap.add_argument('-s', action='append', default=[])
    ap.add_argument('--base', default='')
    ap.add_argument('-n', default=None)
    ap.add_argument('--sim', default=os.path.join(ROOT, 'build', 'sim64'))
    ap.add_argument('--cols', default='image,name,insns,bytes,cycles,cpi,bpc,fe%,ex%,misp%')
    ap.add_argument('--csv', action='store_true')
    ap.add_argument('--raw', action='store_true')
    ap.add_argument('--presets', action='store_true')
    return ap.parse_args()

def build_specs(a):
    base = [s for s in a.c] + [PRESETS[p] for p in a.p]
    if not base: base = [PRESETS['scalar']]
    specs = []
    sweeps = []
    for s in a.s:
        k, v = s.split('=', 1)
        sweeps.append([(k, x) for x in v.split(',')])
    for b in base:
        for combo in itertools.product(*sweeps) if sweeps else [()]:
            parts = ([a.base] if a.base else []) + [b]
            name = None
            m = re.search(r'(?:^|,)name=([^,]*)', b)
            name = m.group(1) if m else 'cfg'
            extra = ','.join('%s=%s' % kv for kv in combo)
            lab = name + ('/' + '/'.join('%s%s' % kv for kv in combo) if combo else '')
            spec = ','.join(parts + ([extra] if extra else [])) + ',name=' + lab
            specs.append((lab, spec))
    return specs

def run_image(a, img, specs):
    out = []
    for i in range(0, len(specs), 32):
        chunk = specs[i:i + 32]
        cmd = [a.sim] + (['-n', a.n] if a.n else []) + ['--timing=' + s for _, s in chunk] + [img]
        r = subprocess.run(cmd, capture_output=True, stdin=subprocess.DEVNULL, text=True, errors='replace')
        for l in r.stderr.splitlines():
            if l.startswith('tm '): out.append(l)
        if not any(l.startswith('tm ') for l in r.stderr.splitlines()):
            sys.stderr.write('timing.py: %s: no timing output (exit %d): %s\n' % (img, r.returncode, r.stderr[-300:]))
    return out

def parse_line(l):
    d = {}
    for kv in l[3:].split():
        k, v = kv.split('=', 1)
        d[k] = v
    return d

def derived(d, img):
    cyc = float(d['cycles']); ins = float(d['insns'])
    d['image'] = os.path.basename(img)
    d['cpi'] = '%.3f' % (cyc / ins)
    d['ipc'] = '%.3f' % (ins / cyc)
    d['fe%'] = '%.1f' % (100.0 * int(d['fe']) / cyc)
    d['ex%'] = '%.1f' % (100.0 * (int(d['ex']) + int(d['occ_blk']) + int(d['occ_sys']) + int(d['occ_mem'])) / cyc)
    d['misp%'] = '%.1f' % (100.0 * int(d['fe_misp']) / cyc)
    d['act%'] = '%.1f' % (100.0 * int(d['active']) / cyc)
    d['mpki'] = '%.2f' % (1000.0 * int(d['mispred']) / ins)
    return d

def main():
    a = parse_args()
    if a.presets:
        for k, v in PRESETS.items(): print('%-9s %s' % (k, v))
        return 0
    if not a.images:
        sys.stderr.write('timing.py: no images\n'); return 2
    specs = build_specs(a)
    rows = []
    for img in a.images:
        for l in run_image(a, img, specs):
            if a.raw: print(l)
            rows.append(derived(parse_line(l), img))
    if a.raw: return 0
    cols = a.cols.split(',')
    if a.csv:
        print(','.join(cols))
        for r in rows: print(','.join(str(r.get(c, '')) for c in cols))
        return 0
    w = [max(len(c), max((len(str(r.get(c, ''))) for r in rows), default=0)) for c in cols]
    print('  '.join(c.ljust(w[i]) if i < 3 else c.rjust(w[i]) for i, c in enumerate(cols)))
    for r in rows:
        print('  '.join(str(r.get(c, '')).ljust(w[i]) if i < 3 else str(r.get(c, '')).rjust(w[i]) for i, c in enumerate(cols)))
    return 0

if __name__ == '__main__':
    sys.exit(main())
