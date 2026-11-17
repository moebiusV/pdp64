#!/usr/bin/env python3
"""mkstatusbook.py STATUS.md BUILDDIR TITLE SUBTITLE SLUG: build a status ledger (status.py's Markdown) into a PDF with
buildabook and Typst: the part under the title is the front matter (without its Contents list), every other `# ` heading is a
chapter.  Template: book/template.typ of the repository, with the title page text replaced and sections flowing on."""
import os, re, shutil, subprocess, sys

log, build, title, subtitle, slug = sys.argv[1:6]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BAB = os.environ.get('BUILDABOOK') or shutil.which('buildabook') or os.path.expanduser('~/claude/buildabook/buildabook')
text = open(log).read().split('\n')
front, chaps, cur = [], [], None
for l in text:
    if l.startswith('# ') and not l.startswith('## '):
        if front == [] and cur is None and not chaps and l[2:] == text[0][2:]:
            cur = front; continue
        cur = [l[2:], []]; chaps.append(cur)
    elif cur is front:
        front.append(l)
    elif cur is not None:
        cur[1].append(l)
# drop the Contents list from the front matter
fm, skip = [], False
for l in front:
    if l.startswith('## Contents'): skip = True; continue
    if l.startswith('## ') and skip: skip = False
    if not skip: fm.append(l)
clean = lambda s: s.replace('{{', '{ {')
shutil.rmtree(build, ignore_errors=True)
os.makedirs(os.path.join(build, 'chapters'))
outline, filemap = ['n:id00001    About this ledger', '', 'c:label:Chapter', 'c:number:arabic'], ['id00001:about.md']
open(os.path.join(build, 'chapters', 'about.md'), 'w').write('# About this ledger\n' + clean('\n'.join(l for l in fm if not l.startswith('## About'))) + '\n')
for i, (name, ls) in enumerate(chaps, 1):
    u = 'id%05d' % (1000 + i)
    outline.append('c:%s    %s' % (u, re.sub(r'\s*\(\d+\)$', '', name) if False else name))
    fn = 'c-%s.md' % u
    open(os.path.join(build, 'chapters', fn), 'w').write('# {{c:%s}} — %s\n' % (u, name) + clean('\n'.join(ls)) + '\n')
    filemap.append('%s:%s' % (u, fn))
open(os.path.join(build, 'outline.txt'), 'w').write('\n'.join(outline) + '\n')
open(os.path.join(build, 'filemap.txt'), 'w').write('\n'.join(filemap) + '\n')
tpl = open(os.path.join(ROOT, 'book', 'template.typ')).read()
tpl = tpl.replace('"The pdp64 Architecture Manual"', '"%s"' % title).replace('"A 64-bit extension of the PDP-11"', '"%s"' % subtitle)
tpl = tpl.replace('"Digital Equity Collective\'s Pragmatic Digital Processor, 64 bit"', '"A working document compiled from the author\'s own messages"')
tpl = re.sub(r'  Copyright #sym\.copyright.*?EB Garamond and DejaVu Sans Mono\.', '  Private working document, compiled from the author\'s own messages in his conversations with AI assistants. Not for publication. Typeset with Typst in EB Garamond and DejaVu Sans Mono.', tpl, flags=re.S)
i = tpl.index('#show heading.where(level: 2)')
tpl = tpl[:i] + tpl[i:].replace('pagebreak(weak: true)', '', 1)
open(os.path.join(build, 'template.typ'), 'w').write(tpl)
open(os.path.join(build, 'book.conf'), 'w').write('''title "%s"
subtitle "%s"
tagline "From the author's own messages"
author "David Walther"
year 2026
slug %s

build {
    outline    outline.txt
    src        chapters
    out        rendered
    template   template.typ
    number-map number_map.csv
}
''' % (title, subtitle, slug))
run = lambda *a: subprocess.run(a, cwd=build, check=True)
run(BAB, 'number-map'); run(BAB, 'typst'); run('typst', 'compile', '--root', '.', 'rendered/book.typ', slug + '.pdf')
print('built', os.path.join(build, slug + '.pdf'))
