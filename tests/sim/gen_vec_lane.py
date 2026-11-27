#!/usr/bin/env python3
"""Generate tests/sim/vec-lane.s: the lane words of the vec family that no other test runs (the bases vsub vmul vand vor vxor vshl vshr vsar vabd vabdu vmin vmax vminu vmaxu vneg
vsubs vaddsu vsubsu vfnma vdotu vdotsu, the strided store vstt, the segment words vlseg4 vsseg3 vsseg4; tools/facts.py --check requires that every base of the family is
run by some test) over 77 elements (a trip count that is not a multiple of the strip, so the last strip is short) against the expected values of an independent model written
here in Python integers (the semantics of docs/encoding-work/vec-isa.md section 2: lane arithmetic wraps, a shift count is the unsigned value of the lane of the second operand
and a count of the lane width or more gives 0, or the sign for vsar; the saturating words clamp; the unsigned words compare as unsigned).  The corners (the sign boundary,
all ones, zero, a shift count at and above the width) are put in by hand.  The result of a test is compared byte for byte (or register for register); a failed test n exits with n.
usage: gen_vec_lane.py OUT.s"""
import sys as _sys, os as _os
_sys.path.insert(0, _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), '..', '..', 'tools'))
import marks		# the words of the encoding written with the width suffixes (tools/marks.py)
import random, struct, sys

N = 77
rng = random.Random(2026)
LB = {'b': 1, 'w': 2, 'l': 4, 'q': 8}
data = []
T = []
cnt = [0]


def sx(x, bits):
    x &= (1 << bits) - 1
    return x - (1 << bits) if x >> (bits - 1) else x


def ux(x, bits):
    return x & ((1 << bits) - 1)


def rnd(bits, n=N):
    return [rng.getrandbits(bits) for _ in range(n)]


def pack(vals, size):
    return b''.join((v & ((1 << (8 * size)) - 1)).to_bytes(size, 'little') for v in vals)


def corners(vals, bits, extra):
    v = list(vals)
    for i, x in enumerate(extra):
        v[i] = ux(x, bits)
    return v


def newtest():
    cnt[0] += 1
    return cnt[0]


def buf(label, content):
    data.append((label, content))


def block(k, nbytes_a, body, loads, out=('O', 'r3'), extra=()):
    o = ['\tmovq\t#%d, r9' % k]
    have = {l for l, _ in data}
    o += ['\tlea\t%s%d, %s' % (lab, k, r) for lab, r in list(loads) + [out] if lab + str(k) in have]
    o += ['\t' + e for e in extra]
    o += ['\tlea\tA%d+%d, r5' % (k, nbytes_a), '\tvec\tr1, r5'] + ['\t' + b for b in body] + ['\tvend']
    return o


def compare(k, nbytes):
    return ['\tlea\tO%d, r1' % k, '\tlea\tE%d, r2' % k, '\tmovq\t#%d, r4' % nbytes, 'c%d:' % k, '\tmovzb\t(r1)+, r5', '\tmovzb\t(r2)+, r6', '\tcbne\tr5, r6, fail', '\tsob\tr4, c%d' % k]


def cmpreg(reg, val):
    return ['\tmovq\t=0x%x, r11' % (val & ((1 << 64) - 1)), '\tcbne\t%s, r11, fail' % reg]


def lane_test(title, k, lane_in, body, a, b, c, want, mst, extra=(), bsize=None):
    """inputs A (B, C when given) of N elements of lane_in bytes, output O of the store's element size mst"""
    buf('A%d' % k, pack(a, lane_in))
    ld = [('A', 'r1')]
    if b is not None:
        buf('B%d' % k, pack(b, bsize or lane_in)); ld.append(('B', 'r2'))
    if c is not None:
        buf('C%d' % k, pack(c, lane_in)); ld.append(('C', 'r7'))
    buf('E%d' % k, pack(want, mst))
    buf('O%d' % k, bytes(N * mst))
    return [';; test %d: %s' % (k, title)] + block(k, N * lane_in, body, ld, ('O', 'r3'), extra) + compare(k, N * mst)


