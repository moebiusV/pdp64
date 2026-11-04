; .text with a difference of two labels in it (a table of offsets): as64 marks the object NOADJ_TEXT and ld64 leaves its .text as it is, so the number
; the assembler computed is still the distance of the two labels at run time.  The calls to the other object are not shortened either.
	.text
	.globl	_start
_start:	call	ext
	call	ext
	lea	L1, r4
	lea	L0, r5
	sub	r5, r4
	movzw	tab, r3
	cmp	r3, r4
	bne	fail
	movzw	tab+2, r3
	cmp	r3, #0
	bne	fail
	movq	#0, r0
	trap	#0
fail:	movq	#1, r0
	trap	#0
L0:	add	#1, r1
	add	#1, r1
	add	#1, r1
L1:	nop
tab:	.word	L1-L0, 0
