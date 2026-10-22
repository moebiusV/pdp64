//===-- PDP64AsmParser.cpp - Parse PDP64 assembly to MCInst instructions --===//
//
// The syntax is docs/asm-syntax.md (spec/pdp64-asm.hbnf).  The operands are not token-shaped, so they are parsed by hand into
// PDP64Operand; the generated matcher only chooses the record by the mnemonic and the kinds of the operands.  The shortest record
// that matches is the one with the narrowest fields; processInstruction then widens a record whose constant does not fit, and
// the MC layer relaxes one whose symbol does not (PDP64AsmBackend).  Page 2 is chosen by the code emitter.
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/PDP64BaseInfo.h"
#include "MCTargetDesc/PDP64MCTargetDesc.h"
#include "TargetInfo/PDP64TargetInfo.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/StringSwitch.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/MC/MCParser/AsmLexer.h"
#include "llvm/MC/MCParser/MCAsmParser.h"
#include "llvm/MC/MCParser/MCParsedAsmOperand.h"
#include "llvm/MC/MCParser/MCTargetAsmParser.h"
#include "llvm/MC/MCSection.h"
#include "llvm/MC/MCStreamer.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/Compiler.h"
#include "llvm/Support/MathExtras.h"

using namespace llvm;

namespace {
struct PDP64Operand;

class PDP64AsmParser : public MCTargetAsmParser {
  const MCInstrInfo &InstrInfo;

  SMLoc getLoc() const { return getParser().getTok().getLoc(); }

  bool matchAndEmitInstruction(SMLoc IDLoc, unsigned &Opcode, OperandVector &Operands, MCStreamer &Out,
                               uint64_t &ErrorInfo, bool MatchingInlineAsm) override;
  bool parseRegister(MCRegister &Reg, SMLoc &StartLoc, SMLoc &EndLoc) override;
  ParseStatus tryParseRegister(MCRegister &Reg, SMLoc &StartLoc, SMLoc &EndLoc) override;
  bool parseInstruction(ParseInstructionInfo &Info, StringRef Name, SMLoc NameLoc, OperandVector &Operands) override;
  ParseStatus parseDirective(AsmToken DirectiveID) override;

#define GET_ASSEMBLER_HEADER
#include "PDP64GenAsmMatcher.inc"

  bool lookupRegister(StringRef Name, MCRegister &Reg);
  bool parseBaseRegister(MCRegister &Reg, bool &IsPC, bool &IsDP);
  bool parseOperand(OperandVector &Operands, StringRef Mnemonic, unsigned Index);
  bool parseIndexSuffix(OperandVector &Operands, SMLoc S, MCRegister Rn, const MCExpr *Disp);
  bool constantDisp(const MCExpr *E, SMLoc Loc, int64_t &V);
  bool processInstruction(MCInst &Inst, SMLoc IDLoc);
  bool fixupWidth(MCInst &Inst, SMLoc IDLoc);

public:
  enum PDP64MatchResultTy {
    Match_Dummy = FIRST_TARGET_MATCH_RESULT_TY,
#define GET_OPERAND_DIAGNOSTIC_TYPES
#include "PDP64GenAsmMatcher.inc"
#undef GET_OPERAND_DIAGNOSTIC_TYPES
  };

  PDP64AsmParser(const MCSubtargetInfo &STI, MCAsmParser &Parser, const MCInstrInfo &MII, const MCTargetOptions &Options)
      : MCTargetAsmParser(Options, STI, MII), InstrInfo(MII) {
    setAvailableFeatures(ComputeAvailableFeatures(STI.getFeatureBits()));
  }
};

/// The operand kinds the parser builds; the .td operand classes (PDP64InstrInfo.td) test them.
struct PDP64Operand : public MCParsedAsmOperand {
  enum KindTy { Token, Reg, Imm, Abs, Bare, Base, Index, DP, PostInc, PreDec, CC, SysReg } Kind;
  SMLoc StartLoc, EndLoc;
  StringRef Tok;
  MCRegister Rn, Rx;
  unsigned ScaleLog2 = 0;
  const MCExpr *Val = nullptr; // #expr, @expr, a label, a displacement or a stride
  int64_t Const = 0;           // the displacement/stride of Base, Index, DP, PostInc, PreDec; the number of CC and SysReg
  bool HasVal = false;         // the displacement or stride was written
  bool ExplicitPC = false;     // expr(pc)

