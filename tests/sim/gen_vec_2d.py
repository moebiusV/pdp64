#!/usr/bin/env python3
"""Generate tests/sim/vec-2d.S: the 2D block `vec2 Rs, Re, Rn, Rw` with its `vskip` words (errata 176, docs/encoding-work/vec-2d.md): results, final registers, and fault and restart.

What it proves, at every strip (sim64 -S 16, 32, 64: vec-2d.strips) and on QEMU:
  (a) a tile run with no fault gives the memory, the scalar result and the final registers of a model written here in Python from the definition (not from a run): every pointer
      that has a vskip is at its entry value plus rows * pitch, Re at entry + (row width + rows * pitch of stream 1) ... Rn is 0; a stream with no vskip is contiguous;
  (b) a fault in the first, a middle and the last row, and at the first element of a row, in the middle of a row and at its last element (so in the first, a middle and the last (short)
      strip of the row at one strip or another), on each of the streams of four kernels (a reduction, a store, a widening store, an in-place update through two pointers): exactly one
      fault, EPC the address of the vec2, ECAUSE a page fault, EVA the first faulting access in the order of the elements; the handler reads EPC, EVA and ECAUSE only, maps the page
      and returns, the vec2 is executed again with the registers as the fault left them and the result must be that of the run with no fault (memory checksum, scalar, final registers);
  (c) the registers the handler sees (kind F, a handler that saves them): the row count has fallen by the rows completed, r' <= the faulting row, and the pointer of stream A is at
      row r' and column c' with c' <= the faulting column when r' is the faulting row (the opaque progress of errata 173, extended to rows).
The window pages are made present by touching them (the handler maps and fills them with the function fb(a) = (5a + (a >> 7)) & 255 of their address), except the one page that
faults, which begins at the element of the faulting stream that the scenario names.
usage: gen_vec_2d.py OUT.S"""
import sys

WIN = 0x800000
PAGE = 4096
def fb(a): return (5 * a + (a >> 7)) & 255
M64 = (1 << 64) - 1

# kernel: name, entry registers: the streams of the kernel with (register, element bytes, role), the body, the scalar model
KERN = {
    'sad': dict(streams=[('A', 'r1', 1, 'r'), ('B', 'r2', 1, 'r')], body=['vld.bu v0, (r1)+', 'vld.bu v1, (r2)+', 'vsad.bu r10, v0, v1'], skip=[('r1', 'r7'), ('r2', 'r8')]),
    'avg': dict(streams=[('A', 'r1', 1, 'r'), ('B', 'r2', 1, 'r'), ('O', 'r3', 1, 'w')], body=['vld.b v0, (r1)+', 'vld.b v1, (r2)+', 'vavgu.b v2, v0, v1', 'vst.b v2, (r3)+'],
                skip=[('r1', 'r7'), ('r2', 'r8'), ('r3', 'r9')]),
    'wid': dict(streams=[('A', 'r1', 1, 'r'), ('O', 'r3', 2, 'w')], body=['vld.bu.w v0, (r1)+', 'vadd.w v0, v0, #7', 'vst.w v0, (r3)+'], skip=[('r1', 'r7'), ('r3', 'r9')]),
    'inp': dict(streams=[('A', 'r1', 1, 'rw'), ('B', 'r2', 1, 'r')], body=['vld.b v0, (r1)+', 'vld.b v1, (r2)+', 'vadd.b v0, v0, v1', 'vst.b v0, (r3)+'],
                skip=[('r1', 'r7'), ('r2', 'r8'), ('r3', 'r7')]),
}
NAMES = list(KERN)


def sim(kn, W, R, base, pitch, init):
    """the model: the final memory (a dict address -> byte, only what the block changes), the scalar, from the definition.  base, pitch: by stream name; W: bytes of a row of stream 1 (= elements)."""
    mem = {}
    def rd(a): return mem.get(a, fb(a))
    acc = init
    for r in range(R):
        for c in range(W):
            a = base['A'] + r * pitch['A'] + c
            if kn == 'sad':
                acc += abs(rd(a) - rd(base['B'] + r * pitch['B'] + c))
            elif kn == 'avg':
                mem[base['O'] + r * pitch['O'] + c] = (rd(a) + rd(base['B'] + r * pitch['B'] + c) + 1) >> 1
            elif kn == 'wid':
                v = (rd(a) + 7) & 0xffff
                o = base['O'] + r * pitch['O'] + 2 * c
                mem[o] = v & 255; mem[o + 1] = v >> 8
            elif kn == 'inp':
                mem[a] = (rd(a) + rd(base['B'] + r * pitch['B'] + c)) & 255
    return mem, acc & M64


