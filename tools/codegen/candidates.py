#!/usr/bin/env python3
"""candidates.py RUN: static counts of instruction sequences that an unused (or not yet used) instruction could replace,
over the pdp64 .s files of the common file set of RUN -> /tmp/p64opt/analysis/candidates.csv"""
import json, sys, re, collections, csv, os

run = sys.argv[1]
D = '/tmp/p64opt/%s' % run
res = json.load(open(D + '/results.json'))
by = collections.defaultdict(dict)
for x in res:
    if 'ins' in x:
        by[x['src']][x['arch']] = x
fair = [s for s, v in by.items() if all(a in v for a in ('pdp64', 'amd64', 'gcc-Os', 'clang-Os'))]
C = collections.Counter()
B = collections.Counter()      # bytes a replacement would save, estimated
CC = r'(?:beq|bne|blt|bge|bgt|ble|bcs|bcc|bhi|blos|bmi|bpl)'
INV = dict(beq='bne', bne='beq', blt='bge', bge='blt', bgt='ble', ble='bgt', bcs='bcc', bcc='bcs', bhi='blos', blos='bhi')


def lines(path):
    out = []
    for l in open(path, errors='replace'):
        l = l.rstrip('\n')
        l = l.split(';')[0].rstrip() if not l.startswith('\t.byte') else l
        if not l.strip():
            continue
        out.append(l.strip() if l.startswith('\t') else l)
    return out


