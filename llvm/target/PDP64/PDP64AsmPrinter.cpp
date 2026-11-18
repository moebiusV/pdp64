//===-- PDP64AsmPrinter.cpp - Print the pdp64 assembly (as64 syntax) ------===//
#include "MCTargetDesc/PDP64InstPrinter.h"
#include "MCTargetDesc/PDP64MCTargetDesc.h"
#include "PDP64.h"
#include "PDP64TargetMachine.h"
#include "TargetInfo/PDP64TargetInfo.h"
#include "llvm/ADT/SmallString.h"
#include "llvm/CodeGen/AsmPrinter.h"
#include "llvm/CodeGen/MachineInstr.h"
#include "llvm/CodeGen/MachineModuleInfo.h"
#include "llvm/IR/DebugInfoMetadata.h"
#include "llvm/IR/Mangler.h"
#include "llvm/IR/Module.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCStreamer.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/Compiler.h"

using namespace llvm;

#define DEBUG_TYPE "asm-printer"

namespace {
class PDP64AsmPrinter : public AsmPrinter {
public:
  static char ID;
  PDP64AsmPrinter(TargetMachine &TM, std::unique_ptr<MCStreamer> Streamer)
      : AsmPrinter(TM, std::move(Streamer), ID) {}
  StringRef getPassName() const override { return "PDP64 Assembly Printer"; }
  void emitInstruction(const MachineInstr *MI) override;
  bool PrintAsmOperand(const MachineInstr *MI, unsigned OpNo, const char *ExtraCode,
                       raw_ostream &OS) override;

private:
  MCOperand lowerSymbol(const MachineOperand &MO) const;
  void lower(const MachineInstr *MI, MCInst &Out) const;
};
} // namespace

MCOperand PDP64AsmPrinter::lowerSymbol(const MachineOperand &MO) const {
  const MCSymbol *Sym = nullptr;
  switch (MO.getType()) {
  case MachineOperand::MO_GlobalAddress:
    Sym = getSymbol(MO.getGlobal());
    break;
  case MachineOperand::MO_ExternalSymbol:
    Sym = GetExternalSymbolSymbol(MO.getSymbolName());
    break;
  case MachineOperand::MO_JumpTableIndex:
    Sym = GetJTISymbol(MO.getIndex());
    break;
  case MachineOperand::MO_ConstantPoolIndex:
    Sym = GetCPISymbol(MO.getIndex());
    break;
  case MachineOperand::MO_BlockAddress:
    Sym = GetBlockAddressSymbol(MO.getBlockAddress());
    break;
  default:
    llvm_unreachable("not a symbol operand");
  }
  const MCExpr *E = MCSymbolRefExpr::create(Sym, OutContext);
  if (!MO.isJTI() && MO.getOffset())
    E = MCBinaryExpr::createAdd(E, MCConstantExpr::create(MO.getOffset(), OutContext),
                                OutContext);
  return MCOperand::createExpr(E);
}

void PDP64AsmPrinter::lower(const MachineInstr *MI, MCInst &Out) const {
  Out.setOpcode(MI->getOpcode());
  for (const MachineOperand &MO : MI->operands()) {
    switch (MO.getType()) {
    case MachineOperand::MO_Register:
      if (MO.isImplicit())
        continue;
      Out.addOperand(MCOperand::createReg(MO.getReg()));
      break;
    case MachineOperand::MO_Immediate:
      Out.addOperand(MCOperand::createImm(MO.getImm()));
      break;
    case MachineOperand::MO_MachineBasicBlock:
      Out.addOperand(MCOperand::createExpr(
          MCSymbolRefExpr::create(MO.getMBB()->getSymbol(), OutContext)));
      break;
    case MachineOperand::MO_RegisterMask:
      break;
    case MachineOperand::MO_GlobalAddress:
    case MachineOperand::MO_ExternalSymbol:
    case MachineOperand::MO_JumpTableIndex:
    case MachineOperand::MO_ConstantPoolIndex:
    case MachineOperand::MO_BlockAddress:
      Out.addOperand(lowerSymbol(MO));
      break;
    default:
      MI->print(errs());
      llvm_unreachable("unknown operand type");
    }
  }
}