def region(kn, W, R, base, pitch):
    """the bytes whose checksum is compared: the footprint of the store stream (gaps included, they must stay as they were)"""
    for nm, reg, es, role in KERN[kn]['streams']:
        if 'w' in role and nm in ('O', 'A') and (kn != 'inp' or nm == 'A'):
            return base[nm], (R - 1) * pitch[nm] + W * es if R else 0
    return base['A'], 0


def csum(mem, lo, n):
    s = 0
    for i in range(n):
        a = lo + i
        s = (s * 31 + mem.get(a, fb(a))) & M64
    return s


cases = []


def case(kn, W, R, bases, pitch, fault=None, init=1000, kind=0):
    """bases: stream name -> window address; fault: None or (stream, row, col); kind 0 handler reads EPC, EVA, ECAUSE only; 1 a handler that saves the registers"""
    k = KERN[kn]
    mem, acc = sim(kn, W, R, bases, pitch, init)
    lo, n = region(kn, W, R, bases, pitch)
    c = dict(kn=kn, W=W, R=R, base=dict(bases), pitch=dict(pitch), fault=fault, init=init, acc=acc, sum=csum(mem, lo, n), lo=lo, n=n, kind=kind)
    # the page that faults begins at the first byte of the faulting element
    if fault:
        s, r, col = fault
        es = [x[2] for x in k['streams'] if x[0] == s][0]
        c['fpage'] = bases[s] + r * pitch[s] + col * es
        assert c['fpage'] % PAGE == 0
        c['eva'] = c['fpage']
    cases.append(c)


# the window of a case: four pages from WB; the faulting page is WB + 8192; the other streams live in page 0
def layout(kn, fault, W, R, pitch):
    k = KERN[kn]
    names = [x[0] for x in k['streams']]
    return names


WB = [WIN]


def newwin():
    w = WB[0]; WB[0] += 4 * PAGE
    return w


PITCH = {'A': 72, 'B': 96, 'O': 80}
PITCHW = {'A': 72, 'B': 96, 'O': 160}       # the widening store has 2-byte elements: its row pitch in bytes
for kn in NAMES:
    k = KERN[kn]
    pt = dict(PITCH)
    if kn == 'wid': pt = dict(PITCHW)
    # no fault: a few tile shapes (a row narrower than a strip, one row, a row of several strips, no rows)
    for (W, R) in [(40, 9), (5, 3), (64, 2), (16, 1), (130, 4), (33, 0)]:
        wb = newwin()
        bases = {'A': wb + 256, 'B': wb + PAGE + 256, 'O': wb + 3 * PAGE + 256}
        p = dict(pt)
        if W > 60: p = {n: v + 2 * W for n, v in pt.items()}
        case(kn, W, R, bases, p)
    # faults: each stream, rows 0, 4, 8, columns 0, 16, 39
    W, R = 40, 9
    for (s, reg, es, role) in k['streams']:
        if kn == 'inp' and False: continue
        for r in (0, 4, 8):
            for col in (0, 16, 39):
                wb = newwin()
                bases = {'A': wb + 256, 'B': wb + PAGE + 256, 'O': wb + 3 * PAGE + 256}
                bases[s] = wb + 2 * PAGE - (r * pt[s] + col * es)
                case(kn, W, R, bases, pt, fault=(s, r, col), kind=0)
    # the handler that saves the registers: stream A, a few places
    for (r, col) in ((0, 0), (4, 16), (8, 39)):
        wb = newwin()
        bases = {'A': wb + 256, 'B': wb + PAGE + 256, 'O': wb + 3 * PAGE + 256}
        bases['A'] = wb + 2 * PAGE - (r * pt['A'] + col)
        case(kn, 40, 9, bases, pt, fault=('A', r, col), kind=1)
assert WB[0] <= WIN + 0x1000000, 'the window is 16 MiB'