  PDP64Operand(KindTy K) : Kind(K) {}

  bool isToken() const override { return Kind == Token; }
  bool isReg() const override { return Kind == Reg; }
  bool isImm() const override { return Kind == Imm; }
  bool isMem() const override { return false; }
  SMLoc getStartLoc() const override { return StartLoc; }
  SMLoc getEndLoc() const override { return EndLoc; }
  MCRegister getReg() const override { return Rn; }

  // predicates of the asm operand classes
  bool isImmOp() const { return Kind == Imm; }
  bool isAbsOp() const { return Kind == Abs; }
  bool isBareOp() const { return Kind == Bare; }
  bool isBaseOp() const { return Kind == Base; }
  bool isIndexOp() const { return Kind == Index; }
  bool isDPOp() const { return Kind == DP; }
  bool isPostIncOp() const { return Kind == PostInc; }
  bool isPreDecOp() const { return Kind == PreDec; }
  bool isCC() const { return Kind == CC; }
  bool isSysReg() const { return Kind == SysReg; }
  bool isNever() const { return false; }

  bool constantValue(int64_t &V) const {
    if (Kind != Imm || !Val)
      return false;
    return Val->evaluateAsAbsolute(V);
  }
  template <unsigned N> bool isUImm() const {
    int64_t V;
    return constantValue(V) && V >= 0 && (uint64_t)V < (1ULL << N);
  }
  template <unsigned N> bool isSImm() const {
    int64_t V;
    return constantValue(V) && PDP64::fitsSigned(V, N);
  }
  bool isSImm16Wide() const {
    int64_t V;
    return constantValue(V) && PDP64::fitsSigned(V, PDP64::CBW_IMM_BITS) && !PDP64::fitsSigned(V, PDP64::CB_IMM_BITS);
  }
  bool isTrapL() const {
    int64_t V;
    return constantValue(V) && V >= 16 && V < 256;
  }
  bool isWidth() const {
    int64_t V;
    return constantValue(V) && V >= 1 && V <= 64;
  }

  void print(raw_ostream &OS, const MCAsmInfo &MAI) const override {
    switch (Kind) {
    case Token:
      OS << "'" << Tok << "'";
      break;
    case Reg:
      OS << "<register " << Rn.id() << ">";
      break;
    default:
      OS << "<operand kind " << (int)Kind << ">";
      break;
    }
  }

  void addExpr(MCInst &Inst, const MCExpr *E) const {
    int64_t V;
    if (isa<MCConstantExpr>(E))
      Inst.addOperand(MCOperand::createImm(cast<MCConstantExpr>(E)->getValue()));
    else if (E->evaluateAsAbsolute(V))
      Inst.addOperand(MCOperand::createImm(V));
    else
      Inst.addOperand(MCOperand::createExpr(E));
  }

  // used by the TableGen'erated matcher
  void addRegOperands(MCInst &Inst, unsigned N) const { Inst.addOperand(MCOperand::createReg(Rn)); }
  void addImmOperands(MCInst &Inst, unsigned N) const {
    if (Kind == CC || Kind == SysReg)
      Inst.addOperand(MCOperand::createImm(Const));
    else if (Kind == DP)
      Inst.addOperand(MCOperand::createImm(Const));
    else if (Kind == Bare && ExplicitPC && !Val)
      Inst.addOperand(MCOperand::createImm(Const));
    else
      addExpr(Inst, Val);
  }
  void addBaseOperands(MCInst &Inst, unsigned N) const {
    Inst.addOperand(MCOperand::createReg(Rn));
    Inst.addOperand(MCOperand::createImm(Const));
  }
  void addIndexOperands(MCInst &Inst, unsigned N) const {
    Inst.addOperand(MCOperand::createReg(Rn));
    Inst.addOperand(MCOperand::createReg(Rx));
    Inst.addOperand(MCOperand::createImm(ScaleLog2));
    Inst.addOperand(MCOperand::createImm(Const));
  }
  void addStrideOperands(MCInst &Inst, unsigned N) const {
    Inst.addOperand(MCOperand::createReg(Rn));
    Inst.addOperand(MCOperand::createImm(HasVal ? Const : -1)); // -1: the default stride of the record, filled in after the match
  }

