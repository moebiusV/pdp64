; 6.15 example 10: a counter that stops at its limit, built with LL and SC (a fetch-and-add cannot stop at a limit).
; The constrained loop: LL, register instructions only, a forward branch, SC; at most 16 instructions; the retry branch is after the SC.
; SC Rs, (Ra), Rd: Rd = 0 when the word was written, nonzero when it was not.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	count, r3
	movq	#98, r4				; (check, not in the text) start two below the limit
	movq	r4, (r3)
	movq	#100, r5			; the limit
retry:	ll	(r3), r1			; load the word and take the reservation on its 128 bytes
	cbeq	r1, r5, full			; at the limit: leave without writing (a forward branch)
	movq	r1, r6
	add	#1, r6				; the new value, in a register
	sc	r6, (r3), r4			; write only if no one wrote the 128 bytes since the LL
	cbne	r4, #0, retry			; r4 is not 0: try again from the LL
	br	retry
full:	movq	(r3), r4			; (check, not in the text) the counter stopped at its limit
	cbeq	r4, r5, 1f
	movq	#1, r0
	halt
1:	movq	#0, r0				; exit status 0: the checks passed
	halt
	.data
	.align	128
count:	.quad	0
	.space	120
