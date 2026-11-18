//===-- PDP64InstrInfo.td - Instruction definitions ---------*- tablegen -*-===//
//
// Stage 1 prints assembly text, so an instruction here is an asm string and a
// selection pattern; no encoding.  The mnemonics are the MN_* variables of
// gen/PDP64GenMnemonics.td (a mnemonic the grammar lacks is an error), the
// field widths are the variables of gen/PDP64GenLayout.td.
//
// Operand order is the assembler's: source first, destination last
// ("add rs, rd" is rd += rs); "cmp rd, src" is the exception (not used: the
// back end branches with cbCC, which carries the comparison).
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Operands and leaves
//===----------------------------------------------------------------------===//

def imm64  : Operand<i64>;                    // printed as a number
def disp   : Operand<i64>;                    // d(rN): DispBits signed
def scale  : Operand<i64>;                    // 1, 2, 4, 8
def symop  : Operand<i64>;                    // a symbol (+ offset): printed as an expression
def brtarget : Operand<OtherVT>;
def ccop   : Operand<i64> { let PrintMethod = "printCondCode"; }

class SImm<int n> : ImmLeaf<i64,
    !strconcat("return isInt<", !cast<string>(n), ">(Imm);")>;
def simm32 : SImm<AluImmBits>;                // the immediate of the ALU forms
def simm28 : SImm<DispBits>;                  // a displacement
def simm16 : SImm<CbImmBits>;                 // the immediate of cbCC
def bigimm : ImmLeaf<i64,
    !strconcat("return !isInt<", !cast<string>(MovImmBits), ">(Imm);")>;
def uimm6  : ImmLeaf<i64, [{ return Imm >= 0 && Imm < 64; }]>;
def scaleimm : ImmLeaf<i64, [{ return Imm == 1 || Imm == 2 || Imm == 4 || Imm == 8; }]>;
def mask8  : ImmLeaf<i64, [{ return Imm == 0xff; }]>;
def mask16 : ImmLeaf<i64, [{ return Imm == 0xffff; }]>;
def mask32 : ImmLeaf<i64, [{ return Imm == 0xffffffff; }]>;

// 64 - n for rol -> rori (the assembler takes both; used for rotr/rotl swaps)
def NegShift : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant((64 - N->getZExtValue()) & 63, SDLoc(N), MVT::i64);
}]>;
def to_tframeindex : SDNodeXForm<frameindex, [{
  return CurDAG->getTargetFrameIndex(cast<FrameIndexSDNode>(N)->getIndex(), MVT::i64);
}]>;
// the bits of a floating-point constant as the integer the register holds
def FPBits64 : SDNodeXForm<fpimm, [{
  return CurDAG->getTargetConstant(N->getValueAPF().bitcastToAPInt().getSExtValue(), SDLoc(N), MVT::i64);
}]>;
def FPBits32 : SDNodeXForm<fpimm, [{
  // a binary32 lives in the low 32 bits of the register, sign-extended
  return CurDAG->getTargetConstant(
      (int64_t)(int32_t)N->getValueAPF().bitcastToAPInt().getZExtValue(), SDLoc(N), MVT::i64);
}]>;

// The address modes are matched in C++ (PDP64ISelDAGToDAG.cpp).
def addrri : ComplexPattern<iPTR, 2, "SelectAddrRI", [], [], 3>;  // d(rN)
def addrrx : ComplexPattern<iPTR, 4, "SelectAddrRX", [], [], 5>;  // d(rN)(rX*s)
def leasr  : ComplexPattern<i64, 3, "SelectLeaRX", [add], [], 5>; // rN + (rX << s)

//===----------------------------------------------------------------------===//
// SelectionDAG nodes
//===----------------------------------------------------------------------===//

