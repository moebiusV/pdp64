#!/usr/bin/env python3
"""Generate tests/sim/vec-strip.s: the strip is invisible (errata 173).  One program, run by tools/check-sim64.sh at the strips 16, 32 and 64 (tests/sim/vec-strip.strips) and at the
default, that must give the same bits at every strip: the expected values are computed here, by a model written independently of the simulator, from the architecture alone
(docs/encoding-work/vec-isa.md section 8: the canonical order of a floating-point sum, the accumulator blocks of 16 bytes), never from a run.  It uses every kind of word that could show a
strip: the floating-point sums (vacc.f, vacc.d, vacc.f.d over 1000 values of adversarial size, so that the order of the additions changes the result), the maximum and minimum with
signed zeros, the integer reductions, the lane operations, the sliding window with its halo, segments, strided loads, the table lookup, compares and select, conversions, the
narrowing stores, and the accumulator blocks: running lanes read inside the block, a vfin epilogue, and the GEMM micro-kernel with vfmab.  A failed check n exits with n.
usage: gen_vec_strip.py OUT.s"""
import sys as _sys, os as _os
_sys.path.insert(0, _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), '..', '..', 'tools'))
import marks		# the words of the encoding written with the width suffixes (tools/marks.py)
import random, struct, sys
from fractions import Fraction

rng = random.Random(173)
N = 1000


def sx(x, bits):
    x &= (1 << bits) - 1
    return x - (1 << bits) if x >> (bits - 1) else x


def ux(x, bits):
    return x & ((1 << bits) - 1)


def pack(vals, size):
    return b''.join((v & ((1 << (8 * size)) - 1)).to_bytes(size, 'little') for v in vals)


def f2b(x):
    return struct.unpack('<I', struct.pack('<f', x))[0]


def b2f(b):
    return struct.unpack('<f', struct.pack('<I', b & 0xffffffff))[0]


def d2b(x):
    return struct.unpack('<Q', struct.pack('<d', x))[0]


def b2d(b):
    return struct.unpack('<d', struct.pack('<Q', b & (2 ** 64 - 1)))[0]


def to32(x):
    """the binary32 nearest to the exact rational x, ties to even (exact: no double rounding); the data stay in the normal range"""
    x = Fraction(x)
    if x == 0:
        return 0.0
    s = -1 if x < 0 else 1
    x = abs(x)
    e = x.numerator.bit_length() - x.denominator.bit_length()
    if Fraction(2) ** e > x:
        e -= 1
    m = x * Fraction(2) ** (23 - e)
    q = m.numerator // m.denominator
    rem = m - q
    if rem > Fraction(1, 2) or (rem == Fraction(1, 2) and q & 1):
        q += 1
    return s * q * 2.0 ** (e - 23)


def add32(a, b):
    return to32(Fraction(a) + Fraction(b))


def fma32(a, b, c):
    return to32(Fraction(a) * Fraction(b) + Fraction(c))


def chunks(vals, init, prec, ch=None):
    """the canonical order of a floating-point sum (vec-isa.md section 8): chunks of 16 bytes of the source lanes (4 binary32, 2 binary64), each by the fixed tree, added to the register in order"""
    ch = ch or (4 if prec == 32 else 2)
    ad = add32 if prec == 32 else (lambda a, b: a + b)
    acc = init
    for c in range(0, len(vals), ch):
        l = vals[c:c + ch]
        m = len(l)
        t = l[0] if m == 1 else ad(l[0], l[1]) if m == 2 else ad(ad(l[0], l[1]), l[2]) if m == 3 else ad(ad(l[0], l[1]), ad(l[2], l[3]))
        acc = ad(acc, t)
    return acc


def adversarial(n, seed, tiny=1e-8):
    r = random.Random(seed)
    v = []
    while len(v) < n:
        big = 10.0 ** r.uniform(5, 8) * r.choice((-1, 1))
        v += [big, r.uniform(-3, 3), -big, r.uniform(-tiny, tiny) * 1e5, r.uniform(0.5, 1.5) * 10.0 ** r.randint(-8, 8) * r.choice((-1, 1))]
    return [to32(x) for x in v[:n]]


data = []
T = []
cnt = [0]


def buf(label, content, space=False):
    data.append((label, content, space))


def newtest():
    cnt[0] += 1
    return cnt[0]


