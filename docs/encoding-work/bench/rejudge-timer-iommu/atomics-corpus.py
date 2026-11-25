#!/usr/bin/env python3
# Static census of the locked (atomic) instructions of x86-64 Linux kernel modules: how often the address has a nonzero
# displacement, which operand sizes occur, and how often a compare-and-swap is a lock acquire (expected value zero).
# usage: atomics-corpus.py OBJDUMP_TEXT_FILE...   or   atomics-corpus.py -   (file names on standard input)   (each made by: objdump -d --no-show-raw-insn m.ko)
import re, sys, collections
ins = re.compile(r'^\s*[0-9a-f]+:\s+(.*)$')
mem = re.compile(r'(-?0x[0-9a-f]+|)\((%[a-z0-9]+)(?:,(%[a-z0-9]+)(?:,(\d))?)?\)')
BASE = ('add', 'sub', 'and', 'or', 'xor', 'inc', 'dec', 'neg', 'not', 'cmpxchg', 'xadd', 'bts', 'btr', 'btc', 'xchg', 'adc', 'sbb')
C = collections.Counter()
files = sys.argv[1:]
if files == ['-']:
    files = [l.rstrip('\n') for l in sys.stdin]
C['modules'] = len(files)
for fn in files:
    prev = []
    for line in open(fn, errors='replace'):
        m = ins.match(line)
        if not m:
            continue
        t = m.group(1).split('#')[0].strip()
        if t.startswith('lock '):
            body = t[5:].strip()
            op = body.split()[0]
            rest = body[len(op):].strip()
            base = op[:-1] if (op[-1] in 'bwlq' and op[:-1] in BASE) else op
            C['total'] += 1
            C['op:' + base] += 1
            sz = None
            regs = re.sub(r'[^,\s]*\([^)]*\)', '', rest)  # operands outside the memory reference
            if base != op:
                sz = op[-1]
            elif re.search(r'%r(ax|bx|cx|dx|si|di|bp|[0-9]+)\b', regs):
                sz = 'q'
            elif re.search(r'%e[a-z]{2}\b|%r[0-9]+d\b', regs):
                sz = 'l'
            elif re.search(r'%[a-d]x\b|%r[0-9]+w\b|%si\b|%di\b', regs):
                sz = 'w'
            elif re.search(r'%[a-d]l\b|%r[0-9]+b\b|%sil\b|%dil\b', regs):
                sz = 'b'
            C['size:' + (sz or '?')] += 1
            if base in ('cmpxchg', 'xadd', 'xchg'):
                C['size of ' + base + ':' + (sz or '?')] += 1
            mm = mem.search(rest)
            if 'rip' in rest:
                C['addr:rip-relative(global)'] += 1
            elif mm:
                d = mm.group(1)
                if mm.group(3):
                    C['addr:indexed'] += 1
                elif d in ('', '0x0'):
                    C['addr:zero-disp'] += 1
                else:
                    C['addr:nonzero-disp'] += 1
                    v = int(d, 16)
                    for lim in (120, 504, 2040, 32760):
                        if 0 < v <= lim:
                            C['disp<=%d bytes (cumulative)' % lim] += 1
                    if v < 0 or v > 32760:
                        C['disp negative or above 32760'] += 1
            else:
                C['addr:other'] += 1
            if base == 'cmpxchg':
                C['cmpxchg'] += 1
                if any(re.search(r'xor\s+%e?ax,%e?ax|mov\s+\$0x0,%e?ax', p) for p in prev[-3:]):
                    C['cmpxchg:expected zero (xor or mov 0 within 3 before)'] += 1
        elif re.match(r'xchg\s+%\w+,\(', t) or (re.match(r'xchg\s+\S+,%\w+$', t) and '(' in t):
            C['xchg-mem (implicitly locked)'] += 1
        prev.append(t)
        if len(prev) > 4:
            prev.pop(0)
for k in sorted(C):
    print('%-56s %d' % (k, C[k]))
