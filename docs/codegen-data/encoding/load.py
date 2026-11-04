import sys,json,collections,pickle,os
sys.dont_write_bytecode=True
sys.path.insert(0,'/tmp/claude-1000/-home-david-claude-pdp64/c8eb5fe9-a8c9-4e79-aafa-1502bfe6a13e/scratchpad/fit')
from m2 import *
S='/tmp/claude-1000/-home-david-claude-pdp64/c8eb5fe9-a8c9-4e79-aafa-1502bfe6a13e/scratchpad'
def corpus(tag):
    d=f'{S}/spill/asm-{tag}'
    out=[]
    for fn in sorted(os.listdir(d)):
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
