"""Assembly of the manual of the pdp64 from its source tree, and the checks of the result.

The hand-written text of the manual is in docs/manual-src/ (the chapters and appendices A to E).  The design notes (decisions pending, the evolution of the design,
proposed, deferred, open items) are outside the manual: their sources are in docs/design/src/ (with the fragments of proposed, deferred and open items in appendix-parts/)
and tools/mkmanual.py writes them to docs/design/.  tools/mkmanual.py writes from the sources the manual (docs/manual/), adding the generated parts (the instruction entries, the dictionary, the figures).  There is
one manual, so the source has no conditional text: resolve() only refuses the markers of the old three-manual source if one comes back.

Numbers (chapters, sections 9.2, statements 9.2.3) are not written in the sources: they are computed from the order of the text and the outline (tools/manual/bookrefs.py)
and every citation is a token resolved while tools/mkmanual.py assembles the manual.  verify() checks, for the generated manual, that the numbers are contiguous (a check
of the resolver) and that every link and every reference to a section or a statement has a target.  The number of a chapter or an appendix is the outline's (book/outline.txt),
passed as `labels` (file name -> number or letter); without `labels` the file name decides, which only the tests use.
"""
import os, re


class SourceError(Exception):
    pass


def resolve(text, where='source'):
    """the text of a source file as it goes into the manual; a leftover marker of the old per-CPU source is an error"""
    m = re.search(r'<!-- /?members?\b|\[\[!?(?:r20|16|32)\b|@@(?:MEMBER|ID|PDF)@@', text)
    if m:
        raise SourceError('%s: %r is a marker of the old three-manual source; the text is for the one manual' % (where, m.group(0)))
    return text


# ---------------------------------------------------------------- the checks
def slug(heading):
    return re.sub(r'[^a-z0-9 -]', '', heading.lower()).replace(' ', '-')


PARTS_LETTERS = ('H', 'I', 'J')       # the design notes assembled from fragments (docs/design/src/appendix-parts/)
DESIGN = {'decisions-pending.md': 'B', 'evolution.md': 'G', 'proposed.md': 'H', 'deferred.md': 'I', 'open-items.md': 'J'}   # the generated design notes (docs/design/) and the letters of their numbers


def parts_outline(name, text, ch, exist):
    """Appendix H (proposed), I (deferred), J (open items): a section for each chapter that has a fragment (`## H.3 Chapter 3: ...`, or `## J.D ...` for appendix D), so the section
    numbers are not contiguous; a statement or section that moved out of the body keeps its old number (`**2.3.3** (moved from chapter 2)`, `### 2.3 ...`), which counts as defined
    here; the open items of J are `### J.3.2 ...`, numbered 1 to n within the chapter."""
    problems, items, fence = [], {}, False
    for line in text.split('\n'):
        if line.startswith('```'):
            fence = not fence
        if fence:
            continue
        h = re.match(r'^## (%s\.(?:\d+|[A-G]))\b' % ch, line)
        if h:
            exist.add(h.group(1))
            continue
        h = re.match(r'^### (%s\.(\d+|[A-G])\.(\d+))\b' % ch, line)
        if h:
            exist.add(h.group(1))
            items.setdefault(h.group(2), []).append(int(h.group(3)))
            continue
        h = re.match(r'^#{2,6} (\d+(?:\.\d+){1,3})\b', line) or re.match(r'^\*\*(\d+(?:\.\d+){2,3})\*\*', line)
        if h:
            exist.add(h.group(1))
    for sec, nums in items.items():
        if nums != list(range(1, len(nums) + 1)):
            problems.append('%s: the items of %s.%s are numbered %s, not 1 to %d' % (name, ch, sec, nums, len(nums)))
    return problems


def outline(files, labels=None):
    """For the chapters: headings and statements.  files: name -> text.  labels: file name -> chapter number or appendix letter, from the outline.  Returns (problems, set of numbers that exist)"""
    problems, exist = [], set()
    for name, text in sorted(files.items()):
        if not name.endswith('.md') or '/' in name:
            continue
        m = re.match(r'(\d+)-', name)
        ap = re.match(r'appendix-([a-e])-', name)
        if not (m or ap or name in DESIGN):
            continue
        ch = labels[name] if labels and labels.get(name) else str(int(m.group(1))) if m else ap.group(1).upper() if ap else DESIGN[name]
        if name in DESIGN and ch in PARTS_LETTERS:
            problems += parts_outline(name, text, ch, exist)
            continue
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