def SDT_PDP64Call    : SDTypeProfile<0, -1, [SDTCisVT<0, iPTR>]>;
def SDT_PDP64Wrapper : SDTypeProfile<1, 1, [SDTCisSameAs<0, 1>, SDTCisVT<0, i64>]>;
def SDT_PDP64BrCC    : SDTypeProfile<0, 4, [SDTCisSameAs<0, 1>, SDTCisVT<2, i64>, SDTCisVT<3, OtherVT>]>;
def SDT_PDP64SelCC   : SDTypeProfile<1, 5, [SDTCisSameAs<1, 2>, SDTCisVT<3, i64>, SDTCisSameAs<0, 4>, SDTCisSameAs<0, 5>]>;
def SDT_PDP64CallSeqStart : SDCallSeqStart<[SDTCisVT<0, i64>, SDTCisVT<1, i64>]>;
def SDT_PDP64CallSeqEnd   : SDCallSeqEnd<[SDTCisVT<0, i64>, SDTCisVT<1, i64>]>;
def SDT_PDP64F32ToI64  : SDTypeProfile<1, 1, [SDTCisVT<0, i64>, SDTCisVT<1, f32>]>;
def SDT_PDP64I64ToF32  : SDTypeProfile<1, 1, [SDTCisVT<0, f32>, SDTCisVT<1, i64>]>;

def pdp64call : SDNode<"PDP64ISD::CALL", SDT_PDP64Call,
                       [SDNPHasChain, SDNPOutGlue, SDNPOptInGlue, SDNPVariadic]>;
def pdp64ret  : SDNode<"PDP64ISD::RET_GLUE", SDTNone,
                       [SDNPHasChain, SDNPOptInGlue, SDNPVariadic]>;
def pdp64wrap : SDNode<"PDP64ISD::WRAPPER", SDT_PDP64Wrapper>;
def pdp64brcc : SDNode<"PDP64ISD::BR_CC", SDT_PDP64BrCC, [SDNPHasChain]>;
def pdp64selcc : SDNode<"PDP64ISD::SELECT_CC", SDT_PDP64SelCC>;
def pdp64f32toi64 : SDNode<"PDP64ISD::F32_TO_I64", SDT_PDP64F32ToI64>;
def pdp64i64tof32 : SDNode<"PDP64ISD::I64_TO_F32", SDT_PDP64I64ToF32>;
def callseq_start : SDNode<"ISD::CALLSEQ_START", SDT_PDP64CallSeqStart,
                           [SDNPHasChain, SDNPOutGlue]>;
def callseq_end   : SDNode<"ISD::CALLSEQ_END", SDT_PDP64CallSeqEnd,
                           [SDNPHasChain, SDNPOptInGlue, SDNPOutGlue]>;

//===----------------------------------------------------------------------===//
// Instruction base class
//===----------------------------------------------------------------------===//

class PI<dag outs, dag ins, string asmstr, list<dag> pattern = []> : Instruction {
  let Namespace = "PDP64";
  let OutOperandList = outs;
  let InOperandList = ins;
  let AsmString = asmstr;
  let Pattern = pattern;
  let hasSideEffects = 0;
}

//===----------------------------------------------------------------------===//
// Register moves and constants
//===----------------------------------------------------------------------===//

let isMoveReg = 1 in {
def MOVrr  : PI<(outs GPR:$rd), (ins GPR:$rs), !strconcat(MN_movq, " $rs, $rd")>;
def MOVrrA : PI<(outs GPRALL:$rd), (ins GPRALL:$rs), !strconcat(MN_movq, " $rs, $rd")>;
}

let isReMaterializable = 1, isAsCheapAsAMove = 1 in {
def MOVI : PI<(outs GPR:$rd), (ins imm64:$i), !strconcat(MN_movq, " #$i, $rd"),
              [(set i64:$rd, simm32:$i)]>;
// a 64-bit constant from the literal pool (as64 makes the pool)
def MOVK : PI<(outs GPR:$rd), (ins imm64:$i), !strconcat(MN_movq, " =$i, $rd"),
              [(set i64:$rd, bigimm:$i)]>;
def CLR  : PI<(outs GPR:$rd), (ins), !strconcat(MN_clr, " $rd"), [(set i64:$rd, 0)]>;
}
def fpsmall : PatLeaf<(fpimm), [{
  return isInt<32>(N->getValueAPF().bitcastToAPInt().getSExtValue()); }]>;
def fpbig   : PatLeaf<(fpimm), [{
  return !isInt<32>(N->getValueAPF().bitcastToAPInt().getSExtValue()); }]>;
def : Pat<(f64 fpsmall:$f), (f64 (MOVI (FPBits64 fpimm:$f)))>;
def : Pat<(f64 fpbig:$f),   (f64 (MOVK (FPBits64 fpimm:$f)))>;
def : Pat<(f32 fpimm:$f),   (f32 (MOVI (FPBits32 fpimm:$f)))>;

