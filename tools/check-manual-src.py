#!/usr/bin/env python3
"""Tests of the assembly mechanism of the manual (tools/manual/assemble.py) and of the computed numbers (tools/manual/bookrefs.py): the refusal of the old per-CPU markers,
the number and link checks, the design notes assembled from fragments; the numbering of sections, statements and figures from the order of the text, the citations by name,
the errors (an unknown name, a name defined twice, a marker in a file that has no number), and that inserting a section renumbers every citation."""
import os, re, sys, tempfile
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'manual'))
import assemble as A
import bookrefs as BR

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

# ---------------------------------------------------------------- the computed numbers
tmp = tempfile.mkdtemp()
open(os.path.join(tmp, 'outline.txt'), 'w').write('n:id00001    About\np:id00100    Part\nc:id01001    One\nc:id01002    Two\nc:label:Appendix\nc:number:letter\nc:count:1\nc:id03001    Extra\n')
open(os.path.join(tmp, 'sources.txt'), 'w').write('n:id00001 docs/manual/00-index.md\nc:id01001 docs/manual/01-one.md\nc:id01002 docs/manual/02-two.md\nc:id03001 docs/manual/appendix-a-extra.md\n')
SRC = {'00-index.md': '# Index\n\n{{n}}. [**One**](01-one.md)\n{{n}}. [**Two**](02-two.md)\n\n{{n}}. again\n',
       '01-one.md': '# {{c:id01001|n}}. One\n\n## {{#first}} First\n\n**{{#rule-a}}** A, see {{r:rule-b}} and section {{r:second}} and chapter {{c:id01002|n}}.\n\n**{{#rule-b}}** B.\n\n## {{#second}} Second\n\n**{{#rule-c}}** C.\n\n![{{#fig-x}}alt](figures/x.svg)\n\nFigure {{r:fig-x}}, [{{r:second}}]({{u:second}}), appendix {{c:id03001|n}}.\n',
       '02-two.md': '# {{c:id01002|n}}. Two\n\n## {{#third}} Third\n\nsection {{r:rule-c}}, section {{r:first}}\n',
       'appendix-a-extra.md': '# Appendix {{c:id03001|n}}. Extra\n\n## {{#a-first}} A first\n\n**{{#a-rule}}** x see {{r:a-first}}\n'}


def book(src):
    b = BR.Book(os.path.join(tmp, 'outline.txt'), os.path.join(tmp, 'sources.txt'))
    b.number(src)
    return b, {fn: b.resolve(x, fn) for fn, x in src.items()}


def refused(src, frag):
    try:
        book(src)
    except BR.RefError as e:
        assert frag in str(e), (frag, str(e))
        return
    raise SystemExit('accepted: ' + frag)


b, out = book(SRC)
assert out['01-one.md'].startswith('# 1. One\n\n## 1.1 First\n\n**1.1.1** A, see 1.1.2 and section 1.2 and chapter 2.'), out['01-one.md']
assert 'Figure 1.1,' in out['01-one.md'] and '[1.2](01-one.md#12-second)' in out['01-one.md'] and 'appendix A.' in out['01-one.md']
assert out['02-two.md'].endswith('section 1.2.1, section 1.1\n') and '## 2.1 Third' in out['02-two.md']
assert '**A.1.1** x see A.1' in out['appendix-a-extra.md'] and '1. [**One**]' in out['00-index.md'] and '2. [**Two**]' in out['00-index.md'] and '\n1. again' in out['00-index.md']
assert BR.leftover(''.join(out.values())) == []
# a section and a statement inserted before the others: every number and every citation follows
ins = dict(SRC)
ins['01-one.md'] = ins['01-one.md'].replace('## {{#first}} First', '## {{#new}} New\n\n**{{#new-rule}}** N.\n\n## {{#first}} First')
b2, out2 = book(ins)
assert b2.defs['first']['num'] == '1.2' and b2.defs['rule-b']['num'] == '1.2.2' and 'section 1.3 and' in out2['01-one.md'] and out2['02-two.md'].endswith('section 1.3.1, section 1.2\n'), out2['02-two.md']
# the errors
refused({**SRC, '02-two.md': SRC['02-two.md'] + '\nsee {{r:nosuch}}\n'}, 'nosuch')
refused({**SRC, '02-two.md': SRC['02-two.md'] + '\n**{{#rule-a}}** twice\n'}, 'defined twice')
refused({**SRC, '00-index.md': SRC['00-index.md'] + '\n## {{#in-index}} Not numbered\n'}, 'not a numbered chapter')
refused({**SRC, '02-two.md': '# {{c:id01002|n}}. Two\n\n**{{#early}}** before any section\n'}, 'before the first numbered section')
refused({**SRC, '02-two.md': SRC['02-two.md'] + '\nsome **text {{#mid}}** here\n'}, 'must be at the start')
try:
    BR.ordinals('x {{n}} y\n')
    raise SystemExit('accepted {{n}} in the middle of a line')
except BR.RefError:
    pass
try:
    b.resolve('chapter {{c:id09999|n}}')
    raise SystemExit('accepted an unknown chapter')
except BR.RefError:
    pass
# the real manual: every name defined once, every citation resolves, and the number of every chapter and appendix is the outline's
real = BR.Book(os.path.join(ROOT, 'book', 'outline.txt'), os.path.join(ROOT, 'book', 'sources.txt'))
order = [os.path.basename(f) for f in real.file_uuid]
src = os.path.join(ROOT, 'docs', 'manual-src')
rf = {fn: open(os.path.join(src, fn)).read() for fn in os.listdir(src) if fn.endswith('.md') and fn != 'README.md'}
rf = {fn: rf[fn] for fn in sorted(rf, key=lambda f: (order.index(f) if f in order else len(order), f))}
rr = real.resolve_all(rf)
assert not [fn for fn, x in rr.items() if BR.leftover(x)]
assert all(re.match(r'^# (\d+|Appendix [A-E])\. ', x) for fn, x in rr.items() if fn[0] in '0a' and fn != '00-index.md' and real.chapter_label(fn)), 'a chapter heading'
print('manual numbering: ok (%d names)' % len(real.defs))
