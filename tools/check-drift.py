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
OPG_BR = 0x30

R2 = {'abs', 'clz', 'ctz', 'clo', 'cto', 'popcnt', 'bswap', 'bswapw', 'bswapl', 'bitrev', 'utf8len', 'utf8dec', 'utf8enc'}
def source(group, word):
    g = group[3:]
    if g in ('mov', 'movz', 'alu'):
        return '%s r1, r2' % word
    if g == 'lea': return 'lea 8(r1), r2'
    if g == 'branch': return '%s l\nl:' % word
    if g == 'cbranch': return '%s r1, #3, l\nl:' % word
    if g == 'sob': return 'sob r1, l\nl:'
    if g == 'tag': return '%s r1, #1, l\nl:' % word
    if g == 'sop': return '%s #3' % word if word in ('pushm', 'popm') else '%s r1' % word
    if g == 'xfer': return 'jtag 8(r1)(r2*8)' if word == 'jtag' else '%s 8(r1)' % word
    if g in ('besc', 'aesc', 'mblk'):
        if word in ('rori', 'rori32'): return '%s r1, #3, r2' % word
        if word == 'rol': return 'rol r1, #3, r2'
        if word == 'dshr': return 'dshr r1, r2, #3, r3'
        if word in ('extb', 'extzb', 'insb'): return '%s r1, #3, #8, r2' % word
        if word == 'mval': return 'mval r1, r2'
        if word in R2: return '%s r1, r2' % word
        return '%s r1, r2, r3' % word
    if g == 'fesc':
        four = word.startswith(('fmadd', 'fmsub', 'fnmadd', 'fnmsub'))
        three = word in ('fcopysign', 'fmin', 'fmax')
        two = not four and not three
        return '%s %s' % (word, ', '.join(['r1', 'r2', 'r3', 'r4'][:4 if four else 3 if three else 2]))
    if g == 'sys-none': return word
    if g == 'sysreg': return 'mfsr r1, ptbr' if word == 'mfsr' else 'mtsr ptbr, r1'
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

ALIAS = dict(en['offset'])['alias']      # a word numbered this far above another is an alias of it
bad = skipped = checked = 0
todo = []
for group, items in en.items():
    if not group.startswith('mn-'):
        continue
    g = group[3:]
    for word, num in items:
        if num >= ALIAS:
            target = [w for w, n in items if n == num - ALIAS]
            if not target or g == 'besc' and word == 'rol':
                continue
            src0 = source(group, target[0])
            if src0 is None:
                continue
            outs = []
            for wd in (target[0], word):
                with tempfile.TemporaryDirectory() as t:
                    f = os.path.join(t, 'a.s'); o = os.path.join(t, 'a.o')
                    open(f, 'w').write('\t.text\n\t' + src0.replace(target[0], wd, 1).replace('\n', '\n\t') + '\n')
                    r = subprocess.run([AS, '-o', o, f], capture_output=True, text=True)
                    outs.append(words(o) if r.returncode == 0 else None)
            checked += 1
            if outs[0] is None or outs[0] != outs[1]:
                bad += 1
                print('DRIFT alias %s of %s: %s vs %s' % (word, target[0], outs[1], outs[0]))
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
        elif g == 'cbranch': got, want = (opc, low), (OPG['cbr'], num)
        elif g == 'tag': got, want = (opc, (low >> 3)), (OPG['tag'], num)
        elif g == 'sop': got, want = (opc, reg), (OPG['sop'], num)
        elif g == 'xfer': got, want = (opc, reg), (OPG['xfer'], num)
        elif g in ('besc', 'aesc', 'mblk', 'fesc'): got, want = (opc, sub), (OPG[g], num)
        elif g == 'sysreg': got, want = (opc, reg, low, w[1] & 15, len(w)), (OPG['sys'], 0, num, 0, 2)
        elif g == 'sys-none': got, want = (opc, reg, low), (OPG['sys'], 0, num)
        elif g == 'sys': got, want = (opc, reg), (OPG['sys'], num)
        checked += 1
        if got != want:
            bad += 1
            print('DRIFT %s %s: encoded %s, the grammar says %s' % (group, word, got, want))
# --- the opcode map, from the same numbers (these were the checks of the retired JSON spec) ---
def numbers(rule, below=None):
    return {n for w, n in en[rule] if below is None or n < below}
