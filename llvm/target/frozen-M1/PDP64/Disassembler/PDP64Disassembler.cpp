//===-- PDP64Disassembler.cpp - Disassembler for PDP64 --------------------===//
//
// The parcels are little-endian; the top two bits of parcel 0 give the length (0..2: one to three parcels, 3: page 2, a
// one-parcel abbreviation that is expanded to its four-byte page-1 form first, common/p2.c).  Three decoder tables, one per
// width, are generated from the Inst fields of the records.
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/PDP64BaseInfo.h"
#include "MCTargetDesc/PDP64MCTargetDesc.h"
#include "TargetInfo/PDP64TargetInfo.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCDecoderOps.h"
#include "llvm/MC/MCDisassembler/MCDisassembler.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/Compiler.h"
#include "llvm/Support/MathExtras.h"

using namespace llvm;

#define DEBUG_TYPE "pdp64-disassembler"

typedef MCDisassembler::DecodeStatus DecodeStatus;

namespace {
class PDP64Disassembler : public MCDisassembler {
public:
  PDP64Disassembler(const MCSubtargetInfo &STI, MCContext &Ctx) : MCDisassembler(STI, Ctx) {}
  ~PDP64Disassembler() override = default;

  DecodeStatus getInstruction(MCInst &Instr, uint64_t &Size, ArrayRef<uint8_t> Bytes, uint64_t Address,
                              raw_ostream &CStream) const override;
};
} // end anonymous namespace

static MCDisassembler *createPDP64Disassembler(const Target &T, const MCSubtargetInfo &STI, MCContext &Ctx) {
  return new PDP64Disassembler(STI, Ctx);
}

extern "C" LLVM_ABI LLVM_EXTERNAL_VISIBILITY void LLVMInitializePDP64Disassembler() {
  TargetRegistry::RegisterMCDisassembler(getThePDP64Target(), createPDP64Disassembler);
}

static DecodeStatus DecodeGPRRegisterClass(MCInst &Inst, uint64_t RegNo, uint64_t Address, const MCDisassembler *Decoder) {
  if (RegNo > 15)
    return MCDisassembler::Fail;
  Inst.addOperand(MCOperand::createReg(PDP64::gprByNumber(RegNo)));
  return MCDisassembler::Success;
}

template <unsigned N>
static DecodeStatus decodeUImm(MCInst &Inst, uint64_t Imm, uint64_t Address, const MCDisassembler *Decoder) {
  Inst.addOperand(MCOperand::createImm(Imm & PDP64::maskBits(N)));
  return MCDisassembler::Success;
}

template <unsigned N>
static DecodeStatus decodeSImm(MCInst &Inst, uint64_t Imm, uint64_t Address, const MCDisassembler *Decoder) {
  Inst.addOperand(MCOperand::createImm(PDP64::signExtend(Imm, N)));
  return MCDisassembler::Success;
}

static DecodeStatus decodeWidth(MCInst &Inst, uint64_t Imm, uint64_t Address, const MCDisassembler *Decoder) {
  if (Imm > 64)
    return MCDisassembler::Fail;
  Inst.addOperand(MCOperand::createImm(Imm == 0 ? 64 : Imm));
  return MCDisassembler::Success;
}

static DecodeStatus decodeCC(MCInst &Inst, uint64_t Imm, uint64_t Address, const MCDisassembler *Decoder) {
  if (!PDP64::getCCName(Imm))
    return MCDisassembler::Fail;
  Inst.addOperand(MCOperand::createImm(Imm));
  return MCDisassembler::Success;
}

static DecodeStatus decodeSysReg(MCInst &Inst, uint64_t Imm, uint64_t Address, const MCDisassembler *Decoder) {
  if (!PDP64::getSysRegName(Imm))
    return MCDisassembler::Fail;
  Inst.addOperand(MCOperand::createImm(Imm));
  return MCDisassembler::Success;
}

// a branch displacement counts parcels; the operand is the byte displacement from the first parcel
template <unsigned Bits>
static DecodeStatus decodeTargetOp(MCInst &Inst, uint64_t Imm, uint64_t Address, const MCDisassembler *Decoder) {
  Inst.addOperand(MCOperand::createImm(PDP64::signExtend(Imm, Bits) * 2));
  return MCDisassembler::Success;
}

template <unsigned Form, unsigned Len>
static DecodeStatus decodeMemOp(MCInst &Inst, uint64_t Val, uint64_t Address, const MCDisassembler *Decoder) {
  using namespace PDP64;
  constexpr unsigned T = 16 * Len;
  constexpr unsigned BaseBits = Len == 1 ? BASE_DISP_BITS_LEN1 : BASE_DISP_BITS_LEN2;
  constexpr unsigned IndexBits = Len == 1 ? INDEX_DISP_BITS_LEN1 : INDEX_DISP_BITS_LEN2;
  static_assert(BaseBits + 4 == T && IndexBits + 10 == T, "see PDP64MCCodeEmitter.cpp");
  switch (Form) {
  case FORM_MEM_BASE:
  case FORM_MEM_POSTINC:
  case FORM_MEM_PREDEC:
    Inst.addOperand(MCOperand::createReg(gprByNumber((Val >> BaseBits) & 15)));
    Inst.addOperand(MCOperand::createImm(signExtend(Val & maskBits(BaseBits), BaseBits)));
    return MCDisassembler::Success;
  case FORM_MEM_INDEX:
    Inst.addOperand(MCOperand::createReg(gprByNumber((Val >> (IndexBits + 6)) & 15)));
    Inst.addOperand(MCOperand::createReg(gprByNumber((Val >> (IndexBits + 2)) & 15)));
    Inst.addOperand(MCOperand::createImm((Val >> IndexBits) & 3));
    Inst.addOperand(MCOperand::createImm(signExtend(Val & maskBits(IndexBits), IndexBits)));
    return MCDisassembler::Success;
  case FORM_MEM_DP:
    if (Val >> BaseBits) // the pad nibble must be zero
      return MCDisassembler::Fail;
    Inst.addOperand(MCOperand::createImm(signExtend(Val & maskBits(BaseBits), BaseBits)));
    return MCDisassembler::Success;
  default:
    Inst.addOperand(MCOperand::createImm(signExtend(Val & maskBits(T), T)));
    return MCDisassembler::Success;
  }
}

#include "PDP64GenDisassemblerTables.inc"

DecodeStatus PDP64Disassembler::getInstruction(MCInst &MI, uint64_t &Size, ArrayRef<uint8_t> Bytes, uint64_t Address,
                                               raw_ostream &CS) const {
  if (Bytes.size() < 2) {
    Size = 0;
    return MCDisassembler::Fail;
  }
  uint16_t P0 = support::endian::read16le(Bytes.data());
  unsigned Len = P0 >> 14;
  if (Len == PDP64::LENCODE_PAGE2) {
    Size = 2;
    uint32_t W;
    if (!PDP64::p2Expand(P0, W))
      return MCDisassembler::Fail;
    return decodeInstruction(DecoderTable32, MI, (uint64_t)W, Address, this, STI);
  }
  unsigned N = 2 * (Len + 1);
  if (Bytes.size() < N) {
    Size = 0;
    return MCDisassembler::Fail;
  }
  uint64_t Insn = 0;
  for (unsigned I = 0; I < N; ++I)
    Insn |= (uint64_t)Bytes[I] << (8 * I);
  Size = N;
  const uint8_t *Table = Len == 0 ? DecoderTable16 : Len == 1 ? DecoderTable32 : DecoderTable48;
  return decodeInstruction(Table, MI, Insn, Address, this, STI);
}
