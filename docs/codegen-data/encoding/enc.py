"""Generic prefix-coded instruction encoding framework.
A Form = (parcels n, mnemonic list, operand specs).  Leaf prefix length L = 16n - operand bits - sub-op bits.
Layout of a form:  P0[15..16-L] prefix, then (sub-op) ; registers at P0 bit 0 upward (last operand register lowest);
all other fields fill the remaining bits in order (P0 middle, then P1, P2).  No pad bits: every bit is prefix, sub-op or operand.
"""
import math,sys,collections
sys.dont_write_bytecode=True
SIZE={'movq':8,'movl':4,'movw':2,'movb':1,'movzl':4,'movzw':2,'movzb':1}
def msize(mn,default=1):
    b=mn.split('.')[0]
    return SIZE.get(b,default)
def sgn(v,b): return -(1<<(b-1))<=v<(1<<(b-1))
RELOC='max'   # 'max': unresolved external needs >=32-bit reach field ; 'near': external treated as value 0
RW=32
# ---------------------------------------------------------------- operand specs
class Spec: pass
class SR(Spec):
    kind='R'
    def __init__(s,w,table=None):
        s.w=w; s.table=table; s.inv=None
        if table is not None: s.inv={r:i for i,r in enumerate(table)}
        s.parts=[('r',w)]
    def fit(s,op,mn):
        if op[0]!='R': return None
        r=op[1]
        if s.inv is not None: return (s.inv[r],) if r in s.inv else None
        return (r,) if 0<=r<(1<<s.w) else None
    def make(s,v,mn):
        return ('R',s.table[v[0]] if s.table is not None and v[0]<len(s.table) else v[0]) if (s.table is None or v[0]<len(s.table)) else None
    def key(s): return ('R',s.w,s.table)
class SK(Spec):  # constant operand, no bits
    @property
    def kind(s): return s.op[0]
    def __init__(s,op): s.op=op; s.parts=[]
    def fit(s,op,mn): return () if op==s.op else None
    def make(s,v,mn): return s.op
    def key(s): return ('K',s.op)
class SI(Spec):
    kind='I'
    def __init__(s,w,signed=True,scale=1,vals=None):
        s.w=w; s.signed=signed; s.scale=scale; s.vals=vals; s.parts=[('i',w)]
    def fit(s,op,mn):
        if op[0]!='I': return None
        v=op[1]
        if s.vals is not None: return (s.vals.index(v),) if v in s.vals else None
        if v%s.scale: return None
        q=v//s.scale
        if s.signed:
            return (q&((1<<s.w)-1),) if sgn(q,s.w) else None
        return (q,) if 0<=q<(1<<s.w) else None
    def make(s,v,mn):
        x=v[0]
        if s.vals is not None: return ('I',s.vals[x]) if x<len(s.vals) else None
        if s.signed and x>>(s.w-1): x-=1<<s.w
        return ('I',x*s.scale)
    def key(s): return ('I',s.w,s.signed,s.scale,s.vals)
class SB(Spec):
    kind='B'  # ('B',d,n)
    def __init__(s,rn,dw,signed=True,scale='sz'):
        s.rn=rn; s.dw=dw; s.signed=signed; s.scale=scale
        s.parts=rn.parts+([('d',dw)] if dw else [])
    def _sc(s,mn): return msize(mn) if s.scale=='sz' else s.scale
    def fit(s,op,mn):
        if op[0]!='B': return None
        d=op[1]; rr=s.rn.fit(('R',op[2]),mn)
        if rr is None: return None
        if s.dw==0: return rr if d==0 else None
        sc=s._sc(mn)
        if d%sc: return None
        q=d//sc
        if s.signed:
            if not sgn(q,s.dw): return None
            q&=(1<<s.dw)-1
        elif not 0<=q<(1<<s.dw): return None
        return rr+(q,)
    def make(s,v,mn):
        nr=len(s.rn.parts); r=s.rn.make(v[:nr],mn)
        if r is None: return None
        if s.dw==0: return ('B',0,r[1])
        q=v[nr]
        if s.signed and q>>(s.dw-1): q-=1<<s.dw
        return ('B',q*s._sc(mn),r[1])
    def key(s): return ('B',s.rn.key(),s.dw,s.signed,s.scale)
