#!/usr/bin/env python3
"""Tests of the assembly mechanism of the manual (tools/manual/assemble.py): the refusal of the old per-CPU markers, the number and link checks, the design notes assembled from fragments."""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'manual'))
import assemble as A

for ok in ('a\nb\n', 'text with [x](y.md) and `code`\n'):
    assert A.resolve(ok) == ok
for bad in ('<!-- member: 16 32 -->\nx\n<!-- /member -->\n', '<!-- members: 16 -->\nx\n', 'e [[16: x]]', 'e [[r20: z]]', 'see @@PDF@@', '@@MEMBER@@', '@@ID@@'):
    try:
        A.resolve(bad)
    except A.SourceError:
        continue
    raise SystemExit('accepted: ' + repr(bad))
good = {'09-isa.md': '# 9. X\n\n## 9.1 A\n\n**9.1.1** s\n\n**9.1.2** t\n\n## 9.2 B\n\nsee section 9.1.2 and [a](#91-a)\n', 'dictionary/x.md': '# x\n'}
assert A.verify(good, set(good), '.') == [], A.verify(good, set(good), '.')
for name, text in (('gap', good['09-isa.md'].replace('9.1.2', '9.1.3')), ('sec', good['09-isa.md'].replace('## 9.2', '## 9.3')),
                   ('ref', good['09-isa.md'].replace('section 9.1.2', 'section 9.7')), ('link', good['09-isa.md'].replace('(#91-a)', '(nosuch.md)'))):
    assert A.verify({'09-isa.md': text}, {'09-isa.md'}, '.'), name
# the design notes of fragments (H proposed, I deferred, J open); the titles of the chapters and appendices come from the manual
mn = {'02-bus.md': '# 2. The bus\n', '03-g.md': '# 3. Graphics\n', 'appendix-c-abi.md': '# Appendix C. The ABI\n'}
tx = {'appendix-h-proposed.md': '# Proposed\n<!-- parts:proposed -->\n<!-- /parts:proposed -->\n',
      'appendix-j-open.md': '# Open items\n<!-- parts:open -->\n<!-- /parts:open -->\n'}
assert A.assemble_parts(tx, {}, mn) == [] and 'Nothing is proposed.' in tx['appendix-h-proposed.md'] and 'There are no open items.' in tx['appendix-j-open.md']
fr = {'02-proposed.md': '**2.3.3** (moved from chapter 2) a\n', '03-proposed.md': '\n', 'd-open.md': '<a id="jd1"></a>\n### J.D.1 Q\n', '03-open.md': '\n'}
tx2 = dict(tx)
assert A.assemble_parts(tx2, fr, mn) == []
h = tx2['appendix-h-proposed.md']
assert '## H.2 Chapter 2: The bus' in h and 'Chapter 3' not in h and '**2.3.3**' in h, h
j = tx2['appendix-j-open.md']
assert '## J.D Appendix D: The ABI (appendix C of the manual)' in j and 'Chapter 3' not in j, j
assert A.assemble_parts(dict(tx), {'03-open.md': 'x\n'}, mn) == [] and A.assemble_parts(dict(tx), {'99-open.md': 'x\n'}, mn) and A.assemble_parts(dict(tx), {'x.md': 'x\n'}, mn)
try:
    A.assemble_parts(dict(tx), {'03-open.md': '<!-- members: 16 -->\nx\n'}, mn)
    raise SystemExit('accepted a members line in a fragment')
except A.SourceError:
    pass
# the numbers and links of the design notes (docs/design/): their own letters, no check of the manual's numbers, a link into the manual needs its target
app = {'proposed.md': '# Proposed\n\n## H.2 Chapter 2: X\n\n**2.3.3** (moved from chapter 2) a\n',
       'open-items.md': '# Open items\n\n## J.3 Chapter 3: G\n\n<a id="j32"></a>\n### J.3.1 a\n\n### J.3.2 b\n\nsee section J.3.2, section 2.3.3 and section 9.99 and [p](proposed.md#h2-chapter-2-x) and [m](../manual/09-isa.md#a)\n\n## J.D Appendix D: A\n\n### J.D.1 c\n'}
man = {'../manual/09-isa.md': {'a'}}
DD = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'docs', 'design')
assert A.verify(app, set(app), DD, design=True, foreign=man) == [], A.verify(app, set(app), DD, design=True, foreign=man)
bad = dict(app); bad['open-items.md'] = app['open-items.md'].replace('J.3.2 b', 'J.3.3 b')
assert A.verify(bad, set(bad), DD, design=True, foreign=man)
bad = dict(app); bad['open-items.md'] = app['open-items.md'].replace('section J.3.2', 'section J.3.9')
assert A.verify(bad, set(bad), DD, design=True, foreign=man)
bad = dict(app); bad['open-items.md'] = app['open-items.md'].replace('(proposed.md#', '(nosuch.md#')
assert A.verify(bad, set(bad), DD, design=True, foreign=man)
assert A.verify(app, set(app), DD, design=True, foreign={'../manual/09-isa.md': {'b'}})
print('manual assembly: ok')
