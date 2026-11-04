import sys,json
sys.path.insert(0,'.')
from variants import *
out={}
for tag in ('base16','r32'):
    for fz in ((),('popmret','popret'),('movcall',),('mov2',),('movcall','popmret','popret','mov2')):
        sc,_=build(tag,reloc='max',fuse=fz)
        t,d=measure(sc,tag,fuse=fz)
        out[f'{tag}/{"+".join(fz) or "none"}']=dict(total=t,mismatch=d['stats'].get('mismatch',0),checked=d['stats'].get('checked'),pairs=d['fused_pairs'],unenc=d['stats'].get('unencodable',0))
        print(tag,fz,out[f'{tag}/{"+".join(fz) or "none"}'],flush=True)
json.dump(out,open('fuse_abl.json','w'))