for s in fair:
    p = D + '/s/' + s.replace('/', '_') + '.s'
    if not os.path.exists(p):
        continue
    L = lines(p)
    n = len(L)
    for i in range(n):
        a = L[i]
        g = lambda k: L[i + k] if i + k < n else ''
        # set cc,rd: bCC L1; movq #1,r | clr r; br L2; L1:; clr r | movq #1,r; L2:
        m = re.match(r'(%s) (\.L\d+)$' % CC, a)
        if m and (g(1).startswith('movq #1,') or g(1).startswith('clr ')) and re.match(r'br \.L\d+$', g(2)) and g(3) == m.group(2) + ':' \
                and (g(4).startswith('movq #1,') or g(4).startswith('clr ')) and g(5) == g(2).split()[1] + ':':
            C['set cc,rd (a comparison as a value)'] += 1
            B['set cc,rd (a comparison as a value)'] += 8
        # abs: tst/cmp ; bge L ; neg r ; L:
        if re.match(r'(tst|cmp) ', a) and re.match(r'(bge|bgt) (\.L\d+)$', g(1)) and re.match(r'neg r\d+$', g(2)) and g(3) == g(1).split()[1] + ':':
            C['abs rs,rd'] += 1
            B['abs rs,rd'] += 4
        # min/max: cmp a,b ; bCC L ; movq x,y ; L:
        if a.startswith('cmp ') and re.match(r'(blt|bge|bgt|ble|bcs|bcc|bhi|blos) (\.L\d+)$', g(1)) and re.match(r'movq r\d+,r\d+$', g(2)) and g(3) == g(1).split()[1] + ':':
            C['min/max/minu/maxu ra,rb,rd'] += 1
            B['min/max/minu/maxu ra,rb,rd'] += 4
        # read-modify-write of a quad in memory
        m = re.match(r'movq (-?\d*\([^)]*\)|[A-Za-z_.][\w.$+-]*),(r\d+)$', a)
        if m:
            mem, r = m.groups()
            if re.match(r'(inc|dec) %s$' % r, g(1)) and g(2) == 'movq %s,%s' % (r, mem):
                C['inc/dec on a quad in memory'] += 1
                B['inc/dec on a quad in memory'] += 6
            mo = re.match(r'(add|sub|bis|bic|and|xor) (r\d+|#-?\d+),%s$' % r, g(1))
            if mo and g(2) == 'movq %s,%s' % (r, mem):
                if mo.group(1) in ('add', 'sub', 'bis', 'bic'):
                    C['addm/subm/bism/bicm (MESC read-modify-write, quad)'] += 1
                    B['addm/subm/bism/bicm (MESC read-modify-write, quad)'] += 6
                else:
                    C['and/xor on a quad in memory (no memory-destination form)'] += 1
        mo = re.match(r'movl (-?\d*\([^)]*\)|[A-Za-z_.][\w.$+-]*),(r\d+)$', a)
        if mo and re.match(r'(inc|dec|add|sub|bis|bic) .*%s$' % mo.group(2), g(1)) and g(2) == 'movl %s,%s' % (mo.group(2), mo.group(1)):
            C['read-modify-write of a 32-bit int in memory (needs sized operands)'] += 1
            B['read-modify-write of a 32-bit int in memory (needs sized operands)'] += 6
        # sob: dec r ; bne L backwards (the label was seen before)
        if re.match(r'dec r\d+$', a) and re.match(r'bne \.L\d+$', g(1)):
            C['sob (dec; bne)'] += 1
        # a narrow load straight into a compare with an immediate
        mc = re.match(r'(movzb|movb|movzw|movw) (.+),(r\d+)$', a)
        if mc and re.match(r'cmp %s,#-?\d+$' % mc.group(3), g(1)) and not re.match(r'r\d+$', mc.group(2)):
            C['narrow load; cmp reg,#imm (a sized compare with memory)'] += 1
        # a 32-bit load then add/sub/cmp with it
        ml = re.match(r'movl (.+),(r\d+)$', a)
        if ml and not re.match(r'r\d+$', ml.group(1)) and re.match(r'(add|sub|cmp|and|bis|xor|mul) (r\d+,%s|%s,r\d+)$' % (ml.group(2), ml.group(2)), g(1)):
            C['movl mem,r; op: a 32-bit load fused into the operation'] += 1
        # a load into a register only to compare it with a constant and r dead afterwards is not detectable here; zero extension + shift
        mz = re.match(r'movzl (r\d+),(r\d+)$', a)
        if mz and mz.group(1) == mz.group(2) and re.match(r'shr #\d+,%s$' % mz.group(1), g(1)):
            C['movzl r,r; shr #n,r (extzb)'] += 1
        # bit fields: shl then sar/shr
        if re.match(r'shl #\d+,(r\d+)$', a) and re.match(r'(movzl|movl) (r\d+),\2$', g(1)) is None and re.match(r'(sar|shr) #\d+,%s$' % a.split(',')[1], g(1)):
            C['shl #a; shr/sar #b (a bit-field extract: extb/extzb)'] += 1
        # division by a constant
        if re.match(r'movq #-?\d+,(r\d+)$', a) and re.match(r'(div|divu|mod|modu) r\d+,%s,r\d+$' % a.split(',')[1], g(1)):
            C['divide or remainder by a constant (mulh, shifts)'] += 1
        # rotate: shl #a,rX ... shr #b,rY ... bis with a+b = 32
        if a.startswith('shl #'):
            ma = re.match(r'shl #(\d+),(r\d+)$', a)
            for k in range(1, 6):
                mb = re.match(r'shr #(\d+),(r\d+)$', g(k))
                if mb and int(ma.group(1)) + int(mb.group(1)) in (32, 64):
                    C['rotate left by a constant: shl, shr, bis (32/64-bit)'] += 1
                    break
        # long immediates
        mi = re.match(r'(movq|cmp|add|and|bis|xor|sub|mul) (?:r\d+,)?#(-?\d+)', a)
        if mi:
            v = int(mi.group(2))
            if not -32768 <= v < 32768:
                C['immediate beyond 16 bits (a 6- or 8-byte instruction)'] += 1
                B['immediate beyond 16 bits (a 6- or 8-byte instruction)'] += (2 if -(1 << 31) <= v < (1 << 31) else 4)
        # a branch to a ret
    # switch chains: runs of >= 4 "cmp rN,#imm; beq L"
    run_len = 0
    last = None
    for i in range(0, n - 1):
        m = re.match(r'cmp (r\d+),#(-?\d+)$', L[i])
        if m and L[i + 1].startswith('beq ') and (last is None or m.group(1) == last):
            run_len += 1
            last = m.group(1)
        else:
            if run_len >= 4:
                C['a switch as a chain of >= 4 compares (jump table: jmpi)'] += 1
                C['  cases in those chains'] += run_len
            if m and L[i + 1].startswith('beq '):
                run_len, last = 1, m.group(1)
            else:
                run_len, last = 0, None
    # functions with a frame
    for i in range(n):
        if L[i] == 'push fp':
            C['functions with a frame pointer (non-leaf under -xdmr: none)'] += 1
rows = [[k, C[k], B.get(k, '')] for k in sorted(C, key=lambda k: -C[k])]
os.makedirs('/tmp/p64opt/analysis', exist_ok=True)
with open('/tmp/p64opt/analysis/candidates.csv', 'w', newline='') as f:
    c = csv.writer(f)
    c.writerow(['pattern (static count over the common files)', 'sites', 'estimated bytes saved'])
    c.writerows(rows)
for r in rows:
    print(r)
