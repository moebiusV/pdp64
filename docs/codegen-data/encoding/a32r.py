import sys,json,collections
sys.path.insert(0,'.')
from variants import *
from proof import *
import dyn3
from tables import dump
mns=['movq','movl','add','sub','xor','and','bis','shl']
ex=lambda R,H3,H4: [Form('RR5',1,mns,[R,R])]
res={}
for reloc in ('max','near'):
    sc16,_=build('base16',reloc=reloc)
    sc,_=build('r32',reloc=reloc,extra=ex)
    total,d=measure(sc,'r32'); nb,bad,nf=boundary_tests(sc); dec=decodability(sc)
    r=dyn3.measure(sc16,sc,reloc); tot=collections.Counter(); per={}
    for p,T in r.items():
        for k in('instr','cur','new16','new32','i32'): tot[k]+=T[k]
        per[p]=(T['new16']/T['instr'],T['new32']/T['instr'])
    res[reloc]=dict(total=total,checked=d['stats'].get('checked'),mismatch=d['stats'].get('mismatch',0),boundary=(nb,len(bad)),sizes=d['sizes'],forms=len(sc.forms),free=dec['free_patterns'],dyn32=tot['new32']/tot['instr'],dyn16=tot['new16']/tot['instr'],today=tot['cur']/tot['instr'],per=per,i32=tot['i32']/tot['instr'])
    print(reloc,res[reloc],flush=True)
    if reloc=='max': dump(sc,'tables-A32r.md','A32r (r32 + 5-bit one-parcel RR for 8 mnemonics)')
json.dump(res,open('a32r.json','w'),default=str)
