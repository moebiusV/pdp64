from norm import *
from cur import cur_len
import math
tag=sys.argv[1]; c=corpus(tag)
for fn,ev,recs in c: layout(ev,cur_len)
H=collections.defaultdict(collections.Counter)
def bl(v):  # bit length signed
    return (v if v>=0 else ~v).bit_length()+1
for fn,ev,recs in c:
    for r in recs:
        mn,ops=inst_of(r,r['dist'])
        for o in ops:
            if o[0]=='PC':
                key=('pc',mn if mn in('call','lea','jmp') else ('cb' if mn.startswith('cb') else 'br' if (mn=='br' or isbr(mn)) else mn))
                if o[1] is None: H[key]['ext']+=1
                else: H[key][bl(o[1]//2)]+=1
            elif o[0]=='I':
                H[('imm',mn)][bl(o[1])]+=1
            elif o[0]=='B':
                sz=SIZE.get(mn,1)
                d=o[1]; 
                H[('B',mn, 'sp' if o[2]==14 else 'r')][('aligned' if d%sz==0 else 'unal', bl(d//sz) if d>=0 else -bl(d//sz))]+=1
for k in sorted(H,key=lambda k:-sum(H[k].values()))[:60]:
    print(k,sum(H[k].values()),sorted(H[k].items(),key=lambda x:str(x[0]))[:24])
