#include "PDP64MCAsmInfo.h"
#include "llvm/TargetParser/Triple.h"

using namespace llvm;

// The syntax of as64 (docs/asm-syntax.md): ';' comments, .byte/.word(16)/.long/.quad,
// .space, .ascii, .align n (bytes), .globl, labels with a colon; no .type/.size/.file.
PDP64MCAsmInfo::PDP64MCAsmInfo(const Triple &TT) {
  WeakRefDirective = "\t.weak\t";
  CodePointerSize = 8;
  CalleeSaveStackSlotSize = 8;
  IsLittleEndian = true;
  CommentString = ";";
  PrivateGlobalPrefix = ".L";
  PrivateLabelPrefix = ".L";
  Data8bitsDirective = "\t.byte\t";
  Data16bitsDirective = "\t.word\t";
  Data32bitsDirective = "\t.long\t";
  Data64bitsDirective = "\t.quad\t";
  ZeroDirective = "\t.space\t";
  AsciiDirective = "\t.ascii\t";
  AscizDirective = nullptr;
  GlobalDirective = "\t.globl\t";
  AlignmentIsInBytes = true;
  HasDotTypeDotSizeDirective = false;
  HasIdentDirective = false;
  HasSingleParameterDotFile = false;
  SupportsDebugInformation = false;
  ExceptionsType = ExceptionHandling::None;
  UsesELFSectionDirectiveForBSS = false;
  MinInstAlignment = 2;
  UseIntegratedAssembler = false;
}

// as64 refuses r0..r31 (and r<digits>), sp and fp, and also "ch" (found by
// trying: the assembler's grammar has it as a word), as the name of a symbol; in
// double quotes any name is taken (docs/asm-syntax.md).
bool PDP64MCAsmInfo::isValidUnquotedName(StringRef Name) const {
  if (!MCAsmInfo::isValidUnquotedName(Name))
    return false;
  if (Name == "sp" || Name == "fp" || Name == "ch")
    return false;
  if (Name.size() > 1 && Name[0] == 'r' &&
      Name.drop_front().find_first_not_of("0123456789") == StringRef::npos)
    return false;
  return true;
}