O = []
w = O.append
w('; GENERATED by tests/sim/gen_vec_2d.py -- do not edit.  The 2D block vec2 Rs, Re, Rn, Rw with vskip (errata 176, docs/encoding-work/vec-2d.md): results and final registers against a model in Python,')
w('; and a fault in a first, middle and last row and strip, on each stream of four kernels, with a handler that reads EPC, EVA and ECAUSE only, and one that saves the registers.')
w('; %d cases; a failed check n halts with status n (checks in the generator); sim64 -K -x 0x800000:0x1800000 at the strips of vec-2d.strips, QEMU with its MMU.' % len(cases))
w('#include "pdp64-consts.h"')
w('\t.text')
w('\t.globl\t_start')
w('_start:')
for l in ['lea\tstk_top, sp', 'lea\tvtab, r1', 'mtsr\tvbr, r1', 'lea\tl2, r1', 'mtsr\tptbr, r1', 'movq\t#1, r1', 'mtsr\tmmuctl, r1', 'lea\tcases, r12', 'lea\tcases_end, r13']:
    w('\t' + l)
# case record (all quads), offsets: 0 kernel code, 8 vec2 address, 16 W, 24 R, 32 pA, 40 pB, 48 pO, 56 gapA, 64 gapB, 72 gapO, 80 init, 88 fault (0/1), 96 eva, 104 expected sum, 112 lo, 120 n, 128 expected acc,
# 136 kind, 144 touch mask (pages 0..3), 152 Re row-advance expected final A, 160.. final p1, p2, p3 (expected), 184 final Rn... (0), 192 pitch A
w('caseloop:')
w('\tcbeq\tr12, r13, alldone')
# touch the pages that do not fault (the handler maps and fills them: expect 0)
w('\tmovq\t#0, r1')
w('\tmovq\tr1, expect')
w('\tmovq\t144(r12), r2')                     # the window base of the case
w('\tmovq\t#4, r3')
w('tch:\tmovq\t96(r12), r5')
w('\tcbeq\tr2, r5, tchs')
w('\tmovzb\t(r2), r1')
w('tchs:')
w('\tmovq\t#0, r4')
w('\tadd\t#4096, r2')
w('\tsob\tr3, tch')
w('\tmovq\t#0, r1')
w('\tmovq\tr1, hcount')
w('\tmovq\tr1, hr_epc')
w('\tmovq\t88(r12), r1')
w('\tmovq\tr1, expect')
w('\tmovq\t32(r12), r1')
w('\tmovq\t40(r12), r2')
w('\tmovq\t48(r12), r3')
w('\tmovq\t56(r12), r7')
w('\tmovq\t64(r12), r8')
w('\tmovq\t72(r12), r9')
w('\tmovq\t16(r12), r6')
w('\tmovq\t24(r12), r5')
w('\tmovq\t80(r12), r10')
w('\tmovq\t(r12), r4')
w('\tcall\tr4')
w('\tmovq\tr1, fin_r1')
w('\tmovq\tr2, fin_r2')
w('\tmovq\tr3, fin_r3')
w('\tmovq\tr4, fin_r4')
w('\tmovq\tr5, fin_r5')
w('\tmovq\tr10, fin_r10')
w('\tmovq\t#0, r1')
w('\tmovq\tr1, expect')
def chk(n, a, b):
    return ['\tmovq\t%s, r1' % a, '\tmovq\t%s, r2' % b, '\tcbeq\tr1, r2, 1f', '\tmovq\t#%d, r0' % n, '\thalt', '1:']
