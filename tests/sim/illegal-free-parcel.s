; a first parcel that no instruction uses is an illegal instruction (exit 139, vector 2).  The two-byte words that were RTI, RTT and GENTER before they took a mask are no
; instructions and have no names; a return to a lesser mode exists only with a mask (the assembler refuses `rti` with none), and the last parcel, 0xffff, is free.
	.text
	.globl _start
_start:
	lea buf, r8
	mov #1, r1
	mov #2, r2
	mov #3, r3
	mov #4, r4
	.word 0xffff
	clr r0
	halt
	.data
	.align 8
buf:	.space 64
