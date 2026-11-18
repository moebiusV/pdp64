#!/usr/bin/env python3
"""vec-glance.py -- the "family at a glance" table of docs/encoding-work/vec-isa.md, generated from the grammar so that it cannot be wrong.

The words, the base mnemonics and their suffixes are read from spec/pdp64/pdp64.hbnf (the quoted vector words of the families VBEG ... VSTS.R).  The compiler path is read
from llvm/vector-usage.md (the table "By instruction": words used by the vecloop and the LoopVectorize builds) and, for a word that no compiled kernel uses, from the
hand-written kernels of docs/encoding-work/arch-data/vec-forms (*.s).  The one-line meaning and the wave of origin are written below (META); the script stops if the
grammar has a base mnemonic META lacks, or META has one the grammar no longer has.

    tools/vec-glance.py             print the table (markdown) and the counts
    tools/vec-glance.py --check F   compare the text of F between the markers <!-- vec-glance:begin --> and <!-- vec-glance:end --> with the table; exit 1 if it differs
    tools/vec-glance.py --update F  rewrite that text in F
"""
import os, re, sys, glob, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GRAMMAR = os.path.join(ROOT, 'spec', 'pdp64', 'pdp64.hbnf')
USAGE = os.path.join(ROOT, 'llvm', 'vector-usage.md')
KERNELS = os.path.join(ROOT, 'docs', 'encoding-work', 'arch-data', 'vec-forms')
BEGIN, END = '<!-- vec-glance:begin -->', '<!-- vec-glance:end -->'

VEC_FAMILIES = {'VBEG', 'VEND', 'VFIN', 'VOP.VVV', 'VOP.VVR', 'VOP.VVI', 'VDACC', 'VTBLM', 'VOP.VV', 'VBSL', 'VOP.VR', 'VOP.VI', 'VFMAB', 'VACC', 'VFIR', 'VCLR',
                'VLD.PI', 'VLD.B', 'VST.PI', 'VST.B', 'VLDT', 'VSTT', 'VSTS.R'}

O, W1, W2, ST = 'original', 'wave 1', 'wave 2', 'errata 173'
# base mnemonic -> (wave of origin, meaning).  "original": in the family as added by errata 161 and kept; a word of such a base may have been added or removed later (vec-isa.md 6, 8).
META = {
    'vec': (O, 'begin a block over the region `[Rs, Re)`'),
    'vend': (O, 'end a block'),
    'vfin': (ST, 'split a block: what follows runs once after the last strip (the epilogue), on the final accumulators'),
    'vld': (O, 'load a strip, widening on the way in (`vld.<m>[.<lane>]`)'),
    'vst': (O, 'store a strip, truncating on the way out (`vst.<lane>[.<m>]`)'),
    'vsts': (O, 'narrowing store with clamping; with `#sh` a rounding shift first (the `#sh` form: wave 1)'),
    'vldt': (O, 'strided load (one field of an array of structures)'),
    'vstt': (O, 'strided store'),
    'vlseg2': (O, 'load 2 interleaved fields into `vD`, `vD+1`'),
    'vlseg3': (O, 'load 3 interleaved fields'),
    'vlseg4': (O, 'load 4 interleaved fields'),
    'vsseg2': (O, 'store 2 registers interleaved'),
    'vsseg3': (O, 'store 3 registers interleaved'),
    'vsseg4': (O, 'store 4 registers interleaved'),
    'vadd': (O, 'lane add (wrapping)'),
    'vsub': (O, 'lane subtract'),
    'vsubr': (O, 'reverse subtract: operand minus `vA`'),
    'vmul': (O, 'lane multiply, low half'),
    'vand': (O, 'bitwise and'),
    'vor': (O, 'bitwise or'),
    'vxor': (O, 'bitwise exclusive or'),
    'vshl': (O, 'shift left'),
    'vshr': (O, 'logical shift right'),
    'vsar': (O, 'arithmetic shift right'),
    'vabd': (O, 'signed absolute difference'),
    'vabdu': (O, 'unsigned absolute difference'),
    'vmin': (O, 'signed minimum'),
    'vmax': (O, 'signed maximum'),
    'vminu': (O, 'unsigned minimum'),
    'vmaxu': (O, 'unsigned maximum'),
    'vmov': (O, 'move a vector, a scalar register or an immediate to every lane'),
    'vneg': (O, 'negate'),
    'vadds': (O, 'signed saturating add'),
    'vsubs': (O, 'signed saturating subtract'),
    'vaddsu': (O, 'unsigned saturating add'),
    'vsubsu': (O, 'unsigned saturating subtract'),
    'vavg': (W1, 'rounding average `(a + b + 1) >> 1`, signed'),
    'vavgu': (W1, 'rounding average, unsigned'),
    'vmulh': (W1, 'high 16 bits of the 16 x 16 product, signed'),
    'vmulhu': (W1, 'high 16 bits of the 16 x 16 product, unsigned'),
    'vmulhr': (W1, 'Q15 rounding multiply, saturating'),
    'vsarr': (W1, 'arithmetic shift right that rounds'),
    'vshrr': (W1, 'logical shift right that rounds'),
    'vmla': (O, '`vD += vA * x` (x a scalar register: original; x a vector: wave 1)'),
    'vfma': (O, 'floating-point `vD += vA * x`'),
    'vfnma': (O, 'floating-point `vD -= vA * vB`'),
    'vfmab': (O, '`vD += vA * broadcast(*Ra)`, `Ra` moved by one element a strip (the micro-kernel; 16-byte strip)'),
    'vdot': (O, 'each 32-bit lane += the products of 4 bytes (`.b`) or 2 halfwords (`.w`, wave 1)'),
    'vdotu': (O, 'the same, unsigned bytes'),
    'vdotsu': (O, 'the same, signed by unsigned bytes'),
    'vdacc': (W1, '`Rd +=` the exact sum of the products of all lanes (a dot product reduced to a register)'),
    'vsad': (W1, '`Rd +=` the sum of absolute differences of unsigned bytes'),
    'vtbl': (W1, 'byte lookup in a 16-byte table in memory; 0 for an index of 16 or more (memory form only)'),
    'vceq': (W2, 'lane compare equal: a mask (all ones or zero)'),
    'vcgt': (W2, 'lane compare signed greater: a mask'),
    'vcgtu': (W2, 'lane compare unsigned greater: a mask'),
    'vbsl': (W2, 'bitwise select `(vM & vA) \\| (~vM & vB)`'),
    'vcvt': (W2, 'int32 <-> binary32 conversion (`vcvt.<from>.<to>`)'),
    'vacc': (O, '`Rd +=` the sum of the lanes, `vacc.<src>.<acc>` (the form: errata 168); floating point in the canonical order (errata 174)'),
    'vmaxacc': (O, '`Rd = max(Rd, the largest lane)`'),
    'vminacc': (O, '`Rd = min(Rd, the smallest lane)`'),
    'vfir': (O, 'sliding-window multiply-accumulate over `taps` scalar registers'),
    'vclr': (O, 'zero `count` registers and name them accumulators (16-byte strip)'),
}


