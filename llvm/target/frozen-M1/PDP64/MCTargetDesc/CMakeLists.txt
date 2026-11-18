add_llvm_component_library(LLVMPDP64Desc
  PDP64AsmBackend.cpp
  PDP64ELFObjectWriter.cpp
  PDP64InstPrinter.cpp
  PDP64MCAsmInfo.cpp
  PDP64MCCodeEmitter.cpp
  PDP64MCTargetDesc.cpp
  PDP64P2.cpp

  LINK_COMPONENTS
  MC
  PDP64Info
  Support
  TargetParser

  ADD_TO_COMPONENT
  PDP64
  )
