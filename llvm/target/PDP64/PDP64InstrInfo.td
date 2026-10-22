//===-- PDP64InstrInfo.td - Operands and instructions --------------*- tablegen -*-===//
//
// MC level only (milestone M1): the instructions are defined for the assembler, the disassembler and the object writer.
// They have no selection patterns and no semantics yet (outs are empty): the code generator milestones add those.
//
// Every instruction is a record per (mnemonic, form, length).  The length of an instruction is a property of its record
// (Size); the assembler starts from the shortest record that matches the operands and the MC layer widens it
// (PDP64AsmBackend::relaxInstruction) when a displacement does not fit.  The wider records are not matchable by the parser:
// their operands have an asm operand class whose predicate is always false.  They exist for the encoder, the decoder and the printer.
//
//===----------------------------------------------------------------------===//

// ---- asm operand classes (the parser builds the operand, the class says which kind it must be) ---------------------------

class PDP64AsmOperand<string n, string pred, string render> : AsmOperandClass {
  let Name = n;
  let PredicateMethod = pred;
  let RenderMethod = render;
  let DiagnosticType = "Invalid" # n;
}
// the same operand, never matched by the parser: for the longer records
class NeverOf<AsmOperandClass c> : AsmOperandClass {
  let Name = c.Name # "W";
  let PredicateMethod = "isNever";
  let RenderMethod = c.RenderMethod;
  let DiagnosticType = "Invalid" # c.Name;
}

def ImmOp     : PDP64AsmOperand<"HashImm", "isImmOp",    "addImmOperands">;       // #expr
def AbsOp     : PDP64AsmOperand<"Abs",     "isAbsOp",    "addImmOperands">;       // @expr
def BareOp    : PDP64AsmOperand<"Bare",    "isBareOp",   "addImmOperands">;       // label, expr(pc)
def BaseOp    : PDP64AsmOperand<"Base",    "isBaseOp",   "addBaseOperands">;      // d(rN)
def IndexOp   : PDP64AsmOperand<"Index",   "isIndexOp",  "addIndexOperands">;     // d(rN)(rX*s)
def DPOp      : PDP64AsmOperand<"DP",      "isDPOp",     "addImmOperands">;       // d(dp)
def PostIncOp : PDP64AsmOperand<"PostInc", "isPostIncOp","addStrideOperands">;    // (rN)+ (rN)+d
def PreDecOp  : PDP64AsmOperand<"PreDec",  "isPreDecOp", "addStrideOperands">;    // -(rN) (rN)-d
def ImmOpW     : NeverOf<ImmOp>;
def AbsOpW     : NeverOf<AbsOp>;
def BareOpW    : NeverOf<BareOp>;
def BaseOpW    : NeverOf<BaseOp>;
def IndexOpW   : NeverOf<IndexOp>;
def DPOpW      : NeverOf<DPOp>;
def PostIncOpW : NeverOf<PostIncOp>;
def PreDecOpW  : NeverOf<PreDecOp>;

class UImmOp<int n> : PDP64AsmOperand<"UImm" # n, "isUImm<" # n # ">", "addImmOperands">;
class SImmOp<int n> : PDP64AsmOperand<"SImm" # n, "isSImm<" # n # ">", "addImmOperands">;
def UImm3Op  : UImmOp<3>;
def UImm4Op  : UImmOp<4>;
def UImm5Op  : UImmOp<5>;
def UImm6Op  : UImmOp<6>;
def UImm16Op : UImmOp<16>;                                                   // pushm, popm
def SImm5Op  : SImmOp<5>;
def SImm5OpW : NeverOf<SImm5Op>;
// the wide cbCC takes what the short one cannot: a 16-bit immediate that is not a 5-bit one
def SImm16WideOp : PDP64AsmOperand<"SImm16Wide", "isSImm16Wide", "addImmOperands">;
def TrapLOp  : PDP64AsmOperand<"TrapL", "isTrapL", "addImmOperands">;        // trap #n for n = 16 .. 255
def WidthOp  : PDP64AsmOperand<"Width", "isWidth", "addImmOperands">;        // 1 .. 64
def CCOp     : PDP64AsmOperand<"CC", "isCC", "addImmOperands">;
def SysRegOp : PDP64AsmOperand<"SysReg", "isSysReg", "addImmOperands">;

