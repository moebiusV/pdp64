#!/usr/bin/env python3
"""write_hbnf -- write an encoding as hbnf grammars (spec/pdp64-enc.hbnf, spec/pdp64-NN/pdp64-NN.hbnf).

The optimiser (export_forms.py) lays out the forms and leaves of an encoding; this writes them as the grammars that are the source of truth of the
encoding (spec/README.md, "The grammars").  The same text is what a person edits by hand.  From the grammars everything is generated (tools/mkenc.py,
which reads them through tools/encgram.py); nothing reads the optimiser's data.

    write_hbnf.py OUTDIR  16=forms16.json  32=forms32.json      write OUTDIR/pdp64-enc.hbnf, OUTDIR/pdp64-16/pdp64-16.hbnf, OUTDIR/pdp64-32/pdp64-32.hbnf
    (export_forms.py calls write_all() with the optimiser's dicts; the JSON form is only for running this on a dict someone kept)

The input is the dict the optimiser produces (the shape of export_forms.py's output), or what tools/encgram.py.load() returns.  The vocabulary of the
grammars (rule and field names) is defined in the header written into spec/pdp64-enc.hbnf; tools/encgram.py is its reader.
"""
import json, os, re, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'tools'))
from encgram import guard_text, leaf_pieces, runs as _runs

SIZES = [(8, ['movq']), (4, ['movl', 'movzl']), (2, ['movw', 'movzw']), (1, ['movb', 'movzb'])]
FUSED_DOC = {'movcall': 'movq rs,rd ; call label', 'popmret': 'popm #mask ; ret', 'popret': 'pop rd ; ret', 'mov2': 'movq ra,rb ; movq rc,rd'}


def mangle(name):
    return re.sub(r'[./_]', '-', name)


def family(name):
    """The family of a form, as the optimiser groups them (docs/codegen-data/encoding/fam.py)."""
    k = re.sub(r'(_?\d+)?(/.*)?$', '', name)
    return re.sub(r'[hH]$', '', k) if len(k) > 4 else k


def regname(r):
    return {14: 'sp', 13: 'fp'}.get(r, 'r%d' % r)


# ---------------------------------------------------------------- shapes
def shape(s):
    """(rule name, body) of an operand spec.  The name carries the kind and the attributes the body cannot (scale, unit, signedness of an absent field)."""
    k = s['k']
    sg = lambda v: 's' if v else 'u'
    def fld(name, w, signed=False):
        return '%s:%d%s' % (name, w, 's' if signed and w else '') if w else None
    if k == 'R':
        return 'reg%d' % s['w'], 'r:%d' % s['w']
    if k == 'K':
        kind, v = s['op']
        if kind == 'R':
            return {14: ('k-sp', 'sp:bits(0)'), 16: ('k-dp', 'dp:bits(0)')}.get(v) or ('k-r%d' % v, 'r%d:bits(0)' % v)
        return 'k-imm%d' % v, 'imm%d:bits(0)' % v
    if k == 'I':
        assert s['vals'] is None
        sc = '' if s['scale'] == 1 else '-x%d' % s['scale']
        return 'imm%d%s%s' % (s['w'], sg(s['signed']), sc), fld('imm', s['w'], s['signed'])
    if k == 'B':
        rn = s['rn']
        if rn['k'] == 'K':                           # d(sp), d(dp): the base takes no bits
            assert rn['op'][0] == 'R' and rn['op'][1] in (14, 16) and s['dw']
            base, parts = {14: 'sp', 16: 'dp'}[rn['op'][1]], []
        else:
            base, parts = 'b%d' % rn['w'], ['base:%d' % rn['w']]
        parts += [fld('d', s['dw'], s['signed'])] if s['dw'] else []
        return '%sd%d%s-x%s' % (base if rn['k'] == 'K' else base, s['dw'], sg(s['signed']), s['scale']), ' '.join(parts) or 'none:bits(0)'
    if k == 'X':
        a, b = s['rn']['w'], s['rx']['w']
        parts = ['base:%d' % a, 'index:%d' % b, 'scale:2'] + ([fld('d', s['dw'], s['signed'])] if s['dw'] else [])
        return 'x%d-%dd%d%s' % (a, b, s['dw'], sg(s['signed'])), ' '.join(parts)
    if k in ('PI', 'PD'):
        rw = s['rn']['w']
        return '%s%d-s%d' % (k.lower(), rw, s['dw']), ' '.join(['base:%d' % rw] + (['stride:%d' % s['dw']] if s['dw'] else []))
    if k == 'PC':
        return 'pc%d-u%d' % (s['w'], s['unit']), 'pcrel:%d' % s['w']
    if k == 'A':
        return 'abs%d' % s['w'], 'abs:%d' % s['w']
    raise ValueError(k)



