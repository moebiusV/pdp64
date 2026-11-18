//===-- PDP64TargetTransformInfo.h - the cost model of the vec blocks -----===//
//
// What LLVM's vectorisers (LoopVectorize, SLP) are told about the pdp64: sixteen hidden vector registers of
// 256 bits (v0-v15, only inside a `vec` ... `vend` block, but a strip is 32 bytes), lanes of b w l q f d, one
// instruction for each strip of a whole vector, and NOTHING for what the ISA lacks: no shuffle, no select or
// compare producing a mask, no masked or predicated operation, no scatter, no lane insert/extract, no integer
// division, no conversion between lane types except as part of a load or a store (vld.bu.l, vst.l.b, vsts).
// An operation the machine has no instruction for costs Invalid, so that the vectorisation factor that needs it
// is dropped (LoopVectorize) or the tree is not built (SLP).  See llvm/README.md, stage 2b.
//===----------------------------------------------------------------------===//
#ifndef LLVM_LIB_TARGET_PDP64_PDP64TARGETTRANSFORMINFO_H
#define LLVM_LIB_TARGET_PDP64_PDP64TARGETTRANSFORMINFO_H

#include "PDP64Subtarget.h"
#include "PDP64TargetMachine.h"
#include "llvm/CodeGen/BasicTTIImpl.h"

namespace llvm {

class PDP64TTIImpl final : public BasicTTIImplBase<PDP64TTIImpl> {
  using BaseT = BasicTTIImplBase<PDP64TTIImpl>;
  using TTI = TargetTransformInfo;
  friend BaseT;

  const PDP64Subtarget *ST;
  const PDP64TargetLowering *TLI;
  const PDP64Subtarget *getST() const { return ST; }
  const PDP64TargetLowering *getTLI() const { return TLI; }

  static constexpr unsigned VecRegBits = 256;

public:
  explicit PDP64TTIImpl(const PDP64TargetMachine *TM, const Function &F)
      : BaseT(TM, F.getDataLayout()), ST(TM->getSubtargetImpl(F)),
        TLI(ST->getTargetLowering()) {}

  // ---- registers
  bool enableInterleavedAccessVectorization() const override;
  // The machine has 16 hidden vector registers (v0-v15).  LoopVectorize counts every loop-invariant splat as a live vector register, but here a splat is a
  // scalar operand of the lane instruction (a general register), so counting 16 refuses VFs that fit (a 4x3 matrix-vector product has 12 splats and 7 live
  // vectors); the count is doubled and the lowering checks the real limit (PDP64VecLoop: more than 16 live vectors leaves the loop scalarised).
  unsigned getNumberOfRegisters(unsigned ClassID) const override {
    return ClassID == 1 ? 32 : 27;
  }
  TypeSize getRegisterBitWidth(TTI::RegisterKind K) const override {
    switch (K) {
    case TTI::RGK_Scalar: return TypeSize::getFixed(64);
    case TTI::RGK_FixedWidthVector: return TypeSize::getFixed(VecRegBits);
    case TTI::RGK_ScalableVector: return TypeSize::getScalable(0);
    }
    llvm_unreachable("bad register kind");
  }
  // SLP (the only user of this) rejects every vector narrower than this: a vector value outside a loop has no instruction here (the vector unit is a vec block over a stream), so SLP
  // can only make code that is scalarised again; a minimum above the 256-bit maximum turns it off
  unsigned getMinVectorRegisterBitWidth() const override { return 4096; }
  bool shouldMaximizeVectorBandwidth(TTI::RegisterKind K) const override {
    return K == TTI::RGK_FixedWidthVector;   // the narrowest lane type (after MinBWs) sets the factor: bytes -> 32 lanes
  }
  ElementCount getMinimumVF(unsigned ElemWidth, bool Scalable) const override {
    return ElementCount::getFixed(Scalable ? 0 : 2);
  }
  // only SLP asks this: its trees need a vector value outside a loop, and the machine has none (vector instructions exist only in a vec block over a
  // stream): a maximum of 1 turns SLP off (llvm/README.md, stage 2b)
  unsigned getMaximumVF(unsigned ElemWidth, unsigned Opcode) const override { return 1; }
  // the hardware strips the region itself: one pass of the vectoriser, no interleaving, no unrolling, no epilogue
  unsigned getMaxInterleaveFactor(ElementCount VF) const override { return 1; }
  bool preferEpilogueVectorization() const override { return false; }
  bool preferPredicateOverEpilogue(TailFoldingInfo *) const override { return false; }
  bool hasActiveVectorLength() const override { return false; }
  bool enableOrderedReductions() const override { return false; }
  // A reduction the machine has an accumulating instruction for (vacc, vmaxacc, vminacc) is made out of the loop, as LoopVectorize does by default.  For
  // the others (product, and, or, xor) the in-loop form is asked for: its cost (getArithmeticReductionCost) is Invalid, and so LoopVectorize does not
  // vectorise the loop (the out-of-loop reduction's final step costs nothing in LoopVectorize's model, so the loop would be vectorised and then not lowered).
  bool preferInLoopReduction(RecurKind K, Type *Ty) const override {
    switch (K) {
    case RecurKind::Add: case RecurKind::FAdd: case RecurKind::SMax: case RecurKind::SMin: case RecurKind::UMax: case RecurKind::UMin:
    case RecurKind::FMax: case RecurKind::FMin: return false;
    default: return true;
    }
  }
  bool isLegalToVectorizeReduction(const RecurrenceDescriptor &RdxDesc, ElementCount VF) const override;
  void getUnrollingPreferences(Loop *L, ScalarEvolution &SE, TTI::UnrollingPreferences &UP,
                               OptimizationRemarkEmitter *ORE) const override;

