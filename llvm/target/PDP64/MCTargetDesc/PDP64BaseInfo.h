//===-- PDP64BaseInfo.h - Shared facts about the PDP64 records ---*- C++ -*-===//
#ifndef LLVM_LIB_TARGET_PDP64_MCTARGETDESC_PDP64BASEINFO_H
#define LLVM_LIB_TARGET_PDP64_MCTARGETDESC_PDP64BASEINFO_H

#include "gen/PDP64Layout.h"
#include "llvm/MC/MCInstrDesc.h"
#include <cstdint>

namespace llvm {
namespace PDP64 {
using namespace PDP64Layout;

// TSFlags, as set by PDP64Inst in PDP64InstrFormats.td
inline unsigned getForm(uint64_t TSFlags) { return TSFlags & 31; }
inline unsigned getStrideLog2(uint64_t TSFlags) { return (TSFlags >> 5) & 3; }
inline bool isMemFirst(uint64_t TSFlags) { return (TSFlags >> 7) & 1; }
inline bool isUnsignedImm(uint64_t TSFlags) { return (TSFlags >> 8) & 1; }
inline bool isMemForm(unsigned Form) { return Form >= FORM_MEM_BASE && Form <= FORM_MEM_PREDEC; }
inline unsigned getParcels(const MCInstrDesc &D) { return D.getSize() / 2; }

inline int64_t signExtend(uint64_t V, unsigned Bits) {
  return Bits >= 64 ? (int64_t)V : (int64_t)(V << (64 - Bits)) >> (64 - Bits);
}
inline bool fitsSigned(int64_t V, unsigned Bits) {
  return Bits >= 64 || (V >= -((int64_t)1 << (Bits - 1)) && V < ((int64_t)1 << (Bits - 1)));
}
inline uint64_t maskBits(unsigned Bits) { return Bits >= 64 ? ~0ULL : ((1ULL << Bits) - 1); }

/// Width of the displacement or immediate field of an addressing-mode form at an instruction length of 1 or 2 extension parcels.
inline unsigned dispBits(unsigned Form, unsigned Len) {
  switch (Form) {
  case FORM_MEM_BASE:
  case FORM_MEM_DP:
  case FORM_MEM_POSTINC:
  case FORM_MEM_PREDEC:
    return Len == 1 ? BASE_DISP_BITS_LEN1 : BASE_DISP_BITS_LEN2;
  case FORM_MEM_INDEX:
    return Len == 1 ? INDEX_DISP_BITS_LEN1 : INDEX_DISP_BITS_LEN2;
  default: // pcrel, imm, abs
    return Len == 1 ? WIDE_BITS_LEN1 : WIDE_BITS_LEN2;
  }
}
} // namespace PDP64
} // namespace llvm

#endif
