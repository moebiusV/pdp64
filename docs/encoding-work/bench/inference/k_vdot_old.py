#!/usr/bin/env python3
"""k_vdot_old.py: runs the REMOVED vdot.b (into an accumulator) on the simulator of the commit before its removal (built in a scratch directory: OLD=dir with build/as64 ld64 sim64; the recipe is in ../vecwave1/README.md) and checks the answer.  That simulator has no cycle model, so the cycles are model 1 applied by hand:
a 16-byte accumulator strip is 4 byte-elements wide (the lane of the accumulator is 32 bits), so 1024 strips x (2 loads + vdot + 1 commit) = 4096 + set-up."""
import os, re, subprocess, tempfile, numpy as np
from lib import *
OLD = os.environ.get('OLD', '/tmp/claude-1000/-home-matthew-claude-pdp64/832cbac5-5e29-461e-9610-ca42cce0b602/scratchpad/inf/old3/build')
N = 4096; r = rng(5)
w = r.randint(-127, 128, N).astype(np.int8); x = r.randint(-127, 128, N).astype(np.int8)
K = """kern:
	clr	r4
	lea	(r0)(r2),r3
	vec	r0,r3
	vclr.l	v2,#1
	vld.b	v0,(r0)+
	vld.b	v1,(r1)+
	vdot.b	v2,v0,v1
	vfin
	vacc.l.l r4,v2
	vend
	ret"""
L = frame(['\tlea\tWQ,r0', '\tlea\tXQ,r1', '\tmov\t#%d,r2' % N, '\tcall\tkern', '\tlea\tRES,r5', '\tmov\tr4,(r5)'], [], 'RES', 8) + K.split('\n') + data('WQ', w) + data('XQ', x) + bss('RES', 8)
d = tempfile.mkdtemp(); open(d + '/p.s', 'w').write(re.sub(r'\tmov\t#', r'\tmov\t$', '\n'.join(L) + '\n'))
subprocess.run([OLD + '/as64', '-o', d + '/p.o', d + '/p.s'], check=True); subprocess.run([OLD + '/ld64', '-o', d + '/p.x', d + '/p.o'], check=True)
for s in (16, 32, 64):
    p = subprocess.run([OLD + '/sim64', '-V', '-S', str(s), '-P', d + '/prof', d + '/p.x'], capture_output=True)
    v = int(np.frombuffer(p.stdout[:8], dtype=np.int64)[0]); e = p.stderr.decode()
    import re
    m = re.search(r'vec blocks (\d+) strips (\d+) ops (\d+)', e); m1 = re.search(r'total (\d+)', e.split('model2')[0].split('model strip')[1] if 'model strip' in e else '')
    print('old sim64, vdot.b into an accumulator, strip %d: %s (%d, expect %d); blocks/strips/ops %s; model 1 total %s' % (s, 'PASS' if v == int((w.astype(np.int64) * x).sum()) else 'FAIL', v, (w.astype(np.int64) * x).sum(), m.groups() if m else None, m1.group(1) if m1 else None))
