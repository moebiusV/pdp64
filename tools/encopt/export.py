#!/usr/bin/env python3
"""export.py -- write the input file of encopt (see encopt.5) from the data of the Python encoding study.

This stays Python on purpose: it reads the corpus with the study's own assembly reader and operand model (docs/codegen-data/encoding: load.py, m2.py, norm.py,
enc.py, cat.py, solve.py), which is the only place that knows how a form fits an operand.  When the compiler corpus tool exists and writes the same file
(encopt.5), this script is not needed any more.

  export.py --corpus DIR [--out FILE] [--weights FILE]... [--lam B] [--budget F] [--no-cb3] [--rounds N]
  export.py --corpus DIR --verify RESULT        # size of the corpus (model bytes, real layout and branch relaxation) with the forms chosen in RESULT

  --corpus DIR   compiled assembly of the 32-register compile (ccom -m pdp64/32 over the corpus, one .s per file)
  --committed    take the distances of the corpus from the layout of the committed grammar spec/pdp64/pdp64.hbnf (default, as export_forms.py --rounds 1) and mark the
                 candidates that the committed grammar contains (lines `committed` of the file)
  --lam B        bytes charged for the extra instruction of cmp + bCC when no cbCC form reaches (default 2: the chosen setting of section 12.2 of encoding-proposal.md)
  --budget F     fraction of the first-parcel space (65,536 patterns) that the forced and the chosen forms may use.  Default 1.0: no reserve, the free-space policy is zero and the
                 candidates may use everything the forced forms leave.  (The study kept 0.95 = 62,259 patterns.)
  --weights FILE the instructions of a profile (encopt(5), WEIGHTS FILE), as `weight dynamic COUNT mnemonic operands` lines, written by profile.py: added to the keys of the corpus
                 (an instruction that is not in the corpus gets the static count 0) and exported as the dynamic counts of the demands; `weight static` adds static counts
  --cb3          offer the three-parcel cbCC candidates (default on)

The reader is corrected here (corpusfix.py): `set cc,rd` and the system-register moves are read with their word operand as a number, not as a label.

What is exported: the forced forms (always present), the candidate forms (one per (form, mnemonic class), the unit the study's optimiser chooses), the instructions of
the corpus grouped by (what the forced forms already give, the set of candidates that would shorten it), and the committed selection.
"""
import sys, os, collections, argparse, json, math, time, re
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
ENC = os.path.join(ROOT, 'docs', 'codegen-data', 'encoding')
sys.dont_write_bytecode = True
sys.path.insert(0, ENC)
sys.path.insert(0, os.path.join(ROOT, 'tools'))
sys.path.insert(0, HERE)
import weightsfile
import corpusfix            # the corrected reader (set cc,rd and mfsr/mtsr read their word operand as a number); before load and variants are imported

ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
ap.add_argument('--corpus')
ap.add_argument('--out', default='-')
ap.add_argument('--lam', type=float, default=2.0)
ap.add_argument('--budget', type=float, default=1.0, help='fraction of the 65,536 first-parcel patterns the forced and the chosen forms may use (default 1.0: no reserve; the study kept 0.95)')
ap.add_argument('--weights', action='append', default=[], metavar='FILE', help='a weights file (encopt(5)): `weight static|dynamic COUNT instruction` lines; repeatable.  Dynamic counts make the objectives fetch and exec meaningful')
ap.add_argument('--no-cb3', action='store_true')
ap.add_argument('--no-committed', action='store_true')
ap.add_argument('--rounds', type=int, default=1)
ap.add_argument('--verify')
ap.add_argument('--prev', metavar='RESULT', help='take the distances of the corpus (and the price of an unreachable cbCC) from the layout of the selection in an earlier encopt result instead of the committed grammar: the next round of the design loop')
ap.add_argument('--python-solve', metavar='OUT', help='also run the study\'s own greedy selection (solve.solve, refine 6) on the same data and write its choice as `chosen` lines to OUT')
ap.add_argument('--compare-leaves', metavar='RESULT', help='compare the leaves of an encopt -C result with those of the grammar spec/pdp64/pdp64.hbnf (form, prefix length, prefix, mnemonics)')
ap.add_argument('--dump-leaves', action='store_true', help='print the leaves of the grammar in the form of the `leaf` lines of an encopt result')
a = ap.parse_args()
os.environ['PDP64_CORPUS_DIR_R32'] = a.corpus or ''
TAG = 'r32'
import m2
import enc
from variants import *
from export_forms import make_fallback, FZ
import encgram
import importlib.util
spec = importlib.util.spec_from_file_location('chk', os.path.join(ROOT, 'tools', 'check-enc.py'))
chk = importlib.util.module_from_spec(spec); spec.loader.exec_module(chk)


