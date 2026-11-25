; 1000 iterations of the loop with nothing in it (the overhead)
	.text
	.globl	_start
_start:
	movq	#1000, r10
loop:
	sub	#1, r10
	bne	loop
	movq	#0, r0
	trap	#0
