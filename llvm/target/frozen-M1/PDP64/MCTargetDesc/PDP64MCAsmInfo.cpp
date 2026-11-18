//===-- PDP64MCAsmInfo.cpp - PDP64 asm properties -------------------------===//
#include "PDP64MCAsmInfo.h"
#include "llvm/TargetParser/Triple.h"

using namespace llvm;

void PDP64MCAsmInfo::anchor() {}

PDP64MCAsmInfo::PDP64MCAsmInfo(const Triple &TT) {
  CodePointerSize = 8;
  CalleeSaveStackSlotSize = 8;
  MinInstAlignment = 2;      // an instruction at an odd address is an assembler error
  IsLittleEndian = true;

  // docs/asm-syntax.md: `;` starts a comment.  As in MSP430, the statement separator is a character that does not otherwise occur.
  CommentString = ";";
  SeparatorString = "{";

  PrivateGlobalPrefix = ".L";
  AlignmentIsInBytes = true;
  UsesELFSectionDirectiveForBSS = true;

  // .short is 16 bits, .long 32, .quad 64 (the generic spellings of .word, .long, .quad)
  Data16bitsDirective = "\t.short\t";
  Data32bitsDirective = "\t.long\t";
  Data64bitsDirective = "\t.quad\t";
}
