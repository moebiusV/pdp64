//===-- PDP64VecLoop.cpp - an innermost counted loop becomes one vec block -===//
//
// Approach (b) of stage 2: hardware strip mining.  The `vec Rs, Re` ... `vend`
// block runs its instructions once for each strip of the region [Rs, Re) of its
// first stream, VL elements at a time, the last strip short.  So a loop
//
//     for (i = 0; i < n; i++) body        // loads, lane operations, stores, reductions
//
// whose body is made of consecutive-access loads and stores (SCEV {p,+,size}),
// lane-wise arithmetic and reductions into scalars, is not vectorised by a
// factor chosen here: it is rewritten as ONE block that covers all n elements,
// with no scalar remainder loop and no loop control.  The loop is replaced (at
// the end of its preheader) by one inline-assembly statement whose operands are
// the stream pointers (read and written: each `(Ra)+` moves its pointer), the
// end of the first stream, the loop-invariant scalars, and the reduction
// accumulators (read and written).  The vector registers are assigned here (the
// hidden registers v0..v15 are not visible to the register allocator): a linear
// scan over the straight-line body.
//
// Safety:
//  * a strip does every load before any of its stores becomes visible, and strips
//    run in order.  That equals the loop only when no store can touch an element
//    another iteration reads or writes.  Two accesses are fine when their
//    addresses are the same recurrence (the same element in each iteration, with
//    the load before the store in the body), when their underlying objects are
//    different identified objects, or when a run-time test finds the ranges
//    disjoint; otherwise the ORIGINAL scalar loop is kept as the fallback
//    (loop versioning) and runs when the test fails.
//  * the block has no hidden accumulation (no vclr, no tile): the integer
//    registers it changes are the (Ra)+ pointers and the reduction registers,
//    both committed when a strip ends; after a fault the block resumes at the
//    strip it stopped in with the registers as they were.  The output
//    operands are early-clobber, so no input register is one of them.
//  * floating-point reductions are reassociated (the lanes are summed in a
//    different order): only with the `reassoc` flag, as LLVM's own vectoriser.
//  * element alignment is checked per element by the hardware, as for the
//    scalar loop.
//===----------------------------------------------------------------------===//
#include "PDP64.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/ADT/StringSet.h"
#include "llvm/Analysis/AliasAnalysis.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/Analysis/ScalarEvolutionExpressions.h"
#include "llvm/Analysis/ValueTracking.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/InlineAsm.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/PatternMatch.h"
#include "llvm/InitializePasses.h"
#include "llvm/Pass.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Transforms/Utils.h"
#include "llvm/Transforms/Utils/Local.h"
#include "llvm/Transforms/Utils/ScalarEvolutionExpander.h"

using namespace llvm;
using namespace llvm::PatternMatch;

#define DEBUG_TYPE "pdp64-vecloop"

static cl::opt<bool> EnableVecLoop("pdp64-vecloop",
    cl::desc("pdp64: turn innermost counted loops into one vec block (hardware strip mining)"),
    cl::init(false));
static cl::opt<bool> VecLoopVerbose("pdp64-vecloop-verbose",
    cl::desc("pdp64: say why each innermost loop was or was not turned into a vec block"),
    cl::init(false));
static cl::opt<bool> VecLoopStrip("pdp64-vecloop-strip",
    cl::desc("pdp64: approach (a): one vec block for each strip of VL elements inside a scalar loop (what a fixed-width vectoriser's loop becomes), "
             "and one block for the remainder, instead of one block for the whole loop"),
    cl::init(false));
static cl::opt<unsigned> VecLoopMaxChecks("pdp64-vecloop-max-checks",
    cl::desc("pdp64: the most run-time overlap tests a vec block may need"), cl::init(64));

STATISTIC(NumBlocks, "loops turned into a vec block");
STATISTIC(NumVersioned, "of them with a run-time overlap test and the scalar loop as fallback");

namespace {

// ---- the program of the block, before the vector registers are assigned ----------------------------------------
struct Opnd {
  enum K { None, V, S, I } Kind = None;
  int Id = -1;      // a virtual vector register (V) or an index in Scalars (S)
  int64_t Imm = 0;  // I
  static Opnd v(int X) { Opnd O; O.Kind = V; O.Id = X; return O; }
  static Opnd s(int X) { Opnd O; O.Kind = S; O.Id = X; return O; }
  static Opnd i(int64_t X) { Opnd O; O.Kind = I; O.Imm = X; return O; }
};
struct VOp {
  enum K { Load, Store, Lane, Mov, Fma, Reduce } Kind;
  std::string Mn;     // mnemonic up to and including the dots (vadd.l, vld.bu.l, vst.l.b, vacc.l ...)
  int Dst = -1;       // virtual vector register written (Load, Lane, Mov, Fma)
  Opnd A, B;          // sources: A is a virtual register (Lane, Fma, Store, Reduce), B any operand
  int Stream = -1;    // memory operations
  int Acc = -1;       // Reduce: index in Accs
  int64_t Stride = 0; // strided memory operations (vldt, vstt): the bytes between elements
};
struct Stream {
  const SCEV *Start;
  int64_t Step;       // bytes between the elements: the access size
  Value *StartVal = nullptr;
  int LastUse = -1;   // index of the VOp that moves the pointer ((Ra)+)
  int FirstUse = -1;
};
struct Acc {
  PHINode *Phi;
  Instruction *Next;
  Type *Ty;
  const char *Base;   // vacc, vmaxacc, vminacc
  char Lane;
  bool IsFP;
};

static char laneChar(Type *T) {
  if (T->isFloatTy()) return 'f';
  if (T->isDoubleTy()) return 'd';
  if (auto *IT = dyn_cast<IntegerType>(T)) {
    switch (IT->getBitWidth()) {
    case 8: return 'b';
    case 16: return 'w';
    case 32: return 'l';
    case 64: return 'q';
    }
  }
  return 0;
}
static bool laneOK(Type *T) { return laneChar(T) != 0; }

static bool grammarHas(StringRef M) {
  static const StringSet<> Set = [] {
    StringSet<> S;
#define X(m) S.insert(m);
    PDP64_VEC_MNEMONICS(X)
#undef X
    return S;
  }();
  return Set.count(M);
}

class Analyzer {
public:
  Loop *L;
  ScalarEvolution &SE;
  const DataLayout &DL;
  std::string Why;

  SmallVector<VOp, 32> Prog;
  SmallVector<Stream, 8> Streams;
  SmallVector<Value *, 8> Scalars;       // loop-invariant values (operands "r")
  SmallVector<Acc, 2> Accs;
  DenseMap<Value *, int> VMap;           // IR value -> virtual vector register
  DenseMap<Value *, Type *> VLane;       // its lane type
  int NextV = 0;
  struct MemAcc { const SCEV *P; int64_t Size; bool Store; int Pos; Value *Ptr; bool Inv; int64_t ElSize = 0; };
  SmallVector<Instruction *, 16> Hoist;   // loop-invariant instructions (loads of invariant addresses, pure operations of invariants), in order: made in the preheader
  SmallPtrSet<Value *, 16> InvSet;
  struct RedStep { int Acc; Value *X; };
  DenseMap<Instruction *, RedStep> RedStepOf;
  SmallVector<MemAcc, 8> Mem;

  Analyzer(Loop *L, ScalarEvolution &SE, const DataLayout &DL) : L(L), SE(SE), DL(DL) {}

  bool fail(const Twine &W) { Why = W.str(); return false; }
  bool inLoop(Value *V) { auto *I = dyn_cast<Instruction>(V); return I && L->contains(I); }

  int scalarIdx(Value *V) {
    for (unsigned i = 0; i < Scalars.size(); ++i)
      if (Scalars[i] == V) return i;
    Scalars.push_back(V);
    return Scalars.size() - 1;
  }
  int streamIdx(const SCEVAddRecExpr *AR, int64_t Step) {
    for (unsigned i = 0; i < Streams.size(); ++i)
      if (Streams[i].Start == AR->getStart() && Streams[i].Step == Step) return i;
    Stream S;
    S.Start = AR->getStart();
    S.Step = Step;
    Streams.push_back(S);
    return Streams.size() - 1;
  }
  // a loop-invariant operand: a small constant is an immediate, anything else a register
  bool invariantOperand(Value *V, Opnd &O, bool AllowImm) {
    if (inLoop(V) && !InvSet.count(V)) return false;
    if (!V->getType()->isIntegerTy() && !V->getType()->isFloatingPointTy())
      return false;
    if (AllowImm)
      if (auto *CI = dyn_cast<ConstantInt>(V))
        if (CI->getValue().getSignificantBits() <= 16) {
          O = Opnd::i(CI->getSExtValue());
          return true;
        }
    O = Opnd::s(scalarIdx(V));
    return true;
  }
  bool operandOf(Value *V, Opnd &O, bool AllowImm = true) {
    auto It = VMap.find(V);
    if (It != VMap.end()) { O = Opnd::v(It->second); return true; }
    return invariantOperand(V, O, AllowImm && V->getType()->isIntegerTy());
  }
  int newV(Value *IR, Type *Lane) {
    int Id = NextV++;
    if (IR) { VMap[IR] = Id; VLane[IR] = Lane; }
    return Id;
  }

