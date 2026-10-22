; isync in kernel mode (sim64 -k): the page-2 form, the four-byte form written out, and no flag changes
	.text
	.globl	_start
_start:
	movq	#5, r1
	cmp	r1, #7		; N and C set
	mfps	r10
	isync
	.word	0x540f, 0x0200	; isync, four bytes
	.word	0xec00		; isync, two bytes
	mfps	r9
	cmp	r9, r10
	bne	f1
	movq	#0, r0
	halt
f1:	movq	#1, r0
	halt
