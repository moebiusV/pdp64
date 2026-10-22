; mfsr in user mode (the default) is a privileged-instruction fault: sim64 stops with status 139
	.text
	.globl	_start
_start:
	movq	#0, r0
	mfsr	r1, ptbr
	movq	#1, r0
	trap	#0
