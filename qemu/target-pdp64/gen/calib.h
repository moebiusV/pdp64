/* The widths and shapes of the instruction fields, measured from the generated encoder (common/calib.c).  Call calibrate() once. */
#ifndef CALIB_H
#define CALIB_H
extern int fieldbits[16][4];	/* [shape][len]: bits of the displacement field, 0 if the shape does not exist at that len */
extern int mode_shape[16];	/* addressing mode -> shape, 0 if no shape takes it */
extern int maxlen;		/* the longest len: an instruction is up to maxlen + 1 parcels */
extern int regbits, lowbits;	/* widths of the reg and low nibbles */
void calibrate(void);
int dispbits(int mode, int len);	/* bits of the displacement/immediate field of an operand mode at that len */
int branchbits(int len);	/* bits of the branch displacement field (parcels) */
#endif