# ---------------------------------------------------------------- text helpers
def wrap(head, items, sep=' | ', width=150, cont='     | '):
    """head + items joined by sep, wrapped before an item that would pass the width; the continuation lines begin with `cont`."""
    lines = []
    cur = head + items[0]
    for it in items[1:]:
        if len(cur) + len(sep) + len(it) > width:
            lines.append(cur)
            cur = cont + it
        else:
            cur += sep + it
    lines.append(cur)
    return '\n'.join(lines)


# ---------------------------------------------------------------- the shared grammar
HEADER_SHARED = r'''; pdp64-enc.hbnf -- what the prefix-coded encodings (pdp64/16, pdp64/32) have in common.  Written by docs/codegen-data/encoding/write_hbnf.py
; from the optimiser's layout, and edited by hand from then on; tools/mkenc.py reads it (through tools/encgram.py) and the members' grammars
; (pdp64-16/pdp64-16.hbnf, pdp64-32/pdp64-32.hbnf) include it.  Nothing else holds the encodings: see spec/README.md.
;
; HOW THE GRAMMARS DESCRIBE AN ENCODING
;
; The input is one instruction: a record of bit fields, read from the top bit of parcel 0, parcel after parcel, each parcel big-endian (the
; same convention as pdp64.hbnf.in: in memory the parcels are little-endian and the reader swaps them).  hbnf numbers bits from the top, so the
; first field of a record is bits 15... of parcel 0 and a field that runs on from parcel k to parcel k+1 is one field.
;
; A LEAF is one alternative of `insn`: the prefix (a constant, as wide as its binary digits: 1 to 16 bits), then the sub-opcode `sub` (or `xsub`),
; then the pieces of the operands, in the order of the bits.  There is no padding: the fields cover the 16*n bits of the n parcels exactly (the
; length of an instruction is a function of its prefix alone).  A leaf is named leaf-FORM-K (K = 1, 2, ... in the order of the sub-opcode ranges).
;
;   sub:J     J bits (binary-aligned) selecting one of the mnemonics of the leaf; the mnemonics are the enum rule sub-FORM-K, numbered 0, 1, 2...
;             (`sub-FORM-K` is the leaf's `leaf-FORM-K` with the prefix `sub-`); a number the enum does not have is illegal (`?(sub < N)`)
;   xsub:W    the same, for the forms that give the mnemonic index W bits of its own wherever they are (the leaf lists the whole mnemonic list)
;   oI-PART   a field (or the first piece of a field) of operand I (1 is the first operand of the assembly syntax); PART is a field of the operand's shape;
;   oI-PART-N the Nth piece (from the top) of a field that the layout splits in two or more places
;
; A FORM is the list of operand shapes of the leaves that share it, form-FORM = o1:shape o2:shape ...  A SHAPE is the operand as the assembly
; language writes it and the fields it is made of (their widths, `s` for signed); the order of the fields of a shape is the order of its parts.
; The name of a shape holds what the fields cannot say:
;
;   regW                 a register, W bits.  W bits that cannot name every register of the member (hotW in the member's grammar) are an index into that table
;   immW[s|u][-xS]       an immediate of W bits, signed or not, in units of S (1 if omitted)
;   bRdD[s|u]-xS         base register of R bits and displacement of D bits (D = 0: none), in units of S bytes; S = sz is the size of the access
;   spdD[s|u]-xS, dpdD   the same with (sp) or the direct page register (dp) as the base, which takes no bits
;   xR-RxdD[s|u]        indexed: base R bits, index Rx bits, scale 2 bits, displacement D bits
;   piR-sD, pdR-sD       (r)+ and -(r): base R bits and a stride field of D bits (0 stride means the size of the access)
;   pcW-uU               pc-relative, W bits, U bytes to the unit (2: the field counts parcels)
;   absW                 absolute address of W bits
;   k-sp, k-dp, k-imm0   a constant operand that takes no bits: (sp), (dp) (direct page), #0
;
; The assembler tries the forms of a mnemonic in the order of the `forms` catalogue of the member's grammar (the number is the index of the form), the shorter
; first; the order of the leaves of one form is the order of their numbers.  Everything else is generated from this: the C tables of the codec
; (build/pdp64-NN-tab.c), the assembly grammar of as64 (build/x/), the tables of spec/pdp64-NN/tables.md.
prefix none
'''