def verify(files, outdir_files, root_dir, design=False, foreign=None, labels=None):
    """files: the generated manual (relative name -> text, with dictionary/ pages); outdir_files: the set of all relative names that exist
    (figures included); root_dir: the directory of the manual in the repository, for links that leave it.  Returns the problems.
    design: files are the generated design notes (docs/design/), whose numbers are those of DESIGN's letters; a reference to a chapter or to an appendix of the manual
    is not checked there (the manual's numbers move without the notes), but a link into the manual must have its target.
    foreign: {path relative to root_dir: set of anchors} of the files that the links leave to (the manual, for the design notes)."""
    problems, exist = outline(files, labels)
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
                    elif frag and foreign and tgt in foreign and frag not in foreign[tgt]:
                        problems.append('%s: link %s: no heading with that anchor' % (name, url))
                    continue
                if tgt not in outdir_files:
                    problems.append('%s: link to %s: no such file in the manual' % (name, url))
                    continue
            else:
                tgt = name
            if frag and tgt in anchors and frag not in anchors[tgt]:
                problems.append('%s: link %s: no heading with that anchor' % (name, url))
        if (design or re.match(r'(\d+|appendix)-?', os.path.basename(name))) and '/' not in name:
            mine = 'BGHIJ' if design else 'A-E'
            for ref in re.findall(r'\b[Ss]ections? ((?:[A-J]|\d+)\.(?:\d+|[A-G])(?:\.\d+)?)\b', body):
                if ref in exist:
                    continue
                if not design and re.match(r'^(\d+)\.', ref) and int(ref.split('.')[0]) <= 10:
                    problems.append('%s: reference to section %s: no such section or statement' % (name, ref))
                elif re.match(r'^[%s]\.' % mine, ref):
                    problems.append('%s: reference to section %s: no such section or statement' % (name, ref))
    return problems


# ---------------------------------------------------------------- the design notes of fragments
PARTS = {'H': ('proposed', 'Nothing is proposed.'), 'I': ('deferred', 'Nothing is deferred.'), 'J': ('open', 'There are no open items.')}
# The fragments of an appendix are named by the letter that appendix had when the notes were written, and the notes cite it by that letter (J.D.2 is the open item of the ABI);
# the file of each, to find its title and its letter in the manual now.
OLD_APPENDIX = {'a': 'improvements', 'b': 'decisions-pending', 'c': 'glossary', 'd': 'abi', 'e': 'assembler', 'f': 'evidence', 'g': 'evolution'}
OLD_LETTER = {v: k for k, v in OLD_APPENDIX.items()}


def fragment_key(fn):
    """02-proposed.md -> ('02', 'proposed'); d-open.md -> ('d', 'open'); None for any other name"""
    m = re.match(r'^(\d\d|[a-g])-(proposed|deferred|open)\.md$', fn)
    return (m.group(1), m.group(2)) if m else None


def assemble_parts(texts, fragments, manual=None, labels=None):
    """texts: the sources of the design notes (file name -> text), changed in place: the region `<!-- parts:KIND -->` ... `<!-- /parts:KIND -->` of
    appendix-h-proposed.md, appendix-i-deferred.md and appendix-j-open.md is filled with a heading `## H.N Chapter N: Title` for each chapter whose fragment is not empty, in chapter order,
    then the appendices (`## J.D Appendix D: Title`, with `(appendix C of the manual)` where the manual now letters it otherwise).  manual: the sources of the manual
    (file name -> text), for the titles of the chapters and appendices; labels: file name -> chapter number or appendix letter from the outline (a fragment `02-proposed.md`
    is of the chapter that the outline numbers 2).  fragments: file name -> raw text.  Returns the problems."""
    problems = []
    titles = {}
    allsrc = dict(manual or {})
    allsrc.update(texts)
    for fn, t in allsrc.items():
        m = re.match(r'(\d\d)-', fn)
        if m:
            n = int(labels[fn]) if labels and labels.get(fn) else int(m.group(1))
            h = re.search(r'(?m)^# \d+\. (.*)$', t)
            titles['%02d' % n] = (str(n), 'Chapter %d' % n, h.group(1) if h else fn)
        a = re.match(r'appendix-[a-g]-(.*)\.md$', fn)
        if a and a.group(1) in OLD_LETTER:
            h = re.search(r'(?m)^# (?:Appendix ([A-G])\. )?(.*)$', t)
            old = OLD_LETTER[a.group(1)].upper()
            now = h.group(1) if h else None
            label = 'Appendix ' + old
            title = h.group(2) if h else fn
            if now and now != old:
                title += ' (appendix %s of the manual)' % now
            titles[old.lower()] = (old, label, title)
    for fn in sorted(fragments):
        k = fragment_key(fn)
        if not k:
            problems.append('appendix-parts/%s: not a fragment name (NN-proposed.md, NN-deferred.md, NN-open.md, or a-open.md for an appendix)' % fn)
        elif k[0] not in titles:
            problems.append('appendix-parts/%s: no chapter or appendix %s' % (fn, k[0]))
    for letter, (kind, none) in PARTS.items():
        fname = next((f for f in texts if f.startswith('appendix-%s-' % letter.lower())), None)
        if not fname:
            continue
        body = []
        for key in sorted(titles, key=lambda x: (not x.isdigit(), x)):
            fn = '%s-%s.md' % (key, kind)
            if fn not in fragments:
                continue
            text = resolve(fragments[fn], 'appendix-parts/' + fn)
            if not text.strip():
                continue
            num, label, title = titles[key]
            body.append('## %s.%s %s: %s\n\n%s\n' % (letter, num, label, title, text.strip('\n')))
        region = '\n'.join(body) if body else none + '\n'
        o, c = '<!-- parts:%s -->' % kind, '<!-- /parts:%s -->' % kind
        t = texts[fname]
        if o not in t or c not in t:
            problems.append('%s: the markers %s and %s are missing' % (fname, o, c))
            continue
        a, b = t.index(o), t.index(c)
        texts[fname] = t[:a] + o + '\n' + region + c + t[b + len(c):]
    return problems
