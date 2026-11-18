#include "PDP64TargetTransformInfo.h"
#include "llvm/Analysis/IVDescriptors.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/Support/CommandLine.h"

using namespace llvm;

#define DEBUG_TYPE "pdp64tti"

static cl::opt<bool> EnableInterleave("pdp64-tti-interleave",
    cl::desc("pdp64 TTI: let LoopVectorize form interleaved access groups (vlseg/vsseg)"), cl::init(true), cl::Hidden);
static cl::opt<unsigned> ScalarizeCost("pdp64-tti-lane-move-cost",
    cl::desc("pdp64 TTI: cost of moving one lane between a vector and a scalar register (there is no instruction: a store and a load)"),
    cl::init(64), cl::Hidden);

static bool legalLane(Type *T) {
  if (T->isFloatTy() || T->isDoubleTy()) return true;
  if (auto *IT = dyn_cast<IntegerType>(T)) {
    unsigned W = IT->getBitWidth();
    return W == 8 || W == 16 || W == 32 || W == 64;
  }
  return false;
}
static bool isFP(Type *T) { return T->isFloatTy() || T->isDoubleTy(); }
// a vector of legal lanes
static bool legalVec(Type *T) {
  auto *VT = dyn_cast<FixedVectorType>(T);
  return VT && VT->getNumElements() >= 2 && legalLane(VT->getElementType());
}
// vector instructions needed for the whole vector: one for each strip of 256 bits
static InstructionCost rawStrips(Type *T) {
  auto *VT = cast<FixedVectorType>(T);
  uint64_t Bits = VT->getNumElements() * VT->getElementType()->getScalarSizeInBits();
  return InstructionCost(std::max<uint64_t>(1, (Bits + 255) / 256));
}
// ... and a vector of fewer than four lanes is made unattractive: the vector unit pays for a block however few the elements, and SLP (which cannot be told that
// a vector outside a block has no instruction) would otherwise "vectorise" pairs and triples of scalars into code that is scalarised again
static InstructionCost strips(Type *T) {
  return rawStrips(T) * (cast<FixedVectorType>(T)->getNumElements() < 4 ? 32 : 1);
}

// the vectoriser asks how many registers a vector takes (LoopVectorize drops a VF that "will not generate any vector instructions", i.e. whose
// type the target would scalarise): one for each strip of 256 bits
unsigned PDP64TTIImpl::getNumberOfParts(Type *Tp) const {
  if (legalVec(Tp)) return (unsigned)rawStrips(Tp).getValue();
  return BaseT::getNumberOfParts(Tp);
}

bool PDP64TTIImpl::enableInterleavedAccessVectorization() const { return EnableInterleave; }

bool PDP64TTIImpl::isLegalToVectorizeReduction(const RecurrenceDescriptor &R, ElementCount VF) const {
  Type *T = R.getRecurrenceType();
  if (!legalLane(T)) return false;
  switch (R.getRecurrenceKind()) {
  case RecurKind::Add: return !isFP(T);                            // vacc
  case RecurKind::FAdd: return isFP(T) && R.getFastMathFlags().allowReassoc();
  case RecurKind::SMax: case RecurKind::SMin: return !isFP(T);     // vmaxacc / vminacc
  case RecurKind::UMax: case RecurKind::UMin: return !isFP(T) && T->getScalarSizeInBits() <= 32;
  case RecurKind::FMax: case RecurKind::FMin: return isFP(T);
  default: return false;   // mul, and, or, xor, fmul, select-compare, fmaximum ...: no accumulating instruction
  }
}

void PDP64TTIImpl::getUnrollingPreferences(Loop *, ScalarEvolution &, TTI::UnrollingPreferences &UP,
                                           OptimizationRemarkEmitter *) const {
  // a vec block is the loop; unrolling the scalar fallback or epilogue only makes code (and breaks the shape the lowering looks for)
  UP.Partial = UP.Runtime = false;
  UP.UpperBound = false;
  UP.Threshold = UP.PartialThreshold = 0;
  UP.MaxCount = 1;
}

InstructionCost PDP64TTIImpl::getArithmeticInstrCost(unsigned Opcode, Type *Ty, TTI::TargetCostKind CostKind,
                                                     TTI::OperandValueInfo O1, TTI::OperandValueInfo O2,
                                                     ArrayRef<const Value *> Args, const Instruction *CxtI) const {
  if (!Ty->isVectorTy())
    return BaseT::getArithmeticInstrCost(Opcode, Ty, CostKind, O1, O2, Args, CxtI);
  if (!legalVec(Ty)) return InstructionCost::getInvalid();
  bool F = isFP(cast<VectorType>(Ty)->getElementType());
  switch (Opcode) {
  case Instruction::Add: case Instruction::Sub: case Instruction::Mul:
  case Instruction::And: case Instruction::Or: case Instruction::Xor:
  case Instruction::Shl: case Instruction::LShr: case Instruction::AShr:
    return F ? InstructionCost::getInvalid() : strips(Ty);
  case Instruction::FAdd: case Instruction::FSub: case Instruction::FMul:
    return F ? strips(Ty) : InstructionCost::getInvalid();
  default:   // sdiv udiv srem urem fdiv frem: nothing in the ISA
    return InstructionCost::getInvalid();
  }
}

