"""Build the schemes with the optimiser and write them as the hbnf grammars of the encodings (spec/pdp64-enc.hbnf, spec/pdp64-16/pdp64-16.hbnf,
spec/pdp64-32/pdp64-32.hbnf), by write_hbnf.py.  The grammars are the source of truth of the encodings; this is the design tool that writes a new one, and the
optimiser stays the independent oracle (check-enc.py lays the grammar's forms out again with the model enc.py and requires the same bits).  Needs the corpus
(load.py paths).  Nothing builds from the optimiser's data: what it writes is a grammar to review, diff and commit (spec/README.md, "Changing an encoding").

    python3 export_forms.py OUTDIR [--tag16 T --tag32 T] [--rounds N] [--lam B] [--keep-hot]    # corpus-trained, static objective, the four fused pairs; writes the three grammars under OUTDIR
    (tags: load.corpus; PDP64_CORPUS_DIR_<TAG> names the directory of compiled assembly; with the defaults, the original study's corpus)
"""
import sys,os,json,collections
HERE=os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0,HERE)
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
def make_fallback(prev,lam):
    """the cost, in bytes, that a cbCC key has when no cbCC form reaches it: the cmp and the bCC as the previous round's scheme sizes them, and lam bytes for the
    extra instruction (an extra executed instruction, and the flags it writes).  lam=None: the optimiser's first model (99 bytes: a cbCC that no form reaches is
    'unencodable' and every cbCC form is credited with 99-4 bytes)."""
    if lam is None or prev is None: return None
    def fb(mn,ops):
        if not (mn.startswith('cb') and len(ops)==3): return None
        c=prev.size1('cmp',(ops[0],ops[1]))
        tgt=ops[2]; nt=tgt if tgt[1] is None else ('PC',tgt[1]-(c or 0),tgt[2])
        b=prev.size1('b'+mn[2:],(nt,))
        return None if c is None or b is None else c+b+lam
    return fb
def build_one(which,tag,prev=None,lam=2.0,opts=None,hot=None,lenfun=None,budget=0.95,refine=0):
    mns=['movq','movl','add','sub','xor','and','bis','shl']
    if which=='16':
        sc,_=build(tag,reloc='max',fuse=FZ,opts=opts,hot=hot,lenfun=lenfun,fallback=make_fallback(prev,lam),budget=budget,refine=refine)
    else:
        ex=lambda R,H3,H4: [Form('RR5',1,mns,[R,R])]
        sc,_=build(tag,reloc='max',fuse=FZ,extra=ex,opts=opts,hot=hot,lenfun=lenfun,fallback=make_fallback(prev,lam),budget=budget,refine=refine)
    return sc
def committed(which):
    """the scheme of the grammar in spec/ (the previous design), as asm_vs_model.py rebuilds it"""
    import importlib.util,encgram
    spec=importlib.util.spec_from_file_location('chk',os.path.join(HERE,'..','..','..','tools','check-enc.py')); chk=importlib.util.module_from_spec(spec); spec.loader.exec_module(chk)
    d=encgram.load(which)
    sc=Scheme([Form(f['name'],f['n'],f['mns'],[chk.mkspec(s) for s in f['specs']],xbits=f['xbits']) for f in d['forms']])
    return sc,d
def rounds(which,tag,nround=3,lam=2.0,opts=None,hot=None,budget=0.95,log=print,refine=0):
    """the design loop: the distances of round k are those of the layout by round k-1's scheme (round 0: the committed grammar's), so that the reaches are chosen from
    the distances the encoding itself produces; returns the last scheme"""
    prev,d=committed(which)
    if hot is None: hot=d['hot16'] if which=='32' else d['hot8']
    for k in range(nround):
        sc=build_one(which,tag,prev=prev,lam=lam,opts=opts,hot=hot,lenfun=prev.lenfun,budget=budget,refine=refine)
        total,m=measure(sc,tag,fuse=())
        st=m['stats']
        log('round %d  pdp64/%s  bytes %d  forms %d leaves %d kraft %.4f  unencodable %d expanded cbCC %d'%(k,which,total,len(sc.forms),len(sc.code.leaves),sc.code.kraft,st.get('unencodable',0),st.get('expanded_cb',0)))
        prev=sc
    return sc,total,m
def export(which,sc,tag,hot=None):
    dec=decodability(sc)
    nb,bad,nf=boundary_tests(sc)
    assert not bad,bad[:3]
    regs=16 if which=='16' else 32; name='pdp64/'+which
    forms=[]
    fidx={}
    for i,f in enumerate(sc.forms):
        fidx[id(f)]=i
        forms.append(dict(name=f.name,n=f.n,mns=f.mns,xbits=f.xbits,specs=[spec_json(s) for s in f.specs]))
    leaves=[]
    for lf in sc.code.leaves:
        place=[[oi,pi,bits] for (oi,pi),bits in sorted(lf.place.items())]
        leaves.append(dict(form=fidx[id(lf.form)],off=lf.off,j=lf.j,L=lf.L,prefix=lf.prefix,mns=lf.mns,subbits=lf.subbits,place=place))
    c,keys,order,cnt=prep(tag)
    if hot is not None: order=list(hot)+[r for r in order if r not in hot]
    out=dict(name=name,registers=regs,hot8=order[:8],hot16=order[:16] if which=='32' else None,
             fused=list(FZ),forms=forms,leaves=leaves,
             stats=dict(decod={k:v for k,v in dec.items()},boundary=[nb,len(bad),nf]))
    print(name,'kraft',sc.code.kraft,'boundary',nb,len(bad))
    return out
if __name__=='__main__':
    import os,write_hbnf,argparse
    ap=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('outdir'); ap.add_argument('--tag16',default='base16'); ap.add_argument('--tag32',default='r32')
    ap.add_argument('--rounds',type=int,default=1); ap.add_argument('--lam',default='none',help="bytes charged for the extra instruction of a cmp+bCC (none: the 99-byte model)")
    ap.add_argument('--budget',type=float,default=0.95); ap.add_argument('--refine',type=int,default=0,help='passes of local search after the greedy selection')
    ap.add_argument('--cb3',action='store_true',help='offer three-parcel cbCC forms (far targets, wide immediates)')
    ap.add_argument('--keep-hot',action='store_true',help='keep the hot-register tables of the committed grammars (the ABI)')
    a=ap.parse_args()
    lam=None if a.lam=='none' else float(a.lam)
    ds=[]
    for w,tag in (('16',a.tag16),('32',a.tag32)):
        hot=None
        if a.keep_hot:
            _,d0=committed(w); hot=d0['hot16'] if w=='32' else d0['hot8']
        opts=dict(cb3=True) if a.cb3 else None
        if a.rounds>1 or lam is not None or a.keep_hot:
            sc,total,m=rounds(w,tag,a.rounds,lam,opts=opts,hot=hot,budget=a.budget,refine=a.refine)
        else:
            sc=build_one(w,tag,lam=None,opts=opts,budget=a.budget,refine=a.refine)
        ds.append((w,json.loads(json.dumps(export(w,sc,tag,hot),default=str))))
    for w,d in ds: print(d['name'],'forms',len(d['forms']),'leaves',len(d['leaves']),'hot8',d['hot8'],'hot16',d['hot16'])
    os.makedirs(a.outdir,exist_ok=True)
    write_hbnf.write_all(a.outdir,ds)
