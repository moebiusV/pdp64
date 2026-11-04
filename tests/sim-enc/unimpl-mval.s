; mval: not in the reference executor, so it traps as an unimplemented instruction (exit 139, the message names it)
	.text
	.globl _start
_start:
	lea buf, r8
	movq #1, r1
	movq #2, r2
	movq #3, r3
	movq #4, r4
	mval r1,r2
	clr r0
	halt
	.data
	.align 8
buf:	.space 64
