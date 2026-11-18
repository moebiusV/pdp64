add_llvm_component_group(PDP64)

set(LLVM_TARGET_DEFINITIONS PDP64.td)

tablegen(LLVM PDP64GenAsmMatcher.inc -gen-asm-matcher)
tablegen(LLVM PDP64GenAsmWriter.inc -gen-asm-writer)
tablegen(LLVM PDP64GenDisassemblerTables.inc -gen-disassembler)
tablegen(LLVM PDP64GenInstrInfo.inc -gen-instr-info)
tablegen(LLVM PDP64GenMCCodeEmitter.inc -gen-emitter)
tablegen(LLVM PDP64GenRegisterInfo.inc -gen-register-info)
tablegen(LLVM PDP64GenSubtargetInfo.inc -gen-subtarget)

add_public_tablegen_target(PDP64CommonTableGen)

# M1 (the machine-code layer): the code generator library is a stub that only defines LLVMInitializePDP64Target.
add_llvm_target(PDP64CodeGen
  PDP64TargetStub.cpp

  LINK_COMPONENTS
  Core
  MC
  PDP64Desc
  PDP64Info
  Support
  Target

  ADD_TO_COMPONENT
  PDP64
  )

add_subdirectory(AsmParser)
add_subdirectory(Disassembler)
add_subdirectory(MCTargetDesc)
add_subdirectory(TargetInfo)
