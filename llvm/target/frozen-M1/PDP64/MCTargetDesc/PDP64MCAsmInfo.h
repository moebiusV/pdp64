//===-- PDP64MCAsmInfo.h - PDP64 asm properties -----------------*- C++ -*-===//
#ifndef LLVM_LIB_TARGET_PDP64_MCTARGETDESC_PDP64MCASMINFO_H
#define LLVM_LIB_TARGET_PDP64_MCTARGETDESC_PDP64MCASMINFO_H

#include "llvm/MC/MCAsmInfoELF.h"

namespace llvm {
class Triple;

class PDP64MCAsmInfo : public MCAsmInfoELF {
  void anchor() override;

public:
  explicit PDP64MCAsmInfo(const Triple &TT);
};
} // namespace llvm

#endif
