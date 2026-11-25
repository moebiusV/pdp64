; syspg1: the word that was RTI (0), RTT (1) or GENTER (2) before they took a mask: reserved, so it traps as an unimplemented instruction (exit 139, the message names it)
	.text
	.globl _start
_start:
	lea buf, r8
	movq #1, r1
	movq #2, r2
	movq #3, r3
	movq #4, r4
	syspg1
	clr r0
	halt
	.data
	.align 8
buf:	.space 64
