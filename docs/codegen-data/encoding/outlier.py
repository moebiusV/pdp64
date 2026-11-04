import sys,collections,json
sys.path.insert(0,'.')
import variants as V
from variants import *
import dyn3
OUT='gcc-src_gcc_testsuite_gcc.c-torture_execute_memcpy-a2.c.s'
res={}
for tag in ('base16','r32'):
    corp=[x for x in corpus(tag) if x[0]!=OUT]
    # training keys without the outlier file
    keys=collections.Counter()
    for fn,ev,recs in corp:
        layout(ev,cur_len)
        for r in recs:
            mn,ops=inst_of(r,r['dist']); keys[(mn,ops)]+=1
    order,cnt=hot_tables(corp)
    V._cache[tag]=(corp,keys,order,cnt)
    sc,_=build(tag,reloc='max')
    full=corpus(tag)
    tot_full,_=measure(sc,tag,do_rt=False)
    tot_x=sum(layout(ev,sc.lenfun) for fn,ev,recs in corp)
    cur_x=0
    for fn,ev,recs in corp: cur_x+=layout(ev,cur_len)
    cur_full=cur_total(tag,'max')
    res[tag]=dict(new_full=tot_full,today_full=cur_full,new_without=tot_x,today_without=cur_x,forms=len(sc.forms))
    print(tag,res[tag],'%.2f%% full  %.2f%% without outlier'%(100*(tot_full/cur_full-1),100*(tot_x/cur_x-1)),flush=True)
    if tag=='base16':
        print('dyn',dynB:=None)
        old=dyn3.progs
        r=dyn3.measure(sc,sc,'max'); tot=collections.Counter()
        for p,T in r.items():
            for k in('instr','cur','new16'): tot[k]+=T[k]
        print('A16x dynamic B/instr new16 %.3f today %.3f'%(tot['new16']/tot['instr'],tot['cur']/tot['instr']))
json.dump(res,open('outlier.json','w'))
