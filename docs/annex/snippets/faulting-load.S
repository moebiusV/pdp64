; A load that faults delivers nothing: the destination keeps its old value (no data was ever put in it for a later instruction to use).
; Run: sim64 -K
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	lea	hbad, r2
	movq	#512, r3
fill:	movq	r2, (r1)+
	sob	r3, fill
	lea	vtab, r1
	lea	hbf, r2
	movq	r2, 8*VECTOR_BUSFAULT(r1)
	movq	=0x1111, r4			; the old value of the destination
	movq	=0x0100000000000000, r5		; an address with nothing behind it
	movq	(r5), r4			; faults; r4 must keep 0x1111
	movq	#1, r0
	halt
hbf:	movq	=0x1111, r6
	cbne	r4, r6, hbad
	movq	#0, r0
	halt
hbad:	movq	#98, r0
	halt
	.data
	.align	4096
vtab:	.space	4096
