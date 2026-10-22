#!/usr/bin/env python3
"""Writes the instruction forms for tests/flaginv.c: for every mnemonic of the grammar one or several operand forms (register, memory, immediate,
literal-pool, page-2), assembled with as64; a line is `parcels # source`.  usage: flaginv.py AS64 OUTFILE"""
import os, struct, subprocess, sys, tempfile
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tools'))
import mkgrammar
AS, OUT = sys.argv[1], sys.argv[2]
en = mkgrammar.enums(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'spec', 'pdp64-mnemonics.hbnf'))
ALIAS = dict(en['offset'])['alias']
R2 = {'abs', 'clz', 'ctz', 'clo', 'cto', 'popcnt', 'bswap', 'bswapw', 'bswapl', 'bitrev', 'utf8len', 'utf8dec', 'utf8enc'}
SHIFTS = {'shl', 'shr', 'sar'}
forms = []
def add(*s): forms.extend(s)
for g, items in en.items():
    if not g.startswith('mn-'): continue
    for w, num in items:
        if num >= ALIAS: continue
        if g in ('mn-mov',):
            add('%s (r5), r3' % w, '%s r6, r3' % w, '%s #5, r3' % w, '%s 24(sp), r3' % w, '%s r3, (r5)' % w, '%s r3, 8(r5)' % w, '%s r3, 16(sp)' % w, '%s r3, r6' % w)
            if w == 'movq': add('movq =0x123456789ABC, r3', 'movq (r5)+, r3', 'movq -(r5), r3', 'movq 8(r5)(r6*2), r3')
        elif g == 'mn-movz': add('%s (r5), r3' % w, '%s r6, r3' % w, '%s #5, r3' % w)
        elif g == 'mn-lea': add('lea 8(r5), r3', 'lea (r5)(r6*2), r3', 'lea 16(sp), r3')
        elif g == 'mn-alu':
            if w in SHIFTS: add('%s r4, r3' % w, '%s #0, r3' % w, '%s #1, r3' % w, '%s #15, r3' % w, '%s #63, r3' % w, '%s (r5), r3' % w)
            elif w in ('cmp', 'fcmp', 'fcmpd'): add('%s r3, r6' % w, '%s r3, (r5)' % w, '%s r3, #5' % w, '%s r3, =0x123456789ABC' % w)
            else: add('%s r6, r3' % w, '%s (r5), r3' % w, '%s #5, r3' % w, '%s =0x123456789ABC, r3' % w, '%s #-1, r3' % w)
        elif g == 'mn-branch': add('%s l\nl:' % w)
        elif g == 'mn-sob': add('sob r3, l\nl:')
        elif g == 'mn-tag': add('%s r3, #1, l\nl:' % w)
        elif g == 'mn-cbranch': add('%s r3, #3, l\nl:' % w, '%s r3, #300, l\nl:' % w, '%s r3, r6, l\nl:' % w)
        elif g == 'mn-sop':
            if w in ('pushm', 'popm'): add('%s #0x8F00' % w, '%s #0x0003' % w)
            elif w in ('jmp', 'call'): pass
            else: add('%s r3' % w, '%s (r5)' % w)
        elif g == 'mn-besc':
            if w in ('rori', 'rori32'): add('%s r6, #3, r3' % w)
            elif w == 'dshr': add('dshr r6, r4, #3, r3')
            elif w in ('extb', 'extzb', 'insb'): add('%s r6, #3, #8, r3' % w)
            elif w in R2: add('%s r6, r3' % w)
            else: add('%s r6, r4, r3' % w)
        elif g == 'mn-aesc': add('%s r6, r3' % w if w in R2 else '%s r6, r4, r3' % w)
        elif g == 'mn-cond' or g == 'mn-sysreg' or g == 'mn-sys-none' or g == 'mn-sys' or g == 'mn-atom' or g == 'mn-mesc' or g == 'mn-xfer': pass
        elif g == 'mn-mblk': add('mval r6, r4' if w == 'mval' else '%s r5, r3, r6' % w)
        elif g == 'mn-fesc':
            four = w.startswith(('fmadd', 'fmsub', 'fnmadd', 'fnmsub')); three = w in ('fcopysign', 'fmin', 'fmax')
            add('%s %s' % (w, ', '.join(['r6', 'r4', 'r7', 'r3'] if four else ['r6', 'r4', 'r3'] if three else ['r6', 'r3'])))
        elif g == 'mn-sysx': add({'hint': 'hint #7'}.get(w, w))
add('mfps r3', 'mtps r6', 'spl #3', 'trap #3', 'bpt', 'nop', 'fence', 'wfe', 'sev', 'lpad', 'mfsr r3, ptbr', 'mtsr ptbr, r6', 'mfsr r3, usp', 'mtsr usp, r6', 'mtdp r6', 'mfdp r3',
    'mfasid r3', 'mtasid r6', 'tlbi r6', 'tlbia', 'tlbsync', 'icinv r6', 'icinva', 'mfcpuid r3', 'rti', 'rtt', 'ret', 'halt', 'set eq, r3', 'set cs, r3', 'prober r3, r6', 'probew r3, r6',
    'push r3', 'pop r3', 'push (r5)', 'push =0x123456789ABC')
with tempfile.TemporaryDirectory() as t:
    out = []
    for src in forms:
        s = os.path.join(t, 'a.s'); ob = os.path.join(t, 'a.o')
        open(s, 'w').write('\t.text\n' + ''.join('\t%s\n' % l for l in src.split('\n')))
        for flags in (['--no-p2'], []):
            r = subprocess.run([AS] + flags + ['-o', ob, s], capture_output=True, text=True)
            if r.returncode: break
            d = open(ob, 'rb').read()
            shoff = struct.unpack_from('<Q', d, 0x28)[0]
            off, size = struct.unpack_from('<QQ', d, shoff + 64 + 24)
            w = [struct.unpack_from('<H', d, off + 2 * i)[0] for i in range(size // 2)]
            n = 1 if w[0] >> 14 == 3 else (w[0] >> 14) + 1
            # the pool of =K follows the instruction: keep only the instruction's parcels (the operand then reads the pool by pc: not mapped here, it faults, fine)
            wd = ' '.join('%04x' % x for x in w[:n])
            if not any(o.startswith(wd + ' #') for o in out): out.append('%s # %s%s' % (wd, src.split('\n')[0], '' if flags else '  [page 2]'))
        else:
            continue
        if r.returncode: sys.stderr.write('flaginv.py: %s: %s' % (src, r.stderr))
open(OUT, 'w').write('\n'.join(out) + '\n')