  static std::unique_ptr<PDP64Operand> create(KindTy K, SMLoc S, SMLoc E) {
    auto Op = std::make_unique<PDP64Operand>(K);
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }
};
} // end anonymous namespace

#define GET_REGISTER_MATCHER
#define GET_MATCHER_IMPLEMENTATION
#include "PDP64GenAsmMatcher.inc"

// ---- registers ---------------------------------------------------------------------------------------------------------------

bool PDP64AsmParser::lookupRegister(StringRef Name, MCRegister &Reg) {
  std::string L = Name.lower();
  int Alias = PDP64::lookupRegAlias(L.data(), L.size());
  if (Alias >= 0) {
    Reg = PDP64::gprByNumber(Alias);
    return true;
  }
  MCRegister R = MatchRegisterName(L);
  if (!R)
    return false;
  Reg = R;
  return true;
}

bool PDP64AsmParser::parseRegister(MCRegister &Reg, SMLoc &StartLoc, SMLoc &EndLoc) {
  if (!tryParseRegister(Reg, StartLoc, EndLoc).isSuccess())
    return Error(StartLoc, "invalid register name");
  return false;
}

ParseStatus PDP64AsmParser::tryParseRegister(MCRegister &Reg, SMLoc &StartLoc, SMLoc &EndLoc) {
  const AsmToken &Tok = getParser().getTok();
  StartLoc = Tok.getLoc();
  EndLoc = Tok.getEndLoc();
  if (Tok.isNot(AsmToken::Identifier) || !lookupRegister(Tok.getIdentifier(), Reg))
    return ParseStatus::NoMatch;
  getParser().Lex();
  return ParseStatus::Success;
}

// Parse a register or the pc or dp base; the current token is the identifier.
bool PDP64AsmParser::parseBaseRegister(MCRegister &Reg, bool &IsPC, bool &IsDP) {
  IsPC = IsDP = false;
  const AsmToken &Tok = getParser().getTok();
  if (Tok.isNot(AsmToken::Identifier))
    return true;
  std::string L = Tok.getIdentifier().lower();
  if (L == "pc" || L == "dp") {
    IsPC = L == "pc";
    IsDP = L == "dp";
    getParser().Lex();
    return false;
  }
  if (!lookupRegister(L, Reg))
    return true;
  getParser().Lex();
  return false;
}

bool PDP64AsmParser::constantDisp(const MCExpr *E, SMLoc Loc, int64_t &V) {
  if (E->evaluateAsAbsolute(V))
    return true;
  Error(Loc, "a displacement from a register must be a constant");
  return false;
}

// ---- operands ---------------------------------------------------------------------------------------------------------------

