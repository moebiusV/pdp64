#ifndef LLVM_LIB_TARGET_PDP64_PDP64SUBTARGET_H
#define LLVM_LIB_TARGET_PDP64_PDP64SUBTARGET_H

#include "PDP64FrameLowering.h"
#include "PDP64ISelLowering.h"
#include "PDP64InstrInfo.h"
#include "llvm/CodeGen/SelectionDAGTargetInfo.h"
#include "llvm/CodeGen/TargetSubtargetInfo.h"
#include "llvm/IR/DataLayout.h"

#define GET_SUBTARGETINFO_HEADER
#include "PDP64GenSubtargetInfo.inc"

namespace llvm {
class PDP64TargetMachine;

class PDP64Subtarget : public PDP64GenSubtargetInfo {
  virtual void anchor();
  bool HasVector = false;

  PDP64InstrInfo InstrInfo;
  PDP64FrameLowering FrameLowering;
  PDP64TargetLowering TLInfo;
  SelectionDAGTargetInfo TSInfo;

public:
  PDP64Subtarget(const Triple &TT, StringRef CPU, StringRef FS,
                 const PDP64TargetMachine &TM);

  void ParseSubtargetFeatures(StringRef CPU, StringRef TuneCPU, StringRef FS);
  PDP64Subtarget &initializeSubtargetDependencies(StringRef CPU, StringRef FS);

  bool hasVector() const { return HasVector; }

  const PDP64InstrInfo *getInstrInfo() const override { return &InstrInfo; }
  const PDP64RegisterInfo *getRegisterInfo() const override {
    return &InstrInfo.getRegisterInfo();
  }
  const PDP64FrameLowering *getFrameLowering() const override {
    return &FrameLowering;
  }
  const PDP64TargetLowering *getTargetLowering() const override {
    return &TLInfo;
  }
  const SelectionDAGTargetInfo *getSelectionDAGInfo() const override {
    return &TSInfo;
  }
};
} // namespace llvm
#endif
