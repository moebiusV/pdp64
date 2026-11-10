#!/usr/bin/env python3
"""mk-exec-tm.py: make the timing-instrumented copy of the shared executor (for sim64 --timing).

The instruction core common/pdp64exec.c (and pdp64exec_enc.inc) is shared with QEMU and stays untouched.  The timing model (common/timing.c)
needs, for every executed instruction, which registers it read and wrote and in which order.  This script copies the two files to
build/pdp64exec_tm.c and build/pdp64exec_enc.inc, replacing every access to the register file (r[..], RG[..]), to the flags (fN fZ fV fC) and to
DP by a call that logs the access and returns the same value (reads) or the same lvalue (writes), and adds three calls at the points where the
instruction is identified (exec_fmt, step_enc).  The semantics are identical: tools/check-sim64.sh runs every test through this copy.

An access is classified from its text: `x = ..`, `x += ..`, `x++` ... write or read-modify-write; `&x` read-modify-write (the pointer may be
written); everything else a read.  Writes to the base register of an addressing mode ((rn)+, -(rn), push/pop of sp) are address updates (WA): the
timing model gives them the latency of an address computation, not of the loaded data.
"""
import re, sys, os

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'common')
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'build')

ADDR_IDX = {'14', 'o->adjust_reg', 'f.rm', 'e->r'}

def match_bracket(s, i):
    """s[i] == '[': return the index of the matching ']'"""
    depth = 0
    for j in range(i, len(s)):
        if s[j] == '[': depth += 1
        elif s[j] == ']':
            depth -= 1
            if depth == 0: return j
    raise ValueError('unbalanced')

WRITE = re.compile(r'\s*=(?!=)')
RMW = re.compile(r'\s*(\+=|-=|\|=|&=|\^=|<<=|>>=|\*=|\+\+|--)')
PRE = re.compile(r'(\+\+|--)\s*$')
ADDROF = re.compile(r'(^|[^\w\)\]\s])\s*&\s*$|^\s*&\s*$')

def classify(before, after):
    if PRE.search(before): return 'M'
    if RMW.match(after): return 'M'
    if WRITE.match(after): return 'W'
    if ADDROF.search(before) and not before.rstrip().endswith('&&'): return 'M'
    return 'R'

def find_stmt_end(s, start):
    depth = 0
    j = start
    while j < len(s):
        ch = s[j]
        if ch in '([{': depth += 1
        elif ch in ')]}':
            depth -= 1
            if depth < 0: return None
        elif ch == ';' and depth == 0: return j
        elif ch == ',' and depth == 0: return None
        elif ch == '"' or ch == "'":
            q = ch; j += 1
            while j < len(s) and s[j] != q:
                if s[j] == '\\': j += 1
                j += 1
        j += 1
    return None

def transform_line(line, regname):
    if line.lstrip().startswith('#'):
        return line
    out = []
    i = 0
    pat = re.compile(r'(?<![\w.>])(%s)\[' % regname + r'|(?<![\w.>])(fN|fZ|fV|fC|dp)\b(?!\s*\()')
    while True:
        m = pat.search(line, i)
        if not m:
            out.append(line[i:]); break
        out.append(line[i:m.start()])
        before = ''.join(out)[-40:]
        if m.group(1):
            b = m.end() - 1
            e = match_bracket(line, b)
            idx = line[b + 1:e]
            kind = classify(before, line[e + 1:])
            a = idx.strip() in ADDR_IDX
            if kind == 'W':
                # `r[i] = expr;`: log the write after the reads and calls inside expr (the order of evaluation of the two sides of = is not defined in C)
                rest = line[e + 1:]
                eq = WRITE.match(rest)
                end = find_stmt_end(rest, eq.end())
                if end is not None:
                    expr = transform_line(rest[eq.end():end], regname)
                    out.append('%s(%s, %s)' % ('TM_SETA' if a else 'TM_SET', idx, expr))
                    i = e + 1 + end
                    continue
                sys.stderr.write('mk-exec-tm: unordered write: %s\n' % line.strip())
            f = {'R': 'TM_R', 'W': 'TM_WA' if a else 'TM_W', 'M': 'TM_MA' if a else 'TM_M'}[kind]
            if f == 'TM_R':
                out.append('TM_R(%s)' % idx)
            else:
                out.append('(*%s(%s))' % (f, idx))
            i = e + 1
        else:
            name = m.group(2)
            kind = classify(before, line[m.end():])
            code = {'fN': 'FN', 'fZ': 'FZ', 'fV': 'FV', 'fC': 'FC', 'dp': 'DP'}[name]
            if kind == 'R': out.append('TMX_R(%s)' % code)
            else: out.append('(*TMX_%s(%s))' % ('W' if kind == 'W' else 'M', code))
            i = m.end()
    return ''.join(out)

