	.text
	.globl	_start
_start:	movq	#msg, r1
	call	f
	bne	f
	movq	val(pc), r2
	halt
	.data
msg:	.quad	f
