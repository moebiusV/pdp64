#!/usr/bin/env python3
"""Build the manual as a book: outline.txt + filemap.txt + the Markdown of docs/streamlined/ -> Typst -> PDF.

This is the `buildabook typst` step of ~/claude/buildabook (github.com/moebiusV/buildabook), reimplemented for this one book because
buildabook needs the HBNF_Config Ada crate, which is not available on this machine. The inputs are in buildabook's formats
(book/outline.txt in the outline language of its LANGUAGE.md; book/template.typ in its template contract), so the real
`buildabook` can build the same book once its crate is available; the numbers are computed from the position in the outline, never written.

    tools/mkbook.py              write book/build/rendered/{*.md,book.typ}
    tools/mkbook.py --pdf        also compile book/build/pdp64-manual.pdf with typst
    tools/mkbook.py --check      only the checks (every file exists, chapter numbers agree with the section numbers in the text)
"""
import os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BOOK = os.path.join(ROOT, 'book')
OUT = os.path.join(BOOK, 'build')
REND = os.path.join(OUT, 'rendered')
GITHUB = 'https://github.com/moebiusV/pdp64/blob/main/'


def roman(n):
    out = ''
    for v, s in ((10, 'X'), (9, 'IX'), (5, 'V'), (4, 'IV'), (1, 'I')):
        while n >= v:
            out += s
            n -= v
    return out


def letter(n):
    return chr(ord('A') + n - 1)


def parse_outline():
    entries = []
    state = {k: {'label': {'c': 'Chapter', 'p': 'Part', 'a': 'Appendix'}.get(k, ''),
                 'number': {'c': 'arabic', 'p': 'roman', 'a': 'letter'}.get(k, 'none'), 'count': 1} for k in 'cpadnuks'}
    for ln, line in enumerate(open(os.path.join(BOOK, 'outline.txt')), 1):
        line = line.rstrip('\n')
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        m = re.match(r'^([cpadnuks]):(id\d{5}(?:\.\d+)?)\s+(.*)$', line)
        if m:
            k, uuid, title = m.groups()
            st = state[k]
            num = ''
            if st['number'] != 'none' and k in 'cpa':
                n = st['count']
                num = {'arabic': str(n), 'roman': roman(n), 'letter': letter(n)}[st['number']]
                st['count'] += 1
            entries.append(dict(kind=k, uuid=uuid, title=title.strip(), label=st['label'], number=num, line=ln))
            continue
        m = re.match(r'^([cpadnuks]):(label|number|count|default|none):(.*)$', line)
        if m:
            k, d, v = m.groups()
            if d == 'label':
                state[k]['label'] = v.split('|')[0]
            elif d == 'number':
                state[k]['number'] = {'arab': 'arabic'}.get(v, v)
            elif d == 'count':
                state[k]['count'] = int(v)
            continue
        raise SystemExit('outline.txt:%d: not an entry or a directive: %r' % (ln, line))
    seen = set()
    for e in entries:
        if e['uuid'] in seen:
            raise SystemExit('duplicate UUID ' + e['uuid'])
        seen.add(e['uuid'])
    return entries


def parse_filemap():
    fm = {}
    for line in open(os.path.join(BOOK, 'filemap.txt')):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        tok, path = line.split(None, 1)
        fm[tok] = path
    return fm


def designation(e):
    if e['kind'] in 'cpa' and e['number']:
        return ('%s %s' % (e['label'], e['number'])).strip()
    return ''


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
        if path.endswith('.md') and os.path.normpath(os.path.join(srcdir, path)).startswith(os.path.join(ROOT, 'docs', 'streamlined')):
            return label
        full = os.path.normpath(os.path.join(srcdir, path))
        rel = os.path.relpath(full, ROOT)
        return '[%s](%s%s)' % (label, GITHUB, rel)
    return re.sub(r'(?<!!)\[([^\]]+)\]\(([^)\s]+)\)', one, text)


