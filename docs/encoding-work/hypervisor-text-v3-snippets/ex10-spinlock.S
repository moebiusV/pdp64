; 6.15 example 10: a spin lock taken and released with compare-and-swap.  The lock word is 0 (free) or 1 (held).
; CAS Rd, Rs, (Ra): Rd holds the expected value and is overwritten by the old value; Rs is the new value; Ra holds the address.
; Not yet assemblable: the atomic words are not in the executor and the three-register spelling is not in as64 (README).
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
	movq	#0, r1
	movq	r1, (r3)			; the release is an ordinary store
	halt
	.data
	.align	8
lock:	.quad	0
