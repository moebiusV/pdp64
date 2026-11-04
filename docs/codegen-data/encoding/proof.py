import sys,random,collections,json,re
sys.path.insert(0,'.')
import enc
from enc import *
from norm import *
def svals(sp,mn):
    """boundary operands of one operand spec"""
    if isinstance(sp,SR):
        regs=sorted(sp.table) if sp.table else list(range(1<<sp.w))
        pick={regs[0],regs[-1],regs[len(regs)//2]}
        if sp.table: pick|={sp.table[0],sp.table[-1]}
        return [('R',r) for r in sorted(pick)]
    if isinstance(sp,SK): return [sp.op]
    if isinstance(sp,SI):
        if sp.vals is not None: return [('I',sp.vals[0]),('I',sp.vals[-1])]
        sc=sp.scale
        if sp.signed: lo,hi=-(1<<(sp.w-1)),(1<<(sp.w-1))-1
        else: lo,hi=0,(1<<sp.w)-1
        return [('I',x*sc) for x in sorted(x for x in {lo,hi,0,1,-1} if lo<=x<=hi)]
    if isinstance(sp,SB):
        out=[]
        rs=svals(sp.rn,mn) if not isinstance(sp.rn,SK) else [sp.rn.op]
        if sp.dw==0: ds=[0]
        else:
            sc=sp._sc(mn)
            if sp.signed: lo,hi=-(1<<(sp.dw-1)),(1<<(sp.dw-1))-1
            else: lo,hi=0,(1<<sp.dw)-1
            ds=sorted({x*sc for x in (lo,hi,0,1) if lo<=x<=hi})
        for r in rs[:2]+rs[-1:]:
            for d in ds: out.append(('B',d,r[1]))
        return out
    if isinstance(sp,SX):
        out=[]
        rs=svals(sp.rn,mn); xs=svals(sp.rx,mn)
        ds=[0]
        if sp.dw:
            lo,hi=(-(1<<(sp.dw-1)),(1<<(sp.dw-1))-1) if sp.signed else (0,(1<<sp.dw)-1)
            ds=sorted({lo,hi,0})
        for r in (rs[0],rs[-1]):
            for x in (xs[0],xs[-1]):
                for d in ds:
                    for s in (1,8): out.append(('X',d,r[1],x[1],s))
        return out
    if isinstance(sp,SP):
        rs=svals(sp.rn,mn)
        return [(sp.kind_,r[1],d) for r in (rs[0],rs[-1]) for d in (0,(1<<sp.dw)-1)]
    if isinstance(sp,SPC):
        lo,hi=-(1<<(sp.w-1)),(1<<(sp.w-1))-1
        return [('PC',x*sp.unit) for x in (lo,hi,0,1,-1)]
    if isinstance(sp,SA):
        lo,hi=-(1<<(sp.w-1)),(1<<(sp.w-1))-1
        return [('A',x) for x in (lo,hi,0,1)]
    raise TypeError(sp)
def dec_roundtrip(sc,mn,ops,form):
    """encode with the given form; decode; return error string or None"""
    vals=form.fit(mn,ops)
    if vals is None: return 'no-fit'
    lf=None
    for l in sc.code.leaves:
        if l.form is form and mn in l.mns: lf=l; break
    w=build_word(lf,mn,vals); par=words_of(w,form.n)
    d=decode_word(sc.code,par)
    if d is None: return 'illegal'
    nops=tuple(o[:2] if o[0]=='PC' else o for o in ops)
    if d[0]!=mn or d[1]!=nops or d[2]!=form.n: return 'mismatch %s %s -> %s'%(mn,ops,d)
    return None
def boundary_tests(sc,seed=1):
    rnd=random.Random(seed); n=0; bad=[]; perform=collections.Counter()
    for f in sc.forms:
        for mn in f.mns:
            lists=[svals(sp,mn) for sp in f.specs]
            combos=[]
            base=[l[0] for l in lists]
            combos.append(tuple(base))
            for i,l in enumerate(lists):
                for v in l:
                    c=list(base); c[i]=v; combos.append(tuple(c))
            for _ in range(10): combos.append(tuple(rnd.choice(l) for l in lists))
            for c in set(combos):
                e=dec_roundtrip(sc,mn,c,f)
                n+=1; perform[f.name]+=1
                if e and len(bad)<20: bad.append((f.name,mn,c,e))
                elif e: bad.append(None)
    return n,[b for b in bad if b],len(perform)
def decodability(sc):
    code=sc.code
    # independent prefix-freeness check: no leaf prefix is a prefix of another
    L=sorted(code.leaves,key=lambda l:l.L)
    clash=0
    for i,a in enumerate(L):
        for b in L[i+1:]:
            if b.prefix>>(b.L-a.L)==a.prefix: clash+=1
    assigned=sum(1 for p in range(65536) if code.table[p] is not None)
    # every pattern: length definite (n from leaf) ; count per n
    cnt=collections.Counter(code.table[p].form.n for p in range(65536) if code.table[p] is not None)
    # bits: each leaf's placement covers all 16n bits exactly once
    for lf in code.leaves:
        f=lf.form; used=set()
        for b in range(15,15-lf.L,-1): used.add(b)
        for p in lf.subbits: assert p not in used; used.add(p)
        for key,bits in lf.place.items():
            for p in bits: assert p not in used,(f.name,key); used.add(p)
        assert len(used)==16*f.n,(f.name,len(used),16*f.n)
    return dict(leaves=len(code.leaves),forms=len(code.forms),clashes=clash,assigned_patterns=assigned,free_patterns=65536-assigned,by_len={k:v for k,v in sorted(cnt.items())},
                kraft=code.kraft,free_fraction=1-code.kraft)
def probe_cases():
    d=json.load(open('/tmp/claude-1000/-home-david-claude-pdp64/c8eb5fe9-a8c9-4e79-aafa-1502bfe6a13e/scratchpad/layouts/probe.json'))
    out=[]
    REGRE=re.compile(r'^(r\d+|sp|fp)$')
    for w,lst in d.items():
        for line,lab,ps in lst:
            parts=line.split(None,1)
            if not parts: continue
            mn=parts[0]; ops=splitops(parts[1]) if len(parts)>1 else []
            ops=[o for o in ops if o.strip()!='']
            ok=True; nops=[]
            for o in ops:
                o=o.strip()
                if o=='lbl': nops.append(('PC',64,'sym')); continue
                if o=='ptbr' or re.fullmatch(r'[a-z]+\d?',o) and not REGRE.match(o) and not o.startswith('r'): nops.append(('I',0)); continue
                k=kind(o)
                if k=='pcrel' and not (o.startswith('=')): ok=False; break
                nops.append(op_norm(o,k,64,0,o.startswith('=')))
            if ok: out.append((w,mn,tuple(nops),line))
    return out
def coverage(sc):
    cases=probe_cases(); miss=collections.Counter(); n=0
    for w,mn,ops,line in cases:
        n+=1
        if sc.plan(mn,ops) is None: miss[(mn,tuple(o[0] for o in ops))]+=1
    return n,miss
