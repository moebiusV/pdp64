#!/usr/bin/env python3
"""vecwin.py -- where a `vec` prefix (a region operation, errata 139, J.8.5) would win in pdp64 assembly.

usage: vecwin.py [-v] FILE.s ... > report          (the output of pcc's ccom, as the arch-compare scripts make it)

The author asked for "a script to examine the asm for cases where the vec instruction would actually be a win" (2026-11-16).  It reads the
assembly of each function, finds the innermost loops (a label that a later branch of the same function jumps back to, with no other loop inside), and
classifies each loop by what its body does, counting the instructions of the body:

    map      loads, element operations and stores, no call and no branch inside: the loop `vec` would replace (a prefix over the operation)
    reduce   loads and element operations that end in a register, no store
    fill     stores of a register or a constant, no load (memset-like)
    call     a call inside the body (a helper such as a clip that the compiler did not inline): not a `vec` loop until the call goes
    branch   a branch inside the body: control flow `vec` has no predication for (J.8.5: predication is still to be decided); a select would do it
    other    none of the above

and, for `map` and `reduce` loops, the shape a design has to cover: element operations per iteration (the chain), load streams, store streams.
Loop control (the induction variable's increment, the compare and the backward branch) is not counted as an element operation.  Output: one line per
loop with -v, and a summary: loops and their static instructions by class, as a share of all the instructions of the files."""
import re, sys, collections

BR = re.compile(r'^(b[a-z]*|br|sob|jmp|cb[a-z]+|tbn?z?)$')
CALLS = ('call', 'movcall', 'jsr', 'callr')
RETS = ('ret', 'popret', 'popmret', 'rti', 'rts')
NODEST = ('cmp', 'tst', 'bit', 'cmpb', 'cmpw', 'cmpl', 'push', 'pushm', 'jmp', 'br')
LABEL = re.compile(r'^(\.?[A-Za-z_][\w.$]*):\s*(?:;.*)?$')
REG = re.compile(r'^(r\d+|sp|fp|pc|dp)$')


def split_ops(s):
    out, d, cur = [], 0, ''
    for ch in s:
        if ch in '([': d += 1
        if ch in ')]': d -= 1
        if ch == ',' and d == 0:
            out.append(cur.strip()); cur = ''
        else:
            cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out


def is_mem(op):
    if op.startswith(('#', '$', '=')):
        return False
    if REG.match(op):
        return False
    return True


def parse(path):
    funcs = []
    cur = None
    for ln in open(path, errors='replace'):
        ln = ln.rstrip('\n')
        s = ln.split(';')[0].rstrip()
        if not s.strip():
            continue
        m = LABEL.match(s.strip())
        if m and not ln[0] in ' \t':
            name = m.group(1)
            if not name.startswith('.L'):
                cur = dict(name=name, items=[]); funcs.append(cur)
            elif cur is not None:
                cur['items'].append(('label', name))
            continue
        if ln[0] in ' \t':
            t = s.strip()
            if t.startswith('.'):
                continue
            parts = t.split(None, 1)
            mn = parts[0]
            ops = split_ops(parts[1]) if len(parts) > 1 else []
            if cur is None:
                cur = dict(name='?', items=[]); funcs.append(cur)
            cur['items'].append(('ins', mn, ops))
        elif m is None and cur is not None:
            pass
    return funcs


def loops_of(f):
    items = f['items']
    labels = {}
    for i, it in enumerate(items):
        if it[0] == 'label':
            labels.setdefault(it[1], i)
    found = []
    for i, it in enumerate(items):
        if it[0] == 'ins' and BR.match(it[1]) and it[2]:
            tgt = it[2][-1]
            if tgt in labels and labels[tgt] <= i:
                found.append((labels[tgt], i))
    # a loop that contains another is not innermost
    inner = [l for l in found if not any(o != l and l[0] <= o[0] and o[1] <= l[1] for o in found)]
    return inner


