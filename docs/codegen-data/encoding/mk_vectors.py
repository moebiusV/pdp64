"""Writes the format vectors of the prefix-coded encodings, tests/enc/vectors-16.txt and vectors-32.txt: an instruction (the operand notation of
tests/enc/encdrv.c) and the parcels the Python prototype gives it (enc.py, from spec/pdp64-NN/pdp64-NN.hbnf; the shortest form that fits).  tools/check-enc.py
requires the C codec to produce the same parcels and to decode them back.  The vectors are chosen to show every length (1, 2, 3 and 5 parcels), the
hot-register fields, the sp-relative forms, the rare groups and the instructions the original encoding could not assemble.

    python3 mk_vectors.py
"""
import sys, os, json
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import enc
from enc import *
import importlib.util
spec = importlib.util.spec_from_file_location('chk', os.path.join(HERE, '..', '..', '..', 'tools', 'check-enc.py'))
chk = importlib.util.module_from_spec(spec); spec.loader.exec_module(chk)
ROOT = os.path.join(HERE, '..', '..', '..')
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import encgram

def P(s):
    f = s.split(); mn = f[0]; ops = []
    for t in f[1:]:
        x = t.split(':'); k = x[0]; ext = len(x) > (3 if k == 'PC' or k == 'A' or k == 'I' else 99)
        if k == 'R': ops.append(('R', int(x[1])))
        elif k == 'I': ops.append(('I', int(x[1])))
        elif k == 'B': ops.append(('B', int(x[1]), int(x[2])))
        elif k == 'X': ops.append(('X', int(x[1]), int(x[2]), int(x[3]), int(x[4])))
        elif k in ('PI', 'PD'): ops.append((k, int(x[1]), int(x[2])))
        elif k == 'PC': ops.append(('PC', None if len(x) > 2 else int(x[1])))
        elif k == 'A': ops.append(('A', None if len(x) > 2 else int(x[1])))
    return mn, tuple(ops)

