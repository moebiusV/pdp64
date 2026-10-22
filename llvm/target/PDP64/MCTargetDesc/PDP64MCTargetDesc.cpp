//===-- PDP64MCTargetDesc.cpp - PDP64 Target Descriptions -----------------===//
#include "PDP64MCTargetDesc.h"
#include "PDP64BaseInfo.h"
#include "PDP64FixupKinds.h"
#include "PDP64InstPrinter.h"
#include "PDP64MCAsmInfo.h"
#include "TargetInfo/PDP64TargetInfo.h"
#include "llvm/MC/MCAsmBackend.h"
#include "llvm/MC/MCCodeEmitter.h"
#include "llvm/MC/MCELFStreamer.h"
#include "llvm/MC/MCInstrAnalysis.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/MC/MCObjectWriter.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/Compiler.h"
#include <cstring>

using namespace llvm;

#define GET_INSTRINFO_MC_DESC
#define ENABLE_INSTR_PREDICATE_VERIFIER
#include "PDP64GenInstrInfo.inc"

#define GET_SUBTARGETINFO_MC_DESC
#include "PDP64GenSubtargetInfo.inc"

#define GET_REGINFO_MC_DESC
#include "PDP64GenRegisterInfo.inc"

// ---- tables from gen/PDP64Tables.inc ----------------------------------------------------------------------------------------

unsigned PDP64::getWiderOpcode(unsigned Opcode) {
  switch (Opcode) {
#define PDP64_WIDEN_TABLE
#define PDP64_WIDEN(narrow, wide)                                                                                      \
  case PDP64::narrow:                                                                                                  \
    return PDP64::wide;
#include "gen/PDP64Tables.inc"
#undef PDP64_WIDEN
#undef PDP64_WIDEN_TABLE
  default:
    return 0;
  }
}

namespace {
struct NameNum {
  const char *Name;
  int Num;
  bool RO;
};
const NameNum CCs[] = {
#define PDP64_CC_TABLE
#define PDP64_CC(n, v) {n, v, false},
#include "gen/PDP64Tables.inc"
#undef PDP64_CC
#undef PDP64_CC_TABLE
};
const NameNum CCPrint[] = {
#define PDP64_CC_PRINT
#define PDP64_CCP(n, v) {n, v, false},
#include "gen/PDP64Tables.inc"
#undef PDP64_CCP
#undef PDP64_CC_PRINT
};
const NameNum SysRegs[] = {
#define PDP64_SYSREG_TABLE
#define PDP64_SYSREG(n, v, ro) {n, v, (bool)ro},
#include "gen/PDP64Tables.inc"
#undef PDP64_SYSREG
#undef PDP64_SYSREG_TABLE
};
const NameNum RegAliases[] = {
#define PDP64_REGALIAS_TABLE
#define PDP64_REGALIAS(n, v) {n, v, false},
#include "gen/PDP64Tables.inc"
#undef PDP64_REGALIAS
#undef PDP64_REGALIAS_TABLE
};

int lookup(ArrayRef<NameNum> T, const char *Name, size_t Len, bool *RO = nullptr) {
  for (const NameNum &E : T)
    if (strlen(E.Name) == Len && memcmp(E.Name, Name, Len) == 0) {
      if (RO)
        *RO = E.RO;
      return E.Num;
    }
  return -1;
}
} // namespace

const char *PDP64::getCCName(unsigned CC) {
  for (const NameNum &E : CCPrint)
    if ((unsigned)E.Num == CC)
      return E.Name;
  return nullptr;
}
int PDP64::lookupCC(const char *Name, size_t Len) { return lookup(CCs, Name, Len); }
const char *PDP64::getSysRegName(unsigned N) {
  for (const NameNum &E : SysRegs)
    if ((unsigned)E.Num == N)
      return E.Name;
  return nullptr;
}
int PDP64::lookupSysReg(const char *Name, size_t Len, bool &RO) {
  RO = false;
  return lookup(SysRegs, Name, Len, &RO);
}
int PDP64::lookupRegAlias(const char *Name, size_t Len) { return lookup(RegAliases, Name, Len); }
const char *PDP64::getRegAliasName(unsigned RegNo) {
  for (const NameNum &E : RegAliases)
    if ((unsigned)E.Num == RegNo)
      return E.Name;
  return nullptr;
}

