; A user program learns the time by asking the kernel (the call number 7 is the example's own).
	.text
	.globl	_start
_start:
	movq	#7, r0
	trap	#0				; r0 comes back holding the time
