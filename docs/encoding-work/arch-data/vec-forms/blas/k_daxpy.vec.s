; k_daxpy (cblas_daxpy): y[i] += a * x[i].  r0 = y, r1 = x, r2 = a, r3 = n.
k_daxpy:
	lea	(r0)(r3*8),r4
	vec	r0,r4
	vld.d	v0,(r1)+
	vld.d	v1,(r0)
	vfma.d	v1,v0,r2
	vst.d	v1,(r0)+
	vend
	ret