def committed_scheme():
    d = encgram.load()
    sc = Scheme([Form(f['name'], f['n'], f['mns'], [chk.mkspec(s) for s in f['specs']], xbits=f['xbits']) for f in d['forms']])
    return sc, d


def setup(prev, hot, lenfun):
    c, keys, order, cnt = prep(TAG, lenfun)
    order = list(hot) + [r for r in order if r not in hot]
    enc.RELOC = 'max'
    R = SR(5); H3 = SR(3, order[:8]); H4 = SR(4, order[:16])
    forced, _ = mk(R, H3, H4)
    forced = forced + fused_forms(R, H3, FZ)
    mns = ['movq', 'movl', 'add', 'sub', 'xor', 'and', 'bis', 'shl']
    forced = forced + [Form('RR5', 1, mns, [R, R])]
    cs = cands(R, H3, H4, None if a.no_cb3 else dict(cb3=True))
    return keys, forced, cs


def patterns(f):
    """first-parcel patterns of 65,536 that the form takes (a power of two times the mnemonics of a binary-aligned group; Code splits a group in such chunks)"""
    return (1 << (16 - f.Lleaf)) if f.xbits else len(f.mns) * (1 << (16 - f.Lleaf))


def model_bytes(forms, keys):
    sc = Scheme(forms)
    tot = 0; lost = 0
    for k, n in keys.items():
        mn, ops = k
        s = sc.size1(mn, ops)
        if s is None: lost += n
        else: tot += n * s
    return sc, tot, lost


def grammar_leaves():
	d = encgram.load()
	out = []
	for l in d['leaves']:
		f = d['forms'][l['form']]
		out.append((f['name'], l['L'], format(l['prefix'], '0%db' % l['L']), tuple(l['mns'])))
	return out


if a.dump_leaves or a.compare_leaves:
	gl = grammar_leaves()
	if a.dump_leaves:
		for n, L, p, mns in gl: print('leaf %s - %d %s %d %s' % (n, L, p, len(mns), ' '.join(mns)))
		sys.exit(0)
	el = []
	for l in open(a.compare_leaves):
		t = l.split()
		if t and t[0] == 'leaf': el.append((t[1], int(t[3]), t[4], tuple(t[6:])))
	# the grammar's leaves of one form are in the order of the catalogue; the result's, in the order of the leaves: compare as sets, and report differences
	sg, se = set(gl), set(el)
	print('leaves: grammar %d, encopt %d, identical %d' % (len(gl), len(el), len(sg & se)))
	for x in sorted(sg - se)[:10]: print('  only in the grammar: %s L=%d %s (%d mnemonics)' % (x[0], x[1], x[2], len(x[3])))
	for x in sorted(se - sg)[:10]: print('  only in encopt: %s L=%d %s (%d mnemonics)' % (x[0], x[1], x[2], len(x[3])))
	sys.exit(0 if sg == se else 1)

if not a.corpus: ap.error('--corpus is required')

