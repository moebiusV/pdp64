//===-- PDP64CallingConv.td - Calling conventions -----------*- tablegen -*-===//
//
// Appendix D of the manual: arguments in r0-r5, the rest in 8-byte stack slots;
// results in r0 (r1 for the second half of a pair); r8-r11, r15, r24-r31 and fp
// are saved by the callee (pcc's choice for r24-r31).  A value narrower than 64
// bits is passed extended to 64 (the lowering uses sign extension unless the
// argument is marked zeroext, as pcc does for int, short, char).
//
//===----------------------------------------------------------------------===//

def CC_PDP64 : CallingConv<[
  CCIfType<[i1, i8, i16, i32], CCPromoteToType<i64>>,
  CCIfType<[i64, f64, f32], CCAssignToReg<[R0, R1, R2, R3, R4, R5]>>,
  CCIfType<[i64, f64, f32], CCAssignToStack<8, 8>>
]>;

def RetCC_PDP64 : CallingConv<[
  CCIfType<[i1, i8, i16, i32], CCPromoteToType<i64>>,
  CCIfType<[i64, f64, f32], CCAssignToReg<[R0, R1]>>
]>;

def CSR_PDP64 : CalleeSavedRegs<(add R8, R9, R10, R11, R15,
                                     R24, R25, R26, R27, R28, R29, R30, R31)>;
