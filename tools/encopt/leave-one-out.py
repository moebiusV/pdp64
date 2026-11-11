#!/usr/bin/env python3
"""leave-one-out.py -- how much of the gain of a profile-trained optimum is overfitting: train on all programs but one, measure on the one.

  leave-one-out.py --corpus DIR --weights-dir DIR [--objective fetch] [--budget 1.0]

DIR/NAME.weights is the profile of one program (profile.py -o ... --program NAME=...; make-profile.sh writes the combined file, so run profile.py once per program for this).  For each
program P: export the corpus with the profiles of the others, run encopt with the objective, then export the corpus with the profile of P alone, replace its `committed` lines
by the chosen candidates, and let encopt -C measure that selection: the measures are those of P under a selection that never saw P.  The committed grammar's measures of P are
the baseline.  Prints one line per program.
"""
import argparse, glob, os, re, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ap = argparse.ArgumentParser()
ap.add_argument('--corpus', required=True); ap.add_argument('--weights-dir', required=True)
ap.add_argument('--objective', default='fetch'); ap.add_argument('--budget', default='1.0')
a = ap.parse_args()
progs = sorted(os.path.basename(f)[:-8] for f in glob.glob(os.path.join(a.weights_dir, '*.weights')))
enc = os.path.join(HERE, 'encopt')
def export(ws, out):
    cmd = [sys.executable, '-I', os.path.join(HERE, 'export.py'), '--corpus', a.corpus, '--budget', a.budget, '--out', out]
    for w in ws: cmd += ['--weights', os.path.join(a.weights_dir, w + '.weights')]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode: raise SystemExit(r.stderr)
def metrics(text, name):
    m = re.search(r'^metrics %s static-bytes (\d+) fetch-bytes (\d+) operations (\d+)' % name, text, re.M)
    return tuple(int(x) for x in m.groups())
print('objective %s, budget %s: held-out program, fetch bytes under the committed grammar, under the optimum trained on all (seen), under the optimum trained on the others (unseen)' % (a.objective, a.budget))
with tempfile.TemporaryDirectory() as td:
    export(progs, td + '/all.encopt')
    allout = subprocess.run([enc, '-q', '-O', a.objective, td + '/all.encopt'], capture_output=True, text=True).stdout
    for p in progs:
        export([q for q in progs if q != p], td + '/train.encopt')
        out = subprocess.run([enc, '-q', '-O', a.objective, td + '/train.encopt'], capture_output=True, text=True).stdout
        chosen = re.findall(r'^chosen (\S+)', out, re.M)
        export([p], td + '/test.encopt')
        base = subprocess.run([enc, '-q', '-C', td + '/test.encopt'], capture_output=True, text=True).stdout
        lines = [l for l in open(td + '/test.encopt') if not l.startswith('committed ')] + ['committed %s\n' % c for c in chosen]
        open(td + '/test2.encopt', 'w').writelines(lines)
        unseen = subprocess.run([enc, '-q', '-C', td + '/test2.encopt'], capture_output=True, text=True).stdout
        chosen_all = re.findall(r'^chosen (\S+)', allout, re.M)
        lines = [l for l in open(td + '/test.encopt') if not l.startswith('committed ')] + ['committed %s\n' % c for c in chosen_all]
        open(td + '/test3.encopt', 'w').writelines(lines)
        seen = subprocess.run([enc, '-q', '-C', td + '/test3.encopt'], capture_output=True, text=True).stdout
        b, s, u = metrics(base, 'committed')[1], metrics(seen, 'committed')[1], metrics(unseen, 'committed')[1]
        print('%-8s committed %12d   seen %12d (%+.2f%%)   unseen %12d (%+.2f%%)' % (p, b, s, 100.0 * (s - b) / b, u, 100.0 * (u - b) / b))
