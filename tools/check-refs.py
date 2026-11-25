#!/usr/bin/env python3
"""check-refs.py -- check that the references in the documents point at something that exists.

The manual's own checks (tools/mkmanual.py --check, tools/check-manual-src.py, tools/mkbook.sh --check) verify that a reference written "section N.M" has a
target and that the heading numbers agree with the outline.  They do not look at the other ways the documents refer to things, and nothing can tell whether a
reference points at the RIGHT thing.  This tool checks the other ways, and can print what each reference points at so that a person can see a wrong one.

References checked (each must have a target):
  errata N, errata N and M, errata N to M     the numbered entries of docs/errata.md
  R123 (three digits)                          the rows of docs/decision-register.md
  J.6.13, B.2.11, A.1.2 ...                    the open items, proposals and improvements of the appendices (docs/manual-src)
  section N.M[.K], manual N.M[.K]              a section or a numbered statement of the manual
  (N.M[.K])                                    the manual's own bare citation, in docs/manual-src only
  `docs/...`, `tools/...`, `spec/...` ...      a path in backquotes (a file or directory of the repository)

    tools/check-refs.py                 check the manual sources strictly (exit 1 on any bad reference) and the other documents with a warning count
    tools/check-refs.py --all           every document is strict
    tools/check-refs.py --show FILE     print every reference of FILE with the first words of its target (to read for a WRONG one)
    tools/check-refs.py --list          print every bad reference
The historical records (docs/errata.md, docs/decision-register.md, docs/decisions-and-status.md) are read for their targets and for bad references.
"""
import glob, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def rd(p):
    with open(os.path.join(ROOT, p), errors='replace') as f:
        return f.read()


def targets():
    T = {'errata': {}, 'R': {}, 'man': {}, 'path': set()}
    for line in rd('docs/errata.md').split('\n'):
        m = re.match(r'^(\d+)\. (.*)$', line)
        if m:
            T['errata'][int(m.group(1))] = m.group(2)
    for line in rd('docs/decision-register.md').split('\n'):
        m = re.match(r'^- R(\d+) \| [^|]*\| [^|]*\| (.*)$', line)
        if m:
            T['R'][int(m.group(1))] = m.group(2)
    files = sorted(glob.glob(os.path.join(ROOT, 'docs/manual-src/*.md')) + glob.glob(os.path.join(ROOT, 'docs/manual-src/appendix-parts/*.md')))
    for p in files:
        for line in open(p, errors='replace'):
            for m in re.finditer(r'\*\*((?:[A-J]\.)?\d+(?:\.\d+)*|[A-J]\.[A-J0-9]+(?:\.\d+)*)\*\*', line):
                T['man'].setdefault(m.group(1), line.strip()[:140])
            m = re.match(r'^#{2,4} ((?:[A-J]\.)?\d+(?:\.\d+)*|J\.[A-D]\.\d+)\b\s*(.*)$', line)
            if m:
                T['man'].setdefault(m.group(1), m.group(2)[:140])
    return T


def numlist(s):
    out = []
    for part in re.split(r'\s*(?:,|and|&)\s*', s.strip()):
        m = re.match(r'^(\d{1,3})\s*(?:to|-|–)\s*(\d{1,3})$', part.strip())
        if m:
            a, b = int(m.group(1)), int(m.group(2))
            out += [a, b]
        elif re.match(r'^\d{1,3}$', part.strip()):
            out.append(int(part))
    return out


