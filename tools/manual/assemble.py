"""Assembly of the three manuals from one source tree, and the checks of the result.

The hand-written text of the manual is in docs/manual-src/ once.  tools/mkmanual.py writes from it the complete manual of each member of the family
(docs/manual/pdp64-r20/, docs/manual/pdp64-16/, docs/manual/pdp64-32/).  The source syntax (also in docs/manual-src/README.md):

    text outside any block                    in every manual
    <!-- member: 16 32 -->  ...  <!-- /member -->      (each marker on a line of its own) these lines only in the manuals of pdp64/16 and pdp64/32
    <!-- member: !r20 -->  ...  <!-- /member -->        the same, written as "not r20"
    [[16 32: some words]]                     the same, inline (the words end at the first ]] ; no line break inside)
    <!-- members: 16 32 -->                   as the first line of a file: the whole file is in those manuals only
    @@MEMBER@@  @@ID@@  @@PDF@@               pdp64/16, 16, pdp64-16.pdf (the name of the member, its short name, the file name of its book)

Blocks do not nest.  Numbers (chapters, sections 9.2, statements 9.2.3) are literal in the text: the author of a member block writes the numbers that
the manual of that member must have, and verify() checks, for each generated manual, that the numbers are contiguous and that every link and every
reference to a section or a statement has a target.
"""
import os, re

MEMBERS = ('r20', '16', '32')
NAME = {'r20': 'pdp64/r20', '16': 'pdp64/16', '32': 'pdp64/32'}


class SourceError(Exception):
    pass


def selected(spec, member):
    """spec: the words after `member:`, e.g. '16 32' or '!r20'"""
    words = spec.split()
    if not words:
        raise SourceError('empty member list')
    for w in words:
        if w.lstrip('!') not in MEMBERS:
            raise SourceError('unknown member %r (members: %s)' % (w, ' '.join(MEMBERS)))
    neg = [w for w in words if w.startswith('!')]
    if neg and len(neg) != len(words):
        raise SourceError('a member list is either all negated or none: ' + spec)
    if neg:
        return member not in [w[1:] for w in words]
    return member in words


def file_members(text):
    """the members a file is written for (all of them when it has no <!-- members: --> line)"""
    m = re.match(r'<!-- members: ([^>]*?) -->\n', text)
    if not m:
        return list(MEMBERS)
    return [x for x in MEMBERS if selected(m.group(1), x)]


def for_member(text, member, where='source'):
    m = re.match(r'<!-- members: ([^>]*?) -->\n', text)
    if m:
        text = text[m.end():]
    out, skipping, depth, spec = [], False, 0, None
    for n, line in enumerate(text.split('\n'), 1):
        s = line.strip()
        mm = re.match(r'^<!-- member: (.*?) -->$', s)
        if mm:
            if depth:
                raise SourceError('%s:%d: member blocks do not nest' % (where, n))
            depth = 1
            skipping = not selected(mm.group(1), member)
            continue
        if s == '<!-- /member -->':
            if not depth:
                raise SourceError('%s:%d: <!-- /member --> with no block open' % (where, n))
            depth, skipping = 0, False
            continue
        if '<!-- member' in line and not re.match(r'^<!-- members: ', s):
            raise SourceError('%s:%d: a member marker must be on a line of its own' % (where, n))
        if not skipping:
            out.append(line)
    if depth:
        raise SourceError('%s: a <!-- member: --> block is not closed' % where)
    text = '\n'.join(out)

    def inline(mm):
        return mm.group(2) if selected(mm.group(1), member) else ''
    text = re.sub(r'\[\[(!?(?:r20|16|32)(?: !?(?:r20|16|32))*): (.*?)\]\]', inline, text)
    text = text.replace('@@MEMBER@@', NAME[member]).replace('@@ID@@', member).replace('@@PDF@@', 'pdp64-%s.pdf' % member)
    return text


# ---------------------------------------------------------------- the checks
def slug(heading):
    return re.sub(r'[^a-z0-9 -]', '', heading.lower()).replace(' ', '-')


