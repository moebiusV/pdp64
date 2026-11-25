#!/usr/bin/env python3
"""latency.py WORKDIR: how long an interrupt waits if a vector block must finish first (today's simulator rule), measured as the vector cycles that sim64 -V (model 1) charges to the whole block,
for the repository's own kernels (the micro-kernel, and the accumulator dot products of ../vector-resume).  A real core takes the interrupt at a strip boundary, which is one strip (a few cycles)
away; that is what the resume design needs.  The times are for a 100 MHz and a 1 GHz clock."""
import subprocess, re, sys, os
B = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', '..', 'build')
VF = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'arch-data', 'vec-forms')
W = sys.argv[1]
def run(src, name):
    p = os.path.join(W, name)
    open(p + '.s', 'w').write(src)
    subprocess.run([B + '/as64', '-o', p + '.o', p + '.s'], check=True); subprocess.run([B + '/ld64', '-o', p + '.x', p + '.o'], check=True)
    r = subprocess.run([B + '/sim64', '-V', p + '.x'], capture_output=True, text=True)
    m = re.search(r'vector (\d+)', r.stderr); return int(m.group(1))
def drv(call, data, setup): return "\t.text\n\t.globl\t_start\n_start:\n" + setup + "\n\tcall\tk\n\thalt\n" + call + "\n\t.data\n\t.align\t64\n" + data
def ukr(K):
    body = open(VF + '/blas/k_sgemm_nt.ukr.s').read().replace('k_ukr:', 'k:')
    return drv(body, "pa:\t.space %d\npb:\t.space %d\npc:\t.space 1024\n" % (32 * K, 16 * K), "\tlea\tpa,r0\n\tlea\tpb,r1\n\tlea\tpc,r2\n\tmovq\t#%d,r3\n\tmovq\t#64,r4" % K)
def fdot(n):
    k = "k:\tlea\t(r0)(r2*4),r3\n\tvec\tr0,r3\n\tvclr.f\tv4,#1\n\tvld.f\tv0,(r0)+\n\tvld.f\tv1,(r1)+\n\tvfma.f\tv4,v0,v1\n\tvfin\n\tvacc.f\tr4,v4\n\tvend\n\tret\n"
    return drv(k, "x:\t.space %d\ny:\t.space %d\n" % (4 * n, 4 * n), "\tlea\tx,r0\n\tlea\ty,r1\n\tmovq\t#%d,r2" % n)
def idot(n):
    k = "k:\tlea\t(r0)(r2),r3\n\tvec\tr0,r3\n\tvclr.l\tv4,#1\n\tvld.b\tv0,(r0)+\n\tvld.b\tv1,(r1)+\n\tvdot.b\tv4,v0,v1\n\tvfin\n\tvacc.l.q\tr4,v4\n\tvend\n\tret\n"
    return drv(k, "x:\t.space %d\ny:\t.space %d\n" % (n, n), "\tlea\tx,r0\n\tlea\ty,r1\n\tmovq\t#%d,r2" % n)
print('block\tvector cycles\tms at 100 MHz\tus at 1 GHz')
for name, src in (('micro-kernel K=64', ukr(64)), ('micro-kernel K=1024', ukr(1024)), ('micro-kernel K=4096', ukr(4096)), ('float dot, 16384', fdot(16384)), ('float dot, 262144', fdot(262144)), ('int8 dot, 1 MiB', idot(1 << 20))):
    c = run(src, name.replace(' ', '_').replace('=', '').replace(',', ''))
    print('%s\t%d\t%.3f\t%.0f' % (name, c, c / 1e5, c / 1e3))
