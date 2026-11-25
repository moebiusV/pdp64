#!/usr/bin/env python3
"""A program read as instructions with the registers each one reads and writes, a control-flow graph, and the registers that are live (read before they are written) at every point.
Input: the files made by tools/sites.py (NAME.s.ins, NAME.s.lab).  Used by tools/analyse.py.

What 'live at a point' means here: a register whose present value can still be read by the code that runs after this point, on some path, before that code writes it.  This is the set
that has to survive a return that resumes at this point; every other register could be cleared without the code noticing.
Choices that make the sets larger, never smaller, than the truth: a call returns to every return point in the program (context-insensitive); an indirect jump ends the path; a trap
reads the registers its handler is documented to read (TRAP_USES); HALT reads r0 (the status).  r14 (the stack pointer) is never counted: it is banked and a return does not clear it."""
import re, sys
ALL = frozenset(range(32)) - {14}
def regno(t):
    t = t.strip()
    if t == 'sp': return 14
    if t == 'fp': return 13
    m = re.fullmatch(r'r(\d+)', t)
    return int(m.group(1)) if m else None
def split_ops(s):
    out, depth, cur = [], 0, ''
    for ch in s:
        if ch == '(': depth += 1
        if ch == ')': depth -= 1
        if ch == ',' and depth == 0: out.append(cur.strip()); cur = ''
        else: cur += ch
    if cur.strip(): out.append(cur.strip())
    return out
def addr_regs(o):
    """registers used to form the address of a memory operand, and the ones an auto-increment writes"""
    r, w = set(), set()
    for m in re.finditer(r'\((r\d+|sp|fp)\)(\+)?', o):
        x = regno(m.group(1)); r.add(x)
        if m.group(2): w.add(x)
    for m in re.finditer(r'-\((r\d+|sp|fp)\)', o):
        x = regno(m.group(1)); r.add(x); w.add(x)
    return r, w
def is_mem(o): return '(' in o and not o.startswith('#') and not o.startswith('=')
MOVES = {'movq', 'movb', 'movw', 'movl', 'movzb', 'movzw', 'movzl', 'movsb', 'movsw', 'movsl', 'lea'}
ALU2 = {'add', 'sub', 'and', 'bis', 'bic', 'xor', 'shr', 'shl', 'sar', 'adc', 'sbc', 'mul', 'rol', 'ror'}
CMP = {'cmp', 'cmpb', 'cmpw', 'cmpl', 'tst', 'bit'}
BRANCH = {'br', 'beq', 'bne', 'bhi', 'bhis', 'blo', 'blos', 'bcs', 'bcc', 'blt', 'ble', 'bgt', 'bge', 'bmi', 'bpl', 'bvs', 'bvc'}
NOP_LIKE = {'nop', 'spl', 'stua', 'clua', 'tlbia', 'tlbsync', 'isync', 'pushx', 'popx', 'fence', 'wfe', 'sev', 'bpt', 'tlbicsync'}
TRAP_USES = {0: {0}, 1: {1, 2}, 224: {0}}          # trap #n reads these registers (the handler's arguments); other traps: r0
TRAP_DEFS = {1: {0}}                                # and writes these (the result of the call); a hypercall of the test hypervisor returns nothing
def rw(mn, ops):
    """(reads, writes) of registers for one instruction.  Unknown mnemonics raise."""
    R, W = set(), set()
    def src(o):
        if o.startswith('#') or o.startswith('='): return
        x = regno(o)
        if x is not None: R.add(x); return
        if is_mem(o):
            a, w = addr_regs(o); R.update(a); W.update(w)
    def dst(o, also_read):
        x = regno(o)
        if x is not None:
            W.add(x)
            if also_read: R.add(x)
        elif is_mem(o):
            a, w = addr_regs(o); R.update(a); W.update(w)
    if mn in MOVES:
        src(ops[0]); dst(ops[1], False)
    elif mn in ALU2:
        src(ops[0]); dst(ops[1], True)
        if is_mem(ops[1]): src(ops[1])          # read-modify-write of memory: address regs (already added)
    elif mn in CMP:
        for o in ops: src(o)
    elif mn.startswith('cb'):
        for o in ops[:-1]: src(o)
    elif mn in BRANCH or mn in NOP_LIKE or mn in ('rti', 'rtt', 'halt', 'genter', 'ret'):
        pass
    elif mn in ('inc', 'dec', 'neg', 'not', 'clr', 'com'):
        dst(ops[0], mn != 'clr')
    elif mn == 'mtsr': src(ops[1])
    elif mn in ('mfsr', 'mfps', 'mfcpuid'): dst(ops[0], False)
    elif mn == 'mtps': src(ops[0])
    elif mn == 'sob': R.add(regno(ops[0])); W.add(regno(ops[0]))
    elif mn == 'jmp':
        x = regno(ops[0])
        if x is not None: R.add(x)
    elif mn in ('call',):
        x = regno(ops[0])
        if x is not None: R.add(x)
    elif mn in ('tlbi', 'tlbiasid'): src(ops[0])
    elif mn in ('prober', 'probew'): dst(ops[0], False); src(ops[1])
    elif mn == 'pushm':
        m = int(ops[0].lstrip('#'), 0); R.update(i for i in range(32) if m >> i & 1)
    elif mn == 'popm':
        m = int(ops[0].lstrip('#'), 0); W.update(i for i in range(32) if m >> i & 1)
    elif mn == 'trap':
        n = int(ops[0].lstrip('#'), 0); R.update(TRAP_USES.get(n, {0})); W.update(TRAP_DEFS.get(n, set()))
    else: raise ValueError('unknown mnemonic ' + mn)
    R.discard(14); W.discard(14)
    return R, W
