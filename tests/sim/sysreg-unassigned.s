; mfsr r1, <8>: system register 8 is not assigned: illegal instruction
	.text
	.globl	_start
_start:
	.word	0x540d, 0x0810
	movq	#1, r0
	trap	#0
