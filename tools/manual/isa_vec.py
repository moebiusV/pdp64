"""Dictionary entries, part 5: the vec block (docs/encoding-work/vec-isa.md; wave 1 of the revised family, errata 170, removed the tile, the GEMM unit and the gather).

The words come from the catalogue of the encoding, docs/codegen-data/encoding/vecfam.py, so removing an instruction there (a dud, after the benchmarks) removes its word
here too; the text is by family.  The family was added to be benchmarked and pruned, the encodings are provisional, and every entry is tagged (P): held back
by isa_entries.HELD and not printed in the manual until the benchmarks have kept it.  The semantics are those of vec-isa.md."""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'docs', 'codegen-data', 'encoding'))
from isa_common import *
from enc import SR
import vecfam
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import facts

ALLW = sorted({w for f in vecfam.vec_forms(SR(5)) for w in f.mns})
P = '*(P)* Added to the design to be benchmarked and pruned; the encoding is provisional (a forced form of the prefix grammar, no usage weights). '
DEXC = 'None beyond the faults of its memory operand.'
DCF = '9.15 (the block operations restart), the vector study (`docs/encoding-work/vec-isa.md`).'

# The entries are data: spec/facts/vec.toml.  A base names its entry (`entry`); the first base of an entry carries the text (title, syntax, op, notes, and exc, cf
# where they are not the defaults above) and the position of the entry in the chapter (`entry_seq`).
_F = facts.load('vec')


def _entries():
    out = []
    for lead, t in sorted(((b, t) for b, t in _F.items() if 'title' in t), key=lambda x: x[1]['entry_seq']):
        bases = {b for b, u in _F.items() if u['entry'] == t['entry']}
        ns = [w for w in ALLW if w.split('.')[0] in bases]
        if ns:
            out.append(E(t['entry'], 'vec', ns, t['title'], t['syntax'], t['op'], NOFLAGS, t.get('exc', DEXC), '9.22', notes=P + t['notes'], cf=t.get('cf', DCF)))
    return out


ENTRIES = _entries()
