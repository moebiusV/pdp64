; isync in kernel mode (sim64 -k): it runs, as before (the privilege check was removed, not the instruction); and it does not touch the registers.
	.text
	.globl	_start
_start:
	mov	#5, r1
	isync
	cbne r1, #5, F1
	mov	#0, r0
	halt
F1:	mov	#1, r0
	halt
