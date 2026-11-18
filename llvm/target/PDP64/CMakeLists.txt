add_llvm_component_group(PDP64)

set(LLVM_TARGET_DEFINITIONS PDP64.td)

tablegen(LLVM PDP64GenAsmWriter.inc -gen-asm-writer)
tablegen(LLVM PDP64GenCallingConv.inc -gen-callingconv)
tablegen(LLVM PDP64GenDAGISel.inc -gen-dag-isel)
tablegen(LLVM PDP64GenInstrInfo.inc -gen-instr-info)
tablegen(LLVM PDP64GenRegisterInfo.inc -gen-register-info)
tablegen(LLVM PDP64GenSubtargetInfo.inc -gen-subtarget)

add_public_tablegen_target(PDP64CommonTableGen)

add_llvm_target(PDP64CodeGen
  PDP64AsmPrinter.cpp
  PDP64CheckFold.cpp
  PDP64FrameLowering.cpp
  PDP64InstrInfo.cpp
  PDP64ISelDAGToDAG.cpp
  PDP64ISelLowering.cpp
  PDP64VecLoop.cpp
  PDP64RegisterInfo.cpp
  PDP64Subtarget.cpp
  PDP64TargetMachine.cpp

  LINK_COMPONENTS
  Analysis
  AsmPrinter
  CodeGen
  CodeGenTypes
  Core
  MC
  PDP64Desc
  PDP64Info
  SelectionDAG
  Support
  Target
  TargetParser
  TransformUtils

  ADD_TO_COMPONENT
  PDP64
  )

add_subdirectory(MCTargetDesc)
add_subdirectory(TargetInfo)