def in_comment_aware(text, regname):
    # transform code outside comments only (a comment may mention r[..]); keep it simple: split on /* */ and // on a per-line basis
    res = []
    incomment = False
    for line in text.split('\n'):
        pos = 0; buf = ''
        while pos < len(line):
            if incomment:
                k = line.find('*/', pos)
                if k < 0: buf += line[pos:]; pos = len(line)
                else: buf += line[pos:k + 2]; pos = k + 2; incomment = False
            else:
                k1 = line.find('/*', pos); k2 = line.find('//', pos)
                cands = [k for k in (k1, k2) if k >= 0]
                if not cands:
                    buf += transform_line(line[pos:], regname); pos = len(line)
                else:
                    k = min(cands)
                    buf += transform_line(line[pos:k], regname)
                    if k == k2 and (k1 < 0 or k2 < k1):
                        buf += line[k:]; pos = len(line)
                    else:
                        k3 = line.find('*/', k + 2)
                        if k3 < 0: buf += line[k:]; pos = len(line); incomment = True
                        else: buf += line[k:k3 + 2]; pos = k3 + 2
        res.append(buf)
    return '\n'.join(res)

PRELUDE = '''/* GENERATED by tools/mk-exec-tm.py from common/pdp64exec.c: do not edit.  The register, flag and DP accesses are logged for the timing model. */
#include "pdp64exec.h"
#include "timing.h"
/* accessors defined before the file's own macros r, fN.. (which would capture the field names) */
static inline uint64_t *tm_regs(struct pdp64_cpu *c) { return c->r; }
static inline int *tm_flag(struct pdp64_cpu *c, int w) { return w == 0 ? &c->fN : w == 1 ? &c->fZ : w == 2 ? &c->fV : &c->fC; }
static inline uint64_t *tm_dp(struct pdp64_cpu *c) { return &c->dp; }
'''

TM_MACROS = '''/* timing instrumentation (tools/mk-exec-tm.py) */
#define TM_R(i) tm_rd(tm_regs(C), (i))
#define TM_SET(i, e) tm_set(tm_regs(C), (i), (e), TM_EV_W)
#define TM_SETA(i, e) tm_set(tm_regs(C), (i), (e), TM_EV_WA)
#define TM_W(i) tm_wr(tm_regs(C), (i), TM_EV_W)
#define TM_WA(i) tm_wr(tm_regs(C), (i), TM_EV_WA)
#define TM_M(i) tm_wr(tm_regs(C), (i), TM_EV_M)
#define TM_MA(i) tm_wr(tm_regs(C), (i), TM_EV_MA)
#define TMF_FN (*tm_flag(C, 0))
#define TMF_FZ (*tm_flag(C, 1))
#define TMF_FV (*tm_flag(C, 2))
#define TMF_FC (*tm_flag(C, 3))
#define TMF_DP (*tm_dp(C))
#define TMX_R(x) (tm_ev(TM_EV_R, TM_REG_##x), TMF_##x)
#define TMX_W(x) (tm_ev(TM_EV_W, TM_REG_##x), &TMF_##x)
#define TMX_M(x) (tm_ev(TM_EV_M, TM_REG_##x), &TMF_##x)
'''

def main():
    os.makedirs(OUT, exist_ok=True)
    c = open(os.path.join(SRC, 'pdp64exec.c')).read()
    inc = open(os.path.join(SRC, 'pdp64exec_enc.inc')).read()
    c = in_comment_aware(c, 'r')
    marker = '#define MODE ((int)pdp64_mode(C))\n'
    assert marker in c
    c = c.replace(marker, marker + TM_MACROS, 1)
    old = '\tint opc = f.opc;\n\tstruct opnd o;\n'
    assert old in c
    c = c.replace(old, old + '\ttm_fmt(&f);\n', 1)
    inc = in_comment_aware(inc, 'RG')
    old = '\tif (E->profile) E->profile(E->u, start, n, classify_enc(h, &in));\n'
    assert old in inc
    inc = inc.replace(old, old + '\ttm_enc(in.mn, t->mn[in.mn].name, &in);\n', 1)
    open(os.path.join(OUT, 'pdp64exec_tm.c'), 'w').write(PRELUDE + c)
    open(os.path.join(OUT, 'pdp64exec_enc.inc'), 'w').write(inc)

if __name__ == '__main__':
    main()
