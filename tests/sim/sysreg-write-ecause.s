; mtsr ecause, r1 (540e 0310) is an illegal instruction
	.text
	.globl	_start
_start:
	.word	0x540e, 0x0310
	movq	#1, r0
	trap	#0
