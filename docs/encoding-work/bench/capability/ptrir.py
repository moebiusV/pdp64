#!/usr/bin/env python3
"""ptrir.py DIR...: compile the C files of OpenBSD source directories (../openbsd-src) to LLVM IR for x86_64-unknown-openbsd (LP64: the same data model as the pdp64,
8-byte pointers) and measure, per directory and in total:
  (1) the fraction of loads and stores whose value is a pointer (count, bytes, and weighted by LLVM's static block frequency, a proxy for execution count);
  (2) the struct types: bytes of pointer fields / bytes of struct, and the size of each struct if every pointer were 16 bytes aligned to 16 (the CHERI-128 layout),
      weighted by static uses of the type (getelementptr) as a proxy for how much of the code touches it;
  (3) what a bounds-setting compiler must emit: allocas whose address escapes (passed to a call or stored), address-of-global uses, calls to allocators.
STATIC COUNTS AND A PROXY: no OpenBSD userland binary for the pdp64 exists on this computer.   usage: TOOLS=dir-with-opt ptrir.py out.json dir..."""
import os, re, sys, json, subprocess, tempfile, glob
O = '/home/matthew/claude/openbsd-src'; S = os.environ['SCR']; INC = S + '/inc'; OPT = os.environ['TOOLS'] + '/opt'
CF = ['--target=x86_64-unknown-openbsd', '-nostdinc', '-isystem', INC, '-isystem', O + '/sys/sys', '-isystem', O + '/lib/libc/include', '-w', '-O2', '-S', '-emit-llvm']
SZ = {'i1': 1, 'i8': 1, 'i16': 2, 'i32': 4, 'i64': 8, 'i128': 16, 'float': 4, 'double': 8, 'ptr': 8, 'half': 2, 'x86_fp80': 16}
def split_top(s):
    out = []; d = 0; cur = ''
    for ch in s:
        if ch in '{[<(': d += 1
        if ch in '}]>)': d -= 1
        if ch == ',' and d == 0: out.append(cur.strip()); cur = ''
        else: cur += ch
    if cur.strip(): out.append(cur.strip())
    return out
class Lay:
    def __init__(s, structs): s.st = structs; s.cache = {}
    def lay(s, t, big):
        """-> (size, align, ptrbytes) ; big: pointers are 16 bytes aligned 16"""
        t = t.strip(); key = (t, big)
        if key in s.cache: return s.cache[key]
        if t == 'ptr': r = (16, 16, 16) if big else (8, 8, 8)
        elif t in SZ: r = (SZ[t], min(SZ[t], 16), 0)
        elif t.startswith('['):
            m = re.match(r'\[(\d+) x (.*)\]$', t); n = int(m.group(1)); a, al, p = s.lay(m.group(2), big); r = (n * a, al, n * p)
        elif t.startswith('%'):
            body = s.st.get(t)
            r = s.lay(body, big) if body else (8, 8, 0)
        elif t.startswith('<{'): fs = split_top(t[2:-2]); r = s.fields(fs, big, packed=True)
        elif t.startswith('{'): fs = split_top(t[1:-1]); r = s.fields(fs, big)
        elif t.startswith('opaque'): r = (8, 8, 0)
        elif t.startswith('<'): r = (16, 16, 0)
        else: r = (8, 8, 0)
        s.cache[key] = r; return r
    def fields(s, fs, big, packed=False):
        off = 0; al = 1; pb = 0
        for f in fs:
            a, fa, p = s.lay(f, big)
            if packed: fa = 1
            off = (off + fa - 1) // fa * fa; off += a; al = max(al, fa); pb += p
        off = (off + al - 1) // al * al
        return (off, al, pb)
def analyse(ll, res):
    txt = open(ll).read()
    structs = {m.group(1): m.group(2) for m in re.finditer(r'^(%[\w.$]+) = type (.*)$', txt, flags=re.M)}
    L = Lay(structs)
    uses = {}
    for m in re.finditer(r'getelementptr (?:inbounds )?(?:nuw )?(?:nusw )?(%[\w.$]+),', txt): uses[m.group(1)] = uses.get(m.group(1), 0) + 1
    for name, body in structs.items():
        sz, al, pb = L.lay(name, False); sz2, al2, pb2 = L.lay(name, True)
        if sz == 0: continue
        r = res['structs'].setdefault(name, dict(size=sz, ptr=pb, size16=sz2, uses=0)); r['uses'] += uses.get(name, 0)
    # loads and stores by function, weighted by block frequency
    bf = subprocess.run([OPT, '-passes=print<block-freq>', '-disable-output', ll], capture_output=True, text=True).stderr
    freq = {}; cur = None
    for l in bf.splitlines():
        m = re.match(r'Printing analysis .* for function \'([^\']*)\'', l)
        if m: cur = m.group(1); freq[cur] = {}; continue
        m = re.match(r'\s*- (\S*): float = ([0-9.e+-]+)', l)
        if m and cur is not None: freq[cur][len(freq[cur])] = float(m.group(2))     # blocks are unnamed: by position
    fn = None; blk = None
    for l in txt.splitlines():
        m = re.match(r'define .*@([\w.$]+)\(', l)
        if m: fn = m.group(1); blk = 0; continue
        if l.startswith('}'): fn = None; continue
        if fn is None: continue
        m = re.match(r'([\w.$-]+):', l)
        if m: blk += 1; continue
        w = freq.get(fn, {}).get(blk, 1.0)
        m = re.search(r'\bload (?:volatile )?(\S+), ptr', l)
        if m:
            t = m.group(1); k = 'ptr' if t == 'ptr' else 'other'; b = SZ.get(t, 8)
            res['ld'][k] += 1; res['ldw'][k] += w; res['ldb'][k] += b; continue
        m = re.search(r'\bstore (?:volatile )?(\S+) (?:.*), ptr', l)
        if m:
            t = m.group(1); k = 'ptr' if t == 'ptr' else 'other'; b = SZ.get(t, 8)
            res['st'][k] += 1; res['stw'][k] += w; res['stb'][k] += b; continue
        if ' alloca ' in l: res['alloca'] += 1
    # escaping allocas: the alloca's value is an argument of a call (not a lifetime marker) or is stored as a value
    names = [m.group(1) for m in re.finditer(r'^\s*(%[\w.$]+) = alloca', txt, flags=re.M)]
    esc = set()
    for l in txt.splitlines():
        if 'call ' in l and '@llvm.lifetime' not in l and '@llvm.dbg' not in l:
            args = l[l.index('('):] if '(' in l else ''
            for n in re.findall(r'ptr (?:[\w()= ]*? )?(%[\w.$]+)', args): esc.add(n)
        m = re.match(r'\s*store ptr (%[\w.$]+),', l)
        if m: esc.add(m.group(1))
    res['alloca_esc'] += sum(1 for n in names if n in esc)
    res['alloc_calls'] += len(re.findall(r'call [^\n]*@(?:malloc|calloc|realloc|reallocarray|recallocarray|xmalloc|xcalloc|xreallocarray|xstrdup|strdup|asprintf)\b', txt))
    res['calls'] += len(re.findall(r'\bcall ', txt))
    res['global_addr'] += len(re.findall(r'\bptr @[\w.$]+', txt))
