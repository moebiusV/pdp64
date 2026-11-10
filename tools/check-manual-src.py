#!/usr/bin/env python3
"""Tests of the assembly mechanism of the manual (tools/manual/assemble.py): the refusal of the old per-CPU markers, the number and link checks, the appendices of fragments."""
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
# the appendices of fragments (H proposed, I deferred, J open)
tx = {'02-bus.md': '# 2. The bus\n', '03-g.md': '# 3. Graphics\n', 'appendix-d-abi.md': '# Appendix D. The ABI\n',
      'appendix-h-proposed.md': '# Appendix H. Proposed\n<!-- parts:proposed -->\n<!-- /parts:proposed -->\n',
      'appendix-j-open.md': '# Appendix J. Open items\n<!-- parts:open -->\n<!-- /parts:open -->\n'}
assert A.assemble_parts(tx, {}) == [] and 'Nothing is proposed.' in tx['appendix-h-proposed.md'] and 'There are no open items.' in tx['appendix-j-open.md']
fr = {'02-proposed.md': '**2.3.3** (moved from chapter 2) a\n', '03-proposed.md': '\n', 'd-open.md': '<a id="jd1"></a>\n### J.D.1 Q\n', '03-open.md': '\n'}
tx2 = dict(tx)
assert A.assemble_parts(tx2, fr) == []
h = tx2['appendix-h-proposed.md']
assert '## H.2 Chapter 2: The bus' in h and 'Chapter 3' not in h and '**2.3.3**' in h, h
j = tx2['appendix-j-open.md']
assert '## J.D Appendix D: The ABI' in j and 'Chapter 3' not in j, j
assert A.assemble_parts(dict(tx), {'03-open.md': 'x\n'}) == [] and A.assemble_parts(dict(tx), {'99-open.md': 'x\n'}) and A.assemble_parts(dict(tx), {'x.md': 'x\n'})
try:
    A.assemble_parts(dict(tx), {'03-open.md': '<!-- members: 16 -->\nx\n'})
    raise SystemExit('accepted a members line in a fragment')
except A.SourceError:
    pass
app = {'02-bus.md': '# 2. X\n\n## 2.1 A\n\n**2.1.1** s\n\nsee section 2.3.3 and section J.3.2 and section J.D.1\n',
       'appendix-h-proposed.md': '# Appendix H\n\n## H.2 Chapter 2: X\n\n**2.3.3** (moved from chapter 2) a\n',
       'appendix-j-open.md': '# Appendix J\n\n## J.3 Chapter 3: G\n\n<a id="j32"></a>\n### J.3.1 a\n\n### J.3.2 b\n\n## J.D Appendix D: A\n\n### J.D.1 c\n'}
assert A.verify(app, set(app), '.') == [], A.verify(app, set(app), '.')
bad = dict(app); bad['appendix-j-open.md'] = app['appendix-j-open.md'].replace('J.3.2 b', 'J.3.3 b')
assert A.verify(bad, set(bad), '.')
bad = dict(app); del bad['appendix-h-proposed.md']
assert A.verify(bad, set(bad), '.')
print('manual assembly: ok')