def write_shared(ds):
    shapes = {}
    for d in ds:
        for f in d['forms']:
            for s in f['specs']:
                n, b = shape(s)
                assert shapes.setdefault(n, b) == b, (n, b, shapes[n])
    out = [HEADER_SHARED]
    kinds = [('R', 'a register', lambda n: n.startswith('reg')),
             ('K', 'a constant operand (no bits)', lambda n: n.startswith('k-')),
             ('I', 'an immediate', lambda n: n.startswith('imm')),
             ('B', 'base register and displacement: d(rb)', lambda n: re.match(r'(b\d|sp|dp)', n)),
             ('X', 'indexed: d(rb,rx,scale)', lambda n: n.startswith('x')),
             ('P', 'auto-increment (r)+ and auto-decrement -(r)', lambda n: n[:2] in ('pi', 'pd')),
             ('C', 'pc-relative', lambda n: n.startswith('pc')),
             ('A', 'absolute', lambda n: n.startswith('abs'))]
    seen = set()
    for key, title, pred in kinds:
        names = sorted((n for n in shapes if pred(n) and n not in seen), key=lambda n: (len(n), n))
        if not names:
            continue
        out.append('; ---- operand shapes: %s\n' % title)
        for n in names:
            seen.add(n)
            out.append('%-14s = %s' % (n, shapes[n]))
        out.append('')
    assert seen == set(shapes), set(shapes) - seen
    out.append('; ---- no operand\nnoop           = none:bits(0)\n')
    out.append('; ---- the size of the access of the moves, in bytes: the words of each rule (a suffix after a dot, .u .d .ud, does not change it); every other mnemonic: 1')
    for sz, words in SIZES:
        out.append('acc-%d = %s' % (sz, ' | '.join('"%s"' % w for w in words)))
    out.append('')
    # the words only the prefix-coded encodings have: set by the caller (needs the words of the original grammar)
    return '\n'.join(out) + '\n'


def write_ext(words):
    """mn-ext: the words of the prefix-coded encodings that the original mnemonic grammar does not have; the number is the position (the C table ext_names)."""
    return '; ---- the mnemonics that only the prefix-coded encodings have (group mn-ext of the assembly grammar of as64): the number is the position in the list\n' + \
           wrap('mn-ext = ', ['"%s"@%d' % (w, i) for i, w in enumerate(words)], cont='       | ') + '\n'


