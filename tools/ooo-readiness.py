#!/usr/bin/env python3
"""ooo-readiness.py: static counts over the kept pdp64 assembly of the fair corpus, for docs/pdp64-ooo-readiness.md.

usage: ooo-readiness.py [--samples N] [--seed S] [--detector NAME] DIR

DIR holds the *.s files that `tools/pdp64size.sh --arch pdp64 --keep DIR` leaves (the compiler's output, before the assembler
chooses page-2 forms).  Everything is a static count of instruction lines; nothing is weighted by execution.

The flag behaviour of each mnemonic is taken from common/pdp64exec.c (the executable semantics), not from the prose of the ISA.
Every detector can print random samples (--samples N) so that the detector can be read against the text it matched.
"""
import argparse, os, random, re, sys
from collections import Counter, defaultdict

N, Z, V, C = 'N', 'Z', 'V', 'C'
ALL = frozenset('NZVC')

# ---- flag writes, from common/pdp64exec.c --------------------------------------------------------------------------
WRITE_ALL = set('add sub cmp neg adc sbc clr tst com asl asr fcmp fcmp32 fcmp16 mcmp'.split())     # N Z V C, always
WRITE_NZV = set('inc dec mul abs min minu max maxu'.split())            # N Z V, C kept (min/max: V cleared)
WRITE_NZ_V0 = set('bic bis bit xor and mulh movq movl movw movb movzl movzw movzb'.split())        # N Z, V cleared, C kept
WRITE_SHIFT = set('shl shr sar'.split())                                 # N Z V C if the count is not zero, nothing if it is
WRITE_Z = set('mscn mscnn'.split())                                      # Z only
# cbCC computes `cmp` itself and WRITES N Z V C (pdp64exec.c: sub_f) although it needs no flag from the past
CB = re.compile(r'^cb(eq|ne|pl|mi|vc|vs|cc|cs|hs|lo|ge|lt|gt|le|hi|los)$')
BCC = re.compile(r'^b(eq|ne|pl|mi|vc|vs|cc|cs|hs|lo|ge|lt|gt|le|hi|los)$')
NEED = {'eq': 'Z', 'ne': 'Z', 'pl': 'N', 'mi': 'N', 'vc': 'V', 'vs': 'V', 'cc': 'C', 'hs': 'C', 'cs': 'C', 'lo': 'C',
        'ge': 'NV', 'lt': 'NV', 'gt': 'ZNV', 'le': 'ZNV', 'hi': 'CZ', 'los': 'CZ'}
READ_CARRY_OPS = set('adc sbc'.split())
MOVES = set('movq movl movw movb movzl movzw movzb'.split())
SOP_MEM = set('inc dec clr neg com asl asr tst adc sbc'.split())
ALU2 = set('add sub and bis bic xor mul mulh cmp bit shl shr sar'.split())

def writes(m, ops):
    """the set of flags an instruction writes (for a register-count shift: the set it writes when the count is not zero)"""
    if m in WRITE_ALL or CB.match(m): return ALL
    if m in WRITE_NZV: return frozenset('NZV')
    if m in WRITE_NZ_V0: return frozenset('NZV')
    if m in WRITE_SHIFT: return ALL
    if m in WRITE_Z: return frozenset('Z')
    return frozenset()

def wclass(m):
    if m in WRITE_ALL or CB.match(m): return 'all four (N Z V C)'
    if m in WRITE_NZV: return 'N Z V, C kept'
    if m in WRITE_NZ_V0: return 'N Z, V cleared, C kept'
    if m in WRITE_SHIFT: return 'shift: all four or none (by count)'
    if m in WRITE_Z: return 'Z only'
    return 'none'

def reads(m):
    """the flags an instruction reads semantically"""
    mm = BCC.match(m)
    if mm: return frozenset(NEED[mm.group(1)])
    if m in READ_CARRY_OPS: return frozenset('C')
    if m == 'set': return ALL
    return frozenset()

def split_ops(s):
    out, depth, cur = [], 0, ''
    for ch in s:
        if ch == '(': depth += 1
        if ch == ')': depth -= 1
        if ch == ',' and depth == 0: out.append(cur.strip()); cur = ''
        else: cur += ch
    if cur.strip(): out.append(cur.strip())
    return out

