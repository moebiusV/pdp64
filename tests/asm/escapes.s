	.text
	clz	r1, r2
	xnorpop	r1, r2, r3
	rori	r1, #5, r2
	rol	r1, #5, r2
	dshr	r1, r2, #5, r3
	extb	r1, #3, #8, r2
	div	r1, r2, r3
	mcpy	r1, r2, r3
	prober	r1, r2
	trap	#200
	trap	#3
	spl	#7
	wait
	nop