assigned = (numbers('mn-mov') | numbers('movstore') | numbers('mn-movz') | numbers('mn-alu', 64) | numbers('mn-branch', 64) | set(OPG.values()))
bad_map = []
if len(assigned) != 57: bad_map.append('%d top-level opcodes assigned, ISA 4.16 as corrected says 55, errata 31 adds cbCC (0x28) and errata 34 the wide cbCC (0x29)' % len(assigned))
free = set(range(64)) - assigned
if free != {0x23} | set(range(0x2A, 0x30)): bad_map.append('unassigned opcodes are %s, expected 0x23 and 0x2A-0x2F' % sorted(hex(x) for x in free))
if OPG['cbr'] != 0x28: bad_map.append('cbCC is not top-level opcode 0x28')
if OPG['cbw'] != 0x29: bad_map.append('the wide cbCC is not top-level opcode 0x29')
if [OPG[k] for k in ('besc', 'mblk', 'aesc', 'mesc', 'fesc', 'atom')] != list(range(0x0C, 0x12)): bad_map.append('the parcel-1 escapes are not contiguous at 0x0C-0x11 (ISA 4.3.1)')
if [OPG[k] for k in ('xfer', 'sop', 'sys')] != [0x12, 0x13, 0x14]: bad_map.append('XFER, SOP and SYS are not adjacent at 0x12-0x14 (ISA 4.3.1)')
if sorted(numbers('mn-branch', 64) | {OPG['sob']}) != list(range(0x30, 0x40)): bad_map.append('the sixteen branch slots are not 0x30-0x3F')
for m in bad_map: print('MAP ' + m)
bad += len(bad_map)
# --- the condition words: encoded in the x field, numbered like the low nibble of the branch opcodes ---
BR = dict(en['mn-branch'])
for rule in ('cc', 'ccalias'):
    for word, num in en[rule]:
        with tempfile.TemporaryDirectory() as t_:
            f = os.path.join(t_, 'a.s'); o = os.path.join(t_, 'a.o')
            open(f, 'w').write('\t.text\n\tset %s, r1\n' % word)
            r = subprocess.run([AS, '-o', o, f], capture_output=True, text=True)
            w = words(o) if r.returncode == 0 else []
        got = (w[1] & 15) if len(w) > 1 else None
        branch = {'al': 'br', 'los': 'blos'}.get(word, 'b' + word)
        want_branch = BR.get(branch)
        if got != num or (rule == 'cc' and (want_branch is None or want_branch - OPG_BR != num)):
            bad += 1
            print('DRIFT cc %s: encoded %s, number %d, branch %s = %s' % (word, got, num, branch, want_branch))
        checked += 1
# --- cbCC: the condition numbers are those of the branches and of `set`, and the aliases follow the branch group's ---
CB = dict(en['mn-cbranch'])
for word, num in en['cc']:
    if word == 'al': continue
    if CB.get('cb' + word) != num: bad += 1; print('DRIFT cbCC: cb%s is %s, the condition number is %d' % (word, CB.get('cb' + word), num))
    checked += 1
for word, num in en['ccalias']:
    name = {'hs': 'cbhis', 'lo': 'cblo'}[word]          # as bhis and blo are the aliases of bcc and bcs
    if CB.get(name) != num + ALIAS: bad += 1; print('DRIFT cbCC alias: %s is %s, expected %d' % (name, CB.get(name), num + ALIAS))
    checked += 1
