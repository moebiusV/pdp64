#!/usr/bin/env python3
"""bookrefs.py -- the computed numbers of the manual: chapters and appendices from book/outline.txt, sections and numbered statements from the order of the
text, and every citation a token.  (Prototype of tools/manual/bookrefs.py.)

Syntax in the source Markdown (docs/manual-src/, tools/manual/*.py strings, tools/mkmanual.py strings):

    # {{c:id01006|n}}. The kernel               the heading of a chapter  (buildabook's own token: the number only)
    # Appendix {{a:id03004|n}}. The ABI         the heading of an appendix
    ## {{#kernel-psw}} Modes and the status word    a section:       renders  6.2
    **{{#kernel-psw-guard}}** The user-memory guard ...   a statement: renders  **6.2.5**   (the Nth numbered item of the section)
    ### {{#vm-walk-steps}} The walk              a numbered subsection: an item of the section, like a statement
    section {{r:kernel-psw}}   (see {{r:kernel-psw-guard}})   a citation: renders the number  6.2   6.2.5
    chapter {{c:id01006|n}}    appendix {{a:id03004|n}}        a citation of a chapter or appendix: the number only (6, C), computed from the outline
    ({{u:kernel-psw}})         the link target of a section (file#anchor), for [text]({{u:...}})
    {{n}}. item                the next number of a typed list at the start of a line (the contents list of 00-index.md)

Names are [a-z0-9][a-z0-9-]*, unique in the book.  A name is never a number; moving a section or a statement changes its number and every citation follows.
"""
import csv, os, re

NAME = r'[a-z0-9][a-z0-9-]*'
TOKEN = re.compile(r'\{\{(#(%s)|r:(%s)|u:(%s)|([ca]):(id\d{5})(\|n)?)\}\}' % (NAME, NAME, NAME))


class RefError(Exception):
    pass


# ---------------------------------------------------------------- the outline: chapter and appendix numbers (cross-checked against buildabook's number_map.csv)
def roman(n):
    out = ''
    for v, s in ((1000, 'M'), (900, 'CM'), (500, 'D'), (400, 'CD'), (100, 'C'), (90, 'XC'), (50, 'L'), (40, 'XL'), (10, 'X'), (9, 'IX'), (5, 'V'), (4, 'IV'), (1, 'I')):
        while n >= v:
            out += s
            n -= v
    return out


def letters(n):
    s = ''
    while n > 0:
        n -= 1
        s = chr(65 + n % 26) + s
        n //= 26
    return s


def fmt(style, n):
    return {'arabic': str(n), 'arab': str(n), 'roman': roman(n), 'roman-lower': roman(n).lower(), 'letter': letters(n), 'none': ''}[style]


def read_outline(path):
    """{uuid: (kind, n, number text, title)} for the numbered kinds, by the rules of buildabook's outline language (label/number/count/default directives; the
    kinds c p a, whose defaults are arabic, roman and letter).  buildabook's own number_map.csv is the authority; tools/mkbook.sh --check compares the two."""
    default = {'c': 'arabic', 'p': 'roman', 'a': 'letter'}
    style = dict(default)
    nxt = {}
    cnt = {'c': 0, 'p': 0, 'a': 0}
    out = {}
    for line in open(path):
        line = line.rstrip('\n')
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        m = re.match(r'^([a-z]):(id\d{5}(?:\.\d+)?)\s*(.*)$', line)
        if m:
            k, uuid, title = m.groups()
            if k in cnt:
                n = nxt.pop(k) if k in nxt else cnt[k] + 1
                cnt[k] = n
                out[uuid] = (k, n, fmt(style[k], n), title.strip())
            else:
                out[uuid] = (k, None, '', title.strip())
            continue
        m = re.match(r'^([a-z]):(label|number|count|default|none):(.*)$', line)
        if not m:
            raise RefError('outline: cannot read %r' % line)
        k, d, v = m.groups()
        v = v.strip()
        if k not in cnt:
            continue
        if d == 'number':
            style[k] = v
        elif d == 'count':
            nxt[k] = int(v)
        elif d == 'default' and v == 'number':
            style[k] = default[k]
        elif d == 'default' and v == 'count':
            nxt[k] = 1
        elif d == 'none' and v == 'number':
            style[k] = 'none'
    return out


