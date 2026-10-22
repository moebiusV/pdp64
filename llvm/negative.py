#!/usr/bin/env python3
"""
negative -- what as64 refuses (tests/asm-err/*.s), llvm-mc must refuse too.

Programs that use the literal pool (=K, .pool) are skipped: LLVM's MC has no pool.  The messages differ; only the refusal is compared.
"""
import os, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..'))
sys.path.insert(0, HERE)
import oracle


def main():
    mc = os.environ.get('LLVM_MC', os.path.expanduser('~/claude/llvm-build/bin/llvm-mc'))
    d = os.path.join(ROOT, 'tests', 'asm-err')
    ok = bad = skip = 0
    for f in sorted(os.listdir(d)):
        if not f.endswith('.s'):
            continue
        path = os.path.join(d, f)
        try:
            src = oracle.translate(open(path).read())
        except oracle.Skip as e:
            print('skip  %s: %s' % (f, e))
            skip += 1
            continue
        with tempfile.TemporaryDirectory() as tmp:
            lf = os.path.join(tmp, 't.s')
            open(lf, 'w').write(src)
            r = oracle.run([mc, '-triple=' + oracle.TRIPLE, '-filetype=obj', '-o', os.path.join(tmp, 't.o'), lf])
        want = open(path[:-2] + '.err').read().strip()
        if r.returncode != 0:
            ok += 1
            print('ok    %s: %s' % (f, r.stderr.strip().split('\n')[0].split(': ', 1)[-1][:90]))
        else:
            bad += 1
            print('FAIL  %s: llvm-mc accepts it (as64: %s)' % (f, want))
    print('%d refused as they should be, %d accepted, %d skipped' % (ok, bad, skip))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