void PDP64AsmPrinter::emitInstruction(const MachineInstr *MI) {
  PDP64_MC::verifyInstructionPredicates(MI->getOpcode(),
                                        getSubtargetInfo().getFeatureBits());
  unsigned Opc = MI->getOpcode();
  if (Opc == PDP64::FBR_D || Opc == PDP64::FBR_S) {
    // fcmp x, y ; b<cc> dst  (see PDP64CC::fpSequence)
    PDP64CC::FPSeq S = PDP64CC::fpSequence(MI->getOperand(2).getImm());
    MCOperand A = MCOperand::createReg(MI->getOperand(0).getReg());
    MCOperand B = MCOperand::createReg(MI->getOperand(1).getReg());
    if (S.Swap)
      std::swap(A, B);
    MCInst Cmp;
    Cmp.setOpcode(Opc == PDP64::FBR_S ? PDP64::FCMP_S : PDP64::FCMP_D);
    Cmp.addOperand(A);
    Cmp.addOperand(B);
    EmitToStreamer(*OutStreamer, Cmp);
    MCInst Br;
    Br.setOpcode(PDP64::BFLAG);
    Br.addOperand(MCOperand::createImm(S.Branch));
    Br.addOperand(MCOperand::createExpr(
        MCSymbolRefExpr::create(MI->getOperand(3).getMBB()->getSymbol(), OutContext)));
    EmitToStreamer(*OutStreamer, Br);
    return;
  }
  switch (Opc) {
  case PDP64::TRAPCHK: case PDP64::CT_rr: case PDP64::CT_ri: case PDP64::CT_z: case PDP64::CHK2: {
    // `.chk KIND, "file", LINE` names the check for the table of check sites (kind 0 and no location: no directive)
    unsigned Kind = MI->getOperand(MI->getNumOperands() - 1).getImm();
    const DebugLoc &DL = MI->getDebugLoc();
    if (Kind || DL) {
      std::string File = MMI->getModule()->getSourceFileName();
      unsigned Line = 0;
      if (DL) {
        Line = DL.getLine();
        if (auto *Sc = dyn_cast_or_null<DIScope>(DL.getScope()))
          if (DIFile *F = Sc->getFile())
            File = F->getFilename().str();
      }
      std::string Esc;
      for (char C : File)
        Esc += (C == '"' || C == '\\') ? std::string("\\") + C : std::string(1, C);
      OutStreamer->emitRawText("\t.chk\t" + Twine(Kind) + ", \"" + Esc + "\", " + Twine(Line));
    }
    break;
  }
  default:
    break;
  }
  MCInst Out;
  lower(MI, Out);
  EmitToStreamer(*OutStreamer, Out);
}

// an operand of inline assembly: a register by name (the (rN)+ and d(rN) forms are in the template), an immediate as a number
bool PDP64AsmPrinter::PrintAsmOperand(const MachineInstr *MI, unsigned OpNo,
                                      const char *ExtraCode, raw_ostream &OS) {
  if (ExtraCode && ExtraCode[0])
    return true;
  const MachineOperand &MO = MI->getOperand(OpNo);
  if (MO.isReg()) {
    OS << PDP64InstPrinter::getRegisterName(MO.getReg());
    return false;
  }
  if (MO.isImm()) {
    OS << MO.getImm();
    return false;
  }
  return true;
}

char PDP64AsmPrinter::ID = 0;

INITIALIZE_PASS(PDP64AsmPrinter, "pdp64-asm-printer", "PDP64 Assembly Printer",
                false, false)

extern "C" LLVM_ABI LLVM_EXTERNAL_VISIBILITY void LLVMInitializePDP64AsmPrinter() {
  RegisterAsmPrinter<PDP64AsmPrinter> X(getThePDP64Target());
}