def cmpmem(k, lab_o, lab_e, nbytes):
    return ['\tlea\t%s, r1' % lab_o, '\tlea\t%s, r2' % lab_e, '\tmovq\t#%d, r4' % nbytes, 'c%d:' % k, '\tmovzb\t(r1)+, r5', '\tmovzb\t(r2)+, r6', '\tcbne\tr5, r6, fail', '\tsob\tr4, c%d' % k]


def cmpreg(reg, val):
    return ['\tmovq\t=0x%x, r11' % (val & ((1 << 64) - 1)), '\tcbne\t%s, r11, fail' % reg]


def addt(lines):
    T.extend(lines)


def begin(k):
    return ['\tmovq\t#%d, r9' % k]


# ---- the floating-point sums in the canonical order
fa = adversarial(N, 1)
fbits = [f2b(x) for x in fa]
for title, body, init, prec, lane, vals, mk in (
        ('vacc.f over 1000 binary32', ['vld.f v0, (r1)+', 'vacc.f r10, v0'], 0.5, 32, 4, fa, lambda v: f2b(v)),
        ('vacc.f over 999 binary32 (a short last chunk)', ['vld.f v0, (r1)+', 'vacc.f r10, v0'], -1.25, 32, 4, fa[:999], lambda v: f2b(v)),
        ('vacc.f.d: binary32 lanes summed in binary64', ['vld.f v0, (r1)+', 'vacc.f.d r10, v0'], 0.25, 64, 4, fa, lambda v: d2b(v))):
    k = newtest()
    n = len(vals)
    buf('A%d' % k, pack([f2b(x) for x in vals], 4))
    want = mk(chunks(vals, to32(init) if prec == 32 else init, prec, 4))
    ib = f2b(init) if prec == 32 else d2b(init)
    addt(begin(k) + ['\tlea\tA%d, r1' % k, '\tlea\tA%d+%d, r5' % (k, 4 * n), '\tmovq\t=0x%x, r10' % ib, '\tvec\tr1, r5'] + ['\t' + b for b in body] + ['\tvend'] + cmpreg('r10', want))
da = [x * (1 + 2.0 ** -40) for x in adversarial(N, 2)]
k = newtest()
buf('A%d' % k, pack([d2b(x) for x in da], 8))
addt(begin(k) + ['\tlea\tA%d, r1' % k, '\tlea\tA%d+%d, r5' % (k, 8 * N), '\tmovq\t=0x%x, r10' % d2b(1.0), '\tvec\tr1, r5', '\tvld.d v0, (r1)+', '\tvacc.d r10, v0', '\tvend'] + cmpreg('r10', d2b(chunks(da, 1.0, 64))))
# several reductions of different precision in one block, and a float sum beside a store of the same lanes
k = newtest()
buf('A%d' % k, pack(fbits, 4)); buf('O%d' % k, bytes(4 * N), True); buf('E%d' % k, pack(fbits, 4))
addt(begin(k) + ['\tlea\tA%d, r1' % k, '\tlea\tO%d, r3' % k, '\tlea\tA%d+%d, r5' % (k, 4 * N), '\tmovq\t#0, r10', '\tmovq\t#0, r11', '\tvec\tr1, r5', '\tvld.f v0, (r1)+', '\tvacc.f r10, v0', '\tvacc.f.d r11, v0',
                 '\tvst.f v0, (r3)+', '\tvend'] + cmpreg('r10', f2b(chunks(fa, 0.0, 32))) + cmpreg('r11', d2b(chunks(fa, 0.0, 64, 4))) + cmpmem(k, 'O%d' % k, 'E%d' % k, 4 * N))

# ---- the maximum and minimum with signed zeros: the order is the stream's (a comparison is exact, so only the sign of a zero and a NaN can show the order)
mz = [to32(-(rng.random() * 100 + 1)) for _ in range(N)]
for p in (15, 16, 31, 32, 63, 64, 100, 127, 128):
    mz[p] = 0.0 if p % 2 else -0.0
    mz[p + 1] = -0.0 if p % 2 else 0.0
