import sys,time,pickle
from solve import *
from scheme import *
tag=sys.argv[1] if len(sys.argv)>1 else 'base16'
c,keys=build_keys(tag)
order,cnt=hot_tables(c)
forced,_=mk(SR(4),SR(3,order[:8]))
cs=cands(SR(4),SR(3,order[:8]))
forms,best,tot,used,unenc=solve(forced,cs,keys,0.95,verbose=False)
sc=Scheme(forced+forms)
print('forms',len(sc.forms),'kraft',sc.code.kraft)
t=time.time()
corp=corpus(tag)
total,stats,sizes,useform,bad=roundtrip(sc,corp)
print('relaxed total bytes',total,'%.1fs'%(time.time()-t))
print(stats); print(sizes); print(bad[:5]); print('unencodable shapes',sc.fail.most_common(10))