REG = re.compile(r'^(r1[0-5]|r[0-9]|sp|fp)$')
def is_reg(o): return bool(REG.match(o))
def is_imm(o): return o.startswith('#')
def is_pool(o): return o.startswith('=')
def is_mem(o): return not (is_reg(o) or is_imm(o) or is_pool(o))
def is_postinc(o): return bool(re.search(r'\)\+', o))
def is_predec(o): return o.startswith('-(') or bool(re.search(r'\)-[0-9]', o))
def is_index(o): return bool(re.search(r'\)\([^)]*\*', o)) or bool(re.search(r'\(r[0-9]+\)\(r[0-9]+', o))

class Ins:
    __slots__ = ('m', 'ops', 'text', 'file', 'line', 'idx')
    def __init__(s, m, ops, text, file, line): s.m, s.ops, s.text, s.file, s.line = m, ops, text, file, line

def load(d):
    """returns a list of basic blocks per file; a block is a list of Ins; a label starts a block"""
    files = sorted(f for f in os.listdir(d) if f.endswith(EXTS))
    allins, blocks = [], []
    for fn in files:
        cur = []
        for ln, raw in enumerate(open(os.path.join(d, fn), errors='replace'), 1):
            line = raw.rstrip('\n')
            if not line.startswith('\t'):
                if line.strip().endswith(':'):                  # a label: a new block (flags may flow in through the fall-through)
                    if cur: blocks.append(cur)
                    cur = []
                continue
            body = line.split(';', 1)[0].strip()
            if not body or body.startswith('.'): continue
            m = re.match(r'^([a-z][a-z0-9_]*)\s*(.*)$', body)
            if not m: continue
            ins = Ins(m.group(1), split_ops(m.group(2)), body, fn, ln)
            cur.append(ins); allins.append(ins)
        if cur: blocks.append(cur)
    return allins, blocks

# ---- detectors: name -> predicate on an instruction ---------------------------------------------------------------------
def d_movrr(i): return i.m == 'movq' and len(i.ops) == 2 and is_reg(i.ops[0]) and is_reg(i.ops[1]) and i.ops[0] != i.ops[1]
def d_movrr_same(i): return i.m == 'movq' and len(i.ops) == 2 and is_reg(i.ops[0]) and i.ops[0] == i.ops[1]
def d_ext_rr(i): return i.m in ('movl', 'movw', 'movb', 'movzl', 'movzw', 'movzb') and len(i.ops) == 2 and is_reg(i.ops[0]) and is_reg(i.ops[1])
def d_store(i): return i.m in ('movq', 'movl', 'movw', 'movb') and len(i.ops) == 2 and is_mem(i.ops[1])
def d_load(i): return i.m in MOVES and len(i.ops) == 2 and is_mem(i.ops[0]) and is_reg(i.ops[1])
def d_regshift(i): return i.m in WRITE_SHIFT and len(i.ops) == 2 and is_reg(i.ops[0])
def d_immshift(i): return i.m in WRITE_SHIFT and len(i.ops) == 2 and is_imm(i.ops[0])
def d_asl_asr(i): return i.m in ('asl', 'asr')
def d_loadop(i):
    if i.m in ALU2 and len(i.ops) == 2:
        if i.m == 'cmp' or i.m == 'bit': return is_mem(i.ops[1])
        return is_mem(i.ops[0]) and is_reg(i.ops[1])
    return False
def d_rmw(i):
    if i.m in ('add', 'sub', 'and', 'bis', 'bic', 'xor') and len(i.ops) == 2: return is_mem(i.ops[1])
    if i.m in ('inc', 'dec', 'neg', 'com', 'asl', 'asr', 'adc', 'sbc') and len(i.ops) == 1: return is_mem(i.ops[0])
    return False
