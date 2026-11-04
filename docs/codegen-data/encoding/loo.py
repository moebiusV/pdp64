import sys,json,pickle,collections
sys.path.insert(0,'.')
from variants import *
import dyn3
dk,per=pickle.load(open(S+'/dynkeys.pkl','rb'))
c,keys,order,cnt=prep('base16')
out={}
for p in dyn3.progs:
    rest=collections.Counter()
    for q,v in per.items():
        if q!=p: rest.update(v)
    lam=3.0*sum(keys.values())/sum(rest.values())
    W=collections.Counter()
    for k,n in keys.items(): W[k]+=n
    for k,n in rest.items(): W[k]+=lam*n
    enc.RELOC='max'
    R=SR(4); H3=SR(3,order[:8]); forced,_=mk(R,H3)
    cs=cands(R,H3)
    forms,best,tot,used,unenc=solve(forced,cs,collections.Counter(W),0.95,weights=W,verbose=False)
    sc=Scheme(forced+forms)
    old=dyn3.progs; dyn3.progs=[p]
    r=dyn3.measure(sc,sc,'max'); dyn3.progs=old
    T=r[p]; out[p]=T['new16']/T['instr']
    print(p,'leave-one-out %.3f'%out[p],flush=True)
json.dump(out,open('loo.json','w'))
