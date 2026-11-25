	add	x0, x0, x1
	ldr	x2, [x3]
	ldr	x2, [x3, #8]
	cmp	x0, x1
	b.eq	1f
1:	mov	x0, #5
