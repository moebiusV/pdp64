"""Writes the link test of the encoding, tests/ld (link.words, link.map; main.s, lib.s and high.s are the sources there).

The expected linked words come from the Python prototype, not from as64 or ld64: each instruction of tests/ld/main.s and lib.s is encoded with the form
the prototype chooses for an unresolved external (a 32-bit field) and the field is then given the value the linking rules say (S + A - P in bytes, divided by the
unit of the field for a pc-relative operand; S + A for an absolute or immediate one), the layout being: text at 0x10000, main.o then lib.o, data on the next page.

    python3 mk_ld_tests.py
"""
import sys, os, json, shutil
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
import collections

for which in ('32',):
    d = encgram.load(ROOT)
    forms = [Form(f['name'], f['n'], f['mns'], [chk.mkspec(s) for s in f['specs']], xbits=f['xbits']) for f in d['forms']]
    code = Code(forms)
    by_mn = collections.defaultdict(list)
    for i, f in enumerate(forms):
        for m in f.mns: by_mn[m].append((f.n, i, f))
    for m in by_mn: by_mn[m].sort(key=lambda x: (x[0], x[1]))
    enc.RELOC = 'max'
    def enc1(mn, ops_ext, ops_final):
        for n, i, f in by_mn[mn]:
            if f.fit(mn, ops_ext) is not None:
                v = f.fit(mn, ops_final)
                assert v is not None
                lf = next(l for l in code.leaves if l.form is f and mn in l.mns)
                return f, words_of(build_word(lf, mn, v), f.n)
        raise ValueError
    def unit(f):
        return [sp.unit for sp in f.specs if isinstance(sp, SPC)]
    TEXT = 0x10000; DATA = 0x11000
    # sizes first (with the externals unknown): main.s = movq #msg,r1 ; call f ; bne f ; movq val(pc),r2 ; halt   lib.s = ret
    ext = [('movq', (('I', 0x11000), ('R', 1)), 'I'), ('call', (('PC', None),), 'PC'), ('bne', (('PC', None),), 'PC'), ('movq', (('PC', None), ('R', 2)), 'PC'), ('halt', (), '-')]
    sizes = []
    for mn, ops, kind in ext:
        # movq #msg is an unresolved immediate: the prototype's immediate fields are signed, 32 bits is the widest
        for n, i, f in by_mn[mn]:
            if kind == 'I':
                if f.fit(mn, ops) is not None and any(isinstance(sp, SI) and sp.w >= 32 for sp in f.specs) or False: pass
            if f.fit(mn, ops if kind != 'PC' else ops) is not None:
                sizes.append(f.n); break
    # movq #msg,r1: the value 0x11000 does not tell the form; an external immediate needs a form of 32 bits or more
    f_imm = next(f for n, i, f in by_mn['movq'] if any(isinstance(sp, SI) and sp.w >= 32 and sp.signed for sp in f.specs) and f.kinds == ('I', 'R'))
    sizes[0] = f_imm.n
    main_len = 2 * sum(sizes)
    f_addr = TEXT + main_len                          # f: in lib.o, after main.o's text
    words = []
    pos = TEXT
    # movq #msg, r1
    lf = next(l for l in code.leaves if l.form is f_imm and 'movq' in l.mns)
    words += words_of(build_word(lf, 'movq', f_imm.fit('movq', (('I', 0x11000), ('R', 1)))), f_imm.n); pos += 2 * f_imm.n
    for mn, ops, kind in ext[1:4]:
        P_ = pos
        exto = tuple(('PC', None) if o[0] == 'PC' else o for o in ops)
        tgt = f_addr if mn in ('call', 'bne') else DATA + 8          # f, or val
        final = tuple(('PC', tgt - P_) if o[0] == 'PC' else o for o in ops)
        f, w = enc1(mn, exto, final)
        words += w; pos += 2 * f.n
    f, w = enc1('halt', (), ()); words += w; pos += 2 * f.n
    assert pos == f_addr
    f, w = enc1('ret', (), ()); words += w
    out = os.path.join(ROOT, 'tests', 'ld')
    open(os.path.join(out, 'link.words'), 'w').write(' '.join('%04x' % x for x in words) + '\n')
    open(os.path.join(out, 'link.map'), 'w').write('0x%016x _start\n0x%016x f\n0x%016x val\n' % (TEXT, f_addr, DATA + 8))
    print(which, 'text parcels', len(words), 'f at %#x' % f_addr)
