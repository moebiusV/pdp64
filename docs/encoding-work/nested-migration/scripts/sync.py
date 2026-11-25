#!/usr/bin/env python3
"""sync.py -- keep the outline rows of the numbered names in step with the chapter sources, so that an author edits only the chapter.

    sync.py [--check] OUTDIR            (OUTDIR holds outline.txt, src/*.md, sources.txt: "uuid file" per chapter)

The rows between  "# >>> names FILE"  and  "# <<< names FILE"  in outline.txt are GENERATED from the source FILE: they are, in the order of the text,
a section (## heading: s1, its title the heading), a statement or numbered subsection (s2, its title the name), and then, after "s:count:1", a figure
(image line of the chapter: s1, its title the image path).  What an author writes in a chapter:

    ## {{s:@|p|=kernel-modes}} Modes and the status word        a new section   (@ = allocate an id for this name)
    **{{s:@|p|=psw-has-three-modes}}** There are three ...      a new statement
    section {{s:@|p|=kernel-modes}}                              a citation by name (@ = look the id up)
    section {{s:id10254|p|=kernel-modes}}                        what the file holds after sync (the name is a comment for the reader: |=name)

sync.py rewrites the "@" ids in place, regenerates the blocks, and (--check) fails when a file or the outline differs from what it would write, when a name is
defined twice or an id carries two names, when a citation's =name is not the name of its id.  buildabook alone does the numbering.
"""
import os, re, sys
check = '--check' in sys.argv
O = [a for a in sys.argv[1:] if not a.startswith('--')][0]
outline_path = os.path.join(O, 'outline.txt')
src_dir = os.path.join(O, 'src')
sources = {}                                   # file -> uuid of its chapter entry
for line in open(os.path.join(O, 'sources.txt')):
    if line.strip() and not line.startswith('#'):
        u, f = line.split()
        sources[f] = u
TOK = re.compile(r'\{\{s:(id\d{5}|@)((?:\|[a-z]+)*)\|=([a-z0-9][a-z0-9-]*)\}\}')
HEAD = re.compile(r'^(#{2,3}) (\{\{s:[^}]*\}\})(.*)$')
STAT = re.compile(r'^\*\*(\{\{s:[^}]*\}\})\*\*')
IMG = re.compile(r'^!\[[^\]]*\]\((figures/[^)?]*)')
problems = []
texts = {f: open(os.path.join(src_dir, f), encoding='utf-8').read() for f in sorted(os.listdir(src_dir)) if f.endswith('.md')}
outline = open(outline_path, encoding='utf-8').read()
used = [int(x) for x in re.findall(r'id(\d{5})', outline)] + [int(x) for t in texts.values() for x in re.findall(r'id(\d{5})', t)]
nxt = max(used) + 1
name_id, id_name = {}, {}
for f, t in texts.items():                      # names that already have an id
    for m in TOK.finditer(t):
        if m.group(1) != '@':
            if id_name.setdefault(m.group(1), m.group(3)) != m.group(3):
                problems.append('%s: the id %s carries two names (%s, %s)' % (f, m.group(1), id_name[m.group(1)], m.group(3)))
            name_id.setdefault(m.group(3), m.group(1))
# a definition with "@" gets a new id, the citation "@" looks it up
def_at = set()
for f, t in texts.items():
    fence = False
    for line in t.split('\n'):
        if line.startswith('```'): fence = not fence
        if fence: continue
        m = HEAD.match(line) or STAT.match(line)
        if m:
            for k in TOK.finditer(m.group(2) if m.re is HEAD else m.group(1)):
                if k.group(1) == '@' and k.group(3) not in name_id:
                    name_id[k.group(3)] = 'id%05d' % nxt; id_name['id%05d' % nxt] = k.group(3); nxt += 1
def fill(m):
    if m.group(1) != '@': return m.group(0)
    if m.group(3) not in name_id:
        problems.append('no definition of the name %s to cite' % m.group(3)); return m.group(0)
    return '{{s:%s%s|=%s}}' % (name_id[m.group(3)], m.group(2), m.group(3))
new_texts = {f: TOK.sub(fill, t) for f, t in texts.items()}
# the rows of each file, from the text
def rows_of(f, t):
    rows, figs, seen = [], [], set()
    fence = False
    for line in t.split('\n'):
        if line.startswith('```'): fence = not fence
        if fence: continue
        m = HEAD.match(line)
        if m:
            k = TOK.search(m.group(2))
            if not k: problems.append('%s: a heading token that is not {{s:id|=name}}: %s' % (f, line[:60])); continue
            title = m.group(3).strip()
            if m.group(1) == '##': rows.append('s1:%s  %s' % (k.group(1), title))
            else: rows.append('s2:%s  %s' % (k.group(1), k.group(3)))
        else:
            m = STAT.match(line)
            if m:
                k = TOK.search(m.group(1)); rows.append('s2:%s  %s' % (k.group(1), k.group(3)))
            else:
                m = IMG.match(line)
                if m:
                    if m.group(1) in seen: problems.append('%s: the image %s twice' % (f, m.group(1)))
                    seen.add(m.group(1)); figs.append(m.group(1))
    return rows, figs
fig_id = {}             # (file, image path) -> id: the id of a figure lives in the outline only
for b in re.finditer(r'^# >>> names (\S+)$(.*?)^# <<< names', outline, re.M | re.S):
    for m in re.finditer(r'^s1:(id\d{5})  (figures/\S+)$', b.group(2), re.M):
        fig_id[(b.group(1), m.group(2))] = m.group(1)
blocks = {}
for f, t in new_texts.items():
    if f not in sources: continue
    rows, figs = rows_of(f, t)
    if not rows and not figs: continue
    L = ['# >>> names %s' % f, 's:root:chapter'] + rows
    if figs:
        L.append('s:count:1')
        for p in figs:
            if (f, p) not in fig_id:
                fig_id[(f, p)] = 'id%05d' % nxt; nxt += 1
            L.append('s1:%s  %s' % (fig_id[(f, p)], p))
    L += ['s:root:section', '# <<< names %s' % f]
    blocks[f] = L
# splice into the outline: replace existing blocks, or put a new one after the chapter's entry
lines = outline.split('\n')
out, i = [], 0
done = set()
while i < len(lines):
    m = re.match(r'^# >>> names (\S+)$', lines[i])
    if m:
        while not lines[i].startswith('# <<< names'): i += 1
        i += 1
        if m.group(1) in blocks: out += blocks[m.group(1)]; done.add(m.group(1))
        continue
    out.append(lines[i]); i += 1
    m = re.match(r'^[cna]:(id\d{5})\b', lines[i - 1])
    if m:
        for f, u in sources.items():
            if u == m.group(1) and f in blocks and f not in done and ('# >>> names %s' % f) not in outline:
                out += blocks[f]; done.add(f)
new_outline = '\n'.join(out)
changed = [f for f in texts if texts[f] != new_texts[f]]
if problems:
    print('\n'.join('sync: ' + p for p in problems)); sys.exit(1)
if check:
    if changed or new_outline != outline:
        print('sync: out of date (%d files with "@" ids; outline %s)' % (len(changed), 'differs' if new_outline != outline else 'ok')); sys.exit(1)
    print('sync: outline and sources agree'); sys.exit(0)
for f in changed: open(os.path.join(src_dir, f), 'w', encoding='utf-8').write(new_texts[f])
open(outline_path, 'w', encoding='utf-8').write(new_outline)
print('sync: %d files rewritten, %d blocks, outline %d lines' % (len(changed), len(blocks), new_outline.count('\n')))
