#!/usr/bin/env python3
"""Generate tests/sim/vec-wave2.s: every word of wave 2 of the vec family (errata 171: the lane compares vceq, vcgt, vcgtu, the bitwise select vbsl, and the conversions
vcvt.l.f, vcvt.lu.f, vcvt.f.l, vcvt.f.lu) run over 77 elements (a trip count that is not a multiple of the strip, so the last strip is short) against the expected values of an
independent model written here (the semantics of docs/encoding-work/vec-isa.md, section "wave 2", worked out in Python integers and IEEE binary32 by struct, not by the
simulator).  The corners are put in by hand: NaN compares, -0.0, the sign boundary of the signed and unsigned compares, a float to integer conversion that overflows or is a NaN,
an integer to float conversion that rounds (2^24 + 1).  The result of a test is compared byte for byte (or register for register); a failed test n exits with n.
usage: gen_vec_wave2.py OUT.s"""
import random, sys

N = 77
rng = random.Random(171)
LB = {'b': 1, 'w': 2, 'l': 4, 'q': 8}
tests = []          # (title, setup+block lines, compare spec)
data = []           # (label, bytes)
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
    """put the corner values (signed or unsigned patterns) at the start"""
    v = list(vals)
    for i, x in enumerate(extra):
        v[i] = ux(x, bits)
    return v


def newtest(title):
    cnt[0] += 1
    return cnt[0]


def buf(label, content):
    data.append((label, content))


def lines_ptr(k, regs):
    """lea the labels A, B, C into r1, r2, r6 as asked"""
    return ['\tlea\t%s%d, %s' % (lab, k, r) for lab, r in regs]


def block(k, nbytes_a, body, loads=(('A', 'r1'),), out=('O', 'r3'), extra=()):
    out_l = ['\tmovq\t#%d, r9' % k]
    have = {l for l, _ in data}
    out_l += lines_ptr(k, [x for x in list(loads) + [out] if x[0] + str(k) in have])
    out_l += list(extra)
    out_l += ['\tlea\tA%d+%d, r5' % (k, nbytes_a), '\tvec\tr1, r5'] + ['\t' + b for b in body] + ['\tvend']
    return out_l


def compare(k, nbytes):
    return ['\tlea\tO%d, r1' % k, '\tlea\tE%d, r2' % k, '\tmovq\t#%d, r4' % nbytes, 'c%d:' % k, '\tmovzb\t(r1)+, r5', '\tmovzb\t(r2)+, r6',
            '\tcbne\tr5, r6, fail', '\tsob\tr4, c%d' % k]


def cmpreg(reg, val):
    return ['\tmovq\t=0x%x, r11' % (val & ((1 << 64) - 1)), '\tcbne\t%s, r11, fail' % reg]


def lane_test(title, k, lane_bytes_in, body, a, b, c, want, mld, mst, extra=(), bsize=None, cin=None, loads=None):
    """a general vector-in, vector-out test: inputs A (and B, C when given) of N elements of lane_bytes_in bytes, output O of the store's element size"""
    sz_in = lane_bytes_in
    buf('A%d' % k, pack(a, sz_in))
    ld = [('A', 'r1')]
    if b is not None:
        buf('B%d' % k, pack(b, bsize or sz_in)); ld.append(('B', 'r2'))
    if c is not None:
        buf('C%d' % k, pack(c, cin or sz_in)); ld.append(('C', 'r7'))
    osz = mst
    buf('E%d' % k, pack(want, osz))
    buf('O%d' % k, bytes(N * osz))
    return [';; test %d: %s' % (k, title)] + block(k, N * sz_in, body, ld, ('O', 'r3'), extra) + compare(k, N * osz)


T = []


def add(x):
    T.extend(x)


import struct


def f2b(x):
    return struct.unpack('<I', struct.pack('<f', x))[0]


def b2f(b):
    return struct.unpack('<f', struct.pack('<I', b & 0xffffffff))[0]


def isnan(x):
    return x != x


M32 = 0xffffffff
CMPNAME = {'vceq': 'equal', 'vcgt': 'signed greater', 'vcgtu': 'unsigned greater'}

