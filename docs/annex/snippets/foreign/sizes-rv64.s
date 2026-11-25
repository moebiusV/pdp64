	add	a0, a0, a1
	ld	a2, 0(a3)
	ld	a2, 8(a3)
	beq	a0, a1, 1f
1:	li	a0, 5
