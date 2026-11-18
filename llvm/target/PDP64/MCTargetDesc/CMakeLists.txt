add_llvm_component_library(LLVMPDP64Desc
  PDP64InstPrinter.cpp
  PDP64MCAsmInfo.cpp
  PDP64MCTargetDesc.cpp

  LINK_COMPONENTS
  MC
  Support
  TargetParser
  PDP64Info

  ADD_TO_COMPONENT
  PDP64
  )
