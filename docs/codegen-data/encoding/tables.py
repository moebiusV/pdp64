import sys
def fieldpos(lf):
    f=lf.form; out=[]
    def rng(bits):
        # bits msb-first absolute positions -> 'p0[7:4]' pieces
        parts=[]; cur=[]
        for b in bits:
            if cur and (b//16!=cur[-1]//16 or b!=cur[-1]-1): parts.append(cur); cur=[]
            cur.append(b)
        if cur: parts.append(cur)
        return '+'.join('p%d[%d:%d]'%(c[0]//16,c[0]%16,c[-1]%16) if len(c)>1 else 'p%d[%d]'%(c[0]//16,c[0]%16) for c in parts)
    pn=['r','r']
    for (oi,pi),bits in sorted(lf.place.items(),key=lambda kv:-max(kv[1])):
        if oi<0: nm='subop'
        else:
            sp=f.specs[oi]; nm='op%d.%s'%(oi+1,sp.parts[pi][0])
        out.append('%s=%s'%(nm,rng(bits)))
    return out
def dump(sc,path,title):
    L=sorted(sc.code.leaves,key=lambda l:(l.form.n,l.L,l.idx if hasattr(l,'idx') else 0))
    with open(path,'w') as f:
        f.write('# %s\n\nLeaves (prefix-coded groups of mnemonics). prefix = top L bits of parcel 0. `subop` selects the mnemonic inside the group (binary-aligned).\n\n'%title)
        f.write('| parcels | form | L | prefix (P0 top bits) | mnemonics | fields (bit positions) |\n|---|---|---|---|---|---|\n')
        for lf in L:
            pre=format(lf.prefix,'0%db'%lf.L)
            f.write('| %d | %s | %d | %s | %s | %s |\n'%(lf.form.n,lf.form.name,lf.L,pre,' '.join(lf.mns),' '.join(fieldpos(lf))))
