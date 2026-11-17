; k_dscal (cblas_dscal): x[i] *= a.  r0 = x, r1 = a, r2 = n.  One memory stream read and written: one strip in memory, one in a register.
k_dscal:
	lea	(r0)(r2*8),r3
	vec	r0,r3
	vld.d	v0,(r0)
	vmul.d	v0,v0,r1
	vst.d	v0,(r0)+
	vend
	ret
