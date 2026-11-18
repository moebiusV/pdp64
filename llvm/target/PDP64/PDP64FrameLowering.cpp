#include "PDP64FrameLowering.h"
#include "PDP64.h"
#include "PDP64InstrInfo.h"
#include "PDP64Subtarget.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"

using namespace llvm;

// A function with nothing in its frame (no locals, no saved registers, no stack
// arguments, no outgoing arguments, no dynamic allocas) has no frame at all:
// pcc does the same ("push fp; movq sp,fp" costs six to ten bytes a function).
// The answer can change when the register allocator makes a spill slot; it is
// asked again before the prologue is emitted.
bool PDP64FrameLowering::hasFPImpl(const MachineFunction &MF) const {
  const MachineFrameInfo &MFI = MF.getFrameInfo();
  return MFI.hasVarSizedObjects() || MFI.getNumObjects() != 0 || MFI.getNumFixedObjects() != 0 ||
         MFI.getMaxCallFrameSize() != 0 || MFI.isFrameAddressTaken() ||
         MFI.hasStackMap() || MFI.hasPatchPoint();
}

// The prologue is "push fp; movq sp, fp; sub #n, sp".  The callee-saved
// registers are stored by the generic code (fp-relative, after the prologue).
void PDP64FrameLowering::emitPrologue(MachineFunction &MF,
                                      MachineBasicBlock &MBB) const {
  if (!hasFP(MF))
    return;
  const PDP64InstrInfo &TII = *STI.getInstrInfo();
  MachineBasicBlock::iterator MBBI = MBB.begin();
  DebugLoc DL;
  BuildMI(MBB, MBBI, DL, TII.get(PDP64::PUSHFP)).setMIFlag(MachineInstr::FrameSetup);
  BuildMI(MBB, MBBI, DL, TII.get(PDP64::SPTOFP)).setMIFlag(MachineInstr::FrameSetup);
  uint64_t Size = MF.getFrameInfo().getStackSize();
  if (Size)
    BuildMI(MBB, MBBI, DL, TII.get(PDP64::SUBSP)).addImm(Size)
        .setMIFlag(MachineInstr::FrameSetup);
}

void PDP64FrameLowering::emitEpilogue(MachineFunction &MF,
                                      MachineBasicBlock &MBB) const {
  if (!hasFP(MF))
    return;
  const PDP64InstrInfo &TII = *STI.getInstrInfo();
  MachineBasicBlock::iterator MBBI = MBB.getFirstTerminator();
  DebugLoc DL = MBBI != MBB.end() ? MBBI->getDebugLoc() : DebugLoc();
  BuildMI(MBB, MBBI, DL, TII.get(PDP64::FPTOSP)).setMIFlag(MachineInstr::FrameDestroy);
  BuildMI(MBB, MBBI, DL, TII.get(PDP64::POPFP)).setMIFlag(MachineInstr::FrameDestroy);
}

bool PDP64FrameLowering::hasReservedCallFrame(const MachineFunction &MF) const {
  return !MF.getFrameInfo().hasVarSizedObjects();
}

MachineBasicBlock::iterator PDP64FrameLowering::eliminateCallFramePseudoInstr(
    MachineFunction &MF, MachineBasicBlock &MBB,
    MachineBasicBlock::iterator I) const {
  const PDP64InstrInfo &TII = *STI.getInstrInfo();
  MachineInstr &Old = *I;
  if (!hasReservedCallFrame(MF)) {
    // dynamic allocas: the call frame is made and removed around each call
    uint64_t Amount = Old.getOperand(0).getImm();
    if (Amount) {
      Amount = alignTo(Amount, getStackAlign());
      if (Old.getOpcode() == TII.getCallFrameSetupOpcode())
        BuildMI(MBB, I, Old.getDebugLoc(), TII.get(PDP64::SUBSP)).addImm(Amount);
      else
        BuildMI(MBB, I, Old.getDebugLoc(), TII.get(PDP64::ADDSP)).addImm(Amount);
    }
  }
  return MBB.erase(I);
}
