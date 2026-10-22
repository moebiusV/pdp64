//===-- PDP64AsmBackend.cpp - PDP64 Assembler Backend ---------------------===//
//
// Fixups, relaxation and nops.  Every fixup sits at offset 0 of its instruction, so a relocation's offset is the address of the
// instruction's first parcel (relocs.h).  The length of an instruction is a property of its record (Size); relaxation swaps the
// record for the next longer one (gen/PDP64Tables.inc, PDP64_WIDEN), which is what as64's "an instruction grows until its
// displacement fits; it never shrinks" does.
//
//===----------------------------------------------------------------------===//

#include "PDP64BaseInfo.h"
#include "PDP64FixupKinds.h"
#include "PDP64MCTargetDesc.h"
#include "llvm/BinaryFormat/ELF.h"
#include "llvm/MC/MCAsmBackend.h"
#include "llvm/MC/MCAssembler.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCFixup.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCObjectWriter.h"
#include "llvm/MC/MCSection.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/MC/MCValue.h"
#include "llvm/Support/EndianStream.h"

using namespace llvm;

namespace {
const PDP64::FixupDesc FixupTable[] = {
#define PDP64_FIXUP(name, bits, parcels, pcrel, shift, reloc) {"fixup_pdp64_" #name, bits, parcels, pcrel, shift, ELF::R_PDP64_##reloc},
#include "gen/PDP64Fixups.def"
#undef PDP64_FIXUP
};

class PDP64AsmBackend : public MCAsmBackend {
public:
  PDP64AsmBackend() : MCAsmBackend(llvm::endianness::little) {}
  ~PDP64AsmBackend() override = default;

  MCFixupKindInfo getFixupKindInfo(MCFixupKind Kind) const override;
  std::optional<bool> evaluateFixup(const MCFragment &F, MCFixup &Fixup, MCValue &Target, uint64_t &Value) override;
  void applyFixup(const MCFragment &F, const MCFixup &Fixup, const MCValue &Target, MutableArrayRef<char> Data,
                  uint64_t Value, bool IsResolved) override;
  bool mayNeedRelaxation(unsigned Opcode, ArrayRef<MCOperand> Operands, const MCSubtargetInfo &STI) const override;
  bool fixupNeedsRelaxationAdvanced(const MCFixup &Fixup, const MCValue &Target, uint64_t Value,
                                    bool Resolved) const override;
  void relaxInstruction(MCInst &Inst, const MCSubtargetInfo &STI) const override;
  bool writeNopData(raw_ostream &OS, uint64_t Count, const MCSubtargetInfo *STI) const override;
  std::unique_ptr<MCObjectTargetWriter> createObjectTargetWriter() const override {
    return createPDP64ELFObjectWriter(0);
  }
};
} // end anonymous namespace

const PDP64::FixupDesc &PDP64::getFixupDesc(unsigned Kind) {
  assert(Kind > fixup_pdp64_start && Kind < fixup_pdp64_end && "not a pdp64 fixup");
  return FixupTable[Kind - FirstTargetFixupKind];
}

MCFixupKindInfo PDP64AsmBackend::getFixupKindInfo(MCFixupKind Kind) const {
  if (Kind < FirstTargetFixupKind)
    return MCAsmBackend::getFixupKindInfo(Kind);
  const PDP64::FixupDesc &D = PDP64::getFixupDesc(Kind);
  return {D.Name, 0, (uint8_t)D.Bits, 0};
}

// A pc-relative reference to a symbol defined in the same section is resolved by the assembler, whatever the symbol's binding:
// there is no preemption here (as64 does the same; relocs.h INSN_PC / INSN_BR are for other sections and undefined symbols).
std::optional<bool> PDP64AsmBackend::evaluateFixup(const MCFragment &F, MCFixup &Fixup, MCValue &Target,
                                                   uint64_t &Value) {
  if (!Fixup.isPCRel())
    return std::nullopt;
  const MCSymbol *Add = Target.getAddSym();
  if (!Add || Target.getSubSym() || !Add->isDefined() || Add->isAbsolute() || !Add->isInSection() ||
      &Add->getSection() != F.getParent())
    return std::nullopt;
  Value = Target.getConstant() + Asm->getSymbolOffset(*Add) - (Asm->getFragmentOffset(F) + Fixup.getOffset());
  return true;
}

static void put16(MutableArrayRef<char> Data, unsigned ByteOff, uint16_t V) {
  Data[ByteOff] = (char)(V & 0xFF);
  Data[ByteOff + 1] = (char)(V >> 8);
}
static uint16_t get16(ArrayRef<char> Data, unsigned ByteOff) {
  return (uint8_t)Data[ByteOff] | ((uint16_t)(uint8_t)Data[ByteOff + 1] << 8);
}

