/* Page 2 (the length code 11): one-parcel forms of page-1 instructions.  The meaning of each page-2 opcode is a table (p2.c), written once and read
   in both directions: the executors expand a page-2 instruction into the page-1 instruction it abbreviates, and the assembler asks whether a
   page-1 instruction has such an abbreviation.  Call calibrate() (calib.h) first. */
#ifndef P2_H
#define P2_H
#include <stdint.h>
#include "fmt.h"

/* p: a decoded instruction with shape FS_P2 (len, opc, reg, low).  lf: the page-1 instruction it abbreviates, as the decoder would have
   produced it from the long encoding (len = 1, shape FS_BASE or FS_WIDE).  Returns 0, or -1 if the page-2 opcode is reserved. */
int p2_expand(const struct fmt *p, struct fmt *lf);

/* Is there a one-parcel form for this page-1 instruction?  It is described by the top-level opcode, the reg field, the addressing mode
   (AMODE_BASE or AMODE_IMM), the base register (for AMODE_BASE) and the signed displacement or immediate.  On success *p is the page-2
   instruction (len, opc, reg, low) and the result is 1.  When several page-2 opcodes mean the same, the lowest opcode is returned. */
int p2_find(int opc, int reg, int mode, int rm, int64_t d, struct fmt *p);
#endif
