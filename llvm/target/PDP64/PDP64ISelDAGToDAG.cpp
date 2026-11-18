//===-- PDP64ISelDAGToDAG.cpp - A dag to dag inst selector for the pdp64 --===//
#include "PDP64.h"
#include "PDP64TargetMachine.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/SelectionDAGISel.h"
#include "llvm/IR/Constants.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/ErrorHandling.h"

using namespace llvm;

#define DEBUG_TYPE "pdp64-isel"
#define PASS_NAME "PDP64 DAG->DAG Pattern Instruction Selection"

namespace {
class PDP64DAGToDAGISel : public SelectionDAGISel {
public:
  PDP64DAGToDAGISel() = delete;
  PDP64DAGToDAGISel(PDP64TargetMachine &TM, CodeGenOptLevel OptLevel)
      : SelectionDAGISel(TM, OptLevel) {}

  // the address modes (ComplexPatterns of PDP64InstrInfo.td)
  bool SelectAddrRI(SDValue Addr, SDValue &Base, SDValue &Disp);
  bool SelectAddrRX(SDValue Addr, SDValue &Base, SDValue &Disp, SDValue &Idx,
                    SDValue &Scale);
  bool SelectLeaRX(SDValue Addr, SDValue &Base, SDValue &Idx, SDValue &Scale);

  void Select(SDNode *N) override;
  bool tryIndexed(SDNode *N);

#include "PDP64GenDAGISel.inc"

private:
  SDValue base(SDValue V) {
    if (auto *FI = dyn_cast<FrameIndexSDNode>(V))
      return CurDAG->getTargetFrameIndex(FI->getIndex(), MVT::i64);
    return V;
  }
  // a scaled index: x << 1..3 gives (x, 2..8), anything else (v, 1)
  bool scaled(SDValue V, SDValue &Idx, int &Scale) {
    if (V.getOpcode() == ISD::SHL && isa<ConstantSDNode>(V.getOperand(1))) {
      uint64_t C = V.getConstantOperandVal(1);
      if (C >= 1 && C <= 3) {
        Idx = V.getOperand(0);
        Scale = 1 << C;
        return true;
      }
    }
    Idx = V;
    Scale = 1;
    return false;
  }
};

class PDP64DAGToDAGISelLegacy : public SelectionDAGISelLegacy {
public:
  static char ID;
  PDP64DAGToDAGISelLegacy(PDP64TargetMachine &TM, CodeGenOptLevel OptLevel)
      : SelectionDAGISelLegacy(
            ID, std::make_unique<PDP64DAGToDAGISel>(TM, OptLevel)) {}
};
} // namespace

char PDP64DAGToDAGISelLegacy::ID;

INITIALIZE_PASS(PDP64DAGToDAGISelLegacy, DEBUG_TYPE, PASS_NAME, false, false)

FunctionPass *llvm::createPDP64ISelDag(PDP64TargetMachine &TM,
                                       CodeGenOptLevel OptLevel) {
  return new PDP64DAGToDAGISelLegacy(TM, OptLevel);
}

// d(rN): a register (or frame index) and a displacement of DispBits bits
bool PDP64DAGToDAGISel::SelectAddrRI(SDValue Addr, SDValue &Base, SDValue &Disp) {
  SDLoc DL(Addr);
  if (Addr.getOpcode() == ISD::ADD && isa<ConstantSDNode>(Addr.getOperand(1))) {
    int64_t C = cast<ConstantSDNode>(Addr.getOperand(1))->getSExtValue();
    if (isInt<PDP64Layout::DispBits>(C)) {
      Base = base(Addr.getOperand(0));
      Disp = CurDAG->getSignedTargetConstant(C, DL, MVT::i64);
      return true;
    }
  }
  Base = base(Addr);
  Disp = CurDAG->getTargetConstant(0, DL, MVT::i64);
  return true;
}

// d(rN)(rX*s): the sum of two registers, one of them shifted left by 1..3
bool PDP64DAGToDAGISel::SelectAddrRX(SDValue Addr, SDValue &Base, SDValue &Disp,
                                     SDValue &Idx, SDValue &Scale) {
  if (Addr.getOpcode() != ISD::ADD)
    return false;
  SDValue A = Addr.getOperand(0), B = Addr.getOperand(1);
  if (isa<ConstantSDNode>(A) || isa<ConstantSDNode>(B))
    return false; // d(rN) does it
  if (isa<FrameIndexSDNode>(A) || isa<FrameIndexSDNode>(B))
    return false; // the displacement of a frame index is not known yet
  SDValue I;
  int S;
  if (B.getOpcode() == ISD::SHL && scaled(B, I, S)) {
    // base A, index B >> shift
  } else if (A.getOpcode() == ISD::SHL && scaled(A, I, S)) {
    std::swap(A, B);
  } else {
    I = B;
    S = 1;
  }
  SDLoc DL(Addr);
  Base = A;
  Idx = I;
  Scale = CurDAG->getTargetConstant(S, DL, MVT::i64);
  Disp = CurDAG->getTargetConstant(0, DL, MVT::i64);
  return true;
}

