"""The cbCC forms of an encoding (read from the grammar through encgram): per condition class, register field and immediate width, the pc field widths that exist.
    python3 cbforms.py 16|32"""
import sys, os, re, collections
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'tools'))
import encgram
d = encgram.load(sys.argv[1])
cls = {'a': 'eq ne', 'b': 'lt ge gt le', 'c': 'cs cc hi los', 'd': 'pl mi vc vs'}
rows = collections.defaultdict(list)
for f in d['forms']:
    if not f['name'].startswith('CB') and not f['name'].startswith('FX'): continue
    sp = f['specs']
    if len(sp) != 3 or not f['mns'] or not f['mns'][0].startswith('cb'): continue
    reg = sp[0]['w'] if 'w' in sp[0] else (sp[0].get('table') and 3)
    k2 = sp[1]
    if k2['k'] == 'R': ik = 'R'
    elif k2['k'] == 'K': ik = '0'
    else: ik = 'i%d' % k2['w']
    rows[(f['mns'][0] if len(f['mns']) < 14 else 'all', ik)].append((f['name'], f['n'], reg, sp[2]['w'], len(f['mns'])))
for k, v in sorted(rows.items(), key=lambda x: str(x)):
    print(k, ' '.join('%s[n%d r%d pc%d m%d]' % x for x in v))

# the code space the cbCC forms take (a leaf with a prefix of L bits takes 2^-L of the 65,536 first parcels)
fi = {i: f for i, f in enumerate(d['forms'])}
k = collections.Counter(); nl = collections.Counter()
for lf in d['leaves']:
    f = fi[lf['form']]
    g = 'cbCC' if f['mns'] and f['mns'][0].startswith('cb') and len(f['specs']) == 3 else 'other'
    k[g] += 2.0 ** -lf['L'] * (1 if True else 0); nl[g] += 1
print('code space of the cbCC leaves: %.4f of 1.0 (%d leaves; %d first parcels of 65,536); all leaves %.4f' % (k['cbCC'], nl['cbCC'], round(k['cbCC'] * 65536), sum(k.values())))