def f2b(x):
    return struct.unpack('<I', struct.pack('<f', x))[0]


def b2f(b):
    return struct.unpack('<f', struct.pack('<I', b & 0xffffffff))[0]


# ---- the integer lane words, in the domain of the unsigned lane value x, y of `bits` bits: the model of each
def model(mn, bits):
    m = (1 << bits) - 1
    lo, hi = -(1 << (bits - 1)), (1 << (bits - 1)) - 1
    S = lambda x: sx(x, bits)
    return {
        'vsub': lambda x, y: (x - y) & m,
        'vmul': lambda x, y: (x * y) & m,
        'vand': lambda x, y: x & y,
        'vor': lambda x, y: x | y,
        'vxor': lambda x, y: x ^ y,
        'vshl': lambda x, y: 0 if y >= bits else (x << y) & m,
        'vshr': lambda x, y: 0 if y >= bits else x >> y,
        'vsar': lambda x, y: (S(x) >> min(y, bits - 1)) & m,
        'vabd': lambda x, y: abs(S(x) - S(y)) & m,
        'vabdu': lambda x, y: abs(x - y),
        'vmin': lambda x, y: min(S(x), S(y)) & m,
        'vmax': lambda x, y: max(S(x), S(y)) & m,
        'vminu': lambda x, y: min(x, y),
        'vmaxu': lambda x, y: max(x, y),
        'vsubs': lambda x, y: max(lo, min(hi, S(x) - S(y))) & m,
        'vaddsu': lambda x, y: min(m, x + y),
        'vsubsu': lambda x, y: max(0, x - y),
    }[mn]


LANES = {'vsub': 'bwlq', 'vmul': 'bwl', 'vand': 'bwlq', 'vor': 'bwlq', 'vxor': 'bwlq', 'vshl': 'bwlq', 'vshr': 'bwlq', 'vsar': 'bwlq', 'vabd': 'bwl', 'vabdu': 'bw',
         'vmin': 'bwl', 'vmax': 'bwl', 'vminu': 'bwl', 'vmaxu': 'bwl', 'vsubs': 'bwl', 'vaddsu': 'bwl', 'vsubsu': 'bwl'}
SHIFT = ('vshl', 'vshr', 'vsar')
for mn, lanes in LANES.items():
    for lane in lanes:
        bits = 8 * LB[lane]
        top = 1 << (bits - 1)
        f = model(mn, bits)
        a = rnd(bits); b = rnd(bits)
        if mn in SHIFT:
            b = [rng.randrange(0, bits + 3) for _ in range(N)]                    # the counts: up to and past the lane width
            a = corners(a, bits, [top, top - 1, (1 << bits) - 1, 1, top, 0xa5a5a5a5a5a5a5a5])
            b = corners(b, bits, [0, 1, bits - 1, bits, bits + 1, 2])
        else:
            for i in range(0, N, 4):
                b[i] = a[i]                                                       # every fourth lane is equal
            a = corners(a, bits, [top, top - 1, (1 << bits) - 1, 0, 1, top, top, 0, (1 << bits) - 1, top + 1])
            b = corners(b, bits, [top - 1, top, 0, (1 << bits) - 1, 1, top, 0, top, (1 << bits) - 1, 1])
        k = newtest()
        T += lane_test('%s.%s vector by vector' % (mn, lane), k, LB[lane], ['vld.%s v0, (r1)+' % lane, 'vld.%s v1, (r2)+' % lane, '%s.%s v2, v0, v1' % (mn, lane), 'vst.%s v2, (r3)+' % lane],
                       a, b, None, [f(x, y) for x, y in zip(a, b)], LB[lane])
        reg = 3 if mn in SHIFT else top | (0xabcd << bits)                      # the register form: the low `bits` bits are the lane value (a count of 3 for a shift)
        k = newtest()
        T += lane_test('%s.%s by a register' % (mn, lane), k, LB[lane], ['vld.%s v0, (r1)+' % lane, '%s.%s v2, v0, r8' % (mn, lane), 'vst.%s v2, (r3)+' % lane], a, None, None,
                       [f(x, ux(reg, bits)) for x in a], LB[lane], extra=['movq\t=0x%x, r8' % reg])
        imm = 5 if mn in SHIFT else -2
        k = newtest()
        T += lane_test('%s.%s by the immediate %d' % (mn, lane, imm), k, LB[lane], ['vld.%s v0, (r1)+' % lane, '%s.%s v2, v0, #%d' % (mn, lane, imm), 'vst.%s v2, (r3)+' % lane], a, None, None,
                       [f(x, ux(imm, bits)) for x in a], LB[lane])

