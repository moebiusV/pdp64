#!/usr/bin/env python3
"""check_forms -- the encodings of one instruction are interchangeable.  One word names the operation and the assembler picks the form; that is safe only if every form the operands
fit does the same thing.  For each instruction below, with the registers and the memory in a fixed state and the flags set in two ways, assemble it as the shortest form and with
`.encode 1`, `.encode 2`, `.encode 3` (the shortest form of that many parcels or more: a number that gives the same form as another is run once), run each under sim64 -r and compare
the whole state: registers, flags (the status word) and the memory the instruction can reach.  A difference is a place where one word would hide a difference; there should be none.
usage: check_forms.py AS64 LD64 SIM64 WORKDIR"""
import os, re, subprocess, sys
AS, LD, SIM, W = sys.argv[1:5]
os.makedirs(W, exist_ok=True)
REGS = [0x0123456789abcdef, 0xfedcba9876543210, 7, -3 & (2**64 - 1), 0x00000000ffffffff, 0x8000000000000000, 0x7fffffffffffffff, 100, 0x00ff00ff00ff00ff]
FLAGS = ['cmp r1, r1', 'cmp r2, r1']			# Z set; N, C and others from the compare
# each case: the instruction (or a few lines).  buf is 64 bytes at the address in r10; r11 is buf+32; sp is in the middle of a stack
ALU = 'add sub and bis bic xor cmp bit mul mulh'.split()
cases = []
for m in ALU:
    cases += ['%s r3, r4' % m, '%s (r10), r4' % m, '%s 8(r10), r4' % m, '%s 40(r10), r4' % m, '%s #5, r4' % m, '%s #-3, r4' % m, '%s #60, r4' % m, '%s -8(r11), r4' % m, '%s 0(r10)(r3*1), r4' % m if False else '%s (r10)(r12*8), r4' % m]
for m in 'shl shr sar'.split():
    cases += ['%s #3, r1' % m, '%s #1, r2' % m, '%s r4, r1' % m, '%s #0, r1' % m]
for m in 'movq movl movw movb movzl movzw movzb'.split():
    cases += ['%s r2, r4' % m, '%s (r10), r4' % m, '%s 8(r10), r4' % m, '%s 24(r10), r4' % m, '%s #5, r4' % m, '%s #-9, r4' % m, '%s #77, r4' % m]
for m in 'movq movl movw movb'.split():
    cases += ['%s r1, (r10)' % m, '%s r1, 8(r10)' % m, '%s r1, 48(r10)' % m, '%s r1, 0(r11)' % m]
cases += ['movq (r10)+, r4', 'movq -(r11), r4', 'movq r1, (r10)+', 'movq r1, -(r11)', 'movl (r10)+, r4', 'movq (r10)(r12*8), r4', 'movq r1, (r10)(r12*8)']
cases += ['lea 8(r10), r4', 'lea (r10)(r12*8), r4', 'lea 40(r10), r4', 'lea 16(sp), r4', 'lea buf, r4', 'movq #buf, r4']
for m in 'clr com inc dec neg tst adc sbc asl asr'.split():
    cases += ['%s r4' % m, '%s (r10)' % m, '%s 8(r10)' % m, '%s 40(r10)' % m]
cases += ['push r1', 'pop r4', 'push #5', 'push #100', 'push (r10)', 'pop (r10)', 'pushm #0x700', 'popm #0x700', 'push #0x12345', 'pushm #0x300']
cases += ['add #16, sp', 'sub #16, sp', 'add #8, sp', 'sub #200, sp', 'add #1, sp', 'add #3, sp']
for c in 'ne eq pl mi vc vs cc cs ge lt gt le hi los'.split():
    cases += ['b%s L1\n movq #1, r5\nL1:' % c, 'cb%s r1, #5, L1\n movq #1, r5\nL1:' % c, 'cb%s r1, r2, L1\n movq #1, r5\nL1:' % c, 'cb%s r4, #0, L1\n movq #1, r5\nL1:' % c, 'cb%s r1, #100, L1\n movq #1, r5\nL1:' % c]
