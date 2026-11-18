"""Dictionary entries, part 5: the vec block, the tile and the GEMM family (docs/encoding-work/vec-isa.md, gemm-forms.md).

The words come from the catalogue of the encoding, docs/codegen-data/encoding/vecfam.py, so removing an instruction there (a dud, after the benchmarks) removes its word
here too; the text is by family.  The family was added to be benchmarked and pruned (errata 161), the encodings are provisional, and every entry is tagged (P): held back
by isa_entries.HELD and not printed in the manual until the benchmarks have kept it (errata 120).  The semantics are those of vec-isa.md."""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'docs', 'codegen-data', 'encoding'))
from isa_common import *
from enc import SR
import vecfam

ALLW = sorted({w for f in vecfam.vec_forms(SR(5)) for w in f.mns})
P = '*(P)* Added to the design to be benchmarked and pruned (errata 161); the encoding is provisional (a forced form of the prefix grammar, no usage weights). '
VEXC = 'Memory operand: page fault, protection fault, alignment fault or bus error; precise at the strip: the strip is annulled, the pointers are those at its start, `EPC` is the address of the faulting instruction of the block.'
FP = 'Floating-point lanes follow the scalar rules (IEEE 754, flags accumulated in `FPSR`, no traps).'


def words(*prefixes):
    """every word of the catalogue that is one of the base operations, with its lane and element suffixes"""
    return [w for w in ALLW if w.split('.')[0] in prefixes or w in prefixes]


def V(id, prefixes, title, syntax, op, notes, exc='None beyond the faults of its memory operand.', cf='9.15 (the block operations restart), the vector study (`docs/encoding-work/vec-isa.md`).'):
    ns = words(*prefixes)
    if not ns:
        return None
    return E(id, 'vec', ns, title, syntax, op, NOFLAGS, exc, '9.22', notes=P + notes, cf=cf)