class SX(Spec):
    kind='X'  # ('X',d,n,x,s)
    def __init__(s,rn,rx,dw,signed=True):
        s.rn=rn; s.rx=rx; s.dw=dw; s.signed=signed
        s.parts=rn.parts+rx.parts+[('s',2)]+([('d',dw)] if dw else [])
    def fit(s,op,mn):
        if op[0]!='X': return None
        d,n,x,sc=op[1:]
        a=s.rn.fit(('R',n),mn); b=s.rx.fit(('R',x),mn)
        if a is None or b is None or sc not in(1,2,4,8): return None
        l=(0,1,2,3)[(1,2,4,8).index(sc)]
        if s.dw==0:
            return a+b+(l,) if d==0 else None
        if s.signed:
            if not sgn(d,s.dw): return None
            d&=(1<<s.dw)-1
        elif not 0<=d<(1<<s.dw): return None
        return a+b+(l,d)
    def make(s,v,mn):
        na=len(s.rn.parts); nb=len(s.rx.parts)
        a=s.rn.make(v[:na],mn); b=s.rx.make(v[na:na+nb],mn)
        if a is None or b is None: return None
        sc=(1,2,4,8)[v[na+nb]]
        d=0
        if s.dw:
            d=v[na+nb+1]
            if s.signed and d>>(s.dw-1): d-=1<<s.dw
        return ('X',d,a[1],b[1],sc)
    def key(s): return ('X',s.rn.key(),s.rx.key(),s.dw,s.signed)
class SP(Spec):
    @property
    def kind(s): return s.kind_
  # post-inc / pre-dec : ('PI',n,stride) 
    def __init__(s,kind,rn,dw):
        s.kind_=kind; s.rn=rn; s.dw=dw; s.parts=rn.parts+[('d',dw)]
    def fit(s,op,mn):
        if op[0]!=s.kind_: return None
        r=s.rn.fit(('R',op[1]),mn)
        if r is None or not 0<=op[2]<(1<<s.dw): return None
        return r+(op[2],)
    def make(s,v,mn):
        r=s.rn.make(v[:-1],mn)
        return None if r is None else (s.kind_,r[1],v[-1])
    def key(s): return ('P',s.kind,s.rn.key(),s.dw)
class SPC(Spec):
    kind='PC'  # ('PC',val,tag) field counts units
    def __init__(s,w,unit=1): s.w=w; s.unit=unit; s.parts=[('p',w)]
    def fit(s,op,mn):
        if op[0]!='PC': return None
        v=op[1]
        if v is None:
            if RELOC=='max' and s.w+int(math.log2(s.unit))<RW: return None
            v=0
        if v%s.unit: return None
        q=v//s.unit
        return (q&((1<<s.w)-1),) if sgn(q,s.w) else None
    def make(s,v,mn):
        x=v[0]
        if x>>(s.w-1): x-=1<<s.w
        return ('PC',x*s.unit)
    def key(s): return ('PC',s.w,s.unit)
class SA(Spec):
    kind='A'  # ('A',v)
    def __init__(s,w): s.w=w; s.parts=[('a',w)]
    def fit(s,op,mn):
        if op[0]!='A': return None
        v=op[1]
        if v is None:
            if RELOC=='max' and s.w<RW: return None
            v=0
        return (v&((1<<s.w)-1),) if sgn(v,s.w) else None
    def make(s,v,mn):
        x=v[0]
        if x>>(s.w-1): x-=1<<s.w
        return ('A',x)
    def key(s): return ('A',s.w)
class SF(Spec):   # free (unsigned) field of w bits carrying an imm  (mask etc.)
    pass
