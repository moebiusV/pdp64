#!/usr/bin/env python3
"""Validation of the timing model against microbenchmarks whose cycle count is worked out by hand from the model's stated pipeline.

usage: check_timing.py BUILD_DIR      (exits 1 if any differs)

The pipeline (docs/timing-model.md): fetch request at cycle R, bytes in the buffer at R+fl, decode at R+fl+ldec, ready to issue dl cycles after that.  So with the
program starting at cycle 0 the first instruction issues at t0 = fl + ldec + dl (2 with the base parameters).  The cycle count is the cycle of the last issue (the
exit `trap #0`, held for `sys` cycles) plus 1.  Each expectation below is a closed formula in the parameters; the formula is derived on paper from that
description, not from the code.  The base configuration has an ideal memory system, perfect branch prediction, ldec=0 and a wide fetch, so that
the count does not depend on the lengths of the instructions unless the test is about fetch.
"""
import sys, os, subprocess, re, tempfile

B = sys.argv[1] if len(sys.argv) > 1 else 'build'
AS, LD, SIM = B + '/as64', B + '/ld64', B + '/sim64'
ENCS = [('pdp64', [])]
BASE = dict(iw=1, W=16, N=64, fl=1, dl=1, ldec=0, sys=1, alu=1, ld=3, mul=3, div=20, pred='perfect', tkb=1, btb=0, brlat=1, dq=4, mp=1, mpx=0, ic=0, dc=0, decw=16, ras=16)
TMP = tempfile.mkdtemp(prefix='tmchk')
fails = 0; ran = 0

def spec(**kw):
    d = dict(BASE); d.update(kw)
    return ','.join('%s=%s' % kv for kv in d.items())

def run(src, enc, name, specs, extra=()):
    """assemble+link src for enc, run with every spec; returns a list of dicts (cycles, insns...) and the profile as {pc: (count, bytes)}"""
    asmf = '%s/%s.%s.s' % (TMP, name, enc[0]); open(asmf, 'w').write(src)
    o = asmf[:-2] + '.o'; x = asmf[:-2] + '.x'; prof = asmf[:-2] + '.prof'
    r = subprocess.run([AS] + enc[1] + ['-o', o, asmf], capture_output=True, text=True)
    if r.returncode: raise SystemExit('as64: ' + r.stderr)
    r = subprocess.run([LD, '-o', x, o], capture_output=True, text=True)
    if r.returncode: raise SystemExit('ld64: ' + r.stderr)
    cmd = [SIM, '-P', prof] + ['--timing=' + s for s in specs] + [x]
    r = subprocess.run(cmd, capture_output=True, text=True)
    res = []
    for l in r.stderr.splitlines():
        if l.startswith('tm '):
            res.append(dict(kv.split('=', 1) for kv in l[3:].split()))
    for d in res:                                   # the accounting identity: every cycle is an issue cycle, a fetch-wait, an execute-wait or a holding cycle
        tot = sum(int(d[k]) for k in d if k.startswith(('fe_', 'ex_', 'occ_'))) + int(d['active'])
        if tot != int(d['cycles']): raise SystemExit('accounting identity broken in %s: %d != %s' % (name, tot, d['cycles']))
    pr = {}
    for l in open(prof):
        if not l.startswith('#'):
            pc, n, by, cat = l.split(); pr[int(pc, 16)] = (int(n), int(by))
    return res, pr

def check(name, what, got, want):
    global fails, ran
    ran += 1
    if int(got) == want: print('ok   %s %s: %d cycles' % (name, what, want))
    else: print('FAIL %s %s: got %d, expected %d' % (name, what, int(got), want)); fails += 1

def prog(body, data=''):
    return '\t.text\n\t.globl _start\n_start:\n' + body + '\tmovq\t#0, r0\n\ttrap\t#0\n' + ('\t.data\n' + data if data else '')

# ---- 1. a chain of N dependent adds, ALU latency A: movq at t0, add_k at t0+1+(k-1)A, `movq #0,r0` the cycle after the last add (in order), trap the cycle after that
def t_chain():
    N = 8
    src = prog('\tmovq\t#1, r1\n' + '\tadd\t#1, r1\n' * N)
    for A in (1, 2, 3, 5):
        for enc in ENCS:
            res, _ = run(src, enc, 'chain', [spec(alu=A)])
            t0 = 2
            check('chain', 'N=%d alu=%d %s' % (N, A, enc[0]), res[0]['cycles'], t0 + (N - 1) * A + 4)

