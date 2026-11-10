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
# the appendices of fragments (H proposed, I deferred, J open)
tx = {'02-bus.md': '# 2. The bus\n', '03-g.md': '# 3. Graphics\n', 'appendix-d-abi.md': '# Appendix D. The ABI\n',
      'appendix-h-proposed.md': '# Appendix H. Proposed\n<!-- parts:proposed -->\n<!-- /parts:proposed -->\n',
      'appendix-j-open.md': '# Appendix J. Open items\n<!-- parts:open -->\n<!-- /parts:open -->\n'}
assert A.assemble_parts(tx, {}, '32') == [] and 'Nothing is proposed.' in tx['appendix-h-proposed.md'] and 'There are no open items.' in tx['appendix-j-open.md']
fr = {'02-proposed.md': '**2.3.3** (moved from chapter 2) a\n', '03-proposed.md': '\n', 'd-open.md': '<a id="jd1"></a>\n### J.D.1 Q\n', '03-open.md': '<!-- members: 16 -->\nx\n'}
tx2 = dict(tx)
assert A.assemble_parts(tx2, fr, '32') == []
h = tx2['appendix-h-proposed.md']
assert '## H.2 Chapter 2: The bus' in h and 'Chapter 3' not in h and '**2.3.3**' in h, h
j = tx2['appendix-j-open.md']
assert '## J.D Appendix D: The ABI' in j and 'Chapter 3' not in j, j
assert A.assemble_parts(dict(tx), {'03-open.md': 'x\n'}, '16') == [] and A.assemble_parts(dict(tx), {'99-open.md': 'x\n'}, '16') and A.assemble_parts(dict(tx), {'x.md': 'x\n'}, '16')
app = {'02-bus.md': '# 2. X\n\n## 2.1 A\n\n**2.1.1** s\n\nsee section 2.3.3 and section J.3.2 and section J.D.1\n',
       'appendix-h-proposed.md': '# Appendix H\n\n## H.2 Chapter 2: X\n\n**2.3.3** (moved from chapter 2) a\n',
       'appendix-j-open.md': '# Appendix J\n\n## J.3 Chapter 3: G\n\n<a id="j32"></a>\n### J.3.1 a\n\n### J.3.2 b\n\n## J.D Appendix D: A\n\n### J.D.1 c\n'}
assert A.verify(app, set(app), '.') == [], A.verify(app, set(app), '.')
bad = dict(app); bad['appendix-j-open.md'] = app['appendix-j-open.md'].replace('J.3.2 b', 'J.3.3 b')
assert A.verify(bad, set(bad), '.')
bad = dict(app); del bad['appendix-h-proposed.md']
assert A.verify(bad, set(bad), '.')
print('manual assembly: ok')
