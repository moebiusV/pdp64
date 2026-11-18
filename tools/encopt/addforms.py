#!/usr/bin/env python3
"""addforms.py -- the committed grammar plus the forced forms of the vec, tile and GEMM family (docs/codegen-data/encoding/vecfam.py), without the corpus.

The prefix optimiser (export.py --write-grammar) needs the 841-file corpus compiled by pcc; this builds the same grammar from the committed one: it keeps every form,
drops the candidate forms named by --drop (they are chosen by tools/encopt/vecdrop.py from the value of each candidate per first-parcel pattern in the statistics of
tests/current.encopt: the least valuable go first), adds the forced forms of vecfam.py, and writes the grammar with the writer the optimiser uses.  The encodings of the
family are provisional by design (no usage weights: nothing emits these instructions yet): they are to be benchmarked and pruned, and the optimiser is to be run again on
the corpus compiled by the LLVM back end.

  addforms.py --grammar-out DIR [--drop NAME]... [--drop-file FILE]

  then  cp DIR/pdp64-enc.hbnf spec/ ; cp DIR/pdp64-32/pdp64-32.hbnf spec/pdp64/pdp64.hbnf   (as export.py --write-grammar says)
"""
import sys, os, json, argparse
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
ENC = os.path.join(ROOT, 'docs', 'codegen-data', 'encoding')
sys.dont_write_bytecode = True
sys.path.insert(0, ENC)
sys.path.insert(0, os.path.join(ROOT, 'tools'))
sys.path.insert(0, HERE)
ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
ap.add_argument('--grammar-out', required=True)
ap.add_argument('--drop', action='append', default=[])
ap.add_argument('--drop-file')
ap.add_argument('--corpus', default='')
a = ap.parse_args()
os.environ['PDP64_CORPUS_DIR_R32'] = a.corpus
os.environ['PDP64_NO_CORPUS'] = '1'
import encgram, enc
from enc import *
import importlib.util
spec = importlib.util.spec_from_file_location('chk', os.path.join(ROOT, 'tools', 'check-enc.py'))
chk = importlib.util.module_from_spec(spec); spec.loader.exec_module(chk)
from variants import Scheme
import vecfam, export_forms, write_hbnf

drops = set(a.drop)
if a.drop_file:
    drops |= {l.strip() for l in open(a.drop_file) if l.strip()}
d = encgram.load()
forms = [Form(f['name'], f['n'], f['mns'], [chk.mkspec(s) for s in f['specs']], xbits=f['xbits']) for f in d['forms']]
known = {f.name for f in forms}
# idempotent: a form already dropped is not an error, and the forms of the family that the grammar already has are replaced by the ones vecfam.py makes now
for n in sorted(drops - known):
    print('addforms: %s is not in the grammar (already dropped)' % n)
vec = vecfam.vec_forms(SR(5))
vnames = {f.name for f in vec}
forms = [f for f in forms if f.name not in drops and f.name not in vnames] + vec
sc = Scheme(forms)
print('addforms: %d forms (%d dropped, %d added), %d leaves, kraft %.5f (%d of 65536 patterns)' % (len(sc.forms), len(drops), len(vec), len(sc.code.leaves), sc.code.kraft, round(sc.code.kraft * 65536)))
hot = d['hot16']
dd = json.loads(json.dumps(export_forms.export('32', sc, 'r32', hot), default=str))
write_hbnf.write_all(a.grammar_out, [('32', dd)])
print('addforms: written to %s' % a.grammar_out)
