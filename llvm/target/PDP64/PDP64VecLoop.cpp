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
#include <functional>
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/ADT/StringSet.h"
#include "llvm/Analysis/AliasAnalysis.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/Analysis/ScalarEvolutionExpressions.h"
#include "llvm/Analysis/ValueTracking.h"
#include "llvm/Analysis/VectorUtils.h"
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
static cl::opt<bool> EnableVecBlock("pdp64-vecblock",
    cl::desc("pdp64: lower the vector loops that LoopVectorize made (fixed-width <N x iM> bodies) to one vec block over the whole range"),
    cl::init(true));
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
  enum K { Load, Store, Lane, Mov, Fma, Reduce, LoadSeg, StoreSeg, Bsl } Kind;
  std::string Mn;     // mnemonic up to and including the dots (vadd.l, vld.bu.l, vst.l.b, vacc.l ...)
  int Dst = -1;       // virtual vector register written (Load, Lane, Mov, Fma)
  Opnd A, B;          // sources: A is a virtual register (Lane, Fma, Store, Reduce), B any operand (Reduce: a second register for vdacc / vsad)
  Opnd C;             // Bsl: the mask (vbsl vD, C, A, B: where the mask is 1 the bit comes from A)
  int Sh = -1;        // Store: the rounding shift of vsts (#sh), -1 none
  int Stream = -1;    // memory operations
  int Acc = -1;       // Reduce: index in Accs
  int64_t Stride = 0; // strided memory operations (vldt, vstt): the bytes between elements
  SmallVector<int, 4> Regs;   // LoadSeg: the virtual registers of the fields (made consecutive); StoreSeg: those stored
  char LaneC = 0;     // StoreSeg: the lane type character (for the copies into consecutive registers)
};
struct Stream {
  const SCEV *Start;
  int64_t Step;       // bytes between the elements: the access size
  Value *StartVal = nullptr;
  int LastUse = -1;   // index of the VOp that moves the pointer ((Ra)+)
  int FirstUse = -1;
};
static ConstantInt *constInt(Value *V) {   // a constant integer, or a splat of one
  if (auto *C = dyn_cast<ConstantInt>(V)) return C;
  if (V->getType()->isVectorTy())
    if (auto *C = dyn_cast<Constant>(V)) return dyn_cast_or_null<ConstantInt>(C->getSplatValue());
  return nullptr;
}

struct Acc {
  bool Uns = false;   // an unsigned maximum / minimum (vmaxacc.bu ...)
  PHINode *Phi;
  Instruction *Next;
  Type *Ty;
  const char *Base;   // vacc, vmaxacc, vminacc
  char Lane;
  bool IsFP;
};

