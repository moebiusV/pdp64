#!/usr/bin/env python3
"""gemmloops.py ISA=OBJECT ... -- the inner loop of OpenBLAS's single-precision GEMM kernels, per instruction set: instructions, fused multiply-adds, loads, and multiply-adds per instruction.

usage: gemmloops.py haswell=hsw.o neon=a64-8x8.o sve=a64-sve.o lasx=la-lasx.o rvv=rv-zvl256.o

The object is the assembled (or, for RISC-V, compiled: its kernel is C with intrinsics) `sgemm_kernel`.  The main loop is the innermost loop (a backward branch) with the
most fused multiply-add instructions: the unrolled loop over the K dimension of the register tile.  The multiply-adds of one iteration are the number of FMA instructions
times their lanes (8 for ymm and LASX, 4 for NEON `.4s`, 8 for RVV at LMUL 1 and VLEN 256; SVE is reported per vector length: lanes = VL)."""
import re, sys, subprocess
def sh(c): return subprocess.run(c, capture_output=True, text=True, errors='replace').stdout
FMA = re.compile(r'^(vfmadd\d*ps|vfnmadd\d*ps|fmla|fmls|xvfmadd\.s|xvfnmadd\.s|vfmacc\.v[vf]|vfmadd\.v[vf]|vfnmsac\.v[vf]|vfmsac\.v[vf]|fmadd|fmadd\.s)$')
LOAD = re.compile(r'^(vmovups|vmovaps|vbroadcastss|vmovss|vmovsd|ld1|ld1r|ld2|ldp|ldr|ldnp|xvld|xvldrepl\.w|xvldrepl|vle\d+\.v|vlse\d+\.v|vlseg\d+e\d+\.v|flw|fld|ld1w|ld1rw|ldnt1w)$')
for arg in sys.argv[1:]:
    isa, obj = arg.split('=', 1)
    dis = sh(['llvm-objdump-21', '-d', '--no-show-raw-insn', obj])
    ins = []
    for ln in dis.split('\n'):
        m = re.match(r'\s*([0-9a-f]+):\s+(\S+)\s*(.*)', ln)
        if m: ins.append((int(m.group(1), 16), m.group(2), m.group(3)))
    addr = {a: i for i, (a, _, _) in enumerate(ins)}
    loops = []
    for i, (a, mn, op) in enumerate(ins):
        m = re.search(r'(?:0x)?([0-9a-f]+)\s*<', op) or re.search(r'(?:^|[\s,])(?:0x)?([0-9a-f]+)\s*$', op)
        if m and re.match(r'(j|b|cb|tb|loop)', mn):
            t = int(m.group(1), 16)
            if t in addr and addr[t] <= i: loops.append((addr[t], i))
    inner = [l for l in loops if not any(o != l and l[0] <= o[0] and o[1] <= l[1] for o in loops)]
    best = None
    for lo, hi in inner:
        body = ins[lo:hi + 1]
        nf = sum(1 for _, mn, _ in body if FMA.match(mn))
        if best is None or nf > best[0]: best = (nf, lo, hi)
    if best is None or best[0] == 0:
        print('%s\tno FMA loop found' % isa); continue
    nf, lo, hi = best
    body = ins[lo:hi + 1]
    n = len(body)
    nl = sum(1 for _, mn, _ in body if LOAD.match(mn))
    lanes = None
    ops = [op for _, mn, op in body if FMA.match(mn)]
    if isa in ('haswell',): lanes = 8 if any('ymm' in o for o in ops) else 4
    elif isa == 'skylakex': lanes = 16 if any('zmm' in o for o in ops) else 8
    elif isa == 'neon': lanes = 2 if any('.2d' in o for o in ops) else 4
    elif isa == 'lasx': lanes = 8
    elif isa == 'rvv': lanes = 8
    elif isa == 'sve': lanes = None
    mix = {}
    for _, mn, _ in body: mix[mn] = mix.get(mn, 0) + 1
    top = ', '.join('%s %d' % kv for kv in sorted(mix.items(), key=lambda x: -x[1])[:6])
    if lanes:
        print('%s\tloop %d instructions, %d FMA (%.0f%%), %d loads; %d multiply-adds per iteration at %d lanes; %.3f instructions per multiply-add\t%s' % (isa, n, nf, 100.0 * nf / n, nl, nf * lanes, lanes, n / (nf * lanes), top))
    else:
        print('%s\tloop %d instructions, %d FMA (%.0f%%), %d loads; multiply-adds per iteration = %d x VL; instructions per multiply-add = %.3f / VL\t%s' % (isa, n, nf, 100.0 * nf / n, nl, nf, n / nf, top))
