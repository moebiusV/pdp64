#!/usr/bin/env python3
"""Generate tests/sim/vec-wave1.s: every word of wave 1 of the vec family (errata 170: vavg, vmulh, vmulhr, vsarr, vshrr, vdot.w, vsad.bu, vdacc, vtbl.b, the rounding
shift of vsts, vmla vector by vector) run over 77 elements (a trip count that is not a multiple of the strip: strips of 32 bytes, 16 words, 8 long words, 4 quad words, so the
last strip is short) against the expected values of an independent model written here (the semantics of docs/encoding-work/vec-isa.md, section "wave 1", worked out
in Python integers, not by the simulator).  The inputs come from a fixed seed, with the corner values put in by hand (the Q15 case -32768 x -32768, the extremes of
each lane, saturation, a shift of the width of the lane).  The result of a test is compared byte for byte (or register for register); a failed test n exits with n.
usage: gen_vec_wave1.py OUT.s"""
import sys as _sys, os as _os
_sys.path.insert(0, _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), '..', '..', 'tools'))
import marks		# the words of the encoding written with the width suffixes (tools/marks.py)
import random, sys

N = 77
rng = random.Random(170)
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
    out_l = ['\tmovq\t$%d, r9' % k]
    have = {l for l, _ in data}
    out_l += lines_ptr(k, [x for x in list(loads) + [out] if x[0] + str(k) in have])
    out_l += list(extra)
    out_l += ['\tlea\tA%d+%d, r5' % (k, nbytes_a), '\tvec\tr1, r5'] + ['\t' + b for b in body] + ['\tvend']
    return out_l


