; A load that faults delivers nothing: the destination keeps its old value (no data was ever put in it for a later instruction to use).
; Run: sim64 -K
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
	lea	hbf, r2
	mov	r2, 8*VECTOR_BUSFAULT(r1)
	mov	=0x1111, r4			; the old value of the destination
	mov	=0x0100000000000000, r5		; an address with nothing behind it
	mov	(r5), r4			; faults; r4 must keep 0x1111
	mov	#1, r0
	halt
hbf:	mov	=0x1111, r6
	cbne	r4, r6, hbad
	mov	#0, r0
	halt
hbad:	mov	#98, r0
	halt
	.data
	.align	4096
vtab:	.space	4096
