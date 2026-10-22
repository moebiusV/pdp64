add_llvm_component_library(LLVMPDP64AsmParser
  PDP64AsmParser.cpp

  LINK_COMPONENTS
  MC
  MCParser
  PDP64Desc
  PDP64Info
  Support
  TargetParser

  ADD_TO_COMPONENT
  PDP64
  )
