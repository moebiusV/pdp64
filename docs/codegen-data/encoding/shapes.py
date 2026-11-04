from load import *
from cur import cur_len
tag=sys.argv[1]
c=corpus(tag)
tot=0
for fn,ev,recs in c: tot+=layout(ev,cur_len)
print(tag,'current total',tot)
cnt=collections.Counter(); byt=collections.Counter()
for fn,ev,recs in c:
    for r in recs:
        key=(r['mn'],tuple(r['k']))
        cnt[key]+=1; byt[key]+=r['len']
N=sum(cnt.values())
H=-sum(v/N*math.log2(v/N) for v in cnt.values()) if False else None
import math
H=-sum(v/N*math.log2(v/N) for v in cnt.values())
print('N',N,'distinct (mn,kinds)',len(cnt),'H bits',H)
for k,v in cnt.most_common(70): print(v,byt[k]/v,k)