# ---- 2. independent adds: 4 registers in rotation; iw=1 one per cycle; iw=2 two per cycle (the trap, dependent on the movq before it, goes alone)
def t_indep():
    N = 40
    src = prog(''.join('\tmovq\t#0, r%d\n' % k for k in (1, 2, 3, 4)) + ''.join('\tadd\t#1, r%d\n' % (1 + i % 4) for i in range(N)))
    M = 4 + N + 2                                   # instructions in all: 4 movq, N add, movq r0, trap
    for enc in ENCS:
        res, _ = run(src, enc, 'indep', [spec(iw=1), spec(iw=2)])
        check('indep', 'iw=1 %s' % enc[0], res[0]['cycles'], 2 + M)
        check('indep', 'iw=2 %s' % enc[0], res[1]['cycles'], 2 + (M - 1 + 1) // 2 + 1)   # ceil((M-1)/2) cycles for all but the trap, then the trap

# ---- 3. a load-use chain: p = *p, N times, load-use latency L (the pointer cell points at itself)
def t_loadchain():
    N = 10
    src = prog('\tmovq\t#p, r1\n' + '\tmovq\t(r1), r1\n' * N, 'p:\t.quad\tp\n')
    for L in (2, 3, 4, 6):
        for enc in ENCS:
            res, _ = run(src, enc, 'ldchain', [spec(ld=L)])
            check('loadchain', 'N=%d ld=%d %s' % (N, L, enc[0]), res[0]['cycles'], 2 + (N - 1) * L + 4)

# ---- 4. a multiply chain
def t_mulchain():
    N = 8
    src = prog('\tmovq\t#3, r1\n' + '\tmul\t#3, r1\n' * N)
    for M in (2, 3, 4, 8):
        for enc in ENCS:
            res, _ = run(src, enc, 'mulchain', [spec(mul=M)])
            check('mulchain', 'N=%d mul=%d %s' % (N, M, enc[0]), res[0]['cycles'], 2 + (N - 1) * M + 4)

# ---- 5. a non-pipelined divider: four independent divides to different registers issue D apart; the exit does not wait for their results
def t_div():
    N = 4
    src = prog('\tmovq\t#100, r7\n\tmovq\t#7, r8\n' + ''.join('\tdiv\tr7, r8, r%d\n' % (9 + k) for k in range(N)))
    for D in (6, 20, 35):
        for enc in ENCS:
            res, _ = run(src, enc, 'div', [spec(div=D)])
            # movq r7 at 2, movq r8 at 3, div_1 at 4 (r8 ready), div_k at 4+(k-1)D, movq r0 next cycle, trap next
            check('div', 'N=%d div=%d %s' % (N, D, enc[0]), res[0]['cycles'], 4 + (N - 1) * D + 3)

# ---- 6. a loop `add; sob`: the redirect after the predicted-taken sob.  sob issues at s, was decoded at d = s - dl; the fetch unit gets the target at R = d + tkb, the add arrives at R + fl,
#         is decoded at R+fl+ldec, issues dl later: the next add issues at s + tkb + fl + ldec + dl - dl + dl... worked out below
def t_loop():
    N = 20
    src = prog('\tmovq\t#%d, r1\n\tmovq\t#0, r2\n1:\tadd\t#1, r2\n\tsob\tr1, 1b\n' % N)
    for tkb, ldec, fl, dl in ((1, 0, 1, 1), (0, 0, 1, 1), (2, 0, 1, 1), (1, 1, 1, 1), (1, 0, 2, 1), (1, 0, 1, 2)):
        for enc in ENCS:
            res, _ = run(src, enc, 'loop', [spec(tkb=tkb, ldec=ldec, fl=fl, dl=dl)])
            t0 = fl + ldec + dl
            # add_1 at t0+2 (after the two movq), sob_1 one cycle later (flags/r1 ready); sob decoded at (its issue - dl) if it flows, so R = s - dl + tkb; the next add
            # issues at R + fl + ldec + dl = s + tkb + fl + ldec.  Period of one iteration = 1 (add -> sob) + tkb + fl + ldec  (but at least 2: two instructions, one slot)
            per = max(2, 1 + tkb + fl + ldec)
            add1 = t0 + 2
            lastsob = add1 + (N - 1) * per + 1
            # after the last sob (not taken): movq r0 at +1, trap at +2  (the fall-through bytes are in the same fetch window or were fetched ahead: no stall)
            exp = lastsob + 2 + 1
            check('loop', 'N=%d tkb=%d ldec=%d fl=%d dl=%d %s' % (N, tkb, ldec, fl, dl, enc[0]), res[0]['cycles'], exp)

# ---- 7. mispredicted branches: pred=none (always predict not taken) makes every taken sob a misprediction: resolved brlat after issue, fetch restarts, the target issues
#         brlat + fl + ldec + dl cycles after the sob
def t_mispredict():
    N = 20
    src = prog('\tmovq\t#%d, r1\n\tmovq\t#0, r2\n1:\tadd\t#1, r2\n\tsob\tr1, 1b\n' % N)
    for brlat, mpx, ldec in ((1, 0, 0), (2, 0, 0), (1, 3, 0), (1, 0, 2), (3, 2, 1)):
        for enc in ENCS:
            res, _ = run(src, enc, 'misp', [spec(pred='none', brlat=brlat, mpx=mpx, ldec=ldec)])
            t0 = 1 + ldec + 1
            per = 1 + brlat + mpx + 1 + ldec + 1          # add -> sob 1 cycle; sob issue -> redirect brlat+mpx; request, arrival fl=1, decode ldec, ready dl=1
            add1 = t0 + 2
            lastsob = add1 + (N - 1) * per + 1
            exp = lastsob + 2 + 1
            check('mispredict', 'N=%d brlat=%d mpx=%d ldec=%d %s' % (N, brlat, mpx, ldec, enc[0]), res[0]['cycles'], exp)
            check('mispredict', 'count %s' % enc[0], res[0]['mispred'], N - 1)

# ---- 8. a straight line of instructions that is limited by fetch: independent `movq #imm64, rK`, W bytes per cycle, one window per cycle.
#         Instruction i ends in window floor((end_i - 1)/W) of the stream, which arrives at (window index - first window index + 1)... computed from the real addresses of the profile
def t_fetch():
    N = 30
    body = ''.join('\tmovq\t#0x1234%04x, r%d\n' % (i, 1 + i % 8) for i in range(N))
    src = prog(body)
    for W in (2, 4, 8, 16):
        for enc in ENCS:
            res, pr = run(src, enc, 'fetch', [spec(W=W, N=64, fl=1, ldec=0, dl=1)])
            pcs = sorted(pr)
            w0 = pcs[0] // W
            last = 0
            t = 0
            for pc in pcs:
                ln = pr[pc][1]
                wend = (pc + ln - 1) // W
                arr = (wend - w0) + 1                   # window k of the stream is requested at cycle k and arrives at k+1
                t = max(t + 1 if last else 0, arr + 0 + 1)   # decode at arrival, ready dl=1 later; one issue per cycle
                last = 1
            # t is the issue cycle of the exit trap, if the model's last instruction (trap) had no operand wait: the trap reads r0 written by the movq before it: ready 1 later
            check('fetch', 'W=%d %s' % (W, enc[0]), res[0]['cycles'], t + 1)

# ---- 9. the tiny loop with a BTB: `add; sob` of 2 instructions, two issue slots, a BTB that predicts the taken sob at fetch: one iteration per cycle.
#         Without the BTB (tkb=1) each iteration costs 1 + tkb + fl = 3 cycles ... (see 6); with the BTB, the next window request is made the cycle after the branch window's request
def t_btb():
    N = 40
    src = prog('\tmovq\t#%d, r1\n\tmovq\t#0, r2\n1:\tadd\t#1, r2\n\tsob\tr1, 1b\n' % N)
    for enc in ENCS:
        res, _ = run(src, enc, 'btb', [spec(iw=2, btb=64, W=16), spec(iw=2, btb=0, W=16, tkb=0)])
        # iw=2: the two movq issue at t0=2 together; the first (add, sob) pair at 3 (sob reads r1, ready at 3).  The first taken sob misses in the BTB (cold): redirect
        # R = d + tkb = 2 + 1 = 3, bytes at 4, decoded at 4, ready at 5: the second pair issues at 5.  From then on every taken sob hits in the BTB: the next request is the cycle
        # after the branch window's request, so one pair per cycle: the pair k (k >= 2) issues at 5 + (k - 2).  Then movq r0 and the trap, one cycle each.
        lastsob = 5 + (N - 2)
        check('btb', 'btb=64 one iteration per cycle after the first %s' % enc[0], res[0]['cycles'], lastsob + 1 + 2)
        check('btb', 'btb hits %s' % enc[0], res[0]['btbhit'], N - 2)
        # without a BTB but with tkb=0 (the target is requested in the cycle the branch is decoded, d): bytes at d+1, decoded at d+1, ready at d+2; the pair was ready at d+1
        # (decoded d, dl=1): so the next pair issues one cycle after: period 1 from the first pair at 3
        check('btb', 'tkb=0 no btb %s' % enc[0], res[1]['cycles'], 3 + (N - 1) + 1 + 2)

# ---- 10. a fused instruction is one issue slot and the dependent latencies add: mov2 r0,r1,r1,r2 (the second move reads what the first wrote) makes r2 ready 2 cycles after issue,
#          mov2 r0,r1,r3,r2 (independent halves) 1 cycle.  movq r0 at 2, mov2 at 3, `add r2,r4` waits for r2: issue 3+2 = 5 (dependent) or 3+1 = 4; movq r0 and trap follow.
def t_fused():
    for dep, ready in ((True, 2), (False, 1)):
        src = prog('\tmovq\t#1, r0\n\tmov2\tr0, r1, %s, r2\n\tadd\tr2, r4\n' % ('r1' if dep else 'r3'))
        for enc in ENCS:
            res, _ = run(src, enc, 'fused', [spec()])
            check('fused', 'mov2 %s %s' % ('dependent' if dep else 'independent', enc[0]), res[0]['cycles'], 3 + ready + 3)
            check('fused', 'one slot %s' % enc[0], res[0]['insns'], 5)

for t in (t_fused, t_chain, t_indep, t_loadchain, t_mulchain, t_div, t_loop, t_mispredict, t_fetch, t_btb):
    t()
print('timing: %d checks, %d failed' % (ran, fails))
sys.exit(1 if fails else 0)