for mn, init, better in (('vmaxacc.f', float('-inf'), lambda v, a: v > a), ('vminacc.f', float('inf'), lambda v, a: v < a)):
    k = newtest()
    buf('A%d' % k, pack([f2b(x) for x in mz], 4))
    acc = init
    for v in mz:
        if better(v, acc):
            acc = v
    addt(begin(k) + ['\tlea\tA%d, r1' % k, '\tlea\tA%d+%d, r5' % (k, 4 * N), '\tmovq\t=0x%x, r10' % f2b(init), '\tvec\tr1, r5', '\tvld.f v0, (r1)+', '\t%s r10, v0' % mn, '\tvend'] +
         cmpreg('r10', f2b(acc)))
# a zero-only stream: the sign of the maximum of [-0.0, +0.0, -0.0, ...] after an initial -inf is that of the first zero
zs = [-0.0 if i % 3 == 0 else 0.0 for i in range(N)]
k = newtest()
buf('A%d' % k, pack([f2b(x) for x in zs], 4))
addt(begin(k) + ['\tlea\tA%d, r1' % k, '\tlea\tA%d+%d, r5' % (k, 4 * N), '\tmovq\t=0x%x, r10' % f2b(float('-inf')), '\tvec\tr1, r5', '\tvld.f v0, (r1)+', '\tvmaxacc.f r10, v0', '\tvend'] + cmpreg('r10', f2b(-0.0)))

# ---- integer reductions (exact: the same at every strip)
ia = [rng.getrandbits(32) for _ in range(N)]
k = newtest()
buf('A%d' % k, pack(ia, 4))
addt(begin(k) + ['\tlea\tA%d, r1' % k, '\tlea\tA%d+%d, r5' % (k, 4 * N), '\tmovq\t#7, r10', '\tvec\tr1, r5', '\tvld.l v0, (r1)+', '\tvacc.l.q r10, v0', '\tvend'] + cmpreg('r10', 7 + sum(sx(x, 32) for x in ia)))
wa = [rng.getrandbits(16) for _ in range(N)]; wb = [rng.getrandbits(16) for _ in range(N)]
wa[0] = wb[0] = wa[1] = wb[1] = 0x8000
k = newtest()
buf('A%d' % k, pack(wa, 2)); buf('B%d' % k, pack(wb, 2))
addt(begin(k) + ['\tlea\tA%d, r1' % k, '\tlea\tB%d, r2' % k, '\tlea\tA%d+%d, r5' % (k, 2 * N), '\tmovq\t#-5, r10', '\tvec\tr1, r5', '\tvld.w v0, (r1)+', '\tvld.w v1, (r2)+', '\tvdacc.w r10, v0, v1', '\tvend'] +
     cmpreg('r10', -5 + sum(sx(x, 16) * sx(y, 16) for x, y in zip(wa, wb))))
k = newtest()
pr = [sx(x, 16) * sx(y, 16) for x, y in zip(wa, wb)]
lanes = [sx(pr[j] + (pr[j + 1] if j + 1 < N else 0), 32) for j in range(0, N, 2)]
addt(begin(k) + ['\tlea\tA%d, r1' % (k - 1), '\tlea\tB%d, r2' % (k - 1), '\tlea\tA%d+%d, r5' % (k - 1, 2 * N), '\tmovq\t#1000, r10', '\tvec\tr1, r5', '\tvld.w v0, (r1)+', '\tvld.w v1, (r2)+', '\tvdot.w v2, v0, v1',
                 '\tvacc.l.q r10, v2', '\tvend'] + cmpreg('r10', 1000 + sum(lanes)))
ba = [rng.getrandbits(8) for _ in range(N)]; bb = [rng.getrandbits(8) for _ in range(N)]
k = newtest()
buf('A%d' % k, pack(ba, 1)); buf('B%d' % k, pack(bb, 1))
addt(begin(k) + ['\tlea\tA%d, r1' % k, '\tlea\tB%d, r2' % k, '\tlea\tA%d+%d, r5' % (k, N), '\tmovq\t#3, r10', '\tvec\tr1, r5', '\tvld.bu v0, (r1)+', '\tvld.bu v1, (r2)+', '\tvsad.bu r10, v0, v1', '\tvend'] +
     cmpreg('r10', 3 + sum(abs(x - y) for x, y in zip(ba, bb))))

