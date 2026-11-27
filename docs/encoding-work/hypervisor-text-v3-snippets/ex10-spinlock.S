; 6.15 example 10: a spin lock taken and released with compare-and-swap.  The lock word is 0 (free) or 1 (held).
; CAS Rs, (Ra), Rd: Rd holds the expected value and is overwritten by the old value; Rs is the new value; Ra holds the address.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	lock, r3
take:	mov	#0, r1				; expected: free
	mov	#1, r2				; new: held
	cas	r2, (r3), r1			; one step; r1 is now the old value
	cbeq	r1, #0, held			; the old value was 0: the lock is mine
	hint	#1				; it was 1: someone else holds it; tell the core this is a wait
	br	take
held:	nop					; ... the work on the shared data ...
	mov	(r3), r4			; (check, not in the text) the word holds 1 while the lock is held
	cbeq	r4, #1, 1f
	mov	#1, r0
	halt
1:	mov	#0, r1
	mov	r1, (r3)			; the release is an ordinary store
	mov	(r3), r4			; (check) the lock is free again, and taking it a second time works
	cbeq	r4, #0, 2f
	mov	#2, r0
	halt
2:	mov	#0, r1
	mov	#1, r2
	cas	r2, (r3), r1
	cbeq	r1, #0, 3f
	mov	#3, r0
	halt
3:	mov	#0, r0				; exit status 0: the checks passed
	halt
	.data
	.align	8
lock:	.quad	0
