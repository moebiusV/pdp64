#ifndef LLVM_LIB_TARGET_PDP64_MCTARGETDESC_PDP64MCTARGETDESC_H
#define LLVM_LIB_TARGET_PDP64_MCTARGETDESC_PDP64MCTARGETDESC_H

#include "llvm/Support/DataTypes.h"

namespace llvm {
class Target;
} // namespace llvm

#define GET_REGINFO_ENUM
#include "PDP64GenRegisterInfo.inc"

#define GET_INSTRINFO_ENUM
#define GET_INSTRINFO_MC_HELPER_DECLS
#include "PDP64GenInstrInfo.inc"

#define GET_SUBTARGETINFO_ENUM
#include "PDP64GenSubtargetInfo.inc"

#endif