# ---------------------------------------------------------------- forms
class Form:
    def __init__(s,name,n,mns,specs,fam='',xbits=0):
        s.name=name; s.n=n; s.mns=list(mns); s.specs=specs; s.fam=fam; s.xbits=xbits
        assert xbits==0 or len(mns)<=(1<<xbits)
        s.ob=sum(p[1] for sp in specs for p in sp.parts)+xbits
        s.Lleaf=16*n-s.ob            # per-mnemonic leaf prefix length (no sub-op)
        assert 0<s.Lleaf<=16+0 or True
    def kraft(s): return 2.0**-s.Lleaf if s.xbits else len(s.mns)*2.0**-s.Lleaf
    def sig(s): return tuple(sp.key() for sp in s.specs)
    @property
    def kinds(s): return tuple(sp.kind for sp in s.specs)
    def fit(s,mn,ops):
        if len(ops)!=len(s.specs) or mn not in s._mnset(): return None
        vals=[]
        for sp,op in zip(s.specs,ops):
            r=sp.fit(op,mn)
            if r is None: return None
            vals.append(r)
        return vals
    def _mnset(s):
        if not hasattr(s,'_ms') or len(s._ms)!=len(s.mns): s._ms=set(s.mns)
        return s._ms

# ---------------------------------------------------------------- the code: prefix assignment, bit layout, encode, decode
def pow2_chunks(k):
    out=[];j=0
    for b in range(20,-1,-1):
        if k>>b&1: out.append(b)
    return out   # exponents, largest first
class Leaf:  # a binary-aligned group of mnemonics of one form
    pass
