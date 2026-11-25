#!/usr/bin/env python3
"""Synthetic traces for hole 1: a guest that churns its stage-2 tables (the worse case for the directory).

usage: synth.py OUT.trace --pages W --regions R --touches T --edits E --entries N [--sw-flush] [--seed S]

The guest touches T pages per entry, chosen at random among W pages spread over R regions of 2 MiB (so over R stage-1 leaf-level table pages and R stage-2 leaf-level
table pages); a walk is the full nested walk of three levels in each stage (15 reads: stage-1 root, middle and leaf entries, each read through a three-read
stage-2 walk, and a final three-read stage-2 walk of the data page).  Between two entries the hypervisor stores E words into stage-2 leaf-level table pages
(a random region each) and, with --sw-flush, then executes TLBIA as a correct software hypervisor would.
Layout (page numbers): stage-1 root 0x100, stage-1 middle 0x101, stage-1 leaves 0x110+r; stage-2 root 0x200, middle 0x201, leaf for the guest's page-table region 0x202,
stage-2 leaves for data regions 0x300+r.
"""
import random, argparse
ap = argparse.ArgumentParser(); ap.add_argument('out'); ap.add_argument('--pages', type=int, default=48); ap.add_argument('--regions', type=int, default=8)
ap.add_argument('--touches', type=int, default=20); ap.add_argument('--edits', type=int, default=1); ap.add_argument('--entries', type=int, default=500)
ap.add_argument('--sw-flush', action='store_true'); ap.add_argument('--edit-every', type=int, default=1, help='the hypervisor edits stage 2 before every K-th entry (0: never)'); ap.add_argument('--seed', type=int, default=1)
a = ap.parse_args()
rnd = random.Random(a.seed)
pages = [(rnd.randrange(a.regions), rnd.randrange(512)) for _ in range(a.pages)]     # (region, page in region)
g = 1 << 48
o = open(a.out, 'w')
def w(*x): o.write(' '.join(str(i) for i in x) + '\n')
def s2reads(idx_page, word):   # three stage-2 reads for a guest-physical page: root, middle, leaf  (leaf page chosen by the caller through word)
    pass
w('H', 1, 0)
for n in range(a.entries):
    edit = a.edit_every and n % a.edit_every == 0
    for _ in range(a.edits if edit else 0):
        r = rnd.randrange(a.regions)
        w('S', '%x' % ((0x300 + r) * 4096 + 8 * rnd.randrange(512)), 8, 1)
    if a.sw_flush and edit: w('F', 1, 0, '%x' % g)
    w('H', 0, '%x' % g)
    for _ in range(a.touches):
        r, p = rnd.choice(pages)
        vpn = (r << 9) | p
        rd = []
        for lvl, pg in ((2, 0x100), (1, 0x101), (0, 0x110 + r)):
            # the stage-2 walk of the page-table page's guest-physical address (all stage-1 tables lie in one region), then the entry itself
            rd += [(2, 0x200 * 4096 + 8 * (lvl)), (2, 0x201 * 4096 + 8 * (lvl)), (2, 0x202 * 4096 + 8 * (pg & 0x1ff))]
            rd += [(1, pg * 4096 + 8 * ((vpn >> (9 * lvl)) & 0x1ff))]
        rd += [(2, 0x200 * 4096 + 8 * (r >> 9)), (2, 0x201 * 4096 + 8 * (r & 0x1ff)), (2, (0x300 + r) * 4096 + 8 * p)]
        w('T', 1, 0, 7, '%x' % vpn, 0, 0, 7, len(rd), *['%d:%x' % x for x in rd])
    w('H', 1, '%x' % g)
