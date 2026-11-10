import sys,time,json,pickle,collections
import enc
from solve import *
from scheme import *
from cur import cur_len
import os; S=os.environ.get('PDP64_SCRATCH','/tmp/pdp64-scratch')+'/enc'
_cache={}
def prep(tag,lenfun=None):
    if tag in _cache and lenfun is None: return _cache[tag]
    c,keys=build_keys(tag,lenfun); order,cnt=hot_tables(c)
    if lenfun is None: _cache[tag]=(c,keys,order,cnt)
    return (c,keys,order,cnt)
def build(tag,opts=None,reloc='max',budget=0.95,weights=None,hot4=True,hot3n=8,rbits=None,verbose=False,mix=0.0,fuse=(),extra=None,lenfun=None,fallback=None,hot=None,refine=0):
    c,keys,order,cnt=prep(tag,lenfun)
    if hot is not None:
        assert set(hot[:8])==set(order[:8]) and (len(hot)<16 or set(hot[:16])==set(order[:16])),'the fixed hot tables are not the corpus hot sets'
        order=list(hot)+[r for r in order if r not in hot]
    if mix:
        dk,per=pickle.load(open(S+'/dynkeys.pkl','rb'))
        lam=mix*sum(keys.values())/sum(dk.values())
        W=collections.Counter()
        for k,n in keys.items(): W[k]+=n
        for k,n in dk.items(): W[k]+=lam*n
        keys=collections.Counter(W); weights=W
    enc.RELOC=reloc
    rb=rbits or (5 if tag.endswith('32') else 4)
    H3=SR(3,order[:hot3n]) if hot3n else SR(3,order[:8])
    if rb==5:
        R=SR(5); H4=SR(4,order[:16]) if hot4 else None
    else: R=SR(4); H4=None
    forced,_=mk(R,H3,H4 if rb==5 else None)
    forced=forced+fused_forms(R,H3,fuse)
    if extra: forced=forced+extra(R,H3,H4 if rb==5 else None)
    cs=cands(R,H3,H4,opts)
    forms,best,tot,used,unenc=solve(forced,cs,keys,budget,weights=weights,verbose=verbose,fallback=fallback,refine=refine)
    sc=Scheme(forced+forms)
    return sc,dict(approx=tot,used=used)
def measure(sc,tag,do_rt=True,fuse=()):
    corp=corpus(tag)
    nfz=0
    if fuse:
        from fuse import fuse_corpus
        corp,nfz=fuse_corpus(corp,fuse)
    if do_rt:
        total,stats,sizes,useform,bad=roundtrip(sc,corp)
        return total,dict(fused_pairs=nfz,stats=dict(stats),sizes=dict(sizes),useform=useform,bad=bad[:3],fail=dict(sc.fail))
    total=sum(layout(ev,sc.lenfun) for fn,ev,recs in corp)
    return total,{}
def cur_total(tag,reloc):
    corp=corpus(tag)
    if reloc=='near':
        f=lambda r,d: cur_len(r,0 if d is None else d)
    else: f=cur_len
    return sum(layout(ev,f) for fn,ev,recs in corp)
if __name__=='__main__':
    tag=sys.argv[1]; reloc=sys.argv[2]
    t=time.time()
    print('today',tag,reloc,cur_total(tag,reloc))
    sc,info=build(tag,reloc=reloc)
    total,d=measure(sc,tag)
    print(tag,reloc,'new',total,d['stats'],'forms',len(sc.forms),'kraft %.4f'%sc.code.kraft,'%.0fs'%(time.time()-t))
