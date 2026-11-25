#!/usr/bin/env python3
"""convert_to_names.py -- turn the literal numbers of the manual into stable names and tokens (the one-time migration step).

    tokenize_numbers.py SRCDIR OUTDIR OUTLINE SOURCES [--force FILE] [--keep FILE] [--py FILE...]

SRCDIR is docs/manual-src/; OUTDIR receives the converted copies (and names.tsv, report.txt).  The CURRENT numbering is the source of the names:
  * `## 6.2 Title`  ->  `## {{#kernel-modes-and-the-status-word}} Title`        (section: name from the title)
  * `### 6.7.3 T`   ->  `### {{#name}} T`, `**6.2.5** Text`  ->  `**{{#text-first-words}}** Text`    (name from the first words)
  * a citation of a number that exists  ->  `{{r:name}}`;  `chapter 6`  ->  `chapter {{c:id01006|n}}`;  `appendix E` -> `appendix {{c:id03006|n}}`
  * `# 6. The kernel` -> `# {{c:id01006|n}}. The kernel`;  `# Appendix B. X` -> `# Appendix {{c:id03003|n}}. X`
  * `<!-- entries:9.6 -->` -> `<!-- entries:{{r:name}} -->`
Nothing that is not an existing number is converted; a candidate that looks like a citation but names nothing, and a number that exists but has no cue
(possibly a decimal), are written to report.txt for a person to look at.  The proof is bookrefs.resolve(convert(x)) == x, byte for byte (roundtrip.py).
"""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bookrefs as BR

STOP = {'the', 'a', 'an', 'this', 'that', 'these', 'those', 'it', 'its', 'and', 'of', 'in', 'on', 'to', 'is', 'are', 'for', 'as', 'at', 'by', 'with', 'then'}


def words(text, n, cap):
    t = re.sub(r'`([^`]*)`', r'\1', text)
    t = re.sub(r'\[([^\]]*)\]\([^)]*\)', r'\1', t)
    ws = re.findall(r'[a-z0-9]+', t.lower())
    while len(ws) > 1 and ws[0] in STOP:
        ws = ws[1:]
    out = []
    for w in ws[:n]:
        if len('-'.join(out + [w])) > cap:
            break
        out.append(w)
    while len(out) > 1 and out[-1] in STOP:
        out.pop()
    return '-'.join(out) or 'x'


class Namer:
    def __init__(self):
        self.used = set()

    def make(self, base, chapter_key):
        name = base
        if name in self.used:
            name = chapter_key + '-' + base
        k = 2
        while name in self.used:
            name = '%s-%d' % (base, k)
            k += 1
        self.used.add(name)
        return name


NUMRE = r'(?:\d{1,2}|[A-E])\.\d{1,3}(?:\.\d{1,3})?'


def scan(files):
    """files: {fn: text}.  The current numbering: {old number: (name, kind, file, line)}"""
    nm = Namer()
    table = {}
    figures = {}
    for fn, text in files.items():
        key = re.sub(r'^\d+-|^appendix-[a-e]-|\.md$', '', fn)
        fence = False
        hm = re.search(r'(?m)^# (?:Appendix )?([0-9A-Z]+)\.', text)
        label, nfig = (hm.group(1) if hm else None), 0
        for ln, line in enumerate(text.split('\n'), 1):
            if line.startswith('```'):
                fence = not fence
            if fence:
                continue
            fm = re.match(r'^!\[([^\]]*)\]\(figures/', line)
            if fm and label:
                nfig += 1
                num = '%s.%d' % (label, nfig)
                figures[num] = nm.make('fig-' + words(fm.group(1), 5, 36), key)
                table[('fig', num)] = (figures[num], 'figure', fn, ln)
                continue
            m = re.match(r'^(#{2,3}) (%s)\s+(.*)$' % NUMRE, line)
            if m and m.group(2).count('.') == (1 if len(m.group(1)) == 2 else 2):
                base = words(m.group(3), 6, 44)
                kind = 'section' if len(m.group(1)) == 2 else 'item'
            else:
                m = re.match(r'^\*\*(%s)\*\* (.*)$' % NUMRE, line)
                if not (m and m.group(1).count('.') == 2):
                    continue
                m = re.match(r'^(\*\*)(%s)\*\* (.*)$' % NUMRE, line)
                base = words(m.group(3), 5, 40)
                kind = 'item'
            num = m.group(2)
            if num in table:
                raise SystemExit('%s:%d: number %s defined twice' % (fn, ln, num))
            table[num] = (nm.make(base, key), kind, fn, ln)
    return table, figures


