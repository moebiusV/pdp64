#!/usr/bin/env python3
"""Generate tests/sim/fma-negate.s: the fused multiply-add set is FMADD (a*b + c) and FNMSUB (-(a*b) + c); the other two operations are those with an exact negation of the addend.

  a*b - c        is  FMADD(a, b, -c)           (the old FMSUB)
  -(a*b) - c     is  FNMSUB(a, b, -c)          (the old FNMADD; NOT the negation of FMADD: for an exact zero sum the signs differ)

-c is the exact sign flip: `FNEG` for binary64, `XOR $-2147483648` for the sign-extended binary32.  The expected results are computed here from exact rational arithmetic and one rounding
to nearest even (the only rounding the machine has), with the canonical quiet NaN for every NaN result; the expected flags are NV (an invalid operation or a signalling NaN), and NX and OF
for an inexact or overflowing finite result.  Cases that would underflow are left out: the flag is the host's.  A failed check n exits with n.

usage: gen_fma.py OUTDIR"""
import sys as _sys, os as _os
_sys.path.insert(0, _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), '..', '..', 'tools'))
import marks		# the words of the encoding written with the width suffixes (tools/marks.py)
import os, sys, struct
from fractions import Fraction

FMT = {64: dict(p=53, emax=1023, emin=-1022, bits=64), 32: dict(p=24, emax=127, emin=-126, bits=32)}


def fields(w, bits):
    if bits == 64:
        return w >> 63, (w >> 52) & 0x7ff, w & ((1 << 52) - 1)
    return w >> 31, (w >> 23) & 0xff, w & ((1 << 23) - 1)


def classify(w, bits):
    s, e, m = fields(w, bits)
    top = 0x7ff if bits == 64 else 0xff
    if e == top:
        if m == 0: return 'inf'
        qbit = 1 << (51 if bits == 64 else 22)
        return 'qnan' if m & qbit else 'snan'
    return 'finite'


def value(w, bits):
    s, e, m = fields(w, bits)
    p = FMT[bits]['p']
    if e == 0:
        v = Fraction(m, 1 << (p - 1)) * Fraction(2) ** FMT[bits]['emin']
    else:
        v = Fraction((1 << (p - 1)) | m, 1 << (p - 1)) * Fraction(2) ** (e - (1023 if bits == 64 else 127))
    return -v if s else v


def encode(q, bits, negzero=False):
    """round the exact rational q to the format, nearest even; returns (bits, overflow, inexact)"""
    f = FMT[bits]; p = f['p']; emax = f['emax']; emin = f['emin']
    sign = 1 if (q < 0 or (q == 0 and negzero)) else 0
    top = 0x7ff if bits == 64 else 0xff
    if q == 0:
        return sign << (bits - 1), False, False
    a = abs(q)
    e = a.numerator.bit_length() - a.denominator.bit_length()
    if Fraction(2) ** e > a: e -= 1
    if e < emin: e = emin
    scale = Fraction(2) ** (e - (p - 1))
    n = a / scale
    fl = n.numerator // n.denominator
    rem = n - fl
    if rem > Fraction(1, 2) or (rem == Fraction(1, 2) and fl & 1): fl += 1
    inexact = rem != 0
    if fl >= 1 << p:
        fl >>= 1; e += 1
    if e > emax:
        return (sign << (bits - 1)) | (top << (p - 1)), True, True
    if fl < 1 << (p - 1):
        return (sign << (bits - 1)) | fl, False, inexact           # subnormal or zero
    return (sign << (bits - 1)) | ((e + emax) << (p - 1)) | (fl - (1 << (p - 1))), False, inexact


def fma_ref(a, b, c, bits):
    """a*b + c fused, from the bit patterns: (bits, flags)"""
    qnan = 0x7ff8000000000000 if bits == 64 else 0x7fc00000
    ca, cb, cc = classify(a, bits), classify(b, bits), classify(c, bits)
    nv = 16 if 'snan' in (ca, cb, cc) else 0
    if 'snan' in (ca, cb, cc) or 'qnan' in (ca, cb, cc):
        return qnan, nv
    sa, sb, sc = fields(a, bits)[0], fields(b, bits)[0], fields(c, bits)[0]
    if ca == 'inf' or cb == 'inf':
        za = ca == 'finite' and value(a, bits) == 0
        zb = cb == 'finite' and value(b, bits) == 0
        if za or zb: return qnan, 16
        ps = sa ^ sb
        if cc == 'inf' and sc != ps: return qnan, 16
        return (ps << (bits - 1)) | ((0x7ff << 52) if bits == 64 else (0xff << 23)), 0
    if cc == 'inf': return c, 0
    exact = value(a, bits) * value(b, bits) + value(c, bits)
    if exact == 0:
        # exact zero: the sum of two zeros of the same sign keeps the sign; otherwise +0 (to nearest even)
        pz = value(a, bits) * value(b, bits) == 0 and value(c, bits) == 0
        ps = sa ^ sb
        neg = pz and ps == 1 and sc == 1
        if not pz: neg = False
        return encode(Fraction(0), bits, neg)[0], 0
    r, of, nx = encode(exact, bits)
    return r, (4 if of else 0) | (1 if nx else 0)


def f64(x): return struct.unpack('<Q', struct.pack('<d', x))[0]
def f32(x): return struct.unpack('<I', struct.pack('<f', x))[0]


