#!/usr/bin/env python3
"""vecscan.py DIR: for every vector block (vec/vec2 ... vend) in the assembly kernels under DIR (the repository's arch-data/vec-forms), count
  changed   = distinct registers the block changes: a base register with (rN)+ or -(rN), the scalar destination of vacc/vred and the like (any operand-0 scalar register of a v* instruction named r<N>)
              (epilogue included, since the resume record covers the whole block);
  accum     = the block has a vclr (hidden accumulators): only those are resumed with a record;
  inplace   = in the main loop (before vfin; the whole body if there is none) a store (vst*, vsts*, vstt*) uses a base register that a load (vld*, vlseg*, vldt*, vfmab, vmla with memory operand) of the main loop also uses
              (the case that the machine would refuse at vec, for a block with accumulators).
Prints one line per block and a summary."""
import re, sys, os, collections
reg = re.compile(r'\b(r\d+)\b')
def blocks(path):
    cur = None; out = []
    for ln in open(path, errors='replace'):
        t = ln.split(';')[0].strip()
        if not t: continue
        m = re.match(r'([A-Za-z_.][\w.]*)\s*(.*)$', t)
        if not m: continue
        mn, ops = m.group(1), m.group(2)
        if mn.endswith(':'): continue
        if mn in ('vec', 'vec2'):
            cur = dict(file=path, lines=[], head=ops); out.append(cur); continue
        if mn == 'vend': cur = None; continue
        if cur is not None: cur['lines'].append((mn, ops))
    return out
def analyse(b):
    changed = set(); accum = False; main = True; loads = set(); stores = set()
    hd = [x.strip() for x in b['head'].split(',')]
    for mn, ops in b['lines']:
        if mn == 'vclr' or mn.startswith('vclr.'): accum = True
        if mn == 'vfin': main = False
        for m in re.finditer(r'\((r\d+)\)\+|-\((r\d+)\)', ops):
            changed.add(m.group(1) or m.group(2))
        parts = [p.strip() for p in re.split(r',(?![^()]*\))', ops)]
        if mn.startswith(('vacc', 'vred', 'vsum', 'vmov2s')) and parts and re.fullmatch(r'r\d+', parts[0]): changed.add(parts[0])
        mem = [p for p in parts if '(' in p]
        bases = set(x for p in mem for x in reg.findall(p))
        if main:
            if mn.startswith(('vst', 'vsts', 'vstt')): stores |= bases
            elif mn.startswith(('vld', 'vlseg', 'vfmab', 'vmla', 'vmul', 'vadd', 'vsub')) and mem: loads |= bases
    return dict(changed=len(changed), accum=accum, inplace=bool(stores & loads), regs=sorted(changed))
rows = []
for d, _, fs in os.walk(sys.argv[1]):
    for f in sorted(fs):
        if f.endswith('.s'):
            for b in blocks(os.path.join(d, f)):
                a = analyse(b); a['name'] = f; rows.append(a)
cnt = collections.Counter(r['changed'] for r in rows)
acc = [r for r in rows if r['accum']]
for r in rows: print('%-34s accum %-5s changed %d inplace %s %s' % (r['name'], r['accum'], r['changed'], r['inplace'], ' '.join(r['regs'])))
print('blocks %d, with accumulators %d' % (len(rows), len(acc)))
print('changed registers, all blocks:', dict(sorted(cnt.items())))
print('changed registers, accumulator blocks:', dict(sorted(collections.Counter(r['changed'] for r in acc).items())))
print('accumulator blocks with more than 4 changed: %d; more than 2: %d' % (sum(r['changed'] > 4 for r in acc), sum(r['changed'] > 2 for r in acc)))
print('all blocks with more than 4 changed: %d' % sum(r['changed'] > 4 for r in rows))
print('accumulator blocks the in-place rule would refuse: %d' % sum(r['inplace'] for r in acc))
print('non-accumulator blocks that store through a register they load through (allowed): %d' % sum(r['inplace'] and not r['accum'] for r in rows))
