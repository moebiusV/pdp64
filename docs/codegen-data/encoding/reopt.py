"""Re-run the optimiser on the output of the new compiler and report the ablation of the cbCC cost model.
    PDP64_CORPUS_DIR_NEW16=DIR PDP64_CORPUS_DIR_NEW32=DIR python3 reopt.py WHICH(16|32) NAME LAM|none ROUNDS [cbwide] [cb3] [refine=N] OUTJSON
runs `rounds` (export_forms.py) with the committed hot tables and writes the result row (bytes of the corpus under the model, forms, expanded cbCC) to OUTJSON;
(OUTJSON.enc.json holds the exported scheme for write_hbnf.py: `python3 write_hbnf.py OUTDIR 16=a.enc.json 32=b.enc.json`)
`cbwide` adds finer cbCC candidates (pc fields of 9, 11 and 13 parcels, immediates of 7 and 14 bits); `cb3` adds three-parcel cbCC candidates (far targets, wide immediates)."""
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from export_forms import *
import write_hbnf
which, name, lam, nr = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
flags = sys.argv[5:-1]; wide = 'cbwide' in flags; cb3 = 'cb3' in flags
outj = sys.argv[-1]
lam = None if lam == 'none' else float(lam)
opts = dict(cbidw=(8,9,10,11,12,13,14,16,18,20), cbiw=(3,4,5,6,7,8,10,12,14,16), cbrdw=(8,9,10,11,12,13,14,16,18,20,22,24)) if wide else {}
if cb3: opts['cb3'] = True
opts = opts or None
tag = 'new' + which
_, d0 = committed(which)
hot = d0['hot16'] if which == '32' else d0['hot8']
refine = next((int(f[7:]) for f in flags if f.startswith('refine=')), 0)
sc, total, m = rounds(which, tag, nr, lam, opts=opts, hot=hot, refine=refine)
st = m['stats']
row = dict(name=name, which=which, lam=lam, rounds=nr, wide=wide, cb3=cb3, refine=refine, bytes=total, forms=len(sc.forms), leaves=len(sc.code.leaves), kraft=sc.code.kraft, checked=st.get('checked'), mismatch=st.get('mismatch', 0),
           unencodable=st.get('unencodable', 0), expanded=st.get('expanded_cb', 0), sizes=m['sizes'])
print(json.dumps(row))
json.dump(row, open(outj, 'w'))
d = json.loads(json.dumps(export(which, sc, tag, hot), default=str))
json.dump(d, open(outj + '.enc.json', 'w'))