INF64, NINF64 = 0x7ff0000000000000, 0xfff0000000000000
QNAN64, NQNAN64 = 0x7ff8000000000123, 0xfff8000000000456
SNAN64, NSNAN64 = 0x7ff0000000000789, 0xfff0000000000789
INF32, NINF32 = 0x7f800000, 0xff800000
QNAN32, NQNAN32 = 0x7fc00123, 0xffc00456
SNAN32, NSNAN32 = 0x7f800789, 0xff800789


def cases(bits):
    fl = f64 if bits == 64 else f32
    vals = [fl(x) for x in (0.0, -0.0, 1.0, -1.0, 2.0, 3.0, 1.5, 2.5, 3.75, -3.75, 7.5, 0.1, 1e10, 1.0 + 2 ** -20, 3.4e38 if bits == 32 else 1e308)]
    specials = [INF64, NINF64, QNAN64, NQNAN64, SNAN64, NSNAN64] if bits == 64 else [INF32, NINF32, QNAN32, NQNAN32, SNAN32, NSNAN32]
    out = []
    for a in vals[:9]:
        for b in (vals[0], vals[1], vals[2], vals[3], vals[6]):
            for c in vals[:11]:
                out.append((a, b, c))
    # exact cancellation, in both senses
    for t in ((1.5, 2.5, 3.75), (1.5, 2.5, -3.75), (-1.5, 2.5, 3.75), (1.5, -2.5, -3.75)):
        out.append(tuple(fl(x) for x in t))
    # overflow and inexact results
    big = 3.0e38 if bits == 32 else 1e308
    for t in ((big, 10.0, 1.0), (big, 10.0, -1.0), (big, -10.0, 1.0), (0.1, 0.3, 0.7), (1e10, 1e10, 1.0)):
        out.append(tuple(fl(x) for x in t))
    # the fused rounding: (1+2^-20)^2 - (1+2^-19) is exact only when fused
    x = fl(1.0 + 2 ** -20); y = fl(-(1.0 + 2 ** -19)) if bits == 32 else fl(-(1.0 + 2 ** -19))
    out.append((x, x, y))
    out.append((x, x, fl(1.0 + 2 ** -19)))
    # NaNs and infinities in every place
    one, two, zero = fl(1.0), fl(2.0), fl(0.0)
    for s in specials:
        out += [(s, two, one), (two, s, one), (two, one, s), (s, zero, one), (zero, s, one), (s, one, s)]
    for s in specials[:2]:
        for t in specials[:2]:
            out += [(s, one, t), (s, zero, t), (one, one, t)]
    return out


class Out:
    def __init__(self): self.l = []; self.n = 0
    def a(self, *ls): self.l += ['\t' + x if not x.endswith(':') else x for x in ls]
    def chk_reg(self, reg, want, tmp='r6'):
        self.n += 1
        self.a('movq\t=0x%x, %s' % (want, tmp), 'cbne\t%s, %s, fail%d' % (reg, tmp, self.n))


def gen():
    o = Out()
    o.l = ['; GENERATED by tests/sim/gen_fma.py -- do not edit.  a*b - c is FMADD with an exact negation of c, and -(a*b) - c is FNMSUB with one: the results and the flags are those of',
           '; the single rounding of the exact value (tests/sim/gen_fma.py).  FNEG is the exact negation of a binary64, `xor $-2147483648` of a binary32 (sign-extended in the register).  A failed check n exits with n.',
           '\t.text', '\t.globl\t_start', '_start:']
    nc = 0
    for bits in (64, 32):
        mask = 1 << (bits - 1)
        for a, b, c in cases(bits):
            nc += 1
            def reg(w):
                if bits == 32 and w & 0x80000000: return w | 0xffffffff00000000
                return w
            negc = c ^ mask
            nega = a ^ mask
            for kind in ('fmsub', 'fnmadd'):
                # fmadd(a, b, -c) = fma(a, b, -c); fnmsub(a, b, -c) = -(a*b) - c = fma(-a, b, -c)
                if kind == 'fmsub':
                    want, flags = fma_ref(a, b, negc, bits); inst = 'fmadd' if bits == 64 else 'fmadd32'
                else:
                    want, flags = fma_ref(nega, b, negc, bits); inst = 'fnmsub' if bits == 64 else 'fnmsub32'
                if bits == 32 and want & 0x80000000: want |= 0xffffffff00000000
                o.a('movq\t=0x%x, r1' % reg(a), 'movq\t=0x%x, r2' % reg(b), 'movq\t=0x%x, r3' % reg(c))
                o.a(('fneg\tr3, r4' if bits == 64 else 'movq\tr3, r4\n\txor\t$-2147483648, r4'))
                o.a('movq\t$0, r9', 'fsflags\tr9, r8')
                o.a('%s\tr1, r2, r4, r5' % inst)
                o.a('fsflags\tr9, r8')
                o.chk_reg('r5', want)
                o.chk_reg('r8', flags)
    o.a('clr\tr0', 'trap\t$0')
    for i in range(1, o.n + 1):
        o.l.append('fail%d:\tmovq\t$%d, r0' % (i, (i - 1) % 255 + 1))
        o.a('trap\t$0')
    return '\n'.join(o.l) + '\n'


if __name__ == '__main__':
    d = sys.argv[1]
    open(os.path.join(d, 'fma-negate.s'), 'w').write(marks.spell_text(gen()))
    print('gen_fma: fma-negate.s')