  // a consecutive access (step = size), or a strided one (step a multiple of the size, at most 1000 bytes: vldt / vstt)
  bool memAccess(Instruction *I, Value *Ptr, Type *Ty, bool Store, int &S, int64_t &Stride) {
    const SCEV *P = SE.getSCEV(Ptr);
    auto *AR = dyn_cast<SCEVAddRecExpr>(P);
    if (!AR || AR->getLoop() != L || !AR->isAffine())
      return fail("an address is not a recurrence of the loop");
    auto *Step = dyn_cast<SCEVConstant>(AR->getStepRecurrence(SE));
    int64_t Sz = DL.getTypeStoreSize(Ty);
    int64_t St = Step ? Step->getAPInt().getSExtValue() : 0;
    if (!Step || St < Sz || St % Sz || St > 1000)
      return fail("an access that is not consecutive or strided forwards");
    if (DL.getTypeStoreSize(Ty) != DL.getTypeSizeInBits(Ty) / 8)
      return fail("odd access size");
    S = streamIdx(AR, St);
    Stride = St == Sz ? 0 : St;
    Mem.push_back({P, St, Store, (int)Prog.size(), Ptr, false, Sz});
    return true;
  }
  void noteUse(int S) {
    Streams[S].LastUse = Prog.size() - 1;
    if (Streams[S].FirstUse < 0)
      Streams[S].FirstUse = Prog.size() - 1;
  }

  // m: memory suffix of a load of Ty extended (or not) to lane type Lane
  static std::string memSuffix(Type *Mem, bool Zext) {
    char C = laneChar(Mem);
    std::string S(1, C);
    if (Zext && C != 'f' && C != 'd') S += 'u';
    return S;
  }

