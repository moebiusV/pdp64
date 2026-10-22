import json,sys,collections
d=sys.argv[1]; ref=sys.argv[2]; N=int(sys.argv[3]) if len(sys.argv)>3 else 25
base=json.load(open('/tmp/p64opt/base/results.json'))
cur=json.load(open('/tmp/p64opt/%s/results.json'%d))
R={(x['arch'],x['src']):x for x in base if 'ins' in x}
rows=[]
for x in cur:
    if x['arch']=='pdp64' and 'ins' in x and (ref,x['src']) in R and ('clang-Os',x['src']) in R and ('gcc-Os',x['src']) in R:
        g=R[(ref,x['src'])]
        if g['image']>1000: rows.append((x['image']/g['image'],x['src'],x['image'],g['image'],x['ins'],g['ins']))
rows.sort(reverse=True)
n=len(rows)
print(n,'files >1KB; total pdp64',sum(x[2] for x in rows),ref,sum(x[3] for x in rows))
for x in rows[:N]: print('%.2f %s %d %d  ins %d %d'%x)
w=[x for x in rows[:n//10] if 'memcpy-a2' not in x[1]]
print('worst 10%% (no memcpy-a2): %d files, pdp64 %d %s %d ratio %.3f'%(len(w),sum(x[2] for x in w),ref,sum(x[3] for x in w),sum(x[2] for x in w)/sum(x[3] for x in w)))
open('/tmp/p64opt/worst_%s.txt'%d,'w').write('\n'.join(x[1] for x in rows[:n//10])+'\n')
