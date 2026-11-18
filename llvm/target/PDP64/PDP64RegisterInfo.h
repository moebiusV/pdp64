#ifndef LLVM_LIB_TARGET_PDP64_PDP64REGISTERINFO_H
#define LLVM_LIB_TARGET_PDP64_PDP64REGISTERINFO_H

#define GET_REGINFO_HEADER
#include "PDP64GenRegisterInfo.inc"

namespace llvm {
class PDP64RegisterInfo : public PDP64GenRegisterInfo {
public:
  PDP64RegisterInfo();

  const MCPhysReg *getCalleeSavedRegs(const MachineFunction *MF) const override;
  const uint32_t *getCallPreservedMask(const MachineFunction &MF,
                                       CallingConv::ID) const override;
  BitVector getReservedRegs(const MachineFunction &MF) const override;
  const TargetRegisterClass *getPointerRegClass(const MachineFunction &MF,
                                                unsigned Kind = 0) const override;
  bool eliminateFrameIndex(MachineBasicBlock::iterator II, int SPAdj,
                           unsigned FIOperandNum,
                           RegScavenger *RS = nullptr) const override;
  Register getFrameRegister(const MachineFunction &MF) const override;
};
} // namespace llvm
#endif
