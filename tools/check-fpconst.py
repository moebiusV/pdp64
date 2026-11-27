#!/usr/bin/env python3
"""The floating-point constants f16(x), f32(x), f64(x) of as64 against an exact reference (Python's Fraction: no floating point is used to decide anything).
Random decimals, and the hard cases: every middle of two neighbours (exactly, and a hair above and below it), the values around the largest number, the denormals, the double-rounding cases.
Usage: tools/check-fpconst.py [as64]; exit 0 if every constant has the reference bits."""
import os, random, struct, subprocess, sys, tempfile
from fractions import Fraction as F

AS = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), '..', 'build', 'as64')
FMT = {16: (11, -14, 15), 32: (24, -126, 127), 64: (53, -1022, 1023)}   # precision, emin, emax

def ref(w, x):
    """x a positive Fraction: the bits of its nearest-even rounding, or None if it overflows or rounds to zero"""
    p, emin, emax = FMT[w]
    if x == 0: return None
    e = max(x.numerator.bit_length() - x.denominator.bit_length() - 1, emin)
    while F(2) ** (e + 1) <= x: e += 1
    while F(2) ** e > x and e > emin: e -= 1
    q = x / F(2) ** (e - (p - 1))                       # in units of the last place
    n = q.numerator // q.denominator
    r = q - n
    if r > F(1, 2) or (r == F(1, 2) and n & 1): n += 1
    if n == 0: return None
    if n >= 2 ** p: e += 1; n >>= 1
    if e > emax: return None
    eb = {16: 5, 32: 8, 64: 11}[w]
    if n < 2 ** (p - 1): return n                      # denormal
    return ((e + (1 << (eb - 1)) - 1) << (p - 1)) | (n - 2 ** (p - 1))

def dec(x, digits=60):
    """a decimal string of a positive Fraction (exact when it terminates, else cut at `digits` significant digits)"""
    e = 0
    y = x
    while y >= 10: y /= 10; e += 1
    while y < 1: y *= 10; e -= 1
    s = ''
    for i in range(digits):
        d = y.numerator // y.denominator
        s += str(d); y = (y - d) * 10
        if y == 0: break
    return '%s.%se%d' % (s[0], s[1:] or '0', e)

random.seed(64)
cases = []
for w in (16, 32, 64):
    p, emin, emax = FMT[w]
    mk = lambda e, n: F(n) * F(2) ** (e - (p - 1))
    pts = []
    for e in list(range(emin - 2, emin + 3)) + [emax - 1, emax] + [random.randint(emin, emax) for _ in range(120)]:
        for n in [2 ** (p - 1), 2 ** (p - 1) + 1, 2 ** p - 1] + [random.randint(2 ** (p - 1), 2 ** p - 1) for _ in range(4)]:
            v = mk(e, n)
            mid = v + F(1, 2) * F(2) ** (max(e, emin) - (p - 1)) if True else v
            for t in (mid, mid * (1 + F(1, 10 ** 25)), mid * (1 - F(1, 10 ** 25)), v):
                pts.append(t)
    for k in range(1, 40): pts.append(F(2) ** (emin - (p - 1)) * F(k, 2))     # denormals and the middles among them
    pts += [F(2) ** (emax + 1) * (1 - F(1, 2 ** p)), F(2) ** (emax + 1) * (1 - F(1, 2 ** p)) * (1 + F(1, 10 ** 30))]
    for t in pts:
        if t > 0: cases.append((w, dec(t)))
    for _ in range(300):
        cases.append((w, '%d.%0*de%d' % (random.randint(0, 99), random.randint(1, 20), random.randint(0, 10 ** 15), random.randint(-50, 40) if w != 16 else random.randint(-9, 5))))
cases.append((32, '1.00000017881393432617187499')); cases.append((32, '1.000000178813934326171875')); cases.append((32, '1.00000017881393432617187501'))
cases.append((16, '65519.99999999999999999')); cases.append((16, '65520')); cases.append((16, '2.98023223876953125e-8')); cases.append((16, '2.98023223876953126e-8'))

def num(s):
    m, _, e = s.partition('e')
    ip, _, fp = m.partition('.')
    return F(int(ip + fp)) * F(10) ** (int(e or 0) - len(fp))

src = []; want = []
for w, s in cases:
    r = ref(w, num(s))
    src.append('\t%s f%d(%s)' % ({16: '.word', 32: '.long', 64: '.quad'}[w], w, s))
    want.append((w, s, r))
# the refused ones are assembled one at a time; the accepted ones all together
good = [(i, c) for i, c in enumerate(want) if c[2] is not None]
bad = [c for c in want if c[2] is None]
with tempfile.TemporaryDirectory() as d:
    open(d + '/g.s', 'w').write('\n'.join(src[i] for i, _ in good) + '\n')
    r = subprocess.run([AS, '--no-relax', '-o', d + '/g.o', d + '/g.s'], capture_output=True, text=True)
    if r.returncode: print(r.stderr); sys.exit(1)
    o = open(d + '/g.o', 'rb').read()
    sh = struct.unpack_from('<Q', o, 0x28)[0]
    off, size = struct.unpack_from('<QQ', o, sh + 64 + 24)
    t = o[off:off + size]
    pos = 0; nbad = 0
    for _, (w, s, rb) in good:
        b = w // 8
        got = int.from_bytes(t[pos:pos + b], 'little'); pos += b
        if got != rb: nbad += 1; print('DIFF f%d(%s): got %x want %x' % (w, s, got, rb))
    # a refused one is a line of its own
    nref = 0
    for w, s, _ in bad:
        open(d + '/b.s', 'w').write('\t.quad f%d(%s)\n' % (w, s))
        r = subprocess.run([AS, '--no-relax', '-o', d + '/b.o', d + '/b.s'], capture_output=True, text=True)
        if r.returncode == 0: nbad += 1; print('ACCEPTED f%d(%s), want a refusal' % (w, s))
        nref += 1
print('check-fpconst: %d constants with the exact bits, %d refusals as the reference says, %d wrong' % (len(good), nref, nbad))
sys.exit(1 if nbad else 0)
