; k_dger (cblas_dger, row major): gW += gy x^T.  r0 = gW, r1 = gy, r2 = x, r3 = nout, r4 = nin.  An axpy of x by gy[i] into each row.
k_dger:
	lea	(r2)(r4*8),r6
.row:	movq	(r1)+,r9
	movq	r2,r7
	vec	r7,r6
	vld.d	v0,(r7)+
	vld.d	v1,(r0)
	vfma.d	v1,v0,r9
	vst.d	v1,(r0)+
	vend
	dec	r3
	cbgt	r3,#0,.row
	ret
