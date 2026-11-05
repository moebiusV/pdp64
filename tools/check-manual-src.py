#!/usr/bin/env python3
"""Tests of the assembly mechanism of the manuals (tools/manual/assemble.py): member blocks, inline words, whole-file members, the number and link checks."""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'manual'))
import assemble as A

src = 'a\n<!-- member: 16 32 -->\nb\n<!-- /member -->\n<!-- member: !r20 -->\nc\n<!-- /member -->\n<!-- member: r20 -->\nd\n<!-- /member -->\ne [[16: x]][[32: y]][[r20: z]] @@ID@@ @@MEMBER@@ @@PDF@@\n'
want = {'r20': 'a\nd\ne z r20 pdp64/r20 pdp64-r20.pdf\n', '16': 'a\nb\nc\ne x 16 pdp64/16 pdp64-16.pdf\n', '32': 'a\nb\nc\ne y 32 pdp64/32 pdp64-32.pdf\n'}
for m in A.MEMBERS:
    got = A.for_member(src, m)
    assert got == want[m], (m, got)
assert A.file_members('<!-- members: 16 32 -->\nx') == ['16', '32'] and A.file_members('x') == list(A.MEMBERS)
for bad in ('<!-- member: 16 -->\nx\n', '<!-- member: 16 --><!-- member: 32 -->\n', '<!-- member: 16 -->\n<!-- member: 32 -->\n<!-- /member -->\n<!-- /member -->\n', '<!-- member: 17 -->\n<!-- /member -->\n', '<!-- /member -->\n'):
    try:
        A.for_member(bad, '16')
    except A.SourceError:
        continue
    raise SystemExit('accepted: ' + repr(bad))
good = {'09-isa.md': '# 9. X\n\n## 9.1 A\n\n**9.1.1** s\n\n**9.1.2** t\n\n## 9.2 B\n\nsee section 9.1.2 and [a](#91-a)\n', 'dictionary/x.md': '# x\n'}
assert A.verify(good, set(good), '.') == [], A.verify(good, set(good), '.')
for name, text in (('gap', good['09-isa.md'].replace('9.1.2', '9.1.3')), ('sec', good['09-isa.md'].replace('## 9.2', '## 9.3')),
                   ('ref', good['09-isa.md'].replace('section 9.1.2', 'section 9.7')), ('link', good['09-isa.md'].replace('(#91-a)', '(nosuch.md)'))):
    assert A.verify({'09-isa.md': text}, {'09-isa.md'}, '.'), name
print('manual assembly: ok')
