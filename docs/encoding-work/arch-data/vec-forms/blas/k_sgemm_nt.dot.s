; k_sgemm_nt, form 1: Y[M,N] = X[M,K] . W[N,K]^T by one dot product for each output, over K (both rows are contiguous for this layout).
; r0 = X, r1 = W, r2 = Y, r3 = M, r4 = K, r5 = N.  The same block as ddot; no register blocking, so two loads for every multiply-add.
k_sgemm_nt:
	lea	(r0)(r4*4),r9		; end of the first row of X: the region for every dot product (it moves with r0 below)
.i:	movq	r1,r7			; W back to its first row
	movq	r5,r8			; j count
	movq	r0,r10
.j:	movq	r10,r11			; the X row again
	clr	r12
	vec	r11,r9
	vld.f	v0,(r11)+
	vld.f	v1,(r7)+		; the block moves r7 along W's row, to the next row
	vmul.f	v0,v0,v1
	vacc.f	r12,v0
	vend
	movl	r12,(r2)+
	dec	r8
	cbgt	r8,#0,.j
	lea	(r0)(r4*4),r0		; next row of X
	lea	(r9)(r4*4),r9
	dec	r3
	cbgt	r3,#0,.i
	ret
