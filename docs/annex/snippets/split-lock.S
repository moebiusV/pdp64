; An atomic add on a word that is not aligned: the fault, with nothing changed.  Run: sim64 -K
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	lea	hbad, r2
	mov	#512, r3
fill:	mov	r2, (r1)+
	sob	r3, fill
	lea	vtab, r1
	lea	hmis, r2
	mov	r2, 8*VECTOR_MISALIGNED(r1)
	lea	buf+2, r3			; a 4-byte word at an address that is 2 mod 4
	mov	#1, r2
	aadd.s32	r2, (r3), r1			; never runs half: the misalignment fault
	mov	#1, r0				; not reached
	halt
hmis:	mfsr	r5, eva				; the address that was refused
	lea	buf+2, r6
	cbne	r5, r6, hbad
	mov	#0, r0
	halt
hbad:	mov	#98, r0
	halt
	.data
	.align	4096
vtab:	.space	4096
buf:	.space	16
