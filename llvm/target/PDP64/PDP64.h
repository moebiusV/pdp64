//===-- PDP64.h - Top-level interface for the pdp64 back end ----*- C++ -*-===//
#ifndef LLVM_LIB_TARGET_PDP64_PDP64_H
#define LLVM_LIB_TARGET_PDP64_PDP64_H

#include "gen/PDP64GenLayout.h"
#include "MCTargetDesc/PDP64MCTargetDesc.h"
#include "llvm/Support/CodeGen.h"

namespace llvm {
class FunctionPass;
class PDP64TargetMachine;
class PassRegistry;

FunctionPass *createPDP64ISelDag(PDP64TargetMachine &TM,
                                 CodeGenOptLevel OptLevel);
void initializePDP64DAGToDAGISelLegacyPass(PassRegistry &);
void initializePDP64AsmPrinterPass(PassRegistry &);
} // namespace llvm

// Condition codes.  The integer ones are the cbCC suffixes of the grammar
// (generated list); the floating-point ones are conditions of the language
// that the custom inserter turns into fcmp + b<cc> (flags after fcmp: N a<b,
// Z a==b, V unordered, C clear).
namespace PDP64CC {
enum CondCode : unsigned {
#define X(c) COND_##c,
  PDP64_CB_CONDS(X)
#undef X
  FP_OEQ, FP_UNE, FP_OGT, FP_OGE, FP_OLT, FP_OLE,
  FP_ULT, FP_ULE, FP_UGT, FP_UGE, FP_ORD, FP_UNO,
  COND_INVALID
};

inline const char *getCondName(unsigned CC) {
  static const char *const Names[] = {
#define X(c) #c,
      PDP64_CB_CONDS(X)
#undef X
  };
  return CC < sizeof(Names) / sizeof(Names[0]) ? Names[CC] : "??";
}

// the inverse of an integer condition
inline CondCode invert(CondCode CC) {
  switch (CC) {
  case COND_eq: return COND_ne;
  case COND_ne: return COND_eq;
  case COND_lt: return COND_ge;
  case COND_ge: return COND_lt;
  case COND_gt: return COND_le;
  case COND_le: return COND_gt;
  case COND_cs: return COND_cc;
  case COND_cc: return COND_cs;
  case COND_hi: return COND_los;
  case COND_los: return COND_hi;
  default: return COND_INVALID;
  }
}

// After fcmp x, y: N is x<y, Z is x==y, V is unordered, C is clear.  The signed
// branches then are:  bgt = x>y (false when unordered), bge = x>=y (false),
// blt = x<y or unordered, ble = x<=y or unordered.  Each floating-point
// condition is one compare (maybe with the operands swapped) and one branch.
struct FPSeq {
  bool Swap;
  unsigned Branch; // a cc name of the b<cc> instructions
};
inline FPSeq fpSequence(unsigned CC) {
  switch (CC) {
  case FP_OEQ: return {false, COND_eq};
  case FP_UNE: return {false, COND_ne};
  case FP_OGT: return {false, COND_gt};
  case FP_OGE: return {false, COND_ge};
  case FP_OLT: return {true, COND_gt};
  case FP_OLE: return {true, COND_ge};
  case FP_ULT: return {false, COND_lt};
  case FP_ULE: return {false, COND_le};
  case FP_UGT: return {true, COND_lt};
  case FP_UGE: return {true, COND_le};
  case FP_ORD: return {false, COND_vc};
  case FP_UNO: return {false, COND_vs};
  default: return {false, COND_INVALID};
  }
}
} // namespace PDP64CC

#endif