if a.verify:
    prev, d = committed_scheme()
    hot = d['hot16']
    keys, forced, cs = setup(prev, hot, prev.lenfun)
    byname = {f.name: f for f in cs}
    chosen = []
    for l in open(a.verify):
        t = l.split()
        if t and t[0] == 'chosen': chosen.append(t[1])
    forms = forced + [byname[n] for n in chosen]
    sc = Scheme(forms)
    c, k2, o2, c2 = prep(TAG, sc.lenfun)
    total, m = measure(sc, TAG, fuse=())
    st = m['stats']
    print('verify: forms %d leaves %d kraft %.4f model bytes (layout, relaxation) %d unencodable %d expanded cbCC %d round trip: %d checked, %d mismatch, %d illegal' % (
        len(sc.forms), len(sc.code.leaves), sc.code.kraft, total, st.get('unencodable', 0), st.get('expanded_cb', 0), st.get('checked', 0), st.get('mismatch', 0), st.get('decode_illegal', 0)))
    if m.get('fail'): print('verify: shapes with no form: %s' % ', '.join('%s %s x%d' % (k[0], '/'.join(k[1]), v) for k, v in sorted(m['fail'].items(), key=lambda kv: -kv[1])[:8]))
    sys.exit(0)

prev, d = committed_scheme()
hot = d['hot16']
if a.prev:
    k0, f0, c0 = setup(prev, hot, prev.lenfun)
    by0 = {f.name: f for f in c0}
    prev = Scheme(f0 + [by0[l.split()[1]] for l in open(a.prev) if l.split()[:1] == ['chosen']])
lenfun = prev.lenfun
for r in range(a.rounds):
    keys, forced, cs = setup(prev, hot, lenfun)
    if r + 1 < a.rounds: raise SystemExit('--rounds > 1 needs the selection of the previous round: run encopt, then export.py again with --verify; one round only here')
fallback = make_fallback(prev, a.lam)
# ---- the covering model: the preamble of solve.solve
t0 = time.time()
skeys = collections.Counter(keys)            # static counts: the corpus (the study's weights), and `weight static` lines
wst, wdy = weightsfile.read_weights(a.weights)
skeys.update(wst)
dkeys = wdy                                  # dynamic counts: the profile
keys = collections.Counter(skeys)            # every instruction that is counted anywhere (a count of 0 keeps the key in the model)
for k in dkeys:
    if k not in keys: keys[k] = 0
groups = collections.defaultdict(list)
for (mn, ops), n in keys.items():
    groups[(mn, tuple(o[0] for o in ops))].append((mn, ops))
base = {}; ops0 = {}
for (mn, ops), n in keys.items():
    b = None; kd = tuple(o[0] for o in ops)
    for f in forced:
        if mn in f._mnset() and f.kinds == kd and f.fit(mn, ops) is not None:
            bb = 2 * f.n
            if b is None or bb < b: b = bb
    o0 = 1
    if b is None:
        b = 99; o0 = 99
        fb = fallback(mn, ops)
        if fb is not None: b = fb; o0 = 2        # a cbCC that no form reaches is a cmp and a bCC: two operations
    base[(mn, ops)] = b; ops0[(mn, ops)] = o0
hits = []      # per candidate: list of keys it fits
for f in cs:
    h = []
    for m in f.mns:
        for k in groups.get((m, f.kinds), ()):
            if f.fit(m, k[1]) is not None: h.append(k)
    hits.append(h)
useful = [i for i, h in enumerate(hits) if h]
cid = {ci: j for j, ci in enumerate(useful)}
cover = collections.defaultdict(list)
for ci in useful:
    for k in hits[ci]: cover[k].append(cid[ci])
dem = collections.defaultdict(lambda: [0, 0, 0])
for k, n in keys.items():
    sig = (base[k], ops0[k], tuple(sorted(cover.get(k, ()))))
    d_ = dem[sig]; d_[0] += n; d_[1] += dkeys.get(k, 0); d_[2] += 1
unenc_keys = [k for k in keys if base[k] >= 99 and not cover.get(k)]
sys.stderr.write('export: %d keys (%d instructions static, %d executed), %d candidates (%d useful), %d demand classes, %d instructions (%d distinct) no form encodes, %.1fs\n' % (
    len(keys), sum(skeys.values()), sum(dkeys.values()), len(cs), len(useful), len(dem), sum(skeys[k] for k in unenc_keys), len(unenc_keys), time.time() - t0))
