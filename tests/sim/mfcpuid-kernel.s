; mfcpuid in kernel mode (sim64 -k) returns the same number as mfsr cpuid
	.text
	.globl	_start
_start:
	mfcpuid	r1
	mfsr	r2, cpuid
	cmp	r1, r2
	bne	F1
	movq	#0, r0
	halt
F1:	movq	#1, r0
	halt