InstructionCost PDP64TTIImpl::getShuffleCost(TTI::ShuffleKind Kind, VectorType *DstTy, VectorType *SrcTy,
                                             ArrayRef<int> Mask, TTI::TargetCostKind CostKind, int Index,
                                             VectorType *SubTp, ArrayRef<const Value *> Args,
                                             const Instruction *CxtI) const {
  // a splat of a loop-invariant scalar is the scalar operand of the lane operation (or vmov): free.  Anything else has no instruction.
  if (Kind == TTI::SK_Broadcast) return 0;
  // the deinterleave of a load group is vlseg, the interleave of a store group is vsseg: the interleaved-access cost accounts for them.
  // Any other shuffle has no instruction.  A large cost and not Invalid: an Invalid cost compares as 0 in the passes that only compare totals
  // (VectorCombine merged three splat products into one <4 x float> operation plus a shuffle of splats, which no vec block can run).
  return 1000;
}

InstructionCost PDP64TTIImpl::getCastInstrCost(unsigned Opcode, Type *Dst, Type *Src, TTI::CastContextHint CCH,
                                               TTI::TargetCostKind CostKind, const Instruction *I) const {
  if (!Dst->isVectorTy() && !Src->isVectorTy())
    return BaseT::getCastInstrCost(Opcode, Dst, Src, CCH, CostKind, I);
  if (!legalVec(Dst) || !legalVec(Src)) return InstructionCost::getInvalid();
  switch (Opcode) {
  case Instruction::ZExt: case Instruction::SExt: case Instruction::FPExt:
  case Instruction::Trunc: case Instruction::FPTrunc:
    // a lane type changes only inside a load (vld.bu.l, vld.f.d) or a store (vst.l.b, vsts, vst.d.f) -- or as the extension of a reduction (vacc.bu.l)
    if (CCH == TTI::CastContextHint::Normal || CCH == TTI::CastContextHint::Interleave) return 0;
    if (I && (Opcode == Instruction::ZExt || Opcode == Instruction::SExt)) {
      // an extension that only feeds a sum: the reduction instruction extends
      if (I->hasOneUse() && isa<BinaryOperator>(*I->user_begin())) {
        auto *U = cast<Instruction>(*I->user_begin());
        if (U->getOpcode() == Instruction::Add)
          for (Value *Op : U->operands())
            if (isa<PHINode>(Op) || (isa<BinaryOperator>(Op) && cast<Instruction>(Op)->getOpcode() == Instruction::Add)) return 0;
      }
    }
    return InstructionCost::getInvalid();
  default:   // int <-> fp, bitcast of vectors, pointers
    return InstructionCost::getInvalid();
  }
}

InstructionCost PDP64TTIImpl::getCmpSelInstrCost(unsigned Opcode, Type *ValTy, Type *CondTy, CmpInst::Predicate Pred,
                                                 TTI::TargetCostKind CostKind, TTI::OperandValueInfo O1,
                                                 TTI::OperandValueInfo O2, const Instruction *I) const {
  // no compare that makes a mask, no select: a vector compare or select is Invalid (scalar: the branch diamond the back end makes)
  // (a <1 x i1> condition is what LoopVectorize builds for the scalar loop's own select: scalar)
  auto Wide = [](Type *T) { auto *V = dyn_cast_or_null<FixedVectorType>(T); return V && V->getNumElements() > 1; };
  if (Wide(ValTy) || Wide(CondTy)) return InstructionCost::getInvalid();
  // scalar: a compare is a cbCC fused with its branch (1); a select is a branch diamond (an extra compare, two moves and a join)
  return Opcode == Instruction::Select ? 3 : 1;
}

InstructionCost PDP64TTIImpl::getVectorInstrCost(unsigned Opcode, Type *Val, TTI::TargetCostKind CostKind,
                                                 unsigned Index, const Value *Op0, const Value *Op1) const {
  // insertelement / extractelement: no instruction (a vector register is not readable outside the block)
  return InstructionCost((int64_t)ScalarizeCost);
}

InstructionCost PDP64TTIImpl::getMemoryOpCost(unsigned Opcode, Type *Src, Align Alignment, unsigned AddressSpace,
                                              TTI::TargetCostKind CostKind, TTI::OperandValueInfo OpInfo,
                                              const Instruction *I) const {
  if (!Src->isVectorTy())
    return BaseT::getMemoryOpCost(Opcode, Src, Alignment, AddressSpace, CostKind, OpInfo, I);
  if (!legalVec(Src)) return InstructionCost::getInvalid();
  return strips(Src);   // vld / vst: one for each strip
}