def compare(k, nbytes):
    return ['\tlea\tO%d, r1' % k, '\tlea\tE%d, r2' % k, '\tmovq\t$%d, r4' % nbytes, 'c%d:' % k, '\tmovzb\t(r1)+, r5', '\tmovzb\t(r2)+, r6',
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


# ---- vavg, vavgu: (a + b + 1) >> 1, the sum in a wider type
for mn, lane, signed in (('vavg', 'b', 1), ('vavgu', 'b', 0), ('vavg', 'w', 1), ('vavgu', 'w', 0)):
    bits = 8 * LB[lane]
    a = rnd(bits); b = rnd(bits)
    lim = [(1 << (bits - 1)) - 1, 1 << (bits - 1), (1 << bits) - 1, 0, 1, (1 << bits) - 1]
    a = corners(a, bits, lim); b = corners(b, bits, [(1 << (bits - 1)) - 1, 1 << (bits - 1), (1 << bits) - 1, 0, 0, (1 << bits) - 2])
    f = (lambda v: sx(v, bits)) if signed else (lambda v: v)
    want = [(f(x) + f(y) + 1) >> 1 for x, y in zip(a, b)]
    k = newtest(mn)
    m = lane if signed else lane + 'u'
    add(lane_test('%s.%s' % (mn, lane), k, LB[lane], ['vld.%s v0, (r1)+' % m, 'vld.%s v1, (r2)+' % m, '%s.%s v2, v0, v1' % (mn, lane), 'vst.%s v2, (r3)+' % lane], a, b, None, want, m, LB[lane]))

# ---- vmulh, vmulhu, vmulhr (.w), the vector, register and immediate forms
a = corners(rnd(16), 16, [-32768, -32768, 32767, 32767, 0xffff, -32768, 1, 0x4000, -1])
b = corners(rnd(16), 16, [-32768, 32767, 32767, -32768, 0xffff, 1, -32768, 0x4000, -1])
for mn in ('vmulh', 'vmulhu', 'vmulhr'):
    if mn == 'vmulhu':
        f = lambda v: ux(v, 16)
        want = [ux((f(x) * f(y)) >> 16, 16) for x, y in zip(a, b)]
        m = 'wu'
    elif mn == 'vmulh':
        f = lambda v: sx(v, 16)
        want = [ux((f(x) * f(y)) >> 16, 16) for x, y in zip(a, b)]
        m = 'w'
    else:
        f = lambda v: sx(v, 16)
        want = [ux(min((f(x) * f(y) + 0x4000) >> 15, 32767), 16) for x, y in zip(a, b)]
        m = 'w'
    k = newtest(mn)
    add(lane_test('%s.w vector by vector' % mn, k, 2, ['vld.%s v0, (r1)+' % m, 'vld.%s v1, (r2)+' % m, '%s.w v2, v0, v1' % mn, 'vst.w v2, (r3)+'], a, b, None, want, m, 2))
    for form, val, setup, opnd in (('register', 23168, ['movq\t$23168, r8'], 'r8'), ('register', -32768, ['movq\t$-32768, r8'], 'r8'), ('immediate', -32768, [], '$-32768'), ('immediate', 2896, [], '$2896')):
        if mn == 'vmulhu':
            want = [ux((f(x) * ux(val, 16)) >> 16, 16) for x in a]
        elif mn == 'vmulh':
            want = [ux((f(x) * sx(val, 16)) >> 16, 16) for x in a]
        else:
            want = [ux(min((f(x) * sx(val, 16) + 0x4000) >> 15, 32767), 16) for x in a]
        k = newtest(mn)
        add(lane_test('%s.w by a %s %d' % (mn, form, val), k, 2, ['vld.%s v0, (r1)+' % m, '%s.w v2, v0, %s' % (mn, opnd), 'vst.w v2, (r3)+'], a, None, None, want, m, 2, extra=setup))

# ---- vsarr, vshrr: round half up, exact, a count above the width gives 0
for mn, lane, counts, imm in (('vsarr', 'w', [0, 1, 3, 15, 16, 17], 5), ('vshrr', 'w', [0, 1, 3, 15, 16, 17], 5), ('vsarr', 'l', [0, 1, 13, 31, 32, 33], 13), ('vshrr', 'l', [0, 1, 13, 31, 32, 33], 13)):
    bits = 8 * LB[lane]
    a = corners(rnd(bits), bits, [(1 << (bits - 1)) - 1, 1 << (bits - 1), (1 << bits) - 1, 1 << (bits - 2), 0, 1, (1 << (bits - 1)) - 2])
    signed = mn == 'vsarr'

    def model(x, c):
        x = sx(x, bits) if signed else ux(x, bits)
        if c == 0:
            return ux(x, bits)
        if c > bits:
            return 0
        return ux((x + (1 << (c - 1))) >> c, bits)
    m = lane if signed else lane + 'u'
    for c in counts:
        k = newtest(mn)
        add(lane_test('%s.%s by %d (a register)' % (mn, lane, c), k, LB[lane], ['vld.%s v0, (r1)+' % m, '%s.%s v1, v0, r10' % (mn, lane), 'vst.%s v1, (r3)+' % lane], a, None, None, [model(x, c) for x in a], m, LB[lane], extra=['movq\t$%d, r10' % c]))
    k = newtest(mn)
    add(lane_test('%s.%s by the immediate %d' % (mn, lane, imm), k, LB[lane], ['vld.%s v0, (r1)+' % m, '%s.%s v1, v0, $%d' % (mn, lane, imm), 'vst.%s v1, (r3)+' % lane], a, None, None, [model(x, imm) for x in a], m, LB[lane]))
    k = newtest(mn)
    bvec = [c % (bits + 3) for c in rnd(8)]
    sh = [rng.randrange(0, bits + 3) for _ in range(N)]
    add(lane_test('%s.%s, a count in every lane (vector by vector)' % (mn, lane), k, LB[lane], ['vld.%s v0, (r1)+' % m, 'vld.%s v2, (r2)+' % m, '%s.%s v1, v0, v2' % (mn, lane), 'vst.%s v1, (r3)+' % lane], a, sh, None, [model(x, c) for x, c in zip(a, sh)], m, LB[lane]))

# ---- vmla vector by vector (and by a register: the old form)
for lane in ('w', 'l'):
    bits = 8 * LB[lane]
    a = rnd(bits); b = rnd(bits); c = rnd(bits)
    a[0] = b[0] = 1 << (bits - 1); a[1] = (1 << bits) - 1; b[1] = (1 << bits) - 1
    k = newtest('vmla')
    add(lane_test('vmla.%s vD, vA, vB (D += A * B)' % lane, k, LB[lane], ['vld.%s v2, (r7)+' % lane, 'vld.%s v0, (r1)+' % lane, 'vld.%s v1, (r2)+' % lane, 'vmla.%s v2, v0, v1' % lane, 'vst.%s v2, (r3)+' % lane], a, b, c, [ux(z + sx(x, bits) * sx(y, bits), bits) for x, y, z in zip(a, b, c)], lane, LB[lane]))
    k = newtest('vmla')
    add(lane_test('vmla.%s vD, vA, Rs (the form that was already there)' % lane, k, LB[lane], ['vld.%s v2, (r7)+' % lane, 'vld.%s v0, (r1)+' % lane, 'vmla.%s v2, v0, r8' % lane, 'vst.%s v2, (r3)+' % lane], a, None, c, [ux(z + sx(x, bits) * 12345, bits) for x, z in zip(a, c)], lane, LB[lane], extra=['movq\t$12345, r8']))

# ---- vdot.w, reduced by vacc.l.q (the sum of the 32-bit lanes, widened): the pairs of 16-bit products
a = rnd(16); b = rnd(16)
a[0] = b[0] = a[1] = b[1] = 0x8000          # -32768 x -32768 twice in one lane: 2^31 wraps to -2^31
pairs = [(sx(a[i], 16) * sx(b[i], 16) + (sx(a[i + 1], 16) * sx(b[i + 1], 16) if i + 1 < N else 0)) for i in range(0, N, 2)]
want = 1000 + sum(sx(p, 32) for p in pairs)
k = newtest('vdot.w')
buf('A%d' % k, pack(a, 2)); buf('B%d' % k, pack(b, 2))
add([';; test %d: vdot.w, 77 words (an odd tail: the last lane has one product), the lanes summed by vacc.l.q; the lane of the first two pairs wraps (-32768 x -32768 twice)' % k] +
    block(k, N * 2, ['vld.w v0, (r1)+', 'vld.w v1, (r2)+', 'vdot.w v2, v0, v1', 'vacc.l.q r10, v2'], [('A', 'r1'), ('B', 'r2')], ('O', 'r3'), ['movq\t$1000, r10']) + cmpreg('r10', want))
# the corner on its own: 16 words of -32768: vdot.w lanes wrap, vdacc.w does not
k = newtest('vdot.w corner')
buf('A%d' % k, pack([0x8000] * 16, 2))
add([';; test %d: 16 words of -32768 squared: vdot.w wraps every lane (8 x -2^31 = -2^34), vdacc.w is exact (+2^34)' % k] +
    block(k, 32, ['vld.w v0, (r1)+', 'vdot.w v2, v0, v0', 'vacc.l.q r10, v2'], [('A', 'r1')], ('O', 'r3'), ['movq\t$0, r10']) + cmpreg('r10', -(1 << 34)) +
    ['\tlea\tA%d, r1' % k, '\tlea\tA%d+32, r5' % k, '\tmovq\t$0, r10', '\tvec\tr1, r5', '\tvld.w v0, (r1)+', '\tvdacc.w r10, v0, v0', '\tvend'] + cmpreg('r10', 1 << 34))

# ---- vsad.bu: the sum of absolute differences of unsigned bytes, added to the register
a = corners(rnd(8), 8, [255, 0, 255, 0, 128]); b = corners(rnd(8), 8, [0, 255, 255, 0, 127])
k = newtest('vsad.bu')
buf('A%d' % k, pack(a, 1)); buf('B%d' % k, pack(b, 1))
add([';; test %d: vsad.bu over 77 bytes (strips of 32, 32, 13), added to a register that starts at 1000' % k] +
    block(k, N, ['vld.bu v0, (r1)+', 'vld.bu v1, (r2)+', 'vsad.bu r10, v0, v1'], [('A', 'r1'), ('B', 'r2')], ('O', 'r3'), ['movq\t$1000, r10']) + cmpreg('r10', 1000 + sum(abs(x - y) for x, y in zip(a, b))))

# ---- vdacc.b .bu .bsu .w: the exact sum of the products, added to the register
for mn, sa, sb, lane, ma, mb in (('vdacc.b', 1, 1, 'b', 'b', 'b'), ('vdacc.bu', 0, 0, 'b', 'bu', 'bu'), ('vdacc.bsu', 1, 0, 'b', 'b', 'bu'), ('vdacc.w', 1, 1, 'w', 'w', 'w')):
    bits = 8 * LB[lane]
    a = corners(rnd(bits), bits, [1 << (bits - 1), (1 << (bits - 1)) - 1, (1 << bits) - 1, 1 << (bits - 1), 0])
    b = corners(rnd(bits), bits, [1 << (bits - 1), (1 << (bits - 1)) - 1, (1 << bits) - 1, (1 << bits) - 1, 5])
    fa = (lambda v: sx(v, bits)) if sa else (lambda v: ux(v, bits))
    fb = (lambda v: sx(v, bits)) if sb else (lambda v: ux(v, bits))
    want = -5 + sum(fa(x) * fb(y) for x, y in zip(a, b))
    k = newtest(mn)
    buf('A%d' % k, pack(a, LB[lane])); buf('B%d' % k, pack(b, LB[lane]))
    add([';; test %d: %s over 77 elements, added to a register that starts at -5' % (k, mn)] +
        block(k, N * LB[lane], ['vld.%s v0, (r1)+' % ma, 'vld.%s v1, (r2)+' % mb, '%s r10, v0, v1' % mn], [('A', 'r1'), ('B', 'r2')], ('O', 'r3'), ['movq\t$-5, r10']) + cmpreg('r10', want))

# ---- vtbl.b: the memory form (16 bytes at (Ra)); the register form was removed in errata 173 (its table was the lanes of a register, so the strip)
idx = [rng.getrandbits(5) for _ in range(N)]
idx[3] = 0x85; idx[40] = 0xff; idx[41] = 16; idx[42] = 15; idx[43] = 0; idx[70] = 12; idx[71] = 13
tab = rnd(8, 32)
k = newtest('vtbl.b (memory)')
want = [tab[i] if i < 16 else 0 for i in idx]
buf('A%d' % k, pack(idx, 1)); buf('T%d' % k, pack(tab[:16], 1)); buf('E%d' % k, pack(want, 1)); buf('O%d' % k, bytes(N))
add([';; test %d: vtbl.b vD, (Ra), vI: the table is exactly 16 bytes at (Ra), the same for every lane and every strip, also in the strip of 13' % k] +
    block(k, N, ['vld.bu v0, (r1)+', 'vtbl.b v2, (r6), v0', 'vst.b v2, (r3)+'], [('A', 'r1'), ('T', 'r6')], ('O', 'r3')) + compare(k, N))

# ---- the rounding shift of the narrowing store
for lane, m, sh in (('w', 'b', 4), ('w', 'bu', 1), ('w', 'b', 0), ('l', 'w', 15), ('l', 'wu', 3), ('l', 'bu', 8), ('l', 'b', 0), ('q', 'l', 40), ('q', 'w', 1)):
    bits = 8 * LB[lane]
    a = corners(rnd(bits), bits, [(1 << (bits - 1)) - 1, 1 << (bits - 1), (1 << bits) - 1, 1 << (bits - 3), 8, 7, 9, ux(-9, bits), ux(-8, bits), ux(-7, bits)])
    msz = LB[m[0]]
    mb = 8 * msz
    if m.endswith('u'):
        lo, hi = 0, (1 << mb) - 1
    else:
        lo, hi = -(1 << (mb - 1)), (1 << (mb - 1)) - 1
    want = []
    for x in a:
        x = sx(x, bits)
        if sh:
            x = (x + (1 << (sh - 1))) >> sh
        want.append(ux(max(lo, min(hi, x)), mb))
    k = newtest('vsts')
    add(lane_test('vsts.%s.%s with a rounding shift of %d' % (lane, m, sh), k, LB[lane], ['vld.%s v0, (r1)+' % lane, 'vsts.%s.%s v0, (r3)+, $%d' % (lane, m, sh), ], a, None, None, want, lane, msz))

# ---- write the program
out = ['; GENERATED by tests/sim/gen_vec_wave1.py -- do not edit.  Wave 1 of the vec family (errata 170): vavg, vavgu, vmulh, vmulhu, vmulhr, vsarr, vshrr, vmla (vector by vector),',
       '; vdot.w, vsad.bu, vdacc, vtbl.b and the rounding shift of vsts, each over 77 elements (the last strip short) against the expected values of an independent model',
       '; (docs/encoding-work/vec-isa.md, "wave 1"); a failed test n exits with n.', '\t.text', '\t.globl\t_start', '_start:']
out += T
out += ['\tmovq\t$0, r0', '\ttrap\t$0', 'fail:\tmovq\tr9, r0', '\ttrap\t$0', '', '\t.data']
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