# ---- the integer compares: vceq, vcgt, vcgtu on b, w, l: the mask is all ones or zero in the lane; the sign boundary (0x80 against 0x7f) is where signed and unsigned differ.
# forms: vector by vector, a register (the low bits are the lane value), an immediate (sign extended, then cut to the lane)
for lane in ('b', 'w', 'l'):
    bits = 8 * LB[lane]
    top = 1 << (bits - 1)
    a = rnd(bits); b = rnd(bits)
    for i in range(0, N, 3):
        b[i] = a[i]                                  # every third lane is equal
    a = corners(a, bits, [top, top - 1, (1 << bits) - 1, 0, 1, top, top, 0, (1 << bits) - 1])
    b = corners(b, bits, [top - 1, top, 0, (1 << bits) - 1, 1, top, 0, top, (1 << bits) - 1])
    for mn in ('vceq', 'vcgt', 'vcgtu'):
        def pred(x, y):
            if mn == 'vceq':
                return ux(x, bits) == ux(y, bits)
            if mn == 'vcgt':
                return sx(x, bits) > sx(y, bits)
            return ux(x, bits) > ux(y, bits)
        mk = lambda t: ux(-1, bits) if t else 0
        k = newtest(mn)
        add(lane_test('%s.%s vector by vector (%s)' % (mn, lane, CMPNAME[mn]), k, LB[lane], ['vld.%s v0, (r1)+' % lane, 'vld.%s v1, (r2)+' % lane, '%s.%s v2, v0, v1' % (mn, lane), 'vst.%s v2, (r3)+' % lane],
                      a, b, None, [mk(pred(x, y)) for x, y in zip(a, b)], lane, LB[lane]))
        k = newtest(mn)
        add(lane_test('%s.%s by a register holding the sign bit of the lane' % (mn, lane), k, LB[lane], ['vld.%s v0, (r1)+' % lane, '%s.%s v2, v0, r8' % (mn, lane), 'vst.%s v2, (r3)+' % lane],
                      a, None, None, [mk(pred(x, top)) for x in a], lane, LB[lane], extra=['movq\t=0x%x, r8' % (top | (0xabcd << bits))]))
        k = newtest(mn)
        add(lane_test('%s.%s by the immediate -2 (the lane value 2^n - 2 for the unsigned compare)' % (mn, lane), k, LB[lane], ['vld.%s v0, (r1)+' % lane, '%s.%s v2, v0, #-2' % (mn, lane), 'vst.%s v2, (r3)+' % lane],
                      a, None, None, [mk(pred(x, ux(-2, bits))) for x in a], lane, LB[lane]))

# ---- the floating-point compares: a NaN compares false (also with itself), -0.0 equals +0.0, the infinities order; the mask is an integer lane of 32 bits
pool = [0.0, -0.0, 1.0, -1.0, 2.5, -2.5, float('nan'), float('inf'), float('-inf'), 1e-45, -1e-45, 3.0e38, -3.0e38, 16777216.0, 1.5, 1.5]
fa = [f2b(rng.choice(pool)) for _ in range(N)]
fb = [f2b(rng.choice(pool)) for _ in range(N)]
for i, (x, y) in enumerate([(0.0, -0.0), (-0.0, 0.0), (float('nan'), float('nan')), (float('inf'), float('inf')), (float('-inf'), float('inf')), (1e-45, 0.0), (float('nan'), 1.0), (1.0, float('nan')), (-0.0, -0.0)]):
    fa[i] = f2b(x); fb[i] = f2b(y)
for mn in ('vceq', 'vcgt'):
    pr = (lambda x, y: x == y) if mn == 'vceq' else (lambda x, y: x > y)
    k = newtest(mn)
    add(lane_test('%s.f vector by vector (NaN, -0.0, infinities)' % mn, k, 4, ['vld.f v0, (r1)+', 'vld.f v1, (r2)+', '%s.f v2, v0, v1' % mn, 'vst.l v2, (r3)+'], fa, fb, None,
                  [M32 if pr(b2f(x), b2f(y)) else 0 for x, y in zip(fa, fb)], 'f', 4))
    k = newtest(mn)
    add(lane_test('%s.f by a register (2.5)' % mn, k, 4, ['vld.f v0, (r1)+', '%s.f v2, v0, r8' % mn, 'vst.l v2, (r3)+'], fa, None, None,
                  [M32 if pr(b2f(x), 2.5) else 0 for x in fa], 'f', 4, extra=['movq\t=0x%x, r8' % f2b(2.5)]))
    k = newtest(mn)
    add(lane_test('%s.f by the immediate -1 (the value -1.0)' % mn, k, 4, ['vld.f v0, (r1)+', '%s.f v2, v0, #-1' % mn, 'vst.l v2, (r3)+'], fa, None, None,
                  [M32 if pr(b2f(x), -1.0) else 0 for x in fa], 'f', 4))

