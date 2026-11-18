#include "PDP64TargetMachine.h"
#include "PDP64.h"
#include "TargetInfo/PDP64TargetInfo.h"
#include "llvm/CodeGen/Passes.h"
#include "llvm/CodeGen/TargetLoweringObjectFileImpl.h"
#include "llvm/CodeGen/TargetPassConfig.h"
#include "llvm/MC/MCSectionELF.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/Compiler.h"

using namespace llvm;

extern "C" LLVM_ABI LLVM_EXTERNAL_VISIBILITY void LLVMInitializePDP64Target() {
  RegisterTargetMachine<PDP64TargetMachine> X(getThePDP64Target());
  PassRegistry &PR = *PassRegistry::getPassRegistry();
  initializePDP64AsmPrinterPass(PR);
  initializePDP64DAGToDAGISelLegacyPass(PR);
}

namespace {
// as64 knows .text, .data and .bss and nothing else: every read-only datum
// (strings, constants, jump tables) goes to .data.
class PDP64TargetObjectFile : public TargetLoweringObjectFileELF {
public:
  MCSection *SelectSectionForGlobal(const GlobalObject *GO, SectionKind Kind,
                                    const TargetMachine &TM) const override {
    if (Kind.isText())
      return TextSection;
    // an internal zero-initialised object would be printed as ".local x" +
    // ".comm" (as64 has neither); it goes to .data as .space instead
    if (Kind.isBSS() && !Kind.isBSSLocal())
      return BSSSection;
    return DataSection;
  }
  MCSection *getSectionForConstant(const DataLayout &DL, SectionKind Kind,
                                   const Constant *C,
                                   Align &Alignment) const override {
    return DataSection;
  }
  MCSection *getSectionForJumpTable(const Function &F,
                                    const TargetMachine &TM) const override {
    return DataSection;
  }
  MCSection *
  getSectionForJumpTable(const Function &F, const TargetMachine &TM,
                         const MachineJumpTableEntry *JTE) const override {
    return DataSection;
  }
};
} // namespace

// pdp64: little-endian; ELF names without a prefix; 64-bit pointers; the stack
// is a multiple of 8; natural alignment of everything.
static std::string computeDataLayout() {
  return "e-m:e-p:64:64-i8:8-i16:16-i32:32-i64:64-i128:64-f32:32-f64:64-n64-S64";
}

PDP64TargetMachine::PDP64TargetMachine(const Target &T, const Triple &TT,
                                       StringRef CPU, StringRef FS,
                                       const TargetOptions &Options,
                                       std::optional<Reloc::Model> RM,
                                       std::optional<CodeModel::Model> CM,
                                       CodeGenOptLevel OL, bool JIT)
    : CodeGenTargetMachineImpl(T, computeDataLayout(), TT, CPU, FS, Options,
                               Reloc::Static, // pc-relative data, absolute jump tables
                               getEffectiveCodeModel(CM, CodeModel::Small), OL),
      TLOF(std::make_unique<PDP64TargetObjectFile>()),
      Subtarget(TT, CPU, FS, *this) {
  initAsmInfo();
}

PDP64TargetMachine::~PDP64TargetMachine() = default;

namespace {
class PDP64PassConfig : public TargetPassConfig {
public:
  PDP64PassConfig(PDP64TargetMachine &TM, PassManagerBase &PM)
      : TargetPassConfig(TM, PM) {}
  PDP64TargetMachine &getPDP64TargetMachine() const {
    return getTM<PDP64TargetMachine>();
  }
  void addIRPasses() override {
    addPass(createAtomicExpandLegacyPass()); // atomics are library calls
    TargetPassConfig::addIRPasses();
  }
  bool addInstSelector() override {
    addPass(createPDP64ISelDag(getPDP64TargetMachine(), getOptLevel()));
    return false;
  }
};
} // namespace

TargetPassConfig *PDP64TargetMachine::createPassConfig(PassManagerBase &PM) {
  return new PDP64PassConfig(*this, PM);
}
