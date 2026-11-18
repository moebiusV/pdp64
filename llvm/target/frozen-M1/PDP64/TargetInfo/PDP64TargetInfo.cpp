//===-- PDP64TargetInfo.cpp - PDP64 Target Implementation -----------------===//
#include "TargetInfo/PDP64TargetInfo.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/Compiler.h"

using namespace llvm;

Target &llvm::getThePDP64Target() {
  static Target ThePDP64Target;
  return ThePDP64Target;
}

extern "C" LLVM_ABI LLVM_EXTERNAL_VISIBILITY void LLVMInitializePDP64TargetInfo() {
  RegisterTarget<Triple::pdp64, /*HasJIT=*/false> X(getThePDP64Target(), "pdp64", "pdp64 (64-bit PDP-11)", "PDP64");
}
