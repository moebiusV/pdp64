#include "PDP64InstrInfo.h"
#include "PDP64.h"
#include "PDP64Subtarget.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineMemOperand.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"

using namespace llvm;

#define GET_INSTRINFO_CTOR_DTOR
#include "PDP64GenInstrInfo.inc"

void PDP64InstrInfo::anchor() {}

PDP64InstrInfo::PDP64InstrInfo(PDP64Subtarget &STI)
    : PDP64GenInstrInfo(PDP64::ADJCALLSTACKDOWN, PDP64::ADJCALLSTACKUP), RI() {}

void PDP64InstrInfo::copyPhysReg(MachineBasicBlock &MBB,
                                 MachineBasicBlock::iterator I,
                                 const DebugLoc &DL, Register DestReg,
                                 Register SrcReg, bool KillSrc, bool,
                                 bool) const {
  bool Plain = PDP64::GPRRegClass.contains(DestReg, SrcReg);
  BuildMI(MBB, I, DL, get(Plain ? PDP64::MOVrr : PDP64::MOVrrA), DestReg)
      .addReg(SrcReg, getKillRegState(KillSrc));
}

void PDP64InstrInfo::storeRegToStackSlot(
    MachineBasicBlock &MBB, MachineBasicBlock::iterator MI, Register SrcReg,
    bool isKill, int FI, const TargetRegisterClass *RC,
    const TargetRegisterInfo *TRI, Register VReg,
    MachineInstr::MIFlag Flags) const {
  DebugLoc DL;
  if (MI != MBB.end())
    DL = MI->getDebugLoc();
  MachineFunction &MF = *MBB.getParent();
  MachineMemOperand *MMO = MF.getMachineMemOperand(
      MachinePointerInfo::getFixedStack(MF, FI), MachineMemOperand::MOStore, 8,
      Align(8));
  BuildMI(MBB, MI, DL, get(PDP64::STQ_R))
      .addReg(SrcReg, getKillRegState(isKill))
      .addFrameIndex(FI)
      .addImm(0)
      .addMemOperand(MMO);
}

void PDP64InstrInfo::loadRegFromStackSlot(
    MachineBasicBlock &MBB, MachineBasicBlock::iterator MI, Register DestReg,
    int FI, const TargetRegisterClass *RC, const TargetRegisterInfo *TRI,
    Register VReg, MachineInstr::MIFlag Flags) const {
  DebugLoc DL;
  if (MI != MBB.end())
    DL = MI->getDebugLoc();
  MachineFunction &MF = *MBB.getParent();
  MachineMemOperand *MMO = MF.getMachineMemOperand(
      MachinePointerInfo::getFixedStack(MF, FI), MachineMemOperand::MOLoad, 8,
      Align(8));
  BuildMI(MBB, MI, DL, get(PDP64::LDQ_R), DestReg)
      .addFrameIndex(FI)
      .addImm(0)
      .addMemOperand(MMO);
}

// Branches: BR dst ; CB_rr/CB_ri a, b|i, cc, dst.  The floating-point branches
// (BFLAG after an fcmp) are not analysed.
static bool isCondBranch(unsigned Opc) {
  return Opc == PDP64::CB_rr || Opc == PDP64::CB_ri;
}

bool PDP64InstrInfo::analyzeBranch(MachineBasicBlock &MBB,
                                   MachineBasicBlock *&TBB,
                                   MachineBasicBlock *&FBB,
                                   SmallVectorImpl<MachineOperand> &Cond,
                                   bool AllowModify) const {
  MachineBasicBlock::iterator I = MBB.end();
  while (I != MBB.begin()) {
    --I;
    if (I->isDebugInstr())
      continue;
    if (!isUnpredicatedTerminator(*I))
      break;
    if (!I->isBranch())
      return true;
    if (I->isIndirectBranch())
      return true;
    unsigned Opc = I->getOpcode();
    if (Opc == PDP64::BR) {
      if (!AllowModify) {
        TBB = I->getOperand(0).getMBB();
        continue;
      }
      MBB.erase(std::next(I), MBB.end());
      Cond.clear();
      FBB = nullptr;
      if (MBB.isLayoutSuccessor(I->getOperand(0).getMBB())) {
        TBB = nullptr;
        I->eraseFromParent();
        I = MBB.end();
        continue;
      }
      TBB = I->getOperand(0).getMBB();
      continue;
    }
    if (!isCondBranch(Opc))
      return true;
    if (!Cond.empty())
      return true; // two conditional branches
    // the first conditional branch from the bottom
    FBB = TBB;
    TBB = I->getOperand(3).getMBB();
    Cond.push_back(MachineOperand::CreateImm(Opc));
    Cond.push_back(I->getOperand(0)); // lhs register
    Cond.push_back(I->getOperand(1)); // rhs register or immediate
    Cond.push_back(I->getOperand(2)); // cc
  }
  return false;
}

unsigned PDP64InstrInfo::removeBranch(MachineBasicBlock &MBB,
                                      int *BytesRemoved) const {
  assert(!BytesRemoved && "code size not handled");
  MachineBasicBlock::iterator I = MBB.end();
  unsigned Count = 0;
  while (I != MBB.begin()) {
    --I;
    if (I->isDebugInstr())
      continue;
    if (I->getOpcode() != PDP64::BR && !isCondBranch(I->getOpcode()))
      break;
    I->eraseFromParent();
    I = MBB.end();
    ++Count;
  }
  return Count;
}

unsigned PDP64InstrInfo::insertBranch(MachineBasicBlock &MBB,
                                      MachineBasicBlock *TBB,
                                      MachineBasicBlock *FBB,
                                      ArrayRef<MachineOperand> Cond,
                                      const DebugLoc &DL,
                                      int *BytesAdded) const {
  assert(!BytesAdded && "code size not handled");
  assert(TBB && "insertBranch must not be told to insert a fallthrough");
  if (Cond.empty()) {
    BuildMI(&MBB, DL, get(PDP64::BR)).addMBB(TBB);
    return 1;
  }
  assert(Cond.size() == 4 && "bad condition");
  MachineInstrBuilder MIB = BuildMI(&MBB, DL, get(Cond[0].getImm()));
  MIB.add(Cond[1]);
  MIB.add(Cond[2]);
  MIB.add(Cond[3]);
  MIB.addMBB(TBB);
  if (!FBB)
    return 1;
  BuildMI(&MBB, DL, get(PDP64::BR)).addMBB(FBB);
  return 2;
}

bool PDP64InstrInfo::reverseBranchCondition(
    SmallVectorImpl<MachineOperand> &Cond) const {
  assert(Cond.size() == 4 && "bad condition");
  auto CC = static_cast<PDP64CC::CondCode>(Cond[3].getImm());
  PDP64CC::CondCode Inv = PDP64CC::invert(CC);
  if (Inv == PDP64CC::COND_INVALID)
    return true;
  Cond[3].setImm(Inv);
  return false;
}
