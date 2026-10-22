; isync is privileged: in user mode it is a fault (sim64 stops with 139)
	.text
	.globl	_start
_start:
	isync
	movq	#1, r0
	trap	#0
