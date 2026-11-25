	add	r1, r2
	movq	(r3), r4
	movq	8(r3), r4
	cbeq	r1, r2, 1f
1:	movq	#5, r5
