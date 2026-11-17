#!/usr/bin/env python3
"""boundscan.py -- census of the bounds-check sites that -fsanitize=bounds puts into the corpus.

usage: boundscan.py INDIR OUTDIR [-j N] [-O LEVEL]

For each preprocessed file INDIR/NNN.i: compile to LLVM IR with `-fsanitize=bounds -fsanitize-trap=bounds` (target
loongarch64; the IR before the back end does not depend on it beyond the data layout) and read the IR.  A *site* is a
conditional branch whose one arm is a block that calls @llvm.ubsantrap.  Each site is classified by the compare that decides
it:
    pred       the compare predicate (ult, ule, ugt, uge, slt, ..., eq, ne), "none" when the condition is not a compare
    bound      "const" when one operand is a constant (the bound is an immediate), "var" otherwise
    offset     "nuw", "nsw" or "yes" when the tested operand is itself `x + c` or `x - c` with a constant c (the flag is that of the add or
               sub): the check on x alone is lo <= x < hi.  With nuw the arithmetic cannot wrap, so one unsigned compare of x with an
               adjusted bound is the whole check; with nsw only, or with no flag, x may lie below lo and a true band is needed
    in_loop    "yes" when the branch block lies on a cycle of its function's control-flow graph
Output: OUTDIR/sites.csv (one row per site: file,function,pred,bound,offset,in_loop), OUTDIR/files.csv (per file: status, sites,
IR instructions), OUTDIR/summary.txt.  The pointer-against-pointer compares of the plain build (`-P`) are counted too:
`icmp u* ptr`, the shape of an address-range check, which the sanitizer does not insert.
"""
import os, re, sys, subprocess, collections, concurrent.futures as cf

CLANG = ['clang', '--target=loongarch64-linux-gnu', '-fno-pic', '-std=gnu99', '-w', '-fno-asynchronous-unwind-tables',
         '-Wno-error=implicit-function-declaration', '-Wno-error=implicit-int', '-Wno-error=int-conversion',
         '-Wno-error=incompatible-pointer-types']
SAN = ['-fsanitize=bounds', '-fsanitize-trap=bounds']

LABEL = re.compile(r'^([\w.$-]+):')
DEFINE = re.compile(r'^define .*@("?[\w.$-]+"?)\(')
BR2 = re.compile(r'^\s*br i1 (%[\w.$-]+|true|false), label %([\w.$-]+), label %([\w.$-]+)')
BR1 = re.compile(r'^\s*br label %([\w.$-]+)')
SW = re.compile(r'^\s*switch .*label %([\w.$-]+) \[')
SWC = re.compile(r'label %([\w.$-]+)')
ICMP = re.compile(r'^\s*(%[\w.$-]+) = icmp (?:samesign )?(\w+) (?:\w+ )?(.+?), (.+)$')
OP = re.compile(r'^\s*(%[\w.$-]+) = (?:tail |musttail )?(\w+)')
ARITH = re.compile(r'^\s*(%[\w.$-]+) = (add|sub)((?: nuw| nsw)*) \S+ (.+?), (.+)$')
TRAP = '@llvm.ubsantrap'


def split_functions(ir):
    fn = None
    for ln in ir.split('\n'):
        m = DEFINE.match(ln)
        if m:
            fn = [m.group(1), []]
            continue
        if fn is not None:
            if ln == '}':
                yield fn
                fn = None
            else:
                fn[1].append(ln)


def blocks_of(lines):
    """-> ordered list of (label, [lines]); the entry block has the label 'entry' if clang did not name it"""
    out = []
    cur = ['%entry', []]
    for ln in lines:
        m = LABEL.match(ln)
        if m and not ln.startswith(' '):
            out.append(cur)
            cur = [m.group(1), []]
        else:
            cur[1].append(ln)
    out.append(cur)
    return [(a, b) for a, b in out if b or a != '%entry']


def cyclic_blocks(succ):
    """names of the blocks that lie on a cycle (Tarjan's SCC, iterative)"""
    idx, low, on, st, res, n = {}, {}, set(), [], set(), [0]
    for root in succ:
        if root in idx:
            continue
        work = [(root, iter(succ.get(root, ())))]
        idx[root] = low[root] = n[0]; n[0] += 1; st.append(root); on.add(root)
        while work:
            v, it = work[-1]
            adv = False
            for w in it:
                if w not in succ:
                    continue
                if w not in idx:
                    idx[w] = low[w] = n[0]; n[0] += 1; st.append(w); on.add(w)
                    work.append((w, iter(succ.get(w, ()))))
                    adv = True
                    break
                elif w in on:
                    low[v] = min(low[v], idx[w])
            if adv:
                continue
            work.pop()
            if work:
                low[work[-1][0]] = min(low[work[-1][0]], low[v])
            if low[v] == idx[v]:
                comp = []
                while True:
                    w = st.pop(); on.discard(w); comp.append(w)
                    if w == v:
                        break
                if len(comp) > 1 or v in succ.get(v, ()):
                    res.update(comp)
    return res


def isconst(s):
    s = s.strip()
    return bool(re.fullmatch(r'-?\d+|true|false|null|zeroinitializer|undef|poison|-?0x[0-9A-Fa-f]+', s))


