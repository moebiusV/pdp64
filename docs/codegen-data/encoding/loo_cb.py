"""Leave-projects-out check of the re-optimisation (static bytes): train on the corpus without the projects HELD, measure on them, with the trained-on-everything
grammar (spec/) and the model of the original design as the references.
    PDP64_CORPUS_DIR_NEW16=... PDP64_CORPUS_DIR_NEW32=... python3 loo_cb.py 16|32 HELD(comma separated file name prefixes, e.g. lua_,lz4_,zlib_,bearssl_) [lam] [cb3]
Prints: bytes and substituted cbCC on the held-out files for (a) the scheme trained without them, (b) the grammar in spec/ (trained on everything), (c) the same on the training files."""
import sys, os
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
which, held = sys.argv[1], sys.argv[2]
lam = float(sys.argv[3]) if len(sys.argv) > 3 else 2.0
opts = dict(cb3=True) if (len(sys.argv) > 4 and sys.argv[4] == 'cb3') else None
os.environ['PDP64_CORPUS_EXCLUDE'] = held
from export_forms import *
tag = 'new' + which
_, d0 = committed(which)
hot = d0['hot16'] if which == '32' else d0['hot8']
sc, total, m = rounds(which, tag, 2, lam, opts=opts, hot=hot, refine=6)
del os.environ['PDP64_CORPUS_EXCLUDE']
res = {}
for name, s in (('trained without', sc), ('spec/ (trained on all)', d0 and committed(which)[0])):
    os.environ['PDP64_CORPUS_ONLY'] = held
    t, mm = measure(s, tag, fuse=())
    res[name] = (t, mm['stats'].get('expanded_cb', 0), mm['stats'].get('checked'))
    print('held-out files (%s): %-24s bytes %d  substituted cbCC %d  instructions %d' % (held, name, t, res[name][1], res[name][2]), flush=True)