for k in sorted(unenc_keys, key=lambda k: -skeys[k])[:5]:
    sys.stderr.write('export:   not encodable: %s %s x%d\n' % (k[0], '/'.join(str(o) for o in k[1]), skeys[k]))
for k in sorted(unenc_keys, key=lambda k: -dkeys.get(k, 0))[:5]:
    if dkeys.get(k): sys.stderr.write('export:   not encodable, executed: %s %s x%d\n' % (k[0], '/'.join(str(o) for o in k[1]), dkeys[k]))
if a.python_solve:
    t1 = time.time()
    forms, best, tot, used, unenc = solve(forced, cs, skeys, a.budget, verbose=False, fallback=fallback, refine=6)
    names = [f.name for f in forms]
    credit = sum(n * min([b] + [2 * cs[useful[x]].n for x in atoms if cs[useful[x]].name in set(names)]) for (b, o, atoms), (n, nd, nk) in dem.items())
    sys.stderr.write('export: the study\'s solve.solve (greedy, five exponents, local search of 6 rounds): %d forms, credit objective %d, bytes %d (excluding %d unencodable), %.1fs\n' % (len(names), credit, tot, sum(n for k, n in skeys.items() if best[k] >= 99), time.time() - t1))
    open(a.python_solve, 'w').write(''.join('chosen %s\n' % n for n in names))
out = sys.stdout if a.out == '-' else open(a.out, 'w')
w = out.write
w('# encopt input, written by export.py from the 32-register compile of the corpus (%d instructions, %d distinct instructions)%s\n' % (sum(skeys.values()), len([k for k in skeys if skeys[k]]),
  ('; plus the dynamic counts of %d executed instructions (%d distinct)' % (sum(dkeys.values()), len(dkeys))) if dkeys else ''))
w('# the instruction bytes are per instruction class: base (what the forced forms give; 99 = no form: the byte credit of the optimiser) and the size of the form that shortens it\n')
w('# demand STATIC DYNAMIC BASE OPS K CANDIDATE...   OPS: operations under the forced forms (1; 2 for a cbCC no form reaches; 99 no form)\n')
w('encopt-input 2\n')
w('budget %d 65536\n' % int(round(a.budget * 65536)))
w('lam %g\n' % a.lam)
for f in forced:
    w('form %s forced %d %d %d %s\n' % (f.name, f.n, f.Lleaf, f.xbits, ' '.join(f.mns)))
for ci in useful:
    f = cs[ci]
    w('form %s cand %d %d %d %s\n' % (f.name, f.n, f.Lleaf, f.xbits, ' '.join(f.mns)))
for (b, o, atoms), (n, nd, nk) in sorted(dem.items(), key=lambda x: (-x[1][0], -x[1][1], x[0])):
    w('demand %d %d %d %d %d %s\n' % (n, nd, b, o, len(atoms), ' '.join(map(str, atoms))))
if not a.no_committed:
    have = {cs[ci].name for ci in useful}
    for f in d['forms']:        # the catalogue order of the grammar: it fixes the order of the leaves, hence the prefixes
        if f['name'] in have: w('committed %s\n' % f['name'])
    # the forms of the committed grammar that are neither forced nor candidate here are reported
    fn = {f.name for f in forced} | {cs[ci].name for ci in useful}
    miss = [f['name'] for f in d['forms'] if f['name'] not in fn]
    if miss: sys.stderr.write('export: committed forms not in the candidate set: %s\n' % ' '.join(miss))
# the committed model bytes, for the side-by-side report
sc0, tot0, lost0 = model_bytes([f for f in forced] + [cs[ci] for ci in useful if cs[ci].name in {f['name'] for f in d['forms']}], skeys)
sys.stderr.write('export: committed selection sized with the forms (keys fixed at the distances of the committed layout): %d bytes, %d instructions unencodable\n' % (tot0, lost0))
for k, n in sorted(skeys.items(), key=lambda kv: -kv[1]):
    if n and sc0.size1(k[0], k[1]) is None: sys.stderr.write('export:   not encodable with the committed forms: %s %s x%d\n' % (k[0], '/'.join(str(o) for o in k[1]), n))
if out is not sys.stdout: out.close()
