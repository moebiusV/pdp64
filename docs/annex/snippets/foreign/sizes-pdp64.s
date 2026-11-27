	add	r1, r2
	mov	(r3), r4
	mov	8(r3), r4
	cbeq	r1, r2, 1f
1:	mov	#5, r5
