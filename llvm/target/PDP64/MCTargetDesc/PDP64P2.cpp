//===-- PDP64P2.cpp - Page 2: the one-parcel abbreviations ----------------===//
//
// common/p2.c is the table, gen/PDP64Tables.inc is that table as numbers.  This is the same logic as p2.c, on the encoded
// four-byte instruction instead of on a decoded `struct fmt`: p2Expand turns a page-2 word into the page-1 word it stands for,
// p2Compress asks whether a page-1 word has an abbreviation (the lowest page-2 opcode wins).
//
//===----------------------------------------------------------------------===//

#include "PDP64BaseInfo.h"
#include "PDP64MCTargetDesc.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/Support/MathExtras.h"
#include <mutex>

using namespace llvm;
using namespace llvm::PDP64;

namespace {
enum DSrc { D_ZERO, D_LOW, D_LOWHI, D_SLOW, D_STEP, D_BYTE };
constexpr int FIELD = -1;
constexpr int NONE = -2;

struct Row {
  unsigned P2Opc;
  int Opc, Reg, Mode, Rm;
  int DSrc;
  int Scale, Idx;
  int Sysx; // -1, or the SYSX sub-opcode that this word abbreviates (pushx, popx): reg and low must be zero
};

const Row Rows[] = {
#define PDP64_P2_TABLE
#define PDP64_P2ROW(p2, opc, reg, mode, rm, dsrc, scale, idx) {p2, opc, reg, mode, rm, dsrc, scale, idx, -1},
#define PDP64_P2SYSX(p2, sub) {p2, OPGROUP_SYS, 0, 0, 0, D_ZERO, 0, 0, sub},
#include "gen/PDP64Tables.inc"
#undef PDP64_P2ROW
#undef PDP64_P2SYSX
#undef PDP64_P2_TABLE
};

int64_t dispOf(const Row &E, unsigned Reg, unsigned Low) {
  switch (E.DSrc) {
  case D_LOW:
    return (int64_t)E.Scale * Low;
  case D_LOWHI:
    return (int64_t)E.Scale * (16 * E.Idx + Low);
  case D_SLOW:
    return Low >= 8 ? (int64_t)Low - 16 : (int64_t)Low;
  case D_STEP:
    return (int64_t)E.Scale * (1 + E.Idx);
  case D_BYTE:
    return (int64_t)E.Scale * (Reg * 16 + Low);
  }
  return 0;
}

const Row *findRow(unsigned P2Opc) {
  for (const Row &R : Rows)
    if (R.P2Opc == P2Opc)
      return &R;
  return nullptr;
}

/// The fields of the page-1 instruction a page-2 (reg, low) of a row stands for (a SYSX row: mode is the SYS minor, rm the sub-opcode).
struct Expanded {
  unsigned Opc, Reg, Mode, Rm;
  int64_t D;
};
Expanded expand(const Row &E, unsigned Reg, unsigned Low) {
  Expanded X;
  if (E.Sysx >= 0) {
    X.Opc = OPGROUP_SYS;
    X.Reg = 0;
    X.Mode = SYS_MINOR_SYSX;
    X.Rm = E.Sysx;
    X.D = 0;
    return X;
  }
  X.Opc = E.Opc;
  X.Reg = E.Reg == FIELD ? Reg : E.Reg;
  X.Mode = E.Mode;
  X.Rm = E.Rm == FIELD ? Low : E.Rm == NONE ? 0 : E.Rm;
  X.D = dispOf(E, Reg, Low);
  return X;
}

uint32_t pack(const Expanded &X) {
  uint32_t V;
  if (X.Opc == OPGROUP_SYS)
    V = X.Rm << 8; // SYSX: sub:8 pad:8 in parcel 1
  else if (X.Mode == AMODE_BASE)
    V = (X.Rm << BASE_DISP_BITS_LEN1) | (uint32_t)((uint64_t)X.D & maskBits(BASE_DISP_BITS_LEN1));
  else
    V = (uint32_t)((uint64_t)X.D & maskBits(WIDE_BITS_LEN1));
  return (LENCODE_PARCELS2 << 14) | (X.Opc << 8) | (X.Reg << 4) | X.Mode | (V << 16);
}

uint64_t key(unsigned Opc, unsigned Reg, unsigned Mode, unsigned Rm, int64_t D) {
  return (uint64_t)Opc | (uint64_t)Reg << 8 | (uint64_t)Mode << 12 | (uint64_t)Rm << 16 | ((uint64_t)D & 0xFFFFFFFFu) << 24;
}

struct Slot {
  uint8_t P2Opc, Reg, Low;
};
DenseMap<uint64_t, Slot> &table() {
  static DenseMap<uint64_t, Slot> T;
  static std::once_flag Once;
  std::call_once(Once, [] {
    for (const Row &E : Rows)
      for (unsigned Reg = 0; Reg < 16; ++Reg)
        for (unsigned Low = 0; Low < 16; ++Low) {
          if (E.Sysx >= 0 && (Reg || Low))
            continue; // pushx and popx have reg and low zero; anything else is reserved
          Expanded X = expand(E, Reg, Low);
          uint64_t K = key(X.Opc, X.Reg, X.Mode, X.Rm, X.D);
          // rows are in the order of the table, which is by page-2 opcode: the first to claim a key keeps it
          T.try_emplace(K, Slot{(uint8_t)E.P2Opc, (uint8_t)Reg, (uint8_t)Low});
        }
  });
  return T;
}
} // namespace

bool PDP64::p2Expand(uint16_t W, uint32_t &Out) {
  if ((W >> 14) != LENCODE_PAGE2)
    return false;
  const Row *E = findRow((W >> 8) & 63);
  if (!E)
    return false;
  if (E->Sysx >= 0 && (W & 0xFF))
    return false;
  Out = pack(expand(*E, (W >> 4) & 15, W & 15));
  return true;
}

bool PDP64::p2Compress(uint32_t W, bool UnsignedImm, uint16_t &Out) {
  if (((W >> 14) & 3) != LENCODE_PARCELS2)
    return false;
  unsigned Opc = (W >> 8) & 63, Reg = (W >> 4) & 15, Mode = W & 15;
  uint32_t P1 = W >> 16;
  unsigned Rm = 0;
  int64_t D;
  if (Opc == OPGROUP_SYS && Mode == SYS_MINOR_SYSX) {
    if (P1 & 0xFF)
      return false; // the pad byte
    Rm = P1 >> 8;
    D = 0;
  } else if (Mode == AMODE_BASE) {
    Rm = P1 >> BASE_DISP_BITS_LEN1;
    D = signExtend(P1 & maskBits(BASE_DISP_BITS_LEN1), BASE_DISP_BITS_LEN1);
  } else if (Mode == AMODE_IMM) {
    D = UnsignedImm ? (int64_t)(P1 & maskBits(WIDE_BITS_LEN1)) : signExtend(P1, WIDE_BITS_LEN1);
  } else {
    return false;
  }
  DenseMap<uint64_t, Slot> &T = table();
  auto It = T.find(key(Opc, Reg, Mode, (Mode == AMODE_BASE || Opc == OPGROUP_SYS) ? Rm : 0, D));
  if (It == T.end())
    return false;
  Out = (LENCODE_PAGE2 << 14) | (It->second.P2Opc << 8) | (It->second.Reg << 4) | It->second.Low;
  return true;
}