  bool run();
  bool matchReduction(PHINode *Phi, Instruction *&Next, Acc &A);
  bool emitReduce(Instruction *I);
};

bool Analyzer::matchReduction(PHINode *Phi, Instruction *&Next, Acc &A) {
  if (Phi->getNumIncomingValues() != 2) return fail("a phi with more than two inputs");
  BasicBlock *Latch = L->getLoopLatch();
  Value *N = Phi->getIncomingValueForBlock(Latch);
  Next = dyn_cast<Instruction>(N);
  if (!Next || !L->contains(Next)) return fail("a phi that is not a reduction");
  Type *Ty = Phi->getType();
  A.Phi = Phi; A.Next = Next; A.Ty = Ty;
  A.IsFP = Ty->isFloatingPointTy();
  if (!laneOK(Ty)) return fail("reduction type");
  Value *R = Phi;
  int Ai = Accs.size();
  SmallVector<RedStep, 4> Steps;
  if (Next->getOpcode() == Instruction::Add) {
    // a chain: acc + x1 + x2 + ... (each add but the last has the next add as its only user)
    A.Base = "vacc";
    Instruction *Cur = Next;
    while (true) {
      if (Cur->getOpcode() != Instruction::Add) return fail("a reduction chain that is not all adds");
      Value *P0 = Cur->getOperand(0), *P1 = Cur->getOperand(1), *Prev, *X;
      auto Chainable = [&](Value *V) {
        auto *I = dyn_cast<Instruction>(V);
        return I && I->getOpcode() == Instruction::Add && L->contains(I) && I->hasOneUse() && !isa<PHINode>(I);
      };
      if (P0 == R) { Prev = P0; X = P1; }
      else if (P1 == R) { Prev = P1; X = P0; }
      else if (Chainable(P0)) { Prev = P0; X = P1; }
      else if (Chainable(P1)) { Prev = P1; X = P0; }
      else return fail("a reduction chain that does not end at its phi");
      Steps.push_back({Ai, X});
      RedStepOf[Cur] = {Ai, X};
      if (Prev == R) break;
      Cur = cast<Instruction>(Prev);
    }
  } else if (Next->getOpcode() == Instruction::FAdd) {
    if (!Next->hasAllowReassoc()) return fail("a floating-point sum without reassoc");
    Value *O0 = Next->getOperand(0), *O1 = Next->getOperand(1);
    if (O0 != R && O1 != R) return fail("reduction operand");
    A.Base = "vacc";
    RedStepOf[Next] = {Ai, O0 == R ? O1 : O0};
  } else if (auto *II = dyn_cast<IntrinsicInst>(Next)) {
    if (II->getIntrinsicID() == Intrinsic::smax) A.Base = "vmaxacc";
    else if (II->getIntrinsicID() == Intrinsic::smin) A.Base = "vminacc";
    else return fail("reduction intrinsic");
    Value *O0 = II->getArgOperand(0), *O1 = II->getArgOperand(1);
    if (O0 != R && O1 != R) return fail("reduction operand");
    RedStepOf[Next] = {Ai, O0 == R ? O1 : O0};
  } else if (auto *Sel = dyn_cast<SelectInst>(Next)) {
    // x > acc ? x : acc  (vmaxacc takes the lane when it is greater, as this does, NaN included)
    auto *Cmp = dyn_cast<FCmpInst>(Sel->getCondition());
    if (!Cmp || !Ty->isFloatingPointTy()) return fail("reduction select");
    Value *T = Sel->getTrueValue(), *F = Sel->getFalseValue();
    if (F != R) return fail("reduction select");
    if (Cmp->getPredicate() == FCmpInst::FCMP_OGT && Cmp->getOperand(0) == T && Cmp->getOperand(1) == R) A.Base = "vmaxacc";
    else if (Cmp->getPredicate() == FCmpInst::FCMP_OLT && Cmp->getOperand(0) == T && Cmp->getOperand(1) == R) A.Base = "vminacc";
    else return fail("reduction select");
    RedStepOf[Next] = {Ai, T};
  } else
    return fail("a phi that is not a sum, maximum or minimum");
  A.Lane = laneChar(Ty);
  Accs.push_back(A);
  return true;
}

// the Reduce operation of one step of an accumulator, at the instruction that is the step
bool Analyzer::emitReduce(Instruction *I) {
  RedStep RS = RedStepOf[I];
  Acc &A = Accs[RS.Acc];
  Value *Src = RS.X;
  if (A.Base == StringRef("vacc") && !A.IsFP)  // a sext of a narrower lane is the same reduction: vacc widens
    if (auto *C = dyn_cast<SExtInst>(Src))
      if (VMap.count(C->getOperand(0)) && laneOK(C->getOperand(0)->getType())) Src = C->getOperand(0);
  auto It = VMap.find(Src);
  if (It == VMap.end()) return fail("the reduced value is not a vector value");
  VOp Op;
  Op.Kind = VOp::Reduce;
  Op.Mn = (Twine(A.Base) + "." + Twine(laneChar(VLane[Src])) + " ").str();
  Op.A = Opnd::v(It->second);
  Op.Acc = RS.Acc;
  Prog.push_back(Op);
  return true;
}

bool Analyzer::run() {
  BasicBlock *H = L->getHeader();
  // the scalar scaffolding: what the addresses and the exit test are made of
  SmallPtrSet<Instruction *, 16> Scaf;
  SmallVector<Instruction *, 16> Work;
  auto Mark = [&](Value *V) {
    if (auto *I = dyn_cast<Instruction>(V))
      if (L->contains(I) && Scaf.insert(I).second) Work.push_back(I);
  };
  for (Instruction &I : *H) {
    if (auto *Ld = dyn_cast<LoadInst>(&I)) Mark(Ld->getPointerOperand());
    if (auto *St = dyn_cast<StoreInst>(&I)) Mark(St->getPointerOperand());
    if (auto *Br = dyn_cast<BranchInst>(&I)) if (Br->isConditional()) Mark(Br->getCondition());
  }
  while (!Work.empty()) {
    Instruction *I = Work.pop_back_val();
    if (isa<LoadInst>(I) || isa<CallInst>(I) || I->mayHaveSideEffects())
      return fail("an address or the exit test depends on a load or a call");
    if (auto *P = dyn_cast<PHINode>(I)) {
      auto *AR = dyn_cast<SCEVAddRecExpr>(SE.getSCEV(P));
      if (!AR || AR->getLoop() != L) return fail("an induction variable that is not a recurrence");
    }
    for (Value *Op : I->operands()) Mark(Op);
  }

  // the fused forms: a load only extended, a trunc only stored, a clamp only truncated and stored
  SmallPtrSet<Instruction *, 16> Skip;
  DenseMap<Instruction *, std::pair<Instruction *, bool>> ExtOf;  // load -> (its single extension, zext?)
  for (Instruction &I : *H) {
    auto *Ld = dyn_cast<LoadInst>(&I);
    if (!Ld || Scaf.count(Ld)) continue;
    if (Ld->use_empty()) continue;
    if (SE.isSCEVable(Ld->getPointerOperand()->getType()) && SE.isLoopInvariant(SE.getSCEV(Ld->getPointerOperand()), L)) continue;  // an invariant load is hoisted, with its extension
    Instruction *E = nullptr;
    bool Z = false, Ok = true;
    for (User *U : Ld->users()) {
      auto *UI = dyn_cast<Instruction>(U);
      if (UI && (isa<ZExtInst>(UI) || isa<SExtInst>(UI)) && L->contains(UI)) {
        if (E && (E->getType() != UI->getType() || isa<ZExtInst>(E) != isa<ZExtInst>(UI))) { Ok = false; break; }
        E = UI; Z = isa<ZExtInst>(UI);
      } else { Ok = false; break; }
    }
    if (Ok && E) {
      // every extension of the same type and kind is the same value: map them all
      ExtOf[Ld] = {E, Z};
      for (User *U : Ld->users()) Skip.insert(cast<Instruction>(U));
    }
  }
  struct SatSt { Value *Src; Type *MemTy; int Mode; };  // Mode 0: truncate, 1: signed clamp, 2: unsigned clamp
  DenseMap<StoreInst *, SatSt> StoreForm;
  for (Instruction &I : *H) {
    auto *St = dyn_cast<StoreInst>(&I);
    if (!St || Scaf.count(St)) continue;
    auto *Tr = dyn_cast<TruncInst>(St->getValueOperand());
    if (!Tr || !Tr->hasOneUse() || !L->contains(Tr)) continue;
    Type *MemTy = Tr->getType();
    unsigned NB = MemTy->getIntegerBitWidth();
    Value *Y = Tr->getOperand(0);
    int Mode = 0;
    Instruction *C1 = nullptr, *C2 = nullptr;
    // smin(smax(y, lo), hi) or smax(smin(y, hi), lo)
    auto Clamp = [&](Value *V, Intrinsic::ID Outer, Intrinsic::ID Inner, Value *&Y2, APInt &Lo, APInt &Hi) -> bool {
      auto *O = dyn_cast<IntrinsicInst>(V);
      if (!O || O->getIntrinsicID() != Outer || !O->hasOneUse()) return false;
      auto *In = dyn_cast<IntrinsicInst>(O->getArgOperand(0));
      auto *C = dyn_cast<ConstantInt>(O->getArgOperand(1));
      if (!In || In->getIntrinsicID() != Inner || !In->hasOneUse() || !C) return false;
      auto *D = dyn_cast<ConstantInt>(In->getArgOperand(1));
      if (!D) return false;
      Y2 = In->getArgOperand(0);
      if (Outer == Intrinsic::smin) { Hi = C->getValue(); Lo = D->getValue(); }
      else { Lo = C->getValue(); Hi = D->getValue(); }
      C1 = O; C2 = In;
      return true;
    };
    Value *Y2 = nullptr;
    APInt Lo, Hi;
    if (Clamp(Y, Intrinsic::smin, Intrinsic::smax, Y2, Lo, Hi) || Clamp(Y, Intrinsic::smax, Intrinsic::smin, Y2, Lo, Hi)) {
      unsigned W = Lo.getBitWidth();
      if (W > NB) {
        if (Lo == APInt::getSignedMinValue(NB).sext(W) && Hi == APInt::getSignedMaxValue(NB).sext(W)) Mode = 1;
        else if (Lo.isZero() && Hi == APInt::getMaxValue(NB).zext(W)) Mode = 2;
      }
      if (Mode) { Y = Y2; Skip.insert(C1); Skip.insert(C2); }
    }
    Skip.insert(Tr);
    StoreForm[St] = {Y, MemTy, Mode};
  }

  // a multiply with the contract flag whose only user is an add (or the subtrahend of a subtract) with it: a multiply-add (vfma / vfnma)
  DenseMap<Instruction *, Instruction *> MulOf;   // the fadd/fsub -> its fmul
  for (Instruction &I : *H) {
    if (I.getOpcode() != Instruction::FMul || !isa<FPMathOperator>(I) || !I.hasAllowContract() || !I.hasOneUse() || Scaf.count(&I)) continue;
    auto *U = dyn_cast<Instruction>(*I.user_begin());
    if (!U || !L->contains(U) || !isa<FPMathOperator>(U) || !U->hasAllowContract() || MulOf.count(U)) continue;
    bool IntoPhi = false;   // the sum of products: a reduction of a product, not a multiply-add
    for (Value *Op : U->operands()) if (auto *Ph = dyn_cast<PHINode>(Op)) if (Ph->getParent() == H) IntoPhi = true;
    if (IntoPhi) continue;
    if (U->getOpcode() == Instruction::FAdd || (U->getOpcode() == Instruction::FSub && U->getOperand(1) == &I)) {
      MulOf[U] = &I;
      Skip.insert(&I);
    }
  }

  // the body in order
  for (Instruction &I : *H) {
    if (Scaf.count(&I) || I.isTerminator() || (Skip.count(&I) && !isa<LoadInst>(&I))) continue;
    if (auto *AI = dyn_cast<IntrinsicInst>(&I)) if (AI->isAssumeLikeIntrinsic()) continue;
    if (RedStepOf.count(&I)) {
      if (!emitReduce(&I)) return false;
      continue;
    }
    // loop-invariant: a load of an address that does not change (made once, before the block, and tested against the stores), and pure
    // operations of invariants (a sext of such a load)
    if (!isa<PHINode>(&I) && !isa<StoreInst>(&I)) {
      bool Inv = true;
      for (Value *Op : I.operands())
        if (inLoop(Op) && !InvSet.count(Op)) Inv = false;
      if (auto *Ld = dyn_cast<LoadInst>(&I)) {
        if (Inv && SE.isSCEVable(Ld->getPointerOperand()->getType()) && SE.isLoopInvariant(SE.getSCEV(Ld->getPointerOperand()), L)) {
          if (!Ld->isSimple() || !laneOK(Ld->getType())) return fail("an invariant load that is not a simple scalar");
          InvSet.insert(Ld);
          Hoist.push_back(Ld);
          Mem.push_back({SE.getSCEV(Ld->getPointerOperand()), (int64_t)DL.getTypeStoreSize(Ld->getType()), false, (int)Prog.size(), Ld->getPointerOperand(), true});
          continue;
        }
      } else if (Inv && !I.mayHaveSideEffects() && !I.mayReadFromMemory() && !isa<CallInst>(&I) && !isa<FCmpInst>(&I) && !isa<SelectInst>(&I) &&
                 (I.getType()->isIntegerTy() || I.getType()->isFloatingPointTy()) && isSafeToSpeculativelyExecute(&I)) {
        InvSet.insert(&I);
        Hoist.push_back(&I);
        continue;
      }
    }
    if (auto *Ld = dyn_cast<LoadInst>(&I)) {
      if (!Ld->isSimple()) return fail("a volatile or atomic load");
      Type *MT = Ld->getType();
      if (!laneOK(MT)) return fail("load type");
      int S;
      int64_t Stride;
      if (!memAccess(Ld, Ld->getPointerOperand(), MT, false, S, Stride)) return false;
      VOp Op;
      Op.Kind = VOp::Load;
      Op.Stride = Stride;
      auto E = ExtOf.find(Ld);
      Type *LT = MT;
      if (E != ExtOf.end()) {
        LT = E->second.first->getType();
        if (!laneOK(LT)) return fail("extended load type");
        Op.Mn = (Twine(Stride ? "vldt." : "vld.") + memSuffix(MT, E->second.second) + "." + Twine(laneChar(LT)) + " ").str();
        int V = newV(nullptr, LT);
        for (User *U : Ld->users()) { VMap[U] = V; VLane[U] = LT; }
        Op.Dst = V;
      } else {
        if (MT->isIntegerTy() && Ld->hasNUses(0)) continue;
        Op.Mn = (Twine(Stride ? "vldt." : "vld.") + memSuffix(MT, false) + " ").str();
        Op.Dst = newV(Ld, LT);
      }
      Op.Stream = S;
      Prog.push_back(Op);
      noteUse(S);
      continue;
    }
    if (auto *St = dyn_cast<StoreInst>(&I)) {
      if (!St->isSimple()) return fail("a volatile or atomic store");
      Value *V = St->getValueOperand();
      Type *MT = V->getType();
      auto F = StoreForm.find(St);
      int Mode = 0;
      if (F != StoreForm.end()) { V = F->second.Src; MT = F->second.MemTy; Mode = F->second.Mode; }
      if (!laneOK(MT)) return fail("store type");
      int S;
      int64_t Stride;
      if (!memAccess(St, St->getPointerOperand(), MT, true, S, Stride)) return false;
      if (Stride && Mode) return fail("a strided saturating store");
      Opnd O;
      if (!operandOf(V, O, false)) return fail("a stored value that is not a vector or invariant scalar");
      if (O.Kind == Opnd::S) {  // a fill: splat the scalar
        Type *LT = V->getType();
        if (!laneOK(LT)) return fail("splat type");
        VOp M;
        M.Kind = VOp::Mov;
        M.Mn = (Twine("vmov.") + Twine(laneChar(LT)) + " ").str();
        M.Dst = newV(nullptr, LT);
        M.B = O;
        Prog.push_back(M);
        O = Opnd::v(M.Dst);
        VLane[V] = LT;
      }
      Type *LT = VLane.count(V) ? VLane[V] : V->getType();
      VOp Op;
      Op.Kind = VOp::Store;
      std::string M(1, laneChar(LT));
      const char *StB = Stride ? "vstt." : "vst.";
      if (Mode) Op.Mn = (Twine("vsts.") + M + "." + Twine(laneChar(MT)) + (Mode == 2 ? "u" : "") + " ").str();
      else if (LT != MT) Op.Mn = (Twine(StB) + M + "." + Twine(laneChar(MT)) + " ").str();
      else Op.Mn = (Twine(StB) + M + " ").str();
      Op.Stride = Stride;
      Op.A = O;
      Op.Stream = S;
      Prog.push_back(Op);
      noteUse(S);
      continue;
    }
    if (auto *Phi = dyn_cast<PHINode>(&I)) {
      // a reduction: its steps are found now and become Reduce operations where they appear in the body
      Instruction *N; Acc A;
      if (!matchReduction(Phi, N, A)) return false;
      continue;
    }
    // lane operations
    if (auto *Bin = dyn_cast<BinaryOperator>(&I)) {
      Type *T = Bin->getType();
      if (!laneOK(T)) return fail("lane type");
      auto MO = MulOf.find(Bin);
      if (MO != MulOf.end()) {
        Instruction *Mul = MO->second;
        Value *C0 = Bin->getOperand(0) == Mul ? Bin->getOperand(1) : Bin->getOperand(0);
        Value *A0 = Mul->getOperand(0), *B0 = Mul->getOperand(1);
        if (!VMap.count(A0)) std::swap(A0, B0);
        Opnd OA, OB, OC;
        if (!operandOf(A0, OA, false) || OA.Kind != Opnd::V || !operandOf(B0, OB, false) || !operandOf(C0, OC, false))
          return fail("a multiply-add with an operand that is not a vector");
        if (OC.Kind != Opnd::V) {  // the addend is a scalar: splat it into the accumulator register
          VOp M;
          M.Kind = VOp::Mov;
          M.Mn = (Twine("vmov.") + Twine(laneChar(T)) + " ").str();
          M.Dst = newV(nullptr, T);
          M.B = OC;
          Prog.push_back(M);
          OC = Opnd::v(M.Dst);
        }
        if (Bin->getOpcode() == Instruction::FSub && OB.Kind != Opnd::V) {  // vfnma has no scalar form: splat
          VOp M;
          M.Kind = VOp::Mov;
          M.Mn = (Twine("vmov.") + Twine(laneChar(T)) + " ").str();
          M.Dst = newV(nullptr, T);
          M.B = OB;
          Prog.push_back(M);
          OB = Opnd::v(M.Dst);
        }
        VOp Op;
        Op.Kind = VOp::Fma;
        Op.Mn = (Twine(Bin->getOpcode() == Instruction::FSub ? "vfnma." : "vfma.") + Twine(laneChar(T)) + " ").str();
        Op.A = OA; Op.B = OB;
        Op.Dst = newV(Bin, T);
        Op.Acc = OC.Id;
        Prog.push_back(Op);
        continue;
      }
      const char *Base = nullptr;
      bool Comm = false;
      switch (Bin->getOpcode()) {
      case Instruction::Add: case Instruction::FAdd: Base = "vadd"; Comm = true; break;
      case Instruction::Sub: case Instruction::FSub: Base = "vsub"; break;
      case Instruction::Mul: case Instruction::FMul: Base = "vmul"; Comm = true; break;
      case Instruction::And: Base = "vand"; Comm = true; break;
      case Instruction::Or: Base = "vor"; Comm = true; break;
      case Instruction::Xor: Base = "vxor"; Comm = true; break;
      case Instruction::Shl: Base = "vshl"; break;
      case Instruction::LShr: Base = "vshr"; break;
      case Instruction::AShr: Base = "vsar"; break;
      default: return fail("an operation without a vector form (" + Twine(Bin->getOpcodeName()) + ")");
      }
      Value *A0 = Bin->getOperand(0), *B0 = Bin->getOperand(1);
      Opnd OA, OB;
      bool AV = VMap.count(A0), BV = VMap.count(B0);
      if (!AV && !BV) return fail("an operation of two invariants in the loop");
      if (!AV) {
        if (Comm) { std::swap(A0, B0); }
        else if (Bin->getOpcode() == Instruction::Sub || Bin->getOpcode() == Instruction::FSub) {
          Base = "vsubr";  // vsubr vD, vA, X = X - vA
          std::swap(A0, B0);
        } else {  // a shift of a scalar by a vector: splat the scalar first
          Opnd SO;
          if (!invariantOperand(A0, SO, true)) return fail("operand");
          VOp M;
          M.Kind = VOp::Mov;
          M.Mn = (Twine("vmov.") + Twine(laneChar(T)) + " ").str();
          M.Dst = newV(nullptr, T);
          M.B = SO;
          Prog.push_back(M);
          OA = Opnd::v(M.Dst);
          A0 = nullptr;
        }
      }
      if (A0) if (!operandOf(A0, OA, false) || OA.Kind != Opnd::V) return fail(Twine("operand 0 of ") + Bin->getOpcodeName());
      if (!operandOf(B0, OB, !T->isFloatingPointTy())) return fail(Twine("operand 1 of ") + Bin->getOpcodeName());
      VOp Op;
      Op.Kind = VOp::Lane;
      Op.Mn = (Twine(Base) + "." + Twine(laneChar(T)) + " ").str();
      Op.A = OA; Op.B = OB;
      Op.Dst = newV(Bin, T);
      Prog.push_back(Op);
      continue;
    }
    if (auto *FN = dyn_cast<UnaryOperator>(&I)) {
      if (FN->getOpcode() != Instruction::FNeg) return fail("unary operation");
      auto It = VMap.find(FN->getOperand(0));
      if (It == VMap.end()) return fail("operand");
      VOp Op;
      Op.Kind = VOp::Lane;
      Op.Mn = (Twine("vneg.") + Twine(laneChar(FN->getType())) + " ").str();
      int SrcV = It->second;
      Op.A = Opnd::v(SrcV);
      Op.Dst = newV(FN, FN->getType());
      Op.B = Opnd::v(SrcV);
      Prog.push_back(Op);
      continue;
    }
    if (auto *II = dyn_cast<IntrinsicInst>(&I)) {
      Type *T = II->getType();
      switch (II->getIntrinsicID()) {
      case Intrinsic::smin: case Intrinsic::smax: case Intrinsic::umin: case Intrinsic::umax: {
        if (!laneOK(T) || T->isFloatingPointTy()) return fail("lane type");
        const char *Base = II->getIntrinsicID() == Intrinsic::smin ? "vmin" : II->getIntrinsicID() == Intrinsic::smax ? "vmax" : II->getIntrinsicID() == Intrinsic::umin ? "vminu" : "vmaxu";
        Value *A0 = II->getArgOperand(0), *B0 = II->getArgOperand(1);
        if (!VMap.count(A0)) std::swap(A0, B0);
        Opnd OA, OB;
        if (!operandOf(A0, OA, false) || OA.Kind != Opnd::V || !operandOf(B0, OB, true)) return fail("operand");
        VOp Op;
        Op.Kind = VOp::Lane;
        Op.Mn = (Twine(Base) + "." + Twine(laneChar(T)) + " ").str();
        Op.A = OA; Op.B = OB;
        Op.Dst = newV(II, T);
        Prog.push_back(Op);
        break;
      }
      case Intrinsic::sadd_sat: case Intrinsic::uadd_sat: case Intrinsic::ssub_sat: case Intrinsic::usub_sat: {
        if (!laneOK(T) || T->isFloatingPointTy()) return fail("lane type");
        Intrinsic::ID ID = II->getIntrinsicID();
        const char *Base = ID == Intrinsic::sadd_sat ? "vadds" : ID == Intrinsic::uadd_sat ? "vaddsu" : ID == Intrinsic::ssub_sat ? "vsubs" : "vsubsu";
        bool Comm = ID == Intrinsic::sadd_sat || ID == Intrinsic::uadd_sat;
        Value *A0 = II->getArgOperand(0), *B0 = II->getArgOperand(1);
        Opnd OA, OB;
        if (!VMap.count(A0)) {
          if (!Comm) {  // scalar - vector: splat the scalar
            Opnd SO;
            if (!invariantOperand(A0, SO, true)) return fail("operand");
            VOp M;
            M.Kind = VOp::Mov;
            M.Mn = (Twine("vmov.") + Twine(laneChar(T)) + " ").str();
            M.Dst = newV(nullptr, T);
            M.B = SO;
            Prog.push_back(M);
            OA = Opnd::v(M.Dst);
            A0 = nullptr;
          } else std::swap(A0, B0);
        }
        if (A0 && (!operandOf(A0, OA, false) || OA.Kind != Opnd::V)) return fail("operand");
        if (!operandOf(B0, OB, true)) return fail("operand");
        VOp Op;
        Op.Kind = VOp::Lane;
        Op.Mn = (Twine(Base) + "." + Twine(laneChar(T)) + " ").str();
        Op.A = OA; Op.B = OB;
        Op.Dst = newV(II, T);
        Prog.push_back(Op);
        break;
      }
      case Intrinsic::abs: {
        // abs(x - y): the absolute difference
        auto *Sub = dyn_cast<BinaryOperator>(II->getArgOperand(0));
        if (!Sub || Sub->getOpcode() != Instruction::Sub || !VMap.count(Sub->getOperand(0)) || !laneOK(T)) return fail("abs of something that is not a difference");
        Opnd OA, OB;
        if (!operandOf(Sub->getOperand(0), OA, false) || !operandOf(Sub->getOperand(1), OB, true)) return fail("operand");
        // the difference itself was emitted as a vsub; replace it by the vabd (the sub is dead if it has no other use)
        if (!Sub->hasOneUse()) return fail("abs of a difference that is used again");
        // remove the vsub emitted just before
        for (int k = Prog.size() - 1; k >= 0; --k)
          if (Prog[k].Kind == VOp::Lane && Prog[k].Dst == VMap[Sub]) { Prog.erase(Prog.begin() + k); break; }
        VOp Op;
        Op.Kind = VOp::Lane;
        Op.Mn = (Twine("vabd.") + Twine(laneChar(T)) + " ").str();
        Op.A = OA; Op.B = OB;
        Op.Dst = newV(II, T);
        Prog.push_back(Op);
        break;
      }
      case Intrinsic::fmuladd: case Intrinsic::fma: {
        if (!T->isFloatingPointTy() || !laneOK(T)) return fail("lane type");
        Value *A0 = II->getArgOperand(0), *B0 = II->getArgOperand(1), *C0 = II->getArgOperand(2);
        if (!VMap.count(A0)) std::swap(A0, B0);
        Opnd OA, OB, OC;
        if (!operandOf(A0, OA, false) || OA.Kind != Opnd::V || !operandOf(B0, OB, false) || !operandOf(C0, OC, false) || OC.Kind != Opnd::V)
          return fail("a multiply-add with an operand that is not a vector");
        VOp Op;
        Op.Kind = VOp::Fma;
        Op.Mn = (Twine("vfma.") + Twine(laneChar(T)) + " ").str();
        Op.A = OA; Op.B = OB;
        Op.Dst = newV(II, T);
        Op.Acc = OC.Id;  // the accumulator input: also the register written
        Prog.push_back(Op);
        break;
      }
      default:
        if (II->isAssumeLikeIntrinsic() || II->getIntrinsicID() == Intrinsic::lifetime_start || II->getIntrinsicID() == Intrinsic::lifetime_end) break;
        return fail("an intrinsic without a vector form");
      }
      continue;
    }
    if (auto *Sel = dyn_cast<SelectInst>(&I)) {
      return fail("a select");
    }
    if (isa<FCmpInst>(&I)) {
      // only as the condition of a reduction select (handled with the select)
      bool Ok = I.hasOneUse() && isa<SelectInst>(*I.user_begin());
      if (!Ok) return fail("a compare");
      continue;
    }
    if (isa<ZExtInst>(&I) || isa<SExtInst>(&I)) {
      // the operand of a reduction (vacc widens)
      bool Ok = I.hasOneUse() && isa<BinaryOperator>(*I.user_begin());
      if (isa<SExtInst>(&I) && Ok && VMap.count(I.getOperand(0))) continue;
      return fail("an extension of a computed value");
    }
    return fail("an instruction without a vector form (" + Twine(I.getOpcodeName()) + ")");
  }
  if (Prog.empty()) return fail("no vector operations");
  // phis that are not accumulators must be induction variables (checked in Scaf); every reduction phi must have been matched
  for (PHINode &P : H->phis()) {
    if (Scaf.count(&P)) continue;
    bool Found = false;
    for (Acc &A : Accs) if (A.Phi == &P) Found = true;
    if (!Found) return fail("a phi that is not an induction variable or a reduction");
  }
  // uses outside the loop: only reductions' results, through LCSSA phis
  for (Instruction &I : *H)
    for (User *U : I.users()) {
      auto *UI = dyn_cast<Instruction>(U);
      if (!UI || L->contains(UI)) continue;
      bool IsNext = false;
      for (Acc &A : Accs) if (A.Next == &I) IsNext = true;
      if (!IsNext || !isa<PHINode>(UI)) return fail("a value of the loop is used after it");
    }
  // a reduction's phi and update have no other users
  for (unsigned ai = 0; ai < Accs.size(); ++ai) {
    Acc &A = Accs[ai];
    for (User *U : A.Phi->users()) {
      auto *UI = dyn_cast<Instruction>(U);
      if (UI && RedStepOf.count(UI) && RedStepOf[UI].Acc == (int)ai) continue;
      if (auto *Sel = dyn_cast<SelectInst>(A.Next))
        if (U == Sel->getCondition()) continue;
      return fail("the accumulator is used in the loop");
    }
    for (User *U : A.Next->users()) if (U != A.Phi && !(isa<PHINode>(U) && !L->contains(cast<Instruction>(U)))) return fail("the accumulator is used in the loop");
  }
  // every mnemonic must be a word of the grammar
  for (VOp &Op : Prog) {
    std::string M = Op.Mn;
    while (!M.empty() && M.back() == ' ') M.pop_back();
    if (!grammarHas(M)) return fail("the grammar has no " + M);
  }
  return true;
}

// ---- the pass -----------------------------------------------------------------------------------------------
class PDP64VecLoop : public FunctionPass {
public:
  static char ID;
  PDP64VecLoop() : FunctionPass(ID) {}
  StringRef getPassName() const override { return "PDP64 loop to vec block"; }
  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.addRequired<LoopInfoWrapperPass>();
    AU.addRequired<ScalarEvolutionWrapperPass>();
    AU.addRequiredID(LoopSimplifyID);
    AU.addRequiredID(LCSSAID);
  }
  bool runOnFunction(Function &F) override;

private:
  bool transform(Loop *L, ScalarEvolution &SE, LoopInfo &LI, Function &F);
};
} // namespace

