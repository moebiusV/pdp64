#!/usr/bin/env python3
"""Tag-check micro-benchmarks for the pdp64 (docs/encoding-work/bench/tagcheck/README.md).

Each workload is generated as assembly for several schemes and run on build/sim64 with the timing presets; the cost of one iteration is the
difference of two runs (N=1000 and N=2000) so that start-up and exit drop out.  usage: bench.py [BUILD_DIR] > results.txt
"""
import sys, os, subprocess, tempfile, re

B = sys.argv[1] if len(sys.argv) > 1 else 'build'
AS, LD, SIM = B + '/as64', B + '/ld64', B + '/sim64'
TMP = tempfile.mkdtemp(prefix='tagchk')
MODELS = {'scalar': 'name=scalar,iw=1,W=8,N=32',
          'dual':   'name=dual,iw=2,W=16,N=48,dq=6,btb=64',
          'wide':   'name=wide,iw=1,W=64,N=128,tkb=0,btb=4096'}

def hdr():
    return '\t.text\n\t.globl _start\n_start:\n'

END = '\tmovq #0,r0\n\ttrap #0\nbad:\tmovq #1,r0\n\ttrap #0\n'

def cell_list(n, mis=0):
    """n cons cells of 16 bytes; car = fixnum 1 (value 8), cdr = tagged pointer to the next (tag 1) or nil (2)."""
    s = '\t.data\n\t.align 8\nc:\n'
    for i in range(n):
        s += '\t.quad 8\n\t.quad ' + ('c+%d' % (16 * (i + 1) + 1) if i + 1 < n else '2') + '\n'
    return s

def ptr_array(n, tag, objsz, mis=0, words=None):
    s = '\t.data\n\t.align 8\narr:\n'
    for i in range(n):
        s += '\t.quad objs+%d\n' % (objsz * i + (tag ^ mis))
    s += 'objs:\n'
    for i in range(n):
        s += words(i)
    return s

# ---------------------------------------------------------------- workloads: name -> {scheme: (text, data-func, instrs of the check)}
def w_list(scheme, n, mis):
    # r1 = x (tagged cons), r2 = sum.  car at -1(x), cdr at 7(x), nil = 2.
    t = hdr() + '\tlea c+1, r1\n\tmovq #0,r2\n'
    if scheme == 'a-old':
        t += 'top:\tmovq -1(r1),r3\n\tadd r3,r2\n\tmovq 7(r1),r1\n\tcbne r1,#2,top\n'
    elif scheme == 'b-naive':       # a check before every access
        t += 'top:\tbntag r1,#1,bad\n\tmovq -1(r1),r3\n\tadd r3,r2\n\tbntag r1,#1,bad\n\tmovq 7(r1),r1\n\tcbne r1,#2,top\n'
    elif scheme == 'b-once':        # one check for the cell (car and cdr)
        t += 'top:\tbntag r1,#1,bad\n\tmovq -1(r1),r3\n\tadd r3,r2\n\tmovq 7(r1),r1\n\tcbne r1,#2,top\n'
    elif scheme == 'c-merged':      # the check replaces the nil test: loop while the cdr is a cons
        t += '\tbntag r1,#1,bad\ntop:\tmovq -1(r1),r3\n\tadd r3,r2\n\tmovq 7(r1),r1\n\tbtag r1,#1,top\n\tcbne r1,#2,bad\n'
    return t + END + cell_list(n)