def run(dirs):
    tot = None; per = {}
    for d in dirs:
        res = dict(ld={'ptr': 0, 'other': 0}, st={'ptr': 0, 'other': 0}, ldw={'ptr': 0.0, 'other': 0.0}, stw={'ptr': 0.0, 'other': 0.0}, ldb={'ptr': 0, 'other': 0}, stb={'ptr': 0, 'other': 0},
                   alloca=0, alloca_esc=0, alloc_calls=0, calls=0, global_addr=0, structs={}, files=0)
        for f in sorted(glob.glob(O + '/' + d + '/*.c')):
            with tempfile.TemporaryDirectory() as t:
                ll = t + '/x.ll'
                r = subprocess.run(['clang'] + CF + ['-I' + O + '/' + d, '-o', ll, f], capture_output=True)
                if r.returncode: continue
                res['files'] += 1; analyse(ll, res)
        per[d] = res
    return per
def summarise(res):
    ld, st = res['ld'], res['st']; out = {}
    out['files'] = res['files']
    out['load_ptr_frac'] = ld['ptr'] / max(1, ld['ptr'] + ld['other']); out['store_ptr_frac'] = st['ptr'] / max(1, st['ptr'] + st['other'])
    lw, sw = res['ldw'], res['stw']
    out['load_ptr_frac_weighted'] = lw['ptr'] / max(1e-9, lw['ptr'] + lw['other']); out['store_ptr_frac_weighted'] = sw['ptr'] / max(1e-9, sw['ptr'] + sw['other'])
    lb, sb = res['ldb'], res['stb']
    out['ptr_byte_frac_weighted_unavailable'] = None
    S = [v for v in res['structs'].values() if v['size'] > 0]
    tb = sum(v['size'] for v in S); pb = sum(v['ptr'] for v in S); gb = sum(v['size16'] for v in S)
    out['struct_types'] = len(S); out['struct_ptr_byte_frac'] = pb / max(1, tb); out['struct_growth'] = gb / max(1, tb) - 1
    uw = sum(v['uses'] for v in S)
    out['struct_ptr_byte_frac_by_use'] = sum(v['ptr'] * v['uses'] for v in S) / max(1, sum(v['size'] * v['uses'] for v in S))
    out['struct_growth_by_use'] = sum(v['size16'] * v['uses'] for v in S) / max(1, sum(v['size'] * v['uses'] for v in S)) - 1
    out['alloca'] = res['alloca']; out['alloca_escaping'] = res['alloca_esc']; out['alloc_calls'] = res['alloc_calls']; out['calls'] = res['calls']; out['global_addr_uses'] = res['global_addr']
    return out
if __name__ == '__main__':
    outf = sys.argv[1]; per = run(sys.argv[2:])
    summ = {d: summarise(r) for d, r in per.items()}
    # total: merge
    tot = None
    for r in per.values():
        if tot is None: tot = json.loads(json.dumps(r)); continue
        for k in ('ld', 'st', 'ldw', 'stw', 'ldb', 'stb'):
            for kk in r[k]: tot[k][kk] += r[k][kk]
        for k in ('alloca', 'alloca_esc', 'alloc_calls', 'calls', 'global_addr', 'files'): tot[k] += r[k]
        for n, v in r['structs'].items():
            t = tot['structs'].setdefault(n, dict(v)); 
            if t is not v: t['uses'] = t['uses'] + v['uses'] if t['uses'] != v['uses'] else t['uses']
    summ['TOTAL'] = summarise(tot)
    json.dump(summ, open(outf, 'w'), indent=1)
    for d, s in summ.items(): print(d, {k: (round(v, 4) if isinstance(v, float) else v) for k, v in s.items() if v is not None})