char PDP64VecLoop::ID = 0;
INITIALIZE_PASS_BEGIN(PDP64VecLoop, DEBUG_TYPE, "PDP64 loop to vec block", false, false)
INITIALIZE_PASS_DEPENDENCY(LoopInfoWrapperPass)
INITIALIZE_PASS_DEPENDENCY(ScalarEvolutionWrapperPass)
INITIALIZE_PASS_DEPENDENCY(LoopSimplify)
INITIALIZE_PASS_DEPENDENCY(LCSSAWrapperPass)
INITIALIZE_PASS_END(PDP64VecLoop, DEBUG_TYPE, "PDP64 loop to vec block", false, false)
FunctionPass *llvm::createPDP64VecLoop() { return new PDP64VecLoop(); }

bool PDP64VecLoop::runOnFunction(Function &F) {
  if (!EnableVecLoop || skipFunction(F))
    return false;
  LoopInfo &LI = getAnalysis<LoopInfoWrapperPass>().getLoopInfo();
  ScalarEvolution &SE = getAnalysis<ScalarEvolutionWrapperPass>().getSE();
  SmallVector<Loop *, 8> Inner;
  for (Loop *L : LI.getLoopsInPreorder())
    if (L->isInnermost())
      Inner.push_back(L);
  bool Changed = false;
  for (Loop *L : Inner)
    Changed |= transform(L, SE, LI, F);
  if (Changed)
    removeUnreachableBlocks(F);
  return Changed;
}

