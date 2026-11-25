#!/usr/bin/env python3
"""corpus_masks.py ASM_DIR: for every function of the compiled corpus (the assembly kept by the earlier study, bench/holes-1-and-6/part-b/asm) treated as the body of a system call,
the mask a return of that function would carry under two ways of choosing it, and how often a one-slot latch would already hold it.
  complement: all registers except those the function can leave dirty (regs_static: written, not callee-saved, not r0), the mask of 'K1' in replay.py;
  convention: r0 and the callee-saved registers (one mask for every function).
For a sequence of returns in random order of calls the chance that the latch already holds the mask is the sum over masks of (share of functions with that mask) squared; it is
reported with the measured top shares.  Writes a table to stdout."""
import sys, os, glob, collections, importlib.util
here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('regs_static', os.path.join(here, '..', '..', 'holes-1-and-6', 'part-b', 'regs_static.py'))
rs = importlib.util.module_from_spec(spec); spec.loader.exec_module(rs)
asm = sys.argv[1]
ALL = frozenset(range(32)) - {14}
for comp in ('pcc', 'llvm'):
    masks = []
    for f in sorted(glob.glob(os.path.join(asm, '*.%s.s' % comp))):
        for fn, r in rs.analyse(f).items():
            masks.append(frozenset(ALL - set(r['dirty'])))
    c = collections.Counter(masks); n = len(masks)
    top = c.most_common(3)
    print('%s: %d functions; %d distinct complement masks; ALL (nothing dirty) for %d (%.0f%%); top shares %s; chance a one-slot latch holds the mask at a random next call %.1f%%' % (
        comp, n, len(c), c[ALL], 100.0 * c[ALL] / n, ', '.join('%.0f%%' % (100.0 * v / n) for m, v in top), 100.0 * sum((v / n) ** 2 for v in c.values())))
    print('  convention mask: 1 distinct mask, the latch always holds it (100%)')
