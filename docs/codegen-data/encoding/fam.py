import sys,re,collections
sys.path.insert(0,'.')
from variants import *
def fam(sc,path,title):
    g=collections.defaultdict(lambda:[0,0,0.0,collections.Counter()])
    for f in sc.forms:
        k=re.sub(r'(_?\d+)?(/.*)?$','',f.name); k=re.sub(r'[hH]$','',k) if len(k)>4 else k
        x=g[k]; x[0]+=1; x[1]+=len(f.mns); x[2]+=f.kraft(); x[3][f.n]+=1
    with open(path,'w') as o:
        o.write('# %s: forms grouped by family\n\n| family | forms | (form,mnemonic) pairs | code space (fraction of 65536 first-parcel patterns) | forms by parcels |\n|---|---|---|---|---|\n'%title)
        for k,v in sorted(g.items(),key=lambda kv:-kv[1][2]):
            o.write('| %s | %d | %d | %.4f | %s |\n'%(k,v[0],v[1],v[2],dict(sorted(v[3].items()))))
        o.write('\nTotal code space used: %.4f; unassigned (illegal-instruction) patterns: %d of 65536 (%.2f%%).\n'%(sc.code.kraft,65536-sum(1 for p in range(65536) if sc.code.table[p]),100*(1-sc.code.kraft)))
for name,tag,mix in (('A16','base16',0.0),('A32','r32',0.0)):
    sc,_=build(tag,reloc='max',mix=mix); fam(sc,'families-%s.md'%name,name)