// After `(rn)` or `expr(rn)`: the optional index register `(rx*s)`.
bool PDP64AsmParser::parseIndexSuffix(OperandVector &Operands, SMLoc S, MCRegister Rn, const MCExpr *Disp) {
  int64_t D = 0;
  if (Disp && !constantDisp(Disp, S, D))
    return true;
  if (getParser().getTok().isNot(AsmToken::LParen)) {
    auto Op = PDP64Operand::create(PDP64Operand::Base, S, getLoc());
    Op->Rn = Rn;
    Op->Const = D;
    Operands.push_back(std::move(Op));
    return false;
  }
  getParser().Lex(); // (
  MCRegister Rx;
  SMLoc RS, RE;
  if (!tryParseRegister(Rx, RS, RE).isSuccess())
    return Error(getLoc(), "expected an index register");
  unsigned Scale = 1;
  if (getParser().getTok().is(AsmToken::Star)) {
    getParser().Lex();
    if (getParser().getTok().isNot(AsmToken::Integer))
      return Error(getLoc(), "the scale is 1, 2, 4 or 8");
    Scale = getParser().getTok().getIntVal();
    getParser().Lex();
  }
  if (Scale != 1 && Scale != 2 && Scale != 4 && Scale != 8)
    return Error(RS, "the scale is 1, 2, 4 or 8");
  if (getParser().getTok().isNot(AsmToken::RParen))
    return Error(getLoc(), "expected ')'");
  getParser().Lex();
  auto Op = PDP64Operand::create(PDP64Operand::Index, S, getLoc());
  Op->Rn = Rn;
  Op->Rx = Rx;
  Op->ScaleLog2 = Log2_32(Scale);
  Op->Const = D;
  Operands.push_back(std::move(Op));
  return false;
}

