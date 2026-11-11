; the instructions that take a word of their own as an operand (spec/pdp64-asm.hbnf: condinsn, srinsn): the reader must read the word as a number, not as a label
	.text
f:	set	eq, r0
	set	ne, r0
	set	eq, r1
	set	cs, r4
	set	los, r0
	set	hs, r2
	set	al, r3
	mfsr	r1, ptbr
	mfsr	r2, cpuid
	mtsr	vbr, r3
	cbeq	r3, #5, f
	cbne	r1, r2, f
	call	foo
	ret
