	.text
	bitrev	r1, r2
	bit	r1, r2
	bhis	x
	bhi	x
	blo	x
	blos	x
x:	movq	r10, r11
	movq	r1, r15
	divu	r1, r2, r3
	div	r1, r2, r3
	mulh	r1, r2
	mulhu	r1, r2, r3
	tlbia
	tlbi	r5
	jmp	x
	jmpi	(r1)
	pushm	#3
	push	r1
