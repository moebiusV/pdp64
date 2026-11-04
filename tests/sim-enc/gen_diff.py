#!/usr/bin/env python3
"""Generate tests/sim-enc/diff.s: one program that executes many instructions of the original ISA, each from two fixed register/memory states, and writes
the registers, the flags and a memory window after each to standard output.  The same source is assembled and run in pdp64/r20, pdp64/16 and
pdp64/32; tools/check-sim64.sh requires the three outputs to be byte-identical (the original encoding is the oracle for the semantics).

usage: gen_diff.py AS64 OUT.s    (AS64 is used to drop the cases that an encoding refuses to assemble; the list of drops goes to stderr)
"""
import subprocess, sys, os, tempfile

AS64, OUT = sys.argv[1], sys.argv[2]
D = tempfile.mkdtemp()

PRE = """\t.text
f1:\tadd #1,r0
\tret
f2:\tmovq #77,r12
\tret
"""
POST = """\t.data
\t.align 8
buf:\t.space 16
buf2:\t.quad 0x1122334455667788
\t.bss
\t.align 16
bigbuf:\t.space 200000
"""

cases = []
def case(*lines):
    cases.append(list(lines))

DATA = ['r1', 'r2', 'r3', 'r4', 'r5', 'r6', 'r7', 'r11', 'r12', 'r15']
MEMSRC = ['8(r8)', '(r8)', '-16(r8)', '2000(r8)', '70000(r8)', '-70000(r8)', '8(r8)(r9*1)', '16(r8)(r9*8)', '(r8)(r9*4)', '(r10)+', '-(r10)', '(r10)+16', '(r10)-16', '@buf2', 'buf2']
IMMS = ['#0', '#1', '#5', '#-1', '#-7', '#100', '#-100', '#1000', '#-1000', '#65535', '#70000', '#-70000', '#0x7fffffff', '#-0x80000000']

# moves
for mn in ['movq', 'movl', 'movw', 'movb', 'movzl', 'movzw', 'movzb']:
    case('%s r1,r2' % mn)
    for im in IMMS: case('%s %s,r2' % (mn, im))
    for m in MEMSRC: case('%s %s,r3' % (mn, m))
for mn in ['movq', 'movl', 'movw', 'movb']:
    for m in MEMSRC:
        if m.startswith('#') or m == 'buf2': continue
        case('%s r4,%s' % (mn, m))
    case('%s r4,buf2' % mn)
for m in ['8(r8)', '8(r8)(r9*8)', '70000(r8)', '(r8)', 'buf2', '@buf2']:
    case('lea %s,r2' % m)
# ALU
for mn in ['add', 'sub', 'bic', 'bis', 'bit', 'xor', 'and', 'mul', 'mulh']:
    case('%s r1,r2' % mn)
    for im in IMMS: case('%s %s,r2' % (mn, im))
    for m in MEMSRC: case('%s %s,r2' % (mn, m))
for im in IMMS[:12] + ['r1']:
    case('cmp r2,%s' % im)
for m in MEMSRC: case('cmp r2,%s' % m)
for mn in ['shl', 'shr', 'sar']:
    case('%s r1,r2' % mn)
    for im in ['#0', '#1', '#3', '#31', '#32', '#63', '#64', '#100', '#255']:
        case('%s %s,r2' % (mn, im))
for mn in ['fadd', 'fsub', 'fmul']:
    case('%s r1,r2' % mn); case('%s r3,r4' % mn); case('%s 8(r8),r2' % mn)
case('fcmp r1,r2'); case('fcmp r3,r4'); case('fcmp r1,r1')
# single operand
for mn in ['clr', 'com', 'inc', 'dec', 'neg', 'tst', 'adc', 'sbc', 'asl', 'asr']:
    for o in ['r2', '8(r8)', '(r8)', '(r10)+', '-(r10)', '8(r8)(r9*8)', '@buf2', 'buf2', '70000(r8)']:
        case('%s %s' % (mn, o))
    case('cmp r1,r2', '%s r3' % mn)
    case('cmp r1,r1', '%s r3' % mn)
    case('cmp r2,r2', 'adc r3')
