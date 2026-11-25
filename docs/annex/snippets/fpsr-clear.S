; A context switch: writing the address-space number and the table base is enough to clear the previous program's floating-point flags.
	.text
	.globl	_start
_start:
	fadd	r1, r2				; (the previous program's arithmetic set its sticky flags)
	mtsr	asid, r3			; the next program's number ...
	mtsr	ptbr, r4			; ... and table: the flags are cleared by these writes, not by a duty of the kernel
