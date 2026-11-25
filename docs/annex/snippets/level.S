; The level of an interrupt follows from its vector number: nothing to program, so nothing to get wrong.
	.text
	.globl	_start
_start:
	lea	vtab, r1
	lea	disk_handler, r2
	movq	r2, 8*100(r1)			; vector 100 is a device's: its level is fixed by the number
	spl	#3				; a section that must not be disturbed by this device (and the levels below it)
	nop
	spl	#0
	halt
disk_handler:
	halt
	.data
	.align	4096
vtab:	.space	4096
