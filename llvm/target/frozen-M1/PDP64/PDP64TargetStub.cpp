//===-- PDP64TargetStub.cpp - The code generator, not yet --------------------===//
//
// Milestone M1 is the machine-code layer.  LLVMInitializeAllTargets() wants an LLVMInitializePDP64Target(); until the
// TargetMachine (selection DAG, calling convention) exists it registers nothing, so llc reports "no code generator".
//
//===----------------------------------------------------------------------===//

#include "TargetInfo/PDP64TargetInfo.h"
#include "llvm/Support/Compiler.h"

using namespace llvm;

extern "C" LLVM_ABI LLVM_EXTERNAL_VISIBILITY void LLVMInitializePDP64Target() {}
