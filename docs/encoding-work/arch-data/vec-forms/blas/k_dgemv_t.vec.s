; k_dgemv_t (cblas_dgemv Trans, row major): gx = W^T gy.  r0 = W, r1 = gy, r2 = gx, r3 = nout, r4 = nin.  gx is cleared (a fill), then an axpy of each row of W
; by gy[i] into gx.
k_dgemv_t:
	movq	r2,r5
	lea	(r2)(r4*8),r6
	vec	r5,r6
	clrq	(r5)+			; the fill: single-instruction prefix
.row:	movq	(r1)+,r9		; gy[i]
	movq	r2,r7
	vec	r7,r6
	vld.d	v0,(r0)+		; W[i, :]
	vld.d	v1,(r7)
	vfma.d	v1,v0,r9
	vst.d	v1,(r7)+
	vend
	dec	r3
	cbgt	r3,#0,.row
	ret
