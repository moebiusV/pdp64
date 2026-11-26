	.text
	.globl	_start
_start:	movq	#msg, r1
	call	f
	br	f
	movq	val(pc), r2
	halt
	.data
msg:	.quad	f