# ---- lane operations on floats: a multiply, an add, a fused multiply-add into a register loaded from memory, stored
fb2 = adversarial(N, 3); fc = adversarial(N, 4)
k = newtest()
buf('A%d' % k, pack([f2b(x) for x in fa], 4)); buf('B%d' % k, pack([f2b(x) for x in fb2], 4)); buf('C%d' % k, pack([f2b(x) for x in fc], 4)); buf('O%d' % k, bytes(4 * N), True)
want = [f2b(fma32(fa[i], fb2[i], fc[i])) for i in range(N)]
buf('E%d' % k, pack(want, 4))
addt(begin(k) + ['\tlea\tA%d, r1' % k, '\tlea\tB%d, r2' % k, '\tlea\tC%d, r7' % k, '\tlea\tO%d, r3' % k, '\tlea\tA%d+%d, r5' % (k, 4 * N), '\tvec\tr1, r5', '\tvld.f v0, (r1)+', '\tvld.f v1, (r2)+',
                 '\tvld.f v2, (r7)+', '\tvfma.f v2, v0, v1', '\tvst.f v2, (r3)+', '\tvend'] + cmpmem(k, 'O%d' % k, 'E%d' % k, 4 * N))

# ---- the sliding window with its halo (3 taps, centre 1): the neighbours across the edge of a strip are read from where the source was loaded, and beyond the region as the scalar code reads them
pad = 4
fw = [to32(rng.uniform(-8, 8)) for _ in range(N + 2 * pad)]
co = [to32(0.25), to32(0.5), to32(-0.125)]
k = newtest()
buf('A%d' % k, pack([f2b(x) for x in fw], 4)); buf('O%d' % k, bytes(4 * N), True)
want = []
for i in range(N):
    j0 = i + pad
    fs = 0.0
    for t in range(3):
        fs = float(Fraction(fw[j0 + t - 1]) * Fraction(co[t]) + Fraction(fs))
    want.append(f2b(struct.unpack('<f', struct.pack('<f', fs))[0]))
buf('E%d' % k, pack(want, 4))
addt(begin(k) + ['\tlea\tA%d+%d, r1' % (k, 4 * pad), '\tlea\tO%d, r3' % k, '\tlea\tA%d+%d, r5' % (k, 4 * (pad + N)), '\tmovq\t=0x%x, r20' % f2b(co[0]), '\tmovq\t=0x%x, r21' % f2b(co[1]), '\tmovq\t=0x%x, r22' % f2b(co[2]),
                 '\tvec\tr1, r5', '\tvld.f v0, (r1)+', '\tvfir.f v1, v0, r20, #3', '\tvst.f v1, (r3)+', '\tvend'] + cmpmem(k, 'O%d' % k, 'E%d' % k, 4 * N))

# ---- segments, a strided load, the table lookup
rgb = [rng.getrandbits(8) for _ in range(3 * 333)]
k = newtest()
buf('A%d' % k, pack(rgb, 1)); buf('O%d' % k, bytes(2 * 333), True)
buf('E%d' % k, pack([rgb[3 * i] + rgb[3 * i + 1] + rgb[3 * i + 2] for i in range(333)], 2))
addt(begin(k) + ['\tlea\tA%d, r1' % k, '\tlea\tO%d, r3' % k, '\tlea\tA%d+%d, r5' % (k, 3 * 333), '\tvec\tr1, r5', '\tvlseg3.bu.w v0, (r1)+', '\tvadd.w v3, v0, v1', '\tvadd.w v3, v3, v2', '\tvst.w v3, (r3)+', '\tvend'] +
     cmpmem(k, 'O%d' % k, 'E%d' % k, 2 * 333))
k = newtest()
w2 = [rng.getrandbits(16) for _ in range(2 * 500)]
buf('A%d' % k, pack(w2, 2)); buf('O%d' % k, bytes(2 * 1000), True)
sw = []
for i in range(500):
    sw += [w2[2 * i + 1], w2[2 * i]]
buf('E%d' % k, pack(sw, 2))
addt(begin(k) + ['\tlea\tA%d, r1' % k, '\tlea\tO%d, r3' % k, '\tlea\tA%d+%d, r5' % (k, 2000), '\tvec\tr1, r5', '\tvlseg2.w v0, (r1)+', '\tvmov.w v2, v1', '\tvmov.w v3, v0', '\tvsseg2.w v2, (r3)+', '\tvend'] +
     cmpmem(k, 'O%d' % k, 'E%d' % k, 2000))