case('push r1', 'pop r2')
case('push #5', 'pop r2')
case('push #-5', 'pop r2')
case('push 8(r8)', 'pop 16(r8)')
case('push r1', 'push r2', 'pop r3', 'pop r4')
case('pushm #0x0f00', 'movq #0,r8', 'movq #0,r9', 'movq #0,r10', 'popm #0x0f00')
case('pushm #0x8002', 'popm #0x8002')
case('pushm #0x1fff', 'popm #0x1fff')
case('call f1')
case('call f2')
case('lea f1,r2', 'call r2')
case('lea f1,r2', 'call (r2)')
case('lea f1,r2', 'jmp (r2)', 'add #100,r0', 'br 1f')
# branches
CONDS = ['ne', 'eq', 'pl', 'mi', 'vc', 'vs', 'cc', 'cs', 'ge', 'lt', 'gt', 'le', 'hi', 'los']
for c in CONDS:
    for a, b in [('r1', 'r2'), ('r3', 'r3'), ('r4', '#5'), ('r5', '#-5'), ('r6', 'r7')]:
        case('cmp %s,%s' % (a, b), 'b%s 1f' % c, 'add #1,r0', '1:')
        case('cmp %s,%s' % (a, b), 'cb%s r11,#3,1f' % c, 'add #1,r0', '1:')
        case('cmp %s,%s' % (a, b), 'cb%s r11,r12,1f' % c, 'add #1,r0', '1:')
        case('cmp %s,%s' % (a, b), 'cb%s r4,#0,1f' % c, 'add #1,r0', '1:')
        case('cmp %s,%s' % (a, b), 'set %s,r11' % c)
    for im in ['#5', '#-5', '#0', '#15', '#-16']:
        case('cb%s r1,%s,1f' % (c, im), 'add #1,r0', '1:')
        case('cb%s r5,%s,1f' % (c, im), 'add #1,r0', '1:')
case('br 1f', 'add #1,r0', '1:')
case('movq #3,r2', '1:', 'add #1,r0', 'sob r2,1b')
for t in range(8):
    case('btag r1,#%d,1f' % t, 'add #1,r0', '1:')
    case('bntag r3,#%d,1f' % t, 'add #1,r0', '1:')
    case('btag r7,#%d,1f' % t, 'add #1,r0', '1:')
# BESC / AESC
for mn in ['clz', 'ctz', 'clo', 'cto', 'popcnt', 'bswap', 'bswapw', 'bswapl', 'bitrev', 'abs']:
    case('%s r1,r2' % mn); case('%s r3,r4' % mn); case('%s r5,r5' % mn)
for mn in ['ror', 'xnorpop', 'clmull', 'clmulh', 'div', 'divu', 'mod', 'modu', 'mulhu', 'min', 'minu', 'max', 'maxu']:
    case('%s r1,r2,r3' % mn); case('%s r4,r5,r6' % mn); case('%s r1,r2,r2' % mn); case('%s r7,r11,r12' % mn)
for n in [0, 1, 5, 31, 32, 63]:
    case('rori r1,#%d,r2' % n); case('rori32 r3,#%d,r4' % (n % 32)); case('rol r5,#%d,r6' % n)
for n in [0, 1, 13, 63]:
    case('dshr r1,r2,#%d,r3' % n)
for pos, w in [(0, 8), (4, 8), (60, 4), (0, 63), (33, 17), (1, 1)]:
    case('extb r1,#%d,#%d,r2' % (pos, w)); case('extzb r3,#%d,#%d,r4' % (pos, w)); case('insb r5,#%d,#%d,r6' % (pos, w))
