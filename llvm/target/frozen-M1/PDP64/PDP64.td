//===-- PDP64.td - Target definition for the pdp64 -------------*- tablegen -*-===//
//
// The 64-bit PDP-11 (https://github.com/moebiusV/pdp64).  See llvm/README.md for the design.
// The numbers (opcodes, modes, registers, field widths) are in gen/, written by tools/gen-llvm-td.py
// from the architecture's grammars; this file and the .td files it includes hold only the structure.
//
//===----------------------------------------------------------------------===//

include "llvm/Target/Target.td"

class PDP64Reg<bits<16> enc, string n> : Register<n> {
  let HWEncoding = enc;
}

include "gen/PDP64Consts.td"
include "gen/PDP64RegisterInfo.td"
include "PDP64InstrFormats.td"
include "PDP64InstrInfo.td"

def PDP64InstrInfo : InstrInfo;

def : ProcessorModel<"generic", NoSchedModel, []>;

def PDP64InstPrinter : AsmWriter {
  string AsmWriterClassName = "InstPrinter";
  bit isMCAsmWriter = 1;
}

def PDP64AsmParser : AsmParser {
  bit HasMnemonicFirst = 1;
}

def PDP64AsmParserVariant : AsmParserVariant {
  int Variant = 0;
  string Name = "pdp64";
  string BreakCharacters = "";
  string TokenizingCharacters = "";
}

def PDP64 : Target {
  let InstructionSet = PDP64InstrInfo;
  let AssemblyWriters = [PDP64InstPrinter];
  let AssemblyParsers = [PDP64AsmParser];
  let AssemblyParserVariants = [PDP64AsmParserVariant];
}