class Prog:
    def __init__(self, name, scr):
        self.ins = {}; self.order = []
        for l in open('%s/%s.s.ins' % (scr, name)):
            k, ln, body = l.rstrip('\n').split('\t', 2); k = int(k)
            parts = body.split(None, 1); mn = parts[0]; ops = split_ops(parts[1]) if len(parts) > 1 else []
            self.ins[k] = (mn, ops, int(ln), body); self.order.append(k)
        self.labs = {}; self.numlabs = {}
        for l in open('%s/%s.s.lab' % (scr, name)):
            nm, k = l.rstrip('\n').split('\t'); k = int(k)
            if nm.isdigit(): self.numlabs.setdefault(nm, []).append(k)
            else: self.labs[nm] = k
        self.guest_halts = set()
        self.build()
    def target(self, k, o):
        m = re.fullmatch(r'(\d+)([fb])', o)
        if m:
            c = self.numlabs[m.group(1)]
            return min(x for x in c if x > k) if m.group(2) == 'f' else max(x for x in c if x <= k)
        return self.labs.get(o)
    def build(self):
        self.rw = {k: rw(self.ins[k][0], self.ins[k][1]) for k in self.order}
        self.succ = {}; calls = {}; rets = []
        retpts = []
        for i, k in enumerate(self.order):
            mn, ops, _, _ = self.ins[k]; nxt = self.order[i + 1] if i + 1 < len(self.order) else None
            s = []
            if mn in ('br',):
                t = self.target(k, ops[0]); s = [t] if t else []
            elif mn == 'jmp':
                t = self.target(k, ops[0]) if regno(ops[0]) is None else None; s = [t] if t else []
            elif mn in BRANCH or mn.startswith('cb') or mn == 'sob':
                t = self.target(k, ops[-1]); s = ([t] if t else []) + ([nxt] if nxt else [])
            elif mn == 'call':
                t = self.target(k, ops[0]); s = [t] if t else []
                if nxt: retpts.append(nxt)
            elif mn == 'ret': rets.append(k)
            elif mn in ('halt', 'rti', 'rtt', 'genter'): s = []
            else: s = [nxt] if nxt else []
            self.succ[k] = [x for x in s if x]
        for k in rets: self.succ[k] = list(retpts)
        # trap and halt: execution continues at the next instruction only after a return from the handler, which is the point this analysis asks about (a trap is a call whose callee
        # is the kernel); halt ends
        for i, k in enumerate(self.order):
            if self.ins[k][0] == 'trap' and i + 1 < len(self.order): self.succ[k] = [self.order[i + 1]]
        self.liveness()
    def liveness(self):
        self.livein = {k: frozenset() for k in self.order}
        self.liveout = {k: frozenset() for k in self.order}
        ch = True
        while ch:
            ch = False
            for k in reversed(self.order):
                out = frozenset().union(*[self.livein[s] for s in self.succ[k]]) if self.succ[k] else frozenset()
                R, W = self.rw[k]
                mn = self.ins[k][0]
                if mn == 'halt' and k not in self.guest_halts: R = R | {0}      # a halt of a kernel stops the machine with r0; a halt in a guest is an exit and needs nothing
                inn = frozenset(R) | (out - W)
                if out != self.liveout[k] or inn != self.livein[k]:
                    self.liveout[k] = out; self.livein[k] = inn; ch = True
def fmt(s):
    s = sorted(s)
    return '{' + ','.join('r%d' % i for i in s) + '}' if s else '{}'
def mask(s):
    return sum(1 << i for i in s)
