import copy
from norm import *
def fuse_events(ev,which):
    """merge adjacent instruction pairs (no label or data between) into pseudo records 'fx_*' whose plan() chooses fused or separate"""
    out=[]; i=0; n=0
    def isreg(r,i_): return r['k'][i_]=='reg'
    while i<len(ev):
        e=ev[i]
        if e[0]=='I' and i+1<len(ev) and ev[i+1][0]=='I':
            a=e[1]; b=ev[i+1][1]; r=None
            if 'movcall' in which and a['mn']=='movq' and a['k']==['reg','reg'] and b['mn']=='call' and b['k']==['pcrel']:
                r=dict(b); r['mn']='fx_movcall'; r['ops']=a['ops']+b['ops']; r['k']=a['k']+b['k']
            elif 'popmret' in which and a['mn']=='popm' and b['mn']=='ret': r=dict(a); r['mn']='fx_popmret'
            elif 'popret' in which and a['mn']=='pop' and a['k']==['reg'] and b['mn']=='ret': r=dict(a); r['mn']='fx_popret'
            elif 'mov2' in which and a['mn']=='movq' and a['k']==['reg','reg'] and b['mn']=='movq' and b['k']==['reg','reg']:
                r=dict(a); r['mn']='fx_mov2'; r['ops']=a['ops']+b['ops']; r['k']=a['k']+b['k']
            if r is not None:
                r['pos']=0; r['cnt']=a.get('cnt',0); r['curlen']=a.get('curlen',0)+b.get('curlen',0); r['ninstr']=2; out.append(('I',r)); i+=2; n+=1; continue
        out.append(e); i+=1
    return out,n
def fuse_corpus(corp,which):
    res=[]; tot=0
    for fn,ev,recs in corp:
        ev2,n=fuse_events(ev,which); tot+=n
        res.append((fn,ev2,[e[1] for e in ev2 if e[0]=='I']))
    return res,tot
