"""cbCC reach diagnosis: every compare-and-branch of a compiled corpus, laid out with the scheme of the committed grammar (as asm_vs_model.py), by
the form that reaches it or by the cmp+bCC substitution; with the distance, the immediate, the registers.

    PDP64_CORPUS_DIR_NEW16=... PDP64_CORPUS_DIR_NEW32=... python3 cbreach.py 16|32 TAG [manifest.json]

TAG is the corpus tag (load.corpus): the directory of the compiled assembly is taken from PDP64_CORPUS_DIR_<TAG>."""
import sys, os, json, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from variants import *
import enc
from enc import *
import importlib.util
here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('chk', os.path.join(here, '..', '..', '..', 'tools', 'check-enc.py'))
chk = importlib.util.module_from_spec(spec); spec.loader.exec_module(chk)
import encgram
which, tag = sys.argv[1], sys.argv[2]
man = json.load(open(sys.argv[3])) if len(sys.argv) > 3 else []
proj = {n: c for c, n in man}
d = encgram.load(which)
forms = [Form(f['name'], f['n'], f['mns'], [chk.mkspec(s) for s in f['specs']], xbits=f['xbits']) for f in d['forms']]
sc = Scheme(forms); enc.RELOC = 'max'
hot4 = d.get('hot16') or d.get('hot8')
corp = corpus(tag)
rows = []
for fn, ev, recs in corp:
    layout(ev, sc.lenfun)
    for r in recs:
        if not (r['mn'].startswith('cb') and len(r['ops']) == 3): continue
        mn, ops = inst_of(r, r['dist'])
        p = sc.plan(mn, ops)
        ch = sc.choose(mn, ops)
        rows.append(dict(file=fn[:-2], proj=proj.get(fn[:-2], fn.split('_')[0]), mn=mn, kind=ops[1][0], imm=ops[1][1], reg=ops[0][1], reg2=ops[1][1] if ops[1][0] == 'R' else None,
                         dist=ops[2][1], ext=ops[2][1] is None, form=(ch[0].name if ch else None), n=(ch[0].n if ch else None)))
json.dump(rows, open(sys.argv[4] if len(sys.argv) > 4 else '/dev/null', 'w'))
N = len(rows); exp = [r for r in rows if r['form'] is None]
print('pdp64/%s: %d cbCC sites; %d reached by a form (parcels of the form: %s); %d substituted by cmp + bCC' % (which, N, N - len(exp), dict(sorted(collections.Counter(r['n'] for r in rows if r['form']).items())), len(exp)))
def bucket(dv):
    if dv is None: return 'external'
    a = abs(dv)
    for b in (16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536): 
        if a <= b: return '<=%d' % b
    return '>65536'
order = ['<=16', '<=32', '<=64', '<=128', '<=256', '<=512', '<=1024', '<=2048', '<=4096', '<=8192', '<=16384', '<=32768', '<=65536', '>65536', 'external']
print('\ndistance (bytes, |d|) of all sites / of the substituted ones')
ca = collections.Counter(bucket(r['dist']) for r in rows); ce = collections.Counter(bucket(r['dist']) for r in exp)
for b in order: print('  %-9s %6d %6d' % (b, ca[b], ce[b]))
print('\nsubstituted sites by cause (imm kind/range, register class)')
cause = collections.Counter()
for r in exp:
    k = 'reg' if r['kind'] == 'R' else ('imm0' if r['imm'] == 0 else 'imm%d' % (next(b for b in (3, 4, 5, 6, 8, 10, 12, 16, 32, 64) if -(1 << (b - 1)) <= r['imm'] < (1 << (b - 1))) if -(1 << 63) <= r['imm'] < (1 << 63) else 99))
    hot = 'hot' if hot4 and r['reg'] in (hot4 if len(hot4) == 16 else []) else 'cold'
    cause[(k, hot, bucket(r['dist']))] += 1
for k, v in sorted(cause.items(), key=lambda x: -x[1])[:25]: print('  ', k, v)
print('\nby project: sites, substituted')
pa = collections.Counter(r['proj'] for r in rows); pe = collections.Counter(r['proj'] for r in exp)
for k in sorted(pa): print('  %-12s %6d %6d' % (k, pa[k], pe[k]))
print('\nforms reaching (top)')
for k, v in collections.Counter(r['form'] for r in rows).most_common(25): print('  ', k, v)