def d_clrmem(i): return i.m == 'clr' and len(i.ops) == 1 and is_mem(i.ops[0])
def d_tstmem(i): return i.m == 'tst' and len(i.ops) == 1 and is_mem(i.ops[0])
def d_postinc(i): return any(is_postinc(o) for o in i.ops)
def d_predec(i): return any(is_predec(o) for o in i.ops)
def d_pushmem(i): return i.m == 'push' and len(i.ops) == 1 and is_mem(i.ops[0])
def d_popmem(i): return i.m == 'pop' and len(i.ops) == 1 and is_mem(i.ops[0])
def d_push(i): return i.m == 'push'
def d_pop(i): return i.m == 'pop'
def d_call(i): return i.m == 'call'
def d_calli(i): return i.m == 'calli'
def d_ret(i): return i.m == 'ret'
def d_pushm(i): return i.m == 'pushm'
def d_popm(i): return i.m == 'popm'
def d_spadj(i): return i.m in ('add', 'sub') and len(i.ops) == 2 and i.ops[1] == 'sp'
def d_block(i): return i.m in ('mcpy', 'mmov', 'mset', 'mcmp', 'mscn', 'mscnn')
def d_cb(i): return bool(CB.match(i.m))
def d_cb_imm(i): return bool(CB.match(i.m)) and len(i.ops) == 3 and is_imm(i.ops[1])
def d_cb_rr(i): return bool(CB.match(i.m)) and len(i.ops) == 3 and is_reg(i.ops[1])
def d_bcc(i): return bool(BCC.match(i.m))
def d_br(i): return i.m == 'br'
def d_index_store(i): return d_store(i) and is_index(i.ops[1])
def d_index_any(i): return any(is_index(o) for o in i.ops)
def d_indirect(i): return i.m in ('calli', 'jmpi', 'jtag') or (i.m in ('jmp', 'call') and len(i.ops) == 1 and (is_reg(i.ops[0]) or '(' in i.ops[0]))
def d_zero_idiom(i): return (i.m in ('xor', 'sub') and len(i.ops) == 2 and is_reg(i.ops[0]) and i.ops[0] == i.ops[1])
def d_clr_reg(i): return i.m == 'clr' and len(i.ops) == 1 and is_reg(i.ops[0])
def d_movimm(i): return i.m == 'movq' and len(i.ops) == 2 and (is_imm(i.ops[0]) or is_pool(i.ops[0])) and is_reg(i.ops[1])
def d_lea(i): return i.m == 'lea'
def d_div(i): return i.m in ('div', 'divu', 'mod', 'modu')
def d_fp(i): return i.m.startswith('f')
def d_rotate(i): return i.m in ('rori32', 'rori', 'rol', 'ror')
def d_writes_any(i): return bool(writes(i.m, i.ops))
def d_writes_partial(i): return bool(writes(i.m, i.ops)) and writes(i.m, i.ops) != ALL or i.m in WRITE_SHIFT
def d_writes_c(i): return 'C' in writes(i.m, i.ops)
def d_keeps_c(i): return bool(writes(i.m, i.ops)) and 'C' not in writes(i.m, i.ops)

def d_symload(i): return i.m in MOVES and len(i.ops) == 2 and is_mem(i.ops[0]) and '(' not in i.ops[0] and is_reg(i.ops[1])
def d_pool_or_pcrel_load(i): return d_symload(i) and i.ops[0].startswith('.L')
def d_sp_modifier(i): return i.m in ('push', 'pop', 'call', 'calli', 'ret', 'pushm', 'popm') or d_spadj(i)
def d_multi_uop(i): return i.m in ('push', 'pop', 'call', 'calli', 'ret', 'pushm', 'popm', 'mcpy', 'mmov', 'mset', 'mcmp', 'mscn', 'mscnn') or d_loadop(i) or d_rmw(i)
def d_flag_and_reg(i):
    if not writes(i.m, i.ops): return False
    if CB.match(i.m) or i.m in ('cmp', 'bit', 'tst', 'fcmp', 'fcmp32', 'fcmp16', 'mcmp', 'mscn', 'mscnn'): return False
    if d_store(i) or d_clrmem(i): return False
    return True
def d_flag_only(i): return bool(writes(i.m, i.ops)) and not d_flag_and_reg(i)

DETECTORS = [(k[2:], v) for k, v in sorted(globals().items()) if k.startswith('d_') and callable(v)]
DET = dict(DETECTORS)

def pct(a, b): return '%.1f%%' % (100.0 * a / b) if b else '-'

