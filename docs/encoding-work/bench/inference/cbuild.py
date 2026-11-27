#!/usr/bin/env python3
"""cbuild.py KERNEL [scalar|lv]: build cdrv.c with -DK_KERNEL through clang -> opt (pdp64, O2, LoopVectorize when lv) -> llc, run at strips 16 32 64; prints model 1 and the number of vec blocks / the vector instructions in the assembly.
Same pipeline as bench/vecwave1/run.py (TOOLS=dir with as64 ld64 sim64 opt llc)."""
import os, re, sys, subprocess, tempfile
import lib
HERE = os.path.dirname(os.path.abspath(__file__))
LLVM = '/home/matthew/claude/llvm-build-22/bin'
CF = ['-O2', '-m64', '-fno-builtin-memset', '-fno-builtin-memcpy', '-fno-stack-protector', '-mlong-double-64', '-mno-sse', '-mno-mmx', '-ffp-contract=fast', '-ffast-math', '-w', '-S', '-emit-llvm']
def strip_ll(txt):
    txt = re.sub(r'^target (datalayout|triple).*\n', '', txt, flags=re.M)
    return re.sub(r'"(target-cpu|target-features|tune-cpu)"="[^"]*"', '', txt)
def build(kernel, variant, d, keep=None):
    vec = variant == 'lv'
    ll0 = d + '/k.ll0'
    lib.sh(['clang'] + CF + (['-fno-vectorize', '-fno-slp-vectorize', '-fno-unroll-loops'] if not vec else ['-Xclang', '-disable-llvm-passes', '-fno-unroll-loops']) + ['-DK_' + kernel, '-o', ll0, HERE + '/cdrv.c'])
    open(d + '/k.ll1', 'w').write(strip_ll(open(ll0).read()))
    if vec: lib.sh([LLVM + '/opt', '-mtriple=pdp64-unknown-elf', '-passes=default<O2>', '-S', d + '/k.ll1', '-o', d + '/k.ll'])
    else: os.replace(d + '/k.ll1', d + '/k.ll')
    lib.sh([LLVM + '/llc', '-mtriple=pdp64-unknown-elf', '-O2', d + '/k.ll', '-o', d + '/k.s'])
    open(d + '/crt.s', 'w').write('\t.text\n\t.globl\t_start\n_start:\tcall\tmain\n\ttrap\t#0\n\t.globl\twrite\nwrite:\ttrap\t#1\n\tret\n\t.globl\tmemcpy\nmemcpy:\tmov\tr0, r3\n\tmcpy\tr0, r1, r2\n\tmov\tr3, r0\n\tret\n\t.globl\tmemset\nmemset:\tmov\tr0, r3\n\tmset\tr0, r1, r2\n\tmov\tr3, r0\n\tret\n')
    for f in ('crt', 'k'): lib.sh([lib.T + '/as64', '-o', d + '/%s.o' % f, d + '/%s.s' % f])
    lib.sh([lib.T + '/ld64', '-o', d + '/p.x', d + '/crt.o', d + '/k.o'])
    if keep: open(keep, 'w').write(open(d + '/k.s').read())
    return d + '/p.x', open(d + '/k.s').read()
if __name__ == '__main__':
    kernel = sys.argv[1]; variant = sys.argv[2] if len(sys.argv) > 2 else 'lv'
    with tempfile.TemporaryDirectory() as d, tempfile.TemporaryDirectory() as d0:
        x, asm = build(kernel, variant, d, sys.argv[3] if len(sys.argv) > 3 else None)
        xb, _ = build('none', variant, d0)
        fn = re.search(r'^k_%s:.*?(?=^\S+:\s*$|\Z)' % kernel, asm, flags=re.M | re.S)
        body = fn.group(0) if fn else ''
        nvec = len(re.findall(r'^\s*vec\s', body, flags=re.M)); nv = len(re.findall(r'^\s*v[a-z]+[\w.]*\s', body, flags=re.M)); ninst = len(re.findall(r'^\s+[a-z]', body, flags=re.M))
        for s in (16, 32, 64):
            a = lib.sim(x, s); b = lib.sim(xb, s)
            print('C %-8s %-6s strip %2d  m1 %7d  m2 %7d  (blocks run %s; the function: %d instructions, %d vector words, %d vec blocks)  out %s' % (kernel, variant, s, a['m1'] - b['m1'], a['m2'] - b['m2'], a.get('blocks'), ninst, nv, nvec, a['out'].hex()[:16]))
