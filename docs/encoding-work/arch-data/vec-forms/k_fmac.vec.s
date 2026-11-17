; k_fmac (FFmpeg vector_fmac_scalar_c): dst[i] += src[i] * mul.  r0 = dst, r1 = src, r2 = len, r3 = mul (a float in a general register).
k_fmac:
	lea	(r0)(r2*4),r4
	vec	r0,r4
	vld.f	v0,(r1)+
	vld.f	v1,(r0)			; no +: the strip is stored back to the same place, and the store moves r0
	vfma.f	v1,v0,r3		; v1 += v0 * r3
	vst.f	v1,(r0)+
	vend
	ret