// the same value, a different type: no instruction
def : Pat<(f64 (bitconvert i64:$x)), (f64 (COPY_TO_REGCLASS $x, GPR))>;
def : Pat<(i64 (bitconvert f64:$x)), (i64 (COPY_TO_REGCLASS $x, GPR))>;
def : Pat<(i64 (pdp64f32toi64 f32:$x)), (i64 (COPY_TO_REGCLASS $x, GPR))>;
def : Pat<(f32 (pdp64i64tof32 i64:$x)), (f32 (COPY_TO_REGCLASS $x, GPR))>;

//===----------------------------------------------------------------------===//
// Two-address ALU: "op rs, rd" is rd = rd op rs; the immediate form is a
// signed AluImmBits-bit field.
//===----------------------------------------------------------------------===//

multiclass ALU<string mn, SDPatternOperator op, bit comm = 0> {
  let Constraints = "$rd = $rs1" in {
    def rr : PI<(outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2), !strconcat(mn, " $rs2, $rd"),
                [(set i64:$rd, (op i64:$rs1, i64:$rs2))]> { let isCommutable = comm; }
    def ri : PI<(outs GPR:$rd), (ins GPR:$rs1, imm64:$imm), !strconcat(mn, " #$imm, $rd"),
                [(set i64:$rd, (op i64:$rs1, simm32:$imm))]>;
  }
}
defm ADD : ALU<MN_add, add, 1>;
defm SUB : ALU<MN_sub, sub>;
defm AND : ALU<MN_and, and, 1>;
defm OR  : ALU<MN_bis, or, 1>;
defm XOR : ALU<MN_xor, xor, 1>;
defm MUL : ALU<MN_mul, mul, 1>;

// shifts: the count is a register or a constant 0..63
multiclass SHIFT<string mn, SDPatternOperator op> {
  let Constraints = "$rd = $rs1" in {
    def rr : PI<(outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2), !strconcat(mn, " $rs2, $rd"),
                [(set i64:$rd, (op i64:$rs1, i64:$rs2))]>;
    def ri : PI<(outs GPR:$rd), (ins GPR:$rs1, imm64:$imm), !strconcat(mn, " #$imm, $rd"),
                [(set i64:$rd, (op i64:$rs1, uimm6:$imm))]>;
  }
}
defm SHL : SHIFT<MN_shl, shl>;
defm SHR : SHIFT<MN_shr, srl>;
defm SAR : SHIFT<MN_sar, sra>;

// rotates by a constant: rori rs, #n, rd ; rol is the assembler's spelling of 64-n
def RORI : PI<(outs GPR:$rd), (ins GPR:$rs, imm64:$imm), !strconcat(MN_rori, " $rs, #$imm, $rd"),
              [(set i64:$rd, (rotr i64:$rs, uimm6:$imm))]>;
def ROLI : PI<(outs GPR:$rd), (ins GPR:$rs, imm64:$imm), !strconcat(MN_rol, " $rs, #$imm, $rd"),
              [(set i64:$rd, (rotl i64:$rs, uimm6:$imm))]>;

// one-register operations (in place)
let Constraints = "$rd = $rs" in {
def NEG : PI<(outs GPR:$rd), (ins GPR:$rs), !strconcat(MN_neg, " $rd"),
             [(set i64:$rd, (ineg i64:$rs))]>;
def COM : PI<(outs GPR:$rd), (ins GPR:$rs), !strconcat(MN_com, " $rd"),
             [(set i64:$rd, (not i64:$rs))]>;
}
let Constraints = "$rd = $rs1" in {
// bic rs, rd: rd &= ~rs
def BIC : PI<(outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2), !strconcat(MN_bic, " $rs2, $rd"),
             [(set i64:$rd, (and i64:$rs1, (not i64:$rs2)))]>;
// mulh rs, rd: the high 64 bits of the signed product
def MULH : PI<(outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2), !strconcat(MN_mulh, " $rs2, $rd"),
              [(set i64:$rd, (mulhs i64:$rs1, i64:$rs2))]> { let isCommutable = 1; }
}

// extensions and the masks that are extensions
def SEXTB : PI<(outs GPR:$rd), (ins GPR:$rs), !strconcat(MN_movb, " $rs, $rd"),
               [(set i64:$rd, (sext_inreg i64:$rs, i8))]>;
def SEXTW : PI<(outs GPR:$rd), (ins GPR:$rs), !strconcat(MN_movw, " $rs, $rd"),
               [(set i64:$rd, (sext_inreg i64:$rs, i16))]>;
