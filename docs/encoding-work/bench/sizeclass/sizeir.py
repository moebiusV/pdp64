#!/usr/bin/env python3
"""sizeir.py OUT.json DIR...: static counts over OpenBSD C sources (../openbsd-src), compiled to LLVM IR for x86_64-unknown-openbsd (LP64, as the pdp64).
  (1) stack objects (allocas) that ESCAPE (their address, or an address derived by gep, is passed to a call or stored): how many have a size known at compile
      time, and their sizes (a power-of-two slot would cost the rounding, and the object ALIGNED to that size);
  (2) calls of the allocators and how many have constant size arguments;
  (3) pointer-to-integer and integer-to-pointer casts (ptrtoint, inttoptr) in the -O0 IR, which is the nearest to the source casts (a proxy for pointer-in-integer code).
STATIC COUNTS AND A PROXY: no OpenBSD binary for the pdp64 exists.   usage: SCR=dir-with-inc TOOLS=x python3 sizeir.py out.json usr.bin/sed ...
(ptrir.py of ../capability supplies the layout code and the compile line; run it from this directory.)"""
import os, re, sys, json, subprocess, tempfile, glob
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'capability'))
import ptrir
from ptrir import Lay, O, CF
ALLOC = r'(?:malloc|calloc|realloc|reallocarray|recallocarray|xmalloc|xcalloc|xreallocarray|xrealloc|emalloc|ecalloc)'
def parse_type(s):
    s = s.strip()
    if s[0] in '{[<':
        d = 0
        for i, ch in enumerate(s):
            if ch in '{[<': d += 1
            if ch in '}]>': d -= 1
            if d == 0: return s[:i + 1], s[i + 1:]
    m = re.match(r'([^,\s]+)', s); return m.group(1), s[len(m.group(1)):]
def analyse(ll, res):
    txt = open(ll).read()
    structs = {m.group(1): m.group(2) for m in re.finditer(r'^(%[\w.$]+) = type (.*)$', txt, flags=re.M)}
    L = Lay(structs)
    # local names (%1, %2, ...) repeat from function to function: take one function at a time
    funcs = re.split(r'(?m)^(?=define )', txt)
    for fb in funcs:
        if not fb.startswith('define'): continue
        allocas = {}; deriv = {}
        lines = fb.splitlines()
        for l in lines:
            m = re.match(r'\s*(%[\w.$]+) = alloca (.*)$', l)
            if m:
                t, rest = parse_type(m.group(2)); cnt = 1; dyn = False
                mm = re.match(r',\s*i\d+ (\S+?),', rest + ',')
                if mm:
                    if mm.group(1).lstrip('-').isdigit(): cnt = int(mm.group(1))
                    else: dyn = True
                sz, al, _ = L.lay(t, False)
                allocas[m.group(1)] = (sz * cnt, dyn); continue
            m = re.match(r'\s*(%[\w.$]+) = (?:getelementptr|select|phi)\b.*', l)
            if m:
                for n in re.findall(r'%[\w.$]+', l[l.index('=') + 1:]): deriv.setdefault(m.group(1), set()).add(n)
        esc = set()
        for l in lines:
            if 'call ' in l and '@llvm.lifetime' not in l and '@llvm.dbg' not in l:
                args = l[l.index('('):] if '(' in l else ''
                for n in re.findall(r'ptr (?:[\w()= ]*? )?(%[\w.$]+)', args): esc.add(n)
            m = re.match(r'\s*store ptr (%[\w.$]+),', l)
            if m: esc.add(m.group(1))
        changed = True
        while changed:
            changed = False
            for y, xs in deriv.items():
                if y in esc:
                    for x in xs:
                        if x not in esc: esc.add(x); changed = True
        big = 0
        for n, (sz, dyn) in allocas.items():
            res['alloca'] += 1
            if n in esc:
                if dyn: res['esc_dyn'] += 1
                else:
                    res['esc_sizes'].append(sz)
                    if sz > 16: big += 1
        res['funcs'] += 1
        if any(n in esc for n in allocas): res['funcs_esc'] += 1
        if big: res['funcs_big'] += 1
    for m in re.finditer(r'call [^\n]*@' + ALLOC + r'\(([^)]*)\)', txt):
        res['alloc_calls'] += 1
        parts = [a.strip() for a in m.group(1).split(',')]
        if all(re.search(r'\s-?\d+$', a) for a in parts): res['alloc_const'] += 1
    res['instrs'] += sum(1 for l in txt.splitlines() if re.match(r'\s+(%[\w.$]+ = )?[a-z]', l))
def casts(ll, res):
    txt = open(ll).read()
    res['ptrtoint'] += len(re.findall(r'= ptrtoint\b', txt)); res['inttoptr'] += len(re.findall(r'= inttoptr\b', txt))
    res['ptr_rel'] += len(re.findall(r'icmp (?:ult|ule|ugt|uge|slt|sle|sgt|sge) ptr\b', txt)); res['ptr_eq'] += len(re.findall(r'icmp (?:eq|ne) ptr\b', txt))
    res['instrs0'] += sum(1 for l in txt.splitlines() if re.match(r'\s+(%[\w.$]+ = )?[a-z]', l))
def run(dirs):
    per = {}
    for d in dirs:
        res = dict(files=0, alloca=0, esc_dyn=0, esc_sizes=[], alloc_calls=0, alloc_const=0, instrs=0, ptrtoint=0, inttoptr=0, instrs0=0, funcs=0, funcs_esc=0, funcs_big=0, ptr_rel=0, ptr_eq=0)
        for f in sorted(glob.glob(O + '/' + d + '/*.c')):
            with tempfile.TemporaryDirectory() as t:
                ll = t + '/x.ll'; l0 = t + '/y.ll'
                r = subprocess.run(['clang'] + CF + ['-I' + O + '/' + d, '-o', ll, f], capture_output=True)
                if r.returncode: continue
                r0 = subprocess.run(['clang'] + [a if a != '-O2' else '-O0' for a in CF] + ['-I' + O + '/' + d, '-o', l0, f], capture_output=True)
                res['files'] += 1; analyse(ll, res)
                if not r0.returncode: casts(l0, res)
        per[d] = res
    return per
if __name__ == '__main__':
    per = run(sys.argv[2:])
    json.dump(per, open(sys.argv[1], 'w'))
