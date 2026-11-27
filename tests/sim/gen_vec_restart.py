#!/usr/bin/env python3
"""Generate tests/sim/vec-restart.S: the fault-and-restart test of the vec words of wave 1 and wave 2 (errata 170, 171) and of the older reductions (the control).

What it proves (docs/encoding-work/vec-isa.md section 4.4 and 4.1, errata 172): a block `vec Rs,Re ... vend` runs strip by strip; a fault in a strip annuls the strip:
  (a) the stores of the faulting strip are not in memory when the handler runs (the stores of the strips before it are),
  (b) the pointer registers and the scalar result (r10) seen by the handler are at an element boundary chosen by the implementation, no later than the faulting element
      (errata 173: the program and the OS treat them as opaque).  The test therefore accepts ANY element boundary e' with e' <= the faulting element, and then requires every
      pointer to be its entry value plus e' elements (a stream that does not move: unchanged), r10 to be the value of the model after exactly e' elements, and the memory the
      handler sees to hold the model's stores of the elements before e', the initial bytes from the faulting element on, and either in between.  A block with hidden
      accumulation (vclr, vfin) restarts from its entry: e' must be 0.  It is the same program at every strip width (sim64 -S 16, 32, 64),
  (c) EPC is the address of the `vec` instruction, EVA the first address that faulted in the order of the architecture (the least element, then the first instruction: the same
      at every strip), ECAUSE the load or store page fault (or the misaligned access),
  (d) after the handler has made the page present and returned (rti: the vec instruction is executed again) the final memory, the final pointers and the final scalar are
      those of a run with no fault (a reference run of the same kernel on pages that are all present, in the same program) and of the model written here in Python.
Each kernel is run (1) with no fault (the reference, also compared with the Python model), then with a fault on a load stream (A, B, C or the table T), on the store stream
(O) and on a misaligned pointer, in the first strip, a middle strip and the last (short) strip, and in a block of one element.  The page that faults is the page boundary
put in the middle of the strip (half of the strip's elements before it, half after it), so the strip has loaded or computed part of its elements and part of its stores
would be in the pages that are present when the fault is found.  The handler may run garbage vec blocks (clob 1: all of v0..v15 overwritten; clob 2: also a block with vclr
accumulators), which stands for the context switch that does not save the hidden registers.
clob 4: the handler runs `vclr` outside any block (it names accumulators) and returns: the exception return clears the naming, so the restarted block, which is not a block with accumulators,
is not treated as one (errata 172's open item, errata 186 decision 13).
clob 3: the handler reads EPC, EVA and ECAUSE only (no pointer, no scalar register, no memory of the block, no vector code), maps the page and returns: what an operating system may rely on (errata 173);
the restart must still give the result of a run with no fault, at every strip.  kind 3: two streams fault in one block (B at its element 1, A later): the first EVA must be B's whatever the strip.
The window of the test pages (WIN..WIN+16 MiB) is made of pages that are not present: on QEMU they are not mapped in the page table (the test builds identity tables and enables
the MMU; the handler maps the page) and on sim64 `-x LO:HI` makes the first access to each page fault (the facility added for this test).  Each scenario uses fresh pages.
usage: gen_vec_restart.py OUT.S"""
import sys as _sys, os as _os
_sys.path.insert(0, _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), '..', '..', 'tools'))
import marks		# the words of the encoding written with the width suffixes (tools/marks.py)
import random, struct, sys, math

rng = random.Random(172)
LB = {'b': 1, 'w': 2, 'l': 4, 'q': 8}
VB = 32                 # bytes of a strip (VBYTES of the simulator and of QEMU)
WIN = 0x800000
WINSZ = 0x1000000
PAGE = 4096


def sx(x, bits):
    x &= (1 << bits) - 1
    return x - (1 << bits) if x >> (bits - 1) else x


def ux(x, bits):
    return x & ((1 << bits) - 1)


def f2b(x):
    return struct.unpack('<I', struct.pack('<f', x))[0]


def b2f(b):
    return struct.unpack('<f', struct.pack('<I', b & 0xffffffff))[0]


def pack(vals, size):
    return b''.join((v & ((1 << (8 * size)) - 1)).to_bytes(size, 'little') for v in vals)


def rnd(bits, n):
    return [rng.getrandbits(bits) for _ in range(n)]


def corners(vals, bits, extra):
    v = list(vals)
    for i, x in enumerate(extra):
        v[i] = ux(x, bits)
    return v


NMAX = 128


class Kern:
    pass


kerns = []


def kern(name, lanemax, body, A, eo=0, B=None, C=None, T=None, model=None, init=0, hidden=False, r8=0, inplace=False, pre=(), nom=None):
    k = Kern()
    k.name = name; k.lanemax = lanemax; k.body = body; k.vl = VB // lanemax
    k.A = A; k.B = B; k.C = C; k.T = T      # (element size, list of unsigned patterns) ; T: (bytes, 'reg'|'mem')
    k.inplace = inplace; k.pre = list(pre)
    k.eo = eo; k.model = model; k.init = init; k.hidden = hidden; k.r8 = r8
    k.idx = len(kerns)
    k.nom = nom or 3 * k.vl + k.vl // 2
    k.res = {N: model(N) for N in (k.nom, 1)}      # evaluated now: the models refer to the module variables a, b that the next kernel replaces
    kerns.append(k)
    return k


def strips(N, vl):
    return [(lo, min(N, lo + vl)) for lo in range(0, N, vl)]


def mapk(f):
    """an element-wise model: f(i, N) -> the unsigned output pattern; no scalar"""
    return lambda N: ([f(i, N) for i in range(N)], None)


def redk(init, step, vl=None):
    """a reduction model: step(acc, lo, hi, N) -> acc (additive over ranges of elements); the table of the scalar after e elements for e = 0..N (the implementation stops where it likes:
    the handler's r10 is the entry value plus the first e' elements: errata 173)"""
    def m(N):
        return [], [step(init, 0, e, N) for e in range(N + 1)]
    return m


S64 = lambda v: sx(v, 64)
LOG = {1: 0, 2: 1, 4: 2, 8: 3}

# ---------------------------------------------------------------- wave 1
# vavg, vavgu
a = corners(rnd(8, NMAX), 8, [127, 0x80, 255, 0, 1, 255]); b = corners(rnd(8, NMAX), 8, [127, 0x80, 255, 0, 0, 254])
kern('vavg.b', 1, ['vld.b v0, (r1)+', 'vld.b v1, (r2)+', 'vavg.b v2, v0, v1', 'vst.b v2, (r3)+'], (1, a), eo=1, B=(1, b),
     model=mapk(lambda i, N: ux((sx(a[i], 8) + sx(b[i], 8) + 1) >> 1, 8)))
a = corners(rnd(16, NMAX), 16, [0x7fff, 0x8000, 0xffff, 0, 1, 0xffff]); b = corners(rnd(16, NMAX), 16, [0x7fff, 0x8000, 0xffff, 0, 0, 0xfffe])
kern('vavgu.w', 2, ['vld.wu v0, (r1)+', 'vld.wu v1, (r2)+', 'vavgu.w v2, v0, v1', 'vst.w v2, (r3)+'], (2, a), eo=2, B=(2, b),
     model=mapk(lambda i, N: (a[i] + b[i] + 1) >> 1))
# vmulh, vmulhu, vmulhr
a = corners(rnd(16, NMAX), 16, [-32768, -32768, 32767, 32767, 0xffff, -32768, 1, 0x4000, -1]); b = corners(rnd(16, NMAX), 16, [-32768, 32767, 32767, -32768, 0xffff, 1, -32768, 0x4000, -1])
kern('vmulh.w', 2, ['vld.w v0, (r1)+', 'vld.w v1, (r2)+', 'vmulh.w v2, v0, v1', 'vst.w v2, (r3)+'], (2, a), eo=2, B=(2, b),
     model=mapk(lambda i, N: ux((sx(a[i], 16) * sx(b[i], 16)) >> 16, 16)))