def SEXTL : PI<(outs GPR:$rd), (ins GPR:$rs), !strconcat(MN_movl, " $rs, $rd"),
               [(set i64:$rd, (sext_inreg i64:$rs, i32))]>;
let AddedComplexity = 10 in {
def ZEXTB : PI<(outs GPR:$rd), (ins GPR:$rs), !strconcat(MN_movzb, " $rs, $rd"),
               [(set i64:$rd, (and i64:$rs, mask8))]>;
def ZEXTW : PI<(outs GPR:$rd), (ins GPR:$rs), !strconcat(MN_movzw, " $rs, $rd"),
               [(set i64:$rd, (and i64:$rs, mask16))]>;
def ZEXTL : PI<(outs GPR:$rd), (ins GPR:$rs), !strconcat(MN_movzl, " $rs, $rd"),
               [(set i64:$rd, (and i64:$rs, mask32))]>;
}

// three-register operations: "op ra, rb, rd" is rd = ra op rb
multiclass RegR3<string mn, SDPatternOperator op, bit comm = 0> {
  def NAME : PI<(outs GPR:$rd), (ins GPR:$ra, GPR:$rb), !strconcat(mn, " $ra, $rb, $rd"),
                [(set i64:$rd, (op i64:$ra, i64:$rb))]> { let isCommutable = comm; }
}
defm DIV : RegR3<MN_div, sdiv>;
defm DIVU : RegR3<MN_divu, udiv>;
defm MOD : RegR3<MN_mod, srem>;
defm MODU : RegR3<MN_modu, urem>;
defm MULHU : RegR3<MN_mulhu, mulhu, 1>;
defm MIN : RegR3<MN_min, smin, 1>;
defm MINU : RegR3<MN_minu, umin, 1>;
defm MAX : RegR3<MN_max, smax, 1>;
defm MAXU : RegR3<MN_maxu, umax, 1>;

// bit counting: "op rs, rd" (the count of zero is 64)
multiclass RegR2<string mn, SDPatternOperator op> {
  def NAME : PI<(outs GPR:$rd), (ins GPR:$rs), !strconcat(mn, " $rs, $rd"),
                [(set i64:$rd, (op i64:$rs))]>;
}
defm CLZ : RegR2<MN_clz, ctlz>;
defm CTZ : RegR2<MN_ctz, cttz>;
defm POPCNT : RegR2<MN_popcnt, ctpop>;
defm BSWAP : RegR2<MN_bswap, bswap>;
defm BITREV : RegR2<MN_bitrev, bitreverse>;

//===----------------------------------------------------------------------===//
// Loads and stores: d(rN), d(rN)(rX*s), symbol (pc-relative)
//===----------------------------------------------------------------------===//

