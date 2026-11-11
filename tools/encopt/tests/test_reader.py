#!/usr/bin/env python3
"""test_reader.py -- the corrected reader of the exporter (corpusfix.py) against the study's reader (docs/codegen-data/encoding/m2.py).

`set cc,rd` and the system-register moves take a word as an operand: the old reader took it for a label (a pc-relative operand), so no form fitted the instruction and it counted as
unencodable (342 of the 296,069 instructions of the corpus of 2026-11-10, e.g. `set eq,r0`).  The test reads tests/corpus/words.s with both and checks: the old reader
reads the words as labels (the bug is still there in the history script, which is not edited); the corrected one reads them as numbers of the grammar; the model finds a form for every one of them and the
numbers are those of the grammar (spec/pdp64-mnemonics.hbnf); the condition in the numbering of the branches (`bne` and `set ne` take 1).
usage: test_reader.py              exit status 0 when all agree"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.join(HERE, '..'))
import corpusfix, m2
import norm, enc
from variants import *
from export_forms import FZ
SRC = os.path.join(HERE, 'corpus', 'words.s')
bad = 0
def check(c, msg):
    global bad
    if not c: print('FAIL ' + msg); bad += 1

ev, recs = corpusfix._orig_parse(SRC)
old = [r for r in recs if r['mn'] in ('set', 'mfsr', 'mtsr')]
check(len(old) == 10, 'the test corpus has 10 word instructions, found %d' % len(old))
check(all('pcrel' in r['k'] for r in old), 'the study\'s reader no longer reads the words as labels (the test of the bug)')
ev, recs = m2.parse(SRC)          # corpusfix has replaced it
new = [r for r in recs if r['mn'] in ('set', 'mfsr', 'mtsr')]
check(all('pcrel' not in r['k'] for r in new), 'the corrected reader still reads a word as a label')
check(corpusfix.STATS['set'] == 7 and corpusfix.STATS['mfsr'] == 2 and corpusfix.STATS['mtsr'] == 1, 'fixed counts %s' % dict(corpusfix.STATS))
keys = [norm.inst_of(r, None) for r in new]
want = [('set', (('I', 2), ('R', 0))), ('set', (('I', 1), ('R', 0))), ('set', (('I', 2), ('R', 1))), ('set', (('I', 8), ('R', 4))), ('set', (('I', 14), ('R', 0))),
        ('set', (('I', 7), ('R', 2))), ('set', (('I', 0), ('R', 3))), ('mfsr', (('R', 1), ('I', 0))), ('mfsr', (('R', 2), ('I', 12))), ('mtsr', (('I', 9), ('R', 3)))]
check(keys == want, 'keys %s' % keys)
# the cb and call lines are untouched: a label stays a label
cbs = [r for r in recs if r['mn'].startswith('cb') or r['mn'] == 'call']
check(all(r['k'][-1] == 'pcrel' for r in cbs if r['mn'].startswith('cb')) and cbs[-1]['k'] == ['pcrel'], 'a label operand changed')
# the model: the forced forms encode every one of them

R = SR(5); H3 = SR(3, list(range(8))); H4 = SR(4, list(range(16)))
forced, _ = mk(R, H3, H4)
sc = Scheme(forced + [Form('RR5', 1, ['movq', 'movl', 'add', 'sub', 'xor', 'and', 'bis', 'shl'], [R, R])])
for k in keys:
    check(sc.size1(k[0], k[1]) is not None, 'no form encodes %s' % (k,))
# the old reading is not encodable: the same instruction with a label operand
old_keys = [norm.inst_of(r, 0) for r in old]
check(all(sc.size1(k[0], k[1]) is None for k in old_keys if k[0] == 'set'), 'the label reading of `set` should have no form')
print('reader: %d word instructions read as numbers, all encodable; the study\'s reader reads them as labels (%d unencodable)' % (len(keys), sum(1 for k in old_keys if sc.size1(k[0], k[1]) is None)))
# the weights file: the notation of encdis -k, and the profile of the repository (tests/profile.weights) has no line that cannot be read
import weightsfile
P = weightsfile.parse_key
check(P('cbeq r3,#5,pc+12') == ('cbeq', (('R', 3), ('I', 5), ('PC', 12, 'sym'))), 'parse cb')
check(P('movq -8(sp),r1') == ('movq', (('B', -8, 14), ('R', 1))), 'parse based')
check(P('movq 4(r2)(r3*8),fp') == ('movq', (('X', 4, 2, 3, 8), ('R', 13))), 'parse indexed')
check(P('movq (r2)+8,r1') == ('movq', (('PI', 2, 8), ('R', 1))) and P('movq r1,(r2)-8') == ('movq', (('R', 1), ('PD', 2, 8))), 'parse postinc/predec')
check(P('movq 8(dp),r1') == ('movq', (('B', 8, 255), ('R', 1))), 'parse dp base')
check(P('movq @4096,r1') == ('movq', (('A', 4096), ('R', 1))) and P('ret') == ('ret', ()) and P('set #2,r0') == ('set', (('I', 2), ('R', 0))), 'parse absolute, none, set')
check(P('call foo') is None, 'a label is not an operand of a weights file')
st, dy = weightsfile.read_weights([os.path.join(HERE, 'profile.weights')])
check(not st and len(dy) == 5069 and sum(dy.values()) == 135177729, 'tests/profile.weights: %d keys %d executed' % (len(dy), sum(dy.values())))
sys.exit(1 if bad else 0)