_E = [
    V('VEC', ['vec'], 'Begin a vector block', ['VEC Rs, Re'],
      'the instructions up to VEND run once for each strip of the region [Rs, Re) of the pointer register Rs, until it is exhausted',
      'The block: the instructions between `VEC` and `VEND` run for each **strip** of the first stream, `VL` elements, `1 <= VL <= the elements left`, chosen by the implementation for each strip. The program never names the width (`VLEN` tells it where it must know). A block of one instruction without `VEND` is the one-instruction prefix (R430). Hidden vector registers `v0` to `v15` are not ordinary registers: the scalar instructions cannot read or write them and a context switch does not save them (R435); their contents do not survive from one strip to the next except for the accumulators that `VCLR` names. A block that holds accumulators restarts from its entry after an interrupt (the assistant\'s leaning, `vec-isa.md` 4.1).'),
    V('VEND', ['vend'], 'End a vector block', ['VEND'], 'end of the block begun by VEC',
      'Nested blocks are refused.'),
    V('VLEN', ['vlen'], 'The number of elements in a strip', ['VLEN.t Rd'], 'Rd <- VL for the element type t',
      'The program must not depend on the value: it differs between implementations and for the last strip.'),
    V('VADD', ['vadd', 'vadds', 'vaddsu'], 'Lane add', ['VADD.t vD, vA, vB | Rs | #imm', 'VADDS.t, VADDSU.t (saturating)'],
      'vD[i] <- vA[i] + vB[i]  (a scalar register or an immediate is the same value in every lane)',
      'Lane arithmetic wraps unless the mnemonic says saturating (`VADDS` signed, `VADDSU` unsigned). ' + FP),
    V('VSUB', ['vsub', 'vsubr', 'vsubs', 'vsubsu'], 'Lane subtract', ['VSUB.t vD, vA, vB | Rs | #imm', 'VSUBR.t (reverse)'],
      'vD[i] <- vA[i] - vB[i]; VSUBR: vD[i] <- operand - vA[i]',
      '`VSUBR` is the reverse subtract: `vsubr.w v2, v2, #255` is `255 - v2`. `VSUBS`, `VSUBSU` saturate.'),
    V('VMUL', ['vmul'], 'Lane multiply', ['VMUL.t vD, vA, vB | Rs | #imm'], 'vD[i] <- vA[i] x vB[i]', 'Low half of the product for integer lanes. ' + FP),
    V('VMINMAX', ['vmin', 'vmax', 'vminu', 'vmaxu', 'vabd', 'vabdu'], 'Lane minimum, maximum and absolute difference',
      ['VMIN.t, VMAX.t, VABD.t vD, vA, vB | Rs | #imm', 'VMINU.t, VMAXU.t, VABDU.t (unsigned)'], 'vD[i] <- min | max | |vA[i] - vB[i]|',
      'The unsigned forms (`VMINU`, `VMAXU`, `VABDU`) are the assistant\'s addition for the bytes of pixels (errata 161). ' + FP),
    V('VLOGIC', ['vand', 'vor', 'vxor', 'vshl', 'vshr', 'vsar'], 'Lane logic and shifts', ['VAND.t, VOR.t, VXOR.t, VSHL.t, VSHR.t, VSAR.t vD, vA, vB | Rs | #imm'],
      'vD[i] <- vA[i] op vB[i]', 'Integer lanes only. `VSHR` is logical, `VSAR` arithmetic.'),
    V('VMOV', ['vmov', 'vneg'], 'Lane move and negate', ['VMOV.t vD, vA | Rs | #imm', 'VNEG.t vD, vA'], 'vD[i] <- operand | -vA[i]',
      'A scalar register or an immediate is broadcast to every lane.'),
    V('VMLA', ['vmla'], 'Integer multiply-add by a scalar', ['VMLA.t vD, vA, Rs'], 'vD[i] <- vD[i] + vA[i] x Rs', 'Integer lanes.'),
    V('VFMA', ['vfma', 'vfnma', 'vfmab'], 'Floating-point multiply-add',
      ['VFMA.f vD, vA, vB | Rs', 'VFNMA.f vD, vA, vB', 'VFMAB.f vD, vA, (Ra)+'], 'vD[i] <- vD[i] + vA[i] x vB[i];  VFNMA: vD - vA x vB;  VFMAB: vD + vA x broadcast(*Ra), Ra moved by one element',
      '`VFMAB` is the broadcast multiply-add of the GEMM micro-kernel (the ten registers of the micro-kernel are why there are sixteen vector registers). ' + FP, exc=VEXC),
    V('VDOT', ['vdot', 'vdotu', 'vdotsu'], 'Int8 dot product', ['VDOT.b vD, vA, vB'], 'each 32-bit lane of vD <- vD + the four byte products of the same lane of vA and vB',
      'Signed (`VDOT`), unsigned (`VDOTU`) and signed by unsigned (`VDOTSU`): the shapes of dp4a, SDOT and VNNI. Accumulates in 32-bit integers with wraparound.'),
    V('VACC', ['vacc', 'vmaxacc', 'vminacc'], 'Reduce a vector into a register', ['VACC.src.acc Rd, vS', 'VMAXACC.src Rd, vS', 'VMINACC.src Rd, vS'],
      'Rd <- Rd + the sum of the lanes, made in the width acc | max(Rd, the largest lane) | min(Rd, the smallest lane)',
      'The source type `src` is the lane type the register holds, with its signedness (`b w l q` signed, `bu wu lu` unsigned, `f d`): the lanes are extended as it says, so unsigned bytes sum without a widening load. The sum is made in `acc` and wraps there: `l` for byte and halfword sources, `l` or `q` for 32-bit lanes, `q` for 64-bit lanes, `f` or `d` for floating point (the fewest widths, to keep the adder tree small). The strip\'s `VL` counts the source lanes, not `acc`. The assembler refuses a `src` that is not the lane type the last instruction of the block wrote into the register (errata 168). The register is updated when the strip commits.'),
    V('VFIR', ['vfir'], 'Sliding-window multiply-accumulate', ['VFIR.t vD, vS, Rt, #taps'],
      'lane i of vD <- the sum over k = 0..taps-1 of R(t+k) x lane (i+k-c) of vS;  c = taps/2 rounded down',
      'The neighbours across the edge of the strip are the last and first elements of the previous and next strip, so the region is read once; it reads `c` elements before the region and `taps-1-c` after, as the scalar code does.'),
    V('VCLR', ['vclr'], 'Zero and name accumulators', ['VCLR.t vN, #count'], 'vN .. v(N+count-1) <- 0, and they keep their values from one strip to the next within the block',
      'The accumulators are the only hidden state that survives a strip (`vec-isa.md` 4.1).'),
    V('VLD', ['vld'], 'Load a strip', ['VLD.m[.lane] vD, (Ra)+ | d(Ra)'], 'vD <- the next strip from memory, widened to the lane',
      '`m` is the memory type (`b w l q`, a following `u` zero-extends, `f` and `d` floating point) and the optional second suffix the lane the strip is held in. `(Ra)+` moves the pointer past the strip. The `d(Ra)+` form (an offset and the move) is `d(Ra)` followed by an add.', exc=VEXC),
    V('VST', ['vst', 'vsts'], 'Store a strip', ['VST.lane[.m] vS, (Ra)+ | d(Ra)', 'VSTS.lane.m vS, (Ra)+ | d(Ra)'], 'the strip to memory, narrowed (truncating; VSTS: clamping to the range of m)',
      '`VSTS.l.bu` clamps to 0..255.', exc=VEXC),
    V('VLDT', ['vldt', 'vstt'], 'Strided load and store', ['VLDT.m[.lane] vD, (Ra)+, #stride', 'VSTT.lane[.m] vS, (Ra)+, #stride'], 'every `stride` bytes (one field of an array of structures)',
      'The stride is a 12-bit unsigned byte count; `(Ra)+` moves the pointer by the elements of the strip times the stride.', exc=VEXC),
    V('VSEG', ['vlseg2', 'vlseg3', 'vlseg4', 'vsseg2', 'vsseg3', 'vsseg4'], 'Segment load and store', ['VLSEGn.m[.lane] vD, (Ra)+ | d(Ra)', 'VSSEGn.lane[.m] vS, (Ra)+ | d(Ra)'],
      'load n interleaved fields into vD .. v(D+n-1); store n registers interleaved', 'n = 2, 3 or 4. The pointer moves by `VL` times the number of fields.', exc=VEXC),
    V('VLDX', ['vldx'], 'Gather', ['VLDX.m[.lane] vD, (Rb)[vI]'], 'lane i of vD <- M[Rb + lane i of vI] (a byte offset)', 'Scatter-add stays under study.', exc=VEXC),
    V('VTILE', ['vtclr', 'vtfmopa', 'vtld', 'vtst', 'vtadd'], 'The tile and the outer product',
      ['VTCLR tN', 'VTFMOPA.f tD, vA, vB', 'VTLD.f tN, (Ra), Rs', 'VTST.f tN, (Ra), Rs', 'VTADD.f tD, tA, tB'],
      'tN <- 0;  tD[i][j] <- tD[i][j] + vA[i] x vB[j];  tile load and store with rows Rs bytes apart;  tD <- tA + tB',
      'Tile registers `t0` to `t7` (hidden, like the vector registers). 256 bytes of tile at 256-bit strips (`vec-cost-benefit.md` row 14).', exc=VEXC),
    V('GEMM', ['gemm.f'], 'The whole-GEMM instruction', ['GEMM.f Rd, Rr, Rc'], 'runs a matrix product described by the descriptor at Rd; Rr and Rc are the row and column of the next output tile',
      'The constants (three addresses, three sizes, three strides, alpha, beta, flags) are in the descriptor in memory; progress is in the two ordinary registers, and it restarts from the start of a tile after an interrupt or fault (`gemm-forms.md` 5a). Under study (row 15): it needs a GEMM unit.', exc=VEXC),
]
ENTRIES = [e for e in _E if e is not None]
