#ifndef LLVM_LIB_TARGET_PDP64_MCTARGETDESC_PDP64MCASMINFO_H
#define LLVM_LIB_TARGET_PDP64_MCTARGETDESC_PDP64MCASMINFO_H

#include "llvm/MC/MCAsmInfo.h"

namespace llvm {
class Triple;
class PDP64MCAsmInfo : public MCAsmInfo {
public:
  explicit PDP64MCAsmInfo(const Triple &TT);
  // a symbol named like a register (or one of as64's other reserved words) is written in quotes
  bool isValidUnquotedName(StringRef Name) const override;
  // not an MCAsmInfoELF: as64 has no sections beyond .text, .data and .bss, so no .note.GNU-stack
};
} // namespace llvm
#endif
