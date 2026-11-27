#!/usr/bin/env python3
"""checksites.py DIR -- the compare-and-branch that guards each run-time check in pdp64 assembly made with `ccom -xchecks` (DIR holds the .s files).

A check is `cbXX operands,.Lok` followed by the failure block that ends in a call or `movcall` of `__chk_fail`, and the label `.Lok`.  Prints the number of checks, the
branch mnemonics, whether the bound is an immediate or a register, and how many of the immediates fit 5, 8, 12 and 16 bits (the sizes of the immediates of the cb and cmp leaves),
and the commonest bounds.  Used for docs/encoding-work/check-instructions.md."""
import re, sys, glob, collections
sites = []; files = collections.Counter()
for f in sorted(glob.glob(sys.argv[1] + '/*.s')):
    L = open(f).read().split('\n')
    for i, l in enumerate(L):
        if '__chk_fail' in l and 'call' in l:
            j = i + 1
            while j < len(L) and not L[j].startswith('.L'): j += 1
            lab = L[j].split(':')[0] if j < len(L) else None
            for k in range(i, max(0, i - 14) - 1, -1):
                m = re.match(r'\s+(cb\w+|b\w+)\s+(.*?),' + re.escape(lab) + r'\s*$', L[k]) if lab else None
                if m: sites.append((m.group(1), m.group(2))); files[f] += 1; break
print('checks %d in %d files' % (len(sites), len(files)))
print('branches', collections.Counter(s[0] for s in sites).most_common())
imm = []; reg = 0
for mn, ops in sites:
    last = ops.split(',')[-1].strip()
    if last.startswith(('#', '$')): imm.append(int(last[1:], 0))
    elif re.match(r'r\d+$', last): reg += 1
print('immediate bounds %d, register bounds %d' % (len(imm), reg))
for lim, name in [(31, '0..31 (5 bits)'), (255, '0..255 (8 bits)'), (4095, '0..4095 (12 bits)'), (65535, '0..65535 (16 bits)')]:
    n = sum(1 for x in imm if 0 <= x <= lim)
    print('  %-20s %6d  %.1f%%' % (name, n, 100.0 * n / len(imm)))
im = sorted(imm)
print('smallest %d, median %d, largest %d' % (im[0], im[len(im) // 2], im[-1]))
print('commonest bounds', collections.Counter(im).most_common(8))
print('distinct bounds', len(set(im)))