def transform(e, src, srcpath):
    lines = src.split('\n')
    # the first heading and any back-link line
    i = next(k for k, l in enumerate(lines) if l.startswith('# '))
    title = lines[i][2:].strip()
    rest = [l for l in lines[i + 1:] if not l.startswith('[← ')]
    body = '\n'.join(rest).strip('\n') + '\n'
    if e['kind'] == 'c':
        m = re.match(r'^(\d+)\.\s+(.*)$', title)
        if not m:
            raise SystemExit('%s: heading %r has no chapter number' % (srcpath, title))
        if m.group(1) != e['number']:
            raise SystemExit('%s: the heading says chapter %s but the outline makes it chapter %s; the section numbers in the text would be wrong' % (srcpath, m.group(1), e['number']))
        title = m.group(2)
    elif e['kind'] == 'a':
        m = re.match(r'^Appendix ([A-Z])\.\s+(.*)$', title)
        if not m:
            raise SystemExit('%s: heading %r has no appendix letter' % (srcpath, title))
        if m.group(1) != e['number']:
            raise SystemExit('%s: the heading says appendix %s but the outline makes it appendix %s' % (srcpath, m.group(1), e['number']))
        title = m.group(2)
    elif e['kind'] == 'n':
        # the index page: keep "How to read it" onward
        k = body.index('## How to read it')
        body = body[k:].replace('## How to read it', '', 1).lstrip('\n')
        title = e['title']
    else:
        title = e['title']
    if e['uuid'] == 'id02001':
        # the dictionary's own index lists its pages with links that mean nothing in a book
        pass
    d = designation(e)
    heading = '%s — %s' % (d, title) if d else title
    body = convert_links(body, srcpath)
    body = body.replace('](../figures/', '](figures/')
    body = re.sub(r'<!--.*?-->\n?', '', body, flags=re.S)
    # headings: the sources use ## for sections and ### for entries; the template renders markdown # as level 2, so they land on levels 3 and 4
    body = body.replace('{{', '{ {')
    return '# %s\n\n%s' % (heading, body)


def build(check_only=False):
    entries = parse_outline()
    fm = parse_filemap()
    os.makedirs(REND, exist_ok=True)
    import shutil
    figsrc = os.path.join(ROOT, 'docs', 'streamlined', 'figures')
    if not check_only:
        shutil.rmtree(os.path.join(REND, 'figures'), ignore_errors=True)
        shutil.copytree(figsrc, os.path.join(REND, 'figures'))
    calls = []
    front = []
    n = 0
    for e in entries:
        token = '%s:%s' % (e['kind'], e['uuid'])
        fname = 'e%03d-%s.md' % (n, e['uuid'])
        n += 1
        if e['kind'] == 'p':
            text = '# %s — %s\n' % (designation(e), e['title'])
            call = '#chapter("%s", token: "%s", part: true)' % (fname, token)
        else:
            path = fm.get(token)
            if not path:
                raise SystemExit('no source file for %s (%s)' % (token, e['title']))
            full = os.path.join(ROOT, path)
            if not os.path.exists(full):
                raise SystemExit('%s: %s does not exist' % (token, path))
            text = transform(e, open(full).read(), full)
            call = '#chapter("%s", token: "%s")' % (fname, token)
        if not check_only:
            open(os.path.join(REND, fname), 'w').write(text)
        (front if e['kind'] == 'n' else calls).append(call)
    if check_only:
        print('book: %d entries, all sources found, chapter and appendix numbers agree with the text' % len(entries))
        return
    tpl = open(os.path.join(BOOK, 'template.typ')).read()
    tpl = tpl.replace('// {{FRONT-MATTER}}', '\n'.join(front))
    open(os.path.join(REND, 'book.typ'), 'w').write(tpl.rstrip('\n') + '\n' + '\n'.join(calls) + '\n')
    print('wrote %s (%d entries)' % (os.path.join(REND, 'book.typ'), len(entries)))


def main():
    build(check_only='--check' in sys.argv)
    if '--pdf' in sys.argv:
        pdf = os.path.join(OUT, 'pdp64-manual.pdf')
        r = subprocess.run(['typst', 'compile', '--root', OUT, os.path.join(REND, 'book.typ'), pdf])
        if r.returncode:
            sys.exit(r.returncode)
        import shutil
        shutil.copyfile(pdf, os.path.join(BOOK, 'pdp64-manual.pdf'))
        print('wrote', pdf, 'and book/pdp64-manual.pdf (tracked in git; rebuild it after every change to the manual)')


if __name__ == '__main__':
    main()
