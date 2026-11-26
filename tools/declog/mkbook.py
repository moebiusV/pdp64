#!/usr/bin/env python3
"""mkbook.py LOG.md BUILDDIR TITLE SUBTITLE SLUG

Builds a decision log (assemble.py's Markdown) into a PDF with buildabook (github.com/moebiusV/buildabook) and Typst:
splits the Markdown into chapters (Part I by month, Part II by category, the appendices), writes outline.txt, book.conf,
filemap.txt and the chapter files into BUILDDIR, runs `buildabook number-map`, `buildabook typst` and `typst compile`,
and leaves BUILDDIR/SLUG.pdf.  The template is book/template.typ of the repository.
"""
import os, re, shutil, subprocess, sys

log, build, title, subtitle, slug = sys.argv[1:6]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BAB = os.environ.get('BUILDABOOK') or shutil.which('buildabook') or os.path.expanduser('~/claude/buildabook/buildabook')
text = open(log).read().split('\n')


def sections(level):
    """split text into [(heading, [lines])] at headings of exactly `level` #'s; lines before the first are dropped"""
    pre = '#' * level + ' '
    res, cur = [], None
    for l in text:
        if l.startswith(pre):
            cur = (l[len(pre):], []); res.append(cur)
        elif cur is not None:
            cur[1].append(l)
    return res


def demote(lines, by):
    out = []
    for l in lines:
        m = re.match(r'^(#+) (.*)$', l)
        if m and len(m.group(1)) > by:
            out.append('#' * (len(m.group(1)) - by) + ' ' + m.group(2))
        else:
            out.append(l)
    return out


def clean(s):
    return s.replace('{{', '{ {')


h1 = {h: ls for h, ls in sections(1)}
shutil.rmtree(build, ignore_errors=True)
os.makedirs(os.path.join(build, 'chapters'))
outline, filemap = [], []


def put(uuid, fname, body, head=None):
    # head (a heading line holding a {{token}}) is written as it is; the body has `{{` neutralised
    open(os.path.join(build, 'chapters', fname), 'w').write(((head + '\n') if head else '') + clean('\n'.join(body)) + '\n')
    filemap.append('%s:%s' % (uuid, fname))


# front matter: About (the Contents list is for the Markdown; the book has its own)
about = [l for l in text if l.startswith('## About')] and None
sec2 = sections(2)
ab = next(ls for h, ls in sec2 if h == 'About this log')
put('id00001', 'about.md', ab, head='# About this log')
outline += ['n:id00001    About this log', '']
# Part I
outline += ['p:label:Part', 'p:number:roman', 'p:id00100    The instructions, in order', 'c:label:Chapter', 'c:number:arabic']
put('id00100', 'part-id00100.md', [], head='# {{p:id00100}} — The instructions, in order')
p1 = h1['Part I. The instructions, in order']
months, cur = [], None
for l in p1:
    if l.startswith('## '):
        cur = (l[3:], []); months.append(cur)
    elif cur is not None:
        cur[1].append(l)
n = 1000
for name, ls in months:
    n += 1
    u = 'id%05d' % n
    outline.append('c:%s    %s' % (u, name))
    put(u, 'c-%s.md' % u, ls, head='# {{c:%s}} — %s' % (u, name))
# Part II
outline += ['', 'p:id00200    The decisions, by the structure of the manual']
put('id00200', 'part-id00200.md', [], head='# {{p:id00200}} — The decisions, by the structure of the manual')
p2 = h1['Part II. The decisions, by the structure of the manual']
cats, cur = [], None
for l in p2:
    if l.startswith('## '):
        cur = (l[3:], []); cats.append(cur)
    elif cur is not None:
        cur[1].append(l)
n = 2000
for name, ls in cats:
    n += 1
    u = 'id%05d' % n
    outline.append('c:%s    %s' % (u, name))
    put(u, 'c-%s.md' % u, demote(ls, 2), head='# {{c:%s}} — %s' % (u, name))
# Appendices
outline += ['', 'p:id00300    Appendices', 'c:label:Appendix', 'c:number:letter', 'c:count:1']
put('id00300', 'part-id00300.md', [], head='# {{p:id00300}} — Appendices')
n = 3000
for h, ls in h1.items():
    m = re.match(r'Appendix [A-Z]\. (.*)$', h)
    if m:
        n += 1
        u = 'id%05d' % n
        outline.append('c:%s    %s' % (u, m.group(1)))
        put(u, 'a-%s.md' % u, ls, head='# {{c:%s}} — %s' % (u, m.group(1)))
open(os.path.join(build, 'outline.txt'), 'w').write('\n'.join(outline) + '\n')
open(os.path.join(build, 'filemap.txt'), 'w').write('\n'.join(filemap) + '\n')
tpl = open(os.path.join(ROOT, 'book', 'template.typ')).read()
tpl = tpl.replace('"The pdp64 Architecture Manual"', '"%s"' % title).replace('"A 64-bit extension of the PDP-11"', '"%s"' % subtitle)
tpl = tpl.replace('"Digital Equity Collective\'s Pragmatic Digital Processor, 64 bit"', '"A working document compiled from the author\'s own messages"')
tpl = re.sub(r'  Copyright #sym\.copyright.*?EB Garamond and DejaVu Sans Mono\.', '  Private working document, compiled from the author\'s own messages in his conversations with AI assistants. Not for publication. Typeset with Typst in EB Garamond and DejaVu Sans Mono.', tpl, flags=re.S)
i = tpl.index('#show heading.where(level: 2)')
tpl = tpl[:i] + tpl[i:].replace('pagebreak(weak: true)', '', 1)   # subjects flow on; only chapters start a page
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
run(BAB, 'number-map')
run(BAB, 'typst')
run('typst', 'compile', '--root', '.', 'rendered/book.typ', slug + '.pdf')
print('built', os.path.join(build, slug + '.pdf'))