bool PDP64AsmParser::parseOperand(OperandVector &Operands, StringRef Mnemonic, unsigned Index) {
  MCAsmParser &P = getParser();
  AsmLexer &L = static_cast<AsmLexer &>(getLexer());
  SMLoc S = getLoc();
  const AsmToken &Tok = P.getTok();

  // set cc, rd
  if (Mnemonic == "set" && Index == 0) {
    if (Tok.isNot(AsmToken::Identifier))
      return Error(S, "expected a condition (eq, ne, ...)");
    std::string N = Tok.getIdentifier().lower();
    int CC = PDP64::lookupCC(N.data(), N.size());
    if (CC < 0)
      return Error(S, "unknown condition");
    P.Lex();
    auto Op = PDP64Operand::create(PDP64Operand::CC, S, getLoc());
    Op->Const = CC;
    Operands.push_back(std::move(Op));
    return false;
  }
  // mfsr rd, name / mtsr name, rs
  if ((Mnemonic == "mfsr" || Mnemonic == "mtsr") && Tok.is(AsmToken::Identifier)) {
    MCRegister R;
    if (!lookupRegister(Tok.getIdentifier(), R)) {
      std::string N = Tok.getIdentifier().lower();
      bool RO;
      int Num = PDP64::lookupSysReg(N.data(), N.size(), RO);
      if (Num < 0)
        return Error(S, "unknown system register");
      P.Lex();
      auto Op = PDP64Operand::create(PDP64Operand::SysReg, S, getLoc());
      Op->Const = Num;
      Operands.push_back(std::move(Op));
      return false;
    }
  }

  switch (Tok.getKind()) {
  case AsmToken::Hash: { // #expr
    P.Lex();
    const MCExpr *E;
    if (P.parseExpression(E))
      return true;
    auto Op = PDP64Operand::create(PDP64Operand::Imm, S, getLoc());
    Op->Val = E;
    Operands.push_back(std::move(Op));
    return false;
  }
  case AsmToken::At: { // @expr
    P.Lex();
    const MCExpr *E;
    if (P.parseExpression(E))
      return true;
    auto Op = PDP64Operand::create(PDP64Operand::Abs, S, getLoc());
    Op->Val = E;
    Operands.push_back(std::move(Op));
    return false;
  }
  case AsmToken::Minus: { // -(rn); anything else starting with a minus is an expression
    AsmToken Buf[3];
    if (L.peekTokens(Buf, true) == 3 && Buf[0].is(AsmToken::LParen) && Buf[1].is(AsmToken::Identifier) &&
        Buf[2].is(AsmToken::RParen)) {
      MCRegister R;
      if (lookupRegister(Buf[1].getIdentifier(), R)) {
        P.Lex(); // -
        P.Lex(); // (
        P.Lex(); // reg
        P.Lex(); // )
        auto Op = PDP64Operand::create(PDP64Operand::PreDec, S, getLoc());
        Op->Rn = R;
        Operands.push_back(std::move(Op));
        return false;
      }
    }
    break;
  }
  case AsmToken::LParen: { // (rn), (rn)+, (rn)-d, (rn)(rx*s)
    AsmToken Buf[2];
    if (L.peekTokens(Buf, true) == 2 && Buf[0].is(AsmToken::Identifier) && Buf[1].is(AsmToken::RParen)) {
      MCRegister R;
      std::string N = Buf[0].getIdentifier().lower();
      if (lookupRegister(N, R) || N == "pc" || N == "dp") {
        P.Lex(); // (
        bool IsPC, IsDP;
        MCRegister Reg;
        if (parseBaseRegister(Reg, IsPC, IsDP))
          return Error(getLoc(), "expected a register");
        if (IsPC || IsDP)
          return Error(S, "pc and dp are written d(pc) and d(dp)");
        P.Lex(); // )
        if (P.getTok().is(AsmToken::Plus)) { // (rn)+ [expr]
          P.Lex();
          auto Op = PDP64Operand::create(PDP64Operand::PostInc, S, getLoc());
          Op->Rn = Reg;
          if (P.getTok().isNot(AsmToken::Comma) && P.getTok().isNot(AsmToken::EndOfStatement)) {
            const MCExpr *E;
            if (P.parseExpression(E))
              return true;
            if (!constantDisp(E, S, Op->Const))
              return true;
            Op->HasVal = true;
          }
          Op->EndLoc = getLoc();
          Operands.push_back(std::move(Op));
          return false;
        }
        if (P.getTok().is(AsmToken::Minus)) { // (rn)-expr
          P.Lex();
          const MCExpr *E;
          if (P.parseExpression(E))
            return true;
          auto Op = PDP64Operand::create(PDP64Operand::PreDec, S, getLoc());
          Op->Rn = Reg;
          if (!constantDisp(E, S, Op->Const))
            return true;
          Op->HasVal = true;
          Operands.push_back(std::move(Op));
          return false;
        }
        return parseIndexSuffix(Operands, S, Reg, nullptr);
      }
    }
    break;
  }
  case AsmToken::Identifier: { // a register
    MCRegister R;
    if (lookupRegister(Tok.getIdentifier(), R)) {
      P.Lex();
      auto Op = PDP64Operand::create(PDP64Operand::Reg, S, getLoc());
      Op->Rn = R;
      Operands.push_back(std::move(Op));
      return false;
    }
    break;
  }
  default:
    break;
  }

  // an expression: a label, or a displacement `expr(rn)`, `expr(rn)(rx*s)`, `expr(pc)`, `expr(dp)`
  const MCExpr *E;
  if (P.parseExpression(E))
    return true;
  if (P.getTok().is(AsmToken::LParen)) {
    AsmToken Buf[2];
    if (L.peekTokens(Buf, true) == 2 && Buf[0].is(AsmToken::Identifier) && Buf[1].is(AsmToken::RParen)) {
      P.Lex(); // (
      MCRegister Reg;
      bool IsPC, IsDP;
      if (parseBaseRegister(Reg, IsPC, IsDP))
        return Error(getLoc(), "expected a register, pc or dp");
      P.Lex(); // )
      if (IsPC) {
        auto Op = PDP64Operand::create(PDP64Operand::Bare, S, getLoc());
        Op->Val = E;
        Op->ExplicitPC = true;
        int64_t V;
        if (E->evaluateAsAbsolute(V)) { // d(pc): the displacement as written
          Op->Val = nullptr;
          Op->Const = V;
        }
        Operands.push_back(std::move(Op));
        return false;
      }
      if (IsDP) {
        auto Op = PDP64Operand::create(PDP64Operand::DP, S, getLoc());
        if (!constantDisp(E, S, Op->Const))
          return true;
        Operands.push_back(std::move(Op));
        return false;
      }
      return parseIndexSuffix(Operands, S, Reg, E);
    }
  }
  int64_t V;
  if (E->evaluateAsAbsolute(V))
    return Error(S, "a bare number is not an address; write @n or #n");
  auto Op = PDP64Operand::create(PDP64Operand::Bare, S, getLoc());
  Op->Val = E;
  Operands.push_back(std::move(Op));
  return false;
}