// ---- operands ----------------------------------------------------------------------------------------------------------

class PDP64Imm<AsmOperandClass cls, string dec, string pr = "printImm"> : Operand<i64> {
  let ParserMatchClass = cls;
  let EncoderMethod = "getImmOpValue";
  let DecoderMethod = dec;
  let PrintMethod = pr;
}
def uimm3 : PDP64Imm<UImm3Op, "decodeUImm<3>">;
def uimm4 : PDP64Imm<UImm4Op, "decodeUImm<4>">;
def uimm5 : PDP64Imm<UImm5Op, "decodeUImm<5>">;
def uimm6 : PDP64Imm<UImm6Op, "decodeUImm<6>">;
def uimm8trap : PDP64Imm<TrapLOp, "decodeUImm<8>">;
def maskop : PDP64Imm<UImm16Op, "decodeUImm<16>">;
def simm5  : PDP64Imm<SImm5Op, "decodeSImm<5>">;
def simm5w : PDP64Imm<SImm5OpW, "decodeSImm<5>">;
def simm16w : PDP64Imm<SImm16WideOp, "decodeSImm<16>">;
def bwidth : PDP64Imm<WidthOp, "decodeWidth">;
def ccop   : PDP64Imm<CCOp, "decodeCC", "printCC">;
def sysregop : PDP64Imm<SysRegOp, "decodeSysReg", "printSysReg">;

// a memory operand of a given form and length (1 or 2 extension... the length of the record)
class MemOp<AsmOperandClass cls, dag mio, int form, int len, string pr> : Operand<i64> {
  let ParserMatchClass = cls;
  let MIOperandInfo = mio;
  let EncoderMethod = "getMemOpValue<" # form # ", " # len # ">";
  let DecoderMethod = "decodeMemOp<" # form # ", " # len # ">";
  let PrintMethod = pr;
}
multiclass MemOperands<int len, AsmOperandClass b, AsmOperandClass x, AsmOperandClass d, AsmOperandClass pc,
                       AsmOperandClass i, AsmOperandClass a, AsmOperandClass pi, AsmOperandClass pd> {
  def _B  : MemOp<b,  (ops GPR, i64imm),             FORM_MEM_BASE,    len, "printMemBase">;
  def _X  : MemOp<x,  (ops GPR, GPR, i32imm, i64imm), FORM_MEM_INDEX,   len, "printMemIndex">;
  def _D  : MemOp<d,  (ops i64imm),                  FORM_MEM_DP,      len, "printMemDP">;
  def _PC : MemOp<pc, (ops i64imm),                  FORM_MEM_PCREL,   len, "printMemPC">;
  def _I  : MemOp<i,  (ops i64imm),                  FORM_MEM_IMM,     len, "printMemImm">;
  def _A  : MemOp<a,  (ops i64imm),                  FORM_MEM_ABS,     len, "printMemAbs">;
  def _PI : MemOp<pi, (ops GPR, i64imm),             FORM_MEM_POSTINC, len, "printMemPostInc">;
  def _PD : MemOp<pd, (ops GPR, i64imm),             FORM_MEM_PREDEC,  len, "printMemPreDec">;
}
defm mop1 : MemOperands<1, BaseOp,  IndexOp,  DPOp,  BareOp,  ImmOp,  AbsOp,  PostIncOp,  PreDecOp>;
defm mop2 : MemOperands<2, BaseOpW, IndexOpW, DPOpW, BareOpW, ImmOpW, AbsOpW, PostIncOpW, PreDecOpW>;

