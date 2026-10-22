import json,sys,collections
name=sys.argv[1]
base=json.load(open('/tmp/p64opt/base/results.json'))
cur=json.load(open('/tmp/p64opt/%s/results.json'%name))
ref={}
for x in base:
    if 'ins' in x and x['arch'] in ('gcc-Os','clang-Os','amd64'):
        ref[(x['arch'],x['src'])]=x
files=set()
by=collections.defaultdict(dict)
for x in cur:
    if x['arch']=='pdp64':
        by[x['src']]=x
bad=[k for k,x in by.items() if 'ins' not in x]
tot=collections.Counter()
n=0
for src,x in by.items():
    if 'ins' not in x: continue
    if not all((a,src) in ref for a in ('gcc-Os','clang-Os','amd64')): continue
    n+=1
    tot['ins']+=x['ins'];tot['img']+=x['image']
    for a in ('gcc-Os','clang-Os','amd64'):
        tot[a+'ins']+=ref[(a,src)]['ins'];tot[a+'img']+=ref[(a,src)]['image']
print('%s: %d files (%d failed) pdp64 ins %d bytes %d | vs gcc-Os ins %.3f bytes %.3f | vs clang-Os ins %.3f bytes %.3f | vs pcc-amd64 ins %.3f bytes %.3f'%(name,n,len(bad),tot['ins'],tot['img'],tot['ins']/tot['gcc-Osins'],tot['img']/tot['gcc-Osimg'],tot['ins']/tot['clang-Osins'],tot['img']/tot['clang-Osimg'],tot['ins']/tot['amd64ins'],tot['img']/tot['amd64img']))
