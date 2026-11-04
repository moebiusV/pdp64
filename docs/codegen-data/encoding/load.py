import sys,os; sys.path.insert(0,os.path.join(os.path.dirname(os.path.abspath(__file__)),"..","..","..","tools"))
import sys,json,collections,pickle,os
sys.dont_write_bytecode=True
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from m2 import *
S=os.environ.get('PDP64_CORPUS_ROOT','/tmp/claude-1000/-home-david-claude-pdp64/c8eb5fe9-a8c9-4e79-aafa-1502bfe6a13e/scratchpad')
def corpus(tag):
    d=os.environ.get('PDP64_CORPUS_DIR_'+tag.upper()) or f'{S}/spill/asm-{tag}'
    out=[]
    for fn in sorted(x for x in os.listdir(d) if x.endswith('.s')):
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