DENY = re.compile(r'(?i)\b(freebsd|openbsd|netbsd|linux|bsd|handbook|revision|versions?|v|rev|release|kernel|gcc|llvm|clang|armv?|riscv|rfc|isa|spec|pdf|page|pages|p|pp|ch)\.? ?$')
CHAIN = re.compile(r'\x01(, and |, | and | to |; | or | & )$')


FORCE = set()      # file:line:number that a person read and confirmed as a citation (--force FILE)
KEEP = set()       # file:line:number that a person read and confirmed as NOT a citation of this manual (--keep FILE): a decimal, a version, a section of another document


def convert_line(line, table, outline_by_label, report, where, figures=None, in_py=False, start_strong=False):
    """citations in one line (not a heading or statement definition): returns the new line.  A number is converted only when it names a section or statement
    that exists AND the words before it make it a citation: `section`, `statement`, `see`, `(` or a list that continues a converted citation (strong), or `of`, `in`,
    a table cell of its own (weak, written to the report).  A decimal, a version (`FreeBSD 5.3`), a citation of another document are left."""
    keep = []

    def stash(m):
        keep.append(m.group(0))
        return '\x00%d\x00' % (len(keep) - 1)

    def numlink(m):
        num, url = m.group(1), m.group(2)
        if num in table and url.split('#')[0].endswith(table[num][2]) and '#' in url:
            keep.append('[{{r:%s}}]({{u:%s}})' % (table[num][0], table[num][0]))
            return '\x00%d\x00' % (len(keep) - 1)
        report.append('%s: link [%s](%s) with a number as its label and no matching target: left' % (where, num, url))
        return m.group(0)
    line = re.sub(r'\[(%s)\]\(([^)\s]+)\)' % NUMRE, numlink, line)
    work = re.sub(r'`[^`]*`|\]\([^)]*\)|<a id="[^"]*">|\{\{[^}]*\}\}', stash, line)
    out, pos = [], 0
    last_conv_end = -1
    prev_end, prev_ok = -1, True
    for m in re.finditer(r'(?<![\w.$/#:=\x00-])(%s)(?![\w%%]|\.\d)' % NUMRE, work):
        num = m.group(1)
        before = work[max(0, pos if False else m.start() - 30):m.start()]
        after = work[m.end():m.end() + 8]
        out.append(work[pos:m.start()])
        pos = m.end()
        fig = re.search(r'\b[Ff]igures? $', before)
        exist = num in table
        if fig and figures is not None and num in figures:
            out.append('{{r:%s}}' % figures[num])
            last_conv_end = m.end()
            prev_ok = True
            continue
        chain = last_conv_end >= 0 and re.search(r'^(, and |, | and | to |; | or )$', work[last_conv_end:m.start()]) is not None
        sep_chain = prev_end >= 0 and re.search(r'^(, and |, | and | to |; | or )$', work[prev_end:m.start()]) is not None
        was_ok = prev_ok
        prev_end = m.end()
        prev_ok = False
        if sep_chain and not was_ok:
            report.append('%s: left literal (follows a number that is not a citation): %s' % (where, num))
            out.append(num)
            continue
        if '%s:%s' % (where, num) in KEEP:
            report.append('%s: left literal (confirmed by a person: not a citation): %s' % (where, num))
            out.append(num)
            continue
        if not exist:
            if re.search(r'(sections?|statements?) $', before) or chain:
                report.append('%s: NOT A NUMBER OF THE MANUAL (left literal; another document, or a stale citation): %s' % (where, num))
            out.append(num)
            continue
        unit = re.match(r'^ (to|and|or|-) \d+\.\d+ ?(KB|MB|GB|bytes?|ns|ms|cycles?|%|bits?)\b', after + work[m.end()+8:m.end()+24]) is not None or re.match(r'^(%|x\b|×| ?(KB|MB|GB|TB|ns|ms|us|µs|MHz|GHz|bits?|bytes?|megabytes?|megabits?|seconds?|cycles?|times|per cent|percent)\b)', after) is not None
        if unit or re.search(r'[$~×\d.-]$', before) or DENY.search(before):
            report.append('%s: left literal (decimal, version or unit): ...%s[%s]%s' % (where, before[-16:].replace('\x00', '`'), num, after))
            out.append(num)
            continue
        strong = (re.search(r'(?i)(\b(sections?|statements?|see|cf\.?)|§) $', before) is not None or before.endswith('(') or chain
                  or (before.endswith('| ') and re.match(r'^( \||,)', after) is not None))
        weak = (re.search(r'\b(of|in|from|under|by|at|than|as|to|and|with|is|are|says|shows|follows|on|that|what|for|technique|which) $', before) is not None
                or re.search(r'(^|[.:*] )$', before) is not None
                or (re.search(r'[,;] $', before) is not None and re.match(r'^[);:]', after) is not None))
        if in_py and start_strong and re.match(r'^[ubrUBR]*[\'"]{1,3}$', before.replace('\x00', '`')[-4:].lstrip('0123456789`,.;() ') or before[-4:]) and m.start() <= 4:
            strong = True
        if '%s:%s' % (where, num) in FORCE:
            strong = True
        if not (strong or weak):
            report.append('%s: left literal (no cue; look at it): ...%s[%s]%s' % (where, before[-18:].replace('\x00', '`'), num, after))
            out.append(num)
            continue
        if not strong:
            report.append('%s: converted on a weak cue: ...%s[%s]%s' % (where, before[-18:].replace('\x00', '`'), num, after))
        out.append('{{r:%s}}' % table[num][0])
        last_conv_end = m.end()
        prev_ok = True
    out.append(work[pos:])
    work = ''.join(out)

    def chap1(n):
        uu = [u for u, v in outline_by_label.items() if v[0] == 'c' and v[1] == int(n)]
        if not uu:
            report.append('%s: chapter %s is not in the outline' % (where, n))
            return n
        return '{{c:%s|n}}' % uu[0]

    def chap(m):
        if re.search(r'(?i)handbook[^.;]{0,25}$', m.string[max(0, m.start() - 40):m.start()]):
            report.append('%s: chapter of another document left literal: %s' % (where, m.group(0)))
            return m.group(0)
        return m.group(1) + chap1(m.group(2)) + re.sub(r'\d+', lambda x: chap1(x.group(0)), m.group(3))
    work = re.sub(r'(?<![\w`])((?:[Cc]hapters? ))(\d{1,2})((?:(?:, and |, | and | to )\d{1,2}\b(?!\.\d))*)(?![.\d]\d|\.\d|%)', chap, work)

    def app1(x):
        uu = [u for u, v in outline_by_label.items() if v[0] == 'a' and v[2] == x]
        if not uu:
            report.append('%s: appendix %s is not in the outline' % (where, x))
            return x
        return '{{c:%s|n}}' % uu[0]

    def app(m):
        return m.group(1) + app1(m.group(2)) + re.sub(r'[A-E]', lambda x: app1(x.group(0)), m.group(3))
    work = re.sub(r'((?:[Aa]ppendi(?:x|ces) ))([A-E])\b(?!\.\d)((?:(?:, and |, | and | to )[A-E]\b(?!\.\d))*)', app, work)
    return re.sub('\x00(\\d+)\x00', lambda m: keep[int(m.group(1))], work)


