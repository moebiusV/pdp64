; isync with a non-zero reg or low in the two-byte form is an illegal instruction (sim64 -k stops with 139)
	.text
	.globl	_start
_start:
	.word	0xec01
	movq	#1, r0
	trap	#0