k = newtest()
sb = [rng.getrandbits(8) for _ in range(3 * 333 + 3)]
buf('A%d' % k, pack(sb, 1)); buf('O%d' % k, bytes(2 * 333), True); buf('E%d' % k, pack([sb[3 * i] for i in range(333)], 2))
addt(begin(k) + ['\tlea\tA%d, r1' % k, '\tlea\tO%d, r3' % k, '\tlea\tA%d+%d, r5' % (k, 3 * 333), '\tvec\tr1, r5', '\tvldt.bu.w v0, (r1)+, #3', '\tvst.w v0, (r3)+', '\tvend'] + cmpmem(k, 'O%d' % k, 'E%d' % k, 2 * 333))
idx = [rng.getrandbits(5) for _ in range(N)]
tab = [rng.getrandbits(8) for _ in range(16)]
k = newtest()
buf('A%d' % k, pack(idx, 1)); buf('T%d' % k, pack(tab, 1)); buf('O%d' % k, bytes(N), True); buf('E%d' % k, pack([tab[i] if i < 16 else 0 for i in idx], 1))
addt(begin(k) + ['\tlea\tA%d, r1' % k, '\tlea\tT%d, r6' % k, '\tlea\tO%d, r3' % k, '\tlea\tA%d+%d, r5' % (k, N), '\tvec\tr1, r5', '\tvld.bu v0, (r1)+', '\tvtbl.b v1, (r6), v0', '\tvst.b v1, (r3)+', '\tvend'] +
     cmpmem(k, 'O%d' % k, 'E%d' % k, N))

# ---- compare, select, convert, narrow with saturation and a rounding shift
la = [sx(rng.getrandbits(32), 32) for _ in range(N)]; lb = [sx(rng.getrandbits(32), 32) for _ in range(N)]
k = newtest()
buf('A%d' % k, pack(la, 4)); buf('B%d' % k, pack(lb, 4)); buf('O%d' % k, bytes(4 * N), True)
buf('E%d' % k, pack([f2b(to32(max(x, y))) for x, y in zip(la, lb)], 4))
addt(begin(k) + ['\tlea\tA%d, r1' % k, '\tlea\tB%d, r2' % k, '\tlea\tO%d, r3' % k, '\tlea\tA%d+%d, r5' % (k, 4 * N), '\tvec\tr1, r5', '\tvld.l v0, (r1)+', '\tvld.l v1, (r2)+', '\tvcgt.l v2, v0, v1', '\tvbsl v3, v2, v0, v1',
                 '\tvcvt.l.f v4, v3', '\tvst.f v4, (r3)+', '\tvend'] + cmpmem(k, 'O%d' % k, 'E%d' % k, 4 * N))
k = newtest()
buf('A%d' % k, pack(la, 4)); buf('O%d' % k, bytes(N), True)
buf('E%d' % k, pack([max(0, min(255, (x + 8) >> 4)) for x in la], 1))
addt(begin(k) + ['\tlea\tA%d, r1' % k, '\tlea\tO%d, r3' % k, '\tlea\tA%d+%d, r5' % (k, 4 * N), '\tvec\tr1, r5', '\tvld.l v0, (r1)+', '\tvsts.l.bu v0, (r3)+, #4', '\tvend'] + cmpmem(k, 'O%d' % k, 'E%d' % k, N))

# ---- accumulator blocks: the strip is 16 bytes on every implementation (the lanes of an accumulator are the program's)
# (a) the running sums by lane, read inside the block (a vst of the accumulator in every strip)
k = newtest()
buf('A%d' % k, pack([x & 0xffffffff for x in la], 4)); buf('O%d' % k, bytes(4 * N), True)
acc = [0] * 4; out = []
for i in range(N):
    acc[i % 4] = ux(acc[i % 4] + la[i], 32)
    out.append(acc[i % 4])
buf('E%d' % k, pack(out, 4))
addt(begin(k) + ['\tlea\tA%d, r1' % k, '\tlea\tO%d, r3' % k, '\tlea\tA%d+%d, r5' % (k, 4 * N), '\tvec\tr1, r5', '\tvclr.l v4, #1', '\tvld.l v0, (r1)+', '\tvadd.l v4, v4, v0', '\tvst.l v4, (r3)+', '\tvend'] +
     cmpmem(k, 'O%d' % k, 'E%d' % k, 4 * N))
