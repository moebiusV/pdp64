#!/usr/bin/env python3
"""strip-equiv.py [OUTDIR] -- does anything a program computes depend on the strip?  (docs/encoding-work/vec-strip.md section 5, vec-isa.md section 8: it must not, errata 173)

Runs every test of tests/sim (assembled with as64 and ld64, as tools/check-sim64.sh does) under sim64 at the strips 16, 32 and 64 bytes (sim64 -S), each exactly as it is: NO check is switched
off and no test is patched (before errata 173 the three tests that look at the strip, vec-basic vlen.b, vec-wave1 test 63 and vec-restart, were run a second time with those checks removed).
A test passes if its exit status is the expected one (NAME.exit, default 0) at every strip and its standard output is the same.  The strip of 8 bytes is outside the architecture (the least is 16:
vec-isa.md section 8) and is run for information only: a program that sums floating-point lanes may differ there.
Then the probe: vacc.f over 1000 binary32 values of adversarial size, and the same with vacc.d and vacc.f.d, must give the same bits at every strip, and the bits of the model of the canonical order.
Then llvm-pdp64/check.sh (the .ll tests, the C programs and the vector kernels of llvm-pdp64/tests/vec, four variants each) runs with PDP64_VSTRIP=16, 32 and 64 (sim64's default strip; check.sh takes no
option) and the lines "ok" and "FAIL" are compared between the strips.  Writes OUTDIR/equiv.md (default tools/gates/strip-results).  NOLLVM=1 skips llvm-pdp64/check.sh.
"""
import os, re, subprocess, sys, tempfile, shutil, struct, random
from fractions import Fraction
HERE = os.path.dirname(os.path.abspath(__file__)); R = os.path.dirname(HERE); B = os.path.join(R, 'build')
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'gates', 'strip-results')
os.makedirs(OUT, exist_ok=True)
STRIPS = (16, 32, 64)
INFO = (8,)

def sh(cmd, **kw): return subprocess.run(cmd, capture_output=True, text=True, **kw)

tmp = tempfile.mkdtemp()
def build(name, src):
    ext = '.S' if src.endswith('.S') else '.s'
    sp = os.path.join(tmp, name + ext)
    shutil.copy(src, sp)
    if ext == '.S':
        pp = sp[:-2] + '.pp.s'
        r = sh([os.path.join(R, 'tools', 'pp-asm.sh'), sp, pp])
        if r.returncode: return None
        sp = pp
    o = sp + '.o'; x = sp + '.x'
    if sh([os.path.join(B, 'as64'), '-o', o, sp]).returncode or sh([os.path.join(B, 'ld64'), '-o', x, o]).returncode: return None
    return x
rows = []
tdir = os.path.join(R, 'tests', 'sim')
tests = sorted(f for f in os.listdir(tdir) if f.endswith(('.s', '.S')))
for f in tests:
    name = f.rsplit('.', 1)[0]
    flags = open(os.path.join(tdir, name + '.flags')).read().split() if os.path.exists(os.path.join(tdir, name + '.flags')) else []
    want = int(open(os.path.join(tdir, name + '.exit')).read()) if os.path.exists(os.path.join(tdir, name + '.exit')) else 0
    x = build(name, os.path.join(tdir, f))
    if not x: rows.append((name, None, [], [])); continue
    res = []; info = []
    for s in STRIPS + INFO:
        r = sh([os.path.join(B, 'sim64'), '-S', str(s)] + flags + [x], timeout=600)
        (res if s in STRIPS else info).append((r.returncode, r.stdout))
    rows.append((name, want, res, info))

