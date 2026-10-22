; mtsr in user mode (the default) is a privileged-instruction fault: sim64 stops with status 139
	.text
	.globl	_start
_start:
	movq	#0, r0
	mtsr	ptbr, r1
	movq	#1, r0
	trap	#0
