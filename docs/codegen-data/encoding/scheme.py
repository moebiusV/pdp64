import sys,collections,struct,math
from norm import *
import enc
from enc import *
class Scheme:
    def __init__(s,forms,name=''):
        s.name=name; s.forms=forms; s.code=Code(forms)
        s.by_mn=collections.defaultdict(list)
        for i,f in enumerate(forms):
            for m in f.mns: s.by_mn[m].append((f.n,i,f))
        for m in s.by_mn: s.by_mn[m].sort(key=lambda x:(x[0],x[1]))
        s.memo={}; s.use=collections.Counter(); s.fail=collections.Counter()
    def choose(s,mn,ops):
        k=(mn,ops,enc.RELOC)
        r=s.memo.get(k,0)
        if r!=0: return r
        res=None
        kd=tuple(o[0] for o in ops)
        for n,i,f in s.by_mn.get(mn,()):
            if f.kinds!=kd: continue
            v=f.fit(mn,ops)
            if v is not None: res=(f,v); break
        s.memo[k]=res; return res
    def size1(s,mn,ops):
        r=s.choose(mn,ops)
        return None if r is None else 2*r[0].n
    def plan(s,mn,ops):
        """list of (mn,ops,kind) hardware instructions for one assembler instruction; None if unencodable"""
        if mn.startswith('fx_'):
            return s.plan_fx(mn,ops)
        if s.choose(mn,ops) is not None: return [(mn,ops)]
        if mn.startswith('cb') and len(ops)==3:
            cmp_=('cmp',(ops[0],ops[1])); l1=s.size1(*cmp_)
            if l1 is None: return None
            tgt=ops[2]
            if tgt[1] is None: nt=tgt
            else: nt=('PC',tgt[1]-l1,tgt[2])
            b=('b'+mn[2:],(nt,))
            if s.size1(*b) is None: return None
            return [cmp_,b]
        return None
    def plan_fx(s,mn,ops):
        sep=None
        if mn=='fx_movcall':
            sep=[('movq',ops[:2])]; l1=s.size1(*sep[0])
            tg=ops[2]; nt=tg if tg[1] is None else ('PC',tg[1]-l1,tg[2])
            sep.append(('call',(nt,))); fused=('movcall',ops)
        elif mn=='fx_popmret': sep=[('popm',ops),('ret',())]; fused=('popmret',ops)
        elif mn=='fx_popret': sep=[('pop',ops),('ret',())]; fused=('popret',ops)
        elif mn=='fx_mov2': sep=[('movq',ops[:2]),('movq',ops[2:])]; fused=('mov2',ops)
        ss=[s.size1(*x) for x in sep]
        if None in ss: return None
        fz=s.size1(*fused) if fused[0] in s.by_mn else None
        if fz is not None and fz<sum(ss): return [fused]
        return sep
    def lenfun(s,r,dist):
        mn,ops=inst_of(r,dist)
        p=s.plan(mn,ops)
        if p is None:
            s.fail[(mn,tuple(o[0] for o in ops))]+=1
            return 8   # unencodable: charge 8 bytes (reported separately)
        return sum(s.size1(m,o) for m,o in p)
def pseudo(i):
    return (((i*2654435761)>>3)%(1<<29)-(1<<28))&~1
def encode_stream(sc,plan_list,counter):
    out=[]
    for mn,ops in plan_list:
        r=sc.choose(mn,ops)
        # resolve unresolved externals to pseudo values (even), keep field fit
        f,vals=r
        nops=[]
        for o in ops:
            if o[0]=='PC' and o[1] is None:
                counter[0]+=1; o=('PC',pseudo(counter[0]) if enc.RELOC=='max' else 0)+o[2:]
            if o[0]=='A' and o[1] is None:
                counter[0]+=1; o=('A',pseudo(counter[0]) if enc.RELOC=='max' else 0)
            nops.append(o)
        nops=tuple(nops)
        if nops!=ops:
            vals=f.fit(mn,nops)
            if vals is None: raise RuntimeError('reloc pseudo value does not fit the form %s %s'%(mn,ops))
        lf=None
        # find leaf of this form containing mn
        for l in sc.code.leaves:
            if l.form is f and mn in l.mns: lf=l; break
        w=build_word(lf,mn,vals)
        out.append((mn,nops,words_of(w,f.n)))
    return out
def roundtrip(sc,corp,progress=True):
    stats=collections.Counter(); bad=[]; sizes=collections.Counter(); useform=collections.Counter()
    total=0
    for fn,ev,recs in corp:
        total+=layout(ev,sc.lenfun)
        plans=[]; ctr=[0]
        stream=[]
        for r in recs:
            mn,ops=inst_of(r,r['dist'])
            p=sc.plan(mn,ops)
            stats['asm_instr']+=1
            if p is None: stats['unencodable']+=1; continue
            if len(p)>1: stats['expanded_cb']+=1
            for m,o in p: stats['hw_instr']+=1
            plans+=p
        enc_=encode_stream(sc,plans,ctr)
        par=[]
        for mn,nops,ws in enc_: par+=ws
        # decode the whole stream sequentially
        i=0; j=0
        while i<len(par):
            d=decode_word(sc.code,par[i:i+6]) if False else None
            lf=sc.code.table[par[i]]
            if lf is None: stats['decode_illegal']+=1; bad.append(('illegal',enc_[j])); break
            n=lf.form.n
            d=decode_word(sc.code,par[i:i+n])
            mn,nops,ws=enc_[j]
            stats['checked']+=1; sizes[n]+=1; useform[lf.form.name]+=1
            if d is None or d[0]!=mn or tuple(o[:2] if o[0]=='PC' else o for o in nops)!=d[1] or d[2]!=len(ws):
                stats['mismatch']+=1
                if len(bad)<20: bad.append((mn,nops,d))
            i+=n; j+=1
        if j!=len(enc_): stats['stream_len_mismatch']+=1
    return total,stats,sizes,useform,bad