void PDP64AsmBackend::applyFixup(const MCFragment &F, const MCFixup &Fixup, const MCValue &Target,
                                 MutableArrayRef<char> Data, uint64_t Value, bool IsResolved) {
  MCFixupKind Kind = Fixup.getKind();
  maybeAddReloc(F, Fixup, Target, Value, IsResolved);
  unsigned Off = Fixup.getOffset();

  // data: .short .long .quad
  switch (Kind) {
  case FK_Data_1:
  case FK_Data_2:
  case FK_Data_4:
  case FK_Data_8: {
    unsigned N = 1u << (Kind - FK_Data_1);
    for (unsigned I = 0; I < N; ++I)
      Data[Off + I] = (char)(Value >> (8 * I));
    return;
  }
  default:
    break;
  }
  if (Kind < FirstTargetFixupKind)
    return; // a .reloc, or a kind this target has no field for (the object writer reports it)

  const PDP64::FixupDesc &D = PDP64::getFixupDesc(Kind);
  if (!IsResolved && D.Reloc != ELF::R_PDP64_NONE)
    return; // a relocation was recorded; the linker fills the field (the field is zero)
  if (!IsResolved) {
    Asm->getContext().reportError(Fixup.getLoc(), "the target of a compare-and-branch must be a label of this section (use cmp and a branch)");
    return;
  }

  int64_t V = (int64_t)Value;
  if (D.Shift) {
    if (V & 1) {
      Asm->getContext().reportError(Fixup.getLoc(), "branch to an odd address");
      return;
    }
    V /= 2;
  }
  if (!PDP64::fitsSigned(V, D.Bits)) {
    Asm->getContext().reportError(Fixup.getLoc(), "target out of reach of this instruction");
    return;
  }
  uint64_t U = (uint64_t)V & PDP64::maskBits(D.Bits);

  if (D.Parcels == 1) { // the two-byte branch: the displacement is the low byte
    Data[Off] = (char)(U & 0xFF);
    return;
  }
  // The field is the last bits of the instruction: its high part fills the low `H` bits of parcel 1 (the rest of parcel 1 is
  // other fields, kept), the lower parcels follow whole.  H = Bits - 16 * (Parcels - 2); H = 0 for the wide cbCC, whose
  // displacement is all of parcel 2.
  unsigned H = D.Bits - 16 * (D.Parcels - 2);
  unsigned Low = D.Bits - H; // bits in whole parcels after parcel 1
  if (H) {
    uint16_t P1 = get16(Data, Off + 2);
    uint16_t Mask = (uint16_t)PDP64::maskBits(H);
    P1 = (uint16_t)((P1 & ~Mask) | ((U >> Low) & Mask));
    put16(Data, Off + 2, P1);
  }
  for (unsigned K = 2; K < D.Parcels; ++K) {
    unsigned Shift = 16 * (D.Parcels - 1 - K);
    put16(Data, Off + 2 * K, (uint16_t)(U >> Shift));
  }
}

bool PDP64AsmBackend::mayNeedRelaxation(unsigned Opcode, ArrayRef<MCOperand> Operands, const MCSubtargetInfo &STI) const {
  bool NeedsImm5;
  if (!PDP64::getWiderOpcode(Opcode, NeedsImm5))
    return false;
  // a constant operand never needs a fixup: the parser chose the length that fits it
  bool HasExpr = false;
  for (const MCOperand &Op : Operands)
    HasExpr |= Op.isExpr();
  if (!HasExpr)
    return false;
  // the long cbCC (immediate 5 bits, displacement 27) is a longer form of the wide one only for an immediate that fits it
  if (NeedsImm5 && !(Operands.size() >= 2 && Operands[1].isImm() && PDP64::fitsSigned(Operands[1].getImm(), PDP64::CB_IMM_BITS)))
    return false;
  return true;
}

bool PDP64AsmBackend::fixupNeedsRelaxationAdvanced(const MCFixup &Fixup, const MCValue &Target, uint64_t Value,
                                                   bool Resolved) const {
  if (Fixup.getKind() < FirstTargetFixupKind)
    return false;
  const PDP64::FixupDesc &D = PDP64::getFixupDesc(Fixup.getKind());
  if (!Resolved)
    return D.Reloc != ELF::R_PDP64_NONE; // a relocation needs the widest field
  int64_t V = (int64_t)Value;
  if (D.Shift) {
    if (V & 1)
      return false; // an error either way; applyFixup reports it
    V /= 2;
  }
  return !PDP64::fitsSigned(V, D.Bits);
}

void PDP64AsmBackend::relaxInstruction(MCInst &Inst, const MCSubtargetInfo &STI) const {
  bool NeedsImm5;
  unsigned W = PDP64::getWiderOpcode(Inst.getOpcode(), NeedsImm5);
  assert(W && "no longer form");
  Inst.setOpcode(W);
}

// Padding in .text is nop (SYS, class 0, minor 0: 0x1400) in whole parcels; an odd byte of padding is zero and comes first
// (the instruction pointer is even, so an odd count means the section is at an odd offset).
bool PDP64AsmBackend::writeNopData(raw_ostream &OS, uint64_t Count, const MCSubtargetInfo *STI) const {
  if (Count & 1) {
    OS.write('\0');
    --Count;
  }
  for (; Count; Count -= 2) {
    OS.write('\0');
    OS.write('\x14');
  }
  return true;
}

MCAsmBackend *llvm::createPDP64AsmBackend(const Target &T, const MCSubtargetInfo &STI, const MCRegisterInfo &MRI,
                                          const MCTargetOptions &Options) {
  return new PDP64AsmBackend();
}