def read_sources(path):
    """sources.txt: {file name relative to docs/manual/: uuid}"""
    m = {}
    for line in open(path):
        line = line.strip()
        if line and not line.startswith('#'):
            tok, p = line.split(None, 1)
            m[p[len('docs/manual/'):]] = tok.split(':', 1)[1]
    return m


# ---------------------------------------------------------------- the numbering of one book
class Book:
    def __init__(self, outline_path, sources_path):
        self.outline = read_outline(outline_path)
        self.file_uuid = read_sources(sources_path)
        self.defs = {}              # name -> dict(kind, num, file, line)

    def chapter_label(self, fn):
        u = self.file_uuid.get(fn)
        if u and self.outline.get(u, ('',))[0] in ('c', 'a'):
            return self.outline[u][2]
        return None

    def number(self, files):
        """files: {name: text} in book order (a chapter file's text may contain generated parts).  Computes the number of every `{{#name}}` and checks the names."""
        self.defs = {}
        self.lines = {}
        for fn, text in files.items():
            label = self.chapter_label(fn)
            sec = item = nfig = 0
            fence = False
            for ln, line in enumerate(text.split('\n'), 1):
                if line.startswith('```'):
                    fence = not fence
                if fence:
                    continue
                m = re.match(r'^!\[\{\{#(%s)\}\}' % NAME, line)
                if m:
                    if label is None:
                        raise RefError('%s:%d: a figure name in a file that is not a numbered chapter' % (fn, ln))
                    nfig += 1
                    if m.group(1) in self.defs:
                        raise RefError('%s:%d: the name %s is defined twice' % (fn, ln, m.group(1)))
                    self.defs[m.group(1)] = dict(kind='figure', num='%s.%d' % (label, nfig), file=fn, line=ln, heading=line)
                    continue
                m = re.match(r'^(#{2,3}) \{\{#(%s)\}\}( |$)' % NAME, line)
                kind = None
                if m:
                    kind, name = ('section' if len(m.group(1)) == 2 else 'item'), m.group(2)
                else:
                    m = re.match(r'^\*\*\{\{#(%s)\}\}\*\*( |$)' % NAME, line)
                    if m:
                        kind, name = 'item', m.group(1)
                if kind is None:
                    if '{{#' in re.sub(r'`[^`]*`', '', line):
                        raise RefError('%s:%d: a {{#name}} must be at the start of a heading (## or ###) or of a statement (**{{#name}}** text)' % (fn, ln))
                    continue
                if label is None:
                    raise RefError('%s:%d: {{#%s}} in a file that is not a numbered chapter or appendix of the outline' % (fn, ln, name))
                if name in self.defs:
                    raise RefError('%s:%d: the name %s is defined twice (also %s:%d)' % (fn, ln, name, self.defs[name]['file'], self.defs[name]['line']))
                if kind == 'section':
                    sec += 1
                    item = 0
                    num = '%s.%d' % (label, sec)
                else:
                    if sec == 0:
                        raise RefError('%s:%d: the statement %s comes before the first numbered section' % (fn, ln, name))
                    item += 1
                    num = '%s.%d.%d' % (label, sec, item)
                self.defs[name] = dict(kind=kind, num=num, file=fn, line=ln, heading=line)
        return self.defs

    # ------------------------------------------------------------ resolution
    def anchor(self, name):
        d = self.defs[name]
        h = re.sub(r'^#+ ', '', d['heading'])
        h = TOKEN.sub(lambda m: d['num'] if m.group(2) else '', h).strip()
        h = '%s %s' % (d['num'], h) if not h.startswith(d['num']) else h
        return '%s#%s' % (d['file'], re.sub(r'[^a-z0-9 -]', '', h.lower()).replace(' ', '-'))

    def resolve(self, text, where='text'):
        """replace every token of `text` by its number (the definitions `{{#name}}` too); an unknown name is an error"""
        errs = []

        def one(m):
            if m.group(2):
                if m.group(2) not in self.defs:
                    return bad(m, m.group(2))
                return '' if self.defs[m.group(2)]['kind'] == 'figure' else self.defs[m.group(2)]['num']
            if m.group(3):
                return self.defs[m.group(3)]['num'] if m.group(3) in self.defs else bad(m, m.group(3))
            if m.group(4):
                return self.anchor(m.group(4)) if m.group(4) in self.defs else bad(m, m.group(4))
            kind, uuid = m.group(5), m.group(6)
            row = self.outline.get(uuid)
            if not row or row[0] != kind:
                return bad(m, uuid)
            return row[2]

        def bad(m, what):
            errs.append('%s: %s: no such name or outline entry' % (where, m.group(0)))
            return m.group(0)
        out = TOKEN.sub(one, ordinals(text, where))
        if errs:
            raise RefError('\n'.join(errs))
        return out

    def resolve_all(self, files):
        self.number(files)
        return {fn: self.resolve(t, fn) for fn, t in files.items()}

    def table(self):
        return ['%s\t%s\t%s\t%s' % (n, d['num'], d['file'], d['kind']) for n, d in sorted(self.defs.items(), key=lambda kv: kv[1]['num'])]


