#!/usr/bin/env python3
"""Generate tests/sim/split-fault.S: a plain access that crosses a page boundary faults precisely on either page and changes nothing (errata 217, C10 of docs/encoding-work/instruction-pass.md).

Four scenarios, each on a pair of adjacent pages A and B (A below B) of the region 0x800000 to 0xa00000 (sim64 -K -x: the first access to each page faults once and then works; QEMU: the pages
are absent and the handler maps them):
  1  a quad store from the last four bytes of A into B, A present and B absent: one fault, a store fault, EVA the first byte of B, EPC the instruction, and at the fault the four bytes of A
     are as they were (the store wrote nothing); after the handler the instruction runs again and writes all eight bytes
  2  the same store with A absent and B present: EVA the address of the store (the first byte of A), the bytes of B as they were
  3  a quad load across the two pages with B absent: a load fault, EVA the first byte of B, EPC the instruction, the destination register as it was; after the handler it holds the quad
  4  a four-byte store across the two pages (the last two bytes of A and the first two of B), B absent: as 1
It is built from the machine of tests/sim/atom-fault-page.S (the page tables, the handler that maps the page).  A failed check n exits with n.

usage: gen_split.py OUTDIR"""
import sys as _sys, os as _os
_sys.path.insert(0, _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), '..', '..', 'tools'))
import marks		# the words of the encoding written with width marks (tools/marks.py)
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, 'atom-fault-page.S')).read()
head = src[:src.index('\tlea\tustack_top, sp\n') + len('\tlea\tustack_top, sp\n')]
head = head.replace(head[:head.index('#include')], '')
tail = src[src.index('h_fault:\n'):]
# the handler also records what is at the watched address and the destination register of the load
tail = tail.replace('h_fault:\n\tmovq\tr1, hr1\n', 'h_fault:\n\tmovq\tr1, hr1\n\tmovq\tr5, hr5\n\tmovq\twatch, r12\n\tcbeq\tr12, #0, 1f\n\tmovl\t(r12), r11\n\tmovq\tr11, seen\n1:\n', 1)
tail = tail.replace('hr1:\t.quad\t0\n', 'hr1:\t.quad\t0\nhr5:\t.quad\t0\nwatch:\t.quad\t0\nseen:\t.quad\t0\n', 1)

n = [0]
out = []


def a(*ls):
    out.extend('\t' + x for x in ls)


def check(reg, want, what):
    n[0] += 1
    a('movq\t=(%s), r17' % want, 'cbeq\t%s, r17, 1f\t; check %d %s' % (reg, n[0], what), 'movq\t#%d, r0' % n[0], 'halt')
    out.append('1:')


def common(ins_label, cause, eva, what):
    a('movq\tcnt, r11'); check('r11', '1', what + ': one fault')
    a('movq\tlast_cause, r11'); check('r11', cause, what + ': the vector')
    a('movq\tlast_eva, r11'); check('r11', eva, what + ': EVA')
    a('lea\t%s, r11' % ins_label, 'movq\tlast_epc, r12', 'cbeq\tr12, r11, 1f\t; check %d %s: EPC is the instruction' % (n[0] + 1, what), 'movq\t#%d, r0' % (n[0] + 1), 'halt')
    n[0] += 1
    out.append('1:')


def pair(k): return 0x820000 + k * 0x2000


# 1: store across A to B, B absent
A = pair(0); B = A + 0x1000
a('; ---- 1: a quad store from A (present) into B (absent)', 'movq\t=(%#x), r3' % A, 'movq\t=(0x44332211), r1', 'movl\tr1, 4092(r3)', 'movq\t#0, r4', 'movq\tr4, cnt',
  'movq\t=(%#x), r4' % (A + 4092), 'movq\tr4, watch', 'movq\t=(0x8877665544332211), r1', 'movq\t#0, r4', 'movq\tr4, cnt')
a('s1:', 'movq\tr1, 4092(r3)')
a('movq\t#0, r4', 'movq\tr4, watch')
common('s1', 'VECTOR_SFAULT', '%#x' % B, 'case 1: a split store, B absent')
a('movq\tseen, r11'); check('r11', '0x44332211', 'case 1: at the fault the four bytes of A are as they were')
a('movq\t4092(r3), r11'); check('r11', '0x8877665544332211', 'case 1: after the restart all eight bytes are there')
# 2: store across A to B, A absent, B present
A = pair(1); B = A + 0x1000
a('; ---- 2: the same store with A absent and B present', 'movq\t=(%#x), r3' % A, 'movq\t=(0x55667788), r1', 'movl\tr1, 4096(r3)', 'movq\t=(%#x), r4' % B, 'movq\tr4, watch',
  'movq\t=(0x8877665544332211), r1', 'movq\t#0, r4', 'movq\tr4, cnt')
a('s2:', 'movq\tr1, 4092(r3)')
a('movq\t#0, r4', 'movq\tr4, watch')
common('s2', 'VECTOR_SFAULT', '%#x' % (A + 4092), 'case 2: a split store, A absent')
a('movq\tseen, r11'); check('r11', '0x55667788', 'case 2: at the fault the bytes of B are as they were')
a('movq\t4092(r3), r11'); check('r11', '0x8877665544332211', 'case 2: after the restart all eight bytes are there')
# 3: load across A to B, B absent
A = pair(2); B = A + 0x1000
a('; ---- 3: a quad load across A (present) and B (absent)', 'movq\t=(%#x), r3' % A, 'movq\t=(0x44332211), r1', 'movl\tr1, 4092(r3)', 'movq\t=(99), r5', 'movq\t#0, r4', 'movq\tr4, cnt', 'movq\tr4, watch')
a('s3:', 'movq\t4092(r3), r5')
common('s3', 'VECTOR_LFAULT', '%#x' % B, 'case 3: a split load, B absent')
a('movq\thr5, r11'); check('r11', '99', 'case 3: at the fault the destination is as it was')
check('r5', '0x44332211', 'case 3: after the restart it holds the quad (the new page is zero)')
# 4: a four-byte store across the pages
A = pair(3); B = A + 0x1000
a('; ---- 4: a four-byte store across A (present) and B (absent)', 'movq\t=(%#x), r3' % A, 'movq\t=(0x44332211), r1', 'movl\tr1, 4092(r3)', 'movq\t=(%#x), r4' % (A + 4092), 'movq\tr4, watch', 'movq\t=(0x1122ccdd), r1', 'movq\t#0, r4', 'movq\tr4, cnt')
a('s4:', 'movl\tr1, 4094(r3)')
a('movq\t#0, r4', 'movq\tr4, watch')
common('s4', 'VECTOR_SFAULT', '%#x' % B, 'case 4: a split four-byte store, B absent')
a('movq\tseen, r11'); check('r11', '0x44332211', 'case 4: at the fault the last four bytes of A are as they were')
a('movl\t4094(r3), r11'); check('r11', '0x1122ccdd', 'case 4: after the restart all four bytes are there')
a('movq\t#0, r0', 'halt')
body = head + '\n'.join(out) + '\n' + tail
body = '; GENERATED by tests/sim/gen_split.py -- do not edit.  A plain access that crosses a page faults precisely on either page and changes nothing: see the generator.  sim64 -K -x 0x800000:0xa00000; QEMU with its tables.  Failed check n: exit n.\n' + body
open(os.path.join(sys.argv[1], 'split-fault.S'), 'w').write(marks.spell_text(body))
print('gen_split: split-fault.S (%d checks)' % n[0])
