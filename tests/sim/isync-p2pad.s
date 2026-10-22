; isync with a non-zero reg or low in the two-byte form is an illegal instruction: delivered to the handler in the vector table (vector 2), which exits with 139 (sim64 -K, QEMU kernel mode)
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	.word	0xec01
	movq	#1, r0
	halt
h_illegal:	movq	#139, r0
	halt
	.data
	.align	8
vtab:	.space	16
	.quad	h_illegal
