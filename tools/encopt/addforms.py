#!/usr/bin/env python3
"""addforms.py -- the committed grammar plus the forced forms of the vec, tile and GEMM family (docs/codegen-data/encoding/vecfam.py), without the corpus.

The prefix optimiser (export.py --write-grammar) needs the 841-file corpus compiled by pcc; this builds the same grammar from the committed one: it keeps every form,
drops the candidate forms named by --drop (they are chosen by tools/encopt/vecdrop.py from the value of each candidate per first-parcel pattern in the statistics of
tests/current.encopt: the least valuable go first), adds the forced forms of vecfam.py, and writes the grammar with the writer the optimiser uses.  The encodings of the
family are provisional by design (no usage weights: nothing emits these instructions yet): they are to be benchmarked and pruned, and the optimiser is to be run again on
the corpus compiled by the LLVM back end.

  addforms.py --grammar-out DIR [--drop NAME]... [--drop-file FILE]

  then  cp DIR/pdp64-enc.hbnf spec/ ; cp DIR/pdp64-32/pdp64-32.hbnf spec/pdp64/pdp64.hbnf   (as export.py --write-grammar says)

The writer (write_hbnf.py) has the text of the first generation of the grammars: the header comments, the name of the member (pdp64/32) and the title of an operand
shape.  The grammars are edited by hand from then on, so this keeps what is in the committed files (spec/pdp64-enc.hbnf, spec/pdp64/pdp64.hbnf) and replaces
only what the forms decide: the forms, leaves, mnemonics, counts and the comments that carry them.  Run on the committed grammar with no change to vecfam.py it
writes the same bytes (tools/check-grammar-enc.sh checks that).  See errata 177.
"""
import sys, os, json, argparse, re, difflib
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


def keep_hand_text(new_path, old_path, member):
    """Rewrite the generated file new_path so that the text the generator should not decide is the committed text of old_path."""
    new = open(new_path).read().split('\n')
    old = open(old_path).read().split('\n')
    if member:
        # the header (up to the first `prefix none`) and the name are the committed ones; the counts of the first line are the new ones
        h = old.index('prefix none')
        m = re.search(r'-- (\d+ registers \(r0-r\d+\), \d+ forms, \d+ leaves)', new[0])
        out = [re.sub(r'\d+ registers \(r0-r\d+\), \d+ forms, \d+ leaves', m.group(1), old[0])] + old[1:h] + new[new.index('prefix none'):]
        nm = [i for i, l in enumerate(out) if l.startswith('encoding-name = ')]
        on = [l for l in old if l.startswith('encoding-name = ')]
        assert len(nm) == 1 and len(on) == 1
        out[nm[0]] = on[0]
    else:
        # a block of comment lines that the generator words differently is the committed one
        out = []
        for op, i1, i2, j1, j2 in difflib.SequenceMatcher(None, old, new, autojunk=False).get_opcodes():
            if op == 'replace' and all(l.startswith(';') for l in old[i1:i2] + new[j1:j2]):
                out += old[i1:i2]
            else:
                out += new[j1:j2]
    open(new_path, 'w').write('\n'.join(out))


keep_hand_text(os.path.join(a.grammar_out, 'pdp64-enc.hbnf'), os.path.join(ROOT, 'spec', 'pdp64-enc.hbnf'), False)
keep_hand_text(os.path.join(a.grammar_out, 'pdp64-32', 'pdp64-32.hbnf'), os.path.join(ROOT, 'spec', 'pdp64', 'pdp64.hbnf'), True)
print('addforms: written to %s' % a.grammar_out)
