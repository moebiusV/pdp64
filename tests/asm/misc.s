	.text
	movql #0x123456789abcdef0,r1
	rori32 r1,#5,r2
	rol r1,#3,r2
	clz r1,r2
	div r1,r2,r3
	fmadd r1,r2,r3,r4
	extb r1,#4,#8,r2
	dshr r1,r2,#3,r4
	xadd r1,r2,r3
	cas r1,r2,r3,r4
	maskeqz r1,r2,r3
	bsel r1,r2,r3,r4
	aesks1 r1,#3,r2
	nop
	halt
	pushm #0x8F00
	popm #0x0100
	sob r1,lb
lb:	btag r1,#2,lb
	movub 8(r3),r2
	addm r1,16(r2)
	movq.u 8(r1),r2
	movb.d (r3),r4
	fcmp r1,r2
	fadd r2,r3
	mul #6,r1
	shr #40,r2
	sar r3,r4
	mulh r1,r2
	ret
