; a 32-bit sign-extended immediate: a symbol must be in the low 2 GB or the top 2 GB of the address space
	.text
	.globl	_start
_start:	movq	#target, r1
	halt
	.data
target:	.quad	0
