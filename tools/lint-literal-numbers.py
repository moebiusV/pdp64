#!/usr/bin/env python3
"""lint-literal-numbers.py -- the check that replaces "the numbers agree with the text".

The numbers of the manual are computed (tools/manual/bookrefs.py): a section is `## {{#name}} Title`, a statement is `**{{#name}}** text`, a citation is `{{r:name}}`.
A literal number in the sources that is the number of an existing section, statement or figure and stands where a citation stands (after `section`, `statement`,
`Figure`, `see`, `§` or an opening parenthesis) would go stale at the first renumbering, so it is an error: write `{{r:name}}`.

It reads docs/manual-src/*.md and the text strings of tools/mkmanual.py and tools/manual/*.py.  A decimal, a version (`FreeBSD 5.3`) or a number of another document
(`docs/pdp64-isa.md section 7.2`) is not in the numbering and passes unless it happens to equal a number of the manual after one of those words; such a number is
written once in tools/manual/literal-keep.txt (file TAB number TAB the text just before it).

    tools/lint-literal-numbers.py        exit 1 if there is a literal citation
"""
import glob, io, os, re, sys, tokenize

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'manual'))
import bookrefs as BR

NUM = re.compile(r'(?<![\w.$/#:=-])((?:\d{1,2}|[A-E])\.\d{1,3}(?:\.\d{1,3})?)(?![\w%]|\.\d)')
CUE = re.compile(r'(?i)(sections?|statements?|figures?|see|§|\() ?$')
UNIT = re.compile(r'^ ?(KB|MB|GB|ns|ms|cycles?|bytes?|bits?|megabytes?)\b')


def keep_list():
    keep = []
    p = os.path.join(ROOT, 'tools', 'manual', 'literal-keep.txt')
    if os.path.exists(p):
        for line in open(p):
            if line.strip() and not line.startswith('#'):
                f, n, before = line.rstrip('\n').split('\t')
                keep.append((f, n, before))
    return keep


def main():
    book = BR.Book(os.path.join(ROOT, 'book', 'outline.txt'), os.path.join(ROOT, 'book', 'sources.txt'))
    src = os.path.join(ROOT, 'docs', 'manual-src')
    order = [os.path.basename(f) for f in book.file_uuid]
    files = {fn: open(os.path.join(src, fn)).read() for fn in os.listdir(src) if fn.endswith('.md') and fn != 'README.md'}
    files = {fn: files[fn] for fn in sorted(files, key=lambda f: (order.index(f) if f in order else len(order), f))}
    book.number(files)
    nums = {d['num'] for d in book.defs.values()}
    keep = keep_list()
    bad = []

    def check(fn, ln, w):
        for m in NUM.finditer(w):
            n = m.group(1)
            before = w[max(0, m.start() - 40):m.start()]
            if n in nums and not UNIT.match(w[m.end():m.end() + 10]) and CUE.search(before[-12:]) \
                    and not any(f == fn and k == n and before.endswith(b) for f, k, b in keep):
                bad.append('%s:%d: literal citation %s (write {{r:name}})' % (fn, ln, n))
    for fn, t in files.items():
        fence = False
        for ln, line in enumerate(t.split('\n'), 1):
            if line.startswith('```'):
                fence = not fence
            if fence:
                continue
            check(fn, ln, re.sub(r'`[^`]*`|\]\([^)]*\)|\{\{[^}]*\}\}|<a id="[^"]*">', ' ', line))
    pyfiles = [os.path.join(ROOT, 'tools', 'mkmanual.py')] + sorted(glob.glob(os.path.join(ROOT, 'tools', 'manual', '*.py')))
    for pf in pyfiles:
        if os.path.basename(pf) in ('bookrefs.py', 'tokenize_numbers.py', 'rename_name.py'):
            continue
        prev = None
        for tk in tokenize.generate_tokens(io.StringIO(open(pf).read()).readline):
            doc = prev is None or prev.type in (tokenize.NEWLINE, tokenize.INDENT, tokenize.DEDENT, tokenize.ENCODING)
            prev = tk if tk.type != tokenize.NL else prev
            if tk.type == tokenize.STRING and not doc:
                for k, line in enumerate(tk.string.split('\n')):
                    check(os.path.basename(pf), tk.start[0] + k, re.sub(r'\{\{[^}]*\}\}', ' ', line))
    for b in bad:
        print('lint-literal-numbers: ' + b)
    print('lint-literal-numbers: %d literal citations in %d manual sources and the text of the generators' % (len(bad), len(files)))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