// ---- registration -----------------------------------------------------------------------------------------------------------

static MCInstrInfo *createPDP64MCInstrInfo() {
  MCInstrInfo *X = new MCInstrInfo();
  InitPDP64MCInstrInfo(X);
  return X;
}

static MCRegisterInfo *createPDP64MCRegisterInfo(const Triple &TT) {
  MCRegisterInfo *X = new MCRegisterInfo();
  // there is no link register: a call pushes the return address; r0 stands in for RA until the ABI's frame description exists
  InitPDP64MCRegisterInfo(X, PDP64::R0);
  return X;
}

static MCAsmInfo *createPDP64MCAsmInfo(const MCRegisterInfo &MRI, const Triple &TT, const MCTargetOptions &Options) {
  return new PDP64MCAsmInfo(TT);
}

static MCSubtargetInfo *createPDP64MCSubtargetInfo(const Triple &TT, StringRef CPU, StringRef FS) {
  if (CPU.empty() || CPU == "generic")
    CPU = "generic";
  return createPDP64MCSubtargetInfoImpl(TT, CPU, /*TuneCPU*/ CPU, FS);
}

static MCInstPrinter *createPDP64MCInstPrinter(const Triple &T, unsigned SyntaxVariant, const MCAsmInfo &MAI,
                                               const MCInstrInfo &MII, const MCRegisterInfo &MRI) {
  if (SyntaxVariant == 0)
    return new PDP64InstPrinter(MAI, MII, MRI);
  return nullptr;
}

static MCStreamer *createPDP64MCStreamer(const Triple &T, MCContext &Ctx, std::unique_ptr<MCAsmBackend> &&MAB,
                                         std::unique_ptr<MCObjectWriter> &&OW, std::unique_ptr<MCCodeEmitter> &&Emitter) {
  return createELFStreamer(Ctx, std::move(MAB), std::move(OW), std::move(Emitter));
}

namespace {
/// Branch targets for llvm-objdump: the immediate of a branch is a byte displacement from the first parcel.
class PDP64MCInstrAnalysis : public MCInstrAnalysis {
public:
  explicit PDP64MCInstrAnalysis(const MCInstrInfo *Info) : MCInstrAnalysis(Info) {}

  bool evaluateBranch(const MCInst &Inst, uint64_t Addr, uint64_t Size, uint64_t &Target) const override {
    const MCInstrDesc &D = Info->get(Inst.getOpcode());
    if (!D.isBranch() || Inst.getNumOperands() == 0)
      return false;
    const MCOperand &Op = Inst.getOperand(Inst.getNumOperands() - 1);
    if (!Op.isImm())
      return false;
    Target = Addr + Op.getImm();
    return true;
  }
};
} // namespace

static MCInstrAnalysis *createPDP64InstrAnalysis(const MCInstrInfo *Info) { return new PDP64MCInstrAnalysis(Info); }

extern "C" LLVM_ABI LLVM_EXTERNAL_VISIBILITY void LLVMInitializePDP64TargetMC() {
  Target &T = getThePDP64Target();
  TargetRegistry::RegisterMCAsmInfo(T, createPDP64MCAsmInfo);
  TargetRegistry::RegisterMCInstrInfo(T, createPDP64MCInstrInfo);
  TargetRegistry::RegisterMCRegInfo(T, createPDP64MCRegisterInfo);
  TargetRegistry::RegisterMCSubtargetInfo(T, createPDP64MCSubtargetInfo);
  TargetRegistry::RegisterMCInstPrinter(T, createPDP64MCInstPrinter);
  TargetRegistry::RegisterMCCodeEmitter(T, createPDP64MCCodeEmitter);
  TargetRegistry::RegisterMCAsmBackend(T, createPDP64AsmBackend);
  TargetRegistry::RegisterELFStreamer(T, createPDP64MCStreamer);
  TargetRegistry::RegisterMCInstrAnalysis(T, createPDP64InstrAnalysis);
}
