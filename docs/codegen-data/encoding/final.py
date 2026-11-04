import sys,json,time,collections
sys.path.insert(0,'.')
from variants import *
from proof import *
import dyn3
from tables import dump
FZ=('movcall','popmret','popret','mov2')
CF={'A16':dict(tag='base16',mix=0.0,fuse=()),'B16':dict(tag='base16',mix=3.0,fuse=()),'C16':dict(tag='base16',mix=3.0,fuse=FZ),
    'A32':dict(tag='r32',mix=0.0,fuse=()),'C32':dict(tag='r32',mix=0.0,fuse=FZ)}
PAIR={'A16':'A32','B16':'A32','C16':'C32'}
out={}
for reloc in ('max','near'):
    S_={}
    for name,c in CF.items():
        t=time.time()
        sc,info=build(c['tag'],reloc=reloc,mix=c['mix'],fuse=c['fuse'])
        total,d=measure(sc,c['tag'],fuse=c['fuse'])
        dec=decodability(sc)
        nb,bad,nf=boundary_tests(sc)
        npr,miss=coverage(sc)
        st=d['stats']
        cur=cur_total(c['tag'],reloc)
        S_[name]=sc
        nh=st['checked']
        sz=d['sizes']
        out[f'{name}/{reloc}']=dict(total=total,today_same_corpus=cur,today16=cur_total('base16',reloc),checked=nh,mismatch=st.get('mismatch',0),illegal=st.get('decode_illegal',0),
            unencodable=st.get('unencodable',0),expanded_cb=st.get('expanded_cb',0),asm_instr=st['asm_instr'],fused_pairs=d['fused_pairs'],sizes={str(k):v for k,v in sz.items()},
            longest_bytes=2*max(sz),mean_bytes=total/nh,forms=len(sc.forms),leaves=dec['leaves'],decod={str(k):(v if not isinstance(v,dict) else {str(a):b for a,b in v.items()}) for k,v in dec.items()},boundary=(nb,len(bad),nf),probe=(npr,sum(miss.values()),{str(k):v for k,v in miss.items()}),
            fail={str(k):v for k,v in sc.fail.items()},bad=str(d['bad']))
        if reloc=='max': dump(sc,f'tables-{name}.md',f'{name} ({c["tag"]}, mix={c["mix"]}, fuse={c["fuse"]})')
        print(reloc,name,total,'vs today(same corpus,%s) %d'%(c['tag'],cur),'checked',nh,'mismatch',st.get('mismatch',0),'boundary',nb,len(bad),'probe miss',sum(miss.values()),'%.0fs'%(time.time()-t),flush=True)
    for a,b in PAIR.items():
        f=CF[a]['fuse']
        r=dyn3.measure(S_[a],S_[b],reloc,fuse=f)
        tot=collections.Counter()
        for p,T in r.items():
            for k in('instr','cur','new16','hw16','new32','i32'): tot[k]+=T[k]
        out[f'dyn:{a}+{b}/{reloc}']=dict(tot=dict(tot),per={p:{k:v for k,v in T.items() if k!='lens'} for p,T in r.items()},lens={p:T['lens'] for p,T in r.items()})
        N=tot['instr']
        print(reloc,'dyn',a,b,'today %.3f new16 %.3f new32 %.3f'%(tot['cur']/N,tot['new16']/N,tot['new32']/N),flush=True)
    json.dump(out,open('final.json','w'),indent=1,default=str)
