#!/usr/bin/env python3
"""profile.py -- the profile collector of encopt: run programs under sim64 and write the dynamic counts per distinct instruction as a weights file (encopt.5).

  profile.py -o WEIGHTS [--tests DIR]... [--program NAME=FILE[,FILE...] [--cppflags NAME=FLAGS] ...] [--runtime FILE.s] [--keep DIR]

  --tests DIR      every DIR/*.c is a test program of tools/pdp64test.sh (`int test(void)`, first line `/* expect: N */`): compiled with build/pcc/ccom, linked with the
                   same driver main and crt, run under sim64.  A test whose result differs from the expectation is not counted.
  --program N=F..  a program that is made of preprocessed C files (the `.i` of tools/arch-compare/prep.py, or any C that ccom reads) and has its own `main`; it is linked
                   with the crt of --runtime (default: the crt of pdp64test.sh without a driver main).  Its standard output is written to OUT.N.stdout
  --keep DIR       keep the intermediate files (assembly, objects, executables, the -P profiles) in DIR

How: `sim64 -P` counts the executed instructions per pc (docs/encoding-work/phase2.md); `encdis -k` decodes the instruction at each counted pc with the codec of the
repository (common/pdp64enc.c) and writes `weight dynamic COUNT mnemonic operands` lines, the operands in the notation export.py reads (a pc-relative operand as pc+N, the bytes
from the first parcel to the target).  Nothing in sim64 changes: its profile is the existing one.  Needs build/as64, build/ld64, build/sim64 (tools/build-sim64.sh) and build/pcc/ccom
(tools/build-pcc.sh).  encdis is compiled into a temporary directory from tools/encdis.c.

The counts are those of the linked programs, so the pc-relative distances and the absolute addresses of an instruction are the linker's; two copies of an instruction that differ
only in such a value are two instructions of the profile, as in the corpus.  The program's own start code, its driver main and the stubs are counted with it.
"""
import argparse, collections, glob, os, re, shlex, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
B = os.path.join(ROOT, 'build')
CPP = ['gcc', '-E', '-P', '-undef', '-D__pcc__', '-D__LP64__', '-D_LP64']

DRIVER = r'''
int test(void);
long write(int, char *, long);
int main(void)
{
	char b[24];
	char *p = b + 24;
	long v = test();
	int neg = v < 0;
	unsigned long u = neg ? -(unsigned long)v : (unsigned long)v;
	*--p = '\n';
	do { *--p = '0' + (int)(u % 10); u /= 10; } while (u);
	if (neg) *--p = '-';
	write(1, p, b + 24 - p);
	return 0;
}
'''
CRT = '''	.text
	.globl	_start
_start:	call	main
	trap	#0
	.globl	write
write:	trap	#1
	ret
	.globl	read
read:	trap	#2
	ret
%s'''
CRT_MEM = '''	.globl	memcpy
memcpy:	movq	r0, r3
	mcpy	r0, r1, r2
	movq	r3, r0
	ret
	.globl	memmove
memmove: movq	r0, r3
	mmov	r0, r1, r2
	movq	r3, r0
	ret
	.globl	memset
memset:	movq	r0, r3
	mset	r0, r1, r2
	movq	r3, r0
	ret
'''


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, errors='replace', **kw)


def build_encdis(tmp):
    exe = os.path.join(tmp, 'encdis')
    r = run(['gcc', '-g', '-w', '-std=gnu11', '-I' + os.path.join(ROOT, 'asm64'), '-I' + os.path.join(ROOT, 'common'), '-I' + B, '-o', exe, os.path.join(ROOT, 'tools', 'encdis.c'),
             os.path.join(ROOT, 'common', 'pdp64enc.c'), os.path.join(B, 'pdp64-tab.c')])
    if r.returncode: raise SystemExit('encdis: ' + r.stderr[:500])
    return exe


def defined_in(asm, name):
    return re.search(r'^%s:' % re.escape(name), asm, re.M) is not None


def link_run(tmp, name, asms, crt_extra, encdis, ccom_flags=(), stdout_to=None):
    objs = []
    for i, s in enumerate(asms):
        o = os.path.join(tmp, '%s.%d.o' % (name, i))
        r = run([os.path.join(B, 'as64'), '-o', o, s])
        if r.returncode: return None, 'as64: ' + r.stderr.strip()[:200]
        objs.append(o)
    x = os.path.join(tmp, name + '.x'); prof = os.path.join(tmp, name + '.prof')
    r = run([os.path.join(B, 'ld64'), '-o', x] + objs)
    if r.returncode: return None, 'ld64: ' + r.stderr.strip()[:200]
    r = run([os.path.join(B, 'sim64'), '-P', prof, x], timeout=3600)
    if stdout_to: open(stdout_to, 'w').write(r.stdout)
    if not os.path.exists(prof): return None, 'sim64: no profile (exit %d) %s' % (r.returncode, r.stderr.strip()[:200])
    k = run([encdis, '-k', prof, x])
    if k.returncode: return None, 'encdis: ' + k.stderr.strip()[:200]
    tot = {}
    for l in open(prof):
        if l.startswith('#instructions') or l.startswith('#bytes'): tot[l.split()[0][1:]] = int(l.split()[1])
    return (r.stdout, r.returncode, k.stdout, tot), ''


