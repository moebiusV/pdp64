#!/usr/bin/env python3
"""Static count, per function of compiled code, of the registers that can hold a value of the function's own at the return: written somewhere in the function (or in a function of
the same file that it calls), and neither the result register r0, nor the stack pointer r14, nor callee-saved by the compiler's convention.

usage: regs_static.py [--json] FILE.s ...        (as64 syntax, as written by pcc and by the LLVM back end)

Callee-saved: r8-r11, r13 (frame pointer), r15, r24-r31 (the LLVM back end's list, PDP64CallingConv.td; pcc keeps r8-r11 and r15 and does not use r16-r31).
Path-insensitive: a register written on any path counts (an upper bound of what one return leaves).  A call to a function not in the file counts as writing r0-r7 and r12 (the
ABI's caller-saved set); r16-r23 are caller-saved for the LLVM back end, unassigned in the ABI draft.
"""
import re, sys, json
CS = {8, 9, 10, 11, 13, 15} | set(range(24, 32))
NOWRITE_PREFIX = ('cb',)
NOWRITE = {'cmp', 'cmpb', 'cmpw', 'cmpl', 'tst', 'tstb', 'bit', 'br', 'jmp', 'jmpi', 'ret', 'push', 'pushm', 'pushx', 'trap', 'nop', 'halt', 'rti', 'spl', 'stua', 'clua',
           'mtsr', 'mtps', 'tlbi', 'tlbia', 'isync', 'genter', 'beq', 'bne', 'bhi', 'bhis', 'blo', 'blos', 'bcs', 'bcc', 'blt', 'ble', 'bgt', 'bge', 'bmi', 'bpl', 'bvs', 'bvc', 'bz', 'bnz'}
REG = re.compile(r'^(?:r(\d+)|sp|fp)$')
def regno(tok):
    tok = tok.strip().strip('"')
    if tok == 'sp': return 14
    if tok == 'fp': return 13
    m = re.fullmatch(r'r(\d+)', tok)
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
def mask_regs(tok):
    m = int(tok.lstrip('#'), 0)
    return {i for i in range(32) if m >> i & 1}

def parse(fn):
    funcs = {}; order = []; cur = None; intext = True
    for line in open(fn):
        line = line.split(';')[0].rstrip()
        if not line.strip(): continue
        s = line.strip()
        if s.startswith('.'):
            d = s.split()[0]
            if d in ('.data', '.bss', '.rodata'): intext = False
            elif d == '.text': intext = True
            elif d == '.section': intext = False
            if not re.match(r'\.L\w*:', s): continue
        m = re.match(r'^([A-Za-z_][\w$.]*):\s*(.*)$', line)
        if m and not m.group(1).startswith('.L'):
            if intext:
                cur = m.group(1); funcs[cur] = []; order.append(cur)
            rest = m.group(2)
            if not rest: continue
            s = rest.strip()
        elif re.match(r'^\.L\w*:', s):
            s = re.sub(r'^\.L\w*:\s*', '', s)
            if not s: continue
        if not intext or cur is None or s.startswith('.'): continue
        parts = s.split(None, 1); mn = parts[0]; ops = split_ops(parts[1]) if len(parts) > 1 else []
        funcs[cur].append((mn, ops))
    return funcs, order

def writes(mn, ops):
    """(registers written, called function names, restored registers, unknown flag)"""
    w, calls, restored = set(), [], set()
    # autoincrement / autodecrement operands
    for o in ops:
        m = re.search(r'\((r\d+|sp|fp)\)\+', o) or re.search(r'-\((r\d+|sp|fp)\)', o)
        if m: w.add(regno(m.group(1)))
    if mn.startswith('cb') or mn in NOWRITE: return w, calls, restored
    if mn in ('call', 'calli'):
        calls.append(ops[0].strip('"') if ops else '?'); return w, calls, restored
    if mn == 'movcall':
        d = regno(ops[1]); w.add(d); calls.append(ops[2]); return w, calls, restored
    if mn == 'mov2':
        for k in (1, 3):
            r = regno(ops[k])
            if r is not None: w.add(r)
        return w, calls, restored
    if mn in ('mfsr', 'mfps', 'mfcpuid', 'mtasid'):
        r = regno(ops[0]); 
        if r is not None and mn != 'mtasid': w.add(r)
        return w, calls, restored
    if mn == 'sob':
        r = regno(ops[0]); w.add(r); return w, calls, restored
    if mn in ('mcpy', 'mmov', 'mset'):
        w |= {0, 1, 2}; return w, calls, restored
    if mn == 'pop': restored |= {regno(ops[0])}; return w, calls, restored
    if mn in ('popm', 'popmret'): restored |= mask_regs(ops[0]); return w, calls, restored
    if mn == 'popret': restored |= {regno(ops[0])}; return w, calls, restored
    if mn.endswith('m') and mn in ('addm', 'subm', 'bism', 'bicm', 'andm', 'xorm', 'incm', 'decm'): return w, calls, restored
    if ops:
        r = regno(ops[-1])
        if r is not None: w.add(r)
    return w, calls, restored

def analyse(fn):
    funcs, order = parse(fn)
    info = {}
    for f in order:
        W, C, R = set(), set(), set()
        for mn, ops in funcs[f]:
            w, c, r = writes(mn, ops); W |= w; C |= set(c); R |= r
            if mn == 'jmp' and ops and not ops[0].startswith('.L') and ops[0] in funcs and ops[0] != f: C.add(ops[0])   # tail call
        info[f] = [W, C, R]
    # close over calls inside the file
    changed = True; ext = {f: False for f in order}
    while changed:
        changed = False
        for f in order:
            W, C, R = info[f]
            for c in C:
                if c in info:
                    n = W | info[c][0]
                    if n != W: W |= info[c][0]; changed = True
                    if ext[c] and not ext[f]: ext[f] = True; changed = True
                elif not ext[f]: ext[f] = True; changed = True
    res = {}
    for f in order:
        W, C, R = info[f]
        if ext[f]: W = W | {0, 1, 2, 3, 4, 5, 6, 7, 12}
        D = sorted(r for r in W if r not in CS and r not in (14, 0))
        res[f] = {'instr': len(funcs[f]), 'written': sorted(W), 'dirty': D, 'n_dirty': len(D), 'external_call': ext[f], 'callee_saved_written': sorted(r for r in W if r in CS)}
    return res

if __name__ == '__main__':
    js = '--json' in sys.argv
    out = {}
    for fn in [a for a in sys.argv[1:] if not a.startswith('--')]:
        out[fn] = analyse(fn)
        if not js:
            for f, r in out[fn].items():
                print('%s %s: %d instr, dirty r%s (%d)%s' % (fn, f, r['instr'], ',r'.join(map(str, r['dirty'])), r['n_dirty'], ' [calls outside the file]' if r['external_call'] else ''))
    if js: print(json.dumps(out))
