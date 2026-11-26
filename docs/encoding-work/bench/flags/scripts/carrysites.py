#!/usr/bin/env python3
# carrysites.py DIR... : count add-with-carry-out idioms in assembly: `add s,d` followed (same block, within 6 instructions) by an unsigned
# test of the sum d against an addend: cbcs/cbcc/cbhi/cblos d,s (or the saved copy of the old d, or the same immediate), or, with flags,
# cmp d,x then bcs/bcc/bhi/blos/set cs|cc|hi|los.  Also counts adc/sbc, and the sub-then-borrow idiom (cmp a,b before sub b,a).
import sys, re, glob, collections
UC = ('cbcs', 'cbcc', 'cbhi', 'cblos', 'bcs', 'bcc', 'bhi', 'blos')
def parse(f):
    out = []
    for line in open(f):
        l = line.split(';')[0].rstrip()
        if not l.strip(): continue
        if l[0] not in ' \t':
            out.append(('label', '', [])); l = re.sub(r'^[^:\s]+:', '', l).strip()
            if not l: continue
        t = l.split(None, 1)
        if t[0].startswith('.'): continue
        ops = [o.strip() for o in re.split(r',(?![^(]*\))', t[1])] if len(t) > 1 else []
        out.append((t[0], t[1] if len(t) > 1 else '', ops))
    return out
for D in sys.argv[1:]:
    c = collections.Counter(); files = collections.Counter()
    for f in sorted(glob.glob(D + '/*.s')):
        ins = parse(f)
        for i, (mn, raw, ops) in enumerate(ins):
            if mn in ('adc', 'sbc'): c[mn] += 1
            if mn == 'add' and len(ops) == 2 and re.fullmatch(r'r\d+|fp|sp', ops[1]):
                s, d = ops
                copies = {ops_[0] for (m2, r2, ops_) in ins[max(0, i - 6):i] if m2 == 'movq' and len(ops_) == 2 and ops_[1] == d} | {s}
                # the old d saved in a register: movq d,x before
                saved = {ops_[1] for (m2, r2, ops_) in ins[max(0, i - 6):i] if m2 == 'movq' and len(ops_) == 2 and ops_[0] == d}
                for j in range(i + 1, min(len(ins), i + 7)):
                    m2, r2, o2 = ins[j]
                    if m2 == 'label' or m2 in ('call', 'ret', 'br', 'jmp'): break
                    if m2 in ('cbcs', 'cbcc', 'cbhi', 'cblos') and len(o2) == 3 and o2[0] == d and (o2[1] in {s} | saved):
                        c['add+unsigned-test-of-sum (cb)'] += 1; files[f.split('/')[-1]] += 1; break
                    if m2 == 'cmp' and len(o2) == 2 and o2[0] == d and (o2[1] in {s} | saved):
                        c['add+cmp-of-sum (flags)'] += 1; files[f.split('/')[-1]] += 1; break
                    if re.fullmatch(r'r\d+', d) and (m2 in ('add', 'sub', 'movq', 'and', 'bis', 'xor', 'shl', 'shr') and len(o2) == 2 and o2[1] == d): break
    print(D, dict(c), 'files:', len(files))
