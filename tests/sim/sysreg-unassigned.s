; mfsr r1, <13>: system register 13 is not assigned: illegal instruction
; (sim64 -K and the QEMU machine with kernel=on: the illegal instruction is delivered to the handler in the vector table, which exits with 139)
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	.word	0x540d, 0x0d10
	movq	#1, r0
	halt
h_illegal:	movq	#139, r0
	halt
	.data
	.align	8
vtab:	.space	16
	.quad	h_illegal