def convert_files(files, table, figures, outline, sources, report):
    out = {}
    for fn, text in files.items():
        fence = False
        res = []
        for ln, line in enumerate(text.split('\n'), 1):
            if line.startswith('```'):
                fence = not fence
                res.append(line)
                continue
            if fence:
                res.append(line)
                continue
            where = '%s:%d' % (fn, ln)
            m = re.match(r'^# (\d+)\. (.*)$', line)
            if m:
                uu = [u for u, v in outline.items() if v[0] == 'c' and v[1] == int(m.group(1))]
                res.append('# {{c:%s|n}}. %s' % (uu[0], m.group(2)))
                continue
            m = re.match(r'^# Appendix ([A-E])\. (.*)$', line)
            if m:
                uu = [u for u, v in outline.items() if v[0] == 'a' and v[2] == m.group(1)]
                res.append('# Appendix {{c:%s|n}}. %s' % (uu[0], m.group(2)))
                continue
            m = re.match(r'^(#{2,3}) (%s)\s+(.*)$' % NUMRE, line)
            if m and m.group(2) in table and table[m.group(2)][2:] == (fn, ln):
                res.append('%s {{#%s}} %s' % (m.group(1), table[m.group(2)][0], convert_line(m.group(3), table, outline, report, where, figures)))
                continue
            m = re.match(r'^\*\*(%s)\*\* (.*)$' % NUMRE, line)
            if m and m.group(1) in table and table[m.group(1)][2:] == (fn, ln):
                res.append('**{{#%s}}** %s' % (table[m.group(1)][0], convert_line(m.group(2), table, outline, report, where, figures)))
                continue
            m = re.match(r'^<!-- (/?entries):(%s) -->$' % NUMRE, line)
            if m and m.group(2) in table:
                res.append('<!-- %s:{{r:%s}} -->' % (m.group(1), table[m.group(2)][0]))
                continue
            fm = re.match(r'^!\[([^\]]*)\]\((figures/.*)$', line)
            if fm and ('fig', ) and any(v[2:] == (fn, ln) and v[1] == 'figure' for v in table.values()):
                nm_ = next(v[0] for v in table.values() if v[2:] == (fn, ln) and v[1] == 'figure')
                res.append('![{{#%s}}%s](%s' % (nm_, fm.group(1), fm.group(2)))
                continue
            res.append(convert_line(line, table, outline, report, where, figures))
        out[fn] = '\n'.join(res)
    return out


