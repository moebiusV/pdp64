#include "PDP64RegisterInfo.h"
#include "PDP64.h"
#include "PDP64FrameLowering.h"
#include "PDP64InstrInfo.h"
#include "PDP64Subtarget.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/TargetFrameLowering.h"
#include "llvm/Support/ErrorHandling.h"

using namespace llvm;

#define GET_REGINFO_TARGET_DESC
#include "PDP64GenRegisterInfo.inc"

PDP64RegisterInfo::PDP64RegisterInfo() : PDP64GenRegisterInfo(PDP64::R0) {}

const MCPhysReg *
PDP64RegisterInfo::getCalleeSavedRegs(const MachineFunction *) const {
  return CSR_PDP64_SaveList;
}

const uint32_t *
PDP64RegisterInfo::getCallPreservedMask(const MachineFunction &,
                                        CallingConv::ID) const {
  return CSR_PDP64_RegMask;
}

BitVector PDP64RegisterInfo::getReservedRegs(const MachineFunction &) const {
  BitVector Reserved(getNumRegs());
  Reserved.set(PDP64::R12); // scratch of the linker
  Reserved.set(PDP64::R13); // fp
  Reserved.set(PDP64::R14); // sp
  return Reserved;
}

const TargetRegisterClass *
PDP64RegisterInfo::getPointerRegClass(const MachineFunction &, unsigned) const {
  return &PDP64::GPRRegClass;
}

Register PDP64RegisterInfo::getFrameRegister(const MachineFunction &) const {
  return PDP64::R13;
}

// A frame index is an address relative to fp:  the frame objects are numbered
// from the end of the arguments (offset 0 = the first stack argument at
// 16(fp); the return address and the saved fp are below it, see
// PDP64FrameLowering.cpp), so the address is fp + 16 + offset.  The operand
// after the frame index is the displacement in every instruction form.
bool PDP64RegisterInfo::eliminateFrameIndex(MachineBasicBlock::iterator II,
                                            int SPAdj, unsigned FIOperandNum,
                                            RegScavenger *) const {
  assert(SPAdj == 0 && "no stack pointer adjustment without a frame pointer");
  MachineInstr &MI = *II;
  MachineFunction &MF = *MI.getParent()->getParent();
  int FI = MI.getOperand(FIOperandNum).getIndex();
  int64_t Offset = MF.getFrameInfo().getObjectOffset(FI) + 16;
  Offset += MI.getOperand(FIOperandNum + 1).getImm();
  if (!isInt<PDP64Layout::DispBits>(Offset))
    report_fatal_error("pdp64: stack frame too large for a displacement");
  MI.getOperand(FIOperandNum).ChangeToRegister(PDP64::R13, false);
  MI.getOperand(FIOperandNum + 1).ChangeToImmediate(Offset);
  return false;
}
