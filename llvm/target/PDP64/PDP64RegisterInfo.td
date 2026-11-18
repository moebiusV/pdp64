//===-- PDP64RegisterInfo.td - Registers of the pdp64 --------*- tablegen -*-===//

class PDP64Reg<bits<5> num, string n> : Register<n> {
  let HWEncoding{4-0} = num;
  let Namespace = "PDP64";
}

// r0..r31 (generated); r14 is sp, r13 is fp, r12 is the linker scratch.
include "gen/PDP64GenRegs.td"

// One class holds integers, pointers and floating point alike (a binary32 is
// the low 32 bits of a register, sign-extended: appendix D of the manual).  The
// order is the allocation order: the caller-saved registers first (r0-r5 carry
// arguments), then the callee-saved ones.  r12 (scratch), fp and sp are not
// allocatable.
def GPR : RegisterClass<"PDP64", [i64, f64, f32], 64,
    (add R0, R1, R2, R3, R4, R5, R6, R7,
         R16, R17, R18, R19, R20, R21, R22, R23,
         R8, R9, R10, R11, R15,
         R24, R25, R26, R27, R28, R29, R30, R31)>;

// Every register, for the copies the frame code makes (fp, sp).
def GPRALL : RegisterClass<"PDP64", [i64], 64, (add GPR, R12, R13, R14)>;