bool PDP64VecLoop::transform(Loop *L, ScalarEvolution &SE, LoopInfo &LI, Function &F) {
  const DataLayout &DL = F.getDataLayout();
  auto Say = [&](const Twine &W) {
    if (VecLoopVerbose)
      errs() << "pdp64-vecloop: " << F.getName() << ": loop at " << L->getHeader()->getName() << ": " << W << "\n";
  };
  if (L->getBlocks().size() != 1 || !L->getLoopPreheader() || !L->getExitBlock() || !L->getLoopLatch() || L->getLoopLatch() != L->getHeader()) {
    Say("not a single-block loop with a preheader and one exit");
    return false;
  }
  BasicBlock *H = L->getHeader(), *P = L->getLoopPreheader(), *Exit = L->getExitBlock();
  if (!isa<BranchInst>(P->getTerminator()) || cast<BranchInst>(P->getTerminator())->isConditional()) {
    Say("the preheader does not end in a plain branch");
    return false;
  }
  const SCEV *BTC = SE.getBackedgeTakenCount(L);
  if (isa<SCEVCouldNotCompute>(BTC)) {
    Say("the trip count is not computable");
    return false;
  }
  Analyzer A(L, SE, DL);
  if (!A.run()) {
    Say("not a vec block: " + A.Why);
    return false;
  }
  // the exit block's phis: what each incoming value from the loop becomes
  for (PHINode &Ph : Exit->phis()) {
    Value *V = Ph.getIncomingValueForBlock(H);
    if (auto *I = dyn_cast<Instruction>(V))
      if (L->contains(I)) {
        bool Ok = false;
        for (Acc &Ac : A.Accs) if (Ac.Next == I) Ok = true;
        if (!Ok) { Say("an exit phi of a value that is not a reduction result"); return false; }
      }
  }

  // ---- the order of the first stream: the first memory operation whose pointer moves is the one whose element size gives the region
  // (the executor takes the first instruction of the body with (Rs)+ on Rs); the program order of the VOps is the body order
  int First = -1;
  for (unsigned i = 0; i < A.Streams.size(); ++i)
    if (First < 0 || A.Streams[i].LastUse < A.Streams[First].LastUse) First = i;
  // the first stream is the stream whose (Ra)+ comes first in the body
  // aliasing
  // the invariant loads of one base (m[0], m[1] ...) are one range
  {
    SmallVector<Analyzer::MemAcc, 8> Merged;
    struct G { const SCEV *Base; int64_t Lo, Hi; Value *Ptr; };
    SmallVector<G, 4> Gs;
    for (auto &M : A.Mem) {
      if (!M.Inv) { Merged.push_back(M); continue; }
      const SCEV *Base = M.P;
      int64_t Off = 0;
      if (auto *Add = dyn_cast<SCEVAddExpr>(M.P))
        if (Add->getNumOperands() == 2)
          if (auto *C = dyn_cast<SCEVConstant>(Add->getOperand(0))) { Off = C->getAPInt().getSExtValue(); Base = Add->getOperand(1); }
      bool Found = false;
      for (G &Gr : Gs)
        if (Gr.Base == Base) { Gr.Lo = std::min(Gr.Lo, Off); Gr.Hi = std::max(Gr.Hi, Off + M.Size); Found = true; }
      if (!Found) Gs.push_back({Base, Off, Off + M.Size, M.Ptr});
    }
    for (G &Gr : Gs)
      Merged.push_back({SE.getAddExpr(Gr.Base, SE.getConstant(Gr.Base->getType(), Gr.Lo)), Gr.Hi - Gr.Lo, false, 0, Gr.Ptr, true});
    A.Mem = Merged;
  }
  struct Pair { const SCEV *S0; int64_t Sz0; bool I0; const SCEV *S1; int64_t Sz1; bool I1; };
  SmallVector<Pair, 8> Checks;
  for (unsigned i = 0; i < A.Mem.size(); ++i)
    for (unsigned j = i + 1; j < A.Mem.size(); ++j) {
      auto &X = A.Mem[i], &Y = A.Mem[j];
      if (!X.Store && !Y.Store) continue;
      if (X.P == Y.P && !X.Inv && !Y.Inv) {
        // the same element in each iteration: a load after the store in the body would read the old value in a strip
        auto &Ld = X.Store ? Y : X; auto &St = X.Store ? X : Y;
        if (!Ld.Store && Ld.Pos > St.Pos) { Say("not a vec block: a load after a store of the same element"); return false; }
        continue;
      }
      if (!X.Inv && !Y.Inv) {
        // the same step and a constant distance: the accesses are fields of one structure (or arrays at a fixed offset); inside each period of the step
        // their bytes are disjoint or they are not (then the loop carries a dependence through memory and stays scalar)
        auto *AX = cast<SCEVAddRecExpr>(X.P), *AY = cast<SCEVAddRecExpr>(Y.P);
        auto *Dc = dyn_cast<SCEVConstant>(SE.getMinusSCEV(AX->getStart(), AY->getStart()));
        if (Dc && AX->getStepRecurrence(SE) == AY->getStepRecurrence(SE)) {
          int64_t Step = X.Size, D = Dc->getAPInt().getSExtValue();   // Mem.Size of a non-invariant access is its step
          int64_t R = ((D % Step) + Step) % Step;
          // the bytes of the elements: X occupies [0, EX), Y occupies [R, R + EY) within a period (R + EY <= Step: no wrap)
          if (R >= X.ElSize && R + Y.ElSize <= Step) continue;
          Say("not a vec block: two accesses overlap with a constant distance (a dependence between iterations)");
          return false;
        }
      }
      Value *OX = getUnderlyingObject(X.Ptr), *OY = getUnderlyingObject(Y.Ptr);
      if (OX != OY && isIdentifiedObject(OX) && isIdentifiedObject(OY)) continue;
      bool Dup = false;
      for (Pair &C : Checks) if ((C.S0 == X.P && C.S1 == Y.P) || (C.S0 == Y.P && C.S1 == X.P)) Dup = true;
      if (!Dup) Checks.push_back({X.P, X.Size, X.Inv, Y.P, Y.Size, Y.Inv});
    }
  if (Checks.size() > VecLoopMaxChecks) { Say("not a vec block: too many overlap tests"); return false; }

  // ---- the vector registers: a linear scan over the body
  int NV = A.NextV;
  SmallVector<int, 32> LastUse(NV, -1);
  SmallVector<int, 32> Def(NV, -1);
  for (unsigned i = 0; i < A.Prog.size(); ++i) {
    VOp &Op = A.Prog[i];
    if (Op.Dst >= 0) Def[Op.Dst] = i;
    if (Op.A.Kind == Opnd::V) LastUse[Op.A.Id] = i;
    if (Op.B.Kind == Opnd::V) LastUse[Op.B.Id] = i;
    if (Op.Kind == VOp::Fma) LastUse[Op.Acc] = i;
  }
  SmallVector<int, 32> Reg(NV, -1);
  bool Free[16];
  for (bool &F0 : Free) F0 = true;
  SmallVector<std::string, 32> Lines;
  auto Alloc = [&]() -> int { for (int r = 0; r < 16; ++r) if (Free[r]) { Free[r] = false; return r; } return -1; };
  auto ReleaseDead = [&](int Pos, int V) { if (V >= 0 && LastUse[V] == Pos && Reg[V] >= 0) Free[Reg[V]] = true; };
  auto Rn = [&](int V) { return ("v" + Twine(Reg[V])).str(); };
  int NS = A.Scalars.size(), NAcc = A.Accs.size(), NStr = A.Streams.size();
  int K = NStr + NAcc;                     // outputs: the stream pointers, then the accumulators
  // operand numbers in the template: outputs 0..K-1, then the end of the first stream (K), then the scalars
  auto PtrOp = [&](int S) { return ("$" + Twine(S)).str(); };
  auto AccOp = [&](int a) { return ("$" + Twine(NStr + a)).str(); };
  auto ScalOp = [&](int s) { return ("$" + Twine(K + 1 + s)).str(); };
  auto Src = [&](Opnd &O) -> std::string {
    if (O.Kind == Opnd::V) return Rn(O.Id);
    if (O.Kind == Opnd::S) return ScalOp(O.Id);
    return ("#" + Twine(O.Imm)).str();
  };
  for (unsigned i = 0; i < A.Prog.size(); ++i) {
    VOp &Op = A.Prog[i];
    std::string T;
    switch (Op.Kind) {
    case VOp::Load: {
      int D = Alloc();
      if (D < 0) { Say("not a vec block: more than 16 vector registers"); return false; }
      Reg[Op.Dst] = D;
      Stream &S = A.Streams[Op.Stream];
      T = Op.Mn + Rn(Op.Dst) + ", " + (S.LastUse == (int)i ? "(" + PtrOp(Op.Stream) + ")+" : "0(" + PtrOp(Op.Stream) + ")") + (Op.Stride ? ", #" + std::to_string(Op.Stride) : "");
      break;
    }
    case VOp::Store: {
      Stream &S = A.Streams[Op.Stream];
      T = Op.Mn + Rn(Op.A.Id) + ", " + (S.LastUse == (int)i ? "(" + PtrOp(Op.Stream) + ")+" : "0(" + PtrOp(Op.Stream) + ")") + (Op.Stride ? ", #" + std::to_string(Op.Stride) : "");
      ReleaseDead(i, Op.A.Id);
      break;
    }
    case VOp::Mov: {
      int D = Alloc();
      if (D < 0) { Say("not a vec block: more than 16 vector registers"); return false; }
      Reg[Op.Dst] = D;
      T = Op.Mn + Rn(Op.Dst) + ", " + Src(Op.B);
      break;
    }
    case VOp::Lane: {
      // a destination can be one of the sources that dies here
      std::string Sa = Src(Op.A), Sb = Op.B.Kind != Opnd::None ? Src(Op.B) : "";
      ReleaseDead(i, Op.A.Kind == Opnd::V ? Op.A.Id : -1);
      if (Op.B.Kind == Opnd::V && Op.B.Id != Op.A.Id) ReleaseDead(i, Op.B.Id);
      int D = Alloc();
      if (D < 0) { Say("not a vec block: more than 16 vector registers"); return false; }
      Reg[Op.Dst] = D;
      bool Unary = Op.Mn.rfind("vneg", 0) == 0;
      T = Op.Mn + Rn(Op.Dst) + ", " + Sa + (Unary ? "" : ", " + Sb);
      break;
    }
    case VOp::Fma: {
      // vfma vD, vA, vB|rS: vD += vA * x, and vD is the accumulator: it is the register of Op.Acc (a copy first if that value lives on)
      std::string Sa = Src(Op.A), Sb = Src(Op.B);
      int C = Op.Acc;
      bool Dies = LastUse[C] == (int)i && !(Op.A.Kind == Opnd::V && Op.A.Id == C) && !(Op.B.Kind == Opnd::V && Op.B.Id == C);
      if (Dies) {
        Reg[Op.Dst] = Reg[C];
      } else {
        int D = Alloc();
        if (D < 0) { Say("not a vec block: more than 16 vector registers"); return false; }
        Reg[Op.Dst] = D;
        std::string Lane = Op.Mn.substr(Op.Mn.find('.') + 1);
        Lines.push_back("vmov." + Lane + Rn(Op.Dst) + ", " + Rn(C));
      }
      if (Op.A.Kind == Opnd::V && Op.A.Id != C) ReleaseDead(i, Op.A.Id);
      if (Op.B.Kind == Opnd::V && Op.B.Id != C && Op.B.Id != Op.A.Id) ReleaseDead(i, Op.B.Id);
      T = Op.Mn + Rn(Op.Dst) + ", " + Sa + ", " + Sb;
      break;
    }
    case VOp::Reduce: {
      T = Op.Mn + AccOp(Op.Acc) + ", " + Rn(Op.A.Id);
      ReleaseDead(i, Op.A.Id);
      break;
    }
    }
    Lines.push_back(T);
  }
  // the first stream: the one whose (Ra)+ is first in the body (the executor takes the element size of the first such instruction)
  std::string Asm;
  {
    int FS = First;
    // the region's element size: that of the instruction that holds the (Ra)+ of the first stream
    Asm = "vec " + PtrOp(FS) + ", $" + Twine(K).str() + "\n";
    for (std::string &Ln : Lines) Asm += "\t" + Ln + "\n";
    Asm += "\tvend";
    // a float accumulator comes back as the low 32 bits: nothing to add (the result is truncated in IR)
  }
  // ---- the IR: the test, the block, the join
  IRBuilder<> B(P->getTerminator());
  SCEVExpander Exp(SE, DL, "vecloop");
  Type *I64 = Type::getInt64Ty(F.getContext());
  Instruction *IP = P->getTerminator();
  const SCEV *Trip = SE.getAddExpr(SE.getTruncateOrZeroExtend(BTC, I64), SE.getOne(I64));
  if (!Exp.isSafeToExpandAt(Trip, IP)) { Say("cannot expand the trip count"); return false; }
  Value *TripV = Exp.expandCodeFor(Trip, I64, IP);
  SmallVector<Value *, 8> Start(NStr), StartI(NStr);
  for (int s = 0; s < NStr; ++s) {
    if (!Exp.isSafeToExpandAt(A.Streams[s].Start, IP)) { Say("cannot expand a stream's start"); return false; }
    Value *V = Exp.expandCodeFor(A.Streams[s].Start, nullptr, IP);
    Start[s] = V;
    StartI[s] = V->getType()->isPointerTy() ? B.CreatePtrToInt(V, I64) : B.CreateZExtOrTrunc(V, I64);
  }
  Value *Ok = nullptr;
  if (!Checks.empty()) {
    auto Range = [&](const SCEV *S, int64_t Sz, bool Inv, Value *&Lo, Value *&Hi) {
      Value *V = Exp.expandCodeFor(Inv ? S : cast<SCEVAddRecExpr>(S)->getStart(), nullptr, IP);
      Lo = V->getType()->isPointerTy() ? B.CreatePtrToInt(V, I64) : V;
      Hi = Inv ? B.CreateAdd(Lo, ConstantInt::get(I64, Sz)) : B.CreateAdd(Lo, B.CreateMul(TripV, ConstantInt::get(I64, Sz)));
    };
    for (Pair &C : Checks) {
      Value *L0, *H0, *L1, *H1;
      Range(C.S0, C.Sz0, C.I0, L0, H0);
      Range(C.S1, C.Sz1, C.I1, L1, H1);
      Value *Disjoint = B.CreateOr(B.CreateICmpULE(H0, L1), B.CreateICmpULE(H1, L0));
      Ok = Ok ? B.CreateAnd(Ok, Disjoint) : Disjoint;
    }
  }
  // the end of the first stream
  Value *EndV = B.CreateAdd(StartI[First], B.CreateMul(TripV, ConstantInt::get(I64, A.Streams[First].Step)));
  // inputs of the asm: the end, the scalars; then the tied inputs (the stream pointers, the accumulators), in the order of the outputs.
  // A pointer or a floating-point value is an "r" operand as it is (a binary32 is the low 32 bits of a register: what the lanes read).
  SmallVector<Value *, 16> Args;
  SmallVector<Type *, 16> ArgTys, OutTys;
  std::string Cons;
  for (int k = 0; k < K; ++k) Cons += "=&r,";
  SmallVector<Value *, 8> ScalArgs, AccInit;
  auto AddIn = [&](Value *V) { Args.push_back(V); ArgTys.push_back(V->getType()); Cons += "r,"; };
  AddIn(EndV);
  // the invariants made once in the preheader (an address that does not change is loaded here, after the test that no store of the loop reaches it:
  // the load is in the preheader, so it also runs when the test fails and the scalar loop is taken, where the same load runs in its first iteration anyway)
  DenseMap<Value *, Value *> HMap;
  for (Instruction *HI : A.Hoist) {
    Instruction *NI;
    if (auto *Ld = dyn_cast<LoadInst>(HI)) {
      Value *Ptr = Exp.expandCodeFor(SE.getSCEV(Ld->getPointerOperand()), nullptr, IP);
      auto *NL = new LoadInst(Ld->getType(), Ptr, "", false, Ld->getAlign(), IP->getIterator());
      NI = NL;
    } else {
      NI = HI->clone();
      for (unsigned i = 0; i < NI->getNumOperands(); ++i) {
        auto It = HMap.find(NI->getOperand(i));
        if (It != HMap.end()) NI->setOperand(i, It->second);
      }
      NI->insertBefore(IP->getIterator());
    }
    HMap[HI] = NI;
  }
  for (int s = 0; s < NS; ++s) {
    Value *V = A.Scalars[s];
    { auto It = HMap.find(V); if (It != HMap.end()) V = It->second; }
    if (!V->getType()->isFloatingPointTy()) V = B.CreateSExtOrTrunc(V, I64);
    AddIn(V);
    ScalArgs.push_back(V);
  }
  for (int s = 0; s < NStr; ++s) {
    Value *V = Start[s];
    if (!V->getType()->isPointerTy()) V = B.CreateIntToPtr(V, PointerType::getUnqual(F.getContext()));
    Args.push_back(V); ArgTys.push_back(V->getType()); OutTys.push_back(V->getType());
    Cons += std::to_string(s) + ",";
  }
  for (int a = 0; a < NAcc; ++a) {
    Acc &Ac = A.Accs[a];
    Value *Init = Ac.Phi->getIncomingValueForBlock(P);
    Value *V = Ac.IsFP ? Init : B.CreateSExtOrTrunc(Init, I64);
    AccInit.push_back(V);
    Args.push_back(V); ArgTys.push_back(V->getType()); OutTys.push_back(V->getType());
    Cons += std::to_string(NStr + a) + ",";
  }
  Cons += "~{memory}";
  Type *RetTy = K == 1 ? OutTys[0] : (Type *)StructType::get(F.getContext(), OutTys);
  FunctionType *FT = FunctionType::get(RetTy, ArgTys, false);
  InlineAsm *IA = InlineAsm::get(FT, Asm, Cons, /*hasSideEffects=*/true);

  // one call of the block: End and the pointers and accumulators in, the new pointers and accumulators out
  auto CallBlock = [&](IRBuilder<> &IB, Value *End, ArrayRef<Value *> Ptrs, ArrayRef<Value *> AccV, SmallVectorImpl<Value *> &Outs) {
    SmallVector<Value *, 16> Av;
    Av.push_back(End);
    for (Value *V : ScalArgs) Av.push_back(V);
    for (Value *V : Ptrs) Av.push_back(V);
    for (Value *V : AccV) Av.push_back(V);
    Value *R = IB.CreateCall(IA, Av);
    for (int k = 0; k < K; ++k) Outs.push_back(K == 1 ? R : IB.CreateExtractValue(R, k));
  };
  SmallVector<Value *, 4> PtrIn(Start.begin(), Start.end());
  for (Value *&V : PtrIn) if (!V->getType()->isPointerTy()) V = B.CreateIntToPtr(V, PointerType::getUnqual(F.getContext()));
  // the entry block of the vector path, and the block that leaves it
  BasicBlock *VB = BasicBlock::Create(F.getContext(), "vecblock", &F, H);
  BasicBlock *VJoin = VB;
  SmallVector<Value *, 4> AccRes;
  auto Narrow = [&](IRBuilder<> &IB, ArrayRef<Value *> Outs) {
    for (int a = 0; a < NAcc; ++a) {
      Value *R = Outs[NStr + a];
      if (!A.Accs[a].IsFP) R = IB.CreateTrunc(R, A.Accs[a].Ty);
      AccRes.push_back(R);
    }
  };
  if (!VecLoopStrip) {
    IRBuilder<> VBB(VB);
    SmallVector<Value *, 8> Outs;
    CallBlock(VBB, EndV, PtrIn, AccInit, Outs);
    Narrow(VBB, Outs);
    VBB.CreateBr(Exit);
  } else {
    // approach (a): the strip of VL elements is one block; the loop around it is scalar (a counter, the end of the strip); a last block does the remainder
    unsigned MaxLane = 1;
    for (VOp &Op : A.Prog) {
      StringRef M = Op.Mn;
      M = M.trim();
      SmallVector<StringRef, 3> Tk;
      M.split(Tk, '.');
      StringRef LaneTok = Tk.size() > 1 ? Tk[1] : StringRef();
      if (Op.Kind == VOp::Load && Tk.size() > 2) LaneTok = Tk[2];   // vld.bu.l: the lane is the last
      if (Op.Kind == VOp::Load && Tk.size() == 2) LaneTok = Tk[1].substr(0, 1);   // vld.f / vld.l: memory type = lane type
      if (LaneTok.empty()) continue;
      unsigned Sz = 1;
      switch (LaneTok[0]) { case 'w': Sz = 2; break; case 'l': case 'f': Sz = 4; break; case 'q': case 'd': Sz = 8; break; default: Sz = 1; }
      MaxLane = std::max(MaxLane, Sz);
    }
    unsigned VL = 32 / MaxLane;
    unsigned Sh = Log2_32(VL);
    Function::iterator Pos = H->getIterator();
    BasicBlock *VLoop = BasicBlock::Create(F.getContext(), "vecstrip", &F, H);
    BasicBlock *VTail = BasicBlock::Create(F.getContext(), "vecstrip.tail", &F, H);
    BasicBlock *VRem = BasicBlock::Create(F.getContext(), "vecstrip.rem", &F, H);
    VJoin = BasicBlock::Create(F.getContext(), "vecstrip.join", &F, H);
    IRBuilder<> IB(VB);
    Value *NFull = IB.CreateLShr(TripV, Sh);
    Value *RemN = IB.CreateAnd(TripV, VL - 1);
    IB.CreateCondBr(IB.CreateICmpNE(NFull, ConstantInt::get(I64, 0)), VLoop, VTail);
    IRBuilder<> LB(VLoop);
    SmallVector<PHINode *, 4> PP, AP;
    SmallVector<Value *, 4> PV, AV;
    for (int s = 0; s < NStr; ++s) { PP.push_back(LB.CreatePHI(PtrIn[s]->getType(), 2)); PV.push_back(PP.back()); }
    for (int a = 0; a < NAcc; ++a) { AP.push_back(LB.CreatePHI(AccInit[a]->getType(), 2)); AV.push_back(AP.back()); }
    PHINode *Cnt = LB.CreatePHI(I64, 2);
    Value *P0 = LB.CreatePtrToInt(PV[First], I64);
    Value *EndS = LB.CreateAdd(P0, ConstantInt::get(I64, (uint64_t)VL * A.Streams[First].Step));
    SmallVector<Value *, 8> Outs;
    CallBlock(LB, EndS, PV, AV, Outs);
    Value *Cnt1 = LB.CreateSub(Cnt, ConstantInt::get(I64, 1));
    LB.CreateCondBr(LB.CreateICmpNE(Cnt1, ConstantInt::get(I64, 0)), VLoop, VTail);
    for (int s = 0; s < NStr; ++s) { PP[s]->addIncoming(PtrIn[s], VB); PP[s]->addIncoming(Outs[s], VLoop); }
    for (int a = 0; a < NAcc; ++a) { AP[a]->addIncoming(AccInit[a], VB); AP[a]->addIncoming(Outs[NStr + a], VLoop); }
    Cnt->addIncoming(NFull, VB); Cnt->addIncoming(Cnt1, VLoop);
    IRBuilder<> TB(VTail);
    SmallVector<PHINode *, 4> TP, TA;
    SmallVector<Value *, 4> TPV, TAV;
    for (int s = 0; s < NStr; ++s) { TP.push_back(TB.CreatePHI(PtrIn[s]->getType(), 2)); TP[s]->addIncoming(PtrIn[s], VB); TP[s]->addIncoming(Outs[s], VLoop); TPV.push_back(TP[s]); }
    for (int a = 0; a < NAcc; ++a) { TA.push_back(TB.CreatePHI(AccInit[a]->getType(), 2)); TA[a]->addIncoming(AccInit[a], VB); TA[a]->addIncoming(Outs[NStr + a], VLoop); TAV.push_back(TA[a]); }
    Value *TP0 = TB.CreatePtrToInt(TPV[First], I64);
    Value *EndT = TB.CreateAdd(TP0, TB.CreateMul(RemN, ConstantInt::get(I64, A.Streams[First].Step)));
    TB.CreateCondBr(TB.CreateICmpNE(RemN, ConstantInt::get(I64, 0)), VRem, VJoin);
    IRBuilder<> RB(VRem);
    SmallVector<Value *, 8> Outs2;
    // EndT is computed in VTail (it dominates VRem)
    CallBlock(RB, EndT, TPV, TAV, Outs2);
    RB.CreateBr(VJoin);
    IRBuilder<> JB(VJoin);
    SmallVector<Value *, 8> Fin;
    for (int a = 0; a < NAcc; ++a) {
      PHINode *J = JB.CreatePHI(AccInit[a]->getType(), 2);
      J->addIncoming(TAV[a], VTail); J->addIncoming(Outs2[NStr + a], VRem);
      Fin.push_back(J);
    }
    SmallVector<Value *, 8> FinFull(NStr, nullptr);
    for (int a = 0; a < NAcc; ++a) FinFull.push_back(Fin[a]);
    Narrow(JB, FinFull);
    JB.CreateBr(Exit);
    (void)Pos;
  }
  // the exit block's phis get the result of the block
  for (PHINode &Ph : Exit->phis()) {
    Value *V = Ph.getIncomingValueForBlock(H);
    Value *N = V;
    if (auto *I = dyn_cast<Instruction>(V))
      for (int a = 0; a < NAcc; ++a)
        if (A.Accs[a].Next == I) N = AccRes[a];
    Ph.addIncoming(N, VJoin);
  }
  // the test: the block if the streams do not overlap (always, if no test is needed), else the scalar loop
  B.SetInsertPoint(P->getTerminator());
  if (Ok) {
    B.CreateCondBr(Ok, VB, H);
    ++NumVersioned;
  } else {
    B.CreateBr(VB);  // the scalar loop is unreachable now: removeUnreachableBlocks takes it (and its edge to the exit phis) away
  }
  P->getTerminator()->eraseFromParent();
  ++NumBlocks;
  Say(Twine("vec block: ") + Twine((unsigned)A.Prog.size()) + " vector instructions, " + Twine(NStr) + " streams, " + Twine(NAcc) + " reductions" +
      (Ok ? ", with a run-time overlap test" : ""));
  SE.forgetLoop(L);
  if (Loop *Par = L->getParentLoop())
    Par->addBasicBlockToLoop(VB, LI);
  return true;
}