EXTS = ('.s',)
def main():
    global EXTS
    ap = argparse.ArgumentParser()
    ap.add_argument('--ext', default='s')
    ap.add_argument('dir'); ap.add_argument('--samples', type=int, default=0); ap.add_argument('--seed', type=int, default=1)
    ap.add_argument('--detector', action='append')
    a = ap.parse_args()
    EXTS = tuple('.' + e for e in a.ext.split(','))
    ins, blocks = load(a.dir)
    T = len(ins)
    rnd = random.Random(a.seed)
    out = []
    P = out.append
    P('files: %d, instruction lines: %d' % (len({i.file for i in ins}), T))
    P('')
    # ---- mnemonic census by flag class ---------------------------------------------------------------------------------
    cls = Counter(); bym = defaultdict(Counter)
    for i in ins:
        c = wclass(i.m) if not CB.match(i.m) else 'all four (N Z V C)'
        cls[c] += 1; bym[c][i.m] += 1
    P('## flag-write classes (instructions)')
    for c, n in cls.most_common():
        P('%-40s %8d %7s   top: %s' % (c, n, pct(n, T), ', '.join('%s %d' % kv for kv in bym[c].most_common(6))))
    anyw = sum(n for c, n in cls.items() if c != 'none')
    P('writes at least one flag: %d (%s)' % (anyw, pct(anyw, T)))
    P('')
    # ---- the detectors -------------------------------------------------------------------------------------------------
    P('## detectors')
    names = a.detector or [n for n, _ in DETECTORS]
    for n in names:
        f = DET[n]
        hits = [i for i in ins if f(i)]
        P('%-18s %8d %7s' % (n, len(hits), pct(len(hits), T)))
        if a.samples:
            for h in rnd.sample(hits, min(a.samples, len(hits))): P('      %s:%d\t%s' % (h.file[:40], h.line, h.text))
    P('')
    # pushm/popm masks
    pm = [bin(int(i.ops[0].lstrip('#'), 0)).count('1') for i in ins if i.m in ('pushm', 'popm') and re.match(r'^#-?\d+$', i.ops[0])]
    if pm: P('pushm/popm: %d instructions, registers per instruction: mean %.2f, min %d, max %d' % (len(pm), sum(pm) / len(pm), min(pm), max(pm)))
    P('')
    # ---- flag consumers, backwards to the nearest writer in the same block -------------------------------------------------
    P('## flag readers and the instruction that wrote what they read (same basic block, scanned backwards)')
    readers = Counter(); cnt_split = 0; samples = defaultdict(list)
    def wk(m):
        if m in MOVES: return 'mov/load/store'
        if m in ('cmp',): return 'cmp'
        if m == 'tst': return 'tst'
        if m in ('bit',): return 'bit'
        if m in ('and', 'bis', 'bic', 'xor'): return 'logic'
        if m in ('add', 'sub', 'neg', 'adc', 'sbc', 'inc', 'dec', 'mul', 'mulh'): return 'arith (add sub neg inc dec mul)'
        if m in WRITE_SHIFT or m in ('asl', 'asr'): return 'shift'
        if CB.match(m): return 'cbCC (fused compare-and-branch)'
        if m in ('clr', 'com'): return 'clr/com'
        if m in ('fcmp', 'fcmp32'): return 'fcmp'
        if m in ('abs', 'min', 'max', 'minu', 'maxu'): return 'abs/min/max'
        if m in ('mcmp', 'mscn', 'mscnn'): return 'block compare/scan'
        return m
    nreaders = 0
    for b in blocks:
        for k, i in enumerate(b):
            need = reads(i.m)
            if not need: continue
            nreaders += 1
            found = {}
            for j in range(k - 1, -1, -1):
                w = writes(b[j].m, b[j].ops)
                if b[j].m in ('call', 'calli'):                      # the callee clobbers flags by the ABI; hardware does not clear them
                    for f in need - set(found): found[f] = ('call', b[j])
                    break
                for f in need & w:
                    if f not in found: found[f] = (wk(b[j].m), b[j])
                if set(found) >= set(need): break
            for f in need:
                if f not in found: found[f] = ('(from a predecessor block)', None)
            wset = {id(v[1]) if v[1] else 0 for v in found.values()}
            key = sorted(found.values(), key=lambda v: v[0])[0][0]
            if len(wset) > 1: cnt_split += 1; key = 'split: ' + '+'.join(sorted({v[0] for v in found.values()}))
            readers[key] += 1
            if len(samples[key]) < 400: samples[key].append((b, k))
    for c, n in readers.most_common(): P('%-70s %8d %7s' % (c, n, pct(n, nreaders)))
    gaps = Counter()
    for b in blocks:
        for k, i in enumerate(b):
            need = reads(i.m)
            if not need: continue
            for j in range(k - 1, -1, -1):
                if writes(b[j].m, b[j].ops) & need or b[j].m in ('call', 'calli'): gaps[min(k - j - 1, 5)] += 1; break
    P('instructions between the flag writer and its reader (5 = five or more): ' + ', '.join('%d: %d' % (g, gaps[g]) for g in sorted(gaps)))
    P('flag readers (conditional bCC, adc, sbc, set): %d' % nreaders)
    if a.samples:
        for key, lst in samples.items():
            P('  samples for [%s]' % key)
            for b, k in rnd.sample(lst, min(a.samples, len(lst))):
                lo = max(0, k - 3)
                P('      ' + ' | '.join(x.text for x in b[lo:k + 1]))
    P('')
    # ---- liveness of flag writes: consumed / killed / escapes the block --------------------------------------------------------
    P('## flag writes: consumed, overwritten unread, or escaping the block (forward scan, same block)')
    life = Counter(); lifebym = defaultdict(Counter); lsamples = defaultdict(list)
    for b in blocks:
        for k, i in enumerate(b):
            w = writes(i.m, i.ops)
            if not w: continue
            live = set(w); consumed = False
            outcome = None
            for j in range(k + 1, len(b)):
                r = reads(b[j].m) & live
                if r: consumed = True; break
                if b[j].m in ('call', 'calli', 'ret'): outcome = 'dead (killed by call/ret)'; break
                live -= writes(b[j].m, b[j].ops) if not (b[j].m in WRITE_SHIFT and b[j].ops and is_reg(b[j].ops[0])) else set()
                if not live: outcome = 'dead (overwritten unread)'; break
                if b[j].m in ('br', 'jmp', 'jmpi', 'jtag'): outcome = 'escapes (block ends in br/jmp)'; break
            if consumed: outcome = 'consumed in block'
            elif outcome is None: outcome = 'escapes (falls to a label / end)'
            life[outcome] += 1; lifebym[i.m][outcome] += 1
            if len(lsamples[outcome]) < 400: lsamples[outcome].append((b, k))
    tw = sum(life.values())
    for c, n in life.most_common(): P('%-40s %8d %7s of %d flag-writing instructions' % (c, n, pct(n, tw), tw))
    P('by mnemonic, share of that mnemonic\'s flag writes that are consumed in the block (top 14 by volume):')
    for m, cn in sorted(lifebym.items(), key=lambda kv: -sum(kv[1].values()))[:14]:
        s = sum(cn.values()); P('   %-8s %7d  consumed %6s   dead %6s   escapes %6s' % (m, s, pct(cn['consumed in block'], s),
            pct(cn['dead (killed by call/ret)'] + cn['dead (overwritten unread)'], s), pct(cn['escapes (block ends in br/jmp)'] + cn['escapes (falls to a label / end)'], s)))
    if a.samples:
        for key, lst in lsamples.items():
            P('  samples for [%s]' % key)
            for b, k in rnd.sample(lst, min(a.samples, len(lst))):
                P('      ' + ' | '.join(x.text for x in b[k:k + 4]))
    # move-elimination candidates whose flag write is dead
    movrr = [(b, k) for b in blocks for k, i in enumerate(b) if d_movrr(i)]
    dead = 0; cons = 0
    for b, k in movrr:
        live = set('NZV'); res = None
        for j in range(k + 1, len(b)):
            if reads(b[j].m) & live: res = 'c'; break
            if b[j].m in ('call', 'calli', 'ret'): res = 'd'; break
            live -= writes(b[j].m, b[j].ops) if not (b[j].m in WRITE_SHIFT and is_reg(b[j].ops[0])) else set()
            if not live: res = 'd'; break
        if res == 'd': dead += 1
        elif res == 'c': cons += 1
    P('')
    P('movq reg,reg (different registers): %d; flags provably dead in block: %d (%s); flags consumed in block: %d (%s); escape the block: %d (%s)' % (
        len(movrr), dead, pct(dead, len(movrr)), cons, pct(cons, len(movrr)), len(movrr) - dead - cons, pct(len(movrr) - dead - cons, len(movrr))))
    # shifts: flags consumed?
    P('')
    P('## register-count shifts: is the flag result read?')
    rs = [(b, k) for b in blocks for k, i in enumerate(b) if d_regshift(i)]
    c_cons = 0
    for b, k in rs:
        live = set(ALL)
        for j in range(k + 1, len(b)):
            if reads(b[j].m) & live: c_cons += 1; break
            if b[j].m in ('call', 'calli', 'ret'): break
            live -= writes(b[j].m, b[j].ops) if not (b[j].m in WRITE_SHIFT and is_reg(b[j].ops[0])) else set()
            if not live: break
    P('register-count shifts: %d; with a flag read in the same block before the flags are overwritten: %d' % (len(rs), c_cons))
    # ---- where do functions' flags flow across labels? -----------------------------------------------------------------------
    P('')
    P('total instructions %d' % T)
    print('\n'.join(out))

if __name__ == '__main__':
    main()