cases += ['br L1\n movq #1, r5\nL1:', 'jmp L1\n movq #1, r5\nL1:', 'sob r8, L1\n movq #1, r5\nL1:', 'call f\n movq #1, r5\n br L1\nf: movq #3, r6\n ret\nL1:']
cases += ['cmp r1, #5', 'cmp r1, #-3', 'cmp r1, #200', 'cmp r1, (r10)', 'cmp r1, 8(r10)', 'cmp r1, #100000']
cases += ['add r3, sp', 'movq sp, r4', 'movq r4, sp', 'xor r4, r4', 'and #0xff, r4', 'and #0xffff, r4', 'bis #0x80, r4', 'bic #1, r4']
cases += ['mulu r3, r4', 'fadd r3, r4', 'fcmp r3, r4', 'rori r1, #5, r2', 'clz r1, r2', 'popcnt r1, r2', 'bswap r1, r2', 'div r1, r2, r4', 'min r1, r2, r4']
cases += ['cteq r5', 'ctne r5', 'cthi r1, #5', 'mfps r4', 'mtps r4', 'spl #3', 'nop', 'hint #1', 'trap #3']
cases += ['movq =0x123456789abcdef0, r4', 'movq #0x123456789abcdef0, r4', 'push =0x123456789abcdef0', 'add =0x123456789abcdef0, r4']
SKIP_RUN = {'mtps r4', 'spl #3', 'trap #3', 'hint #1'}

HEAD = """	.text
	.globl	_start
_start:
	lea	stack_top, sp
	lea	buf, r10
	lea	32(r10), r11
"""
for i, v in enumerate(REGS, 1):
    HEAD += '\tmovq\t=%d, r%d\n' % (v, i if i < 8 else i + 0)
# r1..r9 as in REGS; r8 holds 100 (the sob count), r10 and r11 are buf and buf+32 (set again here: the table above wrote r10 only by the lea)
HEAD += '\tlea\tbuf, r10\n\tlea\t32(r10), r11\n\tmovq\t#3, r12\n\tmovq\t#2, r8\n'
TAIL = """	movq	buf, r20
	movq	buf+8, r21
	movq	buf+16, r22
	movq	buf+24, r23
	movq	buf+32, r24
	movq	buf+40, r25
	movq	buf+48, r26
	movq	buf+56, r27
	mfps	r28
	movq	#0, r0
	trap	#0
	.data
	.even
buf:	.quad	0x1111111111111111, 0x2222222222222222, 0x3333333333333333, 0x4444444444444444, 0x5555555555555555, 0x6666666666666666, 0x7777777777777777, 0x8888888888888888
	.space	256
stack_top:
	.quad	0
"""
def run(src, tag):
    s = os.path.join(W, tag + '.s'); o = os.path.join(W, tag + '.o'); x = os.path.join(W, tag + '.x')
    open(s, 'w').write(src)
    r = subprocess.run([AS, '--no-relax', '-o', o, s], capture_output=True, text=True)
    if r.returncode: return None, 'asm: ' + r.stderr.strip().split('\n')[0]
    r = subprocess.run([LD, '--no-relax', '-o', x, o], capture_output=True, text=True)
    if r.returncode: return None, 'link: ' + r.stderr.strip().split('\n')[0]
    r = subprocess.run([SIM, '-r', x], capture_output=True, text=True)
    return r.stdout + r.stderr, None
def size(src, tag):
    s = os.path.join(W, tag + '.s'); o = os.path.join(W, tag + '.o')
    return os.path.getsize(o) if os.path.exists(o) else 0
bad = 0; ran = 0; multi = 0; forms = 0
for ci, c in enumerate(cases):
    if c in SKIP_RUN: continue
    for fl in FLAGS:
        outs = {}
        text = {}
        for N in (0, 1, 2, 3):
            body = ('\t.encode %d\n' % N if N else '') + '\t' + c.replace('\n', '\n\t') + '\n' + ('\t.encode 0\n' if N else '')
            src = HEAD + '\t%s\n' % fl + body + TAIL.replace('buf+', 'buf+')
            out, err = run(src, 'c')
            if err:
                outs[N] = ('ERR', err); continue
            # the text size tells whether this N gave a form of its own
            d = open(os.path.join(W, 'c.o'), 'rb').read()
            outs[N] = (out, os.path.getsize(os.path.join(W, 'c.o')))
        good = {N: v for N, v in outs.items() if v[0] != 'ERR'}
        ref = good.get(0)
        if ref is None:
            print('SKIP  %-40s %s' % (c.split('\n')[0], outs[0][1])); break
        ran += 1
        sizes = {v[1] for v in good.values()}
        if len(sizes) > 1: multi += 1
        for N, v in good.items():
            if v[0] != ref[0]:
                bad += 1
                print('DIFF  %-40s flags(%s): .encode %d differs from the shortest' % (c.split('\n')[0], fl, N))
                a = ref[0].split('\n'); b = v[0].split('\n')
                for x, y in zip(a, b):
                    if x != y: print('        shortest: %s\n        .encode %d: %s' % (x.strip(), N, y.strip())); break
                break
print('forms: %d runs, %d of them with more than one encoding; %d differ' % (ran, multi, bad))
sys.exit(1 if bad else 0)
