//===-- PDP64CheckFold.cpp - conditional branch to a trap -> a check ------===//
//
// After instruction selection, before register allocation: a conditional
// branch `cbCC a, b, fail` (or the same with the other arm falling into the
// failure block) whose failure block holds nothing but a trap becomes ONE
// check instruction `ctCC a, b` (cteq / ctne for a test against zero), with no
// branch and no failure block.  The condition of ctCC is the condition of
// cbCC: it traps when the branch would have been taken.  When the trap is the
// fall-through arm, the condition is inverted.  Two checks in a row on one
// value, `x < lo` and `x >= hi`, are one `chk2 x, lo, hi`.
//
// The kind of the table of check sites comes from the argument of
// llvm.ubsantrap (PDP64::checkKindOfUbsan); a plain llvm.trap has kind 0 and
// the kind is then guessed from the form of the compare (unsigned: bounds,
// against zero: null, else assertion).  The file and line come from the debug
// location of the trap, else of the branch (AsmPrinter).
//
// A check is a fault with EPC at the instruction (precise, restartable), so
// the check stays where the branch was: nothing is moved across it (the
// instruction has side effects as far as scheduling is concerned).
//===----------------------------------------------------------------------===//
#include "PDP64.h"
#include "PDP64InstrInfo.h"
#include "PDP64Subtarget.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/Support/CommandLine.h"

using namespace llvm;

#define DEBUG_TYPE "pdp64-check-fold"

static cl::opt<bool> FoldChecks("pdp64-fold-checks",
    cl::desc("pdp64: turn a conditional branch to a block that only traps into a check instruction"),
    cl::init(true), cl::Hidden);

STATISTIC(NumCT, "checks made from a compare-and-branch to a trap");
STATISTIC(NumChk2, "pairs of checks made into chk2");

namespace {
class PDP64CheckFold : public MachineFunctionPass {
public:
  static char ID;
  PDP64CheckFold() : MachineFunctionPass(ID) {}
  StringRef getPassName() const override { return "PDP64 check fold"; }
  bool runOnMachineFunction(MachineFunction &MF) override;

private:
  const PDP64InstrInfo *TII = nullptr;
  MachineRegisterInfo *MRI = nullptr;
  static bool isTrapBlock(const MachineBasicBlock *MBB) {
    unsigned N = 0;
    bool Trap = false;
    for (const MachineInstr &MI : *MBB) {
      if (MI.isDebugInstr())
        continue;
      ++N;
      Trap = MI.getOpcode() == PDP64::TRAPCHK;
    }
    return N == 1 && Trap;
  }
  static MachineInstr *trapOf(MachineBasicBlock *MBB) {
    for (MachineInstr &MI : *MBB)
      if (MI.getOpcode() == PDP64::TRAPCHK)
        return &MI;
    return nullptr;
  }
  bool foldBranch(MachineBasicBlock &B, SmallVectorImpl<MachineBasicBlock *> &Dead);
  bool foldChk2(MachineBasicBlock &B);
};
} // namespace

char PDP64CheckFold::ID = 0;
INITIALIZE_PASS(PDP64CheckFold, DEBUG_TYPE, "PDP64 check fold", false, false)
FunctionPass *llvm::createPDP64CheckFold() { return new PDP64CheckFold(); }

static bool isCtImmCond(unsigned CC) {
  switch (CC) {
#define X(c) case PDP64CC::COND_##c:
    PDP64_CT_IMM_CONDS(X)
#undef X
    return true;
  default:
    return false;
  }
}
static bool isCtCond(unsigned CC) {
  switch (CC) {
#define X(c) case PDP64CC::COND_##c:
    PDP64_CT_CONDS(X)
#undef X
    return true;
  default:
    return false;
  }
}

