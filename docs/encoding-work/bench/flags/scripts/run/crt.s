	.text
	.globl	_start
_start:	call	main
	trap	#0
	.globl	write
write:	trap	#1
	ret
	.globl	memcpy
memcpy:	movq	r0, r3
	mcpy	r0, r1, r2
	movq	r3, r0
	ret
	.globl	memmove
memmove: movq	r0, r3
	mmov	r0, r1, r2
	movq	r3, r0
	ret
	.globl	memset
memset:	movq	r0, r3
	mset	r0, r1, r2
	movq	r3, r0
	ret
