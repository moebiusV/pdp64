#!/usr/bin/env python3
"""Writes the pairs for tests/p2diff.c: for every page-2 opcode and every reg and low field, the page-2 word (from the specification's table, CHANGES
section 12) and the parcels of the abbreviated instruction as as64 --no-p2 assembles it from its text.  usage: p2diff.py AS64 OUTFILE"""
import os, struct, subprocess, sys, tempfile
AS, OUT = sys.argv[1], sys.argv[2]
def sext4(v): return v - 16 if v >= 8 else v
def text(opc, reg, low):
    r, l = 'r%d' % reg, 'r%d' % low
    if opc < 0x08:
        m = ('movq', 'movl', 'movw', 'movb')[opc // 2]
        return '%s (%s), %s' % (m, l, r) if opc % 2 == 0 else '%s %s, (%s)' % (m, r, l)
    if opc < 0x0B: return '%s (%s), %s' % (('movzl', 'movzw', 'movzb')[opc - 8], l, r)
    if opc == 0x0B: return 'lea %d(sp), %s' % (8 * low, r)
    if opc in (0x0C, 0x0D): return 'movq %d(sp), %s' % (8 * ((opc & 1) * 16 + low), r)
    if opc == 0x0E: return 'movq %s, %d(sp)' % (r, 8 * low)
    if opc in (0x10, 0x11): return 'movl %d(sp), %s' % (4 * ((opc & 1) * 16 + low), r)
    if opc in (0x12, 0x13): return 'movl %s, %d(sp)' % (r, 4 * ((opc & 1) * 16 + low))
    if 0x14 <= opc <= 0x17: return 'movq %d(%s), %s' % (8 * (1 + (opc & 3)), l, r)
    if opc in (0x18, 0x19): return 'movq %s, %d(%s)' % (r, 8 * (1 + (opc & 1)), l)
    if 0x1A <= opc <= 0x1D: return 'movl %d(%s), %s' % (4 * (1 + opc - 0x1A), l, r)
    n = reg * 16 + low
    if opc == 0x1E: return 'pushm #%d' % (n << 8)
    if opc == 0x1F: return 'popm #%d' % (n << 8)
    if opc == 0x20: return 'sub #%d, sp' % (8 * n)
    if opc == 0x21: return 'add #%d, sp' % (8 * n)
    if opc == 0x22: return 'movq #%d, %s' % (sext4(low), r)
    if opc in (0x23, 0x24, 0x25): return '%s #%d, %s' % (('shl', 'shr', 'sar')[opc - 0x23], low, r)
    if 0x26 <= opc <= 0x29: return '%s #%d, %s' % (('and', 'bis', 'xor', 'add')[opc - 0x26], sext4(low), r)
    if opc in (0x2A, 0x2B) and n == 0: return ('pushx', 'popx')[opc - 0x2A]
    return None
cases = [(o, r, l) for o in range(0x2C) for r in range(16) for l in range(16) if text(o, r, l)]
with tempfile.TemporaryDirectory() as t:
    s = os.path.join(t, 'a.s'); ob = os.path.join(t, 'a.o')
    open(s, 'w').write('\t.text\n' + ''.join('\t%s\n' % text(*c) for c in cases))
    r = subprocess.run([AS, '--no-p2', '-o', ob, s], capture_output=True, text=True)
    if r.returncode: sys.exit(r.stderr)
    d = open(ob, 'rb').read()
    shoff = struct.unpack_from('<Q', d, 0x28)[0]
    off, size = struct.unpack_from('<QQ', d, shoff + 64 + 24)
    w = [struct.unpack_from('<H', d, off + 2 * i)[0] for i in range(size // 2)]
i = 0
with open(OUT, 'w') as f:
    for (o, r, l) in cases:
        n = (w[i] >> 14) + 1
        assert w[i] >> 14 in (1, 2), cases
        f.write('%04x %s\n' % (0xC000 | o << 8 | r << 4 | l, ' '.join('%04x' % x for x in w[i:i + n])))
        i += n
assert i == len(w)
