#!/usr/bin/env python3
"""Generate the relaxation test: main.s and lib.s (two objects) in a directory.
usage: gen_relax.py DIR [seed]
main.s is a program whose result r6 is known (the generator adds up what the executed code adds); it fails with the number of the check.  The blocks:
  skip   a forward branch (br, beq, cbeq, jmp) over K calls, for K = 0..150 (the 2- and 4-byte branch forms reach 32 B to 64 KB: the calls in between are 6 bytes
         before relaxation and 4 after, so the form that the assembler chose is longer than the linker's) and a few K near 64 KB;
  loop   the same backward (a loop of three turns whose branch crosses K calls), also sob;
  data   lea of an external data symbol, of a local one, a load through it, movq =K from the pool, .pool in the middle, .align 4/8/16, .even after odd data;
  table  calli through a table of code addresses in .data (D64 relocations against external and local text), a table in .text
The paddings and pools move with the code: every load from the pool is checked."""
import sys, os, random
d = sys.argv[1]; os.makedirs(d, exist_ok=True)
rnd = random.Random(int(sys.argv[2]) if len(sys.argv) > 2 else 1)
NF = 40
M = (1 << 64) - 1
lib = ['\t.text']
for i in range(NF):
    lib += ['\t.globl f%d' % i, 'f%d:' % i, '\tadd #%d, r6' % (i + 1), '\tret']
lib += ['\t.globl fh', 'fh:\tcall hook', '\tret']      # a global of main.s, behind its relaxed code
lib += ['\t.globl farf', '\t.space 700000', 'farf:\tadd #7, r6', '\tret']      # beyond the reach of the 16- and 18-bit calls
lib += ['\t.data']
for i in range(NF):
    lib += ['\t.globl d%d' % i, 'd%d:\t.quad %d' % (i, (i + 1) * 1000 + 5)]
lib += ['\t.comm cbuf, 64']
open(d + '/lib.s', 'w').write('\n'.join(lib) + '\n')

m = ['\t.text', '\t.globl _start', '_start:', '\tmovq #0, r6', '\tmovq #0, r7']
acc = 0
nl = [0]
def lab():
    nl[0] += 1
    return 'L%d' % nl[0]
def calls(k):
    global acc
    out = []; s = 0
    for _ in range(k):
        i = rnd.randrange(NF); out.append('\tcall f%d' % i); s += i + 1
    return out, s
def add(x):
    global acc
    acc = (acc + x) & M

def exec_calls(k):
    c, s = calls(k); add(s); return c
def skip_block(k, kind):
    l = lab()
    dead, _ = calls(k)
    head = {'br': ['\tbr %s' % l], 'jmp': ['\tjmp %s' % l], 'beq': ['\tcmp r6, r6', '\tbeq %s' % l],
            'cbeq': ['\tmovq #5, r5', '\tcbeq r5, #5, %s' % l], 'cbne': ['\tmovq #5, r5', '\tcbne r5, #6, %s' % l]}[kind]
    return head + dead + [l + ':'] + exec_calls(1)
def loop_block(k, kind):
    l = lab()
    body, s = calls(k)
    add(3 * s)
    if kind == 'bne':
        return ['\tmovq #3, r9', l + ':'] + body + ['\tsub #1, r9', '\tbne %s' % l]
    if kind == 'cbne':
        return ['\tmovq #3, r9', l + ':'] + body + ['\tsub #1, r9', '\tcbne r9, #0, %s' % l]
    return ['\tmovq #3, r9', l + ':'] + body + ['\tsob r9, %s' % l]

body = []
for k in range(0, 151):
    body += skip_block(k, ['br', 'jmp', 'beq', 'cbeq', 'cbne'][k % 5])
for k in range(0, 151, 1):
    body += loop_block(k, ['bne', 'sob', 'cbne'][k % 3])
# near the reach of the 4-byte forms (64 KB): 10600 calls are 63.6 KB before relaxation and 42 KB after
for k in (10600, 10800, 10900, 10930, 10990, 11000, 11100):
    body += skip_block(k, 'br' if k % 2 else 'beq')
for k in (5000, 10800, 10930):
    body += loop_block(k, 'bne')
# data, pools, alignment
data = ['\t.data', 'ld0:\t.quad 77', 'ld1:\t.quad 1000000007', '\t.align 8', 'ltab:']
for r in range(120):
    t = rnd.randrange(12)
    if t == 0:
        i = rnd.randrange(NF); body += ['\tlea d%d, r0' % i, '\tmovq (r0), r1', '\tadd r1, r6']; add((i + 1) * 1000 + 5)
    elif t == 1:
        body += ['\tlea ld0, r0', '\tmovq (r0), r1', '\tadd r1, r6', '\tlea ld1, r0', '\tadd (r0), r6']; add(77 + 1000000007)
    elif t == 2:
        k = rnd.getrandbits(40) + (1 << 33); body += ['\tmovq =%d, r2' % k, '\tadd r2, r6']; add(k)
    elif t == 3:
        l = lab(); k = rnd.getrandbits(48) + (1 << 40)
        body += ['\tbr %s' % l, '\t.pool', l + ':', '\tmovq =%d, r2' % k, '\tadd r2, r6']; add(k)
    elif t == 4:
        body += ['\t.align %d' % rnd.choice((4, 8, 16, 32)), '\tadd #1, r6']; add(1)
    elif t == 5:
        l = lab(); body += ['\tbr %s' % l, '\t.byte 1, 2, 3', '\t.even', l + ':', '\tadd #2, r6']; add(2)
    elif t == 6:
        l = lab(); body += ['\tbr %s' % l, '\t.byte 9', '\t.align 8', '\t.quad 0x1122334455667788', l + ':', '\tadd #3, r6']; add(3)
    elif t == 7:
        i = rnd.randrange(NF)
        body += ['\tlea ftab, r0', '\tcalli %d(r0)' % (8 * i)]; add(i + 1)
    elif t == 8:
        body += exec_calls(rnd.randrange(1, 4)) + ['\tcall lf%d' % rnd.randrange(3)]
        add(0)
    elif t == 9:
        body += ['\tcall farf', '\tcall fh']; add(7 + 11)
    elif t == 10:
        body += ['\tlea cbuf, r0', '\tmovq #%d, r1' % r, '\tmovq r1, (r0)', '\tadd (r0), r6']; add(r)
    else:
        body += ['\tmovq =%d, r3' % (r + 12345678901), '\tadd r3, r6']; add(r + 12345678901)
# the local functions called above add a fixed amount; count them now
lfs = [3, 5, 9]
text = list(body)
# recompute the effect of 'call lfN' (they were counted as 0 above): rewrite by scanning
tot = 0
for line in text:
    if line.startswith('\tcall lf'): tot += lfs[int(line[8:])]
add(tot)
m += text
m += ['\tmovq =%d, r8' % acc, '\tcmp r6, r8', '\tbne fail', '\tmovq #0, r0', '\ttrap #0', 'fail:\tmovq #1, r0', '\ttrap #0']
m += ['\t.globl hook', 'hook:\tadd #11, r6', '\tret']
for i, v in enumerate(lfs):
    m += ['lf%d:\tadd #%d, r6' % (i, v), '\tret']
m += ['\t.align 8', 'codetab:\t.quad lf0, lf1, lf2', '\t.pool']
m += data
m += ['ftab:'] + ['\t.quad f%d' % i for i in range(NF)]
m += ['ltab2:\t.quad lf0, lf1, lf2', '\t.long lf1']
open(d + '/main.s', 'w').write('\n'.join(m) + '\n')