multiclass LD<string mn, SDPatternOperator ld, ValueType vt> {
  def _R : PI<(outs GPR:$rd), (ins GPR:$b, disp:$d), !strconcat(mn, " $d($b), $rd"),
              [(set vt:$rd, (ld (addrri i64:$b, simm28:$d)))]> { let mayLoad = 1; }
  def _X : PI<(outs GPR:$rd), (ins GPR:$b, disp:$d, GPR:$i, scale:$s),
              !strconcat(mn, " $d($b)($i*$s), $rd"),
              [(set vt:$rd, (ld (addrrx i64:$b, simm28:$d, i64:$i, scaleimm:$s)))]> { let mayLoad = 1; }
  def _S : PI<(outs GPR:$rd), (ins symop:$g), !strconcat(mn, " $g, $rd"),
              [(set vt:$rd, (ld (pdp64wrap tglobaladdr:$g)))]> { let mayLoad = 1; }
}
multiclass ST<string mn, SDPatternOperator st, ValueType vt> {
  def _R : PI<(outs), (ins GPR:$rs, GPR:$b, disp:$d), !strconcat(mn, " $rs, $d($b)"),
              [(st vt:$rs, (addrri i64:$b, simm28:$d))]> { let mayStore = 1; }
  def _X : PI<(outs), (ins GPR:$rs, GPR:$b, disp:$d, GPR:$i, scale:$s),
              !strconcat(mn, " $rs, $d($b)($i*$s)"),
              [(st vt:$rs, (addrrx i64:$b, simm28:$d, i64:$i, scaleimm:$s))]> { let mayStore = 1; }
  def _S : PI<(outs), (ins GPR:$rs, symop:$g), !strconcat(mn, " $rs, $g"),
              [(st vt:$rs, (pdp64wrap tglobaladdr:$g))]> { let mayStore = 1; }
}
// a load with no extension pattern of its own: a sign-extending load serves the
// any-extending one (a value narrower than 64 bits is kept extended in a register)
defm LDQ  : LD<MN_movq,  load, i64>;
defm LDFD : LD<MN_movq,  load, f64>;
defm LDFS : LD<MN_movl,  load, f32>;       // movl: sign-extends, as a binary32 is kept
defm LDL  : LD<MN_movl,  sextloadi32, i64>;
defm LDLA : LD<MN_movl,  extloadi32, i64>;
defm LDW  : LD<MN_movw,  sextloadi16, i64>;
defm LDWA : LD<MN_movw,  extloadi16, i64>;
defm LDB  : LD<MN_movb,  sextloadi8, i64>;
defm LDBA : LD<MN_movb,  extloadi8, i64>;
defm LDZL : LD<MN_movzl, zextloadi32, i64>;
defm LDZW : LD<MN_movzw, zextloadi16, i64>;
defm LDZB : LD<MN_movzb, zextloadi8, i64>;
defm LDZ1 : LD<MN_movzb, zextloadi1, i64>;
defm LDA1 : LD<MN_movzb, extloadi1, i64>;
defm STQ  : ST<MN_movq,  store, i64>;
defm STFD : ST<MN_movq,  store, f64>;
defm STFS : ST<MN_movl,  store, f32>;
defm STL  : ST<MN_movl,  truncstorei32, i64>;
defm STW  : ST<MN_movw,  truncstorei16, i64>;
defm STB  : ST<MN_movb,  truncstorei8, i64>;

// post-increment and pre-decrement: "mn (rN)+, rd" loads and then adds the size
// of the access to rN, "mn -(rN), rd" subtracts it first.  Selected in C++
// (tryIndexed in PDP64ISelDAGToDAG.cpp): the size is the size of the access.
multiclass IDXLD<string mn> {
  let Constraints = "$wb = $base", mayLoad = 1 in {
    def _PI : PI<(outs GPR:$rd, GPR:$wb), (ins GPR:$base), !strconcat(mn, " ($base)+, $rd")>;
    def _PD : PI<(outs GPR:$rd, GPR:$wb), (ins GPR:$base), !strconcat(mn, " -($base), $rd")>;
  }
}
multiclass IDXST<string mn> {
  let Constraints = "$wb = $base", mayStore = 1 in {
    def _PI : PI<(outs GPR:$wb), (ins GPR:$rs, GPR:$base), !strconcat(mn, " $rs, ($base)+")>;
    def _PD : PI<(outs GPR:$wb), (ins GPR:$rs, GPR:$base), !strconcat(mn, " $rs, -($base)")>;
  }
}
defm LDQX  : IDXLD<MN_movq>;
defm LDLX  : IDXLD<MN_movl>;
defm LDWX  : IDXLD<MN_movw>;
defm LDBX  : IDXLD<MN_movb>;
defm LDZLX : IDXLD<MN_movzl>;
defm LDZWX : IDXLD<MN_movzw>;
defm LDZBX : IDXLD<MN_movzb>;
defm STQX  : IDXST<MN_movq>;
defm STLX  : IDXST<MN_movl>;
defm STWX  : IDXST<MN_movw>;
defm STBX  : IDXST<MN_movb>;

// lea: three-address add of a displacement, a scaled index, a symbol
def LEA_R : PI<(outs GPR:$rd), (ins GPR:$b, disp:$d), !strconcat(MN_lea, " $d($b), $rd")>;
def LEA_X : PI<(outs GPR:$rd), (ins GPR:$b, disp:$d, GPR:$i, scale:$s),
               !strconcat(MN_lea, " $d($b)($i*$s), $rd")>;
def LEA_S : PI<(outs GPR:$rd), (ins symop:$g), !strconcat(MN_lea, " $g, $rd")>;