// branch targets: the value in the MCInst is a byte displacement (an immediate) or an expression
class BrTarget<AsmOperandClass cls, string fix, int nb> : Operand<OtherVT> {
  let ParserMatchClass = cls;
  let EncoderMethod = "getTargetOpValue<PDP64::fixup_pdp64_" # fix # ", " # nb # ">";
  let DecoderMethod = "decodeTargetOp<" # nb # ">";
  let PrintMethod = "printTarget";
}
def brt0   : BrTarget<BareOp,  "br8",  BRANCH_BITS_LEN0>;
def brt1   : BrTarget<BareOpW, "br16", BRANCH_BITS_LEN1>;   // the long branches are reached by relaxation only
def brt2   : BrTarget<BareOpW, "br32", BRANCH_BITS_LEN2>;
def brt1m  : BrTarget<BareOp,  "br16", BRANCH_BITS_LEN1>;   // SOB and BTAG start at this length
def cbt1   : BrTarget<BareOp,  "cb11", CB_BITS_LEN1>;
def cbwt   : BrTarget<BareOp,  "cbw16", CBW_BITS>;
def cbt2   : BrTarget<BareOpW, "cb27", CB_BITS_LEN2>;
def cbrt1  : BrTarget<BareOp,  "cbr12", CBR_BITS_LEN1>;
def cbrt2  : BrTarget<BareOpW, "cbr28", CBR_BITS_LEN2>;

// ---- memory-class instructions: len:2 opc:6 reg:4 low:4, then the operand ----------------------------------------------
//   len 0: low is a register.  Longer: low is the addressing mode and the operand follows in parcel 1 (and 2).

class MemI16<bits<6> opc, dag ins, string asm> : Inst16<(outs), ins, asm> {
  bits<4> r;
  bits<4> m;
  let Inst{15-14} = LENCODE_PARCELS1;
  let Inst{13-8} = opc;
  let Inst{7-4} = r;
  let Inst{3-0} = m;
  let Form = FORM_REG;
}
class MemI32<bits<6> opc, int mode, dag ins, string asm> : Inst32<(outs), ins, asm> {
  bits<4> r;
  bits<16> m;
  let Inst{15-14} = LENCODE_PARCELS2;
  let Inst{13-8} = opc;
  let Inst{7-4} = r;
  let Inst{3-0} = mode;
  let Inst{31-16} = m;
  let Form = !add(mode, 2);
}
class MemI48<bits<6> opc, int mode, dag ins, string asm> : Inst48<(outs), ins, asm> {
  bits<4> r;
  bits<32> m;
  let Inst{15-14} = LENCODE_PARCELS3;
  let Inst{13-8} = opc;
  let Inst{7-4} = r;
  let Inst{3-0} = mode;
  let Inst{31-16} = m{31-16};
  let Inst{47-32} = m{15-0};
  let Form = !add(mode, 2);
}

// all the forms of one mnemonic: a register (if hasReg) and the eight modes (the immediate if hasImm), each in two lengths.
// `pre` is the register operand that comes before the memory operand ((ins GPR:$r) or (ins)).
multiclass MemModes<string mn, int opc, string ops, dag pre, bit hasReg, bit hasImm> {
  if hasReg then
    def _R : MemI16<opc, !con(pre, (ins GPR:$m)), mn # "\t" # ops>;
  def _B1  : MemI32<opc, AMODE_BASE,    !con(pre, (ins mop1_B:$m)),  mn # "\t" # ops>;
  def _B2  : MemI48<opc, AMODE_BASE,    !con(pre, (ins mop2_B:$m)),  mn # "\t" # ops>;
  def _X1  : MemI32<opc, AMODE_INDEX,   !con(pre, (ins mop1_X:$m)),  mn # "\t" # ops>;
  def _X2  : MemI48<opc, AMODE_INDEX,   !con(pre, (ins mop2_X:$m)),  mn # "\t" # ops>;
  def _D1  : MemI32<opc, AMODE_DP,      !con(pre, (ins mop1_D:$m)),  mn # "\t" # ops>;
  def _D2  : MemI48<opc, AMODE_DP,      !con(pre, (ins mop2_D:$m)),  mn # "\t" # ops>;
  def _PC1 : MemI32<opc, AMODE_PCREL,   !con(pre, (ins mop1_PC:$m)), mn # "\t" # ops>;
  def _PC2 : MemI48<opc, AMODE_PCREL,   !con(pre, (ins mop2_PC:$m)), mn # "\t" # ops>;
  if hasImm then {
    def _I1 : MemI32<opc, AMODE_IMM,    !con(pre, (ins mop1_I:$m)),  mn # "\t" # ops>;
    def _I2 : MemI48<opc, AMODE_IMM,    !con(pre, (ins mop2_I:$m)),  mn # "\t" # ops>;
  }
  def _A1  : MemI32<opc, AMODE_ABS,     !con(pre, (ins mop1_A:$m)),  mn # "\t" # ops>;
  def _A2  : MemI48<opc, AMODE_ABS,     !con(pre, (ins mop2_A:$m)),  mn # "\t" # ops>;
  def _PI1 : MemI32<opc, AMODE_POSTINC, !con(pre, (ins mop1_PI:$m)), mn # "\t" # ops>;
  def _PI2 : MemI48<opc, AMODE_POSTINC, !con(pre, (ins mop2_PI:$m)), mn # "\t" # ops>;
  def _PD1 : MemI32<opc, AMODE_PREDEC,  !con(pre, (ins mop1_PD:$m)), mn # "\t" # ops>;
  def _PD2 : MemI48<opc, AMODE_PREDEC,  !con(pre, (ins mop2_PD:$m)), mn # "\t" # ops>;
}