InstructionCost PDP64TTIImpl::getInterleavedMemoryOpCost(unsigned Opcode, Type *VecTy, unsigned Factor,
                                                         ArrayRef<unsigned> Indices, Align Alignment,
                                                         unsigned AddressSpace, TTI::TargetCostKind CostKind,
                                                         bool UseMaskForCond, bool UseMaskForGaps) const {
  if (UseMaskForCond || UseMaskForGaps) return InstructionCost::getInvalid();
  if (Factor < 2 || Factor > 4 || !legalVec(VecTy)) return InstructionCost::getInvalid();
  // only a group with every field used is vlseg / vsseg (a gap would need a mask); the cost is that of the wide access, per field
  if (Indices.size() != Factor) return InstructionCost::getInvalid();
  return strips(VecTy);
}

InstructionCost PDP64TTIImpl::getIntrinsicInstrCost(const IntrinsicCostAttributes &ICA, TTI::TargetCostKind CostKind) const {
  Type *RT = ICA.getReturnType();
  if (!RT->isVectorTy())
    return BaseT::getIntrinsicInstrCost(ICA, CostKind);
  if (!legalVec(RT)) return InstructionCost::getInvalid();
  Type *ET = cast<VectorType>(RT)->getElementType();
  unsigned W = ET->getScalarSizeInBits();
  switch (ICA.getID()) {
  case Intrinsic::smin: case Intrinsic::smax: case Intrinsic::umin: case Intrinsic::umax:
    return isFP(ET) ? InstructionCost::getInvalid() : strips(RT);
  case Intrinsic::abs:   // vabd of a difference; alone it is a sub and a max
    return isFP(ET) ? InstructionCost::getInvalid() : strips(RT) * 2;
  case Intrinsic::fshl: case Intrinsic::fshr:   // a rotate (both inputs the same value) is vshl, vshr and vor; a true funnel shift is not supported
    if (ICA.getArgs().size() == 3 && ICA.getArgs()[0] == ICA.getArgs()[1] && !isFP(ET)) return strips(RT) * 3;
    return InstructionCost::getInvalid();
  case Intrinsic::sadd_sat: case Intrinsic::ssub_sat: case Intrinsic::uadd_sat: case Intrinsic::usub_sat:
    return (!isFP(ET) && W <= 32) ? strips(RT) : InstructionCost::getInvalid();   // vadds/vsubs/vaddsu/vsubsu: b w l
  case Intrinsic::fma: case Intrinsic::fmuladd:
    return isFP(ET) ? strips(RT) : InstructionCost::getInvalid();   // vfma / vfnma
  case Intrinsic::assume: case Intrinsic::lifetime_start: case Intrinsic::lifetime_end: case Intrinsic::sideeffect:
    return 0;
  default:   // fabs, sqrt, floor, ctpop, bswap, ctlz, bitreverse, fshl, minnum/maxnum lane-wise (vmax.f exists, but fmax is NaN-aware)...
    if (ICA.getID() == Intrinsic::maxnum || ICA.getID() == Intrinsic::minnum) {
      // vmax.f / vmin.f: only with nnan (the reduction pattern); else Invalid
      if (isFP(ET) && ICA.getFlags().noNaNs()) return strips(RT);
    }
    return InstructionCost::getInvalid();
  }
}

InstructionCost PDP64TTIImpl::getArithmeticReductionCost(unsigned Opcode, VectorType *Ty, std::optional<FastMathFlags> FMF,
                                                         TTI::TargetCostKind CostKind) const {
  if (!legalVec(Ty)) return InstructionCost::getInvalid();
  bool F = isFP(Ty->getElementType());
  switch (Opcode) {
  case Instruction::Add:
    return F ? InstructionCost::getInvalid() : strips(Ty);        // vacc, committed at the end of each strip
  case Instruction::FAdd:
    return (F && FMF && FMF->allowReassoc()) ? strips(Ty) : InstructionCost::getInvalid();
  default:
    return InstructionCost::getInvalid();
  }
}

InstructionCost PDP64TTIImpl::getMinMaxReductionCost(Intrinsic::ID IID, VectorType *Ty, FastMathFlags FMF,
                                                     TTI::TargetCostKind CostKind) const {
  if (!legalVec(Ty)) return InstructionCost::getInvalid();
  Type *ET = Ty->getElementType();
  switch (IID) {
  case Intrinsic::vector_reduce_smax: case Intrinsic::vector_reduce_smin:
    return isFP(ET) ? InstructionCost::getInvalid() : strips(Ty);
  case Intrinsic::vector_reduce_umax: case Intrinsic::vector_reduce_umin:
    return (!isFP(ET) && ET->getScalarSizeInBits() <= 32) ? strips(Ty) : InstructionCost::getInvalid();
  case Intrinsic::vector_reduce_fmax: case Intrinsic::vector_reduce_fmin:
    return (isFP(ET) && FMF.noNaNs()) ? strips(Ty) : InstructionCost::getInvalid();
  default:
    return InstructionCost::getInvalid();
  }
}
