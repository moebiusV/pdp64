"""Distances of the pc-relative operands of a compiled corpus, on the layout of a grammar's scheme (the reaches are chosen from these).
    PDP64_CORPUS_DIR_<TAG>=DIR python3 distances.py 16|32 TAG [GRAMMARDIR]
Per class (bCC/br, call/jmp, movcall, cbCC, lea d(pc), other pc-relative memory operands): the number of sites and, for a pc field of w bits (parcels, signed),
the share of the sites it reaches (external symbols excluded: they need the 32-bit relocation forms)."""
import sys, os, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from variants import *
import enc
from enc import *
import importlib.util, encgram
here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('chk', os.path.join(here, '..', '..', '..', 'tools', 'check-enc.py'))
chk = importlib.util.module_from_spec(spec); spec.loader.exec_module(chk)
which, tag = sys.argv[1], sys.argv[2]
d = encgram.load(which)
forms = [Form(f['name'], f['n'], f['mns'], [chk.mkspec(s) for s in f['specs']], xbits=f['xbits']) for f in d['forms']]
sc = Scheme(forms); enc.RELOC = 'max'
cls = collections.defaultdict(list); ext = collections.Counter()
for fn, ev, recs in corpus(tag):
    layout(ev, sc.lenfun)
    for r in recs:
        if 'pcrel' not in r['k'] or r['pool']: continue
        mn = r['mn']
        c = ('movcall' if mn == 'movcall' else 'cbCC' if mn.startswith('cb') and len(r['ops']) == 3 else 'call/jmp' if mn in ('call', 'jmp') else
             'bCC/br' if isbr(mn) and len(r['ops']) == 1 else 'lea' if mn == 'lea' else 'pc-relative memory operand (not lea)')
        if r['dist'] is None: ext[c] += 1; continue
        cls[c].append(r['dist'])
W = (5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 18, 20, 22, 24)
print('pc-relative operand distances on the layout of pdp64/%s (%s), field width in parcels, signed; the share reached' % (which, tag))
print('%-34s %8s %8s ' % ('class', 'sites', 'external') + ' '.join('%5d' % w for w in W))
for c, v in sorted(cls.items(), key=lambda x: -len(x[1])):
    row = []
    for w in W:
        lim = 1 << (w - 1)
        row.append('%5.1f' % (100.0 * sum(1 for x in v if -lim <= x // 2 < lim) / len(v)))
    print('%-34s %8d %8d ' % (c, len(v), ext[c]) + ' '.join(row))
print('(bytes: a field of w bits reaches +-2^w bytes)')
