"""vecfam.py -- the vec block family, as forced forms for the catalogue (cat.py).

The instructions are those of docs/encoding-work/vec-isa.md (the semantics reference, with the family at a glance).  They were added to be **benchmarked and pruned** (errata 161),
and were: the tile, the whole-GEMM unit, the gather and 23 lane variants were removed in wave 1 (errata 170), wave 2 added the compares, the select and the conversions
(errata 171), the strip was made invisible (errata 173 to 175: vlen and the register form of vtbl removed, vfin added).  pcc has no vectorizer; the LLVM back end selects
some of them (llvm/vector-usage.md).  Their encodings are provisional (forced forms, no usage weights: the prefix optimiser is to be run again on the corpus compiled by
the LLVM back end), and a word that the benchmarks show to be a dud is removed by deleting its name from a list below and regenerating (errata 170, "generator workflow":
`addforms.py --grammar-out spec/grammars.d` with --drop for each removed form, tools/grammars_d.py --write, mkenc.py --md, check-grammar-enc.sh --update, mk_vectors.py).  The grammar the family lands in is
generated (errata 179, 180): spec/grammars.d/20-enc-forms.hbnf, 21-enc-shapes.hbnf and 80-mn-ext.hbnf are whole parts that addforms.py writes and a person never edits (a family that is hand
written is a part of its own: spec/README.md, "How a part is added").  Change this file, not the generated ones.

A form is a list of mnemonics that share operand shapes; the leaf of a form has the shortest prefix that the operand bits and the sub-opcode bits leave (as many
first-parcel patterns as 2^(16-L)), so the whole family takes only some tens of patterns.

Operand shapes (the notation of the manual): vN a vector register (4 bits, v0..v15), rN an integer register, (rA)+ a post-increment
memory operand that moves by the strip, d(rA) a base and a 12-bit displacement in bytes (the strided forms take (rA)+ and a stride), #n an immediate.

Deliberately not here (vec-isa.md, "under study"): vexp and the other special functions, the scatter-add, predication, the fp16, bf16 and int4 conversions; and the
operand form d(rA)+ of the strip memory operations (an offset and the move), which is d(rA) followed by an add of the strip.
"""
import math
from enc import *

LANES = ['b', 'w', 'l', 'q', 'f', 'd']
IL = ['b', 'w', 'l', 'q']
FL = ['f', 'd']
WIDTH = {'b': 8, 'w': 16, 'l': 32, 'q': 64, 'f': 32, 'd': 64}


def sfx(ms, ls):
    return [m + '.' + l for m in ms for l in ls]


# ---- the lane operations (vD, vA, vB | rS | #imm)
# Wave 1 of the revised family (errata 170; docs/encoding-work/vec-survey.md 5.1): the lane variants that nothing uses are gone (the 64-bit lanes of the multiply, the
# minimum, the maximum and the absolute difference; the floating-point absolute difference; the 32 and 64-bit unsigned absolute difference), and the words of the rounding
# average, the high-half multiply, the rounding shifts, the 16-bit dot, the reductions of a dot and of a sum of absolute differences, and the table lookup are in.
BIN_ANY = ['vadd', 'vsub', 'vsubr']						# integer and floating-point lanes, all six
BIN_ANY5 = ['vmul', 'vmin', 'vmax']						# b w l f d (no 64-bit integer lanes)
BIN_INT = ['vand', 'vor', 'vxor', 'vshl', 'vshr', 'vsar']			# integer lanes
BIN_INT3 = ['vminu', 'vmaxu']							# b w l (unsigned, for the bytes of pixels)
BIN_WL = ['vsarr', 'vshrr']							# w l: the shifts that round
BIN_W = ['vmulh', 'vmulhu', 'vmulhr']						# w: the high half of the 16 x 16 product, and the Q15 rounding multiply
SAT = ['vadds', 'vsubs', 'vaddsu', 'vsubsu']					# saturating; lanes b, w, l
UN = ['vmov', 'vneg']								# vD, vA | rS | #imm
FMA = ['vfma.f', 'vfma.d']
AVG = sfx(['vavg', 'vavgu'], ['b', 'w'])						# the rounding average (vD, vA, vB only)
# Wave 2 (errata 171; vec-survey.md 5.1 items 10 and 11).  Two groups, separable: drop one by emptying its list (CMP, CVT) and regenerating.
# CMP: the lane compare, a mask (all ones or zero) in an ordinary vector register; the lane operand forms are those of the lane operations (vD, vA, vB | rS | #imm).
# CVT: the conversions int32 <-> binary32 (about 15,800 NAND2 equivalents: vec-silicon.md says to build them only with the floating-point lanes); the name is vcvt.<from>.<to>.
# BSL: the bitwise select vbsl vD, vM, vA, vB (four vectors; no lane suffix).
CMP = sfx(['vceq', 'vcgt'], ['b', 'w', 'l', 'f']) + sfx(['vcgtu'], ['b', 'w', 'l'])
CVT = ['vcvt.l.f', 'vcvt.lu.f', 'vcvt.f.l', 'vcvt.f.lu']
BSL = ['vbsl']
LANEOPS = (CMP + sfx(BIN_ANY, LANES) + sfx(BIN_ANY5, ['b', 'w', 'l', 'f', 'd']) + sfx(BIN_INT, IL) + sfx(BIN_INT3, ['b', 'w', 'l']) + sfx(['vabd'], ['b', 'w', 'l']) +
           sfx(['vabdu'], ['b', 'w']) + sfx(BIN_WL, ['w', 'l']) + sfx(BIN_W, ['w']) + sfx(SAT, ['b', 'w', 'l']))