let AddedComplexity = 5 in {
def : Pat<(i64 (add i64:$b, simm28:$d)), (LEA_R $b, simm28:$d)>;
def : Pat<(i64 (leasr i64:$b, i64:$i, scaleimm:$s)), (LEA_X $b, 0, $i, $s)>;
}
def : Pat<(i64 frameindex:$fi), (LEA_R (i64 (to_tframeindex $fi)), 0)>;
def : Pat<(i64 (pdp64wrap tglobaladdr:$g)), (LEA_S tglobaladdr:$g)>;
def : Pat<(i64 (pdp64wrap texternalsym:$g)), (LEA_S texternalsym:$g)>;
def : Pat<(i64 (pdp64wrap tjumptable:$g)), (LEA_S tjumptable:$g)>;
def : Pat<(i64 (pdp64wrap tblockaddress:$g)), (LEA_S tblockaddress:$g)>;
def : Pat<(i64 (pdp64wrap tconstpool:$g)), (LEA_S tconstpool:$g)>;

// the stack pointer and the frame pointer (prologue, epilogue, dynamic alloca)
let Defs = [R14], Uses = [R14] in {
def ADDSP : PI<(outs), (ins imm64:$i), !strconcat(MN_add, " #$i, sp")>;
def SUBSP : PI<(outs), (ins imm64:$i), !strconcat(MN_sub, " #$i, sp")>;
}
let Defs = [R14], Uses = [R14, R13] in
def FPTOSP : PI<(outs), (ins), !strconcat(MN_movq, " fp, sp")>;
let Defs = [R13], Uses = [R14] in
def SPTOFP : PI<(outs), (ins), !strconcat(MN_movq, " sp, fp")>;
let Defs = [R14], Uses = [R14], mayStore = 1 in
def PUSHFP : PI<(outs), (ins), !strconcat(MN_push, " fp")>;
let Defs = [R14, R13], Uses = [R14], mayLoad = 1 in
def POPFP : PI<(outs), (ins), !strconcat(MN_pop, " fp")>;

//===----------------------------------------------------------------------===//
// Control flow
//===----------------------------------------------------------------------===//

let isBranch = 1, isTerminator = 1, isBarrier = 1 in {
def BR : PI<(outs), (ins brtarget:$dst), !strconcat(MN_br, " $dst"), [(br bb:$dst)]>;
}
let isBranch = 1, isTerminator = 1, isBarrier = 1, isIndirectBranch = 1 in
def JMPR : PI<(outs), (ins GPR:$rs), !strconcat(MN_jmp, " ($rs)"), [(brind i64:$rs)]>;

// compare and branch: cbCC ra, rb|#imm, label (the assembler picks the length)
let isBranch = 1, isTerminator = 1 in {
def CB_rr : PI<(outs), (ins GPR:$a, GPR:$b, ccop:$cc, brtarget:$dst),
               "cb${cc} $a, $b, $dst",
               [(pdp64brcc i64:$a, i64:$b, (i64 timm:$cc), bb:$dst)]>;
def CB_ri : PI<(outs), (ins GPR:$a, imm64:$i, ccop:$cc, brtarget:$dst),
               "cb${cc} $a, #$i, $dst",
               [(pdp64brcc i64:$a, simm16:$i, (i64 timm:$cc), bb:$dst)]>;
// a branch on the flags (after a floating-point compare)
def BFLAG : PI<(outs), (ins ccop:$cc, brtarget:$dst), "b${cc} $dst">;  // only in the printer
// the floating-point compare-and-branch: one instruction here, printed as
// fcmp + b<cc> by the AsmPrinter (PDP64::fpSequence), so that nothing can be
// scheduled between the compare and the branch (the flags are not modelled)
let isCodeGenOnly = 1 in {
def FBR_D : PI<(outs), (ins GPR:$a, GPR:$b, ccop:$cc, brtarget:$dst), "# FBR_D",
               [(pdp64brcc f64:$a, f64:$b, (i64 timm:$cc), bb:$dst)]>;
def FBR_S : PI<(outs), (ins GPR:$a, GPR:$b, ccop:$cc, brtarget:$dst), "# FBR_S",
               [(pdp64brcc f32:$a, f32:$b, (i64 timm:$cc), bb:$dst)]>;
}
}
def FCMP_D : PI<(outs), (ins GPR:$a, GPR:$b), !strconcat(MN_fcmp, " $a, $b")>;
def FCMP_S : PI<(outs), (ins GPR:$a, GPR:$b), !strconcat(MN_fcmp32, " $a, $b")>;