// a mnemonic with a register operand and a memory operand: moves, the ALU, lea.  stride: log2 of the default step of (rN)+.
multiclass MemRM<string mn, int opc, string ops, bit hasReg, bit hasImm, bits<2> stride> {
  let Stride = stride, MemFirst = 1 in
    defm "" : MemModes<mn, opc, ops, (ins GPR:$r), hasReg, hasImm>;
}
// a mnemonic with one operand; the reg field is the sub-opcode
multiclass MemU<string mn, int opc, bits<4> sub, bit hasReg, bit hasImm> {
  let r = sub in
    defm "" : MemModes<mn, opc, "$m", (ins), hasReg, hasImm>;
}
// jtag d(rbase)(rtagged): the indexed mode only
multiclass MemTag<string mn, int opc, bits<4> sub> {
  let r = sub in {
    def _X1 : MemI32<opc, AMODE_INDEX, (ins mop1_X:$m), mn # "\t$m">;
    def _X2 : MemI48<opc, AMODE_INDEX, (ins mop2_X:$m), mn # "\t$m">;
  }
}
// pushm #mask, popm #mask: a 16-bit unsigned mask in the wide field
multiclass MemMask<string mn, bits<4> sub> {
  let r = sub, UImm = 1 in
    def _I1 : MemI32<OPGROUP_SOP, AMODE_IMM, (ins maskop:$m), mn # "\t$m">;
}

// ---- branches ---------------------------------------------------------------------------------------------------------------

class BrI16<bits<6> opc, dag ins, string asm> : Inst16<(outs), ins, asm> {
  let Inst{15-14} = LENCODE_PARCELS1;
  let Inst{13-8} = opc;
  let Form = FORM_BR0;
  let isBranch = 1;
  let isTerminator = 1;
}
class BrI32<bits<6> opc, dag ins, string asm> : Inst32<(outs), ins, asm> {
  bits<4> r;
  bits<4> l;
  let Inst{15-14} = LENCODE_PARCELS2;
  let Inst{13-8} = opc;
  let Inst{7-4} = r;
  let Inst{3-0} = l;
  let Form = FORM_BR;
  let isBranch = 1;
  let isTerminator = 1;
}
class BrI48<bits<6> opc, dag ins, string asm> : Inst48<(outs), ins, asm> {
  bits<4> r;
  bits<4> l;
  let Inst{15-14} = LENCODE_PARCELS3;
  let Inst{13-8} = opc;
  let Inst{7-4} = r;
  let Inst{3-0} = l;
  let Form = FORM_BR;
  let isBranch = 1;
  let isTerminator = 1;
}

multiclass Branch<string mn, int opc, bit barrier> {
  let isBarrier = barrier in {
    def _0 : BrI16<opc, (ins brt0:$t), mn # "\t$t"> {
      bits<8> t;
      let Inst{7-0} = t;
    }
    def _1 : BrI32<opc, (ins brt1:$t), mn # "\t$t"> {
      bits<16> t;
      let r = 0;
      let l = 0;
      let Inst{31-16} = t;
    }
    def _2 : BrI48<opc, (ins brt2:$t), mn # "\t$t"> {
      bits<32> t;
      let r = 0;
      let l = 0;
      let Inst{31-16} = t{31-16};
      let Inst{47-32} = t{15-0};
    }
  }
}

