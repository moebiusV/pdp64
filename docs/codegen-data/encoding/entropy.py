import sys,math,collections,json
from solve import *
tag=sys.argv[1]
c,keys=build_keys(tag)
N=sum(keys.values())
def H(cnt):
    t=sum(cnt.values()); return -sum(v/t*math.log2(v/t) for v in cnt.values()) if t else 0
def bl(v): return (v if v>=0 else ~v).bit_length()+1
sym=collections.Counter(); regs=collections.defaultdict(collections.Counter); num=collections.defaultdict(collections.Counter)
mant=collections.Counter(); extbits=0; ext=0
for (mn,ops),n in keys.items():
    kd=tuple(o[0] for o in ops)
    sym[(mn,kd)]+=n
    lastR=max([i for i,o in enumerate(ops) if o[0]=='R'],default=-1)
    for i,o in enumerate(ops):
        if o[0]=='R': regs['dst' if i==lastR and len(ops)>1 else 'src'][o[1]]+=n
        elif o[0]=='B':
            regs['base'][o[2]]+=n; sc=msize(mn); d=o[1]
            q=d//sc if d%sc==0 else d; b=bl(q); num[(mn,'B')][b]+=n; mant[(mn,'B')]+=n*(b-1)
        elif o[0]=='X':
            regs['base'][o[2]]+=n; regs['idx'][o[3]]+=n; num[(mn,'X')][bl(o[1])]+=n; mant[(mn,'X')]+=n*(bl(o[1])-1); num[(mn,'Xs')][o[4]]+=n
        elif o[0] in('PI','PD'): regs['base'][o[1]]+=n; num[(mn,o[0])][bl(o[2])]+=n; mant[(mn,o[0])]+=n*(bl(o[2])-1)
        elif o[0]=='I':
            b=bl(o[1]); num[(mn,'I')][b]+=n; mant[(mn,'I')]+=n*(b-1)
        elif o[0]=='PC':
            if o[1] is None: ext+=n; num[(mn,'PC')]['ext']+=n
            else:
                b=bl(o[1]//2); num[(mn,'PC')][b]+=n; mant[(mn,'PC')]+=n*(b-1)
        elif o[0]=='A': num[(mn,'A')]['x']+=n; extbits+=n*32
Hs=H(sym)
Hr=sum(H(c)*sum(c.values()) for c in regs.values())/N
Hn=sum(H(c)*sum(c.values()) for c in num.values())/N
Mm=sum(mant.values())/N
Ex=ext*32/N
print(tag,'N',N)
print('H(mnemonic,operand shape) = %.3f bits'%Hs)
print('registers (order-0 per role) = %.3f bits'%Hr)
print('number class (bit-length bucket given mnemonic) = %.3f bits'%Hn)
print('number mantissa (uniform within bucket)         = %.3f bits'%Mm)
print('unresolved external reference payload (32 bit)  = %.3f bits (%d refs)'%(Ex,ext))
tot=Hs+Hr+Hn+Mm
print('TOTAL bound, externals free (near) = %.3f bits = %.3f bytes/instr = %d bytes'%(tot,tot/8,tot/8*N))
print('TOTAL bound, externals 32-bit (max) = %.3f bits = %.3f bytes/instr = %d bytes'%(tot+Ex,(tot+Ex)/8,(tot+Ex)/8*N))
# parcel-rounded bound: each instruction's ideal code length rounded up to whole parcels
def P(cnt,x): return cnt[x]/sum(cnt.values())
psym={k:v/N for k,v in sym.items()}
tot_r=0; tot_r_near=0
for (mn,ops),n in keys.items():
    kd=tuple(o[0] for o in ops)
    b=-math.log2(psym[(mn,kd)]); bn=b
    lastR=max([i for i,o in enumerate(ops) if o[0]=='R'],default=-1)
    for i,o in enumerate(ops):
        if o[0]=='R': b+=-math.log2(P(regs['dst' if i==lastR and len(ops)>1 else 'src'],o[1]))
        elif o[0]=='B':
            sc=msize(mn); d=o[1]; q=d//sc if d%sc==0 else d; bb=bl(q)
            b+=-math.log2(P(regs['base'],o[2]))-math.log2(P(num[(mn,'B')],bb))+bb-1
        elif o[0]=='X':
            b+=-math.log2(P(regs['base'],o[2]))-math.log2(P(regs['idx'],o[3]))-math.log2(P(num[(mn,'Xs')],o[4]))-math.log2(P(num[(mn,'X')],bl(o[1])))+bl(o[1])-1
        elif o[0] in('PI','PD'): b+=-math.log2(P(regs['base'],o[1]))-math.log2(P(num[(mn,o[0])],bl(o[2])))+bl(o[2])-1
        elif o[0]=='I': bb=bl(o[1]); b+=-math.log2(P(num[(mn,'I')],bb))+bb-1
        elif o[0]=='PC':
            if o[1] is None: b+=-math.log2(P(num[(mn,'PC')],'ext'))+32
            else: bb=bl(o[1]//2); b+=-math.log2(P(num[(mn,'PC')],bb))+bb-1
        elif o[0]=='A': b+=32
    tot_r+=n*16*math.ceil(b/16-1e-9)
print('PARCEL-ROUNDED bound (ideal order-0 code, rounded up to 16-bit parcels), externals 32-bit: %d bytes'%(tot_r/8))
