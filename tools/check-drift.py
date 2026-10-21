#!/usr/bin/env python3
"""
check-drift -- does the assembler encode every mnemonic with the number the grammar gives it?

spec/pdp64-mnemonics.hbnf is the one place the numbers are written.  For each word in it this assembles one instruction with as64, reads
the encoding back, and compares: a top-level opcode where the number is the opcode, the `reg` field for SOP, XFER and SYS, the
sub-opcode byte of parcel 1 for the escape groups, the minor in `low` for SYS with no operand.  A group the assembler does not do yet is
listed as such, not skipped silently.  Run after any change to the grammar or to as64.
"""
import os, struct, subprocess, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mkgrammar

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
AS = os.path.join(ROOT, os.environ.get('BUILD', 'build'), 'as64')
en = mkgrammar.enums(os.path.join(ROOT, 'spec', 'pdp64-mnemonics.hbnf'))
OPG = dict(en['opgroup'])

R2 = {'clz', 'ctz', 'clo', 'cto', 'popcnt', 'bswap', 'bswapw', 'bswapl', 'bitrev', 'utf8len', 'utf8dec', 'utf8enc'}
def source(group, word):
    g = group[3:]
    if g in ('mov', 'movz', 'alu'):
        return '%s r1, r2' % word
    if g == 'lea': return 'lea 8(r1), r2'
    if g == 'branch': return '%s l\nl:' % word
    if g == 'sob': return 'sob r1, l\nl:'
    if g == 'tag': return '%s r1, #1, l\nl:' % word
    if g == 'sop': return '%s #3' % word if word in ('pushm', 'popm') else '%s r1' % word
    if g == 'xfer': return 'jtag 8(r1)(r2*8)' if word == 'jtag' else '%s 8(r1)' % word
    if g in ('besc', 'aesc', 'mblk'):
        if word == 'rori': return 'rori r1, #3, r2'
        if word == 'rol': return 'rol r1, #3, r2'
        if word == 'dshr': return 'dshr r1, r2, #3, r3'
        if word in ('extb', 'extzb', 'insb'): return '%s r1, #3, #8, r2' % word
        if word == 'mval': return 'mval r1, r2'
        if word in R2: return '%s r1, r2' % word
        return '%s r1, r2, r3' % word
    if g == 'sys-none': return word
    if g == 'sys':
        if word in ('spl', 'trap'): return '%s #3' % word
        if word in ('prober', 'probew'): return '%s r1, r2' % word
        if word == 'trapl': return None
        return '%s r1' % word
    return None

def words(path):
    d = open(path, 'rb').read()
    shoff = struct.unpack_from('<Q', d, 0x28)[0]
    off, size = struct.unpack_from('<QQ', d, shoff + 64 + 24)
    return [struct.unpack_from('<H', d, off + 2 * i)[0] for i in range(size // 2)]

ALIAS_FLOOR = {'branch': 64, 'alu': 64, 'sys-none': 16, 'besc': 256}      # numbers from here up are aliases (checked by tests/asm)
bad = skipped = checked = 0
todo = []
for group, items in en.items():
    if not group.startswith('mn-'):
        continue
    g = group[3:]
    for word, num in items:
        if num >= ALIAS_FLOOR.get(g, 1 << 30):
            continue
        src = source(group, word)
        if src is None:
            todo.append('%s:%s' % (g, word)); skipped += 1; continue
        with tempfile.TemporaryDirectory() as t:
            f = os.path.join(t, 'a.s'); o = os.path.join(t, 'a.o')
            open(f, 'w').write('\t.text\n\t' + src.replace('\n', '\n\t') + '\n')
            r = subprocess.run([AS, '-o', o, f], capture_output=True, text=True)
            if r.returncode:
                todo.append('%s:%s' % (g, word)); skipped += 1; continue
            w = words(o)
        p0 = w[0]; opc = (p0 >> 8) & 63; reg = (p0 >> 4) & 15; low = p0 & 15
        sub = (w[1] >> 8) if len(w) > 1 else None
        if g in ('mov', 'movz', 'alu', 'branch'): got, want = opc, num
        elif g == 'lea': got, want = opc, OPG['lea']
        elif g == 'sob': got, want = opc, OPG['sob']
        elif g == 'tag': got, want = (opc, (low >> 3)), (OPG['tag'], num)
        elif g == 'sop': got, want = (opc, reg), (OPG['sop'], num)
        elif g == 'xfer': got, want = (opc, reg), (OPG['xfer'], num)
        elif g in ('besc', 'aesc', 'mblk'): got, want = (opc, sub), (OPG[g], num)
        elif g == 'sys-none': got, want = (opc, reg, low), (OPG['sys'], 0, num)
        elif g == 'sys': got, want = (opc, reg), (OPG['sys'], num)
        checked += 1
        if got != want:
            bad += 1
            print('DRIFT %s %s: encoded %s, the grammar says %s' % (group, word, got, want))
print('drift: %d mnemonics checked, %d differ, %d not assembled yet%s' % (checked, bad, skipped, (': ' + ' '.join(todo)) if todo else ''))
sys.exit(1 if bad else 0)
