//===-- PDP64ELFObjectWriter.cpp - PDP64 ELF Writer -----------------------===//
//
// ELF64, little-endian, e_machine EM_PDP64 (0xF064), RELA.  The relocation types are as64's (as64/relocs.h):
//   R_PDP64_D64 / D32       64- and 32-bit data, S + A
//   R_PDP64_INSN_ABS        an immediate or absolute operand: S + A in the instruction's wide field
//   R_PDP64_INSN_PC         d(pc): S + A - P in bytes, P the address of the instruction's first parcel
//   R_PDP64_INSN_BR         a branch: (S + A - P) / 2 in parcels
//
//===----------------------------------------------------------------------===//

#include "PDP64FixupKinds.h"
#include "PDP64MCTargetDesc.h"
#include "llvm/BinaryFormat/ELF.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCELFObjectWriter.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCFixup.h"
#include "llvm/MC/MCValue.h"
#include "llvm/Support/ErrorHandling.h"

using namespace llvm;

namespace {
class PDP64ELFObjectWriter : public MCELFObjectTargetWriter {
public:
  PDP64ELFObjectWriter(uint8_t OSABI)
      : MCELFObjectTargetWriter(/*Is64Bit=*/true, OSABI, ELF::EM_PDP64, /*HasRelocationAddend=*/true) {}
  ~PDP64ELFObjectWriter() override = default;

protected:
  unsigned getRelocType(const MCFixup &Fixup, const MCValue &Target, bool IsPCRel) const override {
    unsigned Kind = Fixup.getKind();
    switch (Kind) {
    case FK_Data_8:
      return ELF::R_PDP64_D64;
    case FK_Data_4:
      return ELF::R_PDP64_D32;
    default:
      break;
    }
    if (Kind > PDP64::fixup_pdp64_start && Kind < PDP64::fixup_pdp64_end) {
      unsigned R = PDP64::getFixupDesc(Kind).Reloc;
      if (R != ELF::R_PDP64_NONE)
        return R;
    }
    reportError(Fixup.getLoc(), "unsupported relocation for this fixup");
    return ELF::R_PDP64_NONE;
  }
};
} // end anonymous namespace

std::unique_ptr<MCObjectTargetWriter> llvm::createPDP64ELFObjectWriter(uint8_t OSABI) {
  return std::make_unique<PDP64ELFObjectWriter>(OSABI);
}
