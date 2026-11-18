add_llvm_component_library(LLVMPDP64Disassembler
  PDP64Disassembler.cpp

  LINK_COMPONENTS
  MCDisassembler
  MC
  PDP64Desc
  PDP64Info
  Support

  ADD_TO_COMPONENT
  PDP64
  )
