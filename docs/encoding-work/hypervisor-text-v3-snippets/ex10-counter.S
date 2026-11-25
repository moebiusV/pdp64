; 6.15 example 10: an atomic counter with fetch-and-add, and the two faults.
; XADD Rd, Rs, (Ra): Rd receives the old value; the word becomes old + Rs.
; Not yet assemblable (README).
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	count, r3
	movq	#1, r2
	xadd	r1, r2, (r3)			; one step: r1 is the number I took, the counter is one more
	halt
	; the faults, not run: the address register is used as it is, with no offset
	lea	count+4, r3
	xadd	r1, r2, (r3)			; an 8-byte word on a 4-byte boundary: a precise alignment fault, nothing changed
	.data
	.align	8
count:	.quad	0
