#!/usr/bin/env python3
"""Label every instruction of a program so that a trace of program counters can be read against the source.
usage: sites.py IN.pp.s OUT.s     (IN.pp.s: the program after tools/pp-asm.sh)
Writes OUT.s with a global label  __I_<k>:  before every instruction of a text section (k = 1, 2, ... in source order; labels do not change the code) and OUT.s.ins with one line
per instruction: k, source line of IN.pp.s, text.  Directives, data and constant definitions are not instructions."""
import sys, re
src, out = sys.argv[1], sys.argv[2]
lines = open(src).read().split('\n')
res, ins, k, intext, labs = [], [], 0, True, []
for ln, l in enumerate(lines, 1):
    code = l.split(';')[0]
    mm = re.match(r'^((?:\s*(?:[A-Za-z_][\w.$]*|\d+):)*)', code)
    if intext and mm and mm.group(1).strip():
        for nm in re.findall(r'([A-Za-z_][\w.$]*|\d+):', mm.group(1)): labs.append((nm, k + 1))
    body = re.sub(r'^\s*(?:[A-Za-z_][\w.$]*:|\d+:)*\s*', '', code).strip()
    if re.match(r'^\s*\.(data|bss|rodata)\b', body): intext = False
    elif re.match(r'^\s*\.text\b', body): intext = True
    isins = bool(body) and intext and not body.startswith('.') and not re.match(r'^[A-Za-z_]\w*\s*=(\s|$)', body) and not re.match(r'^[A-Za-z_]\w*=', body)
    if isins:
        k += 1
        res.append('__I_%d:' % k)
        res.append('\t.globl\t__I_%d' % k)
        ins.append((k, ln, body))
    res.append(l)
open(out, 'w').write('\n'.join(res) + '\n')
open(out + '.ins', 'w').write(''.join('%d\t%d\t%s\n' % t for t in ins))
open(out + '.lab', 'w').write(''.join('%s\t%d\n' % t for t in labs))
