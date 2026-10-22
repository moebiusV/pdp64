add_llvm_component_library(LLVMPDP64Info
  PDP64TargetInfo.cpp

  LINK_COMPONENTS
  MC
  Support

  ADD_TO_COMPONENT
  PDP64
  )