# ---- vneg: 0 - x in the lane (the most negative value stays)
for lane in 'bwlq':
    bits = 8 * LB[lane]
    a = corners(rnd(bits), bits, [1 << (bits - 1), 0, 1, (1 << bits) - 1, (1 << (bits - 1)) - 1])
    k = newtest()
    T += lane_test('vneg.%s' % lane, k, LB[lane], ['vld.%s v0, (r1)+' % lane, 'vneg.%s v2, v0' % lane, 'vst.%s v2, (r3)+' % lane], a, None, None, [(-x) & ((1 << bits) - 1) for x in a], LB[lane])

# ---- the binary32 lanes of vsub, vmul, vmin, vmax (finite values without a signed zero, so that the result does not depend on the order of the operands) and vfnma
# (vD - vA x vB, fused; the values are small multiples of 1/4, so every product and sum is exact)
fp = lambda: [f2b(rng.randrange(-4000, 4001) / 4.0 or 0.25) for _ in range(N)]
fa, fb, fc = fp(), fp(), fp()
for mn, g in (('vsub', lambda x, y: x - y), ('vmul', lambda x, y: x * y), ('vmin', min), ('vmax', max)):
    k = newtest()
    T += lane_test('%s.f vector by vector' % mn, k, 4, ['vld.f v0, (r1)+', 'vld.f v1, (r2)+', '%s.f v2, v0, v1' % mn, 'vst.f v2, (r3)+'], fa, fb, None, [f2b(g(b2f(x), b2f(y))) for x, y in zip(fa, fb)], 4)
k = newtest()
T += lane_test('vfnma.f: vD - vA x vB', k, 4, ['vld.f v0, (r1)+', 'vld.f v1, (r2)+', 'vld.f v2, (r7)+', 'vfnma.f v2, v0, v1', 'vst.f v2, (r3)+'], fa, fb, fc,
               [f2b(b2f(z) - b2f(x) * b2f(y)) for x, y, z in zip(fa, fb, fc)], 4)

# ---- vdotu.b and vdotsu.b: the four byte products of each 32-bit lane; the lanes are summed by vacc.l.q, so the check does not depend on the strip (unsigned by unsigned;
# the first operand signed and the second unsigned for vdotsu)
da = corners(rnd(8), 8, [255, 128, 127, 0, 1, 255, 128]); db = corners(rnd(8), 8, [255, 255, 255, 255, 255, 128, 127])
for mn, pa, pb in (('vdotu', lambda x: x, lambda y: y), ('vdotsu', lambda x: sx(x, 8), lambda y: y)):
    k = newtest()
    buf('A%d' % k, pack(da, 1)); buf('B%d' % k, pack(db, 1)); buf('O%d' % k, bytes(8))
    want = 1000 + sum(pa(x) * pb(y) for x, y in zip(da, db))
    T += [';; test %d: %s.b over 77 bytes, the lanes summed by vacc.l.q (the last lane has one product)' % (k, mn)] + \
         block(k, N, ['vld.b v0, (r1)+', 'vld.b v1, (r2)+', '%s.b v2, v0, v1' % mn, 'vacc.l.q r10, v2'], [('A', 'r1'), ('B', 'r2')], ('O', 'r3'), ['movq\t#1000, r10']) + cmpreg('r10', want)

# ---- vstt.b vS, (Ra)+, #3: every third byte of the output (the others stay zero)
a = rnd(8)
k = newtest()
want = bytearray(N * 3)
for i, x in enumerate(a):
    want[3 * i] = x
