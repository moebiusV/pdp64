; k_dgemv_n (cblas_dgemv NoTrans, row major): y = W x.  r0 = W, r1 = x, r2 = y, r3 = nout, r4 = nin.  A dot product for each row; the rows are a scalar loop,
; and the W pointer, moved by the block over the row, is already at the next row.
k_dgemv_n:
	lea	(r1)(r4*8),r6		; end of x (the region of every row is x)
.row:	movq	r1,r7			; x again (the block moves the pointer it is given)
	clr	r8
	vec	r7,r6
	vld.d	v0,(r7)+
	vld.d	v1,(r0)+
	vmul.d	v0,v0,v1
	vacc.d	r8,v0
	vend
	movq	r8,(r2)+
	dec	r3
	cbgt	r3,#0,.row
	ret