def outline(files):
    """For the chapters: headings and statements.  files: name -> text.  Returns (problems, set of numbers that exist)"""
    problems, exist = [], set()
    for name, text in sorted(files.items()):
        if not name.endswith('.md') or '/' in name:
            continue
        m = re.match(r'(\d+)-', name)
        ap = re.match(r'appendix-([a-f])-', name)
        if not (m or ap):
            continue
        ch = str(int(m.group(1))) if m else ap.group(1).upper()
        secs, stmts = [], {}
        cur = None
        fence = False
        for ln, line in enumerate(text.split('\n'), 1):
            if line.startswith('```'):
                fence = not fence
            if fence:
                continue
            h = re.match(r'^## (%s\.(\d+))\b' % re.escape(ch), line)
            if h:
                secs.append(int(h.group(2)))
                cur = h.group(1)
                exist.add(h.group(1))
                continue
            h3 = re.match(r'^### (%s\.\d+\.\d+)\b' % re.escape(ch), line)
            if h3:
                exist.add(h3.group(1))
            st = re.match(r'^\*\*(%s\.\d+\.\d+)\*\*' % re.escape(ch), line)
            if st:
                exist.add(st.group(1))
                stmts.setdefault('.'.join(st.group(1).split('.')[:2]), []).append((int(st.group(1).split('.')[2]), ln))
        if secs != list(range(1, len(secs) + 1)) and secs:
            problems.append('%s: the sections are numbered %s, not 1 to %d' % (name, secs, len(secs)))
        for sec, lst in stmts.items():
            nums = [n for n, _ in lst]
            if nums != list(range(1, len(nums) + 1)):
                problems.append('%s: the statements of section %s are numbered %s, not 1 to %d' % (name, sec, nums, len(nums)))
    return problems, exist


def verify(files, outdir_files, root_dir):
    """files: the generated manual of one member (relative name -> text, with dictionary/ pages); outdir_files: the set of all relative names that exist
    (figures included); root_dir: the directory of the manual in the repository, for links that leave it.  Returns the problems."""
    problems, exist = outline(files)
    anchors = {}
    for name, text in files.items():
        if name.endswith('.md'):
            a = set()
            fence = False
            for line in text.split('\n'):
                if line.startswith('```'):
                    fence = not fence
                if not fence:
                    h = re.match(r'^#{1,6} (.*)$', line)
                    if h:
                        a.add(slug(h.group(1).strip()))
            a |= set(re.findall(r'<a id="([^"]+)"', text))
            anchors[name] = a
    for name, text in sorted(files.items()):
        if not name.endswith('.md'):
            continue
        body = re.sub(r'(?s)```.*?```', '', text)
        for label, url in re.findall(r'\[([^\]]*)\]\(([^)\s]+)\)', body):
            if re.match(r'^(https?:|mailto:)', url):
                continue
            path, _, frag = url.partition('#')
            if path:
                tgt = os.path.normpath(os.path.join(os.path.dirname(name), path))
                if tgt.startswith('..'):
                    if tgt.endswith('.pdf'):
                        continue                      # the books are built by tools/mkbook.sh
                    if not os.path.exists(os.path.normpath(os.path.join(root_dir, tgt))):
                        problems.append('%s: link to %s does not exist' % (name, url))
                    continue
                if tgt not in outdir_files:
                    problems.append('%s: link to %s: no such file in the manual' % (name, url))
                    continue
            else:
                tgt = name
            if frag and tgt in anchors and frag not in anchors[tgt]:
                problems.append('%s: link %s: no heading with that anchor' % (name, url))
        if re.match(r'(\d+|appendix)-?', os.path.basename(name)) and '/' not in name:
            for ref in re.findall(r'\b[Ss]ections? ((?:[A-F]|\d+)\.\d+(?:\.\d+)?)\b', body):
                if ref not in exist and re.match(r'^(\d+)\.', ref) and int(ref.split('.')[0]) <= 10:
                    problems.append('%s: reference to section %s: no such section or statement' % (name, ref))
                elif ref not in exist and re.match(r'^[A-F]\.', ref):
                    problems.append('%s: reference to section %s: no such section or statement' % (name, ref))
    return problems