// lea (rN)(rX*s), rd for an add with a shifted operand
bool PDP64DAGToDAGISel::SelectLeaRX(SDValue Addr, SDValue &Base, SDValue &Idx,
                                    SDValue &Scale) {
  if (Addr.getOpcode() != ISD::ADD)
    return false;
  SDValue A = Addr.getOperand(0), B = Addr.getOperand(1);
  if (isa<ConstantSDNode>(A) || isa<ConstantSDNode>(B))
    return false;
  int S;
  SDValue I;
  if (B.getOpcode() == ISD::SHL && scaled(B, I, S)) {
    Base = A;
  } else if (A.getOpcode() == ISD::SHL && scaled(A, I, S)) {
    Base = B;
  } else {
    return false;
  }
  Idx = I;
  Scale = CurDAG->getTargetConstant(S, SDLoc(Addr), MVT::i64);
  return true;
}

// Loads and stores that move the pointer: (rN)+ after, -(rN) before.
bool PDP64DAGToDAGISel::tryIndexed(SDNode *N) {
  using namespace PDP64;
  SDLoc DL(N);
  auto *LD = dyn_cast<LoadSDNode>(N);
  auto *ST = dyn_cast<StoreSDNode>(N);
  if (!LD && !ST)
    return false;
  const MemSDNode *M = cast<MemSDNode>(N);
  ISD::MemIndexedMode AM = LD ? LD->getAddressingMode() : ST->getAddressingMode();
  if (AM == ISD::UNINDEXED)
    return false;
  EVT MemVT = M->getMemoryVT();
  int64_t Size = MemVT.getStoreSize();
  SDValue Off = LD ? LD->getOffset() : ST->getOffset();
  auto *C = dyn_cast<ConstantSDNode>(Off);
  if (!C)
    return false;
  int64_t V = C->getSExtValue();
  bool Post;
  if (AM == ISD::POST_INC && V == Size)
    Post = true;
  else if ((AM == ISD::PRE_DEC && V == Size) || (AM == ISD::PRE_INC && V == -Size))
    Post = false;
  else
    return false;
  unsigned Opc = 0;
  if (LD) {
    ISD::LoadExtType Ext = LD->getExtensionType();
    switch (MemVT.getSimpleVT().SimpleTy) {
    case MVT::i64: case MVT::f64: Opc = Post ? LDQX_PI : LDQX_PD; break;
    case MVT::f32: Opc = Post ? LDLX_PI : LDLX_PD; break;
    case MVT::i32:
      Opc = Ext == ISD::ZEXTLOAD ? (Post ? LDZLX_PI : LDZLX_PD) : (Post ? LDLX_PI : LDLX_PD);
      break;
    case MVT::i16:
      Opc = Ext == ISD::ZEXTLOAD ? (Post ? LDZWX_PI : LDZWX_PD) : (Post ? LDWX_PI : LDWX_PD);
      break;
    case MVT::i8:
      Opc = Ext == ISD::ZEXTLOAD ? (Post ? LDZBX_PI : LDZBX_PD) : (Post ? LDBX_PI : LDBX_PD);
      break;
    default: return false;
    }
    SDNode *R = CurDAG->getMachineNode(Opc, DL, N->getValueType(0), MVT::i64, MVT::Other,
                                       LD->getBasePtr(), LD->getChain());
    CurDAG->setNodeMemRefs(cast<MachineSDNode>(R), {LD->getMemOperand()});
    ReplaceUses(SDValue(N, 0), SDValue(R, 0));
    ReplaceUses(SDValue(N, 1), SDValue(R, 1));
    ReplaceUses(SDValue(N, 2), SDValue(R, 2));
  } else {
    switch (MemVT.getSimpleVT().SimpleTy) {
    case MVT::i64: case MVT::f64: Opc = Post ? STQX_PI : STQX_PD; break;
    case MVT::i32: case MVT::f32: Opc = Post ? STLX_PI : STLX_PD; break;
    case MVT::i16: Opc = Post ? STWX_PI : STWX_PD; break;
    case MVT::i8: Opc = Post ? STBX_PI : STBX_PD; break;
    default: return false;
    }
    SDNode *R = CurDAG->getMachineNode(Opc, DL, MVT::i64, MVT::Other, ST->getValue(),
                                       ST->getBasePtr(), ST->getChain());
    CurDAG->setNodeMemRefs(cast<MachineSDNode>(R), {ST->getMemOperand()});
    ReplaceUses(SDValue(N, 0), SDValue(R, 0));
    ReplaceUses(SDValue(N, 1), SDValue(R, 1));
  }
  CurDAG->RemoveDeadNode(N);
  return true;
}

void PDP64DAGToDAGISel::Select(SDNode *Node) {
  if (Node->isMachineOpcode()) {
    Node->setNodeId(-1);
    return;
  }
  if ((Node->getOpcode() == ISD::LOAD || Node->getOpcode() == ISD::STORE) &&
      tryIndexed(Node))
    return;
  SelectCode(Node);
}
