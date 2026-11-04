"""Build one scheme with the optimiser and write it as a machine-readable forms table (the single source of truth of an
encoding: spec/pdp64-16/forms.json, spec/pdp64-32/forms.json).  Needs the corpus (load.py paths) and is run once per revision of the scheme;
everything downstream (tools/mkenc.py, the codec, as64, ld64) reads only the JSON.

    python3 export_forms.py 16 out.json      # A16 + the four fused pairs (corpus-trained, static objective)
    python3 export_forms.py 32 out.json      # A32r + the four fused pairs
"""
import sys,json,collections
sys.path.insert(0,'.')
from variants import *
from proof import decodability,boundary_tests
import enc
FZ=('movcall','popmret','popret','mov2')
def spec_json(sp):
    if isinstance(sp,SR): return dict(k='R',w=sp.w,table=list(sp.table) if sp.table is not None else None)
    if isinstance(sp,SK): return dict(k='K',op=list(sp.op))
    if isinstance(sp,SI): return dict(k='I',w=sp.w,signed=sp.signed,scale=sp.scale,vals=sp.vals)
    if isinstance(sp,SB): return dict(k='B',rn=spec_json(sp.rn),dw=sp.dw,signed=sp.signed,scale=sp.scale)
    if isinstance(sp,SX): return dict(k='X',rn=spec_json(sp.rn),rx=spec_json(sp.rx),dw=sp.dw,signed=sp.signed)
    if isinstance(sp,SP): return dict(k=sp.kind_,rn=spec_json(sp.rn),dw=sp.dw)
    if isinstance(sp,SPC): return dict(k='PC',w=sp.w,unit=sp.unit)
    if isinstance(sp,SA): return dict(k='A',w=sp.w)
    raise TypeError(sp)
def export(which,path):
    mns=['movq','movl','add','sub','xor','and','bis','shl']
    if which=='16':
        sc,_=build('base16',reloc='max',fuse=FZ); regs=16; name='pdp64/16'
    else:
        ex=lambda R,H3,H4: [Form('RR5',1,mns,[R,R])]
        sc,_=build('r32',reloc='max',fuse=FZ,extra=ex); regs=32; name='pdp64/32'
    dec=decodability(sc)
    nb,bad,nf=boundary_tests(sc)
    assert not bad,bad[:3]
    forms=[]
    fidx={}
    for i,f in enumerate(sc.forms):
        fidx[id(f)]=i
        forms.append(dict(name=f.name,n=f.n,mns=f.mns,xbits=f.xbits,specs=[spec_json(s) for s in f.specs]))
    leaves=[]
    for lf in sc.code.leaves:
        place=[[oi,pi,bits] for (oi,pi),bits in sorted(lf.place.items())]
        leaves.append(dict(form=fidx[id(lf.form)],off=lf.off,j=lf.j,L=lf.L,prefix=lf.prefix,mns=lf.mns,subbits=lf.subbits,place=place))
    import pickle
    c,keys,order,cnt=prep('base16' if which=='16' else 'r32')
    out=dict(name=name,registers=regs,hot8=order[:8],hot16=order[:16] if which=='32' else None,
             fused=list(FZ),forms=forms,leaves=leaves,
             stats=dict(decod={k:v for k,v in dec.items()},boundary=[nb,len(bad),nf]))
    json.dump(out,open(path,'w'),indent=0,default=str)
    print(name,'forms',len(forms),'leaves',len(leaves),'kraft',sc.code.kraft,'boundary',nb,len(bad),'hot8',order[:8],'hot16',order[:16])
if __name__=='__main__': export(sys.argv[1],sys.argv[2])
