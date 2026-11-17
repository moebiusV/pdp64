#!/usr/bin/env python3
"""publish.py: put each project's status document into its repository as decisions-and-status.md and link it from the README.

pdp64 -> /home/david/claude/pdp64/docs/decisions-and-status.md      (link in README 'What to read')
imp72 -> /home/david/claude/status-check/imp72/docs/decisions-and-status.md   (link in README 'Documentation')
hbnf  -> /home/david/claude/status-check/hbnf/decisions-and-status.md         (link in README 'All the documents')
Local filesystem paths in the evidence lines become repository-relative ones (pcc:..., ada-on-alpine:..., v7unix-toolchain:...).
"""
import os, re, sys
D = '/home/david/claude/pdp64/docs/decision-log/'
SUB = [('/home/david/claude/status-check/pcc/', 'pcc:'), ('/home/david/claude/status-check/ada-on-alpine/', 'ada-on-alpine:'),
       ('/home/david/claude/status-check/mustache-ada/', 'mustache-ada:'), ('/home/david/claude/status-check/hbnf-silentpc-untracked/', 'uncommitted (other machine): '),
       ('/home/david/claude/status-check/hbnf/', ''), ('/home/david/claude/status-check/imp72/', ''), ('/home/david/claude/pdp64/', ''),
       ('/home/david/claude/pcc-enc/', 'pcc-enc:'), ('/home/david/claude/facetlang/pdp11/v7unix-toolchain/', 'v7unix-toolchain:'),
       ('/home/david/claude/facetlang/pdp11/', 'facetlang/pdp11/'), ('/home/david/claude/silentpc-archive/imp72-repo/', ''),
       ('/home/david/claude/pcc-pr/', 'pcc-pr:'), ('/home/david/claude/', '')]
LINK = {
    'pdp64': ('/home/david/claude/pdp64', 'docs/decisions-and-status.md', 'README.md',
              "6. **The record of decisions.**",
              "7. **Decisions and status.** [`decisions-and-status.md`](docs/decisions-and-status.md) lists each design and implementation choice with its rationale and precedents, and says whether it is done, left to do, rejected or left in the air against the current docs and code.\n", 'after'),
    'imp72': ('/home/david/claude/status-check/imp72', 'docs/decisions-and-status.md', 'README.md',
              "- [docs/ROADMAP.md](docs/ROADMAP.md)",
              "- [docs/decisions-and-status.md](docs/decisions-and-status.md): each design and implementation choice with its rationale and precedents, and whether it is done, left to do, rejected or left in the air\n", 'after'),
    'hbnf': ('/home/david/claude/status-check/hbnf', 'decisions-and-status.md', 'README.md',
             "- [`RFCPLAN.md`](RFCPLAN.md)",
             "- [`decisions-and-status.md`](decisions-and-status.md): each design and implementation choice with its rationale and precedents, and whether it is done, left to do, rejected or left in the air.\n", 'after'),
}
for proj, (repo, rel, readme, anchor, line, where) in LINK.items():
    t = open(D + proj + '-status.md').read()
    for a, b in SUB:
        t = t.replace(a, b)
    t = t.replace('uncommitted (silentpc)', 'uncommitted (other machine)')
    left = re.findall(r'/home/[^\s)"`]+', t)
    if left:
        print('WARNING', proj, 'paths left:', sorted(set(left))[:5])
    open(os.path.join(repo, rel), 'w').write(t)
    regrel = os.path.join(os.path.dirname(rel), 'decision-register.md')
    rt = open(D + 'data/%s/register.md' % proj).read()
    for a, b in SUB:
        rt = rt.replace(a, b)
    open(os.path.join(repo, regrel), 'w').write(rt)
    print(proj, '->', os.path.join(repo, regrel))
    rp = os.path.join(repo, readme)
    r = open(rp).read()
    if 'decision-register.md' not in r and 'decisions-and-status.md' in r:
        lines = r.split('\n')
        for i, l in enumerate(lines):
            if 'decisions-and-status.md' in l:
                lines[i] = l.rstrip() + ' The author\'s messages it cites are rows [R<n>] of the [decision register](%s).' % regrel
                break
        open(rp, 'w').write('\n'.join(lines))
        r = '\n'.join(lines)
    if 'decisions-and-status.md' not in r:
        i = r.index(anchor)
        j = r.index('\n', i) + 1
        # an anchor line may continue on following indented lines (hbnf WIRE.md style): keep to one line here
        r = r[:j] + line + r[j:]
        open(rp, 'w').write(r)
    print(proj, '->', os.path.join(repo, rel))
