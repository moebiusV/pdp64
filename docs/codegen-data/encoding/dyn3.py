import sys,os,json,collections,pickle
sys.dont_write_bytecode=True
S='/tmp/claude-1000/-home-david-claude-pdp64/c8eb5fe9-a8c9-4e79-aafa-1502bfe6a13e/scratchpad'
sys.path.insert(0,S+'/dyn'); sys.path.insert(0,S+'/fit')
import dynlib as L
from norm import *
from cur import cur_len
import enc
W=L.W
progs=['lz4','zlib','bs_hash','bs_sym','bs_ec','lua']
def units_of(p):
    res=json.load(open(f'{W}/res/{p}.json'))
    units=[]
    for f in res['funcs']:
        if f['unit'] not in units: units.append(f['unit'])
    if p=='bs_ec':
        i=units.index('bearssl_ec_prime_i31.c.c')+1; units[i:i]=['bearssl_ec_secp256r1.c.c','bearssl_ec_secp384r1.c.c','bearssl_ec_secp521r1.c.c']
    return units
def load(p):
    units=units_of(p)
    objs=[L.RT+'/crt.o']+[(f'{W}/o/{u}.s.o' if os.path.exists(f'{W}/o/{u}.s.o') else f'{W}/o_s16/{u}.s.o') for u in units if u!='crt.s']
    bases=L.text_bases(objs)
    steps,cnt=L.load_prof(f'{W}/x/{p}.prof')
    return units,objs,bases,cnt
def dyn_keys():
    """executed (mnemonic, operands) counts with the current layout's distances; and total instructions"""
    out=collections.Counter(); per={}
    for p in progs:
        units,objs,bases,cnt=load(p)
        pk=collections.Counter()
        for ui,u in enumerate(units):
            sp=(L.RT+'/crt.s') if u=='crt.s' else f'{W}/s16/{u}.s'
            ev,recs=parse(sp)
            cr,fn,ok,sz=L.scan_s(sp,objs[ui])
            assert len(cr)==len(recs)
            layout(ev,cur_len)
            for r,c in zip(recs,cr):
                n=cnt.get(bases[ui][0]+c['off'],0)
                if n:
                    mn,ops=inst_of(r,r['dist']); pk[(mn,ops)]+=n
        per[p]=pk; out.update(pk)
    return out,per
def measure(sc16,sc32,reloc='max',fuse=()):
    """per program: executed instructions, bytes fetched today / new16 / new32(estimate)"""
    from fuse import fuse_events
    res={}
    def prep(sp,objs_u,cnt,base):
        ev,recs=parse(sp)
        return ev,recs
    for p in progs:
        units,objs,bases,cnt=load(p)
        T=collections.Counter(); lens_hist=collections.Counter()
        for ui,u in enumerate(units):
            sp=(L.RT+'/crt.s') if u=='crt.s' else f'{W}/s16/{u}.s'
            sp32=sp if u=='crt.s' else f'{W}/s32/{u}.s'
            ev,recs=parse(sp)
            cr,fn,ok,sz=L.scan_s(sp,objs[ui]); assert len(cr)==len(recs)
            enc.RELOC=reloc
            layout(ev,(lambda r,d: cur_len(r,0 if d is None else d)) if reloc=='near' else cur_len)
            for r,c in zip(recs,cr):
                r['curlen']=r['len']; r['cnt']=cnt.get(bases[ui][0]+c['off'],0); r['ninstr']=1
            if fuse: ev,_=fuse_events(ev,fuse); recs=[e[1] for e in ev if e[0]=='I']
            layout(ev,sc16.lenfun)
            b16=collections.Counter(); c16=collections.Counter()
            for r in recs: b16[r['func']]+=r['len']; c16[r['func']]+=1
            ev32,recs32=parse(sp32)
            if fuse: ev32,_=fuse_events(ev32,fuse); recs32=[e[1] for e in ev32 if e[0]=='I']
            layout(ev32,sc32.lenfun)
            b32=collections.Counter(); c32=collections.Counter()
            for r in recs32: b32[r['func']]+=r['len']; c32[r['func']]+=1
            for r in recs:
                n=r['cnt']
                if not n: continue
                mn,ops=inst_of(r,r['dist']); pl=sc16.plan(mn,ops); h=len(pl) if pl else 1
                T['instr']+=n*r['ninstr']; T['cur']+=n*r['curlen']; T['new16']+=n*r['len']; T['hw16']+=n*h
                f=r['func']
                rb=(b32[f]/b16[f]) if (b16[f] and f in b32) else 1.0
                ri=(c32[f]/c16[f]) if (c16[f] and f in c32) else 1.0
                T['new32']+=n*r['len']*rb; T['i32']+=n*r['ninstr']*ri
                lens_hist[r['len']]+=n
        T['lens']=dict(lens_hist)
        res[p]=dict(T)
    return res