// sob rd, label
multiclass SobForm<string mn> {
  def _1 : BrI32<OPGROUP_SOB, (ins GPR:$rd, brt1m:$t), mn # "\t$rd, $t"> {
    bits<4> rd;
    bits<16> t;
    let r = rd;
    let l = 0;
    let Inst{31-16} = t;
    let Form = FORM_SOB;
  }
  def _2 : BrI48<OPGROUP_SOB, (ins GPR:$rd, brt2:$t), mn # "\t$rd, $t"> {
    bits<4> rd;
    bits<32> t;
    let r = rd;
    let l = 0;
    let Inst{31-16} = t{31-16};
    let Inst{47-32} = t{15-0};
    let Form = FORM_SOB;
  }
}
// btag rd, #tag, label   (low = sense:1 tag:3)
multiclass TagForm<string mn, bit sense> {
  def _1 : BrI32<OPGROUP_TAG, (ins GPR:$rd, uimm3:$tag, brt1m:$t), mn # "\t$rd, $tag, $t"> {
    bits<4> rd;
    bits<3> tag;
    bits<16> t;
    let r = rd;
    let l = {sense, tag{2}, tag{1}, tag{0}};
    let Inst{31-16} = t;
    let Form = FORM_TAG;
  }
  def _2 : BrI48<OPGROUP_TAG, (ins GPR:$rd, uimm3:$tag, brt2:$t), mn # "\t$rd, $tag, $t"> {
    bits<4> rd;
    bits<3> tag;
    bits<32> t;
    let r = rd;
    let l = {sense, tag{2}, tag{1}, tag{0}};
    let Inst{31-16} = t{31-16};
    let Inst{47-32} = t{15-0};
    let Form = FORM_TAG;
  }
}

// cbCC: compare and branch.  Three flavours of encoding for the immediate form (opcode 0x28 short, 0x29 wide, 0x28 long), and
// the register form (0x2A, two lengths).  The condition is the number of the mnemonic.
multiclass CBranch<string mn, bits<4> cond> {
  let isBranch = 1, isTerminator = 1 in {
    def NAME : Inst32<(outs), (ins GPR:$rd, simm5:$imm, cbt1:$t), mn # "\t$rd, $imm, $t"> {
      bits<4> rd; bits<5> imm; bits<11> t;
      let Inst{15-14} = LENCODE_PARCELS2;
      let Inst{13-8} = OPGROUP_CBR;
      let Inst{7-4} = rd;
      let Inst{3-0} = cond;
      let Inst{31-27} = imm;
      let Inst{26-16} = t;
      let Form = FORM_CB;
    }
    def NAME # "_W" : Inst48<(outs), (ins GPR:$rd, simm16w:$imm, cbwt:$t), mn # "\t$rd, $imm, $t"> {
      bits<4> rd; bits<16> imm; bits<16> t;
      let Inst{15-14} = LENCODE_PARCELS3;
      let Inst{13-8} = OPGROUP_CBW;
      let Inst{7-4} = rd;
      let Inst{3-0} = cond;
      let Inst{31-16} = imm;
      let Inst{47-32} = t;
      let Form = FORM_CBW;
    }
    def NAME # "_L" : Inst48<(outs), (ins GPR:$rd, simm5w:$imm, cbt2:$t), mn # "\t$rd, $imm, $t"> {
      bits<4> rd; bits<5> imm; bits<27> t;
      let Inst{15-14} = LENCODE_PARCELS3;
      let Inst{13-8} = OPGROUP_CBR;
      let Inst{7-4} = rd;
      let Inst{3-0} = cond;
      let Inst{31-27} = imm;
      let Inst{26-16} = t{26-16};
      let Inst{47-32} = t{15-0};
      let Form = FORM_CB;
    }
    def NAME # "_RR1" : Inst32<(outs), (ins GPR:$ra, GPR:$rb, cbrt1:$t), mn # "\t$ra, $rb, $t"> {
      bits<4> ra; bits<4> rb; bits<12> t;
      let Inst{15-14} = LENCODE_PARCELS2;
      let Inst{13-8} = OPGROUP_CBRR;
      let Inst{7-4} = ra;
      let Inst{3-0} = rb;
      let Inst{31-28} = cond;
      let Inst{27-16} = t;
      let Form = FORM_CBR;
    }
    def NAME # "_RR2" : Inst48<(outs), (ins GPR:$ra, GPR:$rb, cbrt2:$t), mn # "\t$ra, $rb, $t"> {
      bits<4> ra; bits<4> rb; bits<28> t;
      let Inst{15-14} = LENCODE_PARCELS3;
      let Inst{13-8} = OPGROUP_CBRR;
      let Inst{7-4} = ra;
      let Inst{3-0} = rb;
      let Inst{31-28} = cond;
      let Inst{27-16} = t{27-16};
      let Inst{47-32} = t{15-0};
      let Form = FORM_CBR;
    }
  }
}

