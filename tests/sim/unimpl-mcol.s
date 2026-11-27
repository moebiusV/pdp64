; mcol: specified (granule colouring) and not in the reference executor yet, so it traps as an unimplemented instruction (exit 139, the message names it); phase B replaces this test with the real ones
	.text
	.globl _start
_start:
	lea buf, r8
	mov $1, r1
	mov $2, r2
	mov $3, r3
	mcol r8, r1, r2
	clr r0
	halt
	.data
	.align 16
buf:	.space 64
