; 6.15 example 10: a spin lock taken and released with compare-and-swap.  The lock word is 0 (free) or 1 (held).
; CAS Rd, Rs, (Ra): Rd holds the expected value and is overwritten by the old value; Rs is the new value; Ra holds the address.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	lock, r3
take:	movq	#0, r1				; expected: free
	movq	#1, r2				; new: held
	casdb	r1, r2, (r3)			; one step, with the barrier; r1 is now the old value
	cbeq	r1, #0, held			; the old value was 0: the lock is mine
	hint	#1				; it was 1: someone else holds it; tell the core this is a wait
	br	take
held:	nop					; ... the work on the shared data ...
	movq	(r3), r4			; (check, not in the text) the word holds 1 while the lock is held
	cbeq	r4, #1, 1f
	movq	#1, r0
	halt
1:	movq	#0, r1
	movq	r1, (r3)			; the release is an ordinary store
	movq	(r3), r4			; (check) the lock is free again, and taking it a second time works
	cbeq	r4, #0, 2f
	movq	#2, r0
	halt
2:	movq	#0, r1
	movq	#1, r2
	casdb	r1, r2, (r3)
	cbeq	r1, #0, 3f
	movq	#3, r0
	halt
3:	movq	#0, r0				; exit status 0: the checks passed
	halt
	.data
	.align	8
lock:	.quad	0