def classify(items, lo, hi):
    loads = stores = alu = calls = brs = nins = 0
    callees = []
    memsrc = collections.Counter()
    # the loop control: the last compare/branch pair and the increments of the register it tests
    body = [it for it in items[lo:hi + 1] if it[0] == 'ins']
    ctrl = set()
    last = body[-1] if body else None
    tested = set()
    if last:
        for o in last[2]:
            if REG.match(o):
                tested.add(o)
        if len(body) > 1 and body[-2][1] in ('cmp', 'cmpb', 'cmpw', 'cmpl', 'tst'):
            ctrl.add(len(body) - 2)
            for o in body[-2][2]:
                if REG.match(o):
                    tested.add(o)
    for k, it in enumerate(body):
        mn, ops = it[1], it[2]
        nins += 1
        if k == len(body) - 1 or k in ctrl:
            continue
        if mn in CALLS or mn in RETS:
            calls += 1
            if ops:
                callees.append(ops[-1])
            continue
        if BR.match(mn):
            brs += 1
            continue
        if mn in ('inc', 'dec', 'add', 'sub', 'lea') and ops and REG.match(ops[-1]) and ops[-1] in tested and (mn in ('inc', 'dec') or ops[0].startswith(('#', '$')) or REG.match(ops[0])):
            continue
        if mn in NODEST:
            alu += 1
            if any(is_mem(o) for o in ops):
                loads += 1
            continue
        dst = ops[-1] if ops else ''
        srcs = ops[:-1] if len(ops) > 1 else []
        if len(ops) >= 1 and is_mem(dst) and dst:
            stores += 1
            memsrc[dst] += 1
        for o in srcs:
            if is_mem(o):
                loads += 1
                memsrc[o] += 1
        if len(ops) == 1 and not is_mem(dst) and mn not in ('clr',):
            alu += 1            # inc, neg: one register
        elif not mn.startswith('mov') and mn != 'lea':
            alu += 1
        # the pure data move and the address computation are not element operations
    if calls:
        kind = 'call'
    elif brs:
        kind = 'branch'
    elif loads and stores:
        kind = 'map'
    elif loads and not stores:
        kind = 'reduce'
    elif stores and not loads:
        kind = 'fill'
    else:
        kind = 'other'
    return dict(kind=kind, ins=nins, loads=loads, stores=stores, ops=alu, calls=calls, branches=brs, callees=callees)


def main():
    verbose = '-v' in sys.argv
    files = [a for a in sys.argv[1:] if not a.startswith('-')]
    tot = 0
    cls = collections.Counter(); clsins = collections.Counter()
    shape = collections.defaultdict(list)
    nloops = 0
    callees = collections.Counter(); onlyclip = 0
    for fn in files:
        for f in parse(fn):
            tot += sum(1 for it in f['items'] if it[0] == 'ins')
            for lo, hi in loops_of(f):
                c = classify(f['items'], lo, hi)
                nloops += 1
                cls[c['kind']] += 1; clsins[c['kind']] += c['ins']
                shape[c['kind']].append(c)
                if c['kind'] == 'call':
                    callees.update(set(c['callees']))
                    if all(x.startswith('iclip') or x in ('imin', 'imax', 'umin', 'umax', 'apply_sign', 'apply_sign64', 'iabs') for x in c['callees']):
                        onlyclip += 1
                if verbose:
                    print('%s %s %s: %s %d instructions, %d loads, %d stores, %d ops, %d calls, %d branches' % (fn.split('/')[-1], f['name'], f['items'][lo][1], c['kind'], c['ins'], c['loads'], c['stores'], c['ops'], c['calls'], c['branches']))
    print('files %d, instructions %d, innermost loops %d (static instructions in them: %d, %.1f%% of all)' % (len(files), tot, nloops, sum(clsins.values()), 100.0 * sum(clsins.values()) / tot if tot else 0))
    for k in ('map', 'reduce', 'fill', 'branch', 'call', 'other'):
        if cls[k]:
            sh = shape[k]
            ops = sorted(x['ops'] for x in sh)
            print('  %-8s %5d loops, %6d instructions (%.1f%% of all); body: median %d instructions; element operations: median %d, max %d; loads %.1f, stores %.1f on average' % (
                k, cls[k], clsins[k], 100.0 * clsins[k] / tot if tot else 0, sorted(x['ins'] for x in sh)[len(sh) // 2], ops[len(ops) // 2], ops[-1], sum(x['loads'] for x in sh) / len(sh), sum(x['stores'] for x in sh) / len(sh)))

    mp = shape.get('map', [])
    if mp:
        print('  map loops a single prefixed instruction could be: one operation on at most two streams (loads <= 2, ops <= 2): %d of %d (%.0f%%); with at most 4 streams and 4 operations: %d (%.0f%%); one store: %d' % (
            sum(1 for x in mp if x['loads'] <= 2 and x['ops'] <= 2), len(mp), 100.0 * sum(1 for x in mp if x['loads'] <= 2 and x['ops'] <= 2) / len(mp),
            sum(1 for x in mp if x['loads'] <= 4 and x['ops'] <= 4), 100.0 * sum(1 for x in mp if x['loads'] <= 4 and x['ops'] <= 4) / len(mp), sum(1 for x in mp if x['stores'] == 1)))
    if callees:
        print('  loops blocked by a call, by callee (a loop counts once for each): ' + ', '.join('%s %d' % kv for kv in callees.most_common(8)))
        print('  of them, loops whose only calls are clip, min, max, abs or sign helpers: %d of %d' % (onlyclip, cls['call']))


if __name__ == '__main__':
    main()
