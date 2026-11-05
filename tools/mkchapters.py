#!/usr/bin/env python3
"""Prepare the chapters of the manual for buildabook (github.com/moebiusV/buildabook).

buildabook builds a book from `chapters/*.md`, `outline.txt`, a filemap (UUID:filename) and a Typst template; it numbers the
entries from the outline and resolves {{token}} references.  The Markdown of the manual (docs/manual/) is written for the
web, so this turns each page into a chapter file: the heading becomes `{{c:id01001}} - Title` (the number comes from buildabook),
links between the pages become plain text (links to other files of the repository become GitHub links), HTML comments go, and
`{{` is escaped.  It also checks, against buildabook's own number map, that the number in each source heading ("# 6. The kernel",
"# Appendix B. ...") is the number the outline gives the entry, because the section numbers inside the text (6.7, 7.12) are literal.

Run by tools/mkbook.sh in book/build-MEMBER/, after `buildabook number-map` has written number_map.csv:

    tools/mkchapters.py MEMBER write book/build-MEMBER/chapters/*.md, book/build-MEMBER/filemap.txt, book/build-MEMBER/figures/
    tools/mkchapters.py MEMBER --outline   print book/outline.txt for that member
"""
import csv, os, re, shutil, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BOOK = os.path.join(ROOT, 'book')
MEMBERS = ('r20', '16', '32')
ID = 'r20'                                              # the member (argument 1); set by main()
BUILD = os.path.join(BOOK, 'build-r20')
CHAP = os.path.join(BUILD, 'chapters')
GITHUB = 'https://github.com/moebiusV/pdp64/blob/main/'
STREAM = os.path.join(ROOT, 'docs', 'manual', 'pdp64-r20')


def setmember(member):
    global ID, BUILD, CHAP, STREAM
    ID = member
    BUILD = os.path.join(BOOK, 'build-' + member)
    CHAP = os.path.join(BUILD, 'chapters')
    STREAM = os.path.join(ROOT, 'docs', 'manual', 'pdp64-' + member)


def outline_for(member):
    """book/outline.txt for one member: a line that starts with `@16,32:` is only in the books of those members"""
    out = []
    for line in open(os.path.join(BOOK, 'outline.txt')):
        m = re.match(r'^@([a-z0-9,]+):(.*)$', line.rstrip('\n'))
        if m:
            if member in m.group(1).split(','):
                out.append(m.group(2) + '\n')
        else:
            out.append(line)
    return ''.join(out)


def read_sources():
    m = {}
    for line in open(os.path.join(BOOK, 'sources.txt')):
        line = line.strip()
        if line and not line.startswith('#'):
            tok, path = line.split(None, 1)
            m[tok.split(':', 1)[1]] = path.replace('@ID@', ID)
    return m


def convert_links(text, srcpath):
    """Links inside the book become plain text; links outside it become GitHub URLs."""
    srcdir = os.path.dirname(srcpath)

    def one(m):
        label, url = m.group(1), m.group(2)
        if re.match(r'^(https?:|mailto:)', url):
            return m.group(0)
        path = url.split('#')[0]
        if not path:
            return label
        full = os.path.normpath(os.path.join(srcdir, path))
        if path.endswith('.md') and full.startswith(STREAM):
            return label
        return '[%s](%s%s)' % (label, GITHUB, os.path.relpath(full, ROOT))
    return re.sub(r'(?<!!)\[([^\]]+)\]\(([^)\s]+)\)', one, text)


CHARTRUN = 6          # a run of at most this many charts of one instruction is kept together with the heading before it and the text after it; a longer run only at its two ends


def mark_sticky(body):
    """The charts of a dictionary entry (figures/w/...) are a run of images between blank lines.  The author's rule: an entry's title and charts are not left at the bottom of a page
    without text after them.  The images that must stay with the next block get `?s` on their path; book/template.typ turns that into a sticky block."""
    lines = body.split('\n')
    out = []
    i = 0
    pat = re.compile(r'^(!\[[^\n]*\]\()(figures/[^)]*)(\))$')
    while i < len(lines):
        if pat.match(lines[i]):
            run = []
            j = i
            while j < len(lines) and (pat.match(lines[j]) or (lines[j] == '' and j + 1 < len(lines) and pat.match(lines[j + 1]))):
                if lines[j]:
                    run.append(j)
                j += 1
            for k, idx in enumerate(run):
                keep = len(run) <= CHARTRUN or k in (0, len(run) - 1)
                lines[idx] = pat.sub(lambda m: m.group(1) + m.group(2) + ('?s' if keep else '') + m.group(3), lines[idx])
            out += lines[i:j]
            i = j
        else:
            out.append(lines[i])
            i += 1
    return '\n'.join(out)