kern('vmulhu.w', 2, ['vld.wu v0, (r1)+', 'vld.wu v1, (r2)+', 'vmulhu.w v2, v0, v1', 'vst.w v2, (r3)+'], (2, a), eo=2, B=(2, b),
     model=mapk(lambda i, N: ux((ux(a[i], 16) * ux(b[i], 16)) >> 16, 16)))
kern('vmulhr.w', 2, ['vld.w v0, (r1)+', 'vld.w v1, (r2)+', 'vmulhr.w v2, v0, v1', 'vst.w v2, (r3)+'], (2, a), eo=2, B=(2, b),
     model=mapk(lambda i, N: ux(min((sx(a[i], 16) * sx(b[i], 16) + 0x4000) >> 15, 32767), 16)))
# vsarr, vshrr
for mn, lane, how in (('vsarr', 'w', 'reg3'), ('vshrr', 'w', 'imm5'), ('vsarr', 'l', 'vec'), ('vshrr', 'l', 'reg13')):
    bits = 8 * LB[lane]
    a = corners(rnd(bits, NMAX), bits, [(1 << (bits - 1)) - 1, 1 << (bits - 1), (1 << bits) - 1, 1 << (bits - 2), 0, 1])
    signed = mn == 'vsarr'
    sh = [rng.randrange(0, bits + 3) for _ in range(NMAX)]

    def rr(x, c, bits=bits, signed=signed):
        x = sx(x, bits) if signed else ux(x, bits)
        if c == 0:
            return ux(x, bits)
        if c > bits:
            return 0
        return ux((x + (1 << (c - 1))) >> c, bits)
    m = lane if signed else lane + 'u'
    if how == 'vec':
        kern('%s.%s (counts in a vector)' % (mn, lane), LB[lane], ['vld.%s v0, (r1)+' % m, 'vld.%s v1, (r2)+' % lane, '%s.%s v2, v0, v1' % (mn, lane), 'vst.%s v2, (r3)+' % lane], (LB[lane], a), eo=LB[lane], B=(LB[lane], sh),
             model=mapk(lambda i, N, a=a, sh=sh, rr=rr: rr(a[i], sh[i])))
    elif how.startswith('reg'):
        c = int(how[3:])
        kern('%s.%s by a register' % (mn, lane), LB[lane], ['vld.%s v0, (r1)+' % m, '%s.%s v1, v0, r8' % (mn, lane), 'vst.%s v1, (r3)+' % lane], (LB[lane], a), eo=LB[lane], r8=c,
             model=mapk(lambda i, N, a=a, c=c, rr=rr: rr(a[i], c)))
    else:
        c = int(how[3:])
        kern('%s.%s by an immediate' % (mn, lane), LB[lane], ['vld.%s v0, (r1)+' % m, '%s.%s v1, v0, $%d' % (mn, lane, c), 'vst.%s v1, (r3)+' % lane], (LB[lane], a), eo=LB[lane],
             model=mapk(lambda i, N, a=a, c=c, rr=rr: rr(a[i], c)))
# vmla vector by vector (the accumulator is loaded each strip: a visible destination)
for lane in ('w', 'l'):
    bits = 8 * LB[lane]
    a = rnd(bits, NMAX); b = rnd(bits, NMAX); c = rnd(bits, NMAX)
    a[0] = b[0] = 1 << (bits - 1)
    kern('vmla.%s vD, vA, vB' % lane, LB[lane], ['vld.%s v2, (r7)+' % lane, 'vld.%s v0, (r1)+' % lane, 'vld.%s v1, (r2)+' % lane, 'vmla.%s v2, v0, v1' % lane, 'vst.%s v2, (r3)+' % lane],
         (LB[lane], a), eo=LB[lane], B=(LB[lane], b), C=(LB[lane], c),
         model=mapk(lambda i, N, a=a, b=b, c=c, bits=bits: ux(c[i] + sx(a[i], bits) * sx(b[i], bits), bits)))
# vdot.w summed by vacc.l.q (the lane of vacc.l makes the strip 8 words)
a = rnd(16, NMAX); b = rnd(16, NMAX)
a[0] = b[0] = a[1] = b[1] = 0x8000


def vdot_step(acc, lo, hi, N):
    ps = [sx(a[i], 16) * sx(b[i], 16) for i in range(lo, hi)]
    lanes = [sx(ps[j] + (ps[j + 1] if j + 1 < len(ps) else 0), 32) for j in range(0, len(ps), 2)]
    return acc + sum(lanes)


kern('vdot.w + vacc.l.q', 4, ['vld.w v0, (r1)+', 'vld.w v1, (r2)+', 'vdot.w v2, v0, v1', 'vacc.l.q r10, v2'], (2, a), B=(2, b), init=1000, model=redk(1000, vdot_step, 8))
# vsad.bu
a = corners(rnd(8, NMAX * 2), 8, [255, 0, 255, 0, 128]); b = corners(rnd(8, NMAX * 2), 8, [0, 255, 255, 0, 127])
kern('vsad.bu', 1, ['vld.bu v0, (r1)+', 'vld.bu v1, (r2)+', 'vsad.bu r10, v0, v1'], (1, a), B=(1, b), init=1000,
     model=redk(1000, lambda acc, lo, hi, N: acc + sum(abs(a[i] - b[i]) for i in range(lo, hi)), 32))
