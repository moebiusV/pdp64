; a reserved page-2 opcode (0x0F: len = 11, opcode 001111) is an illegal instruction: sim64 stops with status 139
	.text
	.globl	_start
_start:
	movq	#0, r0
	.word	0xCF12
	movq	#1, r0
	trap	#0
