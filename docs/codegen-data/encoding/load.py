import sys,os; sys.path.insert(0,os.path.join(os.path.dirname(os.path.abspath(__file__)),"..","..","..","tools"))
import sys,json,collections,pickle,os
sys.dont_write_bytecode=True
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from m2 import *
S=os.environ.get('PDP64_CORPUS_ROOT',os.environ.get('PDP64_SCRATCH','/tmp/pdp64-scratch'))
def corpus(tag):
    d=os.environ.get('PDP64_CORPUS_DIR_'+tag.upper()) or f'{S}/spill/asm-{tag}'
    out=[]
    ex = [p for p in os.environ.get('PDP64_CORPUS_EXCLUDE', '').split(',') if p]     # file name prefixes left out (leave-one-project-out training)
    only = [p for p in os.environ.get('PDP64_CORPUS_ONLY', '').split(',') if p]       # ... or the only ones kept (the held-out measurement)
    for fn in sorted(x for x in os.listdir(d) if x.endswith('.s') and not any(x.startswith(p) for p in ex) and (not only or any(x.startswith(p) for p in only))):
        ev,recs=parse(f'{d}/{fn}'); out.append((fn,ev,recs))
    return out
if __name__=='__main__':
    for tag in ('base16','r32'):
        c=corpus(tag); n=sum(len(r) for _,_,r in c)
        regs=collections.Counter()
        for _,_,rs in c:
            for r in rs:
                for o in r['ops']:
                    import re
                    for m in re.findall(r'\b(r\d+|sp|fp)\b',o): regs[m]+=1
        print(tag,n,sorted(regs.items(),key=lambda x:(len(x[0]),x[0])))
