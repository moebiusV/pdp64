import sys,collections
from variants import *
tag=sys.argv[1] if len(sys.argv)>1 else 'base16'
c,keys,order,cnt=prep(tag)
hot8=set(order[:8])
corp=corpus(tag)
P=collections.Counter(); N=0
for fn,ev,recs in corp:
    prev=None
    for e in ev:
        if e[0]!='I': prev=None; continue
        r=e[1]; mn,ops=inst_of(r,0); N+=1
        if prev is not None:
            pm,po=prev
            if pm=='movq' and po[0][0]=='R' and po[1][0]=='R':
                if mn=='call': P['movq r,r ; call']+=1
                if mn=='movq' and ops[0][0]=='R' and ops[1][0]=='R':
                    P['movq r,r ; movq r,r']+=1
                    if all(o[1] in hot8 for o in po+ops): P['  ... all four registers in the hot 8']+=1
                    if all(o[1]<16 for o in po+ops) : P['  ... all four registers in r0-r15']+=1
            if pm=='popm' and mn=='ret': P['popm ; ret']+=1
            if pm=='pop' and mn=='ret': P['pop r ; ret']+=1
            if pm=='movq' and po[0][0]=='I' and mn=='ret': P['movq #imm,r ; ret']+=1
            if pm=='clr' and mn=='ret': P['clr r ; ret']+=1
            if pm=='movq' and po[0][0]=='I' and mn=='call': P['movq #imm,r ; call']+=1
            if pm=='lea' and po[0][0]=='B' and mn=='call': P['lea d(rn),r ; call']+=1
            if pm=='call' and mn=='ret': P['call ; ret (tail call)']+=1
            if pm=='movq' and po[0][0]=='R' and mn=='br': P['movq r,r ; br']+=1
            if pm=='clr' and mn=='br': P['clr r ; br']+=1
            if pm=='movq' and po[0][0]=='I' and mn=='br': P['movq #imm,r ; br']+=1
        prev=(mn,ops)
print(tag,'instructions',N)
for k,v in P.most_common(): print(v,k,'(%.2f%% of instructions, %d bytes if each saves 2)'%(100*v/N,2*v))