def ordinals(text, where='text'):
    """`{{n}}. item` at the start of a line is the next ordinal of a list that the reader sees as 1. 2. 3. (the contents list of 00-index.md): the count starts again after a
    line that does not begin with the token; `{{n}}` anywhere else is an error"""
    out, k = [], 0
    for ln, line in enumerate(text.split('\n'), 1):
        if line.startswith('{{n}}. '):
            k += 1
            line = '%d. %s' % (k, line[len('{{n}}. '):])
        else:
            k = 0
        if '{{n}}' in line:
            raise RefError('%s:%d: {{n}} is only for the start of a list item ({{n}}. text)' % (where, ln))
        out.append(line)
    return '\n'.join(out)


def leftover(text):
    """a `{{` that is a token of this syntax and was not resolved"""
    return [m.group(0) for m in TOKEN.finditer(text)]


def check_against_buildabook(outline, number_map_csv):
    """the outline reader here and buildabook's number map must agree on every chapter, part and appendix"""
    probs = []
    seen = 0
    for row in csv.DictReader(open(number_map_csv)):
        u = row['uuid']
        if row['kind'] in ('chapter', 'appendix', 'part'):
            seen += 1
            mine = outline.get(u)
            if not mine:
                probs.append('%s: buildabook numbers it, the reader does not' % u)
                continue
            theirs = row['rendered'].split()[-1]
            if mine[2] != theirs:
                probs.append('%s: the outline reader says %s, buildabook says %s (%s)' % (u, mine[2], theirs, row['rendered']))
    if seen != sum(1 for v in outline.values() if v[0] in ('c', 'a', 'p')):
        probs.append('different numbers of numbered entries')
    return probs


if __name__ == '__main__':
    # python3 tools/manual/bookrefs.py OUTLINE NUMBER_MAP_CSV : the outline reader here and buildabook's number map must agree on every chapter, part and appendix
    import sys
    if len(sys.argv) != 3:
        raise SystemExit('usage: bookrefs.py book/outline.txt book/build/number_map.csv')
    probs = check_against_buildabook(read_outline(sys.argv[1]), sys.argv[2])
    for p in probs:
        print('bookrefs: ' + p)
    if probs:
        raise SystemExit(1)
    print('bookrefs: the chapter, part and appendix numbers of tools/manual/bookrefs.py agree with buildabook')