bool PDP64AsmParser::parseInstruction(ParseInstructionInfo &Info, StringRef Name, SMLoc NameLoc, OperandVector &Operands) {
  std::string Lower = Name.lower();
  bool IsRol = Lower == "rol"; // rol rs, #n, rd is rori rs, #(64-n), rd (ISA 4.15)
  if (IsRol)
    Lower = "rori";
  StringRef Mn = getContext().allocateString(Lower);
  auto T = PDP64Operand::create(PDP64Operand::Token, NameLoc, NameLoc);
  T->Tok = Mn;
  Operands.push_back(std::move(T));

  if (getParser().getTok().isNot(AsmToken::EndOfStatement)) {
    unsigned Index = 0;
    for (;;) {
      if (parseOperand(Operands, Mn, Index++)) {
        getParser().eatToEndOfStatement();
        return true;
      }
      if (getParser().getTok().isNot(AsmToken::Comma))
        break;
      getParser().Lex();
    }
  }
  if (getParser().getTok().isNot(AsmToken::EndOfStatement)) {
    SMLoc Loc = getLoc();
    getParser().eatToEndOfStatement();
    return Error(Loc, "unexpected token at the end of the instruction");
  }
  getParser().Lex(); // the end of the statement

  if (IsRol) {
    if (Operands.size() != 4 || !static_cast<PDP64Operand &>(*Operands[2]).isImmOp())
      return Error(NameLoc, "rol takes a register, a constant count and a register (ISA 4.15)");
    PDP64Operand &C = static_cast<PDP64Operand &>(*Operands[2]);
    int64_t N;
    if (!C.constantValue(N))
      return Error(C.getStartLoc(), "rol takes a constant count");
    C.Val = MCConstantExpr::create((64 - N) & 63, getContext());
  }
  return false;
}

// ---- directives that the generic assembler has not: .word, .even, .lpad ------------------------------------------------------

ParseStatus PDP64AsmParser::parseDirective(AsmToken DirectiveID) {
  StringRef D = DirectiveID.getString();
  MCAsmParser &P = getParser();
  if (D == ".word") { // 16 bits (the ISA's PDP-11 terminology: .word 16, .long 32, .quad 64)
    for (;;) {
      const MCExpr *E;
      if (P.parseExpression(E))
        return ParseStatus::Failure;
      getStreamer().emitValue(E, 2, DirectiveID.getLoc());
      if (P.getTok().isNot(AsmToken::Comma))
        break;
      P.Lex();
    }
    return P.parseEOL() ? ParseStatus::Failure : ParseStatus::Success;
  }
  if (D == ".even") {
    if (P.parseEOL())
      return ParseStatus::Failure;
    MCSection *Sec = getStreamer().getCurrentSectionOnly();
    if (Sec->useCodeAlign())
      getStreamer().emitCodeAlignment(Align(2), &getSTI());
    else
      getStreamer().emitValueToAlignment(Align(2), 0, 1, 0);
    return ParseStatus::Success;
  }
  if (D == ".lpad") {
    if (P.parseEOL())
      return ParseStatus::Failure;
    MCInst Inst;
    Inst.setOpcode(PDP64::LPAD);
    Inst.setLoc(DirectiveID.getLoc());
    getStreamer().emitInstruction(Inst, getSTI());
    return ParseStatus::Success;
  }
  return ParseStatus::NoMatch;
}

// ---- after the match ---------------------------------------------------------------------------------------------------------