def w_car(scheme, n, mis):
    # an array of n tagged pointers to cells; sum of the cars (one access per pointer)
    t = hdr() + '\tlea arr, r4\n\tmovq #%d,r5\n\tmovq #0,r2\n' % n
    if scheme == 'a-old':
        t += 'top:\tmovq (r4)+,r1\n\tmovq -1(r1),r3\n\tadd r3,r2\n\tsob r5,top\n'
    elif scheme == 'b-check':
        t += 'top:\tmovq (r4)+,r1\n\tbntag r1,#1,bad\n\tmovq -1(r1),r3\n\tadd r3,r2\n\tsob r5,top\n'
    elif scheme == 'b-check-fail':
        t += 'top:\tmovq (r4)+,r1\n\tbntag r1,#1,fix\nacc:\tmovq -1(r1),r3\n\tadd r3,r2\n\tsob r5,top\n\tbr done\nfix:\tbis #1,r1\n\tbr acc\ndone:\n'
    elif scheme == 'c-trapcheck':   # the check as a trap word: mask, then trap if not equal
        t += 'top:\tmovq (r4)+,r1\n\tmovq r1,r0\n\tand #7,r0\n\tctne r0,#1\n\tmovq -1(r1),r3\n\tadd r3,r2\n\tsob r5,top\n'
    elif scheme == 'd-ctag-proxy':  # a two-byte trap-if-zero word standing in for a one-parcel CTAG Rn,#tag (one issue slot, no branch)
        t += 'top:\tmovq (r4)+,r1\n\tcteq r1\n\tmovq -1(r1),r3\n\tadd r3,r2\n\tsob r5,top\n'
    return t + END + ptr_array(n, 1, 16, mis if scheme == 'b-check-fail' else 0, lambda i: '\t.quad 8\n\t.quad 2\n')

def w_add(scheme, n, mis):
    # dynamic-language add of two tagged small integers (tag 0): both operands checked; result added to sum
    t = hdr() + '\tlea arr, r4\n\tmovq #%d,r5\n\tmovq #0,r2\n' % n
    if scheme == 'ab-same':                 # the alignment fault cannot test an arithmetic operand: old and explicit are identical
        t += 'top:\tmovq (r4)+,r1\n\tmovq (r4)+,r3\n\tmovq r1,r0\n\tbis r3,r0\n\tbntag r0,#0,bad\n\taddv r3,r1\n\tadd r1,r2\n\tsob r5,top\n'
    elif scheme == 'b-const':               # a + constant: one operand checked
        t += '\tmovq #8,r6\ntop:\tmovq (r4)+,r1\n\tbntag r1,#0,bad\n\taddv r6,r1\n\tadd r1,r2\n\tsob r5,top\n'
    elif scheme == 'c-test':                # the same with a bit test and an ordinary branch
        t += 'top:\tmovq (r4)+,r1\n\tmovq (r4)+,r3\n\tmovq r1,r0\n\tbis r3,r0\n\tbit #7,r0\n\tbne bad\n\taddv r3,r1\n\tadd r1,r2\n\tsob r5,top\n'
    s = '\t.data\n\t.align 8\narr:\n' + ''.join('\t.quad 16\n\t.quad 24\n' for i in range(n)) + '\t.quad 0\n'
    return t + END + s

def w_call(scheme, n, mis):
    # method dispatch on a tagged object (tag 3): header (class) at -3, class slot 8 holds the method; the method bumps a field at 5
    t = hdr() + '\tlea arr, r4\n\tmovq #%d,r5\n' % n
    chk = {'a-old': '', 'b-check': '\tbntag r1,#3,bad\n'}[scheme if scheme != 'b-check-fail' else 'b-check']
    t += 'top:\tmovq (r4)+,r1\n' + chk + '\tmovq -3(r1),r3\n\tcalli 8(r3)\n\tsob r5,top\n' + END
    t += 'meth:\tmovq 5(r1),r0\n\tadd #1,r0\n\tmovq r0,5(r1)\n\tret\n'
    s = '\t.data\n\t.align 8\ncls:\t.quad 0\n\t.quad meth\narr:\n' + ''.join('\t.quad objs+%d\n' % (16 * i + 3) for i in range(n)) + 'objs:\n'
    s += ''.join('\t.quad cls\n\t.quad 0\n' for i in range(n))
    return t + s

