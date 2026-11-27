	.text
	.globl	_start
_start:	mov	$msg, r1
	call	f
	br	f
	mov	val(pc), r2
	halt
	.data
msg:	.quad	f