# ---- vbsl vD, vM, vA, vB: (M & A) | (~M & B) bit by bit, vD the same register as the mask, as A, as B, or another; random bits (not a lane mask)
ma = rnd(32); aa = rnd(32); ab = rnd(32)
sel = lambda m, x, y: (m & x) | (~m & y) & M32
for dst, title in (('v3', 'vD another register'), ('v0', 'vD = vM'), ('v1', 'vD = vA'), ('v2', 'vD = vB')):
    k = newtest('vbsl')
    add(lane_test('vbsl, random bits, %s' % title, k, 4, ['vld.l v0, (r1)+', 'vld.l v1, (r2)+', 'vld.l v2, (r7)+', 'vbsl %s, v0, v1, v2' % dst, 'vst.l %s, (r3)+' % dst], ma, aa, ab,
                  [sel(m, x, y) & M32 for m, x, y in zip(ma, aa, ab)], 'l', 4))
# a byte mask from a compare selects bytes (the maximum of unsigned bytes: the select of vcgtu), and the block has strips of 32, 32 and 13
ba = rnd(8); bb = rnd(8)
for i in range(0, N, 4):
    bb[i] = ba[i]
k = newtest('vbsl')
add(lane_test('vcgtu.b and vbsl: the unsigned maximum of bytes', k, 1, ['vld.b v0, (r1)+', 'vld.b v1, (r2)+', 'vcgtu.b v2, v0, v1', 'vbsl v3, v2, v0, v1', 'vst.b v3, (r3)+'], ba, bb, None,
              [max(x, y) for x, y in zip(ba, bb)], 'b', 1))
# the clamp x > 100 ? 100 : x on signed words (the immediate form of the compare, a broadcast constant, the select)
wa = corners(rnd(16), 16, [100, 101, 99, -32768, 32767, 0xffff, 0x8000])
k = newtest('vbsl')
add(lane_test('clamp: vcgt.w by an immediate, vmov.w constant, vbsl', k, 2, ['vld.w v0, (r1)+', 'vcgt.w v1, v0, #100', 'vmov.w v2, #100', 'vbsl v3, v1, v2, v0', 'vst.w v3, (r3)+'], wa, None, None,
              [ux(min(sx(x, 16), 100), 16) for x in wa], 'w', 2))
# relu on binary32 (a NaN gives 0.0: the compare is false): x > 0 ? x : 0
pool2 = [0.0, -0.0, 1.0, -1.0, float('nan'), float('inf'), float('-inf'), 3.5, -3.5, 1e-45, -1e-45]
fr = [f2b(rng.choice(pool2)) for _ in range(N)]
k = newtest('vbsl')
add(lane_test('relu on floats: vcgt.f by an immediate 0, vbsl with 0.0 (NaN and -0.0 give +0.0)', k, 4, ['vld.f v0, (r1)+', 'vcgt.f v1, v0, #0', 'vmov.f v2, #0', 'vbsl v3, v1, v0, v2', 'vst.f v3, (r3)+'], fr, None, None,
              [f2b(b2f(x)) if b2f(x) > 0 else 0 for x in fr], 'f', 4))

