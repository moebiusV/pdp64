; mfsr cpuid in kernel mode (sim64 -k) reads the core number: two reads give the same number, and the register is read only (the assembler refuses a write)
	.text
	.globl	_start
_start:
	mfsr	r1, cpuid
	mfsr	r2, cpuid
	cbne r1, r2, F1
	movq	#0, r0
	halt
F1:	movq	#1, r0
	halt