# the fault (exactly one, EPC, cause, EVA)
w('\tmovq\t88(r12), r1')
w('\tcbeq\tr1, #0, nofault')
for l in chk(1, 'hcount', '#1'.replace('#1', 'one')): w(l)
for l in chk(2, 'hr_epc', '8(r12)'): w(l)
for l in chk(3, 'hr_eva', '96(r12)'): w(l)
w('\tmovq\thr_cause, r1')
w('\tcmp\tr1, #VECTOR_LFAULT')
w('\tbeq\tcausedone')
w('\tcmp\tr1, #VECTOR_SFAULT')
w('\tbeq\tcausedone')
w('\tmovq\t#4, r0')
w('\thalt')
w('causedone:')
# kind 1: the registers the handler saw
w('\tmovq\t136(r12), r1')
w('\tcbeq\tr1, #0, nofault')
# row count: entry R minus completed rows r' (r' <= the faulting row, carried in 200(r12)); pointer A at row r', column c'
w('\tmovq\t24(r12), r1')
w('\tmovq\thr_r5, r2')
w('\tsub\tr2, r1')                              # r' = R - Rn
w('\tmovq\t200(r12), r3')                      # faulting row
w('\tcblos\tr1, r3, 1f')
w('\tmovq\t#5, r0')
w('\thalt')
w('1:\tmovq\t192(r12), r4')                    # pitch A
w('\tmovq\tr1, r6')
w('\tcall\tmulq')                              # r6 = r' * pitchA (r4)
w('\tmovq\t32(r12), r2')
w('\tadd\tr6, r2')                              # the start of row r'
w('\tmovq\thr_r1, r5')
w('\tsub\tr2, r5')                              # c' = Rs - the start of row r'
w('\tcbeq\tr1, r3, 2f')                         # an earlier row: c' in 0..W
w('\tmovq\t16(r12), r4')
w('\tcblos\tr5, r4, nofault')
w('\tmovq\t#6, r0')
w('\thalt')
w('2:\tmovq\t208(r12), r4')                     # the faulting column
w('\tcblos\tr5, r4, nofault')
w('\tmovq\t#7, r0')
w('\thalt')
w('nofault:')
# the final registers: Rn is 0, the pointers have moved by rows * pitch, Re by one row's width and the rows' pitches
for l in chk(8, 'fin_r5', 'zero'): w(l)
for l in chk(9, 'fin_r1', '160(r12)'): w(l)
for l in chk(10, 'fin_r2', '168(r12)'): w(l)
for l in chk(11, 'fin_r3', '176(r12)'): w(l)
for l in chk(12, 'fin_r4', '184(r12)'): w(l)
for l in chk(13, 'fin_r10', '128(r12)'): w(l)
# the checksum of the store stream's footprint: s = s * 31 + byte
w('\tmovq\t112(r12), r1')
w('\tmovq\t120(r12), r3')
w('\tmovq\t#0, r2')
w('\tcbeq\tr3, #0, sumdone')
w('sml:\tmovzb\t(r1)+, r4')
w('\tmovq\tr2, r5')
w('\tshl\t#5, r2')
w('\tsub\tr5, r2')
w('\tadd\tr4, r2')
w('\tsob\tr3, sml')
w('sumdone:\tmovq\t104(r12), r1')
w('\tcbeq\tr1, r2, 1f')
w('\tmovq\t#14, r0')
w('\thalt')
w('1:\tadd\t#256, r12')
w('\tbr\tcaseloop')
w('alldone:\tmovq\t#0, r0')
w('\thalt')
HAND = r'''
mulq:	; r6 = r6 * r4 (small values)
	movq	r6, r7
	movq	#0, r6
	cbeq	r7, #0, mq_d
mq_l:	add	r4, r6
	sob	r7, mq_l
mq_d:	ret

h_bad:	movq	#99, r0
	halt
h_fault:
	pushm	#0x3fff
	movq	r1, hr_r1
	movq	r5, hr_r5
	mfsr	r1, epc
	movq	r1, hr_epc
	mfsr	r1, ecause
	movq	r1, hr_cause
	mfsr	r1, eva
	movq	r1, hr_eva
	movq	expect, r2
	cbeq	r2, #0, h_page
	movq	hcount, r2
	add	#1, r2
	movq	r2, hcount
h_page:
	mfsr	r1, eva
	shr	#12, r1
	shl	#12, r1
	movq	r1, r2
	movq	=0x800000, r3
	sub	r3, r2
	shr	#12, r2
	shl	#3, r2
	lea	wpt, r3
	add	r3, r2
	movq	r1, r3
	bis	#(1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_A|1<<PTE_D), r3
	movq	r3, (r2)
	tlbi	r1
	movq	r1, r3
	movq	#4096, r4
h_fl:	movq	r3, r5
	movq	r3, r6
	shl	#2, r6
	add	r6, r5
	movq	r3, r6
	shr	#7, r6
	add	r6, r5
	movb	r5, (r3)+
	sob	r4, h_fl
	popm	#0x3fff
	rti	#RTIMASK_ALL
'''
w(HAND)
# the kernels: r1 = pA, r2 = pB, r3 = pO, r4 = Re, r5 = rows, r6 = the row width, r7, r8, r9 = the gaps (pitch - the bytes of a row of the stream), r10 = the scalar
for kn in NAMES:
    k = KERN[kn]
    w('\t.align 2')
    w('k_%s:' % kn)
    w('\tlea\t(r1)(r6), r4')
    w('k_%s_vec:' % kn)
    w('\tvec2\tr1, r4, r5, r6')
    for (p, g) in k['skip']:
        w('\tvskip\t%s, %s' % (p, g))
    for b in k['body']:
        w('\t' + b)
    w('\tvend')
    w('\tret')