def scan_function(name, lines, fname):
    blocks = blocks_of(lines)
    succ, trapblk, defs = {}, set(), {}
    for lab, body in blocks:
        s = []
        for ln in body:
            if TRAP in ln and 'call' in ln:
                trapblk.add(lab)
            m = ICMP.match(ln)
            if m:
                defs[m.group(1)] = ('icmp', m.group(2), m.group(3), m.group(4), ln)
            m = ARITH.match(ln)
            if m:
                defs[m.group(1)] = ('arith', m.group(2), m.group(4), m.group(5), ln, m.group(3))
            elif not ICMP.match(ln):
                m = OP.match(ln)
                if m:
                    defs[m.group(1)] = ('op', m.group(2), '', '', ln)
        last = body[-1] if body else ''
        for ln in reversed(body):
            if ln.strip():
                last = ln
                break
        m = BR2.match(last)
        if m:
            s = [m.group(2), m.group(3)]
        else:
            m = BR1.match(last)
            if m:
                s = [m.group(1)]
            elif SW.match(last):
                s = list(dict.fromkeys(SWC.findall(last)))
        succ[lab] = s
    cyc = cyclic_blocks(succ)
    sites = []
    for lab, body in blocks:
        last = ''
        for ln in reversed(body):
            if ln.strip():
                last = ln
                break
        m = BR2.match(last)
        if not m:
            continue
        cond, a, b = m.groups()
        if a in trapblk or b in trapblk:
            if a in trapblk and b in trapblk:
                continue
            d = defs.get(cond)
            pred, bound, off = 'none', 'var', 'no'
            if d and d[0] == 'op':
                pred = 'combo-' + d[1]
            if d and d[0] == 'icmp':
                pred = d[1]
                x, y = d[2].strip(), d[3].strip()
                bound = 'const' if (isconst(x) or isconst(y)) else 'var'
                var = y if isconst(x) else x
                v = defs.get(var)
                if v and v[0] == 'arith' and (isconst(v[2]) or isconst(v[3])):
                    fl = v[5]
                    off = 'nuw' if 'nuw' in fl else 'nsw' if 'nsw' in fl else 'yes'	# nuw: x +/- c cannot wrap, so a compare of x with an adjusted bound is the whole check
            sites.append((fname, name, pred, bound, off, 'yes' if lab in cyc else 'no'))
    return sites


def var_geps(ir):
    """getelementptr instructions with an index that is not a constant: the subscripts a language that checks every subscript would guard"""
    n = 0
    for ln in ir.split('\n'):
        if 'getelementptr' not in ln or not ln.startswith('  '):
            continue
        toks = re.findall(r'\bi\d+ (%[\w.$-]+|-?\d+)', ln.split('getelementptr', 1)[1])
        if any(x.startswith('%') for x in toks):
            n += 1
    return n


def ptr_compares(ir):
    return len(re.findall(r'= icmp (?:u\w+|eq|ne) ptr ', ir))


def one(args):
    n, indir, level, plain = args
    cmd = ['clang'] + CLANG[1:] + ([] if plain else SAN) + [level, '-S', '-emit-llvm', '-c', '-x', 'c', '-o', '-', '%s/%s.i' % (indir, n)]
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, errors='replace', timeout=300)
    except subprocess.TimeoutExpired:
        return n, 'fail', [], 0, 0, 'timeout', 0
    if p.returncode:
        m = [x for x in p.stderr.strip().split('\n') if 'error' in x]
        return n, 'fail', [], 0, 0, (m[0] if m else 'exit %d' % p.returncode)[:150].replace(',', ';'), 0
    ir = p.stdout
    sites = []
    for name, lines in split_functions(ir):
        sites += scan_function(name, lines, n)
    ninsn = sum(1 for ln in ir.split('\n') if ln.startswith('  ') and not ln.strip().startswith(('call void @llvm.dbg', ';')) and '=' in ln or ln.startswith('  ret') or ln.startswith('  br'))
    return n, 'ok', sites, ninsn, ptr_compares(ir), '', var_geps(ir)


def main():
    a = sys.argv[1:]
    indir, out = a[0], a[1]
    jobs, level, plain = 2, '-O2', False
    i = 2
    while i < len(a):
        if a[i] == '-j': jobs = int(a[i + 1]); i += 2
        elif a[i] == '-O': level = '-O' + a[i + 1].lstrip('-O'); i += 2
        elif a[i] == '-P': plain = True; i += 1
        else: i += 1
    os.makedirs(out, exist_ok=True)
    names = sorted(f[:-2] for f in os.listdir(indir) if f.endswith('.i'))
    cnt = collections.Counter(); files = []
    with cf.ThreadPoolExecutor(jobs) as ex, open(out + '/sites.csv', 'w') as sf:
        sf.write('file,function,pred,bound,offset,in_loop\n')
        for n, st, sites, ninsn, pc, msg, vg in ex.map(one, [(n, indir, level, plain) for n in names]):
            files.append((n, st, len(sites), ninsn, pc, vg, msg))
            for s in sites:
                sf.write(','.join(s).replace('"', '') + '\n')
                cnt[(s[2], s[3], s[4], s[5])] += 1
    with open(out + '/files.csv', 'w') as f:
        f.write('file,status,sites,ir_insns,ptr_cmps,var_geps,msg\n')
        for r in files:
            f.write(','.join(str(x) for x in r) + '\n')
    ok = [r for r in files if r[1] == 'ok']
    tot = sum(r[2] for r in ok)
    with open(out + '/summary.txt', 'w') as f:
        f.write('files ok %d of %d; sites %d; IR instructions %d; pointer compares %d; variable-index getelementptr %d\n' % (len(ok), len(files), tot, sum(r[3] for r in ok), sum(r[4] for r in ok), sum(r[5] for r in ok)))
        for k, v in sorted(cnt.items(), key=lambda kv: -kv[1]):
            f.write('%7d  pred=%s bound=%s offset=%s in_loop=%s\n' % ((v,) + k))
    print(open(out + '/summary.txt').read())


if __name__ == '__main__':
    main()
