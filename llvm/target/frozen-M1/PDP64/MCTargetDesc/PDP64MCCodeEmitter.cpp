//===-- PDP64MCCodeEmitter.cpp - Convert PDP64 code to machine code -------===//
//
// getBinaryCodeForInstr (tblgen) assembles the parcels of a page-1 record; the operand methods below pack the displacement
// fields, and record a fixup for an operand that is an expression.  A four-byte instruction without fixups is then offered to
// page 2 (PDP64::p2Compress): the same instruction in one parcel, which is how the assembler (as64) shortens code.
//
//===----------------------------------------------------------------------===//

#include "PDP64BaseInfo.h"
#include "PDP64FixupKinds.h"
#include "PDP64MCTargetDesc.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/MC/MCCodeEmitter.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCFixup.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/Support/EndianStream.h"

using namespace llvm;

#define DEBUG_TYPE "mccodeemitter"

namespace {
class PDP64MCCodeEmitter : public MCCodeEmitter {
  MCContext &Ctx;
  const MCInstrInfo &MCII;

public:
  PDP64MCCodeEmitter(MCContext &Ctx, const MCInstrInfo &MCII) : Ctx(Ctx), MCII(MCII) {}
  ~PDP64MCCodeEmitter() override = default;

  void encodeInstruction(const MCInst &MI, SmallVectorImpl<char> &CB, SmallVectorImpl<MCFixup> &Fixups,
                         const MCSubtargetInfo &STI) const override;

  // TableGen'erated.
  uint64_t getBinaryCodeForInstr(const MCInst &MI, SmallVectorImpl<MCFixup> &Fixups, const MCSubtargetInfo &STI) const;

  uint64_t getMachineOpValue(const MCInst &MI, const MCOperand &MO, SmallVectorImpl<MCFixup> &Fixups,
                             const MCSubtargetInfo &STI) const;
  uint64_t getImmOpValue(const MCInst &MI, unsigned OpNo, SmallVectorImpl<MCFixup> &Fixups,
                         const MCSubtargetInfo &STI) const;
  template <unsigned Form, unsigned Len>
  uint64_t getMemOpValue(const MCInst &MI, unsigned OpNo, SmallVectorImpl<MCFixup> &Fixups,
                         const MCSubtargetInfo &STI) const;
  template <unsigned Kind, unsigned Bits>
  uint64_t getTargetOpValue(const MCInst &MI, unsigned OpNo, SmallVectorImpl<MCFixup> &Fixups,
                            const MCSubtargetInfo &STI) const;

private:
  unsigned regNum(const MCOperand &MO) const { return Ctx.getRegisterInfo()->getEncodingValue(MO.getReg()); }
  int64_t constant(const MCInst &MI, const MCOperand &MO) const;
};
} // end anonymous namespace

MCCodeEmitter *llvm::createPDP64MCCodeEmitter(const MCInstrInfo &MCII, MCContext &Ctx) {
  return new PDP64MCCodeEmitter(Ctx, MCII);
}

int64_t PDP64MCCodeEmitter::constant(const MCInst &MI, const MCOperand &MO) const {
  if (MO.isImm())
    return MO.getImm();
  int64_t V;
  if (MO.isExpr() && MO.getExpr()->evaluateAsAbsolute(V))
    return V;
  Ctx.reportError(MI.getLoc(), "a displacement from a register must be a constant");
  return 0;
}

uint64_t PDP64MCCodeEmitter::getMachineOpValue(const MCInst &MI, const MCOperand &MO, SmallVectorImpl<MCFixup> &Fixups,
                                               const MCSubtargetInfo &STI) const {
  if (MO.isReg())
    return regNum(MO);
  if (MO.isImm())
    return MO.getImm();
  llvm_unreachable("an expression where only a constant can be encoded");
}

uint64_t PDP64MCCodeEmitter::getImmOpValue(const MCInst &MI, unsigned OpNo, SmallVectorImpl<MCFixup> &Fixups,
                                           const MCSubtargetInfo &STI) const {
  const MCOperand &MO = MI.getOperand(OpNo);
  if (MO.isImm())
    return MO.getImm();
  return constant(MI, MO);
}

