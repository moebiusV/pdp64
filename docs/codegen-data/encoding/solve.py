import sys,heapq,collections,time,json,pickle
from norm import *
from cur import cur_len
import enc
from cat import *
def build_keys(tag):
    c=corpus(tag)
    for fn,ev,recs in c: layout(ev,cur_len)
    keys=collections.Counter()
    for fn,ev,recs in c:
        for r in recs:
            mn,ops=inst_of(r,r['dist'])
            keys[(mn,ops)]+=1
    return c,keys
def hot_tables(c):
    cnt=collections.Counter()
    for fn,ev,recs in c:
        for r in recs:
            mn,ops=inst_of(r,0)
            for o in ops:
                if o[0]=='R': cnt[o[1]]+=1
                elif o[0] in('B','PI','PD'): cnt[o[2] if o[0]=='B' else o[1]]+=1
                elif o[0]=='X': cnt[o[2]]+=1; cnt[o[3]]+=1
    order=[r for r,_ in cnt.most_common()]
    return order,cnt
def cover(order,cnt,k):
    tot=sum(cnt.values()); return sum(cnt[r] for r in order[:k])/tot
def solve(forced,cands,keys,budget,weights=None,verbose=True,alphas=(0.8,0.9,1.0,1.1,1.25)):
    """greedy: choose whole (form,mnemonic-class) leaves by weighted bytes saved per unit of code space"""
    W=weights if weights is not None else keys
    groups=collections.defaultdict(list)
    for (mn,ops),n in keys.items():
        groups[(mn,tuple(o[0] for o in ops))].append(((mn,ops),W.get((mn,ops),0)))
    best={}; unenc=collections.Counter()
    for (mn,ops),n in keys.items():
        b=None; kd=tuple(o[0] for o in ops)
        for f in forced:
            if mn in f._mnset() and f.kinds==kd and f.fit(mn,ops) is not None:
                bb=2*f.n
                if b is None or bb<b: b=bb
        if b is None: unenc[(mn,kd)]+=n; b=99
        best[(mn,ops)]=b
    used=sum(f.kraft() for f in forced)
    atoms=[]; t=time.time()
    for ci,f in enumerate(cands):
        hits=[]
        for m in f.mns:
            for k,n in groups.get((m,f.kinds),()):
                if f.fit(m,k[1]) is not None: hits.append((k,n))
        if hits: atoms.append((ci,hits))
    if verbose: print('atoms',len(atoms),'in %.0fs'%(time.time()-t),'forced kraft %.4f'%used,'unencodable-by-forced keys',sum(unenc.values()),flush=True)
    def run(alpha):
        best2=dict(best); used2=used; chosen=[]
        def gain(a):
            by=2*cands[a[0]].n
            return sum(n*(best2[k]-by) for k,n in a[1] if best2[k]>by)
        pr=lambda g,ci: g/cands[ci].kraft()**alpha
        heap=[]
        for i,a in enumerate(atoms):
            g=gain(a)
            if g>0: heap.append((-pr(g,a[0]),i))
        heapq.heapify(heap)
        while heap:
            negr,i=heapq.heappop(heap)
            a=atoms[i]; g=gain(a)
            if g<=0: continue
            r=pr(g,a[0])
            if heap and r < -heap[0][0]-1e-9:
                heapq.heappush(heap,(-r,i)); continue
            cost=cands[a[0]].kraft()
            if used2+cost>budget: continue
            used2+=cost; by=2*cands[a[0]].n
            for k,n in a[1]:
                if by<best2[k]: best2[k]=by
            chosen.append((a[0],g))
        return sum(n*best2[k] for k,n in keys.items() if best2[k]<99),best2,chosen,used2
    res=[run(al) for al in alphas]
    tot_,best,chosen,used=min(res,key=lambda r:r[0])
    if verbose: print('alpha totals',[r[0] for r in res])
    forms=[cands[ci] for ci,g in chosen]
    tot=sum(n*best[k] for k,n in keys.items() if best[k]<99)
    return forms,best,tot,used,unenc
if __name__=='__main__':
    tag=sys.argv[1]
    c,keys=build_keys(tag)
    print('keys',len(keys),'instructions',sum(keys.values()))
    order,cnt=hot_tables(c); print('hot8 cover',cover(order,cnt,8),'hot16',cover(order,cnt,16),order[:16])
    forced,_=mk(SR(4),SR(3,order[:8]))
    cs=cands(SR(4),SR(3,order[:8]))
    forms,best,tot,used,unenc=solve(forced,cs,keys,0.95)
    print('total bytes (approx, dist from current layout)',tot,'kraft',used,'forms',len(forms))
    left=collections.Counter()
    for k,n in keys.items():
        if best[k]>=99: left[(k[0],tuple(o[0] for o in k[1]))]+=n
    print('still unencoded after selection:',sum(left.values()),left.most_common(8))
    cost=collections.defaultdict(lambda:[0,0])
    for k,n in keys.items():
        if best[k]<99:
            kk=k[0] if not k[0].startswith('cb') else 'cb*'
            cost[kk][0]+=n; cost[kk][1]+=n*best[k]
    for k,v in sorted(cost.items(),key=lambda x:-x[1][1])[:20]: print(k,v,round(v[1]/v[0],2))
    for f in forms: print(f.name,f.n,len(f.mns),f.Lleaf,' '.join(f.mns))