def convert_py(text, base, table, outline, report, figures):
    """only inside the string literals of a Python file (a number elsewhere is a float or an index); a `cf='6.7 for ...'` string starts with a citation"""
    import tokenize, io
    toks = list(tokenize.generate_tokens(io.StringIO(text).readline))
    lines = text.split('\n')
    edits = []
    depth = 0
    for i, tk in enumerate(toks):
        if tk.type == tokenize.OP and tk.string in '([{':
            depth += 1
        elif tk.type == tokenize.OP and tk.string in ')]}':
            depth -= 1
        if tk.type != tokenize.STRING:
            continue
        prev = toks[i - 1] if i else None
        nx = toks[i + 1] if i + 1 < len(toks) else None
        if depth == 0 and (prev is None or prev.type in (tokenize.NEWLINE, tokenize.INDENT, tokenize.DEDENT, tokenize.NL, tokenize.ENCODING)) and (nx is None or nx.type in (tokenize.NEWLINE, tokenize.NL, tokenize.ENDMARKER)):
            continue                    # a docstring or a lone string: not output of the manual
        prev2 = toks[i - 2] if i > 1 else None
        nxt = toks[i + 1] if i + 1 < len(toks) else None
        cf = prev is not None and prev.string == '=' and prev2 is not None and prev2.string == 'cf'
        fmt = nxt is not None and nxt.string == '.' and i + 2 < len(toks) and toks[i + 2].string == 'format'
        new = '\n'.join(convert_line(l, table, outline, report, '%s:%d' % (base, tk.start[0] + k), figures, in_py=True, start_strong=(cf and k == 0))
                        for k, l in enumerate(tk.string.split('\n')))
        if new != tk.string:
            if fmt:
                report.append('%s:%d: !! a converted string is used with .format(): double the braces by hand' % (base, tk.start[0]))
            edits.append((tk.start, tk.end, new))
    for (sr, sc), (er, ec), new in sorted(edits, reverse=True):
        if sr == er:
            lines[sr - 1] = lines[sr - 1][:sc] + new + lines[sr - 1][ec:]
        else:
            nl = new.split('\n')
            first = lines[sr - 1][:sc] + nl[0]
            last = nl[-1] + lines[er - 1][ec:]
            lines[sr - 1:er] = [first] + nl[1:-1] + [last]
    return '\n'.join(lines)


def main():
    a = [x for x in sys.argv[1:]]
    src, outdir, outline_p, sources_p = a[:4]
    pyfiles = a[a.index('--py') + 1:] if '--py' in a else []
    for opt, dst in (('--force', FORCE), ('--keep', KEEP)):
        if opt in a:
            dst.update(l.strip() for l in open(a[a.index(opt) + 1]) if l.strip() and not l.startswith('#'))
    if '--py' in a:
        a = a[:a.index('--py')]
    outline = BR.read_outline(outline_p)
    files = {}
    for fn in sorted(os.listdir(src)):
        if fn.endswith('.md') and fn != 'README.md':
            files[fn] = open(os.path.join(src, fn)).read()
    table, figures = scan(files)
    report = []
    conv = convert_files(files, table, figures, outline, None, report)
    os.makedirs(outdir, exist_ok=True)
    for fn, t in conv.items():
        open(os.path.join(outdir, fn), 'w').write(t)
    with open(os.path.join(outdir, 'names.tsv'), 'w') as f:
        for num, (name, kind, fn, ln) in table.items():
            f.write('%s\t%s\t%s\t%s\t%d\n' % (num if isinstance(num, str) else num[1], name, kind, fn, ln))
    for p in pyfiles:
        t = open(p).read()
        dst = os.path.join(outdir, 'py', os.path.basename(p))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        open(dst, 'w').write(convert_py(t, os.path.basename(p), table, outline, report, figures))
    open(os.path.join(outdir, 'report.txt'), 'w').write('\n'.join(report) + '\n')
    n_tok = sum(len(re.findall(r'\{\{r:', t)) for t in conv.values())
    print('%d names (%d sections, %d statements/items), %d citation tokens, %d report lines' % (len(table), sum(1 for v in table.values() if v[1] == 'section'), sum(1 for v in table.values() if v[1] == 'item'), n_tok, len(report)))


if __name__ == '__main__':
    main()
