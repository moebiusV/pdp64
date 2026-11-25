#!/usr/bin/env python3
"""nests2d.py -- 'why not' (c) of docs/encoding-work/vec-2d.md: how many loop nests of the benchmark kernels have a countable outer loop around a loop that LoopVectorize vectorised?
Measured on the IR that opt -O2 (mtriple=pdp64, LoopVectorize with the cost model) leaves for each C source of llvm-pdp64/bench's SRCS list, tiles.c and llvm-pdp64/bench/gaps.c: opt -passes='print<loops>'
gives the loop forest (a vectorised loop's header is the block `vector.body`), opt -passes='print<scalar-evolution>' gives each loop's backedge-taken count (`Unpredictable` when SCEV cannot
count the loop).  A nest is a loop that contains a loop.  Writes a table to standard output.  Needs ../llvm-build/bin/opt and clang."""
import os, re, sys, tempfile, subprocess, collections
HERE = os.path.dirname(os.path.abspath(__file__)); R = os.path.dirname(os.path.dirname(HERE))
LLVM = os.environ.get('LLVM_PDP64') or os.path.join(os.path.dirname(R), 'llvm-pdp64')
src = open(os.path.join(LLVM, 'bench', 'bench.py')).read()
g = {'__file__': os.path.join(LLVM, 'bench', 'bench.py'), '__name__': 'bench'}
exec(compile(src[:src.index('\ndef main():')], 'bench.py', 'exec'), g)
OPT = g['OPT']; SRCS = list(g['SRCS']); ll_of_lv = g['ll_of_lv']; ll_of = g['ll_of']; run = g['run']
SRCS += [os.path.join(LLVM, 'bench', 'gaps.c'), os.path.join(R, 'docs', 'encoding-work', 'arch-data', 'vec-forms', 'tiles', 'tiles.c')]
tmp = tempfile.mkdtemp()
tot = collections.Counter(); rows = []
for s in SRCS:
    ll = os.path.join(tmp, os.path.basename(s) + '.ll'); ll_of_lv(s, ll)
    lp = run([OPT, '-passes=print<loops>', '-disable-output', ll]).stderr
    se = run([OPT, '-passes=print<scalar-evolution>', '-disable-output', ll]).stderr
    btc = {}
    fn = None
    for line in se.split('\n'):
        m = re.match(r'Classifying expressions for: @(\S+)', line)
        if m: fn = m.group(1); continue
        m = re.match(r'Loop (%\S+): (.*)', line)
        if not m or fn is None: continue
        t = m.group(2)
        if t.startswith('backedge-taken count is'): btc[(fn, m.group(1))] = 'count'
        elif t.startswith('Unpredictable backedge-taken count') and (fn, m.group(1)) not in btc: btc[(fn, m.group(1))] = 'no'
    # the forest
    fn = None; stack = []
    loops = []   # (fn, depth, header, vectorised, parent index)
    for line in lp.split('\n'):
        m = re.match(r"Loop info for function '([^']+)'", line)
        if m: fn = m.group(1); stack = []; continue
        m = re.match(r'(\s*)Loop at depth (\d+) containing: (.*)', line)
        if m and fn is not None:
            d = int(m.group(2)); blocks = m.group(3)
            h = re.search(r'%([^,<]+)<header>', blocks).group(1)
            while len(stack) >= d: stack.pop()
            parent = stack[-1] if stack else None
            loops.append(dict(fn=fn, d=d, h='%' + h, vec=(h.startswith('vector.body')), parent=parent, idx=len(loops)))
            stack.append(len(loops) - 1)
    kids = collections.defaultdict(list)
    for l in loops:
        if l['parent'] is not None: kids[l['parent']].append(l['idx'])
    n_nest = n_cnt = n_vec_inner = n_both = 0
    for l in loops:
        if not kids[l['idx']]: continue
        # a nest root of depth 1 (an outer loop) with a descendant loop
        if l['d'] != 1 and not any(loops[k]['vec'] for k in kids[l['idx']]): pass
        outer_ok = btc.get((l['fn'], l['h'])) == 'count'
        desc = []; todo = list(kids[l['idx']])
        while todo:
            k = todo.pop(); desc.append(k); todo += kids[k]
        # a vectorised loop under it (the vector.body is the loop the vectoriser made: it replaces the scalar inner loop)
        vec_inside = any(loops[k]['vec'] for k in desc)
        n_nest += 1; n_cnt += outer_ok; n_vec_inner += vec_inside; n_both += outer_ok and vec_inside
    rows.append((os.path.basename(s), sum(1 for l in loops if not l['vec'] and not l['h'].startswith('%vec.epilog') and not l['h'].startswith('%vector.')), sum(1 for l in loops if l['vec']), n_nest, n_cnt, n_vec_inner, n_both))
    for i, x in enumerate(rows[-1][1:]): tot[i] += x
print('| source | loops (scalar) | vectorised loops | loops that contain a loop | ... with a countable trip count | ... with a vectorised loop inside | both |')
print('|---|---:|---:|---:|---:|---:|---:|')
for r in rows: print('| %s | %d | %d | %d | %d | %d | %d |' % r)
print('| total | ' + ' | '.join(str(tot[i]) for i in range(6)) + ' |')