DACC = ['vdacc.b', 'vdacc.bu', 'vdacc.bsu', 'vdacc.w', 'vsad.bu']			# a dot product or a sum of absolute differences reduced into a scalar register
ALL3 = LANEOPS + AVG


def ldwords(base):
    """the loads: vld.<m>[.<lane>]: the memory type m, widened to the lane (the same width: no second suffix)"""
    out = []
    for m in ['b', 'bu', 'w', 'wu', 'l', 'lu', 'q']:
        for lane in IL:
            if WIDTH[lane] >= WIDTH[m[0]]:
                out.append('%s.%s' % (base, m) if lane == m[0] else '%s.%s.%s' % (base, m, lane))
    out += ['%s.f' % base, '%s.f.d' % base, '%s.d' % base]
    return out


def stwords(base):
    """the stores: vst.<lane>[.<m>]: the lane, narrowed (truncating) to the memory type m"""
    out = []
    for lane in IL:
        out.append('%s.%s' % (base, lane))
        out += ['%s.%s.%s' % (base, lane, m) for m in IL if WIDTH[m] < WIDTH[lane]]
    out += ['%s.f' % base, '%s.d' % base, '%s.d.f' % base]
    return out


def satwords():
    """vsts.<lane>.<m>: narrowing with clamping to the range of m (with an immediate, a rounding shift first: errata 170)"""
    out = []
    for lane in ['w', 'l', 'q']:
        for m in ['b', 'bu', 'w', 'wu', 'l', 'lu']:
            if WIDTH[m[0]] < WIDTH[lane]:
                out.append('vsts.%s.%s' % (lane, m))
    return out


def accwords():
    """the reductions into a register (errata 168): vacc.<src>.<acc> sums lanes of the source type (b w l q signed, bu wu lu unsigned, f d) into an accumulator of width acc (l or q;
    f d for floating point) and adds it to the register; vmaxacc.<src> and vminacc.<src> take the largest or smallest lane, signed or unsigned as the source type says"""
    out = []
    # the accumulate widths are the fewest that the lanes need (the owner: reasonable performance, a small silicon footprint): a sum of 32 bytes or 16 words fits 32 bits, so b and w
    # sources accumulate in l only; 32-bit lanes in l or q (the sum of eight needs 35 bits); 64-bit lanes in q.  A second accumulate width is a second adder tree and its wrap.
    for s in ['b', 'bu', 'w', 'wu', 'l', 'lu', 'q']:
        for a in (('l',) if s[0] in 'bw' else ('l', 'q') if s[0] == 'l' else ('q',)):
            out.append('vacc.%s.%s' % (s, a))
    out += ['vacc.f', 'vacc.f.d', 'vacc.d']
    for b in ('vmaxacc', 'vminacc'):
        out += ['%s.%s' % (b, s) for s in ['b', 'bu', 'w', 'wu', 'l', 'lu', 'q', 'f', 'd']]
    return out


