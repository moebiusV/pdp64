//===-- PDP64InstrFormats.td - Instruction formats ---------------*- tablegen -*-===//
//
// An instruction is 1, 2 or 3 parcels of 16 bits.  `Inst` holds them little-endian: parcel 0 in bits 15-0, parcel 1 in
// bits 31-16, parcel 2 in bits 47-32.  Inside a parcel the bits are numbered as in the architecture's diagrams (and in
// spec/pdp64.hbnf.in, which reads them from the most significant bit): parcel 0 is len:2 opc:6 reg:4 low:4.
// A displacement or immediate that spans parcels has its high part in parcel 1 and the rest in parcel 2.
//
//===----------------------------------------------------------------------===//

class PDP64Inst<int sz, dag outs, dag ins, string asm> : Instruction {
  let Namespace = "PDP64";
  let Size = sz;
  let OutOperandList = outs;
  let InOperandList = ins;
  let AsmString = asm;

  // TSFlags: what the C++ needs to know about a record (the numbers are those of PDP64Layout.h)
  bits<5> Form = FORM_NONE;      // the form of the operand that may have to grow: a register, an addressing mode, a branch ...
  bits<2> Stride = 3;            // log2 of the default stride of (rN)+ and -(rN)
  bit MemFirst = 0;              // the memory operand is operand 1 (a register operand comes first)
  bit UImm = 0;                  // the immediate is unsigned (pushm, popm masks)
  let TSFlags{4-0} = Form;
  let TSFlags{6-5} = Stride;
  let TSFlags{7} = MemFirst;
  let TSFlags{8} = UImm;
}

class Inst16<dag outs, dag ins, string asm> : PDP64Inst<2, outs, ins, asm> {
  field bits<16> Inst;
}
class Inst32<dag outs, dag ins, string asm> : PDP64Inst<4, outs, ins, asm> {
  field bits<32> Inst;
}
class Inst48<dag outs, dag ins, string asm> : PDP64Inst<6, outs, ins, asm> {
  field bits<48> Inst;
}