def compile_c(tmp, name, src, ccom_flags, preprocessed=False, cppflags=()):
    s = os.path.join(tmp, name + '.s')
    if not preprocessed:
        i = os.path.join(tmp, name + '.i')
        p = run(CPP + list(cppflags) + [src])
        if p.returncode: return None, 'cpp: ' + p.stderr.strip()[:200]
        open(i, 'w').write(p.stdout)
    else:
        i = src
    r = run([os.path.join(B, 'pcc', 'ccom')] + list(ccom_flags) + [i, s])
    if r.returncode or not os.path.exists(s) or not os.path.getsize(s): return None, 'ccom: ' + (r.stderr.strip().split('\n') or [''])[0][:200]
    return s, ''


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('-o', '--out', required=True)
    ap.add_argument('--tests', action='append', default=[])
    ap.add_argument('--program', action='append', default=[])
    ap.add_argument('--runtime')
    ap.add_argument('--cppflags', action='append', default=[], metavar='NAME=FLAGS', help='extra preprocessor flags for the .c files of the program NAME (include directories of the library, -D); the .i files are taken as they are')
    ap.add_argument('--keep')
    ap.add_argument('--summary', help='write one line per program: name, status, executed instructions, executed bytes')
    a = ap.parse_args()
    for t in ('as64', 'ld64', 'sim64', os.path.join('pcc', 'ccom')):
        if not os.path.exists(os.path.join(B, t)): raise SystemExit('profile.py: build/%s is missing (tools/build-sim64.sh, tools/build-pcc.sh)' % t)
    w = collections.Counter(); summary = []; counted = skipped = 0
    with tempfile.TemporaryDirectory() as td:
        tmp = a.keep or td
        os.makedirs(tmp, exist_ok=True)
        encdis = build_encdis(td)
        open(os.path.join(tmp, '_driver.c'), 'w').write(DRIVER)
        drv_s, e = compile_c(tmp, '_driver', os.path.join(tmp, '_driver.c'), [])
        if not drv_s: raise SystemExit('profile.py: the driver does not compile: ' + e)

        def add(name, res, expect=None):
            nonlocal counted, skipped
            out, rc, wtxt, tot = res
            if expect is not None and out.strip().split('\n')[-1:] != [expect]:
                skipped += 1; summary.append('%s\tWRONG\t%s' % (name, out.strip()[-40:])); return
            got = 0
            for l in wtxt.splitlines():
                if l.startswith('weight dynamic '):
                    _, _, n, key = l.split(None, 3); w[key] += int(n); got += int(n)
            if got != tot.get('instructions'): raise SystemExit('profile.py: %s: the decoded counts add up to %d, sim64 -P says %d instructions' % (name, got, tot.get('instructions', -1)))
            counted += 1; summary.append('%s\tok\t%d\t%d' % (name, tot.get('instructions', 0), tot.get('bytes', 0)))

        for d in a.tests:
            for src in sorted(glob.glob(os.path.join(d, '*.c'))):
                name = os.path.basename(src)[:-2]
                m = re.match(r'/\* expect: (-?\d+)', open(src, errors='replace').readline())
                s, e = compile_c(tmp, name, src, [])
                if not s: skipped += 1; summary.append('%s\tFAIL\t%s' % (name, e)); continue
                nomem = defined_in(open(s).read(), 'memcpy')
                crt = os.path.join(tmp, name + '.crt.s'); open(crt, 'w').write(CRT % ('' if nomem else CRT_MEM))
                res, e = link_run(tmp, name, [crt, drv_s, s], '', encdis)
                if res is None: skipped += 1; summary.append('%s\tFAIL\t%s' % (name, e)); continue
                add(name, res, m.group(1) if m else None)
        cpp = {c.split('=', 1)[0]: shlex.split(c.split('=', 1)[1]) for c in a.cppflags}
        for spec in a.program:
            name, files = spec.split('=', 1)
            asms = []; bad = ''
            for i, f in enumerate(files.split(',')):
                s, e = compile_c(tmp, '%s.%d' % (name, i), f, [], preprocessed=f.endswith('.i'), cppflags=cpp.get(name, []))
                if not s: bad = '%s: %s' % (f, e); break
                asms.append(s)
            if bad: skipped += 1; summary.append('%s\tFAIL\t%s' % (name, bad)); continue
            if a.runtime: crt = a.runtime
            else:
                crt = os.path.join(tmp, name + '.crt.s'); open(crt, 'w').write(CRT % CRT_MEM)
            res, e = link_run(tmp, name, [crt] + asms, '', encdis, stdout_to=a.out + '.' + name + '.stdout')
            if res is None: skipped += 1; summary.append('%s\tFAIL\t%s' % (name, e)); continue
            add(name, res)
    with open(a.out, 'w') as f:
        f.write('encopt-weights 1\n# written by profile.py: %d programs counted, %d skipped; %d distinct instructions, %d executed\n' % (counted, skipped, len(w), sum(w.values())))
        for key, n in sorted(w.items()): f.write('weight dynamic %d %s\n' % (n, key))
    txt = '\n'.join(summary) + '\n'
    if a.summary: open(a.summary, 'w').write(txt)
    sys.stderr.write('profile: %d programs counted, %d skipped, %d distinct instructions, %d instructions executed\n' % (counted, skipped, len(w), sum(w.values())))
    for l in summary:
        if '\tok\t' not in l: sys.stderr.write('  ' + l + '\n')


main()
