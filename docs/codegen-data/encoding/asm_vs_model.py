"""The real assembler against the Python model: for every file of the corpus, the length of every instruction as64 produced (as64 --dump-lens)
against the length the model's scheme gives it (scheme.py: choose the shortest form, relax against real distances).

    python3 asm_vs_model.py 16|32 OUTDIR 

OUTDIR holds NAME.lens for each corpus file (as64 -m pdp64/NN --dump-lens OUTDIR/NAME.lens ...).  The scheme is rebuilt from
spec/pdp64-NN/forms.json (enc.Form objects), not re-solved.  Paths of the corpus are those of load.py."""
import sys, os, json, collections, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from variants import *
import enc
from enc import *
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'tools'))
import importlib.util
spec = importlib.util.spec_from_file_location('chk', os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'tools', 'check-enc.py'))
chk = importlib.util.module_from_spec(spec); spec.loader.exec_module(chk)
FZ = ('movcall', 'popmret', 'popret', 'mov2')
which, outdir = sys.argv[1], sys.argv[2]
tag = 'base16' if which == '16' else 'r32'
d = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'spec', 'pdp64-' + which, 'forms.json')))
forms = [Form(f['name'], f['n'], f['mns'], [chk.mkspec(s) for s in f['specs']], xbits=f['xbits']) for f in d['forms']]
sc = Scheme(forms)
enc.RELOC = 'max'
corp = corpus(tag)
dec_in = []; dec_exp = []
tot_model = tot_as = ninsn = nmis = nfiles = nbytes_ = nbytes_bad = npool_ = 0
badfiles = []
mnbad = collections.Counter()
for fn, ev, recs in corp:
    total = layout(ev, sc.lenfun)
    lens = []; words = []
    for r in recs:
        mn, ops = inst_of(r, r['dist'])
        p = sc.plan(mn, ops)
        if p is None: lens.append(('unencodable', mn)); continue
        for m, o in p:
            lens.append((sc.size1(m, o) // 2, m))
            # the parcels with an unresolved external as 0 (as64 leaves the field to the linker); the form is the one chosen with the external unknown
            f, vals = sc.choose(m, o)
            o0 = tuple((x[0], 0) + x[2:] if (x[0] in ('PC', 'A') and x[1] is None) else x for x in o)
            v0 = f.fit(m, o0)
            lf = next(l for l in sc.code.leaves if l.form is f and m in l.mns)
            words.append((m, r['pool'], words_of(build_word(lf, m, v0), f.n), o, f.name))
    rows = [tuple(int(x) for x in l.split()) for l in open(os.path.join(outdir, fn + '.lens'))]
    got = [x[1] for x in rows]
    d_ = open(os.path.join(outdir, fn + '.o'), 'rb').read()
    shoff = struct.unpack_from('<Q', d_, 0x28)[0]
    toff, tsize = struct.unpack_from('<QQ', d_, shoff + 64 + 24)
    exp = [l[0] if l[0] != 'unencodable' else None for l in lens]
    nfiles += 1
    tot_model += sum(2 * x for x in exp if x); tot_as += 2 * sum(got); ninsn += len(got)
    if exp == got:
        for (m, pool, ws, oo, fname), row in zip(words, rows):
            if not pool:
                have_ = ' '.join('%04x' % struct.unpack_from('<H', d_, toff + row[2] + 2 * k)[0] for k in range(row[1]))
                dec_in.append(have_)
                dec_exp.append('%d %s' % (row[1], m + ''.join(' ' + chk.tok((x[0], 0) + x[2:] if (x[0] in ('PC', 'A') and x[1] is None) else x) for x in oo)))
            if pool: npool_ += 1; continue          # the model gives a literal-pool load a pseudo distance (32000); as64 knows the pool
            nbytes_ += 1
            have = [struct.unpack_from('<H', d_, toff + row[2] + 2 * k)[0] for k in range(row[1])]
            if have != ws:
                nbytes_bad += 1
                if nbytes_bad <= 5: print('BYTES differ in', fn, m, oo, fname, ['%04x' % x for x in ws], ['%04x' % x for x in have])
    if exp != got:
        badfiles.append(fn)
        # first difference
        for i, (a, b) in enumerate(zip(exp + [None] * len(got), got + [None] * len(exp))):
            if a != b:
                nmis += 1
                mnbad[lens[i][1] if i < len(lens) else '?'] += 1
                if len(badfiles) <= 3: print('first difference in', fn, 'at hardware instruction', i, 'model', a, 'as64', b, lens[i] if i < len(lens) else '')
                break
print('pdp64/%s%s: %d files, %d instructions (as64), model %d bytes, as64 %d bytes, %d files that differ' % (which, '', nfiles, ninsn, tot_model, tot_as, len(badfiles)))
print('first-difference mnemonics:', mnbad.most_common(8))
print('parcels compared one by one in the files whose lengths agree: %d instructions, %d differ (%d literal-pool loads left out: the model\'s distance for them is a pseudo value)' % (nbytes_, nbytes_bad, npool_))

import subprocess
out = subprocess.run([os.path.join(chk.B, 'encdrv'), '-d', which], input='\n'.join(dec_in) + '\n', capture_output=True, text=True).stdout.split('\n')
bad = 0
for a, b in zip(dec_exp, out):
    if a != b:
        bad += 1
        if bad <= 5: print('DECODE differs: wanted', a, 'got', b)
print('decoded back with the C decoder: %d instructions, %d differ from the source' % (len(dec_in), bad))
