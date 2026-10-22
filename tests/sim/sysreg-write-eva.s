; mtsr eva is refused by the assembler, so the word is written by hand: mtsr eva, r1 = 540e 0210; a write to a read-only register is an illegal instruction
	.text
	.globl	_start
_start:
	.word	0x540e, 0x0210
	movq	#1, r0
	trap	#0
