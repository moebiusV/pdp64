; mfcpuid is privileged (manual 6.2.5, 6.14.11; errata 186 decision 2): in user mode (the default machine) it is a privileged-instruction fault: sim64 stops with status 139
	.text
	.globl	_start
_start:
	movq	#0, r0
	mfcpuid	r1
	movq	#1, r0
	trap	#0