lines = ['| test | expected exit | exit at strip 16, 32, 64 | stdout identical | verdict | strip 8 (outside the architecture) |', '|---|---:|---|---|---|---|']
nsame = 0; ndiff = []
for name, want, res, info in rows:
    if want is None: lines.append('| %s | - | did not build | - | FAIL | - |' % name); ndiff.append(name); continue
    ex = [r[0] for r in res]; same_out = len({r[1] for r in res}) == 1
    ok = all(e == want for e in ex) and same_out
    nsame += ok
    if not ok: ndiff.append(name)
    i8 = 'exit %d' % info[0][0] + (', same output' if info[0][1] == res[1][1] else ', output differs')
    if name.startswith('vec') or not ok:
        lines.append('| %s | %d | %s | %s | %s | %s |' % (name, want, ' '.join(map(str, ex)), 'yes' if same_out else 'NO', 'same' if ok else 'DIFFERS', i8))
n8 = sum(1 for name, want, res, info in rows if want is not None and (info[0][0] != want or info[0][1] != res[1][1]))
head = ['%d programs of tests/sim, each run unmodified at the strips 16, 32 and 64 bytes (no check switched off, no test patched): **%d gave the expected exit status and the same standard output at all three, %d did not**%s.  At the strip of 8 bytes, which is outside the architecture, %d of them differ from the strip-32 run.  The table lists the vec tests and any that failed.' % (len(rows), nsame, len(ndiff), (': ' + ', '.join(ndiff)) if ndiff else '', n8)]
txt = '\n\n'.join(head) + '\n\n' + '\n'.join(lines) + '\n'

# the probe: the floating-point sums in the canonical order (vec-isa.md section 8) over 1000 values, at every strip, against the model
def to32(x):
    x = Fraction(x)
    if x == 0: return 0.0
    sg = -1 if x < 0 else 1; x = abs(x)
    e = x.numerator.bit_length() - x.denominator.bit_length()
    if Fraction(2) ** e > x: e -= 1
    m = x * Fraction(2) ** (23 - e); q = m.numerator // m.denominator; rem = m - q
    if rem > Fraction(1, 2) or (rem == Fraction(1, 2) and q & 1): q += 1
    return sg * q * 2.0 ** (e - 23)
def f2b(x): return struct.unpack('<I', struct.pack('<f', x))[0]
def d2b(x): return struct.unpack('<Q', struct.pack('<d', x))[0]
def chunks(vals, init, prec, ch):
    ad = (lambda a, b: to32(Fraction(a) + Fraction(b))) if prec == 32 else (lambda a, b: a + b)
    acc = init
    for c in range(0, len(vals), ch):
        l = vals[c:c + ch]; m = len(l)
        t = l[0] if m == 1 else ad(l[0], l[1]) if m == 2 else ad(ad(l[0], l[1]), l[2]) if m == 3 else ad(ad(l[0], l[1]), ad(l[2], l[3]))
        acc = ad(acc, t)
    return acc
rg = random.Random(1); fl = []
while len(fl) < 1000:
    big = 10.0 ** rg.uniform(5, 8) * rg.choice((-1, 1)); fl += [big, rg.uniform(-3, 3), -big, rg.uniform(-1e-3, 1e-3), rg.uniform(0.5, 1.5) * 10.0 ** rg.randint(-8, 8) * rg.choice((-1, 1))]
