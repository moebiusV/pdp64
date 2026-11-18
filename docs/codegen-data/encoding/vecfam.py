"""vecfam.py -- the vec block, the tile and the GEMM family, as forced forms for the catalogue (cat.py).

The instructions are those of docs/encoding-work/vec-isa.md (section 2) and docs/encoding-work/gemm-forms.md (the tile and the whole-GEMM unit).  They are here to be
**benchmarked and pruned**: nothing in the corpus emits them yet (pcc has no vectorizer), their encodings are provisional (forced forms, no usage weights: the
prefix optimiser is to be run again on the corpus compiled by the LLVM back end, which has the vectorizer), and an instruction that the benchmarks show to be a dud is removed by
deleting its name from a list below and regenerating (docs/encoding-work/vec-family.md says how).

A form is a list of mnemonics that share operand shapes; the leaf of a form has the shortest prefix that the operand bits and the sub-opcode bits leave (as many
first-parcel patterns as 2^(16-L)), so the whole family takes only some tens of patterns.

Operand shapes (the notation of the manual): vN a vector register (4 bits, v0..v15), tN a tile register (3 bits, t0..t7), rN an integer register, (rA)+ a post-increment
memory operand that moves by the strip, d(rA) a base and a 12-bit displacement in bytes (the strided forms take (rA)+ and a stride), (rA)[vI] the base of a gather, #n an immediate.

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
BIN_ANY = ['vadd', 'vsub', 'vsubr', 'vmul', 'vmin', 'vmax', 'vabd']		# integer and floating-point lanes
BIN_INT = ['vand', 'vor', 'vxor', 'vshl', 'vshr', 'vsar', 'vminu', 'vmaxu', 'vabdu']	# integer lanes (vminu, vmaxu, vabdu: unsigned, for the bytes of pixels)
SAT = ['vadds', 'vsubs', 'vaddsu', 'vsubsu']					# saturating; lanes b, w, l
UN = ['vmov', 'vneg']								# vD, vA | rS | #imm
FMA = ['vfma.f', 'vfma.d']
ALL3 = sfx(BIN_ANY, LANES) + sfx(BIN_INT, IL) + sfx(SAT, ['b', 'w', 'l'])


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
    """vsts.<lane>.<m>: narrowing with clamping to the range of m"""
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
LDX = ldwords('vldx')


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
    vf('VBEG', ['vec'], [R, R])
    vf('VEND', ['vend'], [])
    vf('VLEN', sfx(['vlen'], LANES), [R])
    # lane operations
    vf('VOP.VVV', ALL3 + sfx(['vfma', 'vfnma'], FL) + ['vdot.b', 'vdotu.b', 'vdotsu.b'], [V, V, V])
    vf('VOP.VVR', sfx(BIN_ANY, LANES) + sfx(BIN_INT, IL) + sfx(SAT, ['b', 'w', 'l']) + sfx(['vmla'], IL) + FMA, [V, V, R])
    vf('VOP.VVI', sfx(BIN_ANY, LANES) + sfx(BIN_INT, IL) + sfx(SAT, ['b', 'w', 'l']), [V, V, I16])
    vf('VOP.VV', sfx(['vmov', 'vneg'], LANES), [V, V])
    vf('VOP.VR', sfx(['vmov'], LANES), [V, R])
    vf('VOP.VI', sfx(['vmov'], LANES), [V, I16])
    # multiply-add with the broadcast element (the micro-kernel), reductions, the sliding window, accumulators
    vf('VFMAB', sfx(['vfmab'], FL), [V, V, PI])
    vf('VACC', accwords(), [R, V])
    vf('VFIR', sfx(['vfir'], LANES), [V, V, R, SI(6, False)])
    vf('VCLR', sfx(['vclr'], LANES), [V, SI(4, False)])
    # memory: a strip from or to memory, the strided forms, segments, gather
    vf('VLD.PI', LD + SEGLD, [V, PI])
    vf('VLD.B', LD + SEGLD, [V, B])
    vf('VST.PI', ST + SEGST, [V, PI])
    vf('VST.B', ST + SEGST, [V, B])
    vf('VLDT', LDT, [V, PI, SI(12, False)])
    vf('VSTT', STT, [V, PI, SI(12, False)])
    vf('VLDX', LDX, [V, B0, V])
    # the tile and the GEMM unit
    vf('VT.CLR', ['vtclr'], [T])
    vf('VT.MOPA', sfx(['vtfmopa'], FL), [T, V, V])
    vf('VT.LS', sfx(['vtld', 'vtst'], FL), [T, B0, R])
    vf('VT.ADD', sfx(['vtadd'], FL), [T, T, T])
    vf('GEMM', ['gemm.f'], [R, R, R])
    return out
