/* pdp64 ELF constants shared by as64, ld64 and sim64 (docs/elf-pdp64.md). */
#ifndef RELOCS_H
#define RELOCS_H
#define EM_PDP64 0xF064			/* private use: no machine number has been assigned */

/* Relocation types.  The "INSN" ones patch the last 16*len bits of an instruction whose first parcel is at r_offset;
   the field width therefore comes from the `len` bits of that parcel, and the linker may not change it. */
#define R_PDP64_NONE      0
#define R_PDP64_D64       1		/* 64-bit data: S + A */
#define R_PDP64_D32       2		/* 32-bit data: S + A, must fit unsigned or signed 32 */
#define R_PDP64_INSN_ABS  3		/* immediate or absolute operand: S + A, signed, in the instruction's wide field */
#define R_PDP64_INSN_PC   4		/* d(PC) operand: S + A - P, in bytes */
#define R_PDP64_INSN_BR   5		/* branch: (S + A - P) / 2, in parcels */
#define R_PDP64_D32_PC    7		/* 32-bit data: S + A - P, a signed distance from the field itself (the table of check sites, `.bugrec`) */
#define R_PDP64_ALIGN     6		/* padding the linker re-computes (relaxation objects only): r_offset the start of the padding, symbol 0,
					   addend = (bytes of padding the assembler put there) << 32 | alignment (a power of two, in bytes) */

/* e_flags of an object or executable: there is one instruction set, so no field names it.  The executable has e_flags 0, and so has a plain object;
   the two flags below are the only bits ld64 accepts (an object of an earlier iteration of the design, which held a number in the low four bits, is refused).
   (docs/relaxation.md).  A RELAX object (as64 --relax, the default) has a relocation on every instruction of .text
   whose operand is the address of a symbol, local ones too, and R_PDP64_ALIGN on every padding: so the linker may change the length of those
   instructions and move everything behind them.  NOADJ_TEXT: the assembler met something in .text that depends on a distance and is not a relocation (a
   difference of two labels in an expression, a `d(pc)` written as a number): the linker leaves that object's .text exactly as it is. */
#define EF_PDP64_RELAX      0x10
#define EF_PDP64_NOADJ_TEXT 0x20

#define SHN_ABS     0xFFF1
#define SHN_COMMON  0xFFF2
#endif
