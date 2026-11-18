#!/usr/bin/env python3
"""strip-equiv.py [OUTDIR] -- does anything a program computes depend on the strip?  (docs/encoding-work/vec-strip.md, section 5)

Runs every test of tests/sim (assembled with as64 and ld64, as tools/check-sim64.sh does) under sim64 at the strips 8, 16, 32 and 64 bytes (sim64 -S), once as the test is and once
`patched`: the checks that look at the strip itself are switched off in a private copy (the patched checks are listed in the output), so that the rest of the test, which stops at the first
failed check, is run to the end.  Prints, for every test, the exit status at each strip and whether the standard output is identical; the tests/sim/vec-*.s(.S) rows are the vector ones.
Then llvm/check.sh (the .ll tests, the C programs and the vector kernels of llvm/tests/vec, four variants each) runs with PDP64_VSTRIP=8, 16, 32 and 64 (sim64's default strip; check.sh takes
no option) and the lines "ok" and "FAIL" are compared between the strips.  Writes OUTDIR/equiv.md (default tools/gates/strip-results).
"""
import os, re, subprocess, sys, tempfile, shutil
HERE = os.path.dirname(os.path.abspath(__file__)); R = os.path.dirname(HERE); B = os.path.join(R, 'build')
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'gates', 'strip-results')
os.makedirs(OUT, exist_ok=True)
STRIPS = (8, 16, 32, 64)

def sh(cmd, **kw): return subprocess.run(cmd, capture_output=True, text=True, **kw)

# the checks that read the strip: (test, regex, replacement, what it checks)
PATCHES = {
    'vec-basic': [(r'\tcbne\tr5, #32, fail\n', '', 'check 4: vlen.b is 32')],
    'vec-wave1': [(r'\tcbne\tr5, r6, fail\n\tsob\tr4, c63\n', '\tsob\tr4, c63\n', 'check 63: vtbl.b with a table register, the result of lanes 16 and above depends on the strip')],
    'vec-restart': [(r'\tmovq\t#(5|6|7|8|9|10|11), r0\n\thalt\n', '\tnop\n', 'checks 5 to 11: the registers and the memory the handler sees at a fault (the progress at the strip it stopped in)')],
}
tmp = tempfile.mkdtemp()
def build(name, src, patched):
    s = open(src).read()
    used = []
    if patched and name == 'vec-restart':
        # check 13 (the final memory against the model) for the kernels whose block holds a register-form vtbl.b: the model is the strip-32 result
        ks = []
        for m in re.finditer(r'^kern(\d+):\n((?:(?!^kern)[^\n]*\n)*)', s, flags=re.M):
            body = m.group(2)
            if re.search(r'^[ \t]*vtbl\.b[ \t]+v\d+, v\d+, v\d+', body, flags=re.M): ks.append((m.group(1), 'vtbl.b register form'))
            elif re.search(r'^[ \t]*vclr', body, flags=re.M) and re.search(r'^[ \t]*(vs(t|ts|seg\d)|vacc|vmaxacc|vminacc)\b', body, flags=re.M): ks.append((m.group(1), 'an accumulator read inside the block'))
        skip = ''.join('\tlea\tkern%s, r5\n\tcbeq\tr4, r5, rownext\n' % k for k, why in ks)
        s, n = re.subn(r'(\tmovq\t16\(r12\), r1\n\tcbeq\tr1, #0, noflt\n)', lambda m: '\tmovq\t(r12), r4\n' + skip + m.group(1), s, count=1)
        if n: used.append('every check of the rows of the kernels %s, the blocks of which store lanes that depend on the strip (a register-form vtbl.b, or a vclr accumulator stored or reduced inside the block; the expected states are the strip-32 ones; the rows of all other kernels run all checks)' % ' '.join('kern' + k for k, why in ks))
    if patched:
        for pat, rep, what in PATCHES.get(name, []):
            s2, n = re.subn(pat, rep, s)
            if n: used.append('%s (%d)' % (what, n))
            s = s2
    ext = '.S' if src.endswith('.S') else '.s'
    sp = os.path.join(tmp, name + ('.p' if patched else '') + ext)
    open(sp, 'w').write(s)
    if ext == '.S':
        pp = sp[:-2] + '.pp.s'
        r = sh([os.path.join(R, 'tools', 'pp-asm.sh'), sp, pp])
        if r.returncode: return None, used
        sp = pp
    o = sp + '.o'; x = sp + '.x'
    if sh([os.path.join(B, 'as64'), '-o', o, sp]).returncode or sh([os.path.join(B, 'ld64'), '-o', x, o]).returncode: return None, used
    return x, used