# ---------------------------------------------------------------- a member
def write_member(d, tag):
    forms, leaves = d['forms'], d['leaves']
    names = [mangle(f['name']) for f in forms]
    assert len(set(names)) == len(names) and len(set(n.lower() for n in names)) == len(names), 'form names collide when mangled'
    nreg = d['registers']
    out = []
    o = out.append
    o('; %s: the grammar of the encoding -- %d registers (r0-r%d), %d forms, %d leaves.\n;' % (d['name'], nreg, nreg - 1, len(forms), len(leaves)))
    o('; Written by docs/codegen-data/encoding/write_hbnf.py and edited by hand from then on (the vocabulary is in pdp64-enc.hbnf, the workflow in spec/README.md).')
    o('; Everything the codec, the assembler, the linker, the simulator and the documentation know of this encoding is generated from this file.\n')
    o('prefix none')
    o('include "../pdp64-enc.hbnf"\n')
    # the root, which must be the first rule (hbnf reads a grammar whose first rule is a bit rule as bits alone: parse_bits is then the decoder of the encoding):
    # one leaf; the prefixes are disjoint, so the order of the alternatives matters to a reader only
    lnames = []
    for li, lf in enumerate(leaves):
        lnames.append('leaf-%s-%d' % (names[lf['form']], 1 + sum(1 for x in leaves[:li] if x['form'] == lf['form'])))
    free = 65536 - sum(1 << (16 - lf['L']) for lf in leaves)
    o('; The instruction: one leaf.  A first parcel that no leaf matches (%s of the 65,536) is an illegal instruction.' % format(free, ','))
    o(wrap('insn = leaf:( ', lnames, cont='       | ') + ' )\n')
    o('encoding-name = "%s"\n' % d['name'])
    # registers
    o('; ---- the registers\n' + wrap('regs = ', ['"r%d"@%d' % (i, i) for i in range(nreg)], cont='     | '))
    o('; A register field of W bits that cannot hold a register number is an index into the table hotW (the part of the ABI the encoding depends on, docs/abi.md).')
    o(wrap('hot3 = ', ['"%s"' % regname(r) for r in d['hot8']], cont='     | '))
    if d['hot16']:
        o(wrap('hot4 = ', ['"%s"' % regname(r) for r in d['hot16']], cont='     | '))
    o('')
    o('; ---- the fused instructions (the assembler never fuses: they are ordinary mnemonics with operands, chosen by the compiler)')
    o('fused = ' + ' | '.join('"%s"' % m for m in d['fused']) + '\n')
    # the catalogue
    o('; ---- the catalogue of forms: the number is the index of the form (the assembler tries the forms of a mnemonic, shorter first, in this order)')
    o(wrap('forms = ', ['"%s"@%d' % (f['name'], i) for i, f in enumerate(forms)], cont='      | '))
    o('')
    # families, in the order of their first form
    fams = []
    for i, f in enumerate(forms):
        fam = family(f['name'])
        if fam not in [x[0] for x in fams]:
            fams.append([fam, []])
        [x for x in fams if x[0] == fam][0][1].append(i)
    byform = {}
    for li, lf in enumerate(leaves):
        byform.setdefault(lf['form'], []).append(li)
    for fam, fidx in fams:
        mns = [m for i in fidx for m in forms[i]['mns']]
        o('; ' + '=' * 150)
        o('; family %s: %d form%s, %d leaves, %d parcel%s; mnemonics %s%s' % (fam, len(fidx), 's' if len(fidx) > 1 else '', sum(len(byform[i]) for i in fidx),
          forms[fidx[0]]['n'], '' if forms[fidx[0]]['n'] == 1 else 's', ' '.join(mns[:6]), ' ...' if len(mns) > 6 else ''))
        o('; ' + '=' * 150 + '\n')
        for fi in fidx:
            f = forms[fi]
            o('; form %s (index %d): %d parcel%s' % (f['name'], fi, f['n'], '' if f['n'] == 1 else 's'))
            if f['specs']:
                o('form-%s = %s' % (names[fi], ' '.join('o%d:%s' % (k + 1, shape(s)[0]) for k, s in enumerate(f['specs']))))
            else:
                o('form-%s = noop' % names[fi])
            for k, li in enumerate(byform[fi]):
                lf = leaves[li]
                o(write_leaf(lf, f, names[fi], k + 1, d))
            o('')
    return '\n'.join(out) + '\n'


def write_leaf(lf, f, mname, k, d):
    n16 = 16 * f['n']
    L = lf['L']
    nm = len(lf['mns'])
    pcs = leaf_pieces(lf, f['specs'])
    flds = ['0b' + format(lf['prefix'], '0%db' % L)] + ['%s:%d' % (name, w) for _, name, w, _ in pcs]
    assert L + sum(w for _, _, w, _ in pcs) == n16, (f['name'], lf)
    # the check that rejects the unused sub-opcodes
    for key in (('sub',), ('xsub',)):
        ws = [w for _, _, w, kk in pcs if kk == key]
        if ws and nm < 1 << sum(ws):
            flds.append(guard_text(key[0], ws, nm))
    leaf = 'leaf-%s-%d' % (mname, k)
    text = wrap('%s = ' % leaf, flds, sep=' ', width=150, cont='        ')
    en = wrap('sub-%s-%d = ' % (mname, k), ['"%s"' % m for m in lf['mns']], cont='     | ')
    return text + '\n' + en


# ---------------------------------------------------------------- main
def write_all(out, ds):
    """ds = [(tag, dict)]; writes out/pdp64-enc.hbnf and out/pdp64-TAG/pdp64-TAG.hbnf"""
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'tools'))
    import mkgrammar
    en = mkgrammar.enums(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'spec', 'pdp64-mnemonics.hbnf'))
    old = {lit for g, items in en.items() if g.startswith('mn-') for lit, v in items} | {'rol'}
    allmn = sorted({m for _, d in ds for f in d['forms'] for m in f['mns']} - old)
    os.makedirs(out, exist_ok=True)
    open(os.path.join(out, 'pdp64-enc.hbnf'), 'w').write(write_shared([d for _, d in ds]) + '\n' + write_ext(allmn))
    for tag, d in ds:
        os.makedirs(os.path.join(out, 'pdp64-' + tag), exist_ok=True)
        open(os.path.join(out, 'pdp64-' + tag, 'pdp64-%s.hbnf' % tag), 'w').write(write_member(d, tag))


def main():
    ds = []
    for a in sys.argv[2:]:
        tag, path = a.split('=')
        ds.append((tag, json.load(open(path))))
    write_all(sys.argv[1], ds)


if __name__ == '__main__':
    main()
