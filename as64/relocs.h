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

#define SHN_ABS     0xFFF1
#define SHN_COMMON  0xFFF2
#endif
