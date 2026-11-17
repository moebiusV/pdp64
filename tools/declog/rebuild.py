#!/usr/bin/env python3
"""rebuild.py PROJECT: status.py, then the PDF (mkstatusbook.py) and HTML (pandoc) of docs/decision-log/PROJECT-status.*"""
import os, subprocess, sys
p = sys.argv[1]
R = '/home/david/claude/pdp64/'
T = {'pdp64': ('The pdp64: decisions and status', "Private working document. The architecture is the pdp64; one CPU since 2026-11-10."),
     'imp72': ('IMP72: decisions and status', ''), 'hbnf': ('HBNF: decisions and status', '')}
NOTE = {'pdp64': "pdp64/32 is the decided pdp64 (author, 2026-11-10); r20 and pdp64/16 are previous iterations, gone as CPUs with manuals and removed as code (tags pre-single-cpu and pre-code-removal keep them). Checked against the working tree of this repository at commit 7c1fe03 and the working tree (2026-11-10), the pcc clone (master 41e5c36, 2026-11-07; branch single-pdp64 2dbf4f7, pushed and not merged) and the toolchain repository.",
        'imp72': "Checked against the repository at commit a7bff02 (2026-11-07), which is newer than the author's checkout on his other machine (clean at eab123c, 2026-11-05, nothing uncommitted), and the packaging repositories.",
        'hbnf': ''}
d = R + 'docs/decision-log/'
args = ['python3', R + 'tools/declog/status.py', p, T[p][0], d + 'data/%s/ledger' % p, d + p + '-status.md'] + ([NOTE[p]] if NOTE[p] else [])
subprocess.run(args, check=True)
subprocess.run(['python3', R + 'tools/declog/mkstatusbook.py', d + p + '-status.md', d + 'build-%s-status' % p, T[p][0],
                'What is done, left to do, rejected and left in the air, with rationale and precedents', p + '-status'], check=True)
subprocess.run(['cp', d + 'build-%s-status/%s-status.pdf' % (p, p), d + p + '-status.pdf'], check=True)
subprocess.run(['pandoc', '-f', 'gfm', '-s', '--metadata', 'title=' + T[p][0], '-o', d + p + '-status.html', d + p + '-status.md'], check=True)
