; isync is not privileged (errata 190, manual 6.2.6): in user mode it does not fault and gives the program no power; the sequence of a program that
; generates code (write the instructions, icinv, isync) runs in user mode.  The default machine of sim64 runs user mode: a fault would stop with 139.
	.text
	.globl	_start
_start:
	movq	#0x1234, r1
	lea	buf, r2
	movq	r1, (r2)
	icinv	r2
	isync
	icinva
	isync
	hint	#2
	isync
	movq	(r2), r3
	cmp	r3, r1
	bne	F1
	movq	#0, r0
	trap	#0
F1:	movq	#1, r0
	trap	#0
	.data
buf:	.quad	0