def refs_in(text, manual_src):
    """yield (kind, key, line number, text of the reference)"""
    for ln, line in enumerate(text.split('\n'), 1):
        for m in re.finditer(r'\b[Ee]rrata(?: entries| entry| items?)? ((?:\d+(?:\s*(?:to|-|–)\s*\d+)?(?:\s*(?:,|and|&)\s*)?)+)', line):
            for n in numlist(m.group(1)):
                yield ('errata', n, ln, m.group(0))
        for m in re.finditer(r'(?<![A-Za-z0-9_.])R(\d{3})\b', line):
            yield ('R', int(m.group(1)), ln, m.group(0))
        for m in re.finditer(r'(?<![A-Za-z0-9_])(J\.(?:\d+|[A-D])\.\d+|B\.\d+\.\d+(?:\.\d+)?|A\.\d+\.\d+)\b', line):
            yield ('man', m.group(1), ln, m.group(0))
        for m in re.finditer(r'\b(?:[Ss]ections?|[Mm]anual) (\d{1,2}\.\d{1,2}(?:\.\d{1,2})?)\b', line):
            if int(m.group(1).split('.')[0]) <= 10:
                yield ('man', m.group(1), ln, m.group(0))
        if manual_src:
            for m in re.finditer(r'\((\d{1,2}\.\d{1,2}(?:\.\d{1,2})?)\)', line):
                if int(m.group(1).split('.')[0]) <= 10:
                    yield ('man', m.group(1), ln, m.group(0))
        for m in re.finditer(r'`((?:docs|tools|spec|tests|common|sim64|as64|ld64|book)/[A-Za-z0-9_./\-]*[A-Za-z0-9_])`', line):
            if '*' in m.group(1) or '<' in m.group(1):
                continue
            if re.search(r'QEMU|qemu|Linux|OpenBSD|kernel tree|upstream', line):
                continue          # a path inside another project's tree
            yield ('path', m.group(1), ln, m.group(0))


def bad(kind, key, T):
    if kind == 'errata':
        return key not in T['errata']
    if kind == 'R':
        return key not in T['R']
    if kind == 'man':
        return key not in T['man']
    if kind == 'path':
        return not os.path.exists(os.path.join(ROOT, key))
    return False


def target_text(kind, key, T):
    if kind == 'errata':
        return T['errata'].get(key, '(none)')[:110]
    if kind == 'R':
        return T['R'].get(key, '(none)')[:110]
    if kind == 'man':
        return T['man'].get(key, '(none)')[:110]
    return 'exists' if os.path.exists(os.path.join(ROOT, key)) else '(none)'


def main(argv):
    T = targets()
    allstrict = '--all' in argv
    if '--show' in argv:
        p = argv[argv.index('--show') + 1]
        text = rd(p)
        for kind, key, ln, s in refs_in(text, p.startswith('docs/manual-src')):
            print('%s:%d: %-22s -> %s' % (p, ln, s.strip(), target_text(kind, key, T)))
        return 0
    strict_files = sorted(glob.glob(os.path.join(ROOT, 'docs/manual-src/*.md')) + glob.glob(os.path.join(ROOT, 'docs/manual-src/appendix-parts/*.md')))
    other = sorted(glob.glob(os.path.join(ROOT, 'docs/*.md')) + glob.glob(os.path.join(ROOT, 'docs/encoding-work/*.md')) + glob.glob(os.path.join(ROOT, '*.md')))
    nbad_strict, nbad_other, nref = [], [], 0
    for group, sink, ms in ((strict_files, nbad_strict, True), (other, nbad_other, False)):
        for fp in group:
            rel = os.path.relpath(fp, ROOT)
            for kind, key, ln, s in refs_in(open(fp, errors='replace').read(), ms):
                nref += 1
                if bad(kind, key, T):
                    sink.append('%s:%d: %s: no such %s' % (rel, ln, s.strip(), 'file' if kind == 'path' else 'target'))
    if '--list' in argv or nbad_strict or allstrict:
        for l in nbad_strict + (nbad_other if ('--list' in argv or allstrict) else []):
            print('check-refs: ' + l)
    print('check-refs: %d references read; %d bad in the manual sources, %d bad in the other documents%s' % (
        nref, len(nbad_strict), len(nbad_other), '' if allstrict else ' (warning only; --list shows them, --all makes them fail)'))
    return 1 if (nbad_strict or (allstrict and nbad_other)) else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
