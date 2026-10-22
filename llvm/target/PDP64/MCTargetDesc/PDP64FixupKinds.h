//===-- PDP64FixupKinds.h - PDP64 fixup kinds -------------------*- C++ -*-===//
//
// One kind per (field, length).  The fixup is always at offset 0 of the instruction: a relocation's r_offset is the address of the
// instruction's first parcel, and pc-relative values are measured from it.  The table is gen/PDP64Fixups.def.
//
//===----------------------------------------------------------------------===//
#ifndef LLVM_LIB_TARGET_PDP64_MCTARGETDESC_PDP64FIXUPKINDS_H
#define LLVM_LIB_TARGET_PDP64_MCTARGETDESC_PDP64FIXUPKINDS_H

#include "llvm/MC/MCFixup.h"

namespace llvm {
namespace PDP64 {
enum Fixups {
  fixup_pdp64_start = FirstTargetFixupKind - 1,
#define PDP64_FIXUP(name, bits, parcels, pcrel, shift, reloc) fixup_pdp64_##name,
#include "gen/PDP64Fixups.def"
#undef PDP64_FIXUP
  fixup_pdp64_end,
  NumTargetFixupKinds = fixup_pdp64_end - FirstTargetFixupKind
};

/// What a fixup kind says about its field.
struct FixupDesc {
  const char *Name;
  unsigned Bits;     // width of the signed field
  unsigned Parcels;  // length of the instruction in parcels
  bool PCRel;        // measured from the first parcel of the instruction
  unsigned Shift;    // 1: the field counts parcels
  unsigned Reloc;    // ELF relocation number, or 0 (none: the value must be known)
};
const FixupDesc &getFixupDesc(unsigned Kind);
} // namespace PDP64
} // namespace llvm

#endif
