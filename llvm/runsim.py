#!/usr/bin/env python3
"""
runsim -- the object files of llvm-mc, linked by ld64 and run by sim64 (milestone S5).

Every tests/sim/*.s and *.S is assembled with llvm-mc instead of as64, linked with build/ld64 and run under build/sim64 with the
test's own flags; the exit status and the output must be what tools/check-sim64.sh expects (NAME.exit, NAME.out).
"""
import os, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..'))
sys.path.insert(0, HERE)
import oracle


def main():
    B = os.path.join(ROOT, os.environ.get('BUILD', 'build'))
    mc = os.environ.get('LLVM_MC', os.path.expanduser('~/claude/llvm-build/bin/llvm-mc'))
    d = os.path.join(ROOT, 'tests', 'sim')
    names = sorted(f for f in os.listdir(d) if f.endswith(('.s', '.S')))
    if len(sys.argv) > 1:
        names = [n for n in names if os.path.splitext(n)[0] in sys.argv[1:]]
    ok = bad = skip = 0
    for f in names:
        t = os.path.splitext(f)[0]
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(d, f)
            try:
                if f.endswith('.S'):
                    path = oracle.preprocess(path, tmp)
                src = oracle.translate(open(path).read())
            except oracle.Skip as e:
                print('skip  %s: %s' % (t, e)); skip += 1; continue
            lf, o, x = os.path.join(tmp, 't.s'), os.path.join(tmp, 't.o'), os.path.join(tmp, 't.x')
            open(lf, 'w').write(src)
            r = oracle.run([mc, '-triple=' + oracle.TRIPLE, '-filetype=obj', '-o', o, lf])
            if r.returncode:
                print('FAIL  %s: llvm-mc: %s' % (t, r.stderr.strip().split('\n')[0])); bad += 1; continue
            r = oracle.run([os.path.join(B, 'ld64'), '-o', x, o])
            if r.returncode:
                print('FAIL  %s: ld64: %s' % (t, r.stderr.strip().split('\n')[0])); bad += 1; continue
            flags = open(os.path.join(d, t + '.flags')).read().split() if os.path.exists(os.path.join(d, t + '.flags')) else []
            r = oracle.run([os.path.join(B, 'sim64')] + flags + [x])
            want = int(open(os.path.join(d, t + '.exit')).read()) if os.path.exists(os.path.join(d, t + '.exit')) else 0
            good = r.returncode == want
            if os.path.exists(os.path.join(d, t + '.out')) and open(os.path.join(d, t + '.out')).read() != r.stdout:
                good = False
            if good:
                print('ok    %s' % t); ok += 1
            else:
                print('FAIL  %s: exit %d, wanted %d %s' % (t, r.returncode, want, r.stderr.strip()[:100])); bad += 1
    print('sim64 on llvm-mc objects: %d ok, %d failed, %d skipped' % (ok, bad, skip))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
