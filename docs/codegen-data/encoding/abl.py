import sys,json,time,collections,pickle
sys.path.insert(0,'.')
from variants import *
import dyn3
def dynB(sc,reloc='max',progs=None):
    old=dyn3.progs
    if progs: dyn3.progs=progs
    try: r=dyn3.measure(sc,sc,reloc)
    finally: dyn3.progs=old
    tot=collections.Counter()
    for p,T in r.items():
        for k in('instr','cur','new16'): tot[k]+=T[k]
    return tot['new16']/tot['instr'],tot['cur']/tot['instr']
out={}
def run(name,tag='base16',reloc='max',dyn=True,**kw):
    t=time.time()
    sc,info=build(tag,reloc=reloc,**kw)
    total,_=measure(sc,tag,do_rt=False)
    d=None
    if dyn and tag=='base16': d=dynB(sc,reloc)[0]
    out[name]=dict(total=total,dyn=d,forms=len(sc.forms),kraft=sc.code.kraft)
    print(name,total,d,len(sc.forms),'%.0fs'%(time.time()-t),flush=True)
    json.dump(out,open('abl.json','w'),indent=1)
if sys.argv[1]=='16':
    run('full')
    run('no 3-bit hot-register one-parcel (R)+d forms',opts=dict(ldh=False))
    run('no one-parcel sp-relative forms',opts=dict(sp1=False))
    run('no one-parcel immediates/shifts/pushm8/spadj',opts=dict(imm1=False))
    run('no compare-with-zero-and-branch (cbz) forms',opts=dict(cbz=False))
    run('no compare-immediate-and-branch (cbi) forms',opts=dict(cbi=False))
    run('no compare-zero and no compare-imm-and-branch',opts=dict(cbz=False,cbi=False))
    run('no scaled-index forms (X) beyond fallback',opts=dict(idx=False))
    run('no PC-relative/absolute narrow forms (fallback only)',opts=dict(pcrel=False))
    run('coarse widths only (W=8,12,16,20,24)',opts=dict(W=(8,12,16,20,24),W2=(4,6,8)))
    run('code space reserve 20% (budget 0.80)',budget=0.80)
    run('code space reserve 1% (budget 0.99)',budget=0.99)
    run('no optional forms at all (framework fallback only)',opts=dict(ldh=False,sp1=False,imm1=False,cbz=False,cbi=False,idx=False,pcrel=False,W=(99,),W2=(99,)))
    run('policy near (linker relaxes externals)',reloc='near')
    run('dynamic-tuned (mix 3)',mix=3.0)
    run('dynamic-tuned (mix 10)',mix=10.0)
else:
    run('A32 full',tag='r32')
    run('A32 no 4-bit hot-register variants (5-bit everywhere)',tag='r32',hot4=False)
    run('A32 no 3-bit hot one-parcel mem forms',tag='r32',opts=dict(ldh=False))
    run('A32 no 4-bit hot variants in two-parcel families',tag='r32',opts=dict(h4mem=False))
    run('A32 no one-parcel imm/shift/pushm',tag='r32',opts=dict(imm1=False))
    run('A32 no cb imm/zero forms',tag='r32',opts=dict(cbz=False,cbi=False))
    run('A32 policy near',tag='r32',reloc='near')