# block
case('movq #16,r5', 'mcpy r10,r8,r5')
case('movq #16,r5', 'mcpy r10,r8,r5', 'movq #8,r5', 'mcpy r8,r10,r5')
case('movq #24,r5', 'mmov r10,r8,r5')
case('lea 8(r8),r10', 'movq #24,r5', 'mmov r10,r8,r5')
case('lea 8(r8),r10', 'movq #24,r5', 'mmov r8,r10,r5')
case('movq #20,r5', 'mset r10,r1,r5')
case('movq #0,r5', 'mset r10,r1,r5')
case('movq #16,r5', 'mcmp r10,r8,r5')
case('movq #16,r5', 'mcpy r10,r8,r5', 'lea 4(r10),r10', 'lea 4(r8),r8', 'movq #12,r5', 'mcmp r10,r8,r5')
case('movq #16,r5', 'movb #77,r6', 'mscn r8,r6,r5')
case('movq #16,r5', 'movb #0,r6', 'mscn r8,r6,r5')
case('movq #16,r5', 'movb #0,r6', 'mscnn r8,r6,r5')
case('movq #16,r5', 'mset r10,r2,r5', 'movq #16,r5', 'mscnn r10,r2,r5')
# floating point (beyond the four top-level operations)
for mn in ['fdiv', 'fadd32', 'fsub32', 'fmul32', 'fdiv32', 'fcmp32', 'fadd16', 'fsub16', 'fmul16', 'fdiv16', 'fcmp16']:
    case('%s r1,r2' % mn); case('%s r3,r4' % mn); case('%s r5,r6' % mn)
for mn in ['fsqrt', 'fsqrt32', 'fsqrt16', 'fneg', 'fabs', 'fclass', 'fclass16', 'frint', 'frintz', 'frintm', 'frintp', 'frinta', 'fcvtdq', 'fcvtqd', 'fcvtds', 'fcvtsd', 'fcvtsl', 'fcvtls',
           'fcvtdqu', 'fcvtqud', 'fcvtsh', 'fcvths', 'fcvtdh', 'fcvthd', 'fcvthl', 'fcvtlh', 'fsflags']:
    case('%s r1,r2' % mn); case('%s r3,r4' % mn); case('%s r5,r6' % mn)
for mn in ['fcopysign', 'fmin', 'fmax']:
    case('%s r1,r2,r3' % mn); case('%s r4,r5,r6' % mn)
for mn in ['fmadd', 'fmsub', 'fnmadd', 'fnmsub', 'fmadd32', 'fmsub32', 'fnmadd32', 'fnmsub32', 'fmadd16', 'fmsub16', 'fnmadd16', 'fnmsub16']:
    case('%s r1,r2,r3,r4' % mn); case('%s r5,r6,r7,r11' % mn)
# system registers of the user
case('mfps r2'); case('movq #15,r2', 'mtps r2'); case('movq #5,r2', 'mtps r2', 'mfps r3'); case('mtdp r1', 'mfdp r2'); case('mtdp r8', 'movq 16(dp),r2'); case('mtdp r8', 'movq r3,24(dp)')
case('nop'); case('fence'); case('lpad')

# which cases does every encoding assemble?
def asm_ok(mode, lines):
    src = PRE + '\t.text\nstart:\n' + ''.join('\t%s\n' % l if not l.endswith(':') else l + '\n' for l in lines) + POST
    p = os.path.join(D, 't.s'); open(p, 'w').write(src)
    r = subprocess.run([AS64] + (['-m', 'pdp64/' + mode] if mode != 'r20' else []) + ['-o', os.path.join(D, 't.o'), p], capture_output=True, text=True)
    return r.returncode == 0, r.stderr.strip().split('\n')[0] if r.stderr else ''

keep = []; drops = []
for c in cases:
    bad = [(m, asm_ok(m, c)[1]) for m in ('r20', '16', '32') if not asm_ok(m, c)[0]]
    if bad: drops.append((c, bad))
    else: keep.append(c)
for c, bad in drops: print('drop', c, bad, file=sys.stderr)
print('%d cases kept, %d dropped' % (len(keep), len(drops)), file=sys.stderr)