template <unsigned Form, unsigned Len>
uint64_t PDP64MCCodeEmitter::getMemOpValue(const MCInst &MI, unsigned OpNo, SmallVectorImpl<MCFixup> &Fixups,
                                           const MCSubtargetInfo &STI) const {
  using namespace PDP64;
  static_assert(Len == 1 || Len == 2, "an operand follows in one or two parcels");
  constexpr unsigned T = 16 * Len;                       // bits of the operand field: the parcels after the first
  constexpr unsigned BaseBits = Len == 1 ? BASE_DISP_BITS_LEN1 : BASE_DISP_BITS_LEN2;
  constexpr unsigned IndexBits = Len == 1 ? INDEX_DISP_BITS_LEN1 : INDEX_DISP_BITS_LEN2;
  constexpr unsigned WideBits = Len == 1 ? WIDE_BITS_LEN1 : WIDE_BITS_LEN2;
  static_assert(BaseBits + 4 == T && IndexBits + 10 == T && WideBits == T,
                "the grammar's field widths are not the layout this encoder assumes: rm:4 [rx:4 s:2] d");

  auto sizeCheck = [&](int64_t V, unsigned Bits) {
    if (!PDP64::fitsSigned(V, Bits))
      Ctx.reportError(MI.getLoc(), "displacement or immediate does not fit the instruction");
  };
  switch (Form) {
  case FORM_MEM_BASE:
  case FORM_MEM_POSTINC:
  case FORM_MEM_PREDEC: {
    uint64_t Rn = regNum(MI.getOperand(OpNo));
    int64_t D = constant(MI, MI.getOperand(OpNo + 1));
    sizeCheck(D, BaseBits);
    return (Rn << BaseBits) | ((uint64_t)D & maskBits(BaseBits));
  }
  case FORM_MEM_INDEX: {
    uint64_t Rn = regNum(MI.getOperand(OpNo)), Rx = regNum(MI.getOperand(OpNo + 1));
    uint64_t S = MI.getOperand(OpNo + 2).getImm() & 3;
    int64_t D = constant(MI, MI.getOperand(OpNo + 3));
    sizeCheck(D, IndexBits);
    return (((Rn << 4 | Rx) << 2 | S) << IndexBits) | ((uint64_t)D & maskBits(IndexBits));
  }
  case FORM_MEM_DP: {
    int64_t D = constant(MI, MI.getOperand(OpNo));
    sizeCheck(D, BaseBits);
    return (uint64_t)D & maskBits(BaseBits);
  }
  default: { // pcrel, imm, abs: the whole field
    const MCOperand &MO = MI.getOperand(OpNo);
    if (MO.isExpr()) {
      int64_t V;
      if (!MO.getExpr()->evaluateAsAbsolute(V)) {
        bool PC = Form == FORM_MEM_PCREL;
        unsigned Kind = PC ? (Len == 1 ? fixup_pdp64_pc16 : fixup_pdp64_pc32)
                           : (Len == 1 ? fixup_pdp64_abs16 : fixup_pdp64_abs32);
        // the fixup is at the instruction: relocations are relative to its first parcel
        Fixups.push_back(MCFixup::create(0, MO.getExpr(), Kind, PC));
        return 0;
      }
      sizeCheck(V, WideBits);
      return (uint64_t)V & maskBits(WideBits);
    }
    int64_t V = MO.getImm();
    if (!(Form == FORM_MEM_IMM && PDP64::isUnsignedImm(MCII.get(MI.getOpcode()).TSFlags)))
      sizeCheck(V, WideBits);
    return (uint64_t)V & maskBits(WideBits);
  }
  }
}

template <unsigned Kind, unsigned Bits>
uint64_t PDP64MCCodeEmitter::getTargetOpValue(const MCInst &MI, unsigned OpNo, SmallVectorImpl<MCFixup> &Fixups,
                                              const MCSubtargetInfo &STI) const {
  const MCOperand &MO = MI.getOperand(OpNo);
  if (MO.isExpr()) {
    Fixups.push_back(MCFixup::create(0, MO.getExpr(), (MCFixupKind)Kind, true));
    return 0;
  }
  // a byte displacement from the first parcel; the field counts parcels
  int64_t D = MO.getImm();
  if ((D & 1) || !PDP64::fitsSigned(D / 2, Bits))
    Ctx.reportError(MI.getLoc(), "branch target out of range or odd");
  return (uint64_t)(D / 2) & PDP64::maskBits(Bits);
}

void PDP64MCCodeEmitter::encodeInstruction(const MCInst &MI, SmallVectorImpl<char> &CB, SmallVectorImpl<MCFixup> &Fixups,
                                           const MCSubtargetInfo &STI) const {
  const MCInstrDesc &Desc = MCII.get(MI.getOpcode());
  unsigned Size = Desc.getSize();
  assert(Size >= 2 && Size <= 6 && !(Size & 1) && "a record without a size");
  uint64_t Bits = getBinaryCodeForInstr(MI, Fixups, STI);

  if (Size == 4 && Fixups.empty()) {
    uint16_t W;
    if (PDP64::p2Compress((uint32_t)Bits, PDP64::isUnsignedImm(Desc.TSFlags), W)) {
      support::endian::write<uint16_t>(CB, W, llvm::endianness::little);
      return;
    }
  }
  for (unsigned I = 0; I < Size; ++I)
    CB.push_back((char)(Bits >> (8 * I)));
}

#include "PDP64GenMCCodeEmitter.inc"
