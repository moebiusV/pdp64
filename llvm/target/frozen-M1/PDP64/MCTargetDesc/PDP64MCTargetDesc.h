//===-- PDP64MCTargetDesc.h - PDP64 Target Descriptions ---------*- C++ -*-===//
#ifndef LLVM_LIB_TARGET_PDP64_MCTARGETDESC_PDP64MCTARGETDESC_H
#define LLVM_LIB_TARGET_PDP64_MCTARGETDESC_PDP64MCTARGETDESC_H

#include "llvm/Support/DataTypes.h"
#include <cstddef>
#include <memory>

namespace llvm {
class MCAsmBackend;
class MCCodeEmitter;
class MCContext;
class MCInstrInfo;
class MCObjectTargetWriter;
class MCRegisterInfo;
class MCSubtargetInfo;
class MCTargetOptions;
class Target;

MCCodeEmitter *createPDP64MCCodeEmitter(const MCInstrInfo &MCII, MCContext &Ctx);
MCAsmBackend *createPDP64AsmBackend(const Target &T, const MCSubtargetInfo &STI, const MCRegisterInfo &MRI,
                                    const MCTargetOptions &Options);
std::unique_ptr<MCObjectTargetWriter> createPDP64ELFObjectWriter(uint8_t OSABI);

namespace PDP64 {
/// The next longer record of the same instruction (the relaxation chain), or 0.  NeedsImm5: the step is allowed only for an immediate of 5 bits.
unsigned getWiderOpcode(unsigned Opcode, bool &NeedsImm5);
/// Page 2 (common/p2.c): the one-parcel abbreviation of a four-byte page-1 instruction, if there is one.
bool p2Compress(uint32_t Word, bool UnsignedImm, uint16_t &Out);
/// The four-byte page-1 instruction a page-2 word abbreviates.  False for a reserved page-2 opcode.
bool p2Expand(uint16_t Word, uint32_t &Out);
/// Names of the conditions and system registers (gen/PDP64Tables.inc).
const char *getCCName(unsigned CC);
int lookupCC(const char *Name, size_t Len);
const char *getSysRegName(unsigned N);
bool isSysRegReadOnly(unsigned N);
/// R0 .. R15 by number.
unsigned gprByNumber(unsigned N);
int lookupSysReg(const char *Name, size_t Len, bool &ReadOnly);
int lookupRegAlias(const char *Name, size_t Len);
const char *getRegAliasName(unsigned RegNo);
} // namespace PDP64
} // namespace llvm

// Defines symbolic names for the registers, the instructions and the subtarget features.
#define GET_REGINFO_ENUM
#include "PDP64GenRegisterInfo.inc"

#define GET_INSTRINFO_ENUM
#define GET_INSTRINFO_MC_HELPER_DECLS
#include "PDP64GenInstrInfo.inc"

#define GET_SUBTARGETINFO_ENUM
#include "PDP64GenSubtargetInfo.inc"

#endif