static char laneChar(Type *T) {
  T = T->getScalarType();   // a vector value is held lane by lane: its lane type
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
  bool Vec = false;      // the loop is one that LoopVectorize made: <N x iM> values, N lanes in each iteration
  unsigned Lanes = 1;    // N
  struct MemAcc { const SCEV *P; int64_t Size; bool Store; int Pos; Value *Ptr; bool Inv; int64_t ElSize = 0; int64_t ElemStep = 0; };
  SmallVector<Instruction *, 16> Hoist;   // loop-invariant instructions (loads of invariant addresses, pure operations of invariants), in order: made in the preheader
  SmallPtrSet<Value *, 16> InvSet;
  DenseMap<Value *, Value *> SplatInfo;   // a vector made in the loop by insertelement(+shufflevector) of one loop-invariant scalar -> that scalar
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
  int streamIdx(const SCEVAddRecExpr *AR, int64_t Step) {   // Step: the bytes between elements
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
    if (V->getType()->isVectorTy()) {   // a splat of a loop-invariant scalar is the scalar operand of the lane operation
      auto SI = SplatInfo.find(V);
      Value *S = nullptr;
      if (SI != SplatInfo.end()) S = SI->second;
      else if (!inLoop(V)) S = getSplatValue(V);
      if (!S) return false;
      V = S;
    }
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
    return invariantOperand(V, O, AllowImm && V->getType()->getScalarType()->isIntegerTy());
  }
  int newV(Value *IR, Type *Lane) {
    int Id = NextV++;
    if (IR) { VMap[IR] = Id; VLane[IR] = Lane; }
    return Id;
  }

  // a consecutive access (step = size), or a strided one (step a multiple of the size, at most 1000 bytes: vldt / vstt)
  bool memAccess(Instruction *I, Value *Ptr, Type *Ty, bool Store, int &S, int64_t &Stride, unsigned Recs = 0) {
    unsigned N = 1;
    if (auto *VT = dyn_cast<FixedVectorType>(Ty)) {
      N = Recs ? Recs : VT->getNumElements();   // Recs: the records of an interleaved group (the wide vector has Recs * fields lanes)
      if (!Vec) return fail("a vector access in a scalar loop");
      if (Lanes != 1 && Lanes != N) return fail("vector accesses of different lane counts");
      Lanes = N;
    } else if (Vec)
      return fail("a scalar access in a vector loop");
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
    if (N > 1 && St != Sz) return fail("a strided vector access");
    if (St % N) return fail("a step that is not a multiple of the lane count");
    S = streamIdx(AR, St / N);
    Stride = (N > 1 || St == Sz) ? 0 : St;
    Mem.push_back({P, St, Store, (int)Prog.size(), Ptr, false, Sz, St / N});
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

  // ---- wave 1 and 2 words: the idioms that select them (found before the body is emitted)
  struct Pat {                       // avg, the high half of a widening multiply, a rounding shift: one lane operation on the NARROW lanes
    enum K { Avg, Mulh, MulhR, SRound } Kind;
    Value *A = nullptr, *B = nullptr;   // the ext instructions (or the value) whose operand is the lane
    bool BImm = false; int64_t Imm = 0; // B is a constant: an immediate
    bool Uns = false;
    int Sh = 0;
    Type *Narrow = nullptr;             // the lane type of the result register
  };
  struct DotSt { Instruction *E0, *E1; const char *Mn; };   // a widening product feeding a reduction: vdacc.*
  struct SadSt { Instruction *E0, *E1; };                  // abs(zext a - zext b) feeding a reduction: vsad.bu
  DenseMap<Instruction *, Pat> Pats;                       // the root instruction -> its idiom
  DenseMap<Instruction *, DotSt> DotOf;                    // the reduction step -> its dot product
  DenseMap<Instruction *, SadSt> SadOf;
  SmallPtrSet<Instruction *, 16> PatExt;                   // extensions that an idiom reads through (their operand is the lane)
  DenseMap<Value *, bool> MaskInv;                         // the mask register of a compare holds its negation (the arms of a select are swapped instead)
  DenseMap<LoadInst *, bool> LazyLoad;                     // a load only converted to float (sitofp / uitofp of bytes or halfwords): the wide load is made at the conversion
  LLVMContext &ctx() { return L->getHeader()->getContext(); }

  bool run();
  bool matchReduction(PHINode *Phi, Instruction *&Next, Acc &A);
  bool emitReduce(Instruction *I);
  bool plainLoad(LoadInst *Ld, Type *LaneTy, bool Zext, bool SetMap = true, int *RegOut = nullptr);   // a load into a register, extended to the lane type if it is wider
  bool asVector(Value *V, Opnd &O, Type *LaneTy, bool AllowImm = true);   // a vector register: a scalar or constant operand is splatted by vmov
  bool narrowOperand(Value *V, Opnd &O, Type *Want = nullptr);                    // the operand of an extension that an idiom reads through, as a vector register of the narrow lanes
  int emitLane(StringRef Base, char C, Opnd A, Opnd B, Type *ResTy, Value *IR = nullptr);
  bool emitPat(Instruction *Root, Pat &P);
  bool emitCmp(CmpInst *Cmp);
  bool emitSelect(SelectInst *Sel);
  bool emitConv(CastInst *C);
  bool maskOperand(Value *Cond, bool WantInv, Opnd &O);
};

int Analyzer::emitLane(StringRef Base, char C, Opnd A, Opnd B, Type *ResTy, Value *IR) {
  VOp Op;
  Op.Kind = VOp::Lane;
  Op.Mn = (Twine(Base) + "." + Twine(C) + " ").str();
  Op.A = A; Op.B = B;
  Op.Dst = newV(IR, ResTy);
  Prog.push_back(Op);
  return Op.Dst;
}

bool Analyzer::asVector(Value *V, Opnd &O, Type *LaneTy, bool AllowImm) {
  if (!operandOf(V, O, AllowImm)) return fail("an operand that is neither a vector nor an invariant scalar");
  if (O.Kind == Opnd::V) return true;
  char C = laneChar(LaneTy);
  if (!C) return fail("splat type");
  VOp M;
  M.Kind = VOp::Mov;
  M.Mn = (Twine("vmov.") + Twine(C) + " ").str();
  M.Dst = newV(nullptr, LaneTy);
  M.B = O;
  Prog.push_back(M);
  O = Opnd::v(M.Dst);
  return true;
}

// a load that is not extended (or is, by the lane type): the stream, the memory access, the operation
bool Analyzer::plainLoad(LoadInst *Ld, Type *LaneTy, bool Zext, bool SetMap, int *RegOut) {
  if (!Ld->isSimple()) return fail("a volatile or atomic load");
  Type *MT = Ld->getType();
  if (!laneOK(MT)) return fail("load type");
  int S;
  int64_t Stride;
  if (!memAccess(Ld, Ld->getPointerOperand(), MT, false, S, Stride)) return false;
  VOp Op;
  Op.Kind = VOp::Load;
  Op.Stride = Stride;
  Type *MS = MT->getScalarType();
  bool Ext = LaneTy && LaneTy != MS;
  Op.Mn = (Twine(Stride ? "vldt." : "vld.") + memSuffix(MS, Ext && Zext) + (Ext ? "." + std::string(1, laneChar(LaneTy)) : std::string()) + " ").str();
  Op.Dst = newV(SetMap ? Ld : nullptr, Ext ? LaneTy : MS);
  if (RegOut) *RegOut = Op.Dst;
  Op.Stream = S;
  Prog.push_back(Op);
  noteUse(S);
  return true;
}

// the operand of an extension that an idiom reads through: the lane itself (V is the extension, or the narrow value)
bool Analyzer::narrowOperand(Value *V, Opnd &O, Type *Want) {
  Value *X = V;
  if (auto *E = dyn_cast<Instruction>(V)) if (isa<ZExtInst>(E) || isa<SExtInst>(E)) X = E->getOperand(0);
  Type *NT = X->getType()->getScalarType();
  if (VMap.count(X)) {
    if (Want && VLane.count(X) && laneChar(VLane[X]) != laneChar(Want)) return fail("the lane of an idiom's operand is not the narrow lane");
    O = Opnd::v(VMap[X]);
    return true;
  }
  if (auto *Ld = dyn_cast<LoadInst>(X))
    if (L->contains(Ld) && !InvSet.count(Ld)) {
      if (SE.isSCEVable(Ld->getPointerOperand()->getType()) && SE.isLoopInvariant(SE.getSCEV(Ld->getPointerOperand()), L)) return fail("an invariant load as the lane of an idiom");
      if (!plainLoad(Ld, NT, false)) return false;
      O = Opnd::v(VMap[Ld]);
      return true;
    }
  return asVector(X, O, NT, true);
}


bool Analyzer::emitPat(Instruction *Root, Pat &P) {
  Type *NT = P.Narrow;
  char C = laneChar(NT);
  Opnd OA, OB;
  switch (P.Kind) {
  case Pat::Avg:
    if (C != 'b' && C != 'w') return fail("avg lanes");
    if (!narrowOperand(P.A, OA, NT) || !narrowOperand(P.B, OB, NT)) return false;
    emitLane(P.Uns ? "vavgu" : "vavg", C, OA, OB, NT, Root);
    return true;
  case Pat::Mulh: case Pat::MulhR:
    if (C != 'w') return fail("mulh lanes");
    if (!narrowOperand(P.A, OA, NT)) return false;
    if (P.BImm) OB = Opnd::i(P.Imm);
    else if (!narrowOperand(P.B, OB, NT)) return false;
    emitLane(P.Kind == Pat::MulhR ? "vmulhr" : P.Uns ? "vmulhu" : "vmulh", C, OA, OB, NT, Root);
    return true;
  case Pat::SRound:
    if (C != 'w' && C != 'l') return fail("rounding shift lanes");
    if (!narrowOperand(P.A, OA, NT)) return false;
    if (OA.Kind != Opnd::V) return fail("a rounding shift of a scalar");
    emitLane(P.Uns ? "vshrr" : "vsarr", C, OA, Opnd::i(P.Sh), NT, Root);
    return true;
  }
  return false;
}

// a compare makes a mask: integer lanes of the size compared (the compare is bits: also for .f).  Greater-than is the one ordering word; less-than swaps the
// operands, and what the word cannot say (<=, !=, the unordered predicates) is the negation of one that it can, kept as a flag on the mask: the arms of the
// select that uses it are swapped, so that no instruction is spent.  NaN: the compares are ordered, so a predicate that is true for NaN is the negation of an ordered one.
bool Analyzer::emitCmp(CmpInst *Cmp) {
  Value *X = Cmp->getOperand(0), *Y = Cmp->getOperand(1);
  Type *OT = X->getType()->getScalarType();
  char C = laneChar(OT);
  bool FP = OT->isFloatingPointTy();
  if (!C || (FP && C != 'f') || (!FP && C != 'b' && C != 'w' && C != 'l')) return fail("a compare of lanes that vceq / vcgt do not read");
  enum { EQ, GT, GTU } K = EQ;
  bool Swap = false, Inv = false;
  int Comb = 0;   // 1: or the equal mask; 2: or the greater mask with the operands swapped
  bool NN = FP && Cmp->hasNoNaNs();
  switch (Cmp->getPredicate()) {
  case CmpInst::ICMP_EQ: K = EQ; break;
  case CmpInst::ICMP_NE: K = EQ; Inv = true; break;
  case CmpInst::ICMP_SGT: K = GT; break;
  case CmpInst::ICMP_SLE: K = GT; Inv = true; break;
  case CmpInst::ICMP_SLT: K = GT; Swap = true; break;
  case CmpInst::ICMP_SGE: K = GT; Swap = true; Inv = true; break;
  case CmpInst::ICMP_UGT: K = GTU; break;
  case CmpInst::ICMP_ULE: K = GTU; Inv = true; break;
  case CmpInst::ICMP_ULT: K = GTU; Swap = true; break;
  case CmpInst::ICMP_UGE: K = GTU; Swap = true; Inv = true; break;
  case CmpInst::FCMP_OEQ: K = EQ; break;
  case CmpInst::FCMP_UNE: K = EQ; Inv = true; break;
  case CmpInst::FCMP_OGT: K = GT; break;
  case CmpInst::FCMP_ULE: K = GT; Inv = true; break;
  case CmpInst::FCMP_OLT: K = GT; Swap = true; break;
  case CmpInst::FCMP_UGE: K = GT; Swap = true; Inv = true; break;
  case CmpInst::FCMP_OGE: K = GT; if (NN) { Swap = true; Inv = true; } else Comb = 1; break;
  case CmpInst::FCMP_ULT: K = GT; if (NN) { Swap = true; } else { Comb = 1; Inv = true; } break;   // ult = not oge
  case CmpInst::FCMP_OLE: K = GT; Swap = true; if (NN) { Swap = false; Inv = true; } else Comb = 1; break;
  case CmpInst::FCMP_UGT: K = GT; if (NN) { } else { Swap = true; Comb = 1; Inv = true; } break;   // ugt = not ole
  case CmpInst::FCMP_ONE: if (NN) { K = EQ; Inv = true; } else { K = GT; Comb = 2; } break;
  case CmpInst::FCMP_UEQ: if (NN) { K = EQ; } else { K = GT; Comb = 2; Inv = true; } break;
  case CmpInst::FCMP_ORD: case CmpInst::FCMP_UNO: {   // ord(x, y) = (x == x) & (y == y): a NaN is not equal to itself; no second compare for a constant that is not a NaN or the same value
    bool Un = Cmp->getPredicate() == CmpInst::FCMP_UNO;
    Value *CY = Y;
    if (auto *CC = dyn_cast<Constant>(Y)) if (CC->getType()->isVectorTy()) if (Constant *Sp = CC->getSplatValue()) CY = Sp;
    bool YFree = X == Y || (isa<ConstantFP>(CY) && !cast<ConstantFP>(CY)->isNaN());
    Type *MT0 = IntegerType::get(ctx(), 32);
    Opnd P1, P2;
    if (!asVector(X, P1, OT, false)) return false;
    int D = emitLane("vceq", 'f', P1, P1, MT0, YFree ? Cmp : nullptr);
    if (!YFree) {
      if (!asVector(Y, P2, OT, false)) return false;
      int D2 = emitLane("vceq", 'f', P2, P2, MT0);
      D = emitLane("vand", 'l', Opnd::v(D), Opnd::v(D2), MT0, Cmp);
    }
    VLane[Cmp] = MT0;
    MaskInv[Cmp] = Un;
    return true;
  }
  default: return fail("a compare predicate with no vector form (constant)");
  }
  const char *Base = K == EQ ? "vceq" : K == GT ? "vcgt" : "vcgtu";
  Value *First = Swap ? Y : X, *Second = Swap ? X : Y;
  Opnd O1, O2;
  if (!asVector(First, O1, OT, !FP)) return false;
  if (!operandOf(Second, O2, !FP)) return fail("a compare operand");
  Type *MT = IntegerType::get(ctx(), 8 * (C == 'b' ? 1 : C == 'w' ? 2 : 4));
  char MC = C == 'f' ? 'l' : C;
  int D = emitLane(Base, C, O1, O2, MT, Cmp);
  if (Comb) {
    Opnd P1, P2;
    const char *B2 = Comb == 1 ? "vceq" : "vcgt";
    Value *F2 = Comb == 1 ? X : Y, *S2 = Comb == 1 ? Y : X;
    if (!asVector(F2, P1, OT, !FP) || !operandOf(S2, P2, !FP)) return fail("a compare operand");
    int D2 = emitLane(B2, C, P1, P2, MT);
    D = emitLane("vor", MC, Opnd::v(D), Opnd::v(D2), MT, Cmp);
  }
  VLane[Cmp] = MT;
  MaskInv[Cmp] = Inv;
  return true;
}

// the mask register of a compare, as it is or negated (vxor with all ones)
bool Analyzer::maskOperand(Value *Cond, bool WantInv, Opnd &O) {
  auto It = VMap.find(Cond);
  if (It == VMap.end() || !VLane.count(Cond)) return fail("a mask that is not the result of a compare in the loop");
  bool Inv = MaskInv.lookup(Cond);
  O = Opnd::v(It->second);
  if (Inv != WantInv) {
    char MC = laneChar(VLane[Cond]);
    int D = emitLane("vxor", MC, O, Opnd::i(-1), VLane[Cond]);
    O = Opnd::v(D);
  }
  return true;
}

// select(mask, a, b): vbsl takes the bits of a where the mask is 1
bool Analyzer::emitSelect(SelectInst *Sel) {
  Value *Cd = Sel->getCondition();
  Type *T = Sel->getType()->getScalarType();
  char DC = laneChar(T);
  if (!DC) return fail("the lane type of a select");
  auto It = VMap.find(Cd);
  if (It == VMap.end() || !VLane.count(Cd)) return fail("a select whose condition is not a compare of the loop");
  unsigned MBytes = VLane[Cd]->getScalarSizeInBits() / 8;
  bool Inv = MaskInv.lookup(Cd);
  Value *TV = Sel->getTrueValue(), *FV = Sel->getFalseValue();
  if (Inv) std::swap(TV, FV);
  Opnd OT, OF;
  if (T->getScalarSizeInBits() / 8 > MBytes) return fail("a select whose arms are wider than its mask");
  if (T->getScalarSizeInBits() / 8 < MBytes) {
    // narrow arms, wider mask (a halfword or byte compared with an int): the arms are loaded as wide lanes (vld.w.l) or splatted wide, the select is made in the wide lanes and
    // only the low bits are kept by the narrowing store, so the select must be only stored
    for (User *U : Sel->users()) {
      auto *St = dyn_cast<StoreInst>(U);
      if (!St || St->getValueOperand() != Sel) return fail("a select whose arms are narrower than its mask and whose result is not stored");
    }
    Type *WT = IntegerType::get(ctx(), 8 * MBytes);
    auto Wide = [&](Value *V, Opnd &O) -> bool {
      if (auto *Ld = dyn_cast<LoadInst>(V)) if (L->contains(Ld) && !InvSet.count(Ld)) {
        int R;
        if (!plainLoad(Ld, WT, false, false, &R)) return false;
        O = Opnd::v(R);
        return true;
      }
      if (inLoop(V) && !InvSet.count(V)) return fail("a select arm that is a computed narrow value, with a wider mask");
      Opnd Q;
      if (!operandOf(V, Q, true)) return fail("a select arm");
      if (Q.Kind == Opnd::V) return fail("a select arm that is a computed narrow value, with a wider mask");
      VOp M;
      M.Kind = VOp::Mov;
      M.Mn = (Twine("vmov.") + Twine(laneChar(WT)) + " ").str();
      M.Dst = newV(nullptr, WT);
      M.B = Q;
      Prog.push_back(M);
      O = Opnd::v(M.Dst);
      return true;
    };
    if (!Wide(TV, OT) || !Wide(FV, OF)) return false;
    VOp Op;
    Op.Kind = VOp::Bsl;
    Op.Mn = "vbsl ";
    Op.C = Opnd::v(It->second); Op.A = OT; Op.B = OF;
    Op.Dst = newV(Sel, WT);   // the lane type of the register: the store narrows it
    Prog.push_back(Op);
    return true;
  }
  if (!asVector(TV, OT, T, true) || !asVector(FV, OF, T, true)) return false;
  VOp Op;
  Op.Kind = VOp::Bsl;
  Op.Mn = "vbsl ";
  Op.C = Opnd::v(It->second); Op.A = OT; Op.B = OF;
  Op.Dst = newV(Sel, T);
  Prog.push_back(Op);
  return true;
}

// int <-> float of 32-bit lanes: vcvt.l.f (sitofp), vcvt.lu.f (uitofp), vcvt.f.l (fptosi), vcvt.f.lu (fptoui)
bool Analyzer::emitConv(CastInst *Cv) {
  Type *ST = Cv->getOperand(0)->getType()->getScalarType(), *DT = Cv->getType()->getScalarType();
  bool ToF = isa<SIToFPInst>(Cv) || isa<UIToFPInst>(Cv);
  bool Uns = isa<UIToFPInst>(Cv) || isa<FPToUIInst>(Cv);
  Opnd OA;
  if (ToF) {
    if (!DT->isFloatTy() || !ST->isIntegerTy()) return fail("a conversion that is not between 32-bit integer and binary32");
    unsigned SB = ST->getIntegerBitWidth();
    Value *X = Cv->getOperand(0);
    if (SB == 8 || SB == 16) {   // the byte or halfword is loaded as a 32-bit lane
      auto *Ld = dyn_cast<LoadInst>(X);
      if (!Ld || !LazyLoad.count(Ld)) return fail("a conversion of a byte or halfword that is not a loaded value");
      if (!VMap.count(Ld) && !plainLoad(Ld, Type::getInt32Ty(ctx()), Uns)) return false;
    } else if (SB != 32) return fail("a conversion of a 64-bit integer");
    if (!operandOf(X, OA, false) || OA.Kind != Opnd::V) return fail("a conversion of a scalar");
  } else {
    if (!ST->isFloatTy() || !DT->isIntegerTy(32)) return fail("a conversion that is not between binary32 and 32-bit integer");
    if (!operandOf(Cv->getOperand(0), OA, false) || OA.Kind != Opnd::V) return fail("a conversion of a scalar");
  }
  VOp Op;
  Op.Kind = VOp::Lane;
  Op.Mn = ToF ? ((Uns && Cv->getOperand(0)->getType()->getScalarSizeInBits() == 32) ? "vcvt.lu.f " : "vcvt.l.f ") : (Uns ? "vcvt.f.lu " : "vcvt.f.l ");
  Op.A = OA; Op.B = Opnd::v(OA.Id);
  Op.Dst = newV(Cv, DT);
  Prog.push_back(Op);
  return true;
}

bool Analyzer::matchReduction(PHINode *Phi, Instruction *&Next, Acc &A) {
  if (Phi->getNumIncomingValues() != 2) return fail("a phi with more than two inputs");
  BasicBlock *Latch = L->getLoopLatch();
  Value *N = Phi->getIncomingValueForBlock(Latch);
  Next = dyn_cast<Instruction>(N);
  if (!Next || !L->contains(Next)) return fail("a phi that is not a reduction");
  Type *Ty = Phi->getType()->getScalarType();
  if (Phi->getType()->isVectorTy() != Vec) return fail("a reduction phi of the wrong kind");
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
    Intrinsic::ID ID = II->getIntrinsicID();
    if (ID == Intrinsic::smax) A.Base = "vmaxacc";
    else if (ID == Intrinsic::smin) A.Base = "vminacc";
    else if ((ID == Intrinsic::umax || ID == Intrinsic::umin) && Ty->getIntegerBitWidth() <= 32) { A.Base = ID == Intrinsic::umax ? "vmaxacc" : "vminacc"; A.Uns = true; }
    else if ((ID == Intrinsic::maxnum || ID == Intrinsic::minnum) && II->hasNoNaNs()) A.Base = ID == Intrinsic::maxnum ? "vmaxacc" : "vminacc";
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
  {   // vdacc / vsad: the products or the absolute differences of a whole strip go into the scalar register as one instruction
    VOp Op;
    Op.Kind = VOp::Reduce;
    Op.Acc = RS.Acc;
    auto DI = DotOf.find(I);
    auto SI = SadOf.find(I);
    if (DI != DotOf.end() || SI != SadOf.end()) {
      Instruction *E0 = DI != DotOf.end() ? DI->second.E0 : SI->second.E0, *E1 = DI != DotOf.end() ? DI->second.E1 : SI->second.E1;
      Type *NT = E0->getOperand(0)->getType()->getScalarType();
      Opnd OA, OB;
      if (!narrowOperand(E0, OA, NT) || !narrowOperand(E1, OB, NT)) return false;
      if (OA.Kind != Opnd::V || OB.Kind != Opnd::V) return fail("a dot product operand that is not a vector");
      Op.Mn = DI != DotOf.end() ? DI->second.Mn : "vsad.bu ";
      Op.A = OA; Op.B = OB;
      Prog.push_back(Op);
      return true;
    }
  }
  bool Uns = false;
  if (A.Base == StringRef("vacc") && !A.IsFP) {  // an extension of a narrower lane is the same reduction: vacc.<src>.<acc> extends, signed or unsigned as <src> says (errata 168)
    if (auto *C = dyn_cast<SExtInst>(Src)) {
      if (VMap.count(C->getOperand(0)) && laneOK(C->getOperand(0)->getType())) Src = C->getOperand(0);
    } else if (auto *Z = dyn_cast<ZExtInst>(Src)) {
      if (VMap.count(Z->getOperand(0)) && laneOK(Z->getOperand(0)->getType())) { Src = Z->getOperand(0); Uns = true; }
    }
  }
  auto It = VMap.find(Src);
  if (It == VMap.end()) return fail("the reduced value is not a vector value");
  VOp Op;
  Op.Kind = VOp::Reduce;
  {
    // the spelling: vacc.<src>.<acc> (the source lane type, with u for unsigned, then the width the strip's sum is made in: l for byte and halfword lanes, whose sum of a strip
    // cannot pass 32 bits; q for 64-bit lanes; l or q for 32-bit lanes by the width of the accumulator), vmaxacc.<src>, vminacc.<src>; floating point: vacc.f, vacc.d
    char C = laneChar(VLane[Src]);
    std::string SrcS(1, C);
    if (Uns && !A.IsFP) SrcS += 'u';
    if (A.Base == StringRef("vacc") && !A.IsFP) {
      bool Q = C == 'q' || (C == 'l' && A.Ty->getIntegerBitWidth() == 64);
      Op.Mn = "vacc." + SrcS + (Q ? ".q " : ".l ");
    } else {
      if (A.Uns) SrcS += 'u';
      Op.Mn = (Twine(A.Base) + "." + SrcS + " ").str();
    }
  }
  Op.A = Opnd::v(It->second);
  Op.Acc = RS.Acc;
  Prog.push_back(Op);
  return true;
}

bool Analyzer::run() {
  BasicBlock *H = L->getHeader();
  for (Instruction &I : *H) {   // (a store of a vector has no vector type of its own)
    if (I.getType()->isVectorTy()) Vec = true;
    if (auto *St = dyn_cast<StoreInst>(&I)) if (St->getValueOperand()->getType()->isVectorTy()) Vec = true;
  }
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


  // ---- the reductions are matched first: the dot-product and SAD idioms of a reduction step claim their operands
  for (PHINode &Phi : H->phis()) {
    if (Scaf.count(&Phi)) continue;
    Instruction *N; Acc A;
    if (!matchReduction(&Phi, N, A)) return false;
  }

  // ---- the idioms of the new words (waves 1 and 2).  Claimed: the instructions an idiom absorbs (they are not emitted)
  SmallPtrSet<Instruction *, 32> Claimed;
  SmallPtrSet<Instruction *, 16> Skip;
  auto InLoopI = [&](Value *V) -> Instruction * { auto *I = dyn_cast<Instruction>(V); return I && L->contains(I) ? I : nullptr; };
  auto OneUseI = [&](Value *V) -> Instruction * { Instruction *I = InLoopI(V); return I && I->hasOneUse() ? I : nullptr; };
  auto IsExt = [&](Value *V, bool &Z, Type *&Src) -> Instruction * {
    Instruction *E = InLoopI(V);
    if (!E || !(isa<ZExtInst>(E) || isa<SExtInst>(E))) return nullptr;
    Src = E->getOperand(0)->getType()->getScalarType();
    if (!Src->isIntegerTy() || !laneOK(Src)) return nullptr;
    Z = isa<ZExtInst>(E);
    return E;
  };
  auto UsersTruncTo = [&](Instruction *R, unsigned Bits) {
    if (R->use_empty()) return false;
    for (User *U : R->users()) {
      auto *T = dyn_cast<TruncInst>(U);
      if (!T || !L->contains(T) || T->getType()->getScalarSizeInBits() != Bits) return false;
    }
    return true;
  };
  auto FreeOf = [&](std::initializer_list<Instruction *> Is) {
    for (Instruction *I : Is) if (I && Claimed.count(I)) return false;
    return true;
  };
  // the products' operands of a high multiply: an extension of a halfword, or a constant that fits the 16 bits the word reads
  auto Mul16 = [&](BinaryOperator *M, bool WantSigned, Pat &P) -> bool {
    bool Z0 = false, Z1 = false; Type *S0 = nullptr, *S1 = nullptr;
    Value *P0 = M->getOperand(0), *P1 = M->getOperand(1);
    Instruction *E0 = IsExt(P0, Z0, S0), *E1 = IsExt(P1, Z1, S1);
    if (!E0) { std::swap(P0, P1); std::swap(E0, E1); std::swap(Z0, Z1); std::swap(S0, S1); }
    if (!E0 || S0->getIntegerBitWidth() != 16) return false;
    if (Z0 == WantSigned) return false;
    P.A = E0; P.Uns = Z0;
    if (E1) {
      if (S1 != S0 || Z1 != Z0) return false;
      P.B = E1;
    } else if (auto *C = constInt(P1)) {
      APInt V = C->getValue();
      if (Z0 ? (V.isNegative() || V.getActiveBits() > 16) : V.getSignificantBits() > 16) return false;
      P.BImm = true; P.Imm = (int16_t)V.getZExtValue();
    } else return false;
    if (M->getType()->getScalarSizeInBits() < 32) return false;
    return true;
  };
  auto Absorb = [&](Pat &P, std::initializer_list<Instruction *> Is) {
    for (Instruction *I : Is) if (I) Claimed.insert(I);
    if (auto *E = dyn_cast_or_null<Instruction>(P.A)) PatExt.insert(E);
    if (auto *E = dyn_cast_or_null<Instruction>(P.B)) PatExt.insert(E);
  };
  // the Q15 rounding multiply is found first (its shift would otherwise be taken as a rounding shift)
  for (Instruction &I : *H) {
    auto *II = dyn_cast<IntrinsicInst>(&I);
    if (Scaf.count(&I) || Claimed.count(&I)) continue;
    // the Q15 rounding multiply with its saturation: trunc(smin((x * y + 2^14) >> 15, 32767))
    if (II && II->getIntrinsicID() == Intrinsic::smin) {
      auto *C = constInt(II->getArgOperand(1));
      auto *Sr = OneUseI(II->getArgOperand(0));
      if (C && C->getValue() == 32767 && Sr && Sr->getOpcode() == Instruction::AShr && UsersTruncTo(II, 16)) {
        auto *C15 = constInt(Sr->getOperand(1));
        Instruction *Ad = OneUseI(Sr->getOperand(0));
        if (C15 && C15->getZExtValue() == 15 && Ad && Ad->getOpcode() == Instruction::Add) {
          auto *CA = constInt(Ad->getOperand(1));
          Instruction *Mu = OneUseI(Ad->getOperand(0));
          if (!CA) { CA = constInt(Ad->getOperand(0)); Mu = OneUseI(Ad->getOperand(1)); }
          if (CA && Mu && Mu->getOpcode() == Instruction::Mul && CA->getValue() == 16384 && FreeOf({Sr, Ad, Mu})) {
            Pat P; P.Kind = Pat::MulhR;
            if (Mul16(cast<BinaryOperator>(Mu), true, P)) {
              P.Narrow = Type::getIntNTy(ctx(), 16);
              Pats[&I] = P; Absorb(Pats[&I], {Sr, Ad, Mu});
              continue;
            }
          }
        }
      }
    }
  }
  for (Instruction &I : *H) {
    auto *Bo = dyn_cast<BinaryOperator>(&I);
    if (Scaf.count(&I) || Claimed.count(&I)) continue;
    if (Bo && (Bo->getOpcode() == Instruction::LShr || Bo->getOpcode() == Instruction::AShr)) {
      auto *Cs = constInt(Bo->getOperand(1));
      if (!Cs) continue;
      bool IsA = Bo->getOpcode() == Instruction::AShr;
      uint64_t Sh = Cs->getZExtValue();
      Instruction *X = OneUseI(Bo->getOperand(0));
      if (!X) continue;
      // avg: (a + b + 1) >> 1 in a wider type, both extended the same way from bytes or halfwords
      if (Sh == 1 && X->getOpcode() == Instruction::Add) {
        SmallVector<Value *, 4> T;
        SmallVector<Instruction *, 3> Adds{X};
        for (Value *Op : X->operands()) {
          Instruction *Ad = OneUseI(Op);
          if (Ad && Ad->getOpcode() == Instruction::Add && !Ad->hasNUsesOrMore(2) && Ad != X) {
            Adds.push_back(Ad);
            for (Value *O2 : Ad->operands()) T.push_back(O2);
          } else T.push_back(Op);
        }
        if (T.size() == 3) {
          int One = -1;
          for (int k = 0; k < 3; ++k) if (auto *C = constInt(T[k])) if (C->isOne()) One = k;
          if (One >= 0) {
            Value *V[2]; int n = 0;
            for (int k = 0; k < 3; ++k) if (k != One) V[n++] = T[k];
            bool Z0, Z1; Type *S0, *S1;
            Instruction *E0 = IsExt(V[0], Z0, S0), *E1 = IsExt(V[1], Z1, S1);
            unsigned Bits = E0 ? S0->getIntegerBitWidth() : 0;
            if (E0 && E1 && S0 == S1 && Z0 == Z1 && (Bits == 8 || Bits == 16) && Bo->getType()->getScalarSizeInBits() >= Bits + 2 && UsersTruncTo(&I, Bits) &&
                FreeOf({X, Adds.size() > 1 ? Adds[1] : nullptr, Adds.size() > 2 ? Adds[2] : nullptr})) {
              Pat P; P.Kind = Pat::Avg; P.A = E0; P.B = E1; P.Uns = Z0; P.Narrow = S0;
              Pats[&I] = P;
              Absorb(Pats[&I], {X, Adds.size() > 1 ? Adds[1] : nullptr, Adds.size() > 2 ? Adds[2] : nullptr});
              continue;
            }
          }
        }
      }
      // the high half of a 16 x 16 product: trunc(x * y >> 16); both extended the same way (the shift, arithmetic or logical, does not matter: the low 16 bits only)
      if (Sh == 16 && X->getOpcode() == Instruction::Mul && UsersTruncTo(&I, 16)) {
        Pat P; P.Kind = Pat::Mulh;
        bool Sg = false;
        auto *M = cast<BinaryOperator>(X);
        bool Ok = Mul16(M, true, P);   // signed
        if (!Ok) { Pat P2; P2.Kind = Pat::Mulh; Ok = Mul16(M, false, P2); if (Ok) P = P2; }
        (void)Sg;
        if (Ok && FreeOf({X})) {
          P.Narrow = Type::getIntNTy(ctx(), 16);
          Pats[&I] = P;
          Absorb(Pats[&I], {X});
          continue;
        }
      }
      // a rounding shift: (x + 2^(s-1)) >> s
      if (Sh >= 1 && X->getOpcode() == Instruction::Add) {
        auto *CA = constInt(X->getOperand(1));
        Value *Y = X->getOperand(0);
        if (!CA) { CA = constInt(X->getOperand(0)); Y = X->getOperand(1); }
        unsigned W = Bo->getType()->getScalarSizeInBits();
        if (CA && Sh < W && CA->getValue() == APInt::getOneBitSet(CA->getBitWidth(), Sh - 1) && FreeOf({X})) {
          bool Z; Type *S;
          Instruction *E = IsExt(Y, Z, S);
          unsigned SB = E ? S->getIntegerBitWidth() : 0;
          Pat P; P.Kind = Pat::SRound; P.Sh = Sh; P.Uns = !IsA;
          // the narrow lanes: the sum in the wide type cannot wrap, and the narrow result is the same bits whichever way the wide shift fills (the users keep the low SB bits)
          if (E && (SB == 16 || SB == 32) && SB < W && Sh < SB && Sh + SB <= W && UsersTruncTo(&I, SB)) {
            P.A = E; P.Narrow = S; P.Uns = Z;
            Pats[&I] = P; Absorb(Pats[&I], {X});
            continue;
          }
          bool NoWrap = IsA ? X->hasNoSignedWrap() : X->hasNoUnsignedWrap();
          if (!E && NoWrap && (W == 16 || W == 32) && Sh < W) {   // the same width: the sum is exact only if the IR says it does not wrap
            P.A = Y; P.Narrow = Bo->getType()->getScalarType();
            Pats[&I] = P; Absorb(Pats[&I], {X});
            continue;
          }
        }
      }
    }
  }
  // a widening product or an absolute difference that is a step of a sum into an accumulator: vdacc, vsad
  for (auto &KV : RedStepOf) {
    Instruction *Step = KV.first;
    Acc &A = Accs[KV.second.Acc];
    if (A.Base != StringRef("vacc") || A.IsFP) continue;
    Instruction *X = OneUseI(KV.second.X);
    if (!X || Claimed.count(X)) continue;
    if (X->getOpcode() == Instruction::Mul) {
      bool Z0, Z1; Type *S0, *S1;
      Instruction *E0 = IsExt(X->getOperand(0), Z0, S0), *E1 = IsExt(X->getOperand(1), Z1, S1);
      if (!E0 || !E1 || S0 != S1) continue;
      unsigned Bits = S0->getIntegerBitWidth();
      if ((Bits != 8 && Bits != 16) || X->getType()->getScalarSizeInBits() < 2 * Bits) continue;
      const char *Mn = nullptr;
      if (Bits == 16) { if (!Z0 && !Z1) Mn = "vdacc.w "; }
      else if (!Z0 && !Z1) Mn = "vdacc.b ";
      else if (Z0 && Z1) Mn = "vdacc.bu ";
      else { if (Z1) Mn = "vdacc.bsu "; else { Mn = "vdacc.bsu "; std::swap(E0, E1); } }
      if (!Mn) continue;
      DotOf[Step] = {E0, E1, Mn};
      Claimed.insert(X); PatExt.insert(E0); PatExt.insert(E1);
    } else if (auto *Ab = dyn_cast<IntrinsicInst>(X)) {
      if (Ab->getIntrinsicID() != Intrinsic::abs) continue;
      Instruction *Sb = OneUseI(Ab->getArgOperand(0));
      if (!Sb || Sb->getOpcode() != Instruction::Sub || Claimed.count(Sb)) continue;
      bool Z0, Z1; Type *S0, *S1;
      Instruction *E0 = IsExt(Sb->getOperand(0), Z0, S0), *E1 = IsExt(Sb->getOperand(1), Z1, S1);
      if (!E0 || !E1 || !Z0 || !Z1 || S0 != S1 || S0->getIntegerBitWidth() != 8 || Sb->getType()->getScalarSizeInBits() < 9) continue;
      SadOf[Step] = {E0, E1};
      Claimed.insert(X); Claimed.insert(Sb); PatExt.insert(E0); PatExt.insert(E1);
    }
  }
  // an extension whose every user is claimed is not emitted
  for (Instruction *E : PatExt) {
    bool All = true;
    for (User *U : E->users()) if (!Claimed.count(cast<Instruction>(U)) && !Pats.count(cast<Instruction>(U))) All = false;
    if (All) Claimed.insert(E);
  }
  for (Instruction *C : Claimed) Skip.insert(C);

  // the arms of a select that are narrower than its compare (a halfword or byte value against an int) are loaded wide at the select: the narrow load is not made
  for (Instruction &I : *H) {
    auto *Sl = dyn_cast<SelectInst>(&I);
    if (!Sl || Scaf.count(Sl) || RedStepOf.count(Sl)) continue;
    auto *Cm = dyn_cast<CmpInst>(Sl->getCondition());
    if (!Cm || (!Cm->getOperand(0)->getType()->getScalarType()->isIntegerTy() && !Cm->getOperand(0)->getType()->getScalarType()->isFloatTy())) continue;
    if (Sl->getType()->getScalarSizeInBits() >= Cm->getOperand(0)->getType()->getScalarSizeInBits()) continue;
    for (Value *Arm : {Sl->getTrueValue(), Sl->getFalseValue()})
      if (auto *Ld = dyn_cast<LoadInst>(Arm))
        if (L->contains(Ld) && Ld->hasOneUse() && !Scaf.count(Ld) && SE.isSCEVable(Ld->getPointerOperand()->getType()) && !SE.isLoopInvariant(SE.getSCEV(Ld->getPointerOperand()), L))
          LazyLoad[Ld] = false;
  }

  // the fused forms: a load only extended, a trunc only stored, a clamp only truncated and stored
  DenseMap<Instruction *, std::pair<Instruction *, bool>> ExtOf;  // load -> (its single extension, zext?)
  for (Instruction &I : *H) {
    auto *Ld = dyn_cast<LoadInst>(&I);
    if (!Ld || Scaf.count(Ld)) continue;
    if (Ld->use_empty()) continue;
    if (SE.isSCEVable(Ld->getPointerOperand()->getType()) && SE.isLoopInvariant(SE.getSCEV(Ld->getPointerOperand()), L)) continue;  // an invariant load is hoisted, with its extension
    {   // read only through the idioms of the new words: the narrow lanes are what they want (the load is made as it is)
      bool AllPat = true;
      for (User *U : Ld->users()) if (!PatExt.count(cast<Instruction>(U))) AllPat = false;
      if (AllPat) continue;
      // only converted to float (a byte or halfword to float: the load widens it to 32-bit lanes, vld.bu.l, and vcvt.l.f converts)
      bool AllCvt = true, ZC = false;
      for (User *U : Ld->users()) {
        auto *C = dyn_cast<CastInst>(U);
        if (!C || !L->contains(C) || !(isa<SIToFPInst>(C) || isa<UIToFPInst>(C)) || !C->getType()->getScalarType()->isFloatTy() ||
            !(C->getOperand(0)->getType()->getScalarSizeInBits() == 8 || C->getOperand(0)->getType()->getScalarSizeInBits() == 16) ||
            (U != *Ld->user_begin() && ZC != isa<UIToFPInst>(C))) { AllCvt = false; break; }
        ZC = isa<UIToFPInst>(C);
      }
      if (AllCvt) { LazyLoad[Ld] = ZC; continue; }
    }
    Instruction *E = nullptr;
    bool Z = false, Ok = true;
    for (User *U : Ld->users()) {
      auto *UI = dyn_cast<Instruction>(U);
      if (UI && (isa<ZExtInst>(UI) || isa<SExtInst>(UI) || isa<FPExtInst>(UI)) && L->contains(UI)) {   // (a float loaded as a double: vld.f.d)
        if (E && (E->getType() != UI->getType() || isa<ZExtInst>(E) != isa<ZExtInst>(UI))) { Ok = false; break; }
        E = UI; Z = isa<ZExtInst>(UI);
      } else { Ok = false; break; }
    }
    if (Ok && E && E->hasOneUse()) {   // a zero or sign extension that is only the addend of a sum into a phi of the loop: vacc extends, from the narrow lanes
      auto *U = dyn_cast<BinaryOperator>(*E->user_begin());
      if (U && U->getOpcode() == Instruction::Add && L->contains(U))
        for (Value *Op : U->operands())
          if (auto *Ph = dyn_cast<PHINode>(Op))
            if (Ph->getParent() == H && Ph->getIncomingValueForBlock(L->getLoopLatch()) == U) Ok = false;
    }
    if (Ok && E) {
      // every extension of the same type and kind is the same value: map them all
      ExtOf[Ld] = {E, Z};
      for (User *U : Ld->users()) Skip.insert(cast<Instruction>(U));
    }
  }
  struct SatSt { Value *Src; Type *MemTy; int Mode; int RSh; };  // Mode 0: truncate, 1: signed clamp, 2: unsigned clamp
  DenseMap<StoreInst *, SatSt> StoreForm;
  for (Instruction &I : *H) {
    auto *St = dyn_cast<StoreInst>(&I);
    if (!St || Scaf.count(St)) continue;
    if (auto *FT = dyn_cast<FPTruncInst>(St->getValueOperand()))   // a double stored as a float: vst.d.f
      if (FT->hasOneUse() && L->contains(FT)) { Skip.insert(FT); StoreForm[St] = {FT->getOperand(0), FT->getType(), 0, -1}; continue; }
    auto *Tr = dyn_cast<TruncInst>(St->getValueOperand());
    if (!Tr || !Tr->hasOneUse() || !L->contains(Tr)) continue;
    Type *MemTy = Tr->getType();
    if (!MemTy->getScalarType()->isIntegerTy()) continue;
    unsigned NB = MemTy->getScalarSizeInBits();
    Value *Y = Tr->getOperand(0);
    int Mode = 0;
    Instruction *C1 = nullptr, *C2 = nullptr;
    // smin(smax(y, lo), hi) or smax(smin(y, hi), lo)
    auto Clamp = [&](Value *V, Intrinsic::ID Outer, Intrinsic::ID Inner, Value *&Y2, APInt &Lo, APInt &Hi) -> bool {
      auto *O = dyn_cast<IntrinsicInst>(V);
      if (!O || O->getIntrinsicID() != Outer || !O->hasOneUse()) return false;
      auto *In = dyn_cast<IntrinsicInst>(O->getArgOperand(0));
      auto *C = constInt(O->getArgOperand(1));
      if (!In || In->getIntrinsicID() != Inner || !In->hasOneUse() || !C) return false;
      auto *D = constInt(In->getArgOperand(1));
      if (!D) return false;
      Y2 = In->getArgOperand(0);
      if (Outer == Intrinsic::smin || Outer == Intrinsic::umin) { Hi = C->getValue(); Lo = D->getValue(); }
      else { Lo = C->getValue(); Hi = D->getValue(); }
      C1 = O; C2 = In;
      return true;
    };
    Value *Y2 = nullptr;
    APInt Lo, Hi;
    // (InstCombine writes the clamp to 0..255 as smax(y, 0) then umin(.., 255): the same unsigned clamp)
    bool UMinOuter = false;
    if (Clamp(Y, Intrinsic::smin, Intrinsic::smax, Y2, Lo, Hi) || Clamp(Y, Intrinsic::smax, Intrinsic::smin, Y2, Lo, Hi) ||
        (UMinOuter = Clamp(Y, Intrinsic::umin, Intrinsic::smax, Y2, Lo, Hi))) {
      unsigned W = Lo.getBitWidth();
      if (W > NB) {
        if (!UMinOuter && Lo == APInt::getSignedMinValue(NB).sext(W) && Hi == APInt::getSignedMaxValue(NB).sext(W)) Mode = 1;
        else if (Lo.isZero() && Hi == APInt::getMaxValue(NB).zext(W)) Mode = 2;
      }
      if (Mode) { Y = Y2; Skip.insert(C1); Skip.insert(C2); }
    }
    // the rounding shift in front of the clamp: vsts.<lane>.<m> #sh does (x + 2^(sh-1)) >> sh exactly and then clamps
    int RSh = -1;
    if (Mode) {
      Instruction *Sr = OneUseI(Y);
      if (Sr && Sr->getOpcode() == Instruction::AShr) {
        auto *Cs = constInt(Sr->getOperand(1));
        Instruction *Ad = OneUseI(Sr->getOperand(0));
        if (Cs && Ad && Ad->getOpcode() == Instruction::Add && Ad->hasNoSignedWrap() && (!Claimed.count(Ad) || Pats.count(Sr))) {
          auto *CA = constInt(Ad->getOperand(1));
          Value *X = Ad->getOperand(0);
          if (!CA) { CA = constInt(Ad->getOperand(0)); X = Ad->getOperand(1); }
          unsigned W = X->getType()->getScalarSizeInBits();
          uint64_t S0 = Cs->getZExtValue();
          if (CA && (W == 16 || W == 32 || W == 64) && S0 >= 1 && S0 < W && CA->getValue() == APInt::getOneBitSet(CA->getBitWidth(), S0 - 1) &&
              (!Pats.count(Sr) || Pats[Sr].Kind == Pat::SRound)) {
            if (Pats.count(Sr)) { Pats.erase(Sr); Claimed.erase(Ad); Skip.erase(Ad); }
            RSh = S0; Y = X; Skip.insert(Sr); Skip.insert(Ad);
          }
        }
      }
    }
    Skip.insert(Tr);
    StoreForm[St] = {Y, MemTy, Mode, RSh};
  }


  // LoopVectorize's interleaved access groups: ONE wide load whose users are the deinterleaving shuffles <k, k+F, k+2F, ...> (vlseg<F>), and ONE wide store
  // of the interleaving shuffles of F vectors (vsseg<F>).  Only groups with every field used: the block reads and writes whole records, a gap would touch
  // memory the program does not.
  struct SegLd { unsigned F; unsigned N; SmallVector<SmallVector<ShuffleVectorInst *, 2>, 4> Fld; };
  struct SegSt { unsigned F; unsigned N; SmallVector<Value *, 4> Src; Type *MemTy; };
  DenseMap<LoadInst *, SegLd> SegLoads;
  DenseMap<StoreInst *, SegSt> SegStores;
  if (Vec) {
    for (Instruction &I : *H) {
      auto *Ld = dyn_cast<LoadInst>(&I);
      if (!Ld || Scaf.count(Ld) || Ld->use_empty()) continue;
      auto *VT = dyn_cast<FixedVectorType>(Ld->getType());
      if (!VT) continue;
      bool AllSh = true;
      for (User *U : Ld->users()) {
        auto *SV = dyn_cast<ShuffleVectorInst>(U);
        if (!SV || SV->getOperand(0) != Ld || !isa<PoisonValue>(SV->getOperand(1)) || !L->contains(SV)) AllSh = false;
      }
      if (!AllSh) continue;
      auto *S0 = cast<ShuffleVectorInst>(*Ld->user_begin());
      unsigned W = VT->getNumElements(), N = cast<FixedVectorType>(S0->getType())->getNumElements();
      if (N == 0 || W % N || W / N < 2 || W / N > 4) continue;
      unsigned F = W / N;
      SegLd G; G.F = F; G.N = N; G.Fld.resize(F);
      bool Ok = true;
      for (User *U : Ld->users()) {
        auto *SV = cast<ShuffleVectorInst>(U);
        if (cast<FixedVectorType>(SV->getType())->getNumElements() != N) { Ok = false; break; }
        int K = SV->getMaskValue(0);
        if (K < 0 || (unsigned)K >= F) { Ok = false; break; }
        for (unsigned i = 0; i < N; ++i) if (SV->getMaskValue(i) != (int)(K + F * i)) Ok = false;
        if (!Ok) break;
        G.Fld[K].push_back(SV);
      }
      for (auto &Fk : G.Fld) if (Fk.empty()) Ok = false;   // a field that nobody uses
      if (!Ok) continue;
      for (auto &Fk : G.Fld) for (auto *SV : Fk) Skip.insert(SV);
      SegLoads[Ld] = G;
    }
    // where does lane `Lane` of V come from, looking through shuffles (concatenations and interleavings)?
    std::function<bool(Value *, unsigned, Value *&, unsigned &, SmallVectorImpl<ShuffleVectorInst *> &)> LaneSrc =
        [&](Value *V, unsigned Lane, Value *&Src, unsigned &SL, SmallVectorImpl<ShuffleVectorInst *> &Used) -> bool {
      if (auto *SV = dyn_cast<ShuffleVectorInst>(V)) {
        auto *FL = dyn_cast<LoadInst>(SV->getOperand(0));
        if (!L->contains(SV) || !SV->hasOneUse() || (FL && SegLoads.count(FL))) { Src = V; SL = Lane; return true; }   // (a field of a segment load is a value, not a shuffle to look through)
        int M = SV->getMaskValue(Lane);
        if (M < 0) return false;
        unsigned N0 = cast<FixedVectorType>(SV->getOperand(0)->getType())->getNumElements();
        if (!is_contained(Used, SV)) Used.push_back(SV);
        return LaneSrc(M < (int)N0 ? SV->getOperand(0) : SV->getOperand(1), M < (int)N0 ? M : M - N0, Src, SL, Used);
      }
      if (isa<PoisonValue>(V) || isa<UndefValue>(V)) return false;
      Src = V; SL = Lane;
      return true;
    };
    for (Instruction &I : *H) {
      auto *St = dyn_cast<StoreInst>(&I);
      if (!St || Scaf.count(St)) continue;
      auto *VT = dyn_cast<FixedVectorType>(St->getValueOperand()->getType());
      if (!VT || !isa<ShuffleVectorInst>(St->getValueOperand()) || !St->getValueOperand()->hasOneUse()) continue;
      unsigned W = VT->getNumElements();
      for (unsigned F = 2; F <= 4; ++F) {
        if (W % F) continue;
        unsigned N = W / F;
        SmallVector<Value *, 4> Srcs(F, nullptr);
        SmallVector<ShuffleVectorInst *, 8> Used;
        bool Ok = true;
        for (unsigned i = 0; i < N && Ok; ++i)
          for (unsigned k = 0; k < F && Ok; ++k) {
            Value *Sv; unsigned Sl;
            if (!LaneSrc(St->getValueOperand(), i * F + k, Sv, Sl, Used) || Sl != i || !Sv->getType()->isVectorTy() ||
                cast<FixedVectorType>(Sv->getType())->getNumElements() != N) { Ok = false; break; }
            if (!Srcs[k]) Srcs[k] = Sv; else if (Srcs[k] != Sv) Ok = false;
          }
        if (!Ok) continue;
        // a field that is only truncated to the memory type: the store narrows (vsseg.<lane>.<m>)
        Type *MemTy = nullptr;
        bool AllTr = true, NoTr = true;
        for (Value *Sv : Srcs) { if (auto *Tr = dyn_cast<TruncInst>(Sv)) { if (!Tr->hasOneUse() || !L->contains(Tr)) AllTr = false; NoTr = false; } else AllTr = false; }
        SegSt G; G.F = F; G.N = N;
        if (AllTr) {
          bool Same = true;
          for (Value *Sv : Srcs) if (Sv->getType() != Srcs[0]->getType()) Same = false;
          if (!Same) continue;
          MemTy = Srcs[0]->getType();
          for (unsigned k = 0; k < F; ++k) { auto *Tr = cast<TruncInst>(Srcs[k]); Skip.insert(Tr); G.Src.push_back(Tr->getOperand(0)); }
        } else if (NoTr) {
          MemTy = Srcs[0]->getType();
          for (Value *Sv : Srcs) if (Sv->getType() != MemTy) Ok = false;
          if (!Ok) continue;
          for (Value *Sv : Srcs) G.Src.push_back(Sv);
        } else continue;
        G.MemTy = MemTy;
        for (auto *SV : Used) Skip.insert(SV);
        SegStores[St] = G;
        break;
      }
    }
  }

  // a multiply with the contract flag whose only user is an add (or the subtrahend of a subtract) with it: a multiply-add (vfma / vfnma)
  DenseMap<Instruction *, Instruction *> MulOf;   // the fadd/fsub -> its fmul
  for (Instruction &I : *H) {
    bool IsFM = I.getOpcode() == Instruction::FMul && isa<FPMathOperator>(I) && I.hasAllowContract();
    unsigned MB = I.getType()->getScalarSizeInBits();
    bool IsIM = I.getOpcode() == Instruction::Mul && (MB == 16 || MB == 32) && !Claimed.count(&I);   // vmla.w / vmla.l: vD += vA * vB (the low half, wrapping)
    if ((!IsFM && !IsIM) || !I.hasOneUse() || Scaf.count(&I)) continue;
    auto *U = dyn_cast<Instruction>(*I.user_begin());
    if (!U || !L->contains(U) || MulOf.count(U) || RedStepOf.count(U) || Claimed.count(U)) continue;
    if (IsFM && (!isa<FPMathOperator>(U) || !U->hasAllowContract())) continue;
    if (IsIM && U->getOpcode() != Instruction::Add) continue;
    bool IntoPhi = false;   // the sum of products: a reduction of a product, not a multiply-add
    for (Value *Op : U->operands()) if (auto *Ph = dyn_cast<PHINode>(Op)) if (Ph->getParent() == H) IntoPhi = true;
    if (IntoPhi) continue;
    if (IsIM && !(isa<LoadInst>(I.getOperand(0)) || isa<LoadInst>(I.getOperand(1)) || (InLoopI(I.getOperand(0)) && InLoopI(I.getOperand(1))))) continue;
    if (U->getOpcode() == Instruction::FAdd || U->getOpcode() == Instruction::Add || (U->getOpcode() == Instruction::FSub && U->getOperand(1) == &I)) {
      MulOf[U] = &I;
      Skip.insert(&I);
    }
  }

  // the body in order
  for (Instruction &I : *H) {
    if (Scaf.count(&I) || I.isTerminator() || (Skip.count(&I) && !isa<LoadInst>(&I))) continue;
    if (auto *AI = dyn_cast<IntrinsicInst>(&I)) if (AI->isAssumeLikeIntrinsic()) continue;
    {
      auto PI = Pats.find(&I);
      if (PI != Pats.end()) { if (!emitPat(&I, PI->second)) return false; continue; }
      if (auto *LdL = dyn_cast<LoadInst>(&I)) if (LazyLoad.count(LdL)) continue;
    }
    if (RedStepOf.count(&I)) {
      if (!emitReduce(&I)) return false;
      continue;
    }
    if (auto *Ld = dyn_cast<LoadInst>(&I)) {
      auto SL = SegLoads.find(Ld);
      if (SL != SegLoads.end()) {
        SegLd &G = SL->second;
        if (!Ld->isSimple()) return fail("a volatile or atomic load");
        Type *MT = Ld->getType();
        if (!laneOK(MT)) return fail("load type");
        int S;
        int64_t Stride;
        if (!memAccess(Ld, Ld->getPointerOperand(), MT, false, S, Stride, G.N)) return false;
        // the extension of every field, if there is one and it is the same for all: vlseg<F>.<m>.<lane>
        Instruction *E0 = nullptr;
        bool Z = false, ExtOk = true;
        for (auto &Fk : G.Fld) for (auto *SV : Fk) for (User *U : SV->users()) {
          auto *UI = dyn_cast<Instruction>(U);
          if (UI && (isa<ZExtInst>(UI) || isa<SExtInst>(UI)) && L->contains(UI) && (!E0 || (E0->getType() == UI->getType() && isa<ZExtInst>(E0) == isa<ZExtInst>(UI)))) { E0 = UI; Z = isa<ZExtInst>(UI); }
          else ExtOk = false;
        }
        Type *LT = MT;
        if (ExtOk && E0) LT = E0->getType();
        else E0 = nullptr;
        if (!laneOK(LT)) return fail("extended load type");
        VOp Op;
        Op.Kind = VOp::LoadSeg;
        Op.Mn = (Twine("vlseg") + Twine(G.F) + "." + memSuffix(MT, E0 && Z) + (E0 ? "." + std::string(1, laneChar(LT)) : std::string()) + " ").str();
        for (unsigned k = 0; k < G.F; ++k) {
          int V = newV(nullptr, LT);
          Op.Regs.push_back(V);
          for (auto *SV : G.Fld[k]) {
            VMap[SV] = V; VLane[SV] = LT;
            if (E0) for (User *U : SV->users()) { VMap[U] = V; VLane[U] = LT; Skip.insert(cast<Instruction>(U)); }
          }
        }
        Op.Stream = S;
        Prog.push_back(Op);
        noteUse(S);
        continue;
      }
    }
    if (auto *St = dyn_cast<StoreInst>(&I)) {
      auto SS = SegStores.find(St);
      if (SS != SegStores.end()) {
        SegSt &G = SS->second;
        if (!St->isSimple()) return fail("a volatile or atomic store");
        if (!laneOK(G.MemTy)) return fail("store type");
        int S;
        int64_t Stride;
        if (!memAccess(St, St->getPointerOperand(), St->getValueOperand()->getType(), true, S, Stride, G.N)) return false;
        VOp Op;
        Op.Kind = VOp::StoreSeg;
        Type *LT = nullptr;
        for (unsigned k = 0; k < G.F; ++k) {
          Opnd O;
          if (!operandOf(G.Src[k], O, false)) return fail("a stored field that is not a vector or an invariant scalar");
          Type *FT = (VMap.count(G.Src[k]) && VLane.count(G.Src[k]) ? VLane[G.Src[k]] : G.Src[k]->getType())->getScalarType();
          if (O.Kind == Opnd::S) {   // an invariant field: splat it into a register
            VOp M;
            M.Kind = VOp::Mov;
            M.Mn = (Twine("vmov.") + Twine(laneChar(FT)) + " ").str();
            M.Dst = newV(nullptr, FT);
            M.B = O;
            Prog.push_back(M);
            O = Opnd::v(M.Dst);
          }
          if (O.Kind != Opnd::V) return fail("a stored field that is an immediate");
          if (LT && LT != FT) return fail("the fields of a segment store have different lane types");
          LT = FT;
          Op.Regs.push_back(O.Id);
        }
        Type *MTs = G.MemTy->getScalarType();
        Op.LaneC = laneChar(LT);
        Op.Mn = (Twine("vsseg") + Twine(G.F) + "." + Twine(laneChar(LT)) + (LT != MTs ? "." + std::string(1, laneChar(MTs)) : std::string()) + " ").str();
        Op.Stream = S;
        Prog.push_back(Op);
        noteUse(S);
        continue;
      }
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
      int Mode = 0, RSh = -1;
      if (F != StoreForm.end()) { V = F->second.Src; MT = F->second.MemTy; Mode = F->second.Mode; RSh = F->second.RSh; }
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
      Type *LT = (VLane.count(V) ? VLane[V] : V->getType())->getScalarType();
      MT = MT->getScalarType();
      VOp Op;
      Op.Kind = VOp::Store;
      std::string M(1, laneChar(LT));
      const char *StB = Stride ? "vstt." : "vst.";
      if (Mode) Op.Mn = (Twine("vsts.") + M + "." + Twine(laneChar(MT)) + (Mode == 2 ? "u" : "") + " ").str();
      else if (LT != MT) Op.Mn = (Twine(StB) + M + "." + Twine(laneChar(MT)) + " ").str();
      else Op.Mn = (Twine(StB) + M + " ").str();
      Op.Stride = Stride;
      Op.A = O;
      Op.Sh = RSh;
      Op.Stream = S;
      Prog.push_back(Op);
      noteUse(S);
      continue;
    }
    if (isa<PHINode>(&I)) continue;   // a reduction: matched before the body (its steps become Reduce operations where they appear in the body)
    // compare, select, mask, conversion (wave 2)
    if (auto *Cmp = dyn_cast<CmpInst>(&I)) {
      if (Cmp->hasOneUse())   // the condition of a reduction's select: handled with the select
        if (auto *Sl = dyn_cast<SelectInst>(*Cmp->user_begin())) if (RedStepOf.count(Sl)) continue;
      if (!emitCmp(Cmp)) return false;
      continue;
    }
    if (auto *Sl = dyn_cast<SelectInst>(&I)) {
      if (!emitSelect(Sl)) return false;
      continue;
    }
    if (isa<SIToFPInst>(&I) || isa<UIToFPInst>(&I) || isa<FPToSIInst>(&I) || isa<FPToUIInst>(&I)) {
      if (!emitConv(cast<CastInst>(&I))) return false;
      continue;
    }
    if (isa<ZExtInst>(&I) || isa<SExtInst>(&I)) {
      if (I.getOperand(0)->getType()->getScalarType()->isIntegerTy(1)) {   // a mask as a value: sext is the mask, zext is the mask and 1
        Opnd M;
        bool Z = isa<ZExtInst>(&I);
        if (!maskOperand(I.getOperand(0), false, M)) return false;
        Type *MT = VLane[I.getOperand(0)];
        if (Z) {
          int D = emitLane("vand", laneChar(MT), M, Opnd::i(1), MT, &I);
          (void)D;
        } else { VMap[&I] = M.Id; VLane[&I] = MT; }
        continue;
      }
    }
    if (auto *Tr = dyn_cast<TruncInst>(&I)) {   // a value that the idiom of a narrow lane made: already of the narrow lane type
      auto It = VMap.find(Tr->getOperand(0));
      if (It != VMap.end() && VLane.count(Tr->getOperand(0)) && laneChar(VLane[Tr->getOperand(0)]) == laneChar(Tr->getType())) {
        VMap[Tr] = It->second; VLane[Tr] = VLane[Tr->getOperand(0)];
        continue;
      }
      return fail("a truncation of a computed value");
    }
    if (auto *Bi = dyn_cast<BinaryOperator>(&I)) {   // and, or, xor of masks
      if (Bi->getType()->getScalarType()->isIntegerTy(1)) {
        unsigned Opc = Bi->getOpcode();
        if (Opc != Instruction::And && Opc != Instruction::Or && Opc != Instruction::Xor) return fail("an operation on masks");
        Value *A0 = Bi->getOperand(0), *B0 = Bi->getOperand(1);
        auto *CB = constInt(B0);
        if (Opc == Instruction::Xor && CB && CB->isOne() && VMap.count(A0) && VLane.count(A0)) {   // the negation of a mask: a flag, no instruction
          VMap[Bi] = VMap[A0]; VLane[Bi] = VLane[A0]; MaskInv[Bi] = !MaskInv.lookup(A0);
          continue;
        }
        Opnd MA, MB;
        if (!maskOperand(A0, false, MA) || !maskOperand(B0, false, MB)) return false;
        if (VLane[A0] != VLane[B0]) return fail("masks of different lane sizes");
        Type *MT = VLane[A0];
        emitLane(Opc == Instruction::And ? "vand" : Opc == Instruction::Or ? "vor" : "vxor", laneChar(MT), MA, MB, MT, Bi);
        MaskInv[Bi] = false;
        continue;
      }
    }
    // lane operations
    if (auto *Bin = dyn_cast<BinaryOperator>(&I)) {
      Type *T = Bin->getType()->getScalarType();
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
        Op.Mn = (Twine(Bin->getOpcode() == Instruction::FSub ? "vfnma." : T->isFloatingPointTy() ? "vfma." : "vmla.") + Twine(laneChar(T)) + " ").str();
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
      Type *T = II->getType()->getScalarType();
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
      case Intrinsic::fshl: case Intrinsic::fshr: {   // a rotate by a constant (both inputs the same value): vshl, vshr, vor
        if (II->getArgOperand(0) != II->getArgOperand(1) || T->isFloatingPointTy() || !laneOK(T)) return fail("a funnel shift that is not a rotate");
        auto *C = constInt(II->getArgOperand(2));
        unsigned W = T->getScalarSizeInBits();
        if (!C) return fail("a rotate by a variable amount");
        unsigned Sh = C->getZExtValue() % W;
        if (II->getIntrinsicID() == Intrinsic::fshr) Sh = (W - Sh) % W;   // a rotate right by c is a rotate left by W - c
        Opnd OA;
        if (!operandOf(II->getArgOperand(0), OA, false) || OA.Kind != Opnd::V) return fail("operand");
        VOp A1, A2, A3;
        A1.Kind = A2.Kind = A3.Kind = VOp::Lane;
        A1.Mn = (Twine("vshl.") + Twine(laneChar(T)) + " ").str(); A1.A = OA; A1.B = Opnd::i(Sh); A1.Dst = newV(nullptr, T);
        A2.Mn = (Twine("vshr.") + Twine(laneChar(T)) + " ").str(); A2.A = OA; A2.B = Opnd::i(W - Sh); A2.Dst = newV(nullptr, T);
        A3.Mn = (Twine("vor.") + Twine(laneChar(T)) + " ").str(); A3.A = Opnd::v(A1.Dst); A3.B = Opnd::v(A2.Dst); A3.Dst = newV(II, T);
        if (Sh == 0) return fail("a rotate by zero");
        Prog.push_back(A1); Prog.push_back(A2); Prog.push_back(A3);
        break;
      }
      case Intrinsic::maxnum: case Intrinsic::minnum: {   // vmax.f / vmin.f: with nnan only (the reduction patterns of fast-math code)
        if (!T->isFloatingPointTy() || !II->hasNoNaNs()) return fail("fmax/fmin without nnan");
        const char *Base = II->getIntrinsicID() == Intrinsic::maxnum ? "vmax" : "vmin";
        Value *A0 = II->getArgOperand(0), *B0 = II->getArgOperand(1);
        if (!VMap.count(A0)) std::swap(A0, B0);
        Opnd OA, OB;
        if (!operandOf(A0, OA, false) || OA.Kind != Opnd::V || !operandOf(B0, OB, false)) return fail("operand");
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
    if (auto *IE = dyn_cast<InsertElementInst>(&I)) {   // the first half of a splat of a loop-invariant scalar (LoopVectorize makes them in the loop when it hoists nothing)
      auto *Idx = dyn_cast<ConstantInt>(IE->getOperand(2));
      Value *Sc = IE->getOperand(1);
      if (Idx && Idx->isZero() && (isa<PoisonValue>(IE->getOperand(0)) || isa<UndefValue>(IE->getOperand(0))) && (!inLoop(Sc) || InvSet.count(Sc))) {
        SplatInfo[IE] = Sc;
        continue;
      }
      return fail("an insertelement that is not a splat of an invariant");
    }
    if (auto *SV = dyn_cast<ShuffleVectorInst>(&I)) {
      auto It = SplatInfo.find(SV->getOperand(0));
      if (It != SplatInfo.end() && SV->isZeroEltSplat()) { SplatInfo[SV] = It->second; continue; }
      return fail("a shuffle that is not the splat of an invariant (no instruction permutes lanes)");
    }
    if (isa<ZExtInst>(&I) || isa<SExtInst>(&I)) {
      // the operand of a reduction (vacc widens)
      bool Ok = I.hasOneUse() && isa<BinaryOperator>(*I.user_begin());
      if ((isa<SExtInst>(&I) || isa<ZExtInst>(&I)) && Ok && VMap.count(I.getOperand(0))) continue;
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

static bool inLoopVal(Loop *L, Value *V) { auto *I = dyn_cast<Instruction>(V); return I && L->contains(I); }

// ---- the pass -----------------------------------------------------------------------------------------------
class PDP64VecLoop : public FunctionPass {
public:
  static char ID;
  PDP64VecLoop() : FunctionPass(ID) {}
  StringRef getPassName() const override { return "PDP64 loop to vec block"; }
  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.addRequired<LoopInfoWrapperPass>();
    AU.addRequired<ScalarEvolutionWrapperPass>();
    AU.addRequired<DominatorTreeWrapperPass>();
    AU.addRequiredID(LoopSimplifyID);
    AU.addRequiredID(LCSSAID);
  }
  bool runOnFunction(Function &F) override;

private:
  bool transform(Loop *L, ScalarEvolution &SE, LoopInfo &LI, DominatorTree &DT, Function &F);
};
} // namespace

char PDP64VecLoop::ID = 0;
INITIALIZE_PASS_BEGIN(PDP64VecLoop, "pdp64-vecloop-pass", "PDP64 loop to vec block", false, false)
INITIALIZE_PASS_DEPENDENCY(LoopInfoWrapperPass)
INITIALIZE_PASS_DEPENDENCY(ScalarEvolutionWrapperPass)
INITIALIZE_PASS_DEPENDENCY(DominatorTreeWrapperPass)
INITIALIZE_PASS_DEPENDENCY(LoopSimplify)
INITIALIZE_PASS_DEPENDENCY(LCSSAWrapperPass)
INITIALIZE_PASS_END(PDP64VecLoop, "pdp64-vecloop-pass", "PDP64 loop to vec block", false, false)
FunctionPass *llvm::createPDP64VecLoop() { return new PDP64VecLoop(); }

bool PDP64VecLoop::runOnFunction(Function &F) {
  if ((!EnableVecLoop && !EnableVecBlock) || skipFunction(F))
    return false;
  DominatorTree &DT = getAnalysis<DominatorTreeWrapperPass>().getDomTree();
  LoopInfo &LI = getAnalysis<LoopInfoWrapperPass>().getLoopInfo();
  ScalarEvolution &SE = getAnalysis<ScalarEvolutionWrapperPass>().getSE();
  SmallVector<Loop *, 8> Inner;
  for (Loop *L : LI.getLoopsInPreorder())
    if (L->isInnermost())
      Inner.push_back(L);
  bool Changed = false;
  for (Loop *L : Inner)
    Changed |= transform(L, SE, LI, DT, F);
  if (Changed)
    removeUnreachableBlocks(F);
  return Changed;
}

bool PDP64VecLoop::transform(Loop *L, ScalarEvolution &SE, LoopInfo &LI, DominatorTree &DT, Function &F) {
  const DataLayout &DL = F.getDataLayout();
  auto Say = [&](const Twine &W) {
    if (VecLoopVerbose)
      errs() << "pdp64-vecloop: " << F.getName() << ": loop at " << L->getHeader()->getName() << ": " << W << "\n";
  };
  Say("considering");
  if (L->getBlocks().size() != 1 || !L->getLoopPreheader() || !L->getExitBlock() || !L->getLoopLatch() || L->getLoopLatch() != L->getHeader()) {
    Say("not a single-block loop with a preheader and one exit");
    return false;
  }
  BasicBlock *H = L->getHeader(), *P = L->getLoopPreheader(), *Exit = L->getExitBlock();
  if (!isa<BranchInst>(P->getTerminator()) || cast<BranchInst>(P->getTerminator())->isConditional()) {
    Say("the preheader does not end in a plain branch");
    return false;
  }
  bool IsVec = false;   // a loop that LoopVectorize made: its body has vector values
  for (Instruction &I : *H) {
    if (I.getType()->isVectorTy()) IsVec = true;
    if (auto *St = dyn_cast<StoreInst>(&I)) if (St->getValueOperand()->getType()->isVectorTy()) IsVec = true;
  }
  if (IsVec ? !EnableVecBlock : !EnableVecLoop) return false;
  const SCEV *BTC = SE.getBackedgeTakenCount(L);
  if (!IsVec && isa<SCEVCouldNotCompute>(BTC)) {
    Say("the trip count is not computable");
    return false;
  }
  Analyzer A(L, SE, DL);
  if (!A.run()) {
    Say("not a vec block: " + A.Why);
    return false;
  }

  // ---- a vector loop: the shape LoopVectorize leaves around it (vector.ph, middle.block, scalar.ph) and what becomes of it
  //   pred -> vector.ph -> vector.body -> middle.block --(n.vec == TC)--> exit
  //     \_______________________________________\--------> scalar.ph -> epilogue loop -> exit
  // The block covers all TC elements, so middle.block always goes to the exit and the epilogue is reached only when a test fails.
  BasicBlock *MB = nullptr, *XB = nullptr, *ScalarPh = nullptr, *PredB = nullptr;
  Value *TCV = nullptr;
  struct RedResT { PHINode *Lcssa; int Acc; SmallVector<IntrinsicInst *, 2> Calls; };
  SmallVector<RedResT, 2> RedRes;
  SmallVector<BasicBlock *, 4> MinIters;
  SmallVector<Value *, 4> Mirror;
  bool FallbackOK = false;
  if (A.Vec) {
    MB = Exit;
    if (MB->getSinglePredecessor() != H) { Say("not a vec block: the vector loop's exit has other predecessors"); return false; }
    auto *MBBr = dyn_cast<BranchInst>(MB->getTerminator());
    if (!MBBr) { Say("not a vec block: the exit of the vector loop does not end in a branch"); return false; }
    // a constant trip count: the vector loop covers it exactly (or leaves a remainder to the loop that follows, which stays as it is), and the exit of the loop
    // need not be LoopVectorize's middle.block (with a constant count that is a multiple of VF the vector loop is followed directly by whatever came after the
    // original loop, e.g. the latch of an outer loop: no cmp.n at all)
    bool ConstTC = isa<SCEVConstant>(BTC);
    bool CmpN = false;
    if (MBBr->isConditional()) {
      BasicBlock *X0 = MBBr->getSuccessor(0), *S0 = MBBr->getSuccessor(1);
      auto *Cmp = dyn_cast<ICmpInst>(MBBr->getCondition());
      auto *LBr = cast<BranchInst>(H->getTerminator());
      auto *LC = LBr->isConditional() ? dyn_cast<ICmpInst>(LBr->getCondition()) : nullptr;
      std::string Bad;
      if (!Cmp || Cmp->getPredicate() != ICmpInst::ICMP_EQ || !LC) Bad = "middle.block does not compare the trip count";
      else {
        Value *NVec = inLoopVal(L, LC->getOperand(0)) ? LC->getOperand(1) : LC->getOperand(0);
        if (Cmp->getOperand(0) == NVec) TCV = Cmp->getOperand(1);
        else if (Cmp->getOperand(1) == NVec) TCV = Cmp->getOperand(0);
        else Bad = "middle.block compares something other than n.vec";
        if (Bad.empty() && !TCV->getType()->isIntegerTy()) Bad = "trip count type";
        if (Bad.empty())
          if (auto *TI = dyn_cast<Instruction>(TCV))
            if (!DT.dominates(TI, P->getTerminator())) Bad = "the trip count is not available before the vector loop";
      }
      if (Bad.empty()) { XB = X0; ScalarPh = S0; CmpN = true; }
      else if (!ConstTC) { Say("not a vec block: " + Bad); return false; }
      else TCV = nullptr;
    }
    if (!CmpN) {
      if (!MBBr->isConditional()) XB = MBBr->getSuccessor(0);   // no remainder: the trip count is a multiple of VF, known
      if (isa<SCEVCouldNotCompute>(BTC)) { Say("not a vec block: trip count"); return false; }
    }
    // the reductions' results: lcssa phis in middle.block whose only users are the llvm.vector.reduce calls of the same kind
    for (PHINode &Ph : MB->phis()) {
      Value *V = Ph.getIncomingValueForBlock(H);
      auto *VI = dyn_cast<Instruction>(V);
      if (!VI || !L->contains(VI)) continue;
      int Ai = -1;
      for (unsigned a = 0; a < A.Accs.size(); ++a) if (A.Accs[a].Next == VI) Ai = a;
      if (Ai < 0) { Say("not a vec block: a value of the vector loop is used after it (not a reduction)"); return false; }
      Acc &Ac = A.Accs[Ai];
      RedResT R; R.Lcssa = &Ph; R.Acc = Ai;
      for (User *U : Ph.users()) {
        auto *C = dyn_cast<IntrinsicInst>(U);
        bool Ok = false;
        if (C) switch (C->getIntrinsicID()) {
          case Intrinsic::vector_reduce_add: Ok = !Ac.IsFP && Ac.Base == StringRef("vacc"); break;
          case Intrinsic::vector_reduce_fadd: Ok = Ac.IsFP && Ac.Base == StringRef("vacc") && C->hasAllowReassoc(); break;
          case Intrinsic::vector_reduce_smax: Ok = !Ac.IsFP && !Ac.Uns && Ac.Base == StringRef("vmaxacc"); break;
          case Intrinsic::vector_reduce_smin: Ok = !Ac.IsFP && !Ac.Uns && Ac.Base == StringRef("vminacc"); break;
          case Intrinsic::vector_reduce_umax: Ok = !Ac.IsFP && Ac.Uns && Ac.Base == StringRef("vmaxacc"); break;
          case Intrinsic::vector_reduce_umin: Ok = !Ac.IsFP && Ac.Uns && Ac.Base == StringRef("vminacc"); break;
          case Intrinsic::vector_reduce_fmax: Ok = Ac.IsFP && Ac.Base == StringRef("vmaxacc") && C->hasNoNaNs(); break;
          case Intrinsic::vector_reduce_fmin: Ok = Ac.IsFP && Ac.Base == StringRef("vminacc") && C->hasNoNaNs(); break;
          default: break;
        }
        if (!Ok) { Say("not a vec block: a reduction result is used by something other than the matching llvm.vector.reduce"); return false; }
        R.Calls.push_back(C);
      }
      RedRes.push_back(R);
    }
    for (unsigned a = 0; a < A.Accs.size(); ++a) {   // every reduction must have its result
      bool Has = false;
      for (auto &R : RedRes) if (R.Acc == (int)a) Has = true;
      if (!Has && !A.Accs[a].Next->use_empty()) { Say("not a vec block: a reduction whose result is not reduced"); return false; }
    }
    // the way into the scalar loop for the case that a test fails: the predecessor of vector.ph, which branches to both
    PredB = P->getSinglePredecessor();
    if (ScalarPh && PredB)
      if (auto *PBr = dyn_cast<BranchInst>(PredB->getTerminator()))
        if (PBr->isConditional() && is_contained(successors(PredB), ScalarPh) && is_contained(successors(PredB), P)) FallbackOK = true;
    if (ScalarPh) {
      // the minimum-iterations test(s) of LoopVectorize: the block takes any count, so they are not needed
      for (BasicBlock *B = PredB; B && MinIters.size() < 4; B = B->getSinglePredecessor()) {
        auto *Br = dyn_cast<BranchInst>(B->getTerminator());
        if (!Br || !Br->isConditional() || !is_contained(successors(B), ScalarPh)) break;
        if (Br->getCondition()->getName().starts_with("min.iters.check")) MinIters.push_back(B);
      }
    }
  }

  // the exit block's phis: what each incoming value from the loop becomes
  if (!A.Vec) for (PHINode &Ph : Exit->phis()) {
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
          // a load AHEAD of a store (its address is higher by a whole number of elements): a write-after-read dependence, which "every load of a strip before its
          // stores, strips in order" keeps (a[i] = a[i + 1] + 1); a load behind the store would be a read-after-write inside one strip
          if (X.Store != Y.Store && X.ElemStep > 0) {
            int64_t Dist = X.Store ? -D : D;   // load - store
            if (Dist > 0 && Dist % X.ElemStep == 0) continue;
          }
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
      if (!Dup) Checks.push_back({X.P, X.Inv ? X.Size : X.ElemStep, X.Inv, Y.P, Y.Inv ? Y.Size : Y.ElemStep, Y.Inv});
    }
  if (Checks.size() > VecLoopMaxChecks) { Say("not a vec block: too many overlap tests"); return false; }
  if (A.Vec && !Checks.empty()) {
    // LoopVectorize's own run-time check (vector.memcheck) compares the ranges of the whole trip count, remainder included: the same test
    for (BasicBlock *B = PredB; B; B = B->getSinglePredecessor())
      if (B->getName().starts_with("vector.memcheck")) { Checks.clear(); break; }
  }
  if (A.Vec && !Checks.empty() && !FallbackOK) { Say("not a vec block: an overlap test is needed and there is no way to the scalar loop"); return false; }

  // as64 has no `vldt.<t> vD, d(Ra), #stride` / `vstt` without the move: a strided stream can only be one instruction with (Ra)+ (llvm/README.md: assembler limit)
  for (unsigned i = 0; i < A.Prog.size(); ++i)
    if ((A.Prog[i].Kind == VOp::Load || A.Prog[i].Kind == VOp::Store) && A.Prog[i].Stride && A.Streams[A.Prog[i].Stream].LastUse != (int)i) {
      Say("not a vec block: a strided stream used by more than one instruction (as64 has no vldt/vstt with an offset and no move)");
      return false;
    }

  // ---- the vector registers: a linear scan over the body
  int NV = A.NextV;
  SmallVector<int, 32> LastUse(NV, -1);
  SmallVector<int, 32> Def(NV, -1);
  for (unsigned i = 0; i < A.Prog.size(); ++i) {
    VOp &Op = A.Prog[i];
    if (Op.Dst >= 0) Def[Op.Dst] = i;
    if (Op.Kind == VOp::LoadSeg) for (int R : Op.Regs) Def[R] = i;
    if (Op.Kind == VOp::StoreSeg) for (int R : Op.Regs) LastUse[R] = i;
    if (Op.A.Kind == Opnd::V) LastUse[Op.A.Id] = i;
    if (Op.B.Kind == Opnd::V) LastUse[Op.B.Id] = i;
    if (Op.C.Kind == Opnd::V) LastUse[Op.C.Id] = i;
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
      T = Op.Mn + Rn(Op.A.Id) + ", " + (S.LastUse == (int)i ? "(" + PtrOp(Op.Stream) + ")+" : "0(" + PtrOp(Op.Stream) + ")") + (Op.Stride ? ", #" + std::to_string(Op.Stride) : "") +
          (Op.Sh >= 0 ? ", #" + std::to_string(Op.Sh) : "");
      ReleaseDead(i, Op.A.Id);
      break;
    }
    case VOp::LoadSeg: {   // F consecutive registers for the fields
      int F = Op.Regs.size(), Base = -1;
      for (int r = 0; r + F <= 16 && Base < 0; ++r) {
        bool Ok = true;
        for (int k = 0; k < F; ++k) if (!Free[r + k]) Ok = false;
        if (Ok) Base = r;
      }
      if (Base < 0) { Say("not a vec block: no consecutive vector registers for a segment load"); return false; }
      for (int k = 0; k < F; ++k) { Free[Base + k] = false; Reg[Op.Regs[k]] = Base + k; }
      Stream &S = A.Streams[Op.Stream];
      T = Op.Mn + Rn(Op.Regs[0]) + ", " + (S.LastUse == (int)i ? "(" + PtrOp(Op.Stream) + ")+" : "0(" + PtrOp(Op.Stream) + ")");
      break;
    }
    case VOp::StoreSeg: {   // the fields are already in consecutive registers, or are copied into F that are
      int F = Op.Regs.size();
      bool Direct = true;
      for (int k = 0; k < F; ++k) {
        if (Reg[Op.Regs[k]] != Reg[Op.Regs[0]] + k) Direct = false;
        for (int j = 0; j < k; ++j) if (Op.Regs[j] == Op.Regs[k]) Direct = false;   // the same register twice
      }
      std::string First;
      int Tmp = -1;
      if (Direct) First = Rn(Op.Regs[0]);
      else {
        for (int r = 0; r + F <= 16 && Tmp < 0; ++r) {
          bool Ok = true;
          for (int k = 0; k < F; ++k) if (!Free[r + k]) Ok = false;
          if (Ok) Tmp = r;
        }
        if (Tmp < 0) { Say("not a vec block: no consecutive vector registers for a segment store"); return false; }
        for (int k = 0; k < F; ++k) {
          Free[Tmp + k] = false;
          Lines.push_back(std::string("vmov.") + Op.LaneC + " v" + std::to_string(Tmp + k) + ", " + Rn(Op.Regs[k]));
        }
        First = "v" + std::to_string(Tmp);
      }
      Stream &S = A.Streams[Op.Stream];
      T = Op.Mn + First + ", " + (S.LastUse == (int)i ? "(" + PtrOp(Op.Stream) + ")+" : "0(" + PtrOp(Op.Stream) + ")");
      if (Tmp >= 0) for (int k = 0; k < F; ++k) Free[Tmp + k] = true;
      for (int k = 0; k < F; ++k) ReleaseDead(i, Op.Regs[k]);
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
      bool Unary = Op.Mn.rfind("vneg", 0) == 0 || Op.Mn.rfind("vcvt", 0) == 0;
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
      T = Op.Mn + AccOp(Op.Acc) + ", " + Rn(Op.A.Id) + (Op.B.Kind == Opnd::V ? ", " + Rn(Op.B.Id) : "");
      ReleaseDead(i, Op.A.Id);
      if (Op.B.Kind == Opnd::V && Op.B.Id != Op.A.Id) ReleaseDead(i, Op.B.Id);
      break;
    }
    case VOp::Bsl: {   // vbsl vD, vM, vA, vB: the destination may be any of the three (all are read first)
      std::string Sm = Src(Op.C), Sa = Src(Op.A), Sb = Src(Op.B);
      ReleaseDead(i, Op.C.Id);
      if (Op.A.Kind == Opnd::V && Op.A.Id != Op.C.Id) ReleaseDead(i, Op.A.Id);
      if (Op.B.Kind == Opnd::V && Op.B.Id != Op.C.Id && Op.B.Id != Op.A.Id) ReleaseDead(i, Op.B.Id);
      int D = Alloc();
      if (D < 0) { Say("not a vec block: more than 16 vector registers"); return false; }
      Reg[Op.Dst] = D;
      T = Op.Mn + Rn(Op.Dst) + ", " + Sm + ", " + Sa + ", " + Sb;
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
  Value *TripV;
  if (A.Vec && TCV) {
    TripV = B.CreateZExtOrTrunc(TCV, I64);   // elements: the whole count of the original loop, remainder included
  } else {
    const SCEV *Trip = SE.getAddExpr(SE.getTruncateOrZeroExtend(BTC, I64), SE.getOne(I64));
    if (A.Vec) Trip = SE.getMulExpr(Trip, SE.getConstant(I64, A.Lanes));   // vector iterations times lanes
    if (!Exp.isSafeToExpandAt(Trip, IP)) { Say("cannot expand the trip count"); return false; }
    TripV = Exp.expandCodeFor(Trip, I64, IP);
  }
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
    if (A.Vec) {
      // the start of the vector accumulator is a vector (the start value in one lane, the identity in the others, or a splat): the scalar start is its reduction
      Value *Sp = getSplatValue(Init);
      bool IsAdd = Ac.Base == StringRef("vacc");
      Value *Sc = nullptr;
      if (Sp && !IsAdd) Sc = Sp;
      else if (Sp && (match(Sp, m_Zero()) || match(Sp, m_AnyZeroFP()))) Sc = Ac.IsFP ? (Value *)ConstantFP::getZero(Ac.Ty, true) : ConstantInt::get(Ac.Ty, 0);
      else if (auto *IE = dyn_cast<InsertElementInst>(Init)) {
        Value *BaseV = IE->getOperand(0);
        auto *Idx = dyn_cast<ConstantInt>(IE->getOperand(2));
        Value *BS = getSplatValue(BaseV);
        if (Idx && Idx->isZero() && BS && IsAdd && (match(BS, m_Zero()) || match(BS, m_AnyZeroFP()))) Sc = IE->getOperand(1);
        else if (Idx && Idx->isZero() && !IsAdd && BS && BS == IE->getOperand(1)) Sc = BS;
      }
      if (!Sc) {
        Intrinsic::ID RID;
        if (IsAdd) RID = Ac.IsFP ? Intrinsic::vector_reduce_fadd : Intrinsic::vector_reduce_add;
        else if (Ac.Base == StringRef("vmaxacc")) RID = Ac.IsFP ? Intrinsic::vector_reduce_fmax : Ac.Uns ? Intrinsic::vector_reduce_umax : Intrinsic::vector_reduce_smax;
        else RID = Ac.IsFP ? Intrinsic::vector_reduce_fmin : Ac.Uns ? Intrinsic::vector_reduce_umin : Intrinsic::vector_reduce_smin;
        if (RID == Intrinsic::vector_reduce_fadd) {
          FastMathFlags FMF; FMF.setFast();
          IRBuilder<>::FastMathFlagGuard G(B); B.setFastMathFlags(FMF);
          Sc = B.CreateIntrinsic(RID, {Init->getType()}, {ConstantFP::getZero(Ac.Ty, true), Init});
        } else {
          Sc = B.CreateIntrinsic(RID, {Init->getType()}, {Init});
          if (Ac.IsFP) cast<Instruction>(Sc)->setFastMathFlags([] { FastMathFlags F; F.setNoNaNs(); return F; }());
        }
      }
      Init = Sc;
    }
    Value *V = Ac.IsFP ? Init : (Ac.Uns ? B.CreateZExtOrTrunc(Init, I64) : B.CreateSExtOrTrunc(Init, I64));
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
  if (!VecLoopStrip || A.Vec) {
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
  if (!A.Vec) for (PHINode &Ph : Exit->phis()) {
    Value *V = Ph.getIncomingValueForBlock(H);
    Value *N = V;
    if (auto *I = dyn_cast<Instruction>(V))
      for (int a = 0; a < NAcc; ++a)
        if (A.Accs[a].Next == I) N = AccRes[a];
    Ph.addIncoming(N, VJoin);
  }
  if (A.Vec) {
    // middle.block: the llvm.vector.reduce of each accumulator is the block's scalar result; the other phis (values from before the loop) come from the block
    SmallVector<PHINode *, 2> Dead;
    for (PHINode &Ph : MB->phis()) {
      RedResT *RR = nullptr;
      for (auto &R : RedRes) if (R.Lcssa == &Ph) RR = &R;
      if (!RR) { Ph.addIncoming(Ph.getIncomingValueForBlock(H), VJoin); continue; }
      Value *Res = AccRes[RR->Acc];
      for (IntrinsicInst *C : RR->Calls) {
        Value *R = Res;
        if (C->getIntrinsicID() == Intrinsic::vector_reduce_fadd) {
          Value *Start = C->getArgOperand(0);
          if (!match(Start, m_AnyZeroFP())) {
            IRBuilder<> CB(C);
            CB.setFastMathFlags(C->getFastMathFlags());
            R = CB.CreateFAdd(Start, Res);
          }
        }
        C->replaceAllUsesWith(R);
        C->eraseFromParent();
      }
      Dead.push_back(&Ph);
    }
    for (PHINode *Ph : Dead) { Ph->replaceAllUsesWith(PoisonValue::get(Ph->getType())); Ph->eraseFromParent(); }
    // middle.block no longer goes to the scalar loop: the whole range is done
    if (ScalarPh && FallbackOK)
      for (PHINode &Ph : ScalarPh->phis()) Mirror.push_back(Ph.getIncomingValueForBlock(PredB));
    if (ScalarPh) {
      auto *MBBr = cast<BranchInst>(MB->getTerminator());
      BranchInst::Create(XB, MBBr->getIterator());
      ScalarPh->removePredecessor(MB);
      MBBr->eraseFromParent();
      for (BasicBlock *MI : MinIters) {   // no minimum count: the block takes 0 elements and up
        auto *Br = cast<BranchInst>(MI->getTerminator());
        BasicBlock *Next = Br->getSuccessor(0) == ScalarPh ? Br->getSuccessor(1) : Br->getSuccessor(0);
        BranchInst::Create(Next, Br->getIterator());
        ScalarPh->removePredecessor(MI);
        Br->eraseFromParent();
      }
    }
  }
  // the test: the block if the streams do not overlap (always, if no test is needed), else the scalar loop
  B.SetInsertPoint(P->getTerminator());
  if (Ok && A.Vec) {
    // the overlap test failed: the scalar loop, with the values the other bypasses of LoopVectorize give it
    unsigned MI = 0;
    for (PHINode &Ph : ScalarPh->phis()) Ph.addIncoming(Mirror[MI++], P);
    B.CreateCondBr(Ok, VB, ScalarPh);
    ++NumVersioned;
  } else if (Ok) {
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
