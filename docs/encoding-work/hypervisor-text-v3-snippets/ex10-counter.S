; 6.15 example 10: an atomic counter with fetch-and-add, and the two faults.
; AADD Rs, (Ra), Rd: Rd receives the old value; the word becomes old + Rs.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	count, r3
	movq	#1, r2
	aadd	r2, (r3), r1			; one step: r1 is the number I took, the counter is one more
	cbeq	r1, #0, 1f			; (check, not in the text) the number taken was the old value, 0
	movq	#1, r0
	halt
1:	aadd	r2, (r3), r1
	cbeq	r1, #1, 2f			; (check) the second number is 1
	movq	#2, r0
	halt
2:	movq	(r3), r4
	cbeq	r4, #2, 3f			; (check) the counter is 2
	movq	#3, r0
	halt
3:	movq	#0, r0				; exit status 0: the checks passed
	halt
	; the fault, not run here (tests/sim/atom-fault-align.S runs it): the address register is used as it is, with no offset
	lea	count+4, r3
	aadd	r2, (r3), r1			; an 8-byte word on a 4-byte boundary: a precise alignment fault, nothing changed
	.data
	.align	8
count:	.quad	0