// A constant that does not fit the record's field: the next longer record of the same instruction.
bool PDP64AsmParser::fixupWidth(MCInst &Inst, SMLoc IDLoc) {
  using namespace PDP64;
  for (;;) {
    const MCInstrDesc &D = InstrInfo.get(Inst.getOpcode());
    unsigned Form = getForm(D.TSFlags);
    if (!isMemForm(Form))
      return false;
    unsigned M = isMemFirst(D.TSFlags) ? 1 : 0;
    unsigned Len = getParcels(D) - 1;
    unsigned Idx;
    switch (Form) {
    case FORM_MEM_BASE:
    case FORM_MEM_POSTINC:
    case FORM_MEM_PREDEC:
      Idx = M + 1;
      break;
    case FORM_MEM_INDEX:
      Idx = M + 3;
      break;
    default:
      Idx = M;
      break;
    }
    const MCOperand &Op = Inst.getOperand(Idx);
    if (!Op.isImm())
      return false;
    int64_t V = Op.getImm();
    bool Fits = isUnsignedImm(D.TSFlags) ? (V >= 0 && V < (1 << 16)) : fitsSigned(V, dispBits(Form, Len));
    if (Fits)
      return false;
    bool Imm5;
    unsigned W = getWiderOpcode(Inst.getOpcode(), Imm5);
    if (!W) {
      if (isUnsignedImm(D.TSFlags))
        return Error(IDLoc, "register mask out of range");
      if (Form == FORM_MEM_IMM)
        return Error(IDLoc, "constant " + Twine(V) + " does not fit the " + Twine(dispBits(Form, Len)) + "-bit field; use =K to load it from the literal pool");
      return Error(IDLoc, "displacement " + Twine(V) + " too large");
    }
    Inst.setOpcode(W);
  }
}

bool PDP64AsmParser::processInstruction(MCInst &Inst, SMLoc IDLoc) {
  using namespace PDP64;
  const MCInstrDesc &D = InstrInfo.get(Inst.getOpcode());
  unsigned Form = getForm(D.TSFlags);
  // the default stride of (rN)+ and -(rN) is the size of the access
  if (Form == FORM_MEM_POSTINC || Form == FORM_MEM_PREDEC) {
    MCOperand &S = Inst.getOperand(isMemFirst(D.TSFlags) ? 2 : 1);
    if (S.isImm() && S.getImm() == -1)
      S.setImm(1 << getStrideLog2(D.TSFlags));
  }
  if (Inst.getOpcode() == PDP64::MTSR && PDP64::isSysRegReadOnly(Inst.getOperand(1).getImm()))
    return Error(IDLoc, "mtsr: this system register is read only");
  return fixupWidth(Inst, IDLoc);
}

bool PDP64AsmParser::matchAndEmitInstruction(SMLoc IDLoc, unsigned &Opcode, OperandVector &Operands, MCStreamer &Out,
                                             uint64_t &ErrorInfo, bool MatchingInlineAsm) {
  MCInst Inst;
  switch (MatchInstructionImpl(Operands, Inst, ErrorInfo, MatchingInlineAsm)) {
  default:
    break;
  case Match_Success:
    if (processInstruction(Inst, IDLoc))
      return true;
    Inst.setLoc(IDLoc);
    Out.emitInstruction(Inst, getSTI());
    return false;
  case Match_MissingFeature:
    return Error(IDLoc, "instruction use requires an option to be enabled");
  case Match_MnemonicFail:
    return Error(IDLoc, "unrecognized instruction mnemonic");
  }
  SMLoc ErrorLoc = IDLoc;
  if (ErrorInfo != ~0ULL) {
    if (ErrorInfo >= Operands.size())
      return Error(IDLoc, "too few operands for instruction");
    ErrorLoc = static_cast<PDP64Operand &>(*Operands[ErrorInfo]).getStartLoc();
    if (ErrorLoc == SMLoc())
      ErrorLoc = IDLoc;
  }
  return Error(ErrorLoc, "invalid operand for instruction");
}

extern "C" LLVM_ABI LLVM_EXTERNAL_VISIBILITY void LLVMInitializePDP64AsmParser() {
  RegisterMCAsmParser<PDP64AsmParser> X(getThePDP64Target());
}
