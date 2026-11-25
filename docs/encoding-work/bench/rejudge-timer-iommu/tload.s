; 1000 reads of the time from a kernel-kept word (one load), user mode of the stand-in system
	.text
	.globl	_start
_start:
	movq	#1000, r10
	movq	#page, r12
loop:
	movq	(r12), r1
	sub	#1, r10
	bne	loop
	movq	#0, r0
	trap	#0
	.data
	.align	8
page:	.quad	12345
