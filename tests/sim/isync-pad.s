; isync with a non-zero pad byte in the four-byte form is an illegal instruction (sim64 -k stops with 139)
	.text
	.globl	_start
_start:
	.word	0x540f, 0x0201
	movq	#1, r0
	trap	#0
