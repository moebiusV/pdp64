; isync in kernel mode (sim64 -k): it runs, as before (the privilege check was removed, not the instruction); and it does not touch the registers or the flags.
	.text
	.globl	_start
_start:
	movq	#5, r1
	cmp	r1, #5
	isync
	bne	F1
	cmp	r1, #5
	bne	F1
	movq	#0, r0
	halt
F1:	movq	#1, r0
	halt