// ---- SYS ---------------------------------------------------------------------------------------------------------------------

class Sys0<string mn, bits<4> minor> : Inst16<(outs), (ins), mn> {
  let Inst{15-14} = LENCODE_PARCELS1;
  let Inst{13-8} = OPGROUP_SYS;
  let Inst{7-4} = 0;
  let Inst{3-0} = minor;
  let Form = FORM_SYS;
}
class SysReg1<string mn, bits<4> cls> : Inst16<(outs), (ins GPR:$a), mn # "\t$a"> {
  bits<4> a;
  let Inst{15-14} = LENCODE_PARCELS1;
  let Inst{13-8} = OPGROUP_SYS;
  let Inst{7-4} = cls;
  let Inst{3-0} = a;
  let Form = FORM_SYS;
}
class SysImm4<string mn, bits<4> cls> : Inst16<(outs), (ins uimm4:$n), mn # "\t$n"> {
  bits<4> n;
  let Inst{15-14} = LENCODE_PARCELS1;
  let Inst{13-8} = OPGROUP_SYS;
  let Inst{7-4} = cls;
  let Inst{3-0} = n;
  let Form = FORM_SYS;
}
// trap #n for n >= 16: the number is in parcel 1
class SysTrapL<string mn, bits<4> cls> : Inst32<(outs), (ins uimm8trap:$n), mn # "\t$n"> {
  bits<8> n;
  let Inst{15-14} = LENCODE_PARCELS2;
  let Inst{13-8} = OPGROUP_SYS;
  let Inst{7-4} = cls;
  let Inst{3-0} = 0;
  let Inst{31-24} = n;
  let Inst{23-16} = 0;
  let Form = FORM_SYS;
}
class SysProbe<string mn, bits<4> cls> : Inst32<(outs), (ins GPR:$rd, GPR:$rs), mn # "\t$rd, $rs"> {
  bits<4> rd; bits<4> rs;
  let Inst{15-14} = LENCODE_PARCELS2;
  let Inst{13-8} = OPGROUP_SYS;
  let Inst{7-4} = cls;
  let Inst{3-0} = rs;
  let Inst{31-28} = rd;
  let Inst{27-16} = 0;
  let Form = FORM_SYS;
}
// mfsr rd, name / mtsr name, rs: SYS class 0, minors 13 and 14, the system register in parcel 1
class SysRegMove<string mn, bits<4> minor, bit isMf> :
    Inst32<(outs), (ins GPR:$r, sysregop:$sr), !if(isMf, mn # "\t$r, $sr", mn # "\t$sr, $r")> {
  bits<4> r; bits<8> sr;
  let Inst{15-14} = LENCODE_PARCELS2;
  let Inst{13-8} = OPGROUP_SYS;
  let Inst{7-4} = 0;
  let Inst{3-0} = minor;
  let Inst{31-24} = sr;
  let Inst{23-20} = r;
  let Inst{19-16} = 0;
  let Form = FORM_SYS;
}
// set cc, rd: AESC, sub-opcode `set`, the condition in the x field
class SetCond<string mn> : Inst32<(outs), (ins ccop:$cc, GPR:$rd), mn # "\t$cc, $rd"> {
  bits<4> cc; bits<4> rd;
  let Inst{15-14} = LENCODE_PARCELS2;
  let Inst{13-8} = OPGROUP_AESC;
  let Inst{7-4} = rd;
  let Inst{3-0} = 0;
  let Inst{31-24} = SUBOP_SET;
  let Inst{23-20} = 0;
  let Inst{19-16} = cc;
  let Form = FORM_NONE;
}

// ---- BESC, MBLK, AESC, FESC: parcel 1 is sub:8 t:4 x:4 ---------------------------------------------------------------------

