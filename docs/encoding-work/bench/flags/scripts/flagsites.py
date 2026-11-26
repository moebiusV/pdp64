#!/usr/bin/env python3
# flagsites.py DIR : classify flag-reading instructions in the .s files of DIR by the instruction before them
import sys, re, glob, collections
FB = set("beq bne bmi bpl bvc bvs bcc bcs bge blt bgt ble bhi blos set adc sbc trapcc".split())
c = collections.Counter(); ex = {}
for f in sorted(glob.glob(sys.argv[1] + '/*.s')):
    prev = None
    for line in open(f):
        l = line.split(';')[0].rstrip()
        if not l.strip(): continue
        if l[0] not in ' \t':
            l2 = re.sub(r'^[^:\s]+:', '', l).strip()
            if not l2: prev = None; continue   # label: flags from before may reach through, but count as break
            l = '\t' + l2
        t = l.split(None, 1)
        mn = t[0]; ops = t[1] if len(t) > 1 else ''
        if mn.startswith('.'): continue
        if mn in FB:
            key = (mn, prev[0] if prev else '<label/none>', (prev[1] if prev and prev[0] in ('cmp',) else ''))
            k2 = (prev[0] if prev else '<label/none>')
            if prev and prev[0] == 'cmp':
                a = prev[1].split(',')
                shape = []
                for o in a:
                    o = o.strip()
                    shape.append('imm' if o.startswith('#') else 'reg' if re.fullmatch(r'r\d+|sp|fp', o) else 'mem')
                k2 = 'cmp ' + ','.join(shape)
            c[(k2, mn if mn in ('set',) else 'bcc')] += 1
            ex.setdefault((k2, mn if mn in ('set',) else 'bcc'), (f.split('/')[-1], prev, l.strip()))
        prev = (mn, ops)
tot = 0
for k, v in c.most_common(): print(v, k, ex[k]); tot += v
print('total', tot)