# --- page 2: for each opcode, the assembler picks it for the abbreviated instruction, and the page-1 instruction the word expands to is
#     the one the assembler writes with page 2 turned off (--no-p2) ---
P2 = en['p2op']
# name: (source, reg, low) -- the instruction a page-2 word abbreviates, and the fields the one-parcel encoding must carry
CASE = {
 'ld.q': ('movq (r5), r3', 3, 5), 'st.q': ('movq r3, (r5)', 3, 5), 'ld.l': ('movl (r5), r3', 3, 5), 'st.l': ('movl r3, (r5)', 3, 5),
 'ld.w': ('movw (r5), r3', 3, 5), 'st.w': ('movw r3, (r5)', 3, 5), 'ld.b': ('movb (r5), r3', 3, 5), 'st.b': ('movb r3, (r5)', 3, 5),
 'ldz.l': ('movzl (r5), r3', 3, 5), 'ldz.w': ('movzw (r5), r3', 3, 5), 'ldz.b': ('movzb (r5), r3', 3, 5),
 'lea.sp': ('lea 24(sp), r3', 3, 3),
 'ldq.sp0': ('movq 24(sp), r3', 3, 3), 'ldq.sp1': ('movq 136(sp), r3', 3, 1), 'stq.sp': ('movq r3, 24(sp)', 3, 3),
 'ldl.sp0': ('movl 12(sp), r3', 3, 3), 'ldl.sp1': ('movl 68(sp), r3', 3, 1),
 'stl.sp0': ('movl r3, 12(sp)', 3, 3), 'stl.sp1': ('movl r3, 68(sp)', 3, 1),
 'ldq.d1': ('movq 8(r5), r3', 3, 5), 'ldq.d2': ('movq 16(r5), r3', 3, 5), 'ldq.d3': ('movq 24(r5), r3', 3, 5), 'ldq.d4': ('movq 32(r5), r3', 3, 5),
 'stq.d1': ('movq r3, 8(r5)', 3, 5), 'stq.d2': ('movq r3, 16(r5)', 3, 5),
 'ldl.d1': ('movl 4(r5), r3', 3, 5), 'ldl.d2': ('movl 8(r5), r3', 3, 5), 'ldl.d3': ('movl 12(r5), r3', 3, 5), 'ldl.d4': ('movl 16(r5), r3', 3, 5),
 'pushm8': ('pushm #0x8F00', 8, 15), 'popm8': ('popm #0x0100', 0, 1),
 'sub.sp': ('sub #64, sp', 0, 8), 'add.sp': ('add #2040, sp', 15, 15),
 'movq.i': ('movq #-5, r3', 3, 11), 'shl.i': ('shl #9, r3', 3, 9), 'shr.i': ('shr #15, r3', 3, 15), 'sar.i': ('sar #1, r3', 3, 1),
 'and.i': ('and #-1, r3', 3, 15), 'bis.i': ('bis #7, r3', 3, 7), 'xor.i': ('xor #-8, r3', 3, 8), 'add.i': ('add #3, r3', 3, 3),
}
def asm_words(src, *flags):
    with tempfile.TemporaryDirectory() as t_:
        f = os.path.join(t_, 'a.s'); o = os.path.join(t_, 'a.o')
        open(f, 'w').write('\t.text\n\t' + src + '\n')
        r = subprocess.run([AS, *flags, '-o', o, f], capture_output=True, text=True)
        return words(o) if r.returncode == 0 else None
def expand(word):
    return subprocess.run([AS, '--p2-expand', '%04x' % word], capture_output=True, text=True).stdout.split()
# --- the system registers: the number in the sr byte of parcel 1, the general register in the next nibble, the pad zero; eva and ecause read only ---
for name, num in en['sysreg']:
    checked += 1
    w = asm_words('mfsr r2, ' + name)
    if w is None or len(w) != 2 or w[1] != num << 8 | 2 << 4:
        bad += 1; print('DRIFT sysreg %s: `mfsr r2, %s` assembles to %s, the number is %d' % (name, name, w, num))
    wr = asm_words('mtsr %s, r2' % name)
    ro = name in ('eva', 'ecause')
    if (wr is None) != ro or (wr is not None and wr != [w[0] + 1, w[1]]):
        bad += 1; print('DRIFT sysreg %s: mtsr is %s (read only: %s)' % (name, wr, ro))
# --- the wide cbCC: the same condition numbers, opcode 0x29, six bytes: imm16 in parcel 1, disp16 in parcel 2 ---
for word, num in en['mn-cbranch']:
    if num >= ALIAS: continue
    checked += 1
    w = asm_words('%s r3, #1000, l\nl:' % word)
    want = [0x8000 | OPG['cbw'] << 8 | 3 << 4 | num, 1000, 3]
    if w != want: bad += 1; print('DRIFT cbw %s: assembles to %s, expected %s' % (word, w, ['%04x' % x for x in want]))
LENCODE = dict(en['lencode'])
for name, num in P2:
    checked += 1
    if name not in CASE:
        bad += 1; print('DRIFT p2 %s: no test case in tools/check-drift.py' % name); continue
    src, reg, low = CASE[name]
    w = asm_words(src)
    want = LENCODE['page2'] << 14 | num << 8 | reg << 4 | low
    if w != [want]:
        bad += 1; print('DRIFT p2 %s: `%s` assembles to %s, expected %04x' % (name, src, ' '.join('%04x' % x for x in w or []), want)); continue
    long_ = asm_words(src, '--no-p2')
    if long_ is None or expand(w[0]) != ['%04x' % x for x in long_]:
        bad += 1; print('DRIFT p2 %s: %04x expands to %s, the long form of `%s` is %s' % (name, w[0], expand(w[0]), src, long_))
for num in range(64):
    if num not in {n for _, n in P2} and expand(LENCODE['page2'] << 14 | num << 8) != ['reserved']:
        bad += 1; print('DRIFT p2: opcode %#x is not in p2op but is not reserved' % num)
    checked += 1
print('drift: %d mnemonics checked, %d differ, %d not assembled yet%s' % (checked, bad, skipped, (': ' + ' '.join(todo)) if todo else ''))
sys.exit(1 if bad else 0)