class EscBase<int grp, bits<8> sub, dag ins, string asm> : Inst32<(outs), ins, asm> {
  bits<4> rd;      // the reg field
  bits<4> ra;      // the low field
  bits<4> rb;      // t
  bits<4> rc;      // x
  let Inst{15-14} = LENCODE_PARCELS2;
  let Inst{13-8} = grp;
  let Inst{7-4} = rd;
  let Inst{3-0} = ra;
  let Inst{31-24} = sub;
  let Inst{23-20} = rb;
  let Inst{19-16} = rc;
}
class Esc2<int grp, string mn, bits<8> sub> : EscBase<grp, sub, (ins GPR:$ra, GPR:$rd), mn # "\t$ra, $rd"> {
  let rb = 0; let rc = 0;
}
class Esc3<int grp, string mn, bits<8> sub> : EscBase<grp, sub, (ins GPR:$ra, GPR:$rb, GPR:$rd), mn # "\t$ra, $rb, $rd"> {
  let rc = 0;
}
// the memory block instructions name their registers in the order of the fields: mcpy rd, rs, rn
class Esc3Blk<int grp, string mn, bits<8> sub> : EscBase<grp, sub, (ins GPR:$rd, GPR:$ra, GPR:$rb), mn # "\t$rd, $ra, $rb"> {
  let rc = 0;
}
class EscMval<int grp, string mn, bits<8> sub> : EscBase<grp, sub, (ins GPR:$rd, GPR:$rb), mn # "\t$rd, $rb"> {
  let ra = 0; let rc = 0;
}
class Esc4<int grp, string mn, bits<8> sub> : EscBase<grp, sub, (ins GPR:$ra, GPR:$rb, GPR:$rc, GPR:$rd), mn # "\t$ra, $rb, $rc, $rd"> {
}
// fcmp32 rd, rs: register first, as cmp
class EscCmp<int grp, string mn, bits<8> sub> : EscBase<grp, sub, (ins GPR:$rd, GPR:$ra), mn # "\t$rd, $ra"> {
  let rb = 0; let rc = 0;
}
// rori rs, #n, rd: parcel 1 is sub:8 count:8
class EscCount<int grp, string mn, bits<8> sub, Operand cnt> : Inst32<(outs), (ins GPR:$ra, cnt:$n, GPR:$rd), mn # "\t$ra, $n, $rd"> {
  bits<4> rd; bits<4> ra; bits<6> n;
  let Inst{15-14} = LENCODE_PARCELS2;
  let Inst{13-8} = grp;
  let Inst{7-4} = rd;
  let Inst{3-0} = ra;
  let Inst{31-24} = sub;
  let Inst{23-16} = {0, 0, n};
}
// dshr ra, rb, #n, rd: three parcels, the position in parcel 2
class EscDshr<int grp, string mn, bits<8> sub> : Inst48<(outs), (ins GPR:$ra, GPR:$rb, uimm6:$n, GPR:$rd), mn # "\t$ra, $rb, $n, $rd"> {
  bits<4> rd; bits<4> ra; bits<4> rb; bits<6> n;
  let Inst{15-14} = LENCODE_PARCELS3;
  let Inst{13-8} = grp;
  let Inst{7-4} = rd;
  let Inst{3-0} = ra;
  let Inst{31-24} = sub;
  let Inst{23-20} = rb;
  let Inst{19-16} = 0;
  let Inst{47-40} = {0, 0, n};
  let Inst{39-32} = 0;
}
// extb rs, #pos, #width, rd
class EscField<int grp, string mn, bits<8> sub> : Inst48<(outs), (ins GPR:$ra, uimm6:$pos, bwidth:$w, GPR:$rd), mn # "\t$ra, $pos, $w, $rd"> {
  bits<4> rd; bits<4> ra; bits<6> pos; bits<8> w;
  let Inst{15-14} = LENCODE_PARCELS3;
  let Inst{13-8} = grp;
  let Inst{7-4} = rd;
  let Inst{3-0} = ra;
  let Inst{31-24} = sub;
  let Inst{23-16} = 0;
  let Inst{47-40} = {0, 0, pos};
  let Inst{39-32} = w;
}

include "gen/PDP64InstrDefs.td"
