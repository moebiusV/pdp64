; k_quant as the scalar loop that wave 1 leaves (the pcc loop with the scalar conversion FCVTSL), for the count: r0 = y (bytes), r1 = x (floats), r2 = id, r3 = n.
k_quant:
.l:	movl	(r1)+,r5		; x[i] as float bits
	fmul32	r2,r5			; x * id
	fcvtsl	r5,r5			; int32, truncated, saturated
	movq	r5,r6
	cbge	r6,#-128,.lo
	movq	#-128,r6
.lo:	cble	r6,#127,.hi
	movq	#127,r6
.hi:	movb	r6,(r0)+
	dec	r3
	cbgt	r3,#0,.l
	ret