TABA = [0x0123456789abcdef, 0xffffffffffffff85, 0x8000000000000001, 7, 0x00000000ffffff00, 0x7ff0000000000001, 0x3ff8000000000000, 0x4008000000000000, 0xc01c000000000000, 0x00000000fffe5555, 0x40490fdb, 0x3c00]
TABB = [0xfedcba9876543210, 5, 0xffffffff80000000, 0x7fffffffffffffff, 0x000000000000003f, 0x400921fb54442d18, 0x3fe0000000000000, 0x7fc0000000000000, 0xfffffffffffffffd, 0x0000ffff00ff0f0f, 0x3f800000, 0x7c01]
REGS = ['r0', 'r1', 'r2', 'r3', 'r4', 'r5', 'r6', 'r7', 'r9', 'r11', 'r12', 'r15']   # r8 and r10 are pointers, set by init

o = []
w = o.append
w('; GENERATED by tests/sim-enc/gen_diff.py -- do not edit.  Instructions of the original ISA, each run from two fixed states; the log goes to stdout.')
w('\t.text\n\t.globl _start\n_start:\n\tlea logbuf,r0\n\tmovq r0,@logp')
for k, c in enumerate(keep):
    for ini in 'AB':
        w('\tcall init%s' % ini)
        w('case%d%s:' % (k, ini))
        for l in c: w('\t%s' % l if not l.endswith(':') else l)
        w('\tcall dump')
w('\tlea logbuf,r1\n\tmovq @logp,r2\n\tsub r1,r2\n\tmovq #1,r0\n\ttrap #1\n\tclr r0\n\ttrap #0')
w('f1:\tadd #1,r0\n\tret\nf2:\tmovq #77,r12\n\tret')
for ini, tab in (('A', TABA), ('B', TABB)):
    w('init%s:' % ini)
    for i, r in enumerate(REGS):
        w('\tmovq =0x%x,%s' % (tab[i], r) if False else '\tmovq tab%s+%d,%s' % (ini, 8 * i, r))
    w('\tlea bigbuf+100000,r8\n\tlea bigbuf+100000,r10\n\tmovq #16,r9')
    w('\tpush r0\n\tpush r1\n\tpush r2\n\tlea wintpl%s,r0\n\tlea bigbuf+99872,r1\n\tmovq #64,r2\n1:\tmovq (r0)+,r12\n\tmovq r12,(r1)+\n\tsob r2,1b' % ini)
    w('\tpop r2\n\tpop r1\n\tpop r0\n\tmovq tab%s+%d,r12\n\tret' % (ini, 8 * REGS.index('r12')))
w('''dump:\tmovq r11,sv11
\tmfps r11
\tmovq r11,svps
\tmovq logp,r11
\tmovq r0,(r11)+
\tmovq r1,(r11)+
\tmovq r2,(r11)+
\tmovq r3,(r11)+
\tmovq r4,(r11)+
\tmovq r5,(r11)+
\tmovq r6,(r11)+
\tmovq r7,(r11)+
\tmovq r8,(r11)+
\tmovq r9,(r11)+
\tmovq r10,(r11)+
\tmovq sv11,r0
\tmovq r0,(r11)+
\tmovq r12,(r11)+
\tmovq r15,(r11)+
\tmovq svps,r0
\tmovq r0,(r11)+
\tlea bigbuf+99872,r1
\tmovq #64,r2
1:\tmovq (r1)+,r0
\tmovq r0,(r11)+
\tsob r2,1b
\tmovq r11,logp
\tret''')
w('\t.data\n\t.align 8')
for ini, tab in (('A', TABA), ('B', TABB)):
    w('tab%s:' % ini + '\t.quad ' + ', '.join('0x%x' % v for v in tab))
    w('wintpl%s:' % ini + '\t.quad ' + ', '.join('0x%x' % ((0x9e3779b97f4a7c15 * (i + 1 + (7 if ini == 'B' else 0))) & 0xffffffffffffffff) for i in range(64)))
w('logp:\t.quad 0\nsv11:\t.quad 0\nsvps:\t.quad 0\nbuf:\t.space 16\nbuf2:\t.quad 0x1122334455667788')
w('\t.bss\n\t.align 16\nbigbuf:\t.space 200000\nlogbuf:\t.space %d' % (len(keep) * 2 * 8 * 80))
open(OUT, 'w').write('\n'.join(o) + '\n')
