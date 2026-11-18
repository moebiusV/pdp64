#include "PDP64MCTargetDesc.h"
#include "PDP64InstPrinter.h"
#include "PDP64MCAsmInfo.h"
#include "TargetInfo/PDP64TargetInfo.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/Compiler.h"

using namespace llvm;

#define GET_INSTRINFO_MC_DESC
#define ENABLE_INSTR_PREDICATE_VERIFIER
#include "PDP64GenInstrInfo.inc"

#define GET_SUBTARGETINFO_MC_DESC
#include "PDP64GenSubtargetInfo.inc"

#define GET_REGINFO_MC_DESC
#include "PDP64GenRegisterInfo.inc"

static MCInstrInfo *createPDP64MCInstrInfo() {
  MCInstrInfo *X = new MCInstrInfo();
  InitPDP64MCInstrInfo(X);
  return X;
}

static MCRegisterInfo *createPDP64MCRegisterInfo(const Triple &) {
  MCRegisterInfo *X = new MCRegisterInfo();
  InitPDP64MCRegisterInfo(X, PDP64::R0);
  return X;
}

static MCSubtargetInfo *createPDP64MCSubtargetInfo(const Triple &TT,
                                                   StringRef CPU, StringRef FS) {
  if (CPU.empty())
    CPU = "generic";
  return createPDP64MCSubtargetInfoImpl(TT, CPU, /*TuneCPU=*/CPU, FS);
}

static MCAsmInfo *createPDP64MCAsmInfo(const MCRegisterInfo &, const Triple &TT,
                                       const MCTargetOptions &) {
  return new PDP64MCAsmInfo(TT);
}

static MCInstPrinter *createPDP64MCInstPrinter(const Triple &, unsigned,
                                               const MCAsmInfo &MAI,
                                               const MCInstrInfo &MII,
                                               const MCRegisterInfo &MRI) {
  return new PDP64InstPrinter(MAI, MII, MRI);
}

extern "C" LLVM_ABI LLVM_EXTERNAL_VISIBILITY void LLVMInitializePDP64TargetMC() {
  Target &T = getThePDP64Target();
  RegisterMCAsmInfoFn X(T, createPDP64MCAsmInfo);
  TargetRegistry::RegisterMCInstrInfo(T, createPDP64MCInstrInfo);
  TargetRegistry::RegisterMCRegInfo(T, createPDP64MCRegisterInfo);
  TargetRegistry::RegisterMCSubtargetInfo(T, createPDP64MCSubtargetInfo);
  TargetRegistry::RegisterMCInstPrinter(T, createPDP64MCInstPrinter);
  // Stage 2: the MCCodeEmitter and MCAsmBackend (the table codec common/pdp64enc.c) go here.
}
