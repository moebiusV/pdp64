/* The widths and shapes of the instruction fields, measured from the generated encoder (common/calib.c).  Call calibrate() once. */
#ifndef CALIB_H
#define CALIB_H
extern int fieldbits[32][4];	/* [shape][len]: bits of the displacement field, 0 if the shape does not exist at that len */
extern int mode_shape[16];	/* addressing mode -> shape, 0 if no shape takes it */
extern int maxlen;		/* the longest len: a page-1 instruction is up to maxlen + 1 parcels */
extern int regbits, lowbits;	/* widths of the reg and low nibbles */
extern int cbimmbits;		/* bits of the immediate of cbCC */
extern int cbwimmbits;		/* bits of the immediate of the wide cbCC (six bytes) */
void calibrate(void);
int dispbits(int mode, int len);	/* bits of the displacement/immediate field of an operand mode at that len */
int cbwbits(int len);		/* bits of the displacement of the wide cbCC (parcels); 0 unless len is 2 */
int cbbits(int len);		/* bits of the displacement of cbCC (parcels) */
int branchbits(int len);	/* bits of the branch displacement field (parcels) */
#endif
