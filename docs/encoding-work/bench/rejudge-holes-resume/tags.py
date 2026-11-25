#!/usr/bin/env python3
"""tags.py NAME [SCR]: what hardware that tracks "this register holds the user's value" (instead of an RTI mask) would do at every return to a lesser mode of a traced run.
Needs the traces of ../rti-mask-reuse/tools/run_trace.sh made with  -d exec,cpu  (so that r14, the stack pointer, is known before each instruction): NAME.cpu.trace.
The tracking, in words.  One bit U per register, per core.  Set for every register when the first kernel instruction after a user instruction starts (all registers still hold user values).
Cleared by any write of the register.  Designs:
  T0  pure "written since entry": POPM is a write like any other.
  T1  POPM sets U from the bit the matching PUSHM stored beside the value (the bit travels in the saved frame, found by stack address); a register popped with no matching push is cleared.
At a return to a lesser mode the hardware clears every register whose U is 0.  Compared with the two sets of ../rti-mask-reuse (live = the registers the code resumed reads before it
writes them; dirty = the registers that hold the kernel's own values or another process's values at the return):
  leak = registers in dirty that the design leaves (U = 1);   loss = registers in live that the design clears (U = 0).
(The RTI #mask design with the mask the complement of dirty has 0 and 0 by construction; it is the standard of comparison.)"""
import sys, os, re
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(here, '..', 'rti-mask-reuse', 'tools'))
import prog, analyse
ALL = frozenset(range(32)) - {14}
def load(n, scr):
    addr = {}
    for l in open('%s/%s.map' % (scr, n)):
        m = re.match(r'0x([0-9a-f]+) __I_(\d+)$', l.strip())
        if m: addr[int(m.group(1), 16)] = int(m.group(2))
    import bisect; keys = sorted(addr)
    seq = []; raw = []; sp = []
    lines = open('%s/%s.cpu.trace' % (scr, n)).read().split('\n')
    i = 0
    while i < len(lines):
        m = re.match(r'Trace 0: 0x[0-9a-f]+ \[[0-9a-f]+/([0-9a-f]+)/', lines[i])
        if m and i + 4 < len(lines):
            pc = int(m.group(1), 16); raw.append(pc)
            r14 = int(re.search(r'r14 ([0-9a-f]+)', lines[i + 4]).group(1), 16); sp.append(r14)
            for p in (pc, pc & 0x7fffffff, pc & 0xffffffff):
                if p in addr: seq.append(addr[p]); break
            else:
                q = pc & 0x7fffffff; j = bisect.bisect_left(keys, q)
                seq.append(addr[keys[j]] if j < len(keys) and keys[j] - q < 8 else -1)
            i += 5
        else: i += 1
    return seq, raw, sp
def run(name, scr):
    P = prog.Prog(name, scr)
    rows = [r for r in analyse.analyse(name, scr)]
    seq, raw, sp = load(name, scr)
    U0 = set(ALL); U1 = set(ALL); frames = {}
    out = []; ev = 0
    for i, k in enumerate(seq):
        if k not in P.ins: continue
        mn, ops = P.ins[k][0], P.ins[k][1]
        if raw[i] & 0x80000000:
            U0 = set(ALL); U1 = set(ALL); continue
        R, W = P.rw[k]
        if mn in ('pushm', 'push'):
            m = int(ops[0].lstrip('#'), 0) if mn == 'pushm' else 1 << prog.regno(ops[0])
            regs = [j for j in range(32) if m >> j & 1]
            frames[sp[i] - 8 * len(regs)] = {j: (j in U1) for j in regs}      # the bits stored beside the values
        if mn in ('popm', 'pop'):
            m = int(ops[0].lstrip('#'), 0) if mn == 'popm' else 1 << prog.regno(ops[0])
            regs = [j for j in range(32) if m >> j & 1]
            fr = frames.get(sp[i], {})
            for j in regs:
                if fr.get(j): U1.add(j)
                else: U1.discard(j)
                U0.discard(j)
        else:
            U0 -= W; U1 -= W
        if mn in ('rti', 'genter'):
            if ev < len(rows):
                row = rows[ev]; live, dirty, level = row[5], row[6], row[7]
                if level == 'lesser' and mn == 'rti':
                    out.append((ev + 1, mn, row[2], live, dirty, frozenset(U0), frozenset(U1)))
            ev += 1
    return out
def classes(name):
    """site (source line) -> class, from the mask-reuse study's event tables"""
    c = {}
    p = os.path.join(here, '..', 'rti-mask-reuse', 'results', 'events-%s.tsv' % name)
    if os.path.exists(p):
        for l in open(p).read().split('\n')[1:]:
            f = l.split('\t')
            if len(f) > 3: c[int(f[3])] = f[2]
    return c
if __name__ == '__main__':
    name = sys.argv[1]; scr = sys.argv[2]
    rows = run(name, scr); cl = classes(name)
    # loss1: a register the code that resumes reads next (the oracle of the earlier study) is cleared.
    # loss2: for a return from an interrupt or a fault the user may resume anywhere, so every register that does NOT hold the kernel's value (all but dirty) must survive.
    t = {d: dict(n=0, leak=0, loss1=0, loss2=0, bad=0, nint=0) for d in ('T0', 'T1')}
    for n, mn, ln, live, dirty, u0, u1 in rows:
        c = cl.get(ln, '?')
        d0 = dirty - {0} if c == 'syscall' else dirty
        for d, u in (('T0', u0), ('T1', u1)):
            leak = d0 & u; loss1 = live - u
            loss2 = (ALL - dirty - u) if c not in ('syscall', 'start') else frozenset()
            x = t[d]; x['n'] += 1; x['leak'] += bool(leak); x['loss1'] += bool(loss1); x['loss2'] += bool(loss2)
            x['nint'] += c not in ('syscall', 'start'); x['bad'] += bool(leak or loss1 or loss2)
            if os.environ.get('V'): print(d, n, c, 'leak', prog.fmt(leak), 'loss1', prog.fmt(loss1), 'loss2', prog.fmt(loss2))
    for d in ('T0', 'T1'):
        x = t[d]
        print('%s\t%s\treturns %d (of which interrupt or fault %d)\tleak %d\tloss, resume point %d\tloss, interrupt or fault returns %d\twrong any way %d' % (name, d, x['n'], x['nint'], x['leak'], x['loss1'], x['loss2'], x['bad']))