static unsigned guessKind(unsigned CC, bool ZeroCmp) {
  if (ZeroCmp && (CC == PDP64CC::COND_eq || CC == PDP64CC::COND_ne))
    return 2; // null
  switch (CC) {
  case PDP64CC::COND_cs: case PDP64CC::COND_cc:
  case PDP64CC::COND_hi: case PDP64CC::COND_los:
    return 1; // an unsigned compare: bounds
  default:
    return 4; // assertion
  }
}

bool PDP64CheckFold::foldBranch(MachineBasicBlock &B,
                                SmallVectorImpl<MachineBasicBlock *> &Dead) {
  MachineBasicBlock *TBB = nullptr, *FBB = nullptr;
  SmallVector<MachineOperand, 4> Cond;
  if (TII->analyzeBranch(B, TBB, FBB, Cond, false) || Cond.empty() || !TBB)
    return false;
  MachineBasicBlock *Fall = FBB ? FBB : B.getNextNode();
  if (!Fall || Fall == TBB)
    return false;
  MachineInstr *CB = nullptr;
  for (MachineInstr &MI : llvm::reverse(B))
    if (MI.getOpcode() == PDP64::CB_rr || MI.getOpcode() == PDP64::CB_ri) {
      CB = &MI;
      break;
    }
  if (!CB)
    return false;
  unsigned CC = CB->getOperand(2).getImm();
  MachineBasicBlock *Fail, *Ok;
  if (isTrapBlock(TBB) && !isTrapBlock(Fall)) {
    Fail = TBB; Ok = Fall;
  } else if (isTrapBlock(Fall) && !isTrapBlock(TBB)) {
    Fail = Fall; Ok = TBB;
    PDP64CC::CondCode Inv = PDP64CC::invert((PDP64CC::CondCode)CC);
    if (Inv == PDP64CC::COND_INVALID)
      return false;
    CC = Inv;
  } else
    return false;
  if (!isCtCond(CC))
    return false;

  MachineInstr *Trap = trapOf(Fail);
  DebugLoc DL = Trap->getDebugLoc() ? Trap->getDebugLoc() : CB->getDebugLoc();
  unsigned Kind = Trap->getOperand(0).getImm();
  Register A = CB->getOperand(0).getReg();
  const MachineOperand &Rhs = CB->getOperand(1);
  bool ZeroCmp = Rhs.isImm() && Rhs.getImm() == 0;
  if (!Kind)
    Kind = guessKind(CC, ZeroCmp);

  // the check goes where the branch was; its operands are what the branch read
  TII->removeBranch(B);
  auto Ins = B.end();
  if (Rhs.isReg()) {
    BuildMI(B, Ins, DL, TII->get(PDP64::CT_rr)).addReg(A).addReg(Rhs.getReg()).addImm(CC).addImm(Kind);
  } else {
    int64_t I = Rhs.getImm();
    if (I == 0 && (CC == PDP64CC::COND_eq || CC == PDP64CC::COND_ne))
      BuildMI(B, Ins, DL, TII->get(PDP64::CT_z)).addReg(A).addImm(CC).addImm(Kind);
    else if (I >= 0 && I < (1 << PDP64Layout::CtImmBits) && isCtImmCond(CC))
      BuildMI(B, Ins, DL, TII->get(PDP64::CT_ri)).addReg(A).addImm(I).addImm(CC).addImm(Kind);
    else {
      Register T = MRI->createVirtualRegister(&PDP64::GPRRegClass);
      if (I == 0)
        BuildMI(B, Ins, DL, TII->get(PDP64::CLR), T);
      else
        BuildMI(B, Ins, DL, TII->get(PDP64::MOVI), T).addImm(I);
      BuildMI(B, Ins, DL, TII->get(PDP64::CT_rr)).addReg(A).addReg(T).addImm(CC).addImm(Kind);
    }
  }
  ++NumCT;
  B.removeSuccessor(Fail);
  if (Fail->pred_empty())
    Dead.push_back(Fail);
  // B now goes to Ok only: a branch, unless Ok is the next block in the end
  MachineBasicBlock *Next = B.getNextNode();
  if (Next == Fail && Fail->pred_empty())
    Next = Fail->getNextNode();
  if (Next != Ok)
    BuildMI(&B, DL, TII->get(PDP64::BR)).addMBB(Ok);
  return true;
}

