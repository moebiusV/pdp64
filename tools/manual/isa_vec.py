"""Dictionary entries, part 5: the vec block (docs/encoding-work/vec-isa.md; wave 1 of the revised family, errata 170, removed the tile, the GEMM unit and the gather).

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
      'The block: the instructions between `VEC` and `VEND` run for each **strip** of the first stream, `VL` elements, `1 <= VL <= the elements left`, chosen by the implementation for each strip. The program never names the width and the hardware never tells it: there is no instruction that gives `VL` (errata 173), the least strip is 16 bytes, and everything a block computes is the same on every implementation (`vec-isa.md` section 8). A block of one instruction without `VEND` is the one-instruction prefix (R430). Hidden vector registers `v0` to `v15` are not ordinary registers: the scalar instructions cannot read or write them and a context switch does not save them (R435); their contents do not survive from one strip to the next except for the accumulators that `VCLR` names. A block that holds accumulators has a strip of exactly 16 bytes on every implementation and restarts from its entry after a fault (`vec-isa.md` 4.1 and 8).'),
    V('VEND', ['vend'], 'End a vector block', ['VEND'], 'end of the block begun by VEC',
      'Nested blocks are refused.'),
    V('VFIN', ['vfin'], 'End of the strips of a block with accumulators', ['VFIN'], 'the instructions after VFIN run once, after the last strip, on the final lanes of the accumulators',
      'The only strip-independent way to read an accumulator out (errata 173): the instructions between `VFIN` and `VEND` form the epilogue, one more strip of the block\'s lanes that runs once after the last strip, so a `VACC` of an accumulator or a store of it happens once, on its final value, whatever the implementation\'s strip. A block with `VFIN` is a block with accumulators: its strip is 16 bytes and a fault restarts it from its entry. A fault in the epilogue restarts the whole block.', exc=VEXC),
    V('VADD', ['vadd', 'vadds', 'vaddsu'], 'Lane add', ['VADD.t vD, vA, vB | Rs | #imm', 'VADDS.t, VADDSU.t (saturating)'],
      'vD[i] <- vA[i] + vB[i]  (a scalar register or an immediate is the same value in every lane)',
      'Lane arithmetic wraps unless the mnemonic says saturating (`VADDS` signed, `VADDSU` unsigned). ' + FP),
    V('VSUB', ['vsub', 'vsubr', 'vsubs', 'vsubsu'], 'Lane subtract', ['VSUB.t vD, vA, vB | Rs | #imm', 'VSUBR.t (reverse)'],
      'vD[i] <- vA[i] - vB[i]; VSUBR: vD[i] <- operand - vA[i]',
      '`VSUBR` is the reverse subtract: `vsubr.w v2, v2, #255` is `255 - v2`. `VSUBS`, `VSUBSU` saturate.'),
    V('VMUL', ['vmul'], 'Lane multiply', ['VMUL.t vD, vA, vB | Rs | #imm'], 'vD[i] <- vA[i] x vB[i]', 'Low half of the product for integer lanes (`b w l`; the 64-bit integer lanes were removed, errata 170). The high half and the Q15 product are `VMULH`. ' + FP),
    V('VAVG', ['vavg', 'vavgu'], 'Lane rounding average', ['VAVG.t, VAVGU.t vD, vA, vB'], 'vD[i] <- (vA[i] + vB[i] + 1) >> 1',
      'Lanes `b` and `w`; the sum is made in a wider type, so it cannot wrap, and rounds up (half toward plus infinity); `VAVG` signed, `VAVGU` unsigned. One word for the add, the add of one and the shift of the weighted prediction of video codecs (errata 170).'),
    V('VMULH', ['vmulh', 'vmulhu', 'vmulhr'], 'High half and Q15 multiply', ['VMULH.w, VMULHU.w, VMULHR.w vD, vA, vB | Rs | #imm'],
      'vD[i] <- (vA[i] x vB[i]) >> 16 (signed, unsigned);  VMULHR: (vA[i] x vB[i] + 2^14) >> 15, saturated to 32767',
      '16-bit lanes. `VMULHR` is the Q15 rounding multiply (`pmulhrsw`, `sqrdmulh`); the one product that does not fit, -32768 x -32768, gives 32767, not -32768 (the saturation of `sqrdmulh`). A scalar register or an immediate is the same value in every lane (the constants of a transform).'),
    V('VROUND', ['vsarr', 'vshrr'], 'Lane shifts that round', ['VSARR.t, VSHRR.t vD, vA, vB | Rs | #imm'], 'vD[i] <- (vA[i] + 2^(s-1)) >> s, exact, round half up; s = 0 leaves the lane',
      'Lanes `w` and `l`. `VSARR` arithmetic, `VSHRR` logical. The sum is not wrapped; a count above the width of the lane gives 0. The count is the unsigned value of the lane of the second operand.'),
    V('VCMP', ['vceq', 'vcgt', 'vcgtu'], 'Lane compare into a mask', ['VCEQ.t, VCGT.t vD, vA, vB | Rs | #imm  (t = b w l f)', 'VCGTU.t vD, vA, vB | Rs | #imm  (t = b w l)'],
      'vD[i] <- all ones if vA[i] == | > | >u operand, else 0',
      'The mask is an ordinary vector register: an integer lane of the size compared (also for `f`), all ones or zero, so `VAND`, `VBSL` and the stores take it without a mask file (errata 171). `VCGT` is signed, `VCGTU` unsigned; the floating-point compares are ordered: a NaN compares false (also `VCEQ` of a NaN with itself), -0.0 equals +0.0, no flag is set. The second operand may be a scalar register or an immediate (the same value in every lane). There is no less-than: swap the operands, or the arms of the select.'),
    V('VBSL', ['vbsl'], 'Bitwise select', ['VBSL vD, vM, vA, vB'], 'vD <- (vM & vA) | (~vM & vB), bit by bit',
      'No lane suffix: it selects bits. With a lane mask of `VCEQ`, `VCGT` or `VCGTU` in `vM` it is the select of a ternary operator. `vD` may be `vM`, `vA` or `vB` (all are read first). The assembler checks that the mask and both operands hold lanes of the same size (errata 171).'),
    V('VCVT', ['vcvt'], 'Convert 32-bit lanes between integer and binary32', ['VCVT.l.f, VCVT.lu.f vD, vA  (int32 to binary32)', 'VCVT.f.l, VCVT.f.lu vD, vA  (binary32 to int32)'],
      'int to float: vD[i] <- (float) vA[i], round to nearest even;  float to int: truncate toward zero, saturate, a NaN gives the largest value',
      'The name is `VCVT.<from>.<to>`, `l` signed and `lu` unsigned 32-bit integer lanes. The rules are those of the scalar `FCVTLS` and `FCVTSL`: float to signed integer truncates and saturates (a NaN gives 2147483647); to unsigned a negative value gives 0 and a NaN or a value of 2^32 or more gives 4294967295 (as `FCVTDQU`). 2^24 + 1 rounds to 2^24. No flag is set in `FPSR` (the vector lanes never touch it). The lanes change type: the assembler checks it (errata 171).'),
    V('VMINMAX', ['vmin', 'vmax', 'vminu', 'vmaxu', 'vabd', 'vabdu'], 'Lane minimum, maximum and absolute difference',
      ['VMIN.t, VMAX.t, VABD.t vD, vA, vB | Rs | #imm', 'VMINU.t, VMAXU.t, VABDU.t (unsigned)'], 'vD[i] <- min | max | |vA[i] - vB[i]|',
      'The unsigned forms (`VMINU`, `VMAXU`, `VABDU`) are the assistant\'s addition for the bytes of pixels (errata 161). ' + FP),
    V('VLOGIC', ['vand', 'vor', 'vxor', 'vshl', 'vshr', 'vsar'], 'Lane logic and shifts', ['VAND.t, VOR.t, VXOR.t, VSHL.t, VSHR.t, VSAR.t vD, vA, vB | Rs | #imm'],
      'vD[i] <- vA[i] op vB[i]', 'Integer lanes only. `VSHR` is logical, `VSAR` arithmetic.'),
    V('VMOV', ['vmov', 'vneg'], 'Lane move and negate', ['VMOV.t vD, vA | Rs | #imm', 'VNEG.t vD, vA'], 'vD[i] <- operand | -vA[i]',
      'A scalar register or an immediate is broadcast to every lane.'),
    V('VMLA', ['vmla'], 'Integer multiply-add', ['VMLA.t vD, vA, vB | Rs'], 'vD[i] <- vD[i] + vA[i] x vB[i] | Rs', 'Lanes `w` and `l`. The vector by vector form is new in wave 1 (errata 170): it uses the multiplier of `VMUL` and costs no gates.'),
    V('VFMA', ['vfma', 'vfnma', 'vfmab'], 'Floating-point multiply-add',
      ['VFMA.f vD, vA, vB | Rs', 'VFNMA.f vD, vA, vB', 'VFMAB.f vD, vA, (Ra)+'], 'vD[i] <- vD[i] + vA[i] x vB[i];  VFNMA: vD - vA x vB;  VFMAB: vD + vA x broadcast(*Ra), Ra moved by one element',
      '`VFMAB` is the broadcast multiply-add of the GEMM micro-kernel (the ten registers of the micro-kernel are why there are sixteen vector registers). A block with `VFMAB` has a strip of 16 bytes on every implementation (a strip is one step of the micro-kernel and the pointer `Ra` moves once for each strip: errata 173). ' + FP, exc=VEXC),
    V('VDOT', ['vdot', 'vdotu', 'vdotsu'], 'Dot product', ['VDOT.b vD, vA, vB', 'VDOT.w vD, vA, vB'], 'each 32-bit lane of vD <- vD + the four byte products (`.b`) or the two 16-bit products (`.w`) of the same lane of vA and vB',
      'Signed (`VDOT`), unsigned (`VDOTU`) and signed by unsigned (`VDOTSU`) bytes: the shapes of dp4a, SDOT and VNNI; `VDOT.w` is `pmaddwd` (signed halfwords only). Accumulates in 32-bit integers with wraparound.'),
    V('VDACC', ['vdacc', 'vsad'], 'Dot product and sum of absolute differences into a register', ['VDACC.b, VDACC.bu, VDACC.bsu, VDACC.w Rd, vA, vB', 'VSAD.bu Rd, vA, vB'],
      'Rd <- Rd + the exact sum of the products of all the lanes of the strip;  VSAD: Rd <- Rd + the sum of |vA[i] - vB[i]| over the unsigned byte lanes',
      '`VDACC` is a `VDOT` and a `VACC` in one word: the strip stays 32 bytes of byte lanes, and no 32-bit lane is held. Signed (`b`), unsigned (`bu`), signed by unsigned (`bsu`) bytes, signed halfwords (`w`). The sum is exact (not wrapped to 32 bits) and added to the 64-bit register, which is committed when the strip commits, as `VACC`: no state crosses a strip.'),
    V('VTBL', ['vtbl'], 'Table lookup of bytes', ['VTBL.b vD, (Ra), vI'], 'vD[i] <- the byte of a 16-byte table that the index lane vI[i] names; 0 if vI[i] >= 16 (unsigned)',
      'The table is exactly 16 bytes at `(Ra)`, the same for every lane and every strip, whatever the length of the strip. Nothing is kept between strips. It replaces the gather for the dequantisation tables (errata 170). There is no register form (errata 173): a table taken from the lanes of a register would be truncated by a short strip, so the strip would be visible.'),
    V('VACC', ['vacc', 'vmaxacc', 'vminacc'], 'Reduce a vector into a register', ['VACC.src.acc Rd, vS', 'VMAXACC.src Rd, vS', 'VMINACC.src Rd, vS'],
      'Rd <- Rd + the sum of the lanes, made in the width acc | max(Rd, the largest lane) | min(Rd, the smallest lane)',
      'The source type `src` is the lane type the register holds, with its signedness (`b w l q` signed, `bu wu lu` unsigned, `f d`): the lanes are extended as it says, so unsigned bytes sum without a widening load. The sum is made in `acc` and wraps there: `l` for byte and halfword sources, `l` or `q` for 32-bit lanes, `q` for 64-bit lanes, `f` or `d` for floating point (the fewest widths, to keep the adder tree small). The strip\'s `VL` counts the source lanes, not `acc`. The assembler refuses a `src` that is not the lane type the last instruction of the block wrote into the register (errata 168). The register is updated when the strip commits. **A floating-point sum (`VACC.f`, `VACC.f.d`, `VACC.d`) is in a canonical order that does not depend on the strip** (errata 174): the lanes of the stream are taken in chunks of 16 bytes of source lanes (4 binary32, 2 binary64), each chunk is summed by the fixed tree ((l0 + l1) + (l2 + l3)) in the width `acc`, and the chunks are added to the register one after the other in element order; a short last chunk has the lanes it has. The assembler refuses the sum in a block with a lane wider than its source lane. `VMAXACC` and `VMINACC` take the lanes in element order.'),
    V('VFIR', ['vfir'], 'Sliding-window multiply-accumulate', ['VFIR.t vD, vS, Rt, #taps'],
      'lane i of vD <- the sum over k = 0..taps-1 of R(t+k) x lane (i+k-c) of vS;  c = taps/2 rounded down',
      'The neighbours across the edge of the strip are the last and first elements of the previous and next strip, so the region is read once; it reads `c` elements before the region and `taps-1-c` after, as the scalar code does.'),
    V('VCLR', ['vclr'], 'Zero and name accumulators', ['VCLR.t vN, #count'], 'vN .. v(N+count-1) <- 0, and they keep their values from one strip to the next within the block',
      'The accumulators are the only hidden state that survives a strip (`vec-isa.md` 4.1). A block that names accumulators has a strip of exactly 16 bytes on every implementation, so the lanes of an accumulator are the program\'s (errata 173); they are read out after the last strip by `VFIN`.'),
    V('VLD', ['vld'], 'Load a strip', ['VLD.m[.lane] vD, (Ra)+ | d(Ra)'], 'vD <- the next strip from memory, widened to the lane',
      '`m` is the memory type (`b w l q`, a following `u` zero-extends, `f` and `d` floating point) and the optional second suffix the lane the strip is held in. `(Ra)+` moves the pointer past the strip. The `d(Ra)+` form (an offset and the move) is `d(Ra)` followed by an add.', exc=VEXC),
    V('VST', ['vst', 'vsts'], 'Store a strip', ['VST.lane[.m] vS, (Ra)+ | d(Ra)', 'VSTS.lane.m vS, (Ra)+ | d(Ra)', 'VSTS.lane.m vS, (Ra)+, #sh'], 'the strip to memory, narrowed (truncating; VSTS: clamping to the range of m, after the rounding shift if there is one)',
      '`VSTS.l.bu` clamps to 0..255. With `#sh` (0 to 63) each lane is first shifted right by `sh` with rounding, (x + 2^(sh-1)) >> sh, exact and arithmetic, then clamped: the shift-round-narrow-saturate-store of `sqrshrun`.', exc=VEXC),
    V('VLDT', ['vldt', 'vstt'], 'Strided load and store', ['VLDT.m[.lane] vD, (Ra)+, #stride', 'VSTT.lane[.m] vS, (Ra)+, #stride'], 'every `stride` bytes (one field of an array of structures)',
      'The stride is a 12-bit unsigned byte count; `(Ra)+` moves the pointer by the elements of the strip times the stride.', exc=VEXC),
    V('VSEG', ['vlseg2', 'vlseg3', 'vlseg4', 'vsseg2', 'vsseg3', 'vsseg4'], 'Segment load and store', ['VLSEGn.m[.lane] vD, (Ra)+ | d(Ra)', 'VSSEGn.lane[.m] vS, (Ra)+ | d(Ra)'],
      'load n interleaved fields into vD .. v(D+n-1); store n registers interleaved', 'n = 2, 3 or 4. The pointer moves by `VL` times the number of fields.', exc=VEXC),
]
ENTRIES = [e for e in _E if e is not None]
