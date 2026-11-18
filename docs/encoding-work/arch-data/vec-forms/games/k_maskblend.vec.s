; k_maskblend (wave 2, errata 171): dst[i] = m[i] ? a[i] : b[i] on bytes, the mask bytes being 0 or 255 (dav1d's `mask` blends with a stored mask; a compare makes the same kind of mask).
; r0 = dst, r1 = a, r2 = b, r3 = m, r4 = n.  One bitwise select.
k_maskblend:
	lea	(r1)(r4),r5
	vec	r1,r5
	vld.b	v0,(r1)+		; a
	vld.b	v1,(r2)+		; b
	vld.b	v2,(r3)+		; m
	vbsl	v3,v2,v0,v1		; (m & a) | (~m & b)
	vst.b	v3,(r0)+
	vend
	ret
