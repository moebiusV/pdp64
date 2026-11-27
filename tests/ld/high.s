; a symbol in the low 2 GB or the top 2 GB of the address space is one 32-bit sign-extended immediate; any other address makes the linker grow the instruction to the ten-byte form (a plain object cannot grow)
	.text
	.globl	_start
_start:	mov	$target, r1
	halt
	.data
target:	.quad	0
