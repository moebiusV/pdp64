#ifndef LLVM_LIB_TARGET_PDP64_PDP64FRAMELOWERING_H
#define LLVM_LIB_TARGET_PDP64_PDP64FRAMELOWERING_H

#include "llvm/CodeGen/TargetFrameLowering.h"

namespace llvm {
class PDP64Subtarget;

// The frame (all of it below the saved fp, as pcc):
//    16+(fp)   the first stack argument
//     8(fp)    the return address
//     0(fp)    the caller's fp
//    -8(fp)..  the callee-saved registers, then the locals
//     0(sp)..  the outgoing arguments (a reserved call frame)
class PDP64FrameLowering : public TargetFrameLowering {
public:
  explicit PDP64FrameLowering(const PDP64Subtarget &STI)
      : TargetFrameLowering(StackGrowsDown, Align(8), -16, Align(8),
                          /*StackRealignable=*/false),
        STI(STI) {}

  void emitPrologue(MachineFunction &MF, MachineBasicBlock &MBB) const override;
  void emitEpilogue(MachineFunction &MF, MachineBasicBlock &MBB) const override;
  MachineBasicBlock::iterator
  eliminateCallFramePseudoInstr(MachineFunction &MF, MachineBasicBlock &MBB,
                                MachineBasicBlock::iterator I) const override;
  bool hasReservedCallFrame(const MachineFunction &MF) const override;
  // The stack is a multiple of 8 and is not realigned: the alignment of an alloca
  // is clamped to 8 (data alignment is architecturally 8 at most).

protected:
  bool hasFPImpl(const MachineFunction &MF) const override;

private:
  const PDP64Subtarget &STI;
};
} // namespace llvm
#endif
