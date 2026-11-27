; mval: not in the reference executor, so it traps as an unimplemented instruction (exit 139, the message names it)
	.text
	.globl _start
_start:
	lea buf, r8
	mov #1, r1
	mov #2, r2
	mov #3, r3
	mov #4, r4
	mval r1,r2
	clr r0
	halt
	.data
	.align 8
buf:	.space 64