fl = [to32(v) for v in fl[:1000]]
dd = [v * (1 + 2.0 ** -40) for v in fl]
probes = (('vacc.f', 'vld.f', 4, f2b, lambda: f2b(chunks(fl, 0.0, 32, 4))), ('vacc.d', 'vld.d', 8, d2b, lambda: d2b(chunks(dd, 0.0, 64, 2))), ('vacc.f.d', 'vld.f', 4, f2b, lambda: d2b(chunks(fl, 0.0, 64, 4))))
txt += '\nThe probe: a floating-point sum over 1000 values (seeded, mixed sign, 10^-8 to 10^8, with exact cancellations: the order of the additions changes the result), the register as bits by strip, and the model of the canonical order:\n\n'
txt += '| word | model | ' + ' | '.join('strip %d' % s for s in STRIPS + INFO) + ' | verdict |\n|---|---|' + '---|' * (len(STRIPS) + len(INFO)) + '---|\n'
for mn, ld, sz, enc, model in probes:
    vals = dd if mn == 'vacc.d' else fl
    fps = os.path.join(tmp, 'fp_' + mn + '.s')
    pack = ''.join('\t.%s\t0x%x\n' % ('quad' if sz == 8 else 'long', enc(v)) for v in vals)
    open(fps, 'w').write("\t.text\n\t.globl\t_start\n_start:\tlea\tsrc, r1\n\tmovq\t$%d, r2\n\tlea\t(r1)(r2*1), r4\n\tmovq\t$0, r10\n\tvec\tr1, r4\n\t%s v0, (r1)+\n\t%s r10, v0\n\tvend\n"
        "\tlea\tout, r5\n\tmovq\tr10, (r5)\n\tmovq\t$1, r0\n\tlea\tout, r1\n\tmovq\t$8, r2\n\ttrap\t$1\n\tmovq\t$0, r0\n\ttrap\t$0\n\t.data\n\t.align 8\nsrc:\n" % (sz * 1000, ld, mn) + pack + "out:\t.quad\t0\n")
    sh([os.path.join(B, 'as64'), '-o', fps + '.o', fps]); sh([os.path.join(B, 'ld64'), '-o', fps + '.x', fps + '.o'])
    got = {}
    for st in STRIPS + INFO:
        r = subprocess.run([os.path.join(B, 'sim64'), '-S', str(st), fps + '.x'], capture_output=True); got[st] = int.from_bytes(r.stdout[:8], 'little')
    want = model()
    ok = all(got[s] == want for s in STRIPS)
    txt += '| %s | 0x%x | %s | %s |\n' % (mn, want, ' | '.join('0x%x' % got[s] for s in STRIPS + INFO), 'same, equal to the model' if ok else 'DIFFERS')
    if not ok: ndiff.append('probe ' + mn)
# llvm-pdp64/check.sh at each strip
chk = {}
for s in (STRIPS if not os.environ.get('NOLLVM') else ()):
    env = dict(os.environ, PDP64_VSTRIP=str(s))
    r = subprocess.run([os.path.join(os.environ.get('LLVM_PDP64') or os.path.join(os.path.dirname(R), 'llvm-pdp64'), 'check.sh')], capture_output=True, text=True, env=env, timeout=7200)
    chk[s] = [l for l in r.stdout.splitlines() if l.startswith(('ok ', 'FAIL'))]
    summ = [l for l in r.stdout.splitlines() if 'passed' in l]
    chk[s, 'sum'] = summ
if os.environ.get('NOLLVM'):
    open(os.path.join(OUT, 'equiv.md'), 'w').write(txt); print(txt)
    if not os.environ.get('KEEP'): shutil.rmtree(tmp, ignore_errors=True)
    sys.exit(1 if ndiff else 0)
base = set(chk[32])
txt += '\nllvm/check.sh (rc and the lines "ok"/"FAIL", the .ll tests, the C programs through two pipelines and the vector kernels, four variants each):\n\n'
for s in STRIPS:
    txt += '* strip %d: %d ok, %d FAIL; %s\n' % (s, sum(1 for l in chk[s] if l.startswith('ok')), sum(1 for l in chk[s] if l.startswith('FAIL')), ' | '.join(chk[s, 'sum']))
for s in STRIPS:
    if s == 32: continue
    d = sorted(set(chk[s]) ^ base)
    txt += '\nLines that differ between strip 32 and strip %d (%d):\n%s\n' % (s, len(d), '\n'.join('    ' + l for l in d) if d else '    none')
open(os.path.join(OUT, 'equiv.md'), 'w').write(txt)
print(txt)
if not os.environ.get('KEEP'): shutil.rmtree(tmp, ignore_errors=True)
bad = bool(ndiff) or any(l.startswith('FAIL') for s in STRIPS for l in chk[s]) or any(set(chk[s]) ^ base for s in STRIPS)
print('strip-equiv: %s' % ('FAILED' if bad else 'ok: nothing a program computes depends on the strip'))
sys.exit(1 if bad else 0)