static bool isCt(const MachineInstr &MI, unsigned CC) {
  return MI.getOpcode() == PDP64::CT_rr && MI.getOperand(2).getImm() == (int64_t)CC;
}

// ct lt x, lo ; ct ge x, hi (either order, the second in the single successor, only instructions
// without side effects between them)  ->  chk2 x, lo, hi
bool PDP64CheckFold::foldChk2(MachineBasicBlock &B) {
  MachineBasicBlock *S = B.succ_size() == 1 ? *B.succ_begin() : nullptr;
  MachineInstr *First = nullptr;
  for (MachineInstr &MI : llvm::reverse(B)) {
    if (MI.isDebugInstr() || MI.isTerminator())
      continue;
    First = &MI;
    break;
  }
  if (!First)
    return false;
  bool Lt = isCt(*First, PDP64CC::COND_lt), Ge = isCt(*First, PDP64CC::COND_ge);
  if (!Lt && !Ge)
    return false;
  // the second check may be earlier in the same block, or at the head of the single successor
  MachineInstr *Second = nullptr;
  if (S && S->pred_size() == 1) {
    for (MachineInstr &MI : *S) {
      if (MI.isDebugInstr())
        continue;
      if (isCt(MI, Lt ? PDP64CC::COND_ge : PDP64CC::COND_lt)) {
        Second = &MI;
        break;
      }
      if (MI.mayLoadOrStore() || MI.hasUnmodeledSideEffects() || MI.isCall() || MI.isTerminator() ||
          MI.getOpcode() == PDP64::CT_rr || MI.getOpcode() == PDP64::CT_ri || MI.getOpcode() == PDP64::CT_z ||
          MI.getOpcode() == PDP64::CHK2 || MI.getOpcode() == PDP64::TRAPCHK)
        break;
    }
  }
  if (!Second || First->getOperand(0).getReg() != Second->getOperand(0).getReg())
    return false;
  Register X = First->getOperand(0).getReg();
  Register Lo = Lt ? First->getOperand(1).getReg() : Second->getOperand(1).getReg();
  Register Hi = Lt ? Second->getOperand(1).getReg() : First->getOperand(1).getReg();
  unsigned Kind = First->getOperand(3).getImm() ? First->getOperand(3).getImm() : Second->getOperand(3).getImm();
  if (!Kind || Kind == 1 || Kind == 4)
    Kind = 3; // range
  MachineBasicBlock &SB = *Second->getParent();
  DebugLoc DL = Second->getDebugLoc() ? Second->getDebugLoc() : First->getDebugLoc();
  BuildMI(SB, Second->getIterator(), DL, TII->get(PDP64::CHK2)).addReg(X).addReg(Lo).addReg(Hi).addImm(Kind);
  First->eraseFromParent();
  Second->eraseFromParent();
  ++NumChk2;
  return true;
}

bool PDP64CheckFold::runOnMachineFunction(MachineFunction &MF) {
  if (!FoldChecks)
    return false;
  TII = static_cast<const PDP64InstrInfo *>(MF.getSubtarget().getInstrInfo());
  MRI = &MF.getRegInfo();
  bool Changed = false;
  SmallVector<MachineBasicBlock *, 8> Dead;
  for (MachineBasicBlock &B : MF)
    Changed |= foldBranch(B, Dead);
  for (MachineBasicBlock *D : Dead)
    if (D->pred_empty()) {
      for (MachineBasicBlock *S : llvm::make_early_inc_range(D->successors()))
        D->removeSuccessor(S);
      D->eraseFromParent();
    }
  for (MachineBasicBlock &B : MF)
    while (foldChk2(B))
      Changed = true;
  return Changed;
}
