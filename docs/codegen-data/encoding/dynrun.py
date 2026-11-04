import sys,pickle,json
sys.path.insert(0,'.')
from variants import *
import dyn3
def dynreport(sc16,sc32,reloc):
    r=dyn3.measure(sc16,sc32,reloc)
    tot=collections.Counter()
    for p,T in r.items():
        for k in('instr','cur','new16','hw16','new32','i32'): tot[k]+=T[k]
    return r,tot
if __name__=='__main__':
    reloc=sys.argv[1]
    sc16,_=build('base16',reloc=reloc); sc32,_=build('r32',reloc=reloc)
    r,tot=dynreport(sc16,sc32,reloc)
    N=tot['instr']
    print(reloc,'instr',N,'today B/instr %.3f'%(tot['cur']/N),'new16 %.3f (%+.2f%%)'%(tot['new16']/N,100*(tot['new16']/tot['cur']-1)),'new32est %.3f/%.4f instr-ratio (%+.2f%% bytes vs today)'%(tot['new32']/N,tot['i32']/N,100*(tot['new32']/tot['cur']-1)))
    for p,T in r.items(): print(p,T['instr'],'cur %.3f new16 %.3f new32 %.3f'%(T['cur']/T['instr'],T['new16']/T['instr'],T['new32']/T['instr']), 'lens',T['lens'])