def grammar_words():
    words, fam = [], None
    for line in open(GRAMMAR):
        m = re.match(r'; family (\S+):', line)
        if m:
            fam = m.group(1)
            continue
        if fam in VEC_FAMILIES:
            for w in re.findall(r'"(v[a-z0-9]+(?:\.[a-z]+)*)"', line):
                words.append(w)
    # a word may be listed in more than one operand form of the grammar: count each once
    return sorted(set(words))


def usage_rows():
    """base -> (words used, static uses vecloop, static uses lv), from the table By instruction of llvm/vector-usage.md"""
    rows = {}
    for line in open(USAGE):
        m = re.match(r'\| [^|]+ \| `(v[a-z0-9]+)` \| (\d+) \| (\d+) \| (\d+) \| (\d+) \|', line)
        if m:
            rows[m.group(1)] = (int(m.group(3)), int(m.group(4)), int(m.group(5)))
    return rows


def hand_kernels():
    """base mnemonic -> sorted names of the hand-written kernels (.s) that use it"""
    use = collections.defaultdict(set)
    for p in glob.glob(os.path.join(KERNELS, '**', '*.s'), recursive=True):
        if '.vecw1.' in p or '.scalar.' in p:
            continue
        for line in open(p):
            line = line.split(';')[0].split('#')[0]
            m = re.match(r'\s*(?:\w+:)?\s*(v[a-z0-9]+)', line)
            if m:
                use[m.group(1)].add(os.path.basename(p).split('.')[0])
    return use


def build():
    words = grammar_words()
    bases = collections.OrderedDict()
    for w in words:
        bases.setdefault(w.split('.')[0], []).append(w)
    if set(bases) != set(META):
        sys.exit('vec-glance: the grammar and META differ: grammar only %s, META only %s' % (sorted(set(bases) - set(META)), sorted(set(META) - set(bases))))
    use, hand = usage_rows(), hand_kernels()
    order, rest = list(META), []      # the order of META is the order of the groups of vec-isa.md section 2
    out = ['| base | suffixes of the words in the grammar | meaning | wave | selected by the compiler |', '|---|---|---|---|---|']
    nwords = 0
    for b in order + rest:
        ws = bases[b]
        nwords += len(ws)
        sfx = sorted(w[len(b) + 1:] for w in ws if '.' in w)
        if not sfx:
            s = '(none)'
        elif len(sfx) <= 12:
            s = ' '.join('.' + x for x in sfx)
        else:
            s = '%d words (`%s.%s`)' % (len(sfx), b, '<lane>[.<m>]' if b in ('vst', 'vstt') or b.startswith('vsseg') else '<m>[.<lane>]')
        wave, meaning = META[b]
        if b in use and use[b][0] > 0:
            wu, vl_, lv = use[b]
            path = 'LLVM lowering (%d of %d words; %s)' % (wu, len(ws), 'both builds' if vl_ and lv else 'scalar-loop recogniser only' if vl_ else 'LoopVectorize build only')
        elif b in hand:
            path = 'hand-written only (%s)' % ', '.join(sorted(hand[b])[:3])
        else:
            path = 'never (no compiled or hand-written kernel uses it)'
        out.append('| `%s` | %s | %s | %s | %s |' % (b, s, meaning, wave, path))
    tot = '%d words, %d base mnemonics (read from %s)' % (nwords, len(bases), os.path.relpath(GRAMMAR, ROOT))
    return out, tot


def block():
    rows, tot = build()
    return '\n'.join(rows + ['', '*' + tot + '; the table is generated by `tools/vec-glance.py` (`--check vec-isa.md` fails if it is out of date).*'])


def main(argv):
    if len(argv) >= 3 and argv[1] in ('--check', '--update'):
        path = argv[2]
        txt = open(path).read()
        i, j = txt.find(BEGIN), txt.find(END)
        if i < 0 or j < 0:
            sys.exit('vec-glance: no markers in ' + path)
        new = txt[:i + len(BEGIN)] + '\n' + block() + '\n' + txt[j:]
        if argv[1] == '--update':
            open(path, 'w').write(new)
            print('updated', path)
            return 0
        if new != txt:
            print('vec-glance: %s is out of date (run tools/vec-glance.py --update %s)' % (path, path))
            return 1
        print('vec-glance: %s is current' % path)
        return 0
    print(block())
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
