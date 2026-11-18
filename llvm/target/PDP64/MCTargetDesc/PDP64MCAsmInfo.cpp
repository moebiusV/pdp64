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

// as64 reads a register name (r<digits>, sp, fp) and a valid number (a name made only of hexadecimal digits and ending in h or H: ch, ah, deadh; the NASM
// suffix form, "a valid number is never a name", errata 163) as what it is, not as the name of a symbol; in double quotes any name is taken (docs/asm-syntax.md).
// The words that only start a statement or only name a vector register (dd, db, resb, section, v0, t7, ...) are plain symbols where a symbol is expected (errata 169).
bool PDP64MCAsmInfo::isValidUnquotedName(StringRef Name) const {
  if (!MCAsmInfo::isValidUnquotedName(Name))
    return false;
  if (Name == "sp" || Name == "fp")
    return false;
  if (Name.size() > 1 && Name[0] == 'r' &&
      Name.drop_front().find_first_not_of("0123456789") == StringRef::npos)
    return false;
  if (Name.size() > 1 && (Name.back() == 'h' || Name.back() == 'H') &&
      Name.drop_back().find_first_not_of("0123456789abcdefABCDEF") == StringRef::npos)
    return false;
  return true;
}
