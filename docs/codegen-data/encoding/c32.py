import sys,json,collections
sys.path.insert(0,'.')
from variants import *
from proof import *
import dyn3
FZ=('movcall','popmret','popret','mov2')
res={}
for reloc in ('max','near'):
    sc32,_=build('r32',reloc=reloc,fuse=FZ); sc16,_=build('base16',reloc=reloc,mix=3.0,fuse=FZ)
    total,d=measure(sc32,'r32',fuse=FZ)
    st=d['stats']
    r=dyn3.measure(sc16,sc32,reloc,fuse=FZ)
    tot=collections.Counter()
    for p,T in r.items():
        for k in('instr','cur','new16','hw16','new32','i32'): tot[k]+=T[k]
    res[reloc]=dict(total=total,unenc=st.get('unencodable',0),mismatch=st.get('mismatch',0),checked=st.get('checked'),tot=dict(tot))
    print(reloc,res[reloc],flush=True)
json.dump(res,open('c32.json','w'))