w('\t.data')
w('\t.align\t8')
w('vtab:')
w('\t.space\t16')
for v in range(2, 16):
    w('\t.quad\t%s' % ('h_fault' if v in (4, 7, 8, 13) else 'h_bad'))
w('\t.quad\th_bad')
w('\t.align\t8')
for nm in ('expect', 'hcount', 'hr_epc', 'hr_cause', 'hr_eva', 'hr_r1', 'hr_r5', 'fin_r1', 'fin_r2', 'fin_r3', 'fin_r4', 'fin_r5', 'fin_r10', 'zero', 'one'):
    w('%s:\t.quad\t%d' % (nm, 1 if nm == 'one' else 0))
w('\t.align\t8')
w('cases:')
for c in cases:
    kn = c['kn']; k = KERN[kn]; W, R = c['W'], c['R']
    b = c['base']; p = c['pitch']
    wb = min(b.values()) // (4 * PAGE) * (4 * PAGE)
    wb = WIN + ((min(b.values()) - WIN) // (4 * PAGE)) * 4 * PAGE
    if c['fault']: wb = (c['fpage'] - 2 * PAGE)
    es = {s: e for (s, r_, e, ro) in k['streams']}
    esO = es.get('O', 1)
    gaps = {}
    for (pr, g) in k['skip']:
        pass
    # the gap registers: pitch - the bytes of a row of the stream (r7: A, r8: B, r9: O)
    gA = p['A'] - W * 1
    gB = p.get('B', 0) - W
    gO = p.get('O', 0) - W * es.get('O', 1)
    pA, pB, pO = b.get('A', 0), b.get('B', 0), b.get('O', 0)
    if kn == 'inp': pO = pA
    if kn == 'wid': pB = 0
    if kn == 'sad': pO = 0
    # the registers after the block
    f1 = pA + R * p['A'] if R else pA
    f2 = pB + R * p['B'] if (R and kn != 'wid') else pB
    f3 = pO + R * (p['O'] if kn != 'inp' else p['A']) if R else pO
    if kn == 'sad': f3 = pO
    f4 = (pA + W) + R * p['A'] if R else pA + W
    # a case with W rows of the 33-wide shape etc.: the pointers of a stream with vskip move by R * pitch
    fr = c['fault'][1] if c['fault'] else 0
    fc = c['fault'][2] if c['fault'] else 0
    vals = ['k_%s' % kn, 'k_%s_vec' % kn, W, R, pA, pB, pO, gA, gB, gO, c['init'], 1 if c['fault'] else 0, c['eva'] if c['fault'] else 0, c['sum'], c['lo'], c['n'], c['acc'], c['kind'],
            wb, 0, f1, f2, f3, f4, 0, 0, 0, 0, 0, 0, 0, 0]
    # offsets: 0 code, 8 vec, 16 W, 24 R, 32 pA, 40 pB, 48 pO, 56 gA, 64 gB, 72 gO, 80 init, 88 fault, 96 eva, 104 sum, 112 lo, 120 n, 128 acc, 136 kind, 144 wb, 152 -, 160 f1, 168 f2, 176 f3, 184 f4, 192 pitchA, 200 frow, 208 fcol
    vals = vals[:24]
    vals += [p['A'], fr, fc, 0, 0, 0, 0, 0]
    assert len(vals) == 32
    for i in range(0, 32, 4):
        w('\t.quad\t' + ', '.join(str(x) if not isinstance(x, str) else x for x in vals[i:i + 4]))
w('cases_end:')
w('\t.space\t8192')
w('stk_top:')
NW = 0x1000000 // (2 << 20)
W0 = WIN // (2 << 20)
w('\t.align\t4096')
w('l2:')
w('\t.quad\tl1 + (1<<PTE_V)')
w('\t.space\t4088')
w('\t.align\t4096')
w('l1:')
for i in range(512):
    if W0 <= i < W0 + NW:
        w('\t.quad\twpt + %d + (1<<PTE_V)' % ((i - W0) * 4096))
    else:
        w('\t.quad\t%d + (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D)' % (i << 21))
w('\t.align\t4096')
w('wpt:\t.space\t%d' % (NW * 4096))
open(sys.argv[1], 'w').write('\n'.join(O) + '\n')
print('%d cases' % len(cases))