rows = []
tdir = os.path.join(R, 'tests', 'sim')
tests = sorted(f for f in os.listdir(tdir) if f.endswith(('.s', '.S')))
for f in tests:
    name = f.rsplit('.', 1)[0]
    flags = open(os.path.join(tdir, name + '.flags')).read().split() if os.path.exists(os.path.join(tdir, name + '.flags')) else []
    want = int(open(os.path.join(tdir, name + '.exit')).read()) if os.path.exists(os.path.join(tdir, name + '.exit')) else 0
    for patched in ((False, True) if name in PATCHES else (False,)):
        x, used = build(name, os.path.join(tdir, f), patched)
        if not x: rows.append((name, patched, None, [], used)); continue
        res = []
        for s in STRIPS:
            r = sh([os.path.join(B, 'sim64'), '-S', str(s)] + flags + [x], timeout=300)
            res.append((r.returncode, r.stdout))
        rows.append((name, patched, want, res, used))

lines = ['| test | patched | expected exit | exit at strip 8, 16, 32, 64 | stdout identical at all four | verdict |', '|---|---|---:|---|---|---|']
nsame = 0; ndiff = []
for name, patched, want, res, used in rows:
    if want is None: lines.append('| %s | %s | - | did not build | - | - |' % (name, 'yes' if patched else 'no')); ndiff.append(name); continue
    ex = [r[0] for r in res]; same_out = len({r[1] for r in res}) == 1
    if all(e == want for e in ex) and same_out: verdict = 'same'; nsame += 1
    elif len(set(ex)) == 1 and same_out: verdict = 'same (the exit differs from the expected, as at 32)'; nsame += 1
    else: verdict = 'DIFFERS'; ndiff.append(name + (' (patched)' if patched else ''))
    if name in PATCHES or verdict != 'same':
        lines.append('| %s | %s | %d | %s | %s | %s |' % (name, 'yes' if patched else 'no', want, ' '.join(map(str, ex)), 'yes' if same_out else 'NO', verdict))
head = ['%d programs of tests/sim, each run at 4 strips (the %d tests that look at the strip are run a second time with those checks switched off); %d runs gave the same exit status and standard output at all four strips, %d runs differ; the programs that are not in the table below gave the expected exit status and the same output at all four.' % (len({r[0] for r in rows}), len(PATCHES), nsame, len(ndiff))]
for name, patched, want, res, used in rows:
    if used: head.append('Patched copy of %s switches off: %s.' % (name, '; '.join(used)))
txt = '\n\n'.join(head) + '\n\n' + '\n'.join(lines) + '\n'

# the known reproducibility issue: a floating-point sum depends on the order, so on the strip.  vacc.f of 1000 binary32 values of mixed sign and magnitude (a fixed seed), rounded to binary32 after each strip
import random, struct
random.seed(1)
fl = [struct.unpack('<I', struct.pack('<f', random.uniform(-1, 1) * 10 ** random.randint(-3, 3)))[0] for i in range(1000)]
fps = os.path.join(tmp, 'fpsum.s')
open(fps, 'w').write("\t.text\n\t.globl\t_start\n_start:\tlea\tsrc, r1\n\tmovq\t#1000, r2\n\tlea\t(r1)(r2*4), r4\n\tmovq\t#0, r10\n\tvec\tr1, r4\n\tvld.f\tv0, (r1)+\n\tvacc.f\tr10, v0\n\tvend\n"
    "\tlea\tout, r5\n\tmovl\tr10, (r5)\n\tmovq\t#1, r0\n\tlea\tout, r1\n\tmovq\t#4, r2\n\ttrap\t#1\n\tmovq\t#0, r0\n\ttrap\t#0\n\t.data\nsrc:\n" + ''.join('\t.long\t0x%08x\n' % x for x in fl) + "out:\t.long\t0\n")
sh([os.path.join(B, 'as64'), '-o', fps + '.o', fps]); sh([os.path.join(B, 'ld64'), '-o', fps + '.x', fps + '.o'])
fpres = {}
for st in STRIPS:
    r = subprocess.run([os.path.join(B, 'sim64'), '-S', str(st), fps + '.x'], capture_output=True); fpres[st] = r.stdout[::-1].hex()
txt += '\nvacc.f of 1000 binary32 values (seeded random, mixed sign, 10^-3 to 10^3), the result as binary32 bits by strip: ' + ', '.join('%d: 0x%s' % (st, fpres[st]) for st in STRIPS) + (' (they differ: a floating-point sum depends on the strip)' if len(set(fpres.values())) > 1 else ' (identical)') + '\n'
if os.environ.get('NOLLVM'): print(txt[-400:])
# llvm/check.sh at each strip
chk = {}
for s in (STRIPS if not os.environ.get('NOLLVM') else ()):
    env = dict(os.environ, PDP64_VSTRIP=str(s))
    r = subprocess.run([os.path.join(R, 'llvm', 'check.sh')], capture_output=True, text=True, env=env, timeout=7200)
    chk[s] = [l for l in r.stdout.splitlines() if l.startswith(('ok ', 'FAIL'))]
    summ = [l for l in r.stdout.splitlines() if 'passed' in l]
    chk[s, 'sum'] = summ
if os.environ.get('NOLLVM'):
    open(os.path.join(OUT, 'equiv.md'), 'w').write(txt); print(txt)
    if not os.environ.get('KEEP'): shutil.rmtree(tmp, ignore_errors=True)
    else: print('kept', tmp)
    sys.exit(0)
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
else: print('kept', tmp)