COMMON = [
 ('1 parcel: register move, both registers hot or not (a 4-bit field each)', 'movq R:1 R:2'),
 ('', 'movq R:15 R:0'), ('', 'add R:3 R:4'), ('', 'cmp R:7 R:6'),
 ('movq #imm, one parcel', 'movq I:5 R:3'), ('', 'movq I:-64 R:15'), ('', 'movq I:63 R:0'),
 ('sp-relative load/store, scaled offset', 'movq B:8:14 R:3'), ('', 'movq R:3 B:16:14'), ('', 'movl B:12:14 R:5'),
 ('hot-register base and destination, a scaled offset in one parcel', 'movq B:8:8 R:1'), ('', 'movq R:0 B:16:9'),
 ('2 parcels: 12-bit displacement', 'movq B:400:5 R:3'), ('', 'movl B:-20:3 R:2'),
 ('3 parcels: a 32-bit displacement, a 32-bit immediate', 'movq B:100000:1 R:2'), ('', 'add I:100000 R:2'),
 ('indexed', 'movq X:8:1:2:8 R:3'), ('', 'movq R:3 X:0:1:2:1'),
 ('post-increment and pre-decrement', 'movq PI:4:0 R:5'), ('', 'movq R:5 PD:4:0'),
 ('branches: pc-relative field counts parcels', 'br PC:6'), ('', 'bne PC:-20'), ('', 'beq PC:2000'), ('', 'br PC:300000'),
 ('compare and branch', 'cbeq R:3 I:0 PC:8'), ('', 'cbne R:1 R:2 PC:-30'), ('', 'cblt R:4 I:100 PC:60'), ('', 'cbpl R:4 I:3 PC:8'),
 ('call; an external reference needs a 32-bit field', 'call PC:200'), ('', 'call PC:0:E'), ('', 'lea PC:0:E R:1'), ('', 'movq A:0:E R:2'),
 ('no operand', 'ret'), ('', 'nop'), ('', 'halt'), ('', 'lpad'),
 ('system: trap, trapl (one 8-bit vector), set, mfsr', 'trap I:3'), ('', 'trapl I:200'), ('', 'set I:2 R:3'), ('', 'mfsr R:2 I:12'), ('', 'mtsr I:1 R:2'),
 ('trapcc, isync, hint, pushx', 'trapcc.eq'), ('', 'isync'), ('', 'hint I:165'), ('', 'pushx'),
 ('three and four registers: ATOM', 'xadd R:1 R:2 R:3'), ('', 'cas R:1 R:2 R:3 R:4'), ('', 'swapdb R:1 R:2 R:3'), ('', 'll R:1 R:2 R:3'), ('', 'sc R:1 R:2 R:3'),
 ('MESC', 'movub B:8:3 R:2'), ('', 'movul B:8:3 R:2'), ('', 'addm R:1 B:16:2'), ('', 'bism R:1 B:0:2'),
 ('new instructions', 'maskeqz R:1 R:2 R:3'), ('', 'masknez R:1 R:2 R:3'), ('', 'bsel R:1 R:2 R:3 R:4'), ('', 'aeses R:1 R:2 R:3'), ('', 'aesks1 R:1 I:3 R:2'),
 ('', 'sha256sum0 R:1 R:2'), ('', 'maesctr R:1 R:2 R:3 R:4'), ('', 'addv R:1 R:2'), ('', 'mulv R:1 R:2'),
 ('fused pairs', 'movcall R:1 R:2 PC:100'), ('', 'movcall R:1 R:2 PC:0:E'), ('', 'popmret I:36608'), ('', 'popret R:3'), ('', 'mov2 R:1 R:2 R:8 R:3'),
 ('user-qualified loads and stores', 'movq.u B:8:1 R:2'), ('', 'movb.ud B:8:1 R:2'),
 ('bit fields, rotates', 'extb R:1 I:4 I:8 R:2'), ('', 'dshr R:1 R:2 I:3 R:4'), ('', 'rori32 R:1 I:5 R:2'), ('', 'rol R:1 I:3 R:2'),
 ('MOVQL: five parcels, a 64-bit immediate', 'movql I:1311768467463790320 R:4'), ('', 'movql I:-1 R:0'),
 ('push/pop, masks', 'pushm I:36608'), ('', 'popm I:256'), ('', 'push R:3'), ('', 'push I:100000'),
]
R32 = [
 ('registers r16-r31: 5-bit fields', 'movq R:17 R:20'), ('', 'add R:31 R:30'), ('', 'xor R:16 R:1'), ('', 'movq B:8:24 R:25'), ('', 'movq B:100:17 R:30'),
 ('the eight register-register mnemonics have a 5-bit one-parcel form', 'shl R:31 R:30'), ('', 'bis R:16 R:17'), ('', 'sub R:20 R:21'),
 ('', 'cmp R:20 R:21'), ('', 'movq X:0:16:31:8 R:18'), ('', 'cbeq R:19 I:0 PC:8'), ('', 'cbne R:30 R:31 PC:16'),
 ('', 'xadd R:17 R:18 R:19'), ('', 'cas R:20 R:21 R:22 R:23'), ('', 'bsel R:24 R:25 R:26 R:27'),
]
for which in ('16', '32'):
    d = encgram.load(which, ROOT)
    forms = [Form(f['name'], f['n'], f['mns'], [chk.mkspec(s) for s in f['specs']], xbits=f['xbits']) for f in d['forms']]
    code = Code(forms)
    import collections
    by_mn = collections.defaultdict(list)
    for i, f in enumerate(forms):
        for m in f.mns: by_mn[m].append((f.n, i, f))
    for m in by_mn: by_mn[m].sort(key=lambda x: (x[0], x[1]))
    enc.RELOC = 'max'
    out = ['# format vectors of pdp64/%s: the instruction, then `|` and the number of parcels and the parcels (hex, parcel 0 first), from the Python prototype' % which,
           '# (docs/codegen-data/encoding/mk_vectors.py); `PC:v:E`, `A:v:E` is an unresolved external (its field is 0)']
    for note, s in COMMON + (R32 if which == '32' else []):
        if note: out.append('# ' + note)
        mn, ops = P(s)
        r = None
        for n, i, f in by_mn[mn]:
            v = f.fit(mn, ops)
            if v is not None: r = (f, v); break
        assert r is not None, (which, s)
        f, vals = r
        lf = next(l for l in code.leaves if l.form is f and mn in l.mns)
        ws = words_of(build_word(lf, mn, vals), f.n)
        out.append('%s | %d %s' % (s, f.n, ' '.join('%04x' % w for w in ws)))
    open(os.path.join(ROOT, 'tests', 'enc', 'vectors-%s.txt' % which), 'w').write('\n'.join(out) + '\n')
    print(which, len(out))
