; k_ddot (cblas_ddot): the sum of x[i]*y[i].  r0 = x, r1 = y, r2 = n; the result in r0 (a double in a general register).
k_ddot:
	clr	r4
	lea	(r0)(r2*8),r3
	vec	r0,r3
	vld.d	v0,(r0)+
	vld.d	v1,(r1)+
	vmul.d	v0,v0,v1
	vacc.d	r4,v0			; r4 += the sum of the lanes
	vend
	movq	r4,r0
	ret
