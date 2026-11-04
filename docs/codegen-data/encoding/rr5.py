import sys,json,collections
sys.path.insert(0,'.')
from variants import *
import dyn3
def ex(mns):
    return lambda R,H3,H4: [Form('RR5',1,mns,[R,R])]
out={}
sc16,_=build('base16',reloc='max')
for name,mns in (('none',None),('8 hottest ALU/moves',['movq','movl','add','sub','xor','and','bis','shl']),('16 mnemonics (all of RR a+b)',['movq','movl','movzl','movzb','add','sub','cmp','and','bis','xor','shl','shr','sar','mul','movw','movb'])):
    sc32,_=build('r32',reloc='max',extra=ex(mns) if mns else None)
    t,_=measure(sc32,'r32',do_rt=False)
    r=dyn3.measure(sc16,sc32,'max'); tot=collections.Counter()
    for p,T in r.items():
        for k in('instr','cur','new16','new32'): tot[k]+=T[k]
    out[name]=(t,tot['new32']/tot['instr'],tot['new16']/tot['instr'])
    print(name,out[name],'kraft %.3f'%sc32.code.kraft,flush=True)
