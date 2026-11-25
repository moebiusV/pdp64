; 1000 reads of the time by a system call (a trap of the stand-in system: write of 0 bytes; the trap costs `sys` cycles in the model)
	.text
	.globl	_start
_start:
	movq	#1000, r10
loop:
	movq	#1, r0
	movq	#buf, r1
	movq	#0, r2
	trap	#1
	sub	#1, r10
	bne	loop
	movq	#0, r0
	trap	#0
	.data
buf:	.quad	0
