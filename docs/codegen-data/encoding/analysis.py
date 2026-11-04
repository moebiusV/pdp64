import sys,json,collections
sys.path.insert(0,'.')
from variants import *
from fuse import fuse_corpus
from cur import cur_len
FZ=('movcall','popmret','popret','mov2')
def cubes_for_length(sc):
    """number of product terms (cubes) of the function n(parcel0), after merging sibling cubes with equal n; the unassigned patterns are don't-care for the minimizer, counted as illegal here (conservative: not merged)"""
    cube={}
    for lf in sc.code.leaves: cube[(lf.prefix,lf.L)]=lf.form.n
    changed=True
    while changed:
        changed=False
        for (p,L),n in list(cube.items()):
            if (p,L) not in cube or L==0: continue
            sib=(p^1,L)
            if sib in cube and cube[sib]==n:
                del cube[(p,L)]; del cube[sib]; cube[(p>>1,L-1)]=n; changed=True
    byn=collections.Counter(cube.values())
    return len(cube),dict(byn)
def regfixed(sc,corp):
    """fraction of hardware instructions whose register fields all sit in parcel 0 bits [7:0] ([9:0] for 5-bit)"""
    leafof={}
    for lf in sc.code.leaves:
        for m in lf.mns: leafof[(lf.form.name,m)]=lf
    tot=ok=0; ok_any=0; byn=collections.Counter()
    for fn,ev,recs in corp:
        layout(ev,sc.lenfun)
        for r in recs:
            mn,ops=inst_of(r,r['dist']); pl=sc.plan(mn,ops)
            if not pl: continue
            for m,o in pl:
                f,v=sc.choose(m,o); lf=leafof[(f.name,m)]
                tot+=1; byn[f.n]+=1
                good=True
                for (oi,pi),bits in lf.place.items():
                    if oi>=0 and f.specs[oi].parts[pi][0]=='r' and (max(bits)>=10 if False else max(bits)>=16 or min(bits)<0): good=False
                regp=[bits for (oi,pi),bits in lf.place.items() if oi>=0 and f.specs[oi].parts[pi][0]=='r']
                inp0=all(max(b)<16 for b in regp)
                inlow=all(max(b)<(10 if any(len(x)==5 for x in regp) else 8) for b in regp)
                ok+=inlow; ok_any+=inp0
    return tot,ok/tot,ok_any/tot,dict(byn)
def regressions(sc,tag,top=14):
    corp=corpus(tag); rec=collections.defaultdict(lambda:[0,0,0])
    for fn,ev,recs in corp:
        layout(ev,cur_len)
        for r in recs:
            mn,ops=inst_of(r,r['dist']); k=(mn if not mn.startswith('cb') else 'cb*','/'.join(o[0] for o in ops)); rec[k][0]+=1; rec[k][1]+=r['len']
    for fn,ev,recs in corp:
        layout(ev,sc.lenfun)
        for r in recs:
            mn,ops=inst_of(r,r['dist']); k=(mn if not mn.startswith('cb') else 'cb*','/'.join(o[0] for o in ops)); rec[k][2]+=r['len']
    rows=sorted(((v[2]-v[1],k,v) for k,v in rec.items()),reverse=True)
    return rows[:top],rows[-10:]
if __name__=='__main__':
    for name,tag,mix,fz in (('A16','base16',0.0,()),('B16','base16',3.0,()),('A32','r32',0.0,())):
        sc,_=build(tag,reloc='max',mix=mix,fuse=fz)
        corp=corpus(tag)
        print(name,'length-function cubes',cubes_for_length(sc))
        print(name,'register fields fixed in P0 low bits: (hw instr, frac low, frac in P0)',regfixed(sc,corp))
        if name in('A16','A32'):
            up,down=regressions(sc,tag)
            print(name,'classes that grow vs today (delta bytes,class,[count,today,new]):')
            for x in up: print('  ',x)
            print(name,'largest savings:')
            for x in down: print('  ',x)
