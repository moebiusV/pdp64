; mfsr r1, <13>: system register 13 is not assigned: illegal instruction
	.text
	.globl	_start
_start:
	.word	0x540d, 0x0d10
	movq	#1, r0
	trap	#0