# (b) floating-point lanes accumulated by vfma, the lanes read once, after the last strip, by vfin: the sum of the four lanes by the fixed tree is vacc.f of the accumulator
k = newtest()
buf('A%d' % k, pack([f2b(x) for x in fa], 4)); buf('B%d' % k, pack([f2b(x) for x in fb2], 4))
acc = [0.0] * 4
for i in range(N):
    acc[i % 4] = fma32(fa[i], fb2[i], acc[i % 4])
tot = add32(0.0, add32(add32(acc[0], acc[1]), add32(acc[2], acc[3])))
addt(begin(k) + ['\tlea\tA%d, r1' % k, '\tlea\tB%d, r2' % k, '\tlea\tA%d+%d, r5' % (k, 4 * N), '\tmovq\t#0, r10', '\tvec\tr1, r5', '\tvclr.f v4, #1', '\tvld.f v0, (r1)+', '\tvld.f v1, (r2)+', '\tvfma.f v4, v0, v1',
                 '\tvfin', '\tvacc.f r10, v4', '\tvend'] + cmpreg('r10', f2b(tot)))
# (c) the GEMM micro-kernel: C[8 x 4] += A_panel . B_panel over K steps, eight accumulators, vfmab (the pointer of A moves one float for each vfmab and each strip: a strip is one k step on every implementation)
K = 50
ap = [to32(rng.uniform(-2, 2)) for _ in range(K * 8)]; bp = [to32(rng.uniform(-2, 2)) for _ in range(K * 4)]
c0 = [to32(rng.uniform(-4, 4)) for _ in range(8 * 8)]		# C: 8 rows of ldc = 32 bytes (8 floats), the tile is the first 4 floats of each row
k = newtest()
buf('A%d' % k, pack([f2b(x) for x in ap], 4)); buf('B%d' % k, pack([f2b(x) for x in bp], 4)); buf('C%d' % k, pack([f2b(x) for x in c0], 4))
want = list(c0)
for r in range(8):
    for c in range(4):
        a = 0.0
        for kk in range(K):
            a = fma32(bp[kk * 4 + c], ap[kk * 8 + r], a)
        want[r * 8 + c] = add32(c0[r * 8 + c], a)
buf('E%d' % k, pack([f2b(x) for x in want], 4))
setup = ['\tlea\tA%d, r0' % k, '\tlea\tB%d, r1' % k, '\tlea\tB%d+%d, r5' % (k, 16 * K)] + ['\tlea\tC%d+%d, r%d' % (k, 32 * r, 16 + r) for r in range(8)]
body = ['vclr.f v0, #8', 'vld.f v8, (r1)+'] + ['vfmab.f v%d, v8, (r0)+' % r for r in range(8)] + ['vfin']
for r in range(8):
    body += ['vld.f v9, (r%d)' % (16 + r), 'vadd.f v9, v9, v%d' % r, 'vst.f v9, (r%d)' % (16 + r)]
addt(begin(k) + setup + ['\tvec\tr1, r5'] + ['\t' + b for b in body] + ['\tvend'] + cmpmem(k, 'C%d' % k, 'E%d' % k, 4 * 64))

out = ['; GENERATED by tests/sim/gen_vec_strip.py -- do not edit.  The strip of the vec block is invisible (errata 173, docs/encoding-work/vec-isa.md section 8): this program is run at the strips 16, 32 and 64',
       '; (vec-strip.strips) and gives the expected values of a model written from the architecture alone, at each: the floating-point sums in the canonical order, the sliding window, the accumulator',
       '; blocks, the integer reductions and the lane operations.  %d checks; a failed check n exits with n.' % cnt[0], '\t.text', '\t.globl\t_start', '_start:']
out += T
out += ['\tmovq\t#0, r0', '\ttrap\t#0', 'fail:\tmovq\tr9, r0', '\ttrap\t#0', '', '\t.data']
for lab, content, space in data:
    out.append('\t.align\t8')
    out.append('%s:' % lab)
    if space:
        out.append('\t.space\t%d' % len(content))
    else:
        for i in range(0, len(content), 24):
            out.append('\t.byte\t' + ', '.join(str(x) for x in content[i:i + 24]))
open(sys.argv[1], 'w').write(marks.spell_text('\n'.join(out)) + '\n')
print('%d checks' % cnt[0])
