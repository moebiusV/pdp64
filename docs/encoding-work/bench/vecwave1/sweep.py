#!/usr/bin/env python3
"""sweep.py: runs every kernel/variant of the study on the current sim64 (cycle models 1 and 2) and writes results/current.tsv.
TOOLS=dir with as64 ld64 sim64 llc opt.   The removed words are run by removed/run_old.sh (OLD=old tools) and modelled by removed/model.py."""
import os, sys, json, itertools
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run
H = os.path.dirname(os.path.abspath(__file__))
rows = []
def go(k, v, label, strips=(16, 32, 64), ports=(16,), defs=''):
    os.environ['DEFS'] = defs
    for s in strips:
        for p in ports:
            d = run.measure(k, v if v in ('scalar', 'lv') else os.path.join(H, v), s, p)
            d.update(kernel=k, variant=label, strip=s, port=p, defs=defs); rows.append(d)
            print(k, label, s, p, d.get('m1'), d.get('m2'), d.get('pinsn'), d['out'][:8], flush=True)
for k in ('k_sgemm', 'k_q8dot', 'k_q8matvec', 'k_conv1d', 'k_conv3x3', 'k_spmv', 'k_lut256'):
    go(k, 'scalar', 'scalar', strips=(32,))
    go(k, 'lv', 'lv')
go('k_ukr_pack', 'hand/k_ukr.acc.s', 'pack', strips=(32,))
go('k_ukr', 'hand/k_ukr.acc.s', 'ukr+pack')
go('k_q8dot', 'hand/k_q8dot.acc.s', 'vdot-acc')
go('k_q8dot', 'hand/k_q8dot.vdacc.s', 'vdacc')
go('k_conv1d', 'hand/k_conv1d.fir.s', 'vfir')
go('k_lut256', 'hand/k_lut256.vtbl.s', 'vtbl-nibbles')
for nnz in (4, 16, 64):
    go('k_spmv', 'scalar', 'scalar', strips=(32,), defs='-DNNZ_ROW=%d' % nnz)
os.makedirs(os.path.join(H, 'results'), exist_ok=True)
json.dump(rows, open(os.path.join(H, 'results', 'current.json'), 'w'), indent=1)