class Code:
    def __init__(s,forms,reserve_note=''):
        s.forms=forms; s.leaves=[]
        for f in forms:
            off=0
            if f.xbits:
                lf=Leaf(); lf.form=f; lf.off=0; lf.j=0; lf.L=f.Lleaf; lf.mns=f.mns; s.leaves.append(lf); continue
            for j in pow2_chunks(len(f.mns)):
                lf=Leaf(); lf.form=f; lf.off=off; lf.j=j; lf.L=f.Lleaf-j
                lf.mns=f.mns[off:off+(1<<j)]; off+=1<<j
                s.leaves.append(lf)
        for lf in s.leaves:
            if not (1<=lf.L<=16): raise ValueError('prefix length %d out of range for %s'%(lf.L,lf.form.name))
        s.kraft=sum(2.0**-lf.L for lf in s.leaves)
        if s.kraft>1+1e-12: raise ValueError('Kraft sum %.4f > 1'%s.kraft)
        s._assign(); s._layouts()
    def _assign(s):
        order=sorted(range(len(s.leaves)),key=lambda i:(s.leaves[i].L,i))
        code=0; prevL=None
        for i in order:
            lf=s.leaves[i]
            if prevL is not None:
                code=(code+1)<<(lf.L-prevL) if False else code
            lf.idx=i
        # canonical: sort by L; allocate in 16-bit space, aligned
        pos=0
        for i in order:
            lf=s.leaves[i]; size=1<<(16-lf.L)
            if pos%size: pos+=size-(pos%size)
            lf.lo=pos; lf.hi=pos+size; lf.prefix=pos>>(16-lf.L); pos+=size
        assert pos<=65536, pos
        s.used=pos
        s.table=[None]*65536
        for lf in s.leaves:
            for p in range(lf.lo,lf.hi):
                assert s.table[p] is None
                s.table[p]=lf
    def _layouts(s):
        for f in s.forms:
            # leaf-independent field placement depends on L of the leaf (prefix + sub-op): compute per leaf
            pass
        for lf in s.leaves:
            f=lf.form; L=lf.L
            used=[False]*(16*f.n)   # bit index = 16*k + b
            def P(k,b): return 16*k+b
            for b in range(15,15-L,-1): used[P(0,b)]=True   # prefix
            subpos=[]
            fields=[]  # (opidx, partidx, w)
            if f.xbits: fields.append((-1,0,'x',f.xbits))
            for oi,sp in enumerate(f.specs):
                for pi,(nm,w) in enumerate(sp.parts): fields.append((oi,pi,nm,w))
            place={}  # (oi,pi) -> list of bit positions msb-first
            # sub-op field immediately below prefix in P0 (if j>0)
            free_p0=list(range(15-L,-1,-1))
            lf.subbits=[P(0,b) for b in free_p0[:lf.j]]; 
            free_p0=free_p0[lf.j:]
            for p in lf.subbits: used[p]=True
            # registers: from bit 0 upward, last operand's register lowest
            regparts=[x for x in fields if x[2]=='r'][::-1]
            lowptr=0
            for oi,pi,nm,w in regparts:
                bits=[]
                if lowptr+w<=len(free_p0)+0 and all(not used[P(0,b)] for b in range(lowptr,lowptr+w)):
                    bits=[P(0,b) for b in range(lowptr+w-1,lowptr-1,-1)]; lowptr+=w
                    for x in bits: used[x]=True
                    place[(oi,pi)]=bits
            rest=[]
            for k in range(f.n):
                for b in range(15,-1,-1):
                    if not used[P(k,b)]: rest.append(P(k,b))
            ri=0
            others=[x for x in fields if (x[0],x[1]) not in place]
            # smaller fields first so the widest field (displacement/immediate) ends up last (in the later parcels)
            others=sorted(others,key=lambda x:(x[3]>=8, x[0] if False else 0))
            for oi,pi,nm,w in others:
                place[(oi,pi)]=rest[ri:ri+w]; ri+=w
            assert ri==len(rest),(f.name,ri,len(rest))
            lf.place=place
            # which parcels does each field touch; are registers outside P0?
            lf.regs_out=sum(1 for (oi,pi),bs in place.items() if oi>=0 and f.specs[oi].parts[pi][0]=='r' and any(x>=16 for x in bs))
            lf.straddle=sum(1 for (oi,pi),bs in place.items() if len({x//16 for x in bs})>1)
    def encode(s,mn,ops,vals_by_form):
        pass
def build_word(lf,mn,vals):
    f=lf.form; w=0
    L=lf.L
    w|=lf.prefix<<(15-(L-1)) if False else 0
    # prefix bits at P0[15..16-L]
    w|=lf.prefix<<(16-L)
    k=lf.form.mns.index(mn)-lf.off
    if lf.form.xbits:
        bits=lf.place[(-1,0)]
        for i,pos in enumerate(bits): w|=((k>>(len(bits)-1-i))&1)<<pos
    for i,pos in enumerate(lf.subbits): w|=((k>>(lf.j-1-i))&1)<<pos
    for oi,v in enumerate(vals):
        for pi,x in enumerate(v):
            bits=lf.place[(oi,pi)]; wd=len(bits)
            for i,pos in enumerate(bits): w|=((x>>(wd-1-i))&1)<<pos
    return w
def words_of(w,n): return [(w>>(16*k))&0xFFFF for k in range(n)]
def decode_word(code,parcels):
    """returns (mn, ops, nparcels) or None for an illegal pattern.  parcels: list of 16-bit ints (needs >= n)"""
    lf=code.table[parcels[0]]
    if lf is None: return None
    f=lf.form; n=f.n
    if len(parcels)<n: raise IndexError
    w=0
    for k in range(n): w|=parcels[k]<<(16*k)
    k=0
    if f.xbits:
        for pos in lf.place[(-1,0)]: k=(k<<1)|((w>>pos)&1)
    for i,pos in enumerate(lf.subbits): k=(k<<1)|((w>>pos)&1)
    if k>=len(lf.mns): return None
    mn=lf.mns[k]
    ops=[]
    for oi,sp in enumerate(f.specs):
        v=[]
        for pi in range(len(sp.parts)):
            bits=lf.place[(oi,pi)]; x=0
            for pos in bits: x=(x<<1)|((w>>pos)&1)
            v.append(x)
        op=sp.make(tuple(v),mn)
        if op is None: return None
        ops.append(op)
    return mn,tuple(ops),n