def chapter_text(row, src, srcpath):
    lines = src.split('\n')
    i = next(k for k, l in enumerate(lines) if l.startswith('# '))
    title = lines[i][2:].strip()
    rest = [l for l in lines[i + 1:] if not l.startswith('[← ')]
    body = '\n'.join(rest).strip('\n') + '\n'
    kind, uuid = row['kind'], row['uuid']
    if kind == 'front-matter':
        k = body.index('## How to read it')
        body = body[k:].replace('## How to read it', '', 1).lstrip('\n')
        head = row['title']
    elif kind == 'chapter':
        m = re.match(r'^(\d+)\.\s+(.*)$', title)
        if not m:
            raise SystemExit('%s: heading %r has no chapter number' % (srcpath, title))
        if 'Chapter ' + m.group(1) != row['rendered']:
            raise SystemExit('%s: the heading says chapter %s but buildabook numbers it "%s"; the section numbers in the text would be wrong' % (srcpath, m.group(1), row['rendered']))
        head = '{{c:%s}} — %s' % (uuid, m.group(2))
    elif kind == 'appendix':
        m = re.match(r'^Appendix ([A-Z])\.\s+(.*)$', title)
        if not m:
            raise SystemExit('%s: heading %r has no appendix letter' % (srcpath, title))
        if 'Appendix ' + m.group(1) != row['rendered']:
            raise SystemExit('%s: the heading says appendix %s but buildabook numbers it "%s"' % (srcpath, m.group(1), row['rendered']))
        head = '{{a:%s}} — %s' % (uuid, m.group(2))
    else:
        head = row['title']
    body = convert_links(body, srcpath)
    body = body.replace('](../figures/', '](figures/')
    body = re.sub(r'<!--.*?-->\n?', '', body, flags=re.S)
    body = re.sub(r'<a id="[^"]*"></a>', '', body)
    body = re.sub(r'(?m)^\*\*(Syntax|Encoding|Operation)\*\*\n', r'##### \1\n', body)      # a label that must stay with what it labels is a (sticky) heading in the book
    body = mark_sticky(body)           # the anchors of the dictionary pages are for the web
    body = body.replace('{{', '{ {')
    return '# %s\n\n%s' % (head, body)


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in MEMBERS:
        raise SystemExit('usage: mkchapters.py r20|16|32 [--outline]')
    setmember(sys.argv[1])
    if '--outline' in sys.argv:
        sys.stdout.write(outline_for(ID))
        return
    rows = list(csv.DictReader(open(os.path.join(BUILD, 'number_map.csv'))))
    src = read_sources()
    shutil.rmtree(CHAP, ignore_errors=True)
    os.makedirs(CHAP)
    fm = []
    used = set()
    for row in rows:
        kind, uuid = row['kind'], row['uuid']
        if kind in ('section', 'sub-entry'):
            continue
        if kind == 'part':
            name = 'part-%s.md' % uuid
            text = '# {{p:%s}} — %s\n' % (uuid, row['title'])
        else:
            path = src.get(uuid)
            if not path:
                raise SystemExit('no source file for %s (%s)' % (uuid, row['title']))
            full = os.path.join(ROOT, path)
            if not os.path.exists(full):
                raise SystemExit('%s: %s does not exist' % (uuid, path))
            name = re.sub(r'^docs/manual/', '', path).replace('/', '-')
            text = chapter_text(row, open(full).read(), full)
        if name in used:
            raise SystemExit('two entries make the file ' + name)
        used.add(name)
        open(os.path.join(CHAP, name), 'w').write(text)
        fm.append('%s:%s' % (uuid, name))
    open(os.path.join(BUILD, 'filemap.txt'), 'w').write('\n'.join(fm) + '\n')
    shutil.rmtree(os.path.join(BUILD, 'figures'), ignore_errors=True)
    shutil.copytree(os.path.join(STREAM, 'figures'), os.path.join(BUILD, 'figures'))
    print('book: %d chapter files, numbers agree with the text' % len(fm))


if __name__ == '__main__':
    main()