# vdacc.b .bu .bsu .w
for mn, sa, sb, lane, ma, mb in (('vdacc.b', 1, 1, 'b', 'b', 'b'), ('vdacc.bu', 0, 0, 'b', 'bu', 'bu'), ('vdacc.bsu', 1, 0, 'b', 'b', 'bu'), ('vdacc.w', 1, 1, 'w', 'w', 'w')):
    bits = 8 * LB[lane]
    a = corners(rnd(bits, NMAX * 2), bits, [1 << (bits - 1), (1 << (bits - 1)) - 1, (1 << bits) - 1, 1 << (bits - 1), 0])
    b = corners(rnd(bits, NMAX * 2), bits, [1 << (bits - 1), (1 << (bits - 1)) - 1, (1 << bits) - 1, (1 << bits) - 1, 5])
    fa = (lambda v, bits=bits: sx(v, bits)) if sa else (lambda v, bits=bits: ux(v, bits))
    fb = (lambda v, bits=bits: sx(v, bits)) if sb else (lambda v, bits=bits: ux(v, bits))
    kern(mn, LB[lane], ['vld.%s v0, (r1)+' % ma, 'vld.%s v1, (r2)+' % mb, '%s r10, v0, v1' % mn], (LB[lane], a), B=(LB[lane], b), init=-5,
         model=redk(-5, lambda acc, lo, hi, N, a=a, b=b, fa=fa, fb=fb: acc + sum(fa(a[i]) * fb(b[i]) for i in range(lo, hi)), VB // LB[lane]))
# vtbl.b, the memory form (the register form was removed: errata 173)
idx = [rng.getrandbits(5) for _ in range(NMAX * 2)]
idx[3] = 0x85; idx[40] = 0xff; idx[41] = 16; idx[42] = 15; idx[43] = 0; idx[70] = 12; idx[71] = 13
tab = rnd(8, 32)


kern('vtbl.b (memory table)', 1, ['vld.bu v0, (r1)+', 'vtbl.b v2, (r6), v0', 'vst.b v2, (r3)+'], (1, idx), eo=1, T=(bytes(tab[:16]), 'mem'),
     model=mapk(lambda i, N: tab[idx[i]] if idx[i] < 16 else 0))
# vsts with a rounding shift
for lane, m, sh in (('l', 'w', 15), ('w', 'bu', 1), ('l', 'bu', 8)):
    bits = 8 * LB[lane]
    a = corners(rnd(bits, NMAX), bits, [(1 << (bits - 1)) - 1, 1 << (bits - 1), (1 << bits) - 1, 1 << (bits - 3), 8, 7, 9, ux(-9, bits), ux(-8, bits), ux(-7, bits)])
    msz = LB[m[0]]; mb = 8 * msz
    lo_, hi_ = (0, (1 << mb) - 1) if m.endswith('u') else (-(1 << (mb - 1)), (1 << (mb - 1)) - 1)

    def vs(i, N, a=a, bits=bits, sh=sh, lo_=lo_, hi_=hi_, mb=mb):
        x = sx(a[i], bits)
        x = (x + (1 << (sh - 1))) >> sh if sh else x
        return ux(max(lo_, min(hi_, x)), mb)
    kern('vsts.%s.%s rounding shift %d' % (lane, m, sh), LB[lane], ['vld.%s v0, (r1)+' % lane, 'vsts.%s.%s v0, (r3)+, $%d' % (lane, m, sh)], (LB[lane], a), eo=msz, model=mapk(vs))

# ---------------------------------------------------------------- wave 2
CMPNAME = {'vceq': lambda x, y, bits: ux(x, bits) == ux(y, bits), 'vcgt': lambda x, y, bits: sx(x, bits) > sx(y, bits), 'vcgtu': lambda x, y, bits: ux(x, bits) > ux(y, bits)}
for mn in ('vceq', 'vcgt', 'vcgtu'):
    for lane in ('b', 'w', 'l'):
        bits = 8 * LB[lane]; top = 1 << (bits - 1)
        a = rnd(bits, NMAX); b = rnd(bits, NMAX)
        for i in range(0, NMAX, 3):
            b[i] = a[i]
        a = corners(a, bits, [top, top - 1, (1 << bits) - 1, 0, 1]); b = corners(b, bits, [top - 1, top, 0, (1 << bits) - 1, 1])
        mk = lambda t, bits=bits: ux(-1, bits) if t else 0
        kern('%s.%s' % (mn, lane), LB[lane], ['vld.%s v0, (r1)+' % lane, 'vld.%s v1, (r2)+' % lane, '%s.%s v2, v0, v1' % (mn, lane), 'vst.%s v2, (r3)+' % lane], (LB[lane], a), eo=LB[lane], B=(LB[lane], b),
             model=mapk(lambda i, N, a=a, b=b, bits=bits, mn=mn, mk=mk: mk(CMPNAME[mn](a[i], b[i], bits))))
pool = [0.0, -0.0, 1.0, -1.0, 2.5, -2.5, float('nan'), float('inf'), float('-inf'), 1e-45, -1e-45, 3.0e38, -3.0e38, 16777216.0, 1.5, 1.5]
fa = [f2b(rng.choice(pool)) for _ in range(NMAX)]; fb = [f2b(rng.choice(pool)) for _ in range(NMAX)]
for i, (x, y) in enumerate([(0.0, -0.0), (-0.0, 0.0), (float('nan'), float('nan')), (float('inf'), float('inf')), (float('-inf'), float('inf')), (1e-45, 0.0), (float('nan'), 1.0), (1.0, float('nan'))]):
    fa[i] = f2b(x); fb[i] = f2b(y)
for mn, pr in (('vceq', lambda x, y: x == y), ('vcgt', lambda x, y: x > y)):
    kern('%s.f' % mn, 4, ['vld.f v0, (r1)+', 'vld.f v1, (r2)+', '%s.f v2, v0, v1' % mn, 'vst.l v2, (r3)+'], (4, fa), eo=4, B=(4, fb),
         model=mapk(lambda i, N, pr=pr: 0xffffffff if pr(b2f(fa[i]), b2f(fb[i])) else 0))
# vbsl (the destination another register, and the destination the mask), and the byte select
ma = rnd(32, NMAX); aa = rnd(32, NMAX); ab = rnd(32, NMAX)
sel = lambda m, x, y: ((m & x) | (~m & y)) & 0xffffffff
kern('vbsl (vD another)', 4, ['vld.l v0, (r1)+', 'vld.l v1, (r2)+', 'vld.l v2, (r7)+', 'vbsl v3, v0, v1, v2', 'vst.l v3, (r3)+'], (4, ma), eo=4, B=(4, aa), C=(4, ab), model=mapk(lambda i, N: sel(ma[i], aa[i], ab[i])))
kern('vbsl (vD = vM)', 4, ['vld.l v0, (r1)+', 'vld.l v1, (r2)+', 'vld.l v2, (r7)+', 'vbsl v0, v0, v1, v2', 'vst.l v0, (r3)+'], (4, ma), eo=4, B=(4, aa), C=(4, ab), model=mapk(lambda i, N: sel(ma[i], aa[i], ab[i])))
ba = rnd(8, NMAX * 2); bb = rnd(8, NMAX * 2)
for i in range(0, NMAX * 2, 4):
    bb[i] = ba[i]
kern('vcgtu.b + vbsl (unsigned maximum)', 1, ['vld.b v0, (r1)+', 'vld.b v1, (r2)+', 'vcgtu.b v2, v0, v1', 'vbsl v3, v2, v0, v1', 'vst.b v3, (r3)+'], (1, ba), eo=1, B=(1, bb), model=mapk(lambda i, N: max(ba[i], bb[i])))
# vcvt
ia = corners(rnd(32, NMAX), 32, [0, 1, -1, 1 << 24, (1 << 24) + 1, (1 << 24) + 2, (1 << 24) + 3, -((1 << 24) + 1), -((1 << 24) + 3), (1 << 31) - 1, 1 << 31, 0x7fffff80, 0x7fffffc0, 0xffffffff, 0xffffff7f, 0x80000001])
kern('vcvt.l.f', 4, ['vld.l v0, (r1)+', 'vcvt.l.f v1, v0', 'vst.f v1, (r3)+'], (4, ia), eo=4, model=mapk(lambda i, N: f2b(float(sx(ia[i], 32)))))
kern('vcvt.lu.f', 4, ['vld.l v0, (r1)+', 'vcvt.lu.f v1, v0', 'vst.f v1, (r3)+'], (4, ia), eo=4, model=mapk(lambda i, N: f2b(float(ux(ia[i], 32)))))
fv = [0.5, -0.5, 1.9, -1.9, 2147483648.0, -2147483648.0, 2147483520.0, -2147483904.0, 3.0e9, -3.0e9, float('nan'), float('inf'), float('-inf'), -0.0, 16777216.0, 8388608.5, 1e-45, 0.0, 4294967296.0, 4294967040.0, 4294967808.0, -1.0, -0.99999994, 1.0]
fx = [f2b(v) for v in fv] + [rng.getrandbits(32) for _ in range(NMAX - len(fv))]
fx[30] = 0x7fc00001; fx[31] = 0xffc00000; fx[32] = 0x7f800001


def f_to_l(b):
    v = b2f(b)
    if v != v:
        return 0x7fffffff
    if v >= 2147483648.0:
        return 0x7fffffff
    if v < -2147483648.0:
        return 0x80000000
    return ux(int(v), 32)


def f_to_lu(b):
    v = b2f(b)
    if v != v or v >= 4294967296.0:
        return 0xffffffff
    if v <= -1.0:
        return 0
    return int(v)


kern('vcvt.f.l', 4, ['vld.f v0, (r1)+', 'vcvt.f.l v1, v0', 'vst.l v1, (r3)+'], (4, fx), eo=4, model=mapk(lambda i, N: f_to_l(fx[i])))
kern('vcvt.f.lu', 4, ['vld.f v0, (r1)+', 'vcvt.f.lu v1, v0', 'vst.l v1, (r3)+'], (4, fx), eo=4, model=mapk(lambda i, N: f_to_lu(fx[i])))

# ---------------------------------------------------------------- the control: the older words (vadd, vacc, vmaxacc, vminacc)
a = rnd(32, NMAX); b = rnd(32, NMAX)
kern('vadd.l (control)', 4, ['vld.l v0, (r1)+', 'vld.l v1, (r2)+', 'vadd.l v2, v0, v1', 'vst.l v2, (r3)+'], (4, a), eo=4, B=(4, b), model=mapk(lambda i, N: ux(a[i] + b[i], 32)))
a = rnd(32, NMAX * 2)
kern('vacc.l.q (control)', 4, ['vld.l v0, (r1)+', 'vacc.l.q r10, v0'], (4, a), init=7, model=redk(7, lambda acc, lo, hi, N: acc + sum(sx(a[i], 32) for i in range(lo, hi)), 8))
kern('vmaxacc.l (control)', 4, ['vld.l v0, (r1)+', 'vmaxacc.l r10, v0'], (4, a), init=-(1 << 40), model=redk(-(1 << 40), lambda acc, lo, hi, N: max([acc] + [sx(a[i], 32) for i in range(lo, hi)]), 8))
kern('vminacc.l (control)', 4, ['vld.l v0, (r1)+', 'vminacc.l r10, v0'], (4, a), init=1 << 40, model=redk(1 << 40, lambda acc, lo, hi, N: min([acc] + [sx(a[i], 32) for i in range(lo, hi)]), 8))


# a scalar result followed in the same strip by a store or a load that can fault: the scalar must still be that of the start of the strip
def both(outf, red):
    def m(N):
        o, _ = mapk(outf)(N)
        _, sc = red(N)
        return o, sc
    return m


a = rnd(32, NMAX * 2)
kern('vacc.l.q then vst (control)', 4, ['vld.l v0, (r1)+', 'vacc.l.q r10, v0', 'vst.l v0, (r3)+'], (4, a), eo=4, init=7,
     model=both(lambda i, N, a=a: a[i], redk(7, lambda acc, lo, hi, N, a=a: acc + sum(sx(a[i], 32) for i in range(lo, hi)), 8)))
a = rnd(8, NMAX * 2); b = rnd(8, NMAX * 2)
kern('vsad.bu then vst', 1, ['vld.bu v0, (r1)+', 'vld.bu v1, (r2)+', 'vsad.bu r10, v0, v1', 'vst.b v1, (r3)+'], (1, a), eo=1, B=(1, b), init=1000,
     model=both(lambda i, N, b=b: b[i], redk(1000, lambda acc, lo, hi, N, a=a, b=b: acc + sum(abs(a[i] - b[i]) for i in range(lo, hi)), 32)))
a = rnd(8, NMAX * 2); b = rnd(8, NMAX * 2); c = rnd(8, NMAX * 2)
kern('vdacc.b, then a load of C, then vst', 1, ['vld.b v0, (r1)+', 'vld.b v1, (r2)+', 'vdacc.b r10, v0, v1', 'vld.b v2, (r7)+', 'vst.b v2, (r3)+'], (1, a), eo=1, B=(1, b), C=(1, c), init=-5,
     model=both(lambda i, N, c=c: c[i], redk(-5, lambda acc, lo, hi, N, a=a, b=b: acc + sum(sx(a[i], 8) * sx(b[i], 8) for i in range(lo, hi)), 32)))
a = rnd(16, NMAX); b = rnd(16, NMAX)
kern('vdot.w + vacc.l.q then vst', 4, ['vld.w v0, (r1)+', 'vld.w v1, (r2)+', 'vdot.w v2, v0, v1', 'vacc.l.q r10, v2', 'vst.w v0, (r3)+'], (2, a), eo=2, B=(2, b), init=1000,
     model=both(lambda i, N, a=a: a[i], redk(1000, lambda acc, lo, hi, N, a=a, b=b: acc + sum(
         sx((lambda ps: ps[j] + (ps[j + 1] if j + 1 < len(ps) else 0))([sx(a[i], 16) * sx(b[i], 16) for i in range(lo, hi)]), 32) for j in range(0, hi - lo, 2)), 8)))

# ---------------------------------------------------------------- hidden accumulation (vclr in the block): the block restarts from its entry
a = rnd(32, NMAX); b = rnd(32, NMAX)


def h1(N):
    acc = [0] * 8; out = []
    for lo, hi in strips(N, 4):
        for j in range(lo, hi):
            acc[j - lo] = ux(acc[j - lo] + a[j], 32)
            out.append(acc[j - lo])
    return out, None


kern('hidden: vclr.l + vadd.l (running sums by lane)', 4, ['vclr.l v4, $1', 'vld.l v0, (r1)+', 'vadd.l v4, v4, v0', 'vst.l v4, (r3)+'], (4, a), eo=4, hidden=True, model=h1)
a = rnd(16, NMAX); b = rnd(16, NMAX)


def h2(N):
    acc = [0] * 8; r = 0
    for lo, hi in strips(N, 4):
        ps = [sx(a[i], 16) * sx(b[i], 16) for i in range(lo, hi)]
        for j in range(0, len(ps), 2):
            acc[j // 2] = sx(acc[j // 2] + ps[j] + (ps[j + 1] if j + 1 < len(ps) else 0), 32)
        r += sum(acc[:hi - lo])
    return [], [0] * N + [r]


kern('hidden: vclr.l + vdot.w + vacc.l.q', 4, ['vclr.l v4, $1', 'vld.w v0, (r1)+', 'vld.w v1, (r2)+', 'vdot.w v4, v0, v1', 'vacc.l.q r10, v4'], (2, a), B=(2, b), hidden=True, init=0, model=h2)




# the canonical order of a floating-point sum (errata 173, vec-isa.md section 8): chunks of 16 bytes of the source lanes, each summed by the fixed tree ((l0 + l1) + (l2 + l3)) in the
# accumulate precision and added to the register one chunk after the other; a short last chunk has the lanes it has.  The adversarial data: huge and tiny mixed, exact cancellations.
def f32(x):
    return struct.unpack('<f', struct.pack('<f', x))[0]


def d2b(x):
    return struct.unpack('<Q', struct.pack('<d', x))[0]


def b2d(b):
    return struct.unpack('<d', struct.pack('<Q', b & (2 ** 64 - 1)))[0]


def fchunks(vals, init, prec, ch):
    rd = f32 if prec == 32 else (lambda v: v)
    acc = rd(init)
    for c in range(0, len(vals), ch):
        l = vals[c:c + ch]
        m = len(l)
        t = l[0] if m == 1 else rd(l[0] + l[1]) if m == 2 else rd(rd(l[0] + l[1]) + l[2]) if m == 3 else rd(rd(l[0] + l[1]) + rd(l[2] + l[3]))
        acc = rd(acc + t)
    return acc


def adversarial(n, seed):
    r = random.Random(seed)
    v = []
    while len(v) < n:
        big = 10.0 ** r.uniform(5, 8) * r.choice((-1, 1))
        v += [big, r.uniform(-3, 3), -big, r.uniform(-1e-3, 1e-3), r.uniform(0.5, 1.5) * 10.0 ** r.randint(-8, 8) * r.choice((-1, 1))]
    return [f32(x) for x in v[:n]]


fv = adversarial(NMAX, 7)
fb = [f2b(x) for x in fv]
kern('vacc.f (canonical order, 27 elements: a short last chunk)', 4, ['vld.f v0, (r1)+', 'vacc.f r10, v0'], (4, fb), init=f2b(1.0), nom=27,
     model=redk(f2b(1.0), lambda acc, lo, hi, N: f2b(fchunks(fv[lo:hi], b2f(acc), 32, 4))))
kern('vacc.f then vst (a float sum and a store in one strip)', 4, ['vld.f v0, (r1)+', 'vacc.f r10, v0', 'vst.f v0, (r3)+'], (4, fb), eo=4, init=f2b(-1.5), nom=28,
     model=both(lambda i, N: fb[i], redk(f2b(-1.5), lambda acc, lo, hi, N: f2b(fchunks(fv[lo:hi], b2f(acc), 32, 4)))))
dv = [x * (1 + 2.0 ** -40) for x in adversarial(NMAX, 8)]
db = [d2b(x) for x in dv]
kern('vacc.d (canonical order, 2-lane chunks)', 8, ['vld.d v0, (r1)+', 'vacc.d r10, v0'], (8, db), init=d2b(1.0), nom=15,
     model=redk(d2b(1.0), lambda acc, lo, hi, N: d2b(fchunks(dv[lo:hi], b2d(acc), 64, 2))))
kern('vacc.f.d (binary32 lanes summed in binary64)', 4, ['vld.f v0, (r1)+', 'vacc.f.d r10, v0'], (4, fb), init=d2b(0.25), nom=27,
     model=redk(d2b(0.25), lambda acc, lo, hi, N: d2b(fchunks(fv[lo:hi], b2d(acc), 64, 4))))
# a block with accumulators and an epilogue: the strip is 16 bytes on every implementation, the epilogue reads the final lanes (and loads a table: a fault there restarts the block)
a = rnd(32, NMAX); tw = rnd(32, 4)


def hepi(N):
    acc = [0] * 4
    for lo, hi in strips(N, 4):
        for j in range(lo, hi):
            acc[j - lo] = ux(acc[j - lo] + a[j], 32)
    fin = sum(sx(ux(acc[l] + tw[l], 32), 32) for l in range(4))
    return [], [0] * N + [fin]


kern('hidden: vclr.l + vadd.l, vfin, a table load and vacc.l.q', 4, ['vclr.l v4, $1', 'vld.l v0, (r1)+', 'vadd.l v4, v4, v0', 'vfin', 'vld.l v5, (r6)', 'vadd.l v4, v4, v5', 'vacc.l.q r10, v4'],
     (4, a), T=(pack(tw, 4), 'mem'), hidden=True, init=0, model=hepi)

# an in-place kernel (the stream is read and written: a restart that repeats the strips before the fault would add 1 twice) and a block whose accumulator is named
# before the block (the hand-written micro-kernels do this: vclr, then vec)
a = rnd(32, NMAX)
kern('in place: a[i] += 1', 4, ['vld.l v0, (r1)+', 'vadd.l v1, v0, $1', 'vst.l v1, (r3)+'], (4, a), eo=4, inplace=True, model=mapk(lambda i, N: ux(a[i] + 1, 32)))
a = rnd(32, NMAX)
kern('hidden: vclr before the block', 4, ['vld.l v0, (r1)+', 'vadd.l v4, v4, v0', 'vst.l v4, (r3)+'], (4, a), eo=4, hidden=True, pre=['vclr.l v4, $1'], model=h1)

# ---------------------------------------------------------------- scenarios
# the registers of a kernel: r1 stream A, r2 B, r7 C, r3 out O, r6 table T, r5 the end of A, r10 the scalar, r8 a register operand
STREAMS = ['A', 'B', 'C', 'T', 'O']
NB = {nm: 'nb_' + nm for nm in STREAMS}
blobs = []
bcache = {}
slot = [0]


def blob(b):
    b = bytes(b)
    if b in bcache:
        return bcache[b]
    lab = 'bl%d' % len(blobs)
    blobs.append((lab, b))
    bcache[b] = lab
    return lab


def new_slot():
    n = slot[0]
    slot[0] += 1
    pa = WIN + n * 2 * PAGE
    assert pa + 2 * PAGE <= WIN + WINSZ, 'window too small'
    return pa + PAGE


def E(b, off=0):
    if isinstance(b, int):
        return str(b + off)
    return '%s+%d' % (b, off) if off else b


for k in kerns:
    k.klabel = 'kern%d' % k.idx
    k.vlabel = 'kvec%d' % k.idx


def present(k):
    p = ['A']
    if k.B:
        p.append('B')
    if k.C:
        p.append('C')
    if k.T:
        p.append('T')
    if k.eo:
        p.append('O')
    return p


def build_row(k, N, kind, fs=None, s=0, clob=0):
    vl = k.vl
    pres = present(k)
    es = {'A': k.A[0], 'B': k.B[0] if k.B else 0, 'C': k.C[0] if k.C else 0, 'O': k.eo, 'T': 1}
    ob, scal = k.res[N]
    nstr = len(strips(N, vl))
    img = {}
    for nm, st in (('A', k.A), ('B', k.B), ('C', k.C)):
        if st:
            img[nm] = pack(st[1][:N], st[0])
    if k.T:
        img['T'] = k.T[0]
    ln = {nm: (N * es[nm] if nm != 'T' else (len(k.T[0]) if k.T else 0)) for nm in pres}
    base = {nm: NB[nm] for nm in pres}
    win = {nm: 0 for nm in STREAMS}
    pretouch = 0; pretouch2 = 0; pageB = 0; e0 = 0
    if kind == 3:
        # two streams fault: B at its element 1 and A at a later element; the first fault of the strip in the order of the architecture (the least element) is B's, at every strip
        pageA = new_slot(); pageB = new_slot()
        win['A'] = 1; win['B'] = 1
        eb = 1; ea = min(N - 1, vl // 2 + 2)
        base['A'] = pageA - ea * es['A']; base['B'] = pageB - eb * es['B']
        pretouch = pageB - PAGE; pretouch2 = pageA - PAGE
        e0 = ea
    if kind == 1:
        pageB = new_slot()
        win[fs] = 1
        if fs == 'T':
            base['T'] = pageB - ln['T'] // 2
            pretouch = pageB - PAGE
        else:
            if N == 1:
                k0 = 0
            elif s == nstr - 1:
                k0 = max(1, (N - s * vl) // 2)
            else:
                k0 = vl // 2
            e0 = s * vl + k0
            base[fs] = pageB - e0 * es[fs]
            if e0:
                pretouch = pageB - PAGE
    if k.inplace:
        base['O'] = base['A']
    init = {nm: E(base[nm], 1 if (kind == 2 and nm == fs) else 0) for nm in pres}
    fin = {nm: E(base[nm], N * es[nm] if nm != 'T' else 0) for nm in pres}
    if kind == 3:
        cause = 'VECTOR_LFAULT'; eva = str(pageB)
    elif kind == 1:
        cause = 'VECTOR_SFAULT' if fs == 'O' else 'VECTOR_LFAULT'
        eva = str(pageB)
    elif kind == 2:
        cause = 'VECTOR_MISALIGNED'; eva = init[fs]
    else:
        cause = '0'; eva = '0'
    # the memory the handler sees (errata 173): the model's stores of the elements before the progress element e' (whatever the implementation chose), the initial bytes from the
    # faulting element e0 on, and either in between (the strips the implementation had committed, or the ones a hidden block repeats)
    if k.eo:
        if kind == 1 and fs == 'O':
            snaplen = e0 * k.eo
        else:
            snaplen = N * k.eo
        if k.inplace:
            snaplen = e0 * k.eo if kind == 1 else 0
            esnap = pack(k.A[1][:snaplen // k.eo], k.eo)
        else:
            esnap = bytes([0xa5]) * snaplen
    else:
        snaplen = 0; esnap = b''
    e0 = e0 if kind in (1, 3) else 0
    table = [k.init] * (N + 1) if (scal is None or k.hidden) else list(scal)
    r10_fin = scal[-1] if scal is not None else k.init
    q = []
    z = lambda nm: init[nm] if nm in pres else '0'
    q.append('%s' % k.klabel)
    q.append('%d' % N); q.append('%d' % kind); q.append('%d' % clob)
    q.append(E(base['A'], N * es['A']))
    for nm in ('A', 'B', 'C', 'O', 'T'):
        q.append(z(nm))
    q.append('%d' % k.init); q.append('%d' % k.r8)
    for nm in STREAMS:
        if nm in pres and not (nm == 'O' and k.inplace):
            sb = E(base[nm])
            q += [sb, '%d' % ln[nm], blob(img[nm]) if nm in img else '0', '%d' % win[nm]]
        else:
            q += ['0', '0', '0', '0']
    q.append('%d' % pretouch)
    if kind:
        q += [cause, eva, k.vlabel]
        for nm in ('A', 'B', 'C', 'O', 'T'):
            q.append('%d' % ({'A': LOG[es['A']], 'B': LOG.get(es['B'], 0), 'C': LOG.get(es['C'], 0), 'O': LOG.get(es['O'], 0)}[nm] if nm in pres and nm != 'T' else -1))
        q.append(blob(pack(table, 8)))
        q += [E(base['O']) if snaplen else '0', '%d' % snaplen, blob(esnap) if snaplen else '0']
    else:
        q += ['0'] * 3 + ['0'] * 5 + ['0'] + ['0', '0', '0']
    q += [E(base['O']) if k.eo else '0', '%d' % (N * k.eo), blob(pack(ob, k.eo)) if k.eo else '0']
    for nm in ('A', 'B', 'C', 'O', 'T'):
        q.append(fin[nm] if nm in pres else '0')
    q.append('%d' % r10_fin)
    for nm in ('A', 'B', 'C', 'O', 'T'):
        q.append(E(base[nm]) if nm in pres else '0')
    q += ['0'] * (64 - len(q))
    q[59] = '%d' % e0; q[60] = '%d' % (1 if k.hidden else 0); q[61] = '%d' % (2 if kind == 3 else 1); q[62] = '%d' % (e0 * k.eo); q[63] = '%d' % pretouch2
    assert len(q) == 64
    desc.append('%s N=%d kind=%d fs=%s s=%d clob=%d' % (k.name, N, kind, fs, s, clob))
    return q


desc = []
rows = []
for k in kerns:
    pres = present(k)
    last = len(strips(k.nom, k.vl)) - 1
    rows.append(build_row(k, k.nom, 0))
    for s in (0, 1, last):
        rows.append(build_row(k, k.nom, 1, 'A', s))
    rows.append(build_row(k, k.nom, 1, 'A', 1, clob=1))
    rows.append(build_row(k, k.nom, 1, 'A', 1, clob=2))
    rows.append(build_row(k, k.nom, 1, 'A', 1, clob=3))
    rows.append(build_row(k, k.nom, 1, 'A', 1, clob=4))
    if k.B and not k.inplace:
        rows.append(build_row(k, k.nom, 3))
    for nm in ('B', 'C', 'T'):
        if nm in pres:
            rows.append(build_row(k, k.nom, 1, nm, 1 if nm != 'T' else 0))
    if k.eo and not k.inplace:
        for s in (0, 1, last):
            rows.append(build_row(k, k.nom, 1, 'O', s))
        rows.append(build_row(k, k.nom, 1, 'O', 1, clob=2))
    if k.A[0] > 1 and not k.inplace:
        rows.append(build_row(k, k.nom, 2, 'A'))
    if k.eo > 1 and not k.inplace:
        rows.append(build_row(k, k.nom, 2, 'O'))
    rows.append(build_row(k, 1, 0))
    rows.append(build_row(k, 1, 1, 'A', 0))
    if k.eo and not k.inplace:
        rows.append(build_row(k, 1, 1, 'O', 0))

import os
if os.environ.get('VR_ROWS'):
    keep = [int(x) for x in os.environ['VR_ROWS'].split(',')]
    rows = [rows[i] for i in keep]; desc = [desc[i] for i in keep]

# ---------------------------------------------------------------- the program
O = []
w = O.append
w('; GENERATED by tests/sim/gen_vec_restart.py -- do not edit.  Fault and restart of the vec words of wave 1 and wave 2 and of the control reductions (docs/encoding-work/vec-isa.md 4.4, errata 172):')
w('; %d kernels, %d scenarios.  A failed check n halts with status n (check list in the generator); sim64 -K -x 0x800000:0x1800000, QEMU with its MMU.' % (len(kerns), len(rows)))
w('#include "pdp64-consts.h"')
w('\t.text')
w('\t.globl\t_start')
w('_start:')
w('\tlea\tstk_top, sp')
w('\tlea\tvtab, r1')
w('\tmtsr\tvbr, r1')
w('\tlea\tl2, r1')
w('\tmtsr\tptbr, r1')
w('\tmovq\t$1, r1')
w('\tmtsr\tmmuctl, r1')
w('\tlea\trows, r12')
w('\tlea\trows_end, r13')
DRV = r'''
rowloop:
	cbeq	r12, r13, alldone
; the normal streams: copy the image, or fill the destination with 0xa5
	movq	r12, r11
	add	$96, r11
	movq	r12, r10
	add	$256, r10
prep:	cbeq	r11, r10, prepdone
	movq	8(r11), r4
	cbeq	r4, $0, pnext
	movq	24(r11), r3
	cbne	r3, $0, pnext
	movq	(r11), r2
	movq	16(r11), r1
	cbeq	r1, $0, pfill
	mcpy	r2, r1, r4
	br	pnext
pfill:	movq	$0xa5, r1
	mset	r2, r1, r4
pnext:	add	$32, r11
	br	prep
prepdone:
; the page before the one that will fault is touched first (it is paged in by the handler)
	movq	$0, r1
	movq	r1, expect
	movq	256(r12), r1
	cbeq	r1, $0, nopre
	movzb	(r1), r2
nopre:
	movq	504(r12), r1
	cbeq	r1, $0, nopre2
	movzb	(r1), r2
nopre2:
	movq	$0, r1
	movq	r1, hcount
	movq	r1, hr_epc
	movq	16(r12), r1
	setne	r1, $0, r1
	movq	r1, expect
	movq	40(r12), r1
	movq	48(r12), r2
	movq	56(r12), r7
	movq	64(r12), r3
	movq	72(r12), r6
	movq	32(r12), r5
	movq	80(r12), r10
	movq	88(r12), r8
	movq	(r12), r4
	call	r4
	movq	r1, fin_r1
	movq	r2, fin_r2
	movq	r7, fin_r7
	movq	r3, fin_r3
	movq	r6, fin_r6
	movq	r10, fin_r10
	movq	$0, r1
	movq	r1, expect
'''
w(DRV)
checks = []


def chk(n, lines):
    out = list(lines)
    out += ['\tcbeq\tr1, r2, 1f', '\tmovq\t$%d, r0' % n, '\thalt', '1:']
    return out


def cmpq(n, mem, off):
    return chk(n, ['\tmovq\t%s, r1' % mem, '\tmovq\t%d(r12), r2' % off])


w('\tmovq\t16(r12), r1')
w('\tcbeq\tr1, $0, noflt')
# a faulting row: exactly one fault, and its state
for l in chk(1, ['\tmovq\thcount, r1', '\tmovq\t488(r12), r2']):
    w(l)
for n, (mem, off) in enumerate([('hr_cause', 264), ('hr_eva1', 272), ('hr_epc', 280)]):
    for l in cmpq(2 + n, mem, off):
        w(l)
w('\tmovq\t24(r12), r1')
w('\tcbeq\tr1, $3, snapdone')             # clob 3: the handler read EVA, EPC and ECAUSE only and returned; it has no registers to check
# the state the handler saw (errata 173): the implementation's progress is an element boundary e' no later than the faulting element e0.  e' from the pointer of stream A.
w('\tmovq\thr_r1, r1')
w('\tmovq\t40(r12), r2')
w('\tsub\tr2, r1')                    # bytes of progress of stream A
w('\tmovq\t288(r12), r3')              # log2 of its element size
w('\tmovq\tr1, r4')
w('\tshr\tr3, r4')                     # e'
w('\tmovq\tr4, r5')
w('\tshl\tr3, r5')
w('\tcbeq\tr5, r1, pg1')
w('\tmovq\t$5, r0')
w('\thalt')
w('pg1:\tmovq\t472(r12), r2')          # e0, the faulting element
w('\tcblos\tr4, r2, pg2')              # e' <= e0
w('\tmovq\t$5, r0')
w('\thalt')
w('pg2:\tmovq\t480(r12), r2')          # a block with hidden accumulation restarts from its entry
w('\tcbeq\tr2, $0, pg3')
w('\tcbeq\tr4, $0, pg3')
w('\tmovq\t$5, r0')
w('\thalt')
w('pg3:')
for n, (hr, ini, shoff) in enumerate([('hr_r1', 40, 288), ('hr_r2', 48, 296), ('hr_r7', 56, 304), ('hr_r3', 64, 312), ('hr_r6', 72, 320)]):
    w('\tmovq\t%d(r12), r3' % shoff)
    w('\tmovq\t%d(r12), r2' % ini)
    w('\tcbeq\tr3, $-1, pq%d' % n)
    w('\tmovq\tr4, r5')
    w('\tshl\tr3, r5')
    w('\tadd\tr5, r2')
    w('pq%d:\tmovq\t%s, r1' % (n, hr))
    w('\tcbeq\tr1, r2, pr%d' % n)
    w('\tmovq\t$%d, r0' % (5 + n))
    w('\thalt')
    w('pr%d:' % n)
# r10: the model's scalar after exactly e' elements
w('\tmovq\t328(r12), r3')
w('\tmovq\tr4, r5')
w('\tshl\t$3, r5')
w('\tadd\tr5, r3')
w('\tmovq\t(r3), r2')
w('\tmovq\thr_r10, r1')
w('\tcbeq\tr1, r2, ps1')
w('\tmovq\t$10, r0')
w('\thalt')
w('ps1:')
# the memory: the model before e', the initial bytes from e0, either in between
w('\tmovq\t344(r12), r3')
w('\tcbeq\tr3, $0, snapdone')
w('\tmovq\t312(r12), r5')
w('\tmovq\tr4, r8')
w('\tshl\tr5, r8')                     # lo: the bytes of the elements before e\'
w('\tmovq\t496(r12), r9')              # hi: the bytes of the elements before e0
w('\tlea\thsnap, r1')
w('\tmovq\t376(r12), r2')
w('\tmovq\t352(r12), r6')
w('\tmovq\t$0, r7')
w('snl:\tmovzb\t(r1)+, r4')
w('\tmovzb\t(r2)+, r5')
w('\tmovzb\t(r6)+, r0')
w('\tcbhis\tr7, r8, sn2')
w('\tcbeq\tr4, r5, snn')
w('\tbr\tsnbad')
w('sn2:\tcbhis\tr7, r9, sn3')
w('\tcbeq\tr4, r5, snn')
w('\tcbeq\tr4, r0, snn')
w('\tbr\tsnbad')
w('sn3:\tcbeq\tr4, r0, snn')
w('snbad:\tmovq\t$11, r0')
w('\thalt')
w('snn:\tadd\t$1, r7')
w('\tcbne\tr7, r3, snl')
w('snapdone:')
w('\tbr\tfltdone')
w('noflt:')
for l in chk(12, ['\tmovq\thcount, r1', '\tmovq\t$0, r2']):
    w(l)
w('fltdone:')
# final state: memory and registers against the model
w('\tmovq\t360(r12), r1')
w('\tmovq\t376(r12), r2')
w('\tmovq\t368(r12), r3')
w('\tcall\tmemeq')
w('\tcbeq\tr0, $0, 1f')
w('\tmovq\t$13, r0')
w('\thalt')
w('1:')
for n, (mem, off) in enumerate([('fin_r1', 384), ('fin_r2', 392), ('fin_r7', 400), ('fin_r3', 408), ('fin_r6', 416), ('fin_r10', 424)]):
    for l in cmpq(14 + n, mem, off):
        w(l)
# against the reference run (kind 0 saves it; the misaligned rows compare the memory and the scalar only)
w('\tmovq\t16(r12), r1')
w('\tcbne\tr1, $0, vsref')
w('\tmovq\t368(r12), r3')
w('\tcbeq\tr3, $0, 1f')
w('\tlea\trefbuf, r2')
w('\tmovq\t360(r12), r1')
w('\tmcpy\tr2, r1, r3')
w('1:')
for nm, (src, ini) in enumerate([('fin_r1', 40), ('fin_r2', 48), ('fin_r7', 56), ('fin_r3', 64), ('fin_r6', 72)]):
    w('\tmovq\t%s, r1' % src)
    w('\tmovq\t%d(r12), r2' % ini)
    w('\tsub\tr2, r1')
    w('\tmovq\tr1, refd%d' % nm)
w('\tmovq\tfin_r10, r1')
w('\tmovq\tr1, refd5')
w('\tbr\trownext')
w('vsref:')
w('\tmovq\t360(r12), r1')
w('\tlea\trefbuf, r2')
w('\tmovq\t368(r12), r3')
w('\tcall\tmemeq')
w('\tcbeq\tr0, $0, 1f')
w('\tmovq\t$20, r0')
w('\thalt')
w('1:')
w('\tmovq\tfin_r10, r1')
w('\tmovq\trefd5, r2')
w('\tcbeq\tr1, r2, 1f')
w('\tmovq\t$21, r0')
w('\thalt')
w('1:')
w('\tmovq\t16(r12), r1')
w('\tcbeq\tr1, $2, rownext')
for nm, (src, ini) in enumerate([('fin_r1', 40), ('fin_r2', 48), ('fin_r7', 56), ('fin_r3', 64), ('fin_r6', 72)]):
    w('\tmovq\t%s, r1' % src)
    w('\tmovq\t%d(r12), r2' % ini)
    w('\tsub\tr2, r1')
    w('\tmovq\trefd%d, r2' % nm)
    w('\tcbeq\tr1, r2, 1f')
    w('\tmovq\t$%d, r0' % (22 + nm))
    w('\thalt')
    w('1:')
w('rownext:')
w('\tadd\t$512, r12')
w('\tbr\trowloop')
w('alldone:')
w('\tmovq\t$0, r0')
w('\thalt')
HAND = r'''
memeq:	cbeq	r3, $0, me_ok
me_l:	movzb	(r1)+, r0
	movzb	(r2)+, r4
	cbne	r0, r4, me_bad
	sob	r3, me_l
me_ok:	movq	$0, r0
	ret
me_bad:	movq	$1, r0
	ret

h_bad:	movq	$99, r0
	halt
h_fault:
	pushm	$0x3fff
	movq	24(r12), r0
	cbeq	r0, $3, h_min
	movq	r1, hr_r1
	movq	r2, hr_r2
	movq	r7, hr_r7
	movq	r3, hr_r3
	movq	r6, hr_r6
	movq	r10, hr_r10
h_min:
	mfsr	r1, epc
	movq	r1, hr_epc
	mfsr	r1, ecause
	movq	r1, hr_cause
	mfsr	r1, eva
	movq	r1, hr_eva
	movq	expect, r2
	cbeq	r2, $0, h_page
	movq	hcount, r2
	cbne	r2, $0, h_nf
	movq	r1, hr_eva1
h_nf:	add	$1, r2
	movq	r2, hcount
	movq	344(r12), r3
	cbeq	r3, $0, h_nosnap
	lea	hsnap, r2
	movq	336(r12), r4
	mcpy	r2, r4, r3
h_nosnap:
	movq	hr_cause, r2
	cbeq	r2, $VECTOR_MISALIGNED, h_mis
h_page:
	mfsr	r1, eva
	shr	$12, r1
	shl	$12, r1
	movq	r1, r2
	movq	=0x800000, r3
	sub	r3, r2
	shr	$12, r2
	shl	$3, r2
	lea	wpt, r3
	add	r3, r2
	movq	r1, r3
	bis	$(1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D), r3
	movq	r3, (r2)
	tlbi	r1
	movq	r12, r4
	add	$96, r4
	movq	r12, r5
	add	$256, r5
hp_s:	cbeq	r4, r5, h_pdone
	movq	8(r4), r6
	cbeq	r6, $0, hp_next
	movq	24(r4), r7
	cbeq	r7, $0, hp_next
	movq	(r4), r2
	add	r2, r6
	movq	r1, r3
	add	$4096, r3
	cbhis	r2, r1, 1f
	movq	r1, r2
1:	cblo	r6, r3, 1f
	movq	r3, r6
1:	cbhis	r2, r6, hp_next
	movq	r6, r7
	sub	r2, r7
	movq	16(r4), r3
	cbeq	r3, $0, hp_fill
	movq	r2, r0
	movq	(r4), r8
	sub	r8, r0
	add	r0, r3
	mcpy	r2, r3, r7
	br	hp_next
hp_fill:
	movq	$0xa5, r0
	mset	r2, r0, r7
hp_next:
	add	$32, r4
	br	hp_s
h_pdone:
	movq	expect, r2
	cbeq	r2, $0, h_ret
	movq	24(r12), r2
	cbeq	r2, $0, h_ret
	cbeq	r2, $3, h_ret
	cbne	r2, $4, h_garb
; clob 4: the handler names accumulators with vclr OUTSIDE any block (all sixteen registers) and returns: the exception return clears the naming (errata 186 decision 13, 6.14.9;
; the open item of errata 172), so the restarted block of the interrupted program finds nothing named and gives the result of a run with no fault
	vclr.l	v0, $8
	vclr.l	v8, $8
	br	h_ret
h_garb:
; the context switch that does not save the hidden registers: other blocks overwrite v0..v15 (and name accumulators)
	lea	gdata, r1
	lea	gdata+512, r5
	vec	r1, r5
	vld.l	v0, (r1)+
	vld.l	v1, (r1)+
	vld.l	v2, (r1)+
	vld.l	v3, (r1)+
	vld.l	v4, (r1)+
	vld.l	v5, (r1)+
	vld.l	v6, (r1)+
	vld.l	v7, (r1)+
	vld.l	v8, (r1)+
	vld.l	v9, (r1)+
	vld.l	v10, (r1)+
	vld.l	v11, (r1)+
	vld.l	v12, (r1)+
	vld.l	v13, (r1)+
	vld.l	v14, (r1)+
	vld.l	v15, (r1)+
	vend
	movq	24(r12), r2
	cblo	r2, $2, h_ret
	lea	gdata, r1
	lea	gdata+32, r5
	vec	r1, r5
	vclr.l	v0, $8
	vld.l	v8, (r1)+
	vadd.l	v0, v0, v8
	vadd.l	v1, v1, v8
	vadd.l	v2, v2, v8
	vadd.l	v3, v3, v8
	vadd.l	v4, v4, v8
	vadd.l	v5, v5, v8
	vadd.l	v6, v6, v8
	vadd.l	v7, v7, v8
	vend
h_ret:
	popm	$0x3fff
	rti	$RTIMASK_ALL
h_mis:
	movq	24(r12), r2
	lea	fixtramp, r1
	mtsr	epc, r1
	popm	$0x3fff
	rti	$RTIMASK_ALL
fixtramp:
	movq	432(r12), r1
	movq	440(r12), r2
	movq	448(r12), r7
	movq	456(r12), r3
	movq	464(r12), r6
	movq	280(r12), r0
	jmp	r0
'''
w(HAND)
for k in kerns:
    w('\t.align 2')
    w('%s:' % k.klabel)
    for b in k.pre:
        w('\t' + b)
    w('%s:' % k.vlabel)
    w('\tvec\tr1, r5')
    for b in k.body:
        w('\t' + b)
    w('\tvend')
    w('\tret')
w('\t.data')
w('\t.align\t8')
w('vtab:')
w('\t.space\t16')
for v in range(2, 16):
    w('\t.quad\t%s' % ('h_fault' if v in (4, 7, 8, 13) else 'h_bad'))
w('\t.quad\th_bad')
w('\t.align\t8')
for nm in ('expect', 'hcount', 'hr_epc', 'hr_cause', 'hr_eva', 'hr_eva1', 'hr_r1', 'hr_r2', 'hr_r7', 'hr_r3', 'hr_r6', 'hr_r10', 'fin_r1', 'fin_r2', 'fin_r7', 'fin_r3', 'fin_r6', 'fin_r10',
           'refd0', 'refd1', 'refd2', 'refd3', 'refd4', 'refd5'):
    w('%s:\t.quad\t0' % nm)
w('gdata:')
gd = [rng.randrange(1, 256) for _ in range(512)]
for i in range(0, 512, 32):
    w('\t.byte\t' + ', '.join(str(x) for x in gd[i:i + 32]))
for lab, b in blobs:
    w('\t.align\t8')
    w('%s:' % lab)
    for i in range(0, len(b), 32):
        w('\t.byte\t' + ', '.join(str(x) for x in b[i:i + 32]))
    if not b:
        w('\t.space\t8')
w('\t.align\t64')
for nm in STREAMS:
    w('nb_%s:\t.space\t512' % nm)
w('hsnap:\t.space\t512')
w('refbuf:\t.space\t512')
w('\t.align\t8')
w('rows:')
for q in rows:
    for i in range(0, 64, 8):
        w('\t.quad\t' + ', '.join(q[i:i + 8]))
w('rows_end:')
w('\t.space\t8192')
w('stk_top:')
# the page tables (the window pages are not present: wpt is zero)
w('\t.align\t4096')
w('l2:')
w('\t.quad\tl1 + (1<<PTE_V)')
w('\t.space\t4088')
w('\t.align\t4096')
w('l1:')
NW = WINSZ // (2 << 20)
W0 = WIN // (2 << 20)
for i in range(512):
    if W0 <= i < W0 + NW:
        w('\t.quad\twpt + %d + (1<<PTE_V)' % ((i - W0) * 4096))
    else:
        w('\t.quad\t%d + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D)' % (i << 21))
w('\t.align\t4096')
w('wpt:\t.space\t%d' % (NW * 4096))
open(sys.argv[1], 'w').write(marks.spell_text('\n'.join(O)) + '\n')
if len(sys.argv) > 2:
    open(sys.argv[2], 'w').write('\n'.join(desc) + '\n')
print('%d kernels, %d rows, %d window slots, %d blobs' % (len(kerns), len(rows), slot[0], len(blobs)))