// select: a diamond made by the custom inserter
let usesCustomInserter = 1 in {
def SEL_RR : PI<(outs GPR:$rd), (ins GPR:$a, GPR:$b, ccop:$cc, GPR:$t, GPR:$f), "# SEL_RR">;
def SEL_RI : PI<(outs GPR:$rd), (ins GPR:$a, imm64:$i, ccop:$cc, GPR:$t, GPR:$f), "# SEL_RI">;
def SEL_FD : PI<(outs GPR:$rd), (ins GPR:$a, GPR:$b, ccop:$cc, GPR:$t, GPR:$f), "# SEL_FD">;
def SEL_FS : PI<(outs GPR:$rd), (ins GPR:$a, GPR:$b, ccop:$cc, GPR:$t, GPR:$f), "# SEL_FS">;
}
multiclass SelPats<ValueType vt> {
  def : Pat<(vt (pdp64selcc i64:$a, i64:$b, (i64 timm:$cc), vt:$t, vt:$f)),
            (SEL_RR $a, $b, timm:$cc, $t, $f)>;
  def : Pat<(vt (pdp64selcc i64:$a, simm16:$i, (i64 timm:$cc), vt:$t, vt:$f)),
            (SEL_RI $a, simm16:$i, timm:$cc, $t, $f)>;
  def : Pat<(vt (pdp64selcc f64:$a, f64:$b, (i64 timm:$cc), vt:$t, vt:$f)),
            (SEL_FD $a, $b, timm:$cc, $t, $f)>;
  def : Pat<(vt (pdp64selcc f32:$a, f32:$b, (i64 timm:$cc), vt:$t, vt:$f)),
            (SEL_FS $a, $b, timm:$cc, $t, $f)>;
}
defm : SelPats<i64>;
defm : SelPats<f64>;
defm : SelPats<f32>;

// calls: call sym / call (rN); the result is in r0 (r1)
let isCall = 1, Uses = [R14] in {
def CALL  : PI<(outs), (ins symop:$f), !strconcat(MN_call, " $f"), [(pdp64call tglobaladdr:$f)]>;
def CALLX : PI<(outs), (ins symop:$f), !strconcat(MN_call, " $f"), [(pdp64call texternalsym:$f)]>;
def CALLR : PI<(outs), (ins GPR:$r), !strconcat(MN_call, " ($r)"), [(pdp64call i64:$r)]>;
}
let isReturn = 1, isTerminator = 1, isBarrier = 1 in
def RET : PI<(outs), (ins), MN_ret, [(pdp64ret)]>;

let Defs = [R14], Uses = [R14] in {
def ADJCALLSTACKDOWN : PI<(outs), (ins imm64:$a1, imm64:$a2), "# ADJCALLSTACKDOWN $a1, $a2",
                          [(callseq_start timm:$a1, timm:$a2)]>;
def ADJCALLSTACKUP   : PI<(outs), (ins imm64:$a1, imm64:$a2), "# ADJCALLSTACKUP $a1, $a2",
                          [(callseq_end timm:$a1, timm:$a2)]>;
}
// the breakpoint (vector 15): llvm.debugtrap
let isBarrier = 1, isTerminator = 1, hasSideEffects = 1 in
def BPT : PI<(outs), (ins), MN_bpt, [(debugtrap)]>;

//===----------------------------------------------------------------------===//
// The check instructions (errata 144-153, 159, 160): a failed check is a fault on
// vector 16 whose EPC is the instruction.  ctCC rs, rb|#imm traps when "rs CC rb"
// is true (the condition of cbCC), cteq rs / ctne rs when rs is zero / not zero,
// chk2 rs, rlo, rhi unless rlo <= rs < rhi (signed).  The last operand of each
// is the KIND of the table of check sites (1 bounds, 2 null, 3 range, 4
// assertion, 0 unknown); the AsmPrinter writes `.chk KIND, "file", LINE` before it
// (and nothing when KIND is 0 and there is no debug location).  They come from
// PDP64CheckFold, which turns "conditional branch to a block that only traps".
//===----------------------------------------------------------------------===//
def CheckKindXF : SDNodeXForm<timm, [{
  return CurDAG->getTargetConstant(pdp64CheckKindOfUbsan(N->getZExtValue()), SDLoc(N), MVT::i64);
}]>;
let hasSideEffects = 1 in {
// an unconditional trap: ctcc of anything against zero (every unsigned value is higher than or the same as 0)
let isBarrier = 1, isTerminator = 1 in
def TRAPCHK : PI<(outs), (ins imm64:$kind), !strconcat(MN_ctcc, " r0, #0")>;
def CT_rr : PI<(outs), (ins GPR:$a, GPR:$b, ccop:$cc, imm64:$kind), "ct${cc} $a, $b">;
def CT_ri : PI<(outs), (ins GPR:$a, imm64:$i, ccop:$cc, imm64:$kind), "ct${cc} $a, #$i">;
def CT_z  : PI<(outs), (ins GPR:$a, ccop:$cc, imm64:$kind), "ct${cc} $a">;
def CHK2  : PI<(outs), (ins GPR:$a, GPR:$lo, GPR:$hi, imm64:$kind), !strconcat(MN_chk2, " $a, $lo, $hi")>;
}
def : Pat<(trap), (TRAPCHK 0)>;
def : Pat<(ubsantrap timm:$k), (TRAPCHK (CheckKindXF timm:$k))>;
def NOP : PI<(outs), (ins), MN_nop>;

