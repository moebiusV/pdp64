#include "PDP64Subtarget.h"
#include "PDP64.h"
#include "PDP64TargetMachine.h"

using namespace llvm;

#define DEBUG_TYPE "pdp64-subtarget"

#define GET_SUBTARGETINFO_TARGET_DESC
#define GET_SUBTARGETINFO_CTOR
#include "PDP64GenSubtargetInfo.inc"

void PDP64Subtarget::anchor() {}

PDP64Subtarget &
PDP64Subtarget::initializeSubtargetDependencies(StringRef CPU, StringRef FS) {
  StringRef CPUName = CPU.empty() ? "generic" : CPU;
  ParseSubtargetFeatures(CPUName, CPUName, FS);
  return *this;
}

PDP64Subtarget::PDP64Subtarget(const Triple &TT, StringRef CPU, StringRef FS,
                               const PDP64TargetMachine &TM)
    : PDP64GenSubtargetInfo(TT, CPU, CPU, FS),
      InstrInfo(initializeSubtargetDependencies(CPU, FS)),
      FrameLowering(*this), TLInfo(TM, *this) {}