  // ---- legality of memory operations: no masks, no gather, no scatter (the gather vldx was removed in wave 1, errata 170)
  bool isLegalMaskedLoad(Type *, Align, unsigned) const override { return false; }
  bool isLegalMaskedStore(Type *, Align, unsigned) const override { return false; }
  bool isLegalMaskedGather(Type *, Align) const override { return false; }
  bool isLegalMaskedScatter(Type *, Align) const override { return false; }
  bool isLegalStridedLoadStore(Type *, Align) const override { return false; }

  // ---- costs
  unsigned getNumberOfParts(Type *Tp) const override;
  InstructionCost getArithmeticInstrCost(unsigned Opcode, Type *Ty, TTI::TargetCostKind CostKind,
                                         TTI::OperandValueInfo Op1Info = {TTI::OK_AnyValue, TTI::OP_None},
                                         TTI::OperandValueInfo Op2Info = {TTI::OK_AnyValue, TTI::OP_None},
                                         ArrayRef<const Value *> Args = {},
                                         const Instruction *CxtI = nullptr) const override;
  InstructionCost getShuffleCost(TTI::ShuffleKind Kind, VectorType *DstTy, VectorType *SrcTy,
                                 ArrayRef<int> Mask, TTI::TargetCostKind CostKind, int Index,
                                 VectorType *SubTp, ArrayRef<const Value *> Args = {},
                                 const Instruction *CxtI = nullptr) const override;
  InstructionCost getCastInstrCost(unsigned Opcode, Type *Dst, Type *Src, TTI::CastContextHint CCH,
                                   TTI::TargetCostKind CostKind, const Instruction *I = nullptr) const override;
  InstructionCost getCmpSelInstrCost(unsigned Opcode, Type *ValTy, Type *CondTy, CmpInst::Predicate VecPred,
                                     TTI::TargetCostKind CostKind,
                                     TTI::OperandValueInfo Op1Info = {TTI::OK_AnyValue, TTI::OP_None},
                                     TTI::OperandValueInfo Op2Info = {TTI::OK_AnyValue, TTI::OP_None},
                                     const Instruction *I = nullptr) const override;
  using BaseT::getVectorInstrCost;
  InstructionCost getVectorInstrCost(unsigned Opcode, Type *Val, TTI::TargetCostKind CostKind, unsigned Index,
                                     const Value *Op0, const Value *Op1) const override;
  InstructionCost getMemoryOpCost(unsigned Opcode, Type *Src, Align Alignment, unsigned AddressSpace,
                                  TTI::TargetCostKind CostKind,
                                  TTI::OperandValueInfo OpInfo = {TTI::OK_AnyValue, TTI::OP_None},
                                  const Instruction *I = nullptr) const override;
  InstructionCost getMaskedMemoryOpCost(unsigned, Type *, Align, unsigned, TTI::TargetCostKind) const override {
    return InstructionCost::getInvalid();
  }
  InstructionCost getGatherScatterOpCost(unsigned, Type *, const Value *, bool, Align, TTI::TargetCostKind,
                                         const Instruction *) const override {
    return InstructionCost::getInvalid();
  }
  InstructionCost getInterleavedMemoryOpCost(unsigned Opcode, Type *VecTy, unsigned Factor,
                                             ArrayRef<unsigned> Indices, Align Alignment, unsigned AddressSpace,
                                             TTI::TargetCostKind CostKind, bool UseMaskForCond = false,
                                             bool UseMaskForGaps = false) const override;
  InstructionCost getIntrinsicInstrCost(const IntrinsicCostAttributes &ICA, TTI::TargetCostKind CostKind) const override;
  InstructionCost getArithmeticReductionCost(unsigned Opcode, VectorType *Ty, std::optional<FastMathFlags> FMF,
                                             TTI::TargetCostKind CostKind) const override;
  InstructionCost getMinMaxReductionCost(Intrinsic::ID IID, VectorType *Ty, FastMathFlags FMF,
                                         TTI::TargetCostKind CostKind) const override;
  InstructionCost getExtendedReductionCost(unsigned, bool, Type *, VectorType *, std::optional<FastMathFlags>,
                                           TTI::TargetCostKind) const override {
    return InstructionCost::getInvalid();   // (LoopVectorize then costs the extension and the reduction apart)
  }
};

} // namespace llvm
#endif