//===----------------------------------------------------------------------===//
// Floating point: binary64 in a register, binary32 in the low 32 bits
// sign-extended.  "op rs, rd" is rd = rd op rs.
//===----------------------------------------------------------------------===//

multiclass FALU<string mn, ValueType vt, SDPatternOperator op, bit comm = 0> {
  let Constraints = "$rd = $rs1" in
  def NAME : PI<(outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2), !strconcat(mn, " $rs2, $rd"),
                [(set vt:$rd, (op vt:$rs1, vt:$rs2))]> { let isCommutable = comm; }
}
defm FADD_D : FALU<MN_fadd, f64, fadd, 1>;
defm FSUB_D : FALU<MN_fsub, f64, fsub>;
defm FMUL_D : FALU<MN_fmul, f64, fmul, 1>;
defm FDIV_D : FALU<MN_fdiv, f64, fdiv>;
defm FADD_S : FALU<MN_fadd32, f32, fadd, 1>;
defm FSUB_S : FALU<MN_fsub32, f32, fsub>;
defm FMUL_S : FALU<MN_fmul32, f32, fmul, 1>;
defm FDIV_S : FALU<MN_fdiv32, f32, fdiv>;

multiclass FUN<string mn, ValueType dt, ValueType st, SDPatternOperator op> {
  def NAME : PI<(outs GPR:$rd), (ins GPR:$rs), !strconcat(mn, " $rs, $rd"),
                [(set dt:$rd, (op st:$rs))]>;
}
defm FSQRT_D : FUN<MN_fsqrt, f64, f64, fsqrt>;
defm FSQRT_S : FUN<MN_fsqrt32, f32, f32, fsqrt>;
defm FNEG_D  : FUN<MN_fneg, f64, f64, fneg>;
defm FABS_D  : FUN<MN_fabs, f64, f64, fabs>;
defm FCVT_SD : FUN<MN_fcvtsd, f64, f32, fpextend>;
defm FCVT_DS : FUN<MN_fcvtds, f32, f64, fpround>;
defm FCVT_QD : FUN<MN_fcvtqd, f64, i64, sint_to_fp>;
defm FCVT_DQ : FUN<MN_fcvtdq, i64, f64, fp_to_sint>;
defm FCVT_QUD : FUN<MN_fcvtqud, f64, i64, uint_to_fp>;
defm FCVT_DQU : FUN<MN_fcvtdqu, i64, f64, fp_to_uint>;

// binary32 negate and absolute value on the sign-extended bits
def : Pat<(f32 (fneg f32:$a)), (f32 (XORri $a, -2147483648))>;
def : Pat<(f32 (fabs f32:$a)), (f32 (ANDri $a, 2147483647))>;
// conversions of a binary32 through the binary64 (the double rounding of an
// i64 -> f32 is the price of having no direct instruction)
def : Pat<(f32 (sint_to_fp i64:$x)), (f32 (FCVT_DS (f64 (FCVT_QD $x))))>;
def : Pat<(f32 (uint_to_fp i64:$x)), (f32 (FCVT_DS (f64 (FCVT_QUD $x))))>;
def : Pat<(i64 (fp_to_sint f32:$x)), (i64 (FCVT_DQ (f64 (FCVT_SD $x))))>;
def : Pat<(i64 (fp_to_uint f32:$x)), (i64 (FCVT_DQU (f64 (FCVT_SD $x))))>;
