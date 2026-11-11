"""weightsfile.py -- read a weights file (encopt.5, WEIGHTS FILE) into the keys of the study: (mnemonic, tuple of normalised operands).

`weight KIND COUNT mnemonic operands`, KIND static or dynamic; the operands in the assembly notation, a pc-relative operand as pc+N or pc-N (the bytes from the first parcel of
the instruction to the target), `(dp)` as a base register for d(DP).  A line that starts with # is a comment (an immediate operand has a # inside the line).
"""
import os, re, sys, collections
HERE = os.path.dirname(os.path.abspath(__file__))
ENC = os.path.join(HERE, '..', '..', 'docs', 'codegen-data', 'encoding')
sys.dont_write_bytecode = True
if ENC not in sys.path: sys.path.insert(0, ENC)
import m2


def parse_key(text):
    """an instruction of a weights file -> the key of the study: (mnemonic, tuple of normalised operands); None if it cannot be read"""
    import norm
    w = text.strip().split(None, 1)
    mn = w[0]; ops = m2.splitops(w[1]) if len(w) > 1 else []
    out = []
    for o in ops:
        o = o.replace('(dp)', '(r255)')
        mm = re.match(r'^pc([+-]\d+)$', o)
        if mm: out.append(('PC', int(mm.group(1)), 'sym')); continue
        k = m2.kind(o)
        if k == 'pcrel': return None
        out.append(norm.op_norm(o, k, None, 0, False))
    if mn in ('pushm', 'popm', 'fx_popmret', 'popmret') and out and out[0][0] == 'I': out = [('I', out[0][1] & 0xFFFFFFFF)]
    return mn, tuple(out)


def read_weights(files):
    st = collections.Counter(); dy = collections.Counter(); bad = 0
    for fn in files:
        first = True
        for line in open(fn):
            line = line.strip()
            if not line or line[0] == '#': continue        # a comment is a line that starts with # (an immediate operand has one inside the line)
            if first:
                if line.split() != ['encopt-weights', '1']: raise SystemExit('%s: not a weights file (first line must be `encopt-weights 1`)' % fn)
                first = False; continue
            t = line.split(None, 3)
            if len(t) < 4 or t[0] != 'weight' or t[1] not in ('static', 'dynamic'): raise SystemExit('%s: cannot read: %s' % (fn, line))
            key = parse_key(t[3])
            if key is None: bad += 1; continue
            (st if t[1] == 'static' else dy)[key] += int(t[2])
    if bad: sys.stderr.write('export: %d lines of the weights files have an operand that is not an operand of the assembly (skipped)\n' % bad)
    return st, dy


