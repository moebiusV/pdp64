//===-- PDP64InstPrinter.cpp - Convert PDP64 MCInst to asm syntax ---------===//
//
// The syntax is docs/asm-syntax.md: d(rN), d(rN)(rX*s), d(dp), d(pc), #imm, @abs, (rN)+, -(rN), a label for a pc-relative
// operand.  Registers print as sp and fp where the assembler accepts those names.
//
//===----------------------------------------------------------------------===//

#include "PDP64InstPrinter.h"
#include "PDP64BaseInfo.h"
#include "PDP64MCTargetDesc.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

#define DEBUG_TYPE "asm-printer"

#include "PDP64GenAsmWriter.inc"

void PDP64InstPrinter::printRegName(raw_ostream &O, MCRegister Reg) {
  // the register number is the encoding: r13 is fp, r14 is sp
  O << getRegisterName(Reg);
}

void PDP64InstPrinter::printReg(raw_ostream &O, const MCOperand &Op) {
  MCRegister Reg = Op.getReg();
  if (const char *A = PDP64::getRegAliasName(MRI.getEncodingValue(Reg)))
    O << A;
  else
    O << getRegisterName(Reg);
}

void PDP64InstPrinter::printInst(const MCInst *MI, uint64_t Address, StringRef Annot, const MCSubtargetInfo &STI,
                                 raw_ostream &O) {
  printInstruction(MI, Address, O);
  printAnnotation(O, Annot);
}

void PDP64InstPrinter::printValue(raw_ostream &O, const MCOperand &Op) {
  if (Op.isImm())
    O << Op.getImm();
  else if (Op.isExpr())
    MAI.printExpr(O, *Op.getExpr());
  else
    llvm_unreachable("unknown operand kind");
}

void PDP64InstPrinter::printOperand(const MCInst *MI, unsigned OpNo, raw_ostream &O) {
  const MCOperand &Op = MI->getOperand(OpNo);
  if (Op.isReg())
    printReg(O, Op);
  else
    printValue(O, Op);
}

void PDP64InstPrinter::printImm(const MCInst *MI, unsigned OpNo, raw_ostream &O) {
  O << '#';
  printValue(O, MI->getOperand(OpNo));
}

void PDP64InstPrinter::printCC(const MCInst *MI, unsigned OpNo, raw_ostream &O) {
  unsigned CC = MI->getOperand(OpNo).getImm();
  if (const char *N = PDP64::getCCName(CC))
    O << N;
  else
    O << CC;
}

void PDP64InstPrinter::printSysReg(const MCInst *MI, unsigned OpNo, raw_ostream &O) {
  unsigned N = MI->getOperand(OpNo).getImm();
  if (const char *Name = PDP64::getSysRegName(N))
    O << Name;
  else
    O << N; // unassigned: the assembler refuses it, the decoder shows it
}

// A branch target is a byte displacement from the first parcel (an immediate), or an expression.
void PDP64InstPrinter::printTarget(const MCInst *MI, unsigned OpNo, raw_ostream &O) {
  const MCOperand &Op = MI->getOperand(OpNo);
  if (Op.isImm()) {
    int64_t D = Op.getImm();
    O << '.' << (D < 0 ? '-' : '+') << (D < 0 ? -D : D);
  } else {
    printValue(O, Op);
  }
}

void PDP64InstPrinter::printMemBase(const MCInst *MI, unsigned OpNo, raw_ostream &O) {
  const MCOperand &D = MI->getOperand(OpNo + 1);
  if (!D.isImm() || D.getImm() != 0)
    printValue(O, D);
  O << '(';
  printReg(O, MI->getOperand(OpNo));
  O << ')';
}

void PDP64InstPrinter::printMemIndex(const MCInst *MI, unsigned OpNo, raw_ostream &O) {
  const MCOperand &D = MI->getOperand(OpNo + 3);
  if (!D.isImm() || D.getImm() != 0)
    printValue(O, D);
  O << '(';
  printReg(O, MI->getOperand(OpNo));
  O << ")(";
  printReg(O, MI->getOperand(OpNo + 1));
  unsigned S = 1u << MI->getOperand(OpNo + 2).getImm();
  if (S != 1)
    O << '*' << S;
  O << ')';
}

void PDP64InstPrinter::printMemDP(const MCInst *MI, unsigned OpNo, raw_ostream &O) {
  printValue(O, MI->getOperand(OpNo));
  O << "(dp)";
}

void PDP64InstPrinter::printMemPC(const MCInst *MI, unsigned OpNo, raw_ostream &O) {
  const MCOperand &Op = MI->getOperand(OpNo);
  printValue(O, Op);
  if (Op.isImm())
    O << "(pc)";
}

void PDP64InstPrinter::printMemImm(const MCInst *MI, unsigned OpNo, raw_ostream &O) {
  O << '#';
  printValue(O, MI->getOperand(OpNo));
}

void PDP64InstPrinter::printMemAbs(const MCInst *MI, unsigned OpNo, raw_ostream &O) {
  O << '@';
  printValue(O, MI->getOperand(OpNo));
}

unsigned PDP64InstPrinter::defaultStride(const MCInst *MI) const {
  return 1u << PDP64::getStrideLog2(MII.get(MI->getOpcode()).TSFlags);
}

void PDP64InstPrinter::printMemPostInc(const MCInst *MI, unsigned OpNo, raw_ostream &O) {
  O << '(';
  printReg(O, MI->getOperand(OpNo));
  O << ')' << '+';
  const MCOperand &D = MI->getOperand(OpNo + 1);
  if (!D.isImm() || (uint64_t)D.getImm() != defaultStride(MI))
    printValue(O, D);
}

void PDP64InstPrinter::printMemPreDec(const MCInst *MI, unsigned OpNo, raw_ostream &O) {
  const MCOperand &D = MI->getOperand(OpNo + 1);
  if (D.isImm() && (uint64_t)D.getImm() == defaultStride(MI)) {
    O << "-(";
    printReg(O, MI->getOperand(OpNo));
    O << ')';
  } else {
    O << '(';
    printReg(O, MI->getOperand(OpNo));
    O << ")-";
    printValue(O, D);
  }
}
