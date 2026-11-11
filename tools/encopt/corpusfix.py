"""corpusfix.py -- the corrected reader of the compiled assembly, for export.py (the history scripts of docs/codegen-data/encoding stay as they are).

The study's reader (docs/codegen-data/encoding/m2.py) classifies an operand by its shape, so a word that is no register, number or memory form is a label (a
pc-relative operand).  Two groups of instructions take a word of their own as an operand (spec/pdp64-asm.hbnf: `condinsn`, `srinsn`):

  set CC, rd        the condition code (`ne eq pl mi vc vs cc cs ge lt gt le hi los`, aliases `hs lo`, and `al`), then a register
  mfsr rd, SREG     the system register by name (`ptbr epc eva ecause dmw0 dmw1 usp ssp epsw vbr mmuctl asid cpuid`), as the register of the instruction;
  mtsr SREG, rs     the numbers are those of spec/pdp64-mnemonics.hbnf

The old reader took the word for a label, so `set eq,r0` had a label operand and no form fitted it: 342 instructions of the corpus counted as unencodable in every
figure.  Here the word becomes its number as an immediate (`#2` for eq: the form SETF has the condition as a 4-bit unsigned field in the numbering of the
branches, which is the grammar's `cc` numbering) and the operand kind `imm`; the `trapcc.CC` and `cbCC` instructions carry the condition in the mnemonic and have no
such operand, `cb` forms have a label as their last operand and no condition word.  No other mnemonic of the grammar has a word operand.

Use: `import corpusfix` before the first import of `load` or `variants` (it replaces `m2.parse`, which `load` binds by name); `corpusfix.STATS` counts what was fixed.
"""
import os, re, sys, collections
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
ENC = os.path.join(ROOT, 'docs', 'codegen-data', 'encoding')
sys.dont_write_bytecode = True
if ENC not in sys.path: sys.path.insert(0, ENC)
import m2

STATS = collections.Counter()


def _numbers(spec_file, rule):
    """name -> number of the alternatives `"name"@N` of a rule of the grammar (the first rule of that name)"""
    out = {}
    cur = None
    for line in open(spec_file):
        code = line.split(';')[0]
        mm = re.match(r'^([a-z][\w-]*)\s*=', code)
        if mm: cur = mm.group(1)
        if cur == rule:
            for name, num in re.findall(r'"([a-z0-9]+)"@(0b[01]+|0x[0-9a-fA-F]+|\d+)', code): out[name] = int(num, 0)
    return out


MN = os.path.join(ROOT, 'spec', 'pdp64-mnemonics.hbnf')
CC = _numbers(MN, 'cc'); CC.update(_numbers(MN, 'ccalias'))
SREG = _numbers(MN, 'sysreg')
assert CC.get('eq') == 2 and CC.get('los') == 14 and SREG.get('ptbr') == 0, 'the grammar tables of spec/pdp64-mnemonics.hbnf were not read'

_orig_parse = m2.parse


def _word(r, i, table):
    """operand i of the record r is a word of `table`: make it the number, as an immediate"""
    o = r['ops'][i]
    if r['k'][i] == 'pcrel' and o in table:
        r['ops'][i] = '#%d' % table[o]; r['k'][i] = 'imm'
        r['lab'] = None; r['off'] = 0
        return True
    return False


def parse(path):
    ev, recs = _orig_parse(path)
    for r in recs:
        mn = r['mn']
        if mn == 'set' and r['ops'] and _word(r, 0, CC): STATS['set'] += 1
        elif mn == 'mfsr' and len(r['ops']) == 2 and _word(r, 1, SREG): STATS['mfsr'] += 1
        elif mn == 'mtsr' and len(r['ops']) == 2 and _word(r, 0, SREG): STATS['mtsr'] += 1
    return ev, recs


m2.parse = parse