buf('A%d' % k, pack(a, 1)); buf('E%d' % k, bytes(want)); buf('O%d' % k, bytes(N * 3))
T += [';; test %d: vstt.b with a stride of 3' % k] + block(k, N, ['vld.b v0, (r1)+', 'vstt.b v0, (r3)+, #3'], [('A', 'r1')]) + compare(k, N * 3)

# ---- vlseg4.b: four interleaved bytes (a record of four fields) into v0..v3, each stored to its own plane
recs = [rnd(8, 4) for _ in range(N)]
k = newtest()
buf('A%d' % k, bytes(x for r in recs for x in r))
for f in range(4):
    buf('E%d_%d' % (k, f), bytes(r[f] for r in recs)); buf('O%d_%d' % (k, f), bytes(N))
T += [';; test %d: vlseg4.b: 77 records of four bytes de-interleaved into v0 .. v3' % k, '\tmovq\t#%d, r9' % k, '\tlea\tA%d, r1' % k] + ['\tlea\tO%d_%d, r%d' % (k, f, (3, 6, 7, 8)[f]) for f in range(4)] + \
     ['\tlea\tA%d+%d, r5' % (k, 4 * N), '\tvec\tr1, r5', '\tvlseg4.b v0, (r1)+'] + ['\tvst.b v%d, (r%d)+' % (f, (3, 6, 7, 8)[f]) for f in range(4)] + ['\tvend']
for f in range(4):
    T += ['\tlea\tO%d_%d, r1' % (k, f), '\tlea\tE%d_%d, r2' % (k, f), '\tmovq\t#%d, r4' % N, 'c%d_%d:' % (k, f), '\tmovzb\t(r1)+, r5', '\tmovzb\t(r2)+, r6', '\tcbne\tr5, r6, fail', '\tsob\tr4, c%d_%d' % (k, f)]

# ---- vsseg3.b and vsseg4.b: planes of bytes interleaved into records of three and four bytes
for nf in (3, 4):
    planes = [rnd(8) for _ in range(nf)]
    k = newtest()
    for f in range(nf):
        buf('P%d_%d' % (k, f), bytes(planes[f]))
    buf('A%d' % k, bytes(planes[0]))
    buf('E%d' % k, bytes(planes[f][i] for i in range(N) for f in range(nf))); buf('O%d' % k, bytes(N * nf))
    T += [';; test %d: vsseg%d.b: %d planes of 77 bytes interleaved into records' % (k, nf, nf), '\tmovq\t#%d, r9' % k, '\tlea\tA%d, r1' % k, '\tlea\tO%d, r3' % k] + \
         ['\tlea\tP%d_%d, r%d' % (k, f, 6 + f) for f in range(1, nf)] + ['\tlea\tA%d+%d, r5' % (k, N), '\tvec\tr1, r5', '\tvld.b v0, (r1)+'] + \
         ['\tvld.b v%d, (r%d)+' % (f, 6 + f) for f in range(1, nf)] + ['\tvsseg%d.b v0, (r3)+' % nf, '\tvend'] + compare(k, N * nf)

out = ['; GENERATED by tests/sim/gen_vec_lane.py -- do not edit.  The lane words of the vec family that no other test runs: vsub vmul vand vor vxor vshl vshr vsar vabd vabdu vmin vmax',
       '; vminu vmaxu vneg vsubs vaddsu vsubsu vfnma vdotu vdotsu vstt vlseg4 vsseg3 vsseg4, each over 77 elements (the last strip short) against an independent model; a failed test n exits with n.',
       '\t.text', '\t.globl\t_start', '_start:']
out += T
out += ['\tmovq\t#0, r0', '\ttrap\t#0', 'fail:\tmovq\tr9, r0', '\ttrap\t#0', '', '\t.data']
for lab, content in data:
    out.append('\t.align\t8')
    out.append('%s:' % lab)
    if lab[0] == 'O':
        out.append('\t.space\t%d' % len(content))
    else:
        for i in range(0, len(content), 24):
            out.append('\t.byte\t' + ', '.join(str(x) for x in content[i:i + 24]))
open(sys.argv[1], 'w').write(marks.spell_text('\n'.join(out)) + '\n')
print('%d tests' % cnt[0])
