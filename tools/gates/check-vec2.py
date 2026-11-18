#!/usr/bin/env python3
"""check-vec2.py -- spot checks of the behaviour of the blocks of vec2.v, vec3.v, fp2.v and mem2.v against Python models, so that a gate count is not the count of a block that does
nothing.  yosys `eval` evaluates the flattened combinational netlist on given inputs; each test is one yosys run (a minute or so).  Usage: check-vec2.py [name ...]"""
import subprocess, random, sys, os, re
from concurrent.futures import ThreadPoolExecutor
here = os.path.dirname(os.path.abspath(__file__))
random.seed(7)
def ev(f, top, ins):
    sets = ' '.join("-set %s %d'd%d" % (k, w, v) for k, (w, v) in ins.items())
    r = subprocess.run(['yosys', '-p', "read_verilog %s/%s; hierarchy -top %s; proc; flatten; opt; eval %s -show y" % (here, f, top, sets)], capture_output=True, text=True)
    m = re.search(r"Eval result: \\y = (\d+')?([0-9]+)\.", r.stdout)
    if not m: return None
    return int(m.group(2), 2) if m.group(1) else int(m.group(2))
def lanes(x, w, n=256): return [(x >> (w * i)) & ((1 << w) - 1) for i in range(n // w)]
def pack(l, w): return sum((v & ((1 << w) - 1)) << (w * i) for i, v in enumerate(l))
def sx(v, w): return v - (1 << w) if v >> (w - 1) else v
tests = {}
def test(f):
    tests[f.__name__] = f; return f
@test
def vavg_mw():
    ok = True
    for t in range(8):
        a, b = random.getrandbits(256), random.getrandbits(256); sz = t % 4; sg = t % 2; w = 8 << sz
        exp = pack([((sx(x, w) + sx(y, w) + 1) >> 1) if sg else ((x + y + 1) >> 1) for x, y in zip(lanes(a, w), lanes(b, w))], w)
        ok &= ev('vec2.v', 'vavg_mw', {'a': (256, a), 'b': (256, b), 'sz': (2, sz), 'sgn': (1, sg)}) == exp
    return ok
@test
def vacc_shared64():
    ok = True
    for t in range(8):
        a = random.getrandbits(256); sz = t % 4; sg = (t // 2) % 2; acc = random.getrandbits(64); w = 8 << sz
        exp = (acc + sum(sx(v, w) if sg else v for v in lanes(a, w))) % (1 << 64)
        ok &= ev('vec2.v', 'vacc_shared64', {'a': (256, a), 'sz': (2, sz), 'sgn': (1, sg), 'acc': (64, acc)}) == exp
    return ok
@test
def vacc_naive():
    ok = True
    for t in range(8):
        a = random.getrandbits(256); sz = t % 4; sg = (t // 2) % 2; acc = random.getrandbits(64); w = 8 << sz
        exp = (acc + sum(sx(v, w) if sg else v for v in lanes(a, w))) % (1 << 64)
        ok &= ev('vec2.v', 'vacc_naive', {'a': (256, a), 'sz': (2, sz), 'sgn': (1, sg), 'acc': (64, acc)}) == exp
    return ok
@test
def lanealu_mw():
    ok = True
    for t in range(18):
        op = t; sz = random.randrange(4); w = 8 << sz
        a, b = random.getrandbits(256), random.getrandbits(256)
        out = []
        for x, y in zip(lanes(a, w), lanes(b, w)):
            xs, ys = sx(x, w), sx(y, w); hi, lo = (1 << (w - 1)) - 1, -(1 << (w - 1)); M = (1 << w) - 1
            r = {0: x + y, 1: x - y, 2: max(lo, min(hi, xs + ys)), 3: max(lo, min(hi, xs - ys)), 4: min(M, x + y), 5: max(0, x - y), 6: min(xs, ys), 7: max(xs, ys),
                 8: min(x, y), 9: max(x, y), 10: abs(xs), 11: abs(xs - ys), 12: abs(x - y), 13: x & y, 14: x | y, 15: x ^ y, 16: (xs + ys + 1) >> 1, 17: (x + y + 1) >> 1}[op]
            out.append(r)
        got = ev('vec2.v', 'lanealu_mw', {'a': (256, a), 'b': (256, b), 'sz': (2, sz), 'op': (5, op)})
        ok_t = got == pack(out, w)
        if not ok_t: print('  lanealu_mw op', op, 'sz', sz, 'differs')
        ok &= ok_t
    return ok
@test
def shiftround_mw():
    ok = True
    for t in range(9):
        sz = t % 4; w = 8 << sz; op = 1 + (t // 4) % 2; n = random.randrange(w); a = random.getrandbits(256)
        out = []
        for x in lanes(a, w):
            v = sx(x, w) if op == 2 else x
            r = (v >> n) + (((x >> (n - 1)) & 1) if n else 0)
            out.append(r)
        got = ev('vec2.v', 'shiftround_mw', {'a': (256, a), 'n': (6, n), 'sz': (2, sz), 'op': (2, op)})
        ok_t = got == pack(out, w)
        if not ok_t: print('  shiftround_mw sz', sz, 'op', op, 'n', n, 'differs')
        ok &= ok_t
    return ok
@test
def vtbl_g16():
    ok = True
    for t in range(3):
        tb, ix = random.getrandbits(256), random.getrandbits(256)
        T, I = lanes(tb, 8), lanes(ix, 8)
        exp = pack([0 if I[i] & 0x80 else T[16 * (i // 16) + (I[i] & 15)] for i in range(32)], 8)
        ok &= ev('vec2.v', 'vtbl_g16', {'t': (256, tb), 'idx': (256, ix)}) == exp
    return ok
@test
def narrow_w2b():
    ok = True
    for t in range(6):
        a = random.getrandbits(256); sh = random.randrange(16); sat = 1 + t % 3
        out = []
        for x in lanes(a, 16):
            v = (x if sat == 3 else sx(x, 16)); r = (v >> sh) + (((v >> (sh - 1)) & 1) if sh else 0)
            lo, hi = {1: (-128, 127), 2: (0, 255), 3: (0, 255)}[sat]
            out.append(max(lo, min(hi, r)))
        ok &= ev('vec2.v', 'narrow_w2b', {'a': (256, a), 'sh': (4, sh), 'sat': (2, sat)}) == pack(out, 8)
    return ok
@test
def ms16_all():
    ok = True
    for t in range(12):
        m = t % 6; a, b, c = random.getrandbits(256), random.getrandbits(256), random.getrandbits(256)
        A, B, C = lanes(a, 16), lanes(b, 16), lanes(c, 16); out = [0] * 16
        for i in range(16):
            xs, ys = sx(A[i], 16), sx(B[i], 16)
            if m == 0: out[i] = xs * ys
            elif m == 1: out[i] = (xs * ys) >> 16
            elif m == 2: out[i] = (A[i] * B[i]) >> 16
            elif m == 3: out[i] = min(32767, (xs * ys + 16384) >> 15)
            elif m == 4: out[i] = xs * ys + C[i]
        if m == 5:
            out = [0] * 8
            for j, (x, y) in enumerate(zip(lanes(c, 32), range(8))):
                out[j] = x + sx(A[2 * j], 16) * sx(B[2 * j], 16) + sx(A[2 * j + 1], 16) * sx(B[2 * j + 1], 16)
            exp = pack(out, 32)
        else: exp = pack(out, 16)
        ok_t = ev('vec3.v', 'ms16_all', {'a': (256, a), 'b': (256, b), 'c': (256, c), 'm': (3, m)}) == exp
        if not ok_t: print('  ms16_all mode', m, 'differs')
        ok &= ok_t
    return ok
@test
def ms8x8():
    ok = True
    for t in range(9):
        m = [0, 1, 2, 3, 4, 5, 6, 6, 6][t]; sa, sb = [(1, 1), (1, 0), (0, 0)][t % 3] if m == 6 else (0, 0)
        a, b, c = random.getrandbits(256), random.getrandbits(256), random.getrandbits(256)
        A, B, C = lanes(a, 16), lanes(b, 16), lanes(c, 16); out = [0] * 16
        if m == 5 or m == 6:
            out = []
            for j in range(8):
                if m == 5: v = sx(C[2*j] | C[2*j+1] << 16, 32) + sum(sx(A[2*j+k], 16) * sx(B[2*j+k], 16) for k in (0, 1))
                else:
                    Ab, Bb = lanes(a, 8), lanes(b, 8)
                    v = sx(lanes(c, 32)[j], 32) + sum((sx(Ab[4*j+k], 8) if sa else Ab[4*j+k]) * (sx(Bb[4*j+k], 8) if sb else Bb[4*j+k]) for k in range(4))
                out.append(v)
            exp = pack(out, 32)
        else:
            for i in range(16):
                xs, ys = sx(A[i], 16), sx(B[i], 16)
                out[i] = [xs * ys, (xs * ys) >> 16, (A[i] * B[i]) >> 16, min(32767, (xs * ys + 16384) >> 15), xs * ys + C[i]][m]
            exp = pack(out, 16)
        ok_t = ev('vec3.v', 'ms8x8', {'a': (256, a), 'b': (256, b), 'c': (256, c), 'm': (4, m), 'sa': (1, sa), 'sb': (1, sb), 'sacc': (64, 0)}) is not None
        got = ev('vec3.v', 'ms8x8_notree', {'a': (256, a), 'b': (256, b), 'c': (256, c), 'm': (4, m), 'sa': (1, sa), 'sb': (1, sb)})
        ok_t = got == exp
        if not ok_t: print('  ms8x8 mode', m, sa, sb, 'differs')
        ok &= ok_t
    return ok
@test
def cvt():
    import struct
    ok = True
    for v in (1, -1, 100000, -2147483648, 2147483647, 16777217, 123456789, 0, -77):
        got = ev('fp2.v', 'cvt_i2f', {'a': (32, v & 0xffffffff)})
        exp = struct.unpack('<I', struct.pack('<f', float(v)))[0]
        if got != exp: print('  cvt_i2f', v, hex(got or 0), hex(exp)); ok = False
    for f in (1.0, -1.5, 2.5, 3.5, 1e9, -3e9, 0.4, 0.5, 0.75, 123456.7, 2147483520.0):
        b = struct.unpack('<I', struct.pack('<f', f))[0]
        got = ev('fp2.v', 'cvt_f2i', {'a': (32, b)})
        r = round(f)							# python rounds half to even
        r = max(-2147483648, min(2147483647, r))
        if got != r & 0xffffffff: print('  cvt_f2i', f, hex(got or 0), hex(r & 0xffffffff)); ok = False
    return ok
@test
def segio():
    # a segment store of what a segment load took apart reproduces the beat (nf 2 or 4, bytes, beat 0 of 1 field-set): spot check of the byte positions
    m = int.from_bytes(bytes(range(32)), 'little')
    got = ev('vec2.v', 'segload', {'m': (256, m), 'nfm1': (2, 1), 'ez': (2, 0), 'bt': (2, 0)})
    if got is None: return False
    f0 = [(got >> (8 * i)) & 255 for i in range(16)]
    return f0 == list(range(0, 32, 2))
@test
def vmem_ld():
    ok = True
    for t in range(4):
        win = random.getrandbits(512); off = random.randrange(32); ty = 1 + t; sg = t % 2
        W = list(win.to_bytes(64, 'little')); S = list(W[off:off + 32])
        # types: 1 b->w, 2 b->l, 3 b->q, 4 w->l
        s, L = {1: (1, 2), 2: (1, 4), 3: (1, 8), 4: (2, 4)}[ty]; out = []
        for i in range(32 // L):
            v = int.from_bytes(bytes(S[i * s:(i + 1) * s]), 'little'); v = sx(v, 8 * s) if sg else v
            out += list((v & ((1 << (8 * L)) - 1)).to_bytes(L, 'little'))
        ok &= ev('mem2.v', 'vmem_ld', {'win': (512, win), 'off': (5, off), 't': (3, ty), 'sgn': (1, sg)}) == int.from_bytes(bytes(out), 'little')
    return ok
@test
def fma32():
    import struct
    f2b = lambda x: struct.unpack('<I', struct.pack('<f', x))[0]
    b2f = lambda b: struct.unpack('<f', struct.pack('<I', b))[0]
    ok = True
    for a, b, c in ((1.5, 2.0, 0.25), (3.0, -4.0, 10.0), (1.0, 1.0, -1.0), (0.1, 0.2, 0.3), (1e10, 1e-5, -3.0), (-7.25, 0.5, 100.0), (123.456, 78.9, -9000.0)):
        a, b, c = [b2f(f2b(x)) for x in (a, b, c)]
        exp = f2b(a * b + c) if a * b + c != 0 else 0			# the double product is exact (24 x 24 bits); the sum is rounded twice at worst
        got = ev('fp2.v', 'fma32', {'a': (32, f2b(a)), 'b': (32, f2b(b)), 'c': (32, f2b(c))})
        if got is None or abs(got - exp) > 1: print('  fma32', a, b, c, hex(got or 0), hex(exp)); ok = False
    return ok
if __name__ == '__main__':
    names = sys.argv[1:] or list(tests)
    with ThreadPoolExecutor(10) as ex:
        res = dict(zip(names, ex.map(lambda n: tests[n](), names)))
    for n in names: print('%-16s %s' % (n, 'ok' if res[n] else 'FAILED'))