def w_vec(scheme, n, mis):
    # vector (tag 5), length (a fixnum, bytes = 8 * length) at -5, elements from +3; index tagged (i*8): vector-ref with the bounds check, in a loop
    t = hdr() + '\tlea vec+5, r1\n\tmovq #0,r3\n\tmovq #0,r2\n\tmovq #%d,r5\n' % (8 * n)
    body = '\tmovq -5(r1),r4\n\tctcc r3,r4\n\tmovq 3(r1)(r3*1),r0\n\tadd r0,r2\n\tadd #8,r3\n\tcmp r3,r5\n\tbne top\n'
    if scheme == 'a-old':
        t += 'top:\n' + body
    elif scheme == 'b-check':       # tag checked on every vector-ref
        t += 'top:\tbntag r1,#5,bad\n' + body
    elif scheme == 'd-ctag-proxy':
        t += 'top:\tcteq r1\n' + body
    elif scheme == 'c-hoisted':     # the tag checked once, before the loop
        t += '\tbntag r1,#5,bad\ntop:\n' + body
    s = '\t.data\n\t.align 8\nvec:\t.quad %d\n' % (8 * n) + ''.join('\t.quad 8\n' for i in range(n))
    return t + END + s

WL = {  # name: (generator, schemes, accesses per iteration)
    'list':  (w_list, ['a-old', 'b-naive', 'b-once', 'c-merged'], 2),
    'car':   (w_car, ['a-old', 'b-check', 'c-trapcheck', 'd-ctag-proxy'], 1),
    'add':   (w_add, ['ab-same', 'b-const', 'c-test'], 0),
    'call':  (w_call, ['a-old', 'b-check'], 3),
    'vec':   (w_vec, ['a-old', 'b-check', 'c-hoisted', 'd-ctag-proxy'], 1),
}

def run(name, scheme, n, mis=0):
    gen = WL[name][0] if name in WL else {'car-fail': w_car}[name]
    src = gen(scheme, n, mis)
    f = '%s/%s_%s_%d' % (TMP, name, scheme, n)
    open(f + '.s', 'w').write(src)
    for cmd in ([AS, '-o', f + '.o', f + '.s'], [LD, '-o', f + '.x', f + '.o']):
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode: sys.exit('%s: %s\n%s' % (cmd[0], r.stderr, src[:300]))
    prof = f + '.prof'
    cmd = [SIM, '-P', prof] + ['--timing=' + s for s in MODELS.values()] + [f + '.x']
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode: sys.exit('sim64 exit %d: %s %s' % (r.returncode, name + scheme, r.stderr[-500:]))
    out = {}
    for l in r.stderr.splitlines():
        if l.startswith('tm '):
            d = dict(kv.split('=', 1) for kv in l[3:].split())
            out[d['name']] = (int(d['insns']), int(d['bytes']), int(d['cycles']))
    return out

def per_iter(name, scheme, mis=0):
    a, b = run(name, scheme, 1000, mis), run(name, scheme, 2000, mis)
    return {m: tuple((b[m][i] - a[m][i]) / 1000.0 for i in range(3)) for m in a}

if __name__ == '__main__':
    print('# per iteration, from the difference of N=2000 and N=1000: instructions, bytes, cycles (ideal memory, bimodal predictor)')
    print('%-6s %-14s %-7s %6s %6s %7s' % ('load', 'scheme', 'model', 'insns', 'bytes', 'cycles'))
    for name, (g, schemes, acc) in WL.items():
        for s in schemes:
            r = per_iter(name, s)
            for m in MODELS:
                print('%-6s %-14s %-7s %6.2f %6.2f %7.2f' % (name, s, m, *r[m]))
    # the failing path: every check fails and goes to a two-instruction stub that repairs the pointer
    r = per_iter('car', 'b-check-fail', 1)
    for m in MODELS:
        print('%-6s %-14s %-7s %6.2f %6.2f %7.2f' % ('car', 'b-fail-always', m, *r[m]))