LD = ldwords('vld')
ST = stwords('vst') + satwords()
SEGLD = [w for n in (2, 3, 4) for w in ldwords('vlseg%d' % n)]
SEGST = [w for n in (2, 3, 4) for w in stwords('vsseg%d' % n)]
LDT = ldwords('vldt')
STT = stwords('vstt')


def vec_forms(R):
    """the forced forms of the family.  R is the full integer-register spec of the catalogue"""
    V = SV(4, 'v')
    T = SV(3, 't')
    I16 = SI(16, True)
    PI = SP('PI', R, 0)			# (rA)+
    B = SB(R, 12, True, 1)		# d(rA)
    B0 = SB(R, 0, True, 1)		# (rA)
    out = []

    def vf(name, mns, specs):
        ob = sum(p[1] for sp in specs for p in sp.parts)
        need = math.ceil(math.log2(len(mns))) if len(mns) > 1 else 0
        for n in (1, 2, 3):
            if 16 * n - ob - need >= 10 and not (ob == 0 and n == 1):	# (no operand: two parcels, so that the leaf has a field of its own (hbnf makes no record for a leaf with none)
                break
        else:
            raise ValueError('%s: no length fits' % name)
        L = min(16, 16 * n - ob - need)
        out.append(Form(name, n, mns, specs, xbits=16 * n - ob - L))

    # the block
    vf('VBEG', ['vec', 'vskip'], [R, R])				# vskip Ra, Rg: the 2D block's row advance of one stream (errata 176, vec-2d.md); it takes the free sub-opcode of vec
    vf('VBEG2', ['vec2'], [R, R, R, R])					# vec2 Rs, Re, Rn, Rw: a block of Rn rows, repeated with the streams advanced at the end of each row (errata 176, vec-2d.md)
    vf('VEND', ['vend'], [])
    vf('VFIN', ['vfin'], [])						# errata 173: the end-of-block part of a block with accumulators (vec-isa.md section 8); vlen is gone (the strip is invisible)
    # lane operations
    vf('VOP.VVV', ALL3 + sfx(['vfma', 'vfnma'], FL) + sfx(['vmla'], ['w', 'l']), [V, V, V])	# (no register form of vtbl.b: errata 173)
    vf('VOP.VVR', LANEOPS + sfx(['vmla'], ['w', 'l']) + FMA, [V, V, R])
    vf('VOP.VVI', LANEOPS, [V, V, I16])
    vf('VDACC', DACC, [R, V, V])
    vf('VTBLM', ['vtbl.b'], [V, B0, V])
    vf('VOP.VV', sfx(['vmov', 'vneg'], LANES) + CVT, [V, V])
    if BSL:
        vf('VBSL', BSL, [V, V, V, V])
    vf('VOP.VR', sfx(['vmov'], LANES), [V, R])
    vf('VOP.VI', sfx(['vmov'], LANES), [V, I16])
    # multiply-add with the broadcast element (the micro-kernel), reductions, the sliding window, accumulators
    vf('VFMAB', sfx(['vfmab'], FL), [V, V, PI])
    vf('VACC', accwords(), [R, V])
    vf('VFIR', sfx(['vfir'], ['w', 'l', 'f']), [V, V, R, SI(6, False)])
    vf('VCLR', sfx(['vclr'], ['l', 'f', 'd']), [V, SI(4, False)])
    # memory: a strip from or to memory, the strided forms, segments, gather
    vf('VLD.PI', LD + SEGLD, [V, PI])
    vf('VLD.B', LD + SEGLD, [V, B])
    vf('VST.PI', ST + SEGST, [V, PI])
    vf('VST.B', ST + SEGST, [V, B])
    vf('VLDT', LDT, [V, PI, SI(12, False)])
    vf('VSTT', STT, [V, PI, SI(12, False)])
    vf('VSTS.R', satwords(), [V, PI, SI(6, False)])			# the narrowing store with a rounding shift: vsts.<lane>.<m> vS, (Ra)+, #sh
    return out
