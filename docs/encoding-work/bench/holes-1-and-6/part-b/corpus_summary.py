#!/usr/bin/env python3
"""Summary of the static count over the corpus and the instruction counts of each return-path spelling.  usage: corpus_summary.py WORKDIR
WORKDIR: NAME.pcc.s / NAME.llvm.s (compile_corpus.sh), NAME.dir (the group: tests-c, tests-c-new or kern), and dyn-*.json (regs_dynamic.py)."""
import sys, os, glob, json, statistics
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import regs_static as rs
work = sys.argv[1]
rows = []
for f in sorted(glob.glob(os.path.join(work, '*.s'))):
    b = os.path.basename(f)
    name, comp = b.split('.')[0], b.split('.')[1]
    grp = 'kern' if name == 'kern' else open(os.path.join(work, name + '.dir')).read().strip()
    for fn, r in rs.analyse(f).items():
        rows.append((grp, comp, name, fn, r))
def stats(sel, label):
    d = [r['n_dirty'] for _, _, _, _, r in sel]
    if not d: return
    h = {k: sum(1 for x in d if x == k) for k in sorted(set(d))}
    print('%-34s functions %3d  with a dirty register %3d (%2d%%)  mean %.1f  median %.1f  max %2d   frame restore: 2 instr x %d = %d, clears: %d instr, mask-reg: 2 x %d = %d, mask-imm: 0' % (
        label, len(d), sum(1 for x in d if x), 100 * sum(1 for x in d if x) // len(d), statistics.mean(d), statistics.median(d), max(d), sum(1 for x in d if x), 2 * sum(1 for x in d if x), sum(d), len(d), 2 * len(d)))
    return h
for grp in ('tests-c', 'tests-c-new', 'kern', None):
    for comp in ('pcc', 'llvm'):
        sel = [x for x in rows if (grp is None or x[0] == grp) and x[1] == comp]
        stats(sel, '%s / %s (static, every function)' % (grp or 'all', comp))
print()
print('histogram of n dirty registers per function, all groups:')
for comp in ('pcc', 'llvm'):
    d = [r['n_dirty'] for g, c, n, fn, r in rows if c == comp]
    print(' ', comp, {k: d.count(k) for k in sorted(set(d))})
print()
print('functions that use r16-r23 (caller-saved in the LLVM back end, unassigned in the ABI draft):')
for comp in ('pcc', 'llvm'):
    sel = [r for g, c, n, fn, r in rows if c == comp]
    print(' ', comp, sum(1 for r in sel if any(16 <= x <= 23 for x in r['dirty'])), 'of', len(sel))
for what in ('kern', 'corpus'):
    p = os.path.join(work, 'dyn-%s.json' % what)
    if not os.path.exists(p): continue
    dyn = [r for r in json.load(open(p)) if 'n_dirty' in r]
    for comp in ('pcc', 'llvm'):
        d = [r['n_dirty'] for r in dyn if r['comp'] == comp]
        print('dynamic %s / %s: %d runs, runs leaving a dirty register %d, mean %.1f, median %.1f, max %d, ABI violations %d' % (what, comp, len(d), sum(1 for x in d if x), statistics.mean(d), statistics.median(d), max(d), sum(1 for r in dyn if r['comp'] == comp and r['abi_violation'])))
print()
print('per function (kern.c, static / dynamic):')
for g, c, n, fn, r in rows:
    if g == 'kern': print('  %-5s %-14s instr %3d  static dirty %2d r%s' % (c, fn, r['instr'], r['n_dirty'], ',r'.join(map(str, r['dirty']))))