# ---- vcvt.l.f and vcvt.lu.f: int32 to binary32, round to nearest even (2^24 + 1 is not representable and rounds to 2^24; 2^24 + 3 is a tie that goes to 2^24 + 4)
ia = corners(rnd(32), 32, [0, 1, -1, 1 << 24, (1 << 24) + 1, (1 << 24) + 2, (1 << 24) + 3, -((1 << 24) + 1), -((1 << 24) + 3), (1 << 31) - 1, 1 << 31, 0x7fffff80, 0x7fffffc0, 0xffffffff, 0xffffff7f, 0x80000001, 123456789])
for mn, lane_f, conv in (('vcvt.l.f', 'signed', lambda v: sx(v, 32)), ('vcvt.lu.f', 'unsigned', lambda v: ux(v, 32))):
    k = newtest(mn)
    add(lane_test('%s: %s int32 to binary32, round to nearest even' % (mn, lane_f), k, 4, ['vld.l v0, (r1)+', '%s v1, v0' % mn, 'vst.f v1, (r3)+'], ia, None, None, [f2b(float(conv(x))) for x in ia], 'l', 4))

# ---- vcvt.f.l and vcvt.f.lu: binary32 to int32 as the scalar FCVTSL does it (truncate toward zero, then saturate, a NaN gives the largest value); the unsigned form:
# a negative value gives 0, a NaN or 2^32 or more gives 0xffffffff
fv = [0.5, -0.5, 1.9, -1.9, 2147483648.0, -2147483648.0, 2147483520.0, -2147483904.0, 3.0e9, -3.0e9, float('nan'), float('-nan'), float('inf'), float('-inf'), -0.0, 16777216.0,
      8388608.5, 1e-45, 0.0, 4294967296.0, 4294967040.0, 4294967808.0, -1.0, -0.99999994, 1.0, 2.0e9, 4.0e9, 3.99e9]
fx = [f2b(v) for v in fv] + [rng.getrandbits(32) for _ in range(N - len(fv))]
fx[40] = 0x7fc00001; fx[41] = 0xffc00000; fx[42] = 0x7f800001      # NaNs with payloads, and a signalling NaN


def to_sint(x):
    if isnan(x) or x >= 2147483648.0:
        return 0x7fffffff
    if x < -2147483648.0:
        return 0x80000000
    return ux(int(x), 32)


def to_uint(x):
    if isnan(x) or x >= 4294967296.0:
        return M32
    if x <= -1.0:
        return 0
    return int(x)


for mn, f in (('vcvt.f.l', to_sint), ('vcvt.f.lu', to_uint)):
    k = newtest(mn)
    add(lane_test('%s: binary32 to int32, truncate toward zero and saturate, NaN gives the largest value' % mn, k, 4, ['vld.f v0, (r1)+', '%s v1, v0' % mn, 'vst.l v1, (r3)+'], fx, None, None,
                  [f(b2f(x)) for x in fx], 'f', 4))

# the quantise step of an LLM loop: x (int32) to float, clamp to 1000.0 with a compare and a select, back to int32 (truncated)
qa = corners(rnd(32), 32, [999, 1000, 1001, -5, (1 << 24) + 1, (1 << 31) - 1, 1 << 31, 0xffffffff, 0])
qa = [x if i % 2 else ux(sx(x, 32) // 4096, 32) for i, x in enumerate(qa)]       # keep a good share of the values near the clamp
want = []
for x in qa:
    f = b2f(f2b(float(sx(x, 32))))
    g = 1000.0 if f > 1000.0 else f
    want.append(ux(int(g), 32))
k = newtest('vcvt')
add(lane_test('int32 to float, clamp to 1000.0 (vcgt.f, vbsl), back to int32', k, 4, ['vld.l v0, (r1)+', 'vcvt.l.f v1, v0', 'vcgt.f v2, v1, #1000', 'vmov.f v3, #1000', 'vbsl v4, v2, v3, v1',
              'vcvt.f.l v5, v4', 'vst.l v5, (r3)+'], qa, None, None, want, 'l', 4))

# ---- write the program
out = ['; GENERATED by tests/sim/gen_vec_wave2.py -- do not edit.  Wave 2 of the vec family (errata 171): vceq, vcgt, vcgtu (b w l f), vbsl, vcvt.l.f, vcvt.lu.f, vcvt.f.l, vcvt.f.lu,',
       '; each over 77 elements (the last strip short) against the expected values of an independent model (docs/encoding-work/vec-isa.md, "wave 2"); a failed test n exits with n.',
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
open(sys.argv[1], 'w').write('\n'.join(out) + '\n')
print('%d tests' % cnt[0])
