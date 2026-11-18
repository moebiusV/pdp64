//===-- PDP64.td - Target definition for the pdp64 ----------*- tablegen -*-===//
//
// Stage 1: a scalar code generator that prints assembly text for as64.  Nothing
// in the .td files knows an opcode number or an encoding; the mnemonics, the
// registers and the field widths come from gen/ (tools/gen-llvm-td.py, which
// reads spec/pdp64/pdp64.hbnf).
//
//===----------------------------------------------------------------------===//

include "llvm/Target/Target.td"

include "gen/PDP64GenMnemonics.td"
include "gen/PDP64GenLayout.td"

// Stage 2 will hang the vector / tile / GEMM instructions on features.
def FeatureVector : SubtargetFeature<"vector", "HasVector", "true",
                                     "Enable the vector unit (stage 2, unused)">;

def : ProcessorModel<"generic", NoSchedModel, []>;
def : ProcessorModel<"pdp64", NoSchedModel, []>;

include "PDP64RegisterInfo.td"
include "PDP64CallingConv.td"
include "PDP64InstrInfo.td"

def PDP64InstrInfo : InstrInfo;

def PDP64AsmWriter : AsmWriter {
  string AsmWriterClassName = "InstPrinter";
  bit isMCAsmWriter = 1;
}

def PDP64 : Target {
  let InstructionSet = PDP64InstrInfo;
  let AssemblyWriters = [PDP64AsmWriter];
}
