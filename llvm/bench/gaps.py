#!/usr/bin/env python3
"""
gaps.py -- why LoopVectorize did or did not vectorise each loop of llvm/bench/gaps.c, and whether the lowering (PDP64VecLoop) turned the vector loop into a vec block.

For each g_* function: clang -O2 -Xclang -disable-llvm-passes -gline-tables-only, opt -passes='default<O2>' -mtriple=pdp64-unknown-elf with the loop vectoriser's remarks
(missed, analysis, passed), and llc -pdp64-vecloop-verbose.  Prints a markdown table: function, LoopVectorize (vectorised at VF n / the reason it did not), lowering (a vec block / the reason
it left the vector loop scalarised).   gaps.py [--fast] (default: -ffast-math, as the kernels; --strict: no fast-math, to see the ordered reductions)
"""
import os, re, subprocess, sys, tempfile, argparse
HERE = os.path.dirname(os.path.abspath(__file__))
R = os.path.dirname(os.path.dirname(HERE))
LB = os.path.join(os.path.dirname(R), 'llvm-build', 'bin')
def run(c, **k): return subprocess.run(c, capture_output=True, text=True, **k)
def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--strict', action='store_true'); ap.add_argument('--csv'); a = ap.parse_args()
    src = os.path.join(HERE, 'gaps.c')
    tmp = tempfile.mkdtemp()
    fl = ['-m64', '-fno-stack-protector', '-mlong-double-64', '-mno-sse', '-mno-mmx', '-w', '-ffp-contract=fast', '-fno-unroll-loops'] + ([] if a.strict else ['-ffast-math'])
    ll = os.path.join(tmp, 'g.ll')
    r = run(['clang', '-S', '-emit-llvm', '-O2', '-Xclang', '-disable-llvm-passes', '-gline-tables-only'] + fl + ['-o', ll + '.0', src])
    if r.returncode: sys.exit(r.stderr)
    t = open(ll + '.0').read()
    t = re.sub(r'^target (datalayout|triple).*\n', '', t, flags=re.M); t = re.sub(r'"(target-cpu|target-features|tune-cpu)"="[^"]*"', '', t)
    open(ll + '.1', 'w').write(t)
    # (the remarks of the loop vectoriser would be the report, but with -pass-remarks-analysis opt 21.1.8 asserts in emitInvalidCostRemarks on some recipes: the debug output is read instead)
    r = run([os.path.join(LB, 'opt'), '-mtriple=pdp64-unknown-elf', '-passes=default<O2>', '-S', ll + '.1', '-o', ll, '-debug-only=loop-vectorize'])
    if r.returncode: sys.exit(r.stderr[:2000])
    res = {}
    cur = None
    vf = {}
    for ln in r.stderr.splitlines():
        m = re.match(r"LV: Checking a loop in '(\w+)'", ln)
        if m: cur = m.group(1); res.setdefault(cur, []); vf.setdefault(cur, []); continue
        if cur is None: continue
        m = re.match(r'LV: Selecting VF: (\d+)', ln)
        if m and m.group(1) != '1': vf[cur].append(m.group(1))
        if ln.startswith('LV: Not vectorizing') or ln.startswith("LV: Can't vectorize") or ln.startswith('LV: Cannot'):
            res[cur].append(re.sub(r'^LV: ', '', ln.strip())[:140])
        m = re.match(r'Cost of Invalid for VF (\d+): (.*)', ln)
        if m:
            what = m.group(2).split('=')[-1].strip().split(' ')[0] if '=' in m.group(2) else m.group(2).split(' ')[0]
            if 'REDUCE' in m.group(2).upper() or what.startswith('ir<'): what = 'reduction (no accumulating instruction)'
            res[cur].append('no instruction for vector `%s`' % (what.replace('WIDEN-', '').replace('WIDEN', '') or m.group(2)[:30]))
        if 'uses too many registers' in ln: res[cur].append('too many live vectors')
        if 'Vectorization is possible but not beneficial' in ln: res[cur].append('not beneficial')
        if 'LV: Not considering vector loop of width' in ln and 'will not generate any vector' in ln: res[cur].append('only scalarised')
        if 'Found a non-intrinsic callsite' in ln: res[cur].append('a call: ' + ln.split('@')[-1].split('(')[0])
    defs = []
    for i, ln in enumerate(open(src).read().split('\n'), 1):
        m = re.search(r'\b(g_\w+)\(', ln)
        if m and ln.startswith('N '): defs.append((i, m.group(1)))
    r2 = run([os.path.join(LB, 'llc'), '-mtriple=pdp64-unknown-elf', '-O2', '-pdp64-vecloop-verbose', ll, '-o', ll + '.s'])
    low = {}
    for ln in r2.stderr.splitlines():
        m = re.match(r'pdp64-vecloop: (\w+): loop at (\S+): (.*)', ln)
        if m and m.group(3) != 'considering': low.setdefault(m.group(1), []).append(m.group(3))
    blocks = {}
    cur = None
    for ln in open(ll + '.s'):
        m = re.match(r'^(g_\w+):', ln)
        if m: cur = m.group(1)
        if re.match(r'^\s+vec\s', ln) and cur: blocks[cur] = blocks.get(cur, 0) + 1
    out = ['| function | LoopVectorize | lowering |', '|---|---|---|']
    rows = []
    for l, f in defs:
        reasons = []
        for m in res.get(f, []):
            if m not in reasons: reasons.append(m)
        v = vf.get(f, [])
        if v: lv = 'vectorised, VF %s' % '/'.join(sorted(set(v), key=int))
        else: lv = '; '.join(reasons[:4]) if reasons else '(the loop vectoriser never saw it: removed or rewritten by an earlier pass)'
        lw = []
        if blocks.get(f): lw.append('%d vec block(s)' % blocks[f])
        for m in low.get(f, []):
            if not m.startswith('vec block:'): lw.append(m.replace('not a vec block: ', ''))
        rows.append((f, lv, '; '.join(lw) if lw else ('-' if not v else 'no block')))
        out.append('| `%s` | %s | %s |' % rows[-1])
    print('\n'.join(out))
    if a.csv:
        import csv
        w = csv.writer(open(a.csv, 'w')); w.writerow(['function', 'loopvectorize', 'lowering'])
        for r_ in rows: w.writerow(r_)
main()
