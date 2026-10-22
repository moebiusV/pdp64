; mfsr r1, ptbr with a nonzero pad nibble (parcel 1 = 0x0011) is an illegal instruction
	.text
	.globl	_start
_start:
	.word	0x540d, 0x0011
	movq	#1, r0
	trap	#0
